import 'package:flutter_test/flutter_test.dart';
import 'package:spor_takip/features/gamification/domain/levels.dart';
import 'package:spor_takip/features/gamification/domain/monsters.dart';
import 'package:spor_takip/features/workout/domain/exercise_taxonomy.dart';

void main() {
  test('16 monsters with unique ids', () {
    expect(monsters, hasLength(16));
    expect(monsters.map((m) => m.id).toSet(), hasLength(16));
    expect(monsters.first.nameKey, 'gamification.battle.monster.mud_goblin');
    expect(monsters.first.imageAsset, 'assets/monsters/mud_goblin.jpg');
  });

  test('each muscle group except the neck is a weak spot exactly twice', () {
    final counts = <String, int>{};
    for (final m in monsters) {
      expect(m.weakMuscles, hasLength(2));
      for (final muscle in m.weakMuscles) {
        expect(muscleGroups, contains(muscle));
        counts[muscle] = (counts[muscle] ?? 0) + 1;
      }
    }
    expect(counts.keys.toSet(), muscleGroups.where((m) => m != 'neck').toSet());
    expect(counts.values.toSet(), {2});
  });

  test('hp follows the level span × 1.2', () {
    expect([for (var i = 0; i < 16; i++) monsterHp(i)], [
      660, 1500, 2250, 3000, 3750, 4500, 5250, 6000, 6750, 7500, //
      17250, 20250, 23250, 26250, 29250, 32250,
    ]);
    expect(monsterHp(20), 32250);
  });

  test('guardians, the endless boss and tiers', () {
    expect(guardedRank(0), Rank.novice);
    expect(guardedRank(14), Rank.immortal);
    expect(guardedRank(15), isNull);
    expect(monsterAt(15).id, 'ancient_titan');
    expect(monsterAt(99).id, 'ancient_titan');
    expect([monsterTier(0), monsterTier(3), monsterTier(4), monsterTier(14), monsterTier(15)], [1, 2, 2, 4, 4]);
  });
}
