import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../onboarding/application/auth_providers.dart';
import '../domain/food_item.dart';
import '../domain/meal_type.dart';
import 'meal_capture_state.dart';
import 'today_meals_provider.dart';
import 'meal_providers.dart';

final mealCaptureProvider = NotifierProvider<MealCaptureNotifier, MealCaptureState>(
  MealCaptureNotifier.new,
);

class MealCaptureNotifier extends Notifier<MealCaptureState> {
  MealCaptureNotifier({Uuid? uuid}) : _uuid = uuid ?? const Uuid();

  final Uuid _uuid;

  @override
  MealCaptureState build() => const MealCaptureIdle();

  Future<void> startCapture({
    required MealType mealType,
    required Uint8List photoBytes,
  }) async {
    final repo = ref.read(mealRepositoryProvider);
    final userId = ref.read(authRepositoryProvider).currentUserId;
    final mealId = _uuid.v4();

    state = const MealCaptureUploading();
    final String photoPath;
    try {
      photoPath = await repo.uploadPhoto(userId: userId, mealId: mealId, bytes: photoBytes);
    } catch (_) {
      state = MealCaptureUploadError(mealType: mealType);
      return;
    }

    state = const MealCaptureAnalyzing();
    final result = await repo.analyzeMealPhoto(photoPath: photoPath);
    state = MealCaptureReviewing(
      mealType: mealType,
      mealId: mealId,
      photoPath: photoPath,
      items: result.items,
      aiFailureReason: result.failureReason,
    );
  }

  void updateItem(int index, FoodItem updated) {
    final current = state;
    if (current is! MealCaptureReviewing) return;
    final items = [...current.items];
    items[index] = updated;
    state = current.copyWith(items: items);
  }

  void removeItem(int index) {
    final current = state;
    if (current is! MealCaptureReviewing) return;
    final items = [...current.items]..removeAt(index);
    state = current.copyWith(items: items);
  }

  void addManualItem() {
    final current = state;
    if (current is! MealCaptureReviewing) return;
    state = current.copyWith(items: [
      ...current.items,
      const FoodItem(name: '', grams: 0, needsReview: true),
    ]);
  }

  Future<void> confirmSave() async {
    final current = state;
    if (current is! MealCaptureReviewing || !current.canSave) return;

    final repo = ref.read(mealRepositoryProvider);
    final userId = ref.read(authRepositoryProvider).currentUserId;
    state = const MealCaptureSaving();
    try {
      await repo.saveMeal(
        mealId: current.mealId,
        userId: userId,
        mealType: current.mealType,
        photoPath: current.photoPath,
        loggedAt: DateTime.now(),
        items: current.items,
      );
      state = const MealCaptureSaved();
      ref.invalidate(todayMealsProvider);
    } catch (_) {
      state = current;
    }
  }

  void reset() => state = const MealCaptureIdle();
}
