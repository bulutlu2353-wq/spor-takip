import '../../workout/domain/workout_session.dart';
import 'trend.dart';

/// Epley yüksek tekrarda güvenilmez; bundan fazla tekrarlı setler sayılmaz.
const maxRepsForEstimate = 10;

/// Spec §4.1: Epley `kilo × (1 + tekrar / 30)`; tek tekrar → kilonun kendisi.
/// Kilosuz, tekrarsız ya da 10'dan fazla tekrarlı sette null.
double? estimateOneRepMax({required double? weightKg, required int? reps}) {
  if (weightKg == null || reps == null) return null;
  if (weightKg <= 0 || reps < 1 || reps > maxRepsForEstimate) return null;
  return reps == 1 ? weightKg : weightKg * (1 + reps / 30);
}

/// Bir oturumdaki bir hareketin en iyi seti.
class StrengthPoint {
  const StrengthPoint({
    required this.date,
    required this.estimateKg,
    required this.weightKg,
    required this.reps,
  });

  /// Oturumun bitişi (yerel).
  final DateTime date;
  final double estimateKg;
  final double weightKg;
  final int reps;
}

class StrengthSeries {
  const StrengthSeries({required this.exerciseId, required this.exerciseName, required this.points});

  final String exerciseId;
  final String exerciseName;

  /// Oturum başına bir nokta, eskiden yeniye; boş olmaz.
  final List<StrengthPoint> points;

  StrengthPoint get latest => points.last;

  List<ValuePoint> get valuePoints => [for (final p in points) ValuePoint(p.date, p.estimateKg)];
}

int _mostFrequentFirst(StrengthSeries a, StrengthSeries b, int Function(StrengthSeries) count) {
  final byCount = count(b).compareTo(count(a));
  return byCount != 0 ? byCount : b.latest.date.compareTo(a.latest.date);
}

/// Bitmiş oturumlardan hareket başına seri. Sıra: oturum sayısı çoktan aza,
/// eşitlikte en son yapılan önce.
List<StrengthSeries> strengthSeries(List<WorkoutSession> sessions) {
  final points = <String, List<StrengthPoint>>{};
  final names = <String, String>{};
  for (final session in sessions) {
    final finishedAt = session.finishedAt;
    if (finishedAt == null) continue;
    final best = <String, StrengthPoint>{};
    for (final set in session.sets) {
      if (!set.isCompleted) continue;
      final estimate = estimateOneRepMax(weightKg: set.weightKg, reps: set.reps);
      if (estimate == null) continue;
      final current = best[set.exerciseId];
      if (current == null || estimate > current.estimateKg) {
        best[set.exerciseId] = StrengthPoint(
          date: finishedAt.toLocal(),
          estimateKg: estimate,
          weightKg: set.weightKg!,
          reps: set.reps!,
        );
        names[set.exerciseId] = set.exerciseName;
      }
    }
    for (final MapEntry(key: exerciseId, value: point) in best.entries) {
      (points[exerciseId] ??= []).add(point);
    }
  }
  final series = [
    for (final MapEntry(key: exerciseId, value: list) in points.entries)
      StrengthSeries(
        exerciseId: exerciseId,
        exerciseName: names[exerciseId]!,
        points: list..sort((a, b) => a.date.compareTo(b.date)),
      ),
  ];
  return series..sort((a, b) => _mostFrequentFirst(a, b, (s) => s.points.length));
}

/// Spec §4.2: son 90 günde en çok oturumda yapılan [count] hareket.
List<StrengthSeries> topStrengthSeries(List<StrengthSeries> all, DateTime now, {int count = 3}) {
  final since = DateTime(now.year, now.month, now.day - 90);
  int recent(StrengthSeries s) => s.points.where((p) => !p.date.isBefore(since)).length;
  final candidates = [for (final s in all) if (recent(s) > 0) s]
    ..sort((a, b) => _mostFrequentFirst(a, b, recent));
  return candidates.take(count).toList();
}
