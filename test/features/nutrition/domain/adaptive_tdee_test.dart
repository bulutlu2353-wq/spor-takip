import 'package:flutter_test/flutter_test.dart';
import 'package:spor_takip/features/nutrition/domain/adaptive_tdee.dart';
import 'package:spor_takip/features/nutrition/domain/food_item.dart';
import 'package:spor_takip/features/nutrition/domain/meal.dart';
import 'package:spor_takip/features/nutrition/domain/meal_type.dart';
import 'package:spor_takip/features/onboarding/domain/profile.dart';
import 'package:spor_takip/features/progress/domain/trend.dart';

import '../../progress/fixtures.dart';

void main() {
  // testProfile: erkek, 80 kg, 180 cm, 1996 doğumlu, orta aktivite → bakım 2759 kcal.
  // Koruma 2759; dengeli verme −660 → 2099; dengeli alma +308 → 3067.
  final now = DateTime(2026, 10, 22, 10);
  const maintaining = testProfile;
  final losing = testProfile.copyWith(weightDirection: WeightDirection.lose, pace: Pace.balanced);
  final gaining = testProfile.copyWith(weightDirection: WeightDirection.gain, pace: Pace.balanced);

  /// 1 Ekim'den itibaren [days] gün, her gün bir kayıt.
  List<ValuePoint> weights({int days = 22, double Function(int day)? kg}) =>
      [for (var i = 0; i < days; i++) ValuePoint(DateTime(2026, 10, 1 + i), kg == null ? 80 : kg(i))];

  /// 1–21 Ekim (bugün hariç) her güne [kcal].
  Map<DateTime, double> eating(double Function(int day) kcal) =>
      {for (var i = 0; i < 21; i++) DateTime(2026, 10, 1 + i): kcal(i)};

  CalorieSuggestion? suggest(Profile profile, {List<ValuePoint>? points, Map<DateTime, double> kcal = const {}}) =>
      suggestCalorieAdjustment(profile: profile, weights: points ?? weights(), dailyKcal: kcal, now: now);

  group('weightSlopeKgPerDay', () {
    test('fits a least-squares line', () {
      expect(weightSlopeKgPerDay(weights(days: 21, kg: (i) => 80 - 0.05 * i)), closeTo(-0.05, 1e-9));
    });

    test('needs at least 6 logs spread over 14 calendar days', () {
      expect(weightSlopeKgPerDay(weights(days: 5)), isNull);
      expect(weightSlopeKgPerDay(weights(days: 13)), isNull);
      expect(weightSlopeKgPerDay(weights(days: 14)), 0);
      final sparse = [for (final day in [1, 4, 7, 10, 12, 14]) ValuePoint(DateTime(2026, 10, day), 80.0)];
      expect(weightSlopeKgPerDay(sparse), 0);
    });
  });

  group('suggestionWindowStart', () {
    test('is 21 days back, or the day after the latest target change', () {
      expect(suggestionWindowStart(maintaining, now), DateTime(2026, 10, 1));
      final adjusted = maintaining.copyWith(calorieAdjustedAt: DateTime(2026, 10, 5, 18));
      expect(suggestionWindowStart(adjusted, now), DateTime(2026, 10, 6));
      final both = adjusted.copyWith(goalsChangedAt: DateTime(2026, 10, 7, 8));
      expect(suggestionWindowStart(both, now), DateTime(2026, 10, 8));
      final old = maintaining.copyWith(goalsChangedAt: DateTime(2026, 8, 1));
      expect(suggestionWindowStart(old, now), DateTime(2026, 10, 1));
    });
  });

  test('dailyCalories sums meals per local day', () {
    Meal meal(DateTime at, double kcal) => Meal(
          id: '$at',
          userId: 'user-1',
          mealType: MealType.lunch,
          loggedAt: at,
          items: [FoodItem(name: 'x', grams: 100, calories: kcal)],
        );
    final totals = dailyCalories([
      meal(DateTime(2026, 10, 1, 8), 500),
      meal(DateTime(2026, 10, 1, 20), 700),
      meal(DateTime(2026, 10, 2, 13), 900),
    ]);
    expect(totals, {DateTime(2026, 10, 1): 1200.0, DateTime(2026, 10, 2): 900.0});
  });

  group('suggestCalorieAdjustment', () {
    test('energy balance: eating 2500 at a stable weight lowers maintenance, capped at 250', () {
      final s = suggest(maintaining, kcal: eating((_) => 2500))!;
      expect(s.method, SuggestionMethod.energyBalance);
      expect(s.windowDays, 21);
      expect(s.currentTarget, closeTo(2759, 0.01));
      expect(s.newTarget, closeTo(2509, 0.01));
      expect(s.newAdjustmentKcal, closeTo(-250, 0.01));
      expect(s.observedWeeklyKg, closeTo(0, 1e-9));
      expect(s.expectedWeeklyKg, 0);
      expect(s.newProteinTargetG, closeTo(80 * 2.0, 0.01));
    });

    test('energy balance counts the weight change: gaining 0.14 kg/week on 2500', () {
      final s = suggest(maintaining, points: weights(kg: (i) => 80 + 0.02 * i), kcal: eating((_) => 2500))!;
      expect(s.observedWeeklyKg, closeTo(0.14, 1e-9));
      expect(s.newTarget, closeTo(2509, 0.01));
    });

    test('no suggestion when the difference is under 100 kcal', () {
      expect(suggest(maintaining, kcal: eating((_) => 2700)), isNull);
      expect(suggest(maintaining), isNull); // trend: kilo sabit, hedef koru
    });

    test('weight trend: losing nothing on a 0.6 kg/week goal lowers the target by 250', () {
      final s = suggest(losing)!;
      expect(s.method, SuggestionMethod.weightTrend);
      expect(s.currentTarget, closeTo(2099, 0.01));
      expect(s.newTarget, closeTo(1849, 0.01));
      expect(s.newAdjustmentKcal, closeTo(-250, 0.01));
      expect(s.expectedWeeklyKg, closeTo(-0.6, 1e-9));
    });

    test('weight trend: gaining nothing on a 0.28 kg/week goal raises the target by 250', () {
      final s = suggest(gaining)!;
      expect(s.method, SuggestionMethod.weightTrend);
      expect(s.currentTarget, closeTo(3067, 0.01));
      expect(s.newTarget, closeTo(3317, 0.01));
      expect(s.expectedWeeklyKg, closeTo(0.28, 1e-9));
    });

    test('the adjustment builds on the current one', () {
      final s = suggest(losing.copyWith(calorieAdjustmentKcal: -100))!;
      expect(s.currentTarget, closeTo(1999, 0.01));
      expect(s.newAdjustmentKcal, closeTo(-350, 0.01));
      expect(s.newTarget, closeTo(1749, 0.01));
    });

    test('energy balance needs 70% of the window days logged with at least 800 kcal; today is ignored', () {
      final fourteen = eating((i) => i < 14 ? 2500 : 500);
      expect(suggest(losing, kcal: fourteen)!.method, SuggestionMethod.weightTrend);
      final fifteen = eating((i) => i < 15 ? 2500 : 500);
      expect(suggest(losing, kcal: fifteen)!.method, SuggestionMethod.energyBalance);
      final todayOnly = {...eating((_) => 500), DateTime(2026, 10, 22): 50000.0};
      expect(suggest(losing, kcal: todayOnly)!.method, SuggestionMethod.weightTrend);
    });

    test('no suggestion without enough data or time since the last change', () {
      expect(suggest(losing, points: weights(days: 5)), isNull);
      expect(suggest(losing.copyWith(goalsChangedAt: DateTime(2026, 10, 12, 10))), isNull);
      expect(suggest(losing.copyWith(calorieAdjustedAt: DateTime(2026, 10, 8))), isNull);
      expect(suggest(losing.copyWith(calorieAdjustedAt: DateTime(2026, 10, 7))), isNotNull);
    });

    test('a snooze hides the suggestion until it ends', () {
      expect(suggest(losing.copyWith(calorieSuggestionSnoozedUntil: DateTime(2026, 10, 25))), isNull);
      expect(suggest(losing.copyWith(calorieSuggestionSnoozedUntil: DateTime(2026, 10, 20))), isNotNull);
    });

    test('never suggests below the gender floor', () {
      // Kadın, 50 kg, 160 cm, hareketsiz, yavaş verme → hedef zaten taban 1200.
      final floor = losing.copyWith(
        weightKg: 50,
        heightCm: 160,
        birthYear: 2000,
        gender: Gender.female,
        activityLevel: ActivityLevel.sedentary,
        pace: Pace.slow,
      );
      expect(suggest(floor, points: weights(kg: (_) => 50)), isNull);
    });
  });

  test('apply and snooze write the expected columns', () {
    final s = suggest(losing)!;
    final at = DateTime(2026, 10, 22, 10);
    expect(applySuggestionFields(s, at), {
      'calorie_adjustment_kcal': s.newAdjustmentKcal,
      'calorie_adjusted_at': at.toUtc().toIso8601String(),
      'daily_calorie_target': s.newTarget,
      'daily_protein_target_g': s.newProteinTargetG,
    });
    expect(snoozeSuggestionFields(at), {
      'calorie_suggestion_snoozed_until': DateTime(2026, 10, 29, 10).toUtc().toIso8601String(),
    });
  });
}
