import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/widgets/section_header.dart';
import '../../workout/application/session_providers.dart';
import '../application/challenge_providers.dart';
import '../domain/challenge.dart';
import 'create_challenge_sheet.dart';
import 'widgets/challenge_cards.dart';
import 'widgets/challenge_labels.dart';

/// Topluluk sayfasındaki meydan okumalar (S3 spec §7.5): katıldıysam değerim,
/// değilsem "Katıl"; sınır dolmadıysa "Meydan okuma aç".
class CommunityChallengesCard extends ConsumerWidget {
  const CommunityChallengesCard({super.key, required this.communityId});

  final String communityId;

  Future<void> _create(BuildContext context) async {
    final id = await showCreateChallengeSheet(context, communityId: communityId);
    if (id != null && context.mounted) context.push('/social/challenge/$id');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = ref.watch(communityChallengesProvider(communityId)).value ?? const <ChallengeEntry>[];
    final muted = TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant);
    final now = ref.read(nowProvider)();
    final actions = ref.read(challengeActionsProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader('challenge.community_title'.tr(), key: const Key('community_challenges'), trailing: '${entries.length}'),
        if (entries.isEmpty)
          Text('challenge.community_empty'.tr(), key: const Key('community_challenges_empty'), style: muted)
        else
          for (final entry in entries)
            ChallengeCompactRow(
              entry: entry,
              now: now,
              trailing: entry.mine?.status == ChallengeStatus.joined
                  ? Text(challengeValueLabel(entry.challenge.metric, entry.mine!.progress))
                  : TextButton(
                      key: Key('community_challenge_join_${entry.challenge.id}'),
                      onPressed: () => runChallengeAction(context, () => actions.join(entry.challenge)),
                      child: Text('challenge.join'.tr()),
                    ),
            ),
        if (entries.length < maxCommunityChallenges)
          TextButton.icon(
            key: const Key('community_challenge_new'),
            icon: const Icon(Icons.add),
            label: Text('challenge.community_new'.tr()),
            onPressed: () => _create(context),
          ),
      ],
    );
  }
}
