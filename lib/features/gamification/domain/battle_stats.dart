import '../../progress/domain/strength.dart';
import '../../progress/domain/weekly_summary.dart';
import 'fair_play.dart';
import 'streak.dart';

/// Stat kuralları (O2a spec §4).
const strengthWindowDays = 90;
const strengthTopExercises = 3;
const strengthFullRatio = 4.5;
const enduranceWindowDays = 28;
const enduranceSetsPerPoint = 3;
const consistencyWeeks = 8;
const minStat = 1;
const maxStat = 100;
const maxStatSum = 600;

class StatInputs {
  const StatInputs({required this.verdicts, required this.weeklyGoal, this.bodyWeightKg});

  /// `judgeSessions` çıktısı; yalnız sayılanlar kullanılır.
  final List<SessionVerdict> verdicts;
  final int weeklyGoal;

  /// Profil kilosu; null → Güç 1.
  final double? bodyWeightKg;
}

class BattleStats {
  const BattleStats({required this.strength, required this.endurance, required this.consistency});

  static const floor = BattleStats(strength: minStat, endurance: minStat, consistency: minStat);

  final int strength;
  final int endurance;
  final int consistency;

  /// Hasar bonusu, en çok 0,5.
  double get bonus => (strength + endurance + consistency) / maxStatSum;

  int get bonusPercent => (bonus * 100).round();
}

int _stat(num value) => value.round().clamp(minStat, maxStat);

/// [day]'in sonuna kadar biten sayılan oturumlarla statlar.
BattleStats statsOn(DateTime day, StatInputs inputs) {
  final today = localDay(day);
  final end = DateTime(today.year, today.month, today.day + 1);
  final counted = [
    for (final v in inputs.verdicts)
      if (v.counted && v.finishedAt.isBefore(end)) v,
  ];
  return BattleStats(
    strength: _strength(counted, today, inputs.bodyWeightKg),
    endurance: _endurance(counted, today),
    consistency: _consistency(counted, today, inputs.weeklyGoal),
  );
}

int _strength(List<SessionVerdict> counted, DateTime today, double? bodyWeightKg) {
  if (bodyWeightKg == null || bodyWeightKg <= 0) return minStat;
  final from = DateTime(today.year, today.month, today.day - (strengthWindowDays - 1));
  final best = <String, double>{};
  for (final v in counted) {
    if (v.finishedAt.isBefore(from)) continue;
    for (final set in v.countedSets) {
      final estimate = estimateOneRepMax(weightKg: set.weightKg, reps: set.reps);
      if (estimate != null && estimate > (best[set.exerciseId] ?? 0)) best[set.exerciseId] = estimate;
    }
  }
  if (best.isEmpty) return minStat;
  final top = (best.values.toList()..sort((a, b) => b.compareTo(a))).take(strengthTopExercises);
  final ratio = top.fold(0.0, (sum, e) => sum + e) / bodyWeightKg;
  return _stat(ratio / strengthFullRatio * 100);
}

int _endurance(List<SessionVerdict> counted, DateTime today) {
  final from = DateTime(today.year, today.month, today.day - (enduranceWindowDays - 1));
  var sets = 0;
  for (final v in counted) {
    if (!v.finishedAt.isBefore(from)) sets += v.countedSets.length;
  }
  return _stat(sets / enduranceSetsPerPoint);
}

int _consistency(List<SessionVerdict> counted, DateTime today, int weeklyGoal) {
  final thisWeek = startOfWeek(today);
  final from = DateTime(thisWeek.year, thisWeek.month, thisWeek.day - 7 * consistencyWeeks);
  final days = <DateTime, Set<DateTime>>{};
  for (final v in counted) {
    final day = localDay(v.finishedAt);
    if (day.isBefore(from) || !day.isBefore(thisWeek)) continue;
    days.putIfAbsent(startOfWeek(day), () => {}).add(day);
  }
  final hits = days.values.where((d) => d.length >= weeklyGoal).length;
  return _stat(hits * maxStat / consistencyWeeks);
}
