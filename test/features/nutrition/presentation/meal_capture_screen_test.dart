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

    expect(find.byKey(const Key('food_item_name_field_0')), findsOneWidget);
    final saveButton = find.byKey(const Key('capture_save_button'));
    expect(tester.widget<ElevatedButton>(saveButton).onPressed, isNotNull);
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
}
