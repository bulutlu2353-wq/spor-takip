import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../onboarding/domain/profile.dart';

/// Ana sayfanın en üstündeki günlük kalori ve protein hedefi (önceden sayfanın tamamıydı).
class TargetsCard extends StatelessWidget {
  const TargetsCard({super.key, required this.profile});

  final Profile profile;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Card(
      key: const Key('home_targets_card'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('progress.targets.title'.tr(), style: textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              'home.calorie_target'.tr(namedArgs: {'value': profile.dailyCalorieTarget.round().toString()}),
              key: const Key('home_calorie_target'),
              style: textTheme.headlineSmall,
            ),
            Text(
              'home.protein_target'.tr(namedArgs: {'value': profile.dailyProteinTargetG.round().toString()}),
              key: const Key('home_protein_target'),
              style: textTheme.titleMedium,
            ),
          ],
        ),
      ),
    );
  }
}
