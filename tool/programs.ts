import type { BlockDef, ProgramDef, WorkoutDef } from './program_types.ts';

const SQUAT = 'Barbell_Squat';
const BENCH = 'Barbell_Bench_Press_-_Medium_Grip';
const ROW = 'Bent_Over_Barbell_Row';
const OHP = 'Standing_Military_Press';
const DEADLIFT = 'Barbell_Deadlift';

const MAIN_REST = 180;
const T2_REST = 120;
const ACC_REST = 90;

const acc = (exercise: string, sets: number, reps: number | [number, number], notes?: string): BlockDef => ({
  exercise,
  sets,
  reps,
  rest: ACC_REST,
  ...(notes ? { notes } : {}),
});

// ---------------------------------------------------------------- 1. StrongLifts 5x5
// Kaynak: https://stronglifts.com/5x5/
const strongLifts: ProgramDef = {
  n: 1,
  name: 'StrongLifts 5x5',
  description:
    'Yeni başlayanlar için en bilinen kuvvet programı. A ve B antrenmanları sırayla, haftada 3 gün ' +
    '(örn. Pzt/Çrş/Cum) yapılır. Her antrenmanda squat var; ağırlık her antrenmanda küçük adımlarla artırılır.',
  level: 'beginner',
  scheduleMode: 'rotation',
  daysPerWeek: 3,
  workouts: [
    {
      name: 'Antrenman A',
      blocks: [
        { exercise: SQUAT, sets: 5, reps: 5, rest: MAIN_REST },
        { exercise: BENCH, sets: 5, reps: 5, rest: MAIN_REST },
        { exercise: ROW, sets: 5, reps: 5, rest: MAIN_REST },
      ],
    },
    {
      name: 'Antrenman B',
      blocks: [
        { exercise: SQUAT, sets: 5, reps: 5, rest: MAIN_REST },
        { exercise: OHP, sets: 5, reps: 5, rest: MAIN_REST },
        { exercise: DEADLIFT, sets: 1, reps: 5, rest: MAIN_REST },
      ],
    },
  ],
};

// ---------------------------------------------------------------- 2. Full Body 3 gün (genel şablon)
const fullBody: ProgramDef = {
  n: 2,
  name: 'Full Body 3 gün',
  description:
    'Genel şablon: her antrenmanda tüm vücut çalışılır (bir alt vücut, bir itme, bir çekme hareketi). ' +
    'Pazartesi, Çarşamba, Cuma. Yeni başlayanlar ve zamanı kısıtlı olanlar için.',
  level: 'beginner',
  scheduleMode: 'weekdays',
  daysPerWeek: 3,
  workouts: [
    {
      name: 'Tüm Vücut A',
      weekday: 1,
      blocks: [
        { exercise: SQUAT, sets: 3, reps: [8, 12], rest: T2_REST },
        { exercise: BENCH, sets: 3, reps: [8, 12], rest: T2_REST },
        { exercise: ROW, sets: 3, reps: [8, 12], rest: T2_REST },
        acc('Hanging_Leg_Raise', 3, [10, 15]),
      ],
    },
    {
      name: 'Tüm Vücut B',
      weekday: 3,
      blocks: [
        { exercise: 'Romanian_Deadlift', sets: 3, reps: [8, 12], rest: T2_REST },
        { exercise: OHP, sets: 3, reps: [8, 12], rest: T2_REST },
        { exercise: 'Wide-Grip_Lat_Pulldown', sets: 3, reps: [8, 12], rest: T2_REST },
        acc('Dumbbell_Lunges', 3, [10, 12]),
      ],
    },
    {
      name: 'Tüm Vücut C',
      weekday: 5,
      blocks: [
        { exercise: 'Leg_Press', sets: 3, reps: [10, 12], rest: T2_REST },
        { exercise: 'Incline_Dumbbell_Press', sets: 3, reps: [8, 12], rest: T2_REST },
        { exercise: 'Seated_Cable_Rows', sets: 3, reps: [8, 12], rest: T2_REST },
        acc('Dumbbell_Bicep_Curl', 2, [10, 15]),
        acc('Triceps_Pushdown', 2, [10, 15]),
      ],
    },
  ],
};

// ---------------------------------------------------------------- 3. Upper/Lower 4 gün (genel şablon)
const upperLower: ProgramDef = {
  n: 3,
  name: 'Upper/Lower 4 gün',
  description:
    'Genel şablon: haftada iki üst vücut, iki alt vücut günü. Haftanın ilk yarısı kuvvet (düşük tekrar), ' +
    'ikinci yarısı hacim (yüksek tekrar) odaklı. Pzt/Sal/Per/Cum.',
  level: 'intermediate',
  scheduleMode: 'weekdays',
  daysPerWeek: 4,
  workouts: [
    {
      name: 'Üst Vücut (Kuvvet)',
      weekday: 1,
      blocks: [
        { exercise: BENCH, sets: 4, reps: [4, 6], rest: MAIN_REST },
        { exercise: ROW, sets: 4, reps: [4, 6], rest: MAIN_REST },
        { exercise: OHP, sets: 3, reps: [6, 8], rest: T2_REST },
        { exercise: 'Pullups', sets: 3, reps: [6, 10], rest: T2_REST },
        acc('Barbell_Curl', 2, [8, 12]),
        acc('Lying_Triceps_Press', 2, [8, 12]),
      ],
    },
    {
      name: 'Alt Vücut (Kuvvet)',
      weekday: 2,
      blocks: [
        { exercise: SQUAT, sets: 4, reps: [4, 6], rest: MAIN_REST },
        { exercise: 'Romanian_Deadlift', sets: 3, reps: [6, 8], rest: T2_REST },
        { exercise: 'Leg_Press', sets: 3, reps: [8, 10], rest: T2_REST },
        acc('Lying_Leg_Curls', 3, [8, 12]),
        acc('Standing_Calf_Raises', 4, [8, 12]),
      ],
    },
    {
      name: 'Üst Vücut (Hacim)',
      weekday: 4,
      blocks: [
        { exercise: 'Incline_Dumbbell_Press', sets: 3, reps: [8, 12], rest: T2_REST },
        { exercise: 'Seated_Cable_Rows', sets: 3, reps: [8, 12], rest: T2_REST },
        { exercise: 'Dumbbell_Shoulder_Press', sets: 3, reps: [8, 12], rest: T2_REST },
        { exercise: 'Wide-Grip_Lat_Pulldown', sets: 3, reps: [8, 12], rest: T2_REST },
        acc('Side_Lateral_Raise', 3, [12, 15]),
        acc('Hammer_Curls', 3, [10, 12]),
        acc('Triceps_Pushdown', 3, [10, 12]),
      ],
    },
    {
      name: 'Alt Vücut (Hacim)',
      weekday: 5,
      blocks: [
        { exercise: DEADLIFT, sets: 3, reps: 5, rest: MAIN_REST },
        { exercise: 'Front_Barbell_Squat', sets: 3, reps: [8, 10], rest: T2_REST },
        acc('Dumbbell_Lunges', 3, [10, 12]),
        acc('Leg_Extensions', 3, [10, 15]),
        acc('Seated_Leg_Curl', 3, [10, 15]),
        acc('Seated_Calf_Raise', 4, [10, 15]),
      ],
    },
  ],
};

// ---------------------------------------------------------------- 4. Push/Pull/Legs 6 gün
// Kaynak: r/Fitness, u/metallicadpa — https://www.reddit.com/r/Fitness/comments/37ylk5/
// Ayrıntı teyidi: https://fitfrek.com/metallicadpa-6day-ppl/
const pullAccessories: BlockDef[] = [
  acc('Wide-Grip_Lat_Pulldown', 3, [8, 12], 'Barfiks/chin-up ile değiştirilebilir'),
  acc('Seated_Cable_Rows', 3, [8, 12]),
  acc('Face_Pull', 5, [15, 20]),
  acc('Hammer_Curls', 4, [8, 12]),
  acc('Dumbbell_Bicep_Curl', 4, [8, 12]),
];
const pushAccessories: BlockDef[] = [
  acc('Incline_Dumbbell_Press', 3, [8, 12]),
  acc('Triceps_Pushdown', 3, [8, 12], 'Süperset: sonraki yan omuz açış ile'),
  acc('Side_Lateral_Raise', 3, [15, 20]),
  acc('Cable_Rope_Overhead_Triceps_Extension', 3, [8, 12], 'Süperset: sonraki yan omuz açış ile'),
  acc('Side_Lateral_Raise', 3, [15, 20]),
];
const legs: WorkoutDef = {
  name: 'Bacak',
  blocks: [
    { exercise: SQUAT, sets: 2, reps: 5, rest: MAIN_REST },
    { exercise: SQUAT, sets: 1, reps: 5, amrap: true, rest: MAIN_REST },
    acc('Romanian_Deadlift', 3, [8, 12]),
    acc('Leg_Press', 3, [8, 12]),
    acc('Lying_Leg_Curls', 3, [8, 12]),
    acc('Standing_Calf_Raises', 5, [8, 12]),
  ],
};
const ppl: ProgramDef = {
  n: 4,
  name: 'Push/Pull/Legs 6 gün',
  description:
    "r/Fitness'ın bilinen PPL programı (metallicadpa). Çekme, İtme, Bacak sırayla, haftada 6 gün. " +
    'Ana hareketin son seti "yapabildiğin kadar" (AMRAP). Deadlift/Row ve Bench/OHP antrenmanlar arasında dönüşümlü.',
  level: 'intermediate',
  scheduleMode: 'rotation',
  daysPerWeek: 6,
  workouts: [
    {
      name: 'Çekme A (Deadlift)',
      blocks: [{ exercise: DEADLIFT, sets: 1, reps: 5, amrap: true, rest: MAIN_REST }, ...pullAccessories],
    },
    {
      name: 'İtme A (Bench)',
      blocks: [
        { exercise: BENCH, sets: 4, reps: 5, rest: MAIN_REST },
        { exercise: BENCH, sets: 1, reps: 5, amrap: true, rest: MAIN_REST },
        acc(OHP, 3, [8, 12]),
        ...pushAccessories,
      ],
    },
    legs,
    {
      name: 'Çekme B (Row)',
      blocks: [
        { exercise: ROW, sets: 4, reps: 5, rest: MAIN_REST },
        { exercise: ROW, sets: 1, reps: 5, amrap: true, rest: MAIN_REST },
        ...pullAccessories,
      ],
    },
    {
      name: 'İtme B (OHP)',
      blocks: [
        { exercise: OHP, sets: 4, reps: 5, rest: MAIN_REST },
        { exercise: OHP, sets: 1, reps: 5, amrap: true, rest: MAIN_REST },
        acc(BENCH, 3, [8, 12]),
        ...pushAccessories,
      ],
    },
    legs,
  ],
};

// ---------------------------------------------------------------- 5. Bro Split 5 gün (genel şablon)
const broSplit: ProgramDef = {
  n: 5,
  name: 'Bro Split 5 gün',
  description:
    'Genel şablon: her gün tek bir bölge (Göğüs, Sırt, Omuz, Kol, Bacak), Pazartesi–Cuma. ' +
    'Vücut geliştirme odaklı klasik bölünmüş program.',
  level: 'intermediate',
  scheduleMode: 'weekdays',
  daysPerWeek: 5,
  workouts: [
    {
      name: 'Göğüs',
      weekday: 1,
      blocks: [
        { exercise: BENCH, sets: 4, reps: [6, 10], rest: MAIN_REST },
        { exercise: 'Incline_Dumbbell_Press', sets: 3, reps: [8, 12], rest: T2_REST },
        acc('Dips_-_Chest_Version', 3, [8, 12]),
        acc('Dumbbell_Flyes', 3, [10, 15]),
        acc('Cable_Crossover', 3, [12, 15]),
      ],
    },
    {
      name: 'Sırt',
      weekday: 2,
      blocks: [
        { exercise: DEADLIFT, sets: 3, reps: [5, 8], rest: MAIN_REST },
        { exercise: 'Pullups', sets: 3, reps: [6, 10], rest: T2_REST },
        { exercise: ROW, sets: 3, reps: [8, 10], rest: T2_REST },
        acc('Seated_Cable_Rows', 3, [10, 12]),
        acc('Straight-Arm_Pulldown', 3, [12, 15]),
      ],
    },
    {
      name: 'Omuz',
      weekday: 3,
      blocks: [
        { exercise: OHP, sets: 4, reps: [6, 10], rest: MAIN_REST },
        { exercise: 'Arnold_Dumbbell_Press', sets: 3, reps: [8, 12], rest: T2_REST },
        acc('Side_Lateral_Raise', 4, [12, 15]),
        acc('Reverse_Flyes', 3, [12, 15]),
        acc('Barbell_Shrug', 3, [10, 12]),
      ],
    },
    {
      name: 'Kol',
      weekday: 4,
      blocks: [
        { exercise: 'Barbell_Curl', sets: 3, reps: [8, 12], rest: T2_REST },
        { exercise: 'Close-Grip_Barbell_Bench_Press', sets: 3, reps: [6, 10], rest: T2_REST },
        acc('Hammer_Curls', 3, [10, 12]),
        acc('Lying_Triceps_Press', 3, [8, 12]),
        acc('Concentration_Curls', 2, [12, 15]),
        acc('Triceps_Pushdown_-_Rope_Attachment', 2, [12, 15]),
      ],
    },
    {
      name: 'Bacak',
      weekday: 5,
      blocks: [
        { exercise: SQUAT, sets: 4, reps: [6, 10], rest: MAIN_REST },
        { exercise: 'Leg_Press', sets: 3, reps: [10, 12], rest: T2_REST },
        { exercise: 'Romanian_Deadlift', sets: 3, reps: [8, 12], rest: T2_REST },
        acc('Leg_Extensions', 3, [12, 15]),
        acc('Lying_Leg_Curls', 3, [12, 15]),
        acc('Standing_Calf_Raises', 4, [10, 15]),
      ],
    },
  ],
};

// ---------------------------------------------------------------- 6. Arnold Split 6 gün (genel şablon)
const arnoldChestBack: BlockDef[] = [
  { exercise: BENCH, sets: 4, reps: [6, 10], rest: T2_REST },
  { exercise: 'Barbell_Incline_Bench_Press_-_Medium_Grip', sets: 4, reps: [6, 10], rest: T2_REST },
  acc('Dumbbell_Flyes', 3, [10, 12]),
  { exercise: 'Pullups', sets: 4, reps: [6, 10], rest: T2_REST },
  { exercise: ROW, sets: 4, reps: [8, 10], rest: T2_REST },
  acc('T-Bar_Row_with_Handle', 3, [8, 10]),
];
const arnoldShouldersArms: BlockDef[] = [
  { exercise: OHP, sets: 4, reps: [6, 10], rest: T2_REST },
  acc('Arnold_Dumbbell_Press', 3, [8, 12]),
  acc('Side_Lateral_Raise', 4, [10, 12]),
  acc('Barbell_Curl', 4, [8, 10]),
  acc('Close-Grip_Barbell_Bench_Press', 4, [8, 10]),
  acc('Concentration_Curls', 3, [10, 12]),
  acc('Lying_Triceps_Press', 3, [10, 12]),
];
const arnoldLegs: BlockDef[] = [
  { exercise: SQUAT, sets: 5, reps: [8, 12], rest: MAIN_REST },
  acc('Barbell_Lunge', 3, [10, 12]),
  acc('Lying_Leg_Curls', 4, [10, 12]),
  acc('Stiff-Legged_Barbell_Deadlift', 3, 10),
  acc('Standing_Calf_Raises', 5, [12, 15]),
  acc('Hanging_Leg_Raise', 3, 15),
];
const arnoldSplit: ProgramDef = {
  n: 6,
  name: 'Arnold Split 6 gün',
  description:
    "Arnold Schwarzenegger'in klasik bölünmesine dayalı genel şablon: Göğüs+Sırt, Omuz+Kol, Bacak; " +
    'haftada iki tur (Pzt–Cmt). Yüksek hacimli, ileri seviye.',
  level: 'advanced',
  scheduleMode: 'weekdays',
  daysPerWeek: 6,
  workouts: [
    { name: 'Göğüs + Sırt', weekday: 1, blocks: arnoldChestBack },
    { name: 'Omuz + Kol', weekday: 2, blocks: arnoldShouldersArms },
    { name: 'Bacak', weekday: 3, blocks: arnoldLegs },
    { name: 'Göğüs + Sırt', weekday: 4, blocks: arnoldChestBack },
    { name: 'Omuz + Kol', weekday: 5, blocks: arnoldShouldersArms },
    { name: 'Bacak', weekday: 6, blocks: arnoldLegs },
  ],
};

// ---------------------------------------------------------------- 5/3/1 ortak
// Standart 5/3/1 haftaları: [TM yüzdesi, tekrar, son set AMRAP mı].
type SetSpec = [pctTm: number, reps: number, amrap: boolean];
const WEEKS_531: SetSpec[][] = [
  [[65, 5, false], [75, 5, false], [85, 5, true]],
  [[70, 3, false], [80, 3, false], [90, 3, true]],
  [[75, 5, false], [85, 3, false], [95, 1, true]],
];
const DELOAD_531: SetSpec[] = [[40, 5, false], [50, 5, false], [60, 5, false]];

const mainSets = (exercise: string, week: SetSpec[]): BlockDef[] =>
  week.map(([pctTm, reps, amrap]) => ({ exercise, sets: 1, reps, amrap, pctTm, rest: MAIN_REST }));

// ---------------------------------------------------------------- 7. 5/3/1 Boring But Big
// Kaynak: https://jimwendler.com/blogs/jimwendler-com/101077382-boring-but-big
// Yardımcı hareketler Wendler'in BBB örneklerinden (her güne bir lat/karın hareketi).
const bbbDays: { name: string; lift: string; assistance: BlockDef }[] = [
  { name: 'Press', lift: OHP, assistance: acc('Chin-Up', 5, 10) },
  { name: 'Deadlift', lift: DEADLIFT, assistance: acc('Hanging_Leg_Raise', 5, 15) },
  { name: 'Bench', lift: BENCH, assistance: acc('One-Arm_Dumbbell_Row', 5, 10) },
  { name: 'Squat', lift: SQUAT, assistance: acc('Lying_Leg_Curls', 5, 10) },
];
const bbbWeek = (weekNo: number, sets: SetSpec[], bbbSets: number): WorkoutDef[] =>
  bbbDays.map((day) => ({
    name: `Hafta ${weekNo} · ${day.name}`,
    blocks: [
      ...mainSets(day.lift, sets),
      { exercise: day.lift, sets: bbbSets, reps: 10, pctTm: 50, rest: T2_REST, notes: 'Boring But Big' },
      day.assistance,
    ],
  }));
const bbb: ProgramDef = {
  n: 7,
  name: '5/3/1 Boring But Big',
  description:
    "Jim Wendler'in 5/3/1'inin en popüler çeşidi. 4 haftalık döngü (4. hafta deload), haftada 4 gün. " +
    'Her gün bir ana hareket (5/3/1 setleri) ve aynı hareketten 5×10 hacim işi. ' +
    'Ağırlıklar 1RM değerlerinden hesaplanır.',
  level: 'intermediate',
  scheduleMode: 'rotation',
  daysPerWeek: 4,
  workouts: [
    ...bbbWeek(1, WEEKS_531[0], 5),
    ...bbbWeek(2, WEEKS_531[1], 5),
    ...bbbWeek(3, WEEKS_531[2], 5),
    ...bbbWeek(4, DELOAD_531, 3),
  ],
};

// ---------------------------------------------------------------- 8. 5/3/1 for Beginners
// Kaynak: https://thefitness.wiki/routines/5-3-1-for-beginners/
// Yardımcı hareket seçimi kaynakta serbest (50–100 tekrar itme/çekme/tek bacak-karın); burada varsayılan seçim.
const fslSets = (exercise: string, week: SetSpec[]): BlockDef => ({
  exercise,
  sets: 5,
  reps: 5,
  pctTm: week[0][0],
  rest: T2_REST,
  notes: 'FSL (First Set Last)',
});
const beginnerAssistance: BlockDef[] = [
  acc('Pushups', 5, [10, 20], 'İtme: toplam 50–100 tekrar'),
  acc('One-Arm_Dumbbell_Row', 5, [10, 20], 'Çekme: toplam 50–100 tekrar'),
  acc('Hanging_Leg_Raise', 5, [10, 20], 'Karın/tek bacak: toplam 50–100 tekrar'),
];
const beginnerDays: { name: string; lifts: [string, string] }[] = [
  { name: 'Squat + Bench', lifts: [SQUAT, BENCH] },
  { name: 'Deadlift + Press', lifts: [DEADLIFT, OHP] },
  { name: 'Bench + Squat', lifts: [BENCH, SQUAT] },
];
const beginnerWorkouts: WorkoutDef[] = WEEKS_531.flatMap((week, i) =>
  beginnerDays.map((day) => ({
    name: `Hafta ${i + 1} · ${day.name}`,
    blocks: [
      ...mainSets(day.lifts[0], week),
      fslSets(day.lifts[0], week),
      ...mainSets(day.lifts[1], week),
      fslSets(day.lifts[1], week),
      ...beginnerAssistance,
    ],
  }))
);
const beginners531: ProgramDef = {
  n: 8,
  name: '5/3/1 for Beginners',
  description:
    'Yeni başlayanlar için 5/3/1: haftada 3 gün, her gün iki ana hareket, 3 haftalık döngü. ' +
    'Her ana hareketten sonra ilk setin ağırlığıyla 5×5 (FSL). Ağırlıklar 1RM değerlerinden hesaplanır.',
  level: 'beginner',
  scheduleMode: 'rotation',
  daysPerWeek: 3,
  workouts: beginnerWorkouts,
};

// ---------------------------------------------------------------- 9. nSuns 5/3/1 LP 4 gün
// Kaynaklar: https://thefitness.wiki/routines/nsuns-lp/ (TM = %90 1RM),
// https://fithappenspro.com/nsuns-lp-4-day/ , https://repcheckapp.com/blog/nsuns-lp-guide
// Not: Close-Grip Bench T2 için kaynaklar çelişiyor (40/50/60 vs 50/60/70); çoğunluk 40/50/60.
type NSet = [pctTm: number, reps: number, amrap?: boolean];
const T1_VOLUME: NSet[] = [[65, 8], [75, 6], [85, 4], [85, 4], [85, 4], [80, 5], [75, 6], [70, 7], [65, 8, true]];
const T1_HEAVY: NSet[] = [[75, 5], [85, 3], [95, 1, true], [90, 3], [85, 3], [80, 3], [75, 5], [70, 5], [65, 5, true]];
const T2_UPPER_REPS = [6, 5, 3, 5, 7, 4, 6, 8];
const T2_LOWER_REPS = [5, 5, 3, 5, 7, 4, 6, 8];
// T2: ilk set start, ikinci start+10, kalanlar start+20 (örn. 50/60/70/70/…).
const t2 = (reps: number[], start: number): NSet[] =>
  reps.map((r, i) => [i === 0 ? start : i === 1 ? start + 10 : start + 20, r]);
const nsunsBlocks = (exercise: string, sets: NSet[], rest: number, pctRef?: string): BlockDef[] =>
  sets.map(([pctTm, reps, amrap]) => ({
    exercise,
    sets: 1,
    reps,
    amrap: amrap ?? false,
    pctTm,
    rest,
    ...(pctRef ? { pctRef } : {}),
  }));
const nsuns: ProgramDef = {
  n: 9,
  name: 'nSuns 5/3/1 LP 4 gün',
  description:
    'Yüksek hacimli, haftalık ağırlık artışlı ileri seviye program. Her gün bir T1 (9 set) ve bir T2 (8 set) hareketi; ' +
    'her set farklı yüzdeyle. Pzt/Sal/Per/Cum. Aksesuar hareketler serbest (ekleyebilirsin). ' +
    'Ağırlıklar 1RM değerlerinden hesaplanır.',
  level: 'advanced',
  scheduleMode: 'weekdays',
  daysPerWeek: 4,
  workouts: [
    {
      name: 'Bench (Hacim) + OHP',
      weekday: 1,
      blocks: [...nsunsBlocks(BENCH, T1_VOLUME, MAIN_REST), ...nsunsBlocks(OHP, t2(T2_UPPER_REPS, 50), T2_REST)],
    },
    {
      name: 'Squat + Sumo Deadlift',
      weekday: 2,
      blocks: [
        ...nsunsBlocks(SQUAT, T1_HEAVY, MAIN_REST),
        ...nsunsBlocks('Sumo_Deadlift', t2(T2_LOWER_REPS, 50), T2_REST, DEADLIFT),
      ],
    },
    {
      name: 'Bench (Ağır) + Close-Grip Bench',
      weekday: 4,
      blocks: [
        ...nsunsBlocks(BENCH, T1_HEAVY, MAIN_REST),
        ...nsunsBlocks('Close-Grip_Barbell_Bench_Press', t2(T2_UPPER_REPS, 40), T2_REST, BENCH),
      ],
    },
    {
      name: 'Deadlift + Front Squat',
      weekday: 5,
      blocks: [
        ...nsunsBlocks(DEADLIFT, T1_HEAVY, MAIN_REST),
        ...nsunsBlocks('Front_Barbell_Squat', t2(T2_LOWER_REPS, 35), T2_REST, SQUAT),
      ],
    },
  ],
};

export const PROGRAMS: ProgramDef[] = [
  strongLifts,
  fullBody,
  upperLower,
  ppl,
  broSplit,
  arnoldSplit,
  bbb,
  beginners531,
  nsuns,
];
