import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../onboarding/domain/tdee_calculator.dart';
import '../../../progress/domain/progress_format.dart';
import '../../domain/card_data.dart';
import '../../domain/chat_models.dart';

String _num(num value) => formatOneDecimal(value.toDouble());

String _macros(double kcal, double protein, double carbs, double fat) =>
    '${_num(kcal)} kcal · P ${_num(protein)} g · C ${_num(carbs)} g · F ${_num(fat)} g';

class TargetsLine extends StatelessWidget {
  const TargetsLine({super.key, required this.targets});

  final TdeeResult targets;

  @override
  Widget build(BuildContext context) {
    return Text(
      'coach.card.new_targets'.tr(namedArgs: {
        'kcal': targets.calorieTarget.round().toString(),
        'protein': targets.proteinTargetG.round().toString(),
      }),
      key: const Key('card_targets'),
      style: Theme.of(context).textTheme.bodySmall,
    );
  }
}

class WeightCardBody extends StatelessWidget {
  const WeightCardBody({super.key, required this.event, this.targets});

  final ChatEvent event;

  /// Yalnız kayıt en yeniyse (profil ve hedefler değişecekse) verilir.
  final TdeeResult? targets;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(formatShortDate(weightDate(event)), style: Theme.of(context).textTheme.bodySmall),
        Text(
          '${_num(weightBefore(event))} → ${_num(weightAfter(event))} kg',
          key: const Key('card_weight_change'),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        if (targets != null) TargetsLine(targets: targets!),
      ],
    );
  }
}

String _fieldValue(String field, Object? value) {
  if (value == null) return '—';
  switch (field) {
    case 'activity_level':
      return 'onboarding.activity_$value'.tr();
    case 'goal':
      return 'onboarding.goal_$value'.tr();
    case 'does_exercise':
      return (value == true ? 'onboarding.yes' : 'onboarding.no').tr();
  }
  return value is num ? _num(value) : value.toString();
}

class ProfileCardBody extends StatelessWidget {
  const ProfileCardBody({super.key, required this.event, this.targets});

  final ChatEvent event;
  final TdeeResult? targets;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final change in profileFieldChanges(event))
          Text(
            '${'coach.field.${change.field}'.tr()}: '
            '${_fieldValue(change.field, change.before)} → ${_fieldValue(change.field, change.after)}',
            key: Key('card_field_${change.field}'),
          ),
        if (targets != null) TargetsLine(targets: targets!),
      ],
    );
  }
}

class MealCardBody extends StatelessWidget {
  const MealCardBody({
    super.key,
    required this.mealType,
    required this.items,
    required this.editable,
    required this.onGramsChanged,
  });

  final String mealType;
  final List<MealCardItem> items;
  final bool editable;

  /// Geçersiz girişte gram null gelir.
  final void Function(int index, double? grams) onGramsChanged;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    double sum(double Function(MealCardItem) of) => round1(items.fold(0, (total, item) => total + of(item)));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('nutrition.meal_type_$mealType'.tr(), style: textTheme.labelLarge),
        for (var i = 0; i < items.length; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(items[i].name)),
                    if (editable)
                      SizedBox(
                        width: 88,
                        child: TextFormField(
                          key: Key('card_meal_grams_$i'),
                          initialValue: _num(items[i].grams),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(isDense: true, suffixText: 'g'),
                          onChanged: (text) {
                            final grams = parseDecimal(text);
                            onGramsChanged(i, grams != null && grams > 0 && grams <= 2000 ? grams : null);
                          },
                        ),
                      )
                    else
                      Text('${_num(items[i].grams)} g'),
                  ],
                ),
                Text(
                  _macros(items[i].calories, items[i].proteinG, items[i].carbsG, items[i].fatG),
                  key: Key('card_meal_macros_$i'),
                  style: textTheme.bodySmall,
                ),
                if (items[i].needsReview)
                  Row(
                    key: Key('card_meal_review_$i'),
                    children: [
                      const Icon(Icons.warning_amber, size: 16),
                      const SizedBox(width: 4),
                      Flexible(child: Text('coach.card.needs_review'.tr(), style: textTheme.bodySmall)),
                    ],
                  ),
              ],
            ),
          ),
        const Divider(height: 12),
        Text(
          '${'coach.card.total'.tr()}: '
          '${_macros(sum((i) => i.calories), sum((i) => i.proteinG), sum((i) => i.carbsG), sum((i) => i.fatG))}',
          key: const Key('card_meal_total'),
          style: textTheme.bodyMedium,
        ),
      ],
    );
  }
}

class SetCardBody extends StatelessWidget {
  const SetCardBody({super.key, required this.event});

  final ChatEvent event;

  @override
  Widget build(BuildContext context) {
    final payload = event.payload;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(payload['exercise_name'] as String, key: const Key('card_set_exercise')),
        Text('coach.card.set_number'.tr(namedArgs: {'n': '${payload['set_number']}'})),
        Text(
          '${_num(payload['weight_kg'] as num)} kg × ${payload['reps']}',
          key: const Key('card_set_value'),
          style: Theme.of(context).textTheme.titleMedium,
        ),
      ],
    );
  }
}

class ProgramCardBody extends StatelessWidget {
  const ProgramCardBody({super.key, required this.event});

  final ChatEvent event;

  @override
  Widget build(BuildContext context) {
    final labels = programChangeLabels(event);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < labels.length; i++) Text(labels[i], key: Key('card_program_change_$i')),
      ],
    );
  }
}
