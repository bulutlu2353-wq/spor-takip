enum ChatRole { user, assistant }

/// Sohbetin araçları; [dbName] `chat_events.tool` değeridir.
enum ChatTool {
  logBodyWeight('log_body_weight'),
  updateProfile('update_profile'),
  setGoal('set_goal'),
  createMeal('create_meal'),
  logSet('log_set'),
  editProgram('edit_program');

  const ChatTool(this.dbName);

  final String dbName;

  static ChatTool fromDb(String value) {
    for (final tool in values) {
      if (tool.dbName == value) return tool;
    }
    throw ArgumentError('Unknown chat tool: $value');
  }
}

enum ChatEventStatus { pending, applied, cancelled, undone, stale }

/// Sohbetin önerdiği bir değişiklik (`chat_events`). [base]: öneri anındaki
/// verinin görüntüsü; kartta "önce" değerleri buradan okunur.
class ChatEvent {
  const ChatEvent({
    required this.id,
    required this.tool,
    required this.status,
    required this.summary,
    required this.payload,
    required this.base,
  });

  final String id;
  final ChatTool tool;
  final ChatEventStatus status;
  final String summary;
  final Map<String, dynamic> payload;
  final Map<String, dynamic> base;

  factory ChatEvent.fromJson(Map<String, dynamic> json) {
    return ChatEvent(
      id: json['id'] as String,
      tool: ChatTool.fromDb(json['tool'] as String),
      status: ChatEventStatus.values.byName(json['status'] as String),
      summary: json['summary'] as String,
      payload: Map<String, dynamic>.from(json['payload'] as Map),
      base: Map<String, dynamic>.from(json['base'] as Map),
    );
  }

  ChatEvent withStatus(ChatEventStatus status) {
    return ChatEvent(id: id, tool: tool, status: status, summary: summary, payload: payload, base: base);
  }
}

/// `chat_message_json` biçimindeki bir mesaj.
class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.role,
    required this.content,
    required this.createdAt,
    this.event,
  });

  final String id;
  final ChatRole role;
  final String content;
  final DateTime createdAt;
  final ChatEvent? event;

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    final event = json['event'];
    return ChatMessage(
      id: json['id'] as String,
      role: ChatRole.values.byName(json['role'] as String),
      content: json['content'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      event: event == null ? null : ChatEvent.fromJson(Map<String, dynamic>.from(event as Map)),
    );
  }

  ChatMessage withEvent(ChatEvent event) {
    return ChatMessage(id: id, role: role, content: content, createdAt: createdAt, event: event);
  }
}
