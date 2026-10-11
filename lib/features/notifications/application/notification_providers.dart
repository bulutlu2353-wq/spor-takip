import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../nutrition/application/today_meals_provider.dart';
import '../../nutrition/domain/macro_totals.dart';
import '../../onboarding/application/auth_providers.dart';
import '../../onboarding/application/profile_providers.dart';
import '../../progress/application/progress_providers.dart';
import '../../workout/application/session_providers.dart';
import '../../workout/application/workout_providers.dart';
import '../data/local_reminder_scheduler.dart';
import '../data/notification_settings_store.dart';
import '../data/reminder_scheduler.dart';
import '../domain/notification_settings.dart';
import '../domain/reminder_inputs.dart';
import '../domain/reminder_planner.dart';

/// Yerel bildirimler yalnız mobilde (N1 spec §3.3); testlerde değiştirilir.
final notificationsSupportedProvider = Provider<bool>((ref) => !kIsWeb);

final reminderSchedulerProvider = Provider<ReminderScheduler>((ref) =>
    ref.watch(notificationsSupportedProvider) ? LocalReminderScheduler.instance : const NoopReminderScheduler());

/// Bildirim metinleri uygulamanın seçili dilinde.
final reminderTranslatorProvider = Provider<ReminderTranslator>((ref) => (key, args) => key.tr(namedArgs: args));

final notificationSettingsStoreProvider = Provider<NotificationSettingsStore>((ref) => const NotificationSettingsStore());

class NotificationSettingsNotifier extends AsyncNotifier<NotificationSettings> {
  @override
  Future<NotificationSettings> build() => ref.watch(notificationSettingsStoreProvider).load();

  Future<void> save(NotificationSettings next) async {
    state = AsyncData(next);
    await ref.read(notificationSettingsStoreProvider).save(next);
  }
}

final notificationSettingsProvider =
    AsyncNotifierProvider<NotificationSettingsNotifier, NotificationSettings>(NotificationSettingsNotifier.new);

class NotificationPermissionNotifier extends AsyncNotifier<bool> {
  @override
  Future<bool> build() async {
    try {
      return await ref.watch(reminderSchedulerProvider).hasPermission();
    } catch (e) {
      debugPrint('notification permission check failed: $e');
      return false;
    }
  }

  Future<bool> request() async {
    var granted = false;
    try {
      granted = await ref.read(reminderSchedulerProvider).requestPermission();
    } catch (e) {
      debugPrint('notification permission request failed: $e');
    }
    state = AsyncData(granted);
    return granted;
  }
}

final notificationPermissionProvider =
    AsyncNotifierProvider<NotificationPermissionNotifier, bool>(NotificationPermissionNotifier.new);

/// Dokunulan (ya da uygulamayı açan) bildirimin rotası; AppShell alır ve gider.
class PendingNotificationRoute extends Notifier<String?> {
  @override
  String? build() => null;

  void open(String route) => state = route;

  String? take() {
    final route = state;
    state = null;
    return route;
  }
}

final pendingNotificationRouteProvider =
    NotifierProvider<PendingNotificationRoute, String?>(PendingNotificationRoute.new);

/// Son kurulan planın imzası (bellekte); `''` = hepsi iptal. Aynıysa yeniden kurulmaz.
class LastScheduledReminders extends Notifier<String?> {
  @override
  String? build() => null;

  void remember(String? signature) => state = signature;
}

final lastScheduledRemindersProvider =
    NotifierProvider<LastScheduledReminders, String?>(LastScheduledReminders.new);

/// Eklentiyi bir kez kurar ve çıkışta bildirimleri iptal eder (SporTakipApp izler).
final notificationBootstrapProvider = FutureProvider<void>((ref) async {
  final scheduler = ref.watch(reminderSchedulerProvider);
  final pending = ref.read(pendingNotificationRouteProvider.notifier);
  ref.listen(isLoggedInProvider, (previous, next) {
    if (previous != true || next) return;
    ref.read(lastScheduledRemindersProvider.notifier).remember('');
    scheduler.cancelAll().catchError((Object e) => debugPrint('cancel reminders failed: $e'));
  });
  try {
    final launch = await scheduler.init(pending.open);
    if (launch != null) pending.open(launch);
  } catch (e, st) {
    debugPrint('notification init failed: $e\n$st');
  }
});

/// Önümüzdeki 7 günün hatırlatıcılarını kurar (N1 spec §4.3); AppShell dil koduyla izler.
/// Plan bir öncekinden farklıysa `replaceAll`; kapalıyken, izin ya da oturum yokken `cancelAll`.
final notificationSyncProvider = FutureProvider.autoDispose.family<void, String>((ref, languageCode) async {
  final scheduler = ref.watch(reminderSchedulerProvider);
  Future<void> apply(String signature, Future<void> Function() action) async {
    if (ref.read(lastScheduledRemindersProvider) == signature) return;
    try {
      await action();
      ref.read(lastScheduledRemindersProvider.notifier).remember(signature);
    } catch (e, st) {
      debugPrint('notificationSync failed: $e\n$st');
    }
  }

  final loggedIn = ref.watch(isLoggedInProvider);
  final settings = await ref.watch(notificationSettingsProvider.future);
  final allowed = await ref.watch(notificationPermissionProvider.future);
  if (!loggedIn || !settings.anyEnabled || !allowed) return apply('', scheduler.cancelAll);

  final now = ref.read(nowProvider)();
  _refreshOnResume(ref, now);
  final (today, sessions, meals, profile) = await (
    ref.watch(todayWorkoutProvider.future),
    ref.watch(recentSessionsProvider.future),
    ref.watch(todayMealsProvider.future),
    ref.watch(profileProvider.future),
  ).wait;
  final plan = planReminders(
    settings: settings,
    now: now,
    workoutNames: workoutNamesByWeekday(today),
    workoutDoneToday: finishedOn(sessions, now),
    mealTypesToday: {for (final meal in meals) meal.mealType},
    nutritionToday: sumMealMacros(meals),
    targets: profile == null
        ? null
        : NutritionTargets(calories: profile.dailyCalorieTarget, proteinG: profile.dailyProteinTargetG),
    weeklyGoal: programOf(today)?.effectiveDaysPerWeek,
    weeklyDone: finishedThisWeek(sessions, now),
  );
  final tr = ref.read(reminderTranslatorProvider);
  await apply('$languageCode|${plan.join(';')}', () => scheduler.replaceAll(plan, tr));
});

/// Uygulama ön plana dönünce yeniden planlar; gün değiştiyse bugünün verisi tazelenir.
void _refreshOnResume(Ref ref, DateTime plannedAt) {
  final listener = AppLifecycleListener(onResume: () {
    if (!DateUtils.isSameDay(ref.read(nowProvider)(), plannedAt)) {
      ref
        ..invalidate(todayMealsProvider)
        ..invalidate(todayWorkoutProvider);
    }
    ref.invalidateSelf();
  });
  ref.onDispose(listener.dispose);
}
