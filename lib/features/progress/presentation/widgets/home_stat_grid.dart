import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/widgets/stat_tile.dart';
import '../../../onboarding/domain/profile.dart';
import '../../application/progress_providers.dart';
import '../../domain/body_measurement.dart';
import '../../domain/progress_format.dart';
import '../../domain/trend.dart';

/// Kilo değişimi kullanıcının amacına göre olumlu mu?
bool weightChangeIsGood(double change, Goal goal) => switch (goal) {
      Goal.loseWeight => change < 0,
      Goal.gainMuscle => change > 0,
      Goal.maintain => false,
    };

/// Ana sayfada gösterilecek bölge: bel varsa bel, yoksa ilk ölçülen.
MeasurementSite homeMeasurementSite(BodyMeasurement latest) =>
    latest.values.containsKey(MeasurementSite.waist) ? MeasurementSite.waist : latest.values.keys.first;

/// Ana sayfadaki 2×2 özet kutuları (spec §5).
class HomeStatGrid extends StatelessWidget {
  const HomeStatGrid({super.key, required this.profile});

  final Profile profile;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _WeightTile(goal: profile.goal)),
            const SizedBox(width: 12),
            const Expanded(child: _WeekTile()),
          ],
        ),
        const SizedBox(height: 12),
        const Row(
          children: [
            Expanded(child: _StrengthTile()),
            SizedBox(width: 12),
            Expanded(child: _MeasurementTile()),
          ],
        ),
      ],
    );
  }
}

/// Yüklenirken iskelet; hatada "yüklenemedi" ve dokununca yeniden dene.
Widget _asyncTile<T>({
  required Key key,
  required String label,
  required AsyncValue<T> value,
  required VoidCallback onRetry,
  required Widget Function(T data) data,
}) {
  return value.when(
    loading: () => StatTileSkeleton(key: key),
    error: (error, stackTrace) => StatTile(key: key, label: label, emptyHint: 'progress.load_error'.tr(), onTap: onRetry),
    data: data,
  );
}

class _WeightTile extends ConsumerWidget {
  const _WeightTile({required this.goal});

  final Goal goal;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const key = Key('home_tile_weight');
    final label = 'home.tile_weight'.tr();
    void open() => context.push('/home/weight');
    return _asyncTile(
      key: key,
      label: label,
      value: ref.watch(weightLogsProvider),
      onRetry: () => ref.invalidate(weightLogsProvider),
      data: (logs) {
        if (logs.isEmpty) return StatTile(key: key, label: label, emptyHint: 'home.hint_weight'.tr(), onTap: open);
        final change = changeOver30Days([for (final log in logs) ValuePoint(log.date, log.weightKg)]);
        return StatTile(
          key: key,
          label: label,
          value: '${formatOneDecimal(logs.last.weightKg)} kg',
          detail: change == null ? null : 'progress.change_30d'.tr(namedArgs: {'value': '${formatDelta(change)} kg'}),
          highlight: change != null && weightChangeIsGood(change, goal),
          onTap: open,
        );
      },
    );
  }
}

class _WeekTile extends ConsumerWidget {
  const _WeekTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const key = Key('home_tile_week');
    final label = 'home.tile_week'.tr();
    void open() => context.go('/workout/history');
    return _asyncTile(
      key: key,
      label: label,
      value: ref.watch(weeklySummaryProvider),
      onRetry: () => ref.invalidate(weeklySummaryProvider),
      data: (summary) {
        final week = summary.thisWeek;
        if (week.workouts == 0) {
          return StatTile(key: key, label: label, emptyHint: 'home.hint_workout'.tr(), onTap: open);
        }
        return StatTile(
          key: key,
          label: label,
          value: '${week.workouts}',
          detail: 'home.week_sets'.tr(namedArgs: {'count': '${week.sets}'}),
          onTap: open,
        );
      },
    );
  }
}

class _StrengthTile extends ConsumerWidget {
  const _StrengthTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const key = Key('home_tile_strength');
    final label = 'home.tile_strength'.tr();
    void open() => context.push('/home/strength');
    return _asyncTile(
      key: key,
      label: label,
      value: ref.watch(strengthCardProvider),
      onRetry: () => ref.invalidate(recentSessionsProvider),
      data: (series) {
        if (series.isEmpty) return StatTile(key: key, label: label, emptyHint: 'home.hint_strength'.tr(), onTap: open);
        final top = series.first;
        final change = changeOver30Days(top.valuePoints);
        return StatTile(
          key: key,
          label: label,
          value: '${formatOneDecimal(top.latest.estimateKg)} kg',
          detail: change == null ? top.exerciseName : '${top.exerciseName} · ${formatDelta(change)}',
          highlight: change != null && change > 0,
          onTap: open,
        );
      },
    );
  }
}

class _MeasurementTile extends ConsumerWidget {
  const _MeasurementTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const key = Key('home_tile_measurement');
    final label = 'home.tile_measurement'.tr();
    void open() => context.push('/home/measurements');
    return _asyncTile(
      key: key,
      label: label,
      value: ref.watch(measurementsProvider),
      onRetry: () => ref.invalidate(measurementsProvider),
      data: (list) {
        if (list.isEmpty || list.last.values.isEmpty) {
          return StatTile(key: key, label: label, emptyHint: 'home.hint_measurement'.tr(), onTap: open);
        }
        final site = homeMeasurementSite(list.last);
        final change = measurementChange(list, site);
        final siteName = 'progress.sites.${site.name}'.tr();
        return StatTile(
          key: key,
          label: label,
          value: '${formatOneDecimal(list.last.values[site]!)} cm',
          detail: change == null ? siteName : '$siteName · ${formatDelta(change)}',
          highlight: site == MeasurementSite.waist && change != null && change < 0,
          onTap: open,
        );
      },
    );
  }
}
