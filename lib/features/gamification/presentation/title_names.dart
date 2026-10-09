import 'package:easy_localization/easy_localization.dart';

import '../../workout/domain/exercise_taxonomy.dart';
import '../../workout/domain/muscle_heat.dart';
import '../domain/titles.dart';

/// "Kanat Şampiyonu", "Barbell Squat Ustası".
String titleName(TitleProgress title, TitleTier tier) {
  final name = switch (title.kind) {
    TitleKind.muscle => 'gamification.muscle_short.${taxonomySlug(title.subjectId)}'.tr(),
    TitleKind.exercise => title.exerciseName ?? title.subjectId,
  };
  return 'gamification.title_tier.${tier.name}'.tr(namedArgs: {'name': name});
}

/// "320 / 500 set", "41 / 50 oturum"; şampiyonda yalnız değer.
String titleCriterion(TitleProgress title) {
  final isMuscle = title.kind == TitleKind.muscle;
  final value = isMuscle ? formatSets(title.value) : '${title.value.toInt()}';
  final next = title.nextThreshold;
  if (next == null) {
    return (isMuscle ? 'gamification.value_sets' : 'gamification.value_sessions').tr(namedArgs: {'value': value});
  }
  return (isMuscle ? 'gamification.criterion_sets' : 'gamification.criterion_sessions')
      .tr(namedArgs: {'value': value, 'threshold': '${next.toInt()}'});
}
