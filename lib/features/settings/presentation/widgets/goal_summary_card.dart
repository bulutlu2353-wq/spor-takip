import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_fonts.dart';
import '../../../../shared/date_label.dart';
import '../../../onboarding/domain/profile.dart';
import '../../../onboarding/domain/tdee_calculator.dart';
import '../../../progress/domain/progress_format.dart';

/// Ayarların üstündeki hedef kartı (G2 spec §4.1): yön + hız, odaklar ve
/// haftalık tahmin, mevcut kcal/protein hedefi.
class GoalSummaryCard extends StatelessWidget {
  const GoalSummaryCard({super.key, required this.profile, required this.onTap});

  final Profile profile;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final direction = 'onboarding.direction_${profile.weightDirection.name}'.tr();
    final pace = profile.pace;
    final headline = pace == null ? direction : '$direction · ${'onboarding.pace_${pace.name}'.tr()}';
    final focuses = [
      for (final focus in GoalFocus.values)
        if (profile.focuses.contains(focus)) 'onboarding.focus_${focus.name}'.tr(),
    ];
    final weekly = weeklyChangeKg(profile.weightKg, profile.weightDirection, pace);
    final detail = [
      focuses.isEmpty ? 'settings.no_focus'.tr() : focuses.join(', '),
      if (weekly > 0) 'onboarding.pace_estimate'.tr(namedArgs: {'kg': formatOneDecimal(weekly)}),
    ].join(' · ');
    const radius = BorderRadius.all(Radius.circular(16));
    return Material(
      color: scheme.surfaceContainer,
      shape: RoundedRectangleBorder(borderRadius: radius, side: BorderSide(color: scheme.primary, width: 1.5)),
      child: InkWell(
        key: const Key('settings_goal_card'),
        customBorder: const RoundedRectangleBorder(borderRadius: radius),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                headline,
                key: const Key('settings_goal_headline'),
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                detail,
                key: const Key('settings_goal_detail'),
                style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
              if (profile.calorieAdjustmentKcal != 0) ...[
                const SizedBox(height: 4),
                Text(
                  _adjustmentLine(),
                  key: const Key('settings_goal_adjustment'),
                  style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _number(context, profile.dailyCalorieTarget, 'kcal'),
                  const SizedBox(width: 20),
                  _number(context, profile.dailyProteinTargetG, 'settings.protein_unit'.tr()),
                  const Spacer(),
                  Text('${'settings.edit'.tr()} ›', style: theme.textTheme.labelLarge?.copyWith(color: scheme.primary)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// "Uyarlandı: −160 kcal · 8 Ekim" (G3 spec §5.2).
  String _adjustmentLine() {
    final value = profile.calorieAdjustmentKcal.round();
    final kcal = value > 0 ? '+$value' : '−${value.abs()}';
    final at = profile.calorieAdjustedAt;
    return at == null
        ? 'settings.adjustment_line_short'.tr(namedArgs: {'kcal': kcal})
        : 'settings.adjustment_line'.tr(namedArgs: {'kcal': kcal, 'date': shortDateLabel(at, DateTime.now())});
  }

  Widget _number(BuildContext context, double value, String unit) {
    final theme = Theme.of(context);
    return Text.rich(
      TextSpan(children: [
        TextSpan(
          text: value.round().toString(),
          style: TextStyle(
            fontFamily: AppFonts.heading,
            fontWeight: FontWeight.w900,
            fontSize: 22,
            color: theme.colorScheme.primary,
          ),
        ),
        TextSpan(
          text: ' $unit',
          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      ]),
    );
  }
}
