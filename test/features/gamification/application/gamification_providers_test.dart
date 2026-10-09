import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spor_takip/features/gamification/application/gamification_providers.dart';
import 'package:spor_takip/features/nutrition/domain/meal.dart';
import 'package:spor_takip/features/nutrition/domain/meal_type.dart';
import 'package:spor_takip/features/onboarding/application/auth_providers.dart';
import 'package:spor_takip/features/progress/application/progress_providers.dart';
import 'package:spor_takip/features/workout/application/workout_providers.dart';

import '../../progress/fakes.dart';
import '../../workout/fakes.dart';
import '../game_fixtures.dart';

Meal _meal(String id, DateTime loggedAt) =>
    Meal(id: id, userId: 'user-1', mealType: MealType.lunch, loggedAt: loggedAt, items: const []);

ProviderContainer _container() {
  final container = ProviderContainer(overrides: [
    isLoggedInProvider.overrideWithValue(true),
    progressDataRepositoryProvider.overrideWithValue(FakeProgressDataRepository(
      sessions: [gameSession('a', DateTime(2026, 10, 1, 18), gameSets('bench', 2))],
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
    // 50 + 2 × 5 + 10.
    expect(summary.totalXp, 70);
    expect(summary.upcoming.map((t) => t.id), contains('muscle:chest'));
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
