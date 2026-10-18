import 'package:flutter_test/flutter_test.dart';
import 'package:spor_takip/features/gamification/domain/battle_stats.dart';
import 'package:spor_takip/features/gamification/domain/fair_play.dart';
import 'package:spor_takip/features/workout/domain/workout_session.dart';

import '../game_fixtures.dart';

// 18 Ekim 2026 pazar; hafta 12 Ekim pazartesi başlar.
final _today = DateTime(2026, 10, 18, 20);

StatInputs _inputs(List<WorkoutSession> sessions, {double? kg = 100, int goal = 3}) =>
    StatInputs(verdicts: judgeSessions(sessions), weeklyGoal: goal, bodyWeightKg: kg);

/// [at] gününde 18:00'de biten oturum.
WorkoutSession _session(String id, DateTime at, List<SessionSet> sets) =>
    gameSession(id, DateTime(at.year, at.month, at.day, 18), sets);

void main() {
  group('strength', () {
    test('top three exercises 1RM over body weight', () {
      final stats = statsOn(_today, _inputs([
        _session('a', DateTime(2026, 10, 10), [
          ...gameSets('bench', 1, kg: 100, reps: 1),
          ...gameSets('squat', 1, kg: 140, reps: 1),
          ...gameSets('deadlift', 1, kg: 160, reps: 1),
          ...gameSets('row', 1, kg: 50, reps: 1),
        ]),
      ]));
      // (100 + 140 + 160) / 100 = 4,0 → 4 / 4,5 × 100 = 88,9 → 89.
      expect(stats.strength, 89);
    });

    test('uses only the last 90 days and caps at 100', () {
      final inside = _session('in', DateTime(2026, 7, 21), gameSets('bench', 3, kg: 200, reps: 1));
      final outside = _session('out', DateTime(2026, 7, 20), gameSets('squat', 3, kg: 400, reps: 1));
      expect(statsOn(_today, _inputs([inside, outside])).strength, 44); // 200 / 100 / 4,5 → 44
      expect(statsOn(_today, _inputs([inside], kg: 40)).strength, 100);
    });

    test('is 1 without body weight or without a 1RM', () {
      final s = _session('a', DateTime(2026, 10, 10), gameSets('bench', 3, kg: 100, reps: 1));
      expect(statsOn(_today, _inputs([s], kg: null)).strength, 1);
      expect(statsOn(_today, _inputs([_session('b', DateTime(2026, 10, 10), gameSets('bench', 3))])).strength, 1);
    });

    test('ignores sessions after the day', () {
      final later = _session('a', DateTime(2026, 10, 19), gameSets('bench', 3, kg: 100, reps: 1));
      expect(statsOn(_today, _inputs([later])).strength, 1);
    });
  });

  group('endurance', () {
    test('counted sets in the last 28 days over 3', () {
      final stats = statsOn(_today, _inputs([
        _session('a', DateTime(2026, 9, 21), gameSets('bench', 10)), // 18 Ekim − 27 = 21 Eylül: içeride
        _session('b', DateTime(2026, 9, 20), gameSets('bench', 10)), // dışarıda
        _session('c', DateTime(2026, 10, 1), gameSets('bench', 10)),
        _session('d', DateTime(2026, 10, 2), gameSets('bench', 2)), // sayılmaz (< 3 set)
      ]));
      expect(stats.endurance, 7); // 20 / 3 = 6,7 → 7
    });

    test('caps at 100', () {
      final sessions = [
        for (var i = 0; i < 28; i++) _session('s$i', DateTime(2026, 9, 21 + i), gameSets('bench', 12)),
      ];
      expect(statsOn(_today, _inputs(sessions)).endurance, 100); // 336 / 3
    });
  });

  group('consistency', () {
    test('12.5 per completed week that hit the goal; the current week does not count', () {
      List<WorkoutSession> week(String id, DateTime monday, int days) => [
            for (var i = 0; i < days; i++)
              _session('$id$i', DateTime(monday.year, monday.month, monday.day + i), gameSets('bench', 3)),
          ];
      final stats = statsOn(_today, _inputs([
        ...week('cur', DateTime(2026, 10, 12), 3), // bu hafta: sayılmaz
        ...week('w1', DateTime(2026, 10, 5), 3), // tuttu
        ...week('w2', DateTime(2026, 9, 28), 4), // tuttu
        ...week('w3', DateTime(2026, 9, 21), 2), // tutmadı
        ...week('old', DateTime(2026, 8, 10), 3), // 8 haftadan eski
      ]));
      expect(stats.consistency, 25);
    });

    test('two workouts on one day count as one day', () {
      final stats = statsOn(_today, _inputs([
        gameSession('a', DateTime(2026, 10, 5, 9), gameSets('bench', 3)),
        gameSession('b', DateTime(2026, 10, 5, 19), gameSets('bench', 3)),
        _session('c', DateTime(2026, 10, 6), gameSets('bench', 3)),
      ], goal: 3));
      expect(stats.consistency, 1);
    });
  });

  test('an empty history is the floor and the bonus is the stat sum over 600', () {
    final floor = statsOn(_today, _inputs(const []));
    expect((floor.strength, floor.endurance, floor.consistency), (1, 1, 1));
    const avg = BattleStats(strength: 44, endurance: 48, consistency: 50);
    expect(avg.bonus, closeTo(142 / 600, 1e-9));
    expect(avg.bonusPercent, 24);
    expect(const BattleStats(strength: 100, endurance: 100, consistency: 100).bonus, 0.5);
  });
}
