import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../shared/text_case.dart';
import '../../../../shared/widgets/accent_chip.dart';
import '../../domain/trend.dart';

/// "TREND" başlığı, sağda aralık çipleri, altında grafik.
class ChartCard extends StatelessWidget {
  const ChartCard({super.key, required this.range, required this.onRangeChanged, required this.chart});

  final ChartRange range;
  final ValueChanged<ChartRange> onRangeChanged;
  final Widget chart;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text(
                  upperCaseFor('progress.trend'.tr(), Localizations.localeOf(context).languageCode),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(width: 8),
                // Dar ekranda çipler ikinci satıra kayar.
                Flexible(
                  child: Wrap(
                    alignment: WrapAlignment.end,
                    spacing: 4,
                    runSpacing: 4,
                    children: [
                      for (final r in ChartRange.values)
                        AccentChip(
                          key: Key('range_${r.name}'),
                          label: 'progress.range_short.${r.name}'.tr(),
                          selected: r == range,
                          onSelected: (_) => onRangeChanged(r),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            chart,
          ],
        ),
      ),
    );
  }
}
