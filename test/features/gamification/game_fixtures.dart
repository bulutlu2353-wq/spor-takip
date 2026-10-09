import 'package:spor_takip/features/workout/domain/exercise.dart';
import 'package:spor_takip/features/workout/domain/workout_session.dart';

const gameBench = Exercise(
  id: 'bench',
  name: 'Barbell Bench Press',
  primaryMuscles: ['chest'],
  secondaryMuscles: ['triceps'],
);
const gameSquat = Exercise(id: 'squat', name: 'Barbell Squat', primaryMuscles: ['quadriceps']);
final gameExercisesById = {gameBench.id: gameBench, gameSquat.id: gameSquat};

SessionSet gameSet(String exerciseId, {double? kg, int? reps, bool done = true, int index = 0}) => SessionSet(
      exercisePosition: 0,
      setIndex: index,
      exerciseId: exerciseId,
      exerciseName: exerciseId == 'bench' ? 'Barbell Bench Press' : 'Barbell Squat',
      targetRepsMin: 5,
      targetRepsMax: 5,
      weightKg: kg,
      reps: reps,
      completedAt: done ? DateTime(2026, 10, 1) : null,
    );

/// [finishedAt] null → devam eden oturum. Tarihler yerel.
WorkoutSession gameSession(String id, DateTime? finishedAt, List<SessionSet> sets, {String workoutName = 'Push A'}) =>
    WorkoutSession(
      id: id,
      programName: 'P',
      workoutName: workoutName,
      workoutPosition: 0,
      startedAt: (finishedAt ?? DateTime(2026, 10, 1)).subtract(const Duration(hours: 1)),
      finishedAt: finishedAt,
      sets: sets,
    );

/// [count] tamamlanmış set.
List<SessionSet> gameSets(String exerciseId, int count, {double? kg, int? reps}) =>
    [for (var i = 0; i < count; i++) gameSet(exerciseId, kg: kg, reps: reps, index: i)];
