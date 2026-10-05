import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spor_takip/features/onboarding/application/auth_providers.dart';
import 'package:spor_takip/features/onboarding/application/profile_providers.dart';
import 'package:spor_takip/features/progress/application/progress_providers.dart';
import 'package:spor_takip/features/progress/domain/weekly_summary.dart';
import 'package:spor_takip/features/workout/application/session_providers.dart';
import 'package:spor_takip/features/workout/domain/workout_session.dart';
import 'package:spor_takip/features/workout/presentation/history_detail_screen.dart';
import 'package:spor_takip/features/workout/presentation/history_screen.dart';

import '../../progress/fixtures.dart';
import '../fakes.dart';

SessionSet _set(String id, {int idx = 0, bool done = true}) => SessionSet(
      id: id,
      exercisePosition: 0,
      setIndex: idx,
      exerciseId: 'Barbell_Squat',
      exerciseName: 'Barbell Squat',
      targetRepsMin: 5,
      targetRepsMax: 5,
      weightKg: done ? 60 : null,
      reps: done ? 5 : null,
      completedAt: done ? DateTime(2026, 9, 20, 10, 10) : null,
    );

final _finished = WorkoutSession(
  id: 'h1',
  programName: 'StrongLifts 5x5',
  workoutName: 'Antrenman A',
  workoutPosition: 0,
  startedAt: DateTime(2026, 9, 20, 10),
  finishedAt: DateTime(2026, 9, 20, 10, 50),
  sets: [_set('x1'), _set('x2', idx: 1, done: false)],
);

final _inProgress = WorkoutSession(
  id: 'cur',
  programName: 'StrongLifts 5x5',
  workoutName: 'Antrenman B',
  workoutPosition: 1,
  startedAt: DateTime(2026, 9, 26, 10),
);

final _lastYear = WorkoutSession(
  id: 'old',
  programName: 'StrongLifts 5x5',
  workoutName: 'Antrenman A',
  workoutPosition: 0,
  startedAt: DateTime(2025, 12, 30, 10),
  finishedAt: DateTime(2025, 12, 30, 10, 40),
  sets: [_set('y1')],
);

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  Widget wrap(FakeSessionRepository repo) {
    final router = GoRouter(initialLocation: '/workout/history', routes: [
      GoRoute(
        path: '/workout/history',
        builder: (context, state) => const HistoryScreen(),
        routes: [
          GoRoute(
            path: ':id',
            builder: (context, state) => HistoryDetailScreen(sessionId: state.pathParameters['id']!),
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
          nowProvider.overrideWithValue(() => DateTime(2026, 9, 26, 12)),
          weeklySummaryProvider.overrideWith((ref) async => weeklySummary(
                now: DateTime(2026, 9, 26, 12),
                sessions: const [],
                meals: const [],
                weights: const [],
              )),
          profileProvider.overrideWith((ref) async => testProfile),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
  }

  testWidgets('lists only finished sessions', (tester) async {
    await tester.pumpWidget(wrap(FakeSessionRepository(sessions: [_finished, _inProgress])));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('history_h1')), findsOneWidget);
    expect(find.byKey(const Key('history_cur')), findsNothing);
    expect(find.textContaining('300 kg'), findsOneWidget);
    expect(find.byKey(const Key('weekly_summary_card')), findsOneWidget);
    expect(find.text('20 ${'home.month_9'.tr()} · 50:00 · 300 kg'), findsOneWidget);
    expect(find.textContaining('StrongLifts'), findsNothing);
  });

  testWidgets('empty history', (tester) async {
    await tester.pumpWidget(wrap(FakeSessionRepository()));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('history_empty')), findsOneWidget);
    expect(find.byKey(const Key('weekly_summary_card')), findsOneWidget);
  });

  testWidgets('detail shows sets and deleting returns to an empty list', (tester) async {
    final repo = FakeSessionRepository(sessions: [_finished]);
    await tester.pumpWidget(wrap(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('history_h1')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('history_detail_screen')), findsOneWidget);
    expect(find.text('Barbell Squat'), findsOneWidget);
    expect(find.text('60 kg × 5'), findsOneWidget);
    expect(find.byKey(const Key('history_set_x2')), findsOneWidget);
    expect(tester.widget<Text>(find.byKey(const Key('history_detail_meta'))).data, contains('STRONGLIFTS 5X5'));
    expect(
      find.descendant(of: find.byKey(const Key('history_detail_volume')), matching: find.text('300 kg')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('history_delete_button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('history_delete_confirm')));
    await tester.pumpAndSettle();

    expect(repo.sessions, isEmpty);
    expect(find.byKey(const Key('history_empty')), findsOneWidget);
  });

  testWidgets('a session from another year shows the year', (tester) async {
    await tester.pumpWidget(wrap(FakeSessionRepository(sessions: [_lastYear])));
    await tester.pumpAndSettle();

    expect(find.text('30 ${'home.month_12'.tr()} 2025 · 40:00 · 300 kg'), findsOneWidget);
  });
}
