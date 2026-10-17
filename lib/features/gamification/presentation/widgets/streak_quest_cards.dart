import 'dart:math' as math;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../social/domain/period_keys.dart';
import '../../../social/presentation/widgets/period_widgets.dart';
import '../../../workout/domain/exercise_taxonomy.dart';
import '../../domain/quests.dart';
import '../../domain/streak.dart';

/// "5 gün öğün kaydet" (O4 spec §6).
String questText(QuestKind kind, {required double target, String? muscle}) {
  final n = '${target.toInt()}';
  return switch (kind) {
    QuestKind.workouts => 'gamification.quest_workouts'.tr(namedArgs: {'n': n}),
    QuestKind.sets => 'gamification.quest_sets'.tr(namedArgs: {'n': n}),
    QuestKind.volume => 'gamification.quest_volume'.tr(namedArgs: {'n': n}),
    QuestKind.long => 'gamification.quest_long'.tr(namedArgs: {'n': n}),
    QuestKind.record => 'gamification.quest_record'.tr(),
    QuestKind.muscle =>
      'gamification.quest_muscle'.tr(namedArgs: {'n': n, 'muscle': muscleLabelKey(muscle ?? '').tr()}),
    QuestKind.variety => 'gamification.quest_variety'.tr(namedArgs: {'n': n}),
    QuestKind.weekend => 'gamification.quest_weekend'.tr(),
    QuestKind.mealDays => 'gamification.quest_meal_days'.tr(namedArgs: {'n': n}),
    QuestKind.fullDays => 'gamification.quest_full_days'.tr(namedArgs: {'n': n}),
  };
}

/// Alev + gün, bonus, dinlenme hakkı (O4 spec §6).
class StreakCard extends StatelessWidget {
  const StreakCard({super.key, required this.streak});

  final StreakStatus streak;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final muted = theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant);
    return Card(
      key: const Key('level_streak_card'),
      margin: const EdgeInsets.only(top: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.local_fire_department, size: 40, color: streak.broken ? scheme.onSurfaceVariant : scheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${'gamification.streak_title'.tr()} · ${'gamification.streak_days'.tr(namedArgs: {'n': '${streak.length}'})}',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  if (streak.broken)
                    Text('gamification.streak_broken'.tr(), style: muted)
                  else ...[
                    Text(
                      streak.bonusPercent > 0
                          ? 'gamification.streak_bonus'.tr(namedArgs: {'n': '${streak.bonusPercent}'})
                          : 'gamification.streak_bonus_soon'.tr(),
                      style: theme.textTheme.bodyMedium?.copyWith(color: scheme.primary, fontWeight: FontWeight.w700),
                    ),
                    Text('gamification.streak_rest_left'.tr(namedArgs: {'n': '${streak.restLeft}'}), style: muted),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bu haftanın 3 görevi, ilerleme çubukları, bonus ve kalan süre (O4 spec §6).
class QuestsCard extends StatelessWidget {
  const QuestsCard({super.key, required this.quests, required this.now});

  final WeekQuests quests;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final muted = theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant);
    return Card(
      key: const Key('level_quests_card'),
      margin: const EdgeInsets.only(top: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'gamification.quests_title'.tr(),
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
                Text(periodRemainingLabel(PeriodKind.week, now), style: muted),
              ],
            ),
            for (final (index, quest) in quests.quests.indexed)
              Padding(
                key: Key('quest_$index'),
                padding: const EdgeInsets.only(top: 12),
                child: Row(
                  children: [
                    Icon(
                      quest.done ? Icons.check_circle : Icons.radio_button_unchecked,
                      color: quest.done ? scheme.primary : scheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(questText(quest.kind, target: quest.target, muscle: quest.muscle)),
                          const SizedBox(height: 6),
                          LinearProgressIndicator(
                            value: quest.target <= 0 ? 1 : math.min(1, quest.progress / quest.target),
                            borderRadius: const BorderRadius.all(Radius.circular(4)),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${_number(math.min(quest.progress, quest.target))} / ${_number(quest.target)}',
                            style: muted,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'gamification.xp_gain'.tr(namedArgs: {'n': '$xpPerQuest'}),
                      style: theme.textTheme.labelMedium?.copyWith(color: scheme.primary, fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 12),
            Text(
              'gamification.quests_bonus'.tr(),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: quests.bonusDone ? scheme.primary : scheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 3.0 → "3", 14.5 → "14.5".
  static String _number(double x) => x == x.roundToDouble() ? '${x.toInt()}' : x.toStringAsFixed(1);
}
