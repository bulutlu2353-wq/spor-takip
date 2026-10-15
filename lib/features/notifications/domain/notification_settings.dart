import 'dart:convert';

import '../../nutrition/domain/meal_type.dart';
import '../../workout/domain/program.dart';
import '../../workout/domain/schedule_mode.dart';

/// Günün yerel saati; JSON'da gün başından dakika olarak saklanır.
class ReminderTime {
  const ReminderTime(this.hour, this.minute);

  final int hour;
  final int minute;

  int get minutes => hour * 60 + minute;

  String get label => '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

  static ReminderTime? fromMinutes(Object? value) {
    if (value is! int || value < 0 || value >= 24 * 60) return null;
    return ReminderTime(value ~/ 60, value % 60);
  }

  @override
  bool operator ==(Object other) => other is ReminderTime && other.hour == hour && other.minute == minute;

  @override
  int get hashCode => Object.hash(hour, minute);
}

class MealReminder {
  const MealReminder({required this.enabled, required this.time});

  final bool enabled;
  final ReminderTime time;

  MealReminder copyWith({bool? enabled, ReminderTime? time}) =>
      MealReminder(enabled: enabled ?? this.enabled, time: time ?? this.time);
}

/// Hatırlatıcısı olan öğün tipleri (ara öğün yok, N1 spec §3.2).
const reminderMealTypes = [MealType.breakfast, MealType.lunch, MealType.dinner];

const _defaultMeals = {
  MealType.breakfast: MealReminder(enabled: true, time: ReminderTime(9, 0)),
  MealType.lunch: MealReminder(enabled: true, time: ReminderTime(13, 0)),
  MealType.dinner: MealReminder(enabled: true, time: ReminderTime(19, 30)),
};

/// Cihazdaki hatırlatıcı ayarları (N1 spec §3.1); hepsi varsayılan kapalı.
class NotificationSettings {
  const NotificationSettings({
    this.workoutEnabled = false,
    this.workoutDays = const {1, 3, 5},
    this.workoutTime = const ReminderTime(18, 0),
    this.workoutDaysInitialized = false,
    this.mealsEnabled = false,
    this.meals = _defaultMeals,
    this.nutritionEnabled = false,
    this.nutritionTime = const ReminderTime(21, 0),
    this.weeklyEnabled = false,
    this.weeklyDay = DateTime.friday,
    this.weeklyTime = const ReminderTime(19, 0),
  });

  static const defaults = NotificationSettings();

  final bool workoutEnabled;

  /// ISO hafta günleri (1=Pzt … 7=Paz).
  final Set<int> workoutDays;
  final ReminderTime workoutTime;

  /// Günler bir kez kaydedildiyse true; o zamana kadar ekran günleri programdan gösterir.
  final bool workoutDaysInitialized;
  final bool mealsEnabled;
  final Map<MealType, MealReminder> meals;
  final bool nutritionEnabled;
  final ReminderTime nutritionTime;
  final bool weeklyEnabled;
  final int weeklyDay;
  final ReminderTime weeklyTime;

  bool get anyEnabled =>
      workoutEnabled ||
      (mealsEnabled && reminderMealTypes.any((type) => meals[type]!.enabled)) ||
      nutritionEnabled ||
      weeklyEnabled;

  Map<String, Object?> toJson() => {
        'workout': {
          'on': workoutEnabled,
          'days': [...workoutDays]..sort(),
          'time': workoutTime.minutes,
          'init': workoutDaysInitialized,
        },
        'meals': {
          'on': mealsEnabled,
          for (final type in reminderMealTypes)
            type.name: {'on': meals[type]!.enabled, 'time': meals[type]!.time.minutes},
        },
        'nutrition': {'on': nutritionEnabled, 'time': nutritionTime.minutes},
        'weekly': {'on': weeklyEnabled, 'day': weeklyDay, 'time': weeklyTime.minutes},
      };

  /// Bozuk ya da eksik alanlar tek tek varsayılana düşer.
  factory NotificationSettings.fromJson(Object? json) {
    const d = defaults;
    Map<String, Object?> section(Object? value) =>
        value is Map ? value.map((key, v) => MapEntry('$key', v)) : const <String, Object?>{};
    bool flag(Map<String, Object?> m, String key, bool fallback) => m[key] is bool ? m[key] as bool : fallback;
    ReminderTime time(Map<String, Object?> m, ReminderTime fallback) => ReminderTime.fromMinutes(m['time']) ?? fallback;

    final root = section(json);
    final workout = section(root['workout']);
    final meals = section(root['meals']);
    final nutrition = section(root['nutrition']);
    final weekly = section(root['weekly']);
    final days = workout['days'];
    final weeklyDay = weekly['day'];
    return NotificationSettings(
      workoutEnabled: flag(workout, 'on', d.workoutEnabled),
      workoutDays: days is List ? {for (final v in days) if (v is int && v >= 1 && v <= 7) v} : d.workoutDays,
      workoutTime: time(workout, d.workoutTime),
      workoutDaysInitialized: flag(workout, 'init', d.workoutDaysInitialized),
      mealsEnabled: flag(meals, 'on', d.mealsEnabled),
      meals: {
        for (final type in reminderMealTypes)
          type: MealReminder(
            enabled: flag(section(meals[type.name]), 'on', d.meals[type]!.enabled),
            time: time(section(meals[type.name]), d.meals[type]!.time),
          ),
      },
      nutritionEnabled: flag(nutrition, 'on', d.nutritionEnabled),
      nutritionTime: time(nutrition, d.nutritionTime),
      weeklyEnabled: flag(weekly, 'on', d.weeklyEnabled),
      weeklyDay: weeklyDay is int && weeklyDay >= 1 && weeklyDay <= 7 ? weeklyDay : d.weeklyDay,
      weeklyTime: time(weekly, d.weeklyTime),
    );
  }

  NotificationSettings copyWith({
    bool? workoutEnabled,
    Set<int>? workoutDays,
    ReminderTime? workoutTime,
    bool? workoutDaysInitialized,
    bool? mealsEnabled,
    Map<MealType, MealReminder>? meals,
    bool? nutritionEnabled,
    ReminderTime? nutritionTime,
    bool? weeklyEnabled,
    int? weeklyDay,
    ReminderTime? weeklyTime,
  }) {
    return NotificationSettings(
      workoutEnabled: workoutEnabled ?? this.workoutEnabled,
      workoutDays: workoutDays ?? this.workoutDays,
      workoutTime: workoutTime ?? this.workoutTime,
      workoutDaysInitialized: workoutDaysInitialized ?? this.workoutDaysInitialized,
      mealsEnabled: mealsEnabled ?? this.mealsEnabled,
      meals: meals ?? this.meals,
      nutritionEnabled: nutritionEnabled ?? this.nutritionEnabled,
      nutritionTime: nutritionTime ?? this.nutritionTime,
      weeklyEnabled: weeklyEnabled ?? this.weeklyEnabled,
      weeklyDay: weeklyDay ?? this.weeklyDay,
      weeklyTime: weeklyTime ?? this.weeklyTime,
    );
  }

  /// Günler hiç kaydedilmediyse programdan doldurulmuş kopya (N1 spec §3.1).
  NotificationSettings withWorkoutDaysFrom(Program? program) => workoutDaysInitialized
      ? this
      : copyWith(workoutDays: defaultWorkoutDays(program), workoutDaysInitialized: true);

  // JSON biçimi sıralı ve tam olduğu için eşitlik onun üzerinden.
  @override
  bool operator ==(Object other) =>
      other is NotificationSettings && jsonEncode(other.toJson()) == jsonEncode(toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;
}

/// Sabit günlü programda programın günleri, aksi halde Pzt/Çar/Cum.
Set<int> defaultWorkoutDays(Program? program) {
  if (program != null && program.scheduleMode == ScheduleMode.weekdays) {
    final days = {for (final workout in program.workouts) ?workout.weekday};
    if (days.isNotEmpty) return days;
  }
  return const {1, 3, 5};
}
