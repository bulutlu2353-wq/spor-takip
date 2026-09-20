import 'package:flutter_test/flutter_test.dart';
import 'package:spor_takip/features/onboarding/domain/profile.dart';
import 'package:spor_takip/features/onboarding/domain/tdee_calculator.dart';

void main() {
  const calculator = TdeeCalculator();

  test('male, sedentary, maintain', () {
    final result = calculator.calculate(
      weightKg: 80,
      heightCm: 180,
      birthYear: 1996,
      currentYear: 2026,
      gender: Gender.male,
      activityLevel: ActivityLevel.sedentary,
      goal: Goal.maintain,
    );
    expect(result.calorieTarget, closeTo(2136.0, 0.01));
    expect(result.proteinTargetG, closeTo(136.0, 0.01));
  });

  test('female, moderate, lose_weight', () {
    final result = calculator.calculate(
      weightKg: 60,
      heightCm: 165,
      birthYear: 2001,
      currentYear: 2026,
      gender: Gender.female,
      activityLevel: ActivityLevel.moderate,
      goal: Goal.loseWeight,
    );
    expect(result.calorieTarget, closeTo(2085.1375, 0.01));
    expect(result.proteinTargetG, closeTo(120.0, 0.01));
  });

  test('unspecified gender averages male/female BMR, very_active, gain_muscle', () {
    final result = calculator.calculate(
      weightKg: 70,
      heightCm: 170,
      birthYear: 1990,
      currentYear: 2026,
      gender: Gender.unspecified,
      activityLevel: ActivityLevel.veryActive,
      goal: Goal.gainMuscle,
    );
    expect(result.calorieTarget, closeTo(2858.55, 0.01));
    expect(result.proteinTargetG, closeTo(154.0, 0.01));
  });
}
