import '../../nutrition/domain/macro_totals.dart';
import '../../nutrition/domain/meal.dart';
import '../../workout/domain/session_stats.dart';
import '../../workout/domain/workout_session.dart';
import 'body_weight_log.dart';

/// Yerel saatle haftanın Pazartesi 00:00'ı (gün aritmetiği, DST'den etkilenmez).
DateTime startOfWeek(DateTime t) => DateTime(t.year, t.month, t.day - (t.weekday - 1));

class WeekStats {
  const WeekStats({
    required this.workouts,
    required this.sets,
    required this.volumeKg,
    required this.nutritionDays,
    this.avgCalories,
    this.avgProteinG,
    this.lastWeightKg,
  });

  final int workouts;
  final int sets;
  final double volumeKg;

  /// En az bir öğün kaydedilen gün sayısı.
  final int nutritionDays;

  /// Yalnızca öğün kaydedilen günlerin ortalaması; hiç yoksa null.
  final double? avgCalories;
  final double? avgProteinG;

  /// Haftanın son kilo kaydı.
  final double? lastWeightKg;

  bool get isEmpty => workouts == 0 && nutritionDays == 0 && lastWeightKg == null;
}

class WeeklySummary {
  const WeeklySummary({required this.weekStart, required this.thisWeek, required this.lastWeek});

  /// Bu haftanın Pazartesi'si.
  final DateTime weekStart;
  final WeekStats thisWeek;
  final WeekStats lastWeek;

  bool get isEmpty => thisWeek.isEmpty && lastWeek.isEmpty;

  /// Bu haftanın son kilosu − geçen haftanın son kilosu; biri yoksa null.
  double? get weightChangeKg {
    final current = thisWeek.lastWeightKg;
    final previous = lastWeek.lastWeightKg;
    return current == null || previous == null ? null : current - previous;
  }
}

WeekStats _weekStats({
  required DateTime start,
  required DateTime end,
  required List<WorkoutSession> sessions,
  required List<Meal> meals,
  required List<BodyWeightLog> weights,
}) {
  bool inWeek(DateTime t) => !t.isBefore(start) && t.isBefore(end);

  final weekSessions = [
    for (final s in sessions)
      if (s.finishedAt case final finishedAt? when inWeek(finishedAt.toLocal())) s,
  ];

  final mealsByDay = <DateTime, List<Meal>>{};
  for (final meal in meals) {
    final local = meal.loggedAt.toLocal();
    if (!inWeek(local)) continue;
    (mealsByDay[DateTime(local.year, local.month, local.day)] ??= []).add(meal);
  }
  final dayTotals = [for (final dayMeals in mealsByDay.values) sumMealMacros(dayMeals)];
  final days = dayTotals.length;

  final weekWeights = [for (final w in weights) if (inWeek(w.date)) w]
    ..sort((a, b) => a.date.compareTo(b.date));

  return WeekStats(
    workouts: weekSessions.length,
    sets: weekSessions.fold<int>(0, (sum, s) => sum + completedSetCount(s)),
    volumeKg: weekSessions.fold<double>(0, (sum, s) => sum + totalVolumeKg(s)),
    nutritionDays: days,
    avgCalories: days == 0 ? null : dayTotals.fold<double>(0, (sum, t) => sum + t.calories) / days,
    avgProteinG: days == 0 ? null : dayTotals.fold<double>(0, (sum, t) => sum + t.proteinG) / days,
    lastWeightKg: weekWeights.isEmpty ? null : weekWeights.last.weightKg,
  );
}

/// Spec §4.4: bu hafta (Pazartesi'den [now]'a) ve bir önceki tam hafta.
WeeklySummary weeklySummary({
  required DateTime now,
  required List<WorkoutSession> sessions,
  required List<Meal> meals,
  required List<BodyWeightLog> weights,
}) {
  final start = startOfWeek(now);
  final previous = DateTime(start.year, start.month, start.day - 7);
  final next = DateTime(start.year, start.month, start.day + 7);
  return WeeklySummary(
    weekStart: start,
    thisWeek: _weekStats(start: start, end: next, sessions: sessions, meals: meals, weights: weights),
    lastWeek: _weekStats(start: previous, end: start, sessions: sessions, meals: meals, weights: weights),
  );
}
