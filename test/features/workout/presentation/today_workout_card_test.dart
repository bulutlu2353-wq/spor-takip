import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spor_takip/features/onboarding/application/auth_providers.dart';
import 'package:spor_takip/features/workout/application/workout_providers.dart';
import 'package:spor_takip/features/workout/data/program_repository.dart';
import 'package:spor_takip/features/workout/domain/program.dart';
import 'package:spor_takip/features/workout/domain/program_workout.dart';
import 'package:spor_takip/features/workout/domain/schedule_mode.dart';
import 'package:spor_takip/features/workout/domain/today_workout.dart';
import 'package:spor_takip/features/workout/presentation/widgets/today_workout_card.dart';

import '../fakes.dart';

const _rotation = Program(
  id: 'rot',
  userId: 'user-1',
  name: 'Rotasyon',
  scheduleMode: ScheduleMode.rotation,
  workouts: [
    ProgramWorkout(name: 'Antrenman A', exercises: []),
    ProgramWorkout(name: 'Antrenman B', exercises: []),
  ],
);

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  Widget wrap(List overrides) {
    final router = GoRouter(routes: [
      GoRoute(path: '/', builder: (context, state) => const Scaffold(body: TodayWorkoutCard())),
      GoRoute(path: '/workout', builder: (context, state) => const Text('PROGRAMS')),
      GoRoute(
        path: '/workout/program/:id',
        builder: (context, state) => Text('DETAIL_${state.pathParameters['id']}'),
      ),
    ]);
    return EasyLocalization(
      supportedLocales: const [Locale('tr'), Locale('en')],
      path: 'assets/translations',
      fallbackLocale: const Locale('tr'),
      child: ProviderScope(
        overrides: [isLoggedInProvider.overrideWithValue(true), ...overrides.cast()],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
  }

  testWidgets('without an active program it links to the programs tab', (tester) async {
    await tester.pumpWidget(wrap([todayWorkoutProvider.overrideWith((ref) async => const NoActiveProgram())]));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('today_no_program')), findsOneWidget);
    await tester.tap(find.byKey(const Key('today_choose_program')));
    await tester.pumpAndSettle();
    expect(find.text('PROGRAMS'), findsOneWidget);
  });

  testWidgets('rest day', (tester) async {
    await tester.pumpWidget(wrap([
      todayWorkoutProvider.overrideWith((ref) async => const RestDay(_rotation)),
    ]));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('today_rest_day')), findsOneWidget);
  });

  testWidgets('rotation: shows the next workout, Done advances it, tap opens detail', (tester) async {
    final repo = FakeProgramRepository(
      programs: [_rotation],
      active: const ActiveProgramState(programId: 'rot'),
    );
    await tester.pumpWidget(wrap([programRepositoryProvider.overrideWithValue(repo)]));
    await tester.pumpAndSettle();

    expect(find.text('Antrenman A'), findsOneWidget);
    await tester.tap(find.byKey(const Key('today_done_button')));
    await tester.pumpAndSettle();

    expect(repo.active.nextRotationPosition, 1);
    expect(find.text('Antrenman B'), findsOneWidget);

    await tester.tap(find.byKey(const Key('today_scheduled')));
    await tester.pumpAndSettle();
    expect(find.text('DETAIL_rot'), findsOneWidget);
  });
}
