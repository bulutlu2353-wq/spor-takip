import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../application/program_editor_notifier.dart';
import '../application/workout_providers.dart';
import '../domain/block_format.dart';
import '../domain/exercise.dart';
import '../domain/program_workout.dart';
import '../domain/schedule_mode.dart';
import 'widgets/block_edit_dialog.dart';

enum _BlockAction { up, down, delete }

class ProgramEditorScreen extends ConsumerStatefulWidget {
  const ProgramEditorScreen({super.key, this.programId});

  /// null → boş (yeni) program.
  final String? programId;

  @override
  ConsumerState<ProgramEditorScreen> createState() => _ProgramEditorScreenState();
}

class _ProgramEditorScreenState extends ConsumerState<ProgramEditorScreen> {
  final _name = TextEditingController();
  bool _loadFailed = false;
  bool _leaving = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final notifier = ref.read(programEditorProvider.notifier);
    final id = widget.programId;
    if (id == null) {
      notifier.startBlank();
      return;
    }
    try {
      final program = await ref.read(programRepositoryProvider).fetchProgram(id);
      if (!mounted) return;
      _name.text = program.name;
      notifier.start(program);
    } catch (_) {
      if (mounted) setState(() => _loadFailed = true);
    }
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _save() async {
    final error = ref.read(programEditorProvider).validationError;
    if (error != null) {
      _snack('workout.editor_error_${error.name}'.tr());
      return;
    }
    final id = await ref.read(programEditorProvider.notifier).save();
    if (!mounted) return;
    if (id == null) {
      _snack('workout.editor_save_error'.tr());
      return;
    }
    if (widget.programId == null) {
      context.pushReplacement('/workout/program/$id');
    } else {
      context.pop();
    }
  }

  Future<void> _renameWorkout(int index, String current) async {
    final controller = TextEditingController(text: current);
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('workout.editor_rename_title'.tr()),
        content: TextField(key: const Key('rename_field'), controller: controller, autofocus: true),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text('workout.cancel'.tr()),
          ),
          FilledButton(
            key: const Key('rename_ok'),
            onPressed: () => Navigator.of(dialogContext).pop(controller.text),
            child: Text('workout.ok'.tr()),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name != null) ref.read(programEditorProvider.notifier).renameWorkout(index, name);
  }

  Future<void> _addBlock(int workoutIndex) async {
    final exercise = await context.push<Exercise>('/workout/exercises');
    if (exercise != null) ref.read(programEditorProvider.notifier).addBlock(workoutIndex, exercise);
  }

  Future<void> _editBlock(int workoutIndex, int blockIndex, ProgramWorkout workout) async {
    final updated = await showBlockEditDialog(context, workout.exercises[blockIndex]);
    if (updated != null) {
      ref.read(programEditorProvider.notifier).updateBlock(workoutIndex, blockIndex, updated);
    }
  }

  Future<bool> _confirmDiscard() async {
    final leave = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('workout.editor_discard_title'.tr()),
        content: Text('workout.editor_discard_body'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text('workout.cancel'.tr()),
          ),
          TextButton(
            key: const Key('discard_confirm'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text('workout.editor_discard'.tr()),
          ),
        ],
      ),
    );
    return leave ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(programEditorProvider);
    final notifier = ref.read(programEditorProvider.notifier);
    final draft = state.draft;

    return PopScope(
      canPop: !state.dirty || _leaving,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (!await _confirmDiscard() || !mounted) return;
        // canPop'un yeni değeri ancak yeniden çizimden sonra geçerli olur;
        // aynı karede pop edersek PopScope yine engeller ve diyalog tekrar açılır.
        setState(() => _leaving = true);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) context.pop();
        });
      },
      child: Scaffold(
        key: const Key('program_editor_screen'),
        appBar: AppBar(
          title: Text(widget.programId == null ? 'workout.editor_title_new'.tr() : 'workout.editor_title_edit'.tr()),
          actions: [
            IconButton(
              key: const Key('editor_save_button'),
              tooltip: 'workout.editor_save'.tr(),
              onPressed: state.saving || draft == null ? null : _save,
              icon: state.saving
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.check),
            ),
          ],
        ),
        body: _loadFailed
            ? Center(child: Text('workout.editor_load_error'.tr()))
            : draft == null
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                    children: [
                      TextField(
                        key: const Key('editor_name_field'),
                        controller: _name,
                        decoration: InputDecoration(labelText: 'workout.editor_name_label'.tr()),
                        onChanged: notifier.rename,
                      ),
                      const SizedBox(height: 16),
                      SegmentedButton<ScheduleMode>(
                        segments: [
                          ButtonSegment(
                            value: ScheduleMode.weekdays,
                            label: Text('workout.mode_weekdays'.tr(), key: const Key('editor_mode_weekdays')),
                          ),
                          ButtonSegment(
                            value: ScheduleMode.rotation,
                            label: Text('workout.mode_rotation'.tr(), key: const Key('editor_mode_rotation')),
                          ),
                        ],
                        selected: {draft.scheduleMode},
                        onSelectionChanged: (s) => notifier.setScheduleMode(s.single),
                      ),
                      const SizedBox(height: 16),
                      for (final (i, workout) in draft.workouts.indexed)
                        _workoutCard(i, workout, draft.workouts.length, draft.scheduleMode),
                      OutlinedButton.icon(
                        key: const Key('editor_add_workout'),
                        onPressed: () => notifier.addWorkout(
                          'workout.editor_default_workout_name'.tr(namedArgs: {'n': '${draft.workouts.length + 1}'}),
                        ),
                        icon: const Icon(Icons.add),
                        label: Text('workout.editor_add_workout'.tr()),
                      ),
                    ],
                  ),
      ),
    );
  }

  Widget _workoutCard(int i, ProgramWorkout workout, int count, ScheduleMode mode) {
    final notifier = ref.read(programEditorProvider.notifier);
    return Card(
      key: Key('editor_workout_$i'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            title: Text(workout.name, style: Theme.of(context).textTheme.titleMedium),
            trailing: Wrap(
              children: [
                IconButton(
                  key: Key('editor_workout_rename_$i'),
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () => _renameWorkout(i, workout.name),
                ),
                IconButton(
                  key: Key('editor_workout_up_$i'),
                  tooltip: 'workout.move_up'.tr(),
                  icon: const Icon(Icons.arrow_upward),
                  onPressed: i == 0 ? null : () => notifier.moveWorkout(i, i - 1),
                ),
                IconButton(
                  key: Key('editor_workout_down_$i'),
                  tooltip: 'workout.move_down'.tr(),
                  icon: const Icon(Icons.arrow_downward),
                  onPressed: i == count - 1 ? null : () => notifier.moveWorkout(i, i + 1),
                ),
                IconButton(
                  key: Key('editor_workout_delete_$i'),
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => notifier.removeWorkout(i),
                ),
              ],
            ),
          ),
          if (mode == ScheduleMode.weekdays)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: DropdownButton<int>(
                key: Key('editor_weekday_$i'),
                value: workout.weekday,
                hint: Text('workout.editor_weekday_hint'.tr()),
                items: [
                  for (var d = 1; d <= 7; d++)
                    DropdownMenuItem(
                      key: Key('weekday_option_$d'),
                      value: d,
                      child: Text('workout.weekday_$d'.tr()),
                    ),
                ],
                onChanged: (d) {
                  if (!notifier.setWeekday(i, d)) _snack('workout.editor_weekday_taken'.tr());
                },
              ),
            ),
          for (final (b, block) in workout.exercises.indexed)
            ListTile(
              key: Key('editor_block_${i}_$b'),
              title: Text(block.exerciseName),
              subtitle: Text([setsRepsLabel(block), ?loadLabel(block, null)].join(' · ')),
              onTap: () => _editBlock(i, b, workout),
              trailing: PopupMenuButton<_BlockAction>(
                key: Key('editor_block_menu_${i}_$b'),
                onSelected: (action) => switch (action) {
                  _BlockAction.up => notifier.moveBlock(i, b, b - 1),
                  _BlockAction.down => notifier.moveBlock(i, b, b + 1),
                  _BlockAction.delete => notifier.removeBlock(i, b),
                },
                itemBuilder: (_) => [
                  if (b > 0)
                    PopupMenuItem(
                      key: const Key('block_menu_up'),
                      value: _BlockAction.up,
                      child: Text('workout.move_up'.tr()),
                    ),
                  if (b < workout.exercises.length - 1)
                    PopupMenuItem(
                      key: const Key('block_menu_down'),
                      value: _BlockAction.down,
                      child: Text('workout.move_down'.tr()),
                    ),
                  PopupMenuItem(
                    key: const Key('block_menu_delete'),
                    value: _BlockAction.delete,
                    child: Text('workout.delete'.tr()),
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: TextButton.icon(
              key: Key('editor_add_block_$i'),
              onPressed: () => _addBlock(i),
              icon: const Icon(Icons.add),
              label: Text('workout.editor_add_block'.tr()),
            ),
          ),
        ],
      ),
    );
  }
}
