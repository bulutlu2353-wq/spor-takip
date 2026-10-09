import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/social_providers.dart';
import '../../domain/username.dart';

enum UsernameStatus { empty, invalid, checking, available, taken }

/// '@' önekli kullanıcı adı alanı; biçimi anında, uygunluğu 400 ms sonra denetler.
/// [currentUsername] (ayarlarda kendi adım) denetimsiz uygun sayılır.
class UsernameField extends ConsumerStatefulWidget {
  const UsernameField({
    super.key,
    required this.controller,
    required this.onStatusChanged,
    this.fieldKey = const Key('social_username_field'),
    this.currentUsername,
    this.forceTaken = false,
  });

  final TextEditingController controller;
  final ValueChanged<UsernameStatus> onStatusChanged;
  final Key fieldKey;
  final String? currentUsername;

  /// Kaydederken benzersizlik hatası geldiyse; metin değişince üst widget sıfırlar.
  final bool forceTaken;

  @override
  ConsumerState<UsernameField> createState() => _UsernameFieldState();
}

class _UsernameFieldState extends ConsumerState<UsernameField> {
  Timer? _debounce;
  UsernameStatus _status = UsernameStatus.empty;
  UsernameProblem? _problem;

  @override
  void initState() {
    super.initState();
    if (widget.controller.text.isNotEmpty) _check(widget.controller.text, notify: false);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  /// [notify] false yalnız initState'te: orada setState çağrılamaz.
  void _set(UsernameStatus status, {bool notify = true}) {
    if (!notify) {
      _status = status;
      return;
    }
    if (mounted) setState(() => _status = status);
    widget.onStatusChanged(status);
  }

  void _check(String raw, {bool notify = true}) {
    _debounce?.cancel();
    final name = normalizeUsername(raw);
    _problem = name.isEmpty ? null : checkUsername(name);
    if (name.isEmpty) return _set(UsernameStatus.empty, notify: notify);
    if (_problem != null) return _set(UsernameStatus.invalid, notify: notify);
    if (name == widget.currentUsername) return _set(UsernameStatus.available, notify: notify);
    _set(UsernameStatus.checking, notify: notify);
    _debounce = Timer(const Duration(milliseconds: 400), () async {
      try {
        final ok = await ref.read(socialRepositoryProvider).usernameAvailable(name);
        if (mounted && normalizeUsername(widget.controller.text) == name) {
          _set(ok ? UsernameStatus.available : UsernameStatus.taken);
        }
      } catch (_) {
        if (mounted) _set(UsernameStatus.empty);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final status = widget.forceTaken ? UsernameStatus.taken : _status;
    final (text, color) = switch (status) {
      UsernameStatus.empty => ('', scheme.onSurfaceVariant),
      UsernameStatus.checking => ('social.username_checking'.tr(), scheme.onSurfaceVariant),
      UsernameStatus.available => ('social.username_available'.tr(), scheme.primary),
      UsernameStatus.taken => ('social.username_taken'.tr(), scheme.error),
      UsernameStatus.invalid => (
          switch (_problem) {
            UsernameProblem.tooShort => 'social.username_too_short',
            UsernameProblem.tooLong => 'social.username_too_long',
            _ => 'social.username_invalid',
          }
              .tr(),
          scheme.error,
        ),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          key: widget.fieldKey,
          controller: widget.controller,
          autocorrect: false,
          enableSuggestions: false,
          decoration: InputDecoration(labelText: 'social.username_label'.tr(), prefixText: '@'),
          onChanged: _check,
        ),
        const SizedBox(height: 4),
        Text(text, key: const Key('social_username_status'), style: TextStyle(color: color)),
      ],
    );
  }
}
