# F1 — Auth + Onboarding + Profil — Tasarım Spec'i

> Kapsam: PLAN.md'deki F1 fazı ("Auth + onboarding anketi + profil + TDEE hedef hesabı") ve E1 epic'i ("Onboarding & Profil"). Beslenme takibi (F2/E2/E3), antrenman (F3-F4), AI chat (F5) bu spec'in dışındadır.

## 1. Bağlam

F0 (repo/ortam kurulumu) tamamlandı: Flutter+Supabase iskeleti, feature-first klasör yapısı, Riverpod/go_router/dotenv bağımlılıkları, CI pipeline'ı kuruldu ve GitHub'a push edildi (CI ilk çalıştırmasında yeşil geçti). **F0 Task 8 (gerçek Supabase projesi + kimlik bilgileri) hâlâ AÇIK** — kullanıcı henüz bir Supabase projesi oluşturup URL/anon key paylaşmadı. F1'in implementasyon planı bu bağımlılığı açıkça ele almalı: kod/migration/test yazımı gerçek kimlik bilgisi olmadan ilerleyebilir (F1 §9'daki test stratejisi zaten gerçek Supabase'e bağlanmıyor), ancak uygulamanın gerçek cihazda/emülatörde uçtan uca çalıştığının doğrulanması (auth akışı, profil kaydı) gerçek bir Supabase projesi + `profiles` tablosunun migration'ının o projede çalıştırılmış olmasını gerektirir.

F1, uygulamanın ilk gerçek kullanıcı akışını kurar: kayıt/giriş → onboarding anketi → günlük kalori/protein hedefinin hesaplanıp kaydedilmesi → basit bir özet ekranı.

## 2. Onaylanan Kararlar

- **Auth yöntemleri:** E-posta/şifre + Google girişi (ikisi de F1 kapsamında).
- **E-posta doğrulama:** F1'de kapalı (kayıt sonrası direkt giriş yapılabilir; ileride Supabase dashboard'ından açılabilir).
- **TDEE formülü:** Mifflin-St Jeor (cinsiyete göre iki dallı formül + aktivite çarpanı).
- **Protein hedefi:** Kilo başına sabit oran, hedefe göre değişen (kilo verme/kas kazanma/formda kalma).
- **Dil:** Baştan i18n altyapısı (`easy_localization`) kurulacak; sadece `tr.json` gerçek çeviriyle doldurulacak, `en.json` iskelet olarak commit edilecek (F6'da gerçek İngilizce eklenecek).
- **Onboarding akışı:** Çok adımlı sihirbaz, her ekranda 1 soru, ilerleme çubuğuyla.
- **Onboarding veri kaydı:** Yaklaşım A — tüm cevaplar cihazda (Riverpod state) tutulur, son adımda tek bir Supabase `profiles` upsert'i yapılır. Adım adım/anlık kaydetme (Yaklaşım B) YAPILMAYACAK.
- **Onboarding sonrası ekran:** Basit bir özet ekranı (hesaplanan günlük kalori/protein hedefini gösteren placeholder "Dashboard").
- **Şifremi unuttum:** F1 kapsamına dahil — Supabase'in `resetPasswordForEmail` metoduyla login ekranında bir bağlantı, e-posta gönderimi ve "e-postanı kontrol et" mesajı. Basit ve ucuz olduğu için, ayrı bir spec turu gerektirmeden bu spec sürecinde karara bağlandı (bkz. §3.1).
- **Profil düzenleme:** F1'de YOK — kullanıcı onboarding'i bir kez tamamlar, düzenleme ekranı ileriki bir faza (Ayarlar/E9 veya ayrı bir F) bırakılır.
- **Supplement takibi:** F1'in KAPSAMI DIŞINDA — bu bir "günlük tüketim/log" kavramı olduğundan F2 (Fotoğraflı Besin Takibi) / E3 (Besin Veritabanı) planlanırken "hızlı besin girdisi" konsepti içinde ele alınacak (not: bu spec'in yazıldığı brainstorming sırasında kullanıcı tarafından gündeme getirildi, F1'e dahil edilmedi, F2/E3 spec'ine taşınacak).

## 3. Mimari

### 3.1 Auth durumu ve routing

`go_router`'ın `redirect` callback'i, Riverpod'dan gelen auth+profil durumuna göre yönlendirir:

```
Giriş yapılmamış        → /login
Giriş yapılmış, profil yok → /onboarding
Giriş yapılmış, profil var → /home
```

- Auth durumu: `supabase_flutter`'ın `onAuthStateChange` stream'i → `StreamProvider<AuthState>`.
- Profil tamamlanma durumu: login sonrası `profiles` tablosundan tek seferlik sorgu → `FutureProvider<Profile?>` (null = onboarding gerekli).

Login ekranı ayrıca bir "Şifremi unuttum" bağlantısı içerir: e-posta girilip gönderilince Supabase `resetPasswordForEmail` çağrılır, kullanıcıya "e-postanı kontrol et" mesajı gösterilir (gerçek sıfırlama Supabase'in kendi e-posta linki üzerinden, uygulama dışında gerçekleşir — F1'de bunun için ayrı bir uygulama içi ekran gerekmez).

### 3.2 Katman yapısı (F0'ın feature-first mimarisine uyumlu)

```
lib/features/onboarding/
  domain/        → Profile modeli, TdeeCalculator (saf Dart fonksiyonları)
  application/   → Riverpod providers (authStateProvider, profileProvider, OnboardingWizardNotifier)
  data/          → ProfileRepository (Supabase profiles tablosuyla konuşur)
  presentation/  → login/register ekranları, onboarding adım ekranları, özet (home) ekranı
```

## 4. Veri Modeli

### `profiles` tablosu

| Alan | Tip | Açıklama |
|------|-----|----------|
| `user_id` | uuid, PK, `references auth.users(id)` | 1 kullanıcı = 1 profil |
| `weight_kg` | numeric | Kilo |
| `height_cm` | numeric | Boy |
| `birth_year` | int | Doğum yılı |
| `gender` | text (`male`/`female`/`unspecified`) | Mifflin-St Jeor cinsiyete göre farklı katsayı kullanır; `unspecified` seçilirse erkek/kadın sonuçlarının ortalaması alınır |
| `activity_level` | text (`sedentary`/`light`/`moderate`/`active`/`very_active`) | TDEE çarpanı için |
| `does_exercise` | bool | Spor yapıyor mu |
| `sport_type` | text, nullable | Sadece `does_exercise=true` ise dolu |
| `exercise_days_per_week` | int (0-7) | |
| `goal` | text (`lose_weight`/`gain_muscle`/`maintain`) | Protein oranı buna göre değişir |
| `health_notes` | text, nullable | Opsiyonel serbest metin |
| `daily_calorie_target` | numeric | Kayıt anında hesaplanıp saklanır (yeniden hesaplanmaz) |
| `daily_protein_target_g` | numeric | Kayıt anında hesaplanıp saklanır |
| `created_at`, `updated_at` | timestamptz | |

**RLS:** `auth.uid() = user_id` — hem `select` hem `insert`/`update` için. Tüm tablolarda RLS aktif (PLAN.md §5 ilkesine uyumlu).

## 5. Onboarding Sihirbazı

**Adım sırası (koşullu atlamalı):**
1. Kilo → 2. Boy → 3. Doğum yılı → 4. Cinsiyet → 5. Aktivite düzeyi → 6. Spor yapıyor mu? → *(evetse)* 7. Hangi spor → *(evetse)* 8. Haftada kaç gün → 9. Hedef → 10. Sağlık notu (opsiyonel)

**State yönetimi:** `OnboardingWizardNotifier` (Riverpod `Notifier`) — immutable `OnboardingAnswers` modeli + `currentStep` index. Hiçbir ara adımda network çağrısı yok.

**Bitirme akışı:**
1. `OnboardingAnswers` → `TdeeCalculator` ile `{calorieTarget, proteinTargetG}` hesaplanır
2. Tek bir `profiles` upsert'i yapılır (`ProfileRepository`)
3. Başarılıysa `/home`'a yönlendirilir; başarısızsa hata mesajı gösterilir, state korunur (bkz. §7)

**Doğrulama:** Her adımda alan bazlı anlık validasyon (örn. kilo 20-300 kg, boy 100-250 cm aralığı) — geçersizken "İleri" devre dışı.

**Navigasyon:** `PageView`/`IndexedStack` + üstte "Adım X/10" ilerleme göstergesi. Geri butonu state'i korur.

## 6. TDEE / Protein Hesaplama

`lib/features/onboarding/domain/tdee_calculator.dart` — saf Dart, Flutter'a bağımsız, tam unit-testable.

**BMR (Mifflin-St Jeor):**
- Erkek: `10×kilo + 6.25×boy - 5×yaş + 5`
- Kadın: `10×kilo + 6.25×boy - 5×yaş - 161`
- Belirtilmemiş: iki sonucun ortalaması

**TDEE = BMR × aktivite çarpanı:**

| Aktivite düzeyi | Çarpan |
|---|---|
| Hareketsiz | 1.2 |
| Hafif | 1.375 |
| Orta | 1.55 |
| Yoğun | 1.725 |
| Çok yoğun | 1.9 |

**Protein hedefi (g/kg vücut ağırlığı, hedefe göre):**

| Hedef | g/kg |
|---|---|
| Kilo verme | 2.0 |
| Kas kazanma | 2.2 |
| Formda kalma | 1.7 |

## 7. Hata Yönetimi

- **Auth hataları** (yanlış şifre, e-posta zaten kayıtlı, zayıf şifre vb.): Supabase hata koduna göre spesifik, çevrilmiş kullanıcı mesajları — generic "bir hata oluştu" kullanılmaz.
- **Google girişi iptali:** Sessizce login ekranına dönülür, hata mesajı gösterilmez (normal kullanıcı hareketi).
- **Onboarding kaydı sırasında ağ hatası:** Girilen cevaplar state'te kalır (kaybolmaz); "Kaydedilemedi, tekrar dene" mesajıyla yeniden deneme sunulur, sihirbaz baştan başlamaz.

## 8. i18n Altyapısı

**Paket:** `easy_localization`.

```
assets/translations/
  tr.json   → gerçek Türkçe çeviriler
  en.json   → aynı anahtarlar, F6'ya kadar iskelet/placeholder
```

Ekranlardaki tüm metinler `tr(...)` üzerinden çeviri anahtarlarına bağlanır; hardcoded Türkçe string kalmaz.

## 9. Test Stratejisi

- **Unit test:** `tdee_calculator.dart` — cinsiyet/aktivite/hedef kombinasyonlarının tamamını kapsayan saf fonksiyon testleri.
- **Widget test:** Her onboarding adımının validasyon mantığı (geçersiz girdide "İleri" disabled).
- **Widget test:** go_router redirect mantığı — sahte auth/profil state'leriyle doğru rotaya yönlendiğinin doğrulanması.
- **Entegrasyon testi:** F1'de YOK — gerçek Supabase'e bağlanan testler yazılmayacak (F0'daki CI prensibiyle tutarlı); `ProfileRepository` ince bir sarmalayıcı, asıl mantık domain katmanında test ediliyor.

## 10. Kapsam Dışı (F1'de yapılmayacak)

- Profil düzenleme ekranı (ileriki faz)
- Supplement/günlük besin takibi (F2/E3)
- Fotoğraf/AI entegrasyonu (F2)
- Antrenman programları, set takibi (F3-F4)
- AI chat (F5)
- İngilizce çevirilerin gerçek içerikle doldurulması (F6 — sadece iskelet F1'de kurulur)

## 11. Riskler

| Risk | Azaltma |
|------|---------|
| Google OAuth platform kurulumu (Android SHA-1, iOS URL scheme, Supabase provider config) beklenenden uzun sürebilir | Email/şifre akışı önce tam çalışır hale getirilip test edilir, Google girişi ayrı bir alt-görev olarak eklenir |
| `gender: unspecified` için BMR ortalaması klinik olarak "resmi" bir yöntem değil | Kullanıcıya arayüzde bu varsayımın basit bir yaklaşıklık olduğu ima edilebilir (örn. tooltip); tıbbi tavsiye olarak sunulmaz |
| Onboarding ortasında state kaybı (uygulama öldürülürse) | Yaklaşım A'nın bilinen kısıtı olarak kabul edildi (10 kısa soru için düşük risk); B'ye geçiş ileride mümkün |
