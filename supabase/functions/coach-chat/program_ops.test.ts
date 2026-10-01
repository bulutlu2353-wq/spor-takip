import { assertEquals, assertThrows } from 'https://deno.land/std@0.224.0/assert/mod.ts';
import { applyProgramOperations, ProgramOpError } from './program_ops.ts';
import type { ProgramSnapshot } from './program_ops.ts';

function program(): ProgramSnapshot {
  return {
    id: 'prog-1', name: 'My 5x5', description: null, level: null, schedule_mode: 'rotation',
    days_per_week: 3, source_program_id: null,
    workouts: [
      {
        name: 'A', weekday: null,
        exercises: [
          { exercise_id: 'squat', sets: 5, reps_min: 5, reps_max: 5, is_amrap: false, percent_1rm: null, percent_ref_exercise_id: null, rest_seconds: 180, notes: null },
          { exercise_id: 'bench', sets: 3, reps_min: 8, reps_max: 12, is_amrap: false, percent_1rm: null, percent_ref_exercise_id: null, rest_seconds: null, notes: null },
        ],
      },
      { name: 'B', weekday: null, exercises: [] },
    ],
  };
}

const names = { squat: 'Barbell Squat', bench: 'Barbell Bench Press' };

Deno.test('adds an exercise at the end of the workout', () => {
  const { program: result, changes } = applyProgramOperations(program(), [
    { op: 'add_exercise', workout_name: 'b', exercise_id: 'dl', exercise_name: 'Barbell Deadlift', sets: 1, reps_min: 5, reps_max: 5 },
  ], names);
  assertEquals(result.workouts[1].exercises, [{ exercise_id: 'dl', sets: 1, reps_min: 5, reps_max: 5 }]);
  assertEquals(changes, [{ kind: 'add', label: '+ B: Barbell Deadlift 1×5' }]);
});

Deno.test('removes an exercise by name', () => {
  const { program: result, changes } = applyProgramOperations(program(), [
    { op: 'remove_exercise', workout_name: 'A', exercise_name: ' barbell bench press ' },
  ], names);
  assertEquals(result.workouts[0].exercises.map((e) => e.exercise_id), ['squat']);
  assertEquals(changes, [{ kind: 'remove', label: '− A: Barbell Bench Press' }]);
});

Deno.test('modifies sets and reps and keeps other fields', () => {
  const { program: result, changes } = applyProgramOperations(program(), [
    { op: 'modify_exercise', workout_name: 'A', exercise_name: 'Barbell Squat', sets: 3, reps_max: 8 },
  ], names);
  assertEquals(result.workouts[0].exercises[0], {
    exercise_id: 'squat', sets: 3, reps_min: 5, reps_max: 8, is_amrap: false, percent_1rm: null,
    percent_ref_exercise_id: null, rest_seconds: 180, notes: null,
  });
  assertEquals(changes, [{ kind: 'modify', label: '~ A: Barbell Squat 5×5 → 3×5–8' }]);
});

Deno.test('renames a workout', () => {
  const { program: result, changes } = applyProgramOperations(program(), [
    { op: 'rename_workout', workout_name: 'A', new_name: 'Push' },
  ], names);
  assertEquals(result.workouts[0].name, 'Push');
  assertEquals(changes, [{ kind: 'rename', label: '✎ A → Push' }]);
});

Deno.test('does not mutate the input program', () => {
  const input = program();
  applyProgramOperations(input, [{ op: 'remove_exercise', workout_name: 'A', exercise_name: 'Barbell Squat' }], names);
  assertEquals(input.workouts[0].exercises.length, 2);
});

Deno.test('unknown workout lists the workout names as candidates', () => {
  const error = assertThrows(
    () => applyProgramOperations(program(), [{ op: 'rename_workout', workout_name: 'C', new_name: 'x' }], names),
    ProgramOpError,
  );
  assertEquals(error.candidates, ['A', 'B']);
});

Deno.test('unknown exercise lists the workout exercises as candidates', () => {
  const error = assertThrows(
    () => applyProgramOperations(program(), [{ op: 'remove_exercise', workout_name: 'A', exercise_name: 'Deadlift' }], names),
    ProgramOpError,
  );
  assertEquals(error.candidates, ['Barbell Squat', 'Barbell Bench Press']);
});

Deno.test('rejects reps_max below reps_min', () => {
  assertThrows(
    () => applyProgramOperations(program(), [{ op: 'modify_exercise', workout_name: 'A', exercise_name: 'Barbell Squat', reps_max: 3 }], names),
    ProgramOpError,
    'reps_max',
  );
});

Deno.test('rejects out-of-range sets', () => {
  assertThrows(
    () => applyProgramOperations(program(), [{ op: 'modify_exercise', workout_name: 'A', exercise_name: 'Barbell Squat', sets: 11 }], names),
    ProgramOpError,
    'sets',
  );
});
