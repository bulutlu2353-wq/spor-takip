import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spor_takip/core/theme/app_colors.dart';
import 'package:spor_takip/features/progress/application/progress_providers.dart';
import 'package:spor_takip/features/progress/domain/body_measurement.dart';
import 'package:spor_takip/features/progress/presentation/measurements_screen.dart';
import 'package:spor_takip/features/progress/presentation/widgets/progress_line_chart.dart';
import 'package:spor_takip/features/workout/application/session_providers.dart';
import 'package:spor_takip/shared/date_label.dart';

import '../fakes.dart';
import 'test_app.dart';

final _now = DateTime(2026, 9, 28, 12);

void main() {
  setUpAll(initTestLocalization);

  late FakeBodyMeasurementRepository repo;

  setUp(() => repo = FakeBodyMeasurementRepository([
        BodyMeasurement(date: DateTime(2026, 9, 1), values: {MeasurementSite.waist: 85}),
        BodyMeasurement(
          date: DateTime(2026, 9, 20),
          values: {MeasurementSite.waist: 83, MeasurementSite.arm: 35},
        ),
      ]));

  List overrides() => [
        bodyMeasurementRepositoryProvider.overrideWithValue(repo),
        nowProvider.overrideWithValue(() => _now),
      ];

  TextField field(WidgetTester tester, MeasurementSite site) =>
      tester.widget<TextField>(find.byKey(Key('measurement_field_${site.name}')));

  Future<void> openAddForm(WidgetTester tester) async {
    await tester.pumpWidget(testApp(const MeasurementsScreen(), overrides: overrides(), scaffold: false));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('measurements_screen_add')));
    await tester.pumpAndSettle();
  }

  group('form', () {
    testWidgets('saves today with the filled sites only', (tester) async {
      await openAddForm(tester);

      await tester.enterText(find.byKey(const Key('measurement_field_waist')), '82,5');
      await tester.enterText(find.byKey(const Key('measurement_field_neck')), '38');
      await tester.tap(find.byKey(const Key('measurement_save_button')));
      await tester.pumpAndSettle();

      final saved = repo.items.firstWhere((m) => m.date == DateTime(2026, 9, 28));
      expect(saved.values, {MeasurementSite.neck: 38.0, MeasurementSite.waist: 82.5});
      expect(find.byKey(const Key('measurement_save_button')), findsNothing);
    });

    testWidgets('an empty form is not saved', (tester) async {
      await openAddForm(tester);

      await tester.tap(find.byKey(const Key('measurement_save_button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('measurement_form_error')), findsOneWidget);
      expect(repo.items, hasLength(2));
    });

    testWidgets('an out-of-range value marks the field and is not saved', (tester) async {
      await openAddForm(tester);

      await tester.enterText(find.byKey(const Key('measurement_field_waist')), '400');
      await tester.tap(find.byKey(const Key('measurement_save_button')));
      await tester.pumpAndSettle();

      expect(field(tester, MeasurementSite.waist).decoration!.errorText, isNotNull);
      expect(repo.items, hasLength(2));
    });

    testWidgets('opening on a day that has a measurement prefills it', (tester) async {
      repo.items.add(BodyMeasurement(date: DateTime(2026, 9, 28), values: {MeasurementSite.chest: 100}));
      await openAddForm(tester);

      expect(field(tester, MeasurementSite.chest).controller!.text, '100');
      expect(field(tester, MeasurementSite.waist).controller!.text, '');
    });
  });

  group('screen', () {
    Future<void> pumpScreen(WidgetTester tester) async {
      // Testte çeviri yüklenmez; uzun anahtar metinli aralık çipleri alt alta
      // dizilip listeyi aşağı iter. Uzun ekran, satırları görünür tutar.
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(testApp(const MeasurementsScreen(), overrides: overrides(), scaffold: false));
      await tester.pumpAndSettle();
    }

    testWidgets('chips only for sites with data; picking one switches the chart', (tester) async {
      await pumpScreen(tester);

      expect(find.byKey(const Key('site_chip_waist')), findsOneWidget);
      expect(find.byKey(const Key('site_chip_arm')), findsOneWidget);
      expect(find.byKey(const Key('site_chip_neck')), findsNothing);
      ProgressLineChart chart() => tester.widget(find.byKey(const Key('measurement_chart')));
      expect(chart().points.map((p) => p.value), [85, 83]);

      await tester.tap(find.byKey(const Key('site_chip_arm')));
      await tester.pumpAndSettle();
      expect(chart().points.map((p) => p.value), [35]);
    });

    testWidgets('deleting a row asks first', (tester) async {
      await pumpScreen(tester);
      // Son satır FAB'ın altında kalmasın: listenin sonuna (88 px boşluk) kaydır.
      await tester.drag(find.byType(ListView), const Offset(0, -500));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('measurement_delete_2026-09-01')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('confirm_delete_button')));
      await tester.pumpAndSettle();

      expect(repo.items.map((m) => m.date), [DateTime(2026, 9, 20)]);
      expect(find.byKey(const Key('measurement_row_2026-09-01')), findsNothing);
    });

    testWidgets('tapping a row edits it with its values', (tester) async {
      await pumpScreen(tester);

      await tester.tap(find.byKey(const Key('measurement_row_2026-09-20')));
      await tester.pumpAndSettle();

      expect(field(tester, MeasurementSite.waist).controller!.text, '83');
      expect(field(tester, MeasurementSite.arm).controller!.text, '35');
    });

    testWidgets('shows the latest value of the site; the change is never highlighted', (tester) async {
      await pumpScreen(tester);

      Text text(String key) => tester.widget<Text>(find.byKey(Key(key)));
      expect(text('measurement_current').data, '83');
      expect(
        text('measurement_change').data,
        'progress.change_in_range'.tr(namedArgs: {'delta': '▼ 2 cm', 'range': 'progress.range.three_months'.tr()}),
      );
      expect(text('measurement_change').style!.color, AppColors.muted);
      expect(find.text(shortDateLabel(DateTime(2026, 9, 20), _now)), findsOneWidget);
    });
  });
}
