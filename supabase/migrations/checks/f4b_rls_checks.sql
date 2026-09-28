-- F4b RLS / fonksiyon kontrolleri. SQL Editor'da çalıştır (migration değildir).
-- A = profili olan bir kullanıcı, B = başka bir kullanıcı. Sonuç bilerek HATA
-- olarak basılır; hata tüm değişiklikleri geri aldığı için veritabanında
-- hiçbir şey değişmez.
-- Beklenen: backfill=t B_gorulen_kilo=0 B_gorulen_olcu=0 B_guncellenen=0
--           gecmis_profil=70 yeni_profil=82 silince_profil=80
--           eski_liste_engellendi=t tek_kayit_engellendi=t
do $$
declare
  a uuid;
  b uuid;
  has_backfill boolean;
  b_weights int;
  b_measurements int;
  b_updated int;
  kg_after_past numeric;
  kg_after_new numeric;
  kg_after_delete numeric;
  stale_blocked boolean := false;
  last_blocked boolean := false;
begin
  select p.user_id into a from public.profiles p limit 1;
  select u.id into b from auth.users u where u.id <> a limit 1;
  if a is null or b is null then
    raise exception 'Kontrol için iki kullanıcı gerekli (a=%, b=%)', a, b;
  end if;

  select exists (select 1 from public.body_weight_logs where user_id = a) into has_backfill;

  -- A'yı bilinen bir başlangıca getir (hepsi geri alınacak): tek kayıt 10.01 = 80,
  -- profil kilosu kasıtlı olarak farklı (70) ki güncellenip güncellenmediği görülsün.
  delete from public.body_weight_logs where user_id = a;
  delete from public.body_measurements where user_id = a;
  update public.profiles set weight_kg = 70 where user_id = a;
  insert into public.body_weight_logs (user_id, logged_on, weight_kg) values (a, date '2026-01-10', 80);

  -- A olarak
  perform set_config('request.jwt.claims', json_build_object('sub', a, 'role', 'authenticated')::text, true);
  set local role authenticated;

  insert into public.body_measurements (user_id, measured_on, waist) values (a, date '2026-01-10', 82);

  -- Geçmiş tarihli kayıt profile dokunmaz
  perform public.log_body_weight(date '2026-01-01', 78, 2500, 150);
  select weight_kg into kg_after_past from public.profiles where user_id = a;

  -- En yeni kayıt profili günceller
  perform public.log_body_weight(date '2026-01-20', 82, 3000, 180);
  select weight_kg into kg_after_new from public.profiles where user_id = a;

  -- B olarak: A'nın kayıtlarını göremez, değiştiremez
  perform set_config('request.jwt.claims', json_build_object('sub', b, 'role', 'authenticated')::text, true);
  select count(*) into b_weights from public.body_weight_logs where user_id = a;
  select count(*) into b_measurements from public.body_measurements where user_id = a;
  update public.body_weight_logs set weight_kg = 1 where user_id = a;
  get diagnostics b_updated = row_count;

  -- A olarak
  perform set_config('request.jwt.claims', json_build_object('sub', a, 'role', 'authenticated')::text, true);

  -- En yeniyi silerken yanlış "kalan en yeni" kilo → reddedilir
  begin
    perform public.delete_body_weight(date '2026-01-20', 99, 2600, 160);
  exception when others then
    stale_blocked := sqlerrm like '%stale_weight_list%';
  end;

  -- En yeniyi doğru değerle sil → profil bir önceki kayda (10.01 = 80) döner
  perform public.delete_body_weight(date '2026-01-20', 80, 2600, 160);
  select weight_kg into kg_after_delete from public.profiles where user_id = a;

  -- Eskiyi sil (profile dokunmaz), tek kayıt kalır; o da silinemez
  perform public.delete_body_weight(date '2026-01-01', null, null, null);
  begin
    perform public.delete_body_weight(date '2026-01-10', null, null, null);
  exception when others then
    last_blocked := sqlerrm like '%last_weight_log%';
  end;

  reset role;
  raise exception 'SONUC: backfill=% B_gorulen_kilo=% B_gorulen_olcu=% B_guncellenen=% gecmis_profil=% yeni_profil=% silince_profil=% eski_liste_engellendi=% tek_kayit_engellendi=%',
    has_backfill, b_weights, b_measurements, b_updated, kg_after_past, kg_after_new, kg_after_delete,
    stale_blocked, last_blocked;
end $$;
