import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spor_takip/features/progress/application/progress_providers.dart';
import 'package:spor_takip/features/social/application/social_providers.dart';
import 'package:spor_takip/features/social/domain/challenge.dart';
import 'package:spor_takip/features/social/presentation/challenge_screen.dart';
import 'package:spor_takip/features/workout/application/muscle_heat_providers.dart';
import 'package:spor_takip/features/workout/application/session_providers.dart';

import '../../gamification/game_fixtures.dart';
import '../../progress/presentation/test_app.dart';
import '../fakes.dart';
import '../social_fixtures.dart';

final _sessions = [gameSession('a', DateTime(2026, 10, 8, 18), gameSets('bench', 3))];

void main() {
  setUpAll(initTestLocalization);
  setUp(() => SharedPreferences.setMockInitialValues({}));

  FakeSocialRepository repoWith(Challenge challenge, List<ChallengeParticipant> people) => FakeSocialRepository(
        me: socialMe,
        others: [socialAyse, socialBurak, socialCan],
        communities: [socialCommunity],
        challenges: [challenge],
        participants: {challenge.id: people},
      );

  Future<void> pump(WidgetTester tester, FakeSocialRepository repo, String id) async {
    tester.view.physicalSize = const Size(360, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(testApp(
      ChallengeScreen(challengeId: id),
      scaffold: false,
      overrides: [
        socialRepositoryProvider.overrideWithValue(repo),
        nowProvider.overrideWithValue(() => DateTime(2026, 10, 9, 12)),
        allSessionsProvider.overrideWith((ref) async => _sessions),
        mealTimesProvider.overrideWith((ref) async => const []),
        exercisesByIdProvider.overrideWith((ref) async => gameExercisesById),
      ],
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('an active race shows the header, live standings with me highlighted and pending invites',
      (tester) async {
    await pump(
      tester,
      repoWith(socialChallenge(), [
        socialParticipant('ch1', 'ayse', progress: 14),
        socialParticipant('ch1', 'me'),
        socialParticipant('ch1', 'burak', progress: 1),
        socialParticipant('ch1', 'can', status: ChallengeStatus.invited),
      ]),
      'ch1',
    );
    expect(find.byKey(const Key('challenge_header')), findsOneWidget);
    expect(find.byKey(const Key('challenge_time')), findsOneWidget);
    expect(find.byKey(const Key('challenge_result')), findsNothing);
    expect(
      tester.getTopLeft(find.byKey(const Key('challenge_standing_ayse'))).dy,
      lessThan(tester.getTopLeft(find.byKey(const Key('challenge_standing_me'))).dy),
    );
    expect(
      tester.getTopLeft(find.byKey(const Key('challenge_standing_me'))).dy,
      lessThan(tester.getTopLeft(find.byKey(const Key('challenge_standing_burak'))).dy),
    );
    expect(find.byKey(const Key('challenge_pending')), findsOneWidget);
    expect(find.byKey(const Key('challenge_reward')), findsOneWidget);
  });

  testWidgets('a finished race shows my result and the winner trophy', (tester) async {
    await pump(
      tester,
      repoWith(socialChallenge(id: 'old', startsAt: DateTime(2026, 9, 20), endsAt: DateTime(2026, 9, 27)), [
        socialParticipant('old', 'ayse', progress: 10),
        socialParticipant('old', 'me', progress: 20),
      ]),
      'old',
    );
    expect(tester.widget<Text>(find.byKey(const Key('challenge_result'))).data, 'challenge.result_won');
    expect(find.descendant(of: find.byKey(const Key('challenge_standing_me')), matching: find.byIcon(Icons.emoji_events)),
        findsOneWidget);
  });

  testWidgets('an invite can be accepted from the page', (tester) async {
    final repo = repoWith(socialChallenge(), [
      socialParticipant('ch1', 'ayse', progress: 14),
      socialParticipant('ch1', 'me', status: ChallengeStatus.invited),
    ]);
    await pump(tester, repo, 'ch1');
    await tester.tap(find.byKey(const Key('challenge_screen_accept')));
    await tester.pumpAndSettle();
    expect(repo.challengeResponses, [('ch1', true)]);
    expect(find.byKey(const Key('challenge_standing_me')), findsOneWidget);
  });

  testWidgets('a community member who has not joined sees Join; the owner can delete', (tester) async {
    final repo = repoWith(socialChallenge(id: 'cm', communityId: 'c1'), [socialParticipant('cm', 'ayse', progress: 5)]);
    await pump(tester, repo, 'cm');
    await tester.tap(find.byKey(const Key('challenge_join')));
    await tester.pumpAndSettle();
    expect(repo.joinedChallenges, ['cm']);

    await tester.tap(find.byKey(const Key('challenge_menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('challenge_delete')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('challenge_confirm_ok')));
    await tester.pumpAndSettle();
    expect(repo.deletedChallenges, ['cm']);
  });

  testWidgets('leaving asks for confirmation', (tester) async {
    final repo = repoWith(socialChallenge(), [socialParticipant('ch1', 'ayse'), socialParticipant('ch1', 'me')]);
    await pump(tester, repo, 'ch1');
    await tester.tap(find.byKey(const Key('challenge_menu')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('challenge_delete')), findsNothing);
    await tester.tap(find.byKey(const Key('challenge_leave')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('challenge_confirm_ok')));
    await tester.pumpAndSettle();
    expect(repo.leftChallenges, ['ch1']);
  });

  testWidgets('a missing challenge shows the gone text', (tester) async {
    await pump(tester, FakeSocialRepository(me: socialMe), 'nope');
    expect(find.byKey(const Key('challenge_gone')), findsOneWidget);
  });
}
