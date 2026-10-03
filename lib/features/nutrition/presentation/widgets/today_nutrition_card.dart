import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/widgets/macro_bar.dart';
import '../../../../shared/widgets/ring_progress.dart';
import '../../../onboarding/domain/profile.dart';
import '../../../progress/presentation/widgets/card_states.dart';
import '../../application/today_meals_provider.dart';
import '../../domain/macro_totals.dart';

/// Ana sayfa beslenme kartı (spec §5): bugün yenen kalori halkası ve makrolar.
class TodayNutritionCard extends ConsumerWidget {
  const TodayNutritionCard({super.key, required this.profile});

  final Profile profile;

  Widget _content(BuildContext context, MacroTotals totals) {
    final theme = Theme.of(context);
    return Row(
      children: [
        RingProgress(
          value: totals.calories,
          target: profile.dailyCalorieTarget,
          size: 112,
          center: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${totals.calories.round()}',
                key: const Key('today_nutrition_calories'),
                style: theme.textTheme.headlineSmall,
              ),
              Text(
                'home.kcal_of'.tr(namedArgs: {'target': '${profile.dailyCalorieTarget.round()}'}),
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            children: [
              MacroBar(
                key: const Key('today_nutrition_protein'),
                label: 'home.protein'.tr(),
                value: totals.proteinG,
                target: profile.dailyProteinTargetG,
              ),
              const SizedBox(height: 10),
              MacroBar(key: const Key('today_nutrition_carbs'), label: 'home.carbs'.tr(), value: totals.carbsG),
              const SizedBox(height: 10),
              MacroBar(key: const Key('today_nutrition_fat'), label: 'home.fat'.tr(), value: totals.fatG),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mealsAsync = ref.watch(todayMealsProvider);
    return Card(
      key: const Key('today_nutrition_card'),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.go('/nutrition'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: mealsAsync.when(
            loading: () => const SizedBox(height: 112, child: Center(child: CircularProgressIndicator())),
            error: (error, stackTrace) => CardError(onRetry: () => ref.invalidate(todayMealsProvider)),
            data: (meals) => _content(context, sumMealMacros(meals)),
          ),
        ),
      ),
    );
  }
}
