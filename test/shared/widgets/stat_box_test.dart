import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spor_takip/core/theme/app_colors.dart';
import 'package:spor_takip/shared/widgets/stat_box.dart';

import 'themed.dart';

void main() {
  testWidgets('shows the value and the upper-cased label', (tester) async {
    await tester.pumpWidget(themed(const StatBox(label: 'Sets', value: '7/15', valueKey: Key('v'))));

    expect(tester.widget<Text>(find.byKey(const Key('v'))).data, '7/15');
    final label = tester.widget<Text>(find.text('SETS'));
    expect(label.style!.color, AppColors.muted);
  });

  testWidgets('a row gives every box the same width', (tester) async {
    await tester.pumpWidget(themed(const StatBoxRow(children: [
      StatBox(key: Key('a'), label: 'Duration', value: '48:20'),
      StatBox(key: Key('b'), label: 'Sets', value: '15'),
      StatBox(key: Key('c'), label: 'Volume', value: '12500 kg'),
    ])));

    final a = tester.getSize(find.byKey(const Key('a'))).width;
    expect(tester.getSize(find.byKey(const Key('b'))).width, a);
    expect(tester.getSize(find.byKey(const Key('c'))).width, a);
    expect(tester.takeException(), isNull);
  });
}
