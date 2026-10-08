import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spor_takip/features/workout/domain/muscle_map.dart';
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
}
