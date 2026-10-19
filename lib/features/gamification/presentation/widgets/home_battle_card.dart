import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../application/gamification_providers.dart';
import '../../domain/battle.dart';
import '../../domain/monsters.dart';
import 'battle_widgets.dart';

/// Ana sayfadaki aktif canavar kartı (O2a spec §7); yüklenirken, hatada ya da savaş yokken görünmez.
/// Görülmemiş vuruşlarda vuruş ya da yenilme animasyonu oynar (O2 cila spec §6).
class HomeBattleCard extends ConsumerStatefulWidget {
  const HomeBattleCard({super.key});

  @override
  ConsumerState<HomeBattleCard> createState() => _HomeBattleCardState();
}

/// Bir evrenin süresi (ms): vuruş animasyonu ve yenilme anının iki yarısı.
const _phaseMs = 1200.0;

class _HomeBattleCardState extends ConsumerState<HomeBattleCard> with TickerProviderStateMixin {
  late final _hit = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));
  late final _defeat = AnimationController(vsync: this, duration: const Duration(milliseconds: 2400));
  HitReplay? _replay;
  var _checkedOnce = false;
  DateTime? _checked;

  @override
  void initState() {
    super.initState();
    ref.listenManual(playerSummaryProvider, (_, next) {
      final battle = next.value?.battle;
      if (battle != null) _check(battle);
    }, fireImmediately: true);
  }

  @override
  void dispose() {
    _hit.dispose();
    _defeat.dispose();
    super.dispose();
  }

  /// İlk açılışta yalnız görüldü yazar; sonra görülmemiş vuruşları yazar ve oynatır.
  Future<void> _check(BattleState battle) async {
    final newest = battle.recent.firstOrNull?.date;
    if (_checkedOnce && newest == _checked) return;
    _checkedOnce = true;
    _checked = newest;
    final seen = await readSeenHit();
    if (!mounted) return;
    if (seen == null) {
      await writeSeenHit(newest ?? DateTime.fromMillisecondsSinceEpoch(0));
      return;
    }
    final hits = unseenHits(battle, seen);
    if (hits.isEmpty) return;
    await writeSeenHit(hits.last.date);
    if (!mounted || MediaQuery.disableAnimationsOf(context)) return;
    final replay = hitReplay(battle, hits);
    setState(() => _replay = replay);
    try {
      await (replay.defeated == null ? _hit : _defeat).forward(from: 0).orCancel;
    } on TickerCanceled {
      return;
    }
    if (mounted) setState(() => _replay = null);
  }

  void _open() {
    _hit.stop();
    _defeat.stop();
    if (_replay != null) setState(() => _replay = null);
    context.push('/home/battle');
  }

  @override
  Widget build(BuildContext context) {
    final battle = ref.watch(playerSummaryProvider).value?.battle;
    if (battle == null) return const SizedBox.shrink();
    final replay = _replay;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: const Key('home_battle_card'),
        onTap: _open,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: switch (replay) {
            null => _BattleRow(battle: battle),
            HitReplay(defeated: null) => AnimatedBuilder(
                animation: _hit,
                builder: (context, _) => _BattleRow(battle: battle, replay: replay, t: _hit.value),
              ),
            HitReplay(defeated: final int index) => AnimatedBuilder(
                animation: _defeat,
                builder: (context, _) => _defeat.value < 0.5
                    ? _DefeatMoment(index: index, t: _defeat.value * 2)
                    : _BattleRow(battle: battle, replay: replay, t: (_defeat.value - 0.5) * 2),
              ),
          },
        ),
      ),
    );
  }
}

/// Sönümlü yatay sarsıntı; [s] 0–1.
Offset _shake(double s) => Offset(math.sin(s * math.pi * 8) * 6 * (1 - s), 0);

/// "−340" ya da "−340 · KRİTİK!".
String hitFloatText(HitReplay r) =>
    r.crit ? 'gamification.battle.hit_crit'.tr(namedArgs: {'n': '${r.damage}'}) : '−${r.damage}';

/// Kartın içeriği; [replay] varken [t] (0–1) anına göre animasyonlu.
class _BattleRow extends StatelessWidget {
  const _BattleRow({required this.battle, this.replay, this.t = 1});

  final BattleState battle;
  final HitReplay? replay;
  final double t;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    final replay = this.replay;
    final ms = t * _phaseMs;
    Widget avatar = MonsterAvatar(index: battle.index, size: 72, look: activeLook(battle));
    double? bar;
    if (replay != null) {
      bar = lerpDouble(
        replay.fromHpLeft,
        battle.hpLeft / battle.hp,
        Curves.easeOut.transform((ms / 800).clamp(0.0, 1.0)),
      );
      if (replay.defeated == null) {
        final s = (ms / 400).clamp(0.0, 1.0);
        avatar = Stack(
          clipBehavior: Clip.none,
          children: [
            Transform.translate(offset: _shake(s), child: avatar),
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.red.withValues(alpha: 0.5 * (1 - s)),
                  ),
                ),
              ),
            ),
            Positioned(
              left: -40,
              right: -40,
              top: 24 - 40 * t,
              child: Opacity(
                opacity: 1 - t,
                child: Text(
                  hitFloatText(replay),
                  key: const Key('battle_hit_float'),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: theme.colorScheme.error, fontWeight: FontWeight.w900, fontSize: 16),
                ),
              ),
            ),
          ],
        );
      } else {
        final a = (ms / 400).clamp(0.0, 1.0);
        avatar = Opacity(opacity: a, child: Transform.scale(scale: 0.8 + 0.2 * a, child: avatar));
      }
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        avatar,
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(battle.monster.nameKey.tr(),
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
              Text(guardianText(battle), style: muted),
              const SizedBox(height: 8),
              BattleHpBar(battle: battle, value: bar),
              const SizedBox(height: 8),
              WeakMuscleChips(monster: battle.monster),
              const SizedBox(height: 8),
              Text(lastHitText(battle), style: theme.textTheme.bodySmall),
              if (battle.healing)
                Text('gamification.battle.healing'.tr(),
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error)),
            ],
          ),
        ),
      ],
    );
  }
}

/// Yenilme anı: canavar sarsılır, sonra gri olur ve mühür vurulur; [t] 0–1.
class _DefeatMoment extends StatelessWidget {
  const _DefeatMoment({required this.index, required this.t});

  final int index;
  final double t;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ms = t * _phaseMs;
    final stamped = ms >= 400;
    return Row(
      key: const Key('battle_defeat_moment'),
      children: [
        Transform.translate(
          offset: stamped ? Offset.zero : _shake((ms / 400).clamp(0.0, 1.0)),
          child: MonsterAvatar(
            index: index,
            size: 72,
            look: stamped ? MonsterLook.defeated : MonsterLook.normal,
            stampScale: 1.6 - 0.6 * Curves.easeOut.transform(((ms - 400) / 300).clamp(0.0, 1.0)),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            'gamification.battle.defeated'.tr(namedArgs: {'name': monsterAt(index).nameKey.tr()}),
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900, color: theme.colorScheme.error),
          ),
        ),
      ],
    );
  }
}

/// "Bekçi: Acemi" ya da "Sonsuz boss · ×2".
String guardianText(BattleState battle) => switch (guardedRank(battle.index)) {
      final rank? => 'gamification.battle.guardian_of'.tr(namedArgs: {'rank': rank.labelKey.tr()}),
      null => 'gamification.battle.endless'.tr(namedArgs: {'n': '${battle.bossKills}'}),
    };

/// "5 Ekim −121 · %40 kritik" ya da "Antrenmanla saldır".
String lastHitText(BattleState battle) {
  final hit = battle.recent.firstOrNull;
  if (hit == null) return 'gamification.battle.attack_hint'.tr();
  final crit = hit.critShare > 0 ? ' · ${critText(hit.critShare)}' : '';
  return '${battleHitDay(hit.date)} −${hit.damage}$crit';
}
