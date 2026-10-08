import 'dart:math' as math;
import 'dart:ui';

import '../../onboarding/domain/profile.dart';
import 'muscle_map_data.dart';

export 'muscle_map_data.dart' show BodyFigure, BodyView;

/// Figürün iki görünümde de göründüğü tuval alanı (K1 spec §4, K2 spec §4).
const bodyCrops = <BodyFigure, Rect>{
  BodyFigure.male: Rect.fromLTWH(40, 120, 644, 1250),
  BodyFigure.female: Rect.fromLTWH(-10, 78, 661, 1365),
};

/// Profil cinsiyetinden varsayılan figür: kadın → kadın; erkek, belirtilmemiş ve null → erkek.
BodyFigure figureFor(Gender? gender) => gender == Gender.female ? BodyFigure.female : BodyFigure.male;

/// Figürün kırpma alanını bir boyuta oranı koruyarak ortalar: yerel = tuval × [scale] + [offset].
class BodyFit {
  factory BodyFit(Size size, BodyFigure figure) {
    final crop = bodyCrops[figure]!;
    final scale = math.min(size.width / crop.width, size.height / crop.height);
    final pad = Offset((size.width - crop.width * scale) / 2, (size.height - crop.height * scale) / 2);
    return BodyFit._(scale, pad - crop.topLeft * scale);
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

final _muscleCache = <(BodyFigure, BodyView), List<(String?, Path)>>{};
final _silhouetteCache = <(BodyFigure, BodyView), Path>{};

/// Görünümün şekilleri, kaynak (çizim) sırasıyla; süs parçalarında kas null.
List<(String?, Path)> musclePaths(BodyFigure figure, BodyView view) => _muscleCache.putIfAbsent(
      (figure, view),
      () => [for (final s in muscleShapes[figure]![view]!) (s.muscle, buildPath(s.commands))],
    );

Path silhouettePath(BodyFigure figure, BodyView view) =>
    _silhouetteCache.putIfAbsent((figure, view), () => buildPath(bodySilhouettes[figure]![view]!));

/// Tuval noktasındaki kas: üstte çizilen (sondaki) şekil önce; süs parçaları atlanır.
String? muscleAt(BodyFigure figure, BodyView view, Offset canvasPoint) {
  for (final (muscle, path) in musclePaths(figure, view).reversed) {
    if (muscle != null && path.contains(canvasPoint)) return muscle;
  }
  return null;
}

Set<String> musclesIn(BodyFigure figure, BodyView view) => {for (final s in muscleShapes[figure]![view]!) ?s.muscle};
