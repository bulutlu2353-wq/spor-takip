import 'dart:convert';

import '../../gamification/domain/levels.dart';
import '../../gamification/domain/player_summary.dart';
import '../../gamification/domain/xp_rules.dart';
import '../../workout/domain/exercise.dart';
import '../../workout/domain/exercise_taxonomy.dart';
import '../../workout/domain/muscle_heat.dart';
import '../../workout/domain/workout_session.dart';
import 'period_keys.dart';
import 'player_stats.dart';

/// Bir dönemin XP'si ve kas başına ağırlıklı set sayısı.
class PeriodSlot {
  const PeriodSlot({required this.key, this.xp = 0, this.muscles = const {}});

  /// '2026-W41' ya da '2026-10'; yayın yoksa ''.
  final String key;
  final int xp;
  final Map<String, double> muscles;

  /// [category]: 'xp' ya da kas adı.
  double valueOf(String category) => category == 'xp' ? xp.toDouble() : muscles[category] ?? 0;

  Map<String, dynamic> toJson() => {
        'key': key,
        'xp': xp,
        'muscles': {for (final muscle in muscles.keys.toList()..sort()) muscle: muscles[muscle]},
      };

  factory PeriodSlot.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const PeriodSlot(key: '');
    final muscles = json['muscles'] as Map<String, dynamic>? ?? const {};
    return PeriodSlot(
      key: json['key'] as String? ?? '',
      xp: (json['xp'] as num?)?.toInt() ?? 0,
      muscles: {
        for (final MapEntry(key: muscle, value: sets) in muscles.entries) muscle: (sets as num).toDouble(),
      },
    );
  }
}

/// `period_stats` satırı (S2 spec §3.1). Eşitlik `updatedAt`'i saymaz:
/// içerik değişmediyse yeniden yazılmaz.
class PeriodStats {
  const PeriodStats({
    required this.level,
    required this.rank,
    required this.week,
    required this.prevWeek,
    required this.month,
    required this.prevMonth,
    this.activeTitle,
    this.updatedAt,
  });

  final int level;
  final Rank rank;
  final SharedTitle? activeTitle;
  final PeriodSlot week;
  final PeriodSlot prevWeek;
  final PeriodSlot month;
  final PeriodSlot prevMonth;
  final DateTime? updatedAt;

  /// Haftada `week`/`prevWeek`, ayda `month`/`prevMonth` alanlarından anahtarı eşleşen;
  /// yoksa null (eski yayın → o dönemde 0).
  PeriodSlot? slotFor(PeriodKind kind, String key) {
    final candidates = kind == PeriodKind.week ? [week, prevWeek] : [month, prevMonth];
    return candidates.where((s) => s.key == key).firstOrNull;
  }

  double valueFor(PeriodKind kind, String key, String category) => slotFor(kind, key)?.valueOf(category) ?? 0;

  Map<String, dynamic> toJson() => {
        'level': level,
        'rank': rank.name,
        'active_title': activeTitle?.toJson(),
        'periods': {
          'week': week.toJson(),
          'prev_week': prevWeek.toJson(),
          'month': month.toJson(),
          'prev_month': prevMonth.toJson(),
        },
      };

  factory PeriodStats.fromJson(Map<String, dynamic> json) {
    final periods = json['periods'] as Map<String, dynamic>? ?? const {};
    final active = json['active_title'] as Map<String, dynamic>?;
    final updatedAt = json['updated_at'] as String?;
    PeriodSlot slot(String name) => PeriodSlot.fromJson(periods[name] as Map<String, dynamic>?);
    return PeriodStats(
      level: (json['level'] as num?)?.toInt() ?? 1,
      rank: Rank.values.asNameMap()[json['rank']] ?? Rank.rookie,
      activeTitle: active == null ? null : SharedTitle.fromJson(active),
      week: slot('week'),
      prevWeek: slot('prev_week'),
      month: slot('month'),
      prevMonth: slot('prev_month'),
      updatedAt: updatedAt == null ? null : DateTime.parse(updatedAt).toLocal(),
    );
  }

  String get _canonical => jsonEncode(toJson());

  @override
  bool operator ==(Object other) => other is PeriodStats && other._canonical == _canonical;

  @override
  int get hashCode => _canonical.hashCode;
}

/// Uygulamanın yayınlayacağı satır (S2 spec §4): `now`'a göre bu ve önceki hafta/ay.
/// XP: tarihi dönemde olan XP olayları. Kas: bitişi dönemde olan oturumların
/// tamamlanmış setleri × `muscleWeight` (yalnız `muscleGroups`).
PeriodStats buildPeriodStats({
  required PlayerSummary summary,
  required List<WorkoutSession> sessions,
  required List<DateTime> mealTimes,
  required Map<String, Exercise> exercisesById,
  required DateTime now,
  required String? activeTitleId,
}) {
  final events = xpEvents(sessions, mealTimes);

  PeriodSlot slot(PeriodKind kind, {bool previous = false}) {
    final range = periodRange(kind, now, previous: previous);
    bool inRange(DateTime t) => !t.isBefore(range.start) && t.isBefore(range.end);
    var xp = 0;
    for (final e in events) {
      if (inRange(e.date)) xp += e.xp;
    }
    final muscles = <String, double>{};
    for (final session in sessions) {
      final finished = session.finishedAt?.toLocal();
      if (finished == null || !inRange(finished)) continue;
      for (final set in session.sets) {
        if (!set.isCompleted) continue;
        final exercise = exercisesById[set.exerciseId];
        if (exercise == null) continue;
        for (final muscle in muscleGroups) {
          final weight = muscleWeight(exercise, muscle);
          if (weight > 0) muscles[muscle] = (muscles[muscle] ?? 0) + weight;
        }
      }
    }
    return PeriodSlot(key: periodKey(kind, now, previous: previous), xp: xp, muscles: muscles);
  }

  final active = summary.titleById(activeTitleId);
  return PeriodStats(
    level: summary.progress.level,
    rank: summary.rank,
    activeTitle: active == null
        ? null
        : SharedTitle(
            kind: active.kind,
            subjectId: active.subjectId,
            exerciseName: active.exerciseName,
            tier: active.tier!,
          ),
    week: slot(PeriodKind.week),
    prevWeek: slot(PeriodKind.week, previous: true),
    month: slot(PeriodKind.month),
    prevMonth: slot(PeriodKind.month, previous: true),
  );
}
