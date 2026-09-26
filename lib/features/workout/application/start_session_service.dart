import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/exercise.dart';
import '../domain/program.dart';
import '../domain/session_builder.dart';
import '../domain/workout_session.dart';
import 'session_providers.dart';
import 'workout_providers.dart';

final startSessionServiceProvider = Provider<StartSessionService>(StartSessionService.new);

/// Program antrenmanından (veya eklenen hareketten) önerili setler üretir.
class StartSessionService {
  StartSessionService(this._ref);

  final Ref _ref;

  Future<(ExerciseHistory, Map<String, Exercise>)> _context(Set<String> exerciseIds) async {
    final (sessions, exercises) = await (
      _ref.read(sessionRepositoryProvider).fetchExerciseHistory(exerciseIds),
      _ref.read(exercisesProvider.future),
    ).wait;
    return (groupExerciseHistory(sessions), {for (final e in exercises) e.id: e});
  }

  /// Programın [workoutIndex]'teki antrenmanını başlatır, oturum id'sini döner.
  /// Devam eden oturum varsa `ActiveSessionExistsException` fırlatır.
  Future<String> start(Program program, int workoutIndex) async {
    final workout = program.workouts[workoutIndex];
    final (history, exercises) = await _context({for (final b in workout.exercises) b.exerciseId});
    final oneRepMaxes = await _ref.read(oneRepMaxRepositoryProvider).fetchOneRepMaxes();
    final sets = buildSessionSets(
      workout: workout,
      oneRepMaxes: oneRepMaxes,
      history: history,
      exercises: exercises,
    );
    final id = await _ref.read(sessionRepositoryProvider).startSession(
          programId: program.id,
          programName: program.name,
          workoutName: workout.name,
          workoutPosition: workoutIndex,
          sets: sets,
        );
    _ref.invalidate(inProgressSessionProvider);
    return id;
  }

  Future<List<SessionSet>> setsForAddedExercise(Exercise exercise, int exercisePosition) async {
    final (history, exercises) = await _context({exercise.id});
    return buildAddedExerciseSets(
      exercise: exercise,
      exercisePosition: exercisePosition,
      history: history,
      exercises: exercises,
    );
  }
}
