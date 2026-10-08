import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../onboarding/application/profile_providers.dart';
import '../domain/muscle_map.dart';

/// Haritada elle seçilen figür; null = seçilmedi. Uygulama açık kaldıkça sürer, saklanmaz (K2 spec §5.2).
class MapFigureChoice extends Notifier<BodyFigure?> {
  @override
  BodyFigure? build() => null;

  void choose(BodyFigure figure) => state = figure;
}

final mapFigureChoiceProvider = NotifierProvider<MapFigureChoice, BodyFigure?>(MapFigureChoice.new);

/// Haritada gösterilecek figür: elle seçim, yoksa profil cinsiyetinden (yüklenirken/hata/null → erkek).
final mapFigureProvider = Provider<BodyFigure>((ref) {
  return ref.watch(mapFigureChoiceProvider) ?? figureFor(ref.watch(profileProvider).value?.gender);
});
