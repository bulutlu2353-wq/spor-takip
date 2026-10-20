import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/text_case.dart';
import '../../../shared/widgets/section_header.dart';
import '../application/gamification_providers.dart';
import '../domain/battle.dart';
import '../domain/battle_stats.dart';
import '../domain/levels.dart';
import '../domain/monsters.dart';
import '../domain/player_summary.dart';
import '../domain/xp_rules.dart';
import 'level_screen.dart';
import 'widgets/battle_widgets.dart';
import 'widgets/home_battle_card.dart';

/// Aktif canavar, rütbe kapısı, statlar, son vuruşlar ve canavar yolu (O2a spec §7).
class BattleScreen extends ConsumerWidget {
  const BattleScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = context.locale.languageCode;
    return Scaffold(
      key: const Key('battle_screen'),
      appBar: AppBar(
        title: Text(
          upperCaseFor('gamification.battle.title'.tr(), lang),
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
        ),
        actions: [
          IconButton(
            key: const Key('battle_rules_button'),
            tooltip: 'gamification.rules_title'.tr(),
            icon: const Icon(Icons.info_outline),
            onPressed: () => showXpRules(context),
          ),
        ],
      ),
      body: ref.watch(playerSummaryProvider).when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stackTrace) => Center(child: Text('home.load_error'.tr())),
            data: (summary) {
              final battle = summary.battle;
              if (battle == null) return Center(child: Text('home.load_error'.tr()));
              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
                  _MonsterHeader(battle: battle),
                  _Gate(summary: summary, battle: battle),
                  SectionHeader('gamification.battle.stats_title'.tr()),
                  _Stats(stats: battle.stats),
                  SectionHeader('gamification.battle.hits_title'.tr()),
                  _Hits(hits: battle.recent),
                  SectionHeader('gamification.battle.path_title'.tr()),
                  _Path(battle: battle),
                ],
              );
            },
          ),
    );
  }
}

class _MonsterHeader extends StatelessWidget {
  const _MonsterHeader({required this.battle});

  final BattleState battle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        MonsterAvatar(index: battle.index, size: 160, look: activeLook(battle)),
        const SizedBox(height: 12),
        Text(
          battle.monster.nameKey.tr(),
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
        ),
        Text(guardianText(battle), style: theme.textTheme.bodyMedium),
        const SizedBox(height: 12),
        BattleHpBar(battle: battle),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('${'gamification.battle.weak'.tr()}: ', style: theme.textTheme.labelMedium),
            Flexible(child: WeakMuscleChips(monster: battle.monster)),
          ],
        ),
        if (battle.healing) ...[
          const SizedBox(height: 8),
          Text('gamification.battle.healing'.tr(), style: TextStyle(color: theme.colorScheme.error)),
        ],
      ],
    );
  }
}

/// Bekçi önden yenildiyse seviye bekleme satırı; aktif bekçi için "Yenersen → …" ve seviye şartı.
class _Gate extends StatelessWidget {
  const _Gate({required this.summary, required this.battle});

  final PlayerSummary summary;
  final BattleState battle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final level = summary.progress.level;
    final byLevel = rankFor(level);
    final waiting = battle.guardiansBeaten > byLevel.index ? Rank.values[byLevel.index + 1] : null;
    final target = guardedRank(battle.index);
    return Card(
      margin: const EdgeInsets.only(top: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (waiting != null)
              Text(
                'gamification.battle.gate_wait'
                    .tr(namedArgs: {'n': '${waiting.minLevel}', 'rank': waiting.labelKey.tr()}),
                key: const Key('battle_gate_wait'),
                style: theme.textTheme.titleSmall,
              ),
            if (target == null)
              Text('gamification.battle.gate_endless'.tr(), style: theme.textTheme.titleSmall)
            else ...[
              Text(
                'gamification.battle.gate_open'.tr(namedArgs: {'rank': target.labelKey.tr()}),
                key: const Key('battle_gate_open'),
                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
              ),
              if (level < target.minLevel)
                Text(
                  'gamification.battle.gate_level'.tr(namedArgs: {'n': '${target.minLevel}'}),
                  style: theme.textTheme.bodySmall,
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Stats extends StatelessWidget {
  const _Stats({required this.stats});

  final BattleStats stats;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget row(String key, int value) => Padding(
          key: Key('battle_stat_$key'),
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text('gamification.battle.stat_$key'.tr(), style: theme.textTheme.titleSmall)),
                  Text('$value', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                ],
              ),
              const SizedBox(height: 4),
              LinearProgressIndicator(value: value / maxStat, minHeight: 6),
              const SizedBox(height: 2),
              Text(
                'gamification.battle.stat_${key}_hint'.tr(),
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            row('strength', stats.strength),
            row('endurance', stats.endurance),
            row('consistency', stats.consistency),
            Text(
              'gamification.battle.damage_bonus'.tr(namedArgs: {'n': '${stats.bonusPercent}'}),
              style:
                  theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.primary, fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }
}

class _Hits extends StatelessWidget {
  const _Hits({required this.hits});

  final List<BattleHit> hits;

  static IconData _icon(XpSource source) => switch (source) {
        XpSource.workout => Icons.fitness_center,
        XpSource.record => Icons.emoji_events_outlined,
        XpSource.mealDay => Icons.restaurant,
        XpSource.challenge => Icons.flag_outlined,
        XpSource.quest => Icons.task_alt,
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (hits.isEmpty) return Text('gamification.battle.hits_empty'.tr(), style: theme.textTheme.bodyMedium);
    return Column(
      children: [
        for (final (i, hit) in hits.indexed) ...[
          ListTile(
            key: Key('battle_hit_$i'),
            contentPadding: EdgeInsets.zero,
            leading: Icon(_icon(hit.source)),
            title: Text('gamification.battle.hit_line'.tr(namedArgs: {'xp': '${hit.xp}', 'damage': '${hit.damage}'})),
            subtitle: Text([battleHitDay(hit.date), if (hit.critShare > 0) critText(hit.critShare)].join(' · ')),
          ),
          for (final index in hit.defeated)
            Padding(
              padding: const EdgeInsets.only(left: 56, bottom: 4),
              child: Text(
                'gamification.battle.defeated'.tr(namedArgs: {'name': monsterAt(index).nameKey.tr()}),
                style:
                    theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.primary, fontWeight: FontWeight.w800),
              ),
            ),
        ],
      ],
    );
  }
}

class _Path extends StatelessWidget {
  const _Path({required this.battle});

  final BattleState battle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final active = battle.guardiansBeaten;
    return Column(
      children: [
        for (var i = 0; i < monsters.length; i++)
          KeyedSubtree(
            key: Key('battle_path_${monsters[i].id}'),
            child: ListTile(
              key: Key(i < active
                  ? 'battle_path_done_${monsters[i].id}'
                  : i == active
                      ? 'battle_path_active_${monsters[i].id}'
                      : 'battle_path_locked_${monsters[i].id}'),
              contentPadding: EdgeInsets.zero,
              leading: MonsterAvatar(
                index: i,
                size: 44,
                look: i < active
                    ? MonsterLook.defeated
                    : i == active
                        ? activeLook(battle)
                        : MonsterLook.fogged,
              ),
              title: Text(
                pathNameVisible(i, active) ? monsters[i].nameKey.tr() : 'gamification.battle.unknown'.tr(),
                style: i == active ? theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800) : null,
              ),
              subtitle: Text(switch (guardedRank(i)) {
                final rank? => rank.labelKey.tr(),
                null => 'gamification.battle.path_kills'.tr(namedArgs: {'n': '${battle.bossKills}'}),
              }),
              trailing: i < active
                  ? Icon(Icons.check_circle, color: theme.colorScheme.primary)
                  : i == active
                      ? null
                      : const Icon(Icons.lock_outline),
            ),
          ),
      ],
    );
  }
}
