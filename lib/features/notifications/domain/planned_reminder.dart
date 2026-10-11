import 'package:flutter/foundation.dart';

import '../../nutrition/domain/meal_type.dart';

enum ReminderKind { workout, meal, nutrition, weekly }

/// Gün + tür (+ öğün) başına sabit, 32 bit'e sığan bildirim kimliği.
int reminderId(ReminderKind kind, DateTime day, [MealType? mealType]) {
  final dayNumber = DateTime.utc(day.year, day.month, day.day).difference(DateTime.utc(1970)).inDays;
  final slot = kind.index * 10 + (mealType?.index ?? 0);
  return (dayNumber % 10000) * 100 + slot + 1;
}

/// Kurulacak tek bildirim; metinler zamanlama anında çevrilir.
class PlannedReminder {
  const PlannedReminder({
    required this.id,
    required this.kind,
    required this.at,
    required this.titleKey,
    required this.bodyKey,
    required this.route,
    this.args = const {},
  });

  final int id;
  final ReminderKind kind;

  /// Yerel saat.
  final DateTime at;
  final String titleKey;
  final String bodyKey;
  final Map<String, String> args;

  /// Dokununca açılacak rota.
  final String route;

  @override
  bool operator ==(Object other) =>
      other is PlannedReminder &&
      other.id == id &&
      other.kind == kind &&
      other.at == at &&
      other.titleKey == titleKey &&
      other.bodyKey == bodyKey &&
      other.route == route &&
      mapEquals(other.args, args);

  @override
  int get hashCode => Object.hash(
    id,
    kind,
    at,
    titleKey,
    bodyKey,
    route,
    Object.hashAllUnordered(args.entries.map((e) => '${e.key}=${e.value}')),
  );

  @override
  String toString() =>
      'PlannedReminder($id, ${kind.name}, ${at.toIso8601String()}, $titleKey, $bodyKey, $args, $route)';
}
