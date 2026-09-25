/// free-exercise-db'deki tüm `primaryMuscles` değerleri (17).
const muscleGroups = <String>[
  'abdominals',
  'abductors',
  'adductors',
  'biceps',
  'calves',
  'chest',
  'forearms',
  'glutes',
  'hamstrings',
  'lats',
  'lower back',
  'middle back',
  'neck',
  'quadriceps',
  'shoulders',
  'traps',
  'triceps',
];

/// free-exercise-db'deki tüm null olmayan `equipment` değerleri (12).
const equipmentTypes = <String>[
  'bands',
  'barbell',
  'body only',
  'cable',
  'dumbbell',
  'e-z curl bar',
  'exercise ball',
  'foam roll',
  'kettlebells',
  'machine',
  'medicine ball',
  'other',
];

String _slug(String value) => value.replaceAll(RegExp(r'[ -]'), '_');

String muscleLabelKey(String muscle) => 'workout.muscle.${_slug(muscle)}';

String equipmentLabelKey(String equipment) => 'workout.equipment.${_slug(equipment)}';

/// Widget key'lerinde kullanılan kısa ad (`lower back` → `lower_back`).
String taxonomySlug(String value) => _slug(value);
