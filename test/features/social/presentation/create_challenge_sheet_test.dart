import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spor_takip/features/social/application/social_providers.dart';
import 'package:spor_takip/features/social/domain/challenge.dart';
import 'package:spor_takip/features/social/presentation/create_challenge_sheet.dart';
import 'package:spor_takip/features/workout/application/session_providers.dart';

import '../../progress/presentation/test_app.dart';
import '../fakes.dart';
import '../social_fixtures.dart';

void main() {
  setUpAll(initTestLocalization);
  setUp(() => SharedPreferences.setMockInitialValues({}));

  FakeSocialRepository repo() => FakeSocialRepository(
        me: socialMe,
        others: [socialAyse, socialBurak],
        friendships: [socialFriendship('me', 'ayse'), socialFriendship('burak', 'me')],
      );

  Future<void> pump(WidgetTester tester, FakeSocialRepository repo, {String? communityId, String? friendId}) async {
    tester.view.physicalSize = const Size(360, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(testApp(
      CreateChallengeSheet(communityId: communityId, friendId: friendId),
      scaffold: true,
      overrides: [
        socialRepositoryProvider.overrideWithValue(repo),
        nowProvider.overrideWithValue(() => DateTime(2026, 10, 9, 12)),
      ],
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('a friend race sends the chosen metric, muscle, window and invitees', (tester) async {
    final fake = repo();
    await pump(tester, fake, friendId: 'ayse');
    expect(find.byKey(const Key('challenge_muscle')), findsNothing);
    expect(find.byKey(const Key('challenge_target')), findsNothing);

    await tester.tap(find.byKey(const Key('challenge_metric_sets')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('challenge_muscle')), findsOneWidget);
    await tester.tap(find.byKey(const Key('challenge_muscle')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('gamification.muscle_short.lats').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('challenge_days_3')));
    await tester.tap(find.byKey(const Key('challenge_start_tomorrow')));
    await tester.tap(find.byKey(const Key('challenge_invite_burak')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('challenge_form_save')));
    await tester.tap(find.byKey(const Key('challenge_form_save')));
    await tester.pumpAndSettle();

    final draft = fake.createdChallenges.single;
    expect((draft.kind, draft.metric, draft.muscle, draft.target), (ChallengeKind.race, ChallengeMetric.sets, 'lats', null));
    expect((draft.startsAt, draft.endsAt), (DateTime(2026, 10, 10), DateTime(2026, 10, 13)));
    expect(draft.invitees, ['ayse', 'burak']);
    expect(draft.communityId, isNull);
    expect(draft.name, 'challenge.auto_muscle');
  });

  testWidgets('a goal needs a target; the save button waits for it', (tester) async {
    final fake = repo();
    await pump(tester, fake, friendId: 'ayse');
    await tester.tap(find.byKey(const Key('challenge_kind_goal')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('challenge_form_save')));
    expect(tester.widget<FilledButton>(find.byKey(const Key('challenge_form_save'))).onPressed, isNull);

    await tester.enterText(find.byKey(const Key('challenge_target')), '4');
    await tester.enterText(find.byKey(const Key('challenge_name')), 'Bu hafta 4 antrenman');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('challenge_form_save')));
    await tester.pumpAndSettle();
    final draft = fake.createdChallenges.single;
    expect((draft.kind, draft.metric, draft.target, draft.name),
        (ChallengeKind.goal, ChallengeMetric.workouts, 4.0, 'Bu hafta 4 antrenman'));
    expect((draft.startsAt, draft.endsAt), (DateTime(2026, 10, 9, 12), DateTime(2026, 10, 16, 12)));
  });

  testWidgets('in community mode there is no invite list and the community id is sent', (tester) async {
    final fake = repo();
    await pump(tester, fake, communityId: 'c1');
    expect(find.byKey(const Key('challenge_invite_ayse')), findsNothing);
    await tester.ensureVisible(find.byKey(const Key('challenge_form_save')));
    await tester.tap(find.byKey(const Key('challenge_form_save')));
    await tester.pumpAndSettle();
    expect(fake.createdChallenges.single.communityId, 'c1');
    expect(fake.createdChallenges.single.invitees, isEmpty);
  });

  testWidgets('a friend challenge needs an invitee; a server error shows inside the sheet', (tester) async {
    final fake = repo()..challengeError = const ChallengeException('challenge_limit');
    await pump(tester, fake);
    await tester.ensureVisible(find.byKey(const Key('challenge_form_save')));
    expect(tester.widget<FilledButton>(find.byKey(const Key('challenge_form_save'))).onPressed, isNull);

    await tester.tap(find.byKey(const Key('challenge_invite_ayse')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('challenge_form_save')));
    await tester.tap(find.byKey(const Key('challenge_form_save')));
    await tester.pumpAndSettle();
    expect(find.text('challenge.error.challenge_limit'), findsOneWidget);
  });
}
