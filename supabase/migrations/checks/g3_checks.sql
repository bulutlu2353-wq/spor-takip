-- G3 göç kontrolleri (SQL Editor). Tüm sütunlar t olmalı.
select
  exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'profiles'
      and column_name = 'calorie_adjustment_kcal' and is_nullable = 'NO' and column_default = '0'
  ) as pay_varsayilan_0,
  (select count(*) from information_schema.columns
    where table_schema = 'public' and table_name = 'profiles'
      and column_name in ('calorie_adjusted_at', 'calorie_suggestion_snoozed_until', 'goals_changed_at')) = 3
    as zaman_sutunlari,
  not exists (select 1 from public.profiles where calorie_adjustment_kcal <> 0) as mevcut_paylar_0,
  position('goals_changed_at' in pg_get_functiondef('public.chat_write_profile(jsonb)'::regprocedure)) > 0
    as koc_yazar;
