import '../../onboarding/domain/profile.dart';
import '../../onboarding/domain/tdee_calculator.dart';
import '../../progress/domain/progress_format.dart';
import '../../progress/domain/trend.dart';
import 'macro_totals.dart';
import 'meal.dart';

/// Uyarlanabilir kalori varsayılanları (G3 spec §2).
const suggestionWindowDays = 21;
const _minWindowDays = 14;
const _minWeightLogs = 6;
const _minWeightSpanDays = 13; // ilk–son kayıt arası; 14 takvim günü
const _loggedDayMinKcal = 800.0;
const _energyBalanceMinRatio = 0.7;
const _minSuggestionKcal = 100.0;
const _maxSuggestionKcal = 250.0;
const _snoozeDays = 7;
const _kcalPerKg = 7700.0;

enum SuggestionMethod { energyBalance, weightTrend }

/// Kullanıcıya sunulan hedef düzeltmesi.
class CalorieSuggestion {
  const CalorieSuggestion({
    required this.method,
    required this.windowDays,
    required this.currentTarget,
    required this.newTarget,
    required this.newProteinTargetG,
    required this.newAdjustmentKcal,
    required this.observedWeeklyKg,
    required this.expectedWeeklyKg,
  });

  final SuggestionMethod method;

  /// Değerlendirilen gün sayısı (pencere başı → bugün, bugün hariç).
  final int windowDays;
  final double currentTarget;
  final double newTarget;
  final double newProteinTargetG;
  final double newAdjustmentKcal;

  /// İşaretli: kilo verirken negatif.
  final double observedWeeklyKg;
  final double expectedWeeklyKg;
}

/// Yaz saati geçişlerinde de doğru gün farkı.
int _daysBetween(DateTime from, DateTime to) => (dateOnly(to).difference(dateOnly(from)).inHours / 24).round();

/// Pencerenin ilk günü: 21 gün önce ya da son hedef değişikliğinin ertesi günü (hangisi yeniyse).
DateTime suggestionWindowStart(Profile profile, DateTime now) {
  final today = dateOnly(now);
  var start = DateTime(today.year, today.month, today.day - suggestionWindowDays);
  for (final changed in [profile.calorieAdjustedAt, profile.goalsChangedAt]) {
    if (changed == null) continue;
    final next = DateTime(changed.year, changed.month, changed.day + 1);
    if (next.isAfter(start)) start = next;
  }
  return start;
}

/// Yerel gün → o gün yenen kcal.
Map<DateTime, double> dailyCalories(List<Meal> meals) {
  final totals = <DateTime, double>{};
  for (final meal in meals) {
    final day = dateOnly(meal.loggedAt.toLocal());
    totals[day] = (totals[day] ?? 0) + sumMealMacros([meal]).calories;
  }
  return totals;
}

/// [points] eskiden yeniye; en küçük kareler eğimi (kg/gün). Az veri → null.
double? weightSlopeKgPerDay(List<ValuePoint> points) {
  if (points.length < _minWeightLogs) return null;
  final first = points.first.date;
  if (_daysBetween(first, points.last.date) < _minWeightSpanDays) return null;
  final xs = [for (final p in points) _daysBetween(first, p.date).toDouble()];
  final meanX = xs.reduce((a, b) => a + b) / xs.length;
  final meanY = points.map((p) => p.value).reduce((a, b) => a + b) / points.length;
  var covariance = 0.0;
  var variance = 0.0;
  for (var i = 0; i < points.length; i++) {
    covariance += (xs[i] - meanX) * (points[i].value - meanY);
    variance += (xs[i] - meanX) * (xs[i] - meanX);
  }
  return variance == 0 ? null : covariance / variance;
}

/// G3 spec §4.3. Öneri yoksa (erteleme, az veri, küçük fark) null.
CalorieSuggestion? suggestCalorieAdjustment({
  required Profile profile,
  required List<ValuePoint> weights,
  required Map<DateTime, double> dailyKcal,
  required DateTime now,
  TdeeCalculator calculator = const TdeeCalculator(),
}) {
  final snoozedUntil = profile.calorieSuggestionSnoozedUntil;
  if (snoozedUntil != null && snoozedUntil.isAfter(now)) return null;

  final today = dateOnly(now);
  final start = suggestionWindowStart(profile, now);
  final windowDays = _daysBetween(start, today);
  if (windowDays < _minWindowDays) return null;

  final slope = weightSlopeKgPerDay([
    for (final p in weights)
      if (!p.date.isBefore(start) && !p.date.isAfter(today)) p,
  ]);
  if (slope == null) return null;

  final logged = [
    for (var i = 0; i < windowDays; i++)
      if (dailyKcal[DateTime(start.year, start.month, start.day + i)] case final kcal?
          when kcal >= _loggedDayMinKcal)
        kcal,
  ];
  final method = logged.length >= windowDays * _energyBalanceMinRatio
      ? SuggestionMethod.energyBalance
      : SuggestionMethod.weightTrend;

  TdeeResult targets(double adjustment) => calculator.calculate(
        weightKg: profile.weightKg,
        heightCm: profile.heightCm,
        birthYear: profile.birthYear,
        currentYear: now.year,
        gender: profile.gender,
        activityLevel: profile.activityLevel,
        weightDirection: profile.weightDirection,
        pace: profile.pace,
        focuses: profile.focuses,
        adjustmentKcal: adjustment,
      );

  final weekly = weeklyChangeKg(profile.weightKg, profile.weightDirection, profile.pace);
  final expectedWeeklyKg = profile.weightDirection == WeightDirection.lose ? -weekly : weekly;
  final currentAdjustment = profile.calorieAdjustmentKcal;

  final double rawAdjustment;
  if (method == SuggestionMethod.energyBalance) {
    final averageIntake = logged.reduce((a, b) => a + b) / logged.length;
    final observedTdee = averageIntake - slope * _kcalPerKg;
    final formula = calculator.maintenance(
      weightKg: profile.weightKg,
      heightCm: profile.heightCm,
      birthYear: profile.birthYear,
      currentYear: now.year,
      gender: profile.gender,
      activityLevel: profile.activityLevel,
    );
    rawAdjustment = observedTdee - formula;
  } else {
    rawAdjustment = currentAdjustment - (slope - expectedWeeklyKg / 7) * _kcalPerKg;
  }

  final currentTarget = targets(currentAdjustment).calorieTarget;
  final delta = (targets(rawAdjustment).calorieTarget - currentTarget).clamp(-_maxSuggestionKcal, _maxSuggestionKcal);
  if (delta.abs() < _minSuggestionKcal) return null;

  final newAdjustment = currentAdjustment + delta;
  final next = targets(newAdjustment);
  if ((next.calorieTarget - currentTarget).abs() < _minSuggestionKcal) return null;

  return CalorieSuggestion(
    method: method,
    windowDays: windowDays,
    currentTarget: currentTarget,
    newTarget: next.calorieTarget,
    newProteinTargetG: next.proteinTargetG,
    newAdjustmentKcal: newAdjustment,
    observedWeeklyKg: slope * 7,
    expectedWeeklyKg: expectedWeeklyKg,
  );
}

/// "Uygula": payı, zamanı ve yeni hedefleri yazar.
Map<String, dynamic> applySuggestionFields(CalorieSuggestion suggestion, DateTime now) => {
      'calorie_adjustment_kcal': suggestion.newAdjustmentKcal,
      'calorie_adjusted_at': now.toUtc().toIso8601String(),
      'daily_calorie_target': suggestion.newTarget,
      'daily_protein_target_g': suggestion.newProteinTargetG,
    };

/// "Şimdi değil": öneriyi 7 gün gizler.
Map<String, dynamic> snoozeSuggestionFields(DateTime now) => {
      'calorie_suggestion_snoozed_until': now.add(const Duration(days: _snoozeDays)).toUtc().toIso8601String(),
    };
