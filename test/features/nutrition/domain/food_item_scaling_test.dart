import 'package:flutter_test/flutter_test.dart';
import 'package:spor_takip/features/nutrition/domain/food_item.dart';
import 'package:spor_takip/features/nutrition/domain/food_item_scaling.dart';

void main() {
  const chicken = FoodItem(name: 'Tavuk', grams: 200, calories: 330, proteinG: 62, carbsG: 0, fatG: 7);

  group('perGramOf', () {
    test('is null when grams is zero', () {
      expect(perGramOf(const FoodItem(name: 'X', grams: 0, calories: 100)), isNull);
    });

    test('divides calories and macros by grams', () {
      final perGram = perGramOf(chicken)!;
      expect(perGram.calories, closeTo(1.65, 1e-9));
      expect(perGram.proteinG, closeTo(0.31, 1e-9));
      expect(perGram.carbsG, 0);
      expect(perGram.fatG, closeTo(0.035, 1e-9));
    });
  });

  group('withGrams', () {
    test('scales calories and macros with the per-gram values', () {
      final scaled = withGrams(chicken, 300, perGramOf(chicken));
      expect(scaled.grams, 300);
      expect(scaled.calories, closeTo(495, 1e-9));
      expect(scaled.proteinG, closeTo(93, 1e-9));
      expect(scaled.fatG, closeTo(10.5, 1e-9));
      expect(scaled.name, 'Tavuk');
    });

    test('without per-gram values only grams change', () {
      final scaled = withGrams(chicken, 300, null);
      expect(scaled.grams, 300);
      expect(scaled.calories, 330);
      expect(scaled.proteinG, 62);
    });

    test('going through zero grams and back keeps the ratio', () {
      final perGram = perGramOf(chicken);
      final zero = withGrams(chicken, 0, perGram);
      expect(zero.calories, 0);
      final back = withGrams(zero, 250, perGram);
      expect(back.calories, closeTo(412.5, 1e-9));
      expect(back.proteinG, closeTo(77.5, 1e-9));
    });

    test('keeps the needsReview flag', () {
      const item = FoodItem(name: 'Sos', grams: 50, calories: 100, needsReview: true);
      expect(withGrams(item, 100, perGramOf(item)).needsReview, isTrue);
    });
  });
}
