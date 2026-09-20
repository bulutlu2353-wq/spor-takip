enum Gender { male, female, unspecified }

enum ActivityLevel { sedentary, light, moderate, active, veryActive }

enum Goal { loseWeight, gainMuscle, maintain }

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
    required this.goal,
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
  final Goal goal;
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
      activityLevel: _activityLevelFromDb(json['activity_level'] as String),
      doesExercise: json['does_exercise'] as bool,
      sportType: json['sport_type'] as String?,
      exerciseDaysPerWeek: json['exercise_days_per_week'] as int,
      goal: _goalFromDb(json['goal'] as String),
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
      'activity_level': _activityLevelToDb(activityLevel),
      'does_exercise': doesExercise,
      'sport_type': sportType,
      'exercise_days_per_week': exerciseDaysPerWeek,
      'goal': _goalToDb(goal),
      'health_notes': healthNotes,
      'daily_calorie_target': dailyCalorieTarget,
      'daily_protein_target_g': dailyProteinTargetG,
    };
  }
}

String _activityLevelToDb(ActivityLevel level) {
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

ActivityLevel _activityLevelFromDb(String value) {
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

String _goalToDb(Goal goal) {
  switch (goal) {
    case Goal.loseWeight:
      return 'lose_weight';
    case Goal.gainMuscle:
      return 'gain_muscle';
    case Goal.maintain:
      return 'maintain';
  }
}

Goal _goalFromDb(String value) {
  switch (value) {
    case 'lose_weight':
      return Goal.loseWeight;
    case 'gain_muscle':
      return Goal.gainMuscle;
    case 'maintain':
      return Goal.maintain;
    default:
      throw ArgumentError('Unknown goal: $value');
  }
}
