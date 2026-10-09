import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_fonts.dart';
import '../../../shared/text_case.dart';
import '../../../shared/widgets/section_header.dart';
import '../../gamification/presentation/title_names.dart';
import '../../gamification/presentation/widgets/rank_badge.dart';
import '../../workout/application/muscle_map_providers.dart';
import '../../workout/application/session_providers.dart';
import '../../workout/presentation/widgets/muscle_map.dart';
import '../application/social_providers.dart';
import '../domain/player_stats.dart';
import 'social_screen.dart';
import 'widgets/social_avatar.dart';

/// "3 saat önce" gibi; çeviri anahtarı + {n}.
String agoLabel(DateTime updatedAt, DateTime now) {
  final diff = now.difference(updatedAt);
  if (diff.inMinutes < 1) return 'social.ago_now'.tr();
  if (diff.inHours < 1) return 'social.ago_minutes'.tr(namedArgs: {'n': '${diff.inMinutes}'});
  if (diff.inDays < 1) return 'social.ago_hours'.tr(namedArgs: {'n': '${diff.inHours}'});
  return 'social.ago_days'.tr(namedArgs: {'n': '${diff.inDays}'});
}

String _formatKg(double kg) => kg == kg.roundToDouble() ? '${kg.toInt()}' : kg.toStringAsFixed(1);

String _dayLabel(DateTime date) => '${date.day} ${'home.month_${date.month}'.tr()}';

/// Arkadaşın paylaştıkları (S1 spec §6.4).
class FriendProfileScreen extends ConsumerWidget {
  const FriendProfileScreen({super.key, required this.friendId});

  final String friendId;

  Future<void> _confirmRemove(BuildContext context, WidgetRef ref, FriendEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('social.remove_title'.tr()),
        content: Text('social.remove_body'.tr(namedArgs: {'name': entry.profile.displayName})),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: Text('social.cancel'.tr())),
          TextButton(
            key: const Key('friend_remove_confirm'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text('social.remove_confirm'.tr()),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await runSocialAction(context, () => ref.read(socialActionsProvider).remove(entry.profile.userId));
    if (context.mounted && context.canPop()) context.pop();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entryAsync = ref.watch(friendProfileProvider(friendId));
    final entry = entryAsync.value;
    return Scaffold(
      key: const Key('friend_profile_screen'),
      appBar: AppBar(
        title: Text(entry == null ? '' : '@${entry.profile.username}'),
        actions: [
          if (entry != null)
            PopupMenuButton<String>(
              key: const Key('friend_menu'),
              onSelected: (_) => _confirmRemove(context, ref, entry),
              itemBuilder: (context) => [
                PopupMenuItem(value: 'remove', key: const Key('friend_remove'), child: Text('social.remove'.tr())),
              ],
            ),
        ],
      ),
      body: entryAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(
          child: TextButton(
            key: const Key('friend_retry'),
            onPressed: () => ref.invalidate(friendshipsProvider),
            child: Text('social.retry'.tr()),
          ),
        ),
        data: (entry) => entry == null
            ? Center(child: Text('social.not_friend'.tr(), key: const Key('friend_not_found')))
            : _FriendBody(entry: entry),
      ),
    );
  }
}

class _FriendBody extends ConsumerWidget {
  const _FriendBody({required this.entry});

  final FriendEntry entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = entry.stats;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        _Header(entry: entry, now: ref.watch(nowProvider)()),
        if (stats != null) ...[
          SectionHeader('social.friend_titles'.tr()),
          _Titles(stats: stats),
          SectionHeader('social.friend_weekly'.tr()),
          if (stats.weekly case final weekly?)
            _Weekly(weekly: weekly)
          else
            const _Hidden(key: Key('friend_hidden_weekly')),
          SectionHeader('social.friend_heat'.tr()),
          if (stats.heat case final heat?)
            MiniMuscleMapCard(
              key: const Key('friend_heat'),
              figure: ref.watch(mapFigureProvider),
              heat: heat,
              showTitle: false,
            )
          else
            const _Hidden(key: Key('friend_hidden_heat')),
          SectionHeader('social.friend_recent'.tr()),
          if (stats.recent case final recent?)
            _Recent(recent: recent)
          else
            const _Hidden(key: Key('friend_hidden_recent')),
        ],
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.entry, required this.now});

  final FriendEntry entry;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final muted = theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant);
    final stats = entry.stats;
    final active = stats?.activeTitle;
    final updatedAt = stats?.updatedAt;
    final lang = context.locale.languageCode;
    return Card(
      key: const Key('friend_header'),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            if (stats != null)
              RankBadge(rank: stats.rank, level: stats.level, size: 88)
            else
              SocialAvatar(initials: entry.profile.initials, size: 72),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.profile.displayName,
                    style: theme.textTheme.headlineSmall?.copyWith(fontFamily: AppFonts.heading, fontWeight: FontWeight.w900),
                  ),
                  if (active != null)
                    Padding(
                      key: const Key('friend_active_title'),
                      padding: const EdgeInsets.only(top: 6),
                      child: TitlePill(text: titleName(active.asProgress, active.tier)),
                    ),
                  if (stats == null)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text('social.no_stats'.tr(), key: const Key('friend_no_stats'), style: muted),
                    )
                  else ...[
                    const SizedBox(height: 8),
                    Text(
                      'social.level_line'.tr(namedArgs: {
                        'n': '${stats.level}',
                        'rank': upperCaseFor(stats.rank.labelKey.tr(), lang),
                      }),
                      style: theme.textTheme.labelLarge?.copyWith(color: scheme.primary, fontWeight: FontWeight.w800),
                    ),
                    Text('social.total_xp'.tr(namedArgs: {'n': '${stats.totalXp}'}), style: muted),
                    if (updatedAt != null)
                      Text(
                        'social.updated'.tr(namedArgs: {'ago': agoLabel(updatedAt, now)}),
                        key: const Key('friend_updated'),
                        style: muted,
                      ),
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

class _Titles extends StatelessWidget {
  const _Titles({required this.stats});

  final PlayerStats stats;

  @override
  Widget build(BuildContext context) {
    if (stats.titles.isEmpty) {
      return Text(
        'social.friend_titles_empty'.tr(),
        key: const Key('friend_titles'),
        style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
      );
    }
    return Wrap(
      key: const Key('friend_titles'),
      spacing: 8,
      runSpacing: 8,
      children: [for (final t in stats.titles) Chip(label: Text(titleName(t.asProgress, t.tier)))],
    );
  }
}

class _Weekly extends StatelessWidget {
  const _Weekly({required this.weekly});

  final WeeklyStats weekly;

  @override
  Widget build(BuildContext context) {
    Widget tile(IconData icon, int value, String label) => Expanded(
          child: Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
              child: Column(
                children: [
                  Icon(icon, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(height: 6),
                  Text(
                    '$value',
                    style: Theme.of(context)
                        .textTheme
                        .headlineMedium
                        ?.copyWith(fontFamily: AppFonts.heading, fontWeight: FontWeight.w900),
                  ),
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ),
        );
    return Row(
      key: const Key('friend_weekly'),
      children: [
        tile(Icons.fitness_center, weekly.workouts, 'social.weekly_workouts'.tr()),
        const SizedBox(width: 8),
        tile(Icons.repeat, weekly.sets, 'social.weekly_sets'.tr()),
        const SizedBox(width: 8),
        tile(Icons.restaurant, weekly.mealDays, 'social.weekly_meal_days'.tr()),
      ],
    );
  }
}

class _Recent extends StatelessWidget {
  const _Recent({required this.recent});

  final List<RecentWorkout> recent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    if (recent.isEmpty) {
      return Text(
        'social.friend_recent_empty'.tr(),
        key: const Key('friend_recent'),
        style: TextStyle(color: scheme.onSurfaceVariant),
      );
    }
    return Column(
      key: const Key('friend_recent'),
      children: [
        for (final (index, workout) in recent.indexed)
          Card(
            key: Key('friend_recent_$index'),
            margin: const EdgeInsets.only(bottom: 8),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: scheme.surfaceContainerHighest,
                        child: Icon(Icons.fitness_center, color: scheme.primary, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(workout.name, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                            Text(
                              'social.recent_line'
                                  .tr(namedArgs: {'sets': '${workout.sets}', 'date': _dayLabel(workout.date)}),
                              style: TextStyle(color: scheme.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  for (final record in workout.records)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Row(
                        children: [
                          Icon(Icons.bolt, size: 18, color: scheme.primary),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              'social.record_line'.tr(namedArgs: {
                                'name': record.name,
                                'kg': _formatKg(record.weightKg),
                                'reps': '${record.reps}',
                              }),
                              style: TextStyle(color: scheme.primary, fontWeight: FontWeight.w700),
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

class _Hidden extends StatelessWidget {
  const _Hidden({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.lock_outline, color: scheme.onSurfaceVariant),
            const SizedBox(width: 12),
            Text('social.hidden'.tr(), style: TextStyle(color: scheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}
