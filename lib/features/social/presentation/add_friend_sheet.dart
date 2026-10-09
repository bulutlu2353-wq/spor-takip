import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_fonts.dart';
import '../../../shared/text_case.dart';
import '../application/social_providers.dart';
import '../domain/public_profile.dart';
import '../domain/username.dart';
import 'widgets/social_avatar.dart';

/// Kullanıcı adı ya da davet koduyla tam eşleşme arar, istek gönderir (S1 spec §6.3).
Future<void> showAddFriendSheet(BuildContext context) => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => const AddFriendSheet(),
    );

class AddFriendSheet extends ConsumerStatefulWidget {
  const AddFriendSheet({super.key});

  @override
  ConsumerState<AddFriendSheet> createState() => _AddFriendSheetState();
}

class _AddFriendSheetState extends ConsumerState<AddFriendSheet> {
  final _query = TextEditingController();
  bool _byInvite = false;
  bool _searching = false;
  bool _searched = false;
  bool _sending = false;
  FoundUser? _found;
  String? _outcome;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  void _reset() {
    _found = null;
    _searched = false;
    _outcome = null;
  }

  Future<void> _search() async {
    final query = _query.text.trim();
    if (query.isEmpty) return;
    setState(() {
      _searching = true;
      _reset();
    });
    try {
      final repo = ref.read(socialRepositoryProvider);
      final found = _byInvite ? await repo.findByInviteCode(query) : await repo.findByUsername(normalizeUsername(query));
      if (mounted) setState(() => _found = found);
    } catch (e, st) {
      debugPrint('friend search failed: $e\n$st');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('social.action_error'.tr())));
    } finally {
      if (mounted) {
        setState(() {
          _searching = false;
          _searched = true;
        });
      }
    }
  }

  Future<void> _send() async {
    final found = _found;
    if (found == null) return;
    setState(() => _sending = true);
    try {
      final result = await ref.read(socialActionsProvider).send(found.userId);
      if (mounted) {
        setState(() => _outcome = switch (result) {
              'accepted' => 'social.outcome_accepted',
              'already_friends' => 'social.outcome_already',
              _ => 'social.outcome_pending',
            }
                .tr());
      }
    } catch (e, st) {
      debugPrint('send request failed: $e\n$st');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('social.action_error'.tr())));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final found = _found;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, MediaQuery.viewInsetsOf(context).bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            upperCaseFor('social.add_title'.tr(), context.locale.languageCode),
            style: theme.textTheme.titleLarge?.copyWith(fontFamily: AppFonts.heading, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 12),
          SegmentedButton<bool>(
            showSelectedIcon: false,
            segments: [
              ButtonSegment(
                value: false,
                label: Text('social.add_by_username'.tr(), key: const Key('add_mode_username')),
              ),
              ButtonSegment(value: true, label: Text('social.add_by_invite'.tr(), key: const Key('add_mode_invite'))),
            ],
            selected: {_byInvite},
            onSelectionChanged: (selection) => setState(() {
              _byInvite = selection.first;
              _query.clear();
              _reset();
            }),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  key: const Key('add_query_field'),
                  controller: _query,
                  autocorrect: false,
                  textCapitalization: _byInvite ? TextCapitalization.characters : TextCapitalization.none,
                  decoration: InputDecoration(prefixText: _byInvite ? null : '@'),
                  onSubmitted: (_) => _search(),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                key: const Key('add_search'),
                onPressed: _searching ? null : _search,
                child: Text('social.search'.tr()),
              ),
            ],
          ),
          if (_searched && found == null && !_searching)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text(
                'social.not_found'.tr(),
                key: const Key('add_not_found'),
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
            ),
          if (found != null)
            Card(
              key: const Key('add_result'),
              margin: const EdgeInsets.only(top: 16),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    SocialAvatar(initials: found.initials),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(found.displayName, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                          Text('@${found.username}', style: TextStyle(color: scheme.onSurfaceVariant)),
                        ],
                      ),
                    ),
                    FilledButton(
                      key: const Key('add_send'),
                      onPressed: _sending || _outcome != null ? null : _send,
                      child: Text('social.send_request'.tr()),
                    ),
                  ],
                ),
              ),
            ),
          if (_outcome case final outcome?)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(outcome, key: const Key('add_outcome'), style: TextStyle(color: scheme.primary)),
            ),
        ],
      ),
    );
  }
}
