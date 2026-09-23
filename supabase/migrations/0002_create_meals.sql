create table if not exists public.meals (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  meal_type text not null check (meal_type in ('breakfast', 'lunch', 'dinner', 'snack')),
  photo_path text,
  logged_at timestamptz not null default now(),
  created_at timestamptz not null default now()
);

create table if not exists public.meal_items (
  id uuid primary key default gen_random_uuid(),
  meal_id uuid not null references public.meals (id) on delete cascade,
  name text not null,
  grams numeric not null check (grams > 0),
  calories numeric not null default 0,
  protein_g numeric not null default 0,
  carbs_g numeric not null default 0,
  fat_g numeric not null default 0,
  usda_fdc_id text,
  needs_review boolean not null default false,
  created_at timestamptz not null default now()
);

alter table public.meals enable row level security;
alter table public.meal_items enable row level security;

create policy "Users can manage own meals"
  on public.meals for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create policy "Users can manage own meal items"
  on public.meal_items for all
  using (exists (select 1 from public.meals m where m.id = meal_id and m.user_id = auth.uid()))
  with check (exists (select 1 from public.meals m where m.id = meal_id and m.user_id = auth.uid()));
