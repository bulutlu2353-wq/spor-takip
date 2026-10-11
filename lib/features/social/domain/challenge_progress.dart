import '../../gamification/domain/xp_rules.dart';
import '../../workout/domain/exercise.dart';
import '../../workout/domain/muscle_heat.dart';
import '../../workout/domain/workout_session.dart';
import 'challenge.dart';

/// "Hemen" ya da "Yarın 00:00" (S3 spec §3.1).
enum ChallengeStart { now, tomorrow }

/// Hemen: şimdiden N gün; yarın: yerel yarın 00:00'dan N takvim günü sonra 00:00.
({DateTime startsAt, DateTime endsAt}) challengeWindow(ChallengeStart start, int days, DateTime now) {
  if (start == ChallengeStart.now) return (startsAt: now, endsAt: now.add(Duration(days: days)));
  final startsAt = DateTime(now.year, now.month, now.day + 1);
  return (startsAt: startsAt, endsAt: DateTime(startsAt.year, startsAt.month, startsAt.day + days));
}

/// Pencerede (`[startsAt, endsAt)`) bitmiş oturumlardan değer (S3 spec §3.2).
/// [events] tüm XP olayları; meydan okuma ödülleri sayılmaz.
double challengeValue(
  Challenge challenge,
  List<WorkoutSession> sessions,
  List<XpEvent> events,
  Map<String, Exercise> exercisesById,
) {
  bool inWindow(DateTime t) => !t.isBefore(challenge.startsAt) && t.isBefore(challenge.endsAt);
  if (challenge.metric == ChallengeMetric.xp) {
    var xp = 0;
    for (final e in events) {
      if (e.source != XpSource.challenge && inWindow(e.date)) xp += e.xp;
    }
    return xp.toDouble();
  }
  var total = 0.0;
  for (final session in sessions) {
    final finished = session.finishedAt;
    if (finished == null || !inWindow(finished)) continue;
    final done = [
      for (final set in session.sets)
        if (set.isCompleted) set,
    ];
    if (done.isEmpty) continue;
    if (challenge.metric == ChallengeMetric.workouts) {
      total += 1;
      continue;
    }
    for (final set in done) {
      final weight = switch (challenge.muscle) {
        null => 1.0,
        final muscle => switch (exercisesById[set.exerciseId]) {
            final exercise? => muscleWeight(exercise, muscle),
            null => 0.0,
          },
      };
      if (weight == 0) continue;
      total += challenge.metric == ChallengeMetric.sets ? weight : (set.weightKg ?? 0) * (set.reps ?? 0) * weight;
    }
  }
  return challenge.metric == ChallengeMetric.volume ? total.roundToDouble() : total;
}
