# G3 — Uyarlanabilir Kalori Hedefi Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Kilo trendi ve öğün kayıtlarından gerçek TDEE'yi tahmin edip beslenme ekranında onaylı bir kalori hedefi düzeltmesi önermek; onaylanan düzeltmeyi profilde kalıcı bir pay olarak saklamak.

**Architecture:** `profiles`'a dört sütun (pay, son uyarlama, erteleme, son hedef değişikliği). `TdeeCalculator.calculate` payı bakım kalorisine ekler; tüm hedef hesapları (tartı, ayarlar, koç) payı profilden geçirir, böylece korunur. Saf `adaptive_tdee.dart` 21 günlük pencereden öneri üretir (enerji dengesi ya da kilo trendi); `calorieSuggestionProvider` bunu beslenme ekranındaki `CalorieSuggestionCard`'a verir; yazma işleri mevcut `saveProfileChanges` ile yapılır.

**Tech Stack:** Flutter (Riverpod 3, easy_localization), Supabase (Postgres göç + mevcut koç RPC'leri), Deno (coach-chat edge function).

**Spec:** `docs/superpowers/specs/2026-10-08-g3-uyarlanabilir-kalori-design.md`

## Global Constraints

- Dal: `g3-uyarlanabilir-kalori` (açık, spec commit'li).
- Tüm `flutter` komutları `--no-pub` ile. Görevlerde yalnız ilgili test dosyaları çalıştırılır; tam paketi kullanıcı kendi terminalinde çalıştırır (`flutter test --no-pub -j 1`, Task 7). `flutter analyze --no-pub` birkaç dakika sürer (arka planda çalıştır); "No issues found!" vermeli.
- `dart format` çalıştırılmaz; mevcut biçime elle uyulur (satırlar ~120 karaktere kadar).
- Testlerde çeviriler yüklenmez (`testApp` ham anahtar gösterir); metinler `Key` ve ham anahtarlarla doğrulanır.
- Varsayılanlar (spec §2): pencere 21 gün; ≥6 kilo kaydı; ilk–son kayıt arası ≥13 gün (14 takvim günü); son değişiklikten ≥14 gün; kayıtlı gün ≥800 kcal; enerji dengesi oranı ≥0.70; öneri eşiği 100 kcal; tek öneri en çok ±250 kcal; erteleme 7 gün; 7700 kcal/kg.
- Zaman damgaları Supabase'e `DateTime.toUtc().toIso8601String()` olarak yazılır.
- Deno testleri: `deno test supabase/functions/coach-chat/`.
- Commit mesajları şu satırla biter: `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`

## Spec'ten bilinçli sapmalar (kullanıcıya bildirilecek)

1. **Taban, payın dışında hesaplanır:** `calculate` tabanı `min(formül bakımı, cinsiyet tabanı)` ile uygular (pay hariç). Böylece negatif bir pay hedefi 1500/1200'ün altına indiremez ("taban korunur"); pay yoksa sonuç bugünküyle aynı.
2. **"Mevcut hedef"** öneride `profile.dailyCalorieTarget` yerine mevcut payla formülden hesaplanır (pratikte aynı değer; yeni pay = mevcut pay + kırpılmış fark tutarlı kalsın diye).
3. **Değişiklik günü pencereye girmez:** pencere `calorie_adjusted_at` / `goals_changed_at` gününün **ertesi** gününden başlar (o günün öğünleri eski hedefle yenmiştir). Bugün de sayılmaz.
4. **Kart metni:** "{eski} → {yeni} kcal" ayrı, büyük bir satırda (yeni değer neon); gövde "Son {gün} günde … hedefin … Günlük hedefini güncelleyelim mi?". Çeviride sayıyı cümle içinde renklendirmek dil sırasına bağlı olurdu.
5. **`Profile.toJson` yeni alanları içermez:** yalnız `fromJson` okur (eksikse varsayılan); yazma her zaman açık alan haritasıyla yapılır. Onboarding upsert'i bu sütunlara dokunmaz.
6. **SQL kontrolü ayrı dosya:** `checks/g3_checks.sql` (sütun kontrolleri). `f5_rls_checks.sql` değişmez ama göçten sonra yeniden çalıştırılır (koç uygulama/geri alma akışı kırılmadı mı).
7. **`profileChanges` imzası** `currentYear` yerine `now` alır (yıl `now.year`); aktivite değişince pay her zaman `0.0` olarak yazılır.

## Dosya haritası

| Dosya | Sorumluluk |
|---|---|
| `supabase/migrations/0012_adaptive_calories.sql` (yeni) | 4 sütun; koç `chat_write_profile` / `chat_target_snapshot` / `apply_chat_action` güncellemesi |
| `supabase/migrations/checks/g3_checks.sql` (yeni) | Sütun kontrolleri |
| `supabase/migrations/checks/g3_seed_adaptive.sql` (yeni) | Elle test verisi + temizlik |
| `lib/features/onboarding/domain/profile.dart` | 4 yeni alan, `fromJson`, `copyWith` |
| `lib/features/onboarding/domain/tdee_calculator.dart` | `maintenance()`, `adjustmentKcal`, taban kuralı |
| `lib/features/settings/domain/profile_edit.dart` | `targetsFor` payı geçirir; `profileChanges(now:)`; `resetAdjustmentFields` |
| `lib/features/progress/domain/profile_weight_update.dart` | payı geçirir |
| `lib/features/chat/domain/card_data.dart` | `profileAfter` aktivitede payı 0'lar; `targetsAfter` payı geçirir |
| `lib/features/settings/presentation/goals_screen.dart`, `widgets/profile_field_sheets.dart` | `profileChanges(now:)`; Hedeflerim'de sıfırlama |
| `lib/features/nutrition/domain/adaptive_tdee.dart` (yeni) | Pencere, eğim, günlük kcal, öneri, yazma alanları |
| `lib/features/nutrition/application/calorie_suggestion_provider.dart` (yeni) | Veriyi toplayıp öneriyi üretir |
| `lib/features/nutrition/presentation/widgets/calorie_suggestion_card.dart` (yeni) | Kart + Uygula / Şimdi değil |
| `lib/features/nutrition/presentation/nutrition_screen.dart` | Kartı Kalan kartının üstüne koyar |
| `lib/features/settings/presentation/widgets/goal_summary_card.dart` | "Uyarlandı" satırı |
| `assets/translations/tr.json`, `en.json` | Yeni anahtarlar |
| `supabase/functions/coach-chat/{types,context,test_fixtures,context.test}.ts` | Pay satırı |

---

### Task 1: Göç 0012, kontroller ve örnek veri betiği

**Files:**
- Create: `supabase/migrations/0012_adaptive_calories.sql`
- Create: `supabase/migrations/checks/g3_checks.sql`
- Create: `supabase/migrations/checks/g3_seed_adaptive.sql`

**Interfaces:**
- Produces: `profiles.calorie_adjustment_kcal numeric not null default 0`, `profiles.calorie_adjusted_at timestamptz`, `profiles.calorie_suggestion_snoozed_until timestamptz`, `profiles.goals_changed_at timestamptz`. Koç `update_profile` (boy/aktivite değişince) ve `set_goal` uygularken `goals_changed_at = now()` yazar; `update_profile` aktivite içeriyorsa `calorie_adjustment_kcal = 0` yazar; anlık görüntüler bu iki alanı da içerir (geri alma geri yükler).

Bu görevde otomatik test yok: SQL'i kullanıcı Task 7'de SQL Editor'de çalıştırır ve `f5_rls_checks.sql` + `g3_checks.sql` ile doğrular.

- [ ] **Step 1: Göç dosyasının başını yaz**

`supabase/migrations/0012_adaptive_calories.sql`:

```sql
-- G3 (docs/superpowers/specs/2026-10-08-g3-uyarlanabilir-kalori-design.md §3.1):
-- uyarlanabilir kalori hedefi için profil sütunları; koç akışı bunları yazar ve
-- geri alma için anlık görüntüye katar.

alter table public.profiles
  add column calorie_adjustment_kcal numeric not null default 0,
  add column calorie_adjusted_at timestamptz,
  add column calorie_suggestion_snoozed_until timestamptz,
  add column goals_changed_at timestamptz;

-- p_fields'ta bulunan profil kolonlarını yazar (uygulama ve geri alma ortak).
create or replace function public.chat_write_profile(p_fields jsonb)
returns void
language plpgsql
security invoker
set search_path = public
as $$
begin
  update profiles set
    height_cm = case when p_fields ? 'height_cm' then (p_fields->>'height_cm')::numeric else height_cm end,
    activity_level = case when p_fields ? 'activity_level' then p_fields->>'activity_level' else activity_level end,
    does_exercise = case when p_fields ? 'does_exercise' then (p_fields->>'does_exercise')::boolean else does_exercise end,
    sport_type = case when p_fields ? 'sport_type' then p_fields->>'sport_type' else sport_type end,
    exercise_days_per_week = case when p_fields ? 'exercise_days_per_week'
                                  then (p_fields->>'exercise_days_per_week')::int else exercise_days_per_week end,
    health_notes = case when p_fields ? 'health_notes' then p_fields->>'health_notes' else health_notes end,
    weight_direction = case when p_fields ? 'weight_direction'
                            then p_fields->>'weight_direction' else weight_direction end,
    pace = case when p_fields ? 'pace' then p_fields->>'pace' else pace end,
    focuses = case when p_fields ? 'focuses'
                   then array(select jsonb_array_elements_text(p_fields->'focuses')) else focuses end,
    weight_kg = case when p_fields ? 'weight_kg' then (p_fields->>'weight_kg')::numeric else weight_kg end,
    daily_calorie_target = case when p_fields ? 'daily_calorie_target'
                                then (p_fields->>'daily_calorie_target')::numeric else daily_calorie_target end,
    daily_protein_target_g = case when p_fields ? 'daily_protein_target_g'
                                  then (p_fields->>'daily_protein_target_g')::numeric else daily_protein_target_g end,
    calorie_adjustment_kcal = case when p_fields ? 'calorie_adjustment_kcal'
                                   then (p_fields->>'calorie_adjustment_kcal')::numeric else calorie_adjustment_kcal end,
    goals_changed_at = case when p_fields ? 'goals_changed_at'
                            then (p_fields->>'goals_changed_at')::timestamptz else goals_changed_at end,
    updated_at = now()
  where user_id = auth.uid();
end;
$$;
```

- [ ] **Step 2: `chat_target_snapshot`'ı kopyalayıp anahtar listesini genişlet**

`supabase/migrations/0011_goals_redesign.sql` içindeki `create or replace function public.chat_target_snapshot` bloğunu (yorum satırları `-- Bir aracın dokunduğu verinin…` ile başlayıp `$$;` ile biten, ~satır 86–164) **olduğu gibi** 0012'nin sonuna kopyala. Yalnız şu satırı:

```sql
    keys := coalesce(keys, array[]::text[]) || array['daily_calorie_target', 'daily_protein_target_g'];
```

şununla değiştir:

```sql
    keys := coalesce(keys, array[]::text[])
      || array['daily_calorie_target', 'daily_protein_target_g', 'calorie_adjustment_kcal', 'goals_changed_at'];
```

- [ ] **Step 3: `apply_chat_action`'ı kopyalayıp iki `perform`'u değiştir**

0011'deki `-- Bekleyen öneriyi uygular…` yorumuyla başlayan `create or replace function public.apply_chat_action` bloğunu (`$$;` dahil, ~satır 165–286) **olduğu gibi** 0012'nin sonuna kopyala. Sonra:

`update_profile` dalındaki

```sql
    perform chat_write_profile((p->'changes') || targets);
```

satırını şununla değiştir:

```sql
    -- G3: boy/aktivite hedefi değiştirir → pencere yeniden başlar; aktivite payı geçersiz kılar.
    perform chat_write_profile((p->'changes') || targets
      || case when p->'changes' ?| array['height_cm', 'activity_level']
              then jsonb_build_object('goals_changed_at', now()) else '{}'::jsonb end
      || case when p->'changes' ? 'activity_level'
              then jsonb_build_object('calorie_adjustment_kcal', 0) else '{}'::jsonb end);
```

`set_goal` dalındaki

```sql
    perform chat_write_profile(jsonb_build_object(
      'weight_direction', p->'weight_direction',
      'pace', coalesce(p->'pace', 'null'::jsonb),
      'focuses', p->'focuses') || targets);
```

ifadesini şununla değiştir:

```sql
    perform chat_write_profile(jsonb_build_object(
      'weight_direction', p->'weight_direction',
      'pace', coalesce(p->'pace', 'null'::jsonb),
      'focuses', p->'focuses',
      'goals_changed_at', now()) || targets);
```

Not: Geri alma (`0010`'daki undo) `chat_write_profile(ev.before)` çağırır; anlık görüntüde artık `calorie_adjustment_kcal` ve `goals_changed_at` olduğu için onlar da geri yüklenir. Göçten önce oluşturulmuş bekleyen koç önerileri yeni anahtarlar yüzünden "stale" olur (koç sekmesi kilitli; kabul edilebilir).

- [ ] **Step 4: Kontrol betiğini yaz**

`supabase/migrations/checks/g3_checks.sql`:

```sql
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
```

- [ ] **Step 5: Örnek veri betiğini yaz**

`supabase/migrations/checks/g3_seed_adaptive.sql`:

```sql
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
```

- [ ] **Step 6: Commit**

```bash
git add supabase/migrations/0012_adaptive_calories.sql supabase/migrations/checks/g3_checks.sql supabase/migrations/checks/g3_seed_adaptive.sql
git commit -m "feat(db): add adaptive calorie columns and keep them in coach actions

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 2: Profil alanları, hesaplayıcı payı ve tüm hedef yolları

**Files:**
- Modify: `lib/features/onboarding/domain/profile.dart`
- Modify: `lib/features/onboarding/domain/tdee_calculator.dart`
- Modify: `lib/features/settings/domain/profile_edit.dart`
- Modify: `lib/features/progress/domain/profile_weight_update.dart`
- Modify: `lib/features/chat/domain/card_data.dart`
- Modify: `lib/features/settings/presentation/goals_screen.dart:94-97`
- Modify: `lib/features/settings/presentation/widgets/profile_field_sheets.dart:55-60`
- Test: `test/features/onboarding/domain/profile_test.dart`, `profile_copy_test.dart`, `tdee_calculator_test.dart`, `test/features/settings/domain/profile_edit_test.dart`, `test/features/progress/domain/profile_weight_update_test.dart`, `test/features/chat/domain/card_data_test.dart`, `test/features/settings/presentation/goals_screen_test.dart`, `settings_screen_test.dart`

**Interfaces:**
- Produces:
  - `Profile.calorieAdjustmentKcal` (double, varsayılan 0), `Profile.calorieAdjustedAt`, `Profile.calorieSuggestionSnoozedUntil`, `Profile.goalsChangedAt` (DateTime?, yerel saat); `copyWith` bu dördünü de alır.
  - `TdeeCalculator.maintenance({weightKg, heightCm, birthYear, currentYear, gender, activityLevel}) → double` (BMR × aktivite, pay yok).
  - `TdeeCalculator.calculate(..., double adjustmentKcal = 0)`.
  - `profileChanges(Profile before, Profile after, {required DateTime now, TdeeCalculator calculator})`.
  - `resetAdjustmentFields(Profile profile, {required DateTime now, TdeeCalculator calculator}) → Map<String, dynamic>`.

- [ ] **Step 1: Profil testlerini yaz**

`test/features/onboarding/domain/profile_test.dart` sonuna (main içine) ekle:

```dart
  test('Profile.fromJson reads the adaptive calorie fields and defaults them when absent', () {
    final base = {
      'user_id': 'user-3',
      'weight_kg': 80,
      'height_cm': 180,
      'birth_year': 1996,
      'gender': 'male',
      'activity_level': 'moderate',
      'does_exercise': true,
      'sport_type': null,
      'exercise_days_per_week': 3,
      'weight_direction': 'maintain',
      'pace': null,
      'focuses': <String>[],
      'health_notes': null,
      'daily_calorie_target': 2759,
      'daily_protein_target_g': 128,
    };
    final plain = Profile.fromJson(base);
    expect(plain.calorieAdjustmentKcal, 0);
    expect(plain.calorieAdjustedAt, isNull);
    expect(plain.calorieSuggestionSnoozedUntil, isNull);
    expect(plain.goalsChangedAt, isNull);

    final adapted = Profile.fromJson({
      ...base,
      'calorie_adjustment_kcal': -160,
      'calorie_adjusted_at': '2026-10-08T07:00:00+00:00',
      'calorie_suggestion_snoozed_until': '2026-10-15T07:00:00+00:00',
      'goals_changed_at': '2026-09-01T07:00:00+00:00',
    });
    expect(adapted.calorieAdjustmentKcal, -160);
    expect(adapted.calorieAdjustedAt, DateTime.utc(2026, 10, 8, 7).toLocal());
    expect(adapted.calorieSuggestionSnoozedUntil, DateTime.utc(2026, 10, 15, 7).toLocal());
    expect(adapted.goalsChangedAt, DateTime.utc(2026, 9, 1, 7).toLocal());
    expect(adapted.toJson().containsKey('calorie_adjustment_kcal'), isFalse);
  });
```

`test/features/onboarding/domain/profile_copy_test.dart` içine (main içinde, dosyadaki import'larla) ekle:

```dart
  test('copyWith keeps and replaces the adaptive calorie fields', () {
    final adapted = testProfile.copyWith(
      calorieAdjustmentKcal: -160,
      calorieAdjustedAt: DateTime(2026, 10, 8),
      calorieSuggestionSnoozedUntil: DateTime(2026, 10, 15),
      goalsChangedAt: DateTime(2026, 9, 1),
    );
    final copy = adapted.copyWith(heightCm: 181);
    expect(copy.calorieAdjustmentKcal, -160);
    expect(copy.calorieAdjustedAt, DateTime(2026, 10, 8));
    expect(copy.calorieSuggestionSnoozedUntil, DateTime(2026, 10, 15));
    expect(copy.goalsChangedAt, DateTime(2026, 9, 1));
    expect(adapted.copyWith(calorieAdjustmentKcal: 0).calorieAdjustmentKcal, 0);
  });
```

(`profile_copy_test.dart` `testProfile`'ı import etmiyorsa `import '../../progress/fixtures.dart';` ekle.)

- [ ] **Step 2: Hesaplayıcı testlerini yaz**

`test/features/onboarding/domain/tdee_calculator_test.dart` içindeki `calc` yardımcısına `double adjustmentKcal = 0` parametresi ekle ve `calculator.calculate(...)` çağrısına `adjustmentKcal: adjustmentKcal,` geçir. Sonra main içine ekle:

```dart
  test('adjustment shifts maintenance; protein is unchanged', () {
    final result = calc(adjustmentKcal: -100);
    expect(result.calorieTarget, closeTo(2036.0, 0.01));
    expect(result.proteinTargetG, closeTo(128.0, 0.01));
    expect(
      calculator.maintenance(
        weightKg: 80,
        heightCm: 180,
        birthYear: 1996,
        currentYear: 2026,
        gender: Gender.male,
        activityLevel: ActivityLevel.sedentary,
      ),
      closeTo(2136.0, 0.01),
    );
  });

  test('a negative adjustment never pushes the target below the gender floor', () {
    // Kadın, 50 kg, 160 cm, 26 yaş, hareketsiz: bakım 1450.8; yavaş verme −275 → taban 1200.
    TdeeResult female(double adjustment) => calc(
          weightKg: 50,
          heightCm: 160,
          birthYear: 2000,
          gender: Gender.female,
          weightDirection: WeightDirection.lose,
          pace: Pace.slow,
          adjustmentKcal: adjustment,
        );
    expect(female(0).calorieTarget, closeTo(1200.0, 0.01));
    expect(female(-250).calorieTarget, closeTo(1200.0, 0.01));
  });
```

- [ ] **Step 3: `profileChanges`, sıfırlama, tartı ve koç testlerini yaz**

`test/features/settings/domain/profile_edit_test.dart`'ı şu hale getir (mevcut testler korunur; `currentYear: 2026` → `now:` olur ve hedef değişiminde `goals_changed_at` beklenir):

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:spor_takip/features/onboarding/domain/profile.dart';
import 'package:spor_takip/features/onboarding/domain/tdee_calculator.dart';
import 'package:spor_takip/features/settings/domain/profile_edit.dart';

import '../../progress/fixtures.dart';

void main() {
  final now = DateTime(2026, 10, 8, 9);
  final stamp = now.toUtc().toIso8601String();
  Map<String, dynamic> changes(Profile after, {Profile before = testProfile}) =>
      profileChanges(before, after, now: now);

  test('no change gives an empty map', () {
    expect(changes(testProfile), isEmpty);
    expect(changes(testProfile.copyWith(heightCm: 180)), isEmpty);
  });

  test('a target-affecting change adds both new targets and the change time', () {
    final after = testProfile.copyWith(heightCm: 182);
    final targets = targetsFor(after, currentYear: 2026);
    expect(changes(after), {
      'height_cm': 182.0,
      'daily_calorie_target': targets.calorieTarget,
      'daily_protein_target_g': targets.proteinTargetG,
      'goals_changed_at': stamp,
    });
  });

  test('fields that do not affect the targets are written alone', () {
    expect(changes(testProfile.copyWith(healthNotes: 'Diz')), {'health_notes': 'Diz'});
    expect(
      changes(testProfile.copyWith(doesExercise: false, exerciseDaysPerWeek: 0)),
      {'does_exercise': false, 'exercise_days_per_week': 0},
    );
  });

  test('switching to maintain writes a null pace and focuses in DB order', () {
    final losing = testProfile.copyWith(weightDirection: WeightDirection.lose, pace: Pace.fast);
    final after = losing.copyWith(
      weightDirection: WeightDirection.maintain,
      clearPace: true,
      focuses: {GoalFocus.strength, GoalFocus.muscle},
    );
    final result = changes(after, before: losing);
    expect(result['weight_direction'], 'maintain');
    expect(result.containsKey('pace'), isTrue);
    expect(result['pace'], isNull);
    expect(result['focuses'], ['muscle', 'strength']);
    expect(result['daily_calorie_target'], targetsFor(after, currentYear: 2026).calorieTarget);
  });

  test('a goal change keeps the adjustment in the new target', () {
    final adapted = testProfile.copyWith(calorieAdjustmentKcal: -200);
    final after = adapted.copyWith(weightDirection: WeightDirection.lose, pace: Pace.balanced);
    final result = changes(after, before: adapted);
    expect(result.containsKey('calorie_adjustment_kcal'), isFalse);
    expect(result['daily_calorie_target'], targetsFor(after, currentYear: 2026).calorieTarget);
    expect(
      result['daily_calorie_target'],
      closeTo(targetsFor(after.copyWith(calorieAdjustmentKcal: 0), currentYear: 2026).calorieTarget - 200, 0.01),
    );
  });

  test('an activity change resets the adjustment and computes targets without it', () {
    final adapted = testProfile.copyWith(calorieAdjustmentKcal: -200);
    final after = adapted.copyWith(activityLevel: ActivityLevel.active);
    final result = changes(after, before: adapted);
    expect(result['calorie_adjustment_kcal'], 0.0);
    expect(
      result['daily_calorie_target'],
      targetsFor(after.copyWith(calorieAdjustmentKcal: 0), currentYear: 2026).calorieTarget,
    );
    expect(result['goals_changed_at'], stamp);
  });

  test('resetAdjustmentFields zeroes the adjustment and recomputes the targets', () {
    final adapted = testProfile.copyWith(calorieAdjustmentKcal: -160);
    final targets = targetsFor(testProfile, currentYear: 2026);
    expect(resetAdjustmentFields(adapted, now: now), {
      'calorie_adjustment_kcal': 0.0,
      'calorie_adjusted_at': stamp,
      'goals_changed_at': stamp,
      'daily_calorie_target': targets.calorieTarget,
      'daily_protein_target_g': targets.proteinTargetG,
    });
  });

  test('targetsFor runs the TdeeCalculator on every profile field', () {
    final expected = const TdeeCalculator().calculate(
      weightKg: 80,
      heightCm: 180,
      birthYear: 1996,
      currentYear: 2026,
      gender: Gender.male,
      activityLevel: ActivityLevel.moderate,
      weightDirection: WeightDirection.maintain,
      pace: null,
      focuses: {GoalFocus.muscle},
      adjustmentKcal: -50,
    );
    final targets = targetsFor(testProfile.copyWith(calorieAdjustmentKcal: -50), currentYear: 2026);
    expect(targets.calorieTarget, expected.calorieTarget);
    expect(targets.proteinTargetG, expected.proteinTargetG);
  });
}
```

`test/features/progress/domain/profile_weight_update_test.dart` main içine ekle (gerekirse `tdee_calculator.dart` import'u):

```dart
  test('the adjustment is kept when a new weight recomputes the targets', () {
    final update = profileWeightUpdate(testProfile.copyWith(calorieAdjustmentKcal: -150), 82, currentYear: 2026);
    final plain = profileWeightUpdate(testProfile, 82, currentYear: 2026);
    expect(update.calorieTarget, closeTo(plain.calorieTarget - 150, 0.01));
  });
```

`test/features/chat/domain/card_data_test.dart` main içine ekle:

```dart
  test('a coach activity change resets the adjustment; other tools keep it', () {
    final adapted = testProfile.copyWith(calorieAdjustmentKcal: -120);
    expect(profileAfter(adapted, profileEvent()).calorieAdjustmentKcal, 0);
    expect(profileAfter(adapted, weightEvent(kg: 82)).calorieAdjustmentKcal, -120);
    final kept = targetsAfter(adapted, weightEvent(kg: 82), currentYear: 2026)!;
    final plain = targetsAfter(testProfile, weightEvent(kg: 82), currentYear: 2026)!;
    expect(kept.calorieTarget, closeTo(plain.calorieTarget - 120, 0.01));
  });
```

- [ ] **Step 4: Testlerin başarısız olduğunu gör**

Run: `flutter test --no-pub test/features/onboarding/domain/ test/features/settings/domain/ test/features/progress/domain/profile_weight_update_test.dart test/features/chat/domain/card_data_test.dart`
Expected: FAIL — derleme hataları (`calorieAdjustmentKcal`, `maintenance`, `now`, `resetAdjustmentFields` tanımsız).

- [ ] **Step 5: `Profile`'ı genişlet**

`lib/features/onboarding/domain/profile.dart`:

Kurucuya `this.dailyProteinTargetG` satırından sonra ekle:

```dart
    this.calorieAdjustmentKcal = 0,
    this.calorieAdjustedAt,
    this.calorieSuggestionSnoozedUntil,
    this.goalsChangedAt,
```

Alanlara `final double dailyProteinTargetG;` satırından sonra ekle:

```dart

  /// Formül bakım kalorisine eklenen uyarlama payı (G3 spec §3.2). Bu dört alan
  /// `toJson`'a girmez; açık alan haritalarıyla yazılır.
  final double calorieAdjustmentKcal;
  final DateTime? calorieAdjustedAt;
  final DateTime? calorieSuggestionSnoozedUntil;

  /// Hedefi etkileyen son profil değişikliği; öneri penceresi bundan sonra başlar.
  final DateTime? goalsChangedAt;
```

`fromJson` içinde `dailyProteinTargetG: ...` satırından sonra ekle:

```dart
      calorieAdjustmentKcal: (json['calorie_adjustment_kcal'] as num?)?.toDouble() ?? 0,
      calorieAdjustedAt: _parseTime(json['calorie_adjusted_at']),
      calorieSuggestionSnoozedUntil: _parseTime(json['calorie_suggestion_snoozed_until']),
      goalsChangedAt: _parseTime(json['goals_changed_at']),
```

`copyWith` parametrelerine `Set<GoalFocus>? focuses,` satırından sonra ekle:

```dart
    double? calorieAdjustmentKcal,
    DateTime? calorieAdjustedAt,
    DateTime? calorieSuggestionSnoozedUntil,
    DateTime? goalsChangedAt,
```

ve dönen `Profile(...)` içine `dailyProteinTargetG: dailyProteinTargetG,` satırından sonra:

```dart
      calorieAdjustmentKcal: calorieAdjustmentKcal ?? this.calorieAdjustmentKcal,
      calorieAdjustedAt: calorieAdjustedAt ?? this.calorieAdjustedAt,
      calorieSuggestionSnoozedUntil: calorieSuggestionSnoozedUntil ?? this.calorieSuggestionSnoozedUntil,
      goalsChangedAt: goalsChangedAt ?? this.goalsChangedAt,
```

Dosyanın sonuna ekle:

```dart

DateTime? _parseTime(Object? value) => value == null ? null : DateTime.parse(value as String).toLocal();
```

- [ ] **Step 6: `TdeeCalculator`'ı güncelle**

`lib/features/onboarding/domain/tdee_calculator.dart` içinde `_proteinPerKg`'den önce ekle:

```dart
  /// Bakım kalorisi (BMR × aktivite), uyarlama payı hariç.
  double maintenance({
    required double weightKg,
    required double heightCm,
    required int birthYear,
    required int currentYear,
    required Gender gender,
    required ActivityLevel activityLevel,
  }) {
    final bmr = _bmr(weightKg: weightKg, heightCm: heightCm, age: currentYear - birthYear, gender: gender);
    return bmr * _activityMultipliers[activityLevel]!;
  }
```

`calculate`'i şu hale getir:

```dart
  TdeeResult calculate({
    required double weightKg,
    required double heightCm,
    required int birthYear,
    required int currentYear,
    required Gender gender,
    required ActivityLevel activityLevel,
    required WeightDirection weightDirection,
    required Pace? pace,
    required Set<GoalFocus> focuses,
    double adjustmentKcal = 0,
  }) {
    final formula = maintenance(
      weightKg: weightKg,
      heightCm: heightCm,
      birthYear: birthYear,
      currentYear: currentYear,
      gender: gender,
      activityLevel: activityLevel,
    );
    final tdee = formula + adjustmentKcal;
    final dailyDelta = weeklyChangeKg(weightKg, weightDirection, pace) * _kcalPerKg / 7;
    final signedDelta = weightDirection == WeightDirection.lose ? -dailyDelta : dailyDelta;
    final floor = gender == Gender.male ? 1500.0 : 1200.0;
    // Taban açığı ve negatif payı sınırlar ama hedefi formül bakımının üstüne çıkarmaz (G3 spec §4.1).
    final calorieTarget = math.max(tdee + signedDelta, math.min(formula, floor));
    final proteinTargetG = weightKg * _proteinPerKg(weightDirection, focuses);
    return TdeeResult(calorieTarget: calorieTarget, proteinTargetG: proteinTargetG);
  }
```

- [ ] **Step 7: `profile_edit.dart`'ı güncelle**

`targetsFor` içindeki `calculator.calculate(` çağrısına `focuses: profile.focuses,` satırından sonra `adjustmentKcal: profile.calorieAdjustmentKcal,` ekle.

`profileChanges`'i şununla değiştir:

```dart
/// [before] → [after] arasında değişen sütunlar (DB adları, `toJson` biçimi);
/// hedefi etkileyen bir sütun değiştiyse yeni hedefler ve değişiklik zamanı da eklenir.
/// Aktivite değişince uyarlama payı sıfırlanır (G3 spec §4.2). Değişiklik yoksa boş.
Map<String, dynamic> profileChanges(
  Profile before,
  Profile after, {
  required DateTime now,
  TdeeCalculator calculator = const TdeeCalculator(),
}) {
  final old = before.toJson();
  final next = after.toJson();
  final changes = <String, dynamic>{
    for (final column in _editableColumns)
      if (!_same(old[column], next[column])) column: next[column],
  };
  if (changes.keys.any(_targetColumns.contains)) {
    final activityChanged = changes.containsKey('activity_level');
    final target = activityChanged ? after.copyWith(calorieAdjustmentKcal: 0) : after;
    final targets = targetsFor(target, currentYear: now.year, calculator: calculator);
    changes['daily_calorie_target'] = targets.calorieTarget;
    changes['daily_protein_target_g'] = targets.proteinTargetG;
    changes['goals_changed_at'] = now.toUtc().toIso8601String();
    if (activityChanged) changes['calorie_adjustment_kcal'] = 0.0;
  }
  return changes;
}

/// "Uyarlamayı sıfırla" (G3 spec §5.2): pay 0, hedefler formülle, pencere yeniden başlar.
Map<String, dynamic> resetAdjustmentFields(
  Profile profile, {
  required DateTime now,
  TdeeCalculator calculator = const TdeeCalculator(),
}) {
  final targets = targetsFor(profile.copyWith(calorieAdjustmentKcal: 0), currentYear: now.year, calculator: calculator);
  final stamp = now.toUtc().toIso8601String();
  return {
    'calorie_adjustment_kcal': 0.0,
    'calorie_adjusted_at': stamp,
    'goals_changed_at': stamp,
    'daily_calorie_target': targets.calorieTarget,
    'daily_protein_target_g': targets.proteinTargetG,
  };
}
```

- [ ] **Step 8: Tartı ve koç hesaplarına payı geçir**

`lib/features/progress/domain/profile_weight_update.dart` içindeki `calculator.calculate(` çağrısına `focuses: profile.focuses,` satırından sonra `adjustmentKcal: profile.calorieAdjustmentKcal,` ekle.

`lib/features/chat/domain/card_data.dart`:
- `profileAfter`'ın `ChatTool.updateProfile` dalındaki `profile.copyWith(` çağrısına `exerciseDaysPerWeek: ...` satırından sonra ekle:

```dart
        // Aktivite değişince uyarlama payı geçersiz (G3 spec §3.1); SQL de 0 yazar.
        calorieAdjustmentKcal: activity == null ? null : 0,
```

- `targetsAfter` içindeki `calculator.calculate(` çağrısına `focuses: after.focuses,` satırından sonra `adjustmentKcal: after.calorieAdjustmentKcal,` ekle.

- [ ] **Step 9: Ekran çağrılarını `now:` imzasına geçir**

`lib/features/settings/presentation/goals_screen.dart` `build` başında:

```dart
    final now = ref.watch(nowProvider)();
    final year = now.year;
    final draft = _draft;
    final changes = profileChanges(widget.profile, draft, now: now);
```

(`targetsFor(draft, currentYear: year)` satırı aynı kalır.)

`lib/features/settings/presentation/widgets/profile_field_sheets.dart` `build` başında:

```dart
    final now = ref.watch(nowProvider)();
    final draft = widget.draft;
    final changes = draft == null
        ? const <String, dynamic>{}
        : profileChanges(widget.profile, draft, now: now);
```

(`year` başka yerde kullanılmıyorsa sil; kullanılıyorsa `final year = now.year;` olarak bırak.)

- [ ] **Step 10: Ekran testlerinin beklentilerini güncelle**

`test/features/settings/presentation/goals_screen_test.dart` → `'save writes the goal and the new targets'` testindeki beklenen haritaya ekle:

```dart
      'goals_changed_at': DateTime(2026, 10, 7, 9).toUtc().toIso8601String(),
```

`test/features/settings/presentation/settings_screen_test.dart` → `'editing the height previews and saves the new targets'` testindeki beklenen haritaya aynı satırı ekle. Dosyada hedef yazan başka `repo.updates.single` / `repo.updates` beklentileri varsa (ör. cinsiyet, doğum yılı, aktivite sayfaları) her birine `goals_changed_at` ekle; aktivite değişikliği beklentisine ayrıca `'calorie_adjustment_kcal': 0.0` ekle. Kontrol: `grep -n "daily_calorie_target" test/features/settings/presentation/*.dart`.

- [ ] **Step 11: Testlerin geçtiğini gör**

Run: `flutter test --no-pub test/features/onboarding/domain/ test/features/settings/ test/features/progress/domain/profile_weight_update_test.dart test/features/chat/domain/card_data_test.dart`
Expected: PASS (hepsi).

- [ ] **Step 12: Analiz**

Run: `flutter analyze --no-pub` (arka planda)
Expected: `No issues found!`

- [ ] **Step 13: Commit**

```bash
git add lib/features/onboarding/domain/profile.dart lib/features/onboarding/domain/tdee_calculator.dart lib/features/settings/domain/profile_edit.dart lib/features/progress/domain/profile_weight_update.dart lib/features/chat/domain/card_data.dart lib/features/settings/presentation/goals_screen.dart lib/features/settings/presentation/widgets/profile_field_sheets.dart test/
git commit -m "feat(goals): carry a calorie adjustment through every target calculation

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 3: Öneri algoritması (`adaptive_tdee.dart`)

**Files:**
- Create: `lib/features/nutrition/domain/adaptive_tdee.dart`
- Test: `test/features/nutrition/domain/adaptive_tdee_test.dart`

**Interfaces:**
- Consumes: `Profile` alanları (Task 2), `TdeeCalculator.maintenance` / `calculate(adjustmentKcal:)`, `weeklyChangeKg`, `ValuePoint` (`progress/domain/trend.dart`), `dateOnly` (`progress/domain/progress_format.dart`), `sumMealMacros` (`nutrition/domain/macro_totals.dart`).
- Produces:
  - `enum SuggestionMethod { energyBalance, weightTrend }`
  - `class CalorieSuggestion { method, windowDays (int), currentTarget, newTarget, newProteinTargetG, newAdjustmentKcal, observedWeeklyKg, expectedWeeklyKg }` (double'lar; haftalık kg işaretli)
  - `const suggestionWindowDays = 21`
  - `DateTime suggestionWindowStart(Profile profile, DateTime now)`
  - `Map<DateTime, double> dailyCalories(List<Meal> meals)`
  - `double? weightSlopeKgPerDay(List<ValuePoint> points)`
  - `CalorieSuggestion? suggestCalorieAdjustment({required Profile profile, required List<ValuePoint> weights, required Map<DateTime, double> dailyKcal, required DateTime now, TdeeCalculator calculator})`
  - `Map<String, dynamic> applySuggestionFields(CalorieSuggestion s, DateTime now)`
  - `Map<String, dynamic> snoozeSuggestionFields(DateTime now)`

- [ ] **Step 1: Testleri yaz**

`test/features/nutrition/domain/adaptive_tdee_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:spor_takip/features/nutrition/domain/adaptive_tdee.dart';
import 'package:spor_takip/features/nutrition/domain/food_item.dart';
import 'package:spor_takip/features/nutrition/domain/meal.dart';
import 'package:spor_takip/features/nutrition/domain/meal_type.dart';
import 'package:spor_takip/features/onboarding/domain/profile.dart';
import 'package:spor_takip/features/progress/domain/trend.dart';

import '../../progress/fixtures.dart';

void main() {
  // testProfile: erkek, 80 kg, 180 cm, 1996 doğumlu, orta aktivite → bakım 2759 kcal.
  // Koruma 2759; dengeli verme −660 → 2099; dengeli alma +308 → 3067.
  final now = DateTime(2026, 10, 22, 10);
  final maintaining = testProfile;
  final losing = testProfile.copyWith(weightDirection: WeightDirection.lose, pace: Pace.balanced);
  final gaining = testProfile.copyWith(weightDirection: WeightDirection.gain, pace: Pace.balanced);

  /// 1 Ekim'den itibaren [days] gün, her gün bir kayıt.
  List<ValuePoint> weights({int days = 22, double Function(int day)? kg}) =>
      [for (var i = 0; i < days; i++) ValuePoint(DateTime(2026, 10, 1 + i), kg == null ? 80 : kg(i))];

  /// 1–21 Ekim (bugün hariç) her güne [kcal].
  Map<DateTime, double> eating(double Function(int day) kcal) =>
      {for (var i = 0; i < 21; i++) DateTime(2026, 10, 1 + i): kcal(i)};

  CalorieSuggestion? suggest(Profile profile, {List<ValuePoint>? points, Map<DateTime, double> kcal = const {}}) =>
      suggestCalorieAdjustment(profile: profile, weights: points ?? weights(), dailyKcal: kcal, now: now);

  group('weightSlopeKgPerDay', () {
    test('fits a least-squares line', () {
      expect(weightSlopeKgPerDay(weights(days: 21, kg: (i) => 80 - 0.05 * i)), closeTo(-0.05, 1e-9));
    });

    test('needs at least 6 logs spread over 14 calendar days', () {
      expect(weightSlopeKgPerDay(weights(days: 5)), isNull);
      expect(weightSlopeKgPerDay(weights(days: 13)), isNull);
      expect(weightSlopeKgPerDay(weights(days: 14)), 0);
      final sparse = [for (final day in [1, 4, 7, 10, 12, 14]) ValuePoint(DateTime(2026, 10, day), 80.0)];
      expect(weightSlopeKgPerDay(sparse), 0);
    });
  });

  group('suggestionWindowStart', () {
    test('is 21 days back, or the day after the latest target change', () {
      expect(suggestionWindowStart(maintaining, now), DateTime(2026, 10, 1));
      final adjusted = maintaining.copyWith(calorieAdjustedAt: DateTime(2026, 10, 5, 18));
      expect(suggestionWindowStart(adjusted, now), DateTime(2026, 10, 6));
      final both = adjusted.copyWith(goalsChangedAt: DateTime(2026, 10, 7, 8));
      expect(suggestionWindowStart(both, now), DateTime(2026, 10, 8));
      final old = maintaining.copyWith(goalsChangedAt: DateTime(2026, 8, 1));
      expect(suggestionWindowStart(old, now), DateTime(2026, 10, 1));
    });
  });

  test('dailyCalories sums meals per local day', () {
    Meal meal(DateTime at, double kcal) => Meal(
          id: '$at',
          userId: 'user-1',
          mealType: MealType.lunch,
          loggedAt: at,
          items: [FoodItem(name: 'x', grams: 100, calories: kcal)],
        );
    final totals = dailyCalories([
      meal(DateTime(2026, 10, 1, 8), 500),
      meal(DateTime(2026, 10, 1, 20), 700),
      meal(DateTime(2026, 10, 2, 13), 900),
    ]);
    expect(totals, {DateTime(2026, 10, 1): 1200.0, DateTime(2026, 10, 2): 900.0});
  });

  group('suggestCalorieAdjustment', () {
    test('energy balance: eating 2500 at a stable weight lowers maintenance, capped at 250', () {
      final s = suggest(maintaining, kcal: eating((_) => 2500))!;
      expect(s.method, SuggestionMethod.energyBalance);
      expect(s.windowDays, 21);
      expect(s.currentTarget, closeTo(2759, 0.01));
      expect(s.newTarget, closeTo(2509, 0.01));
      expect(s.newAdjustmentKcal, closeTo(-250, 0.01));
      expect(s.observedWeeklyKg, closeTo(0, 1e-9));
      expect(s.expectedWeeklyKg, 0);
      expect(s.newProteinTargetG, closeTo(80 * 2.0, 0.01));
    });

    test('energy balance counts the weight change: gaining 0.14 kg/week on 2500', () {
      final s = suggest(maintaining, points: weights(kg: (i) => 80 + 0.02 * i), kcal: eating((_) => 2500))!;
      expect(s.observedWeeklyKg, closeTo(0.14, 1e-9));
      expect(s.newTarget, closeTo(2509, 0.01));
    });

    test('no suggestion when the difference is under 100 kcal', () {
      expect(suggest(maintaining, kcal: eating((_) => 2700)), isNull);
      expect(suggest(maintaining), isNull); // trend: kilo sabit, hedef koru
    });

    test('weight trend: losing nothing on a 0.6 kg/week goal lowers the target by 250', () {
      final s = suggest(losing)!;
      expect(s.method, SuggestionMethod.weightTrend);
      expect(s.currentTarget, closeTo(2099, 0.01));
      expect(s.newTarget, closeTo(1849, 0.01));
      expect(s.newAdjustmentKcal, closeTo(-250, 0.01));
      expect(s.expectedWeeklyKg, closeTo(-0.6, 1e-9));
    });

    test('weight trend: gaining nothing on a 0.28 kg/week goal raises the target by 250', () {
      final s = suggest(gaining)!;
      expect(s.method, SuggestionMethod.weightTrend);
      expect(s.currentTarget, closeTo(3067, 0.01));
      expect(s.newTarget, closeTo(3317, 0.01));
      expect(s.expectedWeeklyKg, closeTo(0.28, 1e-9));
    });

    test('the adjustment builds on the current one', () {
      final s = suggest(losing.copyWith(calorieAdjustmentKcal: -100))!;
      expect(s.currentTarget, closeTo(1999, 0.01));
      expect(s.newAdjustmentKcal, closeTo(-350, 0.01));
      expect(s.newTarget, closeTo(1749, 0.01));
    });

    test('energy balance needs 70% of the window days logged with at least 800 kcal; today is ignored', () {
      final fourteen = eating((i) => i < 14 ? 2500 : 500);
      expect(suggest(losing, kcal: fourteen)!.method, SuggestionMethod.weightTrend);
      final fifteen = eating((i) => i < 15 ? 2500 : 500);
      expect(suggest(losing, kcal: fifteen)!.method, SuggestionMethod.energyBalance);
      final todayOnly = {...eating((_) => 500), DateTime(2026, 10, 22): 50000.0};
      expect(suggest(losing, kcal: todayOnly)!.method, SuggestionMethod.weightTrend);
    });

    test('no suggestion without enough data or time since the last change', () {
      expect(suggest(losing, points: weights(days: 5)), isNull);
      expect(suggest(losing.copyWith(goalsChangedAt: DateTime(2026, 10, 12, 10))), isNull);
      expect(suggest(losing.copyWith(calorieAdjustedAt: DateTime(2026, 10, 8))), isNull);
      expect(suggest(losing.copyWith(calorieAdjustedAt: DateTime(2026, 10, 7))), isNotNull);
    });

    test('a snooze hides the suggestion until it ends', () {
      expect(suggest(losing.copyWith(calorieSuggestionSnoozedUntil: DateTime(2026, 10, 25))), isNull);
      expect(suggest(losing.copyWith(calorieSuggestionSnoozedUntil: DateTime(2026, 10, 20))), isNotNull);
    });

    test('never suggests below the gender floor', () {
      // Kadın, 50 kg, 160 cm, hareketsiz, yavaş verme → hedef zaten taban 1200.
      final floor = losing.copyWith(
        weightKg: 50,
        heightCm: 160,
        birthYear: 2000,
        gender: Gender.female,
        activityLevel: ActivityLevel.sedentary,
        pace: Pace.slow,
      );
      expect(suggest(floor, points: weights(kg: (_) => 50)), isNull);
    });
  });

  test('apply and snooze write the expected columns', () {
    final s = suggest(losing)!;
    final at = DateTime(2026, 10, 22, 10);
    expect(applySuggestionFields(s, at), {
      'calorie_adjustment_kcal': s.newAdjustmentKcal,
      'calorie_adjusted_at': at.toUtc().toIso8601String(),
      'daily_calorie_target': s.newTarget,
      'daily_protein_target_g': s.newProteinTargetG,
    });
    expect(snoozeSuggestionFields(at), {
      'calorie_suggestion_snoozed_until': DateTime(2026, 10, 29, 10).toUtc().toIso8601String(),
    });
  });
}
```

- [ ] **Step 2: Testlerin başarısız olduğunu gör**

Run: `flutter test --no-pub test/features/nutrition/domain/adaptive_tdee_test.dart`
Expected: FAIL — `adaptive_tdee.dart` yok.

- [ ] **Step 3: Uygula**

`lib/features/nutrition/domain/adaptive_tdee.dart`:

```dart
import '../../onboarding/domain/profile.dart';
import '../../onboarding/domain/tdee_calculator.dart';
import '../../progress/domain/progress_format.dart';
import '../../progress/domain/trend.dart';
import 'macro_totals.dart';
import 'meal.dart';

/// Uyarlanabilir kalori varsayılanları (G3 spec §2).
const suggestionWindowDays = 21;
const _minWindowDays = 14;
const _minWeightLogs = 6;
const _minWeightSpanDays = 13; // ilk–son kayıt arası; 14 takvim günü
const _loggedDayMinKcal = 800.0;
const _energyBalanceMinRatio = 0.7;
const _minSuggestionKcal = 100.0;
const _maxSuggestionKcal = 250.0;
const _snoozeDays = 7;
const _kcalPerKg = 7700.0;

enum SuggestionMethod { energyBalance, weightTrend }

/// Kullanıcıya sunulan hedef düzeltmesi.
class CalorieSuggestion {
  const CalorieSuggestion({
    required this.method,
    required this.windowDays,
    required this.currentTarget,
    required this.newTarget,
    required this.newProteinTargetG,
    required this.newAdjustmentKcal,
    required this.observedWeeklyKg,
    required this.expectedWeeklyKg,
  });

  final SuggestionMethod method;

  /// Değerlendirilen gün sayısı (pencere başı → bugün, bugün hariç).
  final int windowDays;
  final double currentTarget;
  final double newTarget;
  final double newProteinTargetG;
  final double newAdjustmentKcal;

  /// İşaretli: kilo verirken negatif.
  final double observedWeeklyKg;
  final double expectedWeeklyKg;
}

/// Yaz saati geçişlerinde de doğru gün farkı.
int _daysBetween(DateTime from, DateTime to) => (dateOnly(to).difference(dateOnly(from)).inHours / 24).round();

/// Pencerenin ilk günü: 21 gün önce ya da son hedef değişikliğinin ertesi günü (hangisi yeniyse).
DateTime suggestionWindowStart(Profile profile, DateTime now) {
  final today = dateOnly(now);
  var start = DateTime(today.year, today.month, today.day - suggestionWindowDays);
  for (final changed in [profile.calorieAdjustedAt, profile.goalsChangedAt]) {
    if (changed == null) continue;
    final next = DateTime(changed.year, changed.month, changed.day + 1);
    if (next.isAfter(start)) start = next;
  }
  return start;
}

/// Yerel gün → o gün yenen kcal.
Map<DateTime, double> dailyCalories(List<Meal> meals) {
  final totals = <DateTime, double>{};
  for (final meal in meals) {
    final day = dateOnly(meal.loggedAt.toLocal());
    totals[day] = (totals[day] ?? 0) + sumMealMacros([meal]).calories;
  }
  return totals;
}

/// [points] eskiden yeniye; en küçük kareler eğimi (kg/gün). Az veri → null.
double? weightSlopeKgPerDay(List<ValuePoint> points) {
  if (points.length < _minWeightLogs) return null;
  final first = points.first.date;
  if (_daysBetween(first, points.last.date) < _minWeightSpanDays) return null;
  final xs = [for (final p in points) _daysBetween(first, p.date).toDouble()];
  final meanX = xs.reduce((a, b) => a + b) / xs.length;
  final meanY = points.map((p) => p.value).reduce((a, b) => a + b) / points.length;
  var covariance = 0.0;
  var variance = 0.0;
  for (var i = 0; i < points.length; i++) {
    covariance += (xs[i] - meanX) * (points[i].value - meanY);
    variance += (xs[i] - meanX) * (xs[i] - meanX);
  }
  return variance == 0 ? null : covariance / variance;
}

/// G3 spec §4.3. Öneri yoksa (erteleme, az veri, küçük fark) null.
CalorieSuggestion? suggestCalorieAdjustment({
  required Profile profile,
  required List<ValuePoint> weights,
  required Map<DateTime, double> dailyKcal,
  required DateTime now,
  TdeeCalculator calculator = const TdeeCalculator(),
}) {
  final snoozedUntil = profile.calorieSuggestionSnoozedUntil;
  if (snoozedUntil != null && snoozedUntil.isAfter(now)) return null;

  final today = dateOnly(now);
  final start = suggestionWindowStart(profile, now);
  final windowDays = _daysBetween(start, today);
  if (windowDays < _minWindowDays) return null;

  final slope = weightSlopeKgPerDay([
    for (final p in weights)
      if (!p.date.isBefore(start) && !p.date.isAfter(today)) p,
  ]);
  if (slope == null) return null;

  final logged = [
    for (var i = 0; i < windowDays; i++)
      if ((dailyKcal[DateTime(start.year, start.month, start.day + i)] ?? 0) >= _loggedDayMinKcal)
        dailyKcal[DateTime(start.year, start.month, start.day + i)]!,
  ];
  final method = logged.length >= windowDays * _energyBalanceMinRatio
      ? SuggestionMethod.energyBalance
      : SuggestionMethod.weightTrend;

  TdeeResult targets(double adjustment) => calculator.calculate(
        weightKg: profile.weightKg,
        heightCm: profile.heightCm,
        birthYear: profile.birthYear,
        currentYear: now.year,
        gender: profile.gender,
        activityLevel: profile.activityLevel,
        weightDirection: profile.weightDirection,
        pace: profile.pace,
        focuses: profile.focuses,
        adjustmentKcal: adjustment,
      );

  final weekly = weeklyChangeKg(profile.weightKg, profile.weightDirection, profile.pace);
  final expectedWeeklyKg = profile.weightDirection == WeightDirection.lose ? -weekly : weekly;
  final currentAdjustment = profile.calorieAdjustmentKcal;

  final double rawAdjustment;
  if (method == SuggestionMethod.energyBalance) {
    final averageIntake = logged.reduce((a, b) => a + b) / logged.length;
    final observedTdee = averageIntake - slope * _kcalPerKg;
    final formula = calculator.maintenance(
      weightKg: profile.weightKg,
      heightCm: profile.heightCm,
      birthYear: profile.birthYear,
      currentYear: now.year,
      gender: profile.gender,
      activityLevel: profile.activityLevel,
    );
    rawAdjustment = observedTdee - formula;
  } else {
    rawAdjustment = currentAdjustment - (slope - expectedWeeklyKg / 7) * _kcalPerKg;
  }

  final currentTarget = targets(currentAdjustment).calorieTarget;
  final delta = (targets(rawAdjustment).calorieTarget - currentTarget).clamp(-_maxSuggestionKcal, _maxSuggestionKcal);
  if (delta.abs() < _minSuggestionKcal) return null;

  final newAdjustment = currentAdjustment + delta;
  final next = targets(newAdjustment);
  if ((next.calorieTarget - currentTarget).abs() < _minSuggestionKcal) return null;

  return CalorieSuggestion(
    method: method,
    windowDays: windowDays,
    currentTarget: currentTarget,
    newTarget: next.calorieTarget,
    newProteinTargetG: next.proteinTargetG,
    newAdjustmentKcal: newAdjustment,
    observedWeeklyKg: slope * 7,
    expectedWeeklyKg: expectedWeeklyKg,
  );
}

/// "Uygula": payı, zamanı ve yeni hedefleri yazar.
Map<String, dynamic> applySuggestionFields(CalorieSuggestion suggestion, DateTime now) => {
      'calorie_adjustment_kcal': suggestion.newAdjustmentKcal,
      'calorie_adjusted_at': now.toUtc().toIso8601String(),
      'daily_calorie_target': suggestion.newTarget,
      'daily_protein_target_g': suggestion.newProteinTargetG,
    };

/// "Şimdi değil": öneriyi 7 gün gizler.
Map<String, dynamic> snoozeSuggestionFields(DateTime now) => {
      'calorie_suggestion_snoozed_until': now.add(const Duration(days: _snoozeDays)).toUtc().toIso8601String(),
    };
```

- [ ] **Step 4: Testlerin geçtiğini gör**

Run: `flutter test --no-pub test/features/nutrition/domain/adaptive_tdee_test.dart`
Expected: PASS. (Bir sayı tutmazsa hesabı testteki yorumdaki değerlerle elle doğrula: bakım 1780 × 1.55 = 2759; verme farkı 80 × 0.0075 × 7700 / 7 = 660; alma farkı 80 × 0.0035 × 1100 = 308.)

- [ ] **Step 5: Commit**

```bash
git add lib/features/nutrition/domain/adaptive_tdee.dart test/features/nutrition/domain/adaptive_tdee_test.dart
git commit -m "feat(nutrition): estimate a calorie target correction from weight trend and intake

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 4: Sağlayıcı, öneri kartı ve beslenme ekranı

**Files:**
- Create: `lib/features/nutrition/application/calorie_suggestion_provider.dart`
- Create: `lib/features/nutrition/presentation/widgets/calorie_suggestion_card.dart`
- Modify: `lib/features/nutrition/presentation/nutrition_screen.dart`
- Modify: `assets/translations/tr.json`, `assets/translations/en.json` (`nutrition` nesnesi)
- Test: `test/features/nutrition/presentation/widgets/calorie_suggestion_card_test.dart` (yeni), `test/features/nutrition/presentation/nutrition_screen_test.dart`, `test/features/nutrition/application/calorie_suggestion_provider_test.dart` (yeni)

**Interfaces:**
- Consumes: Task 3'teki tüm `adaptive_tdee.dart` API'si; `saveProfileChanges(WidgetRef, Map)` (`settings/application/profile_saver.dart`); `profileProvider`, `weightLogsProvider`, `progressDataRepositoryProvider`, `nowProvider`.
- Produces: `calorieSuggestionProvider` (`FutureProvider.autoDispose<CalorieSuggestion?>`); `CalorieSuggestionCard({required CalorieSuggestion suggestion})` — anahtarlar `calorie_suggestion_card`, `suggestion_body`, `suggestion_targets`, `suggestion_method`, `suggestion_snooze_button`, `suggestion_apply_button`.

- [ ] **Step 1: Çevirileri ekle**

`assets/translations/tr.json` içindeki `"nutrition"` nesnesine (son anahtardan sonra, virgüle dikkat) ekle:

```json
    "suggestion_title": "HEDEFİNİ GÜNCELLE",
    "suggestion_lost": "Son {days} günde haftada {kg} kg verdin",
    "suggestion_gained": "Son {days} günde haftada {kg} kg aldın",
    "suggestion_stable": "Son {days} günde kilon sabit kaldı",
    "suggestion_goal_lose": "hedefin haftada {kg} kg vermek.",
    "suggestion_goal_gain": "hedefin haftada {kg} kg almak.",
    "suggestion_goal_maintain": "hedefin kilonu korumak.",
    "suggestion_question": "Günlük hedefini güncelleyelim mi?",
    "suggestion_method_energy": "Öğün kayıtların ve kilo trendinle hesaplandı",
    "suggestion_method_trend": "Kilo trendinle hesaplandı (öğün kaydı az)",
    "suggestion_snooze": "Şimdi değil",
    "suggestion_apply": "Uygula",
    "suggestion_applied": "Hedef {kcal} kcal oldu"
```

`assets/translations/en.json` `"nutrition"` nesnesine:

```json
    "suggestion_title": "UPDATE YOUR TARGET",
    "suggestion_lost": "In the last {days} days you lost {kg} kg a week",
    "suggestion_gained": "In the last {days} days you gained {kg} kg a week",
    "suggestion_stable": "In the last {days} days your weight held steady",
    "suggestion_goal_lose": "your goal is to lose {kg} kg a week.",
    "suggestion_goal_gain": "your goal is to gain {kg} kg a week.",
    "suggestion_goal_maintain": "your goal is to maintain.",
    "suggestion_question": "Update your daily target?",
    "suggestion_method_energy": "Based on your meal logs and weight trend",
    "suggestion_method_trend": "Based on your weight trend (few meal logs)",
    "suggestion_snooze": "Not now",
    "suggestion_apply": "Apply",
    "suggestion_applied": "Target is now {kcal} kcal"
```

Doğrula: `python -c "import json;[json.load(open(f'assets/translations/{l}.json',encoding='utf-8')) for l in ('tr','en')]"` hata vermemeli.

- [ ] **Step 2: Kart testlerini yaz**

`test/features/nutrition/presentation/widgets/calorie_suggestion_card_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spor_takip/features/nutrition/domain/adaptive_tdee.dart';
import 'package:spor_takip/features/nutrition/presentation/widgets/calorie_suggestion_card.dart';
import 'package:spor_takip/features/onboarding/application/auth_providers.dart';
import 'package:spor_takip/features/onboarding/application/profile_providers.dart';
import 'package:spor_takip/features/workout/application/session_providers.dart';

import '../../../progress/presentation/test_app.dart';
import '../../../settings/fakes.dart';

void main() {
  setUpAll(initTestLocalization);

  final now = DateTime(2026, 10, 22, 10);
  const suggestion = CalorieSuggestion(
    method: SuggestionMethod.weightTrend,
    windowDays: 21,
    currentTarget: 2099.4,
    newTarget: 1849.4,
    newProteinTargetG: 176,
    newAdjustmentKcal: -250,
    observedWeeklyKg: -0.21,
    expectedWeeklyKg: -0.6,
  );
  late FakeProfileRepository repo;

  setUp(() => repo = FakeProfileRepository());

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(testApp(
      const CalorieSuggestionCard(suggestion: suggestion),
      overrides: [
        profileRepositoryProvider.overrideWithValue(repo),
        authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
        nowProvider.overrideWithValue(() => now),
      ],
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('shows the change, the targets and the method', (tester) async {
    await pump(tester);
    expect(find.byKey(const Key('calorie_suggestion_card')), findsOneWidget);
    expect(find.text('2099 → 1849 kcal'), findsOneWidget);
    expect(tester.widget<Text>(find.byKey(const Key('suggestion_method'))).data, 'nutrition.suggestion_method_trend');
    final body = tester.widget<Text>(find.byKey(const Key('suggestion_body'))).data!;
    expect(body, startsWith('nutrition.suggestion_lost'));
    expect(body, contains('nutrition.suggestion_goal_lose'));
  });

  testWidgets('apply writes the adjustment and the new targets', (tester) async {
    await pump(tester);
    await tester.tap(find.byKey(const Key('suggestion_apply_button')));
    await tester.pumpAndSettle();
    expect(repo.updates.single, applySuggestionFields(suggestion, now));
    expect(find.text('nutrition.suggestion_applied'), findsOneWidget);
  });

  testWidgets('not now snoozes for a week', (tester) async {
    await pump(tester);
    await tester.tap(find.byKey(const Key('suggestion_snooze_button')));
    await tester.pumpAndSettle();
    expect(repo.updates.single, snoozeSuggestionFields(now));
  });

  testWidgets('a failed write keeps the card and shows an error', (tester) async {
    repo.error = Exception('offline');
    await pump(tester);
    await tester.tap(find.byKey(const Key('suggestion_apply_button')));
    await tester.pumpAndSettle();
    expect(find.text('settings.save_error'), findsOneWidget);
    expect(find.byKey(const Key('calorie_suggestion_card')), findsOneWidget);
  });
}
```

Not: testlerde çeviri yüklenmediği için `'…'.tr(namedArgs: …)` ham anahtarı döndürür; gövde "anahtar, anahtar anahtar" biçimindedir.

- [ ] **Step 3: Sağlayıcı testini yaz**

`test/features/nutrition/application/calorie_suggestion_provider_test.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spor_takip/features/nutrition/application/calorie_suggestion_provider.dart';
import 'package:spor_takip/features/nutrition/domain/adaptive_tdee.dart';
import 'package:spor_takip/features/onboarding/application/profile_providers.dart';
import 'package:spor_takip/features/onboarding/domain/profile.dart';
import 'package:spor_takip/features/progress/application/progress_providers.dart';
import 'package:spor_takip/features/progress/domain/body_weight_log.dart';
import 'package:spor_takip/features/workout/application/session_providers.dart';

import '../../progress/fakes.dart';
import '../../progress/fixtures.dart';

void main() {
  test('combines profile, weight logs and meals into a suggestion', () async {
    final container = ProviderContainer(
      retry: (retryCount, error) => null,
      overrides: [
        profileProvider.overrideWith(
          (ref) async => testProfile.copyWith(weightDirection: WeightDirection.lose, pace: Pace.balanced),
        ),
        weightLogsProvider.overrideWith((ref) async => [
              for (var i = 0; i < 22; i++) BodyWeightLog(date: DateTime(2026, 10, 1 + i), weightKg: 80),
            ]),
        progressDataRepositoryProvider.overrideWithValue(FakeProgressDataRepository()),
        nowProvider.overrideWithValue(() => DateTime(2026, 10, 22, 10)),
      ],
    );
    addTearDown(container.dispose);

    final suggestion = await container.read(calorieSuggestionProvider.future);
    expect(suggestion, isNotNull);
    expect(suggestion!.method, SuggestionMethod.weightTrend);
    expect(suggestion.newTarget, closeTo(1849, 0.01));
  });

  test('no profile gives no suggestion', () async {
    final container = ProviderContainer(
      retry: (retryCount, error) => null,
      overrides: [
        profileProvider.overrideWith((ref) async => null),
        weightLogsProvider.overrideWith((ref) async => const []),
        progressDataRepositoryProvider.overrideWithValue(FakeProgressDataRepository()),
        nowProvider.overrideWithValue(() => DateTime(2026, 10, 22, 10)),
      ],
    );
    addTearDown(container.dispose);
    expect(await container.read(calorieSuggestionProvider.future), isNull);
  });
}
```

`FakeProgressDataRepository()` öğünsüz kurulur (`meals` boş), bu yüzden yöntem `weightTrend` olur.

- [ ] **Step 4: Beslenme ekranı testlerini güncelle**

`test/features/nutrition/presentation/nutrition_screen_test.dart`:
- Import'lara ekle:

```dart
import 'package:spor_takip/features/nutrition/application/calorie_suggestion_provider.dart';
import 'package:spor_takip/features/nutrition/domain/adaptive_tdee.dart';
```

- `wrap` imzasını `Widget wrap(Widget child, {required List<Meal> meals, CalorieSuggestion? suggestion})` yap ve `overrides` listesine ekle:

```dart
          calorieSuggestionProvider.overrideWith((ref) async => suggestion),
```

- Yeni test ekle:

```dart
  testWidgets('shows the calorie suggestion above the remaining card', (tester) async {
    const suggestion = CalorieSuggestion(
      method: SuggestionMethod.energyBalance,
      windowDays: 21,
      currentTarget: 2500,
      newTarget: 2300,
      newProteinTargetG: 150,
      newAdjustmentKcal: -200,
      observedWeeklyKg: 0.1,
      expectedWeeklyKg: 0,
    );
    await tester.pumpWidget(wrap(const NutritionScreen(), meals: const [], suggestion: suggestion));
    await tester.pumpAndSettle();

    final card = find.byKey(const Key('calorie_suggestion_card'));
    expect(card, findsOneWidget);
    expect(
      tester.getTopLeft(card).dy,
      lessThan(tester.getTopLeft(find.byKey(const Key('remaining_calories_card'))).dy),
    );
  });

  testWidgets('without a suggestion there is no card', (tester) async {
    await tester.pumpWidget(wrap(const NutritionScreen(), meals: const []));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('calorie_suggestion_card')), findsNothing);
  });
```

- [ ] **Step 5: Testlerin başarısız olduğunu gör**

Run: `flutter test --no-pub test/features/nutrition/`
Expected: FAIL — `calorie_suggestion_provider.dart` / `calorie_suggestion_card.dart` yok.

- [ ] **Step 6: Sağlayıcıyı yaz**

`lib/features/nutrition/application/calorie_suggestion_provider.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../onboarding/application/profile_providers.dart';
import '../../progress/application/progress_providers.dart';
import '../../progress/domain/progress_format.dart';
import '../../progress/domain/trend.dart';
import '../../workout/application/session_providers.dart';
import '../domain/adaptive_tdee.dart';

/// Beslenme ekranındaki hedef düzeltme önerisi (G3 spec §4.4). Profil yenilenince
/// (uygula / ertele / hedef değişimi) ve kilo kaydında kendiliğinden yeniden hesaplanır.
final calorieSuggestionProvider = FutureProvider.autoDispose<CalorieSuggestion?>((ref) async {
  final now = ref.watch(nowProvider)();
  final today = dateOnly(now);
  final repo = ref.watch(progressDataRepositoryProvider);
  final (profile, logs, meals) = await (
    ref.watch(profileProvider.future),
    ref.watch(weightLogsProvider.future),
    repo.fetchMeals(from: DateTime(today.year, today.month, today.day - suggestionWindowDays), to: today),
  ).wait;
  if (profile == null) return null;
  return suggestCalorieAdjustment(
    profile: profile,
    weights: [for (final log in logs) ValuePoint(log.date, log.weightKg)],
    dailyKcal: dailyCalories(meals),
    now: now,
  );
});
```

- [ ] **Step 7: Kartı yaz**

`lib/features/nutrition/presentation/widgets/calorie_suggestion_card.dart`:

```dart
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_fonts.dart';
import '../../../progress/domain/progress_format.dart';
import '../../../settings/application/profile_saver.dart';
import '../../../workout/application/session_providers.dart';
import '../../domain/adaptive_tdee.dart';

/// Haftalık değişim bu eşiğin altındaysa "sabit" sayılır.
const _stableKg = 0.05;

/// Hedef düzeltme önerisi (G3 spec §5.1): neon sol kenar, eski → yeni hedef, yöntem,
/// "Şimdi değil" / "Uygula".
class CalorieSuggestionCard extends ConsumerStatefulWidget {
  const CalorieSuggestionCard({super.key, required this.suggestion});

  final CalorieSuggestion suggestion;

  @override
  ConsumerState<CalorieSuggestionCard> createState() => _CalorieSuggestionCardState();
}

class _CalorieSuggestionCardState extends ConsumerState<CalorieSuggestionCard> {
  bool _busy = false;

  Future<void> _write(Map<String, dynamic> fields, {String? successMessage}) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    final ok = await saveProfileChanges(ref, fields);
    // Başarıda profil yenilenir ve kart kaybolabilir; mesaj yine gösterilir.
    if (mounted) setState(() => _busy = false);
    final message = ok ? successMessage : 'settings.save_error'.tr();
    if (message != null) messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  String _body() {
    final s = widget.suggestion;
    final days = s.windowDays.toString();
    final observed = s.observedWeeklyKg;
    final change = observed <= -_stableKg
        ? 'nutrition.suggestion_lost'.tr(namedArgs: {'days': days, 'kg': formatOneDecimal(observed.abs())})
        : observed >= _stableKg
            ? 'nutrition.suggestion_gained'.tr(namedArgs: {'days': days, 'kg': formatOneDecimal(observed)})
            : 'nutrition.suggestion_stable'.tr(namedArgs: {'days': days});
    final expected = s.expectedWeeklyKg;
    final goal = expected < 0
        ? 'nutrition.suggestion_goal_lose'.tr(namedArgs: {'kg': formatOneDecimal(expected.abs())})
        : expected > 0
            ? 'nutrition.suggestion_goal_gain'.tr(namedArgs: {'kg': formatOneDecimal(expected)})
            : 'nutrition.suggestion_goal_maintain'.tr();
    return '$change, $goal ${'nutrition.suggestion_question'.tr()}';
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.suggestion;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final newTarget = s.newTarget.round().toString();
    final heading = TextStyle(fontFamily: AppFonts.heading, fontWeight: FontWeight.w900, fontSize: 20);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      // Tek kenarlı çerçeve borderRadius ile verilemez; köşeleri ClipRRect yuvarlar.
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Container(
          key: const Key('calorie_suggestion_card'),
          decoration: BoxDecoration(
            color: scheme.surfaceContainer,
            border: Border(left: BorderSide(color: scheme.primary, width: 4)),
          ),
          padding: const EdgeInsets.fromLTRB(14, 14, 10, 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'nutrition.suggestion_title'.tr(),
                style: theme.textTheme.labelLarge?.copyWith(
                  fontFamily: AppFonts.heading,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                  color: scheme.primary,
                ),
              ),
              const SizedBox(height: 6),
              Text(_body(), key: const Key('suggestion_body'), style: theme.textTheme.bodyMedium),
              const SizedBox(height: 8),
              Text.rich(
                key: const Key('suggestion_targets'),
                TextSpan(children: [
                  TextSpan(text: '${s.currentTarget.round()} → ', style: heading),
                  TextSpan(text: newTarget, style: heading.copyWith(color: scheme.primary)),
                  TextSpan(
                    text: ' kcal',
                    style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ]),
              ),
              const SizedBox(height: 4),
              Text(
                s.method == SuggestionMethod.energyBalance
                    ? 'nutrition.suggestion_method_energy'.tr()
                    : 'nutrition.suggestion_method_trend'.tr(),
                key: const Key('suggestion_method'),
                style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    key: const Key('suggestion_snooze_button'),
                    onPressed: _busy ? null : () => _write(snoozeSuggestionFields(ref.read(nowProvider)())),
                    child: Text('nutrition.suggestion_snooze'.tr()),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    key: const Key('suggestion_apply_button'),
                    onPressed: _busy
                        ? null
                        : () => _write(
                              applySuggestionFields(s, ref.read(nowProvider)()),
                              successMessage: 'nutrition.suggestion_applied'.tr(namedArgs: {'kcal': newTarget}),
                            ),
                    child: Text('nutrition.suggestion_apply'.tr()),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

Not: Kart testi `find.text('2099 → 1849 kcal')` ile `Text.rich`'in düz metnini arar. Bulamazsa `find.byKey(const Key('suggestion_targets'))` ile `tester.widget<Text>(...).textSpan!.toPlainText()` karşılaştırmasına geç.

- [ ] **Step 8: Kartı beslenme ekranına koy**

`lib/features/nutrition/presentation/nutrition_screen.dart`:
- Import'lara ekle:

```dart
import '../application/calorie_suggestion_provider.dart';
import '../domain/adaptive_tdee.dart';
import 'widgets/calorie_suggestion_card.dart';
```

- `NutritionScreen.build` içinde `final now = …` satırından sonra:

```dart
    // Yüklenirken ya da hata olursa kart gösterilmez (G3 spec §4.4).
    final suggestion = ref.watch(calorieSuggestionProvider).value;
```

ve `_NutritionBody(meals: meals, profile: profile, now: now)` çağrısını `_NutritionBody(meals: meals, profile: profile, now: now, suggestion: suggestion)` yap.

- `_NutritionBody`'ye alan ekle: kurucuya `this.suggestion` (opsiyonel), alan `final CalorieSuggestion? suggestion;`.
- `ListView` children'da `const SizedBox(height: 12),` satırından sonra, `RemainingCaloriesCard(`'tan önce:

```dart
        if (suggestion != null) CalorieSuggestionCard(suggestion: suggestion!),
```

- [ ] **Step 9: Testlerin geçtiğini gör**

Run: `flutter test --no-pub test/features/nutrition/`
Expected: PASS (hepsi).

- [ ] **Step 10: Analiz**

Run: `flutter analyze --no-pub` (arka planda)
Expected: `No issues found!`

- [ ] **Step 11: Commit**

```bash
git add lib/features/nutrition/ assets/translations/tr.json assets/translations/en.json test/features/nutrition/
git commit -m "feat(nutrition): suggest a calorie target update on the nutrition screen

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 5: Ayarlar — "Uyarlandı" satırı ve sıfırlama

**Files:**
- Modify: `lib/features/settings/presentation/widgets/goal_summary_card.dart`
- Modify: `lib/features/settings/presentation/goals_screen.dart`
- Modify: `assets/translations/tr.json`, `en.json` (`settings` nesnesi)
- Test: `test/features/settings/presentation/goal_summary_card_test.dart` (yeni), `test/features/settings/presentation/goals_screen_test.dart`

**Interfaces:**
- Consumes: `Profile.calorieAdjustmentKcal`, `Profile.calorieAdjustedAt`, `resetAdjustmentFields(profile, now:)` (Task 2), `saveProfileChanges`, `shortDateLabel(date, now)` (`lib/shared/date_label.dart`).
- Produces: anahtarlar `settings_goal_adjustment`, `goals_reset_adjustment`, `goals_reset_confirm`, `goals_reset_cancel`.

- [ ] **Step 1: Çevirileri ekle**

`tr.json` `"settings"` nesnesine:

```json
    "adjustment_line": "Uyarlandı: {kcal} kcal · {date}",
    "adjustment_line_short": "Uyarlandı: {kcal} kcal",
    "adjustment_reset": "Uyarlamayı sıfırla",
    "adjustment_reset_confirm": "Uyarlama sıfırlansın mı? Kalori hedefin yeniden formülle hesaplanır.",
    "adjustment_reset_button": "Sıfırla"
```

`en.json` `"settings"` nesnesine:

```json
    "adjustment_line": "Adapted: {kcal} kcal · {date}",
    "adjustment_line_short": "Adapted: {kcal} kcal",
    "adjustment_reset": "Reset adaptation",
    "adjustment_reset_confirm": "Reset the adaptation? Your calorie target will be recalculated from the formula.",
    "adjustment_reset_button": "Reset"
```

JSON geçerliliğini Task 4 Step 1'deki komutla doğrula.

- [ ] **Step 2: Testleri yaz**

`test/features/settings/presentation/goal_summary_card_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spor_takip/features/onboarding/domain/profile.dart';
import 'package:spor_takip/features/settings/presentation/widgets/goal_summary_card.dart';

import '../../progress/fixtures.dart';
import '../../progress/presentation/test_app.dart';

void main() {
  setUpAll(initTestLocalization);

  Future<void> pump(WidgetTester tester, Profile profile) async {
    await tester.pumpWidget(testApp(GoalSummaryCard(profile: profile, onTap: () {})));
    await tester.pumpAndSettle();
  }

  testWidgets('no adaptation line without an adjustment', (tester) async {
    await pump(tester, testProfile);
    expect(find.byKey(const Key('settings_goal_adjustment')), findsNothing);
  });

  testWidgets('shows the adaptation line with its date', (tester) async {
    await pump(tester, testProfile.copyWith(calorieAdjustmentKcal: -160, calorieAdjustedAt: DateTime(2026, 10, 8)));
    final line = tester.widget<Text>(find.byKey(const Key('settings_goal_adjustment'))).data;
    expect(line, 'settings.adjustment_line');
  });

  testWidgets('without a date the short line is used', (tester) async {
    await pump(tester, testProfile.copyWith(calorieAdjustmentKcal: 120));
    final line = tester.widget<Text>(find.byKey(const Key('settings_goal_adjustment'))).data;
    expect(line, 'settings.adjustment_line_short');
  });
}
```

`test/features/settings/presentation/goals_screen_test.dart`:
- `pump`'a `{Profile profile = testProfile}` parametresi ekle ve override'ı `profileProvider.overrideWith((ref) async => profile)` yap (çağrı `pump(tester, profile: …)`).
- Yeni testler:

```dart
  testWidgets('reset is hidden without an adjustment', (tester) async {
    await pump(tester);
    expect(find.byKey(const Key('goals_reset_adjustment')), findsNothing);
  });

  testWidgets('reset asks first, then zeroes the adjustment', (tester) async {
    final adapted = testProfile.copyWith(calorieAdjustmentKcal: -160);
    await pump(tester, profile: adapted);

    await tester.tap(find.byKey(const Key('goals_reset_adjustment')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('goals_reset_cancel')));
    await tester.pumpAndSettle();
    expect(repo.updates, isEmpty);

    await tester.tap(find.byKey(const Key('goals_reset_adjustment')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('goals_reset_confirm')));
    await tester.pumpAndSettle();
    expect(repo.updates.single, resetAdjustmentFields(adapted, now: DateTime(2026, 10, 7, 9)));
  });
```

- [ ] **Step 3: Testlerin başarısız olduğunu gör**

Run: `flutter test --no-pub test/features/settings/presentation/goal_summary_card_test.dart test/features/settings/presentation/goals_screen_test.dart`
Expected: FAIL — anahtarlar bulunamıyor.

- [ ] **Step 4: Hedef kartına satırı ekle**

`lib/features/settings/presentation/widgets/goal_summary_card.dart`:
- Import ekle: `import '../../../../shared/date_label.dart';`
- `settings_goal_detail` Text'inden sonra, `const SizedBox(height: 12),`'den önce:

```dart
              if (profile.calorieAdjustmentKcal != 0) ...[
                const SizedBox(height: 4),
                Text(
                  _adjustmentLine(),
                  key: const Key('settings_goal_adjustment'),
                  style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
```

- Sınıfa ekle:

```dart
  /// "Uyarlandı: −160 kcal · 8 Ekim" (G3 spec §5.2).
  String _adjustmentLine() {
    final value = profile.calorieAdjustmentKcal.round();
    final kcal = value > 0 ? '+$value' : '−${value.abs()}';
    final at = profile.calorieAdjustedAt;
    return at == null
        ? 'settings.adjustment_line_short'.tr(namedArgs: {'kcal': kcal})
        : 'settings.adjustment_line'.tr(namedArgs: {'kcal': kcal, 'date': shortDateLabel(at, DateTime.now())});
  }
```

- [ ] **Step 5: Hedeflerim'e sıfırlamayı ekle**

`lib/features/settings/presentation/goals_screen.dart`, `_GoalsEditorState` içine:

```dart
  Future<void> _resetAdjustment() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        content: Text('settings.adjustment_reset_confirm'.tr()),
        actions: [
          TextButton(
            key: const Key('goals_reset_cancel'),
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('settings.cancel'.tr()),
          ),
          FilledButton(
            key: const Key('goals_reset_confirm'),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('settings.adjustment_reset_button'.tr()),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final ok = await saveProfileChanges(ref, resetAdjustmentFields(widget.profile, now: ref.read(nowProvider)()));
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('settings.save_error'.tr())));
    }
  }
```

ListView children'ın sonuna (odak `Wrap`'inden sonra) ekle:

```dart
              if (widget.profile.calorieAdjustmentKcal != 0) ...[
                const SizedBox(height: 24),
                Center(
                  child: TextButton(
                    key: const Key('goals_reset_adjustment'),
                    onPressed: _saving ? null : _resetAdjustment,
                    child: Text('settings.adjustment_reset'.tr()),
                  ),
                ),
              ],
```

- [ ] **Step 6: Testlerin geçtiğini gör**

Run: `flutter test --no-pub test/features/settings/`
Expected: PASS (hepsi).

- [ ] **Step 7: Commit**

```bash
git add lib/features/settings/ assets/translations/tr.json assets/translations/en.json test/features/settings/
git commit -m "feat(settings): show the calorie adaptation and allow resetting it

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 6: Koç bağlamında pay

**Files:**
- Modify: `supabase/functions/coach-chat/types.ts:11`
- Modify: `supabase/functions/coach-chat/context.ts:51-56`
- Modify: `supabase/functions/coach-chat/test_fixtures.ts`
- Test: `supabase/functions/coach-chat/context.test.ts`

**Interfaces:**
- Consumes: `profiles.calorie_adjustment_kcal` (Task 1; `store.ts` zaten `select('*')`).
- Produces: bağlam metninde pay ≠ 0 ise `, calorie_adjustment_kcal: <tam sayı> (already included in the target)`.

- [ ] **Step 1: Testi yaz**

`context.test.ts` sonuna ekle:

```ts
Deno.test('context shows a non-zero calorie adjustment', () => {
  const data = sampleContext();
  data.profile!.calorie_adjustment_kcal = -160.4;
  const text = buildContextText(data, 180);
  assertStringIncludes(text, 'daily_protein_target_g: 176, calorie_adjustment_kcal: -160 (already included in the target)');
});
```

`test_fixtures.ts` profilinde `daily_protein_target_g: 176,` satırından sonra `calorie_adjustment_kcal: 0,` ekle.

- [ ] **Step 2: Başarısız olduğunu gör**

Run: `deno test supabase/functions/coach-chat/`
Expected: FAIL (tip hatası: `calorie_adjustment_kcal` `ProfileRow`'da yok).

- [ ] **Step 3: Uygula**

`types.ts` `ProfileRow`'a `daily_protein_target_g: number;` sonrasına `calorie_adjustment_kcal: number;` ekle.

`context.ts` hedef satırını şu hale getir:

```ts
    lines.push(
      `goal: ${goal}, focuses: ${p.focuses.length > 0 ? p.focuses.join(',') : '-'}, ` +
        `daily_calorie_target: ${Math.round(p.daily_calorie_target)} kcal, ` +
        `daily_protein_target_g: ${Math.round(p.daily_protein_target_g)}` +
        (p.calorie_adjustment_kcal
          ? `, calorie_adjustment_kcal: ${Math.round(p.calorie_adjustment_kcal)} (already included in the target)`
          : ''),
    );
```

- [ ] **Step 4: Geçtiğini gör**

Run: `deno test supabase/functions/coach-chat/`
Expected: PASS (önceki 56 + 1).

- [ ] **Step 5: Commit**

```bash
git add supabase/functions/coach-chat/
git commit -m "feat(coach): include the calorie adjustment in the coach context

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 7: Doğrulama (kullanıcı terminali), PLAN.md, dalı bitirme

**Files:**
- Modify: `PLAN.md` (tabloya bir satır)

- [ ] **Step 1: Göç (SIRA ÖNEMLİ — web build'den önce)**

Kullanıcı Supabase SQL Editor'de sırayla çalıştırır:
1. `supabase/migrations/0012_adaptive_calories.sql`
2. `supabase/migrations/checks/g3_checks.sql` → dört sütun da `t`.
3. `supabase/migrations/checks/f5_rls_checks.sql` → `SONUC …` satırında öncekiyle aynı değerler (koç uygula/geri al akışı bozulmadı; `eski_amac=t`).

- [ ] **Step 2: Edge function deploy**

Run (kullanıcı): `npx supabase functions deploy coach-chat`

- [ ] **Step 3: Tam test paketi**

Run (kullanıcı): `flutter test --no-pub -j 1`
Expected: All tests passed (G2'de 438; yaklaşık +30).

- [ ] **Step 4: Web build ve örnek veri**

Kullanıcı web release build'i kendi terminalinde alır ve sunar (bkz. önceki fazlar). Test hesabında `supabase/migrations/checks/g3_seed_adaptive.sql` (e-posta değiştirilmiş olarak) çalıştırılır.

- [ ] **Step 5: Manuel kontrol listesi (8)**

1. Beslenme ekranında "HEDEFİNİ GÜNCELLE" kartı Kalan kartının üstünde görünüyor.
2. Metin doğru: gün sayısı, gözlenen değişim (sabit), hedef cümlesi, "eski → yeni kcal", yöntem "Öğün kayıtların ve kilo trendinle hesaplandı".
3. Uygula → snackbar "Hedef X kcal oldu", kart kayboluyor, Kalan kartı yeni hedefi gösteriyor.
4. Kilo ekranından bugüne kilo kaydı → hedef payı koruyor (yeni hedef ≈ formül + pay; ayarlarda satır duruyor).
5. Ayarlar hedef kartında "Uyarlandı: ±X kcal · <tarih>" satırı.
6. Hedeflerim → "Uyarlamayı sıfırla" → onay → hedef formüle dönüyor, satır kayboluyor.
7. Örnek veriyi yeniden çalıştır → kart → "Şimdi değil" → kart kayboluyor, sayfa yenilenince de görünmüyor.
8. Pay varken ayarlardan aktiviteyi değiştir → pay 0, "Uyarlandı" satırı kayboluyor.

Sonra örnek veri betiğinin temizlik bloğu çalıştırılır.

- [ ] **Step 6: PLAN.md satırı**

`PLAN.md` tablosunun sonuna (G2 satırından sonra) tarih + özet satırı ekle: G3 uyarlanabilir kalori tamamlandı (`g3-uyarlanabilir-kalori`, 7 görev); hibrit yöntem (enerji dengesi / kilo trendi), 21 gün, ±250 kcal, onaylı öneri kartı, pay profilde ve tartı/ayar/koç yollarında korunuyor, aktivite değişince sıfırlanıyor; göç 0012; test sayıları ve manuel 8/8; sıradaki: F5+ kas haritası ya da oyunlaştırma.

```bash
git add PLAN.md
git commit -m "docs: record G3 adaptive calorie target verification

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

- [ ] **Step 7: Dalı bitir**

superpowers:finishing-a-development-branch — önceki fazlardaki gibi: master'a fast-forward, dalı sil, kullanıcı onayıyla push.
