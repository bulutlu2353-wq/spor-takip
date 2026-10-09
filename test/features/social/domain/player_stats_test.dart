import 'package:flutter_test/flutter_test.dart';
import 'package:spor_takip/features/gamification/domain/levels.dart';
import 'package:spor_takip/features/gamification/domain/player_summary.dart';
import 'package:spor_takip/features/gamification/domain/titles.dart';
import 'package:spor_takip/features/gamification/domain/xp_rules.dart';
import 'package:spor_takip/features/social/domain/player_stats.dart';
import 'package:spor_takip/features/workout/domain/muscle_heat.dart';

import '../../gamification/game_fixtures.dart';

// Cuma; hafta pazartesi 5 Ekim'de başlar.
final _now = DateTime(2026, 10, 9, 12);

final _sessions = [
  gameSession('sun', DateTime(2026, 10, 4, 23, 59), gameSets('bench', 2, kg: 100, reps: 5), workoutName: 'Push A'),
  gameSession('mon', DateTime(2026, 10, 5), gameSets('bench', 3, kg: 100, reps: 6), workoutName: 'Push B'),
  gameSession('wed', DateTime(2026, 10, 7, 18), gameSets('squat', 4), workoutName: 'Legs'),
  gameSession('empty', DateTime(2026, 10, 8), [gameSet('bench', done: false)], workoutName: 'Empty'),
  gameSession('live', null, gameSets('bench', 5)),
];

final _meals = [
  DateTime(2026, 10, 4, 20),
  DateTime(2026, 10, 6, 8),
  DateTime(2026, 10, 6, 13),
  DateTime(2026, 10, 8, 9),
];

PlayerStats _build({SharedPrivacy privacy = const SharedPrivacy(), String? active, PlayerSummary? summary}) =>
    buildPlayerStats(
      summary: summary ?? playerSummary(_sessions, _meals, gameExercisesById),
      sessions: _sessions,
      mealTimes: _meals,
      exercisesById: gameExercisesById,
      now: _now,
      activeTitleId: active,
      privacy: privacy,
    );

PlayerSummary _summaryWithTitles(int count) => PlayerSummary(
      totalXp: 0,
      progress: levelFor(0),
      rank: Rank.rookie,
      breakdown: const XpBreakdown(),
      recent: const [],
      titles: [
        for (var i = 0; i < count; i++)
          TitleProgress(kind: TitleKind.exercise, subjectId: 'e$i', value: 12, exerciseName: 'Ex $i'),
      ],
      upcoming: const [],
    );

void main() {
  test('level, XP and rank come from the summary', () {
    final summary = playerSummary(_sessions, _meals, gameExercisesById);
    final stats = _build();
    expect((stats.level, stats.totalXp, stats.rank), (summary.progress.level, summary.totalXp, summary.rank));
  });

  test('the week starts on Monday and counts workouts with sets, sets and meal days', () {
    final weekly = _build().weekly!;
    expect((weekly.workouts, weekly.sets, weekly.mealDays), (2, 7, 2));
  });

  test('recent workouts are the last five with sets, newest first, with their records', () {
    final recent = _build().recent!;
    expect([for (final r in recent) r.name], ['Legs', 'Push B', 'Push A']);
    expect(recent[1].sets, 3);
    expect(recent[1].date, DateTime(2026, 10, 5));
    expect([for (final r in recent[1].records) (r.name, r.weightKg, r.reps)], [('Barbell Bench Press', 100.0, 6)]);
    expect(recent[0].records, isEmpty);
  });

  test('heat covers the last seven days', () {
    expect(_build().heat, {
      'chest': HeatTier.medium,
      'triceps': HeatTier.low,
      'quadriceps': HeatTier.medium,
    });
  });

  test('closed sections are left out', () {
    final stats = _build(privacy: const SharedPrivacy(weekly: false, workouts: false, heat: false));
    expect(stats.weekly, isNull);
    expect(stats.recent, isNull);
    expect(stats.heat, isNull);
    final onlyHeat = _build(privacy: const SharedPrivacy(heat: false));
    expect(onlyHeat.weekly, isNotNull);
    expect(onlyHeat.heat, isNull);
  });

  test('at most ten titles and the equipped one if still earned', () {
    final stats = _build(summary: _summaryWithTitles(12), active: 'exercise:e3');
    expect(stats.titles, hasLength(10));
    expect(stats.titles.first.subjectId, 'e0');
    expect(stats.activeTitle?.subjectId, 'e3');
    expect(stats.activeTitle?.tier, TitleTier.apprentice);
    expect(_build(summary: _summaryWithTitles(2), active: 'muscle:neck').activeTitle, isNull);
  });

  test('json round trip keeps everything and equality ignores the update time', () {
    final stats = _build(summary: _summaryWithTitles(2), active: 'exercise:e1');
    final json = stats.toJson();
    expect(json.containsKey('updated_at'), isFalse);
    final back = PlayerStats.fromJson({...json, 'updated_at': '2026-10-09T09:00:00Z'});
    expect(back, stats);
    expect(back.updatedAt, DateTime.utc(2026, 10, 9, 9).toLocal());
    expect(back.recent![1].records.single.weightKg, 100);
    expect(back.titles.first.asProgress.exerciseName, 'Ex 0');
  });

  test('heat order and unknown values do not break equality or parsing', () {
    final a = PlayerStats.fromJson({
      'level': 2,
      'total_xp': 150,
      'rank': 'mystery',
      'titles': [
        {'kind': 'muscle', 'subject_id': 'chest', 'tier': 'master'},
        {'kind': 'alien', 'subject_id': 'x', 'tier': 'master'},
      ],
      'heat': {'quadriceps': 'low', 'chest': 'high', 'calves': 'nuclear'},
    });
    final b = PlayerStats.fromJson({
      'level': 2,
      'total_xp': 150,
      'rank': 'rookie',
      'titles': [
        {'kind': 'muscle', 'subject_id': 'chest', 'tier': 'master'},
      ],
      'heat': {'chest': 'high', 'quadriceps': 'low'},
    });
    expect(a.rank, Rank.rookie);
    expect(a.titles, hasLength(1));
    expect(a.heat, {'quadriceps': HeatTier.low, 'chest': HeatTier.high});
    expect(a, b);
    expect(a.hashCode, b.hashCode);
    expect(a.weekly, isNull);
    expect(a.recent, isNull);
  });
}
