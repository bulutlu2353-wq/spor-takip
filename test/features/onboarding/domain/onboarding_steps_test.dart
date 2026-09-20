import 'package:flutter_test/flutter_test.dart';
import 'package:spor_takip/features/onboarding/domain/onboarding_answers.dart';
import 'package:spor_takip/features/onboarding/domain/onboarding_steps.dart';

void main() {
  group('visibleSteps', () {
    test('excludes sportType and exerciseDays when doesExercise is false', () {
      const answers = OnboardingAnswers(doesExercise: false);
      final steps = visibleSteps(answers);
      expect(steps, isNot(contains(OnboardingStepId.sportType)));
      expect(steps, isNot(contains(OnboardingStepId.exerciseDays)));
    });

    test('includes sportType and exerciseDays when doesExercise is true', () {
      const answers = OnboardingAnswers(doesExercise: true);
      final steps = visibleSteps(answers);
      expect(steps, contains(OnboardingStepId.sportType));
      expect(steps, contains(OnboardingStepId.exerciseDays));
    });

    test('includes all 8 unconditional steps regardless of doesExercise', () {
      const answers = OnboardingAnswers();
      final steps = visibleSteps(answers);
      expect(
        steps,
        containsAll(const [
          OnboardingStepId.weight,
          OnboardingStepId.height,
          OnboardingStepId.birthYear,
          OnboardingStepId.gender,
          OnboardingStepId.activityLevel,
          OnboardingStepId.doesExercise,
          OnboardingStepId.goal,
          OnboardingStepId.healthNotes,
        ]),
      );
    });

    test('healthNotes is always the last step', () {
      expect(visibleSteps(const OnboardingAnswers()).last, OnboardingStepId.healthNotes);
      expect(
        visibleSteps(const OnboardingAnswers(doesExercise: true)).last,
        OnboardingStepId.healthNotes,
      );
    });
  });
}
