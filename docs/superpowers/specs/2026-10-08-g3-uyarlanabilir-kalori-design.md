# G3 — Uyarlanabilir Kalori Hedefi: Tasarım Spec'i

> Durum: Bölümler kullanıcıyla tek tek onaylandı (2026-10-08). Sonraki adım: kullanıcı spec'i gözden geçirir → writing-plans ile G3 implementasyon planı.

## 1. Bağlam

G1 kalori hedefini formülle kurdu: Mifflin-St Jeor BMR × aktivite katsayısı + hıza göre açık/fazla (`weeklyRates`, 7700 kcal/kg) + cinsiyete göre taban (`lib/features/onboarding/domain/tdee_calculator.dart`). Formül kişinin gerçek harcamasından ±%10–20 sapabilir. G1'de "kilo trendine göre düzeltme" ayrı faza bırakıldı; G3 bu fazdır.

Mevcut durum:
- Hedef her kilo kaydında `log_body_weight` RPC'sine Dart'ta hesaplanıp gönderilir (`profileWeightUpdate`); profil/hedef düzenlemede `profileChanges`, koç kartlarında `card_data.dart` aynı `TdeeCalculator.calculate`'i çağırır. Onboarding de öyle. → Uyarlanmış hedef yalnızca `daily_calorie_target`'a yazılsa ilk tartıda ezilir.
- Veri: `body_weight_logs` (günde bir kilo), `meals` + `meal_items.calories` (öğün kaydı).
- Hedef değişikliklerinin zamanı tutulmuyor.

## 2. Kararlar (kullanıcıyla onaylı)

1. **Öneri + onay:** hedef kendiliğinden değişmez; kart öneri sunar, kullanıcı "Uygula" derse değişir.
2. **Hibrit yöntem:** öğün kaydı yeterliyse enerji dengesi, değilse kilo trendi.
3. Varsayılanlar: 21 günlük pencere; doğrusal regresyon eğimi; ≥6 kilo kaydı ve ≥14 gün yayılım; son hedef değişikliğinden ≥14 gün; enerji dengesi için pencere günlerinin ≥%70'i "kayıtlı gün" (gün toplamı ≥800 kcal); fark <100 kcal ise öneri yok; öneri başına en çok ±250 kcal; cinsiyet tabanı korunur; "Şimdi değil" 7 gün gizler.
4. **Düzeltme payı:** uyarlama, profilde formül TDEE'sine eklenen bir pay (`calorie_adjustment_kcal`) olarak saklanır. Kilo/hedef/hız değişimlerinde korunur; **aktivite seviyesi değişince 0'lanır**.
5. Erteleme profilde tutulur (cihazlar arası).
6. Kart beslenme ekranında; ana ekranda yok.

## 3. Veri

### 3.1 Göç `supabase/migrations/0012_adaptive_calories.sql`

`profiles`'a:
- `calorie_adjustment_kcal numeric not null default 0`
- `calorie_adjusted_at timestamptz` (son "Uygula" / "Sıfırla")
- `calorie_suggestion_snoozed_until timestamptz`
- `goals_changed_at timestamptz` (hedefi etkileyen son profil değişikliği)

Mevcut satırlarda hepsi varsayılan/null kalır; `goals_changed_at` null ise pencere yalnızca 21 günle sınırlanır.

Koç akışı (`apply_chat_action` / `chat_write_profile`, 0011'de):
- `chat_write_profile` `calorie_adjustment_kcal` ve `goals_changed_at` alanlarını da kabul eder.
- `update_profile` / `set_goal` anlık görüntü anahtarlarına `calorie_adjustment_kcal` ve `goals_changed_at` eklenir (geri alma bunları da geri yükler).
- `update_profile`/`set_goal` uygulanırken `goals_changed_at = now()`; değişiklikler `activity_level` içeriyorsa `calorie_adjustment_kcal = 0`. Dart tarafı (`card_data.dart`) bu durumda hedefi pay = 0 ile hesaplar. (Kesin yerleşim — SQL'de mi `p_extras` ile mi — plan aşamasında mevcut `apply_chat_action` koduna göre seçilir; davranış bu maddedeki gibidir.)

`supabase/migrations/checks/f5_rls_checks.sql`: yeni sütunların varlığı ve `calorie_adjustment_kcal` varsayılanının 0 olduğu kontrolü eklenir.

### 3.2 Model

`Profile`: `calorieAdjustmentKcal` (double, varsayılan 0), `calorieAdjustedAt`, `calorieSuggestionSnoozedUntil`, `goalsChangedAt` (DateTime?). `fromJson`/`toJson`/`copyWith` güncellenir. `_editableColumns`'a eklenmez (ayarlar formu bunları düzenlemez).

### 3.3 Okuma

- `MealRepository.fetchDailyCalories({userId, from, to})` → `Map<DateTime, double>` (yerel gün → kcal). `meals` `select('logged_at, meal_items(calories)')` ile aralık sorgulanır, Dart'ta yerel güne göre toplanır.
- Kilo kayıtları: mevcut `BodyWeightRepository.fetchLogs()`.

## 4. Alan katmanı

### 4.1 `TdeeCalculator.calculate`

Yeni parametre `double adjustmentKcal = 0`. `tdee = BMR × aktivite + adjustmentKcal`; açık/fazla ve taban `tdee` üzerinden mevcut formülle uygulanır. Tüm çağrı noktaları (`targetsFor`, `profileWeightUpdate`, `card_data.dart`, onboarding — onboarding'de 0) profildeki payı geçirir. Böylece tartı, ayar ve koç yolları payı korur.

### 4.2 `profileChanges`

- Hedefi etkileyen bir sütun değiştiyse `goals_changed_at` (çağıranın verdiği `now`) eklenir.
- `activity_level` değiştiyse `calorie_adjustment_kcal: 0` eklenir ve hedef pay = 0 ile hesaplanır.
- İmzaya `required DateTime now` eklenir (`currentYear` zaten çağırandan geliyor).

### 4.3 `lib/features/nutrition/domain/adaptive_tdee.dart` (saf, test edilebilir)

```dart
enum SuggestionMethod { energyBalance, weightTrend }

class CalorieSuggestion {
  final SuggestionMethod method;
  final double currentTarget;     // profil.dailyCalorieTarget
  final double newTarget;
  final double newAdjustmentKcal;
  final double observedWeeklyKg;  // işaretli, eğim × 7
  final double expectedWeeklyKg;  // işaretli; kilo verirken negatif, korumada 0
}

double? weightSlopeKgPerDay(List<ValuePoint> points); // en küçük kareler; <6 nokta ya da yayılım <14 gün → null

CalorieSuggestion? suggestCalorieAdjustment({
  required Profile profile,
  required List<ValuePoint> weights,        // tarih artan
  required Map<DateTime, double> dailyKcal, // yerel gün → kcal
  required DateTime now,
  required int currentYear,
});
```

Algoritma:
1. `snoozedUntil > now` → null.
2. `windowStart = max(today − 21 gün, calorieAdjustedAt, goalsChangedAt)` (null olanlar yok sayılır). `today − windowStart < 14 gün` → null.
3. Pencere içindeki kilolar → `slope`; null ise null.
4. Pencere günleri (windowStart..dün; bugün yarım gün sayılmaz) içinde `dailyKcal ≥ 800` olan günler "kayıtlı gün". Oranı ≥ 0.70 ise **enerji dengesi**, değilse **kilo trendi**.
5. `formulaTdee` = pay 0 iken BMR × aktivite (mevcut kilo ile).
   - Enerji dengesi: `observedTdee = ortalama(kayıtlı gün kcal) − slope × 7700`; `rawAdjustment = observedTdee − formulaTdee`.
   - Kilo trendi: `expectedSlope = ±weeklyChangeKg(...)/7` (verirken −, alırken +, korumada 0); `rawAdjustment = mevcutPay − (slope − expectedSlope) × 7700`.
6. `rawTarget = calculate(..., adjustmentKcal: rawAdjustment).calorieTarget`. Fark `rawTarget − currentTarget`, ±250 ile kırpılır → `clampedDelta`. `|clampedDelta| < 100` → null.
7. `newAdjustmentKcal = mevcutPay + clampedDelta`; `newTarget = calculate(..., adjustmentKcal: newAdjustmentKcal).calorieTarget` (taban bu adımda da uygulanır; taban yüzünden fark <100'e düşerse null).

### 4.4 Sağlayıcı

`calorieSuggestionProvider` (nutrition/application): profil + kilo kayıtları + `fetchDailyCalories(windowStart..today)` → `suggestCalorieAdjustment`. Yüklenme/hata durumunda kart gösterilmez.

## 5. Arayüz (maket: `.superpowers/brainstorm/adaptive/suggestion-card.html`, onaylı)

### 5.1 `CalorieSuggestionCard` — beslenme ekranı

- Yalnızca seçili gün bugünken, `RemainingCaloriesCard`'ın üstünde.
- `surfaceContainer` zemin, 16 radius, 4 px neon (primary) sol kenar.
- Başlık `nutrition.suggestion_title` "HEDEFİNİ GÜNCELLE" (Montserrat 900, primary).
- Gövde yön ve gözleme göre:
  - Gözlenen değişim |≥0,05| kg/hafta: "Son 3 haftada haftada {obs} kg {verdin/aldın}, hedefin {exp} kg …"
  - Aksi: "Son 3 haftada kilon sabit kaldı …"
  - Korumada hedef cümlesi "hedefin kilonu korumak".
  - Sonu: "Günlük hedefini {cur} → {new} kcal yapalım mı?" (yeni değer neon).
  - "3 hafta" yerine pencere gerçek uzunluğuna göre gün/hafta sayısı yazılır.
- Yöntem satırı (soluk): `nutrition.suggestion_method_energy` "Öğün kayıtların ve kilo trendinle hesaplandı" / `nutrition.suggestion_method_trend` "Kilo trendinle hesaplandı (öğün kaydı az)".
- Butonlar sağda: `TextButton` "Şimdi değil" (`suggestion_snooze_button`), `FilledButton` "Uygula" (`suggestion_apply_button`).
- **Uygula:** `updateProfile` ile `calorie_adjustment_kcal`, `calorie_adjusted_at = now`, `daily_calorie_target`, `daily_protein_target_g`; `profileProvider` invalidate; snackbar `nutrition.suggestion_applied` "Hedef {kcal} kcal oldu".
- **Şimdi değil:** `calorie_suggestion_snoozed_until = now + 7 gün`; `profileProvider` invalidate.
- Hata: mevcut genel hata snackbar'ı, kart kalır. İşlem sürerken butonlar devre dışı.

### 5.2 Ayarlar

- `GoalSummaryCard`: pay ≠ 0 ise soluk satır `settings.adjustment_line` "Uyarlandı: {±kcal} kcal · {gün ay}" (`calorieAdjustedAt` tarihi; null ise yalnızca kcal).
- Hedeflerim ekranının altı: pay ≠ 0 ise `TextButton` `settings.adjustment_reset` "Uyarlamayı sıfırla" → onay dialog'u → `calorie_adjustment_kcal = 0`, `calorie_adjusted_at = now`, `goals_changed_at = now`, hedefler pay 0 ile yeniden.

### 5.3 Koç

`context.ts` profil satırına `calorie_adjustment_kcal` eklenir (`types.ts` `ProfileRow` alanı). Koç öneri yapmaz.

## 6. Hata durumları

- Sağlayıcı hatası/yükleme → kart yok (beslenme ekranı etkilenmez).
- Yazma hatası → snackbar, durum değişmez.
- Eski istemci yeni sütunları bilmez; varsayılanlar sayesinde sorun yok. Yeni istemci göç öncesi çalışırsa `fromJson` eksik alanları varsayılan alır, ama yazma başarısız olur → göç web build'den önce uygulanır.

## 7. Çeviriler (tr + en)

`nutrition.suggestion_title`, `suggestion_lost`, `suggestion_gained`, `suggestion_stable`, `suggestion_goal_lose`, `suggestion_goal_gain`, `suggestion_goal_maintain`, `suggestion_question`, `suggestion_method_energy`, `suggestion_method_trend`, `suggestion_snooze`, `suggestion_apply`, `suggestion_applied`; `settings.adjustment_line`, `adjustment_reset`, `adjustment_reset_confirm_title`, `adjustment_reset_confirm_body`. (Kesin metin bölümlemesi plan aşamasında.)

## 8. Test (TDD)

- `adaptive_tdee_test.dart`: eğim (bilinen doğru); yetersiz veri (<6 kayıt, <14 gün yayılım, son değişiklikten <14 gün); erteleme; yöntem seçimi (%70 sınırı, <800 kcal günler sayılmaz, bugün hariç); enerji dengesi hesabı; kilo trendi (lose/maintain/gain); 100 eşiği; ±250 kırpma; taban.
- `tdee_calculator_test`: `adjustmentKcal`.
- `profile_edit_test`: hedef sütunu değişince `goals_changed_at`; aktivite değişince pay 0 ve hedef pay 0 ile; hedef dışı değişiklikte ikisi de yok.
- `profile_weight_update` testi: pay korunur.
- Koç kart testi: aktivite değişiminde hedef pay 0 ile.
- Widget: kart görünür/gizli (öneri null, bugün değil), Uygula ve Şimdi değil doğru alanları yazar, hata → kart kalır; ayarlar "Uyarlandı" satırı; sıfırla onayı ve yazılan alanlar.
- Deno: `context.test.ts` pay satırı.

## 9. Dal ve doğrulama

Dal `g3-uyarlanabilir-kalori`. Kullanıcı terminalinde, sırayla:
1. 0012 göçü SQL Editor'de; `f5_rls_checks.sql` kontrolleri.
2. `npx supabase functions deploy coach-chat`.
3. `flutter test --no-pub -j 1` (tam paket).
4. Web release build.
5. Örnek veri: `supabase/migrations/checks/g3_seed_adaptive.sql` (yalnızca elle; test hesabına 21 günlük kilo + öğün kaydı ekler, `goals_changed_at`/`calorie_adjusted_at`'i 22 gün geriye çeker; temizleme bloğu içerir).
6. Manuel liste (~8): kart görünür; metin/yöntem doğru; Uygula → hedef ve snackbar; tartı sonrası pay korunur; Şimdi değil → kart gider; ayarlar "Uyarlandı" satırı; sıfırla; aktivite değişince pay 0.

Sonra PLAN.md satırı + finishing-branch (master'a fast-forward, push).

## 10. Kapsam dışı

Öneri geçmişi ekranı, koçun öneri yapması, protein uyarlaması, bildirimler.
