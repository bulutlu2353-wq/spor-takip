import 'package:flutter/material.dart';

import '../../../../core/theme/app_fonts.dart';

/// Büyük ortalı sayı girişi + birim (R4b spec §4.3). [onChanged] ayrıştırılan
/// değeri verir; geçersiz metinde null.
class BigNumberField extends StatelessWidget {
  const BigNumberField({
    super.key,
    required this.controller,
    required this.hintText,
    required this.onChanged,
    this.unit,
  });

  final TextEditingController controller;
  final String hintText;
  final ValueChanged<double?> onChanged;
  final String? unit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        SizedBox(
          width: 220,
          child: TextField(
            key: const Key('numeric_step_field'),
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textAlign: TextAlign.center,
            style: const TextStyle(fontFamily: AppFonts.heading, fontWeight: FontWeight.w900, fontSize: 56),
            decoration: InputDecoration.collapsed(
              hintText: hintText,
              hintStyle: theme.textTheme.bodyLarge?.copyWith(color: scheme.onSurfaceVariant),
            ),
            onChanged: (text) => onChanged(double.tryParse(text)),
          ),
        ),
        if (unit != null) ...[
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              unit!,
              key: const Key('numeric_step_unit'),
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleLarge?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
        ],
      ],
    );
  }
}
