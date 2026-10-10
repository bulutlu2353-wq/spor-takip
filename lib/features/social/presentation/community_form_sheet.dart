import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_fonts.dart';
import '../../../shared/text_case.dart';
import '../application/community_providers.dart';
import '../domain/community.dart';

/// Topluluk kurar ([editing] null) ya da düzenler (S2 spec §6.2). Kurulunca yeni kimliği döndürür.
Future<String?> showCommunityFormSheet(BuildContext context, {Community? editing}) => showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => CommunityFormSheet(editing: editing),
    );

class CommunityFormSheet extends ConsumerStatefulWidget {
  const CommunityFormSheet({super.key, this.editing});

  final Community? editing;

  @override
  ConsumerState<CommunityFormSheet> createState() => _CommunityFormSheetState();
}

class _CommunityFormSheetState extends ConsumerState<CommunityFormSheet> {
  late final _name = TextEditingController(text: widget.editing?.name ?? '');
  late final _description = TextEditingController(text: widget.editing?.description ?? '');
  late bool _isPublic = widget.editing?.isPublic ?? true;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  int get _nameLength => _name.text.trim().length;

  bool get _valid => _nameLength >= 3 && _nameLength <= 40;

  Future<void> _save() async {
    final editing = widget.editing;
    final actions = ref.read(communityActionsProvider);
    final navigator = Navigator.of(context);
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      if (editing == null) {
        final id = await actions.create(
          name: _name.text.trim(),
          description: _description.text.trim(),
          isPublic: _isPublic,
        );
        navigator.pop(id);
      } else {
        await actions.update(
          editing.id,
          name: _name.text.trim(),
          description: _description.text.trim(),
          isPublic: _isPublic,
        );
        navigator.pop();
      }
    } on CommunityException catch (e) {
      if (mounted) setState(() => _error = 'social.community_error.${e.code}'.tr());
    } catch (e, st) {
      debugPrint('community form failed: $e\n$st');
      if (mounted) setState(() => _error = 'social.action_error'.tr());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final editing = widget.editing != null;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        key: const Key('community_form'),
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              upperCaseFor(
                (editing ? 'social.community_edit_title' : 'social.community_form_title').tr(),
                context.locale.languageCode,
              ),
              style: theme.textTheme.titleLarge?.copyWith(fontFamily: AppFonts.heading, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 16),
            TextField(
              key: const Key('community_name_field'),
              controller: _name,
              maxLength: 40,
              decoration: InputDecoration(
                labelText: 'social.community_name_label'.tr(),
                errorText: _nameLength > 0 && _nameLength < 3 ? 'social.community_name_short'.tr() : null,
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 8),
            TextField(
              key: const Key('community_description_field'),
              controller: _description,
              maxLength: 200,
              minLines: 1,
              maxLines: 3,
              decoration: InputDecoration(labelText: 'social.community_description_label'.tr()),
            ),
            SwitchListTile(
              key: const Key('community_public_switch'),
              contentPadding: EdgeInsets.zero,
              title: Text('social.community_public'.tr()),
              subtitle: Text('social.community_public_note'.tr()),
              value: _isPublic,
              onChanged: (v) => setState(() => _isPublic = v),
            ),
            if (_error case final error?)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  error,
                  key: const Key('community_form_error'),
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ),
            const SizedBox(height: 12),
            FilledButton(
              key: const Key('community_form_save'),
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
              onPressed: _valid && !_saving ? _save : null,
              child: Text((editing ? 'social.community_form_update' : 'social.community_form_save').tr()),
            ),
          ],
        ),
      ),
    );
  }
}
