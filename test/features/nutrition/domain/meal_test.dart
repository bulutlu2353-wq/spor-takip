import 'package:flutter_test/flutter_test.dart';
import 'package:spor_takip/features/nutrition/domain/meal.dart';
import 'package:spor_takip/features/nutrition/domain/meal_type.dart';

void main() {
  test('fromJson parses meal fields and nested meal_items', () {
    final meal = Meal.fromJson({
      'id': 'meal-1',
      'user_id': 'user-1',
      'meal_type': 'lunch',
      'photo_path': 'user-1/meal-1.jpg',
      'logged_at': '2026-09-23T12:30:00.000Z',
      'meal_items': [
        {'name': 'Pilav', 'grams': 100, 'calories': 130, 'protein_g': 2.7, 'carbs_g': 28, 'fat_g': 0.3},
      ],
    });

    expect(meal.id, 'meal-1');
    expect(meal.userId, 'user-1');
    expect(meal.mealType, MealType.lunch);
    expect(meal.photoPath, 'user-1/meal-1.jpg');
    expect(meal.loggedAt, DateTime.parse('2026-09-23T12:30:00.000Z'));
    expect(meal.items, hasLength(1));
    expect(meal.items.single.name, 'Pilav');
  });

  test('fromJson handles a missing meal_items key as an empty list', () {
    final meal = Meal.fromJson({
      'id': 'meal-2',
      'user_id': 'user-1',
      'meal_type': 'snack',
      'photo_path': null,
      'logged_at': '2026-09-23T09:00:00.000Z',
    });

    expect(meal.items, isEmpty);
    expect(meal.photoPath, isNull);
  });
}
