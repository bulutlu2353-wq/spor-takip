import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/widgets/accent_chip.dart';
import '../../../shared/widgets/section_header.dart';
import '../../onboarding/application/profile_providers.dart';
import '../../onboarding/domain/profile.dart';
import '../../onboarding/domain/tdee_calculator.dart';
import '../../onboarding/presentation/widgets/choice_card.dart';
import '../../progress/domain/progress_format.dart';
import '../../progress/presentation/widgets/card_states.dart';
import '../../workout/application/session_providers.dart';
import '../application/profile_saver.dart';
import '../domain/profile_edit.dart';
import 'widgets/settings_save_button.dart';
import 'widgets/targets_preview.dart';

/// Hedeflerim (G2 spec §4.2): kilo yönü, hız (ver/al), odaklar; canlı önizleme.
class GoalsScreen extends ConsumerWidget {
  const GoalsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(profileProvider);
    return Scaffold(
      key: const Key('goals_screen'),
      appBar: AppBar(title: Text('settings.goals_title'.tr())),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(child: CardError(onRetry: () => ref.invalidate(profileProvider))),
        data: (profile) => profile == null
            ? Center(child: Text('home.no_profile'.tr()))
            : _GoalsEditor(profile: profile),
      ),
    );
  }
}

class _GoalsEditor extends ConsumerStatefulWidget {
  const _GoalsEditor({required this.profile});

  final Profile profile;

  @override
  ConsumerState<_GoalsEditor> createState() => _GoalsEditorState();
}

class _GoalsEditorState extends ConsumerState<_GoalsEditor> {
  static const _paceIcons = {
    Pace.slow: Icons.directions_walk,
    Pace.balanced: Icons.speed,
    Pace.fast: Icons.rocket_launch,
  };

  late WeightDirection _direction = widget.profile.weightDirection;
  late Pace? _pace = widget.profile.pace;
  late final Set<GoalFocus> _focuses = {...widget.profile.focuses};
  bool _saving = false;

  Profile get _draft => widget.profile.copyWith(
        weightDirection: _direction,
        pace: _pace,
        clearPace: _pace == null,
        focuses: {..._focuses},
      );

  void _setDirection(WeightDirection direction) {
    setState(() {
      _direction = direction;
      _pace = direction == WeightDirection.maintain ? null : _pace ?? Pace.balanced;
    });
  }

  void _toggleFocus(GoalFocus focus, bool on) {
    setState(() => on ? _focuses.add(focus) : _focuses.remove(focus));
  }

  Future<void> _save(Map<String, dynamic> changes) async {
    setState(() => _saving = true);
    final ok = await saveProfileChanges(ref, changes);
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) {
      if (context.canPop()) context.pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('settings.save_error'.tr())));
    }
  }

  Future<void> _resetAdjustment() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        content: Text('settings.adjustment_reset_confirm'.tr()),
        actions: [
          TextButton(
            key: const Key('goals_reset_cancel'),
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('settings.cancel'.tr()),
          ),
          FilledButton(
            key: const Key('goals_reset_confirm'),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('settings.adjustment_reset_button'.tr()),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final ok = await saveProfileChanges(ref, resetAdjustmentFields(widget.profile, now: ref.read(nowProvider)()));
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('settings.save_error'.tr())));
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = ref.watch(nowProvider)();
    final year = now.year;
    final draft = _draft;
    final changes = profileChanges(widget.profile, draft, now: now);
    final targets = targetsFor(draft, currentYear: year);
    final canSave = changes.isNotEmpty && _focuses.isNotEmpty;
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            children: [
              SectionHeader('settings.section_direction'.tr()),
              Wrap(
                spacing: 8,
                children: [
                  for (final direction in WeightDirection.values)
                    AccentChip(
                      key: Key('goal_direction_${direction.name}'),
                      label: 'onboarding.direction_${direction.name}'.tr(),
                      selected: direction == _direction,
                      onSelected: (_) => _setDirection(direction),
                    ),
                ],
              ),
              if (_direction != WeightDirection.maintain) ...[
                SectionHeader('settings.section_pace'.tr()),
                for (final pace in Pace.values)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: ChoiceCard(
                      key: Key('choice_option_$pace'),
                      label: 'onboarding.pace_${pace.name}'.tr(),
                      icon: _paceIcons[pace]!,
                      subtitle: 'onboarding.pace_estimate'.tr(namedArgs: {
                        'kg': formatOneDecimal(weeklyChangeKg(widget.profile.weightKg, _direction, pace)),
                      }),
                      selected: pace == _pace,
                      onTap: () => setState(() => _pace = pace),
                    ),
                  ),
              ],
              SectionHeader('settings.section_focuses'.tr()),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final focus in GoalFocus.values)
                    AccentChip(
                      key: Key('goal_focus_${focus.name}'),
                      label: 'onboarding.focus_${focus.name}'.tr(),
                      selected: _focuses.contains(focus),
                      onSelected: (on) => _toggleFocus(focus, on),
                    ),
                ],
              ),
              if (widget.profile.calorieAdjustmentKcal != 0) ...[
                const SizedBox(height: 24),
                Center(
                  child: TextButton(
                    key: const Key('goals_reset_adjustment'),
                    onPressed: _saving ? null : _resetAdjustment,
                    child: Text('settings.adjustment_reset'.tr()),
                  ),
                ),
              ],
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TargetsPreview(calories: targets.calorieTarget, proteinG: targets.proteinTargetG),
                const SizedBox(height: 12),
                SettingsSaveButton(
                  key: const Key('goals_save'),
                  saving: _saving,
                  onPressed: canSave ? () => _save(changes) : null,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
