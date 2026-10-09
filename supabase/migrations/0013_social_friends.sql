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
