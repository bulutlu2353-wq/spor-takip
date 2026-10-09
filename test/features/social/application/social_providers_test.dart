import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spor_takip/features/gamification/application/gamification_providers.dart';
import 'package:spor_takip/features/gamification/domain/player_summary.dart';
import 'package:spor_takip/features/onboarding/application/auth_providers.dart';
import 'package:spor_takip/features/progress/application/progress_providers.dart';
import 'package:spor_takip/features/social/application/social_providers.dart';
import 'package:spor_takip/features/workout/application/muscle_heat_providers.dart';
import 'package:spor_takip/features/workout/application/session_providers.dart';

import '../../gamification/game_fixtures.dart';
import '../fakes.dart';
import '../social_fixtures.dart';

final _sessions = [gameSession('a', DateTime(2026, 10, 8, 18), gameSets('bench', 3))];

ProviderContainer _container(FakeSocialRepository repo) {
  final container = ProviderContainer(overrides: [
    isLoggedInProvider.overrideWithValue(true),
    socialRepositoryProvider.overrideWithValue(repo),
    nowProvider.overrideWithValue(() => DateTime(2026, 10, 9, 12)),
    allSessionsProvider.overrideWith((ref) async => _sessions),
    mealTimesProvider.overrideWith((ref) async => [DateTime(2026, 10, 9, 8)]),
    exercisesByIdProvider.overrideWith((ref) async => gameExercisesById),
    playerSummaryProvider.overrideWith(
      (ref) async => playerSummary(_sessions, [DateTime(2026, 10, 9, 8)], gameExercisesById),
    ),
  ]);
  addTearDown(container.dispose);
  return container;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('the overview splits friends, incoming and outgoing requests', () async {
    final repo = FakeSocialRepository(
      me: socialMe,
      others: [socialAyse, socialBurak, socialCan, socialDeniz],
      friendships: [
        socialFriendship('me', 'ayse'),
        socialFriendship('burak', 'me'),
        socialFriendship('can', 'me', accepted: false),
        socialFriendship('me', 'deniz', accepted: false),
      ],
      stats: {'ayse': socialStats(level: 10), 'burak': socialStats(level: 20)},
    );
    final container = _container(repo);
    container.listen(socialOverviewProvider, (_, _) {});
    container.listen(incomingRequestCountProvider, (_, _) {});

    final overview = await container.read(socialOverviewProvider.future);
    expect([for (final f in overview.friends) f.profile.userId], ['burak', 'ayse']);
    expect(overview.friends.first.stats?.level, 20);
    expect([for (final r in overview.incoming) r.profile.userId], ['can']);
    expect([for (final r in overview.outgoing) r.profile.userId], ['deniz']);
    expect(container.read(incomingRequestCountProvider), 1);
    expect((await container.read(friendProfileProvider('ayse').future))?.profile.username, 'ayse_k');
    expect(await container.read(friendProfileProvider('can').future), isNull);
  });

  test('without a social profile nothing is fetched or published', () async {
    final repo = FakeSocialRepository();
    final container = _container(repo);
    container.listen(statsSyncProvider, (_, _) {});
    await container.read(statsSyncProvider.future);
    expect(repo.upserts, isEmpty);
    expect((await container.read(socialOverviewProvider.future)).friends, isEmpty);
    expect(container.read(incomingRequestCountProvider), 0);
  });

  test('stats are published once per change, and again after a privacy change', () async {
    final repo = FakeSocialRepository(me: socialMe);
    final container = _container(repo);
    container.listen(statsSyncProvider, (_, _) {});

    await container.read(statsSyncProvider.future);
    expect(repo.upserts, hasLength(1));
    expect(repo.upserts.single.weekly?.workouts, 1);

    container.invalidate(statsSyncProvider);
    await container.read(statsSyncProvider.future);
    expect(repo.upserts, hasLength(1));

    await container.read(socialActionsProvider).updateProfile(shareWeekly: false);
    await container.read(statsSyncProvider.future);
    expect(repo.upserts, hasLength(2));
    expect(repo.upserts.last.weekly, isNull);
  });

  test('actions refresh the friendships', () async {
    final repo = FakeSocialRepository(
      me: socialMe,
      others: [socialCan],
      friendships: [socialFriendship('can', 'me', accepted: false)],
    );
    final container = _container(repo);
    container.listen(socialOverviewProvider, (_, _) {});
    expect((await container.read(socialOverviewProvider.future)).incoming, hasLength(1));

    await container.read(socialActionsProvider).respond('can', accept: true);
    final after = await container.read(socialOverviewProvider.future);
    expect(after.incoming, isEmpty);
    expect([for (final f in after.friends) f.profile.userId], ['can']);
    expect(repo.responses, [('can', true)]);
  });
}
