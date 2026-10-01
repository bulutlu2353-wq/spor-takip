import 'package:flutter_test/flutter_test.dart';
import 'package:spor_takip/features/onboarding/domain/profile.dart';

import '../../progress/fixtures.dart';

void main() {
  test('copyWith replaces only the given fields', () {
    final copy = testProfile.copyWith(weightKg: 82, goal: Goal.loseWeight, activityLevel: ActivityLevel.active);

    expect(copy.weightKg, 82);
    expect(copy.goal, Goal.loseWeight);
    expect(copy.activityLevel, ActivityLevel.active);
    expect(copy.userId, testProfile.userId);
    expect(copy.heightCm, testProfile.heightCm);
    expect(copy.dailyCalorieTarget, testProfile.dailyCalorieTarget);
  });

  test('database names round-trip', () {
    for (final level in ActivityLevel.values) {
      expect(activityLevelFromDb(activityLevelToDb(level)), level);
    }
    for (final goal in Goal.values) {
      expect(goalFromDb(goalToDb(goal)), goal);
    }
    expect(activityLevelToDb(ActivityLevel.veryActive), 'very_active');
    expect(goalToDb(Goal.gainMuscle), 'gain_muscle');
  });
}
