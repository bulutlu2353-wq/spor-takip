import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

/// Kaydet; kayıt sürerken pasif ve küçük bir yükleniyor göstergesiyle.
class SettingsSaveButton extends StatelessWidget {
  const SettingsSaveButton({super.key, required this.saving, required this.onPressed});

  final bool saving;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: saving ? null : onPressed,
      child: saving
          ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
          : Text('settings.save'.tr()),
    );
  }
}
