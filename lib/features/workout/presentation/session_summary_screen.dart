import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_fonts.dart';
import '../../../shared/text_case.dart';
import '../../../shared/widgets/section_header.dart';
import '../../../shared/widgets/stat_box.dart';
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

  void _toggle(String exerciseId, bool accepted) {
    setState(() {
      if (accepted) {
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
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      key: const Key('session_summary_screen'),
      appBar: AppBar(title: Text('workout.session.summary_title'.tr())),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: FilledButton(
            key: const Key('summary_save_button'),
            onPressed: _saving ? null : () => _save(suggestions),
            child: Text('workout.session.save'.tr()),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            upperCaseFor('workout.session.summary_done'.tr(), Localizations.localeOf(context).languageCode),
            style: theme.textTheme.labelMedium?.copyWith(color: scheme.onSurfaceVariant, letterSpacing: 1),
          ),
          const SizedBox(height: 4),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(text: session.workoutName),
                TextSpan(text: ' ✓', style: TextStyle(color: scheme.primary)),
              ],
            ),
            key: const Key('summary_title'),
            style: theme.textTheme.headlineMedium,
          ),
          Text(session.programName, style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
          const SizedBox(height: 16),
          StatBoxRow(
            children: [
              StatBox(
                key: const Key('summary_duration'),
                label: 'workout.session.stat_duration'.tr(),
                value: formatDuration(sessionDuration(session, now)),
              ),
              StatBox(
                key: const Key('summary_sets'),
                label: 'workout.session.stat_sets'.tr(),
                value: '${completedSetCount(session)}',
              ),
              StatBox(
                key: const Key('summary_volume'),
                label: 'workout.session.stat_volume'.tr(),
                value: '${trimNumber(totalVolumeKg(session))} kg',
              ),
            ],
          ),
          if (suggestions.isNotEmpty) ...[
            SectionHeader('workout.session.summary_one_rep_max'.tr()),
            for (final s in suggestions)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _SuggestionCard(
                  key: Key('summary_1rm_${s.exerciseId}'),
                  name: names[s.exerciseId] ?? s.exerciseId,
                  currentKg: s.currentKg,
                  suggestedKg: s.suggestedKg,
                  accepted: !_rejected.contains(s.exerciseId),
                  onChanged: (accepted) => _toggle(s.exerciseId, accepted),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

/// "Squat · 100 → 105 kg" ve onay kutusu; kartın tamamı dokunulabilir.
class _SuggestionCard extends StatelessWidget {
  const _SuggestionCard({
    super.key,
    required this.name,
    required this.currentKg,
    required this.suggestedKg,
    required this.accepted,
    required this.onChanged,
  });

  final String name;
  final double currentKg;
  final double suggestedKg;
  final bool accepted;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => onChanged(!accepted),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontFamily: AppFonts.heading,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(text: '${trimNumber(currentKg)} → '),
                          TextSpan(
                            text: '${trimNumber(suggestedKg)} kg',
                            style: TextStyle(color: scheme.primary, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                      style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              Checkbox(value: accepted, onChanged: (value) => onChanged(value ?? false)),
            ],
          ),
        ),
      ),
    );
  }
}
