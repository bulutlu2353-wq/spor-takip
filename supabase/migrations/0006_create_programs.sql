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
