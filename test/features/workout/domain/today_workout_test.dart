import 'package:flutter_test/flutter_test.dart';
import 'package:spor_takip/features/workout/domain/program.dart';
import 'package:spor_takip/features/workout/domain/program_workout.dart';
import 'package:spor_takip/features/workout/domain/schedule_mode.dart';
import 'package:spor_takip/features/workout/domain/today_workout.dart';

const _weekly = Program(
  id: 'p',
  name: 'Weekly',
  scheduleMode: ScheduleMode.weekdays,
  workouts: [
    ProgramWorkout(name: 'Mon', weekday: 1, exercises: []),
    ProgramWorkout(name: 'Wed', weekday: 3, exercises: []),
  ],
);

const _rotation = Program(
  id: 'r',
  name: 'Rotation',
  scheduleMode: ScheduleMode.rotation,
  workouts: [
    ProgramWorkout(name: 'A', exercises: []),
    ProgramWorkout(name: 'B', exercises: []),
  ],
);

// 2026-09-28 bir Pazartesi, 2026-09-29 Salı.
final _monday = DateTime(2026, 9, 28);
final _tuesday = DateTime(2026, 9, 29);

void main() {
  test('no active program', () {
    expect(resolveTodayWorkout(program: null, nextRotationPosition: 0, now: _monday), isA<NoActiveProgram>());
  });

  test('program without workouts', () {
    const empty = Program(name: 'E', scheduleMode: ScheduleMode.rotation, workouts: []);
    expect(resolveTodayWorkout(program: empty, nextRotationPosition: 0, now: _monday), isA<EmptyProgram>());
  });

  test('weekdays mode picks the workout scheduled for today', () {
    final today = resolveTodayWorkout(program: _weekly, nextRotationPosition: 0, now: _monday);
    expect(today, isA<ScheduledWorkout>());
    today as ScheduledWorkout;
    expect(today.workout.name, 'Mon');
    expect(today.workoutIndex, 0);
  });

  test('weekdays mode with nothing scheduled today is a rest day', () {
    expect(resolveTodayWorkout(program: _weekly, nextRotationPosition: 0, now: _tuesday), isA<RestDay>());
  });

  test('rotation mode uses next position and wraps around', () {
    final first = resolveTodayWorkout(program: _rotation, nextRotationPosition: 1, now: _monday) as ScheduledWorkout;
    expect(first.workout.name, 'B');
    final wrapped = resolveTodayWorkout(program: _rotation, nextRotationPosition: 5, now: _monday) as ScheduledWorkout;
    expect(wrapped.workout.name, 'B');
    expect(wrapped.workoutIndex, 1);
  });
}
