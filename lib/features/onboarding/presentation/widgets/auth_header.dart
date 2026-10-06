import 'package:flutter/material.dart';

import '../../../../core/theme/app_fonts.dart';
import '../../../../shared/text_case.dart';

/// Giriş/kayıt ekranlarının üstü (spec §3.1): neon "S" logosu, büyük harfli
/// uygulama adı (ilk kelime beyaz, kalanı neon) ve slogan.
class AuthHeader extends StatelessWidget {
  const AuthHeader({super.key, required this.title, required this.tagline});

  final String title;
  final String tagline;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final upper = upperCaseFor(title, Localizations.localeOf(context).languageCode);
    final space = upper.indexOf(' ');
    final first = space < 0 ? upper : upper.substring(0, space);
    final rest = space < 0 ? '' : upper.substring(space);
    return Column(
      key: const Key('auth_header'),
      children: [
        Container(
          width: 56,
          height: 56,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: scheme.primary, borderRadius: BorderRadius.circular(16)),
          child: Text(
            'S',
            style: TextStyle(fontFamily: AppFonts.heading, fontWeight: FontWeight.w900, fontSize: 30, color: scheme.onPrimary),
          ),
        ),
        const SizedBox(height: 16),
        Text.rich(
          key: const Key('auth_header_title'),
          TextSpan(
            style: TextStyle(
              fontFamily: AppFonts.heading,
              fontWeight: FontWeight.w900,
              fontSize: 26,
              letterSpacing: 1,
              color: scheme.onSurface,
            ),
            children: [
              TextSpan(text: first),
              if (rest.isNotEmpty) TextSpan(text: rest, style: TextStyle(color: scheme.primary)),
            ],
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 6),
        Text(
          tagline,
          key: const Key('auth_header_tagline'),
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
        ),
      ],
    );
  }
}
