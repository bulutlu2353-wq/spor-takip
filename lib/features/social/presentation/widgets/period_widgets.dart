import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_fonts.dart';
import '../../../../shared/text_case.dart';
import '../../../gamification/domain/levels.dart';
import '../../../gamification/presentation/title_names.dart';
import '../../../gamification/presentation/widgets/rank_badge.dart';
import '../../../workout/domain/exercise_taxonomy.dart';
import '../../../workout/domain/muscle_heat.dart';
import '../../domain/period_keys.dart';
import '../../domain/player_stats.dart';
import 'social_avatar.dart';

/// "Haftanın Kanat Şampiyonu", "Ayın Yıldızı" (S2 spec §6.6).
String periodTitleName(PeriodKind kind, String category) {
  if (category == 'xp') return 'social.period_star_${kind.name}'.tr();
  final name = 'gamification.muscle_short.${taxonomySlug(category)}'.tr();
  return 'social.period_title_${kind.name}'.tr(namedArgs: {'name': name});
}

/// "1240 XP" / "14.5 set".
String periodValueLabel(String category, double value) => category == 'xp'
    ? 'social.value_xp'.tr(namedArgs: {'n': '${value.toInt()}'})
    : 'social.value_sets'.tr(namedArgs: {'n': formatSets(value)});

/// "3 gün kaldı" / "12 saat kaldı".
String periodRemainingLabel(PeriodKind kind, DateTime now) {
  final remaining = periodRemaining(kind, now);
  return (remaining.hours ? 'social.period_remaining_hours' : 'social.period_remaining_days')
      .tr(namedArgs: {'n': '${remaining.n}'});
}

String? sharedTitleName(SharedTitle? title) => title == null ? null : titleName(title.asProgress, title.tier);

/// HAFTA / AY seçici; segment etiketlerinin anahtarı `<keyPrefix>_week`, `<keyPrefix>_month`.
class PeriodSwitch extends StatelessWidget {
  const PeriodSwitch({super.key, required this.kind, required this.onChanged, required this.keyPrefix});

  final PeriodKind kind;
  final ValueChanged<PeriodKind> onChanged;
  final String keyPrefix;

  @override
  Widget build(BuildContext context) {
    final lang = context.locale.languageCode;
    return SizedBox(
      width: double.infinity,
      child: SegmentedButton<PeriodKind>(
        showSelectedIcon: false,
        segments: [
          for (final k in PeriodKind.values)
            ButtonSegment(
              value: k,
              label: Text(upperCaseFor('social.period_${k.name}'.tr(), lang), key: Key('${keyPrefix}_${k.name}')),
            ),
        ],
        selected: {kind},
        onSelectionChanged: (selection) => onChanged(selection.first),
      ),
    );
  }
}

/// Unvan satırı: kategori, sahiplerin adları (eşitlikte birden çok), değer.
class TitleLine {
  const TitleLine({required this.category, required this.holders, required this.value});

  final String category;
  final List<String> holders;
  final double value;
}

/// Kupa ikonlu unvan listesi (Stitch: "Geçen haftanın şampiyonları").
class PeriodTitlesList extends StatelessWidget {
  const PeriodTitlesList({super.key, required this.kind, required this.lines});

  final PeriodKind kind;
  final List<TitleLine> lines;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      child: Column(
        children: [
          for (final (i, line) in lines.indexed) ...[
            if (i > 0) Divider(height: 1, color: scheme.outlineVariant),
            Padding(
              key: Key('title_${line.category}'),
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: scheme.primary.withValues(alpha: 0.12),
                      borderRadius: const BorderRadius.all(Radius.circular(8)),
                      border: Border.all(color: scheme.primary.withValues(alpha: 0.7)),
                    ),
                    child: Icon(
                      line.category == 'xp' ? Icons.workspace_premium : Icons.emoji_events,
                      color: scheme.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          periodTitleName(kind, line.category),
                          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        Text(
                          line.holders.join(', '),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: scheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    periodValueLabel(line.category, line.value),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontFamily: AppFonts.heading,
                      fontWeight: FontWeight.w900,
                      color: scheme.primary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class StandingLine {
  const StandingLine({
    required this.userId,
    required this.position,
    required this.name,
    required this.initials,
    required this.level,
    required this.rank,
    required this.xp,
    this.handle,
    this.title,
    this.isMe = false,
  });

  final String userId;
  final int position;
  final String name;
  final String initials;
  final int level;
  final Rank rank;
  final int xp;

  /// Genel sıralamada kullanıcı adı ('@' olmadan).
  final String? handle;

  /// Takılı unvanın adı.
  final String? title;
  final bool isMe;
}

/// Sıra numaralı canlı sıralama; ilk üç lime, benim satırım lime çerçeveli ve etiketli.
class StandingsList extends StatelessWidget {
  const StandingsList({super.key, required this.lines});

  final List<StandingLine> lines;

  @override
  Widget build(BuildContext context) => Column(children: [for (final line in lines) _StandingRow(line: line)]);
}

class _StandingRow extends StatelessWidget {
  const _StandingRow({required this.line});

  final StandingLine line;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final lang = context.locale.languageCode;
    final top = line.position <= 3;
    final first = line.position == 1;
    final muted = theme.textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant);
    return Container(
      key: Key('standing_${line.userId}'),
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: const BorderRadius.all(Radius.circular(12)),
        border: Border.all(
          color: line.isMe ? scheme.primary : scheme.outlineVariant,
          width: line.isMe ? 2 : 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: first ? scheme.primary : null,
              border: Border.all(color: top ? scheme.primary : scheme.outlineVariant, width: 2),
            ),
            child: Text(
              '${line.position}',
              style: TextStyle(
                fontFamily: AppFonts.heading,
                fontWeight: FontWeight.w900,
                color: first ? scheme.onPrimary : scheme.onSurface,
              ),
            ),
          ),
          const SizedBox(width: 10),
          SocialAvatar(initials: line.initials, size: 40, highlighted: line.isMe || top),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (line.isMe)
                  Text(
                    upperCaseFor('social.your_rank'.tr(), lang),
                    key: const Key('standing_me_label'),
                    style: theme.textTheme.labelSmall
                        ?.copyWith(color: scheme.primary, fontWeight: FontWeight.w900, letterSpacing: 1),
                  ),
                Text(
                  line.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                ),
                Row(
                  children: [
                    RankBadge(rank: line.rank, level: line.level, size: 12),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        'gamification.level_short'.tr(namedArgs: {'n': '${line.level}'}),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: muted,
                      ),
                    ),
                    if (line.handle case final handle?) ...[
                      const SizedBox(width: 6),
                      Flexible(child: Text('@$handle', maxLines: 1, overflow: TextOverflow.ellipsis, style: muted)),
                    ],
                  ],
                ),
                if (line.title case final title?)
                  Padding(padding: const EdgeInsets.only(top: 4), child: TitlePill(text: title)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 96),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Text(
                periodValueLabel('xp', line.xp.toDouble()),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontFamily: AppFonts.heading,
                  fontWeight: FontWeight.w900,
                  color: line.isMe || first ? scheme.primary : scheme.onSurface,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
