# G2 — Profil / Ayarlar Ekranı: Tasarım Spec'i

> Durum: Bölümler kullanıcıyla tek tek onaylandı (2026-10-07). Sonraki adım: kullanıcı spec'i gözden geçirir → writing-plans ile G2 implementasyon planı.

## 1. Bağlam

G1 (`docs/superpowers/specs/2026-10-07-g1-hedefler-design.md`) hedefi kilo yönü + hız + odaklar olarak yeniden kurdu; ancak onboarding sonrası hedefi ya da profil bilgilerini değiştirmenin yolu yok (koç sekmesi kilitli). G2 bu boşluğu kapatır.

Mevcut durum:
- `lib/features/settings/` klasörleri boş.
- `ProfileRepository` (`lib/features/onboarding/data/profile_repository.dart`) yalnızca `fetchProfile` ve `saveProfile` (upsert) sunar.
- Profil kilosu kilo kayıtlarıyla `log_body_weight` RPC üzerinden senkron tutulur.
- Çıkış butonu ana ekranın üst barında (`home_sign_out_button`).
- Uygulama tr/en destekler (`easy_localization`, `startLocale: tr`, seçilen dil kalıcı saklanır) ama dil seçici yok.

Maket (git'e girmez): `.superpowers/brainstorm/g2/settings-layout.html`.

## 2. Kararlar (kullanıcıyla onaylı)

| Konu | Karar |
|------|-------|
| Kapsam | Profil bilgileri, hedefler, dil seçimi, hesap (e-posta + çıkış). Hesap silme yok. |
| Düzen | **A**: liste + alan başına alt sayfa; hedefler ayrı "Hedeflerim" ekranı, canlı önizleme |
| Kaydetme | **Alan bazlı update**: yalnız değişen sütunlar + yeni hedefler istemciden `.update()`; migration yok |
| Kilo | Ayarlarda salt okunur; kilo ekranına gider (kayıtlarla senkron kalır) |
| Dal | `g2-ayarlar`, tek spec + tek plan |

## 3. Yapı ve veri akışı

### 3.1 Gezinme

- Ana ekranın üst barındaki çıkış ikonu kaldırılır; yerine dişli ikonu (`Icons.settings`, anahtar `home_settings_button`) gelir ve `/home/settings` açar.
- Rotalar (`lib/core/router.dart`, `/home` altına): `settings` → `SettingsScreen`, onun altında `goals` → `GoalsScreen` (`/home/settings/goals`).
- Kilo satırı mevcut `/home/weight`'e gider.

### 3.2 `lib/features/settings/`

- `domain/profile_edit.dart`
  - `Map<String, dynamic> profileChanges(Profile before, Profile after, {required int currentYear, TdeeCalculator calculator = const TdeeCalculator()})`
  - Düzenlenebilir alanlar: `height_cm`, `birth_year`, `gender`, `activity_level`, `does_exercise`, `sport_type`, `exercise_days_per_week`, `health_notes`, `weight_direction`, `pace`, `focuses`. Yalnız `before` ile farklı olanlar DB adlarıyla ve `Profile.toJson` biçimiyle döner (ör. `focuses` → `focusesToDb`, `pace` → `pace?.name`).
  - Hiçbir alan değişmediyse boş map.
  - Değişen alan varsa `after` profiliyle `TdeeCalculator` çalıştırılır; `daily_calorie_target` / `daily_protein_target_g` eski değerlerden farklıysa map'e eklenir.
  - `TdeeResult targetsFor(Profile profile, {required int currentYear, …})` — önizleme ve `profileChanges` aynı hesabı kullanır (formül yalnız `TdeeCalculator`'da).
- `presentation/settings_screen.dart` — ana liste.
- `presentation/goals_screen.dart` — Hedeflerim.
- `presentation/widgets/goal_summary_card.dart`, `targets_preview.dart`, `profile_field_sheets.dart` (alt sayfalar).

### 3.3 Kaydetme

- `ProfileRepository.updateProfile(String userId, Map<String, dynamic> fields)` → `_client.from('profiles').update(fields).eq('user_id', userId)`. Boş map'te çağrılmaz.
- Başarılı kayıttan sonra `ref.invalidate(profileProvider)`; ana ekran, beslenme ve kilo renkleri buradan güncellenir.
- Kilo (`weight_kg`) bu ekrandan asla yazılmaz.
- Testlerde `profileRepositoryProvider` sahte bir `ProfileRepository` alt sınıfıyla değiştirilir (`updateProfile` çağrılarını kaydeder, gerektiğinde hata fırlatır).

### 3.4 Ortak bileşenler (hedefli refactor)

- `step_scaffolds.dart` içindeki `_ChoiceCard` → public `ChoiceCard`; büyük ortalı sayı girişi → public `BigNumberField` (Montserrat 56, neon alt çizgi, birim, ipucu). İkisi `lib/features/onboarding/presentation/widgets/` altına taşınır.
- Onboarding (`ChoiceStepScreen`, `MultiChoiceStepScreen`, `NumericStepScreen`) bu widget'ları kullanır; görünüm ve test anahtarları aynı kalır (`choice_option_*`, `choice_subtitle_*`, `numeric_step_field`, `numeric_step_unit`).

## 4. Ekranlar

### 4.1 Ayarlar listesi (`/home/settings`, başlık `settings.title` = "Profil ve ayarlar")

Bölüm başlıkları mevcut `SectionHeader` ile.

**HEDEFİN** — `GoalSummaryCard` (anahtar `settings_goal_card`): neon kenarlıklı kart;
- 1. satır: yön (+ hız): "Kilo vermek · dengeli" / "Kilomu korumak".
- 2. satır: odaklar virgülle + (koru değilse) "≈x kg/hafta" (`weeklyChangeKg`, 1 ondalık). Odak yoksa `settings.no_focus` ("Odak seçilmedi").
- Büyük Montserrat rakamlarla mevcut `dailyCalorieTarget` kcal ve `dailyProteinTargetG` g protein; sağda "Düzenle ›".
- Dokununca `/home/settings/goals`.

**PROFİL** — kart içinde satırlar (anahtar `settings_row_<alan>`):

| Satır | Değer | Dokununca |
|---|---|---|
| Kilo | `80 kg` | `/home/weight` |
| Boy | `180 cm` | Büyük sayı alt sayfası, 100–250 |
| Doğum yılı | `1996` | Büyük sayı alt sayfası, 1920–2020 |
| Cinsiyet | çeviri etiketi | `ChoiceCard` listesi (onboarding seçenekleri ve ikonları) |
| Aktivite | çeviri etiketi | `ChoiceCard` listesi |
| Spor | `Fitness · 3 gün` / `Yapmıyor` | Tek alt sayfa: evet/hayır kartları; evet → spor türü metin alanı + gün sayısı (0–7) |
| Sağlık notları | metin (tek satır, kesilir) / `—` | Çok satırlı metin alanı (boş → null) |

Alt sayfalar (`showModalBottomSheet`, `isScrollControlled`, klavyeye göre yükselir):
- Başlık (alan adı), düzenleyici, `TargetsPreview` (yalnızca `profileChanges` hedefleri değiştiriyorsa: "Yeni hedef: X kcal · Y g protein"), `FilledButton` Kaydet (anahtar `settings_sheet_save`).
- Kaydet geçersiz değerde ya da değişiklik yokken pasif. Doğrulama onboarding sınırlarıyla aynı; spor "evet" iken tür boş olamaz.
- "Spor: hayır" kaydedilirse `sport_type` null, `exercise_days_per_week` 0 (onboarding ile aynı kural).

**DİL** — `SegmentedButton<Locale>` (anahtar `settings_language`): Türkçe / English; seçince `context.setLocale(...)`.

**HESAP**
- E-posta satırı (salt okunur; `auth.currentUser.email`).
- Kırmızı "Çıkış yap" satırı (anahtar `settings_sign_out`) → onay penceresi (`settings.sign_out_confirm`, İptal / Çıkış yap). Onayda mevcut mantık: `ref.invalidate(onboardingWizardProvider)` + `authRepository.signOut()`; router giriş ekranına yönlendirir.

### 4.2 Hedeflerim (`/home/settings/goals`, başlık `settings.goals_title` = "Hedeflerim")

- Ekran açılırken profilin yön/hız/odakları yerel duruma kopyalanır.
- **KİLO YÖNÜ**: üç `AccentChip` (Ver ↓ / Koru ⚖ / Al ↑; anahtar `goal_direction_<ad>`).
- **HIZ** (yalnız ver/al): Yavaş / Dengeli / Hızlı `ChoiceCard`'ları, alt yazı "≈x kg/hafta" (`onboarding.pace_estimate`). Ver/al seçildiğinde hız boşsa `balanced` atanır; koru seçilince hız null olur.
- **ODAKLAR**: dört `AccentChip` (çoklu seçim; anahtar `goal_focus_<ad>`).
- Altta yapışkan alan: `TargetsPreview` (her zaman, yeni değerlerle) + Kaydet (anahtar `goals_save`). Kaydet; değişiklik yoksa ya da odak seçili değilse pasif.
- Kaydet → `profileChanges(profile, edited)` → `updateProfile` → `invalidate` → `pop`.

### 4.3 Kapatma

Alt sayfa ya da Hedeflerim kaydetmeden kapatılırsa değişiklikler sessizce atılır (uyarı yok).

## 5. Hata durumları

- Kayıt sürerken Kaydet butonunda küçük `CircularProgressIndicator`, buton pasif; sayfa/ekran açık kalır.
- Kayıt hatası: SnackBar `settings.save_error` ("Kaydedilemedi, tekrar deneyin"); profil değişmez, düzenleme açık kalır.
- Başarı: alt sayfa / Hedeflerim kapanır; liste güncel profili gösterir.
- Ayarlar ekranında profil yüklenemezse mevcut `CardError` (`lib/features/progress/presentation/widgets/card_states.dart`) ile yeniden dene; yüklenirken `CircularProgressIndicator`.

## 6. Çeviriler (tr + en)

Yeni `settings` grubu: `title`, `section_goal`, `section_profile`, `section_language`, `section_account`, `edit`, `no_focus`, `row_weight`, `row_height`, `row_birth_year`, `row_gender`, `row_activity`, `row_sport`, `row_health_notes`, `sport_none`, `sport_summary` ("{sport} · {days} gün"), `new_targets` ("Yeni hedef: {kcal} kcal · {protein} g protein"), `save`, `save_error`, `sign_out`, `sign_out_confirm`, `cancel`, `goals_title`, `section_direction`, `section_pace`, `section_focuses`, `language_tr` ("Türkçe"), `language_en` ("English"). Mevcut `onboarding.*` seçenek etiketleri (cinsiyet, aktivite, yön, hız, odak) yeniden kullanılır. Haftalık tahmin metni için mevcut `onboarding.pace_estimate` kullanılır; çıkış ikonunun çeviri anahtarı yok, kaldırılacak anahtar da yok.

## 7. Test

TDD; mevcut test yapısı (`testApp`, sahte repository'ler).

- `test/features/settings/domain/profile_edit_test.dart`: yalnız değişen sütunlar + hedefler; değişiklik yok → boş; koru'ya geçiş `pace: null`; odaklar `focusesToDb` sırasında; sağlık notu değişimi hedef eklemez; hedefler `TdeeCalculator` ile aynı.
- Ortak bileşenler: mevcut `step_scaffolds_test.dart` değişmeden geçer; `ChoiceCard`/`BigNumberField` için küçük birim testleri.
- `test/features/settings/presentation/settings_screen_test.dart`: bölümler ve satır değerleri; kilo satırı `/home/weight`; boy alt sayfası önizleme + Kaydet `updateProfile`'ı doğru map'le çağırır; hata SnackBar'ı; spor alt sayfası "hayır" → `does_exercise: false, sport_type: null, exercise_days_per_week: 0`; dil düğmesi; çıkış onayı `signOut` çağırır.
- `test/features/settings/presentation/goals_screen_test.dart`: koru → hız bölümü yok; ver/al → hız `balanced`; odak yokken Kaydet pasif; Kaydet doğru map.
- `home_screen_test.dart`: `home_settings_button` ayarları açar; `home_sign_out_button` yok.
- `router_test.dart`: yeni rotalar.

## 8. Doğrulama (kullanıcı terminali)

Migration ve deploy yok.

1. `flutter test --no-pub -j 1` (tam paket).
2. Web build.
3. Manuel liste:
   1. Ana ekrandaki dişli ayarları açar; liste bölümleri ve değerleri doğru.
   2. Boy değişince önizleme ve kaydettikten sonra ana ekran kalori hedefi güncellenir.
   3. Hedeflerim'de yön/hız/odak değişimi önizlemeyi ve kayıttan sonra hedef kartını günceller.
   4. Spor alt sayfası: hayır/evet geçişi ve tür + gün kaydı.
   5. Dil English'e geçer; sayfa yenilenince seçim korunur.
   6. Çıkış onayı çalışır, giriş ekranına döner.
   7. Kilo satırı kilo ekranına gider.
   8. İnternet kapalıyken kaydet → hata mesajı, profil değişmez.

Sonra `PLAN.md` satırı ve dal kapanışı.

## 9. İsim ve logo: LevelUp Fit (kapsama sonradan eklendi, 2026-10-07)

Kullanıcı plan aşamasında uygulama adı ve logosunun da G2'de yenilenmesini istedi. Maket (git'e girmez): `.superpowers/brainstorm/g2/logo-options.html`, seçilen **B · Rütbe şeritleri**.

### 9.1 Görünen ad

- `app.title` ve `home.title` (tr + en): **LevelUp Fit**.
- `web/index.html`: `<title>` ve `apple-mobile-web-app-title` → "LevelUp Fit"; `description` → "Antrenman, beslenme ve ilerleme takibi".
- `web/manifest.json`: `name` "LevelUp Fit", `short_name` "LevelUp", `description` aynı metin, `background_color` ve `theme_color` `#0E0F12`.
- `android/app/src/main/AndroidManifest.xml` `android:label` ve `ios/Runner/Info.plist` `CFBundleDisplayName` → "LevelUp Fit".
- Değişmeyenler: paket adı `spor_takip`, bundle/application id'ler, `CFBundleName`, repo adı.

### 9.2 Logo bileşeni

- `lib/shared/widgets/app_logo.dart` → `AppLogo({super.key, this.size = 56})`; `CustomPaint` ile:
  - Koyu (`AppColors.background` #0E0F12) yuvarlatılmış kare, radius = size × 0.22, 1.5 px `AppColors.line` kenarlık.
  - 100×100 birimlik koordinatlarda iki "^" şerit: üst `(22,52)→(50,28)→(78,52)`, alt `(22,76)→(50,52)→(78,76)`; kalınlık 12 birim, yuvarlak uç ve birleşim; üst `AppColors.accent`, alt `AppColors.accent` %55 opak.
- `AuthHeader`: "S" karesi yerine `AppLogo(size: 56)` (anahtar `auth_logo`).

### 9.3 Yazı (wordmark)

- Türkçe büyük harf "Fit"i "FİT" yaptığından marka yazısı dile göre büyütülmez.
- `AuthHeader` başlığı sabit iki parça: "LEVELUP" (`onSurface`) + " " + "FIT" (`primary`), mevcut Montserrat 900 26 px / harf aralığı 1. `title` parametresi kaldırılır.
- Diğer yerler (ana ekran üst barı) `app.title`/`home.title` metnini olduğu gibi gösterir.

### 9.4 İkon dosyaları

- `tool/generate_icons.py` (Pillow; projeye paket eklenmez): logoyu 1024 px'te çizip `LANCZOS` ile küçültür.
  - Web: `web/favicon.png` 16 px; `web/icons/Icon-192.png`, `Icon-512.png` (yuvarlatılmış kare, şeffaf köşe); `Icon-maskable-192.png`, `Icon-maskable-512.png` (tam kare koyu zemin, şeritler %70 ölçekte ortalı).
  - Android: `mipmap-mdpi/hdpi/xhdpi/xxhdpi/xxxhdpi/ic_launcher.png` = 48/72/96/144/192 px.
  - iOS: `ios/Runner/Assets.xcassets/AppIcon.appiconset/Contents.json` içindeki her girdinin `size × scale` boyutu, dosya adı Contents.json'dan; tam kare, şeffaflık yok (iOS köşeleri kendisi yuvarlar).
- Çalıştırma: `python tool/generate_icons.py` (proje kökünden). Üretilen PNG'ler commit'lenir.

### 9.5 Test ve doğrulama

- `auth_screens_test`: başlıkta `auth_logo` (`AppLogo`) var; yazı "LEVELUP" + "FIT" (Türkçe yerelde de "FIT").
- `app_logo_test`: verilen boyutta `CustomPaint` çizilir.
- Uygulama adını doğrulayan mevcut testler "LevelUp Fit"e güncellenir.
- Manuel listeye ek: (9) tarayıcı sekmesinde yeni favicon + "LevelUp Fit"; (10) giriş ekranında yeni logo ve "LEVELUP FIT" yazısı.
