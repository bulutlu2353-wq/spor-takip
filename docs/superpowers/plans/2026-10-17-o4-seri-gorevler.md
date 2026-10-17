# O4 Günlük Seri ve Haftalık Görevler — Uygulama Planı

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Günlük seriyi (dinlenme hakkıyla) ve haftada 3 belirlenimli görevi XP'ye bağlamak; ana sayfada hap, Seviye ekranında seri ve görev kartları göstermek.

**Architecture:** İki saf modül: `streak.dart` (gün gün seri, çarpan, güncel durum) ve `quests.dart` (havuz, FNV-1a tohumlu seçim, haftalık ilerleme). `xpEvents` isteğe bağlı `GameSettings` alır; verilirse antrenman XP'sine seri bonusu, kullanıcı id'si de varsa görev olayları ekler. Olaylar `xpEventsProvider`'da bir kez hesaplanır; özet, meydan okuma değeri ve dönem istatistiği bu listeyi paylaşır. Migration yok.

**Tech Stack:** Flutter, Riverpod 3, easy_localization, flutter_test.

**Spec:** `docs/superpowers/specs/2026-10-17-o4-seri-gorevler-design.md`

## Global Constraints

- Haftalık hedef `G`: program `effectiveDaysPerWeek` → profil `exerciseDaysPerWeek` → 3; `[2, 6]`'ya sıkıştırılır; dinlenme hakkı `7 − G` / ISO hafta (pazartesi, `startOfWeek`).
- Seri bonusu: her 7 günde %5, en çok %25; yalnız sayılan antrenmanın `50 + 5 × set` tabanına; tam sayı yüzdeyle (`base * percent ~/ 100`) — kayan nokta `floor` hatası olmasın diye spec'teki oran sabitleri yüzde olarak tutulur.
- Görev: 40 XP; üçü bitince +60 XP; tüm geçmiş haftalara; tohum `fnv1a32(userId + weekKey(weekStart))`.
- `settings == null` → bugünkü davranış (bonus yok, görev yok); `userId == null` → bonus var, görev yok.
- Rekor, öğün, görev ve meydan okuma XP'si çarpandan etkilenmez.
- Var olan CRLF dosyaları CRLF kalır; yeni Dart dosyaları da CRLF yazılır (dizindeki komşularla aynı). JSON çeviri dosyaları LF.
- Testler: `flutter test --no-pub -j 1 <dosya>`; analiz: `flutter analyze lib test` → `No issues found!`.
- Commit mesajları İngilizce, sonunda `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.

## Dosya haritası

| Dosya | Sorumluluk |
|---|---|
| `lib/features/gamification/domain/game_settings.dart` (yeni) | `GameSettings`, `weeklyGoalFor` |
| `lib/features/gamification/domain/streak.dart` (yeni) | seri günleri, çarpan, `StreakStatus` |
| `lib/features/gamification/domain/quests.dart` (yeni) | havuz, seçim, ilerleme, `WeekQuests` |
| `lib/features/gamification/domain/xp_rules.dart` | `XpSource.quest`, yeni alanlar, bonus + görev olayları, döküm |
| `lib/features/gamification/domain/player_summary.dart` | `streak`, `quests` |
| `lib/features/gamification/application/xp_event_providers.dart` (yeni) | `gameSettingsProvider`, `xpEventsProvider` |
| `lib/features/onboarding/application/auth_providers.dart` | `currentUserIdProvider` |
| `lib/features/gamification/application/gamification_providers.dart`, `lib/features/social/application/{challenge,social}_providers.dart`, `lib/features/social/domain/period_stats.dart` | paylaşılan olaylar |
| `lib/features/gamification/presentation/widgets/streak_quest_cards.dart` (yeni) | seri kartı, görev kartı, `questText` |
| `lib/features/gamification/presentation/widgets/home_streak_chip.dart` (yeni) | ana sayfa hapı |
| `lib/features/gamification/presentation/level_screen.dart` | kartlar, döküm, geçmiş, kurallar |
| `assets/translations/{tr,en}.json` | `gamification` anahtarları |

---

### Task 1: Haftalık hedef ve seri (`game_settings.dart`, `streak.dart`)

**Files:**
- Create: `lib/features/gamification/domain/game_settings.dart`
- Create: `lib/features/gamification/domain/streak.dart`
- Test: `test/features/gamification/domain/streak_test.dart`

**Interfaces:**
- Consumes: `SessionVerdict`, `judgeSessions` (`fair_play.dart`); `startOfWeek` (`lib/features/progress/domain/weekly_summary.dart`).
- Produces: `class GameSettings { int weeklyGoal; String? userId; }`, `defaultWeeklyGoal`, `minWeeklyGoal`, `maxWeeklyGoal`, `int weeklyGoalFor({int? programDays, int? profileDays})`; `streakBonusStepDays`, `streakBonusStepPercent`, `maxStreakBonusPercent`, `int streakBonusPercent(int length)`; `DateTime localDay(DateTime t)`; `enum StreakDayKind { workout, rest, pending, broken }`; `class StreakDay { DateTime day; StreakDayKind kind; int length; }`; `List<StreakDay> streakDays(List<SessionVerdict>, {required int weeklyGoal, required DateTime today})`; `Map<DateTime, int> workoutStreakLengths(List<SessionVerdict>, {required int weeklyGoal})`; `class StreakStatus { int length; int bonusPercent; int restLeft; bool broken; static const none; }`; `StreakStatus streakStatus(List<SessionVerdict>, {required int weeklyGoal, required DateTime today})`.

- [ ] **Step 1: Failing test yaz**

`test/features/gamification/domain/streak_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:spor_takip/features/gamification/domain/fair_play.dart';
import 'package:spor_takip/features/gamification/domain/game_settings.dart';
import 'package:spor_takip/features/gamification/domain/streak.dart';

import '../game_fixtures.dart';

/// Her gün 18:00'de 3 setlik (sayılan) antrenman.
List<SessionVerdict> _verdicts(List<DateTime> days) => judgeSessions([
      for (final (i, d) in days.indexed) gameSession('s$i', DateTime(d.year, d.month, d.day, 18), gameSets('bench', 3)),
    ]);

/// "w1 r2 b0 p0" biçimi.
String _kinds(List<StreakDay> days) => days.map((d) => '${d.kind.name[0]}${d.length}').join(' ');

void main() {
  group('weeklyGoalFor', () {
    test('prefers the program, then the profile, then 3', () {
      expect(weeklyGoalFor(programDays: 5, profileDays: 3), 5);
      expect(weeklyGoalFor(profileDays: 4), 4);
      expect(weeklyGoalFor(), 3);
    });

    test('clamps to 2..6', () {
      expect(weeklyGoalFor(programDays: 1), 2);
      expect(weeklyGoalFor(programDays: 7), 6);
    });
  });

  group('streakDays', () {
    // 5 Ekim 2026 pazartesi.
    test('workouts and rest days extend the streak; running out of rest breaks it', () {
      final days = streakDays(
        _verdicts([DateTime(2026, 10, 5), DateTime(2026, 10, 6), DateTime(2026, 10, 10)]),
        weeklyGoal: 5,
        today: DateTime(2026, 10, 11, 9),
      );
      expect(_kinds(days), 'w1 w2 r3 r4 b0 w1 p1');
      expect(days.first.day, DateTime(2026, 10, 5));
    });

    test('rest allowance renews every ISO week', () {
      final days = streakDays(
        _verdicts([DateTime(2026, 10, 10), DateTime(2026, 10, 12), DateTime(2026, 10, 14)]),
        weeklyGoal: 6,
        today: DateTime(2026, 10, 15, 9),
      );
      expect(_kinds(days), 'w1 r2 w3 r4 w5 p5');
    });

    test('days without a workout while the streak is 0 stay broken and use no rest', () {
      final days = streakDays(
        _verdicts([DateTime(2026, 10, 5), DateTime(2026, 10, 13)]),
        weeklyGoal: 5,
        today: DateTime(2026, 10, 17, 9),
      );
      expect(_kinds(days), 'w1 r2 r3 b0 b0 b0 b0 b0 w1 r2 r3 b0 p0');
    });

    test('ignores sessions that do not count and merges two workouts on one day', () {
      final verdicts = judgeSessions([
        gameSession('small', DateTime(2026, 10, 5, 9), gameSets('bench', 2)),
        gameSession('a', DateTime(2026, 10, 6, 9), gameSets('bench', 3)),
        gameSession('b', DateTime(2026, 10, 6, 19), gameSets('bench', 3)),
      ]);
      expect(_kinds(streakDays(verdicts, weeklyGoal: 3, today: DateTime(2026, 10, 6, 20))), 'w1');
    });

    test('no workouts → empty', () {
      expect(streakDays(const [], weeklyGoal: 3, today: DateTime(2026, 10, 6)), isEmpty);
    });
  });

  test('workoutStreakLengths maps each workout day to its streak length', () {
    final lengths = workoutStreakLengths(
      _verdicts([DateTime(2026, 10, 5), DateTime(2026, 10, 6), DateTime(2026, 10, 10)]),
      weeklyGoal: 5,
    );
    expect(lengths, {DateTime(2026, 10, 5): 1, DateTime(2026, 10, 6): 2, DateTime(2026, 10, 10): 1});
  });

  test('bonus percent steps by 5 every 7 days up to 25', () {
    expect([0, 6, 7, 13, 14, 35, 70].map(streakBonusPercent), [0, 0, 5, 5, 10, 25, 25]);
  });

  group('streakStatus', () {
    test('pending today shows yesterday and this week\'s rest left', () {
      final status = streakStatus(
        _verdicts([DateTime(2026, 10, 5), DateTime(2026, 10, 6), DateTime(2026, 10, 10)]),
        weeklyGoal: 5,
        today: DateTime(2026, 10, 11, 9),
      );
      expect((status.length, status.bonusPercent, status.restLeft, status.broken), (1, 0, 0, false));
    });

    test('a workout today counts today', () {
      final status = streakStatus(
        _verdicts([for (var d = 1; d <= 14; d++) DateTime(2026, 10, d)]),
        weeklyGoal: 4,
        today: DateTime(2026, 10, 14, 20),
      );
      expect((status.length, status.bonusPercent, status.restLeft, status.broken), (14, 10, 3, false));
    });

    test('broken yesterday → broken', () {
      final status = streakStatus(
        _verdicts([DateTime(2026, 10, 5), DateTime(2026, 10, 13)]),
        weeklyGoal: 5,
        today: DateTime(2026, 10, 17, 9),
      );
      expect((status.length, status.restLeft, status.broken), (0, 0, true));
    });

    test('no workouts → broken with the full rest allowance', () {
      final status = streakStatus(const [], weeklyGoal: 4, today: DateTime(2026, 10, 17));
      expect((status.length, status.restLeft, status.broken), (0, 3, true));
    });
  });
}
```

- [ ] **Step 2: Testin derlenmediğini doğrula**

Run: `flutter test --no-pub -j 1 test/features/gamification/domain/streak_test.dart`
Expected: FAIL — `game_settings.dart` / `streak.dart` yok.

- [ ] **Step 3: `game_settings.dart` yaz**

```dart
/// Seri ve görevlerin girdisi (O4 spec §5).
class GameSettings {
  const GameSettings({required this.weeklyGoal, this.userId});

  /// Haftalık antrenman hedefi; dinlenme hakkı `7 − weeklyGoal`.
  final int weeklyGoal;

  /// Görev tohumu; null → görev yok.
  final String? userId;
}

const defaultWeeklyGoal = 3;
const minWeeklyGoal = 2;
const maxWeeklyGoal = 6;

/// Program → profil → 3; `[2, 6]`'ya sıkıştırılır (O4 spec §3.1).
int weeklyGoalFor({int? programDays, int? profileDays}) =>
    (programDays ?? profileDays ?? defaultWeeklyGoal).clamp(minWeeklyGoal, maxWeeklyGoal);
```

- [ ] **Step 4: `streak.dart` yaz**

```dart
import 'dart:math' as math;

import '../../progress/domain/weekly_summary.dart';
import 'fair_play.dart';

/// Seri bonusu (O4 spec §3.3): her 7 günde %5, en çok %25. Yüzde tam sayı tutulur.
const streakBonusStepDays = 7;
const streakBonusStepPercent = 5;
const maxStreakBonusPercent = 25;

int streakBonusPercent(int length) =>
    math.min(maxStreakBonusPercent, length ~/ streakBonusStepDays * streakBonusStepPercent);

/// Yerel günün başı.
DateTime localDay(DateTime t) => DateTime(t.year, t.month, t.day);

enum StreakDayKind { workout, rest, pending, broken }

class StreakDay {
  const StreakDay(this.day, this.kind, this.length);

  /// Yerel günün başı.
  final DateTime day;
  final StreakDayKind kind;

  /// Günün sonundaki seri uzunluğu.
  final int length;
}

/// İlk antrenman gününden [today]'e gün gün (O4 spec §3.2); antrenman yoksa boş.
List<StreakDay> streakDays(List<SessionVerdict> verdicts, {required int weeklyGoal, required DateTime today}) {
  final workoutDays = {
    for (final v in verdicts)
      if (v.counted) localDay(v.finishedAt),
  };
  if (workoutDays.isEmpty) return const [];
  final last = localDay(today);
  final restPerWeek = 7 - weeklyGoal;
  final restUsed = <DateTime, int>{};
  final days = <StreakDay>[];
  var length = 0;
  for (var day = workoutDays.reduce((a, b) => a.isBefore(b) ? a : b);
      !day.isAfter(last);
      day = DateTime(day.year, day.month, day.day + 1)) {
    final week = startOfWeek(day);
    final StreakDayKind kind;
    if (workoutDays.contains(day)) {
      kind = StreakDayKind.workout;
      length++;
    } else if (day == last) {
      kind = StreakDayKind.pending;
    } else if (length > 0 && (restUsed[week] ?? 0) < restPerWeek) {
      kind = StreakDayKind.rest;
      restUsed[week] = (restUsed[week] ?? 0) + 1;
      length++;
    } else {
      kind = StreakDayKind.broken;
      length = 0;
    }
    days.add(StreakDay(day, kind, length));
  }
  return days;
}

/// Antrenman günü → o günün seri uzunluğu; bugüne bağlı değil (son antrenman günü "bugün").
Map<DateTime, int> workoutStreakLengths(List<SessionVerdict> verdicts, {required int weeklyGoal}) {
  final counted = [
    for (final v in verdicts)
      if (v.counted) v.finishedAt,
  ];
  if (counted.isEmpty) return const {};
  final last = counted.reduce((a, b) => a.isAfter(b) ? a : b);
  return {
    for (final d in streakDays(verdicts, weeklyGoal: weeklyGoal, today: last))
      if (d.kind == StreakDayKind.workout) d.day: d.length,
  };
}

/// Ana sayfa hapı ve seri kartı (O4 spec §3.4).
class StreakStatus {
  const StreakStatus({required this.length, required this.bonusPercent, required this.restLeft, required this.broken});

  static const none = StreakStatus(length: 0, bonusPercent: 0, restLeft: 0, broken: true);

  /// Dünün sonundaki seri; bugün antrenman varsa bugünün.
  final int length;
  final int bonusPercent;

  /// Bu ISO hafta kalan dinlenme hakkı.
  final int restLeft;

  /// Son gün (bugün bekliyorsa dün) kırık ya da hiç antrenman yok.
  final bool broken;
}

StreakStatus streakStatus(List<SessionVerdict> verdicts, {required int weeklyGoal, required DateTime today}) {
  final days = streakDays(verdicts, weeklyGoal: weeklyGoal, today: today);
  final week = startOfWeek(today);
  final rests = days.where((d) => d.kind == StreakDayKind.rest && startOfWeek(d.day) == week).length;
  final current = switch (days) {
    [..., final previous, StreakDay(kind: StreakDayKind.pending)] => previous,
    [..., final last] => last,
    _ => null,
  };
  final length = current?.length ?? 0;
  return StreakStatus(
    length: length,
    bonusPercent: streakBonusPercent(length),
    restLeft: 7 - weeklyGoal - rests,
    broken: current == null || current.kind == StreakDayKind.broken,
  );
}
```

- [ ] **Step 5: Testi geçir**

Run: `flutter test --no-pub -j 1 test/features/gamification/domain/streak_test.dart`
Expected: PASS (tümü).

- [ ] **Step 6: Commit**

```bash
git add lib/features/gamification/domain/game_settings.dart lib/features/gamification/domain/streak.dart test/features/gamification/domain/streak_test.dart
git commit -m "feat(streak): compute the daily streak with weekly rest days"
```

---

### Task 2: Haftalık görevler (`quests.dart`)

**Files:**
- Create: `lib/features/gamification/domain/quests.dart`
- Test: `test/features/gamification/domain/quests_test.dart`

**Interfaces:**
- Consumes: `SessionVerdict`, `judgeSessions`; `localDay` (Task 1); `startOfWeek`; `weekKey` (`lib/features/social/domain/period_keys.dart`); `muscleGroups` (`lib/features/workout/domain/exercise_taxonomy.dart`); `muscleWeight` (`lib/features/workout/domain/muscle_heat.dart`); `Exercise`.
- Produces: `enum QuestKind { workouts, sets, volume, long, record, muscle, variety, weekend, mealDays, fullDays }`; sabitler `xpPerQuest = 40`, `xpAllQuests = 60`, `allQuestsLabel = 'all'`, `longWorkout`, `varietyMinSets`, `questCategories`; `int fnv1a32(String)`; `typedef QuestPick = ({QuestKind kind, String? muscle})`; `List<QuestPick> pickQuests(String userId, DateTime weekStart)`; `class QuestInputs { verdicts, recordTimes, mealTimes, exercisesById, weeklyGoal }`; `class QuestProgress { kind, muscle, progress, target, doneAt; bool done }`; `class WeekQuests { weekStart, quests; DateTime? bonusAt; bool bonusDone }`; `QuestProgress questProgress(QuestPick, QuestInputs, DateTime weekStart)`; `WeekQuests weekQuests(QuestInputs, {required String userId, required DateTime weekStart})`; `List<DateTime> questWeeks(QuestInputs)`.

- [ ] **Step 1: Failing test yaz**

`test/features/gamification/domain/quests_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:spor_takip/features/gamification/domain/fair_play.dart';
import 'package:spor_takip/features/gamification/domain/quests.dart';
import 'package:spor_takip/features/gamification/domain/xp_rules.dart';
import 'package:spor_takip/features/workout/domain/exercise.dart';
import 'package:spor_takip/features/workout/domain/exercise_taxonomy.dart';
import 'package:spor_takip/features/workout/domain/workout_session.dart';

import '../game_fixtures.dart';

// 5 Ekim 2026 pazartesi; 28 Eylül önceki hafta.
final _week = DateTime(2026, 10, 5);

/// Her kası birincil çalıştıran hareket (kas görevinin seçimi ne olursa olsun katkı verir).
const _everything = Exercise(id: 'bench', name: 'Barbell Bench Press', primaryMuscles: muscleGroups);

QuestInputs _inputs(
  List<WorkoutSession> sessions, {
  List<DateTime> meals = const [],
  int weeklyGoal = 3,
  Map<String, Exercise>? exercisesById,
}) =>
    QuestInputs(
      verdicts: judgeSessions(sessions),
      recordTimes: [
        for (final e in xpEvents(sessions, const []))
          if (e.source == XpSource.record) e.date,
      ],
      mealTimes: meals,
      exercisesById: exercisesById ?? gameExercisesById,
      weeklyGoal: weeklyGoal,
    );

QuestProgress _progress(QuestKind kind, QuestInputs inputs, {String? muscle}) =>
    questProgress((kind: kind, muscle: muscle), inputs, _week);

void main() {
  test('fnv1a32 matches the reference vectors', () {
    expect(fnv1a32(''), 0x811c9dc5);
    expect(fnv1a32('a'), 0xe40c292c);
    expect(fnv1a32('foobar'), 0xbf9cf968);
  });

  group('pickQuests', () {
    test('is stable and takes one quest from each category', () {
      final picks = pickQuests('user-1', _week);
      expect(pickQuests('user-1', _week), picks);
      expect(picks, hasLength(3));
      for (final (i, pick) in picks.indexed) {
        expect(questCategories[i], contains(pick.kind));
        expect(pick.muscle, pick.kind == QuestKind.muscle ? isIn(muscleGroups) : isNull);
      }
    });

    test('changes across weeks', () {
      final weeks = {
        for (var i = 0; i < 20; i++) pickQuests('user-1', DateTime(2026, 10, 5 + 7 * i)).map((p) => p.kind).join(),
      };
      expect(weeks.length, greaterThan(1));
    });
  });

  group('questProgress', () {
    test('workouts: done at the workout that reaches the weekly goal', () {
      final p = _progress(
        QuestKind.workouts,
        _inputs([
          gameSession('a', DateTime(2026, 10, 5, 18), gameSets('bench', 3)),
          gameSession('small', DateTime(2026, 10, 6, 18), gameSets('bench', 2)),
          gameSession('b', DateTime(2026, 10, 7, 18), gameSets('bench', 3)),
          gameSession('c', DateTime(2026, 10, 9, 18), gameSets('bench', 3)),
          gameSession('next', DateTime(2026, 10, 12, 18), gameSets('bench', 3)),
        ], weeklyGoal: 2),
      );
      expect((p.progress, p.target, p.doneAt), (3.0, 2.0, DateTime(2026, 10, 7, 18)));
    });

    test('sets and volume targets grow from the previous 4 weeks', () {
      final history = [
        for (final day in [7, 14, 21, 28])
          gameSession('h$day', DateTime(2026, 9, day, 18), gameSets('bench', 25, kg: 100, reps: 10)),
      ];
      final inputs = _inputs([...history, gameSession('a', DateTime(2026, 10, 6, 18), gameSets('bench', 20, kg: 10, reps: 10))]);
      final sets = _progress(QuestKind.sets, inputs);
      // 100 / 4 × 1,1 = 27,5 → 30.
      expect((sets.progress, sets.target, sets.done), (20.0, 30.0, false));
      final volume = _progress(QuestKind.volume, inputs);
      // 100000 / 4 × 1,1 = 27500.
      expect((volume.progress, volume.target), (2000.0, 27500.0));
    });

    test('sets and volume targets have floors and a ceiling', () {
      final empty = _inputs(const []);
      expect(_progress(QuestKind.sets, empty).target, 15);
      expect(_progress(QuestKind.volume, empty).target, 3000);
      final heavy = _inputs([
        for (final day in [7, 8, 9, 10, 14, 15, 16, 17])
          gameSession('h$day', DateTime(2026, 9, day, 18), gameSets('bench', 30, kg: 50, reps: 5)),
      ]);
      // 240 / 4 × 1,1 = 66 → 70 → 60.
      expect(_progress(QuestKind.sets, heavy).target, 60);
    });

    test('long: only workouts of at least 45 minutes', () {
      final p = _progress(
        QuestKind.long,
        _inputs([
          gameSession('short', DateTime(2026, 10, 5, 18), gameSets('bench', 3), duration: const Duration(minutes: 30)),
          gameSession('a', DateTime(2026, 10, 6, 18), gameSets('bench', 3), duration: const Duration(minutes: 45)),
          gameSession('b', DateTime(2026, 10, 8, 18), gameSets('bench', 3)),
        ]),
      );
      expect((p.progress, p.doneAt), (2.0, DateTime(2026, 10, 8, 18)));
    });

    test('record: done at the record event', () {
      final p = _progress(
        QuestKind.record,
        _inputs([
          gameSession('base', DateTime(2026, 10, 1, 18), gameSets('bench', 3, kg: 100, reps: 5)),
          gameSession('pr', DateTime(2026, 10, 6, 18), gameSets('bench', 3, kg: 110, reps: 5)),
        ]),
      );
      expect((p.progress, p.target, p.doneAt), (1.0, 1.0, DateTime(2026, 10, 6, 18)));
    });

    test('muscle: weighted counted sets for the picked muscle', () {
      final inputs = _inputs([
        gameSession('a', DateTime(2026, 10, 5, 18), gameSets('bench', 6)), // göğüs 6, triceps 3
        gameSession('b', DateTime(2026, 10, 7, 18), gameSets('bench', 6)),
      ]);
      expect(_progress(QuestKind.muscle, inputs, muscle: 'chest').doneAt, DateTime(2026, 10, 7, 18));
      final triceps = _progress(QuestKind.muscle, inputs, muscle: 'triceps');
      expect((triceps.progress, triceps.target, triceps.done), (6.0, 8.0, false));
    });

    test('variety: muscle groups with at least 3 weighted sets', () {
      final p = _progress(
        QuestKind.variety,
        _inputs([
          gameSession('a', DateTime(2026, 10, 5, 18), gameSets('bench', 4)), // göğüs 4, triceps 2
          gameSession('b', DateTime(2026, 10, 6, 18), gameSets('squat', 3)), // quadriceps 3
          gameSession('c', DateTime(2026, 10, 7, 18), gameSets('bench', 2)), // triceps 3
        ]),
      );
      expect((p.progress, p.target, p.done), (3.0, 4.0, false));
    });

    test('weekend: a counted workout on Saturday or Sunday', () {
      final p = _progress(
        QuestKind.weekend,
        _inputs([
          gameSession('fri', DateTime(2026, 10, 9, 18), gameSets('bench', 3)),
          gameSession('sun', DateTime(2026, 10, 11, 10), gameSets('bench', 3)),
        ]),
      );
      expect(p.doneAt, DateTime(2026, 10, 11, 10));
    });

    test('meal days: done at the first meal of the fifth day', () {
      final p = _progress(
        QuestKind.mealDays,
        _inputs(const [], meals: [
          for (var d = 5; d <= 9; d++) ...[DateTime(2026, 10, d, 13), DateTime(2026, 10, d, 8)],
          DateTime(2026, 10, 12, 8),
        ]),
      );
      expect((p.progress, p.doneAt), (5.0, DateTime(2026, 10, 9, 8)));
    });

    test('full days: a counted workout and a meal on the same day, at the later of the two', () {
      final p = _progress(
        QuestKind.fullDays,
        _inputs([
          for (final d in [5, 6, 7, 8]) gameSession('s$d', DateTime(2026, 10, d, 18), gameSets('bench', 3)),
        ], meals: [
          DateTime(2026, 10, 5, 8),
          DateTime(2026, 10, 6, 20),
          DateTime(2026, 10, 7, 21),
          DateTime(2026, 10, 9, 8), // antrenmansız gün
        ]),
      );
      expect((p.progress, p.target, p.doneAt), (3.0, 3.0, DateTime(2026, 10, 7, 21)));
    });
  });

  group('weekQuests', () {
    // Önceki hafta düşük kilo (rekor tabanı); bu hafta 3 gün her kası çalıştıran ağır antrenman + 5 gün öğün:
    // hangi 3 görev seçilirse seçilsin hepsi biter.
    final sessions = [
      gameSession('base', DateTime(2026, 10, 1, 18), gameSets('bench', 10, kg: 100, reps: 5)),
      for (final d in [5, 7, 10]) gameSession('s$d', DateTime(2026, 10, d, 18), gameSets('bench', 10, kg: 110, reps: 5)),
    ];
    final meals = [for (final d in [5, 6, 7, 8, 10]) DateTime(2026, 10, d, 8)];
    final inputs = _inputs(sessions, meals: meals, weeklyGoal: 2, exercisesById: {'bench': _everything});

    test('all three done → bonus at the last completion', () {
      final week = weekQuests(inputs, userId: 'user-1', weekStart: _week);
      expect(week.quests.map((q) => (kind: q.kind, muscle: q.muscle)), pickQuests('user-1', _week));
      expect(week.quests.every((q) => q.done), isTrue);
      final last = week.quests.map((q) => q.doneAt!).reduce((a, b) => a.isAfter(b) ? a : b);
      expect((week.bonusDone, week.bonusAt), (true, last));
    });

    test('nothing this week → no bonus', () {
      final week = weekQuests(inputs, userId: 'user-1', weekStart: DateTime(2026, 10, 12));
      expect(week.quests.any((q) => q.done), isFalse);
      expect(week.bonusAt, isNull);
    });
  });

  test('questWeeks spans the first to the last activity week', () {
    expect(questWeeks(_inputs(const [])), isEmpty);
    final weeks = questWeeks(_inputs(
      [gameSession('a', DateTime(2026, 9, 30, 18), gameSets('bench', 3))],
      meals: [DateTime(2026, 10, 13, 8)],
    ));
    expect(weeks, [DateTime(2026, 9, 28), DateTime(2026, 10, 5), DateTime(2026, 10, 12)]);
  });
}
```

- [ ] **Step 2: Testin derlenmediğini doğrula**

Run: `flutter test --no-pub -j 1 test/features/gamification/domain/quests_test.dart`
Expected: FAIL — `quests.dart` yok.

- [ ] **Step 3: `quests.dart` yaz**

```dart
import 'dart:convert';

import '../../progress/domain/weekly_summary.dart';
import '../../social/domain/period_keys.dart';
import '../../workout/domain/exercise.dart';
import '../../workout/domain/exercise_taxonomy.dart';
import '../../workout/domain/muscle_heat.dart';
import 'fair_play.dart';
import 'streak.dart';

/// Haftalık görev havuzu (O4 spec §4.1).
enum QuestKind { workouts, sets, volume, long, record, muscle, variety, weekend, mealDays, fullDays }

const xpPerQuest = 40;
const xpAllQuests = 60;

/// Üç görevin bonus olayının etiketi.
const allQuestsLabel = 'all';

const longWorkout = Duration(minutes: 45);
const varietyMinSets = 3.0;
const questHistoryWeeks = 4;
const questGrowth = 1.1;
const minQuestSets = 15;
const maxQuestSets = 60;
const minQuestVolume = 3000;

/// Kategori sırasıyla: antrenman, güç/çeşitlilik, beslenme/denge.
const questCategories = <List<QuestKind>>[
  [QuestKind.workouts, QuestKind.sets, QuestKind.volume, QuestKind.long],
  [QuestKind.record, QuestKind.muscle, QuestKind.variety, QuestKind.weekend],
  [QuestKind.mealDays, QuestKind.fullDays],
];

/// 32-bit FNV-1a (UTF-8). Çarpım `2^24 + 403` olarak parçalı: web'de 2^53 aşılmasın.
int fnv1a32(String input) {
  var hash = 0x811c9dc5;
  for (final byte in utf8.encode(input)) {
    hash ^= byte;
    hash = ((hash << 24) + hash * 403) & 0xFFFFFFFF;
  }
  return hash;
}

typedef QuestPick = ({QuestKind kind, String? muscle});

/// Her kategoriden bir görev; tohum kullanıcı + ISO hafta (O4 spec §4.2).
List<QuestPick> pickQuests(String userId, DateTime weekStart) {
  final seed = fnv1a32('$userId${weekKey(weekStart)}');
  return [
    for (final (i, category) in questCategories.indexed)
      if (category[(seed >> (8 * i)) % category.length] case final kind)
        (kind: kind, muscle: kind == QuestKind.muscle ? muscleGroups[(seed >> 24) % muscleGroups.length] : null),
  ];
}

class QuestInputs {
  const QuestInputs({
    required this.verdicts,
    required this.recordTimes,
    required this.mealTimes,
    required this.exercisesById,
    required this.weeklyGoal,
  });

  /// `judgeSessions` çıktısı (eskiden yeniye); yalnız sayılanlar katkı verir.
  final List<SessionVerdict> verdicts;

  /// XP getiren rekor olaylarının yerel zamanları.
  final List<DateTime> recordTimes;
  final List<DateTime> mealTimes;
  final Map<String, Exercise> exercisesById;
  final int weeklyGoal;
}

class QuestProgress {
  const QuestProgress({required this.kind, this.muscle, required this.progress, required this.target, this.doneAt});

  final QuestKind kind;

  /// Yalnız kas görevinde.
  final String? muscle;
  final double progress;
  final double target;

  /// Hedefe ilk ulaşılan an (yerel); null → bitmedi.
  final DateTime? doneAt;

  bool get done => doneAt != null;
}

class WeekQuests {
  const WeekQuests({required this.weekStart, required this.quests});

  final DateTime weekStart;
  final List<QuestProgress> quests;

  /// Üçü de bittiyse sonuncunun anı.
  DateTime? get bonusAt => quests.isNotEmpty && quests.every((q) => q.done)
      ? quests.map((q) => q.doneAt!).reduce((a, b) => a.isAfter(b) ? a : b)
      : null;

  bool get bonusDone => bonusAt != null;
}

WeekQuests weekQuests(QuestInputs inputs, {required String userId, required DateTime weekStart}) => WeekQuests(
      weekStart: weekStart,
      quests: [for (final pick in pickQuests(userId, weekStart)) questProgress(pick, inputs, weekStart)],
    );

/// İlk etkinliğin (sayılan oturum ya da öğün) haftasından sonuncununkine; etkinlik yoksa boş.
List<DateTime> questWeeks(QuestInputs inputs) {
  final times = [
    for (final v in inputs.verdicts)
      if (v.counted) v.finishedAt,
    for (final t in inputs.mealTimes) t.toLocal(),
  ]..sort();
  if (times.isEmpty) return const [];
  final last = startOfWeek(times.last);
  return [
    for (var w = startOfWeek(times.first); !w.isAfter(last); w = DateTime(w.year, w.month, w.day + 7)) w,
  ];
}

/// Görevin [weekStart] haftasındaki ilerlemesi ve tamamlanma anı (O4 spec §4.1, §4.3).
QuestProgress questProgress(QuestPick pick, QuestInputs inputs, DateTime weekStart) {
  final end = DateTime(weekStart.year, weekStart.month, weekStart.day + 7);
  bool inWeek(DateTime t) => !t.isBefore(weekStart) && t.isBefore(end);
  final sessions = [
    for (final v in inputs.verdicts)
      if (v.counted && inWeek(v.finishedAt)) v,
  ];
  final points = _points(pick, inputs, sessions, inWeek);
  final target = _target(pick.kind, inputs, weekStart);
  return QuestProgress(
    kind: pick.kind,
    muscle: pick.muscle,
    progress: points.isEmpty ? 0 : points.last.$2,
    target: target,
    doneAt: points.where((p) => p.$2 >= target).firstOrNull?.$1,
  );
}

/// (an, birikmiş değer), eskiden yeniye.
typedef _Point = (DateTime, double);

List<_Point> _cumulative(List<_Point> deltas) {
  deltas.sort((a, b) => a.$1.compareTo(b.$1));
  var total = 0.0;
  return [for (final (time, delta) in deltas) (time, total += delta)];
}

List<_Point> _points(
  QuestPick pick,
  QuestInputs inputs,
  List<SessionVerdict> sessions,
  bool Function(DateTime) inWeek,
) {
  switch (pick.kind) {
    case QuestKind.workouts:
      return _cumulative([for (final v in sessions) (v.finishedAt, 1)]);
    case QuestKind.sets:
      return _cumulative([for (final v in sessions) (v.finishedAt, v.countedSets.length.toDouble())]);
    case QuestKind.volume:
      return _cumulative([for (final v in sessions) (v.finishedAt, _volume(v))]);
    case QuestKind.long:
      return _cumulative([
        for (final v in sessions)
          if (v.session.finishedAt!.difference(v.session.startedAt) >= longWorkout) (v.finishedAt, 1),
      ]);
    case QuestKind.record:
      return _cumulative([
        for (final t in inputs.recordTimes)
          if (inWeek(t)) (t, 1),
      ]);
    case QuestKind.muscle:
      return _cumulative([
        for (final v in sessions) (v.finishedAt, _muscleSets(v, pick.muscle!, inputs.exercisesById)),
      ]);
    case QuestKind.variety:
      final load = <String, double>{};
      final points = <_Point>[];
      for (final v in sessions) {
        for (final muscle in muscleGroups) {
          final sets = _muscleSets(v, muscle, inputs.exercisesById);
          if (sets > 0) load[muscle] = (load[muscle] ?? 0) + sets;
        }
        points.add((v.finishedAt, load.values.where((sets) => sets >= varietyMinSets).length.toDouble()));
      }
      return points;
    case QuestKind.weekend:
      return _cumulative([
        for (final v in sessions)
          if (v.finishedAt.weekday >= DateTime.saturday) (v.finishedAt, 1),
      ]);
    case QuestKind.mealDays:
      return _cumulative([for (final t in _firstMealByDay(inputs.mealTimes, inWeek).values) (t, 1)]);
    case QuestKind.fullDays:
      final meals = _firstMealByDay(inputs.mealTimes, inWeek);
      final workouts = <DateTime, DateTime>{};
      for (final v in sessions) {
        workouts.putIfAbsent(localDay(v.finishedAt), () => v.finishedAt);
      }
      return _cumulative([
        for (final MapEntry(key: day, value: workoutAt) in workouts.entries)
          if (meals[day] case final mealAt?) (workoutAt.isAfter(mealAt) ? workoutAt : mealAt, 1),
      ]);
  }
}

double _target(QuestKind kind, QuestInputs inputs, DateTime weekStart) => switch (kind) {
      QuestKind.workouts => inputs.weeklyGoal.toDouble(),
      QuestKind.sets => _roundUp(_weeklyAverage(inputs, weekStart, (v) => v.countedSets.length.toDouble()) * questGrowth, 5)
          .clamp(minQuestSets, maxQuestSets)
          .toDouble(),
      QuestKind.volume => _roundUp(_weeklyAverage(inputs, weekStart, _volume) * questGrowth, 500)
          .clamp(minQuestVolume, double.maxFinite)
          .toDouble(),
      QuestKind.long => 2,
      QuestKind.record => 1,
      QuestKind.muscle => 8,
      QuestKind.variety => 4,
      QuestKind.weekend => 1,
      QuestKind.mealDays => 5,
      QuestKind.fullDays => 3,
    };

/// [weekStart]'tan önceki 4 haftanın sayılan oturumlarından haftalık ortalama.
double _weeklyAverage(QuestInputs inputs, DateTime weekStart, double Function(SessionVerdict) value) {
  final from = DateTime(weekStart.year, weekStart.month, weekStart.day - 7 * questHistoryWeeks);
  var total = 0.0;
  for (final v in inputs.verdicts) {
    if (v.counted && !v.finishedAt.isBefore(from) && v.finishedAt.isBefore(weekStart)) total += value(v);
  }
  return total / questHistoryWeeks;
}

/// [step]'in katına yukarı; 27500.000000001 gibi kayan nokta artıkları yukarı taşımasın.
int _roundUp(double x, int step) => (x / step - 1e-9).ceil() * step;

/// Sayılan setlerin kg × tekrar toplamı; kilosuz set 0.
double _volume(SessionVerdict v) => v.countedSets.fold(0.0, (sum, s) => sum + (s.weightKg ?? 0) * (s.reps ?? 0));

/// Sayılan setlerin [muscle] için `muscleWeight` toplamı; kası bilinmeyen hareket 0.
double _muscleSets(SessionVerdict v, String muscle, Map<String, Exercise> exercisesById) => v.countedSets.fold(
      0.0,
      (sum, s) => sum + switch (exercisesById[s.exerciseId]) {
        final exercise? => muscleWeight(exercise, muscle),
        null => 0.0,
      },
    );

/// Gün → o günün ilk öğün anı (yerel), yalnız [inWeek] içinde.
Map<DateTime, DateTime> _firstMealByDay(List<DateTime> mealTimes, bool Function(DateTime) inWeek) {
  final first = <DateTime, DateTime>{};
  for (final t in [for (final t in mealTimes) t.toLocal()]..sort()) {
    if (inWeek(t)) first.putIfAbsent(localDay(t), () => t);
  }
  return first;
}
```

Not: `_target`'taki `.clamp(...)` `num` döndürür; `.toDouble()` gerekli. `quests_test.dart` `xpEvents`'i yalnız rekor zamanları için çağırır (henüz değişmemiş imza).

- [ ] **Step 4: Testi geçir**

Run: `flutter test --no-pub -j 1 test/features/gamification/domain/quests_test.dart`
Expected: PASS. Seçimden bağımsız `weekQuests` testi başarısızsa önce hangi görevin bitmediğine bak (`week.quests` yazdır); fikstür her görevi bitirecek kadar zengin olmalı, kodu fikstüre göre eğme.

- [ ] **Step 5: Commit**

```bash
git add lib/features/gamification/domain/quests.dart test/features/gamification/domain/quests_test.dart
git commit -m "feat(quests): pick three weekly quests and track their progress"
```

---

### Task 3: XP olaylarına seri bonusu ve görevler; özet

**Files:**
- Modify: `lib/features/gamification/domain/xp_rules.dart`
- Modify: `lib/features/gamification/domain/player_summary.dart`
- Modify: `lib/features/gamification/presentation/level_screen.dart` (yalnız `_Recent` switch'leri derlensin diye)
- Create: `lib/features/gamification/presentation/widgets/streak_quest_cards.dart` (yalnız `questText` bu görevde)
- Modify: `assets/translations/tr.json`, `assets/translations/en.json`
- Test: `test/features/gamification/domain/xp_rules_test.dart`, `test/features/gamification/domain/player_summary_test.dart`

**Interfaces:**
- Consumes: Task 1 ve 2'nin tümü.
- Produces: `enum XpSource { workout, record, mealDay, challenge, quest }`; `XpEvent` yeni alanları `int streakBonus = 0`, `int streakPercent = 0`, `String? muscle`, `double? target`; `xpEvents(List<WorkoutSession>, List<DateTime>, {Map<String, Exercise> exercisesById = const {}, GameSettings? settings})`; `XpBreakdown.streak`, `XpBreakdown.quests`; `PlayerSummary.streak` (varsayılan `StreakStatus.none`), `PlayerSummary.quests` (`WeekQuests?`); `playerSummary(sessions, mealTimes, exercisesById, {rewards, GameSettings? settings, List<XpEvent>? events, DateTime? now})`; `String questText(QuestKind kind, {required double target, String? muscle})`.

- [ ] **Step 1: Failing testleri yaz**

`test/features/gamification/domain/xp_rules_test.dart` sonuna (`main` içine) ekle; dosyanın başına `import 'package:spor_takip/features/gamification/domain/game_settings.dart';` ve `import 'package:spor_takip/features/gamification/domain/quests.dart';` ekle:

```dart
  group('O4 streak and quests', () {
    // 14 gün art arda 3 setlik antrenman: 7. günden %5, 14. gün %10.
    final daily = [
      for (var d = 1; d <= 14; d++) gameSession('d$d', DateTime(2026, 9, d, 18), gameSets('bench', 3)),
    ];

    test('without settings nothing changes', () {
      final workouts = xpEvents(daily, const []).where((e) => e.source == XpSource.workout);
      expect(workouts.map((e) => e.xp).toSet(), {65});
    });

    test('the streak bonus is added to counted workout XP', () {
      final events = xpEvents(daily, const [], settings: const GameSettings(weeklyGoal: 3));
      final workouts = events.where((e) => e.source == XpSource.workout).toList();
      // 65 × %5 = 3,25 → 3; 65 × %10 = 6,5 → 6.
      expect(workouts.map((e) => e.xp), [...List.filled(6, 65), ...List.filled(7, 68), 71]);
      expect((workouts[6].streakBonus, workouts[6].streakPercent), (3, 5));
      expect(events.where((e) => e.source == XpSource.quest), isEmpty);
    });

    test('a session that does not count gets no bonus', () {
      final events = xpEvents(
        [...daily, gameSession('small', DateTime(2026, 9, 14, 20), gameSets('bench', 2))],
        const [],
        settings: const GameSettings(weeklyGoal: 3),
      );
      expect(events.where((e) => e.source == XpSource.workout).last.xp, 0);
    });

    test('quest events need a user id and match weekQuests', () {
      final events = xpEvents(
        daily,
        [for (var d = 1; d <= 14; d++) DateTime(2026, 9, d, 8)],
        exercisesById: gameExercisesById,
        settings: const GameSettings(weeklyGoal: 3, userId: 'user-1'),
      );
      final quests = events.where((e) => e.source == XpSource.quest).toList();
      expect(quests, isNotEmpty);
      for (final e in quests) {
        expect(e.xp, e.label == allQuestsLabel ? xpAllQuests : xpPerQuest);
      }
      final inputs = QuestInputs(
        verdicts: judgeSessions(daily),
        recordTimes: const [],
        mealTimes: [for (var d = 1; d <= 14; d++) DateTime(2026, 9, d, 8)],
        exercisesById: gameExercisesById,
        weeklyGoal: 3,
      );
      final expected = [
        for (final week in questWeeks(inputs))
          for (final q in weekQuests(inputs, userId: 'user-1', weekStart: week).quests)
            if (q.doneAt case final at?) (q.kind.name, at),
      ];
      expect([
        for (final e in quests)
          if (e.label != allQuestsLabel) (e.label, e.date),
      ], unorderedEquals(expected));
    });

    test('breakdown splits the streak bonus and quests', () {
      final breakdown = xpBreakdown([
        XpEvent(source: XpSource.workout, date: DateTime(2026, 9, 7), xp: 68, sets: 3, streakBonus: 3, streakPercent: 5),
        XpEvent(source: XpSource.quest, date: DateTime(2026, 9, 7), xp: 40, label: 'sets'),
        XpEvent(source: XpSource.quest, date: DateTime(2026, 9, 7), xp: 60, label: allQuestsLabel),
      ]);
      expect((breakdown.workouts, breakdown.sets, breakdown.streak, breakdown.quests, breakdown.total), (50, 15, 3, 100, 168));
    });
  });
```

`test/features/gamification/domain/player_summary_test.dart` `main` içine ekle (başa `game_settings.dart` importu):

```dart
  test('streak and quests need settings; quests need a user id', () {
    final sessions = [gameSession('a', DateTime(2026, 10, 5, 18), gameSets('bench', 3))];
    final plain = playerSummary(sessions, const [], gameExercisesById);
    expect((plain.streak.length, plain.quests), (0, null));

    final now = DateTime(2026, 10, 6, 9);
    final noUser = playerSummary(sessions, const [], gameExercisesById,
        settings: const GameSettings(weeklyGoal: 4), now: now);
    expect((noUser.streak.length, noUser.streak.restLeft, noUser.quests), (1, 3, null));

    final withUser = playerSummary(sessions, const [], gameExercisesById,
        settings: const GameSettings(weeklyGoal: 4, userId: 'user-1'), now: now);
    expect(withUser.quests!.weekStart, DateTime(2026, 10, 5));
    expect(withUser.quests!.quests, hasLength(3));
  });

  test('precomputed events are used as given', () {
    final event = XpEvent(source: XpSource.quest, date: DateTime(2026, 10, 5), xp: 40, label: 'sets');
    final summary = playerSummary(const [], const [], const {}, events: [event]);
    expect(summary.totalXp, 40);
  });
```

- [ ] **Step 2: Testlerin başarısız olduğunu doğrula**

Run: `flutter test --no-pub -j 1 test/features/gamification/domain/xp_rules_test.dart test/features/gamification/domain/player_summary_test.dart`
Expected: FAIL — `settings`, `streakBonus`, `XpSource.quest` tanımsız.

- [ ] **Step 3: `xp_rules.dart`'ı güncelle**

İmportlara ekle:

```dart
import '../../workout/domain/exercise.dart';
import 'game_settings.dart';
import 'quests.dart';
import 'streak.dart';
```

`XpSource` ve `XpEvent`:

```dart
/// XP olayının kaynağı (O1 spec §3; meydan okuma ödülü S3 spec §3.3; görev O4 spec §4.3).
enum XpSource { workout, record, mealDay, challenge, quest }
```

`XpEvent` yapıcısına `this.streakBonus = 0, this.streakPercent = 0, this.muscle, this.target,` ekle; alanlar (`skip`'ten sonra):

```dart
  /// Yalnız antrenmanda: seri bonusu (XP'ye dahil) ve yüzdesi (O4 spec §3.3).
  final int streakBonus;
  final int streakPercent;

  /// Yalnız görevde: kas görevinin kası ve görevin hedefi; `label` görev türü (`QuestKind.name` ya da 'all').
  final String? muscle;
  final double? target;
```

`label` belgesini güncelle: `/// Antrenman: antrenman adı; rekor: hareket adı; görev: görev türü; öğün: null.`

`xpEvents`'i şununla değiştir:

```dart
/// Eskiden yeniye; aynı anda antrenman → rekor → öğün → meydan okuma → görev. Kurallar: O3a spec §3.
/// [settings] null → seri bonusu ve görev yok (O4 spec §5); `userId` null → görev yok.
List<XpEvent> xpEvents(
  List<WorkoutSession> sessions,
  List<DateTime> mealTimes, {
  Map<String, Exercise> exercisesById = const {},
  GameSettings? settings,
}) {
  final events = <XpEvent>[];
  final best = <String, double>{};
  final lastRecord = <String, DateTime>{};
  final verdicts = judgeSessions(sessions);
  final lengths = settings == null
      ? const <DateTime, int>{}
      : workoutStreakLengths(verdicts, weeklyGoal: settings.weeklyGoal);
  for (final verdict in verdicts) {
    final sets = verdict.countedSets.length;
    final base = verdict.counted ? xpPerWorkout + sets * xpPerSet : 0;
    final percent = verdict.counted ? streakBonusPercent(lengths[localDay(verdict.finishedAt)] ?? 0) : 0;
    final bonus = base * percent ~/ 100;
    events.add(XpEvent(
      source: XpSource.workout,
      date: verdict.finishedAt,
      xp: base + bonus,
      label: verdict.session.workoutName,
      sets: sets,
      skip: verdict.skip,
      streakBonus: bonus,
      streakPercent: percent,
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

  if (settings case GameSettings(userId: final userId?, :final weeklyGoal)) {
    final inputs = QuestInputs(
      verdicts: verdicts,
      recordTimes: [
        for (final e in events)
          if (e.source == XpSource.record) e.date,
      ],
      mealTimes: mealTimes,
      exercisesById: exercisesById,
      weeklyGoal: weeklyGoal,
    );
    events.addAll(_questEvents(inputs, userId));
  }

  events.sort(compareXpEvents);
  return events;
}

/// Her haftanın biten görevleri (40 XP) ve üçü bittiyse bonus (60 XP) (O4 spec §4.3).
List<XpEvent> _questEvents(QuestInputs inputs, String userId) {
  final events = <XpEvent>[];
  for (final weekStart in questWeeks(inputs)) {
    final week = weekQuests(inputs, userId: userId, weekStart: weekStart);
    for (final q in week.quests) {
      if (q.doneAt case final at?) {
        events.add(XpEvent(
          source: XpSource.quest,
          date: at,
          xp: xpPerQuest,
          label: q.kind.name,
          muscle: q.muscle,
          target: q.target,
        ));
      }
    }
    if (week.bonusAt case final at?) {
      events.add(XpEvent(source: XpSource.quest, date: at, xp: xpAllQuests, label: allQuestsLabel));
    }
  }
  return events;
}
```

`compareXpEvents` belgesine "→ görev" ekle. `XpBreakdown`:

```dart
/// Seviye ekranındaki döküm: antrenman tabanı, setler, rekorlar, öğün günleri, meydan okumalar,
/// seri bonusu, görevler.
class XpBreakdown {
  const XpBreakdown({
    this.workouts = 0,
    this.sets = 0,
    this.records = 0,
    this.mealDays = 0,
    this.challenges = 0,
    this.streak = 0,
    this.quests = 0,
  });

  final int workouts;
  final int sets;
  final int records;
  final int mealDays;
  final int challenges;
  final int streak;
  final int quests;

  int get total => workouts + sets + records + mealDays + challenges + streak + quests;
}

XpBreakdown xpBreakdown(List<XpEvent> events) {
  var workouts = 0, sets = 0, records = 0, mealDays = 0, challenges = 0, streak = 0, quests = 0;
  for (final e in events) {
    switch (e.source) {
      case XpSource.workout:
        if (e.xp > 0) workouts += xpPerWorkout;
        sets += e.sets * xpPerSet;
        streak += e.streakBonus;
      case XpSource.record:
        records += e.xp;
      case XpSource.mealDay:
        mealDays += e.xp;
      case XpSource.challenge:
        challenges += e.xp;
      case XpSource.quest:
        quests += e.xp;
    }
  }
  return XpBreakdown(
    workouts: workouts,
    sets: sets,
    records: records,
    mealDays: mealDays,
    challenges: challenges,
    streak: streak,
    quests: quests,
  );
}
```

- [ ] **Step 4: `player_summary.dart`'ı güncelle**

İmportlara `'../../progress/domain/weekly_summary.dart'`, `'fair_play.dart'`, `'game_settings.dart'`, `'quests.dart'`, `'streak.dart'` ekle. Yapıcıya `this.streak = StreakStatus.none, this.quests,` ve alanlar:

```dart
  /// Güncel seri (O4 spec §3.4); ayar yoksa [StreakStatus.none].
  final StreakStatus streak;

  /// Bu haftanın görevleri; kullanıcı id'si yoksa null.
  final WeekQuests? quests;
```

`playerSummary`:

```dart
/// [rewards]: kesinleşmiş meydan okuma ödülleri (`XpSource.challenge`, S3 spec §3.3).
/// [events]: önceden hesaplanmış `xpEvents` (sağlayıcı paylaşır); null ise burada hesaplanır.
PlayerSummary playerSummary(
  List<WorkoutSession> sessions,
  List<DateTime> mealTimes,
  Map<String, Exercise> exercisesById, {
  List<XpEvent> rewards = const [],
  GameSettings? settings,
  List<XpEvent>? events,
  DateTime? now,
}) {
  final all = [
    ...(events ?? xpEvents(sessions, mealTimes, exercisesById: exercisesById, settings: settings)),
    ...rewards,
  ]..sort(compareXpEvents);
  final breakdown = xpBreakdown(all);
  final progress = levelFor(breakdown.total);
  final titles = titleProgress(sessions, exercisesById, challengeWins: rewards.length);
  final today = now ?? DateTime.now();
  final verdicts = settings == null ? const <SessionVerdict>[] : judgeSessions(sessions);
  return PlayerSummary(
    totalXp: breakdown.total,
    progress: progress,
    rank: rankFor(progress.level),
    breakdown: breakdown,
    recent: all.reversed.take(10).toList(),
    titles: earnedTitles(titles),
    upcoming: upcomingTitles(titles),
    streak: settings == null
        ? StreakStatus.none
        : streakStatus(verdicts, weeklyGoal: settings.weeklyGoal, today: today),
    quests: switch (settings) {
      GameSettings(userId: final userId?, :final weeklyGoal) => weekQuests(
          QuestInputs(
            verdicts: verdicts,
            recordTimes: [
              for (final e in all)
                if (e.source == XpSource.record) e.date,
            ],
            mealTimes: mealTimes,
            exercisesById: exercisesById,
            weeklyGoal: weeklyGoal,
          ),
          userId: userId,
          weekStart: startOfWeek(today),
        ),
      _ => null,
    },
  );
}
```

- [ ] **Step 5: Görev metni ve geçmiş satırları**

`lib/features/gamification/presentation/widgets/streak_quest_cards.dart` oluştur (kartlar Task 5'te eklenecek):

```dart
import 'package:easy_localization/easy_localization.dart';

import '../../../workout/domain/exercise_taxonomy.dart';
import '../../domain/quests.dart';

/// "5 gün öğün kaydet" (O4 spec §6).
String questText(QuestKind kind, {required double target, String? muscle}) {
  final n = '${target.toInt()}';
  return switch (kind) {
    QuestKind.workouts => 'gamification.quest_workouts'.tr(namedArgs: {'n': n}),
    QuestKind.sets => 'gamification.quest_sets'.tr(namedArgs: {'n': n}),
    QuestKind.volume => 'gamification.quest_volume'.tr(namedArgs: {'n': n}),
    QuestKind.long => 'gamification.quest_long'.tr(namedArgs: {'n': n}),
    QuestKind.record => 'gamification.quest_record'.tr(),
    QuestKind.muscle =>
      'gamification.quest_muscle'.tr(namedArgs: {'n': n, 'muscle': muscleLabelKey(muscle ?? '').tr()}),
    QuestKind.variety => 'gamification.quest_variety'.tr(namedArgs: {'n': n}),
    QuestKind.weekend => 'gamification.quest_weekend'.tr(),
    QuestKind.mealDays => 'gamification.quest_meal_days'.tr(namedArgs: {'n': n}),
    QuestKind.fullDays => 'gamification.quest_full_days'.tr(namedArgs: {'n': n}),
  };
}
```

`level_screen.dart` `_Recent`'te (dosyaya `import '../domain/quests.dart';` ve `import 'widgets/streak_quest_cards.dart';` ekle):

```dart
  static IconData _icon(XpSource source) => switch (source) {
        XpSource.workout => Icons.fitness_center,
        XpSource.record => Icons.bolt,
        XpSource.mealDay => Icons.restaurant,
        XpSource.challenge => Icons.flag,
        XpSource.quest => Icons.task_alt,
      };

  static String _title(XpEvent event) => switch (event.source) {
        XpSource.workout => event.label ?? '',
        XpSource.record => 'gamification.record'.tr(namedArgs: {'name': event.label ?? ''}),
        XpSource.mealDay => 'gamification.meal_day'.tr(),
        XpSource.challenge => 'gamification.challenge_event'.tr(namedArgs: {'name': event.label ?? ''}),
        XpSource.quest => switch (QuestKind.values.asNameMap()[event.label]) {
            final kind? => 'gamification.quest_event'.tr(namedArgs: {
                'name': questText(kind, target: event.target ?? 0, muscle: event.muscle),
              }),
            null => 'gamification.quest_all'.tr(),
          },
      };

  static String? _detail(XpEvent event) => switch (event.source) {
        XpSource.workout => switch (event.skip) {
            SkipReason.tooSmall => 'gamification.skip_too_small'.tr(),
            SkipReason.dailyLimit => 'gamification.skip_daily_limit'.tr(),
            null => [
                'gamification.workout_sets'.tr(namedArgs: {'n': '${event.sets}'}),
                if (event.streakPercent > 0)
                  'gamification.streak_detail'.tr(namedArgs: {'n': '${event.streakPercent}'}),
              ].join(' · '),
          },
        XpSource.record => 'gamification.record_detail'.tr(namedArgs: {
            'kg': formatKg(event.weightKg ?? 0),
            'reps': '${event.reps ?? 0}',
          }),
        XpSource.mealDay => null,
        XpSource.challenge => null,
        XpSource.quest => null,
      };
```

- [ ] **Step 6: Çevirileri ekle**

`assets/translations/tr.json` `gamification` bölümünde `"rules_challenges": "Kazandığın meydan okumalar ödül XP'si verir."` satırını şununla değiştir:

```json
    "rules_challenges": "Kazandığın meydan okumalar ödül XP'si verir.",
    "quest_workouts": "{n} antrenman yap",
    "quest_sets": "{n} set tamamla",
    "quest_volume": "{n} kg hacim kaldır",
    "quest_long": "45 dakikayı geçen {n} antrenman",
    "quest_record": "Bir rekor kır",
    "quest_muscle": "{muscle} için {n} set",
    "quest_variety": "{n} kas grubunu en az 3 set çalıştır",
    "quest_weekend": "Hafta sonu antrenman yap",
    "quest_meal_days": "{n} gün öğün kaydet",
    "quest_full_days": "{n} gün hem antrenman hem öğün kaydı",
    "quest_event": "Görev: {name}",
    "quest_all": "Haftalık görevlerin hepsi",
    "streak_detail": "seri +%{n}"
```

`assets/translations/en.json`'da `"rules_challenges": "Challenges you win give reward XP."` satırını:

```json
    "rules_challenges": "Challenges you win give reward XP.",
    "quest_workouts": "Do {n} workouts",
    "quest_sets": "Complete {n} sets",
    "quest_volume": "Lift {n} kg of volume",
    "quest_long": "{n} workouts over 45 minutes",
    "quest_record": "Set a record",
    "quest_muscle": "{n} sets for {muscle}",
    "quest_variety": "Train {n} muscle groups for 3+ sets each",
    "quest_weekend": "Work out on the weekend",
    "quest_meal_days": "Log meals on {n} days",
    "quest_full_days": "{n} days with a workout and a meal",
    "quest_event": "Quest: {name}",
    "quest_all": "All weekly quests",
    "streak_detail": "streak +{n}%"
```

- [ ] **Step 7: Testleri geçir**

Run: `flutter test --no-pub -j 1 test/features/gamification`
Expected: PASS (eski testler dahil; `xpEvents` ve `playerSummary` varsayılanları eski davranış).

Run: `flutter analyze lib test`
Expected: `No issues found!` — başka dosyalarda `XpSource` üzerinde tam `switch` varsa (grep: `XpSource.challenge =>`) `XpSource.quest` kolunu ekle.

- [ ] **Step 8: Commit**

```bash
git add lib/features/gamification assets/translations test/features/gamification
git commit -m "feat(xp): add the streak bonus and weekly quest XP"
```

---

### Task 4: Ayar ve olay sağlayıcıları; paylaşılan olaylar

**Files:**
- Modify: `lib/features/onboarding/application/auth_providers.dart`
- Create: `lib/features/gamification/application/xp_event_providers.dart`
- Modify: `lib/features/gamification/application/gamification_providers.dart`
- Modify: `lib/features/social/application/challenge_providers.dart`
- Modify: `lib/features/social/application/social_providers.dart`
- Modify: `lib/features/social/domain/period_stats.dart`
- Test: `test/features/gamification/application/gamification_providers_test.dart`, `test/features/social/domain/period_stats_test.dart`, `test/features/social/application/{social,challenge}_providers_test.dart`

**Interfaces:**
- Consumes: `GameSettings`, `weeklyGoalFor` (Task 1); `xpEvents(..., exercisesById:, settings:)`, `playerSummary(..., settings:, events:, now:)` (Task 3); `programOf` (`lib/features/notifications/domain/reminder_inputs.dart`); `todayWorkoutProvider`, `exercisesByIdProvider`, `allSessionsProvider`, `mealTimesProvider`, `profileProvider`, `nowProvider`.
- Produces: `currentUserIdProvider` (`Provider<String?>`); `gameSettingsProvider` (`FutureProvider.autoDispose<GameSettings>`); `xpEventsProvider` (`FutureProvider.autoDispose<List<XpEvent>>`); `buildPeriodStats({..., required List<XpEvent> events, ...})` (`mealTimes` parametresi kalkar).

- [ ] **Step 1: Failing testleri yaz**

`gamification_providers_test.dart`: importlara `game_settings.dart`, `xp_event_providers.dart`, `onboarding/application/profile_providers.dart`, `workout/domain/today_workout.dart` ve `../../progress/fixtures.dart` (`testProfile`) ekle. `_container`'ı parametreli yap:

```dart
ProviderContainer _container({String? userId}) {
  final container = ProviderContainer(overrides: [
    isLoggedInProvider.overrideWithValue(true),
    currentUserIdProvider.overrideWithValue(userId),
    todayWorkoutProvider.overrideWith((ref) async => const NoActiveProgram()),
    profileProvider.overrideWith((ref) async => testProfile),
    challengeRewardsProvider.overrideWith((ref) async => const []),
    progressDataRepositoryProvider.overrideWithValue(FakeProgressDataRepository(
      sessions: [gameSession('a', DateTime(2026, 10, 1, 18), gameSets('bench', 3))],
      meals: [_meal('m1', DateTime(2026, 10, 2, 8)), _meal('m2', DateTime(2026, 10, 2, 13))],
    )),
    exerciseRepositoryProvider.overrideWithValue(FakeExerciseRepository([gameBench, gameSquat])),
  ]);
  addTearDown(container.dispose);
  return container;
}
```

Yeni testler:

```dart
  test('game settings: profile days without a program, and the user id', () async {
    final container = _container(userId: 'user-1');
    container.listen(gameSettingsProvider, (_, _) {});
    final settings = await container.read(gameSettingsProvider.future);
    expect(settings.weeklyGoal, weeklyGoalFor(profileDays: testProfile.exerciseDaysPerWeek));
    expect(settings.userId, 'user-1');
  });

  test('game settings fall back to 3 when the profile fails', () async {
    final container = ProviderContainer(overrides: [
      currentUserIdProvider.overrideWithValue(null),
      todayWorkoutProvider.overrideWith((ref) async => throw Exception('offline')),
      profileProvider.overrideWith((ref) async => throw Exception('offline')),
    ]);
    addTearDown(container.dispose);
    container.listen(gameSettingsProvider, (_, _) {});
    final settings = await container.read(gameSettingsProvider.future);
    expect((settings.weeklyGoal, settings.userId), (defaultWeeklyGoal, null));
  });

  test('the summary carries quests when signed in', () async {
    final container = _container(userId: 'user-1');
    container.listen(playerSummaryProvider, (_, _) {});
    final summary = await container.read(playerSummaryProvider.future);
    expect(summary.quests!.quests, hasLength(3));
  });
```

`test/features/social/domain/period_stats_test.dart`: `_build`'i `buildPeriodStats(summary: ..., sessions: _sessions, events: xpEvents(_sessions, _meals), exercisesById: ..., now: _now, activeTitleId: null)` yap (`xp_rules.dart` importu ekle) ve şu testi ekle:

```dart
  test('quest XP in the given events counts toward the period', () {
    final base = _build();
    final stats = buildPeriodStats(
      summary: playerSummary(_sessions, _meals, gameExercisesById),
      sessions: _sessions,
      events: [
        ...xpEvents(_sessions, _meals),
        XpEvent(source: XpSource.quest, date: DateTime(2026, 10, 9, 9), xp: 40, label: 'sets'),
      ],
      exercisesById: gameExercisesById,
      now: _now,
      activeTitleId: null,
    );
    expect(stats.week.xp, base.week.xp + 40);
  });
```

- [ ] **Step 2: Testlerin başarısız olduğunu doğrula**

Run: `flutter test --no-pub -j 1 test/features/gamification/application/gamification_providers_test.dart test/features/social/domain/period_stats_test.dart`
Expected: FAIL — `currentUserIdProvider`, `gameSettingsProvider`, `events:` tanımsız.

- [ ] **Step 3: `currentUserIdProvider`**

`auth_providers.dart`'ta `isLoggedInProvider`'dan sonra:

```dart
/// Giriş yapılmış kullanıcının id'si; yoksa null.
final currentUserIdProvider = Provider<String?>((ref) {
  if (!ref.watch(isLoggedInProvider)) return null;
  return AppSupabase.client.auth.currentUser?.id;
});
```

- [ ] **Step 4: `xp_event_providers.dart`**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../notifications/domain/reminder_inputs.dart';
import '../../onboarding/application/auth_providers.dart';
import '../../onboarding/application/profile_providers.dart';
import '../../onboarding/domain/profile.dart';
import '../../progress/application/progress_providers.dart';
import '../../workout/application/muscle_heat_providers.dart';
import '../../workout/application/workout_providers.dart';
import '../../workout/domain/today_workout.dart';
import '../domain/game_settings.dart';
import '../domain/xp_rules.dart';

/// Haftalık hedef (program → profil → 3) ve görev tohumu için kullanıcı (O4 spec §5).
/// Program ya da profil yüklenemezse o kaynak atlanır.
final gameSettingsProvider = FutureProvider.autoDispose<GameSettings>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  final (today, profile) = await (
    ref.watch(todayWorkoutProvider.future).then<TodayWorkout?>((v) => v, onError: (Object _) => null),
    ref.watch(profileProvider.future).then<Profile?>((v) => v, onError: (Object _) => null),
  ).wait;
  return GameSettings(
    weeklyGoal: weeklyGoalFor(
      programDays: today == null ? null : programOf(today)?.effectiveDaysPerWeek,
      profileDays: profile?.exerciseDaysPerWeek,
    ),
    userId: userId,
  );
});

/// Tüm geçmişin XP olayları (seri bonusu + görevler); özet, meydan okuma ve dönem istatistiği paylaşır.
final xpEventsProvider = FutureProvider.autoDispose<List<XpEvent>>((ref) async {
  final (sessions, mealTimes, exercisesById, settings) = await (
    ref.watch(allSessionsProvider.future),
    ref.watch(mealTimesProvider.future),
    ref.watch(exercisesByIdProvider.future),
    ref.watch(gameSettingsProvider.future),
  ).wait;
  return xpEvents(sessions, mealTimes, exercisesById: exercisesById, settings: settings);
});
```

(`allSessionsProvider`, `mealTimesProvider`, `exercisesByIdProvider`'ın tanımlandığı dosyalar `gamification_providers.dart`'taki importlarla aynı; derlenmezse grep ile doğrula. `Profile` sınıfının yolu `lib/features/onboarding/domain/profile.dart`.)

- [ ] **Step 5: Tüketicileri bağla**

`gamification_providers.dart`:

```dart
import '../../workout/application/session_providers.dart';
import 'xp_event_providers.dart';

/// Tüm geçmişten XP, seviye, rütbe, unvanlar (O1 spec §7), meydan okuma ödülleri (S3 spec §3.3),
/// seri ve bu haftanın görevleri (O4 spec §5). Antrenman bitince `allSessionsProvider`, öğün
/// kaydedilince `mealTimesProvider` geçersiz kılınır.
final playerSummaryProvider = FutureProvider.autoDispose<PlayerSummary>((ref) async {
  final (sessions, mealTimes, exercisesById, rewards, settings, events) = await (
    ref.watch(allSessionsProvider.future),
    ref.watch(mealTimesProvider.future),
    ref.watch(exercisesByIdProvider.future),
    ref.watch(challengeRewardsProvider.future),
    ref.watch(gameSettingsProvider.future),
    ref.watch(xpEventsProvider.future),
  ).wait;
  return playerSummary(
    sessions,
    mealTimes,
    exercisesById,
    rewards: rewards,
    settings: settings,
    events: events,
    now: ref.read(nowProvider)(),
  );
});
```

`challenge_providers.dart` — `myChallengeValueProvider`:

```dart
/// Kendi geçmişimden meydan okuma değeri (S3 spec §3.2); XP olayları `xpEventsProvider`'dan.
final myChallengeValueProvider = FutureProvider.autoDispose<double Function(Challenge)>((ref) async {
  final (sessions, exercisesById, events) = await (
    ref.watch(allSessionsProvider.future),
    ref.watch(exercisesByIdProvider.future),
    ref.watch(xpEventsProvider.future),
  ).wait;
  return (challenge) => challengeValue(challenge, sessions, events, exercisesById);
});
```

(`import '../../gamification/application/xp_event_providers.dart';`; `xp_rules.dart` ve `mealTimesProvider` importu artık kullanılmıyorsa analiz uyarısına göre sil.)

`period_stats.dart` — `buildPeriodStats`: `required List<DateTime> mealTimes` yerine `required List<XpEvent> events`, gövdeden `final events = xpEvents(sessions, mealTimes);` satırını sil; belge: `/// XP: [events]'ten (`xpEventsProvider`) tarihi dönemde olanlar. Kas: ...`.

`social_providers.dart` — `statsSyncProvider` bekleme listesine `ref.watch(xpEventsProvider.future)` ekle (`final (summary, sessions, mealTimes, exercisesById, activeTitleId, events) = ...`) ve `buildPeriodStats(..., events: events, ...)` (mealTimes yerine). `import '../../gamification/application/xp_event_providers.dart';`.

- [ ] **Step 6: Diğer sağlayıcı testleri**

`test/features/social/application/social_providers_test.dart` ve `challenge_providers_test.dart` override listelerine ekle (gerçek `gameSettingsProvider` Supabase'e gider):

```dart
    gameSettingsProvider.overrideWith((ref) async => const GameSettings(weeklyGoal: 3)),
```

(importlar: `xp_event_providers.dart`, `game_settings.dart`.)

Run: `flutter test --no-pub -j 1 test/features/gamification test/features/social`
Expected: PASS. Değerler değişen bir test olursa (seri bonusu yok çünkü `userId` null ve tek-iki antrenman <7 gün) nedenini bul; beklentiyi yalnız O4 kuralı gerektiriyorsa güncelle.

- [ ] **Step 7: Tüm paket ve analiz**

Run: `flutter test --no-pub -j 1`
Expected: tümü PASS. `gameSettingsProvider`'ı override etmeyen ve gerçek `playerSummaryProvider`/`xpEventsProvider` okuyan başka test kırılırsa aynı override'ı ekle.

Run: `flutter analyze lib test` → `No issues found!`

- [ ] **Step 8: Commit**

```bash
git add lib test
git commit -m "feat(xp): share one event list with the streak bonus and quests across providers"
```

---

### Task 5: Seviye ekranı — seri ve görev kartları, döküm, kurallar

**Files:**
- Modify: `lib/features/gamification/presentation/widgets/streak_quest_cards.dart`
- Modify: `lib/features/gamification/presentation/level_screen.dart`
- Modify: `assets/translations/tr.json`, `assets/translations/en.json`
- Test: `test/features/gamification/presentation/level_screen_test.dart`

**Interfaces:**
- Consumes: `StreakStatus`, `WeekQuests`, `QuestProgress`, `questText`, `PlayerSummary.streak/quests`, `XpBreakdown.streak/quests`; `periodRemainingLabel(PeriodKind, DateTime)` (`lib/features/social/presentation/widgets/period_widgets.dart`), `PeriodKind` (`period_keys.dart`), `nowProvider`.
- Produces: `class StreakCard extends StatelessWidget { StreakStatus streak; }` (key `level_streak_card`), `class QuestsCard extends StatelessWidget { WeekQuests quests; DateTime now; }` (key `level_quests_card`, satırlar `quest_<index>`).

- [ ] **Step 1: Failing widget testleri yaz**

`level_screen_test.dart` — importlara `streak.dart`, `quests.dart`, `session_providers.dart` (`nowProvider`) ekle. `pump`'ın override listesine `nowProvider.overrideWithValue(() => DateTime(2026, 10, 9, 12)),` ekle. Testler:

```dart
  testWidgets('shows the streak and quest cards', (tester) async {
    await pump(
      tester,
      () async => PlayerSummary(
        totalXp: _summary.totalXp,
        progress: _summary.progress,
        rank: _summary.rank,
        breakdown: const XpBreakdown(streak: 12, quests: 140),
        recent: const [],
        titles: const [],
        upcoming: const [],
        streak: const StreakStatus(length: 14, bonusPercent: 10, restLeft: 2, broken: false),
        quests: WeekQuests(weekStart: DateTime(2026, 10, 5), quests: [
          QuestProgress(kind: QuestKind.workouts, progress: 4, target: 4, doneAt: DateTime(2026, 10, 8)),
          const QuestProgress(kind: QuestKind.muscle, muscle: 'chest', progress: 3, target: 8),
          const QuestProgress(kind: QuestKind.mealDays, progress: 2, target: 5),
        ]),
      ),
    );
    final streak = find.byKey(const Key('level_streak_card'));
    expect(find.descendant(of: streak, matching: find.textContaining('14')), findsWidgets);
    expect(find.descendant(of: streak, matching: find.text('+%10 antrenman XP\'si')), findsOneWidget);
    expect(find.descendant(of: streak, matching: find.text('Bu hafta 2 dinlenme hakkın kaldı')), findsOneWidget);

    final quests = find.byKey(const Key('level_quests_card'));
    expect(find.descendant(of: quests, matching: find.text('4 antrenman yap')), findsOneWidget);
    expect(find.descendant(of: quests, matching: find.text('5 gün öğün kaydet')), findsOneWidget);
    expect(find.descendant(of: find.byKey(const Key('quest_0')), matching: find.byIcon(Icons.check_circle)), findsOneWidget);
    expect(find.descendant(of: quests, matching: find.text('Üçü bitince +60 XP')), findsOneWidget);
    // 9 Ekim 12:00 → pazartesiye 2,5 gün.
    expect(find.descendant(of: quests, matching: find.text('3 gün kaldı')), findsOneWidget);

    final breakdown = find.byKey(const Key('level_breakdown'));
    expect(find.descendant(of: breakdown, matching: find.text('Seri bonusu')), findsOneWidget);
    expect(find.descendant(of: breakdown, matching: find.text('140')), findsOneWidget);
  });

  testWidgets('a broken streak invites a new one; no quests card without quests', (tester) async {
    await pump(tester, () async => playerSummary(const [], const [], const {}));
    expect(find.text('Bugün antrenman yaparak yeni seri başlat'), findsOneWidget);
    expect(find.byKey(const Key('level_quests_card')), findsNothing);
  });

  testWidgets('recent quest and streak rows', (tester) async {
    await pump(
      tester,
      () async => playerSummary(const [], const [], const {}, events: [
        XpEvent(source: XpSource.workout, date: DateTime(2026, 10, 8, 18), xp: 71, label: 'Push A', sets: 3, streakBonus: 6, streakPercent: 10),
        XpEvent(source: XpSource.quest, date: DateTime(2026, 10, 8, 19), xp: 40, label: 'mealDays', target: 5),
        XpEvent(source: XpSource.quest, date: DateTime(2026, 10, 8, 20), xp: 60, label: 'all'),
      ]),
    );
    expect(find.text('3 set · seri +%10'), findsOneWidget);
    expect(find.text('Görev: 5 gün öğün kaydet'), findsOneWidget);
    expect(find.text('Haftalık görevlerin hepsi'), findsOneWidget);
  });
```

Var olan "rules sheet" testi kural sayısını sayıyorsa beklentiyi 9'a çıkar ve şunu ekle:

```dart
    expect(find.textContaining('dinlenme hakkın'), findsOneWidget);
    expect(find.textContaining('üçü bitince +60 XP'), findsOneWidget);
```

- [ ] **Step 2: Testlerin başarısız olduğunu doğrula**

Run: `flutter test --no-pub -j 1 test/features/gamification/presentation/level_screen_test.dart`
Expected: FAIL — kartlar ve çeviriler yok.

- [ ] **Step 3: Çevirileri ekle**

`tr.json`'da `"streak_detail": "seri +%{n}"` satırını:

```json
    "streak_detail": "seri +%{n}",
    "streak_title": "Seri",
    "streak_days": "{n} gün",
    "streak_bonus": "+%{n} antrenman XP'si",
    "streak_bonus_soon": "7. günden itibaren antrenman XP'sine bonus",
    "streak_rest_left": "Bu hafta {n} dinlenme hakkın kaldı",
    "streak_broken": "Bugün antrenman yaparak yeni seri başlat",
    "quests_title": "Haftalık görevler",
    "quests_bonus": "Üçü bitince +60 XP",
    "breakdown_streak": "Seri bonusu",
    "breakdown_quests": "Haftalık görevler",
    "rules_streak": "Seri: antrenman yaptığın ya da dinlenme hakkı kullandığın her gün seriyi uzatır; haftada 7 − hedef gün dinlenme hakkın var. Her 7 gün antrenman XP'sine %5 ekler, en çok %25.",
    "rules_quests": "Her hafta 3 görev: her biri 40 XP, üçü bitince +60 XP."
```

`en.json`'da `"streak_detail": "streak +{n}%"` satırını:

```json
    "streak_detail": "streak +{n}%",
    "streak_title": "Streak",
    "streak_days": "{n} days",
    "streak_bonus": "+{n}% workout XP",
    "streak_bonus_soon": "Workout XP bonus from day 7",
    "streak_rest_left": "{n} rest days left this week",
    "streak_broken": "Work out today to start a new streak",
    "quests_title": "Weekly quests",
    "quests_bonus": "+60 XP when all three are done",
    "breakdown_streak": "Streak bonus",
    "breakdown_quests": "Weekly quests",
    "rules_streak": "Streak: every day you work out or use a rest day extends it; you get 7 − goal rest days a week. Every 7 days adds 5% to workout XP, up to 25%.",
    "rules_quests": "3 quests every week: 40 XP each, +60 XP when all three are done."
```

- [ ] **Step 4: Kartları yaz**

`streak_quest_cards.dart`'a importları ve kartları ekle (dosyanın başındaki importlar):

```dart
import 'dart:math' as math;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../social/domain/period_keys.dart';
import '../../../social/presentation/widgets/period_widgets.dart';
import '../../../workout/domain/exercise_taxonomy.dart';
import '../../domain/quests.dart';
import '../../domain/streak.dart';
```

```dart
/// Alev + gün, bonus, dinlenme hakkı (O4 spec §6).
class StreakCard extends StatelessWidget {
  const StreakCard({super.key, required this.streak});

  final StreakStatus streak;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final muted = theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant);
    return Card(
      key: const Key('level_streak_card'),
      margin: const EdgeInsets.only(top: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.local_fire_department, size: 40, color: streak.broken ? scheme.onSurfaceVariant : scheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${'gamification.streak_title'.tr()} · ${'gamification.streak_days'.tr(namedArgs: {'n': '${streak.length}'})}',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  if (streak.broken)
                    Text('gamification.streak_broken'.tr(), style: muted)
                  else ...[
                    Text(
                      streak.bonusPercent > 0
                          ? 'gamification.streak_bonus'.tr(namedArgs: {'n': '${streak.bonusPercent}'})
                          : 'gamification.streak_bonus_soon'.tr(),
                      style: theme.textTheme.bodyMedium?.copyWith(color: scheme.primary, fontWeight: FontWeight.w700),
                    ),
                    Text('gamification.streak_rest_left'.tr(namedArgs: {'n': '${streak.restLeft}'}), style: muted),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bu haftanın 3 görevi, ilerleme çubukları, bonus ve kalan süre (O4 spec §6).
class QuestsCard extends StatelessWidget {
  const QuestsCard({super.key, required this.quests, required this.now});

  final WeekQuests quests;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final muted = theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant);
    return Card(
      key: const Key('level_quests_card'),
      margin: const EdgeInsets.only(top: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'gamification.quests_title'.tr(),
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
                Text(periodRemainingLabel(PeriodKind.week, now), style: muted),
              ],
            ),
            for (final (index, quest) in quests.quests.indexed)
              Padding(
                key: Key('quest_$index'),
                padding: const EdgeInsets.only(top: 12),
                child: Row(
                  children: [
                    Icon(
                      quest.done ? Icons.check_circle : Icons.radio_button_unchecked,
                      color: quest.done ? scheme.primary : scheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(questText(quest.kind, target: quest.target, muscle: quest.muscle)),
                          const SizedBox(height: 6),
                          LinearProgressIndicator(
                            value: quest.target <= 0 ? 1 : math.min(1, quest.progress / quest.target),
                            borderRadius: const BorderRadius.all(Radius.circular(4)),
                          ),
                          const SizedBox(height: 2),
                          Text('${_number(math.min(quest.progress, quest.target))} / ${_number(quest.target)}', style: muted),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'gamification.xp_gain'.tr(namedArgs: {'n': '$xpPerQuest'}),
                      style: theme.textTheme.labelMedium?.copyWith(color: scheme.primary, fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 12),
            Text(
              'gamification.quests_bonus'.tr(),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: quests.bonusDone ? scheme.primary : scheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 3.0 → "3", 14.5 → "14.5".
  static String _number(double x) => x == x.roundToDouble() ? '${x.toInt()}' : x.toStringAsFixed(1);
}
```

- [ ] **Step 5: Seviye ekranını bağla**

`level_screen.dart`: importlara `'../../workout/application/session_providers.dart'` (`nowProvider`; zaten varsa atla) ekle. `ListView` çocuklarında `_Header(...)`'dan hemen sonra:

```dart
                StreakCard(streak: summary.streak),
                if (summary.quests case final quests?) QuestsCard(quests: quests, now: ref.read(nowProvider)()),
```

`_Breakdown`'da üçüncü satırı şununla değiştir ve dördüncü satırı ekle:

```dart
        Row(
          children: [
            tile(Icons.flag_outlined, 'gamification.breakdown_challenges'.tr(), breakdown.challenges),
            const SizedBox(width: 12),
            tile(Icons.local_fire_department_outlined, 'gamification.breakdown_streak'.tr(), breakdown.streak),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            tile(Icons.task_alt, 'gamification.breakdown_quests'.tr(), breakdown.quests),
            const SizedBox(width: 12),
            const Expanded(child: SizedBox()),
          ],
        ),
```

`_RulesSheet._rules` listesinin sonuna `'rules_streak', 'rules_quests',` ekle; sınıf belgesine "seri ve görevler (O4 spec §6)" ekle.

- [ ] **Step 6: Testleri geçir**

Run: `flutter test --no-pub -j 1 test/features/gamification/presentation`
Expected: PASS. "140" iki yerde çıkıyorsa (ör. toplam XP) beklentiyi `find.descendant` ile döküm kartına daralttığından emin ol.

- [ ] **Step 7: Commit**

```bash
git add lib/features/gamification assets/translations test/features/gamification
git commit -m "feat(level): show the streak and weekly quest cards"
```

---

### Task 6: Ana sayfa seri hapı

**Files:**
- Create: `lib/features/gamification/presentation/widgets/home_streak_chip.dart`
- Modify: `lib/features/onboarding/presentation/home_screen.dart`
- Test: `test/features/gamification/presentation/home_streak_chip_test.dart`

**Interfaces:**
- Consumes: `playerSummaryProvider`, `PlayerSummary.streak/quests`.
- Produces: `class HomeStreakChip extends ConsumerWidget` (key `home_streak_chip`).

- [ ] **Step 1: Failing widget testi yaz**

`test/features/gamification/presentation/home_streak_chip_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spor_takip/features/gamification/application/gamification_providers.dart';
import 'package:spor_takip/features/gamification/domain/player_summary.dart';
import 'package:spor_takip/features/gamification/domain/quests.dart';
import 'package:spor_takip/features/gamification/domain/streak.dart';
import 'package:spor_takip/features/gamification/presentation/widgets/home_streak_chip.dart';

import '../../progress/presentation/test_app.dart';

PlayerSummary _summary({StreakStatus streak = StreakStatus.none, WeekQuests? quests}) {
  final base = playerSummary(const [], const [], const {});
  return PlayerSummary(
    totalXp: base.totalXp,
    progress: base.progress,
    rank: base.rank,
    breakdown: base.breakdown,
    recent: base.recent,
    titles: base.titles,
    upcoming: base.upcoming,
    streak: streak,
    quests: quests,
  );
}

final _quests = WeekQuests(weekStart: DateTime(2026, 10, 5), quests: [
  QuestProgress(kind: QuestKind.workouts, progress: 3, target: 3, doneAt: DateTime(2026, 10, 7)),
  const QuestProgress(kind: QuestKind.record, progress: 0, target: 1),
  const QuestProgress(kind: QuestKind.mealDays, progress: 1, target: 5),
]);

void main() {
  setUpAll(initTestLocalization);

  Future<void> pump(WidgetTester tester, PlayerSummary summary) async {
    await tester.pumpWidget(testApp(
      const HomeStreakChip(),
      overrides: [playerSummaryProvider.overrideWith((ref) async => summary)],
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('shows the streak and done quests', (tester) async {
    await pump(tester, _summary(streak: const StreakStatus(length: 12, bonusPercent: 5, restLeft: 1, broken: false), quests: _quests));
    expect(find.byKey(const Key('home_streak_chip')), findsOneWidget);
    expect(find.text('12'), findsOneWidget);
    expect(find.text('1/3'), findsOneWidget);
  });

  testWidgets('only the quest count when the streak is 0', (tester) async {
    await pump(tester, _summary(quests: _quests));
    expect(find.byIcon(Icons.local_fire_department), findsNothing);
    expect(find.text('1/3'), findsOneWidget);
  });

  testWidgets('hidden with neither a streak nor quests', (tester) async {
    await pump(tester, _summary());
    expect(find.byKey(const Key('home_streak_chip')), findsNothing);
  });
}
```

(`testApp`'in imzasını `test/features/progress/presentation/test_app.dart`'tan doğrula; `scaffold` varsayılanı widget'ı bir `Scaffold` içine koyar.)

- [ ] **Step 2: Testin başarısız olduğunu doğrula**

Run: `flutter test --no-pub -j 1 test/features/gamification/presentation/home_streak_chip_test.dart`
Expected: FAIL — `home_streak_chip.dart` yok.

- [ ] **Step 3: Hapı yaz**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../application/gamification_providers.dart';

/// Ana sayfa AppBar'ında seri + biten görev hapı; dokununca seviye ekranı (O4 spec §6).
/// Özet yüklenirken, hatada ya da seri ve görev yokken görünmez.
class HomeStreakChip extends ConsumerWidget {
  const HomeStreakChip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(playerSummaryProvider).value;
    final streak = summary?.streak.length ?? 0;
    final quests = summary?.quests;
    if (summary == null || (streak == 0 && quests == null)) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final style = theme.textTheme.labelLarge?.copyWith(color: scheme.primary, fontWeight: FontWeight.w800);
    const shape = StadiumBorder();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Material(
        color: scheme.primary.withValues(alpha: 0.1),
        shape: shape.copyWith(side: BorderSide(color: scheme.primary.withValues(alpha: 0.5))),
        child: InkWell(
          key: const Key('home_streak_chip'),
          customBorder: shape,
          onTap: () => context.push('/home/levels'),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (streak > 0) ...[
                  Icon(Icons.local_fire_department, size: 16, color: scheme.primary),
                  const SizedBox(width: 2),
                  Text('$streak', style: style),
                ],
                if (streak > 0 && quests != null) Text(' · ', style: style),
                if (quests != null) Text('${quests.quests.where((q) => q.done).length}/${quests.quests.length}', style: style),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
```

`home_screen.dart` `actions`'ta `const HomeLevelBadge(),`'dan sonra:

```dart
          const SizedBox(width: 6),
          const HomeStreakChip(),
```

(import: `'../../gamification/presentation/widgets/home_streak_chip.dart'`.)

- [ ] **Step 4: Testleri geçir**

Run: `flutter test --no-pub -j 1 test/features/gamification/presentation/home_streak_chip_test.dart test/features/onboarding/presentation/home_screen_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/gamification/presentation/widgets/home_streak_chip.dart lib/features/onboarding/presentation/home_screen.dart test/features/gamification/presentation/home_streak_chip_test.dart
git commit -m "feat(home): add the streak and quest chip"
```

---

### Task 7: Doğrulama, PLAN.md, elle kontrol, birleştirme

**Files:**
- Modify: `PLAN.md`

- [ ] **Step 1: Tam paket ve analiz** (düşük bellekli makine: kullanıcının terminalinde)

Run: `flutter test --no-pub -j 1` → tümü PASS (sayıyı not et).
Run: `flutter analyze lib test` → `No issues found!`

- [ ] **Step 2: Elle kontrol (web release, kullanıcının terminalinde `flutter build web --release` + sunucu)**

1. Ana sayfada seviye rozetinin yanında hap: seri > 0 ise alev + gün, görev "x/3"; dokununca Seviye ekranı.
2. Seviye ekranı: seri kartı (gün, bonus ya da "7. günden itibaren", dinlenme hakkı); görev kartı (3 satır, çubuk, +40 XP, kalan süre, "Üçü bitince +60 XP").
3. Bir görevi bitirecek antrenman/öğün kaydet → görev tik alır, XP geçmişinde "Görev: …" satırı, toplam XP +40.
4. Döküm: "Seri bonusu" ve "Haftalık görevler" kutuları; kurallar sayfasında iki yeni madde.
5. Dil İngilizce → tüm yeni metinler İngilizce; 360 px genişlikte AppBar taşmıyor.

- [ ] **Step 3: PLAN.md**

`PLAN.md` ilerleme tablosuna O3a satırının biçimiyle bir O4 satırı ekle (tarih, dal `o4-seri-gorevler`, 7 görev, özet: dinlenme hakkıyla günlük seri, %5/7 gün en çok %25 antrenman XP bonusu, havuzdan haftada 3 belirlenimli görev 40 XP + 60 bonus, ana sayfa hapı ve Seviye ekranı kartları, migration yok, test sayısı, elle kontrol sonucu, "Sıradaki: O2").

```bash
git add PLAN.md
git commit -m "docs: record O4 in the plan"
```

- [ ] **Step 4: Birleştir** — superpowers:finishing-a-development-branch.
