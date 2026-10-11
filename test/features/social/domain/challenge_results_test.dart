import 'package:flutter_test/flutter_test.dart';
import 'package:spor_takip/features/gamification/domain/xp_rules.dart';
import 'package:spor_takip/features/social/domain/challenge.dart';
import 'package:spor_takip/features/social/domain/challenge_results.dart';

import '../social_fixtures.dart';

final _now = DateTime(2026, 10, 9, 12);
final _finishedRace = socialChallenge(id: 'old', startsAt: DateTime(2026, 9, 20), endsAt: DateTime(2026, 9, 27));
final _finishedGoal = socialChallenge(
  id: 'goal',
  kind: ChallengeKind.goal,
  target: 12,
  startsAt: DateTime(2026, 9, 20),
  endsAt: DateTime(2026, 9, 27),
);

List<ChallengeParticipant> _people(String id, Map<String, double> values) => [
      for (final MapEntry(key: user, value: v) in values.entries) socialParticipant(id, user, progress: v),
    ];

void main() {
  test('standings list joined people by value; equal values share a position, then by name', () {
    final rows = challengeStandings(
      socialChallenge(),
      [
        ..._people('ch1', {'me': 10, 'ayse': 14.5, 'burak': 10}),
        socialParticipant('ch1', 'can', status: ChallengeStatus.invited, progress: 99),
      ],
      names: const {'me': 'Samet', 'ayse': 'Ayşe Kaya', 'burak': 'Burak'},
    );
    expect([for (final r in rows) (r.userId, r.position, r.value)], [
      ('ayse', 1, 14.5),
      ('burak', 2, 10.0),
      ('me', 2, 10.0),
    ]);
    expect(rows.every((r) => !r.reachedGoal), isTrue);
  });

  test('goal standings mark who reached the target', () {
    final rows = challengeStandings(_finishedGoal, _people('goal', {'me': 10, 'ayse': 12}));
    expect({for (final r in rows) r.userId: r.reachedGoal}, {'ayse': true, 'me': false});
  });

  test('winners exist only once finished', () {
    final active = socialChallenge();
    expect(challengeWinners(active, _people('ch1', {'me': 10, 'ayse': 14}), _now), isEmpty);
    expect(challengeWinners(_finishedRace, _people('old', {'me': 10, 'ayse': 14}), _now), {'ayse'});
  });

  test('a race needs two joined people and a value above zero; ties share the win', () {
    expect(challengeWinners(_finishedRace, _people('old', {'me': 10}), _now), isEmpty);
    expect(challengeWinners(_finishedRace, _people('old', {'me': 0, 'ayse': 0}), _now), isEmpty);
    expect(challengeWinners(_finishedRace, _people('old', {'me': 14, 'ayse': 14, 'burak': 2}), _now), {'me', 'ayse'});
  });

  test('every goal reacher wins, even alone', () {
    expect(challengeWinners(_finishedGoal, _people('goal', {'me': 12}), _now), {'me'});
    expect(challengeWinners(_finishedGoal, _people('goal', {'me': 11, 'ayse': 13}), _now), {'ayse'});
  });

  test('rewards are XP events dated at the final moment, oldest first', () {
    final laterGoal = socialChallenge(
      id: 'goal2',
      name: 'Hedef',
      kind: ChallengeKind.goal,
      target: 3,
      startsAt: DateTime(2026, 9, 28),
      endsAt: DateTime(2026, 10, 5),
    );
    final events = challengeRewards('me', [
      (laterGoal, _people('goal2', {'me': 3})),
      (_finishedRace, _people('old', {'me': 20, 'ayse': 14})),
      (socialChallenge(), _people('ch1', {'me': 50, 'ayse': 1})),
      (_finishedGoal, _people('goal', {'me': 1})),
    ], _now);
    expect([for (final e in events) (e.source, e.xp, e.label, e.date)], [
      (XpSource.challenge, 100, '7 günde en çok set', DateTime(2026, 9, 28)),
      (XpSource.challenge, 50, 'Hedef', DateTime(2026, 10, 6)),
    ]);
  });
}
