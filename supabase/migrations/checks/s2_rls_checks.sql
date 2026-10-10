-- S2 RLS / fonksiyon kontrolleri. SQL Editor'da çalıştır (migration değildir).
-- A, B, C = üç mevcut kullanıcı (C yoksa C adımları "atlandi" yazar). Sonuç
-- bilerek HATA olarak basılır; hata tüm değişiklikleri geri aldığı için
-- veritabanında hiçbir şey değişmez.
-- Beklenen: arama=1 kapali_arama=0 acik_degil=not_public kodla_katildi=t B_istatistik=1
--           C_istatistik=0 C_profil=0 sahip_degismez=t yasakli=banned dogrudan_engellendi=t
--           sahip_B=t son_uye_silindi=t limit=community_limit A_genelde=0 B_genelde=1 xp_unvani_B=t
do $$
declare
  a uuid;
  b uuid;
  c uuid;
  tag text;
  cid uuid;
  cid2 uuid;
  joined uuid;
  code text;
  code2 text;
  found_open int;
  found_closed int;
  not_public_err text;
  banned_err text;
  limit_err text;
  b_sees int;
  c_sees int;
  c_profile int;
  owner_locked boolean := false;
  direct_blocked boolean := false;
  owner_is_b boolean;
  last_deleted boolean;
  a_global int;
  b_global int;
  xp_title_b boolean;
  i int;
begin
  select u.id into a from auth.users u order by u.created_at limit 1;
  select u.id into b from auth.users u where u.id <> a order by u.created_at limit 1;
  select u.id into c from auth.users u where u.id not in (a, b) order by u.created_at limit 1;
  if a is null or b is null then
    raise exception 'Kontrol için en az iki kullanıcı gerekli (a=%, b=%)', a, b;
  end if;
  tag := substr(md5(a::text || clock_timestamp()::text), 1, 6);

  -- Başlangıç (hepsi geri alınacak): sosyal kimlikler, arkadaşlık ve üyelik yok,
  -- A ve B için 2099-W01 dönem özeti.
  insert into public.public_profiles (user_id, username, display_name)
    values (a, 'chk_' || substr(md5(a::text), 1, 8), 'A') on conflict (user_id) do nothing;
  insert into public.public_profiles (user_id, username, display_name)
    values (b, 'chk_' || substr(md5(b::text), 1, 8), 'B') on conflict (user_id) do nothing;
  if c is not null then
    insert into public.public_profiles (user_id, username, display_name)
      values (c, 'chk_' || substr(md5(c::text), 1, 8), 'C') on conflict (user_id) do nothing;
  end if;
  update public.public_profiles set compete_globally = true where user_id in (a, b);
  delete from public.friendships where requester in (a, b, c) or addressee in (a, b, c);
  delete from public.community_members where user_id in (a, b, c);
  insert into public.period_stats (user_id, level, rank, periods) values
    (a, 3, 'rookie', '{"week": {"key": "2099-W01", "xp": 500, "muscles": {"lats": 4}}}'),
    (b, 2, 'rookie', '{"week": {"key": "2099-W01", "xp": 300, "muscles": {}}}')
    on conflict (user_id) do update set periods = excluded.periods;

  -- A: iki açık topluluk kurar
  perform set_config('request.jwt.claims', json_build_object('sub', a, 'role', 'authenticated')::text, true);
  set local role authenticated;
  cid := public.create_community('Kontrol ' || tag, 'kontrol', true);
  cid2 := public.create_community('Ikinci ' || tag, 'kontrol', true);

  -- B: adla bulur
  perform set_config('request.jwt.claims', json_build_object('sub', b, 'role', 'authenticated')::text, true);
  select count(*) into found_open from public.search_communities('kontrol ' || tag);

  -- A: ilkini kapatır; sahibi doğrudan değiştiremez
  perform set_config('request.jwt.claims', json_build_object('sub', a, 'role', 'authenticated')::text, true);
  update public.communities set is_public = false where id = cid;
  select invite_code into code from public.communities where id = cid;
  select invite_code into code2 from public.communities where id = cid2;
  begin
    update public.communities set owner = b where id = cid;
  exception when others then
    owner_locked := true;
  end;

  -- B: kapalıyı aramada bulamaz, kimlikle katılamaz, kodla katılır; A'nın özetini görür
  perform set_config('request.jwt.claims', json_build_object('sub', b, 'role', 'authenticated')::text, true);
  select count(*) into found_closed from public.search_communities('kontrol ' || tag);
  begin
    perform public.join_community(cid);
  exception when others then
    not_public_err := sqlerrm;
  end;
  joined := public.join_community_by_code(lower(code));
  select count(*) into b_sees from public.period_stats where user_id = a;
  perform public.join_community(cid2);

  -- C: ortak topluluğu yok; A'nın özetini de profilini de göremez
  if c is not null then
    perform set_config('request.jwt.claims', json_build_object('sub', c, 'role', 'authenticated')::text, true);
    select count(*) into c_sees from public.period_stats where user_id = a;
    select count(*) into c_profile from public.public_profiles where user_id = a;
  end if;

  -- A: B'yi ikinci topluluktan yasaklayarak çıkarır
  perform set_config('request.jwt.claims', json_build_object('sub', a, 'role', 'authenticated')::text, true);
  perform public.remove_member(cid2, b, true);

  -- B: kodla geri dönemez, üyelik tablosuna doğrudan yazamaz
  perform set_config('request.jwt.claims', json_build_object('sub', b, 'role', 'authenticated')::text, true);
  begin
    perform public.join_community_by_code(code2);
  exception when others then
    banned_err := sqlerrm;
  end;
  begin
    insert into public.community_members (community_id, user_id, role) values (cid2, b, 'member');
  exception when others then
    direct_blocked := true;
  end;

  -- A: ilkinden ayrılır (sahip B olur), ikincinin son üyesi olarak ayrılır (silinir),
  -- beş topluluk kurar, altıncısı reddedilir, genel yarıştan çıkar
  perform set_config('request.jwt.claims', json_build_object('sub', a, 'role', 'authenticated')::text, true);
  perform public.leave_community(cid);
  perform public.leave_community(cid2);
  for i in 1..5 loop
    perform public.create_community('Limit ' || tag || ' ' || i, '', true);
  end loop;
  begin
    perform public.create_community('Limit ' || tag || ' 6', '', true);
  exception when others then
    limit_err := sqlerrm;
  end;
  update public.public_profiles set compete_globally = false where user_id = a;

  -- B: genel sonuçlarda A yok
  perform set_config('request.jwt.claims', json_build_object('sub', b, 'role', 'authenticated')::text, true);
  select count(*) into a_global from public.global_leaderboard('week', '2099-W01') g where g.user_id = a;
  select count(*) into b_global from public.global_leaderboard('week', '2099-W01') g where g.user_id = b;
  select count(*) = 1 and bool_and(t.user_id = b) into xp_title_b
    from public.global_titles('week', '2099-W01') t where t.category = 'xp';

  reset role;
  select owner = b into owner_is_b from public.communities where id = cid;
  last_deleted := not exists (select 1 from public.communities where id = cid2);

  raise exception 'SONUC: arama=% kapali_arama=% acik_degil=% kodla_katildi=% B_istatistik=% C_istatistik=% C_profil=% sahip_degismez=% yasakli=% dogrudan_engellendi=% sahip_B=% son_uye_silindi=% limit=% A_genelde=% B_genelde=% xp_unvani_B=%',
    found_open, found_closed, not_public_err, joined = cid, b_sees,
    coalesce(c_sees::text, 'atlandi'), coalesce(c_profile::text, 'atlandi'), owner_locked, banned_err,
    direct_blocked, owner_is_b, last_deleted, limit_err, a_global, b_global, xp_title_b;
end $$;
