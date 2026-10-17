import '../../progress/domain/strength.dart';
import '../../workout/domain/workout_session.dart';
import 'fair_play.dart';

/// XP olayının kaynağı (O1 spec §3; meydan okuma ödülü S3 spec §3.3).
enum XpSource { workout, record, mealDay, challenge }

class XpEvent {
  const XpEvent({
    required this.source,
    required this.date,
    required this.xp,
    this.label,
    this.sets = 0,
    this.weightKg,
    this.reps,
    this.skip,
  });

  final XpSource source;

  /// Yerel: antrenman ve rekorda bitiş, öğünde günün başı.
  final DateTime date;
  final int xp;

  /// Antrenman: antrenman adı; rekor: hareket adı; öğün: null.
  final String? label;

  /// Yalnız antrenmanda: sayılan set (O3a süre tavanıyla).
  final int sets;

  /// Yalnız rekorda: en iyi setin kilosu ve tekrarı.
  final double? weightKg;
  final int? reps;

  /// Yalnız antrenmanda: XP getirmediyse nedeni (O3a spec §3.3).
  final SkipReason? skip;
}

const xpPerWorkout = 50;
const xpPerSet = 5;
const xpPerRecord = 25;
const xpPerMealDay = 10;

/// Eskiden yeniye; aynı anda antrenman → rekor → öğün. Kurallar: O3a spec §3.
List<XpEvent> xpEvents(List<WorkoutSession> sessions, List<DateTime> mealTimes) {
  final events = <XpEvent>[];
  final best = <String, double>{};
  final lastRecord = <String, DateTime>{};
  for (final verdict in judgeSessions(sessions)) {
    final sets = verdict.countedSets.length;
    events.add(XpEvent(
      source: XpSource.workout,
      date: verdict.finishedAt,
      xp: verdict.counted ? xpPerWorkout + sets * xpPerSet : 0,
      label: verdict.session.workoutName,
      sets: sets,
      skip: verdict.skip,
    ));
    events.addAll(_records(verdict, best, lastRecord));
  }

  final days = <DateTime>{
    for (final time in mealTimes)
      if (time.toLocal() case final local) DateTime(local.year, local.month, local.day),
  };
  for (final day in days) {
    events.add(XpEvent(source: XpSource.mealDay, date: day, xp: xpPerMealDay));
  }

  events.sort(compareXpEvents);
  return events;
}

/// Oturumun rekor olayları; [best] (taban) ve [lastRecord] (son rekor XP'si) yerinde güncellenir.
List<XpEvent> _records(SessionVerdict verdict, Map<String, double> best, Map<String, DateTime> lastRecord) {
  final date = verdict.finishedAt;
  final top = <String, (double, SessionSet)>{};
  for (final set in verdict.plausibleSets) {
    final estimate = estimateOneRepMax(weightKg: set.weightKg, reps: set.reps);
    if (estimate == null) continue;
    if (estimate > (top[set.exerciseId]?.$1 ?? 0)) top[set.exerciseId] = (estimate, set);
  }
  final candidates = <(double, SessionSet)>[];
  for (final MapEntry(key: exerciseId, value: (estimate, set)) in top.entries) {
    final previous = best[exerciseId];
    if (previous == null || estimate > previous) best[exerciseId] = estimate;
    if (previous == null || !verdict.counted) continue;
    final gain = estimate / previous - 1;
    if (gain < minRecordGain || gain > maxRecordJump) continue;
    final last = lastRecord[exerciseId];
    if (last != null && date.difference(last) < recordCooldown) continue;
    candidates.add((gain, set));
  }
  candidates.sort((a, b) {
    final byGain = b.$1.compareTo(a.$1);
    return byGain != 0 ? byGain : a.$2.exerciseId.compareTo(b.$2.exerciseId);
  });
  final events = <XpEvent>[];
  for (final (_, set) in candidates.take(maxRecordsPerSession)) {
    lastRecord[set.exerciseId] = date;
    events.add(XpEvent(
      source: XpSource.record,
      date: date,
      xp: xpPerRecord,
      label: set.exerciseName,
      weightKg: set.weightKg,
      reps: set.reps,
    ));
  }
  return events;
}

/// Eskiden yeniye; aynı anda kaynak sırasıyla (antrenman → rekor → öğün → meydan okuma).
int compareXpEvents(XpEvent a, XpEvent b) {
  final byDate = a.date.compareTo(b.date);
  return byDate != 0 ? byDate : a.source.index.compareTo(b.source.index);
}

/// Seviye ekranındaki döküm: antrenman tabanı, setler, rekorlar, öğün günleri, meydan okumalar.
class XpBreakdown {
  const XpBreakdown({this.workouts = 0, this.sets = 0, this.records = 0, this.mealDays = 0, this.challenges = 0});

  final int workouts;
  final int sets;
  final int records;
  final int mealDays;
  final int challenges;

  int get total => workouts + sets + records + mealDays + challenges;
}

XpBreakdown xpBreakdown(List<XpEvent> events) {
  var workouts = 0, sets = 0, records = 0, mealDays = 0, challenges = 0;
  for (final e in events) {
    switch (e.source) {
      case XpSource.workout:
        if (e.xp > 0) workouts += xpPerWorkout;
        sets += e.sets * xpPerSet;
      case XpSource.record:
        records += e.xp;
      case XpSource.mealDay:
        mealDays += e.xp;
      case XpSource.challenge:
        challenges += e.xp;
    }
  }
  return XpBreakdown(workouts: workouts, sets: sets, records: records, mealDays: mealDays, challenges: challenges);
}
