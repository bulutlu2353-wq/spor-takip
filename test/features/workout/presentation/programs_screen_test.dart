import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spor_takip/features/workout/application/workout_providers.dart';
import 'package:spor_takip/features/workout/data/program_repository.dart';
import 'package:spor_takip/features/workout/domain/program.dart';
import 'package:spor_takip/features/workout/domain/program_level.dart';
import 'package:spor_takip/features/workout/domain/schedule_mode.dart';
import 'package:spor_takip/features/workout/presentation/programs_screen.dart';

const _stronglifts = Program(
  id: 'sl',
  name: 'StrongLifts 5x5',
  level: ProgramLevel.beginner,
  scheduleMode: ScheduleMode.rotation,
  daysPerWeek: 3,
  workouts: [],
);
const _nsuns = Program(
  id: 'ns',
  name: 'nSuns 5/3/1 LP 4 gün',
  level: ProgramLevel.advanced,
  scheduleMode: ScheduleMode.weekdays,
  daysPerWeek: 4,
  workouts: [],
);
const _mine = Program(
  id: 'mine',
  userId: 'user-1',
  name: 'Benim programım',
  scheduleMode: ScheduleMode.weekdays,
  workouts: [],
);

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  Widget wrap({required List<Program> programs, String? activeId}) {
    final router = GoRouter(routes: [
      GoRoute(path: '/', builder: (context, state) => const ProgramsScreen()),
      GoRoute(path: '/workout/new', builder: (context, state) => const Text('EDITOR_NEW')),
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
        overrides: [
          programsProvider.overrideWith((ref) async => programs),
          activeProgramStateProvider.overrideWith((ref) async => ActiveProgramState(programId: activeId)),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
  }

  testWidgets('shows my programs and built-in programs', (tester) async {
    await tester.pumpWidget(wrap(programs: [_stronglifts, _nsuns, _mine]));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('programs_screen')), findsOneWidget);
    expect(find.text('Benim programım'), findsOneWidget);
    expect(find.text('StrongLifts 5x5'), findsOneWidget);
    expect(find.text('nSuns 5/3/1 LP 4 gün'), findsOneWidget);
    expect(find.byKey(const Key('programs_active_section')), findsNothing);
  });

  testWidgets('shows the active program at the top', (tester) async {
    await tester.pumpWidget(wrap(programs: [_stronglifts, _mine], activeId: 'sl'));
    await tester.pumpAndSettle();

    final activeSection = find.byKey(const Key('programs_active_section'));
    expect(activeSection, findsOneWidget);
    expect(find.descendant(of: activeSection, matching: find.text('StrongLifts 5x5')), findsOneWidget);
  });

  testWidgets('level and day filters narrow the built-in list', (tester) async {
    await tester.pumpWidget(wrap(programs: [_stronglifts, _nsuns]));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('programs_level_filter_advanced')));
    await tester.pumpAndSettle();
    expect(find.text('StrongLifts 5x5'), findsNothing);
    expect(find.text('nSuns 5/3/1 LP 4 gün'), findsOneWidget);

    await tester.tap(find.byKey(const Key('programs_level_filter_all')));
    await tester.tap(find.byKey(const Key('programs_days_filter_3')));
    await tester.pumpAndSettle();
    expect(find.text('StrongLifts 5x5'), findsOneWidget);
    expect(find.text('nSuns 5/3/1 LP 4 gün'), findsNothing);
  });

  testWidgets('tapping a card opens its detail, FAB opens the empty editor', (tester) async {
    await tester.pumpWidget(wrap(programs: [_stronglifts]));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('program_card_sl')));
    await tester.pumpAndSettle();
    expect(find.text('DETAIL_sl'), findsOneWidget);
  });

  testWidgets('create FAB navigates to the new-program editor', (tester) async {
    await tester.pumpWidget(wrap(programs: const []));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('programs_create_fab')));
    await tester.pumpAndSettle();
    expect(find.text('EDITOR_NEW'), findsOneWidget);
  });
}
