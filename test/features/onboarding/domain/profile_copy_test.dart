import 'package:flutter_test/flutter_test.dart';
import 'package:spor_takip/features/onboarding/domain/profile.dart';

import '../../progress/fixtures.dart';

void main() {
  test('copyWith replaces only the given fields', () {
    final copy = testProfile.copyWith(
      weightKg: 82,
      weightDirection: WeightDirection.lose,
      pace: Pace.fast,
      focuses: {GoalFocus.strength},
      activityLevel: ActivityLevel.active,
    );

    expect(copy.weightKg, 82);
    expect(copy.weightDirection, WeightDirection.lose);
    expect(copy.pace, Pace.fast);
    expect(copy.focuses, {GoalFocus.strength});
    expect(copy.activityLevel, ActivityLevel.active);
    expect(copy.userId, testProfile.userId);
    expect(copy.heightCm, testProfile.heightCm);
    expect(copy.dailyCalorieTarget, testProfile.dailyCalorieTarget);
  });

  test('copyWith keeps the pace unless clearPace is set', () {
    final losing = testProfile.copyWith(weightDirection: WeightDirection.lose, pace: Pace.fast);
    expect(losing.copyWith(weightKg: 81).pace, Pace.fast);
    expect(losing.copyWith(weightDirection: WeightDirection.maintain, clearPace: true).pace, isNull);
  });

  test('copyWith edits and clears the optional settings fields', () {
    final edited = testProfile.copyWith(birthYear: 1990, gender: Gender.female, sportType: 'Koşu', healthNotes: 'Bel');
    expect((edited.birthYear, edited.gender, edited.sportType, edited.healthNotes), (1990, Gender.female, 'Koşu', 'Bel'));
    expect(edited.copyWith(heightCm: 181).sportType, 'Koşu');
    final cleared = edited.copyWith(clearSportType: true, clearHealthNotes: true);
    expect(cleared.sportType, isNull);
    expect(cleared.healthNotes, isNull);
  });

  test('database names round-trip', () {
    for (final level in ActivityLevel.values) {
      expect(activityLevelFromDb(activityLevelToDb(level)), level);
    }
    expect(activityLevelToDb(ActivityLevel.veryActive), 'very_active');
    for (final pace in Pace.values) {
      expect(paceFromDb(pace.name), pace);
    }
    expect(paceFromDb(null), isNull);
    expect(focusesToDb({GoalFocus.strength, GoalFocus.muscle}), ['muscle', 'strength']);
    expect(focusesFromDb(['general', 'endurance']), {GoalFocus.general, GoalFocus.endurance});
  });
}
