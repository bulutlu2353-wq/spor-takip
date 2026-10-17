import 'package:easy_localization/easy_localization.dart';

import '../../../workout/domain/exercise_taxonomy.dart';
import '../../domain/quests.dart';

/// "5 gün öğün kaydet" (O4 spec §6).
String questText(QuestKind kind, {required double target, String? muscle}) {
  final n = '${target.toInt()}';
  return switch (kind) {
    QuestKind.workouts => 'gamification.quest_workouts'.tr(namedArgs: {'n': n}),
    QuestKind.sets => 'gamification.quest_sets'.tr(namedArgs: {'n': n}),
    QuestKind.volume => 'gamification.quest_volume'.tr(namedArgs: {'n': n}),
    QuestKind.long => 'gamification.quest_long'.tr(namedArgs: {'n': n}),
    QuestKind.record => 'gamification.quest_record'.tr(),
    QuestKind.muscle =>
      'gamification.quest_muscle'.tr(namedArgs: {'n': n, 'muscle': muscleLabelKey(muscle ?? '').tr()}),
    QuestKind.variety => 'gamification.quest_variety'.tr(namedArgs: {'n': n}),
    QuestKind.weekend => 'gamification.quest_weekend'.tr(),
    QuestKind.mealDays => 'gamification.quest_meal_days'.tr(namedArgs: {'n': n}),
    QuestKind.fullDays => 'gamification.quest_full_days'.tr(namedArgs: {'n': n}),
  };
}
