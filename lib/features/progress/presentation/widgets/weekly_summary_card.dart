import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_fonts.dart';
import '../../../onboarding/application/profile_providers.dart';
import '../../../onboarding/domain/profile.dart';
import '../../application/progress_providers.dart';
import '../../domain/progress_format.dart';
import '../../domain/weekly_summary.dart';
import 'card_states.dart';

/// `up`: daha fazla antrenman/set/hacim (olumlu artış) → fark vurgu renginde.
typedef _Row = (String key, String label, String current, String previous, String change, bool up);

/// Spec §4.4: bu hafta, geçen hafta ve fark; ayrıntı ekranı yok.
class WeeklySummaryCard extends ConsumerWidget {
  const WeeklySummaryCard({super.key});

  static String _average(double? value) => value == null ? '—' : '${value.round()}';

  /// "2700 · %100"; hedef yoksa yalnızca ortalama.
  static String _withPercent(double? average, double? target) {
    if (average == null || target == null || target <= 0) return _average(average);
    return '${_average(average)} · %${(average / target * 100).round()}';
  }

  static double? _diff(num? current, num? previous) =>
      current == null || previous == null ? null : (current - previous).toDouble();

  static List<_Row> _rows(WeeklySummary summary, Profile? profile) {
    final t = summary.thisWeek;
    final l = summary.lastWeek;
    final calorieTarget = profile?.dailyCalorieTarget;
    final proteinTarget = profile?.dailyProteinTargetG;
    String weight(double? kg) => kg == null ? '—' : formatOneDecimal(kg);
    bool up(num current, num previous) => current > previous;
    return [
      ('workouts', 'progress.weekly.workouts', '${t.workouts}', '${l.workouts}', formatDelta(_diff(t.workouts, l.workouts)), up(t.workouts, l.workouts)),
      ('sets', 'progress.weekly.sets', '${t.sets}', '${l.sets}', formatDelta(_diff(t.sets, l.sets)), up(t.sets, l.sets)),
      (
        'volume',
        'progress.weekly.volume',
        '${t.volumeKg.round()}',
        '${l.volumeKg.round()}',
        formatDelta(_diff(t.volumeKg.round(), l.volumeKg.round())),
        up(t.volumeKg.round(), l.volumeKg.round()),
      ),
      (
        'calories',
        'progress.weekly.calories',
        _withPercent(t.avgCalories, calorieTarget),
        _withPercent(l.avgCalories, calorieTarget),
        formatDelta(_diff(t.avgCalories?.round(), l.avgCalories?.round())),
        false,
      ),
      (
        'protein',
        'progress.weekly.protein',
        _withPercent(t.avgProteinG, proteinTarget),
        _withPercent(l.avgProteinG, proteinTarget),
        formatDelta(_diff(t.avgProteinG?.round(), l.avgProteinG?.round())),
        false,
      ),
      (
        'nutrition_days',
        'progress.weekly.nutrition_days',
        '${t.nutritionDays}',
        '${l.nutritionDays}',
        formatDelta(_diff(t.nutritionDays, l.nutritionDays)),
        false,
      ),
      ('weight', 'progress.weekly.weight', weight(t.lastWeightKg), weight(l.lastWeightKg), formatDelta(summary.weightChangeKg), false),
    ];
  }

  Widget _content(BuildContext context, WeeklySummary summary, Profile? profile) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final small = theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant);
    final value = theme.textTheme.titleSmall?.copyWith(fontFamily: AppFonts.heading, fontWeight: FontWeight.w800);
    final header = ProgressCardHeader(title: 'progress.weekly.title'.tr());
    if (summary.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          header,
          const SizedBox(height: 8),
          Text('progress.weekly.empty'.tr(), key: const Key('weekly_empty')),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        header,
        Text('progress.weekly.so_far'.tr(), style: small),
        const SizedBox(height: 8),
        Table(
          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
          columnWidths: const {
            0: FlexColumnWidth(2),
            1: FlexColumnWidth(1.5),
            2: FlexColumnWidth(1.5),
            3: FlexColumnWidth(1.1),
          },
          children: [
            TableRow(children: [
              const SizedBox.shrink(),
              for (final column in const ['this_week', 'last_week', 'change'])
                Text('progress.weekly.$column'.tr(), textAlign: TextAlign.end, style: small),
            ]),
            for (final (key, label, current, previous, change, up) in _rows(summary, profile))
              TableRow(children: [
                Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Text(label.tr(), style: small)),
                Text(current, key: Key('weekly_${key}_this'), textAlign: TextAlign.end, style: value),
                Text(previous, key: Key('weekly_${key}_last'), textAlign: TextAlign.end, style: value),
                Text(
                  change,
                  key: Key('weekly_${key}_change'),
                  textAlign: TextAlign.end,
                  style: small?.copyWith(color: up ? scheme.primary : scheme.onSurfaceVariant),
                ),
              ]),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(weeklySummaryProvider);
    final profile = ref.watch(profileProvider).value;
    return Card(
      key: const Key('weekly_summary_card'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: summaryAsync.when(
          loading: () => const CardLoading(),
          error: (error, stackTrace) => CardError(
            onRetry: () => ref
              ..invalidate(recentSessionsProvider)
              ..invalidate(weeklyMealsProvider)
              ..invalidate(weightLogsProvider),
          ),
          data: (summary) => _content(context, summary, profile),
        ),
      ),
    );
  }
}
