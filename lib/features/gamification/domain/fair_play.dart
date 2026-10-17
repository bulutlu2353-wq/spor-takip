import 'dart:math' as math;

import '../../progress/domain/strength.dart';
import '../../workout/domain/workout_session.dart';

/// Makullük kuralları (O3a spec §3.1).
const minCountedSets = 3;
const minCountedDuration = Duration(minutes: 10);
const maxCountedWorkoutsPerDay = 2;
const minutesPerCountedSet = 2;
const maxCountedSets = 30;
const maxPlausibleOneRepMaxKg = 500.0;
const minRecordGain = 0.025;
const maxRecordJump = 0.5;
const recordCooldown = Duration(days: 7);
const maxRecordsPerSession = 3;

/// Oturumun XP getirmeme nedeni.
enum SkipReason { tooSmall, dailyLimit }

/// Bir bitmiş oturumun kararı (O3a spec §3.2).
class SessionVerdict {
  const SessionVerdict({required this.session, required this.plausibleSets, this.skip, this.countedSets = const []});

  final WorkoutSession session;

  /// Tamamlanmış ve makul setler; sayılmayan oturumda da dolu (rekor tabanı için).
  final List<SessionSet> plausibleSets;

  /// null → sayılır.
  final SkipReason? skip;

  /// Sayılan setler, tamamlanma sırasıyla; sayılmayan oturumda boş.
  final List<SessionSet> countedSets;

  bool get counted => skip == null;

  /// Yerel bitiş.
  DateTime get finishedAt => session.finishedAt!.toLocal();
}

/// Kilosu ya da tahmini 1RM'si [maxPlausibleOneRepMaxKg]'ı geçen set makul değil.
bool isPlausibleSet(SessionSet set) {
  if ((set.weightKg ?? 0) > maxPlausibleOneRepMaxKg) return false;
  final estimate = estimateOneRepMax(weightKg: set.weightKg, reps: set.reps);
  return estimate == null || estimate <= maxPlausibleOneRepMaxKg;
}

/// Bitmiş ve tamamlanmış seti olan oturumlar, bitişe göre eskiden yeniye.
List<SessionVerdict> judgeSessions(List<WorkoutSession> sessions) {
  final finished = [
    for (final s in sessions)
      if (s.finishedAt != null && s.sets.any((set) => set.isCompleted)) s,
  ]..sort((a, b) => a.finishedAt!.compareTo(b.finishedAt!));
  final perDay = <DateTime, int>{};
  return [for (final session in finished) _judge(session, perDay)];
}

SessionVerdict _judge(WorkoutSession session, Map<DateTime, int> perDay) {
  final plausible = [
    for (final set in session.sets)
      if (set.isCompleted && isPlausibleSet(set)) set,
  ];
  final duration = session.finishedAt!.difference(session.startedAt);
  if (plausible.length < minCountedSets || duration < minCountedDuration) {
    return SessionVerdict(session: session, plausibleSets: plausible, skip: SkipReason.tooSmall);
  }
  final local = session.finishedAt!.toLocal();
  final day = DateTime(local.year, local.month, local.day);
  final used = perDay[day] ?? 0;
  if (used >= maxCountedWorkoutsPerDay) {
    return SessionVerdict(session: session, plausibleSets: plausible, skip: SkipReason.dailyLimit);
  }
  perDay[day] = used + 1;
  final ordered = [...plausible]..sort(_byCompletion);
  final limit = math.min(maxCountedSets, duration.inMinutes ~/ minutesPerCountedSet);
  return SessionVerdict(session: session, plausibleSets: plausible, countedSets: ordered.take(limit).toList());
}

/// Tamamlanma zamanı; eşitlikte hareket sırası ve set sırası (sıralama kararlı olsun).
int _byCompletion(SessionSet a, SessionSet b) {
  final byTime = a.completedAt!.compareTo(b.completedAt!);
  if (byTime != 0) return byTime;
  final byExercise = a.exercisePosition.compareTo(b.exercisePosition);
  return byExercise != 0 ? byExercise : a.setIndex.compareTo(b.setIndex);
}
