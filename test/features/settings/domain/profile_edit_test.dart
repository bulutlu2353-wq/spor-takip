import 'package:flutter_test/flutter_test.dart';
import 'package:spor_takip/features/onboarding/domain/profile.dart';
import 'package:spor_takip/features/onboarding/domain/tdee_calculator.dart';
import 'package:spor_takip/features/settings/domain/profile_edit.dart';

import '../../progress/fixtures.dart';

void main() {
  final now = DateTime(2026, 10, 8, 9);
  final stamp = now.toUtc().toIso8601String();
  Map<String, dynamic> changes(Profile after, {Profile before = testProfile}) =>
      profileChanges(before, after, now: now);

  test('no change gives an empty map', () {
    expect(changes(testProfile), isEmpty);
    expect(changes(testProfile.copyWith(heightCm: 180)), isEmpty);
  });

  test('a target-affecting change adds both new targets and the change time', () {
    final after = testProfile.copyWith(heightCm: 182);
    final targets = targetsFor(after, currentYear: 2026);
    expect(changes(after), {
      'height_cm': 182.0,
      'daily_calorie_target': targets.calorieTarget,
      'daily_protein_target_g': targets.proteinTargetG,
      'goals_changed_at': stamp,
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
    final result = changes(after, before: losing);
    expect(result['weight_direction'], 'maintain');
    expect(result.containsKey('pace'), isTrue);
    expect(result['pace'], isNull);
    expect(result['focuses'], ['muscle', 'strength']);
    expect(result['daily_calorie_target'], targetsFor(after, currentYear: 2026).calorieTarget);
  });

  test('a goal change keeps the adjustment in the new target', () {
    final adapted = testProfile.copyWith(calorieAdjustmentKcal: -200);
    final after = adapted.copyWith(weightDirection: WeightDirection.lose, pace: Pace.balanced);
    final result = changes(after, before: adapted);
    expect(result.containsKey('calorie_adjustment_kcal'), isFalse);
    expect(result['daily_calorie_target'], targetsFor(after, currentYear: 2026).calorieTarget);
    expect(
      result['daily_calorie_target'],
      closeTo(targetsFor(after.copyWith(calorieAdjustmentKcal: 0), currentYear: 2026).calorieTarget - 200, 0.01),
    );
  });

  test('an activity change resets the adjustment and computes targets without it', () {
    final adapted = testProfile.copyWith(calorieAdjustmentKcal: -200);
    final after = adapted.copyWith(activityLevel: ActivityLevel.active);
    final result = changes(after, before: adapted);
    expect(result['calorie_adjustment_kcal'], 0.0);
    expect(
      result['daily_calorie_target'],
      targetsFor(after.copyWith(calorieAdjustmentKcal: 0), currentYear: 2026).calorieTarget,
    );
    expect(result['goals_changed_at'], stamp);
  });

  test('resetAdjustmentFields zeroes the adjustment and recomputes the targets', () {
    final adapted = testProfile.copyWith(calorieAdjustmentKcal: -160);
    final targets = targetsFor(testProfile, currentYear: 2026);
    expect(resetAdjustmentFields(adapted, now: now), {
      'calorie_adjustment_kcal': 0.0,
      'calorie_adjusted_at': stamp,
      'goals_changed_at': stamp,
      'daily_calorie_target': targets.calorieTarget,
      'daily_protein_target_g': targets.proteinTargetG,
    });
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
      adjustmentKcal: -50,
    );
    final targets = targetsFor(testProfile.copyWith(calorieAdjustmentKcal: -50), currentYear: 2026);
    expect(targets.calorieTarget, expected.calorieTarget);
    expect(targets.proteinTargetG, expected.proteinTargetG);
  });
}
