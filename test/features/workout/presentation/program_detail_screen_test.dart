import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spor_takip/features/onboarding/application/auth_providers.dart';
import 'package:spor_takip/features/workout/application/workout_providers.dart';
import 'package:spor_takip/features/workout/domain/program.dart';
import 'package:spor_takip/features/workout/domain/program_workout.dart';
import 'package:spor_takip/features/workout/domain/schedule_mode.dart';
import 'package:spor_takip/features/workout/domain/workout_exercise.dart';
import 'package:spor_takip/features/workout/presentation/program_detail_screen.dart';

import '../fakes.dart';

const _squat5 = WorkoutExercise(
  exerciseId: 'Barbell_Squat',
  exerciseName: 'Barbell Squat',
  sets: 1,
  repsMin: 5,
  repsMax: 5,
  percent1rm: 58.5,
);
const _squat5plus = WorkoutExercise(
  exerciseId: 'Barbell_Squat',
  exerciseName: 'Barbell Squat',
  sets: 1,
  repsMin: 5,
  repsMax: 5,
  isAmrap: true,
  percent1rm: 76.5,
);

const _builtIn = Program(
  id: 'bbb',
  name: '5/3/1 BBB',
  scheduleMode: ScheduleMode.rotation,
  workouts: [ProgramWorkout(name: 'Hafta 1 · Squat', exercises: [_squat5, _squat5plus])],
);
const _mine = Program(
  id: 'mine',
  userId: 'user-1',
  name: 'Benim programım',
  scheduleMode: ScheduleMode.weekdays,
  workouts: [ProgramWorkout(name: 'Bacak', weekday: 1, exercises: [_squat5])],
);

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  late FakeProgramRepository repo;
  late FakeOneRepMaxRepository oneRepMaxRepo;

  Widget wrap(String programId) {
    final router = GoRouter(initialLocation: '/workout', routes: [
      GoRoute(
        path: '/workout',
        builder: (context, state) => const Text('PROGRAMS'),
        routes: [
          GoRoute(
            path: 'program/:id',
            builder: (context, state) => ProgramDetailScreen(programId: state.pathParameters['id']!),
            routes: [
              GoRoute(
                path: 'edit',
                builder: (context, state) => Text('EDITOR_${state.pathParameters['id']}'),
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
          oneRepMaxRepositoryProvider.overrideWithValue(oneRepMaxRepo),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
  }

  Future<void> open(WidgetTester tester, String id) async {
    await tester.pumpWidget(wrap(id));
    await tester.pumpAndSettle();
    GoRouter.of(tester.element(find.text('PROGRAMS'))).push('/workout/program/$id');
    await tester.pumpAndSettle();
  }

  setUp(() {
    repo = FakeProgramRepository(programs: [_builtIn, _mine]);
    oneRepMaxRepo = FakeOneRepMaxRepository();
  });

  testWidgets('groups consecutive blocks and shows percentages without a 1RM', (tester) async {
    await open(tester, 'bbb');

    expect(find.byKey(const Key('program_detail_screen')), findsOneWidget);
    expect(find.text('Barbell Squat'), findsOneWidget); // iki blok tek başlık
    expect(find.textContaining('1 × 5+'), findsOneWidget);
    expect(find.textContaining('%76.5'), findsOneWidget);
  });

  testWidgets('shows kilograms when a 1RM is known', (tester) async {
    oneRepMaxRepo.values['Barbell_Squat'] = 100;
    await open(tester, 'bbb');

    expect(find.textContaining('77.5 kg'), findsOneWidget);
    expect(find.textContaining('57.5 kg'), findsOneWidget);
  });

  testWidgets('built-in program offers customize, which copies and opens the editor', (tester) async {
    await open(tester, 'bbb');

    expect(find.byKey(const Key('program_edit_button')), findsNothing);
    expect(find.byKey(const Key('program_delete_button')), findsNothing);
    await tester.tap(find.byKey(const Key('program_customize_button')));
    await tester.pumpAndSettle();

    expect(repo.copiedIds, ['bbb']);
    expect(find.text('EDITOR_copy-of-bbb'), findsOneWidget);
  });

  testWidgets('activate sets the active program and shows the badge', (tester) async {
    await open(tester, 'mine');

    expect(find.byKey(const Key('program_active_badge')), findsNothing);
    await tester.tap(find.byKey(const Key('program_activate_button')));
    await tester.pumpAndSettle();

    expect(repo.active.programId, 'mine');
    expect(find.byKey(const Key('program_active_badge')), findsOneWidget);
  });

  testWidgets('own program can be deleted after confirmation', (tester) async {
    await open(tester, 'mine');

    await tester.tap(find.byKey(const Key('program_delete_button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('program_delete_confirm')));
    await tester.pumpAndSettle();

    expect(repo.deletedIds, ['mine']);
    expect(find.text('PROGRAMS'), findsOneWidget);
  });
}
