import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../domain/trend.dart';

class RangeSelector extends StatelessWidget {
  const RangeSelector({super.key, required this.value, required this.onChanged});

  final ChartRange value;
  final ValueChanged<ChartRange> onChanged;

  static String _labelKey(ChartRange range) => switch (range) {
        ChartRange.month => 'progress.range.month',
        ChartRange.threeMonths => 'progress.range.three_months',
        ChartRange.year => 'progress.range.year',
        ChartRange.all => 'progress.range.all',
      };

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<ChartRange>(
      showSelectedIcon: false,
      segments: [
        for (final range in ChartRange.values)
          ButtonSegment(value: range, label: Text(_labelKey(range).tr(), key: Key('range_${range.name}'))),
      ],
      selected: {value},
      onSelectionChanged: (selection) => onChanged(selection.single),
    );
  }
}
