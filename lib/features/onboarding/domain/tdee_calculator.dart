import 'profile.dart';

class TdeeResult {
  const TdeeResult({required this.calorieTarget, required this.proteinTargetG});

  final double calorieTarget;
  final double proteinTargetG;
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

  static const Map<Goal, double> _proteinPerKgByGoal = {
    Goal.loseWeight: 2.0,
    Goal.gainMuscle: 2.2,
    Goal.maintain: 1.7,
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

  TdeeResult calculate({
    required double weightKg,
    required double heightCm,
    required int birthYear,
    required int currentYear,
    required Gender gender,
    required ActivityLevel activityLevel,
    required Goal goal,
  }) {
    final age = currentYear - birthYear;
    final bmr = _bmr(
      weightKg: weightKg,
      heightCm: heightCm,
      age: age,
      gender: gender,
    );
    final calorieTarget = bmr * _activityMultipliers[activityLevel]!;
    final proteinTargetG = weightKg * _proteinPerKgByGoal[goal]!;
    return TdeeResult(calorieTarget: calorieTarget, proteinTargetG: proteinTargetG);
  }
}
