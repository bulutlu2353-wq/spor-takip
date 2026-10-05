import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spor_takip/core/theme/app_colors.dart';
import 'package:spor_takip/features/onboarding/application/profile_providers.dart';
import 'package:spor_takip/features/onboarding/domain/profile.dart';
import 'package:spor_takip/features/progress/application/progress_providers.dart';
import 'package:spor_takip/features/progress/domain/body_weight_log.dart';
import 'package:spor_takip/features/progress/presentation/weight_screen.dart';
import 'package:spor_takip/features/workout/application/session_providers.dart';
import 'package:spor_takip/shared/date_label.dart';

import '../fakes.dart';
import '../fixtures.dart';
import 'test_app.dart';

final _now = DateTime(2026, 9, 28, 12);

void main() {
  setUpAll(initTestLocalization);

  late FakeBodyWeightRepository repo;

  setUp(() => repo = FakeBodyWeightRepository([
        BodyWeightLog(date: DateTime(2026, 8, 1), weightKg: 82),
        BodyWeightLog(date: DateTime(2026, 9, 20), weightKg: 80),
      ]));

  List overrides() => [
        bodyWeightRepositoryProvider.overrideWithValue(repo),
        profileProvider.overrideWith((ref) async => testProfile),
        nowProvider.overrideWithValue(() => _now),
      ];

  Future<void> openAddDialog(WidgetTester tester) async {
    await tester.pumpWidget(testApp(const WeightScreen(), overrides: overrides(), scaffold: false));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('weight_screen_add')));
    await tester.pumpAndSettle();
  }

  group('log dialog', () {
    testWidgets('saves today with a comma decimal and closes', (tester) async {
      await openAddDialog(tester);

      await tester.enterText(find.byKey(const Key('weight_input')), '79,5');
      await tester.tap(find.byKey(const Key('weight_save_button')));
      await tester.pumpAndSettle();

      expect(repo.logged.single.date, DateTime(2026, 9, 28));
      expect(repo.logged.single.update.weightKg, 79.5);
      expect(find.byKey(const Key('weight_input')), findsNothing);
    });

    testWidgets('rejects an out-of-range value without saving', (tester) async {
      await openAddDialog(tester);

      await tester.enterText(find.byKey(const Key('weight_input')), '600');
      await tester.tap(find.byKey(const Key('weight_save_button')));
      await tester.pumpAndSettle();

      expect(repo.logged, isEmpty);
      expect(find.byKey(const Key('weight_input')), findsOneWidget);
    });

    testWidgets('a save error keeps the dialog open with a message', (tester) async {
      repo.error = Exception('offline');
      await openAddDialog(tester);

      await tester.enterText(find.byKey(const Key('weight_input')), '79');
      await tester.tap(find.byKey(const Key('weight_save_button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('weight_save_error')), findsOneWidget);
      expect(find.byKey(const Key('weight_input')), findsOneWidget);
    });
  });

  group('screen', () {
    // Testte çeviri yüklenmez; uzun anahtar metinli aralık çipleri alt alta
    // dizilip listeyi aşağı iter. Uzun ekran, satırları görünür tutar.
    void tallView(WidgetTester tester) {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
    }

    Future<void> pumpScreen(WidgetTester tester) async {
      tallView(tester);
      await tester.pumpWidget(testApp(const WeightScreen(), overrides: overrides(), scaffold: false));
      await tester.pumpAndSettle();
    }

    testWidgets('lists entries newest first with a chart', (tester) async {
      await pumpScreen(tester);

      expect(find.byKey(const Key('weight_chart')), findsOneWidget);
      final newest = tester.getTopLeft(find.byKey(const Key('weight_log_2026-09-20')));
      final oldest = tester.getTopLeft(find.byKey(const Key('weight_log_2026-08-01')));
      expect(newest.dy, lessThan(oldest.dy));
    });

    testWidgets('deleting the newest entry asks first and sends the previous weight', (tester) async {
      await pumpScreen(tester);

      await tester.tap(find.byKey(const Key('weight_delete_2026-09-20')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('confirm_delete_button')));
      await tester.pumpAndSettle();

      expect(repo.deleted.single.date, DateTime(2026, 9, 20));
      expect(repo.deleted.single.newLatest!.weightKg, 82);
      expect(find.byKey(const Key('weight_log_2026-09-20')), findsNothing);
    });

    testWidgets('the only entry cannot be deleted', (tester) async {
      repo.logs.removeAt(0);
      await pumpScreen(tester);

      final button = tester.widget<IconButton>(find.byKey(const Key('weight_delete_2026-09-20')));
      expect(button.onPressed, isNull);
    });

    testWidgets('tapping an entry edits its weight with the date fixed', (tester) async {
      await pumpScreen(tester);

      await tester.tap(find.byKey(const Key('weight_log_2026-09-20')));
      await tester.pumpAndSettle();

      final input = tester.widget<TextField>(find.byKey(const Key('weight_input')));
      expect(input.controller!.text, '80');
      final dateButton = tester.widget<TextButton>(find.byKey(const Key('weight_date_button')));
      expect(dateButton.onPressed, isNull);

      await tester.enterText(find.byKey(const Key('weight_input')), '80.4');
      await tester.tap(find.byKey(const Key('weight_save_button')));
      await tester.pumpAndSettle();
      expect(repo.logged.single.date, DateTime(2026, 9, 20));
      expect(repo.logged.single.update.weightKg, 80.4);
    });

    testWidgets('shows the latest weight, the change in range and per-entry differences', (tester) async {
      await pumpScreen(tester);

      Text text(String key) => tester.widget<Text>(find.byKey(Key(key)));
      expect(text('weight_current').data, '80');
      expect(
        text('weight_change').data,
        'progress.change_in_range'.tr(namedArgs: {'delta': '▼ 2 kg', 'range': 'progress.range.three_months'.tr()}),
      );
      // Test profilinin hedefi kas kazanmak: düşüş olumlu sayılmaz.
      expect(text('weight_change').style!.color, AppColors.muted);
      expect(text('weight_delta_2026-09-20').data, '▼ 2');
      expect(find.byKey(const Key('weight_delta_2026-08-01')), findsNothing);
      expect(find.text(shortDateLabel(DateTime(2026, 9, 20), _now)), findsOneWidget);
    });

    testWidgets('a loss is highlighted when the goal is losing weight', (tester) async {
      tallView(tester);
      await tester.pumpWidget(testApp(
        const WeightScreen(),
        overrides: [
          bodyWeightRepositoryProvider.overrideWithValue(repo),
          profileProvider.overrideWith((ref) async => testProfile.copyWith(goal: Goal.loseWeight)),
          nowProvider.overrideWithValue(() => _now),
        ],
        scaffold: false,
      ));
      await tester.pumpAndSettle();

      Color? color(String key) => tester.widget<Text>(find.byKey(Key(key))).style!.color;
      expect(color('weight_change'), AppColors.accent);
      expect(color('weight_delta_2026-09-20'), AppColors.accent);
    });
  });
}
