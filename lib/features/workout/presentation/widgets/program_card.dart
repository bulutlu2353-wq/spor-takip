import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_fonts.dart';
import '../../../../shared/text_case.dart';
import '../../domain/program.dart';

/// "Orta · 4 gün · Rotasyon" — program kartında ve detayında aynı satır.
String programDetails(Program program) {
  final days = program.effectiveDaysPerWeek;
  return [
    if (program.level != null) 'workout.level_${program.level!.name}'.tr(),
    if (days != null) 'workout.days_per_week'.tr(namedArgs: {'count': '$days'}),
    'workout.mode_${program.scheduleMode.name}'.tr(),
  ].join(' · ');
}

/// Neon "AKTİF" etiketi.
class ActiveTag extends StatelessWidget {
  const ActiveTag({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(color: scheme.primary, borderRadius: BorderRadius.circular(6)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        child: Text(
          upperCaseFor('workout.active_badge'.tr(), Localizations.localeOf(context).languageCode),
          style: theme.textTheme.labelSmall?.copyWith(
            color: scheme.onPrimary,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
          ),
        ),
      ),
    );
  }
}

class ProgramCard extends StatelessWidget {
  const ProgramCard({super.key, required this.program, this.isActive = false, this.onTap});

  final Program program;
  final bool isActive;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Card(
        clipBehavior: Clip.antiAlias,
        shape: isActive
            ? RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: scheme.primary, width: 1.5),
              )
            : null,
        child: InkWell(
          key: Key('program_card_${program.id}'),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              program.name,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontFamily: AppFonts.heading,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          if (isActive) ...[
                            const SizedBox(width: 8),
                            const ActiveTag(key: Key('program_card_active_tag')),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        programDetails(program),
                        style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
