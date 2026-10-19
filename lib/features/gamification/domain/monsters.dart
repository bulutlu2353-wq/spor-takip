import 'dart:math' as math;

import 'levels.dart';

/// Rütbe bekçileri ve sonsuz boss (O2a spec §3).
class Monster {
  const Monster(this.id, this.weakMuscles, {this.zoom = 1.0, this.focus = (0.0, 0.0)});

  final String id;

  /// `muscleGroups` değerleri; ana kası bunlardan biri olan setler kritik vurur.
  final List<String> weakMuscles;

  /// Daire portrede büyütme (≥ 1) ve büyütülen görselin görünen kısmı, `Alignment(x, y)`
  /// anlamında (O2 cila spec §3).
  final double zoom;
  final (double, double) focus;

  String get nameKey => 'gamification.battle.monster.$id';

  /// Foto-gerçekçi portre; dosya yoksa arayüz yer tutucu çizer.
  String get imageAsset => 'assets/monsters/$id.jpg';
}

/// Index `i` (0…14) `Rank.values[i + 1]`'in bekçisi; 15 sonsuz boss.
const monsters = <Monster>[
  Monster('mud_goblin', ['chest', 'quadriceps'], zoom: 1.25, focus: (0.0, -0.3)),
  Monster('rat_king', ['lats', 'hamstrings'], zoom: 1.15, focus: (0.0, -0.1)),
  Monster('skeleton_guard', ['shoulders', 'glutes'], zoom: 1.25, focus: (0.0, -0.3)),
  Monster('shadow_wolf', ['biceps', 'calves'], zoom: 1.2, focus: (0.0, -0.3)),
  Monster('orc_warrior', ['triceps', 'abdominals'], zoom: 1.3, focus: (0.0, -0.4)),
  Monster('stone_golem', ['middle back', 'adductors'], zoom: 1.15, focus: (0.0, -0.5)),
  Monster('bridge_troll', ['traps', 'abductors'], zoom: 1.25, focus: (0.2, -0.3)),
  Monster('minotaur', ['lower back', 'forearms'], zoom: 1.1, focus: (0.0, -0.3)),
  Monster('ash_wraith', ['chest', 'hamstrings'], zoom: 1.25, focus: (0.0, -0.4)),
  Monster('basilisk', ['quadriceps', 'lats'], zoom: 1.15, focus: (0.0, -0.3)),
  Monster('cyclops', ['shoulders', 'calves'], zoom: 1.3, focus: (0.0, -0.3)),
  Monster('hydra', ['glutes', 'biceps']),
  Monster('lich', ['abdominals', 'middle back'], zoom: 1.25, focus: (0.0, -0.5)),
  Monster('behemoth', ['triceps', 'adductors']),
  Monster('crimson_dragon', ['traps', 'lower back'], zoom: 1.1, focus: (0.0, -0.2)),
  Monster('ancient_titan', ['forearms', 'abductors'], zoom: 1.3, focus: (0.0, -0.4)),
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
