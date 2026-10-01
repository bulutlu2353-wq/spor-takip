import type { SupabaseClient } from 'jsr:@supabase/supabase-js@2';
import { fetchMacrosPer100g, findBestMatch } from '../_shared/usda_client.ts';
import type { ChatStore } from './handler.ts';
import type { ProgramSnapshot } from './program_ops.ts';
import type { ToolDeps } from './tools.ts';
import type {
  ContextData,
  InProgressSession,
  MealRow,
  NewEvent,
  ProfileRow,
  ProgramView,
  SessionSummary,
  StoredMessage,
  ToolName,
} from './types.ts';

// deno-lint-ignore no-explicit-any
type Row = Record<string, any>;

const DAY_MS = 24 * 60 * 60 * 1000;

function check<T>(result: { data: unknown; error: unknown }, what: string): T {
  if (result.error) throw new Error(`${what} failed: ${JSON.stringify(result.error)}`);
  return result.data as T;
}

function byPosition(rows: Row[]): Row[] {
  return [...rows].sort((a, b) => a.exercise_position - b.exercise_position || a.set_index - b.set_index);
}

/** Tüm sorgular kullanıcının JWT'siyle gider; RLS kullanıcıyı sınırlar. */
export class SupabaseChatStore implements ChatStore {
  constructor(private readonly client: SupabaseClient) {}

  async countUsageSince(since: Date): Promise<number> {
    const { count, error } = await this.client
      .from('chat_usage')
      .select('id', { count: 'exact', head: true })
      .gte('created_at', since.toISOString());
    if (error) throw new Error(`chat_usage count failed: ${JSON.stringify(error)}`);
    return count ?? 0;
  }

  async recentMessages(limit: number): Promise<StoredMessage[]> {
    return check(await this.client.rpc('recent_chat_messages', { p_limit: limit }), 'recent_chat_messages');
  }

  async targetSnapshot(tool: ToolName, payload: Record<string, unknown>): Promise<unknown> {
    return check(await this.client.rpc('chat_target_snapshot', { p_tool: tool, p_payload: payload }), 'chat_target_snapshot');
  }

  async saveExchange(userText: string, assistantText: string, event: NewEvent | null): Promise<StoredMessage[]> {
    return check(
      await this.client.rpc('save_chat_exchange', { p_user_text: userText, p_assistant_text: assistantText, p_event: event }),
      'save_chat_exchange',
    );
  }

  async loadContext(range: { today: string; dayStart: Date; dayEnd: Date }): Promise<ContextData> {
    const weightsSince = new Date(Date.parse(`${range.today}T00:00:00Z`) - 30 * DAY_MS).toISOString().slice(0, 10);
    const [profileRes, mealsRes, weightsRes, sessionsRes, liveRes, ormRes] = await Promise.all([
      this.client.from('profiles').select('*').maybeSingle(),
      this.client
        .from('meals')
        .select('meal_type, logged_at, meal_items(name, grams, calories, protein_g, carbs_g, fat_g)')
        .gte('logged_at', range.dayStart.toISOString())
        .lt('logged_at', range.dayEnd.toISOString())
        .order('logged_at'),
      this.client.from('body_weight_logs').select('logged_on, weight_kg').gte('logged_on', weightsSince).order('logged_on'),
      this.client
        .from('workout_sessions')
        .select('workout_name, finished_at, session_sets(exercise_position, set_index, weight_kg, reps, completed_at, exercises!exercise_id(name))')
        .not('finished_at', 'is', null)
        .order('finished_at', { ascending: false })
        .limit(5),
      this.client
        .from('workout_sessions')
        .select('id, workout_name, session_sets(exercise_position, set_index, target_reps_min, target_reps_max, weight_kg, reps, completed_at, exercises!exercise_id(name))')
        .is('finished_at', null)
        .maybeSingle(),
      this.client.from('user_one_rep_maxes').select('weight_kg, exercises(name)'),
    ]);

    const profile = check<ProfileRow | null>(profileRes, 'profiles');
    const todayMeals: MealRow[] = check<Row[]>(mealsRes, 'meals').map((m) => ({
      meal_type: m.meal_type,
      logged_at: m.logged_at,
      items: m.meal_items ?? [],
    }));
    const weights = check<Array<{ logged_on: string; weight_kg: number }>>(weightsRes, 'body_weight_logs');
    const recentSessions: SessionSummary[] = check<Row[]>(sessionsRes, 'workout_sessions').map((s) => ({
      workout_name: s.workout_name,
      finished_at: s.finished_at,
      sets: byPosition(s.session_sets ?? [])
        .filter((set) => set.completed_at !== null)
        .map((set) => ({ exercise_name: set.exercises?.name ?? '?', weight_kg: set.weight_kg, reps: set.reps })),
    }));
    const live = check<Row | null>(liveRes, 'in-progress session');
    const inProgress: InProgressSession | null = live && {
      id: live.id,
      workout_name: live.workout_name,
      sets: byPosition(live.session_sets ?? []).map((set) => ({
        exercise_position: set.exercise_position,
        set_index: set.set_index,
        exercise_name: set.exercises?.name ?? '?',
        target_reps_min: set.target_reps_min,
        target_reps_max: set.target_reps_max,
        weight_kg: set.weight_kg,
        reps: set.reps,
        completed: set.completed_at !== null,
      })),
    };
    const oneRepMaxes = check<Row[]>(ormRes, 'user_one_rep_maxes').map((r) => ({
      exercise_name: r.exercises?.name ?? '?',
      weight_kg: r.weight_kg,
    }));
    const activeProgram = profile?.active_program_id ? await this.programView(profile.active_program_id) : null;

    return { today: range.today, profile, todayMeals, weights, recentSessions, activeProgram, inProgress, oneRepMaxes };
  }

  private async programView(id: string): Promise<ProgramView | null> {
    const row = check<Row | null>(
      await this.client
        .from('programs')
        .select('id, name, user_id, program_workouts(name, position, workout_exercises(position, sets, reps_min, reps_max, exercises!exercise_id(name)))')
        .eq('id', id)
        .maybeSingle(),
      'programs',
    );
    if (!row) return null;
    const workouts = [...(row.program_workouts ?? [])]
      .sort((a: Row, b: Row) => a.position - b.position)
      .map((w: Row) => ({
        name: w.name,
        exercises: [...(w.workout_exercises ?? [])]
          .sort((a: Row, b: Row) => a.position - b.position)
          .map((e: Row) => ({ name: e.exercises?.name ?? '?', sets: e.sets, reps_min: e.reps_min, reps_max: e.reps_max })),
      }));
    return { id: row.id, name: row.name, is_builtin: row.user_id === null, workouts };
  }
}

export function supabaseToolDeps(client: SupabaseClient, usdaApiKey: string): ToolDeps {
  return {
    findExercises: async (query) => {
      const pattern = `%${query.replace(/[\\%_]/g, (c) => `\\${c}`)}%`;
      return check(await client.from('exercises').select('id, name').ilike('name', pattern).limit(10), 'exercises');
    },
    exerciseNames: async (ids) => {
      const rows = check<Array<{ id: string; name: string }>>(
        await client.from('exercises').select('id, name').in('id', ids),
        'exercises',
      );
      return Object.fromEntries(rows.map((r) => [r.id, r.name]));
    },
    programSnapshot: async (programId) =>
      check<ProgramSnapshot | null>(await client.rpc('program_snapshot', { p_program_id: programId }), 'program_snapshot'),
    findBestMatch: (query) => findBestMatch(query, usdaApiKey),
    fetchMacrosPer100g: (fdcId) => fetchMacrosPer100g(fdcId, usdaApiKey),
    newId: () => crypto.randomUUID(),
  };
}
