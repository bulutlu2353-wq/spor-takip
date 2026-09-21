import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/auth_providers.dart';
import '../application/onboarding_wizard_notifier.dart';
import '../application/profile_providers.dart';
import '../domain/onboarding_steps.dart';
import 'steps/onboarding_step_widgets.dart';

class OnboardingWizardScreen extends ConsumerStatefulWidget {
  const OnboardingWizardScreen({super.key});

  @override
  ConsumerState<OnboardingWizardScreen> createState() => _OnboardingWizardScreenState();
}

class _OnboardingWizardScreenState extends ConsumerState<OnboardingWizardScreen> {
  int _currentIndex = 0;
  bool _isSaving = false;
  String? _saveError;

  void _goBack() {
    setState(() => _currentIndex -= 1);
  }

  void _goNext(int stepCount) {
    if (_currentIndex < stepCount - 1) {
      setState(() => _currentIndex += 1);
    }
  }

  Future<void> _finish() async {
    final answers = ref.read(onboardingWizardProvider);
    if (!answers.isComplete) return;
    setState(() {
      _isSaving = true;
      _saveError = null;
    });
    try {
      final userId = ref.read(authRepositoryProvider).currentUserId;
      final profile = buildProfileFromAnswers(
        answers: answers,
        userId: userId,
        currentYear: DateTime.now().year,
      );
      await ref.read(profileRepositoryProvider).saveProfile(profile);
      ref.invalidate(profileProvider);
    } catch (_) {
      setState(() => _saveError = 'onboarding.save_error'.tr());
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isSaving) {
      return const Scaffold(
        key: Key('onboarding_screen'),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_saveError != null) {
      return Scaffold(
        key: const Key('onboarding_screen'),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_saveError!),
              ElevatedButton(onPressed: _finish, child: Text('onboarding.retry'.tr())),
            ],
          ),
        ),
      );
    }

    final answers = ref.watch(onboardingWizardProvider);
    final steps = visibleSteps(answers);
    final safeIndex = _currentIndex.clamp(0, steps.length - 1);
    final stepId = steps[safeIndex];
    final isLast = safeIndex == steps.length - 1;
    final onBack = safeIndex == 0 ? null : _goBack;
    final onNext = isLast ? _finish : () => _goNext(steps.length);
    final stepNumber = safeIndex + 1;
    final totalSteps = steps.length;

    final stepWidget = switch (stepId) {
      OnboardingStepId.weight => WeightStep(
          stepNumber: stepNumber,
          totalSteps: totalSteps,
          onNext: onNext,
          onBack: onBack,
        ),
      OnboardingStepId.height => HeightStep(
          stepNumber: stepNumber,
          totalSteps: totalSteps,
          onNext: onNext,
          onBack: onBack,
        ),
      OnboardingStepId.birthYear => BirthYearStep(
          stepNumber: stepNumber,
          totalSteps: totalSteps,
          onNext: onNext,
          onBack: onBack,
        ),
      OnboardingStepId.gender => GenderStep(
          stepNumber: stepNumber,
          totalSteps: totalSteps,
          onNext: onNext,
          onBack: onBack,
        ),
      OnboardingStepId.activityLevel => ActivityLevelStep(
          stepNumber: stepNumber,
          totalSteps: totalSteps,
          onNext: onNext,
          onBack: onBack,
        ),
      OnboardingStepId.doesExercise => DoesExerciseStep(
          stepNumber: stepNumber,
          totalSteps: totalSteps,
          onNext: onNext,
          onBack: onBack,
        ),
      OnboardingStepId.sportType => SportTypeStep(
          stepNumber: stepNumber,
          totalSteps: totalSteps,
          onNext: onNext,
          onBack: onBack,
        ),
      OnboardingStepId.exerciseDays => ExerciseDaysStep(
          stepNumber: stepNumber,
          totalSteps: totalSteps,
          onNext: onNext,
          onBack: onBack,
        ),
      OnboardingStepId.goal => GoalStep(
          stepNumber: stepNumber,
          totalSteps: totalSteps,
          onNext: onNext,
          onBack: onBack,
        ),
      OnboardingStepId.healthNotes => HealthNotesStep(
          stepNumber: stepNumber,
          totalSteps: totalSteps,
          onFinish: onNext,
          onBack: onBack,
        ),
    };

    return stepWidget;
  }
}
