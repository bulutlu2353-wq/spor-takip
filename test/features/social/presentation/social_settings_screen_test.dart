import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spor_takip/features/social/application/social_providers.dart';
import 'package:spor_takip/features/social/presentation/social_settings_screen.dart';

import '../../progress/presentation/test_app.dart';
import '../fakes.dart';
import '../social_fixtures.dart';

void main() {
  setUpAll(initTestLocalization);

  Future<FakeSocialRepository> pump(WidgetTester tester, {Set<String> taken = const {}}) async {
    final repo = FakeSocialRepository(me: socialMe, taken: taken);
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(testApp(
      const SocialSettingsScreen(),
      scaffold: false,
      overrides: [socialRepositoryProvider.overrideWithValue(repo)],
    ));
    await tester.pumpAndSettle();
    return repo;
  }

  testWidgets('starts with my names and lets me change the display name', (tester) async {
    final repo = await pump(tester);
    expect(find.text('samet_fit'), findsOneWidget);
    expect(find.text('Samet'), findsOneWidget);
    expect(find.text('social.username_available'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('settings_display_name')), 'Samet A.');
    await tester.pump();
    await tester.tap(find.byKey(const Key('settings_save')));
    await tester.pumpAndSettle();
    expect(repo.me?.displayName, 'Samet A.');
    expect(repo.me?.username, 'samet_fit');
    expect(find.text('social.saved'), findsOneWidget);
  });

  testWidgets('a taken username is rejected', (tester) async {
    final repo = await pump(tester, taken: {'ayse_k'});
    await tester.enterText(find.byKey(const Key('settings_username')), 'ayse_k');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    expect(find.text('social.username_taken'), findsOneWidget);
    expect(tester.widget<FilledButton>(find.byKey(const Key('settings_save'))).onPressed, isNull);
    expect(repo.me?.username, 'samet_fit');
  });

  testWidgets('privacy switches save right away', (tester) async {
    final repo = await pump(tester);
    await tester.tap(find.byKey(const Key('share_weekly')));
    await tester.pumpAndSettle();
    expect(repo.me?.shareWeekly, isFalse);
    await tester.tap(find.byKey(const Key('share_heat')));
    await tester.pumpAndSettle();
    expect(repo.me?.shareHeat, isFalse);
    expect(repo.me?.shareWorkouts, isTrue);
    expect(tester.widget<SwitchListTile>(find.byKey(const Key('share_weekly'))).value, isFalse);
  });

  testWidgets('the compete switch saves right away', (tester) async {
    final repo = await pump(tester);
    final competeSwitch = find.byKey(const Key('compete_globally'));
    await tester.ensureVisible(competeSwitch);
    expect(tester.widget<SwitchListTile>(competeSwitch).value, isTrue);
    await tester.tap(competeSwitch);
    await tester.pumpAndSettle();
    expect(repo.me?.competeGlobally, isFalse);
    expect(tester.widget<SwitchListTile>(competeSwitch).value, isFalse);
  });
}
