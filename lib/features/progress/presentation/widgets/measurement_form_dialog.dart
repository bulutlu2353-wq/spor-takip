import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../workout/application/session_providers.dart';
import '../../application/progress_providers.dart';
import '../../domain/body_measurement.dart';
import '../../domain/progress_format.dart';

/// Ölçüm ekle ya da ([existing] verilirse) düzenle.
Future<void> showMeasurementForm(BuildContext context, {BodyMeasurement? existing}) {
  return showDialog<void>(context: context, builder: (_) => MeasurementFormDialog(existing: existing));
}

class MeasurementFormDialog extends ConsumerStatefulWidget {
  const MeasurementFormDialog({super.key, this.existing});

  /// Verilirse tarih sabittir.
  final BodyMeasurement? existing;

  @override
  ConsumerState<MeasurementFormDialog> createState() => _MeasurementFormDialogState();
}

class _MeasurementFormDialogState extends ConsumerState<MeasurementFormDialog> {
  final _controllers = {for (final site in MeasurementSite.values) site: TextEditingController()};
  final _errors = <MeasurementSite, String>{};
  late DateTime _date;
  String? _formError;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _date = widget.existing?.date ?? dateOnly(ref.read(nowProvider)());
    final initial = widget.existing ?? _measurementOn(_date);
    if (initial != null) _fill(initial);
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  /// Aynı tarihte kayıt varsa form onun değerleriyle açılır (spec §5.4).
  BodyMeasurement? _measurementOn(DateTime date) =>
      ref.read(measurementsProvider).value?.where((m) => m.date == date).firstOrNull;

  void _fill(BodyMeasurement measurement) {
    for (final site in MeasurementSite.values) {
      final value = measurement.values[site];
      _controllers[site]!.text = value == null ? '' : formatOneDecimal(value);
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: dateOnly(ref.read(nowProvider)()), // gelecek tarih seçilemez
    );
    if (picked == null || !mounted) return;
    setState(() {
      _date = dateOnly(picked);
      // Yazılmış değerler, yalnızca o günün kaydı varsa onunla değiştirilir.
      final existing = _measurementOn(_date);
      if (existing != null) _fill(existing);
    });
  }

  Future<void> _save() async {
    final values = <MeasurementSite, double>{};
    _errors.clear();
    for (final site in MeasurementSite.values) {
      final text = _controllers[site]!.text.trim();
      if (text.isEmpty) continue;
      final value = parseDecimal(text);
      if (value == null || !isValidMeasurement(value)) {
        _errors[site] = 'progress.measurements.invalid'.tr();
      } else {
        values[site] = value;
      }
    }
    if (_errors.isNotEmpty) {
      setState(() => _formError = null);
      return;
    }
    if (values.isEmpty) {
      setState(() => _formError = 'progress.measurements.need_one'.tr());
      return;
    }
    setState(() {
      _formError = null;
      _saving = true;
    });
    try {
      await ref
          .read(bodyMeasurementRepositoryProvider)
          .saveMeasurement(BodyMeasurement(date: _date, values: values));
      ref.invalidate(measurementsProvider);
      if (mounted) Navigator.of(context).pop();
    } catch (e, st) {
      debugPrint('MeasurementFormDialog.save failed: $e\n$st');
      if (mounted) {
        setState(() {
          _formError = 'progress.save_error'.tr();
          _saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('progress.measurements.form_title'.tr()),
      content: SizedBox(
        width: 360,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextButton.icon(
                key: const Key('measurement_date_button'),
                icon: const Icon(Icons.calendar_today),
                label: Text('progress.date'.tr(namedArgs: {'date': formatShortDate(_date)})),
                onPressed: widget.existing == null && !_saving ? _pickDate : null,
              ),
              for (final site in MeasurementSite.values)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: TextField(
                    key: Key('measurement_field_${site.name}'),
                    controller: _controllers[site],
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'progress.sites.${site.name}'.tr(),
                      suffixText: 'cm',
                      errorText: _errors[site],
                      isDense: true,
                    ),
                  ),
                ),
              if (_formError != null)
                Text(
                  _formError!,
                  key: const Key('measurement_form_error'),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: Text('progress.cancel'.tr()),
        ),
        FilledButton(
          key: const Key('measurement_save_button'),
          onPressed: _saving ? null : _save,
          child: Text('progress.save'.tr()),
        ),
      ],
    );
  }
}
