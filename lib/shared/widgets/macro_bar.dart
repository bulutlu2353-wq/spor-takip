import 'package:flutter/material.dart';

import 'ring_progress.dart';

/// Makro satırı (spec §4.2): "yenen / hedef birim" ve ince çubuk; hedef
/// yoksa yalnız "yenen birim".
class MacroBar extends StatelessWidget {
  const MacroBar({super.key, required this.label, required this.value, this.target, this.unit = 'g'});

  final String label;
  final double value;
  final double? target;
  final String unit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final target = this.target;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(label, style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
            ),
            Text(
              target == null ? '${value.round()} $unit' : '${value.round()} / ${target.round()} $unit',
              key: const ValueKey('macro_bar_value'),
              style: theme.textTheme.labelLarge,
            ),
          ],
        ),
        if (target != null) ...[
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              key: const ValueKey('macro_bar_progress'),
              value: RingProgress.fraction(value, target),
              minHeight: 5,
              color: RingProgress.isOver(value, target) ? scheme.error : scheme.primary,
              backgroundColor: scheme.outlineVariant,
            ),
          ),
        ],
      ],
    );
  }
}
