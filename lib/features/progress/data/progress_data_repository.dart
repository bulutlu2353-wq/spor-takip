import 'package:supabase_flutter/supabase_flutter.dart';

import '../../nutrition/domain/meal.dart';
import '../../workout/domain/workout_session.dart';

/// Grafik ve özetler için mevcut antrenman ve öğün tablolarından okuma.
abstract interface class ProgressDataRepository {
  /// Bitmiş oturumlar (setleriyle), eskiden yeniye; [since] verilirse
  /// yalnızca `finished_at >= since`.
  Future<List<WorkoutSession>> fetchFinishedSessions({DateTime? since});

  /// `[from, to)` aralığında kaydedilmiş öğünler (kalemleriyle).
  Future<List<Meal>> fetchMeals({required DateTime from, required DateTime to});

  /// Tüm öğünlerin kayıt zamanları (yerel), eskiden yeniye; oyunlaştırmadaki öğün günleri için.
  Future<List<DateTime>> fetchMealTimes();
}

class SupabaseProgressDataRepository implements ProgressDataRepository {
  SupabaseProgressDataRepository(this._client);

  final SupabaseClient _client;

  // Yalnızca grafik ve özetin kullandığı sütunlar. session_sets'in exercises'a
  // iki FK'si var (exercise_id, percent_ref_exercise_id).
  static const _sessionColumns = 'id, program_id, program_name, workout_name, workout_position, '
      'started_at, finished_at, session_sets(exercise_position, set_index, exercise_id, '
      'target_reps_min, target_reps_max, weight_kg, reps, completed_at, exercises!exercise_id(name))';

  @override
  Future<List<WorkoutSession>> fetchFinishedSessions({DateTime? since}) async {
    var query = _client.from('workout_sessions').select(_sessionColumns).not('finished_at', 'is', null);
    if (since != null) query = query.gte('finished_at', since.toUtc().toIso8601String());
    final rows = await query.order('finished_at');
    return [for (final row in rows) WorkoutSession.fromJson(row)];
  }

  @override
  Future<List<Meal>> fetchMeals({required DateTime from, required DateTime to}) async {
    final rows = await _client
        .from('meals')
        .select('*, meal_items(*)')
        .gte('logged_at', from.toUtc().toIso8601String())
        .lt('logged_at', to.toUtc().toIso8601String())
        .order('logged_at');
    return [for (final row in rows) Meal.fromJson(row)];
  }

  @override
  Future<List<DateTime>> fetchMealTimes() async {
    final rows = await _client.from('meals').select('logged_at').order('logged_at');
    return [for (final row in rows) DateTime.parse(row['logged_at'] as String).toLocal()];
  }
}
