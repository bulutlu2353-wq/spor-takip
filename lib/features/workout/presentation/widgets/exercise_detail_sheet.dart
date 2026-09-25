import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../domain/exercise.dart';
import '../../domain/exercise_taxonomy.dart';

Future<bool?> showExerciseDetailSheet(BuildContext context, Exercise exercise, {bool selectable = true}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _ExerciseDetailSheet(exercise: exercise, selectable: selectable),
  );
}

class _ExerciseDetailSheet extends StatelessWidget {
  const _ExerciseDetailSheet({required this.exercise, required this.selectable});

  final Exercise exercise;
  final bool selectable;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.8,
      builder: (context, controller) => ListView(
        controller: controller,
        padding: const EdgeInsets.all(16),
        children: [
          Text(exercise.name, style: theme.textTheme.titleLarge),
          const SizedBox(height: 12),
          if (exercise.imageUrls.isNotEmpty)
            SizedBox(
              height: 160,
              child: Row(
                children: [
                  for (final url in exercise.imageUrls)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Image.network(
                          url,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) => const Icon(
                            Icons.image_not_supported_outlined,
                            key: Key('exercise_image_fallback'),
                            size: 48,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          const SizedBox(height: 12),
          if (exercise.primaryMuscles.isNotEmpty) ...[
            Text('workout.picker_primary_muscles'.tr(), style: theme.textTheme.titleSmall),
            Text(exercise.primaryMuscles.map((m) => muscleLabelKey(m).tr()).join(', ')),
            const SizedBox(height: 12),
          ],
          if (exercise.instructions.isNotEmpty) ...[
            Text('workout.picker_instructions'.tr(), style: theme.textTheme.titleSmall),
            for (final (i, step) in exercise.instructions.indexed)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text('${i + 1}. $step'),
              ),
          ],
          if (selectable) ...[
            const SizedBox(height: 16),
            FilledButton(
              key: const Key('exercise_select_button'),
              onPressed: () => Navigator.of(context).pop(true),
              child: Text('workout.picker_select'.tr()),
            ),
          ],
        ],
      ),
    );
  }
}
