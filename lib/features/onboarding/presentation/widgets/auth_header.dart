import 'package:flutter/material.dart';

import '../../../../core/theme/app_fonts.dart';
import '../../../../shared/widgets/app_logo.dart';

/// Giriş/kayıt ekranlarının üstü (G2 spec §9): LevelUp Fit logosu, marka yazısı
/// ("LEVELUP" beyaz + "FIT" neon; dile göre büyütülmez) ve slogan.
class AuthHeader extends StatelessWidget {
  const AuthHeader({super.key, required this.tagline});

  final String tagline;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Column(
      key: const Key('auth_header'),
      children: [
        const AppLogo(key: Key('auth_logo')),
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
              const TextSpan(text: 'LEVELUP'),
              TextSpan(text: ' FIT', style: TextStyle(color: scheme.primary)),
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
