import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spor_takip/core/theme/app_colors.dart';
import 'package:spor_takip/features/progress/presentation/widgets/progress_hero.dart';

import '../../../../shared/widgets/themed.dart';

void main() {
  testWidgets('shows the upper-cased label, the value and a highlighted change', (tester) async {
    await tester.pumpWidget(themed(const ProgressHero(
      label: 'Current',
      value: '78.4',
      unit: 'kg',
      change: '▼ 1.6 kg · 3 mo',
      highlight: true,
      valueKey: Key('v'),
      changeKey: Key('c'),
    )));

    expect(find.text('CURRENT'), findsOneWidget);
    expect(tester.widget<Text>(find.byKey(const Key('v'))).data, '78.4');
    expect(find.text('kg'), findsOneWidget);
    expect(tester.widget<Text>(find.byKey(const Key('c'))).style!.color, AppColors.accent);
  });

  testWidgets('a plain change is muted and a missing change is not drawn', (tester) async {
    await tester.pumpWidget(themed(const Column(children: [
      ProgressHero(label: 'A', value: '1', unit: 'kg', change: '▲ 1 kg · 3 mo', changeKey: Key('muted')),
      ProgressHero(label: 'B', value: '2', unit: 'kg', changeKey: Key('none')),
    ])));

    expect(tester.widget<Text>(find.byKey(const Key('muted'))).style!.color, AppColors.muted);
    expect(find.byKey(const Key('none')), findsNothing);
  });
}
