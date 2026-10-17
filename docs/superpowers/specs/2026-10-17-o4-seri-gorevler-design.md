# O4 — Günlük Seri ve Haftalık Görevler — Tasarım Spec'i

Tarih: 2026-10-17 · Dal: `o4-seri-gorevler` · Migration: yok

## 1. Bağlam

Oyunlaştırma v2 yol haritası: N2 → O3a XP makullük kuralları → **O4 seri + haftalık görevler** (bu spec) → O2 karakter/canavar savaşı → O5 rozetler → O3b sunucu tarafı XP. XP her açılışta tüm geçmişten istemcide yeniden hesaplanıyor (`xpEvents`, O1 spec §3) ve O3a'nın oturum kararları (`judgeSessions`) neyin sayıldığını belirliyor. Uygulamada henüz seri yok; ana sayfada yalnız "bu hafta X antrenman" kutusu var. O2'deki Tutarlılık statı ileride bu seriyi kullanacak.

## 2. Kararlar (kullanıcıyla onaylı)

1. **Günlük seri**: bir gün, sayılan antrenman ya da dinlenme günüyse seriyi sürdürür.
2. **Dinlenme**: her ISO haftada `7 − G` dinlenme hakkı (G = haftalık hedef); hangi gün dinlenileceği serbest.
3. **Seri ödülü**: antrenman XP'sine seri uzunluğuna göre çarpan.
4. **Görevler**: 10 görevlik havuzdan haftada 3 görev, hafta + kullanıcı id'siyle belirlenimli seçim; sunucu/tablo yok.
5. **Görev ödülü**: görev başına 40 XP, üçü bitince +60 XP; tüm geçmiş haftalara uygulanır.
6. **Yerleşim**: ana sayfada seviye rozetinin yanında küçük hap; Seviye ekranında seri ve görev kartları.
7. Yaklaşım A: saf modüller (`streak.dart`, `quests.dart`), olaylar bir kez hesaplanıp tüm tüketicilerce paylaşılır.

## 3. Seri (`lib/features/gamification/domain/streak.dart`)

### 3.1 Haftalık hedef

`G` = aktif programın `effectiveDaysPerWeek`'i; yoksa (program yok ya da null) profilin `exerciseDaysPerWeek`'i; o da yoksa 3. `G`, `[2, 6]` aralığına sıkıştırılır. Haftalık dinlenme hakkı `7 − G` (1…5).

### 3.2 Gün gün hesap

`List<StreakDay> streakDays(List<SessionVerdict> verdicts, {required int weeklyGoal, required DateTime today})`:

1. Antrenman günleri: `counted` kararların `finishedAt` yerel günleri.
2. İlk antrenman gününden başlayıp `today`'e kadar her gün eskiden yeniye:
   - Antrenman günü → `StreakDayKind.workout`, seri +1.
   - Değilse ve gün `today` ise → `pending` (hak harcanmaz, seri değişmez).
   - Değilse ve o ISO haftada (pazartesi başlangıçlı, `startOfWeek`) harcanan hak `< 7 − G` ise → `rest`, hak harcanır, seri +1.
   - Değilse → `broken`, seri 0. Sonraki antrenman günü seriyi 1'den başlatır; seri 0'ken antrenmansız günler `broken` kalır ve hak harcamaz.
3. `StreakDay { DateTime day; StreakDayKind kind; int length; }` — `length`, o günün sonundaki seri uzunluğu.

Antrenman yoksa liste boş. Çarpan (§3.3) yalnız antrenman günlerinin `length`'ini kullandığı için `xpEvents` `today` olarak son antrenman gününü verir; `now`'a bağlı değildir.

### 3.3 Çarpan

```dart
const streakBonusStepDays = 7;
const streakBonusStep = 0.05;
const maxStreakBonus = 0.25;
double streakBonusRate(int length) => min(maxStreakBonus, (length ~/ streakBonusStepDays) * streakBonusStep);
```

Sayılan antrenman olayının XP'si: `base = 50 + 5 × sets`, `bonus = (base × streakBonusRate(o günün length'i)).floor()`, `xp = base + bonus`. Rekor, öğün, görev ve meydan okuma XP'si çarpandan etkilenmez. Aynı günün iki antrenmanı da o günün `length`'ini kullanır.

### 3.4 Güncel durum

`StreakStatus { int length; double bonusRate; int restLeft; bool broken; }` — `length`: dünün sonundaki seri, bugün antrenman varsa bugünün; `restLeft`: bu ISO hafta kalan hak; `broken`: son gün (bugün `pending` ise dün) `broken` ya da hiç antrenman yok.

### 3.5 Kabul edilen yan etki

Geçmiş bugünkü hedefe göre yorumlanır; program değiştirmek eski serileri ve XP'yi değiştirebilir (O3a'nın "tüm geçmişe" kararıyla tutarlı).

## 4. Haftalık görevler (`lib/features/gamification/domain/quests.dart`)

### 4.1 Havuz

| Kategori | `QuestKind` | Hedef | İlerleme |
|---|---|---|---|
| Antrenman | `workouts` | `G` | sayılan oturum |
| | `sets` | önceki 4 haftanın ortalama sayılan seti × 1,1, 5'e yukarı yuvarlanır; `[15, 60]` | sayılan set |
| | `volume` | önceki 4 haftanın ortalama hacmi × 1,1, 500'e yukarı yuvarlanır; en az 3000 kg | sayılan setlerin kg × tekrar toplamı |
| | `long` | 2 | süresi ≥ 45 dk sayılan oturum |
| Güç / çeşitlilik | `record` | 1 | XP getiren rekor olayı |
| | `muscle` | 8 | tohumla seçilen kas grubunda `muscleWeight` toplamı |
| | `variety` | 4 | `muscleWeight` toplamı ≥ 3 olan kas grubu sayısı |
| | `weekend` | 1 | cumartesi/pazar biten sayılan oturum |
| Beslenme / denge | `mealDays` | 5 | öğün kaydı olan gün |
| | `fullDays` | 3 | hem sayılan oturum hem öğün kaydı olan gün |

Ortalama: hedefin hesaplandığı haftadan önceki 4 ISO haftanın toplamı / 4 (hiç veri yoksa alt sınır). Kas grupları `muscleGroups` (exercise_taxonomy); kası bilinmeyen hareket `muscle`/`variety`'ye katkı vermez.

### 4.2 Seçim

`seed = fnv1a32(userId + weekKey(weekStart))` (kararlı 32-bit FNV-1a; Dart `hashCode` platformlar arası garanti değil). Her kategoriden bir görev: kategori listesinde `index = (seed >> (8 × kategoriSırası)) % kategoriUzunluğu`. `muscle` görevinin kas grubu: `muscleGroups[(seed >> 24) % muscleGroups.length]`.

### 4.3 Olaylar

- Haftalar: ilk etkinliğin (ilk sayılan oturum ya da ilk öğün) haftasından son etkinliğin haftasına kadar.
- Her görev, ilerlemesi hedefe ilk ulaştığı anda tamamlanır; olay tarihi o anı getiren antrenmanın `finishedAt`'ı ya da o günün ilk öğün zamanı (yerel). Rekor görevi için rekor olayının tarihi.
- Her tamamlanan görev: `XpEvent(source: XpSource.quest, xp: 40, label: kind.name, date: ...)`.
- Üçü de tamamlanırsa: `XpEvent(source: XpSource.quest, xp: 60, label: 'all', date: üçüncünün tarihi)`.
- `label` görev türünü (`workouts`, …, `all`) taşır; `muscle` görevinin kas grubu için `XpEvent`'e `String? muscle` alanı eklenir.
- Rekor görevi rekor olaylarına bağlı olduğundan görev olayları, antrenman ve rekor olayları üretildikten sonra hesaplanır.

### 4.4 Güncel durum

`WeekQuests { DateTime weekStart; List<QuestProgress> quests; bool bonusDone; }`, `QuestProgress { QuestKind kind; String? muscle; double progress; double target; bool done; }`. Kalan süre arayüzde `periodRemaining(PeriodKind.week, now)` ile.

## 5. Mimari

- `class GameSettings { final int weeklyGoal; final String? userId; }` — `gameSettingsProvider`: `todayWorkoutProvider` → `programOf(...)?.effectiveDaysPerWeek`, yoksa `profileProvider` → `exerciseDaysPerWeek`, yoksa 3; `[2, 6]`'ya sıkıştırılır. Yükleme hatasında 3. `userId` oturumdaki kullanıcı.
- `xpEvents(sessions, mealTimes, {Map<String, Exercise> exercisesById = const {}, GameSettings? settings})`: `settings` null ise bugünkü davranış (seri bonusu ve görev yok); arkadaşlara açık son antrenmanların rekor listesi (`player_stats.dart`) bu şekilde kalır. `settings` verilip `userId` null ise seri bonusu var, görev yok.
- `xpEventsProvider` (sessions, mealTimes, exercisesById, settings) olayları bir kez hesaplar. `playerSummaryProvider`, `myChallengeValueProvider` ve dönem istatistiği yayını (`buildPeriodStats`) bu listeyi kullanır; `buildPeriodStats` olayları parametre olarak alır.
- `PlayerSummary`'ye `StreakStatus streak` ve `WeekQuests? quests` eklenir (`playerSummary(..., settings, now)`).
- `XpBreakdown`'a `streak` (bonusların toplamı) ve `quests` eklenir; antrenman olayına `int streakBonus` alanı.

## 6. Arayüz

- **Ana sayfa hapı** (`home_streak_chip`, `HomeLevelBadge`'in yanında): "🔥 12 · 1/3"; seri 0 ise yalnız görev sayısı. Özet yüklenirken/hatada görünmez. Dokununca `/home/levels`.
- **Seviye ekranı**, döküm kartının üstünde:
  - Seri kartı (`level_streak_card`): alev + gün sayısı, "+%10 antrenman XP'si", "Bu hafta 2 dinlenme hakkın kaldı"; `broken` ise "Bugün antrenman yaparak yeni seri başlat".
  - Görev kartı (`level_quests_card`): 3 satır (simge, metin, ilerleme çubuğu, "+40 XP", bitende tik), altında "Üçü bitince +60 XP" ve kalan süre.
- XP geçmişi: görev satırı "Görev: 5 gün öğün kaydı", bonus "Haftalık görevlerin hepsi"; antrenman alt yazısında bonus varsa "seri +%10".
- Döküm: "Seri bonusu" ve "Haftalık görevler" satırları.
- Kurallar sayfasına iki madde: seri (dinlenme hakkı, %5/7 gün, en çok %25) ve görevler (40 XP, üçü +60).
- Çeviriler `gamification` bölümüne, tr ve en.

## 7. Hata durumları

- Profil/program yüklenemezse `G = 3`.
- Giriş yoksa görev yok, seri bonusu var.
- Hafta sınırı yerel pazartesi 00:00 (`startOfWeek`).
- Hacim: kilosuz set 0 katkı.

## 8. Test

- `streak_test.dart`: antrenman/dinlenme/kırılma sırası; hak haftalık yenilenir; `pending` bugün hak harcamaz; seri 0'ken antrenmansız gün hak harcamaz; çarpan basamakları (6→0, 7→%5, 35→%25, 70→%25); `StreakStatus`.
- `quests_test.dart`: `fnv1a32` bilinen değer; aynı tohum aynı görevler, her kategoriden bir; her görevin ilerlemesi ve tamamlanma tarihi; 4 haftalık ölçekleme ve sınırlar; bonus; geçmiş hafta olayları; sayılmayan oturum katkı vermez.
- `xp_rules_test.dart`: seri bonusu antrenman XP'sine eklenir, `settings` null iken değişmez; döküm `streak` ve `quests`.
- `period_stats_test.dart`, `challenge_progress_test.dart`, `gamification_providers_test.dart`: olay paylaşımına göre güncellenir.
- Widget: ana sayfa hapı, seri kartı, görev kartı, XP geçmişi satırları.
- Elle (web release): hap, kartlar, bir görevin tamamlanınca XP'ye yansıması, tr/en, 360 px.
