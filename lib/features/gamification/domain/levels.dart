import 'dart:math' as math;

/// n → n+1 için gereken XP (O1 spec §4).
int xpForNext(int level) => 100 + 25 * (level - 1);

class LevelProgress {
  const LevelProgress({required this.level, required this.xpIntoLevel, required this.xpNeeded});

  final int level;

  /// Bu seviyede kazanılan XP.
  final int xpIntoLevel;

  /// Bu seviyeden sonrakine gereken XP.
  final int xpNeeded;

  double get fraction => xpIntoLevel / xpNeeded;
}

LevelProgress levelFor(int totalXp) {
  var level = 1;
  var remaining = math.max(totalXp, 0);
  while (remaining >= xpForNext(level)) {
    remaining -= xpForNext(level);
    level++;
  }
  return LevelProgress(level: level, xpIntoLevel: remaining, xpNeeded: xpForNext(level));
}

/// 16 rütbe; dörtlü kademeler, kademe içinde 1–4 şerit.
enum Rank {
  rookie(1),
  novice(5),
  amateur(10),
  enthusiast(15),
  athlete(20),
  dedicated(25),
  determined(30),
  warrior(35),
  gladiator(40),
  iron(45),
  master(50),
  elite(60),
  champion(70),
  titan(80),
  legend(90),
  immortal(100);

  const Rank(this.minLevel);

  final int minLevel;

  int get tier => index ~/ 4 + 1;

  int get stripes => index % 4 + 1;

  String get labelKey => 'gamification.rank.$name';
}

/// `minLevel <= level` olan en yüksek rütbe.
Rank rankFor(int level) => Rank.values.lastWhere((r) => r.minLevel <= level, orElse: () => Rank.rookie);
