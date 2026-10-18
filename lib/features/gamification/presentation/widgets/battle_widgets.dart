import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../workout/domain/exercise_taxonomy.dart';
import '../../domain/battle.dart';
import '../../domain/monsters.dart';

/// Aşama renkleri ve simgeleri; O2b'de görsellerle değişecek yer tutucu (O2a spec §7).
const _tierColors = [Color(0xFF43A047), Color(0xFF1E88E5), Color(0xFF8E24AA), Color(0xFFE53935)];
const _tierIcons = [Icons.pest_control, Icons.pets, Icons.bolt, Icons.local_fire_department];

/// Aşama renginde daire, canavar simgesi ve adının baş harfi.
class MonsterAvatar extends StatelessWidget {
  const MonsterAvatar({super.key, required this.index, this.size = 64});

  final int index;
  final double size;

  @override
  Widget build(BuildContext context) {
    final monster = monsterAt(index);
    final tier = monsterTier(index);
    final color = _tierColors[tier - 1];
    final name = monster.nameKey.tr();
    return Container(
      key: Key('monster_avatar_${monster.id}'),
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: 0.18),
        border: Border.all(color: color, width: 2),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(_tierIcons[tier - 1], size: size * 0.5, color: color),
          Positioned(
            right: size * 0.12,
            bottom: size * 0.08,
            child: Text(
              name.isEmpty ? '' : name.characters.first,
              style: TextStyle(fontSize: size * 0.2, fontWeight: FontWeight.w900, color: color),
            ),
          ),
        ],
      ),
    );
  }
}

/// Kalan can çubuğu ve "kalan / tam".
class BattleHpBar extends StatelessWidget {
  const BattleHpBar({super.key, required this.battle});

  final BattleState battle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: const BorderRadius.all(Radius.circular(4)),
            child: LinearProgressIndicator(
              key: const Key('battle_hp_bar'),
              value: battle.hpLeft / battle.hp,
              minHeight: 8,
              color: theme.colorScheme.error,
              backgroundColor: theme.colorScheme.error.withValues(alpha: 0.15),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text('${battle.hpLeft} / ${battle.hp}', style: theme.textTheme.labelMedium),
      ],
    );
  }
}

/// Canavarın iki zayıf kası.
class WeakMuscleChips extends StatelessWidget {
  const WeakMuscleChips({super.key, required this.monster});

  final Monster monster;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: [
        for (final muscle in monster.weakMuscles)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: scheme.tertiary.withValues(alpha: 0.12),
              borderRadius: const BorderRadius.all(Radius.circular(12)),
            ),
            child: Text(muscleLabelKey(muscle).tr(), style: TextStyle(fontSize: 12, color: scheme.tertiary)),
          ),
      ],
    );
  }
}

/// "5 Ekim".
String battleHitDay(DateTime d) => '${d.day} ${'home.month_${d.month}'.tr()}';

/// "%40 kritik".
String critText(double share) => 'gamification.battle.crit'.tr(namedArgs: {'n': '${(share * 100).round()}'});
