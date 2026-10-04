import 'package:flutter/material.dart';

import '../../core/theme/app_fonts.dart';
import '../text_case.dart';

/// Küçük, büyük harfli, gri bölüm başlığı (spec §4.2); isteğe bağlı sağda
/// normal renkte kısa metin (ör. öğün kalori ara toplamı).
class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.trailing});

  final String title;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.labelLarge?.copyWith(
      fontFamily: AppFonts.heading,
      fontWeight: FontWeight.w800,
      letterSpacing: 1.2,
      color: theme.colorScheme.onSurfaceVariant,
    );
    final trailing = this.trailing;
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(upperCaseFor(title, Localizations.localeOf(context).languageCode), style: style),
          ),
          if (trailing != null)
            Text(
              trailing,
              key: const ValueKey('section_header_trailing'),
              style: style?.copyWith(color: theme.colorScheme.onSurface),
            ),
        ],
      ),
    );
  }
}
