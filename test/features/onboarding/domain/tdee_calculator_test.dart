import 'package:flutter_test/flutter_test.dart';
import 'package:spor_takip/features/onboarding/domain/profile.dart';
import 'package:spor_takip/features/onboarding/domain/tdee_calculator.dart';

void main() {
  const calculator = TdeeCalculator();

  TdeeResult calc({
    double weightKg = 80,
    double heightCm = 180,
    int birthYear = 1996,
    Gender gender = Gender.male,
    ActivityLevel activityLevel = ActivityLevel.sedentary,
    WeightDirection weightDirection = WeightDirection.maintain,
    Pace? pace,
    Set<GoalFocus> focuses = const {GoalFocus.general},
  }) {
    return calculator.calculate(
      weightKg: weightKg,
      heightCm: heightCm,
      birthYear: birthYear,
      currentYear: 2026,
      gender: gender,
      activityLevel: activityLevel,
      weightDirection: weightDirection,
      pace: pace,
      focuses: focuses,
    );
  }

  test('male, sedentary, maintain: TDEE and 1.6 g/kg protein', () {
    final result = calc();
    expect(result.calorieTarget, closeTo(2136.0, 0.01));
    expect(result.proteinTargetG, closeTo(128.0, 0.01));
  });

  test('female, moderate, lose balanced: 0.75 %/week deficit and 2.2 g/kg protein', () {
    final result = calc(
      weightKg: 60,
      heightCm: 165,
      birthYear: 2001,
      gender: Gender.female,
      activityLevel: ActivityLevel.moderate,
      weightDirection: WeightDirection.lose,
      pace: Pace.balanced,
    );
    // TDEE 2085.1375 − 60 × 0.0075 × 7700 / 7 (495)
    expect(result.calorieTarget, closeTo(1590.1375, 0.01));
    expect(result.proteinTargetG, closeTo(132.0, 0.01));
  });

  test('unspecified gender, very active, gain balanced with muscle focus', () {
    final result = calc(
      weightKg: 70,
      heightCm: 170,
      birthYear: 1990,
      gender: Gender.unspecified,
      activityLevel: ActivityLevel.veryActive,
      weightDirection: WeightDirection.gain,
      pace: Pace.balanced,
      focuses: {GoalFocus.muscle},
    );
    // TDEE 2858.55 + 70 × 0.0035 × 1100 (269.5)
    expect(result.calorieTarget, closeTo(3128.05, 0.01));
    expect(result.proteinTargetG, closeTo(140.0, 0.01));
  });

  test('pace scales the daily delta', () {
    // 80 kg erkek, orta aktivite: TDEE 1780 × 1.55 = 2759 (taban devreye girmez).
    double target(WeightDirection direction, Pace pace) =>
        calc(activityLevel: ActivityLevel.moderate, weightDirection: direction, pace: pace).calorieTarget;
    expect(target(WeightDirection.lose, Pace.slow), closeTo(2759 - 440, 0.01));
    expect(target(WeightDirection.lose, Pace.balanced), closeTo(2759 - 660, 0.01));
    expect(target(WeightDirection.lose, Pace.fast), closeTo(2759 - 880, 0.01));
    expect(target(WeightDirection.gain, Pace.slow), closeTo(2759 + 220, 0.01));
    expect(target(WeightDirection.gain, Pace.balanced), closeTo(2759 + 308, 0.01));
    expect(target(WeightDirection.gain, Pace.fast), closeTo(2759 + 440, 0.01));
  });

  test('the floor limits a deficit but never lifts the target above TDEE', () {
    // Kadın 50 kg, 160 cm, 40 yaş, hareketsiz: TDEE 1366.8; hızlı açık 550 → 816.8 → taban 1200.
    final floored = calc(
      weightKg: 50,
      heightCm: 160,
      birthYear: 1986,
      gender: Gender.female,
      weightDirection: WeightDirection.lose,
      pace: Pace.fast,
    );
    expect(floored.calorieTarget, closeTo(1200.0, 0.01));

    // Kadın 45 kg, 155 cm, 60 yaş: TDEE 1149.3 tabanın altında → hedef TDEE.
    for (final direction in [WeightDirection.lose, WeightDirection.maintain]) {
      final low = calc(
        weightKg: 45,
        heightCm: 155,
        birthYear: 1966,
        gender: Gender.female,
        weightDirection: direction,
        pace: direction == WeightDirection.lose ? Pace.fast : null,
      );
      expect(low.calorieTarget, closeTo(1149.3, 0.01));
    }

    // Erkek tabanı 1500: 80 kg hareketsiz, hızlı açık 880 → 1256 → 1500.
    expect(calc(weightDirection: WeightDirection.lose, pace: Pace.fast).calorieTarget, closeTo(1500.0, 0.01));
  });

  test('protein: losing beats focuses, muscle or strength 2.0, otherwise 1.6', () {
    expect(
      calc(weightDirection: WeightDirection.lose, pace: Pace.slow, focuses: {GoalFocus.muscle}).proteinTargetG,
      closeTo(176.0, 0.01),
    );
    expect(calc(focuses: {GoalFocus.strength}).proteinTargetG, closeTo(160.0, 0.01));
    expect(calc(focuses: {GoalFocus.endurance, GoalFocus.general}).proteinTargetG, closeTo(128.0, 0.01));
    expect(calc(focuses: const {}).proteinTargetG, closeTo(128.0, 0.01));
  });

  test('weeklyChangeKg uses the pace table and is zero when maintaining', () {
    expect(weeklyChangeKg(80, WeightDirection.lose, Pace.balanced), closeTo(0.6, 1e-9));
    expect(weeklyChangeKg(80, WeightDirection.gain, Pace.fast), closeTo(0.4, 1e-9));
    expect(weeklyChangeKg(80, WeightDirection.maintain, null), 0);
    expect(weeklyChangeKg(80, WeightDirection.lose, null), 0);
  });
}
