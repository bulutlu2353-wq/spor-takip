import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spor_takip/features/onboarding/application/auth_providers.dart';
import 'package:spor_takip/features/onboarding/application/profile_providers.dart';
import 'package:spor_takip/features/onboarding/domain/profile.dart';
import 'package:spor_takip/features/settings/domain/profile_edit.dart';
import 'package:spor_takip/features/settings/presentation/goals_screen.dart';
import 'package:spor_takip/features/workout/application/session_providers.dart';

import '../../progress/fixtures.dart';
import '../../progress/presentation/test_app.dart';
import '../fakes.dart';

void main() {
  setUpAll(initTestLocalization);

  late FakeProfileRepository repo;

  setUp(() => repo = FakeProfileRepository());

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(testApp(
      const GoalsScreen(),
      scaffold: false,
      overrides: [
        // testProfile: koru, odak {kas}.
        profileProvider.overrideWith((ref) async => testProfile),
        profileRepositoryProvider.overrideWithValue(repo),
        authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
        nowProvider.overrideWithValue(() => DateTime(2026, 10, 7, 9)),
      ],
    ));
    await tester.pumpAndSettle();
  }

  FilledButton saveButton(WidgetTester tester) => tester.widget<FilledButton>(
        find.descendant(of: find.byKey(const Key('goals_save')), matching: find.byType(FilledButton)),
      );

  bool paceSelected(WidgetTester tester, Pace pace) => tester.any(find.descendant(
        of: find.byKey(Key('choice_option_$pace')),
        matching: find.byIcon(Icons.check_circle),
      ));

  testWidgets('maintaining hides the pace; losing shows it with balanced selected', (tester) async {
    await pump(tester);
    expect(find.byKey(const Key('choice_option_Pace.balanced')), findsNothing);
    expect(find.byKey(const Key('settings_targets_preview')), findsOneWidget);
    expect(saveButton(tester).onPressed, isNull);

    await tester.tap(find.byKey(const Key('goal_direction_lose')));
    await tester.pumpAndSettle();
    expect(paceSelected(tester, Pace.balanced), isTrue);
    expect(saveButton(tester).onPressed, isNotNull);

    await tester.tap(find.byKey(const Key('goal_direction_maintain')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('choice_option_Pace.balanced')), findsNothing);
  });

  testWidgets('save is disabled without a focus', (tester) async {
    await pump(tester);
    await tester.tap(find.byKey(const Key('goal_direction_gain')));
    await tester.tap(find.byKey(const Key('goal_focus_muscle')));
    await tester.pumpAndSettle();
    expect(saveButton(tester).onPressed, isNull);
  });

  testWidgets('save writes the goal and the new targets', (tester) async {
    await pump(tester);
    await tester.tap(find.byKey(const Key('goal_direction_gain')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('goal_focus_strength')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('goals_save')));
    await tester.pumpAndSettle();

    final edited = testProfile.copyWith(
      weightDirection: WeightDirection.gain,
      pace: Pace.balanced,
      focuses: {GoalFocus.muscle, GoalFocus.strength},
    );
    final targets = targetsFor(edited, currentYear: 2026);
    expect(repo.updates.single, {
      'weight_direction': 'gain',
      'pace': 'balanced',
      'focuses': ['muscle', 'strength'],
      'daily_calorie_target': targets.calorieTarget,
      'daily_protein_target_g': targets.proteinTargetG,
    });
  });
}
