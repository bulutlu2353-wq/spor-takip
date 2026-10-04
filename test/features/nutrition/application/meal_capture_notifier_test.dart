// `Uint8List` ve `ValueKey` ikisi de foundation'dan geliyor; ayrıca
// `dart:typed_data` içe aktarmak gereksiz (unnecessary_import).
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spor_takip/features/nutrition/application/meal_capture_notifier.dart';
import 'package:spor_takip/features/nutrition/application/meal_capture_state.dart';
import 'package:spor_takip/features/nutrition/application/meal_providers.dart';
import 'package:spor_takip/features/nutrition/data/meal_repository.dart';
import 'package:spor_takip/features/nutrition/domain/food_item.dart';
import 'package:spor_takip/features/nutrition/domain/meal_type.dart';
import 'package:spor_takip/features/onboarding/application/auth_providers.dart';

import 'fake_meal_repository.dart';

// Not: AuthRepository somut bir sınıf; testte gerçek Supabase client'a
// dokunmadan currentUserId döndürmek için authRepositoryProvider yerine
// doğrudan bir stub AuthRepository alt sınıfı kullanılır.

class _StubAuthRepository implements AuthRepository {
  @override
  String get currentUserId => 'user-1';

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} stub edilmedi');
}

void main() {
  group('MealCaptureReviewing.canSave', () {
    test('false when items is empty', () {
      const state = MealCaptureReviewing(
        mealType: MealType.lunch,
        mealId: 'm',
        photoPath: 'p',
        items: [],
        itemKeys: [],
      );
      expect(state.canSave, isFalse);
    });

    test('false when any item needs review', () {
      const state = MealCaptureReviewing(
        mealType: MealType.lunch,
        mealId: 'm',
        photoPath: 'p',
        items: [
          FoodItem(name: 'A', grams: 100, needsReview: false),
          FoodItem(name: 'B', grams: 50, needsReview: true),
        ],
        itemKeys: [ValueKey('a'), ValueKey('b')],
      );
      expect(state.canSave, isFalse);
    });

    test('false when any item has grams <= 0', () {
      const state = MealCaptureReviewing(
        mealType: MealType.lunch,
        mealId: 'm',
        photoPath: 'p',
        items: [FoodItem(name: 'A', grams: 0, needsReview: false)],
        itemKeys: [ValueKey('a')],
      );
      expect(state.canSave, isFalse);
    });

    test('true when items is non-empty, all reviewed, all grams > 0', () {
      const state = MealCaptureReviewing(
        mealType: MealType.lunch,
        mealId: 'm',
        photoPath: 'p',
        items: [FoodItem(name: 'A', grams: 100, needsReview: false)],
        itemKeys: [ValueKey('a')],
      );
      expect(state.canSave, isTrue);
    });

    test('totalCalories sums item calories', () {
      const state = MealCaptureReviewing(
        mealType: MealType.lunch,
        mealId: 'm',
        photoPath: 'p',
        items: [
          FoodItem(name: 'A', grams: 100, calories: 120.5),
          FoodItem(name: 'B', grams: 50, calories: 80),
        ],
        itemKeys: [ValueKey('a'), ValueKey('b')],
      );
      expect(state.totalCalories, 200.5);
    });
  });

  _registerNotifierTests();
}

void _registerNotifierTests() {
  group('MealCaptureNotifier', () {
    late FakeMealRepository fakeRepo;
    late ProviderContainer container;

    setUp(() {
      fakeRepo = FakeMealRepository();
      container = ProviderContainer(overrides: [
        mealRepositoryProvider.overrideWithValue(fakeRepo),
        authRepositoryProvider.overrideWithValue(_StubAuthRepository()),
      ]);
    });

    tearDown(() => container.dispose());

    test('startCapture moves idle -> uploading -> analyzing -> reviewing', () async {
      fakeRepo.analyzeResult = const MealAnalysisResult(
        items: [FoodItem(name: 'Tavuk', grams: 150, calories: 250)],
        failureReason: AiFailureReason.none,
      );

      final notifier = container.read(mealCaptureProvider.notifier);
      expect(container.read(mealCaptureProvider), isA<MealCaptureIdle>());

      final future = notifier.startCapture(
        mealType: MealType.lunch,
        photoBytes: Uint8List(0),
      );
      await future;

      final state = container.read(mealCaptureProvider);
      expect(state, isA<MealCaptureReviewing>());
      expect((state as MealCaptureReviewing).items.single.name, 'Tavuk');
      expect(state.aiFailureReason, AiFailureReason.none);
    });

    test('startCapture surfaces upload failures as MealCaptureUploadError', () async {
      fakeRepo.uploadError = Exception('network down');
      final notifier = container.read(mealCaptureProvider.notifier);

      await notifier.startCapture(mealType: MealType.breakfast, photoBytes: Uint8List(0));

      final state = container.read(mealCaptureProvider);
      expect(state, isA<MealCaptureUploadError>());
      expect((state as MealCaptureUploadError).mealType, MealType.breakfast);
    });

    test('startCapture with AI failure reaches Reviewing with empty items and the reason set', () async {
      fakeRepo.analyzeResult =
          const MealAnalysisResult(items: [], failureReason: AiFailureReason.quotaExceeded);
      final notifier = container.read(mealCaptureProvider.notifier);

      await notifier.startCapture(mealType: MealType.dinner, photoBytes: Uint8List(0));

      final state = container.read(mealCaptureProvider) as MealCaptureReviewing;
      expect(state.items, isEmpty);
      expect(state.aiFailureReason, AiFailureReason.quotaExceeded);
      expect(state.canSave, isFalse);
    });

    test('updateItem replaces the item at index', () async {
      fakeRepo.analyzeResult = const MealAnalysisResult(
        items: [FoodItem(name: 'A', grams: 100), FoodItem(name: 'B', grams: 50)],
        failureReason: AiFailureReason.none,
      );
      final notifier = container.read(mealCaptureProvider.notifier);
      await notifier.startCapture(mealType: MealType.snack, photoBytes: Uint8List(0));

      notifier.updateItem(1, const FoodItem(name: 'B düzeltildi', grams: 60));

      final state = container.read(mealCaptureProvider) as MealCaptureReviewing;
      expect(state.items[1].name, 'B düzeltildi');
      expect(state.items[1].grams, 60);
      expect(state.items[0].name, 'A');
    });

    test('removeItem drops the item at index', () async {
      fakeRepo.analyzeResult = const MealAnalysisResult(
        items: [FoodItem(name: 'A', grams: 100), FoodItem(name: 'B', grams: 50)],
        failureReason: AiFailureReason.none,
      );
      final notifier = container.read(mealCaptureProvider.notifier);
      await notifier.startCapture(mealType: MealType.snack, photoBytes: Uint8List(0));

      notifier.removeItem(0);

      final state = container.read(mealCaptureProvider) as MealCaptureReviewing;
      expect(state.items, hasLength(1));
      expect(state.items.single.name, 'B');
    });

    test('addManualItem appends a needs-review placeholder item', () async {
      fakeRepo.analyzeResult = const MealAnalysisResult(items: [], failureReason: AiFailureReason.none);
      final notifier = container.read(mealCaptureProvider.notifier);
      await notifier.startCapture(mealType: MealType.snack, photoBytes: Uint8List(0));

      notifier.addManualItem();

      final state = container.read(mealCaptureProvider) as MealCaptureReviewing;
      expect(state.items, hasLength(1));
      expect(state.items.single.needsReview, isTrue);
      expect(state.items.single.grams, 0);
    });

    Future<MealCaptureNotifier> reviewWith(List<FoodItem> items) async {
      fakeRepo.analyzeResult = MealAnalysisResult(items: items, failureReason: AiFailureReason.none);
      final notifier = container.read(mealCaptureProvider.notifier);
      await notifier.startCapture(mealType: MealType.lunch, photoBytes: Uint8List(0));
      return notifier;
    }

    MealCaptureReviewing reviewing() => container.read(mealCaptureProvider) as MealCaptureReviewing;

    test('startCapture stores per-gram values for reviewed items only', () async {
      await reviewWith(const [
        FoodItem(name: 'Tavuk', grams: 200, calories: 330, proteinG: 62),
        FoodItem(name: 'Sos', grams: 0, needsReview: true),
      ]);

      final state = reviewing();
      expect(state.perGram, hasLength(2));
      expect(state.perGram[0]!.calories, closeTo(1.65, 1e-9));
      expect(state.perGram[1], isNull);
    });

    test('updateItemGrams scales calories and macros', () async {
      final notifier = await reviewWith(const [FoodItem(name: 'Tavuk', grams: 200, calories: 330, proteinG: 62)]);

      notifier.updateItemGrams(0, 300);

      final item = reviewing().items.single;
      expect(item.grams, 300);
      expect(item.calories, closeTo(495, 1e-9));
      expect(item.proteinG, closeTo(93, 1e-9));
      expect(reviewing().totalCalories, closeTo(495, 1e-9));
    });

    test('updateItemGrams keeps the ratio when grams pass through zero', () async {
      final notifier = await reviewWith(const [FoodItem(name: 'Tavuk', grams: 200, calories: 330)]);

      notifier.updateItemGrams(0, 0);
      notifier.updateItemGrams(0, 250);

      expect(reviewing().items.single.calories, closeTo(412.5, 1e-9));
    });

    test('updateItemGrams on an item without a ratio only changes grams', () async {
      final notifier = await reviewWith(const [FoodItem(name: 'Sos', grams: 0, calories: 0, needsReview: true)]);

      notifier.updateItemGrams(0, 40);

      final item = reviewing().items.single;
      expect(item.grams, 40);
      expect(item.calories, 0);
      expect(item.needsReview, isTrue);
    });

    test('updateItem with new calories refreshes the ratio', () async {
      final notifier = await reviewWith(const [FoodItem(name: 'Tavuk', grams: 200, calories: 330)]);

      notifier.updateItem(0, reviewing().items.single.copyWith(calories: 400));
      notifier.updateItemGrams(0, 100);

      expect(reviewing().items.single.calories, closeTo(200, 1e-9));
    });

    test('updateItem with only a new name keeps the ratio', () async {
      final notifier = await reviewWith(const [FoodItem(name: 'Tavuk', grams: 200, calories: 330)]);

      notifier.updateItemGrams(0, 0);
      notifier.updateItem(0, reviewing().items.single.copyWith(name: 'Izgara tavuk'));
      notifier.updateItemGrams(0, 200);

      expect(reviewing().items.single.calories, closeTo(330, 1e-9));
    });

    test('removeItem and addManualItem keep perGram aligned with items', () async {
      final notifier = await reviewWith(const [
        FoodItem(name: 'A', grams: 100, calories: 100),
        FoodItem(name: 'B', grams: 100, calories: 300),
      ]);

      notifier.removeItem(0);
      expect(reviewing().perGram, hasLength(1));
      expect(reviewing().perGram.single!.calories, closeTo(3, 1e-9));

      notifier.addManualItem();
      expect(reviewing().perGram, hasLength(2));
      expect(reviewing().perGram[1], isNull);
    });

    test('confirmSave is a no-op when canSave is false', () async {
      fakeRepo.analyzeResult = const MealAnalysisResult(items: [], failureReason: AiFailureReason.none);
      final notifier = container.read(mealCaptureProvider.notifier);
      await notifier.startCapture(mealType: MealType.snack, photoBytes: Uint8List(0));

      await notifier.confirmSave();

      expect(fakeRepo.savedCalls, isEmpty);
      expect(container.read(mealCaptureProvider), isA<MealCaptureReviewing>());
    });

    test('confirmSave saves and transitions to MealCaptureSaved when canSave is true', () async {
      fakeRepo.analyzeResult = const MealAnalysisResult(
        items: [FoodItem(name: 'Tavuk', grams: 150, calories: 250)],
        failureReason: AiFailureReason.none,
      );
      final notifier = container.read(mealCaptureProvider.notifier);
      await notifier.startCapture(mealType: MealType.lunch, photoBytes: Uint8List(0));

      await notifier.confirmSave();

      expect(fakeRepo.savedCalls, hasLength(1));
      expect(fakeRepo.savedCalls.single['userId'], 'user-1');
      expect(container.read(mealCaptureProvider), isA<MealCaptureSaved>());
    });

    test('confirmSave keeps Reviewing state on save failure', () async {
      fakeRepo.analyzeResult = const MealAnalysisResult(
        items: [FoodItem(name: 'Tavuk', grams: 150, calories: 250)],
        failureReason: AiFailureReason.none,
      );
      fakeRepo.saveError = Exception('insert failed');
      final notifier = container.read(mealCaptureProvider.notifier);
      await notifier.startCapture(mealType: MealType.lunch, photoBytes: Uint8List(0));

      await notifier.confirmSave();

      expect(container.read(mealCaptureProvider), isA<MealCaptureReviewing>());
    });

    test('reset returns to Idle', () async {
      fakeRepo.analyzeResult = const MealAnalysisResult(items: [], failureReason: AiFailureReason.none);
      final notifier = container.read(mealCaptureProvider.notifier);
      await notifier.startCapture(mealType: MealType.snack, photoBytes: Uint8List(0));

      notifier.reset();

      expect(container.read(mealCaptureProvider), isA<MealCaptureIdle>());
    });
  });
}
