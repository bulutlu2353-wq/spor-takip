import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spor_takip/features/onboarding/domain/profile.dart';
import 'package:spor_takip/features/settings/presentation/widgets/goal_summary_card.dart';

import '../../progress/fixtures.dart';
import '../../progress/presentation/test_app.dart';

void main() {
  setUpAll(initTestLocalization);

  Future<void> pump(WidgetTester tester, Profile profile) async {
    await tester.pumpWidget(testApp(GoalSummaryCard(profile: profile, onTap: () {})));
    await tester.pumpAndSettle();
  }

  testWidgets('no adaptation line without an adjustment', (tester) async {
    await pump(tester, testProfile);
    expect(find.byKey(const Key('settings_goal_adjustment')), findsNothing);
  });

  testWidgets('shows the adaptation line with its date', (tester) async {
    await pump(tester, testProfile.copyWith(calorieAdjustmentKcal: -160, calorieAdjustedAt: DateTime(2026, 10, 8)));
    final line = tester.widget<Text>(find.byKey(const Key('settings_goal_adjustment'))).data;
    expect(line, 'settings.adjustment_line');
  });

  testWidgets('without a date the short line is used', (tester) async {
    await pump(tester, testProfile.copyWith(calorieAdjustmentKcal: 120));
    final line = tester.widget<Text>(find.byKey(const Key('settings_goal_adjustment'))).data;
    expect(line, 'settings.adjustment_line_short');
  });
}
