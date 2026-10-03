import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/chart_style.dart';
import '../../domain/progress_format.dart';
import '../../domain/trend.dart';

/// Tarih eksenli tek çizgi grafik (kilo, tahmini 1RM, ölçü).
class ProgressLineChart extends StatelessWidget {
  const ProgressLineChart({
    super.key,
    required this.points,
    this.height = 200,
    this.compact = false,
    this.tooltipLabel,
  });

  /// Eskiden yeniye.
  final List<ValuePoint> points;
  final double height;

  /// Kartlardaki küçük grafik: eksen, ızgara ve dokunma yok.
  final bool compact;

  /// `points[index]` için ipucu metni; verilmezse "tarih\ndeğer".
  final String Function(int index)? tooltipLabel;

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) return SizedBox(height: height);
    final theme = Theme.of(context);
    final color = theme.colorScheme.primary;
    final labelStyle = theme.textTheme.labelSmall;

    // x = ilk noktadan beri geçen gün (saatli noktalar için kesirli).
    final origin = points.first.date;
    double dayOf(DateTime d) => d.difference(origin).inMinutes / (60 * 24);
    final spots = [for (final p in points) FlSpot(dayOf(p.date), p.value)];

    final values = points.map((p) => p.value);
    final minValue = values.reduce(math.min);
    final maxValue = values.reduce(math.max);
    final pad = math.max((maxValue - minValue) * 0.1, 1.0);
    final minX = spots.first.x;
    final maxX = spots.last.x == minX ? minX + 1 : spots.last.x;

    String label(int index) =>
        tooltipLabel?.call(index) ??
        '${formatShortDate(points[index].date)}\n${formatOneDecimal(points[index].value)}';

    return SizedBox(
      height: height,
      child: LineChart(
        LineChartData(
          minX: minX,
          maxX: maxX,
          minY: minValue - pad,
          maxY: maxValue + pad,
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              color: color,
              barWidth: compact ? 2 : 3,
              dotData: FlDotData(show: !compact && points.length <= 60),
            ),
          ],
          gridData: FlGridData(
            show: !compact,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) => chartGridLine(context),
          ),
          borderData: FlBorderData(show: false),
          titlesData: compact
              ? const FlTitlesData(show: false)
              : FlTitlesData(
                  topTitles: const AxisTitles(),
                  rightTitles: const AxisTitles(),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget: (value, meta) => Text(meta.formattedValue, style: labelStyle),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 24,
                      interval: math.max(1, (maxX - minX) / 4),
                      getTitlesWidget: (value, meta) {
                        final date = origin.add(Duration(minutes: (value * 60 * 24).round()));
                        return Text('${date.day}.${date.month}', style: labelStyle);
                      },
                    ),
                  ),
                ),
          lineTouchData: compact
              ? const LineTouchData(enabled: false)
              : LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (_) => chartTooltipColor(context),
                    getTooltipItems: (touched) => [
                      for (final spot in touched)
                        LineTooltipItem(
                          label(spot.spotIndex),
                          TextStyle(color: chartTooltipTextColor(context)),
                        ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}
