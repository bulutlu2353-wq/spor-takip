import { assertEquals } from 'https://deno.land/std@0.224.0/assert/mod.ts';
import type { ProgramSnapshot } from './program_ops.ts';
import { sampleContext } from './test_fixtures.ts';
import { prepareToolCall, TOOL_DEFINITIONS } from './tools.ts';
import type { ToolContext, ToolDeps } from './tools.ts';
import { TOOL_NAMES } from './types.ts';

const EXERCISES = [
  { id: 'squat', name: 'Barbell Squat' },
  { id: 'bench', name: 'Barbell Bench Press - Medium Grip' },
  { id: 'dl', name: 'Barbell Deadlift' },
  { id: 'rdl', name: 'Romanian Deadlift' },
];

function snapshot(): ProgramSnapshot {
  return {
    id: 'prog-1', name: 'My 5x5', description: null, level: null, schedule_mode: 'rotation',
    days_per_week: 3, source_program_id: null,
    workouts: [{
      name: 'A', weekday: null,
      exercises: [
        { exercise_id: 'squat', sets: 5, reps_min: 5, reps_max: 5 },
        { exercise_id: 'bench', sets: 3, reps_min: 8, reps_max: 12 },
      ],
    }],
  };
}

function deps(overrides: Partial<ToolDeps> = {}): ToolDeps {
  return {
    findExercises: async (q) => EXERCISES.filter((e) => e.name.toLowerCase().includes(q.toLowerCase())),
    exerciseNames: async (ids) => Object.fromEntries(EXERCISES.filter((e) => ids.includes(e.id)).map((e) => [e.id, e.name])),
    programSnapshot: async () => snapshot(),
    findBestMatch: async (q) => (q.includes('chicken') ? { fdcId: 171077, description: 'Chicken breast', dataType: 'Foundation' } : null),
    fetchMacrosPer100g: async () => ({ calories: 165, proteinG: 31, carbsG: 0, fatG: 3.6 }),
    newId: () => 'meal-uuid',
    ...overrides,
  };
}

// 2026-09-30 22:30 UTC = 2026-10-01 01:30, UTC+3
function ctx(overrides: Partial<ToolContext> = {}): ToolContext {
  return { data: sampleContext(), now: new Date('2026-09-30T22:30:00Z'), utcOffsetMinutes: 180, locale: 'tr', ...overrides };
}

Deno.test('tool definitions follow TOOL_NAMES', () => {
  assertEquals(TOOL_DEFINITIONS.map((t) => t.name), [...TOOL_NAMES]);
});

Deno.test('unknown tool is rejected', async () => {
  assertEquals(await prepareToolCall('delete_everything', {}, ctx(), deps()), { ok: false, error: 'unknown tool delete_everything' });
});

Deno.test('log_body_weight defaults to the local day and rounds to 0.1', async () => {
  assertEquals(await prepareToolCall('log_body_weight', { weight_kg: 82.04 }, ctx(), deps()), {
    ok: true, tool: 'log_body_weight', summary: 'Kilo kaydı: 82 kg (2026-10-01)', payload: { date: '2026-10-01', kg: 82 },
  });
});

Deno.test('log_body_weight validates range and date', async () => {
  const future = await prepareToolCall('log_body_weight', { weight_kg: 80, date: '2026-10-02' }, ctx(), deps());
  assertEquals(future, { ok: false, error: 'date cannot be in the future' });
  const invalid = await prepareToolCall('log_body_weight', { weight_kg: 80, date: '2026-02-30' }, ctx(), deps());
  assertEquals(invalid, { ok: false, error: 'date must be a valid YYYY-MM-DD' });
  const heavy = await prepareToolCall('log_body_weight', { weight_kg: 900 }, ctx(), deps());
  assertEquals(heavy, { ok: false, error: 'weight_kg must be between 20 and 400' });
});

Deno.test('update_profile collects changes and lists them in the summary', async () => {
  const result = await prepareToolCall('update_profile', { height_cm: 185, activity_level: 'active', sport_type: '' }, ctx(), deps());
  assertEquals(result, {
    ok: true, tool: 'update_profile', summary: 'Profil güncelleme: boy, aktivite, spor türü',
    payload: { changes: { height_cm: 185, activity_level: 'active', sport_type: null } },
  });
});

Deno.test('update_profile rejects weight and empty changes', async () => {
  const weight = await prepareToolCall('update_profile', { weight_kg: 80 }, ctx(), deps());
  assertEquals(weight.ok, false);
  assertEquals(await prepareToolCall('update_profile', {}, ctx(), deps()), { ok: false, error: 'at least one field is required' });
  const days = await prepareToolCall('update_profile', { exercise_days_per_week: 2.5 }, ctx(), deps());
  assertEquals(days, { ok: false, error: 'exercise_days_per_week must be an integer' });
});

Deno.test('set_goal rejects the current goal and summarizes in the locale', async () => {
  assertEquals(await prepareToolCall('set_goal', { goal: 'gain_muscle' }, ctx(), deps()), { ok: false, error: 'goal is already gain_muscle' });
  assertEquals(await prepareToolCall('set_goal', { goal: 'lose_weight' }, ctx({ locale: 'en' }), deps()), {
    ok: true, tool: 'set_goal', summary: 'Change goal: Lose weight', payload: { goal: 'lose_weight' },
  });
});

Deno.test('create_meal looks up USDA per-100 g macros and marks misses for review', async () => {
  const result = await prepareToolCall('create_meal', {
    meal_type: 'lunch',
    time: '12:30',
    items: [
      { name: 'Tavuk', grams: 200, usda_query: 'grilled chicken breast' },
      { name: 'Ayran', grams: 200.4, usda_query: 'ayran' },
    ],
  }, ctx(), deps());
  assertEquals(result, {
    ok: true,
    tool: 'create_meal',
    summary: 'Öğün: Öğle — Tavuk (200 g), Ayran (200 g)',
    payload: {
      meal_id: 'meal-uuid',
      meal_type: 'lunch',
      logged_at: '2026-10-01T09:30:00.000Z',
      items: [
        { name: 'Tavuk', grams: 200, per100: { calories: 165, protein_g: 31, carbs_g: 0, fat_g: 3.6 }, usda_fdc_id: '171077', needs_review: false },
        { name: 'Ayran', grams: 200, per100: { calories: 0, protein_g: 0, carbs_g: 0, fat_g: 0 }, usda_fdc_id: null, needs_review: true },
      ],
    },
  });
});

Deno.test('create_meal defaults to now and survives a USDA failure', async () => {
  const result = await prepareToolCall('create_meal', {
    meal_type: 'snack', items: [{ name: 'Tavuk', grams: 100, usda_query: 'chicken' }],
  }, ctx(), deps({ findBestMatch: () => Promise.reject(new Error('USDA down')) }));
  assertEquals(result.ok && result.payload.logged_at, '2026-09-30T22:30:00.000Z');
  assertEquals(result.ok && (result.payload.items as Array<{ needs_review: boolean }>)[0].needs_review, true);
});

Deno.test('create_meal validates items and time', async () => {
  assertEquals(await prepareToolCall('create_meal', { meal_type: 'lunch', items: [] }, ctx(), deps()), { ok: false, error: 'items must have 1-15 entries' });
  const badTime = await prepareToolCall('create_meal', { meal_type: 'lunch', time: '25:00', items: [{ name: 'x', grams: 1, usda_query: 'x' }] }, ctx(), deps());
  assertEquals(badTime, { ok: false, error: 'time must be HH:MM' });
});

Deno.test('log_set maps the 1-based set number to the in-progress set', async () => {
  assertEquals(await prepareToolCall('log_set', { exercise_name: 'barbell squat', set_number: 2, weight_kg: 100, reps: 5 }, ctx(), deps()), {
    ok: true, tool: 'log_set', summary: 'Set kaydı: Barbell Squat 2. set — 100 kg × 5',
    payload: { session_id: 'session-1', exercise_position: 0, set_index: 1, weight_kg: 100, reps: 5, exercise_name: 'Barbell Squat', set_number: 2 },
  });
});

Deno.test('log_set errors list candidates or explain the problem', async () => {
  assertEquals(await prepareToolCall('log_set', { exercise_name: 'Deadlift', set_number: 1, weight_kg: 100, reps: 5 }, ctx(), deps()), {
    ok: false, error: 'exercise "Deadlift" is not in the in-progress workout', candidates: ['Barbell Squat'],
  });
  assertEquals(await prepareToolCall('log_set', { exercise_name: 'Barbell Squat', set_number: 3, weight_kg: 100, reps: 5 }, ctx(), deps()), {
    ok: false, error: 'Barbell Squat has no set 3 (it has 2 sets)',
  });
  const idle = ctx({ data: { ...sampleContext(), inProgress: null } });
  assertEquals(await prepareToolCall('log_set', { exercise_name: 'Barbell Squat', set_number: 1, weight_kg: 100, reps: 5 }, idle, deps()), {
    ok: false, error: 'there is no workout in progress',
  });
});

Deno.test('edit_program resolves exercise names and returns the full new program', async () => {
  const result = await prepareToolCall('edit_program', {
    operations: [
      { op: 'add_exercise', workout_name: 'A', exercise_name: 'Barbell Deadlift', sets: 1, reps_min: 5 },
      { op: 'modify_exercise', workout_name: 'A', exercise_name: 'Barbell Squat', sets: 3 },
    ],
  }, ctx(), deps());
  assertEquals(result.ok, true);
  if (!result.ok) return;
  assertEquals(result.summary, 'Program düzenleme: My 5x5 (2 değişiklik)');
  assertEquals(result.payload.program_id, 'prog-1');
  const program = result.payload.program as ProgramSnapshot;
  assertEquals(program.workouts[0].exercises.map((e) => [e.exercise_id, e.sets, e.reps_min, e.reps_max]), [
    ['squat', 3, 5, 5], ['bench', 3, 8, 12], ['dl', 1, 5, 5],
  ]);
  assertEquals(result.payload.changes, [
    { kind: 'add', label: '+ A: Barbell Deadlift 1×5' },
    { kind: 'modify', label: '~ A: Barbell Squat 5×5 → 3×5' },
  ]);
});

Deno.test('edit_program defaults new exercises to 3x8-12', async () => {
  const result = await prepareToolCall('edit_program', {
    operations: [{ op: 'add_exercise', workout_name: 'A', exercise_name: 'Romanian Deadlift' }],
  }, ctx(), deps());
  assertEquals(result.ok && result.payload.changes, [{ kind: 'add', label: '+ A: Romanian Deadlift 3×8–12' }]);
});

Deno.test('edit_program returns candidates for ambiguous names and rejects built-in programs', async () => {
  assertEquals(await prepareToolCall('edit_program', {
    operations: [{ op: 'add_exercise', workout_name: 'A', exercise_name: 'deadlift' }],
  }, ctx(), deps()), {
    ok: false, error: '"deadlift" matches several exercises; pick one', candidates: ['Barbell Deadlift', 'Romanian Deadlift'],
  });
  const data = sampleContext();
  data.activeProgram = { ...data.activeProgram!, is_builtin: true };
  const builtIn = await prepareToolCall('edit_program', { operations: [{ op: 'rename_workout', workout_name: 'A', new_name: 'B' }] }, ctx({ data }), deps());
  assertEquals(builtIn.ok, false);
});

Deno.test('edit_program passes program operation errors back with candidates', async () => {
  assertEquals(await prepareToolCall('edit_program', {
    operations: [{ op: 'remove_exercise', workout_name: 'A', exercise_name: 'Pullups' }],
  }, ctx(), deps()), {
    ok: false,
    error: 'exercise "Pullups" not found in workout "A"',
    candidates: ['Barbell Squat', 'Barbell Bench Press - Medium Grip'],
  });
});
