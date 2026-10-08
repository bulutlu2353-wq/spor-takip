import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spor_takip/features/onboarding/application/auth_providers.dart';
import 'package:spor_takip/features/onboarding/application/profile_providers.dart';
import 'package:spor_takip/features/settings/domain/profile_edit.dart';
import 'package:spor_takip/features/settings/presentation/settings_screen.dart';
import 'package:spor_takip/features/workout/application/session_providers.dart';

import '../../progress/fixtures.dart';
import '../../progress/presentation/test_app.dart';
import '../fakes.dart';

void main() {
  setUpAll(initTestLocalization);

  late FakeProfileRepository repo;
  late FakeAuthRepository auth;

  setUp(() {
    repo = FakeProfileRepository();
    auth = FakeAuthRepository();
  });

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(testApp(
      const SettingsScreen(),
      scaffold: false,
      stubRoutes: {'/home/weight': 'weight-stub', '/home/settings/goals': 'goals-stub'},
      overrides: [
        profileProvider.overrideWith((ref) async => testProfile),
        profileRepositoryProvider.overrideWithValue(repo),
        authRepositoryProvider.overrideWithValue(auth),
        nowProvider.overrideWithValue(() => DateTime(2026, 10, 7, 9)),
      ],
    ));
    await tester.pumpAndSettle();
  }

  String value(WidgetTester tester, String field) =>
      tester.widget<Text>(find.byKey(Key('settings_value_$field'))).data!;

  testWidgets('shows the goal card, profile values and the account email', (tester) async {
    await pump(tester);

    expect(find.byKey(const Key('settings_goal_card')), findsOneWidget);
    expect(value(tester, 'weight'), '80 kg');
    expect(value(tester, 'height'), '180 cm');
    expect(value(tester, 'birth_year'), '1996');
    expect(value(tester, 'health_notes'), '—');
    expect(find.text('ornek@mail.com'), findsOneWidget);
    expect(find.byKey(const Key('settings_language')), findsOneWidget);
  });

  testWidgets('the weight row opens the weight screen', (tester) async {
    await pump(tester);
    await tester.tap(find.byKey(const Key('settings_row_weight')));
    await tester.pumpAndSettle();
    expect(find.text('weight-stub'), findsOneWidget);
  });

  testWidgets('the goal card opens my goals', (tester) async {
    await pump(tester);
    await tester.tap(find.byKey(const Key('settings_goal_card')));
    await tester.pumpAndSettle();
    expect(find.text('goals-stub'), findsOneWidget);
  });

  testWidgets('editing the height previews and saves the new targets', (tester) async {
    await pump(tester);
    await tester.tap(find.byKey(const Key('settings_row_height')));
    await tester.pumpAndSettle();

    final save = find.descendant(of: find.byKey(const Key('settings_sheet_save')), matching: find.byType(FilledButton));
    expect(tester.widget<FilledButton>(save).onPressed, isNull);
    await tester.enterText(find.byKey(const Key('numeric_step_field')), '182');
    await tester.pump();
    expect(find.byKey(const Key('settings_targets_preview')), findsOneWidget);

    await tester.tap(save);
    await tester.pumpAndSettle();

    final targets = targetsFor(testProfile.copyWith(heightCm: 182), currentYear: 2026);
    expect(repo.updates.single, {
      'height_cm': 182.0,
      'daily_calorie_target': targets.calorieTarget,
      'daily_protein_target_g': targets.proteinTargetG,
      'goals_changed_at': DateTime(2026, 10, 7, 9).toUtc().toIso8601String(),
    });
    expect(find.byKey(const Key('settings_sheet_save')), findsNothing);
  });

  testWidgets('a failed save keeps the sheet open and shows an error', (tester) async {
    repo.error = Exception('offline');
    await pump(tester);
    await tester.tap(find.byKey(const Key('settings_row_height')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('numeric_step_field')), '182');
    await tester.pump();
    await tester.tap(find.descendant(of: find.byKey(const Key('settings_sheet_save')), matching: find.byType(FilledButton)));
    await tester.pumpAndSettle();

    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.byKey(const Key('settings_sheet_save')), findsOneWidget);
    expect(repo.updates, isEmpty);
  });

  testWidgets('turning sport off writes no sport and zero days', (tester) async {
    await pump(tester);
    await tester.tap(find.byKey(const Key('settings_row_sport')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('choice_option_false')));
    await tester.pump();
    await tester.tap(find.descendant(of: find.byKey(const Key('settings_sheet_save')), matching: find.byType(FilledButton)));
    await tester.pumpAndSettle();

    expect(repo.updates.single, {'does_exercise': false, 'exercise_days_per_week': 0});
  });

  testWidgets('sign out asks for confirmation first', (tester) async {
    await pump(tester);
    await tester.tap(find.byKey(const Key('settings_sign_out')));
    await tester.pumpAndSettle();
    expect(auth.signedOut, isFalse);

    await tester.tap(find.byKey(const Key('settings_sign_out_confirm')));
    await tester.pumpAndSettle();
    expect(auth.signedOut, isTrue);
  });

  // Dil seçimi kalıcı saklandığı için en sonda.
  testWidgets('the language selector switches to English', (tester) async {
    await pump(tester);
    await tester.tap(find.byKey(const Key('settings_language_en')));
    await tester.pumpAndSettle();

    final selector = tester.widget<SegmentedButton<String>>(find.byKey(const Key('settings_language')));
    expect(selector.selected, {'en'});
  });
}
