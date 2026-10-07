import 'onboarding_answers.dart';
import 'profile.dart';

enum OnboardingStepId {
  weight,
  height,
  birthYear,
  gender,
  activityLevel,
  doesExercise,
  sportType,
  exerciseDays,
  weightDirection,
  pace,
  focuses,
  healthNotes,
}

/// Mevcut cevaplara göre gösterilecek adımların sırasını döner.
/// [OnboardingStepId.sportType] ve [OnboardingStepId.exerciseDays] sadece
/// `doesExercise == true` ise gösterilir.
/// [OnboardingStepId.pace] yalnızca kilo verme ya da alma seçiliyse gösterilir.
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
    OnboardingStepId.weightDirection,
    if (answers.weightDirection != null && answers.weightDirection != WeightDirection.maintain)
      OnboardingStepId.pace,
    OnboardingStepId.focuses,
    OnboardingStepId.healthNotes,
  ];
}
