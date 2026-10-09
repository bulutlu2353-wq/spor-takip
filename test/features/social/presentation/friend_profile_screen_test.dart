import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spor_takip/features/onboarding/application/profile_providers.dart';
import 'package:spor_takip/features/social/application/social_providers.dart';
import 'package:spor_takip/features/social/presentation/friend_profile_screen.dart';
import 'package:spor_takip/features/workout/application/session_providers.dart';

import '../../progress/fixtures.dart';
import '../../progress/presentation/test_app.dart';
import '../fakes.dart';
import '../social_fixtures.dart';

void main() {
  setUpAll(initTestLocalization);

  Future<FakeSocialRepository> pump(WidgetTester tester, {bool withSections = true, bool withStats = true}) async {
    final repo = FakeSocialRepository(
      me: socialMe,
      others: [socialAyse],
      friendships: [socialFriendship('me', 'ayse')],
      stats: {if (withStats) 'ayse': socialStats(withSections: withSections)},
    );
    tester.view.physicalSize = const Size(800, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(testApp(
      const FriendProfileScreen(friendId: 'ayse'),
      scaffold: false,
      overrides: [
        socialRepositoryProvider.overrideWithValue(repo),
        profileProvider.overrideWith((ref) async => testProfile),
        nowProvider.overrideWithValue(() => DateTime(2026, 10, 9, 12)),
      ],
    ));
    await tester.pumpAndSettle();
    return repo;
  }

  test('ago labels step from minutes to hours to days', () {
    final now = DateTime(2026, 10, 9, 12);
    expect(agoLabel(now.subtract(const Duration(seconds: 30)), now), 'social.ago_now');
    expect(agoLabel(now.subtract(const Duration(minutes: 5)), now), 'social.ago_minutes');
    expect(agoLabel(now.subtract(const Duration(hours: 3)), now), 'social.ago_hours');
    expect(agoLabel(now.subtract(const Duration(days: 2)), now), 'social.ago_days');
  });

  testWidgets('shows the header, titles, week, heat and recent workouts', (tester) async {
    await pump(tester);
    expect(find.byKey(const Key('friend_profile_screen')), findsOneWidget);
    expect(find.text('@ayse_k'), findsOneWidget);
    for (final key in ['friend_header', 'friend_active_title', 'friend_updated', 'friend_titles', 'friend_weekly',
        'friend_heat', 'friend_recent', 'friend_recent_0', 'friend_recent_1']) {
      expect(find.byKey(Key(key)), findsOneWidget, reason: key);
    }
    expect(find.text('62'), findsOneWidget);
    expect(find.descendant(of: find.byKey(const Key('friend_recent_0')), matching: find.text('social.record_line')),
        findsOneWidget);
    expect(find.byKey(const Key('friend_hidden_weekly')), findsNothing);
  });

  testWidgets('hidden sections say they are not shared', (tester) async {
    await pump(tester, withSections: false);
    expect(find.byKey(const Key('friend_hidden_weekly')), findsOneWidget);
    expect(find.byKey(const Key('friend_hidden_heat')), findsOneWidget);
    expect(find.byKey(const Key('friend_hidden_recent')), findsOneWidget);
    expect(find.byKey(const Key('friend_weekly')), findsNothing);
  });

  testWidgets('a friend without stats shows only the name', (tester) async {
    await pump(tester, withStats: false);
    expect(find.byKey(const Key('friend_no_stats')), findsOneWidget);
    expect(find.byKey(const Key('friend_titles')), findsNothing);
  });

  testWidgets('removing asks for confirmation and calls the repository', (tester) async {
    final repo = await pump(tester);
    await tester.tap(find.byKey(const Key('friend_menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('friend_remove')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('friend_remove_confirm')), findsOneWidget);
    await tester.tap(find.byKey(const Key('friend_remove_confirm')));
    await tester.pumpAndSettle();
    expect(repo.removed, ['ayse']);
    expect(find.byKey(const Key('friend_not_found')), findsOneWidget);
  });
}
