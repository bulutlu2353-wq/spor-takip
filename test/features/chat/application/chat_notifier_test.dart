import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spor_takip/features/chat/application/chat_notifier.dart';
import 'package:spor_takip/features/chat/application/chat_providers.dart';
import 'package:spor_takip/features/chat/data/chat_repository.dart';
import 'package:spor_takip/features/chat/domain/chat_models.dart';
import 'package:spor_takip/features/onboarding/application/auth_providers.dart';
import 'package:spor_takip/features/onboarding/application/profile_providers.dart';
import 'package:spor_takip/features/progress/application/progress_providers.dart';
import 'package:spor_takip/features/progress/domain/body_weight_log.dart';
import 'package:spor_takip/features/workout/application/session_providers.dart';

import '../../progress/fixtures.dart';
import '../fakes.dart';
import '../fixtures.dart';

void main() {
  late FakeChatRepository repo;
  late ProviderContainer container;
  late int weightFetches;

  setUp(() {
    weightFetches = 0;
    repo = FakeChatRepository(messages: [userMessage('kilom 82'), assistantMessage(weightEvent())], remaining: 12);
    container = ProviderContainer(overrides: [
      isLoggedInProvider.overrideWithValue(true),
      chatRepositoryProvider.overrideWithValue(repo),
      // UTC "şimdi": saat farkı makineden bağımsız 0 olur.
      nowProvider.overrideWithValue(() => DateTime.utc(2026, 10, 1, 9)),
      profileProvider.overrideWith((ref) async => testProfile),
      weightLogsProvider.overrideWith((ref) async {
        weightFetches++;
        return const <BodyWeightLog>[];
      }),
    ]);
    addTearDown(container.dispose);
  });

  Future<ChatNotifier> ready() async {
    container.listen(chatNotifierProvider, (_, _) {});
    await container.read(chatNotifierProvider.future);
    return container.read(chatNotifierProvider.notifier);
  }

  ChatState current() => container.read(chatNotifierProvider).requireValue;

  test('loads the history and the remaining quota', () async {
    await ready();
    expect(current().messages.map((m) => m.id), ['u1', 'a1']);
    expect(current().remaining, 12);
    expect(current().sending, isFalse);
  });

  test('send appends the saved exchange and updates the quota', () async {
    final notifier = await ready();
    await notifier.send('  Bugün ne yemeliyim? ', locale: 'tr');

    expect(repo.sent.single, (message: 'Bugün ne yemeliyim?', locale: 'tr', utcOffsetMinutes: 0));
    expect(current().messages.map((m) => m.content).toList().sublist(2), ['Bugün ne yemeliyim?', 'Tamam']);
    expect(current().remaining, 11);
    expect(current().unsentText, isNull);
    expect(current().sendError, isNull);
  });

  test('send ignores blank text', () async {
    final notifier = await ready();
    await notifier.send('   ', locale: 'tr');
    expect(repo.sent, isEmpty);
  });

  test('a failed send keeps the text for retry; daily limit zeroes the quota', () async {
    final notifier = await ready();
    repo.sendError = const ChatSendException(ChatSendError.dailyLimit);
    await notifier.send('selam', locale: 'tr');

    expect(current().messages.length, 2);
    expect(current().unsentText, 'selam');
    expect(current().sendError, ChatSendError.dailyLimit);
    expect(current().remaining, 0);

    repo.sendError = null;
    await notifier.retry(locale: 'en');
    expect(repo.sent.last.message, 'selam');
    expect(repo.sent.last.locale, 'en');
    expect(current().unsentText, isNull);
    expect(current().messages.length, 4);
  });

  test('a busy error keeps the known quota', () async {
    final notifier = await ready();
    repo.sendError = const ChatSendException(ChatSendError.busy);
    await notifier.send('selam', locale: 'tr');
    expect(current().sendError, ChatSendError.busy);
    expect(current().remaining, 12);
  });

  test('apply forwards extras, marks the event applied and refreshes weight logs', () async {
    final notifier = await ready();
    container.listen(weightLogsProvider, (_, _) {});
    await container.read(weightLogsProvider.future);
    expect(weightFetches, 1);

    final outcome = await notifier.apply(weightEvent(), {'calorie_target': 2800, 'protein_target': 180});

    expect(outcome, ApplyOutcome.applied);
    expect(repo.applied.single.eventId, 'e-weight');
    expect(repo.applied.single.extras, {'calorie_target': 2800, 'protein_target': 180});
    expect(current().messages.last.event!.status, ChatEventStatus.applied);
    await container.read(weightLogsProvider.future);
    expect(weightFetches, 2);
  });

  test('a stale apply marks the event stale and refreshes nothing', () async {
    final notifier = await ready();
    container.listen(weightLogsProvider, (_, _) {});
    await container.read(weightLogsProvider.future);
    repo.applyOutcome = ApplyOutcome.stale;

    expect(await notifier.apply(weightEvent(), const {}), ApplyOutcome.stale);
    expect(current().messages.last.event!.status, ChatEventStatus.stale);
    await container.read(weightLogsProvider.future);
    expect(weightFetches, 1);
  });

  test('cancel marks the event cancelled', () async {
    final notifier = await ready();
    await notifier.cancel(weightEvent());
    expect(repo.cancelled, ['e-weight']);
    expect(current().messages.last.event!.status, ChatEventStatus.cancelled);
  });

  test('undo marks the event undone; a modified undo leaves it applied', () async {
    final notifier = await ready();
    final applied = weightEvent(status: ChatEventStatus.applied);

    repo.undoOutcome = UndoOutcome.modified;
    expect(await notifier.undo(applied), UndoOutcome.modified);
    expect(current().messages.last.event!.status, ChatEventStatus.pending);

    repo.undoOutcome = UndoOutcome.undone;
    expect(await notifier.undo(applied), UndoOutcome.undone);
    expect(current().messages.last.event!.status, ChatEventStatus.undone);
  });

  test('clear empties the chat but keeps the quota', () async {
    final notifier = await ready();
    await notifier.clear();
    expect(repo.clearCount, 1);
    expect(current().messages, isEmpty);
    expect(current().remaining, 12);
  });
}
