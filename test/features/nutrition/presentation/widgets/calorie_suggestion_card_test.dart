import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spor_takip/features/nutrition/domain/adaptive_tdee.dart';
import 'package:spor_takip/features/nutrition/presentation/widgets/calorie_suggestion_card.dart';
import 'package:spor_takip/features/onboarding/application/auth_providers.dart';
import 'package:spor_takip/features/onboarding/application/profile_providers.dart';
import 'package:spor_takip/features/workout/application/session_providers.dart';

import '../../../progress/presentation/test_app.dart';
import '../../../settings/fakes.dart';

void main() {
  setUpAll(initTestLocalization);

  final now = DateTime(2026, 10, 22, 10);
  const suggestion = CalorieSuggestion(
    method: SuggestionMethod.weightTrend,
    windowDays: 21,
    currentTarget: 2099.4,
    newTarget: 1849.4,
    newProteinTargetG: 176,
    newAdjustmentKcal: -250,
    observedWeeklyKg: -0.21,
    expectedWeeklyKg: -0.6,
  );
  late FakeProfileRepository repo;

  setUp(() => repo = FakeProfileRepository());

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(testApp(
      const CalorieSuggestionCard(suggestion: suggestion),
      overrides: [
        profileRepositoryProvider.overrideWithValue(repo),
        authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
        nowProvider.overrideWithValue(() => now),
      ],
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('shows the change, the targets and the method', (tester) async {
    await pump(tester);
    expect(find.byKey(const Key('calorie_suggestion_card')), findsOneWidget);
    expect(find.text('2099 → 1849 kcal'), findsOneWidget);
    expect(tester.widget<Text>(find.byKey(const Key('suggestion_method'))).data, 'nutrition.suggestion_method_trend');
    final body = tester.widget<Text>(find.byKey(const Key('suggestion_body'))).data!;
    expect(body, startsWith('nutrition.suggestion_lost'));
    expect(body, contains('nutrition.suggestion_goal_lose'));
  });

  testWidgets('apply writes the adjustment and the new targets', (tester) async {
    await pump(tester);
    await tester.tap(find.byKey(const Key('suggestion_apply_button')));
    await tester.pumpAndSettle();
    expect(repo.updates.single, applySuggestionFields(suggestion, now));
    expect(find.text('nutrition.suggestion_applied'), findsOneWidget);
  });

  testWidgets('not now snoozes for a week', (tester) async {
    await pump(tester);
    await tester.tap(find.byKey(const Key('suggestion_snooze_button')));
    await tester.pumpAndSettle();
    expect(repo.updates.single, snoozeSuggestionFields(now));
  });

  testWidgets('a failed write keeps the card and shows an error', (tester) async {
    repo.error = Exception('offline');
    await pump(tester);
    await tester.tap(find.byKey(const Key('suggestion_apply_button')));
    await tester.pumpAndSettle();
    expect(find.text('settings.save_error'), findsOneWidget);
    expect(find.byKey(const Key('calorie_suggestion_card')), findsOneWidget);
  });
}
