create table if not exists public.profiles (
  user_id uuid primary key references auth.users (id) on delete cascade,
  weight_kg numeric not null,
  height_cm numeric not null,
  birth_year integer not null,
  gender text not null check (gender in ('male', 'female', 'unspecified')),
  activity_level text not null check (
    activity_level in ('sedentary', 'light', 'moderate', 'active', 'very_active')
  ),
  does_exercise boolean not null,
  sport_type text,
  exercise_days_per_week integer not null check (exercise_days_per_week between 0 and 7),
  goal text not null check (goal in ('lose_weight', 'gain_muscle', 'maintain')),
  health_notes text,
  daily_calorie_target numeric not null,
  daily_protein_target_g numeric not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.profiles enable row level security;

create policy "Users can view own profile"
  on public.profiles for select
  using (auth.uid() = user_id);

create policy "Users can insert own profile"
  on public.profiles for insert
  with check (auth.uid() = user_id);

create policy "Users can update own profile"
  on public.profiles for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);
