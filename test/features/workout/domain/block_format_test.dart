import 'package:flutter_test/flutter_test.dart';
import 'package:spor_takip/features/workout/domain/block_format.dart';
import 'package:spor_takip/features/workout/domain/workout_exercise.dart';
import 'package:spor_takip/features/workout/domain/workout_session.dart';

WorkoutExercise _b({int sets = 1, int min = 5, int max = 5, bool amrap = false, double? pct}) =>
    WorkoutExercise(
      exerciseId: 'x',
      exerciseName: 'X',
      sets: sets,
      repsMin: min,
      repsMax: max,
      isAmrap: amrap,
      percent1rm: pct,
    );

void main() {
  test('setsRepsLabel', () {
    expect(setsRepsLabel(_b(sets: 5)), '5 × 5');
    expect(setsRepsLabel(_b(sets: 3, min: 8, max: 12)), '3 × 8–12');
    expect(setsRepsLabel(_b(amrap: true)), '1 × 5+');
  });

  test('loadLabel', () {
    expect(loadLabel(_b(), 100), isNull);
    expect(loadLabel(_b(pct: 76.5), null), '%76.5');
    expect(loadLabel(_b(pct: 45), null), '%45');
    expect(loadLabel(_b(pct: 76.5), 100), '77.5 kg');
    expect(loadLabel(_b(pct: 50), 60), '30 kg');
  });

  test('trimNumber drops a trailing .0', () {
    expect(trimNumber(60), '60');
    expect(trimNumber(57.5), '57.5');
  });

  test('sessionSetTargetLabel', () {
    SessionSet target({int min = 5, int max = 5, bool amrap = false, double? pct}) => SessionSet(
          exercisePosition: 0,
          setIndex: 0,
          exerciseId: 'x',
          exerciseName: 'x',
          targetRepsMin: min,
          targetRepsMax: max,
          isAmrap: amrap,
          percent1rm: pct,
        );
    expect(sessionSetTargetLabel(target()), '5');
    expect(sessionSetTargetLabel(target(min: 8, max: 12)), '8–12');
    expect(sessionSetTargetLabel(target(amrap: true, pct: 85)), '5+ · %85');
    expect(sessionSetTargetLabel(target(pct: 76.5)), '5 · %76.5');
  });
}
