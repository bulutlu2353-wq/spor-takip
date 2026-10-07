-- F5 RLS / fonksiyon kontrolleri. SQL Editor'da çalıştır (migration değildir).
-- A = profili olan bir kullanıcı, B = başka bir kullanıcı. Sonuç bilerek HATA
-- olarak basılır; hata tüm değişiklikleri geri aldığı için veritabanında
-- hiçbir şey değişmez.
-- Beklenen: kilo=t profil=t amac=t eski_amac=t ogun=t set=t program=t bayat=stale
--           engel=modified tekrar_engellendi=t iptal=t kayit=t B_gorulen=0
--           B_engellendi=t usage_silinemedi=t temizle=t
do $$
declare
  a uuid;
  b uuid;
  ex1 text;
  ex2 text;
  e uuid;
  e_applied uuid;
  pl jsonb;
  r text;
  snap jsonb;
  pid uuid;
  sid uuid;
  mid uuid := gen_random_uuid();
  n int;
  ok_weight boolean;
  ok_profile boolean;
  ok_goal boolean;
  ok_meal boolean;
  ok_set boolean;
  ok_program boolean;
  stale_result text;
  modified_result text;
  reapply_blocked boolean := false;
  cancel_ok boolean := false;
  exchange_ok boolean;
  b_seen int;
  b_blocked boolean := false;
  usage_kept boolean;
  clear_ok boolean;
  w numeric;
  c numeric;
  h numeric;
  g text;
  g_pace text;
  g_focuses text[];
  ok_legacy boolean;
begin
  select p.user_id into a from public.profiles p limit 1;
  select u.id into b from auth.users u where u.id <> a limit 1;
  if a is null or b is null then
    raise exception 'Kontrol için iki kullanıcı gerekli (a=%, b=%)', a, b;
  end if;
  select id into ex1 from public.exercises where user_id is null order by id limit 1;
  select id into ex2 from public.exercises where user_id is null order by id offset 1 limit 1;

  -- A'yı bilinen bir başlangıca getir (hepsi geri alınacak).
  delete from public.body_weight_logs where user_id = a;
  insert into public.body_weight_logs (user_id, logged_on, weight_kg) values (a, date '2026-01-10', 80);
  update public.profiles
    set weight_kg = 80, height_cm = 180, weight_direction = 'maintain', pace = null, focuses = array['general'], activity_level = 'moderate',
        daily_calorie_target = 2700, daily_protein_target_g = 160
    where user_id = a;
  delete from public.workout_sessions where user_id = a and finished_at is null;

  -- A olarak
  perform set_config('request.jwt.claims', json_build_object('sub', a, 'role', 'authenticated')::text, true);
  set local role authenticated;

  -- 1) Kilo: uygula → profil 82/3000; geri al → 80/2700 ve kayıt silinir
  pl := jsonb_build_object('date', '2026-01-20', 'kg', 82);
  insert into public.chat_events (user_id, tool, summary, payload, base)
    values (a, 'log_body_weight', 's', pl, public.chat_target_snapshot('log_body_weight', pl))
    returning id into e;
  r := public.apply_chat_action(e, '{"calorie_target": 3000, "protein_target": 180}');
  select weight_kg, daily_calorie_target into w, c from public.profiles where user_id = a;
  ok_weight := r = 'applied' and w = 82 and c = 3000;
  r := public.undo_chat_action(e);
  select weight_kg, daily_calorie_target into w, c from public.profiles where user_id = a;
  ok_weight := ok_weight and r = 'undone' and w = 80 and c = 2700
    and not exists (select 1 from public.body_weight_logs where user_id = a and logged_on = date '2026-01-20');

  -- 2) Profil: boy 185 → geri al → 180
  pl := jsonb_build_object('changes', jsonb_build_object('height_cm', 185));
  insert into public.chat_events (user_id, tool, summary, payload, base)
    values (a, 'update_profile', 's', pl, public.chat_target_snapshot('update_profile', pl))
    returning id into e;
  r := public.apply_chat_action(e, '{"calorie_target": 2800, "protein_target": 170}');
  select height_cm into h from public.profiles where user_id = a;
  ok_profile := r = 'applied' and h = 185;
  r := public.undo_chat_action(e);
  select height_cm, daily_calorie_target into h, c from public.profiles where user_id = a;
  ok_profile := ok_profile and r = 'undone' and h = 180 and c = 2700;

  -- 3) Amaç: kilo ver / dengeli / [kas, güç] → geri al → koru / [genel]
  pl := jsonb_build_object('weight_direction', 'lose', 'pace', 'balanced',
                           'focuses', jsonb_build_array('muscle', 'strength'));
  insert into public.chat_events (user_id, tool, summary, payload, base)
    values (a, 'set_goal', 's', pl, public.chat_target_snapshot('set_goal', pl))
    returning id into e;
  r := public.apply_chat_action(e, '{"calorie_target": 2200, "protein_target": 176}');
  select weight_direction, pace, focuses into g, g_pace, g_focuses from public.profiles where user_id = a;
  ok_goal := r = 'applied' and g = 'lose' and g_pace = 'balanced' and g_focuses = array['muscle', 'strength'];
  r := public.undo_chat_action(e);
  select weight_direction, pace, focuses, daily_calorie_target into g, g_pace, g_focuses, c
    from public.profiles where user_id = a;
  ok_goal := ok_goal and r = 'undone' and g = 'maintain' and g_pace is null
    and g_focuses = array['general'] and c = 2700;

  -- 3b) G1 öncesi olaylar: bekleyen uygulanamaz (stale), uygulanmış geri alınamaz (modified)
  insert into public.chat_events (user_id, tool, summary, payload, base)
    values (a, 'set_goal', 's', '{"goal": "lose_weight"}',
            '{"goal": "maintain", "daily_calorie_target": 2700, "daily_protein_target_g": 160}')
    returning id into e;
  r := public.apply_chat_action(e, '{"calorie_target": 2700, "protein_target": 160}');
  ok_legacy := r = 'stale';
  insert into public.chat_events (user_id, tool, status, summary, payload, base, before, after)
    values (a, 'set_goal', 'applied', 's', '{"goal": "lose_weight"}', '{"goal": "maintain"}',
            '{"goal": "maintain"}', '{"goal": "lose_weight"}')
    returning id into e;
  r := public.undo_chat_action(e);
  ok_legacy := ok_legacy and r = 'modified';

  -- 4) Öğün: kartta düzenlenen gramlarla iki kalem; geri al → öğün silinir
  pl := jsonb_build_object(
    'meal_id', mid, 'meal_type', 'lunch', 'logged_at', '2026-01-20T12:00:00Z',
    'items', jsonb_build_array(
      jsonb_build_object('name', 'Tavuk', 'grams', 100, 'usda_fdc_id', '1', 'needs_review', false,
        'per100', jsonb_build_object('calories', 165, 'protein_g', 31, 'carbs_g', 0, 'fat_g', 3.6)),
      jsonb_build_object('name', 'Pilav', 'grams', 100, 'usda_fdc_id', null, 'needs_review', true,
        'per100', jsonb_build_object('calories', 130, 'protein_g', 2.7, 'carbs_g', 28, 'fat_g', 0.3))));
  insert into public.chat_events (user_id, tool, summary, payload, base)
    values (a, 'create_meal', 's', pl, public.chat_target_snapshot('create_meal', pl))
    returning id into e;
  r := public.apply_chat_action(e, '{"item_grams": [200, 150]}');
  select count(*) into n from public.meal_items where meal_id = mid;
  select calories into c from public.meal_items where meal_id = mid and name = 'Tavuk';
  ok_meal := r = 'applied' and n = 2 and c = 330;
  r := public.undo_chat_action(e);
  ok_meal := ok_meal and r = 'undone' and not exists (select 1 from public.meals where id = mid);

  -- 5) Set: devam eden oturumda set kaydı → geri al → boş
  insert into public.workout_sessions (user_id, program_name, workout_name, workout_position)
    values (a, 'P', 'A', 0) returning id into sid;
  insert into public.session_sets (session_id, exercise_position, set_index, exercise_id,
                                   target_reps_min, target_reps_max)
    values (sid, 0, 0, ex1, 5, 5);
  pl := jsonb_build_object('session_id', sid, 'exercise_position', 0, 'set_index', 0,
                           'weight_kg', 80, 'reps', 5);
  insert into public.chat_events (user_id, tool, summary, payload, base)
    values (a, 'log_set', 's', pl, public.chat_target_snapshot('log_set', pl))
    returning id into e;
  r := public.apply_chat_action(e, '{}');
  select weight_kg into w from public.session_sets where session_id = sid;
  ok_set := r = 'applied' and w = 80;
  r := public.undo_chat_action(e);
  ok_set := ok_set and r = 'undone' and exists (
    select 1 from public.session_sets where session_id = sid and weight_kg is null and completed_at is null);

  -- 6) Program: hareket ekle → 2 hareket; geri al → 1
  pid := public.save_program(jsonb_build_object(
    'name', 'F5 Test', 'schedule_mode', 'rotation',
    'workouts', jsonb_build_array(jsonb_build_object('name', 'A',
      'exercises', jsonb_build_array(jsonb_build_object('exercise_id', ex1, 'sets', 3, 'reps_min', 5, 'reps_max', 5))))));
  snap := public.program_snapshot(pid);
  snap := jsonb_set(snap, '{workouts,0,exercises}',
    (snap->'workouts'->0->'exercises') || jsonb_build_array(
      jsonb_build_object('exercise_id', ex2, 'sets', 3, 'reps_min', 8, 'reps_max', 12)));
  pl := jsonb_build_object('program_id', pid, 'program', snap, 'changes', '[]'::jsonb);
  insert into public.chat_events (user_id, tool, summary, payload, base)
    values (a, 'edit_program', 's', pl, public.chat_target_snapshot('edit_program', pl))
    returning id into e;
  r := public.apply_chat_action(e, '{}');
  select count(*) into n from public.workout_exercises we
    join public.program_workouts pw on pw.id = we.workout_id where pw.program_id = pid;
  ok_program := r = 'applied' and n = 2;
  r := public.undo_chat_action(e);
  select count(*) into n from public.workout_exercises we
    join public.program_workouts pw on pw.id = we.workout_id where pw.program_id = pid;
  ok_program := ok_program and r = 'undone' and n = 1;

  -- 7) Bayatlama: öneriden sonra hedef değişirse uygulanmaz
  pl := jsonb_build_object('date', '2026-01-25', 'kg', 83);
  insert into public.chat_events (user_id, tool, summary, payload, base)
    values (a, 'log_body_weight', 's', pl, public.chat_target_snapshot('log_body_weight', pl))
    returning id into e;
  update public.profiles set daily_calorie_target = 2650 where user_id = a;
  stale_result := public.apply_chat_action(e, '{"calorie_target": 3000, "protein_target": 180}');
  select weight_kg into w from public.profiles where user_id = a;
  if w <> 80 then stale_result := stale_result || '_AMA_DEGISTI'; end if;

  -- 8) Geri alma engeli: uygulamadan sonra yeni kilo kaydı gelirse 'modified'
  pl := jsonb_build_object('date', '2026-01-25', 'kg', 83);
  insert into public.chat_events (user_id, tool, summary, payload, base)
    values (a, 'log_body_weight', 's', pl, public.chat_target_snapshot('log_body_weight', pl))
    returning id into e_applied;
  r := public.apply_chat_action(e_applied, '{"calorie_target": 3000, "protein_target": 180}');
  perform public.log_body_weight(date '2026-01-30', 84, 3050, 182);
  modified_result := public.undo_chat_action(e_applied);

  -- 9) Uygulanmış öneri tekrar uygulanamaz
  begin
    perform public.apply_chat_action(e_applied, '{"calorie_target": 3000, "protein_target": 180}');
  exception when others then
    reapply_blocked := sqlerrm like '%event_not_pending%';
  end;

  -- 10) Vazgeçilen öneri uygulanamaz
  pl := jsonb_build_object('weight_direction', 'gain', 'pace', 'slow', 'focuses', jsonb_build_array('muscle'));
  insert into public.chat_events (user_id, tool, summary, payload, base)
    values (a, 'set_goal', 's', pl, public.chat_target_snapshot('set_goal', pl))
    returning id into e;
  perform public.cancel_chat_action(e);
  begin
    perform public.apply_chat_action(e, '{"calorie_target": 2700, "protein_target": 160}');
  exception when others then
    cancel_ok := sqlerrm like '%event_not_pending%';
  end;

  -- 11) Mesaj çifti + öneri kaydı
  pl := jsonb_build_object('weight_direction', 'gain', 'pace', 'slow', 'focuses', jsonb_build_array('muscle'));
  snap := public.save_chat_exchange('merhaba', 'amacını değiştireyim mi?',
    jsonb_build_object('tool', 'set_goal', 'summary', 's', 'payload', pl,
                       'base', public.chat_target_snapshot('set_goal', pl)));
  exchange_ok := jsonb_array_length(snap) = 2
    and snap->0->>'role' = 'user'
    and snap->1->'event'->>'tool' = 'set_goal'
    and jsonb_array_length(public.recent_chat_messages(10)) >= 2;

  -- 12) B olarak: A'nın mesaj ve önerilerini göremez, uygulayamaz
  perform set_config('request.jwt.claims', json_build_object('sub', b, 'role', 'authenticated')::text, true);
  select (select count(*) from public.chat_messages where user_id = a)
       + (select count(*) from public.chat_events where user_id = a)
    into b_seen;
  begin
    perform public.undo_chat_action(e_applied);
  exception when others then
    b_blocked := sqlerrm like '%event_not_found%';
  end;

  -- 13) A olarak: sayaç silinemez, sohbeti temizle mesajları siler ama olayları değil
  perform set_config('request.jwt.claims', json_build_object('sub', a, 'role', 'authenticated')::text, true);
  delete from public.chat_usage where user_id = a;
  get diagnostics n = row_count;
  usage_kept := n = 0;
  perform public.clear_chat();
  clear_ok := not exists (select 1 from public.chat_messages where user_id = a)
    and exists (select 1 from public.chat_events where user_id = a);

  reset role;

  raise exception 'SONUC kilo=% profil=% amac=% eski_amac=% ogun=% set=% program=% bayat=% engel=% tekrar_engellendi=% iptal=% kayit=% B_gorulen=% B_engellendi=% usage_silinemedi=% temizle=%',
    ok_weight, ok_profile, ok_goal, ok_legacy, ok_meal, ok_set, ok_program, stale_result, modified_result,
    reapply_blocked, cancel_ok, exchange_ok, b_seen, b_blocked, usage_kept, clear_ok;
end;
$$;
