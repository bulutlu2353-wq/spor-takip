import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../progress/application/progress_providers.dart';
import '../../social/application/challenge_providers.dart';
import '../../workout/application/muscle_heat_providers.dart';
import '../../workout/application/session_providers.dart';
import '../domain/player_summary.dart';
import 'xp_event_providers.dart';

/// Tüm geçmişten XP, seviye, rütbe, unvanlar (O1 spec §7), meydan okuma ödülleri (S3 spec §3.3),
/// seri ve bu haftanın görevleri (O4 spec §5). Antrenman bitince `allSessionsProvider`, öğün
/// kaydedilince `mealTimesProvider` geçersiz kılınır.
final playerSummaryProvider = FutureProvider.autoDispose<PlayerSummary>((ref) async {
  final (sessions, mealTimes, exercisesById, rewards, settings, events) = await (
    ref.watch(allSessionsProvider.future),
    ref.watch(mealTimesProvider.future),
    ref.watch(exercisesByIdProvider.future),
    ref.watch(challengeRewardsProvider.future),
    ref.watch(gameSettingsProvider.future),
    ref.watch(xpEventsProvider.future),
  ).wait;
  return playerSummary(
    sessions,
    mealTimes,
    exercisesById,
    rewards: rewards,
    settings: settings,
    events: events,
    now: ref.read(nowProvider)(),
  );
});

const activeTitleKey = 'gamification.active_title';

/// Takılı unvanın id'si; cihazda saklanır (O1 spec §6.4). Okunamazsa null.
class ActiveTitle extends AsyncNotifier<String?> {
  @override
  Future<String?> build() async {
    try {
      return (await SharedPreferences.getInstance()).getString(activeTitleKey);
    } catch (_) {
      return null;
    }
  }

  Future<void> equip(String id) async {
    state = AsyncData(id);
    try {
      await (await SharedPreferences.getInstance()).setString(activeTitleKey, id);
    } catch (_) {}
  }

  Future<void> unequip() async {
    state = const AsyncData(null);
    try {
      await (await SharedPreferences.getInstance()).remove(activeTitleKey);
    } catch (_) {}
  }
}

final activeTitleProvider = AsyncNotifierProvider<ActiveTitle, String?>(ActiveTitle.new);

const battleSeenHitKey = 'gamification.battle_seen_hit';

/// En son görülen vuruşun tarihi, cihazda (O2 cila spec §6.1); okunamazsa null.
Future<DateTime?> readSeenHit() async {
  try {
    final raw = (await SharedPreferences.getInstance()).getString(battleSeenHitKey);
    return raw == null ? null : DateTime.tryParse(raw);
  } catch (_) {
    return null;
  }
}

Future<void> writeSeenHit(DateTime date) async {
  try {
    await (await SharedPreferences.getInstance()).setString(battleSeenHitKey, date.toIso8601String());
  } catch (_) {}
}
