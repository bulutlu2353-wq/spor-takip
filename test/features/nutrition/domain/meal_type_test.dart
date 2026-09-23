import 'package:flutter_test/flutter_test.dart';
import 'package:spor_takip/features/nutrition/domain/meal_type.dart';

void main() {
  group('mealTypeToDb / mealTypeFromDb', () {
    test('round-trips every MealType value', () {
      for (final type in MealType.values) {
        expect(mealTypeFromDb(mealTypeToDb(type)), type);
      }
    });

    test('maps to the expected db strings', () {
      expect(mealTypeToDb(MealType.breakfast), 'breakfast');
      expect(mealTypeToDb(MealType.lunch), 'lunch');
      expect(mealTypeToDb(MealType.dinner), 'dinner');
      expect(mealTypeToDb(MealType.snack), 'snack');
    });

    test('throws ArgumentError for an unknown db string', () {
      expect(() => mealTypeFromDb('brunch'), throwsArgumentError);
    });
  });
}
