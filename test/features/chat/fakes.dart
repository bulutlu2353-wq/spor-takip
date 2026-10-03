import 'dart:async';

import 'package:spor_takip/features/chat/data/chat_repository.dart';
import 'package:spor_takip/features/chat/domain/chat_models.dart';

class FakeChatRepository implements ChatRepository {
  FakeChatRepository({List<ChatMessage>? messages, this.remaining = 30}) : messages = [...?messages];

  final List<ChatMessage> messages;
  int? remaining;

  final List<({String message, String locale, int utcOffsetMinutes})> sent = [];
  final List<({String eventId, Map<String, dynamic> extras})> applied = [];
  final List<String> cancelled = [];
  final List<String> undone = [];
  int clearCount = 0;

  /// Doluysa fetchMessages bu hatayı fırlatır.
  Object? loadError;

  /// fetchMessages kaç kez çağrıldı.
  int loadCount = 0;

  /// Doluysa send bu hatayı fırlatır.
  ChatSendException? sendError;

  /// Doluysa apply/cancel/undo bu hatayı fırlatır.
  Object? actionError;

  /// Doluysa send bu tamamlanana kadar bekler ("yazıyor" durumunu görmek için).
  Completer<void>? sendGate;

  ApplyOutcome applyOutcome = ApplyOutcome.applied;
  UndoOutcome undoOutcome = UndoOutcome.undone;

  /// Asistan cevabının taşıyacağı öneri.
  ChatEvent? replyEvent;
  String reply = 'Tamam';

  @override
  Future<List<ChatMessage>> fetchMessages() async {
    loadCount++;
    if (loadError != null) throw loadError!;
    return [...messages];
  }

  @override
  Future<int?> fetchRemaining() async => remaining;

  @override
  Future<ChatSendResult> send({required String message, required String locale, required int utcOffsetMinutes}) async {
    sent.add((message: message, locale: locale, utcOffsetMinutes: utcOffsetMinutes));
    if (sendGate != null) await sendGate!.future;
    if (sendError != null) throw sendError!;
    final n = sent.length;
    final result = [
      ChatMessage(id: 'u$n', role: ChatRole.user, content: message, createdAt: DateTime.utc(2026, 10, 1, 10, n)),
      ChatMessage(
        id: 'a$n',
        role: ChatRole.assistant,
        content: reply,
        createdAt: DateTime.utc(2026, 10, 1, 10, n, 1),
        event: replyEvent,
      ),
    ];
    messages.addAll(result);
    remaining = (remaining ?? 30) - 1;
    return ChatSendResult(messages: result, remaining: remaining!);
  }

  @override
  Future<ApplyOutcome> apply(String eventId, Map<String, dynamic> extras) async {
    if (actionError != null) throw actionError!;
    applied.add((eventId: eventId, extras: extras));
    return applyOutcome;
  }

  @override
  Future<void> cancel(String eventId) async {
    if (actionError != null) throw actionError!;
    cancelled.add(eventId);
  }

  @override
  Future<UndoOutcome> undo(String eventId) async {
    if (actionError != null) throw actionError!;
    undone.add(eventId);
    return undoOutcome;
  }

  @override
  Future<void> clear() async {
    clearCount++;
    messages.clear();
  }
}
