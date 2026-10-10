# S3 Meydan Okumalar Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Arkadaşlara davetle ya da topluluk içinde süreli (3/7/14/30 gün) yarış veya hedef meydan okumaları; canlı sıralama, kesin sonuç, XP ödülü ve "Meydan Okuma" unvanı.

**Architecture:** Yaklaşım A (S1/S2 ile aynı): değerleri uygulama kendi geçmişinden hesaplar ve `publish_challenge_progress` ile yayınlar; sunucu yalnız pencereyi, yetkiyi ve limitleri denetler, bitişten 24 saat sonra yazmayı kapatır. Kazanan sunucuda saklanmaz; istemci kesin değerlerden hesaplar ve ödülü `XpSource.challenge` olayı olarak seviye geçmişine ekler.

**Tech Stack:** Flutter, flutter_riverpod 3, go_router, easy_localization, Supabase (Postgres RLS + security definer fonksiyonlar).

**Spec:** `docs/superpowers/specs/2026-10-10-s3-meydan-okumalar-design.md` (`c2efc52`)

## Global Constraints

- Dal: `s3-meydan-okumalar`. Migration: `supabase/migrations/0015_social_challenges.sql`; kullanıcı SQL Editor'da uygular.
- Düşük bellekli makine: yalnız hedef testleri çalıştır (`flutter test --no-pub -j 1 <dosya>`); tam paketi kullanıcı kendi terminalinde çalıştırır. Analiz: `flutter analyze` (paketi test koşarken arka planda başlatma).
- Testlerde `.tr()` anahtarı aynen döndürür (`initTestLocalization`); metin beklentileri anahtarla yazılır.
- Sabitler: süreler `[3, 7, 14, 30]`; en çok 9 davetli; kişi başı 5 aktif/başlamamış katılım; toplulukta 3 aktif/başlamamış; kesinleşme payı 24 saat; yarış birincisi +100 XP, hedef +50 XP; unvan kademeleri 1 / 5 / 15 başarı.
- Hata kodları: `challenge_limit`, `community_challenge_limit`, `not_friend`, `not_member`, `challenge_closed`, `invalid_challenge`, `not_allowed`, `no_profile`.
- Ekran ~360 px'te taşmamalı; ölçü/süre çipleri `Wrap`, sosyal sekme çubuğu kaydırılabilir.
- Commit mesajları İngilizce, sonunda `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.

## Spec'ten bilinçli sapmalar (kullanıcıya bildirilecek)

1. **Çeviri anahtarları** `social.challenge_*` yerine üst düzey `challenge.` bölümünde (sosyal bölümü zaten çok büyük).
2. **Sıralama satırında** rütbe rozeti yerine avatar (spec onayında söylendi); eşit değerde ada göre sıra `challengeStandings(names:)` ile.
3. **Topluluk kartı** kendi değerimi sunucudaki yayından gösterir (canlı değil); canlı değer Meydan okumalar sekmesinde ve meydan okuma sayfasında. Topluluk sayfası testleri antrenman sağlayıcısına bağımlı olmaz.
4. **Aktif kartta topluluk adı yok;** topluluk meydan okuması `groups` ikonuyla işaretlenir (ad, sayfanın başlığında).
5. **Davet sayısı** alt menüde istek sayısına eklenir (`incomingRequestCountProvider + pendingChallengeInvitesProvider`); Meydan okumalar sekmesinde ayrı rozet.
6. **Dönem XP'si** (`period_stats`) meydan okuma ödülünü saymaz (S2 unvanları yalnız antrenman/öğün XP'si); toplam XP ve seviye sayar.
7. **Otomatik ad** kas varsa "· Kas" ekiyle ("7 günde en çok set · Kanat"); Türkçe küçük harf dönüşümünden kaçınmak için.

## Dosya yapısı

| Dosya | Görev |
|---|---|
| `supabase/migrations/0015_social_challenges.sql` | Tablolar, yardımcılar, RLS, fonksiyonlar |
| `supabase/migrations/checks/s3_rls_checks.sql` | A/B/C kontrol bloğu, `SONUC` satırı |
| `lib/features/social/domain/challenge.dart` | Enum'lar, `Challenge`, `ChallengeParticipant`, `ChallengeDraft`, `ChallengeException`, sabitler |
| `lib/features/social/domain/challenge_progress.dart` | `ChallengeStart`, `challengeWindow`, `challengeValue` |
| `lib/features/social/domain/challenge_results.dart` | `ChallengeStanding`, `challengeStandings`, `challengeWinners`, `challengeRewardXp`, `challengeRewards` |
| `lib/features/gamification/domain/xp_rules.dart` | `XpSource.challenge`, `compareXpEvents`, `XpBreakdown.challenges` |
| `lib/features/gamification/domain/titles.dart` | `TitleKind.challenge`, `challengeThresholds`, `titleProgress(challengeWins:)` |
| `lib/features/gamification/domain/player_summary.dart` | `playerSummary(rewards:)` |
| `lib/features/gamification/presentation/title_names.dart` | Meydan okuma unvan adı ve ölçütü |
| `lib/features/gamification/presentation/level_screen.dart` | Döküm satırı, olay ikonu/metni, unvan ikonu |
| `lib/features/gamification/application/gamification_providers.dart` | `playerSummaryProvider` ödülleri izler |
| `lib/features/social/data/social_repository.dart` | Meydan okuma sorguları ve fonksiyon çağrıları |
| `lib/features/social/application/challenge_providers.dart` | `ChallengeEntry`, `MyChallenges`, `ChallengeDetail`, sağlayıcılar, senkron, `ChallengeActions` |
| `lib/core/app_shell.dart` | Senkronu izler, davet rozetini ekler |
| `lib/features/social/presentation/widgets/challenge_labels.dart` | Metin yardımcıları, `runChallengeAction` |
| `lib/features/social/presentation/widgets/challenge_cards.dart` | `ChallengeChips`, `ChallengeInviteCard`, `ChallengeActiveCard`, `ChallengeCompactRow` |
| `lib/features/social/presentation/create_challenge_sheet.dart` | Oluşturma alt sayfası |
| `lib/features/social/presentation/challenges_tab.dart` | Meydan okumalar sekmesi |
| `lib/features/social/presentation/social_screen.dart` | Dört sekme |
| `lib/features/social/presentation/challenge_screen.dart` | Meydan okuma sayfası |
| `lib/core/router.dart` | `/social/challenge/:id` |
| `lib/features/social/presentation/community_challenges_card.dart` | Topluluk sayfasındaki kart |
| `lib/features/social/presentation/community_screen.dart` | Kartı ekler |
| `lib/features/social/presentation/friend_profile_screen.dart` | "Meydan oku" düğmesi |
| `assets/translations/tr.json`, `en.json` | `challenge.` bölümü + `gamification.` ekleri |
| `test/features/social/social_fixtures.dart`, `fakes.dart` | Meydan okuma fikstürleri ve sahte depo |

---

### Task 1: Migration 0015 ve RLS kontrolü

**Files:**
- Create: `supabase/migrations/0015_social_challenges.sql`
- Create: `supabase/migrations/checks/s3_rls_checks.sql`

**Interfaces:**
- Consumes: `public.are_friends(uuid, uuid)`, `public.has_friendship(uuid, uuid)` (0013), `public.is_member(uuid, uuid)`, `public.shares_community(uuid, uuid)` (0014), `public.communities`, `public.public_profiles`.
- Produces: tablolar `challenges`, `challenge_participants`; RPC'ler `create_challenge(p_name text, p_kind text, p_metric text, p_muscle text, p_target numeric, p_starts_at timestamptz, p_ends_at timestamptz, p_community_id uuid, p_invitees uuid[]) returns uuid`, `respond_challenge(p_id uuid, p_accept boolean)`, `join_challenge(p_id uuid)`, `leave_challenge(p_id uuid)`, `delete_challenge(p_id uuid)`, `publish_challenge_progress(p_id uuid, p_value numeric)`.

- [ ] **Step 1: Migration'ı yaz**

`supabase/migrations/0015_social_challenges.sql`:

```sql
-- S3 meydan okumalar: arkadaşlara davetle ya da topluluk içinde süreli yarış/hedef.
-- Değerleri uygulama hesaplar ve yayınlar; sunucu pencereyi, yetkiyi ve limitleri denetler.

create table if not exists public.challenges (
  id uuid primary key default gen_random_uuid(),
  creator uuid not null references auth.users (id) on delete cascade,
  community_id uuid references public.communities (id) on delete cascade,
  name text not null check (char_length(btrim(name)) between 1 and 60),
  kind text not null check (kind in ('race', 'goal')),
  metric text not null check (metric in ('workouts', 'sets', 'xp', 'volume')),
  muscle text check (muscle is null or metric in ('sets', 'volume')),
  target numeric check ((kind = 'goal' and target > 0) or (kind = 'race' and target is null)),
  starts_at timestamptz not null,
  ends_at timestamptz not null check (ends_at > starts_at),
  created_at timestamptz not null default now()
);
create index if not exists challenges_community_idx on public.challenges (community_id);

create table if not exists public.challenge_participants (
  challenge_id uuid not null references public.challenges (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  status text not null check (status in ('invited', 'joined', 'declined')),
  progress numeric not null default 0 check (progress >= 0),
  updated_at timestamptz not null default now(),
  primary key (challenge_id, user_id)
);
create index if not exists challenge_participants_user_idx on public.challenge_participants (user_id);

-- Katılımcı satırım varsa (her durum) ya da topluluk meydan okumasında üyeysem.
create or replace function public.can_see_challenge(u uuid, p_id uuid) returns boolean
language sql stable security definer set search_path = public
as $$
  select exists (select 1 from challenge_participants where challenge_id = p_id and user_id = u)
      or exists (select 1 from challenges c
                 where c.id = p_id and c.community_id is not null and is_member(u, c.community_id));
$$;

-- İkisinin de reddetmediği ortak bir meydan okuma.
create or replace function public.shares_challenge(a uuid, b uuid) returns boolean
language sql stable security definer set search_path = public
as $$
  select exists (
    select 1
    from challenge_participants x
    join challenge_participants y on y.challenge_id = x.challenge_id
    where x.user_id = a and y.user_id = b and x.status <> 'declined' and y.status <> 'declined'
  );
$$;

-- Bitmemiş (ends_at > now) ve katıldığım meydan okuma sayısı.
create or replace function public.active_challenge_count(u uuid) returns int
language sql stable security definer set search_path = public
as $$
  select count(*)::int
  from challenge_participants p
  join challenges c on c.id = p.challenge_id
  where p.user_id = u and p.status = 'joined' and c.ends_at > now();
$$;

alter table public.challenges enable row level security;
alter table public.challenge_participants enable row level security;

-- Ortak meydan okumadaki kişi de sosyal kimliği görür.
drop policy if exists "Profiles visible to self and connections" on public.public_profiles;
create policy "Profiles visible to self and connections"
  on public.public_profiles for select
  using (
    user_id = auth.uid()
    or public.has_friendship(auth.uid(), user_id)
    or public.shares_community(auth.uid(), user_id)
    or public.shares_challenge(auth.uid(), user_id)
  );

drop policy if exists "Challenges visible to participants and community members" on public.challenges;
create policy "Challenges visible to participants and community members"
  on public.challenges for select
  using (public.can_see_challenge(auth.uid(), id));

drop policy if exists "Participants visible with their challenge" on public.challenge_participants;
create policy "Participants visible with their challenge"
  on public.challenge_participants for select
  using (public.can_see_challenge(auth.uid(), challenge_id));

-- Yazma yalnız fonksiyonlarla (insert/update/delete politikası yok).

create or replace function public.create_challenge(
  p_name text, p_kind text, p_metric text, p_muscle text, p_target numeric,
  p_starts_at timestamptz, p_ends_at timestamptz, p_community_id uuid, p_invitees uuid[])
returns uuid
language plpgsql security definer set search_path = public
as $$
declare
  me uuid := auth.uid();
  span double precision := extract(epoch from (p_ends_at - p_starts_at));
  invitees uuid[] := coalesce(p_invitees, '{}');
  invitee uuid;
  new_id uuid;
begin
  if me is null then
    raise exception 'not authenticated';
  end if;
  if not exists (select 1 from public_profiles where user_id = me) then
    raise exception 'no_profile';
  end if;
  if coalesce(p_kind, '') not in ('race', 'goal')
     or coalesce(p_metric, '') not in ('workouts', 'sets', 'xp', 'volume')
     or (p_muscle is not null and p_metric not in ('sets', 'volume'))
     or (p_kind = 'goal' and coalesce(p_target, 0) <= 0)
     or char_length(btrim(coalesce(p_name, ''))) not between 1 and 60
     or p_starts_at is null or p_ends_at is null
     or p_starts_at < now() - interval '5 minutes'
     or p_starts_at > now() + interval '48 hours'
     or not exists (select 1 from unnest(array[3, 7, 14, 30]) d where abs(span - d * 86400) <= 7200) then
    raise exception 'invalid_challenge';
  end if;
  if public.active_challenge_count(me) >= 5 then
    raise exception 'challenge_limit';
  end if;
  if p_community_id is null then
    if cardinality(invitees) not between 1 and 9 or me = any(invitees) then
      raise exception 'invalid_challenge';
    end if;
    foreach invitee in array invitees loop
      if not public.are_friends(me, invitee) then
        raise exception 'not_friend';
      end if;
    end loop;
  else
    if cardinality(invitees) > 0 then
      raise exception 'invalid_challenge';
    end if;
    if not public.is_member(me, p_community_id) then
      raise exception 'not_member';
    end if;
    if (select count(*) from challenges where community_id = p_community_id and ends_at > now()) >= 3 then
      raise exception 'community_challenge_limit';
    end if;
  end if;
  insert into challenges (creator, community_id, name, kind, metric, muscle, target, starts_at, ends_at)
    values (me, p_community_id, btrim(p_name), p_kind, p_metric, p_muscle,
            case when p_kind = 'goal' then p_target end, p_starts_at, p_ends_at)
    returning id into new_id;
  insert into challenge_participants (challenge_id, user_id, status) values (new_id, me, 'joined');
  insert into challenge_participants (challenge_id, user_id, status)
    select new_id, d.x, 'invited' from (select distinct unnest(invitees) as x) d;
  return new_id;
end;
$$;

create or replace function public.respond_challenge(p_id uuid, p_accept boolean) returns void
language plpgsql security definer set search_path = public
as $$
declare
  me uuid := auth.uid();
begin
  if not exists (select 1 from challenge_participants
                 where challenge_id = p_id and user_id = me and status = 'invited') then
    raise exception 'not_allowed';
  end if;
  if not p_accept then
    update challenge_participants set status = 'declined', updated_at = now()
      where challenge_id = p_id and user_id = me;
    return;
  end if;
  if not exists (select 1 from challenges where id = p_id and ends_at > now()) then
    raise exception 'challenge_closed';
  end if;
  if public.active_challenge_count(me) >= 5 then
    raise exception 'challenge_limit';
  end if;
  update challenge_participants set status = 'joined', updated_at = now()
    where challenge_id = p_id and user_id = me;
end;
$$;

-- Yalnız topluluk meydan okuması; zaten katıldıysam sessiz.
create or replace function public.join_challenge(p_id uuid) returns void
language plpgsql security definer set search_path = public
as $$
declare
  me uuid := auth.uid();
  cid uuid;
begin
  select community_id into cid from challenges where id = p_id;
  if cid is null or not public.is_member(me, cid) then
    raise exception 'not_member';
  end if;
  if exists (select 1 from challenge_participants
             where challenge_id = p_id and user_id = me and status = 'joined') then
    return;
  end if;
  if not exists (select 1 from challenges where id = p_id and ends_at > now()) then
    raise exception 'challenge_closed';
  end if;
  if public.active_challenge_count(me) >= 5 then
    raise exception 'challenge_limit';
  end if;
  insert into challenge_participants (challenge_id, user_id, status) values (p_id, me, 'joined')
    on conflict (challenge_id, user_id) do update set status = 'joined', progress = 0, updated_at = now();
end;
$$;

-- Bitmeden; kimse katılımcı kalmazsa meydan okuma silinir.
create or replace function public.leave_challenge(p_id uuid) returns void
language plpgsql security definer set search_path = public
as $$
declare
  me uuid := auth.uid();
begin
  if not exists (select 1 from challenges where id = p_id and ends_at > now()) then
    raise exception 'challenge_closed';
  end if;
  delete from challenge_participants where challenge_id = p_id and user_id = me;
  if not exists (select 1 from challenge_participants where challenge_id = p_id and status = 'joined') then
    delete from challenges where id = p_id;
  end if;
end;
$$;

-- Topluluk sahibi her zaman; açan, kendisinden başka katılımcı yokken.
create or replace function public.delete_challenge(p_id uuid) returns void
language plpgsql security definer set search_path = public
as $$
declare
  me uuid := auth.uid();
  c challenges;
begin
  select * into c from challenges where id = p_id;
  if not found then
    return;
  end if;
  if (c.community_id is not null
        and exists (select 1 from communities where id = c.community_id and owner = me))
     or (c.creator = me
        and not exists (select 1 from challenge_participants
                        where challenge_id = p_id and status = 'joined' and user_id <> me)) then
    delete from challenges where id = p_id;
    return;
  end if;
  raise exception 'not_allowed';
end;
$$;

create or replace function public.publish_challenge_progress(p_id uuid, p_value numeric) returns void
language plpgsql security definer set search_path = public
as $$
declare
  me uuid := auth.uid();
begin
  if p_value is null or p_value < 0 then
    raise exception 'invalid_challenge';
  end if;
  if not exists (select 1 from challenges where id = p_id and now() < ends_at + interval '24 hours') then
    raise exception 'challenge_closed';
  end if;
  update challenge_participants set progress = p_value, updated_at = now()
    where challenge_id = p_id and user_id = me and status = 'joined';
  if not found then
    raise exception 'not_allowed';
  end if;
end;
$$;

revoke execute on function public.can_see_challenge(uuid, uuid) from public, anon;
revoke execute on function public.shares_challenge(uuid, uuid) from public, anon;
revoke execute on function public.active_challenge_count(uuid) from public, anon, authenticated;
revoke execute on function public.create_challenge(text, text, text, text, numeric, timestamptz, timestamptz, uuid, uuid[]) from public, anon;
revoke execute on function public.respond_challenge(uuid, boolean) from public, anon;
revoke execute on function public.join_challenge(uuid) from public, anon;
revoke execute on function public.leave_challenge(uuid) from public, anon;
revoke execute on function public.delete_challenge(uuid) from public, anon;
revoke execute on function public.publish_challenge_progress(uuid, numeric) from public, anon;

grant execute on function public.can_see_challenge(uuid, uuid) to authenticated;
grant execute on function public.shares_challenge(uuid, uuid) to authenticated;
grant execute on function public.create_challenge(text, text, text, text, numeric, timestamptz, timestamptz, uuid, uuid[]) to authenticated;
grant execute on function public.respond_challenge(uuid, boolean) to authenticated;
grant execute on function public.join_challenge(uuid) to authenticated;
grant execute on function public.leave_challenge(uuid) to authenticated;
grant execute on function public.delete_challenge(uuid) to authenticated;
grant execute on function public.publish_challenge_progress(uuid, numeric) to authenticated;
```

- [ ] **Step 2: RLS kontrol bloğunu yaz**

`supabase/migrations/checks/s3_rls_checks.sql`:

```sql
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
```

Not: A'nın 5 katılımı ch1, ch2, ch3, ch4, ch5'tir (ch2 ve ch3 sonra silinir); altıncı denemede A 5'tedir. B için: ch1, ch2, ch5 → limit altında.

- [ ] **Step 3: Commit**

```bash
git add supabase/migrations/0015_social_challenges.sql supabase/migrations/checks/s3_rls_checks.sql
git commit -m "feat(social): add the challenges migration and RLS checks

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 2: Meydan okuma domain'i (model, değer, sonuç)

**Files:**
- Create: `lib/features/social/domain/challenge.dart`
- Create: `lib/features/social/domain/challenge_progress.dart`
- Create: `lib/features/social/domain/challenge_results.dart`
- Modify: `lib/features/gamification/domain/xp_rules.dart` (yalnız `XpSource.challenge` ve `compareXpEvents`; döküm Task 3'te)
- Modify: `lib/features/gamification/presentation/level_screen.dart` (yeni enum değeri için switch kolları; tam görünüm Task 3'te)
- Modify: `test/features/social/social_fixtures.dart`
- Test: `test/features/social/domain/challenge_test.dart`, `challenge_progress_test.dart`, `challenge_results_test.dart`

**Interfaces:**
- Consumes: `xpEvents`, `XpEvent` (`xp_rules.dart`), `muscleWeight` (`muscle_heat.dart`), `WorkoutSession`, `Exercise`.
- Produces:
  - `enum ChallengeKind { race, goal }`, `enum ChallengeMetric { workouts, sets, xp, volume }`, `enum ChallengeStatus { invited, joined, declined }`, `enum ChallengeState { upcoming, active, finalizing, finished }`
  - `class ChallengeException { final String code; }`, `const challengeErrorCodes`
  - sabitler `challengeDurations`, `maxChallengeInvitees`, `maxActiveChallenges`, `maxCommunityChallenges`, `challengeGrace`, `xpPerRaceWin`, `xpPerGoal`
  - `class Challenge { id, creator, communityId, name, kind, metric, muscle, target, startsAt, endsAt; isCommunity; days; finalAt; ChallengeState state(DateTime now); Challenge.fromJson }`
  - `class ChallengeParticipant { challengeId, userId, status, progress; copyWith({double? progress}); fromJson }`
  - `class ChallengeDraft { name, kind, metric, muscle, target, startsAt, endsAt, communityId, invitees; Map<String, dynamic> toParams() }`
  - `enum ChallengeStart { now, tomorrow }`, `({DateTime startsAt, DateTime endsAt}) challengeWindow(ChallengeStart start, int days, DateTime now)`
  - `double challengeValue(Challenge challenge, List<WorkoutSession> sessions, List<XpEvent> events, Map<String, Exercise> exercisesById)`
  - `class ChallengeStanding { userId, position, value, reachedGoal }`, `List<ChallengeStanding> challengeStandings(Challenge, List<ChallengeParticipant>, {Map<String, String> names})`
  - `Set<String> challengeWinners(Challenge, List<ChallengeParticipant>, DateTime now)`, `int challengeRewardXp(ChallengeKind)`, `List<XpEvent> challengeRewards(String myId, List<(Challenge, List<ChallengeParticipant>)> challenges, DateTime now)`
  - `XpSource.challenge`, `int compareXpEvents(XpEvent a, XpEvent b)`
  - fikstürler `socialChallenge(...)`, `socialParticipant(...)`

- [ ] **Step 1: Fikstürleri ekle**

`test/features/social/social_fixtures.dart` — import'lara ekle:

```dart
import 'package:spor_takip/features/social/domain/challenge.dart';
```

Dosyanın sonuna ekle:

```dart
/// Varsayılan pencere 2026-10-07 00:00 – 2026-10-14 00:00: `now = 2026-10-09 12:00` için aktif.
Challenge socialChallenge({
  String id = 'ch1',
  String name = '7 günde en çok set',
  ChallengeKind kind = ChallengeKind.race,
  ChallengeMetric metric = ChallengeMetric.sets,
  String? muscle,
  double? target,
  String creator = 'ayse',
  String? communityId,
  DateTime? startsAt,
  DateTime? endsAt,
}) =>
    Challenge(
      id: id,
      creator: creator,
      communityId: communityId,
      name: name,
      kind: kind,
      metric: metric,
      muscle: muscle,
      target: target,
      startsAt: startsAt ?? DateTime(2026, 10, 7),
      endsAt: endsAt ?? DateTime(2026, 10, 14),
    );

ChallengeParticipant socialParticipant(
  String challengeId,
  String userId, {
  ChallengeStatus status = ChallengeStatus.joined,
  double progress = 0,
}) =>
    ChallengeParticipant(challengeId: challengeId, userId: userId, status: status, progress: progress);
```

- [ ] **Step 2: Model testini yaz**

`test/features/social/domain/challenge_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:spor_takip/features/social/domain/challenge.dart';

import '../social_fixtures.dart';

void main() {
  test('fromJson reads every column and converts times to local', () {
    final c = Challenge.fromJson({
      'id': 'ch1',
      'creator': 'ayse',
      'community_id': 'c1',
      'name': 'Bu hafta 4 antrenman',
      'kind': 'goal',
      'metric': 'workouts',
      'muscle': null,
      'target': 4,
      'starts_at': '2026-10-07T00:00:00+00:00',
      'ends_at': '2026-10-14T00:00:00+00:00',
    });
    expect((c.id, c.creator, c.communityId, c.name), ('ch1', 'ayse', 'c1', 'Bu hafta 4 antrenman'));
    expect((c.kind, c.metric, c.muscle, c.target), (ChallengeKind.goal, ChallengeMetric.workouts, null, 4.0));
    expect(c.startsAt, DateTime.utc(2026, 10, 7).toLocal());
    expect(c.isCommunity, isTrue);
    expect(c.days, 7);
  });

  test('state walks upcoming → active → finalizing → finished at the exact boundaries', () {
    final c = socialChallenge();
    expect(c.state(DateTime(2026, 10, 6, 23, 59)), ChallengeState.upcoming);
    expect(c.state(DateTime(2026, 10, 7)), ChallengeState.active);
    expect(c.state(DateTime(2026, 10, 13, 23, 59)), ChallengeState.active);
    expect(c.state(DateTime(2026, 10, 14)), ChallengeState.finalizing);
    expect(c.finalAt, DateTime(2026, 10, 15));
    expect(c.state(DateTime(2026, 10, 15)), ChallengeState.finished);
  });

  test('participant fromJson and copyWith', () {
    final p = ChallengeParticipant.fromJson({
      'challenge_id': 'ch1',
      'user_id': 'me',
      'status': 'invited',
      'progress': 18.5,
    });
    expect((p.challengeId, p.userId, p.status, p.progress), ('ch1', 'me', ChallengeStatus.invited, 18.5));
    expect(p.copyWith(progress: 20).progress, 20);
    expect(p.copyWith(progress: 20).status, ChallengeStatus.invited);
  });

  test('a draft becomes RPC parameters with UTC times', () {
    final draft = ChallengeDraft(
      name: 'Kontrol',
      kind: ChallengeKind.race,
      metric: ChallengeMetric.volume,
      muscle: 'chest',
      startsAt: DateTime.utc(2026, 10, 9, 12),
      endsAt: DateTime.utc(2026, 10, 16, 12),
      invitees: const ['ayse'],
    );
    expect(draft.toParams(), {
      'p_name': 'Kontrol',
      'p_kind': 'race',
      'p_metric': 'volume',
      'p_muscle': 'chest',
      'p_target': null,
      'p_starts_at': '2026-10-09T12:00:00.000Z',
      'p_ends_at': '2026-10-16T12:00:00.000Z',
      'p_community_id': null,
      'p_invitees': ['ayse'],
    });
  });
}
```

- [ ] **Step 3: Testin yüklenemediğini gör**

Run: `flutter test --no-pub -j 1 test/features/social/domain/challenge_test.dart`
Expected: FAIL — `challenge.dart` yok.

- [ ] **Step 4: Modeli yaz**

`lib/features/social/domain/challenge.dart`:

```dart
/// Yarış: süre sonunda en yüksek değer kazanır; hedef: ulaşan herkes başarır (S3 spec §2.2).
enum ChallengeKind { race, goal }

enum ChallengeMetric { workouts, sets, xp, volume }

enum ChallengeStatus { invited, joined, declined }

/// S3 spec §3.1.
enum ChallengeState { upcoming, active, finalizing, finished }

/// Meydan okuma fonksiyonunun hata kodu; ekran koda göre metin gösterir.
class ChallengeException implements Exception {
  const ChallengeException(this.code);

  final String code;

  @override
  String toString() => 'ChallengeException($code)';
}

/// Sunucunun `raise exception` ile döndürdüğü, metni olan kodlar.
const challengeErrorCodes = {
  'challenge_limit',
  'community_challenge_limit',
  'not_friend',
  'not_member',
  'challenge_closed',
  'invalid_challenge',
  'not_allowed',
  'no_profile',
};

const challengeDurations = [3, 7, 14, 30];
const maxChallengeInvitees = 9;
const maxActiveChallenges = 5;
const maxCommunityChallenges = 3;

/// Bitişten sonra geç senkron payı; sonra sonuç kesinleşir.
const challengeGrace = Duration(hours: 24);
const xpPerRaceWin = 100;
const xpPerGoal = 50;

class Challenge {
  const Challenge({
    required this.id,
    required this.creator,
    required this.name,
    required this.kind,
    required this.metric,
    required this.startsAt,
    required this.endsAt,
    this.communityId,
    this.muscle,
    this.target,
  });

  final String id;
  final String creator;

  /// null = arkadaş meydan okuması.
  final String? communityId;
  final String name;
  final ChallengeKind kind;
  final ChallengeMetric metric;

  /// Yalnız set ve hacimde; null = tümü.
  final String? muscle;

  /// Yalnız hedefte.
  final double? target;
  final DateTime startsAt;
  final DateTime endsAt;

  bool get isCommunity => communityId != null;

  /// Yaz saati günü ±1 saat yuvarlanır.
  int get days => (endsAt.difference(startsAt).inMinutes / Duration.minutesPerDay).round();

  /// Sonucun kesinleştiği an.
  DateTime get finalAt => endsAt.add(challengeGrace);

  ChallengeState state(DateTime now) {
    if (now.isBefore(startsAt)) return ChallengeState.upcoming;
    if (now.isBefore(endsAt)) return ChallengeState.active;
    if (now.isBefore(finalAt)) return ChallengeState.finalizing;
    return ChallengeState.finished;
  }

  factory Challenge.fromJson(Map<String, dynamic> json) => Challenge(
        id: json['id'] as String,
        creator: json['creator'] as String,
        communityId: json['community_id'] as String?,
        name: json['name'] as String,
        kind: ChallengeKind.values.byName(json['kind'] as String),
        metric: ChallengeMetric.values.byName(json['metric'] as String),
        muscle: json['muscle'] as String?,
        target: (json['target'] as num?)?.toDouble(),
        startsAt: DateTime.parse(json['starts_at'] as String).toLocal(),
        endsAt: DateTime.parse(json['ends_at'] as String).toLocal(),
      );
}

class ChallengeParticipant {
  const ChallengeParticipant({
    required this.challengeId,
    required this.userId,
    required this.status,
    this.progress = 0,
  });

  final String challengeId;
  final String userId;
  final ChallengeStatus status;
  final double progress;

  ChallengeParticipant copyWith({double? progress}) => ChallengeParticipant(
        challengeId: challengeId,
        userId: userId,
        status: status,
        progress: progress ?? this.progress,
      );

  factory ChallengeParticipant.fromJson(Map<String, dynamic> json) => ChallengeParticipant(
        challengeId: json['challenge_id'] as String,
        userId: json['user_id'] as String,
        status: ChallengeStatus.values.byName(json['status'] as String),
        progress: (json['progress'] as num?)?.toDouble() ?? 0,
      );
}

/// `create_challenge` parametreleri.
class ChallengeDraft {
  const ChallengeDraft({
    required this.name,
    required this.kind,
    required this.metric,
    required this.startsAt,
    required this.endsAt,
    this.muscle,
    this.target,
    this.communityId,
    this.invitees = const [],
  });

  final String name;
  final ChallengeKind kind;
  final ChallengeMetric metric;
  final String? muscle;
  final double? target;
  final DateTime startsAt;
  final DateTime endsAt;
  final String? communityId;
  final List<String> invitees;

  Map<String, dynamic> toParams() => {
        'p_name': name,
        'p_kind': kind.name,
        'p_metric': metric.name,
        'p_muscle': muscle,
        'p_target': target,
        'p_starts_at': startsAt.toUtc().toIso8601String(),
        'p_ends_at': endsAt.toUtc().toIso8601String(),
        'p_community_id': communityId,
        'p_invitees': invitees,
      };
}
```

- [ ] **Step 5: Testin geçtiğini gör**

Run: `flutter test --no-pub -j 1 test/features/social/domain/challenge_test.dart`
Expected: PASS (4 test).

- [ ] **Step 6: `XpSource.challenge` ve `compareXpEvents` ekle**

`lib/features/gamification/domain/xp_rules.dart`:

```dart
/// XP olayının kaynağı (O1 spec §3; meydan okuma ödülü S3 spec §3.3).
enum XpSource { workout, record, mealDay, challenge }
```

`xpEvents` içindeki sıralamayı ortak karşılaştırıcıya taşı — dosyada `events.sort((a, b) {` ile başlayan bloğu şununla değiştir:

```dart
  events.sort(compareXpEvents);
  return events;
}

/// Eskiden yeniye; aynı anda kaynak sırasıyla (antrenman → rekor → öğün → meydan okuma).
int compareXpEvents(XpEvent a, XpEvent b) {
  final byDate = a.date.compareTo(b.date);
  return byDate != 0 ? byDate : a.source.index.compareTo(b.source.index);
}
```

(Eski blok `final byDate ...; return byDate != 0 ? ... ;` gövdeli lambda ve ardından gelen `return events;` satırıdır; ikisi birlikte kalkar.)

`xpBreakdown`'daki `switch`'e geçici kol ekle (Task 3 döküm alanını ekler):

```dart
      case XpSource.challenge:
        break;
```

`lib/features/gamification/presentation/level_screen.dart` — üç `switch` ifadesine kol ekle:

```dart
  static IconData _icon(XpSource source) => switch (source) {
        XpSource.workout => Icons.fitness_center,
        XpSource.record => Icons.bolt,
        XpSource.mealDay => Icons.restaurant,
        XpSource.challenge => Icons.flag,
      };

  static String _title(XpEvent event) => switch (event.source) {
        XpSource.workout => event.label ?? '',
        XpSource.record => 'gamification.record'.tr(namedArgs: {'name': event.label ?? ''}),
        XpSource.mealDay => 'gamification.meal_day'.tr(),
        XpSource.challenge => 'gamification.challenge_event'.tr(namedArgs: {'name': event.label ?? ''}),
      };
```

ve `_detail`'e `XpSource.challenge => null,`.

- [ ] **Step 7: Değer testini yaz**

`test/features/social/domain/challenge_progress_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:spor_takip/features/gamification/domain/xp_rules.dart';
import 'package:spor_takip/features/social/domain/challenge.dart';
import 'package:spor_takip/features/social/domain/challenge_progress.dart';

import '../../gamification/game_fixtures.dart';
import '../social_fixtures.dart';

final _sessions = [
  // Pencerede: 3 bench (100 kg × 5) + 2 squat (120 kg × 5) + 1 tamamlanmamış.
  gameSession('in', DateTime(2026, 10, 8, 18), [
    ...gameSets('bench', 3, kg: 100, reps: 5),
    ...gameSets('squat', 2, kg: 120, reps: 5),
    gameSet('bench', kg: 100, reps: 5, done: false, index: 9),
  ]),
  // Pencerede ama tamamlanmış seti yok: sayılmaz.
  gameSession('empty', DateTime(2026, 10, 9, 8), [gameSet('bench', done: false)]),
  // Pencereden önce ve tam bitişte: sayılmaz.
  gameSession('before', DateTime(2026, 10, 6, 18), gameSets('bench', 4)),
  gameSession('at_end', DateTime(2026, 10, 14), gameSets('squat', 5)),
  // Devam eden oturum: sayılmaz.
  gameSession('open', null, gameSets('bench', 2)),
];

double _value(ChallengeMetric metric, {String? muscle, List<XpEvent> extra = const []}) => challengeValue(
      socialChallenge(metric: metric, muscle: muscle),
      _sessions,
      [...xpEvents(_sessions, [DateTime(2026, 10, 7, 9)]), ...extra],
      gameExercisesById,
    );

void main() {
  test('"now" starts immediately; "tomorrow" starts at local midnight and lasts whole days', () {
    final now = DateTime(2026, 10, 9, 12, 30);
    expect(challengeWindow(ChallengeStart.now, 7, now), (startsAt: now, endsAt: DateTime(2026, 10, 16, 12, 30)));
    expect(
      challengeWindow(ChallengeStart.tomorrow, 3, now),
      (startsAt: DateTime(2026, 10, 10), endsAt: DateTime(2026, 10, 13)),
    );
    expect(
      challengeWindow(ChallengeStart.tomorrow, 30, DateTime(2026, 10, 25, 22)),
      (startsAt: DateTime(2026, 10, 26), endsAt: DateTime(2026, 11, 25)),
    );
  });

  test('workouts count finished sessions with a completed set inside [start, end)', () {
    expect(_value(ChallengeMetric.workouts), 1);
  });

  test('sets count completed sets; a muscle filter weighs primary 1 and secondary 0.5', () {
    expect(_value(ChallengeMetric.sets), 5);
    expect(_value(ChallengeMetric.sets, muscle: 'chest'), 3);
    expect(_value(ChallengeMetric.sets, muscle: 'triceps'), 1.5);
    expect(_value(ChallengeMetric.sets, muscle: 'lats'), 0);
  });

  test('volume sums kg × reps (weighted by muscle) and rounds', () {
    expect(_value(ChallengeMetric.volume), 3 * 500 + 2 * 600);
    expect(_value(ChallengeMetric.volume, muscle: 'chest'), 1500);
    expect(_value(ChallengeMetric.volume, muscle: 'triceps'), 750);
  });

  test('xp sums events in the window, includes the meal day at the start, skips challenge rewards', () {
    // Antrenman 50 + 5 × 5 = 75; 7 Ekim öğün günü (gün başı = başlangıç) +10.
    final reward = XpEvent(source: XpSource.challenge, date: DateTime(2026, 10, 8), xp: 100, label: 'x');
    expect(_value(ChallengeMetric.xp, extra: [reward]), 85);
  });
}
```

- [ ] **Step 8: Testin yüklenemediğini gör**

Run: `flutter test --no-pub -j 1 test/features/social/domain/challenge_progress_test.dart`
Expected: FAIL — `challenge_progress.dart` yok.

- [ ] **Step 9: Değer hesabını yaz**

`lib/features/social/domain/challenge_progress.dart`:

```dart
import '../../gamification/domain/xp_rules.dart';
import '../../workout/domain/exercise.dart';
import '../../workout/domain/muscle_heat.dart';
import '../../workout/domain/workout_session.dart';
import 'challenge.dart';

/// "Hemen" ya da "Yarın 00:00" (S3 spec §3.1).
enum ChallengeStart { now, tomorrow }

/// Hemen: şimdiden N gün; yarın: yerel yarın 00:00'dan N takvim günü sonra 00:00.
({DateTime startsAt, DateTime endsAt}) challengeWindow(ChallengeStart start, int days, DateTime now) {
  if (start == ChallengeStart.now) return (startsAt: now, endsAt: now.add(Duration(days: days)));
  final startsAt = DateTime(now.year, now.month, now.day + 1);
  return (startsAt: startsAt, endsAt: DateTime(startsAt.year, startsAt.month, startsAt.day + days));
}

/// Pencerede (`[startsAt, endsAt)`) bitmiş oturumlardan değer (S3 spec §3.2).
/// [events] tüm XP olayları; meydan okuma ödülleri sayılmaz.
double challengeValue(
  Challenge challenge,
  List<WorkoutSession> sessions,
  List<XpEvent> events,
  Map<String, Exercise> exercisesById,
) {
  bool inWindow(DateTime t) => !t.isBefore(challenge.startsAt) && t.isBefore(challenge.endsAt);
  if (challenge.metric == ChallengeMetric.xp) {
    var xp = 0;
    for (final e in events) {
      if (e.source != XpSource.challenge && inWindow(e.date)) xp += e.xp;
    }
    return xp.toDouble();
  }
  var total = 0.0;
  for (final session in sessions) {
    final finished = session.finishedAt;
    if (finished == null || !inWindow(finished)) continue;
    final done = [
      for (final set in session.sets)
        if (set.isCompleted) set,
    ];
    if (done.isEmpty) continue;
    if (challenge.metric == ChallengeMetric.workouts) {
      total += 1;
      continue;
    }
    for (final set in done) {
      final weight = switch (challenge.muscle) {
        null => 1.0,
        final muscle => switch (exercisesById[set.exerciseId]) {
            final exercise? => muscleWeight(exercise, muscle),
            null => 0.0,
          },
      };
      if (weight == 0) continue;
      total += challenge.metric == ChallengeMetric.sets ? weight : (set.weightKg ?? 0) * (set.reps ?? 0) * weight;
    }
  }
  return challenge.metric == ChallengeMetric.volume ? total.roundToDouble() : total;
}
```

- [ ] **Step 10: Testin geçtiğini gör**

Run: `flutter test --no-pub -j 1 test/features/social/domain/challenge_progress_test.dart`
Expected: PASS (5 test).

- [ ] **Step 11: Sonuç testini yaz**

`test/features/social/domain/challenge_results_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:spor_takip/features/gamification/domain/xp_rules.dart';
import 'package:spor_takip/features/social/domain/challenge.dart';
import 'package:spor_takip/features/social/domain/challenge_results.dart';

import '../social_fixtures.dart';

final _now = DateTime(2026, 10, 9, 12);
final _finishedRace = socialChallenge(id: 'old', startsAt: DateTime(2026, 9, 20), endsAt: DateTime(2026, 9, 27));
final _finishedGoal = socialChallenge(
  id: 'goal',
  kind: ChallengeKind.goal,
  target: 12,
  startsAt: DateTime(2026, 9, 20),
  endsAt: DateTime(2026, 9, 27),
);

List<ChallengeParticipant> _people(String id, Map<String, double> values) => [
      for (final MapEntry(key: user, value: v) in values.entries) socialParticipant(id, user, progress: v),
    ];

void main() {
  test('standings list joined people by value; equal values share a position, then by name', () {
    final rows = challengeStandings(
      socialChallenge(),
      [
        ..._people('ch1', {'me': 10, 'ayse': 14.5, 'burak': 10}),
        socialParticipant('ch1', 'can', status: ChallengeStatus.invited, progress: 99),
      ],
      names: const {'me': 'Samet', 'ayse': 'Ayşe Kaya', 'burak': 'Burak'},
    );
    expect([for (final r in rows) (r.userId, r.position, r.value)], [
      ('ayse', 1, 14.5),
      ('burak', 2, 10.0),
      ('me', 2, 10.0),
    ]);
    expect(rows.every((r) => !r.reachedGoal), isTrue);
  });

  test('goal standings mark who reached the target', () {
    final rows = challengeStandings(_finishedGoal, _people('goal', {'me': 10, 'ayse': 12}));
    expect({for (final r in rows) r.userId: r.reachedGoal}, {'ayse': true, 'me': false});
  });

  test('winners exist only once finished', () {
    final active = socialChallenge();
    expect(challengeWinners(active, _people('ch1', {'me': 10, 'ayse': 14}), _now), isEmpty);
    expect(challengeWinners(_finishedRace, _people('old', {'me': 10, 'ayse': 14}), _now), {'ayse'});
  });

  test('a race needs two joined people and a value above zero; ties share the win', () {
    expect(challengeWinners(_finishedRace, _people('old', {'me': 10}), _now), isEmpty);
    expect(challengeWinners(_finishedRace, _people('old', {'me': 0, 'ayse': 0}), _now), isEmpty);
    expect(challengeWinners(_finishedRace, _people('old', {'me': 14, 'ayse': 14, 'burak': 2}), _now), {'me', 'ayse'});
  });

  test('every goal reacher wins, even alone', () {
    expect(challengeWinners(_finishedGoal, _people('goal', {'me': 12}), _now), {'me'});
    expect(challengeWinners(_finishedGoal, _people('goal', {'me': 11, 'ayse': 13}), _now), {'ayse'});
  });

  test('rewards are XP events dated at the final moment, oldest first', () {
    final laterGoal = socialChallenge(
      id: 'goal2',
      name: 'Hedef',
      kind: ChallengeKind.goal,
      target: 3,
      startsAt: DateTime(2026, 9, 28),
      endsAt: DateTime(2026, 10, 5),
    );
    final events = challengeRewards('me', [
      (laterGoal, _people('goal2', {'me': 3})),
      (_finishedRace, _people('old', {'me': 20, 'ayse': 14})),
      (socialChallenge(), _people('ch1', {'me': 50, 'ayse': 1})),
      (_finishedGoal, _people('goal', {'me': 1})),
    ], _now);
    expect([for (final e in events) (e.source, e.xp, e.label, e.date)], [
      (XpSource.challenge, 100, '7 günde en çok set', DateTime(2026, 9, 28)),
      (XpSource.challenge, 50, 'Hedef', DateTime(2026, 10, 6)),
    ]);
  });
}
```

- [ ] **Step 12: Testin yüklenemediğini gör**

Run: `flutter test --no-pub -j 1 test/features/social/domain/challenge_results_test.dart`
Expected: FAIL — `challenge_results.dart` yok.

- [ ] **Step 13: Sonuç fonksiyonlarını yaz**

`lib/features/social/domain/challenge_results.dart`:

```dart
import '../../gamification/domain/xp_rules.dart';
import 'challenge.dart';

class ChallengeStanding {
  const ChallengeStanding({
    required this.userId,
    required this.position,
    required this.value,
    required this.reachedGoal,
  });

  final String userId;

  /// Eşit değerde aynı sıra.
  final int position;
  final double value;

  /// Yalnız hedefte: değer ≥ hedef.
  final bool reachedGoal;
}

/// Katılanlar (joined) değere göre azalan; eşitlikte [names] (yoksa kimlik) sırası.
List<ChallengeStanding> challengeStandings(
  Challenge challenge,
  List<ChallengeParticipant> participants, {
  Map<String, String> names = const {},
}) {
  final joined = [
    for (final p in participants)
      if (p.status == ChallengeStatus.joined) p,
  ]..sort((a, b) {
      final byValue = b.progress.compareTo(a.progress);
      return byValue != 0 ? byValue : (names[a.userId] ?? a.userId).compareTo(names[b.userId] ?? b.userId);
    });
  final rows = <ChallengeStanding>[];
  for (var i = 0; i < joined.length; i++) {
    final p = joined[i];
    rows.add(ChallengeStanding(
      userId: p.userId,
      position: i > 0 && joined[i - 1].progress == p.progress ? rows[i - 1].position : i + 1,
      value: p.progress,
      reachedGoal: challenge.kind == ChallengeKind.goal && p.progress >= (challenge.target ?? double.infinity),
    ));
  }
  return rows;
}

/// Kesinleşmişse ödül alanlar (S3 spec §3.3): yarışta en yüksek (> 0) değer(ler),
/// en az iki katılımcıyla; hedefte ulaşan herkes.
Set<String> challengeWinners(Challenge challenge, List<ChallengeParticipant> participants, DateTime now) {
  if (challenge.state(now) != ChallengeState.finished) return const {};
  final rows = challengeStandings(challenge, participants);
  if (challenge.kind == ChallengeKind.goal) {
    return {
      for (final r in rows)
        if (r.reachedGoal) r.userId,
    };
  }
  if (rows.length < 2 || rows.first.value <= 0) return const {};
  return {
    for (final r in rows)
      if (r.position == 1) r.userId,
  };
}

int challengeRewardXp(ChallengeKind kind) => kind == ChallengeKind.race ? xpPerRaceWin : xpPerGoal;

/// Kazandığım meydan okumaların XP olayları; tarih kesinleşme anı, eskiden yeniye.
List<XpEvent> challengeRewards(
  String myId,
  List<(Challenge, List<ChallengeParticipant>)> challenges,
  DateTime now,
) =>
    [
      for (final (challenge, participants) in challenges)
        if (challengeWinners(challenge, participants, now).contains(myId))
          XpEvent(
            source: XpSource.challenge,
            date: challenge.finalAt,
            xp: challengeRewardXp(challenge.kind),
            label: challenge.name,
          ),
    ]..sort(compareXpEvents);
```

- [ ] **Step 14: Domain testlerinin geçtiğini gör**

Run: `flutter test --no-pub -j 1 test/features/social/domain/challenge_test.dart test/features/social/domain/challenge_progress_test.dart test/features/social/domain/challenge_results_test.dart test/features/gamification/domain/xp_rules_test.dart`
Expected: PASS.

- [ ] **Step 15: Commit**

```bash
git add lib/features/social/domain/challenge.dart lib/features/social/domain/challenge_progress.dart lib/features/social/domain/challenge_results.dart lib/features/gamification/domain/xp_rules.dart lib/features/gamification/presentation/level_screen.dart test/features/social/social_fixtures.dart test/features/social/domain/challenge_test.dart test/features/social/domain/challenge_progress_test.dart test/features/social/domain/challenge_results_test.dart
git commit -m "feat(social): add the challenge model, value and result rules

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 3: XP dökümü, "Meydan Okuma" unvanı ve seviye ekranı

**Files:**
- Modify: `lib/features/gamification/domain/xp_rules.dart`
- Modify: `lib/features/gamification/domain/titles.dart`
- Modify: `lib/features/gamification/domain/player_summary.dart`
- Modify: `lib/features/gamification/presentation/title_names.dart`
- Modify: `lib/features/gamification/presentation/level_screen.dart`
- Modify: `assets/translations/tr.json`, `assets/translations/en.json` (`gamification` ekleri)
- Test: `test/features/gamification/domain/xp_rules_test.dart`, `titles_test.dart`, `player_summary_test.dart`, `test/features/gamification/presentation/level_screen_test.dart`

**Interfaces:**
- Consumes: `XpSource.challenge`, `compareXpEvents` (Task 2).
- Produces: `XpBreakdown.challenges`; `TitleKind.challenge` (subjectId `'wins'`), `const challengeThresholds`; `titleProgress(sessions, exercisesById, {int challengeWins = 0})`; `playerSummary(sessions, mealTimes, exercisesById, {List<XpEvent> rewards = const []})`.

- [ ] **Step 1: Gamification çevirilerini ekle**

Proje kökünde (`D:\spor_takip`) çalıştır — JSON gidiş-dönüşü dosyayı birebir korur (denendi):

```bash
python - <<'EOF'
import json, pathlib
add = {
    "tr": {"breakdown_challenges": "Meydan okumalar", "challenge_title_name": "Meydan Okuma",
           "challenge_event": "Meydan okuma: {name}", "criterion_wins": "{value} / {threshold} başarı",
           "value_wins": "{value} başarı"},
    "en": {"breakdown_challenges": "Challenges", "challenge_title_name": "Challenge",
           "challenge_event": "Challenge: {name}", "criterion_wins": "{value} / {threshold} wins",
           "value_wins": "{value} wins"},
}
for lang, keys in add.items():
    path = pathlib.Path(f"assets/translations/{lang}.json")
    text = path.read_text(encoding="utf-8")
    newline = "\r\n" if "\r\n" in text else "\n"
    data = json.loads(text)
    data["gamification"].update(keys)
    out = json.dumps(data, ensure_ascii=False, indent=2).replace("\n", newline) + newline
    path.write_text(out, encoding="utf-8", newline="")
    print(lang, "tamam")
EOF
```

- [ ] **Step 2: Domain testlerini ekle**

`test/features/gamification/domain/xp_rules_test.dart` — `main` içine ekle:

```dart
  test('the breakdown counts challenge rewards separately', () {
    final breakdown = xpBreakdown([
      XpEvent(source: XpSource.workout, date: DateTime(2026, 10, 1), xp: 60, sets: 2),
      XpEvent(source: XpSource.challenge, date: DateTime(2026, 10, 2), xp: 100, label: 'x'),
      XpEvent(source: XpSource.challenge, date: DateTime(2026, 10, 3), xp: 50, label: 'y'),
    ]);
    expect(breakdown.challenges, 150);
    expect(breakdown.total, 210);
  });
```

`test/features/gamification/domain/titles_test.dart` — `main` içine ekle:

```dart
  test('challenge wins earn the challenge title at 1 / 5 / 15', () {
    TitleProgress? challengeTitle(int wins) =>
        titleProgress(const [], const {}, challengeWins: wins).where((t) => t.kind == TitleKind.challenge).firstOrNull;
    expect(challengeTitle(0), isNull);
    expect((challengeTitle(1)!.id, challengeTitle(1)!.tier), ('challenge:wins', TitleTier.apprentice));
    expect(challengeTitle(4)!.nextThreshold, 5);
    expect(challengeTitle(5)!.tier, TitleTier.master);
    expect(challengeTitle(15)!.tier, TitleTier.champion);
  });
```

`test/features/gamification/domain/player_summary_test.dart` — `main` içine ekle (dosyada `xp_rules.dart` ve `titles.dart` import'u yoksa ekle):

```dart
  test('challenge rewards add XP, a recent gain and count toward the challenge title', () {
    final reward = XpEvent(source: XpSource.challenge, date: DateTime(2026, 10, 5), xp: 100, label: 'Yarış');
    final summary = playerSummary(const [], const [], const {}, rewards: [reward]);
    expect(summary.totalXp, 100);
    expect(summary.breakdown.challenges, 100);
    expect(summary.recent.single.source, XpSource.challenge);
    expect(summary.titles.single.id, 'challenge:wins');
  });
```

- [ ] **Step 3: Testlerin başarısız olduğunu gör**

Run: `flutter test --no-pub -j 1 test/features/gamification/domain/xp_rules_test.dart test/features/gamification/domain/titles_test.dart test/features/gamification/domain/player_summary_test.dart`
Expected: FAIL — `challenges`, `challengeWins`, `rewards` tanımsız.

- [ ] **Step 4: Dökümü genişlet**

`lib/features/gamification/domain/xp_rules.dart` — `XpBreakdown`'ı değiştir:

```dart
/// Seviye ekranındaki döküm: antrenman tabanı, setler, rekorlar, öğün günleri, meydan okumalar.
class XpBreakdown {
  const XpBreakdown({this.workouts = 0, this.sets = 0, this.records = 0, this.mealDays = 0, this.challenges = 0});

  final int workouts;
  final int sets;
  final int records;
  final int mealDays;
  final int challenges;

  int get total => workouts + sets + records + mealDays + challenges;
}
```

`xpBreakdown`'ı değiştir:

```dart
XpBreakdown xpBreakdown(List<XpEvent> events) {
  var workouts = 0, sets = 0, records = 0, mealDays = 0, challenges = 0;
  for (final e in events) {
    switch (e.source) {
      case XpSource.workout:
        workouts += xpPerWorkout;
        sets += e.sets * xpPerSet;
      case XpSource.record:
        records += e.xp;
      case XpSource.mealDay:
        mealDays += e.xp;
      case XpSource.challenge:
        challenges += e.xp;
    }
  }
  return XpBreakdown(workouts: workouts, sets: sets, records: records, mealDays: mealDays, challenges: challenges);
}
```

- [ ] **Step 5: Unvanı ekle**

`lib/features/gamification/domain/titles.dart`:

```dart
enum TitleKind { muscle, exercise, challenge }
```

eşiklerin altına:

```dart
/// Kazanılan meydan okuma sayısı (S3 spec §3.3).
const challengeThresholds = {TitleTier.apprentice: 1.0, TitleTier.master: 5.0, TitleTier.champion: 15.0};
```

`TitleProgress` içindeki `_thresholds`'ı değiştir ve belgeleri güncelle:

```dart
  /// Kas: ağırlıklı set; hareket: oturum sayısı; meydan okuma: kazanım sayısı.
  final double value;

  Map<TitleTier, double> get _thresholds => switch (kind) {
        TitleKind.muscle => muscleThresholds,
        TitleKind.exercise => exerciseThresholds,
        TitleKind.challenge => challengeThresholds,
      };
```

`titleProgress` imzasını ve dönüş listesini değiştir:

```dart
/// Tüm kaslar, hareketler ve meydan okuma kazanımları için ilerleme; değeri 0 olanlar yok.
List<TitleProgress> titleProgress(
  List<WorkoutSession> sessions,
  Map<String, Exercise> exercisesById, {
  int challengeWins = 0,
}) {
```

ve `return [` listesinin sonuna (hareket unvanlarından sonra):

```dart
    if (challengeWins > 0)
      TitleProgress(kind: TitleKind.challenge, subjectId: 'wins', value: challengeWins.toDouble()),
```

- [ ] **Step 6: Özeti ödüllerle kur**

`lib/features/gamification/domain/player_summary.dart` — `playerSummary`'yi değiştir:

```dart
/// [rewards]: kesinleşmiş meydan okuma ödülleri (`XpSource.challenge`, S3 spec §3.3).
PlayerSummary playerSummary(
  List<WorkoutSession> sessions,
  List<DateTime> mealTimes,
  Map<String, Exercise> exercisesById, {
  List<XpEvent> rewards = const [],
}) {
  final events = [...xpEvents(sessions, mealTimes), ...rewards]..sort(compareXpEvents);
  final breakdown = xpBreakdown(events);
  final progress = levelFor(breakdown.total);
  final all = titleProgress(sessions, exercisesById, challengeWins: rewards.length);
  return PlayerSummary(
    totalXp: breakdown.total,
    progress: progress,
    rank: rankFor(progress.level),
    breakdown: breakdown,
    recent: events.reversed.take(10).toList(),
    titles: earnedTitles(all),
    upcoming: upcomingTitles(all),
  );
}
```

- [ ] **Step 7: Domain testlerinin geçtiğini gör**

Run: `flutter test --no-pub -j 1 test/features/gamification/domain/xp_rules_test.dart test/features/gamification/domain/titles_test.dart test/features/gamification/domain/player_summary_test.dart`
Expected: PASS.

- [ ] **Step 8: Unvan adını ve ölçütünü ekle**

`lib/features/gamification/presentation/title_names.dart` — iki fonksiyonu değiştir:

```dart
/// "Kanat Şampiyonu", "Barbell Squat Ustası", "Meydan Okuma Çırağı".
String titleName(TitleProgress title, TitleTier tier) {
  final name = switch (title.kind) {
    TitleKind.muscle => 'gamification.muscle_short.${taxonomySlug(title.subjectId)}'.tr(),
    TitleKind.exercise => title.exerciseName ?? title.subjectId,
    TitleKind.challenge => 'gamification.challenge_title_name'.tr(),
  };
  return 'gamification.title_tier.${tier.name}'.tr(namedArgs: {'name': name});
}

/// "320 / 500 set", "41 / 50 oturum", "3 / 5 başarı"; şampiyonda yalnız değer.
String titleCriterion(TitleProgress title) {
  final (value, unit) = switch (title.kind) {
    TitleKind.muscle => (formatSets(title.value), 'sets'),
    TitleKind.exercise => ('${title.value.toInt()}', 'sessions'),
    TitleKind.challenge => ('${title.value.toInt()}', 'wins'),
  };
  final next = title.nextThreshold;
  if (next == null) return 'gamification.value_$unit'.tr(namedArgs: {'value': value});
  return 'gamification.criterion_$unit'.tr(namedArgs: {'value': value, 'threshold': '${next.toInt()}'});
}
```

- [ ] **Step 9: Seviye ekranı testini ekle**

`test/features/gamification/presentation/level_screen_test.dart` — `main` içine ekle (dosyada `xp_rules.dart` ve `titles.dart` zaten import'lu; `player_summary.dart` da):

```dart
  testWidgets('challenge rewards show in the breakdown, titles and recent gains', (tester) async {
    final reward = XpEvent(source: XpSource.challenge, date: DateTime(2026, 10, 5), xp: 100, label: 'Yarış');
    await pump(tester, () async => playerSummary(const [], const [], const {}, rewards: [reward]));
    final breakdown = find.byKey(const Key('level_breakdown'));
    expect(find.descendant(of: breakdown, matching: find.text('gamification.breakdown_challenges')), findsOneWidget);
    expect(find.descendant(of: find.byKey(const Key('level_titles')), matching: find.byIcon(Icons.flag_outlined)),
        findsOneWidget);
    expect(find.descendant(of: find.byKey(const Key('level_recent')), matching: find.byIcon(Icons.flag)),
        findsOneWidget);
  });
```

- [ ] **Step 10: Testin başarısız olduğunu gör**

Run: `flutter test --no-pub -j 1 test/features/gamification/presentation/level_screen_test.dart`
Expected: FAIL — döküm satırı ve bayrak ikonu yok.

- [ ] **Step 11: Seviye ekranını güncelle**

`lib/features/gamification/presentation/level_screen.dart` — `_Breakdown.build` içindeki `Column` çocuklarının sonuna (öğün satırından sonra) ekle:

```dart
        const SizedBox(height: 12),
        Row(
          children: [
            tile(Icons.flag_outlined, 'gamification.breakdown_challenges'.tr(), breakdown.challenges),
            const SizedBox(width: 12),
            const Expanded(child: SizedBox()),
          ],
        ),
```

Unvan satırının ikonunu (`title.kind == TitleKind.muscle ? Icons.accessibility_new : Icons.fitness_center`) şununla değiştir:

```dart
                    switch (title.kind) {
                      TitleKind.muscle => Icons.accessibility_new,
                      TitleKind.exercise => Icons.fitness_center,
                      TitleKind.challenge => Icons.flag_outlined,
                    },
```

- [ ] **Step 12: Testlerin geçtiğini gör**

Run: `flutter test --no-pub -j 1 test/features/gamification`
Expected: PASS (tüm gamification testleri).

- [ ] **Step 13: Commit**

```bash
git add lib/features/gamification assets/translations/tr.json assets/translations/en.json test/features/gamification
git commit -m "feat(gamification): count challenge rewards in XP and add the challenge title

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 4: Depo, sağlayıcılar, yayın ve ödüllerin bağlanması

**Files:**
- Modify: `lib/features/social/data/social_repository.dart`
- Create: `lib/features/social/application/challenge_providers.dart`
- Modify: `lib/features/gamification/application/gamification_providers.dart`
- Modify: `lib/core/app_shell.dart`
- Modify: `test/features/social/fakes.dart`
- Modify: `test/features/gamification/application/gamification_providers_test.dart`
- Modify: `test/core/app_shell_test.dart`
- Test: `test/features/social/application/challenge_providers_test.dart`

**Interfaces:**
- Consumes: Task 2 domain; `myPublicProfileProvider`, `socialRepositoryProvider`, `allSessionsProvider`, `mealTimesProvider`, `exercisesByIdProvider`, `nowProvider`.
- Produces:
  - `SocialRepository`: `fetchMyChallengeIds()`, `fetchCommunityChallengeIds(String communityId)`, `fetchChallenges(List<String> ids)`, `fetchParticipants(List<String> challengeIds)` → `Map<String, List<ChallengeParticipant>>`, `createChallenge(ChallengeDraft draft)` → `String`, `respondChallenge(String id, {required bool accept})`, `joinChallenge(String id)`, `leaveChallenge(String id)`, `deleteChallenge(String id)`, `publishChallengeProgress(String id, double value)`
  - `class ChallengeEntry { challenge, participants, myId; ChallengeParticipant? mine }`
  - `class MyChallenges { invites, active, upcoming, finished, profiles }`
  - `class ChallengeDetail { challenge, participants, profiles, myId, community; mine; canDelete }`
  - `myChallengeValueProvider` (`FutureProvider.autoDispose<double Function(Challenge)>`), `myChallengesProvider`, `communityChallengesProvider` (family `String`), `challengeDetailProvider` (family `String`), `challengeRewardsProvider` (`List<XpEvent>`), `pendingChallengeInvitesProvider` (`int`), `challengeSyncProvider`, `lastPublishedChallengeValuesProvider`, `challengeActionsProvider` → `ChallengeActions { create(ChallengeDraft) → Future<String>; respond(Challenge, {required bool accept}); join(Challenge); leave(Challenge); delete(Challenge) }`
  - Sahte depo alanları: `challenges`, `participants`, `createdChallenges`, `challengeResponses`, `joinedChallenges`, `leftChallenges`, `deletedChallenges`, `publishedProgress`, `challengeError`.

- [ ] **Step 1: Depo arayüzünü ve Supabase uygulamasını genişlet**

`lib/features/social/data/social_repository.dart` — import ekle:

```dart
import '../domain/challenge.dart';
```

`SocialRepository` arayüzünün sonuna:

```dart
  /// Davetler dahil, reddettiklerim hariç.
  Future<List<String>> fetchMyChallengeIds();
  Future<List<String>> fetchCommunityChallengeIds(String communityId);
  Future<List<Challenge>> fetchChallenges(List<String> ids);

  /// Meydan okuma → katılımcılar.
  Future<Map<String, List<ChallengeParticipant>>> fetchParticipants(List<String> challengeIds);

  /// Yeni meydan okumanın kimliği.
  Future<String> createChallenge(ChallengeDraft draft);
  Future<void> respondChallenge(String id, {required bool accept});
  Future<void> joinChallenge(String id);
  Future<void> leaveChallenge(String id);
  Future<void> deleteChallenge(String id);
  Future<void> publishChallengeProgress(String id, double value);
```

`SupabaseSocialRepository` içine sabit:

```dart
  static const _challengeColumns = 'id, creator, community_id, name, kind, metric, muscle, target, starts_at, ends_at';
```

ve sınıfın sonuna:

```dart
  /// Meydan okuma fonksiyonunun `raise exception '<kod>'` hatasını [ChallengeException]'a çevirir.
  Future<T> _challenge<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on PostgrestException catch (e) {
      if (challengeErrorCodes.contains(e.message)) throw ChallengeException(e.message);
      rethrow;
    }
  }

  @override
  Future<List<String>> fetchMyChallengeIds() async {
    final rows = await _client
        .from('challenge_participants')
        .select('challenge_id')
        .eq('user_id', _me)
        .neq('status', 'declined');
    return [for (final row in rows) row['challenge_id'] as String];
  }

  @override
  Future<List<String>> fetchCommunityChallengeIds(String communityId) async {
    final rows = await _client.from('challenges').select('id').eq('community_id', communityId);
    return [for (final row in rows) row['id'] as String];
  }

  @override
  Future<List<Challenge>> fetchChallenges(List<String> ids) async {
    if (ids.isEmpty) return const [];
    final rows = await _client.from('challenges').select(_challengeColumns).inFilter('id', ids);
    return [for (final row in rows) Challenge.fromJson(row)];
  }

  @override
  Future<Map<String, List<ChallengeParticipant>>> fetchParticipants(List<String> challengeIds) async {
    if (challengeIds.isEmpty) return const {};
    final rows = await _client
        .from('challenge_participants')
        .select('challenge_id, user_id, status, progress')
        .inFilter('challenge_id', challengeIds);
    final result = <String, List<ChallengeParticipant>>{};
    for (final row in rows) {
      final participant = ChallengeParticipant.fromJson(row);
      (result[participant.challengeId] ??= []).add(participant);
    }
    return result;
  }

  @override
  Future<String> createChallenge(ChallengeDraft draft) =>
      _challenge(() async => await _client.rpc('create_challenge', params: draft.toParams()) as String);

  @override
  Future<void> respondChallenge(String id, {required bool accept}) => _challenge(() async {
        await _client.rpc('respond_challenge', params: {'p_id': id, 'p_accept': accept});
      });

  @override
  Future<void> joinChallenge(String id) => _challenge(() async {
        await _client.rpc('join_challenge', params: {'p_id': id});
      });

  @override
  Future<void> leaveChallenge(String id) => _challenge(() async {
        await _client.rpc('leave_challenge', params: {'p_id': id});
      });

  @override
  Future<void> deleteChallenge(String id) => _challenge(() async {
        await _client.rpc('delete_challenge', params: {'p_id': id});
      });

  @override
  Future<void> publishChallengeProgress(String id, double value) => _challenge(() async {
        await _client.rpc('publish_challenge_progress', params: {'p_id': id, 'p_value': value});
      });
```

- [ ] **Step 2: Sahte depoyu genişlet**

`test/features/social/fakes.dart` — import ekle:

```dart
import 'package:spor_takip/features/social/domain/challenge.dart';
```

Kurucu parametrelerine ekle:

```dart
    List<Challenge> challenges = const [],
    Map<String, List<ChallengeParticipant>> participants = const {},
```

başlatıcı listesine ekle:

```dart
        challenges = {for (final c in challenges) c.id: c},
        participants = {for (final MapEntry(key: id, value: list) in participants.entries) id: [...list]},
```

alanlara ekle:

```dart
  final Map<String, Challenge> challenges;
  final Map<String, List<ChallengeParticipant>> participants;
  final List<ChallengeDraft> createdChallenges = [];
  final List<(String, bool)> challengeResponses = [];
  final List<String> joinedChallenges = [];
  final List<String> leftChallenges = [];
  final List<String> deletedChallenges = [];
  final List<(String, double)> publishedProgress = [];

  /// Meydan okuma yazma işlemleri bunu fırlatır.
  ChallengeException? challengeError;
```

yardımcılar ve uygulamalar (sınıfın sonuna):

```dart
  void _throwChallengeError() {
    if (challengeError case final e?) throw e;
  }

  void _setMyStatus(String id, ChallengeStatus status) {
    final list = participants[id] ??= [];
    list.removeWhere((p) => p.userId == _myId);
    list.add(ChallengeParticipant(challengeId: id, userId: _myId, status: status));
  }

  @override
  Future<List<String>> fetchMyChallengeIds() async {
    _maybeThrow();
    return [
      for (final MapEntry(key: id, value: list) in participants.entries)
        if (list.any((p) => p.userId == _myId && p.status != ChallengeStatus.declined)) id,
    ];
  }

  @override
  Future<List<String>> fetchCommunityChallengeIds(String communityId) async => [
        for (final c in challenges.values)
          if (c.communityId == communityId) c.id,
      ];

  @override
  Future<List<Challenge>> fetchChallenges(List<String> ids) async => [
        for (final id in ids)
          ?challenges[id],
      ];

  @override
  Future<Map<String, List<ChallengeParticipant>>> fetchParticipants(List<String> challengeIds) async => {
        for (final id in challengeIds)
          if (participants[id] case final list?) id: [...list],
      };

  @override
  Future<String> createChallenge(ChallengeDraft draft) async {
    _throwChallengeError();
    createdChallenges.add(draft);
    challenges['new'] = Challenge(
      id: 'new',
      creator: _myId,
      communityId: draft.communityId,
      name: draft.name,
      kind: draft.kind,
      metric: draft.metric,
      muscle: draft.muscle,
      target: draft.target,
      startsAt: draft.startsAt,
      endsAt: draft.endsAt,
    );
    participants['new'] = [
      ChallengeParticipant(challengeId: 'new', userId: _myId, status: ChallengeStatus.joined),
      for (final id in draft.invitees) ChallengeParticipant(challengeId: 'new', userId: id, status: ChallengeStatus.invited),
    ];
    return 'new';
  }

  @override
  Future<void> respondChallenge(String id, {required bool accept}) async {
    _throwChallengeError();
    challengeResponses.add((id, accept));
    _setMyStatus(id, accept ? ChallengeStatus.joined : ChallengeStatus.declined);
  }

  @override
  Future<void> joinChallenge(String id) async {
    _throwChallengeError();
    joinedChallenges.add(id);
    _setMyStatus(id, ChallengeStatus.joined);
  }

  @override
  Future<void> leaveChallenge(String id) async {
    _throwChallengeError();
    leftChallenges.add(id);
    participants[id]?.removeWhere((p) => p.userId == _myId);
  }

  @override
  Future<void> deleteChallenge(String id) async {
    _throwChallengeError();
    deletedChallenges.add(id);
    challenges.remove(id);
    participants.remove(id);
  }

  @override
  Future<void> publishChallengeProgress(String id, double value) async => publishedProgress.add((id, value));
```

- [ ] **Step 3: Sağlayıcı testini yaz**

`test/features/social/application/challenge_providers_test.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spor_takip/features/gamification/domain/xp_rules.dart';
import 'package:spor_takip/features/onboarding/application/auth_providers.dart';
import 'package:spor_takip/features/progress/application/progress_providers.dart';
import 'package:spor_takip/features/social/application/challenge_providers.dart';
import 'package:spor_takip/features/social/application/social_providers.dart';
import 'package:spor_takip/features/social/domain/challenge.dart';
import 'package:spor_takip/features/workout/application/muscle_heat_providers.dart';
import 'package:spor_takip/features/workout/application/session_providers.dart';

import '../../gamification/game_fixtures.dart';
import '../fakes.dart';
import '../social_fixtures.dart';

// Aktif pencerede (7–14 Ekim) 3 set.
final _sessions = [gameSession('a', DateTime(2026, 10, 8, 18), gameSets('bench', 3))];

final _invite = socialChallenge(id: 'inv', name: 'Davet');
final _active = socialChallenge(id: 'ch1');
final _upcoming = socialChallenge(id: 'up', startsAt: DateTime(2026, 10, 10), endsAt: DateTime(2026, 10, 13));
final _finished = socialChallenge(id: 'old', name: 'Eski', startsAt: DateTime(2026, 9, 20), endsAt: DateTime(2026, 9, 27));
final _declined = socialChallenge(id: 'no');
final _community = socialChallenge(id: 'cm', communityId: 'c1', creator: 'me');

FakeSocialRepository _repo() => FakeSocialRepository(
      me: socialMe,
      others: [socialAyse, socialBurak],
      communities: [socialCommunity],
      members: {
        'c1': [socialMember('c1', 'me', owner: true), socialMember('c1', 'ayse', day: 2)],
      },
      challenges: [_invite, _active, _upcoming, _finished, _declined, _community],
      participants: {
        'inv': [socialParticipant('inv', 'ayse'), socialParticipant('inv', 'me', status: ChallengeStatus.invited)],
        'ch1': [socialParticipant('ch1', 'ayse', progress: 14), socialParticipant('ch1', 'me')],
        'up': [socialParticipant('up', 'burak'), socialParticipant('up', 'me')],
        'old': [socialParticipant('old', 'ayse', progress: 10), socialParticipant('old', 'me', progress: 20)],
        'no': [socialParticipant('no', 'ayse'), socialParticipant('no', 'me', status: ChallengeStatus.declined)],
        'cm': [socialParticipant('cm', 'me', progress: 2), socialParticipant('cm', 'ayse', progress: 5)],
      },
    );

ProviderContainer _container(FakeSocialRepository repo) {
  final container = ProviderContainer(overrides: [
    isLoggedInProvider.overrideWithValue(true),
    socialRepositoryProvider.overrideWithValue(repo),
    nowProvider.overrideWithValue(() => DateTime(2026, 10, 9, 12)),
    allSessionsProvider.overrideWith((ref) async => _sessions),
    mealTimesProvider.overrideWith((ref) async => const []),
    exercisesByIdProvider.overrideWith((ref) async => gameExercisesById),
  ]);
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('my challenges are grouped; my own value in active ones is live', () async {
    final container = _container(_repo());
    container.listen(myChallengesProvider, (_, _) {});
    container.listen(pendingChallengeInvitesProvider, (_, _) {});
    final mine = await container.read(myChallengesProvider.future);
    expect([for (final e in mine.invites) e.challenge.id], ['inv']);
    expect([for (final e in mine.active) e.challenge.id], ['ch1', 'cm']);
    expect([for (final e in mine.upcoming) e.challenge.id], ['up']);
    expect([for (final e in mine.finished) e.challenge.id], ['old']);
    expect(mine.active.first.mine?.progress, 3);
    expect(mine.finished.single.mine?.progress, 20);
    expect(mine.profiles.keys, containsAll(['me', 'ayse', 'burak']));
    expect(container.read(pendingChallengeInvitesProvider), 1);
  });

  test('without a social profile there are no challenges', () async {
    final container = _container(FakeSocialRepository());
    container.listen(myChallengesProvider, (_, _) {});
    final mine = await container.read(myChallengesProvider.future);
    expect(mine.invites.isEmpty && mine.active.isEmpty && mine.finished.isEmpty, isTrue);
  });

  test('sync publishes only active joined values, and only when they change', () async {
    final repo = _repo();
    final container = _container(repo);
    container.listen(challengeSyncProvider, (_, _) {});
    await container.read(challengeSyncProvider.future);
    expect(repo.publishedProgress, [('ch1', 3.0), ('cm', 3.0)]);

    container.invalidate(challengeSyncProvider);
    await container.read(challengeSyncProvider.future);
    expect(repo.publishedProgress, hasLength(2));
  });

  test('rewards come from finished challenges I won', () async {
    final container = _container(_repo());
    container.listen(challengeRewardsProvider, (_, _) {});
    final rewards = await container.read(challengeRewardsProvider.future);
    expect([for (final e in rewards) (e.source, e.xp, e.label)], [(XpSource.challenge, 100, 'Eski')]);
  });

  test('rewards fall back to empty when the repository fails', () async {
    final container = _container(_repo()..error = Exception('offline'));
    container.listen(challengeRewardsProvider, (_, _) {});
    expect(await container.read(challengeRewardsProvider.future), isEmpty);
  });

  test('community challenges list unfinished ones with server values', () async {
    final container = _container(_repo());
    container.listen(communityChallengesProvider('c1'), (_, _) {});
    final entries = await container.read(communityChallengesProvider('c1').future);
    expect([for (final e in entries) (e.challenge.id, e.mine?.progress)], [('cm', 2.0)]);
  });

  test('detail has profiles (me included), the community, a live value and delete rights', () async {
    final container = _container(_repo());
    container.listen(challengeDetailProvider('cm'), (_, _) {});
    container.listen(challengeDetailProvider('ch1'), (_, _) {});
    container.listen(challengeDetailProvider('nope'), (_, _) {});

    final community = (await container.read(challengeDetailProvider('cm').future))!;
    expect(community.community?.name, 'Demir Kulübü');
    expect(community.profiles.keys, containsAll(['me', 'ayse']));
    expect(community.mine?.progress, 3);
    expect(community.canDelete, isTrue);

    final friends = (await container.read(challengeDetailProvider('ch1').future))!;
    expect(friends.community, isNull);
    expect(friends.canDelete, isFalse);
    expect(await container.read(challengeDetailProvider('nope').future), isNull);
  });

  test('actions call the repository and refresh my challenges', () async {
    final repo = _repo();
    final container = _container(repo);
    container.listen(myChallengesProvider, (_, _) {});
    await container.read(myChallengesProvider.future);
    final actions = container.read(challengeActionsProvider);

    await actions.respond(_invite, accept: true);
    expect(repo.challengeResponses, [('inv', true)]);
    expect([for (final e in (await container.read(myChallengesProvider.future)).active) e.challenge.id],
        containsAll(['inv', 'ch1']));

    final id = await actions.create(ChallengeDraft(
      name: 'Yeni',
      kind: ChallengeKind.race,
      metric: ChallengeMetric.workouts,
      startsAt: DateTime(2026, 10, 9, 12),
      endsAt: DateTime(2026, 10, 12, 12),
      invitees: const ['ayse'],
    ));
    expect(id, 'new');
    expect([for (final e in (await container.read(myChallengesProvider.future)).active) e.challenge.id],
        contains('new'));

    await actions.leave(_active);
    await actions.delete(_community);
    expect((repo.leftChallenges, repo.deletedChallenges), (['ch1'], ['cm']));
  });
}
```

- [ ] **Step 4: Testin yüklenemediğini gör**

Run: `flutter test --no-pub -j 1 test/features/social/application/challenge_providers_test.dart`
Expected: FAIL — `challenge_providers.dart` yok.

- [ ] **Step 5: Sağlayıcıları yaz**

`lib/features/social/application/challenge_providers.dart`:

```dart
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../gamification/domain/xp_rules.dart';
import '../../progress/application/progress_providers.dart';
import '../../workout/application/muscle_heat_providers.dart';
import '../../workout/application/session_providers.dart';
import '../data/social_repository.dart';
import '../domain/challenge.dart';
import '../domain/challenge_progress.dart';
import '../domain/challenge_results.dart';
import '../domain/community.dart';
import '../domain/public_profile.dart';
import 'social_providers.dart';

/// Kendi geçmişimden meydan okuma değeri (S3 spec §3.2); XP olayları bir kez hesaplanır.
final myChallengeValueProvider = FutureProvider.autoDispose<double Function(Challenge)>((ref) async {
  final (sessions, mealTimes, exercisesById) = await (
    ref.watch(allSessionsProvider.future),
    ref.watch(mealTimesProvider.future),
    ref.watch(exercisesByIdProvider.future),
  ).wait;
  final events = xpEvents(sessions, mealTimes);
  return (challenge) => challengeValue(challenge, sessions, events, exercisesById);
});

/// Aktif ya da kesinleşme payındayken katıldığım satıra yerel (canlı) değeri koyar.
List<ChallengeParticipant> _withMyLiveValue(
  Challenge challenge,
  List<ChallengeParticipant> participants,
  String myId,
  DateTime now,
  double Function(Challenge) valueOf,
) {
  final state = challenge.state(now);
  if (state != ChallengeState.active && state != ChallengeState.finalizing) return participants;
  return [
    for (final p in participants)
      p.userId == myId && p.status == ChallengeStatus.joined ? p.copyWith(progress: valueOf(challenge)) : p,
  ];
}

class ChallengeEntry {
  const ChallengeEntry({required this.challenge, required this.participants, required this.myId});

  final Challenge challenge;
  final List<ChallengeParticipant> participants;
  final String myId;

  ChallengeParticipant? get mine => participants.where((p) => p.userId == myId).firstOrNull;
}

class MyChallenges {
  const MyChallenges({
    this.invites = const [],
    this.active = const [],
    this.upcoming = const [],
    this.finished = const [],
    this.profiles = const {},
  });

  /// Bitmemiş davetlerim.
  final List<ChallengeEntry> invites;

  /// Katıldığım, sürmekte ya da kesinleşmekte olanlar; kendi değerim canlı.
  final List<ChallengeEntry> active;
  final List<ChallengeEntry> upcoming;

  /// Son 10, yeniden eskiye.
  final List<ChallengeEntry> finished;

  /// Katılımcı profilleri (ben dahil).
  final Map<String, PublicProfile> profiles;
}

final myChallengesProvider = FutureProvider.autoDispose<MyChallenges>((ref) async {
  final me = await ref.watch(myPublicProfileProvider.future);
  if (me == null) return const MyChallenges();
  final repo = ref.watch(socialRepositoryProvider);
  final ids = await repo.fetchMyChallengeIds();
  final (challenges, participants) = await (repo.fetchChallenges(ids), repo.fetchParticipants(ids)).wait;
  final (profiles, valueOf) = await (
    repo.fetchProfiles([
      ...{
        for (final list in participants.values)
          for (final p in list) p.userId,
      },
    ]),
    ref.watch(myChallengeValueProvider.future),
  ).wait;
  final now = ref.read(nowProvider)();
  final invites = <ChallengeEntry>[], active = <ChallengeEntry>[], upcoming = <ChallengeEntry>[];
  final finished = <ChallengeEntry>[];
  for (final challenge in challenges) {
    final entry = ChallengeEntry(
      challenge: challenge,
      participants: _withMyLiveValue(challenge, participants[challenge.id] ?? const [], me.userId, now, valueOf),
      myId: me.userId,
    );
    final state = challenge.state(now);
    switch (entry.mine?.status) {
      case ChallengeStatus.invited when state == ChallengeState.upcoming || state == ChallengeState.active:
        invites.add(entry);
      case ChallengeStatus.joined:
        switch (state) {
          case ChallengeState.upcoming:
            upcoming.add(entry);
          case ChallengeState.active || ChallengeState.finalizing:
            active.add(entry);
          case ChallengeState.finished:
            finished.add(entry);
        }
      default:
        break;
    }
  }
  int byEnd(ChallengeEntry a, ChallengeEntry b) => a.challenge.endsAt.compareTo(b.challenge.endsAt);
  invites.sort(byEnd);
  active.sort(byEnd);
  upcoming.sort((a, b) => a.challenge.startsAt.compareTo(b.challenge.startsAt));
  finished.sort((a, b) => byEnd(b, a));
  return MyChallenges(
    invites: invites,
    active: active,
    upcoming: upcoming,
    finished: finished.take(10).toList(),
    profiles: {for (final p in profiles) p.userId: p, me.userId: me},
  );
});

/// Sekme ve alt menü rozeti; veri yoksa 0.
final pendingChallengeInvitesProvider = Provider<int>((ref) {
  return ref.watch(myChallengesProvider).value?.invites.length ?? 0;
});

/// Topluluğun bitmemiş meydan okumaları; değerler sunucudaki yayından.
final communityChallengesProvider =
    FutureProvider.autoDispose.family<List<ChallengeEntry>, String>((ref, communityId) async {
  final me = await ref.watch(myPublicProfileProvider.future);
  if (me == null) return const [];
  final repo = ref.watch(socialRepositoryProvider);
  final ids = await repo.fetchCommunityChallengeIds(communityId);
  final (challenges, participants) = await (repo.fetchChallenges(ids), repo.fetchParticipants(ids)).wait;
  final now = ref.read(nowProvider)();
  return [
    for (final challenge in challenges)
      if (challenge.state(now) != ChallengeState.finished)
        ChallengeEntry(challenge: challenge, participants: participants[challenge.id] ?? const [], myId: me.userId),
  ]..sort((a, b) => a.challenge.endsAt.compareTo(b.challenge.endsAt));
});

class ChallengeDetail {
  const ChallengeDetail({
    required this.challenge,
    required this.participants,
    required this.profiles,
    required this.myId,
    this.community,
  });

  final Challenge challenge;

  /// Kendi değerim aktifken canlı.
  final List<ChallengeParticipant> participants;

  /// Kendi profilim dahil.
  final Map<String, PublicProfile> profiles;
  final String myId;

  /// Topluluk meydan okumasında, görünüyorsa.
  final Community? community;

  ChallengeParticipant? get mine => participants.where((p) => p.userId == myId).firstOrNull;

  /// Topluluk sahibi her zaman; açan, kendisinden başka katılımcı yokken.
  bool get canDelete =>
      community?.owner == myId ||
      (challenge.creator == myId &&
          !participants.any((p) => p.userId != myId && p.status == ChallengeStatus.joined));
}

/// Görmüyorsam (ya da silindiyse) null.
final challengeDetailProvider = FutureProvider.autoDispose.family<ChallengeDetail?, String>((ref, id) async {
  final me = await ref.watch(myPublicProfileProvider.future);
  if (me == null) return null;
  final repo = ref.watch(socialRepositoryProvider);
  final (challenges, participants) = await (repo.fetchChallenges([id]), repo.fetchParticipants([id])).wait;
  final challenge = challenges.firstOrNull;
  if (challenge == null) return null;
  final list = participants[id] ?? const <ChallengeParticipant>[];
  final (profiles, communities, valueOf) = await (
    repo.fetchProfiles([for (final p in list) p.userId]),
    repo.fetchCommunities([?challenge.communityId]),
    ref.watch(myChallengeValueProvider.future),
  ).wait;
  final now = ref.read(nowProvider)();
  return ChallengeDetail(
    challenge: challenge,
    participants: _withMyLiveValue(challenge, list, me.userId, now, valueOf),
    profiles: {for (final p in profiles) p.userId: p, me.userId: me},
    myId: me.userId,
    community: communities.firstOrNull,
  );
});

/// Kesinleşmiş ve kazandığım meydan okumaların XP olayları (S3 spec §3.3). Kimlik yoksa
/// ya da okunamazsa boş: seviye meydan okumasız da hesaplanır.
final challengeRewardsProvider = FutureProvider.autoDispose<List<XpEvent>>((ref) async {
  try {
    final me = await ref.watch(myPublicProfileProvider.future);
    if (me == null) return const [];
    final repo = ref.watch(socialRepositoryProvider);
    final ids = await repo.fetchMyChallengeIds();
    final (challenges, participants) = await (repo.fetchChallenges(ids), repo.fetchParticipants(ids)).wait;
    return challengeRewards(
      me.userId,
      [for (final c in challenges) (c, participants[c.id] ?? const <ChallengeParticipant>[])],
      ref.read(nowProvider)(),
    );
  } catch (e, st) {
    debugPrint('challengeRewards failed: $e\n$st');
    return const [];
  }
});

/// Son yayınlanan değerler (bellekte); aynıysa yeniden yazılmaz.
class LastPublishedChallengeValues extends Notifier<Map<String, double>> {
  @override
  Map<String, double> build() => const {};

  void remember(String id, double value) => state = {...state, id: value};
}

final lastPublishedChallengeValuesProvider =
    NotifierProvider<LastPublishedChallengeValues, Map<String, double>>(LastPublishedChallengeValues.new);

/// Aktif ya da kesinleşme payındaki katılımlarımın değerini yayınlar; yalnız değişeni
/// yazar. `AppShell` izler; hata loglanır.
final challengeSyncProvider = FutureProvider.autoDispose<void>((ref) async {
  final mine = await ref.watch(myChallengesProvider.future);
  final repo = ref.read(socialRepositoryProvider);
  for (final entry in mine.active) {
    final value = entry.mine?.progress;
    if (value == null || ref.read(lastPublishedChallengeValuesProvider)[entry.challenge.id] == value) continue;
    try {
      await repo.publishChallengeProgress(entry.challenge.id, value);
      ref.read(lastPublishedChallengeValuesProvider.notifier).remember(entry.challenge.id, value);
    } catch (e, st) {
      debugPrint('challengeSync failed: $e\n$st');
    }
  }
});

/// Meydan okuma yazma işlemleri; her biri ilgili sağlayıcıları yeniler.
class ChallengeActions {
  ChallengeActions(this._ref);

  final Ref _ref;

  SocialRepository get _repo => _ref.read(socialRepositoryProvider);

  void _refresh(String id, String? communityId) {
    _ref.invalidate(myChallengesProvider);
    _ref.invalidate(challengeDetailProvider(id));
    if (communityId != null) _ref.invalidate(communityChallengesProvider(communityId));
  }

  Future<String> create(ChallengeDraft draft) async {
    final id = await _repo.createChallenge(draft);
    _refresh(id, draft.communityId);
    return id;
  }

  Future<void> respond(Challenge challenge, {required bool accept}) async {
    await _repo.respondChallenge(challenge.id, accept: accept);
    _refresh(challenge.id, challenge.communityId);
  }

  Future<void> join(Challenge challenge) async {
    await _repo.joinChallenge(challenge.id);
    _refresh(challenge.id, challenge.communityId);
  }

  Future<void> leave(Challenge challenge) async {
    await _repo.leaveChallenge(challenge.id);
    _refresh(challenge.id, challenge.communityId);
  }

  Future<void> delete(Challenge challenge) async {
    await _repo.deleteChallenge(challenge.id);
    _refresh(challenge.id, challenge.communityId);
  }
}

final challengeActionsProvider = Provider<ChallengeActions>(ChallengeActions.new);
```

- [ ] **Step 6: Testin geçtiğini gör**

Run: `flutter test --no-pub -j 1 test/features/social/application/challenge_providers_test.dart`
Expected: PASS (8 test). Sıralama farkı çıkarsa (`active` ch1/cm): ikisinin de bitişi 14 Ekim'dir; `byEnd` eşitliği kararsızsa `byEnd`'e `a.challenge.id.compareTo(b.challenge.id)` ikincil anahtarını ekle.

- [ ] **Step 7: Ödülleri özete, senkronu ve rozeti kabuğa bağla**

`lib/features/gamification/application/gamification_providers.dart`:

```dart
import '../../social/application/challenge_providers.dart';
```

ve sağlayıcıyı değiştir:

```dart
/// Tüm geçmişten XP, seviye, rütbe ve unvanlar (O1 spec §7) + meydan okuma ödülleri
/// (S3 spec §3.3). Antrenman bitince `allSessionsProvider`, öğün kaydedilince
/// `mealTimesProvider` geçersiz kılınır.
final playerSummaryProvider = FutureProvider.autoDispose<PlayerSummary>((ref) async {
  final (sessions, mealTimes, exercisesById, rewards) = await (
    ref.watch(allSessionsProvider.future),
    ref.watch(mealTimesProvider.future),
    ref.watch(exercisesByIdProvider.future),
    ref.watch(challengeRewardsProvider.future),
  ).wait;
  return playerSummary(sessions, mealTimes, exercisesById, rewards: rewards);
});
```

`test/features/gamification/application/gamification_providers_test.dart` — `_container` override listesine ekle (ve import):

```dart
import 'package:spor_takip/features/social/application/challenge_providers.dart';
...
    challengeRewardsProvider.overrideWith((ref) async => const []),
```

`lib/core/app_shell.dart`:

```dart
import '../features/social/application/challenge_providers.dart';
```

`build` başını değiştir:

```dart
    // Kabuk açıkken oyuncu özeti (S1 spec §6.1) ve meydan okuma değerlerim (S3) yayınlanır.
    ref.watch(statsSyncProvider);
    ref.watch(challengeSyncProvider);
    final requests = ref.watch(incomingRequestCountProvider) + ref.watch(pendingChallengeInvitesProvider);
```

`test/core/app_shell_test.dart` — import ve override'lar:

```dart
import 'package:spor_takip/features/social/application/challenge_providers.dart';
...
          challengeSyncProvider.overrideWith((ref) async {}),
          pendingChallengeInvitesProvider.overrideWithValue(0),
```

- [ ] **Step 8: İlgili testlerin geçtiğini gör**

Run: `flutter test --no-pub -j 1 test/features/gamification/application/gamification_providers_test.dart test/core/app_shell_test.dart test/features/social/application`
Expected: PASS.

- [ ] **Step 9: Commit**

```bash
git add lib/features/social/data/social_repository.dart lib/features/social/application/challenge_providers.dart lib/features/gamification/application/gamification_providers.dart lib/core/app_shell.dart test/features/social/fakes.dart test/features/social/application/challenge_providers_test.dart test/features/gamification/application/gamification_providers_test.dart test/core/app_shell_test.dart
git commit -m "feat(social): add challenge data, providers, progress sync and XP rewards

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 5: Çeviriler, metin yardımcıları, kartlar ve oluşturma sayfası

**Files:**
- Modify: `assets/translations/tr.json`, `assets/translations/en.json` (üst düzey `challenge`)
- Create: `lib/features/social/presentation/widgets/challenge_labels.dart`
- Create: `lib/features/social/presentation/widgets/challenge_cards.dart`
- Create: `lib/features/social/presentation/create_challenge_sheet.dart`
- Test: `test/features/social/presentation/create_challenge_sheet_test.dart`

**Interfaces:**
- Consumes: Task 2 domain, Task 4 sağlayıcılar, `socialOverviewProvider`, `SocialAvatar`, `formatSets`, `taxonomySlug`, `muscleGroups`, `upperCaseFor`.
- Produces:
  - `challenge_labels.dart`: `String challengeMetricLabel(ChallengeMetric)`, `String challengeMuscleLabel(String)`, `String challengeNumber(ChallengeMetric, double)`, `String challengeValueLabel(ChallengeMetric, double)`, `String challengeAutoName({required ChallengeKind kind, required ChallengeMetric metric, String? muscle, double? target, required int days})`, `String challengeDateLabel(DateTime, {bool withTime = false})`, `String challengeTimeLabel(Challenge, DateTime now)`, `String challengeResultLabel(Challenge, List<ChallengeParticipant>, String myId, DateTime now)`, `Future<bool> runChallengeAction(BuildContext, Future<void> Function())`
  - `challenge_cards.dart`: `ChallengeChips({required Challenge challenge})`, `ChallengeInviteCard({required ChallengeEntry entry, PublicProfile? creator})`, `ChallengeActiveCard({required ChallengeEntry entry, required Map<String, PublicProfile> profiles, required DateTime now})`, `ChallengeCompactRow({required ChallengeEntry entry, required DateTime now, Widget? trailing})`
  - `Future<String?> showCreateChallengeSheet(BuildContext context, {String? communityId, String? friendId})`, `CreateChallengeSheet`
  - Anahtarlar: `challenge_form`, `challenge_kind_<race|goal>`, `challenge_metric_<metric>`, `challenge_muscle`, `challenge_target`, `challenge_days_<n>`, `challenge_start_<now|tomorrow>`, `challenge_name`, `challenge_invite_<userId>`, `challenge_form_error`, `challenge_form_save`; kartlarda `challenge_invite_card_<id>`, `challenge_accept_<id>`, `challenge_decline_<id>`, `challenge_active_<id>`, `challenge_position_<id>`, `challenge_leader_<id>`, `challenge_goal_<id>`, `challenge_time_<id>`, `challenge_item_<id>`.

- [ ] **Step 1: `challenge` çevirilerini ekle**

Proje kökünde çalıştır:

```bash
python - <<'EOF'
import json, pathlib
tr = {
  "tab": "Meydan okumalar",
  "invites": "Davetler",
  "active": "Aktif",
  "active_empty": "Aktif meydan okuman yok.",
  "upcoming": "Başlamadı",
  "finished": "Biten",
  "need_friends": "Meydan okumak için önce arkadaş ekle.",
  "new": "Yeni meydan okuma",
  "new_title": "Yeni meydan okuma",
  "invited_by": "{name} seni meydan okumaya davet etti",
  "accept": "Kabul",
  "decline": "Reddet",
  "join": "Katıl",
  "position_of": "/ {n}",
  "leader": "Lider: {name} ({value})",
  "goal_progress": "{value} / {target}",
  "kind": {"race": "Yarış", "goal": "Hedef"},
  "kind_note": {"race": "Süre sonunda en yüksek değer kazanır", "goal": "Süre içinde hedefe ulaşan herkes başarır"},
  "metric_label": "Ölçü",
  "metric": {"workouts": "Antrenman", "sets": "Set", "xp": "XP", "volume": "Hacim (kg)"},
  "metric_noun": {"workouts": "antrenman", "sets": "set", "xp": "XP", "volume": "hacim"},
  "value": {"workouts": "{n} antrenman", "sets": "{n} set", "xp": "{n} XP", "volume": "{n} kg"},
  "unit": {"workouts": "antrenman", "sets": "set", "xp": "XP", "volume": "kg"},
  "muscle_label": "Kas",
  "muscle_all": "Tümü",
  "target_label": "Hedef",
  "duration_label": "Süre",
  "days": "{n} gün",
  "start_label": "Başlangıç",
  "start": {"now": "Hemen", "tomorrow": "Yarın 00:00"},
  "name_label": "Ad (isteğe bağlı)",
  "invite_label": "Arkadaşları davet et · {n}/{max}",
  "start_button": "Meydan okumayı başlat",
  "auto_race": "{days} günde en çok {metric}",
  "auto_goal": "{days} günde {value}",
  "auto_muscle": "{name} · {muscle}",
  "starts_at": "Başlangıç: {date}",
  "finalizing": "Kesinleşiyor",
  "ended": "Bitti",
  "result_won": "Kazandın · +{xp} XP",
  "result_goal": "Başardın · +{xp} XP",
  "result_position": "{n}. oldun",
  "result_missed": "Hedefe ulaşamadın",
  "result_none": "Kazanan yok",
  "title": "Meydan okuma",
  "gone": "Bu meydan okuma artık yok.",
  "standings": "Sıralama",
  "standings_empty": "Henüz katılan yok.",
  "me": "Sen",
  "pending": "Bekleyen davet: {names}",
  "participants_by": "{n} katılımcı · açan {name}",
  "target": "Hedef: {value}",
  "reward_race": "Birinci +{xp} XP",
  "reward_goal": "Hedefe ulaşan herkese +{xp} XP",
  "reward_title": "Meydan Okuma unvanına sayılır",
  "leave": "Ayrıl",
  "delete": "Sil",
  "leave_confirm": "Meydan okumadan ayrılmak istiyor musun? İlerlemen silinir.",
  "delete_confirm": "Meydan okuma herkes için silinecek. Emin misin?",
  "confirm": "Evet",
  "community_title": "Meydan okumalar",
  "community_empty": "Toplulukta aktif meydan okuma yok.",
  "community_new": "Meydan okuma aç",
  "challenge_friend": "Meydan oku",
  "error": {
    "challenge_limit": "En çok 5 aktif meydan okumada bulunabilirsin.",
    "community_challenge_limit": "Toplulukta aynı anda en çok 3 meydan okuma olabilir.",
    "not_friend": "Yalnız arkadaşlarını davet edebilirsin.",
    "not_member": "Bu topluluğun üyesi değilsin.",
    "challenge_closed": "Bu meydan okuma sona erdi.",
    "invalid_challenge": "Meydan okuma bilgileri geçersiz.",
    "not_allowed": "Bunu yapmaya yetkin yok.",
    "no_profile": "Önce sosyal kimliğini oluştur."
  }
}
en = {
  "tab": "Challenges",
  "invites": "Invites",
  "active": "Active",
  "active_empty": "You have no active challenges.",
  "upcoming": "Not started",
  "finished": "Finished",
  "need_friends": "Add a friend first to challenge them.",
  "new": "New challenge",
  "new_title": "New challenge",
  "invited_by": "{name} challenged you",
  "accept": "Accept",
  "decline": "Decline",
  "join": "Join",
  "position_of": "/ {n}",
  "leader": "Leader: {name} ({value})",
  "goal_progress": "{value} / {target}",
  "kind": {"race": "Race", "goal": "Goal"},
  "kind_note": {"race": "Highest value at the end wins", "goal": "Everyone who reaches the goal in time succeeds"},
  "metric_label": "Metric",
  "metric": {"workouts": "Workouts", "sets": "Sets", "xp": "XP", "volume": "Volume (kg)"},
  "metric_noun": {"workouts": "workouts", "sets": "sets", "xp": "XP", "volume": "volume"},
  "value": {"workouts": "{n} workouts", "sets": "{n} sets", "xp": "{n} XP", "volume": "{n} kg"},
  "unit": {"workouts": "workouts", "sets": "sets", "xp": "XP", "volume": "kg"},
  "muscle_label": "Muscle",
  "muscle_all": "All",
  "target_label": "Goal",
  "duration_label": "Duration",
  "days": "{n} days",
  "start_label": "Start",
  "start": {"now": "Now", "tomorrow": "Tomorrow 00:00"},
  "name_label": "Name (optional)",
  "invite_label": "Invite friends · {n}/{max}",
  "start_button": "Start the challenge",
  "auto_race": "Most {metric} in {days} days",
  "auto_goal": "{value} in {days} days",
  "auto_muscle": "{name} · {muscle}",
  "starts_at": "Starts: {date}",
  "finalizing": "Finalizing",
  "ended": "Ended",
  "result_won": "You won · +{xp} XP",
  "result_goal": "Goal reached · +{xp} XP",
  "result_position": "You finished #{n}",
  "result_missed": "Goal missed",
  "result_none": "No winner",
  "title": "Challenge",
  "gone": "This challenge no longer exists.",
  "standings": "Standings",
  "standings_empty": "Nobody has joined yet.",
  "me": "You",
  "pending": "Pending invite: {names}",
  "participants_by": "{n} participants · by {name}",
  "target": "Goal: {value}",
  "reward_race": "Winner +{xp} XP",
  "reward_goal": "+{xp} XP for everyone who reaches the goal",
  "reward_title": "Counts toward the Challenge title",
  "leave": "Leave",
  "delete": "Delete",
  "leave_confirm": "Leave this challenge? Your progress is removed.",
  "delete_confirm": "The challenge will be deleted for everyone. Are you sure?",
  "confirm": "Yes",
  "community_title": "Challenges",
  "community_empty": "No active challenges in this community.",
  "community_new": "Start a challenge",
  "challenge_friend": "Challenge",
  "error": {
    "challenge_limit": "You can be in at most 5 active challenges.",
    "community_challenge_limit": "A community can have at most 3 challenges at a time.",
    "not_friend": "You can only invite your friends.",
    "not_member": "You are not a member of this community.",
    "challenge_closed": "This challenge has ended.",
    "invalid_challenge": "The challenge details are invalid.",
    "not_allowed": "You are not allowed to do that.",
    "no_profile": "Create your social profile first."
  }
}
for lang, keys in (("tr", tr), ("en", en)):
    path = pathlib.Path(f"assets/translations/{lang}.json")
    text = path.read_text(encoding="utf-8")
    newline = "\r\n" if "\r\n" in text else "\n"
    data = json.loads(text)
    data["challenge"] = keys
    out = json.dumps(data, ensure_ascii=False, indent=2).replace("\n", newline) + newline
    path.write_text(out, encoding="utf-8", newline="")
    print(lang, "tamam")
EOF
```

- [ ] **Step 2: Metin yardımcılarını yaz**

`lib/features/social/presentation/widgets/challenge_labels.dart`:

```dart
import 'dart:math' as math;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../workout/domain/exercise_taxonomy.dart';
import '../../../workout/domain/muscle_heat.dart';
import '../../domain/challenge.dart';
import '../../domain/challenge_results.dart';

String challengeMetricLabel(ChallengeMetric metric) => 'challenge.metric.${metric.name}'.tr();

String challengeMuscleLabel(String muscle) => 'gamification.muscle_short.${taxonomySlug(muscle)}'.tr();

/// Set bir ondalık ("18.5"), diğerleri tamsayı.
String challengeNumber(ChallengeMetric metric, double value) =>
    metric == ChallengeMetric.sets ? formatSets(value) : '${value.round()}';

/// "18.5 set", "2700 kg", "85 XP", "3 antrenman".
String challengeValueLabel(ChallengeMetric metric, double value) =>
    'challenge.value.${metric.name}'.tr(namedArgs: {'n': challengeNumber(metric, value)});

/// Ad boşsa (S3 spec §3.4); en çok 60 karakter.
String challengeAutoName({
  required ChallengeKind kind,
  required ChallengeMetric metric,
  String? muscle,
  double? target,
  required int days,
}) {
  final base = kind == ChallengeKind.race
      ? 'challenge.auto_race'.tr(namedArgs: {'days': '$days', 'metric': 'challenge.metric_noun.${metric.name}'.tr()})
      : 'challenge.auto_goal'.tr(namedArgs: {'days': '$days', 'value': challengeValueLabel(metric, target ?? 0)});
  final name =
      muscle == null ? base : 'challenge.auto_muscle'.tr(namedArgs: {'name': base, 'muscle': challengeMuscleLabel(muscle)});
  return name.length > 60 ? name.substring(0, 60) : name;
}

/// "10 Ekim", saatle "10 Ekim 00:00".
String challengeDateLabel(DateTime date, {bool withTime = false}) {
  final local = date.toLocal();
  final day = '${local.day} ${'home.month_${local.month}'.tr()}';
  if (!withTime) return day;
  return '$day ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
}

/// Başlamadıysa başlangıç, sürüyorsa kalan süre, sonra "Kesinleşiyor" / "Bitti".
String challengeTimeLabel(Challenge challenge, DateTime now) => switch (challenge.state(now)) {
      ChallengeState.upcoming =>
        'challenge.starts_at'.tr(namedArgs: {'date': challengeDateLabel(challenge.startsAt, withTime: true)}),
      ChallengeState.active => _remaining(challenge.endsAt.difference(now)),
      ChallengeState.finalizing => 'challenge.finalizing'.tr(),
      ChallengeState.finished => 'challenge.ended'.tr(),
    };

String _remaining(Duration left) {
  final hours = math.max(1, (left.inMinutes / 60).ceil());
  return hours < 24
      ? 'social.period_remaining_hours'.tr(namedArgs: {'n': '$hours'})
      : 'social.period_remaining_days'.tr(namedArgs: {'n': '${(hours / 24).ceil()}'});
}

/// Biten meydan okumada benim sonucum.
String challengeResultLabel(
  Challenge challenge,
  List<ChallengeParticipant> participants,
  String myId,
  DateTime now,
) {
  final winners = challengeWinners(challenge, participants, now);
  final xp = '${challengeRewardXp(challenge.kind)}';
  if (winners.contains(myId)) {
    return (challenge.kind == ChallengeKind.race ? 'challenge.result_won' : 'challenge.result_goal')
        .tr(namedArgs: {'xp': xp});
  }
  if (challenge.kind == ChallengeKind.goal) return 'challenge.result_missed'.tr();
  if (winners.isEmpty) return 'challenge.result_none'.tr();
  final mine = challengeStandings(challenge, participants).where((r) => r.userId == myId).firstOrNull;
  return mine == null
      ? 'challenge.result_none'.tr()
      : 'challenge.result_position'.tr(namedArgs: {'n': '${mine.position}'});
}

/// İşlemi çalıştırır; hata kodunu ya da genel hatayı SnackBar'la bildirir. Başarıda true.
Future<bool> runChallengeAction(BuildContext context, Future<void> Function() action) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    await action();
    return true;
  } on ChallengeException catch (e) {
    messenger.showSnackBar(SnackBar(content: Text('challenge.error.${e.code}'.tr())));
  } catch (e, st) {
    debugPrint('challenge action failed: $e\n$st');
    messenger.showSnackBar(SnackBar(content: Text('social.action_error'.tr())));
  }
  return false;
}
```

- [ ] **Step 3: Kartları yaz**

`lib/features/social/presentation/widgets/challenge_cards.dart`:

```dart
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../application/challenge_providers.dart';
import '../../domain/challenge.dart';
import '../../domain/challenge_results.dart';
import '../../domain/public_profile.dart';
import 'challenge_labels.dart';
import 'social_avatar.dart';

void _open(BuildContext context, Challenge challenge) => context.push('/social/challenge/${challenge.id}');

/// Tür · ölçü · kas · süre hapları; satır taşarsa alta sarılır.
class ChallengeChips extends StatelessWidget {
  const ChallengeChips({super.key, required this.challenge});

  final Challenge challenge;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    Widget pill(String text, {bool accent = false}) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: accent ? scheme.primary.withValues(alpha: 0.15) : scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: accent ? scheme.primary : scheme.outlineVariant),
          ),
          child: Text(
            text,
            style: theme.textTheme.labelMedium?.copyWith(
              color: accent ? scheme.primary : scheme.onSurface,
              fontWeight: FontWeight.w700,
            ),
          ),
        );
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        pill('challenge.kind.${challenge.kind.name}'.tr(), accent: true),
        pill(challengeMetricLabel(challenge.metric)),
        if (challenge.muscle case final muscle?) pill(challengeMuscleLabel(muscle)),
        pill('challenge.days'.tr(namedArgs: {'n': '${challenge.days}'})),
      ],
    );
  }
}

/// Davet kartı: açan, ad, haplar, Kabul / Reddet.
class ChallengeInviteCard extends ConsumerWidget {
  const ChallengeInviteCard({super.key, required this.entry, this.creator});

  final ChallengeEntry entry;
  final PublicProfile? creator;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final challenge = entry.challenge;
    final actions = ref.read(challengeActionsProvider);
    return Card(
      key: Key('challenge_invite_card_${challenge.id}'),
      margin: const EdgeInsets.only(bottom: 8),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _open(context, challenge),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  SocialAvatar(initials: creator?.initials ?? '?', size: 40),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'challenge.invited_by'.tr(namedArgs: {'name': creator?.displayName ?? '?'}),
                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(challenge.name, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              ChallengeChips(challenge: challenge),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      key: Key('challenge_accept_${challenge.id}'),
                      onPressed: () => runChallengeAction(context, () => actions.respond(challenge, accept: true)),
                      child: Text('challenge.accept'.tr()),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      key: Key('challenge_decline_${challenge.id}'),
                      onPressed: () => runChallengeAction(context, () => actions.respond(challenge, accept: false)),
                      child: Text('challenge.decline'.tr()),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Aktif kart: yarışta sıram + lider + çubuk, hedefte ilerleme + yüzde.
class ChallengeActiveCard extends StatelessWidget {
  const ChallengeActiveCard({super.key, required this.entry, required this.profiles, required this.now});

  final ChallengeEntry entry;
  final Map<String, PublicProfile> profiles;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final muted = TextStyle(color: scheme.onSurfaceVariant);
    final challenge = entry.challenge;
    final rows = challengeStandings(
      challenge,
      entry.participants,
      names: {for (final MapEntry(key: id, value: p) in profiles.entries) id: p.displayName},
    );
    final mine = rows.where((r) => r.userId == entry.myId).firstOrNull;
    final myValue = mine?.value ?? 0;
    final bar = switch (challenge.kind) {
      ChallengeKind.race => rows.isEmpty || rows.first.value <= 0 ? 0.0 : (myValue / rows.first.value).clamp(0.0, 1.0),
      ChallengeKind.goal => (myValue / (challenge.target ?? 1)).clamp(0.0, 1.0),
    };
    return Card(
      key: Key('challenge_active_${challenge.id}'),
      margin: const EdgeInsets.only(bottom: 8),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _open(context, challenge),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (challenge.isCommunity) ...[
                    Icon(Icons.groups, size: 18, color: scheme.primary),
                    const SizedBox(width: 6),
                  ],
                  Expanded(child: Text('challenge.kind.${challenge.kind.name}'.tr(), style: TextStyle(color: scheme.primary))),
                  Text(challengeTimeLabel(challenge, now), key: Key('challenge_time_${challenge.id}'), style: muted),
                ],
              ),
              const SizedBox(height: 6),
              Text(challenge.name, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              if (challenge.kind == ChallengeKind.race) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      mine == null ? '—' : '${mine.position}.',
                      key: Key('challenge_position_${challenge.id}'),
                      style: theme.textTheme.headlineSmall?.copyWith(color: scheme.primary, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(width: 4),
                    Text('challenge.position_of'.tr(namedArgs: {'n': '${rows.length}'}), style: muted),
                    const Spacer(),
                    Text(
                      challengeValueLabel(challenge.metric, myValue),
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
                if (rows.isNotEmpty && rows.first.userId != entry.myId)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'challenge.leader'.tr(namedArgs: {
                        'name': profiles[rows.first.userId]?.displayName ?? '?',
                        'value': challengeValueLabel(challenge.metric, rows.first.value),
                      }),
                      key: Key('challenge_leader_${challenge.id}'),
                      style: muted,
                    ),
                  ),
              ] else
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'challenge.goal_progress'.tr(namedArgs: {
                          'value': challengeNumber(challenge.metric, myValue),
                          'target': challengeValueLabel(challenge.metric, challenge.target ?? 0),
                        }),
                        key: Key('challenge_goal_${challenge.id}'),
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ),
                    Text('%${(bar * 100).round()}', style: TextStyle(color: scheme.primary, fontWeight: FontWeight.w800)),
                  ],
                ),
              const SizedBox(height: 8),
              LinearProgressIndicator(value: bar, minHeight: 6, borderRadius: BorderRadius.circular(3)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Başlamamış, biten ya da topluluk satırı: ikon, ad, zaman ya da sonuç.
class ChallengeCompactRow extends StatelessWidget {
  const ChallengeCompactRow({super.key, required this.entry, required this.now, this.trailing});

  final ChallengeEntry entry;
  final DateTime now;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final challenge = entry.challenge;
    final state = challenge.state(now);
    final finished = state == ChallengeState.finished;
    final won = finished && challengeWinners(challenge, entry.participants, now).contains(entry.myId);
    return Card(
      key: Key('challenge_item_${challenge.id}'),
      margin: const EdgeInsets.only(bottom: 8),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        onTap: () => _open(context, challenge),
        leading: Icon(
          won
              ? Icons.emoji_events
              : state == ChallengeState.upcoming
                  ? Icons.event
                  : Icons.flag_outlined,
          color: won ? scheme.primary : scheme.onSurfaceVariant,
        ),
        title: Text(challenge.name, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          finished
              ? challengeResultLabel(challenge, entry.participants, entry.myId, now)
              : challengeTimeLabel(challenge, now),
        ),
        trailing: trailing ?? const Icon(Icons.chevron_right),
      ),
    );
  }
}
```

- [ ] **Step 4: Oluşturma sayfası testini yaz**

`test/features/social/presentation/create_challenge_sheet_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spor_takip/features/social/application/social_providers.dart';
import 'package:spor_takip/features/social/domain/challenge.dart';
import 'package:spor_takip/features/social/presentation/create_challenge_sheet.dart';
import 'package:spor_takip/features/workout/application/session_providers.dart';

import '../../progress/presentation/test_app.dart';
import '../fakes.dart';
import '../social_fixtures.dart';

void main() {
  setUpAll(initTestLocalization);
  setUp(() => SharedPreferences.setMockInitialValues({}));

  FakeSocialRepository repo() => FakeSocialRepository(
        me: socialMe,
        others: [socialAyse, socialBurak],
        friendships: [socialFriendship('me', 'ayse'), socialFriendship('burak', 'me')],
      );

  Future<void> pump(WidgetTester tester, FakeSocialRepository repo, {String? communityId, String? friendId}) async {
    tester.view.physicalSize = const Size(360, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(testApp(
      CreateChallengeSheet(communityId: communityId, friendId: friendId),
      scaffold: true,
      overrides: [
        socialRepositoryProvider.overrideWithValue(repo),
        nowProvider.overrideWithValue(() => DateTime(2026, 10, 9, 12)),
      ],
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('a friend race sends the chosen metric, muscle, window and invitees', (tester) async {
    final fake = repo();
    await pump(tester, fake, friendId: 'ayse');
    expect(find.byKey(const Key('challenge_muscle')), findsNothing);
    expect(find.byKey(const Key('challenge_target')), findsNothing);

    await tester.tap(find.byKey(const Key('challenge_metric_sets')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('challenge_muscle')), findsOneWidget);
    await tester.tap(find.byKey(const Key('challenge_muscle')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('gamification.muscle_short.lats').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('challenge_days_3')));
    await tester.tap(find.byKey(const Key('challenge_start_tomorrow')));
    await tester.tap(find.byKey(const Key('challenge_invite_burak')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('challenge_form_save')));
    await tester.tap(find.byKey(const Key('challenge_form_save')));
    await tester.pumpAndSettle();

    final draft = fake.createdChallenges.single;
    expect((draft.kind, draft.metric, draft.muscle, draft.target), (ChallengeKind.race, ChallengeMetric.sets, 'lats', null));
    expect((draft.startsAt, draft.endsAt), (DateTime(2026, 10, 10), DateTime(2026, 10, 13)));
    expect(draft.invitees, ['ayse', 'burak']);
    expect(draft.communityId, isNull);
    expect(draft.name, 'challenge.auto_muscle');
  });

  testWidgets('a goal needs a target; the save button waits for it', (tester) async {
    final fake = repo();
    await pump(tester, fake, friendId: 'ayse');
    await tester.tap(find.byKey(const Key('challenge_kind_goal')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('challenge_form_save')));
    expect(tester.widget<FilledButton>(find.byKey(const Key('challenge_form_save'))).onPressed, isNull);

    await tester.enterText(find.byKey(const Key('challenge_target')), '4');
    await tester.enterText(find.byKey(const Key('challenge_name')), 'Bu hafta 4 antrenman');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('challenge_form_save')));
    await tester.pumpAndSettle();
    final draft = fake.createdChallenges.single;
    expect((draft.kind, draft.metric, draft.target, draft.name),
        (ChallengeKind.goal, ChallengeMetric.workouts, 4.0, 'Bu hafta 4 antrenman'));
    expect((draft.startsAt, draft.endsAt), (DateTime(2026, 10, 9, 12), DateTime(2026, 10, 16, 12)));
  });

  testWidgets('in community mode there is no invite list and the community id is sent', (tester) async {
    final fake = repo();
    await pump(tester, fake, communityId: 'c1');
    expect(find.byKey(const Key('challenge_invite_ayse')), findsNothing);
    await tester.ensureVisible(find.byKey(const Key('challenge_form_save')));
    await tester.tap(find.byKey(const Key('challenge_form_save')));
    await tester.pumpAndSettle();
    expect(fake.createdChallenges.single.communityId, 'c1');
    expect(fake.createdChallenges.single.invitees, isEmpty);
  });

  testWidgets('a friend challenge needs an invitee; a server error shows inside the sheet', (tester) async {
    final fake = repo()..challengeError = const ChallengeException('challenge_limit');
    await pump(tester, fake);
    await tester.ensureVisible(find.byKey(const Key('challenge_form_save')));
    expect(tester.widget<FilledButton>(find.byKey(const Key('challenge_form_save'))).onPressed, isNull);

    await tester.tap(find.byKey(const Key('challenge_invite_ayse')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('challenge_form_save')));
    await tester.tap(find.byKey(const Key('challenge_form_save')));
    await tester.pumpAndSettle();
    expect(find.text('challenge.error.challenge_limit'), findsOneWidget);
  });
}
```

- [ ] **Step 5: Testin yüklenemediğini gör**

Run: `flutter test --no-pub -j 1 test/features/social/presentation/create_challenge_sheet_test.dart`
Expected: FAIL — `create_challenge_sheet.dart` yok.

- [ ] **Step 6: Oluşturma sayfasını yaz**

`lib/features/social/presentation/create_challenge_sheet.dart`:

```dart
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_fonts.dart';
import '../../../shared/text_case.dart';
import '../../workout/application/session_providers.dart';
import '../../workout/domain/exercise_taxonomy.dart';
import '../application/challenge_providers.dart';
import '../application/social_providers.dart';
import '../domain/challenge.dart';
import '../domain/challenge_progress.dart';
import 'widgets/challenge_labels.dart';
import 'widgets/social_avatar.dart';

/// Meydan okuma kurar (S3 spec §7.3). [communityId] verilirse topluluk kipinde (davet
/// listesi yok); [friendId] önceden seçili arkadaş. Kurulunca yeni kimliği döndürür.
Future<String?> showCreateChallengeSheet(BuildContext context, {String? communityId, String? friendId}) =>
    showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => CreateChallengeSheet(communityId: communityId, friendId: friendId),
    );

class CreateChallengeSheet extends ConsumerStatefulWidget {
  const CreateChallengeSheet({super.key, this.communityId, this.friendId});

  final String? communityId;
  final String? friendId;

  @override
  ConsumerState<CreateChallengeSheet> createState() => _CreateChallengeSheetState();
}

class _CreateChallengeSheetState extends ConsumerState<CreateChallengeSheet> {
  final _target = TextEditingController();
  final _name = TextEditingController();
  ChallengeKind _kind = ChallengeKind.race;
  ChallengeMetric _metric = ChallengeMetric.workouts;
  String? _muscle;
  int _days = 7;
  ChallengeStart _start = ChallengeStart.now;
  late final Set<String> _invitees = {?widget.friendId};
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _target.dispose();
    _name.dispose();
    super.dispose();
  }

  bool get _community => widget.communityId != null;
  bool get _hasMuscle => _metric == ChallengeMetric.sets || _metric == ChallengeMetric.volume;
  double? get _targetValue => double.tryParse(_target.text.trim().replaceAll(',', '.'));
  bool get _valid => (_kind == ChallengeKind.race || (_targetValue ?? 0) > 0) && (_community || _invitees.isNotEmpty);

  String get _autoName => challengeAutoName(
        kind: _kind,
        metric: _metric,
        muscle: _hasMuscle ? _muscle : null,
        target: _targetValue,
        days: _days,
      );

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    final navigator = Navigator.of(context);
    final window = challengeWindow(_start, _days, ref.read(nowProvider)());
    final typed = _name.text.trim();
    final invitees = [..._invitees]..sort();
    try {
      final id = await ref.read(challengeActionsProvider).create(ChallengeDraft(
            name: typed.isEmpty ? _autoName : typed,
            kind: _kind,
            metric: _metric,
            muscle: _hasMuscle ? _muscle : null,
            target: _kind == ChallengeKind.goal ? _targetValue : null,
            startsAt: window.startsAt,
            endsAt: window.endsAt,
            communityId: widget.communityId,
            invitees: _community ? const [] : invitees,
          ));
      navigator.pop(id);
    } on ChallengeException catch (e) {
      if (mounted) setState(() => _error = 'challenge.error.${e.code}'.tr());
    } catch (e, st) {
      debugPrint('create challenge failed: $e\n$st');
      if (mounted) setState(() => _error = 'social.action_error'.tr());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final lang = context.locale.languageCode;
    final friends = _community
        ? const <FriendEntry>[]
        : ref.watch(socialOverviewProvider).value?.friends ?? const <FriendEntry>[];
    Widget label(String text) => Padding(
          padding: const EdgeInsets.only(top: 16, bottom: 8),
          child: Text(
            upperCaseFor(text, lang),
            style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w800, letterSpacing: 1),
          ),
        );
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        key: const Key('challenge_form'),
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              upperCaseFor('challenge.new_title'.tr(), lang),
              style: theme.textTheme.titleLarge?.copyWith(fontFamily: AppFonts.heading, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 16),
            SegmentedButton<ChallengeKind>(
              showSelectedIcon: false,
              segments: [
                for (final kind in ChallengeKind.values)
                  ButtonSegment(
                    value: kind,
                    label: Text('challenge.kind.${kind.name}'.tr(), key: Key('challenge_kind_${kind.name}')),
                  ),
              ],
              selected: {_kind},
              onSelectionChanged: (selection) => setState(() => _kind = selection.first),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'challenge.kind_note.${_kind.name}'.tr(),
                style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ),
            label('challenge.metric_label'.tr()),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final metric in ChallengeMetric.values)
                  ChoiceChip(
                    key: Key('challenge_metric_${metric.name}'),
                    label: Text(challengeMetricLabel(metric)),
                    selected: _metric == metric,
                    onSelected: (_) => setState(() {
                      _metric = metric;
                      if (!_hasMuscle) _muscle = null;
                    }),
                  ),
              ],
            ),
            if (_hasMuscle)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: DropdownButtonFormField<String?>(
                  key: const Key('challenge_muscle'),
                  initialValue: _muscle,
                  decoration: InputDecoration(labelText: 'challenge.muscle_label'.tr()),
                  items: [
                    DropdownMenuItem(value: null, child: Text('challenge.muscle_all'.tr())),
                    for (final muscle in muscleGroups)
                      DropdownMenuItem(value: muscle, child: Text(challengeMuscleLabel(muscle))),
                  ],
                  onChanged: (value) => setState(() => _muscle = value),
                ),
              ),
            if (_kind == ChallengeKind.goal)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: TextField(
                  key: const Key('challenge_target'),
                  controller: _target,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'challenge.target_label'.tr(),
                    suffixText: 'challenge.unit.${_metric.name}'.tr(),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
            label('challenge.duration_label'.tr()),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final days in challengeDurations)
                  ChoiceChip(
                    key: Key('challenge_days_$days'),
                    label: Text('challenge.days'.tr(namedArgs: {'n': '$days'})),
                    selected: _days == days,
                    onSelected: (_) => setState(() => _days = days),
                  ),
              ],
            ),
            label('challenge.start_label'.tr()),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final start in ChallengeStart.values)
                  ChoiceChip(
                    key: Key('challenge_start_${start.name}'),
                    label: Text('challenge.start.${start.name}'.tr()),
                    selected: _start == start,
                    onSelected: (_) => setState(() => _start = start),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              key: const Key('challenge_name'),
              controller: _name,
              maxLength: 60,
              decoration: InputDecoration(labelText: 'challenge.name_label'.tr(), hintText: _autoName),
            ),
            if (!_community) ...[
              label('challenge.invite_label'
                  .tr(namedArgs: {'n': '${_invitees.length}', 'max': '$maxChallengeInvitees'})),
              for (final friend in friends)
                CheckboxListTile(
                  key: Key('challenge_invite_${friend.profile.userId}'),
                  contentPadding: EdgeInsets.zero,
                  secondary: SocialAvatar(initials: friend.profile.initials, size: 40),
                  title: Text(friend.profile.displayName),
                  value: _invitees.contains(friend.profile.userId),
                  onChanged: (checked) => setState(() {
                    if (checked != true) {
                      _invitees.remove(friend.profile.userId);
                    } else if (_invitees.length < maxChallengeInvitees) {
                      _invitees.add(friend.profile.userId);
                    }
                  }),
                ),
            ],
            if (_error case final error?)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(error, key: const Key('challenge_form_error'), style: TextStyle(color: scheme.error)),
              ),
            const SizedBox(height: 12),
            FilledButton(
              key: const Key('challenge_form_save'),
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
              onPressed: _valid && !_saving ? _save : null,
              child: Text('challenge.start_button'.tr()),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 7: Testin geçtiğini gör**

Run: `flutter test --no-pub -j 1 test/features/social/presentation/create_challenge_sheet_test.dart`
Expected: PASS (4 test). Not: `friends` listesi `socialOverviewProvider` yüklendikten sonra dolar; `pumpAndSettle` bekler. `scaffold: true` sayfayı `SingleChildScrollView` içine koyar; içteki `SingleChildScrollView` ile birlikte sorun çıkarsa `scaffold: false` ve `Scaffold(body: CreateChallengeSheet(...))` kullan.

- [ ] **Step 8: Commit**

```bash
git add assets/translations/tr.json assets/translations/en.json lib/features/social/presentation/widgets/challenge_labels.dart lib/features/social/presentation/widgets/challenge_cards.dart lib/features/social/presentation/create_challenge_sheet.dart test/features/social/presentation/create_challenge_sheet_test.dart
git commit -m "feat(social): add challenge texts, cards and the create sheet

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 6: Meydan okumalar sekmesi ve dört sekmeli Sosyal ekranı

**Files:**
- Create: `lib/features/social/presentation/challenges_tab.dart`
- Modify: `lib/features/social/presentation/social_screen.dart`
- Test: `test/features/social/presentation/challenges_tab_test.dart`, `test/features/social/presentation/social_screen_test.dart`

**Interfaces:**
- Consumes: `myChallengesProvider`, `pendingChallengeInvitesProvider`, `socialOverviewProvider`, kartlar ve `showCreateChallengeSheet` (Task 5).
- Produces: `ChallengesTab`; anahtarlar `challenges_tab`, `challenges_retry`, `challenges_active_empty`, `challenges_need_friends`, `challenge_new`, `social_tab_challenges`, `challenge_tab_badge`.

- [ ] **Step 1: Sekme testini yaz**

`test/features/social/presentation/challenges_tab_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spor_takip/features/progress/application/progress_providers.dart';
import 'package:spor_takip/features/social/application/social_providers.dart';
import 'package:spor_takip/features/social/domain/challenge.dart';
import 'package:spor_takip/features/social/presentation/challenges_tab.dart';
import 'package:spor_takip/features/workout/application/muscle_heat_providers.dart';
import 'package:spor_takip/features/workout/application/session_providers.dart';

import '../../gamification/game_fixtures.dart';
import '../../progress/presentation/test_app.dart';
import '../fakes.dart';
import '../social_fixtures.dart';

final _sessions = [gameSession('a', DateTime(2026, 10, 8, 18), gameSets('bench', 3))];

void main() {
  setUpAll(initTestLocalization);
  setUp(() => SharedPreferences.setMockInitialValues({}));

  FakeSocialRepository repoWith({bool friends = true}) => FakeSocialRepository(
        me: socialMe,
        others: [socialAyse, socialBurak],
        friendships: [if (friends) socialFriendship('me', 'ayse')],
        challenges: [
          socialChallenge(id: 'inv', name: 'Davet'),
          socialChallenge(id: 'ch1'),
          socialChallenge(id: 'goal', kind: ChallengeKind.goal, metric: ChallengeMetric.workouts, target: 4),
          socialChallenge(id: 'up', startsAt: DateTime(2026, 10, 10), endsAt: DateTime(2026, 10, 13)),
          socialChallenge(id: 'old', startsAt: DateTime(2026, 9, 20), endsAt: DateTime(2026, 9, 27)),
        ],
        participants: {
          'inv': [socialParticipant('inv', 'ayse'), socialParticipant('inv', 'me', status: ChallengeStatus.invited)],
          'ch1': [socialParticipant('ch1', 'ayse', progress: 14), socialParticipant('ch1', 'me')],
          'goal': [socialParticipant('goal', 'me')],
          'up': [socialParticipant('up', 'me')],
          'old': [socialParticipant('old', 'ayse', progress: 10), socialParticipant('old', 'me', progress: 20)],
        },
      );

  Future<void> pump(WidgetTester tester, FakeSocialRepository repo) async {
    tester.view.physicalSize = const Size(360, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(testApp(
      const Scaffold(body: ChallengesTab()),
      scaffold: false,
      stubRoutes: const {'/social/challenge/:id': 'CHALLENGE_PAGE'},
      overrides: [
        socialRepositoryProvider.overrideWithValue(repo),
        nowProvider.overrideWithValue(() => DateTime(2026, 10, 9, 12)),
        allSessionsProvider.overrideWith((ref) async => _sessions),
        mealTimesProvider.overrideWith((ref) async => const []),
        exercisesByIdProvider.overrideWith((ref) async => gameExercisesById),
      ],
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('shows invites, active race and goal cards, upcoming and finished rows', (tester) async {
    await pump(tester, repoWith());
    expect(find.byKey(const Key('challenge_invite_card_inv')), findsOneWidget);
    expect(tester.widget<Text>(find.byKey(const Key('challenge_position_ch1'))).data, '2.');
    expect(find.byKey(const Key('challenge_leader_ch1')), findsOneWidget);
    expect(tester.widget<Text>(find.byKey(const Key('challenge_goal_goal'))).data, 'challenge.goal_progress');
    expect(find.byKey(const Key('challenge_item_up')), findsOneWidget);
    expect(find.descendant(of: find.byKey(const Key('challenge_item_old')), matching: find.text('challenge.result_won')),
        findsOneWidget);
    expect(find.byKey(const Key('challenge_new')), findsOneWidget);
  });

  testWidgets('accepting an invite moves it to active', (tester) async {
    final repo = repoWith();
    await pump(tester, repo);
    await tester.tap(find.byKey(const Key('challenge_accept_inv')));
    await tester.pumpAndSettle();
    expect(repo.challengeResponses, [('inv', true)]);
    expect(find.byKey(const Key('challenge_invite_card_inv')), findsNothing);
    expect(find.byKey(const Key('challenge_active_inv')), findsOneWidget);
  });

  testWidgets('without friends the button is replaced by a hint', (tester) async {
    await pump(tester, repoWith(friends: false));
    expect(find.byKey(const Key('challenge_new')), findsNothing);
    expect(find.byKey(const Key('challenges_need_friends')), findsOneWidget);
  });

  testWidgets('empty state', (tester) async {
    await pump(tester, FakeSocialRepository(me: socialMe, friendships: [socialFriendship('me', 'ayse')], others: [socialAyse]));
    expect(find.byKey(const Key('challenges_active_empty')), findsOneWidget);
  });
}
```

- [ ] **Step 2: Testin yüklenemediğini gör**

Run: `flutter test --no-pub -j 1 test/features/social/presentation/challenges_tab_test.dart`
Expected: FAIL — `challenges_tab.dart` yok.

- [ ] **Step 3: Sekmeyi yaz**

`lib/features/social/presentation/challenges_tab.dart`:

```dart
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/widgets/section_header.dart';
import '../../workout/application/session_providers.dart';
import '../application/challenge_providers.dart';
import '../application/social_providers.dart';
import 'create_challenge_sheet.dart';
import 'widgets/challenge_cards.dart';

/// Meydan okumalar sekmesi (S3 spec §7.2): davetler, aktif, başlamamış, biten.
class ChallengesTab extends ConsumerWidget {
  const ChallengesTab({super.key});

  Future<void> _create(BuildContext context) async {
    final id = await showCreateChallengeSheet(context);
    if (id != null && context.mounted) context.push('/social/challenge/$id');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(myChallengesProvider);
    final hasFriends = (ref.watch(socialOverviewProvider).value?.friends ?? const []).isNotEmpty;
    final muted = TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant);
    final now = ref.read(nowProvider)();
    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(myChallengesProvider);
            await ref.read(myChallengesProvider.future);
          },
          child: ListView(
            key: const Key('challenges_tab'),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
            children: async.when(
              loading: () => const [
                Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator())),
              ],
              error: (error, stackTrace) => [
                Center(
                  child: TextButton(
                    key: const Key('challenges_retry'),
                    onPressed: () => ref.invalidate(myChallengesProvider),
                    child: Text('social.retry'.tr()),
                  ),
                ),
              ],
              data: (mine) => [
                if (mine.invites.isNotEmpty) ...[
                  SectionHeader('challenge.invites'.tr(), trailing: '${mine.invites.length}'),
                  for (final entry in mine.invites)
                    ChallengeInviteCard(entry: entry, creator: mine.profiles[entry.challenge.creator]),
                ],
                SectionHeader('challenge.active'.tr(), trailing: '${mine.active.length}'),
                if (mine.active.isEmpty)
                  Text('challenge.active_empty'.tr(), key: const Key('challenges_active_empty'), style: muted)
                else
                  for (final entry in mine.active) ChallengeActiveCard(entry: entry, profiles: mine.profiles, now: now),
                if (mine.upcoming.isNotEmpty) ...[
                  SectionHeader('challenge.upcoming'.tr()),
                  for (final entry in mine.upcoming) ChallengeCompactRow(entry: entry, now: now),
                ],
                if (mine.finished.isNotEmpty) ...[
                  SectionHeader('challenge.finished'.tr()),
                  for (final entry in mine.finished) ChallengeCompactRow(entry: entry, now: now),
                ],
                if (!hasFriends)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Text('challenge.need_friends'.tr(), key: const Key('challenges_need_friends'), style: muted),
                  ),
              ],
            ),
          ),
        ),
        if (hasFriends)
          Positioned(
            right: 16,
            bottom: 16,
            child: FloatingActionButton.extended(
              key: const Key('challenge_new'),
              icon: const Icon(Icons.add),
              label: Text('challenge.new'.tr()),
              onPressed: () => _create(context),
            ),
          ),
      ],
    );
  }
}
```

- [ ] **Step 4: Testin geçtiğini gör**

Run: `flutter test --no-pub -j 1 test/features/social/presentation/challenges_tab_test.dart`
Expected: PASS (4 test). 360 px'te `RenderFlex overflowed` çıkarsa ilgili satırdaki metni `Flexible`/`Expanded` içine al ve tekrar çalıştır.

- [ ] **Step 5: Sosyal ekranına dördüncü sekmeyi ekle**

`lib/features/social/presentation/social_screen.dart` — import'lar:

```dart
import '../application/challenge_providers.dart';
import 'challenges_tab.dart';
```

`_Tabs`'ı değiştir:

```dart
/// Arkadaşlar / Topluluklar / Meydan okumalar / Genel (S2 spec §6.1, S3 spec §7.1).
class _Tabs extends ConsumerWidget {
  const _Tabs({required this.me});

  final PublicProfile me;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = context.locale.languageCode;
    final invites = ref.watch(pendingChallengeInvitesProvider);
    Tab tab(String key, String label) => Tab(key: Key(key), text: upperCaseFor(label.tr(), lang));
    final challengesLabel = Text(upperCaseFor('challenge.tab'.tr(), lang));
    return DefaultTabController(
      length: 4,
      child: Column(
        children: [
          TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              tab('social_tab_friends', 'social.tab_friends'),
              tab('social_tab_communities', 'social.tab_communities'),
              Tab(
                key: const Key('social_tab_challenges'),
                child: invites > 0
                    ? Badge(key: const Key('challenge_tab_badge'), label: Text('$invites'), child: challengesLabel)
                    : challengesLabel,
              ),
              tab('social_tab_global', 'social.tab_global'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _Overview(me: me),
                const CommunitiesTab(),
                const ChallengesTab(),
                const GlobalTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 6: Sosyal ekran testine sekme kontrolü ekle**

`test/features/social/presentation/social_screen_test.dart` — dosyadaki sekme geçişi testinin (üç sekmeyi dolaşan test) sonuna ekle ya da yeni test olarak:

```dart
  testWidgets('the challenges tab sits between communities and global', (tester) async {
    await pump(tester, FakeSocialRepository(me: socialMe));
    expect(find.byKey(const Key('social_tab_challenges')), findsOneWidget);
    await tester.tap(find.byKey(const Key('social_tab_challenges')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('challenges_tab')), findsOneWidget);
  });
```

(`pump` dosyadaki yardımcının adıdır; farklıysa dosyadaki yardımcıyı kullan. `ChallengesTab` antrenman sağlayıcılarını izler; override yoksa kendi değer hesabı hata verir ve sekme yeniden dene düğmesini gösterir — anahtar `challenges_tab` yine bulunur.)

- [ ] **Step 7: Testlerin geçtiğini gör**

Run: `flutter test --no-pub -j 1 test/features/social/presentation/social_screen_test.dart test/features/social/presentation/challenges_tab_test.dart`
Expected: PASS.

- [ ] **Step 8: Commit**

```bash
git add lib/features/social/presentation/challenges_tab.dart lib/features/social/presentation/social_screen.dart test/features/social/presentation/challenges_tab_test.dart test/features/social/presentation/social_screen_test.dart
git commit -m "feat(social): add the challenges tab as the third social tab

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 7: Meydan okuma sayfası ve rota

**Files:**
- Create: `lib/features/social/presentation/challenge_screen.dart`
- Modify: `lib/core/router.dart`
- Test: `test/features/social/presentation/challenge_screen_test.dart`

**Interfaces:**
- Consumes: `challengeDetailProvider`, `challengeActionsProvider`, Task 5 yardımcıları ve kartları, `challengeStandings`, `challengeWinners`, `challengeRewardXp`.
- Produces: `ChallengeScreen({required String challengeId})`; rota `/social/challenge/:id`; anahtarlar `challenge_screen`, `challenge_retry`, `challenge_gone`, `challenge_header`, `challenge_time`, `challenge_result`, `challenge_standing_<userId>`, `challenge_standing_me`, `challenge_pending`, `challenge_reward`, `challenge_screen_accept`, `challenge_screen_decline`, `challenge_join`, `challenge_menu`, `challenge_leave`, `challenge_delete`, `challenge_confirm_ok`.

- [ ] **Step 1: Sayfa testini yaz**

`test/features/social/presentation/challenge_screen_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spor_takip/features/progress/application/progress_providers.dart';
import 'package:spor_takip/features/social/application/social_providers.dart';
import 'package:spor_takip/features/social/domain/challenge.dart';
import 'package:spor_takip/features/social/presentation/challenge_screen.dart';
import 'package:spor_takip/features/workout/application/muscle_heat_providers.dart';
import 'package:spor_takip/features/workout/application/session_providers.dart';

import '../../gamification/game_fixtures.dart';
import '../../progress/presentation/test_app.dart';
import '../fakes.dart';
import '../social_fixtures.dart';

final _sessions = [gameSession('a', DateTime(2026, 10, 8, 18), gameSets('bench', 3))];

void main() {
  setUpAll(initTestLocalization);
  setUp(() => SharedPreferences.setMockInitialValues({}));

  FakeSocialRepository repoWith(Challenge challenge, List<ChallengeParticipant> people) => FakeSocialRepository(
        me: socialMe,
        others: [socialAyse, socialBurak, socialCan],
        communities: [socialCommunity],
        challenges: [challenge],
        participants: {challenge.id: people},
      );

  Future<void> pump(WidgetTester tester, FakeSocialRepository repo, String id) async {
    tester.view.physicalSize = const Size(360, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(testApp(
      ChallengeScreen(challengeId: id),
      scaffold: false,
      overrides: [
        socialRepositoryProvider.overrideWithValue(repo),
        nowProvider.overrideWithValue(() => DateTime(2026, 10, 9, 12)),
        allSessionsProvider.overrideWith((ref) async => _sessions),
        mealTimesProvider.overrideWith((ref) async => const []),
        exercisesByIdProvider.overrideWith((ref) async => gameExercisesById),
      ],
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('an active race shows the header, live standings with me highlighted and pending invites',
      (tester) async {
    await pump(
      tester,
      repoWith(socialChallenge(), [
        socialParticipant('ch1', 'ayse', progress: 14),
        socialParticipant('ch1', 'me'),
        socialParticipant('ch1', 'burak', progress: 1),
        socialParticipant('ch1', 'can', status: ChallengeStatus.invited),
      ]),
      'ch1',
    );
    expect(find.byKey(const Key('challenge_header')), findsOneWidget);
    expect(find.byKey(const Key('challenge_time')), findsOneWidget);
    expect(find.byKey(const Key('challenge_result')), findsNothing);
    expect(
      tester.getTopLeft(find.byKey(const Key('challenge_standing_ayse'))).dy,
      lessThan(tester.getTopLeft(find.byKey(const Key('challenge_standing_me'))).dy),
    );
    expect(
      tester.getTopLeft(find.byKey(const Key('challenge_standing_me'))).dy,
      lessThan(tester.getTopLeft(find.byKey(const Key('challenge_standing_burak'))).dy),
    );
    expect(find.byKey(const Key('challenge_pending')), findsOneWidget);
    expect(find.byKey(const Key('challenge_reward')), findsOneWidget);
  });

  testWidgets('a finished race shows my result and the winner trophy', (tester) async {
    await pump(
      tester,
      repoWith(socialChallenge(id: 'old', startsAt: DateTime(2026, 9, 20), endsAt: DateTime(2026, 9, 27)), [
        socialParticipant('old', 'ayse', progress: 10),
        socialParticipant('old', 'me', progress: 20),
      ]),
      'old',
    );
    expect(tester.widget<Text>(find.byKey(const Key('challenge_result'))).data, 'challenge.result_won');
    expect(find.descendant(of: find.byKey(const Key('challenge_standing_me')), matching: find.byIcon(Icons.emoji_events)),
        findsOneWidget);
  });

  testWidgets('an invite can be accepted from the page', (tester) async {
    final repo = repoWith(socialChallenge(), [
      socialParticipant('ch1', 'ayse', progress: 14),
      socialParticipant('ch1', 'me', status: ChallengeStatus.invited),
    ]);
    await pump(tester, repo, 'ch1');
    await tester.tap(find.byKey(const Key('challenge_screen_accept')));
    await tester.pumpAndSettle();
    expect(repo.challengeResponses, [('ch1', true)]);
    expect(find.byKey(const Key('challenge_standing_me')), findsOneWidget);
  });

  testWidgets('a community member who has not joined sees Join; the owner can delete', (tester) async {
    final repo = repoWith(socialChallenge(id: 'cm', communityId: 'c1'), [socialParticipant('cm', 'ayse', progress: 5)]);
    await pump(tester, repo, 'cm');
    await tester.tap(find.byKey(const Key('challenge_join')));
    await tester.pumpAndSettle();
    expect(repo.joinedChallenges, ['cm']);

    await tester.tap(find.byKey(const Key('challenge_menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('challenge_delete')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('challenge_confirm_ok')));
    await tester.pumpAndSettle();
    expect(repo.deletedChallenges, ['cm']);
  });

  testWidgets('leaving asks for confirmation', (tester) async {
    final repo = repoWith(socialChallenge(), [socialParticipant('ch1', 'ayse'), socialParticipant('ch1', 'me')]);
    await pump(tester, repo, 'ch1');
    await tester.tap(find.byKey(const Key('challenge_menu')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('challenge_delete')), findsNothing);
    await tester.tap(find.byKey(const Key('challenge_leave')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('challenge_confirm_ok')));
    await tester.pumpAndSettle();
    expect(repo.leftChallenges, ['ch1']);
  });

  testWidgets('a missing challenge shows the gone text', (tester) async {
    await pump(tester, FakeSocialRepository(me: socialMe), 'nope');
    expect(find.byKey(const Key('challenge_gone')), findsOneWidget);
  });
}
```

- [ ] **Step 2: Testin yüklenemediğini gör**

Run: `flutter test --no-pub -j 1 test/features/social/presentation/challenge_screen_test.dart`
Expected: FAIL — `challenge_screen.dart` yok.

- [ ] **Step 3: Sayfayı yaz**

`lib/features/social/presentation/challenge_screen.dart`:

```dart
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_fonts.dart';
import '../../../shared/text_case.dart';
import '../../../shared/widgets/section_header.dart';
import '../../workout/application/session_providers.dart';
import '../application/challenge_providers.dart';
import '../domain/challenge.dart';
import '../domain/challenge_results.dart';
import '../domain/public_profile.dart';
import 'widgets/challenge_cards.dart';
import 'widgets/challenge_labels.dart';
import 'widgets/social_avatar.dart';

/// Meydan okuma sayfası (S3 spec §7.4).
class ChallengeScreen extends ConsumerWidget {
  const ChallengeScreen({super.key, required this.challengeId});

  final String challengeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = challengeDetailProvider(challengeId);
    final async = ref.watch(provider);
    final current = async.value;
    return Scaffold(
      key: const Key('challenge_screen'),
      appBar: AppBar(
        title: Text(
          upperCaseFor('challenge.title'.tr(), context.locale.languageCode),
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
        ),
        actions: [if (current != null) _ChallengeMenu(detail: current)],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(
          child: TextButton(
            key: const Key('challenge_retry'),
            onPressed: () => ref.invalidate(provider),
            child: Text('social.retry'.tr()),
          ),
        ),
        data: (detail) => detail == null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text('challenge.gone'.tr(), key: const Key('challenge_gone'), textAlign: TextAlign.center),
                ),
              )
            : RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(provider);
                  await ref.read(provider.future);
                },
                child: _ChallengeBody(detail: detail),
              ),
      ),
    );
  }
}

class _ChallengeBody extends ConsumerWidget {
  const _ChallengeBody({required this.detail});

  final ChallengeDetail detail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final muted = TextStyle(color: scheme.onSurfaceVariant);
    final challenge = detail.challenge;
    final now = ref.read(nowProvider)();
    final state = challenge.state(now);
    final names = {for (final MapEntry(key: id, value: p) in detail.profiles.entries) id: p.displayName};
    final rows = challengeStandings(challenge, detail.participants, names: names);
    final winners = challengeWinners(challenge, detail.participants, now);
    final pending = [
      for (final p in detail.participants)
        if (p.status == ChallengeStatus.invited) names[p.userId] ?? '?',
    ];
    final mine = detail.mine;
    final open = state == ChallengeState.upcoming || state == ChallengeState.active;
    final actions = ref.read(challengeActionsProvider);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        _Header(detail: detail, now: now),
        if (state == ChallengeState.finished)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              challengeResultLabel(challenge, detail.participants, detail.myId, now),
              key: const Key('challenge_result'),
              style: theme.textTheme.titleMedium?.copyWith(color: scheme.primary, fontWeight: FontWeight.w800),
            ),
          ),
        SectionHeader('challenge.standings'.tr(), trailing: '${rows.length}'),
        if (rows.isEmpty)
          Text('challenge.standings_empty'.tr(), style: muted)
        else
          for (final row in rows)
            _StandingRow(
              row: row,
              challenge: challenge,
              profile: detail.profiles[row.userId],
              isMe: row.userId == detail.myId,
              isWinner: winners.contains(row.userId),
            ),
        if (pending.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'challenge.pending'.tr(namedArgs: {'names': pending.join(', ')}),
              key: const Key('challenge_pending'),
              style: muted,
            ),
          ),
        const SizedBox(height: 16),
        Card(
          key: const Key('challenge_reward'),
          margin: EdgeInsets.zero,
          child: ListTile(
            leading: Icon(Icons.emoji_events, color: scheme.primary),
            title: Text(
              (challenge.kind == ChallengeKind.race ? 'challenge.reward_race' : 'challenge.reward_goal')
                  .tr(namedArgs: {'xp': '${challengeRewardXp(challenge.kind)}'}),
            ),
            subtitle: Text('challenge.reward_title'.tr()),
          ),
        ),
        if (mine?.status == ChallengeStatus.invited && open) ...[
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  key: const Key('challenge_screen_accept'),
                  onPressed: () => runChallengeAction(context, () => actions.respond(challenge, accept: true)),
                  child: Text('challenge.accept'.tr()),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  key: const Key('challenge_screen_decline'),
                  onPressed: () => runChallengeAction(context, () => actions.respond(challenge, accept: false)),
                  child: Text('challenge.decline'.tr()),
                ),
              ),
            ],
          ),
        ],
        if (challenge.isCommunity && mine?.status != ChallengeStatus.joined && open) ...[
          const SizedBox(height: 16),
          FilledButton(
            key: const Key('challenge_join'),
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            onPressed: () => runChallengeAction(context, () => actions.join(challenge)),
            child: Text('challenge.join'.tr()),
          ),
        ],
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.detail, required this.now});

  final ChallengeDetail detail;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final muted = TextStyle(color: scheme.onSurfaceVariant);
    final challenge = detail.challenge;
    final joined = detail.participants.where((p) => p.status == ChallengeStatus.joined).length;
    return Card(
      key: const Key('challenge_header'),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              challenge.name,
              style: theme.textTheme.headlineSmall?.copyWith(fontFamily: AppFonts.heading, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            ChallengeChips(challenge: challenge),
            if (detail.community case final community?)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    Icon(Icons.groups, size: 18, color: scheme.primary),
                    const SizedBox(width: 6),
                    Expanded(child: Text(community.name, overflow: TextOverflow.ellipsis)),
                  ],
                ),
              ),
            const SizedBox(height: 8),
            Text('${challengeDateLabel(challenge.startsAt)} – ${challengeDateLabel(challenge.endsAt)}', style: muted),
            Text(
              challengeTimeLabel(challenge, now),
              key: const Key('challenge_time'),
              style: TextStyle(color: scheme.primary, fontWeight: FontWeight.w800),
            ),
            if (challenge.kind == ChallengeKind.goal)
              Text('challenge.target'.tr(namedArgs: {
                'value': challengeValueLabel(challenge.metric, challenge.target ?? 0),
              })),
            const SizedBox(height: 4),
            Text(
              'challenge.participants_by'.tr(namedArgs: {
                'n': '$joined',
                'name': detail.profiles[challenge.creator]?.displayName ?? '?',
              }),
              style: muted,
            ),
          ],
        ),
      ),
    );
  }
}

class _StandingRow extends StatelessWidget {
  const _StandingRow({
    required this.row,
    required this.challenge,
    required this.profile,
    required this.isMe,
    required this.isWinner,
  });

  final ChallengeStanding row;
  final Challenge challenge;
  final PublicProfile? profile;
  final bool isMe;
  final bool isWinner;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final goal = challenge.kind == ChallengeKind.goal;
    return Container(
      key: Key('challenge_standing_${row.userId}'),
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isMe ? scheme.primary : scheme.outlineVariant),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Text('${row.position}', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
          ),
          SocialAvatar(initials: profile?.initials ?? '?', highlighted: isMe, size: 36),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        profile?.displayName ?? '?',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ),
                    if (isMe)
                      Padding(
                        padding: const EdgeInsets.only(left: 6),
                        child: Text(
                          'challenge.me'.tr(),
                          key: const Key('challenge_standing_me_label'),
                          style: TextStyle(color: scheme.primary, fontWeight: FontWeight.w800),
                        ),
                      ),
                  ],
                ),
                if (goal)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: LinearProgressIndicator(
                      value: (row.value / (challenge.target ?? 1)).clamp(0.0, 1.0),
                      minHeight: 4,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (isWinner)
            Padding(padding: const EdgeInsets.only(right: 6), child: Icon(Icons.emoji_events, color: scheme.primary))
          else if (row.reachedGoal)
            Padding(padding: const EdgeInsets.only(right: 6), child: Icon(Icons.check_circle, color: scheme.primary)),
          Text(
            challengeValueLabel(challenge.metric, row.value),
            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _ChallengeMenu extends ConsumerWidget {
  const _ChallengeMenu({required this.detail});

  final ChallengeDetail detail;

  Future<bool> _confirm(BuildContext context, String body) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          content: Text(body.tr()),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text('social.cancel'.tr())),
            FilledButton(
              key: const Key('challenge_confirm_ok'),
              onPressed: () => Navigator.of(context).pop(true),
              child: Text('challenge.confirm'.tr()),
            ),
          ],
        ),
      ) ??
      false;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final challenge = detail.challenge;
    final state = challenge.state(ref.read(nowProvider)());
    final canLeave = detail.mine != null && (state == ChallengeState.upcoming || state == ChallengeState.active);
    if (!canLeave && !detail.canDelete) return const SizedBox.shrink();
    final actions = ref.read(challengeActionsProvider);
    return PopupMenuButton<String>(
      key: const Key('challenge_menu'),
      onSelected: (value) async {
        final leave = value == 'leave';
        if (!await _confirm(context, leave ? 'challenge.leave_confirm' : 'challenge.delete_confirm')) return;
        if (!context.mounted) return;
        final done = await runChallengeAction(
          context,
          () => leave ? actions.leave(challenge) : actions.delete(challenge),
        );
        if (done && context.mounted && Navigator.of(context).canPop()) Navigator.of(context).pop();
      },
      itemBuilder: (context) => [
        if (canLeave)
          PopupMenuItem(value: 'leave', key: const Key('challenge_leave'), child: Text('challenge.leave'.tr())),
        if (detail.canDelete)
          PopupMenuItem(value: 'delete', key: const Key('challenge_delete'), child: Text('challenge.delete'.tr())),
      ],
    );
  }
}
```

- [ ] **Step 4: Testin geçtiğini gör**

Run: `flutter test --no-pub -j 1 test/features/social/presentation/challenge_screen_test.dart`
Expected: PASS (6 test). Not: topluluk testinde `socialCommunity.owner == 'me'` olduğu için silme menüde görünür; katılmadan önce menüde yalnız "Sil" vardır.

- [ ] **Step 5: Rotayı ekle**

`lib/core/router.dart` — import:

```dart
import '../features/social/presentation/challenge_screen.dart';
```

`community/:id` rotasının hemen altına:

```dart
                  GoRoute(
                    path: 'challenge/:id',
                    builder: (context, state) => ChallengeScreen(challengeId: state.pathParameters['id']!),
                  ),
```

- [ ] **Step 6: Analiz**

Run: `flutter analyze lib/features/social lib/core`
Expected: `No issues found!`

- [ ] **Step 7: Commit**

```bash
git add lib/features/social/presentation/challenge_screen.dart lib/core/router.dart test/features/social/presentation/challenge_screen_test.dart
git commit -m "feat(social): add the challenge page with standings, results and actions

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 8: Topluluk kartı ve arkadaş profilinden meydan okuma

**Files:**
- Create: `lib/features/social/presentation/community_challenges_card.dart`
- Modify: `lib/features/social/presentation/community_screen.dart`
- Modify: `lib/features/social/presentation/friend_profile_screen.dart`
- Test: `test/features/social/presentation/community_screen_test.dart`, `test/features/social/presentation/friend_profile_screen_test.dart`

**Interfaces:**
- Consumes: `communityChallengesProvider`, `challengeActionsProvider`, `ChallengeCompactRow`, `challengeValueLabel`, `runChallengeAction`, `showCreateChallengeSheet`, `maxCommunityChallenges`.
- Produces: `CommunityChallengesCard({required String communityId})`; anahtarlar `community_challenges`, `community_challenges_empty`, `community_challenge_join_<id>`, `community_challenge_new`, `friend_challenge`.

- [ ] **Step 1: Topluluk sayfası testlerini ekle**

`test/features/social/presentation/community_screen_test.dart` — import'lara ekle:

```dart
import 'package:spor_takip/features/social/domain/challenge.dart';
```

`main` içine ekle:

```dart
  testWidgets('the challenges card lists community challenges and lets me join', (tester) async {
    final repo = repoWith()
      ..challenges['cm'] = socialChallenge(id: 'cm', communityId: 'c1', name: 'Topluluk yarışı')
      ..participants['cm'] = [socialParticipant('cm', 'ayse', progress: 5)];
    await pump(tester, repo);
    await tester.scrollUntilVisible(
      find.byKey(const Key('community_challenge_join_cm')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.byKey(const Key('challenge_item_cm')), findsOneWidget);
    await tester.tap(find.byKey(const Key('community_challenge_join_cm')));
    await tester.pumpAndSettle();
    expect(repo.joinedChallenges, ['cm']);
    expect(find.byKey(const Key('community_challenge_join_cm')), findsNothing);
  });

  testWidgets('the challenges card shows the empty text and the new button', (tester) async {
    await pump(tester, repoWith());
    await tester.scrollUntilVisible(
      find.byKey(const Key('community_challenge_new')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.byKey(const Key('community_challenges_empty')), findsOneWidget);
  });
```

(`repoWith` ve `pump` dosyadaki yardımcılardır; `FakeSocialRepository.challenges`/`participants` değiştirilebilir haritalardır.)

- [ ] **Step 2: Testlerin başarısız olduğunu gör**

Run: `flutter test --no-pub -j 1 test/features/social/presentation/community_screen_test.dart`
Expected: FAIL — `community_challenge_join_cm` bulunamaz.

- [ ] **Step 3: Topluluk kartını yaz**

`lib/features/social/presentation/community_challenges_card.dart`:

```dart
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/widgets/section_header.dart';
import '../../workout/application/session_providers.dart';
import '../application/challenge_providers.dart';
import '../domain/challenge.dart';
import 'create_challenge_sheet.dart';
import 'widgets/challenge_cards.dart';
import 'widgets/challenge_labels.dart';

/// Topluluk sayfasındaki meydan okumalar (S3 spec §7.5): katıldıysam değerim,
/// değilsem "Katıl"; sınır dolmadıysa "Meydan okuma aç".
class CommunityChallengesCard extends ConsumerWidget {
  const CommunityChallengesCard({super.key, required this.communityId});

  final String communityId;

  Future<void> _create(BuildContext context) async {
    final id = await showCreateChallengeSheet(context, communityId: communityId);
    if (id != null && context.mounted) context.push('/social/challenge/$id');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = ref.watch(communityChallengesProvider(communityId)).value ?? const <ChallengeEntry>[];
    final muted = TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant);
    final now = ref.read(nowProvider)();
    final actions = ref.read(challengeActionsProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader('challenge.community_title'.tr(), key: const Key('community_challenges'), trailing: '${entries.length}'),
        if (entries.isEmpty)
          Text('challenge.community_empty'.tr(), key: const Key('community_challenges_empty'), style: muted)
        else
          for (final entry in entries)
            ChallengeCompactRow(
              entry: entry,
              now: now,
              trailing: entry.mine?.status == ChallengeStatus.joined
                  ? Text(challengeValueLabel(entry.challenge.metric, entry.mine!.progress))
                  : TextButton(
                      key: Key('community_challenge_join_${entry.challenge.id}'),
                      onPressed: () => runChallengeAction(context, () => actions.join(entry.challenge)),
                      child: Text('challenge.join'.tr()),
                    ),
            ),
        if (entries.length < maxCommunityChallenges)
          TextButton.icon(
            key: const Key('community_challenge_new'),
            icon: const Icon(Icons.add),
            label: Text('challenge.community_new'.tr()),
            onPressed: () => _create(context),
          ),
      ],
    );
  }
}
```

`lib/features/social/presentation/community_screen.dart` — import:

```dart
import 'community_challenges_card.dart';
```

`_CommunityBody`'deki `ListView` çocuklarının sonuna (kas liderleri kartından sonra):

```dart
        CommunityChallengesCard(communityId: detail.community.id),
```

- [ ] **Step 4: Topluluk testlerinin geçtiğini gör**

Run: `flutter test --no-pub -j 1 test/features/social/presentation/community_screen_test.dart`
Expected: PASS.

- [ ] **Step 5: Arkadaş profili testini ekle**

`test/features/social/presentation/friend_profile_screen_test.dart` — `main` içine ekle (dosyadaki `pump`/repo yardımcılarıyla; Ayşe arkadaş profili açılıyorsa):

```dart
  testWidgets('"Challenge" opens the create sheet with the friend preselected', (tester) async {
    await pump(tester, repo());
    await tester.tap(find.byKey(const Key('friend_challenge')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('challenge_form')), findsOneWidget);
    expect(tester.widget<CheckboxListTile>(find.byKey(const Key('challenge_invite_ayse'))).value, isTrue);
  });
```

(Yardımcıların adı dosyada farklıysa uyarla: profili açılan arkadaşın kimliğini kullan.)

- [ ] **Step 6: Testin başarısız olduğunu gör**

Run: `flutter test --no-pub -j 1 test/features/social/presentation/friend_profile_screen_test.dart`
Expected: FAIL — `friend_challenge` yok.

- [ ] **Step 7: Düğmeyi ekle**

`lib/features/social/presentation/friend_profile_screen.dart` — import'lar:

```dart
import 'package:go_router/go_router.dart';
import 'create_challenge_sheet.dart';
```

(`go_router` zaten import'luysa tekrar ekleme.) `_FriendBody`'deki `ListView` çocuklarında `_Header(...)`'dan hemen sonra:

```dart
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: OutlinedButton.icon(
            key: const Key('friend_challenge'),
            style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            icon: const Icon(Icons.flag_outlined),
            label: Text('challenge.challenge_friend'.tr()),
            onPressed: () async {
              final id = await showCreateChallengeSheet(context, friendId: entry.profile.userId);
              if (id != null && context.mounted) context.push('/social/challenge/$id');
            },
          ),
        ),
```

- [ ] **Step 8: Testlerin geçtiğini gör**

Run: `flutter test --no-pub -j 1 test/features/social/presentation/friend_profile_screen_test.dart test/features/social/presentation/community_screen_test.dart`
Expected: PASS.

- [ ] **Step 9: Commit**

```bash
git add lib/features/social/presentation/community_challenges_card.dart lib/features/social/presentation/community_screen.dart lib/features/social/presentation/friend_profile_screen.dart test/features/social/presentation/community_screen_test.dart test/features/social/presentation/friend_profile_screen_test.dart
git commit -m "feat(social): add community challenges and challenge a friend from their profile

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 9: Doğrulama, migration, manuel kontrol ve PLAN.md

**Files:**
- Modify: `PLAN.md`

- [ ] **Step 1: Analiz ve sosyal + oyunlaştırma testleri**

Run: `flutter analyze` ardından (analiz bittikten sonra) `flutter test --no-pub -j 1 test/features/social test/features/gamification test/core/app_shell_test.dart`
Expected: `No issues found!` ve tüm testler PASS.

- [ ] **Step 2: Kullanıcı tam paketi çalıştırır**

Kullanıcıdan kendi terminalinde `flutter test -j 1` çalıştırmasını iste; sonucu (toplam test sayısı) PLAN satırına yaz.

- [ ] **Step 3: Kullanıcı migration'ı uygular ve kontrolü çalıştırır**

Kullanıcı Supabase SQL Editor'da `supabase/migrations/0015_social_challenges.sql`'i, sonra `supabase/migrations/checks/s3_rls_checks.sql`'i çalıştırır. Beklenen hata satırı (üç hesapla):

```
SONUC: B_gorur=1 B_ilerleme=12 A_ilerleme=0 arkadas_degil=not_friend C_profil_B=1 C_reddetti_profil_B=0 disaridan_gorur=0 disaridan_katil=not_member uye_gorur=1 topluluk_limit=community_challenge_limit kisisel_limit=challenge_limit kapandi=challenge_closed acan_silemez=not_allowed sahip_sildi=t son_ayrilan_sildi=t
```

Farklı değer çıkarsa ilgili fonksiyonu düzelt, migration'ı yeniden çalıştırılabilir tut (`create or replace`, `drop policy if exists`) ve kontrolü tekrarlat.

- [ ] **Step 4: Manuel kontrol (iki hesap, web release)**

Kullanıcı kendi PowerShell'inde: `flutter build web --release --no-pub`, sonra `cd build\web` ve `python -m http.server 5555 --bind 127.0.0.1`; `http://localhost:5555` (ikinci hesap gizli pencerede). Kontrol listesi:

1. A, B'ye 3 günlük set yarışı açar; B'de davet ve rozet görünür; B kabul eder.
2. A antrenman yapar; iki tarafta da sıralama ve değerler güncellenir.
3. Hedef meydan okumasında ilerleme çubuğu ve hedefe ulaşınca tik.
4. Toplulukta A meydan okuma açar; B topluluk sayfasından katılır; 4. meydan okuma açılamaz.
5. B reddettiği davetin listeden kalktığını görür; ayrılma ve silme onaylı çalışır.
6. Kesinleşme: SQL Editor'da `update public.challenges set starts_at = now() - interval '5 days', ends_at = now() - interval '2 days' where name = '<ad>';` → uygulamayı yenile: "Bitti", kazanan kupası, "+100 XP"; seviye ekranında XP dökümünde "Meydan okumalar" ve "Meydan Okuma Çırağı" unvanı. (`ends_at` + 24 saat geçmeden "Kesinleşiyor" görünür: `ends_at = now() - interval '1 hour'` ile de bakılabilir.)
7. Arkadaş profilinden "Meydan oku" o arkadaş seçili açılır.
8. ~360 px'te taşma yok (dört sekme kayar, ölçü çipleri sarılır); EN metinler doğru.

- [ ] **Step 5: PLAN.md satırı**

`PLAN.md`'deki ilerleme tablosunun sonuna (2026-10-10 S2 satırından sonra) bir satır ekle: tarih, "**F5+ S3 (meydan okumalar) tamamlandı** (`s3-meydan-okumalar` dalı, 9 görev)", kısa özet (arkadaş/topluluk meydan okumaları, yarış/hedef, dört ölçü + kas filtresi, hazır süreler, canlı sıralama, 24 saat kesinleşme, +100/+50 XP ve "Meydan Okuma" unvanı, migration `0015` + `s3_rls_checks.sql` sonucu), bu plandaki sapmalar listesi, otomatik test sayısı ve analiz sonucu, manuel kontrol sonucu, "Oyunlaştırma yol haritası tamamlandı".

```bash
git add PLAN.md
git commit -m "docs: record S3 challenges in the plan

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

- [ ] **Step 6: Dalı bitir**

`superpowers:finishing-a-development-branch` ile birleştirme seçeneğini kullanıcıya sor.
