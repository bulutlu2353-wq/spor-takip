import 'exercise.dart';
import 'program.dart';
import 'workout_session.dart';

/// Haftalık set yüküne göre ısı kademesi (K3 spec §3).
enum HeatTier { none, low, medium, optimal, high }

HeatTier heatTierFor(double weeklySets) {
  if (weeklySets <= 0) return HeatTier.none;
  if (weeklySets < 4) return HeatTier.low;
  if (weeklySets < 10) return HeatTier.medium;
  if (weeklySets < 20) return HeatTier.optimal;
  return HeatTier.high;
}

/// Bir hareketin bir kasa katkısı: birincilse 1, ikincilse 0,5, değilse 0.
double muscleWeight(Exercise exercise, String muscle) {
  if (exercise.primaryMuscles.contains(muscle)) return 1;
  if (exercise.secondaryMuscles.contains(muscle)) return 0.5;
  return 0;
}

/// Kas başına ağırlıklı set yükü.
typedef MuscleLoad = Map<String, double>;

/// Bir kas için hareket başına ham set sayısı; [primary] kas birincilse true.
typedef ExerciseLoad = ({Exercise exercise, int sets, bool primary});

/// Hareket → [since]'ten sonra biten oturumlardaki tamamlanmış set sayısı.
Map<String, int> _historySetCounts(List<WorkoutSession> sessions, DateTime since) {
  final counts = <String, int>{};
  for (final session in sessions) {
    final finished = session.finishedAt;
    if (finished == null || finished.isBefore(since)) continue;
    for (final set in session.sets) {
      if (set.isCompleted) counts[set.exerciseId] = (counts[set.exerciseId] ?? 0) + 1;
    }
  }
  return counts;
}

/// Hareket → programın tüm günlerindeki planlı set sayısı.
Map<String, int> _programSetCounts(Program program) {
  final counts = <String, int>{};
  for (final workout in program.workouts) {
    for (final e in workout.exercises) {
      if (e.sets > 0) counts[e.exerciseId] = (counts[e.exerciseId] ?? 0) + e.sets;
    }
  }
  return counts;
}

MuscleLoad _loadFrom(Map<String, int> counts, Map<String, Exercise> exercisesById) {
  final load = <String, double>{};
  for (final MapEntry(key: id, value: sets) in counts.entries) {
    final exercise = exercisesById[id];
    if (exercise == null) continue;
    for (final muscle in {...exercise.primaryMuscles, ...exercise.secondaryMuscles}) {
      load[muscle] = (load[muscle] ?? 0) + sets * muscleWeight(exercise, muscle);
    }
  }
  return load;
}

List<ExerciseLoad> _loadsForMuscle(Map<String, int> counts, Map<String, Exercise> exercisesById, String muscle) {
  final rows = <ExerciseLoad>[
    for (final MapEntry(key: id, value: sets) in counts.entries)
      if (exercisesById[id] case final exercise? when muscleWeight(exercise, muscle) > 0)
        (exercise: exercise, sets: sets, primary: exercise.primaryMuscles.contains(muscle)),
  ];
  rows.sort((a, b) {
    final bySets = b.sets.compareTo(a.sets);
    return bySets != 0 ? bySets : a.exercise.name.compareTo(b.exercise.name);
  });
  return rows;
}

/// Bitmiş oturumlardan, `finishedAt >= since` olanların tamamlanmış setleri.
/// Hareketi [exercisesById]'de olmayan setler atlanır.
MuscleLoad historyMuscleLoad(List<WorkoutSession> sessions, Map<String, Exercise> exercisesById, DateTime since) =>
    _loadFrom(_historySetCounts(sessions, since), exercisesById);

/// Programdaki tüm günlerin planlı setleri, aynı ağırlıklarla.
MuscleLoad programMuscleLoad(Program program, Map<String, Exercise> exercisesById) =>
    _loadFrom(_programSetCounts(program), exercisesById);

/// Yükü haftalığa çevirip kademeye eşler; `none` olanlar dışarıda kalır.
/// [days] null → yük olduğu gibi (program bir döngü).
Map<String, HeatTier> heatTiers(MuscleLoad load, {int? days}) {
  final perWeek = days == null ? 1.0 : 7 / days;
  return {
    for (final MapEntry(key: muscle, value: sets) in load.entries)
      if (heatTierFor(sets * perWeek) case final tier when tier != HeatTier.none) muscle: tier,
  };
}

List<ExerciseLoad> historyLoadsForMuscle(
  List<WorkoutSession> sessions,
  Map<String, Exercise> exercisesById,
  DateTime since,
  String muscle,
) =>
    _loadsForMuscle(_historySetCounts(sessions, since), exercisesById, muscle);

List<ExerciseLoad> programLoadsForMuscle(Program program, Map<String, Exercise> exercisesById, String muscle) =>
    _loadsForMuscle(_programSetCounts(program), exercisesById, muscle);

/// 5.0 → "5", 1.5 → "1.5".
String formatSets(double sets) =>
    sets == sets.roundToDouble() ? sets.toInt().toString() : sets.toStringAsFixed(1);
