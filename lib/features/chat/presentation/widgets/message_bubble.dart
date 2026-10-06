import 'package:flutter/material.dart';

import '../../domain/chat_models.dart';
import 'confirm_card.dart';

class MessageBubble extends StatelessWidget {
  const MessageBubble({super.key, required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == ChatRole.user;
    final scheme = Theme.of(context).colorScheme;
    final event = message.event;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.85),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Column(
            crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              Container(
                key: Key('bubble_${message.id}'),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: isUser ? scheme.primary : scheme.surfaceContainer,
                  border: isUser ? null : Border.all(color: scheme.outlineVariant),
                  // Konuşan tarafın alt köşesi sivri (spec §5.2).
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(16),
                    topRight: const Radius.circular(16),
                    bottomLeft: Radius.circular(isUser ? 16 : 4),
                    bottomRight: Radius.circular(isUser ? 4 : 16),
                  ),
                ),
                child: Text(
                  message.content,
                  style: TextStyle(color: isUser ? scheme.onPrimary : scheme.onSurface),
                ),
              ),
              if (event != null) ConfirmCard(key: ValueKey(event.id), event: event),
            ],
          ),
        ),
      ),
    );
  }
}
