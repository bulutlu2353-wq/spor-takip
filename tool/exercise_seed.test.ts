import { assertEquals, assertStringIncludes } from 'https://deno.land/std@0.224.0/assert/mod.ts';
import { buildExerciseSeedSql, sqlString, sqlTextArray } from './exercise_seed.ts';
import type { RawExercise } from './exercise_seed.ts';

const squat: RawExercise = {
  id: 'Barbell_Squat',
  name: 'Barbell Squat',
  category: 'strength',
  equipment: 'barbell',
  level: 'beginner',
  primaryMuscles: ['quadriceps'],
  secondaryMuscles: ['glutes', 'hamstrings'],
  instructions: ["Keep your back straight, don't round it."],
  images: ['Barbell_Squat/0.jpg', 'Barbell_Squat/1.jpg'],
};

Deno.test('sqlString escapes single quotes and maps null to NULL', () => {
  assertEquals(sqlString("don't"), "'don''t'");
  assertEquals(sqlString(null), 'null');
  assertEquals(sqlString(undefined), 'null');
});

Deno.test('sqlTextArray builds a typed text[] literal', () => {
  assertEquals(sqlTextArray([]), "'{}'::text[]");
  assertEquals(sqlTextArray(['a', "b'c"]), "array['a', 'b''c']::text[]");
});

Deno.test('buildExerciseSeedSql inserts every exercise with user_id null and is idempotent', () => {
  const sql = buildExerciseSeedSql([squat, { ...squat, id: 'Pullups', name: 'Pullups', equipment: null }]);
  assertStringIncludes(sql, 'insert into public.exercises');
  assertStringIncludes(sql, "('Barbell_Squat', null, 'Barbell Squat', 'strength', 'barbell', 'beginner'");
  assertStringIncludes(sql, "array['Keep your back straight, don''t round it.']::text[]");
  assertStringIncludes(sql, "('Pullups', null, 'Pullups', 'strength', null, 'beginner'");
  assertStringIncludes(sql, 'on conflict (id) do nothing;');
});
