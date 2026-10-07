import 'package:spor_takip/features/nutrition/domain/food_item.dart';
import 'package:spor_takip/features/nutrition/domain/meal.dart';
import 'package:spor_takip/features/nutrition/domain/meal_type.dart';
import 'package:spor_takip/features/onboarding/domain/profile.dart';
import 'package:spor_takip/features/workout/domain/workout_session.dart';

const testProfile = Profile(
  userId: 'user-1',
  weightKg: 80,
  heightCm: 180,
  birthYear: 1996,
  gender: Gender.male,
  activityLevel: ActivityLevel.moderate,
  doesExercise: true,
  exerciseDaysPerWeek: 3,
  weightDirection: WeightDirection.maintain,
  focuses: {GoalFocus.muscle},
  dailyCalorieTarget: 2700,
  dailyProteinTargetG: 176,
);

/// Tamamlanmış (varsayılan) bir set; [kg] null = vücut ağırlığı.
SessionSet doneSet(
  String exerciseId, {
  double? kg = 100,
  int? reps = 5,
  bool done = true,
  int setIndex = 0,
}) {
  return SessionSet(
    exercisePosition: 0,
    setIndex: setIndex,
    exerciseId: exerciseId,
    exerciseName: '$exerciseId name',
    targetRepsMin: 5,
    targetRepsMax: 5,
    weightKg: kg,
    reps: reps,
    completedAt: done ? DateTime(2026, 9, 1) : null,
  );
}

/// [finishedAt] null = devam eden oturum.
WorkoutSession finishedSession(String id, DateTime? finishedAt, List<SessionSet> sets) {
  return WorkoutSession(
    id: id,
    programName: 'Program',
    workoutName: 'A',
    workoutPosition: 0,
    startedAt: (finishedAt ?? DateTime(2026, 9, 1)).subtract(const Duration(hours: 1)),
    finishedAt: finishedAt,
    sets: sets,
  );
}

/// Tek kalemli öğün.
Meal testMeal(DateTime loggedAt, {double calories = 500, double proteinG = 30}) {
  return Meal(
    id: 'meal-${loggedAt.toIso8601String()}',
    userId: 'user-1',
    mealType: MealType.lunch,
    loggedAt: loggedAt,
    items: [FoodItem(name: 'Yemek', grams: 100, calories: calories, proteinG: proteinG)],
  );
}
