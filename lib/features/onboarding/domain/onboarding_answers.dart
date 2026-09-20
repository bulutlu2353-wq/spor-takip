import 'profile.dart';

class OnboardingAnswers {
  const OnboardingAnswers({
    this.weightKg,
    this.heightCm,
    this.birthYear,
    this.gender,
    this.activityLevel,
    this.doesExercise,
    this.sportType,
    this.exerciseDaysPerWeek,
    this.goal,
    this.healthNotes,
  });

  final double? weightKg;
  final double? heightCm;
  final int? birthYear;
  final Gender? gender;
  final ActivityLevel? activityLevel;
  final bool? doesExercise;
  final String? sportType;
  final int? exerciseDaysPerWeek;
  final Goal? goal;
  final String? healthNotes;

  OnboardingAnswers copyWith({
    double? weightKg,
    double? heightCm,
    int? birthYear,
    Gender? gender,
    ActivityLevel? activityLevel,
    bool? doesExercise,
    String? sportType,
    int? exerciseDaysPerWeek,
    Goal? goal,
    String? healthNotes,
  }) {
    return OnboardingAnswers(
      weightKg: weightKg ?? this.weightKg,
      heightCm: heightCm ?? this.heightCm,
      birthYear: birthYear ?? this.birthYear,
      gender: gender ?? this.gender,
      activityLevel: activityLevel ?? this.activityLevel,
      doesExercise: doesExercise ?? this.doesExercise,
      sportType: sportType ?? this.sportType,
      exerciseDaysPerWeek: exerciseDaysPerWeek ?? this.exerciseDaysPerWeek,
      goal: goal ?? this.goal,
      healthNotes: healthNotes ?? this.healthNotes,
    );
  }

  bool get isComplete =>
      weightKg != null &&
      heightCm != null &&
      birthYear != null &&
      gender != null &&
      activityLevel != null &&
      doesExercise != null &&
      (doesExercise == false ||
          (sportType != null && exerciseDaysPerWeek != null)) &&
      goal != null;
}
