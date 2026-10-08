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

void main() {
  test('every taxonomy muscle is drawn in at least one view', () {
    final drawn = {
      for (final view in BodyView.values)
        for (final shape in muscleShapes[view]!) ?shape.muscle,
    };
    expect(drawn, unorderedEquals(muscleGroups));
  });

  test('shape counts match the source data', () {
    expect(muscleShapes[BodyView.front], hasLength(88));
    expect(muscleShapes[BodyView.back], hasLength(69));
  });

  test('silhouettes and shapes are well-formed command lists', () {
    for (final view in BodyView.values) {
      _expectWellFormed(bodySilhouettes[view]!, '${view.name} silhouette');
      for (final (i, shape) in muscleShapes[view]!.indexed) {
        _expectWellFormed(shape.commands, '${view.name} shape $i (${shape.muscle})');
      }
    }
  });

  test('canvas size', () {
    expect(bodyCanvasWidth, 724);
    expect(bodyCanvasHeight, 1448);
  });
}
