import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../application/workout_providers.dart';
import '../domain/block_grouping.dart';
import '../domain/program.dart';
import '../domain/schedule_mode.dart';
import 'widgets/exercise_group_tile.dart';

/// Programı aktif yapar. Task 12, yüzdelik programlar için önce 1RM panelini
/// gösterecek şekilde bu fonksiyonu genişletir.
Future<void> activateProgram(BuildContext context, WidgetRef ref, Program program) async {
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
    } catch (_) {
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
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (program.description != null) Text(program.description!),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (isActive)
                    Chip(
                      key: const Key('program_active_badge'),
                      avatar: const Icon(Icons.star, size: 18),
                      label: Text('workout.active_badge'.tr()),
                    )
                  else
                    FilledButton(
                      key: const Key('program_activate_button'),
                      onPressed: () => _run(context, () => activateProgram(context, ref, program)),
                      child: Text('workout.activate'.tr()),
                    ),
                  if (program.isBuiltIn)
                    OutlinedButton(
                      key: const Key('program_customize_button'),
                      onPressed: () => _run(context, () => _customize(context, ref, program)),
                      child: Text('workout.customize'.tr()),
                    )
                  else ...[
                    OutlinedButton(
                      key: const Key('program_edit_button'),
                      onPressed: () => context.push('/workout/program/${program.id}/edit'),
                      child: Text('workout.edit'.tr()),
                    ),
                    OutlinedButton(
                      key: const Key('program_delete_button'),
                      onPressed: () => _run(context, () => _delete(context, ref, program)),
                      child: Text('workout.delete'.tr()),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 16),
              if (program.workouts.isEmpty) Text('workout.no_workouts'.tr()),
              for (final (index, workout) in program.workouts.indexed)
                Card(
                  key: Key('workout_section_$index'),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ListTile(
                        title: Text(workout.name, style: Theme.of(context).textTheme.titleMedium),
                        subtitle: program.scheduleMode == ScheduleMode.weekdays && workout.weekday != null
                            ? Text('workout.weekday_${workout.weekday}'.tr())
                            : null,
                      ),
                      for (final group in groupBlocks(workout.exercises))
                        ExerciseGroupTile(group: group, oneRepMaxes: oneRepMaxes),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
