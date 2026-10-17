import 'package:flutter_test/flutter_test.dart';
import 'package:spor_takip/features/gamification/domain/fair_play.dart';
import 'package:spor_takip/features/gamification/domain/game_settings.dart';
import 'package:spor_takip/features/gamification/domain/streak.dart';

import '../game_fixtures.dart';

/// Her gün 18:00'de 3 setlik (sayılan) antrenman.
List<SessionVerdict> _verdicts(List<DateTime> days) => judgeSessions([
      for (final (i, d) in days.indexed) gameSession('s$i', DateTime(d.year, d.month, d.day, 18), gameSets('bench', 3)),
    ]);

/// "w1 r2 b0 p0" biçimi.
String _kinds(List<StreakDay> days) => days.map((d) => '${d.kind.name[0]}${d.length}').join(' ');

void main() {
  group('weeklyGoalFor', () {
    test('prefers the program, then the profile, then 3', () {
      expect(weeklyGoalFor(programDays: 5, profileDays: 3), 5);
      expect(weeklyGoalFor(profileDays: 4), 4);
      expect(weeklyGoalFor(), 3);
    });

    test('clamps to 2..6', () {
      expect(weeklyGoalFor(programDays: 1), 2);
      expect(weeklyGoalFor(programDays: 7), 6);
    });
  });

  group('streakDays', () {
    // 5 Ekim 2026 pazartesi.
    test('workouts and rest days extend the streak; running out of rest breaks it', () {
      final days = streakDays(
        _verdicts([DateTime(2026, 10, 5), DateTime(2026, 10, 6), DateTime(2026, 10, 10)]),
        weeklyGoal: 5,
        today: DateTime(2026, 10, 11, 9),
      );
      expect(_kinds(days), 'w1 w2 r3 r4 b0 w1 p1');
      expect(days.first.day, DateTime(2026, 10, 5));
    });

    test('rest allowance renews every ISO week', () {
      final days = streakDays(
        _verdicts([DateTime(2026, 10, 10), DateTime(2026, 10, 12), DateTime(2026, 10, 14)]),
        weeklyGoal: 6,
        today: DateTime(2026, 10, 15, 9),
      );
      expect(_kinds(days), 'w1 r2 w3 r4 w5 p5');
    });

    test('days without a workout while the streak is 0 stay broken and use no rest', () {
      final days = streakDays(
        _verdicts([DateTime(2026, 10, 5), DateTime(2026, 10, 13)]),
        weeklyGoal: 5,
        today: DateTime(2026, 10, 17, 9),
      );
      expect(_kinds(days), 'w1 r2 r3 b0 b0 b0 b0 b0 w1 r2 r3 b0 p0');
    });

    test('ignores sessions that do not count and merges two workouts on one day', () {
      final verdicts = judgeSessions([
        gameSession('small', DateTime(2026, 10, 5, 9), gameSets('bench', 2)),
        gameSession('a', DateTime(2026, 10, 6, 9), gameSets('bench', 3)),
        gameSession('b', DateTime(2026, 10, 6, 19), gameSets('bench', 3)),
      ]);
      expect(_kinds(streakDays(verdicts, weeklyGoal: 3, today: DateTime(2026, 10, 6, 20))), 'w1');
    });

    test('no workouts → empty', () {
      expect(streakDays(const [], weeklyGoal: 3, today: DateTime(2026, 10, 6)), isEmpty);
    });
  });

  test('workoutStreakLengths maps each workout day to its streak length', () {
    final lengths = workoutStreakLengths(
      _verdicts([DateTime(2026, 10, 5), DateTime(2026, 10, 6), DateTime(2026, 10, 10)]),
      weeklyGoal: 5,
    );
    expect(lengths, {DateTime(2026, 10, 5): 1, DateTime(2026, 10, 6): 2, DateTime(2026, 10, 10): 1});
  });

  test('bonus percent steps by 5 every 7 days up to 25', () {
    expect([0, 6, 7, 13, 14, 35, 70].map(streakBonusPercent), [0, 0, 5, 5, 10, 25, 25]);
  });

  group('streakStatus', () {
    test('pending today shows yesterday and this week\'s rest left', () {
      final status = streakStatus(
        _verdicts([DateTime(2026, 10, 5), DateTime(2026, 10, 6), DateTime(2026, 10, 10)]),
        weeklyGoal: 5,
        today: DateTime(2026, 10, 11, 9),
      );
      expect((status.length, status.bonusPercent, status.restLeft, status.broken), (1, 0, 0, false));
    });

    test('a workout today counts today', () {
      final status = streakStatus(
        _verdicts([for (var d = 1; d <= 14; d++) DateTime(2026, 10, d)]),
        weeklyGoal: 4,
        today: DateTime(2026, 10, 14, 20),
      );
      expect((status.length, status.bonusPercent, status.restLeft, status.broken), (14, 10, 3, false));
    });

    test('broken yesterday → broken', () {
      final status = streakStatus(
        _verdicts([DateTime(2026, 10, 5), DateTime(2026, 10, 13)]),
        weeklyGoal: 5,
        today: DateTime(2026, 10, 17, 9),
      );
      expect((status.length, status.restLeft, status.broken), (0, 0, true));
    });

    test('no workouts → broken with the full rest allowance', () {
      final status = streakStatus(const [], weeklyGoal: 4, today: DateTime(2026, 10, 17));
      expect((status.length, status.restLeft, status.broken), (0, 3, true));
    });
  });
}
