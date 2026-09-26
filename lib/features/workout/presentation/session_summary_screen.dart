import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../application/session_notifier.dart';
import '../application/session_providers.dart';
import '../application/workout_providers.dart';
import '../domain/block_format.dart';
import '../domain/exercise.dart';
import '../domain/progression.dart';
import '../domain/session_stats.dart';

/// Bitir → süre, set, hacim ve onaylanacak 1RM önerileri → Kaydet.
class SessionSummaryScreen extends ConsumerStatefulWidget {
  const SessionSummaryScreen({super.key, required this.sessionId});

  final String sessionId;

  @override
  ConsumerState<SessionSummaryScreen> createState() => _SessionSummaryScreenState();
}

class _SessionSummaryScreenState extends ConsumerState<SessionSummaryScreen> {
  final Set<String> _rejected = {};
  bool _saving = false;

  Future<void> _save(List<OneRepMaxSuggestion> suggestions) async {
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(sessionNotifierProvider(widget.sessionId).notifier).finish({
        for (final s in suggestions)
          if (!_rejected.contains(s.exerciseId)) s.exerciseId: s.suggestedKg,
      });
      if (mounted) context.go('/home');
    } catch (e, st) {
      debugPrint('SessionSummaryScreen.save failed: $e\n$st');
      messenger.showSnackBar(SnackBar(content: Text('workout.session.save_error'.tr())));
      if (mounted) setState(() => _saving = false);
    }
  }

  void _toggle(String exerciseId, bool? checked) {
    setState(() {
      if (checked == true) {
        _rejected.remove(exerciseId);
      } else {
        _rejected.add(exerciseId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionNotifierProvider(widget.sessionId)).value;
    final oneRepMaxes = ref.watch(oneRepMaxesProvider).value ?? const <String, double>{};
    final exercises = ref.watch(exercisesProvider).value ?? const <Exercise>[];
    if (session == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final names = {
      for (final e in exercises) e.id: e.name,
      for (final s in session.sets) s.exerciseId: s.exerciseName,
    };
    final suggestions = oneRepMaxSuggestions(sets: session.sets, oneRepMaxes: oneRepMaxes);
    final now = ref.watch(nowProvider)();
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      key: const Key('session_summary_screen'),
      appBar: AppBar(title: Text('workout.session.summary_title'.tr())),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(session.workoutName, style: textTheme.titleLarge),
          ListTile(
            key: const Key('summary_duration'),
            title: Text('workout.session.summary_duration'.tr()),
            trailing: Text(formatDuration(sessionDuration(session, now))),
          ),
          ListTile(
            key: const Key('summary_sets'),
            title: Text('workout.session.summary_sets'.tr()),
            trailing: Text('${completedSetCount(session)}'),
          ),
          ListTile(
            key: const Key('summary_volume'),
            title: Text('workout.session.summary_volume'.tr()),
            trailing: Text('${trimNumber(totalVolumeKg(session))} kg'),
          ),
          if (suggestions.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('workout.session.summary_one_rep_max'.tr(), style: textTheme.titleMedium),
            for (final s in suggestions)
              CheckboxListTile(
                key: Key('summary_1rm_${s.exerciseId}'),
                value: !_rejected.contains(s.exerciseId),
                onChanged: (checked) => _toggle(s.exerciseId, checked),
                title: Text(names[s.exerciseId] ?? s.exerciseId),
                subtitle: Text('${trimNumber(s.currentKg)} → ${trimNumber(s.suggestedKg)} kg'),
              ),
          ],
          const SizedBox(height: 24),
          FilledButton(
            key: const Key('summary_save_button'),
            onPressed: _saving ? null : () => _save(suggestions),
            child: Text('workout.session.save'.tr()),
          ),
        ],
      ),
    );
  }
}
