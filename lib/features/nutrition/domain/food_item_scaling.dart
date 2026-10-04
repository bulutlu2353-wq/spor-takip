import 'food_item.dart';
import 'macro_totals.dart';

/// 1 gram başına kcal/makro (R2 spec §4.4). Gram 0 ise oran bilinemez → null.
MacroTotals? perGramOf(FoodItem item) {
  if (item.grams <= 0) return null;
  return MacroTotals(
    calories: item.calories / item.grams,
    proteinG: item.proteinG / item.grams,
    carbsG: item.carbsG / item.grams,
    fatG: item.fatG / item.grams,
  );
}

/// Gramı değiştirir; [perGram] varsa kcal/makroları da `perGram × grams` yapar.
/// Oran dışarıda tutulduğu için gram geçici olarak 0'a inse de kaybolmaz.
FoodItem withGrams(FoodItem item, double grams, MacroTotals? perGram) {
  if (perGram == null) return item.copyWith(grams: grams);
  return item.copyWith(
    grams: grams,
    calories: perGram.calories * grams,
    proteinG: perGram.proteinG * grams,
    carbsG: perGram.carbsG * grams,
    fatG: perGram.fatG * grams,
  );
}
