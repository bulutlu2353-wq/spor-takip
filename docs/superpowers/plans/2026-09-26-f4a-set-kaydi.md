# F4a — Antrenman ve Set Kaydı Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Kullanıcının programdaki bir antrenmanı başlatıp setleri (kilo + tekrar) anında sunucuya kaydederek yapabildiği, dinlenme sayacı, otomatik ağırlık önerisi (artış / aynı / %10 düşüş), bitişte AMRAP'e göre 1RM önerisi ve geçmiş listesi olan uçtan uca bir dikey dilim.

**Architecture:** Server-first: `start_session` RPC oturumu ve planın kopyası olan `session_sets` satırlarını tek transaction'da yazar; set işaretleme/düzeltme tablolara doğrudan update'tir; `finish_session` RPC oturumu kapatır, rotasyonu ilerletir ve onaylanan 1RM'leri yazar. Kilo önerileri ve 1RM önerileri saf Dart fonksiyonlarıdır (`progression.dart`). Antrenman ekranı alt menü dışında tam ekran bir rotadır (`/session/:id`).

**Tech Stack:** Flutter + Riverpod 3 (`AsyncNotifierProvider.autoDispose.family`) + go_router 18 + supabase_flutter 2.17 (postgrest 2.9) + easy_localization (mevcut yığın, yeni paket yok). Backend: Postgres (Supabase) plpgsql fonksiyonları.

**Spec:** `docs/superpowers/specs/2026-09-26-f4a-set-kaydi-design.md`

## Global Constraints

- Tüm yeni tablolarda Supabase RLS zorunlu; kullanıcı yalnızca kendi oturumlarını ve setlerini görür/yazar (spec §3).
- Her iki RPC `security invoker`, tek transaction (spec §3).
- Kullanıcı başına en fazla bir devam eden oturum (kısmi unique index) (spec §3).
- Kilo önerileri en yakın 2,5 kg'a yuvarlanır; alt vücut halter hareketi +5 kg, diğerleri +2,5 kg; 3 başarısız oturumda ×0,9 (spec §4.1).
- 1RM önerisi tablosu: hedefin altı ×0,9; 0 fazla → öneri yok; 1–2 → +2,5; 3–4 → +5; ≥5 → +7,5 kg; sonuç 2,5 kg'a yuvarlanır (spec §4.3).
- Dinlenme varsayılanı 90 sn; eklenen hareket 3 set × 8–12, dinlenme 90 sn (spec §5.2).
- Hareket adları İngilizce kalır; tüm diğer UI metinleri `assets/translations/tr.json` + `en.json`'a eklenir.
- Supabase'e dokunan repository sınıfları doğrudan unit test edilmez; iş mantığı fake repository ile test edilir; SQL Task 12'de kullanıcıyla SQL Editor'da doğrulanır.
- Widget testlerinde `.tr()` çıktısına güvenilmez; bulma `Key`, ikon veya veri metni (hareket/antrenman adı, sayılar) ile yapılır.
- Oturum ekranı veya sayaç içeren widget testlerinde `clockProvider` **her zaman** `Stream.value(sabit)` ile, `nowProvider` sabit bir fonksiyonla override edilir (aksi halde periyodik stream `pumpAndSettle`'ı kilitler).
- `flutter analyze` "No issues found!" vermeli (info dahil): her `await`'ten sonra `context` kullanmadan önce `context.mounted` / `mounted` kontrolü.
- Tüm işler `f4a-set-kaydi` dalında yapılır.
- Düşük bellekli makine: `flutter test` tam paket ~9 dk sürer; görev içinde yalnızca ilgili test dosyaları, görev sonunda tam paket.

## Spec'ten Bilinçli Sapmalar (plan yazımında ortaya çıktı)

1. **`session_sets.deloaded boolean`:** "3 kez başarısız, kilo düşürüldü" notunun sayfa yenilendikten sonra da görünmesi için öneriyle birlikte saklanır.
2. **Oturum rotaları `/session/:id`, `/session/:id/summary`, `/session/:id/exercises`** (spec'te `/workout/session/:id`): alt menü dışında tam ekran; ana ekrandan ve program detayından sekme değiştirmeden açılır. Hareket seçici bu rotada ikinci kez tanımlanır (shell içindeki `/workout/exercises`'a shell dışından push etmemek için).
3. **Geçmişe giriş:** Programlar ekranının AppBar'ında geçmiş ikonu (`/workout/history`) — spec'teki "bölüm/sekme" yerine en az değişiklikle.
4. **`finish_session` parametre adları `p_session_id`, `p_one_rep_maxes`:** plpgsql'de sütun adlarıyla çakışmayı önlemek için.

## Dosya Haritası

```
supabase/migrations/
  0008_create_workout_sessions.sql      # şema + RLS + start_session + finish_session (Task 1)
  checks/f4a_rls_checks.sql             # Task 12 elle doğrulama betiği
lib/features/workout/
  domain/  workout_session.dart (WorkoutSession, SessionSet)          (Task 2)
           session_stats.dart (sayım, hacim, süre, biçim)              (Task 2)
           block_format.dart  (değişir: trimNumber, sessionSetTargetLabel) (Task 2)
           weight_calculator.dart (değişir: roundToPlate)              (Task 3)
           progression.dart (kilo + 1RM önerileri)                     (Task 3)
           session_builder.dart (program antrenmanı → setler)          (Task 4)
  data/    session_repository.dart                                     (Task 5)
  application/ session_providers.dart (repo, in-progress, geçmiş, saat) (Task 5)
               start_session_service.dart                              (Task 6)
               session_notifier.dart, rest_timer.dart                  (Task 7)
  presentation/ session_screen.dart, widgets/set_row.dart,
                widgets/rest_timer_bar.dart                            (Task 8)
                session_summary_screen.dart                            (Task 9)
                history_screen.dart, history_detail_screen.dart        (Task 10)
                start_workout.dart; today_workout_card.dart,
                program_detail_screen.dart (değişir)                   (Task 11)
                programs_screen.dart (değişir: geçmiş ikonu)           (Task 10)
lib/core/router.dart                                                   (Task 8, 9, 10)
test/features/workout/fakes.dart  (FakeSessionRepository eklenir)      (Task 5)
```

---

## Task 1: Veritabanı şeması ve RPC'ler — `0008`

**Files:**
- Create: `supabase/migrations/0008_create_workout_sessions.sql`

**Interfaces:**
- Produces: tablolar `public.workout_sessions`, `public.session_sets`; `public.start_session(payload jsonb) returns uuid`; `public.finish_session(p_session_id uuid, p_one_rep_maxes jsonb) returns void`. `start_session` payload: `{program_id, program_name, workout_name, workout_position, sets: [{exercise_position, set_index, exercise_id, target_reps_min, target_reps_max, is_amrap, percent_1rm, percent_ref_exercise_id, rest_seconds, suggested_weight_kg, deloaded}]}`. `p_one_rep_maxes`: `[{exercise_id, weight_kg}]`. İkinci devam eden oturumda `unique_violation` (SQLSTATE `23505`).

SQL bu görevde otomatik test edilmez (bkz. Global Constraints); Task 12'de kullanıcıyla doğrulanır.

- [ ] **Step 1: Migration'ı yaz**

`supabase/migrations/0008_create_workout_sessions.sql`:

```sql
-- F4a: antrenman oturumları ve set kayıtları.

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

create index if not exists workout_sessions_user_finished
  on public.workout_sessions (user_id, finished_at desc);

create table if not exists public.session_sets (
  id uuid primary key default gen_random_uuid(),
  session_id uuid not null references public.workout_sessions (id) on delete cascade,
  exercise_position int not null,
  set_index int not null,
  exercise_id text not null references public.exercises (id) on delete restrict,
  target_reps_min int not null check (target_reps_min > 0),
  target_reps_max int not null check (target_reps_max >= target_reps_min),
  is_amrap boolean not null default false,
  percent_1rm numeric check (percent_1rm > 0 and percent_1rm <= 100),
  percent_ref_exercise_id text references public.exercises (id) on delete restrict,
  rest_seconds int check (rest_seconds >= 0),
  suggested_weight_kg numeric check (suggested_weight_kg >= 0),
  deloaded boolean not null default false,  -- öneri 3 başarısızlık sonrası düşürüldü
  weight_kg numeric check (weight_kg >= 0),
  reps int check (reps >= 0),
  completed_at timestamptz,                 -- null = henüz yapılmadı
  unique (session_id, exercise_position, set_index)
);

create index if not exists session_sets_exercise on public.session_sets (exercise_id);

alter table public.workout_sessions enable row level security;
alter table public.session_sets enable row level security;

create policy "Users can manage own sessions"
  on public.workout_sessions for all
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

create policy "Users can manage sets of own sessions"
  on public.session_sets for all
  using (exists (
    select 1 from public.workout_sessions s where s.id = session_id and s.user_id = auth.uid()
  ))
  with check (exists (
    select 1 from public.workout_sessions s where s.id = session_id and s.user_id = auth.uid()
  ));

-- Oturumu ve planın kopyası olan setleri tek transaction'da yazar.
-- Devam eden oturum varken kısmi unique index nedeniyle unique_violation verir.
create or replace function public.start_session(payload jsonb)
returns uuid
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_id uuid;
  s jsonb;
begin
  if auth.uid() is null then
    raise exception 'not authenticated';
  end if;

  insert into workout_sessions (user_id, program_id, program_name, workout_name, workout_position)
  values (
    auth.uid(), (payload->>'program_id')::uuid, payload->>'program_name',
    payload->>'workout_name', (payload->>'workout_position')::int
  )
  returning id into v_id;

  for s in select value from jsonb_array_elements(coalesce(payload->'sets', '[]'::jsonb)) loop
    insert into session_sets (session_id, exercise_position, set_index, exercise_id,
                              target_reps_min, target_reps_max, is_amrap, percent_1rm,
                              percent_ref_exercise_id, rest_seconds, suggested_weight_kg, deloaded)
    values (
      v_id, (s->>'exercise_position')::int, (s->>'set_index')::int, s->>'exercise_id',
      (s->>'target_reps_min')::int, (s->>'target_reps_max')::int,
      coalesce((s->>'is_amrap')::boolean, false), (s->>'percent_1rm')::numeric,
      s->>'percent_ref_exercise_id', (s->>'rest_seconds')::int,
      (s->>'suggested_weight_kg')::numeric, coalesce((s->>'deloaded')::boolean, false)
    );
  end loop;

  return v_id;
end;
$$;

-- Oturumu kapatır; programı aktif ve rotasyon modundaysa sırayı ilerletir;
-- onaylanan 1RM'leri upsert eder. Hepsi ya uygulanır ya hiçbiri.
create or replace function public.finish_session(p_session_id uuid, p_one_rep_maxes jsonb)
returns void
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_session workout_sessions;
  r jsonb;
begin
  if auth.uid() is null then
    raise exception 'not authenticated';
  end if;

  select * into v_session from workout_sessions
  where id = p_session_id and user_id = auth.uid() and finished_at is null
  for update;
  if not found then
    raise exception 'session not found or already finished';
  end if;

  update workout_sessions set finished_at = now() where id = p_session_id;

  update profiles p
  set next_rotation_position = v_session.workout_position + 1
  from programs pr
  where p.user_id = auth.uid()
    and p.active_program_id = v_session.program_id
    and pr.id = v_session.program_id
    and pr.schedule_mode = 'rotation';

  for r in select value from jsonb_array_elements(coalesce(p_one_rep_maxes, '[]'::jsonb)) loop
    insert into user_one_rep_maxes (user_id, exercise_id, weight_kg, updated_at)
    values (auth.uid(), r->>'exercise_id', (r->>'weight_kg')::numeric, now())
    on conflict (user_id, exercise_id)
    do update set weight_kg = excluded.weight_kg, updated_at = excluded.updated_at;
  end loop;
end;
$$;
```

- [ ] **Step 2: Commit**

```bash
git add supabase/migrations/0008_create_workout_sessions.sql
git commit -m "feat(workout): add workout session schema, RLS and start/finish functions"
```

---

## Task 2: Oturum domain modelleri, istatistikler ve hedef etiketi

**Files:**
- Create: `lib/features/workout/domain/workout_session.dart`, `lib/features/workout/domain/session_stats.dart`
- Modify: `lib/features/workout/domain/block_format.dart`
- Test: `test/features/workout/domain/workout_session_test.dart`, `test/features/workout/domain/session_stats_test.dart`, `test/features/workout/domain/block_format_test.dart` (eklenir)

**Interfaces:**
- Produces:
  - `class SessionSet` — alanlar: `String? id, int exercisePosition, int setIndex, String exerciseId, String exerciseName, int targetRepsMin, int targetRepsMax, bool isAmrap, double? percent1rm, String? percentRefExerciseId, int? restSeconds, double? suggestedWeightKg, bool deloaded, double? weightKg, int? reps, DateTime? completedAt`; getter'lar `isCompleted`, `oneRepMaxExerciseId`, `hitTarget`, `displayWeightKg`, `displayReps`; `SessionSet.fromJson`, `Map<String, dynamic> toInsertJson()`, `copyWith({String? id, double? weightKg, bool clearWeight, int? reps, bool clearReps, DateTime? completedAt, bool clearCompletedAt})`.
  - `class WorkoutSession` — alanlar: `String id, String? programId, String programName, String workoutName, int workoutPosition, DateTime startedAt, DateTime? finishedAt, List<SessionSet> sets`; `isInProgress`, `List<List<SessionSet>> exerciseGroups`, `int nextExercisePosition`, `SessionSet setById(String id)`, `WorkoutSession replaceSet(SessionSet)`, `WorkoutSession copyWith({DateTime? finishedAt, List<SessionSet>? sets})`, `WorkoutSession.fromJson`.
  - `session_stats.dart`: `int completedSetCount(WorkoutSession)`, `double totalVolumeKg(WorkoutSession)`, `Duration sessionDuration(WorkoutSession, DateTime now)`, `String formatDuration(Duration)`.
  - `block_format.dart`: `String trimNumber(double)` (eski özel `_trim`), `String sessionSetTargetLabel(SessionSet)`.

- [ ] **Step 1: Başarısız testleri yaz**

`test/features/workout/domain/workout_session_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:spor_takip/features/workout/domain/workout_session.dart';

Map<String, dynamic> _setJson(
  String id, {
  required int position,
  required int index,
  String exercise = 'Barbell_Squat',
  String name = 'Barbell Squat',
  Object? weight,
  Object? reps,
  String? completedAt,
  Object? percent,
}) {
  return {
    'id': id,
    'session_id': 's1',
    'exercise_position': position,
    'set_index': index,
    'exercise_id': exercise,
    'exercises': {'name': name},
    'target_reps_min': 5,
    'target_reps_max': 5,
    'is_amrap': false,
    'percent_1rm': percent,
    'percent_ref_exercise_id': null,
    'rest_seconds': 180,
    'suggested_weight_kg': 60,
    'deloaded': false,
    'weight_kg': weight,
    'reps': reps,
    'completed_at': completedAt,
  };
}

SessionSet _set({
  String id = 'x',
  int min = 5,
  int max = 5,
  bool amrap = false,
  double? suggested,
  double? weight,
  int? reps,
  bool done = false,
}) {
  return SessionSet(
    id: id,
    exercisePosition: 0,
    setIndex: 0,
    exerciseId: 'Barbell_Squat',
    exerciseName: 'Barbell Squat',
    targetRepsMin: min,
    targetRepsMax: max,
    isAmrap: amrap,
    suggestedWeightKg: suggested,
    weightKg: weight,
    reps: reps,
    completedAt: done ? DateTime(2026, 9, 26, 10, 5) : null,
  );
}

void main() {
  test('fromJson parses the session and sorts sets by exercise and set order', () {
    final session = WorkoutSession.fromJson({
      'id': 's1',
      'user_id': 'user-1',
      'program_id': 'p1',
      'program_name': 'StrongLifts 5x5',
      'workout_name': 'Antrenman A',
      'workout_position': 1,
      'started_at': '2026-09-26T10:00:00+00:00',
      'finished_at': null,
      'session_sets': [
        _setJson('b', position: 1, index: 0, exercise: 'Bench', name: 'Bench Press'),
        _setJson('a2', position: 0, index: 1, weight: 60, reps: 5,
            completedAt: '2026-09-26T10:05:00+00:00', percent: 85.5),
        _setJson('a1', position: 0, index: 0),
      ],
    });

    expect(session.id, 's1');
    expect(session.programId, 'p1');
    expect(session.workoutPosition, 1);
    expect(session.isInProgress, isTrue);
    expect(session.sets.map((s) => s.id), ['a1', 'a2', 'b']);
    expect(session.exerciseGroups.map((g) => g.length), [2, 1]);
    expect(session.sets[2].exerciseName, 'Bench Press');
    expect(session.sets[1].isCompleted, isTrue);
    expect(session.sets[1].weightKg, 60);
    expect(session.sets[1].percent1rm, 85.5);
    expect(session.sets[0].suggestedWeightKg, 60);
    expect(session.sets[0].restSeconds, 180);
    expect(session.nextExercisePosition, 2);
    expect(session.setById('b').exerciseId, 'Bench');
  });

  test('a finished session without sets', () {
    final session = WorkoutSession.fromJson({
      'id': 's2',
      'program_id': null,
      'program_name': 'Silinmiş',
      'workout_name': 'A',
      'workout_position': 0,
      'started_at': '2026-09-26T10:00:00+00:00',
      'finished_at': '2026-09-26T11:00:00+00:00',
    });
    expect(session.isInProgress, isFalse);
    expect(session.programId, isNull);
    expect(session.sets, isEmpty);
    expect(session.exerciseGroups, isEmpty);
    expect(session.nextExercisePosition, 0);
  });

  test('toInsertJson carries the plan but not the results', () {
    final json = const SessionSet(
      exercisePosition: 2,
      setIndex: 1,
      exerciseId: 'Sumo_Deadlift',
      exerciseName: 'Sumo Deadlift',
      targetRepsMin: 3,
      targetRepsMax: 3,
      isAmrap: true,
      percent1rm: 70,
      percentRefExerciseId: 'Barbell_Deadlift',
      restSeconds: 120,
      suggestedWeightKg: 100,
      deloaded: true,
    ).toInsertJson();

    expect(json, {
      'exercise_position': 2,
      'set_index': 1,
      'exercise_id': 'Sumo_Deadlift',
      'target_reps_min': 3,
      'target_reps_max': 3,
      'is_amrap': true,
      'percent_1rm': 70.0,
      'percent_ref_exercise_id': 'Barbell_Deadlift',
      'rest_seconds': 120,
      'suggested_weight_kg': 100.0,
      'deloaded': true,
    });
  });

  test('display values fall back to the suggestion and the top of the range', () {
    expect(_set(suggested: 60).displayWeightKg, 60);
    expect(_set(suggested: 60, weight: 65).displayWeightKg, 65);
    expect(_set(min: 8, max: 12).displayReps, 12);
    expect(_set(amrap: true).displayReps, isNull);
    expect(_set(reps: 7).displayReps, 7);
  });

  test('hitTarget: top of range for normal sets, bottom for AMRAP', () {
    expect(_set(min: 8, max: 12, reps: 12, done: true).hitTarget, isTrue);
    expect(_set(min: 8, max: 12, reps: 11, done: true).hitTarget, isFalse);
    expect(_set(amrap: true, reps: 5, done: true).hitTarget, isTrue);
    expect(_set(amrap: true, reps: 4, done: true).hitTarget, isFalse);
    expect(_set(reps: 5).hitTarget, isFalse, reason: 'not completed');
  });

  test('copyWith and replaceSet', () {
    final set = _set(id: 'a', weight: 60, reps: 5, done: true);
    final cleared = set.copyWith(clearCompletedAt: true, clearWeight: true);
    expect(cleared.isCompleted, isFalse);
    expect(cleared.weightKg, isNull);
    expect(cleared.reps, 5);
    expect(set.copyWith(id: 'b').id, 'b');

    final session = WorkoutSession(
      id: 's',
      programName: 'P',
      workoutName: 'A',
      workoutPosition: 0,
      startedAt: DateTime(2026, 9, 26, 10),
      sets: [set, _set(id: 'c')],
    );
    final replaced = session.replaceSet(cleared);
    expect(replaced.setById('a').isCompleted, isFalse);
    expect(replaced.sets.length, 2);
    expect(session.copyWith(finishedAt: DateTime(2026, 9, 26, 11)).isInProgress, isFalse);
  });
}
```

`test/features/workout/domain/session_stats_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:spor_takip/features/workout/domain/session_stats.dart';
import 'package:spor_takip/features/workout/domain/workout_session.dart';

SessionSet _set(String id, {double? weight, int? reps, bool done = true}) {
  return SessionSet(
    id: id,
    exercisePosition: 0,
    setIndex: 0,
    exerciseId: 'Barbell_Squat',
    exerciseName: 'Barbell Squat',
    targetRepsMin: 5,
    targetRepsMax: 5,
    weightKg: weight,
    reps: reps,
    completedAt: done ? DateTime(2026, 9, 26, 10, 5) : null,
  );
}

WorkoutSession _session(List<SessionSet> sets, {DateTime? finishedAt}) {
  return WorkoutSession(
    id: 's',
    programName: 'P',
    workoutName: 'A',
    workoutPosition: 0,
    startedAt: DateTime(2026, 9, 26, 10),
    finishedAt: finishedAt,
    sets: sets,
  );
}

void main() {
  final session = _session([
    _set('a', weight: 60, reps: 5),
    _set('b', weight: 60, reps: 5),
    _set('c', reps: 10), // vücut ağırlığı
    _set('d', weight: 60, reps: 5, done: false),
  ]);

  test('counts completed sets', () {
    expect(completedSetCount(session), 3);
  });

  test('volume sums weight × reps of completed weighted sets', () {
    expect(totalVolumeKg(session), 600);
  });

  test('duration uses finishedAt, else now; never negative', () {
    expect(
      sessionDuration(_session([], finishedAt: DateTime(2026, 9, 26, 10, 45)), DateTime(2026, 9, 26, 12)),
      const Duration(minutes: 45),
    );
    expect(sessionDuration(session, DateTime(2026, 9, 26, 10, 30)), const Duration(minutes: 30));
    expect(sessionDuration(session, DateTime(2026, 9, 26, 9)), Duration.zero);
  });

  test('formatDuration', () {
    expect(formatDuration(const Duration(seconds: 90)), '01:30');
    expect(formatDuration(const Duration(minutes: 30)), '30:00');
    expect(formatDuration(const Duration(hours: 1, minutes: 5, seconds: 3)), '1:05:03');
  });
}
```

`test/features/workout/domain/block_format_test.dart` dosyasının **sonuna** (son `}`'ten önce, `main` içine) ekle; dosyanın başına `import 'package:spor_takip/features/workout/domain/workout_session.dart';` ekle:

```dart
  test('trimNumber drops a trailing .0', () {
    expect(trimNumber(60), '60');
    expect(trimNumber(57.5), '57.5');
  });

  test('sessionSetTargetLabel', () {
    SessionSet target({int min = 5, int max = 5, bool amrap = false, double? pct}) => SessionSet(
          exercisePosition: 0,
          setIndex: 0,
          exerciseId: 'x',
          exerciseName: 'x',
          targetRepsMin: min,
          targetRepsMax: max,
          isAmrap: amrap,
          percent1rm: pct,
        );
    expect(sessionSetTargetLabel(target()), '5');
    expect(sessionSetTargetLabel(target(min: 8, max: 12)), '8–12');
    expect(sessionSetTargetLabel(target(amrap: true, pct: 85)), '5+ · %85');
    expect(sessionSetTargetLabel(target(pct: 76.5)), '5 · %76.5');
  });
```

- [ ] **Step 2: Testlerin başarısız olduğunu doğrula**

Run: `flutter test test/features/workout/domain/workout_session_test.dart test/features/workout/domain/session_stats_test.dart test/features/workout/domain/block_format_test.dart`
Expected: FAIL — `workout_session.dart`, `session_stats.dart` yok; `trimNumber`, `sessionSetTargetLabel` tanımsız.

- [ ] **Step 3: Modelleri yaz**

`lib/features/workout/domain/workout_session.dart`:

```dart
import 'dart:math' as math;

DateTime? _parseTime(Object? value) => value == null ? null : DateTime.parse(value as String);

/// Bir antrenman oturumundaki tek set: planın kopyası (hedef, yüzde, öneri)
/// ve gerçekte yapılan (kilo, tekrar, tamamlanma).
class SessionSet {
  const SessionSet({
    required this.exercisePosition,
    required this.setIndex,
    required this.exerciseId,
    required this.exerciseName,
    required this.targetRepsMin,
    required this.targetRepsMax,
    this.id,
    this.isAmrap = false,
    this.percent1rm,
    this.percentRefExerciseId,
    this.restSeconds,
    this.suggestedWeightKg,
    this.deloaded = false,
    this.weightKg,
    this.reps,
    this.completedAt,
  });

  /// Sunucuya yazılmadan önce null.
  final String? id;
  final int exercisePosition;
  final int setIndex;
  final String exerciseId;
  final String exerciseName;
  final int targetRepsMin;
  final int targetRepsMax;
  final bool isAmrap;
  final double? percent1rm;
  final String? percentRefExerciseId;
  final int? restSeconds;
  final double? suggestedWeightKg;

  /// Öneri, 3 başarısız oturum sonrası %10 düşürüldü.
  final bool deloaded;
  final double? weightKg;
  final int? reps;

  /// null = henüz yapılmadı.
  final DateTime? completedAt;

  bool get isCompleted => completedAt != null;

  /// Yüzdenin dayandığı 1RM'nin hareketi (nSuns T2: Sumo Deadlift → Deadlift).
  String get oneRepMaxExerciseId => percentRefExerciseId ?? exerciseId;

  /// Hedefe ulaşıldı mı: normal sette üst sınır, AMRAP setinde alt sınır.
  bool get hitTarget => isCompleted && (reps ?? 0) >= (isAmrap ? targetRepsMin : targetRepsMax);

  /// Kilo kutusunda gösterilecek değer: girilen, yoksa önerilen.
  double? get displayWeightKg => weightKg ?? suggestedWeightKg;

  /// Tekrar kutusunda gösterilecek değer: girilen, yoksa (AMRAP değilse) hedefin üst sınırı.
  int? get displayReps => reps ?? (isAmrap ? null : targetRepsMax);

  factory SessionSet.fromJson(Map<String, dynamic> json) {
    final exercise = json['exercises'] as Map<String, dynamic>?;
    return SessionSet(
      id: json['id'] as String?,
      exercisePosition: json['exercise_position'] as int,
      setIndex: json['set_index'] as int,
      exerciseId: json['exercise_id'] as String,
      exerciseName: exercise?['name'] as String? ?? json['exercise_id'] as String,
      targetRepsMin: json['target_reps_min'] as int,
      targetRepsMax: json['target_reps_max'] as int,
      isAmrap: json['is_amrap'] as bool? ?? false,
      percent1rm: (json['percent_1rm'] as num?)?.toDouble(),
      percentRefExerciseId: json['percent_ref_exercise_id'] as String?,
      restSeconds: json['rest_seconds'] as int?,
      suggestedWeightKg: (json['suggested_weight_kg'] as num?)?.toDouble(),
      deloaded: json['deloaded'] as bool? ?? false,
      weightKg: (json['weight_kg'] as num?)?.toDouble(),
      reps: json['reps'] as int?,
      completedAt: _parseTime(json['completed_at']),
    );
  }

  /// `start_session` payload'ındaki ve `session_sets` insert'indeki şekil
  /// (oturum id'si ve sonuçlar hariç).
  Map<String, dynamic> toInsertJson() {
    return {
      'exercise_position': exercisePosition,
      'set_index': setIndex,
      'exercise_id': exerciseId,
      'target_reps_min': targetRepsMin,
      'target_reps_max': targetRepsMax,
      'is_amrap': isAmrap,
      'percent_1rm': percent1rm,
      'percent_ref_exercise_id': percentRefExerciseId,
      'rest_seconds': restSeconds,
      'suggested_weight_kg': suggestedWeightKg,
      'deloaded': deloaded,
    };
  }

  SessionSet copyWith({
    String? id,
    double? weightKg,
    bool clearWeight = false,
    int? reps,
    bool clearReps = false,
    DateTime? completedAt,
    bool clearCompletedAt = false,
  }) {
    return SessionSet(
      id: id ?? this.id,
      exercisePosition: exercisePosition,
      setIndex: setIndex,
      exerciseId: exerciseId,
      exerciseName: exerciseName,
      targetRepsMin: targetRepsMin,
      targetRepsMax: targetRepsMax,
      isAmrap: isAmrap,
      percent1rm: percent1rm,
      percentRefExerciseId: percentRefExerciseId,
      restSeconds: restSeconds,
      suggestedWeightKg: suggestedWeightKg,
      deloaded: deloaded,
      weightKg: clearWeight ? null : (weightKg ?? this.weightKg),
      reps: clearReps ? null : (reps ?? this.reps),
      completedAt: clearCompletedAt ? null : (completedAt ?? this.completedAt),
    );
  }
}

class WorkoutSession {
  const WorkoutSession({
    required this.id,
    required this.programName,
    required this.workoutName,
    required this.workoutPosition,
    required this.startedAt,
    this.programId,
    this.finishedAt,
    this.sets = const [],
  });

  final String id;

  /// Program silinmişse null.
  final String? programId;
  final String programName;
  final String workoutName;
  final int workoutPosition;
  final DateTime startedAt;

  /// null = devam ediyor.
  final DateTime? finishedAt;

  /// `exercisePosition`, `setIndex` sırasıyla.
  final List<SessionSet> sets;

  bool get isInProgress => finishedAt == null;

  /// Aynı `exercisePosition`'lı ardışık setler (ekrandaki hareket kartları).
  List<List<SessionSet>> get exerciseGroups {
    final groups = <List<SessionSet>>[];
    for (final set in sets) {
      if (groups.isNotEmpty && groups.last.first.exercisePosition == set.exercisePosition) {
        groups.last.add(set);
      } else {
        groups.add([set]);
      }
    }
    return groups;
  }

  /// Yeni eklenecek hareketin sırası.
  int get nextExercisePosition =>
      sets.isEmpty ? 0 : sets.map((s) => s.exercisePosition).reduce(math.max) + 1;

  SessionSet setById(String id) => sets.firstWhere((s) => s.id == id);

  WorkoutSession replaceSet(SessionSet updated) =>
      copyWith(sets: [for (final s in sets) s.id == updated.id ? updated : s]);

  WorkoutSession copyWith({DateTime? finishedAt, List<SessionSet>? sets}) {
    return WorkoutSession(
      id: id,
      programId: programId,
      programName: programName,
      workoutName: workoutName,
      workoutPosition: workoutPosition,
      startedAt: startedAt,
      finishedAt: finishedAt ?? this.finishedAt,
      sets: sets ?? this.sets,
    );
  }

  factory WorkoutSession.fromJson(Map<String, dynamic> json) {
    final sets = [
      for (final row in json['session_sets'] as List? ?? const [])
        SessionSet.fromJson(row as Map<String, dynamic>),
    ]..sort((a, b) {
        final byExercise = a.exercisePosition.compareTo(b.exercisePosition);
        return byExercise != 0 ? byExercise : a.setIndex.compareTo(b.setIndex);
      });
    return WorkoutSession(
      id: json['id'] as String,
      programId: json['program_id'] as String?,
      programName: json['program_name'] as String,
      workoutName: json['workout_name'] as String,
      workoutPosition: json['workout_position'] as int,
      startedAt: DateTime.parse(json['started_at'] as String),
      finishedAt: _parseTime(json['finished_at']),
      sets: sets,
    );
  }
}
```

`lib/features/workout/domain/session_stats.dart`:

```dart
import 'workout_session.dart';

int completedSetCount(WorkoutSession session) => session.sets.where((s) => s.isCompleted).length;

/// Σ kilo × tekrar; kilosuz (vücut ağırlığı) setler hariç.
double totalVolumeKg(WorkoutSession session) {
  var total = 0.0;
  for (final s in session.sets) {
    if (s.isCompleted && s.weightKg != null && s.reps != null) total += s.weightKg! * s.reps!;
  }
  return total;
}

/// Bitmişse başlangıçtan bitişe, değilse başlangıçtan [now]'a; negatif olmaz.
Duration sessionDuration(WorkoutSession session, DateTime now) {
  final elapsed = (session.finishedAt ?? now).difference(session.startedAt);
  return elapsed.isNegative ? Duration.zero : elapsed;
}

/// 90 sn → "01:30", 1 sa 5 dk 3 sn → "1:05:03".
String formatDuration(Duration duration) {
  String two(int n) => n.toString().padLeft(2, '0');
  final minutes = two(duration.inMinutes.remainder(60));
  final seconds = two(duration.inSeconds.remainder(60));
  return duration.inHours > 0 ? '${duration.inHours}:$minutes:$seconds' : '$minutes:$seconds';
}
```

`lib/features/workout/domain/block_format.dart` dosyasının tamamını şununla değiştir (çıktılar aynı kalır; `_trim` public olur, oturum etiketi eklenir):

```dart
import 'weight_calculator.dart';
import 'workout_exercise.dart';
import 'workout_session.dart';

/// 60.0 → "60", 57.5 → "57.5".
String trimNumber(double value) =>
    value == value.roundToDouble() ? value.toInt().toString() : value.toString();

String _repsLabel(int min, int max, bool isAmrap) =>
    '${min == max ? '$min' : '$min–$max'}${isAmrap ? '+' : ''}';

String setsRepsLabel(WorkoutExercise block) =>
    '${block.sets} × ${_repsLabel(block.repsMin, block.repsMax, block.isAmrap)}';

/// 1RM varsa hesaplanan kilo, yoksa yüzde; yüzdesiz blokta null.
String? loadLabel(WorkoutExercise block, double? oneRepMaxKg) {
  final pct = block.percent1rm;
  if (pct == null) return null;
  final kg = targetWeightKg(oneRepMaxKg: oneRepMaxKg, percent1rm: pct);
  return kg == null ? '%${trimNumber(pct)}' : '${trimNumber(kg)} kg';
}

/// Oturum setinin hedefi: "5", "8–12", "5+"; yüzdeliyse "5+ · %85".
String sessionSetTargetLabel(SessionSet set) {
  final reps = _repsLabel(set.targetRepsMin, set.targetRepsMax, set.isAmrap);
  final pct = set.percent1rm;
  return pct == null ? reps : '$reps · %${trimNumber(pct)}';
}
```

- [ ] **Step 4: Testlerin geçtiğini doğrula**

Run: `flutter test test/features/workout/domain/`
Expected: PASS (yeni testler + mevcut `block_format_test`, `models_test` vb. değişmeden geçer).

- [ ] **Step 5: Commit**

```bash
git add lib/features/workout/domain/workout_session.dart lib/features/workout/domain/session_stats.dart lib/features/workout/domain/block_format.dart test/features/workout/domain/workout_session_test.dart test/features/workout/domain/session_stats_test.dart test/features/workout/domain/block_format_test.dart
git commit -m "feat(workout): add workout session models, stats and set target label"
```

---

## Task 3: Otomatik artış kuralları — `progression.dart`

**Files:**
- Create: `lib/features/workout/domain/progression.dart`
- Modify: `lib/features/workout/domain/weight_calculator.dart`
- Test: `test/features/workout/domain/progression_test.dart`

**Interfaces:**
- Consumes: `SessionSet` (Task 2), `Exercise` (F3).
- Produces:
  - `weight_calculator.dart`: `double roundToPlate(double kg)`.
  - `double weightIncrementKg(Exercise? exercise)`.
  - `class WeightSuggestion { final double? weightKg; final bool deloaded; }`.
  - `WeightSuggestion suggestWeight({required List<List<SessionSet>> history, required double incrementKg})` — `history`: hareketin geçtiği bitmiş oturumlardaki setleri, **yeniden eskiye**.
  - `class OneRepMaxSuggestion { final String exerciseId; final double currentKg; final double suggestedKg; }`.
  - `double? adjustedOneRepMax({required double currentKg, required int extraReps})`.
  - `List<OneRepMaxSuggestion> oneRepMaxSuggestions({required List<SessionSet> sets, required Map<String, double> oneRepMaxes})`.

- [ ] **Step 1: Başarısız testleri yaz**

`test/features/workout/domain/progression_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:spor_takip/features/workout/domain/exercise.dart';
import 'package:spor_takip/features/workout/domain/progression.dart';
import 'package:spor_takip/features/workout/domain/weight_calculator.dart';
import 'package:spor_takip/features/workout/domain/workout_session.dart';

SessionSet _set({
  double? weight,
  int? reps,
  int min = 5,
  int max = 5,
  bool amrap = false,
  double? pct,
  bool done = true,
  String exercise = 'Barbell_Squat',
  String? ref,
}) {
  return SessionSet(
    id: 'x',
    exercisePosition: 0,
    setIndex: 0,
    exerciseId: exercise,
    exerciseName: exercise,
    targetRepsMin: min,
    targetRepsMax: max,
    isAmrap: amrap,
    percent1rm: pct,
    percentRefExerciseId: ref,
    weightKg: weight,
    reps: reps,
    completedAt: done ? DateTime(2026, 9, 1) : null,
  );
}

List<SessionSet> _session(double weight, List<int> reps, {int min = 5, int max = 5}) =>
    [for (final r in reps) _set(weight: weight, reps: r, min: min, max: max)];

void main() {
  test('roundToPlate rounds to the nearest 2.5 kg', () {
    expect(roundToPlate(54), 55);
    expect(roundToPlate(53.7), 52.5);
    expect(roundToPlate(90), 90);
  });

  group('weightIncrementKg', () {
    test('lower-body barbell lifts go up by 5 kg', () {
      const squat = Exercise(
          id: 'Barbell_Squat', name: 'Barbell Squat', equipment: 'barbell', primaryMuscles: ['quadriceps']);
      const deadlift = Exercise(
          id: 'Barbell_Deadlift', name: 'Barbell Deadlift', equipment: 'barbell', primaryMuscles: ['lower back']);
      expect(weightIncrementKg(squat), 5);
      expect(weightIncrementKg(deadlift), 5);
    });

    test('everything else goes up by 2.5 kg', () {
      const bench = Exercise(id: 'Bench', name: 'Bench', equipment: 'barbell', primaryMuscles: ['chest']);
      const legPress =
          Exercise(id: 'Leg_Press', name: 'Leg Press', equipment: 'machine', primaryMuscles: ['quadriceps']);
      expect(weightIncrementKg(bench), 2.5);
      expect(weightIncrementKg(legPress), 2.5);
      expect(weightIncrementKg(null), 2.5);
    });
  });

  group('suggestWeight', () {
    test('no history → empty', () {
      expect(suggestWeight(history: const [], incrementKg: 2.5).weightKg, isNull);
    });

    test('history without weights (bodyweight) → empty', () {
      expect(suggestWeight(history: [[_set(reps: 10, min: 8, max: 12)]], incrementKg: 2.5).weightKg, isNull);
    });

    test('every set at the top of the range → increase', () {
      final s = suggestWeight(history: [_session(60, [5, 5, 5, 5, 5])], incrementKg: 5);
      expect(s.weightKg, 65);
      expect(s.deloaded, isFalse);
    });

    test('rep range needs repsMax on every set', () {
      expect(suggestWeight(history: [_session(40, [12, 12, 12], min: 8, max: 12)], incrementKg: 2.5).weightKg, 42.5);
      expect(suggestWeight(history: [_session(40, [12, 12, 10], min: 8, max: 12)], incrementKg: 2.5).weightKg, 40);
    });

    test('an unfinished set counts as a miss', () {
      final sets = [..._session(60, [5, 5, 5, 5]), _set(weight: 60, done: false)];
      expect(suggestWeight(history: [sets], incrementKg: 5).weightKg, 60);
    });

    test('reference is the heaviest completed set', () {
      final sets = [_set(weight: 50, reps: 5), _set(weight: 60, reps: 5)];
      expect(suggestWeight(history: [sets], incrementKg: 2.5).weightKg, 62.5);
    });

    test('three failed sessions at the same weight → 10% deload rounded to 2.5 kg', () {
      final failed = _session(60, [5, 5, 4]);
      final s = suggestWeight(history: [failed, failed, failed], incrementKg: 5);
      expect(s.weightKg, 55);
      expect(s.deloaded, isTrue);
    });

    test('two failures are not enough to deload', () {
      final failed = _session(60, [5, 5, 4]);
      expect(suggestWeight(history: [failed, failed, _session(57.5, [5, 5, 5])], incrementKg: 2.5).weightKg, 60);
    });

    test('after a deload one failure keeps the lower weight', () {
      final history = [_session(55, [5, 4]), _session(60, [4]), _session(60, [4])];
      expect(suggestWeight(history: history, incrementKg: 5).weightKg, 55);
    });

    test('percentage-based sets are ignored', () {
      final history = [
        [_set(weight: 100, reps: 5, pct: 85)],
        _session(60, [5]),
      ];
      expect(suggestWeight(history: history, incrementKg: 5).weightKg, 65);
    });
  });

  group('oneRepMaxSuggestions', () {
    List<SessionSet> amrap(int reps, {double pct = 85, int min = 5, String exercise = 'Barbell_Squat', String? ref}) =>
        [_set(weight: 85, reps: reps, min: min, max: min, amrap: true, pct: pct, exercise: exercise, ref: ref)];

    double? suggested(List<SessionSet> sets) {
      final result = oneRepMaxSuggestions(sets: sets, oneRepMaxes: {'Barbell_Squat': 100});
      return result.isEmpty ? null : result.single.suggestedKg;
    }

    test('5+ set: below target −10%, on target none, then +2.5 / +5 / +7.5', () {
      expect(suggested(amrap(4)), 90);
      expect(suggested(amrap(5)), isNull);
      expect(suggested(amrap(6)), 102.5);
      expect(suggested(amrap(7)), 102.5);
      expect(suggested(amrap(8)), 105);
      expect(suggested(amrap(9)), 105);
      expect(suggested(amrap(10)), 107.5);
      expect(suggested(amrap(15)), 107.5);
    });

    test('nSuns 1+ set matches the source table', () {
      expect(suggested(amrap(0, min: 1, pct: 95)), 90);
      expect(suggested(amrap(1, min: 1, pct: 95)), isNull);
      expect(suggested(amrap(3, min: 1, pct: 95)), 102.5);
      expect(suggested(amrap(5, min: 1, pct: 95)), 105);
      expect(suggested(amrap(6, min: 1, pct: 95)), 107.5);
    });

    test('uses the highest-percentage AMRAP set of each lift', () {
      expect(suggested([...amrap(12, pct: 65), ...amrap(5, pct: 95)]), isNull);
    });

    test('percent_ref lifts are credited to the referenced 1RM', () {
      final result = oneRepMaxSuggestions(
        sets: amrap(8, exercise: 'Sumo_Deadlift', ref: 'Barbell_Deadlift'),
        oneRepMaxes: {'Barbell_Deadlift': 140},
      );
      expect(result.single.exerciseId, 'Barbell_Deadlift');
      expect(result.single.currentKg, 140);
      expect(result.single.suggestedKg, 145);
    });

    test('nothing without a stored 1RM, for unfinished sets or non-AMRAP sets', () {
      expect(oneRepMaxSuggestions(sets: amrap(8), oneRepMaxes: const {}), isEmpty);
      expect(suggested([_set(weight: 85, reps: 8, amrap: true, pct: 85, done: false)]), isNull);
      expect(suggested([_set(weight: 85, reps: 8, pct: 85)]), isNull);
    });
  });
}
```

- [ ] **Step 2: Testlerin başarısız olduğunu doğrula**

Run: `flutter test test/features/workout/domain/progression_test.dart`
Expected: FAIL — `progression.dart` yok, `roundToPlate` tanımsız.

- [ ] **Step 3: `roundToPlate`'i ekle**

`lib/features/workout/domain/weight_calculator.dart` dosyasının tamamını şununla değiştir:

```dart
const _plateStepKg = 2.5;

/// En yakın 2,5 kg'a yuvarlar.
double roundToPlate(double kg) => (kg / _plateStepKg).round() * _plateStepKg;

/// 1RM × yüzde; en yakın 2,5 kg'a yuvarlanır. Girdilerden biri yoksa null
/// (arayüz o zaman kilo yerine yüzdeyi gösterir).
double? targetWeightKg({required double? oneRepMaxKg, required double? percent1rm}) {
  if (oneRepMaxKg == null || percent1rm == null) return null;
  return roundToPlate(oneRepMaxKg * percent1rm / 100);
}
```

- [ ] **Step 4: Kuralları yaz**

`lib/features/workout/domain/progression.dart`:

```dart
import 'dart:math' as math;

import 'exercise.dart';
import 'weight_calculator.dart';
import 'workout_session.dart';

const _lowerBodyMuscles = {'quadriceps', 'hamstrings', 'glutes', 'lower back'};
const _deloadFactor = 0.9;
const _deloadAfterFailures = 3;

/// Alt vücut halter hareketleri +5 kg, diğer her şey +2,5 kg.
double weightIncrementKg(Exercise? exercise) {
  final lowerBodyBarbell = exercise != null &&
      exercise.equipment == 'barbell' &&
      exercise.primaryMuscles.any(_lowerBodyMuscles.contains);
  return lowerBodyBarbell ? 5 : 2.5;
}

class WeightSuggestion {
  const WeightSuggestion(this.weightKg, {this.deloaded = false});

  /// null = öneri yok (geçmiş yok ya da kilo girilmemiş).
  final double? weightKg;
  final bool deloaded;
}

double? _referenceWeight(List<SessionSet> sets) {
  final weights = [for (final s in sets) if (s.isCompleted && s.weightKg != null) s.weightKg!];
  return weights.isEmpty ? null : weights.reduce(math.max);
}

bool _succeeded(List<SessionSet> sets) => sets.every((s) => s.hitTarget);

/// Yüzdelik olmayan bir bloğun önerilen kilosu.
///
/// [history]: hareketin geçtiği bitmiş oturumlardaki setleri, yeniden eskiye.
/// Son oturumda her set hedefin üstüne ulaştıysa artış, ulaşmadıysa aynı kilo;
/// son 3 oturum aynı kiloda ve üçü de başarısızsa %10 düşüş.
WeightSuggestion suggestWeight({required List<List<SessionSet>> history, required double incrementKg}) {
  final sessions = [
    for (final sets in history) [for (final s in sets) if (s.percent1rm == null) s],
  ].where((sets) => sets.isNotEmpty).toList();
  if (sessions.isEmpty) return const WeightSuggestion(null);

  final reference = _referenceWeight(sessions.first);
  if (reference == null) return const WeightSuggestion(null);

  final recent = sessions.take(_deloadAfterFailures).toList();
  final stuck = recent.length == _deloadAfterFailures &&
      recent.every((sets) => _referenceWeight(sets) == reference && !_succeeded(sets));
  if (stuck) return WeightSuggestion(roundToPlate(reference * _deloadFactor), deloaded: true);

  return WeightSuggestion(_succeeded(sessions.first) ? reference + incrementKg : reference);
}

class OneRepMaxSuggestion {
  const OneRepMaxSuggestion({required this.exerciseId, required this.currentKg, required this.suggestedKg});

  final String exerciseId;
  final double currentKg;
  final double suggestedKg;
}

/// AMRAP setindeki fazla tekrara göre yeni 1RM; değişiklik yoksa null.
/// Hedefin altı −%10; 0 fazla → yok; 1–2 → +2,5; 3–4 → +5; 5+ → +7,5 kg.
double? adjustedOneRepMax({required double currentKg, required int extraReps}) {
  if (extraReps < 0) return roundToPlate(currentKg * _deloadFactor);
  if (extraReps == 0) return null;
  final step = extraReps <= 2
      ? 2.5
      : extraReps <= 4
          ? 5.0
          : 7.5;
  return roundToPlate(currentKg + step);
}

/// Oturumdaki her 1RM hareketi için en yüksek yüzdeli tamamlanmış AMRAP setine
/// göre öneri. Kayıtlı 1RM'si olmayan hareketlere öneri yapılmaz.
List<OneRepMaxSuggestion> oneRepMaxSuggestions({
  required List<SessionSet> sets,
  required Map<String, double> oneRepMaxes,
}) {
  final best = <String, SessionSet>{};
  for (final s in sets) {
    if (!s.isAmrap || !s.isCompleted || s.percent1rm == null || s.reps == null) continue;
    final current = best[s.oneRepMaxExerciseId];
    if (current == null || s.percent1rm! > current.percent1rm!) best[s.oneRepMaxExerciseId] = s;
  }

  final result = <OneRepMaxSuggestion>[];
  for (final MapEntry(key: exerciseId, value: set) in best.entries) {
    final current = oneRepMaxes[exerciseId];
    if (current == null) continue;
    final next = adjustedOneRepMax(currentKg: current, extraReps: set.reps! - set.targetRepsMin);
    if (next == null || next == current) continue;
    result.add(OneRepMaxSuggestion(exerciseId: exerciseId, currentKg: current, suggestedKg: next));
  }
  return result;
}
```

- [ ] **Step 5: Testlerin geçtiğini doğrula**

Run: `flutter test test/features/workout/domain/`
Expected: PASS (mevcut `weight_calculator_test` da değişmeden geçer).

- [ ] **Step 6: Commit**

```bash
git add lib/features/workout/domain/progression.dart lib/features/workout/domain/weight_calculator.dart test/features/workout/domain/progression_test.dart
git commit -m "feat(workout): add weight progression, deload and 1RM suggestion rules"
```

---

## Task 4: Program antrenmanından oturum setleri — `session_builder.dart`

**Files:**
- Create: `lib/features/workout/domain/session_builder.dart`
- Test: `test/features/workout/domain/session_builder_test.dart`

**Interfaces:**
- Consumes: `groupBlocks` (F3), `ProgramWorkout`, `WorkoutExercise`, `Exercise`, `targetWeightKg`, `suggestWeight`, `weightIncrementKg` (Task 3), `SessionSet`, `WorkoutSession` (Task 2).
- Produces:
  - `typedef ExerciseHistory = Map<String, List<List<SessionSet>>>;`
  - `ExerciseHistory groupExerciseHistory(List<WorkoutSession> sessionsNewestFirst)`.
  - `List<SessionSet> buildSessionSets({required ProgramWorkout workout, required Map<String, double> oneRepMaxes, required ExerciseHistory history, required Map<String, Exercise> exercises})`.
  - `List<SessionSet> buildAddedExerciseSets({required Exercise exercise, required int exercisePosition, required ExerciseHistory history, required Map<String, Exercise> exercises})` — 3 set × 8–12, dinlenme 90 sn.

- [ ] **Step 1: Başarısız testleri yaz**

`test/features/workout/domain/session_builder_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:spor_takip/features/workout/domain/exercise.dart';
import 'package:spor_takip/features/workout/domain/program_workout.dart';
import 'package:spor_takip/features/workout/domain/session_builder.dart';
import 'package:spor_takip/features/workout/domain/workout_exercise.dart';
import 'package:spor_takip/features/workout/domain/workout_session.dart';

const _squat = Exercise(
    id: 'Barbell_Squat', name: 'Barbell Squat', equipment: 'barbell', primaryMuscles: ['quadriceps']);
const _bench = Exercise(id: 'Bench', name: 'Bench Press', equipment: 'barbell', primaryMuscles: ['chest']);
const _exercises = {'Barbell_Squat': _squat, 'Bench': _bench};

const _squatBlock = WorkoutExercise(
  exerciseId: 'Barbell_Squat',
  exerciseName: 'Barbell Squat',
  sets: 3,
  repsMin: 5,
  repsMax: 5,
  restSeconds: 180,
);
const _curl = WorkoutExercise(
  exerciseId: 'Barbell_Curl',
  exerciseName: 'Barbell Curl',
  sets: 2,
  repsMin: 8,
  repsMax: 12,
);
const _pct65 = WorkoutExercise(
  exerciseId: 'Barbell_Squat',
  exerciseName: 'Barbell Squat',
  sets: 1,
  repsMin: 5,
  repsMax: 5,
  percent1rm: 58.5,
);
const _pct85 = WorkoutExercise(
  exerciseId: 'Barbell_Squat',
  exerciseName: 'Barbell Squat',
  sets: 1,
  repsMin: 5,
  repsMax: 5,
  isAmrap: true,
  percent1rm: 76.5,
);
const _sumo = WorkoutExercise(
  exerciseId: 'Sumo_Deadlift',
  exerciseName: 'Sumo Deadlift',
  sets: 1,
  repsMin: 5,
  repsMax: 5,
  percent1rm: 50,
  percentRefExerciseId: 'Barbell_Deadlift',
);

SessionSet _done(String exercise, double weight, int reps, {int max = 5}) => SessionSet(
      id: 'h',
      exercisePosition: 0,
      setIndex: 0,
      exerciseId: exercise,
      exerciseName: exercise,
      targetRepsMin: 5,
      targetRepsMax: max,
      weightKg: weight,
      reps: reps,
      completedAt: DateTime(2026, 9, 1),
    );

List<SessionSet> _build(List<WorkoutExercise> blocks,
    {Map<String, double> oneRepMaxes = const {}, ExerciseHistory history = const {}}) {
  return buildSessionSets(
    workout: ProgramWorkout(name: 'A', exercises: blocks),
    oneRepMaxes: oneRepMaxes,
    history: history,
    exercises: _exercises,
  );
}

void main() {
  test('expands blocks into sets; one exercise position per lift', () {
    final sets = _build([_squatBlock, _curl]);
    expect(sets.map((s) => s.exercisePosition), [0, 0, 0, 1, 1]);
    expect(sets.map((s) => s.setIndex), [0, 1, 2, 0, 1]);
    expect(sets.first.restSeconds, 180);
    expect(sets.first.exerciseName, 'Barbell Squat');
    expect(sets.last.targetRepsMin, 8);
    expect(sets.last.targetRepsMax, 12);
    expect(sets.every((s) => s.id == null && !s.isCompleted), isTrue);
  });

  test('consecutive percentage blocks of one lift share a position and number on', () {
    final sets = _build([_pct65, _pct85], oneRepMaxes: {'Barbell_Squat': 100});
    expect(sets.map((s) => s.exercisePosition), [0, 0]);
    expect(sets.map((s) => s.setIndex), [0, 1]);
    expect(sets.map((s) => s.suggestedWeightKg), [57.5, 77.5]);
    expect(sets[1].isAmrap, isTrue);
    expect(sets[1].percent1rm, 76.5);
  });

  test('percent_ref uses the referenced 1RM; no 1RM → no suggestion', () {
    expect(_build([_sumo], oneRepMaxes: {'Barbell_Deadlift': 200}).single.suggestedWeightKg, 100);
    expect(_build([_sumo]).single.suggestedWeightKg, isNull);
    expect(_build([_sumo]).single.percentRefExerciseId, 'Barbell_Deadlift');
  });

  test('plain blocks use progression from history', () {
    final history = {
      'Barbell_Squat': [
        [_done('Barbell_Squat', 60, 5), _done('Barbell_Squat', 60, 5), _done('Barbell_Squat', 60, 5)],
      ],
    };
    final sets = _build([_squatBlock], history: history);
    expect(sets.map((s) => s.suggestedWeightKg), [65, 65, 65]);
    expect(sets.any((s) => s.deloaded), isFalse);
  });

  test('deload is flagged on every set of the lift', () {
    final failed = [_done('Barbell_Squat', 60, 4)];
    final sets = _build([_squatBlock], history: {
      'Barbell_Squat': [failed, failed, failed],
    });
    expect(sets.map((s) => s.suggestedWeightKg), [55, 55, 55]);
    expect(sets.every((s) => s.deloaded), isTrue);
  });

  test('groupExerciseHistory keeps newest-first order per exercise', () {
    WorkoutSession session(String id, List<SessionSet> sets) => WorkoutSession(
          id: id,
          programName: 'P',
          workoutName: 'A',
          workoutPosition: 0,
          startedAt: DateTime(2026, 9, 1),
          finishedAt: DateTime(2026, 9, 1, 1),
          sets: sets,
        );
    final history = groupExerciseHistory([
      session('new', [_done('Barbell_Squat', 65, 5), _done('Bench', 40, 5)]),
      session('old', [_done('Barbell_Squat', 60, 5)]),
    ]);
    expect(history['Barbell_Squat']!.map((sets) => sets.single.weightKg), [65, 60]);
    expect(history['Bench']!.length, 1);
  });

  test('an added exercise gets 3 × 8–12 with 90 s rest and a suggestion', () {
    final sets = buildAddedExerciseSets(
      exercise: _bench,
      exercisePosition: 4,
      history: {
        'Bench': [
          [_done('Bench', 40, 12, max: 12), _done('Bench', 40, 12, max: 12)],
        ],
      },
      exercises: _exercises,
    );
    expect(sets.length, 3);
    expect(sets.map((s) => s.exercisePosition).toSet(), {4});
    expect(sets.map((s) => s.setIndex), [0, 1, 2]);
    expect(sets.first.exerciseName, 'Bench Press');
    expect(sets.first.targetRepsMin, 8);
    expect(sets.first.targetRepsMax, 12);
    expect(sets.first.restSeconds, 90);
    expect(sets.first.suggestedWeightKg, 42.5);
  });
}
```

- [ ] **Step 2: Testlerin başarısız olduğunu doğrula**

Run: `flutter test test/features/workout/domain/session_builder_test.dart`
Expected: FAIL — `session_builder.dart` yok.

- [ ] **Step 3: Üreticiyi yaz**

`lib/features/workout/domain/session_builder.dart`:

```dart
import 'block_grouping.dart';
import 'exercise.dart';
import 'program_workout.dart';
import 'progression.dart';
import 'weight_calculator.dart';
import 'workout_session.dart';

/// exerciseId → hareketin geçtiği her bitmiş oturumdaki setleri, yeniden eskiye.
typedef ExerciseHistory = Map<String, List<List<SessionSet>>>;

const _addedSets = 3;
const _addedRepsMin = 8;
const _addedRepsMax = 12;
const _addedRestSeconds = 90;

ExerciseHistory groupExerciseHistory(List<WorkoutSession> sessionsNewestFirst) {
  final history = <String, List<List<SessionSet>>>{};
  for (final session in sessionsNewestFirst) {
    final byExercise = <String, List<SessionSet>>{};
    for (final set in session.sets) {
      (byExercise[set.exerciseId] ??= []).add(set);
    }
    byExercise.forEach((exerciseId, sets) => (history[exerciseId] ??= []).add(sets));
  }
  return history;
}

WeightSuggestion _suggestion(String exerciseId, ExerciseHistory history, Map<String, Exercise> exercises) {
  return suggestWeight(
    history: history[exerciseId] ?? const [],
    incrementKg: weightIncrementKg(exercises[exerciseId]),
  );
}

/// Programdaki antrenmanın her bloğunun her seti için bir [SessionSet].
/// Art arda aynı hareketli bloklar tek `exercisePosition` altında toplanır.
List<SessionSet> buildSessionSets({
  required ProgramWorkout workout,
  required Map<String, double> oneRepMaxes,
  required ExerciseHistory history,
  required Map<String, Exercise> exercises,
}) {
  final sets = <SessionSet>[];
  for (final (position, group) in groupBlocks(workout.exercises).indexed) {
    final plain = _suggestion(group.exerciseId, history, exercises);
    var setIndex = 0;
    for (final block in group.blocks) {
      final pct = block.percent1rm;
      final weight = pct == null
          ? plain.weightKg
          : targetWeightKg(oneRepMaxKg: oneRepMaxes[block.oneRepMaxExerciseId], percent1rm: pct);
      for (var i = 0; i < block.sets; i++) {
        sets.add(SessionSet(
          exercisePosition: position,
          setIndex: setIndex++,
          exerciseId: block.exerciseId,
          exerciseName: block.exerciseName,
          targetRepsMin: block.repsMin,
          targetRepsMax: block.repsMax,
          isAmrap: block.isAmrap,
          percent1rm: pct,
          percentRefExerciseId: block.percentRefExerciseId,
          restSeconds: block.restSeconds,
          suggestedWeightKg: weight,
          deloaded: pct == null && plain.deloaded,
        ));
      }
    }
  }
  return sets;
}

/// Antrenman sırasında eklenen hareket: 3 set × 8–12, 90 sn dinlenme.
List<SessionSet> buildAddedExerciseSets({
  required Exercise exercise,
  required int exercisePosition,
  required ExerciseHistory history,
  required Map<String, Exercise> exercises,
}) {
  final suggestion = _suggestion(exercise.id, history, exercises);
  return [
    for (var i = 0; i < _addedSets; i++)
      SessionSet(
        exercisePosition: exercisePosition,
        setIndex: i,
        exerciseId: exercise.id,
        exerciseName: exercise.name,
        targetRepsMin: _addedRepsMin,
        targetRepsMax: _addedRepsMax,
        restSeconds: _addedRestSeconds,
        suggestedWeightKg: suggestion.weightKg,
        deloaded: suggestion.deloaded,
      ),
  ];
}
```

- [ ] **Step 4: Testlerin geçtiğini doğrula**

Run: `flutter test test/features/workout/domain/session_builder_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/workout/domain/session_builder.dart test/features/workout/domain/session_builder_test.dart
git commit -m "feat(workout): build session sets with suggested weights from a program workout"
```

---

## Task 5: Oturum repository'si, provider'lar ve test fake'i

**Files:**
- Create: `lib/features/workout/data/session_repository.dart`, `lib/features/workout/application/session_providers.dart`
- Modify: `test/features/workout/fakes.dart`
- Test: `test/features/workout/application/session_providers_test.dart`

**Interfaces:**
- Consumes: `WorkoutSession`, `SessionSet` (Task 2); `AppSupabase.client`, `isLoggedInProvider` (mevcut).
- Produces:
  - `class ActiveSessionExistsException implements Exception`.
  - `abstract interface class SessionRepository` — `fetchInProgressSession() → Future<WorkoutSession?>`, `fetchSession(String id) → Future<WorkoutSession>`, `fetchHistory() → Future<List<WorkoutSession>>`, `fetchExerciseHistory(Set<String> exerciseIds) → Future<List<WorkoutSession>>`, `startSession({required String? programId, required String programName, required String workoutName, required int workoutPosition, required List<SessionSet> sets}) → Future<String>`, `updateSet(SessionSet set) → Future<void>`, `addSets(String sessionId, List<SessionSet> sets) → Future<List<SessionSet>>`, `deleteSets(List<String> setIds) → Future<void>`, `finishSession(String sessionId, Map<String, double> oneRepMaxes) → Future<void>`, `deleteSession(String sessionId) → Future<void>`.
  - `session_providers.dart`: `sessionRepositoryProvider`, `inProgressSessionProvider` (`FutureProvider.autoDispose<WorkoutSession?>`), `sessionHistoryProvider` (`FutureProvider.autoDispose<List<WorkoutSession>>`), `sessionDetailProvider` (`FutureProvider.autoDispose.family<WorkoutSession, String>`), `nowProvider` (`Provider<DateTime Function()>`), `clockProvider` (`StreamProvider.autoDispose<DateTime>`).
  - `fakes.dart`: `FakeSessionRepository({List<WorkoutSession>? sessions})` — alanlar `sessions`, `updateError`, `finishError`, `updatedSets`, `deletedSetIds`, `finished`; yeni oturum id'leri `session-N`, yeni set id'leri `set-N` (tek sayaç, 0'dan); yeni oturumun `startedAt`'i `DateTime(2026, 9, 26, 10)`, bitişi `DateTime(2026, 9, 26, 11)`.

- [ ] **Step 1: Repository'yi yaz**

`lib/features/workout/data/session_repository.dart`:

```dart
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/workout_session.dart';

/// Kullanıcının zaten devam eden bir oturumu var (kısmi unique index).
class ActiveSessionExistsException implements Exception {}

abstract interface class SessionRepository {
  /// Devam eden oturum (setleriyle) ya da null.
  Future<WorkoutSession?> fetchInProgressSession();

  Future<WorkoutSession> fetchSession(String id);

  /// Bitmiş oturumlar (setleriyle), yeniden eskiye.
  Future<List<WorkoutSession>> fetchHistory();

  /// Verilen hareketlerin geçtiği bitmiş oturumlar, yeniden eskiye; her
  /// oturumda yalnızca bu hareketlerin setleri bulunur.
  Future<List<WorkoutSession>> fetchExerciseHistory(Set<String> exerciseIds);

  /// Oturumu ve setleri tek RPC'de yazar, oturum id'sini döner.
  /// Devam eden oturum varsa [ActiveSessionExistsException].
  Future<String> startSession({
    required String? programId,
    required String programName,
    required String workoutName,
    required int workoutPosition,
    required List<SessionSet> sets,
  });

  /// Yalnızca sonuçlar: `weight_kg`, `reps`, `completed_at`.
  Future<void> updateSet(SessionSet set);

  /// Setleri ekler; sunucu id'leriyle döner.
  Future<List<SessionSet>> addSets(String sessionId, List<SessionSet> sets);

  Future<void> deleteSets(List<String> setIds);

  /// Oturumu kapatır, rotasyonu ilerletir, 1RM'leri yazar (tek RPC).
  Future<void> finishSession(String sessionId, Map<String, double> oneRepMaxes);

  Future<void> deleteSession(String sessionId);
}

class SupabaseSessionRepository implements SessionRepository {
  SupabaseSessionRepository(this._client);

  final SupabaseClient _client;

  static const _sessions = 'workout_sessions';
  static const _sets = 'session_sets';
  // session_sets'in exercises'a iki FK'si var (exercise_id, percent_ref_exercise_id).
  static const _setColumns = '*, exercises!exercise_id(name)';
  static const _sessionColumns = '*, session_sets($_setColumns)';
  static const _uniqueViolation = '23505';
  static const _historyLimit = 100;
  static const _exerciseHistoryLimit = 30;

  static List<WorkoutSession> _sessionList(Object? rows) =>
      (rows as List).map((r) => WorkoutSession.fromJson(r as Map<String, dynamic>)).toList();

  @override
  Future<WorkoutSession?> fetchInProgressSession() async {
    final row = await _client
        .from(_sessions)
        .select(_sessionColumns)
        .isFilter('finished_at', null)
        .maybeSingle();
    return row == null ? null : WorkoutSession.fromJson(row);
  }

  @override
  Future<WorkoutSession> fetchSession(String id) async {
    final row = await _client.from(_sessions).select(_sessionColumns).eq('id', id).single();
    return WorkoutSession.fromJson(row);
  }

  @override
  Future<List<WorkoutSession>> fetchHistory() async {
    final rows = await _client
        .from(_sessions)
        .select(_sessionColumns)
        .not('finished_at', 'is', null)
        .order('finished_at', ascending: false)
        .limit(_historyLimit);
    return _sessionList(rows);
  }

  @override
  Future<List<WorkoutSession>> fetchExerciseHistory(Set<String> exerciseIds) async {
    if (exerciseIds.isEmpty) return const [];
    final rows = await _client
        .from(_sessions)
        .select('*, session_sets!inner($_setColumns)')
        .not('finished_at', 'is', null)
        .inFilter('session_sets.exercise_id', exerciseIds.toList())
        .order('finished_at', ascending: false)
        .limit(_exerciseHistoryLimit);
    return _sessionList(rows);
  }

  @override
  Future<String> startSession({
    required String? programId,
    required String programName,
    required String workoutName,
    required int workoutPosition,
    required List<SessionSet> sets,
  }) async {
    try {
      final id = await _client.rpc('start_session', params: {
        'payload': {
          'program_id': programId,
          'program_name': programName,
          'workout_name': workoutName,
          'workout_position': workoutPosition,
          'sets': [for (final s in sets) s.toInsertJson()],
        },
      });
      return id as String;
    } on PostgrestException catch (error) {
      if (error.code == _uniqueViolation) throw ActiveSessionExistsException();
      rethrow;
    }
  }

  @override
  Future<void> updateSet(SessionSet set) async {
    await _client.from(_sets).update({
      'weight_kg': set.weightKg,
      'reps': set.reps,
      'completed_at': set.completedAt?.toUtc().toIso8601String(),
    }).eq('id', set.id!);
  }

  @override
  Future<List<SessionSet>> addSets(String sessionId, List<SessionSet> sets) async {
    final rows = await _client
        .from(_sets)
        .insert([for (final s in sets) {...s.toInsertJson(), 'session_id': sessionId}])
        .select(_setColumns);
    return (rows as List).map((r) => SessionSet.fromJson(r as Map<String, dynamic>)).toList();
  }

  @override
  Future<void> deleteSets(List<String> setIds) async {
    if (setIds.isEmpty) return;
    await _client.from(_sets).delete().inFilter('id', setIds);
  }

  @override
  Future<void> finishSession(String sessionId, Map<String, double> oneRepMaxes) async {
    await _client.rpc('finish_session', params: {
      'p_session_id': sessionId,
      'p_one_rep_maxes': [
        for (final MapEntry(key: exerciseId, value: kg) in oneRepMaxes.entries)
          {'exercise_id': exerciseId, 'weight_kg': kg},
      ],
    });
  }

  @override
  Future<void> deleteSession(String sessionId) async {
    await _client.from(_sessions).delete().eq('id', sessionId);
  }
}
```

- [ ] **Step 2: Provider'ları yaz**

`lib/features/workout/application/session_providers.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase_client.dart';
import '../../onboarding/application/auth_providers.dart';
import '../data/session_repository.dart';
import '../domain/workout_session.dart';

final sessionRepositoryProvider = Provider<SessionRepository>((ref) {
  return SupabaseSessionRepository(AppSupabase.client);
});

/// Ana ekran kartı ve başlatma çakışması için; başlat/bitir/iptal sonrası invalidate edilir.
final inProgressSessionProvider = FutureProvider.autoDispose<WorkoutSession?>((ref) async {
  if (!ref.watch(isLoggedInProvider)) return null;
  return ref.watch(sessionRepositoryProvider).fetchInProgressSession();
});

final sessionHistoryProvider = FutureProvider.autoDispose<List<WorkoutSession>>((ref) async {
  if (!ref.watch(isLoggedInProvider)) return const [];
  return ref.watch(sessionRepositoryProvider).fetchHistory();
});

final sessionDetailProvider = FutureProvider.autoDispose.family<WorkoutSession, String>((ref, id) {
  return ref.watch(sessionRepositoryProvider).fetchSession(id);
});

/// "Şimdi"; testlerde sabit bir fonksiyonla override edilir.
final nowProvider = Provider<DateTime Function()>((ref) => DateTime.now);

/// Saniyede bir "şimdi"; geçen süre ve dinlenme sayacı bunu izler.
/// Widget testlerinde `Stream.value(sabit)` ile override edilmeli.
final clockProvider = StreamProvider.autoDispose<DateTime>((ref) {
  return Stream.periodic(const Duration(seconds: 1), (_) => DateTime.now());
});
```

- [ ] **Step 3: Fake repository'yi ekle**

`test/features/workout/fakes.dart` başına import'ları ekle:

```dart
import 'package:spor_takip/features/workout/data/session_repository.dart';
import 'package:spor_takip/features/workout/domain/workout_session.dart';
```

Dosyanın sonuna ekle:

```dart
class FakeSessionRepository implements SessionRepository {
  FakeSessionRepository({List<WorkoutSession>? sessions})
      : sessions = {for (final s in sessions ?? const <WorkoutSession>[]) s.id: s};

  final Map<String, WorkoutSession> sessions;
  Object? updateError;
  Object? finishError;
  final List<SessionSet> updatedSets = [];
  final List<String> deletedSetIds = [];
  final List<({String sessionId, Map<String, double> oneRepMaxes})> finished = [];
  var _counter = 0;

  String _id(String prefix) => '$prefix-${_counter++}';

  List<WorkoutSession> get _finishedNewestFirst =>
      sessions.values.where((s) => !s.isInProgress).toList()
        ..sort((a, b) => b.finishedAt!.compareTo(a.finishedAt!));

  @override
  Future<WorkoutSession?> fetchInProgressSession() async =>
      sessions.values.where((s) => s.isInProgress).firstOrNull;

  @override
  Future<WorkoutSession> fetchSession(String id) async => sessions[id]!;

  @override
  Future<List<WorkoutSession>> fetchHistory() async => _finishedNewestFirst;

  @override
  Future<List<WorkoutSession>> fetchExerciseHistory(Set<String> exerciseIds) async => [
        for (final s in _finishedNewestFirst)
          if (s.sets.any((x) => exerciseIds.contains(x.exerciseId)))
            s.copyWith(sets: [for (final x in s.sets) if (exerciseIds.contains(x.exerciseId)) x]),
      ];

  @override
  Future<String> startSession({
    required String? programId,
    required String programName,
    required String workoutName,
    required int workoutPosition,
    required List<SessionSet> sets,
  }) async {
    if (sessions.values.any((s) => s.isInProgress)) throw ActiveSessionExistsException();
    final id = _id('session');
    sessions[id] = WorkoutSession(
      id: id,
      programId: programId,
      programName: programName,
      workoutName: workoutName,
      workoutPosition: workoutPosition,
      startedAt: DateTime(2026, 9, 26, 10),
      sets: [for (final s in sets) s.copyWith(id: _id('set'))],
    );
    return id;
  }

  @override
  Future<void> updateSet(SessionSet set) async {
    if (updateError != null) throw updateError!;
    updatedSets.add(set);
    final owner = sessions.values.firstWhere((s) => s.sets.any((x) => x.id == set.id));
    sessions[owner.id] = owner.replaceSet(set);
  }

  @override
  Future<List<SessionSet>> addSets(String sessionId, List<SessionSet> sets) async {
    final added = [for (final s in sets) s.copyWith(id: _id('set'))];
    final session = sessions[sessionId]!;
    sessions[sessionId] = session.copyWith(sets: [...session.sets, ...added]);
    return added;
  }

  @override
  Future<void> deleteSets(List<String> setIds) async {
    deletedSetIds.addAll(setIds);
    for (final s in sessions.values.toList()) {
      sessions[s.id] = s.copyWith(sets: [for (final x in s.sets) if (!setIds.contains(x.id)) x]);
    }
  }

  @override
  Future<void> finishSession(String sessionId, Map<String, double> oneRepMaxes) async {
    if (finishError != null) throw finishError!;
    finished.add((sessionId: sessionId, oneRepMaxes: oneRepMaxes));
    sessions[sessionId] = sessions[sessionId]!.copyWith(finishedAt: DateTime(2026, 9, 26, 11));
  }

  @override
  Future<void> deleteSession(String sessionId) async {
    sessions.remove(sessionId);
  }
}
```

- [ ] **Step 4: Provider testini yaz**

`test/features/workout/application/session_providers_test.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spor_takip/features/onboarding/application/auth_providers.dart';
import 'package:spor_takip/features/workout/application/session_providers.dart';
import 'package:spor_takip/features/workout/domain/workout_session.dart';

import '../fakes.dart';

WorkoutSession _session(String id, {DateTime? finishedAt}) => WorkoutSession(
      id: id,
      programName: 'P',
      workoutName: 'A',
      workoutPosition: 0,
      startedAt: DateTime(2026, 9, 20, 10),
      finishedAt: finishedAt,
    );

void main() {
  ProviderContainer containerWith(FakeSessionRepository repo, {bool loggedIn = true}) {
    final container = ProviderContainer(overrides: [
      isLoggedInProvider.overrideWithValue(loggedIn),
      sessionRepositoryProvider.overrideWithValue(repo),
    ]);
    addTearDown(container.dispose);
    return container;
  }

  test('in-progress session and history come from the repository', () async {
    final repo = FakeSessionRepository(sessions: [
      _session('cur'),
      _session('old', finishedAt: DateTime(2026, 9, 20, 11)),
      _session('older', finishedAt: DateTime(2026, 9, 18, 11)),
    ]);
    final container = containerWith(repo);
    container.listen(inProgressSessionProvider, (_, _) {});
    container.listen(sessionHistoryProvider, (_, _) {});

    expect((await container.read(inProgressSessionProvider.future))!.id, 'cur');
    expect((await container.read(sessionHistoryProvider.future)).map((s) => s.id), ['old', 'older']);
  });

  test('logged out → no session and empty history', () async {
    final container = containerWith(FakeSessionRepository(sessions: [_session('cur')]), loggedIn: false);
    container.listen(inProgressSessionProvider, (_, _) {});
    container.listen(sessionHistoryProvider, (_, _) {});

    expect(await container.read(inProgressSessionProvider.future), isNull);
    expect(await container.read(sessionHistoryProvider.future), isEmpty);
  });
}
```

- [ ] **Step 5: Testlerin geçtiğini doğrula**

Run: `flutter test test/features/workout/application/session_providers_test.dart`
Expected: PASS.

Run: `flutter analyze lib/features/workout test/features/workout`
Expected: `No issues found!`

- [ ] **Step 6: Commit**

```bash
git add lib/features/workout/data/session_repository.dart lib/features/workout/application/session_providers.dart test/features/workout/fakes.dart test/features/workout/application/session_providers_test.dart
git commit -m "feat(workout): add session repository, providers and fake"
```

---

## Task 6: Oturum başlatma servisi

**Files:**
- Create: `lib/features/workout/application/start_session_service.dart`
- Test: `test/features/workout/application/start_session_service_test.dart`

**Interfaces:**
- Consumes: `sessionRepositoryProvider`, `inProgressSessionProvider` (Task 5); `exercisesProvider`, `oneRepMaxRepositoryProvider` (F3); `groupExerciseHistory`, `buildSessionSets`, `buildAddedExerciseSets` (Task 4).
- Produces: `startSessionServiceProvider` (`Provider<StartSessionService>`); `class StartSessionService` — `Future<String> start(Program program, int workoutIndex)` (oturum id'si; `inProgressSessionProvider`'ı invalidate eder; `ActiveSessionExistsException`'ı olduğu gibi fırlatır), `Future<List<SessionSet>> setsForAddedExercise(Exercise exercise, int exercisePosition)`.

- [ ] **Step 1: Başarısız testleri yaz**

`test/features/workout/application/start_session_service_test.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spor_takip/features/onboarding/application/auth_providers.dart';
import 'package:spor_takip/features/workout/application/session_providers.dart';
import 'package:spor_takip/features/workout/application/start_session_service.dart';
import 'package:spor_takip/features/workout/application/workout_providers.dart';
import 'package:spor_takip/features/workout/data/session_repository.dart';
import 'package:spor_takip/features/workout/domain/exercise.dart';
import 'package:spor_takip/features/workout/domain/program.dart';
import 'package:spor_takip/features/workout/domain/program_workout.dart';
import 'package:spor_takip/features/workout/domain/schedule_mode.dart';
import 'package:spor_takip/features/workout/domain/workout_exercise.dart';
import 'package:spor_takip/features/workout/domain/workout_session.dart';

import '../fakes.dart';

const _squat = Exercise(
    id: 'Barbell_Squat', name: 'Barbell Squat', equipment: 'barbell', primaryMuscles: ['quadriceps']);
const _bench = Exercise(id: 'Bench', name: 'Bench Press', equipment: 'barbell', primaryMuscles: ['chest']);

const _program = Program(
  id: 'sl',
  name: 'StrongLifts 5x5',
  scheduleMode: ScheduleMode.rotation,
  workouts: [
    ProgramWorkout(name: 'A', exercises: [
      WorkoutExercise(
          exerciseId: 'Barbell_Squat', exerciseName: 'Barbell Squat', sets: 3, repsMin: 5, repsMax: 5, restSeconds: 180),
      WorkoutExercise(
          exerciseId: 'Bench', exerciseName: 'Bench Press', sets: 1, repsMin: 5, repsMax: 5, isAmrap: true, percent1rm: 75),
    ]),
  ],
);

SessionSet _done(String id, int index) => SessionSet(
      id: id,
      exercisePosition: 0,
      setIndex: index,
      exerciseId: 'Barbell_Squat',
      exerciseName: 'Barbell Squat',
      targetRepsMin: 5,
      targetRepsMax: 5,
      weightKg: 60,
      reps: 5,
      completedAt: DateTime(2026, 9, 20, 10, 30),
    );

final _old = WorkoutSession(
  id: 'old',
  programId: 'sl',
  programName: 'StrongLifts 5x5',
  workoutName: 'A',
  workoutPosition: 0,
  startedAt: DateTime(2026, 9, 20, 10),
  finishedAt: DateTime(2026, 9, 20, 11),
  sets: [_done('o1', 0), _done('o2', 1), _done('o3', 2)],
);

void main() {
  late FakeSessionRepository repo;
  late ProviderContainer container;

  setUp(() {
    repo = FakeSessionRepository(sessions: [_old]);
    container = ProviderContainer(overrides: [
      isLoggedInProvider.overrideWithValue(true),
      sessionRepositoryProvider.overrideWithValue(repo),
      exerciseRepositoryProvider.overrideWithValue(FakeExerciseRepository([_squat, _bench])),
      oneRepMaxRepositoryProvider.overrideWithValue(FakeOneRepMaxRepository()..values['Bench'] = 100),
    ]);
    container.listen(inProgressSessionProvider, (_, _) {});
  });

  tearDown(() => container.dispose());

  test('start writes the session with suggested weights and refreshes the in-progress session', () async {
    expect(await container.read(inProgressSessionProvider.future), isNull);

    final id = await container.read(startSessionServiceProvider).start(_program, 0);

    final session = repo.sessions[id]!;
    expect(session.programId, 'sl');
    expect(session.programName, 'StrongLifts 5x5');
    expect(session.workoutName, 'A');
    expect(session.workoutPosition, 0);
    expect(session.sets.length, 4);
    expect(session.sets.take(3).map((s) => s.suggestedWeightKg), [65, 65, 65]);
    expect(session.sets.last.suggestedWeightKg, 75);
    expect(session.sets.last.isAmrap, isTrue);
    expect((await container.read(inProgressSessionProvider.future))!.id, id);
  });

  test('start rethrows when a session is already in progress', () async {
    await container.read(startSessionServiceProvider).start(_program, 0);
    expect(
      () => container.read(startSessionServiceProvider).start(_program, 0),
      throwsA(isA<ActiveSessionExistsException>()),
    );
  });

  test('sets for an added exercise use its own history', () async {
    final sets = await container.read(startSessionServiceProvider).setsForAddedExercise(_squat, 3);
    expect(sets.length, 3);
    expect(sets.first.exercisePosition, 3);
    expect(sets.first.targetRepsMax, 12);
    // son oturum 5 tekrarla bitti, 8–12 hedefinin üstüne ulaşmadı → aynı kilo
    expect(sets.first.suggestedWeightKg, 60);
  });
}
```

- [ ] **Step 2: Testlerin başarısız olduğunu doğrula**

Run: `flutter test test/features/workout/application/start_session_service_test.dart`
Expected: FAIL — `start_session_service.dart` yok.

- [ ] **Step 3: Servisi yaz**

`lib/features/workout/application/start_session_service.dart`:

```dart
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/exercise.dart';
import '../domain/program.dart';
import '../domain/session_builder.dart';
import '../domain/workout_session.dart';
import 'session_providers.dart';
import 'workout_providers.dart';

final startSessionServiceProvider = Provider<StartSessionService>(StartSessionService.new);

/// Program antrenmanından (veya eklenen hareketten) önerili setler üretir.
class StartSessionService {
  StartSessionService(this._ref);

  final Ref _ref;

  Future<(ExerciseHistory, Map<String, Exercise>)> _context(Set<String> exerciseIds) async {
    final (sessions, exercises) = await (
      _ref.read(sessionRepositoryProvider).fetchExerciseHistory(exerciseIds),
      _ref.read(exercisesProvider.future),
    ).wait;
    return (groupExerciseHistory(sessions), {for (final e in exercises) e.id: e});
  }

  /// Programın [workoutIndex]'teki antrenmanını başlatır, oturum id'sini döner.
  /// Devam eden oturum varsa `ActiveSessionExistsException` fırlatır.
  Future<String> start(Program program, int workoutIndex) async {
    final workout = program.workouts[workoutIndex];
    final (history, exercises) = await _context({for (final b in workout.exercises) b.exerciseId});
    final oneRepMaxes = await _ref.read(oneRepMaxRepositoryProvider).fetchOneRepMaxes();
    final sets = buildSessionSets(
      workout: workout,
      oneRepMaxes: oneRepMaxes,
      history: history,
      exercises: exercises,
    );
    final id = await _ref.read(sessionRepositoryProvider).startSession(
          programId: program.id,
          programName: program.name,
          workoutName: workout.name,
          workoutPosition: workoutIndex,
          sets: sets,
        );
    _ref.invalidate(inProgressSessionProvider);
    return id;
  }

  Future<List<SessionSet>> setsForAddedExercise(Exercise exercise, int exercisePosition) async {
    final (history, exercises) = await _context({exercise.id});
    return buildAddedExerciseSets(
      exercise: exercise,
      exercisePosition: exercisePosition,
      history: history,
      exercises: exercises,
    );
  }
}
```

- [ ] **Step 4: Testlerin geçtiğini doğrula**

Run: `flutter test test/features/workout/application/start_session_service_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/workout/application/start_session_service.dart test/features/workout/application/start_session_service_test.dart
git commit -m "feat(workout): add start session service with suggested weights"
```

---

## Task 7: Oturum notifier'ı ve dinlenme sayacı

**Files:**
- Create: `lib/features/workout/application/session_notifier.dart`, `lib/features/workout/application/rest_timer.dart`
- Test: `test/features/workout/application/session_notifier_test.dart`, `test/features/workout/application/rest_timer_test.dart`

**Interfaces:**
- Consumes: `sessionRepositoryProvider`, `inProgressSessionProvider`, `sessionHistoryProvider`, `nowProvider` (Task 5); `startSessionServiceProvider` (Task 6); `activeProgramStateProvider`, `oneRepMaxesProvider` (F3).
- Produces:
  - `sessionNotifierProvider` — `AsyncNotifierProvider.autoDispose.family<SessionNotifier, WorkoutSession, String>`; `SessionNotifier` metotları: `void setWeight(String setId, double? weightKg)`, `void setReps(String setId, int? reps)`, `Future<bool> complete(String setId)`, `Future<bool> uncomplete(String setId)`, `Future<bool> addExercise(Exercise exercise)`, `Future<bool> removeExercise(int exercisePosition)`, `Future<void> cancel()`, `Future<void> finish(Map<String, double> oneRepMaxes)` (hata fırlatır).
  - `restTimerProvider` — `NotifierProvider.autoDispose<RestTimerNotifier, DateTime?>` (dinlenmenin bittiği an); `RestTimerNotifier.defaultSeconds = 90`, `void start(int? seconds)`, `void addSeconds(int seconds)`, `void stop()`.

- [ ] **Step 1: Başarısız testleri yaz**

`test/features/workout/application/session_notifier_test.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spor_takip/features/onboarding/application/auth_providers.dart';
import 'package:spor_takip/features/workout/application/session_notifier.dart';
import 'package:spor_takip/features/workout/application/session_providers.dart';
import 'package:spor_takip/features/workout/application/workout_providers.dart';
import 'package:spor_takip/features/workout/domain/exercise.dart';
import 'package:spor_takip/features/workout/domain/workout_session.dart';

import '../fakes.dart';

const _bench = Exercise(id: 'Bench', name: 'Bench Press', equipment: 'barbell', primaryMuscles: ['chest']);

SessionSet _s(
  String id, {
  int pos = 0,
  int idx = 0,
  String exercise = 'Barbell_Squat',
  double? suggested = 60,
  double? pct,
  bool amrap = false,
  bool done = false,
  double? weight,
  int? reps,
  int max = 5,
}) {
  return SessionSet(
    id: id,
    exercisePosition: pos,
    setIndex: idx,
    exerciseId: exercise,
    exerciseName: exercise,
    targetRepsMin: 5,
    targetRepsMax: max,
    isAmrap: amrap,
    percent1rm: pct,
    restSeconds: 90,
    suggestedWeightKg: suggested,
    weightKg: weight,
    reps: reps,
    completedAt: done ? DateTime(2026, 9, 26, 10, 5) : null,
  );
}

WorkoutSession _session(String id, List<SessionSet> sets, {DateTime? finishedAt}) => WorkoutSession(
      id: id,
      programId: 'p1',
      programName: 'SL',
      workoutName: 'A',
      workoutPosition: 0,
      startedAt: DateTime(2026, 9, 26, 10),
      finishedAt: finishedAt,
      sets: sets,
    );

void main() {
  late FakeSessionRepository repo;
  late ProviderContainer container;

  void setUpWith(List<SessionSet> sets, {List<WorkoutSession> history = const []}) {
    repo = FakeSessionRepository(sessions: [_session('sess', sets), ...history]);
    container = ProviderContainer(overrides: [
      isLoggedInProvider.overrideWithValue(true),
      sessionRepositoryProvider.overrideWithValue(repo),
      exerciseRepositoryProvider.overrideWithValue(FakeExerciseRepository([_bench])),
      oneRepMaxRepositoryProvider.overrideWithValue(FakeOneRepMaxRepository()),
    ]);
    addTearDown(container.dispose);
    container.listen(sessionNotifierProvider('sess'), (_, _) {});
  }

  Future<void> load() => container.read(sessionNotifierProvider('sess').future);
  SessionNotifier notifier() => container.read(sessionNotifierProvider('sess').notifier);
  WorkoutSession current() => container.read(sessionNotifierProvider('sess')).requireValue;

  test('complete saves the suggested weight and target reps', () async {
    setUpWith([_s('a'), _s('b', idx: 1)]);
    await load();

    expect(await notifier().complete('a'), isTrue);

    final saved = repo.updatedSets.single;
    expect(saved.id, 'a');
    expect(saved.weightKg, 60);
    expect(saved.reps, 5);
    expect(saved.completedAt, isNotNull);
    expect(current().setById('a').isCompleted, isTrue);
  });

  test('a failed save reverts the set', () async {
    setUpWith([_s('a')]);
    await load();
    repo.updateError = Exception('offline');

    expect(await notifier().complete('a'), isFalse);

    expect(current().setById('a').isCompleted, isFalse);
    expect(current().setById('a').weightKg, isNull);
  });

  test('an AMRAP set without reps cannot be completed', () async {
    setUpWith([_s('a', amrap: true)]);
    await load();

    expect(await notifier().complete('a'), isFalse);
    expect(repo.updatedSets, isEmpty);

    notifier().setReps('a', 8);
    expect(await notifier().complete('a'), isTrue);
    expect(repo.updatedSets.single.reps, 8);
  });

  test('uncomplete clears completion but keeps the values', () async {
    setUpWith([_s('a', done: true, weight: 60, reps: 5)]);
    await load();

    expect(await notifier().uncomplete('a'), isTrue);

    final set = current().setById('a');
    expect(set.isCompleted, isFalse);
    expect(set.weightKg, 60);
    expect(repo.updatedSets.single.completedAt, isNull);
  });

  test('editing the first pending weight fills the following pending sets of the lift', () async {
    setUpWith([_s('a'), _s('b', idx: 1), _s('c', pos: 1, exercise: 'Bench')]);
    await load();

    notifier().setWeight('a', 65);
    expect(current().setById('a').weightKg, 65);
    expect(current().setById('b').weightKg, 65);
    expect(current().setById('c').weightKg, isNull);

    notifier().setWeight('b', 70);
    expect(current().setById('a').weightKg, 65, reason: 'b is not the first pending set');
    expect(current().setById('b').weightKg, 70);
  });

  test('propagation starts at the first pending set and skips other percentages', () async {
    setUpWith([
      _s('done', done: true, weight: 60, reps: 5),
      _s('p1', idx: 1, pct: 65),
      _s('p2', idx: 2, pct: 65),
      _s('p3', idx: 3, pct: 85),
    ]);
    await load();

    notifier().setWeight('p1', 50);
    expect(current().setById('p2').weightKg, 50);
    expect(current().setById('p3').weightKg, isNull);
    expect(current().setById('done').weightKg, 60);
  });

  test('addExercise appends three suggested sets at the next position', () async {
    final old = _session(
      'old',
      [for (var i = 0; i < 3; i++) _s('o$i', idx: i, exercise: 'Bench', done: true, weight: 40, reps: 8, max: 12)],
      finishedAt: DateTime(2026, 9, 20, 11),
    );
    setUpWith([_s('a')], history: [old]);
    await load();

    expect(await notifier().addExercise(_bench), isTrue);

    final groups = current().exerciseGroups;
    expect(groups.length, 2);
    expect(groups.last.length, 3);
    expect(groups.last.first.exercisePosition, 1);
    expect(groups.last.first.exerciseName, 'Bench Press');
    expect(groups.last.first.suggestedWeightKg, 40);
    expect(groups.last.every((s) => s.id != null), isTrue);
  });

  test('removeExercise deletes only pending sets', () async {
    setUpWith([_s('a', done: true, weight: 60, reps: 5), _s('b', idx: 1), _s('c', pos: 1, exercise: 'Bench')]);
    await load();

    expect(await notifier().removeExercise(0), isTrue);

    expect(repo.deletedSetIds, ['b']);
    expect(current().sets.map((s) => s.id), ['a', 'c']);
  });

  test('cancel deletes the session', () async {
    setUpWith([_s('a')]);
    await load();

    await notifier().cancel();

    expect(repo.sessions.containsKey('sess'), isFalse);
  });

  test('finish passes the approved 1RMs', () async {
    setUpWith([_s('a', done: true, weight: 60, reps: 5)]);
    await load();

    await notifier().finish({'Barbell_Squat': 105});

    expect(repo.finished.single.sessionId, 'sess');
    expect(repo.finished.single.oneRepMaxes, {'Barbell_Squat': 105});
  });

  test('finish rethrows repository errors', () async {
    setUpWith([_s('a', done: true, weight: 60, reps: 5)]);
    await load();
    repo.finishError = Exception('offline');

    expect(() => notifier().finish(const {}), throwsException);
  });
}
```

`test/features/workout/application/rest_timer_test.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spor_takip/features/workout/application/rest_timer.dart';
import 'package:spor_takip/features/workout/application/session_providers.dart';

void main() {
  final now = DateTime(2026, 9, 26, 10);

  test('start, extend and stop', () {
    final container = ProviderContainer(overrides: [nowProvider.overrideWithValue(() => now)]);
    addTearDown(container.dispose);
    container.listen(restTimerProvider, (_, _) {});
    final timer = container.read(restTimerProvider.notifier);

    expect(container.read(restTimerProvider), isNull);

    timer.start(null);
    expect(container.read(restTimerProvider), now.add(const Duration(seconds: 90)));

    timer.start(60);
    expect(container.read(restTimerProvider), now.add(const Duration(seconds: 60)));

    timer.addSeconds(30);
    expect(container.read(restTimerProvider), now.add(const Duration(seconds: 90)));

    timer.stop();
    expect(container.read(restTimerProvider), isNull);

    timer.addSeconds(30);
    expect(container.read(restTimerProvider), isNull, reason: 'extending a stopped timer does nothing');
  });
}
```

- [ ] **Step 2: Testlerin başarısız olduğunu doğrula**

Run: `flutter test test/features/workout/application/session_notifier_test.dart test/features/workout/application/rest_timer_test.dart`
Expected: FAIL — `session_notifier.dart`, `rest_timer.dart` yok.

- [ ] **Step 3: Notifier'ı yaz**

`lib/features/workout/application/session_notifier.dart`:

```dart
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/session_repository.dart';
import '../domain/exercise.dart';
import '../domain/workout_session.dart';
import 'session_providers.dart';
import 'start_session_service.dart';
import 'workout_providers.dart';

final sessionNotifierProvider =
    AsyncNotifierProvider.autoDispose.family<SessionNotifier, WorkoutSession, String>(SessionNotifier.new);

/// Antrenman ekranının state'i. Kilo/tekrar kutuları yalnızca yerel; ✓ ile
/// set anında sunucuya yazılır (iyimser; hata olursa geri alınır).
class SessionNotifier extends AsyncNotifier<WorkoutSession> {
  SessionNotifier(this.sessionId);

  final String sessionId;

  SessionRepository get _repo => ref.read(sessionRepositoryProvider);
  WorkoutSession get _session => state.requireValue;

  @override
  Future<WorkoutSession> build() => ref.watch(sessionRepositoryProvider).fetchSession(sessionId);

  void _replaceAll(Iterable<SessionSet> updated) {
    final byId = {for (final s in updated) s.id: s};
    state = AsyncData(_session.copyWith(sets: [for (final s in _session.sets) byId[s.id] ?? s]));
  }

  /// Hareketin ilk yapılmamış setiyse, aynı hareketin aynı yüzdeli diğer
  /// yapılmamış setlerine de yayılır.
  void setWeight(String setId, double? weightKg) {
    final target = _session.setById(setId);
    final pending = [
      for (final s in _session.sets)
        if (s.exercisePosition == target.exercisePosition && !s.isCompleted) s,
    ];
    final isFirstPending = pending.isNotEmpty && pending.first.id == setId;
    final affected = isFirstPending ? pending.where((s) => s.percent1rm == target.percent1rm) : [target];
    _replaceAll([for (final s in affected) s.copyWith(weightKg: weightKg, clearWeight: weightKg == null)]);
  }

  void setReps(String setId, int? reps) {
    _replaceAll([_session.setById(setId).copyWith(reps: reps, clearReps: reps == null)]);
  }

  /// Kutudaki değerlerle seti tamamlar. Tekrar bilinmiyorsa (boş AMRAP) veya
  /// yazılamazsa false.
  Future<bool> complete(String setId) {
    final before = _session.setById(setId);
    final reps = before.displayReps;
    if (reps == null) return Future.value(false);
    return _save(
      before,
      before.copyWith(weightKg: before.displayWeightKg, reps: reps, completedAt: DateTime.now()),
    );
  }

  Future<bool> uncomplete(String setId) {
    final before = _session.setById(setId);
    return _save(before, before.copyWith(clearCompletedAt: true));
  }

  Future<bool> _save(SessionSet before, SessionSet after) async {
    _replaceAll([after]);
    try {
      await _repo.updateSet(after);
      return true;
    } catch (e, st) {
      debugPrint('SessionNotifier.updateSet failed: $e\n$st');
      _replaceAll([before]);
      return false;
    }
  }

  Future<bool> addExercise(Exercise exercise) async {
    try {
      final sets = await ref
          .read(startSessionServiceProvider)
          .setsForAddedExercise(exercise, _session.nextExercisePosition);
      final added = await _repo.addSets(sessionId, sets);
      state = AsyncData(_session.copyWith(sets: [..._session.sets, ...added]));
      return true;
    } catch (e, st) {
      debugPrint('SessionNotifier.addExercise failed: $e\n$st');
      return false;
    }
  }

  /// Hareketin yapılmamış setlerini siler; yapılmışlar kalır.
  Future<bool> removeExercise(int exercisePosition) async {
    final ids = [
      for (final s in _session.sets)
        if (s.exercisePosition == exercisePosition && !s.isCompleted) s.id!,
    ];
    try {
      await _repo.deleteSets(ids);
      state = AsyncData(_session.copyWith(sets: [for (final s in _session.sets) if (!ids.contains(s.id)) s]));
      return true;
    } catch (e, st) {
      debugPrint('SessionNotifier.removeExercise failed: $e\n$st');
      return false;
    }
  }

  Future<void> cancel() async {
    await _repo.deleteSession(sessionId);
    ref.invalidate(inProgressSessionProvider);
  }

  /// Oturumu kapatır ve onaylanan 1RM'leri yazar (tek RPC). Hata fırlatır.
  Future<void> finish(Map<String, double> oneRepMaxes) async {
    await _repo.finishSession(sessionId, oneRepMaxes);
    ref
      ..invalidate(inProgressSessionProvider)
      ..invalidate(sessionHistoryProvider)
      ..invalidate(activeProgramStateProvider)
      ..invalidate(oneRepMaxesProvider);
  }
}
```

- [ ] **Step 4: Dinlenme sayacını yaz**

`lib/features/workout/application/rest_timer.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'session_providers.dart';

/// Dinlenmenin bittiği an; null = sayaç kapalı. Oturum ekranı kapanınca sıfırlanır.
final restTimerProvider = NotifierProvider.autoDispose<RestTimerNotifier, DateTime?>(RestTimerNotifier.new);

class RestTimerNotifier extends Notifier<DateTime?> {
  static const defaultSeconds = 90;

  @override
  DateTime? build() => null;

  void start(int? seconds) {
    state = ref.read(nowProvider)().add(Duration(seconds: seconds ?? defaultSeconds));
  }

  void addSeconds(int seconds) {
    final endsAt = state;
    if (endsAt != null) state = endsAt.add(Duration(seconds: seconds));
  }

  void stop() => state = null;
}
```

- [ ] **Step 5: Testlerin geçtiğini doğrula**

Run: `flutter test test/features/workout/application/`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/features/workout/application/session_notifier.dart lib/features/workout/application/rest_timer.dart test/features/workout/application/session_notifier_test.dart test/features/workout/application/rest_timer_test.dart
git commit -m "feat(workout): add session notifier with optimistic set logging and rest timer"
```

---

## Task 8: Antrenman ekranı, set satırı ve dinlenme çubuğu

**Files:**
- Create: `lib/features/workout/presentation/session_screen.dart`, `lib/features/workout/presentation/widgets/set_row.dart`, `lib/features/workout/presentation/widgets/rest_timer_bar.dart`
- Modify: `lib/core/router.dart`, `assets/translations/tr.json`, `assets/translations/en.json`
- Test: `test/features/workout/presentation/session_screen_test.dart`

**Interfaces:**
- Consumes: `sessionNotifierProvider`, `restTimerProvider` (Task 7); `clockProvider`, `nowProvider` (Task 5); `completedSetCount`, `sessionDuration`, `formatDuration` (Task 2); `trimNumber`, `sessionSetTargetLabel` (Task 2); `ExercisePickerScreen` (F3, `context.pop(Exercise)` ile döner).
- Produces:
  - `class SessionScreen extends ConsumerWidget { const SessionScreen({super.key, required String sessionId}); }` — rota `/session/:id`.
  - `class SetRow extends StatefulWidget` (`set`, `number`, `onWeightChanged`, `onRepsChanged`, `onToggle`).
  - `class RestTimerBar extends ConsumerWidget`.
  - Rotalar: `/session/:id`, `/session/:id/exercises` (hareket seçici), `/session/:id/summary` (Task 9'da ekrana bağlanır; bu görevde `SessionScreen` push eder).
  - Key'ler: `session_screen`, `session_elapsed`, `session_finish_button`, `session_menu`, `session_cancel_item`, `session_cancel_dialog`, `session_cancel_confirm`, `session_no_sets_dialog`, `session_no_sets_cancel`, `session_add_exercise`, `session_exercise_<pos>`, `session_exercise_menu_<pos>`, `session_remove_exercise_<pos>`, `set_weight_<id>`, `set_reps_<id>`, `set_check_<id>`, `set_deloaded_<id>`, `rest_timer_bar`, `rest_timer_remaining`, `rest_timer_add`, `rest_timer_skip`.
  - Çeviriler: `workout.session.*` (Task 9 ve 11'in anahtarları dahil).

- [ ] **Step 1: Çevirileri ekle**

`assets/translations/tr.json` → `workout` nesnesinde son anahtar `"today_load_error": "Antrenman bilgisi yüklenemedi"` satırının sonuna virgül koy ve ardından ekle:

```json
    "session": {
      "start": "Başla",
      "resume": "Devam et",
      "started_at": "{time} başladı",
      "finish": "Bitir",
      "cancel": "Antrenmanı iptal et",
      "cancel_confirm_title": "Antrenman iptal edilsin mi?",
      "cancel_confirm_body": "Bu antrenmanın tüm setleri silinecek.",
      "cancel_confirm": "İptal et",
      "no_sets_title": "Hiç set tamamlanmadı",
      "no_sets_body": "Antrenmanı iptal etmek ister misin?",
      "add_exercise": "Hareket ekle",
      "remove_exercise": "Hareketi çıkar",
      "set_label": "Set {n}",
      "deloaded": "3 kez başarısız, kilo düşürüldü",
      "save_error": "Kaydedilemedi, tekrar dene",
      "reps_required": "Önce tekrar sayısını gir",
      "load_error": "Antrenman yüklenemedi",
      "rest": "Dinlenme",
      "rest_add": "+30 sn",
      "rest_skip": "Atla",
      "conflict_title": "Devam eden bir antrenmanın var",
      "conflict_replace": "İptal et, yenisini başlat",
      "summary_title": "Antrenman özeti",
      "summary_duration": "Süre",
      "summary_sets": "Tamamlanan set",
      "summary_volume": "Toplam hacim",
      "summary_one_rep_max": "1RM önerileri",
      "save": "Kaydet"
    }
```

`assets/translations/en.json` → aynı yerde (`"today_load_error": "Could not load today's workout"` satırından sonra, virgülle):

```json
    "session": {
      "start": "Start",
      "resume": "Resume",
      "started_at": "Started {time}",
      "finish": "Finish",
      "cancel": "Cancel workout",
      "cancel_confirm_title": "Cancel this workout?",
      "cancel_confirm_body": "All sets of this workout will be deleted.",
      "cancel_confirm": "Cancel workout",
      "no_sets_title": "No sets completed",
      "no_sets_body": "Do you want to cancel the workout?",
      "add_exercise": "Add exercise",
      "remove_exercise": "Remove exercise",
      "set_label": "Set {n}",
      "deloaded": "Failed 3 times, weight reduced",
      "save_error": "Could not save, try again",
      "reps_required": "Enter the reps first",
      "load_error": "Could not load the workout",
      "rest": "Rest",
      "rest_add": "+30 s",
      "rest_skip": "Skip",
      "conflict_title": "You have a workout in progress",
      "conflict_replace": "Cancel it and start new",
      "summary_title": "Workout summary",
      "summary_duration": "Duration",
      "summary_sets": "Completed sets",
      "summary_volume": "Total volume",
      "summary_one_rep_max": "1RM suggestions",
      "save": "Save"
    }
```

Doğrula: `python -c "import json;[json.load(open(f'assets/translations/{x}.json',encoding='utf-8')) for x in ('tr','en')];print('ok')"` → `ok`.

- [ ] **Step 2: Başarısız widget testlerini yaz**

`test/features/workout/presentation/session_screen_test.dart`:

```dart
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spor_takip/features/onboarding/application/auth_providers.dart';
import 'package:spor_takip/features/workout/application/session_providers.dart';
import 'package:spor_takip/features/workout/application/workout_providers.dart';
import 'package:spor_takip/features/workout/domain/exercise.dart';
import 'package:spor_takip/features/workout/domain/workout_session.dart';
import 'package:spor_takip/features/workout/presentation/session_screen.dart';

import '../fakes.dart';

const _bench = Exercise(id: 'Bench', name: 'Bench Press', equipment: 'barbell', primaryMuscles: ['chest']);
final _now = DateTime(2026, 9, 26, 10, 30);

SessionSet _s(String id, {int idx = 0, bool deloaded = false}) => SessionSet(
      id: id,
      exercisePosition: 0,
      setIndex: idx,
      exerciseId: 'Barbell_Squat',
      exerciseName: 'Barbell Squat',
      targetRepsMin: 5,
      targetRepsMax: 5,
      restSeconds: 90,
      suggestedWeightKg: 60,
      deloaded: deloaded,
    );

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  late FakeSessionRepository repo;

  setUp(() {
    repo = FakeSessionRepository(sessions: [
      WorkoutSession(
        id: 'sess',
        programId: 'p1',
        programName: 'StrongLifts 5x5',
        workoutName: 'Antrenman A',
        workoutPosition: 0,
        startedAt: DateTime(2026, 9, 26, 10),
        sets: [_s('a'), _s('b', idx: 1, deloaded: true)],
      ),
    ]);
  });

  Widget wrap() {
    final router = GoRouter(initialLocation: '/session/sess', routes: [
      GoRoute(path: '/home', builder: (context, state) => const Text('HOME')),
      GoRoute(
        path: '/session/:id',
        builder: (context, state) => SessionScreen(sessionId: state.pathParameters['id']!),
        routes: [
          GoRoute(path: 'summary', builder: (context, state) => const Text('SUMMARY')),
          GoRoute(
            path: 'exercises',
            builder: (context, state) => Builder(
              builder: (ctx) => TextButton(onPressed: () => ctx.pop(_bench), child: const Text('PICK')),
            ),
          ),
        ],
      ),
    ]);
    return EasyLocalization(
      supportedLocales: const [Locale('tr'), Locale('en')],
      path: 'assets/translations',
      fallbackLocale: const Locale('tr'),
      child: ProviderScope(
        overrides: [
          isLoggedInProvider.overrideWithValue(true),
          sessionRepositoryProvider.overrideWithValue(repo),
          exerciseRepositoryProvider.overrideWithValue(FakeExerciseRepository([_bench])),
          oneRepMaxRepositoryProvider.overrideWithValue(FakeOneRepMaxRepository()),
          nowProvider.overrideWithValue(() => _now),
          clockProvider.overrideWith((ref) => Stream.value(_now)),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
  }

  String fieldText(WidgetTester tester, String key) =>
      tester.widget<TextField>(find.byKey(Key(key))).controller!.text;

  Future<void> open(WidgetTester tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();
  }

  testWidgets('shows the exercise with prefilled values, elapsed time and deload note', (tester) async {
    await open(tester);

    expect(find.byKey(const Key('session_screen')), findsOneWidget);
    expect(find.text('Barbell Squat'), findsOneWidget);
    expect(fieldText(tester, 'set_weight_a'), '60');
    expect(fieldText(tester, 'set_reps_a'), '5');
    expect(find.text('30:00'), findsOneWidget);
    expect(find.byKey(const Key('set_deloaded_b')), findsOneWidget);
    expect(find.byKey(const Key('set_deloaded_a')), findsNothing);
  });

  testWidgets('checking a set saves it and starts the rest timer', (tester) async {
    await open(tester);

    await tester.tap(find.byKey(const Key('set_check_a')));
    await tester.pumpAndSettle();

    expect(repo.updatedSets.single.weightKg, 60);
    expect(repo.updatedSets.single.reps, 5);
    expect(find.byKey(const Key('rest_timer_bar')), findsOneWidget);
    expect(find.text('01:30'), findsOneWidget);

    await tester.tap(find.byKey(const Key('rest_timer_add')));
    await tester.pumpAndSettle();
    expect(find.text('02:00'), findsOneWidget);

    await tester.tap(find.byKey(const Key('rest_timer_skip')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('rest_timer_bar')), findsNothing);
  });

  testWidgets('a failed save reverts the check and shows an error', (tester) async {
    repo.updateError = Exception('offline');
    await open(tester);

    await tester.tap(find.byKey(const Key('set_check_a')));
    await tester.pumpAndSettle();

    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.byKey(const Key('rest_timer_bar')), findsNothing);
    expect(
      find.descendant(of: find.byKey(const Key('set_check_a')), matching: find.byIcon(Icons.check_circle_outline)),
      findsOneWidget,
    );
  });

  testWidgets('editing the first weight fills the following set', (tester) async {
    await open(tester);

    await tester.enterText(find.byKey(const Key('set_weight_a')), '65');
    await tester.pumpAndSettle();

    expect(fieldText(tester, 'set_weight_b'), '65');
  });

  testWidgets('adding an exercise appends its card', (tester) async {
    await open(tester);

    await tester.tap(find.byKey(const Key('session_add_exercise')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('PICK'));
    await tester.pumpAndSettle();

    expect(find.text('Bench Press'), findsOneWidget);
    expect(find.byKey(const Key('session_exercise_1')), findsOneWidget);
  });

  testWidgets('removing an exercise drops its pending sets', (tester) async {
    await open(tester);

    await tester.tap(find.byKey(const Key('session_exercise_menu_0')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('session_remove_exercise_0')));
    await tester.pumpAndSettle();

    expect(find.text('Barbell Squat'), findsNothing);
    expect(repo.deletedSetIds, ['a', 'b']);
  });

  testWidgets('cancel deletes the session after confirmation and goes home', (tester) async {
    await open(tester);

    await tester.tap(find.byKey(const Key('session_menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('session_cancel_item')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('session_cancel_confirm')));
    await tester.pumpAndSettle();

    expect(repo.sessions, isEmpty);
    expect(find.text('HOME'), findsOneWidget);
  });

  testWidgets('finish without completed sets offers to cancel', (tester) async {
    await open(tester);

    await tester.tap(find.byKey(const Key('session_finish_button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('session_no_sets_dialog')), findsOneWidget);

    await tester.tap(find.byKey(const Key('session_no_sets_cancel')));
    await tester.pumpAndSettle();
    expect(find.text('HOME'), findsOneWidget);
  });

  testWidgets('finish with completed sets opens the summary', (tester) async {
    await open(tester);

    await tester.tap(find.byKey(const Key('set_check_a')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('session_finish_button')));
    await tester.pumpAndSettle();

    expect(find.text('SUMMARY'), findsOneWidget);
  });
}
```

- [ ] **Step 3: Testlerin başarısız olduğunu doğrula**

Run: `flutter test test/features/workout/presentation/session_screen_test.dart`
Expected: FAIL — `session_screen.dart` yok.

- [ ] **Step 4: Set satırını yaz**

`lib/features/workout/presentation/widgets/set_row.dart`:

```dart
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../domain/block_format.dart';
import '../../domain/workout_session.dart';

String _weightText(SessionSet set) {
  final kg = set.displayWeightKg;
  return kg == null ? '' : trimNumber(kg);
}

String _repsText(SessionSet set) => set.displayReps?.toString() ?? '';

/// `Set n · hedef · [kilo] kg · [tekrar] · ✓`. Tamamlanmış satırın kutuları
/// kilitlidir; ✓'ye tekrar basınca işaret kalkar ve düzenlenebilir.
class SetRow extends StatefulWidget {
  const SetRow({
    super.key,
    required this.set,
    required this.number,
    required this.onWeightChanged,
    required this.onRepsChanged,
    required this.onToggle,
  });

  final SessionSet set;
  final int number;
  final ValueChanged<double?> onWeightChanged;
  final ValueChanged<int?> onRepsChanged;
  final VoidCallback onToggle;

  @override
  State<SetRow> createState() => _SetRowState();
}

class _SetRowState extends State<SetRow> {
  late final _weight = TextEditingController(text: _weightText(widget.set));
  late final _reps = TextEditingController(text: _repsText(widget.set));
  final _weightFocus = FocusNode();
  final _repsFocus = FocusNode();

  @override
  void didUpdateWidget(SetRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Başka satırdan yayılan kilo ya da geri alınan değer; yazılan kutuya dokunma.
    _sync(_weight, _weightFocus, _weightText(widget.set));
    _sync(_reps, _repsFocus, _repsText(widget.set));
  }

  void _sync(TextEditingController controller, FocusNode focus, String text) {
    if (!focus.hasFocus && controller.text != text) controller.text = text;
  }

  @override
  void dispose() {
    _weight.dispose();
    _reps.dispose();
    _weightFocus.dispose();
    _repsFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final set = widget.set;
    final done = set.isCompleted;
    final colors = Theme.of(context).colorScheme;
    return Container(
      color: done ? colors.primaryContainer.withValues(alpha: 0.4) : null,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 56,
                child: Text('workout.session.set_label'.tr(namedArgs: {'n': '${widget.number}'})),
              ),
              Expanded(child: Text(sessionSetTargetLabel(set))),
              SizedBox(
                width: 80,
                child: TextField(
                  key: Key('set_weight_${set.id}'),
                  controller: _weight,
                  focusNode: _weightFocus,
                  enabled: !done,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                  decoration: const InputDecoration(isDense: true, suffixText: 'kg'),
                  onChanged: (text) => widget.onWeightChanged(double.tryParse(text.replaceAll(',', '.'))),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 56,
                child: TextField(
                  key: Key('set_reps_${set.id}'),
                  controller: _reps,
                  focusNode: _repsFocus,
                  enabled: !done,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(isDense: true, hintText: set.isAmrap ? '+' : null),
                  onChanged: (text) => widget.onRepsChanged(int.tryParse(text)),
                ),
              ),
              IconButton(
                key: Key('set_check_${set.id}'),
                onPressed: widget.onToggle,
                color: done ? colors.primary : null,
                icon: Icon(done ? Icons.check_circle : Icons.check_circle_outline),
              ),
            ],
          ),
          if (set.deloaded && !done)
            Text(
              'workout.session.deloaded'.tr(),
              key: Key('set_deloaded_${set.id}'),
              style: Theme.of(context).textTheme.bodySmall,
            ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 5: Dinlenme çubuğunu yaz**

`lib/features/workout/presentation/widgets/rest_timer_bar.dart`:

```dart
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/rest_timer.dart';
import '../../application/session_providers.dart';
import '../../domain/session_stats.dart';

/// Set işaretlenince görünen geri sayım. Süre dolunca titreşim + sistem sesi.
/// Yalnızca uygulama açıkken çalışır (bildirimler F6'da).
class RestTimerBar extends ConsumerWidget {
  const RestTimerBar({super.key});

  void _alarm(BuildContext context, WidgetRef ref) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) return;
      HapticFeedback.vibrate();
      SystemSound.play(SystemSoundType.alert);
      ref.read(restTimerProvider.notifier).stop();
    });
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final endsAt = ref.watch(restTimerProvider);
    if (endsAt == null) return const SizedBox.shrink();
    final now = ref.watch(clockProvider).value ?? ref.watch(nowProvider)();
    final remaining = endsAt.difference(now);
    if (remaining <= Duration.zero) {
      _alarm(context, ref);
      return const SizedBox.shrink();
    }
    final timer = ref.read(restTimerProvider.notifier);
    return Material(
      key: const Key('rest_timer_bar'),
      color: Theme.of(context).colorScheme.secondaryContainer,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              const Icon(Icons.timer_outlined),
              const SizedBox(width: 8),
              Text('workout.session.rest'.tr()),
              const SizedBox(width: 8),
              Text(
                formatDuration(remaining),
                key: const Key('rest_timer_remaining'),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const Spacer(),
              TextButton(
                key: const Key('rest_timer_add'),
                onPressed: () => timer.addSeconds(30),
                child: Text('workout.session.rest_add'.tr()),
              ),
              TextButton(
                key: const Key('rest_timer_skip'),
                onPressed: timer.stop,
                child: Text('workout.session.rest_skip'.tr()),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 6: Antrenman ekranını yaz**

`lib/features/workout/presentation/session_screen.dart`:

```dart
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../application/rest_timer.dart';
import '../application/session_notifier.dart';
import '../application/session_providers.dart';
import '../domain/exercise.dart';
import '../domain/session_stats.dart';
import '../domain/workout_session.dart';
import 'widgets/rest_timer_bar.dart';
import 'widgets/set_row.dart';

class SessionScreen extends ConsumerWidget {
  const SessionScreen({super.key, required this.sessionId});

  final String sessionId;

  SessionNotifier _notifier(WidgetRef ref) => ref.read(sessionNotifierProvider(sessionId).notifier);

  void _snack(BuildContext context, String key) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(key.tr())));
  }

  Future<void> _complete(BuildContext context, WidgetRef ref, SessionSet set) async {
    if (set.displayReps == null) {
      _snack(context, 'workout.session.reps_required');
      return;
    }
    final ok = await _notifier(ref).complete(set.id!);
    if (!context.mounted) return;
    if (ok) {
      ref.read(restTimerProvider.notifier).start(set.restSeconds);
    } else {
      _snack(context, 'workout.session.save_error');
    }
  }

  Future<void> _uncomplete(BuildContext context, WidgetRef ref, SessionSet set) async {
    final ok = await _notifier(ref).uncomplete(set.id!);
    if (!ok && context.mounted) _snack(context, 'workout.session.save_error');
  }

  Future<void> _addExercise(BuildContext context, WidgetRef ref) async {
    final exercise = await context.push<Exercise>('/session/$sessionId/exercises');
    if (exercise == null || !context.mounted) return;
    final ok = await _notifier(ref).addExercise(exercise);
    if (!ok && context.mounted) _snack(context, 'workout.session.save_error');
  }

  Future<void> _removeExercise(BuildContext context, WidgetRef ref, int exercisePosition) async {
    final ok = await _notifier(ref).removeExercise(exercisePosition);
    if (!ok && context.mounted) _snack(context, 'workout.session.save_error');
  }

  Future<bool> _confirm(
    BuildContext context, {
    required Key dialogKey,
    required Key confirmKey,
    required String title,
    required String body,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        key: dialogKey,
        title: Text(title.tr()),
        content: Text(body.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text('workout.cancel'.tr()),
          ),
          TextButton(
            key: confirmKey,
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text('workout.session.cancel_confirm'.tr()),
          ),
        ],
      ),
    );
    return confirmed == true;
  }

  Future<void> _cancelSession(BuildContext context, WidgetRef ref) async {
    try {
      await _notifier(ref).cancel();
      if (context.mounted) context.go('/home');
    } catch (e, st) {
      debugPrint('SessionScreen.cancel failed: $e\n$st');
      if (context.mounted) _snack(context, 'workout.action_error');
    }
  }

  Future<void> _askCancel(BuildContext context, WidgetRef ref) async {
    final confirmed = await _confirm(
      context,
      dialogKey: const Key('session_cancel_dialog'),
      confirmKey: const Key('session_cancel_confirm'),
      title: 'workout.session.cancel_confirm_title',
      body: 'workout.session.cancel_confirm_body',
    );
    if (confirmed && context.mounted) await _cancelSession(context, ref);
  }

  Future<void> _finish(BuildContext context, WidgetRef ref, WorkoutSession session) async {
    if (completedSetCount(session) > 0) {
      context.push('/session/$sessionId/summary');
      return;
    }
    final cancel = await _confirm(
      context,
      dialogKey: const Key('session_no_sets_dialog'),
      confirmKey: const Key('session_no_sets_cancel'),
      title: 'workout.session.no_sets_title',
      body: 'workout.session.no_sets_body',
    );
    if (cancel && context.mounted) await _cancelSession(context, ref);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionAsync = ref.watch(sessionNotifierProvider(sessionId));
    final now = ref.watch(clockProvider).value ?? ref.watch(nowProvider)();
    final loaded = sessionAsync.value;

    return Scaffold(
      key: const Key('session_screen'),
      appBar: AppBar(
        title: Text(loaded?.workoutName ?? ''),
        actions: [
          if (loaded != null) ...[
            Center(
              child: Text(
                formatDuration(sessionDuration(loaded, now)),
                key: const Key('session_elapsed'),
              ),
            ),
            TextButton(
              key: const Key('session_finish_button'),
              onPressed: () => _finish(context, ref, loaded),
              child: Text('workout.session.finish'.tr()),
            ),
            PopupMenuButton<String>(
              key: const Key('session_menu'),
              onSelected: (_) => _askCancel(context, ref),
              itemBuilder: (_) => [
                PopupMenuItem(
                  key: const Key('session_cancel_item'),
                  value: 'cancel',
                  child: Text('workout.session.cancel'.tr()),
                ),
              ],
            ),
          ],
        ],
      ),
      bottomNavigationBar: const RestTimerBar(),
      body: sessionAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('workout.session.load_error'.tr()),
              TextButton(
                onPressed: () => ref.invalidate(sessionNotifierProvider(sessionId)),
                child: Text('workout.retry'.tr()),
              ),
            ],
          ),
        ),
        data: (session) => ListView(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 96),
          children: [
            for (final sets in session.exerciseGroups) _exerciseCard(context, ref, sets),
            TextButton.icon(
              key: const Key('session_add_exercise'),
              onPressed: () => _addExercise(context, ref),
              icon: const Icon(Icons.add),
              label: Text('workout.session.add_exercise'.tr()),
            ),
          ],
        ),
      ),
    );
  }

  Widget _exerciseCard(BuildContext context, WidgetRef ref, List<SessionSet> sets) {
    final position = sets.first.exercisePosition;
    return Card(
      key: Key('session_exercise_$position'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListTile(
            title: Text(sets.first.exerciseName, style: Theme.of(context).textTheme.titleMedium),
            trailing: PopupMenuButton<String>(
              key: Key('session_exercise_menu_$position'),
              onSelected: (_) => _removeExercise(context, ref, position),
              itemBuilder: (_) => [
                PopupMenuItem(
                  key: Key('session_remove_exercise_$position'),
                  value: 'remove',
                  child: Text('workout.session.remove_exercise'.tr()),
                ),
              ],
            ),
          ),
          for (final (index, set) in sets.indexed)
            SetRow(
              key: ValueKey(set.id),
              set: set,
              number: index + 1,
              onWeightChanged: (kg) => _notifier(ref).setWeight(set.id!, kg),
              onRepsChanged: (reps) => _notifier(ref).setReps(set.id!, reps),
              onToggle: () => set.isCompleted ? _uncomplete(context, ref, set) : _complete(context, ref, set),
            ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 7: Rotaları ekle**

`lib/core/router.dart` → import'lara ekle:

```dart
import '../features/workout/presentation/session_screen.dart';
```

`routes:` listesinde `/onboarding` rotasından sonra, `StatefulShellRoute.indexedStack(`'ten önce ekle:

```dart
      // Antrenman: alt menü dışında tam ekran.
      GoRoute(
        path: '/session/:id',
        builder: (context, state) => SessionScreen(sessionId: state.pathParameters['id']!),
        routes: [
          GoRoute(path: 'exercises', builder: (context, state) => const ExercisePickerScreen()),
        ],
      ),
```

- [ ] **Step 8: Testlerin geçtiğini doğrula**

Run: `flutter test test/features/workout/presentation/session_screen_test.dart`
Expected: PASS.

Run: `flutter analyze lib test`
Expected: `No issues found!`

- [ ] **Step 9: Commit**

```bash
git add lib/features/workout/presentation/session_screen.dart lib/features/workout/presentation/widgets/set_row.dart lib/features/workout/presentation/widgets/rest_timer_bar.dart lib/core/router.dart assets/translations test/features/workout/presentation/session_screen_test.dart
git commit -m "feat(workout): add workout session screen with set logging and rest timer"
```

---

## Task 9: Bitiş özeti ekranı

**Files:**
- Create: `lib/features/workout/presentation/session_summary_screen.dart`
- Modify: `lib/core/router.dart`
- Test: `test/features/workout/presentation/session_summary_screen_test.dart`

**Interfaces:**
- Consumes: `sessionNotifierProvider` (`finish`) (Task 7); `nowProvider` (Task 5); `oneRepMaxesProvider`, `exercisesProvider` (F3); `oneRepMaxSuggestions`, `OneRepMaxSuggestion` (Task 3); `completedSetCount`, `totalVolumeKg`, `sessionDuration`, `formatDuration`, `trimNumber` (Task 2).
- Produces: `class SessionSummaryScreen extends ConsumerStatefulWidget { const SessionSummaryScreen({super.key, required String sessionId}); }` — rota `/session/:id/summary`; key'ler `session_summary_screen`, `summary_duration`, `summary_sets`, `summary_volume`, `summary_1rm_<exerciseId>`, `summary_save_button`.

- [ ] **Step 1: Başarısız testleri yaz**

`test/features/workout/presentation/session_summary_screen_test.dart`:

```dart
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spor_takip/features/onboarding/application/auth_providers.dart';
import 'package:spor_takip/features/workout/application/session_providers.dart';
import 'package:spor_takip/features/workout/application/workout_providers.dart';
import 'package:spor_takip/features/workout/domain/exercise.dart';
import 'package:spor_takip/features/workout/domain/workout_session.dart';
import 'package:spor_takip/features/workout/presentation/session_summary_screen.dart';

import '../fakes.dart';

const _squat = Exercise(id: 'Barbell_Squat', name: 'Barbell Squat');
final _now = DateTime(2026, 9, 26, 10, 45);

final _session = WorkoutSession(
  id: 'sess',
  programId: 'bbb',
  programName: '5/3/1 BBB',
  workoutName: 'Hafta 1 · Squat',
  workoutPosition: 0,
  startedAt: DateTime(2026, 9, 26, 10),
  sets: [
    SessionSet(
      id: 'amrap',
      exercisePosition: 0,
      setIndex: 0,
      exerciseId: 'Barbell_Squat',
      exerciseName: 'Barbell Squat',
      targetRepsMin: 5,
      targetRepsMax: 5,
      isAmrap: true,
      percent1rm: 85,
      weightKg: 85,
      reps: 8,
      completedAt: DateTime(2026, 9, 26, 10, 20),
    ),
    SessionSet(
      id: 'bench',
      exercisePosition: 1,
      setIndex: 0,
      exerciseId: 'Bench',
      exerciseName: 'Bench Press',
      targetRepsMin: 5,
      targetRepsMax: 5,
      weightKg: 40,
      reps: 5,
      completedAt: DateTime(2026, 9, 26, 10, 30),
    ),
  ],
);

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  late FakeSessionRepository repo;

  setUp(() => repo = FakeSessionRepository(sessions: [_session]));

  Widget wrap() {
    final router = GoRouter(initialLocation: '/session/sess/summary', routes: [
      GoRoute(path: '/home', builder: (context, state) => const Text('HOME')),
      GoRoute(
        path: '/session/:id',
        builder: (context, state) => const Text('SESSION'),
        routes: [
          GoRoute(
            path: 'summary',
            builder: (context, state) => SessionSummaryScreen(sessionId: state.pathParameters['id']!),
          ),
        ],
      ),
    ]);
    return EasyLocalization(
      supportedLocales: const [Locale('tr'), Locale('en')],
      path: 'assets/translations',
      fallbackLocale: const Locale('tr'),
      child: ProviderScope(
        overrides: [
          isLoggedInProvider.overrideWithValue(true),
          sessionRepositoryProvider.overrideWithValue(repo),
          exerciseRepositoryProvider.overrideWithValue(FakeExerciseRepository([_squat])),
          oneRepMaxRepositoryProvider.overrideWithValue(FakeOneRepMaxRepository()..values['Barbell_Squat'] = 100),
          nowProvider.overrideWithValue(() => _now),
          clockProvider.overrideWith((ref) => Stream.value(_now)),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
  }

  testWidgets('shows stats and saves the 1RM suggestion by default', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('session_summary_screen')), findsOneWidget);
    expect(find.text('45:00'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('880 kg'), findsOneWidget);
    expect(find.text('100 → 105 kg'), findsOneWidget);

    await tester.tap(find.byKey(const Key('summary_save_button')));
    await tester.pumpAndSettle();

    expect(repo.finished.single.oneRepMaxes, {'Barbell_Squat': 105.0});
    expect(find.text('HOME'), findsOneWidget);
  });

  testWidgets('an unticked suggestion is not saved', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('summary_1rm_Barbell_Squat')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('summary_save_button')));
    await tester.pumpAndSettle();

    expect(repo.finished.single.oneRepMaxes, isEmpty);
  });

  testWidgets('a failed finish keeps the summary open', (tester) async {
    repo.finishError = Exception('offline');
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('summary_save_button')));
    await tester.pumpAndSettle();

    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.byKey(const Key('session_summary_screen')), findsOneWidget);
  });
}
```

- [ ] **Step 2: Testlerin başarısız olduğunu doğrula**

Run: `flutter test test/features/workout/presentation/session_summary_screen_test.dart`
Expected: FAIL — `session_summary_screen.dart` yok.

- [ ] **Step 3: Özet ekranını yaz**

`lib/features/workout/presentation/session_summary_screen.dart`:

```dart
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../application/session_notifier.dart';
import '../application/session_providers.dart';
import '../application/workout_providers.dart';
import '../domain/block_format.dart';
import '../domain/exercise.dart';
import '../domain/progression.dart';
import '../domain/session_stats.dart';

/// Bitir → süre, set, hacim ve onaylanacak 1RM önerileri → Kaydet.
class SessionSummaryScreen extends ConsumerStatefulWidget {
  const SessionSummaryScreen({super.key, required this.sessionId});

  final String sessionId;

  @override
  ConsumerState<SessionSummaryScreen> createState() => _SessionSummaryScreenState();
}

class _SessionSummaryScreenState extends ConsumerState<SessionSummaryScreen> {
  final Set<String> _rejected = {};
  bool _saving = false;

  Future<void> _save(List<OneRepMaxSuggestion> suggestions) async {
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(sessionNotifierProvider(widget.sessionId).notifier).finish({
        for (final s in suggestions)
          if (!_rejected.contains(s.exerciseId)) s.exerciseId: s.suggestedKg,
      });
      if (mounted) context.go('/home');
    } catch (e, st) {
      debugPrint('SessionSummaryScreen.save failed: $e\n$st');
      messenger.showSnackBar(SnackBar(content: Text('workout.session.save_error'.tr())));
      if (mounted) setState(() => _saving = false);
    }
  }

  void _toggle(String exerciseId, bool? checked) {
    setState(() {
      if (checked == true) {
        _rejected.remove(exerciseId);
      } else {
        _rejected.add(exerciseId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionNotifierProvider(widget.sessionId)).value;
    final oneRepMaxes = ref.watch(oneRepMaxesProvider).value ?? const <String, double>{};
    final exercises = ref.watch(exercisesProvider).value ?? const <Exercise>[];
    if (session == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final names = {
      for (final e in exercises) e.id: e.name,
      for (final s in session.sets) s.exerciseId: s.exerciseName,
    };
    final suggestions = oneRepMaxSuggestions(sets: session.sets, oneRepMaxes: oneRepMaxes);
    final now = ref.watch(nowProvider)();
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      key: const Key('session_summary_screen'),
      appBar: AppBar(title: Text('workout.session.summary_title'.tr())),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(session.workoutName, style: textTheme.titleLarge),
          ListTile(
            key: const Key('summary_duration'),
            title: Text('workout.session.summary_duration'.tr()),
            trailing: Text(formatDuration(sessionDuration(session, now))),
          ),
          ListTile(
            key: const Key('summary_sets'),
            title: Text('workout.session.summary_sets'.tr()),
            trailing: Text('${completedSetCount(session)}'),
          ),
          ListTile(
            key: const Key('summary_volume'),
            title: Text('workout.session.summary_volume'.tr()),
            trailing: Text('${trimNumber(totalVolumeKg(session))} kg'),
          ),
          if (suggestions.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('workout.session.summary_one_rep_max'.tr(), style: textTheme.titleMedium),
            for (final s in suggestions)
              CheckboxListTile(
                key: Key('summary_1rm_${s.exerciseId}'),
                value: !_rejected.contains(s.exerciseId),
                onChanged: (checked) => _toggle(s.exerciseId, checked),
                title: Text(names[s.exerciseId] ?? s.exerciseId),
                subtitle: Text('${trimNumber(s.currentKg)} → ${trimNumber(s.suggestedKg)} kg'),
              ),
          ],
          const SizedBox(height: 24),
          FilledButton(
            key: const Key('summary_save_button'),
            onPressed: _saving ? null : () => _save(suggestions),
            child: Text('workout.session.save'.tr()),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Rotayı ekle**

`lib/core/router.dart` → import:

```dart
import '../features/workout/presentation/session_summary_screen.dart';
```

`/session/:id` rotasının `routes:` listesine (`exercises`'tan sonra) ekle:

```dart
          GoRoute(
            path: 'summary',
            builder: (context, state) => SessionSummaryScreen(sessionId: state.pathParameters['id']!),
          ),
```

- [ ] **Step 5: Testlerin geçtiğini doğrula**

Run: `flutter test test/features/workout/presentation/session_summary_screen_test.dart`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/features/workout/presentation/session_summary_screen.dart lib/core/router.dart test/features/workout/presentation/session_summary_screen_test.dart
git commit -m "feat(workout): add workout summary with 1RM suggestions"
```

---

## Task 10: Geçmiş listesi ve detayı

**Files:**
- Create: `lib/features/workout/presentation/history_screen.dart`, `lib/features/workout/presentation/history_detail_screen.dart`
- Modify: `lib/features/workout/presentation/programs_screen.dart`, `lib/core/router.dart`, `assets/translations/tr.json`, `assets/translations/en.json`
- Test: `test/features/workout/presentation/history_screen_test.dart`, `test/features/workout/presentation/programs_screen_test.dart` (eklenir)

**Interfaces:**
- Consumes: `sessionHistoryProvider`, `sessionDetailProvider`, `sessionRepositoryProvider` (Task 5); `sessionDuration`, `formatDuration`, `totalVolumeKg`, `trimNumber` (Task 2).
- Produces: `class HistoryScreen extends ConsumerWidget` (`/workout/history`), `class HistoryDetailScreen extends ConsumerWidget { const HistoryDetailScreen({super.key, required String sessionId}); }` (`/workout/history/:id`), `String historySubtitle(WorkoutSession session)`; key'ler `history_screen`, `history_empty`, `history_<sessionId>`, `history_detail_screen`, `history_set_<setId>`, `history_delete_button`, `history_delete_confirm`, `programs_history_button`.

- [ ] **Step 1: Çevirileri ekle**

`tr.json` → `workout` nesnesinde `"session": { ... }` bloğunun kapanış `}`'inden sonra virgül koy ve ekle:

```json
    "history": {
      "title": "Geçmiş",
      "empty": "Henüz tamamlanmış antrenman yok",
      "load_error": "Geçmiş yüklenemedi",
      "not_done": "yapılmadı",
      "delete_title": "Antrenman kaydı silinsin mi?"
    }
```

`en.json` → aynı yere:

```json
    "history": {
      "title": "History",
      "empty": "No completed workouts yet",
      "load_error": "Could not load history",
      "not_done": "not done",
      "delete_title": "Delete this workout log?"
    }
```

Doğrula: `python -c "import json;[json.load(open(f'assets/translations/{x}.json',encoding='utf-8')) for x in ('tr','en')];print('ok')"` → `ok`.

- [ ] **Step 2: Başarısız testleri yaz**

`test/features/workout/presentation/history_screen_test.dart`:

```dart
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spor_takip/features/onboarding/application/auth_providers.dart';
import 'package:spor_takip/features/workout/application/session_providers.dart';
import 'package:spor_takip/features/workout/domain/workout_session.dart';
import 'package:spor_takip/features/workout/presentation/history_detail_screen.dart';
import 'package:spor_takip/features/workout/presentation/history_screen.dart';

import '../fakes.dart';

SessionSet _set(String id, {int idx = 0, bool done = true}) => SessionSet(
      id: id,
      exercisePosition: 0,
      setIndex: idx,
      exerciseId: 'Barbell_Squat',
      exerciseName: 'Barbell Squat',
      targetRepsMin: 5,
      targetRepsMax: 5,
      weightKg: done ? 60 : null,
      reps: done ? 5 : null,
      completedAt: done ? DateTime(2026, 9, 20, 10, 10) : null,
    );

final _finished = WorkoutSession(
  id: 'h1',
  programName: 'StrongLifts 5x5',
  workoutName: 'Antrenman A',
  workoutPosition: 0,
  startedAt: DateTime(2026, 9, 20, 10),
  finishedAt: DateTime(2026, 9, 20, 10, 50),
  sets: [_set('x1'), _set('x2', idx: 1, done: false)],
);

final _inProgress = WorkoutSession(
  id: 'cur',
  programName: 'StrongLifts 5x5',
  workoutName: 'Antrenman B',
  workoutPosition: 1,
  startedAt: DateTime(2026, 9, 26, 10),
);

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  Widget wrap(FakeSessionRepository repo) {
    final router = GoRouter(initialLocation: '/workout/history', routes: [
      GoRoute(
        path: '/workout/history',
        builder: (context, state) => const HistoryScreen(),
        routes: [
          GoRoute(
            path: ':id',
            builder: (context, state) => HistoryDetailScreen(sessionId: state.pathParameters['id']!),
          ),
        ],
      ),
    ]);
    return EasyLocalization(
      supportedLocales: const [Locale('tr'), Locale('en')],
      path: 'assets/translations',
      fallbackLocale: const Locale('tr'),
      child: ProviderScope(
        overrides: [
          isLoggedInProvider.overrideWithValue(true),
          sessionRepositoryProvider.overrideWithValue(repo),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
  }

  testWidgets('lists only finished sessions', (tester) async {
    await tester.pumpWidget(wrap(FakeSessionRepository(sessions: [_finished, _inProgress])));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('history_h1')), findsOneWidget);
    expect(find.byKey(const Key('history_cur')), findsNothing);
    expect(find.textContaining('300 kg'), findsOneWidget);
  });

  testWidgets('empty history', (tester) async {
    await tester.pumpWidget(wrap(FakeSessionRepository()));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('history_empty')), findsOneWidget);
  });

  testWidgets('detail shows sets and deleting returns to an empty list', (tester) async {
    final repo = FakeSessionRepository(sessions: [_finished]);
    await tester.pumpWidget(wrap(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('history_h1')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('history_detail_screen')), findsOneWidget);
    expect(find.text('Barbell Squat'), findsOneWidget);
    expect(find.text('60 kg × 5'), findsOneWidget);
    expect(find.byKey(const Key('history_set_x2')), findsOneWidget);

    await tester.tap(find.byKey(const Key('history_delete_button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('history_delete_confirm')));
    await tester.pumpAndSettle();

    expect(repo.sessions, isEmpty);
    expect(find.byKey(const Key('history_empty')), findsOneWidget);
  });
}
```

`test/features/workout/presentation/programs_screen_test.dart` → `wrap` içindeki `GoRouter(routes: [...])` listesine ekle:

```dart
      GoRoute(path: '/workout/history', builder: (context, state) => const Text('HISTORY')),
```

ve `main`'in sonuna test ekle:

```dart
  testWidgets('history button opens the workout history', (tester) async {
    await tester.pumpWidget(wrap(programs: [_stronglifts]));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('programs_history_button')));
    await tester.pumpAndSettle();

    expect(find.text('HISTORY'), findsOneWidget);
  });
```

- [ ] **Step 3: Testlerin başarısız olduğunu doğrula**

Run: `flutter test test/features/workout/presentation/history_screen_test.dart test/features/workout/presentation/programs_screen_test.dart`
Expected: FAIL — geçmiş ekranları yok, `programs_history_button` yok.

- [ ] **Step 4: Geçmiş ekranlarını yaz**

`lib/features/workout/presentation/history_screen.dart`:

```dart
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../application/session_providers.dart';
import '../domain/block_format.dart';
import '../domain/session_stats.dart';
import '../domain/workout_session.dart';

/// "26.9.2026 · StrongLifts 5x5 · 50:00 · 1500 kg"
String historySubtitle(WorkoutSession session) {
  final d = session.startedAt.toLocal();
  final duration = formatDuration(sessionDuration(session, DateTime.now()));
  return '${d.day}.${d.month}.${d.year} · ${session.programName} · $duration · '
      '${trimNumber(totalVolumeKg(session))} kg';
}

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(sessionHistoryProvider);
    return Scaffold(
      key: const Key('history_screen'),
      appBar: AppBar(title: Text('workout.history.title'.tr())),
      body: historyAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('workout.history.load_error'.tr()),
              TextButton(
                onPressed: () => ref.invalidate(sessionHistoryProvider),
                child: Text('workout.retry'.tr()),
              ),
            ],
          ),
        ),
        data: (sessions) {
          if (sessions.isEmpty) {
            return Center(child: Text('workout.history.empty'.tr(), key: const Key('history_empty')));
          }
          return ListView(
            children: [
              for (final session in sessions)
                ListTile(
                  key: Key('history_${session.id}'),
                  title: Text(session.workoutName),
                  subtitle: Text(historySubtitle(session)),
                  onTap: () => context.push('/workout/history/${session.id}'),
                ),
            ],
          );
        },
      ),
    );
  }
}
```

`lib/features/workout/presentation/history_detail_screen.dart`:

```dart
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../application/session_providers.dart';
import '../domain/block_format.dart';
import '../domain/workout_session.dart';
import 'history_screen.dart';

String _doneLabel(SessionSet set) =>
    set.weightKg == null ? '× ${set.reps}' : '${trimNumber(set.weightKg!)} kg × ${set.reps}';

class HistoryDetailScreen extends ConsumerWidget {
  const HistoryDetailScreen({super.key, required this.sessionId});

  final String sessionId;

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('workout.history.delete_title'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text('workout.cancel'.tr()),
          ),
          TextButton(
            key: const Key('history_delete_confirm'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text('workout.delete'.tr()),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(sessionRepositoryProvider).deleteSession(sessionId);
      ref.invalidate(sessionHistoryProvider);
      if (context.mounted) context.pop();
    } catch (e, st) {
      debugPrint('HistoryDetailScreen.delete failed: $e\n$st');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('workout.action_error'.tr())));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionAsync = ref.watch(sessionDetailProvider(sessionId));
    return Scaffold(
      key: const Key('history_detail_screen'),
      appBar: AppBar(
        title: Text(sessionAsync.value?.workoutName ?? ''),
        actions: [
          IconButton(
            key: const Key('history_delete_button'),
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _delete(context, ref),
          ),
        ],
      ),
      body: sessionAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(child: Text('workout.history.load_error'.tr())),
        data: (session) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(historySubtitle(session)),
            const SizedBox(height: 8),
            for (final sets in session.exerciseGroups)
              Card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ListTile(title: Text(sets.first.exerciseName)),
                    for (final (index, set) in sets.indexed)
                      ListTile(
                        key: Key('history_set_${set.id}'),
                        dense: true,
                        enabled: set.isCompleted,
                        leading: Text('${index + 1}'),
                        title: Text(set.isCompleted ? _doneLabel(set) : 'workout.history.not_done'.tr()),
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
```

- [ ] **Step 5: Programlar ekranına geçmiş ikonu ekle**

`lib/features/workout/presentation/programs_screen.dart` → `appBar: AppBar(title: Text('workout.programs_title'.tr())),` satırını şununla değiştir:

```dart
      appBar: AppBar(
        title: Text('workout.programs_title'.tr()),
        actions: [
          IconButton(
            key: const Key('programs_history_button'),
            icon: const Icon(Icons.history),
            tooltip: 'workout.history.title'.tr(),
            onPressed: () => context.push('/workout/history'),
          ),
        ],
      ),
```

- [ ] **Step 6: Rotaları ekle**

`lib/core/router.dart` → import'lar:

```dart
import '../features/workout/presentation/history_detail_screen.dart';
import '../features/workout/presentation/history_screen.dart';
```

`/workout` rotasının `routes:` listesine (`exercises` rotasından sonra) ekle:

```dart
                  GoRoute(
                    path: 'history',
                    builder: (context, state) => const HistoryScreen(),
                    routes: [
                      GoRoute(
                        path: ':id',
                        builder: (context, state) =>
                            HistoryDetailScreen(sessionId: state.pathParameters['id']!),
                      ),
                    ],
                  ),
```

- [ ] **Step 7: Testlerin geçtiğini doğrula**

Run: `flutter test test/features/workout/presentation/history_screen_test.dart test/features/workout/presentation/programs_screen_test.dart`
Expected: PASS.

- [ ] **Step 8: Commit**

```bash
git add lib/features/workout/presentation/history_screen.dart lib/features/workout/presentation/history_detail_screen.dart lib/features/workout/presentation/programs_screen.dart lib/core/router.dart assets/translations test/features/workout/presentation/history_screen_test.dart test/features/workout/presentation/programs_screen_test.dart
git commit -m "feat(workout): add workout history list and detail"
```

---

## Task 11: Başlatma girişleri — ana ekran kartı ve program detayı

**Files:**
- Create: `lib/features/workout/presentation/start_workout.dart`
- Modify: `lib/features/workout/presentation/widgets/today_workout_card.dart`, `lib/features/workout/presentation/program_detail_screen.dart`, `assets/translations/tr.json`, `assets/translations/en.json`
- Test: `test/features/workout/presentation/today_workout_card_test.dart` (yeniden yazılır), `test/features/workout/presentation/program_detail_screen_test.dart` (eklenir)

**Interfaces:**
- Consumes: `sessionRepositoryProvider`, `inProgressSessionProvider` (Task 5); `startSessionServiceProvider` (Task 6); `todayWorkoutProvider`, `ScheduledWorkout(program, workoutIndex, workout)` (F3).
- Produces: `Future<void> startWorkout(BuildContext context, WidgetRef ref, Program program, int workoutIndex)` (hata fırlatır; çağıran yakalar); key'ler `today_in_progress`, `today_resume_button`, `today_start_button`, `workout_start_<index>`, `session_conflict_resume`, `session_conflict_replace`. `today_done_button` ve `workout.today_done` kaldırılır.

- [ ] **Step 1: Çevirileri güncelle**

`tr.json` → `workout` içinde:
- `"today_done": "Tamamladım",` satırını sil.
- `"exercise_in_use"` değerini `"Bu hareket bir programında veya antrenman kayıtlarında kullanılıyor."` yap.

`en.json` → `workout` içinde:
- `"today_done": "Done",` satırını sil.
- `"exercise_in_use"` değerini `"This exercise is used in one of your programs or workout logs."` yap.

Doğrula: `python -c "import json;[json.load(open(f'assets/translations/{x}.json',encoding='utf-8')) for x in ('tr','en')];print('ok')"` → `ok`.

- [ ] **Step 2: Ana ekran kartı testini yeniden yaz**

`test/features/workout/presentation/today_workout_card_test.dart` dosyasının tamamını şununla değiştir:

```dart
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spor_takip/features/onboarding/application/auth_providers.dart';
import 'package:spor_takip/features/workout/application/session_providers.dart';
import 'package:spor_takip/features/workout/application/workout_providers.dart';
import 'package:spor_takip/features/workout/data/program_repository.dart';
import 'package:spor_takip/features/workout/domain/program.dart';
import 'package:spor_takip/features/workout/domain/program_workout.dart';
import 'package:spor_takip/features/workout/domain/schedule_mode.dart';
import 'package:spor_takip/features/workout/domain/today_workout.dart';
import 'package:spor_takip/features/workout/domain/workout_session.dart';
import 'package:spor_takip/features/workout/presentation/widgets/today_workout_card.dart';

import '../fakes.dart';

const _rotation = Program(
  id: 'rot',
  userId: 'user-1',
  name: 'Rotasyon',
  scheduleMode: ScheduleMode.rotation,
  workouts: [
    ProgramWorkout(name: 'Antrenman A', exercises: []),
    ProgramWorkout(name: 'Antrenman B', exercises: []),
  ],
);

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  late FakeSessionRepository sessionRepo;

  setUp(() => sessionRepo = FakeSessionRepository());

  Widget wrap(List overrides) {
    final router = GoRouter(routes: [
      GoRoute(path: '/', builder: (context, state) => const Scaffold(body: TodayWorkoutCard())),
      GoRoute(path: '/workout', builder: (context, state) => const Text('PROGRAMS')),
      GoRoute(
        path: '/workout/program/:id',
        builder: (context, state) => Text('DETAIL_${state.pathParameters['id']}'),
      ),
      GoRoute(
        path: '/session/:id',
        builder: (context, state) => Text('SESSION_${state.pathParameters['id']}'),
      ),
    ]);
    return EasyLocalization(
      supportedLocales: const [Locale('tr'), Locale('en')],
      path: 'assets/translations',
      fallbackLocale: const Locale('tr'),
      child: ProviderScope(
        overrides: [
          isLoggedInProvider.overrideWithValue(true),
          sessionRepositoryProvider.overrideWithValue(sessionRepo),
          exerciseRepositoryProvider.overrideWithValue(FakeExerciseRepository()),
          oneRepMaxRepositoryProvider.overrideWithValue(FakeOneRepMaxRepository()),
          ...overrides.cast(),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
  }

  testWidgets('without an active program it links to the programs tab', (tester) async {
    await tester.pumpWidget(wrap([todayWorkoutProvider.overrideWith((ref) async => const NoActiveProgram())]));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('today_no_program')), findsOneWidget);
    await tester.tap(find.byKey(const Key('today_choose_program')));
    await tester.pumpAndSettle();
    expect(find.text('PROGRAMS'), findsOneWidget);
  });

  testWidgets('rest day', (tester) async {
    await tester.pumpWidget(wrap([
      todayWorkoutProvider.overrideWith((ref) async => const RestDay(_rotation)),
    ]));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('today_rest_day')), findsOneWidget);
  });

  testWidgets('scheduled workout: Start opens a new session, tap opens detail', (tester) async {
    final repo = FakeProgramRepository(
      programs: [_rotation],
      active: const ActiveProgramState(programId: 'rot', nextRotationPosition: 1),
    );
    await tester.pumpWidget(wrap([programRepositoryProvider.overrideWithValue(repo)]));
    await tester.pumpAndSettle();

    expect(find.text('Antrenman B'), findsOneWidget);
    expect(find.byKey(const Key('today_done_button')), findsNothing);

    await tester.tap(find.byKey(const Key('today_start_button')));
    await tester.pumpAndSettle();

    expect(find.text('SESSION_session-0'), findsOneWidget);
    final session = sessionRepo.sessions['session-0']!;
    expect(session.workoutName, 'Antrenman B');
    expect(session.workoutPosition, 1);
  });

  testWidgets('scheduled workout tile opens the program detail', (tester) async {
    final repo = FakeProgramRepository(programs: [_rotation], active: const ActiveProgramState(programId: 'rot'));
    await tester.pumpWidget(wrap([programRepositoryProvider.overrideWithValue(repo)]));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('today_scheduled')));
    await tester.pumpAndSettle();
    expect(find.text('DETAIL_rot'), findsOneWidget);
  });

  testWidgets('an in-progress session shows Resume', (tester) async {
    sessionRepo.sessions['cur'] = WorkoutSession(
      id: 'cur',
      programId: 'rot',
      programName: 'Rotasyon',
      workoutName: 'Antrenman A',
      workoutPosition: 0,
      startedAt: DateTime.now(),
    );
    await tester.pumpWidget(wrap([todayWorkoutProvider.overrideWith((ref) async => const NoActiveProgram())]));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('today_in_progress')), findsOneWidget);
    expect(find.text('Antrenman A'), findsOneWidget);

    await tester.tap(find.byKey(const Key('today_resume_button')));
    await tester.pumpAndSettle();
    expect(find.text('SESSION_cur'), findsOneWidget);
  });
}
```

- [ ] **Step 3: Program detay testlerini ekle**

`test/features/workout/presentation/program_detail_screen_test.dart`:

Import'lara ekle:

```dart
import 'package:spor_takip/features/workout/application/session_providers.dart';
import 'package:spor_takip/features/workout/domain/workout_session.dart';
```

`late FakeOneRepMaxRepository oneRepMaxRepo;` satırından sonra ekle:

```dart
  late FakeSessionRepository sessionRepo;
```

`wrap` içindeki `GoRouter(initialLocation: '/workout', routes: [` listesine, `/workout` rotasından **sonra** (aynı seviyede) ekle:

```dart
      GoRoute(
        path: '/session/:id',
        builder: (context, state) => Text('SESSION_${state.pathParameters['id']}'),
      ),
```

`ProviderScope(overrides: [...])` listesine ekle:

```dart
          sessionRepositoryProvider.overrideWithValue(sessionRepo),
          exerciseRepositoryProvider.overrideWithValue(FakeExerciseRepository()),
```

`setUp` içine ekle:

```dart
    sessionRepo = FakeSessionRepository();
```

`main`'in sonuna testleri ekle:

```dart
  testWidgets('start opens a new session for that workout', (tester) async {
    await open(tester, 'mine');

    await tester.tap(find.byKey(const Key('workout_start_0')));
    await tester.pumpAndSettle();

    expect(find.text('SESSION_session-0'), findsOneWidget);
    expect(sessionRepo.sessions['session-0']!.workoutName, 'Bacak');
    expect(sessionRepo.sessions['session-0']!.sets.length, 1);
  });

  WorkoutSession inProgress() => WorkoutSession(
        id: 'cur',
        programName: 'Başka',
        workoutName: 'Eski antrenman',
        workoutPosition: 0,
        startedAt: DateTime(2026, 9, 26, 9),
      );

  testWidgets('with a session in progress, Resume opens it', (tester) async {
    sessionRepo.sessions['cur'] = inProgress();
    await open(tester, 'mine');

    await tester.tap(find.byKey(const Key('workout_start_0')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('session_conflict_resume')));
    await tester.pumpAndSettle();

    expect(find.text('SESSION_cur'), findsOneWidget);
    expect(sessionRepo.sessions.length, 1);
  });

  testWidgets('with a session in progress, Replace cancels it and starts a new one', (tester) async {
    sessionRepo.sessions['cur'] = inProgress();
    await open(tester, 'mine');

    await tester.tap(find.byKey(const Key('workout_start_0')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('session_conflict_replace')));
    await tester.pumpAndSettle();

    expect(sessionRepo.sessions.containsKey('cur'), isFalse);
    expect(find.text('SESSION_session-0'), findsOneWidget);
  });
```

- [ ] **Step 4: Testlerin başarısız olduğunu doğrula**

Run: `flutter test test/features/workout/presentation/today_workout_card_test.dart test/features/workout/presentation/program_detail_screen_test.dart`
Expected: FAIL — `today_start_button`, `today_in_progress`, `workout_start_0` bulunamıyor.

- [ ] **Step 5: Başlatma yardımcısını yaz**

`lib/features/workout/presentation/start_workout.dart`:

```dart
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../application/session_providers.dart';
import '../application/start_session_service.dart';
import '../domain/program.dart';

enum _Conflict { resume, replace }

/// Antrenmanı başlatıp oturum ekranını açar. Devam eden oturum varsa önce
/// "Devam et / İptal et, yenisini başlat / Vazgeç" sorulur. Hata fırlatır;
/// çağıran yakalayıp kullanıcıya gösterir.
Future<void> startWorkout(BuildContext context, WidgetRef ref, Program program, int workoutIndex) async {
  final existing = await ref.read(sessionRepositoryProvider).fetchInProgressSession();
  if (!context.mounted) return;
  if (existing != null) {
    final choice = await showDialog<_Conflict>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('workout.session.conflict_title'.tr()),
        content: Text(existing.workoutName),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text('workout.cancel'.tr()),
          ),
          TextButton(
            key: const Key('session_conflict_replace'),
            onPressed: () => Navigator.of(dialogContext).pop(_Conflict.replace),
            child: Text('workout.session.conflict_replace'.tr()),
          ),
          FilledButton(
            key: const Key('session_conflict_resume'),
            onPressed: () => Navigator.of(dialogContext).pop(_Conflict.resume),
            child: Text('workout.session.resume'.tr()),
          ),
        ],
      ),
    );
    if (choice == null || !context.mounted) return;
    if (choice == _Conflict.resume) {
      context.push('/session/${existing.id}');
      return;
    }
    await ref.read(sessionRepositoryProvider).deleteSession(existing.id);
  }
  final id = await ref.read(startSessionServiceProvider).start(program, workoutIndex);
  if (context.mounted) context.push('/session/$id');
}
```

- [ ] **Step 6: Ana ekran kartını yeniden yaz**

`lib/features/workout/presentation/widgets/today_workout_card.dart` dosyasının tamamını şununla değiştir:

```dart
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../application/session_providers.dart';
import '../../application/workout_providers.dart';
import '../../domain/program.dart';
import '../../domain/schedule_mode.dart';
import '../../domain/today_workout.dart';
import '../../domain/workout_session.dart';
import '../start_workout.dart';

class TodayWorkoutCard extends ConsumerWidget {
  const TodayWorkoutCard({super.key});

  Future<void> _start(BuildContext context, WidgetRef ref, Program program, int workoutIndex) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await startWorkout(context, ref, program, workoutIndex);
    } catch (e, st) {
      debugPrint('TodayWorkoutCard start failed: $e\n$st');
      messenger.showSnackBar(SnackBar(content: Text('workout.action_error'.tr())));
    }
  }

  /// Bugün başladıysa "10:05", değilse "24.9. 10:05".
  static String _startedLabel(DateTime startedAt, DateTime now) {
    final local = startedAt.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    final time = '${two(local.hour)}:${two(local.minute)}';
    final sameDay = local.year == now.year && local.month == now.month && local.day == now.day;
    return sameDay ? time : '${local.day}.${local.month}. $time';
  }

  Widget _inProgress(BuildContext context, WorkoutSession session) {
    return ListTile(
      key: const Key('today_in_progress'),
      leading: const Icon(Icons.play_circle_outline),
      title: Text(session.workoutName),
      subtitle: Text('workout.session.started_at'.tr(
        namedArgs: {'time': _startedLabel(session.startedAt, DateTime.now())},
      )),
      trailing: FilledButton(
        key: const Key('today_resume_button'),
        onPressed: () => context.push('/session/${session.id}'),
        child: Text('workout.session.resume'.tr()),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inProgress = ref.watch(inProgressSessionProvider).value;
    final todayAsync = ref.watch(todayWorkoutProvider);
    return Card(
      key: const Key('today_workout_card'),
      child: inProgress != null
          ? _inProgress(context, inProgress)
          : todayAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (error, stackTrace) => ListTile(title: Text('workout.today_load_error'.tr())),
              data: (today) => switch (today) {
                NoActiveProgram() => ListTile(
                    key: const Key('today_no_program'),
                    leading: const Icon(Icons.fitness_center_outlined),
                    title: Text('workout.today_no_program'.tr()),
                    trailing: TextButton(
                      key: const Key('today_choose_program'),
                      onPressed: () => context.go('/workout'),
                      child: Text('workout.today_choose'.tr()),
                    ),
                  ),
                EmptyProgram(:final program) => ListTile(
                    key: const Key('today_empty_program'),
                    title: Text(program.name),
                    subtitle: Text('workout.no_workouts'.tr()),
                  ),
                RestDay(:final program) => ListTile(
                    key: const Key('today_rest_day'),
                    leading: const Icon(Icons.self_improvement),
                    title: Text('workout.today_rest_day'.tr()),
                    subtitle: Text(program.name),
                  ),
                ScheduledWorkout(:final program, :final workoutIndex, :final workout) => ListTile(
                    key: const Key('today_scheduled'),
                    leading: const Icon(Icons.fitness_center),
                    title: Text(workout.name),
                    subtitle: Text(
                      '${program.scheduleMode == ScheduleMode.weekdays ? 'workout.today_label'.tr() : 'workout.next_label'.tr()}'
                      ' · ${program.name}',
                    ),
                    onTap: () => context.push('/workout/program/${program.id}'),
                    trailing: FilledButton(
                      key: const Key('today_start_button'),
                      onPressed: () => _start(context, ref, program, workoutIndex),
                      child: Text('workout.session.start'.tr()),
                    ),
                  ),
              },
            ),
    );
  }
}
```

- [ ] **Step 7: Program detayına "Başla" ekle**

`lib/features/workout/presentation/program_detail_screen.dart` → import'lara ekle:

```dart
import 'start_workout.dart';
```

Antrenman kartındaki `ListTile(`'ı (`title: Text(workout.name, ...)` olan) şununla değiştir:

```dart
                      ListTile(
                        title: Text(workout.name, style: Theme.of(context).textTheme.titleMedium),
                        subtitle: program.scheduleMode == ScheduleMode.weekdays && workout.weekday != null
                            ? Text('workout.weekday_${workout.weekday}'.tr())
                            : null,
                        trailing: workout.exercises.isEmpty
                            ? null
                            : TextButton(
                                key: Key('workout_start_$index'),
                                onPressed: () => _run(context, () => startWorkout(context, ref, program, index)),
                                child: Text('workout.session.start'.tr()),
                              ),
                      ),
```

- [ ] **Step 8: Testlerin geçtiğini doğrula**

Run: `flutter test test/features/workout/presentation/today_workout_card_test.dart test/features/workout/presentation/program_detail_screen_test.dart`
Expected: PASS.

- [ ] **Step 9: Tüm kontroller**

Run: `flutter analyze` → Expected: `No issues found!`
Run: `flutter test` (arka planda, ~10 dk) → Expected: tüm testler PASS.

- [ ] **Step 10: Commit**

```bash
git add lib/features/workout/presentation/start_workout.dart lib/features/workout/presentation/widgets/today_workout_card.dart lib/features/workout/presentation/program_detail_screen.dart assets/translations test/features/workout/presentation/today_workout_card_test.dart test/features/workout/presentation/program_detail_screen_test.dart
git commit -m "feat(workout): start workouts from the home card and program detail"
```

---

## Task 12: SQL doğrulaması, uçtan uca manuel test ve günlük

**Files:**
- Create: `supabase/migrations/checks/f4a_rls_checks.sql`
- Modify: `PLAN.md` (Değişiklik Günlüğü)

Bu görev kullanıcıyla birlikte yapılır (veritabanı şifresi yok → Dashboard SQL Editor; düşük bellekli makine → release web build'i kullanıcının terminalinden sunulur).

- [ ] **Step 1: Kontrol betiğini yaz**

`supabase/migrations/checks/f4a_rls_checks.sql`:

```sql
-- F4a RLS / fonksiyon kontrolleri. SQL Editor'da çalıştır (migration değildir).
-- Kullanıcıları kendisi seçer: A = profili olan bir kullanıcı, B = başka bir kullanıcı.
-- Sonucu bilerek bir HATA olarak basar; hata tüm değişiklikleri geri aldığı için
-- veritabanında hiçbir şey değişmez.
-- Beklenen: ikinci_oturum_engellendi=t B_gorulen_oturum=0 B_gorulen_set=0
--           B_guncellenen_set=0 B_bitirme_engellendi=t bitti=t rotasyon=1 1rm=123.4
do $$
declare
  a uuid;
  b uuid;
  s_id uuid;
  second_blocked boolean := false;
  b_sessions int;
  b_sets int;
  b_updated int;
  b_finish_blocked boolean := false;
  is_finished boolean;
  rotation int;
  orm numeric;
begin
  select p.user_id into a from public.profiles p limit 1;
  select u.id into b from auth.users u where u.id <> a limit 1;
  if a is null or b is null then
    raise exception 'Kontrol için iki kullanıcı gerekli (a=%, b=%)', a, b;
  end if;
  -- A'nın elle testten kalmış devam eden oturumu varsa (geri alınacak) kaldır
  delete from public.workout_sessions where user_id = a and finished_at is null;

  -- A: StrongLifts aktif, oturum başlatır; ikinci oturum reddedilir
  perform set_config('request.jwt.claims', json_build_object('sub', a, 'role', 'authenticated')::text, true);
  set local role authenticated;
  update public.profiles
    set active_program_id = 'f3000000-0000-4000-8000-000000000001', next_rotation_position = 0
    where user_id = a;
  s_id := public.start_session(jsonb_build_object(
    'program_id', 'f3000000-0000-4000-8000-000000000001',
    'program_name', 'StrongLifts 5x5',
    'workout_name', 'Antrenman A',
    'workout_position', 0,
    'sets', '[{"exercise_position":0,"set_index":0,"exercise_id":"Barbell_Squat","target_reps_min":5,"target_reps_max":5,"suggested_weight_kg":60}]'::jsonb));
  begin
    perform public.start_session(jsonb_build_object(
      'program_id', null, 'program_name', 'x', 'workout_name', 'x', 'workout_position', 0, 'sets', '[]'::jsonb));
  exception when unique_violation then
    second_blocked := true;
  end;

  -- B: A'nın oturumunu ve setlerini göremez, güncelleyemez, bitiremez
  perform set_config('request.jwt.claims', json_build_object('sub', b, 'role', 'authenticated')::text, true);
  select count(*) into b_sessions from public.workout_sessions where user_id = a;
  select count(*) into b_sets from public.session_sets where session_id = s_id;
  update public.session_sets set reps = 99 where session_id = s_id;
  get diagnostics b_updated = row_count;
  begin
    perform public.finish_session(s_id, '[]'::jsonb);
  exception when others then
    b_finish_blocked := true;
  end;

  -- A: seti tamamlar, 1RM ile bitirir
  perform set_config('request.jwt.claims', json_build_object('sub', a, 'role', 'authenticated')::text, true);
  update public.session_sets set weight_kg = 60, reps = 5, completed_at = now() where session_id = s_id;
  perform public.finish_session(s_id, '[{"exercise_id":"Barbell_Squat","weight_kg":123.4}]'::jsonb);

  reset role;
  select finished_at is not null into is_finished from public.workout_sessions where id = s_id;
  select next_rotation_position into rotation from public.profiles where user_id = a;
  select weight_kg into orm from public.user_one_rep_maxes where user_id = a and exercise_id = 'Barbell_Squat';

  raise exception 'SONUC: ikinci_oturum_engellendi=% B_gorulen_oturum=% B_gorulen_set=% B_guncellenen_set=% B_bitirme_engellendi=% bitti=% rotasyon=% 1rm=%',
    second_blocked, b_sessions, b_sets, b_updated, b_finish_blocked, is_finished, rotation, orm;
end $$;
```

- [ ] **Step 2: Migration ve kontroller (kullanıcı)**

Kullanıcıya: Dashboard → SQL Editor'da `0008_create_workout_sessions.sql`'i **bir kez** çalıştırması (PowerShell'de `Get-Content D:\spor_takip\supabase\migrations\0008_create_workout_sessions.sql -Raw -Encoding UTF8 | Set-Clipboard`, sonra Editor'a yapıştır → Run). "already exists" hatası alırsa migration zaten uygulanmıştır; tekrar çalıştırmaz. Ardından `f4a_rls_checks.sql`'i aynı yolla çalıştırıp çıkan `SONUC:` satırını paylaşması; değerler betik başındaki "Beklenen" satırıyla karşılaştırılır.

- [ ] **Step 3: Release web build ve manuel kontrol listesi (kullanıcı)**

Run (arka planda, ~15–25 dk): `flutter build web --release`
Kullanıcı kendi PowerShell'inde: `cd D:\spor_takip\build\web; python -m http.server 5555 --bind 127.0.0.1` → `http://127.0.0.1:5555` (Ctrl+Shift+R).

Kontrol listesi:
1. StrongLifts aktifken ana sayfada sıradaki antrenman ve **Başla**; basınca tam ekran antrenman açılıyor, süre işliyor.
2. İlk squat setinin kilosunu değiştir → alttaki setler de değişiyor; ✓ → satır yeşil, dinlenme sayacı 3:00'ten geri sayıyor; +30 sn ve Atla çalışıyor.
3. Sayfayı yenile (F5) → ana sayfada **Devam et**; açınca tamamlanan set hâlâ yeşil.
4. Hareket ekle (seçiciden) → 3 set × 8–12 kartı en altta; bir hareketi menüden çıkar → yapılmamış setleri gidiyor.
5. Tüm setleri yapıp **Bitir** → özet: süre, set sayısı, hacim → Kaydet → ana sayfa sıradaki antrenmanı (B) gösteriyor.
6. Bir sonraki A antrenmanını başlat → squat önerisi +5 kg, bench +2,5 kg (her set hedefe ulaşmışsa).
7. 5/3/1 BBB aktif (1RM'ler girilmiş) → AMRAP setinde hedefin 3 fazlasını gir → Bitir → özette "… → +5 kg" önerisi, onaylayınca 1RM panelinde yeni değer.
8. Başka bir programın detayında "Başla" → devam eden oturum varsa diyalog; "İptal et, yenisini başlat" eskisini siliyor.
9. Antrenman sekmesi → geçmiş ikonu → bitmiş oturumlar listeleniyor; detayda yapılmayan setler soluk; silince listeden gidiyor.
10. Hiç set yapmadan Bitir → iptal önerisi; antrenman menüsünden İptal → onay → ana sayfa.
11. Bir kayıtta kullandığın kendi hareketini seçicide silmeye çalış → "programında veya antrenman kayıtlarında kullanılıyor".

- [ ] **Step 4: PLAN.md ve commit**

`PLAN.md` Değişiklik Günlüğü tablosuna, doğrulama sonuçlarını gerçek bulgularla yansıtan bir satır ekle (tarih, tamamlanan kapsam, bulunan/düzeltilen hatalar, test sayıları).

```bash
git add supabase/migrations/checks/f4a_rls_checks.sql PLAN.md
git commit -m "Document F4a verification and add RLS check script"
```
