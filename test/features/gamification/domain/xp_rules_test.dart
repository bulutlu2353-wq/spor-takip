import 'package:flutter_test/flutter_test.dart';
import 'package:spor_takip/features/gamification/domain/fair_play.dart';
import 'package:spor_takip/features/gamification/domain/xp_rules.dart';
import 'package:spor_takip/features/workout/domain/workout_session.dart';

import '../game_fixtures.dart';

void main() {
  List<XpEvent> records(List<XpEvent> events) => [
        for (final e in events)
          if (e.source == XpSource.record) e,
      ];
  WorkoutSession bench(String id, DateTime at, double kg) => gameSession(id, at, gameSets('bench', 3, kg: kg, reps: 5));

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

  test('the breakdown splits workout XP into base and sets and skips 0 XP workouts', () {
    final events = xpEvents([
      gameSession('s1', DateTime(2026, 10, 1), [gameSet('bench', kg: 100, reps: 5)]),
      gameSession('s2', DateTime(2026, 10, 2), [...gameSets('bench', 3, kg: 100, reps: 8)]),
    ], [DateTime(2026, 10, 1, 12)]);
    final breakdown = xpBreakdown(events);
    expect(breakdown.workouts, 50);
    expect(breakdown.sets, 15);
    expect(breakdown.records, 25);
    expect(breakdown.mealDays, 10);
    expect(breakdown.total, 100);
  });

  test('the breakdown counts challenge rewards separately', () {
    final breakdown = xpBreakdown([
      XpEvent(source: XpSource.workout, date: DateTime(2026, 10, 1), xp: 60, sets: 2),
      XpEvent(source: XpSource.challenge, date: DateTime(2026, 10, 2), xp: 100, label: 'x'),
      XpEvent(source: XpSource.challenge, date: DateTime(2026, 10, 3), xp: 50, label: 'y'),
    ]);
    expect(breakdown.challenges, 150);
    expect(breakdown.total, 210);
  });

  test('a skipped session gives a 0 XP workout event with its reason', () {
    final events = xpEvents([gameSession('a', DateTime(2026, 10, 1, 18), gameSets('bench', 2))], const []);
    expect((events.single.xp, events.single.sets, events.single.skip), (0, 0, SkipReason.tooSmall));
  });

  test('counted sets follow the session time cap', () {
    final events = xpEvents([
      gameSession('a', DateTime(2026, 10, 1, 18), gameSets('bench', 20), duration: const Duration(minutes: 24)),
    ], const []);
    expect((events.single.xp, events.single.sets, events.single.skip), (110, 12, null));
  });

  test('a record needs a 2.5% gain; smaller gains still raise the best', () {
    final events = xpEvents([
      bench('s1', DateTime(2026, 10, 1, 18), 100),
      bench('s2', DateTime(2026, 10, 10, 18), 102), // +%2 → yok, taban 102
      bench('s3', DateTime(2026, 10, 20, 18), 104), // 102'ye göre +%1,96 → yok, taban 104
      bench('s4', DateTime(2026, 10, 30, 18), 107), // 104'e göre +%2,9 → rekor
    ], const []);
    expect([for (final r in records(events)) (r.date, r.weightKg)], [(DateTime(2026, 10, 30, 18), 107.0)]);
  });

  test('a jump over 50% gives no XP but becomes the new best', () {
    final events = xpEvents([
      bench('s1', DateTime(2026, 10, 1, 18), 20),
      bench('s2', DateTime(2026, 10, 10, 18), 60), // +%200 → yok, taban 60
      bench('s3', DateTime(2026, 10, 20, 18), 62), // +%3,3 → rekor
    ], const []);
    expect([for (final r in records(events)) r.weightKg], [62.0]);
  });

  test('the same exercise earns a record at most once in seven days', () {
    final events = xpEvents([
      bench('s1', DateTime(2026, 10, 1, 18), 100),
      bench('s2', DateTime(2026, 10, 2, 18), 105), // rekor
      bench('s3', DateTime(2026, 10, 7, 18), 110), // 5 gün → XP yok, taban 110
      bench('s4', DateTime(2026, 10, 9, 18), 115), // 7 gün → rekor (110'a göre +%4,5)
    ], const []);
    expect([for (final r in records(events)) r.date], [DateTime(2026, 10, 2, 18), DateTime(2026, 10, 9, 18)]);
  });

  test('one session gives at most three records, the biggest gains first', () {
    final events = xpEvents([
      gameSession('s1', DateTime(2026, 10, 1, 18), [
        for (final (i, id) in ['bench', 'squat', 'row', 'press'].indexed) gameSet(id, kg: 100, reps: 5, index: i),
      ]),
      gameSession('s2', DateTime(2026, 10, 10, 18), [
        gameSet('bench', kg: 110, reps: 5), // +%10
        gameSet('squat', kg: 104, reps: 5, index: 1), // +%4
        gameSet('row', kg: 120, reps: 5, index: 2), // +%20
        gameSet('press', kg: 103, reps: 5, index: 3), // +%3 → dışarıda
      ]),
    ], const []);
    expect({for (final r in records(events)) r.weightKg}, {120.0, 110.0, 104.0});
  });

  test('a record in a skipped session gives no XP but raises the best', () {
    final events = xpEvents([
      bench('s1', DateTime(2026, 10, 1, 18), 100),
      gameSession('s2', DateTime(2026, 10, 10, 18), [gameSet('bench', kg: 110, reps: 5)]), // tek set → sayılmaz
      bench('s3', DateTime(2026, 10, 20, 18), 112), // 110'a göre +%1,8 → yok
    ], const []);
    expect(records(events), isEmpty);
  });
}
