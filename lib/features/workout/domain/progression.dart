import 'dart:math' as math;

import 'exercise.dart';
import 'weight_calculator.dart';
import 'workout_session.dart';

const _lowerBodyMuscles = {'quadriceps', 'hamstrings', 'glutes', 'lower back'};
const _deloadFactor = 0.9;
const _deloadAfterFailures = 3;

/// Alt vücut halter hareketleri +5 kg, diğer her şey +2,5 kg.
double weightIncrementKg(Exercise? exercise) {
  final lowerBodyBarbell = exercise != null &&
      exercise.equipment == 'barbell' &&
      exercise.primaryMuscles.any(_lowerBodyMuscles.contains);
  return lowerBodyBarbell ? 5 : 2.5;
}

class WeightSuggestion {
  const WeightSuggestion(this.weightKg, {this.deloaded = false});

  /// null = öneri yok (geçmiş yok ya da kilo girilmemiş).
  final double? weightKg;
  final bool deloaded;
}

double? _referenceWeight(List<SessionSet> sets) {
  final weights = [for (final s in sets) if (s.isCompleted && s.weightKg != null) s.weightKg!];
  return weights.isEmpty ? null : weights.reduce(math.max);
}

bool _succeeded(List<SessionSet> sets) => sets.every((s) => s.hitTarget);

/// Yüzdelik olmayan bir bloğun önerilen kilosu.
///
/// [history]: hareketin geçtiği bitmiş oturumlardaki setleri, yeniden eskiye.
/// Son oturumda her set hedefin üstüne ulaştıysa artış, ulaşmadıysa aynı kilo;
/// son 3 oturum aynı kiloda ve üçü de başarısızsa %10 düşüş.
WeightSuggestion suggestWeight({required List<List<SessionSet>> history, required double incrementKg}) {
  final sessions = [
    for (final sets in history) [for (final s in sets) if (s.percent1rm == null) s],
  ].where((sets) => sets.isNotEmpty).toList();
  if (sessions.isEmpty) return const WeightSuggestion(null);

  final reference = _referenceWeight(sessions.first);
  if (reference == null) return const WeightSuggestion(null);

  final recent = sessions.take(_deloadAfterFailures).toList();
  final stuck = recent.length == _deloadAfterFailures &&
      recent.every((sets) => _referenceWeight(sets) == reference && !_succeeded(sets));
  if (stuck) return WeightSuggestion(roundToPlate(reference * _deloadFactor), deloaded: true);

  return WeightSuggestion(_succeeded(sessions.first) ? reference + incrementKg : reference);
}

class OneRepMaxSuggestion {
  const OneRepMaxSuggestion({required this.exerciseId, required this.currentKg, required this.suggestedKg});

  final String exerciseId;
  final double currentKg;
  final double suggestedKg;
}

/// AMRAP setindeki fazla tekrara göre yeni 1RM; değişiklik yoksa null.
/// Hedefin altı −%10; 0 fazla → yok; 1–2 → +2,5; 3–4 → +5; 5+ → +7,5 kg.
double? adjustedOneRepMax({required double currentKg, required int extraReps}) {
  if (extraReps < 0) return roundToPlate(currentKg * _deloadFactor);
  if (extraReps == 0) return null;
  final step = extraReps <= 2
      ? 2.5
      : extraReps <= 4
          ? 5.0
          : 7.5;
  return roundToPlate(currentKg + step);
}

/// Oturumdaki her 1RM hareketi için en yüksek yüzdeli tamamlanmış AMRAP setine
/// göre öneri. Kayıtlı 1RM'si olmayan hareketlere öneri yapılmaz.
List<OneRepMaxSuggestion> oneRepMaxSuggestions({
  required List<SessionSet> sets,
  required Map<String, double> oneRepMaxes,
}) {
  final best = <String, SessionSet>{};
  for (final s in sets) {
    if (!s.isAmrap || !s.isCompleted || s.percent1rm == null || s.reps == null) continue;
    final current = best[s.oneRepMaxExerciseId];
    if (current == null || s.percent1rm! > current.percent1rm!) best[s.oneRepMaxExerciseId] = s;
  }

  final result = <OneRepMaxSuggestion>[];
  for (final MapEntry(key: exerciseId, value: set) in best.entries) {
    final current = oneRepMaxes[exerciseId];
    if (current == null) continue;
    final next = adjustedOneRepMax(currentKg: current, extraReps: set.reps! - set.targetRepsMin);
    if (next == null || next == current) continue;
    result.add(OneRepMaxSuggestion(exerciseId: exerciseId, currentKg: current, suggestedKg: next));
  }
  return result;
}
