import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../application/gamification_providers.dart';
import 'rank_badge.dart';

/// Ana sayfa AppBar'ında rütbe + "Sv n" hapı; dokununca seviye ekranı.
/// Özet yüklenirken ya da hatada görünmez (O1 spec §6.2).
class HomeLevelBadge extends ConsumerWidget {
  const HomeLevelBadge({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(playerSummaryProvider).value;
    if (summary == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    const shape = StadiumBorder();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Material(
        color: scheme.primary.withValues(alpha: 0.1),
        shape: shape.copyWith(side: BorderSide(color: scheme.primary.withValues(alpha: 0.5))),
        child: InkWell(
          key: const Key('home_level_badge'),
          customBorder: shape,
          onTap: () => context.push('/home/levels'),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                RankBadge(rank: summary.rank, level: summary.progress.level, size: 16),
                const SizedBox(width: 6),
                Text(
                  'gamification.level_short'.tr(namedArgs: {'n': '${summary.progress.level}'}),
                  style: theme.textTheme.labelLarge?.copyWith(color: scheme.primary, fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
