import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../application/session_providers.dart';
import '../domain/block_format.dart';
import '../domain/session_stats.dart';
import '../domain/workout_session.dart';

/// "26.9.2026 · StrongLifts 5x5 · 50:00 · 1500 kg"
String historySubtitle(WorkoutSession session) {
  final d = session.startedAt.toLocal();
  final duration = formatDuration(sessionDuration(session, DateTime.now()));
  return '${d.day}.${d.month}.${d.year} · ${session.programName} · $duration · '
      '${trimNumber(totalVolumeKg(session))} kg';
}

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(sessionHistoryProvider);
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
        data: (sessions) {
          if (sessions.isEmpty) {
            return Center(child: Text('workout.history.empty'.tr(), key: const Key('history_empty')));
          }
          return ListView(
            children: [
              for (final session in sessions)
                ListTile(
                  key: Key('history_${session.id}'),
                  title: Text(session.workoutName),
                  subtitle: Text(historySubtitle(session)),
                  onTap: () => context.push('/workout/history/${session.id}'),
                ),
            ],
          );
        },
      ),
    );
  }
}
