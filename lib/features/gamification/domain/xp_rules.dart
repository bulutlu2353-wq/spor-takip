import 'dart:math' as math;

import '../../progress/domain/strength.dart';
import '../../workout/domain/workout_session.dart';

/// XP olayının kaynağı (O1 spec §3).
enum XpSource { workout, record, mealDay }

class XpEvent {
  const XpEvent({
    required this.source,
    required this.date,
    required this.xp,
    this.label,
    this.sets = 0,
    this.weightKg,
    this.reps,
  });

  final XpSource source;

  /// Yerel: antrenman ve rekorda bitiş, öğünde günün başı.
  final DateTime date;
  final int xp;

  /// Antrenman: antrenman adı; rekor: hareket adı; öğün: null.
  final String? label;

  /// Yalnız antrenmanda: sayılan (≤ [maxCountedSets]) tamamlanmış set.
  final int sets;

  /// Yalnız rekorda: en iyi setin kilosu ve tekrarı.
  final double? weightKg;
  final int? reps;
}

const xpPerWorkout = 50;
const xpPerSet = 5;
const maxCountedSets = 30;
const xpPerRecord = 25;
const xpPerMealDay = 10;

/// Eskiden yeniye; aynı anda antrenman → rekor → öğün.
List<XpEvent> xpEvents(List<WorkoutSession> sessions, List<DateTime> mealTimes) {
  final events = <XpEvent>[];
  final finished = [
    for (final s in sessions)
      if (s.finishedAt != null) s,
  ]..sort((a, b) => a.finishedAt!.compareTo(b.finishedAt!));
  final bestSoFar = <String, double>{};
  for (final session in finished) {
    final completed = [
      for (final set in session.sets)
        if (set.isCompleted) set,
    ];
    if (completed.isEmpty) continue;
    final date = session.finishedAt!.toLocal();
    final counted = math.min(completed.length, maxCountedSets);
    events.add(XpEvent(
      source: XpSource.workout,
      date: date,
      xp: xpPerWorkout + counted * xpPerSet,
      label: session.workoutName,
      sets: counted,
    ));

    final bestSet = <String, SessionSet>{};
    final bestEstimate = <String, double>{};
    for (final set in completed) {
      final estimate = estimateOneRepMax(weightKg: set.weightKg, reps: set.reps);
      if (estimate == null) continue;
      if (estimate > (bestEstimate[set.exerciseId] ?? 0)) {
        bestEstimate[set.exerciseId] = estimate;
        bestSet[set.exerciseId] = set;
      }
    }
    for (final MapEntry(key: exerciseId, value: estimate) in bestEstimate.entries) {
      final previous = bestSoFar[exerciseId];
      if (previous != null && estimate > previous) {
        final set = bestSet[exerciseId]!;
        events.add(XpEvent(
          source: XpSource.record,
          date: date,
          xp: xpPerRecord,
          label: set.exerciseName,
          weightKg: set.weightKg,
          reps: set.reps,
        ));
      }
      if (previous == null || estimate > previous) bestSoFar[exerciseId] = estimate;
    }
  }

  final days = <DateTime>{
    for (final time in mealTimes)
      if (time.toLocal() case final local) DateTime(local.year, local.month, local.day),
  };
  for (final day in days) {
    events.add(XpEvent(source: XpSource.mealDay, date: day, xp: xpPerMealDay));
  }

  events.sort((a, b) {
    final byDate = a.date.compareTo(b.date);
    return byDate != 0 ? byDate : a.source.index.compareTo(b.source.index);
  });
  return events;
}

/// Seviye ekranındaki döküm: antrenman tabanı, setler, rekorlar, öğün günleri.
class XpBreakdown {
  const XpBreakdown({this.workouts = 0, this.sets = 0, this.records = 0, this.mealDays = 0});

  final int workouts;
  final int sets;
  final int records;
  final int mealDays;

  int get total => workouts + sets + records + mealDays;
}

XpBreakdown xpBreakdown(List<XpEvent> events) {
  var workouts = 0, sets = 0, records = 0, mealDays = 0;
  for (final e in events) {
    switch (e.source) {
      case XpSource.workout:
        workouts += xpPerWorkout;
        sets += e.sets * xpPerSet;
      case XpSource.record:
        records += e.xp;
      case XpSource.mealDay:
        mealDays += e.xp;
    }
  }
  return XpBreakdown(workouts: workouts, sets: sets, records: records, mealDays: mealDays);
}
