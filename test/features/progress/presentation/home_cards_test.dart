import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spor_takip/features/onboarding/application/profile_providers.dart';
import 'package:spor_takip/features/progress/application/progress_providers.dart';
import 'package:spor_takip/features/progress/domain/weekly_summary.dart';
import 'package:spor_takip/features/progress/presentation/widgets/weekly_summary_card.dart';

import '../fixtures.dart';
import 'test_app.dart';

String _text(WidgetTester tester, String key) => tester.widget<Text>(find.byKey(Key(key))).data!;

final _summary = WeeklySummary(
  weekStart: DateTime(2026, 9, 28),
  thisWeek: const WeekStats(
    workouts: 3,
    sets: 45,
    volumeKg: 12000.4,
    nutritionDays: 4,
    avgCalories: 2700,
    avgProteinG: 150,
    lastWeightKg: 80,
  ),
  lastWeek: const WeekStats(workouts: 2, sets: 30, volumeKg: 9000, nutritionDays: 0, lastWeightKg: 80.5),
);

void main() {
  setUpAll(initTestLocalization);

  testWidgets('weekly summary shows this week, last week and the change', (tester) async {
    await tester.pumpWidget(testApp(const WeeklySummaryCard(), overrides: [
      weeklySummaryProvider.overrideWith((ref) async => _summary),
      profileProvider.overrideWith((ref) async => testProfile),
    ]));
    await tester.pumpAndSettle();

    expect(_text(tester, 'weekly_workouts_this'), '3');
    expect(_text(tester, 'weekly_workouts_last'), '2');
    expect(_text(tester, 'weekly_workouts_change'), '▲ 1');
    expect(_text(tester, 'weekly_volume_this'), '12000');
    expect(_text(tester, 'weekly_calories_this'), '2700 · %100');
    expect(_text(tester, 'weekly_calories_last'), '—');
    expect(_text(tester, 'weekly_calories_change'), '—');
    expect(_text(tester, 'weekly_nutrition_days_this'), '4');
    expect(_text(tester, 'weekly_weight_this'), '80');
    expect(_text(tester, 'weekly_weight_change'), '▼ 0.5');
  });

  testWidgets('weekly summary empty state', (tester) async {
    await tester.pumpWidget(testApp(const WeeklySummaryCard(), overrides: [
      weeklySummaryProvider.overrideWith((ref) async => weeklySummary(
            now: DateTime(2026, 9, 30),
            sessions: const [],
            meals: const [],
            weights: const [],
          )),
      profileProvider.overrideWith((ref) async => testProfile),
    ]));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('weekly_empty')), findsOneWidget);
    expect(find.byKey(const Key('weekly_workouts_this')), findsNothing);
  });

  testWidgets('weekly summary error shows retry', (tester) async {
    await tester.pumpWidget(testApp(const WeeklySummaryCard(), overrides: [
      weeklySummaryProvider.overrideWith((ref) async => throw Exception('offline')),
      profileProvider.overrideWith((ref) async => testProfile),
    ]));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('card_retry')), findsOneWidget);
  });
}
