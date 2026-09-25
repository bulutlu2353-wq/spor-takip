import 'package:flutter_test/flutter_test.dart';
import 'package:spor_takip/features/workout/domain/block_grouping.dart';
import 'package:spor_takip/features/workout/domain/workout_exercise.dart';

WorkoutExercise _b(String id, {int reps = 5}) =>
    WorkoutExercise(exerciseId: id, exerciseName: id.toUpperCase(), sets: 1, repsMin: reps, repsMax: reps);

void main() {
  test('merges consecutive blocks of the same exercise', () {
    final groups = groupBlocks([_b('squat', reps: 5), _b('squat', reps: 3), _b('bench'), _b('squat')]);
    expect(groups.map((g) => g.exerciseId), ['squat', 'bench', 'squat']);
    expect(groups.first.blocks.map((b) => b.repsMin), [5, 3]);
    expect(groups.first.exerciseName, 'SQUAT');
  });

  test('empty input gives empty output', () {
    expect(groupBlocks(const []), isEmpty);
  });
}
