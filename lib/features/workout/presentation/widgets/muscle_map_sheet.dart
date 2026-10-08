import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/text_case.dart';
import '../../application/muscle_map_providers.dart';
import '../../domain/exercise_taxonomy.dart';
import '../../domain/muscle_map.dart';
import 'muscle_map.dart';

/// Haritadan kas seçtirir; kasa dokununca o kas, kapatılırsa null döner.
Future<String?> showMuscleMapSheet(BuildContext context, {String? selected}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _MuscleMapSheet(selected: selected),
  );
}

class _MuscleMapSheet extends ConsumerStatefulWidget {
  const _MuscleMapSheet({required this.selected});

  final String? selected;

  @override
  ConsumerState<_MuscleMapSheet> createState() => _MuscleMapSheetState();
}

class _MuscleMapSheetState extends ConsumerState<_MuscleMapSheet> {
  BodyView _view = BodyView.front;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final figure = ref.watch(mapFigureProvider);
    final selected = widget.selected;
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.8,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      upperCaseFor('workout.muscle_map.pick_title'.tr(), context.locale.languageCode),
                      style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                    ),
                  ),
                  IconButton.filledTonal(
                    key: const Key('muscle_map_sheet_close'),
                    tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              MuscleMapControls(
                view: _view,
                onViewChanged: (v) => setState(() => _view = v),
                figure: figure,
                onFigureChanged: (f) => ref.read(mapFigureChoiceProvider.notifier).choose(f),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: MuscleMapCard(
                  label: selected == null ? null : muscleLabelKey(selected).tr(),
                  child: MuscleMap(
                    view: _view,
                    figure: figure,
                    selected: selected,
                    onSelected: (muscle) => Navigator.of(context).pop(muscle),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'workout.muscle_map.sheet_hint'.tr(),
                key: const Key('muscle_map_sheet_hint'),
                textAlign: TextAlign.center,
                style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
