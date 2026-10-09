# O1 — Kişisel Oyunlaştırma: XP, Seviye, Rütbe, Unvanlar — Tasarım Spec'i

> Durum: Bölümler kullanıcıyla tek tek onaylandı (2026-10-09). Sonraki adım: kullanıcı spec'i gözden geçirir → writing-plans ile O1 implementasyon planı. Dal: `f5p-oyunlastirma`.

## 1. Bağlam

PLAN.md F5+ satırı oyunlaştırmayı "seviye, kazanılan unvanlar" olarak tarif eder; uygulamanın adı LevelUp Fit ve logosu rütbe şerididir (`lib/shared/widgets/app_logo.dart`). Kullanıcı oyunlaştırmayı sosyal bir katmanla birlikte istedi; iş dört faza bölündü (§10). Bu spec yalnızca **O1**'i kapsar: tek kullanıcının kendi verisinden hesaplanan XP, seviye, rütbe ve unvanlar.

Mevcut kod:
- Oturumlar: `allSessionsProvider` (`lib/features/progress/application/progress_providers.dart`) — tüm bitmiş oturumlar, setleriyle (`ProgressDataRepository.fetchFinishedSessions`).
- Güç: `estimateOneRepMax({weightKg, reps})` (`lib/features/progress/domain/strength.dart`; Epley, ≤ 10 tekrar).
- Kas ağırlığı: `muscleWeight(exercise, muscle)` (`lib/features/workout/domain/muscle_heat.dart`, K3).
- Hareketler: `exercisesByIdProvider` (`lib/features/workout/application/muscle_heat_providers.dart`).
- Öğünler: `meals.logged_at timestamptz` (migration 0002); `ProgressDataRepository.fetchMeals` kalemleriyle birlikte çeker.
- Kas grupları: `muscleGroups` (17 değer) ve `muscleLabelKey` (`exercise_taxonomy.dart`).
- Ana sayfa: `lib/features/onboarding/presentation/home_screen.dart`, AppBar'da `home_settings_button` (dişli).
- `shared_preferences: ^2.5.5` bağımlılığı var.
- Tema: arka plan `#0E0F12`, kart `#181A20`, çizgi `#262830`, metin `#F2F3F5`, soluk `#8A8F98`, vurgu `#C6FF00`; Montserrat (başlık) / Inter.

## 2. Kararlar (kullanıcıyla onaylı)

1. **Çekirdek:** XP + seviye + rütbe; üstüne kalıcı kişisel kas/hareket unvanları.
2. **XP kaynakları:** antrenman bitirmek, yeni rekor (PR), öğün kaydı. Tartı/ölçü XP vermez.
3. **Yaklaşım A:** XP istemcide, geçmişten hesaplanır; saklanmaz. Migration ve deploy yok. Geçmişe dönük çalışır; silinen veri XP'yi kendiliğinden düşürür.
4. **Arayüz:** Ana sayfada küçük rütbe rozeti → seviye ekranı. Antrenman özeti ve ayarlar değişmez.
5. **Rütbe merdiveni:** 16 rütbe, seviye 100'e kadar; eğri `100 + 25 × (n − 1)`.
6. **Unvanlar:** Kas + hareket, üç kademe. Aktif unvan seçilebilir, cihazda saklanır.
7. **Fazlar:** O1 → S1 (arkadaşlık) → S2 (topluluklar) → S3 (meydan okumalar). Haftalık/aylık yarışma unvanları S2'dedir.
8. **Stitch taslakları:** projeler 13509290851929310980 (seviye ekranı) ve 7901177823631841304 (ana sayfa rozeti). Görseller `.superpowers/brainstorm/o1-stitch/` altında (git'e girmez): `level_screen.png`, `home_badge.png`. Taslakta olup kapsam dışı: unvan bonus XP metni, alt menü değişikliği, AppBar'da LVL hapı ve dişli, "BU SEZON" / "HEDEFLER" / "YOLCULUK" / "GEÇMİŞ" etiketleri. Yerleşimin bağlayıcı tarifi §6'dır.

## 3. XP kuralları (`lib/features/gamification/domain/xp_rules.dart`)

| Olay | XP | Koşul |
|---|---|---|
| Antrenman | `50 + 5 × min(tamamlanan set, 30)` | Bitmiş oturum, en az 1 tamamlanmış set. En çok 200. |
| Rekor (PR) | Hareket başına 25 | Oturumdaki en iyi tahmini 1RM, aynı hareketin **önceki** oturumlarındaki en iyiyi kesin olarak aşar. İlk yapılış PR değildir. |
| Öğün günü | 10 | En az bir öğünün `logged_at`'i o yerel günde. Günde bir kez. |

```dart
enum XpSource { workout, record, mealDay }

class XpEvent {
  const XpEvent({
    required this.source,
    required this.date,
    required this.xp,
    this.label,
    this.sets = 0,
    this.weightKg,
    this.reps,
  });
  final XpSource source;
  final DateTime date;   // yerel; antrenman ve rekorda finishedAt, öğünde günün başı
  final int xp;
  final String? label;   // antrenman: workoutName; rekor: exerciseName; öğün: null
  final int sets;        // yalnız antrenmanda: sayılan (≤ 30) tamamlanmış set
  final double? weightKg; // yalnız rekorda: en iyi setin kilosu
  final int? reps;        // yalnız rekorda: en iyi setin tekrarı
}

const workoutBaseXp = 50, setXp = 5, maxCountedSets = 30, recordXp = 25, mealDayXp = 10;

/// Eskiden yeniye. Oturumlar finishedAt'e göre sıralanıp işlenir (PR "önceki"ye bakar).
List<XpEvent> xpEvents(List<WorkoutSession> sessions, List<DateTime> mealTimes);
```

- Rekor tahmini `estimateOneRepMax` ile yapılır; kilosuz ya da > 10 tekrarlı setler rekora girmez ama antrenman XP'sine set olarak sayılır.
- Aynı oturumda aynı hareket için en çok bir rekor olayı.
- Öğün günü: `mealTimes` yerel saate çevrilip `DateTime(y, m, d)`'ye indirgenir; benzersiz günler.
- Döküm: `XpBreakdown(workoutXp, setXp, recordXp, mealDayXp)`; antrenman olayının XP'si `workoutBaseXp` ve `sets × setXp` olarak ikiye ayrılır.

## 4. Seviye ve rütbe (`lib/features/gamification/domain/levels.dart`)

```dart
/// n → n+1 için gereken XP.
int xpForNext(int level) => 100 + 25 * (level - 1);

class LevelProgress {
  final int level;        // ≥ 1
  final int xpIntoLevel;  // bu seviyede kazanılan
  final int xpForNext;    // bu seviyeden sonrakine gereken
  double get fraction;    // xpIntoLevel / xpForNext
}

LevelProgress levelFor(int totalXp);
```

Örnek: 0 XP → seviye 1 (0/100); 100 → seviye 2 (0/125); 224 → seviye 2 (124/125); 225 → seviye 3.

Rütbeler (`enum Rank`, sırayla): her biri `minLevel`, `tier` (1–4, dörtlü gruplar) ve `stripes` (1–4, grup içindeki sıra).

| # | Rank | minLevel | TR | EN | tier | stripes |
|---|---|---|---|---|---|---|
| 1 | rookie | 1 | Çaylak | Rookie | 1 | 1 |
| 2 | novice | 5 | Acemi | Novice | 1 | 2 |
| 3 | amateur | 10 | Amatör | Amateur | 1 | 3 |
| 4 | enthusiast | 15 | Hevesli | Enthusiast | 1 | 4 |
| 5 | athlete | 20 | Sporcu | Athlete | 2 | 1 |
| 6 | dedicated | 25 | Azimli | Dedicated | 2 | 2 |
| 7 | determined | 30 | Kararlı | Determined | 2 | 3 |
| 8 | warrior | 35 | Savaşçı | Warrior | 2 | 4 |
| 9 | gladiator | 40 | Gladyatör | Gladiator | 3 | 1 |
| 10 | iron | 45 | Demir | Iron | 3 | 2 |
| 11 | master | 50 | Usta | Master | 3 | 3 |
| 12 | elite | 60 | Elit | Elite | 3 | 4 |
| 13 | champion | 70 | Şampiyon | Champion | 4 | 1 |
| 14 | titan | 80 | Titan | Titan | 4 | 2 |
| 15 | legend | 90 | Efsane | Legend | 4 | 3 |
| 16 | immortal | 100 | Ölümsüz | Immortal | 4 | 4 |

`Rank rankFor(int level)`: `minLevel <= level` olan en yüksek rütbe. 100'den sonra seviye artar, rütbe Ölümsüz kalır.

## 5. Unvanlar (`lib/features/gamification/domain/titles.dart`)

```dart
enum TitleTier { apprentice, master, champion }   // Çırağı / Ustası / Şampiyonu
enum TitleKind { muscle, exercise }

class TitleProgress {
  final TitleKind kind;
  final String subjectId;    // kas adı ya da exerciseId
  final String? exerciseName; // yalnız hareket unvanında
  final TitleTier? tier;      // ulaşılan en yüksek; null = henüz yok
  final double value;         // kas: ağırlıklı set; hareket: oturum sayısı
  final double? nextThreshold; // sonraki kademe eşiği; şampiyonda null
  String get id;              // '<kind>:<subjectId>' — aktif unvan anahtarı
}

const muscleThresholds = {TitleTier.apprentice: 100.0, TitleTier.master: 500.0, TitleTier.champion: 1500.0};
const exerciseThresholds = {TitleTier.apprentice: 10.0, TitleTier.master: 50.0, TitleTier.champion: 150.0};

/// Tüm kas ve hareketler için ilerleme (değeri 0 olanlar hariç).
List<TitleProgress> titleProgress(List<WorkoutSession> sessions, Map<String, Exercise> exercisesById);

/// tier != null olanlar; sıra: kademe yüksekten düşüğe, sonra değer büyükten küçüğe.
List<TitleProgress> earnedTitles(List<TitleProgress> all);

/// Sonraki kademeye en yakın [count] tanesi (value / nextThreshold büyükten küçüğe); şampiyonlar hariç.
List<TitleProgress> upcomingTitles(List<TitleProgress> all, {int count = 3});
```

- Kas değeri: bitmiş oturumlardaki tamamlanmış her set × `muscleWeight(exercise, muscle)`; hareketi `exercisesById`'de olmayan setler kas unvanına katkı vermez.
- Hareket değeri: hareketin en az bir tamamlanmış seti olan bitmiş oturum sayısı. Hareket adı `exercisesById`'den, yoksa setin `exerciseName`'inden.
- Görünen ad:
  - kas: `'gamification.title.<tier>'.tr(namedArgs: {'name': 'gamification.muscle_short.<muscleKey>'.tr()})`
  - hareket: aynı kalıp, `name` = hareket adı.
  - `<muscleKey>`: kas adında boşluk alt çizgiye (`lower back` → `lower_back`), `muscleLabelKey` ile aynı kural.
  - TR kalıpları: `{name} Çırağı`, `{name} Ustası`, `{name} Şampiyonu`; EN: `{name} Apprentice`, `{name} Master`, `{name} Champion`.

## 6. Arayüz

### 6.1 `RankBadge` (`presentation/widgets/rank_badge.dart`)

- `RankBadge({required Rank rank, required int level, double size = 28})`: kalkan biçimli `CustomPaint`; içinde `rank.stripes` kadar üst üste chevron şerit; altında seviye numarası (size ≥ 56 ise).
- Kademe rengi: tier 1 `onSurfaceVariant`, tier 2 `primary` %55, tier 3 `primary`, tier 4 `primary` + bulanık parlama.
- Anahtar dışarıdan verilir; test için `RankBadge` alanları (`rank`, `level`) okunur.

### 6.2 Ana sayfa rozeti (`HomeLevelBadge`)

- `home_screen.dart` AppBar `actions`'ında `home_settings_button`'dan önce.
- Hap biçimi: küçük `RankBadge` + "Sv {n}" (`gamification.level_short`); anahtar `home_level_badge`; dokununca `context.push('/home/levels')`.
- `playerSummaryProvider` yüklenirken ya da hatada gösterilmez (`SizedBox.shrink`).

### 6.3 Seviye ekranı (`LevelScreen`, rota `/home/levels`)

`Scaffold` (`level_screen`), AppBar başlığı "SEVİYE". `ListView` içinde sırayla:

1. **Başlık kartı** (`level_header`): solda büyük `RankBadge` (size 88); sağda rütbe adı (büyük harf), aktif unvan varsa lime hap (`level_active_title`), "SEVİYE {n}", `LinearProgressIndicator` + "{x} / {y} XP" (`level_progress`), soluk "Toplam {n} XP" (`level_total_xp`).
2. **XP dökümü** (`level_breakdown`): 2×2 mevcut `StatTile`'lar: antrenman, setler, rekorlar, öğün günleri.
3. **Unvanlar** (`level_titles`): başlık satırında sağda "{n} açıldı" (`level_titles_count`). Kazanılanlar kart satırları: solda ikon (kas → `Icons.accessibility_new`, hareket → `Icons.fitness_center`), unvan adı, alt satırda ölçüt ("{value} / {threshold} set" ya da "oturum"; şampiyonda yalnız "{value} set/oturum"), sağda düğme. Satır anahtarı `title_<id>`. Aktif olanın kartı lime çerçeveli, düğmesi dolu "TAKILI" (`title_unequip_<id>`, dokununca çıkarır); diğerlerinde çerçeveli "TAK" (`title_equip_<id>`). Hiç unvan yoksa `level_titles_empty`. Altında "YAKINDA" kartı: `upcomingTitles` satırları, sağda "{value} / {threshold} set|oturum", altında lime ilerleme çubuğu (`upcoming_<id>`).
4. **Rütbe merdiveni** (`level_ladder`): 16 rütbe yatay kaydırılan kart satırı (kart ~120 px). Kartta küçük `RankBadge` (ya da geçilmişse lime onay dairesi), "Sv {minLevel}", rütbe adı ve durum hapı: "GEÇİLDİ" / "ŞU AN" / kilit ikonu (`ladder_<rank.name>`). Mevcut olan lime çerçeveli ve parlamalı; kilitliler %40 opaklık. Açılışta mevcut rütbe görünür olacak şekilde kaydırılır.
5. **Son kazanımlar** (`level_recent`): son 10 olay yeniden eskiye, kart satırları (`recent_<index>`): solda ikon (antrenman `Icons.fitness_center`, rekor `Icons.bolt`, öğün `Icons.restaurant`), başlık (antrenman → workoutName; rekor → "Rekor: {exerciseName}"; öğün → "Öğün kaydı"), alt satır (antrenman → "{sets} set"; rekor → "{kg} kg × {reps}"; öğün → yok), sağda lime "+{xp} XP" hapı ve altında soluk tarih (`d MMM`). Olay yoksa `level_recent_empty`.

Yükleme: ortada `CircularProgressIndicator`. Hata: "tekrar dene" (`level_retry`) → `allSessionsProvider`, `mealTimesProvider`, `exercisesProvider` yenilenir.

### 6.4 Aktif unvan

- `activeTitleProvider` (`AsyncNotifier<String?>`): SharedPreferences anahtarı `gamification.active_title`; `equip(String id)`, `unequip()`.
- Gösterilen aktif unvan: kayıtlı id `earnedTitles` içinde varsa o; yoksa yok (kayıt silinmez; tekrar kazanılırsa geri gelir).

### 6.5 Çeviriler (`tr.json`, `en.json`, yeni `gamification` bloğu)

`title` (Seviye / Level), `level_short` (Sv {n} / Lv {n}), `level` (SEVİYE {n} / LEVEL {n}), `progress` ({x} / {y} XP), `total_xp` (Toplam {n} XP / Total {n} XP), `breakdown_title`, `breakdown_workouts`, `breakdown_sets`, `breakdown_records`, `breakdown_meal_days`, `titles_title`, `titles_count` ({n} açıldı / {n} unlocked), `titles_empty`, `upcoming_title`, `equipped` (TAKILI / EQUIPPED), `equip` (TAK / EQUIP), `criterion_sets` ({value} / {threshold} set), `criterion_sessions` ({value} / {threshold} oturum), `value_sets` ({value} set), `value_sessions` ({value} oturum), `ladder_title`, `ladder_passed` (GEÇİLDİ / PASSED), `ladder_current` (ŞU AN / CURRENT), `recent_title`, `recent_empty`, `record` (Rekor: {name}), `record_detail` ({kg} kg × {reps}), `workout_sets` ({n} set), `meal_day` (Öğün kaydı), `xp_gain` (+{n} XP), `retry`; `rank.<rank.name>` (16); `muscle_short.<muscleKey>` (17); `title.apprentice|master|champion` ({name} Çırağı / Ustası / Şampiyonu).

Kısa kas adları (TR / EN): abdominals Karın / Abs, abductors Abdüktör / Abductors, adductors Addüktör / Adductors, biceps Biseps / Biceps, calves Baldır / Calves, chest Göğüs / Chest, forearms Ön kol / Forearms, glutes Kalça / Glutes, hamstrings Arka bacak / Hamstrings, lats Kanat / Lats, lower_back Alt sırt / Lower Back, middle_back Orta sırt / Middle Back, neck Boyun / Neck, quadriceps Ön bacak / Quads, shoulders Omuz / Shoulders, traps Trapez / Traps, triceps Triseps / Triceps.

## 7. Veri ve sağlayıcılar

- `ProgressDataRepository.fetchMealTimes()` → `Future<List<DateTime>>`: `meals` tablosundan yalnızca `logged_at`, sıralı; `DateTime.parse(...).toLocal()`.
- `lib/features/gamification/application/gamification_providers.dart`:
  - `mealTimesProvider` (`FutureProvider.autoDispose<List<DateTime>>`; giriş yoksa boş).
  - `playerSummaryProvider` (`FutureProvider.autoDispose<PlayerSummary>`): `allSessionsProvider`, `mealTimesProvider`, `exercisesByIdProvider`.
  - `activeTitleProvider` (§6.4).
- `lib/features/gamification/domain/player_summary.dart`:

```dart
class PlayerSummary {
  final int totalXp;
  final LevelProgress progress;
  final Rank rank;
  final XpBreakdown breakdown;
  final List<XpEvent> recent;          // son 10, yeniden eskiye
  final List<TitleProgress> titles;    // earnedTitles
  final List<TitleProgress> upcoming;  // upcomingTitles
}

PlayerSummary playerSummary(List<WorkoutSession> sessions, List<DateTime> mealTimes, Map<String, Exercise> exercisesById);
```

- Tazelik: antrenman bitince ve öğün kaydedilince `allSessionsProvider` / `mealTimesProvider` geçersiz kılınır (plan, mevcut geçersiz kılma noktalarını bulup ekler).

## 8. Hata ve kenar durumları

- Hiç veri yok: 0 XP, seviye 1, Çaylak; unvan ve kazanım listelerinde boş metinler.
- Devam eden oturum XP vermez.
- Rekor için önceki oturumda tahmin yoksa (hep kilosuz ya da > 10 tekrar) ilk tahminli oturum PR sayılmaz; "önceki en iyi" yalnızca tahmini olan oturumlardan oluşur.
- Saat dilimi: öğün günü ve olay tarihleri yerel saatle.
- SharedPreferences okunamazsa aktif unvan yok sayılır.

## 9. Testler (TDD)

- **Domain:**
  - `xp_rules_test`: taban + set XP; 30 set sınırı; setsiz oturum yok; devam eden oturum yok; PR yalnızca önceki en iyiyi aşınca; ilk yapılış PR değil; aynı oturumda tek PR; öğün günü tekilleştirme ve yerel gün; döküm toplamları.
  - `levels_test`: 0 / 99 / 100 / 224 / 225 XP; `xpForNext`; `rankFor` 1, 4, 5, 34, 35, 99, 100, 150; tier/stripes tablosu.
  - `titles_test`: kas ağırlıklı değer (birincil 1, ikincil 0,5); hareket oturum sayısı; kademe eşikleri (99.5 → yok, 100 → çırak, 1500 → şampiyon, nextThreshold null); `earnedTitles` sırası; `upcomingTitles` sırası ve şampiyon hariç.
  - `player_summary_test`: birleşim, son 10 olay sırası.
- **Sağlayıcı:** `playerSummaryProvider` sahte depolarla; `activeTitleProvider` tak/çıkar ve kalıcılık (`SharedPreferences.setMockInitialValues`).
- **Widget:** `RankBadge` alanları ve boyut; `HomeLevelBadge` yükleniyorken gizli, veriyle "Sv n" ve dokununca `/home/levels`.
- **Ekran:** beş bölüm anahtarları; boş veride boş metinler; TAK → başlıkta aktif unvan ve düğme TAKILI; TAKILI'ya dokun → kaybolur; merdivende 16 öğe; rekor kazanımında kilo × tekrar.
- **Ana sayfa testi:** mevcut testler geçer (sağlayıcı override'ı eklenir).

## 10. Sonraki fazlar (çerçeve; her biri kendi soru-cevap turuyla netleşir)

- **S1 — Arkadaşlık temeli:** kullanıcı adı + görünen ad; kullanıcı adı/davet koduyla arkadaşlık isteği, kabul/ret; arkadaş listesi; arkadaş profili (rütbe, seviye, unvanlar, son antrenmanlar, haftalık özet); gizlilik ayarı. Uygulama `PlayerSummary`'den türetilen `player_stats` satırını yazar, arkadaşlar okur. Tablolar, RLS, fonksiyonlar.
- **S2 — Topluluklar:** topluluk kurma, davet kodu, üyeler; haftalık/aylık sıralama (XP, set); topluluk içi dönem unvanları ("Haftanın Kanat Şampiyonu"), sahipleri dönem sonunda değişir; üyelerin ilerlemesi.
- **S3 — Meydan okumalar:** arkadaşa ya da topluluğa süreli meydan okuma ("7 günde en çok set", "bu hafta 4 antrenman"); canlı ilerleme, kazanan, XP ödülü.

## 11. Dal, sıra, manuel kontrol

- Dal: `f5p-oyunlastirma`. Sıra: domain (XP → seviye/rütbe → unvanlar → özet) → veri + sağlayıcılar → rozet widget'ı + ana sayfa → seviye ekranı → doğrulama.
- Migration / deploy yok. Tam test paketi ve web release derlemesi kullanıcının terminalinde.

Manuel kontrol listesi:
1. Ana sayfada dişlinin yanında rütbe rozeti ve "Sv n" görünüyor; dokununca seviye ekranı açılıyor.
2. Mevcut geçmişle seviye, rütbe ve toplam XP makul (geçmişe dönük hesap).
3. XP dökümü toplamı toplam XP'ye eşit.
4. Yeni bir antrenman bitirince rozet ve ekran güncelleniyor; rekor kırılınca "Rekor: …" kazanımı görünüyor.
5. Öğün kaydedilen gün "Öğün kaydı · +10 XP" olarak bir kez görünüyor.
6. Unvanlar mantıklı; TAK → başlıkta görünüyor, uygulama yenilenince de duruyor; TAKILI'ya dokununca kayboluyor.
7. Rütbe merdiveni mevcut rütbeye kaydırılmış; kilitliler soluk.
8. Yaklaşık 360 px genişlikte taşma yok; EN dilinde metinler doğru.
