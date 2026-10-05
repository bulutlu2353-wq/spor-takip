import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/date_label.dart';
import '../../../shared/widgets/section_header.dart';
import '../../onboarding/application/profile_providers.dart';
import '../../onboarding/domain/profile.dart';
import '../../workout/application/session_providers.dart';
import '../application/body_weight_service.dart';
import '../application/progress_providers.dart';
import '../data/body_weight_repository.dart';
import '../domain/body_weight_log.dart';
import '../domain/progress_format.dart';
import '../domain/trend.dart';
import 'widgets/card_states.dart';
import 'widgets/chart_card.dart';
import 'widgets/home_stat_grid.dart' show weightChangeIsGood;
import 'widgets/progress_hero.dart';
import 'widgets/progress_line_chart.dart';
import 'widgets/weight_log_dialog.dart';

class WeightScreen extends ConsumerStatefulWidget {
  const WeightScreen({super.key});

  @override
  ConsumerState<WeightScreen> createState() => _WeightScreenState();
}

class _WeightScreenState extends ConsumerState<WeightScreen> {
  ChartRange _range = ChartRange.threeMonths;

  /// Fark kullanıcının amacına göre olumlu mu? Profil yoksa hayır.
  static bool _isGood(double? delta, Goal? goal) =>
      delta != null && goal != null && weightChangeIsGood(delta, goal);

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

  Widget _list(List<BodyWeightLog> logs, DateTime now, Goal? goal) {
    if (logs.isEmpty) {
      return Center(child: Text('progress.weight.empty'.tr(), key: const Key('weight_empty')));
    }
    final points = [for (final log in logs) ValuePoint(log.date, log.weightKg)];
    final inRange = pointsInRange(points, _range, now);
    final change = changeInRange(inRange);
    final canDelete = logs.length > 1;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
      children: [
        ProgressHero(
          label: 'progress.weight.current'.tr(),
          value: formatOneDecimal(logs.last.weightKg),
          unit: 'kg',
          change: rangeChangeLabel(change, 'kg', _range),
          highlight: _isGood(change, goal),
          valueKey: const Key('weight_current'),
          changeKey: const Key('weight_change'),
        ),
        const SizedBox(height: 16),
        ChartCard(
          range: _range,
          onRangeChanged: (range) => setState(() => _range = range),
          chart: ProgressLineChart(key: const Key('weight_chart'), points: inRange),
        ),
        SectionHeader('progress.records'.tr()),
        Card(
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              // Yeniden eskiye; fark bir önceki (daha eski) kayda göre.
              for (var i = logs.length - 1; i >= 0; i--) ...[
                if (i < logs.length - 1) const Divider(height: 1),
                _row(
                  logs[i],
                  delta: i > 0 ? logs[i].weightKg - logs[i - 1].weightKg : null,
                  now: now,
                  goal: goal,
                  canDelete: canDelete,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _row(
    BodyWeightLog log, {
    required double? delta,
    required DateTime now,
    required Goal? goal,
    required bool canDelete,
  }) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final day = formatDbDate(log.date);
    return InkWell(
      key: Key('weight_log_$day'),
      onTap: () => showWeightLogDialog(context, existing: log),
      child: Padding(
        padding: const EdgeInsets.only(left: 16),
        child: Row(
          children: [
            Text(
              '${formatOneDecimal(log.weightKg)} kg',
              style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(width: 12),
            if (delta != null)
              Text(
                formatDelta(delta),
                key: Key('weight_delta_$day'),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: _isGood(delta, goal) ? scheme.primary : scheme.onSurfaceVariant,
                ),
              ),
            const Spacer(),
            Text(
              shortDateLabel(log.date, now),
              style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
            IconButton(
              key: Key('weight_delete_$day'),
              icon: const Icon(Icons.delete_outline),
              color: scheme.onSurfaceVariant,
              tooltip: (canDelete ? 'progress.delete' : 'progress.weight.last_log_hint').tr(),
              onPressed: canDelete ? () => _delete(log) : null,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final logsAsync = ref.watch(weightLogsProvider);
    final goal = ref.watch(profileProvider).value?.goal;
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
        data: (logs) => _list(logs, now, goal),
      ),
    );
  }
}
