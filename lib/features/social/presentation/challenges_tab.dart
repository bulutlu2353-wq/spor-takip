import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/widgets/section_header.dart';
import '../../workout/application/session_providers.dart';
import '../application/challenge_providers.dart';
import '../application/social_providers.dart';
import 'create_challenge_sheet.dart';
import 'widgets/challenge_cards.dart';

/// Meydan okumalar sekmesi (S3 spec §7.2): davetler, aktif, başlamamış, biten.
class ChallengesTab extends ConsumerWidget {
  const ChallengesTab({super.key});

  Future<void> _create(BuildContext context) async {
    final id = await showCreateChallengeSheet(context);
    if (id != null && context.mounted) context.push('/social/challenge/$id');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(myChallengesProvider);
    final friends = ref.watch(socialOverviewProvider).value?.friends;
    final hasFriends = friends?.isNotEmpty ?? false;
    final muted = TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant);
    final now = ref.read(nowProvider)();
    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(myChallengesProvider);
            await ref.read(myChallengesProvider.future);
          },
          child: ListView(
            key: const Key('challenges_tab'),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
            children: async.when(
              loading: () => const [
                Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator())),
              ],
              error: (error, stackTrace) => [
                Center(
                  child: TextButton(
                    key: const Key('challenges_retry'),
                    onPressed: () => ref.invalidate(myChallengesProvider),
                    child: Text('social.retry'.tr()),
                  ),
                ),
              ],
              data: (mine) => [
                if (mine.invites.isNotEmpty) ...[
                  SectionHeader('challenge.invites'.tr(), trailing: '${mine.invites.length}'),
                  for (final entry in mine.invites)
                    ChallengeInviteCard(entry: entry, creator: mine.profiles[entry.challenge.creator]),
                ],
                SectionHeader('challenge.active'.tr(), trailing: '${mine.active.length}'),
                if (mine.active.isEmpty)
                  Text('challenge.active_empty'.tr(), key: const Key('challenges_active_empty'), style: muted)
                else
                  for (final entry in mine.active) ChallengeActiveCard(entry: entry, profiles: mine.profiles, now: now),
                if (mine.upcoming.isNotEmpty) ...[
                  SectionHeader('challenge.upcoming'.tr()),
                  for (final entry in mine.upcoming) ChallengeCompactRow(entry: entry, now: now),
                ],
                if (mine.finished.isNotEmpty) ...[
                  SectionHeader('challenge.finished'.tr()),
                  for (final entry in mine.finished) ChallengeCompactRow(entry: entry, now: now),
                ],
                if (friends != null && friends.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Text('challenge.need_friends'.tr(), key: const Key('challenges_need_friends'), style: muted),
                  ),
              ],
            ),
          ),
        ),
        if (hasFriends)
          Positioned(
            right: 16,
            bottom: 16,
            child: FloatingActionButton.extended(
              key: const Key('challenge_new'),
              icon: const Icon(Icons.add),
              label: Text('challenge.new'.tr()),
              onPressed: () => _create(context),
            ),
          ),
      ],
    );
  }
}
