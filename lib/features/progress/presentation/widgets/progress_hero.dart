import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../shared/text_case.dart';
import '../../domain/progress_format.dart';
import '../../domain/trend.dart';

String rangeLabelKey(ChartRange range) => switch (range) {
      ChartRange.month => 'progress.range.month',
      ChartRange.threeMonths => 'progress.range.three_months',
      ChartRange.year => 'progress.range.year',
      ChartRange.all => 'progress.range.all',
    };

/// "▼ 2 kg · 3 ay"; [change] null → null (satır çizilmez).
String? rangeChangeLabel(double? change, String unit, ChartRange range) {
  if (change == null) return null;
  return 'progress.change_in_range'.tr(namedArgs: {
    'delta': '${formatDelta(change)} $unit',
    'range': rangeLabelKey(range).tr(),
  });
}

/// İlerleme ekranlarının üstündeki büyük sayı: etiket, değer + birim, değişim.
class ProgressHero extends StatelessWidget {
  const ProgressHero({
    super.key,
    required this.label,
    required this.value,
    required this.unit,
    this.change,
    this.highlight = false,
    this.valueKey,
    this.changeKey,
  });

  final String label;
  final String value;
  final String unit;

  /// Hazır değişim metni; null ise satır çizilmez.
  final String? change;

  /// Değişim olumlu mu (vurgu rengi)?
  final bool highlight;
  final Key? valueKey;
  final Key? changeKey;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final change = this.change;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          upperCaseFor(label, Localizations.localeOf(context).languageCode),
          style: theme.textTheme.labelMedium?.copyWith(color: scheme.onSurfaceVariant, letterSpacing: 1),
        ),
        const SizedBox(height: 2),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(value, key: valueKey, style: theme.textTheme.displaySmall),
            const SizedBox(width: 6),
            Text(unit, style: theme.textTheme.titleMedium?.copyWith(color: scheme.onSurfaceVariant)),
          ],
        ),
        if (change != null) ...[
          const SizedBox(height: 4),
          Text(
            change,
            key: changeKey,
            style: theme.textTheme.bodySmall?.copyWith(
              color: highlight ? scheme.primary : scheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );
  }
}
