import 'package:flutter_test/flutter_test.dart';
import 'package:spor_takip/features/workout/domain/exercise_taxonomy.dart';
import 'package:spor_takip/features/workout/domain/muscle_map_data.dart';

const _arity = {0: 2, 1: 2, 2: 6, 3: 4, 4: 0};

void _expectWellFormed(List<double> commands, String label) {
  expect(commands, isNotEmpty, reason: label);
  expect(commands.first, 0, reason: '$label starts with M');
  var i = 0;
  while (i < commands.length) {
    final code = commands[i].toInt();
    expect(commands[i], code.toDouble(), reason: '$label: code at $i is an integer');
    expect(_arity.containsKey(code), isTrue, reason: '$label: unknown code $code at $i');
    i += 1 + _arity[code]!;
  }
  expect(i, commands.length, reason: '$label: argument count matches the codes');
}

Set<String> _muscles(BodyFigure figure, BodyView view) => {for (final s in muscleShapes[figure]![view]!) ?s.muscle};

void main() {
  test('every taxonomy muscle is drawn in at least one view of each figure', () {
    for (final figure in BodyFigure.values) {
      final drawn = {for (final view in BodyView.values) ..._muscles(figure, view)};
      expect(drawn, unorderedEquals(muscleGroups), reason: figure.name);
    }
  });

  test('both figures offer the same muscles in each view', () {
    for (final view in BodyView.values) {
      expect(_muscles(BodyFigure.female, view), _muscles(BodyFigure.male, view), reason: view.name);
    }
  });

  test('shape counts match the source data', () {
    expect(muscleShapes[BodyFigure.male]![BodyView.front], hasLength(88));
    expect(muscleShapes[BodyFigure.male]![BodyView.back], hasLength(69));
    expect(muscleShapes[BodyFigure.female]![BodyView.front], hasLength(90));
    expect(muscleShapes[BodyFigure.female]![BodyView.back], hasLength(64));
  });

  test('silhouettes and shapes are well-formed command lists', () {
    for (final figure in BodyFigure.values) {
      for (final view in BodyView.values) {
        final label = '${figure.name}/${view.name}';
        _expectWellFormed(bodySilhouettes[figure]![view]!, '$label silhouette');
        for (final (i, shape) in muscleShapes[figure]![view]!.indexed) {
          _expectWellFormed(shape.commands, '$label shape $i (${shape.muscle})');
        }
      }
    }
  });

  test('canvas size', () {
    expect(bodyCanvasWidth, 724);
    expect(bodyCanvasHeight, 1448);
  });
}
