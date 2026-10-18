import 'dart:math' as math;

import 'levels.dart';

/// Rütbe bekçileri ve sonsuz boss (O2a spec §3).
class Monster {
  const Monster(this.id, this.weakMuscles);

  final String id;

  /// `muscleGroups` değerleri; ana kası bunlardan biri olan setler kritik vurur.
  final List<String> weakMuscles;

  String get nameKey => 'gamification.battle.monster.$id';

  /// Foto-gerçekçi portre; dosya yoksa arayüz yer tutucu çizer.
  String get imageAsset => 'assets/monsters/$id.png';
}

/// Index `i` (0…14) `Rank.values[i + 1]`'in bekçisi; 15 sonsuz boss.
const monsters = <Monster>[
  Monster('mud_goblin', ['chest', 'quadriceps']),
  Monster('rat_king', ['lats', 'hamstrings']),
  Monster('skeleton_guard', ['shoulders', 'glutes']),
  Monster('shadow_wolf', ['biceps', 'calves']),
  Monster('orc_warrior', ['triceps', 'abdominals']),
  Monster('stone_golem', ['middle back', 'adductors']),
  Monster('bridge_troll', ['traps', 'abductors']),
  Monster('minotaur', ['lower back', 'forearms']),
  Monster('ash_wraith', ['chest', 'hamstrings']),
  Monster('basilisk', ['quadriceps', 'lats']),
  Monster('cyclops', ['shoulders', 'calves']),
  Monster('hydra', ['glutes', 'biceps']),
  Monster('lich', ['abdominals', 'middle back']),
  Monster('behemoth', ['triceps', 'adductors']),
  Monster('crimson_dragon', ['traps', 'lower back']),
  Monster('ancient_titan', ['forearms', 'abductors']),
];

const endlessIndex = 15;
const monsterHpFactor = 1.2;
const endlessFromLevel = 100;
const endlessToLevel = 110;

/// Index ≥ [endlessIndex] her zaman sonsuz boss.
Monster monsterAt(int index) => monsters[math.min(index, endlessIndex)];

/// Bekçi: rütbe aralığındaki XP × 1,2; sonsuz boss: seviye 100–109. 10'a yuvarlı.
int monsterHp(int index) {
  final (from, to) = index >= endlessIndex
      ? (endlessFromLevel, endlessToLevel)
      : (Rank.values[index].minLevel, Rank.values[index + 1].minLevel);
  var span = 0;
  for (var level = from; level < to; level++) {
    span += xpForNext(level);
  }
  return (span * monsterHpFactor / 10).round() * 10;
}

/// Bekçisi olduğu rütbe; sonsuz boss için null.
Rank? guardedRank(int index) => index >= endlessIndex ? null : Rank.values[index + 1];

/// Görsel aşama (1–4); sonsuz boss 4.
int monsterTier(int index) => guardedRank(index)?.tier ?? 4;
