import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spor_takip/features/onboarding/application/auth_providers.dart';
import 'package:spor_takip/features/workout/application/workout_providers.dart';
import 'package:spor_takip/features/workout/domain/exercise.dart';
import 'package:spor_takip/features/workout/presentation/exercise_picker_screen.dart';

import '../fakes.dart';

const _squat = Exercise(
  id: 'Barbell_Squat',
  name: 'Barbell Squat',
  equipment: 'barbell',
  primaryMuscles: ['quadriceps'],
  instructions: ['Stand under the bar.'],
  images: ['Barbell_Squat/0.jpg'],
);
const _pushups = Exercise(id: 'Pushups', name: 'Pushups', equipment: 'body only', primaryMuscles: ['chest']);
const _mine = Exercise(id: 'custom-0', userId: 'user-1', name: 'My Move', primaryMuscles: ['chest']);

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  late FakeExerciseRepository repo;

  setUp(() => repo = FakeExerciseRepository([_squat, _pushups, _mine]));

  Widget wrap() {
    final router = GoRouter(initialLocation: '/caller', routes: [
      GoRoute(
        path: '/caller',
        builder: (context, state) => _Caller(),
      ),
      GoRoute(path: '/workout/exercises', builder: (context, state) => const ExercisePickerScreen()),
    ]);
    return EasyLocalization(
      supportedLocales: const [Locale('tr'), Locale('en')],
      path: 'assets/translations',
      fallbackLocale: const Locale('tr'),
      child: ProviderScope(
        overrides: [
          isLoggedInProvider.overrideWithValue(true),
          exerciseRepositoryProvider.overrideWithValue(repo),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
  }

  Future<void> openPicker(WidgetTester tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('open_picker')));
    await tester.pumpAndSettle();
  }

  testWidgets('search narrows the list', (tester) async {
    await openPicker(tester);
    expect(find.byKey(const Key('exercise_tile_Barbell_Squat')), findsOneWidget);

    await tester.enterText(find.byKey(const Key('exercise_search_field')), 'push');
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('exercise_tile_Barbell_Squat')), findsNothing);
    expect(find.byKey(const Key('exercise_tile_Pushups')), findsOneWidget);
  });

  testWidgets('muscle filter chip narrows the list', (tester) async {
    await openPicker(tester);

    // The chip row scrolls horizontally and lazily builds only chips near
    // the viewport; with translation keys unresolved in the test
    // environment (fallback text is the raw, long key) later chips such as
    // quadriceps land off the default test viewport and aren't mounted
    // yet, so drag the row until it comes into view before tapping —
    // matches how a real user would reach it too.
    await tester.dragUntilVisible(
      find.byKey(const Key('muscle_filter_quadriceps')),
      find.byKey(const Key('muscle_filter_row')),
      const Offset(-300, 0),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('muscle_filter_quadriceps')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('exercise_tile_Barbell_Squat')), findsOneWidget);
    expect(find.byKey(const Key('exercise_tile_Pushups')), findsNothing);
  });

  testWidgets('detail sheet shows a fallback when the image fails and select returns the exercise',
      (tester) async {
    await openPicker(tester);

    await tester.tap(find.byKey(const Key('exercise_tile_Barbell_Squat')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Stand under the bar.'), findsOneWidget);
    expect(find.byKey(const Key('exercise_image_fallback')), findsWidgets);

    await tester.tap(find.byKey(const Key('exercise_select_button')));
    await tester.pumpAndSettle();

    expect(find.text('PICKED_Barbell_Squat'), findsOneWidget);
  });

  testWidgets('creating a custom exercise returns it to the caller', (tester) async {
    await openPicker(tester);

    await tester.tap(find.byKey(const Key('exercise_create_fab')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('custom_exercise_name')), 'Landmine Press');
    await tester.tap(find.byKey(const Key('custom_exercise_save')));
    await tester.pumpAndSettle();

    expect(repo.exercises.last.name, 'Landmine Press');
    expect(find.textContaining('PICKED_custom-'), findsOneWidget);
  });

  testWidgets('deleting a custom exercise that is in use shows a message', (tester) async {
    repo.inUseIds.add('custom-0');
    await openPicker(tester);

    await tester.longPress(find.byKey(const Key('exercise_tile_custom-0')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('custom_delete_confirm')));
    await tester.pumpAndSettle();

    expect(repo.deletedIds, isEmpty);
    expect(find.byType(SnackBar), findsOneWidget);
  });
}

class _Caller extends StatefulWidget {
  @override
  State<_Caller> createState() => _CallerState();
}

class _CallerState extends State<_Caller> {
  String _picked = 'NONE';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Text('PICKED_$_picked'),
          TextButton(
            key: const Key('open_picker'),
            onPressed: () async {
              final e = await context.push<Exercise>('/workout/exercises');
              if (e != null) setState(() => _picked = e.id);
            },
            child: const Text('OPEN'),
          ),
        ],
      ),
    );
  }
}
