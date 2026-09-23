import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../domain/food_item.dart';

class FoodItemEditTile extends StatelessWidget {
  const FoodItemEditTile({
    super.key,
    required this.item,
    required this.index,
    required this.onChanged,
    required this.onRemove,
  });

  final FoodItem item;
  final int index;
  final ValueChanged<FoodItem> onChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    key: Key('food_item_name_field_$index'),
                    initialValue: item.name,
                    decoration: InputDecoration(labelText: 'nutrition.item_name_label'.tr()),
                    onChanged: (value) => onChanged(item.copyWith(name: value, needsReview: false)),
                  ),
                ),
                IconButton(
                  key: Key('food_item_remove_button_$index'),
                  icon: const Icon(Icons.delete_outline),
                  tooltip: 'nutrition.item_remove'.tr(),
                  onPressed: onRemove,
                ),
              ],
            ),
            TextFormField(
              key: Key('food_item_grams_field_$index'),
              initialValue: item.grams == 0 ? '' : item.grams.toString(),
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: 'nutrition.item_grams_label'.tr()),
              onChanged: (value) {
                final grams = double.tryParse(value) ?? 0;
                onChanged(item.copyWith(grams: grams, needsReview: false));
              },
            ),
            if (item.needsReview) ...[
              Chip(
                key: Key('food_item_needs_review_badge_$index'),
                label: Text('nutrition.item_needs_review'.tr()),
                backgroundColor: Theme.of(context).colorScheme.errorContainer,
              ),
              TextFormField(
                key: Key('food_item_calories_field_$index'),
                initialValue: item.calories == 0 ? '' : item.calories.toString(),
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Kalori'),
                onChanged: (value) {
                  final calories = double.tryParse(value) ?? 0;
                  onChanged(item.copyWith(calories: calories, needsReview: false));
                },
              ),
              TextFormField(
                key: Key('food_item_protein_field_$index'),
                initialValue: item.proteinG == 0 ? '' : item.proteinG.toString(),
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Protein (g)'),
                onChanged: (value) {
                  final protein = double.tryParse(value) ?? 0;
                  onChanged(item.copyWith(proteinG: protein, needsReview: false));
                },
              ),
              TextFormField(
                key: Key('food_item_carbs_field_$index'),
                initialValue: item.carbsG == 0 ? '' : item.carbsG.toString(),
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Karbonhidrat (g)'),
                onChanged: (value) {
                  final carbs = double.tryParse(value) ?? 0;
                  onChanged(item.copyWith(carbsG: carbs, needsReview: false));
                },
              ),
              TextFormField(
                key: Key('food_item_fat_field_$index'),
                initialValue: item.fatG == 0 ? '' : item.fatG.toString(),
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Yağ (g)'),
                onChanged: (value) {
                  final fat = double.tryParse(value) ?? 0;
                  onChanged(item.copyWith(fatG: fat, needsReview: false));
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}
