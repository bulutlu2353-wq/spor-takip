import 'weight_calculator.dart';
import 'workout_exercise.dart';

String _trim(double value) =>
    value == value.roundToDouble() ? value.toInt().toString() : value.toString();

String setsRepsLabel(WorkoutExercise block) {
  final reps = block.repsMin == block.repsMax ? '${block.repsMin}' : '${block.repsMin}–${block.repsMax}';
  return '${block.sets} × $reps${block.isAmrap ? '+' : ''}';
}

/// 1RM varsa hesaplanan kilo, yoksa yüzde; yüzdesiz blokta null.
String? loadLabel(WorkoutExercise block, double? oneRepMaxKg) {
  final pct = block.percent1rm;
  if (pct == null) return null;
  final kg = targetWeightKg(oneRepMaxKg: oneRepMaxKg, percent1rm: pct);
  return kg == null ? '%${_trim(pct)}' : '${_trim(kg)} kg';
}
