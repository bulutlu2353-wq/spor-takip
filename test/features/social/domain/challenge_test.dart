import 'package:flutter_test/flutter_test.dart';
import 'package:spor_takip/features/social/domain/challenge.dart';

import '../social_fixtures.dart';

void main() {
  test('fromJson reads every column and converts times to local', () {
    final c = Challenge.fromJson({
      'id': 'ch1',
      'creator': 'ayse',
      'community_id': 'c1',
      'name': 'Bu hafta 4 antrenman',
      'kind': 'goal',
      'metric': 'workouts',
      'muscle': null,
      'target': 4,
      'starts_at': '2026-10-07T00:00:00+00:00',
      'ends_at': '2026-10-14T00:00:00+00:00',
    });
    expect((c.id, c.creator, c.communityId, c.name), ('ch1', 'ayse', 'c1', 'Bu hafta 4 antrenman'));
    expect((c.kind, c.metric, c.muscle, c.target), (ChallengeKind.goal, ChallengeMetric.workouts, null, 4.0));
    expect(c.startsAt, DateTime.utc(2026, 10, 7).toLocal());
    expect(c.isCommunity, isTrue);
    expect(c.days, 7);
  });

  test('state walks upcoming → active → finalizing → finished at the exact boundaries', () {
    final c = socialChallenge();
    expect(c.state(DateTime(2026, 10, 6, 23, 59)), ChallengeState.upcoming);
    expect(c.state(DateTime(2026, 10, 7)), ChallengeState.active);
    expect(c.state(DateTime(2026, 10, 13, 23, 59)), ChallengeState.active);
    expect(c.state(DateTime(2026, 10, 14)), ChallengeState.finalizing);
    expect(c.finalAt, DateTime(2026, 10, 15));
    expect(c.state(DateTime(2026, 10, 15)), ChallengeState.finished);
  });

  test('participant fromJson and copyWith', () {
    final p = ChallengeParticipant.fromJson({
      'challenge_id': 'ch1',
      'user_id': 'me',
      'status': 'invited',
      'progress': 18.5,
    });
    expect((p.challengeId, p.userId, p.status, p.progress), ('ch1', 'me', ChallengeStatus.invited, 18.5));
    expect(p.copyWith(progress: 20).progress, 20);
    expect(p.copyWith(progress: 20).status, ChallengeStatus.invited);
  });

  test('a draft becomes RPC parameters with UTC times', () {
    final draft = ChallengeDraft(
      name: 'Kontrol',
      kind: ChallengeKind.race,
      metric: ChallengeMetric.volume,
      muscle: 'chest',
      startsAt: DateTime.utc(2026, 10, 9, 12),
      endsAt: DateTime.utc(2026, 10, 16, 12),
      invitees: const ['ayse'],
    );
    expect(draft.toParams(), {
      'p_name': 'Kontrol',
      'p_kind': 'race',
      'p_metric': 'volume',
      'p_muscle': 'chest',
      'p_target': null,
      'p_starts_at': '2026-10-09T12:00:00.000Z',
      'p_ends_at': '2026-10-16T12:00:00.000Z',
      'p_community_id': null,
      'p_invitees': ['ayse'],
    });
  });
}
