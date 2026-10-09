import 'package:flutter/material.dart';

import '../../../../core/theme/app_fonts.dart';

/// Baş harfli köşeli avatar; arkadaşlarda lime, diğerlerinde gri çerçeve.
class SocialAvatar extends StatelessWidget {
  const SocialAvatar({super.key, required this.initials, this.highlighted = true, this.size = 48});

  final String initials;
  final bool highlighted;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(size * 0.25),
        border: Border.all(color: highlighted ? scheme.primary : scheme.outlineVariant, width: 2),
      ),
      child: Text(
        initials,
        style: TextStyle(
          fontFamily: AppFonts.heading,
          fontWeight: FontWeight.w900,
          fontSize: size * 0.34,
          color: highlighted ? scheme.onSurface : scheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// Lime çerçeveli küçük unvan hapı.
class TitlePill extends StatelessWidget {
  const TitlePill({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: 0.12),
        borderRadius: const BorderRadius.all(Radius.circular(6)),
        border: Border.all(color: scheme.primary.withValues(alpha: 0.7)),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.labelSmall?.copyWith(color: scheme.primary, fontWeight: FontWeight.w800),
      ),
    );
  }
}
