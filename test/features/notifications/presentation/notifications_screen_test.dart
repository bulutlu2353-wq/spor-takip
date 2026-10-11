import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spor_takip/features/notifications/application/notification_providers.dart';
import 'package:spor_takip/features/notifications/data/notification_settings_store.dart';
import 'package:spor_takip/features/notifications/domain/notification_settings.dart';
import 'package:spor_takip/features/notifications/presentation/notifications_screen.dart';
import 'package:spor_takip/features/nutrition/domain/meal_type.dart';
import 'package:spor_takip/features/workout/application/workout_providers.dart';
import 'package:spor_takip/features/workout/domain/program.dart';
import 'package:spor_takip/features/workout/domain/program_workout.dart';
import 'package:spor_takip/features/workout/domain/schedule_mode.dart';
import 'package:spor_takip/features/workout/domain/today_workout.dart';

import '../../progress/presentation/test_app.dart';
import '../fakes.dart';

const _program = Program(
  name: 'P',
  scheduleMode: ScheduleMode.weekdays,
  workouts: [
    ProgramWorkout(name: 'A', exercises: [], weekday: 2),
    ProgramWorkout(name: 'B', exercises: [], weekday: 4),
  ],
);

void main() {
  setUpAll(initTestLocalization);
  setUp(() => SharedPreferences.setMockInitialValues({}));

  late FakeReminderScheduler scheduler;

  Future<void> pump(
    WidgetTester tester, {
    bool supported = true,
    bool permission = true,
    bool requestResult = true,
    TimeOfDay? picked,
    double width = 800,
  }) async {
    scheduler = FakeReminderScheduler(permission: permission, requestResult: requestResult);
    tester.view.physicalSize = Size(width, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(testApp(
      NotificationsScreen(pickTime: (context, initial) async => picked),
      scaffold: false,
      overrides: [
        reminderSchedulerProvider.overrideWithValue(scheduler),
        notificationsSupportedProvider.overrideWithValue(supported),
        todayWorkoutProvider.overrideWith((ref) async => const RestDay(_program)),
      ],
    ));
    await tester.pumpAndSettle();
  }

  Future<NotificationSettings> stored() => const NotificationSettingsStore().load();

  bool switchValue(WidgetTester tester, String key) => tester.widget<SwitchListTile>(find.byKey(Key(key))).value;

  testWidgets('shows four cards, all off, with the default times', (tester) async {
    await pump(tester);
    for (final card in ['workout', 'meals', 'nutrition', 'weekly']) {
      expect(switchValue(tester, 'notif_${card}_switch'), isFalse);
    }
    String time(String key) => tester.widget<Text>(find.descendant(of: find.byKey(Key(key)), matching: find.byType(Text))).data!;
    expect(time('notif_workout_time'), '18:00');
    expect(time('notif_meal_breakfast_time'), '09:00');
    expect(time('notif_meal_lunch_time'), '13:00');
    expect(time('notif_meal_dinner_time'), '19:30');
    expect(time('notif_nutrition_time'), '21:00');
    expect(time('notif_weekly_time'), '19:00');
    expect(find.byKey(const Key('notifications_web_note')), findsNothing);
    expect(find.byKey(const Key('notifications_permission_warning')), findsNothing);
  });

  testWidgets('workout days start from the program and turning on saves them', (tester) async {
    await pump(tester, permission: false);
    bool selected(int day) => tester.widget<FilterChip>(find.byKey(Key('notif_workout_day_$day'))).selected;
    expect([for (var d = 1; d <= 7; d++) if (selected(d)) d], [2, 4]);

    await tester.tap(find.byKey(const Key('notif_workout_switch')));
    await tester.pumpAndSettle();
    expect(scheduler.permissionRequests, 1);
    final saved = await stored();
    expect(saved.workoutEnabled, isTrue);
    expect(saved.workoutDays, {2, 4});
    expect(saved.workoutDaysInitialized, isTrue);

    await tester.tap(find.byKey(const Key('notif_workout_day_1')));
    await tester.pumpAndSettle();
    expect((await stored()).workoutDays, {1, 2, 4});
  });

  testWidgets('a picked time is shown and saved', (tester) async {
    await pump(tester, picked: const TimeOfDay(hour: 7, minute: 45));
    await tester.tap(find.byKey(const Key('notif_nutrition_time')));
    await tester.pumpAndSettle();
    expect(find.text('07:45'), findsOneWidget);
    expect((await stored()).nutritionTime, const ReminderTime(7, 45));
  });

  testWidgets('a single meal can be turned off', (tester) async {
    await pump(tester);
    await tester.tap(find.byKey(const Key('notif_meals_switch')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('notif_meal_lunch_switch')));
    await tester.pumpAndSettle();
    final saved = await stored();
    expect(saved.mealsEnabled, isTrue);
    expect(saved.meals[MealType.lunch]!.enabled, isFalse);
    expect(saved.meals[MealType.dinner]!.enabled, isTrue);
  });

  testWidgets('the weekly day can be changed', (tester) async {
    await pump(tester);
    await tester.tap(find.byKey(const Key('notif_weekly_day')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('home.weekday_3').last);
    await tester.pumpAndSettle();
    expect((await stored()).weeklyDay, DateTime.wednesday);
  });

  testWidgets('a denied permission shows the warning with a settings button', (tester) async {
    await pump(tester, permission: false, requestResult: false);
    await tester.tap(find.byKey(const Key('notif_weekly_switch')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('notifications_permission_warning')), findsOneWidget);
    expect((await stored()).weeklyEnabled, isTrue);
    await tester.tap(find.byKey(const Key('notifications_open_settings')));
    await tester.pumpAndSettle();
    expect(scheduler.settingsOpened, 1);
  });

  testWidgets('on the web the page explains and the switches are off', (tester) async {
    await pump(tester, supported: false);
    expect(find.byKey(const Key('notifications_web_note')), findsOneWidget);
    expect(tester.widget<SwitchListTile>(find.byKey(const Key('notif_workout_switch'))).onChanged, isNull);
  });

  testWidgets('fits a 360 px wide phone', (tester) async {
    await pump(tester, width: 360);
    expect(tester.takeException(), isNull);
  });
}
