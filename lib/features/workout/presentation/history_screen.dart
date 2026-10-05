import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_fonts.dart';
import '../../../shared/date_label.dart';
import '../../../shared/widgets/section_header.dart';
import '../../progress/presentation/widgets/weekly_summary_card.dart';
import '../application/session_providers.dart';
import '../domain/block_format.dart';
import '../domain/session_stats.dart';
import '../domain/workout_session.dart';

/// "4 Ekim · 48:20 · 5850 kg" — geçmiş listesindeki alt satır (program adı detayda).
String historyListSubtitle(WorkoutSession session, DateTime now) {
  final duration = formatDuration(sessionDuration(session, now));
  return '${shortDateLabel(session.startedAt, now)} · $duration · ${trimNumber(totalVolumeKg(session))} kg';
}

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(sessionHistoryProvider);
    final now = ref.watch(nowProvider)();
    return Scaffold(
      key: const Key('history_screen'),
      appBar: AppBar(title: Text('workout.history.title'.tr())),
      body: historyAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('workout.history.load_error'.tr()),
              TextButton(
                onPressed: () => ref.invalidate(sessionHistoryProvider),
                child: Text('workout.retry'.tr()),
              ),
            ],
          ),
        ),
        data: (sessions) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            const WeeklySummaryCard(),
            SectionHeader('workout.history.sessions'.tr()),
            if (sessions.isEmpty)
              Text(
                'workout.history.empty'.tr(),
                key: const Key('history_empty'),
                style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
              )
            else
              for (final session in sessions) _HistoryTile(session: session, now: now),
          ],
        ),
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({required this.session, required this.now});

  final WorkoutSession session;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Card(
        key: Key('history_${session.id}'),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => context.push('/workout/history/${session.id}'),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        session.workoutName,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontFamily: AppFonts.heading,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        historyListSubtitle(session, now),
                        style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
