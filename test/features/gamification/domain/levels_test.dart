import 'package:flutter_test/flutter_test.dart';
import 'package:spor_takip/features/gamification/domain/levels.dart';

void main() {
  test('each level costs 25 XP more than the last', () {
    expect(xpForNext(1), 100);
    expect(xpForNext(2), 125);
    expect(xpForNext(10), 325);
  });

  test('levelFor walks the curve', () {
    LevelProgress p(int xp) => levelFor(xp);
    expect((p(0).level, p(0).xpIntoLevel, p(0).xpNeeded), (1, 0, 100));
    expect((p(99).level, p(99).xpIntoLevel), (1, 99));
    expect((p(100).level, p(100).xpIntoLevel, p(100).xpNeeded), (2, 0, 125));
    expect((p(224).level, p(224).xpIntoLevel), (2, 124));
    expect((p(225).level, p(225).xpIntoLevel, p(225).xpNeeded), (3, 0, 150));
    expect(p(-5).level, 1);
    expect(p(50).fraction, 0.5);
  });

  test('ranks follow their minimum levels', () {
    expect(rankFor(1), Rank.rookie);
    expect(rankFor(4), Rank.rookie);
    expect(rankFor(5), Rank.novice);
    expect(rankFor(34), Rank.determined);
    expect(rankFor(35), Rank.warrior);
    expect(rankFor(99), Rank.legend);
    expect(rankFor(100), Rank.immortal);
    expect(rankFor(150), Rank.immortal);
  });

  test('sixteen ranks in four tiers of four stripes', () {
    expect(Rank.values, hasLength(16));
    expect((Rank.rookie.tier, Rank.rookie.stripes), (1, 1));
    expect((Rank.warrior.tier, Rank.warrior.stripes), (2, 4));
    expect((Rank.gladiator.tier, Rank.gladiator.stripes), (3, 1));
    expect((Rank.immortal.tier, Rank.immortal.stripes), (4, 4));
    expect(Rank.elite.minLevel, 60);
    expect(Rank.titan.labelKey, 'gamification.rank.titan');
  });
}
