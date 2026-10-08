import 'package:flutter/material.dart';

/// Ekipman türü (`equipmentTypes`) → liste ikonu; bilinmeyen/null → dambıl.
IconData equipmentIcon(String? equipment) => switch (equipment) {
      'cable' => Icons.cable,
      'machine' => Icons.precision_manufacturing,
      'body only' => Icons.accessibility_new,
      'bands' => Icons.linear_scale,
      'exercise ball' || 'medicine ball' => Icons.sports_volleyball,
      'foam roll' => Icons.view_week,
      _ => Icons.fitness_center, // barbell, dumbbell, e-z curl bar, kettlebells, other
    };

/// Hareket satırının başındaki yuvarlak ikon (K2 spec §5.1).
class ExerciseIconBadge extends StatelessWidget {
  const ExerciseIconBadge({super.key, required this.equipment});

  final String? equipment;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return CircleAvatar(
      radius: 20,
      backgroundColor: scheme.surfaceContainerHighest,
      child: Icon(equipmentIcon(equipment), size: 20, color: scheme.primary),
    );
  }
}
