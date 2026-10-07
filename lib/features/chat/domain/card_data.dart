import '../../onboarding/domain/profile.dart';
import '../../onboarding/domain/tdee_calculator.dart';
import '../../progress/domain/body_weight_log.dart';
import '../../progress/domain/progress_format.dart';
import 'chat_models.dart';

/// Onayda yeni kalori/protein hedefi gönderen araçlar.
const profileTools = {ChatTool.logBodyWeight, ChatTool.updateProfile, ChatTool.setGoal};

/// Kartta bir profil alanının önce → sonra satırı.
class FieldChange {
  const FieldChange(this.field, this.before, this.after);

  final String field;
  final Object? before;
  final Object? after;
}

/// `set_goal` payload'ındaki alanlar (G1 sonrası; hep birlikte gönderilir).
const goalFields = ['weight_direction', 'pace', 'focuses'];

List<FieldChange> profileFieldChanges(ChatEvent event) {
  final Map<String, dynamic> changes;
  if (event.tool == ChatTool.setGoal) {
    // G1 öncesi olaylar tek `goal` alanı taşır.
    changes = event.payload.containsKey('goal')
        ? {'goal': event.payload['goal']}
        : {for (final field in goalFields) field: event.payload[field]};
  } else {
    changes = Map<String, dynamic>.from(event.payload['changes'] as Map);
  }
  return [for (final e in changes.entries) FieldChange(e.key, event.base[e.key], e.value)];
}

/// Değişiklik uygulanmış profil (yalnız hedefi etkileyen alanlar).
Profile profileAfter(Profile profile, ChatEvent event) {
  switch (event.tool) {
    case ChatTool.logBodyWeight:
      return profile.copyWith(weightKg: weightAfter(event));
    case ChatTool.setGoal:
      final payload = event.payload;
      // G1 öncesi olay artık uygulanamaz; profil değişmez.
      if (payload.containsKey('goal')) return profile;
      final pace = paceFromDb(payload['pace'] as String?);
      return profile.copyWith(
        weightDirection: WeightDirection.values.byName(payload['weight_direction'] as String),
        pace: pace,
        clearPace: pace == null,
        focuses: focusesFromDb(payload['focuses'] as List<dynamic>),
      );
    case ChatTool.updateProfile:
      final changes = Map<String, dynamic>.from(event.payload['changes'] as Map);
      final activity = changes['activity_level'] as String?;
      return profile.copyWith(
        heightCm: (changes['height_cm'] as num?)?.toDouble(),
        activityLevel: activity == null ? null : activityLevelFromDb(activity),
        doesExercise: changes['does_exercise'] as bool?,
        exerciseDaysPerWeek: changes['exercise_days_per_week'] as int?,
      );
    case ChatTool.createMeal || ChatTool.logSet || ChatTool.editProgram:
      return profile;
  }
}

/// Profil araçlarında onayla gönderilecek yeni hedefler; diğerlerinde null.
TdeeResult? targetsAfter(
  Profile profile,
  ChatEvent event, {
  required int currentYear,
  TdeeCalculator calculator = const TdeeCalculator(),
}) {
  if (!profileTools.contains(event.tool)) return null;
  final after = profileAfter(profile, event);
  return calculator.calculate(
    weightKg: after.weightKg,
    heightCm: after.heightCm,
    birthYear: after.birthYear,
    currentYear: currentYear,
    gender: after.gender,
    activityLevel: after.activityLevel,
    weightDirection: after.weightDirection,
    pace: after.pace,
    focuses: after.focuses,
  );
}

DateTime weightDate(ChatEvent event) => parseDbDate(event.payload['date'] as String);

double weightAfter(ChatEvent event) => (event.payload['kg'] as num).toDouble();

/// O tarihte kayıt varsa onun kilosu, yoksa profildeki kilo.
double weightBefore(ChatEvent event) {
  final log = event.base['log'] as num?;
  final profile = Map<String, dynamic>.from(event.base['profile'] as Map);
  return (log ?? profile['weight_kg'] as num).toDouble();
}

/// Kayıt en yeniyse profili ve hedefleri değiştirir (log_body_weight kuralı).
bool isNewestWeight(ChatEvent event, List<BodyWeightLog> logs) {
  return logs.isEmpty || !weightDate(event).isBefore(logs.last.date);
}

double round1(double value) => (value * 10).roundToDouble() / 10;

/// Öğün kartındaki bir kalem; makrolar 100 g değerlerinden hesaplanır (SQL ile aynı yuvarlama).
class MealCardItem {
  const MealCardItem({
    required this.name,
    required this.grams,
    required this.per100Calories,
    required this.per100ProteinG,
    required this.per100CarbsG,
    required this.per100FatG,
    required this.needsReview,
  });

  factory MealCardItem.fromPayload(Map<String, dynamic> json) {
    final per100 = Map<String, dynamic>.from(json['per100'] as Map);
    return MealCardItem(
      name: json['name'] as String,
      grams: (json['grams'] as num).toDouble(),
      per100Calories: (per100['calories'] as num).toDouble(),
      per100ProteinG: (per100['protein_g'] as num).toDouble(),
      per100CarbsG: (per100['carbs_g'] as num).toDouble(),
      per100FatG: (per100['fat_g'] as num).toDouble(),
      needsReview: json['needs_review'] as bool? ?? false,
    );
  }

  final String name;
  final double grams;
  final double per100Calories;
  final double per100ProteinG;
  final double per100CarbsG;
  final double per100FatG;
  final bool needsReview;

  double _scale(double per100) => round1(grams * per100 / 100);

  double get calories => _scale(per100Calories);
  double get proteinG => _scale(per100ProteinG);
  double get carbsG => _scale(per100CarbsG);
  double get fatG => _scale(per100FatG);

  MealCardItem withGrams(double grams) {
    return MealCardItem(
      name: name,
      grams: grams,
      per100Calories: per100Calories,
      per100ProteinG: per100ProteinG,
      per100CarbsG: per100CarbsG,
      per100FatG: per100FatG,
      needsReview: needsReview,
    );
  }
}

List<MealCardItem> mealItems(ChatEvent event) {
  return [
    for (final item in event.payload['items'] as List) MealCardItem.fromPayload(Map<String, dynamic>.from(item as Map)),
  ];
}

/// `apply_chat_action`'ın `p_extras` parametresi.
Map<String, dynamic> applyExtras({TdeeResult? targets, List<double>? itemGrams}) {
  return {
    if (targets != null) ...{'calorie_target': targets.calorieTarget, 'protein_target': targets.proteinTargetG},
    'item_grams': ?itemGrams,
  };
}

List<String> programChangeLabels(ChatEvent event) {
  return [for (final change in event.payload['changes'] as List) (change as Map)['label'] as String];
}
