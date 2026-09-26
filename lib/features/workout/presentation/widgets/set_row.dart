import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../domain/block_format.dart';
import '../../domain/workout_session.dart';

String _weightText(SessionSet set) {
  final kg = set.displayWeightKg;
  return kg == null ? '' : trimNumber(kg);
}

String _repsText(SessionSet set) => set.displayReps?.toString() ?? '';

/// `Set n · hedef · [kilo] kg · [tekrar] · ✓`. Tamamlanmış satırın kutuları
/// kilitlidir; ✓'ye tekrar basınca işaret kalkar ve düzenlenebilir.
class SetRow extends StatefulWidget {
  const SetRow({
    super.key,
    required this.set,
    required this.number,
    required this.onWeightChanged,
    required this.onRepsChanged,
    required this.onToggle,
  });

  final SessionSet set;
  final int number;
  final ValueChanged<double?> onWeightChanged;
  final ValueChanged<int?> onRepsChanged;
  final VoidCallback onToggle;

  @override
  State<SetRow> createState() => _SetRowState();
}

class _SetRowState extends State<SetRow> {
  late final _weight = TextEditingController(text: _weightText(widget.set));
  late final _reps = TextEditingController(text: _repsText(widget.set));
  final _weightFocus = FocusNode();
  final _repsFocus = FocusNode();

  @override
  void didUpdateWidget(SetRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Başka satırdan yayılan kilo ya da geri alınan değer; yazılan kutuya dokunma.
    _sync(_weight, _weightFocus, _weightText(widget.set));
    _sync(_reps, _repsFocus, _repsText(widget.set));
  }

  void _sync(TextEditingController controller, FocusNode focus, String text) {
    if (!focus.hasFocus && controller.text != text) controller.text = text;
  }

  @override
  void dispose() {
    _weight.dispose();
    _reps.dispose();
    _weightFocus.dispose();
    _repsFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final set = widget.set;
    final done = set.isCompleted;
    final colors = Theme.of(context).colorScheme;
    return Container(
      color: done ? colors.primaryContainer.withValues(alpha: 0.4) : null,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 56,
                child: Text('workout.session.set_label'.tr(namedArgs: {'n': '${widget.number}'})),
              ),
              Expanded(child: Text(sessionSetTargetLabel(set))),
              SizedBox(
                width: 80,
                child: TextField(
                  key: Key('set_weight_${set.id}'),
                  controller: _weight,
                  focusNode: _weightFocus,
                  enabled: !done,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                  decoration: const InputDecoration(isDense: true, suffixText: 'kg'),
                  onChanged: (text) => widget.onWeightChanged(double.tryParse(text.replaceAll(',', '.'))),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 56,
                child: TextField(
                  key: Key('set_reps_${set.id}'),
                  controller: _reps,
                  focusNode: _repsFocus,
                  enabled: !done,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(isDense: true, hintText: set.isAmrap ? '+' : null),
                  onChanged: (text) => widget.onRepsChanged(int.tryParse(text)),
                ),
              ),
              IconButton(
                key: Key('set_check_${set.id}'),
                onPressed: widget.onToggle,
                color: done ? colors.primary : null,
                icon: Icon(done ? Icons.check_circle : Icons.check_circle_outline),
              ),
            ],
          ),
          if (set.deloaded && !done)
            Text(
              'workout.session.deloaded'.tr(),
              key: Key('set_deloaded_${set.id}'),
              style: Theme.of(context).textTheme.bodySmall,
            ),
        ],
      ),
    );
  }
}
