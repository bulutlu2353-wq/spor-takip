import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spor_takip/features/onboarding/application/auth_providers.dart';
import 'package:spor_takip/features/progress/application/progress_providers.dart';
import 'package:spor_takip/features/progress/domain/body_weight_log.dart';
import 'package:spor_takip/features/workout/application/session_providers.dart';

import '../fakes.dart';
import '../fixtures.dart';

final _now = DateTime(2026, 9, 30, 12); // Çarşamba

void main() {
  late FakeProgressDataRepository data;
  late FakeBodyWeightRepository weights;

  ProviderContainer containerWith({bool loggedIn = true}) {
    final container = ProviderContainer(overrides: [
      isLoggedInProvider.overrideWithValue(loggedIn),
      progressDataRepositoryProvider.overrideWithValue(data),
      bodyWeightRepositoryProvider.overrideWithValue(weights),
      bodyMeasurementRepositoryProvider.overrideWithValue(FakeBodyMeasurementRepository()),
      nowProvider.overrideWithValue(() => _now),
    ]);
    addTearDown(container.dispose);
    return container;
  }

  setUp(() {
    data = FakeProgressDataRepository(
      sessions: [
        finishedSession('old', DateTime(2026, 6, 1), [doneSet('deadlift')]),
        finishedSession('a', DateTime(2026, 9, 22), [doneSet('squat'), doneSet('bench')]),
        finishedSession('b', DateTime(2026, 9, 29), [doneSet('squat')]),
      ],
      meals: [
        testMeal(DateTime(2026, 9, 29, 13), calories: 2000),
        testMeal(DateTime(2026, 9, 14, 13)), // iki hafta önce: çekilmez
      ],
    );
    weights = FakeBodyWeightRepository([BodyWeightLog(date: DateTime(2026, 9, 29), weightKg: 80)]);
  });

  test('recent sessions cover the last 90 days only', () async {
    final sessions = await containerWith().read(recentSessionsProvider.future);
    expect(sessions.map((s) => s.id), ['a', 'b']);
  });

  test('all sessions include older ones', () async {
    final sessions = await containerWith().read(allSessionsProvider.future);
    expect(sessions.map((s) => s.id), ['old', 'a', 'b']);
  });

  test('weekly meals cover last week and this week', () async {
    final meals = await containerWith().read(weeklyMealsProvider.future);
    expect(meals, hasLength(1));
  });

  test('weekly summary combines sessions, meals and weights', () async {
    final summary = await containerWith().read(weeklySummaryProvider.future);
    expect(summary.thisWeek.workouts, 1);
    expect(summary.lastWeek.workouts, 1);
    expect(summary.thisWeek.avgCalories, 2000);
    expect(summary.thisWeek.lastWeightKg, 80);
  });

  test('strength card lists the most frequent recent exercises', () async {
    final series = await containerWith().read(strengthCardProvider.future);
    expect(series.map((s) => s.exerciseId), ['squat', 'bench']);
  });

  test('logged out → empty lists without hitting the repositories', () async {
    final container = containerWith(loggedIn: false);
    expect(await container.read(recentSessionsProvider.future), isEmpty);
    expect(await container.read(weightLogsProvider.future), isEmpty);
    expect(data.sessionFetches, 0);
  });
}
