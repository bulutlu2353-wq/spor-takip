import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spor_takip/features/progress/application/progress_providers.dart';
import 'package:spor_takip/features/progress/domain/body_measurement.dart';
import 'package:spor_takip/features/progress/presentation/measurements_screen.dart';
import 'package:spor_takip/features/progress/presentation/widgets/measurements_card.dart';
import 'package:spor_takip/features/progress/presentation/widgets/progress_line_chart.dart';
import 'package:spor_takip/features/workout/application/session_providers.dart';

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
    await tester.pumpWidget(testApp(const MeasurementsCard(), overrides: overrides()));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('measurement_add_button')));
    await tester.pumpAndSettle();
  }

  group('card', () {
    testWidgets('shows the last date and a chip per filled site', (tester) async {
      await tester.pumpWidget(testApp(const MeasurementsCard(), overrides: overrides()));
      await tester.pumpAndSettle();

      // Tarih `.tr()` namedArgs'ı içinde (bkz. Global Constraints); yalnızca varlığı.
      expect(find.byKey(const Key('measurements_last')), findsOneWidget);
      expect(find.byKey(const Key('measurement_chip_waist')), findsOneWidget);
      expect(find.byKey(const Key('measurement_chip_arm')), findsOneWidget);
      expect(find.byKey(const Key('measurement_chip_neck')), findsNothing);
      expect(find.textContaining('83 (▼ 2)'), findsOneWidget);
    });

    testWidgets('empty state', (tester) async {
      repo.items.clear();
      await tester.pumpWidget(testApp(const MeasurementsCard(), overrides: overrides()));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('measurements_empty')), findsOneWidget);
    });

    testWidgets('tapping opens the measurements screen', (tester) async {
      await tester.pumpWidget(testApp(
        const MeasurementsCard(),
        overrides: overrides(),
        stubRoutes: {'/home/measurements': 'MEASUREMENTS_SCREEN'},
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('measurements_last')));
      await tester.pumpAndSettle();
      expect(find.text('MEASUREMENTS_SCREEN'), findsOneWidget);
    });
  });

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
  });
}
