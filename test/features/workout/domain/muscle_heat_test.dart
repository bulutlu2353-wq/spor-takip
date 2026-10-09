import 'package:flutter_test/flutter_test.dart';
import 'package:spor_takip/features/workout/domain/muscle_heat.dart';

import '../heat_fixtures.dart';

void main() {
  final since7 = heatNow.subtract(const Duration(days: 7));
  final since30 = heatNow.subtract(const Duration(days: 30));

  test('heatTierFor cuts at 4, 10 and 20 sets a week', () {
    expect(heatTierFor(0), HeatTier.none);
    expect(heatTierFor(0.5), HeatTier.low);
    expect(heatTierFor(3.9), HeatTier.low);
    expect(heatTierFor(4), HeatTier.medium);
    expect(heatTierFor(9.9), HeatTier.medium);
    expect(heatTierFor(10), HeatTier.optimal);
    expect(heatTierFor(19.9), HeatTier.optimal);
    expect(heatTierFor(20), HeatTier.high);
  });

  test('muscleWeight is 1 for primary, 0.5 for secondary, else 0', () {
    expect(muscleWeight(heatBench, 'chest'), 1);
    expect(muscleWeight(heatBench, 'triceps'), 0.5);
    expect(muscleWeight(heatBench, 'quadriceps'), 0);
  });

  test('history load counts completed sets of finished sessions since the cut', () {
    // bench 3 (yarım set ve devam eden oturum sayılmaz), pushups 2; squat 20 gün önce.
    expect(historyMuscleLoad(heatSessions, heatExercisesById, since7), {'chest': 5.0, 'triceps': 1.5});
    expect(
      historyMuscleLoad(heatSessions, heatExercisesById, since30),
      {'chest': 5.0, 'triceps': 1.5, 'quadriceps': 4.0},
    );
  });

  test('program load sums planned sets of every workout', () {
    // bench 5 → chest 5, triceps 2.5; squat 5 + 0; dips 3 → triceps 3, chest 1.5.
    expect(
      programMuscleLoad(heatProgram, heatExercisesById),
      {'chest': 6.5, 'triceps': 5.5, 'quadriceps': 5.0},
    );
  });

  test('heatTiers scales to a week and drops empty muscles', () {
    final load = {'chest': 5.0, 'triceps': 1.5, 'quadriceps': 30.0, 'calves': 0.0};
    expect(heatTiers(load, days: 7), {
      'chest': HeatTier.medium,
      'triceps': HeatTier.low,
      'quadriceps': HeatTier.high,
    });
    // 30 gün → × 7/30: chest 1.17 low, quadriceps 7 medium.
    expect(heatTiers(load, days: 30), {
      'chest': HeatTier.low,
      'triceps': HeatTier.low,
      'quadriceps': HeatTier.medium,
    });
    // Program: ölçeksiz.
    expect(heatTiers({'chest': 12.0}), {'chest': HeatTier.optimal});
  });

  test('history loads for a muscle list raw set counts, most first, with the primary flag', () {
    final rows = historyLoadsForMuscle(heatSessions, heatExercisesById, since7, 'chest');
    expect([for (final r in rows) (r.exercise.id, r.sets, r.primary)], [('bench', 3, true), ('pushups', 2, true)]);

    final triceps = historyLoadsForMuscle(heatSessions, heatExercisesById, since7, 'triceps');
    expect([for (final r in triceps) (r.exercise.id, r.sets, r.primary)], [('bench', 3, false)]);

    expect(historyLoadsForMuscle(heatSessions, heatExercisesById, since7, 'quadriceps'), isEmpty);
  });

  test('program loads for a muscle use planned sets', () {
    final rows = programLoadsForMuscle(heatProgram, heatExercisesById, 'triceps');
    // bench 5 (ikincil), dips 3 (birincil).
    expect([for (final r in rows) (r.exercise.id, r.sets, r.primary)], [('bench', 5, false), ('dips', 3, true)]);

    // squat iki günde 5 + 0 → 5.
    final quads = programLoadsForMuscle(heatProgram, heatExercisesById, 'quadriceps');
    expect([for (final r in quads) (r.exercise.id, r.sets)], [('squat', 5)]);
  });

  test('equal set counts sort by exercise name', () {
    final sessions = [
      heatSession('s', heatNow, [heatSet('pushups', 0), heatSet('bench', 0)]),
    ];
    final rows = historyLoadsForMuscle(sessions, heatExercisesById, heatNow.subtract(const Duration(days: 1)), 'chest');
    expect([for (final r in rows) r.exercise.id], ['bench', 'pushups']); // "Barbell…" < "Pushups"
  });

  test('formatSets drops a zero decimal', () {
    expect(formatSets(5), '5');
    expect(formatSets(1.5), '1.5');
    expect(formatSets(6.25), '6.3');
  });
}
