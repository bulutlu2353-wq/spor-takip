import 'workout_session.dart';

int completedSetCount(WorkoutSession session) => session.sets.where((s) => s.isCompleted).length;

/// Σ kilo × tekrar; kilosuz (vücut ağırlığı) setler hariç.
double totalVolumeKg(WorkoutSession session) {
  var total = 0.0;
  for (final s in session.sets) {
    if (s.isCompleted && s.weightKg != null && s.reps != null) total += s.weightKg! * s.reps!;
  }
  return total;
}

/// Bitmişse başlangıçtan bitişe, değilse başlangıçtan [now]'a; negatif olmaz.
Duration sessionDuration(WorkoutSession session, DateTime now) {
  final elapsed = (session.finishedAt ?? now).difference(session.startedAt);
  return elapsed.isNegative ? Duration.zero : elapsed;
}

/// 90 sn → "01:30", 1 sa 5 dk 3 sn → "1:05:03".
String formatDuration(Duration duration) {
  String two(int n) => n.toString().padLeft(2, '0');
  final minutes = two(duration.inMinutes.remainder(60));
  final seconds = two(duration.inSeconds.remainder(60));
  return duration.inHours > 0 ? '${duration.inHours}:$minutes:$seconds' : '$minutes:$seconds';
}
