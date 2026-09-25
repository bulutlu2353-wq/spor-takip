import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase_client.dart';
import '../../onboarding/application/auth_providers.dart';
import '../data/exercise_repository.dart';
import '../data/one_rep_max_repository.dart';
import '../data/program_repository.dart';
import '../domain/exercise.dart';
import '../domain/program.dart';
import '../domain/today_workout.dart';

final exerciseRepositoryProvider = Provider<ExerciseRepository>((ref) {
  return SupabaseExerciseRepository(AppSupabase.client);
});

final programRepositoryProvider = Provider<ProgramRepository>((ref) {
  return SupabaseProgramRepository(AppSupabase.client);
});

final oneRepMaxRepositoryProvider = Provider<OneRepMaxRepository>((ref) {
  return SupabaseOneRepMaxRepository(AppSupabase.client);
});

/// 876+ hareket; oturum boyunca bir kez çekilir (autoDispose değil).
/// Kendi hareketi eklenince/silinince `ref.invalidate(exercisesProvider)`.
final exercisesProvider = FutureProvider<List<Exercise>>((ref) async {
  if (!ref.watch(isLoggedInProvider)) return const [];
  return ref.watch(exerciseRepositoryProvider).fetchExercises();
});

final programsProvider = FutureProvider.autoDispose<List<Program>>((ref) async {
  if (!ref.watch(isLoggedInProvider)) return const [];
  return ref.watch(programRepositoryProvider).fetchPrograms();
});

final programDetailProvider = FutureProvider.autoDispose.family<Program, String>((ref, id) {
  return ref.watch(programRepositoryProvider).fetchProgram(id);
});

final oneRepMaxesProvider = FutureProvider.autoDispose<Map<String, double>>((ref) async {
  if (!ref.watch(isLoggedInProvider)) return const {};
  return ref.watch(oneRepMaxRepositoryProvider).fetchOneRepMaxes();
});

final activeProgramStateProvider = FutureProvider.autoDispose<ActiveProgramState>((ref) async {
  if (!ref.watch(isLoggedInProvider)) return const ActiveProgramState();
  return ref.watch(programRepositoryProvider).fetchActiveProgramState();
});

final todayWorkoutProvider = FutureProvider.autoDispose<TodayWorkout>((ref) async {
  final state = await ref.watch(activeProgramStateProvider.future);
  final programId = state.programId;
  final program = programId == null ? null : await ref.watch(programDetailProvider(programId).future);
  return resolveTodayWorkout(
    program: program,
    nextRotationPosition: state.nextRotationPosition,
    now: DateTime.now(),
  );
});
