import 'package:flutter_test/flutter_test.dart';
import 'package:spor_takip/features/nutrition/domain/food_item.dart';
import 'package:spor_takip/features/nutrition/domain/macro_totals.dart';
import 'package:spor_takip/features/nutrition/domain/meal.dart';
import 'package:spor_takip/features/nutrition/domain/meal_type.dart';

Meal _meal(List<FoodItem> items) => Meal(
      id: 'm',
      userId: 'u',
      mealType: MealType.lunch,
      loggedAt: DateTime(2026, 9, 23),
      items: items,
    );

void main() {
  test('MacroTotals + adds fields component-wise', () {
    const a = MacroTotals(calories: 100, proteinG: 10, carbsG: 5, fatG: 2);
    const b = MacroTotals(calories: 50, proteinG: 5, carbsG: 1, fatG: 1);
    final sum = a + b;
    expect(sum.calories, 150);
    expect(sum.proteinG, 15);
    expect(sum.carbsG, 6);
    expect(sum.fatG, 3);
  });

  test('sumMealMacros returns zero totals for an empty meal list', () {
    final totals = sumMealMacros(const []);
    expect(totals.calories, 0);
    expect(totals.proteinG, 0);
  });

  test('sumMealMacros sums every item across every meal', () {
    final meals = [
      _meal([
        const FoodItem(name: 'A', grams: 100, calories: 200, proteinG: 10, carbsG: 20, fatG: 5),
        const FoodItem(name: 'B', grams: 50, calories: 80, proteinG: 4, carbsG: 8, fatG: 2),
      ]),
      _meal([
        const FoodItem(name: 'C', grams: 150, calories: 300, proteinG: 25, carbsG: 10, fatG: 12),
      ]),
    ];

    final totals = sumMealMacros(meals);
    expect(totals.calories, 580);
    expect(totals.proteinG, 39);
    expect(totals.carbsG, 38);
    expect(totals.fatG, 19);
  });
}
