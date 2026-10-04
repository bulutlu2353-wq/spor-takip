import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spor_takip/core/theme/app_theme.dart';
import 'package:spor_takip/features/nutrition/domain/macro_totals.dart';
import 'package:spor_takip/features/nutrition/presentation/widgets/remaining_calories_card.dart';

import '../../../progress/presentation/test_app.dart';

void main() {
  setUpAll(initTestLocalization);

  final scheme = AppTheme.dark().colorScheme;

  Future<void> pump(WidgetTester tester, {required double kcal, required double target, double proteinTarget = 150}) async {
    await tester.pumpWidget(testApp(RemainingCaloriesCard(
      eaten: MacroTotals(calories: kcal, proteinG: 96, carbsG: 150, fatG: 42),
      calorieTarget: target,
      proteinTarget: proteinTarget,
    )));
    await tester.pumpAndSettle();
  }

  Text value(WidgetTester tester) => tester.widget<Text>(find.byKey(const Key('remaining_calories_value')));

  String chip(WidgetTester tester, String key) => tester
      .widget<Text>(find.descendant(of: find.byKey(Key(key)), matching: find.byKey(const ValueKey('macro_chip_value'))))
      .data!;

  test('modeFor picks remaining, over or no target', () {
    expect(RemainingCaloriesCard.modeFor(1420, 2100), RemainingMode.remaining);
    expect(RemainingCaloriesCard.modeFor(2100, 2100), RemainingMode.remaining);
    expect(RemainingCaloriesCard.modeFor(2220, 2100), RemainingMode.over);
    expect(RemainingCaloriesCard.modeFor(1420, 0), RemainingMode.noTarget);
  });

  testWidgets('under the target shows remaining calories and a bar', (tester) async {
    await pump(tester, kcal: 1420, target: 2100);

    expect(value(tester).data, '680');
    expect(value(tester).style!.color, scheme.onSurface);
    expect(find.byKey(const Key('remaining_calories_bar')), findsOneWidget);
  });

  testWidgets('over the target shows the excess in the error color', (tester) async {
    await pump(tester, kcal: 2220, target: 2100);

    expect(value(tester).data, '120');
    expect(value(tester).style!.color, scheme.error);
    final bar = tester.widget<LinearProgressIndicator>(find.byKey(const Key('remaining_calories_bar')));
    expect(bar.value, 1);
    expect(bar.color, scheme.error);
  });

  testWidgets('without a target shows eaten calories and no bar', (tester) async {
    await pump(tester, kcal: 1420, target: 0);

    expect(value(tester).data, '1420');
    expect(find.byKey(const Key('remaining_calories_bar')), findsNothing);
  });

  testWidgets('macro chips show protein against its target and grams for the rest', (tester) async {
    await pump(tester, kcal: 1420, target: 2100);

    expect(chip(tester, 'remaining_macro_protein'), '96/150 g');
    expect(chip(tester, 'remaining_macro_carbs'), '150 g');
    expect(chip(tester, 'remaining_macro_fat'), '42 g');
  });

  testWidgets('protein chip without a target shows grams only', (tester) async {
    await pump(tester, kcal: 1420, target: 2100, proteinTarget: 0);

    expect(chip(tester, 'remaining_macro_protein'), '96 g');
  });
}
