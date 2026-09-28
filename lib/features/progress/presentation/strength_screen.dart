import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../workout/application/session_providers.dart';
import '../application/progress_providers.dart';
import '../domain/progress_format.dart';
import '../domain/strength.dart';
import '../domain/trend.dart';
import 'widgets/card_states.dart';
import 'widgets/progress_line_chart.dart';
import 'widgets/range_selector.dart';

class StrengthScreen extends ConsumerStatefulWidget {
  const StrengthScreen({super.key});

  @override
  ConsumerState<StrengthScreen> createState() => _StrengthScreenState();
}

class _StrengthScreenState extends ConsumerState<StrengthScreen> {
  String? _exerciseId;
  ChartRange _range = ChartRange.threeMonths;

  static String _tooltip(StrengthPoint p) => '${formatShortDate(p.date)}\n'
      '${formatOneDecimal(p.weightKg)} kg × ${p.reps}\n'
      '≈ ${formatOneDecimal(p.estimateKg)} kg';

  Widget _content(List<StrengthSeries> all, DateTime now) {
    if (all.isEmpty) {
      return Center(child: Text('progress.strength.empty'.tr(), key: const Key('strength_empty')));
    }
    final selected = all.firstWhere((s) => s.exerciseId == _exerciseId, orElse: () => all.first);
    final points = [for (final p in selected.points) if (isInRange(p.date, _range, now)) p];
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('progress.strength.exercise'.tr(), style: Theme.of(context).textTheme.labelMedium),
        DropdownButton<String>(
          key: const Key('strength_exercise_picker'),
          value: selected.exerciseId,
          isExpanded: true,
          items: [
            for (final s in all)
              DropdownMenuItem(
                value: s.exerciseId,
                child: Text(s.exerciseName, overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: (id) => setState(() => _exerciseId = id),
        ),
        const SizedBox(height: 16),
        RangeSelector(value: _range, onChanged: (range) => setState(() => _range = range)),
        const SizedBox(height: 16),
        ProgressLineChart(
          key: const Key('strength_chart'),
          points: [for (final p in points) ValuePoint(p.date, p.estimateKg)],
          tooltipLabel: (index) => _tooltip(points[index]),
        ),
        const SizedBox(height: 8),
        Text('progress.strength.estimated_note'.tr(), style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final seriesAsync = ref.watch(allStrengthSeriesProvider);
    final now = ref.watch(nowProvider)();
    return Scaffold(
      key: const Key('strength_screen'),
      appBar: AppBar(title: Text('progress.strength.title'.tr())),
      body: seriesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(child: CardError(onRetry: () => ref.invalidate(allSessionsProvider))),
        data: (all) => _content(all, now),
      ),
    );
  }
}
