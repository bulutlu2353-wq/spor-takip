import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../onboarding/application/profile_providers.dart';
import '../../progress/application/progress_providers.dart';
import '../../progress/domain/progress_format.dart';
import '../../progress/domain/trend.dart';
import '../../workout/application/session_providers.dart';
import '../domain/adaptive_tdee.dart';

/// Beslenme ekranındaki hedef düzeltme önerisi (G3 spec §4.4). Profil yenilenince
/// (uygula / ertele / hedef değişimi) ve kilo kaydında kendiliğinden yeniden hesaplanır.
final calorieSuggestionProvider = FutureProvider.autoDispose<CalorieSuggestion?>((ref) async {
  final now = ref.watch(nowProvider)();
  final today = dateOnly(now);
  final repo = ref.watch(progressDataRepositoryProvider);
  final (profile, logs, meals) = await (
    ref.watch(profileProvider.future),
    ref.watch(weightLogsProvider.future),
    repo.fetchMeals(from: DateTime(today.year, today.month, today.day - suggestionWindowDays), to: today),
  ).wait;
  if (profile == null) return null;
  return suggestCalorieAdjustment(
    profile: profile,
    weights: [for (final log in logs) ValuePoint(log.date, log.weightKg)],
    dailyKcal: dailyCalories(meals),
    now: now,
  );
});
