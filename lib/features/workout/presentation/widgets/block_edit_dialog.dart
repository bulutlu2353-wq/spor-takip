import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../domain/workout_exercise.dart';

Future<WorkoutExercise?> showBlockEditDialog(BuildContext context, WorkoutExercise block) {
  return showDialog<WorkoutExercise>(
    context: context,
    builder: (_) => _BlockEditDialog(block: block),
  );
}

class _BlockEditDialog extends StatefulWidget {
  const _BlockEditDialog({required this.block});

  final WorkoutExercise block;

  @override
  State<_BlockEditDialog> createState() => _BlockEditDialogState();
}

class _BlockEditDialogState extends State<_BlockEditDialog> {
  late final _sets = TextEditingController(text: '${widget.block.sets}');
  late final _repsMin = TextEditingController(text: '${widget.block.repsMin}');
  late final _repsMax = TextEditingController(text: '${widget.block.repsMax}');
  late final _percent = TextEditingController(text: widget.block.percent1rm?.toString() ?? '');
  late final _rest = TextEditingController(text: widget.block.restSeconds?.toString() ?? '');
  late bool _amrap = widget.block.isAmrap;
  bool _invalid = false;

  @override
  void dispose() {
    for (final c in [_sets, _repsMin, _repsMax, _percent, _rest]) {
      c.dispose();
    }
    super.dispose();
  }

  void _submit() {
    final sets = int.tryParse(_sets.text.trim());
    final repsMin = int.tryParse(_repsMin.text.trim());
    final repsMax = int.tryParse(_repsMax.text.trim());
    final percentText = _percent.text.trim().replaceAll(',', '.');
    final percent = percentText.isEmpty ? null : double.tryParse(percentText);
    final restText = _rest.text.trim();
    final rest = restText.isEmpty ? null : int.tryParse(restText);

    final valid = sets != null &&
        sets > 0 &&
        repsMin != null &&
        repsMin > 0 &&
        repsMax != null &&
        repsMax >= repsMin &&
        (percentText.isEmpty || (percent != null && percent > 0 && percent <= 100)) &&
        (restText.isEmpty || (rest != null && rest >= 0));
    if (!valid) {
      setState(() => _invalid = true);
      return;
    }
    Navigator.of(context).pop(widget.block.copyWith(
      sets: sets,
      repsMin: repsMin,
      repsMax: repsMax,
      isAmrap: _amrap,
      percent1rm: percent,
      clearPercent1rm: percent == null,
      restSeconds: rest,
      clearRestSeconds: rest == null,
    ));
  }

  Widget _field(Key key, TextEditingController controller, String label) {
    return TextField(
      key: key,
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(labelText: label),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('${widget.block.exerciseName} — ${'workout.block_title'.tr()}'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _field(const Key('block_sets_field'), _sets, 'workout.block_sets'.tr()),
            _field(const Key('block_reps_min_field'), _repsMin, 'workout.block_reps_min'.tr()),
            _field(const Key('block_reps_max_field'), _repsMax, 'workout.block_reps_max'.tr()),
            _field(const Key('block_percent_field'), _percent, 'workout.block_percent'.tr()),
            _field(const Key('block_rest_field'), _rest, 'workout.block_rest'.tr()),
            SwitchListTile(
              key: const Key('block_amrap_switch'),
              contentPadding: EdgeInsets.zero,
              title: Text('workout.block_amrap'.tr()),
              value: _amrap,
              onChanged: (v) => setState(() => _amrap = v),
            ),
            if (_invalid)
              Text(
                'workout.block_invalid'.tr(),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: Text('workout.cancel'.tr())),
        FilledButton(
          key: const Key('block_save_button'),
          onPressed: _submit,
          child: Text('workout.ok'.tr()),
        ),
      ],
    );
  }
}
