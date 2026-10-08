import 'package:flutter_test/flutter_test.dart';
import 'package:spor_takip/features/onboarding/domain/profile.dart';

void main() {
  test('Profile fromJson/toJson round-trips DB column names correctly', () {
    final json = {
      'user_id': 'user-1',
      'weight_kg': 80.5,
      'height_cm': 180.0,
      'birth_year': 1996,
      'gender': 'male',
      'activity_level': 'very_active',
      'does_exercise': true,
      'sport_type': 'Fitness',
      'exercise_days_per_week': 4,
      'weight_direction': 'gain',
      'pace': 'balanced',
      'focuses': ['muscle', 'strength'],
      'health_notes': 'Diz sakatlığı geçmişi',
      'daily_calorie_target': 2858.55,
      'daily_protein_target_g': 154.0,
    };

    final profile = Profile.fromJson(json);

    expect(profile.userId, 'user-1');
    expect(profile.weightKg, 80.5);
    expect(profile.heightCm, 180.0);
    expect(profile.birthYear, 1996);
    expect(profile.gender, Gender.male);
    expect(profile.activityLevel, ActivityLevel.veryActive);
    expect(profile.doesExercise, true);
    expect(profile.sportType, 'Fitness');
    expect(profile.exerciseDaysPerWeek, 4);
    expect(profile.weightDirection, WeightDirection.gain);
    expect(profile.pace, Pace.balanced);
    expect(profile.focuses, {GoalFocus.muscle, GoalFocus.strength});
    expect(profile.healthNotes, 'Diz sakatlığı geçmişi');
    expect(profile.dailyCalorieTarget, 2858.55);
    expect(profile.dailyProteinTargetG, 154.0);

    expect(profile.toJson(), json);
  });

  test('Profile.fromJson handles null sport_type and health_notes', () {
    final json = {
      'user_id': 'user-2',
      'weight_kg': 60.0,
      'height_cm': 165.0,
      'birth_year': 2001,
      'gender': 'female',
      'activity_level': 'sedentary',
      'does_exercise': false,
      'sport_type': null,
      'exercise_days_per_week': 0,
      'weight_direction': 'maintain',
      'pace': null,
      'focuses': <String>[],
      'health_notes': null,
      'daily_calorie_target': 1345.25,
      'daily_protein_target_g': 120.0,
    };

    final profile = Profile.fromJson(json);

    expect(profile.sportType, isNull);
    expect(profile.healthNotes, isNull);
    expect(profile.pace, isNull);
    expect(profile.focuses, isEmpty);
    expect(profile.toJson(), json);
  });

  test('Profile.fromJson reads the adaptive calorie fields and defaults them when absent', () {
    final base = {
      'user_id': 'user-3',
      'weight_kg': 80,
      'height_cm': 180,
      'birth_year': 1996,
      'gender': 'male',
      'activity_level': 'moderate',
      'does_exercise': true,
      'sport_type': null,
      'exercise_days_per_week': 3,
      'weight_direction': 'maintain',
      'pace': null,
      'focuses': <String>[],
      'health_notes': null,
      'daily_calorie_target': 2759,
      'daily_protein_target_g': 128,
    };
    final plain = Profile.fromJson(base);
    expect(plain.calorieAdjustmentKcal, 0);
    expect(plain.calorieAdjustedAt, isNull);
    expect(plain.calorieSuggestionSnoozedUntil, isNull);
    expect(plain.goalsChangedAt, isNull);

    final adapted = Profile.fromJson({
      ...base,
      'calorie_adjustment_kcal': -160,
      'calorie_adjusted_at': '2026-10-08T07:00:00+00:00',
      'calorie_suggestion_snoozed_until': '2026-10-15T07:00:00+00:00',
      'goals_changed_at': '2026-09-01T07:00:00+00:00',
    });
    expect(adapted.calorieAdjustmentKcal, -160);
    expect(adapted.calorieAdjustedAt, DateTime.utc(2026, 10, 8, 7).toLocal());
    expect(adapted.calorieSuggestionSnoozedUntil, DateTime.utc(2026, 10, 15, 7).toLocal());
    expect(adapted.goalsChangedAt, DateTime.utc(2026, 9, 1, 7).toLocal());
    expect(adapted.toJson().containsKey('calorie_adjustment_kcal'), isFalse);
  });
}
