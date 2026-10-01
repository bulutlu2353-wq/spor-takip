import type { Macros, UsdaFood } from '../_shared/usda_client.ts';
import { localDate } from './context.ts';
import type { ToolDefinition } from './llm/types.ts';
import { applyProgramOperations, ProgramOpError } from './program_ops.ts';
import type { ProgramOperation, ProgramSnapshot } from './program_ops.ts';
import type { ContextData, Locale, ToolName } from './types.ts';

export interface ToolDeps {
  findExercises(query: string): Promise<Array<{ id: string; name: string }>>;
  exerciseNames(ids: string[]): Promise<Record<string, string>>;
  programSnapshot(programId: string): Promise<ProgramSnapshot | null>;
  findBestMatch(query: string): Promise<UsdaFood | null>;
  fetchMacrosPer100g(fdcId: number): Promise<Macros>;
  newId(): string;
}

export interface ToolContext {
  data: ContextData;
  now: Date;
  utcOffsetMinutes: number;
  locale: Locale;
}

export type PreparedTool =
  | { ok: true; tool: ToolName; summary: string; payload: Record<string, unknown> }
  | { ok: false; error: string; candidates?: string[] };

type Args = Record<string, unknown>;

const GOALS = ['lose_weight', 'gain_muscle', 'maintain'] as const;
const ACTIVITY_LEVELS = ['sedentary', 'light', 'moderate', 'active', 'very_active'] as const;
const MEAL_TYPES = ['breakfast', 'lunch', 'dinner', 'snack'] as const;
const PROGRAM_OPS = ['add_exercise', 'remove_exercise', 'modify_exercise', 'rename_workout'] as const;
const PROFILE_FIELDS = ['height_cm', 'activity_level', 'does_exercise', 'sport_type', 'exercise_days_per_week', 'health_notes'];

export const TOOL_DEFINITIONS: ToolDefinition[] = [
  {
    name: 'log_body_weight',
    description: "Log the user's body weight for a day (default today). If it is the newest entry it also " +
      'updates the profile weight and the calorie/protein targets.',
    parameters: {
      type: 'object',
      properties: {
        weight_kg: { type: 'number', description: 'Body weight in kg (20-400).' },
        date: { type: 'string', description: 'Local date YYYY-MM-DD; omit for today. Cannot be in the future.' },
      },
      required: ['weight_kg'],
    },
  },
  {
    name: 'update_profile',
    description: 'Change profile fields other than weight and goal. The app recalculates the calorie/protein targets.',
    parameters: {
      type: 'object',
      properties: {
        height_cm: { type: 'number', description: 'Height in cm (100-250).' },
        activity_level: { type: 'string', enum: [...ACTIVITY_LEVELS] },
        does_exercise: { type: 'boolean' },
        sport_type: { type: 'string', description: 'For example fitness, running, swimming.' },
        exercise_days_per_week: { type: 'integer', description: '0-7' },
        health_notes: { type: 'string' },
      },
    },
  },
  {
    name: 'set_goal',
    description: "Change the user's goal. The app recalculates the calorie/protein targets.",
    parameters: {
      type: 'object',
      properties: { goal: { type: 'string', enum: [...GOALS] } },
      required: ['goal'],
    },
  },
  {
    name: 'create_meal',
    description: 'Log a meal the user describes. Do not estimate calories or macros: they are looked up from USDA.',
    parameters: {
      type: 'object',
      properties: {
        meal_type: { type: 'string', enum: [...MEAL_TYPES] },
        time: { type: 'string', description: 'Local time today as HH:MM; omit for now.' },
        items: {
          type: 'array',
          items: {
            type: 'object',
            properties: {
              name: { type: 'string', description: "Food name in the user's language (shown to the user)." },
              grams: { type: 'number', description: 'Estimated portion in grams (1-2000).' },
              usda_query: { type: 'string', description: 'Generic English USDA search query incl. raw/cooked, e.g. "cooked white rice".' },
            },
            required: ['name', 'grams', 'usda_query'],
          },
        },
      },
      required: ['meal_type', 'items'],
    },
  },
  {
    name: 'log_set',
    description: 'Record weight and reps for one set of the in-progress workout and mark it done.',
    parameters: {
      type: 'object',
      properties: {
        exercise_name: { type: 'string', description: 'Exercise name exactly as listed in the in-progress workout.' },
        set_number: { type: 'integer', description: '1-based set number.' },
        weight_kg: { type: 'number', description: 'Weight in kg; 0 for bodyweight.' },
        reps: { type: 'integer' },
      },
      required: ['exercise_name', 'set_number', 'weight_kg', 'reps'],
    },
  },
  {
    name: 'edit_program',
    description: "Edit the user's own active program with one or more operations.",
    parameters: {
      type: 'object',
      properties: {
        operations: {
          type: 'array',
          items: {
            type: 'object',
            properties: {
              op: { type: 'string', enum: [...PROGRAM_OPS] },
              workout_name: { type: 'string', description: 'Workout name as listed in the active program.' },
              exercise_name: { type: 'string', description: 'English exercise name (add/remove/modify).' },
              sets: { type: 'integer', description: '1-10' },
              reps_min: { type: 'integer', description: '1-100' },
              reps_max: { type: 'integer', description: '1-100, at least reps_min' },
              new_name: { type: 'string', description: 'New workout name (rename_workout).' },
            },
            required: ['op', 'workout_name'],
          },
        },
      },
      required: ['operations'],
    },
  },
];

const LABELS = {
  tr: {
    weight: 'Kilo kaydı',
    profile: 'Profil güncelleme',
    goal: 'Amaç değişikliği',
    meal: 'Öğün',
    program: 'Program düzenleme',
    changes: 'değişiklik',
    set: (name: string, n: number, kg: number, reps: number) => `Set kaydı: ${name} ${n}. set — ${kg} kg × ${reps}`,
    goals: { lose_weight: 'Kilo vermek', gain_muscle: 'Kas kazanmak', maintain: 'Formda kalmak' },
    meals: { breakfast: 'Kahvaltı', lunch: 'Öğle', dinner: 'Akşam', snack: 'Atıştırmalık' },
    fields: {
      height_cm: 'boy', activity_level: 'aktivite', does_exercise: 'spor yapma', sport_type: 'spor türü',
      exercise_days_per_week: 'haftalık spor günü', health_notes: 'sağlık notları',
    } as Record<string, string>,
  },
  en: {
    weight: 'Log weight',
    profile: 'Update profile',
    goal: 'Change goal',
    meal: 'Meal',
    program: 'Edit program',
    changes: 'changes',
    set: (name: string, n: number, kg: number, reps: number) => `Log set: ${name} set ${n} — ${kg} kg × ${reps}`,
    goals: { lose_weight: 'Lose weight', gain_muscle: 'Gain muscle', maintain: 'Stay fit' },
    meals: { breakfast: 'Breakfast', lunch: 'Lunch', dinner: 'Dinner', snack: 'Snack' },
    fields: {
      height_cm: 'height', activity_level: 'activity', does_exercise: 'exercising', sport_type: 'sport',
      exercise_days_per_week: 'weekly training days', health_notes: 'health notes',
    } as Record<string, string>,
  },
};

class ToolArgError extends Error {
  constructor(message: string, readonly candidates: string[] = []) {
    super(message);
  }
}

function present(args: Args, key: string): boolean {
  return args[key] !== undefined && args[key] !== null;
}

function num(args: Args, key: string, min: number, max: number, integer = false): number {
  const value = args[key];
  if (typeof value !== 'number' || !Number.isFinite(value)) throw new ToolArgError(`${key} must be a number`);
  if (integer && !Number.isInteger(value)) throw new ToolArgError(`${key} must be an integer`);
  if (value < min || value > max) throw new ToolArgError(`${key} must be between ${min} and ${max}`);
  return value;
}

function optNum(args: Args, key: string, min: number, max: number, integer = false): number | undefined {
  return present(args, key) ? num(args, key, min, max, integer) : undefined;
}

function str(args: Args, key: string, maxLength: number): string {
  const value = args[key];
  if (typeof value !== 'string' || value.trim().length === 0 || value.length > maxLength) {
    throw new ToolArgError(`${key} must be a non-empty string of at most ${maxLength} characters`);
  }
  return value.trim();
}

/** Boş metin veya null → null (alanı temizler). */
function optText(args: Args, key: string, maxLength: number): string | null {
  return args[key] === null || args[key] === '' ? null : str(args, key, maxLength);
}

function oneOf<T extends string>(args: Args, key: string, values: readonly T[]): T {
  const value = args[key];
  if (typeof value !== 'string' || !(values as readonly string[]).includes(value)) {
    throw new ToolArgError(`${key} must be one of: ${values.join(', ')}`);
  }
  return value as T;
}

function objectAt(value: unknown, what: string): Args {
  if (typeof value !== 'object' || value === null || Array.isArray(value)) throw new ToolArgError(`each ${what} must be an object`);
  return value as Args;
}

function same(a: string, b: string): boolean {
  return a.trim().toLowerCase() === b.trim().toLowerCase();
}

function unique(values: string[]): string[] {
  return [...new Set(values)];
}

function round1(value: number): number {
  return Math.round(value * 10) / 10;
}

export async function prepareToolCall(name: string, args: Args, ctx: ToolContext, deps: ToolDeps): Promise<PreparedTool> {
  try {
    switch (name) {
      case 'log_body_weight':
        return prepareWeight(args, ctx);
      case 'update_profile':
        return prepareProfile(args, ctx);
      case 'set_goal':
        return prepareGoal(args, ctx);
      case 'create_meal':
        return await prepareMeal(args, ctx, deps);
      case 'log_set':
        return prepareSet(args, ctx);
      case 'edit_program':
        return await prepareProgram(args, ctx, deps);
      default:
        return { ok: false, error: `unknown tool ${name}` };
    }
  } catch (error) {
    if (error instanceof ToolArgError || error instanceof ProgramOpError) {
      return error.candidates.length > 0
        ? { ok: false, error: error.message, candidates: error.candidates }
        : { ok: false, error: error.message };
    }
    throw error;
  }
}

function prepareWeight(args: Args, ctx: ToolContext): PreparedTool {
  const kg = round1(num(args, 'weight_kg', 20, 400));
  const today = localDate(ctx.now, ctx.utcOffsetMinutes);
  let date = today;
  if (present(args, 'date')) {
    date = str(args, 'date', 10);
    const parsed = new Date(`${date}T00:00:00Z`);
    if (!/^\d{4}-\d{2}-\d{2}$/.test(date) || Number.isNaN(parsed.getTime()) || parsed.toISOString().slice(0, 10) !== date) {
      throw new ToolArgError('date must be a valid YYYY-MM-DD');
    }
    if (date > today) throw new ToolArgError('date cannot be in the future');
  }
  return {
    ok: true,
    tool: 'log_body_weight',
    summary: `${LABELS[ctx.locale].weight}: ${kg} kg (${date})`,
    payload: { date, kg },
  };
}

function prepareProfile(args: Args, ctx: ToolContext): PreparedTool {
  for (const key of Object.keys(args)) {
    if (!PROFILE_FIELDS.includes(key)) {
      throw new ToolArgError(`unknown field ${key}; weight changes go through log_body_weight and the goal through set_goal`);
    }
  }
  const changes: Record<string, unknown> = {};
  if (present(args, 'height_cm')) changes.height_cm = round1(num(args, 'height_cm', 100, 250));
  if (present(args, 'activity_level')) changes.activity_level = oneOf(args, 'activity_level', ACTIVITY_LEVELS);
  if (present(args, 'does_exercise')) {
    if (typeof args.does_exercise !== 'boolean') throw new ToolArgError('does_exercise must be a boolean');
    changes.does_exercise = args.does_exercise;
  }
  if (args.sport_type !== undefined) changes.sport_type = optText(args, 'sport_type', 100);
  if (present(args, 'exercise_days_per_week')) changes.exercise_days_per_week = num(args, 'exercise_days_per_week', 0, 7, true);
  if (args.health_notes !== undefined) changes.health_notes = optText(args, 'health_notes', 500);

  const keys = Object.keys(changes);
  if (keys.length === 0) throw new ToolArgError('at least one field is required');
  const labels = LABELS[ctx.locale];
  return {
    ok: true,
    tool: 'update_profile',
    summary: `${labels.profile}: ${keys.map((k) => labels.fields[k]).join(', ')}`,
    payload: { changes },
  };
}

function prepareGoal(args: Args, ctx: ToolContext): PreparedTool {
  const goal = oneOf(args, 'goal', GOALS);
  if (ctx.data.profile?.goal === goal) throw new ToolArgError(`goal is already ${goal}`);
  const labels = LABELS[ctx.locale];
  return { ok: true, tool: 'set_goal', summary: `${labels.goal}: ${labels.goals[goal]}`, payload: { goal } };
}

/** Bugünün yerel saati (HH:MM) → UTC ISO; saat yoksa şimdi. */
function mealTime(args: Args, ctx: ToolContext): string {
  if (!present(args, 'time')) return ctx.now.toISOString();
  const match = /^([01]\d|2[0-3]):([0-5]\d)$/.exec(String(args.time));
  if (!match) throw new ToolArgError('time must be HH:MM');
  const [year, month, day] = localDate(ctx.now, ctx.utcOffsetMinutes).split('-').map(Number);
  const localMs = Date.UTC(year, month - 1, day, Number(match[1]), Number(match[2]));
  return new Date(localMs - ctx.utcOffsetMinutes * 60_000).toISOString();
}

async function lookupMacros(query: string, deps: ToolDeps) {
  try {
    const match = await deps.findBestMatch(query);
    if (match) {
      const macros = await deps.fetchMacrosPer100g(match.fdcId);
      return {
        per100: { calories: macros.calories, protein_g: macros.proteinG, carbs_g: macros.carbsG, fat_g: macros.fatG },
        usda_fdc_id: String(match.fdcId),
        needs_review: false,
      };
    }
    console.warn(`No USDA match for "${query}"`);
  } catch (error) {
    console.error(`USDA lookup failed for "${query}":`, error);
  }
  return { per100: { calories: 0, protein_g: 0, carbs_g: 0, fat_g: 0 }, usda_fdc_id: null, needs_review: true };
}

async function prepareMeal(args: Args, ctx: ToolContext, deps: ToolDeps): Promise<PreparedTool> {
  const mealType = oneOf(args, 'meal_type', MEAL_TYPES);
  if (!Array.isArray(args.items) || args.items.length < 1 || args.items.length > 15) {
    throw new ToolArgError('items must have 1-15 entries');
  }
  const loggedAt = mealTime(args, ctx);
  const parsed = args.items.map((raw) => {
    const item = objectAt(raw, 'item');
    return { name: str(item, 'name', 100), grams: Math.round(num(item, 'grams', 1, 2000)), query: str(item, 'usda_query', 200) };
  });
  const items = [];
  for (const item of parsed) {
    items.push({ name: item.name, grams: item.grams, ...(await lookupMacros(item.query, deps)) });
  }
  const labels = LABELS[ctx.locale];
  return {
    ok: true,
    tool: 'create_meal',
    summary: `${labels.meal}: ${labels.meals[mealType]} — ${items.map((i) => `${i.name} (${i.grams} g)`).join(', ')}`,
    payload: { meal_id: deps.newId(), meal_type: mealType, logged_at: loggedAt, items },
  };
}

function prepareSet(args: Args, ctx: ToolContext): PreparedTool {
  const live = ctx.data.inProgress;
  if (!live) throw new ToolArgError('there is no workout in progress');
  const name = str(args, 'exercise_name', 100);
  const setNumber = num(args, 'set_number', 1, 50, true);
  const weightKg = round1(num(args, 'weight_kg', 0, 1000));
  const reps = num(args, 'reps', 0, 100, true);

  const matching = live.sets.filter((s) => same(s.exercise_name, name));
  if (matching.length === 0) {
    throw new ToolArgError(`exercise "${name}" is not in the in-progress workout`, unique(live.sets.map((s) => s.exercise_name)));
  }
  const position = matching[0].exercise_position;
  const ofExercise = matching.filter((s) => s.exercise_position === position);
  const target = ofExercise.find((s) => s.set_index === setNumber - 1);
  if (!target) {
    throw new ToolArgError(`${matching[0].exercise_name} has no set ${setNumber} (it has ${ofExercise.length} sets)`);
  }
  return {
    ok: true,
    tool: 'log_set',
    summary: LABELS[ctx.locale].set(target.exercise_name, setNumber, weightKg, reps),
    payload: {
      session_id: live.id,
      exercise_position: position,
      set_index: setNumber - 1,
      weight_kg: weightKg,
      reps,
      exercise_name: target.exercise_name,
      set_number: setNumber,
    },
  };
}

async function resolveExercise(query: string, deps: ToolDeps): Promise<{ id: string; name: string }> {
  const found = await deps.findExercises(query);
  const exact = found.filter((e) => same(e.name, query));
  if (exact.length > 0) return exact[0];
  if (found.length === 1) return found[0];
  throw new ToolArgError(
    found.length === 0 ? `no exercise matches "${query}"` : `"${query}" matches several exercises; pick one`,
    found.slice(0, 10).map((e) => e.name),
  );
}

async function prepareProgram(args: Args, ctx: ToolContext, deps: ToolDeps): Promise<PreparedTool> {
  const active = ctx.data.activeProgram;
  if (!active) throw new ToolArgError('the user has no active program');
  if (active.is_builtin) {
    throw new ToolArgError('the active program is built-in and read-only; tell the user to copy it in the Workout tab first');
  }
  if (!Array.isArray(args.operations) || args.operations.length < 1 || args.operations.length > 10) {
    throw new ToolArgError('operations must have 1-10 entries');
  }
  const snapshot = await deps.programSnapshot(active.id);
  if (!snapshot) throw new ToolArgError('the active program was not found');
  const ids = unique(snapshot.workouts.flatMap((w) => w.exercises.map((e) => e.exercise_id)));
  const names = ids.length > 0 ? await deps.exerciseNames(ids) : {};

  const ops: ProgramOperation[] = [];
  for (const raw of args.operations) {
    const o = objectAt(raw, 'operation');
    const op = oneOf(o, 'op', PROGRAM_OPS);
    const workoutName = str(o, 'workout_name', 50);
    switch (op) {
      case 'add_exercise': {
        const exercise = await resolveExercise(str(o, 'exercise_name', 100), deps);
        const repsMin = optNum(o, 'reps_min', 1, 100, true) ?? 8;
        ops.push({
          op,
          workout_name: workoutName,
          exercise_id: exercise.id,
          exercise_name: exercise.name,
          sets: optNum(o, 'sets', 1, 10, true) ?? 3,
          reps_min: repsMin,
          reps_max: optNum(o, 'reps_max', 1, 100, true) ?? (present(o, 'reps_min') ? repsMin : 12),
        });
        break;
      }
      case 'remove_exercise':
        ops.push({ op, workout_name: workoutName, exercise_name: str(o, 'exercise_name', 100) });
        break;
      case 'modify_exercise': {
        const sets = optNum(o, 'sets', 1, 10, true);
        const repsMin = optNum(o, 'reps_min', 1, 100, true);
        const repsMax = optNum(o, 'reps_max', 1, 100, true);
        if (sets === undefined && repsMin === undefined && repsMax === undefined) {
          throw new ToolArgError('modify_exercise needs sets, reps_min or reps_max');
        }
        ops.push({ op, workout_name: workoutName, exercise_name: str(o, 'exercise_name', 100), sets, reps_min: repsMin, reps_max: repsMax });
        break;
      }
      case 'rename_workout':
        ops.push({ op, workout_name: workoutName, new_name: str(o, 'new_name', 50) });
        break;
    }
  }

  const { program, changes } = applyProgramOperations(snapshot, ops, names);
  const labels = LABELS[ctx.locale];
  return {
    ok: true,
    tool: 'edit_program',
    summary: `${labels.program}: ${program.name} (${changes.length} ${labels.changes})`,
    payload: { program_id: active.id, program, changes },
  };
}
