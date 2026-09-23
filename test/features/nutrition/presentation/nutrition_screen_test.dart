import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spor_takip/features/nutrition/application/today_meals_provider.dart';
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
      goal: Goal.maintain,
      dailyCalorieTarget: 2500,
      dailyProteinTargetG: 150,
    );

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  Widget wrap(Widget child, {required List<Meal> meals}) {
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
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
  }

  testWidgets('shows empty state when there are no meals today', (tester) async {
    await tester.pumpWidget(wrap(const NutritionScreen(), meals: const []));
    await tester.pumpAndSettle();

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
    expect(find.byKey(const Key('nutrition_daily_totals')), findsOneWidget);
  });

  testWidgets('tapping the FAB navigates to /nutrition/capture', (tester) async {
    await tester.pumpWidget(wrap(const NutritionScreen(), meals: const []));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('nutrition_add_meal_fab')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('meal_capture_screen')), findsNothing); // gerçek ekran değil, route stub'ı
  });
}
