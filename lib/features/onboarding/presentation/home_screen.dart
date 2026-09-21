import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/auth_providers.dart';
import '../application/onboarding_wizard_notifier.dart';
import '../application/profile_providers.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(profileProvider);
    return Scaffold(
      key: const Key('home_screen'),
      appBar: AppBar(
        title: Text('home.title'.tr()),
        actions: [
          IconButton(
            key: const Key('home_sign_out_button'),
            icon: const Icon(Icons.logout),
            onPressed: () {
              ref.invalidate(onboardingWizardProvider);
              ref.read(authRepositoryProvider).signOut();
            },
          ),
        ],
      ),
      body: profileAsync.when(
        data: (profile) {
          if (profile == null) {
            return Center(child: Text('home.no_profile'.tr()));
          }
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'home.calorie_target'.tr(
                    namedArgs: {'value': profile.dailyCalorieTarget.round().toString()},
                  ),
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'home.protein_target'.tr(
                    namedArgs: {'value': profile.dailyProteinTargetG.round().toString()},
                  ),
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(child: Text('home.load_error'.tr())),
      ),
    );
  }
}
