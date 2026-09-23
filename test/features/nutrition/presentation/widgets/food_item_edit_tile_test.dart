import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spor_takip/features/nutrition/domain/food_item.dart';
import 'package:spor_takip/features/nutrition/presentation/widgets/food_item_edit_tile.dart';

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  Widget wrap(Widget child) {
    return EasyLocalization(
      supportedLocales: const [Locale('tr'), Locale('en')],
      path: 'assets/translations',
      fallbackLocale: const Locale('tr'),
      child: MaterialApp(home: Scaffold(body: child)),
    );
  }

  testWidgets('shows name and grams fields, no macro fields when reviewed', (tester) async {
    const item = FoodItem(name: 'Tavuk', grams: 150, calories: 250, needsReview: false);
    await tester.pumpWidget(wrap(FoodItemEditTile(
      item: item,
      index: 0,
      onChanged: (_) {},
      onRemove: () {},
    )));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('food_item_name_field_0')), findsOneWidget);
    expect(find.byKey(const Key('food_item_grams_field_0')), findsOneWidget);
    expect(find.byKey(const Key('food_item_calories_field_0')), findsNothing);
  });

  testWidgets('shows macro fields and a review badge when needsReview is true', (tester) async {
    const item = FoodItem(name: '', grams: 0, needsReview: true);
    await tester.pumpWidget(wrap(FoodItemEditTile(
      item: item,
      index: 0,
      onChanged: (_) {},
      onRemove: () {},
    )));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('food_item_calories_field_0')), findsOneWidget);
    expect(find.byKey(const Key('food_item_needs_review_badge_0')), findsOneWidget);
  });

  // Gram düzenlemesi tek başına "incelendi" sinyali değildir: eksik olan veri
  // makrolardır, gram değil. Bu yüzden sadece gram değişince needsReview
  // bayrağı korunur.
  testWidgets('editing grams calls onChanged with updated value and keeps needsReview true', (tester) async {
    FoodItem? changed;
    const item = FoodItem(name: 'Sos', grams: 0, needsReview: true);
    await tester.pumpWidget(wrap(FoodItemEditTile(
      item: item,
      index: 0,
      onChanged: (updated) => changed = updated,
      onRemove: () {},
    )));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('food_item_grams_field_0')), '30');
    await tester.pump();

    expect(changed, isNotNull);
    expect(changed!.grams, 30);
    expect(changed!.needsReview, isTrue);
  });

  testWidgets('tapping remove calls onRemove', (tester) async {
    var removed = false;
    const item = FoodItem(name: 'Tavuk', grams: 150);
    await tester.pumpWidget(wrap(FoodItemEditTile(
      item: item,
      index: 2,
      onChanged: (_) {},
      onRemove: () => removed = true,
    )));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('food_item_remove_button_2')));
    await tester.pump();

    expect(removed, isTrue);
  });
}
