import 'dart:math' as math;

import 'battle_stats.dart';
import 'levels.dart';
import 'monsters.dart';
import 'streak.dart';
import 'xp_rules.dart';

/// Savaş kuralları (O2a spec §5).
const healGraceDays = 7;
const healPercent = 3;
const critExtra = 0.5;
const recentHitCount = 10;

class BattleHit {
  const BattleHit({
    required this.date,
    required this.source,
    required this.xp,
    required this.damage,
    required this.critShare,
    required this.monsterIndex,
    this.defeated = const [],
  });

  final DateTime date;
  final XpSource source;
  final int xp;
  final int damage;

  /// 0–1: zayıf kasa düşen sayılan set payı.
  final double critShare;

  /// Vuruşun başladığı canavar.
  final int monsterIndex;

  /// Bu vuruşla yenilen canavarlar.
  final List<int> defeated;
}

class BattleState {
  const BattleState({
    required this.index,
    required this.damage,
    required this.stats,
    this.recent = const [],
    this.healed = 0,
    this.healing = false,
  });

  /// Aktif canavar; ≥ [endlessIndex] sonsuz boss.
  final int index;

  /// Aktif canavara verilen hasar.
  final int damage;

  /// Bugünkü statlar.
  final BattleStats stats;

  /// Son vuruşlar, yeniden eskiye.
  final List<BattleHit> recent;

  /// Molalarda toplam iyileşen can.
  final int healed;

  /// Bugün iyileşme sürüyor.
  final bool healing;

  int get guardiansBeaten => math.min(index, endlessIndex);
  int get bossKills => math.max(0, index - endlessIndex);
  Monster get monster => monsterAt(index);
  int get hp => monsterHp(index);
  int get hpLeft => hp - damage;
}

DateTime _addDays(DateTime day, int days) => DateTime(day.year, day.month, day.day + days);

/// [events] eskiden yeniye sıralı (`compareXpEvents`), meydan okuma ödülleri dahil.
BattleState battle(List<XpEvent> events, StatInputs inputs, {required DateTime today}) {
  var index = 0;
  var damage = 0;
  var healed = 0;
  DateTime? lastWorkoutDay;
  DateTime? healedThrough;
  final statsByDay = <DateTime, BattleStats>{};
  final hits = <BattleHit>[];

  /// Son antrenman + 8. günden [day]'e (dahil) işlenmemiş her gün iyileşme.
  void healThrough(DateTime day) {
    final last = lastWorkoutDay;
    if (last == null) return;
    final first = _addDays(last, healGraceDays + 1);
    final previous = healedThrough;
    for (var d = previous == null || previous.isBefore(first) ? first : _addDays(previous, 1);
        !d.isAfter(day);
        d = _addDays(d, 1)) {
      final amount = math.min(damage, (monsterHp(index) * healPercent / 100).round());
      damage -= amount;
      healed += amount;
      healedThrough = d;
    }
  }

  for (final e in events) {
    final day = localDay(e.date);
    final workout = e.source == XpSource.workout && e.xp > 0;
    healThrough(workout ? _addDays(day, -1) : day);
    if (workout) lastWorkoutDay = day;
    if (e.xp <= 0) continue;
    final bonus = statsByDay.putIfAbsent(day, () => statsOn(day, inputs)).bonus;
    final weak = monsterAt(index).weakMuscles;
    final onWeak = e.muscleSets.entries.where((m) => weak.contains(m.key)).fold(0, (sum, m) => sum + m.value);
    final share = workout && e.sets > 0 ? math.min(1.0, onWeak / e.sets) : 0.0;
    final hit = (e.xp * (1 + bonus) * (1 + critExtra * share)).round();
    final start = index;
    final defeated = <int>[];
    damage += hit;
    while (damage >= monsterHp(index)) {
      damage -= monsterHp(index);
      defeated.add(index);
      index++;
    }
    hits.add(BattleHit(
      date: e.date,
      source: e.source,
      xp: e.xp,
      damage: hit,
      critShare: share,
      monsterIndex: start,
      defeated: defeated,
    ));
  }

  final now = localDay(today);
  healThrough(now);
  final last = lastWorkoutDay;
  return BattleState(
    index: index,
    damage: damage,
    stats: statsByDay[now] ?? statsOn(now, inputs),
    recent: hits.reversed.take(recentHitCount).toList(),
    healed: healed,
    healing: last != null && !now.isBefore(_addDays(last, healGraceDays + 1)),
  );
}

/// Rütbe için hem seviye eşiği hem bekçi gerekir (O2a spec §5.6); savaş yoksa yalnız seviye.
Rank gatedRank(int level, BattleState? battle) {
  final byLevel = rankFor(level);
  if (battle == null) return byLevel;
  return Rank.values[math.min(byLevel.index, battle.guardiansBeaten)];
}

/// [seen]'den sonraki vuruşlar, eskiden yeniye (O2 cila spec §6.1). [seen] null → boş (ilk açılış).
List<BattleHit> unseenHits(BattleState state, DateTime? seen) {
  if (seen == null) return const [];
  return [for (final hit in state.recent.reversed) if (hit.date.isAfter(seen)) hit];
}

/// Ana sayfa kartında oynatılacak vuruş özeti (O2 cila spec §6.2).
class HitReplay {
  const HitReplay({required this.damage, required this.crit, required this.fromHpLeft, this.defeated});

  final int damage;
  final bool crit;

  /// Animasyon başında kalan can oranı (0–1); yenilme varsa yeni canavar tam canla başlar.
  final double fromHpLeft;

  /// Yenilen son canavar; yoksa null.
  final int? defeated;
}

HitReplay hitReplay(BattleState state, List<BattleHit> hits) {
  final damage = hits.fold(0, (sum, h) => sum + h.damage);
  final defeated = hits.expand((h) => h.defeated).lastOrNull;
  final before = defeated == null ? math.max(0, state.damage - damage) : 0;
  return HitReplay(
    damage: damage,
    crit: hits.any((h) => h.critShare > 0),
    fromHpLeft: (state.hp - before) / state.hp,
    defeated: defeated,
  );
}
