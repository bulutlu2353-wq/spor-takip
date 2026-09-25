import { sqlString } from './exercise_seed.ts';
import type { BlockDef, ProgramDef } from './program_types.ts';

const TM_TO_1RM = 0.9;

const hex = (n: number, width: number) => n.toString(16).padStart(width, '0');

export const programId = (n: number) => `f3000000-0000-4000-8000-${hex(n, 12)}`;
export const workoutId = (n: number, w: number) => `f3000000-${hex(n, 4)}-4000-8000-${hex(w, 12)}`;
export const blockId = (n: number, w: number, b: number) =>
  `f3000000-${hex(n, 4)}-4000-${hex(w, 4)}-${hex(b, 12)}`;

export function toOneRmPercent(block: BlockDef): number | null {
  if (block.pct1rm !== undefined) return block.pct1rm;
  if (block.pctTm !== undefined) return Math.round(block.pctTm * TM_TO_1RM * 100) / 100;
  return null;
}

const repsOf = (b: BlockDef): [number, number] => (Array.isArray(b.reps) ? b.reps : [b.reps, b.reps]);

export function validatePrograms(programs: ProgramDef[], exerciseIds: Set<string>): string[] {
  const errors: string[] = [];
  for (const p of programs) {
    const seenWeekdays = new Set<number>();
    p.workouts.forEach((w, wi) => {
      const where = `${p.name} / ${w.name} (#${wi})`;
      if (p.scheduleMode === 'weekdays') {
        if (w.weekday === undefined) errors.push(`${where}: weekday eksik`);
        else if (seenWeekdays.has(w.weekday)) errors.push(`${where}: weekday ${w.weekday} tekrar ediyor`);
        else seenWeekdays.add(w.weekday);
      } else if (w.weekday !== undefined) {
        errors.push(`${where}: rotation modunda weekday olmamalı`);
      }
      w.blocks.forEach((b, bi) => {
        const at = `${where} blok ${bi}`;
        if (!exerciseIds.has(b.exercise)) errors.push(`${at}: bilinmeyen hareket ${b.exercise}`);
        if (b.pctRef && !exerciseIds.has(b.pctRef)) errors.push(`${at}: bilinmeyen referans ${b.pctRef}`);
        if (b.sets < 1) errors.push(`${at}: sets < 1`);
        const [min, max] = repsOf(b);
        if (min < 1 || max < min) errors.push(`${at}: geçersiz reps ${min}-${max}`);
        const pct = toOneRmPercent(b);
        if (pct !== null && (pct <= 0 || pct > 100)) errors.push(`${at}: geçersiz yüzde ${pct}`);
      });
    });
  }
  return errors;
}

const num = (v: number | null | undefined) => (v === null || v === undefined ? 'null' : String(v));
const ON_CONFLICT = '\non conflict (id) do nothing;';

export function buildProgramSeedSql(programs: ProgramDef[]): string {
  const lines: string[] = [
    '-- Üretildi: deno run --allow-read --allow-write tool/generate_program_seed.ts',
    '-- Kaynak: tool/programs.ts (her programın kaynak linki orada)',
  ];
  for (const p of programs) {
    lines.push(
      '',
      `-- ${p.name}`,
      'insert into public.programs (id, user_id, name, description, level, schedule_mode, days_per_week) values',
      `  ('${programId(p.n)}', null, ${sqlString(p.name)}, ${sqlString(p.description)}, '${p.level}', ` +
        `'${p.scheduleMode}', ${p.daysPerWeek})${ON_CONFLICT}`,
      'insert into public.program_workouts (id, program_id, position, name, weekday) values',
      p.workouts
        .map((w, wi) => `  ('${workoutId(p.n, wi)}', '${programId(p.n)}', ${wi}, ${sqlString(w.name)}, ${num(w.weekday)})`)
        .join(',\n') + ON_CONFLICT,
      'insert into public.workout_exercises (id, workout_id, position, exercise_id, sets, reps_min, reps_max, ' +
        'is_amrap, percent_1rm, percent_ref_exercise_id, rest_seconds, notes) values',
    );
    const blockRows: string[] = [];
    p.workouts.forEach((w, wi) =>
      w.blocks.forEach((b, bi) => {
        const [min, max] = repsOf(b);
        blockRows.push(
          `  ('${blockId(p.n, wi, bi)}', '${workoutId(p.n, wi)}', ${bi}, ${sqlString(b.exercise)}, ${b.sets}, ` +
            `${min}, ${max}, ${b.amrap ? 'true' : 'false'}, ${num(toOneRmPercent(b))}, ${sqlString(b.pctRef)}, ` +
            `${num(b.rest)}, ${sqlString(b.notes)})`,
        );
      })
    );
    lines.push(blockRows.join(',\n') + ON_CONFLICT);
  }
  return lines.join('\n') + '\n';
}
