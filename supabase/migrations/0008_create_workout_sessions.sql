-- F4a: antrenman oturumları ve set kayıtları.

create table if not exists public.workout_sessions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  program_id uuid references public.programs (id) on delete set null,
  program_name text not null,        -- başlatma anındaki adın kopyası
  workout_name text not null,
  workout_position int not null,     -- rotasyon ilerlemesi için
  started_at timestamptz not null default now(),
  finished_at timestamptz            -- null = devam ediyor
);

-- Kullanıcı başına en fazla bir devam eden oturum
create unique index if not exists workout_sessions_one_in_progress
  on public.workout_sessions (user_id) where finished_at is null;

create index if not exists workout_sessions_user_finished
  on public.workout_sessions (user_id, finished_at desc);

create table if not exists public.session_sets (
  id uuid primary key default gen_random_uuid(),
  session_id uuid not null references public.workout_sessions (id) on delete cascade,
  exercise_position int not null,
  set_index int not null,
  exercise_id text not null references public.exercises (id) on delete restrict,
  target_reps_min int not null check (target_reps_min > 0),
  target_reps_max int not null check (target_reps_max >= target_reps_min),
  is_amrap boolean not null default false,
  percent_1rm numeric check (percent_1rm > 0 and percent_1rm <= 100),
  percent_ref_exercise_id text references public.exercises (id) on delete restrict,
  rest_seconds int check (rest_seconds >= 0),
  suggested_weight_kg numeric check (suggested_weight_kg >= 0),
  deloaded boolean not null default false,  -- öneri 3 başarısızlık sonrası düşürüldü
  weight_kg numeric check (weight_kg >= 0),
  reps int check (reps >= 0),
  completed_at timestamptz,                 -- null = henüz yapılmadı
  unique (session_id, exercise_position, set_index)
);

create index if not exists session_sets_exercise on public.session_sets (exercise_id);

alter table public.workout_sessions enable row level security;
alter table public.session_sets enable row level security;

create policy "Users can manage own sessions"
  on public.workout_sessions for all
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

create policy "Users can manage sets of own sessions"
  on public.session_sets for all
  using (exists (
    select 1 from public.workout_sessions s where s.id = session_id and s.user_id = auth.uid()
  ))
  with check (exists (
    select 1 from public.workout_sessions s where s.id = session_id and s.user_id = auth.uid()
  ));

-- Oturumu ve planın kopyası olan setleri tek transaction'da yazar.
-- Devam eden oturum varken kısmi unique index nedeniyle unique_violation verir.
create or replace function public.start_session(payload jsonb)
returns uuid
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_id uuid;
  s jsonb;
begin
  if auth.uid() is null then
    raise exception 'not authenticated';
  end if;

  insert into workout_sessions (user_id, program_id, program_name, workout_name, workout_position)
  values (
    auth.uid(), (payload->>'program_id')::uuid, payload->>'program_name',
    payload->>'workout_name', (payload->>'workout_position')::int
  )
  returning id into v_id;

  for s in select value from jsonb_array_elements(coalesce(payload->'sets', '[]'::jsonb)) loop
    insert into session_sets (session_id, exercise_position, set_index, exercise_id,
                              target_reps_min, target_reps_max, is_amrap, percent_1rm,
                              percent_ref_exercise_id, rest_seconds, suggested_weight_kg, deloaded)
    values (
      v_id, (s->>'exercise_position')::int, (s->>'set_index')::int, s->>'exercise_id',
      (s->>'target_reps_min')::int, (s->>'target_reps_max')::int,
      coalesce((s->>'is_amrap')::boolean, false), (s->>'percent_1rm')::numeric,
      s->>'percent_ref_exercise_id', (s->>'rest_seconds')::int,
      (s->>'suggested_weight_kg')::numeric, coalesce((s->>'deloaded')::boolean, false)
    );
  end loop;

  return v_id;
end;
$$;

-- Oturumu kapatır; programı aktif ve rotasyon modundaysa sırayı ilerletir;
-- onaylanan 1RM'leri upsert eder. Hepsi ya uygulanır ya hiçbiri.
create or replace function public.finish_session(p_session_id uuid, p_one_rep_maxes jsonb)
returns void
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_session workout_sessions;
  r jsonb;
begin
  if auth.uid() is null then
    raise exception 'not authenticated';
  end if;

  select * into v_session from workout_sessions
  where id = p_session_id and user_id = auth.uid() and finished_at is null
  for update;
  if not found then
    raise exception 'session not found or already finished';
  end if;

  update workout_sessions set finished_at = now() where id = p_session_id;

  update profiles p
  set next_rotation_position = v_session.workout_position + 1
  from programs pr
  where p.user_id = auth.uid()
    and p.active_program_id = v_session.program_id
    and pr.id = v_session.program_id
    and pr.schedule_mode = 'rotation';

  for r in select value from jsonb_array_elements(coalesce(p_one_rep_maxes, '[]'::jsonb)) loop
    insert into user_one_rep_maxes (user_id, exercise_id, weight_kg, updated_at)
    values (auth.uid(), r->>'exercise_id', (r->>'weight_kg')::numeric, now())
    on conflict (user_id, exercise_id)
    do update set weight_kg = excluded.weight_kg, updated_at = excluded.updated_at;
  end loop;
end;
$$;
