import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../onboarding/application/profile_providers.dart';
import '../../../onboarding/domain/tdee_calculator.dart';
import '../../../progress/application/progress_providers.dart';
import '../../../progress/domain/body_weight_log.dart';
import '../../../workout/application/session_providers.dart';
import '../../application/chat_notifier.dart';
import '../../data/chat_repository.dart';
import '../../domain/card_data.dart';
import '../../domain/chat_models.dart';
import 'card_bodies.dart';

/// Sohbetteki öneri kartı: önce → sonra, Onayla / Vazgeç, Geri al (spec §5.3).
class ConfirmCard extends ConsumerStatefulWidget {
  const ConfirmCard({super.key, required this.event});

  final ChatEvent event;

  @override
  ConsumerState<ConfirmCard> createState() => _ConfirmCardState();
}

class _ConfirmCardState extends ConsumerState<ConfirmCard> {
  static const _icons = {
    ChatTool.logBodyWeight: Icons.monitor_weight_outlined,
    ChatTool.updateProfile: Icons.person_outline,
    ChatTool.setGoal: Icons.flag_outlined,
    ChatTool.createMeal: Icons.restaurant_outlined,
    ChatTool.logSet: Icons.fitness_center_outlined,
    ChatTool.editProgram: Icons.edit_note,
  };

  bool _busy = false;
  bool _undoBlocked = false;
  late List<MealCardItem> _mealItems =
      widget.event.tool == ChatTool.createMeal ? mealItems(widget.event) : const [];
  final Set<int> _invalidGrams = {};

  ChatEvent get _event => widget.event;

  @override
  Widget build(BuildContext context) {
    final event = _event;
    final needsTargets = profileTools.contains(event.tool);
    final profile = needsTargets ? ref.watch(profileProvider).value : null;
    final targets = profile == null ? null : targetsAfter(profile, event, currentYear: ref.read(nowProvider)().year);
    final canApply = !_busy && (!needsTargets || targets != null) && _invalidGrams.isEmpty;

    return Card(
      key: Key('confirm_card_${event.id}'),
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(_icons[event.tool], size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text(event.summary, style: Theme.of(context).textTheme.titleSmall)),
              ],
            ),
            const SizedBox(height: 8),
            _body(targets),
            const SizedBox(height: 8),
            _footer(canApply, targets),
          ],
        ),
      ),
    );
  }

  Widget _body(TdeeResult? targets) {
    final event = _event;
    switch (event.tool) {
      case ChatTool.logBodyWeight:
        final logs = ref.watch(weightLogsProvider).value ?? const <BodyWeightLog>[];
        return WeightCardBody(event: event, targets: isNewestWeight(event, logs) ? targets : null);
      case ChatTool.updateProfile || ChatTool.setGoal:
        return ProfileCardBody(event: event, targets: targets);
      case ChatTool.createMeal:
        return MealCardBody(
          mealType: event.payload['meal_type'] as String,
          items: _mealItems,
          editable: event.status == ChatEventStatus.pending,
          onGramsChanged: _onGramsChanged,
        );
      case ChatTool.logSet:
        return SetCardBody(event: event);
      case ChatTool.editProgram:
        return ProgramCardBody(event: event);
    }
  }

  void _onGramsChanged(int index, double? grams) {
    setState(() {
      if (grams == null) {
        _invalidGrams.add(index);
        return;
      }
      _invalidGrams.remove(index);
      _mealItems = [
        for (var i = 0; i < _mealItems.length; i++) i == index ? _mealItems[i].withGrams(grams) : _mealItems[i],
      ];
    });
  }

  Widget _footer(bool canApply, TdeeResult? targets) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    switch (_event.status) {
      case ChatEventStatus.pending:
        return Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              key: const Key('card_cancel'),
              onPressed: _busy ? null : _cancel,
              child: Text('coach.card.cancel'.tr()),
            ),
            const SizedBox(width: 8),
            FilledButton(
              key: const Key('card_apply'),
              onPressed: canApply ? () => _apply(targets) : null,
              child: Text('coach.card.apply'.tr()),
            ),
          ],
        );
      case ChatEventStatus.applied:
        return Row(
          children: [
            Icon(Icons.check_circle, size: 18, color: theme.colorScheme.primary),
            const SizedBox(width: 4),
            Expanded(
              child: _undoBlocked
                  ? Text('coach.card.modified'.tr(), key: const Key('card_modified'), style: muted)
                  : Text('coach.card.applied'.tr(), key: const Key('card_applied')),
            ),
            TextButton(
              key: const Key('card_undo'),
              onPressed: _busy || _undoBlocked ? null : _undo,
              child: Text('coach.card.undo'.tr()),
            ),
          ],
        );
      case ChatEventStatus.cancelled:
        return Text('coach.card.cancelled'.tr(), key: const Key('card_status_cancelled'), style: muted);
      case ChatEventStatus.undone:
        return Text('coach.card.undone'.tr(), key: const Key('card_status_undone'), style: muted);
      case ChatEventStatus.stale:
        return Text('coach.card.stale'.tr(), key: const Key('card_status_stale'), style: muted);
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } catch (error, stack) {
      debugPrint('ConfirmCard action failed: $error\n$stack');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('coach.card.error'.tr())));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _apply(TdeeResult? targets) => _run(() async {
        final extras = applyExtras(
          targets: targets,
          itemGrams: _event.tool == ChatTool.createMeal ? [for (final item in _mealItems) item.grams] : null,
        );
        await ref.read(chatNotifierProvider.notifier).apply(_event, extras);
      });

  Future<void> _cancel() => _run(() => ref.read(chatNotifierProvider.notifier).cancel(_event));

  Future<void> _undo() => _run(() async {
        final outcome = await ref.read(chatNotifierProvider.notifier).undo(_event);
        if (outcome == UndoOutcome.modified && mounted) setState(() => _undoBlocked = true);
      });
}
