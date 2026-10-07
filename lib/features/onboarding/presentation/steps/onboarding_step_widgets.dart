import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/onboarding_wizard_notifier.dart';
import '../../../progress/domain/progress_format.dart';
import '../../domain/profile.dart';
import '../../domain/tdee_calculator.dart';
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
      unit: 'kg',
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
      unit: 'cm',
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
        (Gender.male, 'onboarding.gender_male'.tr(), Icons.male),
        (Gender.female, 'onboarding.gender_female'.tr(), Icons.female),
        (Gender.unspecified, 'onboarding.gender_unspecified'.tr(), Icons.person_outline),
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
        (ActivityLevel.sedentary, 'onboarding.activity_sedentary'.tr(), Icons.weekend_outlined),
        (ActivityLevel.light, 'onboarding.activity_light'.tr(), Icons.directions_walk),
        (ActivityLevel.moderate, 'onboarding.activity_moderate'.tr(), Icons.directions_run),
        (ActivityLevel.active, 'onboarding.activity_active'.tr(), Icons.fitness_center),
        (ActivityLevel.veryActive, 'onboarding.activity_very_active'.tr(), Icons.bolt),
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
        (true, 'onboarding.yes'.tr(), Icons.check),
        (false, 'onboarding.no'.tr(), Icons.close),
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
      unit: 'onboarding.days_unit'.tr(),
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

class WeightDirectionStep extends ConsumerWidget {
  const WeightDirectionStep({
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
    return ChoiceStepScreen<WeightDirection>(
      title: 'onboarding.direction_question'.tr(),
      options: [
        (WeightDirection.lose, 'onboarding.direction_lose'.tr(), Icons.trending_down),
        (WeightDirection.maintain, 'onboarding.direction_maintain'.tr(), Icons.balance),
        (WeightDirection.gain, 'onboarding.direction_gain'.tr(), Icons.trending_up),
      ],
      selected: answers.weightDirection,
      onSave: (value) => ref
          .read(onboardingWizardProvider.notifier)
          .update((a) => a.copyWith(weightDirection: value)),
      onNext: onNext,
      onBack: onBack,
      stepNumber: stepNumber,
      totalSteps: totalSteps,
    );
  }
}

class PaceStep extends ConsumerWidget {
  const PaceStep({
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
    final weightKg = answers.weightKg ?? 0;
    final direction = answers.weightDirection ?? WeightDirection.lose;
    return ChoiceStepScreen<Pace>(
      title: 'onboarding.pace_question'.tr(),
      options: [
        (Pace.slow, 'onboarding.pace_slow'.tr(), Icons.directions_walk),
        (Pace.balanced, 'onboarding.pace_balanced'.tr(), Icons.speed),
        (Pace.fast, 'onboarding.pace_fast'.tr(), Icons.rocket_launch),
      ],
      subtitleOf: (pace) => 'onboarding.pace_estimate'.tr(
        namedArgs: {'kg': formatOneDecimal(weeklyChangeKg(weightKg, direction, pace))},
      ),
      selected: answers.pace,
      onSave: (value) => ref
          .read(onboardingWizardProvider.notifier)
          .update((a) => a.copyWith(pace: value)),
      onNext: onNext,
      onBack: onBack,
      stepNumber: stepNumber,
      totalSteps: totalSteps,
    );
  }
}

class FocusesStep extends ConsumerWidget {
  const FocusesStep({
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
    return MultiChoiceStepScreen<GoalFocus>(
      title: 'onboarding.focus_question'.tr(),
      hint: 'onboarding.focus_hint'.tr(),
      options: [
        (GoalFocus.muscle, 'onboarding.focus_muscle'.tr(), Icons.fitness_center),
        (GoalFocus.strength, 'onboarding.focus_strength'.tr(), Icons.bolt),
        (GoalFocus.endurance, 'onboarding.focus_endurance'.tr(), Icons.directions_run),
        (GoalFocus.general, 'onboarding.focus_general'.tr(), Icons.favorite),
      ],
      selected: answers.focuses,
      onChanged: (value) => ref
          .read(onboardingWizardProvider.notifier)
          .update((a) => a.copyWith(focuses: value)),
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
