import 'package:flutter_test/flutter_test.dart';
import 'package:spor_takip/features/progress/domain/progress_format.dart';

void main() {
  test('dateOnly drops the time of day', () {
    expect(dateOnly(DateTime(2026, 9, 28, 13, 5)), DateTime(2026, 9, 28));
  });

  test('database dates round-trip', () {
    expect(formatDbDate(DateTime(2026, 1, 5, 23, 59)), '2026-01-05');
    expect(parseDbDate('2026-01-05'), DateTime(2026, 1, 5));
  });

  test('short date', () {
    expect(formatShortDate(DateTime(2026, 9, 8)), '8.9.2026');
  });

  test('one decimal', () {
    expect(formatOneDecimal(80), '80');
    expect(formatOneDecimal(80.25), '80.3');
    expect(formatOneDecimal(79.94), '79.9');
  });

  test('delta shows direction, rounds to one decimal, dash for null', () {
    expect(formatDelta(null), '—');
    expect(formatDelta(0.04), '0');
    expect(formatDelta(1.5), '▲ 1.5');
    expect(formatDelta(-2), '▼ 2');
  });

  test('parseDecimal accepts comma and dot', () {
    expect(parseDecimal(' 80,5 '), 80.5);
    expect(parseDecimal('80.5'), 80.5);
    expect(parseDecimal(''), isNull);
    expect(parseDecimal('abc'), isNull);
  });
}
