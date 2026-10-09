# K3 Kas Haritası: Isı Haritası ve Programdan Haritaya — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Kas haritası ekranına son 7/30 günün setlerini gösteren ISI modu ve program detayına programın kaslarını gösteren mini harita kartı eklemek; kart, haritayı program modunda açar.

**Architecture:** Saf domain (`muscle_heat.dart`) set sayılarını kaslara dağıtır ve haftalık yükü 5 kademeye çevirir. İki `FutureProvider.family` mevcut `sessionHistoryProvider` / `programDetailProvider` ve `exercisesProvider` verisini birleştirir; yeni sorgu yok. `MuscleMap` isteğe bağlı `heat` haritası alır ve `onSelected` verilmezse dokunuş yakalamaz; ekran mod/dönem durumunu kendi `State`'inde tutar.

**Tech Stack:** Flutter, flutter_riverpod 3, go_router, easy_localization, flutter_test.

**Spec:** `docs/superpowers/specs/2026-10-09-k3-kas-haritasi-design.md`

## Global Constraints

- Dal: `f5p-kas-haritasi-k3`. Migration / deploy yok.
- Görevlerde yalnızca ilgili test dosyaları çalıştırılır: `flutter test --no-pub -j 1 <dosya>`. Tam paketi kullanıcı kendi terminalinde çalıştırır (Task 6).
- `flutter analyze --no-pub` birkaç dakika sürer; arka planda çalıştır. Sonuç "No issues found!" olmalı.
- `dart format` çalıştırılmaz. Mevcut biçime elle uyulur; satırlar en çok ~120 karakter.
- Testlerde çeviriler yüklenmez; `.tr()` ham anahtarı döndürür. Metinler `Key` ya da ham anahtarla doğrulanır; sayılar domain testlerinde doğrulanır.
- Ağırlıklar: birincil kas 1, ikincil kas 0,5. Kademe sınırları (haftalık set): 0 → none, (0, 4) → low, [4, 10) → medium, [10, 20) → optimal, ≥ 20 → high. Haftalık çevirme `load × 7 / days`; program yükü olduğu gibi.
- Isı opaklıkları (`primary` üzerine): low 0.25, medium 0.45, optimal 0.7, high 1.0.
- Kas adları `muscleGroups`'taki 17 değerden biridir; `lower back` ve `middle back` boşlukludur.
- Mevcut test anahtarlarının hepsi korunur.
- Yeni anahtarlar: `muscle_map_mode_toggle`, `muscle_map_mode_explore`, `muscle_map_mode_heat`, `muscle_heat_period_toggle`, `muscle_heat_period_7`, `muscle_heat_period_30`, `muscle_heat_legend`, `muscle_heat_empty`, `muscle_heat_summary`, `muscle_heat_row_<exerciseId>`, `muscle_heat_muscle_empty`, `muscle_heat_program_muscle_empty`, `muscle_heat_retry`, `muscle_map_program_name`, `program_muscle_map_card`.
- Profil okuyan widget'ların testleri `profileProvider`'ı override eder (yoksa Supabase'e gider).
- Bash aracı her komutta `commit-graph` uyarıları basıyor; zararsız, yok sayılır.
- Commit mesajları şu satırla biter: `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`

## Spec'ten bilinçli sapmalar (kullanıcıya bildirilecek)

1. **`ExerciseLoad.sets` `int`:** Spec `double sets` diyordu; satırdaki değer ham set sayısı olduğu için `int` yapıldı. Ağırlıklı toplam (başlık) yine `double`.
2. **Mini kart programı doğrudan kullanır:** Program detayı zaten `Program`'ı yüklediği için kart `programHeatProvider` yerine `programMuscleLoad(program, exercisesById)` çağırır; aynı sonuç, ikinci istek yok.
3. **`formatSets` domain'de:** Başlıktaki "tam sayıysa ondalıksız, değilse bir ondalık" biçimi `muscle_heat.dart`'ta saf fonksiyon olarak test edilir.

## Dosya yapısı

| Dosya | Görev |
|---|---|
| `lib/features/workout/domain/muscle_heat.dart` (yeni) | `HeatTier`, `heatTierFor`, `muscleWeight`, `MuscleLoad`, `historyMuscleLoad`, `programMuscleLoad`, `heatTiers`, `ExerciseLoad`, `historyLoadsForMuscle`, `programLoadsForMuscle`, `formatSets` |
| `lib/features/workout/application/muscle_heat_providers.dart` (yeni) | `exercisesByIdProvider`, `historyHeatProvider(days)`, `programHeatProvider(id)` |
| `lib/features/workout/presentation/widgets/muscle_map.dart` | `MuscleMap(heat, onSelected?)`, `heatColor`, `HeatLegend`, `MiniMuscleMapCard` |
| `lib/features/workout/presentation/muscle_map_screen.dart` | Mod geçişi, dönem, program modu, ısı listeleri |
| `lib/features/workout/presentation/program_detail_screen.dart` | Mini kart |
| `lib/core/router.dart` | `?program=` → `MuscleMapScreen(programId:)` |
| `assets/translations/tr.json`, `en.json` | 14 yeni anahtar (`workout.muscle_map.*`) |
| `test/features/workout/heat_fixtures.dart` (yeni) | Ortak test verisi |
| `test/features/workout/domain/muscle_heat_test.dart` (yeni) | Domain |
| `test/features/workout/application/muscle_heat_providers_test.dart` (yeni) | Sağlayıcılar |
| `test/features/workout/presentation/muscle_map_widget_test.dart`, `muscle_map_screen_test.dart`, `program_detail_screen_test.dart` | Yeni davranışlar |

---

### Task 1: Isı domain'i

**Files:**
- Create: `lib/features/workout/domain/muscle_heat.dart`
- Create: `test/features/workout/heat_fixtures.dart`
- Test: `test/features/workout/domain/muscle_heat_test.dart`

**Interfaces:**
- Produces (sonraki görevler kullanır):
  - `enum HeatTier { none, low, medium, optimal, high }`
  - `HeatTier heatTierFor(double weeklySets)`
  - `double muscleWeight(Exercise exercise, String muscle)`
  - `typedef MuscleLoad = Map<String, double>`
  - `MuscleLoad historyMuscleLoad(List<WorkoutSession> sessions, Map<String, Exercise> exercisesById, DateTime since)`
  - `MuscleLoad programMuscleLoad(Program program, Map<String, Exercise> exercisesById)`
  - `Map<String, HeatTier> heatTiers(MuscleLoad load, {int? days})`
  - `typedef ExerciseLoad = ({Exercise exercise, int sets, bool primary})`
  - `List<ExerciseLoad> historyLoadsForMuscle(List<WorkoutSession> sessions, Map<String, Exercise> exercisesById, DateTime since, String muscle)`
  - `List<ExerciseLoad> programLoadsForMuscle(Program program, Map<String, Exercise> exercisesById, String muscle)`
  - `String formatSets(double sets)`
  - Test yardımcıları (`heat_fixtures.dart`): `heatNow`, `heatBench`, `heatPushups`, `heatDips`, `heatSquat`, `heatExercises`, `heatExercisesById`, `heatSet(...)`, `heatSession(...)`, `heatSessions`, `heatProgram`

- [ ] **Step 1: Ortak test verisini yaz**

`test/features/workout/heat_fixtures.dart`:

```dart
import 'package:spor_takip/features/workout/domain/exercise.dart';
import 'package:spor_takip/features/workout/domain/program.dart';
import 'package:spor_takip/features/workout/domain/program_workout.dart';
import 'package:spor_takip/features/workout/domain/schedule_mode.dart';
import 'package:spor_takip/features/workout/domain/workout_exercise.dart';
import 'package:spor_takip/features/workout/domain/workout_session.dart';

/// Isı testlerinin "şimdi"si.
final heatNow = DateTime(2026, 10, 9, 12);

const heatBench = Exercise(
  id: 'bench',
  name: 'Barbell Bench Press',
  equipment: 'barbell',
  primaryMuscles: ['chest'],
  secondaryMuscles: ['triceps'],
);
const heatPushups = Exercise(id: 'pushups', name: 'Pushups', equipment: 'body only', primaryMuscles: ['chest']);
const heatDips = Exercise(id: 'dips', name: 'Dips', primaryMuscles: ['triceps'], secondaryMuscles: ['chest']);
const heatSquat = Exercise(id: 'squat', name: 'Squat', primaryMuscles: ['quadriceps']);
const heatExercises = [heatBench, heatPushups, heatDips, heatSquat];
final heatExercisesById = {for (final e in heatExercises) e.id: e};

SessionSet heatSet(String exerciseId, int index, {bool done = true}) => SessionSet(
      exercisePosition: 0,
      setIndex: index,
      exerciseId: exerciseId,
      exerciseName: exerciseId,
      targetRepsMin: 5,
      targetRepsMax: 5,
      completedAt: done ? DateTime(2026, 10, 1) : null,
    );

WorkoutSession heatSession(String id, DateTime? finishedAt, List<SessionSet> sets) => WorkoutSession(
      id: id,
      programName: 'P',
      workoutName: 'A',
      workoutPosition: 0,
      startedAt: (finishedAt ?? heatNow).subtract(const Duration(hours: 1)),
      finishedAt: finishedAt,
      sets: sets,
    );

/// 2 gün önce: bench 3 tamam + 1 yarım, pushups 2, silinmiş hareket 1.
/// 20 gün önce: squat 4. Devam eden oturum: bench 5 (sayılmaz).
final heatSessions = [
  heatSession('recent', heatNow.subtract(const Duration(days: 2)), [
    heatSet('bench', 0),
    heatSet('bench', 1),
    heatSet('bench', 2),
    heatSet('bench', 3, done: false),
    heatSet('pushups', 0),
    heatSet('pushups', 1),
    heatSet('deleted', 0),
  ]),
  heatSession('old', heatNow.subtract(const Duration(days: 20)), [
    for (var i = 0; i < 4; i++) heatSet('squat', i),
  ]),
  heatSession('live', null, [for (var i = 0; i < 5; i++) heatSet('bench', i)]),
];

WorkoutExercise _block(Exercise e, int sets) =>
    WorkoutExercise(exerciseId: e.id, exerciseName: e.name, sets: sets, repsMin: 5, repsMax: 5);

/// A: bench 5 + squat 5, B: dips 3 + squat 0 (katkısız).
final heatProgram = Program(
  id: 'prog',
  name: '5x5',
  scheduleMode: ScheduleMode.rotation,
  workouts: [
    ProgramWorkout(name: 'A', exercises: [_block(heatBench, 5), _block(heatSquat, 5)]),
    ProgramWorkout(name: 'B', exercises: [_block(heatDips, 3), _block(heatSquat, 0)]),
  ],
);
```

- [ ] **Step 2: Başarısız domain testlerini yaz**

`test/features/workout/domain/muscle_heat_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:spor_takip/features/workout/domain/muscle_heat.dart';

import '../heat_fixtures.dart';

void main() {
  final since7 = heatNow.subtract(const Duration(days: 7));
  final since30 = heatNow.subtract(const Duration(days: 30));

  test('heatTierFor cuts at 4, 10 and 20 sets a week', () {
    expect(heatTierFor(0), HeatTier.none);
    expect(heatTierFor(0.5), HeatTier.low);
    expect(heatTierFor(3.9), HeatTier.low);
    expect(heatTierFor(4), HeatTier.medium);
    expect(heatTierFor(9.9), HeatTier.medium);
    expect(heatTierFor(10), HeatTier.optimal);
    expect(heatTierFor(19.9), HeatTier.optimal);
    expect(heatTierFor(20), HeatTier.high);
  });

  test('muscleWeight is 1 for primary, 0.5 for secondary, else 0', () {
    expect(muscleWeight(heatBench, 'chest'), 1);
    expect(muscleWeight(heatBench, 'triceps'), 0.5);
    expect(muscleWeight(heatBench, 'quadriceps'), 0);
  });

  test('history load counts completed sets of finished sessions since the cut', () {
    // bench 3 (yarım set ve devam eden oturum sayılmaz), pushups 2; squat 20 gün önce.
    expect(historyMuscleLoad(heatSessions, heatExercisesById, since7), {'chest': 5.0, 'triceps': 1.5});
    expect(
      historyMuscleLoad(heatSessions, heatExercisesById, since30),
      {'chest': 5.0, 'triceps': 1.5, 'quadriceps': 4.0},
    );
  });

  test('program load sums planned sets of every workout', () {
    // bench 5 → chest 5, triceps 2.5; squat 5 + 0; dips 3 → triceps 3, chest 1.5.
    expect(
      programMuscleLoad(heatProgram, heatExercisesById),
      {'chest': 6.5, 'triceps': 5.5, 'quadriceps': 5.0},
    );
  });

  test('heatTiers scales to a week and drops empty muscles', () {
    final load = {'chest': 5.0, 'triceps': 1.5, 'quadriceps': 30.0, 'calves': 0.0};
    expect(heatTiers(load, days: 7), {
      'chest': HeatTier.medium,
      'triceps': HeatTier.low,
      'quadriceps': HeatTier.high,
    });
    // 30 gün → × 7/30: chest 1.17 low, quadriceps 7 medium.
    expect(heatTiers(load, days: 30), {
      'chest': HeatTier.low,
      'triceps': HeatTier.low,
      'quadriceps': HeatTier.medium,
    });
    // Program: ölçeksiz.
    expect(heatTiers({'chest': 12.0}), {'chest': HeatTier.optimal});
  });

  test('history loads for a muscle list raw set counts, most first, with the primary flag', () {
    final rows = historyLoadsForMuscle(heatSessions, heatExercisesById, since7, 'chest');
    expect([for (final r in rows) (r.exercise.id, r.sets, r.primary)], [('bench', 3, true), ('pushups', 2, true)]);

    final triceps = historyLoadsForMuscle(heatSessions, heatExercisesById, since7, 'triceps');
    expect([for (final r in triceps) (r.exercise.id, r.sets, r.primary)], [('bench', 3, false)]);

    expect(historyLoadsForMuscle(heatSessions, heatExercisesById, since7, 'quadriceps'), isEmpty);
  });

  test('program loads for a muscle use planned sets', () {
    final rows = programLoadsForMuscle(heatProgram, heatExercisesById, 'triceps');
    // bench 5 (ikincil), dips 3 (birincil).
    expect([for (final r in rows) (r.exercise.id, r.sets, r.primary)], [('bench', 5, false), ('dips', 3, true)]);

    // squat iki günde 5 + 0 → 5.
    final quads = programLoadsForMuscle(heatProgram, heatExercisesById, 'quadriceps');
    expect([for (final r in quads) (r.exercise.id, r.sets)], [('squat', 5)]);
  });

  test('equal set counts sort by exercise name', () {
    final sessions = [
      heatSession('s', heatNow, [heatSet('pushups', 0), heatSet('bench', 0)]),
    ];
    final rows = historyLoadsForMuscle(sessions, heatExercisesById, heatNow.subtract(const Duration(days: 1)), 'chest');
    expect([for (final r in rows) r.exercise.id], ['bench', 'pushups']); // "Barbell…" < "Pushups"
  });

  test('formatSets drops a zero decimal', () {
    expect(formatSets(5), '5');
    expect(formatSets(1.5), '1.5');
    expect(formatSets(6.25), '6.3');
  });
}
```

- [ ] **Step 3: Testin başarısız olduğunu gör**

Run: `flutter test --no-pub -j 1 test/features/workout/domain/muscle_heat_test.dart`
Expected: FAIL — `muscle_heat.dart` bulunamıyor.

- [ ] **Step 4: Domain'i yaz**

`lib/features/workout/domain/muscle_heat.dart`:

```dart
import 'exercise.dart';
import 'program.dart';
import 'workout_session.dart';

/// Haftalık set yüküne göre ısı kademesi (K3 spec §3).
enum HeatTier { none, low, medium, optimal, high }

HeatTier heatTierFor(double weeklySets) {
  if (weeklySets <= 0) return HeatTier.none;
  if (weeklySets < 4) return HeatTier.low;
  if (weeklySets < 10) return HeatTier.medium;
  if (weeklySets < 20) return HeatTier.optimal;
  return HeatTier.high;
}

/// Bir hareketin bir kasa katkısı: birincilse 1, ikincilse 0,5, değilse 0.
double muscleWeight(Exercise exercise, String muscle) {
  if (exercise.primaryMuscles.contains(muscle)) return 1;
  if (exercise.secondaryMuscles.contains(muscle)) return 0.5;
  return 0;
}

/// Kas başına ağırlıklı set yükü.
typedef MuscleLoad = Map<String, double>;

/// Bir kas için hareket başına ham set sayısı; [primary] kas birincilse true.
typedef ExerciseLoad = ({Exercise exercise, int sets, bool primary});

/// Hareket → [since]'ten sonra biten oturumlardaki tamamlanmış set sayısı.
Map<String, int> _historySetCounts(List<WorkoutSession> sessions, DateTime since) {
  final counts = <String, int>{};
  for (final session in sessions) {
    final finished = session.finishedAt;
    if (finished == null || finished.isBefore(since)) continue;
    for (final set in session.sets) {
      if (set.isCompleted) counts[set.exerciseId] = (counts[set.exerciseId] ?? 0) + 1;
    }
  }
  return counts;
}

/// Hareket → programın tüm günlerindeki planlı set sayısı.
Map<String, int> _programSetCounts(Program program) {
  final counts = <String, int>{};
  for (final workout in program.workouts) {
    for (final e in workout.exercises) {
      if (e.sets > 0) counts[e.exerciseId] = (counts[e.exerciseId] ?? 0) + e.sets;
    }
  }
  return counts;
}

MuscleLoad _loadFrom(Map<String, int> counts, Map<String, Exercise> exercisesById) {
  final load = <String, double>{};
  for (final MapEntry(key: id, value: sets) in counts.entries) {
    final exercise = exercisesById[id];
    if (exercise == null) continue;
    for (final muscle in {...exercise.primaryMuscles, ...exercise.secondaryMuscles}) {
      load[muscle] = (load[muscle] ?? 0) + sets * muscleWeight(exercise, muscle);
    }
  }
  return load;
}

List<ExerciseLoad> _loadsForMuscle(Map<String, int> counts, Map<String, Exercise> exercisesById, String muscle) {
  final rows = <ExerciseLoad>[
    for (final MapEntry(key: id, value: sets) in counts.entries)
      if (exercisesById[id] case final exercise? when muscleWeight(exercise, muscle) > 0)
        (exercise: exercise, sets: sets, primary: exercise.primaryMuscles.contains(muscle)),
  ];
  rows.sort((a, b) {
    final bySets = b.sets.compareTo(a.sets);
    return bySets != 0 ? bySets : a.exercise.name.compareTo(b.exercise.name);
  });
  return rows;
}

/// Bitmiş oturumlardan, `finishedAt >= since` olanların tamamlanmış setleri.
/// Hareketi [exercisesById]'de olmayan setler atlanır.
MuscleLoad historyMuscleLoad(List<WorkoutSession> sessions, Map<String, Exercise> exercisesById, DateTime since) =>
    _loadFrom(_historySetCounts(sessions, since), exercisesById);

/// Programdaki tüm günlerin planlı setleri, aynı ağırlıklarla.
MuscleLoad programMuscleLoad(Program program, Map<String, Exercise> exercisesById) =>
    _loadFrom(_programSetCounts(program), exercisesById);

/// Yükü haftalığa çevirip kademeye eşler; `none` olanlar dışarıda kalır.
/// [days] null → yük olduğu gibi (program bir döngü).
Map<String, HeatTier> heatTiers(MuscleLoad load, {int? days}) {
  final perWeek = days == null ? 1.0 : 7 / days;
  return {
    for (final MapEntry(key: muscle, value: sets) in load.entries)
      if (heatTierFor(sets * perWeek) case final tier when tier != HeatTier.none) muscle: tier,
  };
}

List<ExerciseLoad> historyLoadsForMuscle(
  List<WorkoutSession> sessions,
  Map<String, Exercise> exercisesById,
  DateTime since,
  String muscle,
) =>
    _loadsForMuscle(_historySetCounts(sessions, since), exercisesById, muscle);

List<ExerciseLoad> programLoadsForMuscle(Program program, Map<String, Exercise> exercisesById, String muscle) =>
    _loadsForMuscle(_programSetCounts(program), exercisesById, muscle);

/// 5.0 → "5", 1.5 → "1.5".
String formatSets(double sets) =>
    sets == sets.roundToDouble() ? sets.toInt().toString() : sets.toStringAsFixed(1);
```

- [ ] **Step 5: Testlerin geçtiğini gör**

Run: `flutter test --no-pub -j 1 test/features/workout/domain/muscle_heat_test.dart`
Expected: PASS (9 test).

- [ ] **Step 6: Commit**

```bash
git add lib/features/workout/domain/muscle_heat.dart test/features/workout/heat_fixtures.dart test/features/workout/domain/muscle_heat_test.dart
git commit -m "feat(workout): spread finished and planned sets over muscles as heat tiers

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 2: Isı sağlayıcıları

**Files:**
- Create: `lib/features/workout/application/muscle_heat_providers.dart`
- Test: `test/features/workout/application/muscle_heat_providers_test.dart`

**Interfaces:**
- Consumes: Task 1 (`MuscleLoad`, `historyMuscleLoad`, `programMuscleLoad`); mevcut `exercisesProvider`, `programDetailProvider` (`workout_providers.dart`), `sessionHistoryProvider`, `nowProvider` (`session_providers.dart`).
- Produces:
  - `typedef HistoryHeat = ({List<WorkoutSession> sessions, Map<String, Exercise> exercisesById, MuscleLoad load, DateTime since})`
  - `typedef ProgramHeat = ({Program program, Map<String, Exercise> exercisesById, MuscleLoad load})`
  - `final exercisesByIdProvider` — `FutureProvider.autoDispose<Map<String, Exercise>>`
  - `final historyHeatProvider` — `FutureProvider.autoDispose.family<HistoryHeat, int>` (argüman: gün)
  - `final programHeatProvider` — `FutureProvider.autoDispose.family<ProgramHeat, String>` (argüman: program id)

- [ ] **Step 1: Başarısız testleri yaz**

`test/features/workout/application/muscle_heat_providers_test.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spor_takip/features/onboarding/application/auth_providers.dart';
import 'package:spor_takip/features/workout/application/muscle_heat_providers.dart';
import 'package:spor_takip/features/workout/application/session_providers.dart';
import 'package:spor_takip/features/workout/application/workout_providers.dart';

import '../fakes.dart';
import '../heat_fixtures.dart';

ProviderContainer _container() {
  final container = ProviderContainer(overrides: [
    isLoggedInProvider.overrideWithValue(true),
    nowProvider.overrideWithValue(() => heatNow),
    sessionRepositoryProvider.overrideWithValue(FakeSessionRepository(sessions: heatSessions)),
    exerciseRepositoryProvider.overrideWithValue(FakeExerciseRepository(heatExercises)),
    programRepositoryProvider.overrideWithValue(FakeProgramRepository(programs: [heatProgram])),
  ]);
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('history heat counts the last N days from now', () async {
    final container = _container();
    container.listen(historyHeatProvider(7), (_, _) {});
    container.listen(historyHeatProvider(30), (_, _) {});

    final week = await container.read(historyHeatProvider(7).future);
    expect(week.load, {'chest': 5.0, 'triceps': 1.5});
    expect(week.since, heatNow.subtract(const Duration(days: 7)));
    expect(week.exercisesById.keys, containsAll(['bench', 'squat']));

    final month = await container.read(historyHeatProvider(30).future);
    expect(month.load['quadriceps'], 4.0);
  });

  test('program heat sums the planned sets', () async {
    final container = _container();
    container.listen(programHeatProvider('prog'), (_, _) {});

    final heat = await container.read(programHeatProvider('prog').future);
    expect(heat.program.name, '5x5');
    expect(heat.load, {'chest': 6.5, 'triceps': 5.5, 'quadriceps': 5.0});
  });

  test('exercises are indexed by id', () async {
    final container = _container();
    container.listen(exercisesByIdProvider, (_, _) {});

    final byId = await container.read(exercisesByIdProvider.future);
    expect(byId['dips']?.name, 'Dips');
  });
}
```

- [ ] **Step 2: Testin başarısız olduğunu gör**

Run: `flutter test --no-pub -j 1 test/features/workout/application/muscle_heat_providers_test.dart`
Expected: FAIL — `muscle_heat_providers.dart` bulunamıyor.

- [ ] **Step 3: Sağlayıcıları yaz**

`lib/features/workout/application/muscle_heat_providers.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/exercise.dart';
import '../domain/muscle_heat.dart';
import '../domain/program.dart';
import '../domain/workout_session.dart';
import 'session_providers.dart';
import 'workout_providers.dart';

typedef HistoryHeat = ({
  List<WorkoutSession> sessions,
  Map<String, Exercise> exercisesById,
  MuscleLoad load,
  DateTime since,
});

typedef ProgramHeat = ({Program program, Map<String, Exercise> exercisesById, MuscleLoad load});

final exercisesByIdProvider = FutureProvider.autoDispose<Map<String, Exercise>>((ref) async {
  final all = await ref.watch(exercisesProvider.future);
  return {for (final e in all) e.id: e};
});

/// Son [days] günde biten oturumların set yükü. Kaynak: son 100 bitmiş oturum (K3 spec §2.5).
final historyHeatProvider = FutureProvider.autoDispose.family<HistoryHeat, int>((ref, days) async {
  final sessions = await ref.watch(sessionHistoryProvider.future);
  final exercisesById = await ref.watch(exercisesByIdProvider.future);
  final since = ref.read(nowProvider)().subtract(Duration(days: days));
  return (
    sessions: sessions,
    exercisesById: exercisesById,
    load: historyMuscleLoad(sessions, exercisesById, since),
    since: since,
  );
});

/// Programın planlı set yükü.
final programHeatProvider = FutureProvider.autoDispose.family<ProgramHeat, String>((ref, programId) async {
  final program = await ref.watch(programDetailProvider(programId).future);
  final exercisesById = await ref.watch(exercisesByIdProvider.future);
  return (program: program, exercisesById: exercisesById, load: programMuscleLoad(program, exercisesById));
});
```

- [ ] **Step 4: Testlerin geçtiğini gör**

Run: `flutter test --no-pub -j 1 test/features/workout/application/muscle_heat_providers_test.dart`
Expected: PASS (3 test).

- [ ] **Step 5: Commit**

```bash
git add lib/features/workout/application/muscle_heat_providers.dart test/features/workout/application/muscle_heat_providers_test.dart
git commit -m "feat(workout): provide history and program muscle heat

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 3: Harita widget'ı — ısı boyama, dokunmasız harita, lejant, mini kart, çeviriler

**Files:**
- Modify: `lib/features/workout/presentation/widgets/muscle_map.dart` (`MuscleMap`, `_MuscleMapPainter`; dosya sonuna yeni sınıflar)
- Modify: `assets/translations/tr.json`, `assets/translations/en.json` (`workout.muscle_map` bloğu)
- Test: `test/features/workout/presentation/muscle_map_widget_test.dart`

**Interfaces:**
- Consumes: Task 1 `HeatTier`.
- Produces:
  - `MuscleMap({key, required BodyView view, BodyFigure figure = BodyFigure.male, String? selected, ValueChanged<String>? onSelected, Map<String, HeatTier> heat = const {}})` — `onSelected == null` → `GestureDetector` yok; anahtar `muscle_map_<view>` her iki durumda da var.
  - `Color? heatColor(Color accent, HeatTier tier)` — `none` → null; low/medium/optimal/high → accent 0.25/0.45/0.7/1.0.
  - `class HeatLegend extends StatelessWidget` — `const HeatLegend({super.key})`; içteki `Row` anahtarı `muscle_heat_legend`.
  - `class MiniMuscleMapCard extends StatelessWidget` — `const MiniMuscleMapCard({super.key, required BodyFigure figure, required Map<String, HeatTier> heat, required VoidCallback onTap})`.
  - Çeviri anahtarları (`workout.muscle_map.`): `mode_explore`, `mode_heat`, `period_days`, `legend_low`, `legend_high`, `heat_summary`, `heat_summary_program`, `heat_empty`, `heat_muscle_empty`, `heat_program_muscle_empty`, `heat_row_sets`, `primary`, `secondary`, `program_card_title`.

- [ ] **Step 1: Başarısız testleri yaz**

`test/features/workout/presentation/muscle_map_widget_test.dart` dosyasının importlarına ekle:

```dart
import 'package:spor_takip/features/workout/domain/muscle_heat.dart';
```

ve `main()` içinde, son testten sonra ekle:

```dart
  testWidgets('without onSelected the map lets taps reach its parent', (tester) async {
    var taps = 0;
    await tester.pumpWidget(testApp(
      Scaffold(
        body: Center(
          child: InkWell(
            onTap: () => taps++,
            child: const SizedBox(width: 300, height: 500, child: MuscleMap(view: BodyView.front)),
          ),
        ),
      ),
      scaffold: false,
    ));
    await tester.pumpAndSettle();
    await tester.tapAt(screenPointFor(tester, find.byKey(const Key('muscle_map_front')), BodyView.front, 'chest'));
    expect(taps, 1);
  });

  testWidgets('a heat map paints without errors', (tester) async {
    await tester.pumpWidget(testApp(
      const Scaffold(
        body: SizedBox(
          width: 300,
          height: 500,
          child: MuscleMap(view: BodyView.front, heat: {'chest': HeatTier.high, 'abdominals': HeatTier.low}),
        ),
      ),
      scaffold: false,
    ));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(tester.widget<MuscleMap>(find.byType(MuscleMap)).heat['chest'], HeatTier.high);
  });

  test('heatColor fades the accent by tier', () {
    const accent = Color(0xFFC6FF00);
    expect(heatColor(accent, HeatTier.none), isNull);
    expect(heatColor(accent, HeatTier.low)!.a, closeTo(0.25, 0.01));
    expect(heatColor(accent, HeatTier.medium)!.a, closeTo(0.45, 0.01));
    expect(heatColor(accent, HeatTier.optimal)!.a, closeTo(0.7, 0.01));
    expect(heatColor(accent, HeatTier.high), accent);
  });

  testWidgets('the legend shows four swatches between low and high', (tester) async {
    await tester.pumpWidget(testApp(const HeatLegend()));
    await tester.pumpAndSettle();
    final legend = find.byKey(const Key('muscle_heat_legend'));
    expect(legend, findsOneWidget);
    expect(find.descendant(of: legend, matching: find.text('workout.muscle_map.legend_low')), findsOneWidget);
    expect(find.descendant(of: legend, matching: find.text('workout.muscle_map.legend_high')), findsOneWidget);
    expect(find.descendant(of: legend, matching: find.byType(DecoratedBox)), findsNWidgets(4));
  });

  testWidgets('the mini card shows both views and reports a tap anywhere', (tester) async {
    var taps = 0;
    await tester.pumpWidget(testApp(
      MiniMuscleMapCard(figure: BodyFigure.female, heat: const {'chest': HeatTier.medium}, onTap: () => taps++),
    ));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('muscle_map_front')), findsOneWidget);
    expect(find.byKey(const Key('muscle_map_back')), findsOneWidget);
    expect(find.byKey(const Key('muscle_heat_legend')), findsOneWidget);
    expect(find.textContaining('PROGRAM_CARD_T'), findsOneWidget);

    await tester.tap(find.byKey(const Key('muscle_map_front')));
    expect(taps, 1);
  });
```

Not: Testte çeviri yüklenmediği için başlık ham anahtarın büyük harfli halidir. Türkçede `upperCaseFor` `i` → `İ` yaptığından (`…_TİTLE`) yalnızca `PROGRAM_CARD_T` öneki aranır.

- [ ] **Step 2: Testin başarısız olduğunu gör**

Run: `flutter test --no-pub -j 1 test/features/workout/presentation/muscle_map_widget_test.dart`
Expected: FAIL — `heat`, `heatColor`, `HeatLegend`, `MiniMuscleMapCard` tanımlı değil; `onSelected` zorunlu.

- [ ] **Step 3: `MuscleMap`'i güncelle**

`lib/features/workout/presentation/widgets/muscle_map.dart` importlarını şöyle yap:

```dart
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_fonts.dart';
import '../../../../shared/text_case.dart';
import '../../domain/muscle_heat.dart';
import '../../domain/muscle_map.dart';
```

`MuscleMap` sınıfını (satır 15–63) şununla değiştir:

```dart
/// Ön ya da arka vücut figürü; kasa dokununca [onSelected] (null → dokunuş üst widget'a geçer).
/// [heat] verilirse kaslar kademeye göre vurgu rengiyle tonlanır. Sınırlı boyut ister.
class MuscleMap extends StatelessWidget {
  const MuscleMap({
    super.key,
    required this.view,
    this.figure = BodyFigure.male,
    this.selected,
    this.onSelected,
    this.heat = const {},
  });

  final BodyView view;
  final BodyFigure figure;
  final String? selected;
  final ValueChanged<String>? onSelected;
  final Map<String, HeatTier> heat;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final _MapColors colors = (
      silhouette: scheme.surfaceContainerLowest,
      outline: scheme.onSurfaceVariant.withValues(alpha: 0.6),
      decor: scheme.onSurfaceVariant.withValues(alpha: 0.25),
      muscle: scheme.onSurfaceVariant.withValues(alpha: 0.5),
      selected: scheme.primary,
      edge: theme.scaffoldBackgroundColor,
    );
    final onSelected = this.onSelected;
    return Semantics(
      label: 'workout.muscle_map.title'.tr(),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = constraints.biggest;
          final paint = CustomPaint(
            size: size,
            painter: _MuscleMapPainter(figure: figure, view: view, selected: selected, heat: heat, colors: colors),
          );
          final key = Key('muscle_map_${view.name}');
          if (onSelected == null) return KeyedSubtree(key: key, child: paint);
          return GestureDetector(
            key: key,
            behavior: HitTestBehavior.opaque,
            onTapUp: (details) {
              final muscle = muscleAt(figure, view, BodyFit(size, figure).toCanvas(details.localPosition));
              if (muscle != null) onSelected(muscle);
            },
            child: paint,
          );
        },
      ),
    );
  }
}

const _heatAlpha = {HeatTier.low: 0.25, HeatTier.medium: 0.45, HeatTier.optimal: 0.7, HeatTier.high: 1.0};

/// Kademenin dolgu rengi; `none` → null (kas gri kalır).
Color? heatColor(Color accent, HeatTier tier) {
  final alpha = _heatAlpha[tier];
  if (alpha == null) return null;
  return alpha == 1.0 ? accent : accent.withValues(alpha: alpha);
}
```

`_MuscleMapPainter` sınıfında kurucu, alanlar, dolgu satırı ve `shouldRepaint`'i güncelle:

```dart
class _MuscleMapPainter extends CustomPainter {
  _MuscleMapPainter({
    required this.figure,
    required this.view,
    required this.selected,
    required this.heat,
    required this.colors,
  });

  final BodyFigure figure;
  final BodyView view;
  final String? selected;
  final Map<String, HeatTier> heat;
  final _MapColors colors;
```

`paint` içindeki dolgu satırını

```dart
      final fill = isSelected ? colors.selected : (muscle == null ? colors.decor : colors.muscle);
```

şununla değiştir:

```dart
      final fill = isSelected
          ? colors.selected
          : muscle == null
              ? colors.decor
              : heatColor(colors.selected, heat[muscle] ?? HeatTier.none) ?? colors.muscle;
```

ve `shouldRepaint`'i:

```dart
  @override
  bool shouldRepaint(_MuscleMapPainter old) =>
      old.figure != figure ||
      old.view != view ||
      old.selected != selected ||
      old.colors != colors ||
      !mapEquals(old.heat, heat);
```

- [ ] **Step 4: `HeatLegend` ve `MiniMuscleMapCard`'ı ekle**

Aynı dosyanın sonuna (`_DotGridPainter`'dan sonra) ekle:

```dart
/// Az → Çok arası dört ton karesi.
class HeatLegend extends StatelessWidget {
  const HeatLegend({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final style = theme.textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant);
    return Row(
      key: const Key('muscle_heat_legend'),
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('workout.muscle_map.legend_low'.tr(), style: style),
        const SizedBox(width: 6),
        for (final tier in const [HeatTier.low, HeatTier.medium, HeatTier.optimal, HeatTier.high])
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: heatColor(scheme.primary, tier),
                borderRadius: const BorderRadius.all(Radius.circular(3)),
              ),
              child: const SizedBox(width: 12, height: 12),
            ),
          ),
        const SizedBox(width: 6),
        Text('workout.muscle_map.legend_high'.tr(), style: style),
      ],
    );
  }
}

/// Program detayındaki "Çalışan kaslar" kartı: ön ve arka figür yan yana, ısı tonlarıyla.
/// Figürler dokunuş yakalamaz; kartın tamamı [onTap].
class MiniMuscleMapCard extends StatelessWidget {
  const MiniMuscleMapCard({super.key, required this.figure, required this.heat, required this.onTap});

  final BodyFigure figure;
  final Map<String, HeatTier> heat;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final heading = theme.textTheme.titleSmall?.copyWith(fontFamily: AppFonts.heading, fontWeight: FontWeight.w800);
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      upperCaseFor('workout.muscle_map.program_card_title'.tr(), context.locale.languageCode),
                      style: heading,
                    ),
                  ),
                  Icon(Icons.chevron_right, color: theme.colorScheme.onSurfaceVariant),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 180,
                child: Row(
                  children: [
                    Expanded(child: MuscleMap(view: BodyView.front, figure: figure, heat: heat)),
                    const SizedBox(width: 12),
                    Expanded(child: MuscleMap(view: BodyView.back, figure: figure, heat: heat)),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const Align(alignment: Alignment.centerRight, child: HeatLegend()),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 5: Çevirileri ekle**

`assets/translations/tr.json` içinde `workout.muscle_map` bloğunda `"figure_female": "Kadın figürü"` satırını şununla değiştir:

```json
      "figure_female": "Kadın figürü",
      "mode_explore": "KEŞFET",
      "mode_heat": "ISI",
      "period_days": "{n} GÜN",
      "legend_low": "Az",
      "legend_high": "Çok",
      "heat_summary": "{sets} set · son {n} gün",
      "heat_summary_program": "{sets} set · program",
      "heat_empty": "Son {n} günde biten antrenman yok",
      "heat_muscle_empty": "Bu kası son {n} günde çalıştırmadın",
      "heat_program_muscle_empty": "Bu program bu kası çalıştırmıyor",
      "heat_row_sets": "{n} set",
      "primary": "Birincil",
      "secondary": "İkincil",
      "program_card_title": "Çalışan kaslar"
```

`assets/translations/en.json` içinde `"figure_female": "Female figure"` satırını şununla değiştir:

```json
      "figure_female": "Female figure",
      "mode_explore": "EXPLORE",
      "mode_heat": "HEAT",
      "period_days": "{n} DAYS",
      "legend_low": "Low",
      "legend_high": "High",
      "heat_summary": "{sets} sets · last {n} days",
      "heat_summary_program": "{sets} sets · program",
      "heat_empty": "No finished workouts in the last {n} days",
      "heat_muscle_empty": "You haven't trained this muscle in the last {n} days",
      "heat_program_muscle_empty": "This program doesn't train this muscle",
      "heat_row_sets": "{n} sets",
      "primary": "Primary",
      "secondary": "Secondary",
      "program_card_title": "Muscles worked"
```

- [ ] **Step 6: Testlerin geçtiğini gör**

Run: `flutter test --no-pub -j 1 test/features/workout/presentation/muscle_map_widget_test.dart test/features/workout/presentation/muscle_map_screen_test.dart`
Expected: PASS (mevcut testler + 5 yeni). Ekran testleri değişmeden geçmeli (ekran `onSelected` veriyor).

- [ ] **Step 7: Commit**

```bash
git add lib/features/workout/presentation/widgets/muscle_map.dart assets/translations/tr.json assets/translations/en.json test/features/workout/presentation/muscle_map_widget_test.dart
git commit -m "feat(workout): tint the muscle map by heat and add the legend and mini map card

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 4: Kas haritası ekranı — ISI modu, dönem, program modu, rota

**Files:**
- Modify: `lib/features/workout/presentation/muscle_map_screen.dart` (tamamı)
- Modify: `lib/core/router.dart:113`
- Test: `test/features/workout/presentation/muscle_map_screen_test.dart`

**Interfaces:**
- Consumes: Task 1 (`HeatTier`, `MuscleLoad`, `heatTiers`, `ExerciseLoad`, `historyLoadsForMuscle`, `programLoadsForMuscle`, `formatSets`), Task 2 (`historyHeatProvider`, `programHeatProvider`), Task 3 (`MuscleMap(heat:)`, `HeatLegend`); mevcut `sessionHistoryProvider`, `programDetailProvider`, `exercisesProvider`.
- Produces: `MuscleMapScreen({Key? key, String? programId})`; rota `/workout/muscles?program=<id>`.

- [ ] **Step 1: Başarısız testleri yaz**

`test/features/workout/presentation/muscle_map_screen_test.dart` importlarına ekle:

```dart
import 'package:spor_takip/features/workout/application/session_providers.dart';
import 'package:spor_takip/features/workout/domain/muscle_heat.dart';
import 'package:spor_takip/features/workout/domain/program.dart';
import 'package:spor_takip/features/workout/domain/workout_session.dart';

import '../fakes.dart';
import '../heat_fixtures.dart';
```

`pumpScreen`'i şununla değiştir (yeni parametreler: `sessions`, `programId`, `programs`):

```dart
  Future<void> pumpScreen(
    WidgetTester tester, {
    Future<List<Exercise>> Function()? load,
    Profile? profile = testProfile,
    List<WorkoutSession> sessions = const [],
    String? programId,
    List<Program> programs = const [],
  }) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(testApp(
      MuscleMapScreen(programId: programId),
      scaffold: false,
      overrides: [
        exercisesProvider.overrideWith((ref) => (load ?? () async => _all)()),
        profileProvider.overrideWith((ref) async => profile),
        nowProvider.overrideWithValue(() => heatNow),
        sessionRepositoryProvider.overrideWithValue(FakeSessionRepository(sessions: sessions)),
        programRepositoryProvider.overrideWithValue(FakeProgramRepository(programs: programs)),
      ],
    ));
    await tester.pumpAndSettle();
  }

  Future<void> tapKey(WidgetTester tester, String key) async {
    await tester.tap(find.byKey(Key(key)));
    await tester.pumpAndSettle();
  }
```

`main()` sonuna ekle:

```dart
  testWidgets('opens in explore mode; heat mode shows the period and legend and hides the secondary chip',
      (tester) async {
    await pumpScreen(tester, sessions: heatSessions);
    expect(find.byKey(const Key('muscle_map_mode_toggle')), findsOneWidget);
    expect(find.byKey(const Key('muscle_heat_legend')), findsNothing);
    expect(tester.widget<MuscleMap>(find.byType(MuscleMap)).heat, isEmpty);

    await tapKey(tester, 'muscle_map_mode_heat');
    expect(find.byKey(const Key('muscle_heat_period_7')), findsOneWidget);
    expect(find.byKey(const Key('muscle_heat_legend')), findsOneWidget);
    expect(tester.widget<MuscleMap>(find.byType(MuscleMap)).heat, {'chest': HeatTier.medium, 'triceps': HeatTier.low});

    await tapMuscle(tester, BodyView.front, 'chest');
    expect(find.byKey(const Key('muscle_map_secondary_chip')), findsNothing);
    expect(find.byKey(const Key('muscle_heat_summary')), findsOneWidget);
  });

  testWidgets('heat mode lists the exercises done for a muscle with their set counts', (tester) async {
    await pumpScreen(tester, sessions: heatSessions);
    await tapKey(tester, 'muscle_map_mode_heat');
    await tapMuscle(tester, BodyView.front, 'chest');

    expect(find.byKey(const Key('muscle_heat_row_bench')), findsOneWidget);
    expect(find.byKey(const Key('muscle_heat_row_pushups')), findsOneWidget);
    expect(find.byKey(const Key('muscle_map_exercise_bench')), findsNothing);
    final bench = find.byKey(const Key('muscle_heat_row_bench'));
    expect(find.descendant(of: bench, matching: find.text('workout.muscle_map.primary')), findsOneWidget);
    expect(find.descendant(of: bench, matching: find.text('workout.muscle_map.heat_row_sets')), findsOneWidget);
  });

  testWidgets('30 days reaches older sessions', (tester) async {
    await pumpScreen(tester, sessions: heatSessions);
    await tapKey(tester, 'muscle_map_mode_heat');
    await tapMuscle(tester, BodyView.front, 'quadriceps');
    expect(find.byKey(const Key('muscle_heat_muscle_empty')), findsOneWidget);

    await tapKey(tester, 'muscle_heat_period_30');
    expect(find.byKey(const Key('muscle_heat_row_squat')), findsOneWidget);
    expect(tester.widget<MuscleMap>(find.byType(MuscleMap)).heat['quadriceps'], HeatTier.low);
  });

  testWidgets('heat mode without finished workouts says so', (tester) async {
    await pumpScreen(tester);
    await tapKey(tester, 'muscle_map_mode_heat');
    expect(find.byKey(const Key('muscle_heat_empty')), findsOneWidget);
    expect(find.byKey(const Key('muscle_map_hint')), findsNothing);
  });

  testWidgets('switching modes keeps the chosen muscle', (tester) async {
    await pumpScreen(tester, sessions: heatSessions);
    await tapMuscle(tester, BodyView.front, 'chest');
    await tapKey(tester, 'muscle_map_mode_heat');
    expect(find.byKey(const Key('muscle_heat_row_bench')), findsOneWidget);

    await tapKey(tester, 'muscle_map_mode_explore');
    expect(find.byKey(const Key('muscle_map_exercise_bench')), findsOneWidget);
  });

  testWidgets('program mode shows the program heat and its exercises for a muscle', (tester) async {
    await pumpScreen(tester, programId: 'prog', programs: [heatProgram]);
    expect(find.byKey(const Key('muscle_map_program_name')), findsOneWidget);
    expect(find.text('5x5'), findsOneWidget);
    expect(find.byKey(const Key('muscle_map_mode_toggle')), findsNothing);
    expect(find.byKey(const Key('muscle_heat_period_7')), findsNothing);
    expect(find.byKey(const Key('muscle_heat_legend')), findsOneWidget);
    expect(tester.widget<MuscleMap>(find.byType(MuscleMap)).heat['chest'], HeatTier.medium);

    await tapMuscle(tester, BodyView.front, 'chest');
    expect(find.byKey(const Key('muscle_heat_row_bench')), findsOneWidget);
    expect(find.byKey(const Key('muscle_heat_row_dips')), findsOneWidget);
    final dips = find.byKey(const Key('muscle_heat_row_dips'));
    expect(find.descendant(of: dips, matching: find.text('workout.muscle_map.secondary')), findsOneWidget);

    await tapMuscle(tester, BodyView.front, 'abdominals');
    expect(find.byKey(const Key('muscle_heat_program_muscle_empty')), findsOneWidget);
  });
```

Not: `heatProgram`'da chest = bench 5 + dips 1.5 = 6.5 → medium.

- [ ] **Step 2: Testin başarısız olduğunu gör**

Run: `flutter test --no-pub -j 1 test/features/workout/presentation/muscle_map_screen_test.dart`
Expected: FAIL — `MuscleMapScreen` `programId` almıyor.

- [ ] **Step 3: Ekranı yaz**

`lib/features/workout/presentation/muscle_map_screen.dart` dosyasının tamamını şununla değiştir:

```dart
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/text_case.dart';
import '../../../shared/widgets/accent_chip.dart';
import '../application/muscle_heat_providers.dart';
import '../application/muscle_map_providers.dart';
import '../application/session_providers.dart';
import '../application/workout_providers.dart';
import '../domain/exercise.dart';
import '../domain/exercise_filter.dart';
import '../domain/exercise_taxonomy.dart';
import '../domain/muscle_heat.dart';
import '../domain/muscle_map.dart';
import 'widgets/exercise_detail_sheet.dart';
import 'widgets/exercise_icon_badge.dart';
import 'widgets/muscle_map.dart';

/// Kas haritası: kasa dokun → o kası çalıştıran hareketler (yalnız göz atma).
/// ISI modunda son 7/30 günün setleri, [programId] verilirse programın planlı setleri tonlanır (K3 spec §5.2).
class MuscleMapScreen extends ConsumerStatefulWidget {
  const MuscleMapScreen({super.key, this.programId});

  final String? programId;

  @override
  ConsumerState<MuscleMapScreen> createState() => _MuscleMapScreenState();
}

class _MuscleMapScreenState extends ConsumerState<MuscleMapScreen> {
  BodyView _view = BodyView.front;
  String? _muscle;
  bool _includeSecondary = false;
  bool _heatMode = false;
  int _days = 7;

  bool get _showsHeat => widget.programId != null || _heatMode;

  /// Haritada gösterilecek yük; ısı kapalıyken, yüklenirken ya da hatada null.
  MuscleLoad? _load() {
    final programId = widget.programId;
    if (programId != null) return ref.watch(programHeatProvider(programId)).value?.load;
    if (_heatMode) return ref.watch(historyHeatProvider(_days)).value?.load;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final muscle = _muscle;
    final programId = widget.programId;
    final figure = ref.watch(mapFigureProvider);
    final lang = context.locale.languageCode;
    final muted = TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant);
    final load = _load();
    final heat = load == null ? const <String, HeatTier>{} : heatTiers(load, days: programId == null ? _days : null);
    final programName = programId == null ? null : ref.watch(programDetailProvider(programId)).value?.name;
    final noWorkouts = programId == null && _heatMode && load != null && load.isEmpty;
    return Scaffold(
      key: const Key('muscle_map_screen'),
      appBar: AppBar(
        title: Text(
          upperCaseFor('workout.muscle_map.title'.tr(), lang),
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
        ),
      ),
      body: CustomScrollView(
        slivers: [
          if (programName != null)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
              sliver: SliverToBoxAdapter(
                child: Text(programName, key: const Key('muscle_map_program_name'), style: muted),
              ),
            ),
          if (programId == null)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              sliver: SliverToBoxAdapter(child: _modeToggle()),
            ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            sliver: SliverToBoxAdapter(
              child: MuscleMapControls(
                view: _view,
                onViewChanged: (v) => setState(() => _view = v),
                figure: figure,
                onFigureChanged: (f) => ref.read(mapFigureChoiceProvider.notifier).choose(f),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverToBoxAdapter(
              child: SizedBox(
                height: MediaQuery.sizeOf(context).height * 0.45,
                child: MuscleMapCard(
                  child: MuscleMap(
                    view: _view,
                    figure: figure,
                    selected: muscle,
                    heat: heat,
                    onSelected: (m) => setState(() => _muscle = m),
                  ),
                ),
              ),
            ),
          ),
          if (_showsHeat)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              sliver: SliverToBoxAdapter(child: _heatBar()),
            ),
          if (muscle == null)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  noWorkouts
                      ? 'workout.muscle_map.heat_empty'.tr(namedArgs: {'n': '$_days'})
                      : 'workout.muscle_map.hint'.tr(),
                  key: Key(noWorkouts ? 'muscle_heat_empty' : 'muscle_map_hint'),
                  textAlign: TextAlign.center,
                  style: muted,
                ),
              ),
            )
          else if (_showsHeat)
            ..._heatResults(context, muscle)
          else
            ..._results(context, muscle),
        ],
      ),
    );
  }

  Widget _modeToggle() {
    return SegmentedButton<bool>(
      key: const Key('muscle_map_mode_toggle'),
      showSelectedIcon: false,
      expandedInsets: EdgeInsets.zero,
      segments: [
        ButtonSegment(
          value: false,
          label: Text('workout.muscle_map.mode_explore'.tr(), key: const Key('muscle_map_mode_explore')),
        ),
        ButtonSegment(
          value: true,
          label: Text('workout.muscle_map.mode_heat'.tr(), key: const Key('muscle_map_mode_heat')),
        ),
      ],
      selected: {_heatMode},
      onSelectionChanged: (selection) => setState(() => _heatMode = selection.first),
    );
  }

  /// Solda 7/30 GÜN (program modunda yok), sağda lejant.
  Widget _heatBar() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        if (widget.programId == null)
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: SegmentedButton<int>(
                key: const Key('muscle_heat_period_toggle'),
                showSelectedIcon: false,
                segments: [
                  for (final days in const [7, 30])
                    ButtonSegment(
                      value: days,
                      label: Text(
                        'workout.muscle_map.period_days'.tr(namedArgs: {'n': '$days'}),
                        key: Key('muscle_heat_period_$days'),
                      ),
                    ),
                ],
                selected: {_days},
                onSelectionChanged: (selection) => setState(() => _days = selection.first),
              ),
            ),
          )
        else
          const SizedBox.shrink(),
        const SizedBox(width: 12),
        const HeatLegend(),
      ],
    );
  }

  static const _loading = [
    SliverToBoxAdapter(
      child: Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator())),
    ),
  ];

  List<Widget> _retry(Key key, VoidCallback onPressed) {
    return [
      SliverToBoxAdapter(
        child: Center(
          child: TextButton(key: key, onPressed: onPressed, child: Text('workout.picker_load_error'.tr())),
        ),
      ),
    ];
  }

  List<Widget> _results(BuildContext context, String muscle) {
    return ref.watch(exercisesProvider).when(
          loading: () => _loading,
          error: (error, stackTrace) =>
              _retry(const Key('muscle_map_retry'), () => ref.invalidate(exercisesProvider)),
          data: (all) {
            final list = exercisesForMuscle(all, muscle, includeSecondary: _includeSecondary);
            return [
              SliverToBoxAdapter(
                child: _header(
                  context,
                  muscle,
                  infoKey: const Key('muscle_map_count'),
                  info: 'workout.muscle_map.count'.tr(namedArgs: {'n': '${list.length}'}),
                  trailing: AccentChip(
                    key: const Key('muscle_map_secondary_chip'),
                    label: 'workout.muscle_map.include_secondary'.tr(),
                    selected: _includeSecondary,
                    onSelected: (on) => setState(() => _includeSecondary = on),
                  ),
                ),
              ),
              if (list.isEmpty)
                _emptySliver(context, const Key('muscle_map_empty'), 'workout.muscle_map.empty'.tr())
              else
                _listCard(context, list.length, (index) => _row(context, list[index])),
            ];
          },
        );
  }

  List<Widget> _heatResults(BuildContext context, String muscle) {
    final programId = widget.programId;
    if (programId != null) {
      return ref.watch(programHeatProvider(programId)).when(
            loading: () => _loading,
            error: (error, stackTrace) => _retry(const Key('muscle_heat_retry'), () {
              ref.invalidate(programDetailProvider(programId));
              ref.invalidate(exercisesProvider);
            }),
            data: (heat) => _heatList(
              context,
              muscle,
              summary: 'workout.muscle_map.heat_summary_program'.tr(
                namedArgs: {'sets': formatSets(heat.load[muscle] ?? 0)},
              ),
              rows: programLoadsForMuscle(heat.program, heat.exercisesById, muscle),
              emptyKey: const Key('muscle_heat_program_muscle_empty'),
              emptyText: 'workout.muscle_map.heat_program_muscle_empty'.tr(),
            ),
          );
    }
    return ref.watch(historyHeatProvider(_days)).when(
          loading: () => _loading,
          error: (error, stackTrace) => _retry(const Key('muscle_heat_retry'), () {
            ref.invalidate(sessionHistoryProvider);
            ref.invalidate(exercisesProvider);
          }),
          data: (heat) => _heatList(
            context,
            muscle,
            summary: 'workout.muscle_map.heat_summary'.tr(
              namedArgs: {'sets': formatSets(heat.load[muscle] ?? 0), 'n': '$_days'},
            ),
            rows: historyLoadsForMuscle(heat.sessions, heat.exercisesById, heat.since, muscle),
            emptyKey: const Key('muscle_heat_muscle_empty'),
            emptyText: 'workout.muscle_map.heat_muscle_empty'.tr(namedArgs: {'n': '$_days'}),
          ),
        );
  }

  List<Widget> _heatList(
    BuildContext context,
    String muscle, {
    required String summary,
    required List<ExerciseLoad> rows,
    required Key emptyKey,
    required String emptyText,
  }) {
    return [
      SliverToBoxAdapter(child: _header(context, muscle, infoKey: const Key('muscle_heat_summary'), info: summary)),
      if (rows.isEmpty)
        _emptySliver(context, emptyKey, emptyText)
      else
        _listCard(context, rows.length, (index) => _heatRow(context, rows[index])),
    ];
  }

  Widget _emptySliver(BuildContext context, Key key, String text) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          text,
          key: key,
          textAlign: TextAlign.center,
          style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      ),
    );
  }

  Widget _listCard(BuildContext context, int count, Widget Function(int index) row) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      sliver: DecoratedSliver(
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color,
          borderRadius: const BorderRadius.all(Radius.circular(16)),
        ),
        sliver: SliverList.separated(
          itemCount: count,
          separatorBuilder: (context, index) => const Divider(height: 1, indent: 72, endIndent: 16),
          itemBuilder: (context, index) => row(index),
        ),
      ),
    );
  }

  Widget _header(BuildContext context, String muscle, {required Key infoKey, required String info, Widget? trailing}) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Wrap(
              spacing: 12,
              crossAxisAlignment: WrapCrossAlignment.end,
              children: [
                Text(
                  upperCaseFor(muscleLabelKey(muscle).tr(), context.locale.languageCode),
                  key: const Key('muscle_map_selected'),
                  style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Text(info, key: infoKey, style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
                ),
              ],
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 8), trailing],
        ],
      ),
    );
  }

  Widget _row(BuildContext context, Exercise e) {
    final subtitle = [
      if (e.equipment case final equipment?) equipmentLabelKey(equipment).tr(),
      if (_levelKey(e.level) case final level?) level.tr(),
      if (e.isCustom) 'workout.custom_exercise_badge'.tr(),
    ].join(' · ');
    return ListTile(
      key: Key('muscle_map_exercise_${e.id}'),
      leading: ExerciseIconBadge(equipment: e.equipment),
      title: Text(e.name),
      subtitle: subtitle.isEmpty ? null : Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => showExerciseDetailSheet(context, e, selectable: false),
    );
  }

  Widget _heatRow(BuildContext context, ExerciseLoad load) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      key: Key('muscle_heat_row_${load.exercise.id}'),
      leading: ExerciseIconBadge(equipment: load.exercise.equipment),
      title: Text(load.exercise.name),
      subtitle: Text((load.primary ? 'workout.muscle_map.primary' : 'workout.muscle_map.secondary').tr()),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: scheme.primary.withValues(alpha: 0.12),
          borderRadius: const BorderRadius.all(Radius.circular(999)),
          border: Border.all(color: scheme.primary),
        ),
        child: Text(
          'workout.muscle_map.heat_row_sets'.tr(namedArgs: {'n': '${load.sets}'}),
          style: Theme.of(context).textTheme.labelLarge?.copyWith(color: scheme.primary),
        ),
      ),
      onTap: () => showExerciseDetailSheet(context, load.exercise, selectable: false),
    );
  }
}

String? _levelKey(String? level) => switch (level) {
      'beginner' => 'workout.level_beginner',
      'intermediate' => 'workout.level_intermediate',
      'expert' => 'workout.level_advanced',
      _ => null,
    };
```

`_levelKey` mevcut dosyanın sonundakiyle aynıdır (taşınır, değişmez).

- [ ] **Step 4: Rotayı güncelle**

`lib/core/router.dart:113` satırını:

```dart
                  GoRoute(path: 'muscles', builder: (context, state) => const MuscleMapScreen()),
```

şununla değiştir:

```dart
                  GoRoute(
                    path: 'muscles',
                    builder: (context, state) => MuscleMapScreen(programId: state.uri.queryParameters['program']),
                  ),
```

- [ ] **Step 5: Testlerin geçtiğini gör**

Run: `flutter test --no-pub -j 1 test/features/workout/presentation/muscle_map_screen_test.dart test/features/workout/presentation/programs_screen_test.dart`
Expected: PASS (mevcut 8 + 6 yeni ekran testi; programlar ekranı testi değişmeden).

- [ ] **Step 6: Commit**

```bash
git add lib/features/workout/presentation/muscle_map_screen.dart lib/core/router.dart test/features/workout/presentation/muscle_map_screen_test.dart
git commit -m "feat(workout): add the heat mode and the program mode to the muscle map screen

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 5: Program detayında "Çalışan kaslar" kartı

**Files:**
- Modify: `lib/features/workout/presentation/program_detail_screen.dart`
- Test: `test/features/workout/presentation/program_detail_screen_test.dart`

**Interfaces:**
- Consumes: Task 1 (`programMuscleLoad`, `heatTiers`), Task 2 (`exercisesByIdProvider`), Task 3 (`MiniMuscleMapCard`); mevcut `mapFigureProvider`.
- Produces: Program detayında `program_muscle_map_card` → `context.push('/workout/muscles?program=<id>')`.

- [ ] **Step 1: Başarısız testleri yaz**

`test/features/workout/presentation/program_detail_screen_test.dart` importlarına ekle:

```dart
import 'package:spor_takip/features/onboarding/application/profile_providers.dart';
import 'package:spor_takip/features/workout/domain/exercise.dart';

import '../../progress/fixtures.dart';
```

`late FakeSessionRepository sessionRepo;` satırından sonra ekle:

```dart
  late List<Exercise> exercises;
```

`wrap` içindeki `/workout` rotasının `routes` listesine (`program/:id` rotasından sonra) ekle:

```dart
          GoRoute(
            path: 'muscles',
            builder: (context, state) => Text('MUSCLES_${state.uri.queryParameters['program']}'),
          ),
```

`ProviderScope` overrides'ında `exerciseRepositoryProvider.overrideWithValue(FakeExerciseRepository()),` satırını şununla değiştir:

```dart
          exerciseRepositoryProvider.overrideWithValue(FakeExerciseRepository(exercises)),
          profileProvider.overrideWith((ref) async => testProfile),
```

`setUp` içine ekle:

```dart
    exercises = [];
```

`main()` sonuna ekle:

```dart
  testWidgets('shows the muscles worked card, which opens the map in program mode', (tester) async {
    exercises = [const Exercise(id: 'Barbell_Squat', name: 'Barbell Squat', primaryMuscles: ['quadriceps'])];
    await open(tester, 'mine');

    final card = find.byKey(const Key('program_muscle_map_card'));
    expect(card, findsOneWidget);
    await tester.ensureVisible(card);
    await tester.tap(card);
    await tester.pumpAndSettle();
    expect(find.text('MUSCLES_mine'), findsOneWidget);
  });

  testWidgets('hides the card when no exercise maps to a muscle', (tester) async {
    exercises = [const Exercise(id: 'Barbell_Squat', name: 'Barbell Squat')];
    await open(tester, 'mine');
    expect(find.byKey(const Key('program_muscle_map_card')), findsNothing);
  });
```

- [ ] **Step 2: Testin başarısız olduğunu gör**

Run: `flutter test --no-pub -j 1 test/features/workout/presentation/program_detail_screen_test.dart`
Expected: İlk yeni test FAIL (`program_muscle_map_card` yok); diğerleri PASS.

- [ ] **Step 3: Kartı ekle**

`lib/features/workout/presentation/program_detail_screen.dart` importlarına ekle:

```dart
import '../application/muscle_heat_providers.dart';
import '../application/muscle_map_providers.dart';
import '../domain/muscle_heat.dart';
import 'widgets/muscle_map.dart';
```

`ListView` çocuklarında butonları saran `Wrap(...)`'ın kapanışından hemen sonra, `if (program.workouts.isEmpty)` satırından önce ekle:

```dart
              _ProgramMuscleMap(program: program),
```

Dosyanın sonuna ekle:

```dart
/// "Çalışan kaslar" kartı; hareketler yüklenmediyse ya da hiçbiri bir kasa eşlenmiyorsa gizli (K3 spec §5.3).
class _ProgramMuscleMap extends ConsumerWidget {
  const _ProgramMuscleMap({required this.program});

  final Program program;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final exercisesById = ref.watch(exercisesByIdProvider).value;
    if (exercisesById == null) return const SizedBox.shrink();
    final load = programMuscleLoad(program, exercisesById);
    if (load.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: MiniMuscleMapCard(
        key: const Key('program_muscle_map_card'),
        figure: ref.watch(mapFigureProvider),
        heat: heatTiers(load),
        onTap: () => context.push('/workout/muscles?program=${program.id}'),
      ),
    );
  }
}
```

- [ ] **Step 4: Testlerin geçtiğini gör**

Run: `flutter test --no-pub -j 1 test/features/workout/presentation/program_detail_screen_test.dart`
Expected: PASS (mevcut + 2 yeni).

- [ ] **Step 5: Analiz**

Run: `flutter analyze --no-pub` (arka planda)
Expected: `No issues found!`

- [ ] **Step 6: Commit**

```bash
git add lib/features/workout/presentation/program_detail_screen.dart test/features/workout/presentation/program_detail_screen_test.dart
git commit -m "feat(workout): show the muscles a program works on its detail screen

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 6: Doğrulama ve kayıt

**Files:**
- Modify: `PLAN.md`

- [ ] **Step 1: Statik analiz**

Run: `flutter analyze --no-pub` (arka planda)
Expected: `No issues found!`

- [ ] **Step 2: Kullanıcıdan tam test paketi**

Kullanıcı kendi terminalinde `flutter test --no-pub -j 1` çalıştırır.
Expected: Hepsi geçer. Beklenen sayı 519 + domain 9 + sağlayıcı 3 + widget 5 + ekran 6 + program detayı 2 = ~544. Kesin sayı kullanıcının çıktısından alınır.

- [ ] **Step 3: Kullanıcıdan web release derlemesi ve manuel kontrol**

Kullanıcı `flutter build web --release --no-pub` çalıştırır ve `build/web`'i kendi terminalinden sunar: `python -m http.server 5555 --bind 127.0.0.1`.

Kontrol listesi (spec §8):
1. KEŞFET modu K2'deki gibi çalışıyor.
2. ISI modunda son 7 günde çalışılan kaslar tonlanıyor; 30 GÜN'e geçince tonlar mantıklı biçimde değişiyor.
3. Isı modunda kasa dokununca set özeti ve yapılan hareketler set sayılarıyla listeleniyor.
4. Hiç antrenman olmayan dönemde boş mesajı çıkıyor.
5. Program detayında "ÇALIŞAN KASLAR" kartı görünüyor; ön/arka figür programın kaslarını tonluyor.
6. Karta dokununca harita program modunda açılıyor; kasa dokununca program hareketleri planlı set sayılarıyla listeleniyor.
7. ♂/♀ seçimi mini kartta ve program modunda da geçerli.
8. Yaklaşık 360 px genişlikte taşma yok.

- [ ] **Step 4: PLAN.md satırı ve commit**

`PLAN.md`'de K2 satırından sonra K3 satırı eklenir (tarih, dal, özet, sapmalar, test sayısı, manuel sonuç, sıradaki). Ardından:

```bash
git add PLAN.md
git commit -m "docs: record K3 muscle heat map in the plan

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

- [ ] **Step 5: Dalı bitir**

superpowers:finishing-a-development-branch; kullanıcı onayıyla `f5p-kas-haritasi-k3` → `master` fast-forward + push.
