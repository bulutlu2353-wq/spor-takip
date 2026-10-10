import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/section_header.dart';
import '../application/social_providers.dart';
import '../data/social_repository.dart';
import '../domain/public_profile.dart';
import '../domain/username.dart';
import 'social_screen.dart';
import 'widgets/username_field.dart';

/// Görünen ad, kullanıcı adı ve gizlilik anahtarları (S1 spec §6.5).
class SocialSettingsScreen extends ConsumerWidget {
  const SocialSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(myPublicProfileProvider);
    return Scaffold(
      key: const Key('social_settings_screen'),
      appBar: AppBar(title: Text('social.settings_title'.tr())),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(
          child: TextButton(
            onPressed: () => ref.invalidate(myPublicProfileProvider),
            child: Text('social.retry'.tr()),
          ),
        ),
        data: (me) => me == null ? const SizedBox.shrink() : _SettingsForm(me: me),
      ),
    );
  }
}

class _SettingsForm extends ConsumerStatefulWidget {
  const _SettingsForm({required this.me});

  final PublicProfile me;

  @override
  ConsumerState<_SettingsForm> createState() => _SettingsFormState();
}

class _SettingsFormState extends ConsumerState<_SettingsForm> {
  late final _username = TextEditingController(text: widget.me.username);
  late final _displayName = TextEditingController(text: widget.me.displayName);
  UsernameStatus _status = UsernameStatus.available;
  bool _forceTaken = false;
  bool _saving = false;

  @override
  void dispose() {
    _username.dispose();
    _displayName.dispose();
    super.dispose();
  }

  bool get _canSave =>
      !_saving && !_forceTaken && _status == UsernameStatus.available && _displayName.text.trim().isNotEmpty;

  Future<void> _save() async {
    final username = normalizeUsername(_username.text);
    final displayName = _displayName.text.trim();
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _saving = true);
    try {
      await ref.read(socialActionsProvider).updateProfile(
            username: username == widget.me.username ? null : username,
            displayName: displayName == widget.me.displayName ? null : displayName,
          );
      messenger.showSnackBar(SnackBar(content: Text('social.saved'.tr())));
    } on UsernameTakenException {
      if (mounted) setState(() => _forceTaken = true);
    } catch (e, st) {
      debugPrint('updateProfile failed: $e\n$st');
      messenger.showSnackBar(SnackBar(content: Text('social.action_error'.tr())));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(myPublicProfileProvider).value ?? widget.me;
    final actions = ref.read(socialActionsProvider);
    final scheme = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        TextField(
          key: const Key('settings_display_name'),
          controller: _displayName,
          maxLength: 30,
          decoration: InputDecoration(labelText: 'social.display_name_label'.tr()),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 8),
        UsernameField(
          controller: _username,
          fieldKey: const Key('settings_username'),
          currentUsername: widget.me.username,
          forceTaken: _forceTaken,
          onStatusChanged: (status) => setState(() {
            _status = status;
            _forceTaken = false;
          }),
        ),
        const SizedBox(height: 12),
        FilledButton(
          key: const Key('settings_save'),
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
          onPressed: _canSave ? _save : null,
          child: Text('social.save'.tr()),
        ),
        SectionHeader('social.privacy_title'.tr()),
        SwitchListTile(
          key: const Key('share_weekly'),
          title: Text('social.share_weekly'.tr()),
          value: me.shareWeekly,
          onChanged: (v) => runSocialAction(context, () => actions.updateProfile(shareWeekly: v)),
        ),
        SwitchListTile(
          key: const Key('share_workouts'),
          title: Text('social.share_workouts'.tr()),
          value: me.shareWorkouts,
          onChanged: (v) => runSocialAction(context, () => actions.updateProfile(shareWorkouts: v)),
        ),
        SwitchListTile(
          key: const Key('share_heat'),
          title: Text('social.share_heat'.tr()),
          value: me.shareHeat,
          onChanged: (v) => runSocialAction(context, () => actions.updateProfile(shareHeat: v)),
        ),
        const SizedBox(height: 8),
        Text('social.privacy_note'.tr(), style: TextStyle(color: scheme.onSurfaceVariant)),
        SectionHeader('social.compete_title'.tr()),
        SwitchListTile(
          key: const Key('compete_globally'),
          title: Text('social.compete_globally'.tr()),
          subtitle: Text('social.compete_globally_note'.tr()),
          value: me.competeGlobally,
          onChanged: (v) => runSocialAction(context, () => actions.updateProfile(competeGlobally: v)),
        ),
      ],
    );
  }
}
