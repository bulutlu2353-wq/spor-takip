import 'dart:math' as math;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_fonts.dart';
import '../../../shared/text_case.dart';
import '../../../shared/widgets/section_header.dart';
import '../../progress/application/progress_providers.dart';
import '../../workout/application/workout_providers.dart';
import '../application/gamification_providers.dart';
import '../domain/levels.dart';
import '../domain/player_summary.dart';
import '../domain/titles.dart';
import '../domain/xp_rules.dart';
import 'title_names.dart';
import 'widgets/rank_badge.dart';

/// Seviye, rütbe, unvanlar ve son kazanımlar (O1 spec §6.3).
class LevelScreen extends ConsumerWidget {
  const LevelScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = context.locale.languageCode;
    final activeId = ref.watch(activeTitleProvider).value;
    return Scaffold(
      key: const Key('level_screen'),
      appBar: AppBar(
        title: Text(
          upperCaseFor('gamification.title'.tr(), lang),
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
        ),
      ),
      body: ref.watch(playerSummaryProvider).when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stackTrace) => Center(
              child: TextButton(
                key: const Key('level_retry'),
                onPressed: () {
                  ref.invalidate(allSessionsProvider);
                  ref.invalidate(mealTimesProvider);
                  ref.invalidate(exercisesProvider);
                },
                child: Text('gamification.retry'.tr()),
              ),
            ),
            data: (summary) => ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                _Header(summary: summary, active: summary.titleById(activeId)),
                SectionHeader('gamification.breakdown_title'.tr()),
                _Breakdown(breakdown: summary.breakdown),
                SectionHeader(
                  'gamification.titles_title'.tr(),
                  key: const Key('level_titles_count'),
                  trailing: 'gamification.titles_count'.tr(namedArgs: {'n': '${summary.titles.length}'}),
                ),
                _Titles(summary: summary, activeId: activeId),
                SectionHeader('gamification.ladder_title'.tr()),
                _Ladder(current: summary.rank),
                SectionHeader('gamification.recent_title'.tr()),
                _Recent(events: summary.recent),
              ],
            ),
          ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.summary, required this.active});

  final PlayerSummary summary;
  final TitleProgress? active;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final muted = theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant);
    final progress = summary.progress;
    final active = this.active;
    return Card(
      key: const Key('level_header'),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            RankBadge(rank: summary.rank, level: progress.level, size: 88),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    upperCaseFor(summary.rank.labelKey.tr(), context.locale.languageCode),
                    style: theme.textTheme.headlineSmall?.copyWith(fontFamily: AppFonts.heading, fontWeight: FontWeight.w900),
                  ),
                  if (active != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Container(
                        key: const Key('level_active_title'),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: scheme.primary.withValues(alpha: 0.12),
                          borderRadius: const BorderRadius.all(Radius.circular(999)),
                          border: Border.all(color: scheme.primary),
                        ),
                        child: Text(
                          titleName(active, active.tier!),
                          style: theme.textTheme.labelLarge?.copyWith(color: scheme.primary),
                        ),
                      ),
                    ),
                  const SizedBox(height: 10),
                  Text(
                    'gamification.level'.tr(namedArgs: {'n': '${progress.level}'}),
                    style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800, letterSpacing: 1),
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: const BorderRadius.all(Radius.circular(999)),
                    child: LinearProgressIndicator(value: progress.fraction, minHeight: 8),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'gamification.progress'.tr(namedArgs: {'x': '${progress.xpIntoLevel}', 'y': '${progress.xpNeeded}'}),
                    key: const Key('level_progress'),
                    style: theme.textTheme.bodySmall?.copyWith(color: scheme.primary),
                  ),
                  Text(
                    'gamification.total_xp'.tr(namedArgs: {'n': '${summary.totalXp}'}),
                    key: const Key('level_total_xp'),
                    style: muted,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Breakdown extends StatelessWidget {
  const _Breakdown({required this.breakdown});

  final XpBreakdown breakdown;

  @override
  Widget build(BuildContext context) {
    Widget tile(IconData icon, String label, int xp) => Expanded(child: _BreakdownTile(icon: icon, label: label, xp: xp));
    return Column(
      key: const Key('level_breakdown'),
      children: [
        Row(
          children: [
            tile(Icons.fitness_center, 'gamification.breakdown_workouts'.tr(), breakdown.workouts),
            const SizedBox(width: 12),
            tile(Icons.layers_outlined, 'gamification.breakdown_sets'.tr(), breakdown.sets),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            tile(Icons.emoji_events_outlined, 'gamification.breakdown_records'.tr(), breakdown.records),
            const SizedBox(width: 12),
            tile(Icons.restaurant, 'gamification.breakdown_meal_days'.tr(), breakdown.mealDays),
          ],
        ),
      ],
    );
  }
}

class _BreakdownTile extends StatelessWidget {
  const _BreakdownTile({required this.icon, required this.label, required this.xp});

  final IconData icon;
  final String label;
  final int xp;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(label, style: theme.textTheme.labelLarge?.copyWith(color: scheme.onSurfaceVariant)),
                ),
                Icon(icon, size: 18, color: scheme.primary),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '$xp',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontFamily: AppFonts.heading,
                fontWeight: FontWeight.w900,
                color: scheme.primary,
              ),
            ),
            Text('XP', style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}

class _Titles extends ConsumerWidget {
  const _Titles({required this.summary, required this.activeId});

  final PlayerSummary summary;
  final String? activeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final notifier = ref.read(activeTitleProvider.notifier);
    const compact = Size(0, 32);
    const padding = EdgeInsets.symmetric(horizontal: 12);
    return Column(
      key: const Key('level_titles'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (summary.titles.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'gamification.titles_empty'.tr(),
              key: const Key('level_titles_empty'),
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
          ),
        for (final title in summary.titles)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Card(
              key: Key('title_${title.id}'),
              margin: EdgeInsets.zero,
              shape: RoundedRectangleBorder(
                borderRadius: const BorderRadius.all(Radius.circular(16)),
                side: title.id == activeId ? BorderSide(color: scheme.primary) : BorderSide.none,
              ),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: scheme.surfaceContainerHighest,
                  child: Icon(
                    title.kind == TitleKind.muscle ? Icons.accessibility_new : Icons.fitness_center,
                    color: scheme.primary,
                    size: 20,
                  ),
                ),
                title: Text(titleName(title, title.tier!)),
                subtitle: Text(titleCriterion(title)),
                trailing: title.id == activeId
                    ? FilledButton(
                        key: Key('title_unequip_${title.id}'),
                        style: FilledButton.styleFrom(minimumSize: compact, padding: padding),
                        onPressed: notifier.unequip,
                        child: Text('gamification.equipped'.tr()),
                      )
                    : OutlinedButton(
                        key: Key('title_equip_${title.id}'),
                        style: OutlinedButton.styleFrom(minimumSize: compact, padding: padding),
                        onPressed: () => notifier.equip(title.id),
                        child: Text('gamification.equip'.tr()),
                      ),
              ),
            ),
          ),
        if (summary.upcoming.isNotEmpty)
          Card(
            key: const Key('level_upcoming'),
            margin: const EdgeInsets.only(top: 4),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    upperCaseFor('gamification.upcoming_title'.tr(), context.locale.languageCode),
                    style: theme.textTheme.labelLarge?.copyWith(color: scheme.onSurfaceVariant, letterSpacing: 1),
                  ),
                  for (final title in summary.upcoming)
                    Padding(
                      key: Key('upcoming_${title.id}'),
                      padding: const EdgeInsets.only(top: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Expanded(child: Text(titleName(title, title.nextTier!))),
                              Text(
                                titleCriterion(title),
                                style: theme.textTheme.bodySmall?.copyWith(color: scheme.primary),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: const BorderRadius.all(Radius.circular(999)),
                            child: LinearProgressIndicator(
                              value: (title.value / title.nextThreshold!).clamp(0.0, 1.0),
                              minHeight: 6,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _Ladder extends StatefulWidget {
  const _Ladder({required this.current});

  final Rank current;

  @override
  State<_Ladder> createState() => _LadderState();
}

class _LadderState extends State<_Ladder> {
  static const _cardWidth = 120.0;
  static const _gap = 12.0;
  late final ScrollController _controller =
      ScrollController(initialScrollOffset: math.max(0, (widget.current.index - 1) * (_cardWidth + _gap)));

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final lang = context.locale.languageCode;
    return SizedBox(
      key: const Key('level_ladder'),
      height: 168,
      child: ListView.separated(
        controller: _controller,
        scrollDirection: Axis.horizontal,
        itemCount: Rank.values.length,
        separatorBuilder: (context, index) => const SizedBox(width: _gap),
        itemBuilder: (context, index) {
          final rank = Rank.values[index];
          final isCurrent = rank == widget.current;
          final passed = rank.index < widget.current.index;
          final status = isCurrent
              ? _pill(context, 'gamification.ladder_current'.tr(), filled: true)
              : passed
                  ? _pill(context, 'gamification.ladder_passed'.tr(), filled: false)
                  : Icon(Icons.lock_outline, size: 16, color: scheme.onSurfaceVariant);
          return Opacity(
            key: Key('ladder_${rank.name}'),
            opacity: rank.index > widget.current.index ? 0.4 : 1,
            child: Container(
              width: _cardWidth,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.cardTheme.color ?? scheme.surfaceContainer,
                borderRadius: const BorderRadius.all(Radius.circular(16)),
                border: Border.all(color: isCurrent ? scheme.primary : scheme.outlineVariant),
                boxShadow: isCurrent ? [BoxShadow(color: scheme.primary.withValues(alpha: 0.25), blurRadius: 16)] : null,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  RankBadge(rank: rank, level: rank.minLevel, size: 36),
                  const SizedBox(height: 8),
                  Text(
                    'gamification.level_short'.tr(namedArgs: {'n': '${rank.minLevel}'}),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                  Text(
                    upperCaseFor(rank.labelKey.tr(), lang),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 6),
                  // Uzun çeviride taşmak yerine küçülür.
                  FittedBox(fit: BoxFit.scaleDown, child: status),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _pill(BuildContext context, String text, {required bool filled}) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: filled ? scheme.primary : scheme.primary.withValues(alpha: 0.12),
        borderRadius: const BorderRadius.all(Radius.circular(999)),
      ),
      child: Text(
        text,
        style: theme.textTheme.labelSmall?.copyWith(
          color: filled ? scheme.onPrimary : scheme.primary,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _Recent extends StatelessWidget {
  const _Recent({required this.events});

  final List<XpEvent> events;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Column(
      key: const Key('level_recent'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (events.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'gamification.recent_empty'.tr(),
              key: const Key('level_recent_empty'),
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
          ),
        for (final (index, event) in events.indexed)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Card(
              key: Key('recent_$index'),
              margin: EdgeInsets.zero,
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: scheme.surfaceContainerHighest,
                  child: Icon(_icon(event.source), color: scheme.primary, size: 20),
                ),
                title: Text(_title(event)),
                subtitle: switch (_detail(event)) {
                  final detail? => Text(detail),
                  null => null,
                },
                trailing: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: scheme.primary.withValues(alpha: 0.12),
                        borderRadius: const BorderRadius.all(Radius.circular(999)),
                        border: Border.all(color: scheme.primary.withValues(alpha: 0.5)),
                      ),
                      child: Text(
                        'gamification.xp_gain'.tr(namedArgs: {'n': '${event.xp}'}),
                        style: theme.textTheme.labelMedium?.copyWith(color: scheme.primary, fontWeight: FontWeight.w800),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${event.date.day} ${'home.month_${event.date.month}'.tr()}',
                      style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  static IconData _icon(XpSource source) => switch (source) {
        XpSource.workout => Icons.fitness_center,
        XpSource.record => Icons.bolt,
        XpSource.mealDay => Icons.restaurant,
      };

  static String _title(XpEvent event) => switch (event.source) {
        XpSource.workout => event.label ?? '',
        XpSource.record => 'gamification.record'.tr(namedArgs: {'name': event.label ?? ''}),
        XpSource.mealDay => 'gamification.meal_day'.tr(),
      };

  static String? _detail(XpEvent event) => switch (event.source) {
        XpSource.workout => 'gamification.workout_sets'.tr(namedArgs: {'n': '${event.sets}'}),
        XpSource.record => 'gamification.record_detail'.tr(namedArgs: {
            'kg': formatKg(event.weightKg ?? 0),
            'reps': '${event.reps ?? 0}',
          }),
        XpSource.mealDay => null,
      };

  /// 140.0 → "140", 62.5 → "62.5".
  static String formatKg(double kg) => kg == kg.roundToDouble() ? '${kg.toInt()}' : kg.toStringAsFixed(1);
}
