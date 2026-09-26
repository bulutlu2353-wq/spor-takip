-- F4a RLS / fonksiyon kontrolleri. SQL Editor'da çalıştır (migration değildir).
-- Kullanıcıları kendisi seçer: A = profili olan bir kullanıcı, B = başka bir kullanıcı.
-- Sonucu bilerek bir HATA olarak basar; hata tüm değişiklikleri geri aldığı için
-- veritabanında hiçbir şey değişmez.
-- Beklenen: ikinci_oturum_engellendi=t B_gorulen_oturum=0 B_gorulen_set=0
--           B_guncellenen_set=0 B_bitirme_engellendi=t bitti=t rotasyon=1 1rm=123.4
do $$
declare
  a uuid;
  b uuid;
  s_id uuid;
  second_blocked boolean := false;
  b_sessions int;
  b_sets int;
  b_updated int;
  b_finish_blocked boolean := false;
  is_finished boolean;
  rotation int;
  orm numeric;
begin
  select p.user_id into a from public.profiles p limit 1;
  select u.id into b from auth.users u where u.id <> a limit 1;
  if a is null or b is null then
    raise exception 'Kontrol için iki kullanıcı gerekli (a=%, b=%)', a, b;
  end if;
  -- A'nın elle testten kalmış devam eden oturumu varsa (geri alınacak) kaldır
  delete from public.workout_sessions where user_id = a and finished_at is null;

  -- A: StrongLifts aktif, oturum başlatır; ikinci oturum reddedilir
  perform set_config('request.jwt.claims', json_build_object('sub', a, 'role', 'authenticated')::text, true);
  set local role authenticated;
  update public.profiles
    set active_program_id = 'f3000000-0000-4000-8000-000000000001', next_rotation_position = 0
    where user_id = a;
  s_id := public.start_session(jsonb_build_object(
    'program_id', 'f3000000-0000-4000-8000-000000000001',
    'program_name', 'StrongLifts 5x5',
    'workout_name', 'Antrenman A',
    'workout_position', 0,
    'sets', '[{"exercise_position":0,"set_index":0,"exercise_id":"Barbell_Squat","target_reps_min":5,"target_reps_max":5,"suggested_weight_kg":60}]'::jsonb));
  begin
    perform public.start_session(jsonb_build_object(
      'program_id', null, 'program_name', 'x', 'workout_name', 'x', 'workout_position', 0, 'sets', '[]'::jsonb));
  exception when unique_violation then
    second_blocked := true;
  end;

  -- B: A'nın oturumunu ve setlerini göremez, güncelleyemez, bitiremez
  perform set_config('request.jwt.claims', json_build_object('sub', b, 'role', 'authenticated')::text, true);
  select count(*) into b_sessions from public.workout_sessions where user_id = a;
  select count(*) into b_sets from public.session_sets where session_id = s_id;
  update public.session_sets set reps = 99 where session_id = s_id;
  get diagnostics b_updated = row_count;
  begin
    perform public.finish_session(s_id, '[]'::jsonb);
  exception when others then
    b_finish_blocked := true;
  end;

  -- A: seti tamamlar, 1RM ile bitirir
  perform set_config('request.jwt.claims', json_build_object('sub', a, 'role', 'authenticated')::text, true);
  update public.session_sets set weight_kg = 60, reps = 5, completed_at = now() where session_id = s_id;
  perform public.finish_session(s_id, '[{"exercise_id":"Barbell_Squat","weight_kg":123.4}]'::jsonb);

  reset role;
  select finished_at is not null into is_finished from public.workout_sessions where id = s_id;
  select next_rotation_position into rotation from public.profiles where user_id = a;
  select weight_kg into orm from public.user_one_rep_maxes where user_id = a and exercise_id = 'Barbell_Squat';

  raise exception 'SONUC: ikinci_oturum_engellendi=% B_gorulen_oturum=% B_gorulen_set=% B_guncellenen_set=% B_bitirme_engellendi=% bitti=% rotasyon=% 1rm=%',
    second_blocked, b_sessions, b_sets, b_updated, b_finish_blocked, is_finished, rotation, orm;
end $$;
