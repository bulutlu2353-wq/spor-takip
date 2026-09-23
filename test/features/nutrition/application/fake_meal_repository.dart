import 'dart:typed_data';

import 'package:spor_takip/features/nutrition/data/meal_repository.dart';
import 'package:spor_takip/features/nutrition/domain/food_item.dart';
import 'package:spor_takip/features/nutrition/domain/meal.dart';
import 'package:spor_takip/features/nutrition/domain/meal_type.dart';

class FakeMealRepository implements MealRepository {
  String uploadedPath = 'user-1/meal-1.jpg';
  Object? uploadError;
  MealAnalysisResult analyzeResult =
      const MealAnalysisResult(items: [], failureReason: AiFailureReason.none);
  Object? saveError;
  final List<Map<String, dynamic>> savedCalls = [];

  @override
  Future<String> uploadPhoto({
    required String userId,
    required String mealId,
    required Uint8List bytes,
  }) async {
    if (uploadError != null) throw uploadError!;
    return uploadedPath;
  }

  @override
  Future<MealAnalysisResult> analyzeMealPhoto({required String photoPath}) async {
    return analyzeResult;
  }

  @override
  Future<void> saveMeal({
    required String mealId,
    required String userId,
    required MealType mealType,
    required String? photoPath,
    required DateTime loggedAt,
    required List<FoodItem> items,
  }) async {
    if (saveError != null) throw saveError!;
    savedCalls.add({
      'mealId': mealId,
      'userId': userId,
      'mealType': mealType,
      'photoPath': photoPath,
      'items': items,
    });
  }

  @override
  Future<List<Meal>> fetchMealsForDate({required String userId, required DateTime date}) async {
    return const [];
  }
}
