import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../application/gamification_providers.dart';
import '../../domain/battle.dart';
import '../../domain/monsters.dart';
import 'battle_widgets.dart';

/// Ana sayfadaki aktif canavar kartı (O2a spec §7); yüklenirken, hatada ya da savaş yokken görünmez.
class HomeBattleCard extends ConsumerWidget {
  const HomeBattleCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final battle = ref.watch(playerSummaryProvider).value?.battle;
    if (battle == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: const Key('home_battle_card'),
        onTap: () => context.push('/home/battle'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              MonsterAvatar(index: battle.index, size: 72),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(battle.monster.nameKey.tr(),
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                    Text(guardianText(battle), style: muted),
                    const SizedBox(height: 8),
                    BattleHpBar(battle: battle),
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
          ),
        ),
      ),
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
