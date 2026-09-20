import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/onboarding_answers.dart';
import '../domain/profile.dart';
import '../domain/tdee_calculator.dart';

final onboardingWizardProvider =
    NotifierProvider<OnboardingWizardNotifier, OnboardingAnswers>(
  OnboardingWizardNotifier.new,
);

class OnboardingWizardNotifier extends Notifier<OnboardingAnswers> {
  @override
  OnboardingAnswers build() => const OnboardingAnswers();

  void update(OnboardingAnswers Function(OnboardingAnswers) updater) {
    state = updater(state);
  }
}

/// [answers.isComplete] olduğu varsayılarak, hesaplanan hedeflerle birlikte
/// kaydedilmeye hazır bir [Profile] üretir. Saf fonksiyon — Supabase'e
/// dokunmaz, ayrıca çağıran taraf `saveProfile` ile kaydeder.
Profile buildProfileFromAnswers({
  required OnboardingAnswers answers,
  required String userId,
  required int currentYear,
  TdeeCalculator calculator = const TdeeCalculator(),
}) {
  assert(answers.isComplete, 'buildProfileFromAnswers tamamlanmamış cevaplarla çağrıldı');
  final doesExercise = answers.doesExercise!;
  final result = calculator.calculate(
    weightKg: answers.weightKg!,
    heightCm: answers.heightCm!,
    birthYear: answers.birthYear!,
    currentYear: currentYear,
    gender: answers.gender!,
    activityLevel: answers.activityLevel!,
    goal: answers.goal!,
  );
  return Profile(
    userId: userId,
    weightKg: answers.weightKg!,
    heightCm: answers.heightCm!,
    birthYear: answers.birthYear!,
    gender: answers.gender!,
    activityLevel: answers.activityLevel!,
    doesExercise: doesExercise,
    sportType: doesExercise ? answers.sportType : null,
    exerciseDaysPerWeek: doesExercise ? answers.exerciseDaysPerWeek! : 0,
    goal: answers.goal!,
    healthNotes: answers.healthNotes,
    dailyCalorieTarget: result.calorieTarget,
    dailyProteinTargetG: result.proteinTargetG,
  );
}
