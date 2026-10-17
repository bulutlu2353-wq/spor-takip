import 'package:flutter_test/flutter_test.dart';
import 'package:spor_takip/features/gamification/domain/fair_play.dart';

import '../game_fixtures.dart';

void main() {
  test('unfinished sessions and sessions without completed sets are left out', () {
    expect(
      judgeSessions([
        gameSession('live', null, gameSets('bench', 5)),
        gameSession('empty', DateTime(2026, 10, 1), [gameSet('bench', done: false)]),
      ]),
      isEmpty,
    );
  });

  test('a session needs three completed sets and ten minutes', () {
    final verdicts = judgeSessions([
      gameSession('two', DateTime(2026, 10, 1, 9), gameSets('bench', 2)),
      gameSession('short', DateTime(2026, 10, 2, 9), gameSets('bench', 5), duration: const Duration(minutes: 9)),
      gameSession('ok', DateTime(2026, 10, 3, 9), gameSets('bench', 3), duration: const Duration(minutes: 10)),
      gameSession('backwards', DateTime(2026, 10, 4, 9), gameSets('bench', 5), duration: const Duration(minutes: -30)),
    ]);
    expect([for (final v in verdicts) (v.session.id, v.skip)], [
      ('two', SkipReason.tooSmall),
      ('short', SkipReason.tooSmall),
      ('ok', null),
      ('backwards', SkipReason.tooSmall),
    ]);
    expect(verdicts[2].counted, isTrue);
    expect(verdicts[2].countedSets, hasLength(3));
    expect(verdicts[2].finishedAt, DateTime(2026, 10, 3, 9));
    expect(verdicts.first.countedSets, isEmpty);
    expect(verdicts.first.plausibleSets, hasLength(2));
  });

  test('only the first two eligible sessions of a local day count; small ones do not use the limit', () {
    final verdicts = judgeSessions([
      gameSession('c', DateTime(2026, 10, 1, 20), gameSets('bench', 3)),
      gameSession('a', DateTime(2026, 10, 1, 8), gameSets('bench', 3)),
      gameSession('small', DateTime(2026, 10, 1, 10), gameSets('bench', 1)),
      gameSession('b', DateTime(2026, 10, 1, 14), gameSets('bench', 3)),
      gameSession('next', DateTime(2026, 10, 2, 8), gameSets('bench', 3)),
    ]);
    expect([for (final v in verdicts) (v.session.id, v.skip)], [
      ('a', null),
      ('small', SkipReason.tooSmall),
      ('b', null),
      ('c', SkipReason.dailyLimit),
      ('next', null),
    ]);
    expect(verdicts[3].countedSets, isEmpty);
  });

  test('counted sets are capped at one per two minutes and at thirty, in completion order', () {
    final early = DateTime(2026, 10, 1, 9);
    final verdicts = judgeSessions([
      gameSession(
        'a',
        DateTime(2026, 10, 1, 10),
        [for (var i = 0; i < 20; i++) gameSet('bench', index: i, at: early.add(Duration(minutes: 20 - i)))],
        duration: const Duration(minutes: 24),
      ),
      gameSession('b', DateTime(2026, 10, 2, 10), gameSets('bench', 40), duration: const Duration(hours: 2)),
    ]);
    expect(verdicts[0].countedSets, hasLength(12));
    // En büyük index'li set en erken tamamlandı.
    expect(verdicts[0].countedSets.first.setIndex, 19);
    expect(verdicts[0].countedSets.last.setIndex, 8);
    expect(verdicts[1].countedSets, hasLength(30));
  });

  test('sets over 500 kg are not plausible and do not make a session eligible', () {
    expect(isPlausibleSet(gameSet('squat', kg: 400, reps: 8)), isFalse); // ≈ 506.7
    expect(isPlausibleSet(gameSet('squat', kg: 600, reps: 12)), isFalse); // tahmin yok, kilo 500 üstü
    expect(isPlausibleSet(gameSet('squat', kg: 300, reps: 10)), isTrue); // 400
    expect(isPlausibleSet(gameSet('squat')), isTrue); // kilosuz
    final verdict = judgeSessions([
      gameSession('a', DateTime(2026, 10, 1), [
        ...gameSets('squat', 2, kg: 100, reps: 5),
        gameSet('squat', kg: 900, reps: 1, index: 5),
      ]),
    ]).single;
    expect(verdict.skip, SkipReason.tooSmall);
    expect(verdict.plausibleSets, hasLength(2));
  });
}
