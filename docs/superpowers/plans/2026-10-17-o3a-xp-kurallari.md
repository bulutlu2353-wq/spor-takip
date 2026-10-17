# O3a XP Makullük Kuralları — Uygulama Planı

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** XP, meydan okuma ve dönem sıralamasını makul olmayan kullanımlara (antrenman spamı, hızlı set işaretleme, rekor sağma, abartılı kilolar) karşı tek bir kural modülüyle süzmek.

**Architecture:** Saf `fair_play.dart` her bitmiş oturum için bir `SessionVerdict` üretir (sayılır mı, neden, hangi setler). `xpEvents` (antrenman + rekor XP'si), `challengeValue` ve `buildPeriodStats` aynı kararı kullanır. Seviye ekranı 0 XP'lik antrenmanı nedeniyle gösterir ve bir "XP kuralları" sayfası açar. Migration yok.

**Tech Stack:** Flutter, Riverpod 3, easy_localization, flutter_test.

**Spec:** `docs/superpowers/specs/2026-10-17-o3a-xp-kurallari-design.md`

## Global Constraints

- Sabitler: en az 3 set, en az 10 dk, günde en çok 2 sayılan antrenman, her 2 dakikaya 1 set, en çok 30 set, tahmini 1RM 500 kg üstü makul değil, rekor için en az %2,5, %50 üstü sıçrama XP yok ama taban olur, hareket başına 7 günde 1 rekor XP'si, oturum başına en çok 3 rekor.
- Kurallar tüm geçmişe uygulanır; öğün XP'si ve unvan hesabı (`titleProgress`) değişmez; `WeeklyStats` ham kalır.
- Günlük sınır ve soğuma yerel zamanla.
- Var olan CRLF dosyaları CRLF kalır (düzenleme yardımcısı satır sonlarını korumalı).
- Testler: `flutter test --no-pub -j 1 <dosya>`; analiz: `flutter analyze lib test` → `No issues found!`.
- Commit mesajları İngilizce, sonunda `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.

---

### Task 1: Oturum kararı (`fair_play.dart`)

**Files:**
- Create: `lib/features/gamification/domain/fair_play.dart`
- Modify: `test/features/gamification/game_fixtures.dart`
- Test: `test/features/gamification/domain/fair_play_test.dart`

**Interfaces:**
- Consumes: `estimateOneRepMax({double? weightKg, int? reps})` (`lib/features/progress/domain/strength.dart`), `WorkoutSession`, `SessionSet`.
- Produces: sabitler `minCountedSets`, `minCountedDuration`, `maxCountedWorkoutsPerDay`, `minutesPerCountedSet`, `maxCountedSets`, `maxPlausibleOneRepMaxKg`, `minRecordGain`, `maxRecordJump`, `recordCooldown`, `maxRecordsPerSession`; `enum SkipReason { tooSmall, dailyLimit }`; `class SessionVerdict { WorkoutSession session; List<SessionSet> plausibleSets; SkipReason? skip; List<SessionSet> countedSets; bool get counted; DateTime get finishedAt /* yerel */ }`; `bool isPlausibleSet(SessionSet set)`; `List<SessionVerdict> judgeSessions(List<WorkoutSession> sessions)`. Fikstür: `gameSet(..., DateTime? at)`, `gameSession(..., Duration duration = const Duration(hours: 1))`.

- [ ] **Step 1: Fikstürü genişlet**

`test/features/gamification/game_fixtures.dart` içinde `gameSet` ve `gameSession`'ı şu hâle getir (davranış varsayılanlarda aynı):

```dart
SessionSet gameSet(String exerciseId, {double? kg, int? reps, bool done = true, int index = 0, DateTime? at}) =>
    SessionSet(
      exercisePosition: 0,
      setIndex: index,
      exerciseId: exerciseId,
      exerciseName: exerciseId == 'bench' ? 'Barbell Bench Press' : 'Barbell Squat',
      targetRepsMin: 5,
      targetRepsMax: 5,
      weightKg: kg,
      reps: reps,
      completedAt: done ? (at ?? DateTime(2026, 10, 1)) : null,
    );

/// [finishedAt] null → devam eden oturum. Tarihler yerel; [duration] bitişten geriye başlangıç.
WorkoutSession gameSession(
  String id,
  DateTime? finishedAt,
  List<SessionSet> sets, {
  String workoutName = 'Push A',
  Duration duration = const Duration(hours: 1),
}) =>
    WorkoutSession(
      id: id,
      programName: 'P',
      workoutName: workoutName,
      workoutPosition: 0,
      startedAt: (finishedAt ?? DateTime(2026, 10, 1)).subtract(duration),
      finishedAt: finishedAt,
      sets: sets,
    );
```

- [ ] **Step 2: Failing testleri yaz**

`test/features/gamification/domain/fair_play_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:spor_takip/features/gamification/domain/fair_play.dart';

import '../game_fixtures.dart';

void main() {
  test('unfinished sessions and sessions without completed sets are left out', () {
    expect(
      judgeSessions([
        gameSession('live', null, gameSets('bench', 5)),
        gameSession('empty', DateTime(2026, 10, 1), [gameSet('bench', done: false)]),
      ]),
      isEmpty,
    );
  });

  test('a session needs three completed sets and ten minutes', () {
    final verdicts = judgeSessions([
      gameSession('two', DateTime(2026, 10, 1, 9), gameSets('bench', 2)),
      gameSession('short', DateTime(2026, 10, 2, 9), gameSets('bench', 5), duration: const Duration(minutes: 9)),
      gameSession('ok', DateTime(2026, 10, 3, 9), gameSets('bench', 3), duration: const Duration(minutes: 10)),
      gameSession('backwards', DateTime(2026, 10, 4, 9), gameSets('bench', 5), duration: const Duration(minutes: -30)),
    ]);
    expect([for (final v in verdicts) (v.session.id, v.skip)], [
      ('two', SkipReason.tooSmall),
      ('short', SkipReason.tooSmall),
      ('ok', null),
      ('backwards', SkipReason.tooSmall),
    ]);
    expect(verdicts[2].counted, isTrue);
    expect(verdicts[2].countedSets, hasLength(3));
    expect(verdicts[2].finishedAt, DateTime(2026, 10, 3, 9));
    expect(verdicts.first.countedSets, isEmpty);
    expect(verdicts.first.plausibleSets, hasLength(2));
  });

  test('only the first two eligible sessions of a local day count; small ones do not use the limit', () {
    final verdicts = judgeSessions([
      gameSession('c', DateTime(2026, 10, 1, 20), gameSets('bench', 3)),
      gameSession('a', DateTime(2026, 10, 1, 8), gameSets('bench', 3)),
      gameSession('small', DateTime(2026, 10, 1, 10), gameSets('bench', 1)),
      gameSession('b', DateTime(2026, 10, 1, 14), gameSets('bench', 3)),
      gameSession('next', DateTime(2026, 10, 2, 8), gameSets('bench', 3)),
    ]);
    expect([for (final v in verdicts) (v.session.id, v.skip)], [
      ('a', null),
      ('small', SkipReason.tooSmall),
      ('b', null),
      ('c', SkipReason.dailyLimit),
      ('next', null),
    ]);
    expect(verdicts[3].countedSets, isEmpty);
  });

  test('counted sets are capped at one per two minutes and at thirty, in completion order', () {
    final early = DateTime(2026, 10, 1, 9);
    final verdicts = judgeSessions([
      gameSession(
        'a',
        DateTime(2026, 10, 1, 10),
        [for (var i = 0; i < 20; i++) gameSet('bench', index: i, at: early.add(Duration(minutes: 20 - i)))],
        duration: const Duration(minutes: 24),
      ),
      gameSession('b', DateTime(2026, 10, 2, 10), gameSets('bench', 40), duration: const Duration(hours: 2)),
    ]);
    expect(verdicts[0].countedSets, hasLength(12));
    // En büyük index'li set en erken tamamlandı.
    expect(verdicts[0].countedSets.first.setIndex, 19);
    expect(verdicts[0].countedSets.last.setIndex, 8);
    expect(verdicts[1].countedSets, hasLength(30));
  });

  test('sets over 500 kg are not plausible and do not make a session eligible', () {
    expect(isPlausibleSet(gameSet('squat', kg: 400, reps: 8)), isFalse); // ≈ 506.7
    expect(isPlausibleSet(gameSet('squat', kg: 600, reps: 12)), isFalse); // tahmin yok, kilo 500 üstü
    expect(isPlausibleSet(gameSet('squat', kg: 300, reps: 10)), isTrue); // 400
    expect(isPlausibleSet(gameSet('squat')), isTrue); // kilosuz
    final verdict = judgeSessions([
      gameSession('a', DateTime(2026, 10, 1), [
        ...gameSets('squat', 2, kg: 100, reps: 5),
        gameSet('squat', kg: 900, reps: 1, index: 5),
      ]),
    ]).single;
    expect(verdict.skip, SkipReason.tooSmall);
    expect(verdict.plausibleSets, hasLength(2));
  });
}
```

- [ ] **Step 3: Testin başarısız olduğunu gör**

Run: `flutter test --no-pub -j 1 test/features/gamification/domain/fair_play_test.dart`
Expected: FAIL — `fair_play.dart` yok.

- [ ] **Step 4: Modülü yaz**

`lib/features/gamification/domain/fair_play.dart`:

```dart
import 'dart:math' as math;

import '../../progress/domain/strength.dart';
import '../../workout/domain/workout_session.dart';

/// Makullük kuralları (O3a spec §3.1).
const minCountedSets = 3;
const minCountedDuration = Duration(minutes: 10);
const maxCountedWorkoutsPerDay = 2;
const minutesPerCountedSet = 2;
const maxCountedSets = 30;
const maxPlausibleOneRepMaxKg = 500.0;
const minRecordGain = 0.025;
const maxRecordJump = 0.5;
const recordCooldown = Duration(days: 7);
const maxRecordsPerSession = 3;

/// Oturumun XP getirmeme nedeni.
enum SkipReason { tooSmall, dailyLimit }

/// Bir bitmiş oturumun kararı (O3a spec §3.2).
class SessionVerdict {
  const SessionVerdict({required this.session, required this.plausibleSets, this.skip, this.countedSets = const []});

  final WorkoutSession session;

  /// Tamamlanmış ve makul setler; sayılmayan oturumda da dolu (rekor tabanı için).
  final List<SessionSet> plausibleSets;

  /// null → sayılır.
  final SkipReason? skip;

  /// Sayılan setler, tamamlanma sırasıyla; sayılmayan oturumda boş.
  final List<SessionSet> countedSets;

  bool get counted => skip == null;

  /// Yerel bitiş.
  DateTime get finishedAt => session.finishedAt!.toLocal();
}

/// Kilosu ya da tahmini 1RM'si [maxPlausibleOneRepMaxKg]'ı geçen set makul değil.
bool isPlausibleSet(SessionSet set) {
  if ((set.weightKg ?? 0) > maxPlausibleOneRepMaxKg) return false;
  final estimate = estimateOneRepMax(weightKg: set.weightKg, reps: set.reps);
  return estimate == null || estimate <= maxPlausibleOneRepMaxKg;
}

/// Bitmiş ve tamamlanmış seti olan oturumlar, bitişe göre eskiden yeniye.
List<SessionVerdict> judgeSessions(List<WorkoutSession> sessions) {
  final finished = [
    for (final s in sessions)
      if (s.finishedAt != null && s.sets.any((set) => set.isCompleted)) s,
  ]..sort((a, b) => a.finishedAt!.compareTo(b.finishedAt!));
  final perDay = <DateTime, int>{};
  return [for (final session in finished) _judge(session, perDay)];
}

SessionVerdict _judge(WorkoutSession session, Map<DateTime, int> perDay) {
  final plausible = [
    for (final set in session.sets)
      if (set.isCompleted && isPlausibleSet(set)) set,
  ];
  final duration = session.finishedAt!.difference(session.startedAt);
  if (plausible.length < minCountedSets || duration < minCountedDuration) {
    return SessionVerdict(session: session, plausibleSets: plausible, skip: SkipReason.tooSmall);
  }
  final local = session.finishedAt!.toLocal();
  final day = DateTime(local.year, local.month, local.day);
  final used = perDay[day] ?? 0;
  if (used >= maxCountedWorkoutsPerDay) {
    return SessionVerdict(session: session, plausibleSets: plausible, skip: SkipReason.dailyLimit);
  }
  perDay[day] = used + 1;
  final ordered = [...plausible]..sort(_byCompletion);
  final limit = math.min(maxCountedSets, duration.inMinutes ~/ minutesPerCountedSet);
  return SessionVerdict(session: session, plausibleSets: plausible, countedSets: ordered.take(limit).toList());
}

/// Tamamlanma zamanı; eşitlikte hareket sırası ve set sırası (sıralama kararlı olsun).
int _byCompletion(SessionSet a, SessionSet b) {
  final byTime = a.completedAt!.compareTo(b.completedAt!);
  if (byTime != 0) return byTime;
  final byExercise = a.exercisePosition.compareTo(b.exercisePosition);
  return byExercise != 0 ? byExercise : a.setIndex.compareTo(b.setIndex);
}
```

- [ ] **Step 5: Testlerin geçtiğini gör**

Run: `flutter test --no-pub -j 1 test/features/gamification/domain/fair_play_test.dart`
Expected: PASS (5 test). `maxCountedSets` henüz `xp_rules.dart`'ta da tanımlı; bu dosyayı içe aktaran test olmadığından çakışma yok (Task 2 kaldırır).

- [ ] **Step 6: Commit**

```bash
git add lib/features/gamification/domain/fair_play.dart test/features/gamification/domain/fair_play_test.dart test/features/gamification/game_fixtures.dart
git commit -m "feat(xp): add session verdicts for the XP sanity rules"
```

---

### Task 2: XP olayları yeni kurallarla

**Files:**
- Modify: `lib/features/gamification/domain/xp_rules.dart`
- Modify: `test/features/gamification/domain/xp_rules_test.dart`
- Modify: `test/features/gamification/application/gamification_providers_test.dart`

**Interfaces:**
- Consumes: Task 1'deki `judgeSessions`, `SessionVerdict`, `SkipReason`, sabitler.
- Produces: `XpEvent.skip` (`SkipReason?`, varsayılan null); `xpEvents` imzası aynı (`List<XpEvent> xpEvents(List<WorkoutSession> sessions, List<DateTime> mealTimes)`); `xpBreakdown` antrenman tabanını yalnız `xp > 0` antrenmanlarda sayar. `maxCountedSets` artık yalnız `fair_play.dart`'ta.

- [ ] **Step 1: Testleri güncelle ve ekle**

`xp_rules_test.dart`:
1. Import ekle: `package:spor_takip/features/gamification/domain/fair_play.dart`, `package:spor_takip/features/workout/domain/workout_session.dart`.
2. `the breakdown splits workout XP into base and sets` testini şununla değiştir:

```dart
  test('the breakdown splits workout XP into base and sets and skips 0 XP workouts', () {
    final events = xpEvents([
      gameSession('s1', DateTime(2026, 10, 1), [gameSet('bench', kg: 100, reps: 5)]),
      gameSession('s2', DateTime(2026, 10, 2), [...gameSets('bench', 3, kg: 100, reps: 8)]),
    ], [DateTime(2026, 10, 1, 12)]);
    final breakdown = xpBreakdown(events);
    expect(breakdown.workouts, 50);
    expect(breakdown.sets, 15);
    expect(breakdown.records, 25);
    expect(breakdown.mealDays, 10);
    expect(breakdown.total, 100);
  });
```

3. `main()` başına yardımcılar, dosya sonuna (son `}`'den önce) testler:

```dart
  List<XpEvent> records(List<XpEvent> events) => [
        for (final e in events)
          if (e.source == XpSource.record) e,
      ];
  WorkoutSession bench(String id, DateTime at, double kg) => gameSession(id, at, gameSets('bench', 3, kg: kg, reps: 5));
```

```dart
  test('a skipped session gives a 0 XP workout event with its reason', () {
    final events = xpEvents([gameSession('a', DateTime(2026, 10, 1, 18), gameSets('bench', 2))], const []);
    expect((events.single.xp, events.single.sets, events.single.skip), (0, 0, SkipReason.tooSmall));
  });

  test('counted sets follow the session time cap', () {
    final events = xpEvents([
      gameSession('a', DateTime(2026, 10, 1, 18), gameSets('bench', 20), duration: const Duration(minutes: 24)),
    ], const []);
    expect((events.single.xp, events.single.sets, events.single.skip), (110, 12, null));
  });

  test('a record needs a 2.5% gain; smaller gains still raise the best', () {
    final events = xpEvents([
      bench('s1', DateTime(2026, 10, 1, 18), 100),
      bench('s2', DateTime(2026, 10, 10, 18), 102), // +%2 → yok, taban 102
      bench('s3', DateTime(2026, 10, 20, 18), 104), // 102'ye göre +%1,96 → yok, taban 104
      bench('s4', DateTime(2026, 10, 30, 18), 107), // 104'e göre +%2,9 → rekor
    ], const []);
    expect([for (final r in records(events)) (r.date, r.weightKg)], [(DateTime(2026, 10, 30, 18), 107.0)]);
  });

  test('a jump over 50% gives no XP but becomes the new best', () {
    final events = xpEvents([
      bench('s1', DateTime(2026, 10, 1, 18), 20),
      bench('s2', DateTime(2026, 10, 10, 18), 60), // +%200 → yok, taban 60
      bench('s3', DateTime(2026, 10, 20, 18), 62), // +%3,3 → rekor
    ], const []);
    expect([for (final r in records(events)) r.weightKg], [62.0]);
  });

  test('the same exercise earns a record at most once in seven days', () {
    final events = xpEvents([
      bench('s1', DateTime(2026, 10, 1, 18), 100),
      bench('s2', DateTime(2026, 10, 2, 18), 105), // rekor
      bench('s3', DateTime(2026, 10, 7, 18), 110), // 5 gün → XP yok, taban 110
      bench('s4', DateTime(2026, 10, 9, 18), 115), // 7 gün → rekor (110'a göre +%4,5)
    ], const []);
    expect([for (final r in records(events)) r.date], [DateTime(2026, 10, 2, 18), DateTime(2026, 10, 9, 18)]);
  });

  test('one session gives at most three records, the biggest gains first', () {
    final events = xpEvents([
      gameSession('s1', DateTime(2026, 10, 1, 18), [
        for (final (i, id) in ['bench', 'squat', 'row', 'press'].indexed) gameSet(id, kg: 100, reps: 5, index: i),
      ]),
      gameSession('s2', DateTime(2026, 10, 10, 18), [
        gameSet('bench', kg: 110, reps: 5), // +%10
        gameSet('squat', kg: 104, reps: 5, index: 1), // +%4
        gameSet('row', kg: 120, reps: 5, index: 2), // +%20
        gameSet('press', kg: 103, reps: 5, index: 3), // +%3 → dışarıda
      ]),
    ], const []);
    expect({for (final r in records(events)) r.weightKg}, {120.0, 110.0, 104.0});
  });

  test('a record in a skipped session gives no XP but raises the best', () {
    final events = xpEvents([
      bench('s1', DateTime(2026, 10, 1, 18), 100),
      gameSession('s2', DateTime(2026, 10, 10, 18), [gameSet('bench', kg: 110, reps: 5)]), // tek set → sayılmaz
      bench('s3', DateTime(2026, 10, 20, 18), 112), // 110'a göre +%1,8 → yok
    ], const []);
    expect(records(events), isEmpty);
  });
```

`gamification_providers_test.dart`: `_container()` içindeki oturumu `gameSets('bench', 3)` yap; "the player summary joins..." testinde yorumu `// 50 + 3 × 5 + 10.` ve beklentiyi `expect(summary.totalXp, 75);` yap.

- [ ] **Step 2: Testlerin başarısız olduğunu gör**

Run: `flutter test --no-pub -j 1 test/features/gamification/domain/xp_rules_test.dart`
Expected: FAIL — `skip` parametresi yok; kural testleri yanlış değer.

- [ ] **Step 3: `xp_rules.dart`'ı yeniden yaz**

1. `import 'dart:math' as math;` satırını kaldır; `import 'fair_play.dart';` ekle (`../../progress/domain/strength.dart` ve `workout_session.dart` kalır).
2. `XpEvent`'e alan ekle: kurucuya `this.skip,` ve sınıfa:

```dart
  /// Yalnız antrenmanda: XP getirmediyse nedeni (O3a spec §3.3).
  final SkipReason? skip;
```

`sets` alanının yorumunu `/// Yalnız antrenmanda: sayılan set (O3a süre tavanıyla).` yap.
3. `const maxCountedSets = 30;` satırını sil.
4. `xpEvents`'i ve yeni `_records`'u şöyle yaz (öğün kısmı aynı):

```dart
/// Eskiden yeniye; aynı anda antrenman → rekor → öğün. Kurallar: O3a spec §3.
List<XpEvent> xpEvents(List<WorkoutSession> sessions, List<DateTime> mealTimes) {
  final events = <XpEvent>[];
  final best = <String, double>{};
  final lastRecord = <String, DateTime>{};
  for (final verdict in judgeSessions(sessions)) {
    final sets = verdict.countedSets.length;
    events.add(XpEvent(
      source: XpSource.workout,
      date: verdict.finishedAt,
      xp: verdict.counted ? xpPerWorkout + sets * xpPerSet : 0,
      label: verdict.session.workoutName,
      sets: sets,
      skip: verdict.skip,
    ));
    events.addAll(_records(verdict, best, lastRecord));
  }

  final days = <DateTime>{
    for (final time in mealTimes)
      if (time.toLocal() case final local) DateTime(local.year, local.month, local.day),
  };
  for (final day in days) {
    events.add(XpEvent(source: XpSource.mealDay, date: day, xp: xpPerMealDay));
  }

  events.sort(compareXpEvents);
  return events;
}

/// Oturumun rekor olayları; [best] (taban) ve [lastRecord] (son rekor XP'si) yerinde güncellenir.
List<XpEvent> _records(SessionVerdict verdict, Map<String, double> best, Map<String, DateTime> lastRecord) {
  final date = verdict.finishedAt;
  final top = <String, (double, SessionSet)>{};
  for (final set in verdict.plausibleSets) {
    final estimate = estimateOneRepMax(weightKg: set.weightKg, reps: set.reps);
    if (estimate == null) continue;
    if (estimate > (top[set.exerciseId]?.$1 ?? 0)) top[set.exerciseId] = (estimate, set);
  }
  final candidates = <(double, SessionSet)>[];
  for (final MapEntry(key: exerciseId, value: (estimate, set)) in top.entries) {
    final previous = best[exerciseId];
    if (previous == null || estimate > previous) best[exerciseId] = estimate;
    if (previous == null || !verdict.counted) continue;
    final gain = estimate / previous - 1;
    if (gain < minRecordGain || gain > maxRecordJump) continue;
    final last = lastRecord[exerciseId];
    if (last != null && date.difference(last) < recordCooldown) continue;
    candidates.add((gain, set));
  }
  candidates.sort((a, b) {
    final byGain = b.$1.compareTo(a.$1);
    return byGain != 0 ? byGain : a.$2.exerciseId.compareTo(b.$2.exerciseId);
  });
  final events = <XpEvent>[];
  for (final (_, set) in candidates.take(maxRecordsPerSession)) {
    lastRecord[set.exerciseId] = date;
    events.add(XpEvent(
      source: XpSource.record,
      date: date,
      xp: xpPerRecord,
      label: set.exerciseName,
      weightKg: set.weightKg,
      reps: set.reps,
    ));
  }
  return events;
}
```

5. `xpBreakdown` içinde antrenman dalını değiştir:

```dart
      case XpSource.workout:
        if (e.xp > 0) workouts += xpPerWorkout;
        sets += e.sets * xpPerSet;
```

(Sayılmayan antrenmanda `sets = 0` olduğundan set toplamı zaten etkilenmez.)

- [ ] **Step 4: Testlerin geçtiğini gör**

Run: `flutter test --no-pub -j 1 test/features/gamification/domain/xp_rules_test.dart test/features/gamification/domain/fair_play_test.dart test/features/gamification/domain/player_summary_test.dart test/features/gamification/application/gamification_providers_test.dart test/features/social/domain/player_stats_test.dart`
Expected: PASS. (`player_stats_test`: 'sun' oturumu artık 0 XP ama tabanı kurar; 'mon' rekoru %2,9 artışla kalır.)

- [ ] **Step 5: Commit**

```bash
git add lib/features/gamification/domain/xp_rules.dart test/features/gamification/domain/xp_rules_test.dart test/features/gamification/application/gamification_providers_test.dart
git commit -m "feat(xp): apply the sanity rules to workout and record XP"
```

---

### Task 3: Meydan okuma ve dönem kas sıralaması

**Files:**
- Modify: `lib/features/social/domain/challenge_progress.dart`
- Modify: `lib/features/social/domain/period_stats.dart`
- Modify: `test/features/social/domain/challenge_progress_test.dart`
- Modify: `test/features/social/domain/period_stats_test.dart`

**Interfaces:**
- Consumes: `judgeSessions`, `SessionVerdict` (Task 1).
- Produces: `challengeValue` ve `buildPeriodStats` imzaları aynı; XP dışı değerler yalnız sayılan oturumların `countedSets`'inden.

- [ ] **Step 1: Testleri güncelle**

`challenge_progress_test.dart` — son testten sonra ekle:

```dart
  test('skipped sessions and sets over the time cap do not count', () {
    final sessions = [
      gameSession('small', DateTime(2026, 10, 8, 9), gameSets('bench', 2)),
      gameSession('rushed', DateTime(2026, 10, 9, 9), gameSets('bench', 10), duration: const Duration(minutes: 12)),
    ];
    double value(ChallengeMetric metric) =>
        challengeValue(socialChallenge(metric: metric), sessions, const [], gameExercisesById);
    expect(value(ChallengeMetric.workouts), 1);
    expect(value(ChallengeMetric.sets), 6);
  });
```

`period_stats_test.dart` — `_sessions`'ı ve iki testteki beklentileri şöyle değiştir:

```dart
// W41 = 5–11 Ekim, W40 = 28 Eylül–4 Ekim.
final _sessions = [
  gameSession('a', DateTime(2026, 10, 8, 18), gameSets('bench', 3)), // W41: 65 XP
  gameSession('d', DateTime(2026, 10, 5), gameSets('squat', 3)), // W41 sınırı: 65 XP
  gameSession('small', DateTime(2026, 10, 7, 9), gameSets('bench', 2)), // W41 ama sayılmaz: 0 XP, kas yok
  gameSession('b', DateTime(2026, 10, 4, 23, 59), gameSets('squat', 4)), // W40: 70 XP
  gameSession('c', DateTime(2026, 9, 20, 10), gameSets('bench', 3)), // Eylül: 65 XP
  gameSession('open', null, gameSets('bench', 4)), // bitmemiş: sayılmaz
];
```

```dart
    expect(stats.week.key, '2026-W41');
    expect(stats.week.xp, 140);
    expect(stats.week.muscles, {'chest': 3.0, 'triceps': 1.5, 'quadriceps': 3.0});

    expect(stats.prevWeek.key, '2026-W40');
    expect(stats.prevWeek.xp, 70);
    expect(stats.prevWeek.muscles, {'quadriceps': 4.0});

    expect(stats.month.key, '2026-10');
    expect(stats.month.xp, 210);
    expect(stats.month.muscles, {'chest': 3.0, 'triceps': 1.5, 'quadriceps': 7.0});

    expect(stats.prevMonth.key, '2026-09');
    expect(stats.prevMonth.xp, 65);
    expect(stats.prevMonth.muscles, {'chest': 3.0, 'triceps': 1.5});
```

```dart
    expect(stats.slotFor(PeriodKind.week, '2026-W40')?.xp, 70);
    expect(stats.slotFor(PeriodKind.week, '2026-W41')?.xp, 140);
    expect(stats.slotFor(PeriodKind.week, '2026-W39'), isNull);
    expect(stats.slotFor(PeriodKind.month, '2026-W41'), isNull);
    expect(stats.valueFor(PeriodKind.month, '2026-10', 'quadriceps'), 7);
    expect(stats.valueFor(PeriodKind.month, '2026-09', 'xp'), 65);
```

- [ ] **Step 2: Testlerin başarısız olduğunu gör**

Run: `flutter test --no-pub -j 1 test/features/social/domain/challenge_progress_test.dart test/features/social/domain/period_stats_test.dart`
Expected: FAIL — kas toplamları ve set/antrenman sayıları ham veriden geliyor.

- [ ] **Step 3: Hesapları değiştir**

`challenge_progress.dart`: import ekle `../../gamification/domain/fair_play.dart`; XP dışı döngüyü şöyle yaz:

```dart
  var total = 0.0;
  for (final verdict in judgeSessions(sessions)) {
    if (!verdict.counted || !inWindow(verdict.finishedAt)) continue;
    if (challenge.metric == ChallengeMetric.workouts) {
      total += 1;
      continue;
    }
    for (final set in verdict.countedSets) {
      final weight = switch (challenge.muscle) {
        null => 1.0,
        final muscle => switch (exercisesById[set.exerciseId]) {
            final exercise? => muscleWeight(exercise, muscle),
            null => 0.0,
          },
      };
      if (weight == 0) continue;
      total += challenge.metric == ChallengeMetric.sets ? weight : (set.weightKg ?? 0) * (set.reps ?? 0) * weight;
    }
  }
  return challenge.metric == ChallengeMetric.volume ? total.roundToDouble() : total;
```

Fonksiyon yorumunu `/// Pencerede (`[startsAt, endsAt)`) bitmiş ve sayılan oturumlardan değer (S3 spec §3.2, O3a spec §3.4).` yap. `workout_session.dart` importu artık kullanılmıyorsa da imza `List<WorkoutSession>` aldığı için kalır.

`period_stats.dart`: import ekle `../../gamification/domain/fair_play.dart`; `slot` içindeki kas döngüsünü şöyle yaz:

```dart
    final muscles = <String, double>{};
    for (final verdict in judgeSessions(sessions)) {
      if (!verdict.counted || !inRange(verdict.finishedAt)) continue;
      for (final set in verdict.countedSets) {
        final exercise = exercisesById[set.exerciseId];
        if (exercise == null) continue;
        for (final muscle in muscleGroups) {
          final weight = muscleWeight(exercise, muscle);
          if (weight > 0) muscles[muscle] = (muscles[muscle] ?? 0) + weight;
        }
      }
    }
```

`judgeSessions(sessions)` her `slot` çağrısında yeniden hesaplanmasın: `buildPeriodStats` gövdesinin başında `final verdicts = judgeSessions(sessions);` tanımla ve döngüde `verdicts` kullan.

- [ ] **Step 4: Testlerin geçtiğini gör**

Run: `flutter test --no-pub -j 1 test/features/social/domain/challenge_progress_test.dart test/features/social/domain/period_stats_test.dart test/features/social/application/social_providers_test.dart test/features/social/application/challenge_providers_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/social/domain/challenge_progress.dart lib/features/social/domain/period_stats.dart test/features/social/domain/challenge_progress_test.dart test/features/social/domain/period_stats_test.dart
git commit -m "feat(xp): count only fair sessions in challenges and period muscle boards"
```

---

### Task 4: Seviye ekranı — 0 XP nedeni ve XP kuralları

**Files:**
- Modify: `lib/features/gamification/presentation/level_screen.dart`
- Modify: `assets/translations/tr.json`, `assets/translations/en.json`
- Modify: `test/features/gamification/presentation/level_screen_test.dart`

**Interfaces:**
- Consumes: `XpEvent.skip`, `SkipReason` (Task 1–2).
- Produces: anahtarlar `level_rules_button`, `level_rules_sheet`; çeviriler `gamification.skip_too_small`, `skip_daily_limit`, `xp_none`, `rules_title`, `rules_workout`, `rules_minimum`, `rules_daily`, `rules_sets`, `rules_records`, `rules_meals`, `rules_challenges`.

- [ ] **Step 1: Çevirileri ekle**

`gamification` bölümünün sonuna (`"value_wins"` satırından sonra, virgülle):

tr:
```json
    "skip_too_small": "En az 3 set ve 10 dakika gerekir",
    "skip_daily_limit": "Günlük 2 antrenman sınırı",
    "xp_none": "0 XP",
    "rules_title": "XP kuralları",
    "rules_workout": "Antrenman: 50 XP + sayılan her set için 5 XP.",
    "rules_minimum": "Antrenmanın XP getirmesi için en az 3 set ve 10 dakika gerekir.",
    "rules_daily": "Günde en çok 2 antrenman XP getirir.",
    "rules_sets": "Her 2 dakikaya 1 set sayılır, en çok 30 set.",
    "rules_records": "Rekor: 25 XP. En az %2,5 artış gerekir; aynı hareketten haftada 1, bir antrenmanda en çok 3 rekor.",
    "rules_meals": "Öğün kaydettiğin her gün: 10 XP.",
    "rules_challenges": "Kazandığın meydan okumalar ödül XP'si verir."
```

en:
```json
    "skip_too_small": "Needs at least 3 sets and 10 minutes",
    "skip_daily_limit": "Daily limit of 2 workouts",
    "xp_none": "0 XP",
    "rules_title": "XP rules",
    "rules_workout": "Workout: 50 XP + 5 XP for each counted set.",
    "rules_minimum": "A workout needs at least 3 sets and 10 minutes to earn XP.",
    "rules_daily": "Up to 2 workouts a day earn XP.",
    "rules_sets": "One set counts per 2 minutes of workout, up to 30 sets.",
    "rules_records": "Record: 25 XP. Needs at least a 2.5% gain; once a week per exercise, up to 3 per workout.",
    "rules_meals": "Each day you log a meal: 10 XP.",
    "rules_challenges": "Challenges you win give reward XP."
```

Run: `python -c "import json;[json.load(open(f'assets/translations/{l}.json',encoding='utf-8')) for l in ('tr','en')]"`
Expected: hata yok.

- [ ] **Step 2: Failing widget testleri**

`level_screen_test.dart`: importlar `package:easy_localization/easy_localization.dart`, `package:spor_takip/features/gamification/domain/fair_play.dart`. Dosya sonuna (son `}`'den önce):

```dart
  testWidgets('a workout without XP shows 0 XP and the reason', (tester) async {
    final skipped = PlayerSummary(
      totalXp: 0,
      progress: levelFor(0),
      rank: Rank.rookie,
      breakdown: const XpBreakdown(),
      recent: [
        XpEvent(source: XpSource.workout, date: DateTime(2026, 10, 9, 18), xp: 0, label: 'Kısa', skip: SkipReason.tooSmall),
        XpEvent(source: XpSource.workout, date: DateTime(2026, 10, 9, 12), xp: 0, label: 'Üçüncü', skip: SkipReason.dailyLimit),
      ],
      titles: const [],
      upcoming: const [],
    );
    await pump(tester, () async => skipped);
    final recent = find.byKey(const Key('level_recent'));
    expect(find.descendant(of: recent, matching: find.text('gamification.skip_too_small'.tr())), findsOneWidget);
    expect(find.descendant(of: recent, matching: find.text('gamification.skip_daily_limit'.tr())), findsOneWidget);
    expect(find.descendant(of: recent, matching: find.text('gamification.xp_none'.tr())), findsNWidgets(2));
  });

  testWidgets('the info button opens the XP rules', (tester) async {
    await pump(tester, () async => _summary);
    await tester.tap(find.byKey(const Key('level_rules_button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('level_rules_sheet')), findsOneWidget);
    expect(find.text('gamification.rules_minimum'.tr()), findsOneWidget);
  });
```

Run: `flutter test --no-pub -j 1 test/features/gamification/presentation/level_screen_test.dart`
Expected: FAIL — neden metni ve `level_rules_button` yok.

- [ ] **Step 3: Ekranı değiştir**

`level_screen.dart`:
1. Import ekle: `import '../domain/fair_play.dart';`
2. `SectionHeader('gamification.breakdown_title'.tr()),` satırını şununla değiştir:

```dart
                Row(
                  children: [
                    Expanded(child: SectionHeader('gamification.breakdown_title'.tr())),
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: IconButton(
                        key: const Key('level_rules_button'),
                        tooltip: 'gamification.rules_title'.tr(),
                        icon: const Icon(Icons.info_outline),
                        onPressed: () => showModalBottomSheet<void>(
                          context: context,
                          showDragHandle: true,
                          isScrollControlled: true,
                          builder: (_) => const _RulesSheet(),
                        ),
                      ),
                    ),
                  ],
                ),
```

3. `_Recent` içinde kazanç hapını XP'ye göre ayır — `trailing` `Column`'unun ilk çocuğu olan `Container`'ı şununla değiştir:

```dart
                    if (event.xp == 0)
                      Text(
                        'gamification.xp_none'.tr(),
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                          fontWeight: FontWeight.w800,
                        ),
                      )
                    else
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
```

4. `_detail`'in antrenman dalını değiştir:

```dart
        XpSource.workout => switch (event.skip) {
            SkipReason.tooSmall => 'gamification.skip_too_small'.tr(),
            SkipReason.dailyLimit => 'gamification.skip_daily_limit'.tr(),
            null => 'gamification.workout_sets'.tr(namedArgs: {'n': '${event.sets}'}),
          },
```

5. Dosyanın sonuna widget ekle:

```dart
/// XP kaynakları ve makullük kuralları (O3a spec §4).
class _RulesSheet extends StatelessWidget {
  const _RulesSheet();

  static const _rules = [
    'rules_workout',
    'rules_minimum',
    'rules_daily',
    'rules_sets',
    'rules_records',
    'rules_meals',
    'rules_challenges',
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: SingleChildScrollView(
        key: const Key('level_rules_sheet'),
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('gamification.rules_title'.tr(), style: theme.textTheme.titleLarge),
            const SizedBox(height: 12),
            for (final rule in _rules)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('•  '),
                    Expanded(child: Text('gamification.$rule'.tr())),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Testlerin geçtiğini gör**

Run: `flutter test --no-pub -j 1 test/features/gamification/presentation/level_screen_test.dart`
Expected: PASS (mevcutlar + 2 yeni).

- [ ] **Step 5: Analiz**

Run: `flutter analyze lib test`
Expected: `No issues found!`

- [ ] **Step 6: Commit**

```bash
git add lib/features/gamification/presentation/level_screen.dart assets/translations/tr.json assets/translations/en.json test/features/gamification/presentation/level_screen_test.dart
git commit -m "feat(xp): show why a workout earned no XP and explain the XP rules"
```

---

### Task 5: Doğrulama, PLAN.md ve elle kontrol (kullanıcıyla)

**Files:**
- Modify: `PLAN.md`

- [ ] **Step 1: Tüm testler**

Kullanıcıdan kendi terminalinde: `flutter test -j 1`. Beklenen: hepsi geçer. Başarısız test varsa: yeni kurallardan beklenen bir değişiklik mi (az setli fikstür) yoksa hata mı, birlikte incele; fikstürü kurala uygun hâle getir ya da kodu düzelt, ek commit at.

- [ ] **Step 2: Elle kontrol (web release, kullanıcının terminalinde `flutter build web --release` + sunucu)**

1. Seviye ekranı açılır; toplam XP yeniden hesaplanmış (eskisinden düşük olabilir).
2. 2 setlik kısa bir antrenman bitir → son kazanımlarda "0 XP · En az 3 set ve 10 dakika gerekir".
3. Aynı gün üçüncü uygun antrenman → "0 XP · Günlük 2 antrenman sınırı".
4. Döküm başlığındaki bilgi düğmesi → XP kuralları sayfası, yedi madde, tr/en.
5. 360 px genişlikte taşma yok.

- [ ] **Step 3: PLAN.md satırı**

Tablonun sonuna (N1 satırından sonra) ekle:

```markdown
| 2026-10-17 | **O3a (XP makullük kuralları) tamamlandı** (`o3a-xp-kurallari` dalı, 5 görev). Tek saf modül `fair_play.dart` her bitmiş oturuma karar verir: en az 3 set + 10 dk, günde en çok 2 sayılan antrenman, her 2 dakikaya 1 set (en çok 30), tahmini 1RM ya da kilo 500 kg üstü set yok sayılır. Rekor: en az %2,5 artış, %50 üstü sıçrama XP'siz taban olur, hareket başına 7 günde 1, oturum başına en çok 3 (en büyük artışlar); sayılmayan oturum tabanı yükseltir ama rekor XP'si vermez. Kurallar tüm geçmişe uygulanır; meydan okumaların antrenman/set/hacim değerleri ve dönem kas sıralaması da aynı süzgeçten geçer; öğün XP'si, unvanlar ve arkadaşlara açık haftalık özet değişmez. Seviye ekranında 0 XP'lik antrenman nedeniyle görünür, döküm başlığında "XP kuralları" sayfası. Migration yok. Otomatik: <N> Flutter testi (kullanıcının terminalinde `-j 1`), `flutter analyze` temiz. Manuel: web release'te 5 maddelik kontrol sorunsuz. Sıradaki: O4 (seri + haftalık görevler). |
```

`<N>` yerine Step 1'deki test sayısını yaz.

- [ ] **Step 4: Commit**

```bash
git add PLAN.md
git commit -m "docs: record O3a in the plan"
```

- [ ] **Step 5: Dalı bitir**

superpowers:finishing-a-development-branch ile kullanıcıya birleştirme seçeneğini sor. Not: `n2-sosyal-push` dalı henüz birleşmedi; O3a master'dan ayrıldı, ikisi aynı dosyalara dokunmuyor (çeviri dosyalarında farklı bölümler).
