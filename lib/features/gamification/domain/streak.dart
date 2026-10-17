import 'dart:math' as math;

import '../../progress/domain/weekly_summary.dart';
import 'fair_play.dart';

/// Seri bonusu (O4 spec §3.3): her 7 günde %5, en çok %25. Yüzde tam sayı tutulur.
const streakBonusStepDays = 7;
const streakBonusStepPercent = 5;
const maxStreakBonusPercent = 25;

int streakBonusPercent(int length) =>
    math.min(maxStreakBonusPercent, length ~/ streakBonusStepDays * streakBonusStepPercent);

/// Yerel günün başı.
DateTime localDay(DateTime t) => DateTime(t.year, t.month, t.day);

enum StreakDayKind { workout, rest, pending, broken }

class StreakDay {
  const StreakDay(this.day, this.kind, this.length);

  /// Yerel günün başı.
  final DateTime day;
  final StreakDayKind kind;

  /// Günün sonundaki seri uzunluğu.
  final int length;
}

/// İlk antrenman gününden [today]'e gün gün (O4 spec §3.2); antrenman yoksa boş.
List<StreakDay> streakDays(List<SessionVerdict> verdicts, {required int weeklyGoal, required DateTime today}) {
  final workoutDays = {
    for (final v in verdicts)
      if (v.counted) localDay(v.finishedAt),
  };
  if (workoutDays.isEmpty) return const [];
  final last = localDay(today);
  final restPerWeek = 7 - weeklyGoal;
  final restUsed = <DateTime, int>{};
  final days = <StreakDay>[];
  var length = 0;
  for (var day = workoutDays.reduce((a, b) => a.isBefore(b) ? a : b);
      !day.isAfter(last);
      day = DateTime(day.year, day.month, day.day + 1)) {
    final week = startOfWeek(day);
    final StreakDayKind kind;
    if (workoutDays.contains(day)) {
      kind = StreakDayKind.workout;
      length++;
    } else if (day == last) {
      kind = StreakDayKind.pending;
    } else if (length > 0 && (restUsed[week] ?? 0) < restPerWeek) {
      kind = StreakDayKind.rest;
      restUsed[week] = (restUsed[week] ?? 0) + 1;
      length++;
    } else {
      kind = StreakDayKind.broken;
      length = 0;
    }
    days.add(StreakDay(day, kind, length));
  }
  return days;
}

/// Antrenman günü → o günün seri uzunluğu; bugüne bağlı değil (son antrenman günü "bugün").
Map<DateTime, int> workoutStreakLengths(List<SessionVerdict> verdicts, {required int weeklyGoal}) {
  final counted = [
    for (final v in verdicts)
      if (v.counted) v.finishedAt,
  ];
  if (counted.isEmpty) return const {};
  final last = counted.reduce((a, b) => a.isAfter(b) ? a : b);
  return {
    for (final d in streakDays(verdicts, weeklyGoal: weeklyGoal, today: last))
      if (d.kind == StreakDayKind.workout) d.day: d.length,
  };
}

/// Ana sayfa hapı ve seri kartı (O4 spec §3.4).
class StreakStatus {
  const StreakStatus({required this.length, required this.bonusPercent, required this.restLeft, required this.broken});

  static const none = StreakStatus(length: 0, bonusPercent: 0, restLeft: 0, broken: true);

  /// Dünün sonundaki seri; bugün antrenman varsa bugünün.
  final int length;
  final int bonusPercent;

  /// Bu ISO hafta kalan dinlenme hakkı.
  final int restLeft;

  /// Son gün (bugün bekliyorsa dün) kırık ya da hiç antrenman yok.
  final bool broken;
}

StreakStatus streakStatus(List<SessionVerdict> verdicts, {required int weeklyGoal, required DateTime today}) {
  final days = streakDays(verdicts, weeklyGoal: weeklyGoal, today: today);
  final week = startOfWeek(today);
  final rests = days.where((d) => d.kind == StreakDayKind.rest && startOfWeek(d.day) == week).length;
  final current = switch (days) {
    [..., final previous, StreakDay(kind: StreakDayKind.pending)] => previous,
    [..., final last] => last,
    _ => null,
  };
  final length = current?.length ?? 0;
  return StreakStatus(
    length: length,
    bonusPercent: streakBonusPercent(length),
    restLeft: 7 - weeklyGoal - rests,
    broken: current == null || current.kind == StreakDayKind.broken,
  );
}
