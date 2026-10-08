import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:spor_takip/features/workout/domain/exercise_taxonomy.dart';
import 'package:spor_takip/features/workout/domain/muscle_map.dart';
import 'package:spor_takip/features/workout/domain/muscle_map_data.dart';

import '../muscle_map_points.dart';

void main() {
  test('buildPath handles every command', () {
    final path = buildPath([0, 10, 10, 1, 20, 10, 2, 25, 10, 30, 15, 30, 20, 3, 30, 30, 20, 30, 4]);
    final bounds = path.getBounds();
    expect(bounds.left, 10);
    expect(bounds.top, 10);
    expect(bounds.right, closeTo(30, 0.01));
    expect(bounds.bottom, 30);
    expect(path.contains(const Offset(22, 20)), isTrue);
    expect(() => buildPath([9, 0, 0]), throwsArgumentError);
  });

  test('all paths stay on the canvas and inside the crop', () {
    const canvas = Rect.fromLTWH(0, 0, bodyCanvasWidth, bodyCanvasHeight);
    for (final view in BodyView.values) {
      final silhouette = silhouettePath(view).getBounds();
      expect(bodyCrop.intersect(silhouette), silhouette, reason: '${view.name} silhouette inside crop');
      for (final (muscle, path) in musclePaths(view)) {
        final b = path.getBounds();
        expect(canvas.intersect(b), b, reason: '${view.name} $muscle on canvas');
      }
    }
  });

  test('every drawn muscle can be tapped', () {
    for (final view in BodyView.values) {
      for (final muscle in musclesIn(view)) {
        expect(canvasPointFor(view, muscle), isNotNull, reason: '${view.name} $muscle');
      }
    }
  });

  test('views hold the expected muscles', () {
    expect(musclesIn(BodyView.front), containsAll(['chest', 'abdominals', 'biceps', 'quadriceps']));
    expect(musclesIn(BodyView.front), isNot(contains('lats')));
    expect(musclesIn(BodyView.back), containsAll(['lats', 'middle back', 'lower back', 'glutes', 'abductors']));
    expect(musclesIn(BodyView.back), isNot(contains('chest')));
    expect({...musclesIn(BodyView.front), ...musclesIn(BodyView.back)}, unorderedEquals(muscleGroups));
  });

  test('empty canvas and decoration parts return no muscle', () {
    expect(muscleAt(BodyView.front, Offset.zero), isNull);
    for (final view in BodyView.values) {
      final p = decorPoint(view);
      expect(p, isNotNull, reason: '${view.name} has a decoration-only point');
      expect(muscleAt(view, p!), isNull);
    }
  });

  test('paths are cached', () {
    expect(identical(musclePaths(BodyView.back), musclePaths(BodyView.back)), isTrue);
    expect(identical(silhouettePath(BodyView.front), silhouettePath(BodyView.front)), isTrue);
  });

  test('BodyFit centers the crop and round-trips points', () {
    final tall = BodyFit(const Size(322, 1000));
    expect(tall.scale, 0.5);
    expect(tall.toLocal(bodyCrop.topLeft), const Offset(0, 187.5));

    final wide = BodyFit(const Size(1000, 625));
    expect(wide.scale, 0.5);
    expect(wide.toLocal(bodyCrop.topLeft), const Offset(339, 0));
    final back = wide.toCanvas(wide.toLocal(const Offset(300, 700)));
    expect(back.dx, closeTo(300, 1e-9));
    expect(back.dy, closeTo(700, 1e-9));
  });
}
