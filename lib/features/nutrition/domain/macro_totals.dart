import 'meal.dart';

class MacroTotals {
  const MacroTotals({
    this.calories = 0,
    this.proteinG = 0,
    this.carbsG = 0,
    this.fatG = 0,
  });

  final double calories;
  final double proteinG;
  final double carbsG;
  final double fatG;

  MacroTotals operator +(MacroTotals other) {
    return MacroTotals(
      calories: calories + other.calories,
      proteinG: proteinG + other.proteinG,
      carbsG: carbsG + other.carbsG,
      fatG: fatG + other.fatG,
    );
  }
}

MacroTotals sumMealMacros(List<Meal> meals) {
  var total = const MacroTotals();
  for (final meal in meals) {
    for (final item in meal.items) {
      total = total +
          MacroTotals(
            calories: item.calories,
            proteinG: item.proteinG,
            carbsG: item.carbsG,
            fatG: item.fatG,
          );
    }
  }
  return total;
}
