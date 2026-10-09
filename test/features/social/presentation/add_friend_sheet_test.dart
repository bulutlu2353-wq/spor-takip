import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spor_takip/features/social/application/social_providers.dart';
import 'package:spor_takip/features/social/presentation/add_friend_sheet.dart';

import '../../progress/presentation/test_app.dart';
import '../fakes.dart';
import '../social_fixtures.dart';

void main() {
  setUpAll(initTestLocalization);

  Future<void> pump(WidgetTester tester, FakeSocialRepository repo) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(testApp(
      Builder(
        builder: (context) => TextButton(onPressed: () => showAddFriendSheet(context), child: const Text('open')),
      ),
      overrides: [socialRepositoryProvider.overrideWithValue(repo)],
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  Future<void> search(WidgetTester tester, String query) async {
    await tester.enterText(find.byKey(const Key('add_query_field')), query);
    await tester.tap(find.byKey(const Key('add_search')));
    await tester.pumpAndSettle();
  }

  testWidgets('an unknown username says no one was found', (tester) async {
    await pump(tester, FakeSocialRepository(me: socialMe, others: [socialAyse]));
    await search(tester, 'nobody');
    expect(find.byKey(const Key('add_not_found')), findsOneWidget);
    expect(find.byKey(const Key('add_result')), findsNothing);
  });

  testWidgets('a username match sends a request and shows the outcome', (tester) async {
    final repo = FakeSocialRepository(me: socialMe, others: [socialAyse]);
    await pump(tester, repo);
    await search(tester, '@Ayse_K');
    expect(find.byKey(const Key('add_result')), findsOneWidget);
    expect(find.text('Ayşe Kaya'), findsOneWidget);

    await tester.tap(find.byKey(const Key('add_send')));
    await tester.pumpAndSettle();
    expect(repo.sent, ['ayse']);
    expect(find.text('social.outcome_pending'), findsOneWidget);
    expect(tester.widget<FilledButton>(find.byKey(const Key('add_send'))).onPressed, isNull);
  });

  testWidgets('an invite code finds the person; a mutual request becomes a friendship', (tester) async {
    final repo = FakeSocialRepository(me: socialMe, others: [socialBurak])..sendResult = 'accepted';
    await pump(tester, repo);
    await tester.tap(find.byKey(const Key('add_mode_invite')));
    await tester.pumpAndSettle();
    await search(tester, 'burak234');
    expect(find.text('Burak'), findsOneWidget);

    await tester.tap(find.byKey(const Key('add_send')));
    await tester.pumpAndSettle();
    expect(find.text('social.outcome_accepted'), findsOneWidget);
  });
}
