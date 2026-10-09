import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../progress/application/progress_providers.dart';
import '../../workout/application/muscle_heat_providers.dart';
import '../domain/player_summary.dart';

/// Tüm geçmişten XP, seviye, rütbe ve unvanlar (O1 spec §7). Antrenman bitince
/// `allSessionsProvider`, öğün kaydedilince `mealTimesProvider` geçersiz kılınır.
final playerSummaryProvider = FutureProvider.autoDispose<PlayerSummary>((ref) async {
  final (sessions, mealTimes, exercisesById) = await (
    ref.watch(allSessionsProvider.future),
    ref.watch(mealTimesProvider.future),
    ref.watch(exercisesByIdProvider.future),
  ).wait;
  return playerSummary(sessions, mealTimes, exercisesById);
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
