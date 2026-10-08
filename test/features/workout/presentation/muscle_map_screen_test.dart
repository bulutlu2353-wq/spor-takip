import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spor_takip/features/workout/application/workout_providers.dart';
import 'package:spor_takip/features/workout/domain/exercise.dart';
import 'package:spor_takip/features/workout/domain/muscle_map.dart';
import 'package:spor_takip/features/workout/presentation/muscle_map_screen.dart';

import '../../progress/presentation/test_app.dart';
import '../muscle_map_points.dart';

const _bench = Exercise(
  id: 'bench',
  name: 'Barbell Bench Press',
  equipment: 'barbell',
  level: 'expert',
  primaryMuscles: ['chest'],
  secondaryMuscles: ['triceps'],
  instructions: ['Lower the bar.'],
);
const _pushups = Exercise(id: 'pushups', name: 'Pushups', equipment: 'body only', primaryMuscles: ['chest']);
const _dips = Exercise(id: 'dips', name: 'Dips', primaryMuscles: ['triceps'], secondaryMuscles: ['chest']);
const _squat = Exercise(id: 'squat', name: 'Squat', primaryMuscles: ['quadriceps']);
const _all = [_bench, _pushups, _dips, _squat];

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  Future<void> pumpScreen(WidgetTester tester, {Future<List<Exercise>> Function()? load}) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(testApp(
      const MuscleMapScreen(),
      scaffold: false,
      overrides: [exercisesProvider.overrideWith((ref) => (load ?? () async => _all)())],
    ));
    await tester.pumpAndSettle();
  }

  Future<void> tapMuscle(WidgetTester tester, BodyView view, String muscle) async {
    await tester.tapAt(screenPointFor(tester, find.byKey(Key('muscle_map_${view.name}')), view, muscle));
    await tester.pumpAndSettle();
  }

  testWidgets('shows a hint until a muscle is chosen', (tester) async {
    await pumpScreen(tester);
    expect(find.byKey(const Key('muscle_map_screen')), findsOneWidget);
    expect(find.byKey(const Key('muscle_map_hint')), findsOneWidget);
    expect(find.byKey(const Key('muscle_map_selected')), findsNothing);
  });

  testWidgets('choosing a muscle lists its exercises; the chip adds secondary ones', (tester) async {
    await pumpScreen(tester);
    await tapMuscle(tester, BodyView.front, 'chest');

    expect(find.byKey(const Key('muscle_map_hint')), findsNothing);
    expect(find.byKey(const Key('muscle_map_selected')), findsOneWidget);
    expect(find.byKey(const Key('muscle_map_count')), findsOneWidget);
    expect(find.byKey(const Key('muscle_map_exercise_bench')), findsOneWidget);
    expect(find.byKey(const Key('muscle_map_exercise_pushups')), findsOneWidget);
    expect(find.byKey(const Key('muscle_map_exercise_dips')), findsNothing);
    expect(find.byKey(const Key('muscle_map_exercise_squat')), findsNothing);
    // Ekipman · seviye ('expert' → İleri).
    expect(find.text('workout.equipment.barbell · workout.level_advanced'), findsOneWidget);

    await tester.tap(find.byKey(const Key('muscle_map_secondary_chip')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('muscle_map_exercise_dips')), findsOneWidget);
  });

  testWidgets('a row opens the detail sheet without a select button', (tester) async {
    await pumpScreen(tester);
    await tapMuscle(tester, BodyView.front, 'chest');

    await tester.tap(find.byKey(const Key('muscle_map_exercise_bench')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Lower the bar.'), findsOneWidget);
    expect(find.byKey(const Key('exercise_select_button')), findsNothing);
  });

  testWidgets('switching to the back keeps the selection and the list', (tester) async {
    await pumpScreen(tester);
    await tapMuscle(tester, BodyView.front, 'chest');

    await tester.tap(find.text('workout.muscle_map.back'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('muscle_map_back')), findsOneWidget);
    expect(find.byKey(const Key('muscle_map_selected')), findsOneWidget);
    expect(find.byKey(const Key('muscle_map_exercise_bench')), findsOneWidget);

    // Örnek veride hamstring hareketi yok → boş liste mesajı.
    await tapMuscle(tester, BodyView.back, 'hamstrings');
    expect(find.byKey(const Key('muscle_map_empty')), findsOneWidget);
  });

  testWidgets('a load error offers a retry', (tester) async {
    var calls = 0;
    await pumpScreen(tester, load: () async {
      calls++;
      if (calls == 1) throw Exception('offline');
      return _all;
    });
    await tapMuscle(tester, BodyView.front, 'chest');
    expect(find.byKey(const Key('muscle_map_retry')), findsOneWidget);

    await tester.tap(find.byKey(const Key('muscle_map_retry')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('muscle_map_exercise_bench')), findsOneWidget);
  });
}
