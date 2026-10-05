import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_fonts.dart';
import '../../../shared/text_case.dart';
import '../../../shared/widgets/stat_box.dart';
import '../application/rest_timer.dart';
import '../application/session_notifier.dart';
import '../application/session_providers.dart';
import '../domain/block_format.dart';
import '../domain/exercise.dart';
import '../domain/session_stats.dart';
import '../domain/workout_session.dart';
import 'widgets/rest_timer_bar.dart';
import 'widgets/set_row.dart';

class SessionScreen extends ConsumerStatefulWidget {
  const SessionScreen({super.key, required this.sessionId});

  final String sessionId;

  @override
  ConsumerState<SessionScreen> createState() => _SessionScreenState();
}

class _SessionScreenState extends ConsumerState<SessionScreen> {
  /// Tüm setleri bittiği hâlde kullanıcının açtığı hareketler (exercisePosition).
  /// Yalnız görünüm durumu; kaydedilmez.
  final Set<int> _expanded = {};

  String get _sessionId => widget.sessionId;

  SessionNotifier get _notifier => ref.read(sessionNotifierProvider(_sessionId).notifier);

  void _snack(String key) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(key.tr())));
  }

  Future<void> _complete(SessionSet set) async {
    if (set.displayReps == null) {
      _snack('workout.session.reps_required');
      return;
    }
    final ok = await _notifier.complete(set.id!);
    if (!mounted) return;
    if (ok) {
      ref.read(restTimerProvider.notifier).start(set.restSeconds);
    } else {
      _snack('workout.session.save_error');
    }
  }

  Future<void> _uncomplete(SessionSet set) async {
    final ok = await _notifier.uncomplete(set.id!);
    if (!ok && mounted) _snack('workout.session.save_error');
  }

  Future<void> _addExercise() async {
    final exercise = await context.push<Exercise>('/session/$_sessionId/exercises');
    if (exercise == null || !mounted) return;
    final ok = await _notifier.addExercise(exercise);
    if (!ok && mounted) _snack('workout.session.save_error');
  }

  Future<void> _removeExercise(int exercisePosition) async {
    final ok = await _notifier.removeExercise(exercisePosition);
    if (!ok && mounted) _snack('workout.session.save_error');
  }

  Future<bool> _confirm({
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

  Future<void> _cancelSession() async {
    try {
      await _notifier.cancel();
      if (mounted) context.go('/home');
    } catch (e, st) {
      debugPrint('SessionScreen.cancel failed: $e\n$st');
      if (mounted) _snack('workout.action_error');
    }
  }

  Future<void> _askCancel() async {
    final confirmed = await _confirm(
      dialogKey: const Key('session_cancel_dialog'),
      confirmKey: const Key('session_cancel_confirm'),
      title: 'workout.session.cancel_confirm_title',
      body: 'workout.session.cancel_confirm_body',
    );
    if (confirmed && mounted) await _cancelSession();
  }

  Future<void> _finish(WorkoutSession session) async {
    if (completedSetCount(session) > 0) {
      context.push('/session/$_sessionId/summary');
      return;
    }
    final cancel = await _confirm(
      dialogKey: const Key('session_no_sets_dialog'),
      confirmKey: const Key('session_no_sets_cancel'),
      title: 'workout.session.no_sets_title',
      body: 'workout.session.no_sets_body',
    );
    if (cancel && mounted) await _cancelSession();
  }

  @override
  Widget build(BuildContext context) {
    final sessionAsync = ref.watch(sessionNotifierProvider(_sessionId));
    final now = ref.watch(clockProvider).value ?? ref.watch(nowProvider)();
    final loaded = sessionAsync.value;
    final theme = Theme.of(context);

    return Scaffold(
      key: const Key('session_screen'),
      appBar: AppBar(
        title: loaded == null
            ? null
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    upperCaseFor(loaded.workoutName, Localizations.localeOf(context).languageCode),
                    key: const Key('session_workout_name'),
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      letterSpacing: 1,
                    ),
                  ),
                  Text(
                    loaded.programName,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontFamily: AppFonts.heading,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
        actions: [
          if (loaded != null) ...[
            FilledButton(
              key: const Key('session_finish_button'),
              style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
              onPressed: () => _finish(loaded),
              child: Text('workout.session.finish'.tr()),
            ),
            PopupMenuButton<String>(
              key: const Key('session_menu'),
              onSelected: (_) => _askCancel(),
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
                onPressed: () => ref.invalidate(sessionNotifierProvider(_sessionId)),
                child: Text('workout.retry'.tr()),
              ),
            ],
          ),
        ),
        data: (session) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
          children: [
            _SessionStats(session: session, now: now),
            const SizedBox(height: 16),
            for (final sets in session.exerciseGroups) ...[
              _exercise(sets),
              const SizedBox(height: 8),
            ],
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                key: const Key('session_add_exercise'),
                onPressed: _addExercise,
                icon: const Icon(Icons.add),
                label: Text('workout.session.add_exercise'.tr()),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _exerciseMenu(int position) => PopupMenuButton<String>(
        key: Key('session_exercise_menu_$position'),
        onSelected: (_) => _removeExercise(position),
        itemBuilder: (_) => [
          PopupMenuItem(
            key: Key('session_remove_exercise_$position'),
            value: 'remove',
            child: Text('workout.session.remove_exercise'.tr()),
          ),
        ],
      );

  Widget _exercise(List<SessionSet> sets) {
    final position = sets.first.exercisePosition;
    final done = sets.where((s) => s.isCompleted).length;
    final allDone = done == sets.length;
    if (allDone && !_expanded.contains(position)) {
      return _CollapsedExercise(
        key: Key('session_exercise_collapsed_$position'),
        name: sets.first.exerciseName,
        setCount: sets.length,
        menu: _exerciseMenu(position),
        onTap: () => setState(() => _expanded.add(position)),
      );
    }
    final theme = Theme.of(context);
    return Card(
      key: Key('session_exercise_$position'),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            key: Key('session_exercise_header_$position'),
            onTap: allDone ? () => setState(() => _expanded.remove(position)) : null,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 4, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      sets.first.exerciseName,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontFamily: AppFonts.heading,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Text(
                    '$done/${sets.length}',
                    key: Key('session_exercise_progress_$position'),
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                  _exerciseMenu(position),
                ],
              ),
            ),
          ),
          const SetTableHeader(),
          for (final (index, set) in sets.indexed) ...[
            if (index > 0) const Divider(height: 1, indent: 12, endIndent: 12),
            SetRow(
              key: ValueKey(set.id),
              set: set,
              number: index + 1,
              onWeightChanged: (kg) => _notifier.setWeight(set.id!, kg),
              onRepsChanged: (reps) => _notifier.setReps(set.id!, reps),
              onToggle: () => set.isCompleted ? _uncomplete(set) : _complete(set),
            ),
          ],
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

/// Süre · set (biten/toplam) · hacim kutuları ve altında ilerleme çubuğu.
class _SessionStats extends StatelessWidget {
  const _SessionStats({required this.session, required this.now});

  final WorkoutSession session;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final done = completedSetCount(session);
    final total = session.sets.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        StatBoxRow(
          children: [
            StatBox(
              label: 'workout.session.stat_duration'.tr(),
              value: formatDuration(sessionDuration(session, now)),
              valueKey: const Key('session_elapsed'),
            ),
            StatBox(
              label: 'workout.session.stat_sets'.tr(),
              value: '$done/$total',
              valueKey: const Key('session_sets_progress'),
            ),
            StatBox(
              label: 'workout.session.stat_volume'.tr(),
              value: '${trimNumber(totalVolumeKg(session))} kg',
              valueKey: const Key('session_volume'),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            key: const Key('session_progress_bar'),
            value: total == 0 ? 0 : done / total,
            minHeight: 5,
          ),
        ),
      ],
    );
  }
}

/// Tüm setleri biten hareketin tek satırlık hâli; dokununca açılır.
class _CollapsedExercise extends StatelessWidget {
  const _CollapsedExercise({
    super.key,
    required this.name,
    required this.setCount,
    required this.menu,
    required this.onTap,
  });

  final String name;
  final int setCount;
  final Widget menu;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 4, 4),
          child: Row(
            children: [
              Expanded(
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: name,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontFamily: AppFonts.heading,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      TextSpan(
                        text: '  ·  ${'workout.session.sets_count'.tr(namedArgs: {'n': '$setCount'})}',
                        style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              DecoratedBox(
                decoration: BoxDecoration(color: scheme.primary, borderRadius: BorderRadius.circular(6)),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  child: Text(
                    '✓ ${'workout.session.done_tag'.tr()}',
                    style: theme.textTheme.labelSmall?.copyWith(color: scheme.onPrimary, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              menu,
            ],
          ),
        ),
      ),
    );
  }
}
