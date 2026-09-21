import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/onboarding_wizard_notifier.dart';
import '../../domain/profile.dart';
import 'step_scaffolds.dart';

class WeightStep extends ConsumerWidget {
  const WeightStep({
    super.key,
    required this.stepNumber,
    required this.totalSteps,
    required this.onNext,
    required this.onBack,
  });

  final int stepNumber;
  final int totalSteps;
  final VoidCallback onNext;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final answers = ref.watch(onboardingWizardProvider);
    return NumericStepScreen(
      title: 'onboarding.weight_question'.tr(),
      hintText: 'onboarding.weight_hint'.tr(),
      min: 20,
      max: 300,
      initialValue: answers.weightKg,
      onSave: (value) => ref
          .read(onboardingWizardProvider.notifier)
          .update((a) => a.copyWith(weightKg: value)),
      onNext: onNext,
      onBack: onBack,
      stepNumber: stepNumber,
      totalSteps: totalSteps,
    );
  }
}

class HeightStep extends ConsumerWidget {
  const HeightStep({
    super.key,
    required this.stepNumber,
    required this.totalSteps,
    required this.onNext,
    required this.onBack,
  });

  final int stepNumber;
  final int totalSteps;
  final VoidCallback onNext;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final answers = ref.watch(onboardingWizardProvider);
    return NumericStepScreen(
      title: 'onboarding.height_question'.tr(),
      hintText: 'onboarding.height_hint'.tr(),
      min: 100,
      max: 250,
      initialValue: answers.heightCm,
      onSave: (value) => ref
          .read(onboardingWizardProvider.notifier)
          .update((a) => a.copyWith(heightCm: value)),
      onNext: onNext,
      onBack: onBack,
      stepNumber: stepNumber,
      totalSteps: totalSteps,
    );
  }
}

class BirthYearStep extends ConsumerWidget {
  const BirthYearStep({
    super.key,
    required this.stepNumber,
    required this.totalSteps,
    required this.onNext,
    required this.onBack,
  });

  final int stepNumber;
  final int totalSteps;
  final VoidCallback onNext;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final answers = ref.watch(onboardingWizardProvider);
    return NumericStepScreen(
      title: 'onboarding.birth_year_question'.tr(),
      hintText: 'onboarding.birth_year_hint'.tr(),
      min: 1920,
      max: 2020,
      initialValue: answers.birthYear?.toDouble(),
      onSave: (value) => ref
          .read(onboardingWizardProvider.notifier)
          .update((a) => a.copyWith(birthYear: value.round())),
      onNext: onNext,
      onBack: onBack,
      stepNumber: stepNumber,
      totalSteps: totalSteps,
    );
  }
}

class GenderStep extends ConsumerWidget {
  const GenderStep({
    super.key,
    required this.stepNumber,
    required this.totalSteps,
    required this.onNext,
    required this.onBack,
  });

  final int stepNumber;
  final int totalSteps;
  final VoidCallback onNext;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final answers = ref.watch(onboardingWizardProvider);
    return ChoiceStepScreen<Gender>(
      title: 'onboarding.gender_question'.tr(),
      options: [
        (Gender.male, 'onboarding.gender_male'.tr()),
        (Gender.female, 'onboarding.gender_female'.tr()),
        (Gender.unspecified, 'onboarding.gender_unspecified'.tr()),
      ],
      selected: answers.gender,
      onSave: (value) => ref
          .read(onboardingWizardProvider.notifier)
          .update((a) => a.copyWith(gender: value)),
      onNext: onNext,
      onBack: onBack,
      stepNumber: stepNumber,
      totalSteps: totalSteps,
    );
  }
}

class ActivityLevelStep extends ConsumerWidget {
  const ActivityLevelStep({
    super.key,
    required this.stepNumber,
    required this.totalSteps,
    required this.onNext,
    required this.onBack,
  });

  final int stepNumber;
  final int totalSteps;
  final VoidCallback onNext;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final answers = ref.watch(onboardingWizardProvider);
    return ChoiceStepScreen<ActivityLevel>(
      title: 'onboarding.activity_question'.tr(),
      options: [
        (ActivityLevel.sedentary, 'onboarding.activity_sedentary'.tr()),
        (ActivityLevel.light, 'onboarding.activity_light'.tr()),
        (ActivityLevel.moderate, 'onboarding.activity_moderate'.tr()),
        (ActivityLevel.active, 'onboarding.activity_active'.tr()),
        (ActivityLevel.veryActive, 'onboarding.activity_very_active'.tr()),
      ],
      selected: answers.activityLevel,
      onSave: (value) => ref
          .read(onboardingWizardProvider.notifier)
          .update((a) => a.copyWith(activityLevel: value)),
      onNext: onNext,
      onBack: onBack,
      stepNumber: stepNumber,
      totalSteps: totalSteps,
    );
  }
}

class DoesExerciseStep extends ConsumerWidget {
  const DoesExerciseStep({
    super.key,
    required this.stepNumber,
    required this.totalSteps,
    required this.onNext,
    required this.onBack,
  });

  final int stepNumber;
  final int totalSteps;
  final VoidCallback onNext;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final answers = ref.watch(onboardingWizardProvider);
    return ChoiceStepScreen<bool>(
      title: 'onboarding.does_exercise_question'.tr(),
      options: [
        (true, 'onboarding.yes'.tr()),
        (false, 'onboarding.no'.tr()),
      ],
      selected: answers.doesExercise,
      onSave: (value) => ref
          .read(onboardingWizardProvider.notifier)
          .update((a) => a.copyWith(doesExercise: value)),
      onNext: onNext,
      onBack: onBack,
      stepNumber: stepNumber,
      totalSteps: totalSteps,
    );
  }
}

class SportTypeStep extends ConsumerWidget {
  const SportTypeStep({
    super.key,
    required this.stepNumber,
    required this.totalSteps,
    required this.onNext,
    required this.onBack,
  });

  final int stepNumber;
  final int totalSteps;
  final VoidCallback onNext;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final answers = ref.watch(onboardingWizardProvider);
    return TextStepScreen(
      title: 'onboarding.sport_type_question'.tr(),
      hintText: 'onboarding.sport_type_hint'.tr(),
      initialValue: answers.sportType,
      required: true,
      onSave: (value) => ref
          .read(onboardingWizardProvider.notifier)
          .update((a) => a.copyWith(sportType: value)),
      onNext: onNext,
      onBack: onBack,
      stepNumber: stepNumber,
      totalSteps: totalSteps,
    );
  }
}

class ExerciseDaysStep extends ConsumerWidget {
  const ExerciseDaysStep({
    super.key,
    required this.stepNumber,
    required this.totalSteps,
    required this.onNext,
    required this.onBack,
  });

  final int stepNumber;
  final int totalSteps;
  final VoidCallback onNext;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final answers = ref.watch(onboardingWizardProvider);
    return NumericStepScreen(
      title: 'onboarding.exercise_days_question'.tr(),
      hintText: 'onboarding.exercise_days_hint'.tr(),
      min: 0,
      max: 7,
      initialValue: answers.exerciseDaysPerWeek?.toDouble(),
      onSave: (value) => ref
          .read(onboardingWizardProvider.notifier)
          .update((a) => a.copyWith(exerciseDaysPerWeek: value.round())),
      onNext: onNext,
      onBack: onBack,
      stepNumber: stepNumber,
      totalSteps: totalSteps,
    );
  }
}

class GoalStep extends ConsumerWidget {
  const GoalStep({
    super.key,
    required this.stepNumber,
    required this.totalSteps,
    required this.onNext,
    required this.onBack,
  });

  final int stepNumber;
  final int totalSteps;
  final VoidCallback onNext;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final answers = ref.watch(onboardingWizardProvider);
    return ChoiceStepScreen<Goal>(
      title: 'onboarding.goal_question'.tr(),
      options: [
        (Goal.loseWeight, 'onboarding.goal_lose_weight'.tr()),
        (Goal.gainMuscle, 'onboarding.goal_gain_muscle'.tr()),
        (Goal.maintain, 'onboarding.goal_maintain'.tr()),
      ],
      selected: answers.goal,
      onSave: (value) => ref
          .read(onboardingWizardProvider.notifier)
          .update((a) => a.copyWith(goal: value)),
      onNext: onNext,
      onBack: onBack,
      stepNumber: stepNumber,
      totalSteps: totalSteps,
    );
  }
}

class HealthNotesStep extends ConsumerWidget {
  const HealthNotesStep({
    super.key,
    required this.stepNumber,
    required this.totalSteps,
    required this.onFinish,
    required this.onBack,
  });

  final int stepNumber;
  final int totalSteps;
  final VoidCallback onFinish;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final answers = ref.watch(onboardingWizardProvider);
    return TextStepScreen(
      title: 'onboarding.health_notes_question'.tr(),
      hintText: 'onboarding.health_notes_hint'.tr(),
      initialValue: answers.healthNotes,
      required: false,
      nextLabel: 'onboarding.finish'.tr(),
      onSave: (value) => ref
          .read(onboardingWizardProvider.notifier)
          .update((a) => a.copyWith(healthNotes: value)),
      onNext: onFinish,
      onBack: onBack,
      stepNumber: stepNumber,
      totalSteps: totalSteps,
    );
  }
}
