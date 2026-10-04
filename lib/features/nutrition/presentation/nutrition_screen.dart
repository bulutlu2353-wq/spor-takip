import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/day_label.dart';
import '../../../shared/text_case.dart';
import '../../../shared/widgets/section_header.dart';
import '../../onboarding/application/profile_providers.dart';
import '../../onboarding/domain/profile.dart';
import '../../workout/application/session_providers.dart';
import '../application/today_meals_provider.dart';
import '../domain/food_item.dart';
import '../domain/macro_totals.dart';
import '../domain/meal.dart';
import '../domain/meal_type.dart';
import 'widgets/remaining_calories_card.dart';

/// Beslenme ekranı (R2 spec §3): tarih, kalan kalori kartı, öğün tipi başına
/// ara toplamlı kartlar.
class NutritionScreen extends ConsumerWidget {
  const NutritionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mealsAsync = ref.watch(todayMealsProvider);
    // Profil henüz yüklenmediyse kart "hedefsiz" (YENEN) durumunda görünür.
    final profile = ref.watch(profileProvider).value;
    final now = ref.watch(nowProvider)();

    return Scaffold(
      key: const Key('nutrition_screen'),
      appBar: AppBar(title: Text('nutrition.screen_title'.tr())),
      floatingActionButton: FloatingActionButton(
        key: const Key('nutrition_add_meal_fab'),
        tooltip: 'nutrition.add_meal_fab'.tr(),
        onPressed: () => context.push('/nutrition/capture'),
        child: const Icon(Icons.add_a_photo_outlined),
      ),
      body: mealsAsync.when(
        data: (meals) => _NutritionBody(meals: meals, profile: profile, now: now),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(child: Text('nutrition.load_error'.tr())),
      ),
    );
  }
}

class _NutritionBody extends StatelessWidget {
  const _NutritionBody({required this.meals, required this.profile, required this.now});

  final List<Meal> meals;
  final Profile? profile;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return ListView(
      // Alt boşluk: son satır FAB'ın altında kalmasın.
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
      children: [
        Text(
          upperCaseFor(dayLabel(now), context.locale.languageCode),
          key: const Key('nutrition_date'),
          style: theme.textTheme.labelMedium?.copyWith(color: muted, letterSpacing: 1),
        ),
        const SizedBox(height: 12),
        RemainingCaloriesCard(
          eaten: sumMealMacros(meals),
          calorieTarget: profile?.dailyCalorieTarget ?? 0,
          proteinTarget: profile?.dailyProteinTargetG ?? 0,
        ),
        if (meals.isEmpty)
          Padding(
            key: const Key('nutrition_empty_state'),
            padding: const EdgeInsets.only(top: 32),
            child: Column(
              children: [
                Text('nutrition.no_meals_today'.tr(), style: theme.textTheme.titleMedium, textAlign: TextAlign.center),
                const SizedBox(height: 4),
                Text(
                  'nutrition.empty_hint'.tr(),
                  style: theme.textTheme.bodySmall?.copyWith(color: muted),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          )
        else
          for (final type in MealType.values) ..._section(context, type),
      ],
    );
  }

  List<Widget> _section(BuildContext context, MealType type) {
    final mealsOfType = meals.where((meal) => meal.mealType == type).toList();
    if (mealsOfType.isEmpty) return const [];
    final items = [for (final meal in mealsOfType) ...meal.items];
    final subtotal = sumMealMacros(mealsOfType).calories;
    final divider = Theme.of(context).colorScheme.outlineVariant;
    return [
      SectionHeader(
        'nutrition.meal_type_${type.name}'.tr(),
        key: Key('nutrition_section_${type.name}'),
        trailing: '${subtotal.round()} ${'nutrition.kcal'.tr()}',
      ),
      Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Column(
            children: [
              for (var i = 0; i < items.length; i++) ...[
                if (i > 0) Divider(height: 1, color: divider),
                _FoodRow(item: items[i]),
              ],
            ],
          ),
        ),
      ),
    ];
  }
}

class _FoodRow extends StatelessWidget {
  const _FoodRow({required this.item});

  final FoodItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      key: const Key('nutrition_food_row'),
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Flexible(child: Text(item.name, overflow: TextOverflow.ellipsis)),
          const SizedBox(width: 6),
          Text(
            'nutrition.item_grams'.tr(namedArgs: {'grams': '${item.grams.round()}'}),
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const Spacer(),
          Text('${item.calories.round()}', style: theme.textTheme.titleSmall),
        ],
      ),
    );
  }
}
