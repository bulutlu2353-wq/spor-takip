import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spor_takip/features/gamification/domain/xp_rules.dart';
import 'package:spor_takip/features/gamification/application/xp_event_providers.dart';
import 'package:spor_takip/features/gamification/domain/game_settings.dart';
import 'package:spor_takip/features/onboarding/application/auth_providers.dart';
import 'package:spor_takip/features/progress/application/progress_providers.dart';
import 'package:spor_takip/features/social/application/challenge_providers.dart';
import 'package:spor_takip/features/social/application/social_providers.dart';
import 'package:spor_takip/features/social/domain/challenge.dart';
import 'package:spor_takip/features/workout/application/muscle_heat_providers.dart';
import 'package:spor_takip/features/workout/application/session_providers.dart';

import '../../gamification/game_fixtures.dart';
import '../fakes.dart';
import '../social_fixtures.dart';

// Aktif pencerede (7–14 Ekim) 3 set.
final _sessions = [gameSession('a', DateTime(2026, 10, 8, 18), gameSets('bench', 3))];

final _invite = socialChallenge(id: 'inv', name: 'Davet');
final _active = socialChallenge(id: 'ch1');
final _upcoming = socialChallenge(id: 'up', startsAt: DateTime(2026, 10, 10), endsAt: DateTime(2026, 10, 13));
final _finished = socialChallenge(id: 'old', name: 'Eski', startsAt: DateTime(2026, 9, 20), endsAt: DateTime(2026, 9, 27));
final _declined = socialChallenge(id: 'no');
final _community = socialChallenge(id: 'cm', communityId: 'c1', creator: 'me');

FakeSocialRepository _repo() => FakeSocialRepository(
      me: socialMe,
      others: [socialAyse, socialBurak],
      communities: [socialCommunity],
      members: {
        'c1': [socialMember('c1', 'me', owner: true), socialMember('c1', 'ayse', day: 2)],
      },
      challenges: [_invite, _active, _upcoming, _finished, _declined, _community],
      participants: {
        'inv': [socialParticipant('inv', 'ayse'), socialParticipant('inv', 'me', status: ChallengeStatus.invited)],
        'ch1': [socialParticipant('ch1', 'ayse', progress: 14), socialParticipant('ch1', 'me')],
        'up': [socialParticipant('up', 'burak'), socialParticipant('up', 'me')],
        'old': [socialParticipant('old', 'ayse', progress: 10), socialParticipant('old', 'me', progress: 20)],
        'no': [socialParticipant('no', 'ayse'), socialParticipant('no', 'me', status: ChallengeStatus.declined)],
        'cm': [socialParticipant('cm', 'me', progress: 2), socialParticipant('cm', 'ayse', progress: 5)],
      },
    );

ProviderContainer _container(FakeSocialRepository repo, {bool retry = false}) {
  final container = ProviderContainer(retry: retry ? null : (_, _) => null, overrides: [
    isLoggedInProvider.overrideWithValue(true),
    socialRepositoryProvider.overrideWithValue(repo),
    nowProvider.overrideWithValue(() => DateTime(2026, 10, 9, 12)),
    allSessionsProvider.overrideWith((ref) async => _sessions),
    mealTimesProvider.overrideWith((ref) async => const []),
    exercisesByIdProvider.overrideWith((ref) async => gameExercisesById),
    gameSettingsProvider.overrideWith((ref) async => const GameSettings(weeklyGoal: 3)),
  ]);
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('my challenges are grouped; my own value in active ones is live', () async {
    final container = _container(_repo());
    container.listen(myChallengesProvider, (_, _) {});
    container.listen(pendingChallengeInvitesProvider, (_, _) {});
    final mine = await container.read(myChallengesProvider.future);
    expect([for (final e in mine.invites) e.challenge.id], ['inv']);
    expect([for (final e in mine.active) e.challenge.id], ['ch1', 'cm']);
    expect([for (final e in mine.upcoming) e.challenge.id], ['up']);
    expect([for (final e in mine.finished) e.challenge.id], ['old']);
    expect(mine.active.first.mine?.progress, 3);
    expect(mine.finished.single.mine?.progress, 20);
    expect(mine.profiles.keys, containsAll(['me', 'ayse', 'burak']));
    expect(container.read(pendingChallengeInvitesProvider), 1);
  });

  test('without a social profile there are no challenges', () async {
    final container = _container(FakeSocialRepository());
    container.listen(myChallengesProvider, (_, _) {});
    final mine = await container.read(myChallengesProvider.future);
    expect(mine.invites.isEmpty && mine.active.isEmpty && mine.finished.isEmpty, isTrue);
  });

  test('sync publishes only active joined values, and only when they change', () async {
    final repo = _repo();
    final container = _container(repo);
    container.listen(challengeSyncProvider, (_, _) {});
    await container.read(challengeSyncProvider.future);
    expect(repo.publishedProgress, [('ch1', 3.0), ('cm', 3.0)]);

    container.invalidate(challengeSyncProvider);
    await container.read(challengeSyncProvider.future);
    expect(repo.publishedProgress, hasLength(2));
  });

  test('rewards come from finished challenges I won', () async {
    final container = _container(_repo());
    container.listen(challengeRewardsProvider, (_, _) {});
    final rewards = await container.read(challengeRewardsProvider.future);
    expect([for (final e in rewards) (e.source, e.xp, e.label)], [(XpSource.challenge, 100, 'Eski')]);
  });

  test('rewards fall back to empty when the repository fails', () async {
    // Varsayılan yeniden deneme açık: profil okuması denenirken bile boş dönmeli.
    final container = _container(_repo()..error = Exception('offline'), retry: true);
    container.listen(challengeRewardsProvider, (_, _) {});
    expect(await container.read(challengeRewardsProvider.future).timeout(const Duration(seconds: 5)), isEmpty);
  });

  test('community challenges list unfinished ones with server values', () async {
    final container = _container(_repo());
    container.listen(communityChallengesProvider('c1'), (_, _) {});
    final entries = await container.read(communityChallengesProvider('c1').future);
    expect([for (final e in entries) (e.challenge.id, e.mine?.progress)], [('cm', 2.0)]);
  });

  test('detail has profiles (me included), the community, a live value and delete rights', () async {
    final container = _container(_repo());
    container.listen(challengeDetailProvider('cm'), (_, _) {});
    container.listen(challengeDetailProvider('ch1'), (_, _) {});
    container.listen(challengeDetailProvider('nope'), (_, _) {});

    final community = (await container.read(challengeDetailProvider('cm').future))!;
    expect(community.community?.name, 'Demir Kulübü');
    expect(community.profiles.keys, containsAll(['me', 'ayse']));
    expect(community.mine?.progress, 3);
    expect(community.canDelete, isTrue);

    final friends = (await container.read(challengeDetailProvider('ch1').future))!;
    expect(friends.community, isNull);
    expect(friends.canDelete, isFalse);
    expect(await container.read(challengeDetailProvider('nope').future), isNull);
  });

  test('actions call the repository and refresh my challenges', () async {
    final repo = _repo();
    final container = _container(repo);
    container.listen(myChallengesProvider, (_, _) {});
    await container.read(myChallengesProvider.future);
    final actions = container.read(challengeActionsProvider);

    await actions.respond(_invite, accept: true);
    expect(repo.challengeResponses, [('inv', true)]);
    expect([for (final e in (await container.read(myChallengesProvider.future)).active) e.challenge.id],
        containsAll(['inv', 'ch1']));

    final id = await actions.create(ChallengeDraft(
      name: 'Yeni',
      kind: ChallengeKind.race,
      metric: ChallengeMetric.workouts,
      startsAt: DateTime(2026, 10, 9, 12),
      endsAt: DateTime(2026, 10, 12, 12),
      invitees: const ['ayse'],
    ));
    expect(id, 'new');
    expect([for (final e in (await container.read(myChallengesProvider.future)).active) e.challenge.id],
        contains('new'));

    await actions.leave(_active);
    await actions.delete(_community);
    expect(repo.leftChallenges, ['ch1']);
    expect(repo.deletedChallenges, ['cm']);
  });
}
