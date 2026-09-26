import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../application/session_providers.dart';
import '../domain/block_format.dart';
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
      ref.invalidate(sessionHistoryProvider);
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
        data: (session) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(historySubtitle(session)),
            const SizedBox(height: 8),
            for (final sets in session.exerciseGroups)
              Card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ListTile(title: Text(sets.first.exerciseName)),
                    for (final (index, set) in sets.indexed)
                      ListTile(
                        key: Key('history_set_${set.id}'),
                        dense: true,
                        enabled: set.isCompleted,
                        leading: Text('${index + 1}'),
                        title: Text(set.isCompleted ? _doneLabel(set) : 'workout.history.not_done'.tr()),
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
