import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spor_takip/core/theme/app_colors.dart';
import 'package:spor_takip/features/progress/domain/trend.dart';
import 'package:spor_takip/features/progress/presentation/widgets/progress_line_chart.dart';

import '../../../shared/widgets/themed.dart';

void main() {
  testWidgets('chart colors come from the dark theme', (tester) async {
    await tester.pumpWidget(themed(ProgressLineChart(points: [
      ValuePoint(DateTime(2026, 9, 1), 80),
      ValuePoint(DateTime(2026, 9, 20), 79),
    ])));
    await tester.pumpAndSettle();

    final data = tester.widget<LineChart>(find.byType(LineChart)).data;
    final bar = data.lineBarsData.single;
    expect(bar.color, AppColors.accent);
    expect(data.gridData.getDrawingHorizontalLine(0).color, AppColors.line);
    final tooltipColor = data.lineTouchData.touchTooltipData.getTooltipColor(LineBarSpot(bar, 0, bar.spots.first));
    expect(tooltipColor, AppColors.surfaceHigh);
  });
}
