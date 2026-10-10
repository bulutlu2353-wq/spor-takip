import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spor_takip/features/onboarding/application/auth_providers.dart';
import 'package:spor_takip/features/social/application/community_providers.dart';
import 'package:spor_takip/features/social/application/social_providers.dart';
import 'package:spor_takip/features/social/domain/community.dart';
import 'package:spor_takip/features/social/domain/period_keys.dart';
import 'package:spor_takip/features/workout/application/session_providers.dart';

import '../fakes.dart';
import '../social_fixtures.dart';

ProviderContainer _container(FakeSocialRepository repo) {
  final container = ProviderContainer(overrides: [
    isLoggedInProvider.overrideWithValue(true),
    socialRepositoryProvider.overrideWithValue(repo),
    nowProvider.overrideWithValue(() => DateTime(2026, 10, 9, 12)),
  ]);
  addTearDown(container.dispose);
  return container;
}

FakeSocialRepository _repo() => FakeSocialRepository(
      me: socialMe,
      others: [socialAyse, socialBurak],
      communities: [socialCommunity, socialCommunity2, socialCommunity3],
      members: {
        'c1': [
          socialMember('c1', 'me', owner: true),
          socialMember('c1', 'ayse', day: 2),
          socialMember('c1', 'burak', day: 3),
        ],
        'c2': [socialMember('c2', 'ayse', owner: true)],
        'c3': [socialMember('c3', 'me', owner: true)],
      },
      periodStats: {
        'me': socialPeriod(week: 640),
        'ayse': socialPeriod(week: 1420),
        'burak': socialPeriod(),
      },
    );

void main() {
  test('my communities are sorted by name with member count and my weekly position', () async {
    final container = _container(_repo());
    container.listen(myCommunitiesProvider, (_, _) {});
    final entries = await container.read(myCommunitiesProvider.future);
    expect([for (final e in entries) (e.community.id, e.memberCount, e.myPosition)], [
      ('c3', 1, 1),
      ('c1', 3, 2),
    ]);
  });

  test('without a social profile there are no communities', () async {
    final container = _container(FakeSocialRepository());
    container.listen(myCommunitiesProvider, (_, _) {});
    expect(await container.read(myCommunitiesProvider.future), isEmpty);
  });

  test('community detail has members, profiles (me included) and stats; null if not a member', () async {
    final container = _container(_repo());
    container.listen(communityDetailProvider('c1'), (_, _) {});
    container.listen(communityDetailProvider('c2'), (_, _) {});
    container.listen(communityDetailProvider('nope'), (_, _) {});

    final detail = (await container.read(communityDetailProvider('c1').future))!;
    expect(detail.community.name, 'Demir Kulübü');
    expect([for (final m in detail.members) m.userId], ['me', 'ayse', 'burak']);
    expect(detail.profiles.keys, containsAll(['me', 'ayse', 'burak']));
    expect(detail.stats['ayse']?.week.xp, 1420);
    expect(detail.iAmOwner, isTrue);
    expect(detail.myId, 'me');

    expect(await container.read(communityDetailProvider('c2').future), isNull);
    expect(await container.read(communityDetailProvider('nope').future), isNull);
  });

  test('the global board asks for last period titles and this period standings', () async {
    final repo = _repo();
    final container = _container(repo);
    container.listen(globalBoardProvider(PeriodKind.week), (_, _) {});
    await container.read(globalBoardProvider(PeriodKind.week).future);
    expect(repo.globalQueries, [(PeriodKind.week, '2026-W40'), (PeriodKind.week, '2026-W41')]);

    repo.globalQueries.clear();
    container.listen(globalBoardProvider(PeriodKind.month), (_, _) {});
    await container.read(globalBoardProvider(PeriodKind.month).future);
    expect(repo.globalQueries, [(PeriodKind.month, '2026-09'), (PeriodKind.month, '2026-10')]);
  });

  test('actions refresh my communities; errors keep their code', () async {
    final repo = _repo();
    final container = _container(repo);
    container.listen(myCommunitiesProvider, (_, _) {});
    final actions = container.read(communityActionsProvider);
    Future<List<String>> ids() async =>
        [for (final e in await container.read(myCommunitiesProvider.future)) e.community.id];

    expect(await ids(), ['c3', 'c1']);
    expect(await actions.joinByCode('aysetkm2'), 'c2');
    expect(await ids(), ['c3', 'c2', 'c1']);

    await actions.leave('c1');
    expect(await ids(), ['c3', 'c2']);
    expect(repo.left, ['c1']);

    expect(await actions.create(name: 'Demir', description: '', isPublic: true), 'new');
    expect(await ids(), contains('new'));

    repo.communityError = const CommunityException('community_limit');
    await expectLater(
      actions.join('c9'),
      throwsA(isA<CommunityException>().having((e) => e.code, 'code', 'community_limit')),
    );
  });
}
