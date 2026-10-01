// edit_program aracının program üzerindeki işlemleri (saf fonksiyonlar).

export interface ProgramExercise {
  exercise_id: string;
  sets: number;
  reps_min: number;
  reps_max: number;
  is_amrap?: boolean;
  percent_1rm?: number | null;
  percent_ref_exercise_id?: string | null;
  rest_seconds?: number | null;
  notes?: string | null;
}

export interface ProgramWorkout {
  name: string;
  weekday: number | null;
  exercises: ProgramExercise[];
}

/** `program_snapshot` / `save_program` formatı. */
export interface ProgramSnapshot {
  id: string;
  name: string;
  description: string | null;
  level: string | null;
  schedule_mode: string;
  days_per_week: number | null;
  source_program_id: string | null;
  workouts: ProgramWorkout[];
}

export type ProgramOperation =
  | { op: 'add_exercise'; workout_name: string; exercise_id: string; exercise_name: string; sets: number; reps_min: number; reps_max: number }
  | { op: 'remove_exercise'; workout_name: string; exercise_name: string }
  | { op: 'modify_exercise'; workout_name: string; exercise_name: string; sets?: number; reps_min?: number; reps_max?: number }
  | { op: 'rename_workout'; workout_name: string; new_name: string };

export interface ProgramChange {
  kind: 'add' | 'remove' | 'modify' | 'rename';
  label: string;
}

export class ProgramOpError extends Error {
  constructor(message: string, readonly candidates: string[] = []) {
    super(message);
  }
}

function same(a: string, b: string): boolean {
  return a.trim().toLowerCase() === b.trim().toLowerCase();
}

function scheme(sets: number, min: number, max: number): string {
  return `${sets}×${min === max ? min : `${min}–${max}`}`;
}

function validate(sets: number, min: number, max: number): void {
  if (!Number.isInteger(sets) || sets < 1 || sets > 10) throw new ProgramOpError('sets must be an integer 1-10');
  if (!Number.isInteger(min) || min < 1 || min > 100) throw new ProgramOpError('reps_min must be an integer 1-100');
  if (!Number.isInteger(max) || max < min || max > 100) throw new ProgramOpError('reps_max must be an integer between reps_min and 100');
}

export function applyProgramOperations(
  input: ProgramSnapshot,
  ops: ProgramOperation[],
  names: Record<string, string>,
): { program: ProgramSnapshot; changes: ProgramChange[] } {
  const program: ProgramSnapshot = structuredClone(input);
  const nameMap: Record<string, string> = { ...names };
  const changes: ProgramChange[] = [];

  const findWorkout = (name: string): ProgramWorkout => {
    const workout = program.workouts.find((w) => same(w.name, name));
    if (!workout) {
      throw new ProgramOpError(`workout "${name}" not found`, program.workouts.map((w) => w.name));
    }
    return workout;
  };
  const nameOf = (exercise: ProgramExercise) => nameMap[exercise.exercise_id] ?? exercise.exercise_id;
  const findExerciseIndex = (workout: ProgramWorkout, name: string): number => {
    const index = workout.exercises.findIndex((e) => same(nameOf(e), name));
    if (index < 0) {
      throw new ProgramOpError(`exercise "${name}" not found in workout "${workout.name}"`, workout.exercises.map(nameOf));
    }
    return index;
  };

  for (const op of ops) {
    const workout = findWorkout(op.workout_name);
    switch (op.op) {
      case 'add_exercise': {
        validate(op.sets, op.reps_min, op.reps_max);
        workout.exercises.push({ exercise_id: op.exercise_id, sets: op.sets, reps_min: op.reps_min, reps_max: op.reps_max });
        nameMap[op.exercise_id] = op.exercise_name;
        changes.push({ kind: 'add', label: `+ ${workout.name}: ${op.exercise_name} ${scheme(op.sets, op.reps_min, op.reps_max)}` });
        break;
      }
      case 'remove_exercise': {
        const [removed] = workout.exercises.splice(findExerciseIndex(workout, op.exercise_name), 1);
        changes.push({ kind: 'remove', label: `− ${workout.name}: ${nameOf(removed)}` });
        break;
      }
      case 'modify_exercise': {
        const exercise = workout.exercises[findExerciseIndex(workout, op.exercise_name)];
        const before = scheme(exercise.sets, exercise.reps_min, exercise.reps_max);
        const sets = op.sets ?? exercise.sets;
        const min = op.reps_min ?? exercise.reps_min;
        const max = op.reps_max ?? exercise.reps_max;
        validate(sets, min, max);
        exercise.sets = sets;
        exercise.reps_min = min;
        exercise.reps_max = max;
        changes.push({ kind: 'modify', label: `~ ${workout.name}: ${nameOf(exercise)} ${before} → ${scheme(sets, min, max)}` });
        break;
      }
      case 'rename_workout': {
        const newName = op.new_name.trim();
        if (newName.length === 0 || newName.length > 50) throw new ProgramOpError('new_name must be 1-50 characters');
        changes.push({ kind: 'rename', label: `✎ ${workout.name} → ${newName}` });
        workout.name = newName;
        break;
      }
    }
  }
  return { program, changes };
}
