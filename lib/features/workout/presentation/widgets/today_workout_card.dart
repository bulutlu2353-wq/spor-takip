import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../application/workout_providers.dart';
import '../../domain/schedule_mode.dart';
import '../../domain/today_workout.dart';

class TodayWorkoutCard extends ConsumerWidget {
  const TodayWorkoutCard({super.key});

  /// F4'te gerçek antrenman kaydıyla değiştirilecek.
  Future<void> _complete(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final state = await ref.read(activeProgramStateProvider.future);
      await ref.read(programRepositoryProvider).setRotationPosition(state.nextRotationPosition + 1);
      ref.invalidate(activeProgramStateProvider);
    } catch (e, st) {
      debugPrint('TodayWorkoutCard complete failed: $e\n$st');
      messenger.showSnackBar(SnackBar(content: Text('workout.action_error'.tr())));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final todayAsync = ref.watch(todayWorkoutProvider);
    return Card(
      key: const Key('today_workout_card'),
      child: todayAsync.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(16),
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (error, stackTrace) => ListTile(title: Text('workout.today_load_error'.tr())),
        data: (today) => switch (today) {
          NoActiveProgram() => ListTile(
              key: const Key('today_no_program'),
              leading: const Icon(Icons.fitness_center_outlined),
              title: Text('workout.today_no_program'.tr()),
              trailing: TextButton(
                key: const Key('today_choose_program'),
                onPressed: () => context.go('/workout'),
                child: Text('workout.today_choose'.tr()),
              ),
            ),
          EmptyProgram(:final program) => ListTile(
              key: const Key('today_empty_program'),
              title: Text(program.name),
              subtitle: Text('workout.no_workouts'.tr()),
            ),
          RestDay(:final program) => ListTile(
              key: const Key('today_rest_day'),
              leading: const Icon(Icons.self_improvement),
              title: Text('workout.today_rest_day'.tr()),
              subtitle: Text(program.name),
            ),
          ScheduledWorkout(:final program, :final workout) => ListTile(
              key: const Key('today_scheduled'),
              leading: const Icon(Icons.fitness_center),
              title: Text(workout.name),
              subtitle: Text(
                '${program.scheduleMode == ScheduleMode.weekdays ? 'workout.today_label'.tr() : 'workout.next_label'.tr()}'
                ' · ${program.name}',
              ),
              onTap: () => context.push('/workout/program/${program.id}'),
              trailing: program.scheduleMode == ScheduleMode.rotation
                  ? TextButton(
                      key: const Key('today_done_button'),
                      onPressed: () => _complete(context, ref),
                      child: Text('workout.today_done'.tr()),
                    )
                  : null,
            ),
        },
      ),
    );
  }
}
