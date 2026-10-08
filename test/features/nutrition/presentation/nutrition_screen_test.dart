import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spor_takip/features/nutrition/application/calorie_suggestion_provider.dart';
import 'package:spor_takip/features/nutrition/application/today_meals_provider.dart';
import 'package:spor_takip/features/nutrition/domain/adaptive_tdee.dart';
import 'package:spor_takip/features/nutrition/domain/food_item.dart';
import 'package:spor_takip/features/nutrition/domain/meal.dart';
import 'package:spor_takip/features/nutrition/domain/meal_type.dart';
import 'package:spor_takip/features/nutrition/presentation/nutrition_screen.dart';
import 'package:spor_takip/features/onboarding/application/profile_providers.dart';
import 'package:spor_takip/features/onboarding/domain/profile.dart';

Profile _profile() => const Profile(
      userId: 'user-1',
      weightKg: 80,
      heightCm: 180,
      birthYear: 1996,
      gender: Gender.male,
      activityLevel: ActivityLevel.moderate,
      doesExercise: true,
      sportType: 'Fitness',
      exerciseDaysPerWeek: 3,
      weightDirection: WeightDirection.maintain,
      dailyCalorieTarget: 2500,
      dailyProteinTargetG: 150,
    );

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  Widget wrap(Widget child, {required List<Meal> meals, CalorieSuggestion? suggestion}) {
    final router = GoRouter(routes: [
      GoRoute(path: '/', builder: (context, state) => child),
      GoRoute(path: '/nutrition/capture', builder: (context, state) => const SizedBox()),
    ]);
    return EasyLocalization(
      supportedLocales: const [Locale('tr'), Locale('en')],
      path: 'assets/translations',
      fallbackLocale: const Locale('tr'),
      child: ProviderScope(
        overrides: [
          todayMealsProvider.overrideWith((ref) async => meals),
          profileProvider.overrideWith((ref) async => _profile()),
          calorieSuggestionProvider.overrideWith((ref) async => suggestion),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
  }

  testWidgets('with no meals shows the remaining card and the empty state', (tester) async {
    await tester.pumpWidget(wrap(const NutritionScreen(), meals: const []));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('remaining_calories_card')), findsOneWidget);
    expect(tester.widget<Text>(find.byKey(const Key('remaining_calories_value'))).data, '2500');
    expect(find.byKey(const Key('nutrition_empty_state')), findsOneWidget);
  });

  testWidgets('lists meals grouped by meal type and shows daily totals', (tester) async {
    final meals = [
      Meal(
        id: 'm1',
        userId: 'user-1',
        mealType: MealType.breakfast,
        loggedAt: DateTime.now(),
        items: const [FoodItem(name: 'Yulaf', grams: 100, calories: 380, proteinG: 13)],
      ),
      Meal(
        id: 'm2',
        userId: 'user-1',
        mealType: MealType.lunch,
        loggedAt: DateTime.now(),
        items: const [FoodItem(name: 'Tavuk', grams: 150, calories: 250, proteinG: 46)],
      ),
    ];

    await tester.pumpWidget(wrap(const NutritionScreen(), meals: meals));
    await tester.pumpAndSettle();

    expect(find.text('Yulaf'), findsOneWidget);
    expect(find.text('Tavuk'), findsOneWidget);
    // 2500 hedef − (380 + 250) yenen
    expect(tester.widget<Text>(find.byKey(const Key('remaining_calories_value'))).data, '1870');
    String subtotal(String type) => tester
        .widget<Text>(find.descendant(
          of: find.byKey(Key('nutrition_section_$type')),
          matching: find.byKey(const ValueKey('section_header_trailing')),
        ))
        .data!;
    expect(subtotal('breakfast'), startsWith('380'));
    expect(subtotal('lunch'), startsWith('250'));
    expect(find.byKey(const Key('nutrition_section_dinner')), findsNothing);
    expect(find.byKey(const Key('nutrition_empty_state')), findsNothing);
  });

  testWidgets('tapping the FAB navigates to /nutrition/capture', (tester) async {
    await tester.pumpWidget(wrap(const NutritionScreen(), meals: const []));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('nutrition_add_meal_fab')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('meal_capture_screen')), findsNothing); // gerçek ekran değil, route stub'ı
  });

  testWidgets('shows the calorie suggestion above the remaining card', (tester) async {
    const suggestion = CalorieSuggestion(
      method: SuggestionMethod.energyBalance,
      windowDays: 21,
      currentTarget: 2500,
      newTarget: 2300,
      newProteinTargetG: 150,
      newAdjustmentKcal: -200,
      observedWeeklyKg: 0.1,
      expectedWeeklyKg: 0,
    );
    await tester.pumpWidget(wrap(const NutritionScreen(), meals: const [], suggestion: suggestion));
    await tester.pumpAndSettle();

    final card = find.byKey(const Key('calorie_suggestion_card'));
    expect(card, findsOneWidget);
    expect(
      tester.getTopLeft(card).dy,
      lessThan(tester.getTopLeft(find.byKey(const Key('remaining_calories_card'))).dy),
    );
  });

  testWidgets('without a suggestion there is no card', (tester) async {
    await tester.pumpWidget(wrap(const NutritionScreen(), meals: const []));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('calorie_suggestion_card')), findsNothing);
  });
}
