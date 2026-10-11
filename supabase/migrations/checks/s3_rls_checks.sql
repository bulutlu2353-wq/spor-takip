-- S3 RLS / fonksiyon kontrolleri. SQL Editor'da çalıştır (migration değildir).
-- A, B, C = üç mevcut kullanıcı (C yoksa C adımları "atlandi" yazar). Sonuç
-- bilerek HATA olarak basılır; hata tüm değişiklikleri geri aldığı için
-- veritabanında hiçbir şey değişmez.
-- Beklenen: B_gorur=1 B_ilerleme=12 A_ilerleme=0 arkadas_degil=not_friend C_profil_B=1
--           C_reddetti_profil_B=0 disaridan_gorur=0 disaridan_katil=not_member uye_gorur=1
--           topluluk_limit=community_challenge_limit kisisel_limit=challenge_limit
--           kapandi=challenge_closed acan_silemez=not_allowed sahip_sildi=t son_ayrilan_sildi=t
do $$
declare
  a uuid;
  b uuid;
  c uuid;
  tag text;
  cm uuid;
  ch1 uuid;
  ch2 uuid;
  ch3 uuid;
  ch4 uuid;
  ch5 uuid;
  b_sees int;
  b_progress numeric;
  a_progress numeric;
  not_friend_err text;
  c_profile_b int;
  c_profile_b_after int;
  outsider_sees int;
  outsider_join_err text;
  member_sees int;
  community_limit_err text;
  personal_limit_err text;
  closed_err text;
  creator_delete_err text;
  owner_deleted boolean;
  last_deleted boolean;
begin
  select u.id into a from auth.users u order by u.created_at limit 1;
  select u.id into b from auth.users u where u.id <> a order by u.created_at limit 1;
  select u.id into c from auth.users u where u.id not in (a, b) order by u.created_at limit 1;
  if a is null or b is null then
    raise exception 'Kontrol için en az iki kullanıcı gerekli (a=%, b=%)', a, b;
  end if;
  tag := substr(md5(a::text || clock_timestamp()::text), 1, 6);

  -- Başlangıç (hepsi geri alınacak): sosyal kimlikler; A–B ve A–C arkadaş, B–C değil;
  -- üyelik ve meydan okuma katılımı yok.
  insert into public.public_profiles (user_id, username, display_name)
    values (a, 'chk_' || substr(md5(a::text), 1, 8), 'A') on conflict (user_id) do nothing;
  insert into public.public_profiles (user_id, username, display_name)
    values (b, 'chk_' || substr(md5(b::text), 1, 8), 'B') on conflict (user_id) do nothing;
  if c is not null then
    insert into public.public_profiles (user_id, username, display_name)
      values (c, 'chk_' || substr(md5(c::text), 1, 8), 'C') on conflict (user_id) do nothing;
  end if;
  delete from public.friendships where requester in (a, b, c) or addressee in (a, b, c);
  insert into public.friendships (requester, addressee, status, accepted_at) values (a, b, 'accepted', now());
  if c is not null then
    insert into public.friendships (requester, addressee, status, accepted_at) values (a, c, 'accepted', now());
  end if;
  delete from public.community_members where user_id in (a, b, c);
  delete from public.challenge_participants where user_id in (a, b, c);

  -- A: B'yi (ve C'yi) 7 günlük set yarışına davet eder
  perform set_config('request.jwt.claims', json_build_object('sub', a, 'role', 'authenticated')::text, true);
  set local role authenticated;
  ch1 := public.create_challenge('Kontrol ' || tag, 'race', 'sets', null, null, now(), now() + interval '7 days',
                                 null, case when c is null then array[b] else array[b, c] end);

  -- B: görür, kabul eder, değerini yayınlar, A'nın satırına doğrudan yazamaz;
  -- arkadaşı olmayan C'yi davet edemez
  perform set_config('request.jwt.claims', json_build_object('sub', b, 'role', 'authenticated')::text, true);
  select count(*) into b_sees from public.challenges where id = ch1;
  perform public.respond_challenge(ch1, true);
  perform public.publish_challenge_progress(ch1, 12);
  update public.challenge_participants set progress = 99 where challenge_id = ch1 and user_id = a;
  if c is not null then
    begin
      perform public.create_challenge('Davet ' || tag, 'race', 'sets', null, null, now(), now() + interval '3 days',
                                      null, array[c]);
    exception when others then
      not_friend_err := sqlerrm;
    end;
  end if;

  -- C: davetliyken B'nin profilini ortak meydan okumayla görür; reddedince göremez
  if c is not null then
    perform set_config('request.jwt.claims', json_build_object('sub', c, 'role', 'authenticated')::text, true);
    select count(*) into c_profile_b from public.public_profiles where user_id = b;
    perform public.respond_challenge(ch1, false);
    select count(*) into c_profile_b_after from public.public_profiles where user_id = b;
  end if;

  -- A: topluluk kurar ve topluluk meydan okuması açar
  perform set_config('request.jwt.claims', json_build_object('sub', a, 'role', 'authenticated')::text, true);
  cm := public.create_community('Meydan ' || tag, 'kontrol', true);
  ch2 := public.create_challenge('Topluluk ' || tag, 'goal', 'workouts', null, 4, now(), now() + interval '7 days',
                                 cm, null);

  -- B: üye değilken görmez ve katılamaz; üye olunca görür ve katılır
  perform set_config('request.jwt.claims', json_build_object('sub', b, 'role', 'authenticated')::text, true);
  select count(*) into outsider_sees from public.challenges where id = ch2;
  begin
    perform public.join_challenge(ch2);
  exception when others then
    outsider_join_err := sqlerrm;
  end;
  perform public.join_community(cm);
  select count(*) into member_sees from public.challenges where id = ch2;
  perform public.join_challenge(ch2);

  -- A: toplulukta iki tane daha (3 olur), dördüncüsü reddedilir; bir arkadaş meydan okuması
  -- daha (A'nın 5. katılımı), altıncısı reddedilir
  perform set_config('request.jwt.claims', json_build_object('sub', a, 'role', 'authenticated')::text, true);
  ch3 := public.create_challenge('Uc ' || tag, 'race', 'xp', null, null, now(), now() + interval '3 days', cm, null);
  ch4 := public.create_challenge('Dort ' || tag, 'race', 'volume', 'chest', null, now(), now() + interval '14 days',
                                 cm, null);
  begin
    perform public.create_challenge('Fazla ' || tag, 'race', 'sets', null, null, now(), now() + interval '3 days',
                                    cm, null);
  exception when others then
    community_limit_err := sqlerrm;
  end;
  ch5 := public.create_challenge('Bes ' || tag, 'race', 'workouts', null, null, now(), now() + interval '30 days',
                                 null, array[b]);
  begin
    perform public.create_challenge('Alti ' || tag, 'race', 'workouts', null, null, now(), now() + interval '3 days',
                                    null, array[b]);
  exception when others then
    personal_limit_err := sqlerrm;
  end;

  -- B: beşinciyi kabul eder; A (açan) B katıldığı için silemez
  perform set_config('request.jwt.claims', json_build_object('sub', b, 'role', 'authenticated')::text, true);
  perform public.respond_challenge(ch5, true);
  perform set_config('request.jwt.claims', json_build_object('sub', a, 'role', 'authenticated')::text, true);
  begin
    perform public.delete_challenge(ch5);
  exception when others then
    creator_delete_err := sqlerrm;
  end;
  -- A topluluk sahibi: B'nin katıldığı topluluk meydan okumasını siler; tek başına olduğu
  -- ch3'ten ayrılınca ch3 silinir
  perform public.delete_challenge(ch2);
  perform public.leave_challenge(ch3);

  -- İlk meydan okuma 24 saatten önce bitmiş olsun: B artık yayınlayamaz
  reset role;
  update public.challenges set starts_at = now() - interval '9 days', ends_at = now() - interval '2 days'
    where id = ch1;
  perform set_config('request.jwt.claims', json_build_object('sub', b, 'role', 'authenticated')::text, true);
  set local role authenticated;
  begin
    perform public.publish_challenge_progress(ch1, 20);
  exception when others then
    closed_err := sqlerrm;
  end;

  reset role;
  select progress into b_progress from public.challenge_participants where challenge_id = ch1 and user_id = b;
  select progress into a_progress from public.challenge_participants where challenge_id = ch1 and user_id = a;
  owner_deleted := not exists (select 1 from public.challenges where id = ch2);
  last_deleted := not exists (select 1 from public.challenges where id = ch3);

  raise exception 'SONUC: B_gorur=% B_ilerleme=% A_ilerleme=% arkadas_degil=% C_profil_B=% C_reddetti_profil_B=% disaridan_gorur=% disaridan_katil=% uye_gorur=% topluluk_limit=% kisisel_limit=% kapandi=% acan_silemez=% sahip_sildi=% son_ayrilan_sildi=%',
    b_sees, b_progress, a_progress, coalesce(not_friend_err, 'atlandi'),
    coalesce(c_profile_b::text, 'atlandi'), coalesce(c_profile_b_after::text, 'atlandi'),
    outsider_sees, outsider_join_err, member_sees, community_limit_err, personal_limit_err, closed_err,
    creator_delete_err, owner_deleted, last_deleted;
end $$;
