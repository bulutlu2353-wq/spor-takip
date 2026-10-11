import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spor_takip/features/progress/application/progress_providers.dart';
import 'package:spor_takip/features/social/application/social_providers.dart';
import 'package:spor_takip/features/social/domain/challenge.dart';
import 'package:spor_takip/features/social/presentation/challenges_tab.dart';
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

  FakeSocialRepository repoWith({bool friends = true}) => FakeSocialRepository(
        me: socialMe,
        others: [socialAyse, socialBurak],
        friendships: [if (friends) socialFriendship('me', 'ayse')],
        challenges: [
          socialChallenge(id: 'inv', name: 'Davet'),
          socialChallenge(id: 'ch1'),
          socialChallenge(id: 'goal', kind: ChallengeKind.goal, metric: ChallengeMetric.workouts, target: 4),
          socialChallenge(id: 'up', startsAt: DateTime(2026, 10, 10), endsAt: DateTime(2026, 10, 13)),
          socialChallenge(id: 'old', startsAt: DateTime(2026, 9, 20), endsAt: DateTime(2026, 9, 27)),
        ],
        participants: {
          'inv': [socialParticipant('inv', 'ayse'), socialParticipant('inv', 'me', status: ChallengeStatus.invited)],
          'ch1': [socialParticipant('ch1', 'ayse', progress: 14), socialParticipant('ch1', 'me')],
          'goal': [socialParticipant('goal', 'me')],
          'up': [socialParticipant('up', 'me')],
          'old': [socialParticipant('old', 'ayse', progress: 10), socialParticipant('old', 'me', progress: 20)],
        },
      );

  Future<void> pump(WidgetTester tester, FakeSocialRepository repo) async {
    tester.view.physicalSize = const Size(360, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(testApp(
      const Scaffold(body: ChallengesTab()),
      scaffold: false,
      stubRoutes: const {'/social/challenge/:id': 'CHALLENGE_PAGE'},
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

  testWidgets('shows invites, active race and goal cards, upcoming and finished rows', (tester) async {
    await pump(tester, repoWith());
    expect(find.byKey(const Key('challenge_invite_card_inv')), findsOneWidget);
    expect(tester.widget<Text>(find.byKey(const Key('challenge_position_ch1'))).data, '2.');
    expect(find.byKey(const Key('challenge_leader_ch1')), findsOneWidget);
    expect(tester.widget<Text>(find.byKey(const Key('challenge_goal_goal'))).data, 'challenge.goal_progress');
    expect(find.byKey(const Key('challenge_item_up')), findsOneWidget);
    expect(find.descendant(of: find.byKey(const Key('challenge_item_old')), matching: find.text('challenge.result_won')),
        findsOneWidget);
    expect(find.byKey(const Key('challenge_new')), findsOneWidget);
  });

  testWidgets('accepting an invite moves it to active', (tester) async {
    final repo = repoWith();
    await pump(tester, repo);
    await tester.tap(find.byKey(const Key('challenge_accept_inv')));
    await tester.pumpAndSettle();
    expect(repo.challengeResponses, [('inv', true)]);
    expect(find.byKey(const Key('challenge_invite_card_inv')), findsNothing);
    expect(find.byKey(const Key('challenge_active_inv')), findsOneWidget);
  });

  testWidgets('without friends the button is replaced by a hint', (tester) async {
    await pump(tester, repoWith(friends: false));
    expect(find.byKey(const Key('challenge_new')), findsNothing);
    expect(find.byKey(const Key('challenges_need_friends')), findsOneWidget);
  });

  testWidgets('empty state', (tester) async {
    await pump(tester, FakeSocialRepository(me: socialMe, friendships: [socialFriendship('me', 'ayse')], others: [socialAyse]));
    expect(find.byKey(const Key('challenges_active_empty')), findsOneWidget);
  });
}
