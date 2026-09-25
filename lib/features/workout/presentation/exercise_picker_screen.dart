import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../application/workout_providers.dart';
import '../data/exercise_repository.dart';
import '../domain/exercise.dart';
import '../domain/exercise_filter.dart';
import '../domain/exercise_taxonomy.dart';
import 'widgets/exercise_detail_sheet.dart';

class ExercisePickerScreen extends ConsumerStatefulWidget {
  const ExercisePickerScreen({super.key});

  @override
  ConsumerState<ExercisePickerScreen> createState() => _ExercisePickerScreenState();
}

class _ExercisePickerScreenState extends ConsumerState<ExercisePickerScreen> {
  String _query = '';
  String? _muscle;
  String? _equipment;

  void _snack(String message) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));

  Future<void> _openDetail(Exercise exercise) async {
    final selected = await showExerciseDetailSheet(context, exercise);
    if (selected == true && mounted) context.pop(exercise);
  }

  Future<void> _createCustom() async {
    final created = await showDialog<Exercise>(
      context: context,
      builder: (_) => const _CustomExerciseDialog(),
    );
    if (created == null || !mounted) return;
    ref.invalidate(exercisesProvider);
    context.pop(created);
  }

  Future<void> _deleteCustom(Exercise exercise) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('workout.custom_delete_title'.tr()),
        content: Text(exercise.name),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text('workout.cancel'.tr()),
          ),
          TextButton(
            key: const Key('custom_delete_confirm'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text('workout.delete'.tr()),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(exerciseRepositoryProvider).deleteCustomExercise(exercise.id);
      ref.invalidate(exercisesProvider);
    } on ExerciseInUseException catch (e, st) {
      debugPrint('ExercisePickerScreen.deleteCustom failed (in use): $e\n$st');
      if (!mounted) return;
      _snack('workout.exercise_in_use'.tr());
    } catch (e, st) {
      debugPrint('ExercisePickerScreen.deleteCustom failed: $e\n$st');
      if (!mounted) return;
      _snack('workout.action_error'.tr());
    }
  }

  @override
  Widget build(BuildContext context) {
    final exercisesAsync = ref.watch(exercisesProvider);

    return Scaffold(
      key: const Key('exercise_picker_screen'),
      appBar: AppBar(title: Text('workout.picker_title'.tr())),
      floatingActionButton: FloatingActionButton(
        key: const Key('exercise_create_fab'),
        tooltip: 'workout.custom_exercise_title'.tr(),
        onPressed: _createCustom,
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              key: const Key('exercise_search_field'),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: 'workout.picker_search'.tr(),
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          _chipRow(
            rowKey: 'muscle_filter_row',
            values: muscleGroups,
            selected: _muscle,
            keyPrefix: 'muscle_filter_',
            label: (m) => muscleLabelKey(m).tr(),
            onSelected: (m) => setState(() => _muscle = m),
          ),
          _chipRow(
            rowKey: 'equipment_filter_row',
            values: equipmentTypes,
            selected: _equipment,
            keyPrefix: 'equipment_filter_',
            label: (e) => equipmentLabelKey(e).tr(),
            onSelected: (e) => setState(() => _equipment = e),
          ),
          Expanded(
            child: exercisesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stackTrace) => Center(
                child: TextButton(
                  onPressed: () => ref.invalidate(exercisesProvider),
                  child: Text('workout.picker_load_error'.tr()),
                ),
              ),
              data: (all) {
                final results = filterExercises(all, query: _query, muscle: _muscle, equipment: _equipment);
                if (results.isEmpty) return Center(child: Text('workout.picker_no_results'.tr()));
                return ListView.builder(
                  padding: const EdgeInsets.only(bottom: 88),
                  itemCount: results.length,
                  itemBuilder: (context, index) {
                    final e = results[index];
                    return ListTile(
                      key: Key('exercise_tile_${e.id}'),
                      title: Text(e.name),
                      subtitle: Text([
                        ...e.primaryMuscles.map((m) => muscleLabelKey(m).tr()),
                        if (e.isCustom) 'workout.custom_exercise_badge'.tr(),
                      ].join(' · ')),
                      onTap: () => _openDetail(e),
                      onLongPress: e.isCustom ? () => _deleteCustom(e) : null,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _chipRow({
    required String rowKey,
    required List<String> values,
    required String? selected,
    required String keyPrefix,
    required String Function(String) label,
    required void Function(String?) onSelected,
  }) {
    return SizedBox(
      height: 48,
      child: ListView(
        key: Key(rowKey),
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        children: [
          for (final v in values)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: FilterChip(
                key: Key('$keyPrefix${taxonomySlug(v)}'),
                label: Text(label(v)),
                selected: selected == v,
                onSelected: (on) => onSelected(on ? v : null),
              ),
            ),
        ],
      ),
    );
  }
}

class _CustomExerciseDialog extends ConsumerStatefulWidget {
  const _CustomExerciseDialog();

  @override
  ConsumerState<_CustomExerciseDialog> createState() => _CustomExerciseDialogState();
}

class _CustomExerciseDialogState extends ConsumerState<_CustomExerciseDialog> {
  final _name = TextEditingController();
  String? _muscle;
  String? _equipment;
  bool _saving = false;
  bool _saveFailed = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty || _saving) return;
    setState(() {
      _saving = true;
      _saveFailed = false;
    });
    try {
      final created = await ref
          .read(exerciseRepositoryProvider)
          .createCustomExercise(name: name, primaryMuscle: _muscle, equipment: _equipment);
      if (mounted) Navigator.of(context).pop(created);
    } catch (e, st) {
      debugPrint('CustomExerciseDialog.save failed: $e\n$st');
      if (mounted) {
        setState(() {
          _saving = false;
          _saveFailed = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('workout.custom_exercise_title'.tr()),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            key: const Key('custom_exercise_name'),
            controller: _name,
            decoration: InputDecoration(labelText: 'workout.custom_exercise_name'.tr()),
          ),
          DropdownButton<String>(
            key: const Key('custom_exercise_muscle'),
            isExpanded: true,
            value: _muscle,
            hint: Text('workout.custom_exercise_muscle'.tr()),
            items: [
              for (final m in muscleGroups) DropdownMenuItem(value: m, child: Text(muscleLabelKey(m).tr())),
            ],
            onChanged: (m) => setState(() => _muscle = m),
          ),
          DropdownButton<String>(
            key: const Key('custom_exercise_equipment'),
            isExpanded: true,
            value: _equipment,
            hint: Text('workout.custom_exercise_equipment'.tr()),
            items: [
              for (final e in equipmentTypes) DropdownMenuItem(value: e, child: Text(equipmentLabelKey(e).tr())),
            ],
            onChanged: (e) => setState(() => _equipment = e),
          ),
          if (_saveFailed) ...[
            const SizedBox(height: 8),
            Text(
              'workout.action_error'.tr(),
              key: const Key('custom_exercise_save_error'),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: Text('workout.cancel'.tr())),
        FilledButton(
          key: const Key('custom_exercise_save'),
          onPressed: _saving ? null : _save,
          child: Text('workout.ok'.tr()),
        ),
      ],
    );
  }
}
