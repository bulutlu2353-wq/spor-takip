import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spor_takip/features/onboarding/application/onboarding_wizard_notifier.dart';
import 'package:spor_takip/features/onboarding/domain/onboarding_answers.dart';
import 'package:spor_takip/features/onboarding/domain/profile.dart';

void main() {
  test('buildProfileFromAnswers computes targets and maps fields', () {
    const answers = OnboardingAnswers(
      weightKg: 80,
      heightCm: 180,
      birthYear: 1996,
      gender: Gender.male,
      activityLevel: ActivityLevel.sedentary,
      doesExercise: true,
      sportType: 'Fitness',
      exerciseDaysPerWeek: 3,
      weightDirection: WeightDirection.maintain,
      focuses: {GoalFocus.general},
      healthNotes: null,
    );

    final profile = buildProfileFromAnswers(
      answers: answers,
      userId: 'user-1',
      currentYear: 2026,
    );

    expect(profile.userId, 'user-1');
    expect(profile.sportType, 'Fitness');
    expect(profile.exerciseDaysPerWeek, 3);
    expect(profile.dailyCalorieTarget, closeTo(2136.0, 0.01));
    expect(profile.dailyProteinTargetG, closeTo(128.0, 0.01));
    expect(profile.weightDirection, WeightDirection.maintain);
    expect(profile.pace, isNull);
    expect(profile.focuses, {GoalFocus.general});
  });

  test('buildProfileFromAnswers nulls out sportType when doesExercise is false', () {
    const answers = OnboardingAnswers(
      weightKg: 60,
      heightCm: 165,
      birthYear: 2001,
      gender: Gender.female,
      activityLevel: ActivityLevel.moderate,
      doesExercise: false,
      sportType: null,
      exerciseDaysPerWeek: null,
      weightDirection: WeightDirection.lose,
      pace: Pace.balanced,
      focuses: {GoalFocus.muscle},
      healthNotes: 'Diz sakatlığı geçmişi',
    );

    final profile = buildProfileFromAnswers(
      answers: answers,
      userId: 'user-2',
      currentYear: 2026,
    );

    expect(profile.sportType, isNull);
    expect(profile.exerciseDaysPerWeek, 0);
    expect(profile.healthNotes, 'Diz sakatlığı geçmişi');
    expect(profile.pace, Pace.balanced);
    expect(profile.dailyCalorieTarget, closeTo(1590.1375, 0.01));
    expect(profile.dailyProteinTargetG, closeTo(132.0, 0.01));
  });

  const goalBase = OnboardingAnswers(
    weightKg: 80,
    heightCm: 180,
    birthYear: 1996,
    gender: Gender.male,
    activityLevel: ActivityLevel.sedentary,
    doesExercise: false,
  );

  test('buildProfileFromAnswers drops a leftover pace when maintaining', () {
    final profile = buildProfileFromAnswers(
      answers: goalBase.copyWith(
        weightDirection: WeightDirection.maintain,
        pace: Pace.fast,
        focuses: {GoalFocus.general},
      ),
      userId: 'user-3',
      currentYear: 2026,
    );
    expect(profile.pace, isNull);
    expect(profile.dailyCalorieTarget, closeTo(2136.0, 0.01));
  });

  test('isComplete needs a pace unless maintaining, and at least one focus', () {
    expect(goalBase.isComplete, isFalse);
    expect(goalBase.copyWith(weightDirection: WeightDirection.lose, focuses: {GoalFocus.muscle}).isComplete, isFalse);
    expect(
      goalBase.copyWith(weightDirection: WeightDirection.lose, pace: Pace.slow, focuses: {GoalFocus.muscle}).isComplete,
      isTrue,
    );
    expect(goalBase.copyWith(weightDirection: WeightDirection.maintain).isComplete, isFalse);
    expect(goalBase.copyWith(weightDirection: WeightDirection.maintain, focuses: {GoalFocus.general}).isComplete, isTrue);
  });

  test('OnboardingWizardNotifier starts empty and updates via copyWith', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(onboardingWizardProvider).weightKg, isNull);

    container
        .read(onboardingWizardProvider.notifier)
        .update((answers) => answers.copyWith(weightKg: 80));

    expect(container.read(onboardingWizardProvider).weightKg, 80);
  });
}
