import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/session_repository.dart';
import '../domain/exercise.dart';
import '../domain/workout_session.dart';
import 'session_providers.dart';
import 'start_session_service.dart';
import 'workout_providers.dart';

final sessionNotifierProvider =
    AsyncNotifierProvider.autoDispose.family<SessionNotifier, WorkoutSession, String>(SessionNotifier.new);

/// Antrenman ekranının state'i. Kilo/tekrar kutuları yalnızca yerel; ✓ ile
/// set anında sunucuya yazılır (iyimser; hata olursa geri alınır).
class SessionNotifier extends AsyncNotifier<WorkoutSession> {
  SessionNotifier(this.sessionId);

  final String sessionId;

  SessionRepository get _repo => ref.read(sessionRepositoryProvider);
  WorkoutSession get _session => state.requireValue;

  @override
  Future<WorkoutSession> build() => ref.watch(sessionRepositoryProvider).fetchSession(sessionId);

  void _replaceAll(Iterable<SessionSet> updated) {
    final byId = {for (final s in updated) s.id: s};
    state = AsyncData(_session.copyWith(sets: [for (final s in _session.sets) byId[s.id] ?? s]));
  }

  /// Hareketin ilk yapılmamış setiyse, aynı hareketin aynı yüzdeli diğer
  /// yapılmamış setlerine de yayılır.
  void setWeight(String setId, double? weightKg) {
    final target = _session.setById(setId);
    final pending = [
      for (final s in _session.sets)
        if (s.exercisePosition == target.exercisePosition && !s.isCompleted) s,
    ];
    final isFirstPending = pending.isNotEmpty && pending.first.id == setId;
    final affected = isFirstPending ? pending.where((s) => s.percent1rm == target.percent1rm) : [target];
    _replaceAll([for (final s in affected) s.copyWith(weightKg: weightKg, clearWeight: weightKg == null)]);
  }

  void setReps(String setId, int? reps) {
    _replaceAll([_session.setById(setId).copyWith(reps: reps, clearReps: reps == null)]);
  }

  /// Kutudaki değerlerle seti tamamlar. Tekrar bilinmiyorsa (boş AMRAP) veya
  /// yazılamazsa false.
  Future<bool> complete(String setId) {
    final before = _session.setById(setId);
    final reps = before.displayReps;
    if (reps == null) return Future.value(false);
    return _save(
      before,
      before.copyWith(weightKg: before.displayWeightKg, reps: reps, completedAt: DateTime.now()),
    );
  }

  Future<bool> uncomplete(String setId) {
    final before = _session.setById(setId);
    return _save(before, before.copyWith(clearCompletedAt: true));
  }

  Future<bool> _save(SessionSet before, SessionSet after) async {
    _replaceAll([after]);
    try {
      await _repo.updateSet(after);
      return true;
    } catch (e, st) {
      debugPrint('SessionNotifier.updateSet failed: $e\n$st');
      _replaceAll([before]);
      return false;
    }
  }

  Future<bool> addExercise(Exercise exercise) async {
    try {
      final sets = await ref
          .read(startSessionServiceProvider)
          .setsForAddedExercise(exercise, _session.nextExercisePosition);
      final added = await _repo.addSets(sessionId, sets);
      state = AsyncData(_session.copyWith(sets: [..._session.sets, ...added]));
      return true;
    } catch (e, st) {
      debugPrint('SessionNotifier.addExercise failed: $e\n$st');
      return false;
    }
  }

  /// Hareketin yapılmamış setlerini siler; yapılmışlar kalır.
  Future<bool> removeExercise(int exercisePosition) async {
    final ids = [
      for (final s in _session.sets)
        if (s.exercisePosition == exercisePosition && !s.isCompleted) s.id!,
    ];
    try {
      await _repo.deleteSets(ids);
      state = AsyncData(_session.copyWith(sets: [for (final s in _session.sets) if (!ids.contains(s.id)) s]));
      return true;
    } catch (e, st) {
      debugPrint('SessionNotifier.removeExercise failed: $e\n$st');
      return false;
    }
  }

  Future<void> cancel() async {
    await _repo.deleteSession(sessionId);
    ref.invalidate(inProgressSessionProvider);
  }

  /// Oturumu kapatır ve onaylanan 1RM'leri yazar (tek RPC). Hata fırlatır.
  Future<void> finish(Map<String, double> oneRepMaxes) async {
    await _repo.finishSession(sessionId, oneRepMaxes);
    ref
      ..invalidate(inProgressSessionProvider)
      ..invalidate(sessionHistoryProvider)
      ..invalidate(activeProgramStateProvider)
      ..invalidate(oneRepMaxesProvider);
  }
}
