# N1 — Yerel Hatırlatıcılar — Tasarım Spec'i

Tarih: 2026-10-11 · Dal: `n1-hatirlaticilar` · Migration: yok

## 1. Bağlam

F6 (bildirimler, dil, tema, son testler) parçalara bölündü; ilk parça bildirimler, o da ikiye: **N1 yerel hatırlatıcılar** (bu spec) ve **N2 sosyal push** (FCM; sonra). Uygulamada bugüne kadar bildirim yok. Test web release derlemesiyle yapılıyordu; yerel zamanlanmış bildirim web'de çalışmaz, N1'in elle kontrolü kullanıcının Android telefonunda (USB, `flutter run --release`) yapılır.

## 2. Kararlar (kullanıcıyla onaylı)

1. Dört hatırlatıcı: antrenman, öğün, akşam beslenme özeti, haftalık antrenman hedefi.
2. **Yaklaşım A:** uygulama önümüzdeki 7 günün bildirimlerini zamanlar ve ilgili veri değiştikçe yeniden kurar. Sunucu ve arka plan görevi yok. Kabul edilen sınır: başka cihazda yapılan kayıt, bu cihazda uygulama açılana kadar bilinmez.
3. Ayarlar cihazda (SharedPreferences); bildirimler cihaza özgü.
4. Zamanlama esnek (`inexactAllowWhileIdle`, ±birkaç dakika); tam alarm izni istenmez.
5. Hepsi varsayılan kapalı (opt-in).

## 3. Davranış

### 3.1 Bildirimler sayfası

Ayarlar ekranında Dil ile Hesap bölümleri arasına "Bildirimler" satırı → `/settings/notifications`. Sayfada dört kart; her kartın bir ana anahtarı var.

| Kart | Ayarlar | Varsayılan |
|---|---|---|
| Antrenman | gün çipleri (Pzt–Paz, `Wrap`) + saat | sabit günlü (`weekdays`) aktif programda programın günleri, aksi halde Pzt/Çar/Cum; 18:00 |
| Öğün | kahvaltı / öğle / akşam için ayrı anahtar + saat | 09:00 / 13:00 / 19:30 |
| Akşam beslenme özeti | saat | 21:00 |
| Haftalık antrenman hedefi | gün + saat | Cuma, 19:00 |

Antrenman kartı ilk açıldığında günler programdan doldurulur; sonra kullanıcının seçimi saklanır (program değişse de kendiliğinden değişmez). Saat seçimi `showTimePicker`.

### 3.2 Kurallar ("ne zaman gelmez")

- **Antrenman:** seçili günlerde, seçilen saatte. O gün (yerel) bitmiş bir antrenman oturumu varsa bugünkü bildirim kurulmaz. Metin: aktif programda o günün antrenman adı (sabit günlüde o güne bağlı antrenman, yoksa ad olmadan genel metin; döngüselde `todayWorkoutProvider`'ın verdiği sıradaki antrenman); program yoksa genel metin.
- **Öğün:** her açık öğün tipi için her gün, saatinde. O gün o öğün tipinde (`MealType.breakfast/lunch/dinner`) kayıt varsa bugünkü bildirim kurulmaz. Ara öğün (snack) yok.
- **Akşam beslenme özeti:** ufuktaki her gün saatinde kurulur. Bugünkü metin bugünün verisinden; gelecek günler 1. kuralın metniyle ("öğün kaydetmedin") kurulur ve o gün uygulama açılınca / öğün kaydedilince güncellenir. Bugün için metin önceliği:
  1. Bugün hiç öğün yok → "Bugün öğün kaydetmedin".
  2. Protein hedefe ulaşmadı → "Proteinine {g} g kaldı" (tamsayıya yuvarlanmış).
  3. Kalori hedefe ulaşmadı → "Hedefine {kcal} kcal kaldı".
  4. İkisi de tuttu → bildirim kurulmaz.
  Hedefler profilden (`dailyProteinTargetG`, `dailyCalorieTarget` + `calorieAdjustmentKcal`, beslenme ekranındaki etkin hedefle aynı hesap). Profil yoksa yalnız 1. kural uygulanır, diğer durumda kurulmaz.
- **Haftalık hedef:** seçili gün ve saatte, yalnız bu haftanın (ISO hafta, Pzt başlangıç) o günü için. Hedef = aktif programın `effectiveDaysPerWeek`; hedef yoksa (program yok ya da gün sayısı belirsiz) kurulmaz. Bu hafta bitmiş antrenman sayısı ≥ hedef ise kurulmaz. Metin: "Bu hafta {done}/{goal} antrenman, {left} gün kaldı" (`left` = o günden pazara kalan gün sayısı, o gün dahil).
- Saati geçmiş bugünkü bildirimler kurulmaz. Ufuk: bugün + 6 gün.

### 3.3 Diğer

- Metinler uygulamanın seçili dilinde (TR/EN), zamanlama anında oluşturulur; dil değişince yeniden kurulur.
- Dokununca: antrenman ve haftalık hedef → `/home`; öğün ve beslenme özeti → `/nutrition`.
- İzin: bir kartın anahtarı ilk açıldığında bildirim izni istenir (Android 13+). Reddedilirse anahtar açık kaydedilir ama sayfanın üstünde "Bildirim izni yok" uyarısı ve sistem ayarlarına giden düğme görünür; zamanlama yapılmaz.
- Web: sayfa açılır, üstte "Bildirimler yalnız mobil uygulamada çalışır" notu, anahtarlar pasif.
- Çıkış yapınca tüm bildirimler iptal edilir.

## 4. Mimari (`lib/features/notifications/`)

### 4.1 Domain

- `notification_settings.dart`: `NotificationSettings` (workout: enabled, weekdays `Set<int>` 1–7, time; meals: map `MealType → (enabled, time)` yalnız breakfast/lunch/dinner; nutrition: enabled, time; weekly: enabled, weekday, time; `workoutDaysInitialized` bayrağı), `ReminderTime(hour, minute)`, `toJson`/`fromJson` (bozuk veri → varsayılanlar), `copyWith`, `defaults`.
- `planned_reminder.dart`: `ReminderKind { workout, meal, nutrition, weekly }`, `PlannedReminder(id, kind, at, titleKey, bodyKey, args, route)`; `reminderId(kind, day, [mealType])` deterministik int.
- `reminder_planner.dart`: `planReminders({settings, now, todayWorkoutName, workoutDoneToday, mealTypesToday, nutritionToday, targets, weeklyGoal, weeklyDone})` → `List<PlannedReminder>`. Saf; tüm §3.2 kuralları burada. Girdiler küçük değer tipleri (`NutritionTotals`, `NutritionTargets`).

### 4.2 Data

- `reminder_scheduler.dart`: arayüz `ReminderScheduler { Future<void> init(void Function(String route) onTap); Future<bool> requestPermission(); Future<bool> hasPermission(); Future<void> replaceAll(List<PlannedReminder>, String Function(String key, Map<String,String> args) tr); Future<void> cancelAll(); }`.
- `local_reminder_scheduler.dart`: `flutter_local_notifications` + `timezone` + `flutter_timezone`; Android kanalı "Hatırlatıcılar"; `zonedSchedule(..., androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle)`; payload = rota. `replaceAll` önce bekleyenleri iptal eder, sonra planı kurar.
- `noop_reminder_scheduler.dart`: web ve testler için.
- `notification_settings_store.dart`: SharedPreferences anahtarı `notification_settings_v1`.

### 4.3 Application

- `reminderSchedulerProvider` (web'de Noop, mobilde Local; testlerde override).
- `notificationSettingsProvider` (Notifier): yükler, `update(...)` ile kaydeder; antrenman günleri ilk açılışta aktif programdan doldurulur.
- `notificationPermissionProvider`: izin durumu; `request()`.
- `notificationSyncProvider`: AppShell izler. Girdileri: ayarlar, izin, oturum (`isLoggedInProvider`), oturumlar, bugünkü öğünler, aktif program / bugünkü antrenman, profil, dil, saat (gün değişimi için `nowProvider` ile hesap). Planı hesaplar, bir öncekinden farklıysa `replaceAll`; çıkışta ya da hiçbir kart açık değilken `cancelAll`. Hatalar loglanır, akış bozulmaz.

### 4.4 Presentation

- `notifications_screen.dart`: dört kart, gün çipleri, saat düğmeleri, izin uyarısı, web notu. ~360 px'te taşmaz.
- Ayarlar ekranına satır; `router.dart`'a rota.
- `main.dart`: mobilde `init` (saat dilimi + eklenti); bildirime dokununca `router.go(route)`; uygulama bildirimle açıldıysa açılış rotası.

### 4.5 Platform

- `pubspec.yaml`: `flutter_local_notifications`, `timezone`, `flutter_timezone` (güncel kararlı sürümler).
- Android: `POST_NOTIFICATIONS`, `RECEIVE_BOOT_COMPLETED`; eklentinin alıcıları (`ScheduledNotificationReceiver`, `ScheduledNotificationBootReceiver`); `coreLibraryDesugaringEnabled` + `desugar_jdk_libs` bağımlılığı.
- iOS: yalnız derlenebilir kalması (Darwin init); iOS testi kapsam dışı.

### 4.6 Çeviriler

Üst düzey `notifications.` bölümü TR + EN: sayfa başlığı, kart başlıkları/açıklamaları, gün kısaltmaları (mevcut varsa yeniden kullanılır), izin ve web notları, bildirim başlık/metinleri (`workout_title`, `workout_body_named`, `workout_body`, `meal_title_<tip>`, `meal_body`, `nutrition_none`, `nutrition_protein`, `nutrition_kcal`, `weekly_body`, kanal adı).

## 5. Hata ve kenar durumları

- İzin yok → zamanlama yapılmaz, uyarı gösterilir.
- Zamanlama/eklenti hatası → `debugPrint`, uygulama devam eder.
- Veri okunamazsa (çevrimdışı) son kurulan plan kalır (sync o turu atlar).
- Yaz saati: `timezone` ile yerel saat dilimine göre `TZDateTime`.
- Telefon yeniden başlarsa eklentinin boot alıcısı zamanlamaları geri yükler.
- Uygulama günlerce açılmazsa 7 günlük ufuk biter; sonrasında bildirim gelmez (kabul edilen sınır).

## 6. Testler (TDD)

- **Domain:** `NotificationSettings` JSON gidiş-dönüşü ve bozuk veri; `planReminders`: seçili günler/saatler, 7 günlük ufuk, bugün geçmiş saat, bitmiş antrenman, adlı/adsız metin, kaydedilmiş öğün tipi, beslenme metin önceliği (öğün yok / protein / kalori / ikisi tuttu / profil yok), haftalık hedef (tamamlandı, hedef yok, kalan gün), kapalı kartlar, deterministik kimlikler.
- **Application:** sahte zamanlayıcıyla `notificationSyncProvider` yalnız plan değişince `replaceAll`; çıkışta `cancelAll`; izin yokken zamanlama yok; antrenman günlerinin programdan ilk doldurulması.
- **Ekran:** dört kart ve varsayılanlar, gün çipi seçimi, saat değişimi kaydı, izin reddi uyarısı, web notu (Noop + `kIsWeb` yerine enjekte edilen platform bayrağı), Ayarlar satırının sayfayı açması.

## 7. Dal, sıra, elle kontrol

Sıra: paketler + Android ayarı → domain (ayarlar, planlayıcı) → zamanlayıcı + depolama → sağlayıcılar + senkron + AppShell → sayfa + Ayarlar satırı + rota + çeviriler → main.dart kurulumu → doğrulama.

Elle kontrol (Android telefon, `flutter run --release`):
1. İlk anahtar açılışında izin istenir; reddedince uyarı ve ayarlar düğmesi.
2. Antrenman: bugünü seç, saati 2 dk sonraya kur → bildirim gelir, metinde antrenman adı; dokununca Ana sayfa.
3. Antrenmanı bitir → aynı gün yeni saatle kurulan antrenman bildirimi gelmez.
4. Öğün: öğle saatini 2 dk sonraya kur → gelir; öğle öğünü kaydedip tekrar kur → gelmez.
5. Beslenme özeti: öğün yokken "öğün kaydetmedin"; protein eksikken "{g} g kaldı"; dokununca Beslenme.
6. Haftalık hedef: bugünü seç → "x/y antrenman" metni.
7. Telefonu yeniden başlat → bekleyen bildirim yine gelir.
8. Dili EN yap → yeni bildirimler İngilizce; çıkış yap → hiçbir bildirim gelmez.
9. Web release'te sayfa "yalnız mobil" notuyla açılır; ~360 px'te taşma yok.

## 8. Kapsam dışı

- Sosyal push bildirimleri (N2), cihazlar arası senkron.
- Sessiz saatler, ara öğün hatırlatıcısı, su hatırlatıcısı.
- Seri (streak) sistemi.
- iOS'ta elle test.
