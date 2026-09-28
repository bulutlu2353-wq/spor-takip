import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../workout/application/session_providers.dart';
import '../application/body_weight_service.dart';
import '../application/progress_providers.dart';
import '../data/body_weight_repository.dart';
import '../domain/body_weight_log.dart';
import '../domain/progress_format.dart';
import '../domain/trend.dart';
import 'widgets/card_states.dart';
import 'widgets/progress_line_chart.dart';
import 'widgets/range_selector.dart';
import 'widgets/weight_log_dialog.dart';

class WeightScreen extends ConsumerStatefulWidget {
  const WeightScreen({super.key});

  @override
  ConsumerState<WeightScreen> createState() => _WeightScreenState();
}

class _WeightScreenState extends ConsumerState<WeightScreen> {
  ChartRange _range = ChartRange.threeMonths;

  Future<void> _delete(BodyWeightLog log) async {
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
    String? message;
    try {
      await ref.read(bodyWeightServiceProvider).delete(log.date);
    } on StaleWeightListException {
      message = 'progress.weight.stale';
    } on LastWeightLogException {
      message = 'progress.weight.last_log_hint';
    } catch (e, st) {
      debugPrint('WeightScreen.delete failed: $e\n$st');
      message = 'progress.delete_error';
    }
    if (message != null) messenger.showSnackBar(SnackBar(content: Text(message.tr())));
  }

  Widget _list(List<BodyWeightLog> logs, DateTime now) {
    if (logs.isEmpty) {
      return Center(child: Text('progress.weight.empty'.tr(), key: const Key('weight_empty')));
    }
    final points = [for (final log in logs) ValuePoint(log.date, log.weightKg)];
    final canDelete = logs.length > 1;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
      children: [
        RangeSelector(value: _range, onChanged: (range) => setState(() => _range = range)),
        const SizedBox(height: 16),
        ProgressLineChart(key: const Key('weight_chart'), points: pointsInRange(points, _range, now)),
        const SizedBox(height: 16),
        for (final log in logs.reversed)
          ListTile(
            key: Key('weight_log_${formatDbDate(log.date)}'),
            title: Text('${formatOneDecimal(log.weightKg)} kg'),
            subtitle: Text(formatShortDate(log.date)),
            onTap: () => showWeightLogDialog(context, existing: log),
            trailing: IconButton(
              key: Key('weight_delete_${formatDbDate(log.date)}'),
              icon: const Icon(Icons.delete_outline),
              tooltip: (canDelete ? 'progress.delete' : 'progress.weight.last_log_hint').tr(),
              onPressed: canDelete ? () => _delete(log) : null,
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final logsAsync = ref.watch(weightLogsProvider);
    final now = ref.watch(nowProvider)();
    return Scaffold(
      key: const Key('weight_screen'),
      appBar: AppBar(title: Text('progress.weight.title'.tr())),
      floatingActionButton: FloatingActionButton(
        key: const Key('weight_screen_add'),
        tooltip: 'progress.weight.add'.tr(),
        onPressed: () => showWeightLogDialog(context),
        child: const Icon(Icons.add),
      ),
      body: logsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(child: CardError(onRetry: () => ref.invalidate(weightLogsProvider))),
        data: (logs) => _list(logs, now),
      ),
    );
  }
}
