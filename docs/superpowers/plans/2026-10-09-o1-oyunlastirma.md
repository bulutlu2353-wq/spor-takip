# O1 Kişisel Oyunlaştırma Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Kullanıcının geçmişinden XP, seviye, 16 rütbe ve kalıcı kas/hareket unvanları hesaplamak; ana sayfadaki rozetten açılan seviye ekranında göstermek.

**Architecture:** Saf domain (`lib/features/gamification/domain/`) oturumlardan ve öğün zamanlarından XP olaylarını, seviye/rütbeyi ve unvan ilerlemesini üretir; `playerSummary` hepsini birleştirir. Sağlayıcılar mevcut `allSessionsProvider`, yeni hafif `mealTimesProvider` ve `exercisesByIdProvider`'ı birleştirir; aktif unvan SharedPreferences'ta. Migration yok.

**Tech Stack:** Flutter, flutter_riverpod 3, go_router, easy_localization, shared_preferences, flutter_test.

**Spec:** `docs/superpowers/specs/2026-10-09-o1-oyunlastirma-design.md`

## Global Constraints

- Dal: `f5p-oyunlastirma`. Migration / deploy yok.
- Görevlerde yalnızca ilgili test dosyaları çalıştırılır: `flutter test --no-pub -j 1 <dosya>`. Tam paketi kullanıcı kendi terminalinde çalıştırır (Task 7).
- `flutter analyze --no-pub` arka planda; sonuç "No issues found!".
- `dart format` çalıştırılmaz; mevcut biçime elle uyulur, satırlar ≤ ~120 karakter.
- Testlerde çeviriler yüklenmez; `.tr()` ham anahtarı döndürür. Sayılar domain testlerinde doğrulanır.
- XP: antrenman `50 + 5 × min(tamamlanan set, 30)`; rekor hareket başına 25; öğün günü 10.
- Seviye: n → n+1 için `100 + 25 × (n − 1)` XP; seviye 1 = 0 XP.
- Unvan eşikleri: kas 100 / 500 / 1500 ağırlıklı set; hareket 10 / 50 / 150 oturum.
- Aktif unvan anahtarı (SharedPreferences): `gamification.active_title`; değer `TitleProgress.id` (`muscle:<kas>` ya da `exercise:<exerciseId>`).
- Rota: `/home/levels`.
- Commit mesajları şu satırla biter: `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`
- Bash aracı her komutta `commit-graph` / CRLF uyarıları basar; zararsız.

## Spec'ten bilinçli sapmalar (kullanıcıya bildirilecek)

1. **`LevelProgress.xpNeeded`:** Spec alanı `xpForNext` diyordu; aynı adlı üst düzey fonksiyonla çakışmasın diye alan `xpNeeded` oldu.
2. **XP sabit adları:** `xpPerWorkout`, `xpPerSet`, `maxCountedSets`, `xpPerRecord`, `xpPerMealDay`; döküm alanları `workouts`, `sets`, `records`, `mealDays` (alan/sabit çakışmasını önlemek için).
3. **`mealTimesProvider` `progress_providers.dart`'ta:** `weeklyMealsProvider`'ın yanında; beslenme ve sohbet kodu oyunlaştırma klasörünü import etmek zorunda kalmaz.
4. **Aktif unvan seçimi `PlayerSummary.titleById`:** Spec §6.4'teki kural domain'de bir metot olarak.
5. **`TitleProgress.nextTier`:** "Yakında" satırında bir sonraki kademenin adı ("Omuz Ustası") gösterilsin diye eklendi.
6. **Merdiven testi:** Yatay liste tembel kurulduğu için test 16 öğeyi değil, mevcut ve önceki rütbe kartlarını doğrular.
7. **Unvan kalıbı anahtarı `gamification.title_tier.<tier>`:** Spec `title.<tier>` diyordu; `gamification.title` ekran başlığı olduğu için çakışmasın diye.

## Dosya yapısı

| Dosya | Görev |
|---|---|
| `lib/features/gamification/domain/xp_rules.dart` | `XpSource`, `XpEvent`, sabitler, `xpEvents`, `XpBreakdown`, `xpBreakdown` |
| `lib/features/gamification/domain/levels.dart` | `xpForNext`, `LevelProgress`, `levelFor`, `Rank`, `rankFor` |
| `lib/features/gamification/domain/titles.dart` | `TitleTier`, `TitleKind`, eşikler, `TitleProgress`, `titleProgress`, `earnedTitles`, `upcomingTitles` |
| `lib/features/gamification/domain/player_summary.dart` | `PlayerSummary`, `playerSummary` |
| `lib/features/gamification/application/gamification_providers.dart` | `playerSummaryProvider`, `ActiveTitle`, `activeTitleProvider` |
| `lib/features/gamification/presentation/widgets/rank_badge.dart` | `RankBadge` |
| `lib/features/gamification/presentation/widgets/home_level_badge.dart` | `HomeLevelBadge` |
| `lib/features/gamification/presentation/title_names.dart` | `titleName`, `titleCriterion` |
| `lib/features/gamification/presentation/level_screen.dart` | `LevelScreen` |
| `lib/features/progress/data/progress_data_repository.dart` | `fetchMealTimes` |
| `lib/features/progress/application/progress_providers.dart` | `mealTimesProvider` |
| `lib/features/nutrition/application/meal_capture_notifier.dart`, `lib/features/chat/application/chat_refresh.dart` | `mealTimesProvider`'ı geçersiz kılma |
| `lib/features/onboarding/presentation/home_screen.dart` | AppBar'a `HomeLevelBadge` |
| `lib/core/router.dart` | `/home/levels` |
| `assets/translations/tr.json`, `en.json` | `gamification` bloğu |
| `test/features/gamification/game_fixtures.dart` | Ortak test verisi |
| `test/features/gamification/domain/*_test.dart`, `application/gamification_providers_test.dart`, `presentation/*_test.dart` | Testler |
| `test/features/progress/fakes.dart` | Sahte depoya `fetchMealTimes` |
| `test/features/onboarding/presentation/home_screen_test.dart` | Rozet override'ı ve testi |

---

### Task 1: XP kuralları

**Files:**
- Create: `lib/features/gamification/domain/xp_rules.dart`
- Create: `test/features/gamification/game_fixtures.dart`
- Test: `test/features/gamification/domain/xp_rules_test.dart`

**Interfaces:**
- Consumes: `estimateOneRepMax({double? weightKg, int? reps})` (`lib/features/progress/domain/strength.dart`); `WorkoutSession`, `SessionSet` (`lib/features/workout/domain/workout_session.dart`).
- Produces:
  - `enum XpSource { workout, record, mealDay }`
  - `class XpEvent { XpSource source; DateTime date; int xp; String? label; int sets; double? weightKg; int? reps; }`
  - `const xpPerWorkout = 50, xpPerSet = 5, maxCountedSets = 30, xpPerRecord = 25, xpPerMealDay = 10;`
  - `List<XpEvent> xpEvents(List<WorkoutSession> sessions, List<DateTime> mealTimes)` — eskiden yeniye; aynı anda `workout` → `record` → `mealDay`.
  - `class XpBreakdown { int workouts, sets, records, mealDays; int get total; }`
  - `XpBreakdown xpBreakdown(List<XpEvent> events)`
  - Test yardımcıları: `gameSet`, `gameSession`, `gameBench`, `gameSquat`, `gameExercisesById`.

- [ ] **Step 1: Ortak test verisini yaz**

`test/features/gamification/game_fixtures.dart`:

```dart
import 'package:spor_takip/features/workout/domain/exercise.dart';
import 'package:spor_takip/features/workout/domain/workout_session.dart';

const gameBench = Exercise(
  id: 'bench',
  name: 'Barbell Bench Press',
  primaryMuscles: ['chest'],
  secondaryMuscles: ['triceps'],
);
const gameSquat = Exercise(id: 'squat', name: 'Barbell Squat', primaryMuscles: ['quadriceps']);
final gameExercisesById = {gameBench.id: gameBench, gameSquat.id: gameSquat};

SessionSet gameSet(String exerciseId, {double? kg, int? reps, bool done = true, int index = 0}) => SessionSet(
      exercisePosition: 0,
      setIndex: index,
      exerciseId: exerciseId,
      exerciseName: exerciseId == 'bench' ? 'Barbell Bench Press' : 'Barbell Squat',
      targetRepsMin: 5,
      targetRepsMax: 5,
      weightKg: kg,
      reps: reps,
      completedAt: done ? DateTime(2026, 10, 1) : null,
    );

/// [finishedAt] null → devam eden oturum. Tarihler yerel.
WorkoutSession gameSession(String id, DateTime? finishedAt, List<SessionSet> sets, {String workoutName = 'Push A'}) =>
    WorkoutSession(
      id: id,
      programName: 'P',
      workoutName: workoutName,
      workoutPosition: 0,
      startedAt: (finishedAt ?? DateTime(2026, 10, 1)).subtract(const Duration(hours: 1)),
      finishedAt: finishedAt,
      sets: sets,
    );

/// [count] tamamlanmış set.
List<SessionSet> gameSets(String exerciseId, int count, {double? kg, int? reps}) =>
    [for (var i = 0; i < count; i++) gameSet(exerciseId, kg: kg, reps: reps, index: i)];
```

- [ ] **Step 2: Başarısız testleri yaz**

`test/features/gamification/domain/xp_rules_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:spor_takip/features/gamification/domain/xp_rules.dart';

import '../game_fixtures.dart';

void main() {
  test('a finished workout gives 50 plus 5 per completed set', () {
    final events = xpEvents([
      gameSession('a', DateTime(2026, 10, 1, 18), [...gameSets('bench', 3), gameSet('bench', done: false)]),
    ], const []);
    expect(events, hasLength(1));
    expect(events.single.source, XpSource.workout);
    expect(events.single.xp, 65);
    expect(events.single.sets, 3);
    expect(events.single.label, 'Push A');
    expect(events.single.date, DateTime(2026, 10, 1, 18));
  });

  test('set XP stops at 30 sets', () {
    final events = xpEvents([gameSession('a', DateTime(2026, 10, 1), gameSets('bench', 40))], const []);
    expect(events.single.xp, 200);
    expect(events.single.sets, 30);
  });

  test('sessions without completed sets and unfinished sessions give nothing', () {
    final events = xpEvents([
      gameSession('empty', DateTime(2026, 10, 1), [gameSet('bench', done: false)]),
      gameSession('live', null, gameSets('bench', 5)),
    ], const []);
    expect(events, isEmpty);
  });

  test('a record needs to beat the best of earlier sessions, once per exercise', () {
    final events = xpEvents([
      // İlk yapılış: 100×5 ≈ 116.7 — rekor değil.
      gameSession('s1', DateTime(2026, 10, 1), [gameSet('bench', kg: 100, reps: 5)]),
      // 100×6 = 120 ve 100×7 ≈ 123.3 → tek rekor, en iyi set; squat ilk kez → rekor değil.
      gameSession('s2', DateTime(2026, 10, 3), [
        gameSet('bench', kg: 100, reps: 6),
        gameSet('bench', kg: 100, reps: 7, index: 1),
        gameSet('squat', kg: 140, reps: 3),
      ]),
      // 100×5 önceki en iyiyi geçmez.
      gameSession('s3', DateTime(2026, 10, 5), [gameSet('bench', kg: 100, reps: 5)]),
    ], const []);
    final records = [for (final e in events) if (e.source == XpSource.record) e];
    expect(records, hasLength(1));
    expect(records.single.xp, 25);
    expect(records.single.label, 'Barbell Bench Press');
    expect(records.single.weightKg, 100);
    expect(records.single.reps, 7);
    expect(records.single.date, DateTime(2026, 10, 3));
  });

  test('sets over ten reps never count as the earlier best', () {
    final events = xpEvents([
      gameSession('s1', DateTime(2026, 10, 1), [gameSet('bench', kg: 60, reps: 12)]),
      gameSession('s2', DateTime(2026, 10, 2), [gameSet('bench', kg: 60, reps: 5)]),
    ], const []);
    expect(events.where((e) => e.source == XpSource.record), isEmpty);
  });

  test('meal days count once per local day and sort with workouts by time', () {
    final events = xpEvents(
      [gameSession('a', DateTime(2026, 10, 1, 18), gameSets('bench', 1))],
      [DateTime(2026, 10, 1, 8), DateTime(2026, 10, 1, 20), DateTime(2026, 10, 2, 9)],
    );
    expect([for (final e in events) (e.source, e.date)], [
      (XpSource.mealDay, DateTime(2026, 10, 1)),
      (XpSource.workout, DateTime(2026, 10, 1, 18)),
      (XpSource.mealDay, DateTime(2026, 10, 2)),
    ]);
    expect(events.first.xp, 10);
  });

  test('the breakdown splits workout XP into base and sets', () {
    final events = xpEvents([
      gameSession('s1', DateTime(2026, 10, 1), [gameSet('bench', kg: 100, reps: 5)]),
      gameSession('s2', DateTime(2026, 10, 2), [...gameSets('bench', 3, kg: 100, reps: 8)]),
    ], [DateTime(2026, 10, 1, 12)]);
    final breakdown = xpBreakdown(events);
    expect(breakdown.workouts, 100);
    expect(breakdown.sets, 20);
    expect(breakdown.records, 25);
    expect(breakdown.mealDays, 10);
    expect(breakdown.total, 155);
  });
}
```

- [ ] **Step 3: Testin başarısız olduğunu gör**

Run: `flutter test --no-pub -j 1 test/features/gamification/domain/xp_rules_test.dart`
Expected: FAIL — `xp_rules.dart` bulunamıyor.

- [ ] **Step 4: XP kurallarını yaz**

`lib/features/gamification/domain/xp_rules.dart`:

```dart
import 'dart:math' as math;

import '../../progress/domain/strength.dart';
import '../../workout/domain/workout_session.dart';

/// XP olayının kaynağı (O1 spec §3).
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

  /// Yerel: antrenman ve rekorda bitiş, öğünde günün başı.
  final DateTime date;
  final int xp;

  /// Antrenman: antrenman adı; rekor: hareket adı; öğün: null.
  final String? label;

  /// Yalnız antrenmanda: sayılan (≤ [maxCountedSets]) tamamlanmış set.
  final int sets;

  /// Yalnız rekorda: en iyi setin kilosu ve tekrarı.
  final double? weightKg;
  final int? reps;
}

const xpPerWorkout = 50;
const xpPerSet = 5;
const maxCountedSets = 30;
const xpPerRecord = 25;
const xpPerMealDay = 10;

/// Eskiden yeniye; aynı anda antrenman → rekor → öğün.
List<XpEvent> xpEvents(List<WorkoutSession> sessions, List<DateTime> mealTimes) {
  final events = <XpEvent>[];
  final finished = [
    for (final s in sessions)
      if (s.finishedAt != null) s,
  ]..sort((a, b) => a.finishedAt!.compareTo(b.finishedAt!));
  final bestSoFar = <String, double>{};
  for (final session in finished) {
    final completed = [
      for (final set in session.sets)
        if (set.isCompleted) set,
    ];
    if (completed.isEmpty) continue;
    final date = session.finishedAt!.toLocal();
    final counted = math.min(completed.length, maxCountedSets);
    events.add(XpEvent(
      source: XpSource.workout,
      date: date,
      xp: xpPerWorkout + counted * xpPerSet,
      label: session.workoutName,
      sets: counted,
    ));

    final bestSet = <String, SessionSet>{};
    final bestEstimate = <String, double>{};
    for (final set in completed) {
      final estimate = estimateOneRepMax(weightKg: set.weightKg, reps: set.reps);
      if (estimate == null) continue;
      if (estimate > (bestEstimate[set.exerciseId] ?? 0)) {
        bestEstimate[set.exerciseId] = estimate;
        bestSet[set.exerciseId] = set;
      }
    }
    for (final MapEntry(key: exerciseId, value: estimate) in bestEstimate.entries) {
      final previous = bestSoFar[exerciseId];
      if (previous != null && estimate > previous) {
        final set = bestSet[exerciseId]!;
        events.add(XpEvent(
          source: XpSource.record,
          date: date,
          xp: xpPerRecord,
          label: set.exerciseName,
          weightKg: set.weightKg,
          reps: set.reps,
        ));
      }
      if (previous == null || estimate > previous) bestSoFar[exerciseId] = estimate;
    }
  }

  final days = <DateTime>{
    for (final time in mealTimes)
      if (time.toLocal() case final local) DateTime(local.year, local.month, local.day),
  };
  for (final day in days) {
    events.add(XpEvent(source: XpSource.mealDay, date: day, xp: xpPerMealDay));
  }

  events.sort((a, b) {
    final byDate = a.date.compareTo(b.date);
    return byDate != 0 ? byDate : a.source.index.compareTo(b.source.index);
  });
  return events;
}

/// Seviye ekranındaki döküm: antrenman tabanı, setler, rekorlar, öğün günleri.
class XpBreakdown {
  const XpBreakdown({this.workouts = 0, this.sets = 0, this.records = 0, this.mealDays = 0});

  final int workouts;
  final int sets;
  final int records;
  final int mealDays;

  int get total => workouts + sets + records + mealDays;
}

XpBreakdown xpBreakdown(List<XpEvent> events) {
  var workouts = 0, sets = 0, records = 0, mealDays = 0;
  for (final e in events) {
    switch (e.source) {
      case XpSource.workout:
        workouts += xpPerWorkout;
        sets += e.sets * xpPerSet;
      case XpSource.record:
        records += e.xp;
      case XpSource.mealDay:
        mealDays += e.xp;
    }
  }
  return XpBreakdown(workouts: workouts, sets: sets, records: records, mealDays: mealDays);
}
```

Not: `List.sort` kararlı değildir; bu yüzden karşılaştırıcı tarih eşitliğinde kaynak sırasına bakar.

- [ ] **Step 5: Testlerin geçtiğini gör**

Run: `flutter test --no-pub -j 1 test/features/gamification/domain/xp_rules_test.dart`
Expected: PASS (7 test).

- [ ] **Step 6: Commit**

```bash
git add lib/features/gamification/domain/xp_rules.dart test/features/gamification/game_fixtures.dart test/features/gamification/domain/xp_rules_test.dart
git commit -m "feat(gamification): earn XP from workouts, records and meal days

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 2: Seviye ve rütbe

**Files:**
- Create: `lib/features/gamification/domain/levels.dart`
- Test: `test/features/gamification/domain/levels_test.dart`

**Interfaces:**
- Produces:
  - `int xpForNext(int level)`
  - `class LevelProgress { int level; int xpIntoLevel; int xpNeeded; double get fraction; }`
  - `LevelProgress levelFor(int totalXp)`
  - `enum Rank { rookie … immortal }` — `int minLevel`, `int get tier` (1–4), `int get stripes` (1–4), `String get labelKey` (`gamification.rank.<name>`)
  - `Rank rankFor(int level)`

- [ ] **Step 1: Başarısız testleri yaz**

`test/features/gamification/domain/levels_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:spor_takip/features/gamification/domain/levels.dart';

void main() {
  test('each level costs 25 XP more than the last', () {
    expect(xpForNext(1), 100);
    expect(xpForNext(2), 125);
    expect(xpForNext(10), 325);
  });

  test('levelFor walks the curve', () {
    LevelProgress p(int xp) => levelFor(xp);
    expect((p(0).level, p(0).xpIntoLevel, p(0).xpNeeded), (1, 0, 100));
    expect((p(99).level, p(99).xpIntoLevel), (1, 99));
    expect((p(100).level, p(100).xpIntoLevel, p(100).xpNeeded), (2, 0, 125));
    expect((p(224).level, p(224).xpIntoLevel), (2, 124));
    expect((p(225).level, p(225).xpIntoLevel, p(225).xpNeeded), (3, 0, 150));
    expect(p(-5).level, 1);
    expect(p(50).fraction, 0.5);
  });

  test('ranks follow their minimum levels', () {
    expect(rankFor(1), Rank.rookie);
    expect(rankFor(4), Rank.rookie);
    expect(rankFor(5), Rank.novice);
    expect(rankFor(34), Rank.determined);
    expect(rankFor(35), Rank.warrior);
    expect(rankFor(99), Rank.legend);
    expect(rankFor(100), Rank.immortal);
    expect(rankFor(150), Rank.immortal);
  });

  test('sixteen ranks in four tiers of four stripes', () {
    expect(Rank.values, hasLength(16));
    expect((Rank.rookie.tier, Rank.rookie.stripes), (1, 1));
    expect((Rank.warrior.tier, Rank.warrior.stripes), (2, 4));
    expect((Rank.gladiator.tier, Rank.gladiator.stripes), (3, 1));
    expect((Rank.immortal.tier, Rank.immortal.stripes), (4, 4));
    expect(Rank.elite.minLevel, 60);
    expect(Rank.titan.labelKey, 'gamification.rank.titan');
  });
}
```

- [ ] **Step 2: Testin başarısız olduğunu gör**

Run: `flutter test --no-pub -j 1 test/features/gamification/domain/levels_test.dart`
Expected: FAIL — `levels.dart` bulunamıyor.

- [ ] **Step 3: Seviye ve rütbeyi yaz**

`lib/features/gamification/domain/levels.dart`:

```dart
import 'dart:math' as math;

/// n → n+1 için gereken XP (O1 spec §4).
int xpForNext(int level) => 100 + 25 * (level - 1);

class LevelProgress {
  const LevelProgress({required this.level, required this.xpIntoLevel, required this.xpNeeded});

  final int level;

  /// Bu seviyede kazanılan XP.
  final int xpIntoLevel;

  /// Bu seviyeden sonrakine gereken XP.
  final int xpNeeded;

  double get fraction => xpIntoLevel / xpNeeded;
}

LevelProgress levelFor(int totalXp) {
  var level = 1;
  var remaining = math.max(totalXp, 0);
  while (remaining >= xpForNext(level)) {
    remaining -= xpForNext(level);
    level++;
  }
  return LevelProgress(level: level, xpIntoLevel: remaining, xpNeeded: xpForNext(level));
}

/// 16 rütbe; dörtlü kademeler, kademe içinde 1–4 şerit.
enum Rank {
  rookie(1),
  novice(5),
  amateur(10),
  enthusiast(15),
  athlete(20),
  dedicated(25),
  determined(30),
  warrior(35),
  gladiator(40),
  iron(45),
  master(50),
  elite(60),
  champion(70),
  titan(80),
  legend(90),
  immortal(100);

  const Rank(this.minLevel);

  final int minLevel;

  int get tier => index ~/ 4 + 1;

  int get stripes => index % 4 + 1;

  String get labelKey => 'gamification.rank.$name';
}

/// `minLevel <= level` olan en yüksek rütbe.
Rank rankFor(int level) => Rank.values.lastWhere((r) => r.minLevel <= level, orElse: () => Rank.rookie);
```

- [ ] **Step 4: Testlerin geçtiğini gör**

Run: `flutter test --no-pub -j 1 test/features/gamification/domain/levels_test.dart`
Expected: PASS (4 test).

- [ ] **Step 5: Commit**

```bash
git add lib/features/gamification/domain/levels.dart test/features/gamification/domain/levels_test.dart
git commit -m "feat(gamification): turn XP into levels and sixteen ranks

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 3: Unvanlar ve oyuncu özeti

**Files:**
- Create: `lib/features/gamification/domain/titles.dart`
- Create: `lib/features/gamification/domain/player_summary.dart`
- Test: `test/features/gamification/domain/titles_test.dart`
- Test: `test/features/gamification/domain/player_summary_test.dart`

**Interfaces:**
- Consumes: Task 1 (`xpEvents`, `xpBreakdown`, `XpEvent`, `XpBreakdown`), Task 2 (`levelFor`, `rankFor`, `LevelProgress`, `Rank`); `muscleWeight(Exercise, String)` (`lib/features/workout/domain/muscle_heat.dart`); `muscleGroups` (`lib/features/workout/domain/exercise_taxonomy.dart`).
- Produces:
  - `enum TitleTier { apprentice, master, champion }`, `enum TitleKind { muscle, exercise }`
  - `const muscleThresholds`, `const exerciseThresholds` (`Map<TitleTier, double>`)
  - `class TitleProgress { TitleKind kind; String subjectId; String? exerciseName; double value; TitleTier? get tier; TitleTier? get nextTier; double? get nextThreshold; String get id; }`
  - `List<TitleProgress> titleProgress(List<WorkoutSession> sessions, Map<String, Exercise> exercisesById)`
  - `List<TitleProgress> earnedTitles(List<TitleProgress> all)`
  - `List<TitleProgress> upcomingTitles(List<TitleProgress> all, {int count = 3})`
  - `class PlayerSummary { int totalXp; LevelProgress progress; Rank rank; XpBreakdown breakdown; List<XpEvent> recent; List<TitleProgress> titles; List<TitleProgress> upcoming; TitleProgress? titleById(String? id); }`
  - `PlayerSummary playerSummary(List<WorkoutSession> sessions, List<DateTime> mealTimes, Map<String, Exercise> exercisesById)`

- [ ] **Step 1: Başarısız unvan testlerini yaz**

`test/features/gamification/domain/titles_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:spor_takip/features/gamification/domain/titles.dart';

import '../game_fixtures.dart';

TitleProgress _muscle(String id, double value) =>
    TitleProgress(kind: TitleKind.muscle, subjectId: id, value: value);

TitleProgress _exercise(String id, double value) =>
    TitleProgress(kind: TitleKind.exercise, subjectId: id, value: value, exerciseName: id);

void main() {
  test('muscle values weigh primary 1 and secondary 0.5; exercise values count sessions', () {
    final all = titleProgress([
      gameSession('a', DateTime(2026, 10, 1), [...gameSets('bench', 4), gameSet('bench', done: false)]),
      gameSession('b', DateTime(2026, 10, 2), gameSets('bench', 2)),
      gameSession('c', DateTime(2026, 10, 3), [gameSet('squat', done: false)]),
      gameSession('live', null, gameSets('squat', 9)),
    ], gameExercisesById);
    final byId = {for (final t in all) t.id: t};
    expect(byId['muscle:chest']!.value, 6);
    expect(byId['muscle:triceps']!.value, 3);
    expect(byId['exercise:bench']!.value, 2);
    expect(byId['exercise:bench']!.exerciseName, 'Barbell Bench Press');
    expect(byId.containsKey('exercise:squat'), isFalse);
    expect(byId.containsKey('muscle:quadriceps'), isFalse);
  });

  test('an unknown exercise still earns its exercise title under the set name', () {
    final all = titleProgress([gameSession('a', DateTime(2026, 10, 1), gameSets('squat', 1))], const {});
    expect(all.single.id, 'exercise:squat');
    expect(all.single.exerciseName, 'Barbell Squat');
  });

  test('tiers and next thresholds follow the kind', () {
    expect(_muscle('chest', 99.5).tier, isNull);
    expect(_muscle('chest', 99.5).nextTier, TitleTier.apprentice);
    expect(_muscle('chest', 100).tier, TitleTier.apprentice);
    expect(_muscle('chest', 100).nextThreshold, 500);
    expect(_muscle('chest', 1500).tier, TitleTier.champion);
    expect(_muscle('chest', 1500).nextThreshold, isNull);
    expect(_muscle('chest', 1500).nextTier, isNull);
    expect(_exercise('bench', 10).tier, TitleTier.apprentice);
    expect(_exercise('bench', 49).nextThreshold, 50);
    expect(_exercise('bench', 49).nextTier, TitleTier.master);
  });

  test('earned titles sort by tier, then value', () {
    final earned = earnedTitles([
      _muscle('chest', 600),
      _exercise('bench', 12),
      _muscle('lats', 2000),
      _muscle('quadriceps', 50),
      _muscle('shoulders', 700),
    ]);
    expect([for (final t in earned) t.id], ['muscle:lats', 'muscle:shoulders', 'muscle:chest', 'exercise:bench']);
  });

  test('upcoming titles are the closest to their next tier, champions excluded', () {
    final all = [_muscle('chest', 450), _exercise('bench', 12), _muscle('quadriceps', 50), _muscle('lats', 2000)];
    expect([for (final t in upcomingTitles(all)) t.id], ['muscle:chest', 'muscle:quadriceps', 'exercise:bench']);
    expect([for (final t in upcomingTitles(all, count: 2)) t.id], ['muscle:chest', 'muscle:quadriceps']);
  });
}
```

- [ ] **Step 2: Başarısız özet testini yaz**

`test/features/gamification/domain/player_summary_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:spor_takip/features/gamification/domain/levels.dart';
import 'package:spor_takip/features/gamification/domain/player_summary.dart';
import 'package:spor_takip/features/gamification/domain/xp_rules.dart';

import '../game_fixtures.dart';

void main() {
  test('an empty history is a level 1 rookie', () {
    final summary = playerSummary(const [], const [], const {});
    expect(summary.totalXp, 0);
    expect(summary.progress.level, 1);
    expect(summary.rank, Rank.rookie);
    expect(summary.recent, isEmpty);
    expect(summary.titles, isEmpty);
    expect(summary.titleById('muscle:chest'), isNull);
  });

  test('combines XP, level, rank, the last ten events and titles', () {
    final sessions = [
      for (var i = 0; i < 12; i++) gameSession('s$i', DateTime(2026, 9, 1 + i, 18), gameSets('bench', 10)),
    ];
    final summary = playerSummary(sessions, [DateTime(2026, 9, 1, 9)], gameExercisesById);
    // 12 × (50 + 50) + 10 = 1210 → seviye 7 (eşik 975), 235 / 250.
    expect(summary.totalXp, 1210);
    expect(summary.breakdown.total, 1210);
    expect((summary.progress.level, summary.progress.xpIntoLevel), (7, 235));
    expect(summary.rank, Rank.novice);
    expect(summary.recent, hasLength(10));
    expect(summary.recent.first.date, DateTime(2026, 9, 12, 18)); // yeniden eskiye
    expect(summary.recent.first.source, XpSource.workout);
    // chest 120 → çırak; bench 12 oturum → çırak.
    expect({for (final t in summary.titles) t.id}, {'muscle:chest', 'exercise:bench'});
    expect(summary.titleById('exercise:bench')?.value, 12);
    expect(summary.titleById('muscle:triceps'), isNull); // 60 < 100
    expect(summary.upcoming.first.id, 'muscle:triceps'); // 60 / 100
  });
}
```

- [ ] **Step 3: Testlerin başarısız olduğunu gör**

Run: `flutter test --no-pub -j 1 test/features/gamification/domain/titles_test.dart test/features/gamification/domain/player_summary_test.dart`
Expected: FAIL — `titles.dart` / `player_summary.dart` bulunamıyor.

- [ ] **Step 4: Unvanları yaz**

`lib/features/gamification/domain/titles.dart`:

```dart
import '../../workout/domain/exercise.dart';
import '../../workout/domain/exercise_taxonomy.dart';
import '../../workout/domain/muscle_heat.dart';
import '../../workout/domain/workout_session.dart';

/// Çırağı / Ustası / Şampiyonu (O1 spec §5).
enum TitleTier { apprentice, master, champion }

enum TitleKind { muscle, exercise }

const muscleThresholds = {TitleTier.apprentice: 100.0, TitleTier.master: 500.0, TitleTier.champion: 1500.0};
const exerciseThresholds = {TitleTier.apprentice: 10.0, TitleTier.master: 50.0, TitleTier.champion: 150.0};

class TitleProgress {
  const TitleProgress({required this.kind, required this.subjectId, required this.value, this.exerciseName});

  final TitleKind kind;

  /// Kas adı (`muscleGroups`) ya da exerciseId.
  final String subjectId;

  /// Yalnız hareket unvanında.
  final String? exerciseName;

  /// Kas: ağırlıklı set; hareket: oturum sayısı.
  final double value;

  Map<TitleTier, double> get _thresholds => kind == TitleKind.muscle ? muscleThresholds : exerciseThresholds;

  /// Ulaşılan en yüksek kademe; null = henüz yok.
  TitleTier? get tier {
    TitleTier? reached;
    for (final t in TitleTier.values) {
      if (value >= _thresholds[t]!) reached = t;
    }
    return reached;
  }

  /// Sonraki kademe; şampiyonda null.
  TitleTier? get nextTier {
    for (final t in TitleTier.values) {
      if (value < _thresholds[t]!) return t;
    }
    return null;
  }

  double? get nextThreshold => switch (nextTier) {
        final next? => _thresholds[next],
        null => null,
      };

  /// Aktif unvan anahtarı.
  String get id => '${kind.name}:$subjectId';
}

/// Tüm kaslar ve hareketler için ilerleme; değeri 0 olanlar yok.
List<TitleProgress> titleProgress(List<WorkoutSession> sessions, Map<String, Exercise> exercisesById) {
  final muscles = <String, double>{};
  final exerciseSessions = <String, int>{};
  final setNames = <String, String>{};
  for (final session in sessions) {
    if (session.finishedAt == null) continue;
    final done = <String>{};
    for (final set in session.sets) {
      if (!set.isCompleted) continue;
      done.add(set.exerciseId);
      setNames[set.exerciseId] ??= set.exerciseName;
      final exercise = exercisesById[set.exerciseId];
      if (exercise == null) continue;
      for (final muscle in {...exercise.primaryMuscles, ...exercise.secondaryMuscles}) {
        if (!muscleGroups.contains(muscle)) continue;
        muscles[muscle] = (muscles[muscle] ?? 0) + muscleWeight(exercise, muscle);
      }
    }
    for (final id in done) {
      exerciseSessions[id] = (exerciseSessions[id] ?? 0) + 1;
    }
  }
  return [
    for (final MapEntry(key: muscle, value: value) in muscles.entries)
      if (value > 0) TitleProgress(kind: TitleKind.muscle, subjectId: muscle, value: value),
    for (final MapEntry(key: id, value: count) in exerciseSessions.entries)
      TitleProgress(
        kind: TitleKind.exercise,
        subjectId: id,
        value: count.toDouble(),
        exerciseName: exercisesById[id]?.name ?? setNames[id],
      ),
  ];
}

/// Kazanılanlar: kademe yüksekten düşüğe, sonra değer büyükten küçüğe, sonra id.
List<TitleProgress> earnedTitles(List<TitleProgress> all) {
  final earned = [
    for (final t in all)
      if (t.tier != null) t,
  ];
  earned.sort((a, b) {
    final byTier = b.tier!.index.compareTo(a.tier!.index);
    if (byTier != 0) return byTier;
    final byValue = b.value.compareTo(a.value);
    return byValue != 0 ? byValue : a.id.compareTo(b.id);
  });
  return earned;
}

/// Sonraki kademeye en yakın [count] tanesi; şampiyonlar hariç.
List<TitleProgress> upcomingTitles(List<TitleProgress> all, {int count = 3}) {
  final open = [
    for (final t in all)
      if (t.nextThreshold != null) t,
  ];
  double share(TitleProgress t) => t.value / t.nextThreshold!;
  open.sort((a, b) {
    final byShare = share(b).compareTo(share(a));
    return byShare != 0 ? byShare : a.id.compareTo(b.id);
  });
  return open.take(count).toList();
}
```

- [ ] **Step 5: Oyuncu özetini yaz**

`lib/features/gamification/domain/player_summary.dart`:

```dart
import '../../workout/domain/exercise.dart';
import '../../workout/domain/workout_session.dart';
import 'levels.dart';
import 'titles.dart';
import 'xp_rules.dart';

/// Seviye ekranı ve ana sayfa rozetinin tek kaynağı (O1 spec §7).
class PlayerSummary {
  const PlayerSummary({
    required this.totalXp,
    required this.progress,
    required this.rank,
    required this.breakdown,
    required this.recent,
    required this.titles,
    required this.upcoming,
  });

  final int totalXp;
  final LevelProgress progress;
  final Rank rank;
  final XpBreakdown breakdown;

  /// Son 10 olay, yeniden eskiye.
  final List<XpEvent> recent;

  /// Kazanılan unvanlar (`earnedTitles` sırası).
  final List<TitleProgress> titles;
  final List<TitleProgress> upcoming;

  /// Kayıtlı aktif unvan hâlâ kazanılmışsa o; değilse null.
  TitleProgress? titleById(String? id) => id == null ? null : titles.where((t) => t.id == id).firstOrNull;
}

PlayerSummary playerSummary(
  List<WorkoutSession> sessions,
  List<DateTime> mealTimes,
  Map<String, Exercise> exercisesById,
) {
  final events = xpEvents(sessions, mealTimes);
  final breakdown = xpBreakdown(events);
  final progress = levelFor(breakdown.total);
  final all = titleProgress(sessions, exercisesById);
  return PlayerSummary(
    totalXp: breakdown.total,
    progress: progress,
    rank: rankFor(progress.level),
    breakdown: breakdown,
    recent: events.reversed.take(10).toList(),
    titles: earnedTitles(all),
    upcoming: upcomingTitles(all),
  );
}
```

- [ ] **Step 6: Testlerin geçtiğini gör**

Run: `flutter test --no-pub -j 1 test/features/gamification/domain/titles_test.dart test/features/gamification/domain/player_summary_test.dart`
Expected: PASS (7 test).

- [ ] **Step 7: Commit**

```bash
git add lib/features/gamification/domain/titles.dart lib/features/gamification/domain/player_summary.dart test/features/gamification/domain/titles_test.dart test/features/gamification/domain/player_summary_test.dart
git commit -m "feat(gamification): earn muscle and exercise titles and sum up the player

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 4: Öğün zamanları, sağlayıcılar ve aktif unvan

**Files:**
- Modify: `lib/features/progress/data/progress_data_repository.dart`
- Modify: `lib/features/progress/application/progress_providers.dart`
- Modify: `lib/features/nutrition/application/meal_capture_notifier.dart:130-131`
- Modify: `lib/features/chat/application/chat_refresh.dart` (`ChatTool.createMeal` dalı)
- Modify: `test/features/progress/fakes.dart` (`FakeProgressDataRepository`)
- Create: `lib/features/gamification/application/gamification_providers.dart`
- Test: `test/features/gamification/application/gamification_providers_test.dart`

**Interfaces:**
- Consumes: Task 3 (`playerSummary`, `PlayerSummary`); mevcut `allSessionsProvider`, `progressDataRepositoryProvider`, `isLoggedInProvider`, `exercisesByIdProvider`.
- Produces:
  - `ProgressDataRepository.fetchMealTimes()` → `Future<List<DateTime>>` (yerel, eskiden yeniye)
  - `mealTimesProvider` — `FutureProvider.autoDispose<List<DateTime>>` (`progress_providers.dart`)
  - `playerSummaryProvider` — `FutureProvider.autoDispose<PlayerSummary>`
  - `const activeTitleKey = 'gamification.active_title'`
  - `class ActiveTitle extends AsyncNotifier<String?>` — `Future<void> equip(String id)`, `Future<void> unequip()`
  - `activeTitleProvider` — `AsyncNotifierProvider<ActiveTitle, String?>`

- [ ] **Step 1: Başarısız testleri yaz**

`test/features/gamification/application/gamification_providers_test.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spor_takip/features/gamification/application/gamification_providers.dart';
import 'package:spor_takip/features/nutrition/domain/meal.dart';
import 'package:spor_takip/features/nutrition/domain/meal_type.dart';
import 'package:spor_takip/features/onboarding/application/auth_providers.dart';
import 'package:spor_takip/features/progress/application/progress_providers.dart';
import 'package:spor_takip/features/workout/application/workout_providers.dart';

import '../../progress/fakes.dart';
import '../../workout/fakes.dart';
import '../game_fixtures.dart';

Meal _meal(String id, DateTime loggedAt) =>
    Meal(id: id, userId: 'user-1', mealType: MealType.lunch, loggedAt: loggedAt, items: const []);

ProviderContainer _container() {
  final container = ProviderContainer(overrides: [
    isLoggedInProvider.overrideWithValue(true),
    progressDataRepositoryProvider.overrideWithValue(FakeProgressDataRepository(
      sessions: [gameSession('a', DateTime(2026, 10, 1, 18), gameSets('bench', 2))],
      meals: [_meal('m1', DateTime(2026, 10, 2, 8)), _meal('m2', DateTime(2026, 10, 2, 13))],
    )),
    exerciseRepositoryProvider.overrideWithValue(FakeExerciseRepository([gameBench, gameSquat])),
  ]);
  addTearDown(container.dispose);
  return container;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('meal times come back oldest first', () async {
    final container = _container();
    container.listen(mealTimesProvider, (_, _) {});
    expect(await container.read(mealTimesProvider.future), [DateTime(2026, 10, 2, 8), DateTime(2026, 10, 2, 13)]);
  });

  test('the player summary joins sessions, meal days and exercises', () async {
    final container = _container();
    container.listen(playerSummaryProvider, (_, _) {});
    final summary = await container.read(playerSummaryProvider.future);
    // 50 + 2 × 5 + 10.
    expect(summary.totalXp, 70);
    expect(summary.upcoming.map((t) => t.id), contains('muscle:chest'));
  });

  test('the active title is saved and read back', () async {
    SharedPreferences.setMockInitialValues({'gamification.active_title': 'muscle:lats'});
    final first = _container();
    expect(await first.read(activeTitleProvider.future), 'muscle:lats');

    await first.read(activeTitleProvider.notifier).equip('exercise:bench');
    expect(first.read(activeTitleProvider).value, 'exercise:bench');
    final second = _container();
    expect(await second.read(activeTitleProvider.future), 'exercise:bench');

    await second.read(activeTitleProvider.notifier).unequip();
    final third = _container();
    expect(await third.read(activeTitleProvider.future), isNull);
  });
}
```

- [ ] **Step 2: Testin başarısız olduğunu gör**

Run: `flutter test --no-pub -j 1 test/features/gamification/application/gamification_providers_test.dart`
Expected: FAIL — `gamification_providers.dart` ve `mealTimesProvider` yok.

- [ ] **Step 3: Depoya `fetchMealTimes` ekle**

`lib/features/progress/data/progress_data_repository.dart` arayüzünde `fetchMeals` bildiriminden sonra ekle:

```dart

  /// Tüm öğünlerin kayıt zamanları (yerel), eskiden yeniye; oyunlaştırmadaki öğün günleri için.
  Future<List<DateTime>> fetchMealTimes();
```

`SupabaseProgressDataRepository` içinde `fetchMeals`'tan sonra ekle:

```dart

  @override
  Future<List<DateTime>> fetchMealTimes() async {
    final rows = await _client.from('meals').select('logged_at').order('logged_at');
    return [for (final row in rows) DateTime.parse(row['logged_at'] as String).toLocal()];
  }
```

`test/features/progress/fakes.dart` içinde `FakeProgressDataRepository`'nin `fetchMeals`'ından sonra ekle:

```dart

  @override
  Future<List<DateTime>> fetchMealTimes() async => [for (final m in meals) m.loggedAt]..sort();
```

- [ ] **Step 4: `mealTimesProvider` ve geçersiz kılmalar**

`lib/features/progress/application/progress_providers.dart` içinde `weeklyMealsProvider` tanımından sonra ekle:

```dart

/// Tüm öğünlerin kayıt zamanları (oyunlaştırma öğün günleri); öğün kaydedilince invalidate edilir.
final mealTimesProvider = FutureProvider.autoDispose<List<DateTime>>((ref) async {
  if (!ref.watch(isLoggedInProvider)) return const [];
  return ref.watch(progressDataRepositoryProvider).fetchMealTimes();
});
```

`lib/features/nutrition/application/meal_capture_notifier.dart` içinde

```dart
      ref.invalidate(weeklyMealsProvider); // F4b haftalık özet
```

satırından sonra ekle:

```dart
      ref.invalidate(mealTimesProvider); // oyunlaştırma öğün günleri
```

`lib/features/chat/application/chat_refresh.dart` içinde `ChatTool.createMeal` dalını şöyle yap:

```dart
    case ChatTool.createMeal:
      ref
        ..invalidate(todayMealsProvider)
        ..invalidate(weeklyMealsProvider)
        ..invalidate(mealTimesProvider);
```

- [ ] **Step 5: Oyunlaştırma sağlayıcılarını yaz**

`lib/features/gamification/application/gamification_providers.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../progress/application/progress_providers.dart';
import '../../workout/application/muscle_heat_providers.dart';
import '../domain/player_summary.dart';

/// Tüm geçmişten XP, seviye, rütbe ve unvanlar (O1 spec §7). Antrenman bitince
/// `allSessionsProvider`, öğün kaydedilince `mealTimesProvider` geçersiz kılınır.
final playerSummaryProvider = FutureProvider.autoDispose<PlayerSummary>((ref) async {
  final (sessions, mealTimes, exercisesById) = await (
    ref.watch(allSessionsProvider.future),
    ref.watch(mealTimesProvider.future),
    ref.watch(exercisesByIdProvider.future),
  ).wait;
  return playerSummary(sessions, mealTimes, exercisesById);
});

const activeTitleKey = 'gamification.active_title';

/// Takılı unvanın id'si; cihazda saklanır (O1 spec §6.4). Okunamazsa null.
class ActiveTitle extends AsyncNotifier<String?> {
  @override
  Future<String?> build() async {
    try {
      return (await SharedPreferences.getInstance()).getString(activeTitleKey);
    } catch (_) {
      return null;
    }
  }

  Future<void> equip(String id) async {
    state = AsyncData(id);
    try {
      await (await SharedPreferences.getInstance()).setString(activeTitleKey, id);
    } catch (_) {}
  }

  Future<void> unequip() async {
    state = const AsyncData(null);
    try {
      await (await SharedPreferences.getInstance()).remove(activeTitleKey);
    } catch (_) {}
  }
}

final activeTitleProvider = AsyncNotifierProvider<ActiveTitle, String?>(ActiveTitle.new);
```

- [ ] **Step 6: Testlerin geçtiğini gör**

Run: `flutter test --no-pub -j 1 test/features/gamification/application/gamification_providers_test.dart test/features/nutrition/application test/features/chat/application`
Expected: PASS (3 yeni + mevcut beslenme/sohbet uygulama testleri).

- [ ] **Step 7: Commit**

```bash
git add lib/features/progress/data/progress_data_repository.dart lib/features/progress/application/progress_providers.dart lib/features/nutrition/application/meal_capture_notifier.dart lib/features/chat/application/chat_refresh.dart test/features/progress/fakes.dart lib/features/gamification/application/gamification_providers.dart test/features/gamification/application/gamification_providers_test.dart
git commit -m "feat(gamification): provide the player summary and the equipped title

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 5: Rütbe rozeti, ana sayfa rozeti ve çeviriler

**Files:**
- Create: `lib/features/gamification/presentation/widgets/rank_badge.dart`
- Create: `lib/features/gamification/presentation/widgets/home_level_badge.dart`
- Modify: `lib/features/onboarding/presentation/home_screen.dart` (AppBar `actions`)
- Modify: `assets/translations/tr.json`, `assets/translations/en.json`
- Test: `test/features/gamification/presentation/rank_badge_test.dart`
- Test: `test/features/onboarding/presentation/home_screen_test.dart`

**Interfaces:**
- Consumes: Task 2 (`Rank`), Task 4 (`playerSummaryProvider`).
- Produces:
  - `RankBadge({Key? key, required Rank rank, required int level, double size = 28})` — yükseklik `size × 1.15`; `size >= 56` ise içinde seviye numarası.
  - `HomeLevelBadge()` — anahtar `home_level_badge`; `context.push('/home/levels')`.
  - `gamification` çeviri bloğu (spec §6.5 + kısa kas adları).

- [ ] **Step 1: Başarısız testleri yaz**

`test/features/gamification/presentation/rank_badge_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spor_takip/features/gamification/domain/levels.dart';
import 'package:spor_takip/features/gamification/presentation/widgets/rank_badge.dart';

import '../../progress/presentation/test_app.dart';

void main() {
  setUpAll(initTestLocalization);

  testWidgets('a large badge shows the level number', (tester) async {
    await tester.pumpWidget(testApp(const RankBadge(rank: Rank.warrior, level: 37, size: 88)));
    await tester.pumpAndSettle();
    expect(find.text('37'), findsOneWidget);
    expect(tester.getSize(find.byType(RankBadge)), const Size(88, 88 * 1.15));
  });

  testWidgets('a small badge hides the number', (tester) async {
    await tester.pumpWidget(testApp(const RankBadge(rank: Rank.immortal, level: 120)));
    await tester.pumpAndSettle();
    expect(find.text('120'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
```

`test/features/onboarding/presentation/home_screen_test.dart` importlarına ekle:

```dart
import 'package:spor_takip/features/gamification/application/gamification_providers.dart';
import 'package:spor_takip/features/gamification/domain/player_summary.dart';
```

`homeOverrides()` listesinin sonuna ekle:

```dart
        playerSummaryProvider.overrideWith((ref) async => playerSummary(const [], const [], const {})),
```

`main()` sonuna ekle:

```dart
  testWidgets('the level badge shows the level and opens the level screen', (tester) async {
    tallView(tester);
    await tester.pumpWidget(testApp(
      const HomeScreen(),
      scaffold: false,
      overrides: homeOverrides(),
      stubRoutes: {'/home/levels': 'levels-stub'},
    ));
    await tester.pumpAndSettle();

    final badge = find.byKey(const Key('home_level_badge'));
    expect(badge, findsOneWidget);
    expect(find.descendant(of: badge, matching: find.text('gamification.level_short')), findsOneWidget);
    await tester.tap(badge);
    await tester.pumpAndSettle();
    expect(find.text('levels-stub'), findsOneWidget);
  });
```

Not: `testApp`'teki stub rotası `/home/levels` yolunu kök rotanın kardeşi olarak tanımlar; `context.push('/home/levels')` ona gider.

- [ ] **Step 2: Testlerin başarısız olduğunu gör**

Run: `flutter test --no-pub -j 1 test/features/gamification/presentation/rank_badge_test.dart test/features/onboarding/presentation/home_screen_test.dart`
Expected: FAIL — `rank_badge.dart` yok; ana sayfa testi derlenmiyor ya da `home_level_badge` bulunamıyor.

- [ ] **Step 3: `RankBadge`'i yaz**

`lib/features/gamification/presentation/widgets/rank_badge.dart`:

```dart
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_fonts.dart';
import '../../domain/levels.dart';

/// Kalkan biçimli rütbe rozeti: kademe rengi, kademe içi sıra kadar chevron şerit;
/// büyük boyda (≥ 56) altta seviye numarası (O1 spec §6.1).
class RankBadge extends StatelessWidget {
  const RankBadge({super.key, required this.rank, required this.level, this.size = 28});

  final Rank rank;
  final int level;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = switch (rank.tier) {
      1 => scheme.onSurfaceVariant,
      2 => scheme.primary.withValues(alpha: 0.55),
      _ => scheme.primary,
    };
    return SizedBox(
      width: size,
      height: size * 1.15,
      child: CustomPaint(
        painter: _RankBadgePainter(
          color: color,
          background: scheme.surfaceContainerLowest,
          stripes: rank.stripes,
          glow: rank.tier == 4,
        ),
        child: size >= 56
            ? Align(
                alignment: const Alignment(0, 0.62),
                child: Text(
                  '$level',
                  style: TextStyle(
                    fontFamily: AppFonts.heading,
                    fontWeight: FontWeight.w900,
                    fontSize: size * 0.26,
                    color: scheme.onSurface,
                  ),
                ),
              )
            : null,
      ),
    );
  }
}

class _RankBadgePainter extends CustomPainter {
  const _RankBadgePainter({required this.color, required this.background, required this.stripes, required this.glow});

  final Color color;
  final Color background;
  final int stripes;
  final bool glow;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final shield = Path()
      ..moveTo(w * 0.5, 0)
      ..lineTo(w, h * 0.15)
      ..lineTo(w, h * 0.55)
      ..quadraticBezierTo(w, h * 0.85, w * 0.5, h)
      ..quadraticBezierTo(0, h * 0.85, 0, h * 0.55)
      ..lineTo(0, h * 0.15)
      ..close();
    if (glow) {
      canvas.drawPath(
        shield,
        Paint()
          ..color = color.withValues(alpha: 0.5)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, w * 0.12),
      );
    }
    canvas.drawPath(shield, Paint()..color = background);
    canvas.drawPath(
      shield,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.5, w * 0.06)
        ..color = color,
    );
    final chevron = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.5, w * 0.08)
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = color;
    for (var i = 0; i < stripes; i++) {
      final y = h * (0.18 + i * 0.1);
      canvas.drawPath(
        Path()
          ..moveTo(w * 0.28, y)
          ..lineTo(w * 0.5, y + h * 0.08)
          ..lineTo(w * 0.72, y),
        chevron,
      );
    }
  }

  @override
  bool shouldRepaint(_RankBadgePainter old) =>
      old.color != color || old.background != background || old.stripes != stripes || old.glow != glow;
}
```

- [ ] **Step 4: `HomeLevelBadge`'i yaz ve ana sayfaya ekle**

`lib/features/gamification/presentation/widgets/home_level_badge.dart`:

```dart
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../application/gamification_providers.dart';
import 'rank_badge.dart';

/// Ana sayfa AppBar'ında rütbe + "Sv n" hapı; dokununca seviye ekranı.
/// Özet yüklenirken ya da hatada görünmez (O1 spec §6.2).
class HomeLevelBadge extends ConsumerWidget {
  const HomeLevelBadge({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(playerSummaryProvider).value;
    if (summary == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    const shape = StadiumBorder();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Material(
        color: scheme.primary.withValues(alpha: 0.1),
        shape: shape.copyWith(side: BorderSide(color: scheme.primary.withValues(alpha: 0.5))),
        child: InkWell(
          key: const Key('home_level_badge'),
          customBorder: shape,
          onTap: () => context.push('/home/levels'),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                RankBadge(rank: summary.rank, level: summary.progress.level, size: 16),
                const SizedBox(width: 6),
                Text(
                  'gamification.level_short'.tr(namedArgs: {'n': '${summary.progress.level}'}),
                  style: theme.textTheme.labelLarge?.copyWith(color: scheme.primary, fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
```

`lib/features/onboarding/presentation/home_screen.dart` importlarına ekle:

```dart
import '../../gamification/presentation/widgets/home_level_badge.dart';
```

AppBar `actions` listesinin başına (`IconButton(key: const Key('home_settings_button')` öncesine) ekle:

```dart
          const HomeLevelBadge(),
          const SizedBox(width: 4),
```

- [ ] **Step 5: Çevirileri ekle**

`assets/translations/tr.json` ve `en.json` kök nesnesine (son üst düzey anahtardan sonra, aynı girintiyle) `gamification` bloğunu ekle. Python ile eklemek en güvenlisi (JSON'u yükleyip yazmak dosyanın biçimini bozar; bu yüzden metin olarak son `}`'den önce eklenir):

```bash
python - <<'EOF'
import json
blocks = {
 'tr': {
  "title": "Seviye", "level_short": "Sv {n}", "level": "SEVİYE {n}", "progress": "{x} / {y} XP",
  "total_xp": "Toplam {n} XP", "breakdown_title": "XP dökümü", "breakdown_workouts": "Antrenman",
  "breakdown_sets": "Setler", "breakdown_records": "Rekorlar", "breakdown_meal_days": "Öğün günleri",
  "titles_title": "Unvanlar", "titles_count": "{n} açıldı",
  "titles_empty": "Henüz unvan yok — antrenman yaptıkça kas ve hareket unvanları açılır",
  "upcoming_title": "Yakında", "equipped": "TAKILI", "equip": "TAK",
  "criterion_sets": "{value} / {threshold} set", "criterion_sessions": "{value} / {threshold} oturum",
  "value_sets": "{value} set", "value_sessions": "{value} oturum",
  "ladder_title": "Rütbe merdiveni", "ladder_passed": "GEÇİLDİ", "ladder_current": "ŞU AN",
  "recent_title": "Son kazanımlar", "recent_empty": "Henüz XP kazanılmadı",
  "record": "Rekor: {name}", "record_detail": "{kg} kg × {reps}", "workout_sets": "{n} set",
  "meal_day": "Öğün kaydı", "xp_gain": "+{n} XP", "retry": "Yüklenemedi — tekrar dene",
  "rank": {"rookie": "Çaylak", "novice": "Acemi", "amateur": "Amatör", "enthusiast": "Hevesli",
           "athlete": "Sporcu", "dedicated": "Azimli", "determined": "Kararlı", "warrior": "Savaşçı",
           "gladiator": "Gladyatör", "iron": "Demir", "master": "Usta", "elite": "Elit",
           "champion": "Şampiyon", "titan": "Titan", "legend": "Efsane", "immortal": "Ölümsüz"},
  "muscle_short": {"abdominals": "Karın", "abductors": "Abdüktör", "adductors": "Addüktör", "biceps": "Biseps",
                   "calves": "Baldır", "chest": "Göğüs", "forearms": "Ön kol", "glutes": "Kalça",
                   "hamstrings": "Arka bacak", "lats": "Kanat", "lower_back": "Alt sırt", "middle_back": "Orta sırt",
                   "neck": "Boyun", "quadriceps": "Ön bacak", "shoulders": "Omuz", "traps": "Trapez",
                   "triceps": "Triseps"},
  "title_tier": {"apprentice": "{name} Çırağı", "master": "{name} Ustası", "champion": "{name} Şampiyonu"}
 },
 'en': {
  "title": "Level", "level_short": "Lv {n}", "level": "LEVEL {n}", "progress": "{x} / {y} XP",
  "total_xp": "Total {n} XP", "breakdown_title": "XP breakdown", "breakdown_workouts": "Workouts",
  "breakdown_sets": "Sets", "breakdown_records": "Records", "breakdown_meal_days": "Meal days",
  "titles_title": "Titles", "titles_count": "{n} unlocked",
  "titles_empty": "No titles yet — muscle and exercise titles unlock as you train",
  "upcoming_title": "Up next", "equipped": "EQUIPPED", "equip": "EQUIP",
  "criterion_sets": "{value} / {threshold} sets", "criterion_sessions": "{value} / {threshold} sessions",
  "value_sets": "{value} sets", "value_sessions": "{value} sessions",
  "ladder_title": "Rank ladder", "ladder_passed": "PASSED", "ladder_current": "CURRENT",
  "recent_title": "Recent gains", "recent_empty": "No XP earned yet",
  "record": "Record: {name}", "record_detail": "{kg} kg × {reps}", "workout_sets": "{n} sets",
  "meal_day": "Meal logged", "xp_gain": "+{n} XP", "retry": "Couldn't load — try again",
  "rank": {"rookie": "Rookie", "novice": "Novice", "amateur": "Amateur", "enthusiast": "Enthusiast",
           "athlete": "Athlete", "dedicated": "Dedicated", "determined": "Determined", "warrior": "Warrior",
           "gladiator": "Gladiator", "iron": "Iron", "master": "Master", "elite": "Elite",
           "champion": "Champion", "titan": "Titan", "legend": "Legend", "immortal": "Immortal"},
  "muscle_short": {"abdominals": "Abs", "abductors": "Abductors", "adductors": "Adductors", "biceps": "Biceps",
                   "calves": "Calves", "chest": "Chest", "forearms": "Forearms", "glutes": "Glutes",
                   "hamstrings": "Hamstrings", "lats": "Lats", "lower_back": "Lower Back", "middle_back": "Middle Back",
                   "neck": "Neck", "quadriceps": "Quads", "shoulders": "Shoulders", "traps": "Traps",
                   "triceps": "Triceps"},
  "title_tier": {"apprentice": "{name} Apprentice", "master": "{name} Master", "champion": "{name} Champion"}
 },
}
for lang, block in blocks.items():
    path = f'assets/translations/{lang}.json'
    text = open(path, encoding='utf-8').read()
    crlf = '\r\n' in text
    text = text.replace('\r\n', '\n')
    assert '"gamification"' not in text
    body = json.dumps(block, ensure_ascii=False, indent=2)
    body = '\n'.join('  ' + line if i else line for i, line in enumerate(body.split('\n')))
    end = text.rstrip().rfind('}')
    head = text[:end].rstrip()
    text = head + ',\n  "gamification": ' + body + '\n}\n'
    json.loads(text)
    if crlf:
        text = text.replace('\n', '\r\n')
    open(path, 'w', encoding='utf-8', newline='').write(text)
    print(lang, 'ok')
EOF
```

Not: Spec §6.5'teki unvan kalıbı anahtarı `title.<tier>` idi; `title` anahtarı ekran başlığıyla çakışacağı için kalıplar `gamification.title_tier.<tier>` altında.

- [ ] **Step 6: Testlerin geçtiğini gör**

Run: `flutter test --no-pub -j 1 test/features/gamification/presentation/rank_badge_test.dart test/features/onboarding/presentation/home_screen_test.dart`
Expected: PASS (2 rozet + mevcut ana sayfa testleri + 1 yeni).

- [ ] **Step 7: Commit**

```bash
git add lib/features/gamification/presentation/widgets/rank_badge.dart lib/features/gamification/presentation/widgets/home_level_badge.dart lib/features/onboarding/presentation/home_screen.dart assets/translations/tr.json assets/translations/en.json test/features/gamification/presentation/rank_badge_test.dart test/features/onboarding/presentation/home_screen_test.dart
git commit -m "feat(gamification): add the rank badge and show the level on the home screen

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 6: Seviye ekranı

**Files:**
- Create: `lib/features/gamification/presentation/title_names.dart`
- Create: `lib/features/gamification/presentation/level_screen.dart`
- Modify: `lib/core/router.dart` (`/home` rotaları)
- Test: `test/features/gamification/presentation/level_screen_test.dart`

**Interfaces:**
- Consumes: Task 1–5 (`PlayerSummary`, `XpEvent`, `XpSource`, `XpBreakdown`, `levelFor`, `rankFor`, `Rank`, `TitleProgress`, `TitleTier`, `TitleKind`, `playerSummaryProvider`, `activeTitleProvider`, `RankBadge`); `formatSets(double)` (`muscle_heat.dart`); `taxonomySlug(String)` (`exercise_taxonomy.dart`); `upperCaseFor`; `SectionHeader(title, {trailing})`; `allSessionsProvider`, `mealTimesProvider`, `exercisesProvider`.
- Produces:
  - `String titleName(TitleProgress title, TitleTier tier)`
  - `String titleCriterion(TitleProgress title)`
  - `LevelScreen()` (`level_screen`), rota `/home/levels`.

- [ ] **Step 1: Başarısız ekran testlerini yaz**

`test/features/gamification/presentation/level_screen_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spor_takip/features/gamification/application/gamification_providers.dart';
import 'package:spor_takip/features/gamification/domain/levels.dart';
import 'package:spor_takip/features/gamification/domain/player_summary.dart';
import 'package:spor_takip/features/gamification/domain/titles.dart';
import 'package:spor_takip/features/gamification/domain/xp_rules.dart';
import 'package:spor_takip/features/gamification/presentation/level_screen.dart';
import 'package:spor_takip/features/gamification/presentation/widgets/rank_badge.dart';

import '../../progress/presentation/test_app.dart';

final _progress = levelFor(1234); // seviye 8
final _summary = PlayerSummary(
  totalXp: 1234,
  progress: _progress,
  rank: rankFor(_progress.level),
  breakdown: const XpBreakdown(workouts: 500, sets: 400, records: 50, mealDays: 284),
  recent: [
    XpEvent(source: XpSource.workout, date: DateTime(2026, 10, 9, 18), xp: 115, label: 'Push A', sets: 13),
    XpEvent(source: XpSource.record, date: DateTime(2026, 10, 8, 20), xp: 25, label: 'Squat', weightKg: 140, reps: 3),
    XpEvent(source: XpSource.mealDay, date: DateTime(2026, 10, 8), xp: 10),
  ],
  titles: const [
    TitleProgress(kind: TitleKind.muscle, subjectId: 'lats', value: 1600),
    TitleProgress(kind: TitleKind.muscle, subjectId: 'chest', value: 600),
    TitleProgress(kind: TitleKind.exercise, subjectId: 'squat', value: 12, exerciseName: 'Barbell Squat'),
  ],
  upcoming: const [
    TitleProgress(kind: TitleKind.muscle, subjectId: 'shoulders', value: 320),
    TitleProgress(kind: TitleKind.exercise, subjectId: 'deadlift', value: 41, exerciseName: 'Deadlift'),
  ],
);

void main() {
  setUpAll(initTestLocalization);
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> pump(WidgetTester tester, Future<PlayerSummary> Function() load) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(testApp(
      const LevelScreen(),
      scaffold: false,
      overrides: [playerSummaryProvider.overrideWith((ref) => load())],
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('shows the header, breakdown, titles, ladder and recent gains', (tester) async {
    await pump(tester, () async => _summary);
    expect(find.byKey(const Key('level_screen')), findsOneWidget);
    for (final key in ['level_header', 'level_breakdown', 'level_titles', 'level_upcoming', 'level_ladder', 'level_recent']) {
      expect(find.byKey(Key(key)), findsOneWidget, reason: key);
    }
    final header = find.byKey(const Key('level_header'));
    final badge = tester.widget<RankBadge>(find.descendant(of: header, matching: find.byType(RankBadge)));
    expect((badge.rank, badge.level), (Rank.novice, 8));
    expect(find.byKey(const Key('level_progress')), findsOneWidget);
    expect(find.byKey(const Key('title_muscle:lats')), findsOneWidget);
    expect(find.byKey(const Key('title_exercise:squat')), findsOneWidget);
    expect(find.byKey(const Key('upcoming_muscle:shoulders')), findsOneWidget);
    expect(find.byKey(const Key('ladder_novice')), findsOneWidget);
    expect(find.byKey(const Key('ladder_rookie')), findsOneWidget);
    for (var i = 0; i < 3; i++) {
      expect(find.byKey(Key('recent_$i')), findsOneWidget);
    }
    expect(find.descendant(of: find.byKey(const Key('recent_1')), matching: find.text('gamification.record')),
        findsOneWidget);
    expect(find.byKey(const Key('level_active_title')), findsNothing);
  });

  testWidgets('equipping a title shows it in the header; tapping it again takes it off', (tester) async {
    await pump(tester, () async => _summary);
    await tester.ensureVisible(find.byKey(const Key('title_equip_muscle:chest')));
    await tester.tap(find.byKey(const Key('title_equip_muscle:chest')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('level_active_title')), findsOneWidget);
    expect(find.byKey(const Key('title_unequip_muscle:chest')), findsOneWidget);
    expect(find.byKey(const Key('title_equip_muscle:lats')), findsOneWidget);

    await tester.tap(find.byKey(const Key('title_unequip_muscle:chest')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('level_active_title')), findsNothing);
  });

  testWidgets('a saved title that is no longer earned is not shown', (tester) async {
    SharedPreferences.setMockInitialValues({'gamification.active_title': 'muscle:neck'});
    await pump(tester, () async => _summary);
    expect(find.byKey(const Key('level_active_title')), findsNothing);
  });

  testWidgets('an empty history shows empty texts', (tester) async {
    await pump(tester, () async => playerSummary(const [], const [], const {}));
    expect(find.byKey(const Key('level_titles_empty')), findsOneWidget);
    expect(find.byKey(const Key('level_recent_empty')), findsOneWidget);
    expect(find.byKey(const Key('level_upcoming')), findsNothing);
  });

  testWidgets('a load error offers a retry', (tester) async {
    await pump(tester, () async => throw Exception('offline'));
    expect(find.byKey(const Key('level_retry')), findsOneWidget);
  });
}
```

- [ ] **Step 2: Testin başarısız olduğunu gör**

Run: `flutter test --no-pub -j 1 test/features/gamification/presentation/level_screen_test.dart`
Expected: FAIL — `level_screen.dart` bulunamıyor.

- [ ] **Step 3: Unvan adlarını yaz**

`lib/features/gamification/presentation/title_names.dart`:

```dart
import 'package:easy_localization/easy_localization.dart';

import '../../workout/domain/exercise_taxonomy.dart';
import '../../workout/domain/muscle_heat.dart';
import '../domain/titles.dart';

/// "Kanat Şampiyonu", "Barbell Squat Ustası".
String titleName(TitleProgress title, TitleTier tier) {
  final name = switch (title.kind) {
    TitleKind.muscle => 'gamification.muscle_short.${taxonomySlug(title.subjectId)}'.tr(),
    TitleKind.exercise => title.exerciseName ?? title.subjectId,
  };
  return 'gamification.title_tier.${tier.name}'.tr(namedArgs: {'name': name});
}

/// "320 / 500 set", "41 / 50 oturum"; şampiyonda yalnız değer.
String titleCriterion(TitleProgress title) {
  final isMuscle = title.kind == TitleKind.muscle;
  final value = isMuscle ? formatSets(title.value) : '${title.value.toInt()}';
  final next = title.nextThreshold;
  if (next == null) {
    return (isMuscle ? 'gamification.value_sets' : 'gamification.value_sessions').tr(namedArgs: {'value': value});
  }
  return (isMuscle ? 'gamification.criterion_sets' : 'gamification.criterion_sessions')
      .tr(namedArgs: {'value': value, 'threshold': '${next.toInt()}'});
}
```

- [ ] **Step 4: Seviye ekranını yaz**

`lib/features/gamification/presentation/level_screen.dart`:

```dart
import 'dart:math' as math;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_fonts.dart';
import '../../../shared/text_case.dart';
import '../../../shared/widgets/section_header.dart';
import '../../progress/application/progress_providers.dart';
import '../../workout/application/workout_providers.dart';
import '../application/gamification_providers.dart';
import '../domain/levels.dart';
import '../domain/player_summary.dart';
import '../domain/titles.dart';
import '../domain/xp_rules.dart';
import 'title_names.dart';
import 'widgets/rank_badge.dart';

/// Seviye, rütbe, unvanlar ve son kazanımlar (O1 spec §6.3).
class LevelScreen extends ConsumerWidget {
  const LevelScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = context.locale.languageCode;
    final activeId = ref.watch(activeTitleProvider).value;
    return Scaffold(
      key: const Key('level_screen'),
      appBar: AppBar(
        title: Text(
          upperCaseFor('gamification.title'.tr(), lang),
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
        ),
      ),
      body: ref.watch(playerSummaryProvider).when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stackTrace) => Center(
              child: TextButton(
                key: const Key('level_retry'),
                onPressed: () {
                  ref.invalidate(allSessionsProvider);
                  ref.invalidate(mealTimesProvider);
                  ref.invalidate(exercisesProvider);
                },
                child: Text('gamification.retry'.tr()),
              ),
            ),
            data: (summary) => ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                _Header(summary: summary, active: summary.titleById(activeId)),
                SectionHeader('gamification.breakdown_title'.tr()),
                _Breakdown(breakdown: summary.breakdown),
                SectionHeader(
                  'gamification.titles_title'.tr(),
                  key: const Key('level_titles_count'),
                  trailing: 'gamification.titles_count'.tr(namedArgs: {'n': '${summary.titles.length}'}),
                ),
                _Titles(summary: summary, activeId: activeId),
                SectionHeader('gamification.ladder_title'.tr()),
                _Ladder(current: summary.rank),
                SectionHeader('gamification.recent_title'.tr()),
                _Recent(events: summary.recent),
              ],
            ),
          ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.summary, required this.active});

  final PlayerSummary summary;
  final TitleProgress? active;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final muted = theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant);
    final progress = summary.progress;
    final active = this.active;
    return Card(
      key: const Key('level_header'),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            RankBadge(rank: summary.rank, level: progress.level, size: 88),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    upperCaseFor(summary.rank.labelKey.tr(), context.locale.languageCode),
                    style: theme.textTheme.headlineSmall?.copyWith(fontFamily: AppFonts.heading, fontWeight: FontWeight.w900),
                  ),
                  if (active != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Container(
                        key: const Key('level_active_title'),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: scheme.primary.withValues(alpha: 0.12),
                          borderRadius: const BorderRadius.all(Radius.circular(999)),
                          border: Border.all(color: scheme.primary),
                        ),
                        child: Text(
                          titleName(active, active.tier!),
                          style: theme.textTheme.labelLarge?.copyWith(color: scheme.primary),
                        ),
                      ),
                    ),
                  const SizedBox(height: 10),
                  Text(
                    'gamification.level'.tr(namedArgs: {'n': '${progress.level}'}),
                    style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800, letterSpacing: 1),
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: const BorderRadius.all(Radius.circular(999)),
                    child: LinearProgressIndicator(value: progress.fraction, minHeight: 8),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'gamification.progress'.tr(namedArgs: {'x': '${progress.xpIntoLevel}', 'y': '${progress.xpNeeded}'}),
                    key: const Key('level_progress'),
                    style: theme.textTheme.bodySmall?.copyWith(color: scheme.primary),
                  ),
                  Text(
                    'gamification.total_xp'.tr(namedArgs: {'n': '${summary.totalXp}'}),
                    key: const Key('level_total_xp'),
                    style: muted,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Breakdown extends StatelessWidget {
  const _Breakdown({required this.breakdown});

  final XpBreakdown breakdown;

  @override
  Widget build(BuildContext context) {
    Widget tile(IconData icon, String label, int xp) => Expanded(child: _BreakdownTile(icon: icon, label: label, xp: xp));
    return Column(
      key: const Key('level_breakdown'),
      children: [
        Row(
          children: [
            tile(Icons.fitness_center, 'gamification.breakdown_workouts'.tr(), breakdown.workouts),
            const SizedBox(width: 12),
            tile(Icons.layers_outlined, 'gamification.breakdown_sets'.tr(), breakdown.sets),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            tile(Icons.emoji_events_outlined, 'gamification.breakdown_records'.tr(), breakdown.records),
            const SizedBox(width: 12),
            tile(Icons.restaurant, 'gamification.breakdown_meal_days'.tr(), breakdown.mealDays),
          ],
        ),
      ],
    );
  }
}

class _BreakdownTile extends StatelessWidget {
  const _BreakdownTile({required this.icon, required this.label, required this.xp});

  final IconData icon;
  final String label;
  final int xp;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(label, style: theme.textTheme.labelLarge?.copyWith(color: scheme.onSurfaceVariant)),
                ),
                Icon(icon, size: 18, color: scheme.primary),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '$xp',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontFamily: AppFonts.heading,
                fontWeight: FontWeight.w900,
                color: scheme.primary,
              ),
            ),
            Text('XP', style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}

class _Titles extends ConsumerWidget {
  const _Titles({required this.summary, required this.activeId});

  final PlayerSummary summary;
  final String? activeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final notifier = ref.read(activeTitleProvider.notifier);
    const compact = Size(0, 32);
    const padding = EdgeInsets.symmetric(horizontal: 12);
    return Column(
      key: const Key('level_titles'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (summary.titles.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'gamification.titles_empty'.tr(),
              key: const Key('level_titles_empty'),
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
          ),
        for (final title in summary.titles)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Card(
              key: Key('title_${title.id}'),
              margin: EdgeInsets.zero,
              shape: RoundedRectangleBorder(
                borderRadius: const BorderRadius.all(Radius.circular(16)),
                side: title.id == activeId ? BorderSide(color: scheme.primary) : BorderSide.none,
              ),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: scheme.surfaceContainerHighest,
                  child: Icon(
                    title.kind == TitleKind.muscle ? Icons.accessibility_new : Icons.fitness_center,
                    color: scheme.primary,
                    size: 20,
                  ),
                ),
                title: Text(titleName(title, title.tier!)),
                subtitle: Text(titleCriterion(title)),
                trailing: title.id == activeId
                    ? FilledButton(
                        key: Key('title_unequip_${title.id}'),
                        style: FilledButton.styleFrom(minimumSize: compact, padding: padding),
                        onPressed: notifier.unequip,
                        child: Text('gamification.equipped'.tr()),
                      )
                    : OutlinedButton(
                        key: Key('title_equip_${title.id}'),
                        style: OutlinedButton.styleFrom(minimumSize: compact, padding: padding),
                        onPressed: () => notifier.equip(title.id),
                        child: Text('gamification.equip'.tr()),
                      ),
              ),
            ),
          ),
        if (summary.upcoming.isNotEmpty)
          Card(
            key: const Key('level_upcoming'),
            margin: const EdgeInsets.only(top: 4),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    upperCaseFor('gamification.upcoming_title'.tr(), context.locale.languageCode),
                    style: theme.textTheme.labelLarge?.copyWith(color: scheme.onSurfaceVariant, letterSpacing: 1),
                  ),
                  for (final title in summary.upcoming)
                    Padding(
                      key: Key('upcoming_${title.id}'),
                      padding: const EdgeInsets.only(top: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Expanded(child: Text(titleName(title, title.nextTier!))),
                              Text(
                                titleCriterion(title),
                                style: theme.textTheme.bodySmall?.copyWith(color: scheme.primary),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: const BorderRadius.all(Radius.circular(999)),
                            child: LinearProgressIndicator(
                              value: (title.value / title.nextThreshold!).clamp(0.0, 1.0),
                              minHeight: 6,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _Ladder extends StatefulWidget {
  const _Ladder({required this.current});

  final Rank current;

  @override
  State<_Ladder> createState() => _LadderState();
}

class _LadderState extends State<_Ladder> {
  static const _cardWidth = 120.0;
  static const _gap = 12.0;
  late final ScrollController _controller =
      ScrollController(initialScrollOffset: math.max(0, (widget.current.index - 1) * (_cardWidth + _gap)));

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final lang = context.locale.languageCode;
    return SizedBox(
      key: const Key('level_ladder'),
      height: 168,
      child: ListView.separated(
        controller: _controller,
        scrollDirection: Axis.horizontal,
        itemCount: Rank.values.length,
        separatorBuilder: (context, index) => const SizedBox(width: _gap),
        itemBuilder: (context, index) {
          final rank = Rank.values[index];
          final isCurrent = rank == widget.current;
          final passed = rank.index < widget.current.index;
          final status = isCurrent
              ? _pill(context, 'gamification.ladder_current'.tr(), filled: true)
              : passed
                  ? _pill(context, 'gamification.ladder_passed'.tr(), filled: false)
                  : Icon(Icons.lock_outline, size: 16, color: scheme.onSurfaceVariant);
          return Opacity(
            key: Key('ladder_${rank.name}'),
            opacity: rank.index > widget.current.index ? 0.4 : 1,
            child: Container(
              width: _cardWidth,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.cardTheme.color ?? scheme.surfaceContainer,
                borderRadius: const BorderRadius.all(Radius.circular(16)),
                border: Border.all(color: isCurrent ? scheme.primary : scheme.outlineVariant),
                boxShadow: isCurrent ? [BoxShadow(color: scheme.primary.withValues(alpha: 0.25), blurRadius: 16)] : null,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  RankBadge(rank: rank, level: rank.minLevel, size: 36),
                  const SizedBox(height: 8),
                  Text(
                    'gamification.level_short'.tr(namedArgs: {'n': '${rank.minLevel}'}),
                    style: theme.textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                  Text(
                    upperCaseFor(rank.labelKey.tr(), lang),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 6),
                  status,
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _pill(BuildContext context, String text, {required bool filled}) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: filled ? scheme.primary : scheme.primary.withValues(alpha: 0.12),
        borderRadius: const BorderRadius.all(Radius.circular(999)),
      ),
      child: Text(
        text,
        style: theme.textTheme.labelSmall?.copyWith(
          color: filled ? scheme.onPrimary : scheme.primary,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _Recent extends StatelessWidget {
  const _Recent({required this.events});

  final List<XpEvent> events;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Column(
      key: const Key('level_recent'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (events.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'gamification.recent_empty'.tr(),
              key: const Key('level_recent_empty'),
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
          ),
        for (final (index, event) in events.indexed)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Card(
              key: Key('recent_$index'),
              margin: EdgeInsets.zero,
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: scheme.surfaceContainerHighest,
                  child: Icon(_icon(event.source), color: scheme.primary, size: 20),
                ),
                title: Text(_title(event)),
                subtitle: switch (_detail(event)) {
                  final detail? => Text(detail),
                  null => null,
                },
                trailing: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: scheme.primary.withValues(alpha: 0.12),
                        borderRadius: const BorderRadius.all(Radius.circular(999)),
                        border: Border.all(color: scheme.primary.withValues(alpha: 0.5)),
                      ),
                      child: Text(
                        'gamification.xp_gain'.tr(namedArgs: {'n': '${event.xp}'}),
                        style: theme.textTheme.labelMedium?.copyWith(color: scheme.primary, fontWeight: FontWeight.w800),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${event.date.day} ${'home.month_${event.date.month}'.tr()}',
                      style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  static IconData _icon(XpSource source) => switch (source) {
        XpSource.workout => Icons.fitness_center,
        XpSource.record => Icons.bolt,
        XpSource.mealDay => Icons.restaurant,
      };

  static String _title(XpEvent event) => switch (event.source) {
        XpSource.workout => event.label ?? '',
        XpSource.record => 'gamification.record'.tr(namedArgs: {'name': event.label ?? ''}),
        XpSource.mealDay => 'gamification.meal_day'.tr(),
      };

  static String? _detail(XpEvent event) => switch (event.source) {
        XpSource.workout => 'gamification.workout_sets'.tr(namedArgs: {'n': '${event.sets}'}),
        XpSource.record => 'gamification.record_detail'.tr(namedArgs: {
            'kg': formatKg(event.weightKg ?? 0),
            'reps': '${event.reps ?? 0}',
          }),
        XpSource.mealDay => null,
      };

  /// 140.0 → "140", 62.5 → "62.5".
  static String formatKg(double kg) => kg == kg.roundToDouble() ? '${kg.toInt()}' : kg.toStringAsFixed(1);
}
```

- [ ] **Step 5: Rotayı ekle**

`lib/core/router.dart` importlarına ekle:

```dart
import '../features/gamification/presentation/level_screen.dart';
```

`/home` rotasının `routes` listesinde `GoRoute(path: 'measurements', ...)` satırından sonra ekle:

```dart
                  GoRoute(path: 'levels', builder: (context, state) => const LevelScreen()),
```

- [ ] **Step 6: Testlerin geçtiğini gör**

Run: `flutter test --no-pub -j 1 test/features/gamification/presentation/level_screen_test.dart`
Expected: PASS (5 test).

- [ ] **Step 7: Analiz**

Run: `flutter analyze --no-pub` (arka planda)
Expected: `No issues found!`

- [ ] **Step 8: Commit**

```bash
git add lib/features/gamification/presentation/title_names.dart lib/features/gamification/presentation/level_screen.dart lib/core/router.dart test/features/gamification/presentation/level_screen_test.dart
git commit -m "feat(gamification): add the level screen with titles, rank ladder and recent gains

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 7: Doğrulama ve kayıt

**Files:**
- Modify: `PLAN.md`

- [ ] **Step 1: Statik analiz**

Run: `flutter analyze --no-pub` (arka planda)
Expected: `No issues found!`

- [ ] **Step 2: Kullanıcıdan tam test paketi**

Kullanıcı kendi terminalinde `flutter test --no-pub -j 1` çalıştırır.
Expected: Hepsi geçer. Beklenen ≈ 544 + XP 7 + seviye 4 + unvan 5 + özet 2 + sağlayıcı 3 + rozet 2 + ana sayfa 1 + ekran 5 = ~573.

- [ ] **Step 3: Kullanıcıdan web release derlemesi ve manuel kontrol**

Kullanıcı `flutter build web --release --no-pub` çalıştırır ve `build/web`'i sunar: `python -m http.server 5555 --bind 127.0.0.1`.

Kontrol listesi (spec §11):
1. Ana sayfada dişlinin yanında rütbe rozeti ve "Sv n" görünüyor; dokununca seviye ekranı açılıyor.
2. Mevcut geçmişle seviye, rütbe ve toplam XP makul (geçmişe dönük hesap).
3. XP dökümü toplamı toplam XP'ye eşit.
4. Yeni bir antrenman bitirince rozet ve ekran güncelleniyor; rekor kırılınca "Rekor: …" kazanımı görünüyor.
5. Öğün kaydedilen gün "Öğün kaydı · +10 XP" olarak bir kez görünüyor.
6. Unvanlar mantıklı; TAK → başlıkta görünüyor, uygulama yenilenince de duruyor; TAKILI'ya dokununca kayboluyor.
7. Rütbe merdiveni mevcut rütbeye kaydırılmış; kilitliler soluk.
8. Yaklaşık 360 px genişlikte taşma yok; EN dilinde metinler doğru.

- [ ] **Step 4: PLAN.md satırı ve commit**

`PLAN.md`'de K3 satırından sonra O1 satırı eklenir (tarih, dal, özet, sapmalar, test sayısı, manuel sonuç, sıradaki: S1 arkadaşlık). Ardından:

```bash
git add PLAN.md
git commit -m "docs: record O1 personal gamification in the plan

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

- [ ] **Step 5: Dalı bitir**

superpowers:finishing-a-development-branch; kullanıcı onayıyla `f5p-oyunlastirma` → `master` fast-forward + push.
