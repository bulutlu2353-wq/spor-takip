import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_fonts.dart';
import '../../../shared/text_case.dart';
import '../application/community_providers.dart';
import '../application/social_providers.dart';
import '../domain/community.dart';

/// Adla arayıp ya da davet koduyla katılır (S2 spec §6.2). Katılınan topluluğun kimliğini döndürür.
Future<String?> showJoinCommunitySheet(BuildContext context) => showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => const JoinCommunitySheet(),
    );

enum _JoinMode { search, code }

class JoinCommunitySheet extends ConsumerStatefulWidget {
  const JoinCommunitySheet({super.key});

  @override
  ConsumerState<JoinCommunitySheet> createState() => _JoinCommunitySheetState();
}

class _JoinCommunitySheetState extends ConsumerState<JoinCommunitySheet> {
  final _query = TextEditingController();
  final _code = TextEditingController();
  _JoinMode _mode = _JoinMode.search;
  List<CommunitySearchResult>? _results;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _query.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } on CommunityException catch (e) {
      if (mounted) setState(() => _error = 'social.community_error.${e.code}'.tr());
    } catch (e, st) {
      debugPrint('join community failed: $e\n$st');
      if (mounted) setState(() => _error = 'social.action_error'.tr());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  bool get _canSearch => !_busy && _query.text.trim().length >= 2;

  bool get _canJoinByCode => !_busy && _code.text.trim().length == 8;

  void _search() {
    if (!_canSearch) return;
    final query = _query.text.trim();
    _run(() async {
      final results = await ref.read(socialRepositoryProvider).searchCommunities(query);
      if (mounted) setState(() => _results = results);
    });
  }

  void _join(String id) {
    final navigator = Navigator.of(context);
    _run(() async {
      await ref.read(communityActionsProvider).join(id);
      navigator.pop(id);
    });
  }

  void _joinByCode() {
    final navigator = Navigator.of(context);
    _run(() async {
      final id = await ref.read(communityActionsProvider).joinByCode(_code.text);
      navigator.pop(id);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final results = _results;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        key: const Key('join_sheet'),
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              upperCaseFor('social.join_title'.tr(), context.locale.languageCode),
              style: theme.textTheme.titleLarge?.copyWith(fontFamily: AppFonts.heading, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            Text(
              'social.join_privacy_note'.tr(),
              key: const Key('join_privacy_note'),
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            SegmentedButton<_JoinMode>(
              showSelectedIcon: false,
              segments: [
                ButtonSegment(
                  value: _JoinMode.search,
                  label: Text('social.join_mode_search'.tr(), key: const Key('join_mode_search')),
                ),
                ButtonSegment(
                  value: _JoinMode.code,
                  label: Text('social.join_mode_code'.tr(), key: const Key('join_mode_code')),
                ),
              ],
              selected: {_mode},
              onSelectionChanged: (selection) => setState(() {
                _mode = selection.first;
                _error = null;
              }),
            ),
            const SizedBox(height: 16),
            if (_mode == _JoinMode.search) ...[
              TextField(
                key: const Key('join_search_field'),
                controller: _query,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(labelText: 'social.join_search_hint'.tr()),
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) => _search(),
              ),
              const SizedBox(height: 8),
              FilledButton(
                key: const Key('join_search_submit'),
                onPressed: _canSearch ? _search : null,
                child: Text('social.search'.tr()),
              ),
              if (results != null && results.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    'social.join_no_results'.tr(),
                    key: const Key('join_no_results'),
                    style: TextStyle(color: scheme.onSurfaceVariant),
                  ),
                ),
              if (results != null)
                for (final r in results) _ResultRow(result: r, onJoin: _busy ? null : () => _join(r.id)),
            ] else ...[
              TextField(
                key: const Key('join_code_field'),
                controller: _code,
                maxLength: 8,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(labelText: 'social.join_code_hint'.tr()),
                onChanged: (_) => setState(() {}),
              ),
              FilledButton(
                key: const Key('join_code_submit'),
                onPressed: _canJoinByCode ? _joinByCode : null,
                child: Text('social.join_button'.tr()),
              ),
            ],
            if (_error case final error?)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(error, key: const Key('join_error'), style: TextStyle(color: scheme.error)),
              ),
          ],
        ),
      ),
    );
  }
}

class _ResultRow extends StatelessWidget {
  const _ResultRow({required this.result, required this.onJoin});

  final CommunitySearchResult result;
  final VoidCallback? onJoin;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Card(
      key: Key('join_result_${result.id}'),
      margin: const EdgeInsets.only(top: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    result.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  if (result.description.isNotEmpty)
                    Text(
                      result.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: scheme.onSurfaceVariant),
                    ),
                  Text(
                    'social.community_members'.tr(namedArgs: {'n': '${result.memberCount}'}),
                    style: theme.textTheme.labelMedium?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (result.isMember)
              Text('social.join_member'.tr(), style: TextStyle(color: scheme.primary, fontWeight: FontWeight.w800))
            else
              FilledButton(
                key: Key('join_result_join_${result.id}'),
                onPressed: onJoin,
                child: Text('social.join_button'.tr()),
              ),
          ],
        ),
      ),
    );
  }
}
