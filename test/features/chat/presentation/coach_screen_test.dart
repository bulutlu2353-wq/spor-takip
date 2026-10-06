import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spor_takip/core/theme/app_colors.dart';
import 'package:spor_takip/features/chat/application/chat_providers.dart';
import 'package:spor_takip/features/chat/data/chat_repository.dart';
import 'package:spor_takip/features/chat/domain/chat_models.dart';
import 'package:spor_takip/features/chat/presentation/coach_screen.dart';
import 'package:spor_takip/features/onboarding/application/profile_providers.dart';
import 'package:spor_takip/features/progress/application/progress_providers.dart';
import 'package:spor_takip/features/progress/domain/body_weight_log.dart';
import 'package:spor_takip/features/workout/application/session_providers.dart';

import '../../progress/fixtures.dart';
import '../../progress/presentation/test_app.dart';
import '../fakes.dart';
import '../fixtures.dart';

void main() {
  setUpAll(initTestLocalization);

  Future<FakeChatRepository> pumpScreen(WidgetTester tester, {List<ChatMessage>? messages, int? remaining = 30, Object? loadError, bool enabled = true}) async {
    final repo = FakeChatRepository(messages: messages, remaining: remaining)..loadError = loadError;
    await tester.pumpWidget(testApp(
      const CoachScreen(),
      scaffold: false,
      overrides: [
        coachEnabledProvider.overrideWithValue(enabled),
        chatRepositoryProvider.overrideWithValue(repo),
        profileProvider.overrideWith((ref) async => testProfile),
        weightLogsProvider.overrideWith((ref) async => const <BodyWeightLog>[]),
        nowProvider.overrideWithValue(() => DateTime.utc(2026, 10, 1, 9)),
      ],
    ));
    await tester.pumpAndSettle();
    return repo;
  }

  Future<void> typeAndSend(WidgetTester tester, String text) async {
    await tester.enterText(find.byKey(const Key('coach_input')), text);
    await tester.tap(find.byKey(const Key('coach_send')));
  }

  testWidgets('disabled coach shows the in-development screen and never loads the chat', (tester) async {
    final repo = await pumpScreen(tester, enabled: false);

    expect(find.byKey(const Key('coach_locked')), findsOneWidget);
    expect(find.byKey(const Key('coach_input')), findsNothing);
    expect(find.byKey(const Key('coach_suggestion_0')), findsNothing);
    expect(repo.loadCount, 0);
    expect(find.byKey(const Key('coach_locked_badge')), findsOneWidget);
    expect(find.byKey(const Key('coach_locked_title')), findsOneWidget);
    for (var i = 0; i < 6; i++) {
      expect(find.byKey(Key('coach_feature_$i')), findsOneWidget);
    }
  });

  testWidgets('empty chat shows suggestions; tapping one sends it', (tester) async {
    final repo = await pumpScreen(tester);

    expect(find.byKey(const Key('coach_suggestion_0')), findsOneWidget);
    await tester.tap(find.byKey(const Key('coach_suggestion_0')));
    await tester.pumpAndSettle();

    expect(repo.sent.single.message, isNotEmpty);
    expect(find.byKey(const Key('bubble_u1')), findsOneWidget);
    expect(find.byKey(const Key('bubble_a1')), findsOneWidget);
    expect(find.byKey(const Key('coach_suggestion_0')), findsNothing);
  });

  testWidgets('history shows bubbles and the proposal card', (tester) async {
    await pumpScreen(tester, messages: [userMessage('kilom 82'), assistantMessage(weightEvent())]);

    expect(find.text('kilom 82'), findsOneWidget);
    expect(find.text('Kaydedeyim mi?'), findsOneWidget);
    expect(find.byKey(const Key('confirm_card_e-weight')), findsOneWidget);
  });

  testWidgets('shows a typing indicator while sending and clears the input', (tester) async {
    final repo = await pumpScreen(tester);
    repo.sendGate = Completer<void>();

    await typeAndSend(tester, 'selam');
    await tester.pump();

    expect(find.byKey(const Key('coach_typing')), findsOneWidget);
    expect(tester.widget<TextField>(find.byKey(const Key('coach_input'))).controller!.text, isEmpty);

    repo.sendGate!.complete();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('coach_typing')), findsNothing);
    expect(find.text('selam'), findsOneWidget);
    // Dil, EasyLocalization'ın seçtiği yerel ayardan gelir (testte cihaz diline bağlı).
    expect(repo.sent.single.locale, anyOf('tr', 'en'));
  });

  testWidgets('a failed message stays with a retry button', (tester) async {
    final repo = await pumpScreen(tester);
    repo.sendError = const ChatSendException(ChatSendError.busy);

    await typeAndSend(tester, 'selam');
    await tester.pumpAndSettle();

    expect(tester.widget<Text>(find.byKey(const Key('coach_unsent_text'))).data, 'selam');
    expect(find.byKey(const Key('coach_send_error')), findsOneWidget);

    repo.sendError = null;
    await tester.tap(find.byKey(const Key('coach_retry')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('coach_unsent_text')), findsNothing);
    expect(find.byKey(const Key('bubble_a2')), findsOneWidget);
  });

  testWidgets('a high remaining quota is not shown', (tester) async {
    await pumpScreen(tester, remaining: 12);
    expect(find.byKey(const Key('coach_remaining')), findsNothing);
  });

  testWidgets('a low remaining quota is shown and input stays enabled', (tester) async {
    await pumpScreen(tester, remaining: 5);
    expect(find.byKey(const Key('coach_remaining')), findsOneWidget);
    expect(tester.widget<TextField>(find.byKey(const Key('coach_input'))).enabled, isTrue);
  });

  testWidgets('no remaining quota locks the input', (tester) async {
    await pumpScreen(tester, remaining: 0);
    expect(tester.widget<TextField>(find.byKey(const Key('coach_input'))).enabled, isFalse);
    expect(tester.widget<IconButton>(find.byKey(const Key('coach_send'))).onPressed, isNull);
  });

  testWidgets('clear chat asks for confirmation and empties the list', (tester) async {
    final repo = await pumpScreen(tester, messages: [userMessage('selam'), assistantMessage(null, content: 'merhaba')]);

    await tester.tap(find.byKey(const Key('coach_menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('coach_clear')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('coach_clear_confirm')));
    await tester.pumpAndSettle();

    expect(repo.clearCount, 1);
    expect(find.text('selam'), findsNothing);
    expect(find.byKey(const Key('coach_suggestion_0')), findsOneWidget);
  });

  testWidgets('a load error offers a reload', (tester) async {
    await pumpScreen(tester, loadError: Exception('offline'));
    expect(find.byKey(const Key('coach_reload')), findsOneWidget);
  });

  testWidgets('user bubbles use the accent, assistant bubbles the card surface', (tester) async {
    await pumpScreen(tester, messages: [userMessage('selam'), assistantMessage(null, content: 'merhaba')]);

    BoxDecoration decorationOf(String key) =>
        tester.widget<Container>(find.byKey(Key(key))).decoration! as BoxDecoration;
    expect(decorationOf('bubble_u1').color, AppColors.accent);
    expect(decorationOf('bubble_a1').color, AppColors.surface);
  });
}