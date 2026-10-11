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
