import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../notifications/domain/reminder_inputs.dart';
import '../../onboarding/application/auth_providers.dart';
import '../../onboarding/application/profile_providers.dart';
import '../../onboarding/domain/profile.dart';
import '../../progress/application/progress_providers.dart';
import '../../workout/application/muscle_heat_providers.dart';
import '../../workout/application/workout_providers.dart';
import '../../workout/domain/today_workout.dart';
import '../domain/game_settings.dart';
import '../domain/xp_rules.dart';

/// Haftalık hedef (program → profil → 3) ve görev tohumu için kullanıcı (O4 spec §5).
/// Program ya da profil yüklenemezse o kaynak atlanır.
final gameSettingsProvider = FutureProvider.autoDispose<GameSettings>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  final (today, profile) = await (
    ref.watch(todayWorkoutProvider.future).then<TodayWorkout?>((v) => v, onError: (Object _) => null),
    ref.watch(profileProvider.future).then<Profile?>((v) => v, onError: (Object _) => null),
  ).wait;
  return GameSettings(
    weeklyGoal: weeklyGoalFor(
      programDays: today == null ? null : programOf(today)?.effectiveDaysPerWeek,
      profileDays: profile?.exerciseDaysPerWeek,
    ),
    userId: userId,
    bodyWeightKg: profile?.weightKg,
  );
});

/// Tüm geçmişin XP olayları (seri bonusu + görevler); özet, meydan okuma ve dönem istatistiği paylaşır.
final xpEventsProvider = FutureProvider.autoDispose<List<XpEvent>>((ref) async {
  final (sessions, mealTimes, exercisesById, settings) = await (
    ref.watch(allSessionsProvider.future),
    ref.watch(mealTimesProvider.future),
    ref.watch(exercisesByIdProvider.future),
    ref.watch(gameSettingsProvider.future),
  ).wait;
  return xpEvents(sessions, mealTimes, exercisesById: exercisesById, settings: settings);
});
