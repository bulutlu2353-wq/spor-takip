import 'package:flutter_test/flutter_test.dart';
import 'package:spor_takip/features/workout/domain/session_stats.dart';
import 'package:spor_takip/features/workout/domain/workout_session.dart';

SessionSet _set(String id, {double? weight, int? reps, bool done = true}) {
  return SessionSet(
    id: id,
    exercisePosition: 0,
    setIndex: 0,
    exerciseId: 'Barbell_Squat',
    exerciseName: 'Barbell Squat',
    targetRepsMin: 5,
    targetRepsMax: 5,
    weightKg: weight,
    reps: reps,
    completedAt: done ? DateTime(2026, 9, 26, 10, 5) : null,
  );
}

WorkoutSession _session(List<SessionSet> sets, {DateTime? finishedAt}) {
  return WorkoutSession(
    id: 's',
    programName: 'P',
    workoutName: 'A',
    workoutPosition: 0,
    startedAt: DateTime(2026, 9, 26, 10),
    finishedAt: finishedAt,
    sets: sets,
  );
}

void main() {
  final session = _session([
    _set('a', weight: 60, reps: 5),
    _set('b', weight: 60, reps: 5),
    _set('c', reps: 10), // vücut ağırlığı
    _set('d', weight: 60, reps: 5, done: false),
  ]);

  test('counts completed sets', () {
    expect(completedSetCount(session), 3);
  });

  test('volume sums weight × reps of completed weighted sets', () {
    expect(totalVolumeKg(session), 600);
  });

  test('duration uses finishedAt, else now; never negative', () {
    expect(
      sessionDuration(_session([], finishedAt: DateTime(2026, 9, 26, 10, 45)), DateTime(2026, 9, 26, 12)),
      const Duration(minutes: 45),
    );
    expect(sessionDuration(session, DateTime(2026, 9, 26, 10, 30)), const Duration(minutes: 30));
    expect(sessionDuration(session, DateTime(2026, 9, 26, 9)), Duration.zero);
  });

  test('formatDuration', () {
    expect(formatDuration(const Duration(seconds: 90)), '01:30');
    expect(formatDuration(const Duration(minutes: 30)), '30:00');
    expect(formatDuration(const Duration(hours: 1, minutes: 5, seconds: 3)), '1:05:03');
  });
}
