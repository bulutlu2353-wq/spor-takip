import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../onboarding/application/profile_providers.dart';
import '../../onboarding/domain/profile.dart';
import '../application/today_meals_provider.dart';
import '../domain/macro_totals.dart';
import '../domain/meal.dart';
import '../domain/meal_type.dart';

class NutritionScreen extends ConsumerWidget {
  const NutritionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mealsAsync = ref.watch(todayMealsProvider);
    final profileAsync = ref.watch(profileProvider);

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
        data: (meals) => _buildList(context, meals, profileAsync.value),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(child: Text('nutrition.load_error'.tr())),
      ),
    );
  }

  Widget _buildList(BuildContext context, List<Meal> meals, Profile? profile) {
    if (meals.isEmpty) {
      return Center(
        key: const Key('nutrition_empty_state'),
        child: Text('nutrition.no_meals_today'.tr()),
      );
    }

    final totals = sumMealMacros(meals);
    // profile null olabilir (henüz yükleniyor); bu durumda hedefsiz toplam
    // yerine boş bir hedef göstermek yerine 0 hedefle gösteriyoruz ki widget
    // her zaman aynı anahtarla tek bir metin üretsin.
    final calorieTarget = profile?.dailyCalorieTarget ?? 0;
    final proteinTarget = profile?.dailyProteinTargetG ?? 0;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'nutrition.daily_totals_with_target'.tr(namedArgs: {
              'calories': totals.calories.round().toString(),
              'calorieTarget': calorieTarget.round().toString(),
              'protein': totals.proteinG.round().toString(),
              'proteinTarget': proteinTarget.round().toString(),
            }),
            key: const Key('nutrition_daily_totals'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        Expanded(
          child: ListView(
            children: [
              for (final type in MealType.values) ..._buildMealTypeSection(context, type, meals),
            ],
          ),
        ),
      ],
    );
  }

  List<Widget> _buildMealTypeSection(BuildContext context, MealType type, List<Meal> meals) {
    final mealsOfType = meals.where((meal) => meal.mealType == type).toList();
    if (mealsOfType.isEmpty) return const [];
    return [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Text(
          'nutrition.meal_type_${type.name}'.tr(),
          style: Theme.of(context).textTheme.titleSmall,
        ),
      ),
      for (final meal in mealsOfType)
        for (final item in meal.items)
          ListTile(
            title: Text(item.name),
            subtitle: Text('${item.grams.round()} g · ${item.calories.round()} kcal'),
          ),
    ];
  }
}
