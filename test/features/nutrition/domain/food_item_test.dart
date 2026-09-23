import 'package:flutter_test/flutter_test.dart';
import 'package:spor_takip/features/nutrition/domain/food_item.dart';

void main() {
  const item = FoodItem(
    name: 'Izgara tavuk göğsü',
    grams: 150,
    calories: 247,
    proteinG: 46.5,
    carbsG: 0,
    fatG: 5.4,
    usdaFdcId: '171077',
    needsReview: false,
  );

  test('toJson/fromJson round-trips all fields', () {
    final json = item.toJson();
    final parsed = FoodItem.fromJson(json);
    expect(parsed.name, item.name);
    expect(parsed.grams, item.grams);
    expect(parsed.calories, item.calories);
    expect(parsed.proteinG, item.proteinG);
    expect(parsed.carbsG, item.carbsG);
    expect(parsed.fatG, item.fatG);
    expect(parsed.usdaFdcId, item.usdaFdcId);
    expect(parsed.needsReview, item.needsReview);
  });

  test('fromJson defaults missing macro/needs_review fields', () {
    final parsed = FoodItem.fromJson({'name': 'Bilinmeyen sos', 'grams': 30});
    expect(parsed.calories, 0);
    expect(parsed.proteinG, 0);
    expect(parsed.carbsG, 0);
    expect(parsed.fatG, 0);
    expect(parsed.usdaFdcId, isNull);
    expect(parsed.needsReview, isFalse);
  });

  test('copyWith overrides only given fields', () {
    final updated = item.copyWith(grams: 200, needsReview: true);
    expect(updated.grams, 200);
    expect(updated.needsReview, isTrue);
    expect(updated.name, item.name);
    expect(updated.calories, item.calories);
  });
}
