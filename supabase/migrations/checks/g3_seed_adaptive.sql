-- G3 elle test verisi (yalnızca TEST hesabında, SQL Editor'de elle çalıştır).
-- 1) e-postayı değiştir, 2) çalıştır. Son 21 güne (bugün hariç) profildeki kiloyla sabit
-- kilo kaydı (var olan günlere dokunmaz) ve her güne 2200 kcal'lik "G3 test" öğünü ekler;
-- pencere açık olsun diye hedef/uyarlama zamanlarını 22 gün geri çeker, ertelemeyi siler.
do $$
declare
  uid uuid := (select id from auth.users where email = 'TEST_EPOSTA@ornek.com');
  kg numeric;
  d int;
  m uuid;
begin
  if uid is null then
    raise exception 'kullanıcı bulunamadı';
  end if;
  select weight_kg into kg from public.profiles where user_id = uid;
  for d in 1..21 loop
    insert into public.body_weight_logs (user_id, logged_on, weight_kg)
      values (uid, current_date - d, kg)
      on conflict (user_id, logged_on) do nothing;
    m := gen_random_uuid();
    insert into public.meals (id, user_id, meal_type, logged_at)
      values (m, uid, 'lunch', (current_date - d) + time '09:00');
    insert into public.meal_items (meal_id, name, grams, calories)
      values (m, 'G3 test', 500, 2200);
  end loop;
  update public.profiles
    set goals_changed_at = now() - interval '22 days',
        calorie_adjusted_at = null,
        calorie_suggestion_snoozed_until = null
    where user_id = uid;
end;
$$;

-- TEMİZLİK (gerekirse yorumdan çıkarıp çalıştır; kilo kayıtları için son 21 günü siler):
-- delete from public.meals where id in (select meal_id from public.meal_items where name = 'G3 test');
-- delete from public.body_weight_logs
--   where user_id = (select id from auth.users where email = 'TEST_EPOSTA@ornek.com')
--     and logged_on between current_date - 21 and current_date - 1;
