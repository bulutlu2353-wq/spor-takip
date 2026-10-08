import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:spor_takip/features/onboarding/domain/profile.dart';
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

  test('figureFor picks the female figure only for female profiles', () {
    expect(figureFor(Gender.female), BodyFigure.female);
    expect(figureFor(Gender.male), BodyFigure.male);
    expect(figureFor(Gender.unspecified), BodyFigure.male);
    expect(figureFor(null), BodyFigure.male);
  });

  test('silhouettes stay inside the figure crop and shapes on the canvas', () {
    const canvas = Rect.fromLTWH(0, 0, bodyCanvasWidth, bodyCanvasHeight);
    for (final figure in BodyFigure.values) {
      final crop = bodyCrops[figure]!;
      for (final view in BodyView.values) {
        final label = '${figure.name}/${view.name}';
        final silhouette = silhouettePath(figure, view).getBounds();
        expect(crop.intersect(silhouette), silhouette, reason: '$label silhouette inside crop');
        for (final (muscle, path) in musclePaths(figure, view)) {
          final b = path.getBounds();
          expect(canvas.intersect(b), b, reason: '$label $muscle on canvas');
        }
      }
    }
  });

  test('every drawn muscle can be tapped on both figures', () {
    for (final figure in BodyFigure.values) {
      for (final view in BodyView.values) {
        for (final muscle in musclesIn(figure, view)) {
          expect(canvasPointFor(view, muscle, figure: figure), isNotNull, reason: '${figure.name}/${view.name} $muscle');
        }
      }
    }
  });

  test('views hold the expected muscles', () {
    for (final figure in BodyFigure.values) {
      final front = musclesIn(figure, BodyView.front);
      final back = musclesIn(figure, BodyView.back);
      expect(front, containsAll(['chest', 'abdominals', 'biceps', 'quadriceps']), reason: figure.name);
      expect(front, isNot(contains('lats')), reason: figure.name);
      expect(back, containsAll(['lats', 'middle back', 'lower back', 'glutes', 'abductors']), reason: figure.name);
      expect(back, isNot(contains('chest')), reason: figure.name);
      expect({...front, ...back}, unorderedEquals(muscleGroups), reason: figure.name);
    }
  });

  test('empty canvas and decoration parts return no muscle', () {
    for (final figure in BodyFigure.values) {
      expect(muscleAt(figure, BodyView.front, Offset.zero), isNull);
      for (final view in BodyView.values) {
        final p = decorPoint(view, figure: figure);
        expect(p, isNotNull, reason: '${figure.name}/${view.name} has a decoration-only point');
        expect(muscleAt(figure, view, p!), isNull);
      }
    }
  });

  test('paths are cached per figure and view', () {
    expect(identical(musclePaths(BodyFigure.male, BodyView.back), musclePaths(BodyFigure.male, BodyView.back)), isTrue);
    expect(identical(musclePaths(BodyFigure.male, BodyView.back), musclePaths(BodyFigure.female, BodyView.back)), isFalse);
    expect(
      identical(silhouettePath(BodyFigure.female, BodyView.front), silhouettePath(BodyFigure.female, BodyView.front)),
      isTrue,
    );
  });

  test('BodyFit centers the male crop and round-trips points', () {
    final crop = bodyCrops[BodyFigure.male]!;
    final tall = BodyFit(const Size(322, 1000), BodyFigure.male);
    expect(tall.scale, 0.5);
    expect(tall.toLocal(crop.topLeft), const Offset(0, 187.5));

    final wide = BodyFit(const Size(1000, 625), BodyFigure.male);
    expect(wide.scale, 0.5);
    expect(wide.toLocal(crop.topLeft), const Offset(339, 0));
    final back = wide.toCanvas(wide.toLocal(const Offset(300, 700)));
    expect(back.dx, closeTo(300, 1e-9));
    expect(back.dy, closeTo(700, 1e-9));
  });

  test('BodyFit uses the female crop for the female figure', () {
    final crop = bodyCrops[BodyFigure.female]!;
    final fit = BodyFit(const Size(661, 2000), BodyFigure.female);
    expect(fit.scale, 1);
    expect(fit.toLocal(crop.topLeft), const Offset(0, 317.5));
  });
}
