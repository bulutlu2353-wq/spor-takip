# S2 Topluluklar ve Dönem Unvanları Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Topluluk kurma/katılma (adla arama ya da davet kodu), topluluk içinde ve tüm kullanıcılar arasında haftalık/aylık canlı sıralama, sahibi her dönem değişen unvanlar ("Haftanın Kanat Şampiyonu", "Ayın Yıldızı") ve topluluk yönetimi; Sosyal sekmesinde Arkadaşlar / Topluluklar / Genel alt sekmeleri.

**Architecture:** Migration `0014` dönem özeti (`period_stats`), topluluk (`communities`), üyelik (`community_members`) ve yasak (`community_bans`) tablolarını, RLS'yi ve security definer fonksiyonları ekler. Uygulama `PlayerSummary` + oturumlardan bu ve önceki hafta/ayın XP ve kas setlerini hesaplayıp kendi `period_stats` satırını yazar (`statsSyncProvider`). Topluluk sıralaması ve unvanları uygulamada (`standings`, `periodTitles`), genel sonuçlar sunucuda yayınlanmış sayılar üzerinde gruplamayla (`global_titles`, `global_leaderboard`) hesaplanır.

**Tech Stack:** Flutter, flutter_riverpod 3, go_router, easy_localization, supabase_flutter, Postgres (SQL Editor), flutter_test.

**Spec:** `docs/superpowers/specs/2026-10-10-s2-topluluklar-design.md`

## Global Constraints

- Dal: `s2-topluluklar`. Migration `supabase/migrations/0014_social_communities.sql`; kullanıcı SQL Editor'da uygular. Edge Function deploy yok.
- Görevlerde yalnızca ilgili test dosyaları çalıştırılır: `flutter test --no-pub -j 1 <dosya>` (makine ~3.8 GB RAM). Tam paketi kullanıcı kendi terminalinde çalıştırır.
- `flutter analyze --no-pub` arka planda; "No issues found!".
- `dart format` çalıştırılmaz; satırlar ≤ ~120 karakter.
- Testlerde çeviriler yüklenmez; `.tr()` ham anahtarı döndürür (adlandırılmış argümanlar görünmez); `upperCaseFor(..., 'tr')` `i`'yi `İ` yapar (test metinleri buna göre aranır ya da `Key` kullanılır).
- Dönemler: hafta ISO (pazartesi başlar, anahtar `'2026-W41'`), ay (`'2026-10'`). Geçen dönemin sahipleri kesin unvan; bu dönem canlı.
- Unvan kategorileri: `'xp'` + 17 kas (`muscleGroups`); kas değeri dönemde biten oturumların tamamlanmış setleri × `muscleWeight`.
- Sınırlar: kişi başı en çok 5 topluluk, toplulukta en çok 100 üye; ad trim sonrası 3–40, açıklama ≤ 200. Genel sıralama ilk 50.
- Hata kodları: `community_limit`, `community_full`, `banned`, `not_public`, `unknown_code`, `no_profile`, `not_owner`.
- Arkadaş olmayan topluluk üyeleri yalnız sıralama verisini görür (ad, @kullanıcıadı, rütbe/seviye, takılı unvan, dönem XP'si ve kas setleri); haftalık özet, son antrenmanlar, ısı haritası S1'deki gibi yalnız arkadaşlara.
- Commit mesajları şu satırla biter: `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`
- Bash/PowerShell her git komutunda `commit-graph` / CRLF uyarıları basar; zararsız.

## Spec'ten bilinçli sapmalar (kullanıcıya bildirilecek)

1. **Depo arayüzü:** `fetchMyCommunities()` + `fetchCommunity(id)` + `fetchMembers(communityId)` yerine `fetchMyCommunityIds()`, `fetchCommunities(ids)` ve `fetchMembers(communityIds)` (topluluk → üyeler). "Topluluklarım"daki sıra için zaten tüm üyeler ve dönem özetleri gerekiyor; böylece beş topluluk dört istekte gelir. `Community`'de `memberCount` yok; sayı üye listesinden.
2. **`myCommunitiesProvider`** `List<CommunityEntry>` döndürür (topluluk, üye sayısı, bu haftaki sıram).
3. **Topluluk güncelleme koruması:** `with check (owner = auth.uid())` politikasına ek olarak sütun izni: `authenticated` yalnız `name`, `description`, `is_public` güncelleyebilir; sahip ve kod yalnız fonksiyonlarla değişir.
4. **`communities.owner`** `on delete cascade` (hesap silinirse topluluğu da silinir).
5. **İç yardımcı `add_community_member(p_id)`:** katılma denetimleri tek yerde; kimseye çalıştırma izni yok.
6. **Katılma/kurma hataları** SnackBar yerine sayfanın içinde metin (`join_error`, `community_form_error`): alt sayfa SnackBar'ı örter.
7. **Arama** "ARA" düğmesi ya da klavye gönder ile (yazarken otomatik değil).
8. **`GlobalBoard`** yalnız `titles` + `rows`; yarış dışı metni doğrudan `PublicProfile.competeGlobally`'den.
9. **Kalan süre** saf fonksiyon `periodRemaining` (domain) + `periodRemainingLabel` (çeviri).

## Dosya yapısı

| Dosya | Görev |
|---|---|
| `supabase/migrations/0014_social_communities.sql` | Tablolar, RLS, fonksiyonlar, izinler |
| `supabase/migrations/checks/s2_rls_checks.sql` | A/B/C DO bloğu |
| `lib/features/social/domain/period_keys.dart` | `PeriodKind`, `weekKey`, `monthKey`, `periodRange`, `periodKey`, `periodRemaining` |
| `lib/features/social/domain/period_stats.dart` | `PeriodSlot`, `PeriodStats`, `buildPeriodStats` |
| `lib/features/social/domain/standings.dart` | `periodCategories`, `Standing`, `standings`, `PeriodTitle`, `periodTitles` |
| `lib/features/social/domain/community.dart` | `CommunityException`, `communityErrorCodes`, `maxCommunities`, `Community`, `CommunityMember`, `CommunitySearchResult`, `GlobalTitle`, `GlobalRow` |
| `lib/features/social/domain/public_profile.dart` | `competeGlobally` |
| `lib/features/social/data/social_repository.dart` | Topluluk/dönem/genel metotları |
| `lib/features/social/application/social_providers.dart` | `lastPublishedPeriodStatsProvider`, `statsSyncProvider` dönem yayını, `updateProfile(competeGlobally)` |
| `lib/features/social/application/community_providers.dart` | `CommunityEntry`, `myCommunitiesProvider`, `CommunityDetail`, `communityDetailProvider`, `GlobalBoard`, `globalBoardProvider`, `CommunityActions` |
| `lib/features/social/presentation/widgets/period_widgets.dart` | Unvan/değer/kalan süre metinleri, `PeriodSwitch`, `TitleLine`, `PeriodTitlesList`, `StandingLine`, `StandingsList` |
| `lib/features/social/presentation/communities_tab.dart` | `CommunitiesTab` |
| `lib/features/social/presentation/community_form_sheet.dart` | `showCommunityFormSheet`, `CommunityFormSheet` |
| `lib/features/social/presentation/join_community_sheet.dart` | `showJoinCommunitySheet`, `JoinCommunitySheet` |
| `lib/features/social/presentation/community_screen.dart` | `CommunityScreen` |
| `lib/features/social/presentation/manage_members_sheet.dart` | `showManageMembersSheet`, `ManageMembersSheet` |
| `lib/features/social/presentation/global_tab.dart` | `GlobalTab`, `globalTitleLines` |
| `lib/features/social/presentation/social_screen.dart` | Üç alt sekme |
| `lib/features/social/presentation/social_settings_screen.dart` | "Yarış" anahtarı |
| `lib/core/router.dart` | `/social/community/:id` |
| `assets/translations/tr.json`, `en.json` | `social` bloğuna S2 anahtarları |
| `test/features/social/...` | Testler, `fakes.dart`, `social_fixtures.dart` |

---

### Task 1: Migration ve RLS kontrolü

**Files:**
- Create: `supabase/migrations/0014_social_communities.sql`
- Create: `supabase/migrations/checks/s2_rls_checks.sql`

**Interfaces:**
- Consumes (veritabanı, `0013`): `public_profiles`, `friendships`, `new_invite_code()`, `are_friends(uuid, uuid)`, `has_friendship(uuid, uuid)`.
- Produces (veritabanı): `public_profiles.compete_globally`; tablolar `period_stats`, `communities`, `community_members`, `community_bans`; fonksiyonlar `is_member(uuid, uuid)`, `shares_community(uuid, uuid)`, `create_community(text, text, boolean) → uuid`, `join_community(uuid)`, `join_community_by_code(text) → uuid`, `leave_community(uuid)`, `remove_member(uuid, uuid, boolean)`, `regenerate_community_code(uuid) → text`, `search_communities(text)`, `global_titles(text, text)`, `global_leaderboard(text, text)`. Fonksiyon hataları `raise exception '<kod>'` (PostgREST'te `PostgrestException.message == '<kod>'`).

- [ ] **Step 1: Migration'ı yaz**

`supabase/migrations/0014_social_communities.sql`:

```sql
-- S2 topluluklar ve dönem unvanları: dönem özeti, topluluklar, üyelik, yasaklar,
-- genel sıralama. XP ve kas kuralları yalnız uygulamada; sunucu yayınlanan sayıları gruplar.

alter table public.public_profiles
  add column if not exists compete_globally boolean not null default true;

-- periods: {"week"|"prev_week"|"month"|"prev_month": {"key", "xp", "muscles": {kas: set}}}
create table if not exists public.period_stats (
  user_id uuid primary key references auth.users (id) on delete cascade,
  level int not null,
  rank text not null,
  active_title jsonb,
  periods jsonb not null,
  updated_at timestamptz not null default now()
);

create table if not exists public.communities (
  id uuid primary key default gen_random_uuid(),
  name text not null check (char_length(btrim(name)) between 3 and 40),
  description text not null default '' check (char_length(description) <= 200),
  is_public boolean not null default true,
  invite_code text not null unique default public.new_invite_code(),
  owner uuid not null references auth.users (id) on delete cascade,
  created_at timestamptz not null default now()
);

create table if not exists public.community_members (
  community_id uuid not null references public.communities (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  role text not null check (role in ('owner', 'member')),
  joined_at timestamptz not null default now(),
  primary key (community_id, user_id)
);
create index if not exists community_members_user_idx on public.community_members (user_id);

create table if not exists public.community_bans (
  community_id uuid not null references public.communities (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (community_id, user_id)
);

create or replace function public.is_member(u uuid, c uuid) returns boolean
language sql stable security definer set search_path = public
as $$
  select exists (select 1 from community_members where user_id = u and community_id = c);
$$;

create or replace function public.shares_community(a uuid, b uuid) returns boolean
language sql stable security definer set search_path = public
as $$
  select exists (
    select 1
    from community_members x
    join community_members y on y.community_id = x.community_id
    where x.user_id = a and y.user_id = b
  );
$$;

alter table public.period_stats enable row level security;
alter table public.communities enable row level security;
alter table public.community_members enable row level security;
alter table public.community_bans enable row level security;

-- Ortak topluluktaki kişi de sosyal kimliği (ad, @kullanıcıadı) görür.
drop policy if exists "Profiles visible to self and connections" on public.public_profiles;
create policy "Profiles visible to self and connections"
  on public.public_profiles for select
  using (
    user_id = auth.uid()
    or public.has_friendship(auth.uid(), user_id)
    or public.shares_community(auth.uid(), user_id)
  );

create policy "Period stats visible to self, friends and community members"
  on public.period_stats for select
  using (
    user_id = auth.uid()
    or public.are_friends(auth.uid(), user_id)
    or public.shares_community(auth.uid(), user_id)
  );

create policy "Users insert own period stats"
  on public.period_stats for insert
  with check (user_id = auth.uid());

create policy "Users update own period stats"
  on public.period_stats for update
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

create policy "Public or joined communities are visible"
  on public.communities for select
  using (is_public or public.is_member(auth.uid(), id));

create policy "Owners update their community"
  on public.communities for update
  using (owner = auth.uid())
  with check (owner = auth.uid());

-- Doğrudan güncellenebilen: ad, açıklama, açık/kapalı. Sahip ve kod fonksiyonlarla değişir.
revoke update on public.communities from anon, authenticated;
grant update (name, description, is_public) on public.communities to authenticated;

-- Üyelik ve yasak yazımı yalnız fonksiyonlarla.
create policy "Members see their community's members"
  on public.community_members for select
  using (public.is_member(auth.uid(), community_id));

create policy "Owners see their community's bans"
  on public.community_bans for select
  using (exists (select 1 from public.communities c where c.id = community_id and c.owner = auth.uid()));

create or replace function public.create_community(p_name text, p_description text, p_is_public boolean)
returns uuid
language plpgsql security definer set search_path = public
as $$
declare
  me uuid := auth.uid();
  new_id uuid;
begin
  if me is null then
    raise exception 'not authenticated';
  end if;
  if not exists (select 1 from public_profiles where user_id = me) then
    raise exception 'no_profile';
  end if;
  if (select count(*) from community_members where user_id = me) >= 5 then
    raise exception 'community_limit';
  end if;
  insert into communities (name, description, is_public, owner)
    values (btrim(p_name), btrim(coalesce(p_description, '')), p_is_public, me)
    returning id into new_id;
  insert into community_members (community_id, user_id, role) values (new_id, me, 'owner');
  return new_id;
end;
$$;

-- İç yardımcı: katılma denetimleri; zaten üyeyse sessiz.
create or replace function public.add_community_member(p_id uuid) returns void
language plpgsql security definer set search_path = public
as $$
declare
  me uuid := auth.uid();
begin
  if me is null then
    raise exception 'not authenticated';
  end if;
  if exists (select 1 from community_members where community_id = p_id and user_id = me) then
    return;
  end if;
  if not exists (select 1 from public_profiles where user_id = me) then
    raise exception 'no_profile';
  end if;
  if exists (select 1 from community_bans where community_id = p_id and user_id = me) then
    raise exception 'banned';
  end if;
  if (select count(*) from community_members where community_id = p_id) >= 100 then
    raise exception 'community_full';
  end if;
  if (select count(*) from community_members where user_id = me) >= 5 then
    raise exception 'community_limit';
  end if;
  insert into community_members (community_id, user_id, role) values (p_id, me, 'member');
end;
$$;

create or replace function public.join_community(p_id uuid) returns void
language plpgsql security definer set search_path = public
as $$
begin
  if public.is_member(auth.uid(), p_id) then
    return;
  end if;
  if not exists (select 1 from communities where id = p_id and is_public) then
    raise exception 'not_public';
  end if;
  perform public.add_community_member(p_id);
end;
$$;

-- Kapalı topluluklar dahil; büyük/küçük harf ve boşluk yok sayılır.
create or replace function public.join_community_by_code(p_code text) returns uuid
language plpgsql security definer set search_path = public
as $$
declare
  cid uuid;
begin
  select id into cid from communities where invite_code = upper(btrim(p_code));
  if cid is null then
    raise exception 'unknown_code';
  end if;
  perform public.add_community_member(cid);
  return cid;
end;
$$;

-- Sahip ayrılırsa en eski üye sahip olur; kimse kalmazsa topluluk silinir.
create or replace function public.leave_community(p_id uuid) returns void
language plpgsql security definer set search_path = public
as $$
declare
  me uuid := auth.uid();
  was_owner boolean;
  next_owner uuid;
begin
  if me is null then
    raise exception 'not authenticated';
  end if;
  delete from community_members where community_id = p_id and user_id = me
    returning role = 'owner' into was_owner;
  if not found then
    return;
  end if;
  select user_id into next_owner from community_members
    where community_id = p_id order by joined_at, user_id limit 1;
  if next_owner is null then
    delete from communities where id = p_id;
    return;
  end if;
  if was_owner then
    update community_members set role = 'owner' where community_id = p_id and user_id = next_owner;
    update communities set owner = next_owner where id = p_id;
  end if;
end;
$$;

create or replace function public.remove_member(p_id uuid, p_user uuid, p_ban boolean) returns void
language plpgsql security definer set search_path = public
as $$
declare
  me uuid := auth.uid();
begin
  if me is null then
    raise exception 'not authenticated';
  end if;
  if not exists (select 1 from communities where id = p_id and owner = me) then
    raise exception 'not_owner';
  end if;
  if p_user = me then
    raise exception 'self_remove';
  end if;
  delete from community_members where community_id = p_id and user_id = p_user;
  if p_ban then
    insert into community_bans (community_id, user_id) values (p_id, p_user) on conflict do nothing;
  end if;
end;
$$;

create or replace function public.regenerate_community_code(p_id uuid) returns text
language plpgsql security definer set search_path = public
as $$
declare
  code text;
begin
  if not exists (select 1 from communities where id = p_id and owner = auth.uid()) then
    raise exception 'not_owner';
  end if;
  update communities set invite_code = new_invite_code() where id = p_id returning invite_code into code;
  return code;
end;
$$;

-- Açık topluluklar; sorgu en az 2 karakter; üye sayısına göre, en çok 20.
create or replace function public.search_communities(p_query text)
returns table (id uuid, name text, description text, member_count int, is_member boolean)
language sql stable security definer set search_path = public
as $$
  select c.id, c.name, c.description,
         (select count(*)::int from community_members m where m.community_id = c.id) as member_count,
         exists (select 1 from community_members m where m.community_id = c.id and m.user_id = auth.uid())
  from communities c
  where auth.uid() is not null
    and c.is_public
    and char_length(btrim(p_query)) >= 2
    and c.name ilike '%' || replace(replace(replace(btrim(p_query), '\', '\\'), '%', '\%'), '_', '\_') || '%'
  order by member_count desc, c.name
  limit 20;
$$;

-- p_kind 'week' ise week/prev_week, değilse month/prev_month alanlarından anahtarı
-- eşleşenin değeri ('xp' ya da kas adı); yoksa 0.
create or replace function public.community_period_value(p_periods jsonb, p_kind text, p_key text, p_field text)
returns numeric
language sql immutable set search_path = public
as $$
  select coalesce((
    select case when p_field = 'xp' then (s.slot ->> 'xp')::numeric
                else (s.slot -> 'muscles' ->> p_field)::numeric end
    from jsonb_array_elements(
      case when p_kind = 'week'
        then jsonb_build_array(p_periods -> 'week', p_periods -> 'prev_week')
        else jsonb_build_array(p_periods -> 'month', p_periods -> 'prev_month')
      end) as s(slot)
    where s.slot ->> 'key' = p_key
    limit 1
  ), 0);
$$;

-- Genel yarıştakiler arasında kategori başına en yüksek değer (> 0); eşitlikte hepsi.
create or replace function public.global_titles(p_kind text, p_key text)
returns table (category text, user_id uuid, username text, display_name text, level int, rank text, value numeric)
language sql stable security definer set search_path = public
as $$
  with candidates as (
    select c.cat, p.user_id as uid, p.username as uname, p.display_name as dname,
           s.level as lvl, s.rank as rnk,
           community_period_value(s.periods, p_kind, p_key, c.cat) as val
    from unnest(array['xp', 'abdominals', 'abductors', 'adductors', 'biceps', 'calves', 'chest', 'forearms',
                      'glutes', 'hamstrings', 'lats', 'lower back', 'middle back', 'neck', 'quadriceps',
                      'shoulders', 'traps', 'triceps']) as c(cat)
    cross join period_stats s
    join public_profiles p on p.user_id = s.user_id
    where auth.uid() is not null and p.compete_globally
  ),
  best as (
    select x.cat, max(x.val) as top from candidates x where x.val > 0 group by x.cat
  )
  select x.cat, x.uid, x.uname, x.dname, x.lvl, x.rnk, x.val
  from candidates x
  join best b on b.cat = x.cat and x.val = b.top
  order by x.cat, x.uname;
$$;

-- Genel yarıştakiler arasında dönem XP'sine göre ilk 50 (> 0); eşit XP aynı sıra.
create or replace function public.global_leaderboard(p_kind text, p_key text)
returns table (position int, user_id uuid, username text, display_name text, level int, rank text,
               active_title jsonb, xp int)
language sql stable security definer set search_path = public
as $$
  select (rank() over (order by x.val desc))::int, x.uid, x.uname, x.dname, x.lvl, x.rnk, x.title, x.val::int
  from (
    select p.user_id as uid, p.username as uname, p.display_name as dname, s.level as lvl, s.rank as rnk,
           s.active_title as title, community_period_value(s.periods, p_kind, p_key, 'xp') as val
    from period_stats s
    join public_profiles p on p.user_id = s.user_id
    where auth.uid() is not null and p.compete_globally
  ) x
  where x.val > 0
  order by x.val desc, x.uname
  limit 50;
$$;

revoke execute on function public.is_member(uuid, uuid) from public, anon;
revoke execute on function public.shares_community(uuid, uuid) from public, anon;
revoke execute on function public.create_community(text, text, boolean) from public, anon;
revoke execute on function public.add_community_member(uuid) from public, anon, authenticated;
revoke execute on function public.join_community(uuid) from public, anon;
revoke execute on function public.join_community_by_code(text) from public, anon;
revoke execute on function public.leave_community(uuid) from public, anon;
revoke execute on function public.remove_member(uuid, uuid, boolean) from public, anon;
revoke execute on function public.regenerate_community_code(uuid) from public, anon;
revoke execute on function public.search_communities(text) from public, anon;
revoke execute on function public.community_period_value(jsonb, text, text, text) from public, anon, authenticated;
revoke execute on function public.global_titles(text, text) from public, anon;
revoke execute on function public.global_leaderboard(text, text) from public, anon;

grant execute on function public.is_member(uuid, uuid) to authenticated;
grant execute on function public.shares_community(uuid, uuid) to authenticated;
grant execute on function public.create_community(text, text, boolean) to authenticated;
grant execute on function public.join_community(uuid) to authenticated;
grant execute on function public.join_community_by_code(text) to authenticated;
grant execute on function public.leave_community(uuid) to authenticated;
grant execute on function public.remove_member(uuid, uuid, boolean) to authenticated;
grant execute on function public.regenerate_community_code(uuid) to authenticated;
grant execute on function public.search_communities(text) to authenticated;
grant execute on function public.global_titles(text, text) to authenticated;
grant execute on function public.global_leaderboard(text, text) to authenticated;
```

- [ ] **Step 2: RLS kontrol bloğunu yaz**

`supabase/migrations/checks/s2_rls_checks.sql`:

```sql
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
```

- [ ] **Step 3: Commit**

```bash
git add supabase/migrations/0014_social_communities.sql supabase/migrations/checks/s2_rls_checks.sql
git commit -m "feat(social): add communities, period stats and global boards to the database

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

Not: Migration'ı kullanıcı Task 10'da SQL Editor'da uygular ve kontrol bloğunu çalıştırır; uygulama kodu bu görevden sonra uygulanmamış veritabanına karşı da derlenir ve testlerden geçer (testler sahte depo kullanır).

---

### Task 2: Dönem anahtarları

**Files:**
- Create: `lib/features/social/domain/period_keys.dart`
- Test: `test/features/social/domain/period_keys_test.dart`

**Interfaces:**
- Consumes: `startOfWeek(DateTime)` (`lib/features/progress/domain/weekly_summary.dart`; pazartesi 00:00).
- Produces:
  - `enum PeriodKind { week, month }`
  - `String weekKey(DateTime local)` → `'2026-W41'`
  - `String monthKey(DateTime local)` → `'2026-10'`
  - `({DateTime start, DateTime end}) periodRange(PeriodKind kind, DateTime local, {bool previous = false})` — yerel `[start, end)`
  - `String periodKey(PeriodKind kind, DateTime local, {bool previous = false})`
  - `({int n, bool hours}) periodRemaining(PeriodKind kind, DateTime now)`

- [ ] **Step 1: Testi yaz**

`test/features/social/domain/period_keys_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:spor_takip/features/social/domain/period_keys.dart';

void main() {
  test('ISO week keys, including the 53rd week around the new year', () {
    expect(weekKey(DateTime(2026, 10, 9, 12)), '2026-W41');
    expect(weekKey(DateTime(2025, 12, 29)), '2026-W01');
    expect(weekKey(DateTime(2026, 1, 1)), '2026-W01');
    expect(weekKey(DateTime(2026, 12, 28)), '2026-W53');
    expect(weekKey(DateTime(2026, 12, 31, 23, 59)), '2026-W53');
    expect(weekKey(DateTime(2027, 1, 1)), '2026-W53');
    expect(weekKey(DateTime(2027, 1, 3, 23)), '2026-W53');
    expect(weekKey(DateTime(2027, 1, 4)), '2027-W01');
  });

  test('month keys are zero padded', () {
    expect(monthKey(DateTime(2026, 10, 9)), '2026-10');
    expect(monthKey(DateTime(2027, 1, 1)), '2027-01');
  });

  test('ranges start on Monday / the first and end exclusively', () {
    final now = DateTime(2026, 10, 9, 12);
    expect(periodRange(PeriodKind.week, now), (start: DateTime(2026, 10, 5), end: DateTime(2026, 10, 12)));
    expect(
      periodRange(PeriodKind.week, now, previous: true),
      (start: DateTime(2026, 9, 28), end: DateTime(2026, 10, 5)),
    );
    expect(periodRange(PeriodKind.month, now), (start: DateTime(2026, 10), end: DateTime(2026, 11)));
    expect(
      periodRange(PeriodKind.month, DateTime(2027, 1, 15), previous: true),
      (start: DateTime(2026, 12), end: DateTime(2027, 1)),
    );
  });

  test('period keys for this and the previous period', () {
    final now = DateTime(2026, 10, 9, 12);
    expect(periodKey(PeriodKind.week, now), '2026-W41');
    expect(periodKey(PeriodKind.week, now, previous: true), '2026-W40');
    expect(periodKey(PeriodKind.month, now), '2026-10');
    expect(periodKey(PeriodKind.month, DateTime(2027, 1, 15), previous: true), '2026-12');
    expect(periodKey(PeriodKind.week, DateTime(2027, 1, 4), previous: true), '2026-W53');
  });

  test('remaining time is in days, or in hours on the last day; rounded up, at least 1', () {
    expect(periodRemaining(PeriodKind.week, DateTime(2026, 10, 9, 12)), (n: 3, hours: false));
    expect(periodRemaining(PeriodKind.week, DateTime(2026, 10, 11, 12, 30)), (n: 12, hours: true));
    expect(periodRemaining(PeriodKind.week, DateTime(2026, 10, 11, 23, 59, 30)), (n: 1, hours: true));
    expect(periodRemaining(PeriodKind.month, DateTime(2026, 10, 9, 12)), (n: 23, hours: false));
  });
}
```

- [ ] **Step 2: Testin başarısız olduğunu gör**

Run: `flutter test --no-pub -j 1 test/features/social/domain/period_keys_test.dart`
Expected: FAIL (`period_keys.dart` yok).

- [ ] **Step 3: Uygula**

`lib/features/social/domain/period_keys.dart`:

```dart
import 'dart:math' as math;

import '../../progress/domain/weekly_summary.dart';

/// Sıralama ve unvan dönemi (S2 spec §2.3): ISO hafta (pazartesi) ya da takvim ayı.
enum PeriodKind { week, month }

String _two(int n) => n.toString().padLeft(2, '0');

/// ISO hafta anahtarı: '2026-W41'. Hafta, perşembesinin düştüğü yıla aittir.
String weekKey(DateTime local) {
  final thursday = DateTime.utc(local.year, local.month, local.day + 4 - local.weekday);
  final week = thursday.difference(DateTime.utc(thursday.year)).inDays ~/ 7 + 1;
  return '${thursday.year}-W${_two(week)}';
}

/// '2026-10'.
String monthKey(DateTime local) => '${local.year}-${_two(local.month)}';

/// Yerel `[start, end)`; [previous] true ise bir önceki dönem.
({DateTime start, DateTime end}) periodRange(PeriodKind kind, DateTime local, {bool previous = false}) {
  switch (kind) {
    case PeriodKind.week:
      final current = startOfWeek(local);
      final start = previous ? DateTime(current.year, current.month, current.day - 7) : current;
      return (start: start, end: DateTime(start.year, start.month, start.day + 7));
    case PeriodKind.month:
      final start = DateTime(local.year, local.month - (previous ? 1 : 0));
      return (start: start, end: DateTime(start.year, start.month + 1));
  }
}

String periodKey(PeriodKind kind, DateTime local, {bool previous = false}) {
  final start = periodRange(kind, local, previous: previous).start;
  return kind == PeriodKind.week ? weekKey(start) : monthKey(start);
}

/// Dönem bitişine kalan: 24 saatten azsa saat, değilse gün; ikisi de yukarı yuvarlanır, en az 1.
({int n, bool hours}) periodRemaining(PeriodKind kind, DateTime now) {
  final minutes = periodRange(kind, now).end.difference(now).inMinutes;
  final hours = math.max(1, (minutes / 60).ceil());
  return hours < 24 ? (n: hours, hours: true) : (n: (hours / 24).ceil(), hours: false);
}
```

- [ ] **Step 4: Testin geçtiğini gör**

Run: `flutter test --no-pub -j 1 test/features/social/domain/period_keys_test.dart`
Expected: PASS (5 test).

- [ ] **Step 5: Commit**

```bash
git add lib/features/social/domain/period_keys.dart test/features/social/domain/period_keys_test.dart
git commit -m "feat(social): add ISO week and month period keys

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 3: Dönem özeti (`PeriodStats`)

**Files:**
- Create: `lib/features/social/domain/period_stats.dart`
- Test: `test/features/social/domain/period_stats_test.dart`

**Interfaces:**
- Consumes: Task 2 (`PeriodKind`, `periodRange`, `periodKey`); `xpEvents(sessions, mealTimes)` (`XpEvent.date` yerel, `.xp`); `muscleWeight(Exercise, String)`; `muscleGroups`; `PlayerSummary` (`progress.level`, `rank`, `titleById(String?)` → `TitleProgress?` with `kind`, `subjectId`, `exerciseName`, `tier`); `SharedTitle` (`player_stats.dart`, `toJson`, `static fromJson`).
- Produces:
  - `class PeriodSlot { String key; int xp; Map<String, double> muscles; double valueOf(String category); toJson(); factory fromJson(Map<String, dynamic>?) }` — `fromJson(null)` → `key: ''`.
  - `class PeriodStats { int level; Rank rank; SharedTitle? activeTitle; PeriodSlot week, prevWeek, month, prevMonth; DateTime? updatedAt; PeriodSlot? slotFor(PeriodKind, String key); double valueFor(PeriodKind, String key, String category); toJson(); factory fromJson; ==/hashCode (updatedAt hariç) }`
  - `PeriodStats buildPeriodStats({required PlayerSummary summary, required List<WorkoutSession> sessions, required List<DateTime> mealTimes, required Map<String, Exercise> exercisesById, required DateTime now, required String? activeTitleId})`

- [ ] **Step 1: Testi yaz**

`test/features/social/domain/period_stats_test.dart`:

```dart
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:spor_takip/features/gamification/domain/levels.dart';
import 'package:spor_takip/features/gamification/domain/player_summary.dart';
import 'package:spor_takip/features/social/domain/period_keys.dart';
import 'package:spor_takip/features/social/domain/period_stats.dart';

import '../../gamification/game_fixtures.dart';

final _now = DateTime(2026, 10, 9, 12);

// W41 = 5–11 Ekim, W40 = 28 Eylül–4 Ekim.
final _sessions = [
  gameSession('a', DateTime(2026, 10, 8, 18), gameSets('bench', 3)), // W41: 65 XP
  gameSession('d', DateTime(2026, 10, 5), gameSets('squat', 1)), // W41 sınırı: 55 XP
  gameSession('b', DateTime(2026, 10, 4, 23, 59), gameSets('squat', 2)), // W40: 60 XP
  gameSession('c', DateTime(2026, 9, 20, 10), gameSets('bench', 1)), // Eylül: 55 XP
  gameSession('open', null, gameSets('bench', 4)), // bitmemiş: sayılmaz
];
final _meals = [DateTime(2026, 10, 9, 8)]; // W41: 10 XP

PeriodStats _build() => buildPeriodStats(
      summary: playerSummary(_sessions, _meals, gameExercisesById),
      sessions: _sessions,
      mealTimes: _meals,
      exercisesById: gameExercisesById,
      now: _now,
      activeTitleId: null,
    );

void main() {
  test('fills this and the previous week and month', () {
    final stats = _build();
    expect(stats.level, playerSummary(_sessions, _meals, gameExercisesById).progress.level);
    expect(stats.activeTitle, isNull);

    expect(stats.week.key, '2026-W41');
    expect(stats.week.xp, 130);
    expect(stats.week.muscles, {'chest': 3.0, 'triceps': 1.5, 'quadriceps': 1.0});

    expect(stats.prevWeek.key, '2026-W40');
    expect(stats.prevWeek.xp, 60);
    expect(stats.prevWeek.muscles, {'quadriceps': 2.0});

    expect(stats.month.key, '2026-10');
    expect(stats.month.xp, 190);
    expect(stats.month.muscles, {'chest': 3.0, 'triceps': 1.5, 'quadriceps': 3.0});

    expect(stats.prevMonth.key, '2026-09');
    expect(stats.prevMonth.xp, 55);
    expect(stats.prevMonth.muscles, {'chest': 1.0, 'triceps': 0.5});
  });

  test('slotFor matches either field of the kind and nothing else', () {
    final stats = _build();
    expect(stats.slotFor(PeriodKind.week, '2026-W40')?.xp, 60);
    expect(stats.slotFor(PeriodKind.week, '2026-W41')?.xp, 130);
    expect(stats.slotFor(PeriodKind.week, '2026-W39'), isNull);
    expect(stats.slotFor(PeriodKind.month, '2026-W41'), isNull);
    expect(stats.valueFor(PeriodKind.month, '2026-10', 'quadriceps'), 3);
    expect(stats.valueFor(PeriodKind.month, '2026-09', 'xp'), 55);
    expect(stats.valueFor(PeriodKind.week, '2026-W39', 'xp'), 0);
    expect(stats.valueFor(PeriodKind.week, '2026-W41', 'lats'), 0);
  });

  test('JSON round trip keeps equality; updatedAt is ignored; muscles are sorted', () {
    final stats = _build();
    final json = jsonDecode(jsonEncode(stats.toJson())) as Map<String, dynamic>;
    final back = PeriodStats.fromJson({...json, 'updated_at': '2026-10-09T09:00:00Z'});
    expect(back, stats);
    expect(back.hashCode, stats.hashCode);
    expect(back.updatedAt, isNotNull);
    final week = (json['periods'] as Map<String, dynamic>)['week'] as Map<String, dynamic>;
    expect((week['muscles'] as Map<String, dynamic>).keys.toList(), ['chest', 'quadriceps', 'triceps']);
  });

  test('missing fields fall back to defaults', () {
    final stats = PeriodStats.fromJson({'level': 2, 'rank': 'nope', 'periods': <String, dynamic>{}});
    expect(stats.level, 2);
    expect(stats.rank, Rank.rookie);
    expect(stats.week.key, '');
    expect(stats.prevMonth.xp, 0);
    expect(stats.slotFor(PeriodKind.week, '2026-W41'), isNull);
  });
}
```

- [ ] **Step 2: Testin başarısız olduğunu gör**

Run: `flutter test --no-pub -j 1 test/features/social/domain/period_stats_test.dart`
Expected: FAIL (`period_stats.dart` yok).

- [ ] **Step 3: Uygula**

`lib/features/social/domain/period_stats.dart`:

```dart
import 'dart:convert';

import '../../gamification/domain/levels.dart';
import '../../gamification/domain/player_summary.dart';
import '../../gamification/domain/xp_rules.dart';
import '../../workout/domain/exercise.dart';
import '../../workout/domain/exercise_taxonomy.dart';
import '../../workout/domain/muscle_heat.dart';
import '../../workout/domain/workout_session.dart';
import 'period_keys.dart';
import 'player_stats.dart';

/// Bir dönemin XP'si ve kas başına ağırlıklı set sayısı.
class PeriodSlot {
  const PeriodSlot({required this.key, this.xp = 0, this.muscles = const {}});

  /// '2026-W41' ya da '2026-10'; yayın yoksa ''.
  final String key;
  final int xp;
  final Map<String, double> muscles;

  /// [category]: 'xp' ya da kas adı.
  double valueOf(String category) => category == 'xp' ? xp.toDouble() : muscles[category] ?? 0;

  Map<String, dynamic> toJson() => {
        'key': key,
        'xp': xp,
        'muscles': {for (final muscle in muscles.keys.toList()..sort()) muscle: muscles[muscle]},
      };

  factory PeriodSlot.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const PeriodSlot(key: '');
    final muscles = json['muscles'] as Map<String, dynamic>? ?? const {};
    return PeriodSlot(
      key: json['key'] as String? ?? '',
      xp: (json['xp'] as num?)?.toInt() ?? 0,
      muscles: {
        for (final MapEntry(key: muscle, value: sets) in muscles.entries) muscle: (sets as num).toDouble(),
      },
    );
  }
}

/// `period_stats` satırı (S2 spec §3.1). Eşitlik `updatedAt`'i saymaz:
/// içerik değişmediyse yeniden yazılmaz.
class PeriodStats {
  const PeriodStats({
    required this.level,
    required this.rank,
    required this.week,
    required this.prevWeek,
    required this.month,
    required this.prevMonth,
    this.activeTitle,
    this.updatedAt,
  });

  final int level;
  final Rank rank;
  final SharedTitle? activeTitle;
  final PeriodSlot week;
  final PeriodSlot prevWeek;
  final PeriodSlot month;
  final PeriodSlot prevMonth;
  final DateTime? updatedAt;

  /// Haftada `week`/`prevWeek`, ayda `month`/`prevMonth` alanlarından anahtarı eşleşen;
  /// yoksa null (eski yayın → o dönemde 0).
  PeriodSlot? slotFor(PeriodKind kind, String key) {
    final candidates = kind == PeriodKind.week ? [week, prevWeek] : [month, prevMonth];
    return candidates.where((s) => s.key == key).firstOrNull;
  }

  double valueFor(PeriodKind kind, String key, String category) => slotFor(kind, key)?.valueOf(category) ?? 0;

  Map<String, dynamic> toJson() => {
        'level': level,
        'rank': rank.name,
        'active_title': activeTitle?.toJson(),
        'periods': {
          'week': week.toJson(),
          'prev_week': prevWeek.toJson(),
          'month': month.toJson(),
          'prev_month': prevMonth.toJson(),
        },
      };

  factory PeriodStats.fromJson(Map<String, dynamic> json) {
    final periods = json['periods'] as Map<String, dynamic>? ?? const {};
    final active = json['active_title'] as Map<String, dynamic>?;
    final updatedAt = json['updated_at'] as String?;
    PeriodSlot slot(String name) => PeriodSlot.fromJson(periods[name] as Map<String, dynamic>?);
    return PeriodStats(
      level: (json['level'] as num?)?.toInt() ?? 1,
      rank: Rank.values.asNameMap()[json['rank']] ?? Rank.rookie,
      activeTitle: active == null ? null : SharedTitle.fromJson(active),
      week: slot('week'),
      prevWeek: slot('prev_week'),
      month: slot('month'),
      prevMonth: slot('prev_month'),
      updatedAt: updatedAt == null ? null : DateTime.parse(updatedAt).toLocal(),
    );
  }

  String get _canonical => jsonEncode(toJson());

  @override
  bool operator ==(Object other) => other is PeriodStats && other._canonical == _canonical;

  @override
  int get hashCode => _canonical.hashCode;
}

/// Uygulamanın yayınlayacağı satır (S2 spec §4): `now`'a göre bu ve önceki hafta/ay.
/// XP: tarihi dönemde olan XP olayları. Kas: bitişi dönemde olan oturumların
/// tamamlanmış setleri × `muscleWeight` (yalnız `muscleGroups`).
PeriodStats buildPeriodStats({
  required PlayerSummary summary,
  required List<WorkoutSession> sessions,
  required List<DateTime> mealTimes,
  required Map<String, Exercise> exercisesById,
  required DateTime now,
  required String? activeTitleId,
}) {
  final events = xpEvents(sessions, mealTimes);

  PeriodSlot slot(PeriodKind kind, {bool previous = false}) {
    final range = periodRange(kind, now, previous: previous);
    bool inRange(DateTime t) => !t.isBefore(range.start) && t.isBefore(range.end);
    var xp = 0;
    for (final e in events) {
      if (inRange(e.date)) xp += e.xp;
    }
    final muscles = <String, double>{};
    for (final session in sessions) {
      final finished = session.finishedAt?.toLocal();
      if (finished == null || !inRange(finished)) continue;
      for (final set in session.sets) {
        if (!set.isCompleted) continue;
        final exercise = exercisesById[set.exerciseId];
        if (exercise == null) continue;
        for (final muscle in muscleGroups) {
          final weight = muscleWeight(exercise, muscle);
          if (weight > 0) muscles[muscle] = (muscles[muscle] ?? 0) + weight;
        }
      }
    }
    return PeriodSlot(key: periodKey(kind, now, previous: previous), xp: xp, muscles: muscles);
  }

  final active = summary.titleById(activeTitleId);
  return PeriodStats(
    level: summary.progress.level,
    rank: summary.rank,
    activeTitle: active == null
        ? null
        : SharedTitle(
            kind: active.kind,
            subjectId: active.subjectId,
            exerciseName: active.exerciseName,
            tier: active.tier!,
          ),
    week: slot(PeriodKind.week),
    prevWeek: slot(PeriodKind.week, previous: true),
    month: slot(PeriodKind.month),
    prevMonth: slot(PeriodKind.month, previous: true),
  );
}
```

- [ ] **Step 4: Testin geçtiğini gör**

Run: `flutter test --no-pub -j 1 test/features/social/domain/period_stats_test.dart`
Expected: PASS (4 test).

- [ ] **Step 5: Commit**

```bash
git add lib/features/social/domain/period_stats.dart test/features/social/domain/period_stats_test.dart
git commit -m "feat(social): compute weekly and monthly XP and muscle sets for publishing

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 4: Sıralama, unvanlar ve topluluk modelleri

**Files:**
- Create: `lib/features/social/domain/standings.dart`
- Create: `lib/features/social/domain/community.dart`
- Modify: `lib/features/social/domain/public_profile.dart` (`competeGlobally`)
- Modify: `test/features/social/social_fixtures.dart` (`socialPeriod`)
- Test: `test/features/social/domain/standings_test.dart`
- Test: `test/features/social/domain/community_models_test.dart`

**Interfaces:**
- Consumes: Task 2–3 (`PeriodKind`, `PeriodStats.valueFor`, `PeriodSlot`); `muscleGroups`; `Rank`; `SharedTitle.fromJson`; `initialsOf`.
- Produces:
  - `const periodCategories = <String>['xp', ...muscleGroups];`
  - `class Standing { String userId; int xp; int position; }` ve `List<Standing> standings(Map<String, PeriodStats> members, PeriodKind kind, String key)` — XP > 0, büyükten küçüğe (eşitlikte userId), eşit XP aynı sıra.
  - `class PeriodTitle { String category; List<String> holders; double value; }` ve `List<PeriodTitle> periodTitles(Map<String, PeriodStats> members, PeriodKind kind, String key)` — değer > 0, `periodCategories` sırası, eşitlikte tüm sahipler (userId sırasıyla).
  - `class CommunityException implements Exception { const CommunityException(this.code); final String code; }`, `const communityErrorCodes` (Set<String>), `const maxCommunities = 5`.
  - `Community {id, name, description, isPublic, inviteCode, owner; fromJson; copyWith({name, description, isPublic, inviteCode})}`
  - `CommunityMember {communityId, userId, isOwner, joinedAt; fromJson}`
  - `CommunitySearchResult {id, name, description, memberCount, isMember; fromJson}`
  - `GlobalTitle {category, userId, username, displayName, level, rank, value; fromJson}`
  - `GlobalRow {position, userId, username, displayName, level, rank, activeTitle, xp; initials; fromJson}`
  - `PublicProfile.competeGlobally` (varsayılan true; `fromJson` `'compete_globally'`; `copyWith(competeGlobally:)`).
  - Fikstür: `PeriodStats socialPeriod({int level = 31, Rank rank = Rank.determined, int week = 0, Map<String, double> weekMuscles = const {}, String weekSlotKey = '2026-W41', int prevWeek = 0, Map<String, double> prevWeekMuscles = const {}, int month = 0, int prevMonth = 0, SharedTitle? activeTitle})` — anahtarlar `now = 2026-10-09`'a göre: `2026-W41`, `2026-W40`, `2026-10`, `2026-09`.

- [ ] **Step 1: Fikstürü ekle**

`test/features/social/social_fixtures.dart` — importlara ekle:

```dart
import 'package:spor_takip/features/social/domain/period_stats.dart';
```

Dosyanın sonuna ekle:

```dart
/// `now = 2026-10-09` için dönem özeti: W41 / W40 / 2026-10 / 2026-09.
PeriodStats socialPeriod({
  int level = 31,
  Rank rank = Rank.determined,
  int week = 0,
  Map<String, double> weekMuscles = const {},
  String weekSlotKey = '2026-W41',
  int prevWeek = 0,
  Map<String, double> prevWeekMuscles = const {},
  int month = 0,
  int prevMonth = 0,
  SharedTitle? activeTitle,
}) =>
    PeriodStats(
      level: level,
      rank: rank,
      activeTitle: activeTitle,
      week: PeriodSlot(key: weekSlotKey, xp: week, muscles: weekMuscles),
      prevWeek: PeriodSlot(key: '2026-W40', xp: prevWeek, muscles: prevWeekMuscles),
      month: PeriodSlot(key: '2026-10', xp: month),
      prevMonth: PeriodSlot(key: '2026-09', xp: prevMonth),
    );
```

- [ ] **Step 2: Testleri yaz**

`test/features/social/domain/standings_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:spor_takip/features/social/domain/period_keys.dart';
import 'package:spor_takip/features/social/domain/standings.dart';

import '../social_fixtures.dart';

final _members = {
  'me': socialPeriod(week: 640, weekMuscles: {'lats': 10}),
  'ayse': socialPeriod(week: 1420, weekMuscles: {'lats': 14.5, 'chest': 9}, prevWeek: 900),
  'burak': socialPeriod(week: 640, weekMuscles: {'lats': 14.5}, prevWeek: 900, prevWeekMuscles: {'chest': 4}),
  'can': socialPeriod(),
  'deniz': socialPeriod(week: 5000, weekSlotKey: '2026-W39'), // eski yayın
  'eda': socialPeriod(week: 100),
};

void main() {
  test('standings: XP > 0, highest first, equal XP shares a position', () {
    final rows = standings(_members, PeriodKind.week, '2026-W41');
    expect([for (final s in rows) (s.userId, s.position, s.xp)], [
      ('ayse', 1, 1420),
      ('burak', 2, 640),
      ('me', 2, 640),
      ('eda', 4, 100),
    ]);
  });

  test('standings for the previous week read the prev_week field', () {
    final rows = standings(_members, PeriodKind.week, '2026-W40');
    expect([for (final s in rows) (s.userId, s.position)], [('ayse', 1), ('burak', 1)]);
    expect(standings(_members, PeriodKind.month, '2026-10'), isEmpty);
  });

  test('titles: XP first then muscle order; all holders on a tie; zero values left out', () {
    final titles = periodTitles(_members, PeriodKind.week, '2026-W41');
    expect([for (final t in titles) (t.category, t.holders.join(','), t.value)], [
      ('xp', 'ayse', 1420.0),
      ('chest', 'ayse', 9.0),
      ('lats', 'ayse,burak', 14.5),
    ]);
  });

  test('previous week titles', () {
    final titles = periodTitles(_members, PeriodKind.week, '2026-W40');
    expect([for (final t in titles) (t.category, t.holders.join(','))], [
      ('xp', 'ayse,burak'),
      ('chest', 'burak'),
    ]);
    expect(periodTitles(const {}, PeriodKind.week, '2026-W40'), isEmpty);
  });

  test('categories are XP plus the 17 muscle groups', () {
    expect(periodCategories.first, 'xp');
    expect(periodCategories, hasLength(18));
  });
}
```

`test/features/social/domain/community_models_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:spor_takip/features/gamification/domain/levels.dart';
import 'package:spor_takip/features/gamification/domain/titles.dart';
import 'package:spor_takip/features/social/domain/community.dart';
import 'package:spor_takip/features/social/domain/public_profile.dart';

void main() {
  test('community, member and search result rows', () {
    final community = Community.fromJson({
      'id': 'c1',
      'name': 'Demir Kulübü',
      'description': 'Sabah 6 ekibi',
      'is_public': false,
      'invite_code': 'Q7M2K9TA',
      'owner': 'me',
    });
    expect(community.isPublic, isFalse);
    expect(community.inviteCode, 'Q7M2K9TA');
    final edited = community.copyWith(name: 'Demir', isPublic: true);
    expect((edited.id, edited.name, edited.description, edited.isPublic, edited.owner),
        ('c1', 'Demir', 'Sabah 6 ekibi', true, 'me'));

    final member = CommunityMember.fromJson({
      'community_id': 'c1',
      'user_id': 'ayse',
      'role': 'owner',
      'joined_at': '2026-10-01T09:00:00Z',
    });
    expect((member.communityId, member.userId, member.isOwner), ('c1', 'ayse', true));
    expect(member.joinedAt.isUtc, isFalse);

    final result = CommunitySearchResult.fromJson({
      'id': 'c1',
      'name': 'Demir Kulübü',
      'description': null,
      'member_count': 24,
      'is_member': true,
    });
    expect((result.description, result.memberCount, result.isMember), ('', 24, true));
  });

  test('global title and row', () {
    final title = GlobalTitle.fromJson({
      'category': 'lats',
      'user_id': 'ayse',
      'username': 'ayse_k',
      'display_name': 'Ayşe Kaya',
      'level': 42,
      'rank': 'gladiator',
      'value': 41.5,
    });
    expect((title.category, title.level, title.rank, title.value), ('lats', 42, Rank.gladiator, 41.5));

    final row = GlobalRow.fromJson({
      'position': 3,
      'user_id': 'ayse',
      'username': 'ayse_k',
      'display_name': 'Ayşe Kaya',
      'level': 42,
      'rank': 'unknown',
      'active_title': {'kind': 'muscle', 'subject_id': 'lats', 'tier': 'champion'},
      'xp': 4120,
    });
    expect((row.position, row.rank, row.xp, row.initials), (3, Rank.rookie, 4120, 'AK'));
    expect(row.activeTitle?.tier, TitleTier.champion);
  });

  test('community exception keeps its code', () {
    expect(const CommunityException('banned').code, 'banned');
    expect(communityErrorCodes, containsAll(['community_limit', 'unknown_code', 'not_owner']));
    expect(maxCommunities, 5);
  });

  test('profiles compete globally unless the row says otherwise', () {
    const base = {'user_id': 'me', 'username': 'samet_fit', 'display_name': 'Samet'};
    expect(PublicProfile.fromJson(base).competeGlobally, isTrue);
    final out = PublicProfile.fromJson({...base, 'compete_globally': false});
    expect(out.competeGlobally, isFalse);
    expect(out.copyWith(competeGlobally: true).competeGlobally, isTrue);
    expect(out.copyWith(displayName: 'S').competeGlobally, isFalse);
  });
}
```

- [ ] **Step 3: Testlerin başarısız olduğunu gör**

Run: `flutter test --no-pub -j 1 test/features/social/domain/standings_test.dart test/features/social/domain/community_models_test.dart`
Expected: FAIL (dosyalar yok, `competeGlobally` yok).

- [ ] **Step 4: `standings.dart`'ı yaz**

`lib/features/social/domain/standings.dart`:

```dart
import '../../workout/domain/exercise_taxonomy.dart';
import 'period_keys.dart';
import 'period_stats.dart';

/// Unvan kategorileri gösterim sırasıyla: genel XP ("Yıldız") ve 17 kas.
const periodCategories = <String>['xp', ...muscleGroups];

class Standing {
  const Standing({required this.userId, required this.xp, required this.position});

  final String userId;
  final int xp;

  /// 1'den; eşit XP aynı sıra (1, 2, 2, 4).
  final int position;
}

/// Dönem XP'si > 0 olanlar, büyükten küçüğe; eşitlikte userId sırası.
List<Standing> standings(Map<String, PeriodStats> members, PeriodKind kind, String key) {
  final rows = [
    for (final MapEntry(key: id, value: stats) in members.entries)
      if (stats.valueFor(kind, key, 'xp').toInt() case final xp when xp > 0) (id: id, xp: xp),
  ]..sort((a, b) {
      final byXp = b.xp.compareTo(a.xp);
      return byXp != 0 ? byXp : a.id.compareTo(b.id);
    });
  final result = <Standing>[];
  for (var i = 0; i < rows.length; i++) {
    final position = i > 0 && rows[i].xp == rows[i - 1].xp ? result[i - 1].position : i + 1;
    result.add(Standing(userId: rows[i].id, xp: rows[i].xp, position: position));
  }
  return result;
}

class PeriodTitle {
  const PeriodTitle({required this.category, required this.holders, required this.value});

  /// 'xp' ya da kas adı.
  final String category;

  /// Eşitlikte birden çok; userId sırasıyla.
  final List<String> holders;
  final double value;
}

/// Kategori başına en yüksek değer (> 0) ve sahipleri; [periodCategories] sırasıyla.
List<PeriodTitle> periodTitles(Map<String, PeriodStats> members, PeriodKind kind, String key) {
  final result = <PeriodTitle>[];
  for (final category in periodCategories) {
    var best = 0.0;
    final holders = <String>[];
    for (final MapEntry(key: id, value: stats) in members.entries) {
      final value = stats.valueFor(kind, key, category);
      if (value <= 0 || value < best) continue;
      if (value > best) {
        best = value;
        holders.clear();
      }
      holders.add(id);
    }
    if (holders.isNotEmpty) result.add(PeriodTitle(category: category, holders: holders..sort(), value: best));
  }
  return result;
}
```

- [ ] **Step 5: `community.dart`'ı yaz**

`lib/features/social/domain/community.dart`:

```dart
import '../../gamification/domain/levels.dart';
import 'player_stats.dart';
import 'public_profile.dart';

/// Topluluk fonksiyonunun hata kodu (S2 spec §5); ekran koda göre metin gösterir.
class CommunityException implements Exception {
  const CommunityException(this.code);

  final String code;

  @override
  String toString() => 'CommunityException($code)';
}

/// Sunucunun `raise exception` ile döndürdüğü, metni olan kodlar.
const communityErrorCodes = {
  'community_limit',
  'community_full',
  'banned',
  'not_public',
  'unknown_code',
  'no_profile',
  'not_owner',
};

/// Kişi başı topluluk sınırı (S2 spec §2.7).
const maxCommunities = 5;

class Community {
  const Community({
    required this.id,
    required this.name,
    required this.description,
    required this.isPublic,
    required this.inviteCode,
    required this.owner,
  });

  final String id;
  final String name;
  final String description;
  final bool isPublic;
  final String inviteCode;
  final String owner;

  factory Community.fromJson(Map<String, dynamic> json) => Community(
        id: json['id'] as String,
        name: json['name'] as String,
        description: json['description'] as String? ?? '',
        isPublic: json['is_public'] as bool? ?? true,
        inviteCode: json['invite_code'] as String? ?? '',
        owner: json['owner'] as String,
      );

  Community copyWith({String? name, String? description, bool? isPublic, String? inviteCode}) => Community(
        id: id,
        name: name ?? this.name,
        description: description ?? this.description,
        isPublic: isPublic ?? this.isPublic,
        inviteCode: inviteCode ?? this.inviteCode,
        owner: owner,
      );
}

class CommunityMember {
  const CommunityMember({
    required this.communityId,
    required this.userId,
    required this.isOwner,
    required this.joinedAt,
  });

  final String communityId;
  final String userId;
  final bool isOwner;
  final DateTime joinedAt;

  factory CommunityMember.fromJson(Map<String, dynamic> json) => CommunityMember(
        communityId: json['community_id'] as String,
        userId: json['user_id'] as String,
        isOwner: json['role'] == 'owner',
        joinedAt: DateTime.parse(json['joined_at'] as String).toLocal(),
      );
}

/// `search_communities` satırı.
class CommunitySearchResult {
  const CommunitySearchResult({
    required this.id,
    required this.name,
    required this.description,
    required this.memberCount,
    required this.isMember,
  });

  final String id;
  final String name;
  final String description;
  final int memberCount;
  final bool isMember;

  factory CommunitySearchResult.fromJson(Map<String, dynamic> json) => CommunitySearchResult(
        id: json['id'] as String,
        name: json['name'] as String,
        description: json['description'] as String? ?? '',
        memberCount: (json['member_count'] as num?)?.toInt() ?? 0,
        isMember: json['is_member'] as bool? ?? false,
      );
}

/// `global_titles` satırı: bir kategorinin (eşitlikte birden çok) sahibi.
class GlobalTitle {
  const GlobalTitle({
    required this.category,
    required this.userId,
    required this.username,
    required this.displayName,
    required this.level,
    required this.rank,
    required this.value,
  });

  final String category;
  final String userId;
  final String username;
  final String displayName;
  final int level;
  final Rank rank;
  final double value;

  factory GlobalTitle.fromJson(Map<String, dynamic> json) => GlobalTitle(
        category: json['category'] as String,
        userId: json['user_id'] as String,
        username: json['username'] as String,
        displayName: json['display_name'] as String,
        level: (json['level'] as num?)?.toInt() ?? 1,
        rank: Rank.values.asNameMap()[json['rank']] ?? Rank.rookie,
        value: (json['value'] as num?)?.toDouble() ?? 0,
      );
}

/// `global_leaderboard` satırı.
class GlobalRow {
  const GlobalRow({
    required this.position,
    required this.userId,
    required this.username,
    required this.displayName,
    required this.level,
    required this.rank,
    required this.xp,
    this.activeTitle,
  });

  final int position;
  final String userId;
  final String username;
  final String displayName;
  final int level;
  final Rank rank;
  final SharedTitle? activeTitle;
  final int xp;

  String get initials => initialsOf(displayName, username);

  factory GlobalRow.fromJson(Map<String, dynamic> json) {
    final active = json['active_title'] as Map<String, dynamic>?;
    return GlobalRow(
      position: (json['position'] as num).toInt(),
      userId: json['user_id'] as String,
      username: json['username'] as String,
      displayName: json['display_name'] as String,
      level: (json['level'] as num?)?.toInt() ?? 1,
      rank: Rank.values.asNameMap()[json['rank']] ?? Rank.rookie,
      activeTitle: active == null ? null : SharedTitle.fromJson(active),
      xp: (json['xp'] as num?)?.toInt() ?? 0,
    );
  }
}
```

- [ ] **Step 6: `PublicProfile`'a `competeGlobally` ekle**

`lib/features/social/domain/public_profile.dart` — `PublicProfile` sınıfı:

Constructor'a `this.shareHeat = true,` satırından sonra:

```dart
    this.competeGlobally = true,
```

Alanlara `final bool shareHeat;` satırından sonra:

```dart
  /// Genel sıralamada ve genel unvanlarda yer alır (S2 spec §2.6).
  final bool competeGlobally;
```

`fromJson`'da `shareHeat: ...` satırından sonra:

```dart
        competeGlobally: json['compete_globally'] as bool? ?? true,
```

`copyWith` imzasına `bool? shareHeat,` satırından sonra `bool? competeGlobally,` ekle ve gövdede `shareHeat: shareHeat ?? this.shareHeat,` satırından sonra:

```dart
        competeGlobally: competeGlobally ?? this.competeGlobally,
```

- [ ] **Step 7: Testlerin geçtiğini gör**

Run: `flutter test --no-pub -j 1 test/features/social/domain/standings_test.dart test/features/social/domain/community_models_test.dart test/features/social/domain/social_models_test.dart`
Expected: PASS.

- [ ] **Step 8: Commit**

```bash
git add lib/features/social/domain/standings.dart lib/features/social/domain/community.dart lib/features/social/domain/public_profile.dart test/features/social/social_fixtures.dart test/features/social/domain/standings_test.dart test/features/social/domain/community_models_test.dart
git commit -m "feat(social): add period standings, period titles and community models

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 5: Depo, sağlayıcılar ve dönem yayını

**Files:**
- Modify: `lib/features/social/data/social_repository.dart`
- Modify: `lib/features/social/application/social_providers.dart`
- Create: `lib/features/social/application/community_providers.dart`
- Modify: `test/features/social/fakes.dart`
- Modify: `test/features/social/social_fixtures.dart`
- Modify: `test/features/social/application/social_providers_test.dart`
- Test: `test/features/social/application/community_providers_test.dart`

**Interfaces:**
- Consumes: Task 2–4; S1 `SocialRepository`, `myPublicProfileProvider`, `socialRepositoryProvider`, `statsSyncProvider`, `SocialActions`; `nowProvider` (`lib/features/workout/application/session_providers.dart`).
- Produces:
  - `SocialRepository`'ye: `fetchMyCommunityIds()`, `fetchCommunities(List<String> ids)`, `fetchMembers(List<String> communityIds) → Map<String, List<CommunityMember>>` (katılma sırasıyla), `searchCommunities(String)`, `createCommunity({name, description, isPublic}) → String`, `joinCommunity(String)`, `joinCommunityByCode(String) → String`, `leaveCommunity(String)`, `updateCommunity(String id, {String? name, String? description, bool? isPublic})`, `removeMember(String communityId, String userId, {required bool ban})`, `regenerateCommunityCode(String) → String`, `fetchPeriodStats(List<String>) → Map<String, PeriodStats>`, `upsertMyPeriodStats(PeriodStats)`, `globalTitles(PeriodKind, String key)`, `globalLeaderboard(PeriodKind, String key)`; `updateProfile(..., bool? competeGlobally)`. Topluluk fonksiyonu hataları `CommunityException(code)`.
  - `social_providers.dart`: `lastPublishedPeriodStatsProvider`; `statsSyncProvider` iki satırı ayrı ayrı yalnız değişince yazar; `SocialActions.updateProfile(..., bool? competeGlobally)`.
  - `community_providers.dart`: `CommunityEntry {community, memberCount, myPosition}`, `myCommunitiesProvider` (`FutureProvider.autoDispose<List<CommunityEntry>>`, ada göre), `CommunityDetail {community, members, profiles, stats, myId, iAmOwner}`, `communityDetailProvider` (`FutureProvider.autoDispose.family<CommunityDetail?, String>`; üye değilsem null; `profiles` kendimi içerir), `GlobalBoard {titles, rows}`, `globalBoardProvider` (`FutureProvider.autoDispose.family<GlobalBoard, PeriodKind>`; geçen dönemin unvanları + bu dönemin ilk 50'si), `CommunityActions` (`create`, `join`, `joinByCode`, `leave`, `update`, `removeMember`, `regenerateCode`), `communityActionsProvider`.
  - Test: `FakeSocialRepository` yeni parametreler `communities`, `members`, `periodStats`; kayıtlar `periodUpserts`, `joined`, `left`, `memberRemovals`, `globalQueries`; ayarlar `searchResults`, `globalTitlesResult`, `globalRowsResult`, `communityError`. Kurulan topluluk kimliği `'new'` (kod `'NEWCMTY2'`), yenilenen kod `'R3GENKQ2'`. Fikstürler `socialCommunity` (`c1`, sahip `me`), `socialCommunity2` (`c2`, kapalı, sahip `ayse`, kod `AYSETKM2`), `socialCommunity3` (`c3`, sahip `me`), `socialMember(communityId, userId, {owner, day})`.

- [ ] **Step 1: Depoyu genişlet**

`lib/features/social/data/social_repository.dart`:

Importları şöyle yap:

```dart
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/community.dart';
import '../domain/friendship.dart';
import '../domain/period_keys.dart';
import '../domain/period_stats.dart';
import '../domain/player_stats.dart';
import '../domain/public_profile.dart';
```

Arayüzdeki `updateProfile` imzasına `bool? shareHeat,` satırından sonra `bool? competeGlobally,` ekle. Arayüzün sonuna (`upsertMyStats` satırından sonra) ekle:

```dart
  Future<List<String>> fetchMyCommunityIds();
  Future<List<Community>> fetchCommunities(List<String> ids);

  /// Topluluk → üyeler (katılma sırasıyla).
  Future<Map<String, List<CommunityMember>>> fetchMembers(List<String> communityIds);
  Future<List<CommunitySearchResult>> searchCommunities(String query);

  /// Yeni topluluğun kimliği.
  Future<String> createCommunity({required String name, required String description, required bool isPublic});
  Future<void> joinCommunity(String id);

  /// Katılınan topluluğun kimliği.
  Future<String> joinCommunityByCode(String code);
  Future<void> leaveCommunity(String id);
  Future<void> updateCommunity(String id, {String? name, String? description, bool? isPublic});
  Future<void> removeMember(String communityId, String userId, {required bool ban});
  Future<String> regenerateCommunityCode(String id);
  Future<Map<String, PeriodStats>> fetchPeriodStats(List<String> userIds);
  Future<void> upsertMyPeriodStats(PeriodStats stats);
  Future<List<GlobalTitle>> globalTitles(PeriodKind kind, String key);
  Future<List<GlobalRow>> globalLeaderboard(PeriodKind kind, String key);
```

`SupabaseSocialRepository` içinde `_profileColumns`'u şöyle değiştir:

```dart
  static const _profileColumns =
      'user_id, username, display_name, invite_code, share_weekly, share_workouts, share_heat, compete_globally';
  static const _communityColumns = 'id, name, description, is_public, invite_code, owner';
```

`updateProfile` uygulamasının imzasına `bool? competeGlobally,` ekle ve güncellenen haritaya `'share_heat': ?shareHeat,` satırından sonra:

```dart
            'compete_globally': ?competeGlobally,
```

Sınıfın sonuna (`upsertMyStats`'tan sonra) ekle:

```dart
  /// Topluluk fonksiyonunun `raise exception '<kod>'` hatasını [CommunityException]'a çevirir.
  Future<T> _community<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on PostgrestException catch (e) {
      if (communityErrorCodes.contains(e.message)) throw CommunityException(e.message);
      rethrow;
    }
  }

  @override
  Future<List<String>> fetchMyCommunityIds() async {
    final rows = await _client.from('community_members').select('community_id').eq('user_id', _me);
    return [for (final row in rows) row['community_id'] as String];
  }

  @override
  Future<List<Community>> fetchCommunities(List<String> ids) async {
    if (ids.isEmpty) return const [];
    final rows = await _client.from('communities').select(_communityColumns).inFilter('id', ids);
    return [for (final row in rows) Community.fromJson(row)];
  }

  @override
  Future<Map<String, List<CommunityMember>>> fetchMembers(List<String> communityIds) async {
    if (communityIds.isEmpty) return const {};
    final rows = await _client
        .from('community_members')
        .select('community_id, user_id, role, joined_at')
        .inFilter('community_id', communityIds)
        .order('joined_at');
    final result = <String, List<CommunityMember>>{};
    for (final row in rows) {
      final member = CommunityMember.fromJson(row);
      (result[member.communityId] ??= []).add(member);
    }
    return result;
  }

  @override
  Future<List<CommunitySearchResult>> searchCommunities(String query) async {
    final rows = await _client.rpc('search_communities', params: {'p_query': query}) as List? ?? const [];
    return [for (final row in rows) CommunitySearchResult.fromJson(row as Map<String, dynamic>)];
  }

  @override
  Future<String> createCommunity({required String name, required String description, required bool isPublic}) =>
      _community(() async => await _client.rpc('create_community', params: {
            'p_name': name,
            'p_description': description,
            'p_is_public': isPublic,
          }) as String);

  @override
  Future<void> joinCommunity(String id) => _community(() async {
        await _client.rpc('join_community', params: {'p_id': id});
      });

  @override
  Future<String> joinCommunityByCode(String code) =>
      _community(() async => await _client.rpc('join_community_by_code', params: {'p_code': code}) as String);

  @override
  Future<void> leaveCommunity(String id) => _community(() async {
        await _client.rpc('leave_community', params: {'p_id': id});
      });

  @override
  Future<void> updateCommunity(String id, {String? name, String? description, bool? isPublic}) async {
    await _client.from('communities').update({
      'name': ?name?.trim(),
      'description': ?description?.trim(),
      'is_public': ?isPublic,
    }).eq('id', id);
  }

  @override
  Future<void> removeMember(String communityId, String userId, {required bool ban}) => _community(() async {
        await _client.rpc('remove_member', params: {'p_id': communityId, 'p_user': userId, 'p_ban': ban});
      });

  @override
  Future<String> regenerateCommunityCode(String id) =>
      _community(() async => await _client.rpc('regenerate_community_code', params: {'p_id': id}) as String);

  @override
  Future<Map<String, PeriodStats>> fetchPeriodStats(List<String> userIds) async {
    if (userIds.isEmpty) return const {};
    final rows = await _client.from('period_stats').select().inFilter('user_id', userIds);
    return {for (final row in rows) row['user_id'] as String: PeriodStats.fromJson(row)};
  }

  @override
  Future<void> upsertMyPeriodStats(PeriodStats stats) async {
    await _client.from('period_stats').upsert({
      ...stats.toJson(),
      'user_id': _me,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  @override
  Future<List<GlobalTitle>> globalTitles(PeriodKind kind, String key) async {
    final rows = await _client.rpc('global_titles', params: {'p_kind': kind.name, 'p_key': key}) as List? ?? const [];
    return [for (final row in rows) GlobalTitle.fromJson(row as Map<String, dynamic>)];
  }

  @override
  Future<List<GlobalRow>> globalLeaderboard(PeriodKind kind, String key) async {
    final rows =
        await _client.rpc('global_leaderboard', params: {'p_kind': kind.name, 'p_key': key}) as List? ?? const [];
    return [for (final row in rows) GlobalRow.fromJson(row as Map<String, dynamic>)];
  }
```

- [ ] **Step 2: Sahte depoyu ve fikstürleri güncelle**

`test/features/social/fakes.dart`'ı tamamen şununla değiştir:

```dart
import 'package:spor_takip/features/social/data/social_repository.dart';
import 'package:spor_takip/features/social/domain/community.dart';
import 'package:spor_takip/features/social/domain/friendship.dart';
import 'package:spor_takip/features/social/domain/period_keys.dart';
import 'package:spor_takip/features/social/domain/period_stats.dart';
import 'package:spor_takip/features/social/domain/player_stats.dart';
import 'package:spor_takip/features/social/domain/public_profile.dart';

class FakeSocialRepository implements SocialRepository {
  FakeSocialRepository({
    this.me,
    List<PublicProfile> others = const [],
    List<Friendship> friendships = const [],
    Map<String, PlayerStats> stats = const {},
    Set<String> taken = const {},
    List<Community> communities = const [],
    Map<String, List<CommunityMember>> members = const {},
    Map<String, PeriodStats> periodStats = const {},
  })  : others = {for (final p in others) p.userId: p},
        friendships = [...friendships],
        stats = {...stats},
        taken = {...taken},
        communities = {for (final c in communities) c.id: c},
        members = {for (final MapEntry(key: id, value: list) in members.entries) id: [...list]},
        periodStats = {...periodStats};

  PublicProfile? me;
  final Map<String, PublicProfile> others;
  final List<Friendship> friendships;
  final Map<String, PlayerStats> stats;
  final Set<String> taken;
  final Map<String, Community> communities;
  final Map<String, List<CommunityMember>> members;
  final Map<String, PeriodStats> periodStats;
  final List<PlayerStats> upserts = [];
  final List<PeriodStats> periodUpserts = [];
  final List<String> sent = [];
  final List<(String, bool)> responses = [];
  final List<String> removed = [];
  final List<String> joined = [];
  final List<String> left = [];
  final List<(String, String, bool)> memberRemovals = [];
  final List<(PeriodKind, String)> globalQueries = [];
  List<CommunitySearchResult> searchResults = [];
  List<GlobalTitle> globalTitlesResult = [];
  List<GlobalRow> globalRowsResult = [];
  String sendResult = 'pending';
  Object? error;

  /// Kurma ve katılma bunu fırlatır.
  CommunityException? communityError;

  String get _myId => me?.userId ?? 'me';

  void _maybeThrow() {
    if (error case final e?) throw e;
  }

  void _throwCommunityError() {
    if (communityError case final e?) throw e;
  }

  void _addMe(String communityId, {bool owner = false}) {
    final list = members[communityId] ??= [];
    if (list.any((m) => m.userId == _myId)) return;
    list.add(CommunityMember(communityId: communityId, userId: _myId, isOwner: owner, joinedAt: DateTime(2026, 10, 9)));
  }

  @override
  Future<PublicProfile?> fetchMyProfile() async {
    _maybeThrow();
    return me;
  }

  @override
  Future<PublicProfile> createProfile({required String username, required String displayName}) async {
    if (taken.contains(username)) throw UsernameTakenException();
    return me = PublicProfile(userId: 'me', username: username, displayName: displayName, inviteCode: 'K7Q2M9XA');
  }

  @override
  Future<PublicProfile> updateProfile({
    String? username,
    String? displayName,
    bool? shareWeekly,
    bool? shareWorkouts,
    bool? shareHeat,
    bool? competeGlobally,
  }) async {
    if (username != null && taken.contains(username)) throw UsernameTakenException();
    return me = me!.copyWith(
      username: username,
      displayName: displayName,
      shareWeekly: shareWeekly,
      shareWorkouts: shareWorkouts,
      shareHeat: shareHeat,
      competeGlobally: competeGlobally,
    );
  }

  @override
  Future<bool> usernameAvailable(String username) async => !taken.contains(username);

  @override
  Future<FoundUser?> findByUsername(String username) async {
    for (final p in others.values) {
      if (p.username == username) {
        return FoundUser(userId: p.userId, username: p.username, displayName: p.displayName);
      }
    }
    return null;
  }

  @override
  Future<FoundUser?> findByInviteCode(String code) async {
    for (final p in others.values) {
      if (p.inviteCode == code.trim().toUpperCase()) {
        return FoundUser(userId: p.userId, username: p.username, displayName: p.displayName);
      }
    }
    return null;
  }

  @override
  Future<List<Friendship>> fetchFriendships() async {
    _maybeThrow();
    return [...friendships];
  }

  @override
  Future<String> sendRequest(String targetId) async {
    sent.add(targetId);
    return sendResult;
  }

  @override
  Future<void> respond(String requesterId, {required bool accept}) async {
    responses.add((requesterId, accept));
    final index = friendships.indexWhere((f) => f.requester == requesterId && !f.accepted);
    if (index < 0) return;
    if (accept) {
      final f = friendships[index];
      friendships[index] =
          Friendship(requester: f.requester, addressee: f.addressee, accepted: true, createdAt: f.createdAt);
    } else {
      friendships.removeAt(index);
    }
  }

  @override
  Future<void> removeFriend(String otherId) async {
    removed.add(otherId);
    friendships.removeWhere((f) => f.requester == otherId || f.addressee == otherId);
  }

  @override
  Future<List<PublicProfile>> fetchProfiles(List<String> userIds) async => [
        for (final id in userIds)
          ?others[id],
      ];

  @override
  Future<Map<String, PlayerStats>> fetchStats(List<String> userIds) async => {
        for (final id in userIds)
          id: ?stats[id],
      };

  @override
  Future<void> upsertMyStats(PlayerStats stats) async => upserts.add(stats);

  @override
  Future<List<String>> fetchMyCommunityIds() async {
    _maybeThrow();
    return [
      for (final MapEntry(key: id, value: list) in members.entries)
        if (list.any((m) => m.userId == _myId)) id,
    ];
  }

  @override
  Future<List<Community>> fetchCommunities(List<String> ids) async => [
        for (final id in ids)
          ?communities[id],
      ];

  @override
  Future<Map<String, List<CommunityMember>>> fetchMembers(List<String> communityIds) async => {
        for (final id in communityIds)
          if (members[id] case final list?) id: [...list],
      };

  @override
  Future<List<CommunitySearchResult>> searchCommunities(String query) async => [...searchResults];

  @override
  Future<String> createCommunity({required String name, required String description, required bool isPublic}) async {
    _throwCommunityError();
    communities['new'] = Community(
      id: 'new',
      name: name,
      description: description,
      isPublic: isPublic,
      inviteCode: 'NEWCMTY2',
      owner: _myId,
    );
    _addMe('new', owner: true);
    return 'new';
  }

  @override
  Future<void> joinCommunity(String id) async {
    _throwCommunityError();
    joined.add(id);
    _addMe(id);
  }

  @override
  Future<String> joinCommunityByCode(String code) async {
    _throwCommunityError();
    final community = communities.values.where((c) => c.inviteCode == code.trim().toUpperCase()).firstOrNull;
    if (community == null) throw const CommunityException('unknown_code');
    joined.add(community.id);
    _addMe(community.id);
    return community.id;
  }

  @override
  Future<void> leaveCommunity(String id) async {
    left.add(id);
    members[id]?.removeWhere((m) => m.userId == _myId);
  }

  @override
  Future<void> updateCommunity(String id, {String? name, String? description, bool? isPublic}) async {
    communities[id] = communities[id]!.copyWith(name: name, description: description, isPublic: isPublic);
  }

  @override
  Future<void> removeMember(String communityId, String userId, {required bool ban}) async {
    memberRemovals.add((communityId, userId, ban));
    members[communityId]?.removeWhere((m) => m.userId == userId);
  }

  @override
  Future<String> regenerateCommunityCode(String id) async {
    communities[id] = communities[id]!.copyWith(inviteCode: 'R3GENKQ2');
    return 'R3GENKQ2';
  }

  @override
  Future<Map<String, PeriodStats>> fetchPeriodStats(List<String> userIds) async => {
        for (final id in userIds)
          id: ?periodStats[id],
      };

  @override
  Future<void> upsertMyPeriodStats(PeriodStats stats) async => periodUpserts.add(stats);

  @override
  Future<List<GlobalTitle>> globalTitles(PeriodKind kind, String key) async {
    globalQueries.add((kind, key));
    return [...globalTitlesResult];
  }

  @override
  Future<List<GlobalRow>> globalLeaderboard(PeriodKind kind, String key) async {
    globalQueries.add((kind, key));
    return [...globalRowsResult];
  }
}
```

`test/features/social/social_fixtures.dart` — importlara ekle:

```dart
import 'package:spor_takip/features/social/domain/community.dart';
```

Dosyanın sonuna ekle:

```dart
const socialCommunity = Community(
  id: 'c1',
  name: 'Demir Kulübü',
  description: 'Sabah 6 ekibi',
  isPublic: true,
  inviteCode: 'Q7M2K9TA',
  owner: 'me',
);
const socialCommunity2 = Community(
  id: 'c2',
  name: 'Ayşe Takımı',
  description: '',
  isPublic: false,
  inviteCode: 'AYSETKM2',
  owner: 'ayse',
);
const socialCommunity3 = Community(
  id: 'c3',
  name: 'Akşamcılar',
  description: '',
  isPublic: true,
  inviteCode: 'AKSAMC23',
  owner: 'me',
);

/// [day]: Ekim 2026'da katılma günü (sıra için).
CommunityMember socialMember(String communityId, String userId, {bool owner = false, int day = 1}) =>
    CommunityMember(communityId: communityId, userId: userId, isOwner: owner, joinedAt: DateTime(2026, 10, day));
```

- [ ] **Step 3: Sağlayıcı testlerini yaz**

`test/features/social/application/community_providers_test.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spor_takip/features/onboarding/application/auth_providers.dart';
import 'package:spor_takip/features/social/application/community_providers.dart';
import 'package:spor_takip/features/social/application/social_providers.dart';
import 'package:spor_takip/features/social/domain/community.dart';
import 'package:spor_takip/features/social/domain/period_keys.dart';
import 'package:spor_takip/features/workout/application/session_providers.dart';

import '../fakes.dart';
import '../social_fixtures.dart';

ProviderContainer _container(FakeSocialRepository repo) {
  final container = ProviderContainer(overrides: [
    isLoggedInProvider.overrideWithValue(true),
    socialRepositoryProvider.overrideWithValue(repo),
    nowProvider.overrideWithValue(() => DateTime(2026, 10, 9, 12)),
  ]);
  addTearDown(container.dispose);
  return container;
}

FakeSocialRepository _repo() => FakeSocialRepository(
      me: socialMe,
      others: [socialAyse, socialBurak],
      communities: [socialCommunity, socialCommunity2, socialCommunity3],
      members: {
        'c1': [
          socialMember('c1', 'me', owner: true),
          socialMember('c1', 'ayse', day: 2),
          socialMember('c1', 'burak', day: 3),
        ],
        'c2': [socialMember('c2', 'ayse', owner: true)],
        'c3': [socialMember('c3', 'me', owner: true)],
      },
      periodStats: {
        'me': socialPeriod(week: 640),
        'ayse': socialPeriod(week: 1420),
        'burak': socialPeriod(),
      },
    );

void main() {
  test('my communities are sorted by name with member count and my weekly position', () async {
    final container = _container(_repo());
    container.listen(myCommunitiesProvider, (_, _) {});
    final entries = await container.read(myCommunitiesProvider.future);
    expect([for (final e in entries) (e.community.id, e.memberCount, e.myPosition)], [
      ('c3', 1, 1),
      ('c1', 3, 2),
    ]);
  });

  test('without a social profile there are no communities', () async {
    final container = _container(FakeSocialRepository());
    container.listen(myCommunitiesProvider, (_, _) {});
    expect(await container.read(myCommunitiesProvider.future), isEmpty);
  });

  test('community detail has members, profiles (me included) and stats; null if not a member', () async {
    final container = _container(_repo());
    container.listen(communityDetailProvider('c1'), (_, _) {});
    container.listen(communityDetailProvider('c2'), (_, _) {});
    container.listen(communityDetailProvider('nope'), (_, _) {});

    final detail = (await container.read(communityDetailProvider('c1').future))!;
    expect(detail.community.name, 'Demir Kulübü');
    expect([for (final m in detail.members) m.userId], ['me', 'ayse', 'burak']);
    expect(detail.profiles.keys, containsAll(['me', 'ayse', 'burak']));
    expect(detail.stats['ayse']?.week.xp, 1420);
    expect(detail.iAmOwner, isTrue);
    expect(detail.myId, 'me');

    expect(await container.read(communityDetailProvider('c2').future), isNull);
    expect(await container.read(communityDetailProvider('nope').future), isNull);
  });

  test('the global board asks for last period titles and this period standings', () async {
    final repo = _repo();
    final container = _container(repo);
    container.listen(globalBoardProvider(PeriodKind.week), (_, _) {});
    await container.read(globalBoardProvider(PeriodKind.week).future);
    expect(repo.globalQueries, [(PeriodKind.week, '2026-W40'), (PeriodKind.week, '2026-W41')]);

    repo.globalQueries.clear();
    container.listen(globalBoardProvider(PeriodKind.month), (_, _) {});
    await container.read(globalBoardProvider(PeriodKind.month).future);
    expect(repo.globalQueries, [(PeriodKind.month, '2026-09'), (PeriodKind.month, '2026-10')]);
  });

  test('actions refresh my communities; errors keep their code', () async {
    final repo = _repo();
    final container = _container(repo);
    container.listen(myCommunitiesProvider, (_, _) {});
    final actions = container.read(communityActionsProvider);
    Future<List<String>> ids() async =>
        [for (final e in await container.read(myCommunitiesProvider.future)) e.community.id];

    expect(await ids(), ['c3', 'c1']);
    expect(await actions.joinByCode('aysetkm2'), 'c2');
    expect(await ids(), ['c3', 'c2', 'c1']);

    await actions.leave('c1');
    expect(await ids(), ['c3', 'c2']);
    expect(repo.left, ['c1']);

    expect(await actions.create(name: 'Demir', description: '', isPublic: true), 'new');
    expect(await ids(), contains('new'));

    repo.communityError = const CommunityException('community_limit');
    await expectLater(
      actions.join('c9'),
      throwsA(isA<CommunityException>().having((e) => e.code, 'code', 'community_limit')),
    );
  });
}
```

`test/features/social/application/social_providers_test.dart` — `main()` içinde son testten sonra ekle:

```dart
  test('period stats are published once per change', () async {
    final repo = FakeSocialRepository(me: socialMe);
    final container = _container(repo);
    container.listen(statsSyncProvider, (_, _) {});

    await container.read(statsSyncProvider.future);
    expect(repo.periodUpserts, hasLength(1));
    final period = repo.periodUpserts.single;
    expect(period.week.key, '2026-W41');
    expect(period.week.xp, 75);
    expect(period.week.muscles, {'chest': 3.0, 'triceps': 1.5});
    expect(period.prevMonth.key, '2026-09');

    container.invalidate(statsSyncProvider);
    await container.read(statsSyncProvider.future);
    expect(repo.periodUpserts, hasLength(1));
    expect(repo.upserts, hasLength(1));
  });
```

- [ ] **Step 4: Testlerin başarısız olduğunu gör**

Run: `flutter test --no-pub -j 1 test/features/social/application/community_providers_test.dart test/features/social/application/social_providers_test.dart`
Expected: FAIL (`community_providers.dart` yok, dönem yayını yok).

- [ ] **Step 5: `social_providers.dart`'ı güncelle**

`lib/features/social/application/social_providers.dart`:

Importlara ekle:

```dart
import '../domain/period_stats.dart';
```

`lastPublishedStatsProvider` tanımından sonra ekle:

```dart
/// Son yayınlanan dönem özeti (bellekte); aynıysa yeniden yazılmaz.
class LastPublishedPeriodStats extends Notifier<PeriodStats?> {
  @override
  PeriodStats? build() => null;

  void remember(PeriodStats stats) => state = stats;
}

final lastPublishedPeriodStatsProvider =
    NotifierProvider<LastPublishedPeriodStats, PeriodStats?>(LastPublishedPeriodStats.new);
```

`statsSyncProvider`'ı tamamen şununla değiştir:

```dart
/// Kendi `player_stats` (S1 spec §5) ve `period_stats` (S2 spec §5) satırlarımı
/// yayınlar; her biri yalnız değişince yazılır. `AppShell` izler; hata loglanır.
final statsSyncProvider = FutureProvider.autoDispose<void>((ref) async {
  final profile = await ref.watch(myPublicProfileProvider.future);
  if (profile == null) return;
  final (summary, sessions, mealTimes, exercisesById, activeTitleId) = await (
    ref.watch(playerSummaryProvider.future),
    ref.watch(allSessionsProvider.future),
    ref.watch(mealTimesProvider.future),
    ref.watch(exercisesByIdProvider.future),
    ref.watch(activeTitleProvider.future),
  ).wait;
  final now = ref.read(nowProvider)();
  final repo = ref.read(socialRepositoryProvider);
  final stats = buildPlayerStats(
    summary: summary,
    sessions: sessions,
    mealTimes: mealTimes,
    exercisesById: exercisesById,
    now: now,
    activeTitleId: activeTitleId,
    privacy: SharedPrivacy(weekly: profile.shareWeekly, workouts: profile.shareWorkouts, heat: profile.shareHeat),
  );
  if (ref.read(lastPublishedStatsProvider) != stats) {
    try {
      await repo.upsertMyStats(stats);
      ref.read(lastPublishedStatsProvider.notifier).remember(stats);
    } catch (e, st) {
      debugPrint('statsSync failed: $e\n$st');
    }
  }
  final period = buildPeriodStats(
    summary: summary,
    sessions: sessions,
    mealTimes: mealTimes,
    exercisesById: exercisesById,
    now: now,
    activeTitleId: activeTitleId,
  );
  if (ref.read(lastPublishedPeriodStatsProvider) != period) {
    try {
      await repo.upsertMyPeriodStats(period);
      ref.read(lastPublishedPeriodStatsProvider.notifier).remember(period);
    } catch (e, st) {
      debugPrint('periodStatsSync failed: $e\n$st');
    }
  }
});
```

`SocialActions.updateProfile`'ı şununla değiştir:

```dart
  Future<PublicProfile> updateProfile({
    String? username,
    String? displayName,
    bool? shareWeekly,
    bool? shareWorkouts,
    bool? shareHeat,
    bool? competeGlobally,
  }) async {
    final profile = await _repo.updateProfile(
      username: username,
      displayName: displayName,
      shareWeekly: shareWeekly,
      shareWorkouts: shareWorkouts,
      shareHeat: shareHeat,
      competeGlobally: competeGlobally,
    );
    _ref.invalidate(myPublicProfileProvider);
    return profile;
  }
```

- [ ] **Step 6: `community_providers.dart`'ı yaz**

`lib/features/social/application/community_providers.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../workout/application/session_providers.dart';
import '../data/social_repository.dart';
import '../domain/community.dart';
import '../domain/period_keys.dart';
import '../domain/period_stats.dart';
import '../domain/public_profile.dart';
import '../domain/standings.dart';
import 'social_providers.dart';

/// "Topluluklarım" satırı (S2 spec §6.2).
class CommunityEntry {
  const CommunityEntry({required this.community, required this.memberCount, this.myPosition});

  final Community community;
  final int memberCount;

  /// Bu haftaki sıram; sıralamada yoksam null.
  final int? myPosition;
}

/// Üyesi olduğum topluluklar, ada göre; kimlik yoksa boş.
final myCommunitiesProvider = FutureProvider.autoDispose<List<CommunityEntry>>((ref) async {
  final me = await ref.watch(myPublicProfileProvider.future);
  if (me == null) return const [];
  final repo = ref.watch(socialRepositoryProvider);
  final ids = await repo.fetchMyCommunityIds();
  final (communities, members) = await (repo.fetchCommunities(ids), repo.fetchMembers(ids)).wait;
  final stats = await repo.fetchPeriodStats([
    ...{
      for (final list in members.values)
        for (final m in list) m.userId,
    },
  ]);
  final key = periodKey(PeriodKind.week, ref.read(nowProvider)());
  final entries = <CommunityEntry>[];
  for (final community in communities) {
    final list = members[community.id] ?? const <CommunityMember>[];
    final memberStats = {
      for (final m in list)
        if (stats[m.userId] case final s?) m.userId: s,
    };
    final mine = standings(memberStats, PeriodKind.week, key).where((s) => s.userId == me.userId).firstOrNull;
    entries.add(CommunityEntry(community: community, memberCount: list.length, myPosition: mine?.position));
  }
  return entries..sort((a, b) => a.community.name.toLowerCase().compareTo(b.community.name.toLowerCase()));
});

class CommunityDetail {
  const CommunityDetail({
    required this.community,
    required this.members,
    required this.profiles,
    required this.stats,
    required this.myId,
  });

  final Community community;

  /// Katılma sırasıyla.
  final List<CommunityMember> members;

  /// Kendi profilim dahil.
  final Map<String, PublicProfile> profiles;

  /// Yayın yapmamış üye yok.
  final Map<String, PeriodStats> stats;
  final String myId;

  bool get iAmOwner => community.owner == myId;
}

/// Üye değilsem (ya da topluluk yoksa) null.
final communityDetailProvider = FutureProvider.autoDispose.family<CommunityDetail?, String>((ref, id) async {
  final me = await ref.watch(myPublicProfileProvider.future);
  if (me == null) return null;
  final repo = ref.watch(socialRepositoryProvider);
  final (communities, members) = await (repo.fetchCommunities([id]), repo.fetchMembers([id])).wait;
  final community = communities.firstOrNull;
  final list = members[id] ?? const <CommunityMember>[];
  if (community == null || !list.any((m) => m.userId == me.userId)) return null;
  final ids = [for (final m in list) m.userId];
  final (profiles, stats) = await (repo.fetchProfiles(ids), repo.fetchPeriodStats(ids)).wait;
  return CommunityDetail(
    community: community,
    members: list,
    profiles: {for (final p in profiles) p.userId: p, me.userId: me},
    stats: stats,
    myId: me.userId,
  );
});

class GlobalBoard {
  const GlobalBoard({this.titles = const [], this.rows = const []});

  /// Geçen dönemin genel unvanları.
  final List<GlobalTitle> titles;

  /// Bu dönemin ilk 50'si.
  final List<GlobalRow> rows;
}

final globalBoardProvider = FutureProvider.autoDispose.family<GlobalBoard, PeriodKind>((ref, kind) async {
  final me = await ref.watch(myPublicProfileProvider.future);
  if (me == null) return const GlobalBoard();
  final repo = ref.watch(socialRepositoryProvider);
  final now = ref.read(nowProvider)();
  final (titles, rows) = await (
    repo.globalTitles(kind, periodKey(kind, now, previous: true)),
    repo.globalLeaderboard(kind, periodKey(kind, now)),
  ).wait;
  return GlobalBoard(titles: titles, rows: rows);
});

/// Topluluk yazma işlemleri; her biri ilgili sağlayıcıları yeniler.
class CommunityActions {
  CommunityActions(this._ref);

  final Ref _ref;

  SocialRepository get _repo => _ref.read(socialRepositoryProvider);

  void _refresh(String id) {
    _ref.invalidate(myCommunitiesProvider);
    _ref.invalidate(communityDetailProvider(id));
  }

  Future<String> create({required String name, required String description, required bool isPublic}) async {
    final id = await _repo.createCommunity(name: name, description: description, isPublic: isPublic);
    _refresh(id);
    return id;
  }

  Future<void> join(String id) async {
    await _repo.joinCommunity(id);
    _refresh(id);
  }

  Future<String> joinByCode(String code) async {
    final id = await _repo.joinCommunityByCode(code);
    _refresh(id);
    return id;
  }

  Future<void> leave(String id) async {
    await _repo.leaveCommunity(id);
    _refresh(id);
  }

  Future<void> update(String id, {String? name, String? description, bool? isPublic}) async {
    await _repo.updateCommunity(id, name: name, description: description, isPublic: isPublic);
    _refresh(id);
  }

  Future<void> removeMember(String communityId, String userId, {required bool ban}) async {
    await _repo.removeMember(communityId, userId, ban: ban);
    _refresh(communityId);
  }

  Future<String> regenerateCode(String id) async {
    final code = await _repo.regenerateCommunityCode(id);
    _refresh(id);
    return code;
  }
}

final communityActionsProvider = Provider<CommunityActions>(CommunityActions.new);
```

- [ ] **Step 7: Testlerin geçtiğini gör**

Run: `flutter test --no-pub -j 1 test/features/social/application/community_providers_test.dart test/features/social/application/social_providers_test.dart`
Expected: PASS.

Run: `flutter test --no-pub -j 1 test/features/social/presentation/social_screen_test.dart test/features/social/presentation/social_settings_screen_test.dart`
Expected: PASS (S1 ekranları yeni sahte depoyla bozulmadı).

- [ ] **Step 8: Commit**

```bash
git add lib/features/social/data/social_repository.dart lib/features/social/application/social_providers.dart lib/features/social/application/community_providers.dart test/features/social/fakes.dart test/features/social/social_fixtures.dart test/features/social/application/community_providers_test.dart test/features/social/application/social_providers_test.dart
git commit -m "feat(social): add community data, providers and period stats publishing

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 6: Çeviriler ve dönem bileşenleri

**Files:**
- Modify: `assets/translations/tr.json`, `assets/translations/en.json`
- Create: `lib/features/social/presentation/widgets/period_widgets.dart`
- Test: `test/features/social/presentation/period_widgets_test.dart`

**Interfaces:**
- Consumes: Task 2 (`PeriodKind`, `periodRemaining`); `taxonomySlug`; `formatSets`; `titleName`; `RankBadge`; `SocialAvatar`, `TitlePill`; `SharedTitle.asProgress`; `upperCaseFor`; `AppFonts.heading`.
- Produces:
  - `String periodTitleName(PeriodKind kind, String category)` — `'social.period_star_<kind>'` ya da `'social.period_title_<kind>'` (`{name}` = kas kısa adı).
  - `String periodValueLabel(String category, double value)` — `'social.value_xp'` / `'social.value_sets'` (`{n}`).
  - `String periodRemainingLabel(PeriodKind kind, DateTime now)`.
  - `String? sharedTitleName(SharedTitle? title)`.
  - `PeriodSwitch({required PeriodKind kind, required ValueChanged<PeriodKind> onChanged, required String keyPrefix})` — segment etiketlerinin anahtarı `'<keyPrefix>_week'`, `'<keyPrefix>_month'`.
  - `TitleLine({required String category, required List<String> holders, required double value})`, `PeriodTitlesList({required PeriodKind kind, required List<TitleLine> lines})` — satır anahtarı `'title_<category>'`.
  - `StandingLine({required userId, required position, required name, required initials, required level, required rank, required xp, String? handle, String? title, bool isMe = false})`, `StandingsList({required List<StandingLine> lines})` — satır `'standing_<userId>'`, benim etiketim `'standing_me_label'`.
  - Çeviri anahtarları (`social.` altında): aşağıdaki Step 1 listesi; hata metinleri `social.community_error.<kod>`.

- [ ] **Step 1: Türkçe çevirileri ekle**

`assets/translations/tr.json` — `social` bloğundaki son satır

```json
    "privacy_note": "Seviye, rütbe ve unvanlar her zaman görünür. Kilo, ölçü ve beslenme asla paylaşılmaz."
```

şununla değiştir:

```json
    "privacy_note": "Seviye, rütbe ve unvanlar her zaman görünür. Kilo, ölçü ve beslenme asla paylaşılmaz.",
    "tab_friends": "Arkadaşlar",
    "tab_communities": "Topluluklar",
    "tab_global": "Genel",
    "community_create": "TOPLULUK KUR",
    "community_join": "KATIL",
    "community_limit_note": "En çok 5 topluluğa üye olabilirsin",
    "my_communities": "Topluluklarım",
    "communities_empty": "Henüz bir topluluğun yok — kur ya da katıl",
    "community_members": "{n} üye",
    "community_position": "{p}. / {n}",
    "community_form_title": "Topluluk kur",
    "community_edit_title": "Topluluğu düzenle",
    "community_name_label": "Ad",
    "community_name_short": "En az 3 karakter",
    "community_description_label": "Açıklama",
    "community_public": "Herkese açık",
    "community_public_note": "Açık topluluklar adla aranabilir; kapalı topluluğa yalnız davet koduyla katılınır.",
    "community_form_save": "OLUŞTUR",
    "community_form_update": "KAYDET",
    "join_title": "Topluluğa katıl",
    "join_privacy_note": "Katıldığında üyeler adını, seviyeni, takılı unvanını ve dönem XP'ni görür; antrenman ayrıntıların yalnız arkadaşlarına açık kalır.",
    "join_mode_search": "Ara",
    "join_mode_code": "Davet kodu",
    "join_search_hint": "Topluluk adı",
    "join_code_hint": "8 karakterlik kod",
    "join_no_results": "Topluluk bulunamadı",
    "join_member": "Üyesin",
    "join_button": "KATIL",
    "community_error": {
      "community_limit": "En çok 5 topluluğa üye olabilirsin",
      "community_full": "Topluluk dolu (100 üye)",
      "banned": "Bu topluluğa katılamazsın",
      "not_public": "Bu topluluk kapalı — davet koduyla katıl",
      "unknown_code": "Bu kodla bir topluluk yok",
      "no_profile": "Önce sosyal kimliğini oluştur",
      "not_owner": "Bunu yalnız topluluk sahibi yapabilir"
    },
    "community_public_badge": "Açık",
    "community_private_badge": "Kapalı",
    "community_code_label": "Davet kodu",
    "community_invite_text": "LevelUp Fit'te {name} topluluğuna katıl — kod: {code}",
    "period_week": "Hafta",
    "period_month": "Ay",
    "titles_prev_week": "Geçen haftanın şampiyonları",
    "titles_prev_month": "Geçen ayın şampiyonları",
    "titles_empty": "Geçen dönemden şampiyon yok",
    "standings_week": "Bu hafta · canlı",
    "standings_month": "Bu ay · canlı",
    "standings_empty": "Bu dönemde henüz XP yok",
    "period_remaining_hours": "{n} saat kaldı",
    "period_remaining_days": "{n} gün kaldı",
    "your_rank": "Senin sıran",
    "muscle_leaders": "Kas liderleri",
    "muscle_leaders_empty": "Bu dönemde henüz kas seti yok",
    "period_title_week": "Haftanın {name} Şampiyonu",
    "period_title_month": "Ayın {name} Şampiyonu",
    "period_star_week": "Haftanın Yıldızı",
    "period_star_month": "Ayın Yıldızı",
    "value_xp": "{n} XP",
    "value_sets": "{n} set",
    "community_leave": "Topluluktan ayrıl",
    "community_leave_title": "Topluluktan ayrılınsın mı?",
    "community_leave_body": "Sıralamadan çıkarsın; istediğinde yeniden katılabilirsin.",
    "community_leave_owner_body": "Yönetim en eski üyeye geçer.",
    "community_leave_last_body": "Son üye sensin; topluluk silinir.",
    "community_leave_confirm": "AYRIL",
    "community_edit": "Düzenle",
    "community_regenerate": "Kodu yenile",
    "community_regenerated": "Yeni davet kodu: {code}",
    "community_manage": "Üyeleri yönet",
    "community_not_member": "Bu topluluğun üyesi değilsin",
    "manage_title": "Üyeler",
    "manage_remove": "ÇIKAR",
    "manage_ban": "YASAKLA",
    "manage_remove_title": "{name} çıkarılsın mı?",
    "manage_ban_title": "{name} yasaklansın mı?",
    "manage_ban_body": "Yasaklanan kişi davet koduyla da geri katılamaz.",
    "manage_confirm": "ONAYLA",
    "global_titles_week": "Geçen haftanın genel şampiyonları",
    "global_titles_month": "Geçen ayın genel şampiyonları",
    "global_standings_week": "Bu hafta · ilk 50",
    "global_standings_month": "Bu ay · ilk 50",
    "global_opted_out": "Genel sıralamada yer almıyorsun.",
    "global_open_settings": "AYARLAR",
    "compete_title": "Yarış",
    "compete_globally": "Genel sıralamada yer al",
    "compete_globally_note": "Kapalıyken adın genel sıralamada ve genel şampiyonlarda görünmez; topluluk sıralamaları etkilenmez."
```

- [ ] **Step 2: İngilizce çevirileri ekle**

`assets/translations/en.json` — `social` bloğundaki son satır

```json
    "privacy_note": "Level, rank and titles are always visible. Weight, measurements and nutrition are never shared."
```

şununla değiştir:

```json
    "privacy_note": "Level, rank and titles are always visible. Weight, measurements and nutrition are never shared.",
    "tab_friends": "Friends",
    "tab_communities": "Communities",
    "tab_global": "Global",
    "community_create": "CREATE",
    "community_join": "JOIN",
    "community_limit_note": "You can be in at most 5 communities",
    "my_communities": "My communities",
    "communities_empty": "No communities yet — create or join one",
    "community_members": "{n} members",
    "community_position": "#{p} / {n}",
    "community_form_title": "Create a community",
    "community_edit_title": "Edit community",
    "community_name_label": "Name",
    "community_name_short": "At least 3 characters",
    "community_description_label": "Description",
    "community_public": "Public",
    "community_public_note": "Public communities can be found by name; private ones can only be joined with the invite code.",
    "community_form_save": "CREATE",
    "community_form_update": "SAVE",
    "join_title": "Join a community",
    "join_privacy_note": "Members will see your name, level, equipped title and period XP; your workout details stay visible to friends only.",
    "join_mode_search": "Search",
    "join_mode_code": "Invite code",
    "join_search_hint": "Community name",
    "join_code_hint": "8-character code",
    "join_no_results": "No communities found",
    "join_member": "Member",
    "join_button": "JOIN",
    "community_error": {
      "community_limit": "You can be in at most 5 communities",
      "community_full": "This community is full (100 members)",
      "banned": "You can't join this community",
      "not_public": "This community is private — join with the invite code",
      "unknown_code": "No community has this code",
      "no_profile": "Create your social profile first",
      "not_owner": "Only the owner can do this"
    },
    "community_public_badge": "Public",
    "community_private_badge": "Private",
    "community_code_label": "Invite code",
    "community_invite_text": "Join {name} on LevelUp Fit — code: {code}",
    "period_week": "Week",
    "period_month": "Month",
    "titles_prev_week": "Last week's champions",
    "titles_prev_month": "Last month's champions",
    "titles_empty": "No champions from the last period",
    "standings_week": "This week · live",
    "standings_month": "This month · live",
    "standings_empty": "No XP in this period yet",
    "period_remaining_hours": "{n} h left",
    "period_remaining_days": "{n} days left",
    "your_rank": "Your rank",
    "muscle_leaders": "Muscle leaders",
    "muscle_leaders_empty": "No muscle sets in this period yet",
    "period_title_week": "{name} Champion of the Week",
    "period_title_month": "{name} Champion of the Month",
    "period_star_week": "Star of the Week",
    "period_star_month": "Star of the Month",
    "value_xp": "{n} XP",
    "value_sets": "{n} sets",
    "community_leave": "Leave community",
    "community_leave_title": "Leave this community?",
    "community_leave_body": "You'll leave the standings; you can join again any time.",
    "community_leave_owner_body": "Ownership passes to the longest-standing member.",
    "community_leave_last_body": "You're the last member; the community will be deleted.",
    "community_leave_confirm": "LEAVE",
    "community_edit": "Edit",
    "community_regenerate": "New invite code",
    "community_regenerated": "New invite code: {code}",
    "community_manage": "Manage members",
    "community_not_member": "You're not a member of this community",
    "manage_title": "Members",
    "manage_remove": "REMOVE",
    "manage_ban": "BAN",
    "manage_remove_title": "Remove {name}?",
    "manage_ban_title": "Ban {name}?",
    "manage_ban_body": "A banned person can't rejoin, even with the invite code.",
    "manage_confirm": "CONFIRM",
    "global_titles_week": "Last week's global champions",
    "global_titles_month": "Last month's global champions",
    "global_standings_week": "This week · top 50",
    "global_standings_month": "This month · top 50",
    "global_opted_out": "You're not in the global standings.",
    "global_open_settings": "SETTINGS",
    "compete_title": "Competition",
    "compete_globally": "Take part in global standings",
    "compete_globally_note": "When off, your name doesn't appear in global standings or global champions; community standings are not affected."
```

- [ ] **Step 3: JSON'un geçerli olduğunu doğrula**

Run (PowerShell): `Get-Content assets/translations/tr.json -Raw -Encoding utf8 | ConvertFrom-Json | Out-Null; Get-Content assets/translations/en.json -Raw -Encoding utf8 | ConvertFrom-Json | Out-Null; "ok"`
Expected: `ok`

- [ ] **Step 4: Bileşen testini yaz**

`test/features/social/presentation/period_widgets_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spor_takip/features/gamification/domain/levels.dart';
import 'package:spor_takip/features/social/domain/period_keys.dart';
import 'package:spor_takip/features/social/presentation/widgets/period_widgets.dart';

import '../../progress/presentation/test_app.dart';

void main() {
  setUpAll(initTestLocalization);

  testWidgets('titles list and standings render at phone width without overflow', (tester) async {
    tester.view.physicalSize = const Size(360, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(testApp(const Column(
      children: [
        PeriodTitlesList(
          kind: PeriodKind.week,
          lines: [
            TitleLine(category: 'xp', holders: ['Ayşe Kaya'], value: 1240),
            TitleLine(category: 'lats', holders: ['Ayşe Kaya', 'Burak Uzunisimlioğlu'], value: 14.5),
          ],
        ),
        StandingsList(
          lines: [
            StandingLine(
              userId: 'ayse',
              position: 1,
              name: 'Ayşe Kaya',
              initials: 'AK',
              level: 34,
              rank: Rank.determined,
              xp: 1420,
            ),
            StandingLine(
              userId: 'me',
              position: 4,
              name: 'Samet Çok Uzun Bir İsim Soyisim Daha',
              initials: 'S',
              level: 31,
              rank: Rank.determined,
              xp: 640,
              handle: 'samet_fit',
              title: 'Kanat Şampiyonu',
              isMe: true,
            ),
          ],
        ),
      ],
    )));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    expect(find.byKey(const Key('title_xp')), findsOneWidget);
    expect(find.byKey(const Key('title_lats')), findsOneWidget);
    expect(find.text('social.period_star_week'), findsOneWidget);
    expect(find.text('social.period_title_week'), findsOneWidget);
    expect(find.text('Ayşe Kaya, Burak Uzunisimlioğlu'), findsOneWidget);

    expect(find.byKey(const Key('standing_ayse')), findsOneWidget);
    expect(find.byKey(const Key('standing_me')), findsOneWidget);
    expect(find.byKey(const Key('standing_me_label')), findsOneWidget);
    expect(find.text('@samet_fit'), findsOneWidget);
    expect(find.text('Kanat Şampiyonu'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
    expect(find.text('4'), findsOneWidget);
  });

  testWidgets('the period switch reports the chosen period', (tester) async {
    PeriodKind? chosen;
    await tester.pumpWidget(testApp(PeriodSwitch(
      kind: PeriodKind.week,
      keyPrefix: 'period',
      onChanged: (k) => chosen = k,
    )));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('period_month')));
    await tester.pumpAndSettle();
    expect(chosen, PeriodKind.month);
  });
}
```

- [ ] **Step 5: Testin başarısız olduğunu gör**

Run: `flutter test --no-pub -j 1 test/features/social/presentation/period_widgets_test.dart`
Expected: FAIL (`period_widgets.dart` yok).

- [ ] **Step 6: Bileşenleri yaz**

`lib/features/social/presentation/widgets/period_widgets.dart`:

```dart
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_fonts.dart';
import '../../../../shared/text_case.dart';
import '../../../gamification/domain/levels.dart';
import '../../../gamification/presentation/title_names.dart';
import '../../../gamification/presentation/widgets/rank_badge.dart';
import '../../../workout/domain/exercise_taxonomy.dart';
import '../../../workout/domain/muscle_heat.dart';
import '../../domain/period_keys.dart';
import '../../domain/player_stats.dart';
import 'social_avatar.dart';

/// "Haftanın Kanat Şampiyonu", "Ayın Yıldızı" (S2 spec §6.6).
String periodTitleName(PeriodKind kind, String category) {
  if (category == 'xp') return 'social.period_star_${kind.name}'.tr();
  final name = 'gamification.muscle_short.${taxonomySlug(category)}'.tr();
  return 'social.period_title_${kind.name}'.tr(namedArgs: {'name': name});
}

/// "1240 XP" / "14.5 set".
String periodValueLabel(String category, double value) => category == 'xp'
    ? 'social.value_xp'.tr(namedArgs: {'n': '${value.toInt()}'})
    : 'social.value_sets'.tr(namedArgs: {'n': formatSets(value)});

/// "3 gün kaldı" / "12 saat kaldı".
String periodRemainingLabel(PeriodKind kind, DateTime now) {
  final remaining = periodRemaining(kind, now);
  return (remaining.hours ? 'social.period_remaining_hours' : 'social.period_remaining_days')
      .tr(namedArgs: {'n': '${remaining.n}'});
}

String? sharedTitleName(SharedTitle? title) => title == null ? null : titleName(title.asProgress, title.tier);

/// HAFTA / AY seçici; segment etiketlerinin anahtarı `<keyPrefix>_week`, `<keyPrefix>_month`.
class PeriodSwitch extends StatelessWidget {
  const PeriodSwitch({super.key, required this.kind, required this.onChanged, required this.keyPrefix});

  final PeriodKind kind;
  final ValueChanged<PeriodKind> onChanged;
  final String keyPrefix;

  @override
  Widget build(BuildContext context) {
    final lang = context.locale.languageCode;
    return SizedBox(
      width: double.infinity,
      child: SegmentedButton<PeriodKind>(
        showSelectedIcon: false,
        segments: [
          for (final k in PeriodKind.values)
            ButtonSegment(
              value: k,
              label: Text(upperCaseFor('social.period_${k.name}'.tr(), lang), key: Key('${keyPrefix}_${k.name}')),
            ),
        ],
        selected: {kind},
        onSelectionChanged: (selection) => onChanged(selection.first),
      ),
    );
  }
}

/// Unvan satırı: kategori, sahiplerin adları (eşitlikte birden çok), değer.
class TitleLine {
  const TitleLine({required this.category, required this.holders, required this.value});

  final String category;
  final List<String> holders;
  final double value;
}

/// Kupa ikonlu unvan listesi (Stitch: "Geçen haftanın şampiyonları").
class PeriodTitlesList extends StatelessWidget {
  const PeriodTitlesList({super.key, required this.kind, required this.lines});

  final PeriodKind kind;
  final List<TitleLine> lines;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      child: Column(
        children: [
          for (final (i, line) in lines.indexed) ...[
            if (i > 0) Divider(height: 1, color: scheme.outlineVariant),
            Padding(
              key: Key('title_${line.category}'),
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: scheme.primary.withValues(alpha: 0.12),
                      borderRadius: const BorderRadius.all(Radius.circular(8)),
                      border: Border.all(color: scheme.primary.withValues(alpha: 0.7)),
                    ),
                    child: Icon(
                      line.category == 'xp' ? Icons.workspace_premium : Icons.emoji_events,
                      color: scheme.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          periodTitleName(kind, line.category),
                          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        Text(
                          line.holders.join(', '),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: scheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    periodValueLabel(line.category, line.value),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontFamily: AppFonts.heading,
                      fontWeight: FontWeight.w900,
                      color: scheme.primary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class StandingLine {
  const StandingLine({
    required this.userId,
    required this.position,
    required this.name,
    required this.initials,
    required this.level,
    required this.rank,
    required this.xp,
    this.handle,
    this.title,
    this.isMe = false,
  });

  final String userId;
  final int position;
  final String name;
  final String initials;
  final int level;
  final Rank rank;
  final int xp;

  /// Genel sıralamada kullanıcı adı ('@' olmadan).
  final String? handle;

  /// Takılı unvanın adı.
  final String? title;
  final bool isMe;
}

/// Sıra numaralı canlı sıralama; ilk üç lime, benim satırım lime çerçeveli ve etiketli.
class StandingsList extends StatelessWidget {
  const StandingsList({super.key, required this.lines});

  final List<StandingLine> lines;

  @override
  Widget build(BuildContext context) => Column(children: [for (final line in lines) _StandingRow(line: line)]);
}

class _StandingRow extends StatelessWidget {
  const _StandingRow({required this.line});

  final StandingLine line;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final lang = context.locale.languageCode;
    final top = line.position <= 3;
    final first = line.position == 1;
    final muted = theme.textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant);
    return Container(
      key: Key('standing_${line.userId}'),
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: const BorderRadius.all(Radius.circular(12)),
        border: Border.all(
          color: line.isMe ? scheme.primary : scheme.outlineVariant,
          width: line.isMe ? 2 : 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: first ? scheme.primary : null,
              border: Border.all(color: top ? scheme.primary : scheme.outlineVariant, width: 2),
            ),
            child: Text(
              '${line.position}',
              style: TextStyle(
                fontFamily: AppFonts.heading,
                fontWeight: FontWeight.w900,
                color: first ? scheme.onPrimary : scheme.onSurface,
              ),
            ),
          ),
          const SizedBox(width: 10),
          SocialAvatar(initials: line.initials, size: 40, highlighted: line.isMe || top),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (line.isMe)
                  Text(
                    upperCaseFor('social.your_rank'.tr(), lang),
                    key: const Key('standing_me_label'),
                    style: theme.textTheme.labelSmall
                        ?.copyWith(color: scheme.primary, fontWeight: FontWeight.w900, letterSpacing: 1),
                  ),
                Text(
                  line.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                ),
                Row(
                  children: [
                    RankBadge(rank: line.rank, level: line.level, size: 12),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        'gamification.level_short'.tr(namedArgs: {'n': '${line.level}'}),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: muted,
                      ),
                    ),
                    if (line.handle case final handle?) ...[
                      const SizedBox(width: 6),
                      Flexible(child: Text('@$handle', maxLines: 1, overflow: TextOverflow.ellipsis, style: muted)),
                    ],
                  ],
                ),
                if (line.title case final title?)
                  Padding(padding: const EdgeInsets.only(top: 4), child: TitlePill(text: title)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            periodValueLabel('xp', line.xp.toDouble()),
            style: theme.textTheme.titleMedium?.copyWith(
              fontFamily: AppFonts.heading,
              fontWeight: FontWeight.w900,
              color: line.isMe || first ? scheme.primary : scheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 7: Testin geçtiğini gör**

Run: `flutter test --no-pub -j 1 test/features/social/presentation/period_widgets_test.dart`
Expected: PASS (2 test). Taşma olursa (`takeException` null değil) taşan satırdaki metne `Flexible`/`maxLines` ekle; testi gevşetme.

- [ ] **Step 8: Commit**

```bash
git add assets/translations/tr.json assets/translations/en.json lib/features/social/presentation/widgets/period_widgets.dart test/features/social/presentation/period_widgets_test.dart
git commit -m "feat(social): add period title, standings and period switch widgets with S2 texts

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 7: Sosyal alt sekmeleri ve Topluluklar sekmesi

**Files:**
- Modify: `lib/features/social/presentation/social_screen.dart`
- Create: `lib/features/social/presentation/communities_tab.dart`
- Create: `lib/features/social/presentation/community_form_sheet.dart`
- Create: `lib/features/social/presentation/join_community_sheet.dart`
- Modify: `test/features/social/presentation/social_screen_test.dart`
- Test: `test/features/social/presentation/communities_tab_test.dart`

**Interfaces:**
- Consumes: Task 4–6 (`maxCommunities`, `CommunityException`, `CommunitySearchResult`, `Community`, `myCommunitiesProvider`, `CommunityEntry`, `communityActionsProvider`, `socialRepositoryProvider`).
- Produces:
  - `SocialScreen` profil varken üç sekme: anahtarlar `social_tab_friends`, `social_tab_communities`, `social_tab_global`; üçüncü görünüm bu görevde `const SizedBox.shrink()` (Task 9'da `GlobalTab`).
  - `CommunitiesTab` (liste anahtarı `communities_tab`; düğmeler `community_create`, `community_join`; `community_limit_note`; satır `community_<id>`, sıra metni `community_position_<id>`; `communities_empty`; `communities_retry`). Satıra dokununca `/social/community/<id>`.
  - `Future<String?> showCommunityFormSheet(BuildContext context, {Community? editing})` — kurulunca yeni kimlik; alanlar `community_name_field`, `community_description_field`, `community_public_switch`, `community_form_save`, hata `community_form_error`.
  - `Future<String?> showJoinCommunitySheet(BuildContext context)` — katılınan topluluğun kimliği; `join_privacy_note`, `join_mode_search`, `join_mode_code`, `join_search_field`, `join_search_submit`, `join_result_<id>`, `join_result_join_<id>`, `join_no_results`, `join_code_field`, `join_code_submit`, `join_error`.

- [ ] **Step 1: Testleri yaz**

`test/features/social/presentation/communities_tab_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spor_takip/features/social/application/social_providers.dart';
import 'package:spor_takip/features/social/domain/community.dart';
import 'package:spor_takip/features/social/presentation/communities_tab.dart';
import 'package:spor_takip/features/workout/application/session_providers.dart';

import '../../progress/presentation/test_app.dart';
import '../fakes.dart';
import '../social_fixtures.dart';

void main() {
  setUpAll(initTestLocalization);
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> pump(WidgetTester tester, FakeSocialRepository repo) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(testApp(
      const Scaffold(body: CommunitiesTab()),
      scaffold: false,
      overrides: [
        socialRepositoryProvider.overrideWithValue(repo),
        nowProvider.overrideWithValue(() => DateTime(2026, 10, 9, 12)),
      ],
      stubRoutes: {
        '/social/community/c1': 'community-c1',
        '/social/community/c2': 'community-c2',
        '/social/community/c9': 'community-c9',
        '/social/community/new': 'community-new',
      },
    ));
    await tester.pumpAndSettle();
  }

  FakeSocialRepository repoWith({Map<String, List<CommunityMember>>? members}) => FakeSocialRepository(
        me: socialMe,
        others: [socialAyse],
        communities: [socialCommunity, socialCommunity2, socialCommunity3],
        members: members ??
            {
              'c1': [socialMember('c1', 'me', owner: true), socialMember('c1', 'ayse', day: 2)],
              'c3': [socialMember('c3', 'me', owner: true)],
            },
        periodStats: {'ayse': socialPeriod(week: 900)},
      );

  testWidgets('lists my communities with my position and opens one', (tester) async {
    await pump(tester, repoWith());
    expect(find.byKey(const Key('community_c1')), findsOneWidget);
    expect(find.byKey(const Key('community_c3')), findsOneWidget);
    expect(find.byKey(const Key('community_c2')), findsNothing);
    // c1'de Ayşe'nin XP'si var, benim yok → sıram yok.
    expect(tester.widget<Text>(find.byKey(const Key('community_position_c1'))).data, '—');
    expect(find.byKey(const Key('community_limit_note')), findsNothing);

    await tester.tap(find.byKey(const Key('community_c1')));
    await tester.pumpAndSettle();
    expect(find.text('community-c1'), findsOneWidget);
  });

  testWidgets('no communities shows the empty text', (tester) async {
    await pump(tester, repoWith(members: const {}));
    expect(find.byKey(const Key('communities_empty')), findsOneWidget);
  });

  testWidgets('with five communities both buttons are disabled', (tester) async {
    final ids = ['c1', 'c2', 'c3', 'c4', 'c5'];
    await pump(
      tester,
      FakeSocialRepository(
        me: socialMe,
        communities: [
          for (final id in ids)
            Community(id: id, name: 'Topluluk $id', description: '', isPublic: true, inviteCode: 'KOD$id', owner: id),
        ],
        members: {
          for (final id in ids) id: [socialMember(id, 'me')],
        },
      ),
    );
    expect(find.byKey(const Key('community_limit_note')), findsOneWidget);
    expect(tester.widget<ButtonStyleButton>(find.byKey(const Key('community_create'))).onPressed, isNull);
    expect(tester.widget<ButtonStyleButton>(find.byKey(const Key('community_join'))).onPressed, isNull);
  });

  testWidgets('creating a community validates the name and opens it', (tester) async {
    final repo = repoWith();
    await pump(tester, repo);
    await tester.tap(find.byKey(const Key('community_create')));
    await tester.pumpAndSettle();

    final save = find.byKey(const Key('community_form_save'));
    await tester.enterText(find.byKey(const Key('community_name_field')), 'De');
    await tester.pump();
    expect(find.text('social.community_name_short'), findsOneWidget);
    expect(tester.widget<FilledButton>(save).onPressed, isNull);

    await tester.enterText(find.byKey(const Key('community_name_field')), '  Demir Kulübü 2 ');
    await tester.enterText(find.byKey(const Key('community_description_field')), 'Akşam ekibi');
    await tester.tap(find.byKey(const Key('community_public_switch')));
    await tester.pump();
    await tester.tap(save);
    await tester.pumpAndSettle();

    final created = repo.communities['new']!;
    expect((created.name, created.description, created.isPublic), ('Demir Kulübü 2', 'Akşam ekibi', false));
    expect(find.text('community-new'), findsOneWidget);
  });

  testWidgets('a creation error is shown inside the sheet', (tester) async {
    final repo = repoWith()..communityError = const CommunityException('community_limit');
    await pump(tester, repo);
    await tester.tap(find.byKey(const Key('community_create')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('community_name_field')), 'Demir');
    await tester.pump();
    await tester.tap(find.byKey(const Key('community_form_save')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('community_form_error')), findsOneWidget);
    expect(find.text('social.community_error.community_limit'), findsOneWidget);
  });

  testWidgets('joining by search opens the community', (tester) async {
    final repo = repoWith()
      ..searchResults = const [
        CommunitySearchResult(id: 'c9', name: 'Sabah Ekibi', description: 'Erkenciler', memberCount: 12, isMember: false),
        CommunitySearchResult(id: 'c1', name: 'Demir Kulübü', description: '', memberCount: 2, isMember: true),
      ];
    await pump(tester, repo);
    await tester.tap(find.byKey(const Key('community_join')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('join_privacy_note')), findsOneWidget);

    final submit = find.byKey(const Key('join_search_submit'));
    await tester.enterText(find.byKey(const Key('join_search_field')), 's');
    await tester.pump();
    expect(tester.widget<FilledButton>(submit).onPressed, isNull);
    await tester.enterText(find.byKey(const Key('join_search_field')), 'sab');
    await tester.pump();
    await tester.tap(submit);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('join_result_c9')), findsOneWidget);
    expect(find.byKey(const Key('join_result_join_c1')), findsNothing);
    expect(find.text('social.join_member'), findsOneWidget);

    await tester.tap(find.byKey(const Key('join_result_join_c9')));
    await tester.pumpAndSettle();
    expect(repo.joined, ['c9']);
    expect(find.text('community-c9'), findsOneWidget);
  });

  testWidgets('joining by code: errors stay in the sheet, a valid code opens the community', (tester) async {
    final repo = repoWith()..communityError = const CommunityException('banned');
    await pump(tester, repo);
    await tester.tap(find.byKey(const Key('community_join')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('join_mode_code')));
    await tester.pumpAndSettle();

    final submit = find.byKey(const Key('join_code_submit'));
    await tester.enterText(find.byKey(const Key('join_code_field')), 'aysetkm');
    await tester.pump();
    expect(tester.widget<FilledButton>(submit).onPressed, isNull);
    await tester.enterText(find.byKey(const Key('join_code_field')), 'aysetkm2');
    await tester.pump();
    await tester.tap(submit);
    await tester.pumpAndSettle();
    expect(find.text('social.community_error.banned'), findsOneWidget);

    repo.communityError = null;
    await tester.tap(submit);
    await tester.pumpAndSettle();
    expect(repo.joined, ['c2']);
    expect(find.text('community-c2'), findsOneWidget);
  });
}
```

`test/features/social/presentation/social_screen_test.dart` — `main()` içinde son testten sonra ekle:

```dart
  testWidgets('the social tab has friends, communities and global sub-tabs', (tester) async {
    await pump(tester, FakeSocialRepository(me: socialMe));
    expect(find.byKey(const Key('social_tab_friends')), findsOneWidget);
    expect(find.byKey(const Key('social_me_card')), findsOneWidget);

    await tester.tap(find.byKey(const Key('social_tab_communities')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('communities_tab')), findsOneWidget);
    expect(find.byKey(const Key('communities_empty')), findsOneWidget);

    await tester.tap(find.byKey(const Key('social_tab_global')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('communities_tab')), findsNothing);
  });
```

- [ ] **Step 2: Testlerin başarısız olduğunu gör**

Run: `flutter test --no-pub -j 1 test/features/social/presentation/communities_tab_test.dart test/features/social/presentation/social_screen_test.dart`
Expected: FAIL (`communities_tab.dart` yok, sekmeler yok).

- [ ] **Step 3: Kurma sayfasını yaz**

`lib/features/social/presentation/community_form_sheet.dart`:

```dart
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_fonts.dart';
import '../../../shared/text_case.dart';
import '../application/community_providers.dart';
import '../domain/community.dart';

/// Topluluk kurar ([editing] null) ya da düzenler (S2 spec §6.2). Kurulunca yeni kimliği döndürür.
Future<String?> showCommunityFormSheet(BuildContext context, {Community? editing}) => showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => CommunityFormSheet(editing: editing),
    );

class CommunityFormSheet extends ConsumerStatefulWidget {
  const CommunityFormSheet({super.key, this.editing});

  final Community? editing;

  @override
  ConsumerState<CommunityFormSheet> createState() => _CommunityFormSheetState();
}

class _CommunityFormSheetState extends ConsumerState<CommunityFormSheet> {
  late final _name = TextEditingController(text: widget.editing?.name ?? '');
  late final _description = TextEditingController(text: widget.editing?.description ?? '');
  late bool _isPublic = widget.editing?.isPublic ?? true;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  int get _nameLength => _name.text.trim().length;

  bool get _valid => _nameLength >= 3 && _nameLength <= 40;

  Future<void> _save() async {
    final editing = widget.editing;
    final actions = ref.read(communityActionsProvider);
    final navigator = Navigator.of(context);
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      if (editing == null) {
        final id = await actions.create(
          name: _name.text.trim(),
          description: _description.text.trim(),
          isPublic: _isPublic,
        );
        navigator.pop(id);
      } else {
        await actions.update(
          editing.id,
          name: _name.text.trim(),
          description: _description.text.trim(),
          isPublic: _isPublic,
        );
        navigator.pop();
      }
    } on CommunityException catch (e) {
      if (mounted) setState(() => _error = 'social.community_error.${e.code}'.tr());
    } catch (e, st) {
      debugPrint('community form failed: $e\n$st');
      if (mounted) setState(() => _error = 'social.action_error'.tr());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final editing = widget.editing != null;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        key: const Key('community_form'),
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              upperCaseFor(
                (editing ? 'social.community_edit_title' : 'social.community_form_title').tr(),
                context.locale.languageCode,
              ),
              style: theme.textTheme.titleLarge?.copyWith(fontFamily: AppFonts.heading, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 16),
            TextField(
              key: const Key('community_name_field'),
              controller: _name,
              maxLength: 40,
              decoration: InputDecoration(
                labelText: 'social.community_name_label'.tr(),
                errorText: _nameLength > 0 && _nameLength < 3 ? 'social.community_name_short'.tr() : null,
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 8),
            TextField(
              key: const Key('community_description_field'),
              controller: _description,
              maxLength: 200,
              minLines: 1,
              maxLines: 3,
              decoration: InputDecoration(labelText: 'social.community_description_label'.tr()),
            ),
            SwitchListTile(
              key: const Key('community_public_switch'),
              contentPadding: EdgeInsets.zero,
              title: Text('social.community_public'.tr()),
              subtitle: Text('social.community_public_note'.tr()),
              value: _isPublic,
              onChanged: (v) => setState(() => _isPublic = v),
            ),
            if (_error case final error?)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  error,
                  key: const Key('community_form_error'),
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ),
            const SizedBox(height: 12),
            FilledButton(
              key: const Key('community_form_save'),
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
              onPressed: _valid && !_saving ? _save : null,
              child: Text((editing ? 'social.community_form_update' : 'social.community_form_save').tr()),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Katılma sayfasını yaz**

`lib/features/social/presentation/join_community_sheet.dart`:

```dart
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_fonts.dart';
import '../../../shared/text_case.dart';
import '../application/community_providers.dart';
import '../application/social_providers.dart';
import '../domain/community.dart';

/// Adla arayıp ya da davet koduyla katılır (S2 spec §6.2). Katılınan topluluğun kimliğini döndürür.
Future<String?> showJoinCommunitySheet(BuildContext context) => showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => const JoinCommunitySheet(),
    );

enum _JoinMode { search, code }

class JoinCommunitySheet extends ConsumerStatefulWidget {
  const JoinCommunitySheet({super.key});

  @override
  ConsumerState<JoinCommunitySheet> createState() => _JoinCommunitySheetState();
}

class _JoinCommunitySheetState extends ConsumerState<JoinCommunitySheet> {
  final _query = TextEditingController();
  final _code = TextEditingController();
  _JoinMode _mode = _JoinMode.search;
  List<CommunitySearchResult>? _results;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _query.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } on CommunityException catch (e) {
      if (mounted) setState(() => _error = 'social.community_error.${e.code}'.tr());
    } catch (e, st) {
      debugPrint('join community failed: $e\n$st');
      if (mounted) setState(() => _error = 'social.action_error'.tr());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  bool get _canSearch => !_busy && _query.text.trim().length >= 2;

  bool get _canJoinByCode => !_busy && _code.text.trim().length == 8;

  void _search() {
    if (!_canSearch) return;
    final query = _query.text.trim();
    _run(() async {
      final results = await ref.read(socialRepositoryProvider).searchCommunities(query);
      if (mounted) setState(() => _results = results);
    });
  }

  void _join(String id) {
    final navigator = Navigator.of(context);
    _run(() async {
      await ref.read(communityActionsProvider).join(id);
      navigator.pop(id);
    });
  }

  void _joinByCode() {
    final navigator = Navigator.of(context);
    _run(() async {
      final id = await ref.read(communityActionsProvider).joinByCode(_code.text);
      navigator.pop(id);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final results = _results;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        key: const Key('join_sheet'),
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              upperCaseFor('social.join_title'.tr(), context.locale.languageCode),
              style: theme.textTheme.titleLarge?.copyWith(fontFamily: AppFonts.heading, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            Text(
              'social.join_privacy_note'.tr(),
              key: const Key('join_privacy_note'),
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            SegmentedButton<_JoinMode>(
              showSelectedIcon: false,
              segments: [
                ButtonSegment(
                  value: _JoinMode.search,
                  label: Text('social.join_mode_search'.tr(), key: const Key('join_mode_search')),
                ),
                ButtonSegment(
                  value: _JoinMode.code,
                  label: Text('social.join_mode_code'.tr(), key: const Key('join_mode_code')),
                ),
              ],
              selected: {_mode},
              onSelectionChanged: (selection) => setState(() {
                _mode = selection.first;
                _error = null;
              }),
            ),
            const SizedBox(height: 16),
            if (_mode == _JoinMode.search) ...[
              TextField(
                key: const Key('join_search_field'),
                controller: _query,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(labelText: 'social.join_search_hint'.tr()),
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) => _search(),
              ),
              const SizedBox(height: 8),
              FilledButton(
                key: const Key('join_search_submit'),
                onPressed: _canSearch ? _search : null,
                child: Text('social.search'.tr()),
              ),
              if (results != null && results.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    'social.join_no_results'.tr(),
                    key: const Key('join_no_results'),
                    style: TextStyle(color: scheme.onSurfaceVariant),
                  ),
                ),
              if (results != null)
                for (final r in results) _ResultRow(result: r, onJoin: _busy ? null : () => _join(r.id)),
            ] else ...[
              TextField(
                key: const Key('join_code_field'),
                controller: _code,
                maxLength: 8,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(labelText: 'social.join_code_hint'.tr()),
                onChanged: (_) => setState(() {}),
              ),
              FilledButton(
                key: const Key('join_code_submit'),
                onPressed: _canJoinByCode ? _joinByCode : null,
                child: Text('social.join_button'.tr()),
              ),
            ],
            if (_error case final error?)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(error, key: const Key('join_error'), style: TextStyle(color: scheme.error)),
              ),
          ],
        ),
      ),
    );
  }
}

class _ResultRow extends StatelessWidget {
  const _ResultRow({required this.result, required this.onJoin});

  final CommunitySearchResult result;
  final VoidCallback? onJoin;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Card(
      key: Key('join_result_${result.id}'),
      margin: const EdgeInsets.only(top: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    result.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  if (result.description.isNotEmpty)
                    Text(
                      result.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: scheme.onSurfaceVariant),
                    ),
                  Text(
                    'social.community_members'.tr(namedArgs: {'n': '${result.memberCount}'}),
                    style: theme.textTheme.labelMedium?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (result.isMember)
              Text('social.join_member'.tr(), style: TextStyle(color: scheme.primary, fontWeight: FontWeight.w800))
            else
              FilledButton(
                key: Key('join_result_join_${result.id}'),
                onPressed: onJoin,
                child: Text('social.join_button'.tr()),
              ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 5: Topluluklar sekmesini yaz**

`lib/features/social/presentation/communities_tab.dart`:

```dart
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/widgets/section_header.dart';
import '../application/community_providers.dart';
import '../domain/community.dart';
import 'community_form_sheet.dart';
import 'join_community_sheet.dart';

/// Topluluklar sekmesi (S2 spec §6.2): kurma/katılma ve "Topluluklarım".
class CommunitiesTab extends ConsumerWidget {
  const CommunitiesTab({super.key});

  /// Alt sayfa bir kimlik döndürürse o topluluğu açar.
  Future<void> _openAfter(BuildContext context, Future<String?> sheet) async {
    final id = await sheet;
    if (id != null && context.mounted) context.push('/social/community/$id');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(myCommunitiesProvider);
    final scheme = Theme.of(context).colorScheme;
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(myCommunitiesProvider);
        await ref.read(myCommunitiesProvider.future);
      },
      child: ListView(
        key: const Key('communities_tab'),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: async.when(
          loading: () => const [
            Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator())),
          ],
          error: (error, stackTrace) => [
            Center(
              child: TextButton(
                key: const Key('communities_retry'),
                onPressed: () => ref.invalidate(myCommunitiesProvider),
                child: Text('social.retry'.tr()),
              ),
            ),
          ],
          data: (entries) {
            final full = entries.length >= maxCommunities;
            return [
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      key: const Key('community_create'),
                      style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                      icon: const Icon(Icons.add),
                      label: Text('social.community_create'.tr()),
                      onPressed: full ? null : () => _openAfter(context, showCommunityFormSheet(context)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      key: const Key('community_join'),
                      style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                      icon: const Icon(Icons.group_add),
                      label: Text('social.community_join'.tr()),
                      onPressed: full ? null : () => _openAfter(context, showJoinCommunitySheet(context)),
                    ),
                  ),
                ],
              ),
              if (full)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'social.community_limit_note'.tr(),
                    key: const Key('community_limit_note'),
                    style: TextStyle(color: scheme.onSurfaceVariant),
                  ),
                ),
              SectionHeader('social.my_communities'.tr(), trailing: '${entries.length}'),
              if (entries.isEmpty)
                Text(
                  'social.communities_empty'.tr(),
                  key: const Key('communities_empty'),
                  style: TextStyle(color: scheme.onSurfaceVariant),
                )
              else
                for (final entry in entries) _CommunityRow(entry: entry),
            ];
          },
        ),
      ),
    );
  }
}

class _CommunityRow extends StatelessWidget {
  const _CommunityRow({required this.entry});

  final CommunityEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final community = entry.community;
    final position = entry.myPosition;
    return Card(
      key: Key('community_${community.id}'),
      margin: const EdgeInsets.only(bottom: 8),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/social/community/${community.id}'),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Icon(community.isPublic ? Icons.groups : Icons.lock_outline, color: scheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      community.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    Text(
                      'social.community_members'.tr(namedArgs: {'n': '${entry.memberCount}'}),
                      style: TextStyle(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              Text(
                position == null
                    ? '—'
                    : 'social.community_position'.tr(namedArgs: {'p': '$position', 'n': '${entry.memberCount}'}),
                key: Key('community_position_${community.id}'),
                style: theme.textTheme.titleMedium?.copyWith(color: scheme.primary, fontWeight: FontWeight.w900),
              ),
              Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 6: Sosyal ekrana alt sekmeleri ekle**

`lib/features/social/presentation/social_screen.dart`:

Importlara ekle:

```dart
import 'communities_tab.dart';
```

`SocialScreen.build` içindeki

```dart
        data: (me) => me == null ? const _CreateProfile() : _Overview(me: me),
```

satırını şununla değiştir:

```dart
        data: (me) => me == null ? const _CreateProfile() : _Tabs(me: me),
```

`runSocialAction` fonksiyonundan önce ekle:

```dart
/// Arkadaşlar / Topluluklar / Genel (S2 spec §6.1).
class _Tabs extends StatelessWidget {
  const _Tabs({required this.me});

  final PublicProfile me;

  @override
  Widget build(BuildContext context) {
    final lang = context.locale.languageCode;
    Tab tab(String key, String label) => Tab(key: Key(key), text: upperCaseFor(label.tr(), lang));
    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          TabBar(
            tabs: [
              tab('social_tab_friends', 'social.tab_friends'),
              tab('social_tab_communities', 'social.tab_communities'),
              tab('social_tab_global', 'social.tab_global'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _Overview(me: me),
                const CommunitiesTab(),
                // Task 9: GlobalTab.
                const SizedBox.shrink(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 7: Testlerin geçtiğini gör**

Run: `flutter test --no-pub -j 1 test/features/social/presentation/communities_tab_test.dart test/features/social/presentation/social_screen_test.dart`
Expected: PASS.

- [ ] **Step 8: Commit**

```bash
git add lib/features/social/presentation/social_screen.dart lib/features/social/presentation/communities_tab.dart lib/features/social/presentation/community_form_sheet.dart lib/features/social/presentation/join_community_sheet.dart test/features/social/presentation/communities_tab_test.dart test/features/social/presentation/social_screen_test.dart
git commit -m "feat(social): add the communities tab with create and join sheets

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 8: Topluluk sayfası ve üye yönetimi

**Files:**
- Create: `lib/features/social/presentation/community_screen.dart`
- Create: `lib/features/social/presentation/manage_members_sheet.dart`
- Modify: `lib/core/router.dart`
- Test: `test/features/social/presentation/community_screen_test.dart`

**Interfaces:**
- Consumes: Task 2–7 (`periodKey`, `standings`, `periodTitles`, `PeriodTitle`, `communityDetailProvider`, `CommunityDetail`, `communityActionsProvider`, `PeriodSwitch`, `PeriodTitlesList`, `TitleLine`, `StandingsList`, `StandingLine`, `periodRemainingLabel`, `sharedTitleName`, `showCommunityFormSheet`); `runSocialAction` (`social_screen.dart`); `SocialAvatar`; `nowProvider`.
- Produces:
  - `CommunityScreen({required String communityId})` — anahtarlar: `community_screen`, `community_retry`, `community_not_member`, `community_menu` (öğeler `community_edit`, `community_regenerate`, `community_manage`, `community_leave`), onay `community_leave_confirm`, `community_header`, `community_code`, `community_copy_code`, `period_week`/`period_month`, `community_titles`/`community_titles_empty`, `period_remaining`, `community_standings`/`community_standings_empty`, `community_muscle_leaders`.
  - `Future<void> showManageMembersSheet(BuildContext context, String communityId)` — satır `manage_<userId>`, `manage_remove_<id>`, `manage_ban_<id>`, onay `manage_confirm`.
  - Rota `/social/community/:id`.

- [ ] **Step 1: Testi yaz**

`test/features/social/presentation/community_screen_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spor_takip/features/social/application/social_providers.dart';
import 'package:spor_takip/features/social/domain/community.dart';
import 'package:spor_takip/features/social/presentation/community_screen.dart';
import 'package:spor_takip/features/workout/application/session_providers.dart';

import '../../progress/presentation/test_app.dart';
import '../fakes.dart';
import '../social_fixtures.dart';

void main() {
  setUpAll(initTestLocalization);
  setUp(() => SharedPreferences.setMockInitialValues({}));

  FakeSocialRepository repoWith({Community community = socialCommunity, bool meIsMember = true}) =>
      FakeSocialRepository(
        me: socialMe,
        others: [socialAyse, socialBurak],
        communities: [community],
        members: {
          'c1': [
            if (meIsMember) socialMember('c1', 'me', owner: community.owner == 'me'),
            socialMember('c1', 'ayse', owner: community.owner == 'ayse', day: 2),
            socialMember('c1', 'burak', day: 3),
          ],
        },
        periodStats: {
          'me': socialPeriod(week: 640, weekMuscles: {'lats': 10}, prevWeek: 300),
          'ayse': socialPeriod(
            week: 1420,
            weekMuscles: {'lats': 14.5, 'chest': 9},
            prevWeek: 900,
            prevWeekMuscles: {'lats': 22},
          ),
          'burak': socialPeriod(),
        },
      );

  Future<void> pump(WidgetTester tester, FakeSocialRepository repo) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(testApp(
      const CommunityScreen(communityId: 'c1'),
      scaffold: false,
      overrides: [
        socialRepositoryProvider.overrideWithValue(repo),
        nowProvider.overrideWithValue(() => DateTime(2026, 10, 9, 12)),
      ],
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('shows the header, last week champions and live standings with me highlighted', (tester) async {
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') copied = (call.arguments as Map)['text'] as String;
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
    await pump(tester, repoWith());

    expect(find.byKey(const Key('community_header')), findsOneWidget);
    expect(tester.widget<Text>(find.byKey(const Key('community_code'))).data, 'Q7M2K9TA');

    final titles = find.byKey(const Key('community_titles'));
    expect(find.descendant(of: titles, matching: find.byKey(const Key('title_xp'))), findsOneWidget);
    expect(find.descendant(of: titles, matching: find.byKey(const Key('title_lats'))), findsOneWidget);
    expect(find.descendant(of: titles, matching: find.text('Ayşe Kaya')), findsNWidgets(2));

    expect(find.byKey(const Key('period_remaining')), findsOneWidget);
    expect(find.byKey(const Key('standing_ayse')), findsOneWidget);
    expect(find.byKey(const Key('standing_me')), findsOneWidget);
    expect(find.byKey(const Key('standing_burak')), findsNothing);
    expect(find.byKey(const Key('standing_me_label')), findsOneWidget);
    expect(
      tester.getTopLeft(find.byKey(const Key('standing_ayse'))).dy,
      lessThan(tester.getTopLeft(find.byKey(const Key('standing_me'))).dy),
    );

    await tester.tap(find.byKey(const Key('community_copy_code')));
    await tester.pumpAndSettle();
    expect(copied, 'social.community_invite_text');
  });

  testWidgets('the month view shows empty texts; muscle leaders list this period without XP', (tester) async {
    await pump(tester, repoWith());
    final leaders = find.byKey(const Key('community_muscle_leaders'));
    await tester.ensureVisible(leaders);
    await tester.tap(leaders);
    await tester.pumpAndSettle();
    expect(find.descendant(of: leaders, matching: find.byKey(const Key('title_chest'))), findsOneWidget);
    expect(find.descendant(of: leaders, matching: find.byKey(const Key('title_lats'))), findsOneWidget);
    expect(find.descendant(of: leaders, matching: find.byKey(const Key('title_xp'))), findsNothing);

    await tester.ensureVisible(find.byKey(const Key('period_month')));
    await tester.tap(find.byKey(const Key('period_month')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('community_titles_empty')), findsOneWidget);
    expect(find.byKey(const Key('community_standings_empty')), findsOneWidget);
  });

  testWidgets('the owner menu regenerates the code and manages members', (tester) async {
    final repo = repoWith();
    await pump(tester, repo);

    await tester.tap(find.byKey(const Key('community_menu')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('community_edit')), findsOneWidget);
    expect(find.byKey(const Key('community_manage')), findsOneWidget);
    expect(find.byKey(const Key('community_leave')), findsOneWidget);
    await tester.tap(find.byKey(const Key('community_regenerate')));
    await tester.pumpAndSettle();
    expect(find.text('social.community_regenerated'), findsOneWidget);
    expect(tester.widget<Text>(find.byKey(const Key('community_code'))).data, 'R3GENKQ2');

    await tester.tap(find.byKey(const Key('community_menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('community_manage')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('manage_ayse')), findsOneWidget);
    expect(find.byKey(const Key('manage_ban_me')), findsNothing);
    await tester.tap(find.byKey(const Key('manage_ban_ayse')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('manage_confirm')));
    await tester.pumpAndSettle();
    expect(repo.memberRemovals, [('c1', 'ayse', true)]);
    expect(find.byKey(const Key('manage_ayse')), findsNothing);
  });

  testWidgets('a member only sees leave; leaving asks first', (tester) async {
    const owned = Community(
      id: 'c1',
      name: 'Demir Kulübü',
      description: '',
      isPublic: false,
      inviteCode: 'Q7M2K9TA',
      owner: 'ayse',
    );
    final repo = repoWith(community: owned);
    await pump(tester, repo);

    await tester.tap(find.byKey(const Key('community_menu')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('community_edit')), findsNothing);
    expect(find.byKey(const Key('community_manage')), findsNothing);
    await tester.tap(find.byKey(const Key('community_leave')));
    await tester.pumpAndSettle();
    expect(find.text('social.community_leave_body'), findsOneWidget);
    await tester.tap(find.byKey(const Key('community_leave_confirm')));
    await tester.pumpAndSettle();
    expect(repo.left, ['c1']);
    expect(find.byKey(const Key('community_not_member')), findsOneWidget);
  });

  testWidgets('not a member shows the not-member text', (tester) async {
    await pump(tester, repoWith(meIsMember: false));
    expect(find.byKey(const Key('community_not_member')), findsOneWidget);
    expect(find.byKey(const Key('community_menu')), findsNothing);
  });
}
```

- [ ] **Step 2: Testin başarısız olduğunu gör**

Run: `flutter test --no-pub -j 1 test/features/social/presentation/community_screen_test.dart`
Expected: FAIL (`community_screen.dart` yok).

- [ ] **Step 3: Üye yönetimi sayfasını yaz**

`lib/features/social/presentation/manage_members_sheet.dart`:

```dart
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_fonts.dart';
import '../../../shared/text_case.dart';
import '../application/community_providers.dart';
import '../domain/public_profile.dart';
import 'social_screen.dart';
import 'widgets/social_avatar.dart';

/// Sahip üyeleri çıkarır ya da yasaklar (S2 spec §6.3); kendisi ve sahip için düğme yok.
Future<void> showManageMembersSheet(BuildContext context, String communityId) => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => ManageMembersSheet(communityId: communityId),
    );

class ManageMembersSheet extends ConsumerWidget {
  const ManageMembersSheet({super.key, required this.communityId});

  final String communityId;

  Future<void> _remove(BuildContext context, WidgetRef ref, PublicProfile profile, {required bool ban}) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          (ban ? 'social.manage_ban_title' : 'social.manage_remove_title')
              .tr(namedArgs: {'name': profile.displayName}),
        ),
        content: ban ? Text('social.manage_ban_body'.tr()) : null,
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text('social.cancel'.tr())),
          FilledButton(
            key: const Key('manage_confirm'),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('social.manage_confirm'.tr()),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await runSocialAction(
      context,
      () => ref.read(communityActionsProvider).removeMember(communityId, profile.userId, ban: ban),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(communityDetailProvider(communityId)).value;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    if (detail == null) {
      return const SizedBox(height: 160, child: Center(child: CircularProgressIndicator()));
    }
    return ListView(
      key: const Key('manage_sheet'),
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
      children: [
        Text(
          upperCaseFor('social.manage_title'.tr(), context.locale.languageCode),
          style: theme.textTheme.titleLarge?.copyWith(fontFamily: AppFonts.heading, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 12),
        for (final member in detail.members)
          if (detail.profiles[member.userId] case final profile?)
            Padding(
              key: Key('manage_${member.userId}'),
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  SocialAvatar(initials: profile.initials, size: 40, highlighted: member.isOwner),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          profile.displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        Text(
                          '@${profile.username}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: scheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  if (member.userId != detail.myId && !member.isOwner) ...[
                    OutlinedButton(
                      key: Key('manage_remove_${member.userId}'),
                      onPressed: () => _remove(context, ref, profile, ban: false),
                      child: Text('social.manage_remove'.tr()),
                    ),
                    const SizedBox(width: 4),
                    TextButton(
                      key: Key('manage_ban_${member.userId}'),
                      style: TextButton.styleFrom(foregroundColor: scheme.error),
                      onPressed: () => _remove(context, ref, profile, ban: true),
                      child: Text('social.manage_ban'.tr()),
                    ),
                  ],
                ],
              ),
            ),
      ],
    );
  }
}
```

- [ ] **Step 4: Topluluk sayfasını yaz**

`lib/features/social/presentation/community_screen.dart`:

```dart
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_fonts.dart';
import '../../../shared/text_case.dart';
import '../../../shared/widgets/section_header.dart';
import '../../workout/application/session_providers.dart';
import '../application/community_providers.dart';
import '../domain/period_keys.dart';
import '../domain/standings.dart';
import 'community_form_sheet.dart';
import 'manage_members_sheet.dart';
import 'social_screen.dart';
import 'widgets/period_widgets.dart';

/// Topluluk sayfası (S2 spec §6.3): başlık kartı, HAFTA/AY, geçen dönemin
/// şampiyonları, canlı sıralama ve kas liderleri.
class CommunityScreen extends ConsumerStatefulWidget {
  const CommunityScreen({super.key, required this.communityId});

  final String communityId;

  @override
  ConsumerState<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends ConsumerState<CommunityScreen> {
  PeriodKind _kind = PeriodKind.week;

  @override
  Widget build(BuildContext context) {
    final provider = communityDetailProvider(widget.communityId);
    final async = ref.watch(provider);
    final current = async.value;
    return Scaffold(
      key: const Key('community_screen'),
      appBar: AppBar(
        title: Text(
          current == null ? '' : upperCaseFor(current.community.name, context.locale.languageCode),
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
        ),
        actions: [if (current != null) _CommunityMenu(detail: current)],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(
          child: TextButton(
            key: const Key('community_retry'),
            onPressed: () => ref.invalidate(provider),
            child: Text('social.retry'.tr()),
          ),
        ),
        data: (detail) => detail == null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'social.community_not_member'.tr(),
                    key: const Key('community_not_member'),
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            : RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(provider);
                  await ref.read(provider.future);
                },
                child: _CommunityBody(detail: detail, kind: _kind, onKind: (k) => setState(() => _kind = k)),
              ),
      ),
    );
  }
}

class _CommunityBody extends ConsumerWidget {
  const _CommunityBody({required this.detail, required this.kind, required this.onKind});

  final CommunityDetail detail;
  final PeriodKind kind;
  final ValueChanged<PeriodKind> onKind;

  List<TitleLine> _lines(Iterable<PeriodTitle> titles) => [
        for (final t in titles)
          TitleLine(
            category: t.category,
            holders: [for (final id in t.holders) detail.profiles[id]?.displayName ?? '?'],
            value: t.value,
          ),
      ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final muted = TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant);
    final now = ref.read(nowProvider)();
    final key = periodKey(kind, now);
    final previous = _lines(periodTitles(detail.stats, kind, periodKey(kind, now, previous: true)));
    final leaders = _lines(periodTitles(detail.stats, kind, key).where((t) => t.category != 'xp'));
    final rows = [
      for (final s in standings(detail.stats, kind, key))
        if ((detail.profiles[s.userId], detail.stats[s.userId]) case (final profile?, final stats?))
          StandingLine(
            userId: s.userId,
            position: s.position,
            name: profile.displayName,
            initials: profile.initials,
            level: stats.level,
            rank: stats.rank,
            xp: s.xp,
            title: sharedTitleName(stats.activeTitle),
            isMe: s.userId == detail.myId,
          ),
    ];
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        _CommunityHeader(detail: detail),
        const SizedBox(height: 16),
        PeriodSwitch(kind: kind, keyPrefix: 'period', onChanged: onKind),
        SectionHeader('social.titles_prev_${kind.name}'.tr()),
        if (previous.isEmpty)
          Text('social.titles_empty'.tr(), key: const Key('community_titles_empty'), style: muted)
        else
          PeriodTitlesList(key: const Key('community_titles'), kind: kind, lines: previous),
        SectionHeader(
          'social.standings_${kind.name}'.tr(),
          key: const Key('period_remaining'),
          trailing: periodRemainingLabel(kind, now),
        ),
        if (rows.isEmpty)
          Text('social.standings_empty'.tr(), key: const Key('community_standings_empty'), style: muted)
        else
          StandingsList(key: const Key('community_standings'), lines: rows),
        const SizedBox(height: 8),
        Card(
          margin: EdgeInsets.zero,
          clipBehavior: Clip.antiAlias,
          child: ExpansionTile(
            key: const Key('community_muscle_leaders'),
            leading: const Icon(Icons.fitness_center),
            title: Text('social.muscle_leaders'.tr()),
            childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            children: [
              if (leaders.isEmpty)
                Text('social.muscle_leaders_empty'.tr(), style: muted)
              else
                PeriodTitlesList(kind: kind, lines: leaders),
            ],
          ),
        ),
      ],
    );
  }
}

class _CommunityHeader extends StatelessWidget {
  const _CommunityHeader({required this.detail});

  final CommunityDetail detail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final lang = context.locale.languageCode;
    final community = detail.community;
    return Card(
      key: const Key('community_header'),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              community.name,
              style: theme.textTheme.headlineSmall?.copyWith(fontFamily: AppFonts.heading, fontWeight: FontWeight.w900),
            ),
            if (community.description.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(community.description, style: TextStyle(color: scheme.onSurfaceVariant)),
              ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _Chip(
                  icon: Icons.group,
                  text: 'social.community_members'.tr(namedArgs: {'n': '${detail.members.length}'}),
                ),
                _Chip(
                  icon: community.isPublic ? Icons.public : Icons.lock_outline,
                  text: upperCaseFor(
                    (community.isPublic ? 'social.community_public_badge' : 'social.community_private_badge').tr(),
                    lang,
                  ),
                  highlighted: community.isPublic,
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        upperCaseFor('social.community_code_label'.tr(), lang),
                        style: theme.textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant, letterSpacing: 1),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        community.inviteCode,
                        key: const Key('community_code'),
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontFamily: AppFonts.heading,
                          fontWeight: FontWeight.w900,
                          color: scheme.primary,
                          letterSpacing: 2,
                        ),
                      ),
                    ],
                  ),
                ),
                OutlinedButton.icon(
                  key: const Key('community_copy_code'),
                  icon: const Icon(Icons.copy, size: 18),
                  label: Text('social.copy'.tr()),
                  onPressed: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    await Clipboard.setData(ClipboardData(
                      text: 'social.community_invite_text'
                          .tr(namedArgs: {'name': community.name, 'code': community.inviteCode}),
                    ));
                    messenger.showSnackBar(SnackBar(content: Text('social.copied'.tr())));
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.icon, required this.text, this.highlighted = false});

  final IconData icon;
  final String text;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final color = highlighted ? scheme.primary : scheme.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.all(Radius.circular(6)),
        border: Border.all(color: highlighted ? scheme.primary : scheme.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(text, style: theme.textTheme.labelMedium?.copyWith(color: color, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _CommunityMenu extends ConsumerWidget {
  const _CommunityMenu({required this.detail});

  final CommunityDetail detail;

  Future<void> _leave(BuildContext context, WidgetRef ref) async {
    final body = detail.members.length == 1
        ? 'social.community_leave_last_body'
        : detail.iAmOwner
            ? 'social.community_leave_owner_body'
            : 'social.community_leave_body';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('social.community_leave_title'.tr()),
        content: Text(body.tr()),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text('social.cancel'.tr())),
          FilledButton(
            key: const Key('community_leave_confirm'),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('social.community_leave_confirm'.tr()),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await runSocialAction(context, () async {
      await ref.read(communityActionsProvider).leave(detail.community.id);
      if (context.mounted && context.canPop()) context.pop();
    });
  }

  Future<void> _regenerate(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    await runSocialAction(context, () async {
      final code = await ref.read(communityActionsProvider).regenerateCode(detail.community.id);
      messenger.showSnackBar(SnackBar(content: Text('social.community_regenerated'.tr(namedArgs: {'code': code}))));
    });
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<String>(
      key: const Key('community_menu'),
      onSelected: (value) => switch (value) {
        'edit' => showCommunityFormSheet(context, editing: detail.community),
        'regenerate' => _regenerate(context, ref),
        'manage' => showManageMembersSheet(context, detail.community.id),
        _ => _leave(context, ref),
      },
      itemBuilder: (context) => [
        if (detail.iAmOwner) ...[
          PopupMenuItem(key: const Key('community_edit'), value: 'edit', child: Text('social.community_edit'.tr())),
          PopupMenuItem(
            key: const Key('community_regenerate'),
            value: 'regenerate',
            child: Text('social.community_regenerate'.tr()),
          ),
          PopupMenuItem(
            key: const Key('community_manage'),
            value: 'manage',
            child: Text('social.community_manage'.tr()),
          ),
        ],
        PopupMenuItem(key: const Key('community_leave'), value: 'leave', child: Text('social.community_leave'.tr())),
      ],
    );
  }
}
```

- [ ] **Step 5: Rotayı ekle**

`lib/core/router.dart` — importlara ekle:

```dart
import '../features/social/presentation/community_screen.dart';
```

`/social` rotasının `routes` listesinde `settings` satırından sonra ekle:

```dart
                  GoRoute(
                    path: 'community/:id',
                    builder: (context, state) => CommunityScreen(communityId: state.pathParameters['id']!),
                  ),
```

- [ ] **Step 6: Testin geçtiğini gör**

Run: `flutter test --no-pub -j 1 test/features/social/presentation/community_screen_test.dart`
Expected: PASS (5 test).

- [ ] **Step 7: Commit**

```bash
git add lib/features/social/presentation/community_screen.dart lib/features/social/presentation/manage_members_sheet.dart lib/core/router.dart test/features/social/presentation/community_screen_test.dart
git commit -m "feat(social): add the community page with champions, live standings and member management

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 9: Genel sekmesi ve "Genel sıralamada yer al"

**Files:**
- Create: `lib/features/social/presentation/global_tab.dart`
- Modify: `lib/features/social/presentation/social_screen.dart`
- Modify: `lib/features/social/presentation/social_settings_screen.dart`
- Modify: `test/features/social/presentation/social_screen_test.dart`
- Modify: `test/features/social/presentation/social_settings_screen_test.dart`
- Test: `test/features/social/presentation/global_tab_test.dart`

**Interfaces:**
- Consumes: Task 4–6 (`periodCategories`, `GlobalTitle`, `GlobalRow`, `globalBoardProvider`, `myPublicProfileProvider`, `PeriodSwitch`, `PeriodTitlesList`, `TitleLine`, `StandingsList`, `StandingLine`, `periodRemainingLabel`, `sharedTitleName`); `SocialActions.updateProfile(competeGlobally:)`.
- Produces:
  - `GlobalTab` — anahtarlar `global_tab`, `global_period_week`/`global_period_month`, `global_opted_out`, `global_open_settings`, `global_titles`/`global_titles_empty`, `period_remaining`, `global_standings`/`global_standings_empty`, `global_retry`.
  - `List<TitleLine> globalTitleLines(List<GlobalTitle> titles)` — `periodCategories` sırasıyla; sahipler `@kullanıcıadı`, gelen sırayla.
  - Ayarlarda `SwitchListTile` `compete_globally`.

- [ ] **Step 1: Testleri yaz**

`test/features/social/presentation/global_tab_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spor_takip/features/gamification/domain/levels.dart';
import 'package:spor_takip/features/social/application/social_providers.dart';
import 'package:spor_takip/features/social/domain/community.dart';
import 'package:spor_takip/features/social/domain/period_keys.dart';
import 'package:spor_takip/features/social/presentation/global_tab.dart';
import 'package:spor_takip/features/workout/application/session_providers.dart';

import '../../progress/presentation/test_app.dart';
import '../fakes.dart';
import '../social_fixtures.dart';

const _titles = [
  GlobalTitle(
    category: 'lats',
    userId: 'burak',
    username: 'burak',
    displayName: 'Burak',
    level: 20,
    rank: Rank.athlete,
    value: 41,
  ),
  GlobalTitle(
    category: 'xp',
    userId: 'ayse',
    username: 'ayse_k',
    displayName: 'Ayşe Kaya',
    level: 42,
    rank: Rank.gladiator,
    value: 3480,
  ),
  GlobalTitle(
    category: 'lats',
    userId: 'ayse',
    username: 'ayse_k',
    displayName: 'Ayşe Kaya',
    level: 42,
    rank: Rank.gladiator,
    value: 41,
  ),
];

const _rows = [
  GlobalRow(
    position: 1,
    userId: 'ayse',
    username: 'ayse_k',
    displayName: 'Ayşe Kaya',
    level: 42,
    rank: Rank.gladiator,
    xp: 4120,
  ),
  GlobalRow(
    position: 2,
    userId: 'me',
    username: 'samet_fit',
    displayName: 'Samet',
    level: 28,
    rank: Rank.dedicated,
    xp: 2190,
  ),
];

void main() {
  setUpAll(initTestLocalization);
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> pump(WidgetTester tester, FakeSocialRepository repo) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(testApp(
      const Scaffold(body: GlobalTab()),
      scaffold: false,
      overrides: [
        socialRepositoryProvider.overrideWithValue(repo),
        nowProvider.overrideWithValue(() => DateTime(2026, 10, 9, 12)),
      ],
      stubRoutes: {'/social/settings': 'settings-stub'},
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('shows last week global champions and this week top list with me highlighted', (tester) async {
    final repo = FakeSocialRepository(me: socialMe)
      ..globalTitlesResult = _titles
      ..globalRowsResult = _rows;
    await pump(tester, repo);

    expect(repo.globalQueries, [(PeriodKind.week, '2026-W40'), (PeriodKind.week, '2026-W41')]);
    expect(find.byKey(const Key('global_opted_out')), findsNothing);
    expect(
      tester.getTopLeft(find.byKey(const Key('title_xp'))).dy,
      lessThan(tester.getTopLeft(find.byKey(const Key('title_lats'))).dy),
    );
    expect(find.text('@burak, @ayse_k'), findsOneWidget);
    expect(find.text('@ayse_k'), findsWidgets);
    expect(find.byKey(const Key('standing_ayse')), findsOneWidget);
    expect(find.byKey(const Key('standing_me_label')), findsOneWidget);
    expect(find.byKey(const Key('period_remaining')), findsOneWidget);
  });

  testWidgets('the month view asks for month keys; empty results show empty texts', (tester) async {
    final repo = FakeSocialRepository(me: socialMe);
    await pump(tester, repo);
    expect(find.byKey(const Key('global_titles_empty')), findsOneWidget);
    expect(find.byKey(const Key('global_standings_empty')), findsOneWidget);

    repo.globalQueries.clear();
    await tester.tap(find.byKey(const Key('global_period_month')));
    await tester.pumpAndSettle();
    expect(repo.globalQueries, [(PeriodKind.month, '2026-09'), (PeriodKind.month, '2026-10')]);
  });

  testWidgets('opted out shows a note that opens the settings', (tester) async {
    await pump(tester, FakeSocialRepository(me: socialMe.copyWith(competeGlobally: false)));
    expect(find.byKey(const Key('global_opted_out')), findsOneWidget);
    await tester.tap(find.byKey(const Key('global_open_settings')));
    await tester.pumpAndSettle();
    expect(find.text('settings-stub'), findsOneWidget);
  });
}
```

`test/features/social/presentation/social_settings_screen_test.dart` — `main()` içinde son testten sonra ekle:

```dart
  testWidgets('the compete switch saves right away', (tester) async {
    final repo = await pump(tester);
    final competeSwitch = find.byKey(const Key('compete_globally'));
    await tester.ensureVisible(competeSwitch);
    expect(tester.widget<SwitchListTile>(competeSwitch).value, isTrue);
    await tester.tap(competeSwitch);
    await tester.pumpAndSettle();
    expect(repo.me?.competeGlobally, isFalse);
    expect(tester.widget<SwitchListTile>(competeSwitch).value, isFalse);
  });
```

`test/features/social/presentation/social_screen_test.dart` — Task 7'de eklenen sekme testinin sonundaki

```dart
    await tester.tap(find.byKey(const Key('social_tab_global')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('communities_tab')), findsNothing);
```

satırlarını şununla değiştir:

```dart
    await tester.tap(find.byKey(const Key('social_tab_global')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('global_tab')), findsOneWidget);
```

- [ ] **Step 2: Testlerin başarısız olduğunu gör**

Run: `flutter test --no-pub -j 1 test/features/social/presentation/global_tab_test.dart test/features/social/presentation/social_settings_screen_test.dart test/features/social/presentation/social_screen_test.dart`
Expected: FAIL (`global_tab.dart` yok, anahtar yok).

- [ ] **Step 3: Genel sekmesini yaz**

`lib/features/social/presentation/global_tab.dart`:

```dart
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/widgets/section_header.dart';
import '../../workout/application/session_providers.dart';
import '../application/community_providers.dart';
import '../application/social_providers.dart';
import '../domain/community.dart';
import '../domain/period_keys.dart';
import '../domain/standings.dart';
import 'widgets/period_widgets.dart';

/// Genel unvanlar kategori sırasıyla; eşitlikte sahipler @kullanıcıadı ile, gelen sırayla.
List<TitleLine> globalTitleLines(List<GlobalTitle> titles) {
  final lines = <TitleLine>[];
  for (final category in periodCategories) {
    final holders = [
      for (final t in titles)
        if (t.category == category) t,
    ];
    if (holders.isEmpty) continue;
    lines.add(TitleLine(
      category: category,
      holders: [for (final h in holders) '@${h.username}'],
      value: holders.first.value,
    ));
  }
  return lines;
}

/// Genel sekmesi (S2 spec §6.4): geçen dönemin genel şampiyonları ve bu dönemin ilk 50'si.
class GlobalTab extends ConsumerStatefulWidget {
  const GlobalTab({super.key});

  @override
  ConsumerState<GlobalTab> createState() => _GlobalTabState();
}

class _GlobalTabState extends ConsumerState<GlobalTab> {
  PeriodKind _kind = PeriodKind.week;

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(myPublicProfileProvider).value;
    final provider = globalBoardProvider(_kind);
    final async = ref.watch(provider);
    final muted = TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant);
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(provider);
        await ref.read(provider.future);
      },
      child: ListView(
        key: const Key('global_tab'),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          PeriodSwitch(kind: _kind, keyPrefix: 'global_period', onChanged: (k) => setState(() => _kind = k)),
          if (me != null && !me.competeGlobally)
            Card(
              key: const Key('global_opted_out'),
              margin: const EdgeInsets.only(top: 12),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
                child: Row(
                  children: [
                    Expanded(child: Text('social.global_opted_out'.tr())),
                    TextButton(
                      key: const Key('global_open_settings'),
                      onPressed: () => context.push('/social/settings'),
                      child: Text('social.global_open_settings'.tr()),
                    ),
                  ],
                ),
              ),
            ),
          ...async.when(
            loading: () => const [
              Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator())),
            ],
            error: (error, stackTrace) => [
              Center(
                child: TextButton(
                  key: const Key('global_retry'),
                  onPressed: () => ref.invalidate(provider),
                  child: Text('social.retry'.tr()),
                ),
              ),
            ],
            data: (board) => [
              SectionHeader('social.global_titles_${_kind.name}'.tr()),
              if (board.titles.isEmpty)
                Text('social.titles_empty'.tr(), key: const Key('global_titles_empty'), style: muted)
              else
                PeriodTitlesList(key: const Key('global_titles'), kind: _kind, lines: globalTitleLines(board.titles)),
              SectionHeader(
                'social.global_standings_${_kind.name}'.tr(),
                key: const Key('period_remaining'),
                trailing: periodRemainingLabel(_kind, ref.read(nowProvider)()),
              ),
              if (board.rows.isEmpty)
                Text('social.standings_empty'.tr(), key: const Key('global_standings_empty'), style: muted)
              else
                StandingsList(
                  key: const Key('global_standings'),
                  lines: [
                    for (final r in board.rows)
                      StandingLine(
                        userId: r.userId,
                        position: r.position,
                        name: r.displayName,
                        handle: r.username,
                        initials: r.initials,
                        level: r.level,
                        rank: r.rank,
                        xp: r.xp,
                        title: sharedTitleName(r.activeTitle),
                        isMe: r.userId == me?.userId,
                      ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Sosyal ekranda üçüncü sekmeyi bağla**

`lib/features/social/presentation/social_screen.dart` — importlara ekle:

```dart
import 'global_tab.dart';
```

`_Tabs` içindeki

```dart
                // Task 9: GlobalTab.
                const SizedBox.shrink(),
```

satırlarını şununla değiştir:

```dart
                const GlobalTab(),
```

- [ ] **Step 5: Ayarlara "Yarış" bölümünü ekle**

`lib/features/social/presentation/social_settings_screen.dart` — `_SettingsFormState.build` içindeki son öğe

```dart
        Text('social.privacy_note'.tr(), style: TextStyle(color: scheme.onSurfaceVariant)),
```

satırından sonra ekle:

```dart
        SectionHeader('social.compete_title'.tr()),
        SwitchListTile(
          key: const Key('compete_globally'),
          title: Text('social.compete_globally'.tr()),
          subtitle: Text('social.compete_globally_note'.tr()),
          value: me.competeGlobally,
          onChanged: (v) => runSocialAction(context, () => actions.updateProfile(competeGlobally: v)),
        ),
```

- [ ] **Step 6: Testlerin geçtiğini gör**

Run: `flutter test --no-pub -j 1 test/features/social/presentation/global_tab_test.dart test/features/social/presentation/social_settings_screen_test.dart test/features/social/presentation/social_screen_test.dart`
Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add lib/features/social/presentation/global_tab.dart lib/features/social/presentation/social_screen.dart lib/features/social/presentation/social_settings_screen.dart test/features/social/presentation/global_tab_test.dart test/features/social/presentation/social_settings_screen_test.dart test/features/social/presentation/social_screen_test.dart
git commit -m "feat(social): add the global tab and the global standings opt-out

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 10: Doğrulama, veritabanı ve kayıt

**Files:**
- Modify: `PLAN.md` (S2 satırı)

- [ ] **Step 1: Sosyal testlerini çalıştır**

Run: `flutter test --no-pub -j 1 test/features/social`
Expected: PASS (tüm sosyal testleri).

- [ ] **Step 2: Analiz**

Run (arka planda): `flutter analyze --no-pub`
Expected: `No issues found!` Uyarı varsa düzelt ve ilgili testi yeniden çalıştır.

- [ ] **Step 3: Kullanıcıdan tam paketi iste**

Kullanıcıya kendi terminalinde `flutter test -j 1` çalıştırmasını söyle; sonucu (test sayısı, hata yok) bekle.

- [ ] **Step 4: Migration ve RLS kontrolü (kullanıcı)**

Kullanıcıya: Supabase SQL Editor'da `supabase/migrations/0014_social_communities.sql`'i çalıştır; ardından `supabase/migrations/checks/s2_rls_checks.sql`'i çalıştır. Beklenen hata satırı:

```
SONUC: arama=1 kapali_arama=0 acik_degil=not_public kodla_katildi=t B_istatistik=1 C_istatistik=0 C_profil=0 sahip_degismez=t yasakli=banned dogrudan_engellendi=t sahip_B=t son_uye_silindi=t limit=community_limit A_genelde=0 B_genelde=1 xp_unvani_B=t
```

(C yoksa `C_istatistik=atlandi C_profil=atlandi`.) Fark varsa `systematic-debugging` ile migration'ı düzelt, yeni bir `0015_...` yerine aynı dosyayı `create or replace` / `drop policy if exists` ile yeniden uygulanabilir tut ve kontrolü tekrarla.

- [ ] **Step 5: Manuel kontrol (kullanıcı, iki hesap, web release derlemesi)**

Kullanıcı kendi terminalinde web release derlemesini sunar. Kontrol listesi (spec §9):
1. A topluluk kurar; B adla arayıp katılır; ikisi de "Topluluklarım"da görür.
2. Antrenmandan sonra topluluk sayfasında canlı sıralama ve kas liderleri doğru.
3. A topluluğu kapalı yapar; aramada çıkmaz; kodla katılma çalışır.
4. A, B'yi yasaklar; B kodla katılamaz ve hata metnini görür.
5. Genel sekmesinde iki hesap ilk 50'de; A "Genel sıralamada yer al"ı kapatınca A listeden çıkar ve yarış dışı metni görür.
6. Geçen dönem şampiyonları bölümü (henüz geçmiş dönem verisi yoksa boş metni) doğru.
7. Sahip ayrılınca yönetim diğer üyeye geçer.
8. ~360 px'te taşma yok; EN metinler doğru.

- [ ] **Step 6: PLAN.md'ye kaydet**

`PLAN.md`'deki ilerleme tablosunun sonuna (2026-10-10 S1 satırından sonra) bir satır ekle: tarih, "**F5+ S2 (topluluklar ve dönem unvanları) tamamlandı** (`s2-topluluklar` dalı, 10 görev)", kısa özet (alt sekmeler, topluluk kurma/katılma/yönetim, haftalık/aylık canlı sıralama ve unvanlar, genel ilk 50 ve yarıştan çıkma, migration `0014` + `s2_rls_checks.sql` sonucu), bu plandaki sapmalar listesi, otomatik test sayısı ve analiz sonucu, manuel kontrol sonucu, "Sıradaki: S3 (meydan okumalar)".

```bash
git add PLAN.md
git commit -m "docs: record S2 communities and period titles in the plan

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

- [ ] **Step 7: Dalı bitir**

`superpowers:finishing-a-development-branch` ile birleştirme seçeneğini kullanıcıya sor.
