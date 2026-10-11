import 'package:flutter_test/flutter_test.dart';
import 'package:spor_takip/features/notifications/domain/notification_settings.dart';
import 'package:spor_takip/features/nutrition/domain/meal_type.dart';
import 'package:spor_takip/features/workout/domain/program.dart';
import 'package:spor_takip/features/workout/domain/program_workout.dart';
import 'package:spor_takip/features/workout/domain/schedule_mode.dart';

Program _program(ScheduleMode mode, List<int?> weekdays) => Program(
      name: 'P',
      scheduleMode: mode,
      workouts: [for (final day in weekdays) ProgramWorkout(name: 'W$day', exercises: const [], weekday: day)],
    );

void main() {
  test('defaults are all off with the spec times', () {
    const s = NotificationSettings.defaults;
    expect(s.anyEnabled, isFalse);
    expect(s.workoutDays, {1, 3, 5});
    expect(s.workoutTime.label, '18:00');
    expect(s.meals[MealType.breakfast]!.time.label, '09:00');
    expect(s.meals[MealType.lunch]!.time.label, '13:00');
    expect(s.meals[MealType.dinner]!.time.label, '19:30');
    expect(reminderMealTypes.every((type) => s.meals[type]!.enabled), isTrue);
    expect(s.nutritionTime.label, '21:00');
    expect(s.weeklyDay, DateTime.friday);
    expect(s.weeklyTime.label, '19:00');
  });

  test('round-trips through JSON', () {
    final s = NotificationSettings.defaults.copyWith(
      workoutEnabled: true,
      workoutDays: {2, 6},
      workoutTime: const ReminderTime(7, 5),
      workoutDaysInitialized: true,
      mealsEnabled: true,
      meals: {
        ...NotificationSettings.defaults.meals,
        MealType.lunch: const MealReminder(enabled: false, time: ReminderTime(12, 15)),
      },
      nutritionEnabled: true,
      nutritionTime: const ReminderTime(22, 0),
      weeklyEnabled: true,
      weeklyDay: DateTime.sunday,
      weeklyTime: const ReminderTime(10, 30),
    );
    expect(NotificationSettings.fromJson(s.toJson()), s);
    expect(NotificationSettings.fromJson(s.toJson()).workoutTime.label, '07:05');
  });

  test('broken data falls back to the defaults field by field', () {
    expect(NotificationSettings.fromJson(null), NotificationSettings.defaults);
    expect(NotificationSettings.fromJson('x'), NotificationSettings.defaults);
    expect(
      NotificationSettings.fromJson({
        'workout': 'x',
        'meals': {'lunch': {'time': 9999}},
        'weekly': {'day': 9},
      }),
      NotificationSettings.defaults,
    );
    final partial = NotificationSettings.fromJson({
      'workout': {'on': true, 'days': [2, 9, 'a']},
    });
    expect(partial.workoutEnabled, isTrue);
    expect(partial.workoutDays, {2});
    expect(partial.workoutTime, NotificationSettings.defaults.workoutTime);
  });

  test('meals count as enabled only with the card switch and one meal on', () {
    final allMealsOff = {
      for (final type in reminderMealTypes) type: NotificationSettings.defaults.meals[type]!.copyWith(enabled: false),
    };
    expect(NotificationSettings.defaults.copyWith(mealsEnabled: true, meals: allMealsOff).anyEnabled, isFalse);
    expect(NotificationSettings.defaults.copyWith(mealsEnabled: true).anyEnabled, isTrue);
    expect(NotificationSettings.defaults.copyWith(weeklyEnabled: true).anyEnabled, isTrue);
  });

  test('default workout days come from a fixed-day program', () {
    expect(defaultWorkoutDays(_program(ScheduleMode.weekdays, [2, 4])), {2, 4});
    expect(defaultWorkoutDays(_program(ScheduleMode.weekdays, [null])), {1, 3, 5});
    expect(defaultWorkoutDays(_program(ScheduleMode.rotation, [null, null])), {1, 3, 5});
    expect(defaultWorkoutDays(null), {1, 3, 5});
  });

  test('workout days are filled from the program only until saved once', () {
    final program = _program(ScheduleMode.weekdays, [2, 4]);
    final filled = NotificationSettings.defaults.withWorkoutDaysFrom(program);
    expect(filled.workoutDays, {2, 4});
    expect(filled.workoutDaysInitialized, isTrue);
    final saved = NotificationSettings.defaults.copyWith(workoutDays: {7}, workoutDaysInitialized: true);
    expect(saved.withWorkoutDaysFrom(program).workoutDays, {7});
  });
}
