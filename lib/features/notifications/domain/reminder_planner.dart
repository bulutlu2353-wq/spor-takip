import '../../nutrition/domain/macro_totals.dart';
import '../../nutrition/domain/meal_type.dart';
import 'notification_settings.dart';
import 'planned_reminder.dart';

class NutritionTargets {
  const NutritionTargets({required this.calories, required this.proteinG});

  final double calories;
  final double proteinG;
}

/// Bugün + 6 gün.
const reminderHorizonDays = 7;

/// Ayarlar ve bugünün verisinden kurulacak bildirimler (N1 spec §3.2), zamana göre sıralı.
/// [workoutNames]: ISO hafta günü → antrenman adı. [mealTypesToday]: bugün kaydedilen öğün
/// tipleri (ara öğün dahil). [targets] null ise profil yok. [weeklyGoal] null ise hedef yok.
List<PlannedReminder> planReminders({
  required NotificationSettings settings,
  required DateTime now,
  Map<int, String> workoutNames = const {},
  bool workoutDoneToday = false,
  Set<MealType> mealTypesToday = const {},
  MacroTotals nutritionToday = const MacroTotals(),
  NutritionTargets? targets,
  int? weeklyGoal,
  int weeklyDone = 0,
}) {
  final plan = <PlannedReminder>[];
  void add(
    ReminderKind kind,
    DateTime day,
    ReminderTime time, {
    required String titleKey,
    required String bodyKey,
    required String route,
    MealType? mealType,
    Map<String, String> args = const {},
  }) {
    final at = DateTime(day.year, day.month, day.day, time.hour, time.minute);
    if (!at.isAfter(now)) return;
    plan.add(
      PlannedReminder(
        id: reminderId(kind, day, mealType),
        kind: kind,
        at: at,
        titleKey: titleKey,
        bodyKey: bodyKey,
        route: route,
        args: args,
      ),
    );
  }

  for (var offset = 0; offset < reminderHorizonDays; offset++) {
    final day = DateTime(now.year, now.month, now.day + offset);
    final isToday = offset == 0;

    if (settings.workoutEnabled && settings.workoutDays.contains(day.weekday) && !(isToday && workoutDoneToday)) {
      final name = workoutNames[day.weekday];
      add(
        ReminderKind.workout,
        day,
        settings.workoutTime,
        titleKey: 'notifications.workout_title',
        bodyKey: name == null ? 'notifications.workout_body' : 'notifications.workout_body_named',
        route: '/home',
        args: {'name': ?name},
      );
    }

    if (settings.mealsEnabled) {
      for (final type in reminderMealTypes) {
        final meal = settings.meals[type]!;
        if (!meal.enabled || (isToday && mealTypesToday.contains(type))) continue;
        add(
          ReminderKind.meal,
          day,
          meal.time,
          titleKey: 'notifications.meal_title_${type.name}',
          bodyKey: 'notifications.meal_body',
          route: '/nutrition',
          mealType: type,
        );
      }
    }

    if (settings.nutritionEnabled) {
      final body = isToday
          ? _nutritionBody(mealTypesToday, nutritionToday, targets)
          : ('notifications.nutrition_none', const <String, String>{});
      if (body != null) {
        add(
          ReminderKind.nutrition,
          day,
          settings.nutritionTime,
          titleKey: 'notifications.nutrition_title',
          bodyKey: body.$1,
          route: '/nutrition',
          args: body.$2,
        );
      }
    }

    final sameWeek = offset <= DateTime.sunday - now.weekday;
    if (settings.weeklyEnabled &&
        sameWeek &&
        day.weekday == settings.weeklyDay &&
        weeklyGoal != null &&
        weeklyGoal > 0 &&
        weeklyDone < weeklyGoal) {
      add(
        ReminderKind.weekly,
        day,
        settings.weeklyTime,
        titleKey: 'notifications.weekly_title',
        bodyKey: 'notifications.weekly_body',
        route: '/home',
        args: {'done': '$weeklyDone', 'goal': '$weeklyGoal', 'left': '${DateTime.sunday - day.weekday + 1}'},
      );
    }
  }
  plan.sort((a, b) {
    final byTime = a.at.compareTo(b.at);
    return byTime != 0 ? byTime : a.id.compareTo(b.id);
  });
  return plan;
}

/// Bugünkü özetin metni; null ise bugün kurulmaz.
(String, Map<String, String>)? _nutritionBody(Set<MealType> mealTypes, MacroTotals totals, NutritionTargets? targets) {
  if (mealTypes.isEmpty) return ('notifications.nutrition_none', const {});
  if (targets == null) return null;
  final protein = (targets.proteinG - totals.proteinG).round();
  if (protein > 0) return ('notifications.nutrition_protein', {'g': '$protein'});
  final kcal = (targets.calories - totals.calories).round();
  if (kcal > 0) return ('notifications.nutrition_kcal', {'kcal': '$kcal'});
  return null;
}
