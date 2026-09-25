import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/exercise.dart';
import '../domain/program.dart';
import '../domain/program_workout.dart';
import '../domain/schedule_mode.dart';
import '../domain/workout_exercise.dart';
import 'program_editor_state.dart';
import 'workout_providers.dart';

final programEditorProvider =
    NotifierProvider.autoDispose<ProgramEditorNotifier, ProgramEditorState>(ProgramEditorNotifier.new);

List<T> _move<T>(List<T> list, int from, int to) {
  final copy = [...list];
  final item = copy.removeAt(from);
  copy.insert(to, item);
  return copy;
}

/// Değişiklikler yalnızca yerel taslakta tutulur; `save()` tüm ağacı tek RPC ile yazar.
class ProgramEditorNotifier extends Notifier<ProgramEditorState> {
  @override
  ProgramEditorState build() => const ProgramEditorState();

  void start(Program program) => state = ProgramEditorState(draft: program);

  void startBlank() => state = const ProgramEditorState(
        draft: Program(name: '', scheduleMode: ScheduleMode.weekdays, workouts: []),
      );

  void _edit(Program Function(Program draft) change) {
    final draft = state.draft;
    if (draft == null) return;
    state = state.copyWith(draft: change(draft), dirty: true, saveFailed: false);
  }

  void _editWorkout(int index, ProgramWorkout Function(ProgramWorkout workout) change) {
    _edit((p) => p.copyWith(workouts: [...p.workouts]..[index] = change(p.workouts[index])));
  }

  void rename(String name) => _edit((p) => p.copyWith(name: name));

  void setScheduleMode(ScheduleMode mode) => _edit((p) => p.copyWith(
        scheduleMode: mode,
        workouts: mode == ScheduleMode.rotation
            ? [for (final w in p.workouts) w.copyWith(clearWeekday: true)]
            : p.workouts,
      ));

  void addWorkout(String name) =>
      _edit((p) => p.copyWith(workouts: [...p.workouts, ProgramWorkout(name: name, exercises: const [])]));

  void renameWorkout(int index, String name) => _editWorkout(index, (w) => w.copyWith(name: name));

  void removeWorkout(int index) => _edit((p) => p.copyWith(workouts: [...p.workouts]..removeAt(index)));

  void moveWorkout(int from, int to) => _edit((p) => p.copyWith(workouts: _move(p.workouts, from, to)));

  bool setWeekday(int index, int? weekday) {
    final draft = state.draft;
    if (draft == null) return false;
    final taken = weekday != null &&
        draft.workouts.indexed.any((entry) => entry.$1 != index && entry.$2.weekday == weekday);
    if (taken) return false;
    _editWorkout(index, (w) => weekday == null ? w.copyWith(clearWeekday: true) : w.copyWith(weekday: weekday));
    return true;
  }

  void addBlock(int workoutIndex, Exercise exercise) => _editWorkout(
        workoutIndex,
        (w) => w.copyWith(exercises: [
          ...w.exercises,
          WorkoutExercise(
            exerciseId: exercise.id,
            exerciseName: exercise.name,
            sets: 3,
            repsMin: 8,
            repsMax: 12,
            restSeconds: 90,
          ),
        ]),
      );

  void updateBlock(int workoutIndex, int blockIndex, WorkoutExercise block) =>
      _editWorkout(workoutIndex, (w) => w.copyWith(exercises: [...w.exercises]..[blockIndex] = block));

  void removeBlock(int workoutIndex, int blockIndex) =>
      _editWorkout(workoutIndex, (w) => w.copyWith(exercises: [...w.exercises]..removeAt(blockIndex)));

  void moveBlock(int workoutIndex, int from, int to) =>
      _editWorkout(workoutIndex, (w) => w.copyWith(exercises: _move(w.exercises, from, to)));

  Future<String?> save() async {
    final draft = state.draft;
    if (draft == null || state.validationError != null || state.saving) return null;
    state = state.copyWith(saving: true, saveFailed: false);
    try {
      final id = await ref.read(programRepositoryProvider).saveProgram(draft);
      state = ProgramEditorState(draft: draft.copyWith(id: id));
      ref.invalidate(programsProvider);
      ref.invalidate(programDetailProvider(id));
      return id;
    } catch (e, st) {
      debugPrint('ProgramEditorNotifier.save failed: $e\n$st');
      state = state.copyWith(saving: false, saveFailed: true);
      return null;
    }
  }
}
