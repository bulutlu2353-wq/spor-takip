import 'package:flutter_test/flutter_test.dart';
import 'package:spor_takip/features/gamification/domain/xp_rules.dart';
import 'package:spor_takip/features/social/domain/challenge.dart';
import 'package:spor_takip/features/social/domain/challenge_progress.dart';

import '../../gamification/game_fixtures.dart';
import '../social_fixtures.dart';

final _sessions = [
  // Pencerede: 3 bench (100 kg × 5) + 2 squat (120 kg × 5) + 1 tamamlanmamış.
  gameSession('in', DateTime(2026, 10, 8, 18), [
    ...gameSets('bench', 3, kg: 100, reps: 5),
    ...gameSets('squat', 2, kg: 120, reps: 5),
    gameSet('bench', kg: 100, reps: 5, done: false, index: 9),
  ]),
  // Pencerede ama tamamlanmış seti yok: sayılmaz.
  gameSession('empty', DateTime(2026, 10, 9, 8), [gameSet('bench', done: false)]),
  // Pencereden önce ve tam bitişte: sayılmaz.
  gameSession('before', DateTime(2026, 10, 6, 18), gameSets('bench', 4)),
  gameSession('at_end', DateTime(2026, 10, 14), gameSets('squat', 5)),
  // Devam eden oturum: sayılmaz.
  gameSession('open', null, gameSets('bench', 2)),
];

double _value(ChallengeMetric metric, {String? muscle, List<XpEvent> extra = const []}) => challengeValue(
      socialChallenge(metric: metric, muscle: muscle),
      _sessions,
      [...xpEvents(_sessions, [DateTime(2026, 10, 7, 9)]), ...extra],
      gameExercisesById,
    );

void main() {
  test('"now" starts immediately; "tomorrow" starts at local midnight and lasts whole days', () {
    final now = DateTime(2026, 10, 9, 12, 30);
    expect(challengeWindow(ChallengeStart.now, 7, now), (startsAt: now, endsAt: DateTime(2026, 10, 16, 12, 30)));
    expect(
      challengeWindow(ChallengeStart.tomorrow, 3, now),
      (startsAt: DateTime(2026, 10, 10), endsAt: DateTime(2026, 10, 13)),
    );
    expect(
      challengeWindow(ChallengeStart.tomorrow, 30, DateTime(2026, 10, 25, 22)),
      (startsAt: DateTime(2026, 10, 26), endsAt: DateTime(2026, 11, 25)),
    );
  });

  test('workouts count finished sessions with a completed set inside [start, end)', () {
    expect(_value(ChallengeMetric.workouts), 1);
  });

  test('sets count completed sets; a muscle filter weighs primary 1 and secondary 0.5', () {
    expect(_value(ChallengeMetric.sets), 5);
    expect(_value(ChallengeMetric.sets, muscle: 'chest'), 3);
    expect(_value(ChallengeMetric.sets, muscle: 'triceps'), 1.5);
    expect(_value(ChallengeMetric.sets, muscle: 'lats'), 0);
  });

  test('volume sums kg × reps (weighted by muscle) and rounds', () {
    expect(_value(ChallengeMetric.volume), 3 * 500 + 2 * 600);
    expect(_value(ChallengeMetric.volume, muscle: 'chest'), 1500);
    expect(_value(ChallengeMetric.volume, muscle: 'triceps'), 750);
  });

  test('xp sums events in the window, includes the meal day at the start, skips challenge rewards', () {
    // Antrenman 50 + 5 × 5 = 75; 7 Ekim öğün günü (gün başı = başlangıç) +10.
    final reward = XpEvent(source: XpSource.challenge, date: DateTime(2026, 10, 8), xp: 100, label: 'x');
    expect(_value(ChallengeMetric.xp, extra: [reward]), 85);
  });
}
