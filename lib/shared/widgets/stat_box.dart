import 'package:flutter/material.dart';

import '../../core/theme/app_fonts.dart';
import '../text_case.dart';

/// Dokunulamayan küçük rakam kutusu (R3 spec §3): üstte büyük değer, altta
/// gri büyük harfli etiket. Dokunulan kutu için [StatTile] kullanılır.
class StatBox extends StatelessWidget {
  const StatBox({super.key, required this.label, required this.value, this.valueKey});

  final String label;
  final String value;
  final Key? valueKey;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(color: scheme.surfaceContainer, borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        child: Column(
          children: [
            // Dar ekranda uzun değer (ör. "12500 kg") taşmasın diye küçülür.
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                key: valueKey,
                maxLines: 1,
                style: theme.textTheme.titleLarge?.copyWith(fontFamily: AppFonts.heading, fontWeight: FontWeight.w900),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              upperCaseFor(label, Localizations.localeOf(context).languageCode),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant, letterSpacing: 1),
            ),
          ],
        ),
      ),
    );
  }
}

/// [StatBox]'ları eşit genişlikte, aralarında 8 px boşlukla yan yana dizer.
class StatBoxRow extends StatelessWidget {
  const StatBoxRow({super.key, required this.children});

  final List<StatBox> children;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final (index, box) in children.indexed) ...[
          if (index > 0) const SizedBox(width: 8),
          Expanded(child: box),
        ],
      ],
    );
  }
}
