import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/workout_session.dart';

/// Kullanıcının zaten devam eden bir oturumu var (kısmi unique index).
class ActiveSessionExistsException implements Exception {}

abstract interface class SessionRepository {
  /// Devam eden oturum (setleriyle) ya da null.
  Future<WorkoutSession?> fetchInProgressSession();

  Future<WorkoutSession> fetchSession(String id);

  /// Bitmiş oturumlar (setleriyle), yeniden eskiye.
  Future<List<WorkoutSession>> fetchHistory();

  /// Verilen hareketlerin geçtiği bitmiş oturumlar, yeniden eskiye; her
  /// oturumda yalnızca bu hareketlerin setleri bulunur.
  Future<List<WorkoutSession>> fetchExerciseHistory(Set<String> exerciseIds);

  /// Oturumu ve setleri tek RPC'de yazar, oturum id'sini döner.
  /// Devam eden oturum varsa [ActiveSessionExistsException].
  Future<String> startSession({
    required String? programId,
    required String programName,
    required String workoutName,
    required int workoutPosition,
    required List<SessionSet> sets,
  });

  /// Yalnızca sonuçlar: `weight_kg`, `reps`, `completed_at`.
  Future<void> updateSet(SessionSet set);

  /// Setleri ekler; sunucu id'leriyle döner.
  Future<List<SessionSet>> addSets(String sessionId, List<SessionSet> sets);

  Future<void> deleteSets(List<String> setIds);

  /// Oturumu kapatır, rotasyonu ilerletir, 1RM'leri yazar (tek RPC).
  Future<void> finishSession(String sessionId, Map<String, double> oneRepMaxes);

  Future<void> deleteSession(String sessionId);
}

class SupabaseSessionRepository implements SessionRepository {
  SupabaseSessionRepository(this._client);

  final SupabaseClient _client;

  static const _sessions = 'workout_sessions';
  static const _sets = 'session_sets';
  // session_sets'in exercises'a iki FK'si var (exercise_id, percent_ref_exercise_id).
  static const _setColumns = '*, exercises!exercise_id(name)';
  static const _sessionColumns = '*, session_sets($_setColumns)';
  static const _uniqueViolation = '23505';
  static const _historyLimit = 100;
  static const _exerciseHistoryLimit = 30;

  static List<WorkoutSession> _sessionList(Object? rows) =>
      (rows as List).map((r) => WorkoutSession.fromJson(r as Map<String, dynamic>)).toList();

  @override
  Future<WorkoutSession?> fetchInProgressSession() async {
    final row = await _client
        .from(_sessions)
        .select(_sessionColumns)
        .isFilter('finished_at', null)
        .maybeSingle();
    return row == null ? null : WorkoutSession.fromJson(row);
  }

  @override
  Future<WorkoutSession> fetchSession(String id) async {
    final row = await _client.from(_sessions).select(_sessionColumns).eq('id', id).single();
    return WorkoutSession.fromJson(row);
  }

  @override
  Future<List<WorkoutSession>> fetchHistory() async {
    final rows = await _client
        .from(_sessions)
        .select(_sessionColumns)
        .not('finished_at', 'is', null)
        .order('finished_at', ascending: false)
        .limit(_historyLimit);
    return _sessionList(rows);
  }

  @override
  Future<List<WorkoutSession>> fetchExerciseHistory(Set<String> exerciseIds) async {
    if (exerciseIds.isEmpty) return const [];
    final rows = await _client
        .from(_sessions)
        .select('*, session_sets!inner($_setColumns)')
        .not('finished_at', 'is', null)
        .inFilter('session_sets.exercise_id', exerciseIds.toList())
        .order('finished_at', ascending: false)
        .limit(_exerciseHistoryLimit);
    return _sessionList(rows);
  }

  @override
  Future<String> startSession({
    required String? programId,
    required String programName,
    required String workoutName,
    required int workoutPosition,
    required List<SessionSet> sets,
  }) async {
    try {
      final id = await _client.rpc('start_session', params: {
        'payload': {
          'program_id': programId,
          'program_name': programName,
          'workout_name': workoutName,
          'workout_position': workoutPosition,
          'sets': [for (final s in sets) s.toInsertJson()],
        },
      });
      return id as String;
    } on PostgrestException catch (error) {
      if (error.code == _uniqueViolation) throw ActiveSessionExistsException();
      rethrow;
    }
  }

  @override
  Future<void> updateSet(SessionSet set) async {
    await _client.from(_sets).update({
      'weight_kg': set.weightKg,
      'reps': set.reps,
      'completed_at': set.completedAt?.toUtc().toIso8601String(),
    }).eq('id', set.id!);
  }

  @override
  Future<List<SessionSet>> addSets(String sessionId, List<SessionSet> sets) async {
    final rows = await _client
        .from(_sets)
        .insert([for (final s in sets) {...s.toInsertJson(), 'session_id': sessionId}])
        .select(_setColumns);
    return (rows as List).map((r) => SessionSet.fromJson(r as Map<String, dynamic>)).toList();
  }

  @override
  Future<void> deleteSets(List<String> setIds) async {
    if (setIds.isEmpty) return;
    await _client.from(_sets).delete().inFilter('id', setIds);
  }

  @override
  Future<void> finishSession(String sessionId, Map<String, double> oneRepMaxes) async {
    await _client.rpc('finish_session', params: {
      'p_session_id': sessionId,
      'p_one_rep_maxes': [
        for (final MapEntry(key: exerciseId, value: kg) in oneRepMaxes.entries)
          {'exercise_id': exerciseId, 'weight_kg': kg},
      ],
    });
  }

  @override
  Future<void> deleteSession(String sessionId) async {
    await _client.from(_sessions).delete().eq('id', sessionId);
  }
}
