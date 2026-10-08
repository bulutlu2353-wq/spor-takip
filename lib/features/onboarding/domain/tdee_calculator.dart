import 'dart:math' as math;

import 'profile.dart';

class TdeeResult {
  const TdeeResult({required this.calorieTarget, required this.proteinTargetG});

  final double calorieTarget;
  final double proteinTargetG;
}

/// Haftalık kilo değişimi, vücut ağırlığının oranı olarak (spec §4.2).
const Map<WeightDirection, Map<Pace, double>> weeklyRates = {
  WeightDirection.lose: {Pace.slow: 0.005, Pace.balanced: 0.0075, Pace.fast: 0.01},
  WeightDirection.gain: {Pace.slow: 0.0025, Pace.balanced: 0.0035, Pace.fast: 0.005},
};

const double _kcalPerKg = 7700;

/// Haftalık tahmini kilo değişimi (kg, işaretsiz); korumada ya da hız yoksa 0.
double weeklyChangeKg(double weightKg, WeightDirection direction, Pace? pace) {
  final rate = pace == null ? null : weeklyRates[direction]?[pace];
  return rate == null ? 0 : weightKg * rate;
}

class TdeeCalculator {
  const TdeeCalculator();

  static const Map<ActivityLevel, double> _activityMultipliers = {
    ActivityLevel.sedentary: 1.2,
    ActivityLevel.light: 1.375,
    ActivityLevel.moderate: 1.55,
    ActivityLevel.active: 1.725,
    ActivityLevel.veryActive: 1.9,
  };

  double _bmr({
    required double weightKg,
    required double heightCm,
    required int age,
    required Gender gender,
  }) {
    final base = 10 * weightKg + 6.25 * heightCm - 5 * age;
    switch (gender) {
      case Gender.male:
        return base + 5;
      case Gender.female:
        return base - 161;
      case Gender.unspecified:
        return ((base + 5) + (base - 161)) / 2;
    }
  }

  /// Bakım kalorisi (BMR × aktivite), uyarlama payı hariç.
  double maintenance({
    required double weightKg,
    required double heightCm,
    required int birthYear,
    required int currentYear,
    required Gender gender,
    required ActivityLevel activityLevel,
  }) {
    final bmr = _bmr(weightKg: weightKg, heightCm: heightCm, age: currentYear - birthYear, gender: gender);
    return bmr * _activityMultipliers[activityLevel]!;
  }

  /// Kilo verirken kası korumak için en yüksek; kas/güç odağında orta; diğerlerinde 1.6.
  double _proteinPerKg(WeightDirection direction, Set<GoalFocus> focuses) {
    if (direction == WeightDirection.lose) return 2.2;
    if (focuses.contains(GoalFocus.muscle) || focuses.contains(GoalFocus.strength)) return 2.0;
    return 1.6;
  }

  TdeeResult calculate({
    required double weightKg,
    required double heightCm,
    required int birthYear,
    required int currentYear,
    required Gender gender,
    required ActivityLevel activityLevel,
    required WeightDirection weightDirection,
    required Pace? pace,
    required Set<GoalFocus> focuses,
    double adjustmentKcal = 0,
  }) {
    final formula = maintenance(
      weightKg: weightKg,
      heightCm: heightCm,
      birthYear: birthYear,
      currentYear: currentYear,
      gender: gender,
      activityLevel: activityLevel,
    );
    final tdee = formula + adjustmentKcal;
    final dailyDelta = weeklyChangeKg(weightKg, weightDirection, pace) * _kcalPerKg / 7;
    final signedDelta = weightDirection == WeightDirection.lose ? -dailyDelta : dailyDelta;
    final floor = gender == Gender.male ? 1500.0 : 1200.0;
    // Taban açığı ve negatif payı sınırlar ama hedefi formül bakımının üstüne çıkarmaz (G3 spec §4.1).
    final calorieTarget = math.max(tdee + signedDelta, math.min(formula, floor));
    final proteinTargetG = weightKg * _proteinPerKg(weightDirection, focuses);
    return TdeeResult(calorieTarget: calorieTarget, proteinTargetG: proteinTargetG);
  }
}
