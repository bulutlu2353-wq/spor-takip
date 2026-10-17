import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spor_takip/features/gamification/application/gamification_providers.dart';
import 'package:spor_takip/features/gamification/application/xp_event_providers.dart';
import 'package:spor_takip/features/gamification/domain/game_settings.dart';
import 'package:spor_takip/features/nutrition/domain/meal.dart';
import 'package:spor_takip/features/nutrition/domain/meal_type.dart';
import 'package:spor_takip/features/onboarding/application/auth_providers.dart';
import 'package:spor_takip/features/onboarding/application/profile_providers.dart';
import 'package:spor_takip/features/progress/application/progress_providers.dart';
import 'package:spor_takip/features/social/application/challenge_providers.dart';
import 'package:spor_takip/features/workout/application/workout_providers.dart';
import 'package:spor_takip/features/workout/domain/today_workout.dart';

import '../../progress/fakes.dart';
import '../../progress/fixtures.dart';
import '../../workout/fakes.dart';
import '../game_fixtures.dart';

Meal _meal(String id, DateTime loggedAt) =>
    Meal(id: id, userId: 'user-1', mealType: MealType.lunch, loggedAt: loggedAt, items: const []);

ProviderContainer _container({String? userId}) {
  final container = ProviderContainer(overrides: [
    isLoggedInProvider.overrideWithValue(true),
    currentUserIdProvider.overrideWithValue(userId),
    todayWorkoutProvider.overrideWith((ref) async => const NoActiveProgram()),
    profileProvider.overrideWith((ref) async => testProfile),
    challengeRewardsProvider.overrideWith((ref) async => const []),
    progressDataRepositoryProvider.overrideWithValue(FakeProgressDataRepository(
      sessions: [gameSession('a', DateTime(2026, 10, 1, 18), gameSets('bench', 3))],
      meals: [_meal('m1', DateTime(2026, 10, 2, 8)), _meal('m2', DateTime(2026, 10, 2, 13))],
    )),
    exerciseRepositoryProvider.overrideWithValue(FakeExerciseRepository([gameBench, gameSquat])),
  ]);
  addTearDown(container.dispose);
  return container;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('meal times come back oldest first', () async {
    final container = _container();
    container.listen(mealTimesProvider, (_, _) {});
    expect(await container.read(mealTimesProvider.future), [DateTime(2026, 10, 2, 8), DateTime(2026, 10, 2, 13)]);
  });

  test('the player summary joins sessions, meal days and exercises', () async {
    final container = _container();
    container.listen(playerSummaryProvider, (_, _) {});
    final summary = await container.read(playerSummaryProvider.future);
    // 50 + 3 × 5 + 10.
    expect(summary.totalXp, 75);
    expect(summary.upcoming.map((t) => t.id), contains('muscle:chest'));
  });

  test('game settings: profile days without a program, and the user id', () async {
    final container = _container(userId: 'user-1');
    container.listen(gameSettingsProvider, (_, _) {});
    final settings = await container.read(gameSettingsProvider.future);
    expect(settings.weeklyGoal, weeklyGoalFor(profileDays: testProfile.exerciseDaysPerWeek));
    expect(settings.userId, 'user-1');
  });

  test('game settings fall back to 3 when the profile fails', () async {
    // Riverpod'un otomatik yeniden denemesi hatayı geciktirmesin.
    final container = ProviderContainer(retry: (_, _) => null, overrides: [
      currentUserIdProvider.overrideWithValue(null),
      todayWorkoutProvider.overrideWith((ref) async => throw Exception('offline')),
      profileProvider.overrideWith((ref) async => throw Exception('offline')),
    ]);
    addTearDown(container.dispose);
    container.listen(gameSettingsProvider, (_, _) {});
    final settings = await container.read(gameSettingsProvider.future);
    expect((settings.weeklyGoal, settings.userId), (defaultWeeklyGoal, null));
  });

  test('the summary carries quests when signed in', () async {
    final container = _container(userId: 'user-1');
    container.listen(playerSummaryProvider, (_, _) {});
    final summary = await container.read(playerSummaryProvider.future);
    expect(summary.quests!.quests, hasLength(3));
  });

  test('the active title is saved and read back', () async {
    SharedPreferences.setMockInitialValues({'gamification.active_title': 'muscle:lats'});
    final first = _container();
    expect(await first.read(activeTitleProvider.future), 'muscle:lats');

    await first.read(activeTitleProvider.notifier).equip('exercise:bench');
    expect(first.read(activeTitleProvider).value, 'exercise:bench');
    final second = _container();
    expect(await second.read(activeTitleProvider.future), 'exercise:bench');

    await second.read(activeTitleProvider.notifier).unequip();
    final third = _container();
    expect(await third.read(activeTitleProvider.future), isNull);
  });
}
