# F4a — Antrenman ve Set Kaydı: Tasarım Spec'i

> Durum: Onaylandı (2026-09-26). Sonraki adım: writing-plans ile implementasyon planı.

## 1. Kapsam

PLAN.md F4 fazı (E5 Ağırlık & Set Takibi + E6 İlerleme Takibi) üç parçaya bölündü; bu spec **F4a**'yı kapsar:

- **F4a (bu spec):** antrenman oturumu, set kaydı, dinlenme sayacı, otomatik ağırlık artışı/düşüşü, geçmiş.
- **F4b (sonra):** ilerleme grafikleri, vücut ağırlığı ve beden ölçüleri, haftalık özet.

**Kapsamda:**
- Aktif ya da herhangi bir programdaki herhangi bir antrenmanı başlatma (ana ekran kartı + program detayı).
- Antrenman ekranı: set işaretleme (kilo + tekrar), her set anında sunucuya yazılır; dinlenme sayacı; antrenman sırasında hareket ekleme/çıkarma.
- Otomatik ağırlık önerisi: yüzdelik olmayan bloklarda artış/aynı/düşüş; yüzdelik bloklarda bitişte AMRAP'e göre 1RM değişikliği önerisi (kullanıcı onaylar).
- Bitiş özeti ve geçmiş listesi/detayı.
- F3'teki ana ekran "Tamamladım" düğmesinin gerçek kayıtla değiştirilmesi.

**Kapsam dışı:** ilerleme grafikleri, vücut ağırlığı/ölçüleri (F4b); çevrimdışı kuyruk; bildirimler (F6); plaka hesaplayıcı; programsız serbest antrenman.

## 2. Mimari Karar: Server-first

Antrenman başlatılınca Supabase'de bir oturum satırı açılır; her set işaretlendiğinde ilgili satır anında güncellenir. Gerekçe: sayfa yenilense/uygulama kapansa bile veri kaybolmaz, ana ekran devam eden oturumu gösterebilir, F2'nin düz Supabase paterniyle uyumludur. Bedeli: internet yokken set işaretlenemez (hata + tekrar dene). Salon bağlantısı sorun olursa ileride yerel kuyruğa geçilebilir; tablo yapısı değişmez.

## 3. Veri Modeli (`0008_create_workout_sessions.sql`)

```sql
create table if not exists public.workout_sessions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  program_id uuid references public.programs (id) on delete set null,
  program_name text not null,        -- başlatma anındaki adın kopyası
  workout_name text not null,
  workout_position int not null,     -- rotasyon ilerlemesi için
  started_at timestamptz not null default now(),
  finished_at timestamptz            -- null = devam ediyor
);

-- Kullanıcı başına en fazla bir devam eden oturum
create unique index if not exists workout_sessions_one_in_progress
  on public.workout_sessions (user_id) where finished_at is null;

create table if not exists public.session_sets (
  id uuid primary key default gen_random_uuid(),
  session_id uuid not null references public.workout_sessions (id) on delete cascade,
  exercise_position int not null,    -- hareketin oturumdaki sırası
  set_index int not null,            -- hareket içindeki set sırası
  exercise_id text not null references public.exercises (id) on delete restrict,
  target_reps_min int not null check (target_reps_min > 0),
  target_reps_max int not null check (target_reps_max >= target_reps_min),
  is_amrap boolean not null default false,
  percent_1rm numeric check (percent_1rm > 0 and percent_1rm <= 100),
  percent_ref_exercise_id text references public.exercises (id) on delete restrict,
  rest_seconds int check (rest_seconds >= 0),
  suggested_weight_kg numeric check (suggested_weight_kg >= 0),
  weight_kg numeric check (weight_kg >= 0),
  reps int check (reps >= 0),
  completed_at timestamptz,          -- null = henüz yapılmadı
  unique (session_id, exercise_position, set_index)
);
```

- **Planın kopyası:** `start_session` programdaki her bloğun her seti için bir `session_sets` satırı yazar. Program sonradan düzenlense (F3'te `save_program` blok id'lerini yeniden üretir) veya silinse bile oturum ve geçmiş etkilenmez; bu yüzden program bloklarına foreign key yoktur.
- **RLS:** `workout_sessions` için dört politika `user_id = auth.uid()`; `session_sets` için oturumun sahibine göre (`exists (select 1 from workout_sessions s where s.id = session_id and s.user_id = auth.uid())`).
- **Rotasyon:** `profiles.next_rotation_position` kalır (F3 spec'inde türetmeye geçiş düşünülmüştü; bilinçli olarak vazgeçildi — sıradaki yerine başka antrenman yapıldığında sıranın o antrenmandan devam etmesi, türetmeyle aynı sonucu daha basit verir).
- **Hareket silme:** Kullanıcının kendi hareketi bir `session_sets` satırında geçiyorsa silinemez (`restrict`); F3'teki "programında kullanılıyor" mesajı "programında veya antrenman kayıtlarında kullanılıyor" olarak güncellenir.

### Sunucu fonksiyonları (her ikisi `security invoker`, tek transaction)

- **`start_session(payload jsonb) returns uuid`** — payload: `program_id`, `program_name`, `workout_name`, `workout_position`, `sets[]` (her biri `session_sets` sütunları, `suggested_weight_kg` dahil). Oturumu ve setleri yazar. Devam eden oturum varken kısmi unique index nedeniyle hata verir.
- **`finish_session(session_id uuid, one_rep_maxes jsonb) returns void`** — oturum kullanıcıya ait ve devam ediyor değilse hata. `finished_at = now()`; oturumun `program_id`'si kullanıcının `active_program_id`'sine eşit ve program `rotation` modundaysa `profiles.next_rotation_position = workout_position + 1`; `one_rep_maxes` (`[{exercise_id, weight_kg}]`) `user_one_rep_maxes`'e upsert edilir.

Set işaretleme/düzeltme, hareket ekleme/çıkarma ve iptal (oturumu silme) tablolara doğrudan yazılır; RLS korur.

## 4. Otomatik Artış Kuralları (`lib/features/workout/domain/progression.dart`, saf Dart)

Önerilen kilolar istemcide hesaplanır ve `start_session` payload'ına yazılır.

### 4.1 Yüzdelik olmayan bloklar — önerilen kilo

Girdi: hareketin, en yeni olandan başlayarak bitmiş oturumlardaki set kayıtları.

1. Hareketin geçtiği son bitmiş oturum yoksa veya o oturumda kilo girilmiş tamamlanmış set yoksa → **boş** (null).
2. **Referans kilo** = o oturumdaki tamamlanmış setlerin en büyük `weight_kg`'ı.
3. **Başarılı oturum:** o oturumda hareketin tüm setleri tamamlanmış ve her birinde `reps >= target_reps_max` (AMRAP setlerinde `reps >= target_reps_min`).
4. **Düşüş:** hareketin geçtiği son 3 bitmiş oturumun referans kilosu aynı ve üçü de başarısız → `referans × 0,9`, 2,5 kg'a yuvarlanmış; arayüzde "3 kez başarısız, kilo düşürüldü" notu.
5. Aksi halde son oturum başarılıysa → `referans + artış`; değilse → `referans`.
6. **Artış:** hareketin `equipment = 'barbell'` ve `primary_muscles` içinde `quadriceps`, `hamstrings`, `glutes` veya `lower back` varsa **+5 kg**; aksi halde **+2,5 kg**.

### 4.2 Yüzdelik bloklar — önerilen kilo

F3'teki `targetWeightKg(1RM, %)` (en yakın 2,5 kg). 1RM yoksa boş.

### 4.3 Yüzdelik bloklar — bitişte 1RM önerisi

Her 1RM hareketi için (`percent_ref_exercise_id ?? exercise_id`) oturumdaki tamamlanmış AMRAP setlerinden **en yüksek `percent_1rm`'li** olan alınır; `fazla = reps - target_reps_min`:

| Durum | 1RM önerisi |
|---|---|
| `fazla < 0` (hedefin altı) | × 0,9 (−%10) |
| `fazla = 0` | değişmez (öneri gösterilmez) |
| 1–2 | +2,5 kg |
| 3–4 | +5 kg |
| ≥ 5 | +7,5 kg |

Sonuç 2,5 kg'a yuvarlanır. Kullanıcının o hareket için kayıtlı 1RM'si yoksa öneri yapılmaz. Tablo nSuns'ın TM kuralıdır ve doğrudan 1RM'ye uygulanır (F3'teki `× 0,9` TM dönüşümü uygulanmaz; fark kullanıcı onayıyla kabul edilen küçük bir yuvarlamadır). Kaynaktan tek bilinçli sapma: nSuns'ta 0 tekrar "artış yok"tur, burada −%10 önerilir.

### 4.4 Kullanıcı kontrolü

Önerilen kilo her zaman değiştirilebilir; işaretlenen değer kaydedilir. 1RM önerileri bitiş özetinde onay kutularıyla gelir (varsayılan işaretli); yalnızca işaretli olanlar yazılır.

## 5. Ekranlar ve Akış

### 5.1 Başlatma

- **Ana ekran kartı** (F3 `TodayWorkoutCard`): "Tamamladım" kaldırılır. Devam eden oturum yoksa bugünün/sıradakinin yanında **"Başla"**; varsa kart devam eden oturumu gösterir: antrenman adı, başlangıç (bugün değilse tarih ile) ve **"Devam et"**.
- **Program detayı:** her antrenman başlığında "Başla".
- Devam eden oturum varken başka antrenman başlatılmaya çalışılırsa: "Devam eden bir antrenmanın var" diyaloğu → "Devam et" / "İptal et ve yenisini başlat" / "Vazgeç".
- Başlatma: program bloklarından setler üretilir, 4.1/4.2 ile önerilen kilolar hesaplanır, `start_session` çağrılır, `/workout/session/:id`'ye gidilir.

### 5.2 Antrenman ekranı (`/workout/session/:id`)

- Üst çubuk: antrenman adı, geçen süre, **Bitir**, menüde **İptal**.
- Hareketler `exercise_position` sırasıyla kartlar; her kartta set satırları: `Set n · hedef (5 / 8–12 / 5+) · [kilo] kg · [tekrar] · ✓`. Yüzdelik setlerde hedefin yanında `%85`.
- Kilo kutusu önerilen kiloyla, tekrar kutusu `target_reps_max` ile dolar; AMRAP setinde tekrar kutusu boş ve hedef "5+" biçiminde.
- **✓:** satır anında "tamamlandı" görünür, update isteği gider; hata olursa işaret geri alınır, değerler korunur, snackbar "Kaydedilemedi, tekrar dene" + `debugPrint`. Tamamlanmış satıra dokununca düzenlenebilir (tekrar ✓ ile kaydedilir) veya işaret kaldırılabilir.
- **Kilo yayılımı:** hareketin ilk tamamlanmamış setinin kilosu değiştirilince aynı hareketin diğer tamamlanmamış setlerinin kilosu da (yalnızca arayüzde; kaydedilince yazılır) aynı değere geçer. Yüzdelik bloklarda farklı yüzdeli setlere yayılmaz.
- **Dinlenme sayacı:** set işaretlenince alt çubukta bloğun `rest_seconds`'ı (null → 90 sn) geri sayar; "+30 sn" ve "Atla". Bitince `HapticFeedback` + kısa sistem sesi (`SystemSound.play`). Yalnızca uygulama açıkken; oturum ekranından çıkılınca sıfırlanır.
- **Hareket ekle:** F3 hareket seçicisi; seçilen hareket en sona 3 set × 8–12, dinlenme 90 sn olarak eklenir (öneri 4.1'e göre).
- **Hareketi çıkar:** hareket kartı menüsü; yapılmamış setler silinir, tamamlanmış setler kalır.
- **İptal:** onay diyaloğu → oturum silinir (setler cascade) → ana ekrana dönülür; rotasyon değişmez.

### 5.3 Bitiş özeti

- **Bitir** → hiç tamamlanmış set yoksa "Hiç set tamamlanmadı; antrenmanı iptal etmek ister misin?" diyaloğu.
- Aksi halde özet ekranı: süre, tamamlanan set sayısı, toplam hacim (Σ kilo × tekrar, kilosuz setler hariç), 4.3'e göre 1RM önerileri (onay kutulu). Tamamlanmamış set satırları olduğu gibi kalır (`completed_at = null`); geçmişte "yapılmadı" görünür ve 4.1'de başarısızlık sayılır.
- **Kaydet** → `finish_session` → ana ekran; kart sıradaki antrenmanı gösterir.

### 5.4 Geçmiş

- Antrenman sekmesinde "Geçmiş" bölümü/sekmesi: bitmiş oturumlar yeniden eskiye; satırda tarih, antrenman adı, program adı, süre, hacim.
- Detay (`/workout/history/:id`): hareket bazında setler (salt okunur), yapılmayanlar soluk; menüde **Sil** (onaylı).

## 6. Katmanlar ve Dosyalar

`lib/features/workout/` altında F3 yapısı izlenir:

- `domain/`: `workout_session.dart` (`WorkoutSession`, `SessionSet`), `progression.dart` (4.1–4.3), `session_stats.dart` (süre, hacim, tamamlanan set), `session_builder.dart` (program antrenmanı → `SessionSet` listesi).
- `data/`: `session_repository.dart` (`SessionRepository` arayüzü + Supabase: `fetchInProgressSession`, `fetchSession`, `fetchHistory`, `fetchExerciseHistory(exerciseIds)`, `startSession`, `updateSet`, `addSets`, `deleteSets`, `finishSession`, `deleteSession`).
- `application/`: `session_providers.dart`, `session_notifier.dart` (oturum ekranı state'i: işaretleme, geri alma, yayılım, ekleme/çıkarma), `start_session_service.dart` (üretim + öneri + RPC).
- `presentation/`: `session_screen.dart`, `session_summary_screen.dart`, `history_screen.dart`, `history_detail_screen.dart`, `widgets/set_row.dart`, `widgets/rest_timer_bar.dart`; `today_workout_card.dart` ve `program_detail_screen.dart` değişir.
- Çeviriler `tr.json`/`en.json` → `workout.session.*`, `workout.history.*`.

## 7. Hata Durumları

| Durum | Davranış |
|---|---|
| Set yazılamadı | İşaret geri alınır, değerler korunur, snackbar + `debugPrint` |
| Sayfa yenilendi / uygulama kapandı | Açılışta devam eden oturum okunur; kartta "Devam et" |
| Oturumun programı silindi | `program_id = null`; adların kopyası sayesinde oturum ve geçmiş sorunsuz; rotasyon ilerlemez |
| Günler önce başlanmış, bitirilmemiş oturum | Kartta başlangıç tarihiyle "Devam et"; kullanıcı iptal edebilir; otomatik kapatma yok |
| Devam eden oturum varken yeni başlatma | 5.1'deki diyalog; sunucuda kısmi unique index ikinci güvence |
| `finish_session` hatası | Özet ekranında kalınır, snackbar; hiçbir değişiklik uygulanmamıştır (tek transaction) |

## 8. Test Stratejisi

- **Birim:** `progression.dart` (artış, aynı, 3 başarısızlıkta düşüş, alt vücut +5, kilosuz hareket, AMRAP tablosunun her satırı, `percent_ref`, 1RM yoksa öneri yok), `session_stats.dart`, `session_builder.dart`, `SessionNotifier` (işaretleme, hata sonrası geri alma, yayılım, ekleme/çıkarma) — fake repository ile.
- **Widget** (fake repository, `Key` ile bulma): oturum ekranı, bitiş özeti, geçmiş, ana kartın "Başla"/"Devam et" durumları, program detayındaki "Başla".
- **Repository'ler ve SQL:** doğrudan test edilmez; `supabase/migrations/checks/f4a_rls_checks.sql` (F3 gibi tek DO bloğu, sonuç hata mesajında) SQL Editor'da kullanıcıyla çalıştırılır: iki kullanıcı arası izolasyon, ikinci devam eden oturumun reddi, `finish_session`'ın rotasyon ve 1RM etkisi.
- **Manuel:** release web build üzerinde uçtan uca kontrol listesi (başlat → set işaretle → sayaç → hareket ekle/çıkar → yenile ve devam et → bitir → 1RM önerisi → geçmiş → bir sonraki oturumda artırılmış kilo).

## 9. Riskler

| Risk | Önlem |
|---|---|
| Salonda internet yok | Hata + tekrar dene; gerekirse ileride yerel kuyruk (tablo yapısı değişmez) |
| Her set bir ağ isteği | Tek satır update; hissedilir gecikmede iyimser arayüz zaten işareti anında gösteriyor |
| Web'de sayaç sesi/titreşimi tarayıcıya göre çalışmayabilir | Görsel geri sayım esas; ses/titreşim ek |
| 1RM tablosunun doğrudan 1RM'ye uygulanması | Kullanıcı her öneriyi onaylar |
