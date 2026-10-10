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
