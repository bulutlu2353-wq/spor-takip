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

const _sumo = WorkoutExercise(
  exerciseId: 'Sumo_Deadlift',
  exerciseName: 'Sumo Deadlift',
  sets: 1,
  repsMin: 5,
  repsMax: 5,
  percent1rm: 45,
  percentRefExerciseId: 'Barbell_Deadlift',
);
const _deadlift = WorkoutExercise(
  exerciseId: 'Barbell_Deadlift',
  exerciseName: 'Barbell Deadlift',
  sets: 1,
  repsMin: 5,
  repsMax: 5,
  percent1rm: 67.5,
);
const _percentProgram = Program(
  id: 'ns',
  name: 'nSuns',
  scheduleMode: ScheduleMode.weekdays,
  workouts: [ProgramWorkout(name: 'Gün', weekday: 5, exercises: [_deadlift, _sumo])],
);

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  late FakeProgramRepository programRepo;
  late FakeOneRepMaxRepository oneRepMaxRepo;

  setUp(() {
    programRepo = FakeProgramRepository(programs: [_percentProgram]);
    oneRepMaxRepo = FakeOneRepMaxRepository();
  });

  Widget wrap() {
    final router = GoRouter(routes: [
      GoRoute(path: '/', builder: (context, state) => const ProgramDetailScreen(programId: 'ns')),
    ]);
    return EasyLocalization(
      supportedLocales: const [Locale('tr'), Locale('en')],
      path: 'assets/translations',
      fallbackLocale: const Locale('tr'),
      child: ProviderScope(
        overrides: [
          isLoggedInProvider.overrideWithValue(true),
          programRepositoryProvider.overrideWithValue(programRepo),
          oneRepMaxRepositoryProvider.overrideWithValue(oneRepMaxRepo),
          exerciseRepositoryProvider.overrideWithValue(FakeExerciseRepository()),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
  }

  testWidgets('activating a percentage program asks for the referenced 1RMs, saves them and activates',
      (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('program_activate_button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('one_rep_max_sheet')), findsOneWidget);
    // Sumo, deadlift'in 1RM'sine dayandığı için tek alan var.
    expect(find.byKey(const Key('one_rep_max_field_Barbell_Deadlift')), findsOneWidget);
    expect(find.byKey(const Key('one_rep_max_field_Sumo_Deadlift')), findsNothing);

    await tester.enterText(find.byKey(const Key('one_rep_max_field_Barbell_Deadlift')), '200');
    await tester.tap(find.byKey(const Key('one_rep_max_save')));
    await tester.pumpAndSettle();

    expect(oneRepMaxRepo.values, {'Barbell_Deadlift': 200.0});
    expect(programRepo.active.programId, 'ns');
    expect(find.textContaining('135 kg'), findsOneWidget); // 200 × %67.5
    expect(find.textContaining('90 kg'), findsOneWidget); // 200 × %45
  });

  testWidgets('skipping the sheet still activates the program', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('program_activate_button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('one_rep_max_skip')));
    await tester.pumpAndSettle();

    expect(oneRepMaxRepo.values, isEmpty);
    expect(programRepo.active.programId, 'ns');
  });

  testWidgets('1RM button opens the sheet prefilled with saved values', (tester) async {
    oneRepMaxRepo.values['Barbell_Deadlift'] = 180;
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('program_one_rep_max_button')));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(TextField, '180'), findsOneWidget);
  });
}
