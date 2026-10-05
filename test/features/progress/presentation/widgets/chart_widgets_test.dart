import 'package:easy_localization/easy_localization.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spor_takip/features/progress/domain/trend.dart';
import 'package:spor_takip/features/progress/presentation/widgets/card_states.dart';
import 'package:spor_takip/features/progress/presentation/widgets/chart_card.dart';
import 'package:spor_takip/features/progress/presentation/widgets/progress_line_chart.dart';

Widget _wrap(Widget child) => EasyLocalization(
      supportedLocales: const [Locale('tr'), Locale('en')],
      path: 'assets/translations',
      fallbackLocale: const Locale('tr'),
      child: MaterialApp(home: Scaffold(body: child)),
    );

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  testWidgets('draws a line chart for points, nothing for an empty list', (tester) async {
    await tester.pumpWidget(_wrap(Column(children: [
      ProgressLineChart(
        key: const Key('full'),
        points: [ValuePoint(DateTime(2026, 9, 1), 80), ValuePoint(DateTime(2026, 9, 20), 79)],
      ),
      ProgressLineChart(key: const Key('single'), compact: true, height: 60, points: [ValuePoint(DateTime(2026, 9, 1), 80)]),
      const ProgressLineChart(key: Key('empty'), points: []),
    ])));
    await tester.pumpAndSettle();

    expect(find.descendant(of: find.byKey(const Key('full')), matching: find.byType(LineChart)), findsOneWidget);
    expect(find.descendant(of: find.byKey(const Key('single')), matching: find.byType(LineChart)), findsOneWidget);
    expect(find.descendant(of: find.byKey(const Key('empty')), matching: find.byType(LineChart)), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('chart card shows the chart and reports the tapped range', (tester) async {
    ChartRange? picked;
    await tester.pumpWidget(_wrap(ChartCard(
      range: ChartRange.threeMonths,
      onRangeChanged: (r) => picked = r,
      chart: const SizedBox(key: Key('chart'), height: 50),
    )));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('chart')), findsOneWidget);
    expect(find.byKey(const Key('range_all')), findsOneWidget);
    await tester.tap(find.byKey(const Key('range_year')));
    await tester.pumpAndSettle();
    expect(picked, ChartRange.year);
  });

  testWidgets('card error calls retry', (tester) async {
    var retried = false;
    await tester.pumpWidget(_wrap(CardError(onRetry: () => retried = true)));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('card_retry')));
    expect(retried, isTrue);
  });
}
