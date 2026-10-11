import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_fonts.dart';
import '../../../shared/text_case.dart';
import '../../../shared/widgets/section_header.dart';
import '../../workout/application/session_providers.dart';
import '../application/challenge_providers.dart';
import '../domain/challenge.dart';
import '../domain/challenge_results.dart';
import '../domain/public_profile.dart';
import 'widgets/challenge_cards.dart';
import 'widgets/challenge_labels.dart';
import 'widgets/social_avatar.dart';

/// Meydan okuma sayfası (S3 spec §7.4).
class ChallengeScreen extends ConsumerWidget {
  const ChallengeScreen({super.key, required this.challengeId});

  final String challengeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = challengeDetailProvider(challengeId);
    final async = ref.watch(provider);
    final current = async.value;
    return Scaffold(
      key: const Key('challenge_screen'),
      appBar: AppBar(
        title: Text(
          upperCaseFor('challenge.title'.tr(), context.locale.languageCode),
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
        ),
        actions: [if (current != null) _ChallengeMenu(detail: current)],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(
          child: TextButton(
            key: const Key('challenge_retry'),
            onPressed: () => ref.invalidate(provider),
            child: Text('social.retry'.tr()),
          ),
        ),
        data: (detail) => detail == null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text('challenge.gone'.tr(), key: const Key('challenge_gone'), textAlign: TextAlign.center),
                ),
              )
            : RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(provider);
                  await ref.read(provider.future);
                },
                child: _ChallengeBody(detail: detail),
              ),
      ),
    );
  }
}

class _ChallengeBody extends ConsumerWidget {
  const _ChallengeBody({required this.detail});

  final ChallengeDetail detail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final muted = TextStyle(color: scheme.onSurfaceVariant);
    final challenge = detail.challenge;
    final now = ref.read(nowProvider)();
    final state = challenge.state(now);
    final names = {for (final MapEntry(key: id, value: p) in detail.profiles.entries) id: p.displayName};
    final rows = challengeStandings(challenge, detail.participants, names: names);
    final winners = challengeWinners(challenge, detail.participants, now);
    final pending = [
      for (final p in detail.participants)
        if (p.status == ChallengeStatus.invited) names[p.userId] ?? '?',
    ];
    final mine = detail.mine;
    final open = state == ChallengeState.upcoming || state == ChallengeState.active;
    final actions = ref.read(challengeActionsProvider);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        _Header(detail: detail, now: now),
        if (state == ChallengeState.finished)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              challengeResultLabel(challenge, detail.participants, detail.myId, now),
              key: const Key('challenge_result'),
              style: theme.textTheme.titleMedium?.copyWith(color: scheme.primary, fontWeight: FontWeight.w800),
            ),
          ),
        SectionHeader('challenge.standings'.tr(), trailing: '${rows.length}'),
        if (rows.isEmpty)
          Text('challenge.standings_empty'.tr(), style: muted)
        else
          for (final row in rows)
            _StandingRow(
              row: row,
              challenge: challenge,
              profile: detail.profiles[row.userId],
              isMe: row.userId == detail.myId,
              isWinner: winners.contains(row.userId),
            ),
        if (pending.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'challenge.pending'.tr(namedArgs: {'names': pending.join(', ')}),
              key: const Key('challenge_pending'),
              style: muted,
            ),
          ),
        const SizedBox(height: 16),
        Card(
          key: const Key('challenge_reward'),
          margin: EdgeInsets.zero,
          child: ListTile(
            leading: Icon(Icons.emoji_events, color: scheme.primary),
            title: Text(
              (challenge.kind == ChallengeKind.race ? 'challenge.reward_race' : 'challenge.reward_goal')
                  .tr(namedArgs: {'xp': '${challengeRewardXp(challenge.kind)}'}),
            ),
            subtitle: Text('challenge.reward_title'.tr()),
          ),
        ),
        if (mine?.status == ChallengeStatus.invited && open) ...[
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  key: const Key('challenge_screen_accept'),
                  onPressed: () => runChallengeAction(context, () => actions.respond(challenge, accept: true)),
                  child: Text('challenge.accept'.tr()),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  key: const Key('challenge_screen_decline'),
                  onPressed: () => runChallengeAction(context, () => actions.respond(challenge, accept: false)),
                  child: Text('challenge.decline'.tr()),
                ),
              ),
            ],
          ),
        ],
        if (challenge.isCommunity && mine?.status != ChallengeStatus.joined && open) ...[
          const SizedBox(height: 16),
          FilledButton(
            key: const Key('challenge_join'),
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            onPressed: () => runChallengeAction(context, () => actions.join(challenge)),
            child: Text('challenge.join'.tr()),
          ),
        ],
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.detail, required this.now});

  final ChallengeDetail detail;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final muted = TextStyle(color: scheme.onSurfaceVariant);
    final challenge = detail.challenge;
    final joined = detail.participants.where((p) => p.status == ChallengeStatus.joined).length;
    return Card(
      key: const Key('challenge_header'),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              challenge.name,
              style: theme.textTheme.headlineSmall?.copyWith(fontFamily: AppFonts.heading, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            ChallengeChips(challenge: challenge),
            if (detail.community case final community?)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    Icon(Icons.groups, size: 18, color: scheme.primary),
                    const SizedBox(width: 6),
                    Expanded(child: Text(community.name, overflow: TextOverflow.ellipsis)),
                  ],
                ),
              ),
            const SizedBox(height: 8),
            Text('${challengeDateLabel(challenge.startsAt)} – ${challengeDateLabel(challenge.endsAt)}', style: muted),
            Text(
              challengeTimeLabel(challenge, now),
              key: const Key('challenge_time'),
              style: TextStyle(color: scheme.primary, fontWeight: FontWeight.w800),
            ),
            if (challenge.kind == ChallengeKind.goal)
              Text('challenge.target'.tr(namedArgs: {
                'value': challengeValueLabel(challenge.metric, challenge.target ?? 0),
              })),
            const SizedBox(height: 4),
            Text(
              'challenge.participants_by'.tr(namedArgs: {
                'n': '$joined',
                'name': detail.profiles[challenge.creator]?.displayName ?? '?',
              }),
              style: muted,
            ),
          ],
        ),
      ),
    );
  }
}

class _StandingRow extends StatelessWidget {
  const _StandingRow({
    required this.row,
    required this.challenge,
    required this.profile,
    required this.isMe,
    required this.isWinner,
  });

  final ChallengeStanding row;
  final Challenge challenge;
  final PublicProfile? profile;
  final bool isMe;
  final bool isWinner;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final goal = challenge.kind == ChallengeKind.goal;
    return Container(
      key: Key('challenge_standing_${row.userId}'),
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isMe ? scheme.primary : scheme.outlineVariant),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Text('${row.position}', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
          ),
          SocialAvatar(initials: profile?.initials ?? '?', highlighted: isMe, size: 36),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        profile?.displayName ?? '?',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ),
                    if (isMe)
                      Flexible(
                        child: Padding(
                          padding: const EdgeInsets.only(left: 6),
                          child: Text(
                            'challenge.me'.tr(),
                            key: const Key('challenge_standing_me_label'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: scheme.primary, fontWeight: FontWeight.w800),
                          ),
                        ),
                      ),
                  ],
                ),
                if (goal)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: LinearProgressIndicator(
                      value: (row.value / (challenge.target ?? 1)).clamp(0.0, 1.0),
                      minHeight: 4,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (isWinner)
            Padding(padding: const EdgeInsets.only(right: 6), child: Icon(Icons.emoji_events, color: scheme.primary))
          else if (row.reachedGoal)
            Padding(padding: const EdgeInsets.only(right: 6), child: Icon(Icons.check_circle, color: scheme.primary)),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 110),
            child: Text(
              challengeValueLabel(challenge.metric, row.value),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChallengeMenu extends ConsumerWidget {
  const _ChallengeMenu({required this.detail});

  final ChallengeDetail detail;

  Future<bool> _confirm(BuildContext context, String body) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          content: Text(body.tr()),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text('social.cancel'.tr())),
            FilledButton(
              key: const Key('challenge_confirm_ok'),
              onPressed: () => Navigator.of(context).pop(true),
              child: Text('challenge.confirm'.tr()),
            ),
          ],
        ),
      ) ??
      false;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final challenge = detail.challenge;
    final state = challenge.state(ref.read(nowProvider)());
    final canLeave = detail.mine != null && (state == ChallengeState.upcoming || state == ChallengeState.active);
    if (!canLeave && !detail.canDelete) return const SizedBox.shrink();
    final actions = ref.read(challengeActionsProvider);
    return PopupMenuButton<String>(
      key: const Key('challenge_menu'),
      onSelected: (value) async {
        final leave = value == 'leave';
        if (!await _confirm(context, leave ? 'challenge.leave_confirm' : 'challenge.delete_confirm')) return;
        if (!context.mounted) return;
        final done = await runChallengeAction(
          context,
          () => leave ? actions.leave(challenge) : actions.delete(challenge),
        );
        if (done && context.mounted && Navigator.of(context).canPop()) Navigator.of(context).pop();
      },
      itemBuilder: (context) => [
        if (canLeave)
          PopupMenuItem(value: 'leave', key: const Key('challenge_leave'), child: Text('challenge.leave'.tr())),
        if (detail.canDelete)
          PopupMenuItem(value: 'delete', key: const Key('challenge_delete'), child: Text('challenge.delete'.tr())),
      ],
    );
  }
}
