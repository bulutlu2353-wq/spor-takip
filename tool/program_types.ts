export type Level = 'beginner' | 'intermediate' | 'advanced';
export type ScheduleMode = 'weekdays' | 'rotation';

export interface BlockDef {
  exercise: string; // free-exercise-db id
  sets: number;
  reps: number | [number, number]; // sabit tekrar veya [min, max]
  amrap?: boolean;
  pctTm?: number; // kaynaktaki training max yüzdesi (TM = %90 1RM)
  pct1rm?: number; // doğrudan 1RM yüzdesi
  pctRef?: string; // yüzdenin dayandığı hareket (yoksa `exercise`)
  rest?: number; // saniye
  notes?: string;
}

export interface WorkoutDef {
  name: string;
  weekday?: number; // ISO 1=Pzt … 7=Paz, yalnızca weekdays modunda
  blocks: BlockDef[];
}

export interface ProgramDef {
  n: number; // sabit uuid üretimi için 1..9
  name: string;
  description: string;
  level: Level;
  scheduleMode: ScheduleMode;
  daysPerWeek: number;
  workouts: WorkoutDef[];
}
