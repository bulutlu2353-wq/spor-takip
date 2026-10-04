// `Uint8List` ve `UniqueKey` ikisi de foundation'dan geliyor; ayrıca
// `dart:typed_data` içe aktarmak gereksiz (unnecessary_import).
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../onboarding/application/auth_providers.dart';
import '../../progress/application/progress_providers.dart';
import '../domain/food_item.dart';
import '../domain/food_item_scaling.dart';
import '../domain/macro_totals.dart';
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
      itemKeys: [for (final _ in result.items) UniqueKey()],
      perGram: [for (final item in result.items) item.needsReview ? null : perGramOf(item)],
      aiFailureReason: result.failureReason,
    );
  }

  /// Ad / kcal / makro değişimi. Kcal veya makro değiştiyse gram başı oran
  /// yeni değerlerden yeniden hesaplanır (gram 0 ise oran null olur).
  void updateItem(int index, FoodItem updated) {
    final current = state;
    if (current is! MealCaptureReviewing) return;
    final old = current.items[index];
    final items = [...current.items];
    items[index] = updated;
    final perGram = _alignedPerGram(current);
    final macrosChanged = old.calories != updated.calories ||
        old.proteinG != updated.proteinG ||
        old.carbsG != updated.carbsG ||
        old.fatG != updated.fatG;
    if (macrosChanged) perGram[index] = perGramOf(updated);
    state = current.copyWith(items: items, perGram: perGram);
  }

  /// Gram değişimi: oran varsa kcal/makrolar orantılı güncellenir; oran
  /// değişmez, böylece alan geçici olarak boşalsa da kaybolmaz.
  void updateItemGrams(int index, double grams) {
    final current = state;
    if (current is! MealCaptureReviewing) return;
    final perGram = _alignedPerGram(current);
    final items = [...current.items];
    items[index] = withGrams(items[index], grams, perGram[index]);
    state = current.copyWith(items: items, perGram: perGram);
  }

  void removeItem(int index) {
    final current = state;
    if (current is! MealCaptureReviewing) return;
    final items = [...current.items]..removeAt(index);
    final itemKeys = [...current.itemKeys]..removeAt(index);
    final perGram = _alignedPerGram(current)..removeAt(index);
    state = current.copyWith(items: items, itemKeys: itemKeys, perGram: perGram);
  }

  void addManualItem() {
    final current = state;
    if (current is! MealCaptureReviewing) return;
    state = current.copyWith(
      items: [...current.items, const FoodItem(name: '', grams: 0, needsReview: true)],
      itemKeys: [...current.itemKeys, UniqueKey()],
      perGram: [..._alignedPerGram(current), null],
    );
  }

  /// `perGram`'ı `items` uzunluğuna getirir (elle kurulmuş durumlarda liste
  /// boş olabilir); eksik oranlar null.
  List<MacroTotals?> _alignedPerGram(MealCaptureReviewing current) => [
        for (var i = 0; i < current.items.length; i++)
          i < current.perGram.length ? current.perGram[i] : null,
      ];

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
      ref.invalidate(weeklyMealsProvider); // F4b haftalık özet
    } catch (_) {
      state = current;
    }
  }

  void reset() => state = const MealCaptureIdle();
}
