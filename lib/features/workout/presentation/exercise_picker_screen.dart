import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/text_case.dart';
import '../../../shared/widgets/accent_chip.dart';
import '../application/workout_providers.dart';
import '../data/exercise_repository.dart';
import '../domain/exercise.dart';
import '../domain/exercise_filter.dart';
import '../domain/exercise_taxonomy.dart';
import 'widgets/exercise_detail_sheet.dart';
import 'widgets/exercise_icon_badge.dart';
import 'widgets/muscle_map_sheet.dart';

class ExercisePickerScreen extends ConsumerStatefulWidget {
  const ExercisePickerScreen({super.key});

  @override
  ConsumerState<ExercisePickerScreen> createState() => _ExercisePickerScreenState();
}

class _ExercisePickerScreenState extends ConsumerState<ExercisePickerScreen> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  String _query = '';
  String? _muscle;
  String? _equipment;

  void _snack(String message) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));

  Future<void> _openDetail(Exercise exercise) async {
    final selected = await showExerciseDetailSheet(context, exercise);
    if (selected == true && mounted) context.pop(exercise);
  }

  Future<void> _pickFromMap() async {
    final muscle = await showMuscleMapSheet(context, selected: _muscle);
    if (muscle != null && mounted) setState(() => _muscle = muscle);
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
      appBar: AppBar(
        title: Text(
          upperCaseFor('workout.picker_title'.tr(), context.locale.languageCode),
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        key: const Key('exercise_create_fab'),
        tooltip: 'workout.custom_exercise_title'.tr(),
        onPressed: _createCustom,
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              key: const Key('exercise_search_field'),
              controller: _search,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: 'workout.picker_search'.tr(),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        key: const Key('exercise_search_clear'),
                        tooltip: 'workout.picker_search_clear'.tr(),
                        icon: const Icon(Icons.cancel_outlined),
                        onPressed: () {
                          _search.clear();
                          setState(() => _query = '');
                        },
                      ),
                enabledBorder: _pill(Theme.of(context).colorScheme.outlineVariant, 1),
                focusedBorder: _pill(Theme.of(context).colorScheme.primary, 2),
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
            leading: ActionChip(
              key: const Key('muscle_filter_map'),
              avatar: Icon(Icons.accessibility_new, size: 18, color: Theme.of(context).colorScheme.primary),
              label: Text(
                'workout.muscle_map.pick_from_map'.tr(),
                style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w600),
              ),
              side: BorderSide(color: Theme.of(context).colorScheme.primary),
              onPressed: _pickFromMap,
            ),
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
                final theme = Theme.of(context);
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                      child: Text(
                        upperCaseFor(
                          'workout.picker_count'.tr(namedArgs: {'n': '${results.length}'}),
                          context.locale.languageCode,
                        ),
                        key: const Key('exercise_picker_count'),
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 88),
                        itemCount: results.length,
                        separatorBuilder: (context, index) => ColoredBox(
                          color: _cardColor(theme),
                          child: const Divider(height: 1, indent: 72, endIndent: 16),
                        ),
                        itemBuilder: (context, index) => _tile(context, results[index], index, results.length),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  static OutlineInputBorder _pill(Color color, double width) => OutlineInputBorder(
        borderRadius: const BorderRadius.all(Radius.circular(28)),
        borderSide: BorderSide(color: color, width: width),
      );

  static Color _cardColor(ThemeData theme) => theme.cardTheme.color ?? theme.colorScheme.surfaceContainer;

  /// Kart görünümlü satır: ilk ve son satır yuvarlak köşeli (liste tembel kalır).
  Widget _tile(BuildContext context, Exercise e, int index, int count) {
    final theme = Theme.of(context);
    const radius = Radius.circular(16);
    return Material(
      color: _cardColor(theme),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: index == 0 ? radius : Radius.zero,
          bottom: index == count - 1 ? radius : Radius.zero,
        ),
      ),
      child: ListTile(
        key: Key('exercise_tile_${e.id}'),
        leading: ExerciseIconBadge(equipment: e.equipment),
        title: Row(
          children: [
            Flexible(child: Text(e.name, overflow: TextOverflow.ellipsis)),
            if (e.isCustom) ...[
              const SizedBox(width: 8),
              Container(
                key: Key('exercise_custom_badge_${e.id}'),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.12),
                  borderRadius: const BorderRadius.all(Radius.circular(999)),
                  border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.6)),
                ),
                child: Text(
                  upperCaseFor('workout.custom_badge_short'.tr(), context.locale.languageCode),
                  style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.primary, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ],
        ),
        subtitle: Text(e.primaryMuscles.map((m) => muscleLabelKey(m).tr()).join(' · ')),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => _openDetail(e),
        onLongPress: e.isCustom ? () => _deleteCustom(e) : null,
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
    Widget? leading,
  }) {
    return SizedBox(
      height: 48,
      child: ListView(
        key: Key(rowKey),
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: [
          if (leading != null) Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: leading),
          for (final v in values)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: AccentChip(
                key: Key('$keyPrefix${taxonomySlug(v)}'),
                label: label(v),
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
