import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/exercise.dart';
import '../domain/muscle_heat.dart';
import '../domain/program.dart';
import '../domain/workout_session.dart';
import 'session_providers.dart';
import 'workout_providers.dart';

typedef HistoryHeat = ({
  List<WorkoutSession> sessions,
  Map<String, Exercise> exercisesById,
  MuscleLoad load,
  DateTime since,
});

typedef ProgramHeat = ({Program program, Map<String, Exercise> exercisesById, MuscleLoad load});

final exercisesByIdProvider = FutureProvider.autoDispose<Map<String, Exercise>>((ref) async {
  final all = await ref.watch(exercisesProvider.future);
  return {for (final e in all) e.id: e};
});

/// Son [days] günde biten oturumların set yükü. Kaynak: son 100 bitmiş oturum (K3 spec §2.5).
final historyHeatProvider = FutureProvider.autoDispose.family<HistoryHeat, int>((ref, days) async {
  final sessions = await ref.watch(sessionHistoryProvider.future);
  final exercisesById = await ref.watch(exercisesByIdProvider.future);
  final since = ref.read(nowProvider)().subtract(Duration(days: days));
  return (
    sessions: sessions,
    exercisesById: exercisesById,
    load: historyMuscleLoad(sessions, exercisesById, since),
    since: since,
  );
});

/// Programın planlı set yükü.
final programHeatProvider = FutureProvider.autoDispose.family<ProgramHeat, String>((ref, programId) async {
  final program = await ref.watch(programDetailProvider(programId).future);
  final exercisesById = await ref.watch(exercisesByIdProvider.future);
  return (program: program, exercisesById: exercisesById, load: programMuscleLoad(program, exercisesById));
});
