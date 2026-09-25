import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/program.dart';

class ActiveProgramState {
  const ActiveProgramState({this.programId, this.nextRotationPosition = 0});

  final String? programId;
  final int nextRotationPosition;
}

abstract interface class ProgramRepository {
  /// Hazır + kendi programları; antrenmanlar gömülü değil (liste ekranı için).
  Future<List<Program>> fetchPrograms();

  /// Tüm antrenman ve bloklarıyla tek program.
  Future<Program> fetchProgram(String id);

  /// Kaynağın kullanıcıya ait kopyasını oluşturur, yeni id'yi döner.
  Future<String> copyProgram(String sourceId);

  /// Program ağacını tek transaction'da yazar (id null → yeni), id'yi döner.
  Future<String> saveProgram(Program program);

  Future<void> deleteProgram(String id);

  Future<ActiveProgramState> fetchActiveProgramState();

  /// Aktif programı değiştirir ve döngü sırasını başa alır.
  Future<void> setActiveProgram(String? programId);

  Future<void> setRotationPosition(int position);
}

class SupabaseProgramRepository implements ProgramRepository {
  SupabaseProgramRepository(this._client);

  final SupabaseClient _client;

  static const _programs = 'programs';
  static const _profiles = 'profiles';
  static const _summaryColumns =
      'id, user_id, name, description, level, schedule_mode, days_per_week, source_program_id';
  static const _treeColumns =
      '*, program_workouts(*, workout_exercises(*, exercises!exercise_id(name)))';

  String get _userId => _client.auth.currentUser!.id;

  @override
  Future<List<Program>> fetchPrograms() async {
    final rows = await _client.from(_programs).select(_summaryColumns).order('name');
    return (rows as List).map((r) => Program.fromJson(r as Map<String, dynamic>)).toList();
  }

  @override
  Future<Program> fetchProgram(String id) async {
    final row = await _client.from(_programs).select(_treeColumns).eq('id', id).single();
    return Program.fromJson(row);
  }

  @override
  Future<String> copyProgram(String sourceId) async {
    final id = await _client.rpc('copy_program', params: {'source': sourceId});
    return id as String;
  }

  @override
  Future<String> saveProgram(Program program) async {
    final id = await _client.rpc('save_program', params: {'payload': program.toSavePayload()});
    return id as String;
  }

  @override
  Future<void> deleteProgram(String id) async {
    await _client.from(_programs).delete().eq('id', id);
  }

  @override
  Future<ActiveProgramState> fetchActiveProgramState() async {
    final row = await _client
        .from(_profiles)
        .select('active_program_id, next_rotation_position')
        .eq('user_id', _userId)
        .maybeSingle();
    if (row == null) return const ActiveProgramState();
    return ActiveProgramState(
      programId: row['active_program_id'] as String?,
      nextRotationPosition: row['next_rotation_position'] as int? ?? 0,
    );
  }

  @override
  Future<void> setActiveProgram(String? programId) async {
    await _client
        .from(_profiles)
        .update({'active_program_id': programId, 'next_rotation_position': 0})
        .eq('user_id', _userId);
  }

  @override
  Future<void> setRotationPosition(int position) async {
    await _client
        .from(_profiles)
        .update({'next_rotation_position': position})
        .eq('user_id', _userId);
  }
}
