import '../../workout/domain/exercise.dart';
import '../../workout/domain/workout_session.dart';
import 'levels.dart';
import 'titles.dart';
import 'xp_rules.dart';

/// Seviye ekranı ve ana sayfa rozetinin tek kaynağı (O1 spec §7).
class PlayerSummary {
  const PlayerSummary({
    required this.totalXp,
    required this.progress,
    required this.rank,
    required this.breakdown,
    required this.recent,
    required this.titles,
    required this.upcoming,
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

  /// Kayıtlı aktif unvan hâlâ kazanılmışsa o; değilse null.
  TitleProgress? titleById(String? id) => id == null ? null : titles.where((t) => t.id == id).firstOrNull;
}

PlayerSummary playerSummary(
  List<WorkoutSession> sessions,
  List<DateTime> mealTimes,
  Map<String, Exercise> exercisesById,
) {
  final events = xpEvents(sessions, mealTimes);
  final breakdown = xpBreakdown(events);
  final progress = levelFor(breakdown.total);
  final all = titleProgress(sessions, exercisesById);
  return PlayerSummary(
    totalXp: breakdown.total,
    progress: progress,
    rank: rankFor(progress.level),
    breakdown: breakdown,
    recent: events.reversed.take(10).toList(),
    titles: earnedTitles(all),
    upcoming: upcomingTitles(all),
  );
}
