import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:spor_takip/features/workout/domain/muscle_map.dart';

const _step = 4.0;

Iterable<Offset> _grid(Rect bounds) sync* {
  yield bounds.center;
  for (var y = bounds.top; y <= bounds.bottom; y += _step) {
    for (var x = bounds.left; x <= bounds.right; x += _step) {
      yield Offset(x, y);
    }
  }
}

/// [muscle]'a düşen bir tuval noktası (önce şeklin merkezi, sonra 4 birimlik ızgara).
Offset? canvasPointFor(BodyView view, String muscle, {BodyFigure figure = BodyFigure.male}) {
  for (final (m, path) in musclePaths(figure, view)) {
    if (m != muscle) continue;
    for (final p in _grid(path.getBounds())) {
      if (path.contains(p) && muscleAt(figure, view, p) == muscle) return p;
    }
  }
  return null;
}

/// Bir süs parçasının (baş, el, diz…) içinde olup hiçbir kas şeklinde olmayan nokta.
Offset? decorPoint(BodyView view, {BodyFigure figure = BodyFigure.male}) {
  final paths = musclePaths(figure, view);
  for (final (m, path) in paths) {
    if (m != null) continue;
    for (final p in _grid(path.getBounds())) {
      if (path.contains(p) && !paths.any((s) => s.$1 != null && s.$2.contains(p))) return p;
    }
  }
  return null;
}

/// [map] (MuscleMap içindeki `muscle_map_<view>` kutusu) üzerinde [muscle]'a dokunulacak genel ekran noktası.
Offset screenPointFor(
  WidgetTester tester,
  Finder map,
  BodyView view,
  String muscle, {
  BodyFigure figure = BodyFigure.male,
}) {
  final rect = tester.getRect(map);
  return rect.topLeft + BodyFit(rect.size, figure).toLocal(canvasPointFor(view, muscle, figure: figure)!);
}
