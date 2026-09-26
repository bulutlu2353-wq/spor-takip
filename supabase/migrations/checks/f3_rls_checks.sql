-- F3 RLS / fonksiyon kontrolleri. SQL Editor'da çalıştır (migration değildir;
-- `checks/` alt klasörü Supabase CLI tarafından migration olarak okunmaz).

-- 1) Seed sayıları
select
  (select count(*) from public.exercises where user_id is null) as builtin_exercises,          -- 876
  (select count(*) from public.programs where user_id is null) as builtin_programs,            -- 9
  (select count(*) from public.program_workouts w join public.programs p on p.id = w.program_id
     where p.user_id is null) as builtin_workouts;                                             -- 55

-- 2) RLS ve fonksiyonlar. Kullanıcıları kendisi seçer: A = kendi programı olan bir kullanıcı,
--    B = başka bir kullanıcı. Sonucu bilerek bir HATA olarak basar; hata tüm değişiklikleri
--    geri aldığı için veritabanında hiçbir şey değişmez.
--    Beklenen: kopya_blok=68 hazir_ad=StrongLifts 5x5 hazir_silinen=0 B_gorulen_program=0
--              B_gorulen_antrenman=0 B_yazma_engellendi=true A_program_adi_degismedi=true
do $$
declare
  a uuid;
  b uuid;
  a_prog uuid;
  a_prog_name text;
  copy_id uuid;
  copied_blocks int;
  builtin_name text;
  builtin_deleted int;
  b_programs int;
  b_workouts int;
  b_blocked boolean := false;
  b_error text := '';
  name_after text;
begin
  select p.user_id, p.id, p.name into a, a_prog, a_prog_name
    from public.programs p where p.user_id is not null limit 1;
  select u.id into b from auth.users u where u.id <> a limit 1;
  if a is null or b is null then
    raise exception 'Kontrol için iki kullanıcı gerekli ve A''nın kendi programı olmalı (a=%, b=%)', a, b;
  end if;

  -- A: hazır programı kopyalar; hazır programı değiştiremez/silemez
  perform set_config('request.jwt.claims', json_build_object('sub', a, 'role', 'authenticated')::text, true);
  set local role authenticated;
  copy_id := public.copy_program('f3000000-0000-4000-8000-000000000009');
  select count(*) into copied_blocks from public.workout_exercises e
    join public.program_workouts w on w.id = e.workout_id where w.program_id = copy_id;
  update public.programs set name = 'hack' where id = 'f3000000-0000-4000-8000-000000000001';
  delete from public.programs where id = 'f3000000-0000-4000-8000-000000000002';
  get diagnostics builtin_deleted = row_count;
  select name into builtin_name from public.programs where id = 'f3000000-0000-4000-8000-000000000001';

  -- B: A'nın programlarını göremez, save_program ile üzerine yazamaz
  perform set_config('request.jwt.claims', json_build_object('sub', b, 'role', 'authenticated')::text, true);
  select count(*) into b_programs from public.programs where user_id = a;
  select count(*) into b_workouts from public.program_workouts where program_id = a_prog;
  begin
    perform public.save_program(jsonb_build_object(
      'id', a_prog, 'name', 'hack', 'schedule_mode', 'rotation', 'workouts', '[]'::jsonb));
  exception when others then
    b_blocked := true;
    b_error := sqlerrm;
  end;

  reset role;
  select name into name_after from public.programs where id = a_prog;

  raise exception 'SONUC: kopya_blok=% hazir_ad=% hazir_silinen=% B_gorulen_program=% B_gorulen_antrenman=% B_yazma_engellendi=% A_program_adi_degismedi=% [B hatasi: %]',
    copied_blocks, builtin_name, builtin_deleted, b_programs, b_workouts, b_blocked,
    name_after = a_prog_name, b_error;
end $$;
