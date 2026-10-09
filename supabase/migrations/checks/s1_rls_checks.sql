-- S1 RLS / fonksiyon kontrolleri. SQL Editor'da çalıştır (migration değildir).
-- A, B, C = üç mevcut kullanıcı (C yoksa C adımları "atlandi" yazar). Sonuç
-- bilerek HATA olarak basılır; hata tüm değişiklikleri geri aldığı için
-- veritabanında hiçbir şey değişmez.
-- Beklenen: A_istek=pending B_istek=accepted kendini_bulmaz=t buyuk_harf_bulundu=t
--           A_icin_uygun=t B_icin_uygun=f B_gorulen=1 C_gorulen=0 C_profil=0
--           cikinca_B_gorulen=0 dogrudan_engellendi=t
do $$
declare
  a uuid;
  b uuid;
  c uuid;
  ua text;
  r1 text;
  r2 text;
  self_found int;
  upper_found int;
  avail_a boolean;
  avail_b boolean;
  b_sees int;
  c_sees int;
  c_profile int;
  b_sees_after int;
  direct_blocked boolean := false;
begin
  select u.id into a from auth.users u order by u.created_at limit 1;
  select u.id into b from auth.users u where u.id <> a order by u.created_at limit 1;
  select u.id into c from auth.users u where u.id not in (a, b) order by u.created_at limit 1;
  if a is null or b is null then
    raise exception 'Kontrol için en az iki kullanıcı gerekli (a=%, b=%)', a, b;
  end if;

  -- Başlangıç (hepsi geri alınacak): sosyal kimlikler, temiz arkadaşlık, A'nın özeti.
  insert into public.public_profiles (user_id, username, display_name)
    values (a, 'chk_' || substr(md5(a::text), 1, 8), 'A') on conflict (user_id) do nothing;
  insert into public.public_profiles (user_id, username, display_name)
    values (b, 'chk_' || substr(md5(b::text), 1, 8), 'B') on conflict (user_id) do nothing;
  if c is not null then
    insert into public.public_profiles (user_id, username, display_name)
      values (c, 'chk_' || substr(md5(c::text), 1, 8), 'C') on conflict (user_id) do nothing;
  end if;
  select username into ua from public.public_profiles where user_id = a;
  delete from public.friendships where requester in (a, b) or addressee in (a, b);
  insert into public.player_stats (user_id, level, total_xp, rank)
    values (a, 3, 300, 'rookie') on conflict (user_id) do update set level = 3;

  -- A olarak
  perform set_config('request.jwt.claims', json_build_object('sub', a, 'role', 'authenticated')::text, true);
  set local role authenticated;
  r1 := public.send_friend_request(b);
  select count(*) into self_found from public.find_user(ua);
  avail_a := public.username_available(ua);

  -- B olarak: büyük harfle bulur, ad onun için uygun değil, karşılıklı istek kabul olur
  perform set_config('request.jwt.claims', json_build_object('sub', b, 'role', 'authenticated')::text, true);
  select count(*) into upper_found from public.find_user(upper(ua));
  avail_b := public.username_available(ua);
  r2 := public.send_friend_request(a);
  select count(*) into b_sees from public.player_stats where user_id = a;

  -- C olarak: A'nın özetini de profilini de göremez
  if c is not null then
    perform set_config('request.jwt.claims', json_build_object('sub', c, 'role', 'authenticated')::text, true);
    select count(*) into c_sees from public.player_stats where user_id = a;
    select count(*) into c_profile from public.public_profiles where user_id = a;
  end if;

  -- B arkadaşlığı bitirir; artık göremez ve tabloya doğrudan yazamaz
  perform set_config('request.jwt.claims', json_build_object('sub', b, 'role', 'authenticated')::text, true);
  perform public.remove_friend(a);
  select count(*) into b_sees_after from public.player_stats where user_id = a;
  begin
    insert into public.friendships (requester, addressee, status) values (b, a, 'accepted');
  exception when others then
    direct_blocked := true;
  end;

  reset role;
  raise exception 'SONUC: A_istek=% B_istek=% kendini_bulmaz=% buyuk_harf_bulundu=% A_icin_uygun=% B_icin_uygun=% B_gorulen=% C_gorulen=% C_profil=% cikinca_B_gorulen=% dogrudan_engellendi=%',
    r1, r2, self_found = 0, upper_found = 1, avail_a, avail_b, b_sees,
    coalesce(c_sees::text, 'atlandi'), coalesce(c_profile::text, 'atlandi'), b_sees_after, direct_blocked;
end $$;
