import '../data/meal_repository.dart';
import '../domain/food_item.dart';
import '../domain/meal_type.dart';

sealed class MealCaptureState {
  const MealCaptureState();
}

class MealCaptureIdle extends MealCaptureState {
  const MealCaptureIdle();
}

class MealCaptureUploading extends MealCaptureState {
  const MealCaptureUploading();
}

class MealCaptureAnalyzing extends MealCaptureState {
  const MealCaptureAnalyzing();
}

class MealCaptureReviewing extends MealCaptureState {
  const MealCaptureReviewing({
    required this.mealType,
    required this.mealId,
    required this.photoPath,
    required this.items,
    this.aiFailureReason = AiFailureReason.none,
  });

  final MealType mealType;
  final String mealId;
  final String photoPath;
  final List<FoodItem> items;
  final AiFailureReason aiFailureReason;

  bool get canSave =>
      items.isNotEmpty && items.every((item) => item.grams > 0 && !item.needsReview);

  MealCaptureReviewing copyWith({List<FoodItem>? items}) {
    return MealCaptureReviewing(
      mealType: mealType,
      mealId: mealId,
      photoPath: photoPath,
      items: items ?? this.items,
      aiFailureReason: aiFailureReason,
    );
  }
}

class MealCaptureSaving extends MealCaptureState {
  const MealCaptureSaving();
}

class MealCaptureSaved extends MealCaptureState {
  const MealCaptureSaved();
}

class MealCaptureUploadError extends MealCaptureState {
  const MealCaptureUploadError({required this.mealType});

  final MealType mealType;
}
