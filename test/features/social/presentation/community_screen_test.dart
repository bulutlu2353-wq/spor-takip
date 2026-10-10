import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spor_takip/features/social/application/social_providers.dart';
import 'package:spor_takip/features/social/domain/community.dart';
import 'package:spor_takip/features/social/presentation/community_screen.dart';
import 'package:spor_takip/features/workout/application/session_providers.dart';

import '../../progress/presentation/test_app.dart';
import '../fakes.dart';
import '../social_fixtures.dart';

void main() {
  setUpAll(initTestLocalization);
  setUp(() => SharedPreferences.setMockInitialValues({}));

  FakeSocialRepository repoWith({Community community = socialCommunity, bool meIsMember = true}) =>
      FakeSocialRepository(
        me: socialMe,
        others: [socialAyse, socialBurak],
        communities: [community],
        members: {
          'c1': [
            if (meIsMember) socialMember('c1', 'me', owner: community.owner == 'me'),
            socialMember('c1', 'ayse', owner: community.owner == 'ayse', day: 2),
            socialMember('c1', 'burak', day: 3),
          ],
        },
        periodStats: {
          'me': socialPeriod(week: 640, weekMuscles: {'lats': 10}, prevWeek: 300),
          'ayse': socialPeriod(
            week: 1420,
            weekMuscles: {'lats': 14.5, 'chest': 9},
            prevWeek: 900,
            prevWeekMuscles: {'lats': 22},
          ),
          'burak': socialPeriod(),
        },
      );

  Future<void> pump(WidgetTester tester, FakeSocialRepository repo) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(testApp(
      const CommunityScreen(communityId: 'c1'),
      scaffold: false,
      overrides: [
        socialRepositoryProvider.overrideWithValue(repo),
        nowProvider.overrideWithValue(() => DateTime(2026, 10, 9, 12)),
      ],
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('shows the header, last week champions and live standings with me highlighted', (tester) async {
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') copied = (call.arguments as Map)['text'] as String;
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
    await pump(tester, repoWith());

    expect(find.byKey(const Key('community_header')), findsOneWidget);
    expect(tester.widget<Text>(find.byKey(const Key('community_code'))).data, 'Q7M2K9TA');

    final titles = find.byKey(const Key('community_titles'));
    expect(find.descendant(of: titles, matching: find.byKey(const Key('title_xp'))), findsOneWidget);
    expect(find.descendant(of: titles, matching: find.byKey(const Key('title_lats'))), findsOneWidget);
    expect(find.descendant(of: titles, matching: find.text('Ayşe Kaya')), findsNWidgets(2));

    expect(find.byKey(const Key('period_remaining')), findsOneWidget);
    expect(find.byKey(const Key('standing_ayse')), findsOneWidget);
    expect(find.byKey(const Key('standing_me')), findsOneWidget);
    expect(find.byKey(const Key('standing_burak')), findsNothing);
    expect(find.byKey(const Key('standing_me_label')), findsOneWidget);
    expect(
      tester.getTopLeft(find.byKey(const Key('standing_ayse'))).dy,
      lessThan(tester.getTopLeft(find.byKey(const Key('standing_me'))).dy),
    );

    await tester.tap(find.byKey(const Key('community_copy_code')));
    await tester.pumpAndSettle();
    expect(copied, 'Q7M2K9TA');
  });

  testWidgets('the month view shows empty texts; muscle leaders list this period without XP', (tester) async {
    await pump(tester, repoWith());
    final leaders = find.byKey(const Key('community_muscle_leaders'));
    await tester.ensureVisible(leaders);
    await tester.tap(leaders);
    await tester.pumpAndSettle();
    expect(find.descendant(of: leaders, matching: find.byKey(const Key('title_chest'))), findsOneWidget);
    expect(find.descendant(of: leaders, matching: find.byKey(const Key('title_lats'))), findsOneWidget);
    expect(find.descendant(of: leaders, matching: find.byKey(const Key('title_xp'))), findsNothing);

    await tester.ensureVisible(find.byKey(const Key('period_month')));
    await tester.tap(find.byKey(const Key('period_month')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('community_titles_empty')), findsOneWidget);
    expect(find.byKey(const Key('community_standings_empty')), findsOneWidget);
  });

  testWidgets('the owner menu regenerates the code and manages members', (tester) async {
    final repo = repoWith();
    await pump(tester, repo);

    await tester.tap(find.byKey(const Key('community_menu')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('community_edit')), findsOneWidget);
    expect(find.byKey(const Key('community_manage')), findsOneWidget);
    expect(find.byKey(const Key('community_leave')), findsOneWidget);
    await tester.tap(find.byKey(const Key('community_regenerate')));
    await tester.pumpAndSettle();
    expect(find.text('social.community_regenerated'), findsOneWidget);
    expect(tester.widget<Text>(find.byKey(const Key('community_code'))).data, 'R3GENKQ2');

    await tester.tap(find.byKey(const Key('community_menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('community_manage')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('manage_ayse')), findsOneWidget);
    expect(find.byKey(const Key('manage_ban_me')), findsNothing);
    await tester.tap(find.byKey(const Key('manage_ban_ayse')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('manage_confirm')));
    await tester.pumpAndSettle();
    expect(repo.memberRemovals, [('c1', 'ayse', true)]);
    expect(find.byKey(const Key('manage_ayse')), findsNothing);
  });

  testWidgets('a member only sees leave; leaving asks first', (tester) async {
    const owned = Community(
      id: 'c1',
      name: 'Demir Kulübü',
      description: '',
      isPublic: false,
      inviteCode: 'Q7M2K9TA',
      owner: 'ayse',
    );
    final repo = repoWith(community: owned);
    await pump(tester, repo);

    await tester.tap(find.byKey(const Key('community_menu')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('community_edit')), findsNothing);
    expect(find.byKey(const Key('community_manage')), findsNothing);
    await tester.tap(find.byKey(const Key('community_leave')));
    await tester.pumpAndSettle();
    expect(find.text('social.community_leave_body'), findsOneWidget);
    await tester.tap(find.byKey(const Key('community_leave_confirm')));
    await tester.pumpAndSettle();
    expect(repo.left, ['c1']);
    expect(find.byKey(const Key('community_not_member')), findsOneWidget);
  });

  testWidgets('not a member shows the not-member text', (tester) async {
    await pump(tester, repoWith(meIsMember: false));
    expect(find.byKey(const Key('community_not_member')), findsOneWidget);
    expect(find.byKey(const Key('community_menu')), findsNothing);
  });
}
