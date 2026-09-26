import 'package:flutter_test/flutter_test.dart';
import 'package:spor_takip/features/workout/domain/workout_session.dart';

Map<String, dynamic> _setJson(
  String id, {
  required int position,
  required int index,
  String exercise = 'Barbell_Squat',
  String name = 'Barbell Squat',
  Object? weight,
  Object? reps,
  String? completedAt,
  Object? percent,
}) {
  return {
    'id': id,
    'session_id': 's1',
    'exercise_position': position,
    'set_index': index,
    'exercise_id': exercise,
    'exercises': {'name': name},
    'target_reps_min': 5,
    'target_reps_max': 5,
    'is_amrap': false,
    'percent_1rm': percent,
    'percent_ref_exercise_id': null,
    'rest_seconds': 180,
    'suggested_weight_kg': 60,
    'deloaded': false,
    'weight_kg': weight,
    'reps': reps,
    'completed_at': completedAt,
  };
}

SessionSet _set({
  String id = 'x',
  int min = 5,
  int max = 5,
  bool amrap = false,
  double? suggested,
  double? weight,
  int? reps,
  bool done = false,
}) {
  return SessionSet(
    id: id,
    exercisePosition: 0,
    setIndex: 0,
    exerciseId: 'Barbell_Squat',
    exerciseName: 'Barbell Squat',
    targetRepsMin: min,
    targetRepsMax: max,
    isAmrap: amrap,
    suggestedWeightKg: suggested,
    weightKg: weight,
    reps: reps,
    completedAt: done ? DateTime(2026, 9, 26, 10, 5) : null,
  );
}

void main() {
  test('fromJson parses the session and sorts sets by exercise and set order', () {
    final session = WorkoutSession.fromJson({
      'id': 's1',
      'user_id': 'user-1',
      'program_id': 'p1',
      'program_name': 'StrongLifts 5x5',
      'workout_name': 'Antrenman A',
      'workout_position': 1,
      'started_at': '2026-09-26T10:00:00+00:00',
      'finished_at': null,
      'session_sets': [
        _setJson('b', position: 1, index: 0, exercise: 'Bench', name: 'Bench Press'),
        _setJson('a2', position: 0, index: 1, weight: 60, reps: 5,
            completedAt: '2026-09-26T10:05:00+00:00', percent: 85.5),
        _setJson('a1', position: 0, index: 0),
      ],
    });

    expect(session.id, 's1');
    expect(session.programId, 'p1');
    expect(session.workoutPosition, 1);
    expect(session.isInProgress, isTrue);
    expect(session.sets.map((s) => s.id), ['a1', 'a2', 'b']);
    expect(session.exerciseGroups.map((g) => g.length), [2, 1]);
    expect(session.sets[2].exerciseName, 'Bench Press');
    expect(session.sets[1].isCompleted, isTrue);
    expect(session.sets[1].weightKg, 60);
    expect(session.sets[1].percent1rm, 85.5);
    expect(session.sets[0].suggestedWeightKg, 60);
    expect(session.sets[0].restSeconds, 180);
    expect(session.nextExercisePosition, 2);
    expect(session.setById('b').exerciseId, 'Bench');
  });

  test('a finished session without sets', () {
    final session = WorkoutSession.fromJson({
      'id': 's2',
      'program_id': null,
      'program_name': 'Silinmiş',
      'workout_name': 'A',
      'workout_position': 0,
      'started_at': '2026-09-26T10:00:00+00:00',
      'finished_at': '2026-09-26T11:00:00+00:00',
    });
    expect(session.isInProgress, isFalse);
    expect(session.programId, isNull);
    expect(session.sets, isEmpty);
    expect(session.exerciseGroups, isEmpty);
    expect(session.nextExercisePosition, 0);
  });

  test('toInsertJson carries the plan but not the results', () {
    final json = const SessionSet(
      exercisePosition: 2,
      setIndex: 1,
      exerciseId: 'Sumo_Deadlift',
      exerciseName: 'Sumo Deadlift',
      targetRepsMin: 3,
      targetRepsMax: 3,
      isAmrap: true,
      percent1rm: 70,
      percentRefExerciseId: 'Barbell_Deadlift',
      restSeconds: 120,
      suggestedWeightKg: 100,
      deloaded: true,
    ).toInsertJson();

    expect(json, {
      'exercise_position': 2,
      'set_index': 1,
      'exercise_id': 'Sumo_Deadlift',
      'target_reps_min': 3,
      'target_reps_max': 3,
      'is_amrap': true,
      'percent_1rm': 70.0,
      'percent_ref_exercise_id': 'Barbell_Deadlift',
      'rest_seconds': 120,
      'suggested_weight_kg': 100.0,
      'deloaded': true,
    });
  });

  test('display values fall back to the suggestion and the top of the range', () {
    expect(_set(suggested: 60).displayWeightKg, 60);
    expect(_set(suggested: 60, weight: 65).displayWeightKg, 65);
    expect(_set(min: 8, max: 12).displayReps, 12);
    expect(_set(amrap: true).displayReps, isNull);
    expect(_set(reps: 7).displayReps, 7);
  });

  test('hitTarget: top of range for normal sets, bottom for AMRAP', () {
    expect(_set(min: 8, max: 12, reps: 12, done: true).hitTarget, isTrue);
    expect(_set(min: 8, max: 12, reps: 11, done: true).hitTarget, isFalse);
    expect(_set(amrap: true, reps: 5, done: true).hitTarget, isTrue);
    expect(_set(amrap: true, reps: 4, done: true).hitTarget, isFalse);
    expect(_set(reps: 5).hitTarget, isFalse, reason: 'not completed');
  });

  test('copyWith and replaceSet', () {
    final set = _set(id: 'a', weight: 60, reps: 5, done: true);
    final cleared = set.copyWith(clearCompletedAt: true, clearWeight: true);
    expect(cleared.isCompleted, isFalse);
    expect(cleared.weightKg, isNull);
    expect(cleared.reps, 5);
    expect(set.copyWith(id: 'b').id, 'b');

    final session = WorkoutSession(
      id: 's',
      programName: 'P',
      workoutName: 'A',
      workoutPosition: 0,
      startedAt: DateTime(2026, 9, 26, 10),
      sets: [set, _set(id: 'c')],
    );
    final replaced = session.replaceSet(cleared);
    expect(replaced.setById('a').isCompleted, isFalse);
    expect(replaced.sets.length, 2);
    expect(session.copyWith(finishedAt: DateTime(2026, 9, 26, 11)).isInProgress, isFalse);
  });
}
