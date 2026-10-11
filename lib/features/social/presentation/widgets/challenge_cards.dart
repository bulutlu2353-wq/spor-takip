import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../application/challenge_providers.dart';
import '../../domain/challenge.dart';
import '../../domain/challenge_results.dart';
import '../../domain/public_profile.dart';
import 'challenge_labels.dart';
import 'social_avatar.dart';

void _open(BuildContext context, Challenge challenge) => context.push('/social/challenge/${challenge.id}');

/// Tür · ölçü · kas · süre hapları; satır taşarsa alta sarılır.
class ChallengeChips extends StatelessWidget {
  const ChallengeChips({super.key, required this.challenge});

  final Challenge challenge;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    Widget pill(String text, {bool accent = false}) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: accent ? scheme.primary.withValues(alpha: 0.15) : scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: accent ? scheme.primary : scheme.outlineVariant),
          ),
          child: Text(
            text,
            style: theme.textTheme.labelMedium?.copyWith(
              color: accent ? scheme.primary : scheme.onSurface,
              fontWeight: FontWeight.w700,
            ),
          ),
        );
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        pill('challenge.kind.${challenge.kind.name}'.tr(), accent: true),
        pill(challengeMetricLabel(challenge.metric)),
        if (challenge.muscle case final muscle?) pill(challengeMuscleLabel(muscle)),
        pill('challenge.days'.tr(namedArgs: {'n': '${challenge.days}'})),
      ],
    );
  }
}

/// Davet kartı: açan, ad, haplar, Kabul / Reddet.
class ChallengeInviteCard extends ConsumerWidget {
  const ChallengeInviteCard({super.key, required this.entry, this.creator});

  final ChallengeEntry entry;
  final PublicProfile? creator;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final challenge = entry.challenge;
    final actions = ref.read(challengeActionsProvider);
    return Card(
      key: Key('challenge_invite_card_${challenge.id}'),
      margin: const EdgeInsets.only(bottom: 8),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _open(context, challenge),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  SocialAvatar(initials: creator?.initials ?? '?', size: 40),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'challenge.invited_by'.tr(namedArgs: {'name': creator?.displayName ?? '?'}),
                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(challenge.name, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              ChallengeChips(challenge: challenge),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      key: Key('challenge_accept_${challenge.id}'),
                      onPressed: () => runChallengeAction(context, () => actions.respond(challenge, accept: true)),
                      child: Text('challenge.accept'.tr()),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      key: Key('challenge_decline_${challenge.id}'),
                      onPressed: () => runChallengeAction(context, () => actions.respond(challenge, accept: false)),
                      child: Text('challenge.decline'.tr()),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Aktif kart: yarışta sıram + lider + çubuk, hedefte ilerleme + yüzde.
class ChallengeActiveCard extends StatelessWidget {
  const ChallengeActiveCard({super.key, required this.entry, required this.profiles, required this.now});

  final ChallengeEntry entry;
  final Map<String, PublicProfile> profiles;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final muted = TextStyle(color: scheme.onSurfaceVariant);
    final challenge = entry.challenge;
    final rows = challengeStandings(
      challenge,
      entry.participants,
      names: {for (final MapEntry(key: id, value: p) in profiles.entries) id: p.displayName},
    );
    final mine = rows.where((r) => r.userId == entry.myId).firstOrNull;
    final myValue = mine?.value ?? 0;
    final bar = switch (challenge.kind) {
      ChallengeKind.race => rows.isEmpty || rows.first.value <= 0 ? 0.0 : (myValue / rows.first.value).clamp(0.0, 1.0),
      ChallengeKind.goal => (myValue / (challenge.target ?? 1)).clamp(0.0, 1.0),
    };
    return Card(
      key: Key('challenge_active_${challenge.id}'),
      margin: const EdgeInsets.only(bottom: 8),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _open(context, challenge),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (challenge.isCommunity) ...[
                    Icon(Icons.groups, size: 18, color: scheme.primary),
                    const SizedBox(width: 6),
                  ],
                  Expanded(child: Text('challenge.kind.${challenge.kind.name}'.tr(), style: TextStyle(color: scheme.primary))),
                  Text(challengeTimeLabel(challenge, now), key: Key('challenge_time_${challenge.id}'), style: muted),
                ],
              ),
              const SizedBox(height: 6),
              Text(challenge.name, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              if (challenge.kind == ChallengeKind.race) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      mine == null ? '—' : '${mine.position}.',
                      key: Key('challenge_position_${challenge.id}'),
                      style: theme.textTheme.headlineSmall?.copyWith(color: scheme.primary, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(width: 4),
                    Text('challenge.position_of'.tr(namedArgs: {'n': '${rows.length}'}), style: muted),
                    const Spacer(),
                    Text(
                      challengeValueLabel(challenge.metric, myValue),
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
                if (rows.isNotEmpty && rows.first.userId != entry.myId)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'challenge.leader'.tr(namedArgs: {
                        'name': profiles[rows.first.userId]?.displayName ?? '?',
                        'value': challengeValueLabel(challenge.metric, rows.first.value),
                      }),
                      key: Key('challenge_leader_${challenge.id}'),
                      style: muted,
                    ),
                  ),
              ] else
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'challenge.goal_progress'.tr(namedArgs: {
                          'value': challengeNumber(challenge.metric, myValue),
                          'target': challengeValueLabel(challenge.metric, challenge.target ?? 0),
                        }),
                        key: Key('challenge_goal_${challenge.id}'),
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ),
                    Text('%${(bar * 100).round()}', style: TextStyle(color: scheme.primary, fontWeight: FontWeight.w800)),
                  ],
                ),
              const SizedBox(height: 8),
              LinearProgressIndicator(value: bar, minHeight: 6, borderRadius: BorderRadius.circular(3)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Başlamamış, biten ya da topluluk satırı: ikon, ad, zaman ya da sonuç.
class ChallengeCompactRow extends StatelessWidget {
  const ChallengeCompactRow({super.key, required this.entry, required this.now, this.trailing});

  final ChallengeEntry entry;
  final DateTime now;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final challenge = entry.challenge;
    final state = challenge.state(now);
    final finished = state == ChallengeState.finished;
    final won = finished && challengeWinners(challenge, entry.participants, now).contains(entry.myId);
    return Card(
      key: Key('challenge_item_${challenge.id}'),
      margin: const EdgeInsets.only(bottom: 8),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        onTap: () => _open(context, challenge),
        leading: Icon(
          won
              ? Icons.emoji_events
              : state == ChallengeState.upcoming
                  ? Icons.event
                  : Icons.flag_outlined,
          color: won ? scheme.primary : scheme.onSurfaceVariant,
        ),
        title: Text(challenge.name, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          finished
              ? challengeResultLabel(challenge, entry.participants, entry.myId, now)
              : challengeTimeLabel(challenge, now),
        ),
        trailing: trailing ?? const Icon(Icons.chevron_right),
      ),
    );
  }
}
