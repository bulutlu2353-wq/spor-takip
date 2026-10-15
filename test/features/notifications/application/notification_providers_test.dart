import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spor_takip/features/notifications/application/notification_providers.dart';
import 'package:spor_takip/features/notifications/data/notification_settings_store.dart';
import 'package:spor_takip/features/notifications/domain/notification_settings.dart';
import 'package:spor_takip/features/nutrition/application/today_meals_provider.dart';
import 'package:spor_takip/features/onboarding/application/auth_providers.dart';
import 'package:spor_takip/features/onboarding/application/profile_providers.dart';
import 'package:spor_takip/features/progress/application/progress_providers.dart';
import 'package:spor_takip/features/workout/application/session_providers.dart';
import 'package:spor_takip/features/workout/application/workout_providers.dart';
import 'package:spor_takip/features/workout/domain/program.dart';
import 'package:spor_takip/features/workout/domain/program_workout.dart';
import 'package:spor_takip/features/workout/domain/schedule_mode.dart';
import 'package:spor_takip/features/workout/domain/today_workout.dart';
import 'package:spor_takip/features/workout/domain/workout_session.dart';

import '../../gamification/game_fixtures.dart';
import '../../progress/fixtures.dart';
import '../fakes.dart';

const _push = ProgramWorkout(name: 'Push A', exercises: [], weekday: 1);
const _legs = ProgramWorkout(name: 'Legs', exercises: [], weekday: 3);
const _program = Program(name: 'P', scheduleMode: ScheduleMode.weekdays, workouts: [_push, _legs]);

void _store(NotificationSettings settings) =>
    SharedPreferences.setMockInitialValues({notificationSettingsKey: jsonEncode(settings.toJson())});

ProviderContainer _container(
  FakeReminderScheduler scheduler, {
  bool loggedIn = true,
  TodayWorkout today = const NoActiveProgram(),
  List<WorkoutSession> sessions = const [],
}) {
  final container = ProviderContainer(
    retry: (retryCount, error) => null,
    overrides: [
      reminderSchedulerProvider.overrideWithValue(scheduler),
      reminderTranslatorProvider.overrideWithValue((key, args) => '$key$args'),
      isLoggedInProvider.overrideWithValue(loggedIn),
      nowProvider.overrideWithValue(() => DateTime(2026, 10, 12, 12)),
      todayWorkoutProvider.overrideWith((ref) async => today),
      recentSessionsProvider.overrideWith((ref) async => sessions),
      todayMealsProvider.overrideWith((ref) async => const []),
      profileProvider.overrideWith((ref) async => testProfile),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

Future<void> _sync(ProviderContainer container, [String lang = 'tr']) async {
  container.listen(notificationSyncProvider(lang), (_, _) {});
  await container.read(notificationSyncProvider(lang).future);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('with every card off it only cancels, once', () async {
    final scheduler = FakeReminderScheduler();
    final container = _container(scheduler);
    await _sync(container);
    container.invalidate(notificationSyncProvider('tr'));
    await _sync(container);
    expect(scheduler.replaced, isEmpty);
    expect(scheduler.cancels, 1);
  });

  test('schedules the plan once and again only when it changes', () async {
    _store(NotificationSettings.defaults.copyWith(workoutEnabled: true, workoutDaysInitialized: true));
    final scheduler = FakeReminderScheduler();
    final container = _container(scheduler);

    await _sync(container);
    expect(scheduler.replaced, hasLength(1));
    expect(scheduler.replaced.single, hasLength(3));
    expect(scheduler.translated.single.first, 'notifications.workout_body{}');

    container.invalidate(notificationSyncProvider('tr'));
    await _sync(container);
    expect(scheduler.replaced, hasLength(1));

    final settings = await container.read(notificationSettingsProvider.future);
    await container.read(notificationSettingsProvider.notifier).save(settings.copyWith(workoutTime: const ReminderTime(19, 0)));
    await _sync(container);
    expect(scheduler.replaced, hasLength(2));
    expect(scheduler.replaced.last.first.at, DateTime(2026, 10, 12, 19));
  });

  test('a language change reschedules', () async {
    _store(NotificationSettings.defaults.copyWith(nutritionEnabled: true));
    final scheduler = FakeReminderScheduler();
    final container = _container(scheduler);
    await _sync(container, 'tr');
    await _sync(container, 'en');
    expect(scheduler.replaced, hasLength(2));
  });

  test('without permission or a session nothing is scheduled', () async {
    _store(NotificationSettings.defaults.copyWith(workoutEnabled: true));
    final denied = FakeReminderScheduler(permission: false);
    await _sync(_container(denied));
    expect(denied.replaced, isEmpty);
    expect(denied.cancels, 1);

    final loggedOut = FakeReminderScheduler();
    await _sync(_container(loggedOut, loggedIn: false));
    expect(loggedOut.replaced, isEmpty);
    expect(loggedOut.cancels, 1);
  });

  test('uses the program, the finished workout and the weekly goal', () async {
    _store(NotificationSettings.defaults.copyWith(
      workoutEnabled: true,
      workoutDays: {1, 3},
      workoutDaysInitialized: true,
      weeklyEnabled: true,
    ));
    final scheduler = FakeReminderScheduler();
    final container = _container(
      scheduler,
      today: const ScheduledWorkout(_program, 0, _push),
      sessions: [gameSession('s', DateTime(2026, 10, 12, 10), const [])],
    );
    await _sync(container);
    final plan = scheduler.replaced.single;
    expect([for (final r in plan) r.at], [DateTime(2026, 10, 14, 18), DateTime(2026, 10, 16, 19)]);
    expect(plan.first.args, {'name': 'Legs'});
    expect(plan.last.args, {'done': '1', 'goal': '2', 'left': '3'});
  });

  test('saved settings survive a new container', () async {
    final first = _container(FakeReminderScheduler());
    await first.read(notificationSettingsProvider.future);
    await first.read(notificationSettingsProvider.notifier).save(NotificationSettings.defaults.copyWith(weeklyEnabled: true));
    final second = _container(FakeReminderScheduler());
    expect((await second.read(notificationSettingsProvider.future)).weeklyEnabled, isTrue);
  });

  test('requesting permission updates its state', () async {
    final scheduler = FakeReminderScheduler(permission: false, requestResult: true);
    final container = _container(scheduler);
    container.listen(notificationPermissionProvider, (_, _) {});
    expect(await container.read(notificationPermissionProvider.future), isFalse);
    expect(await container.read(notificationPermissionProvider.notifier).request(), isTrue);
    expect(container.read(notificationPermissionProvider).value, isTrue);
  });

  test('bootstrap passes the launch and tapped routes on, and cancels on sign-out', () async {
    final scheduler = FakeReminderScheduler(launchRoute: '/nutrition');
    final container = _container(scheduler);
    await container.read(notificationBootstrapProvider.future);
    expect(container.read(pendingNotificationRouteProvider.notifier).take(), '/nutrition');
    expect(container.read(pendingNotificationRouteProvider), isNull);
    scheduler.onTap!('/home');
    expect(container.read(pendingNotificationRouteProvider), '/home');
  });
}
