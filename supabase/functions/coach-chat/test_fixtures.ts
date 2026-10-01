import type { ContextData } from './types.ts';

/** Testlerde ortak bağlam: 2026-10-01, UTC+3. */
export function sampleContext(): ContextData {
  return {
    today: '2026-10-01',
    profile: {
      weight_kg: 80,
      height_cm: 180,
      birth_year: 1996,
      gender: 'male',
      activity_level: 'moderate',
      does_exercise: true,
      sport_type: 'fitness',
      exercise_days_per_week: 3,
      goal: 'gain_muscle',
      health_notes: null,
      daily_calorie_target: 2700.4,
      daily_protein_target_g: 176,
      active_program_id: 'prog-1',
    },
    todayMeals: [
      {
        meal_type: 'lunch',
        logged_at: '2026-10-01T09:30:00Z',
        items: [
          { name: 'Tavuk', grams: 200, calories: 330, protein_g: 62, carbs_g: 0, fat_g: 7.2 },
          { name: 'Pilav', grams: 150, calories: 195, protein_g: 4.1, carbs_g: 42, fat_g: 0.5 },
        ],
      },
    ],
    weights: [
      { logged_on: '2026-09-20', weight_kg: 80.5 },
      { logged_on: '2026-09-30', weight_kg: 80 },
    ],
    recentSessions: [
      {
        workout_name: 'A',
        finished_at: '2026-09-30T18:00:00Z',
        sets: [
          { exercise_name: 'Barbell Squat', weight_kg: 100, reps: 5 },
          { exercise_name: 'Barbell Squat', weight_kg: 105, reps: 3 },
          { exercise_name: 'Pullups', weight_kg: null, reps: 8 },
        ],
      },
    ],
    activeProgram: {
      id: 'prog-1',
      name: 'My 5x5',
      is_builtin: false,
      workouts: [
        {
          name: 'A',
          exercises: [
            { name: 'Barbell Squat', sets: 5, reps_min: 5, reps_max: 5 },
            { name: 'Barbell Bench Press - Medium Grip', sets: 3, reps_min: 8, reps_max: 12 },
          ],
        },
      ],
    },
    inProgress: {
      id: 'session-1',
      workout_name: 'A',
      sets: [
        { exercise_position: 0, set_index: 0, exercise_name: 'Barbell Squat', target_reps_min: 5, target_reps_max: 5, weight_kg: 100, reps: 5, completed: true },
        { exercise_position: 0, set_index: 1, exercise_name: 'Barbell Squat', target_reps_min: 5, target_reps_max: 5, weight_kg: null, reps: null, completed: false },
      ],
    },
    oneRepMaxes: [{ exercise_name: 'Barbell Squat', weight_kg: 120 }],
  };
}
