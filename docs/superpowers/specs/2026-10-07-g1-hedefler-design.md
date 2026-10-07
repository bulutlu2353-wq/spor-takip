# G1 — Hedef Çekirdeği (kilo yönü + hız + odaklar): Tasarım Spec'i

> Durum: Bölümler kullanıcıyla tek tek onaylandı (2026-10-07). Sonraki adım: kullanıcı spec'i gözden geçirir → writing-plans ile G1 implementasyon planı.

## 1. Bağlam

İki kullanıcı isteği: (1) hedeflerde "kilo almak" yok, (2) aynı anda birden fazla hedef (ör. kilo vermek + kas kazanmak) seçilebilsin.

Mevcut durum (kod incelemesi):
- `profiles.goal` tek değer: `lose_weight | gain_muscle | maintain` (`0001_create_profiles.sql`).
- `TdeeCalculator` kaloriyi yalnız `BMR × aktivite katsayısı` olarak hesaplar; hedef **kaloriyi değiştirmez**, yalnız protein/kg'yi (2.0 / 2.2 / 1.7).
- Onboarding sonrası hedefi değiştirmenin yolu yok (ayarlar ekranı yok, koç sekmesi kilitli).

İş iki faza bölündü:
- **G1 (bu spec):** veri modeli, hesaplama, onboarding adımları, kilo renkleri, koç `set_goal`.
- **G2 (ayrı spec):** Profil/Ayarlar ekranı (ana ekranda dişli ikonu; profil alanları + hedefler düzenlenir; çıkış butonu oraya taşınır). G1 bitince hedef yine yalnız onboarding'de seçilir.

Sonraya bırakılan: **adaptif kalori** (tartı trendine göre 2–3 haftada bir kalori hedefini düzeltme) — ayrı faz.

## 2. Kararlar (kullanıcıyla onaylı)

| Konu | Karar |
|------|-------|
| Hedef modeli | **İki eksen**: kilo yönü (ver / koru / al, tek seçim, kaloriyi belirler) + odaklar (çoklu seçim, proteini ve koç bağlamını etkiler) |
| Kalori | Vücut ağırlığına göre **haftalık hız**: günlük fark = kilo × hız × 7700 / 7 (Helms 2014, ISSN, Iraki 2019) |
| Hız | Kullanıcı seçer: Yavaş / Dengeli (varsayılan) / Hızlı; "koru"da adım yok |
| Odaklar | Kas kazanmak, Güç artırmak, Dayanıklılık / kondisyon, Genel sağlık / form |
| Veri modeli | **A**: `profiles` üzerinde 3 sütun; `goal` kaldırılır |
| Düzenleme yeri | Profil/Ayarlar ekranı → G2 |
| Dal | `g1-hedefler`, tek spec + tek plan |

## 3. Veri modeli ve migration

### 3.1 `supabase/migrations/0011_goals_redesign.sql`

Yeni sütunlar (`profiles`):
- `weight_direction text not null check (weight_direction in ('lose','maintain','gain'))`
- `pace text null check (pace in ('slow','balanced','fast'))`
- `focuses text[] not null default '{}'`
  - check: `focuses <@ array['muscle','strength','endurance','general']` ve tekrarsız (`cardinality(focuses) = cardinality(array(select distinct unnest(focuses)))`).
- Tutarlılık check'i: `(weight_direction = 'maintain') = (pace is null)`.

Sıra: sütunlar null'a izinli eklenir → veri taşınır → `not null` + check'ler eklenir → `goal` sütunu düşürülür.

Mevcut kayıtların taşınması:

| Eski `goal` | `weight_direction` / `pace` / `focuses` | Kalori | Protein |
|---|---|---|---|
| `lose_weight` | `lose` / `balanced` / `{}` | `greatest(daily_calorie_target − weight_kg × 8.25, taban)` | `weight_kg × 2.2` |
| `gain_muscle` | `maintain` / null / `{muscle}` | değişmez (zaten TDEE) | `weight_kg × 2.0` |
| `maintain` | `maintain` / null / `{general}` | değişmez | `weight_kg × 1.6` |

`8.25 = 0.0075 × 7700 / 7` (dengeli kilo verme). Taban: `gender = 'male'` → 1500, diğerleri → 1200. Saklanan `daily_calorie_target` bugün TDEE'ye eşit olduğu için bu SQL hesabı istemcideki yeni formülle aynı sonucu verir.

`focuses` boş olabilir (yalnız taşınan `lose_weight` kayıtları); onboarding ve koç en az bir odak ister.

### 3.2 Koç SQL fonksiyonları (aynı migration'da `create or replace`)

- `chat_write_profile`: `goal` satırı kalkar; `weight_direction`, `pace`, `focuses` eklenir (`p_fields ? 'pace'` ile null yazılabilir; `focuses` jsonb dizisinden `text[]`'e çevrilir).
- `chat_target_snapshot('set_goal')`: anahtarlar `weight_direction`, `pace`, `focuses` + hedefler.
- Uygulama (`set_goal`): `chat_write_profile(jsonb_build_object('weight_direction', …, 'pace', …, 'focuses', …) || targets)`; payload şekli doğrulanır, değilse `invalid_payload`.
- Geri alma (`set_goal`): `base` içinde `goal` anahtarı varsa (migration öncesi olay) `stale` döner; değilse `chat_write_profile(b)`.

## 4. Dart domain

### 4.1 `lib/features/onboarding/domain/profile.dart`

- `enum Goal` kaldırılır. Yeni:
  - `enum WeightDirection { lose, maintain, gain }`
  - `enum Pace { slow, balanced, fast }`
  - `enum Focus { muscle, strength, endurance, general }`
- `Profile.goal` → `weightDirection`, `Pace? pace`, `Set<Focus> focuses`. `fromJson` / `toJson` / `copyWith` güncellenir (`pace`'i null'a çekmek için `copyWith(clearPace: true)` bayrağı; aynı bayrak `OnboardingAnswers`'ta da).
- DB eşlemeleri: enum adları DB değerleriyle aynı (`byName` / `.name`); `goalToDb` / `goalFromDb` kaldırılır.

### 4.2 Hız tablosu (tek yer, `tdee_calculator.dart`)

Haftalık değişim, vücut ağırlığının yüzdesi:

| | Yavaş | Dengeli | Hızlı |
|---|---|---|---|
| Kilo ver | %0.5 | %0.75 | %1.0 |
| Kilo al | %0.25 | %0.35 | %0.5 |

Yardımcı: `double weeklyChangeKg(double weightKg, WeightDirection d, Pace? p)` (koru → 0; onboarding alt yazısı da bunu kullanır).

### 4.3 `TdeeCalculator.calculate`

Parametre `goal` yerine `weightDirection`, `pace`, `focuses`.

```
tdee   = BMR × aktivite katsayısı                       (mevcut)
delta  = weightKg × oran × 7700 / 7                     (ver: −, al: +, koru: 0)
kcal   = max(tdee + delta, taban)                       (taban: male 1500, diğer 1200)
protein/kg = lose ise 2.2
           ; değilse focuses ∩ {muscle, strength} ≠ ∅ ise 2.0
           ; değilse 1.6
```

Çağıranlar güncellenir: onboarding kaydı, `profileWeightUpdate` (kilo girişi hedefleri yeni kiloyla yeniden hesaplar — delta otomatik ölçeklenir), koç `targetsAfter`.

### 4.4 `weightChangeIsGood` (`home_stat_grid.dart`)

`(double change, WeightDirection d)`: `lose → change < 0`, `gain → change > 0`, `maintain → false`. Kilo ekranı ve ana ekran kilo kutusu `profile.weightDirection` geçirir.

## 5. Onboarding

### 5.1 Adımlar (`onboarding_steps.dart`)

`OnboardingStepId.goal` yerine sırayla `weightDirection`, `pace`, `focuses` (ardından `healthNotes`). `pace` yalnız `answers.weightDirection` `lose` veya `gain` ise görünür (`sportType` deseni).

### 5.2 Ekranlar (`onboarding_step_widgets.dart`, `step_scaffolds.dart`)

- **WeightDirectionStep** — `ChoiceStepScreen<WeightDirection>`; başlık `onboarding.direction_question`; seçenekler: Kilo vermek (`Icons.trending_down`), Kilomu korumak (`Icons.balance`), Kilo almak (`Icons.trending_up`). Yön `maintain` seçilirse `answers.pace` temizlenir.
- **PaceStep** — `ChoiceStepScreen<Pace>`; başlık `onboarding.pace_question`; Yavaş / Dengeli / Hızlı. Her kartta alt yazı: `onboarding.pace_estimate` → "≈{kg} kg/hafta" (`weeklyChangeKg(answers.weightKg, …)`, 1 ondalık). `_ChoiceCard` opsiyonel `subtitle` alır; `ChoiceStepScreen` opsiyonel `String? Function(T)? subtitleOf` parametresi alır (3'lü seçenek kaydı aynen kalır).
- **FocusesStep** — yeni `MultiChoiceStepScreen<T>`: aynı `_ChoiceCard` görünümü, kart dokununca seçilir/bırakılır, `isValid` en az bir seçimde. Başlık `onboarding.focus_question`, altında `onboarding.focus_hint` ("Birden fazla seçebilirsin"). Seçenekler: Kas kazanmak (`Icons.fitness_center`), Güç artırmak (`Icons.bolt`), Dayanıklılık (`Icons.directions_run`), Genel sağlık (`Icons.favorite`).
- Kart anahtarları `choice_option_$value` aynen.

### 5.3 `OnboardingAnswers` ve kayıt

`goal` → `weightDirection`, `pace`, `focuses` (`Set<Focus>`, varsayılan boş). `isComplete`: yön dolu, yön `maintain` değilse `pace` dolu, `focuses` boş değil. Sihirbaz notifier'ı profili ve hedefleri yeni alanlarla kaydeder.

### 5.4 Çeviriler (tr + en)

Kaldırılır: `onboarding.goal_question`, `goal_lose_weight`, `goal_gain_muscle`, `goal_maintain`.
Eklenir: `onboarding.direction_question`, `direction_lose`, `direction_maintain`, `direction_gain`, `pace_question`, `pace_slow`, `pace_balanced`, `pace_fast`, `pace_estimate`, `focus_question`, `focus_hint`, `focus_muscle`, `focus_strength`, `focus_endurance`, `focus_general`. Sohbet kartı alan etiketleri (`…goal: "Amaç"` grubu) `weight_direction`, `pace`, `focuses` için genişletilir; eski `goal` etiketi eski olayların gösterimi için kalır.

## 6. Koç

Koç sekmesi kilitli kalır (`coachEnabledProvider=false`); kod yeni modelle tutarlı tutulur.

### 6.1 Edge function (`supabase/functions/coach-chat/`)

- `tools.ts`: `set_goal` parametreleri `{weight_direction: enum, pace?: enum, focuses: enum[]}` (`required: ['weight_direction', 'focuses']`). Doğrulama: yön `lose|gain` ise `pace` zorunlu, `maintain` ise yasak; `focuses` ≥1, tekrarsız, geçerli değerler; mevcut hedefle (yön + hız + odak kümesi) birebir aynıysa `goal is already …` hatası. Özet: `"Amaç değişikliği: Kilo vermek (dengeli) · Kas, Güç"` (tr) / `"Change goal: Lose weight (balanced) · Muscle, Strength"` (en). `update_profile` hata metni `set_goal`'a yönlendirmeye devam eder.
- `types.ts`: `ProfileRow.goal` → `weight_direction`, `pace`, `focuses`.
- `context.ts`: `goal: lose/balanced, focuses: muscle,strength` (koru: `goal: maintain`).
- `prompts.ts`: hedef açıklaması iki eksenli modele göre yeniden yazılır.
- Deploy: kullanıcı kendi terminalinde.

### 6.2 İstemci (`lib/features/chat/`)

- `card_data.dart`: `profileFieldChanges` `set_goal` için üç satır (`weight_direction`, `pace`, `focuses`) üretir; payload'da `goal` varsa (eski olay) tek `goal` satırı döner. `profileAfter` yeni alanları uygular; eski olay için profil değişmez.
- `card_bodies.dart`: değerleri çeviri etiketleriyle gösterir (odaklar virgülle; `pace` null → "—"; eski `goal` değerleri eski etiketlerle).
- `chat_models.dart`: gerekirse alan adı sabitleri.

## 7. Test

TDD; mevcut test yapısı (`test/features/...`, `testApp`).

- `tdee_calculator_test`: 3 yön × 3 hız kalori; taban (düşük kilolu kadın, hızlı kilo verme); protein önceliği (lose > kas/güç > diğer); `weeklyChangeKg`.
- `profile_test`: `fromJson`/`toJson` gidiş-dönüş, `pace` null, `focuses` dizisi.
- `weightChangeIsGood`: üç yön.
- Onboarding: `visibleSteps` koru'da `pace` yok; pace kartı "≈0.6 kg/hafta" (80 kg, dengeli ver); odak çoklu seçim + İleri aktifliği; yön koru'ya dönünce `pace` temizlenir; sihirbaz sonu kaydedilen profil ve hedefler.
- Koç Dart: `profileFieldChanges` üç satır; eski `goal` olayı; `targetsAfter`.
- Deno: `tools.test.ts` (doğrulama, özet tr/en, aynı hedef reddi), `context.test.ts`, `handler.test.ts`, `test_fixtures.ts`.
- SQL: `checks/f5_rls_checks.sql` `set_goal` senaryoları yeni payload'la; eski (`goal`'lu base) olayın undo'su `stale`.

## 8. Doğrulama (kullanıcı terminali)

1. Migration'ı uygula + SQL check'leri.
2. Edge function deploy.
3. `flutter test --no-pub -j 1` (tam paket).
4. Web build.
5. Manuel liste:
   1. Yeni hesap: onboarding'de yön → hız → odak adımları görünür.
   2. "Koru" seçilince hız adımı atlanır; geri dönüp "ver" seçilince hız adımı gelir.
   3. Hız kartlarında kg/hafta tahmini girilen kiloya uygun.
   4. Odaklarda birden fazla seçim yapılır; hiçbiri seçili değilken İleri pasif.
   5. Ana ekran kalori hedefi formülle uyumlu (ör. kilo ver dengeli → TDEE'den ≈ kilo×8.25 düşük).
   6. Mevcut hesap: taşınan hedefe göre kalori/protein doğru, uygulama hatasız açılır.
   7. Kilo al hedefinde kilo ekranı ve ana ekran kilo kutusunda artış neon.
   8. Kilo girişi sonrası kalori hedefi yeni kiloyla güncellenir.

Sonra `PLAN.md` satırı, branch kapanışı (master'a fast-forward, push onayla), ardından G2 brainstorm.

## 9. Plan sırasında netleşenler (2026-10-07)

Plan (`docs/superpowers/plans/2026-10-07-g1-hedefler.md`) yazılırken bu spec'teki şu noktalar güncellendi; çelişki olursa bu bölüm geçerlidir:

1. Odak enum'unun adı `GoalFocus` (`Focus`, Flutter widget'ıyla çakışıyor).
2. Kalori formülü `max(tdee + delta, min(tdee, taban))`: taban açığı sınırlar ama hedefi TDEE'nin üstüne çıkarmaz. Migration da aynı formülü kullanır.
3. Onboarding'de "koru" seçilince `pace` cevaplarda kalır; `buildProfileFromAnswers` korumada `pace`'i null yazar (`sportType` deseni). `OnboardingAnswers`'ta `clearPace` yok, yalnızca `Profile.copyWith`'te var.
4. G1 öncesi uygulanmış `set_goal` olayının geri alınması `modified` döner (mevcut `after` karşılaştırması sayesinde ek kod gerekmez); bekleyen eski olay `stale` olur.
5. Eski olay kartlarındaki hedef değer etiketleri `coach.legacy_goal.*` altına taşınır.
