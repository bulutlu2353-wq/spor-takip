import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spor_takip/features/gamification/application/gamification_providers.dart';
import 'package:spor_takip/features/gamification/domain/player_summary.dart';
import 'package:spor_takip/features/social/application/social_providers.dart';
import 'package:spor_takip/features/social/presentation/social_screen.dart';

import '../../progress/presentation/test_app.dart';
import '../fakes.dart';
import '../social_fixtures.dart';

void main() {
  setUpAll(initTestLocalization);
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> pump(WidgetTester tester, FakeSocialRepository repo) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(testApp(
      const SocialScreen(),
      scaffold: false,
      overrides: [
        socialRepositoryProvider.overrideWithValue(repo),
        playerSummaryProvider.overrideWith((ref) async => playerSummary(const [], const [], const {})),
      ],
      stubRoutes: {'/social/friend/ayse': 'friend-ayse', '/social/settings': 'settings-stub'},
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('without a profile it asks for a username and display name', (tester) async {
    final repo = FakeSocialRepository(taken: {'taken_name'});
    await pump(tester, repo);
    expect(find.byKey(const Key('social_create')), findsOneWidget);
    expect(find.byKey(const Key('social_settings_button')), findsNothing);
    final create = find.byKey(const Key('social_create_button'));
    expect(tester.widget<FilledButton>(create).onPressed, isNull);

    await tester.enterText(find.byKey(const Key('social_username_field')), 'ab');
    await tester.pump();
    expect(find.text('social.username_too_short'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('social_username_field')), 'taken_name');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    expect(find.text('social.username_taken'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('social_username_field')), '@Samet_Fit');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    expect(find.text('social.username_available'), findsOneWidget);
    expect(tester.widget<FilledButton>(create).onPressed, isNull); // görünen ad boş

    await tester.enterText(find.byKey(const Key('social_display_name_field')), 'Samet');
    await tester.pump();
    await tester.tap(create);
    await tester.pumpAndSettle();
    expect(repo.me?.username, 'samet_fit');
    expect(find.byKey(const Key('social_me_card')), findsOneWidget);
  });

  testWidgets('shows my card, requests and friends; copies the invite text', (tester) async {
    final repo = FakeSocialRepository(
      me: socialMe,
      others: [socialAyse, socialCan, socialDeniz],
      friendships: [
        socialFriendship('me', 'ayse'),
        socialFriendship('can', 'me', accepted: false),
        socialFriendship('me', 'deniz', accepted: false),
      ],
      stats: {'ayse': socialStats()},
    );
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') copied = (call.arguments as Map)['text'] as String;
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
    await pump(tester, repo);

    expect(find.byKey(const Key('social_me_card')), findsOneWidget);
    expect(find.text('K7Q2M9XA'), findsOneWidget);
    expect(find.byKey(const Key('request_can')), findsOneWidget);
    expect(find.byKey(const Key('request_accept_can')), findsOneWidget);
    expect(find.byKey(const Key('request_cancel_deniz')), findsOneWidget);
    expect(find.byKey(const Key('friend_ayse')), findsOneWidget);

    await tester.tap(find.byKey(const Key('social_copy_invite')));
    await tester.pumpAndSettle();
    expect(copied, 'social.invite_text');
    expect(find.text('social.copied'), findsOneWidget);
  });

  testWidgets('accepting, declining and cancelling requests call the repository', (tester) async {
    final repo = FakeSocialRepository(
      me: socialMe,
      others: [socialCan, socialBurak, socialDeniz],
      friendships: [
        socialFriendship('can', 'me', accepted: false),
        socialFriendship('burak', 'me', accepted: false),
        socialFriendship('me', 'deniz', accepted: false),
      ],
    );
    await pump(tester, repo);

    await tester.tap(find.byKey(const Key('request_accept_can')));
    await tester.pumpAndSettle();
    expect(repo.responses, [('can', true)]);
    expect(find.byKey(const Key('friend_can')), findsOneWidget);

    await tester.tap(find.byKey(const Key('request_decline_burak')));
    await tester.pumpAndSettle();
    expect(repo.responses.last, ('burak', false));
    expect(find.byKey(const Key('request_burak')), findsNothing);

    await tester.tap(find.byKey(const Key('request_cancel_deniz')));
    await tester.pumpAndSettle();
    expect(repo.removed, ['deniz']);
  });

  testWidgets('a friend row opens the friend profile; the gear opens settings', (tester) async {
    final repo = FakeSocialRepository(
      me: socialMe,
      others: [socialAyse],
      friendships: [socialFriendship('me', 'ayse')],
    );
    await pump(tester, repo);
    expect(find.byKey(const Key('social_friends_empty')), findsNothing);
    await tester.tap(find.byKey(const Key('friend_ayse')));
    await tester.pumpAndSettle();
    expect(find.text('friend-ayse'), findsOneWidget);
  });

  testWidgets('no friends shows the empty text', (tester) async {
    await pump(tester, FakeSocialRepository(me: socialMe));
    expect(find.byKey(const Key('social_friends_empty')), findsOneWidget);
    expect(find.byKey(const Key('social_requests')), findsNothing);
    await tester.tap(find.byKey(const Key('social_settings_button')));
    await tester.pumpAndSettle();
    expect(find.text('settings-stub'), findsOneWidget);
  });
}
