import 'package:flutter/material.dart';

import '../../core/theme/app_fonts.dart';
import '../text_case.dart';

/// Küçük, büyük harfli, gri bölüm başlığı (spec §4.2).
class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key});

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 8),
      child: Text(
        upperCaseFor(title, Localizations.localeOf(context).languageCode),
        style: theme.textTheme.labelLarge?.copyWith(
          fontFamily: AppFonts.heading,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.2,
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
