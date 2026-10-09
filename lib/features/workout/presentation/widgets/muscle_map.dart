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
  const MuscleMap({
    super.key,
    required this.view,
    this.figure = BodyFigure.male,
    this.selected,
    required this.onSelected,
  });

  final BodyView view;
  final BodyFigure figure;
  final String? selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final _MapColors colors = (
      silhouette: scheme.surfaceContainerLowest,
      outline: scheme.onSurfaceVariant.withValues(alpha: 0.6),
      decor: scheme.onSurfaceVariant.withValues(alpha: 0.25),
      muscle: scheme.onSurfaceVariant.withValues(alpha: 0.5),
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
              final muscle = muscleAt(figure, view, BodyFit(size, figure).toCanvas(details.localPosition));
              if (muscle != null) onSelected(muscle);
            },
            child: CustomPaint(
              size: size,
              painter: _MuscleMapPainter(figure: figure, view: view, selected: selected, colors: colors),
            ),
          );
        },
      ),
    );
  }
}

class _MuscleMapPainter extends CustomPainter {
  _MuscleMapPainter({required this.figure, required this.view, required this.selected, required this.colors});

  final BodyFigure figure;
  final BodyView view;
  final String? selected;
  final _MapColors colors;

  @override
  void paint(Canvas canvas, Size size) {
    final fit = BodyFit(size, figure);
    canvas.save();
    canvas.translate(fit.offset.dx, fit.offset.dy);
    canvas.scale(fit.scale);

    final silhouette = silhouettePath(figure, view);
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
    for (final (muscle, path) in musclePaths(figure, view)) {
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
  bool shouldRepaint(_MuscleMapPainter old) =>
      old.figure != figure || old.view != view || old.selected != selected || old.colors != colors;
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

/// ♂ / ♀ figür anahtarı.
class FigureToggle extends StatelessWidget {
  const FigureToggle({super.key, required this.figure, required this.onChanged});

  final BodyFigure figure;
  final ValueChanged<BodyFigure> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<BodyFigure>(
      key: const Key('figure_toggle'),
      showSelectedIcon: false,
      segments: [
        ButtonSegment(
          value: BodyFigure.male,
          tooltip: 'workout.muscle_map.figure_male'.tr(),
          label: Icon(Icons.male, key: const Key('figure_toggle_male'), semanticLabel: 'workout.muscle_map.figure_male'.tr()),
        ),
        ButtonSegment(
          value: BodyFigure.female,
          tooltip: 'workout.muscle_map.figure_female'.tr(),
          label: Icon(
            Icons.female,
            key: const Key('figure_toggle_female'),
            semanticLabel: 'workout.muscle_map.figure_female'.tr(),
          ),
        ),
      ],
      selected: {figure},
      onSelectionChanged: (selection) => onChanged(selection.first),
    );
  }
}

/// Solda ÖN/ARKA, sağda ♂/♀ (ekran ve alt sayfa ortak).
class MuscleMapControls extends StatelessWidget {
  const MuscleMapControls({
    super.key,
    required this.view,
    required this.onViewChanged,
    required this.figure,
    required this.onFigureChanged,
  });

  final BodyView view;
  final ValueChanged<BodyView> onViewChanged;
  final BodyFigure figure;
  final ValueChanged<BodyFigure> onFigureChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Dar ekranda (ya da uzun çeviride) taşmak yerine küçülür.
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: BodyViewToggle(view: view, onChanged: onViewChanged),
          ),
        ),
        const SizedBox(width: 12),
        FigureToggle(figure: figure, onChanged: onFigureChanged),
      ],
    );
  }
}

/// Figürü saran noktalı koyu kart; [label] sol üstte seçili kas hapı. Sınırlı yükseklik ister.
class MuscleMapCard extends StatelessWidget {
  const MuscleMapCard({super.key, required this.child, this.label});

  final Widget child;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final label = this.label;
    return ClipRRect(
      borderRadius: const BorderRadius.all(Radius.circular(16)),
      child: ColoredBox(
        color: theme.cardTheme.color ?? scheme.surfaceContainer,
        child: Stack(
          children: [
            Positioned.fill(child: CustomPaint(painter: _DotGridPainter(scheme.outlineVariant))),
            Positioned.fill(child: Padding(padding: const EdgeInsets.all(12), child: child)),
            if (label != null)
              Positioned(
                left: 12,
                top: 12,
                child: Container(
                  key: const Key('muscle_map_card_label'),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: theme.scaffoldBackgroundColor,
                    borderRadius: const BorderRadius.all(Radius.circular(999)),
                    border: Border.all(color: scheme.primary.withValues(alpha: 0.6)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.circle, size: 8, color: scheme.primary),
                      const SizedBox(width: 8),
                      Text(label, style: theme.textTheme.labelLarge),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _DotGridPainter extends CustomPainter {
  _DotGridPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color.withValues(alpha: 0.5);
    for (var y = 8.0; y < size.height; y += 16) {
      for (var x = 8.0; x < size.width; x += 16) {
        canvas.drawCircle(Offset(x, y), 1, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DotGridPainter old) => old.color != color;
}
