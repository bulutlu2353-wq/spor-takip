import 'package:flutter_test/flutter_test.dart';
import 'package:spor_takip/features/gamification/domain/battle.dart';
import 'package:spor_takip/features/gamification/domain/battle_stats.dart';
import 'package:spor_takip/features/gamification/domain/levels.dart';
import 'package:spor_takip/features/gamification/domain/xp_rules.dart';

// Boş geçmişte statlar 1/1/1 → bonus 0,005; XP'ler kayan nokta yuvarlamasından uzak seçildi.
const _inputs = StatInputs(verdicts: [], weeklyGoal: 3);

XpEvent _workout(DateTime at, int xp, {int sets = 0, Map<String, int> muscles = const {}}) =>
    XpEvent(source: XpSource.workout, date: at, xp: xp, sets: sets, muscleSets: muscles);

XpEvent _meal(DateTime at, int xp) => XpEvent(source: XpSource.mealDay, date: at, xp: xp);

XpEvent _reward(DateTime at, int xp) => XpEvent(source: XpSource.challenge, date: at, xp: xp);

void main() {
  test('no events: the first monster at full hp', () {
    final state = battle(const [], _inputs, today: DateTime(2026, 10, 18));
    expect((state.index, state.damage, state.hpLeft, state.monster.id), (0, 0, 660, 'mud_goblin'));
    expect(state.recent, isEmpty);
    expect((state.healing, state.healed), (false, 0));
    expect(state.stats.bonus, closeTo(0.005, 1e-9));
  });

  test('every XP source deals xp × (1 + bonus)', () {
    final state = battle([_meal(DateTime(2026, 10, 1), 10), _reward(DateTime(2026, 10, 2), 200)], _inputs,
        today: DateTime(2026, 10, 2));
    expect(state.damage, 10 + 201);
    expect(state.recent.map((h) => h.source), [XpSource.challenge, XpSource.mealDay]); // yeniden eskiye
  });

  test('sets on the weak muscles crit ×1.5 by their share', () {
    final state = battle([
      _workout(DateTime(2026, 10, 1, 18), 100, sets: 10, muscles: {'chest': 4, 'triceps': 6}),
    ], _inputs, today: DateTime(2026, 10, 1, 20));
    // 100 × 1,005 × (1 + 0,5 × 0,4) = 120,6 → 121.
    expect(state.damage, 121);
    expect(state.recent.single.critShare, closeTo(0.4, 1e-9));
  });

  test('overflow carries on and one event can beat several monsters', () {
    final state = battle([_reward(DateTime(2026, 10, 1), 2200)], _inputs, today: DateTime(2026, 10, 1));
    // 2211 − 660 − 1500 = 51.
    expect((state.index, state.damage, state.guardiansBeaten), (2, 51, 2));
    expect(state.recent.single.defeated, [0, 1]);
    expect(state.recent.single.monsterIndex, 0);
  });

  group('healing', () {
    final events = [_workout(DateTime(2026, 10, 1, 18), 200)]; // 201 hasar

    test('starts on the 8th idle day at 3% of hp per day', () {
      final day7 = battle(events, _inputs, today: DateTime(2026, 10, 8));
      expect((day7.damage, day7.healing), (201, false));
      final day8 = battle(events, _inputs, today: DateTime(2026, 10, 9));
      expect((day8.damage, day8.healed, day8.healing), (181, 20, true));
    });

    test('stops at full hp', () {
      final state = battle(events, _inputs, today: DateTime(2026, 10, 30));
      expect((state.damage, state.healed), (0, 201));
    });

    test('never brings back a beaten monster', () {
      // 800 → 804: goblin yenildi, sıçan kralına 144; günde 45 iyileşir.
      final state = battle([_workout(DateTime(2026, 10, 1, 18), 800)], _inputs, today: DateTime(2026, 10, 12));
      expect((state.index, state.damage, state.healed), (1, 0, 144));
    });

    test('meals do not stop it, a workout resets it', () {
      final state = battle([
        ...events,
        _meal(DateTime(2026, 10, 12), 10), // önce 9–12 Ekim: 4 × 20 iyileşme → 121, sonra +10
        _workout(DateTime(2026, 10, 13, 18), 200), // +201
      ], _inputs, today: DateTime(2026, 10, 20));
      expect((state.damage, state.healed, state.healing), (332, 80, false));
    });
  });

  test('the endless boss keeps coming back', () {
    // 300000 × 1,005 = 301500; bekçiler 157410 → kalan 144090 = 4 × 32250 + 15090.
    final state = battle([_reward(DateTime(2026, 10, 1), 300000)], _inputs, today: DateTime(2026, 10, 1));
    expect((state.guardiansBeaten, state.bossKills, state.damage), (15, 4, 15090));
    expect(state.monster.id, 'ancient_titan');
  });

  test('zero-XP events deal no hit; recent keeps the last ten, newest first', () {
    final state = battle([
      XpEvent(source: XpSource.workout, date: DateTime(2026, 9, 1), xp: 0),
      for (var i = 0; i < 12; i++) _meal(DateTime(2026, 9, 2 + i), 10),
    ], _inputs, today: DateTime(2026, 9, 14));
    expect(state.recent, hasLength(10));
    expect(state.recent.first.date, DateTime(2026, 9, 13));
    expect(state.damage, 120);
  });

  test('gatedRank needs both the level and the guardian', () {
    final none = battle(const [], _inputs, today: DateTime(2026, 10, 1));
    final two = battle([_reward(DateTime(2026, 10, 1), 2200)], _inputs, today: DateTime(2026, 10, 1));
    expect(gatedRank(12, none), Rank.rookie);
    expect(gatedRank(12, two), Rank.amateur);
    expect(gatedRank(7, two), Rank.novice);
    expect(gatedRank(12, null), Rank.amateur);
  });
}
