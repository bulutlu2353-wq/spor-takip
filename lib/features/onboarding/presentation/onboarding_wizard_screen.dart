import 'package:flutter/material.dart';

class OnboardingWizardScreen extends StatelessWidget {
  const OnboardingWizardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      key: Key('onboarding_screen'),
      body: Center(child: Text('Onboarding')),
    );
  }
}
