import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/widgets/section_header.dart';
import '../../onboarding/application/auth_providers.dart';
import '../../onboarding/application/onboarding_wizard_notifier.dart';
import '../../onboarding/application/profile_providers.dart';
import '../../onboarding/domain/profile.dart';
import '../../progress/domain/progress_format.dart';
import '../../progress/presentation/widgets/card_states.dart';
import 'widgets/goal_summary_card.dart';
import 'widgets/profile_field_sheets.dart';

/// Profil ve ayarlar (G2 spec §4.1): hedef kartı, profil satırları, dil, hesap.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(profileProvider);
    return Scaffold(
      key: const Key('settings_screen'),
      appBar: AppBar(title: Text('settings.title'.tr())),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(child: CardError(onRetry: () => ref.invalidate(profileProvider))),
        data: (profile) => profile == null
            ? Center(child: Text('home.no_profile'.tr()))
            : _SettingsList(profile: profile),
      ),
    );
  }
}

class _SettingsList extends ConsumerWidget {
  const _SettingsList({required this.profile});

  final Profile profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final rows = [
      _row(context, 'weight', 'settings.row_weight'.tr(), '${formatOneDecimal(profile.weightKg)} kg',
          () => context.push('/home/weight')),
      _row(context, 'height', 'settings.row_height'.tr(), '${formatOneDecimal(profile.heightCm)} cm',
          () => showProfileSheet(context, NumberFieldSheet(
                title: 'settings.row_height'.tr(),
                profile: profile,
                initial: profile.heightCm,
                min: 100,
                max: 250,
                unit: 'cm',
                apply: (p, v) => p.copyWith(heightCm: v),
              ))),
      _row(context, 'birth_year', 'settings.row_birth_year'.tr(), '${profile.birthYear}',
          () => showProfileSheet(context, NumberFieldSheet(
                title: 'settings.row_birth_year'.tr(),
                profile: profile,
                initial: profile.birthYear.toDouble(),
                min: 1920,
                max: 2020,
                apply: (p, v) => p.copyWith(birthYear: v.round()),
              ))),
      _row(context, 'gender', 'settings.row_gender'.tr(), 'onboarding.gender_${profile.gender.name}'.tr(),
          () => showProfileSheet(context, ChoiceFieldSheet<Gender>(
                title: 'settings.row_gender'.tr(),
                profile: profile,
                initial: profile.gender,
                options: [
                  (Gender.male, 'onboarding.gender_male'.tr(), Icons.male),
                  (Gender.female, 'onboarding.gender_female'.tr(), Icons.female),
                  (Gender.unspecified, 'onboarding.gender_unspecified'.tr(), Icons.person_outline),
                ],
                apply: (p, v) => p.copyWith(gender: v),
              ))),
      _row(context, 'activity', 'settings.row_activity'.tr(),
          'onboarding.activity_${activityLevelToDb(profile.activityLevel)}'.tr(),
          () => showProfileSheet(context, ChoiceFieldSheet<ActivityLevel>(
                title: 'settings.row_activity'.tr(),
                profile: profile,
                initial: profile.activityLevel,
                options: [
                  (ActivityLevel.sedentary, 'onboarding.activity_sedentary'.tr(), Icons.weekend_outlined),
                  (ActivityLevel.light, 'onboarding.activity_light'.tr(), Icons.directions_walk),
                  (ActivityLevel.moderate, 'onboarding.activity_moderate'.tr(), Icons.directions_run),
                  (ActivityLevel.active, 'onboarding.activity_active'.tr(), Icons.fitness_center),
                  (ActivityLevel.veryActive, 'onboarding.activity_very_active'.tr(), Icons.bolt),
                ],
                apply: (p, v) => p.copyWith(activityLevel: v),
              ))),
      _row(context, 'sport', 'settings.row_sport'.tr(), _sportSummary(),
          () => showProfileSheet(context, SportSheet(profile: profile))),
      _row(context, 'health_notes', 'settings.row_health_notes'.tr(), profile.healthNotes ?? '—',
          () => showProfileSheet(context, HealthNotesSheet(profile: profile))),
    ];
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: [
        SectionHeader('settings.section_goal'.tr()),
        GoalSummaryCard(profile: profile, onTap: () => context.push('/home/settings/goals')),
        SectionHeader('settings.section_profile'.tr()),
        Card(
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (var i = 0; i < rows.length; i++) ...[
                if (i > 0) const Divider(height: 1),
                rows[i],
              ],
            ],
          ),
        ),
        SectionHeader('settings.section_language'.tr()),
        const _LanguageSelector(),
        SectionHeader('settings.section_account'.tr()),
        Card(
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              ListTile(
                key: const Key('settings_email'),
                leading: const Icon(Icons.mail_outline),
                title: Text(ref.watch(authRepositoryProvider).currentEmail ?? '—'),
              ),
              const Divider(height: 1),
              ListTile(
                key: const Key('settings_sign_out'),
                leading: Icon(Icons.logout, color: scheme.error),
                title: Text('settings.sign_out'.tr(), style: TextStyle(color: scheme.error)),
                onTap: () => _confirmSignOut(context, ref),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _sportSummary() {
    if (!profile.doesExercise) return 'settings.sport_none'.tr();
    return 'settings.sport_summary'.tr(namedArgs: {
      'sport': profile.sportType ?? '—',
      'days': '${profile.exerciseDaysPerWeek}',
    });
  }

  Widget _row(BuildContext context, String field, String label, String value, VoidCallback onTap) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return ListTile(
      key: Key('settings_row_$field'),
      title: Text(label),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 160),
            child: Text(
              value,
              key: Key('settings_value_$field'),
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(color: muted),
            ),
          ),
          const SizedBox(width: 4),
          Icon(Icons.chevron_right, color: muted),
        ],
      ),
      onTap: onTap,
    );
  }

  Future<void> _confirmSignOut(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        content: Text('settings.sign_out_confirm'.tr()),
        actions: [
          TextButton(
            key: const Key('settings_sign_out_cancel'),
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('settings.cancel'.tr()),
          ),
          FilledButton(
            key: const Key('settings_sign_out_confirm'),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('settings.sign_out'.tr()),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    ref.invalidate(onboardingWizardProvider);
    await ref.read(authRepositoryProvider).signOut();
  }
}

/// Türkçe / English; seçim easy_localization tarafından kalıcı saklanır.
class _LanguageSelector extends StatelessWidget {
  const _LanguageSelector();

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<String>(
      key: const Key('settings_language'),
      showSelectedIcon: false,
      segments: [
        ButtonSegment(value: 'tr', label: Text('settings.language_tr'.tr(), key: const Key('settings_language_tr'))),
        ButtonSegment(value: 'en', label: Text('settings.language_en'.tr(), key: const Key('settings_language_en'))),
      ],
      selected: {context.locale.languageCode},
      onSelectionChanged: (selection) => context.setLocale(Locale(selection.first)),
    );
  }
}
