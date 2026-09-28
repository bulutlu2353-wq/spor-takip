import 'package:flutter_test/flutter_test.dart';
import 'package:spor_takip/features/progress/domain/trend.dart';

final _now = DateTime(2026, 9, 28, 15);

ValuePoint _p(int month, int day, double value) => ValuePoint(DateTime(2026, month, day), value);

void main() {
  group('rangeStart', () {
    test('counts days back from today, all has no start', () {
      expect(rangeStart(ChartRange.month, _now), DateTime(2026, 8, 29));
      expect(rangeStart(ChartRange.threeMonths, _now), DateTime(2026, 6, 30));
      expect(rangeStart(ChartRange.year, _now), DateTime(2025, 9, 28));
      expect(rangeStart(ChartRange.all, _now), isNull);
    });

    test('pointsInRange keeps points on or after the start', () {
      final points = [_p(8, 28, 1), _p(8, 29, 2), _p(9, 28, 3)];
      expect(pointsInRange(points, ChartRange.month, _now).map((p) => p.value), [2, 3]);
      expect(pointsInRange(points, ChartRange.all, _now), hasLength(3));
      expect(isInRange(DateTime(2026, 8, 28, 23), ChartRange.month, _now), isFalse);
    });
  });

  group('changeOver30Days', () {
    test('no points or no point old enough → null', () {
      expect(changeOver30Days(const []), isNull);
      expect(changeOver30Days([_p(9, 1, 80), _p(9, 28, 79)]), isNull);
    });

    test('uses the newest point at least 30 days before the last one', () {
      final points = [_p(8, 1, 83), _p(8, 29, 82), _p(9, 10, 81), _p(9, 28, 79.5)];
      // 28.9 − 30 gün = 29.8 → referans 29.8 (82)
      expect(changeOver30Days(points), -2.5);
    });
  });
}
