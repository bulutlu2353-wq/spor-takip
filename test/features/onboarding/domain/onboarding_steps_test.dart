import 'package:flutter_test/flutter_test.dart';
import 'package:spor_takip/features/onboarding/domain/onboarding_answers.dart';
import 'package:spor_takip/features/onboarding/domain/onboarding_steps.dart';
import 'package:spor_takip/features/onboarding/domain/profile.dart';

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

    test('includes all 9 unconditional steps regardless of doesExercise', () {
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
          OnboardingStepId.weightDirection,
          OnboardingStepId.focuses,
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

    test('pace follows weightDirection only when losing or gaining weight', () {
      expect(visibleSteps(const OnboardingAnswers()), isNot(contains(OnboardingStepId.pace)));
      expect(
        visibleSteps(const OnboardingAnswers(weightDirection: WeightDirection.maintain)),
        isNot(contains(OnboardingStepId.pace)),
      );
      for (final direction in [WeightDirection.lose, WeightDirection.gain]) {
        final steps = visibleSteps(OnboardingAnswers(weightDirection: direction));
        final index = steps.indexOf(OnboardingStepId.weightDirection);
        expect(steps.sublist(index, index + 3), [
          OnboardingStepId.weightDirection,
          OnboardingStepId.pace,
          OnboardingStepId.focuses,
        ]);
      }
    });
  });
}
