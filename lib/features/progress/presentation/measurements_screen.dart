import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/date_label.dart';
import '../../../shared/widgets/accent_chip.dart';
import '../../../shared/widgets/section_header.dart';
import '../../workout/application/session_providers.dart';
import '../application/progress_providers.dart';
import '../domain/body_measurement.dart';
import '../domain/progress_format.dart';
import '../domain/trend.dart';
import 'widgets/card_states.dart';
import 'widgets/chart_card.dart';
import 'widgets/measurement_form_dialog.dart';
import 'widgets/progress_hero.dart';
import 'widgets/progress_line_chart.dart';

class MeasurementsScreen extends ConsumerStatefulWidget {
  const MeasurementsScreen({super.key});

  @override
  ConsumerState<MeasurementsScreen> createState() => _MeasurementsScreenState();
}

class _MeasurementsScreenState extends ConsumerState<MeasurementsScreen> {
  MeasurementSite? _site;
  ChartRange _range = ChartRange.threeMonths;

  static String _summary(BodyMeasurement m) => [
        for (final MapEntry(key: site, value: cm) in m.values.entries)
          '${'progress.sites.${site.name}'.tr()} ${formatOneDecimal(cm)}',
      ].join(' · ');

  Future<void> _delete(BodyMeasurement measurement) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        content: Text('progress.delete_confirm'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text('progress.cancel'.tr()),
          ),
          TextButton(
            key: const Key('confirm_delete_button'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text('progress.delete'.tr()),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(bodyMeasurementRepositoryProvider).deleteMeasurement(measurement.date);
      ref.invalidate(measurementsProvider);
    } catch (e, st) {
      debugPrint('MeasurementsScreen.delete failed: $e\n$st');
      messenger.showSnackBar(SnackBar(content: Text('progress.delete_error'.tr())));
    }
  }

  Widget _content(List<BodyMeasurement> list, DateTime now) {
    if (list.isEmpty) {
      return Center(child: Text('progress.measurements.empty'.tr(), key: const Key('measurements_empty')));
    }
    final sites = [
      for (final site in MeasurementSite.values)
        if (list.any((m) => m.values.containsKey(site))) site,
    ];
    final site = sites.contains(_site) ? _site! : sites.first;
    final points = [
      for (final m in list)
        if (m.values[site] case final cm?) ValuePoint(m.date, cm),
    ];
    final inRange = pointsInRange(points, _range, now);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final s in sites)
              AccentChip(
                key: Key('site_chip_${s.name}'),
                label: 'progress.sites.${s.name}'.tr(),
                selected: s == site,
                onSelected: (_) => setState(() => _site = s),
              ),
          ],
        ),
        const SizedBox(height: 16),
        // Hangi yönün iyi olduğu bölgeye ve amaca bağlı: değişim hep gri.
        ProgressHero(
          label: 'progress.sites.${site.name}'.tr(),
          value: formatOneDecimal(points.last.value),
          unit: 'cm',
          change: rangeChangeLabel(changeInRange(inRange), 'cm', _range),
          valueKey: const Key('measurement_current'),
          changeKey: const Key('measurement_change'),
        ),
        const SizedBox(height: 16),
        ChartCard(
          range: _range,
          onRangeChanged: (range) => setState(() => _range = range),
          chart: ProgressLineChart(key: const Key('measurement_chart'), points: inRange),
        ),
        SectionHeader('progress.records'.tr()),
        Card(
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (final (index, m) in list.reversed.indexed) ...[
                if (index > 0) const Divider(height: 1),
                _row(m, now),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _row(BodyMeasurement m, DateTime now) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final day = formatDbDate(m.date);
    return InkWell(
      key: Key('measurement_row_$day'),
      onTap: () => showMeasurementForm(context, existing: m),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 0, 8),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    shortDateLabel(m.date, now),
                    style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  Text(_summary(m), style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
                ],
              ),
            ),
            IconButton(
              key: Key('measurement_delete_$day'),
              icon: const Icon(Icons.delete_outline),
              color: scheme.onSurfaceVariant,
              tooltip: 'progress.delete'.tr(),
              onPressed: () => _delete(m),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final measurementsAsync = ref.watch(measurementsProvider);
    final now = ref.watch(nowProvider)();
    return Scaffold(
      key: const Key('measurements_screen'),
      appBar: AppBar(title: Text('progress.measurements.title'.tr())),
      floatingActionButton: FloatingActionButton(
        key: const Key('measurements_screen_add'),
        tooltip: 'progress.measurements.add'.tr(),
        onPressed: () => showMeasurementForm(context),
        child: const Icon(Icons.add),
      ),
      body: measurementsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(child: CardError(onRetry: () => ref.invalidate(measurementsProvider))),
        data: (list) => _content(list, now),
      ),
    );
  }
}
