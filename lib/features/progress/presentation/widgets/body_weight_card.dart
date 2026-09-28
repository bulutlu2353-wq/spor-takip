import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../workout/application/session_providers.dart';
import '../../application/progress_providers.dart';
import '../../domain/body_weight_log.dart';
import '../../domain/progress_format.dart';
import '../../domain/trend.dart';
import 'card_states.dart';
import 'progress_line_chart.dart';
import 'weight_log_dialog.dart';

class BodyWeightCard extends ConsumerWidget {
  const BodyWeightCard({super.key});

  Widget _content(BuildContext context, List<BodyWeightLog> logs, DateTime now) {
    if (logs.isEmpty) return Text('progress.weight.empty'.tr(), key: const Key('weight_empty'));
    final points = [for (final log in logs) ValuePoint(log.date, log.weightKg)];
    final change = changeOver30Days(points);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${formatOneDecimal(logs.last.weightKg)} kg',
          key: const Key('weight_latest'),
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        if (change != null)
          Text(
            'progress.change_30d'.tr(namedArgs: {'value': '${formatDelta(change)} kg'}),
            key: const Key('weight_change'),
          ),
        const SizedBox(height: 8),
        ProgressLineChart(points: pointsInRange(points, ChartRange.threeMonths, now), compact: true, height: 60),
      ],
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logsAsync = ref.watch(weightLogsProvider);
    final now = ref.watch(nowProvider)();
    return Card(
      key: const Key('weight_card'),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/home/weight'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ProgressCardHeader(
                title: 'progress.weight.title'.tr(),
                trailing: IconButton(
                  key: const Key('weight_add_button'),
                  tooltip: 'progress.weight.add'.tr(),
                  icon: const Icon(Icons.add),
                  onPressed: () => showWeightLogDialog(context),
                ),
              ),
              logsAsync.when(
                loading: () => const CardLoading(),
                error: (error, stackTrace) => CardError(onRetry: () => ref.invalidate(weightLogsProvider)),
                data: (logs) => _content(context, logs, now),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
