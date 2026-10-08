import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../domain/muscle_map.dart';
import 'muscle_map.dart';

/// Haritadan kas seçtirir; kasa dokununca o kas, kapatılırsa null döner.
Future<String?> showMuscleMapSheet(BuildContext context, {String? selected}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _MuscleMapSheet(selected: selected),
  );
}

class _MuscleMapSheet extends StatefulWidget {
  const _MuscleMapSheet({required this.selected});

  final String? selected;

  @override
  State<_MuscleMapSheet> createState() => _MuscleMapSheetState();
}

class _MuscleMapSheetState extends State<_MuscleMapSheet> {
  BodyView _view = BodyView.front;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            BodyViewToggle(view: _view, onChanged: (v) => setState(() => _view = v)),
            const SizedBox(height: 8),
            SizedBox(
              height: MediaQuery.sizeOf(context).height * 0.6,
              child: MuscleMap(
                view: _view,
                selected: widget.selected,
                onSelected: (muscle) => Navigator.of(context).pop(muscle),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'workout.muscle_map.hint'.tr(),
              key: const Key('muscle_map_sheet_hint'),
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
