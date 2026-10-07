import 'package:flutter_test/flutter_test.dart';
import 'package:spor_takip/features/onboarding/domain/profile.dart';
import 'package:spor_takip/features/onboarding/domain/tdee_calculator.dart';
import 'package:spor_takip/features/settings/domain/profile_edit.dart';

import '../../progress/fixtures.dart';

void main() {
  Map<String, dynamic> changes(Profile after) => profileChanges(testProfile, after, currentYear: 2026);

  test('no change gives an empty map', () {
    expect(changes(testProfile), isEmpty);
    expect(changes(testProfile.copyWith(heightCm: 180)), isEmpty);
  });

  test('a target-affecting change adds both new targets', () {
    final after = testProfile.copyWith(heightCm: 182);
    final targets = targetsFor(after, currentYear: 2026);
    expect(changes(after), {
      'height_cm': 182.0,
      'daily_calorie_target': targets.calorieTarget,
      'daily_protein_target_g': targets.proteinTargetG,
    });
  });

  test('fields that do not affect the targets are written alone', () {
    expect(changes(testProfile.copyWith(healthNotes: 'Diz')), {'health_notes': 'Diz'});
    expect(
      changes(testProfile.copyWith(doesExercise: false, exerciseDaysPerWeek: 0)),
      {'does_exercise': false, 'exercise_days_per_week': 0},
    );
  });

  test('switching to maintain writes a null pace and focuses in DB order', () {
    final losing = testProfile.copyWith(weightDirection: WeightDirection.lose, pace: Pace.fast);
    final after = losing.copyWith(
      weightDirection: WeightDirection.maintain,
      clearPace: true,
      focuses: {GoalFocus.strength, GoalFocus.muscle},
    );
    final result = profileChanges(losing, after, currentYear: 2026);
    expect(result['weight_direction'], 'maintain');
    expect(result.containsKey('pace'), isTrue);
    expect(result['pace'], isNull);
    expect(result['focuses'], ['muscle', 'strength']);
    expect(result['daily_calorie_target'], targetsFor(after, currentYear: 2026).calorieTarget);
  });

  test('targetsFor runs the TdeeCalculator on every profile field', () {
    final expected = const TdeeCalculator().calculate(
      weightKg: 80,
      heightCm: 180,
      birthYear: 1996,
      currentYear: 2026,
      gender: Gender.male,
      activityLevel: ActivityLevel.moderate,
      weightDirection: WeightDirection.maintain,
      pace: null,
      focuses: {GoalFocus.muscle},
    );
    final targets = targetsFor(testProfile, currentYear: 2026);
    expect(targets.calorieTarget, expected.calorieTarget);
    expect(targets.proteinTargetG, expected.proteinTargetG);
  });
}
