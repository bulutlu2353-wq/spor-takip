-- F5: AI antrenör sohbeti. Öneri → onay → uygula → geri al akışı; görüntüler
-- (base/before/after) jsonb eşitliğiyle "arada değişti mi" kontrolü yapar.

create table if not exists public.chat_events (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  tool text not null check (tool in ('log_body_weight', 'update_profile', 'set_goal',
                                     'create_meal', 'log_set', 'edit_program')),
  status text not null default 'pending'
    check (status in ('pending', 'applied', 'cancelled', 'undone', 'stale')),
  summary text not null,
  payload jsonb not null,
  base jsonb not null,               -- öneri anındaki görüntü
  before jsonb,                      -- uygulamadan hemen önce
  after jsonb,                       -- uygulamadan sonra
  created_at timestamptz not null default now(),
  applied_at timestamptz,
  resolved_at timestamptz            -- vazgeçme / geri alma / bayatlama
);

create table if not exists public.chat_messages (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  role text not null check (role in ('user', 'assistant')),
  content text not null,
  event_id uuid references public.chat_events (id) on delete set null,
  created_at timestamptz not null default now()
);

create index if not exists chat_messages_user_created
  on public.chat_messages (user_id, created_at desc);

-- Günlük sınır sayacı: her başarılı cevapta bir satır. Silme politikası yok,
-- böylece "Sohbeti temizle" sınırı sıfırlamaz.
create table if not exists public.chat_usage (
  id bigserial primary key,
  user_id uuid not null references auth.users (id) on delete cascade,
  created_at timestamptz not null default now()
);

create index if not exists chat_usage_user_created on public.chat_usage (user_id, created_at);

alter table public.chat_events enable row level security;
alter table public.chat_messages enable row level security;
alter table public.chat_usage enable row level security;

create policy "Users can manage own chat events"
  on public.chat_events for all
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

create policy "Users can manage own chat messages"
  on public.chat_messages for all
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

create policy "Users can view own chat usage"
  on public.chat_usage for select
  using (user_id = auth.uid());

create policy "Users can insert own chat usage"
  on public.chat_usage for insert
  with check (user_id = auth.uid());

-- Programın save_program girdisi formatındaki tam hali (yalnız kullanıcının kendi programı).
create or replace function public.program_snapshot(p_program_id uuid)
returns jsonb
language sql
stable
security invoker
set search_path = public
as $$
  select jsonb_build_object(
    'id', p.id,
    'name', p.name,
    'description', p.description,
    'level', p.level,
    'schedule_mode', p.schedule_mode,
    'days_per_week', p.days_per_week,
    'source_program_id', p.source_program_id,
    'workouts', coalesce((
      select jsonb_agg(jsonb_build_object(
        'name', w.name,
        'weekday', w.weekday,
        'exercises', coalesce((
          select jsonb_agg(jsonb_build_object(
            'exercise_id', e.exercise_id,
            'sets', e.sets,
            'reps_min', e.reps_min,
            'reps_max', e.reps_max,
            'is_amrap', e.is_amrap,
            'percent_1rm', e.percent_1rm,
            'percent_ref_exercise_id', e.percent_ref_exercise_id,
            'rest_seconds', e.rest_seconds,
            'notes', e.notes
          ) order by e.position)
          from workout_exercises e where e.workout_id = w.id
        ), '[]'::jsonb)
      ) order by w.position)
      from program_workouts w where w.program_id = p.id
    ), '[]'::jsonb)
  )
  from programs p
  where p.id = p_program_id and p.user_id = auth.uid();
$$;

-- Bir aracın dokunduğu verinin şu anki hali (spec §3.1). base/before/after hep
-- bununla alınır ve jsonb eşitliğiyle karşılaştırılır.
create or replace function public.chat_target_snapshot(p_tool text, p_payload jsonb)
returns jsonb
language plpgsql
stable
security invoker
set search_path = public
as $$
declare
  uid uuid := auth.uid();
  keys text[];
  result jsonb;
begin
  if uid is null then
    raise exception 'not authenticated';
  end if;

  case p_tool
  when 'log_body_weight' then
    select jsonb_build_object(
      'log', (select l.weight_kg from body_weight_logs l
               where l.user_id = uid and l.logged_on = (p_payload->>'date')::date),
      'profile', (select jsonb_build_object(
                    'weight_kg', p.weight_kg,
                    'daily_calorie_target', p.daily_calorie_target,
                    'daily_protein_target_g', p.daily_protein_target_g)
                  from profiles p where p.user_id = uid))
      into result;
  when 'update_profile', 'set_goal' then
    if p_tool = 'set_goal' then
      keys := array['goal'];
    else
      select array_agg(k order by k) into keys from jsonb_object_keys(p_payload->'changes') k;
    end if;
    keys := coalesce(keys, array[]::text[]) || array['daily_calorie_target', 'daily_protein_target_g'];
    select jsonb_object_agg(k, to_jsonb(p) -> k)
      into result
      from profiles p, unnest(keys) k
      where p.user_id = uid;
  when 'create_meal' then
    select jsonb_build_object('meal', (
      select jsonb_build_object(
        'meal_type', m.meal_type,
        'logged_at', m.logged_at,
        'items', coalesce((
          select jsonb_agg(jsonb_build_object(
            'name', i.name, 'grams', i.grams, 'calories', i.calories,
            'protein_g', i.protein_g, 'carbs_g', i.carbs_g, 'fat_g', i.fat_g
          ) order by i.id)
          from meal_items i where i.meal_id = m.id
        ), '[]'::jsonb))
      from meals m
      where m.id = (p_payload->>'meal_id')::uuid and m.user_id = uid))
      into result;
  when 'log_set' then
    select jsonb_build_object('set', (
      select jsonb_build_object(
        'weight_kg', s.weight_kg,
        'reps', s.reps,
        'completed_at', s.completed_at,
        'finished_at', w.finished_at)
      from session_sets s
      join workout_sessions w on w.id = s.session_id
      where s.session_id = (p_payload->>'session_id')::uuid
        and s.exercise_position = (p_payload->>'exercise_position')::int
        and s.set_index = (p_payload->>'set_index')::int
        and w.user_id = uid))
      into result;
  when 'edit_program' then
    result := jsonb_build_object('program', program_snapshot((p_payload->>'program_id')::uuid));
  else
    raise exception 'unknown_tool %', p_tool;
  end case;

  return result;
end;
$$;

-- Uygulamanın ve Edge Function'ın kullandığı tek mesaj biçimi.
create or replace function public.chat_message_json(m public.chat_messages)
returns jsonb
language sql
stable
security invoker
set search_path = public
as $$
  select jsonb_build_object(
    'id', m.id,
    'role', m.role,
    'content', m.content,
    'created_at', m.created_at,
    'event', (select jsonb_build_object(
                'id', e.id, 'tool', e.tool, 'status', e.status,
                'summary', e.summary, 'payload', e.payload, 'base', e.base)
              from chat_events e where e.id = m.event_id));
$$;

-- Son p_limit mesaj, eskiden yeniye.
create or replace function public.recent_chat_messages(p_limit int)
returns jsonb
language sql
stable
security invoker
set search_path = public
as $$
  select coalesce(jsonb_agg(t.j order by t.created_at), '[]'::jsonb)
  from (
    select chat_message_json(m) as j, m.created_at
    from chat_messages m
    where m.user_id = auth.uid()
    order by m.created_at desc
    limit p_limit
  ) t;
$$;

-- Bir soru-cevap çiftini (ve varsa bekleyen öneriyi) tek transaction'da yazar,
-- günlük sayaca bir satır ekler. İki mesajı eskiden yeniye döndürür.
create or replace function public.save_chat_exchange(
  p_user_text text,
  p_assistant_text text,
  p_event jsonb
) returns jsonb
language plpgsql
security invoker
set search_path = public
as $$
declare
  uid uuid := auth.uid();
  v_event_id uuid;
  v_user_msg uuid;
  v_assistant_msg uuid;
begin
  if uid is null then
    raise exception 'not authenticated';
  end if;

  if p_event is not null then
    insert into chat_events (user_id, tool, summary, payload, base)
      values (uid, p_event->>'tool', p_event->>'summary', p_event->'payload', p_event->'base')
      returning id into v_event_id;
  end if;

  -- clock_timestamp: aynı transaction'daki iki mesaj farklı zaman alsın (sıralama).
  insert into chat_messages (user_id, role, content, created_at)
    values (uid, 'user', p_user_text, clock_timestamp())
    returning id into v_user_msg;
  insert into chat_messages (user_id, role, content, event_id, created_at)
    values (uid, 'assistant', p_assistant_text, v_event_id, clock_timestamp())
    returning id into v_assistant_msg;
  insert into chat_usage (user_id) values (uid);

  return (
    select jsonb_agg(chat_message_json(m) order by m.created_at)
    from chat_messages m
    where m.id in (v_user_msg, v_assistant_msg)
  );
end;
$$;

-- Sohbeti temizler; chat_events ve chat_usage kalır.
create or replace function public.clear_chat()
returns void
language sql
security invoker
set search_path = public
as $$
  delete from chat_messages where user_id = auth.uid();
$$;

-- p_fields'ta bulunan profil kolonlarını yazar (uygulama ve geri alma ortak).
create or replace function public.chat_write_profile(p_fields jsonb)
returns void
language plpgsql
security invoker
set search_path = public
as $$
begin
  update profiles set
    height_cm = case when p_fields ? 'height_cm' then (p_fields->>'height_cm')::numeric else height_cm end,
    activity_level = case when p_fields ? 'activity_level' then p_fields->>'activity_level' else activity_level end,
    does_exercise = case when p_fields ? 'does_exercise' then (p_fields->>'does_exercise')::boolean else does_exercise end,
    sport_type = case when p_fields ? 'sport_type' then p_fields->>'sport_type' else sport_type end,
    exercise_days_per_week = case when p_fields ? 'exercise_days_per_week'
                                  then (p_fields->>'exercise_days_per_week')::int else exercise_days_per_week end,
    health_notes = case when p_fields ? 'health_notes' then p_fields->>'health_notes' else health_notes end,
    goal = case when p_fields ? 'goal' then p_fields->>'goal' else goal end,
    weight_kg = case when p_fields ? 'weight_kg' then (p_fields->>'weight_kg')::numeric else weight_kg end,
    daily_calorie_target = case when p_fields ? 'daily_calorie_target'
                                then (p_fields->>'daily_calorie_target')::numeric else daily_calorie_target end,
    daily_protein_target_g = case when p_fields ? 'daily_protein_target_g'
                                  then (p_fields->>'daily_protein_target_g')::numeric else daily_protein_target_g end,
    updated_at = now()
  where user_id = auth.uid();
end;
$$;

-- Bekleyen öneriyi uygular. Veri öneriden beri değiştiyse 'stale' (hiçbir şey değişmez).
create or replace function public.apply_chat_action(p_event_id uuid, p_extras jsonb)
returns text
language plpgsql
security invoker
set search_path = public
as $$
declare
  uid uuid := auth.uid();
  ev chat_events%rowtype;
  cur jsonb;
  p jsonb;
  targets jsonb;
  item jsonb;
  grams numeric;
  idx int := 0;
begin
  if uid is null then
    raise exception 'not authenticated';
  end if;

  select * into ev from chat_events where id = p_event_id and user_id = uid for update;
  if not found then
    raise exception 'event_not_found';
  end if;
  if ev.status <> 'pending' then
    raise exception 'event_not_pending';
  end if;

  cur := chat_target_snapshot(ev.tool, ev.payload);
  if cur is distinct from ev.base then
    update chat_events set status = 'stale', resolved_at = now() where id = ev.id;
    return 'stale';
  end if;

  p := ev.payload;

  if ev.tool in ('log_body_weight', 'update_profile', 'set_goal') then
    if coalesce((p_extras->>'calorie_target')::numeric, 0) <= 0
       or coalesce((p_extras->>'protein_target')::numeric, 0) <= 0 then
      raise exception 'invalid_targets';
    end if;
    targets := jsonb_build_object(
      'daily_calorie_target', (p_extras->>'calorie_target')::numeric,
      'daily_protein_target_g', (p_extras->>'protein_target')::numeric);
  end if;

  case ev.tool
  when 'log_body_weight' then
    if (p->>'kg')::numeric not between 20 and 400 or (p->>'date') is null then
      raise exception 'invalid_payload';
    end if;
    perform log_body_weight((p->>'date')::date, (p->>'kg')::numeric,
                            (targets->>'daily_calorie_target')::numeric,
                            (targets->>'daily_protein_target_g')::numeric);
  when 'update_profile' then
    if jsonb_typeof(p->'changes') is distinct from 'object'
       or exists (select 1 from jsonb_object_keys(p->'changes') k
                  where k not in ('height_cm', 'activity_level', 'does_exercise', 'sport_type',
                                  'exercise_days_per_week', 'health_notes')) then
      raise exception 'invalid_payload';
    end if;
    perform chat_write_profile((p->'changes') || targets);
  when 'set_goal' then
    perform chat_write_profile(jsonb_build_object('goal', p->>'goal') || targets);
  when 'create_meal' then
    if p_extras ? 'item_grams'
       and jsonb_array_length(p_extras->'item_grams') <> jsonb_array_length(p->'items') then
      raise exception 'invalid_extras';
    end if;
    insert into meals (id, user_id, meal_type, logged_at)
      values ((p->>'meal_id')::uuid, uid, p->>'meal_type', (p->>'logged_at')::timestamptz);
    for item in select value from jsonb_array_elements(p->'items') loop
      grams := coalesce((p_extras->'item_grams'->>idx)::numeric, (item->>'grams')::numeric);
      if grams is null or grams <= 0 then
        raise exception 'invalid_extras';
      end if;
      insert into meal_items (meal_id, name, grams, calories, protein_g, carbs_g, fat_g,
                              usda_fdc_id, needs_review)
      values (
        (p->>'meal_id')::uuid, item->>'name', grams,
        round(grams * (item->'per100'->>'calories')::numeric / 100, 1),
        round(grams * (item->'per100'->>'protein_g')::numeric / 100, 1),
        round(grams * (item->'per100'->>'carbs_g')::numeric / 100, 1),
        round(grams * (item->'per100'->>'fat_g')::numeric / 100, 1),
        item->>'usda_fdc_id',
        coalesce((item->>'needs_review')::boolean, false));
      idx := idx + 1;
    end loop;
  when 'log_set' then
    if jsonb_typeof(cur->'set') is distinct from 'object' or (cur->'set'->>'finished_at') is not null then
      raise exception 'set_not_available';
    end if;
    update session_sets
      set weight_kg = (p->>'weight_kg')::numeric,
          reps = (p->>'reps')::int,
          completed_at = coalesce(completed_at, now())
      where session_id = (p->>'session_id')::uuid
        and exercise_position = (p->>'exercise_position')::int
        and set_index = (p->>'set_index')::int;
  when 'edit_program' then
    if jsonb_typeof(cur->'program') is distinct from 'object' then
      raise exception 'program_not_found';
    end if;
    perform save_program((p->'program') || jsonb_build_object('id', p->>'program_id'));
  end case;

  update chat_events
    set status = 'applied',
        before = cur,
        after = chat_target_snapshot(ev.tool, ev.payload),
        applied_at = now()
    where id = ev.id;
  return 'applied';
end;
$$;

create or replace function public.cancel_chat_action(p_event_id uuid)
returns void
language plpgsql
security invoker
set search_path = public
as $$
begin
  update chat_events set status = 'cancelled', resolved_at = now()
    where id = p_event_id and user_id = auth.uid() and status = 'pending';
  if not found then
    raise exception 'event_not_pending';
  end if;
end;
$$;

-- Uygulanmış öneriyi geri alır. Veri uygulamadan sonra değiştiyse 'modified'
-- (hiçbir şey değişmez).
create or replace function public.undo_chat_action(p_event_id uuid)
returns text
language plpgsql
security invoker
set search_path = public
as $$
declare
  uid uuid := auth.uid();
  ev chat_events%rowtype;
  b jsonb;
  p jsonb;
begin
  if uid is null then
    raise exception 'not authenticated';
  end if;

  select * into ev from chat_events where id = p_event_id and user_id = uid for update;
  if not found then
    raise exception 'event_not_found';
  end if;
  if ev.status <> 'applied' then
    raise exception 'event_not_applied';
  end if;
  if chat_target_snapshot(ev.tool, ev.payload) is distinct from ev.after then
    return 'modified';
  end if;

  b := ev.before;
  p := ev.payload;

  case ev.tool
  when 'log_body_weight' then
    if jsonb_typeof(b->'log') = 'number' then
      update body_weight_logs set weight_kg = (b->>'log')::numeric
        where user_id = uid and logged_on = (p->>'date')::date;
    else
      delete from body_weight_logs where user_id = uid and logged_on = (p->>'date')::date;
    end if;
    perform chat_write_profile(b->'profile');
  when 'update_profile', 'set_goal' then
    perform chat_write_profile(b);
  when 'create_meal' then
    delete from meals where id = (p->>'meal_id')::uuid and user_id = uid;
  when 'log_set' then
    update session_sets
      set weight_kg = (b->'set'->>'weight_kg')::numeric,
          reps = (b->'set'->>'reps')::int,
          completed_at = (b->'set'->>'completed_at')::timestamptz
      where session_id = (p->>'session_id')::uuid
        and exercise_position = (p->>'exercise_position')::int
        and set_index = (p->>'set_index')::int;
  when 'edit_program' then
    perform save_program(b->'program');
  end case;

  update chat_events set status = 'undone', resolved_at = now() where id = ev.id;
  return 'undone';
end;
$$;
