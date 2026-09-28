import 'package:flutter_test/flutter_test.dart';
import 'package:spor_takip/features/progress/domain/body_weight_log.dart';
import 'package:spor_takip/features/progress/domain/weekly_summary.dart';

import '../fixtures.dart';

final _now = DateTime(2026, 9, 30, 12); // Çarşamba

void main() {
  test('startOfWeek is Monday 00:00 in local time', () {
    expect(startOfWeek(_now), DateTime(2026, 9, 28));
    expect(startOfWeek(DateTime(2026, 9, 28)), DateTime(2026, 9, 28));
    expect(startOfWeek(DateTime(2026, 9, 27, 23, 59)), DateTime(2026, 9, 21));
    expect(startOfWeek(DateTime(2026, 10, 4, 22)), DateTime(2026, 9, 28));
  });

  test('workouts, sets and volume count finished sessions by their finish time', () {
    final summary = weeklySummary(
      now: _now,
      sessions: [
        // Pazartesi 00:00 tam sınır → bu hafta
        finishedSession('a', DateTime(2026, 9, 28), [
          doneSet('squat', kg: 100, reps: 5),
          doneSet('squat', kg: 100, reps: 5, setIndex: 1),
          doneSet('squat', kg: 100, reps: 5, setIndex: 2, done: false),
        ]),
        // Pazar 23:59 → geçen hafta
        finishedSession('b', DateTime(2026, 9, 27, 23, 59), [doneSet('bench', kg: 60, reps: 10)]),
        // iki hafta önce → hiçbiri
        finishedSession('c', DateTime(2026, 9, 20), [doneSet('bench')]),
        // devam ediyor → sayılmaz
        finishedSession('d', null, [doneSet('bench')]),
      ],
      meals: const [],
      weights: const [],
    );
    expect(summary.weekStart, DateTime(2026, 9, 28));
    expect(summary.thisWeek.workouts, 1);
    expect(summary.thisWeek.sets, 2);
    expect(summary.thisWeek.volumeKg, 1000);
    expect(summary.lastWeek.workouts, 1);
    expect(summary.lastWeek.sets, 1);
    expect(summary.lastWeek.volumeKg, 600);
  });

  test('nutrition averages only over days with at least one meal', () {
    final summary = weeklySummary(
      now: _now,
      sessions: const [],
      meals: [
        testMeal(DateTime(2026, 9, 28, 8), calories: 1000, proteinG: 50),
        testMeal(DateTime(2026, 9, 28, 19), calories: 800, proteinG: 40),
        testMeal(DateTime(2026, 9, 29, 13), calories: 2200, proteinG: 110),
        testMeal(DateTime(2026, 9, 22, 13), calories: 1500, proteinG: 60),
      ],
      weights: const [],
    );
    expect(summary.thisWeek.nutritionDays, 2);
    expect(summary.thisWeek.avgCalories, 2000); // (1800 + 2200) / 2
    expect(summary.thisWeek.avgProteinG, 100); // (90 + 110) / 2
    expect(summary.lastWeek.nutritionDays, 1);
    expect(summary.lastWeek.avgCalories, 1500);
  });

  test('weight change is last entry of this week minus last entry of last week', () {
    final summary = weeklySummary(
      now: _now,
      sessions: const [],
      meals: const [],
      weights: [
        BodyWeightLog(date: DateTime(2026, 9, 29), weightKg: 80),
        BodyWeightLog(date: DateTime(2026, 9, 22), weightKg: 81),
        BodyWeightLog(date: DateTime(2026, 9, 26), weightKg: 80.5),
      ],
    );
    expect(summary.thisWeek.lastWeightKg, 80);
    expect(summary.lastWeek.lastWeightKg, 80.5);
    expect(summary.weightChangeKg, -0.5);
  });

  test('empty weeks have no averages and no weight change', () {
    final summary = weeklySummary(
      now: _now,
      sessions: const [],
      meals: const [],
      weights: [BodyWeightLog(date: DateTime(2026, 9, 29), weightKg: 80)],
    );
    expect(summary.thisWeek.avgCalories, isNull);
    expect(summary.thisWeek.avgProteinG, isNull);
    expect(summary.weightChangeKg, isNull);
    expect(summary.lastWeek.isEmpty, isTrue);
    expect(summary.isEmpty, isFalse);
    expect(
      weeklySummary(now: _now, sessions: const [], meals: const [], weights: const []).isEmpty,
      isTrue,
    );
  });
}
