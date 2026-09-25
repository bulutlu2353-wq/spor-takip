import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/workout_providers.dart';
import '../domain/program.dart';

Future<bool> showOneRepMaxSheet(BuildContext context, Program program) async {
  final saved = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _OneRepMaxSheet(program: program),
  );
  return saved ?? false;
}

class _OneRepMaxSheet extends ConsumerStatefulWidget {
  const _OneRepMaxSheet({required this.program});

  final Program program;

  @override
  ConsumerState<_OneRepMaxSheet> createState() => _OneRepMaxSheetState();
}

class _OneRepMaxSheetState extends ConsumerState<_OneRepMaxSheet> {
  late final List<String> _ids = widget.program.oneRepMaxExerciseIds.toList()..sort();
  late final Map<String, TextEditingController> _controllers = {
    for (final id in _ids) id: TextEditingController(),
  };
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      try {
        final existing = await ref.read(oneRepMaxRepositoryProvider).fetchOneRepMaxes();
        if (!mounted) return;
        for (final id in _ids) {
          final kg = existing[id];
          if (kg != null && _controllers[id]!.text.isEmpty) {
            _controllers[id]!.text = kg == kg.roundToDouble() ? '${kg.toInt()}' : '$kg';
          }
        }
      } catch (e, st) {
        debugPrint('OneRepMaxSheet fetch failed: $e\n$st');
        if (!mounted) return;
        setState(() => _error = 'workout.action_error'.tr());
      }
    });
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  /// Blok adlarından, yoksa hareket kütüphanesinden, o da yoksa id'den okunur ad.
  String _nameOf(String id) {
    for (final w in widget.program.workouts) {
      for (final b in w.exercises) {
        if (b.exerciseId == id) return b.exerciseName;
      }
    }
    final library = ref.read(exercisesProvider).value ?? const [];
    return library.where((e) => e.id == id).firstOrNull?.name ?? id.replaceAll('_', ' ');
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    final repo = ref.read(oneRepMaxRepositoryProvider);
    try {
      for (final id in _ids) {
        final kg = double.tryParse(_controllers[id]!.text.trim().replaceAll(',', '.'));
        if (kg != null && kg > 0) await repo.saveOneRepMax(exerciseId: id, weightKg: kg);
      }
      ref.invalidate(oneRepMaxesProvider);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e, st) {
      debugPrint('OneRepMaxSheet save failed: $e\n$st');
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'workout.action_error'.tr();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: const Key('one_rep_max_sheet'),
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('workout.one_rep_max_title'.tr(), style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text('workout.one_rep_max_body'.tr()),
            for (final id in _ids)
              TextField(
                key: Key('one_rep_max_field_$id'),
                controller: _controllers[id],
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'workout.one_rep_max_kg'.tr(namedArgs: {'name': _nameOf(id)}),
                ),
              ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
            const SizedBox(height: 16),
            OverflowBar(
              alignment: MainAxisAlignment.end,
              spacing: 8,
              children: [
                TextButton(
                  key: const Key('one_rep_max_skip'),
                  onPressed: _saving ? null : () => Navigator.of(context).pop(false),
                  child: Text('workout.one_rep_max_skip'.tr()),
                ),
                FilledButton(
                  key: const Key('one_rep_max_save'),
                  onPressed: _saving ? null : _save,
                  child: Text('workout.one_rep_max_save'.tr()),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
