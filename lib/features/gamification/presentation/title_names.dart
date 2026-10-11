import 'package:easy_localization/easy_localization.dart';

import '../../workout/domain/exercise_taxonomy.dart';
import '../../workout/domain/muscle_heat.dart';
import '../domain/titles.dart';

/// "Kanat Şampiyonu", "Barbell Squat Ustası", "Meydan Okuma Çırağı".
String titleName(TitleProgress title, TitleTier tier) {
  final name = switch (title.kind) {
    TitleKind.muscle => 'gamification.muscle_short.${taxonomySlug(title.subjectId)}'.tr(),
    TitleKind.exercise => title.exerciseName ?? title.subjectId,
    TitleKind.challenge => 'gamification.challenge_title_name'.tr(),
  };
  return 'gamification.title_tier.${tier.name}'.tr(namedArgs: {'name': name});
}

/// "320 / 500 set", "41 / 50 oturum", "3 / 5 başarı"; şampiyonda yalnız değer.
String titleCriterion(TitleProgress title) {
  final (value, unit) = switch (title.kind) {
    TitleKind.muscle => (formatSets(title.value), 'sets'),
    TitleKind.exercise => ('${title.value.toInt()}', 'sessions'),
    TitleKind.challenge => ('${title.value.toInt()}', 'wins'),
  };
  final next = title.nextThreshold;
  if (next == null) return 'gamification.value_$unit'.tr(namedArgs: {'value': value});
  return 'gamification.criterion_$unit'.tr(namedArgs: {'value': value, 'threshold': '${next.toInt()}'});
}
