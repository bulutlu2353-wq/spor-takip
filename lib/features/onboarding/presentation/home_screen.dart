import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/auth_providers.dart';
import '../application/onboarding_wizard_notifier.dart';
import '../application/profile_providers.dart';
import '../../progress/presentation/widgets/targets_card.dart';
import '../../progress/presentation/widgets/weekly_summary_card.dart';
import '../../workout/presentation/widgets/today_workout_card.dart';

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
          return ListView(
            key: const Key('home_list'),
            padding: const EdgeInsets.all(16),
            children: [
              TargetsCard(profile: profile),
              const SizedBox(height: 12),
              const TodayWorkoutCard(),
              const SizedBox(height: 12),
              const WeeklySummaryCard(),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(child: Text('home.load_error'.tr())),
      ),
    );
  }
}
