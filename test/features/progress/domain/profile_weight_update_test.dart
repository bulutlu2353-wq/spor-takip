import 'package:flutter_test/flutter_test.dart';
import 'package:spor_takip/features/onboarding/domain/tdee_calculator.dart';
import 'package:spor_takip/features/progress/domain/profile_weight_update.dart';

import '../fixtures.dart';

void main() {
  test('recalculates targets for the new weight with the other profile fields', () {
    final update = profileWeightUpdate(testProfile, 85, currentYear: 2026);
    final expected = const TdeeCalculator().calculate(
      weightKg: 85,
      heightCm: 180,
      birthYear: 1996,
      currentYear: 2026,
      gender: testProfile.gender,
      activityLevel: testProfile.activityLevel,
      weightDirection: testProfile.weightDirection,
      pace: testProfile.pace,
      focuses: testProfile.focuses,
    );
    expect(update.weightKg, 85);
    expect(update.calorieTarget, expected.calorieTarget);
    expect(update.proteinTargetG, expected.proteinTargetG);
    expect(update.calorieTarget, isNot(testProfile.dailyCalorieTarget));
  });

  test('the adjustment is kept when a new weight recomputes the targets', () {
    final update = profileWeightUpdate(testProfile.copyWith(calorieAdjustmentKcal: -150), 82, currentYear: 2026);
    final plain = profileWeightUpdate(testProfile, 82, currentYear: 2026);
    expect(update.calorieTarget, closeTo(plain.calorieTarget - 150, 0.01));
  });
}
