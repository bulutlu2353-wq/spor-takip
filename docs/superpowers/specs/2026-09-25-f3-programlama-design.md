# F3 — Antrenman Programlama: Tasarım Spec'i

> Durum: Onaylandı (2026-09-25). Sonraki adım: writing-plans ile implementasyon planı.

## 1. Kapsam

Bu spec, PLAN.md §3 E4 epic'ini (Antrenman Programları) ve F3 fazını kapsar: hazır ve özel antrenman programları, haftalık plan, hareket kütüphanesi.

**Kapsamda:**
- 876 hareketlik açık kaynak hareket kütüphanesi + kullanıcının kendi hareketleri.
- 9 hazır program (başlangıç, orta, bölgesel, yüzdelik).
- Boştan program oluşturma ve hazır programı kopyalayıp özelleştirme.
- İki planlama modu: haftanın günlerine sabit (`weekdays`) ve sıralı döngü (`rotation`).
- Yüzdelik programlar için kullanıcının 1RM girişi ve kilo hesabı.
- Tek aktif program + ana ekranda "Bugün" kartı.

**Kapsam dışı (F4'e ertelendi):**
- Antrenman sırasında set işaretleme, dinlenme sayacı, set kaydı (`set_logs`).
- Otomatik ağırlık artışı (StrongLifts +2,5 kg, 5/3/1 döngü sonu TM artışı, nSuns AMRAP'e göre artış).
- Hareket adlarının Türkçe çevirisi (isimler İngilizce kalır — kullanıcı kararı).

## 2. Hareket Kütüphanesi Kaynağı

- **Veri seti:** [yuhonas/free-exercise-db](https://github.com/yuhonas/free-exercise-db), lisans **Unlicense** (kamu malı). 876 hareket; alanlar: `id`, `name`, `force`, `level`, `mechanic`, `equipment`, `primaryMuscles`, `secondaryMuscles`, `instructions`, `category`, `images`.
- **Sabitlenmiş commit:** `a859101d633a01c4a1a920d6a8ce41dabba0705f`. Seed bu commit'teki `dist/exercises.json`'dan üretilir.
- **Görseller:** Barındırılmaz; uygulama `https://raw.githubusercontent.com/yuhonas/free-exercise-db/<commit>/exercises/<images[i]>` adresinden yükler. Taban URL tek bir sabittedir (ileride Supabase Storage'a taşımak tek satır). Görsel yüklenemezse yerine ikon gösterilir.
- **Dil:** Hareket adları ve talimatlar İngilizce. Kas grubu (17 değer) ve ekipman (13 değer + null) etiketleri `tr.json`/`en.json`'a çevrilir (`workout.muscle.<değer>`, `workout.equipment.<değer>`).

## 3. Veri Modeli

```sql
-- 0004: hareket kütüphanesi (şema + 876 satır seed)
create table if not exists public.exercises (
  id text primary key default gen_random_uuid()::text,
  user_id uuid references auth.users (id) on delete cascade, -- null = hazır hareket
  name text not null,
  category text,
  equipment text,
  level text,
  primary_muscles text[] not null default '{}',
  secondary_muscles text[] not null default '{}',
  instructions text[] not null default '{}',
  images text[] not null default '{}',
  created_at timestamptz not null default now()
);

-- 0005: programlar (şema + copy_program + 9 hazır program seed)
create table if not exists public.programs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users (id) on delete cascade, -- null = hazır program
  name text not null,
  description text,
  level text check (level in ('beginner', 'intermediate', 'advanced')),
  schedule_mode text not null check (schedule_mode in ('weekdays', 'rotation')),
  source_program_id uuid references public.programs (id) on delete set null,
  created_at timestamptz not null default now()
);

create table if not exists public.program_workouts (
  id uuid primary key default gen_random_uuid(),
  program_id uuid not null references public.programs (id) on delete cascade,
  position int not null,
  name text not null,
  weekday smallint check (weekday between 1 and 7), -- ISO: 1=Pzt … 7=Paz; yalnızca weekdays modunda dolu
  unique (program_id, position)
);
create unique index if not exists program_workouts_weekday_uniq
  on public.program_workouts (program_id, weekday) where weekday is not null;

create table if not exists public.workout_exercises (
  id uuid primary key default gen_random_uuid(),
  workout_id uuid not null references public.program_workouts (id) on delete cascade,
  position int not null,
  exercise_id text not null references public.exercises (id) on delete restrict,
  sets int not null check (sets > 0),
  reps_min int not null check (reps_min > 0),
  reps_max int not null check (reps_max >= reps_min),
  is_amrap boolean not null default false,
  percent_1rm numeric check (percent_1rm > 0 and percent_1rm <= 100),
  rest_seconds int check (rest_seconds >= 0),
  notes text,
  unique (workout_id, position)
);

create table if not exists public.user_one_rep_maxes (
  user_id uuid not null references auth.users (id) on delete cascade,
  exercise_id text not null references public.exercises (id) on delete cascade,
  weight_kg numeric not null check (weight_kg > 0),
  updated_at timestamptz not null default now(),
  primary key (user_id, exercise_id)
);

alter table public.profiles
  add column if not exists active_program_id uuid references public.programs (id) on delete set null,
  add column if not exists next_rotation_position int not null default 0;
```

**RLS:**
- `exercises`, `programs`: `select` → `user_id is null or user_id = auth.uid()`; `insert/update/delete` → `user_id = auth.uid()` (hazır satırlar hiçbir kullanıcı tarafından değiştirilemez).
- `program_workouts`, `workout_exercises`: `select` → üst program görünürse (hazır veya kendi); yazma → üst program kullanıcınınsa (`exists` alt sorgusu, `meal_items` paterni).
- `user_one_rep_maxes`: yalnızca kendi satırları (`for all`).

**Blok modeli:** Bir `workout_exercises` satırı *özdeş setlerden oluşan bir blok*tur. Setleri farklı yüzde/tekrarla yapılan hareketler (5/3/1, nSuns) art arda birden fazla satır olarak yazılır; arayüz art arda gelen aynı `exercise_id`'li blokları tek başlık altında gruplar.

**Yüzde bazı:** `percent_1rm` her zaman 1RM'ye göredir. Kaynağı training max (TM = %90 1RM) üzerinden veren programlar (5/3/1, 5/3/1 for Beginners, nSuns) seed üretilirken `yüzde × 0,9` ile 1RM bazına çevrilir. Gösterilen kilo = `1RM × yüzde / 100`, **en yakın 2,5 kg'a** yuvarlanır. 1RM girilmemişse kilo yerine "%X" gösterilir.

**`copy_program(source uuid) returns uuid`:** `security invoker` plpgsql fonksiyonu. Kaynağı (RLS altında görünür olmalı) tüm `program_workouts` ve `workout_exercises` satırlarıyla birlikte `user_id = auth.uid()` olan yeni bir programa kopyalar, `source_program_id`'yi doldurur, yeni id'yi döner. Tek transaction — yarım kopya kalmaz. Kopya adı: kaynak adı (kullanıcı düzenleyicide değiştirir).

**Aktif program:** `profiles.active_program_id`. Aktif yaparken `next_rotation_position = 0`. Program silinirse FK `on delete set null` ile boşalır.

## 4. "Bugün" Hesabı

Saf domain fonksiyonu, `DateTime` + aktif program + `next_rotation_position` alır:
- **weekdays:** `weekday == today.weekday` olan antrenman; yoksa "Dinlenme günü".
- **rotation:** `position`'a göre sıralı listede `next_rotation_position % workouts.length` indeksindeki antrenman. "Tamamladım" butonu `next_rotation_position`'ı 1 artırır (F4'te gerçek antrenman kaydıyla değiştirilecek).
- Aktif program yok → karta "Program seç" yönlendirmesi.
- Antrenmansız program (boş) → "Bu programda antrenman yok".

## 5. Hazır Programlar

Adlar yaygın hâliyle, açıklamalar Türkçe. Program verisi `tool/programs/*.ts` içinde TypeScript olarak tanımlanır; üretici betik `0005` seed SQL'ini çıkarır. **Set/tekrar/yüzde değerleri hafızadan yazılmaz** — her program orijinal kaynağıyla karşılaştırılır, kaynak linki program dosyasına yorum olarak eklenir.

| Program | Seviye | Mod | Yapı |
|---|---|---|---|
| StrongLifts 5x5 | beginner | rotation (A/B), 3 gün/hafta | A: Squat, Bench, Barbell Row 5×5. B: Squat 5×5, OHP 5×5, Deadlift 1×5 |
| Full Body 3 gün | beginner | weekdays (1, 3, 5) | Her gün alt vücut + itme + çekme, 3×8–12 (genel şablon) |
| Upper/Lower 4 gün | intermediate | weekdays (1, 2, 4, 5) | Üst/alt kuvvet (4–6) + üst/alt hacim (8–12) |
| Push/Pull/Legs 6 gün | intermediate | rotation (6 antrenman) | r/Fitness PPL: Bench/OHP ve Deadlift/Row dönüşümlü, ana hareketin son seti AMRAP |
| Bro Split 5 gün | intermediate | weekdays (1–5) | Göğüs / Sırt / Omuz / Kol / Bacak |
| Arnold Split 6 gün | advanced | weekdays (1–6) | Göğüs+Sırt / Omuz+Kol / Bacak ×2 |
| 5/3/1 Boring But Big | intermediate | rotation (16 = 4 hafta × 4 gün) | Ana hareket OHP/Deadlift/Bench/Squat; 5/5/5+, 3/3/3+, 5/3/1+, deload; BBB 5×10 |
| 5/3/1 for Beginners | beginner | rotation (3 gün/hafta, 3 haftalık döngü — kaynakla doğrulanacak) | Her gün iki ana hareket: 5/3/1 setleri + 5×5 FSL |
| nSuns 5/3/1 LP 4 gün | advanced | weekdays (1, 2, 4, 5) | Her gün T1 (9 set) + T2 (8 set), set set yüzdeler |

Hazır program satırları sabit uuid'lerle seed'lenir (migration tekrar çalıştırılabilir, `on conflict do nothing`).

## 6. Ekranlar

Alt menüye üçüncü sekme: **Antrenman** (`nav.workout`).

1. **Programlar** (sekme kökü): aktif program kartı → "Programlarım" → "Hazır programlar" (seviye ve gün sayısı filtreleri) → "Boş program oluştur".
2. **Program detayı:** antrenmanlar sırayla, içlerinde gruplanmış bloklar (set × tekrar, AMRAP ise "5+", dinlenme, varsa kilo/yüzde). Butonlar: "Aktif yap"; hazır programda "Özelleştir" (`copy_program` → düzenleyici); kendi programında "Düzenle" / "Sil" (onay diyaloğu).
3. **Program düzenleyici:** ad, mod seçimi; antrenman ekle/sil/sırala; weekdays modunda gün seçimi (aynı gün iki kez seçilemez); her antrenmanda hareket bloğu ekle/sil/sırala, set/tekrar aralığı/AMRAP/dinlenme/yüzde düzenleme. Değişiklikler yerel state'te tutulur, "Kaydet" ile tek seferde yazılır; başarısızlıkta yerel düzenlemeler korunur ve hata gösterilir. Kaydedilmemiş değişiklikle çıkışta onay sorulur.
4. **Hareket seçici:** İngilizce isimle arama, kas grubu ve ekipman filtre çipleri (Türkçe etiket), harekete dokununca detay paneli (2 görsel + talimatlar), "Kendi hareketini ekle" (isim, kas grubu, ekipman). Kendi hareketi bir programda kullanılıyorsa silinemez (FK `restrict` → anlaşılır hata mesajı).
5. **1RM girişi:** `percent_1rm` içeren bir program aktif yapılırken, programın yüzdeli hareketleri için 1RM sorulur (atlanabilir). Program detayından sonradan düzenlenebilir.
6. **Ana ekran "Bugün" kartı:** §4'teki hesapla; dokununca ilgili antrenmanın detayı. Rotation modunda "Tamamladım" butonu.

Tüm liste/detay ekranları F2'deki yükleniyor / hata + tekrar dene / boş durumlarını izler. Tüm metinler `tr.json` + `en.json`'da.

## 7. Kod Yapısı

```
lib/features/workout/
  domain/        exercise.dart, program.dart, program_workout.dart, workout_exercise.dart,
                 schedule_mode.dart, today_workout.dart (bugün hesabı),
                 weight_calculator.dart (1RM × % → 2,5 kg yuvarlama), block_grouping.dart
  data/          program_repository.dart, exercise_repository.dart, one_rep_max_repository.dart
  application/   Riverpod provider'ları, program_editor_notifier.dart
  presentation/  programs_screen.dart, program_detail_screen.dart, program_editor_screen.dart,
                 exercise_picker_screen.dart, one_rep_max_sheet.dart, widgets/
tool/
  generate_exercise_seed.ts   exercises.json → supabase/migrations/0004_create_exercises.sql
  generate_program_seed.ts    tool/programs/*.ts → supabase/migrations/0005_create_programs.sql
  programs/                   9 program tanımı (kaynak linkleriyle)
```

Router'a `StatefulShellRoute` dalı, `AppShell`'e üçüncü `NavigationDestination`, ana ekrana "Bugün" kartı eklenir.

**Migration uygulama:** Veritabanı şifresi olmadığı için F2'deki gibi Dashboard SQL Editor ile. `0004` ~1 MB olacağı için Editor tek seferde kabul etmezse üretici betik seed'i parçalara (`0004a`, `0004b`…) böler.

## 8. Test Stratejisi (TDD)

- **Deno (CI'daki `deno-test` job'ına eklenir):** üretici betiklerin çıktısı; her programdaki her `exercise_id` veri setinde var mı; yüzdeler (0, 100] aralığında mı; 5/3/1 BBB deload haftası yüzdeleri diğer haftalardan düşük mü; weekdays programlarında gün tekrarı yok mu; SQL kaçışları (tek tırnak içeren isim/talimat).
- **Dart birim:** bugün hesabı (iki mod, dinlenme günü, boş program, döngü sarması), kilo hesabı ve yuvarlama, blok gruplama, domain modellerinin JSON dönüşümleri, düzenleyici notifier (ekle/sil/sırala/gün çakışması/kaydet hatası).
- **Widget (sahte repository ile, `fake_meal_repository` paterni):** program listesi ve filtreler, detay (hazır vs kendi program butonları), düzenleyici akışı, hareket seçici arama/filtre, "Bugün" kartının iki modu, 1RM paneli.
- **SQL:** CI'da veritabanı yok. RLS ve `copy_program`, uygulamadan sonra gerçek projede bir kontrol SQL betiğiyle (başka kullanıcının programını okuyamama, hazır programı değiştirememe, kopyanın tam olması) ve uçtan uca manuel testle doğrulanır.

## 9. Riskler

| Risk | Azaltma |
|---|---|
| Hazır program değerleri yanlış girilir | Kaynakla karşılaştırma + kaynak linki + Deno doğrulama testleri |
| GitHub raw görselleri erişilemez / hız sınırı | Ikon yedeği; taban URL tek sabit, Storage'a taşınabilir |
| 1 MB seed SQL Editor'a sığmaz | Üretici betik parçalara böler |
| `next_rotation_position` F4'te gerçek kayıtlarla çakışır | F4 spec'inde kayıtlardan türetmeye geçiş planlanacak; sütun o zaman kaldırılabilir |
