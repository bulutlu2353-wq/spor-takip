export interface RawExercise {
  id: string;
  name: string;
  category?: string | null;
  equipment?: string | null;
  level?: string | null;
  primaryMuscles: string[];
  secondaryMuscles: string[];
  instructions: string[];
  images: string[];
}

export function sqlString(value: string | null | undefined): string {
  if (value === null || value === undefined) return 'null';
  return `'${value.replaceAll("'", "''")}'`;
}

export function sqlTextArray(values: string[]): string {
  if (values.length === 0) return "'{}'::text[]";
  return `array[${values.map(sqlString).join(', ')}]::text[]`;
}

function row(e: RawExercise): string {
  return `(${[
    sqlString(e.id),
    'null',
    sqlString(e.name),
    sqlString(e.category),
    sqlString(e.equipment),
    sqlString(e.level),
    sqlTextArray(e.primaryMuscles),
    sqlTextArray(e.secondaryMuscles),
    sqlTextArray(e.instructions),
    sqlTextArray(e.images),
  ].join(', ')})`;
}

export function buildExerciseSeedSql(exercises: RawExercise[]): string {
  return (
    '-- Üretildi: deno run --allow-net --allow-write tool/generate_exercise_seed.ts\n' +
    '-- Kaynak: https://github.com/yuhonas/free-exercise-db (Unlicense)\n' +
    'insert into public.exercises\n' +
    '  (id, user_id, name, category, equipment, level, primary_muscles, secondary_muscles, instructions, images)\n' +
    'values\n' +
    exercises.map(row).join(',\n') +
    '\non conflict (id) do nothing;\n'
  );
}
