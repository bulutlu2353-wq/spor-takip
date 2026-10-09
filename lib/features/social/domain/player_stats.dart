import 'dart:convert';

import '../../gamification/domain/levels.dart';
import '../../gamification/domain/player_summary.dart';
import '../../gamification/domain/titles.dart';
import '../../gamification/domain/xp_rules.dart';
import '../../progress/domain/weekly_summary.dart';
import '../../workout/domain/exercise.dart';
import '../../workout/domain/muscle_heat.dart';
import '../../workout/domain/workout_session.dart';

/// Arkadaşlara açık bölümler (S1 spec §2.3).
class SharedPrivacy {
  const SharedPrivacy({this.weekly = true, this.workouts = true, this.heat = true});

  final bool weekly;
  final bool workouts;
  final bool heat;
}

class WeeklyStats {
  const WeeklyStats({required this.workouts, required this.sets, required this.mealDays});

  final int workouts;
  final int sets;
  final int mealDays;

  Map<String, dynamic> toJson() => {'workouts': workouts, 'sets': sets, 'meal_days': mealDays};

  factory WeeklyStats.fromJson(Map<String, dynamic> json) => WeeklyStats(
        workouts: (json['workouts'] as num?)?.toInt() ?? 0,
        sets: (json['sets'] as num?)?.toInt() ?? 0,
        mealDays: (json['meal_days'] as num?)?.toInt() ?? 0,
      );
}

class SharedRecord {
  const SharedRecord({required this.name, required this.weightKg, required this.reps});

  final String name;
  final double weightKg;
  final int reps;

  Map<String, dynamic> toJson() => {'name': name, 'weight_kg': weightKg, 'reps': reps};

  factory SharedRecord.fromJson(Map<String, dynamic> json) => SharedRecord(
        name: json['name'] as String? ?? '',
        weightKg: (json['weight_kg'] as num?)?.toDouble() ?? 0,
        reps: (json['reps'] as num?)?.toInt() ?? 0,
      );
}

class RecentWorkout {
  const RecentWorkout({required this.name, required this.date, required this.sets, required this.records});

  final String name;

  /// Yerel bitiş zamanı.
  final DateTime date;
  final int sets;
  final List<SharedRecord> records;

  Map<String, dynamic> toJson() => {
        'name': name,
        'date': date.toUtc().toIso8601String(),
        'sets': sets,
        'records': [for (final r in records) r.toJson()],
      };

  factory RecentWorkout.fromJson(Map<String, dynamic> json) => RecentWorkout(
        name: json['name'] as String? ?? '',
        date: DateTime.parse(json['date'] as String).toLocal(),
        sets: (json['sets'] as num?)?.toInt() ?? 0,
        records: [
          for (final r in json['records'] as List? ?? const []) SharedRecord.fromJson(r as Map<String, dynamic>),
        ],
      );
}

class SharedTitle {
  const SharedTitle({required this.kind, required this.subjectId, required this.tier, this.exerciseName});

  final TitleKind kind;
  final String subjectId;
  final String? exerciseName;
  final TitleTier tier;

  /// `titleName` için; değer kullanılmaz.
  TitleProgress get asProgress =>
      TitleProgress(kind: kind, subjectId: subjectId, value: 0, exerciseName: exerciseName);

  Map<String, dynamic> toJson() => {
        'kind': kind.name,
        'subject_id': subjectId,
        'exercise_name': exerciseName,
        'tier': tier.name,
      };

  /// Bilinmeyen tür ya da kademe (gelecek sürüm) → null.
  static SharedTitle? fromJson(Map<String, dynamic> json) {
    final kind = TitleKind.values.asNameMap()[json['kind']];
    final tier = TitleTier.values.asNameMap()[json['tier']];
    if (kind == null || tier == null) return null;
    return SharedTitle(
      kind: kind,
      subjectId: json['subject_id'] as String? ?? '',
      exerciseName: json['exercise_name'] as String?,
      tier: tier,
    );
  }
}

/// `player_stats` satırı (S1 spec §3.3). Eşitlik `updatedAt`'i saymaz:
/// içerik değişmediyse yeniden yazılmaz.
class PlayerStats {
  const PlayerStats({
    required this.level,
    required this.totalXp,
    required this.rank,
    required this.titles,
    this.activeTitle,
    this.weekly,
    this.recent,
    this.heat,
    this.updatedAt,
  });

  final int level;
  final int totalXp;
  final Rank rank;
  final SharedTitle? activeTitle;
  final List<SharedTitle> titles;
  final WeeklyStats? weekly;
  final List<RecentWorkout>? recent;
  final Map<String, HeatTier>? heat;
  final DateTime? updatedAt;

  Map<String, dynamic> toJson() {
    final heat = this.heat;
    final recent = this.recent;
    return {
      'level': level,
      'total_xp': totalXp,
      'rank': rank.name,
      'active_title': activeTitle?.toJson(),
      'titles': [for (final t in titles) t.toJson()],
      'weekly': weekly?.toJson(),
      'recent': recent == null ? null : [for (final r in recent) r.toJson()],
      'heat': heat == null ? null : {for (final muscle in heat.keys.toList()..sort()) muscle: heat[muscle]!.name},
    };
  }

  factory PlayerStats.fromJson(Map<String, dynamic> json) {
    final heat = json['heat'] as Map<String, dynamic>?;
    final recent = json['recent'] as List?;
    final weekly = json['weekly'] as Map<String, dynamic>?;
    final active = json['active_title'] as Map<String, dynamic>?;
    final updatedAt = json['updated_at'] as String?;
    return PlayerStats(
      level: (json['level'] as num?)?.toInt() ?? 1,
      totalXp: (json['total_xp'] as num?)?.toInt() ?? 0,
      rank: Rank.values.asNameMap()[json['rank']] ?? Rank.rookie,
      activeTitle: active == null ? null : SharedTitle.fromJson(active),
      titles: [
        for (final t in json['titles'] as List? ?? const [])
          if (SharedTitle.fromJson(t as Map<String, dynamic>) case final title?) title,
      ],
      weekly: weekly == null ? null : WeeklyStats.fromJson(weekly),
      recent: recent == null
          ? null
          : [for (final r in recent) RecentWorkout.fromJson(r as Map<String, dynamic>)],
      heat: heat == null
          ? null
          : {
              for (final MapEntry(key: muscle, value: tier) in heat.entries)
                if (HeatTier.values.asNameMap()[tier] case final known?) muscle: known,
            },
      updatedAt: updatedAt == null ? null : DateTime.parse(updatedAt).toLocal(),
    );
  }

  String get _canonical => jsonEncode(toJson());

  @override
  bool operator ==(Object other) => other is PlayerStats && other._canonical == _canonical;

  @override
  int get hashCode => _canonical.hashCode;
}

List<WorkoutSession> _finishedWithSets(List<WorkoutSession> sessions) => [
      for (final s in sessions)
        if (s.finishedAt != null && s.sets.any((set) => set.isCompleted)) s,
    ]..sort((a, b) => b.finishedAt!.compareTo(a.finishedAt!));

int _completedSets(WorkoutSession session) => session.sets.where((s) => s.isCompleted).length;

WeeklyStats _weekly(List<WorkoutSession> sessions, List<DateTime> mealTimes, DateTime now) {
  final start = startOfWeek(now);
  final end = DateTime(start.year, start.month, start.day + 7);
  bool inWeek(DateTime t) => !t.isBefore(start) && t.isBefore(end);
  var workouts = 0;
  var sets = 0;
  for (final s in _finishedWithSets(sessions)) {
    if (!inWeek(s.finishedAt!.toLocal())) continue;
    workouts++;
    sets += _completedSets(s);
  }
  final days = <DateTime>{
    for (final time in mealTimes)
      if (time.toLocal() case final local when inWeek(local)) DateTime(local.year, local.month, local.day),
  };
  return WeeklyStats(workouts: workouts, sets: sets, mealDays: days.length);
}

List<RecentWorkout> _recent(List<WorkoutSession> sessions) {
  final records = [
    for (final e in xpEvents(sessions, const []))
      if (e.source == XpSource.record) e,
  ];
  return [
    for (final s in _finishedWithSets(sessions).take(5))
      RecentWorkout(
        name: s.workoutName,
        date: s.finishedAt!.toLocal(),
        sets: _completedSets(s),
        records: [
          for (final e in records)
            if (e.date == s.finishedAt!.toLocal())
              SharedRecord(name: e.label ?? '', weightKg: e.weightKg ?? 0, reps: e.reps ?? 0),
        ],
      ),
  ];
}

/// Uygulamanın yayınlayacağı satır (S1 spec §4); gizli bölümler null.
PlayerStats buildPlayerStats({
  required PlayerSummary summary,
  required List<WorkoutSession> sessions,
  required List<DateTime> mealTimes,
  required Map<String, Exercise> exercisesById,
  required DateTime now,
  required String? activeTitleId,
  required SharedPrivacy privacy,
}) {
  SharedTitle shared(TitleProgress t) =>
      SharedTitle(kind: t.kind, subjectId: t.subjectId, exerciseName: t.exerciseName, tier: t.tier!);
  final active = summary.titleById(activeTitleId);
  return PlayerStats(
    level: summary.progress.level,
    totalXp: summary.totalXp,
    rank: summary.rank,
    activeTitle: active == null ? null : shared(active),
    titles: [for (final t in summary.titles.take(10)) shared(t)],
    weekly: privacy.weekly ? _weekly(sessions, mealTimes, now) : null,
    recent: privacy.workouts ? _recent(sessions) : null,
    heat: privacy.heat
        ? heatTiers(historyMuscleLoad(sessions, exercisesById, now.subtract(const Duration(days: 7))), days: 7)
        : null,
  );
}
