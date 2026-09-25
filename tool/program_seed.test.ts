import { assert, assertAlmostEquals, assertEquals, assertStringIncludes } from 'https://deno.land/std@0.224.0/assert/mod.ts';
import { PROGRAMS } from './programs.ts';
import type { ProgramDef } from './program_types.ts';
import { blockId, buildProgramSeedSql, programId, toOneRmPercent, validatePrograms, workoutId } from './program_seed.ts';

const exerciseIds = new Set<string>(
  JSON.parse(await Deno.readTextFile(new URL('./data/exercise_ids.json', import.meta.url))),
);

Deno.test('all 9 built-in programs are valid against the exercise dataset', () => {
  assertEquals(PROGRAMS.length, 9);
  assertEquals(validatePrograms(PROGRAMS, exerciseIds), []);
});

Deno.test('validatePrograms reports unknown exercises, duplicate/missing weekdays, bad reps and percentages', () => {
  const bad: ProgramDef = {
    n: 99,
    name: 'Bad',
    description: '',
    level: 'beginner',
    scheduleMode: 'weekdays',
    daysPerWeek: 2,
    workouts: [
      { name: 'X', weekday: 1, blocks: [{ exercise: 'Nope', sets: 1, reps: 5 }] },
      { name: 'Y', weekday: 1, blocks: [{ exercise: 'Pullups', sets: 1, reps: 5, pct1rm: 120 }] },
      { name: 'Z', blocks: [{ exercise: 'Pullups', sets: 1, reps: [10, 8] }] },
    ],
  };
  const errors = validatePrograms([bad], exerciseIds);
  assert(errors.some((e) => e.includes('Nope')));
  assert(errors.some((e) => e.includes('weekday 1')));
  assert(errors.some((e) => e.includes('120')));
  assert(errors.some((e) => e.includes('weekday eksik')));
  assert(errors.some((e) => e.includes('reps')));
});

Deno.test('toOneRmPercent converts training-max percentages to 1RM basis', () => {
  assertAlmostEquals(toOneRmPercent({ exercise: 'x', sets: 1, reps: 5, pctTm: 85 })!, 76.5);
  assertEquals(toOneRmPercent({ exercise: 'x', sets: 1, reps: 5, pct1rm: 80 }), 80);
  assertEquals(toOneRmPercent({ exercise: 'x', sets: 1, reps: 5 }), null);
});

Deno.test('5/3/1 BBB deload week main sets are lighter than every other week top set', () => {
  const bbb = PROGRAMS.find((p) => p.name === '5/3/1 Boring But Big')!;
  assertEquals(bbb.workouts.length, 16);
  const topMainPct = (w: number) =>
    Math.max(...bbb.workouts[w].blocks.filter((b) => b.notes === undefined && b.pctTm).map((b) => b.pctTm!));
  for (let w = 12; w < 16; w++) {
    for (let other = 0; other < 12; other++) {
      assert(topMainPct(w) < topMainPct(other), `deload ${w} >= ${other}`);
    }
  }
});

Deno.test('nSuns T1 has 9 sets and T2 has 8 sets per day, T2 lifts reference the parent lift', () => {
  const nsuns = PROGRAMS.find((p) => p.name.startsWith('nSuns'))!;
  for (const w of nsuns.workouts) {
    const lifts = [...new Set(w.blocks.map((b) => b.exercise))];
    assertEquals(lifts.length, 2);
    assertEquals(w.blocks.filter((b) => b.exercise === lifts[0]).length, 9);
    assertEquals(w.blocks.filter((b) => b.exercise === lifts[1]).length, 8);
  }
  const sumo = nsuns.workouts[1].blocks.find((b) => b.exercise === 'Sumo_Deadlift')!;
  assertEquals(sumo.pctRef, 'Barbell_Deadlift');
});

Deno.test('ids are deterministic valid uuids', () => {
  const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/;
  assert(uuid.test(programId(9)));
  assert(uuid.test(workoutId(9, 15)));
  assert(uuid.test(blockId(9, 15, 16)));
  assertEquals(programId(1), programId(1));
  assert(workoutId(1, 0) !== workoutId(1, 1));
});

Deno.test('buildProgramSeedSql writes idempotent inserts with 1RM-based percentages', () => {
  const sql = buildProgramSeedSql(PROGRAMS);
  assertStringIncludes(sql, `('${programId(1)}', null, 'StrongLifts 5x5'`);
  assertStringIncludes(sql, "'rotation', 3)\non conflict (id) do nothing;");
  // nSuns Sumo Deadlift ilk seti: %50 TM → %45 1RM, referans deadlift, 120 sn dinlenme
  assertStringIncludes(sql, "'Sumo_Deadlift', 1, 5, 5, false, 45, 'Barbell_Deadlift', 120, null)");
  // Açıklamadaki kesme işareti kaçırılmış olmalı
  assertStringIncludes(sql, "Arnold Schwarzenegger''in");
});
