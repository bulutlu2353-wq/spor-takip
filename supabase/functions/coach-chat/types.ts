// coach-chat'in ortak tipleri. Satır tipleri PostgREST'in döndürdüğü
// snake_case alan adlarını korur.

export type Locale = 'tr' | 'en';
export const TOOL_NAMES = ['log_body_weight', 'update_profile', 'set_goal', 'create_meal', 'log_set', 'edit_program'] as const;
export type ToolName = typeof TOOL_NAMES[number];
export type EventStatus = 'pending' | 'applied' | 'cancelled' | 'undone' | 'stale';
export interface StoredEvent { id: string; tool: ToolName; status: EventStatus; summary: string; payload: Record<string, unknown>; base: unknown }
export interface StoredMessage { id: string; role: 'user' | 'assistant'; content: string; created_at: string; event: StoredEvent | null }
export interface NewEvent { tool: ToolName; summary: string; payload: Record<string, unknown>; base: unknown }
export interface ProfileRow { weight_kg: number; height_cm: number; birth_year: number; gender: string; activity_level: string; does_exercise: boolean; sport_type: string | null; exercise_days_per_week: number; weight_direction: string; pace: string | null; focuses: string[]; health_notes: string | null; daily_calorie_target: number; daily_protein_target_g: number; calorie_adjustment_kcal: number; active_program_id: string | null }
export interface MealItemRow { name: string; grams: number; calories: number; protein_g: number; carbs_g: number; fat_g: number }
export interface MealRow { meal_type: string; logged_at: string; items: MealItemRow[] }
export interface SetRow { exercise_name: string; weight_kg: number | null; reps: number | null }
export interface SessionSummary { workout_name: string; finished_at: string; sets: SetRow[] }
export interface ProgramView { id: string; name: string; is_builtin: boolean; workouts: Array<{ name: string; exercises: Array<{ name: string; sets: number; reps_min: number; reps_max: number }> }> }
export interface InProgressSet { exercise_position: number; set_index: number; exercise_name: string; target_reps_min: number; target_reps_max: number; weight_kg: number | null; reps: number | null; completed: boolean }
export interface InProgressSession { id: string; workout_name: string; sets: InProgressSet[] }
export interface ContextData { today: string; profile: ProfileRow | null; todayMeals: MealRow[]; weights: Array<{ logged_on: string; weight_kg: number }>; recentSessions: SessionSummary[]; activeProgram: ProgramView | null; inProgress: InProgressSession | null; oneRepMaxes: Array<{ exercise_name: string; weight_kg: number }> }
