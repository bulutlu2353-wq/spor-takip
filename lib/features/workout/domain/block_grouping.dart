import 'workout_exercise.dart';

class ExerciseGroup {
  const ExerciseGroup({required this.exerciseId, required this.exerciseName, required this.blocks});

  final String exerciseId;
  final String exerciseName;
  final List<WorkoutExercise> blocks;
}

/// Art arda gelen aynı hareketli blokları tek başlık altında toplar
/// (5/3/1: %65×5, %75×5, %85×5+ → "Squat" altında üç satır).
List<ExerciseGroup> groupBlocks(List<WorkoutExercise> blocks) {
  final groups = <ExerciseGroup>[];
  for (final block in blocks) {
    if (groups.isNotEmpty && groups.last.exerciseId == block.exerciseId) {
      groups.last.blocks.add(block);
    } else {
      groups.add(ExerciseGroup(
        exerciseId: block.exerciseId,
        exerciseName: block.exerciseName,
        blocks: [block],
      ));
    }
  }
  return groups;
}
