import 'package:flutter_test/flutter_test.dart';
import 'package:spor_takip/features/chat/domain/chat_models.dart';

void main() {
  test('parses a message with an embedded event (chat_message_json shape)', () {
    final message = ChatMessage.fromJson({
      'id': 'm1',
      'role': 'assistant',
      'content': 'Kaydedeyim mi?',
      'created_at': '2026-10-01T09:01:00+00:00',
      'event': {
        'id': 'e1',
        'tool': 'log_body_weight',
        'status': 'pending',
        'summary': 'Kilo kaydı: 82 kg (2026-10-01)',
        'payload': {'date': '2026-10-01', 'kg': 82},
        'base': {'log': null},
      },
    });

    expect(message.role, ChatRole.assistant);
    expect(message.createdAt, DateTime.utc(2026, 10, 1, 9, 1));
    expect(message.event!.tool, ChatTool.logBodyWeight);
    expect(message.event!.status, ChatEventStatus.pending);
    expect(message.event!.payload['kg'], 82);
    expect(message.event!.base, {'log': null});
  });

  test('parses a message without an event', () {
    final message = ChatMessage.fromJson({
      'id': 'm2',
      'role': 'user',
      'content': 'selam',
      'created_at': '2026-10-01T09:00:00Z',
      'event': null,
    });
    expect(message.role, ChatRole.user);
    expect(message.event, isNull);
  });

  test('tool names map to and from the database', () {
    for (final tool in ChatTool.values) {
      expect(ChatTool.fromDb(tool.dbName), tool);
    }
    expect(ChatTool.editProgram.dbName, 'edit_program');
    expect(() => ChatTool.fromDb('nope'), throwsArgumentError);
  });

  test('withStatus and withEvent copy everything else', () {
    final event = ChatEvent.fromJson({
      'id': 'e1',
      'tool': 'set_goal',
      'status': 'pending',
      'summary': 's',
      'payload': {'goal': 'maintain'},
      'base': {'goal': 'gain_muscle'},
    });
    final applied = event.withStatus(ChatEventStatus.applied);
    expect(applied.status, ChatEventStatus.applied);
    expect(applied.payload, event.payload);

    final message = ChatMessage(id: 'm', role: ChatRole.assistant, content: 'c', createdAt: DateTime.utc(2026), event: event);
    expect(message.withEvent(applied).event!.status, ChatEventStatus.applied);
    expect(message.withEvent(applied).content, 'c');
  });
}
