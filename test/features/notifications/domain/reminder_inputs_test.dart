import 'package:flutter_test/flutter_test.dart';
import 'package:spor_takip/features/notifications/domain/reminder_inputs.dart';
import 'package:spor_takip/features/workout/domain/program.dart';
import 'package:spor_takip/features/workout/domain/program_workout.dart';
import 'package:spor_takip/features/workout/domain/schedule_mode.dart';
import 'package:spor_takip/features/workout/domain/today_workout.dart';

import '../../gamification/game_fixtures.dart';

const _push = ProgramWorkout(name: 'Push', exercises: [], weekday: 1);
const _pull = ProgramWorkout(name: 'Pull', exercises: [], weekday: 4);
const _fixed = Program(name: 'Fixed', scheduleMode: ScheduleMode.weekdays, workouts: [_push, _pull]);
const _rotation = Program(
  name: 'Rot',
  scheduleMode: ScheduleMode.rotation,
  workouts: [
    ProgramWorkout(name: 'A', exercises: []),
    ProgramWorkout(name: 'B', exercises: []),
  ],
);

void main() {
  test('programOf unwraps every state', () {
    expect(programOf(const NoActiveProgram()), isNull);
    expect(programOf(const RestDay(_fixed)), _fixed);
    expect(programOf(const EmptyProgram(_fixed)), _fixed);
    expect(programOf(const ScheduledWorkout(_fixed, 0, _push)), _fixed);
  });

  test('fixed-day programs name their days, rotations name the next workout every day', () {
    expect(workoutNamesByWeekday(const RestDay(_fixed)), {1: 'Push', 4: 'Pull'});
    expect(workoutNamesByWeekday(ScheduledWorkout(_rotation, 1, _rotation.workouts[1])), {
      for (var d = 1; d <= 7; d++) d: 'B',
    });
    expect(workoutNamesByWeekday(const EmptyProgram(_rotation)), isEmpty);
    expect(workoutNamesByWeekday(const NoActiveProgram()), isEmpty);
  });

  test('finished sessions are counted by local day and ISO week', () {
    final sessions = [
      gameSession('sun', DateTime(2026, 10, 11, 20), const []),
      gameSession('mon', DateTime(2026, 10, 12, 8), const []),
      gameSession('open', null, const []),
    ];
    final now = DateTime(2026, 10, 12, 12);
    expect(finishedOn(sessions, now), isTrue);
    expect(finishedOn(sessions, DateTime(2026, 10, 13)), isFalse);
    expect(finishedThisWeek(sessions, now), 1);
    expect(finishedThisWeek(sessions, DateTime(2026, 10, 11, 23)), 1);
  });
}
