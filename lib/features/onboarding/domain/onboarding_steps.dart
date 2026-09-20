import 'onboarding_answers.dart';

enum OnboardingStepId {
  weight,
  height,
  birthYear,
  gender,
  activityLevel,
  doesExercise,
  sportType,
  exerciseDays,
  goal,
  healthNotes,
}

/// Mevcut cevaplara göre gösterilecek adımların sırasını döner.
/// [OnboardingStepId.sportType] ve [OnboardingStepId.exerciseDays] sadece
/// `doesExercise == true` ise gösterilir.
List<OnboardingStepId> visibleSteps(OnboardingAnswers answers) {
  return [
    OnboardingStepId.weight,
    OnboardingStepId.height,
    OnboardingStepId.birthYear,
    OnboardingStepId.gender,
    OnboardingStepId.activityLevel,
    OnboardingStepId.doesExercise,
    if (answers.doesExercise == true) OnboardingStepId.sportType,
    if (answers.doesExercise == true) OnboardingStepId.exerciseDays,
    OnboardingStepId.goal,
    OnboardingStepId.healthNotes,
  ];
}
