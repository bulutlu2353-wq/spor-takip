# S1 Arkadaşlık Temeli Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Kullanıcı adı ve davet koduyla arkadaş ekleme, arkadaş listesi, arkadaşın seviye/unvan/haftalık özet/son antrenman/kas ısısını gösteren profil ve bölüm bölüm gizlilik; alt menüde beşinci "Sosyal" sekmesi.

**Architecture:** Migration `0013` sosyal kimlik (`public_profiles`), arkadaşlık (`friendships`) ve paylaşılan özet (`player_stats`) tablolarını, RLS'yi ve security definer fonksiyonları ekler. Uygulama O1 `PlayerSummary`'den `PlayerStats` üretip kendi satırını yazar (`statsSyncProvider`, `AppShell` izler); arkadaşlar RLS üzerinden okur. Ekranlar `lib/features/social/` altında.

**Tech Stack:** Flutter, flutter_riverpod 3, go_router, easy_localization, supabase_flutter, Postgres (SQL Editor), flutter_test.

**Spec:** `docs/superpowers/specs/2026-10-09-s1-arkadaslik-design.md`

## Global Constraints

- Dal: `s1-arkadaslik`. Migration `supabase/migrations/0013_social_friends.sql`; kullanıcı SQL Editor'da uygular. Edge Function deploy yok.
- Görevlerde yalnızca ilgili test dosyaları çalıştırılır: `flutter test --no-pub -j 1 <dosya>`. Tam paketi kullanıcı kendi terminalinde çalıştırır.
- `flutter analyze --no-pub` arka planda; "No issues found!".
- `dart format` çalıştırılmaz; satırlar ≤ ~120 karakter.
- Testlerde çeviriler yüklenmez; `.tr()` ham anahtarı döndürür; `upperCaseFor(..., 'tr')` `i`'yi `İ` yapar (test metinleri buna göre aranır ya da `Key` kullanılır).
- Kullanıcı adı: `^[a-z0-9_]{3,20}$`; görünen ad 1–30 karakter; davet kodu 8 karakter, alfabe `ABCDEFGHJKLMNPQRSTUVWXYZ23456789`.
- `send_friend_request` dönüşleri: `'pending'`, `'accepted'`, `'already_friends'`.
- Paylaşılmayanlar: kilo, ölçü, beslenme içeriği, sağlık notları, e-posta.
- Commit mesajları şu satırla biter: `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`
- Bash aracı her komutta `commit-graph` / CRLF uyarıları basar; zararsız.

## Spec'ten bilinçli sapmalar (kullanıcıya bildirilecek)

1. **`friendsProvider` yerine `socialOverviewProvider`:** Arkadaşlar, gelen ve giden istekler tek sağlayıcıda (`SocialOverview`) birleşir; profiller tek istekle çekilir. `friendProfileProvider(id)` bunun üstünde.
2. **`UsernameField` ortak widget:** Kimlik oluşturma ve ayarlar aynı uygunluk göstergeli alanı kullanır.
3. **`MiniMuscleMapCard`:** `onTap` isteğe bağlı ve `showTitle` (varsayılan `true`) eklendi; spec'teki `title` parametresi yerine bölüm başlığı ekranda `SectionHeader` ile verilir.
4. **Sayılar arası sıralama:** Arkadaş listesi seviye (büyükten küçüğe), sonra görünen ad.
5. **Arkadaş profilinden çıkarınca** ekran yalnız geri gidilebiliyorsa kapanır (`canPop`).
6. **Davet kodu kutusu** düz çerçeveli (kesik çizgi için ek boyama yok).

## Dosya yapısı

| Dosya | Görev |
|---|---|
| `supabase/migrations/0013_social_friends.sql` | Tablolar, RLS, fonksiyonlar, izinler |
| `supabase/migrations/checks/s1_rls_checks.sql` | A/B/C DO bloğu |
| `lib/features/social/domain/username.dart` | `UsernameProblem`, `normalizeUsername`, `checkUsername` |
| `lib/features/social/domain/public_profile.dart` | `PublicProfile`, `FoundUser` |
| `lib/features/social/domain/friendship.dart` | `FriendshipState`, `Friendship` |
| `lib/features/social/domain/player_stats.dart` | `SharedPrivacy`, `WeeklyStats`, `SharedRecord`, `RecentWorkout`, `SharedTitle`, `PlayerStats`, `buildPlayerStats` |
| `lib/features/social/data/social_repository.dart` | `SocialRepository`, `UsernameTakenException`, `SupabaseSocialRepository` |
| `lib/features/social/application/social_providers.dart` | Sağlayıcılar, `SocialOverview`, `FriendEntry`, `RequestEntry`, `SocialActions`, `statsSyncProvider` |
| `lib/features/social/presentation/widgets/social_avatar.dart` | `SocialAvatar`, `TitlePill` |
| `lib/features/social/presentation/widgets/username_field.dart` | `UsernameStatus`, `UsernameField` |
| `lib/features/social/presentation/social_screen.dart` | `SocialScreen` |
| `lib/features/social/presentation/add_friend_sheet.dart` | `showAddFriendSheet`, `AddFriendSheet` |
| `lib/features/social/presentation/friend_profile_screen.dart` | `FriendProfileScreen`, `agoLabel` |
| `lib/features/social/presentation/social_settings_screen.dart` | `SocialSettingsScreen` |
| `lib/features/workout/presentation/widgets/muscle_map.dart` | `MiniMuscleMapCard(onTap?, showTitle)` |
| `lib/core/app_shell.dart`, `lib/core/router.dart` | Beşinci sekme ve rotalar |
| `assets/translations/tr.json`, `en.json` | `nav.social`, `social` bloğu |
| `test/features/social/...` | Testler, `fakes.dart`, `social_fixtures.dart` |
| `test/core/app_shell_test.dart` | ProviderScope + beşinci dal |

---

### Task 1: Migration ve RLS kontrolü

**Files:**
- Create: `supabase/migrations/0013_social_friends.sql`
- Create: `supabase/migrations/checks/s1_rls_checks.sql`

**Interfaces:**
- Produces (veritabanı): tablolar `public_profiles`, `friendships`, `player_stats`; fonksiyonlar `new_invite_code()`, `are_friends(uuid, uuid)`, `has_friendship(uuid, uuid)`, `find_user(text)`, `find_user_by_invite(text)`, `username_available(text)`, `send_friend_request(uuid)`, `respond_friend_request(uuid, boolean)`, `remove_friend(uuid)`.

- [ ] **Step 1: Migration'ı yaz**

`supabase/migrations/0013_social_friends.sql`:

```sql
-- S1 arkadaşlık temeli: sosyal kimlik, arkadaşlıklar, paylaşılan oyuncu özeti.
-- Kilo, ölçü, beslenme ve sağlık verisi bu tablolara hiç yazılmaz.

-- 8 karakter; karışan 0/O/1/I yok.
create or replace function public.new_invite_code() returns text
language sql volatile
as $$
  select string_agg(substr('ABCDEFGHJKLMNPQRSTUVWXYZ23456789', 1 + floor(random() * 32)::int, 1), '')
  from generate_series(1, 8);
$$;

create table if not exists public.public_profiles (
  user_id uuid primary key references auth.users (id) on delete cascade,
  username text not null unique check (username ~ '^[a-z0-9_]{3,20}$'),
  display_name text not null check (char_length(btrim(display_name)) between 1 and 30),
  invite_code text not null unique default public.new_invite_code(),
  share_weekly boolean not null default true,
  share_workouts boolean not null default true,
  share_heat boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.friendships (
  requester uuid not null references auth.users (id) on delete cascade,
  addressee uuid not null references auth.users (id) on delete cascade,
  status text not null check (status in ('pending', 'accepted')),
  created_at timestamptz not null default now(),
  accepted_at timestamptz,
  primary key (requester, addressee),
  check (requester <> addressee)
);

-- Aynı iki kişi arasında yönden bağımsız tek satır.
create unique index if not exists friendships_pair_idx
  on public.friendships (least(requester, addressee), greatest(requester, addressee));
create index if not exists friendships_addressee_idx on public.friendships (addressee);

create table if not exists public.player_stats (
  user_id uuid primary key references auth.users (id) on delete cascade,
  level int not null,
  total_xp int not null,
  rank text not null,
  active_title jsonb,
  titles jsonb not null default '[]'::jsonb,
  weekly jsonb,
  recent jsonb,
  heat jsonb,
  updated_at timestamptz not null default now()
);

create or replace function public.are_friends(a uuid, b uuid) returns boolean
language sql stable security definer set search_path = public
as $$
  select exists (
    select 1 from friendships
    where status = 'accepted'
      and ((requester = a and addressee = b) or (requester = b and addressee = a))
  );
$$;

create or replace function public.has_friendship(a uuid, b uuid) returns boolean
language sql stable security definer set search_path = public
as $$
  select exists (
    select 1 from friendships
    where (requester = a and addressee = b) or (requester = b and addressee = a)
  );
$$;

alter table public.public_profiles enable row level security;
alter table public.friendships enable row level security;
alter table public.player_stats enable row level security;

-- Kendisi ve aralarında bekleyen ya da kabul edilmiş arkadaşlık olan kişi okur.
create policy "Profiles visible to self and connections"
  on public.public_profiles for select
  using (user_id = auth.uid() or public.has_friendship(auth.uid(), user_id));

create policy "Users insert own social profile"
  on public.public_profiles for insert
  with check (user_id = auth.uid());

create policy "Users update own social profile"
  on public.public_profiles for update
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

-- Yazma yalnız fonksiyonlarla.
create policy "Parties see their friendships"
  on public.friendships for select
  using (auth.uid() in (requester, addressee));

create policy "Stats visible to self and friends"
  on public.player_stats for select
  using (user_id = auth.uid() or public.are_friends(auth.uid(), user_id));

create policy "Users insert own stats"
  on public.player_stats for insert
  with check (user_id = auth.uid());

create policy "Users update own stats"
  on public.player_stats for update
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

-- Tam eşleşme; kendini döndürmez; başındaki '@' yok sayılır.
create or replace function public.find_user(p_username text)
returns table (user_id uuid, username text, display_name text)
language sql stable security definer set search_path = public
as $$
  select p.user_id, p.username, p.display_name
  from public_profiles p
  where auth.uid() is not null
    and p.username = lower(ltrim(btrim(p_username), '@'))
    and p.user_id <> auth.uid();
$$;

create or replace function public.find_user_by_invite(p_code text)
returns table (user_id uuid, username text, display_name text)
language sql stable security definer set search_path = public
as $$
  select p.user_id, p.username, p.display_name
  from public_profiles p
  where auth.uid() is not null
    and p.invite_code = upper(btrim(p_code))
    and p.user_id <> auth.uid();
$$;

-- Kurala uyuyor ve başkasında değilse true (kendi adı da true).
create or replace function public.username_available(p_username text) returns boolean
language sql stable security definer set search_path = public
as $$
  select lower(btrim(p_username)) ~ '^[a-z0-9_]{3,20}$'
    and not exists (
      select 1 from public_profiles p
      where p.username = lower(btrim(p_username)) and p.user_id <> auth.uid()
    );
$$;

-- Karşı taraftan bekleyen istek varsa doğrudan arkadaş olunur.
create or replace function public.send_friend_request(p_target uuid) returns text
language plpgsql security definer set search_path = public
as $$
declare
  me uuid := auth.uid();
  existing friendships;
begin
  if me is null then
    raise exception 'not authenticated';
  end if;
  if p_target = me then
    raise exception 'self_request';
  end if;
  if not exists (select 1 from public_profiles where user_id = me) then
    raise exception 'no_profile';
  end if;
  if not exists (select 1 from public_profiles where user_id = p_target) then
    raise exception 'unknown_user';
  end if;

  select * into existing from friendships
    where (requester = me and addressee = p_target) or (requester = p_target and addressee = me);
  if found then
    if existing.status = 'accepted' then
      return 'already_friends';
    end if;
    if existing.requester = me then
      return 'pending';
    end if;
    update friendships set status = 'accepted', accepted_at = now()
      where requester = p_target and addressee = me;
    return 'accepted';
  end if;

  insert into friendships (requester, addressee, status) values (me, p_target, 'pending');
  return 'pending';
end;
$$;

create or replace function public.respond_friend_request(p_requester uuid, p_accept boolean) returns void
language plpgsql security definer set search_path = public
as $$
declare
  me uuid := auth.uid();
begin
  if me is null then
    raise exception 'not authenticated';
  end if;
  if p_accept then
    update friendships set status = 'accepted', accepted_at = now()
      where requester = p_requester and addressee = me and status = 'pending';
  else
    delete from friendships
      where requester = p_requester and addressee = me and status = 'pending';
  end if;
  if not found then
    raise exception 'no_request';
  end if;
end;
$$;

-- Arkadaşlığı bitirir ya da isteği geri çeker/reddeder; satır yoksa sessiz.
create or replace function public.remove_friend(p_other uuid) returns void
language plpgsql security definer set search_path = public
as $$
declare
  me uuid := auth.uid();
begin
  if me is null then
    raise exception 'not authenticated';
  end if;
  delete from friendships
    where (requester = me and addressee = p_other) or (requester = p_other and addressee = me);
end;
$$;

revoke execute on function public.are_friends(uuid, uuid) from public, anon;
revoke execute on function public.has_friendship(uuid, uuid) from public, anon;
revoke execute on function public.find_user(text) from public, anon;
revoke execute on function public.find_user_by_invite(text) from public, anon;
revoke execute on function public.username_available(text) from public, anon;
revoke execute on function public.send_friend_request(uuid) from public, anon;
revoke execute on function public.respond_friend_request(uuid, boolean) from public, anon;
revoke execute on function public.remove_friend(uuid) from public, anon;

grant execute on function public.are_friends(uuid, uuid) to authenticated;
grant execute on function public.has_friendship(uuid, uuid) to authenticated;
grant execute on function public.find_user(text) to authenticated;
grant execute on function public.find_user_by_invite(text) to authenticated;
grant execute on function public.username_available(text) to authenticated;
grant execute on function public.send_friend_request(uuid) to authenticated;
grant execute on function public.respond_friend_request(uuid, boolean) to authenticated;
grant execute on function public.remove_friend(uuid) to authenticated;
```

- [ ] **Step 2: RLS kontrolünü yaz**

`supabase/migrations/checks/s1_rls_checks.sql`:

```sql
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
```

- [ ] **Step 3: Kullanıcıdan uygulama (bu görevde ya da Task 10'da)**

Kullanıcı Supabase SQL Editor'da önce `0013_social_friends.sql`'i, sonra `checks/s1_rls_checks.sql`'i çalıştırır. Beklenen hata satırı Step 2'deki "Beklenen" satırıyla aynı olmalı. Uygulama kodu migration olmadan da testlerden geçer; migration manuel kontrolden önce uygulanmış olmalı.

- [ ] **Step 4: Commit**

```bash
git add supabase/migrations/0013_social_friends.sql supabase/migrations/checks/s1_rls_checks.sql
git commit -m "feat(social): add social profiles, friendships and shared player stats

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 2: Kullanıcı adı, profil ve arkadaşlık modelleri

**Files:**
- Create: `lib/features/social/domain/username.dart`
- Create: `lib/features/social/domain/public_profile.dart`
- Create: `lib/features/social/domain/friendship.dart`
- Test: `test/features/social/domain/social_models_test.dart`

**Interfaces:**
- Produces:
  - `enum UsernameProblem { tooShort, tooLong, invalidCharacters }`
  - `String normalizeUsername(String raw)`, `UsernameProblem? checkUsername(String normalized)`
  - `class PublicProfile { String userId, username, displayName, inviteCode; bool shareWeekly, shareWorkouts, shareHeat; String get initials; PublicProfile copyWith({...}); factory fromJson; }`
  - `class FoundUser { String userId, username, displayName; String get initials; factory fromJson; }`
  - `enum FriendshipState { incoming, outgoing, friends }`
  - `class Friendship { String requester, addressee; bool accepted; DateTime createdAt; FriendshipState stateFor(String me); String otherThan(String me); factory fromJson; }`
  - `String initialsOf(String displayName, String username)`

- [ ] **Step 1: Başarısız testleri yaz**

`test/features/social/domain/social_models_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:spor_takip/features/social/domain/friendship.dart';
import 'package:spor_takip/features/social/domain/public_profile.dart';
import 'package:spor_takip/features/social/domain/username.dart';

void main() {
  test('usernames are trimmed, lowercased and lose a leading @', () {
    expect(normalizeUsername('  @Samet_Fit '), 'samet_fit');
    expect(normalizeUsername('ab'), 'ab');
  });

  test('username rules: 3–20 characters of a–z, 0–9 and _', () {
    expect(checkUsername('ab'), UsernameProblem.tooShort);
    expect(checkUsername('abc'), isNull);
    expect(checkUsername('a' * 20), isNull);
    expect(checkUsername('a' * 21), UsernameProblem.tooLong);
    expect(checkUsername('ali-veli'), UsernameProblem.invalidCharacters);
    expect(checkUsername('şule'), UsernameProblem.invalidCharacters);
    expect(checkUsername('ali veli'), UsernameProblem.invalidCharacters);
  });

  test('a profile reads its row and falls back to sharing everything', () {
    final p = PublicProfile.fromJson({
      'user_id': 'u1',
      'username': 'samet_fit',
      'display_name': 'Samet Aydın',
      'invite_code': 'K7Q2M9XA',
      'share_weekly': false,
    });
    expect((p.userId, p.username, p.displayName, p.inviteCode), ('u1', 'samet_fit', 'Samet Aydın', 'K7Q2M9XA'));
    expect((p.shareWeekly, p.shareWorkouts, p.shareHeat), (false, true, true));
    expect(p.initials, 'SA');
    expect(p.copyWith(shareHeat: false).shareHeat, isFalse);
    expect(p.copyWith(displayName: 'Ali').displayName, 'Ali');
  });

  test('initials come from the first two words, else the first two letters', () {
    expect(initialsOf('Ayşe Kaya', 'ayse'), 'AK');
    expect(initialsOf('deniz', 'deniz'), 'DE');
    expect(initialsOf('  ', 'mo'), 'MO');
  });

  test('found users read the function rows', () {
    final f = FoundUser.fromJson({'user_id': 'u2', 'username': 'ayse.k', 'display_name': 'Ayşe Kaya'});
    expect((f.userId, f.username, f.displayName, f.initials), ('u2', 'ayse.k', 'Ayşe Kaya', 'AK'));
  });

  test('a friendship knows its side', () {
    final f = Friendship.fromJson({
      'requester': 'me',
      'addressee': 'ayse',
      'status': 'pending',
      'created_at': '2026-10-09T10:00:00Z',
    });
    expect(f.stateFor('me'), FriendshipState.outgoing);
    expect(f.stateFor('ayse'), FriendshipState.incoming);
    expect(f.otherThan('me'), 'ayse');
    expect(f.otherThan('ayse'), 'me');
    final accepted = Friendship(requester: 'me', addressee: 'ayse', accepted: true, createdAt: DateTime(2026));
    expect(accepted.stateFor('ayse'), FriendshipState.friends);
  });
}
```

- [ ] **Step 2: Testin başarısız olduğunu gör**

Run: `flutter test --no-pub -j 1 test/features/social/domain/social_models_test.dart`
Expected: FAIL — dosyalar yok.

- [ ] **Step 3: Modelleri yaz**

`lib/features/social/domain/username.dart`:

```dart
/// Kullanıcı adı kuralı (S1 spec §3.1): 3–20 karakter, a–z, 0–9, _.
enum UsernameProblem { tooShort, tooLong, invalidCharacters }

final _allowed = RegExp(r'^[a-z0-9_]+$');

/// Boşluklar kırpılır, küçük harfe çevrilir, baştaki '@' atılır.
String normalizeUsername(String raw) {
  final lower = raw.trim().toLowerCase();
  return lower.startsWith('@') ? lower.substring(1) : lower;
}

UsernameProblem? checkUsername(String normalized) {
  if (normalized.length < 3) return UsernameProblem.tooShort;
  if (normalized.length > 20) return UsernameProblem.tooLong;
  if (!_allowed.hasMatch(normalized)) return UsernameProblem.invalidCharacters;
  return null;
}
```

`lib/features/social/domain/public_profile.dart`:

```dart
/// Avatar baş harfleri: ilk iki kelimenin baş harfi, tek kelimede ilk iki harf;
/// görünen ad boşsa kullanıcı adından.
String initialsOf(String displayName, String username) {
  final words = displayName.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
  final source = words.isEmpty ? username : words.first;
  final letters = words.length >= 2
      ? '${words[0].substring(0, 1)}${words[1].substring(0, 1)}'
      : source.substring(0, source.length < 2 ? source.length : 2);
  return letters.toUpperCase();
}

/// Sosyal kimlik (S1 spec §3.1). Arkadaşların satırında da gizlilik bayrakları gelir.
class PublicProfile {
  const PublicProfile({
    required this.userId,
    required this.username,
    required this.displayName,
    required this.inviteCode,
    this.shareWeekly = true,
    this.shareWorkouts = true,
    this.shareHeat = true,
  });

  final String userId;
  final String username;
  final String displayName;
  final String inviteCode;
  final bool shareWeekly;
  final bool shareWorkouts;
  final bool shareHeat;

  String get initials => initialsOf(displayName, username);

  factory PublicProfile.fromJson(Map<String, dynamic> json) => PublicProfile(
        userId: json['user_id'] as String,
        username: json['username'] as String,
        displayName: json['display_name'] as String,
        inviteCode: json['invite_code'] as String? ?? '',
        shareWeekly: json['share_weekly'] as bool? ?? true,
        shareWorkouts: json['share_workouts'] as bool? ?? true,
        shareHeat: json['share_heat'] as bool? ?? true,
      );

  PublicProfile copyWith({
    String? username,
    String? displayName,
    bool? shareWeekly,
    bool? shareWorkouts,
    bool? shareHeat,
  }) =>
      PublicProfile(
        userId: userId,
        username: username ?? this.username,
        displayName: displayName ?? this.displayName,
        inviteCode: inviteCode,
        shareWeekly: shareWeekly ?? this.shareWeekly,
        shareWorkouts: shareWorkouts ?? this.shareWorkouts,
        shareHeat: shareHeat ?? this.shareHeat,
      );
}

/// `find_user` / `find_user_by_invite` satırı.
class FoundUser {
  const FoundUser({required this.userId, required this.username, required this.displayName});

  final String userId;
  final String username;
  final String displayName;

  String get initials => initialsOf(displayName, username);

  factory FoundUser.fromJson(Map<String, dynamic> json) => FoundUser(
        userId: json['user_id'] as String,
        username: json['username'] as String,
        displayName: json['display_name'] as String,
      );
}
```

`lib/features/social/domain/friendship.dart`:

```dart
/// Benim açımdan bir arkadaşlık satırı.
enum FriendshipState { incoming, outgoing, friends }

class Friendship {
  const Friendship({
    required this.requester,
    required this.addressee,
    required this.accepted,
    required this.createdAt,
  });

  final String requester;
  final String addressee;
  final bool accepted;
  final DateTime createdAt;

  FriendshipState stateFor(String me) {
    if (accepted) return FriendshipState.friends;
    return requester == me ? FriendshipState.outgoing : FriendshipState.incoming;
  }

  String otherThan(String me) => requester == me ? addressee : requester;

  factory Friendship.fromJson(Map<String, dynamic> json) => Friendship(
        requester: json['requester'] as String,
        addressee: json['addressee'] as String,
        accepted: json['status'] == 'accepted',
        createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
      );
}
```

- [ ] **Step 4: Testlerin geçtiğini gör**

Run: `flutter test --no-pub -j 1 test/features/social/domain/social_models_test.dart`
Expected: PASS (6 test).

- [ ] **Step 5: Commit**

```bash
git add lib/features/social/domain/username.dart lib/features/social/domain/public_profile.dart lib/features/social/domain/friendship.dart test/features/social/domain/social_models_test.dart
git commit -m "feat(social): add username rules, social profiles and friendships

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 3: Paylaşılan oyuncu özeti

**Files:**
- Create: `lib/features/social/domain/player_stats.dart`
- Test: `test/features/social/domain/player_stats_test.dart`

**Interfaces:**
- Consumes: `PlayerSummary`, `playerSummary` (O1), `Rank`, `TitleKind`, `TitleTier`, `TitleProgress`, `xpEvents`, `XpSource`; `heatTiers`, `historyMuscleLoad`, `HeatTier` (K3); `startOfWeek` (`lib/features/progress/domain/weekly_summary.dart`); test yardımcıları `gameSession`, `gameSet`, `gameSets`, `gameExercisesById` (`test/features/gamification/game_fixtures.dart`).
- Produces:
  - `class SharedPrivacy { bool weekly, workouts, heat; }`
  - `class WeeklyStats { int workouts, sets, mealDays; }`
  - `class SharedRecord { String name; double weightKg; int reps; }`
  - `class RecentWorkout { String name; DateTime date; int sets; List<SharedRecord> records; }`
  - `class SharedTitle { TitleKind kind; String subjectId; String? exerciseName; TitleTier tier; TitleProgress get asProgress; }`
  - `class PlayerStats { int level, totalXp; Rank rank; SharedTitle? activeTitle; List<SharedTitle> titles; WeeklyStats? weekly; List<RecentWorkout>? recent; Map<String, HeatTier>? heat; DateTime? updatedAt; Map<String, dynamic> toJson(); factory fromJson; == / hashCode (updatedAt hariç) }`
  - `PlayerStats buildPlayerStats({required PlayerSummary summary, required List<WorkoutSession> sessions, required List<DateTime> mealTimes, required Map<String, Exercise> exercisesById, required DateTime now, required String? activeTitleId, required SharedPrivacy privacy})`

- [ ] **Step 1: Başarısız testleri yaz**

`test/features/social/domain/player_stats_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:spor_takip/features/gamification/domain/levels.dart';
import 'package:spor_takip/features/gamification/domain/player_summary.dart';
import 'package:spor_takip/features/gamification/domain/titles.dart';
import 'package:spor_takip/features/gamification/domain/xp_rules.dart';
import 'package:spor_takip/features/social/domain/player_stats.dart';
import 'package:spor_takip/features/workout/domain/muscle_heat.dart';

import '../../gamification/game_fixtures.dart';

// Cuma; hafta pazartesi 5 Ekim'de başlar.
final _now = DateTime(2026, 10, 9, 12);

final _sessions = [
  gameSession('sun', DateTime(2026, 10, 4, 23, 59), gameSets('bench', 2, kg: 100, reps: 5), workoutName: 'Push A'),
  gameSession('mon', DateTime(2026, 10, 5), gameSets('bench', 3, kg: 100, reps: 6), workoutName: 'Push B'),
  gameSession('wed', DateTime(2026, 10, 7, 18), gameSets('squat', 4), workoutName: 'Legs'),
  gameSession('empty', DateTime(2026, 10, 8), [gameSet('bench', done: false)], workoutName: 'Empty'),
  gameSession('live', null, gameSets('bench', 5)),
];

final _meals = [
  DateTime(2026, 10, 4, 20),
  DateTime(2026, 10, 6, 8),
  DateTime(2026, 10, 6, 13),
  DateTime(2026, 10, 8, 9),
];

PlayerStats _build({SharedPrivacy privacy = const SharedPrivacy(), String? active, PlayerSummary? summary}) =>
    buildPlayerStats(
      summary: summary ?? playerSummary(_sessions, _meals, gameExercisesById),
      sessions: _sessions,
      mealTimes: _meals,
      exercisesById: gameExercisesById,
      now: _now,
      activeTitleId: active,
      privacy: privacy,
    );

PlayerSummary _summaryWithTitles(int count) => PlayerSummary(
      totalXp: 0,
      progress: levelFor(0),
      rank: Rank.rookie,
      breakdown: const XpBreakdown(),
      recent: const [],
      titles: [
        for (var i = 0; i < count; i++)
          TitleProgress(kind: TitleKind.exercise, subjectId: 'e$i', value: 12, exerciseName: 'Ex $i'),
      ],
      upcoming: const [],
    );

void main() {
  test('level, XP and rank come from the summary', () {
    final summary = playerSummary(_sessions, _meals, gameExercisesById);
    final stats = _build();
    expect((stats.level, stats.totalXp, stats.rank), (summary.progress.level, summary.totalXp, summary.rank));
  });

  test('the week starts on Monday and counts workouts with sets, sets and meal days', () {
    final weekly = _build().weekly!;
    expect((weekly.workouts, weekly.sets, weekly.mealDays), (2, 7, 2));
  });

  test('recent workouts are the last five with sets, newest first, with their records', () {
    final recent = _build().recent!;
    expect([for (final r in recent) r.name], ['Legs', 'Push B', 'Push A']);
    expect(recent[1].sets, 3);
    expect(recent[1].date, DateTime(2026, 10, 5));
    expect([for (final r in recent[1].records) (r.name, r.weightKg, r.reps)], [('Barbell Bench Press', 100.0, 6)]);
    expect(recent[0].records, isEmpty);
  });

  test('heat covers the last seven days', () {
    expect(_build().heat, {
      'chest': HeatTier.medium,
      'triceps': HeatTier.low,
      'quadriceps': HeatTier.medium,
    });
  });

  test('closed sections are left out', () {
    final stats = _build(privacy: const SharedPrivacy(weekly: false, workouts: false, heat: false));
    expect(stats.weekly, isNull);
    expect(stats.recent, isNull);
    expect(stats.heat, isNull);
    final onlyHeat = _build(privacy: const SharedPrivacy(heat: false));
    expect(onlyHeat.weekly, isNotNull);
    expect(onlyHeat.heat, isNull);
  });

  test('at most ten titles and the equipped one if still earned', () {
    final stats = _build(summary: _summaryWithTitles(12), active: 'exercise:e3');
    expect(stats.titles, hasLength(10));
    expect(stats.titles.first.subjectId, 'e0');
    expect(stats.activeTitle?.subjectId, 'e3');
    expect(stats.activeTitle?.tier, TitleTier.apprentice);
    expect(_build(summary: _summaryWithTitles(2), active: 'muscle:neck').activeTitle, isNull);
  });

  test('json round trip keeps everything and equality ignores the update time', () {
    final stats = _build(summary: _summaryWithTitles(2), active: 'exercise:e1');
    final json = stats.toJson();
    expect(json.containsKey('updated_at'), isFalse);
    final back = PlayerStats.fromJson({...json, 'updated_at': '2026-10-09T09:00:00Z'});
    expect(back, stats);
    expect(back.updatedAt, DateTime.utc(2026, 10, 9, 9).toLocal());
    expect(back.recent![1].records.single.weightKg, 100);
    expect(back.titles.first.asProgress.exerciseName, 'Ex 0');
  });

  test('heat order and unknown values do not break equality or parsing', () {
    final a = PlayerStats.fromJson({
      'level': 2,
      'total_xp': 150,
      'rank': 'mystery',
      'titles': [
        {'kind': 'muscle', 'subject_id': 'chest', 'tier': 'master'},
        {'kind': 'alien', 'subject_id': 'x', 'tier': 'master'},
      ],
      'heat': {'quadriceps': 'low', 'chest': 'high', 'calves': 'nuclear'},
    });
    final b = PlayerStats.fromJson({
      'level': 2,
      'total_xp': 150,
      'rank': 'rookie',
      'titles': [
        {'kind': 'muscle', 'subject_id': 'chest', 'tier': 'master'},
      ],
      'heat': {'chest': 'high', 'quadriceps': 'low'},
    });
    expect(a.rank, Rank.rookie);
    expect(a.titles, hasLength(1));
    expect(a.heat, {'quadriceps': HeatTier.low, 'chest': HeatTier.high});
    expect(a, b);
    expect(a.hashCode, b.hashCode);
    expect(a.weekly, isNull);
    expect(a.recent, isNull);
  });
}
```

Not: Isı: 7 günde (2 Ekim 12:00'dan sonra) bench 5 set → chest 5 (medium), triceps 2,5 (low); squat 4 → quadriceps 4 (medium). Rekor: pazartesi 100×6 = 120 > pazar 100×5 ≈ 116,7.

- [ ] **Step 2: Testin başarısız olduğunu gör**

Run: `flutter test --no-pub -j 1 test/features/social/domain/player_stats_test.dart`
Expected: FAIL — `player_stats.dart` yok.

- [ ] **Step 3: Özeti yaz**

`lib/features/social/domain/player_stats.dart`:

```dart
import 'dart:convert';

import '../../gamification/domain/levels.dart';
import '../../gamification/domain/player_summary.dart';
import '../../gamification/domain/titles.dart';
import '../../gamification/domain/xp_rules.dart';
import '../../progress/domain/weekly_summary.dart';
import '../../workout/domain/exercise.dart';
import '../../workout/domain/muscle_heat.dart';
import '../../workout/domain/workout_session.dart';

/// Arkadaşlara açık bölümler (S1 spec §2.3).
class SharedPrivacy {
  const SharedPrivacy({this.weekly = true, this.workouts = true, this.heat = true});

  final bool weekly;
  final bool workouts;
  final bool heat;
}

class WeeklyStats {
  const WeeklyStats({required this.workouts, required this.sets, required this.mealDays});

  final int workouts;
  final int sets;
  final int mealDays;

  Map<String, dynamic> toJson() => {'workouts': workouts, 'sets': sets, 'meal_days': mealDays};

  factory WeeklyStats.fromJson(Map<String, dynamic> json) => WeeklyStats(
        workouts: (json['workouts'] as num?)?.toInt() ?? 0,
        sets: (json['sets'] as num?)?.toInt() ?? 0,
        mealDays: (json['meal_days'] as num?)?.toInt() ?? 0,
      );
}

class SharedRecord {
  const SharedRecord({required this.name, required this.weightKg, required this.reps});

  final String name;
  final double weightKg;
  final int reps;

  Map<String, dynamic> toJson() => {'name': name, 'weight_kg': weightKg, 'reps': reps};

  factory SharedRecord.fromJson(Map<String, dynamic> json) => SharedRecord(
        name: json['name'] as String? ?? '',
        weightKg: (json['weight_kg'] as num?)?.toDouble() ?? 0,
        reps: (json['reps'] as num?)?.toInt() ?? 0,
      );
}

class RecentWorkout {
  const RecentWorkout({required this.name, required this.date, required this.sets, required this.records});

  final String name;

  /// Yerel bitiş zamanı.
  final DateTime date;
  final int sets;
  final List<SharedRecord> records;

  Map<String, dynamic> toJson() => {
        'name': name,
        'date': date.toUtc().toIso8601String(),
        'sets': sets,
        'records': [for (final r in records) r.toJson()],
      };

  factory RecentWorkout.fromJson(Map<String, dynamic> json) => RecentWorkout(
        name: json['name'] as String? ?? '',
        date: DateTime.parse(json['date'] as String).toLocal(),
        sets: (json['sets'] as num?)?.toInt() ?? 0,
        records: [
          for (final r in json['records'] as List? ?? const []) SharedRecord.fromJson(r as Map<String, dynamic>),
        ],
      );
}

class SharedTitle {
  const SharedTitle({required this.kind, required this.subjectId, required this.tier, this.exerciseName});

  final TitleKind kind;
  final String subjectId;
  final String? exerciseName;
  final TitleTier tier;

  /// `titleName` için; değer kullanılmaz.
  TitleProgress get asProgress =>
      TitleProgress(kind: kind, subjectId: subjectId, value: 0, exerciseName: exerciseName);

  Map<String, dynamic> toJson() => {
        'kind': kind.name,
        'subject_id': subjectId,
        'exercise_name': exerciseName,
        'tier': tier.name,
      };

  /// Bilinmeyen tür ya da kademe (gelecek sürüm) → null.
  static SharedTitle? fromJson(Map<String, dynamic> json) {
    final kind = TitleKind.values.asNameMap()[json['kind']];
    final tier = TitleTier.values.asNameMap()[json['tier']];
    if (kind == null || tier == null) return null;
    return SharedTitle(
      kind: kind,
      subjectId: json['subject_id'] as String? ?? '',
      exerciseName: json['exercise_name'] as String?,
      tier: tier,
    );
  }
}

/// `player_stats` satırı (S1 spec §3.3). Eşitlik `updatedAt`'i saymaz:
/// içerik değişmediyse yeniden yazılmaz.
class PlayerStats {
  const PlayerStats({
    required this.level,
    required this.totalXp,
    required this.rank,
    required this.titles,
    this.activeTitle,
    this.weekly,
    this.recent,
    this.heat,
    this.updatedAt,
  });

  final int level;
  final int totalXp;
  final Rank rank;
  final SharedTitle? activeTitle;
  final List<SharedTitle> titles;
  final WeeklyStats? weekly;
  final List<RecentWorkout>? recent;
  final Map<String, HeatTier>? heat;
  final DateTime? updatedAt;

  Map<String, dynamic> toJson() {
    final heat = this.heat;
    final recent = this.recent;
    return {
      'level': level,
      'total_xp': totalXp,
      'rank': rank.name,
      'active_title': activeTitle?.toJson(),
      'titles': [for (final t in titles) t.toJson()],
      'weekly': weekly?.toJson(),
      'recent': recent == null ? null : [for (final r in recent) r.toJson()],
      'heat': heat == null ? null : {for (final muscle in heat.keys.toList()..sort()) muscle: heat[muscle]!.name},
    };
  }

  factory PlayerStats.fromJson(Map<String, dynamic> json) {
    final heat = json['heat'] as Map<String, dynamic>?;
    final recent = json['recent'] as List?;
    final weekly = json['weekly'] as Map<String, dynamic>?;
    final active = json['active_title'] as Map<String, dynamic>?;
    final updatedAt = json['updated_at'] as String?;
    return PlayerStats(
      level: (json['level'] as num?)?.toInt() ?? 1,
      totalXp: (json['total_xp'] as num?)?.toInt() ?? 0,
      rank: Rank.values.asNameMap()[json['rank']] ?? Rank.rookie,
      activeTitle: active == null ? null : SharedTitle.fromJson(active),
      titles: [
        for (final t in json['titles'] as List? ?? const [])
          if (SharedTitle.fromJson(t as Map<String, dynamic>) case final title?) title,
      ],
      weekly: weekly == null ? null : WeeklyStats.fromJson(weekly),
      recent: recent == null
          ? null
          : [for (final r in recent) RecentWorkout.fromJson(r as Map<String, dynamic>)],
      heat: heat == null
          ? null
          : {
              for (final MapEntry(key: muscle, value: tier) in heat.entries)
                if (HeatTier.values.asNameMap()[tier] case final known?) muscle: known,
            },
      updatedAt: updatedAt == null ? null : DateTime.parse(updatedAt).toLocal(),
    );
  }

  String get _canonical => jsonEncode(toJson());

  @override
  bool operator ==(Object other) => other is PlayerStats && other._canonical == _canonical;

  @override
  int get hashCode => _canonical.hashCode;
}

List<WorkoutSession> _finishedWithSets(List<WorkoutSession> sessions) => [
      for (final s in sessions)
        if (s.finishedAt != null && s.sets.any((set) => set.isCompleted)) s,
    ]..sort((a, b) => b.finishedAt!.compareTo(a.finishedAt!));

int _completedSets(WorkoutSession session) => session.sets.where((s) => s.isCompleted).length;

WeeklyStats _weekly(List<WorkoutSession> sessions, List<DateTime> mealTimes, DateTime now) {
  final start = startOfWeek(now);
  final end = DateTime(start.year, start.month, start.day + 7);
  bool inWeek(DateTime t) => !t.isBefore(start) && t.isBefore(end);
  var workouts = 0;
  var sets = 0;
  for (final s in _finishedWithSets(sessions)) {
    if (!inWeek(s.finishedAt!.toLocal())) continue;
    workouts++;
    sets += _completedSets(s);
  }
  final days = <DateTime>{
    for (final time in mealTimes)
      if (time.toLocal() case final local when inWeek(local)) DateTime(local.year, local.month, local.day),
  };
  return WeeklyStats(workouts: workouts, sets: sets, mealDays: days.length);
}

List<RecentWorkout> _recent(List<WorkoutSession> sessions) {
  final records = [
    for (final e in xpEvents(sessions, const []))
      if (e.source == XpSource.record) e,
  ];
  return [
    for (final s in _finishedWithSets(sessions).take(5))
      RecentWorkout(
        name: s.workoutName,
        date: s.finishedAt!.toLocal(),
        sets: _completedSets(s),
        records: [
          for (final e in records)
            if (e.date == s.finishedAt!.toLocal())
              SharedRecord(name: e.label ?? '', weightKg: e.weightKg ?? 0, reps: e.reps ?? 0),
        ],
      ),
  ];
}

/// Uygulamanın yayınlayacağı satır (S1 spec §4); gizli bölümler null.
PlayerStats buildPlayerStats({
  required PlayerSummary summary,
  required List<WorkoutSession> sessions,
  required List<DateTime> mealTimes,
  required Map<String, Exercise> exercisesById,
  required DateTime now,
  required String? activeTitleId,
  required SharedPrivacy privacy,
}) {
  SharedTitle shared(TitleProgress t) =>
      SharedTitle(kind: t.kind, subjectId: t.subjectId, exerciseName: t.exerciseName, tier: t.tier!);
  final active = summary.titleById(activeTitleId);
  return PlayerStats(
    level: summary.progress.level,
    totalXp: summary.totalXp,
    rank: summary.rank,
    activeTitle: active == null ? null : shared(active),
    titles: [for (final t in summary.titles.take(10)) shared(t)],
    weekly: privacy.weekly ? _weekly(sessions, mealTimes, now) : null,
    recent: privacy.workouts ? _recent(sessions) : null,
    heat: privacy.heat
        ? heatTiers(historyMuscleLoad(sessions, exercisesById, now.subtract(const Duration(days: 7))), days: 7)
        : null,
  );
}
```

- [ ] **Step 4: Testlerin geçtiğini gör**

Run: `flutter test --no-pub -j 1 test/features/social/domain/player_stats_test.dart`
Expected: PASS (8 test).

- [ ] **Step 5: Commit**

```bash
git add lib/features/social/domain/player_stats.dart test/features/social/domain/player_stats_test.dart
git commit -m "feat(social): build the shared player stats with privacy

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 4: Depo, sağlayıcılar ve yayınlama

**Files:**
- Create: `lib/features/social/data/social_repository.dart`
- Create: `lib/features/social/application/social_providers.dart`
- Create: `test/features/social/fakes.dart`
- Create: `test/features/social/social_fixtures.dart`
- Test: `test/features/social/application/social_providers_test.dart`

**Interfaces:**
- Consumes: Task 2–3 modelleri; `playerSummaryProvider`, `activeTitleProvider` (O1); `allSessionsProvider`, `mealTimesProvider` (`progress_providers.dart`); `exercisesByIdProvider` (`muscle_heat_providers.dart`); `nowProvider` (`session_providers.dart`); `isLoggedInProvider`; `AppSupabase.client` (`lib/core/supabase_client.dart`).
- Produces:
  - `abstract class SocialRepository` (spec §5 imzaları), `class UsernameTakenException implements Exception`, `SupabaseSocialRepository`
  - `socialRepositoryProvider`, `myPublicProfileProvider` (`FutureProvider<PublicProfile?>`), `friendshipsProvider` (`FutureProvider.autoDispose<List<Friendship>>`), `socialOverviewProvider` (`FutureProvider.autoDispose<SocialOverview>`), `incomingRequestCountProvider` (`Provider<int>`), `friendProfileProvider` (`FutureProvider.autoDispose.family<FriendEntry?, String>`), `lastPublishedStatsProvider` (`NotifierProvider<LastPublishedStats, PlayerStats?>`), `statsSyncProvider` (`FutureProvider.autoDispose<void>`), `socialActionsProvider` (`Provider<SocialActions>`)
  - `class FriendEntry { PublicProfile profile; PlayerStats? stats; }`
  - `class RequestEntry { PublicProfile profile; FriendshipState state; }`
  - `class SocialOverview { List<FriendEntry> friends; List<RequestEntry> incoming; List<RequestEntry> outgoing; }`
  - `class SocialActions { createProfile, updateProfile, send, respond, remove }`
  - Test: `FakeSocialRepository`, `socialMe`, `socialAyse`, `socialBurak`, `socialCan`, `socialDeniz`, `socialStats(...)`, `socialFriendship(...)`

- [ ] **Step 1: Sahte depoyu ve test verisini yaz**

`test/features/social/fakes.dart`:

```dart
import 'package:spor_takip/features/social/data/social_repository.dart';
import 'package:spor_takip/features/social/domain/friendship.dart';
import 'package:spor_takip/features/social/domain/player_stats.dart';
import 'package:spor_takip/features/social/domain/public_profile.dart';

class FakeSocialRepository implements SocialRepository {
  FakeSocialRepository({
    this.me,
    List<PublicProfile> others = const [],
    List<Friendship> friendships = const [],
    Map<String, PlayerStats> stats = const {},
    Set<String> taken = const {},
  })  : others = {for (final p in others) p.userId: p},
        friendships = [...friendships],
        stats = {...stats},
        taken = {...taken};

  PublicProfile? me;
  final Map<String, PublicProfile> others;
  final List<Friendship> friendships;
  final Map<String, PlayerStats> stats;
  final Set<String> taken;
  final List<PlayerStats> upserts = [];
  final List<String> sent = [];
  final List<(String, bool)> responses = [];
  final List<String> removed = [];
  String sendResult = 'pending';
  Object? error;

  void _maybeThrow() {
    if (error case final e?) throw e;
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
  }) async {
    if (username != null && taken.contains(username)) throw UsernameTakenException();
    return me = me!.copyWith(
      username: username,
      displayName: displayName,
      shareWeekly: shareWeekly,
      shareWorkouts: shareWorkouts,
      shareHeat: shareHeat,
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
          if (others[id] case final p?) p,
      ];

  @override
  Future<Map<String, PlayerStats>> fetchStats(List<String> userIds) async => {
        for (final id in userIds)
          if (stats[id] case final s?) id: s,
      };

  @override
  Future<void> upsertMyStats(PlayerStats stats) async => upserts.add(stats);
}
```

`test/features/social/social_fixtures.dart`:

```dart
import 'package:spor_takip/features/gamification/domain/levels.dart';
import 'package:spor_takip/features/gamification/domain/titles.dart';
import 'package:spor_takip/features/social/domain/friendship.dart';
import 'package:spor_takip/features/social/domain/player_stats.dart';
import 'package:spor_takip/features/social/domain/public_profile.dart';
import 'package:spor_takip/features/workout/domain/muscle_heat.dart';

const socialMe = PublicProfile(userId: 'me', username: 'samet_fit', displayName: 'Samet', inviteCode: 'K7Q2M9XA');
const socialAyse = PublicProfile(userId: 'ayse', username: 'ayse_k', displayName: 'Ayşe Kaya', inviteCode: 'AYSE2345');
const socialBurak = PublicProfile(userId: 'burak', username: 'burak', displayName: 'Burak', inviteCode: 'BURAK234');
const socialCan = PublicProfile(userId: 'can', username: 'can', displayName: 'Can', inviteCode: 'CANCAN23');
const socialDeniz = PublicProfile(userId: 'deniz', username: 'deniz', displayName: 'Deniz', inviteCode: 'DENIZ234');

Friendship socialFriendship(String requester, String addressee, {bool accepted = true}) =>
    Friendship(requester: requester, addressee: addressee, accepted: accepted, createdAt: DateTime(2026, 10, 1));

PlayerStats socialStats({
  int level = 31,
  Rank rank = Rank.determined,
  bool withSections = true,
  DateTime? updatedAt,
}) =>
    PlayerStats(
      level: level,
      totalXp: 18420,
      rank: rank,
      activeTitle: const SharedTitle(kind: TitleKind.muscle, subjectId: 'lats', tier: TitleTier.champion),
      titles: const [
        SharedTitle(kind: TitleKind.muscle, subjectId: 'lats', tier: TitleTier.champion),
        SharedTitle(kind: TitleKind.exercise, subjectId: 'row', exerciseName: 'Barbell Row', tier: TitleTier.master),
      ],
      weekly: withSections ? const WeeklyStats(workouts: 4, sets: 62, mealDays: 6) : null,
      recent: withSections
          ? [
              RecentWorkout(
                name: 'Pull A',
                date: DateTime(2026, 10, 9, 8),
                sets: 18,
                records: const [SharedRecord(name: 'Barbell Row', weightKg: 90, reps: 5)],
              ),
              RecentWorkout(name: 'Legs', date: DateTime(2026, 10, 8, 18), sets: 21, records: const []),
            ]
          : null,
      heat: withSections ? const {'lats': HeatTier.high, 'quadriceps': HeatTier.medium} : null,
      updatedAt: updatedAt ?? DateTime(2026, 10, 9, 9),
    );
```

- [ ] **Step 2: Başarısız sağlayıcı testlerini yaz**

`test/features/social/application/social_providers_test.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spor_takip/features/gamification/application/gamification_providers.dart';
import 'package:spor_takip/features/gamification/domain/player_summary.dart';
import 'package:spor_takip/features/onboarding/application/auth_providers.dart';
import 'package:spor_takip/features/progress/application/progress_providers.dart';
import 'package:spor_takip/features/social/application/social_providers.dart';
import 'package:spor_takip/features/workout/application/muscle_heat_providers.dart';
import 'package:spor_takip/features/workout/application/session_providers.dart';

import '../../gamification/game_fixtures.dart';
import '../fakes.dart';
import '../social_fixtures.dart';

final _sessions = [gameSession('a', DateTime(2026, 10, 8, 18), gameSets('bench', 3))];

ProviderContainer _container(FakeSocialRepository repo) {
  final container = ProviderContainer(overrides: [
    isLoggedInProvider.overrideWithValue(true),
    socialRepositoryProvider.overrideWithValue(repo),
    nowProvider.overrideWithValue(() => DateTime(2026, 10, 9, 12)),
    allSessionsProvider.overrideWith((ref) async => _sessions),
    mealTimesProvider.overrideWith((ref) async => [DateTime(2026, 10, 9, 8)]),
    exercisesByIdProvider.overrideWith((ref) async => gameExercisesById),
    playerSummaryProvider.overrideWith(
      (ref) async => playerSummary(_sessions, [DateTime(2026, 10, 9, 8)], gameExercisesById),
    ),
  ]);
  addTearDown(container.dispose);
  return container;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('the overview splits friends, incoming and outgoing requests', () async {
    final repo = FakeSocialRepository(
      me: socialMe,
      others: [socialAyse, socialBurak, socialCan, socialDeniz],
      friendships: [
        socialFriendship('me', 'ayse'),
        socialFriendship('burak', 'me'),
        socialFriendship('can', 'me', accepted: false),
        socialFriendship('me', 'deniz', accepted: false),
      ],
      stats: {'ayse': socialStats(level: 10), 'burak': socialStats(level: 20)},
    );
    final container = _container(repo);
    container.listen(socialOverviewProvider, (_, _) {});
    container.listen(incomingRequestCountProvider, (_, _) {});

    final overview = await container.read(socialOverviewProvider.future);
    expect([for (final f in overview.friends) f.profile.userId], ['burak', 'ayse']);
    expect(overview.friends.first.stats?.level, 20);
    expect([for (final r in overview.incoming) r.profile.userId], ['can']);
    expect([for (final r in overview.outgoing) r.profile.userId], ['deniz']);
    expect(container.read(incomingRequestCountProvider), 1);
    expect((await container.read(friendProfileProvider('ayse').future))?.profile.username, 'ayse_k');
    expect(await container.read(friendProfileProvider('can').future), isNull);
  });

  test('without a social profile nothing is fetched or published', () async {
    final repo = FakeSocialRepository();
    final container = _container(repo);
    container.listen(statsSyncProvider, (_, _) {});
    await container.read(statsSyncProvider.future);
    expect(repo.upserts, isEmpty);
    expect((await container.read(socialOverviewProvider.future)).friends, isEmpty);
    expect(container.read(incomingRequestCountProvider), 0);
  });

  test('stats are published once per change, and again after a privacy change', () async {
    final repo = FakeSocialRepository(me: socialMe);
    final container = _container(repo);
    container.listen(statsSyncProvider, (_, _) {});

    await container.read(statsSyncProvider.future);
    expect(repo.upserts, hasLength(1));
    expect(repo.upserts.single.weekly?.workouts, 1);

    container.invalidate(statsSyncProvider);
    await container.read(statsSyncProvider.future);
    expect(repo.upserts, hasLength(1));

    await container.read(socialActionsProvider).updateProfile(shareWeekly: false);
    await container.read(statsSyncProvider.future);
    expect(repo.upserts, hasLength(2));
    expect(repo.upserts.last.weekly, isNull);
  });

  test('actions refresh the friendships', () async {
    final repo = FakeSocialRepository(
      me: socialMe,
      others: [socialCan],
      friendships: [socialFriendship('can', 'me', accepted: false)],
    );
    final container = _container(repo);
    container.listen(socialOverviewProvider, (_, _) {});
    expect((await container.read(socialOverviewProvider.future)).incoming, hasLength(1));

    await container.read(socialActionsProvider).respond('can', accept: true);
    final after = await container.read(socialOverviewProvider.future);
    expect(after.incoming, isEmpty);
    expect([for (final f in after.friends) f.profile.userId], ['can']);
    expect(repo.responses, [('can', true)]);
  });
}
```

- [ ] **Step 3: Testin başarısız olduğunu gör**

Run: `flutter test --no-pub -j 1 test/features/social/application/social_providers_test.dart`
Expected: FAIL — `social_repository.dart` / `social_providers.dart` yok.

- [ ] **Step 4: Depoyu yaz**

`lib/features/social/data/social_repository.dart`:

```dart
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/friendship.dart';
import '../domain/player_stats.dart';
import '../domain/public_profile.dart';

/// Kullanıcı adı başkasında (benzersizlik ihlali, `23505`).
class UsernameTakenException implements Exception {}

abstract interface class SocialRepository {
  Future<PublicProfile?> fetchMyProfile();
  Future<PublicProfile> createProfile({required String username, required String displayName});
  Future<PublicProfile> updateProfile({
    String? username,
    String? displayName,
    bool? shareWeekly,
    bool? shareWorkouts,
    bool? shareHeat,
  });
  Future<bool> usernameAvailable(String username);
  Future<FoundUser?> findByUsername(String username);
  Future<FoundUser?> findByInviteCode(String code);
  Future<List<Friendship>> fetchFriendships();

  /// `'pending'`, `'accepted'` ya da `'already_friends'`.
  Future<String> sendRequest(String targetId);
  Future<void> respond(String requesterId, {required bool accept});
  Future<void> removeFriend(String otherId);
  Future<List<PublicProfile>> fetchProfiles(List<String> userIds);
  Future<Map<String, PlayerStats>> fetchStats(List<String> userIds);
  Future<void> upsertMyStats(PlayerStats stats);
}

class SupabaseSocialRepository implements SocialRepository {
  SupabaseSocialRepository(this._client);

  final SupabaseClient _client;

  static const _profileColumns =
      'user_id, username, display_name, invite_code, share_weekly, share_workouts, share_heat';

  String get _me => _client.auth.currentUser!.id;

  bool _isUnique(PostgrestException e, String column) => e.code == '23505' && e.message.contains(column);

  @override
  Future<PublicProfile?> fetchMyProfile() async {
    final row = await _client.from('public_profiles').select(_profileColumns).eq('user_id', _me).maybeSingle();
    return row == null ? null : PublicProfile.fromJson(row);
  }

  @override
  Future<PublicProfile> createProfile({required String username, required String displayName}) async {
    // Davet kodu çakışması (çok düşük olasılık) → yeniden dene.
    for (var attempt = 0;; attempt++) {
      try {
        final row = await _client
            .from('public_profiles')
            .insert({'user_id': _me, 'username': username, 'display_name': displayName.trim()})
            .select(_profileColumns)
            .single();
        return PublicProfile.fromJson(row);
      } on PostgrestException catch (e) {
        if (_isUnique(e, 'username')) throw UsernameTakenException();
        if (_isUnique(e, 'invite_code') && attempt < 2) continue;
        rethrow;
      }
    }
  }

  @override
  Future<PublicProfile> updateProfile({
    String? username,
    String? displayName,
    bool? shareWeekly,
    bool? shareWorkouts,
    bool? shareHeat,
  }) async {
    try {
      final row = await _client
          .from('public_profiles')
          .update({
            'username': ?username,
            'display_name': ?displayName?.trim(),
            'share_weekly': ?shareWeekly,
            'share_workouts': ?shareWorkouts,
            'share_heat': ?shareHeat,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('user_id', _me)
          .select(_profileColumns)
          .single();
      return PublicProfile.fromJson(row);
    } on PostgrestException catch (e) {
      if (_isUnique(e, 'username')) throw UsernameTakenException();
      rethrow;
    }
  }

  @override
  Future<bool> usernameAvailable(String username) async =>
      await _client.rpc('username_available', params: {'p_username': username}) as bool;

  Future<FoundUser?> _first(Object? rows) {
    final list = rows as List? ?? const [];
    return Future.value(list.isEmpty ? null : FoundUser.fromJson(list.first as Map<String, dynamic>));
  }

  @override
  Future<FoundUser?> findByUsername(String username) async =>
      _first(await _client.rpc('find_user', params: {'p_username': username}));

  @override
  Future<FoundUser?> findByInviteCode(String code) async =>
      _first(await _client.rpc('find_user_by_invite', params: {'p_code': code}));

  @override
  Future<List<Friendship>> fetchFriendships() async {
    final rows = await _client.from('friendships').select('requester, addressee, status, created_at');
    return [for (final row in rows) Friendship.fromJson(row)];
  }

  @override
  Future<String> sendRequest(String targetId) async =>
      await _client.rpc('send_friend_request', params: {'p_target': targetId}) as String;

  @override
  Future<void> respond(String requesterId, {required bool accept}) async {
    await _client.rpc('respond_friend_request', params: {'p_requester': requesterId, 'p_accept': accept});
  }

  @override
  Future<void> removeFriend(String otherId) async {
    await _client.rpc('remove_friend', params: {'p_other': otherId});
  }

  @override
  Future<List<PublicProfile>> fetchProfiles(List<String> userIds) async {
    if (userIds.isEmpty) return const [];
    final rows = await _client.from('public_profiles').select(_profileColumns).inFilter('user_id', userIds);
    return [for (final row in rows) PublicProfile.fromJson(row)];
  }

  @override
  Future<Map<String, PlayerStats>> fetchStats(List<String> userIds) async {
    if (userIds.isEmpty) return const {};
    final rows = await _client.from('player_stats').select().inFilter('user_id', userIds);
    return {for (final row in rows) row['user_id'] as String: PlayerStats.fromJson(row)};
  }

  @override
  Future<void> upsertMyStats(PlayerStats stats) async {
    await _client.from('player_stats').upsert({
      ...stats.toJson(),
      'user_id': _me,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });
  }
}
```

Not: `'key': ?value` (null-aware map öğesi) Dart 3.8+ özelliğidir; projede `exercise_repository.dart` (`'primary_muscles': [?primaryMuscle]`) zaten benzerini kullanıyor.

- [ ] **Step 5: Sağlayıcıları yaz**

`lib/features/social/application/social_providers.dart`:

```dart
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase_client.dart';
import '../../gamification/application/gamification_providers.dart';
import '../../onboarding/application/auth_providers.dart';
import '../../progress/application/progress_providers.dart';
import '../../workout/application/muscle_heat_providers.dart';
import '../../workout/application/session_providers.dart';
import '../data/social_repository.dart';
import '../domain/friendship.dart';
import '../domain/player_stats.dart';
import '../domain/public_profile.dart';

final socialRepositoryProvider = Provider<SocialRepository>((ref) {
  return SupabaseSocialRepository(AppSupabase.client);
});

/// Kendi sosyal kimliğim; yoksa null (Sosyal sekmesi oluşturmayı ister).
final myPublicProfileProvider = FutureProvider<PublicProfile?>((ref) async {
  if (!ref.watch(isLoggedInProvider)) return null;
  return ref.watch(socialRepositoryProvider).fetchMyProfile();
});

final friendshipsProvider = FutureProvider.autoDispose<List<Friendship>>((ref) async {
  final me = await ref.watch(myPublicProfileProvider.future);
  if (me == null) return const [];
  return ref.watch(socialRepositoryProvider).fetchFriendships();
});

class FriendEntry {
  const FriendEntry({required this.profile, this.stats});

  final PublicProfile profile;

  /// Arkadaş henüz yayın yapmadıysa null.
  final PlayerStats? stats;
}

class RequestEntry {
  const RequestEntry({required this.profile, required this.state});

  final PublicProfile profile;
  final FriendshipState state;
}

class SocialOverview {
  const SocialOverview({this.friends = const [], this.incoming = const [], this.outgoing = const []});

  /// Seviye büyükten küçüğe, sonra görünen ad.
  final List<FriendEntry> friends;
  final List<RequestEntry> incoming;
  final List<RequestEntry> outgoing;
}

final socialOverviewProvider = FutureProvider.autoDispose<SocialOverview>((ref) async {
  final me = await ref.watch(myPublicProfileProvider.future);
  if (me == null) return const SocialOverview();
  final friendships = await ref.watch(friendshipsProvider.future);
  final repo = ref.watch(socialRepositoryProvider);
  final friendIds = [
    for (final f in friendships)
      if (f.accepted) f.otherThan(me.userId),
  ];
  final (profiles, stats) = await (
    repo.fetchProfiles([for (final f in friendships) f.otherThan(me.userId)]),
    repo.fetchStats(friendIds),
  ).wait;
  final byId = {for (final p in profiles) p.userId: p};
  final friends = [
    for (final id in friendIds)
      if (byId[id] case final profile?) FriendEntry(profile: profile, stats: stats[id]),
  ]..sort((a, b) {
      final byLevel = (b.stats?.level ?? 0).compareTo(a.stats?.level ?? 0);
      return byLevel != 0 ? byLevel : a.profile.displayName.compareTo(b.profile.displayName);
    });
  List<RequestEntry> requests(FriendshipState state) => [
        for (final f in friendships)
          if (f.stateFor(me.userId) == state)
            if (byId[f.otherThan(me.userId)] case final profile?) RequestEntry(profile: profile, state: state),
      ];
  return SocialOverview(
    friends: friends,
    incoming: requests(FriendshipState.incoming),
    outgoing: requests(FriendshipState.outgoing),
  );
});

/// Sekme rozeti; veri yoksa 0.
final incomingRequestCountProvider = Provider<int>((ref) {
  final me = ref.watch(myPublicProfileProvider).value;
  final friendships = ref.watch(friendshipsProvider).value;
  if (me == null || friendships == null) return 0;
  return friendships.where((f) => f.stateFor(me.userId) == FriendshipState.incoming).length;
});

/// Arkadaş değilse null.
final friendProfileProvider = FutureProvider.autoDispose.family<FriendEntry?, String>((ref, id) async {
  final overview = await ref.watch(socialOverviewProvider.future);
  return overview.friends.where((f) => f.profile.userId == id).firstOrNull;
});

/// Son yayınlanan satır (bellekte); aynıysa yeniden yazılmaz.
class LastPublishedStats extends Notifier<PlayerStats?> {
  @override
  PlayerStats? build() => null;

  void remember(PlayerStats stats) => state = stats;
}

final lastPublishedStatsProvider = NotifierProvider<LastPublishedStats, PlayerStats?>(LastPublishedStats.new);

/// Kendi `player_stats` satırımı yayınlar (S1 spec §5). `AppShell` izler; hata loglanır.
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
  final stats = buildPlayerStats(
    summary: summary,
    sessions: sessions,
    mealTimes: mealTimes,
    exercisesById: exercisesById,
    now: ref.read(nowProvider)(),
    activeTitleId: activeTitleId,
    privacy: SharedPrivacy(weekly: profile.shareWeekly, workouts: profile.shareWorkouts, heat: profile.shareHeat),
  );
  if (ref.read(lastPublishedStatsProvider) == stats) return;
  try {
    await ref.read(socialRepositoryProvider).upsertMyStats(stats);
    ref.read(lastPublishedStatsProvider.notifier).remember(stats);
  } catch (e, st) {
    debugPrint('statsSync failed: $e\n$st');
  }
});

/// Ekranların yazma işlemleri; her biri ilgili sağlayıcıları yeniler.
class SocialActions {
  SocialActions(this._ref);

  final Ref _ref;

  SocialRepository get _repo => _ref.read(socialRepositoryProvider);

  Future<PublicProfile> createProfile({required String username, required String displayName}) async {
    final profile = await _repo.createProfile(username: username, displayName: displayName);
    _ref.invalidate(myPublicProfileProvider);
    return profile;
  }

  Future<PublicProfile> updateProfile({
    String? username,
    String? displayName,
    bool? shareWeekly,
    bool? shareWorkouts,
    bool? shareHeat,
  }) async {
    final profile = await _repo.updateProfile(
      username: username,
      displayName: displayName,
      shareWeekly: shareWeekly,
      shareWorkouts: shareWorkouts,
      shareHeat: shareHeat,
    );
    _ref.invalidate(myPublicProfileProvider);
    return profile;
  }

  Future<String> send(String targetId) async {
    final result = await _repo.sendRequest(targetId);
    _ref.invalidate(friendshipsProvider);
    return result;
  }

  Future<void> respond(String requesterId, {required bool accept}) async {
    await _repo.respond(requesterId, accept: accept);
    _ref.invalidate(friendshipsProvider);
  }

  Future<void> remove(String otherId) async {
    await _repo.removeFriend(otherId);
    _ref.invalidate(friendshipsProvider);
  }
}

final socialActionsProvider = Provider<SocialActions>(SocialActions.new);
```

- [ ] **Step 6: Testlerin geçtiğini gör**

Run: `flutter test --no-pub -j 1 test/features/social/application/social_providers_test.dart`
Expected: PASS (4 test).

- [ ] **Step 7: Commit**

```bash
git add lib/features/social/data/social_repository.dart lib/features/social/application/social_providers.dart test/features/social/fakes.dart test/features/social/social_fixtures.dart test/features/social/application/social_providers_test.dart
git commit -m "feat(social): add the social repository, providers and stats publishing

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 5: Sosyal ekranı (kimlik oluşturma ve ana görünüm) ve çeviriler

**Files:**
- Create: `lib/features/social/presentation/widgets/social_avatar.dart`
- Create: `lib/features/social/presentation/widgets/username_field.dart`
- Create: `lib/features/social/presentation/social_screen.dart`
- Create: `lib/features/social/presentation/add_friend_sheet.dart` (Task 6'da doldurulur; bu görevde yalnız `showAddFriendSheet` iskeleti)
- Modify: `assets/translations/tr.json`, `assets/translations/en.json` (`nav.social` + `social` bloğu)
- Test: `test/features/social/presentation/social_screen_test.dart`

**Interfaces:**
- Consumes: Task 2–4; `RankBadge` (`lib/features/gamification/presentation/widgets/rank_badge.dart`), `titleName` (`lib/features/gamification/presentation/title_names.dart`), `playerSummaryProvider`; `SectionHeader`; `upperCaseFor`; `AppFonts`.
- Produces:
  - `SocialAvatar({required String initials, bool highlighted = true, double size = 48})`
  - `TitlePill({required String text})`
  - `enum UsernameStatus { empty, invalid, checking, available, taken }`
  - `UsernameField({required TextEditingController controller, required ValueChanged<UsernameStatus> onStatusChanged, Key fieldKey = const Key('social_username_field'), String? currentUsername, bool forceTaken = false})`
  - `SocialScreen()` (`social_screen`)
  - `Future<void> showAddFriendSheet(BuildContext context)`

- [ ] **Step 1: Çevirileri ekle**

```bash
python - <<'EOF'
import json
blocks = {
 'tr': {
  "title": "Sosyal", "create_title": "Sosyal kimliğini oluştur",
  "create_body": "Arkadaşların seni bu kullanıcı adıyla bulur. Seviyen, rütben ve unvanların arkadaşlarına görünür; kilo, ölçü ve beslenme asla paylaşılmaz.",
  "username_label": "Kullanıcı adı", "display_name_label": "Görünen ad",
  "username_available": "Uygun", "username_taken": "Bu ad alınmış", "username_checking": "Bakılıyor…",
  "username_too_short": "En az 3 karakter", "username_too_long": "En çok 20 karakter",
  "username_invalid": "Yalnız a–z, 0–9 ve _", "create": "OLUŞTUR",
  "level_rank": "SV {n} · {rank}", "invite_label": "Davet kodum", "copy": "KOPYALA",
  "copied": "Davet metni kopyalandı", "invite_text": "LevelUp Fit'te arkadaşım ol — kod: {code}",
  "add_friend": "ARKADAŞ EKLE", "requests_title": "İstekler", "accept": "KABUL", "decline": "REDDET",
  "cancel_request": "GERİ ÇEK", "sent": "Gönderildi", "friends_title": "Arkadaşlar",
  "friends_empty": "Henüz arkadaşın yok — davet kodunu paylaş ya da kullanıcı adıyla ekle",
  "add_title": "Arkadaş ekle", "add_by_username": "Kullanıcı adı", "add_by_invite": "Davet kodu",
  "search": "ARA", "not_found": "Kimse bulunamadı", "send_request": "İSTEK GÖNDER",
  "outcome_pending": "İstek gönderildi", "outcome_accepted": "Artık arkadaşsınız", "outcome_already": "Zaten arkadaşsınız",
  "action_error": "İşlem yapılamadı — tekrar dene", "retry": "Yüklenemedi — tekrar dene",
  "friend_titles": "Unvanlar", "friend_titles_empty": "Henüz unvan yok", "friend_weekly": "Bu hafta",
  "weekly_workouts": "antrenman", "weekly_sets": "set", "weekly_meal_days": "öğün günü",
  "friend_heat": "Kas ısısı · son 7 gün", "friend_recent": "Son antrenmanlar", "friend_recent_empty": "Henüz antrenman yok",
  "hidden": "Paylaşılmıyor", "no_stats": "Henüz istatistik yok", "updated": "Güncellendi: {ago}",
  "ago_now": "az önce", "ago_minutes": "{n} dk önce", "ago_hours": "{n} saat önce", "ago_days": "{n} gün önce",
  "recent_line": "{sets} set · {date}", "record_line": "Rekor: {name} {kg} kg × {reps}",
  "level_line": "SEVİYE {n} · {rank}", "total_xp": "Toplam {n} XP",
  "remove": "Arkadaşlıktan çıkar", "remove_title": "Arkadaşlıktan çıkarılsın mı?",
  "remove_body": "{name} arkadaş listenden çıkar; yeniden eklemek için istek göndermen gerekir.",
  "remove_confirm": "ÇIKAR", "cancel": "Vazgeç", "not_friend": "Bu kişi arkadaş listende değil",
  "settings_title": "Sosyal ayarlar", "save": "KAYDET", "saved": "Kaydedildi",
  "privacy_title": "Arkadaşlarım görebilir", "share_weekly": "Haftalık özet", "share_workouts": "Son antrenmanlar",
  "share_heat": "Kas ısısı",
  "privacy_note": "Seviye, rütbe ve unvanlar her zaman görünür. Kilo, ölçü ve beslenme asla paylaşılmaz."
 },
 'en': {
  "title": "Social", "create_title": "Create your social profile",
  "create_body": "Friends find you by this username. Your level, rank and titles are visible to friends; weight, measurements and nutrition are never shared.",
  "username_label": "Username", "display_name_label": "Display name",
  "username_available": "Available", "username_taken": "Already taken", "username_checking": "Checking…",
  "username_too_short": "At least 3 characters", "username_too_long": "At most 20 characters",
  "username_invalid": "Only a–z, 0–9 and _", "create": "CREATE",
  "level_rank": "LV {n} · {rank}", "invite_label": "My invite code", "copy": "COPY",
  "copied": "Invite text copied", "invite_text": "Join me on LevelUp Fit — code: {code}",
  "add_friend": "ADD FRIEND", "requests_title": "Requests", "accept": "ACCEPT", "decline": "DECLINE",
  "cancel_request": "CANCEL", "sent": "Sent", "friends_title": "Friends",
  "friends_empty": "No friends yet — share your invite code or add someone by username",
  "add_title": "Add a friend", "add_by_username": "Username", "add_by_invite": "Invite code",
  "search": "SEARCH", "not_found": "No one found", "send_request": "SEND REQUEST",
  "outcome_pending": "Request sent", "outcome_accepted": "You are now friends", "outcome_already": "Already friends",
  "action_error": "Couldn't do that — try again", "retry": "Couldn't load — try again",
  "friend_titles": "Titles", "friend_titles_empty": "No titles yet", "friend_weekly": "This week",
  "weekly_workouts": "workouts", "weekly_sets": "sets", "weekly_meal_days": "meal days",
  "friend_heat": "Muscle heat · last 7 days", "friend_recent": "Recent workouts", "friend_recent_empty": "No workouts yet",
  "hidden": "Not shared", "no_stats": "No stats yet", "updated": "Updated: {ago}",
  "ago_now": "just now", "ago_minutes": "{n} min ago", "ago_hours": "{n} h ago", "ago_days": "{n} days ago",
  "recent_line": "{sets} sets · {date}", "record_line": "Record: {name} {kg} kg × {reps}",
  "level_line": "LEVEL {n} · {rank}", "total_xp": "Total {n} XP",
  "remove": "Remove friend", "remove_title": "Remove this friend?",
  "remove_body": "{name} leaves your friend list; you'll need to send a new request to add them again.",
  "remove_confirm": "REMOVE", "cancel": "Cancel", "not_friend": "This person isn't on your friend list",
  "settings_title": "Social settings", "save": "SAVE", "saved": "Saved",
  "privacy_title": "My friends can see", "share_weekly": "Weekly summary", "share_workouts": "Recent workouts",
  "share_heat": "Muscle heat",
  "privacy_note": "Level, rank and titles are always visible. Weight, measurements and nutrition are never shared."
 },
}
nav = {'tr': 'Sosyal', 'en': 'Social'}
for lang, block in blocks.items():
    path = f'assets/translations/{lang}.json'
    text = open(path, encoding='utf-8').read()
    crlf = '\r\n' in text
    text = text.replace('\r\n', '\n')
    assert '"social"' not in text
    old = '"coach": "Antrenör"\n  },' if lang == 'tr' else None
    import re
    m = re.search(r'("nav": \{[^}]*?)(\n  \})', text)
    assert m, lang
    text = text[:m.end(1)] + f',\n    "social": "{nav[lang]}"' + text[m.end(1):]
    body = json.dumps(block, ensure_ascii=False, indent=2)
    body = '\n'.join('  ' + line if i else line for i, line in enumerate(body.split('\n')))
    end = text.rstrip().rfind('}')
    text = text[:end].rstrip() + ',\n  "social": ' + body + '\n}\n'
    json.loads(text)
    if crlf:
        text = text.replace('\n', '\r\n')
    open(path, 'w', encoding='utf-8', newline='').write(text)
    print(lang, 'ok')
EOF
```

- [ ] **Step 2: Başarısız ekran testlerini yaz**

`test/features/social/presentation/social_screen_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spor_takip/features/gamification/application/gamification_providers.dart';
import 'package:spor_takip/features/gamification/domain/player_summary.dart';
import 'package:spor_takip/features/social/application/social_providers.dart';
import 'package:spor_takip/features/social/presentation/social_screen.dart';

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
      const SocialScreen(),
      scaffold: false,
      overrides: [
        socialRepositoryProvider.overrideWithValue(repo),
        playerSummaryProvider.overrideWith((ref) async => playerSummary(const [], const [], const {})),
      ],
      stubRoutes: {'/social/friend/ayse': 'friend-ayse', '/social/settings': 'settings-stub'},
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('without a profile it asks for a username and display name', (tester) async {
    final repo = FakeSocialRepository(taken: {'taken_name'});
    await pump(tester, repo);
    expect(find.byKey(const Key('social_create')), findsOneWidget);
    expect(find.byKey(const Key('social_settings_button')), findsNothing);
    final create = find.byKey(const Key('social_create_button'));
    expect(tester.widget<FilledButton>(create).onPressed, isNull);

    await tester.enterText(find.byKey(const Key('social_username_field')), 'ab');
    await tester.pump();
    expect(find.text('social.username_too_short'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('social_username_field')), 'taken_name');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    expect(find.text('social.username_taken'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('social_username_field')), '@Samet_Fit');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    expect(find.text('social.username_available'), findsOneWidget);
    expect(tester.widget<FilledButton>(create).onPressed, isNull); // görünen ad boş

    await tester.enterText(find.byKey(const Key('social_display_name_field')), 'Samet');
    await tester.pump();
    await tester.tap(create);
    await tester.pumpAndSettle();
    expect(repo.me?.username, 'samet_fit');
    expect(find.byKey(const Key('social_me_card')), findsOneWidget);
  });

  testWidgets('shows my card, requests and friends; copies the invite text', (tester) async {
    final repo = FakeSocialRepository(
      me: socialMe,
      others: [socialAyse, socialCan, socialDeniz],
      friendships: [
        socialFriendship('me', 'ayse'),
        socialFriendship('can', 'me', accepted: false),
        socialFriendship('me', 'deniz', accepted: false),
      ],
      stats: {'ayse': socialStats()},
    );
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') copied = (call.arguments as Map)['text'] as String;
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
    await pump(tester, repo);

    expect(find.byKey(const Key('social_me_card')), findsOneWidget);
    expect(find.text('K7Q2M9XA'), findsOneWidget);
    expect(find.byKey(const Key('request_can')), findsOneWidget);
    expect(find.byKey(const Key('request_accept_can')), findsOneWidget);
    expect(find.byKey(const Key('request_cancel_deniz')), findsOneWidget);
    expect(find.byKey(const Key('friend_ayse')), findsOneWidget);

    await tester.tap(find.byKey(const Key('social_copy_invite')));
    await tester.pumpAndSettle();
    expect(copied, 'social.invite_text');
    expect(find.text('social.copied'), findsOneWidget);
  });

  testWidgets('accepting, declining and cancelling requests call the repository', (tester) async {
    final repo = FakeSocialRepository(
      me: socialMe,
      others: [socialCan, socialBurak, socialDeniz],
      friendships: [
        socialFriendship('can', 'me', accepted: false),
        socialFriendship('burak', 'me', accepted: false),
        socialFriendship('me', 'deniz', accepted: false),
      ],
    );
    await pump(tester, repo);

    await tester.tap(find.byKey(const Key('request_accept_can')));
    await tester.pumpAndSettle();
    expect(repo.responses, [('can', true)]);
    expect(find.byKey(const Key('friend_can')), findsOneWidget);

    await tester.tap(find.byKey(const Key('request_decline_burak')));
    await tester.pumpAndSettle();
    expect(repo.responses.last, ('burak', false));
    expect(find.byKey(const Key('request_burak')), findsNothing);

    await tester.tap(find.byKey(const Key('request_cancel_deniz')));
    await tester.pumpAndSettle();
    expect(repo.removed, ['deniz']);
  });

  testWidgets('a friend row opens the friend profile; the gear opens settings', (tester) async {
    final repo = FakeSocialRepository(
      me: socialMe,
      others: [socialAyse],
      friendships: [socialFriendship('me', 'ayse')],
    );
    await pump(tester, repo);
    expect(find.byKey(const Key('social_friends_empty')), findsNothing);
    await tester.tap(find.byKey(const Key('friend_ayse')));
    await tester.pumpAndSettle();
    expect(find.text('friend-ayse'), findsOneWidget);
  });

  testWidgets('no friends shows the empty text', (tester) async {
    await pump(tester, FakeSocialRepository(me: socialMe));
    expect(find.byKey(const Key('social_friends_empty')), findsOneWidget);
    expect(find.byKey(const Key('social_requests')), findsNothing);
    await tester.tap(find.byKey(const Key('social_settings_button')));
    await tester.pumpAndSettle();
    expect(find.text('settings-stub'), findsOneWidget);
  });
}
```

- [ ] **Step 3: Testin başarısız olduğunu gör**

Run: `flutter test --no-pub -j 1 test/features/social/presentation/social_screen_test.dart`
Expected: FAIL — `social_screen.dart` yok.

- [ ] **Step 4: Avatar ve unvan hapını yaz**

`lib/features/social/presentation/widgets/social_avatar.dart`:

```dart
import 'package:flutter/material.dart';

import '../../../../core/theme/app_fonts.dart';

/// Baş harfli köşeli avatar; arkadaşlarda lime, diğerlerinde gri çerçeve.
class SocialAvatar extends StatelessWidget {
  const SocialAvatar({super.key, required this.initials, this.highlighted = true, this.size = 48});

  final String initials;
  final bool highlighted;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(size * 0.25),
        border: Border.all(color: highlighted ? scheme.primary : scheme.outlineVariant, width: 2),
      ),
      child: Text(
        initials,
        style: TextStyle(
          fontFamily: AppFonts.heading,
          fontWeight: FontWeight.w900,
          fontSize: size * 0.34,
          color: highlighted ? scheme.onSurface : scheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// Lime çerçeveli küçük unvan hapı.
class TitlePill extends StatelessWidget {
  const TitlePill({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: 0.12),
        borderRadius: const BorderRadius.all(Radius.circular(6)),
        border: Border.all(color: scheme.primary.withValues(alpha: 0.7)),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.labelSmall?.copyWith(color: scheme.primary, fontWeight: FontWeight.w800),
      ),
    );
  }
}
```

- [ ] **Step 5: Kullanıcı adı alanını yaz**

`lib/features/social/presentation/widgets/username_field.dart`:

```dart
import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/social_providers.dart';
import '../../domain/username.dart';

enum UsernameStatus { empty, invalid, checking, available, taken }

/// '@' önekli kullanıcı adı alanı; biçimi anında, uygunluğu 400 ms sonra denetler.
/// [currentUsername] (ayarlarda kendi adım) denetimsiz uygun sayılır.
class UsernameField extends ConsumerStatefulWidget {
  const UsernameField({
    super.key,
    required this.controller,
    required this.onStatusChanged,
    this.fieldKey = const Key('social_username_field'),
    this.currentUsername,
    this.forceTaken = false,
  });

  final TextEditingController controller;
  final ValueChanged<UsernameStatus> onStatusChanged;
  final Key fieldKey;
  final String? currentUsername;

  /// Kaydederken benzersizlik hatası geldiyse; metin değişince üst widget sıfırlar.
  final bool forceTaken;

  @override
  ConsumerState<UsernameField> createState() => _UsernameFieldState();
}

class _UsernameFieldState extends ConsumerState<UsernameField> {
  Timer? _debounce;
  UsernameStatus _status = UsernameStatus.empty;
  UsernameProblem? _problem;

  @override
  void initState() {
    super.initState();
    if (widget.controller.text.isNotEmpty) _check(widget.controller.text, notify: false);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  /// [notify] false yalnız initState'te: orada setState çağrılamaz.
  void _set(UsernameStatus status, {bool notify = true}) {
    if (!notify) {
      _status = status;
      return;
    }
    if (mounted) setState(() => _status = status);
    widget.onStatusChanged(status);
  }

  void _check(String raw, {bool notify = true}) {
    _debounce?.cancel();
    final name = normalizeUsername(raw);
    _problem = name.isEmpty ? null : checkUsername(name);
    if (name.isEmpty) return _set(UsernameStatus.empty, notify: notify);
    if (_problem != null) return _set(UsernameStatus.invalid, notify: notify);
    if (name == widget.currentUsername) return _set(UsernameStatus.available, notify: notify);
    _set(UsernameStatus.checking, notify: notify);
    _debounce = Timer(const Duration(milliseconds: 400), () async {
      try {
        final ok = await ref.read(socialRepositoryProvider).usernameAvailable(name);
        if (mounted && normalizeUsername(widget.controller.text) == name) {
          _set(ok ? UsernameStatus.available : UsernameStatus.taken);
        }
      } catch (_) {
        if (mounted) _set(UsernameStatus.empty);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final status = widget.forceTaken ? UsernameStatus.taken : _status;
    final (text, color) = switch (status) {
      UsernameStatus.empty => ('', scheme.onSurfaceVariant),
      UsernameStatus.checking => ('social.username_checking'.tr(), scheme.onSurfaceVariant),
      UsernameStatus.available => ('social.username_available'.tr(), scheme.primary),
      UsernameStatus.taken => ('social.username_taken'.tr(), scheme.error),
      UsernameStatus.invalid => (
          switch (_problem) {
            UsernameProblem.tooShort => 'social.username_too_short',
            UsernameProblem.tooLong => 'social.username_too_long',
            _ => 'social.username_invalid',
          }
              .tr(),
          scheme.error,
        ),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          key: widget.fieldKey,
          controller: widget.controller,
          autocorrect: false,
          enableSuggestions: false,
          decoration: InputDecoration(labelText: 'social.username_label'.tr(), prefixText: '@'),
          onChanged: _check,
        ),
        const SizedBox(height: 4),
        Text(text, key: const Key('social_username_status'), style: TextStyle(color: color)),
      ],
    );
  }
}
```

- [ ] **Step 6: Ekleme sayfası iskeletini yaz**

`lib/features/social/presentation/add_friend_sheet.dart` (Task 6 tamamlar):

```dart
import 'package:flutter/material.dart';

/// Arkadaş ekleme alt sayfası (Task 6).
Future<void> showAddFriendSheet(BuildContext context) async {}
```

- [ ] **Step 7: Sosyal ekranını yaz**

`lib/features/social/presentation/social_screen.dart`:

```dart
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_fonts.dart';
import '../../../shared/text_case.dart';
import '../../../shared/widgets/section_header.dart';
import '../../gamification/application/gamification_providers.dart';
import '../../gamification/presentation/title_names.dart';
import '../../gamification/presentation/widgets/rank_badge.dart';
import '../application/social_providers.dart';
import '../data/social_repository.dart';
import '../domain/public_profile.dart';
import '../domain/username.dart';
import 'add_friend_sheet.dart';
import 'widgets/social_avatar.dart';
import 'widgets/username_field.dart';

/// Sosyal sekmesi (S1 spec §6.2): kimlik yoksa oluşturma, varsa kart + istekler + arkadaşlar.
class SocialScreen extends ConsumerWidget {
  const SocialScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(myPublicProfileProvider);
    return Scaffold(
      key: const Key('social_screen'),
      appBar: AppBar(
        title: Text(
          upperCaseFor('social.title'.tr(), context.locale.languageCode),
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
        ),
        actions: [
          if (profileAsync.value != null)
            IconButton(
              key: const Key('social_settings_button'),
              icon: const Icon(Icons.settings_outlined),
              tooltip: 'social.settings_title'.tr(),
              onPressed: () => context.push('/social/settings'),
            ),
        ],
      ),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(
          child: TextButton(
            key: const Key('social_retry'),
            onPressed: () => ref.invalidate(myPublicProfileProvider),
            child: Text('social.retry'.tr()),
          ),
        ),
        data: (me) => me == null ? const _CreateProfile() : _Overview(me: me),
      ),
    );
  }
}

/// İşlem hatasını SnackBar'la bildirir.
Future<void> runSocialAction(BuildContext context, Future<void> Function() action) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    await action();
  } catch (e, st) {
    debugPrint('social action failed: $e\n$st');
    messenger.showSnackBar(SnackBar(content: Text('social.action_error'.tr())));
  }
}

class _CreateProfile extends ConsumerStatefulWidget {
  const _CreateProfile();

  @override
  ConsumerState<_CreateProfile> createState() => _CreateProfileState();
}

class _CreateProfileState extends ConsumerState<_CreateProfile> {
  final _username = TextEditingController();
  final _displayName = TextEditingController();
  UsernameStatus _status = UsernameStatus.empty;
  bool _forceTaken = false;
  bool _saving = false;

  @override
  void dispose() {
    _username.dispose();
    _displayName.dispose();
    super.dispose();
  }

  bool get _canCreate =>
      !_saving && !_forceTaken && _status == UsernameStatus.available && _displayName.text.trim().isNotEmpty;

  Future<void> _create() async {
    setState(() => _saving = true);
    try {
      await ref.read(socialActionsProvider).createProfile(
            username: normalizeUsername(_username.text),
            displayName: _displayName.text.trim(),
          );
    } on UsernameTakenException {
      if (mounted) setState(() => _forceTaken = true);
    } catch (e, st) {
      debugPrint('createProfile failed: $e\n$st');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('social.action_error'.tr())));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      key: const Key('social_create'),
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          upperCaseFor('social.create_title'.tr(), context.locale.languageCode),
          style: theme.textTheme.headlineSmall?.copyWith(fontFamily: AppFonts.heading, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 8),
        Text('social.create_body'.tr(), style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
        const SizedBox(height: 20),
        UsernameField(
          controller: _username,
          forceTaken: _forceTaken,
          onStatusChanged: (status) => setState(() {
            _status = status;
            _forceTaken = false;
          }),
        ),
        const SizedBox(height: 12),
        TextField(
          key: const Key('social_display_name_field'),
          controller: _displayName,
          maxLength: 30,
          decoration: InputDecoration(labelText: 'social.display_name_label'.tr()),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 12),
        FilledButton(
          key: const Key('social_create_button'),
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
          onPressed: _canCreate ? _create : null,
          child: Text('social.create'.tr()),
        ),
      ],
    );
  }
}

class _Overview extends ConsumerWidget {
  const _Overview({required this.me});

  final PublicProfile me;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overviewAsync = ref.watch(socialOverviewProvider);
    final scheme = Theme.of(context).colorScheme;
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(friendshipsProvider);
        await ref.read(socialOverviewProvider.future);
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          _MeCard(me: me),
          const SizedBox(height: 12),
          FilledButton.icon(
            key: const Key('social_add_friend'),
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
            icon: const Icon(Icons.person_add_alt_1),
            label: Text('social.add_friend'.tr()),
            onPressed: () => showAddFriendSheet(context),
          ),
          ...overviewAsync.when(
            loading: () => const [
              Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator())),
            ],
            error: (error, stackTrace) => [
              Center(
                child: TextButton(
                  key: const Key('social_overview_retry'),
                  onPressed: () => ref.invalidate(friendshipsProvider),
                  child: Text('social.retry'.tr()),
                ),
              ),
            ],
            data: (overview) => [
              if (overview.incoming.isNotEmpty || overview.outgoing.isNotEmpty) ...[
                SectionHeader(
                  'social.requests_title'.tr(),
                  trailing: '${overview.incoming.length + overview.outgoing.length}',
                ),
                Column(
                  key: const Key('social_requests'),
                  children: [
                    for (final r in overview.incoming) _IncomingRequest(entry: r),
                    for (final r in overview.outgoing) _OutgoingRequest(entry: r),
                  ],
                ),
              ],
              SectionHeader('social.friends_title'.tr(), trailing: '${overview.friends.length}'),
              if (overview.friends.isEmpty)
                Text(
                  'social.friends_empty'.tr(),
                  key: const Key('social_friends_empty'),
                  style: TextStyle(color: scheme.onSurfaceVariant),
                )
              else
                Column(
                  key: const Key('social_friends'),
                  children: [for (final f in overview.friends) _FriendRow(entry: f)],
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MeCard extends ConsumerWidget {
  const _MeCard({required this.me});

  final PublicProfile me;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final summary = ref.watch(playerSummaryProvider).value;
    final lang = context.locale.languageCode;
    return Card(
      key: const Key('social_me_card'),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                SocialAvatar(initials: me.initials, size: 56),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(me.displayName, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                      Text('@${me.username}', style: TextStyle(color: scheme.onSurfaceVariant)),
                      if (summary != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Row(
                            children: [
                              RankBadge(rank: summary.rank, level: summary.progress.level, size: 14),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  'social.level_rank'.tr(namedArgs: {
                                    'n': '${summary.progress.level}',
                                    'rank': upperCaseFor(summary.rank.labelKey.tr(), lang),
                                  }),
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.labelLarge
                                      ?.copyWith(color: scheme.primary, fontWeight: FontWeight.w800),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.all(Radius.circular(12)),
                border: Border.all(color: scheme.outlineVariant),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          upperCaseFor('social.invite_label'.tr(), lang),
                          style: theme.textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant, letterSpacing: 1),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          me.inviteCode,
                          key: const Key('social_invite_code'),
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontFamily: AppFonts.heading,
                            fontWeight: FontWeight.w900,
                            color: scheme.primary,
                            letterSpacing: 3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  OutlinedButton.icon(
                    key: const Key('social_copy_invite'),
                    icon: const Icon(Icons.copy, size: 18),
                    label: Text('social.copy'.tr()),
                    onPressed: () async {
                      final messenger = ScaffoldMessenger.of(context);
                      await Clipboard.setData(
                        ClipboardData(text: 'social.invite_text'.tr(namedArgs: {'code': me.inviteCode})),
                      );
                      messenger.showSnackBar(SnackBar(content: Text('social.copied'.tr())));
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IncomingRequest extends ConsumerWidget {
  const _IncomingRequest({required this.entry});

  final RequestEntry entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = entry.profile.userId;
    final actions = ref.read(socialActionsProvider);
    return Card(
      key: Key('request_$id'),
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Row(
              children: [
                SocialAvatar(initials: entry.profile.initials),
                const SizedBox(width: 12),
                Expanded(child: _NameColumn(profile: entry.profile)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    key: Key('request_decline_$id'),
                    onPressed: () => runSocialAction(context, () => actions.respond(id, accept: false)),
                    child: Text('social.decline'.tr()),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    key: Key('request_accept_$id'),
                    onPressed: () => runSocialAction(context, () => actions.respond(id, accept: true)),
                    child: Text('social.accept'.tr()),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _OutgoingRequest extends ConsumerWidget {
  const _OutgoingRequest({required this.entry});

  final RequestEntry entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = entry.profile.userId;
    final theme = Theme.of(context);
    return Card(
      key: Key('request_$id'),
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            SocialAvatar(initials: entry.profile.initials, highlighted: false),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('social.sent'.tr(), style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
                  Text('@${entry.profile.username}', style: theme.textTheme.titleMedium),
                ],
              ),
            ),
            OutlinedButton(
              key: Key('request_cancel_$id'),
              onPressed: () => runSocialAction(context, () => ref.read(socialActionsProvider).remove(id)),
              child: Text('social.cancel_request'.tr()),
            ),
          ],
        ),
      ),
    );
  }
}

class _NameColumn extends StatelessWidget {
  const _NameColumn({required this.profile});

  final PublicProfile profile;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          profile.displayName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        Text('@${profile.username}', style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
      ],
    );
  }
}

class _FriendRow extends StatelessWidget {
  const _FriendRow({required this.entry});

  final FriendEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final stats = entry.stats;
    final active = stats?.activeTitle;
    return Card(
      key: Key('friend_${entry.profile.userId}'),
      margin: const EdgeInsets.only(bottom: 8),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/social/friend/${entry.profile.userId}'),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              SocialAvatar(initials: entry.profile.initials),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            entry.profile.displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                          ),
                        ),
                        if (stats != null) ...[
                          const SizedBox(width: 8),
                          RankBadge(rank: stats.rank, level: stats.level, size: 14),
                          const SizedBox(width: 4),
                          Text(
                            'gamification.level_short'.tr(namedArgs: {'n': '${stats.level}'}),
                            style: theme.textTheme.labelMedium?.copyWith(color: scheme.onSurfaceVariant),
                          ),
                        ],
                      ],
                    ),
                    Text('@${entry.profile.username}', style: TextStyle(color: scheme.onSurfaceVariant)),
                    if (active != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: TitlePill(text: titleName(active.asProgress, active.tier)),
                      ),
                  ],
                ),
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

- [ ] **Step 8: Testlerin geçtiğini gör**

Run: `flutter test --no-pub -j 1 test/features/social/presentation/social_screen_test.dart`
Expected: PASS (5 test).

- [ ] **Step 9: Commit**

```bash
git add lib/features/social/presentation/widgets/social_avatar.dart lib/features/social/presentation/widgets/username_field.dart lib/features/social/presentation/social_screen.dart lib/features/social/presentation/add_friend_sheet.dart assets/translations/tr.json assets/translations/en.json test/features/social/presentation/social_screen_test.dart
git commit -m "feat(social): add the social tab with profile creation, requests and friends

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 6: Arkadaş ekleme sayfası

**Files:**
- Modify: `lib/features/social/presentation/add_friend_sheet.dart` (tamamı)
- Test: `test/features/social/presentation/add_friend_sheet_test.dart`

**Interfaces:**
- Consumes: Task 4 (`socialRepositoryProvider`, `socialActionsProvider`), Task 2 (`normalizeUsername`, `FoundUser`), Task 5 (`SocialAvatar`).
- Produces: `Future<void> showAddFriendSheet(BuildContext context)`, `AddFriendSheet()`.

- [ ] **Step 1: Başarısız testleri yaz**

`test/features/social/presentation/add_friend_sheet_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spor_takip/features/social/application/social_providers.dart';
import 'package:spor_takip/features/social/presentation/add_friend_sheet.dart';

import '../../progress/presentation/test_app.dart';
import '../fakes.dart';
import '../social_fixtures.dart';

void main() {
  setUpAll(initTestLocalization);

  Future<void> pump(WidgetTester tester, FakeSocialRepository repo) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(testApp(
      Builder(
        builder: (context) => TextButton(onPressed: () => showAddFriendSheet(context), child: const Text('open')),
      ),
      overrides: [socialRepositoryProvider.overrideWithValue(repo)],
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  Future<void> search(WidgetTester tester, String query) async {
    await tester.enterText(find.byKey(const Key('add_query_field')), query);
    await tester.tap(find.byKey(const Key('add_search')));
    await tester.pumpAndSettle();
  }

  testWidgets('an unknown username says no one was found', (tester) async {
    await pump(tester, FakeSocialRepository(me: socialMe, others: [socialAyse]));
    await search(tester, 'nobody');
    expect(find.byKey(const Key('add_not_found')), findsOneWidget);
    expect(find.byKey(const Key('add_result')), findsNothing);
  });

  testWidgets('a username match sends a request and shows the outcome', (tester) async {
    final repo = FakeSocialRepository(me: socialMe, others: [socialAyse]);
    await pump(tester, repo);
    await search(tester, '@Ayse_K');
    expect(find.byKey(const Key('add_result')), findsOneWidget);
    expect(find.text('Ayşe Kaya'), findsOneWidget);

    await tester.tap(find.byKey(const Key('add_send')));
    await tester.pumpAndSettle();
    expect(repo.sent, ['ayse']);
    expect(find.text('social.outcome_pending'), findsOneWidget);
    expect(tester.widget<FilledButton>(find.byKey(const Key('add_send'))).onPressed, isNull);
  });

  testWidgets('an invite code finds the person; a mutual request becomes a friendship', (tester) async {
    final repo = FakeSocialRepository(me: socialMe, others: [socialBurak])..sendResult = 'accepted';
    await pump(tester, repo);
    await tester.tap(find.byKey(const Key('add_mode_invite')));
    await tester.pumpAndSettle();
    await search(tester, 'burak234');
    expect(find.text('Burak'), findsOneWidget);

    await tester.tap(find.byKey(const Key('add_send')));
    await tester.pumpAndSettle();
    expect(find.text('social.outcome_accepted'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Testin başarısız olduğunu gör**

Run: `flutter test --no-pub -j 1 test/features/social/presentation/add_friend_sheet_test.dart`
Expected: FAIL — `add_query_field` bulunamıyor (iskelet sayfa açmıyor).

- [ ] **Step 3: Sayfayı yaz**

`lib/features/social/presentation/add_friend_sheet.dart`:

```dart
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_fonts.dart';
import '../../../shared/text_case.dart';
import '../application/social_providers.dart';
import '../domain/public_profile.dart';
import '../domain/username.dart';
import 'widgets/social_avatar.dart';

/// Kullanıcı adı ya da davet koduyla tam eşleşme arar, istek gönderir (S1 spec §6.3).
Future<void> showAddFriendSheet(BuildContext context) => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => const AddFriendSheet(),
    );

class AddFriendSheet extends ConsumerStatefulWidget {
  const AddFriendSheet({super.key});

  @override
  ConsumerState<AddFriendSheet> createState() => _AddFriendSheetState();
}

class _AddFriendSheetState extends ConsumerState<AddFriendSheet> {
  final _query = TextEditingController();
  bool _byInvite = false;
  bool _searching = false;
  bool _searched = false;
  bool _sending = false;
  FoundUser? _found;
  String? _outcome;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  void _reset() {
    _found = null;
    _searched = false;
    _outcome = null;
  }

  Future<void> _search() async {
    final query = _query.text.trim();
    if (query.isEmpty) return;
    setState(() {
      _searching = true;
      _reset();
    });
    try {
      final repo = ref.read(socialRepositoryProvider);
      final found = _byInvite ? await repo.findByInviteCode(query) : await repo.findByUsername(normalizeUsername(query));
      if (mounted) setState(() => _found = found);
    } catch (e, st) {
      debugPrint('friend search failed: $e\n$st');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('social.action_error'.tr())));
    } finally {
      if (mounted) {
        setState(() {
          _searching = false;
          _searched = true;
        });
      }
    }
  }

  Future<void> _send() async {
    final found = _found;
    if (found == null) return;
    setState(() => _sending = true);
    try {
      final result = await ref.read(socialActionsProvider).send(found.userId);
      if (mounted) {
        setState(() => _outcome = switch (result) {
              'accepted' => 'social.outcome_accepted',
              'already_friends' => 'social.outcome_already',
              _ => 'social.outcome_pending',
            }
                .tr());
      }
    } catch (e, st) {
      debugPrint('send request failed: $e\n$st');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('social.action_error'.tr())));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final found = _found;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, MediaQuery.viewInsetsOf(context).bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            upperCaseFor('social.add_title'.tr(), context.locale.languageCode),
            style: theme.textTheme.titleLarge?.copyWith(fontFamily: AppFonts.heading, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 12),
          SegmentedButton<bool>(
            showSelectedIcon: false,
            segments: [
              ButtonSegment(
                value: false,
                label: Text('social.add_by_username'.tr(), key: const Key('add_mode_username')),
              ),
              ButtonSegment(value: true, label: Text('social.add_by_invite'.tr(), key: const Key('add_mode_invite'))),
            ],
            selected: {_byInvite},
            onSelectionChanged: (selection) => setState(() {
              _byInvite = selection.first;
              _query.clear();
              _reset();
            }),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  key: const Key('add_query_field'),
                  controller: _query,
                  autocorrect: false,
                  textCapitalization: _byInvite ? TextCapitalization.characters : TextCapitalization.none,
                  decoration: InputDecoration(prefixText: _byInvite ? null : '@'),
                  onSubmitted: (_) => _search(),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                key: const Key('add_search'),
                onPressed: _searching ? null : _search,
                child: Text('social.search'.tr()),
              ),
            ],
          ),
          if (_searched && found == null && !_searching)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text(
                'social.not_found'.tr(),
                key: const Key('add_not_found'),
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
            ),
          if (found != null)
            Card(
              key: const Key('add_result'),
              margin: const EdgeInsets.only(top: 16),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    SocialAvatar(initials: found.initials),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(found.displayName, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                          Text('@${found.username}', style: TextStyle(color: scheme.onSurfaceVariant)),
                        ],
                      ),
                    ),
                    FilledButton(
                      key: const Key('add_send'),
                      onPressed: _sending || _outcome != null ? null : _send,
                      child: Text('social.send_request'.tr()),
                    ),
                  ],
                ),
              ),
            ),
          if (_outcome case final outcome?)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(outcome, key: const Key('add_outcome'), style: TextStyle(color: scheme.primary)),
            ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Testlerin geçtiğini gör**

Run: `flutter test --no-pub -j 1 test/features/social/presentation/add_friend_sheet_test.dart test/features/social/presentation/social_screen_test.dart`
Expected: PASS (3 + 5).

- [ ] **Step 5: Commit**

```bash
git add lib/features/social/presentation/add_friend_sheet.dart test/features/social/presentation/add_friend_sheet_test.dart
git commit -m "feat(social): find people by username or invite code and send requests

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 7: Arkadaş profili

**Files:**
- Modify: `lib/features/workout/presentation/widgets/muscle_map.dart` (`MiniMuscleMapCard`)
- Create: `lib/features/social/presentation/friend_profile_screen.dart`
- Test: `test/features/social/presentation/friend_profile_screen_test.dart`

**Interfaces:**
- Consumes: Task 3 (`PlayerStats`, `RecentWorkout`), Task 4 (`friendProfileProvider`, `friendshipsProvider`, `socialActionsProvider`), Task 5 (`SocialAvatar`, `TitlePill`, `runSocialAction`); `RankBadge`, `titleName`; `mapFigureProvider` (`muscle_map_providers.dart`); `nowProvider`; `SectionHeader`.
- Produces:
  - `MiniMuscleMapCard({Key? key, required BodyFigure figure, required Map<String, HeatTier> heat, VoidCallback? onTap, bool showTitle = true})`
  - `String agoLabel(DateTime updatedAt, DateTime now)`
  - `FriendProfileScreen({required String friendId})` (`friend_profile_screen`)

- [ ] **Step 1: Başarısız testleri yaz**

`test/features/social/presentation/friend_profile_screen_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spor_takip/features/onboarding/application/profile_providers.dart';
import 'package:spor_takip/features/social/application/social_providers.dart';
import 'package:spor_takip/features/social/presentation/friend_profile_screen.dart';
import 'package:spor_takip/features/workout/application/session_providers.dart';

import '../../progress/fixtures.dart';
import '../../progress/presentation/test_app.dart';
import '../fakes.dart';
import '../social_fixtures.dart';

void main() {
  setUpAll(initTestLocalization);

  Future<FakeSocialRepository> pump(WidgetTester tester, {bool withSections = true, bool withStats = true}) async {
    final repo = FakeSocialRepository(
      me: socialMe,
      others: [socialAyse],
      friendships: [socialFriendship('me', 'ayse')],
      stats: {if (withStats) 'ayse': socialStats(withSections: withSections)},
    );
    tester.view.physicalSize = const Size(800, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(testApp(
      const FriendProfileScreen(friendId: 'ayse'),
      scaffold: false,
      overrides: [
        socialRepositoryProvider.overrideWithValue(repo),
        profileProvider.overrideWith((ref) async => testProfile),
        nowProvider.overrideWithValue(() => DateTime(2026, 10, 9, 12)),
      ],
    ));
    await tester.pumpAndSettle();
    return repo;
  }

  test('ago labels step from minutes to hours to days', () {
    final now = DateTime(2026, 10, 9, 12);
    expect(agoLabel(now.subtract(const Duration(seconds: 30)), now), 'social.ago_now');
    expect(agoLabel(now.subtract(const Duration(minutes: 5)), now), 'social.ago_minutes');
    expect(agoLabel(now.subtract(const Duration(hours: 3)), now), 'social.ago_hours');
    expect(agoLabel(now.subtract(const Duration(days: 2)), now), 'social.ago_days');
  });

  testWidgets('shows the header, titles, week, heat and recent workouts', (tester) async {
    await pump(tester);
    expect(find.byKey(const Key('friend_profile_screen')), findsOneWidget);
    expect(find.text('@ayse_k'), findsOneWidget);
    for (final key in ['friend_header', 'friend_active_title', 'friend_updated', 'friend_titles', 'friend_weekly',
        'friend_heat', 'friend_recent', 'friend_recent_0', 'friend_recent_1']) {
      expect(find.byKey(Key(key)), findsOneWidget, reason: key);
    }
    expect(find.text('62'), findsOneWidget);
    expect(find.descendant(of: find.byKey(const Key('friend_recent_0')), matching: find.text('social.record_line')),
        findsOneWidget);
    expect(find.byKey(const Key('friend_hidden_weekly')), findsNothing);
  });

  testWidgets('hidden sections say they are not shared', (tester) async {
    await pump(tester, withSections: false);
    expect(find.byKey(const Key('friend_hidden_weekly')), findsOneWidget);
    expect(find.byKey(const Key('friend_hidden_heat')), findsOneWidget);
    expect(find.byKey(const Key('friend_hidden_recent')), findsOneWidget);
    expect(find.byKey(const Key('friend_weekly')), findsNothing);
  });

  testWidgets('a friend without stats shows only the name', (tester) async {
    await pump(tester, withStats: false);
    expect(find.byKey(const Key('friend_no_stats')), findsOneWidget);
    expect(find.byKey(const Key('friend_titles')), findsNothing);
  });

  testWidgets('removing asks for confirmation and calls the repository', (tester) async {
    final repo = await pump(tester);
    await tester.tap(find.byKey(const Key('friend_menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('friend_remove')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('friend_remove_confirm')), findsOneWidget);
    await tester.tap(find.byKey(const Key('friend_remove_confirm')));
    await tester.pumpAndSettle();
    expect(repo.removed, ['ayse']);
    expect(find.byKey(const Key('friend_not_found')), findsOneWidget);
  });
}
```

- [ ] **Step 2: Testin başarısız olduğunu gör**

Run: `flutter test --no-pub -j 1 test/features/social/presentation/friend_profile_screen_test.dart`
Expected: FAIL — `friend_profile_screen.dart` yok.

- [ ] **Step 3: `MiniMuscleMapCard`'ı esnet**

`lib/features/workout/presentation/widgets/muscle_map.dart` içinde `MiniMuscleMapCard` sınıfını şununla değiştir:

```dart
/// Ön ve arka figür yan yana, ısı tonlarıyla. Figürler dokunuş yakalamaz; [onTap]
/// verilirse kartın tamamı dokunulabilir ve sağ üstte ok görünür (program detayı);
/// verilmezse düz kart (arkadaş profili). [showTitle] "Çalışan kaslar" başlığını gösterir.
class MiniMuscleMapCard extends StatelessWidget {
  const MiniMuscleMapCard({
    super.key,
    required this.figure,
    required this.heat,
    this.onTap,
    this.showTitle = true,
  });

  final BodyFigure figure;
  final Map<String, HeatTier> heat;
  final VoidCallback? onTap;
  final bool showTitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final heading = theme.textTheme.titleSmall?.copyWith(fontFamily: AppFonts.heading, fontWeight: FontWeight.w800);
    final onTap = this.onTap;
    final content = Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (showTitle) ...[
            Row(
              children: [
                Expanded(
                  child: Text(
                    upperCaseFor('workout.muscle_map.program_card_title'.tr(), context.locale.languageCode),
                    style: heading,
                  ),
                ),
                if (onTap != null) Icon(Icons.chevron_right, color: theme.colorScheme.onSurfaceVariant),
              ],
            ),
            const SizedBox(height: 12),
          ],
          SizedBox(
            height: 180,
            child: Row(
              children: [
                Expanded(child: MuscleMap(view: BodyView.front, figure: figure, heat: heat)),
                const SizedBox(width: 12),
                Expanded(child: MuscleMap(view: BodyView.back, figure: figure, heat: heat)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Uzun çeviride taşmak yerine küçülür.
          const Align(
            alignment: Alignment.centerRight,
            child: FittedBox(fit: BoxFit.scaleDown, child: HeatLegend()),
          ),
        ],
      ),
    );
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: onTap == null ? content : InkWell(onTap: onTap, child: content),
    );
  }
}
```

- [ ] **Step 4: Arkadaş profilini yaz**

`lib/features/social/presentation/friend_profile_screen.dart`:

```dart
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_fonts.dart';
import '../../../shared/text_case.dart';
import '../../../shared/widgets/section_header.dart';
import '../../gamification/presentation/title_names.dart';
import '../../gamification/presentation/widgets/rank_badge.dart';
import '../../workout/application/muscle_map_providers.dart';
import '../../workout/application/session_providers.dart';
import '../../workout/presentation/widgets/muscle_map.dart';
import '../application/social_providers.dart';
import '../domain/player_stats.dart';
import 'social_screen.dart';
import 'widgets/social_avatar.dart';

/// "3 saat önce" gibi; çeviri anahtarı + {n}.
String agoLabel(DateTime updatedAt, DateTime now) {
  final diff = now.difference(updatedAt);
  if (diff.inMinutes < 1) return 'social.ago_now'.tr();
  if (diff.inHours < 1) return 'social.ago_minutes'.tr(namedArgs: {'n': '${diff.inMinutes}'});
  if (diff.inDays < 1) return 'social.ago_hours'.tr(namedArgs: {'n': '${diff.inHours}'});
  return 'social.ago_days'.tr(namedArgs: {'n': '${diff.inDays}'});
}

String _formatKg(double kg) => kg == kg.roundToDouble() ? '${kg.toInt()}' : kg.toStringAsFixed(1);

String _dayLabel(DateTime date) => '${date.day} ${'home.month_${date.month}'.tr()}';

/// Arkadaşın paylaştıkları (S1 spec §6.4).
class FriendProfileScreen extends ConsumerWidget {
  const FriendProfileScreen({super.key, required this.friendId});

  final String friendId;

  Future<void> _confirmRemove(BuildContext context, WidgetRef ref, FriendEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('social.remove_title'.tr()),
        content: Text('social.remove_body'.tr(namedArgs: {'name': entry.profile.displayName})),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: Text('social.cancel'.tr())),
          TextButton(
            key: const Key('friend_remove_confirm'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text('social.remove_confirm'.tr()),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await runSocialAction(context, () => ref.read(socialActionsProvider).remove(entry.profile.userId));
    if (context.mounted && context.canPop()) context.pop();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entryAsync = ref.watch(friendProfileProvider(friendId));
    final entry = entryAsync.value;
    return Scaffold(
      key: const Key('friend_profile_screen'),
      appBar: AppBar(
        title: Text(entry == null ? '' : '@${entry.profile.username}'),
        actions: [
          if (entry != null)
            PopupMenuButton<String>(
              key: const Key('friend_menu'),
              onSelected: (_) => _confirmRemove(context, ref, entry),
              itemBuilder: (context) => [
                PopupMenuItem(value: 'remove', key: const Key('friend_remove'), child: Text('social.remove'.tr())),
              ],
            ),
        ],
      ),
      body: entryAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(
          child: TextButton(
            key: const Key('friend_retry'),
            onPressed: () => ref.invalidate(friendshipsProvider),
            child: Text('social.retry'.tr()),
          ),
        ),
        data: (entry) => entry == null
            ? Center(child: Text('social.not_friend'.tr(), key: const Key('friend_not_found')))
            : _FriendBody(entry: entry),
      ),
    );
  }
}

class _FriendBody extends ConsumerWidget {
  const _FriendBody({required this.entry});

  final FriendEntry entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = entry.stats;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        _Header(entry: entry, now: ref.watch(nowProvider)()),
        if (stats != null) ...[
          SectionHeader('social.friend_titles'.tr()),
          _Titles(stats: stats),
          SectionHeader('social.friend_weekly'.tr()),
          if (stats.weekly case final weekly?)
            _Weekly(weekly: weekly)
          else
            const _Hidden(key: Key('friend_hidden_weekly')),
          SectionHeader('social.friend_heat'.tr()),
          if (stats.heat case final heat?)
            MiniMuscleMapCard(
              key: const Key('friend_heat'),
              figure: ref.watch(mapFigureProvider),
              heat: heat,
              showTitle: false,
            )
          else
            const _Hidden(key: Key('friend_hidden_heat')),
          SectionHeader('social.friend_recent'.tr()),
          if (stats.recent case final recent?)
            _Recent(recent: recent)
          else
            const _Hidden(key: Key('friend_hidden_recent')),
        ],
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.entry, required this.now});

  final FriendEntry entry;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final muted = theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant);
    final stats = entry.stats;
    final active = stats?.activeTitle;
    final updatedAt = stats?.updatedAt;
    final lang = context.locale.languageCode;
    return Card(
      key: const Key('friend_header'),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            if (stats != null)
              RankBadge(rank: stats.rank, level: stats.level, size: 88)
            else
              SocialAvatar(initials: entry.profile.initials, size: 72),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.profile.displayName,
                    style: theme.textTheme.headlineSmall?.copyWith(fontFamily: AppFonts.heading, fontWeight: FontWeight.w900),
                  ),
                  if (active != null)
                    Padding(
                      key: const Key('friend_active_title'),
                      padding: const EdgeInsets.only(top: 6),
                      child: TitlePill(text: titleName(active.asProgress, active.tier)),
                    ),
                  if (stats == null)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text('social.no_stats'.tr(), key: const Key('friend_no_stats'), style: muted),
                    )
                  else ...[
                    const SizedBox(height: 8),
                    Text(
                      'social.level_line'.tr(namedArgs: {
                        'n': '${stats.level}',
                        'rank': upperCaseFor(stats.rank.labelKey.tr(), lang),
                      }),
                      style: theme.textTheme.labelLarge?.copyWith(color: scheme.primary, fontWeight: FontWeight.w800),
                    ),
                    Text('social.total_xp'.tr(namedArgs: {'n': '${stats.totalXp}'}), style: muted),
                    if (updatedAt != null)
                      Text(
                        'social.updated'.tr(namedArgs: {'ago': agoLabel(updatedAt, now)}),
                        key: const Key('friend_updated'),
                        style: muted,
                      ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Titles extends StatelessWidget {
  const _Titles({required this.stats});

  final PlayerStats stats;

  @override
  Widget build(BuildContext context) {
    if (stats.titles.isEmpty) {
      return Text(
        'social.friend_titles_empty'.tr(),
        key: const Key('friend_titles'),
        style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
      );
    }
    return Wrap(
      key: const Key('friend_titles'),
      spacing: 8,
      runSpacing: 8,
      children: [for (final t in stats.titles) Chip(label: Text(titleName(t.asProgress, t.tier)))],
    );
  }
}

class _Weekly extends StatelessWidget {
  const _Weekly({required this.weekly});

  final WeeklyStats weekly;

  @override
  Widget build(BuildContext context) {
    Widget tile(IconData icon, int value, String label) => Expanded(
          child: Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
              child: Column(
                children: [
                  Icon(icon, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(height: 6),
                  Text(
                    '$value',
                    style: Theme.of(context)
                        .textTheme
                        .headlineMedium
                        ?.copyWith(fontFamily: AppFonts.heading, fontWeight: FontWeight.w900),
                  ),
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ),
        );
    return Row(
      key: const Key('friend_weekly'),
      children: [
        tile(Icons.fitness_center, weekly.workouts, 'social.weekly_workouts'.tr()),
        const SizedBox(width: 8),
        tile(Icons.repeat, weekly.sets, 'social.weekly_sets'.tr()),
        const SizedBox(width: 8),
        tile(Icons.restaurant, weekly.mealDays, 'social.weekly_meal_days'.tr()),
      ],
    );
  }
}

class _Recent extends StatelessWidget {
  const _Recent({required this.recent});

  final List<RecentWorkout> recent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    if (recent.isEmpty) {
      return Text(
        'social.friend_recent_empty'.tr(),
        key: const Key('friend_recent'),
        style: TextStyle(color: scheme.onSurfaceVariant),
      );
    }
    return Column(
      key: const Key('friend_recent'),
      children: [
        for (final (index, workout) in recent.indexed)
          Card(
            key: Key('friend_recent_$index'),
            margin: const EdgeInsets.only(bottom: 8),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: scheme.surfaceContainerHighest,
                        child: Icon(Icons.fitness_center, color: scheme.primary, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(workout.name, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                            Text(
                              'social.recent_line'
                                  .tr(namedArgs: {'sets': '${workout.sets}', 'date': _dayLabel(workout.date)}),
                              style: TextStyle(color: scheme.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  for (final record in workout.records)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Row(
                        children: [
                          Icon(Icons.bolt, size: 18, color: scheme.primary),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              'social.record_line'.tr(namedArgs: {
                                'name': record.name,
                                'kg': _formatKg(record.weightKg),
                                'reps': '${record.reps}',
                              }),
                              style: TextStyle(color: scheme.primary, fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _Hidden extends StatelessWidget {
  const _Hidden({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.lock_outline, color: scheme.onSurfaceVariant),
            const SizedBox(width: 12),
            Text('social.hidden'.tr(), style: TextStyle(color: scheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 5: Testlerin geçtiğini gör**

Run: `flutter test --no-pub -j 1 test/features/social/presentation/friend_profile_screen_test.dart test/features/workout/presentation/program_detail_screen_test.dart test/features/workout/presentation/muscle_map_widget_test.dart`
Expected: PASS (5 yeni + mevcut program detayı ve harita testleri).

- [ ] **Step 6: Commit**

```bash
git add lib/features/workout/presentation/widgets/muscle_map.dart lib/features/social/presentation/friend_profile_screen.dart test/features/social/presentation/friend_profile_screen_test.dart
git commit -m "feat(social): show a friend's level, titles, week, muscle heat and workouts

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 8: Sosyal ayarlar

**Files:**
- Create: `lib/features/social/presentation/social_settings_screen.dart`
- Test: `test/features/social/presentation/social_settings_screen_test.dart`

**Interfaces:**
- Consumes: Task 4 (`myPublicProfileProvider`, `socialActionsProvider`, `UsernameTakenException`), Task 5 (`UsernameField`, `UsernameStatus`, `runSocialAction`), Task 2 (`normalizeUsername`).
- Produces: `SocialSettingsScreen()` (`social_settings_screen`).

- [ ] **Step 1: Başarısız testleri yaz**

`test/features/social/presentation/social_settings_screen_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spor_takip/features/social/application/social_providers.dart';
import 'package:spor_takip/features/social/presentation/social_settings_screen.dart';

import '../../progress/presentation/test_app.dart';
import '../fakes.dart';
import '../social_fixtures.dart';

void main() {
  setUpAll(initTestLocalization);

  Future<FakeSocialRepository> pump(WidgetTester tester, {Set<String> taken = const {}}) async {
    final repo = FakeSocialRepository(me: socialMe, taken: taken);
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(testApp(
      const SocialSettingsScreen(),
      scaffold: false,
      overrides: [socialRepositoryProvider.overrideWithValue(repo)],
    ));
    await tester.pumpAndSettle();
    return repo;
  }

  testWidgets('starts with my names and lets me change the display name', (tester) async {
    final repo = await pump(tester);
    expect(find.text('samet_fit'), findsOneWidget);
    expect(find.text('Samet'), findsOneWidget);
    expect(find.text('social.username_available'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('settings_display_name')), 'Samet A.');
    await tester.pump();
    await tester.tap(find.byKey(const Key('settings_save')));
    await tester.pumpAndSettle();
    expect(repo.me?.displayName, 'Samet A.');
    expect(repo.me?.username, 'samet_fit');
    expect(find.text('social.saved'), findsOneWidget);
  });

  testWidgets('a taken username is rejected', (tester) async {
    final repo = await pump(tester, taken: {'ayse_k'});
    await tester.enterText(find.byKey(const Key('settings_username')), 'ayse_k');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    expect(find.text('social.username_taken'), findsOneWidget);
    expect(tester.widget<FilledButton>(find.byKey(const Key('settings_save'))).onPressed, isNull);
    expect(repo.me?.username, 'samet_fit');
  });

  testWidgets('privacy switches save right away', (tester) async {
    final repo = await pump(tester);
    await tester.tap(find.byKey(const Key('share_weekly')));
    await tester.pumpAndSettle();
    expect(repo.me?.shareWeekly, isFalse);
    await tester.tap(find.byKey(const Key('share_heat')));
    await tester.pumpAndSettle();
    expect(repo.me?.shareHeat, isFalse);
    expect(repo.me?.shareWorkouts, isTrue);
    expect(tester.widget<SwitchListTile>(find.byKey(const Key('share_weekly'))).value, isFalse);
  });
}
```

- [ ] **Step 2: Testin başarısız olduğunu gör**

Run: `flutter test --no-pub -j 1 test/features/social/presentation/social_settings_screen_test.dart`
Expected: FAIL — `social_settings_screen.dart` yok.

- [ ] **Step 3: Ayarlar ekranını yaz**

`lib/features/social/presentation/social_settings_screen.dart`:

```dart
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/section_header.dart';
import '../application/social_providers.dart';
import '../data/social_repository.dart';
import '../domain/public_profile.dart';
import '../domain/username.dart';
import 'social_screen.dart';
import 'widgets/username_field.dart';

/// Görünen ad, kullanıcı adı ve gizlilik anahtarları (S1 spec §6.5).
class SocialSettingsScreen extends ConsumerWidget {
  const SocialSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(myPublicProfileProvider);
    return Scaffold(
      key: const Key('social_settings_screen'),
      appBar: AppBar(title: Text('social.settings_title'.tr())),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(
          child: TextButton(
            onPressed: () => ref.invalidate(myPublicProfileProvider),
            child: Text('social.retry'.tr()),
          ),
        ),
        data: (me) => me == null ? const SizedBox.shrink() : _SettingsForm(me: me),
      ),
    );
  }
}

class _SettingsForm extends ConsumerStatefulWidget {
  const _SettingsForm({required this.me});

  final PublicProfile me;

  @override
  ConsumerState<_SettingsForm> createState() => _SettingsFormState();
}

class _SettingsFormState extends ConsumerState<_SettingsForm> {
  late final _username = TextEditingController(text: widget.me.username);
  late final _displayName = TextEditingController(text: widget.me.displayName);
  UsernameStatus _status = UsernameStatus.available;
  bool _forceTaken = false;
  bool _saving = false;

  @override
  void dispose() {
    _username.dispose();
    _displayName.dispose();
    super.dispose();
  }

  bool get _canSave =>
      !_saving && !_forceTaken && _status == UsernameStatus.available && _displayName.text.trim().isNotEmpty;

  Future<void> _save() async {
    final username = normalizeUsername(_username.text);
    final displayName = _displayName.text.trim();
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _saving = true);
    try {
      await ref.read(socialActionsProvider).updateProfile(
            username: username == widget.me.username ? null : username,
            displayName: displayName == widget.me.displayName ? null : displayName,
          );
      messenger.showSnackBar(SnackBar(content: Text('social.saved'.tr())));
    } on UsernameTakenException {
      if (mounted) setState(() => _forceTaken = true);
    } catch (e, st) {
      debugPrint('updateProfile failed: $e\n$st');
      messenger.showSnackBar(SnackBar(content: Text('social.action_error'.tr())));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(myPublicProfileProvider).value ?? widget.me;
    final actions = ref.read(socialActionsProvider);
    final scheme = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        TextField(
          key: const Key('settings_display_name'),
          controller: _displayName,
          maxLength: 30,
          decoration: InputDecoration(labelText: 'social.display_name_label'.tr()),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 8),
        UsernameField(
          controller: _username,
          fieldKey: const Key('settings_username'),
          currentUsername: widget.me.username,
          forceTaken: _forceTaken,
          onStatusChanged: (status) => setState(() {
            _status = status;
            _forceTaken = false;
          }),
        ),
        const SizedBox(height: 12),
        FilledButton(
          key: const Key('settings_save'),
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
          onPressed: _canSave ? _save : null,
          child: Text('social.save'.tr()),
        ),
        SectionHeader('social.privacy_title'.tr()),
        SwitchListTile(
          key: const Key('share_weekly'),
          title: Text('social.share_weekly'.tr()),
          value: me.shareWeekly,
          onChanged: (v) => runSocialAction(context, () => actions.updateProfile(shareWeekly: v)),
        ),
        SwitchListTile(
          key: const Key('share_workouts'),
          title: Text('social.share_workouts'.tr()),
          value: me.shareWorkouts,
          onChanged: (v) => runSocialAction(context, () => actions.updateProfile(shareWorkouts: v)),
        ),
        SwitchListTile(
          key: const Key('share_heat'),
          title: Text('social.share_heat'.tr()),
          value: me.shareHeat,
          onChanged: (v) => runSocialAction(context, () => actions.updateProfile(shareHeat: v)),
        ),
        const SizedBox(height: 8),
        Text('social.privacy_note'.tr(), style: TextStyle(color: scheme.onSurfaceVariant)),
      ],
    );
  }
}
```

- [ ] **Step 4: Testlerin geçtiğini gör**

Run: `flutter test --no-pub -j 1 test/features/social/presentation/social_settings_screen_test.dart`
Expected: PASS (3 test).

- [ ] **Step 5: Commit**

```bash
git add lib/features/social/presentation/social_settings_screen.dart test/features/social/presentation/social_settings_screen_test.dart
git commit -m "feat(social): add social settings with names and per-section privacy

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 9: Beşinci sekme ve rotalar

**Files:**
- Modify: `lib/core/app_shell.dart` (tamamı)
- Modify: `lib/core/router.dart` (importlar + beşinci dal)
- Modify: `test/core/app_shell_test.dart`

**Interfaces:**
- Consumes: Task 4 (`statsSyncProvider`, `incomingRequestCountProvider`), Task 5/7/8 ekranları.
- Produces: `AppShell` (`ConsumerWidget`), rotalar `/social`, `/social/friend/:id`, `/social/settings`.

- [ ] **Step 1: Kabuk testini güncelle (önce başarısız)**

`test/core/app_shell_test.dart` dosyasını şununla değiştir:

```dart
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spor_takip/core/app_shell.dart';
import 'package:spor_takip/features/social/application/social_providers.dart';

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  Widget buildTestRouter({int requests = 0}) {
    final router = GoRouter(
      initialLocation: '/home',
      routes: [
        StatefulShellRoute.indexedStack(
          builder: (context, state, navigationShell) => AppShell(navigationShell: navigationShell),
          branches: [
            StatefulShellBranch(routes: [
              GoRoute(path: '/home', builder: (context, state) => const Text('HOME_SCREEN')),
            ]),
            StatefulShellBranch(routes: [
              GoRoute(path: '/nutrition', builder: (context, state) => const Text('NUTRITION_SCREEN')),
            ]),
            StatefulShellBranch(routes: [
              GoRoute(path: '/workout', builder: (context, state) => const Text('WORKOUT_SCREEN')),
            ]),
            StatefulShellBranch(routes: [
              GoRoute(path: '/coach', builder: (context, state) => const Text('COACH_SCREEN')),
            ]),
            StatefulShellBranch(routes: [
              GoRoute(path: '/social', builder: (context, state) => const Text('SOCIAL_SCREEN')),
            ]),
          ],
        ),
      ],
    );
    return EasyLocalization(
      supportedLocales: const [Locale('tr'), Locale('en')],
      path: 'assets/translations',
      fallbackLocale: const Locale('tr'),
      child: ProviderScope(
        overrides: [
          statsSyncProvider.overrideWith((ref) async {}),
          incomingRequestCountProvider.overrideWithValue(requests),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
  }

  testWidgets('shows all nav destinations and starts on the home branch', (tester) async {
    await tester.pumpWidget(buildTestRouter());
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('app_bottom_nav')), findsOneWidget);
    expect(find.text('HOME_SCREEN'), findsOneWidget);
    expect(find.text('NUTRITION_SCREEN'), findsNothing);
    expect(find.byIcon(Icons.group_outlined), findsOneWidget);
    expect(find.byKey(const Key('nav_social_badge')), findsNothing);
  });

  testWidgets('tapping the nutrition destination switches branch', (tester) async {
    await tester.pumpWidget(buildTestRouter());
    await tester.pumpAndSettle();

    // Çeviri metni testlerde güvenilir değil; ikonla dokunulur.
    await tester.tap(find.byIcon(Icons.restaurant_outlined));
    await tester.pumpAndSettle();

    expect(find.text('NUTRITION_SCREEN'), findsOneWidget);
    expect(find.text('HOME_SCREEN'), findsNothing);
  });

  testWidgets('tapping the workout destination switches branch', (tester) async {
    await tester.pumpWidget(buildTestRouter());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.fitness_center_outlined));
    await tester.pumpAndSettle();

    expect(find.text('WORKOUT_SCREEN'), findsOneWidget);
    expect(find.text('HOME_SCREEN'), findsNothing);
  });

  testWidgets('tapping the coach destination switches to the coach branch', (tester) async {
    await tester.pumpWidget(buildTestRouter());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.forum_outlined));
    await tester.pumpAndSettle();

    expect(find.text('COACH_SCREEN'), findsOneWidget);
    expect(find.text('HOME_SCREEN'), findsNothing);
  });

  testWidgets('the social tab opens the social branch and shows pending requests', (tester) async {
    await tester.pumpWidget(buildTestRouter(requests: 2));
    await tester.pumpAndSettle();

    final badge = find.byKey(const Key('nav_social_badge'));
    expect(badge, findsOneWidget);
    expect(find.descendant(of: badge, matching: find.text('2')), findsOneWidget);

    await tester.tap(find.byIcon(Icons.group_outlined));
    await tester.pumpAndSettle();
    expect(find.text('SOCIAL_SCREEN'), findsOneWidget);
  });
}
```

Run: `flutter test --no-pub -j 1 test/core/app_shell_test.dart`
Expected: FAIL — beşinci sekme ve rozet yok.

- [ ] **Step 2: Kabuğu yaz**

`lib/core/app_shell.dart`:

```dart
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/social/application/social_providers.dart';

class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Kabuk açıkken oyuncu özeti arkadaşlar için yayınlanır (S1 spec §6.1).
    ref.watch(statsSyncProvider);
    final requests = ref.watch(incomingRequestCountProvider);
    Widget socialIcon(IconData icon) =>
        requests > 0 ? Badge(key: const Key('nav_social_badge'), label: Text('$requests'), child: Icon(icon)) : Icon(icon);
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        key: const Key('app_bottom_nav'),
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (index) => navigationShell.goBranch(
          index,
          initialLocation: index == navigationShell.currentIndex,
        ),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.home_outlined),
            selectedIcon: const Icon(Icons.home),
            label: 'nav.home'.tr(),
          ),
          NavigationDestination(
            icon: const Icon(Icons.restaurant_outlined),
            selectedIcon: const Icon(Icons.restaurant),
            label: 'nav.nutrition'.tr(),
          ),
          NavigationDestination(
            icon: const Icon(Icons.fitness_center_outlined),
            selectedIcon: const Icon(Icons.fitness_center),
            label: 'nav.workout'.tr(),
          ),
          NavigationDestination(
            icon: const Icon(Icons.forum_outlined),
            selectedIcon: const Icon(Icons.forum),
            label: 'nav.coach'.tr(),
          ),
          NavigationDestination(
            icon: socialIcon(Icons.group_outlined),
            selectedIcon: socialIcon(Icons.group),
            label: 'nav.social'.tr(),
          ),
        ],
      ),
    );
  }
}
```

Not: Seçili ve seçili olmayan ikon aynı anda ağaçta olmaz; `nav_social_badge` anahtarı tek kez bulunur.

- [ ] **Step 3: Rotaları ekle**

`lib/core/router.dart` importlarına (alfabetik sırayla, `features/settings` satırlarının yanına) ekle:

```dart
import '../features/social/presentation/friend_profile_screen.dart';
import '../features/social/presentation/social_screen.dart';
import '../features/social/presentation/social_settings_screen.dart';
```

Son `StatefulShellBranch` (`/coach`) kapanışından sonra, `branches` listesinin sonuna ekle:

```dart
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/social',
                builder: (context, state) => const SocialScreen(),
                routes: [
                  GoRoute(
                    path: 'friend/:id',
                    builder: (context, state) => FriendProfileScreen(friendId: state.pathParameters['id']!),
                  ),
                  GoRoute(path: 'settings', builder: (context, state) => const SocialSettingsScreen()),
                ],
              ),
            ],
          ),
```

- [ ] **Step 4: Testlerin geçtiğini gör**

Run: `flutter test --no-pub -j 1 test/core/app_shell_test.dart`
Expected: PASS (5 test).

- [ ] **Step 5: Analiz**

Run: `flutter analyze --no-pub` (arka planda)
Expected: `No issues found!`

- [ ] **Step 6: Commit**

```bash
git add lib/core/app_shell.dart lib/core/router.dart test/core/app_shell_test.dart
git commit -m "feat(social): add the social tab with a request badge and its routes

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 10: Doğrulama ve kayıt

**Files:**
- Modify: `PLAN.md`

- [ ] **Step 1: Statik analiz**

Run: `flutter analyze --no-pub` (arka planda). Expected: `No issues found!`

- [ ] **Step 2: Kullanıcıdan migration ve RLS kontrolü**

Kullanıcı SQL Editor'da `0013_social_friends.sql`'i, ardından `checks/s1_rls_checks.sql`'i çalıştırır. Beklenen: `SONUC: A_istek=pending B_istek=accepted kendini_bulmaz=t buyuk_harf_bulundu=t A_icin_uygun=t B_icin_uygun=f B_gorulen=1 C_gorulen=0 C_profil=0 cikinca_B_gorulen=0 dogrudan_engellendi=t` (üçüncü hesap yoksa `C_*=atlandi`).

- [ ] **Step 3: Kullanıcıdan tam test paketi**

`flutter test --no-pub -j 1`. Beklenen ≈ 573 + modeller 6 + özet 8 + sağlayıcı 4 + sosyal ekran 5 + ekleme 3 + profil 5 + ayarlar 3 + kabuk 1 (yeni) = ~608.

- [ ] **Step 4: Kullanıcıdan web release derlemesi ve manuel kontrol**

`flutter build web --release --no-pub`; `build/web`'de `python -m http.server 5555 --bind 127.0.0.1`. İki hesap, iki tarayıcı profili (ya da biri gizli pencere). Spec §9 listesi:
1. Sosyal sekmesi ilk açılışta kimlik oluşturmayı istiyor; alınmış ad "alınmış" gösteriyor.
2. A, B'yi kullanıcı adıyla buluyor ve istek gönderiyor; B'nin sekmesinde rozet "1" (B sayfayı yenileyince).
3. B kabul ediyor; iki tarafta da arkadaş listesinde görünüyorlar.
4. Davet koduyla ekleme çalışıyor (arkadaşlıktan çıkarıp yeniden ekleyerek).
5. A antrenman bitiriyor; B yenileyince A'nın profilinde son antrenman ve rekor görünüyor.
6. A haftalık özeti kapatıyor; B yenileyince "Paylaşılmıyor".
7. Arkadaşlıktan çıkarınca iki tarafta da liste boşalıyor, profil açılmıyor.
8. ~360 px genişlikte taşma yok; EN metinler doğru.

- [ ] **Step 5: PLAN.md satırı ve commit**

`PLAN.md`'de O1 satırından sonra S1 satırı (tarih, dal, özet, migration ve kontrol sonucu, sapmalar, test sayısı, manuel sonuç, sıradaki: S2 topluluklar). Ardından:

```bash
git add PLAN.md
git commit -m "docs: record S1 friends foundation in the plan

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

- [ ] **Step 6: Dalı bitir**

superpowers:finishing-a-development-branch; kullanıcı onayıyla `s1-arkadaslik` → `master` fast-forward + push.
