import 'dart:convert';

import '../../progress/domain/weekly_summary.dart';
import '../../social/domain/period_keys.dart';
import '../../workout/domain/exercise.dart';
import '../../workout/domain/exercise_taxonomy.dart';
import '../../workout/domain/muscle_heat.dart';
import 'fair_play.dart';
import 'streak.dart';

/// Haftalık görev havuzu (O4 spec §4.1).
enum QuestKind { workouts, sets, volume, long, record, muscle, variety, weekend, mealDays, fullDays }

const xpPerQuest = 40;
const xpAllQuests = 60;

/// Üç görevin bonus olayının etiketi.
const allQuestsLabel = 'all';

const longWorkout = Duration(minutes: 45);
const varietyMinSets = 3.0;
const questHistoryWeeks = 4;
const questGrowth = 1.1;
const minQuestSets = 15;
const maxQuestSets = 60;
const minQuestVolume = 3000;

/// Kategori sırasıyla: antrenman, güç/çeşitlilik, beslenme/denge.
const questCategories = <List<QuestKind>>[
  [QuestKind.workouts, QuestKind.sets, QuestKind.volume, QuestKind.long],
  [QuestKind.record, QuestKind.muscle, QuestKind.variety, QuestKind.weekend],
  [QuestKind.mealDays, QuestKind.fullDays],
];

/// 32-bit FNV-1a (UTF-8). Çarpım `2^24 + 403` olarak parçalı: web'de 2^53 aşılmasın.
int fnv1a32(String input) {
  var hash = 0x811c9dc5;
  for (final byte in utf8.encode(input)) {
    hash ^= byte;
    hash = ((hash << 24) + hash * 403) & 0xFFFFFFFF;
  }
  return hash;
}

typedef QuestPick = ({QuestKind kind, String? muscle});

/// Her kategoriden bir görev; tohum kullanıcı + ISO hafta (O4 spec §4.2).
List<QuestPick> pickQuests(String userId, DateTime weekStart) {
  final seed = fnv1a32('$userId${weekKey(weekStart)}');
  return [
    for (final (i, category) in questCategories.indexed)
      if (category[(seed >> (8 * i)) % category.length] case final kind)
        (kind: kind, muscle: kind == QuestKind.muscle ? muscleGroups[(seed >> 24) % muscleGroups.length] : null),
  ];
}

class QuestInputs {
  const QuestInputs({
    required this.verdicts,
    required this.recordTimes,
    required this.mealTimes,
    required this.exercisesById,
    required this.weeklyGoal,
  });

  /// `judgeSessions` çıktısı (eskiden yeniye); yalnız sayılanlar katkı verir.
  final List<SessionVerdict> verdicts;

  /// XP getiren rekor olaylarının yerel zamanları.
  final List<DateTime> recordTimes;
  final List<DateTime> mealTimes;
  final Map<String, Exercise> exercisesById;
  final int weeklyGoal;
}

class QuestProgress {
  const QuestProgress({required this.kind, this.muscle, required this.progress, required this.target, this.doneAt});

  final QuestKind kind;

  /// Yalnız kas görevinde.
  final String? muscle;
  final double progress;
  final double target;

  /// Hedefe ilk ulaşılan an (yerel); null → bitmedi.
  final DateTime? doneAt;

  bool get done => doneAt != null;
}

class WeekQuests {
  const WeekQuests({required this.weekStart, required this.quests});

  final DateTime weekStart;
  final List<QuestProgress> quests;

  /// Üçü de bittiyse sonuncunun anı.
  DateTime? get bonusAt => quests.isNotEmpty && quests.every((q) => q.done)
      ? quests.map((q) => q.doneAt!).reduce((a, b) => a.isAfter(b) ? a : b)
      : null;

  bool get bonusDone => bonusAt != null;
}

WeekQuests weekQuests(QuestInputs inputs, {required String userId, required DateTime weekStart}) => WeekQuests(
      weekStart: weekStart,
      quests: [for (final pick in pickQuests(userId, weekStart)) questProgress(pick, inputs, weekStart)],
    );

/// İlk etkinliğin (sayılan oturum ya da öğün) haftasından sonuncununkine; etkinlik yoksa boş.
List<DateTime> questWeeks(QuestInputs inputs) {
  final times = [
    for (final v in inputs.verdicts)
      if (v.counted) v.finishedAt,
    for (final t in inputs.mealTimes) t.toLocal(),
  ]..sort();
  if (times.isEmpty) return const [];
  final last = startOfWeek(times.last);
  return [
    for (var w = startOfWeek(times.first); !w.isAfter(last); w = DateTime(w.year, w.month, w.day + 7)) w,
  ];
}

/// Görevin [weekStart] haftasındaki ilerlemesi ve tamamlanma anı (O4 spec §4.1, §4.3).
QuestProgress questProgress(QuestPick pick, QuestInputs inputs, DateTime weekStart) {
  final end = DateTime(weekStart.year, weekStart.month, weekStart.day + 7);
  bool inWeek(DateTime t) => !t.isBefore(weekStart) && t.isBefore(end);
  final sessions = [
    for (final v in inputs.verdicts)
      if (v.counted && inWeek(v.finishedAt)) v,
  ];
  final points = _points(pick, inputs, sessions, inWeek);
  final target = _target(pick.kind, inputs, weekStart);
  return QuestProgress(
    kind: pick.kind,
    muscle: pick.muscle,
    progress: points.isEmpty ? 0 : points.last.$2,
    target: target,
    doneAt: points.where((p) => p.$2 >= target).firstOrNull?.$1,
  );
}

/// (an, birikmiş değer), eskiden yeniye.
typedef _Point = (DateTime, double);

List<_Point> _cumulative(List<_Point> deltas) {
  deltas.sort((a, b) => a.$1.compareTo(b.$1));
  var total = 0.0;
  return [for (final (time, delta) in deltas) (time, total += delta)];
}

List<_Point> _points(
  QuestPick pick,
  QuestInputs inputs,
  List<SessionVerdict> sessions,
  bool Function(DateTime) inWeek,
) {
  switch (pick.kind) {
    case QuestKind.workouts:
      return _cumulative([for (final v in sessions) (v.finishedAt, 1)]);
    case QuestKind.sets:
      return _cumulative([for (final v in sessions) (v.finishedAt, v.countedSets.length.toDouble())]);
    case QuestKind.volume:
      return _cumulative([for (final v in sessions) (v.finishedAt, _volume(v))]);
    case QuestKind.long:
      return _cumulative([
        for (final v in sessions)
          if (v.session.finishedAt!.difference(v.session.startedAt) >= longWorkout) (v.finishedAt, 1),
      ]);
    case QuestKind.record:
      return _cumulative([
        for (final t in inputs.recordTimes)
          if (inWeek(t)) (t, 1),
      ]);
    case QuestKind.muscle:
      return _cumulative([
        for (final v in sessions) (v.finishedAt, _muscleSets(v, pick.muscle!, inputs.exercisesById)),
      ]);
    case QuestKind.variety:
      final load = <String, double>{};
      final points = <_Point>[];
      for (final v in sessions) {
        for (final muscle in muscleGroups) {
          final sets = _muscleSets(v, muscle, inputs.exercisesById);
          if (sets > 0) load[muscle] = (load[muscle] ?? 0) + sets;
        }
        points.add((v.finishedAt, load.values.where((sets) => sets >= varietyMinSets).length.toDouble()));
      }
      return points;
    case QuestKind.weekend:
      return _cumulative([
        for (final v in sessions)
          if (v.finishedAt.weekday >= DateTime.saturday) (v.finishedAt, 1),
      ]);
    case QuestKind.mealDays:
      return _cumulative([for (final t in _firstMealByDay(inputs.mealTimes, inWeek).values) (t, 1)]);
    case QuestKind.fullDays:
      final meals = _firstMealByDay(inputs.mealTimes, inWeek);
      final workouts = <DateTime, DateTime>{};
      for (final v in sessions) {
        workouts.putIfAbsent(localDay(v.finishedAt), () => v.finishedAt);
      }
      return _cumulative([
        for (final MapEntry(key: day, value: workoutAt) in workouts.entries)
          if (meals[day] case final mealAt?) (workoutAt.isAfter(mealAt) ? workoutAt : mealAt, 1),
      ]);
  }
}

double _target(QuestKind kind, QuestInputs inputs, DateTime weekStart) => switch (kind) {
      QuestKind.workouts => inputs.weeklyGoal.toDouble(),
      QuestKind.sets => _roundUp(_weeklyAverage(inputs, weekStart, (v) => v.countedSets.length.toDouble()) * questGrowth, 5)
          .clamp(minQuestSets, maxQuestSets)
          .toDouble(),
      QuestKind.volume => _roundUp(_weeklyAverage(inputs, weekStart, _volume) * questGrowth, 500)
          .clamp(minQuestVolume, double.maxFinite)
          .toDouble(),
      QuestKind.long => 2,
      QuestKind.record => 1,
      QuestKind.muscle => 8,
      QuestKind.variety => 4,
      QuestKind.weekend => 1,
      QuestKind.mealDays => 5,
      QuestKind.fullDays => 3,
    };

/// [weekStart]'tan önceki 4 haftanın sayılan oturumlarından haftalık ortalama.
double _weeklyAverage(QuestInputs inputs, DateTime weekStart, double Function(SessionVerdict) value) {
  final from = DateTime(weekStart.year, weekStart.month, weekStart.day - 7 * questHistoryWeeks);
  var total = 0.0;
  for (final v in inputs.verdicts) {
    if (v.counted && !v.finishedAt.isBefore(from) && v.finishedAt.isBefore(weekStart)) total += value(v);
  }
  return total / questHistoryWeeks;
}

/// [step]'in katına yukarı; 27500.000000001 gibi kayan nokta artıkları yukarı taşımasın.
int _roundUp(double x, int step) => (x / step - 1e-9).ceil() * step;

/// Sayılan setlerin kg × tekrar toplamı; kilosuz set 0.
double _volume(SessionVerdict v) => v.countedSets.fold(0.0, (sum, s) => sum + (s.weightKg ?? 0) * (s.reps ?? 0));

/// Sayılan setlerin [muscle] için `muscleWeight` toplamı; kası bilinmeyen hareket 0.
double _muscleSets(SessionVerdict v, String muscle, Map<String, Exercise> exercisesById) => v.countedSets.fold(
      0.0,
      (sum, s) =>
          sum +
          switch (exercisesById[s.exerciseId]) {
            final exercise? => muscleWeight(exercise, muscle),
            null => 0.0,
          },
    );

/// Gün → o günün ilk öğün anı (yerel), yalnız [inWeek] içinde.
Map<DateTime, DateTime> _firstMealByDay(List<DateTime> mealTimes, bool Function(DateTime) inWeek) {
  final first = <DateTime, DateTime>{};
  for (final t in [for (final t in mealTimes) t.toLocal()]..sort()) {
    if (inWeek(t)) first.putIfAbsent(localDay(t), () => t);
  }
  return first;
}
