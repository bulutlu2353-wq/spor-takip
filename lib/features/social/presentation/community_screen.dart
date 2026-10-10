import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_fonts.dart';
import '../../../shared/text_case.dart';
import '../../../shared/widgets/section_header.dart';
import '../../workout/application/session_providers.dart';
import '../application/community_providers.dart';
import '../domain/period_keys.dart';
import '../domain/standings.dart';
import 'community_form_sheet.dart';
import 'manage_members_sheet.dart';
import 'social_screen.dart';
import 'widgets/period_widgets.dart';

/// Topluluk sayfası (S2 spec §6.3): başlık kartı, HAFTA/AY, geçen dönemin
/// şampiyonları, canlı sıralama ve kas liderleri.
class CommunityScreen extends ConsumerStatefulWidget {
  const CommunityScreen({super.key, required this.communityId});

  final String communityId;

  @override
  ConsumerState<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends ConsumerState<CommunityScreen> {
  PeriodKind _kind = PeriodKind.week;

  @override
  Widget build(BuildContext context) {
    final provider = communityDetailProvider(widget.communityId);
    final async = ref.watch(provider);
    final current = async.value;
    return Scaffold(
      key: const Key('community_screen'),
      appBar: AppBar(
        title: Text(
          current == null ? '' : upperCaseFor(current.community.name, context.locale.languageCode),
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
        ),
        actions: [if (current != null) _CommunityMenu(detail: current)],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(
          child: TextButton(
            key: const Key('community_retry'),
            onPressed: () => ref.invalidate(provider),
            child: Text('social.retry'.tr()),
          ),
        ),
        data: (detail) => detail == null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'social.community_not_member'.tr(),
                    key: const Key('community_not_member'),
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            : RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(provider);
                  await ref.read(provider.future);
                },
                child: _CommunityBody(detail: detail, kind: _kind, onKind: (k) => setState(() => _kind = k)),
              ),
      ),
    );
  }
}

class _CommunityBody extends ConsumerWidget {
  const _CommunityBody({required this.detail, required this.kind, required this.onKind});

  final CommunityDetail detail;
  final PeriodKind kind;
  final ValueChanged<PeriodKind> onKind;

  List<TitleLine> _lines(Iterable<PeriodTitle> titles) => [
        for (final t in titles)
          TitleLine(
            category: t.category,
            holders: [for (final id in t.holders) detail.profiles[id]?.displayName ?? '?'],
            value: t.value,
          ),
      ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final muted = TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant);
    final now = ref.read(nowProvider)();
    final key = periodKey(kind, now);
    final previous = _lines(periodTitles(detail.stats, kind, periodKey(kind, now, previous: true)));
    final leaders = _lines(periodTitles(detail.stats, kind, key).where((t) => t.category != 'xp'));
    final rows = [
      for (final s in standings(detail.stats, kind, key))
        if ((detail.profiles[s.userId], detail.stats[s.userId]) case (final profile?, final stats?))
          StandingLine(
            userId: s.userId,
            position: s.position,
            name: profile.displayName,
            initials: profile.initials,
            level: stats.level,
            rank: stats.rank,
            xp: s.xp,
            title: sharedTitleName(stats.activeTitle),
            isMe: s.userId == detail.myId,
          ),
    ];
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        _CommunityHeader(detail: detail),
        const SizedBox(height: 16),
        PeriodSwitch(kind: kind, keyPrefix: 'period', onChanged: onKind),
        SectionHeader('social.titles_prev_${kind.name}'.tr()),
        if (previous.isEmpty)
          Text('social.titles_empty'.tr(), key: const Key('community_titles_empty'), style: muted)
        else
          PeriodTitlesList(key: const Key('community_titles'), kind: kind, lines: previous),
        SectionHeader(
          'social.standings_${kind.name}'.tr(),
          key: const Key('period_remaining'),
          trailing: periodRemainingLabel(kind, now),
        ),
        if (rows.isEmpty)
          Text('social.standings_empty'.tr(), key: const Key('community_standings_empty'), style: muted)
        else
          StandingsList(key: const Key('community_standings'), lines: rows),
        const SizedBox(height: 8),
        Card(
          margin: EdgeInsets.zero,
          clipBehavior: Clip.antiAlias,
          child: ExpansionTile(
            key: const Key('community_muscle_leaders'),
            leading: const Icon(Icons.fitness_center),
            title: Text('social.muscle_leaders'.tr()),
            childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            children: [
              if (leaders.isEmpty)
                Text('social.muscle_leaders_empty'.tr(), style: muted)
              else
                PeriodTitlesList(kind: kind, lines: leaders),
            ],
          ),
        ),
      ],
    );
  }
}

class _CommunityHeader extends StatelessWidget {
  const _CommunityHeader({required this.detail});

  final CommunityDetail detail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final lang = context.locale.languageCode;
    final community = detail.community;
    return Card(
      key: const Key('community_header'),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              community.name,
              style: theme.textTheme.headlineSmall?.copyWith(fontFamily: AppFonts.heading, fontWeight: FontWeight.w900),
            ),
            if (community.description.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(community.description, style: TextStyle(color: scheme.onSurfaceVariant)),
              ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _Chip(
                  icon: Icons.group,
                  text: 'social.community_members'.tr(namedArgs: {'n': '${detail.members.length}'}),
                ),
                _Chip(
                  icon: community.isPublic ? Icons.public : Icons.lock_outline,
                  text: upperCaseFor(
                    (community.isPublic ? 'social.community_public_badge' : 'social.community_private_badge').tr(),
                    lang,
                  ),
                  highlighted: community.isPublic,
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        upperCaseFor('social.community_code_label'.tr(), lang),
                        style: theme.textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant, letterSpacing: 1),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        community.inviteCode,
                        key: const Key('community_code'),
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontFamily: AppFonts.heading,
                          fontWeight: FontWeight.w900,
                          color: scheme.primary,
                          letterSpacing: 2,
                        ),
                      ),
                    ],
                  ),
                ),
                OutlinedButton.icon(
                  key: const Key('community_copy_code'),
                  icon: const Icon(Icons.copy, size: 18),
                  label: Text('social.copy'.tr()),
                  onPressed: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    await Clipboard.setData(ClipboardData(
                      text: 'social.community_invite_text'
                          .tr(namedArgs: {'name': community.name, 'code': community.inviteCode}),
                    ));
                    messenger.showSnackBar(SnackBar(content: Text('social.copied'.tr())));
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.icon, required this.text, this.highlighted = false});

  final IconData icon;
  final String text;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final color = highlighted ? scheme.primary : scheme.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.all(Radius.circular(6)),
        border: Border.all(color: highlighted ? scheme.primary : scheme.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(text, style: theme.textTheme.labelMedium?.copyWith(color: color, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _CommunityMenu extends ConsumerWidget {
  const _CommunityMenu({required this.detail});

  final CommunityDetail detail;

  Future<void> _leave(BuildContext context, WidgetRef ref) async {
    final body = detail.members.length == 1
        ? 'social.community_leave_last_body'
        : detail.iAmOwner
            ? 'social.community_leave_owner_body'
            : 'social.community_leave_body';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('social.community_leave_title'.tr()),
        content: Text(body.tr()),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text('social.cancel'.tr())),
          FilledButton(
            key: const Key('community_leave_confirm'),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('social.community_leave_confirm'.tr()),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await runSocialAction(context, () async {
      await ref.read(communityActionsProvider).leave(detail.community.id);
      if (context.mounted && context.canPop()) context.pop();
    });
  }

  Future<void> _regenerate(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    await runSocialAction(context, () async {
      final code = await ref.read(communityActionsProvider).regenerateCode(detail.community.id);
      messenger.showSnackBar(SnackBar(content: Text('social.community_regenerated'.tr(namedArgs: {'code': code}))));
    });
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<String>(
      key: const Key('community_menu'),
      onSelected: (value) => switch (value) {
        'edit' => showCommunityFormSheet(context, editing: detail.community),
        'regenerate' => _regenerate(context, ref),
        'manage' => showManageMembersSheet(context, detail.community.id),
        _ => _leave(context, ref),
      },
      itemBuilder: (context) => [
        if (detail.iAmOwner) ...[
          PopupMenuItem(key: const Key('community_edit'), value: 'edit', child: Text('social.community_edit'.tr())),
          PopupMenuItem(
            key: const Key('community_regenerate'),
            value: 'regenerate',
            child: Text('social.community_regenerate'.tr()),
          ),
          PopupMenuItem(
            key: const Key('community_manage'),
            value: 'manage',
            child: Text('social.community_manage'.tr()),
          ),
        ],
        PopupMenuItem(key: const Key('community_leave'), value: 'leave', child: Text('social.community_leave'.tr())),
      ],
    );
  }
}
