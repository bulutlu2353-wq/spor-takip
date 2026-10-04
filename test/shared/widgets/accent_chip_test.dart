import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spor_takip/core/theme/app_colors.dart';
import 'package:spor_takip/shared/widgets/accent_chip.dart';

import 'themed.dart';

void main() {
  testWidgets('a selected chip is filled with the accent and uses dark text', (tester) async {
    await tester.pumpWidget(themed(AccentChip(label: 'Chest', selected: true, onSelected: (_) {})));

    final chip = tester.widget<ChoiceChip>(find.byType(ChoiceChip));
    expect(chip.selectedColor, AppColors.accent);
    expect(chip.showCheckmark, isFalse);
    expect(tester.widget<Text>(find.text('Chest')).style!.color, AppColors.onAccent);
  });

  testWidgets('tapping an unselected chip reports true', (tester) async {
    bool? reported;
    await tester.pumpWidget(themed(AccentChip(label: 'Back', selected: false, onSelected: (v) => reported = v)));

    expect(tester.widget<Text>(find.text('Back')).style!.color, AppColors.text);
    await tester.tap(find.byType(AccentChip));
    expect(reported, isTrue);
  });
}
