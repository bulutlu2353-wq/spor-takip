import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spor_takip/features/nutrition/application/today_meals_provider.dart';
import 'package:spor_takip/features/nutrition/domain/meal.dart';
import 'package:spor_takip/features/nutrition/presentation/widgets/today_nutrition_card.dart';

import '../../progress/fixtures.dart';
import '../../progress/presentation/test_app.dart';

void main() {
  setUpAll(initTestLocalization);

  Future<void> pump(WidgetTester tester, Future<List<Meal>> Function() meals) async {
    await tester.pumpWidget(testApp(
      const TodayNutritionCard(profile: testProfile),
      overrides: [todayMealsProvider.overrideWith((ref) => meals())],
      stubRoutes: {'/nutrition': 'NUTRITION'},
    ));
    await tester.pumpAndSettle();
  }

  String macroValue(WidgetTester tester, String key) => tester
      .widget<Text>(find.descendant(of: find.byKey(Key(key)), matching: find.byKey(const ValueKey('macro_bar_value'))))
      .data!;

  testWidgets('shows today\'s calories and protein against the targets', (tester) async {
    await pump(tester, () async => [
          testMeal(DateTime(2026, 10, 3, 8), calories: 400, proteinG: 20),
          testMeal(DateTime(2026, 10, 3, 13), calories: 600, proteinG: 40),
        ]);

    expect(tester.widget<Text>(find.byKey(const Key('today_nutrition_calories'))).data, '1000');
    expect(macroValue(tester, 'today_nutrition_protein'), '60 / 176 g');
    expect(macroValue(tester, 'today_nutrition_carbs'), '0 g');
    expect(macroValue(tester, 'today_nutrition_fat'), '0 g');
  });

  testWidgets('with no meals the ring is at zero', (tester) async {
    await pump(tester, () async => const []);

    expect(tester.widget<Text>(find.byKey(const Key('today_nutrition_calories'))).data, '0');
  });

  testWidgets('tapping opens the nutrition tab', (tester) async {
    await pump(tester, () async => const []);

    await tester.tap(find.byKey(const Key('today_nutrition_card')));
    await tester.pumpAndSettle();
    expect(find.text('NUTRITION'), findsOneWidget);
  });

  testWidgets('a load error offers a retry', (tester) async {
    await pump(tester, () async => throw Exception('offline'));

    expect(find.byKey(const Key('card_retry')), findsOneWidget);
  });
}
