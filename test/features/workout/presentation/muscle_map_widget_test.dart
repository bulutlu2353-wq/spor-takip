import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spor_takip/features/workout/domain/muscle_heat.dart';
import 'package:spor_takip/features/workout/domain/muscle_map.dart';
import 'package:spor_takip/features/workout/presentation/widgets/exercise_icon_badge.dart';
import 'package:spor_takip/features/workout/presentation/widgets/muscle_map.dart';

import '../../progress/presentation/test_app.dart';
import '../muscle_map_points.dart';

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  Future<List<String>> pumpMap(WidgetTester tester, BodyView view, {String? selected}) async {
    final taps = <String>[];
    await tester.pumpWidget(testApp(
      Scaffold(
        body: Center(
          child: SizedBox(width: 300, height: 500, child: MuscleMap(view: view, selected: selected, onSelected: taps.add)),
        ),
      ),
      scaffold: false,
    ));
    await tester.pumpAndSettle();
    return taps;
  }

  testWidgets('tapping the chest reports chest', (tester) async {
    final taps = await pumpMap(tester, BodyView.front);
    await tester.tapAt(screenPointFor(tester, find.byKey(const Key('muscle_map_front')), BodyView.front, 'chest'));
    expect(taps, ['chest']);
  });

  testWidgets('back view reports lats', (tester) async {
    final taps = await pumpMap(tester, BodyView.back, selected: 'lats');
    await tester.tapAt(screenPointFor(tester, find.byKey(const Key('muscle_map_back')), BodyView.back, 'lats'));
    expect(taps, ['lats']);
  });

  testWidgets('tapping empty space reports nothing', (tester) async {
    final taps = await pumpMap(tester, BodyView.front);
    await tester.tapAt(tester.getTopLeft(find.byKey(const Key('muscle_map_front'))) + const Offset(2, 2));
    expect(taps, isEmpty);
  });

  testWidgets('view toggle reports the chosen side', (tester) async {
    final changes = <BodyView>[];
    await tester.pumpWidget(testApp(BodyViewToggle(view: BodyView.front, onChanged: changes.add)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('workout.muscle_map.back'));
    expect(changes, [BodyView.back]);
  });

  testWidgets('the female figure reports taps on its own shapes', (tester) async {
    final taps = <String>[];
    await tester.pumpWidget(testApp(
      Scaffold(
        body: Center(
          child: SizedBox(
            width: 300,
            height: 500,
            child: MuscleMap(view: BodyView.back, figure: BodyFigure.female, onSelected: taps.add),
          ),
        ),
      ),
      scaffold: false,
    ));
    await tester.pumpAndSettle();
    final map = find.byKey(const Key('muscle_map_back'));
    for (final muscle in ['lats', 'middle back', 'glutes', 'abductors']) {
      await tester.tapAt(screenPointFor(tester, map, BodyView.back, muscle, figure: BodyFigure.female));
    }
    expect(taps, ['lats', 'middle back', 'glutes', 'abductors']);
  });

  testWidgets('figure toggle reports the chosen figure', (tester) async {
    final changes = <BodyFigure>[];
    await tester.pumpWidget(testApp(FigureToggle(figure: BodyFigure.male, onChanged: changes.add)));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('figure_toggle_female')));
    expect(changes, [BodyFigure.female]);
  });

  testWidgets('controls hold both toggles', (tester) async {
    final views = <BodyView>[];
    final figures = <BodyFigure>[];
    await tester.pumpWidget(testApp(MuscleMapControls(
      view: BodyView.front,
      onViewChanged: views.add,
      figure: BodyFigure.female,
      onFigureChanged: figures.add,
    )));
    await tester.pumpAndSettle();
    await tester.tap(find.text('workout.muscle_map.back'));
    await tester.tap(find.byKey(const Key('figure_toggle_male')));
    expect(views, [BodyView.back]);
    expect(figures, [BodyFigure.male]);
  });

  testWidgets('map card shows its label only when given', (tester) async {
    await tester.pumpWidget(testApp(
      const SizedBox(height: 200, child: MuscleMapCard(label: 'Kanat', child: SizedBox.expand())),
    ));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('muscle_map_card_label')), findsOneWidget);
    expect(find.text('Kanat'), findsOneWidget);

    await tester.pumpWidget(testApp(const SizedBox(height: 200, child: MuscleMapCard(child: SizedBox.expand()))));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('muscle_map_card_label')), findsNothing);
  });

  test('equipment icons fall back for unknown equipment', () {
    expect(equipmentIcon('cable'), Icons.cable);
    expect(equipmentIcon('body only'), Icons.accessibility_new);
    expect(equipmentIcon(null), Icons.fitness_center);
    expect(equipmentIcon('unknown'), Icons.fitness_center);
  });

  testWidgets('without onSelected the map lets taps reach its parent', (tester) async {
    var taps = 0;
    await tester.pumpWidget(testApp(
      Scaffold(
        body: Center(
          child: InkWell(
            onTap: () => taps++,
            child: const SizedBox(width: 300, height: 500, child: MuscleMap(view: BodyView.front)),
          ),
        ),
      ),
      scaffold: false,
    ));
    await tester.pumpAndSettle();
    await tester.tapAt(screenPointFor(tester, find.byKey(const Key('muscle_map_front')), BodyView.front, 'chest'));
    expect(taps, 1);
  });

  testWidgets('a heat map paints without errors', (tester) async {
    await tester.pumpWidget(testApp(
      const Scaffold(
        body: SizedBox(
          width: 300,
          height: 500,
          child: MuscleMap(view: BodyView.front, heat: {'chest': HeatTier.high, 'abdominals': HeatTier.low}),
        ),
      ),
      scaffold: false,
    ));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(tester.widget<MuscleMap>(find.byType(MuscleMap)).heat['chest'], HeatTier.high);
  });

  test('heatColor fades the accent by tier', () {
    const accent = Color(0xFFC6FF00);
    expect(heatColor(accent, HeatTier.none), isNull);
    expect(heatColor(accent, HeatTier.low)!.a, closeTo(0.25, 0.01));
    expect(heatColor(accent, HeatTier.medium)!.a, closeTo(0.45, 0.01));
    expect(heatColor(accent, HeatTier.optimal)!.a, closeTo(0.7, 0.01));
    expect(heatColor(accent, HeatTier.high), accent);
  });

  testWidgets('the legend shows four swatches between low and high', (tester) async {
    await tester.pumpWidget(testApp(const HeatLegend()));
    await tester.pumpAndSettle();
    final legend = find.byKey(const Key('muscle_heat_legend'));
    expect(legend, findsOneWidget);
    expect(find.descendant(of: legend, matching: find.text('workout.muscle_map.legend_low')), findsOneWidget);
    expect(find.descendant(of: legend, matching: find.text('workout.muscle_map.legend_high')), findsOneWidget);
    expect(find.descendant(of: legend, matching: find.byType(DecoratedBox)), findsNWidgets(4));
  });

  testWidgets('the mini card shows both views and reports a tap anywhere', (tester) async {
    var taps = 0;
    await tester.pumpWidget(testApp(
      MiniMuscleMapCard(figure: BodyFigure.female, heat: const {'chest': HeatTier.medium}, onTap: () => taps++),
    ));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('muscle_map_front')), findsOneWidget);
    expect(find.byKey(const Key('muscle_map_back')), findsOneWidget);
    expect(find.byKey(const Key('muscle_heat_legend')), findsOneWidget);
    expect(find.textContaining('PROGRAM_CARD_T'), findsOneWidget);

    await tester.tap(find.byKey(const Key('muscle_map_front')));
    expect(taps, 1);
  });
}
