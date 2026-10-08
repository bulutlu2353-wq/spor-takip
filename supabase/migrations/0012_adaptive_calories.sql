-- G3 (docs/superpowers/specs/2026-10-08-g3-uyarlanabilir-kalori-design.md §3.1):
-- uyarlanabilir kalori hedefi için profil sütunları; koç akışı bunları yazar ve
-- geri alma için anlık görüntüye katar.

alter table public.profiles
  add column calorie_adjustment_kcal numeric not null default 0,
  add column calorie_adjusted_at timestamptz,
  add column calorie_suggestion_snoozed_until timestamptz,
  add column goals_changed_at timestamptz;

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
    weight_direction = case when p_fields ? 'weight_direction'
                            then p_fields->>'weight_direction' else weight_direction end,
    pace = case when p_fields ? 'pace' then p_fields->>'pace' else pace end,
    focuses = case when p_fields ? 'focuses'
                   then array(select jsonb_array_elements_text(p_fields->'focuses')) else focuses end,
    weight_kg = case when p_fields ? 'weight_kg' then (p_fields->>'weight_kg')::numeric else weight_kg end,
    daily_calorie_target = case when p_fields ? 'daily_calorie_target'
                                then (p_fields->>'daily_calorie_target')::numeric else daily_calorie_target end,
    daily_protein_target_g = case when p_fields ? 'daily_protein_target_g'
                                  then (p_fields->>'daily_protein_target_g')::numeric else daily_protein_target_g end,
    calorie_adjustment_kcal = case when p_fields ? 'calorie_adjustment_kcal'
                                   then (p_fields->>'calorie_adjustment_kcal')::numeric else calorie_adjustment_kcal end,
    goals_changed_at = case when p_fields ? 'goals_changed_at'
                            then (p_fields->>'goals_changed_at')::timestamptz else goals_changed_at end,
    updated_at = now()
  where user_id = auth.uid();
end;
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
      keys := array['weight_direction', 'pace', 'focuses'];
    else
      select array_agg(k order by k) into keys from jsonb_object_keys(p_payload->'changes') k;
    end if;
    keys := coalesce(keys, array[]::text[])
      || array['daily_calorie_target', 'daily_protein_target_g', 'calorie_adjustment_kcal', 'goals_changed_at'];
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
    -- G3: boy/aktivite hedefi değiştirir → pencere yeniden başlar; aktivite payı geçersiz kılar.
    perform chat_write_profile((p->'changes') || targets
      || case when p->'changes' ?| array['height_cm', 'activity_level']
              then jsonb_build_object('goals_changed_at', now()) else '{}'::jsonb end
      || case when p->'changes' ? 'activity_level'
              then jsonb_build_object('calorie_adjustment_kcal', 0) else '{}'::jsonb end);
  when 'set_goal' then
    if jsonb_typeof(p->'focuses') is distinct from 'array' or not (p ? 'weight_direction') then
      raise exception 'invalid_payload';
    end if;
    perform chat_write_profile(jsonb_build_object(
      'weight_direction', p->'weight_direction',
      'pace', coalesce(p->'pace', 'null'::jsonb),
      'focuses', p->'focuses',
      'goals_changed_at', now()) || targets);
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
