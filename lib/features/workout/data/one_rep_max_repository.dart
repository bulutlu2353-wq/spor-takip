import 'package:supabase_flutter/supabase_flutter.dart';

abstract interface class OneRepMaxRepository {
  /// exercise_id → kg
  Future<Map<String, double>> fetchOneRepMaxes();

  Future<void> saveOneRepMax({required String exerciseId, required double weightKg});
}

class SupabaseOneRepMaxRepository implements OneRepMaxRepository {
  SupabaseOneRepMaxRepository(this._client);

  final SupabaseClient _client;

  static const _table = 'user_one_rep_maxes';

  @override
  Future<Map<String, double>> fetchOneRepMaxes() async {
    final rows = await _client.from(_table).select('exercise_id, weight_kg');
    return {
      for (final r in rows as List)
        (r as Map<String, dynamic>)['exercise_id'] as String: (r['weight_kg'] as num).toDouble(),
    };
  }

  @override
  Future<void> saveOneRepMax({required String exerciseId, required double weightKg}) async {
    await _client.from(_table).upsert({
      'user_id': _client.auth.currentUser!.id,
      'exercise_id': exerciseId,
      'weight_kg': weightKg,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });
  }
}
