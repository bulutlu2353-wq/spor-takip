import 'package:flutter/material.dart';

/// Filtre çipi: seçiliyken neon dolu, koyu yazılı; değilken temadaki koyu çip.
class AccentChip extends StatelessWidget {
  const AccentChip({super.key, required this.label, required this.selected, required this.onSelected});

  final String label;
  final bool selected;
  final ValueChanged<bool> onSelected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          color: selected ? scheme.onPrimary : scheme.onSurface,
          fontWeight: selected ? FontWeight.w600 : null,
        ),
      ),
      selected: selected,
      showCheckmark: false,
      selectedColor: scheme.primary,
      onSelected: onSelected,
    );
  }
}
