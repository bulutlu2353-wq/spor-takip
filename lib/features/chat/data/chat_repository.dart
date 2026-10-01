import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/chat_models.dart';

enum ChatSendError { dailyLimit, busy, unavailable }

class ChatSendException implements Exception {
  const ChatSendException(this.error);

  final ChatSendError error;
}

enum ApplyOutcome { applied, stale }

enum UndoOutcome { undone, modified }

class ChatSendResult {
  const ChatSendResult({required this.messages, required this.remaining});

  /// Kaydedilen kullanıcı ve asistan mesajı, eskiden yeniye.
  final List<ChatMessage> messages;
  final int remaining;
}

abstract interface class ChatRepository {
  /// Son 200 mesaj, eskiden yeniye.
  Future<List<ChatMessage>> fetchMessages();

  /// Son 24 saatte kalan mesaj hakkı; öğrenilemezse null.
  Future<int?> fetchRemaining();

  /// Hata durumunda [ChatSendException]; hiçbir şey kaydedilmez.
  Future<ChatSendResult> send({required String message, required String locale, required int utcOffsetMinutes});

  Future<ApplyOutcome> apply(String eventId, Map<String, dynamic> extras);

  Future<void> cancel(String eventId);

  Future<UndoOutcome> undo(String eventId);

  /// Mesajları siler (öneri kayıtları ve sayaç kalır).
  Future<void> clear();
}

class SupabaseChatRepository implements ChatRepository {
  SupabaseChatRepository(this._client);

  final SupabaseClient _client;

  static const _function = 'coach-chat';
  static const _historyLimit = 200;

  List<ChatMessage> _parse(Object? data) {
    return [for (final row in data as List) ChatMessage.fromJson(Map<String, dynamic>.from(row as Map))];
  }

  @override
  Future<List<ChatMessage>> fetchMessages() async {
    return _parse(await _client.rpc('recent_chat_messages', params: {'p_limit': _historyLimit}));
  }

  @override
  Future<int?> fetchRemaining() async {
    try {
      final response = await _client.functions.invoke(_function, body: {'action': 'status'});
      return (response.data as Map)['remaining'] as int;
    } catch (error) {
      debugPrint('coach-chat status failed: $error');
      return null;
    }
  }

  @override
  Future<ChatSendResult> send({required String message, required String locale, required int utcOffsetMinutes}) async {
    try {
      final response = await _client.functions.invoke(
        _function,
        body: {'message': message, 'locale': locale, 'utc_offset_minutes': utcOffsetMinutes},
      );
      final data = Map<String, dynamic>.from(response.data as Map);
      return ChatSendResult(messages: _parse(data['messages']), remaining: data['remaining'] as int);
    } on FunctionException catch (error) {
      final details = error.details;
      final code = details is Map ? details['code'] as String? : null;
      debugPrint('coach-chat send failed: ${error.status} $code');
      throw ChatSendException(switch (code) {
        'DAILY_LIMIT' => ChatSendError.dailyLimit,
        'LLM_QUOTA' => ChatSendError.busy,
        _ => ChatSendError.unavailable,
      });
    } catch (error) {
      debugPrint('coach-chat send failed: $error');
      throw const ChatSendException(ChatSendError.unavailable);
    }
  }

  @override
  Future<ApplyOutcome> apply(String eventId, Map<String, dynamic> extras) async {
    final result = await _client.rpc('apply_chat_action', params: {'p_event_id': eventId, 'p_extras': extras});
    return result == 'stale' ? ApplyOutcome.stale : ApplyOutcome.applied;
  }

  @override
  Future<void> cancel(String eventId) async {
    await _client.rpc('cancel_chat_action', params: {'p_event_id': eventId});
  }

  @override
  Future<UndoOutcome> undo(String eventId) async {
    final result = await _client.rpc('undo_chat_action', params: {'p_event_id': eventId});
    return result == 'modified' ? UndoOutcome.modified : UndoOutcome.undone;
  }

  @override
  Future<void> clear() async {
    await _client.rpc('clear_chat');
  }
}
