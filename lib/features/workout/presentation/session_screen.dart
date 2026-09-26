import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../application/rest_timer.dart';
import '../application/session_notifier.dart';
import '../application/session_providers.dart';
import '../domain/exercise.dart';
import '../domain/session_stats.dart';
import '../domain/workout_session.dart';
import 'widgets/rest_timer_bar.dart';
import 'widgets/set_row.dart';

class SessionScreen extends ConsumerWidget {
  const SessionScreen({super.key, required this.sessionId});

  final String sessionId;

  SessionNotifier _notifier(WidgetRef ref) => ref.read(sessionNotifierProvider(sessionId).notifier);

  void _snack(BuildContext context, String key) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(key.tr())));
  }

  Future<void> _complete(BuildContext context, WidgetRef ref, SessionSet set) async {
    if (set.displayReps == null) {
      _snack(context, 'workout.session.reps_required');
      return;
    }
    final ok = await _notifier(ref).complete(set.id!);
    if (!context.mounted) return;
    if (ok) {
      ref.read(restTimerProvider.notifier).start(set.restSeconds);
    } else {
      _snack(context, 'workout.session.save_error');
    }
  }

  Future<void> _uncomplete(BuildContext context, WidgetRef ref, SessionSet set) async {
    final ok = await _notifier(ref).uncomplete(set.id!);
    if (!ok && context.mounted) _snack(context, 'workout.session.save_error');
  }

  Future<void> _addExercise(BuildContext context, WidgetRef ref) async {
    final exercise = await context.push<Exercise>('/session/$sessionId/exercises');
    if (exercise == null || !context.mounted) return;
    final ok = await _notifier(ref).addExercise(exercise);
    if (!ok && context.mounted) _snack(context, 'workout.session.save_error');
  }

  Future<void> _removeExercise(BuildContext context, WidgetRef ref, int exercisePosition) async {
    final ok = await _notifier(ref).removeExercise(exercisePosition);
    if (!ok && context.mounted) _snack(context, 'workout.session.save_error');
  }

  Future<bool> _confirm(
    BuildContext context, {
    required Key dialogKey,
    required Key confirmKey,
    required String title,
    required String body,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        key: dialogKey,
        title: Text(title.tr()),
        content: Text(body.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text('workout.cancel'.tr()),
          ),
          TextButton(
            key: confirmKey,
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text('workout.session.cancel_confirm'.tr()),
          ),
        ],
      ),
    );
    return confirmed == true;
  }

  Future<void> _cancelSession(BuildContext context, WidgetRef ref) async {
    try {
      await _notifier(ref).cancel();
      if (context.mounted) context.go('/home');
    } catch (e, st) {
      debugPrint('SessionScreen.cancel failed: $e\n$st');
      if (context.mounted) _snack(context, 'workout.action_error');
    }
  }

  Future<void> _askCancel(BuildContext context, WidgetRef ref) async {
    final confirmed = await _confirm(
      context,
      dialogKey: const Key('session_cancel_dialog'),
      confirmKey: const Key('session_cancel_confirm'),
      title: 'workout.session.cancel_confirm_title',
      body: 'workout.session.cancel_confirm_body',
    );
    if (confirmed && context.mounted) await _cancelSession(context, ref);
  }

  Future<void> _finish(BuildContext context, WidgetRef ref, WorkoutSession session) async {
    if (completedSetCount(session) > 0) {
      context.push('/session/$sessionId/summary');
      return;
    }
    final cancel = await _confirm(
      context,
      dialogKey: const Key('session_no_sets_dialog'),
      confirmKey: const Key('session_no_sets_cancel'),
      title: 'workout.session.no_sets_title',
      body: 'workout.session.no_sets_body',
    );
    if (cancel && context.mounted) await _cancelSession(context, ref);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionAsync = ref.watch(sessionNotifierProvider(sessionId));
    final now = ref.watch(clockProvider).value ?? ref.watch(nowProvider)();
    final loaded = sessionAsync.value;

    return Scaffold(
      key: const Key('session_screen'),
      appBar: AppBar(
        title: Text(loaded?.workoutName ?? ''),
        actions: [
          if (loaded != null) ...[
            Center(
              child: Text(
                formatDuration(sessionDuration(loaded, now)),
                key: const Key('session_elapsed'),
              ),
            ),
            TextButton(
              key: const Key('session_finish_button'),
              onPressed: () => _finish(context, ref, loaded),
              child: Text('workout.session.finish'.tr()),
            ),
            PopupMenuButton<String>(
              key: const Key('session_menu'),
              onSelected: (_) => _askCancel(context, ref),
              itemBuilder: (_) => [
                PopupMenuItem(
                  key: const Key('session_cancel_item'),
                  value: 'cancel',
                  child: Text('workout.session.cancel'.tr()),
                ),
              ],
            ),
          ],
        ],
      ),
      bottomNavigationBar: const RestTimerBar(),
      body: sessionAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('workout.session.load_error'.tr()),
              TextButton(
                onPressed: () => ref.invalidate(sessionNotifierProvider(sessionId)),
                child: Text('workout.retry'.tr()),
              ),
            ],
          ),
        ),
        data: (session) => ListView(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 96),
          children: [
            for (final sets in session.exerciseGroups) _exerciseCard(context, ref, sets),
            TextButton.icon(
              key: const Key('session_add_exercise'),
              onPressed: () => _addExercise(context, ref),
              icon: const Icon(Icons.add),
              label: Text('workout.session.add_exercise'.tr()),
            ),
          ],
        ),
      ),
    );
  }

  Widget _exerciseCard(BuildContext context, WidgetRef ref, List<SessionSet> sets) {
    final position = sets.first.exercisePosition;
    return Card(
      key: Key('session_exercise_$position'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListTile(
            title: Text(sets.first.exerciseName, style: Theme.of(context).textTheme.titleMedium),
            trailing: PopupMenuButton<String>(
              key: Key('session_exercise_menu_$position'),
              onSelected: (_) => _removeExercise(context, ref, position),
              itemBuilder: (_) => [
                PopupMenuItem(
                  key: Key('session_remove_exercise_$position'),
                  value: 'remove',
                  child: Text('workout.session.remove_exercise'.tr()),
                ),
              ],
            ),
          ),
          for (final (index, set) in sets.indexed)
            SetRow(
              key: ValueKey(set.id),
              set: set,
              number: index + 1,
              onWeightChanged: (kg) => _notifier(ref).setWeight(set.id!, kg),
              onRepsChanged: (reps) => _notifier(ref).setReps(set.id!, reps),
              onToggle: () => set.isCompleted ? _uncomplete(context, ref, set) : _complete(context, ref, set),
            ),
        ],
      ),
    );
  }
}
