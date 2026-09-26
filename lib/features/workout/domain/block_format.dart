import 'weight_calculator.dart';
import 'workout_exercise.dart';
import 'workout_session.dart';

/// 60.0 → "60", 57.5 → "57.5".
String trimNumber(double value) =>
    value == value.roundToDouble() ? value.toInt().toString() : value.toString();

String _repsLabel(int min, int max, bool isAmrap) =>
    '${min == max ? '$min' : '$min–$max'}${isAmrap ? '+' : ''}';

String setsRepsLabel(WorkoutExercise block) =>
    '${block.sets} × ${_repsLabel(block.repsMin, block.repsMax, block.isAmrap)}';

/// 1RM varsa hesaplanan kilo, yoksa yüzde; yüzdesiz blokta null.
String? loadLabel(WorkoutExercise block, double? oneRepMaxKg) {
  final pct = block.percent1rm;
  if (pct == null) return null;
  final kg = targetWeightKg(oneRepMaxKg: oneRepMaxKg, percent1rm: pct);
  return kg == null ? '%${trimNumber(pct)}' : '${trimNumber(kg)} kg';
}

/// Oturum setinin hedefi: "5", "8–12", "5+"; yüzdeliyse "5+ · %85".
String sessionSetTargetLabel(SessionSet set) {
  final reps = _repsLabel(set.targetRepsMin, set.targetRepsMax, set.isAmrap);
  final pct = set.percent1rm;
  return pct == null ? reps : '$reps · %${trimNumber(pct)}';
}
