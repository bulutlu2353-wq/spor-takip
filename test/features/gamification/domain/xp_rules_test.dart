import 'package:flutter_test/flutter_test.dart';
import 'package:spor_takip/features/gamification/domain/xp_rules.dart';

import '../game_fixtures.dart';

void main() {
  test('a finished workout gives 50 plus 5 per completed set', () {
    final events = xpEvents([
      gameSession('a', DateTime(2026, 10, 1, 18), [...gameSets('bench', 3), gameSet('bench', done: false)]),
    ], const []);
    expect(events, hasLength(1));
    expect(events.single.source, XpSource.workout);
    expect(events.single.xp, 65);
    expect(events.single.sets, 3);
    expect(events.single.label, 'Push A');
    expect(events.single.date, DateTime(2026, 10, 1, 18));
  });

  test('set XP stops at 30 sets', () {
    final events = xpEvents([gameSession('a', DateTime(2026, 10, 1), gameSets('bench', 40))], const []);
    expect(events.single.xp, 200);
    expect(events.single.sets, 30);
  });

  test('sessions without completed sets and unfinished sessions give nothing', () {
    final events = xpEvents([
      gameSession('empty', DateTime(2026, 10, 1), [gameSet('bench', done: false)]),
      gameSession('live', null, gameSets('bench', 5)),
    ], const []);
    expect(events, isEmpty);
  });

  test('a record needs to beat the best of earlier sessions, once per exercise', () {
    final events = xpEvents([
      // İlk yapılış: 100×5 ≈ 116.7 — rekor değil.
      gameSession('s1', DateTime(2026, 10, 1), [gameSet('bench', kg: 100, reps: 5)]),
      // 100×6 = 120 ve 100×7 ≈ 123.3 → tek rekor, en iyi set; squat ilk kez → rekor değil.
      gameSession('s2', DateTime(2026, 10, 3), [
        gameSet('bench', kg: 100, reps: 6),
        gameSet('bench', kg: 100, reps: 7, index: 1),
        gameSet('squat', kg: 140, reps: 3),
      ]),
      // 100×5 önceki en iyiyi geçmez.
      gameSession('s3', DateTime(2026, 10, 5), [gameSet('bench', kg: 100, reps: 5)]),
    ], const []);
    final records = [for (final e in events) if (e.source == XpSource.record) e];
    expect(records, hasLength(1));
    expect(records.single.xp, 25);
    expect(records.single.label, 'Barbell Bench Press');
    expect(records.single.weightKg, 100);
    expect(records.single.reps, 7);
    expect(records.single.date, DateTime(2026, 10, 3));
  });

  test('sets over ten reps never count as the earlier best', () {
    final events = xpEvents([
      gameSession('s1', DateTime(2026, 10, 1), [gameSet('bench', kg: 60, reps: 12)]),
      gameSession('s2', DateTime(2026, 10, 2), [gameSet('bench', kg: 60, reps: 5)]),
    ], const []);
    expect(events.where((e) => e.source == XpSource.record), isEmpty);
  });

  test('meal days count once per local day and sort with workouts by time', () {
    final events = xpEvents(
      [gameSession('a', DateTime(2026, 10, 1, 18), gameSets('bench', 1))],
      [DateTime(2026, 10, 1, 8), DateTime(2026, 10, 1, 20), DateTime(2026, 10, 2, 9)],
    );
    expect([for (final e in events) (e.source, e.date)], [
      (XpSource.mealDay, DateTime(2026, 10, 1)),
      (XpSource.workout, DateTime(2026, 10, 1, 18)),
      (XpSource.mealDay, DateTime(2026, 10, 2)),
    ]);
    expect(events.first.xp, 10);
  });

  test('the breakdown splits workout XP into base and sets', () {
    final events = xpEvents([
      gameSession('s1', DateTime(2026, 10, 1), [gameSet('bench', kg: 100, reps: 5)]),
      gameSession('s2', DateTime(2026, 10, 2), [...gameSets('bench', 3, kg: 100, reps: 8)]),
    ], [DateTime(2026, 10, 1, 12)]);
    final breakdown = xpBreakdown(events);
    expect(breakdown.workouts, 100);
    expect(breakdown.sets, 20);
    expect(breakdown.records, 25);
    expect(breakdown.mealDays, 10);
    expect(breakdown.total, 155);
  });
}
