import 'block_grouping.dart';
import 'exercise.dart';
import 'program_workout.dart';
import 'progression.dart';
import 'weight_calculator.dart';
import 'workout_session.dart';

/// exerciseId → hareketin geçtiği her bitmiş oturumdaki setleri, yeniden eskiye.
typedef ExerciseHistory = Map<String, List<List<SessionSet>>>;

const _addedSets = 3;
const _addedRepsMin = 8;
const _addedRepsMax = 12;
const _addedRestSeconds = 90;

ExerciseHistory groupExerciseHistory(List<WorkoutSession> sessionsNewestFirst) {
  final history = <String, List<List<SessionSet>>>{};
  for (final session in sessionsNewestFirst) {
    final byExercise = <String, List<SessionSet>>{};
    for (final set in session.sets) {
      (byExercise[set.exerciseId] ??= []).add(set);
    }
    byExercise.forEach((exerciseId, sets) => (history[exerciseId] ??= []).add(sets));
  }
  return history;
}

WeightSuggestion _suggestion(String exerciseId, ExerciseHistory history, Map<String, Exercise> exercises) {
  return suggestWeight(
    history: history[exerciseId] ?? const [],
    incrementKg: weightIncrementKg(exercises[exerciseId]),
  );
}

/// Programdaki antrenmanın her bloğunun her seti için bir [SessionSet].
/// Art arda aynı hareketli bloklar tek `exercisePosition` altında toplanır.
List<SessionSet> buildSessionSets({
  required ProgramWorkout workout,
  required Map<String, double> oneRepMaxes,
  required ExerciseHistory history,
  required Map<String, Exercise> exercises,
}) {
  final sets = <SessionSet>[];
  for (final (position, group) in groupBlocks(workout.exercises).indexed) {
    final plain = _suggestion(group.exerciseId, history, exercises);
    var setIndex = 0;
    for (final block in group.blocks) {
      final pct = block.percent1rm;
      final weight = pct == null
          ? plain.weightKg
          : targetWeightKg(oneRepMaxKg: oneRepMaxes[block.oneRepMaxExerciseId], percent1rm: pct);
      for (var i = 0; i < block.sets; i++) {
        sets.add(SessionSet(
          exercisePosition: position,
          setIndex: setIndex++,
          exerciseId: block.exerciseId,
          exerciseName: block.exerciseName,
          targetRepsMin: block.repsMin,
          targetRepsMax: block.repsMax,
          isAmrap: block.isAmrap,
          percent1rm: pct,
          percentRefExerciseId: block.percentRefExerciseId,
          restSeconds: block.restSeconds,
          suggestedWeightKg: weight,
          deloaded: pct == null && plain.deloaded,
        ));
      }
    }
  }
  return sets;
}

/// Antrenman sırasında eklenen hareket: 3 set × 8–12, 90 sn dinlenme.
List<SessionSet> buildAddedExerciseSets({
  required Exercise exercise,
  required int exercisePosition,
  required ExerciseHistory history,
  required Map<String, Exercise> exercises,
}) {
  final suggestion = _suggestion(exercise.id, history, exercises);
  return [
    for (var i = 0; i < _addedSets; i++)
      SessionSet(
        exercisePosition: exercisePosition,
        setIndex: i,
        exerciseId: exercise.id,
        exerciseName: exercise.name,
        targetRepsMin: _addedRepsMin,
        targetRepsMax: _addedRepsMax,
        restSeconds: _addedRestSeconds,
        suggestedWeightKg: suggestion.weightKg,
        deloaded: suggestion.deloaded,
      ),
  ];
}
