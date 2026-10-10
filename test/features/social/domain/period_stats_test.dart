import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:spor_takip/features/gamification/domain/levels.dart';
import 'package:spor_takip/features/gamification/domain/player_summary.dart';
import 'package:spor_takip/features/social/domain/period_keys.dart';
import 'package:spor_takip/features/social/domain/period_stats.dart';

import '../../gamification/game_fixtures.dart';

final _now = DateTime(2026, 10, 9, 12);

// W41 = 5–11 Ekim, W40 = 28 Eylül–4 Ekim.
final _sessions = [
  gameSession('a', DateTime(2026, 10, 8, 18), gameSets('bench', 3)), // W41: 65 XP
  gameSession('d', DateTime(2026, 10, 5), gameSets('squat', 1)), // W41 sınırı: 55 XP
  gameSession('b', DateTime(2026, 10, 4, 23, 59), gameSets('squat', 2)), // W40: 60 XP
  gameSession('c', DateTime(2026, 9, 20, 10), gameSets('bench', 1)), // Eylül: 55 XP
  gameSession('open', null, gameSets('bench', 4)), // bitmemiş: sayılmaz
];
final _meals = [DateTime(2026, 10, 9, 8)]; // W41: 10 XP

PeriodStats _build() => buildPeriodStats(
      summary: playerSummary(_sessions, _meals, gameExercisesById),
      sessions: _sessions,
      mealTimes: _meals,
      exercisesById: gameExercisesById,
      now: _now,
      activeTitleId: null,
    );

void main() {
  test('fills this and the previous week and month', () {
    final stats = _build();
    expect(stats.level, playerSummary(_sessions, _meals, gameExercisesById).progress.level);
    expect(stats.activeTitle, isNull);

    expect(stats.week.key, '2026-W41');
    expect(stats.week.xp, 130);
    expect(stats.week.muscles, {'chest': 3.0, 'triceps': 1.5, 'quadriceps': 1.0});

    expect(stats.prevWeek.key, '2026-W40');
    expect(stats.prevWeek.xp, 60);
    expect(stats.prevWeek.muscles, {'quadriceps': 2.0});

    expect(stats.month.key, '2026-10');
    expect(stats.month.xp, 190);
    expect(stats.month.muscles, {'chest': 3.0, 'triceps': 1.5, 'quadriceps': 3.0});

    expect(stats.prevMonth.key, '2026-09');
    expect(stats.prevMonth.xp, 55);
    expect(stats.prevMonth.muscles, {'chest': 1.0, 'triceps': 0.5});
  });

  test('slotFor matches either field of the kind and nothing else', () {
    final stats = _build();
    expect(stats.slotFor(PeriodKind.week, '2026-W40')?.xp, 60);
    expect(stats.slotFor(PeriodKind.week, '2026-W41')?.xp, 130);
    expect(stats.slotFor(PeriodKind.week, '2026-W39'), isNull);
    expect(stats.slotFor(PeriodKind.month, '2026-W41'), isNull);
    expect(stats.valueFor(PeriodKind.month, '2026-10', 'quadriceps'), 3);
    expect(stats.valueFor(PeriodKind.month, '2026-09', 'xp'), 55);
    expect(stats.valueFor(PeriodKind.week, '2026-W39', 'xp'), 0);
    expect(stats.valueFor(PeriodKind.week, '2026-W41', 'lats'), 0);
  });

  test('JSON round trip keeps equality; updatedAt is ignored; muscles are sorted', () {
    final stats = _build();
    final json = jsonDecode(jsonEncode(stats.toJson())) as Map<String, dynamic>;
    final back = PeriodStats.fromJson({...json, 'updated_at': '2026-10-09T09:00:00Z'});
    expect(back, stats);
    expect(back.hashCode, stats.hashCode);
    expect(back.updatedAt, isNotNull);
    final week = (json['periods'] as Map<String, dynamic>)['week'] as Map<String, dynamic>;
    expect((week['muscles'] as Map<String, dynamic>).keys.toList(), ['chest', 'quadriceps', 'triceps']);
  });

  test('missing fields fall back to defaults', () {
    final stats = PeriodStats.fromJson({'level': 2, 'rank': 'nope', 'periods': <String, dynamic>{}});
    expect(stats.level, 2);
    expect(stats.rank, Rank.rookie);
    expect(stats.week.key, '');
    expect(stats.prevMonth.xp, 0);
    expect(stats.slotFor(PeriodKind.week, '2026-W41'), isNull);
  });
}
