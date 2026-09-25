# F3 — Antrenman Programlama Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Kullanıcının 876 hareketlik kütüphaneden hareket seçerek boştan program oluşturabildiği, 9 hazır programdan birini kopyalayıp özelleştirebildiği, bir programı aktif edip ana ekranda "Bugün" antrenmanını görebildiği uçtan uca bir dikey dilim inşa etmek.

**Architecture:** Yeni `lib/features/workout/` feature'ı `nutrition` feature'ının domain/data/application/presentation katmanlarını izler. Hareket kütüphanesi ve hazır programlar, `tool/` altındaki Deno betikleriyle üretilen seed migration'larıyla Supabase'e yüklenir. Program kopyalama (`copy_program`) ve kaydetme (`save_program`) tek transaction'lı Postgres fonksiyonlarıdır; istemci program ağacını tek bir RPC ile yazar. Alt navigasyona üçüncü sekme (Antrenman) eklenir.

**Tech Stack:** Flutter + Riverpod 3 + go_router 18 + supabase_flutter 2.17 + easy_localization (mevcut yığın, yeni paket yok). Backend: Postgres (Supabase) plpgsql fonksiyonları. Araçlar: Deno 2 (seed üreticileri + testleri).

**Spec:** `docs/superpowers/specs/2026-09-25-f3-programlama-design.md`

## Global Constraints

- Tüm yeni tablolarda Supabase RLS zorunlu; hazır satırlar (`user_id is null`) hiçbir kullanıcı tarafından yazılamaz (spec §3).
- Hareket veri seti `yuhonas/free-exercise-db` commit `a859101d633a01c4a1a920d6a8ce41dabba0705f`'e sabitlenir; görsel taban URL'si `https://raw.githubusercontent.com/yuhonas/free-exercise-db/a859101d633a01c4a1a920d6a8ce41dabba0705f/exercises/` (spec §2).
- Hareket adları ve talimatlar İngilizce kalır; kas grubu/ekipman etiketleri ve tüm diğer UI metinleri `assets/translations/tr.json` + `en.json`'a eklenir (spec §2, mevcut proje kuralı).
- `percent_1rm` her zaman 1RM bazındadır; TM bazlı kaynak yüzdeleri seed üretiminde `× 0.9` ile çevrilir. Gösterilen kilo en yakın 2,5 kg'a yuvarlanır (spec §3).
- Mevcut feature-first katman yapısı izlenir (`lib/features/nutrition/` paterni).
- Supabase'e dokunan repository sınıfları doğrudan unit test edilmez (F2 paterni); iş mantığı fake repository ile test edilir, repository'ler ve SQL gerçek projede Task 15'te elle doğrulanır.
- Widget testlerinde `.tr()` çıktısına güvenilmez (EasyLocalization asset yüklemesi testte güvenilir tamamlanmıyor — bkz. `test/core/app_shell_test.dart` yorumu); bulma `Key`, ikon veya veri metni (program/hareket adı) ile yapılır.
- Tüm işler `f3-programlama` dalında yapılır.

## Spec'ten Bilinçli Sapmalar (plan yazımında araştırmayla ortaya çıktı)

1. **Migration numaraları:** Spec'teki `0004`/`0005` yerine şema ile üretilmiş seed ayrı dosyalarda: `0004_create_exercises.sql` (şema+RLS, elle), `0005_seed_exercises.sql` (üretilmiş), `0006_create_programs.sql` (şema+RLS+fonksiyonlar, elle), `0007_seed_programs.sql` (üretilmiş). Gerekçe: üretilmiş dosya yeniden üretildiğinde elle yazılan şemaya dokunulmaz.
2. **`workout_exercises.percent_ref_exercise_id`:** nSuns T2 hareketleri (Sumo Deadlift, Front Squat, Close-Grip Bench) başka bir hareketin TM'sine göre yüzde verir. Bu sütun, yüzdenin hangi hareketin 1RM'sine dayandığını tutar (null → blok kendi `exercise_id`'si).
3. **`programs.days_per_week`:** Rotation programlarında haftalık gün sayısı antrenman sayısından türetilemez (5/3/1 BBB = 16 antrenman, haftada 4 gün). Hazır program filtresi için gerekli.
4. **`save_program(payload jsonb)` RPC'si:** Düzenleyicinin "tek seferde kaydet" gereksinimini (spec §6.3) atomik yapmak için; istemciden çoklu insert/delete yerine.
5. **Seed parçalama:** `0005` tek dosya üretilir; SQL Editor kabul etmezse üretici `--chunks N` ile `supabase/.temp/`-dışı bir geçici klasöre parçalar yazar (Task 1).

## Dosya Haritası

```
tool/
  exercise_seed.ts            # saf: exercises.json satırları → SQL (Task 1)
  exercise_seed.test.ts
  generate_exercise_seed.ts   # CLI: sabit commit'ten indir → 0005 + tool/data/exercise_ids.json
  data/exercise_ids.json      # üretilmiş; program testleri için id listesi
  program_types.ts            # ProgramDef/WorkoutDef/BlockDef tipleri (Task 2)
  programs.ts                 # 9 hazır program (kaynak linkleriyle)
  program_seed.ts             # saf: ProgramDef[] → SQL
  program_seed.test.ts        # doğrulama + SQL testleri
  generate_program_seed.ts    # CLI: → 0007
supabase/migrations/
  0004_create_exercises.sql   0005_seed_exercises.sql
  0006_create_programs.sql    0007_seed_programs.sql
  checks/f3_rls_checks.sql    # Task 15 elle doğrulama betiği
lib/features/workout/
  domain/  exercise.dart, exercise_images.dart, schedule_mode.dart, program_level.dart,
           workout_exercise.dart, program_workout.dart, program.dart,
           weight_calculator.dart, block_grouping.dart, today_workout.dart,
           block_format.dart, exercise_taxonomy.dart, exercise_filter.dart
  data/    exercise_repository.dart, program_repository.dart, one_rep_max_repository.dart
  application/ workout_providers.dart, program_editor_state.dart, program_editor_notifier.dart
  presentation/ programs_screen.dart, program_detail_screen.dart, program_editor_screen.dart,
                exercise_picker_screen.dart, one_rep_max_sheet.dart,
                widgets/program_card.dart, widgets/exercise_group_tile.dart,
                widgets/exercise_detail_sheet.dart, widgets/today_workout_card.dart,
                widgets/block_edit_dialog.dart
lib/core/router.dart, lib/core/app_shell.dart            # değişir
lib/features/onboarding/presentation/home_screen.dart    # değişir ("Bugün" kartı)
test/features/workout/...                                 # her görevin testleri
test/features/workout/fakes.dart                          # fake repository'ler (Task 6)
.github/workflows/ci.yml                                  # deno test tool/ eklenir
```

---

## Task 1: Hareket kütüphanesi — şema, seed üreticisi, `0004` + `0005`

**Files:**
- Create: `supabase/migrations/0004_create_exercises.sql`
- Create: `tool/exercise_seed.ts`, `tool/exercise_seed.test.ts`, `tool/generate_exercise_seed.ts`
- Create (üretilmiş): `supabase/migrations/0005_seed_exercises.sql`, `tool/data/exercise_ids.json`
- Modify: `.github/workflows/ci.yml` (deno-test job)

**Interfaces:**
- Produces: tablo `public.exercises` (spec §3 sütunları); TS `export interface RawExercise { id: string; name: string; category?: string | null; equipment?: string | null; level?: string | null; primaryMuscles: string[]; secondaryMuscles: string[]; instructions: string[]; images: string[] }`, `export function sqlString(value: string | null | undefined): string`, `export function sqlTextArray(values: string[]): string`, `export function buildExerciseSeedSql(exercises: RawExercise[]): string`. `tool/data/exercise_ids.json` = `string[]`.

- [ ] **Step 1: Şema migration'ını yaz**

`supabase/migrations/0004_create_exercises.sql`:

```sql
create table if not exists public.exercises (
  id text primary key default gen_random_uuid()::text,
  user_id uuid references auth.users (id) on delete cascade, -- null = hazır hareket
  name text not null,
  category text,
  equipment text,
  level text,
  primary_muscles text[] not null default '{}',
  secondary_muscles text[] not null default '{}',
  instructions text[] not null default '{}',
  images text[] not null default '{}',
  created_at timestamptz not null default now()
);

alter table public.exercises enable row level security;

create policy "Users can view built-in and own exercises"
  on public.exercises for select
  using (user_id is null or user_id = auth.uid());

create policy "Users can insert own exercises"
  on public.exercises for insert
  with check (user_id = auth.uid());

create policy "Users can update own exercises"
  on public.exercises for update
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

create policy "Users can delete own exercises"
  on public.exercises for delete
  using (user_id = auth.uid());
```

- [ ] **Step 2: Başarısız testi yaz**

`tool/exercise_seed.test.ts`:

```ts
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
```

- [ ] **Step 3: Testin başarısız olduğunu doğrula**

Run: `deno test tool/exercise_seed.test.ts`
Expected: FAIL — `Module not found "file:///.../tool/exercise_seed.ts"`

- [ ] **Step 4: Saf üreticiyi yaz**

`tool/exercise_seed.ts`:

```ts
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
```

- [ ] **Step 5: Testlerin geçtiğini doğrula**

Run: `deno test tool/exercise_seed.test.ts`
Expected: PASS (3 test)

- [ ] **Step 6: CLI üreticiyi yaz**

`tool/generate_exercise_seed.ts`:

```ts
// Kullanım: deno run --allow-net --allow-write tool/generate_exercise_seed.ts [--chunks N]
// --chunks N: SQL Editor tek dosyayı kabul etmezse, aynı içeriği N parçaya bölüp
// tool/.out/ altına yazar (git'e girmez). Migration dosyası her durumda tek parça üretilir.
import { buildExerciseSeedSql } from './exercise_seed.ts';
import type { RawExercise } from './exercise_seed.ts';

export const DATASET_COMMIT = 'a859101d633a01c4a1a920d6a8ce41dabba0705f';
const url = `https://raw.githubusercontent.com/yuhonas/free-exercise-db/${DATASET_COMMIT}/dist/exercises.json`;

const response = await fetch(url);
if (!response.ok) throw new Error(`İndirilemedi: ${response.status}`);
const exercises = (await response.json()) as RawExercise[];
exercises.sort((a, b) => a.id.localeCompare(b.id));

await Deno.writeTextFile('supabase/migrations/0005_seed_exercises.sql', buildExerciseSeedSql(exercises));
await Deno.mkdir('tool/data', { recursive: true });
await Deno.writeTextFile('tool/data/exercise_ids.json', JSON.stringify(exercises.map((e) => e.id), null, 1) + '\n');

const chunkFlag = Deno.args.indexOf('--chunks');
if (chunkFlag >= 0) {
  const n = Number(Deno.args[chunkFlag + 1]);
  const size = Math.ceil(exercises.length / n);
  await Deno.mkdir('tool/.out', { recursive: true });
  for (let i = 0; i < n; i++) {
    const part = exercises.slice(i * size, (i + 1) * size);
    await Deno.writeTextFile(`tool/.out/0005_part${i + 1}.sql`, buildExerciseSeedSql(part));
  }
}
console.log(`${exercises.length} hareket yazıldı.`);
```

`.gitignore` sonuna ekle:

```
# Seed parçaları (tool/generate_exercise_seed.ts --chunks)
tool/.out/
```

- [ ] **Step 7: Seed'i üret ve kontrol et**

Run: `deno run --allow-net --allow-write tool/generate_exercise_seed.ts`
Expected: `876 hareket yazıldı.`; `supabase/migrations/0005_seed_exercises.sql` ~1 MB; `tool/data/exercise_ids.json` 876 eleman. Kontrol: `grep -c "^('" supabase/migrations/0005_seed_exercises.sql` → `876`.

- [ ] **Step 8: CI'a tool testlerini ekle**

`.github/workflows/ci.yml` içinde `deno-test` job'ının son adımından sonra:

```yaml
      - name: Run seed generator tests
        run: deno test --allow-read tool/
```

- [ ] **Step 9: Commit**

```bash
git add supabase/migrations/0004_create_exercises.sql supabase/migrations/0005_seed_exercises.sql tool/exercise_seed.ts tool/exercise_seed.test.ts tool/generate_exercise_seed.ts tool/data/exercise_ids.json .gitignore .github/workflows/ci.yml
git commit -m "feat(workout): add exercise library schema and free-exercise-db seed"
```

---

## Task 2: Program şeması, RLS, `copy_program` / `save_program` — `0006`

**Files:**
- Create: `supabase/migrations/0006_create_programs.sql`

**Interfaces:**
- Consumes: `public.exercises` (Task 1).
- Produces: tablolar `programs`, `program_workouts`, `workout_exercises`, `user_one_rep_maxes`; `profiles.active_program_id`, `profiles.next_rotation_position`; RPC `copy_program(source uuid) returns uuid`, `save_program(payload jsonb) returns uuid`. `save_program` payload şekli:
  `{"id": uuid|null, "name": text, "description": text|null, "level": text|null, "schedule_mode": "weekdays"|"rotation", "days_per_week": int|null, "source_program_id": uuid|null, "workouts": [{"name": text, "weekday": int|null, "exercises": [{"exercise_id": text, "sets": int, "reps_min": int, "reps_max": int, "is_amrap": bool, "percent_1rm": numeric|null, "percent_ref_exercise_id": text|null, "rest_seconds": int|null, "notes": text|null}]}]}`

Bu görevde otomatik test yok (CI'da veritabanı yok — Global Constraints); SQL, Task 15'te gerçek projede `checks/f3_rls_checks.sql` ile doğrulanır. Bu görevin çıktısı, gözden geçirenin satır satır okuyabileceği tek bir migration dosyasıdır.

- [ ] **Step 1: Migration'ı yaz**

`supabase/migrations/0006_create_programs.sql`:

```sql
create table if not exists public.programs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users (id) on delete cascade, -- null = hazır program
  name text not null,
  description text,
  level text check (level in ('beginner', 'intermediate', 'advanced')),
  schedule_mode text not null check (schedule_mode in ('weekdays', 'rotation')),
  days_per_week smallint check (days_per_week between 1 and 7),
  source_program_id uuid references public.programs (id) on delete set null,
  created_at timestamptz not null default now()
);

create table if not exists public.program_workouts (
  id uuid primary key default gen_random_uuid(),
  program_id uuid not null references public.programs (id) on delete cascade,
  position int not null,
  name text not null,
  weekday smallint check (weekday between 1 and 7), -- ISO: 1=Pzt … 7=Paz
  unique (program_id, position)
);

create unique index if not exists program_workouts_weekday_uniq
  on public.program_workouts (program_id, weekday) where weekday is not null;

create table if not exists public.workout_exercises (
  id uuid primary key default gen_random_uuid(),
  workout_id uuid not null references public.program_workouts (id) on delete cascade,
  position int not null,
  exercise_id text not null references public.exercises (id) on delete restrict,
  sets int not null check (sets > 0),
  reps_min int not null check (reps_min > 0),
  reps_max int not null check (reps_max >= reps_min),
  is_amrap boolean not null default false,
  percent_1rm numeric check (percent_1rm > 0 and percent_1rm <= 100),
  percent_ref_exercise_id text references public.exercises (id) on delete restrict,
  rest_seconds int check (rest_seconds >= 0),
  notes text,
  unique (workout_id, position)
);

create table if not exists public.user_one_rep_maxes (
  user_id uuid not null references auth.users (id) on delete cascade,
  exercise_id text not null references public.exercises (id) on delete cascade,
  weight_kg numeric not null check (weight_kg > 0),
  updated_at timestamptz not null default now(),
  primary key (user_id, exercise_id)
);

alter table public.profiles
  add column if not exists active_program_id uuid references public.programs (id) on delete set null,
  add column if not exists next_rotation_position int not null default 0;

alter table public.programs enable row level security;
alter table public.program_workouts enable row level security;
alter table public.workout_exercises enable row level security;
alter table public.user_one_rep_maxes enable row level security;

create policy "Users can view built-in and own programs"
  on public.programs for select
  using (user_id is null or user_id = auth.uid());
create policy "Users can insert own programs"
  on public.programs for insert with check (user_id = auth.uid());
create policy "Users can update own programs"
  on public.programs for update using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "Users can delete own programs"
  on public.programs for delete using (user_id = auth.uid());

create policy "Users can view workouts of visible programs"
  on public.program_workouts for select
  using (exists (select 1 from public.programs p
                 where p.id = program_id and (p.user_id is null or p.user_id = auth.uid())));
create policy "Users can write workouts of own programs"
  on public.program_workouts for all
  using (exists (select 1 from public.programs p where p.id = program_id and p.user_id = auth.uid()))
  with check (exists (select 1 from public.programs p where p.id = program_id and p.user_id = auth.uid()));

create policy "Users can view exercises of visible workouts"
  on public.workout_exercises for select
  using (exists (select 1 from public.program_workouts w join public.programs p on p.id = w.program_id
                 where w.id = workout_id and (p.user_id is null or p.user_id = auth.uid())));
create policy "Users can write exercises of own workouts"
  on public.workout_exercises for all
  using (exists (select 1 from public.program_workouts w join public.programs p on p.id = w.program_id
                 where w.id = workout_id and p.user_id = auth.uid()))
  with check (exists (select 1 from public.program_workouts w join public.programs p on p.id = w.program_id
                      where w.id = workout_id and p.user_id = auth.uid()));

create policy "Users can manage own one rep maxes"
  on public.user_one_rep_maxes for all
  using (user_id = auth.uid()) with check (user_id = auth.uid());

-- Kaynak programı (hazır veya kendi) tüm antrenman ve bloklarıyla kullanıcıya kopyalar.
-- security invoker: RLS geçerli — başkasının programı görünmez, "not found" döner.
create or replace function public.copy_program(source uuid)
returns uuid
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_new uuid := gen_random_uuid();
  w record;
  v_workout_id uuid;
begin
  if auth.uid() is null then
    raise exception 'not authenticated';
  end if;

  insert into programs (id, user_id, name, description, level, schedule_mode, days_per_week, source_program_id)
  select v_new, auth.uid(), name, description, level, schedule_mode, days_per_week, id
  from programs where id = source;
  if not found then
    raise exception 'program not found';
  end if;

  for w in select * from program_workouts where program_id = source order by position loop
    insert into program_workouts (program_id, position, name, weekday)
    values (v_new, w.position, w.name, w.weekday)
    returning id into v_workout_id;

    insert into workout_exercises (workout_id, position, exercise_id, sets, reps_min, reps_max,
                                   is_amrap, percent_1rm, percent_ref_exercise_id, rest_seconds, notes)
    select v_workout_id, position, exercise_id, sets, reps_min, reps_max,
           is_amrap, percent_1rm, percent_ref_exercise_id, rest_seconds, notes
    from workout_exercises where workout_id = w.id;
  end loop;

  return v_new;
end;
$$;

-- Düzenleyicinin tüm program ağacını tek transaction'da yazar (id null → yeni program).
-- Var olan programın antrenmanları silinip yeniden yazılır.
create or replace function public.save_program(payload jsonb)
returns uuid
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_id uuid := coalesce((payload->>'id')::uuid, gen_random_uuid());
  w jsonb;
  e jsonb;
  v_workout_id uuid;
  w_pos int := 0;
  e_pos int;
begin
  if auth.uid() is null then
    raise exception 'not authenticated';
  end if;

  insert into programs (id, user_id, name, description, level, schedule_mode, days_per_week, source_program_id)
  values (
    v_id, auth.uid(), payload->>'name', payload->>'description', payload->>'level',
    payload->>'schedule_mode', (payload->>'days_per_week')::smallint,
    (payload->>'source_program_id')::uuid
  )
  on conflict (id) do update set
    name = excluded.name,
    description = excluded.description,
    level = excluded.level,
    schedule_mode = excluded.schedule_mode,
    days_per_week = excluded.days_per_week;

  if not exists (select 1 from programs where id = v_id and user_id = auth.uid()) then
    raise exception 'program not owned by user';
  end if;

  delete from program_workouts where program_id = v_id;

  for w in select value from jsonb_array_elements(coalesce(payload->'workouts', '[]'::jsonb)) loop
    insert into program_workouts (program_id, position, name, weekday)
    values (v_id, w_pos, w->>'name', (w->>'weekday')::smallint)
    returning id into v_workout_id;

    e_pos := 0;
    for e in select value from jsonb_array_elements(coalesce(w->'exercises', '[]'::jsonb)) loop
      insert into workout_exercises (workout_id, position, exercise_id, sets, reps_min, reps_max,
                                     is_amrap, percent_1rm, percent_ref_exercise_id, rest_seconds, notes)
      values (
        v_workout_id, e_pos, e->>'exercise_id', (e->>'sets')::int, (e->>'reps_min')::int,
        (e->>'reps_max')::int, coalesce((e->>'is_amrap')::boolean, false),
        (e->>'percent_1rm')::numeric, e->>'percent_ref_exercise_id',
        (e->>'rest_seconds')::int, e->>'notes'
      );
      e_pos := e_pos + 1;
    end loop;

    w_pos := w_pos + 1;
  end loop;

  return v_id;
end;
$$;
```

- [ ] **Step 2: Kendi kendine gözden geçir**

Kontrol listesi (dosyayı okuyarak): her yeni tabloda `enable row level security` var; hazır satırlar (`user_id is null`) için yalnızca `select` politikası var; `workout_exercises.exercise_id` `on delete restrict`; iki fonksiyon da `security invoker` ve `auth.uid() is null` kontrolü yapıyor; `save_program` başka kullanıcının `id`'siyle çağrılırsa `on conflict do update` RLS'e takılır veya sahiplik kontrolü exception fırlatır.

- [ ] **Step 3: Commit**

```bash
git add supabase/migrations/0006_create_programs.sql
git commit -m "feat(workout): add program schema, RLS and copy/save program functions"
```

---
## Task 3: Hazır programlar — veri, doğrulama, seed üreticisi, `0007`

**Files:**
- Create: `tool/program_types.ts`, `tool/programs.ts`, `tool/program_seed.ts`, `tool/program_seed.test.ts`, `tool/generate_program_seed.ts`
- Create (üretilmiş): `supabase/migrations/0007_seed_programs.sql`

**Interfaces:**
- Consumes: `sqlString` (Task 1, `tool/exercise_seed.ts`), `tool/data/exercise_ids.json`, Task 2 şeması.
- Produces: `PROGRAMS: ProgramDef[]` (9 program), `export function validatePrograms(programs: ProgramDef[], exerciseIds: Set<string>): string[]` (hata mesajları; boş = geçerli), `export function toOneRmPercent(block: BlockDef): number | null`, `export function buildProgramSeedSql(programs: ProgramDef[]): string`, `export function programId(n: number): string`, `export function workoutId(n: number, w: number): string`, `export function blockId(n: number, w: number, b: number): string`.

**Kaynaklar (plan yazımında doğrulandı, 2026-09-25):**
- StrongLifts 5x5: https://stronglifts.com/5x5/
- Metallicadpa PPL: https://www.reddit.com/r/Fitness/comments/37ylk5/ — ayrıntılar https://fitfrek.com/metallicadpa-6day-ppl/ ile teyit edildi.
- 5/3/1 BBB: https://jimwendler.com/blogs/jimwendler-com/101077382-boring-but-big (BBB 5×10 @ %50–60 TM; deload'da 5×10 veya 3×10). Ana set yüzdeleri Wendler'in standart şeması: 65/75/85 ×5,5,5+; 70/80/90 ×3,3,3+; 75/85/95 ×5,3,1+; deload 40/50/60 ×5.
- 5/3/1 for Beginners: https://thefitness.wiki/routines/5-3-1-for-beginners/ (3 gün, 3 haftalık döngü, FSL 5×5, yardımcı hareket seçimi serbest: 50–100 tekrar itme/çekme/tek bacak-karın).
- nSuns 5/3/1 LP 4 gün: https://thefitness.wiki/routines/nsuns-lp/ (TM = %90 1RM). Set set değerler: https://fithappenspro.com/nsuns-lp-4-day/ ve https://repcheckapp.com/blog/nsuns-lp-guide. **Bilinen çelişki:** Close-Grip Bench T2 yüzdeleri iki kaynakta 40/50/60, bir kaynakta 50/60/70; çoğunluk (40/50/60) seçildi, program dosyasına not düşüldü.
- Full Body 3 gün, Upper/Lower 4 gün, Bro Split 5 gün, Arnold Split 6 gün: tek bir kanonik kaynağı olmayan genel şablonlar; açıklamalarında "genel şablon" olarak belirtilir.

- [ ] **Step 1: Tipleri yaz**

`tool/program_types.ts`:

```ts
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
```

- [ ] **Step 2: Program verisini yaz**

`tool/programs.ts`:

```ts
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
    'Yüksek hacimli, haftalık ağırlık artışlı ileri seviye program. Her gün bir T1 (9 set) ve bir T2 (8 set) hareket; ' +
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
```

- [ ] **Step 3: Başarısız testleri yaz**

`tool/program_seed.test.ts`:

```ts
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
```

- [ ] **Step 4: Testin başarısız olduğunu doğrula**

Run: `deno test --allow-read tool/program_seed.test.ts`
Expected: FAIL — `Module not found ".../tool/program_seed.ts"`

- [ ] **Step 5: Seed üreticisini yaz**

`tool/program_seed.ts`:

```ts
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
```

- [ ] **Step 6: Testlerin geçtiğini doğrula**

Run: `deno test --allow-read tool/`
Expected: PASS (exercise_seed 3 + program_seed 7 test). `validatePrograms` hata listesi boş değilse, listede adı geçen program/blok `tool/programs.ts`'te düzeltilir (id yazım hatası, gün tekrarı) — test beklentisi gevşetilmez.

- [ ] **Step 7: CLI üreticiyi yaz ve seed'i üret**

`tool/generate_program_seed.ts`:

```ts
// Kullanım: deno run --allow-read --allow-write tool/generate_program_seed.ts
import { PROGRAMS } from './programs.ts';
import { buildProgramSeedSql, validatePrograms } from './program_seed.ts';

const ids = new Set<string>(JSON.parse(await Deno.readTextFile('tool/data/exercise_ids.json')));
const errors = validatePrograms(PROGRAMS, ids);
if (errors.length > 0) {
  console.error(errors.join('\n'));
  Deno.exit(1);
}
await Deno.writeTextFile('supabase/migrations/0007_seed_programs.sql', buildProgramSeedSql(PROGRAMS));
console.log(`${PROGRAMS.length} program yazıldı.`);
```

Run: `deno run --allow-read --allow-write tool/generate_program_seed.ts`
Expected: `9 program yazıldı.`

- [ ] **Step 8: Commit**

```bash
git add tool/program_types.ts tool/programs.ts tool/program_seed.ts tool/program_seed.test.ts tool/generate_program_seed.ts supabase/migrations/0007_seed_programs.sql
git commit -m "feat(workout): add 9 built-in programs with source-checked data and seed generator"
```

---

## Task 4: Domain modelleri

**Files:**
- Create: `lib/features/workout/domain/schedule_mode.dart`, `program_level.dart`, `exercise_images.dart`, `exercise.dart`, `workout_exercise.dart`, `program_workout.dart`, `program.dart`
- Test: `test/features/workout/domain/models_test.dart`
- Delete: `lib/features/workout/domain/.gitkeep`

**Interfaces:**
- Produces (Dart):
  - `enum ScheduleMode { weekdays, rotation }`; `ScheduleMode scheduleModeFromDb(String)`; `String scheduleModeToDb(ScheduleMode)`.
  - `enum ProgramLevel { beginner, intermediate, advanced }`; `ProgramLevel? programLevelFromDb(String?)`; `String? programLevelToDb(ProgramLevel?)`.
  - `const exerciseImageBaseUrl = 'https://raw.githubusercontent.com/yuhonas/free-exercise-db/a859101d633a01c4a1a920d6a8ce41dabba0705f/exercises/'`; `String exerciseImageUrl(String path)`.
  - `class Exercise { String id; String? userId; String name; String? category; String? equipment; String? level; List<String> primaryMuscles; List<String> secondaryMuscles; List<String> instructions; List<String> images; bool get isCustom; List<String> get imageUrls; factory Exercise.fromJson(Map<String, dynamic>) }`
  - `class WorkoutExercise { String exerciseId; String exerciseName; int sets; int repsMin; int repsMax; bool isAmrap; double? percent1rm; String? percentRefExerciseId; int? restSeconds; String? notes; String get oneRepMaxExerciseId; factory fromJson; Map<String, dynamic> toJson(); WorkoutExercise copyWith({...}) }` — `fromJson` beklediği şekil: `workout_exercises` satırı + gömülü `exercises: {name}`; `toJson` yalnızca `save_program` payload alanlarını üretir (`exercise_name` hariç). `copyWith`'te nullable alanları temizlemek için `clearPercent1rm`, `clearRestSeconds`, `clearNotes` bool parametreleri.
  - `class ProgramWorkout { String name; int? weekday; List<WorkoutExercise> exercises; factory fromJson; Map<String, dynamic> toJson(); ProgramWorkout copyWith({String? name, int? weekday, bool clearWeekday = false, List<WorkoutExercise>? exercises}) }` — `fromJson`, gömülü `workout_exercises` listesini `position`'a göre sıralar.
  - `class Program { String? id; String? userId; String name; String? description; ProgramLevel? level; ScheduleMode scheduleMode; int? daysPerWeek; String? sourceProgramId; List<ProgramWorkout> workouts; bool get isBuiltIn; int? get effectiveDaysPerWeek; bool get usesPercentages; Set<String> get oneRepMaxExerciseIds; factory fromJson; Map<String, dynamic> toSavePayload(); Program copyWith({...}) }` — `fromJson` gömülü `program_workouts` listesini `position`'a göre sıralar (liste sorgusunda gömülü liste yoksa boş liste). `isBuiltIn` = `userId == null`. `effectiveDaysPerWeek` = `daysPerWeek ?? (scheduleMode == weekdays ? workouts.length : null)`. `usesPercentages` = herhangi bir blokta `percent1rm != null`.

- [ ] **Step 1: Başarısız testleri yaz**

`test/features/workout/domain/models_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:spor_takip/features/workout/domain/exercise.dart';
import 'package:spor_takip/features/workout/domain/exercise_images.dart';
import 'package:spor_takip/features/workout/domain/program.dart';
import 'package:spor_takip/features/workout/domain/program_level.dart';
import 'package:spor_takip/features/workout/domain/program_workout.dart';
import 'package:spor_takip/features/workout/domain/schedule_mode.dart';
import 'package:spor_takip/features/workout/domain/workout_exercise.dart';

Map<String, dynamic> _blockRow({
  required int position,
  String exerciseId = 'Barbell_Squat',
  String name = 'Barbell Squat',
  num? percent,
  String? ref,
}) =>
    {
      'position': position,
      'exercise_id': exerciseId,
      'sets': 5,
      'reps_min': 5,
      'reps_max': 5,
      'is_amrap': false,
      'percent_1rm': percent,
      'percent_ref_exercise_id': ref,
      'rest_seconds': 180,
      'notes': null,
      'exercises': {'name': name},
    };

void main() {
  test('ScheduleMode and ProgramLevel round-trip through db strings', () {
    for (final mode in ScheduleMode.values) {
      expect(scheduleModeFromDb(scheduleModeToDb(mode)), mode);
    }
    expect(programLevelFromDb('advanced'), ProgramLevel.advanced);
    expect(programLevelFromDb(null), isNull);
    expect(programLevelToDb(ProgramLevel.beginner), 'beginner');
  });

  test('Exercise.fromJson reads arrays, builds pinned image urls and flags custom exercises', () {
    final e = Exercise.fromJson({
      'id': 'Barbell_Squat',
      'user_id': null,
      'name': 'Barbell Squat',
      'category': 'strength',
      'equipment': 'barbell',
      'level': 'beginner',
      'primary_muscles': ['quadriceps'],
      'secondary_muscles': ['glutes'],
      'instructions': ['Step 1'],
      'images': ['Barbell_Squat/0.jpg'],
    });
    expect(e.isCustom, isFalse);
    expect(e.primaryMuscles, ['quadriceps']);
    expect(e.imageUrls, ['${exerciseImageBaseUrl}Barbell_Squat/0.jpg']);
    expect(exerciseImageBaseUrl, contains('a859101d633a01c4a1a920d6a8ce41dabba0705f'));

    final custom = Exercise.fromJson({'id': 'x', 'user_id': 'u1', 'name': 'My move'});
    expect(custom.isCustom, isTrue);
    expect(custom.images, isEmpty);
  });

  test('WorkoutExercise.fromJson reads the joined exercise name and toJson omits it', () {
    final block = WorkoutExercise.fromJson(_blockRow(position: 0, percent: 76.5, ref: 'Barbell_Deadlift'));
    expect(block.exerciseName, 'Barbell Squat');
    expect(block.percent1rm, 76.5);
    expect(block.oneRepMaxExerciseId, 'Barbell_Deadlift');
    expect(block.toJson(), {
      'exercise_id': 'Barbell_Squat',
      'sets': 5,
      'reps_min': 5,
      'reps_max': 5,
      'is_amrap': false,
      'percent_1rm': 76.5,
      'percent_ref_exercise_id': 'Barbell_Deadlift',
      'rest_seconds': 180,
      'notes': null,
    });
    expect(WorkoutExercise.fromJson(_blockRow(position: 0)).oneRepMaxExerciseId, 'Barbell_Squat');
    expect(block.copyWith(clearPercent1rm: true).percent1rm, isNull);
  });

  test('Program.fromJson sorts nested workouts and blocks by position', () {
    final program = Program.fromJson({
      'id': 'p1',
      'user_id': null,
      'name': 'StrongLifts 5x5',
      'description': 'd',
      'level': 'beginner',
      'schedule_mode': 'rotation',
      'days_per_week': 3,
      'source_program_id': null,
      'program_workouts': [
        {
          'position': 1,
          'name': 'B',
          'weekday': null,
          'workout_exercises': [_blockRow(position: 0)],
        },
        {
          'position': 0,
          'name': 'A',
          'weekday': null,
          'workout_exercises': [
            _blockRow(position: 1, exerciseId: 'Bench', name: 'Bench'),
            _blockRow(position: 0),
          ],
        },
      ],
    });
    expect(program.isBuiltIn, isTrue);
    expect(program.level, ProgramLevel.beginner);
    expect(program.workouts.map((w) => w.name), ['A', 'B']);
    expect(program.workouts.first.exercises.map((b) => b.exerciseId), ['Barbell_Squat', 'Bench']);
    expect(program.effectiveDaysPerWeek, 3);
    expect(program.usesPercentages, isFalse);
  });

  test('Program without nested workouts (list query) has an empty workout list', () {
    final program = Program.fromJson({
      'id': 'p1',
      'user_id': 'u1',
      'name': 'Mine',
      'schedule_mode': 'weekdays',
    });
    expect(program.workouts, isEmpty);
    expect(program.isBuiltIn, isFalse);
  });

  test('effectiveDaysPerWeek falls back to workout count in weekdays mode', () {
    const program = Program(
      name: 'Mine',
      scheduleMode: ScheduleMode.weekdays,
      workouts: [
        ProgramWorkout(name: 'A', weekday: 1, exercises: []),
        ProgramWorkout(name: 'B', weekday: 4, exercises: []),
      ],
    );
    expect(program.effectiveDaysPerWeek, 2);
    expect(program.copyWith(scheduleMode: ScheduleMode.rotation).effectiveDaysPerWeek, isNull);
  });

  test('toSavePayload serializes the whole tree for save_program', () {
    const program = Program(
      id: 'p1',
      name: 'Mine',
      scheduleMode: ScheduleMode.weekdays,
      level: ProgramLevel.intermediate,
      sourceProgramId: 'src',
      workouts: [
        ProgramWorkout(
          name: 'A',
          weekday: 1,
          exercises: [
            WorkoutExercise(
              exerciseId: 'Barbell_Squat',
              exerciseName: 'Barbell Squat',
              sets: 3,
              repsMin: 8,
              repsMax: 12,
              percent1rm: 70,
            ),
          ],
        ),
      ],
    );
    final payload = program.toSavePayload();
    expect(payload['id'], 'p1');
    expect(payload['schedule_mode'], 'weekdays');
    expect(payload['level'], 'intermediate');
    expect(payload['source_program_id'], 'src');
    expect(payload['days_per_week'], isNull);
    final workouts = payload['workouts'] as List;
    expect(workouts.single['weekday'], 1);
    expect((workouts.single['exercises'] as List).single['exercise_id'], 'Barbell_Squat');
    expect(program.usesPercentages, isTrue);
    expect(program.oneRepMaxExerciseIds, {'Barbell_Squat'});
  });
}
```

- [ ] **Step 2: Testin başarısız olduğunu doğrula**

Run: `flutter test test/features/workout/domain/models_test.dart`
Expected: FAIL — `Error: Couldn't resolve the package 'spor_takip' ... exercise.dart` (dosyalar yok).

- [ ] **Step 3: Enum'ları ve görsel URL'sini yaz**

`lib/features/workout/domain/schedule_mode.dart`:

```dart
/// Programın haftaya nasıl yerleştiği: haftanın sabit günlerine mi, yoksa
/// sıralı bir döngü olarak mı (hangi gün gidilirse sıradaki antrenman).
enum ScheduleMode { weekdays, rotation }

ScheduleMode scheduleModeFromDb(String value) => ScheduleMode.values.byName(value);

String scheduleModeToDb(ScheduleMode mode) => mode.name;
```

`lib/features/workout/domain/program_level.dart`:

```dart
enum ProgramLevel { beginner, intermediate, advanced }

ProgramLevel? programLevelFromDb(String? value) =>
    value == null ? null : ProgramLevel.values.byName(value);

String? programLevelToDb(ProgramLevel? level) => level?.name;
```

`lib/features/workout/domain/exercise_images.dart`:

```dart
/// free-exercise-db görselleri barındırılmıyor; veri setinin sabitlenmiş
/// commit'inden doğrudan yükleniyor. Storage'a taşımak için yalnızca bu sabit değişir.
const exerciseImageBaseUrl =
    'https://raw.githubusercontent.com/yuhonas/free-exercise-db/a859101d633a01c4a1a920d6a8ce41dabba0705f/exercises/';

String exerciseImageUrl(String path) => '$exerciseImageBaseUrl$path';
```

- [ ] **Step 4: `Exercise`'ı yaz**

`lib/features/workout/domain/exercise.dart`:

```dart
import 'exercise_images.dart';

List<String> _stringList(Object? value) =>
    (value as List? ?? const []).map((e) => e as String).toList();

class Exercise {
  const Exercise({
    required this.id,
    required this.name,
    this.userId,
    this.category,
    this.equipment,
    this.level,
    this.primaryMuscles = const [],
    this.secondaryMuscles = const [],
    this.instructions = const [],
    this.images = const [],
  });

  final String id;
  final String? userId;
  final String name;
  final String? category;
  final String? equipment;
  final String? level;
  final List<String> primaryMuscles;
  final List<String> secondaryMuscles;
  final List<String> instructions;
  final List<String> images;

  bool get isCustom => userId != null;

  List<String> get imageUrls => images.map(exerciseImageUrl).toList();

  factory Exercise.fromJson(Map<String, dynamic> json) {
    return Exercise(
      id: json['id'] as String,
      userId: json['user_id'] as String?,
      name: json['name'] as String,
      category: json['category'] as String?,
      equipment: json['equipment'] as String?,
      level: json['level'] as String?,
      primaryMuscles: _stringList(json['primary_muscles']),
      secondaryMuscles: _stringList(json['secondary_muscles']),
      instructions: _stringList(json['instructions']),
      images: _stringList(json['images']),
    );
  }
}
```

- [ ] **Step 5: `WorkoutExercise`, `ProgramWorkout`, `Program`'ı yaz**

`lib/features/workout/domain/workout_exercise.dart`:

```dart
/// Bir antrenmandaki *özdeş setlerden oluşan bir blok*. Setleri farklı
/// yüzde/tekrarla yapılan hareketler (5/3/1, nSuns) art arda birden fazla blok olur.
class WorkoutExercise {
  const WorkoutExercise({
    required this.exerciseId,
    required this.exerciseName,
    required this.sets,
    required this.repsMin,
    required this.repsMax,
    this.isAmrap = false,
    this.percent1rm,
    this.percentRefExerciseId,
    this.restSeconds,
    this.notes,
  });

  final String exerciseId;
  final String exerciseName;
  final int sets;
  final int repsMin;
  final int repsMax;
  final bool isAmrap;
  final double? percent1rm;
  final String? percentRefExerciseId;
  final int? restSeconds;
  final String? notes;

  /// Yüzdenin dayandığı 1RM'nin hareketi (nSuns T2: Sumo Deadlift → Deadlift).
  String get oneRepMaxExerciseId => percentRefExerciseId ?? exerciseId;

  factory WorkoutExercise.fromJson(Map<String, dynamic> json) {
    final exercise = json['exercises'] as Map<String, dynamic>?;
    return WorkoutExercise(
      exerciseId: json['exercise_id'] as String,
      exerciseName: exercise?['name'] as String? ?? json['exercise_id'] as String,
      sets: json['sets'] as int,
      repsMin: json['reps_min'] as int,
      repsMax: json['reps_max'] as int,
      isAmrap: json['is_amrap'] as bool? ?? false,
      percent1rm: (json['percent_1rm'] as num?)?.toDouble(),
      percentRefExerciseId: json['percent_ref_exercise_id'] as String?,
      restSeconds: json['rest_seconds'] as int?,
      notes: json['notes'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'exercise_id': exerciseId,
      'sets': sets,
      'reps_min': repsMin,
      'reps_max': repsMax,
      'is_amrap': isAmrap,
      'percent_1rm': percent1rm,
      'percent_ref_exercise_id': percentRefExerciseId,
      'rest_seconds': restSeconds,
      'notes': notes,
    };
  }

  WorkoutExercise copyWith({
    String? exerciseId,
    String? exerciseName,
    int? sets,
    int? repsMin,
    int? repsMax,
    bool? isAmrap,
    double? percent1rm,
    bool clearPercent1rm = false,
    int? restSeconds,
    bool clearRestSeconds = false,
    String? notes,
    bool clearNotes = false,
  }) {
    return WorkoutExercise(
      exerciseId: exerciseId ?? this.exerciseId,
      exerciseName: exerciseName ?? this.exerciseName,
      sets: sets ?? this.sets,
      repsMin: repsMin ?? this.repsMin,
      repsMax: repsMax ?? this.repsMax,
      isAmrap: isAmrap ?? this.isAmrap,
      percent1rm: clearPercent1rm ? null : (percent1rm ?? this.percent1rm),
      percentRefExerciseId: percentRefExerciseId,
      restSeconds: clearRestSeconds ? null : (restSeconds ?? this.restSeconds),
      notes: clearNotes ? null : (notes ?? this.notes),
    );
  }
}
```

`lib/features/workout/domain/program_workout.dart`:

```dart
import 'workout_exercise.dart';

class ProgramWorkout {
  const ProgramWorkout({required this.name, required this.exercises, this.weekday});

  final String name;

  /// ISO hafta günü (1=Pzt … 7=Paz); yalnızca weekdays modunda dolu.
  final int? weekday;
  final List<WorkoutExercise> exercises;

  factory ProgramWorkout.fromJson(Map<String, dynamic> json) {
    final rows = [...(json['workout_exercises'] as List? ?? const [])]
        .cast<Map<String, dynamic>>()
      ..sort((a, b) => (a['position'] as int).compareTo(b['position'] as int));
    return ProgramWorkout(
      name: json['name'] as String,
      weekday: json['weekday'] as int?,
      exercises: rows.map(WorkoutExercise.fromJson).toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'weekday': weekday,
      'exercises': exercises.map((e) => e.toJson()).toList(),
    };
  }

  ProgramWorkout copyWith({
    String? name,
    int? weekday,
    bool clearWeekday = false,
    List<WorkoutExercise>? exercises,
  }) {
    return ProgramWorkout(
      name: name ?? this.name,
      weekday: clearWeekday ? null : (weekday ?? this.weekday),
      exercises: exercises ?? this.exercises,
    );
  }
}
```

`lib/features/workout/domain/program.dart`:

```dart
import 'program_level.dart';
import 'program_workout.dart';
import 'schedule_mode.dart';

class Program {
  const Program({
    required this.name,
    required this.scheduleMode,
    required this.workouts,
    this.id,
    this.userId,
    this.description,
    this.level,
    this.daysPerWeek,
    this.sourceProgramId,
  });

  /// Henüz kaydedilmemiş (yeni) programda null.
  final String? id;

  /// Hazır programlarda null.
  final String? userId;
  final String name;
  final String? description;
  final ProgramLevel? level;
  final ScheduleMode scheduleMode;
  final int? daysPerWeek;
  final String? sourceProgramId;
  final List<ProgramWorkout> workouts;

  bool get isBuiltIn => userId == null;

  int? get effectiveDaysPerWeek =>
      daysPerWeek ?? (scheduleMode == ScheduleMode.weekdays ? workouts.length : null);

  bool get usesPercentages =>
      workouts.any((w) => w.exercises.any((e) => e.percent1rm != null));

  /// Kilo hesabı için 1RM'si gereken hareketler.
  Set<String> get oneRepMaxExerciseIds => {
        for (final w in workouts)
          for (final e in w.exercises)
            if (e.percent1rm != null) e.oneRepMaxExerciseId,
      };

  factory Program.fromJson(Map<String, dynamic> json) {
    final rows = [...(json['program_workouts'] as List? ?? const [])]
        .cast<Map<String, dynamic>>()
      ..sort((a, b) => (a['position'] as int).compareTo(b['position'] as int));
    return Program(
      id: json['id'] as String?,
      userId: json['user_id'] as String?,
      name: json['name'] as String,
      description: json['description'] as String?,
      level: programLevelFromDb(json['level'] as String?),
      scheduleMode: scheduleModeFromDb(json['schedule_mode'] as String),
      daysPerWeek: json['days_per_week'] as int?,
      sourceProgramId: json['source_program_id'] as String?,
      workouts: rows.map(ProgramWorkout.fromJson).toList(),
    );
  }

  /// `save_program(payload jsonb)` RPC'sinin beklediği şekil.
  Map<String, dynamic> toSavePayload() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'level': programLevelToDb(level),
      'schedule_mode': scheduleModeToDb(scheduleMode),
      'days_per_week': daysPerWeek,
      'source_program_id': sourceProgramId,
      'workouts': workouts.map((w) => w.toJson()).toList(),
    };
  }

  Program copyWith({
    String? id,
    String? name,
    String? description,
    ScheduleMode? scheduleMode,
    List<ProgramWorkout>? workouts,
  }) {
    return Program(
      id: id ?? this.id,
      userId: userId,
      name: name ?? this.name,
      description: description ?? this.description,
      level: level,
      scheduleMode: scheduleMode ?? this.scheduleMode,
      daysPerWeek: daysPerWeek,
      sourceProgramId: sourceProgramId,
      workouts: workouts ?? this.workouts,
    );
  }
}
```

- [ ] **Step 6: Testlerin geçtiğini doğrula**

Run: `flutter test test/features/workout/domain/models_test.dart`
Expected: PASS (7 test)

- [ ] **Step 7: Commit**

```bash
git rm -q lib/features/workout/domain/.gitkeep
git add lib/features/workout/domain test/features/workout/domain/models_test.dart
git commit -m "feat(workout): add exercise and program domain models"
```

---

## Task 5: Saf iş mantığı — kilo hesabı, blok gruplama, "Bugün"

**Files:**
- Create: `lib/features/workout/domain/weight_calculator.dart`, `block_grouping.dart`, `today_workout.dart`
- Test: `test/features/workout/domain/weight_calculator_test.dart`, `block_grouping_test.dart`, `today_workout_test.dart`

**Interfaces:**
- Consumes: `WorkoutExercise`, `ProgramWorkout`, `Program`, `ScheduleMode` (Task 4).
- Produces:
  - `double? targetWeightKg({required double? oneRepMaxKg, required double? percent1rm})` — ikisinden biri null ise null; aksi halde `oneRepMaxKg * percent1rm / 100` en yakın 2,5'e yuvarlanmış.
  - `class ExerciseGroup { String exerciseId; String exerciseName; List<WorkoutExercise> blocks; }`; `List<ExerciseGroup> groupBlocks(List<WorkoutExercise> blocks)` — yalnızca *art arda* gelen aynı `exerciseId`'li bloklar birleşir.
  - `sealed class TodayWorkout`; alt sınıflar: `NoActiveProgram()`, `EmptyProgram(Program program)`, `RestDay(Program program)`, `ScheduledWorkout(Program program, int workoutIndex, ProgramWorkout workout)`; `TodayWorkout resolveTodayWorkout({required Program? program, required int nextRotationPosition, required DateTime now})`.

- [ ] **Step 1: Başarısız testleri yaz**

`test/features/workout/domain/weight_calculator_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:spor_takip/features/workout/domain/weight_calculator.dart';

void main() {
  test('returns null when either input is missing', () {
    expect(targetWeightKg(oneRepMaxKg: null, percent1rm: 80), isNull);
    expect(targetWeightKg(oneRepMaxKg: 100, percent1rm: null), isNull);
  });

  test('multiplies and rounds to the nearest 2.5 kg', () {
    expect(targetWeightKg(oneRepMaxKg: 100, percent1rm: 76.5), 77.5); // 76.5 → 77.5
    expect(targetWeightKg(oneRepMaxKg: 100, percent1rm: 58.5), 57.5); // 58.5 → 57.5
    expect(targetWeightKg(oneRepMaxKg: 140, percent1rm: 85.5), 120.0); // 119.7 → 120
    expect(targetWeightKg(oneRepMaxKg: 60, percent1rm: 50), 30.0);
  });
}
```

`test/features/workout/domain/block_grouping_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:spor_takip/features/workout/domain/block_grouping.dart';
import 'package:spor_takip/features/workout/domain/workout_exercise.dart';

WorkoutExercise _b(String id, {int reps = 5}) =>
    WorkoutExercise(exerciseId: id, exerciseName: id.toUpperCase(), sets: 1, repsMin: reps, repsMax: reps);

void main() {
  test('merges consecutive blocks of the same exercise', () {
    final groups = groupBlocks([_b('squat', reps: 5), _b('squat', reps: 3), _b('bench'), _b('squat')]);
    expect(groups.map((g) => g.exerciseId), ['squat', 'bench', 'squat']);
    expect(groups.first.blocks.map((b) => b.repsMin), [5, 3]);
    expect(groups.first.exerciseName, 'SQUAT');
  });

  test('empty input gives empty output', () {
    expect(groupBlocks(const []), isEmpty);
  });
}
```

`test/features/workout/domain/today_workout_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:spor_takip/features/workout/domain/program.dart';
import 'package:spor_takip/features/workout/domain/program_workout.dart';
import 'package:spor_takip/features/workout/domain/schedule_mode.dart';
import 'package:spor_takip/features/workout/domain/today_workout.dart';

const _weekly = Program(
  id: 'p',
  name: 'Weekly',
  scheduleMode: ScheduleMode.weekdays,
  workouts: [
    ProgramWorkout(name: 'Mon', weekday: 1, exercises: []),
    ProgramWorkout(name: 'Wed', weekday: 3, exercises: []),
  ],
);

const _rotation = Program(
  id: 'r',
  name: 'Rotation',
  scheduleMode: ScheduleMode.rotation,
  workouts: [
    ProgramWorkout(name: 'A', exercises: []),
    ProgramWorkout(name: 'B', exercises: []),
  ],
);

// 2026-09-28 bir Pazartesi, 2026-09-29 Salı.
final _monday = DateTime(2026, 9, 28);
final _tuesday = DateTime(2026, 9, 29);

void main() {
  test('no active program', () {
    expect(resolveTodayWorkout(program: null, nextRotationPosition: 0, now: _monday), isA<NoActiveProgram>());
  });

  test('program without workouts', () {
    const empty = Program(name: 'E', scheduleMode: ScheduleMode.rotation, workouts: []);
    expect(resolveTodayWorkout(program: empty, nextRotationPosition: 0, now: _monday), isA<EmptyProgram>());
  });

  test('weekdays mode picks the workout scheduled for today', () {
    final today = resolveTodayWorkout(program: _weekly, nextRotationPosition: 0, now: _monday);
    expect(today, isA<ScheduledWorkout>());
    today as ScheduledWorkout;
    expect(today.workout.name, 'Mon');
    expect(today.workoutIndex, 0);
  });

  test('weekdays mode with nothing scheduled today is a rest day', () {
    expect(resolveTodayWorkout(program: _weekly, nextRotationPosition: 0, now: _tuesday), isA<RestDay>());
  });

  test('rotation mode uses next position and wraps around', () {
    final first = resolveTodayWorkout(program: _rotation, nextRotationPosition: 1, now: _monday) as ScheduledWorkout;
    expect(first.workout.name, 'B');
    final wrapped = resolveTodayWorkout(program: _rotation, nextRotationPosition: 5, now: _monday) as ScheduledWorkout;
    expect(wrapped.workout.name, 'B');
    expect(wrapped.workoutIndex, 1);
  });
}
```

- [ ] **Step 2: Testlerin başarısız olduğunu doğrula**

Run: `flutter test test/features/workout/domain/`
Expected: FAIL — üç yeni dosya çözümlenemiyor (`weight_calculator.dart`, `block_grouping.dart`, `today_workout.dart`).

- [ ] **Step 3: Uygulamayı yaz**

`lib/features/workout/domain/weight_calculator.dart`:

```dart
const _plateStepKg = 2.5;

/// 1RM × yüzde; en yakın 2,5 kg'a yuvarlanır. Girdilerden biri yoksa null
/// (arayüz o zaman kilo yerine yüzdeyi gösterir).
double? targetWeightKg({required double? oneRepMaxKg, required double? percent1rm}) {
  if (oneRepMaxKg == null || percent1rm == null) return null;
  final raw = oneRepMaxKg * percent1rm / 100;
  return (raw / _plateStepKg).round() * _plateStepKg;
}
```

`lib/features/workout/domain/block_grouping.dart`:

```dart
import 'workout_exercise.dart';

class ExerciseGroup {
  const ExerciseGroup({required this.exerciseId, required this.exerciseName, required this.blocks});

  final String exerciseId;
  final String exerciseName;
  final List<WorkoutExercise> blocks;
}

/// Art arda gelen aynı hareketli blokları tek başlık altında toplar
/// (5/3/1: %65×5, %75×5, %85×5+ → "Squat" altında üç satır).
List<ExerciseGroup> groupBlocks(List<WorkoutExercise> blocks) {
  final groups = <ExerciseGroup>[];
  for (final block in blocks) {
    if (groups.isNotEmpty && groups.last.exerciseId == block.exerciseId) {
      groups.last.blocks.add(block);
    } else {
      groups.add(ExerciseGroup(
        exerciseId: block.exerciseId,
        exerciseName: block.exerciseName,
        blocks: [block],
      ));
    }
  }
  return groups;
}
```

`lib/features/workout/domain/today_workout.dart`:

```dart
import 'program.dart';
import 'program_workout.dart';
import 'schedule_mode.dart';

sealed class TodayWorkout {
  const TodayWorkout();
}

class NoActiveProgram extends TodayWorkout {
  const NoActiveProgram();
}

class EmptyProgram extends TodayWorkout {
  const EmptyProgram(this.program);
  final Program program;
}

class RestDay extends TodayWorkout {
  const RestDay(this.program);
  final Program program;
}

class ScheduledWorkout extends TodayWorkout {
  const ScheduledWorkout(this.program, this.workoutIndex, this.workout);
  final Program program;
  final int workoutIndex;
  final ProgramWorkout workout;
}

TodayWorkout resolveTodayWorkout({
  required Program? program,
  required int nextRotationPosition,
  required DateTime now,
}) {
  if (program == null) return const NoActiveProgram();
  if (program.workouts.isEmpty) return EmptyProgram(program);

  switch (program.scheduleMode) {
    case ScheduleMode.weekdays:
      final index = program.workouts.indexWhere((w) => w.weekday == now.weekday);
      return index < 0 ? RestDay(program) : ScheduledWorkout(program, index, program.workouts[index]);
    case ScheduleMode.rotation:
      final index = nextRotationPosition % program.workouts.length;
      return ScheduledWorkout(program, index, program.workouts[index]);
  }
}
```

- [ ] **Step 4: Testlerin geçtiğini doğrula**

Run: `flutter test test/features/workout/domain/`
Expected: PASS (models 7 + weight 2 + grouping 2 + today 5 = 16 test)

- [ ] **Step 5: Commit**

```bash
git add lib/features/workout/domain test/features/workout/domain
git commit -m "feat(workout): add weight calculator, block grouping and today's workout logic"
```

---

## Task 6: Repository'ler, provider'lar ve test fake'leri

**Files:**
- Create: `lib/features/workout/data/exercise_repository.dart`, `program_repository.dart`, `one_rep_max_repository.dart`
- Create: `lib/features/workout/application/workout_providers.dart`
- Create: `test/features/workout/fakes.dart`
- Test: `test/features/workout/application/workout_providers_test.dart`
- Delete: `lib/features/workout/data/.gitkeep`, `lib/features/workout/application/.gitkeep`

**Interfaces:**
- Consumes: domain modelleri (Task 4), `resolveTodayWorkout` (Task 5), `AppSupabase.client`, `isLoggedInProvider` (`lib/features/onboarding/application/auth_providers.dart`).
- Produces:
  - `abstract interface class ExerciseRepository { Future<List<Exercise>> fetchExercises(); Future<Exercise> createCustomExercise({required String name, String? primaryMuscle, String? equipment}); Future<void> deleteCustomExercise(String id); }` + `class ExerciseInUseException implements Exception`.
  - `class ActiveProgramState { const ActiveProgramState({this.programId, this.nextRotationPosition = 0}); final String? programId; final int nextRotationPosition; }`
  - `abstract interface class ProgramRepository { Future<List<Program>> fetchPrograms(); Future<Program> fetchProgram(String id); Future<String> copyProgram(String sourceId); Future<String> saveProgram(Program program); Future<void> deleteProgram(String id); Future<ActiveProgramState> fetchActiveProgramState(); Future<void> setActiveProgram(String? programId); Future<void> setRotationPosition(int position); }`
  - `abstract interface class OneRepMaxRepository { Future<Map<String, double>> fetchOneRepMaxes(); Future<void> saveOneRepMax({required String exerciseId, required double weightKg}); }`
  - Provider'lar: `exerciseRepositoryProvider`, `programRepositoryProvider`, `oneRepMaxRepositoryProvider` (`Provider<...>`); `exercisesProvider` (`FutureProvider<List<Exercise>>`, keepAlive — kütüphane oturum boyunca bir kez çekilir); `programsProvider` (`FutureProvider.autoDispose<List<Program>>`); `programDetailProvider` (`FutureProvider.autoDispose.family<Program, String>`); `oneRepMaxesProvider` (`FutureProvider.autoDispose<Map<String, double>>`); `activeProgramStateProvider` (`FutureProvider.autoDispose<ActiveProgramState>`); `todayWorkoutProvider` (`FutureProvider.autoDispose<TodayWorkout>`).
  - Test fake'leri: `FakeExerciseRepository`, `FakeProgramRepository`, `FakeOneRepMaxRepository` (aşağıdaki kod).

- [ ] **Step 1: Repository'leri yaz**

Önemli PostgREST ayrıntısı: `workout_exercises`'in `exercises`'a iki FK'sı var (`exercise_id`, `percent_ref_exercise_id`), bu yüzden gömme ifadesinde FK sütunu ipucu olarak verilmeli: `exercises!exercise_id(name)`. İpucu olmadan PostgREST "more than one relationship" hatası döner. Ayrıca PostgREST varsayılan olarak en fazla 1000 satır döndürür; hareket listesi sayfalanarak çekilir.

`lib/features/workout/data/exercise_repository.dart`:

```dart
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/exercise.dart';

/// Kendi hareketi bir programda kullanılırken silinmeye çalışıldı (FK restrict).
class ExerciseInUseException implements Exception {}

abstract interface class ExerciseRepository {
  Future<List<Exercise>> fetchExercises();

  Future<Exercise> createCustomExercise({
    required String name,
    String? primaryMuscle,
    String? equipment,
  });

  Future<void> deleteCustomExercise(String id);
}

class SupabaseExerciseRepository implements ExerciseRepository {
  SupabaseExerciseRepository(this._client);

  final SupabaseClient _client;

  static const _table = 'exercises';
  static const _pageSize = 1000;
  static const _foreignKeyViolation = '23503';

  @override
  Future<List<Exercise>> fetchExercises() async {
    final all = <Exercise>[];
    for (var from = 0;; from += _pageSize) {
      final rows = await _client
          .from(_table)
          .select()
          .order('name')
          .range(from, from + _pageSize - 1);
      all.addAll((rows as List).map((r) => Exercise.fromJson(r as Map<String, dynamic>)));
      if (rows.length < _pageSize) return all;
    }
  }

  @override
  Future<Exercise> createCustomExercise({
    required String name,
    String? primaryMuscle,
    String? equipment,
  }) async {
    final row = await _client
        .from(_table)
        .insert({
          'user_id': _client.auth.currentUser!.id,
          'name': name,
          'category': 'strength',
          'equipment': equipment,
          'primary_muscles': [?primaryMuscle],
        })
        .select()
        .single();
    return Exercise.fromJson(row);
  }

  @override
  Future<void> deleteCustomExercise(String id) async {
    try {
      await _client.from(_table).delete().eq('id', id);
    } on PostgrestException catch (error) {
      if (error.code == _foreignKeyViolation) throw ExerciseInUseException();
      rethrow;
    }
  }
}
```

> `[?primaryMuscle]` Dart 3.8+ null-aware liste elemanıdır (proje Flutter 3.47 / Dart 3.x kullanıyor). `flutter analyze` şikâyet ederse `[if (primaryMuscle != null) primaryMuscle]` yaz.

`lib/features/workout/data/program_repository.dart`:

```dart
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/program.dart';

class ActiveProgramState {
  const ActiveProgramState({this.programId, this.nextRotationPosition = 0});

  final String? programId;
  final int nextRotationPosition;
}

abstract interface class ProgramRepository {
  /// Hazır + kendi programları; antrenmanlar gömülü değil (liste ekranı için).
  Future<List<Program>> fetchPrograms();

  /// Tüm antrenman ve bloklarıyla tek program.
  Future<Program> fetchProgram(String id);

  /// Kaynağın kullanıcıya ait kopyasını oluşturur, yeni id'yi döner.
  Future<String> copyProgram(String sourceId);

  /// Program ağacını tek transaction'da yazar (id null → yeni), id'yi döner.
  Future<String> saveProgram(Program program);

  Future<void> deleteProgram(String id);

  Future<ActiveProgramState> fetchActiveProgramState();

  /// Aktif programı değiştirir ve döngü sırasını başa alır.
  Future<void> setActiveProgram(String? programId);

  Future<void> setRotationPosition(int position);
}

class SupabaseProgramRepository implements ProgramRepository {
  SupabaseProgramRepository(this._client);

  final SupabaseClient _client;

  static const _programs = 'programs';
  static const _profiles = 'profiles';
  static const _summaryColumns =
      'id, user_id, name, description, level, schedule_mode, days_per_week, source_program_id';
  static const _treeColumns =
      '*, program_workouts(*, workout_exercises(*, exercises!exercise_id(name)))';

  String get _userId => _client.auth.currentUser!.id;

  @override
  Future<List<Program>> fetchPrograms() async {
    final rows = await _client.from(_programs).select(_summaryColumns).order('name');
    return (rows as List).map((r) => Program.fromJson(r as Map<String, dynamic>)).toList();
  }

  @override
  Future<Program> fetchProgram(String id) async {
    final row = await _client.from(_programs).select(_treeColumns).eq('id', id).single();
    return Program.fromJson(row);
  }

  @override
  Future<String> copyProgram(String sourceId) async {
    final id = await _client.rpc('copy_program', params: {'source': sourceId});
    return id as String;
  }

  @override
  Future<String> saveProgram(Program program) async {
    final id = await _client.rpc('save_program', params: {'payload': program.toSavePayload()});
    return id as String;
  }

  @override
  Future<void> deleteProgram(String id) async {
    await _client.from(_programs).delete().eq('id', id);
  }

  @override
  Future<ActiveProgramState> fetchActiveProgramState() async {
    final row = await _client
        .from(_profiles)
        .select('active_program_id, next_rotation_position')
        .eq('user_id', _userId)
        .maybeSingle();
    if (row == null) return const ActiveProgramState();
    return ActiveProgramState(
      programId: row['active_program_id'] as String?,
      nextRotationPosition: row['next_rotation_position'] as int? ?? 0,
    );
  }

  @override
  Future<void> setActiveProgram(String? programId) async {
    await _client
        .from(_profiles)
        .update({'active_program_id': programId, 'next_rotation_position': 0})
        .eq('user_id', _userId);
  }

  @override
  Future<void> setRotationPosition(int position) async {
    await _client
        .from(_profiles)
        .update({'next_rotation_position': position})
        .eq('user_id', _userId);
  }
}
```

`lib/features/workout/data/one_rep_max_repository.dart`:

```dart
import 'package:supabase_flutter/supabase_flutter.dart';

abstract interface class OneRepMaxRepository {
  /// exercise_id → kg
  Future<Map<String, double>> fetchOneRepMaxes();

  Future<void> saveOneRepMax({required String exerciseId, required double weightKg});
}

class SupabaseOneRepMaxRepository implements OneRepMaxRepository {
  SupabaseOneRepMaxRepository(this._client);

  final SupabaseClient _client;

  static const _table = 'user_one_rep_maxes';

  @override
  Future<Map<String, double>> fetchOneRepMaxes() async {
    final rows = await _client.from(_table).select('exercise_id, weight_kg');
    return {
      for (final r in rows as List)
        (r as Map<String, dynamic>)['exercise_id'] as String: (r['weight_kg'] as num).toDouble(),
    };
  }

  @override
  Future<void> saveOneRepMax({required String exerciseId, required double weightKg}) async {
    await _client.from(_table).upsert({
      'user_id': _client.auth.currentUser!.id,
      'exercise_id': exerciseId,
      'weight_kg': weightKg,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });
  }
}
```

- [ ] **Step 2: Test fake'lerini yaz**

`test/features/workout/fakes.dart`:

```dart
import 'package:spor_takip/features/workout/data/exercise_repository.dart';
import 'package:spor_takip/features/workout/data/one_rep_max_repository.dart';
import 'package:spor_takip/features/workout/data/program_repository.dart';
import 'package:spor_takip/features/workout/domain/exercise.dart';
import 'package:spor_takip/features/workout/domain/program.dart';

class FakeExerciseRepository implements ExerciseRepository {
  FakeExerciseRepository([List<Exercise>? exercises]) : exercises = [...?exercises];

  final List<Exercise> exercises;
  final Set<String> inUseIds = {};
  final List<String> deletedIds = [];

  @override
  Future<List<Exercise>> fetchExercises() async => [...exercises];

  @override
  Future<Exercise> createCustomExercise({
    required String name,
    String? primaryMuscle,
    String? equipment,
  }) async {
    final exercise = Exercise(
      id: 'custom-${exercises.length}',
      userId: 'user-1',
      name: name,
      equipment: equipment,
      primaryMuscles: [?primaryMuscle],
    );
    exercises.add(exercise);
    return exercise;
  }

  @override
  Future<void> deleteCustomExercise(String id) async {
    if (inUseIds.contains(id)) throw ExerciseInUseException();
    deletedIds.add(id);
    exercises.removeWhere((e) => e.id == id);
  }
}

class FakeProgramRepository implements ProgramRepository {
  FakeProgramRepository({List<Program>? programs, this.active = const ActiveProgramState()})
      : programs = {for (final p in programs ?? const <Program>[]) p.id!: p};

  final Map<String, Program> programs;
  ActiveProgramState active;
  Object? saveError;
  final List<Program> savedPrograms = [];
  final List<String> copiedIds = [];
  final List<String> deletedIds = [];

  @override
  Future<List<Program>> fetchPrograms() async => programs.values.toList();

  @override
  Future<Program> fetchProgram(String id) async => programs[id]!;

  @override
  Future<String> copyProgram(String sourceId) async {
    copiedIds.add(sourceId);
    final newId = 'copy-of-$sourceId';
    final source = programs[sourceId]!;
    programs[newId] = Program(
      id: newId,
      userId: 'user-1',
      name: source.name,
      scheduleMode: source.scheduleMode,
      sourceProgramId: sourceId,
      workouts: source.workouts,
    );
    return newId;
  }

  @override
  Future<String> saveProgram(Program program) async {
    if (saveError != null) throw saveError!;
    savedPrograms.add(program);
    final id = program.id ?? 'new-${savedPrograms.length}';
    programs[id] = program.copyWith(id: id);
    return id;
  }

  @override
  Future<void> deleteProgram(String id) async {
    deletedIds.add(id);
    programs.remove(id);
    if (active.programId == id) active = const ActiveProgramState();
  }

  @override
  Future<ActiveProgramState> fetchActiveProgramState() async => active;

  @override
  Future<void> setActiveProgram(String? programId) async {
    active = ActiveProgramState(programId: programId);
  }

  @override
  Future<void> setRotationPosition(int position) async {
    active = ActiveProgramState(programId: active.programId, nextRotationPosition: position);
  }
}

class FakeOneRepMaxRepository implements OneRepMaxRepository {
  final Map<String, double> values = {};

  @override
  Future<Map<String, double>> fetchOneRepMaxes() async => {...values};

  @override
  Future<void> saveOneRepMax({required String exerciseId, required double weightKg}) async {
    values[exerciseId] = weightKg;
  }
}
```

- [ ] **Step 3: Başarısız provider testini yaz**

`test/features/workout/application/workout_providers_test.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spor_takip/features/onboarding/application/auth_providers.dart';
import 'package:spor_takip/features/workout/application/workout_providers.dart';
import 'package:spor_takip/features/workout/data/program_repository.dart';
import 'package:spor_takip/features/workout/domain/program.dart';
import 'package:spor_takip/features/workout/domain/program_workout.dart';
import 'package:spor_takip/features/workout/domain/schedule_mode.dart';
import 'package:spor_takip/features/workout/domain/today_workout.dart';

import '../fakes.dart';

const _rotation = Program(
  id: 'p1',
  userId: 'user-1',
  name: 'Rotation',
  scheduleMode: ScheduleMode.rotation,
  workouts: [
    ProgramWorkout(name: 'A', exercises: []),
    ProgramWorkout(name: 'B', exercises: []),
  ],
);

void main() {
  ProviderContainer containerWith(FakeProgramRepository repo, {bool loggedIn = true}) {
    final container = ProviderContainer(overrides: [
      isLoggedInProvider.overrideWithValue(loggedIn),
      programRepositoryProvider.overrideWithValue(repo),
    ]);
    addTearDown(container.dispose);
    return container;
  }

  test('todayWorkoutProvider resolves the active rotation program at its next position', () async {
    final repo = FakeProgramRepository(
      programs: [_rotation],
      active: const ActiveProgramState(programId: 'p1', nextRotationPosition: 1),
    );
    final today = await containerWith(repo).read(todayWorkoutProvider.future);
    expect(today, isA<ScheduledWorkout>());
    expect((today as ScheduledWorkout).workout.name, 'B');
  });

  test('todayWorkoutProvider is NoActiveProgram without an active program', () async {
    final today = await containerWith(FakeProgramRepository()).read(todayWorkoutProvider.future);
    expect(today, isA<NoActiveProgram>());
  });

  test('providers return empty data when logged out (no Supabase calls)', () async {
    final container = containerWith(FakeProgramRepository(programs: [_rotation]), loggedIn: false);
    expect(await container.read(programsProvider.future), isEmpty);
    expect(await container.read(todayWorkoutProvider.future), isA<NoActiveProgram>());
  });
}
```

- [ ] **Step 4: Testin başarısız olduğunu doğrula**

Run: `flutter test test/features/workout/application/workout_providers_test.dart`
Expected: FAIL — `workout_providers.dart` çözümlenemiyor.

- [ ] **Step 5: Provider'ları yaz**

`lib/features/workout/application/workout_providers.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase_client.dart';
import '../../onboarding/application/auth_providers.dart';
import '../data/exercise_repository.dart';
import '../data/one_rep_max_repository.dart';
import '../data/program_repository.dart';
import '../domain/exercise.dart';
import '../domain/program.dart';
import '../domain/today_workout.dart';

final exerciseRepositoryProvider = Provider<ExerciseRepository>((ref) {
  return SupabaseExerciseRepository(AppSupabase.client);
});

final programRepositoryProvider = Provider<ProgramRepository>((ref) {
  return SupabaseProgramRepository(AppSupabase.client);
});

final oneRepMaxRepositoryProvider = Provider<OneRepMaxRepository>((ref) {
  return SupabaseOneRepMaxRepository(AppSupabase.client);
});

/// 876+ hareket; oturum boyunca bir kez çekilir (autoDispose değil).
/// Kendi hareketi eklenince/silinince `ref.invalidate(exercisesProvider)`.
final exercisesProvider = FutureProvider<List<Exercise>>((ref) async {
  if (!ref.watch(isLoggedInProvider)) return const [];
  return ref.watch(exerciseRepositoryProvider).fetchExercises();
});

final programsProvider = FutureProvider.autoDispose<List<Program>>((ref) async {
  if (!ref.watch(isLoggedInProvider)) return const [];
  return ref.watch(programRepositoryProvider).fetchPrograms();
});

final programDetailProvider = FutureProvider.autoDispose.family<Program, String>((ref, id) {
  return ref.watch(programRepositoryProvider).fetchProgram(id);
});

final oneRepMaxesProvider = FutureProvider.autoDispose<Map<String, double>>((ref) async {
  if (!ref.watch(isLoggedInProvider)) return const {};
  return ref.watch(oneRepMaxRepositoryProvider).fetchOneRepMaxes();
});

final activeProgramStateProvider = FutureProvider.autoDispose<ActiveProgramState>((ref) async {
  if (!ref.watch(isLoggedInProvider)) return const ActiveProgramState();
  return ref.watch(programRepositoryProvider).fetchActiveProgramState();
});

final todayWorkoutProvider = FutureProvider.autoDispose<TodayWorkout>((ref) async {
  final state = await ref.watch(activeProgramStateProvider.future);
  final programId = state.programId;
  final program = programId == null ? null : await ref.watch(programDetailProvider(programId).future);
  return resolveTodayWorkout(
    program: program,
    nextRotationPosition: state.nextRotationPosition,
    now: DateTime.now(),
  );
});
```

- [ ] **Step 6: Testlerin geçtiğini doğrula**

Run: `flutter test test/features/workout/`
Expected: PASS (domain 16 + providers 3 = 19 test)

- [ ] **Step 7: Analyze + commit**

Run: `flutter analyze lib/features/workout test/features/workout`
Expected: `No issues found!`

```bash
git rm -q lib/features/workout/data/.gitkeep lib/features/workout/application/.gitkeep
git add lib/features/workout/data lib/features/workout/application test/features/workout/fakes.dart test/features/workout/application
git commit -m "feat(workout): add Supabase repositories and Riverpod providers"
```

---

## Task 7: Antrenman sekmesi ve Programlar ekranı

**Files:**
- Create: `lib/features/workout/presentation/programs_screen.dart`, `lib/features/workout/presentation/widgets/program_card.dart`
- Modify: `lib/core/app_shell.dart` (3. hedef), `lib/core/router.dart` (yeni dal), `assets/translations/tr.json`, `assets/translations/en.json`
- Modify: `test/core/app_shell_test.dart` (3 dal)
- Test: `test/features/workout/presentation/programs_screen_test.dart`
- Delete: `lib/features/workout/presentation/.gitkeep`

**Interfaces:**
- Consumes: `programsProvider`, `activeProgramStateProvider` (Task 6), `Program`, `ProgramLevel` (Task 4).
- Produces: route `/workout` → `ProgramsScreen`; `ProgramCard({required Program program, bool isActive = false, VoidCallback? onTap})`; widget key'leri: `programs_screen`, `programs_active_section`, `program_card_<id>`, `programs_level_filter_<beginner|intermediate|advanced|all>`, `programs_days_filter_<3|4|5|6|all>`, `programs_create_fab`. Sonraki görevler `/workout/...` alt rotalarını bu dala ekler.

- [ ] **Step 1: Çevirileri ekle**

`assets/translations/tr.json` içinde `nav` nesnesine `"workout": "Antrenman"` ekle ve kök nesneye yeni `workout` nesnesi ekle (sonraki görevler bu nesneye anahtar ekler):

```json
"workout": {
  "programs_title": "Programlar",
  "active_program": "Aktif program",
  "my_programs": "Programlarım",
  "built_in_programs": "Hazır programlar",
  "no_my_programs": "Henüz kendi programın yok. Hazır bir programı özelleştir veya boş program oluştur.",
  "create_program": "Boş program oluştur",
  "load_error": "Programlar yüklenemedi",
  "retry": "Tekrar dene",
  "filter_all": "Tümü",
  "days_per_week": "Haftada {count} gün",
  "level_beginner": "Başlangıç",
  "level_intermediate": "Orta",
  "level_advanced": "İleri",
  "mode_weekdays": "Sabit günler",
  "mode_rotation": "Sıralı döngü",
  "no_filter_results": "Bu filtrelere uyan program yok"
}
```

`assets/translations/en.json` içinde `nav` nesnesine `"workout": "Workout"` ve:

```json
"workout": {
  "programs_title": "Programs",
  "active_program": "Active program",
  "my_programs": "My programs",
  "built_in_programs": "Built-in programs",
  "no_my_programs": "You have no programs yet. Customize a built-in program or create an empty one.",
  "create_program": "Create empty program",
  "load_error": "Could not load programs",
  "retry": "Try again",
  "filter_all": "All",
  "days_per_week": "{count} days per week",
  "level_beginner": "Beginner",
  "level_intermediate": "Intermediate",
  "level_advanced": "Advanced",
  "mode_weekdays": "Fixed weekdays",
  "mode_rotation": "Rotation",
  "no_filter_results": "No programs match these filters"
}
```

- [ ] **Step 2: AppShell testini 3 dala güncelle (başarısız)**

`test/core/app_shell_test.dart` → `buildTestRouter()` içindeki `branches` listesine üçüncü dalı ekle:

```dart
            StatefulShellBranch(routes: [
              GoRoute(path: '/workout', builder: (context, state) => const Text('WORKOUT_SCREEN')),
            ]),
```

ve dosyanın sonuna yeni test ekle:

```dart
  testWidgets('tapping the workout destination switches branch', (tester) async {
    await tester.pumpWidget(buildTestRouter());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.fitness_center_outlined));
    await tester.pumpAndSettle();

    expect(find.text('WORKOUT_SCREEN'), findsOneWidget);
    expect(find.text('HOME_SCREEN'), findsNothing);
  });
```

İlk testin adını `'shows all nav destinations and starts on the home branch'` yap.

Run: `flutter test test/core/app_shell_test.dart`
Expected: FAIL — yeni testte `find.byIcon(Icons.fitness_center_outlined)` bulunamıyor.

- [ ] **Step 3: AppShell'e hedef ekle**

`lib/core/app_shell.dart` → `destinations` listesinin sonuna:

```dart
          NavigationDestination(
            icon: const Icon(Icons.fitness_center_outlined),
            selectedIcon: const Icon(Icons.fitness_center),
            label: 'nav.workout'.tr(),
          ),
```

Run: `flutter test test/core/app_shell_test.dart`
Expected: PASS (3 test)

- [ ] **Step 4: Programlar ekranı için başarısız testi yaz**

`test/features/workout/presentation/programs_screen_test.dart`:

```dart
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spor_takip/features/workout/application/workout_providers.dart';
import 'package:spor_takip/features/workout/data/program_repository.dart';
import 'package:spor_takip/features/workout/domain/program.dart';
import 'package:spor_takip/features/workout/domain/program_level.dart';
import 'package:spor_takip/features/workout/domain/schedule_mode.dart';
import 'package:spor_takip/features/workout/presentation/programs_screen.dart';

const _stronglifts = Program(
  id: 'sl',
  name: 'StrongLifts 5x5',
  level: ProgramLevel.beginner,
  scheduleMode: ScheduleMode.rotation,
  daysPerWeek: 3,
  workouts: [],
);
const _nsuns = Program(
  id: 'ns',
  name: 'nSuns 5/3/1 LP 4 gün',
  level: ProgramLevel.advanced,
  scheduleMode: ScheduleMode.weekdays,
  daysPerWeek: 4,
  workouts: [],
);
const _mine = Program(
  id: 'mine',
  userId: 'user-1',
  name: 'Benim programım',
  scheduleMode: ScheduleMode.weekdays,
  workouts: [],
);

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  Widget wrap({required List<Program> programs, String? activeId}) {
    final router = GoRouter(routes: [
      GoRoute(path: '/', builder: (context, state) => const ProgramsScreen()),
      GoRoute(path: '/workout/new', builder: (context, state) => const Text('EDITOR_NEW')),
      GoRoute(
        path: '/workout/program/:id',
        builder: (context, state) => Text('DETAIL_${state.pathParameters['id']}'),
      ),
    ]);
    return EasyLocalization(
      supportedLocales: const [Locale('tr'), Locale('en')],
      path: 'assets/translations',
      fallbackLocale: const Locale('tr'),
      child: ProviderScope(
        overrides: [
          programsProvider.overrideWith((ref) async => programs),
          activeProgramStateProvider.overrideWith((ref) async => ActiveProgramState(programId: activeId)),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
  }

  testWidgets('shows my programs and built-in programs', (tester) async {
    await tester.pumpWidget(wrap(programs: [_stronglifts, _nsuns, _mine]));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('programs_screen')), findsOneWidget);
    expect(find.text('Benim programım'), findsOneWidget);
    expect(find.text('StrongLifts 5x5'), findsOneWidget);
    expect(find.text('nSuns 5/3/1 LP 4 gün'), findsOneWidget);
    expect(find.byKey(const Key('programs_active_section')), findsNothing);
  });

  testWidgets('shows the active program at the top', (tester) async {
    await tester.pumpWidget(wrap(programs: [_stronglifts, _mine], activeId: 'sl'));
    await tester.pumpAndSettle();

    final activeSection = find.byKey(const Key('programs_active_section'));
    expect(activeSection, findsOneWidget);
    expect(find.descendant(of: activeSection, matching: find.text('StrongLifts 5x5')), findsOneWidget);
  });

  testWidgets('level and day filters narrow the built-in list', (tester) async {
    await tester.pumpWidget(wrap(programs: [_stronglifts, _nsuns]));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('programs_level_filter_advanced')));
    await tester.pumpAndSettle();
    expect(find.text('StrongLifts 5x5'), findsNothing);
    expect(find.text('nSuns 5/3/1 LP 4 gün'), findsOneWidget);

    await tester.tap(find.byKey(const Key('programs_level_filter_all')));
    await tester.tap(find.byKey(const Key('programs_days_filter_3')));
    await tester.pumpAndSettle();
    expect(find.text('StrongLifts 5x5'), findsOneWidget);
    expect(find.text('nSuns 5/3/1 LP 4 gün'), findsNothing);
  });

  testWidgets('tapping a card opens its detail, FAB opens the empty editor', (tester) async {
    await tester.pumpWidget(wrap(programs: [_stronglifts]));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('program_card_sl')));
    await tester.pumpAndSettle();
    expect(find.text('DETAIL_sl'), findsOneWidget);
  });

  testWidgets('create FAB navigates to the new-program editor', (tester) async {
    await tester.pumpWidget(wrap(programs: const []));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('programs_create_fab')));
    await tester.pumpAndSettle();
    expect(find.text('EDITOR_NEW'), findsOneWidget);
  });
}
```

- [ ] **Step 5: Testin başarısız olduğunu doğrula**

Run: `flutter test test/features/workout/presentation/programs_screen_test.dart`
Expected: FAIL — `programs_screen.dart` çözümlenemiyor.

- [ ] **Step 6: `ProgramCard` ve `ProgramsScreen`'i yaz**

`lib/features/workout/presentation/widgets/program_card.dart`:

```dart
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../domain/program.dart';

class ProgramCard extends StatelessWidget {
  const ProgramCard({super.key, required this.program, this.isActive = false, this.onTap});

  final Program program;
  final bool isActive;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final days = program.effectiveDaysPerWeek;
    final details = [
      if (program.level != null) 'workout.level_${program.level!.name}'.tr(),
      if (days != null) 'workout.days_per_week'.tr(namedArgs: {'count': '$days'}),
      'workout.mode_${program.scheduleMode.name}'.tr(),
    ];
    return Card(
      child: ListTile(
        key: Key('program_card_${program.id}'),
        leading: Icon(isActive ? Icons.star : Icons.fitness_center_outlined),
        title: Text(program.name),
        subtitle: Text(details.join(' · ')),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
```

`lib/features/workout/presentation/programs_screen.dart`:

```dart
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../application/workout_providers.dart';
import '../domain/program.dart';
import '../domain/program_level.dart';
import 'widgets/program_card.dart';

class ProgramsScreen extends ConsumerStatefulWidget {
  const ProgramsScreen({super.key});

  @override
  ConsumerState<ProgramsScreen> createState() => _ProgramsScreenState();
}

class _ProgramsScreenState extends ConsumerState<ProgramsScreen> {
  static const _dayOptions = [3, 4, 5, 6];

  ProgramLevel? _level;
  int? _days;

  @override
  Widget build(BuildContext context) {
    final programsAsync = ref.watch(programsProvider);
    final activeId = ref.watch(activeProgramStateProvider).value?.programId;

    return Scaffold(
      key: const Key('programs_screen'),
      appBar: AppBar(title: Text('workout.programs_title'.tr())),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('programs_create_fab'),
        onPressed: () => context.push('/workout/new'),
        icon: const Icon(Icons.add),
        label: Text('workout.create_program'.tr()),
      ),
      body: programsAsync.when(
        data: (programs) => _buildList(context, programs, activeId),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('workout.load_error'.tr()),
              TextButton(
                onPressed: () => ref.invalidate(programsProvider),
                child: Text('workout.retry'.tr()),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildList(BuildContext context, List<Program> programs, String? activeId) {
    final active = programs.where((p) => p.id == activeId).firstOrNull;
    final mine = programs.where((p) => !p.isBuiltIn).toList();
    final builtIn = programs
        .where((p) => p.isBuiltIn)
        .where((p) => _level == null || p.level == _level)
        .where((p) => _days == null || p.effectiveDaysPerWeek == _days)
        .toList();
    final titleStyle = Theme.of(context).textTheme.titleMedium;

    void open(Program p) => context.push('/workout/program/${p.id}');

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      children: [
        if (active != null)
          Column(
            key: const Key('programs_active_section'),
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('workout.active_program'.tr(), style: titleStyle),
              ProgramCard(program: active, isActive: true, onTap: () => open(active)),
              const SizedBox(height: 16),
            ],
          ),
        Text('workout.my_programs'.tr(), style: titleStyle),
        if (mine.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text('workout.no_my_programs'.tr()),
          ),
        for (final p in mine) ProgramCard(key: ValueKey('mine_${p.id}'), program: p, onTap: () => open(p)),
        const SizedBox(height: 16),
        Text('workout.built_in_programs'.tr(), style: titleStyle),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            ChoiceChip(
              key: const Key('programs_level_filter_all'),
              label: Text('workout.filter_all'.tr()),
              selected: _level == null,
              onSelected: (_) => setState(() => _level = null),
            ),
            for (final level in ProgramLevel.values)
              ChoiceChip(
                key: Key('programs_level_filter_${level.name}'),
                label: Text('workout.level_${level.name}'.tr()),
                selected: _level == level,
                onSelected: (_) => setState(() => _level = level),
              ),
          ],
        ),
        Wrap(
          spacing: 8,
          children: [
            ChoiceChip(
              key: const Key('programs_days_filter_all'),
              label: Text('workout.filter_all'.tr()),
              selected: _days == null,
              onSelected: (_) => setState(() => _days = null),
            ),
            for (final d in _dayOptions)
              ChoiceChip(
                key: Key('programs_days_filter_$d'),
                label: Text('workout.days_per_week'.tr(namedArgs: {'count': '$d'})),
                selected: _days == d,
                onSelected: (_) => setState(() => _days = d),
              ),
          ],
        ),
        if (builtIn.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text('workout.no_filter_results'.tr()),
          ),
        for (final p in builtIn) ProgramCard(key: ValueKey('builtin_${p.id}'), program: p, onTap: () => open(p)),
      ],
    );
  }
}
```

> Aktif program hem "Aktif program" bölümünde hem kendi listesinde görünür; iki `ProgramCard` aynı `program_card_<id>` iç key'ini taşır. Widget key'leri yalnızca kardeşler arasında benzersiz olmalı, farklı alt ağaçlarda tekrar sorun değil — ama `find.byKey(Key('program_card_sl'))` iki sonuç bulur. Bu yüzden testteki "tapping a card" senaryosunda aktif program yoktur; aktif bölüm testinde `find.descendant` kullanılır.

- [ ] **Step 7: Router'a dalı ekle**

`lib/core/router.dart` → import ekle:

```dart
import '../features/workout/presentation/programs_screen.dart';
```

`branches` listesinin sonuna (nutrition dalından sonra):

```dart
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/workout',
                builder: (context, state) => const ProgramsScreen(),
                routes: const [],
              ),
            ],
          ),
```

(`routes: const []` sonraki görevlerde alt rotalarla doldurulur.)

- [ ] **Step 8: Testlerin geçtiğini doğrula**

Run: `flutter test test/features/workout test/core`
Expected: PASS (workout 19 + programs_screen 5 + core testleri)

- [ ] **Step 9: Commit**

```bash
git rm -q lib/features/workout/presentation/.gitkeep
git add lib/core/app_shell.dart lib/core/router.dart lib/features/workout/presentation assets/translations test/core/app_shell_test.dart test/features/workout/presentation/programs_screen_test.dart
git commit -m "feat(workout): add workout tab with programs list and filters"
```

---

## Task 8: Program detay ekranı

**Files:**
- Create: `lib/features/workout/domain/block_format.dart`, `lib/features/workout/presentation/program_detail_screen.dart`, `lib/features/workout/presentation/widgets/exercise_group_tile.dart`
- Modify: `lib/core/router.dart`, `assets/translations/tr.json`, `assets/translations/en.json`
- Test: `test/features/workout/domain/block_format_test.dart`, `test/features/workout/presentation/program_detail_screen_test.dart`

**Interfaces:**
- Consumes: `programDetailProvider`, `activeProgramStateProvider`, `oneRepMaxesProvider`, `programsProvider`, `programRepositoryProvider` (Task 6); `groupBlocks`, `targetWeightKg` (Task 5).
- Produces:
  - `String setsRepsLabel(WorkoutExercise block)` → `'5 × 5'`, `'3 × 8–12'`, `'1 × 5+'`.
  - `String? loadLabel(WorkoutExercise block, double? oneRepMaxKg)` → `'77.5 kg'` (1RM var), `'%76.5'` (1RM yok), `null` (yüzdesiz blok). Sayılar `_trim` ile: tam sayıysa ondalıksız (`'30 kg'`, `'%45'`).
  - `class ProgramDetailScreen extends ConsumerWidget { const ProgramDetailScreen({super.key, required this.programId}); }`; içinde `Future<void> activateProgram(BuildContext, WidgetRef, Program)` Task 12'de 1RM paneliyle genişletilecek ayrı bir üst düzey fonksiyon olarak tanımlanır.
  - Route `/workout/program/:id` → `ProgramDetailScreen`.
  - Key'ler: `program_detail_screen`, `program_active_badge`, `program_activate_button`, `program_customize_button`, `program_edit_button`, `program_delete_button`, `program_delete_confirm`, `workout_section_<index>`.

- [ ] **Step 1: Biçimlendirme için başarısız test**

`test/features/workout/domain/block_format_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:spor_takip/features/workout/domain/block_format.dart';
import 'package:spor_takip/features/workout/domain/workout_exercise.dart';

WorkoutExercise _b({int sets = 1, int min = 5, int max = 5, bool amrap = false, double? pct}) =>
    WorkoutExercise(
      exerciseId: 'x',
      exerciseName: 'X',
      sets: sets,
      repsMin: min,
      repsMax: max,
      isAmrap: amrap,
      percent1rm: pct,
    );

void main() {
  test('setsRepsLabel', () {
    expect(setsRepsLabel(_b(sets: 5)), '5 × 5');
    expect(setsRepsLabel(_b(sets: 3, min: 8, max: 12)), '3 × 8–12');
    expect(setsRepsLabel(_b(amrap: true)), '1 × 5+');
  });

  test('loadLabel', () {
    expect(loadLabel(_b(), 100), isNull);
    expect(loadLabel(_b(pct: 76.5), null), '%76.5');
    expect(loadLabel(_b(pct: 45), null), '%45');
    expect(loadLabel(_b(pct: 76.5), 100), '77.5 kg');
    expect(loadLabel(_b(pct: 50), 60), '30 kg');
  });
}
```

Run: `flutter test test/features/workout/domain/block_format_test.dart`
Expected: FAIL — `block_format.dart` yok.

- [ ] **Step 2: `block_format.dart`'ı yaz**

```dart
import 'weight_calculator.dart';
import 'workout_exercise.dart';

String _trim(double value) =>
    value == value.roundToDouble() ? value.toInt().toString() : value.toString();

String setsRepsLabel(WorkoutExercise block) {
  final reps = block.repsMin == block.repsMax ? '${block.repsMin}' : '${block.repsMin}–${block.repsMax}';
  return '${block.sets} × $reps${block.isAmrap ? '+' : ''}';
}

/// 1RM varsa hesaplanan kilo, yoksa yüzde; yüzdesiz blokta null.
String? loadLabel(WorkoutExercise block, double? oneRepMaxKg) {
  final pct = block.percent1rm;
  if (pct == null) return null;
  final kg = targetWeightKg(oneRepMaxKg: oneRepMaxKg, percent1rm: pct);
  return kg == null ? '%${_trim(pct)}' : '${_trim(kg)} kg';
}
```

Run: `flutter test test/features/workout/domain/block_format_test.dart`
Expected: PASS (2 test)

- [ ] **Step 3: Çevirileri ekle**

`tr.json` → `workout` nesnesine:

```json
"detail_load_error": "Program yüklenemedi",
"active_badge": "Aktif",
"activate": "Aktif yap",
"customize": "Özelleştir",
"edit": "Düzenle",
"delete": "Sil",
"delete_confirm_title": "Program silinsin mi?",
"delete_confirm_body": "Bu işlem geri alınamaz.",
"cancel": "Vazgeç",
"action_error": "İşlem başarısız, tekrar dene",
"activated": "Program aktif edildi",
"rest_seconds": "Dinlenme: {seconds} sn",
"no_workouts": "Bu programda antrenman yok",
"weekday_1": "Pazartesi",
"weekday_2": "Salı",
"weekday_3": "Çarşamba",
"weekday_4": "Perşembe",
"weekday_5": "Cuma",
"weekday_6": "Cumartesi",
"weekday_7": "Pazar"
```

`en.json` → `workout` nesnesine:

```json
"detail_load_error": "Could not load program",
"active_badge": "Active",
"activate": "Activate",
"customize": "Customize",
"edit": "Edit",
"delete": "Delete",
"delete_confirm_title": "Delete this program?",
"delete_confirm_body": "This cannot be undone.",
"cancel": "Cancel",
"action_error": "Action failed, try again",
"activated": "Program activated",
"rest_seconds": "Rest: {seconds} s",
"no_workouts": "This program has no workouts",
"weekday_1": "Monday",
"weekday_2": "Tuesday",
"weekday_3": "Wednesday",
"weekday_4": "Thursday",
"weekday_5": "Friday",
"weekday_6": "Saturday",
"weekday_7": "Sunday"
```

- [ ] **Step 4: Detay ekranı için başarısız widget testi**

`test/features/workout/presentation/program_detail_screen_test.dart`:

```dart
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spor_takip/features/onboarding/application/auth_providers.dart';
import 'package:spor_takip/features/workout/application/workout_providers.dart';
import 'package:spor_takip/features/workout/data/program_repository.dart';
import 'package:spor_takip/features/workout/domain/program.dart';
import 'package:spor_takip/features/workout/domain/program_workout.dart';
import 'package:spor_takip/features/workout/domain/schedule_mode.dart';
import 'package:spor_takip/features/workout/domain/workout_exercise.dart';
import 'package:spor_takip/features/workout/presentation/program_detail_screen.dart';

import '../fakes.dart';

const _squat5 = WorkoutExercise(
  exerciseId: 'Barbell_Squat',
  exerciseName: 'Barbell Squat',
  sets: 1,
  repsMin: 5,
  repsMax: 5,
  percent1rm: 58.5,
);
const _squat5plus = WorkoutExercise(
  exerciseId: 'Barbell_Squat',
  exerciseName: 'Barbell Squat',
  sets: 1,
  repsMin: 5,
  repsMax: 5,
  isAmrap: true,
  percent1rm: 76.5,
);

const _builtIn = Program(
  id: 'bbb',
  name: '5/3/1 BBB',
  scheduleMode: ScheduleMode.rotation,
  workouts: [ProgramWorkout(name: 'Hafta 1 · Squat', exercises: [_squat5, _squat5plus])],
);
const _mine = Program(
  id: 'mine',
  userId: 'user-1',
  name: 'Benim programım',
  scheduleMode: ScheduleMode.weekdays,
  workouts: [ProgramWorkout(name: 'Bacak', weekday: 1, exercises: [_squat5])],
);

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  late FakeProgramRepository repo;
  late FakeOneRepMaxRepository oneRepMaxRepo;

  Widget wrap(String programId) {
    final router = GoRouter(initialLocation: '/workout', routes: [
      GoRoute(
        path: '/workout',
        builder: (context, state) => const Text('PROGRAMS'),
        routes: [
          GoRoute(
            path: 'program/:id',
            builder: (context, state) => ProgramDetailScreen(programId: state.pathParameters['id']!),
            routes: [
              GoRoute(
                path: 'edit',
                builder: (context, state) => Text('EDITOR_${state.pathParameters['id']}'),
              ),
            ],
          ),
        ],
      ),
    ]);
    return EasyLocalization(
      supportedLocales: const [Locale('tr'), Locale('en')],
      path: 'assets/translations',
      fallbackLocale: const Locale('tr'),
      child: ProviderScope(
        overrides: [
          isLoggedInProvider.overrideWithValue(true),
          programRepositoryProvider.overrideWithValue(repo),
          oneRepMaxRepositoryProvider.overrideWithValue(oneRepMaxRepo),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
  }

  Future<void> open(WidgetTester tester, String id) async {
    await tester.pumpWidget(wrap(id));
    await tester.pumpAndSettle();
    GoRouter.of(tester.element(find.text('PROGRAMS'))).push('/workout/program/$id');
    await tester.pumpAndSettle();
  }

  setUp(() {
    repo = FakeProgramRepository(programs: [_builtIn, _mine]);
    oneRepMaxRepo = FakeOneRepMaxRepository();
  });

  testWidgets('groups consecutive blocks and shows percentages without a 1RM', (tester) async {
    await open(tester, 'bbb');

    expect(find.byKey(const Key('program_detail_screen')), findsOneWidget);
    expect(find.text('Barbell Squat'), findsOneWidget); // iki blok tek başlık
    expect(find.textContaining('1 × 5+'), findsOneWidget);
    expect(find.textContaining('%76.5'), findsOneWidget);
  });

  testWidgets('shows kilograms when a 1RM is known', (tester) async {
    oneRepMaxRepo.values['Barbell_Squat'] = 100;
    await open(tester, 'bbb');

    expect(find.textContaining('77.5 kg'), findsOneWidget);
    expect(find.textContaining('57.5 kg'), findsOneWidget);
  });

  testWidgets('built-in program offers customize, which copies and opens the editor', (tester) async {
    await open(tester, 'bbb');

    expect(find.byKey(const Key('program_edit_button')), findsNothing);
    expect(find.byKey(const Key('program_delete_button')), findsNothing);
    await tester.tap(find.byKey(const Key('program_customize_button')));
    await tester.pumpAndSettle();

    expect(repo.copiedIds, ['bbb']);
    expect(find.text('EDITOR_copy-of-bbb'), findsOneWidget);
  });

  testWidgets('activate sets the active program and shows the badge', (tester) async {
    await open(tester, 'mine');

    expect(find.byKey(const Key('program_active_badge')), findsNothing);
    await tester.tap(find.byKey(const Key('program_activate_button')));
    await tester.pumpAndSettle();

    expect(repo.active.programId, 'mine');
    expect(find.byKey(const Key('program_active_badge')), findsOneWidget);
  });

  testWidgets('own program can be deleted after confirmation', (tester) async {
    await open(tester, 'mine');

    await tester.tap(find.byKey(const Key('program_delete_button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('program_delete_confirm')));
    await tester.pumpAndSettle();

    expect(repo.deletedIds, ['mine']);
    expect(find.text('PROGRAMS'), findsOneWidget);
  });
}
```

Run: `flutter test test/features/workout/presentation/program_detail_screen_test.dart`
Expected: FAIL — `program_detail_screen.dart` yok.

- [ ] **Step 5: `ExerciseGroupTile` ve `ProgramDetailScreen`'i yaz**

`lib/features/workout/presentation/widgets/exercise_group_tile.dart`:

```dart
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../domain/block_format.dart';
import '../../domain/block_grouping.dart';
import '../../domain/workout_exercise.dart';

/// Bir hareket başlığı + altında art arda gelen blokları.
class ExerciseGroupTile extends StatelessWidget {
  const ExerciseGroupTile({super.key, required this.group, required this.oneRepMaxes});

  final ExerciseGroup group;
  final Map<String, double> oneRepMaxes;

  String _line(WorkoutExercise block) {
    final parts = [
      setsRepsLabel(block),
      ?loadLabel(block, oneRepMaxes[block.oneRepMaxExerciseId]),
      if (block.restSeconds != null)
        'workout.rest_seconds'.tr(namedArgs: {'seconds': '${block.restSeconds}'}),
      ?block.notes,
    ];
    return parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(group.exerciseName),
      subtitle: Text(group.blocks.map(_line).join('\n')),
    );
  }
}
```

> `?expr` liste elemanı Dart 3.8+ null-aware element sözdizimidir; analyze reddederse `if (x != null) x` kullan.

`lib/features/workout/presentation/program_detail_screen.dart`:

```dart
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../application/workout_providers.dart';
import '../domain/block_grouping.dart';
import '../domain/program.dart';
import '../domain/schedule_mode.dart';
import 'widgets/exercise_group_tile.dart';

/// Programı aktif yapar. Task 12, yüzdelik programlar için önce 1RM panelini
/// gösterecek şekilde bu fonksiyonu genişletir.
Future<void> activateProgram(BuildContext context, WidgetRef ref, Program program) async {
  await ref.read(programRepositoryProvider).setActiveProgram(program.id);
  ref.invalidate(activeProgramStateProvider);
}

class ProgramDetailScreen extends ConsumerWidget {
  const ProgramDetailScreen({super.key, required this.programId});

  final String programId;

  Future<void> _run(BuildContext context, Future<void> Function() action) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await action();
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text('workout.action_error'.tr())));
    }
  }

  Future<void> _customize(BuildContext context, WidgetRef ref, Program program) async {
    final newId = await ref.read(programRepositoryProvider).copyProgram(program.id!);
    ref.invalidate(programsProvider);
    if (!context.mounted) return;
    // Hazır programın detayını kopyanın detayıyla değiştir, sonra düzenleyiciyi aç:
    // düzenleyici kaydedip pop ettiğinde kullanıcı kendi kopyasının detayına döner.
    final router = GoRouter.of(context);
    router.pushReplacement('/workout/program/$newId');
    router.push('/workout/program/$newId/edit');
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, Program program) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('workout.delete_confirm_title'.tr()),
        content: Text('workout.delete_confirm_body'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text('workout.cancel'.tr()),
          ),
          TextButton(
            key: const Key('program_delete_confirm'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text('workout.delete'.tr()),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(programRepositoryProvider).deleteProgram(program.id!);
    ref.invalidate(programsProvider);
    ref.invalidate(activeProgramStateProvider);
    if (context.mounted) context.pop();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final programAsync = ref.watch(programDetailProvider(programId));
    final activeId = ref.watch(activeProgramStateProvider).value?.programId;
    final oneRepMaxes = ref.watch(oneRepMaxesProvider).value ?? const <String, double>{};

    return Scaffold(
      key: const Key('program_detail_screen'),
      appBar: AppBar(title: Text(programAsync.value?.name ?? '')),
      body: programAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('workout.detail_load_error'.tr()),
              TextButton(
                onPressed: () => ref.invalidate(programDetailProvider(programId)),
                child: Text('workout.retry'.tr()),
              ),
            ],
          ),
        ),
        data: (program) {
          final isActive = program.id == activeId;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (program.description != null) Text(program.description!),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (isActive)
                    Chip(
                      key: const Key('program_active_badge'),
                      avatar: const Icon(Icons.star, size: 18),
                      label: Text('workout.active_badge'.tr()),
                    )
                  else
                    FilledButton(
                      key: const Key('program_activate_button'),
                      onPressed: () => _run(context, () => activateProgram(context, ref, program)),
                      child: Text('workout.activate'.tr()),
                    ),
                  if (program.isBuiltIn)
                    OutlinedButton(
                      key: const Key('program_customize_button'),
                      onPressed: () => _run(context, () => _customize(context, ref, program)),
                      child: Text('workout.customize'.tr()),
                    )
                  else ...[
                    OutlinedButton(
                      key: const Key('program_edit_button'),
                      onPressed: () => context.push('/workout/program/${program.id}/edit'),
                      child: Text('workout.edit'.tr()),
                    ),
                    OutlinedButton(
                      key: const Key('program_delete_button'),
                      onPressed: () => _run(context, () => _delete(context, ref, program)),
                      child: Text('workout.delete'.tr()),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 16),
              if (program.workouts.isEmpty) Text('workout.no_workouts'.tr()),
              for (final (index, workout) in program.workouts.indexed)
                Card(
                  key: Key('workout_section_$index'),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ListTile(
                        title: Text(workout.name, style: Theme.of(context).textTheme.titleMedium),
                        subtitle: program.scheduleMode == ScheduleMode.weekdays && workout.weekday != null
                            ? Text('workout.weekday_${workout.weekday}'.tr())
                            : null,
                      ),
                      for (final group in groupBlocks(workout.exercises))
                        ExerciseGroupTile(group: group, oneRepMaxes: oneRepMaxes),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
```

- [ ] **Step 6: Router'a rotayı ekle**

`lib/core/router.dart` → import:

```dart
import '../features/workout/presentation/program_detail_screen.dart';
```

`/workout` rotasının `routes: const []` listesini şununla değiştir:

```dart
                routes: [
                  GoRoute(
                    path: 'program/:id',
                    builder: (context, state) =>
                        ProgramDetailScreen(programId: state.pathParameters['id']!),
                  ),
                ],
```

- [ ] **Step 7: Testlerin geçtiğini doğrula**

Run: `flutter test test/features/workout`
Expected: PASS (önceki testler + block_format 2 + detail 5)

- [ ] **Step 8: Commit**

```bash
git add lib/features/workout lib/core/router.dart assets/translations test/features/workout
git commit -m "feat(workout): add program detail screen with grouped blocks and actions"
```

---

## Task 9: Program düzenleyici state'i ve notifier'ı

**Files:**
- Create: `lib/features/workout/application/program_editor_state.dart`, `lib/features/workout/application/program_editor_notifier.dart`
- Test: `test/features/workout/application/program_editor_notifier_test.dart`

**Interfaces:**
- Consumes: `Program`, `ProgramWorkout`, `WorkoutExercise`, `Exercise`, `ScheduleMode` (Task 4); `programRepositoryProvider`, `programsProvider`, `programDetailProvider` (Task 6).
- Produces:
  - `enum EditorValidationError { emptyName, emptyWorkoutName, missingWeekday }`
  - `class ProgramEditorState { Program? draft; bool dirty; bool saving; bool saveFailed; EditorValidationError? get validationError; ProgramEditorState copyWith({Program? draft, bool? dirty, bool? saving, bool? saveFailed}); }` — `draft == null` = henüz yüklenmedi.
  - `final programEditorProvider = NotifierProvider.autoDispose<ProgramEditorNotifier, ProgramEditorState>(ProgramEditorNotifier.new);`
  - `ProgramEditorNotifier` metotları: `void start(Program program)`, `void startBlank()`, `void rename(String name)`, `void setScheduleMode(ScheduleMode mode)` (rotation'a geçişte tüm `weekday`'ler temizlenir), `void addWorkout(String name)`, `void renameWorkout(int index, String name)`, `void removeWorkout(int index)`, `void moveWorkout(int from, int to)` (doğrudan indeks: `from` çıkarılır, `to`'ya eklenir), `bool setWeekday(int index, int? weekday)` (başka antrenmanda aynı gün varsa değişiklik yapmaz, `false` döner), `void addBlock(int workoutIndex, Exercise exercise)` (varsayılan 3 × 8–12, 90 sn), `void updateBlock(int workoutIndex, int blockIndex, WorkoutExercise block)`, `void removeBlock(int workoutIndex, int blockIndex)`, `void moveBlock(int workoutIndex, int from, int to)`, `Future<String?> save()` (geçersiz/kaydediliyor → `null`; başarı → id, `dirty=false`; hata → `null`, `saveFailed=true`, taslak korunur).

- [ ] **Step 1: Başarısız testleri yaz**

`test/features/workout/application/program_editor_notifier_test.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spor_takip/features/onboarding/application/auth_providers.dart';
import 'package:spor_takip/features/workout/application/program_editor_notifier.dart';
import 'package:spor_takip/features/workout/application/program_editor_state.dart';
import 'package:spor_takip/features/workout/application/workout_providers.dart';
import 'package:spor_takip/features/workout/domain/exercise.dart';
import 'package:spor_takip/features/workout/domain/program.dart';
import 'package:spor_takip/features/workout/domain/program_workout.dart';
import 'package:spor_takip/features/workout/domain/schedule_mode.dart';

import '../fakes.dart';

const _squat = Exercise(id: 'Barbell_Squat', name: 'Barbell Squat');
const _bench = Exercise(id: 'Bench', name: 'Bench');

void main() {
  late FakeProgramRepository repo;
  late ProviderContainer container;

  ProgramEditorNotifier notifier() => container.read(programEditorProvider.notifier);
  ProgramEditorState state() => container.read(programEditorProvider);

  setUp(() {
    repo = FakeProgramRepository();
    container = ProviderContainer(overrides: [
      isLoggedInProvider.overrideWithValue(true),
      programRepositoryProvider.overrideWithValue(repo),
    ]);
    // autoDispose provider'ı test boyunca canlı tut.
    container.listen(programEditorProvider, (_, _) {});
  });

  tearDown(() => container.dispose());

  test('startBlank creates an empty weekdays draft that is not dirty', () {
    notifier().startBlank();
    expect(state().draft!.name, '');
    expect(state().draft!.scheduleMode, ScheduleMode.weekdays);
    expect(state().dirty, isFalse);
    expect(state().validationError, EditorValidationError.emptyName);
  });

  test('edits mark the draft dirty and validation follows the draft', () {
    notifier()
      ..startBlank()
      ..rename('Benim programım')
      ..addWorkout('Gün 1');
    expect(state().dirty, isTrue);
    expect(state().validationError, EditorValidationError.missingWeekday);

    expect(notifier().setWeekday(0, 1), isTrue);
    expect(state().validationError, isNull);

    notifier().renameWorkout(0, '  ');
    expect(state().validationError, EditorValidationError.emptyWorkoutName);
  });

  test('setWeekday rejects a day already used by another workout', () {
    notifier()
      ..startBlank()
      ..addWorkout('A')
      ..addWorkout('B');
    expect(notifier().setWeekday(0, 3), isTrue);
    expect(notifier().setWeekday(1, 3), isFalse);
    expect(state().draft!.workouts[1].weekday, isNull);
    expect(notifier().setWeekday(0, 3), isTrue, reason: 'same workout may keep its own day');
  });

  test('switching to rotation clears weekdays', () {
    notifier()
      ..startBlank()
      ..addWorkout('A');
    notifier().setWeekday(0, 2);
    notifier().setScheduleMode(ScheduleMode.rotation);
    expect(state().draft!.workouts.single.weekday, isNull);
    expect(state().validationError, EditorValidationError.emptyName);
  });

  test('blocks can be added with defaults, updated, moved and removed', () {
    notifier()
      ..startBlank()
      ..addWorkout('A')
      ..addBlock(0, _squat)
      ..addBlock(0, _bench);
    final first = state().draft!.workouts[0].exercises.first;
    expect(first.exerciseId, 'Barbell_Squat');
    expect([first.sets, first.repsMin, first.repsMax, first.restSeconds], [3, 8, 12, 90]);

    notifier().updateBlock(0, 0, first.copyWith(sets: 5, repsMin: 5, repsMax: 5));
    expect(state().draft!.workouts[0].exercises.first.sets, 5);

    notifier().moveBlock(0, 1, 0);
    expect(state().draft!.workouts[0].exercises.map((b) => b.exerciseId), ['Bench', 'Barbell_Squat']);

    notifier().removeBlock(0, 0);
    expect(state().draft!.workouts[0].exercises.map((b) => b.exerciseId), ['Barbell_Squat']);
  });

  test('workouts can be moved and removed', () {
    notifier()
      ..startBlank()
      ..addWorkout('A')
      ..addWorkout('B')
      ..addWorkout('C')
      ..moveWorkout(2, 0);
    expect(state().draft!.workouts.map((w) => w.name), ['C', 'A', 'B']);
    notifier().removeWorkout(1);
    expect(state().draft!.workouts.map((w) => w.name), ['C', 'B']);
  });

  test('save writes the draft, returns the id and clears dirty', () async {
    notifier()
      ..startBlank()
      ..rename('Mine')
      ..setScheduleMode(ScheduleMode.rotation)
      ..addWorkout('A')
      ..addBlock(0, _squat);

    final id = await notifier().save();

    expect(id, 'new-1');
    expect(repo.savedPrograms.single.name, 'Mine');
    expect(state().draft!.id, 'new-1');
    expect(state().dirty, isFalse);
    expect(state().saving, isFalse);
  });

  test('save refuses an invalid draft without calling the repository', () async {
    notifier().startBlank();
    expect(await notifier().save(), isNull);
    expect(repo.savedPrograms, isEmpty);
  });

  test('failed save keeps the draft and flags the failure', () async {
    repo.saveError = Exception('network');
    notifier().start(const Program(
      id: 'p1',
      userId: 'user-1',
      name: 'Mine',
      scheduleMode: ScheduleMode.rotation,
      workouts: [ProgramWorkout(name: 'A', exercises: [])],
    ));
    notifier().rename('Mine v2');

    expect(await notifier().save(), isNull);
    expect(state().saveFailed, isTrue);
    expect(state().dirty, isTrue);
    expect(state().draft!.name, 'Mine v2');
  });
}
```

- [ ] **Step 2: Testin başarısız olduğunu doğrula**

Run: `flutter test test/features/workout/application/program_editor_notifier_test.dart`
Expected: FAIL — `program_editor_notifier.dart` çözümlenemiyor.

- [ ] **Step 3: State'i yaz**

`lib/features/workout/application/program_editor_state.dart`:

```dart
import '../domain/program.dart';
import '../domain/schedule_mode.dart';

enum EditorValidationError { emptyName, emptyWorkoutName, missingWeekday }

class ProgramEditorState {
  const ProgramEditorState({this.draft, this.dirty = false, this.saving = false, this.saveFailed = false});

  /// null = düzenlenecek program henüz yüklenmedi.
  final Program? draft;
  final bool dirty;
  final bool saving;
  final bool saveFailed;

  EditorValidationError? get validationError {
    final d = draft;
    if (d == null) return null;
    if (d.name.trim().isEmpty) return EditorValidationError.emptyName;
    if (d.workouts.any((w) => w.name.trim().isEmpty)) return EditorValidationError.emptyWorkoutName;
    if (d.scheduleMode == ScheduleMode.weekdays && d.workouts.any((w) => w.weekday == null)) {
      return EditorValidationError.missingWeekday;
    }
    return null;
  }

  ProgramEditorState copyWith({Program? draft, bool? dirty, bool? saving, bool? saveFailed}) {
    return ProgramEditorState(
      draft: draft ?? this.draft,
      dirty: dirty ?? this.dirty,
      saving: saving ?? this.saving,
      saveFailed: saveFailed ?? this.saveFailed,
    );
  }
}
```

- [ ] **Step 4: Notifier'ı yaz**

`lib/features/workout/application/program_editor_notifier.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/exercise.dart';
import '../domain/program.dart';
import '../domain/program_workout.dart';
import '../domain/schedule_mode.dart';
import '../domain/workout_exercise.dart';
import 'program_editor_state.dart';
import 'workout_providers.dart';

final programEditorProvider =
    NotifierProvider.autoDispose<ProgramEditorNotifier, ProgramEditorState>(ProgramEditorNotifier.new);

List<T> _move<T>(List<T> list, int from, int to) {
  final copy = [...list];
  final item = copy.removeAt(from);
  copy.insert(to, item);
  return copy;
}

/// Değişiklikler yalnızca yerel taslakta tutulur; `save()` tüm ağacı tek RPC ile yazar.
class ProgramEditorNotifier extends Notifier<ProgramEditorState> {
  @override
  ProgramEditorState build() => const ProgramEditorState();

  void start(Program program) => state = ProgramEditorState(draft: program);

  void startBlank() => state = const ProgramEditorState(
        draft: Program(name: '', scheduleMode: ScheduleMode.weekdays, workouts: []),
      );

  void _edit(Program Function(Program draft) change) {
    final draft = state.draft;
    if (draft == null) return;
    state = state.copyWith(draft: change(draft), dirty: true, saveFailed: false);
  }

  void _editWorkout(int index, ProgramWorkout Function(ProgramWorkout workout) change) {
    _edit((p) => p.copyWith(workouts: [...p.workouts]..[index] = change(p.workouts[index])));
  }

  void rename(String name) => _edit((p) => p.copyWith(name: name));

  void setScheduleMode(ScheduleMode mode) => _edit((p) => p.copyWith(
        scheduleMode: mode,
        workouts: mode == ScheduleMode.rotation
            ? [for (final w in p.workouts) w.copyWith(clearWeekday: true)]
            : p.workouts,
      ));

  void addWorkout(String name) =>
      _edit((p) => p.copyWith(workouts: [...p.workouts, ProgramWorkout(name: name, exercises: const [])]));

  void renameWorkout(int index, String name) => _editWorkout(index, (w) => w.copyWith(name: name));

  void removeWorkout(int index) => _edit((p) => p.copyWith(workouts: [...p.workouts]..removeAt(index)));

  void moveWorkout(int from, int to) => _edit((p) => p.copyWith(workouts: _move(p.workouts, from, to)));

  bool setWeekday(int index, int? weekday) {
    final draft = state.draft;
    if (draft == null) return false;
    final taken = weekday != null &&
        draft.workouts.indexed.any((entry) => entry.$1 != index && entry.$2.weekday == weekday);
    if (taken) return false;
    _editWorkout(index, (w) => weekday == null ? w.copyWith(clearWeekday: true) : w.copyWith(weekday: weekday));
    return true;
  }

  void addBlock(int workoutIndex, Exercise exercise) => _editWorkout(
        workoutIndex,
        (w) => w.copyWith(exercises: [
          ...w.exercises,
          WorkoutExercise(
            exerciseId: exercise.id,
            exerciseName: exercise.name,
            sets: 3,
            repsMin: 8,
            repsMax: 12,
            restSeconds: 90,
          ),
        ]),
      );

  void updateBlock(int workoutIndex, int blockIndex, WorkoutExercise block) =>
      _editWorkout(workoutIndex, (w) => w.copyWith(exercises: [...w.exercises]..[blockIndex] = block));

  void removeBlock(int workoutIndex, int blockIndex) =>
      _editWorkout(workoutIndex, (w) => w.copyWith(exercises: [...w.exercises]..removeAt(blockIndex)));

  void moveBlock(int workoutIndex, int from, int to) =>
      _editWorkout(workoutIndex, (w) => w.copyWith(exercises: _move(w.exercises, from, to)));

  Future<String?> save() async {
    final draft = state.draft;
    if (draft == null || state.validationError != null || state.saving) return null;
    state = state.copyWith(saving: true, saveFailed: false);
    try {
      final id = await ref.read(programRepositoryProvider).saveProgram(draft);
      state = ProgramEditorState(draft: draft.copyWith(id: id));
      ref.invalidate(programsProvider);
      ref.invalidate(programDetailProvider(id));
      return id;
    } catch (_) {
      state = state.copyWith(saving: false, saveFailed: true);
      return null;
    }
  }
}
```

- [ ] **Step 5: Testlerin geçtiğini doğrula**

Run: `flutter test test/features/workout/application/`
Expected: PASS (providers 3 + editor 9)

- [ ] **Step 6: Commit**

```bash
git add lib/features/workout/application test/features/workout/application/program_editor_notifier_test.dart
git commit -m "feat(workout): add program editor state and notifier"
```

---

## Task 10: Program düzenleyici ekranı

**Files:**
- Create: `lib/features/workout/presentation/program_editor_screen.dart`, `lib/features/workout/presentation/widgets/block_edit_dialog.dart`
- Modify: `lib/core/router.dart`, `assets/translations/tr.json`, `assets/translations/en.json`
- Test: `test/features/workout/presentation/program_editor_screen_test.dart`

**Interfaces:**
- Consumes: `programEditorProvider`, `EditorValidationError` (Task 9); `programRepositoryProvider` (Task 6); `setsRepsLabel`, `loadLabel` (Task 8); route `/workout/exercises` (Task 11 ekler; bu görev yalnızca `context.push<Exercise>('/workout/exercises')` çağırır).
- Produces:
  - `class ProgramEditorScreen extends ConsumerStatefulWidget { const ProgramEditorScreen({super.key, this.programId}); final String? programId; }` — `programId == null` → boş program.
  - `Future<WorkoutExercise?> showBlockEditDialog(BuildContext context, WorkoutExercise block)`.
  - Rotalar: `/workout/new` → `ProgramEditorScreen()`, `/workout/program/:id/edit` → `ProgramEditorScreen(programId: id)`.
  - Kaydetme sonrası: yeni program → `pushReplacement('/workout/program/<id>')`; var olan → `pop()`.
  - Key'ler: `program_editor_screen`, `editor_name_field`, `editor_mode_weekdays`, `editor_mode_rotation` (segment etiketleri), `editor_save_button`, `editor_add_workout`, `editor_workout_<i>`, `editor_workout_rename_<i>`, `editor_workout_up_<i>`, `editor_workout_down_<i>`, `editor_workout_delete_<i>`, `editor_weekday_<i>`, `weekday_option_<1..7>`, `editor_add_block_<i>`, `editor_block_<i>_<b>`, `editor_block_menu_<i>_<b>`, `block_menu_up`, `block_menu_down`, `block_menu_delete`, `rename_field`, `rename_ok`, `discard_confirm`; diyalog: `block_sets_field`, `block_reps_min_field`, `block_reps_max_field`, `block_percent_field`, `block_rest_field`, `block_amrap_switch`, `block_save_button`.

- [ ] **Step 1: Çevirileri ekle**

`tr.json` → `workout`:

```json
"editor_title_new": "Yeni program",
"editor_title_edit": "Programı düzenle",
"editor_name_label": "Program adı",
"editor_save": "Kaydet",
"editor_add_workout": "Antrenman ekle",
"editor_add_block": "Hareket ekle",
"editor_default_workout_name": "Antrenman {n}",
"editor_rename_title": "Antrenman adı",
"editor_weekday_hint": "Gün seç",
"editor_weekday_taken": "Bu güne zaten bir antrenman atanmış",
"editor_error_emptyName": "Program adı boş olamaz",
"editor_error_emptyWorkoutName": "Antrenman adları boş olamaz",
"editor_error_missingWeekday": "Her antrenmana bir gün seç",
"editor_save_error": "Kaydedilemedi, tekrar dene. Değişikliklerin kaybolmadı.",
"editor_load_error": "Program yüklenemedi",
"editor_discard_title": "Değişiklikler kaydedilmedi",
"editor_discard_body": "Çıkarsan kaydedilmemiş değişiklikler kaybolacak.",
"editor_discard": "Çık",
"move_up": "Yukarı taşı",
"move_down": "Aşağı taşı",
"ok": "Tamam",
"block_title": "Set ayarları",
"block_sets": "Set",
"block_reps_min": "Tekrar (en az)",
"block_reps_max": "Tekrar (en çok)",
"block_percent": "1RM yüzdesi (opsiyonel)",
"block_rest": "Dinlenme (sn, opsiyonel)",
"block_amrap": "Son set: yapabildiğin kadar (AMRAP)",
"block_invalid": "Set ve tekrar pozitif olmalı; en çok tekrar en azdan küçük olamaz."
```

`en.json` → `workout`:

```json
"editor_title_new": "New program",
"editor_title_edit": "Edit program",
"editor_name_label": "Program name",
"editor_save": "Save",
"editor_add_workout": "Add workout",
"editor_add_block": "Add exercise",
"editor_default_workout_name": "Workout {n}",
"editor_rename_title": "Workout name",
"editor_weekday_hint": "Pick a day",
"editor_weekday_taken": "Another workout is already on this day",
"editor_error_emptyName": "Program name cannot be empty",
"editor_error_emptyWorkoutName": "Workout names cannot be empty",
"editor_error_missingWeekday": "Pick a day for every workout",
"editor_save_error": "Could not save, try again. Your changes are kept.",
"editor_load_error": "Could not load program",
"editor_discard_title": "Unsaved changes",
"editor_discard_body": "Leaving will discard your unsaved changes.",
"editor_discard": "Leave",
"move_up": "Move up",
"move_down": "Move down",
"ok": "OK",
"block_title": "Set settings",
"block_sets": "Sets",
"block_reps_min": "Reps (min)",
"block_reps_max": "Reps (max)",
"block_percent": "% of 1RM (optional)",
"block_rest": "Rest (s, optional)",
"block_amrap": "Last set: as many reps as possible (AMRAP)",
"block_invalid": "Sets and reps must be positive; max reps cannot be below min reps."
```

- [ ] **Step 2: Başarısız widget testlerini yaz**

`test/features/workout/presentation/program_editor_screen_test.dart`:

```dart
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spor_takip/features/onboarding/application/auth_providers.dart';
import 'package:spor_takip/features/workout/application/workout_providers.dart';
import 'package:spor_takip/features/workout/domain/exercise.dart';
import 'package:spor_takip/features/workout/domain/program.dart';
import 'package:spor_takip/features/workout/domain/program_workout.dart';
import 'package:spor_takip/features/workout/domain/schedule_mode.dart';
import 'package:spor_takip/features/workout/domain/workout_exercise.dart';
import 'package:spor_takip/features/workout/presentation/program_editor_screen.dart';

import '../fakes.dart';

const _picked = Exercise(id: 'Barbell_Squat', name: 'Barbell Squat');

const _existing = Program(
  id: 'mine',
  userId: 'user-1',
  name: 'Benim programım',
  scheduleMode: ScheduleMode.rotation,
  workouts: [
    ProgramWorkout(name: 'A', exercises: [
      WorkoutExercise(exerciseId: 'Bench', exerciseName: 'Bench', sets: 3, repsMin: 8, repsMax: 12),
      WorkoutExercise(exerciseId: 'Row', exerciseName: 'Row', sets: 3, repsMin: 8, repsMax: 12),
    ]),
  ],
);

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  late FakeProgramRepository repo;

  setUp(() => repo = FakeProgramRepository(programs: [_existing]));

  Widget wrap(String initial) {
    final router = GoRouter(initialLocation: '/workout', routes: [
      GoRoute(
        path: '/workout',
        builder: (context, state) => const Text('PROGRAMS'),
        routes: [
          GoRoute(path: 'new', builder: (context, state) => const ProgramEditorScreen()),
          GoRoute(
            path: 'exercises',
            builder: (context, state) => Scaffold(
              body: TextButton(
                key: const Key('fake_pick'),
                onPressed: () => context.pop(_picked),
                child: const Text('PICK'),
              ),
            ),
          ),
          GoRoute(
            path: 'program/:id',
            builder: (context, state) => Text('DETAIL_${state.pathParameters['id']}'),
            routes: [
              GoRoute(
                path: 'edit',
                builder: (context, state) => ProgramEditorScreen(programId: state.pathParameters['id']),
              ),
            ],
          ),
        ],
      ),
    ]);
    return EasyLocalization(
      supportedLocales: const [Locale('tr'), Locale('en')],
      path: 'assets/translations',
      fallbackLocale: const Locale('tr'),
      child: ProviderScope(
        overrides: [
          isLoggedInProvider.overrideWithValue(true),
          programRepositoryProvider.overrideWithValue(repo),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
  }

  Future<void> open(WidgetTester tester, String location) async {
    await tester.pumpWidget(wrap(location));
    await tester.pumpAndSettle();
    GoRouter.of(tester.element(find.text('PROGRAMS'))).push(location);
    await tester.pumpAndSettle();
  }

  testWidgets('builds a new weekdays program and saves it', (tester) async {
    await open(tester, '/workout/new');

    await tester.enterText(find.byKey(const Key('editor_name_field')), 'Yeni program');
    await tester.tap(find.byKey(const Key('editor_add_workout')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('editor_weekday_0')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('weekday_option_1')).last);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('editor_add_block_0')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('fake_pick')));
    await tester.pumpAndSettle();
    expect(find.text('Barbell Squat'), findsOneWidget);

    await tester.tap(find.byKey(const Key('editor_save_button')));
    await tester.pumpAndSettle();

    final saved = repo.savedPrograms.single;
    expect(saved.name, 'Yeni program');
    expect(saved.workouts.single.weekday, 1);
    expect(saved.workouts.single.exercises.single.exerciseId, 'Barbell_Squat');
    expect(find.text('DETAIL_new-1'), findsOneWidget);
  });

  testWidgets('does not save an invalid program', (tester) async {
    await open(tester, '/workout/new');

    await tester.tap(find.byKey(const Key('editor_save_button')));
    await tester.pumpAndSettle();

    expect(repo.savedPrograms, isEmpty);
    expect(find.byType(SnackBar), findsOneWidget);
  });

  testWidgets('edits an existing program: loads it, reorders a block, saves and pops', (tester) async {
    await tester.pumpWidget(wrap('/workout'));
    await tester.pumpAndSettle();
    final router = GoRouter.of(tester.element(find.text('PROGRAMS')));
    router.push('/workout/program/mine');
    await tester.pumpAndSettle();
    router.push('/workout/program/mine/edit');
    await tester.pumpAndSettle();

    expect(find.widgetWithText(TextField, 'Benim programım'), findsOneWidget);

    await tester.tap(find.byKey(const Key('editor_block_menu_0_1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('block_menu_up')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('editor_save_button')));
    await tester.pumpAndSettle();

    expect(repo.savedPrograms.single.workouts.single.exercises.map((b) => b.exerciseId), ['Row', 'Bench']);
    expect(find.text('DETAIL_mine'), findsOneWidget);
  });

  testWidgets('leaving with unsaved changes asks for confirmation', (tester) async {
    await open(tester, '/workout/new');
    await tester.enterText(find.byKey(const Key('editor_name_field')), 'Taslak');
    await tester.pumpAndSettle();

    final navigator = tester.state<NavigatorState>(find.byType(Navigator).last);
    navigator.maybePop();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('discard_confirm')));
    await tester.pumpAndSettle();

    expect(find.text('PROGRAMS'), findsOneWidget);
    expect(repo.savedPrograms, isEmpty);
  });

  testWidgets('editing a block through the dialog updates sets and reps', (tester) async {
    await tester.pumpWidget(wrap('/workout'));
    await tester.pumpAndSettle();
    final router = GoRouter.of(tester.element(find.text('PROGRAMS')));
    router.push('/workout/program/mine/edit');
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('editor_block_0_0')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('block_sets_field')), '5');
    await tester.enterText(find.byKey(const Key('block_reps_min_field')), '5');
    await tester.enterText(find.byKey(const Key('block_reps_max_field')), '5');
    await tester.tap(find.byKey(const Key('block_save_button')));
    await tester.pumpAndSettle();

    expect(find.textContaining('5 × 5'), findsOneWidget);
  });
}
```

- [ ] **Step 3: Testin başarısız olduğunu doğrula**

Run: `flutter test test/features/workout/presentation/program_editor_screen_test.dart`
Expected: FAIL — `program_editor_screen.dart` çözümlenemiyor.

- [ ] **Step 4: Blok diyaloğunu yaz**

`lib/features/workout/presentation/widgets/block_edit_dialog.dart`:

```dart
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../domain/workout_exercise.dart';

Future<WorkoutExercise?> showBlockEditDialog(BuildContext context, WorkoutExercise block) {
  return showDialog<WorkoutExercise>(
    context: context,
    builder: (_) => _BlockEditDialog(block: block),
  );
}

class _BlockEditDialog extends StatefulWidget {
  const _BlockEditDialog({required this.block});

  final WorkoutExercise block;

  @override
  State<_BlockEditDialog> createState() => _BlockEditDialogState();
}

class _BlockEditDialogState extends State<_BlockEditDialog> {
  late final _sets = TextEditingController(text: '${widget.block.sets}');
  late final _repsMin = TextEditingController(text: '${widget.block.repsMin}');
  late final _repsMax = TextEditingController(text: '${widget.block.repsMax}');
  late final _percent = TextEditingController(text: widget.block.percent1rm?.toString() ?? '');
  late final _rest = TextEditingController(text: widget.block.restSeconds?.toString() ?? '');
  late bool _amrap = widget.block.isAmrap;
  bool _invalid = false;

  @override
  void dispose() {
    for (final c in [_sets, _repsMin, _repsMax, _percent, _rest]) {
      c.dispose();
    }
    super.dispose();
  }

  void _submit() {
    final sets = int.tryParse(_sets.text.trim());
    final repsMin = int.tryParse(_repsMin.text.trim());
    final repsMax = int.tryParse(_repsMax.text.trim());
    final percentText = _percent.text.trim().replaceAll(',', '.');
    final percent = percentText.isEmpty ? null : double.tryParse(percentText);
    final restText = _rest.text.trim();
    final rest = restText.isEmpty ? null : int.tryParse(restText);

    final valid = sets != null &&
        sets > 0 &&
        repsMin != null &&
        repsMin > 0 &&
        repsMax != null &&
        repsMax >= repsMin &&
        (percentText.isEmpty || (percent != null && percent > 0 && percent <= 100)) &&
        (restText.isEmpty || (rest != null && rest >= 0));
    if (!valid) {
      setState(() => _invalid = true);
      return;
    }
    Navigator.of(context).pop(widget.block.copyWith(
      sets: sets,
      repsMin: repsMin,
      repsMax: repsMax,
      isAmrap: _amrap,
      percent1rm: percent,
      clearPercent1rm: percent == null,
      restSeconds: rest,
      clearRestSeconds: rest == null,
    ));
  }

  Widget _field(Key key, TextEditingController controller, String label) {
    return TextField(
      key: key,
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(labelText: label),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('${widget.block.exerciseName} — ${'workout.block_title'.tr()}'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _field(const Key('block_sets_field'), _sets, 'workout.block_sets'.tr()),
            _field(const Key('block_reps_min_field'), _repsMin, 'workout.block_reps_min'.tr()),
            _field(const Key('block_reps_max_field'), _repsMax, 'workout.block_reps_max'.tr()),
            _field(const Key('block_percent_field'), _percent, 'workout.block_percent'.tr()),
            _field(const Key('block_rest_field'), _rest, 'workout.block_rest'.tr()),
            SwitchListTile(
              key: const Key('block_amrap_switch'),
              contentPadding: EdgeInsets.zero,
              title: Text('workout.block_amrap'.tr()),
              value: _amrap,
              onChanged: (v) => setState(() => _amrap = v),
            ),
            if (_invalid)
              Text(
                'workout.block_invalid'.tr(),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: Text('workout.cancel'.tr())),
        FilledButton(
          key: const Key('block_save_button'),
          onPressed: _submit,
          child: Text('workout.ok'.tr()),
        ),
      ],
    );
  }
}
```

- [ ] **Step 5: Düzenleyici ekranını yaz**

`lib/features/workout/presentation/program_editor_screen.dart`:

```dart
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../application/program_editor_notifier.dart';
import '../application/workout_providers.dart';
import '../domain/block_format.dart';
import '../domain/exercise.dart';
import '../domain/program_workout.dart';
import '../domain/schedule_mode.dart';
import 'widgets/block_edit_dialog.dart';

enum _BlockAction { up, down, delete }

class ProgramEditorScreen extends ConsumerStatefulWidget {
  const ProgramEditorScreen({super.key, this.programId});

  /// null → boş (yeni) program.
  final String? programId;

  @override
  ConsumerState<ProgramEditorScreen> createState() => _ProgramEditorScreenState();
}

class _ProgramEditorScreenState extends ConsumerState<ProgramEditorScreen> {
  final _name = TextEditingController();
  bool _loadFailed = false;
  bool _leaving = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final notifier = ref.read(programEditorProvider.notifier);
    final id = widget.programId;
    if (id == null) {
      notifier.startBlank();
      return;
    }
    try {
      final program = await ref.read(programRepositoryProvider).fetchProgram(id);
      if (!mounted) return;
      _name.text = program.name;
      notifier.start(program);
    } catch (_) {
      if (mounted) setState(() => _loadFailed = true);
    }
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _save() async {
    final error = ref.read(programEditorProvider).validationError;
    if (error != null) {
      _snack('workout.editor_error_${error.name}'.tr());
      return;
    }
    final id = await ref.read(programEditorProvider.notifier).save();
    if (!mounted) return;
    if (id == null) {
      _snack('workout.editor_save_error'.tr());
      return;
    }
    if (widget.programId == null) {
      context.pushReplacement('/workout/program/$id');
    } else {
      context.pop();
    }
  }

  Future<void> _renameWorkout(int index, String current) async {
    final controller = TextEditingController(text: current);
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('workout.editor_rename_title'.tr()),
        content: TextField(key: const Key('rename_field'), controller: controller, autofocus: true),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text('workout.cancel'.tr()),
          ),
          FilledButton(
            key: const Key('rename_ok'),
            onPressed: () => Navigator.of(dialogContext).pop(controller.text),
            child: Text('workout.ok'.tr()),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name != null) ref.read(programEditorProvider.notifier).renameWorkout(index, name);
  }

  Future<void> _addBlock(int workoutIndex) async {
    final exercise = await context.push<Exercise>('/workout/exercises');
    if (exercise != null) ref.read(programEditorProvider.notifier).addBlock(workoutIndex, exercise);
  }

  Future<void> _editBlock(int workoutIndex, int blockIndex, ProgramWorkout workout) async {
    final updated = await showBlockEditDialog(context, workout.exercises[blockIndex]);
    if (updated != null) {
      ref.read(programEditorProvider.notifier).updateBlock(workoutIndex, blockIndex, updated);
    }
  }

  Future<bool> _confirmDiscard() async {
    final leave = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('workout.editor_discard_title'.tr()),
        content: Text('workout.editor_discard_body'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text('workout.cancel'.tr()),
          ),
          TextButton(
            key: const Key('discard_confirm'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text('workout.editor_discard'.tr()),
          ),
        ],
      ),
    );
    return leave ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(programEditorProvider);
    final notifier = ref.read(programEditorProvider.notifier);
    final draft = state.draft;

    return PopScope(
      canPop: !state.dirty || _leaving,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (!await _confirmDiscard() || !mounted) return;
        // canPop'un yeni değeri ancak yeniden çizimden sonra geçerli olur;
        // aynı karede pop edersek PopScope yine engeller ve diyalog tekrar açılır.
        setState(() => _leaving = true);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) context.pop();
        });
      },
      child: Scaffold(
        key: const Key('program_editor_screen'),
        appBar: AppBar(
          title: Text(widget.programId == null ? 'workout.editor_title_new'.tr() : 'workout.editor_title_edit'.tr()),
          actions: [
            IconButton(
              key: const Key('editor_save_button'),
              tooltip: 'workout.editor_save'.tr(),
              onPressed: state.saving || draft == null ? null : _save,
              icon: state.saving
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.check),
            ),
          ],
        ),
        body: _loadFailed
            ? Center(child: Text('workout.editor_load_error'.tr()))
            : draft == null
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                    children: [
                      TextField(
                        key: const Key('editor_name_field'),
                        controller: _name,
                        decoration: InputDecoration(labelText: 'workout.editor_name_label'.tr()),
                        onChanged: notifier.rename,
                      ),
                      const SizedBox(height: 16),
                      SegmentedButton<ScheduleMode>(
                        segments: [
                          ButtonSegment(
                            value: ScheduleMode.weekdays,
                            label: Text('workout.mode_weekdays'.tr(), key: const Key('editor_mode_weekdays')),
                          ),
                          ButtonSegment(
                            value: ScheduleMode.rotation,
                            label: Text('workout.mode_rotation'.tr(), key: const Key('editor_mode_rotation')),
                          ),
                        ],
                        selected: {draft.scheduleMode},
                        onSelectionChanged: (s) => notifier.setScheduleMode(s.single),
                      ),
                      const SizedBox(height: 16),
                      for (final (i, workout) in draft.workouts.indexed)
                        _workoutCard(i, workout, draft.workouts.length, draft.scheduleMode),
                      OutlinedButton.icon(
                        key: const Key('editor_add_workout'),
                        onPressed: () => notifier.addWorkout(
                          'workout.editor_default_workout_name'.tr(namedArgs: {'n': '${draft.workouts.length + 1}'}),
                        ),
                        icon: const Icon(Icons.add),
                        label: Text('workout.editor_add_workout'.tr()),
                      ),
                    ],
                  ),
      ),
    );
  }

  Widget _workoutCard(int i, ProgramWorkout workout, int count, ScheduleMode mode) {
    final notifier = ref.read(programEditorProvider.notifier);
    return Card(
      key: Key('editor_workout_$i'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            title: Text(workout.name, style: Theme.of(context).textTheme.titleMedium),
            trailing: Wrap(
              children: [
                IconButton(
                  key: Key('editor_workout_rename_$i'),
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () => _renameWorkout(i, workout.name),
                ),
                IconButton(
                  key: Key('editor_workout_up_$i'),
                  tooltip: 'workout.move_up'.tr(),
                  icon: const Icon(Icons.arrow_upward),
                  onPressed: i == 0 ? null : () => notifier.moveWorkout(i, i - 1),
                ),
                IconButton(
                  key: Key('editor_workout_down_$i'),
                  tooltip: 'workout.move_down'.tr(),
                  icon: const Icon(Icons.arrow_downward),
                  onPressed: i == count - 1 ? null : () => notifier.moveWorkout(i, i + 1),
                ),
                IconButton(
                  key: Key('editor_workout_delete_$i'),
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => notifier.removeWorkout(i),
                ),
              ],
            ),
          ),
          if (mode == ScheduleMode.weekdays)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: DropdownButton<int>(
                key: Key('editor_weekday_$i'),
                value: workout.weekday,
                hint: Text('workout.editor_weekday_hint'.tr()),
                items: [
                  for (var d = 1; d <= 7; d++)
                    DropdownMenuItem(
                      key: Key('weekday_option_$d'),
                      value: d,
                      child: Text('workout.weekday_$d'.tr()),
                    ),
                ],
                onChanged: (d) {
                  if (!notifier.setWeekday(i, d)) _snack('workout.editor_weekday_taken'.tr());
                },
              ),
            ),
          for (final (b, block) in workout.exercises.indexed)
            ListTile(
              key: Key('editor_block_${i}_$b'),
              title: Text(block.exerciseName),
              subtitle: Text([setsRepsLabel(block), ?loadLabel(block, null)].join(' · ')),
              onTap: () => _editBlock(i, b, workout),
              trailing: PopupMenuButton<_BlockAction>(
                key: Key('editor_block_menu_${i}_$b'),
                onSelected: (action) => switch (action) {
                  _BlockAction.up => notifier.moveBlock(i, b, b - 1),
                  _BlockAction.down => notifier.moveBlock(i, b, b + 1),
                  _BlockAction.delete => notifier.removeBlock(i, b),
                },
                itemBuilder: (_) => [
                  if (b > 0)
                    PopupMenuItem(
                      key: const Key('block_menu_up'),
                      value: _BlockAction.up,
                      child: Text('workout.move_up'.tr()),
                    ),
                  if (b < workout.exercises.length - 1)
                    PopupMenuItem(
                      key: const Key('block_menu_down'),
                      value: _BlockAction.down,
                      child: Text('workout.move_down'.tr()),
                    ),
                  PopupMenuItem(
                    key: const Key('block_menu_delete'),
                    value: _BlockAction.delete,
                    child: Text('workout.delete'.tr()),
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: TextButton.icon(
              key: Key('editor_add_block_$i'),
              onPressed: () => _addBlock(i),
              icon: const Icon(Icons.add),
              label: Text('workout.editor_add_block'.tr()),
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 6: Router'a rotaları ekle**

`lib/core/router.dart` → import:

```dart
import '../features/workout/presentation/program_editor_screen.dart';
```

`/workout` rotasının `routes` listesine (`program/:id`'den önce) ekle:

```dart
                  GoRoute(path: 'new', builder: (context, state) => const ProgramEditorScreen()),
```

ve `program/:id` rotasına alt rota ekle:

```dart
                    routes: [
                      GoRoute(
                        path: 'edit',
                        builder: (context, state) =>
                            ProgramEditorScreen(programId: state.pathParameters['id']),
                      ),
                    ],
```

- [ ] **Step 7: Testlerin geçtiğini doğrula**

Run: `flutter test test/features/workout`
Expected: PASS (önceki testler + editor ekranı 5)

Muhtemel sorun: `DropdownButton` açıldığında seçenekler hem kapalı düğmede hem menüde bulunur — test bu yüzden `find.byKey(Key('weekday_option_1')).last` kullanır. Test bulamazsa `find.byKey(...)` sonucunu `tester.widgetList` ile inceleyip menü katmanındakini seç; test mantığını gevşetme.

- [ ] **Step 8: Commit**

```bash
git add lib/features/workout lib/core/router.dart assets/translations test/features/workout/presentation/program_editor_screen_test.dart
git commit -m "feat(workout): add program editor screen with workout and block editing"
```

---

## Task 11: Hareket seçici

**Files:**
- Create: `lib/features/workout/domain/exercise_taxonomy.dart`, `lib/features/workout/domain/exercise_filter.dart`
- Create: `lib/features/workout/presentation/exercise_picker_screen.dart`, `lib/features/workout/presentation/widgets/exercise_detail_sheet.dart`
- Modify: `lib/core/router.dart`, `assets/translations/tr.json`, `assets/translations/en.json`
- Test: `test/features/workout/domain/exercise_filter_test.dart`, `test/features/workout/presentation/exercise_picker_screen_test.dart`

**Interfaces:**
- Consumes: `Exercise` (Task 4); `exercisesProvider`, `exerciseRepositoryProvider`, `ExerciseInUseException` (Task 6).
- Produces:
  - `const muscleGroups = <String>[...17]`, `const equipmentTypes = <String>[...12]`, `String muscleLabelKey(String muscle)`, `String equipmentLabelKey(String equipment)` — boşluk ve tire `_` olur: `'lower back'` → `'workout.muscle.lower_back'`, `'e-z curl bar'` → `'workout.equipment.e_z_curl_bar'`.
  - `List<Exercise> filterExercises(List<Exercise> all, {String query = '', String? muscle, String? equipment})` — isimde büyük/küçük harf duyarsız alt dize; `muscle` birincil kaslar arasında; `equipment` eşit.
  - `class ExercisePickerScreen extends ConsumerStatefulWidget` — seçilen `Exercise` ile `pop` eder.
  - `Future<bool?> showExerciseDetailSheet(BuildContext context, Exercise exercise, {bool selectable = true})` — "Seç"e basılırsa `true`.
  - Route `/workout/exercises` → `ExercisePickerScreen`.
  - Key'ler: `exercise_picker_screen`, `exercise_search_field`, `muscle_filter_<muscle_key>` (`muscleLabelKey`'in son parçası, örn. `muscle_filter_lower_back`), `equipment_filter_<equipment_key>`, `exercise_tile_<id>`, `exercise_select_button`, `exercise_image_fallback`, `exercise_create_fab`, `custom_exercise_name`, `custom_exercise_muscle`, `custom_exercise_equipment`, `custom_exercise_save`, `custom_delete_confirm`.

- [ ] **Step 1: Filtre için başarısız test**

`test/features/workout/domain/exercise_filter_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:spor_takip/features/workout/domain/exercise.dart';
import 'package:spor_takip/features/workout/domain/exercise_filter.dart';
import 'package:spor_takip/features/workout/domain/exercise_taxonomy.dart';

const _all = [
  Exercise(id: 'sq', name: 'Barbell Squat', equipment: 'barbell', primaryMuscles: ['quadriceps']),
  Exercise(id: 'bp', name: 'Barbell Bench Press', equipment: 'barbell', primaryMuscles: ['chest']),
  Exercise(id: 'pu', name: 'Pushups', equipment: 'body only', primaryMuscles: ['chest']),
];

void main() {
  test('query matches name case-insensitively', () {
    expect(filterExercises(_all, query: 'bench').map((e) => e.id), ['bp']);
    expect(filterExercises(_all, query: '  BARBELL ').map((e) => e.id), ['sq', 'bp']);
  });

  test('muscle and equipment filters combine', () {
    expect(filterExercises(_all, muscle: 'chest').map((e) => e.id), ['bp', 'pu']);
    expect(filterExercises(_all, muscle: 'chest', equipment: 'body only').map((e) => e.id), ['pu']);
  });

  test('taxonomy lists and label keys', () {
    expect(muscleGroups, hasLength(17));
    expect(equipmentTypes, hasLength(12));
    expect(muscleLabelKey('lower back'), 'workout.muscle.lower_back');
    expect(equipmentLabelKey('e-z curl bar'), 'workout.equipment.e_z_curl_bar');
  });
}
```

Run: `flutter test test/features/workout/domain/exercise_filter_test.dart`
Expected: FAIL — dosyalar yok.

- [ ] **Step 2: Taksonomi ve filtreyi yaz**

`lib/features/workout/domain/exercise_taxonomy.dart`:

```dart
/// free-exercise-db'deki tüm `primaryMuscles` değerleri (17).
const muscleGroups = <String>[
  'abdominals',
  'abductors',
  'adductors',
  'biceps',
  'calves',
  'chest',
  'forearms',
  'glutes',
  'hamstrings',
  'lats',
  'lower back',
  'middle back',
  'neck',
  'quadriceps',
  'shoulders',
  'traps',
  'triceps',
];

/// free-exercise-db'deki tüm null olmayan `equipment` değerleri (12).
const equipmentTypes = <String>[
  'bands',
  'barbell',
  'body only',
  'cable',
  'dumbbell',
  'e-z curl bar',
  'exercise ball',
  'foam roll',
  'kettlebells',
  'machine',
  'medicine ball',
  'other',
];

String _slug(String value) => value.replaceAll(RegExp(r'[ -]'), '_');

String muscleLabelKey(String muscle) => 'workout.muscle.${_slug(muscle)}';

String equipmentLabelKey(String equipment) => 'workout.equipment.${_slug(equipment)}';

/// Widget key'lerinde kullanılan kısa ad (`lower back` → `lower_back`).
String taxonomySlug(String value) => _slug(value);
```

`lib/features/workout/domain/exercise_filter.dart`:

```dart
import 'exercise.dart';

List<Exercise> filterExercises(
  List<Exercise> all, {
  String query = '',
  String? muscle,
  String? equipment,
}) {
  final q = query.trim().toLowerCase();
  return all
      .where((e) => q.isEmpty || e.name.toLowerCase().contains(q))
      .where((e) => muscle == null || e.primaryMuscles.contains(muscle))
      .where((e) => equipment == null || e.equipment == equipment)
      .toList();
}
```

Run: `flutter test test/features/workout/domain/exercise_filter_test.dart`
Expected: PASS (3 test)

- [ ] **Step 3: Çevirileri ekle**

`tr.json` → `workout` nesnesine:

```json
"picker_title": "Hareket seç",
"picker_search": "Hareket ara (İngilizce)",
"picker_load_error": "Hareketler yüklenemedi",
"picker_no_results": "Sonuç yok",
"picker_select": "Seç",
"picker_primary_muscles": "Ana kaslar",
"picker_instructions": "Nasıl yapılır",
"custom_exercise_title": "Kendi hareketini ekle",
"custom_exercise_name": "Hareket adı",
"custom_exercise_muscle": "Ana kas grubu",
"custom_exercise_equipment": "Ekipman",
"custom_exercise_badge": "Senin hareketin",
"custom_delete_title": "Hareket silinsin mi?",
"exercise_in_use": "Bu hareket bir programında kullanılıyor, önce programdan çıkar.",
"muscle": {
  "abdominals": "Karın",
  "abductors": "Kalça dışı (abduktör)",
  "adductors": "İç bacak (adduktör)",
  "biceps": "Ön kol kası (biseps)",
  "calves": "Baldır",
  "chest": "Göğüs",
  "forearms": "Ön kol",
  "glutes": "Kalça",
  "hamstrings": "Arka bacak",
  "lats": "Kanat (latissimus)",
  "lower_back": "Alt sırt",
  "middle_back": "Orta sırt",
  "neck": "Boyun",
  "quadriceps": "Ön bacak (quadriceps)",
  "shoulders": "Omuz",
  "traps": "Trapez",
  "triceps": "Arka kol (triseps)"
},
"equipment": {
  "bands": "Direnç bandı",
  "barbell": "Halter (barbell)",
  "body_only": "Vücut ağırlığı",
  "cable": "Kablo",
  "dumbbell": "Dambıl",
  "e_z_curl_bar": "EZ bar",
  "exercise_ball": "Pilates topu",
  "foam_roll": "Foam roller",
  "kettlebells": "Kettlebell",
  "machine": "Makine",
  "medicine_ball": "Sağlık topu",
  "other": "Diğer"
}
```

`en.json` → `workout` nesnesine:

```json
"picker_title": "Choose exercise",
"picker_search": "Search exercises",
"picker_load_error": "Could not load exercises",
"picker_no_results": "No results",
"picker_select": "Select",
"picker_primary_muscles": "Primary muscles",
"picker_instructions": "Instructions",
"custom_exercise_title": "Add your own exercise",
"custom_exercise_name": "Exercise name",
"custom_exercise_muscle": "Primary muscle group",
"custom_exercise_equipment": "Equipment",
"custom_exercise_badge": "Your exercise",
"custom_delete_title": "Delete this exercise?",
"exercise_in_use": "This exercise is used in one of your programs; remove it there first.",
"muscle": {
  "abdominals": "Abdominals",
  "abductors": "Abductors",
  "adductors": "Adductors",
  "biceps": "Biceps",
  "calves": "Calves",
  "chest": "Chest",
  "forearms": "Forearms",
  "glutes": "Glutes",
  "hamstrings": "Hamstrings",
  "lats": "Lats",
  "lower_back": "Lower back",
  "middle_back": "Middle back",
  "neck": "Neck",
  "quadriceps": "Quadriceps",
  "shoulders": "Shoulders",
  "traps": "Traps",
  "triceps": "Triceps"
},
"equipment": {
  "bands": "Bands",
  "barbell": "Barbell",
  "body_only": "Body only",
  "cable": "Cable",
  "dumbbell": "Dumbbell",
  "e_z_curl_bar": "EZ curl bar",
  "exercise_ball": "Exercise ball",
  "foam_roll": "Foam roll",
  "kettlebells": "Kettlebells",
  "machine": "Machine",
  "medicine_ball": "Medicine ball",
  "other": "Other"
}
```

- [ ] **Step 4: Seçici ekranı için başarısız widget testi**

`test/features/workout/presentation/exercise_picker_screen_test.dart`:

```dart
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spor_takip/features/onboarding/application/auth_providers.dart';
import 'package:spor_takip/features/workout/application/workout_providers.dart';
import 'package:spor_takip/features/workout/domain/exercise.dart';
import 'package:spor_takip/features/workout/presentation/exercise_picker_screen.dart';

import '../fakes.dart';

const _squat = Exercise(
  id: 'Barbell_Squat',
  name: 'Barbell Squat',
  equipment: 'barbell',
  primaryMuscles: ['quadriceps'],
  instructions: ['Stand under the bar.'],
  images: ['Barbell_Squat/0.jpg'],
);
const _pushups = Exercise(id: 'Pushups', name: 'Pushups', equipment: 'body only', primaryMuscles: ['chest']);
const _mine = Exercise(id: 'custom-0', userId: 'user-1', name: 'My Move', primaryMuscles: ['chest']);

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  late FakeExerciseRepository repo;

  setUp(() => repo = FakeExerciseRepository([_squat, _pushups, _mine]));

  Widget wrap() {
    final router = GoRouter(initialLocation: '/caller', routes: [
      GoRoute(
        path: '/caller',
        builder: (context, state) => _Caller(),
      ),
      GoRoute(path: '/workout/exercises', builder: (context, state) => const ExercisePickerScreen()),
    ]);
    return EasyLocalization(
      supportedLocales: const [Locale('tr'), Locale('en')],
      path: 'assets/translations',
      fallbackLocale: const Locale('tr'),
      child: ProviderScope(
        overrides: [
          isLoggedInProvider.overrideWithValue(true),
          exerciseRepositoryProvider.overrideWithValue(repo),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
  }

  Future<void> openPicker(WidgetTester tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('open_picker')));
    await tester.pumpAndSettle();
  }

  testWidgets('search narrows the list', (tester) async {
    await openPicker(tester);
    expect(find.byKey(const Key('exercise_tile_Barbell_Squat')), findsOneWidget);

    await tester.enterText(find.byKey(const Key('exercise_search_field')), 'push');
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('exercise_tile_Barbell_Squat')), findsNothing);
    expect(find.byKey(const Key('exercise_tile_Pushups')), findsOneWidget);
  });

  testWidgets('muscle filter chip narrows the list', (tester) async {
    await openPicker(tester);

    await tester.tap(find.byKey(const Key('muscle_filter_quadriceps')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('exercise_tile_Barbell_Squat')), findsOneWidget);
    expect(find.byKey(const Key('exercise_tile_Pushups')), findsNothing);
  });

  testWidgets('detail sheet shows a fallback when the image fails and select returns the exercise',
      (tester) async {
    await openPicker(tester);

    await tester.tap(find.byKey(const Key('exercise_tile_Barbell_Squat')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Stand under the bar.'), findsOneWidget);
    expect(find.byKey(const Key('exercise_image_fallback')), findsWidgets);

    await tester.tap(find.byKey(const Key('exercise_select_button')));
    await tester.pumpAndSettle();

    expect(find.text('PICKED_Barbell_Squat'), findsOneWidget);
  });

  testWidgets('creating a custom exercise returns it to the caller', (tester) async {
    await openPicker(tester);

    await tester.tap(find.byKey(const Key('exercise_create_fab')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('custom_exercise_name')), 'Landmine Press');
    await tester.tap(find.byKey(const Key('custom_exercise_save')));
    await tester.pumpAndSettle();

    expect(repo.exercises.last.name, 'Landmine Press');
    expect(find.textContaining('PICKED_custom-'), findsOneWidget);
  });

  testWidgets('deleting a custom exercise that is in use shows a message', (tester) async {
    repo.inUseIds.add('custom-0');
    await openPicker(tester);

    await tester.longPress(find.byKey(const Key('exercise_tile_custom-0')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('custom_delete_confirm')));
    await tester.pumpAndSettle();

    expect(repo.deletedIds, isEmpty);
    expect(find.byType(SnackBar), findsOneWidget);
  });
}

class _Caller extends StatefulWidget {
  @override
  State<_Caller> createState() => _CallerState();
}

class _CallerState extends State<_Caller> {
  String _picked = 'NONE';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Text('PICKED_$_picked'),
          TextButton(
            key: const Key('open_picker'),
            onPressed: () async {
              final e = await context.push<Exercise>('/workout/exercises');
              if (e != null) setState(() => _picked = e.id);
            },
            child: const Text('OPEN'),
          ),
        ],
      ),
    );
  }
}
```

Run: `flutter test test/features/workout/presentation/exercise_picker_screen_test.dart`
Expected: FAIL — `exercise_picker_screen.dart` yok.

> Widget testlerinde `Image.network` gerçek ağa çıkmaz; Flutter test ortamı HTTP isteklerine 400 döner ve `errorBuilder` devreye girer — `exercise_image_fallback` bu yolu doğrular.

- [ ] **Step 5: Detay panelini yaz**

`lib/features/workout/presentation/widgets/exercise_detail_sheet.dart`:

```dart
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../domain/exercise.dart';
import '../../domain/exercise_taxonomy.dart';

Future<bool?> showExerciseDetailSheet(BuildContext context, Exercise exercise, {bool selectable = true}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _ExerciseDetailSheet(exercise: exercise, selectable: selectable),
  );
}

class _ExerciseDetailSheet extends StatelessWidget {
  const _ExerciseDetailSheet({required this.exercise, required this.selectable});

  final Exercise exercise;
  final bool selectable;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.8,
      builder: (context, controller) => ListView(
        controller: controller,
        padding: const EdgeInsets.all(16),
        children: [
          Text(exercise.name, style: theme.textTheme.titleLarge),
          const SizedBox(height: 12),
          if (exercise.imageUrls.isNotEmpty)
            SizedBox(
              height: 160,
              child: Row(
                children: [
                  for (final url in exercise.imageUrls)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Image.network(
                          url,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) => const Icon(
                            Icons.image_not_supported_outlined,
                            key: Key('exercise_image_fallback'),
                            size: 48,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          const SizedBox(height: 12),
          if (exercise.primaryMuscles.isNotEmpty) ...[
            Text('workout.picker_primary_muscles'.tr(), style: theme.textTheme.titleSmall),
            Text(exercise.primaryMuscles.map((m) => muscleLabelKey(m).tr()).join(', ')),
            const SizedBox(height: 12),
          ],
          if (exercise.instructions.isNotEmpty) ...[
            Text('workout.picker_instructions'.tr(), style: theme.textTheme.titleSmall),
            for (final (i, step) in exercise.instructions.indexed)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text('${i + 1}. $step'),
              ),
          ],
          if (selectable) ...[
            const SizedBox(height: 16),
            FilledButton(
              key: const Key('exercise_select_button'),
              onPressed: () => Navigator.of(context).pop(true),
              child: Text('workout.picker_select'.tr()),
            ),
          ],
        ],
      ),
    );
  }
}
```

- [ ] **Step 6: Seçici ekranını yaz**

`lib/features/workout/presentation/exercise_picker_screen.dart`:

```dart
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../application/workout_providers.dart';
import '../data/exercise_repository.dart';
import '../domain/exercise.dart';
import '../domain/exercise_filter.dart';
import '../domain/exercise_taxonomy.dart';
import 'widgets/exercise_detail_sheet.dart';

class ExercisePickerScreen extends ConsumerStatefulWidget {
  const ExercisePickerScreen({super.key});

  @override
  ConsumerState<ExercisePickerScreen> createState() => _ExercisePickerScreenState();
}

class _ExercisePickerScreenState extends ConsumerState<ExercisePickerScreen> {
  String _query = '';
  String? _muscle;
  String? _equipment;

  void _snack(String message) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));

  Future<void> _openDetail(Exercise exercise) async {
    final selected = await showExerciseDetailSheet(context, exercise);
    if (selected == true && mounted) context.pop(exercise);
  }

  Future<void> _createCustom() async {
    final created = await showDialog<Exercise>(
      context: context,
      builder: (_) => const _CustomExerciseDialog(),
    );
    if (created == null || !mounted) return;
    ref.invalidate(exercisesProvider);
    context.pop(created);
  }

  Future<void> _deleteCustom(Exercise exercise) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('workout.custom_delete_title'.tr()),
        content: Text(exercise.name),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text('workout.cancel'.tr()),
          ),
          TextButton(
            key: const Key('custom_delete_confirm'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text('workout.delete'.tr()),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(exerciseRepositoryProvider).deleteCustomExercise(exercise.id);
      ref.invalidate(exercisesProvider);
    } on ExerciseInUseException {
      _snack('workout.exercise_in_use'.tr());
    } catch (_) {
      _snack('workout.action_error'.tr());
    }
  }

  @override
  Widget build(BuildContext context) {
    final exercisesAsync = ref.watch(exercisesProvider);

    return Scaffold(
      key: const Key('exercise_picker_screen'),
      appBar: AppBar(title: Text('workout.picker_title'.tr())),
      floatingActionButton: FloatingActionButton(
        key: const Key('exercise_create_fab'),
        tooltip: 'workout.custom_exercise_title'.tr(),
        onPressed: _createCustom,
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              key: const Key('exercise_search_field'),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: 'workout.picker_search'.tr(),
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          _chipRow(
            values: muscleGroups,
            selected: _muscle,
            keyPrefix: 'muscle_filter_',
            label: (m) => muscleLabelKey(m).tr(),
            onSelected: (m) => setState(() => _muscle = m),
          ),
          _chipRow(
            values: equipmentTypes,
            selected: _equipment,
            keyPrefix: 'equipment_filter_',
            label: (e) => equipmentLabelKey(e).tr(),
            onSelected: (e) => setState(() => _equipment = e),
          ),
          Expanded(
            child: exercisesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stackTrace) => Center(
                child: TextButton(
                  onPressed: () => ref.invalidate(exercisesProvider),
                  child: Text('workout.picker_load_error'.tr()),
                ),
              ),
              data: (all) {
                final results = filterExercises(all, query: _query, muscle: _muscle, equipment: _equipment);
                if (results.isEmpty) return Center(child: Text('workout.picker_no_results'.tr()));
                return ListView.builder(
                  padding: const EdgeInsets.only(bottom: 88),
                  itemCount: results.length,
                  itemBuilder: (context, index) {
                    final e = results[index];
                    return ListTile(
                      key: Key('exercise_tile_${e.id}'),
                      title: Text(e.name),
                      subtitle: Text([
                        ...e.primaryMuscles.map((m) => muscleLabelKey(m).tr()),
                        if (e.isCustom) 'workout.custom_exercise_badge'.tr(),
                      ].join(' · ')),
                      onTap: () => _openDetail(e),
                      onLongPress: e.isCustom ? () => _deleteCustom(e) : null,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _chipRow({
    required List<String> values,
    required String? selected,
    required String keyPrefix,
    required String Function(String) label,
    required void Function(String?) onSelected,
  }) {
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        children: [
          for (final v in values)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: FilterChip(
                key: Key('$keyPrefix${taxonomySlug(v)}'),
                label: Text(label(v)),
                selected: selected == v,
                onSelected: (on) => onSelected(on ? v : null),
              ),
            ),
        ],
      ),
    );
  }
}

class _CustomExerciseDialog extends ConsumerStatefulWidget {
  const _CustomExerciseDialog();

  @override
  ConsumerState<_CustomExerciseDialog> createState() => _CustomExerciseDialogState();
}

class _CustomExerciseDialogState extends ConsumerState<_CustomExerciseDialog> {
  final _name = TextEditingController();
  String? _muscle;
  String? _equipment;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty || _saving) return;
    setState(() => _saving = true);
    try {
      final created = await ref
          .read(exerciseRepositoryProvider)
          .createCustomExercise(name: name, primaryMuscle: _muscle, equipment: _equipment);
      if (mounted) Navigator.of(context).pop(created);
    } catch (_) {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('workout.custom_exercise_title'.tr()),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            key: const Key('custom_exercise_name'),
            controller: _name,
            decoration: InputDecoration(labelText: 'workout.custom_exercise_name'.tr()),
          ),
          DropdownButton<String>(
            key: const Key('custom_exercise_muscle'),
            isExpanded: true,
            value: _muscle,
            hint: Text('workout.custom_exercise_muscle'.tr()),
            items: [
              for (final m in muscleGroups) DropdownMenuItem(value: m, child: Text(muscleLabelKey(m).tr())),
            ],
            onChanged: (m) => setState(() => _muscle = m),
          ),
          DropdownButton<String>(
            key: const Key('custom_exercise_equipment'),
            isExpanded: true,
            value: _equipment,
            hint: Text('workout.custom_exercise_equipment'.tr()),
            items: [
              for (final e in equipmentTypes) DropdownMenuItem(value: e, child: Text(equipmentLabelKey(e).tr())),
            ],
            onChanged: (e) => setState(() => _equipment = e),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: Text('workout.cancel'.tr())),
        FilledButton(
          key: const Key('custom_exercise_save'),
          onPressed: _saving ? null : _save,
          child: Text('workout.ok'.tr()),
        ),
      ],
    );
  }
}
```

- [ ] **Step 7: Router'a rotayı ekle**

`lib/core/router.dart` → import:

```dart
import '../features/workout/presentation/exercise_picker_screen.dart';
```

`/workout` rotasının `routes` listesine ekle:

```dart
                  GoRoute(path: 'exercises', builder: (context, state) => const ExercisePickerScreen()),
```

- [ ] **Step 8: Testlerin geçtiğini doğrula**

Run: `flutter test test/features/workout`
Expected: PASS (önceki testler + filter 3 + picker 5)

- [ ] **Step 9: Commit**

```bash
git add lib/features/workout lib/core/router.dart assets/translations test/features/workout
git commit -m "feat(workout): add exercise picker with filters, detail sheet and custom exercises"
```

---

## Task 12: 1RM paneli ve yüzdelik program aktivasyonu

**Files:**
- Create: `lib/features/workout/presentation/one_rep_max_sheet.dart`
- Modify: `lib/features/workout/presentation/program_detail_screen.dart` (`activateProgram` + 1RM butonu), `assets/translations/tr.json`, `assets/translations/en.json`
- Test: `test/features/workout/presentation/one_rep_max_sheet_test.dart`

**Interfaces:**
- Consumes: `Program.oneRepMaxExerciseIds`, `Program.usesPercentages` (Task 4); `oneRepMaxRepositoryProvider`, `oneRepMaxesProvider`, `exercisesProvider` (Task 6); `activateProgram` (Task 8).
- Produces: `Future<bool> showOneRepMaxSheet(BuildContext context, Program program)` — kaydedilirse `true`, atlanırsa `false`. Key'ler: `one_rep_max_sheet`, `one_rep_max_field_<exerciseId>`, `one_rep_max_save`, `one_rep_max_skip`, `program_one_rep_max_button`.

- [ ] **Step 1: Çevirileri ekle**

`tr.json` → `workout`:

```json
"one_rep_max_title": "1RM değerlerin",
"one_rep_max_body": "Bu program ağırlıkları 1 tekrar maksimumuna (1RM) göre hesaplar. Bilmiyorsan atlayabilirsin; ağırlık yerine yüzde gösterilir.",
"one_rep_max_kg": "{name} (kg)",
"one_rep_max_save": "Kaydet",
"one_rep_max_skip": "Atla",
"one_rep_max_button": "1RM değerlerim"
```

`en.json` → `workout`:

```json
"one_rep_max_title": "Your 1RMs",
"one_rep_max_body": "This program calculates weights from your one-rep max (1RM). If you don't know it, skip; percentages are shown instead of weights.",
"one_rep_max_kg": "{name} (kg)",
"one_rep_max_save": "Save",
"one_rep_max_skip": "Skip",
"one_rep_max_button": "My 1RMs"
```

- [ ] **Step 2: Başarısız testleri yaz**

`test/features/workout/presentation/one_rep_max_sheet_test.dart`:

```dart
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spor_takip/features/onboarding/application/auth_providers.dart';
import 'package:spor_takip/features/workout/application/workout_providers.dart';
import 'package:spor_takip/features/workout/domain/program.dart';
import 'package:spor_takip/features/workout/domain/program_workout.dart';
import 'package:spor_takip/features/workout/domain/schedule_mode.dart';
import 'package:spor_takip/features/workout/domain/workout_exercise.dart';
import 'package:spor_takip/features/workout/presentation/program_detail_screen.dart';

import '../fakes.dart';

const _sumo = WorkoutExercise(
  exerciseId: 'Sumo_Deadlift',
  exerciseName: 'Sumo Deadlift',
  sets: 1,
  repsMin: 5,
  repsMax: 5,
  percent1rm: 45,
  percentRefExerciseId: 'Barbell_Deadlift',
);
const _deadlift = WorkoutExercise(
  exerciseId: 'Barbell_Deadlift',
  exerciseName: 'Barbell Deadlift',
  sets: 1,
  repsMin: 5,
  repsMax: 5,
  percent1rm: 67.5,
);
const _percentProgram = Program(
  id: 'ns',
  name: 'nSuns',
  scheduleMode: ScheduleMode.weekdays,
  workouts: [ProgramWorkout(name: 'Gün', weekday: 5, exercises: [_deadlift, _sumo])],
);

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  late FakeProgramRepository programRepo;
  late FakeOneRepMaxRepository oneRepMaxRepo;

  setUp(() {
    programRepo = FakeProgramRepository(programs: [_percentProgram]);
    oneRepMaxRepo = FakeOneRepMaxRepository();
  });

  Widget wrap() {
    final router = GoRouter(routes: [
      GoRoute(path: '/', builder: (context, state) => const ProgramDetailScreen(programId: 'ns')),
    ]);
    return EasyLocalization(
      supportedLocales: const [Locale('tr'), Locale('en')],
      path: 'assets/translations',
      fallbackLocale: const Locale('tr'),
      child: ProviderScope(
        overrides: [
          isLoggedInProvider.overrideWithValue(true),
          programRepositoryProvider.overrideWithValue(programRepo),
          oneRepMaxRepositoryProvider.overrideWithValue(oneRepMaxRepo),
          exerciseRepositoryProvider.overrideWithValue(FakeExerciseRepository()),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
  }

  testWidgets('activating a percentage program asks for the referenced 1RMs, saves them and activates',
      (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('program_activate_button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('one_rep_max_sheet')), findsOneWidget);
    // Sumo, deadlift'in 1RM'sine dayandığı için tek alan var.
    expect(find.byKey(const Key('one_rep_max_field_Barbell_Deadlift')), findsOneWidget);
    expect(find.byKey(const Key('one_rep_max_field_Sumo_Deadlift')), findsNothing);

    await tester.enterText(find.byKey(const Key('one_rep_max_field_Barbell_Deadlift')), '200');
    await tester.tap(find.byKey(const Key('one_rep_max_save')));
    await tester.pumpAndSettle();

    expect(oneRepMaxRepo.values, {'Barbell_Deadlift': 200.0});
    expect(programRepo.active.programId, 'ns');
    expect(find.textContaining('135 kg'), findsOneWidget); // 200 × %67.5
    expect(find.textContaining('90 kg'), findsOneWidget); // 200 × %45
  });

  testWidgets('skipping the sheet still activates the program', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('program_activate_button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('one_rep_max_skip')));
    await tester.pumpAndSettle();

    expect(oneRepMaxRepo.values, isEmpty);
    expect(programRepo.active.programId, 'ns');
  });

  testWidgets('1RM button opens the sheet prefilled with saved values', (tester) async {
    oneRepMaxRepo.values['Barbell_Deadlift'] = 180;
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('program_one_rep_max_button')));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(TextField, '180'), findsOneWidget);
  });
}
```

Run: `flutter test test/features/workout/presentation/one_rep_max_sheet_test.dart`
Expected: FAIL — aktivasyonda panel açılmıyor / `program_one_rep_max_button` yok.

- [ ] **Step 3: Paneli yaz**

`lib/features/workout/presentation/one_rep_max_sheet.dart`:

```dart
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/workout_providers.dart';
import '../domain/program.dart';

Future<bool> showOneRepMaxSheet(BuildContext context, Program program) async {
  final saved = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _OneRepMaxSheet(program: program),
  );
  return saved ?? false;
}

class _OneRepMaxSheet extends ConsumerStatefulWidget {
  const _OneRepMaxSheet({required this.program});

  final Program program;

  @override
  ConsumerState<_OneRepMaxSheet> createState() => _OneRepMaxSheetState();
}

class _OneRepMaxSheetState extends ConsumerState<_OneRepMaxSheet> {
  late final List<String> _ids = widget.program.oneRepMaxExerciseIds.toList()..sort();
  late final Map<String, TextEditingController> _controllers = {
    for (final id in _ids) id: TextEditingController(),
  };
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      final existing = await ref.read(oneRepMaxRepositoryProvider).fetchOneRepMaxes();
      if (!mounted) return;
      for (final id in _ids) {
        final kg = existing[id];
        if (kg != null && _controllers[id]!.text.isEmpty) {
          _controllers[id]!.text = kg == kg.roundToDouble() ? '${kg.toInt()}' : '$kg';
        }
      }
    });
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  /// Blok adlarından, yoksa hareket kütüphanesinden, o da yoksa id'den okunur ad.
  String _nameOf(String id) {
    for (final w in widget.program.workouts) {
      for (final b in w.exercises) {
        if (b.exerciseId == id) return b.exerciseName;
      }
    }
    final library = ref.read(exercisesProvider).value ?? const [];
    return library.where((e) => e.id == id).firstOrNull?.name ?? id.replaceAll('_', ' ');
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final repo = ref.read(oneRepMaxRepositoryProvider);
    try {
      for (final id in _ids) {
        final kg = double.tryParse(_controllers[id]!.text.trim().replaceAll(',', '.'));
        if (kg != null && kg > 0) await repo.saveOneRepMax(exerciseId: id, weightKg: kg);
      }
      ref.invalidate(oneRepMaxesProvider);
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('workout.action_error'.tr())));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: const Key('one_rep_max_sheet'),
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('workout.one_rep_max_title'.tr(), style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text('workout.one_rep_max_body'.tr()),
            for (final id in _ids)
              TextField(
                key: Key('one_rep_max_field_$id'),
                controller: _controllers[id],
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'workout.one_rep_max_kg'.tr(namedArgs: {'name': _nameOf(id)}),
                ),
              ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  key: const Key('one_rep_max_skip'),
                  onPressed: _saving ? null : () => Navigator.of(context).pop(false),
                  child: Text('workout.one_rep_max_skip'.tr()),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  key: const Key('one_rep_max_save'),
                  onPressed: _saving ? null : _save,
                  child: Text('workout.one_rep_max_save'.tr()),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Detay ekranına bağla**

`lib/features/workout/presentation/program_detail_screen.dart`:

Import ekle:

```dart
import 'one_rep_max_sheet.dart';
```

`activateProgram`'ı şununla değiştir:

```dart
/// Programı aktif yapar; yüzdelik programlarda önce 1RM panelini gösterir
/// (panel atlanabilir, aktivasyon her durumda yapılır).
Future<void> activateProgram(BuildContext context, WidgetRef ref, Program program) async {
  if (program.usesPercentages) {
    await showOneRepMaxSheet(context, program);
  }
  await ref.read(programRepositoryProvider).setActiveProgram(program.id);
  ref.invalidate(activeProgramStateProvider);
}
```

Butonların bulunduğu `Wrap`'in `children` listesinin sonuna ekle:

```dart
                  if (program.usesPercentages)
                    OutlinedButton(
                      key: const Key('program_one_rep_max_button'),
                      onPressed: () => showOneRepMaxSheet(context, program),
                      child: Text('workout.one_rep_max_button'.tr()),
                    ),
```

- [ ] **Step 5: Testlerin geçtiğini doğrula**

Run: `flutter test test/features/workout`
Expected: PASS (önceki testler + 1RM 3). Task 8'in detay testleri değişmeden geçmeli (o testlerdeki programların `activate` edilen `_mine`'ı yüzdesiz).

- [ ] **Step 6: Commit**

```bash
git add lib/features/workout assets/translations test/features/workout/presentation/one_rep_max_sheet_test.dart
git commit -m "feat(workout): ask for 1RMs when activating percentage-based programs"
```

---

## Task 13: Ana ekranda "Bugün" kartı

**Files:**
- Create: `lib/features/workout/presentation/widgets/today_workout_card.dart`
- Modify: `lib/features/onboarding/presentation/home_screen.dart`, `assets/translations/tr.json`, `assets/translations/en.json`
- Test: `test/features/workout/presentation/today_workout_card_test.dart`

**Interfaces:**
- Consumes: `todayWorkoutProvider`, `activeProgramStateProvider`, `programRepositoryProvider` (Task 6); `TodayWorkout` alt sınıfları (Task 5).
- Produces: `class TodayWorkoutCard extends ConsumerWidget`; key'ler: `today_workout_card`, `today_no_program`, `today_choose_program`, `today_rest_day`, `today_empty_program`, `today_scheduled`, `today_done_button`.

- [ ] **Step 1: Çevirileri ekle**

`tr.json` → `workout`:

```json
"today_title": "Bugünün antrenmanı",
"today_no_program": "Aktif programın yok",
"today_choose": "Program seç",
"today_rest_day": "Bugün dinlenme günü",
"today_label": "Bugün",
"next_label": "Sıradaki",
"today_done": "Tamamladım",
"today_load_error": "Antrenman bilgisi yüklenemedi"
```

`en.json` → `workout`:

```json
"today_title": "Today's workout",
"today_no_program": "You have no active program",
"today_choose": "Choose a program",
"today_rest_day": "Rest day today",
"today_label": "Today",
"next_label": "Up next",
"today_done": "Done",
"today_load_error": "Could not load today's workout"
```

- [ ] **Step 2: Başarısız testleri yaz**

`test/features/workout/presentation/today_workout_card_test.dart`:

```dart
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spor_takip/features/onboarding/application/auth_providers.dart';
import 'package:spor_takip/features/workout/application/workout_providers.dart';
import 'package:spor_takip/features/workout/data/program_repository.dart';
import 'package:spor_takip/features/workout/domain/program.dart';
import 'package:spor_takip/features/workout/domain/program_workout.dart';
import 'package:spor_takip/features/workout/domain/schedule_mode.dart';
import 'package:spor_takip/features/workout/domain/today_workout.dart';
import 'package:spor_takip/features/workout/presentation/widgets/today_workout_card.dart';

import '../fakes.dart';

const _rotation = Program(
  id: 'rot',
  userId: 'user-1',
  name: 'Rotasyon',
  scheduleMode: ScheduleMode.rotation,
  workouts: [
    ProgramWorkout(name: 'Antrenman A', exercises: []),
    ProgramWorkout(name: 'Antrenman B', exercises: []),
  ],
);

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  Widget wrap(List overrides) {
    final router = GoRouter(routes: [
      GoRoute(path: '/', builder: (context, state) => const Scaffold(body: TodayWorkoutCard())),
      GoRoute(path: '/workout', builder: (context, state) => const Text('PROGRAMS')),
      GoRoute(
        path: '/workout/program/:id',
        builder: (context, state) => Text('DETAIL_${state.pathParameters['id']}'),
      ),
    ]);
    return EasyLocalization(
      supportedLocales: const [Locale('tr'), Locale('en')],
      path: 'assets/translations',
      fallbackLocale: const Locale('tr'),
      child: ProviderScope(
        overrides: [isLoggedInProvider.overrideWithValue(true), ...overrides.cast()],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
  }

  testWidgets('without an active program it links to the programs tab', (tester) async {
    await tester.pumpWidget(wrap([todayWorkoutProvider.overrideWith((ref) async => const NoActiveProgram())]));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('today_no_program')), findsOneWidget);
    await tester.tap(find.byKey(const Key('today_choose_program')));
    await tester.pumpAndSettle();
    expect(find.text('PROGRAMS'), findsOneWidget);
  });

  testWidgets('rest day', (tester) async {
    await tester.pumpWidget(wrap([
      todayWorkoutProvider.overrideWith((ref) async => const RestDay(_rotation)),
    ]));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('today_rest_day')), findsOneWidget);
  });

  testWidgets('rotation: shows the next workout, Done advances it, tap opens detail', (tester) async {
    final repo = FakeProgramRepository(
      programs: [_rotation],
      active: const ActiveProgramState(programId: 'rot'),
    );
    await tester.pumpWidget(wrap([programRepositoryProvider.overrideWithValue(repo)]));
    await tester.pumpAndSettle();

    expect(find.text('Antrenman A'), findsOneWidget);
    await tester.tap(find.byKey(const Key('today_done_button')));
    await tester.pumpAndSettle();

    expect(repo.active.nextRotationPosition, 1);
    expect(find.text('Antrenman B'), findsOneWidget);

    await tester.tap(find.byKey(const Key('today_scheduled')));
    await tester.pumpAndSettle();
    expect(find.text('DETAIL_rot'), findsOneWidget);
  });
}
```

Run: `flutter test test/features/workout/presentation/today_workout_card_test.dart`
Expected: FAIL — `today_workout_card.dart` yok.

- [ ] **Step 3: Kartı yaz**

`lib/features/workout/presentation/widgets/today_workout_card.dart`:

```dart
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../application/workout_providers.dart';
import '../../domain/schedule_mode.dart';
import '../../domain/today_workout.dart';

class TodayWorkoutCard extends ConsumerWidget {
  const TodayWorkoutCard({super.key});

  /// F4'te gerçek antrenman kaydıyla değiştirilecek.
  Future<void> _complete(WidgetRef ref) async {
    final state = await ref.read(activeProgramStateProvider.future);
    await ref.read(programRepositoryProvider).setRotationPosition(state.nextRotationPosition + 1);
    ref.invalidate(activeProgramStateProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final todayAsync = ref.watch(todayWorkoutProvider);
    return Card(
      key: const Key('today_workout_card'),
      child: todayAsync.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(16),
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (error, stackTrace) => ListTile(title: Text('workout.today_load_error'.tr())),
        data: (today) => switch (today) {
          NoActiveProgram() => ListTile(
              key: const Key('today_no_program'),
              leading: const Icon(Icons.fitness_center_outlined),
              title: Text('workout.today_no_program'.tr()),
              trailing: TextButton(
                key: const Key('today_choose_program'),
                onPressed: () => context.go('/workout'),
                child: Text('workout.today_choose'.tr()),
              ),
            ),
          EmptyProgram(:final program) => ListTile(
              key: const Key('today_empty_program'),
              title: Text(program.name),
              subtitle: Text('workout.no_workouts'.tr()),
            ),
          RestDay(:final program) => ListTile(
              key: const Key('today_rest_day'),
              leading: const Icon(Icons.self_improvement),
              title: Text('workout.today_rest_day'.tr()),
              subtitle: Text(program.name),
            ),
          ScheduledWorkout(:final program, :final workout) => ListTile(
              key: const Key('today_scheduled'),
              leading: const Icon(Icons.fitness_center),
              title: Text(workout.name),
              subtitle: Text(
                '${program.scheduleMode == ScheduleMode.weekdays ? 'workout.today_label'.tr() : 'workout.next_label'.tr()}'
                ' · ${program.name}',
              ),
              onTap: () => context.push('/workout/program/${program.id}'),
              trailing: program.scheduleMode == ScheduleMode.rotation
                  ? TextButton(
                      key: const Key('today_done_button'),
                      onPressed: () => _complete(ref),
                      child: Text('workout.today_done'.tr()),
                    )
                  : null,
            ),
        },
      ),
    );
  }
}
```

- [ ] **Step 4: Ana ekrana ekle**

`lib/features/onboarding/presentation/home_screen.dart` → import:

```dart
import '../../workout/presentation/widgets/today_workout_card.dart';
```

`data:` dalındaki `Column`'un `children` listesinin sonuna (`protein_target` metninden sonra) ekle:

```dart
                const SizedBox(height: 24),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: TodayWorkoutCard(),
                ),
```

- [ ] **Step 5: Testlerin geçtiğini doğrula**

Run: `flutter test`
Expected: PASS (tüm proje). `test/widget_test.dart` giriş yapmamış kullanıcıyla `HomeScreen`'e ulaşmadığı için etkilenmez.

- [ ] **Step 6: Commit**

```bash
git add lib/features/workout/presentation/widgets/today_workout_card.dart lib/features/onboarding/presentation/home_screen.dart assets/translations test/features/workout/presentation/today_workout_card_test.dart
git commit -m "feat(workout): show today's workout card on the home screen"
```

---

## Task 14: Uygulama, SQL doğrulaması ve uçtan uca manuel test

**Files:**
- Create: `supabase/migrations/checks/f3_rls_checks.sql`
- Modify: `PLAN.md` (Değişiklik Günlüğü)

Bu görev kullanıcıyla birlikte yapılır (veritabanı şifresi yok → Dashboard SQL Editor; düşük bellekli makine → release web build'i kullanıcının terminalinden sunulur).

- [ ] **Step 1: Tüm otomatik kontroller**

Run: `flutter analyze` → Expected: `No issues found!`
Run: `flutter test` → Expected: tüm testler PASS.
Run: `deno test --allow-read tool/ supabase/functions/analyze-meal-photo/` → Expected: PASS.

- [ ] **Step 2: Kontrol SQL betiğini yaz**

`supabase/migrations/checks/f3_rls_checks.sql` (migration değildir; SQL Editor'da elle çalıştırılır. `checks/` alt klasörü Supabase CLI tarafından migration olarak okunmaz):

```sql
-- F3 RLS / fonksiyon kontrolleri. SQL Editor'da çalıştır.
-- <USER_A> ve <USER_B> yerine auth.users'tan iki gerçek kullanıcı id'si yaz.
-- Her blok bir transaction içinde, sonunda rollback — veri değişmez.

-- 1) Seed sayıları
select
  (select count(*) from public.exercises where user_id is null) as builtin_exercises,          -- 876
  (select count(*) from public.programs where user_id is null) as builtin_programs,            -- 9
  (select count(*) from public.program_workouts w join public.programs p on p.id = w.program_id
     where p.user_id is null) as builtin_workouts;                                             -- 2+3+4+6+5+6+16+9+4 = 55

-- 2) A kullanıcısı: hazır programı kopyalar, kopya tam olmalı; hazır programı değiştiremez
begin;
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"<USER_A>","role":"authenticated"}', true);
select public.copy_program('f3000000-0000-4000-8000-000000000009') as copy_id;
select count(*) as copied_blocks from public.workout_exercises e
  join public.program_workouts w on w.id = e.workout_id
  join public.programs p on p.id = w.program_id
  where p.user_id = '<USER_A>';                                                               -- 68 (nSuns: 4 × 17)
update public.programs set name = 'hack' where id = 'f3000000-0000-4000-8000-000000000001';
select name from public.programs where id = 'f3000000-0000-4000-8000-000000000001';            -- hâlâ 'StrongLifts 5x5'
rollback;

-- 3) B kullanıcısı A'nın programını göremez ve save_program ile üzerine yazamaz
--    (önce A olarak bir kopya oluşturup commit et, id'sini not al, sonra aşağıyı çalıştır)
begin;
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"<USER_B>","role":"authenticated"}', true);
select count(*) from public.programs where user_id = '<USER_A>';                               -- 0
select public.save_program('{"id":"<A_PROGRAM_ID>","name":"x","schedule_mode":"rotation","workouts":[]}'::jsonb);
-- Beklenen: hata (row-level security veya 'program not owned by user')
rollback;
```

- [ ] **Step 3: Migration'ları uygula (kullanıcı)**

Kullanıcıya sırayla Dashboard → SQL Editor'da çalıştırmasını söyle: `0004_create_exercises.sql`, `0005_seed_exercises.sql`, `0006_create_programs.sql`, `0007_seed_programs.sql`. `0005` Editor'a sığmazsa: `deno run --allow-net --allow-write tool/generate_exercise_seed.ts --chunks 4` ve `tool/.out/0005_part1..4.sql`'i sırayla çalıştır. Ardından `f3_rls_checks.sql` bloklarını çalıştırıp yorumlardaki beklenen değerlerle karşılaştır.

- [ ] **Step 4: Release web build ve manuel kontrol listesi (kullanıcı)**

Run (arka planda, ~15–25 dk): `flutter build web --release`
Kullanıcı kendi PowerShell'inde: `cd D:\spor_takip\build\web; python -m http.server 5555 --bind 127.0.0.1` → `http://127.0.0.1:5555` (Ctrl+Shift+R).

Kontrol listesi:
1. Alt menüde üç sekme var; Antrenman sekmesinde 9 hazır program listeleniyor; seviye ve gün filtreleri çalışıyor.
2. StrongLifts 5x5 detayı: iki antrenman, 5 × 5 bloklar; "Aktif yap" → yıldız rozeti; Ana sayfada "Sıradaki: Antrenman A", "Tamamladım" → "Antrenman B".
3. nSuns detayında 9+8 set gruplu görünüyor, yüzdeler "%" ile; "Aktif yap" → 1RM paneli yalnızca Bench/Squat/Deadlift/OHP (Sumo/Front Squat/CG Bench yok); 1RM girince kilolar görünüyor.
4. Full Body 3 gün "Özelleştir" → düzenleyici açılıyor; bir hareket ekle (seçicide arama, kas filtresi, detay panelinde iki görsel + talimat), set/tekrar düzenle, bir bloğu yukarı taşı, kaydet → kendi programının detayına dönüyor; "Programlarım"da görünüyor.
5. "Boş program oluştur" → gün seçmeden kaydet → uyarı; aynı günü iki antrenmana vermeye çalış → uyarı.
6. Kendi hareketini ekle → programda kullan → seçicide uzun basıp silmeye çalış → "programında kullanılıyor" mesajı.
7. Düzenleyicide değişiklik yapıp geri çık → onay diyaloğu.
8. Kendi programını sil (aktifse) → Ana sayfada "Aktif programın yok".

- [ ] **Step 5: PLAN.md ve commit**

`PLAN.md` Değişiklik Günlüğü tablosuna, doğrulama sonuçlarını gerçek bulgularla yansıtan bir satır ekle (tarih, tamamlanan kapsam, bulunan/düzeltilen hatalar, test sayıları).

```bash
git add supabase/migrations/checks/f3_rls_checks.sql PLAN.md
git commit -m "Document F3 verification and add RLS check script"
```
