import 'package:flutter_test/flutter_test.dart';
import 'package:spor_takip/features/gamification/domain/battle.dart';
import 'package:spor_takip/features/gamification/domain/battle_stats.dart';
import 'package:spor_takip/features/gamification/domain/xp_rules.dart';

BattleHit _hit(int day, int damage, {double crit = 0, List<int> defeated = const []}) => BattleHit(
      date: DateTime(2026, 10, day, 18),
      source: XpSource.workout,
      xp: damage,
      damage: damage,
      critShare: crit,
      monsterIndex: 0,
      defeated: defeated,
    );

void main() {
  // recent yeniden eskiye.
  final state = BattleState(
    index: 0,
    damage: 300,
    stats: BattleStats.floor,
    recent: [_hit(7, 200), _hit(6, 100), _hit(5, 50)],
  );

  test('unseenHits: null means first open, equal date is seen, newer ones come oldest first', () {
    expect(unseenHits(state, null), isEmpty);
    expect(unseenHits(state, DateTime(2026, 10, 7, 18)), isEmpty);
    expect(unseenHits(state, DateTime(2026, 10, 5, 18)).map((h) => h.damage), [100, 200]);
  });

  test('hitReplay without a kill: total damage, crit flag and hp before', () {
    final r = hitReplay(state, [_hit(6, 100), _hit(7, 200, crit: 0.3)]);
    expect(r.damage, 300);
    expect(r.crit, isTrue);
    expect(r.defeated, isNull);
    expect(r.fromHpLeft, 1.0); // 300 − 300 = 0 hasar önce
    final small = hitReplay(state, [_hit(7, 200)]);
    expect(small.crit, isFalse);
    expect(small.fromHpLeft, closeTo((state.hp - 100) / state.hp, 1e-9));
  });

  test('hitReplay with kills: the last defeated monster, bar starts full', () {
    const after = BattleState(index: 2, damage: 40, stats: BattleStats.floor);
    final r = hitReplay(after, [_hit(6, 900, defeated: [0]), _hit(7, 900, defeated: [1])]);
    expect(r.defeated, 1);
    expect(r.fromHpLeft, 1.0);
  });
}
