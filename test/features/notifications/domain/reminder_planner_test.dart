import 'package:flutter_test/flutter_test.dart';
import 'package:spor_takip/features/notifications/domain/notification_settings.dart';
import 'package:spor_takip/features/notifications/domain/planned_reminder.dart';
import 'package:spor_takip/features/notifications/domain/reminder_planner.dart';
import 'package:spor_takip/features/nutrition/domain/macro_totals.dart';
import 'package:spor_takip/features/nutrition/domain/meal_type.dart';

// Pazartesi öğlen.
final _now = DateTime(2026, 10, 12, 12);
const _off = NotificationSettings.defaults;
const _targets = NutritionTargets(calories: 2700, proteinG: 176);

List<PlannedReminder> _plan(
  NotificationSettings settings, {
  DateTime? now,
  Map<int, String> workoutNames = const {},
  bool workoutDoneToday = false,
  Set<MealType> mealTypesToday = const {},
  MacroTotals nutritionToday = const MacroTotals(),
  NutritionTargets? targets = _targets,
  int? weeklyGoal,
  int weeklyDone = 0,
}) => planReminders(
  settings: settings,
  now: now ?? _now,
  workoutNames: workoutNames,
  workoutDoneToday: workoutDoneToday,
  mealTypesToday: mealTypesToday,
  nutritionToday: nutritionToday,
  targets: targets,
  weeklyGoal: weeklyGoal,
  weeklyDone: weeklyDone,
);

List<DateTime> _times(List<PlannedReminder> plan) => [for (final r in plan) r.at];

void main() {
  test('the fixture day is a Monday', () => expect(_now.weekday, DateTime.monday));

  test('nothing is planned while every card is off', () {
    expect(_plan(_off), isEmpty);
  });

  group('workout', () {
    final on = _off.copyWith(workoutEnabled: true);

    test('lands on the chosen days within seven days', () {
      final plan = _plan(on);
      expect(_times(plan), [DateTime(2026, 10, 12, 18), DateTime(2026, 10, 14, 18), DateTime(2026, 10, 16, 18)]);
      expect(plan.every((r) => r.kind == ReminderKind.workout && r.route == '/home'), isTrue);
      expect(plan.first.titleKey, 'notifications.workout_title');
    });

    test('skips today when the time has passed or a workout is done', () {
      final early = on.copyWith(workoutTime: const ReminderTime(9, 0));
      expect(_times(_plan(early)), [DateTime(2026, 10, 14, 9), DateTime(2026, 10, 16, 9)]);
      expect(_times(_plan(on, workoutDoneToday: true)), [DateTime(2026, 10, 14, 18), DateTime(2026, 10, 16, 18)]);
    });

    test('names the workout when the day has one', () {
      final plan = _plan(on, workoutNames: {DateTime.monday: 'Push A'});
      expect(plan[0].bodyKey, 'notifications.workout_body_named');
      expect(plan[0].args, {'name': 'Push A'});
      expect(plan[1].bodyKey, 'notifications.workout_body');
      expect(plan[1].args, isEmpty);
    });
  });

  group('meals', () {
    final on = _off.copyWith(mealsEnabled: true);

    test('skips today for logged meal types and passed times', () {
      final plan = _plan(on, mealTypesToday: {MealType.lunch});
      final today = plan.where((r) => r.at.day == 12).toList();
      expect(today, hasLength(1));
      expect(today.single.titleKey, 'notifications.meal_title_dinner');
      expect(today.single.route, '/nutrition');
      expect(today.single.bodyKey, 'notifications.meal_body');
      expect(plan, hasLength(1 + 6 * 3));
    });

    test('respects the per-meal and card switches', () {
      final noLunch = on.copyWith(
        meals: {..._off.meals, MealType.lunch: _off.meals[MealType.lunch]!.copyWith(enabled: false)},
      );
      expect(_plan(noLunch).where((r) => r.titleKey == 'notifications.meal_title_lunch'), isEmpty);
      expect(_plan(_off.copyWith(mealsEnabled: false)), isEmpty);
    });
  });

  group('nutrition summary', () {
    final on = _off.copyWith(nutritionEnabled: true);
    PlannedReminder? today(List<PlannedReminder> plan) => plan.where((r) => r.at.day == 12).firstOrNull;

    test('reminds every day; future days say no meal yet', () {
      final plan = _plan(on);
      expect(plan, hasLength(7));
      expect(plan.every((r) => r.bodyKey == 'notifications.nutrition_none'), isTrue);
      expect(plan.first.at, DateTime(2026, 10, 12, 21));
      expect(plan.first.titleKey, 'notifications.nutrition_title');
    });

    test('protein comes before calories', () {
      final plan = _plan(
        on,
        mealTypesToday: {MealType.lunch},
        nutritionToday: const MacroTotals(calories: 1500, proteinG: 100.4),
      );
      expect(today(plan)!.bodyKey, 'notifications.nutrition_protein');
      expect(today(plan)!.args, {'g': '76'});
    });

    test('calories when protein is met', () {
      final plan = _plan(
        on,
        mealTypesToday: {MealType.lunch},
        nutritionToday: const MacroTotals(calories: 2000, proteinG: 180),
      );
      expect(today(plan)!.bodyKey, 'notifications.nutrition_kcal');
      expect(today(plan)!.args, {'kcal': '700'});
    });

    test('nothing today when both are met or there is no profile', () {
      final met = _plan(
        on,
        mealTypesToday: {MealType.lunch},
        nutritionToday: const MacroTotals(calories: 2800, proteinG: 180),
      );
      expect(today(met), isNull);
      expect(met, hasLength(6));
      expect(today(_plan(on, mealTypesToday: {MealType.lunch}, targets: null)), isNull);
      expect(today(_plan(on, targets: null))!.bodyKey, 'notifications.nutrition_none');
    });
  });

  group('weekly goal', () {
    final on = _off.copyWith(weeklyEnabled: true);

    test('reminds on the chosen day of this week with the remaining days', () {
      final plan = _plan(on, weeklyGoal: 4, weeklyDone: 1);
      expect(plan, hasLength(1));
      expect(plan.single.at, DateTime(2026, 10, 16, 19));
      expect(plan.single.bodyKey, 'notifications.weekly_body');
      expect(plan.single.args, {'done': '1', 'goal': '4', 'left': '3'});
      expect(plan.single.route, '/home');
    });

    test('nothing when the goal is met or unknown', () {
      expect(_plan(on, weeklyGoal: 4, weeklyDone: 4), isEmpty);
      expect(_plan(on, weeklyGoal: null), isEmpty);
    });

    test('only this ISO week counts', () {
      final monday = on.copyWith(weeklyDay: DateTime.monday);
      expect(_plan(monday, weeklyGoal: 3).single.args['left'], '7');
      expect(_plan(monday, weeklyGoal: 3, now: DateTime(2026, 10, 13, 12)), isEmpty);
    });
  });

  test('ids are unique, stable per day and the plan is sorted by time', () {
    final all = _off.copyWith(workoutEnabled: true, mealsEnabled: true, nutritionEnabled: true, weeklyEnabled: true);
    final plan = _plan(all, weeklyGoal: 3);
    expect({for (final r in plan) r.id}, hasLength(plan.length));
    expect(_times(plan), [..._times(plan)]..sort());
    expect(
      reminderId(ReminderKind.workout, DateTime(2026, 10, 12)),
      reminderId(ReminderKind.workout, DateTime(2026, 10, 12, 23, 59)),
    );
    expect(
      reminderId(ReminderKind.meal, DateTime(2026, 10, 12), MealType.lunch),
      isNot(reminderId(ReminderKind.meal, DateTime(2026, 10, 12), MealType.dinner)),
    );
    expect(plan.every((r) => r.id > 0 && r.id < 1 << 31), isTrue);
    expect(_plan(all, weeklyGoal: 3), plan);
  });
}
