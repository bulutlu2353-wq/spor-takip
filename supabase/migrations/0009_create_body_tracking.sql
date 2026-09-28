-- F4b: vücut ağırlığı ve beden ölçüleri.

create table if not exists public.body_weight_logs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  logged_on date not null,
  weight_kg numeric not null check (weight_kg > 0 and weight_kg < 500),
  created_at timestamptz not null default now(),
  unique (user_id, logged_on)              -- günde tek kayıt
);

create table if not exists public.body_measurements (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  measured_on date not null,
  -- cm; hepsi isteğe bağlı
  neck numeric check (neck > 0 and neck < 300),
  shoulders numeric check (shoulders > 0 and shoulders < 300),
  chest numeric check (chest > 0 and chest < 300),
  waist numeric check (waist > 0 and waist < 300),
  hips numeric check (hips > 0 and hips < 300),
  arm numeric check (arm > 0 and arm < 300),
  forearm numeric check (forearm > 0 and forearm < 300),
  thigh numeric check (thigh > 0 and thigh < 300),
  calf numeric check (calf > 0 and calf < 300),
  created_at timestamptz not null default now(),
  unique (user_id, measured_on),           -- günde tek ölçüm
  check (num_nonnulls(neck, shoulders, chest, waist, hips, arm, forearm, thigh, calf) > 0)
);

alter table public.body_weight_logs enable row level security;
alter table public.body_measurements enable row level security;

create policy "Users can manage own weight logs"
  on public.body_weight_logs for all
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

create policy "Users can manage own measurements"
  on public.body_measurements for all
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

-- Kilo kaydını yazar (aynı güne üzerine yazar). Kayıt en yeniyse profildeki kilo
-- ve hedefler de güncellenir; hedefleri uygulama TdeeCalculator ile hesaplar.
create or replace function public.log_body_weight(
  p_date date,
  p_kg numeric,
  p_calorie_target numeric,
  p_protein_target numeric
) returns void
language plpgsql
security invoker
set search_path = public
as $$
declare
  uid uuid := auth.uid();
  latest date;
begin
  if uid is null then
    raise exception 'not authenticated';
  end if;

  insert into body_weight_logs (user_id, logged_on, weight_kg)
    values (uid, p_date, p_kg)
    on conflict (user_id, logged_on) do update set weight_kg = excluded.weight_kg;

  select max(logged_on) into latest from body_weight_logs where user_id = uid;
  if p_date >= latest then
    update profiles
      set weight_kg = p_kg,
          daily_calorie_target = p_calorie_target,
          daily_protein_target_g = p_protein_target,
          updated_at = now()
      where user_id = uid;
  end if;
end;
$$;

-- Kilo kaydını siler. Tek kayıt silinemez (profildeki kilonun kaynağı).
-- Silinen en yeniyse profil kalan en yeni kayda göre güncellenir; uygulamanın
-- gönderdiği kilo o kayıtla uyuşmuyorsa (eski liste) işlem geri alınır.
create or replace function public.delete_body_weight(
  p_date date,
  p_new_latest_kg numeric,
  p_calorie_target numeric,
  p_protein_target numeric
) returns void
language plpgsql
security invoker
set search_path = public
as $$
declare
  uid uuid := auth.uid();
  remaining int;
  latest date;
  new_kg numeric;
begin
  if uid is null then
    raise exception 'not authenticated';
  end if;

  select count(*), max(logged_on) into remaining, latest
    from body_weight_logs where user_id = uid;
  if remaining <= 1 then
    raise exception 'last_weight_log';
  end if;

  delete from body_weight_logs where user_id = uid and logged_on = p_date;

  if p_date = latest then
    select weight_kg into new_kg
      from body_weight_logs where user_id = uid
      order by logged_on desc limit 1;
    if new_kg is distinct from p_new_latest_kg then
      raise exception 'stale_weight_list';
    end if;
    update profiles
      set weight_kg = new_kg,
          daily_calorie_target = p_calorie_target,
          daily_protein_target_g = p_protein_target,
          updated_at = now()
      where user_id = uid;
  end if;
end;
$$;

-- Mevcut profillerin kilosu ilk kayıt olur; grafik boş başlamaz.
insert into public.body_weight_logs (user_id, logged_on, weight_kg)
select user_id, created_at::date, weight_kg from public.profiles
on conflict (user_id, logged_on) do nothing;
