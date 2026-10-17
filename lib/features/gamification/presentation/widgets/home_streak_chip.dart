import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../application/gamification_providers.dart';

/// Ana sayfa AppBar'ında seri + biten görev hapı; dokununca seviye ekranı (O4 spec §6).
/// Özet yüklenirken, hatada ya da seri ve görev yokken görünmez.
class HomeStreakChip extends ConsumerWidget {
  const HomeStreakChip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(playerSummaryProvider).value;
    final streak = summary?.streak.length ?? 0;
    final quests = summary?.quests;
    if (summary == null || (streak == 0 && quests == null)) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final style = theme.textTheme.labelLarge?.copyWith(color: scheme.primary, fontWeight: FontWeight.w800);
    const shape = StadiumBorder();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Material(
        color: scheme.primary.withValues(alpha: 0.1),
        shape: shape.copyWith(side: BorderSide(color: scheme.primary.withValues(alpha: 0.5))),
        child: InkWell(
          key: const Key('home_streak_chip'),
          customBorder: shape,
          onTap: () => context.push('/home/levels'),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (streak > 0) ...[
                  Icon(Icons.local_fire_department, size: 16, color: scheme.primary),
                  const SizedBox(width: 2),
                  Text('$streak', style: style),
                ],
                if (streak > 0 && quests != null) Text(' · ', style: style),
                if (quests != null)
                  Text('${quests.quests.where((q) => q.done).length}/${quests.quests.length}', style: style),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
