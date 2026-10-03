import 'package:flutter/material.dart';

import '../text_case.dart';

/// Ana sayfadaki özet kutusu (spec §4.2): etiket, büyük değer, detay satırı.
/// [value] null ise "—" ve [emptyHint] gösterilir.
class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.label,
    required this.onTap,
    this.value,
    this.detail,
    this.highlight = false,
    this.emptyHint,
  });

  static const double height = 112;

  final String label;
  final VoidCallback onTap;
  final String? value;
  final String? detail;

  /// Detay satırı vurgu renginde (olumlu değişim); boş kutuda yok sayılır.
  final bool highlight;
  final String? emptyHint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final empty = value == null;
    final bottom = empty ? emptyHint : detail;
    return Material(
      color: scheme.surfaceContainer,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: height,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  upperCaseFor(label, Localizations.localeOf(context).languageCode),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant, letterSpacing: 1),
                ),
                const Spacer(),
                Text(
                  value ?? '—',
                  key: const ValueKey('stat_tile_value'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.headlineSmall,
                ),
                if (bottom != null)
                  Text(
                    bottom,
                    key: const ValueKey('stat_tile_detail'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: highlight && !empty ? scheme.primary : scheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Veri yüklenirken [StatTile] yerine duran boş kutu.
class StatTileSkeleton extends StatelessWidget {
  const StatTileSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: StatTile.height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }
}
