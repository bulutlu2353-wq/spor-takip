import 'dart:typed_data';

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
      );
      expect(state.canSave, isFalse);
    });

    test('false when any item has grams <= 0', () {
      const state = MealCaptureReviewing(
        mealType: MealType.lunch,
        mealId: 'm',
        photoPath: 'p',
        items: [FoodItem(name: 'A', grams: 0, needsReview: false)],
      );
      expect(state.canSave, isFalse);
    });

    test('true when items is non-empty, all reviewed, all grams > 0', () {
      const state = MealCaptureReviewing(
        mealType: MealType.lunch,
        mealId: 'm',
        photoPath: 'p',
        items: [FoodItem(name: 'A', grams: 100, needsReview: false)],
      );
      expect(state.canSave, isTrue);
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
