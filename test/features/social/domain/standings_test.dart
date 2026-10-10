import 'package:flutter_test/flutter_test.dart';
import 'package:spor_takip/features/social/domain/period_keys.dart';
import 'package:spor_takip/features/social/domain/standings.dart';

import '../social_fixtures.dart';

final _members = {
  'me': socialPeriod(week: 640, weekMuscles: {'lats': 10}),
  'ayse': socialPeriod(week: 1420, weekMuscles: {'lats': 14.5, 'chest': 9}, prevWeek: 900),
  'burak': socialPeriod(week: 640, weekMuscles: {'lats': 14.5}, prevWeek: 900, prevWeekMuscles: {'chest': 4}),
  'can': socialPeriod(),
  'deniz': socialPeriod(week: 5000, weekSlotKey: '2026-W39'), // eski yayın
  'eda': socialPeriod(week: 100),
};

void main() {
  test('standings: XP > 0, highest first, equal XP shares a position', () {
    final rows = standings(_members, PeriodKind.week, '2026-W41');
    expect([for (final s in rows) (s.userId, s.position, s.xp)], [
      ('ayse', 1, 1420),
      ('burak', 2, 640),
      ('me', 2, 640),
      ('eda', 4, 100),
    ]);
  });

  test('standings for the previous week read the prev_week field', () {
    final rows = standings(_members, PeriodKind.week, '2026-W40');
    expect([for (final s in rows) (s.userId, s.position)], [('ayse', 1), ('burak', 1)]);
    expect(standings(_members, PeriodKind.month, '2026-10'), isEmpty);
  });

  test('titles: XP first then muscle order; all holders on a tie; zero values left out', () {
    final titles = periodTitles(_members, PeriodKind.week, '2026-W41');
    expect([for (final t in titles) (t.category, t.holders.join(','), t.value)], [
      ('xp', 'ayse', 1420.0),
      ('chest', 'ayse', 9.0),
      ('lats', 'ayse,burak', 14.5),
    ]);
  });

  test('previous week titles', () {
    final titles = periodTitles(_members, PeriodKind.week, '2026-W40');
    expect([for (final t in titles) (t.category, t.holders.join(','))], [
      ('xp', 'ayse,burak'),
      ('chest', 'burak'),
    ]);
    expect(periodTitles(const {}, PeriodKind.week, '2026-W40'), isEmpty);
  });

  test('categories are XP plus the 17 muscle groups', () {
    expect(periodCategories.first, 'xp');
    expect(periodCategories, hasLength(18));
  });
}
