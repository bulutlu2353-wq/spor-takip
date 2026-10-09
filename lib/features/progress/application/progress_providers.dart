import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase_client.dart';
import '../../nutrition/domain/meal.dart';
import '../../onboarding/application/auth_providers.dart';
import '../../workout/application/session_providers.dart';
import '../../workout/domain/workout_session.dart';
import '../data/body_measurement_repository.dart';
import '../data/body_weight_repository.dart';
import '../data/progress_data_repository.dart';
import '../domain/body_measurement.dart';
import '../domain/body_weight_log.dart';
import '../domain/strength.dart';
import '../domain/weekly_summary.dart';

final progressDataRepositoryProvider = Provider<ProgressDataRepository>((ref) {
  return SupabaseProgressDataRepository(AppSupabase.client);
});

final bodyWeightRepositoryProvider = Provider<BodyWeightRepository>((ref) {
  return SupabaseBodyWeightRepository(AppSupabase.client);
});

final bodyMeasurementRepositoryProvider = Provider<BodyMeasurementRepository>((ref) {
  return SupabaseBodyMeasurementRepository(AppSupabase.client);
});

/// Eskiden yeniye; kilo kaydı/silme sonrası invalidate edilir.
final weightLogsProvider = FutureProvider.autoDispose<List<BodyWeightLog>>((ref) async {
  if (!ref.watch(isLoggedInProvider)) return const [];
  return ref.watch(bodyWeightRepositoryProvider).fetchLogs();
});

/// Eskiden yeniye; ölçüm kaydı/silme sonrası invalidate edilir.
final measurementsProvider = FutureProvider.autoDispose<List<BodyMeasurement>>((ref) async {
  if (!ref.watch(isLoggedInProvider)) return const [];
  return ref.watch(bodyMeasurementRepositoryProvider).fetchMeasurements();
});

/// Son 90 günün bitmiş oturumları (güç kartı, haftalık özet).
/// Antrenman bitince/silinince invalidate edilir.
final recentSessionsProvider = FutureProvider.autoDispose<List<WorkoutSession>>((ref) async {
  if (!ref.watch(isLoggedInProvider)) return const [];
  final now = ref.watch(nowProvider)();
  return ref
      .watch(progressDataRepositoryProvider)
      .fetchFinishedSessions(since: DateTime(now.year, now.month, now.day - 90));
});

/// Tüm bitmiş oturumlar (güç ekranı).
final allSessionsProvider = FutureProvider.autoDispose<List<WorkoutSession>>((ref) async {
  if (!ref.watch(isLoggedInProvider)) return const [];
  return ref.watch(progressDataRepositoryProvider).fetchFinishedSessions();
});

/// Geçen hafta ve bu haftanın öğünleri; öğün kaydedilince invalidate edilir.
final weeklyMealsProvider = FutureProvider.autoDispose<List<Meal>>((ref) async {
  if (!ref.watch(isLoggedInProvider)) return const [];
  final start = startOfWeek(ref.watch(nowProvider)());
  return ref.watch(progressDataRepositoryProvider).fetchMeals(
        from: DateTime(start.year, start.month, start.day - 7),
        to: DateTime(start.year, start.month, start.day + 7),
      );
});

/// Tüm öğünlerin kayıt zamanları (oyunlaştırma öğün günleri); öğün kaydedilince invalidate edilir.
final mealTimesProvider = FutureProvider.autoDispose<List<DateTime>>((ref) async {
  if (!ref.watch(isLoggedInProvider)) return const [];
  return ref.watch(progressDataRepositoryProvider).fetchMealTimes();
});

final weeklySummaryProvider = FutureProvider.autoDispose<WeeklySummary>((ref) async {
  final now = ref.watch(nowProvider)();
  final (sessions, meals, weights) = await (
    ref.watch(recentSessionsProvider.future),
    ref.watch(weeklyMealsProvider.future),
    ref.watch(weightLogsProvider.future),
  ).wait;
  return weeklySummary(now: now, sessions: sessions, meals: meals, weights: weights);
});

/// Ana sayfa güç kartı: son 90 günde en sık yapılan 3 hareket.
final strengthCardProvider = FutureProvider.autoDispose<List<StrengthSeries>>((ref) async {
  final now = ref.watch(nowProvider)();
  final sessions = await ref.watch(recentSessionsProvider.future);
  return topStrengthSeries(strengthSeries(sessions), now);
});

/// Güç ekranı: tüm geçmişteki hareketler, en sık yapılan önce.
final allStrengthSeriesProvider = FutureProvider.autoDispose<List<StrengthSeries>>((ref) async {
  return strengthSeries(await ref.watch(allSessionsProvider.future));
});
