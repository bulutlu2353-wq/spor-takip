import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../application/session_providers.dart';
import '../../application/workout_providers.dart';
import '../../domain/program.dart';
import '../../domain/schedule_mode.dart';
import '../../domain/today_workout.dart';
import '../../domain/workout_session.dart';
import '../start_workout.dart';

class TodayWorkoutCard extends ConsumerWidget {
  const TodayWorkoutCard({super.key});

  Future<void> _start(BuildContext context, WidgetRef ref, Program program, int workoutIndex) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await startWorkout(context, ref, program, workoutIndex);
    } catch (e, st) {
      debugPrint('TodayWorkoutCard start failed: $e\n$st');
      messenger.showSnackBar(SnackBar(content: Text('workout.action_error'.tr())));
    }
  }

  /// Bugün başladıysa "10:05", değilse "24.9. 10:05".
  static String _startedLabel(DateTime startedAt, DateTime now) {
    final local = startedAt.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    final time = '${two(local.hour)}:${two(local.minute)}';
    final sameDay = local.year == now.year && local.month == now.month && local.day == now.day;
    return sameDay ? time : '${local.day}.${local.month}. $time';
  }

  Widget _inProgress(BuildContext context, WorkoutSession session) {
    return ListTile(
      key: const Key('today_in_progress'),
      leading: const Icon(Icons.play_circle_outline),
      title: Text(session.workoutName),
      subtitle: Text('workout.session.started_at'.tr(
        namedArgs: {'time': _startedLabel(session.startedAt, DateTime.now())},
      )),
      trailing: FilledButton(
        key: const Key('today_resume_button'),
        onPressed: () => context.push('/session/${session.id}'),
        child: Text('workout.session.resume'.tr()),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inProgress = ref.watch(inProgressSessionProvider).value;
    final todayAsync = ref.watch(todayWorkoutProvider);
    return Card(
      key: const Key('today_workout_card'),
      child: inProgress != null
          ? _inProgress(context, inProgress)
          : todayAsync.when(
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
                ScheduledWorkout(:final program, :final workoutIndex, :final workout) => ListTile(
                    key: const Key('today_scheduled'),
                    leading: const Icon(Icons.fitness_center),
                    title: Text(workout.name),
                    subtitle: Text(
                      '${program.scheduleMode == ScheduleMode.weekdays ? 'workout.today_label'.tr() : 'workout.next_label'.tr()}'
                      ' · ${program.name}',
                    ),
                    onTap: () => context.push('/workout/program/${program.id}'),
                    trailing: FilledButton(
                      key: const Key('today_start_button'),
                      onPressed: () => _start(context, ref, program, workoutIndex),
                      child: Text('workout.session.start'.tr()),
                    ),
                  ),
              },
            ),
    );
  }
}
