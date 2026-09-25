const _plateStepKg = 2.5;

/// 1RM × yüzde; en yakın 2,5 kg'a yuvarlanır. Girdilerden biri yoksa null
/// (arayüz o zaman kilo yerine yüzdeyi gösterir).
double? targetWeightKg({required double? oneRepMaxKg, required double? percent1rm}) {
  if (oneRepMaxKg == null || percent1rm == null) return null;
  final raw = oneRepMaxKg * percent1rm / 100;
  return (raw / _plateStepKg).round() * _plateStepKg;
}
