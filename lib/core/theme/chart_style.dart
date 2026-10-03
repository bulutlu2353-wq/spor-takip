import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

// fl_chart renkleri temadan otomatik almaz (spec §4.1); grafikler bunları kullanır.

FlLine chartGridLine(BuildContext context) =>
    FlLine(color: Theme.of(context).colorScheme.outlineVariant, strokeWidth: 1);

Color chartTooltipColor(BuildContext context) => Theme.of(context).colorScheme.surfaceContainerHigh;

Color chartTooltipTextColor(BuildContext context) => Theme.of(context).colorScheme.onSurface;
