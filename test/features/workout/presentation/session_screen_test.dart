import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spor_takip/features/onboarding/application/auth_providers.dart';
import 'package:spor_takip/features/workout/application/session_providers.dart';
import 'package:spor_takip/features/workout/application/workout_providers.dart';
import 'package:spor_takip/features/workout/domain/exercise.dart';
import 'package:spor_takip/features/workout/domain/workout_session.dart';
import 'package:spor_takip/features/workout/presentation/session_screen.dart';

import '../fakes.dart';

const _bench = Exercise(id: 'Bench', name: 'Bench Press', equipment: 'barbell', primaryMuscles: ['chest']);
final _now = DateTime(2026, 9, 26, 10, 30);

SessionSet _s(String id, {int idx = 0, bool deloaded = false}) => SessionSet(
      id: id,
      exercisePosition: 0,
      setIndex: idx,
      exerciseId: 'Barbell_Squat',
      exerciseName: 'Barbell Squat',
      targetRepsMin: 5,
      targetRepsMax: 5,
      restSeconds: 90,
      suggestedWeightKg: 60,
      deloaded: deloaded,
    );

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  late FakeSessionRepository repo;

  setUp(() {
    repo = FakeSessionRepository(sessions: [
      WorkoutSession(
        id: 'sess',
        programId: 'p1',
        programName: 'StrongLifts 5x5',
        workoutName: 'Antrenman A',
        workoutPosition: 0,
        startedAt: DateTime(2026, 9, 26, 10),
        sets: [_s('a'), _s('b', idx: 1, deloaded: true)],
      ),
    ]);
  });

  Widget wrap() {
    final router = GoRouter(initialLocation: '/session/sess', routes: [
      GoRoute(path: '/home', builder: (context, state) => const Text('HOME')),
      GoRoute(
        path: '/session/:id',
        builder: (context, state) => SessionScreen(sessionId: state.pathParameters['id']!),
        routes: [
          GoRoute(path: 'summary', builder: (context, state) => const Text('SUMMARY')),
          GoRoute(
            path: 'exercises',
            builder: (context, state) => Builder(
              builder: (ctx) => TextButton(onPressed: () => ctx.pop(_bench), child: const Text('PICK')),
            ),
          ),
        ],
      ),
    ]);
    return EasyLocalization(
      supportedLocales: const [Locale('tr'), Locale('en')],
      path: 'assets/translations',
      fallbackLocale: const Locale('tr'),
      child: ProviderScope(
        overrides: [
          isLoggedInProvider.overrideWithValue(true),
          sessionRepositoryProvider.overrideWithValue(repo),
          exerciseRepositoryProvider.overrideWithValue(FakeExerciseRepository([_bench])),
          oneRepMaxRepositoryProvider.overrideWithValue(FakeOneRepMaxRepository()),
          nowProvider.overrideWithValue(() => _now),
          clockProvider.overrideWith((ref) => Stream.value(_now)),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
  }

  String fieldText(WidgetTester tester, String key) =>
      tester.widget<TextField>(find.byKey(Key(key))).controller!.text;

  Future<void> open(WidgetTester tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();
  }

  testWidgets('shows the exercise with prefilled values, elapsed time and deload note', (tester) async {
    await open(tester);

    expect(find.byKey(const Key('session_screen')), findsOneWidget);
    expect(find.text('Barbell Squat'), findsOneWidget);
    expect(fieldText(tester, 'set_weight_a'), '60');
    expect(fieldText(tester, 'set_reps_a'), '5');
    expect(find.text('30:00'), findsOneWidget);
    expect(find.byKey(const Key('set_deloaded_b')), findsOneWidget);
    expect(find.byKey(const Key('set_deloaded_a')), findsNothing);
  });

  testWidgets('checking a set saves it and starts the rest timer', (tester) async {
    await open(tester);

    await tester.tap(find.byKey(const Key('set_check_a')));
    await tester.pumpAndSettle();

    expect(repo.updatedSets.single.weightKg, 60);
    expect(repo.updatedSets.single.reps, 5);
    expect(find.byKey(const Key('rest_timer_bar')), findsOneWidget);
    expect(find.text('01:30'), findsOneWidget);

    await tester.tap(find.byKey(const Key('rest_timer_add')));
    await tester.pumpAndSettle();
    expect(find.text('02:00'), findsOneWidget);

    await tester.tap(find.byKey(const Key('rest_timer_skip')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('rest_timer_bar')), findsNothing);
  });

  testWidgets('a failed save reverts the check and shows an error', (tester) async {
    repo.updateError = Exception('offline');
    await open(tester);

    await tester.tap(find.byKey(const Key('set_check_a')));
    await tester.pumpAndSettle();

    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.byKey(const Key('rest_timer_bar')), findsNothing);
    expect(
      find.descendant(of: find.byKey(const Key('set_check_a')), matching: find.byIcon(Icons.check_circle_outline)),
      findsOneWidget,
    );
  });

  testWidgets('editing the first weight fills the following set', (tester) async {
    await open(tester);

    await tester.enterText(find.byKey(const Key('set_weight_a')), '65');
    await tester.pumpAndSettle();

    expect(fieldText(tester, 'set_weight_b'), '65');
  });

  testWidgets('adding an exercise appends its card', (tester) async {
    await open(tester);

    await tester.tap(find.byKey(const Key('session_add_exercise')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('PICK'));
    await tester.pumpAndSettle();

    expect(find.text('Bench Press'), findsOneWidget);
    expect(find.byKey(const Key('session_exercise_1')), findsOneWidget);
  });

  testWidgets('removing an exercise drops its pending sets', (tester) async {
    await open(tester);

    await tester.tap(find.byKey(const Key('session_exercise_menu_0')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('session_remove_exercise_0')));
    await tester.pumpAndSettle();

    expect(find.text('Barbell Squat'), findsNothing);
    expect(repo.deletedSetIds, ['a', 'b']);
  });

  testWidgets('cancel deletes the session after confirmation and goes home', (tester) async {
    await open(tester);

    await tester.tap(find.byKey(const Key('session_menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('session_cancel_item')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('session_cancel_confirm')));
    await tester.pumpAndSettle();

    expect(repo.sessions, isEmpty);
    expect(find.text('HOME'), findsOneWidget);
  });

  testWidgets('finish without completed sets offers to cancel', (tester) async {
    await open(tester);

    await tester.tap(find.byKey(const Key('session_finish_button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('session_no_sets_dialog')), findsOneWidget);

    await tester.tap(find.byKey(const Key('session_no_sets_cancel')));
    await tester.pumpAndSettle();
    expect(find.text('HOME'), findsOneWidget);
  });

  testWidgets('finish with completed sets opens the summary', (tester) async {
    await open(tester);

    await tester.tap(find.byKey(const Key('set_check_a')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('session_finish_button')));
    await tester.pumpAndSettle();

    expect(find.text('SUMMARY'), findsOneWidget);
  });
}
