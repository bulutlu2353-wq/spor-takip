import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_fonts.dart';
import '../../../shared/text_case.dart';
import '../application/community_providers.dart';
import '../domain/public_profile.dart';
import 'social_screen.dart';
import 'widgets/social_avatar.dart';

/// Sahip üyeleri çıkarır ya da yasaklar (S2 spec §6.3); kendisi ve sahip için düğme yok.
Future<void> showManageMembersSheet(BuildContext context, String communityId) => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => ManageMembersSheet(communityId: communityId),
    );

class ManageMembersSheet extends ConsumerWidget {
  const ManageMembersSheet({super.key, required this.communityId});

  final String communityId;

  Future<void> _remove(BuildContext context, WidgetRef ref, PublicProfile profile, {required bool ban}) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          (ban ? 'social.manage_ban_title' : 'social.manage_remove_title')
              .tr(namedArgs: {'name': profile.displayName}),
        ),
        content: ban ? Text('social.manage_ban_body'.tr()) : null,
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text('social.cancel'.tr())),
          FilledButton(
            key: const Key('manage_confirm'),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('social.manage_confirm'.tr()),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await runSocialAction(
      context,
      () => ref.read(communityActionsProvider).removeMember(communityId, profile.userId, ban: ban),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(communityDetailProvider(communityId)).value;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    if (detail == null) {
      return const SizedBox(height: 160, child: Center(child: CircularProgressIndicator()));
    }
    return ListView(
      key: const Key('manage_sheet'),
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
      children: [
        Text(
          upperCaseFor('social.manage_title'.tr(), context.locale.languageCode),
          style: theme.textTheme.titleLarge?.copyWith(fontFamily: AppFonts.heading, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 12),
        for (final member in detail.members)
          if (detail.profiles[member.userId] case final profile?)
            Padding(
              key: Key('manage_${member.userId}'),
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SocialAvatar(initials: profile.initials, size: 40, highlighted: member.isOwner),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          profile.displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        Text(
                          '@${profile.username}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: scheme.onSurfaceVariant),
                        ),
                        // Dar ekranda adın yanına sığmaz; altına, gerekirse alt satıra.
                        if (member.userId != detail.myId && !member.isOwner)
                          Wrap(
                            spacing: 8,
                            children: [
                              OutlinedButton(
                                key: Key('manage_remove_${member.userId}'),
                                onPressed: () => _remove(context, ref, profile, ban: false),
                                child: Text('social.manage_remove'.tr()),
                              ),
                              TextButton(
                                key: Key('manage_ban_${member.userId}'),
                                style: TextButton.styleFrom(foregroundColor: scheme.error),
                                onPressed: () => _remove(context, ref, profile, ban: true),
                                child: Text('social.manage_ban'.tr()),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
      ],
    );
  }
}
