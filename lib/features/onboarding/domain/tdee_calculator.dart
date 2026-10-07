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
  }) {
    final age = currentYear - birthYear;
    final bmr = _bmr(
      weightKg: weightKg,
      heightCm: heightCm,
      age: age,
      gender: gender,
    );
    final tdee = bmr * _activityMultipliers[activityLevel]!;
    final dailyDelta = weeklyChangeKg(weightKg, weightDirection, pace) * _kcalPerKg / 7;
    final signedDelta = weightDirection == WeightDirection.lose ? -dailyDelta : dailyDelta;
    final floor = gender == Gender.male ? 1500.0 : 1200.0;
    // Taban açığı sınırlar ama hedefi TDEE'nin üstüne çıkarmaz.
    final calorieTarget = math.max(tdee + signedDelta, math.min(tdee, floor));
    final proteinTargetG = weightKg * _proteinPerKg(weightDirection, focuses);
    return TdeeResult(calorieTarget: calorieTarget, proteinTargetG: proteinTargetG);
  }
}
