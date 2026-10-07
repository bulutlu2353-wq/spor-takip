import type { LlmMessage } from './llm/types.ts';
import type { ContextData, EventStatus, SetRow, StoredMessage } from './types.ts';

const MINUTE_MS = 60_000;

/** Cihazın yerel günü (YYYY-MM-DD). */
export function localDate(now: Date, utcOffsetMinutes: number): string {
  return new Date(now.getTime() + utcOffsetMinutes * MINUTE_MS).toISOString().slice(0, 10);
}

function localTime(iso: string, utcOffsetMinutes: number): string {
  return new Date(new Date(iso).getTime() + utcOffsetMinutes * MINUTE_MS).toISOString().slice(11, 16);
}

function fmt(value: number): string {
  return String(Math.round(value * 10) / 10);
}

function repsLabel(min: number, max: number): string {
  return min === max ? `${min}` : `${min}-${max}`;
}

function kgLabel(kg: number | null): string {
  return kg === null ? 'bodyweight' : fmt(kg);
}

/** Hareket başına en ağır (eşitse en çok tekrarlı) set; ilk görülme sırasıyla. */
function bestSets(sets: SetRow[]): string {
  const best = new Map<string, SetRow>();
  for (const set of sets) {
    const current = best.get(set.exercise_name);
    const kg = set.weight_kg ?? 0;
    const currentKg = current?.weight_kg ?? 0;
    if (!current || kg > currentKg || (kg === currentKg && (set.reps ?? 0) > (current.reps ?? 0))) {
      best.set(set.exercise_name, set);
    }
  }
  return [...best.values()].map((s) => `${s.exercise_name} ${kgLabel(s.weight_kg)}x${s.reps ?? 0}`).join(', ');
}

/** LLM'e giden veri özeti (etiketler İngilizce; cevap dili sistem talimatında). */
export function buildContextText(data: ContextData, utcOffsetMinutes: number): string {
  const lines: string[] = ['## Profile'];
  const p = data.profile;
  if (p) {
    lines.push(`weight_kg: ${fmt(p.weight_kg)}, height_cm: ${fmt(p.height_cm)}, birth_year: ${p.birth_year}, gender: ${p.gender}`);
    lines.push(
      `activity_level: ${p.activity_level}, does_exercise: ${p.does_exercise}, sport_type: ${p.sport_type ?? '-'}, ` +
        `exercise_days_per_week: ${p.exercise_days_per_week}`,
    );
    const goal = p.pace ? `${p.weight_direction}/${p.pace}` : p.weight_direction;
    lines.push(
      `goal: ${goal}, focuses: ${p.focuses.length > 0 ? p.focuses.join(',') : '-'}, ` +
        `daily_calorie_target: ${Math.round(p.daily_calorie_target)} kcal, ` +
        `daily_protein_target_g: ${Math.round(p.daily_protein_target_g)}`,
    );
    if (p.health_notes) lines.push(`health_notes: ${p.health_notes}`);
  } else {
    lines.push('none');
  }

  lines.push('', `## Today's meals (${data.today})`);
  if (data.todayMeals.length === 0) {
    lines.push('none logged');
  } else {
    let kcal = 0, protein = 0, carbs = 0, fat = 0;
    for (const meal of data.todayMeals) {
      const items = meal.items.map((i) => `${i.name} ${fmt(i.grams)} g`).join(', ');
      const mealKcal = meal.items.reduce((sum, i) => sum + i.calories, 0);
      lines.push(`- ${meal.meal_type} ${localTime(meal.logged_at, utcOffsetMinutes)}: ${items} (${Math.round(mealKcal)} kcal)`);
      for (const i of meal.items) {
        kcal += i.calories;
        protein += i.protein_g;
        carbs += i.carbs_g;
        fat += i.fat_g;
      }
    }
    lines.push(`totals: ${Math.round(kcal)} kcal, protein ${fmt(protein)} g, carbs ${fmt(carbs)} g, fat ${fmt(fat)} g`);
  }

  lines.push('', '## Body weight (last 30 days)');
  lines.push(data.weights.length === 0 ? 'none' : data.weights.map((w) => `${w.logged_on}: ${fmt(w.weight_kg)}`).join(', '));

  lines.push('', '## Recent workouts');
  if (data.recentSessions.length === 0) lines.push('none');
  for (const session of data.recentSessions) {
    lines.push(`- ${localDate(new Date(session.finished_at), utcOffsetMinutes)} ${session.workout_name}: ${bestSets(session.sets)}`);
  }

  lines.push('');
  const program = data.activeProgram;
  if (!program) {
    lines.push('## Active program: none');
  } else {
    lines.push(`## Active program: ${program.name} (${program.is_builtin ? 'built-in, read-only' : 'own, editable'})`);
    for (const workout of program.workouts) {
      const exercises = workout.exercises.map((e) => `${e.name} ${e.sets}x${repsLabel(e.reps_min, e.reps_max)}`);
      lines.push(`- ${workout.name}: ${exercises.join(', ')}`);
    }
  }

  lines.push('');
  const live = data.inProgress;
  if (!live) {
    lines.push('## In-progress workout: none');
  } else {
    lines.push(`## In-progress workout: ${live.workout_name}`);
    for (const set of live.sets) {
      const state = set.completed
        ? `done ${set.weight_kg === null ? 'bodyweight' : `${fmt(set.weight_kg)} kg`} x ${set.reps ?? 0}`
        : 'not done';
      lines.push(`- ${set.exercise_name} set ${set.set_index + 1}: target ${repsLabel(set.target_reps_min, set.target_reps_max)}, ${state}`);
    }
  }

  lines.push('', '## 1RM');
  lines.push(
    data.oneRepMaxes.length === 0 ? 'none' : data.oneRepMaxes.map((o) => `${o.exercise_name}: ${fmt(o.weight_kg)} kg`).join(', '),
  );
  return lines.join('\n');
}

const STATUS_NOTES: Record<EventStatus, string> = {
  pending: '[proposed change awaiting user confirmation]',
  applied: '[user confirmed; change applied]',
  cancelled: '[user declined the change]',
  undone: '[change was applied, then the user undid it]',
  stale: '[not applied: data changed before confirmation]',
};

/** Kayıtlı geçmiş → LLM mesajları; öneri kartlarının durumu metne eklenir. */
export function historyToLlmMessages(history: StoredMessage[]): LlmMessage[] {
  return history.map((message): LlmMessage => {
    if (message.role === 'user') return { role: 'user', text: message.content };
    const note = message.event ? `\n${message.event.summary} ${STATUS_NOTES[message.event.status]}` : '';
    return { role: 'assistant', text: `${message.content}${note}` };
  });
}
