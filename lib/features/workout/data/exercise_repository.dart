import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/exercise.dart';

/// Kendi hareketi bir programda kullanılırken silinmeye çalışıldı (FK restrict).
class ExerciseInUseException implements Exception {}

abstract interface class ExerciseRepository {
  Future<List<Exercise>> fetchExercises();

  Future<Exercise> createCustomExercise({
    required String name,
    String? primaryMuscle,
    String? equipment,
  });

  Future<void> deleteCustomExercise(String id);
}

class SupabaseExerciseRepository implements ExerciseRepository {
  SupabaseExerciseRepository(this._client);

  final SupabaseClient _client;

  static const _table = 'exercises';
  static const _pageSize = 1000;
  static const _foreignKeyViolation = '23503';

  @override
  Future<List<Exercise>> fetchExercises() async {
    final all = <Exercise>[];
    for (var from = 0;; from += _pageSize) {
      final rows = await _client
          .from(_table)
          .select()
          .order('name')
          .range(from, from + _pageSize - 1);
      all.addAll((rows as List).map((r) => Exercise.fromJson(r as Map<String, dynamic>)));
      if (rows.length < _pageSize) return all;
    }
  }

  @override
  Future<Exercise> createCustomExercise({
    required String name,
    String? primaryMuscle,
    String? equipment,
  }) async {
    final row = await _client
        .from(_table)
        .insert({
          'user_id': _client.auth.currentUser!.id,
          'name': name,
          'category': 'strength',
          'equipment': equipment,
          'primary_muscles': [?primaryMuscle],
        })
        .select()
        .single();
    return Exercise.fromJson(row);
  }

  @override
  Future<void> deleteCustomExercise(String id) async {
    try {
      await _client.from(_table).delete().eq('id', id);
    } on PostgrestException catch (error) {
      if (error.code == _foreignKeyViolation) throw ExerciseInUseException();
      rethrow;
    }
  }
}
