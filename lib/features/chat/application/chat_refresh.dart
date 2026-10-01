import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../nutrition/application/today_meals_provider.dart';
import '../../onboarding/application/profile_providers.dart';
import '../../progress/application/progress_providers.dart';
import '../../workout/application/session_notifier.dart';
import '../../workout/application/session_providers.dart';
import '../../workout/application/workout_providers.dart';
import '../domain/chat_models.dart';

/// Sohbetten uygulanan / geri alınan bir değişiklikten sonra etkilenen
/// ekranların verisini yeniler (spec §5.4).
void refreshAfterChatChange(Ref ref, ChatEvent event) {
  switch (event.tool) {
    case ChatTool.logBodyWeight:
      ref
        ..invalidate(weightLogsProvider)
        ..invalidate(profileProvider);
    case ChatTool.updateProfile || ChatTool.setGoal:
      ref.invalidate(profileProvider);
    case ChatTool.createMeal:
      ref
        ..invalidate(todayMealsProvider)
        ..invalidate(weeklyMealsProvider);
    case ChatTool.logSet:
      ref
        ..invalidate(inProgressSessionProvider)
        ..invalidate(sessionNotifierProvider(event.payload['session_id'] as String));
    case ChatTool.editProgram:
      ref
        ..invalidate(programsProvider)
        ..invalidate(programDetailProvider(event.payload['program_id'] as String));
  }
}
