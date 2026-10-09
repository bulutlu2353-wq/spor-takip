import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_fonts.dart';
import '../../../shared/text_case.dart';
import '../../../shared/widgets/section_header.dart';
import '../../gamification/application/gamification_providers.dart';
import '../../gamification/presentation/title_names.dart';
import '../../gamification/presentation/widgets/rank_badge.dart';
import '../application/social_providers.dart';
import '../data/social_repository.dart';
import '../domain/public_profile.dart';
import '../domain/username.dart';
import 'add_friend_sheet.dart';
import 'widgets/social_avatar.dart';
import 'widgets/username_field.dart';

/// Sosyal sekmesi (S1 spec §6.2): kimlik yoksa oluşturma, varsa kart + istekler + arkadaşlar.
class SocialScreen extends ConsumerWidget {
  const SocialScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(myPublicProfileProvider);
    return Scaffold(
      key: const Key('social_screen'),
      appBar: AppBar(
        title: Text(
          upperCaseFor('social.title'.tr(), context.locale.languageCode),
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
        ),
        actions: [
          if (profileAsync.value != null)
            IconButton(
              key: const Key('social_settings_button'),
              icon: const Icon(Icons.settings_outlined),
              tooltip: 'social.settings_title'.tr(),
              onPressed: () => context.push('/social/settings'),
            ),
        ],
      ),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(
          child: TextButton(
            key: const Key('social_retry'),
            onPressed: () => ref.invalidate(myPublicProfileProvider),
            child: Text('social.retry'.tr()),
          ),
        ),
        data: (me) => me == null ? const _CreateProfile() : _Overview(me: me),
      ),
    );
  }
}

/// İşlem hatasını SnackBar'la bildirir.
Future<void> runSocialAction(BuildContext context, Future<void> Function() action) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    await action();
  } catch (e, st) {
    debugPrint('social action failed: $e\n$st');
    messenger.showSnackBar(SnackBar(content: Text('social.action_error'.tr())));
  }
}

class _CreateProfile extends ConsumerStatefulWidget {
  const _CreateProfile();

  @override
  ConsumerState<_CreateProfile> createState() => _CreateProfileState();
}

class _CreateProfileState extends ConsumerState<_CreateProfile> {
  final _username = TextEditingController();
  final _displayName = TextEditingController();
  UsernameStatus _status = UsernameStatus.empty;
  bool _forceTaken = false;
  bool _saving = false;

  @override
  void dispose() {
    _username.dispose();
    _displayName.dispose();
    super.dispose();
  }

  bool get _canCreate =>
      !_saving && !_forceTaken && _status == UsernameStatus.available && _displayName.text.trim().isNotEmpty;

  Future<void> _create() async {
    setState(() => _saving = true);
    try {
      await ref.read(socialActionsProvider).createProfile(
            username: normalizeUsername(_username.text),
            displayName: _displayName.text.trim(),
          );
    } on UsernameTakenException {
      if (mounted) setState(() => _forceTaken = true);
    } catch (e, st) {
      debugPrint('createProfile failed: $e\n$st');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('social.action_error'.tr())));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      key: const Key('social_create'),
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          upperCaseFor('social.create_title'.tr(), context.locale.languageCode),
          style: theme.textTheme.headlineSmall?.copyWith(fontFamily: AppFonts.heading, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 8),
        Text('social.create_body'.tr(), style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
        const SizedBox(height: 20),
        UsernameField(
          controller: _username,
          forceTaken: _forceTaken,
          onStatusChanged: (status) => setState(() {
            _status = status;
            _forceTaken = false;
          }),
        ),
        const SizedBox(height: 12),
        TextField(
          key: const Key('social_display_name_field'),
          controller: _displayName,
          maxLength: 30,
          decoration: InputDecoration(labelText: 'social.display_name_label'.tr()),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 12),
        FilledButton(
          key: const Key('social_create_button'),
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
          onPressed: _canCreate ? _create : null,
          child: Text('social.create'.tr()),
        ),
      ],
    );
  }
}

class _Overview extends ConsumerWidget {
  const _Overview({required this.me});

  final PublicProfile me;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overviewAsync = ref.watch(socialOverviewProvider);
    final scheme = Theme.of(context).colorScheme;
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(friendshipsProvider);
        await ref.read(socialOverviewProvider.future);
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          _MeCard(me: me),
          const SizedBox(height: 12),
          FilledButton.icon(
            key: const Key('social_add_friend'),
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
            icon: const Icon(Icons.person_add_alt_1),
            label: Text('social.add_friend'.tr()),
            onPressed: () => showAddFriendSheet(context),
          ),
          ...overviewAsync.when(
            loading: () => const [
              Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator())),
            ],
            error: (error, stackTrace) => [
              Center(
                child: TextButton(
                  key: const Key('social_overview_retry'),
                  onPressed: () => ref.invalidate(friendshipsProvider),
                  child: Text('social.retry'.tr()),
                ),
              ),
            ],
            data: (overview) => [
              if (overview.incoming.isNotEmpty || overview.outgoing.isNotEmpty) ...[
                SectionHeader(
                  'social.requests_title'.tr(),
                  trailing: '${overview.incoming.length + overview.outgoing.length}',
                ),
                Column(
                  key: const Key('social_requests'),
                  children: [
                    for (final r in overview.incoming) _IncomingRequest(entry: r),
                    for (final r in overview.outgoing) _OutgoingRequest(entry: r),
                  ],
                ),
              ],
              SectionHeader('social.friends_title'.tr(), trailing: '${overview.friends.length}'),
              if (overview.friends.isEmpty)
                Text(
                  'social.friends_empty'.tr(),
                  key: const Key('social_friends_empty'),
                  style: TextStyle(color: scheme.onSurfaceVariant),
                )
              else
                Column(
                  key: const Key('social_friends'),
                  children: [for (final f in overview.friends) _FriendRow(entry: f)],
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MeCard extends ConsumerWidget {
  const _MeCard({required this.me});

  final PublicProfile me;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final summary = ref.watch(playerSummaryProvider).value;
    final lang = context.locale.languageCode;
    return Card(
      key: const Key('social_me_card'),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                SocialAvatar(initials: me.initials, size: 56),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(me.displayName, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                      Text('@${me.username}', style: TextStyle(color: scheme.onSurfaceVariant)),
                      if (summary != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Row(
                            children: [
                              RankBadge(rank: summary.rank, level: summary.progress.level, size: 14),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  'social.level_rank'.tr(namedArgs: {
                                    'n': '${summary.progress.level}',
                                    'rank': upperCaseFor(summary.rank.labelKey.tr(), lang),
                                  }),
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.labelLarge
                                      ?.copyWith(color: scheme.primary, fontWeight: FontWeight.w800),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.all(Radius.circular(12)),
                border: Border.all(color: scheme.outlineVariant),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          upperCaseFor('social.invite_label'.tr(), lang),
                          style: theme.textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant, letterSpacing: 1),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          me.inviteCode,
                          key: const Key('social_invite_code'),
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontFamily: AppFonts.heading,
                            fontWeight: FontWeight.w900,
                            color: scheme.primary,
                            letterSpacing: 3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  OutlinedButton.icon(
                    key: const Key('social_copy_invite'),
                    icon: const Icon(Icons.copy, size: 18),
                    label: Text('social.copy'.tr()),
                    onPressed: () async {
                      final messenger = ScaffoldMessenger.of(context);
                      await Clipboard.setData(
                        ClipboardData(text: 'social.invite_text'.tr(namedArgs: {'code': me.inviteCode})),
                      );
                      messenger.showSnackBar(SnackBar(content: Text('social.copied'.tr())));
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IncomingRequest extends ConsumerWidget {
  const _IncomingRequest({required this.entry});

  final RequestEntry entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = entry.profile.userId;
    final actions = ref.read(socialActionsProvider);
    return Card(
      key: Key('request_$id'),
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Row(
              children: [
                SocialAvatar(initials: entry.profile.initials),
                const SizedBox(width: 12),
                Expanded(child: _NameColumn(profile: entry.profile)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    key: Key('request_decline_$id'),
                    onPressed: () => runSocialAction(context, () => actions.respond(id, accept: false)),
                    child: Text('social.decline'.tr()),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    key: Key('request_accept_$id'),
                    onPressed: () => runSocialAction(context, () => actions.respond(id, accept: true)),
                    child: Text('social.accept'.tr()),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _OutgoingRequest extends ConsumerWidget {
  const _OutgoingRequest({required this.entry});

  final RequestEntry entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = entry.profile.userId;
    final theme = Theme.of(context);
    return Card(
      key: Key('request_$id'),
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            SocialAvatar(initials: entry.profile.initials, highlighted: false),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('social.sent'.tr(), style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
                  Text('@${entry.profile.username}', style: theme.textTheme.titleMedium),
                ],
              ),
            ),
            OutlinedButton(
              key: Key('request_cancel_$id'),
              onPressed: () => runSocialAction(context, () => ref.read(socialActionsProvider).remove(id)),
              child: Text('social.cancel_request'.tr()),
            ),
          ],
        ),
      ),
    );
  }
}

class _NameColumn extends StatelessWidget {
  const _NameColumn({required this.profile});

  final PublicProfile profile;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          profile.displayName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        Text('@${profile.username}', style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
      ],
    );
  }
}

class _FriendRow extends StatelessWidget {
  const _FriendRow({required this.entry});

  final FriendEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final stats = entry.stats;
    final active = stats?.activeTitle;
    return Card(
      key: Key('friend_${entry.profile.userId}'),
      margin: const EdgeInsets.only(bottom: 8),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/social/friend/${entry.profile.userId}'),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              SocialAvatar(initials: entry.profile.initials),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            entry.profile.displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                          ),
                        ),
                        if (stats != null) ...[
                          const SizedBox(width: 8),
                          RankBadge(rank: stats.rank, level: stats.level, size: 14),
                          const SizedBox(width: 4),
                          Text(
                            'gamification.level_short'.tr(namedArgs: {'n': '${stats.level}'}),
                            style: theme.textTheme.labelMedium?.copyWith(color: scheme.onSurfaceVariant),
                          ),
                        ],
                      ],
                    ),
                    Text('@${entry.profile.username}', style: TextStyle(color: scheme.onSurfaceVariant)),
                    if (active != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: TitlePill(text: titleName(active.asProgress, active.tier)),
                      ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}
