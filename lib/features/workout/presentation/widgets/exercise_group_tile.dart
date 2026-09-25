import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../domain/block_format.dart';
import '../../domain/block_grouping.dart';
import '../../domain/workout_exercise.dart';

/// Bir hareket başlığı + altında art arda gelen blokları.
class ExerciseGroupTile extends StatelessWidget {
  const ExerciseGroupTile({super.key, required this.group, required this.oneRepMaxes});

  final ExerciseGroup group;
  final Map<String, double> oneRepMaxes;

  String _line(WorkoutExercise block) {
    final parts = [
      setsRepsLabel(block),
      ?loadLabel(block, oneRepMaxes[block.oneRepMaxExerciseId]),
      if (block.restSeconds != null)
        'workout.rest_seconds'.tr(namedArgs: {'seconds': '${block.restSeconds}'}),
      ?block.notes,
    ];
    return parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(group.exerciseName),
      subtitle: Text(group.blocks.map(_line).join('\n')),
    );
  }
}
