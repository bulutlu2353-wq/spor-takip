import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_fonts.dart';
import '../application/workout_providers.dart';
import '../domain/block_grouping.dart';
import '../domain/program.dart';
import '../domain/schedule_mode.dart';
import 'one_rep_max_sheet.dart';
import 'start_workout.dart';
import 'widgets/exercise_group_tile.dart';
import 'widgets/program_card.dart';

/// Programı aktif yapar; yüzdelik programlarda önce 1RM panelini gösterir
/// (panel atlanabilir, aktivasyon her durumda yapılır).
Future<void> activateProgram(BuildContext context, WidgetRef ref, Program program) async {
  if (program.usesPercentages) {
    await showOneRepMaxSheet(context, program);
  }
  await ref.read(programRepositoryProvider).setActiveProgram(program.id);
  ref.invalidate(activeProgramStateProvider);
}

class ProgramDetailScreen extends ConsumerWidget {
  const ProgramDetailScreen({super.key, required this.programId});

  final String programId;

  Future<void> _run(BuildContext context, Future<void> Function() action) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await action();
    } catch (e, st) {
      debugPrint('ProgramDetailScreen action failed: $e\n$st');
      messenger.showSnackBar(SnackBar(content: Text('workout.action_error'.tr())));
    }
  }

  Future<void> _customize(BuildContext context, WidgetRef ref, Program program) async {
    final newId = await ref.read(programRepositoryProvider).copyProgram(program.id!);
    ref.invalidate(programsProvider);
    if (!context.mounted) return;
    // Hazır programın detayını kopyanın detayıyla değiştir, sonra düzenleyiciyi aç:
    // düzenleyici kaydedip pop ettiğinde kullanıcı kendi kopyasının detayına döner.
    final router = GoRouter.of(context);
    router.pushReplacement('/workout/program/$newId');
    router.push('/workout/program/$newId/edit');
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, Program program) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('workout.delete_confirm_title'.tr()),
        content: Text('workout.delete_confirm_body'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text('workout.cancel'.tr()),
          ),
          TextButton(
            key: const Key('program_delete_confirm'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text('workout.delete'.tr()),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(programRepositoryProvider).deleteProgram(program.id!);
    ref.invalidate(programsProvider);
    ref.invalidate(activeProgramStateProvider);
    if (context.mounted) context.pop();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final programAsync = ref.watch(programDetailProvider(programId));
    final activeId = ref.watch(activeProgramStateProvider).value?.programId;
    final oneRepMaxes = ref.watch(oneRepMaxesProvider).value ?? const <String, double>{};

    return Scaffold(
      key: const Key('program_detail_screen'),
      appBar: AppBar(title: Text(programAsync.value?.name ?? '')),
      body: programAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('workout.detail_load_error'.tr()),
              TextButton(
                onPressed: () => ref.invalidate(programDetailProvider(programId)),
                child: Text('workout.retry'.tr()),
              ),
            ],
          ),
        ),
        data: (program) {
          final isActive = program.id == activeId;
          final theme = Theme.of(context);
          final scheme = theme.colorScheme;
          final muted = theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant);
          final heading = theme.textTheme.titleSmall?.copyWith(
            fontFamily: AppFonts.heading,
            fontWeight: FontWeight.w800,
          );
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                children: [
                  Flexible(child: Text(programDetails(program), key: const Key('program_detail_meta'), style: muted)),
                  if (isActive) ...[
                    const SizedBox(width: 8),
                    const ActiveTag(key: Key('program_active_badge')),
                  ],
                ],
              ),
              if (program.description != null) ...[
                const SizedBox(height: 8),
                Text(program.description!),
              ],
              const SizedBox(height: 16),
              if (!isActive) ...[
                FilledButton(
                  key: const Key('program_activate_button'),
                  onPressed: () => _run(context, () => activateProgram(context, ref, program)),
                  child: Text('workout.activate'.tr()),
                ),
                const SizedBox(height: 8),
              ],
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (program.isBuiltIn)
                    OutlinedButton(
                      key: const Key('program_customize_button'),
                      onPressed: () => _run(context, () => _customize(context, ref, program)),
                      child: Text('workout.customize'.tr()),
                    )
                  else
                    OutlinedButton(
                      key: const Key('program_edit_button'),
                      onPressed: () => context.push('/workout/program/${program.id}/edit'),
                      child: Text('workout.edit'.tr()),
                    ),
                  if (program.usesPercentages)
                    OutlinedButton(
                      key: const Key('program_one_rep_max_button'),
                      onPressed: () => showOneRepMaxSheet(context, program),
                      child: Text('workout.one_rep_max_button'.tr()),
                    ),
                  if (!program.isBuiltIn)
                    TextButton(
                      key: const Key('program_delete_button'),
                      style: TextButton.styleFrom(foregroundColor: scheme.error),
                      onPressed: () => _run(context, () => _delete(context, ref, program)),
                      child: Text('workout.delete'.tr()),
                    ),
                ],
              ),
              if (program.workouts.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Text('workout.no_workouts'.tr(), style: muted),
                ),
              for (final (index, workout) in program.workouts.indexed)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Card(
                    key: Key('workout_section_$index'),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 12, 4),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(workout.name, style: heading),
                                    if (program.scheduleMode == ScheduleMode.weekdays && workout.weekday != null)
                                      Text('workout.weekday_${workout.weekday}'.tr(), style: muted),
                                  ],
                                ),
                              ),
                              if (workout.exercises.isNotEmpty)
                                FilledButton(
                                  key: Key('workout_start_$index'),
                                  style: FilledButton.styleFrom(
                                    minimumSize: const Size(0, 36),
                                    padding: const EdgeInsets.symmetric(horizontal: 16),
                                  ),
                                  onPressed: () => _run(context, () => startWorkout(context, ref, program, index)),
                                  child: Text('workout.session.start'.tr()),
                                ),
                            ],
                          ),
                        ),
                        for (final (g, group) in groupBlocks(workout.exercises).indexed) ...[
                          if (g > 0) const Divider(indent: 16, endIndent: 16),
                          ExerciseGroupTile(group: group, oneRepMaxes: oneRepMaxes),
                        ],
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
