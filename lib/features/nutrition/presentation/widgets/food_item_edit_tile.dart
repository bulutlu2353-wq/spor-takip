import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../domain/food_item.dart';

/// Düzenlenebilir alanlar. [keyName] mevcut test anahtarlarıyla aynı
/// (`food_item_<keyName>_field_<index>`); `title` değeri bilerek `name`
/// değil (enum'un `.name` getter'ıyla karışmasın).
enum _Field {
  title('name', 'nutrition.item_name_label'),
  grams('grams', 'nutrition.item_grams_label'),
  calories('calories', 'nutrition.item_calories_label'),
  protein('protein', 'nutrition.item_protein_label'),
  carbs('carbs', 'nutrition.item_carbs_label'),
  fat('fat', 'nutrition.item_fat_label');

  const _Field(this.keyName, this.labelKey);

  final String keyName;
  final String labelKey;
}

/// Düzeltme ekranında bir yemek (R2 spec §4.3): kapalıyken tek satır özet,
/// dokununca tüm alanlar. Açık/kapalı durumu burada tutulur; böylece
/// `needsReview` false olunca alanlar kaybolmaz.
class FoodItemEditTile extends StatefulWidget {
  const FoodItemEditTile({
    super.key,
    required this.item,
    required this.index,
    required this.onChanged,
    required this.onGramsChanged,
    required this.onRemove,
  });

  final FoodItem item;
  final int index;

  /// Ad, kcal veya makro değişimi (makro değişimi `needsReview`'u kapatır).
  final ValueChanged<FoodItem> onChanged;

  /// Gram değişimi; kcal/makro ölçeklemesini çağıran taraf yapar.
  final ValueChanged<double> onGramsChanged;
  final VoidCallback onRemove;

  @override
  State<FoodItemEditTile> createState() => _FoodItemEditTileState();
}

class _FoodItemEditTileState extends State<FoodItemEditTile> {
  late bool _expanded = widget.item.needsReview || widget.item.grams <= 0;
  late final Map<_Field, TextEditingController> _controllers = {
    for (final field in _Field.values) field: TextEditingController(text: _textFor(widget.item, field)),
  };
  final Map<_Field, FocusNode> _focusNodes = {for (final field in _Field.values) field: FocusNode()};

  static String _number(double value) {
    if (value == 0) return '';
    return value == value.roundToDouble() ? value.toInt().toString() : value.toStringAsFixed(1);
  }

  static String _textFor(FoodItem item, _Field field) => switch (field) {
        _Field.title => item.name,
        _Field.grams => _number(item.grams),
        _Field.calories => _number(item.calories),
        _Field.protein => _number(item.proteinG),
        _Field.carbs => _number(item.carbsG),
        _Field.fat => _number(item.fatG),
      };

  @override
  void didUpdateWidget(covariant FoodItemEditTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Dışarıdan gelen değişikliği (gram ölçeklemesi) odakta olmayan alanlara
    // yaz; kullanıcının o an yazdığı alana dokunma (imleç kaçmasın).
    for (final field in _Field.values) {
      if (_focusNodes[field]!.hasFocus) continue;
      final text = _textFor(widget.item, field);
      if (_controllers[field]!.text != text) _controllers[field]!.text = text;
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    for (final node in _focusNodes.values) {
      node.dispose();
    }
    super.dispose();
  }

  void _onFieldChanged(_Field field, String text) {
    final item = widget.item;
    if (field == _Field.title) {
      widget.onChanged(item.copyWith(name: text));
      return;
    }
    final value = double.tryParse(text) ?? 0;
    switch (field) {
      case _Field.grams:
        widget.onGramsChanged(value);
      case _Field.calories:
        widget.onChanged(item.copyWith(calories: value, needsReview: false));
      case _Field.protein:
        widget.onChanged(item.copyWith(proteinG: value, needsReview: false));
      case _Field.carbs:
        widget.onChanged(item.copyWith(carbsG: value, needsReview: false));
      case _Field.fat:
        widget.onChanged(item.copyWith(fatG: value, needsReview: false));
      case _Field.title:
        break;
    }
  }

  Widget _field(_Field field) {
    return TextField(
      key: Key('food_item_${field.keyName}_field_${widget.index}'),
      controller: _controllers[field],
      focusNode: _focusNodes[field],
      keyboardType: field == _Field.title ? TextInputType.text : TextInputType.number,
      decoration: InputDecoration(labelText: field.labelKey.tr(), isDense: true),
      onChanged: (text) => _onFieldChanged(field, text),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final item = widget.item;
    final index = widget.index;
    final muted = scheme.onSurfaceVariant;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            key: Key('food_item_row_$index'),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                item.name.isEmpty ? 'nutrition.new_item'.tr() : item.name,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodyLarge?.copyWith(color: item.name.isEmpty ? muted : null),
                              ),
                            ),
                            if (item.needsReview) ...[
                              const SizedBox(width: 8),
                              Container(
                                key: Key('food_item_needs_review_badge_$index'),
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: scheme.error.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'nutrition.needs_review_short'.tr(),
                                  style: theme.textTheme.labelSmall?.copyWith(color: scheme.error),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        if (item.grams <= 0)
                          Text(
                            'nutrition.grams_hint'.tr(),
                            key: Key('food_item_grams_hint_$index'),
                            style: theme.textTheme.bodySmall?.copyWith(color: scheme.error),
                          )
                        else
                          Text(
                            'nutrition.row_summary'.tr(namedArgs: {
                              'grams': '${item.grams.round()}',
                              'protein': '${item.proteinG.round()}',
                            }),
                            style: theme.textTheme.bodySmall?.copyWith(color: muted),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    item.needsReview ? '—' : '${item.calories.round()}',
                    key: Key('food_item_kcal_$index'),
                    style: theme.textTheme.titleLarge,
                  ),
                  Icon(_expanded ? Icons.expand_less : Icons.expand_more, color: muted),
                ],
              ),
            ),
          ),
          if (_expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(child: _field(_Field.title)),
                      IconButton(
                        key: Key('food_item_remove_button_$index'),
                        icon: const Icon(Icons.delete_outline),
                        tooltip: 'nutrition.item_remove'.tr(),
                        onPressed: widget.onRemove,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _field(_Field.grams),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(child: _field(_Field.calories)),
                      const SizedBox(width: 8),
                      Expanded(child: _field(_Field.protein)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(child: _field(_Field.carbs)),
                      const SizedBox(width: 8),
                      Expanded(child: _field(_Field.fat)),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
