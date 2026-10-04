import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spor_takip/features/nutrition/domain/food_item.dart';
import 'package:spor_takip/features/nutrition/presentation/widgets/food_item_edit_tile.dart';

import '../../../progress/presentation/test_app.dart';

void main() {
  setUpAll(initTestLocalization);

  Future<void> pump(
    WidgetTester tester,
    FoodItem item, {
    int index = 0,
    ValueChanged<FoodItem>? onChanged,
    ValueChanged<double>? onGramsChanged,
    VoidCallback? onRemove,
  }) async {
    await tester.pumpWidget(testApp(FoodItemEditTile(
      item: item,
      index: index,
      onChanged: onChanged ?? (_) {},
      onGramsChanged: onGramsChanged ?? (_) {},
      onRemove: onRemove ?? () {},
    )));
    await tester.pumpAndSettle();
  }

  /// Ebeveyn gibi davranan sarmalayıcı: tile'ın bildirdiği değişikliği
  /// [item]'a yazar ve yeniden çizer (notifier akışının taklidi).
  Future<ValueNotifier<FoodItem>> pumpLive(WidgetTester tester, FoodItem initial) async {
    final item = ValueNotifier(initial);
    await tester.pumpWidget(testApp(ValueListenableBuilder<FoodItem>(
      valueListenable: item,
      builder: (context, value, _) => FoodItemEditTile(
        item: value,
        index: 0,
        onChanged: (updated) => item.value = updated,
        onGramsChanged: (grams) => item.value = value.copyWith(grams: grams),
        onRemove: () {},
      ),
    )));
    await tester.pumpAndSettle();
    return item;
  }

  testWidgets('a reviewed item starts collapsed with a one-line summary', (tester) async {
    await pump(tester, const FoodItem(name: 'Tavuk', grams: 200, calories: 330, proteinG: 62));

    expect(find.text('Tavuk'), findsOneWidget);
    expect(tester.widget<Text>(find.byKey(const Key('food_item_kcal_0'))).data, '330');
    expect(find.byKey(const Key('food_item_name_field_0')), findsNothing);
  });

  testWidgets('tapping the row expands and collapses the fields', (tester) async {
    await pump(tester, const FoodItem(name: 'Tavuk', grams: 200, calories: 330));

    await tester.tap(find.byKey(const Key('food_item_row_0')));
    await tester.pumpAndSettle();
    for (final field in ['name', 'grams', 'calories', 'protein', 'carbs', 'fat']) {
      expect(find.byKey(Key('food_item_${field}_field_0')), findsOneWidget, reason: field);
    }

    await tester.tap(find.byKey(const Key('food_item_row_0')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('food_item_name_field_0')), findsNothing);
  });

  testWidgets('an item that needs review starts expanded with a badge and no calories', (tester) async {
    await pump(tester, const FoodItem(name: 'Sos', grams: 30, needsReview: true));

    expect(find.byKey(const Key('food_item_needs_review_badge_0')), findsOneWidget);
    expect(find.byKey(const Key('food_item_calories_field_0')), findsOneWidget);
    expect(tester.widget<Text>(find.byKey(const Key('food_item_kcal_0'))).data, '—');
  });

  testWidgets('zero grams shows the grams hint', (tester) async {
    await pump(tester, const FoodItem(name: '', grams: 0, needsReview: true));

    expect(find.byKey(const Key('food_item_grams_hint_0')), findsOneWidget);
  });

  // Gram düzenlemesi tek başına "incelendi" sinyali değildir; ölçekleme
  // notifier'da yapılır, tile yalnız yeni gramı bildirir.
  testWidgets('editing grams reports the new grams through onGramsChanged only', (tester) async {
    double? grams;
    FoodItem? changed;
    await pump(
      tester,
      const FoodItem(name: 'Sos', grams: 0, needsReview: true),
      onGramsChanged: (value) => grams = value,
      onChanged: (value) => changed = value,
    );

    await tester.enterText(find.byKey(const Key('food_item_grams_field_0')), '30');
    await tester.pump();

    expect(grams, 30);
    expect(changed, isNull);
  });

  testWidgets('typing a macro clears needsReview but the fields stay visible', (tester) async {
    final item = await pumpLive(tester, const FoodItem(name: 'Sos', grams: 30, needsReview: true));

    await tester.enterText(find.byKey(const Key('food_item_calories_field_0')), '1');
    await tester.pumpAndSettle();

    expect(item.value.needsReview, isFalse);
    expect(item.value.calories, 1);
    expect(find.byKey(const Key('food_item_calories_field_0')), findsOneWidget);
    expect(find.byKey(const Key('food_item_protein_field_0')), findsOneWidget);
    expect(find.byKey(const Key('food_item_needs_review_badge_0')), findsNothing);
  });

  testWidgets('values changed from outside appear in fields that are not focused', (tester) async {
    final item = await pumpLive(tester, const FoodItem(name: 'Tavuk', grams: 200, calories: 330));
    await tester.tap(find.byKey(const Key('food_item_row_0')));
    await tester.pumpAndSettle();

    item.value = item.value.copyWith(grams: 300, calories: 495);
    await tester.pumpAndSettle();

    String fieldText(String field) =>
        tester.widget<TextField>(find.byKey(Key('food_item_${field}_field_0'))).controller!.text;
    expect(fieldText('grams'), '300');
    expect(fieldText('calories'), '495');
  });

  testWidgets('tapping remove calls onRemove', (tester) async {
    var removed = false;
    await pump(tester, const FoodItem(name: 'Tavuk', grams: 150), index: 2, onRemove: () => removed = true);

    await tester.tap(find.byKey(const Key('food_item_row_2')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('food_item_remove_button_2')));
    await tester.pump();

    expect(removed, isTrue);
  });
}
