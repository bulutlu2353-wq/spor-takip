import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/chat_notifier.dart';
import '../application/chat_providers.dart';
import '../data/chat_repository.dart';
import '../domain/chat_models.dart';
import 'widgets/message_bubble.dart';

const _lowQuotaThreshold = 5;
const _suggestions = ['coach.suggestion_1', 'coach.suggestion_2', 'coach.suggestion_3'];
const _sendErrorKeys = {
  ChatSendError.dailyLimit: 'coach.error_daily_limit',
  ChatSendError.busy: 'coach.error_busy',
  ChatSendError.unavailable: 'coach.error_unavailable',
};

const _lockedFeatures = [
  (Icons.chat_bubble_outline, 'coach.locked_feature_1'),
  (Icons.monitor_weight_outlined, 'coach.locked_feature_2'),
  (Icons.flag_outlined, 'coach.locked_feature_3'),
  (Icons.restaurant_outlined, 'coach.locked_feature_4'),
  (Icons.fitness_center, 'coach.locked_feature_5'),
  (Icons.edit_calendar_outlined, 'coach.locked_feature_6'),
];

/// Alt menüdeki "Antrenör" sekmesi (spec §5.2). [coachEnabledProvider] kapalıyken
/// sohbet yüklenmez; yalnız tanıtım ekranı gösterilir.
class CoachScreen extends ConsumerWidget {
  const CoachScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(coachEnabledProvider) ? const _CoachChat() : const _CoachLocked();
  }
}

class _CoachLocked extends StatelessWidget {
  const _CoachLocked();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text('coach.title'.tr())),
      body: Center(
        child: SingleChildScrollView(
          key: const Key('coach_locked'),
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.construction_outlined, size: 56, color: theme.colorScheme.primary),
                const SizedBox(height: 12),
                Chip(label: Text('coach.locked_badge'.tr())),
                const SizedBox(height: 12),
                Text('coach.locked_body'.tr(), textAlign: TextAlign.center, style: theme.textTheme.titleMedium),
                const SizedBox(height: 16),
                for (final (icon, key) in _lockedFeatures)
                  ListTile(dense: true, leading: Icon(icon), title: Text(key.tr())),
                const SizedBox(height: 12),
                Text('coach.locked_note'.tr(), textAlign: TextAlign.center, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CoachChat extends ConsumerStatefulWidget {
  const _CoachChat();

  @override
  ConsumerState<_CoachChat> createState() => _CoachChatState();
}

class _CoachChatState extends ConsumerState<_CoachChat> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String get _locale => context.locale.languageCode;

  Future<void> _send([String? text]) async {
    final message = (text ?? _controller.text).trim();
    if (message.isEmpty) return;
    _controller.clear();
    await ref.read(chatNotifierProvider.notifier).send(message, locale: _locale);
  }

  Future<void> _confirmClear() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('coach.clear_title'.tr()),
        content: Text('coach.clear_body'.tr()),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text('coach.cancel'.tr())),
          FilledButton(
            key: const Key('coach_clear_confirm'),
            onPressed: () => Navigator.pop(context, true),
            child: Text('coach.clear'.tr()),
          ),
        ],
      ),
    );
    if (confirmed == true) await ref.read(chatNotifierProvider.notifier).clear();
  }

  @override
  Widget build(BuildContext context) {
    final chat = ref.watch(chatNotifierProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text('coach.title'.tr()),
        actions: [
          PopupMenuButton<String>(
            key: const Key('coach_menu'),
            onSelected: (_) => _confirmClear(),
            itemBuilder: (context) => [
              PopupMenuItem(value: 'clear', key: const Key('coach_clear'), child: Text('coach.clear'.tr())),
            ],
          ),
        ],
      ),
      body: chat.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('coach.load_error'.tr()),
              TextButton(
                key: const Key('coach_reload'),
                onPressed: () => ref.invalidate(chatNotifierProvider),
                child: Text('coach.retry'.tr()),
              ),
            ],
          ),
        ),
        data: (state) => Column(
          children: [
            Expanded(child: state.messages.isEmpty ? _Suggestions(onTap: _send) : _MessageList(messages: state.messages)),
            if (state.sending)
              Padding(
                key: const Key('coach_typing'),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Align(alignment: Alignment.centerLeft, child: Text('coach.typing'.tr())),
              ),
            if (!state.sending && state.unsentText != null)
              _UnsentRow(state: state, onRetry: () => ref.read(chatNotifierProvider.notifier).retry(locale: _locale)),
            if (state.remaining != null && state.remaining! <= _lowQuotaThreshold)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'coach.remaining'.tr(namedArgs: {'count': '${state.remaining}'}),
                  key: const Key('coach_remaining'),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            _InputBar(
              controller: _controller,
              enabled: !state.sending && state.remaining != 0,
              onSend: _send,
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageList extends StatelessWidget {
  const _MessageList({required this.messages});

  final List<ChatMessage> messages;

  @override
  Widget build(BuildContext context) {
    // reverse: en yeni mesaj altta ve görünür kalır.
    return ListView.builder(
      reverse: true,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: messages.length,
      itemBuilder: (context, index) => MessageBubble(message: messages[messages.length - 1 - index]),
    );
  }
}

class _Suggestions extends StatelessWidget {
  const _Suggestions({required this.onTap});

  final void Function(String text) onTap;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.forum_outlined, size: 48),
            const SizedBox(height: 12),
            Text('coach.empty'.tr(), textAlign: TextAlign.center),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                for (var i = 0; i < _suggestions.length; i++)
                  ActionChip(
                    key: Key('coach_suggestion_$i'),
                    label: Text(_suggestions[i].tr()),
                    onPressed: () => onTap(_suggestions[i].tr()),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _UnsentRow extends StatelessWidget {
  const _UnsentRow({required this.state, required this.onRetry});

  final ChatState state;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final error = state.sendError;
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: theme.colorScheme.error, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(state.unsentText!, key: const Key('coach_unsent_text'), maxLines: 2, overflow: TextOverflow.ellipsis),
                if (error != null)
                  Text(
                    _sendErrorKeys[error]!.tr(),
                    key: const Key('coach_send_error'),
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
                  ),
              ],
            ),
          ),
          TextButton(
            key: const Key('coach_retry'),
            onPressed: error == ChatSendError.dailyLimit ? null : onRetry,
            child: Text('coach.retry'.tr()),
          ),
        ],
      ),
    );
  }
}

class _InputBar extends StatelessWidget {
  const _InputBar({required this.controller, required this.enabled, required this.onSend});

  final TextEditingController controller;
  final bool enabled;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 4, 8),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                key: const Key('coach_input'),
                controller: controller,
                enabled: enabled,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onSend(),
                decoration: InputDecoration(hintText: 'coach.input_hint'.tr(), border: const OutlineInputBorder()),
              ),
            ),
            IconButton(
              key: const Key('coach_send'),
              icon: const Icon(Icons.send),
              onPressed: enabled ? onSend : null,
            ),
          ],
        ),
      ),
    );
  }
}
