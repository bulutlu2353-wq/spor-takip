import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/day_label.dart';
import '../../../shared/text_case.dart';
import '../../../shared/widgets/section_header.dart';
import '../../nutrition/presentation/widgets/today_nutrition_card.dart';
import '../../progress/presentation/widgets/home_stat_grid.dart';
import '../../workout/application/session_providers.dart';
import '../../workout/presentation/widgets/today_workout_card.dart';
import '../application/auth_providers.dart';
import '../application/onboarding_wizard_notifier.dart';
import '../application/profile_providers.dart';
import '../domain/home_greeting.dart';

/// Ana sayfa (spec §5): başlık, beslenme halkası, bugünkü antrenman, 2×2 özet.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(profileProvider);
    final now = ref.watch(nowProvider)();
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
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            children: [
              _HomeHeader(now: now),
              const SizedBox(height: 16),
              TodayNutritionCard(profile: profile),
              const SizedBox(height: 12),
              const TodayWorkoutCard(),
              SectionHeader('home.section_progress'.tr()),
              HomeStatGrid(profile: profile),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(child: Text('home.load_error'.tr())),
      ),
    );
  }
}

class _HomeHeader extends StatelessWidget {
  const _HomeHeader({required this.now});

  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final date = dayLabel(now);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          upperCaseFor(date, context.locale.languageCode),
          key: const Key('home_date'),
          style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant, letterSpacing: 1),
        ),
        const SizedBox(height: 4),
        Text(greetingKey(now).tr(), key: const Key('home_greeting'), style: theme.textTheme.headlineMedium),
      ],
    );
  }
}
