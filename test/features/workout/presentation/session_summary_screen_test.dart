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
import 'package:spor_takip/features/workout/presentation/session_summary_screen.dart';

import '../fakes.dart';

const _squat = Exercise(id: 'Barbell_Squat', name: 'Barbell Squat');
final _now = DateTime(2026, 9, 26, 10, 45);

final _session = WorkoutSession(
  id: 'sess',
  programId: 'bbb',
  programName: '5/3/1 BBB',
  workoutName: 'Hafta 1 · Squat',
  workoutPosition: 0,
  startedAt: DateTime(2026, 9, 26, 10),
  sets: [
    SessionSet(
      id: 'amrap',
      exercisePosition: 0,
      setIndex: 0,
      exerciseId: 'Barbell_Squat',
      exerciseName: 'Barbell Squat',
      targetRepsMin: 5,
      targetRepsMax: 5,
      isAmrap: true,
      percent1rm: 85,
      weightKg: 85,
      reps: 8,
      completedAt: DateTime(2026, 9, 26, 10, 20),
    ),
    SessionSet(
      id: 'bench',
      exercisePosition: 1,
      setIndex: 0,
      exerciseId: 'Bench',
      exerciseName: 'Bench Press',
      targetRepsMin: 5,
      targetRepsMax: 5,
      weightKg: 40,
      reps: 5,
      completedAt: DateTime(2026, 9, 26, 10, 30),
    ),
  ],
);

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  late FakeSessionRepository repo;

  setUp(() => repo = FakeSessionRepository(sessions: [_session]));

  Widget wrap() {
    final router = GoRouter(initialLocation: '/session/sess/summary', routes: [
      GoRoute(path: '/home', builder: (context, state) => const Text('HOME')),
      GoRoute(
        path: '/session/:id',
        builder: (context, state) => const Text('SESSION'),
        routes: [
          GoRoute(
            path: 'summary',
            builder: (context, state) => SessionSummaryScreen(sessionId: state.pathParameters['id']!),
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
          exerciseRepositoryProvider.overrideWithValue(FakeExerciseRepository([_squat])),
          oneRepMaxRepositoryProvider.overrideWithValue(FakeOneRepMaxRepository()..values['Barbell_Squat'] = 100),
          nowProvider.overrideWithValue(() => _now),
          clockProvider.overrideWith((ref) => Stream.value(_now)),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
  }

  testWidgets('shows stats and saves the 1RM suggestion by default', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('session_summary_screen')), findsOneWidget);
    expect(find.text('45:00'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('880 kg'), findsOneWidget);
    expect(find.text('100 → 105 kg'), findsOneWidget);

    await tester.tap(find.byKey(const Key('summary_save_button')));
    await tester.pumpAndSettle();

    expect(repo.finished.single.oneRepMaxes, {'Barbell_Squat': 105.0});
    expect(find.text('HOME'), findsOneWidget);
  });

  testWidgets('an unticked suggestion is not saved', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('summary_1rm_Barbell_Squat')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('summary_save_button')));
    await tester.pumpAndSettle();

    expect(repo.finished.single.oneRepMaxes, isEmpty);
  });

  testWidgets('a failed finish keeps the summary open', (tester) async {
    repo.finishError = Exception('offline');
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('summary_save_button')));
    await tester.pumpAndSettle();

    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.byKey(const Key('session_summary_screen')), findsOneWidget);
  });
}
