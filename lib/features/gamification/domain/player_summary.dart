import '../../progress/domain/weekly_summary.dart';
import '../../workout/domain/exercise.dart';
import '../../workout/domain/workout_session.dart';
import 'battle.dart';
import 'battle_stats.dart';
import 'fair_play.dart';
import 'game_settings.dart';
import 'levels.dart';
import 'quests.dart';
import 'streak.dart';
import 'titles.dart';
import 'xp_rules.dart';

/// Seviye ekranı ve ana sayfa rozetinin tek kaynağı (O1 spec §7); savaş (O2a spec §6).
class PlayerSummary {
  const PlayerSummary({
    required this.totalXp,
    required this.progress,
    required this.rank,
    required this.breakdown,
    required this.recent,
    required this.titles,
    required this.upcoming,
    this.streak = StreakStatus.none,
    this.quests,
    this.battle,
  });

  final int totalXp;
  final LevelProgress progress;
  final Rank rank;
  final XpBreakdown breakdown;

  /// Son 10 olay, yeniden eskiye.
  final List<XpEvent> recent;

  /// Kazanılan unvanlar (`earnedTitles` sırası).
  final List<TitleProgress> titles;
  final List<TitleProgress> upcoming;

  /// Güncel seri (O4 spec §3.4); ayar yoksa [StreakStatus.none].
  final StreakStatus streak;

  /// Bu haftanın görevleri; kullanıcı id'si yoksa null.
  final WeekQuests? quests;

  /// Savaş durumu (O2a spec §5); `settings` yoksa null.
  final BattleState? battle;

  /// Kayıtlı aktif unvan hâlâ kazanılmışsa o; değilse null.
  TitleProgress? titleById(String? id) => id == null ? null : titles.where((t) => t.id == id).firstOrNull;
}

/// [rewards]: kesinleşmiş meydan okuma ödülleri (`XpSource.challenge`, S3 spec §3.3).
/// [events]: önceden hesaplanmış `xpEvents` (sağlayıcı paylaşır); null ise burada hesaplanır.
PlayerSummary playerSummary(
  List<WorkoutSession> sessions,
  List<DateTime> mealTimes,
  Map<String, Exercise> exercisesById, {
  List<XpEvent> rewards = const [],
  GameSettings? settings,
  List<XpEvent>? events,
  DateTime? now,
}) {
  final all = [
    ...(events ?? xpEvents(sessions, mealTimes, exercisesById: exercisesById, settings: settings)),
    ...rewards,
  ]..sort(compareXpEvents);
  final breakdown = xpBreakdown(all);
  final progress = levelFor(breakdown.total);
  final titles = titleProgress(sessions, exercisesById, challengeWins: rewards.length);
  final today = now ?? DateTime.now();
  final verdicts = settings == null ? const <SessionVerdict>[] : judgeSessions(sessions);
  final fight = switch (settings) {
    GameSettings(:final weeklyGoal, :final bodyWeightKg) => battle(
        all,
        StatInputs(verdicts: verdicts, weeklyGoal: weeklyGoal, bodyWeightKg: bodyWeightKg),
        today: today,
      ),
    null => null,
  };
  return PlayerSummary(
    totalXp: breakdown.total,
    progress: progress,
    rank: gatedRank(progress.level, fight),
    battle: fight,
    breakdown: breakdown,
    recent: all.reversed.take(10).toList(),
    titles: earnedTitles(titles),
    upcoming: upcomingTitles(titles),
    streak: settings == null
        ? StreakStatus.none
        : streakStatus(verdicts, weeklyGoal: settings.weeklyGoal, today: today),
    quests: switch (settings) {
      GameSettings(userId: final userId?, :final weeklyGoal) => weekQuests(
          QuestInputs(
            verdicts: verdicts,
            recordTimes: [
              for (final e in all)
                if (e.source == XpSource.record) e.date,
            ],
            mealTimes: mealTimes,
            exercisesById: exercisesById,
            weeklyGoal: weeklyGoal,
          ),
          userId: userId,
          weekStart: startOfWeek(today),
        ),
      _ => null,
    },
  );
}
