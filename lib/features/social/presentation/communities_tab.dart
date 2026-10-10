import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/widgets/section_header.dart';
import '../application/community_providers.dart';
import '../domain/community.dart';
import 'community_form_sheet.dart';
import 'join_community_sheet.dart';

/// Topluluklar sekmesi (S2 spec §6.2): kurma/katılma ve "Topluluklarım".
class CommunitiesTab extends ConsumerWidget {
  const CommunitiesTab({super.key});

  /// Alt sayfa bir kimlik döndürürse o topluluğu açar.
  Future<void> _openAfter(BuildContext context, Future<String?> sheet) async {
    final id = await sheet;
    if (id != null && context.mounted) context.push('/social/community/$id');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(myCommunitiesProvider);
    final scheme = Theme.of(context).colorScheme;
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(myCommunitiesProvider);
        await ref.read(myCommunitiesProvider.future);
      },
      child: ListView(
        key: const Key('communities_tab'),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: async.when(
          loading: () => const [
            Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator())),
          ],
          error: (error, stackTrace) => [
            Center(
              child: TextButton(
                key: const Key('communities_retry'),
                onPressed: () => ref.invalidate(myCommunitiesProvider),
                child: Text('social.retry'.tr()),
              ),
            ),
          ],
          data: (entries) {
            final full = entries.length >= maxCommunities;
            return [
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      key: const Key('community_create'),
                      style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                      icon: const Icon(Icons.add),
                      label: Text('social.community_create'.tr()),
                      onPressed: full ? null : () => _openAfter(context, showCommunityFormSheet(context)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      key: const Key('community_join'),
                      style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                      icon: const Icon(Icons.group_add),
                      label: Text('social.community_join'.tr()),
                      onPressed: full ? null : () => _openAfter(context, showJoinCommunitySheet(context)),
                    ),
                  ),
                ],
              ),
              if (full)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'social.community_limit_note'.tr(),
                    key: const Key('community_limit_note'),
                    style: TextStyle(color: scheme.onSurfaceVariant),
                  ),
                ),
              SectionHeader('social.my_communities'.tr(), trailing: '${entries.length}'),
              if (entries.isEmpty)
                Text(
                  'social.communities_empty'.tr(),
                  key: const Key('communities_empty'),
                  style: TextStyle(color: scheme.onSurfaceVariant),
                )
              else
                for (final entry in entries) _CommunityRow(entry: entry),
            ];
          },
        ),
      ),
    );
  }
}

class _CommunityRow extends StatelessWidget {
  const _CommunityRow({required this.entry});

  final CommunityEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final community = entry.community;
    final position = entry.myPosition;
    return Card(
      key: Key('community_${community.id}'),
      margin: const EdgeInsets.only(bottom: 8),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/social/community/${community.id}'),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Icon(community.isPublic ? Icons.groups : Icons.lock_outline, color: scheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      community.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    Text(
                      'social.community_members'.tr(namedArgs: {'n': '${entry.memberCount}'}),
                      style: TextStyle(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              Text(
                position == null
                    ? '—'
                    : 'social.community_position'.tr(namedArgs: {'p': '$position', 'n': '${entry.memberCount}'}),
                key: Key('community_position_${community.id}'),
                style: theme.textTheme.titleMedium?.copyWith(color: scheme.primary, fontWeight: FontWeight.w900),
              ),
              Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}
