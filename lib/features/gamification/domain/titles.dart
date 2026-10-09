import '../../workout/domain/exercise.dart';
import '../../workout/domain/exercise_taxonomy.dart';
import '../../workout/domain/muscle_heat.dart';
import '../../workout/domain/workout_session.dart';

/// Çırağı / Ustası / Şampiyonu (O1 spec §5).
enum TitleTier { apprentice, master, champion }

enum TitleKind { muscle, exercise }

const muscleThresholds = {TitleTier.apprentice: 100.0, TitleTier.master: 500.0, TitleTier.champion: 1500.0};
const exerciseThresholds = {TitleTier.apprentice: 10.0, TitleTier.master: 50.0, TitleTier.champion: 150.0};

class TitleProgress {
  const TitleProgress({required this.kind, required this.subjectId, required this.value, this.exerciseName});

  final TitleKind kind;

  /// Kas adı (`muscleGroups`) ya da exerciseId.
  final String subjectId;

  /// Yalnız hareket unvanında.
  final String? exerciseName;

  /// Kas: ağırlıklı set; hareket: oturum sayısı.
  final double value;

  Map<TitleTier, double> get _thresholds => kind == TitleKind.muscle ? muscleThresholds : exerciseThresholds;

  /// Ulaşılan en yüksek kademe; null = henüz yok.
  TitleTier? get tier {
    TitleTier? reached;
    for (final t in TitleTier.values) {
      if (value >= _thresholds[t]!) reached = t;
    }
    return reached;
  }

  /// Sonraki kademe; şampiyonda null.
  TitleTier? get nextTier {
    for (final t in TitleTier.values) {
      if (value < _thresholds[t]!) return t;
    }
    return null;
  }

  double? get nextThreshold => switch (nextTier) {
        final next? => _thresholds[next],
        null => null,
      };

  /// Aktif unvan anahtarı.
  String get id => '${kind.name}:$subjectId';
}

/// Tüm kaslar ve hareketler için ilerleme; değeri 0 olanlar yok.
List<TitleProgress> titleProgress(List<WorkoutSession> sessions, Map<String, Exercise> exercisesById) {
  final muscles = <String, double>{};
  final exerciseSessions = <String, int>{};
  final setNames = <String, String>{};
  for (final session in sessions) {
    if (session.finishedAt == null) continue;
    final done = <String>{};
    for (final set in session.sets) {
      if (!set.isCompleted) continue;
      done.add(set.exerciseId);
      setNames[set.exerciseId] ??= set.exerciseName;
      final exercise = exercisesById[set.exerciseId];
      if (exercise == null) continue;
      for (final muscle in {...exercise.primaryMuscles, ...exercise.secondaryMuscles}) {
        if (!muscleGroups.contains(muscle)) continue;
        muscles[muscle] = (muscles[muscle] ?? 0) + muscleWeight(exercise, muscle);
      }
    }
    for (final id in done) {
      exerciseSessions[id] = (exerciseSessions[id] ?? 0) + 1;
    }
  }
  return [
    for (final MapEntry(key: muscle, value: value) in muscles.entries)
      if (value > 0) TitleProgress(kind: TitleKind.muscle, subjectId: muscle, value: value),
    for (final MapEntry(key: id, value: count) in exerciseSessions.entries)
      TitleProgress(
        kind: TitleKind.exercise,
        subjectId: id,
        value: count.toDouble(),
        exerciseName: exercisesById[id]?.name ?? setNames[id],
      ),
  ];
}

/// Kazanılanlar: kademe yüksekten düşüğe, sonra değer büyükten küçüğe, sonra id.
List<TitleProgress> earnedTitles(List<TitleProgress> all) {
  final earned = [
    for (final t in all)
      if (t.tier != null) t,
  ];
  earned.sort((a, b) {
    final byTier = b.tier!.index.compareTo(a.tier!.index);
    if (byTier != 0) return byTier;
    final byValue = b.value.compareTo(a.value);
    return byValue != 0 ? byValue : a.id.compareTo(b.id);
  });
  return earned;
}

/// Sonraki kademeye en yakın [count] tanesi; şampiyonlar hariç.
List<TitleProgress> upcomingTitles(List<TitleProgress> all, {int count = 3}) {
  final open = [
    for (final t in all)
      if (t.nextThreshold != null) t,
  ];
  double share(TitleProgress t) => t.value / t.nextThreshold!;
  open.sort((a, b) {
    final byShare = share(b).compareTo(share(a));
    return byShare != 0 ? byShare : a.id.compareTo(b.id);
  });
  return open.take(count).toList();
}
