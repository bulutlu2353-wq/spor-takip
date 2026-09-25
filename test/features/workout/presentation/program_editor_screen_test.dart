import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spor_takip/features/onboarding/application/auth_providers.dart';
import 'package:spor_takip/features/workout/application/workout_providers.dart';
import 'package:spor_takip/features/workout/domain/exercise.dart';
import 'package:spor_takip/features/workout/domain/program.dart';
import 'package:spor_takip/features/workout/domain/program_workout.dart';
import 'package:spor_takip/features/workout/domain/schedule_mode.dart';
import 'package:spor_takip/features/workout/domain/workout_exercise.dart';
import 'package:spor_takip/features/workout/presentation/program_editor_screen.dart';

import '../fakes.dart';

const _picked = Exercise(id: 'Barbell_Squat', name: 'Barbell Squat');

const _existing = Program(
  id: 'mine',
  userId: 'user-1',
  name: 'Benim programım',
  scheduleMode: ScheduleMode.rotation,
  workouts: [
    ProgramWorkout(name: 'A', exercises: [
      WorkoutExercise(exerciseId: 'Bench', exerciseName: 'Bench', sets: 3, repsMin: 8, repsMax: 12),
      WorkoutExercise(exerciseId: 'Row', exerciseName: 'Row', sets: 3, repsMin: 8, repsMax: 12),
    ]),
  ],
);

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  late FakeProgramRepository repo;

  setUp(() => repo = FakeProgramRepository(programs: [_existing]));

  Widget wrap(String initial) {
    final router = GoRouter(initialLocation: '/workout', routes: [
      GoRoute(
        path: '/workout',
        builder: (context, state) => const Text('PROGRAMS'),
        routes: [
          GoRoute(path: 'new', builder: (context, state) => const ProgramEditorScreen()),
          GoRoute(
            path: 'exercises',
            builder: (context, state) => Scaffold(
              body: TextButton(
                key: const Key('fake_pick'),
                onPressed: () => context.pop(_picked),
                child: const Text('PICK'),
              ),
            ),
          ),
          GoRoute(
            path: 'program/:id',
            builder: (context, state) => Text('DETAIL_${state.pathParameters['id']}'),
            routes: [
              GoRoute(
                path: 'edit',
                builder: (context, state) => ProgramEditorScreen(programId: state.pathParameters['id']),
              ),
            ],
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
          programRepositoryProvider.overrideWithValue(repo),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
  }

  Future<void> open(WidgetTester tester, String location) async {
    await tester.pumpWidget(wrap(location));
    await tester.pumpAndSettle();
    GoRouter.of(tester.element(find.text('PROGRAMS'))).push(location);
    await tester.pumpAndSettle();
  }

  testWidgets('builds a new weekdays program and saves it', (tester) async {
    await open(tester, '/workout/new');

    await tester.enterText(find.byKey(const Key('editor_name_field')), 'Yeni program');
    await tester.tap(find.byKey(const Key('editor_add_workout')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('editor_weekday_0')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('weekday_option_1')).last);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('editor_add_block_0')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('fake_pick')));
    await tester.pumpAndSettle();
    expect(find.text('Barbell Squat'), findsOneWidget);

    await tester.tap(find.byKey(const Key('editor_save_button')));
    await tester.pumpAndSettle();

    final saved = repo.savedPrograms.single;
    expect(saved.name, 'Yeni program');
    expect(saved.workouts.single.weekday, 1);
    expect(saved.workouts.single.exercises.single.exerciseId, 'Barbell_Squat');
    expect(find.text('DETAIL_new-1'), findsOneWidget);
  });

  testWidgets('does not save an invalid program', (tester) async {
    await open(tester, '/workout/new');

    await tester.tap(find.byKey(const Key('editor_save_button')));
    await tester.pumpAndSettle();

    expect(repo.savedPrograms, isEmpty);
    expect(find.byType(SnackBar), findsOneWidget);
  });

  testWidgets('edits an existing program: loads it, reorders a block, saves and pops', (tester) async {
    await tester.pumpWidget(wrap('/workout'));
    await tester.pumpAndSettle();
    final router = GoRouter.of(tester.element(find.text('PROGRAMS')));
    router.push('/workout/program/mine');
    await tester.pumpAndSettle();
    router.push('/workout/program/mine/edit');
    await tester.pumpAndSettle();

    expect(find.widgetWithText(TextField, 'Benim programım'), findsOneWidget);

    await tester.tap(find.byKey(const Key('editor_block_menu_0_1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('block_menu_up')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('editor_save_button')));
    await tester.pumpAndSettle();

    expect(repo.savedPrograms.single.workouts.single.exercises.map((b) => b.exerciseId), ['Row', 'Bench']);
    expect(find.text('DETAIL_mine'), findsOneWidget);
  });

  testWidgets('leaving with unsaved changes asks for confirmation', (tester) async {
    await open(tester, '/workout/new');
    await tester.enterText(find.byKey(const Key('editor_name_field')), 'Taslak');
    await tester.pumpAndSettle();

    final navigator = tester.state<NavigatorState>(find.byType(Navigator).last);
    navigator.maybePop();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('discard_confirm')));
    await tester.pumpAndSettle();

    expect(find.text('PROGRAMS'), findsOneWidget);
    expect(repo.savedPrograms, isEmpty);
  });

  testWidgets('editing a block through the dialog updates sets and reps', (tester) async {
    await tester.pumpWidget(wrap('/workout'));
    await tester.pumpAndSettle();
    final router = GoRouter.of(tester.element(find.text('PROGRAMS')));
    router.push('/workout/program/mine/edit');
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('editor_block_0_0')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('block_sets_field')), '5');
    await tester.enterText(find.byKey(const Key('block_reps_min_field')), '5');
    await tester.enterText(find.byKey(const Key('block_reps_max_field')), '5');
    await tester.tap(find.byKey(const Key('block_save_button')));
    await tester.pumpAndSettle();

    expect(find.textContaining('5 × 5'), findsOneWidget);
  });
}
