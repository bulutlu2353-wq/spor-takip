import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spor_takip/features/nutrition/application/today_meals_provider.dart';
import 'package:spor_takip/features/onboarding/application/profile_providers.dart';
import 'package:spor_takip/features/onboarding/presentation/home_screen.dart';
import 'package:spor_takip/features/progress/application/progress_providers.dart';
import 'package:spor_takip/features/progress/domain/weekly_summary.dart';
import 'package:spor_takip/features/workout/application/session_providers.dart';
import 'package:spor_takip/features/workout/application/workout_providers.dart';
import 'package:spor_takip/features/workout/domain/today_workout.dart';

import '../../progress/fixtures.dart';
import '../../progress/presentation/test_app.dart';

void main() {
  setUpAll(initTestLocalization);

  testWidgets('shows the header, nutrition, today\'s workout and four tiles', (tester) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(testApp(
      const HomeScreen(),
      scaffold: false,
      overrides: [
        nowProvider.overrideWithValue(() => DateTime(2026, 10, 3, 9)),
        profileProvider.overrideWith((ref) async => testProfile),
        todayMealsProvider.overrideWith((ref) async => const []),
        todayWorkoutProvider.overrideWith((ref) async => const NoActiveProgram()),
        inProgressSessionProvider.overrideWith((ref) async => null),
        weightLogsProvider.overrideWith((ref) async => const []),
        weeklySummaryProvider.overrideWith((ref) async => weeklySummary(
              now: DateTime(2026, 10, 3, 9),
              sessions: const [],
              meals: const [],
              weights: const [],
            )),
        strengthCardProvider.overrideWith((ref) async => const []),
        measurementsProvider.overrideWith((ref) async => const []),
      ],
    ));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('home_date')), findsOneWidget);
    expect(find.byKey(const Key('home_greeting')), findsOneWidget);
    expect(find.byKey(const Key('home_sign_out_button')), findsOneWidget);
    expect(find.byKey(const Key('today_nutrition_card')), findsOneWidget);
    expect(find.byKey(const Key('today_no_program')), findsOneWidget);
    for (final tile in ['home_tile_weight', 'home_tile_week', 'home_tile_strength', 'home_tile_measurement']) {
      expect(find.byKey(Key(tile)), findsOneWidget, reason: tile);
    }
    // Eski kartlar yok.
    expect(find.byKey(const Key('home_targets_card')), findsNothing);
    expect(find.byKey(const Key('weight_card')), findsNothing);
  });

  testWidgets('without a profile it shows the no-profile message', (tester) async {
    await tester.pumpWidget(testApp(
      const HomeScreen(),
      scaffold: false,
      overrides: [profileProvider.overrideWith((ref) async => null)],
    ));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('home_list')), findsNothing);
  });
}
