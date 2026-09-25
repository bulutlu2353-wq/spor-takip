import 'package:flutter_test/flutter_test.dart';
import 'package:spor_takip/features/workout/domain/exercise.dart';
import 'package:spor_takip/features/workout/domain/exercise_images.dart';
import 'package:spor_takip/features/workout/domain/program.dart';
import 'package:spor_takip/features/workout/domain/program_level.dart';
import 'package:spor_takip/features/workout/domain/program_workout.dart';
import 'package:spor_takip/features/workout/domain/schedule_mode.dart';
import 'package:spor_takip/features/workout/domain/workout_exercise.dart';

Map<String, dynamic> _blockRow({
  required int position,
  String exerciseId = 'Barbell_Squat',
  String name = 'Barbell Squat',
  num? percent,
  String? ref,
}) =>
    {
      'position': position,
      'exercise_id': exerciseId,
      'sets': 5,
      'reps_min': 5,
      'reps_max': 5,
      'is_amrap': false,
      'percent_1rm': percent,
      'percent_ref_exercise_id': ref,
      'rest_seconds': 180,
      'notes': null,
      'exercises': {'name': name},
    };

void main() {
  test('ScheduleMode and ProgramLevel round-trip through db strings', () {
    for (final mode in ScheduleMode.values) {
      expect(scheduleModeFromDb(scheduleModeToDb(mode)), mode);
    }
    expect(programLevelFromDb('advanced'), ProgramLevel.advanced);
    expect(programLevelFromDb(null), isNull);
    expect(programLevelToDb(ProgramLevel.beginner), 'beginner');
  });

  test('Exercise.fromJson reads arrays, builds pinned image urls and flags custom exercises', () {
    final e = Exercise.fromJson({
      'id': 'Barbell_Squat',
      'user_id': null,
      'name': 'Barbell Squat',
      'category': 'strength',
      'equipment': 'barbell',
      'level': 'beginner',
      'primary_muscles': ['quadriceps'],
      'secondary_muscles': ['glutes'],
      'instructions': ['Step 1'],
      'images': ['Barbell_Squat/0.jpg'],
    });
    expect(e.isCustom, isFalse);
    expect(e.primaryMuscles, ['quadriceps']);
    expect(e.imageUrls, ['${exerciseImageBaseUrl}Barbell_Squat/0.jpg']);
    expect(exerciseImageBaseUrl, contains('a859101d633a01c4a1a920d6a8ce41dabba0705f'));

    final custom = Exercise.fromJson({'id': 'x', 'user_id': 'u1', 'name': 'My move'});
    expect(custom.isCustom, isTrue);
    expect(custom.images, isEmpty);
  });

  test('WorkoutExercise.fromJson reads the joined exercise name and toJson omits it', () {
    final block = WorkoutExercise.fromJson(_blockRow(position: 0, percent: 76.5, ref: 'Barbell_Deadlift'));
    expect(block.exerciseName, 'Barbell Squat');
    expect(block.percent1rm, 76.5);
    expect(block.oneRepMaxExerciseId, 'Barbell_Deadlift');
    expect(block.toJson(), {
      'exercise_id': 'Barbell_Squat',
      'sets': 5,
      'reps_min': 5,
      'reps_max': 5,
      'is_amrap': false,
      'percent_1rm': 76.5,
      'percent_ref_exercise_id': 'Barbell_Deadlift',
      'rest_seconds': 180,
      'notes': null,
    });
    expect(WorkoutExercise.fromJson(_blockRow(position: 0)).oneRepMaxExerciseId, 'Barbell_Squat');
    expect(block.copyWith(clearPercent1rm: true).percent1rm, isNull);
  });

  test('Program.fromJson sorts nested workouts and blocks by position', () {
    final program = Program.fromJson({
      'id': 'p1',
      'user_id': null,
      'name': 'StrongLifts 5x5',
      'description': 'd',
      'level': 'beginner',
      'schedule_mode': 'rotation',
      'days_per_week': 3,
      'source_program_id': null,
      'program_workouts': [
        {
          'position': 1,
          'name': 'B',
          'weekday': null,
          'workout_exercises': [_blockRow(position: 0)],
        },
        {
          'position': 0,
          'name': 'A',
          'weekday': null,
          'workout_exercises': [
            _blockRow(position: 1, exerciseId: 'Bench', name: 'Bench'),
            _blockRow(position: 0),
          ],
        },
      ],
    });
    expect(program.isBuiltIn, isTrue);
    expect(program.level, ProgramLevel.beginner);
    expect(program.workouts.map((w) => w.name), ['A', 'B']);
    expect(program.workouts.first.exercises.map((b) => b.exerciseId), ['Barbell_Squat', 'Bench']);
    expect(program.effectiveDaysPerWeek, 3);
    expect(program.usesPercentages, isFalse);
  });

  test('Program without nested workouts (list query) has an empty workout list', () {
    final program = Program.fromJson({
      'id': 'p1',
      'user_id': 'u1',
      'name': 'Mine',
      'schedule_mode': 'weekdays',
    });
    expect(program.workouts, isEmpty);
    expect(program.isBuiltIn, isFalse);
  });

  test('effectiveDaysPerWeek falls back to workout count in weekdays mode', () {
    const program = Program(
      name: 'Mine',
      scheduleMode: ScheduleMode.weekdays,
      workouts: [
        ProgramWorkout(name: 'A', weekday: 1, exercises: []),
        ProgramWorkout(name: 'B', weekday: 4, exercises: []),
      ],
    );
    expect(program.effectiveDaysPerWeek, 2);
    expect(program.copyWith(scheduleMode: ScheduleMode.rotation).effectiveDaysPerWeek, isNull);
  });

  test('toSavePayload serializes the whole tree for save_program', () {
    const program = Program(
      id: 'p1',
      name: 'Mine',
      scheduleMode: ScheduleMode.weekdays,
      level: ProgramLevel.intermediate,
      sourceProgramId: 'src',
      workouts: [
        ProgramWorkout(
          name: 'A',
          weekday: 1,
          exercises: [
            WorkoutExercise(
              exerciseId: 'Barbell_Squat',
              exerciseName: 'Barbell Squat',
              sets: 3,
              repsMin: 8,
              repsMax: 12,
              percent1rm: 70,
            ),
          ],
        ),
      ],
    );
    final payload = program.toSavePayload();
    expect(payload['id'], 'p1');
    expect(payload['schedule_mode'], 'weekdays');
    expect(payload['level'], 'intermediate');
    expect(payload['source_program_id'], 'src');
    expect(payload['days_per_week'], isNull);
    final workouts = payload['workouts'] as List;
    expect(workouts.single['weekday'], 1);
    expect((workouts.single['exercises'] as List).single['exercise_id'], 'Barbell_Squat');
    expect(program.usesPercentages, isTrue);
    expect(program.oneRepMaxExerciseIds, {'Barbell_Squat'});
  });
}
