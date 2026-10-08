import '../../onboarding/domain/profile.dart';
import '../../onboarding/domain/tdee_calculator.dart';

/// [profile] için kalori/protein hedefi; önizleme ve kayıt aynı hesabı kullanır.
TdeeResult targetsFor(
  Profile profile, {
  required int currentYear,
  TdeeCalculator calculator = const TdeeCalculator(),
}) {
  return calculator.calculate(
    weightKg: profile.weightKg,
    heightCm: profile.heightCm,
    birthYear: profile.birthYear,
    currentYear: currentYear,
    gender: profile.gender,
    activityLevel: profile.activityLevel,
    weightDirection: profile.weightDirection,
    pace: profile.pace,
    focuses: profile.focuses,
    adjustmentKcal: profile.calorieAdjustmentKcal,
  );
}

/// Ayarlarda düzenlenebilen sütunlar. Kilo yok: kilo kayıtlarıyla senkron (G2 spec §3.3).
const _editableColumns = [
  'height_cm',
  'birth_year',
  'gender',
  'activity_level',
  'does_exercise',
  'sport_type',
  'exercise_days_per_week',
  'health_notes',
  'weight_direction',
  'pace',
  'focuses',
];

/// Değişince kalori/protein hedefinin yeniden hesaplandığı sütunlar.
const _targetColumns = {'height_cm', 'birth_year', 'gender', 'activity_level', 'weight_direction', 'pace', 'focuses'};

/// [before] → [after] arasında değişen sütunlar (DB adları, `toJson` biçimi);
/// hedefi etkileyen bir sütun değiştiyse yeni hedefler ve değişiklik zamanı da eklenir.
/// Aktivite değişince uyarlama payı sıfırlanır (G3 spec §4.2). Değişiklik yoksa boş.
Map<String, dynamic> profileChanges(
  Profile before,
  Profile after, {
  required DateTime now,
  TdeeCalculator calculator = const TdeeCalculator(),
}) {
  final old = before.toJson();
  final next = after.toJson();
  final changes = <String, dynamic>{
    for (final column in _editableColumns)
      if (!_same(old[column], next[column])) column: next[column],
  };
  if (changes.keys.any(_targetColumns.contains)) {
    final activityChanged = changes.containsKey('activity_level');
    final target = activityChanged ? after.copyWith(calorieAdjustmentKcal: 0) : after;
    final targets = targetsFor(target, currentYear: now.year, calculator: calculator);
    changes['daily_calorie_target'] = targets.calorieTarget;
    changes['daily_protein_target_g'] = targets.proteinTargetG;
    changes['goals_changed_at'] = now.toUtc().toIso8601String();
    if (activityChanged) changes['calorie_adjustment_kcal'] = 0.0;
  }
  return changes;
}

/// "Uyarlamayı sıfırla" (G3 spec §5.2): pay 0, hedefler formülle, pencere yeniden başlar.
Map<String, dynamic> resetAdjustmentFields(
  Profile profile, {
  required DateTime now,
  TdeeCalculator calculator = const TdeeCalculator(),
}) {
  final targets = targetsFor(profile.copyWith(calorieAdjustmentKcal: 0), currentYear: now.year, calculator: calculator);
  final stamp = now.toUtc().toIso8601String();
  return {
    'calorie_adjustment_kcal': 0.0,
    'calorie_adjusted_at': stamp,
    'goals_changed_at': stamp,
    'daily_calorie_target': targets.calorieTarget,
    'daily_protein_target_g': targets.proteinTargetG,
  };
}

/// `focuses` dizisi değer olarak karşılaştırılır.
bool _same(Object? a, Object? b) => a is List && b is List ? a.join(',') == b.join(',') : a == b;
