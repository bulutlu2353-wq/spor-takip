create table if not exists public.exercises (
  id text primary key default gen_random_uuid()::text,
  user_id uuid references auth.users (id) on delete cascade, -- null = hazır hareket
  name text not null,
  category text,
  equipment text,
  level text,
  primary_muscles text[] not null default '{}',
  secondary_muscles text[] not null default '{}',
  instructions text[] not null default '{}',
  images text[] not null default '{}',
  created_at timestamptz not null default now()
);

alter table public.exercises enable row level security;

create policy "Users can view built-in and own exercises"
  on public.exercises for select
  using (user_id is null or user_id = auth.uid());

create policy "Users can insert own exercises"
  on public.exercises for insert
  with check (user_id = auth.uid());

create policy "Users can update own exercises"
  on public.exercises for update
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

create policy "Users can delete own exercises"
  on public.exercises for delete
  using (user_id = auth.uid());
