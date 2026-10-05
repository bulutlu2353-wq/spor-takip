import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../shared/text_case.dart';
import '../../domain/block_format.dart';
import '../../domain/workout_session.dart';

String _weightText(SessionSet set) {
  final kg = set.displayWeightKg;
  return kg == null ? '' : trimNumber(kg);
}

String _repsText(SessionSet set) => set.displayReps?.toString() ?? '';

/// SET · HEDEF · KG · TEK. · ✓ sütun genişlikleri; başlık ve satırlar paylaşır.
abstract final class SetColumns {
  static const number = 32.0;
  static const weight = 72.0;
  static const gap = 8.0;
  static const reps = 56.0;
  static const check = 48.0;
}

/// Hareket kartındaki gri sütun başlıkları.
class SetTableHeader extends StatelessWidget {
  const SetTableHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant, letterSpacing: 1);
    final languageCode = Localizations.localeOf(context).languageCode;
    String h(String key) => upperCaseFor(key.tr(), languageCode);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 2),
      child: Row(
        children: [
          SizedBox(width: SetColumns.number, child: Text(h('workout.session.col_set'), style: style)),
          Expanded(child: Text(h('workout.session.col_target'), style: style)),
          SizedBox(
            width: SetColumns.weight,
            child: Text(h('workout.session.col_kg'), textAlign: TextAlign.center, style: style),
          ),
          const SizedBox(width: SetColumns.gap),
          SizedBox(
            width: SetColumns.reps,
            child: Text(h('workout.session.col_reps'), textAlign: TextAlign.center, style: style),
          ),
          const SizedBox(width: SetColumns.check),
        ],
      ),
    );
  }
}

/// `n · hedef · [kilo] · [tekrar] · ✓`. Tamamlanmış satırın kutuları
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
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final valueStyle = TextStyle(color: done ? colors.onSurfaceVariant : colors.onSurface, fontWeight: FontWeight.w600);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: SetColumns.number,
                child: Text('${widget.number}', key: Key('set_number_${set.id}'), style: valueStyle),
              ),
              Expanded(
                child: Text(
                  sessionSetTargetLabel(set),
                  style: TextStyle(color: done ? colors.onSurfaceVariant : colors.onSurface),
                ),
              ),
              SizedBox(
                width: SetColumns.weight,
                child: TextField(
                  key: Key('set_weight_${set.id}'),
                  controller: _weight,
                  focusNode: _weightFocus,
                  enabled: !done,
                  textAlign: TextAlign.center,
                  style: valueStyle,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                  decoration: const InputDecoration(isDense: true),
                  onChanged: (text) => widget.onWeightChanged(double.tryParse(text.replaceAll(',', '.'))),
                ),
              ),
              const SizedBox(width: SetColumns.gap),
              SizedBox(
                width: SetColumns.reps,
                child: TextField(
                  key: Key('set_reps_${set.id}'),
                  controller: _reps,
                  focusNode: _repsFocus,
                  enabled: !done,
                  textAlign: TextAlign.center,
                  style: valueStyle,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(isDense: true, hintText: set.isAmrap ? '+' : null),
                  onChanged: (text) => widget.onRepsChanged(int.tryParse(text)),
                ),
              ),
              SizedBox(
                width: SetColumns.check,
                child: IconButton(
                  key: Key('set_check_${set.id}'),
                  onPressed: widget.onToggle,
                  color: done ? colors.primary : colors.onSurfaceVariant,
                  icon: Icon(done ? Icons.check_circle : Icons.check_circle_outline),
                ),
              ),
            ],
          ),
          if (set.deloaded && !done)
            Text(
              'workout.session.deloaded'.tr(),
              key: Key('set_deloaded_${set.id}'),
              style: theme.textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
            ),
        ],
      ),
    );
  }
}
