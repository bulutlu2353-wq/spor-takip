import 'dart:math' as math;
import 'dart:ui';

import 'muscle_map_data.dart';

export 'muscle_map_data.dart' show BodyView;

/// İki görünümde de figürün göründüğü tuval alanı (spec §4).
const bodyCrop = Rect.fromLTWH(40, 120, 644, 1250);

/// [bodyCrop]'u bir boyuta oranı koruyarak ortalar: yerel = tuval × [scale] + [offset].
class BodyFit {
  factory BodyFit(Size size) {
    final scale = math.min(size.width / bodyCrop.width, size.height / bodyCrop.height);
    final pad = Offset((size.width - bodyCrop.width * scale) / 2, (size.height - bodyCrop.height * scale) / 2);
    return BodyFit._(scale, pad - bodyCrop.topLeft * scale);
  }

  const BodyFit._(this.scale, this.offset);

  final double scale;
  final Offset offset;

  Offset toCanvas(Offset local) => (local - offset) / scale;

  Offset toLocal(Offset canvas) => canvas * scale + offset;
}

/// Üretilen komut listesinden yol (kodlar `muscle_map_data.dart`'ta).
Path buildPath(List<double> commands) {
  final path = Path();
  final c = commands;
  var i = 0;
  while (i < c.length) {
    switch (c[i].toInt()) {
      case 0:
        path.moveTo(c[i + 1], c[i + 2]);
        i += 3;
      case 1:
        path.lineTo(c[i + 1], c[i + 2]);
        i += 3;
      case 2:
        path.cubicTo(c[i + 1], c[i + 2], c[i + 3], c[i + 4], c[i + 5], c[i + 6]);
        i += 7;
      case 3:
        path.quadraticBezierTo(c[i + 1], c[i + 2], c[i + 3], c[i + 4]);
        i += 5;
      case 4:
        path.close();
        i += 1;
      default:
        throw ArgumentError('Unknown path command ${c[i]} at $i');
    }
  }
  return path;
}

final _muscleCache = <BodyView, List<(String?, Path)>>{};
final _silhouetteCache = <BodyView, Path>{};

/// Görünümün şekilleri, kaynak (çizim) sırasıyla; süs parçalarında kas null.
List<(String?, Path)> musclePaths(BodyView view) => _muscleCache.putIfAbsent(
      view,
      () => [for (final s in muscleShapes[view]!) (s.muscle, buildPath(s.commands))],
    );

Path silhouettePath(BodyView view) => _silhouetteCache.putIfAbsent(view, () => buildPath(bodySilhouettes[view]!));

/// Tuval noktasındaki kas: üstte çizilen (sondaki) şekil önce; süs parçaları atlanır.
String? muscleAt(BodyView view, Offset canvasPoint) {
  for (final (muscle, path) in musclePaths(view).reversed) {
    if (muscle != null && path.contains(canvasPoint)) return muscle;
  }
  return null;
}

Set<String> musclesIn(BodyView view) => {for (final s in muscleShapes[view]!) ?s.muscle};
