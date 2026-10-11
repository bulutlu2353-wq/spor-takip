import '../../progress/domain/weekly_summary.dart';
import '../../workout/domain/program.dart';
import '../../workout/domain/schedule_mode.dart';
import '../../workout/domain/today_workout.dart';
import '../../workout/domain/workout_session.dart';

Program? programOf(TodayWorkout today) => switch (today) {
  NoActiveProgram() => null,
  EmptyProgram(:final program) => program,
  RestDay(:final program) => program,
  ScheduledWorkout(:final program) => program,
};

/// ISO hafta günü → antrenman adı (N1 spec §3.2): sabit günlüde programın günleri,
/// döngüselde sıradaki antrenman her gün.
Map<int, String> workoutNamesByWeekday(TodayWorkout today) {
  final program = programOf(today);
  if (program == null) return const {};
  switch (program.scheduleMode) {
    case ScheduleMode.weekdays:
      return {for (final workout in program.workouts) ?workout.weekday: workout.name};
    case ScheduleMode.rotation:
      if (today is! ScheduledWorkout) return const {};
      return {for (var day = DateTime.monday; day <= DateTime.sunday; day++) day: today.workout.name};
  }
}

bool _sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

/// O (yerel) gün bitmiş bir oturum var mı.
bool finishedOn(List<WorkoutSession> sessions, DateTime day) =>
    sessions.any((s) => s.finishedAt != null && _sameDay(s.finishedAt!.toLocal(), day));

/// Bu ISO haftada [now]'a kadar bitmiş oturum sayısı.
int finishedThisWeek(List<WorkoutSession> sessions, DateTime now) {
  final start = startOfWeek(now);
  return sessions.where((s) {
    final finished = s.finishedAt?.toLocal();
    return finished != null && !finished.isBefore(start) && !finished.isAfter(now);
  }).length;
}
