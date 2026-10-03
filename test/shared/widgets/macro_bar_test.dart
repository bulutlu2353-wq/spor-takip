import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spor_takip/core/theme/app_colors.dart';
import 'package:spor_takip/shared/widgets/macro_bar.dart';

import 'themed.dart';

void main() {
  String valueText(WidgetTester tester) =>
      tester.widget<Text>(find.byKey(const ValueKey('macro_bar_value'))).data!;
  LinearProgressIndicator bar(WidgetTester tester) =>
      tester.widget<LinearProgressIndicator>(find.byKey(const ValueKey('macro_bar_progress')));

  testWidgets('with a target shows eaten / target and a bar', (tester) async {
    await tester.pumpWidget(themed(const MacroBar(label: 'Protein', value: 29.6, target: 176)));

    expect(find.text('Protein'), findsOneWidget);
    expect(valueText(tester), '30 / 176 g');
    expect(bar(tester).value, closeTo(29.6 / 176, 1e-9));
    expect(bar(tester).color, AppColors.accent);
  });

  testWidgets('without a target shows only the eaten amount', (tester) async {
    await tester.pumpWidget(themed(const MacroBar(label: 'Yağ', value: 42)));

    expect(valueText(tester), '42 g');
    expect(find.byKey(const ValueKey('macro_bar_progress')), findsNothing);
  });

  testWidgets('over the target the bar is full and red', (tester) async {
    await tester.pumpWidget(themed(const MacroBar(label: 'Protein', value: 200, target: 176)));

    expect(bar(tester).value, 1);
    expect(bar(tester).color, AppColors.error);
  });
}
