# F4b — İlerleme Takibi: Tasarım Spec'i

> Durum: Onaylandı (2026-09-28). Sonraki adım: writing-plans ile implementasyon planı.

## 1. Kapsam

PLAN.md F4 fazının (E5 + E6) ikinci parçası. F4a (antrenman oturumu, set kaydı) üzerine kurulur; dal `f4b-ilerleme`, `f4a-set-kaydi`'den açılır.

**Kapsamda:**
- Vücut ağırlığı kaydı (günde tek kayıt), grafik ve liste; en yeni kayıt profildeki kiloyu ve kalori/protein hedeflerini otomatik günceller.
- Beden ölçüleri: sabit 9 alanlık liste (hepsi isteğe bağlı), grafik ve geçmiş.
- Güç ilerlemesi: hareket başına tahmini 1RM grafiği.
- Haftalık özet: bu hafta (Pzt–Paz) + geçen haftayla kıyas.
- Hepsi ana sayfada kart olarak; kilo, güç ve ölçüler için ayrıntı ekranı.

**Kapsam dışı:** profil düzenleme ekranı; ölçü fotoğrafları; hedef kilo / tahmini hedef tarihi; birim seçimi (lbs, inç); çevrimdışı kuyruk; bildirim ve hatırlatmalar (F6); dışa aktarma.

## 2. Mimari Karar

- **Grafikler:** `fl_chart` paketi (web + mobil). Kendi `CustomPainter` çizimi ve sunucu tarafı hesap (SQL view/RPC) elendi: ilki eksen/ölçek/dokunma işini yeniden yazmak demek, ikincisi her hesabın SQL Editor'da elle doğrulanmasını gerektirir ve veri hacmi (kullanıcı başına birkaç yüz oturum) bunu gerektirmiyor.
- **Hesaplar uygulamada:** güç grafikleri ve haftalık özet mevcut `workout_sessions`/`session_sets` ve `meals` tablolarından okunur; hesaplar `lib/features/progress/domain/` altında saf Dart fonksiyonlarıdır.
- **Yeni SQL yalnızca** kilo ve ölçü tabloları ile profil güncellemesini tek transaction'da yapan iki RPC içindir.
- **TDEE formülü tek yerde kalır:** yeni hedefleri uygulamadaki mevcut `TdeeCalculator` hesaplar ve RPC'ye parametre olarak verir.

## 3. Veri Modeli (`0009_create_body_tracking.sql`)

### `body_weight_logs`
| Sütun | Tip | Not |
|---|---|---|
| `id` | uuid pk default `gen_random_uuid()` | |
| `user_id` | uuid not null → `auth.users` on delete cascade | |
| `logged_on` | date not null | |
| `weight_kg` | numeric not null, `check (weight_kg > 0 and weight_kg < 500)` | |
| `created_at` | timestamptz not null default now() | |

`unique (user_id, logged_on)`: günde tek kayıt; aynı güne yeni kayıt öncekinin üzerine yazar.

### `body_measurements`
`id`, `user_id` (yukarıdaki gibi), `measured_on date not null`, `created_at`, `unique (user_id, measured_on)`.
Ölçü sütunları (cm, `numeric`, hepsi null olabilir, dolu olan `> 0 and < 300`): `neck`, `shoulders`, `chest`, `waist`, `hips`, `arm`, `forearm`, `thigh`, `calf`.
`check (num_nonnulls(neck, shoulders, chest, waist, hips, arm, forearm, thigh, calf) > 0)`.

### RLS
İki tabloda da RLS açık; select/insert/update/delete politikaları `auth.uid() = user_id`. Ölçüler doğrudan tablo üzerinden upsert/delete edilir; kilo kayıtları yalnızca aşağıdaki RPC'lerle yazılır (profil tutarlılığı için), ama politikalar yine de dört işlemi de sahibine açar.

### Sunucu fonksiyonları (`security invoker`, tek transaction)
- **`log_body_weight(p_date date, p_kg numeric, p_calorie_target numeric, p_protein_target numeric)`**
  - `(auth.uid(), p_date)` için upsert.
  - `p_date` kullanıcının en yeni kayıt tarihine eşit ya da ondan yeniyse `profiles.weight_kg = p_kg`, `daily_calorie_target`, `daily_protein_target_g` ve `updated_at` güncellenir. Geçmiş tarihli kayıt profile dokunmaz.
- **`delete_body_weight(p_date date, p_new_latest_kg numeric, p_calorie_target numeric, p_protein_target numeric)`**
  - Kullanıcının tek kaydıysa silmeyi reddeder (`raise exception`); profildeki kilonun her zaman bir kaynağı olmalı.
  - Kaydı siler. Silinen kayıt en yeniyse profil, kalan en yeni kayda göre güncellenir; bu kaydın kilosu `p_new_latest_kg`'ye eşit değilse (uygulamanın listesi eski) `raise exception` ile işlem geri alınır. En yeni değilse profile dokunulmaz.
- **Backfill:** migration, mevcut her profil için `(user_id, created_at::date, weight_kg)` kaydını `on conflict do nothing` ile ekler.
- **Onboarding:** profil oluşturulduktan sonra onboarding akışı bugünün tarihiyle ilk kilo kaydını ekler (aynı RPC; hedefler zaten profildekilerle aynıdır).

## 4. Hesap Mantığı (`lib/features/progress/domain/`, saf Dart)

### 4.1 Tahmini 1RM
- Epley: `kilo × (1 + tekrar / 30)`; `tekrar == 1` ise sonuç kilonun kendisi.
- Sayılan setler: tamamlanmış, `weight_kg` ve `reps` dolu, `1 ≤ reps ≤ 10`. Kilosuz (vücut ağırlığı) setler ve 10'dan fazla tekrarlı setler güç grafiğine girmez.
- Bir hareketin her oturumu tek nokta verir: o oturumdaki en yüksek tahmini 1RM; tarih oturumun `finished_at`'i (yerel saat).
- Bu değer yalnızca grafik içindir; F4a'nın AMRAP tabanlı 1RM önerisi ve `user_one_rep_maxes` bundan etkilenmez.

### 4.2 En sık 3 hareket (güç kartı)
Son 90 günde, 4.1'e göre sayılan en az bir seti olan oturum sayısı en yüksek 3 hareket. Eşitlikte en son yapılan önce gelir.

### 4.3 30 günlük değişim (kilo ve güç kartları)
`son değer − referans`; referans, tarihi `son tarih − 30 gün` ya da daha eski olan en yeni değerdir. Böyle bir değer yoksa değişim gösterilmez.

### 4.4 Haftalık özet
- Hafta: cihazın yerel saatiyle Pazartesi 00:00 – sonraki Pazartesi 00:00 (hariç). Kıyas bir önceki tam haftayla; bu hafta henüz bitmediği için kartta "şu ana kadar" notu gösterilir.
- **Antrenman / set / hacim:** `finished_at`'i hafta içinde olan bitmiş oturumlar; set sayısı `completedSetCount`, hacim F4a'daki `totalVolumeKg` ile.
- **Kalori / protein:** hafta içindeki öğünler yerel güne göre gruplanır (`sumMealMacros` ile); yalnızca en az bir öğünü olan günlerin ortalaması alınır ve profildeki güncel hedefe göre yüzde olarak gösterilir. Kaç günün sayıldığı yazılır ("4 gün"). Hiç öğün yoksa "—".
- **Kilo değişimi:** haftanın son kilo kaydı − önceki haftanın son kilo kaydı; biri yoksa "—".
- Her metrik için bu hafta, geçen hafta ve fark (▲/▼) gösterilir.

## 5. Ekranlar ve Akış

### 5.1 Ana sayfa
Ortalanmış sütun kaydırılabilir bir listeye (`ListView`) çevrilir. Sıra:
1. **Hedefler kartı:** kalori ve protein hedefi (mevcut içerik).
2. **Bugünkü antrenman:** F4a `TodayWorkoutCard` (değişmez).
3. **Haftalık özet kartı:** 4.4'teki metrikler; ayrıntı ekranı yok.
4. **Vücut ağırlığı kartı:** son kilo, 30 günlük değişim, küçük çizgi grafik; **+** düğmesi hızlı kayıt penceresi (kilo + tarih, tarih varsayılanı bugün). Dokununca `/home/weight`.
5. **Güç ilerlemesi kartı:** 4.2'deki 3 hareket, her biri için son tahmini 1RM ve 30 günlük değişim. Dokununca `/home/strength`.
6. **Beden ölçüleri kartı:** son ölçüm tarihi, dolu alanların bir önceki ölçüme göre farkı. Dokununca `/home/measurements`.

Veri yoksa her kart kısa bir açıklama ve eylem düğmesi gösterir (ör. "İlk antrenmanını bitirince burada güç grafiğin görünecek.").

### 5.2 Kilo ekranı (`/home/weight`)
Büyük çizgi grafik; aralık seçimi 1 ay / 3 ay / 1 yıl / Tümü; kayıt listesi (yeniden eskiye). Kayda dokununca düzenleme penceresi (kilo değişir; tarih değişmez — başka tarihe taşımak için sil + yeni kayıt), kaydırarak ya da menüden silme (onaylı). Tek kayıt kaldıysa silme devre dışı ve açıklaması gösterilir.

### 5.3 Güç ekranı (`/home/strength`)
Hareket seçici (yalnızca 4.1'e göre sayılan seti olan hareketler, en sık yapılan üstte); seçilen hareket için oturum başına tahmini 1RM çizgi grafiği; aralık seçimi kilo ekranıyla aynı. Grafik noktasına dokununca tarih, set (kilo × tekrar) ve tahmini 1RM ipucu.

### 5.4 Ölçüler ekranı (`/home/measurements`)
- Üstte bölge seçim çipleri (verisi olan bölgeler) ve seçili bölge için çizgi grafik.
- **+** ile ölçüm formu: tarih (varsayılan bugün) + 9 alan; en az biri dolu olmadan kaydedilemez. Aynı tarihte kayıt varsa form onun değerleriyle açılır ve kaydetme üzerine yazar.
- Geçmiş listesi; düzenleme (aynı form) ve onaylı silme.

### 5.5 Yenileme
Kilo kaydı/silme, ölçüm kaydı/silme ve antrenman bitirme/silme sonrası ilgili provider'lar `invalidate` edilir; kilo değişince `profileProvider` da yenilenir (hedefler ana sayfada güncellenir).

## 6. Katmanlar ve Dosyalar

`lib/features/progress/` mevcut katman yapısıyla:
- `domain/`: `body_weight_log.dart`, `body_measurement.dart` (9 alan + `MeasurementSite` enum), `one_rep_max_estimate.dart` (4.1–4.2), `trend.dart` (4.3), `weekly_summary.dart` (4.4).
- `data/`: `body_weight_repository.dart` (liste + iki RPC), `body_measurement_repository.dart` (liste, upsert, delete), `progress_data_repository.dart` (aralık bazlı bitmiş oturum + set ve öğün sorguları; mevcut workout/meal repository'leri tarih aralığı sorgusu sunmuyorsa buraya eklenir).
- `application/`: Riverpod provider'ları (kart verileri, ekran verileri, kilo kaydetme/silme işlemleri — `TdeeCalculator` ile hedef hesabı burada).
- `presentation/`: `weight_screen.dart`, `strength_screen.dart`, `measurements_screen.dart`, `widgets/` altında dört kart, hızlı kilo penceresi, ölçüm formu, ortak `progress_line_chart.dart` (`fl_chart` sarmalayıcısı) ve aralık seçici.
- Değişenler: `home_screen.dart` (liste + kartlar), `router.dart` (`/home` alt rotaları), onboarding kaydı (ilk kilo kaydı), `pubspec.yaml` (`fl_chart`), `assets/translations/*.json` (TR/EN anahtarları).

## 7. Hata Durumları

- Ağ/sunucu hatası: kartlar kendi içinde hata metni + "Tekrar dene" gösterir; bir kartın hatası diğerlerini ve ana sayfayı bozmaz.
- Kaydetme/silme hatası: SnackBar ile bildirilir, form açık kalır.
- `delete_body_weight` eski liste hatası: SnackBar "Liste güncellendi, tekrar dene" + liste yenilenir.
- Geçersiz giriş (kilo ≤ 0 ya da ≥ 500, ölçü ≤ 0 ya da ≥ 300, boş ölçüm formu): form doğrulaması, sunucuya gitmez; aynı sınırlar veritabanında `check` ile de korunur.
- Gelecek tarih: tarih seçici bugünden sonrasına izin vermez.

## 8. Test Stratejisi

- **Birim (TDD):** tahmini 1RM ve 10 tekrar sınırı, oturum başına en iyi değer, en sık 3 hareket ve eşitlik kuralı, 30 günlük değişim (yetersiz veri dahil), haftalık özet (Pazartesi 00:00 sınırı, kayıtsız günlerin ortalamaya girmemesi, boş haftada "—").
- **Uygulama katmanı (fake repository):** geçmiş tarihli kayıt hedef hesaplamaz/profili değiştirmez; en yeni kayıt `TdeeCalculator` hedefleriyle RPC'yi çağırır; en yeni kayıt silinince bir önceki kaydın kilosuyla hedef hesaplanır; tek kayıt silinemez.
- **Widget:** her kartın dolu/boş durumu; hızlı kilo penceresi; ölçü formu doğrulaması; güç ekranında hareket seçimi; grafiklerin render olması (piksel karşılaştırması yok).
- Her görev sonunda `flutter analyze` temiz ve tüm testler yeşil (`--no-pub`).
- **SQL (kullanıcıyla, SQL Editor):** `0009` uygulanır; `supabase/migrations/checks/f4b_rls_checks.sql` tek DO bloğu, sonucu `raise exception` ile basar (her şey geri alınır). Kontroller: B, A'nın kilo/ölçü kayıtlarını göremez/değiştiremez; geçmiş tarihli kayıt profili değiştirmez; en yeni kayıt değiştirir; en yeni kayıt silinince profil öncekine döner; tek kayıt silinemez; backfill kaydı vardır.
- **Elle (kullanıcıyla, release web build):** ~8 maddelik liste; F4a'nın 11 maddelik listesiyle aynı oturumda yapılabilir.

## 9. Riskler

- **`fl_chart` web performansı / paket boyutu:** düşük; grafikler en fazla birkaç yüz nokta çizer. Sorun çıkarsa aralık seçimi varsayılanı 3 ay tutulur.
- **Saat dilimi:** haftalar ve günler cihazın yerel saatine göre; kullanıcı saat dilimi değiştirirse sınırdaki kayıtlar komşu güne/haftaya kayabilir. Kabul edildi.
- **Epley'in yüksek tekrarda sapması:** 10 tekrar sınırıyla sınırlandı; grafik "tahmini" diye etiketlenir.
- **Hedeflerin otomatik değişmesi kullanıcıyı şaşırtabilir:** kilo kaydından sonra SnackBar yeni kalori hedefini bildirir.
