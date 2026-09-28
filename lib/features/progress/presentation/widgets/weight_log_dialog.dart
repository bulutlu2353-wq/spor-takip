import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../workout/application/session_providers.dart';
import '../../application/body_weight_service.dart';
import '../../domain/body_weight_log.dart';
import '../../domain/progress_format.dart';

/// Diyaloğun kaydettikten sonra döndürdüğü sonuç.
class WeightLogResult {
  const WeightLogResult(this.newCalorieTarget);

  /// Profil güncellendiyse yeni kalori hedefi; geçmiş tarihli kayıtta null.
  final double? newCalorieTarget;
}

/// Kilo ekle ya da ([existing] verilirse) düzenle; kaydedince SnackBar gösterir.
Future<void> showWeightLogDialog(BuildContext context, {BodyWeightLog? existing}) async {
  final messenger = ScaffoldMessenger.of(context);
  final result = await showDialog<WeightLogResult>(
    context: context,
    builder: (_) => WeightLogDialog(existing: existing),
  );
  if (result == null) return;
  final target = result.newCalorieTarget;
  // Hedeflerin kendiliğinden değişmesi şaşırtmasın (spec §9).
  messenger.showSnackBar(SnackBar(
    content: Text(target == null
        ? 'progress.weight.saved'.tr()
        : 'progress.weight.saved_target'.tr(namedArgs: {'value': target.round().toString()})),
  ));
}

class WeightLogDialog extends ConsumerStatefulWidget {
  const WeightLogDialog({super.key, this.existing});

  /// Verilirse tarih sabittir (başka güne taşımak = sil + yeni kayıt).
  final BodyWeightLog? existing;

  @override
  ConsumerState<WeightLogDialog> createState() => _WeightLogDialogState();
}

class _WeightLogDialogState extends ConsumerState<WeightLogDialog> {
  late final TextEditingController _controller;
  late DateTime _date;
  String? _inputError;
  bool _saveFailed = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _date = existing?.date ?? dateOnly(ref.read(nowProvider)());
    _controller = TextEditingController(text: existing == null ? '' : formatOneDecimal(existing.weightKg));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final today = dateOnly(ref.read(nowProvider)());
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: today, // gelecek tarih seçilemez
    );
    if (picked != null && mounted) setState(() => _date = dateOnly(picked));
  }

  Future<void> _save() async {
    final kg = parseDecimal(_controller.text);
    if (kg == null || !isValidBodyWeight(kg)) {
      setState(() => _inputError = 'progress.weight.invalid'.tr());
      return;
    }
    setState(() {
      _inputError = null;
      _saveFailed = false;
      _saving = true;
    });
    try {
      final target = await ref.read(bodyWeightServiceProvider).log(date: _date, weightKg: kg);
      if (mounted) Navigator.of(context).pop(WeightLogResult(target));
    } catch (e, st) {
      debugPrint('WeightLogDialog.save failed: $e\n$st');
      if (mounted) {
        setState(() {
          _saveFailed = true;
          _saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text((widget.existing == null ? 'progress.weight.add' : 'progress.weight.edit').tr()),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            key: const Key('weight_input'),
            controller: _controller,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'progress.weight.input_label'.tr(),
              suffixText: 'kg',
              errorText: _inputError,
            ),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            key: const Key('weight_date_button'),
            icon: const Icon(Icons.calendar_today),
            label: Text('progress.date'.tr(namedArgs: {'date': formatShortDate(_date)})),
            onPressed: widget.existing == null && !_saving ? _pickDate : null,
          ),
          if (_saveFailed)
            Text(
              'progress.save_error'.tr(),
              key: const Key('weight_save_error'),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: Text('progress.cancel'.tr()),
        ),
        FilledButton(
          key: const Key('weight_save_button'),
          onPressed: _saving ? null : _save,
          child: Text('progress.save'.tr()),
        ),
      ],
    );
  }
}
