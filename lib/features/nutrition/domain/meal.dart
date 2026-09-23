import 'food_item.dart';
import 'meal_type.dart';

class Meal {
  const Meal({
    required this.id,
    required this.userId,
    required this.mealType,
    required this.loggedAt,
    required this.items,
    this.photoPath,
  });

  final String id;
  final String userId;
  final MealType mealType;
  final DateTime loggedAt;
  final String? photoPath;
  final List<FoodItem> items;

  factory Meal.fromJson(Map<String, dynamic> json) {
    final itemRows = json['meal_items'] as List? ?? const [];
    return Meal(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      mealType: mealTypeFromDb(json['meal_type'] as String),
      loggedAt: DateTime.parse(json['logged_at'] as String),
      photoPath: json['photo_path'] as String?,
      items: itemRows.map((e) => FoodItem.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }
}
