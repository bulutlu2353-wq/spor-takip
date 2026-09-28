import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spor_takip/features/progress/application/progress_providers.dart';
import 'package:spor_takip/features/progress/presentation/strength_screen.dart';
import 'package:spor_takip/features/progress/presentation/widgets/progress_line_chart.dart';
import 'package:spor_takip/features/progress/presentation/widgets/strength_card.dart';
import 'package:spor_takip/features/workout/application/session_providers.dart';

import '../fakes.dart';
import '../fixtures.dart';
import 'test_app.dart';

final _now = DateTime(2026, 9, 28, 12);

void main() {
  setUpAll(initTestLocalization);

  late FakeProgressDataRepository data;

  setUp(() => data = FakeProgressDataRepository(sessions: [
        finishedSession('old', DateTime(2026, 5, 1), [doneSet('deadlift', kg: 140, reps: 5)]),
        finishedSession('a', DateTime(2026, 8, 20), [doneSet('squat', kg: 100, reps: 5), doneSet('bench', kg: 60, reps: 5)]),
        finishedSession('b', DateTime(2026, 9, 25), [doneSet('squat', kg: 110, reps: 1)]),
      ]));

  List overrides() => [
        progressDataRepositoryProvider.overrideWithValue(data),
        nowProvider.overrideWithValue(() => _now),
      ];

  group('card', () {
    testWidgets('lists recent exercises with the latest estimate and the change', (tester) async {
      await tester.pumpWidget(testApp(const StrengthCard(), overrides: overrides()));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('strength_row_squat')), findsOneWidget);
      expect(find.byKey(const Key('strength_row_bench')), findsOneWidget);
      expect(find.byKey(const Key('strength_row_deadlift')), findsNothing); // 90 günden eski
      expect(tester.widget<Text>(find.byKey(const Key('strength_value_squat'))).data, '110 kg');
      expect(find.text('squat name'), findsOneWidget);
    });

    testWidgets('empty state', (tester) async {
      data.sessions.clear();
      await tester.pumpWidget(testApp(const StrengthCard(), overrides: overrides()));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('strength_empty')), findsOneWidget);
    });

    testWidgets('tapping opens the strength screen', (tester) async {
      await tester.pumpWidget(testApp(
        const StrengthCard(),
        overrides: overrides(),
        stubRoutes: {'/home/strength': 'STRENGTH_SCREEN'},
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('strength_value_squat')));
      await tester.pumpAndSettle();
      expect(find.text('STRENGTH_SCREEN'), findsOneWidget);
    });
  });

  group('screen', () {
    Future<void> pumpScreen(WidgetTester tester) async {
      await tester.pumpWidget(testApp(const StrengthScreen(), overrides: overrides(), scaffold: false));
      await tester.pumpAndSettle();
    }

    DropdownButton<String> picker(WidgetTester tester) =>
        tester.widget<DropdownButton<String>>(find.byKey(const Key('strength_exercise_picker')));

    testWidgets('starts with the most frequent exercise and lists all history', (tester) async {
      await pumpScreen(tester);

      expect(picker(tester).value, 'squat');
      expect(picker(tester).items!.map((i) => i.value), ['squat', 'bench', 'deadlift']);
      expect(find.byKey(const Key('strength_chart')), findsOneWidget);
    });

    testWidgets('picking another exercise switches the chart', (tester) async {
      await pumpScreen(tester);

      await tester.tap(find.byKey(const Key('strength_exercise_picker')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('bench name').last);
      await tester.pumpAndSettle();

      expect(picker(tester).value, 'bench');
      final chart = tester.widget<ProgressLineChart>(find.byKey(const Key('strength_chart')));
      expect(chart.points.single.value, closeTo(70, 0.01)); // 60 × (1 + 5/30)
    });

    testWidgets('empty state', (tester) async {
      data.sessions.clear();
      await pumpScreen(tester);

      expect(find.byKey(const Key('strength_empty')), findsOneWidget);
    });
  });
}
