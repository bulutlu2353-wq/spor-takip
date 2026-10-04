import 'dart:convert';
import 'dart:typed_data';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spor_takip/features/nutrition/application/meal_providers.dart';
import 'package:spor_takip/features/nutrition/data/meal_repository.dart';
import 'package:spor_takip/features/nutrition/domain/food_item.dart';
import 'package:spor_takip/features/nutrition/presentation/meal_capture_screen.dart';
import 'package:spor_takip/features/onboarding/application/auth_providers.dart';

import '../application/fake_meal_repository.dart';

class _StubAuthRepository implements AuthRepository {
  @override
  String get currentUserId => 'user-1';

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} stub edilmedi');
}

/// 1×1 saydam PNG — önizlemenin gerçek bir görüntüyle çizildiğini doğrular.
final _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
);

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  Widget wrap(Widget child, {required FakeMealRepository repo}) {
    return EasyLocalization(
      supportedLocales: const [Locale('tr'), Locale('en')],
      path: 'assets/translations',
      fallbackLocale: const Locale('tr'),
      child: ProviderScope(
        overrides: [
          mealRepositoryProvider.overrideWithValue(repo),
          authRepositoryProvider.overrideWithValue(_StubAuthRepository()),
        ],
        child: MaterialApp(home: child),
      ),
    );
  }

  testWidgets('selecting meal type then picking a photo shows detected items', (tester) async {
    final repo = FakeMealRepository()
      ..analyzeResult = const MealAnalysisResult(
        items: [FoodItem(name: 'Tavuk', grams: 150, calories: 250)],
        failureReason: AiFailureReason.none,
      );

    await tester.pumpWidget(wrap(
      MealCaptureScreen(pickImageOverride: (_) async => Uint8List(0)),
      repo: repo,
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('meal_type_lunch_chip')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('capture_take_photo_button')));
    await tester.pumpAndSettle();

    // İncelenmiş yemek kapalı satır olarak gelir; alanlar dokununca açılır.
    expect(find.byKey(const Key('food_item_name_field_0')), findsNothing);
    await tester.tap(find.byKey(const Key('food_item_row_0')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('food_item_name_field_0')), findsOneWidget);
    final saveButton = find.byKey(const Key('capture_save_button'));
    expect(tester.widget<FilledButton>(saveButton).onPressed, isNotNull);
  });

  testWidgets('AI unavailable shows a banner and an empty, manually-addable list', (tester) async {
    final repo = FakeMealRepository()
      ..analyzeResult = const MealAnalysisResult(items: [], failureReason: AiFailureReason.unavailable);

    await tester.pumpWidget(wrap(
      MealCaptureScreen(pickImageOverride: (_) async => Uint8List(0)),
      repo: repo,
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('meal_type_snack_chip')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('capture_take_photo_button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('capture_ai_failure_banner')), findsOneWidget);

    await tester.tap(find.byKey(const Key('capture_add_item_button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('food_item_name_field_0')), findsOneWidget);
  });

  testWidgets('upload failure shows an error with a retry button', (tester) async {
    final repo = FakeMealRepository()..uploadError = Exception('network down');

    await tester.pumpWidget(wrap(
      MealCaptureScreen(pickImageOverride: (_) async => Uint8List(0)),
      repo: repo,
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('meal_type_breakfast_chip')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('capture_take_photo_button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('capture_upload_error')), findsOneWidget);
    expect(find.byKey(const Key('capture_retry_button')), findsOneWidget);
  });

  Future<void> reviewWith(WidgetTester tester, List<FoodItem> items, {Uint8List? photo}) async {
    final repo = FakeMealRepository()
      ..analyzeResult = MealAnalysisResult(items: items, failureReason: AiFailureReason.none);
    await tester.pumpWidget(wrap(
      MealCaptureScreen(pickImageOverride: (_) async => photo ?? Uint8List(0)),
      repo: repo,
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('meal_type_lunch_chip')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('capture_take_photo_button')));
    await tester.pumpAndSettle();
  }

  testWidgets('review shows the photo preview and the meal type in the app bar', (tester) async {
    await reviewWith(tester, const [FoodItem(name: 'Tavuk', grams: 200, calories: 330)], photo: _png);

    expect(find.byKey(const Key('capture_photo_preview')), findsOneWidget);
    expect(
      find.descendant(of: find.byType(AppBar), matching: find.text('nutrition.meal_type_lunch'.tr())),
      findsOneWidget,
    );
  });

  testWidgets('changing grams updates the live total', (tester) async {
    await reviewWith(tester, const [FoodItem(name: 'Tavuk', grams: 200, calories: 330)]);

    Text total() => tester.widget<Text>(find.byKey(const Key('capture_total_calories')));
    expect(total().data, startsWith('330'));

    await tester.tap(find.byKey(const Key('food_item_row_0')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('food_item_grams_field_0')), '300');
    await tester.pumpAndSettle();

    expect(total().data, startsWith('495'));
  });

  testWidgets('typing a macro for an item that needs review keeps its fields open', (tester) async {
    await reviewWith(tester, const [FoodItem(name: 'Sos', grams: 30, needsReview: true)]);

    await tester.enterText(find.byKey(const Key('food_item_calories_field_0')), '1');
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('food_item_protein_field_0')), findsOneWidget);
    expect(tester.widget<FilledButton>(find.byKey(const Key('capture_save_button'))).onPressed, isNotNull);
  });
}
