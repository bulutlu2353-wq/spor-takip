import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spor_takip/core/theme/app_colors.dart';
import 'package:spor_takip/features/onboarding/domain/profile.dart';
import 'package:spor_takip/features/progress/application/progress_providers.dart';
import 'package:spor_takip/features/progress/domain/body_measurement.dart';
import 'package:spor_takip/features/progress/domain/body_weight_log.dart';
import 'package:spor_takip/features/progress/domain/strength.dart';
import 'package:spor_takip/features/progress/domain/weekly_summary.dart';
import 'package:spor_takip/features/progress/presentation/widgets/home_stat_grid.dart';
import 'package:spor_takip/features/workout/application/session_providers.dart';

import '../fixtures.dart';
import 'test_app.dart';

final _now = DateTime(2026, 9, 28, 12);

final _summary = WeeklySummary(
  weekStart: DateTime(2026, 9, 28),
  thisWeek: const WeekStats(workouts: 3, sets: 45, volumeKg: 12000, nutritionDays: 4, lastWeightKg: 80),
  lastWeek: const WeekStats(workouts: 2, sets: 30, volumeKg: 9000, nutritionDays: 0, lastWeightKg: 80.5),
);

final _emptySummary = WeeklySummary(
  weekStart: DateTime(2026, 9, 28),
  thisWeek: const WeekStats(workouts: 0, sets: 0, volumeKg: 0, nutritionDays: 0),
  lastWeek: const WeekStats(workouts: 0, sets: 0, volumeKg: 0, nutritionDays: 0),
);

final _squat = StrengthSeries(exerciseId: 'squat', exerciseName: 'Squat', points: [
  StrengthPoint(date: DateTime(2026, 8, 1), estimateKg: 100, weightKg: 100, reps: 1),
  StrengthPoint(date: DateTime(2026, 9, 20), estimateKg: 110, weightKg: 110, reps: 1),
]);

void main() {
  test('weightChangeIsGood follows the weight direction', () {
    expect(weightChangeIsGood(-1, WeightDirection.lose), isTrue);
    expect(weightChangeIsGood(1, WeightDirection.lose), isFalse);
    expect(weightChangeIsGood(1, WeightDirection.gain), isTrue);
    expect(weightChangeIsGood(-1, WeightDirection.gain), isFalse);
    expect(weightChangeIsGood(-1, WeightDirection.maintain), isFalse);
    expect(weightChangeIsGood(1, WeightDirection.maintain), isFalse);
  });

  setUpAll(initTestLocalization);

  Future<void> pump(
    WidgetTester tester, {
    Profile profile = testProfile,
    List<BodyWeightLog> weights = const [],
    WeeklySummary? summary,
    List<StrengthSeries> strength = const [],
    List<BodyMeasurement> measurements = const [],
    Object? weightError,
  }) async {
    await tester.pumpWidget(testApp(
      HomeStatGrid(profile: profile),
      overrides: [
        nowProvider.overrideWithValue(() => _now),
        weightLogsProvider.overrideWith((ref) async => weightError != null ? throw weightError : weights),
        weeklySummaryProvider.overrideWith((ref) async => summary ?? _emptySummary),
        strengthCardProvider.overrideWith((ref) async => strength),
        measurementsProvider.overrideWith((ref) async => measurements),
      ],
      stubRoutes: {
        '/home/weight': 'WEIGHT',
        '/workout/history': 'HISTORY',
        '/home/strength': 'STRENGTH',
        '/home/measurements': 'MEASUREMENTS',
      },
    ));
    await tester.pumpAndSettle();
  }

  Text part(WidgetTester tester, String tile, String part) => tester.widget<Text>(
      find.descendant(of: find.byKey(Key(tile)), matching: find.byKey(ValueKey('stat_tile_$part'))));

  testWidgets('fills the four tiles from the progress data', (tester) async {
    await pump(
      tester,
      weights: [
        BodyWeightLog(date: DateTime(2026, 8, 1), weightKg: 82),
        BodyWeightLog(date: DateTime(2026, 9, 20), weightKg: 80),
      ],
      summary: _summary,
      strength: [_squat],
      measurements: [
        BodyMeasurement(date: DateTime(2026, 9, 1), values: {MeasurementSite.waist: 85}),
        BodyMeasurement(date: DateTime(2026, 9, 20), values: {MeasurementSite.waist: 83, MeasurementSite.arm: 35}),
      ],
    );

    expect(part(tester, 'home_tile_weight', 'value').data, '80 kg');
    expect(part(tester, 'home_tile_week', 'value').data, '3');
    expect(part(tester, 'home_tile_strength', 'value').data, '110 kg');
    expect(part(tester, 'home_tile_measurement', 'value').data, '83 cm');
    // Detay metinleri `.tr()` içinde; yalnızca renkleri doğrulanır.
    expect(part(tester, 'home_tile_strength', 'detail').style!.color, AppColors.accent); // ▲ 10
    expect(part(tester, 'home_tile_measurement', 'detail').style!.color, AppColors.accent); // bel ▼ 2
  });

  testWidgets('weight change color follows the goal', (tester) async {
    final weights = [
      BodyWeightLog(date: DateTime(2026, 8, 1), weightKg: 82),
      BodyWeightLog(date: DateTime(2026, 9, 20), weightKg: 80),
    ];
    // testProfile kilosunu koruyor: düşüş olumlu değil.
    await pump(tester, weights: weights);
    expect(part(tester, 'home_tile_weight', 'detail').style!.color, AppColors.muted);

    await pump(tester, weights: weights, profile: testProfile.copyWith(weightDirection: WeightDirection.lose, pace: Pace.balanced));
    expect(part(tester, 'home_tile_weight', 'detail').style!.color, AppColors.accent);
  });

  testWidgets('empty data shows dashes', (tester) async {
    await pump(tester);

    for (final tile in ['home_tile_weight', 'home_tile_week', 'home_tile_strength', 'home_tile_measurement']) {
      expect(part(tester, tile, 'value').data, '—', reason: tile);
    }
  });

  testWidgets('a failed source only empties its own tile', (tester) async {
    await pump(tester, weightError: Exception('offline'), summary: _summary);

    expect(part(tester, 'home_tile_weight', 'value').data, '—');
    expect(part(tester, 'home_tile_week', 'value').data, '3');
  });

  for (final (tile, screen) in [
    ('home_tile_weight', 'WEIGHT'),
    ('home_tile_week', 'HISTORY'),
    ('home_tile_strength', 'STRENGTH'),
    ('home_tile_measurement', 'MEASUREMENTS'),
  ]) {
    testWidgets('tapping $tile opens $screen', (tester) async {
      await pump(tester);

      await tester.tap(find.byKey(Key(tile)));
      await tester.pumpAndSettle();
      expect(find.text(screen), findsOneWidget);
    });
  }
}
