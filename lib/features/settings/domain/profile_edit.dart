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
/// hedefi etkileyen bir sütun değiştiyse yeni hedefler de eklenir. Değişiklik yoksa boş.
Map<String, dynamic> profileChanges(
  Profile before,
  Profile after, {
  required int currentYear,
  TdeeCalculator calculator = const TdeeCalculator(),
}) {
  final old = before.toJson();
  final now = after.toJson();
  final changes = <String, dynamic>{
    for (final column in _editableColumns)
      if (!_same(old[column], now[column])) column: now[column],
  };
  if (changes.keys.any(_targetColumns.contains)) {
    final targets = targetsFor(after, currentYear: currentYear, calculator: calculator);
    changes['daily_calorie_target'] = targets.calorieTarget;
    changes['daily_protein_target_g'] = targets.proteinTargetG;
  }
  return changes;
}

/// `focuses` dizisi değer olarak karşılaştırılır.
bool _same(Object? a, Object? b) => a is List && b is List ? a.join(',') == b.join(',') : a == b;
