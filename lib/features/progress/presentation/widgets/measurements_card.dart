import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../application/progress_providers.dart';
import '../../domain/body_measurement.dart';
import '../../domain/progress_format.dart';
import 'card_states.dart';
import 'measurement_form_dialog.dart';

class MeasurementsCard extends ConsumerWidget {
  const MeasurementsCard({super.key});

  /// "Bel 83 (▼ 2)"; önceki değer yoksa fark yazılmaz.
  static String _chipText(MeasurementSite site, double cm, double? change) {
    final base = '${'progress.sites.${site.name}'.tr()} ${formatOneDecimal(cm)}';
    return change == null ? base : '$base (${formatDelta(change)})';
  }

  Widget _content(List<BodyMeasurement> list) {
    if (list.isEmpty) return Text('progress.measurements.empty'.tr(), key: const Key('measurements_empty'));
    final latest = list.last;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'progress.measurements.last'.tr(namedArgs: {'date': formatShortDate(latest.date)}),
          key: const Key('measurements_last'),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final MapEntry(key: site, value: cm) in latest.values.entries)
              Chip(
                key: Key('measurement_chip_${site.name}'),
                label: Text(_chipText(site, cm, measurementChange(list, site))),
              ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final measurementsAsync = ref.watch(measurementsProvider);
    return Card(
      key: const Key('measurements_card'),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/home/measurements'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ProgressCardHeader(
                title: 'progress.measurements.title'.tr(),
                trailing: IconButton(
                  key: const Key('measurement_add_button'),
                  tooltip: 'progress.measurements.add'.tr(),
                  icon: const Icon(Icons.add),
                  onPressed: () => showMeasurementForm(context),
                ),
              ),
              measurementsAsync.when(
                loading: () => const CardLoading(),
                error: (error, stackTrace) => CardError(onRetry: () => ref.invalidate(measurementsProvider)),
                data: _content,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
