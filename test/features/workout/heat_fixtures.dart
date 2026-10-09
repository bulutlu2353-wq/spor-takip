import 'package:spor_takip/features/workout/domain/exercise.dart';
import 'package:spor_takip/features/workout/domain/program.dart';
import 'package:spor_takip/features/workout/domain/program_workout.dart';
import 'package:spor_takip/features/workout/domain/schedule_mode.dart';
import 'package:spor_takip/features/workout/domain/workout_exercise.dart';
import 'package:spor_takip/features/workout/domain/workout_session.dart';

/// Isı testlerinin "şimdi"si.
final heatNow = DateTime(2026, 10, 9, 12);

const heatBench = Exercise(
  id: 'bench',
  name: 'Barbell Bench Press',
  equipment: 'barbell',
  primaryMuscles: ['chest'],
  secondaryMuscles: ['triceps'],
);
const heatPushups = Exercise(id: 'pushups', name: 'Pushups', equipment: 'body only', primaryMuscles: ['chest']);
const heatDips = Exercise(id: 'dips', name: 'Dips', primaryMuscles: ['triceps'], secondaryMuscles: ['chest']);
const heatSquat = Exercise(id: 'squat', name: 'Squat', primaryMuscles: ['quadriceps']);
const heatExercises = [heatBench, heatPushups, heatDips, heatSquat];
final heatExercisesById = {for (final e in heatExercises) e.id: e};

SessionSet heatSet(String exerciseId, int index, {bool done = true}) => SessionSet(
      exercisePosition: 0,
      setIndex: index,
      exerciseId: exerciseId,
      exerciseName: exerciseId,
      targetRepsMin: 5,
      targetRepsMax: 5,
      completedAt: done ? DateTime(2026, 10, 1) : null,
    );

WorkoutSession heatSession(String id, DateTime? finishedAt, List<SessionSet> sets) => WorkoutSession(
      id: id,
      programName: 'P',
      workoutName: 'A',
      workoutPosition: 0,
      startedAt: (finishedAt ?? heatNow).subtract(const Duration(hours: 1)),
      finishedAt: finishedAt,
      sets: sets,
    );

/// 2 gün önce: bench 3 tamam + 1 yarım, pushups 2, silinmiş hareket 1.
/// 20 gün önce: squat 4. Devam eden oturum: bench 5 (sayılmaz).
final heatSessions = [
  heatSession('recent', heatNow.subtract(const Duration(days: 2)), [
    heatSet('bench', 0),
    heatSet('bench', 1),
    heatSet('bench', 2),
    heatSet('bench', 3, done: false),
    heatSet('pushups', 0),
    heatSet('pushups', 1),
    heatSet('deleted', 0),
  ]),
  heatSession('old', heatNow.subtract(const Duration(days: 20)), [
    for (var i = 0; i < 4; i++) heatSet('squat', i),
  ]),
  heatSession('live', null, [for (var i = 0; i < 5; i++) heatSet('bench', i)]),
];

WorkoutExercise _block(Exercise e, int sets) =>
    WorkoutExercise(exerciseId: e.id, exerciseName: e.name, sets: sets, repsMin: 5, repsMax: 5);

/// A: bench 5 + squat 5, B: dips 3 + squat 0 (katkısız).
final heatProgram = Program(
  id: 'prog',
  name: '5x5',
  scheduleMode: ScheduleMode.rotation,
  workouts: [
    ProgramWorkout(name: 'A', exercises: [_block(heatBench, 5), _block(heatSquat, 5)]),
    ProgramWorkout(name: 'B', exercises: [_block(heatDips, 3), _block(heatSquat, 0)]),
  ],
);
