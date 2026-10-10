import 'package:flutter_test/flutter_test.dart';
import 'package:spor_takip/features/social/domain/period_keys.dart';

void main() {
  test('ISO week keys, including the 53rd week around the new year', () {
    expect(weekKey(DateTime(2026, 10, 9, 12)), '2026-W41');
    expect(weekKey(DateTime(2025, 12, 29)), '2026-W01');
    expect(weekKey(DateTime(2026, 1, 1)), '2026-W01');
    expect(weekKey(DateTime(2026, 12, 28)), '2026-W53');
    expect(weekKey(DateTime(2026, 12, 31, 23, 59)), '2026-W53');
    expect(weekKey(DateTime(2027, 1, 1)), '2026-W53');
    expect(weekKey(DateTime(2027, 1, 3, 23)), '2026-W53');
    expect(weekKey(DateTime(2027, 1, 4)), '2027-W01');
  });

  test('month keys are zero padded', () {
    expect(monthKey(DateTime(2026, 10, 9)), '2026-10');
    expect(monthKey(DateTime(2027, 1, 1)), '2027-01');
  });

  test('ranges start on Monday / the first and end exclusively', () {
    final now = DateTime(2026, 10, 9, 12);
    expect(periodRange(PeriodKind.week, now), (start: DateTime(2026, 10, 5), end: DateTime(2026, 10, 12)));
    expect(
      periodRange(PeriodKind.week, now, previous: true),
      (start: DateTime(2026, 9, 28), end: DateTime(2026, 10, 5)),
    );
    expect(periodRange(PeriodKind.month, now), (start: DateTime(2026, 10), end: DateTime(2026, 11)));
    expect(
      periodRange(PeriodKind.month, DateTime(2027, 1, 15), previous: true),
      (start: DateTime(2026, 12), end: DateTime(2027, 1)),
    );
  });

  test('period keys for this and the previous period', () {
    final now = DateTime(2026, 10, 9, 12);
    expect(periodKey(PeriodKind.week, now), '2026-W41');
    expect(periodKey(PeriodKind.week, now, previous: true), '2026-W40');
    expect(periodKey(PeriodKind.month, now), '2026-10');
    expect(periodKey(PeriodKind.month, DateTime(2027, 1, 15), previous: true), '2026-12');
    expect(periodKey(PeriodKind.week, DateTime(2027, 1, 4), previous: true), '2026-W53');
  });

  test('remaining time is in days, or in hours on the last day; rounded up, at least 1', () {
    expect(periodRemaining(PeriodKind.week, DateTime(2026, 10, 9, 12)), (n: 3, hours: false));
    expect(periodRemaining(PeriodKind.week, DateTime(2026, 10, 11, 12, 30)), (n: 12, hours: true));
    expect(periodRemaining(PeriodKind.week, DateTime(2026, 10, 11, 23, 59, 30)), (n: 1, hours: true));
    expect(periodRemaining(PeriodKind.month, DateTime(2026, 10, 9, 12)), (n: 23, hours: false));
  });
}
