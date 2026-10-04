import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../shared/text_case.dart';
import '../../../../shared/widgets/ring_progress.dart';
import '../../domain/macro_totals.dart';

enum RemainingMode { remaining, over, noTarget }

/// Beslenme ekranı üst kartı (R2 spec §3): kalan / aşım / yenen kcal, bar ve
/// üç makro kutusu.
class RemainingCaloriesCard extends StatelessWidget {
  const RemainingCaloriesCard({
    super.key,
    required this.eaten,
    required this.calorieTarget,
    required this.proteinTarget,
  });

  final MacroTotals eaten;
  final double calorieTarget;
  final double proteinTarget;

  static RemainingMode modeFor(double eaten, double target) {
    if (target <= 0) return RemainingMode.noTarget;
    return RingProgress.isOver(eaten, target) ? RemainingMode.over : RemainingMode.remaining;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final languageCode = Localizations.localeOf(context).languageCode;
    final kcal = eaten.calories;
    final mode = modeFor(kcal, calorieTarget);
    final (labelKey, value) = switch (mode) {
      RemainingMode.remaining => ('nutrition.remaining', calorieTarget - kcal),
      RemainingMode.over => ('nutrition.over', kcal - calorieTarget),
      RemainingMode.noTarget => ('nutrition.eaten_label', kcal),
    };
    final isOver = mode == RemainingMode.over;
    final muted = scheme.onSurfaceVariant;

    return Card(
      key: const Key('remaining_calories_card'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              upperCaseFor(labelKey.tr(), languageCode),
              key: const Key('remaining_calories_label'),
              style: theme.textTheme.labelMedium?.copyWith(color: muted, letterSpacing: 1),
            ),
            const SizedBox(height: 4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  '${value.round()}',
                  key: const Key('remaining_calories_value'),
                  style: theme.textTheme.displaySmall?.copyWith(color: isOver ? scheme.error : scheme.onSurface),
                ),
                const SizedBox(width: 6),
                Text('nutrition.kcal'.tr(), style: theme.textTheme.bodyMedium?.copyWith(color: muted)),
              ],
            ),
            if (mode != RemainingMode.noTarget) ...[
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  key: const Key('remaining_calories_bar'),
                  value: RingProgress.fraction(kcal, calorieTarget),
                  minHeight: 7,
                  color: isOver ? scheme.error : scheme.primary,
                  backgroundColor: scheme.outlineVariant,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'nutrition.eaten_of_target'.tr(namedArgs: {
                  'eaten': '${kcal.round()}',
                  'target': '${calorieTarget.round()}',
                }),
                style: theme.textTheme.bodySmall?.copyWith(color: muted),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _MacroChip(
                    key: const Key('remaining_macro_protein'),
                    label: 'nutrition.protein_short'.tr(),
                    value: proteinTarget > 0
                        ? '${eaten.proteinG.round()}/${proteinTarget.round()} g'
                        : '${eaten.proteinG.round()} g',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _MacroChip(
                    key: const Key('remaining_macro_carbs'),
                    label: 'nutrition.carbs_short'.tr(),
                    value: '${eaten.carbsG.round()} g',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _MacroChip(
                    key: const Key('remaining_macro_fat'),
                    label: 'nutrition.fat_short'.tr(),
                    value: '${eaten.fatG.round()} g',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MacroChip extends StatelessWidget {
  const _MacroChip({super.key, required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.outlineVariant,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(value, key: const ValueKey('macro_chip_value'), style: theme.textTheme.titleSmall),
          const SizedBox(height: 2),
          Text(label, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}
