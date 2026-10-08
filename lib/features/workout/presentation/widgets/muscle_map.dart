import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../domain/muscle_map.dart';

typedef _MapColors = ({
  Color silhouette,
  Color outline,
  Color decor,
  Color muscle,
  Color selected,
  Color edge,
});

/// Ön ya da arka vücut figürü; kasa dokununca [onSelected]. Sınırlı boyut ister.
class MuscleMap extends StatelessWidget {
  const MuscleMap({super.key, required this.view, this.selected, required this.onSelected});

  final BodyView view;
  final String? selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final _MapColors colors = (
      silhouette: scheme.surfaceContainerLowest,
      outline: scheme.outlineVariant,
      decor: scheme.surfaceContainer,
      muscle: scheme.surfaceContainerHighest,
      selected: scheme.primary,
      edge: theme.scaffoldBackgroundColor,
    );
    return Semantics(
      label: 'workout.muscle_map.title'.tr(),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = constraints.biggest;
          return GestureDetector(
            key: Key('muscle_map_${view.name}'),
            behavior: HitTestBehavior.opaque,
            onTapUp: (details) {
              final muscle = muscleAt(view, BodyFit(size).toCanvas(details.localPosition));
              if (muscle != null) onSelected(muscle);
            },
            child: CustomPaint(size: size, painter: _MuscleMapPainter(view: view, selected: selected, colors: colors)),
          );
        },
      ),
    );
  }
}

class _MuscleMapPainter extends CustomPainter {
  _MuscleMapPainter({required this.view, required this.selected, required this.colors});

  final BodyView view;
  final String? selected;
  final _MapColors colors;

  @override
  void paint(Canvas canvas, Size size) {
    final fit = BodyFit(size);
    canvas.save();
    canvas.translate(fit.offset.dx, fit.offset.dy);
    canvas.scale(fit.scale);

    final silhouette = silhouettePath(view);
    canvas.drawPath(silhouette, Paint()..color = colors.silhouette);
    canvas.drawPath(
      silhouette,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = colors.outline,
    );

    final edge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..color = colors.edge;
    for (final (muscle, path) in musclePaths(view)) {
      final isSelected = muscle != null && muscle == selected;
      if (isSelected) {
        canvas.drawPath(
          path,
          Paint()
            ..color = colors.selected.withValues(alpha: 0.6)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
        );
      }
      final fill = isSelected ? colors.selected : (muscle == null ? colors.decor : colors.muscle);
      canvas.drawPath(path, Paint()..color = fill);
      canvas.drawPath(path, edge);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_MuscleMapPainter old) => old.view != view || old.selected != selected || old.colors != colors;
}

/// ÖN / ARKA anahtarı (ekran ve alt sayfa ortak).
class BodyViewToggle extends StatelessWidget {
  const BodyViewToggle({super.key, required this.view, required this.onChanged});

  final BodyView view;
  final ValueChanged<BodyView> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<BodyView>(
      key: const Key('muscle_map_view_toggle'),
      showSelectedIcon: false,
      segments: [
        ButtonSegment(value: BodyView.front, label: Text('workout.muscle_map.front'.tr())),
        ButtonSegment(value: BodyView.back, label: Text('workout.muscle_map.back'.tr())),
      ],
      selected: {view},
      onSelectionChanged: (selection) => onChanged(selection.first),
    );
  }
}
