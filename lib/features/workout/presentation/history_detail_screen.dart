import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_fonts.dart';
import '../../../shared/text_case.dart';
import '../../../shared/widgets/stat_box.dart';
import '../../progress/application/progress_providers.dart';
import '../application/session_providers.dart';
import '../domain/block_format.dart';
import '../domain/session_stats.dart';
import '../domain/workout_session.dart';
import 'history_screen.dart';

String _doneLabel(SessionSet set) =>
    set.weightKg == null ? '× ${set.reps}' : '${trimNumber(set.weightKg!)} kg × ${set.reps}';

class HistoryDetailScreen extends ConsumerWidget {
  const HistoryDetailScreen({super.key, required this.sessionId});

  final String sessionId;

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('workout.history.delete_title'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text('workout.cancel'.tr()),
          ),
          TextButton(
            key: const Key('history_delete_confirm'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text('workout.delete'.tr()),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(sessionRepositoryProvider).deleteSession(sessionId);
      ref
        ..invalidate(sessionHistoryProvider)
        ..invalidate(recentSessionsProvider)
        ..invalidate(allSessionsProvider);
      if (context.mounted) context.pop();
    } catch (e, st) {
      debugPrint('HistoryDetailScreen.delete failed: $e\n$st');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('workout.action_error'.tr())));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionAsync = ref.watch(sessionDetailProvider(sessionId));
    final now = ref.watch(nowProvider)();
    return Scaffold(
      key: const Key('history_detail_screen'),
      appBar: AppBar(
        title: Text(sessionAsync.value?.workoutName ?? ''),
        actions: [
          IconButton(
            key: const Key('history_delete_button'),
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _delete(context, ref),
          ),
        ],
      ),
      body: sessionAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(child: Text('workout.history.load_error'.tr())),
        data: (session) => _content(context, session, now),
      ),
    );
  }

  Widget _content(BuildContext context, WorkoutSession session, DateTime now) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final muted = theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant);
    final meta = '${historyDateLabel(session.startedAt, now)} · ${session.programName}';
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          upperCaseFor(meta, Localizations.localeOf(context).languageCode),
          key: const Key('history_detail_meta'),
          style: theme.textTheme.labelMedium?.copyWith(color: scheme.onSurfaceVariant, letterSpacing: 1),
        ),
        const SizedBox(height: 12),
        StatBoxRow(
          children: [
            StatBox(
              key: const Key('history_detail_duration'),
              label: 'workout.session.stat_duration'.tr(),
              value: formatDuration(sessionDuration(session, now)),
            ),
            StatBox(
              key: const Key('history_detail_sets'),
              label: 'workout.session.stat_sets'.tr(),
              value: '${completedSetCount(session)}',
            ),
            StatBox(
              key: const Key('history_detail_volume'),
              label: 'workout.session.stat_volume'.tr(),
              value: '${trimNumber(totalVolumeKg(session))} kg',
            ),
          ],
        ),
        for (final sets in session.exerciseGroups)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      sets.first.exerciseName,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontFamily: AppFonts.heading,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    for (final (index, set) in sets.indexed) ...[
                      if (index > 0) const Divider(height: 1),
                      Padding(
                        key: Key('history_set_${set.id}'),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          children: [
                            SizedBox(width: 32, child: Text('${index + 1}', style: muted)),
                            Expanded(
                              child: Text(
                                set.isCompleted ? _doneLabel(set) : 'workout.history.not_done'.tr(),
                                style: set.isCompleted ? null : muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
