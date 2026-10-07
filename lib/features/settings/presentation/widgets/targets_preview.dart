import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

/// "Yeni hedef: X kcal · Y g protein" (G2 spec §4).
class TargetsPreview extends StatelessWidget {
  const TargetsPreview({super.key, required this.calories, required this.proteinG});

  final double calories;
  final double proteinG;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      key: const Key('settings_targets_preview'),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.outlineVariant,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        'settings.new_targets'.tr(namedArgs: {
          'kcal': calories.round().toString(),
          'protein': proteinG.round().toString(),
        }),
        style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
      ),
    );
  }
}
