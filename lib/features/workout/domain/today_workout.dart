import 'program.dart';
import 'program_workout.dart';
import 'schedule_mode.dart';

sealed class TodayWorkout {
  const TodayWorkout();
}

class NoActiveProgram extends TodayWorkout {
  const NoActiveProgram();
}

class EmptyProgram extends TodayWorkout {
  const EmptyProgram(this.program);
  final Program program;
}

class RestDay extends TodayWorkout {
  const RestDay(this.program);
  final Program program;
}

class ScheduledWorkout extends TodayWorkout {
  const ScheduledWorkout(this.program, this.workoutIndex, this.workout);
  final Program program;
  final int workoutIndex;
  final ProgramWorkout workout;
}

TodayWorkout resolveTodayWorkout({
  required Program? program,
  required int nextRotationPosition,
  required DateTime now,
}) {
  if (program == null) return const NoActiveProgram();
  if (program.workouts.isEmpty) return EmptyProgram(program);

  switch (program.scheduleMode) {
    case ScheduleMode.weekdays:
      final index = program.workouts.indexWhere((w) => w.weekday == now.weekday);
      return index < 0 ? RestDay(program) : ScheduledWorkout(program, index, program.workouts[index]);
    case ScheduleMode.rotation:
      final index = nextRotationPosition % program.workouts.length;
      return ScheduledWorkout(program, index, program.workouts[index]);
  }
}
