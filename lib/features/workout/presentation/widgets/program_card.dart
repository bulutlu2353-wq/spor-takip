import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../domain/program.dart';

class ProgramCard extends StatelessWidget {
  const ProgramCard({super.key, required this.program, this.isActive = false, this.onTap});

  final Program program;
  final bool isActive;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final days = program.effectiveDaysPerWeek;
    final details = [
      if (program.level != null) 'workout.level_${program.level!.name}'.tr(),
      if (days != null) 'workout.days_per_week'.tr(namedArgs: {'count': '$days'}),
      'workout.mode_${program.scheduleMode.name}'.tr(),
    ];
    return Card(
      child: ListTile(
        key: Key('program_card_${program.id}'),
        leading: Icon(isActive ? Icons.star : Icons.fitness_center_outlined),
        title: Text(program.name),
        subtitle: Text(details.join(' · ')),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
