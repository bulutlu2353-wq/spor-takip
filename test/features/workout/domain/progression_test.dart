import 'package:flutter_test/flutter_test.dart';
import 'package:spor_takip/features/workout/domain/exercise.dart';
import 'package:spor_takip/features/workout/domain/progression.dart';
import 'package:spor_takip/features/workout/domain/weight_calculator.dart';
import 'package:spor_takip/features/workout/domain/workout_session.dart';

SessionSet _set({
  double? weight,
  int? reps,
  int min = 5,
  int max = 5,
  bool amrap = false,
  double? pct,
  bool done = true,
  String exercise = 'Barbell_Squat',
  String? ref,
}) {
  return SessionSet(
    id: 'x',
    exercisePosition: 0,
    setIndex: 0,
    exerciseId: exercise,
    exerciseName: exercise,
    targetRepsMin: min,
    targetRepsMax: max,
    isAmrap: amrap,
    percent1rm: pct,
    percentRefExerciseId: ref,
    weightKg: weight,
    reps: reps,
    completedAt: done ? DateTime(2026, 9, 1) : null,
  );
}

List<SessionSet> _session(double weight, List<int> reps, {int min = 5, int max = 5}) =>
    [for (final r in reps) _set(weight: weight, reps: r, min: min, max: max)];

void main() {
  test('roundToPlate rounds to the nearest 2.5 kg', () {
    expect(roundToPlate(54), 55);
    expect(roundToPlate(53.7), 52.5);
    expect(roundToPlate(90), 90);
  });

  group('weightIncrementKg', () {
    test('lower-body barbell lifts go up by 5 kg', () {
      const squat = Exercise(
          id: 'Barbell_Squat', name: 'Barbell Squat', equipment: 'barbell', primaryMuscles: ['quadriceps']);
      const deadlift = Exercise(
          id: 'Barbell_Deadlift', name: 'Barbell Deadlift', equipment: 'barbell', primaryMuscles: ['lower back']);
      expect(weightIncrementKg(squat), 5);
      expect(weightIncrementKg(deadlift), 5);
    });

    test('everything else goes up by 2.5 kg', () {
      const bench = Exercise(id: 'Bench', name: 'Bench', equipment: 'barbell', primaryMuscles: ['chest']);
      const legPress =
          Exercise(id: 'Leg_Press', name: 'Leg Press', equipment: 'machine', primaryMuscles: ['quadriceps']);
      expect(weightIncrementKg(bench), 2.5);
      expect(weightIncrementKg(legPress), 2.5);
      expect(weightIncrementKg(null), 2.5);
    });
  });

  group('suggestWeight', () {
    test('no history → empty', () {
      expect(suggestWeight(history: const [], incrementKg: 2.5).weightKg, isNull);
    });

    test('history without weights (bodyweight) → empty', () {
      expect(suggestWeight(history: [[_set(reps: 10, min: 8, max: 12)]], incrementKg: 2.5).weightKg, isNull);
    });

    test('every set at the top of the range → increase', () {
      final s = suggestWeight(history: [_session(60, [5, 5, 5, 5, 5])], incrementKg: 5);
      expect(s.weightKg, 65);
      expect(s.deloaded, isFalse);
    });

    test('rep range needs repsMax on every set', () {
      expect(suggestWeight(history: [_session(40, [12, 12, 12], min: 8, max: 12)], incrementKg: 2.5).weightKg, 42.5);
      expect(suggestWeight(history: [_session(40, [12, 12, 10], min: 8, max: 12)], incrementKg: 2.5).weightKg, 40);
    });

    test('an unfinished set counts as a miss', () {
      final sets = [..._session(60, [5, 5, 5, 5]), _set(weight: 60, done: false)];
      expect(suggestWeight(history: [sets], incrementKg: 5).weightKg, 60);
    });

    test('reference is the heaviest completed set', () {
      final sets = [_set(weight: 50, reps: 5), _set(weight: 60, reps: 5)];
      expect(suggestWeight(history: [sets], incrementKg: 2.5).weightKg, 62.5);
    });

    test('three failed sessions at the same weight → 10% deload rounded to 2.5 kg', () {
      final failed = _session(60, [5, 5, 4]);
      final s = suggestWeight(history: [failed, failed, failed], incrementKg: 5);
      expect(s.weightKg, 55);
      expect(s.deloaded, isTrue);
    });

    test('two failures are not enough to deload', () {
      final failed = _session(60, [5, 5, 4]);
      expect(suggestWeight(history: [failed, failed, _session(57.5, [5, 5, 5])], incrementKg: 2.5).weightKg, 60);
    });

    test('after a deload one failure keeps the lower weight', () {
      final history = [_session(55, [5, 4]), _session(60, [4]), _session(60, [4])];
      expect(suggestWeight(history: history, incrementKg: 5).weightKg, 55);
    });

    test('percentage-based sets are ignored', () {
      final history = [
        [_set(weight: 100, reps: 5, pct: 85)],
        _session(60, [5]),
      ];
      expect(suggestWeight(history: history, incrementKg: 5).weightKg, 65);
    });
  });

  group('oneRepMaxSuggestions', () {
    List<SessionSet> amrap(int reps, {double pct = 85, int min = 5, String exercise = 'Barbell_Squat', String? ref}) =>
        [_set(weight: 85, reps: reps, min: min, max: min, amrap: true, pct: pct, exercise: exercise, ref: ref)];

    double? suggested(List<SessionSet> sets) {
      final result = oneRepMaxSuggestions(sets: sets, oneRepMaxes: {'Barbell_Squat': 100});
      return result.isEmpty ? null : result.single.suggestedKg;
    }

    test('5+ set: below target −10%, on target none, then +2.5 / +5 / +7.5', () {
      expect(suggested(amrap(4)), 90);
      expect(suggested(amrap(5)), isNull);
      expect(suggested(amrap(6)), 102.5);
      expect(suggested(amrap(7)), 102.5);
      expect(suggested(amrap(8)), 105);
      expect(suggested(amrap(9)), 105);
      expect(suggested(amrap(10)), 107.5);
      expect(suggested(amrap(15)), 107.5);
    });

    test('nSuns 1+ set matches the source table', () {
      expect(suggested(amrap(0, min: 1, pct: 95)), 90);
      expect(suggested(amrap(1, min: 1, pct: 95)), isNull);
      expect(suggested(amrap(3, min: 1, pct: 95)), 102.5);
      expect(suggested(amrap(5, min: 1, pct: 95)), 105);
      expect(suggested(amrap(6, min: 1, pct: 95)), 107.5);
    });

    test('uses the highest-percentage AMRAP set of each lift', () {
      expect(suggested([...amrap(12, pct: 65), ...amrap(5, pct: 95)]), isNull);
    });

    test('percent_ref lifts are credited to the referenced 1RM', () {
      final result = oneRepMaxSuggestions(
        sets: amrap(8, exercise: 'Sumo_Deadlift', ref: 'Barbell_Deadlift'),
        oneRepMaxes: {'Barbell_Deadlift': 140},
      );
      expect(result.single.exerciseId, 'Barbell_Deadlift');
      expect(result.single.currentKg, 140);
      expect(result.single.suggestedKg, 145);
    });

    test('nothing without a stored 1RM, for unfinished sets or non-AMRAP sets', () {
      expect(oneRepMaxSuggestions(sets: amrap(8), oneRepMaxes: const {}), isEmpty);
      expect(suggested([_set(weight: 85, reps: 8, amrap: true, pct: 85, done: false)]), isNull);
      expect(suggested([_set(weight: 85, reps: 8, pct: 85)]), isNull);
    });
  });
}
