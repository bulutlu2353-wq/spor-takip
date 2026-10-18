import '../../progress/domain/strength.dart';
import '../../workout/domain/exercise.dart';
import '../../workout/domain/workout_session.dart';
import 'fair_play.dart';
import 'game_settings.dart';
import 'quests.dart';
import 'streak.dart';

/// XP olayının kaynağı (O1 spec §3; meydan okuma ödülü S3 spec §3.3; görev O4 spec §4.3).
enum XpSource { workout, record, mealDay, challenge, quest }

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
    this.streakBonus = 0,
    this.streakPercent = 0,
    this.muscle,
    this.target,
    this.muscleSets = const {},
  });

  final XpSource source;

  /// Yerel: antrenman ve rekorda bitiş, öğünde günün başı.
  final DateTime date;
  final int xp;

  /// Antrenman: antrenman adı; rekor: hareket adı; görev: görev türü; öğün: null.
  final String? label;

  /// Yalnız antrenmanda: sayılan set (O3a süre tavanıyla).
  final int sets;

  /// Yalnız rekorda: en iyi setin kilosu ve tekrarı.
  final double? weightKg;
  final int? reps;

  /// Yalnız antrenmanda: XP getirmediyse nedeni (O3a spec §3.3).
  final SkipReason? skip;

  /// Yalnız antrenmanda: seri bonusu (XP'ye dahil) ve yüzdesi (O4 spec §3.3).
  final int streakBonus;
  final int streakPercent;

  /// Yalnız görevde: kas görevinin kası ve görevin hedefi; `label` görev türü (`QuestKind.name` ya da 'all').
  final String? muscle;
  final double? target;

  /// Yalnız sayılan antrenmanda: sayılan setlerin ana kasa göre sayısı (O2a spec §6).
  final Map<String, int> muscleSets;
}

const xpPerWorkout = 50;
const xpPerSet = 5;
const xpPerRecord = 25;
const xpPerMealDay = 10;

/// Eskiden yeniye; aynı anda antrenman → rekor → öğün → meydan okuma → görev. Kurallar: O3a spec §3.
/// [settings] null → seri bonusu ve görev yok (O4 spec §5); `userId` null → görev yok.
List<XpEvent> xpEvents(
  List<WorkoutSession> sessions,
  List<DateTime> mealTimes, {
  Map<String, Exercise> exercisesById = const {},
  GameSettings? settings,
}) {
  final events = <XpEvent>[];
  final best = <String, double>{};
  final lastRecord = <String, DateTime>{};
  final verdicts = judgeSessions(sessions);
  final lengths = settings == null
      ? const <DateTime, int>{}
      : workoutStreakLengths(verdicts, weeklyGoal: settings.weeklyGoal);
  for (final verdict in verdicts) {
    final sets = verdict.countedSets.length;
    final base = verdict.counted ? xpPerWorkout + sets * xpPerSet : 0;
    final percent = verdict.counted ? streakBonusPercent(lengths[localDay(verdict.finishedAt)] ?? 0) : 0;
    final bonus = base * percent ~/ 100;
    events.add(XpEvent(
      source: XpSource.workout,
      date: verdict.finishedAt,
      xp: base + bonus,
      label: verdict.session.workoutName,
      sets: sets,
      skip: verdict.skip,
      streakBonus: bonus,
      streakPercent: percent,
      muscleSets: verdict.counted ? _muscleSets(verdict.countedSets, exercisesById) : const {},
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

  if (settings case GameSettings(userId: final userId?, :final weeklyGoal)) {
    final inputs = QuestInputs(
      verdicts: verdicts,
      recordTimes: [
        for (final e in events)
          if (e.source == XpSource.record) e.date,
      ],
      mealTimes: mealTimes,
      exercisesById: exercisesById,
      weeklyGoal: weeklyGoal,
    );
    events.addAll(_questEvents(inputs, userId));
  }

  events.sort(compareXpEvents);
  return events;
}

/// Her haftanın biten görevleri (40 XP) ve üçü bittiyse bonus (60 XP) (O4 spec §4.3).
List<XpEvent> _questEvents(QuestInputs inputs, String userId) {
  final events = <XpEvent>[];
  for (final weekStart in questWeeks(inputs)) {
    final week = weekQuests(inputs, userId: userId, weekStart: weekStart);
    for (final q in week.quests) {
      if (q.doneAt case final at?) {
        events.add(XpEvent(
          source: XpSource.quest,
          date: at,
          xp: xpPerQuest,
          label: q.kind.name,
          muscle: q.muscle,
          target: q.target,
        ));
      }
    }
    if (week.bonusAt case final at?) {
      events.add(XpEvent(source: XpSource.quest, date: at, xp: xpAllQuests, label: allQuestsLabel));
    }
  }
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

/// Sayılan setlerin ilk ana kasa göre sayısı; kas bilgisi olmayan hareket atlanır.
Map<String, int> _muscleSets(List<SessionSet> sets, Map<String, Exercise> exercisesById) {
  final counts = <String, int>{};
  for (final set in sets) {
    final muscle = exercisesById[set.exerciseId]?.primaryMuscles.firstOrNull;
    if (muscle != null) counts[muscle] = (counts[muscle] ?? 0) + 1;
  }
  return counts;
}

/// Eskiden yeniye; aynı anda kaynak sırasıyla (antrenman → rekor → öğün → meydan okuma → görev).
int compareXpEvents(XpEvent a, XpEvent b) {
  final byDate = a.date.compareTo(b.date);
  return byDate != 0 ? byDate : a.source.index.compareTo(b.source.index);
}

/// Seviye ekranındaki döküm: antrenman tabanı, setler, rekorlar, öğün günleri, meydan okumalar,
/// seri bonusu, görevler.
class XpBreakdown {
  const XpBreakdown({
    this.workouts = 0,
    this.sets = 0,
    this.records = 0,
    this.mealDays = 0,
    this.challenges = 0,
    this.streak = 0,
    this.quests = 0,
  });

  final int workouts;
  final int sets;
  final int records;
  final int mealDays;
  final int challenges;
  final int streak;
  final int quests;

  int get total => workouts + sets + records + mealDays + challenges + streak + quests;
}

XpBreakdown xpBreakdown(List<XpEvent> events) {
  var workouts = 0, sets = 0, records = 0, mealDays = 0, challenges = 0, streak = 0, quests = 0;
  for (final e in events) {
    switch (e.source) {
      case XpSource.workout:
        if (e.xp > 0) workouts += xpPerWorkout;
        sets += e.sets * xpPerSet;
        streak += e.streakBonus;
      case XpSource.record:
        records += e.xp;
      case XpSource.mealDay:
        mealDays += e.xp;
      case XpSource.challenge:
        challenges += e.xp;
      case XpSource.quest:
        quests += e.xp;
    }
  }
  return XpBreakdown(
    workouts: workouts,
    sets: sets,
    records: records,
    mealDays: mealDays,
    challenges: challenges,
    streak: streak,
    quests: quests,
  );
}
