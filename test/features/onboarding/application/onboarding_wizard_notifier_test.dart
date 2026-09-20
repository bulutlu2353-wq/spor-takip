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
      goal: Goal.maintain,
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
    expect(profile.dailyProteinTargetG, closeTo(136.0, 0.01));
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
      goal: Goal.loseWeight,
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
