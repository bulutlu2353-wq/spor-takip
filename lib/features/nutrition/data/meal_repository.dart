import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/food_item.dart';
import '../domain/meal.dart';
import '../domain/meal_type.dart';

enum AiFailureReason { none, unavailable, quotaExceeded }

class MealAnalysisResult {
  const MealAnalysisResult({required this.items, required this.failureReason});

  final List<FoodItem> items;
  final AiFailureReason failureReason;
}

abstract interface class MealRepository {
  Future<String> uploadPhoto({
    required String userId,
    required String mealId,
    required Uint8List bytes,
  });

  Future<MealAnalysisResult> analyzeMealPhoto({required String photoPath});

  Future<void> saveMeal({
    required String mealId,
    required String userId,
    required MealType mealType,
    required String? photoPath,
    required DateTime loggedAt,
    required List<FoodItem> items,
  });

  Future<List<Meal>> fetchMealsForDate({required String userId, required DateTime date});
}

class SupabaseMealRepository implements MealRepository {
  SupabaseMealRepository(this._client);

  final SupabaseClient _client;

  static const _photosBucket = 'meal-photos';
  static const _mealsTable = 'meals';
  static const _mealItemsTable = 'meal_items';

  @override
  Future<String> uploadPhoto({
    required String userId,
    required String mealId,
    required Uint8List bytes,
  }) async {
    final path = '$userId/$mealId.jpg';
    await _client.storage
        .from(_photosBucket)
        .uploadBinary(path, bytes, fileOptions: const FileOptions(upsert: true));
    return path;
  }

  @override
  Future<MealAnalysisResult> analyzeMealPhoto({required String photoPath}) async {
    try {
      final response = await _client.functions.invoke(
        'analyze-meal-photo',
        body: {'photo_path': photoPath},
      );
      final data = response.data as Map<String, dynamic>;
      final items = (data['items'] as List)
          .map((e) => FoodItem.fromJson(e as Map<String, dynamic>))
          .toList();
      return MealAnalysisResult(items: items, failureReason: AiFailureReason.none);
    } on FunctionException catch (error) {
      final details = error.details;
      final code = details is Map ? details['code'] as String? : null;
      if (code == 'GEMINI_QUOTA_EXCEEDED') {
        return const MealAnalysisResult(items: [], failureReason: AiFailureReason.quotaExceeded);
      }
      return const MealAnalysisResult(items: [], failureReason: AiFailureReason.unavailable);
    } catch (_) {
      return const MealAnalysisResult(items: [], failureReason: AiFailureReason.unavailable);
    }
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
    await _client.from(_mealsTable).upsert({
      'id': mealId,
      'user_id': userId,
      'meal_type': mealTypeToDb(mealType),
      'photo_path': photoPath,
      'logged_at': loggedAt.toUtc().toIso8601String(),
    });
    await _client.from(_mealItemsTable).insert(
          items.map((item) => {...item.toJson(), 'meal_id': mealId}).toList(),
        );
  }

  @override
  Future<List<Meal>> fetchMealsForDate({required String userId, required DateTime date}) async {
    final start = DateTime(date.year, date.month, date.day);
    final end = start.add(const Duration(days: 1));
    final rows = await _client
        .from(_mealsTable)
        .select('*, meal_items(*)')
        .eq('user_id', userId)
        .gte('logged_at', start.toUtc().toIso8601String())
        .lt('logged_at', end.toUtc().toIso8601String())
        .order('logged_at');
    return (rows as List).map((row) => Meal.fromJson(row as Map<String, dynamic>)).toList();
  }
}
