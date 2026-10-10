import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spor_takip/features/social/application/social_providers.dart';
import 'package:spor_takip/features/social/domain/community.dart';
import 'package:spor_takip/features/social/presentation/communities_tab.dart';
import 'package:spor_takip/features/workout/application/session_providers.dart';

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
      const Scaffold(body: CommunitiesTab()),
      scaffold: false,
      overrides: [
        socialRepositoryProvider.overrideWithValue(repo),
        nowProvider.overrideWithValue(() => DateTime(2026, 10, 9, 12)),
      ],
      stubRoutes: {
        '/social/community/c1': 'community-c1',
        '/social/community/c2': 'community-c2',
        '/social/community/c9': 'community-c9',
        '/social/community/new': 'community-new',
      },
    ));
    await tester.pumpAndSettle();
  }

  FakeSocialRepository repoWith({Map<String, List<CommunityMember>>? members}) => FakeSocialRepository(
        me: socialMe,
        others: [socialAyse],
        communities: [socialCommunity, socialCommunity2, socialCommunity3],
        members: members ??
            {
              'c1': [socialMember('c1', 'me', owner: true), socialMember('c1', 'ayse', day: 2)],
              'c3': [socialMember('c3', 'me', owner: true)],
            },
        periodStats: {'ayse': socialPeriod(week: 900)},
      );

  testWidgets('lists my communities with my position and opens one', (tester) async {
    await pump(tester, repoWith());
    expect(find.byKey(const Key('community_c1')), findsOneWidget);
    expect(find.byKey(const Key('community_c3')), findsOneWidget);
    expect(find.byKey(const Key('community_c2')), findsNothing);
    // c1'de Ayşe'nin XP'si var, benim yok → sıram yok.
    expect(tester.widget<Text>(find.byKey(const Key('community_position_c1'))).data, '—');
    expect(find.byKey(const Key('community_limit_note')), findsNothing);

    await tester.tap(find.byKey(const Key('community_c1')));
    await tester.pumpAndSettle();
    expect(find.text('community-c1'), findsOneWidget);
  });

  testWidgets('no communities shows the empty text', (tester) async {
    await pump(tester, repoWith(members: const {}));
    expect(find.byKey(const Key('communities_empty')), findsOneWidget);
  });

  testWidgets('with five communities both buttons are disabled', (tester) async {
    final ids = ['c1', 'c2', 'c3', 'c4', 'c5'];
    await pump(
      tester,
      FakeSocialRepository(
        me: socialMe,
        communities: [
          for (final id in ids)
            Community(id: id, name: 'Topluluk $id', description: '', isPublic: true, inviteCode: 'KOD$id', owner: id),
        ],
        members: {
          for (final id in ids) id: [socialMember(id, 'me')],
        },
      ),
    );
    expect(find.byKey(const Key('community_limit_note')), findsOneWidget);
    expect(tester.widget<ButtonStyleButton>(find.byKey(const Key('community_create'))).onPressed, isNull);
    expect(tester.widget<ButtonStyleButton>(find.byKey(const Key('community_join'))).onPressed, isNull);
  });

  testWidgets('creating a community validates the name and opens it', (tester) async {
    final repo = repoWith();
    await pump(tester, repo);
    await tester.tap(find.byKey(const Key('community_create')));
    await tester.pumpAndSettle();

    final save = find.byKey(const Key('community_form_save'));
    await tester.enterText(find.byKey(const Key('community_name_field')), 'De');
    await tester.pump();
    expect(find.text('social.community_name_short'), findsOneWidget);
    expect(tester.widget<FilledButton>(save).onPressed, isNull);

    await tester.enterText(find.byKey(const Key('community_name_field')), '  Demir Kulübü 2 ');
    await tester.enterText(find.byKey(const Key('community_description_field')), 'Akşam ekibi');
    await tester.tap(find.byKey(const Key('community_public_switch')));
    await tester.pump();
    await tester.tap(save);
    await tester.pumpAndSettle();

    final created = repo.communities['new']!;
    expect((created.name, created.description, created.isPublic), ('Demir Kulübü 2', 'Akşam ekibi', false));
    expect(find.text('community-new'), findsOneWidget);
  });

  testWidgets('a creation error is shown inside the sheet', (tester) async {
    final repo = repoWith()..communityError = const CommunityException('community_limit');
    await pump(tester, repo);
    await tester.tap(find.byKey(const Key('community_create')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('community_name_field')), 'Demir');
    await tester.pump();
    await tester.tap(find.byKey(const Key('community_form_save')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('community_form_error')), findsOneWidget);
    expect(find.text('social.community_error.community_limit'), findsOneWidget);
  });

  testWidgets('joining by search opens the community', (tester) async {
    final repo = repoWith()
      ..searchResults = const [
        CommunitySearchResult(id: 'c9', name: 'Sabah Ekibi', description: 'Erkenciler', memberCount: 12, isMember: false),
        CommunitySearchResult(id: 'c1', name: 'Demir Kulübü', description: '', memberCount: 2, isMember: true),
      ];
    await pump(tester, repo);
    await tester.tap(find.byKey(const Key('community_join')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('join_privacy_note')), findsOneWidget);

    final submit = find.byKey(const Key('join_search_submit'));
    await tester.enterText(find.byKey(const Key('join_search_field')), 's');
    await tester.pump();
    expect(tester.widget<FilledButton>(submit).onPressed, isNull);
    await tester.enterText(find.byKey(const Key('join_search_field')), 'sab');
    await tester.pump();
    await tester.tap(submit);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('join_result_c9')), findsOneWidget);
    expect(find.byKey(const Key('join_result_join_c1')), findsNothing);
    expect(find.text('social.join_member'), findsOneWidget);

    await tester.tap(find.byKey(const Key('join_result_join_c9')));
    await tester.pumpAndSettle();
    expect(repo.joined, ['c9']);
    expect(find.text('community-c9'), findsOneWidget);
  });

  testWidgets('joining by code: errors stay in the sheet, a valid code opens the community', (tester) async {
    final repo = repoWith()..communityError = const CommunityException('banned');
    await pump(tester, repo);
    await tester.tap(find.byKey(const Key('community_join')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('join_mode_code')));
    await tester.pumpAndSettle();

    final submit = find.byKey(const Key('join_code_submit'));
    await tester.enterText(find.byKey(const Key('join_code_field')), 'aysetkm');
    await tester.pump();
    expect(tester.widget<FilledButton>(submit).onPressed, isNull);
    await tester.enterText(find.byKey(const Key('join_code_field')), 'aysetkm2');
    await tester.pump();
    await tester.tap(submit);
    await tester.pumpAndSettle();
    expect(find.text('social.community_error.banned'), findsOneWidget);

    repo.communityError = null;
    await tester.tap(submit);
    await tester.pumpAndSettle();
    expect(repo.joined, ['c2']);
    expect(find.text('community-c2'), findsOneWidget);
  });
}
