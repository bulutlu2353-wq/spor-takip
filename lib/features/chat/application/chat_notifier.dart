import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../workout/application/session_providers.dart';
import '../data/chat_repository.dart';
import '../domain/chat_models.dart';
import 'chat_providers.dart';
import 'chat_refresh.dart';

class ChatState {
  const ChatState({
    this.messages = const [],
    this.sending = false,
    this.unsentText,
    this.sendError,
    this.remaining,
  });

  /// Eskiden yeniye.
  final List<ChatMessage> messages;
  final bool sending;

  /// Gönderilmekte olan veya gönderilemeyen mesaj; başarıda temizlenir.
  final String? unsentText;
  final ChatSendError? sendError;

  /// Son 24 saatte kalan mesaj hakkı; bilinmiyorsa null.
  final int? remaining;
}

final chatNotifierProvider = AsyncNotifierProvider.autoDispose<ChatNotifier, ChatState>(ChatNotifier.new);

class ChatNotifier extends AsyncNotifier<ChatState> {
  ChatRepository get _repo => ref.read(chatRepositoryProvider);
  ChatState get _current => state.requireValue;

  @override
  Future<ChatState> build() async {
    final repo = ref.watch(chatRepositoryProvider);
    final (messages, remaining) = await (repo.fetchMessages(), repo.fetchRemaining()).wait;
    return ChatState(messages: messages, remaining: remaining);
  }

  Future<void> send(String text, {required String locale}) async {
    final message = text.trim();
    final before = _current;
    if (message.isEmpty || before.sending) return;
    state = AsyncData(ChatState(messages: before.messages, sending: true, unsentText: message, remaining: before.remaining));
    try {
      final result = await _repo.send(
        message: message,
        locale: locale,
        utcOffsetMinutes: ref.read(nowProvider)().timeZoneOffset.inMinutes,
      );
      if (!ref.mounted) return;
      state = AsyncData(ChatState(messages: [..._current.messages, ...result.messages], remaining: result.remaining));
    } on ChatSendException catch (error) {
      if (!ref.mounted) return;
      state = AsyncData(ChatState(
        messages: _current.messages,
        unsentText: message,
        sendError: error.error,
        remaining: error.error == ChatSendError.dailyLimit ? 0 : _current.remaining,
      ));
    }
  }

  Future<void> retry({required String locale}) async {
    final text = _current.unsentText;
    if (text != null) await send(text, locale: locale);
  }

  Future<ApplyOutcome> apply(ChatEvent event, Map<String, dynamic> extras) async {
    final outcome = await _repo.apply(event.id, extras);
    if (!ref.mounted) return outcome;
    final applied = outcome == ApplyOutcome.applied;
    _replaceEvent(event.withStatus(applied ? ChatEventStatus.applied : ChatEventStatus.stale));
    if (applied) refreshAfterChatChange(ref, event);
    return outcome;
  }

  Future<void> cancel(ChatEvent event) async {
    await _repo.cancel(event.id);
    if (!ref.mounted) return;
    _replaceEvent(event.withStatus(ChatEventStatus.cancelled));
  }

  Future<UndoOutcome> undo(ChatEvent event) async {
    final outcome = await _repo.undo(event.id);
    if (!ref.mounted || outcome == UndoOutcome.modified) return outcome;
    _replaceEvent(event.withStatus(ChatEventStatus.undone));
    refreshAfterChatChange(ref, event);
    return outcome;
  }

  Future<void> clear() async {
    await _repo.clear();
    if (!ref.mounted) return;
    state = AsyncData(ChatState(remaining: _current.remaining));
  }

  void _replaceEvent(ChatEvent event) {
    final current = _current;
    state = AsyncData(ChatState(
      messages: [for (final m in current.messages) m.event?.id == event.id ? m.withEvent(event) : m],
      sending: current.sending,
      unsentText: current.unsentText,
      sendError: current.sendError,
      remaining: current.remaining,
    ));
  }
}
