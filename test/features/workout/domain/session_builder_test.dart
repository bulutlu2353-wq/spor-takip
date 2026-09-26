import 'package:flutter_test/flutter_test.dart';
import 'package:spor_takip/features/workout/domain/exercise.dart';
import 'package:spor_takip/features/workout/domain/program_workout.dart';
import 'package:spor_takip/features/workout/domain/session_builder.dart';
import 'package:spor_takip/features/workout/domain/workout_exercise.dart';
import 'package:spor_takip/features/workout/domain/workout_session.dart';

const _squat = Exercise(
    id: 'Barbell_Squat', name: 'Barbell Squat', equipment: 'barbell', primaryMuscles: ['quadriceps']);
const _bench = Exercise(id: 'Bench', name: 'Bench Press', equipment: 'barbell', primaryMuscles: ['chest']);
const _exercises = {'Barbell_Squat': _squat, 'Bench': _bench};

const _squatBlock = WorkoutExercise(
  exerciseId: 'Barbell_Squat',
  exerciseName: 'Barbell Squat',
  sets: 3,
  repsMin: 5,
  repsMax: 5,
  restSeconds: 180,
);
const _curl = WorkoutExercise(
  exerciseId: 'Barbell_Curl',
  exerciseName: 'Barbell Curl',
  sets: 2,
  repsMin: 8,
  repsMax: 12,
);
const _pct65 = WorkoutExercise(
  exerciseId: 'Barbell_Squat',
  exerciseName: 'Barbell Squat',
  sets: 1,
  repsMin: 5,
  repsMax: 5,
  percent1rm: 58.5,
);
const _pct85 = WorkoutExercise(
  exerciseId: 'Barbell_Squat',
  exerciseName: 'Barbell Squat',
  sets: 1,
  repsMin: 5,
  repsMax: 5,
  isAmrap: true,
  percent1rm: 76.5,
);
const _sumo = WorkoutExercise(
  exerciseId: 'Sumo_Deadlift',
  exerciseName: 'Sumo Deadlift',
  sets: 1,
  repsMin: 5,
  repsMax: 5,
  percent1rm: 50,
  percentRefExerciseId: 'Barbell_Deadlift',
);

SessionSet _done(String exercise, double weight, int reps, {int max = 5}) => SessionSet(
      id: 'h',
      exercisePosition: 0,
      setIndex: 0,
      exerciseId: exercise,
      exerciseName: exercise,
      targetRepsMin: 5,
      targetRepsMax: max,
      weightKg: weight,
      reps: reps,
      completedAt: DateTime(2026, 9, 1),
    );

List<SessionSet> _build(List<WorkoutExercise> blocks,
    {Map<String, double> oneRepMaxes = const {}, ExerciseHistory history = const {}}) {
  return buildSessionSets(
    workout: ProgramWorkout(name: 'A', exercises: blocks),
    oneRepMaxes: oneRepMaxes,
    history: history,
    exercises: _exercises,
  );
}

void main() {
  test('expands blocks into sets; one exercise position per lift', () {
    final sets = _build([_squatBlock, _curl]);
    expect(sets.map((s) => s.exercisePosition), [0, 0, 0, 1, 1]);
    expect(sets.map((s) => s.setIndex), [0, 1, 2, 0, 1]);
    expect(sets.first.restSeconds, 180);
    expect(sets.first.exerciseName, 'Barbell Squat');
    expect(sets.last.targetRepsMin, 8);
    expect(sets.last.targetRepsMax, 12);
    expect(sets.every((s) => s.id == null && !s.isCompleted), isTrue);
  });

  test('consecutive percentage blocks of one lift share a position and number on', () {
    final sets = _build([_pct65, _pct85], oneRepMaxes: {'Barbell_Squat': 100});
    expect(sets.map((s) => s.exercisePosition), [0, 0]);
    expect(sets.map((s) => s.setIndex), [0, 1]);
    expect(sets.map((s) => s.suggestedWeightKg), [57.5, 77.5]);
    expect(sets[1].isAmrap, isTrue);
    expect(sets[1].percent1rm, 76.5);
  });

  test('percent_ref uses the referenced 1RM; no 1RM → no suggestion', () {
    expect(_build([_sumo], oneRepMaxes: {'Barbell_Deadlift': 200}).single.suggestedWeightKg, 100);
    expect(_build([_sumo]).single.suggestedWeightKg, isNull);
    expect(_build([_sumo]).single.percentRefExerciseId, 'Barbell_Deadlift');
  });

  test('plain blocks use progression from history', () {
    final history = {
      'Barbell_Squat': [
        [_done('Barbell_Squat', 60, 5), _done('Barbell_Squat', 60, 5), _done('Barbell_Squat', 60, 5)],
      ],
    };
    final sets = _build([_squatBlock], history: history);
    expect(sets.map((s) => s.suggestedWeightKg), [65, 65, 65]);
    expect(sets.any((s) => s.deloaded), isFalse);
  });

  test('deload is flagged on every set of the lift', () {
    final failed = [_done('Barbell_Squat', 60, 4)];
    final sets = _build([_squatBlock], history: {
      'Barbell_Squat': [failed, failed, failed],
    });
    expect(sets.map((s) => s.suggestedWeightKg), [55, 55, 55]);
    expect(sets.every((s) => s.deloaded), isTrue);
  });

  test('groupExerciseHistory keeps newest-first order per exercise', () {
    WorkoutSession session(String id, List<SessionSet> sets) => WorkoutSession(
          id: id,
          programName: 'P',
          workoutName: 'A',
          workoutPosition: 0,
          startedAt: DateTime(2026, 9, 1),
          finishedAt: DateTime(2026, 9, 1, 1),
          sets: sets,
        );
    final history = groupExerciseHistory([
      session('new', [_done('Barbell_Squat', 65, 5), _done('Bench', 40, 5)]),
      session('old', [_done('Barbell_Squat', 60, 5)]),
    ]);
    expect(history['Barbell_Squat']!.map((sets) => sets.single.weightKg), [65, 60]);
    expect(history['Bench']!.length, 1);
  });

  test('an added exercise gets 3 × 8–12 with 90 s rest and a suggestion', () {
    final sets = buildAddedExerciseSets(
      exercise: _bench,
      exercisePosition: 4,
      history: {
        'Bench': [
          [_done('Bench', 40, 12, max: 12), _done('Bench', 40, 12, max: 12)],
        ],
      },
      exercises: _exercises,
    );
    expect(sets.length, 3);
    expect(sets.map((s) => s.exercisePosition).toSet(), {4});
    expect(sets.map((s) => s.setIndex), [0, 1, 2]);
    expect(sets.first.exerciseName, 'Bench Press');
    expect(sets.first.targetRepsMin, 8);
    expect(sets.first.targetRepsMax, 12);
    expect(sets.first.restSeconds, 90);
    expect(sets.first.suggestedWeightKg, 42.5);
  });
}
