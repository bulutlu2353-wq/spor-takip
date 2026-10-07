enum Gender { male, female, unspecified }

enum ActivityLevel { sedentary, light, moderate, active, veryActive }

/// Kilo yönü: kalori hedefini belirler (spec §2).
enum WeightDirection { lose, maintain, gain }

/// Kilo verme/alma hızı; korumada yok.
enum Pace { slow, balanced, fast }

/// Odaklar (çoklu). Flutter'ın `Focus` widget'ıyla çakışmasın diye `GoalFocus`.
enum GoalFocus { muscle, strength, endurance, general }

class Profile {
  const Profile({
    required this.userId,
    required this.weightKg,
    required this.heightCm,
    required this.birthYear,
    required this.gender,
    required this.activityLevel,
    required this.doesExercise,
    this.sportType,
    required this.exerciseDaysPerWeek,
    required this.weightDirection,
    this.pace,
    this.focuses = const <GoalFocus>{},
    this.healthNotes,
    required this.dailyCalorieTarget,
    required this.dailyProteinTargetG,
  });

  final String userId;
  final double weightKg;
  final double heightCm;
  final int birthYear;
  final Gender gender;
  final ActivityLevel activityLevel;
  final bool doesExercise;
  final String? sportType;
  final int exerciseDaysPerWeek;
  final WeightDirection weightDirection;
  final Pace? pace;
  final Set<GoalFocus> focuses;
  final String? healthNotes;
  final double dailyCalorieTarget;
  final double dailyProteinTargetG;

  factory Profile.fromJson(Map<String, dynamic> json) {
    return Profile(
      userId: json['user_id'] as String,
      weightKg: (json['weight_kg'] as num).toDouble(),
      heightCm: (json['height_cm'] as num).toDouble(),
      birthYear: json['birth_year'] as int,
      gender: Gender.values.byName(json['gender'] as String),
      activityLevel: activityLevelFromDb(json['activity_level'] as String),
      doesExercise: json['does_exercise'] as bool,
      sportType: json['sport_type'] as String?,
      exerciseDaysPerWeek: json['exercise_days_per_week'] as int,
      weightDirection: WeightDirection.values.byName(json['weight_direction'] as String),
      pace: paceFromDb(json['pace'] as String?),
      focuses: focusesFromDb(json['focuses'] as List<dynamic>),
      healthNotes: json['health_notes'] as String?,
      dailyCalorieTarget: (json['daily_calorie_target'] as num).toDouble(),
      dailyProteinTargetG: (json['daily_protein_target_g'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'weight_kg': weightKg,
      'height_cm': heightCm,
      'birth_year': birthYear,
      'gender': gender.name,
      'activity_level': activityLevelToDb(activityLevel),
      'does_exercise': doesExercise,
      'sport_type': sportType,
      'exercise_days_per_week': exerciseDaysPerWeek,
      'weight_direction': weightDirection.name,
      'pace': pace?.name,
      'focuses': focusesToDb(focuses),
      'health_notes': healthNotes,
      'daily_calorie_target': dailyCalorieTarget,
      'daily_protein_target_g': dailyProteinTargetG,
    };
  }

  /// Hedef hesabı gibi "ya böyle olsaydı" durumları için kopya.
  Profile copyWith({
    double? weightKg,
    double? heightCm,
    ActivityLevel? activityLevel,
    bool? doesExercise,
    int? exerciseDaysPerWeek,
    WeightDirection? weightDirection,
    Pace? pace,
    bool clearPace = false,
    Set<GoalFocus>? focuses,
  }) {
    return Profile(
      userId: userId,
      weightKg: weightKg ?? this.weightKg,
      heightCm: heightCm ?? this.heightCm,
      birthYear: birthYear,
      gender: gender,
      activityLevel: activityLevel ?? this.activityLevel,
      doesExercise: doesExercise ?? this.doesExercise,
      sportType: sportType,
      exerciseDaysPerWeek: exerciseDaysPerWeek ?? this.exerciseDaysPerWeek,
      weightDirection: weightDirection ?? this.weightDirection,
      pace: clearPace ? null : pace ?? this.pace,
      focuses: focuses ?? this.focuses,
      healthNotes: healthNotes,
      dailyCalorieTarget: dailyCalorieTarget,
      dailyProteinTargetG: dailyProteinTargetG,
    );
  }
}

String activityLevelToDb(ActivityLevel level) {
  switch (level) {
    case ActivityLevel.sedentary:
      return 'sedentary';
    case ActivityLevel.light:
      return 'light';
    case ActivityLevel.moderate:
      return 'moderate';
    case ActivityLevel.active:
      return 'active';
    case ActivityLevel.veryActive:
      return 'very_active';
  }
}

ActivityLevel activityLevelFromDb(String value) {
  switch (value) {
    case 'sedentary':
      return ActivityLevel.sedentary;
    case 'light':
      return ActivityLevel.light;
    case 'moderate':
      return ActivityLevel.moderate;
    case 'active':
      return ActivityLevel.active;
    case 'very_active':
      return ActivityLevel.veryActive;
    default:
      throw ArgumentError('Unknown activity_level: $value');
  }
}

Pace? paceFromDb(String? value) => value == null ? null : Pace.values.byName(value);

Set<GoalFocus> focusesFromDb(List<dynamic> values) =>
    {for (final value in values) GoalFocus.values.byName(value as String)};

/// Enum sırasıyla; aynı küme hep aynı diziyi verir.
List<String> focusesToDb(Set<GoalFocus> focuses) =>
    [for (final focus in GoalFocus.values) if (focuses.contains(focus)) focus.name];
