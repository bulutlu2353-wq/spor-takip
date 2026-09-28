import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../application/progress_providers.dart';
import '../../domain/progress_format.dart';
import '../../domain/strength.dart';
import '../../domain/trend.dart';
import 'card_states.dart';

/// Son 90 günde en sık yapılan 3 hareketin tahmini 1RM'i (spec §4.2).
class StrengthCard extends ConsumerWidget {
  const StrengthCard({super.key});

  Widget _row(StrengthSeries series) {
    final change = changeOver30Days(series.valuePoints);
    return ListTile(
      key: Key('strength_row_${series.exerciseId}'),
      contentPadding: EdgeInsets.zero,
      dense: true,
      title: Text(series.exerciseName),
      subtitle: change == null
          ? null
          : Text('progress.change_30d'.tr(namedArgs: {'value': '${formatDelta(change)} kg'})),
      trailing: Text(
        '${formatOneDecimal(series.latest.estimateKg)} kg',
        key: Key('strength_value_${series.exerciseId}'),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final seriesAsync = ref.watch(strengthCardProvider);
    return Card(
      key: const Key('strength_card'),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/home/strength'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ProgressCardHeader(title: 'progress.strength.title'.tr()),
              const SizedBox(height: 8),
              seriesAsync.when(
                loading: () => const CardLoading(),
                error: (error, stackTrace) => CardError(onRetry: () => ref.invalidate(recentSessionsProvider)),
                data: (series) => series.isEmpty
                    ? Text('progress.strength.empty'.tr(), key: const Key('strength_empty'))
                    : Column(children: [for (final s in series) _row(s)]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
