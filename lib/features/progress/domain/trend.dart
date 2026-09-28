/// Grafikte tek nokta.
class ValuePoint {
  const ValuePoint(this.date, this.value);

  final DateTime date;
  final double value;
}

/// Grafik aralığı seçimi.
enum ChartRange { month, threeMonths, year, all }

/// Aralığın ilk günü (dahil, yerel 00:00); [ChartRange.all] için null.
DateTime? rangeStart(ChartRange range, DateTime now) {
  final days = switch (range) {
    ChartRange.month => 30,
    ChartRange.threeMonths => 90,
    ChartRange.year => 365,
    ChartRange.all => null,
  };
  if (days == null) return null;
  return DateTime(now.year, now.month, now.day - days);
}

bool isInRange(DateTime date, ChartRange range, DateTime now) {
  final start = rangeStart(range, now);
  return start == null || !date.isBefore(start);
}

List<ValuePoint> pointsInRange(List<ValuePoint> points, ChartRange range, DateTime now) =>
    [for (final p in points) if (isInRange(p.date, range, now)) p];

/// Spec §4.3. [points] eskiden yeniye: son değer − (tarihi son tarihten en az
/// 30 gün önce olan en yeni değer). Böyle bir değer yoksa null.
double? changeOver30Days(List<ValuePoint> points) {
  if (points.isEmpty) return null;
  final last = points.last;
  final cutoff = DateTime(last.date.year, last.date.month, last.date.day - 30);
  ValuePoint? reference;
  for (final p in points) {
    if (!p.date.isAfter(cutoff)) reference = p;
  }
  return reference == null ? null : last.value - reference.value;
}
