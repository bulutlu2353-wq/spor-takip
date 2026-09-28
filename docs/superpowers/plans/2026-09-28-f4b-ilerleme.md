# F4b — İlerleme Takibi Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ana sayfada haftalık özet, vücut ağırlığı, güç ilerlemesi ve beden ölçüleri kartları; kilo, güç ve ölçüler için grafikli ayrıntı ekranları; en yeni kilo kaydının profildeki kiloyu ve kalori/protein hedeflerini otomatik güncellemesi.

**Architecture:** Yeni SQL yalnızca `body_weight_logs` / `body_measurements` tabloları ve profil tutarlılığı için iki RPC'dir (`log_body_weight`, `delete_body_weight`). Güç grafikleri ve haftalık özet mevcut `workout_sessions`/`session_sets` ve `meals` tablolarından okunur; tüm hesaplar `lib/features/progress/domain/` altında saf Dart fonksiyonlarıdır. Yeni hedefleri mevcut `TdeeCalculator` hesaplayıp RPC'ye verir. Grafikler `fl_chart` ile tek bir ortak sarmalayıcıdan (`ProgressLineChart`) çizilir.

**Tech Stack:** Flutter + Riverpod 3 (`FutureProvider.autoDispose`) + go_router 18 + supabase_flutter 2.17 + easy_localization + **fl_chart ^1.2.0 (yeni)**. Backend: Postgres (Supabase) plpgsql fonksiyonları.

**Spec:** `docs/superpowers/specs/2026-09-28-f4b-ilerleme-design.md`

## Global Constraints

- İki yeni tabloda RLS zorunlu; kullanıcı yalnızca kendi satırlarını görür/yazar (spec §3).
- İki RPC `security invoker`, tek transaction (spec §3).
- Kilo `0 < kg < 500`, ölçü `0 < cm < 300`; aynı sınırlar hem formda hem veritabanı `check`'inde (spec §3, §7).
- Günde tek kilo kaydı, günde tek ölçüm (`unique (user_id, tarih)`); aynı güne yeni kayıt üzerine yazar (spec §3).
- Tahmini 1RM: Epley `kilo × (1 + tekrar / 30)`, `tekrar == 1` → kilo; yalnızca tamamlanmış, kilolu, `1 ≤ tekrar ≤ 10` setler (spec §4.1).
- Hafta: yerel saatle Pazartesi 00:00 – sonraki Pazartesi 00:00 (hariç) (spec §4.4).
- Hareket adları İngilizce kalır; tüm diğer UI metinleri `assets/translations/tr.json` + `en.json`'daki `progress` bölümündedir.
- Supabase'e dokunan repository sınıfları doğrudan unit test edilmez; iş mantığı fake repository ile test edilir; SQL Task 12'de kullanıcıyla SQL Editor'da doğrulanır.
- Widget testlerinde `.tr()` çıktısına güvenilmez; bulma `Key`, ikon veya veri metni (hareket adı, sayılar) ile yapılır.
- "Şimdi"ye bağlı her provider/servis `nowProvider`'ı (`lib/features/workout/application/session_providers.dart`) kullanır; testlerde sabit bir fonksiyonla override edilir.
- `flutter analyze` "No issues found!" vermeli (info dahil): her `await`'ten sonra `context` kullanmadan önce `context.mounted` / `mounted` kontrolü.
- Tüm `flutter` komutları `--no-pub` ile çalıştırılır (otomatik `pub get` bu makinede ağda takılıyor); tek istisna Task 6'daki `flutter pub add`.
- Tüm işler `f4b-ilerleme` dalında yapılır (`f4a-set-kaydi`'den açıldı).
- Düşük bellekli makine: `flutter test` tam paket ~9 dk sürer; görev içinde yalnızca ilgili test dosyaları, görev sonunda tam paket.

## Spec'ten Bilinçli Sapmalar (plan yazımında ortaya çıktı)

1. **Güç ekranı tüm geçmişi bir kez çeker** (`allSessionsProvider`); spec "Tümü seçilince ayrıca çekilir" diyordu. Hareket seçicisi zaten tüm geçmişteki hareketleri listelemek zorunda, iki ayrı sorgu gereksiz.
2. **Kilo kayıtlarının tamamı çekilir** (spec "son ~13 ay" diyordu): kilo ekranındaki "Tümü" aralığı için gerekli. PostgREST'in 1000 satır sınırına karşı yeniden eskiye sıralanıp çevrilir; sınır aşılırsa en eskiler düşer.
3. **Diyaloglardaki kaydetme hataları SnackBar yerine diyalog içinde metin olarak gösterilir**: SnackBar açık diyaloğun altında kalıyor.
4. **`routerProvider` yalnızca profilin *durumunu* izler** (Task 5): kilo kaydı `profileProvider`'ı yeniler; router tüm profili izlediği için her yenilemede yeni bir `GoRouter` kuruluyor ve kullanıcı kilo ekranından ana sayfaya atılıyordu.
5. **Kilo kaydı silme, listede kaydırma yerine satırdaki çöp kutusu ikonuyla** (onaylı) yapılır.

## Dosya Haritası

```
supabase/migrations/
  0009_create_body_tracking.sql            # tablolar + RLS + 2 RPC + backfill        (Task 1)
  checks/f4b_rls_checks.sql                # elle doğrulama betiği                     (Task 12)
lib/features/progress/
  domain/  progress_format.dart   (tarih ve sayı biçimleri)                            (Task 2)
           body_weight_log.dart, body_measurement.dart                                 (Task 2)
           profile_weight_update.dart (TdeeCalculator ile yeni hedefler)                (Task 2)
           trend.dart (ValuePoint, ChartRange, 30 günlük değişim)                        (Task 3)
           strength.dart (Epley, StrengthSeries, en sık 3 hareket)                      (Task 3)
           weekly_summary.dart                                                          (Task 4)
  data/    progress_data_repository.dart, body_weight_repository.dart,
           body_measurement_repository.dart                                            (Task 5)
  application/ progress_providers.dart, body_weight_service.dart                       (Task 5)
  presentation/ widgets/progress_line_chart.dart, widgets/range_selector.dart,
                widgets/card_states.dart                                               (Task 6)
                widgets/targets_card.dart, widgets/weekly_summary_card.dart            (Task 7)
                widgets/body_weight_card.dart, widgets/weight_log_dialog.dart,
                weight_screen.dart                                                     (Task 8)
                widgets/strength_card.dart, strength_screen.dart                       (Task 9)
                widgets/measurements_card.dart, widgets/measurement_form_dialog.dart,
                measurements_screen.dart                                               (Task 10)
lib/features/onboarding/presentation/home_screen.dart   (değişir)                      (Task 7–10)
lib/features/onboarding/presentation/onboarding_wizard_screen.dart (değişir)           (Task 11)
lib/features/workout/application/session_notifier.dart  (değişir)                      (Task 11)
lib/features/workout/presentation/history_detail_screen.dart (değişir)                 (Task 11)
lib/features/nutrition/application/meal_capture_notifier.dart (değişir)                (Task 11)
lib/core/router.dart   (değişir)                                                        (Task 5, 8, 9, 10)
assets/translations/tr.json, en.json  (progress bölümü)                                 (Task 2)
test/features/progress/fixtures.dart, fakes.dart                                       (Task 2, 5)
```

---

## Task 1: Veritabanı şeması ve RPC'ler — `0009`

**Files:**
- Create: `supabase/migrations/0009_create_body_tracking.sql`

**Interfaces:**
- Produces: tablolar `public.body_weight_logs (user_id, logged_on date, weight_kg)`, `public.body_measurements (user_id, measured_on date, neck, shoulders, chest, waist, hips, arm, forearm, thigh, calf)`; `public.log_body_weight(p_date date, p_kg numeric, p_calorie_target numeric, p_protein_target numeric) returns void`; `public.delete_body_weight(p_date date, p_new_latest_kg numeric, p_calorie_target numeric, p_protein_target numeric) returns void`. Hata mesajları: tek kayıt silinmek istenirse `last_weight_log`, uygulamanın listesi eskiyse `stale_weight_list`.

SQL bu görevde otomatik test edilmez (bkz. Global Constraints); Task 12'de kullanıcıyla doğrulanır.

- [ ] **Step 1: Migration'ı yaz**

`supabase/migrations/0009_create_body_tracking.sql`:

```sql
-- F4b: vücut ağırlığı ve beden ölçüleri.

create table if not exists public.body_weight_logs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  logged_on date not null,
  weight_kg numeric not null check (weight_kg > 0 and weight_kg < 500),
  created_at timestamptz not null default now(),
  unique (user_id, logged_on)              -- günde tek kayıt
);

create table if not exists public.body_measurements (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  measured_on date not null,
  -- cm; hepsi isteğe bağlı
  neck numeric check (neck > 0 and neck < 300),
  shoulders numeric check (shoulders > 0 and shoulders < 300),
  chest numeric check (chest > 0 and chest < 300),
  waist numeric check (waist > 0 and waist < 300),
  hips numeric check (hips > 0 and hips < 300),
  arm numeric check (arm > 0 and arm < 300),
  forearm numeric check (forearm > 0 and forearm < 300),
  thigh numeric check (thigh > 0 and thigh < 300),
  calf numeric check (calf > 0 and calf < 300),
  created_at timestamptz not null default now(),
  unique (user_id, measured_on),           -- günde tek ölçüm
  check (num_nonnulls(neck, shoulders, chest, waist, hips, arm, forearm, thigh, calf) > 0)
);

alter table public.body_weight_logs enable row level security;
alter table public.body_measurements enable row level security;

create policy "Users can manage own weight logs"
  on public.body_weight_logs for all
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

create policy "Users can manage own measurements"
  on public.body_measurements for all
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

-- Kilo kaydını yazar (aynı güne üzerine yazar). Kayıt en yeniyse profildeki kilo
-- ve hedefler de güncellenir; hedefleri uygulama TdeeCalculator ile hesaplar.
create or replace function public.log_body_weight(
  p_date date,
  p_kg numeric,
  p_calorie_target numeric,
  p_protein_target numeric
) returns void
language plpgsql
security invoker
set search_path = public
as $$
declare
  uid uuid := auth.uid();
  latest date;
begin
  if uid is null then
    raise exception 'not authenticated';
  end if;

  insert into body_weight_logs (user_id, logged_on, weight_kg)
    values (uid, p_date, p_kg)
    on conflict (user_id, logged_on) do update set weight_kg = excluded.weight_kg;

  select max(logged_on) into latest from body_weight_logs where user_id = uid;
  if p_date >= latest then
    update profiles
      set weight_kg = p_kg,
          daily_calorie_target = p_calorie_target,
          daily_protein_target_g = p_protein_target,
          updated_at = now()
      where user_id = uid;
  end if;
end;
$$;

-- Kilo kaydını siler. Tek kayıt silinemez (profildeki kilonun kaynağı).
-- Silinen en yeniyse profil kalan en yeni kayda göre güncellenir; uygulamanın
-- gönderdiği kilo o kayıtla uyuşmuyorsa (eski liste) işlem geri alınır.
create or replace function public.delete_body_weight(
  p_date date,
  p_new_latest_kg numeric,
  p_calorie_target numeric,
  p_protein_target numeric
) returns void
language plpgsql
security invoker
set search_path = public
as $$
declare
  uid uuid := auth.uid();
  remaining int;
  latest date;
  new_kg numeric;
begin
  if uid is null then
    raise exception 'not authenticated';
  end if;

  select count(*), max(logged_on) into remaining, latest
    from body_weight_logs where user_id = uid;
  if remaining <= 1 then
    raise exception 'last_weight_log';
  end if;

  delete from body_weight_logs where user_id = uid and logged_on = p_date;

  if p_date = latest then
    select weight_kg into new_kg
      from body_weight_logs where user_id = uid
      order by logged_on desc limit 1;
    if new_kg is distinct from p_new_latest_kg then
      raise exception 'stale_weight_list';
    end if;
    update profiles
      set weight_kg = new_kg,
          daily_calorie_target = p_calorie_target,
          daily_protein_target_g = p_protein_target,
          updated_at = now()
      where user_id = uid;
  end if;
end;
$$;

-- Mevcut profillerin kilosu ilk kayıt olur; grafik boş başlamaz.
insert into public.body_weight_logs (user_id, logged_on, weight_kg)
select user_id, created_at::date, weight_kg from public.profiles
on conflict (user_id, logged_on) do nothing;
```

- [ ] **Step 2: Commit**

```bash
git add supabase/migrations/0009_create_body_tracking.sql
git commit -m "feat(progress): add body weight and measurement tables with RPCs"
```

---

## Task 2: Ortak biçimler, modeller, hedef hesabı ve çeviriler

**Files:**
- Create: `lib/features/progress/domain/progress_format.dart`
- Create: `lib/features/progress/domain/body_weight_log.dart`
- Create: `lib/features/progress/domain/body_measurement.dart`
- Create: `lib/features/progress/domain/profile_weight_update.dart`
- Modify: `assets/translations/tr.json`, `assets/translations/en.json` (yeni üst düzey `progress` bölümü)
- Create: `test/features/progress/fixtures.dart`
- Test: `test/features/progress/domain/progress_format_test.dart`, `test/features/progress/domain/body_models_test.dart`, `test/features/progress/domain/profile_weight_update_test.dart`

**Interfaces:**
- Consumes: `trimNumber(double)` (`lib/features/workout/domain/block_format.dart`); `Profile`, `Gender`, `ActivityLevel`, `Goal` (`lib/features/onboarding/domain/profile.dart`); `TdeeCalculator` (`lib/features/onboarding/domain/tdee_calculator.dart`).
- Produces:
  - `progress_format.dart`: `DateTime dateOnly(DateTime)`, `String formatDbDate(DateTime)`, `DateTime parseDbDate(String)`, `String formatShortDate(DateTime)`, `String formatOneDecimal(double)`, `String formatDelta(double?)`, `double? parseDecimal(String)`.
  - `body_weight_log.dart`: `const maxBodyWeightKg = 500.0`, `bool isValidBodyWeight(double)`, `class BodyWeightLog { DateTime date; double weightKg; BodyWeightLog.fromJson }`.
  - `body_measurement.dart`: `const maxMeasurementCm = 300.0`, `bool isValidMeasurement(double)`, `enum MeasurementSite { neck, shoulders, chest, waist, hips, arm, forearm, thigh, calf }`, `class BodyMeasurement { DateTime date; Map<MeasurementSite, double> values; fromJson; toUpsertJson() }`, `double? measurementChange(List<BodyMeasurement>, MeasurementSite)`.
  - `profile_weight_update.dart`: `class ProfileWeightUpdate { double weightKg, calorieTarget, proteinTargetG }`, `ProfileWeightUpdate profileWeightUpdate(Profile, double weightKg, {required int currentYear, TdeeCalculator calculator})`.
  - `test/features/progress/fixtures.dart`: `testProfile`, `doneSet(...)`, `finishedSession(...)`, `testMeal(...)` (aşağıda).
  - Çeviri anahtarları `progress.*` (aşağıdaki JSON; sonraki görevler yalnızca bunları kullanır).

- [ ] **Step 1: Test fixture'larını yaz**

`test/features/progress/fixtures.dart`:

```dart
import 'package:spor_takip/features/nutrition/domain/food_item.dart';
import 'package:spor_takip/features/nutrition/domain/meal.dart';
import 'package:spor_takip/features/nutrition/domain/meal_type.dart';
import 'package:spor_takip/features/onboarding/domain/profile.dart';
import 'package:spor_takip/features/workout/domain/workout_session.dart';

const testProfile = Profile(
  userId: 'user-1',
  weightKg: 80,
  heightCm: 180,
  birthYear: 1996,
  gender: Gender.male,
  activityLevel: ActivityLevel.moderate,
  doesExercise: true,
  exerciseDaysPerWeek: 3,
  goal: Goal.gainMuscle,
  dailyCalorieTarget: 2700,
  dailyProteinTargetG: 176,
);

/// Tamamlanmış (varsayılan) bir set; [kg] null = vücut ağırlığı.
SessionSet doneSet(
  String exerciseId, {
  double? kg = 100,
  int? reps = 5,
  bool done = true,
  int setIndex = 0,
}) {
  return SessionSet(
    exercisePosition: 0,
    setIndex: setIndex,
    exerciseId: exerciseId,
    exerciseName: '$exerciseId name',
    targetRepsMin: 5,
    targetRepsMax: 5,
    weightKg: kg,
    reps: reps,
    completedAt: done ? DateTime(2026, 9, 1) : null,
  );
}

/// [finishedAt] null = devam eden oturum.
WorkoutSession finishedSession(String id, DateTime? finishedAt, List<SessionSet> sets) {
  return WorkoutSession(
    id: id,
    programName: 'Program',
    workoutName: 'A',
    workoutPosition: 0,
    startedAt: (finishedAt ?? DateTime(2026, 9, 1)).subtract(const Duration(hours: 1)),
    finishedAt: finishedAt,
    sets: sets,
  );
}

/// Tek kalemli öğün.
Meal testMeal(DateTime loggedAt, {double calories = 500, double proteinG = 30}) {
  return Meal(
    id: 'meal-${loggedAt.toIso8601String()}',
    userId: 'user-1',
    mealType: MealType.lunch,
    loggedAt: loggedAt,
    items: [FoodItem(name: 'Yemek', grams: 100, calories: calories, proteinG: proteinG)],
  );
}
```

- [ ] **Step 2: Biçim testlerini yaz**

`test/features/progress/domain/progress_format_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:spor_takip/features/progress/domain/progress_format.dart';

void main() {
  test('dateOnly drops the time of day', () {
    expect(dateOnly(DateTime(2026, 9, 28, 13, 5)), DateTime(2026, 9, 28));
  });

  test('database dates round-trip', () {
    expect(formatDbDate(DateTime(2026, 1, 5, 23, 59)), '2026-01-05');
    expect(parseDbDate('2026-01-05'), DateTime(2026, 1, 5));
  });

  test('short date', () {
    expect(formatShortDate(DateTime(2026, 9, 8)), '8.9.2026');
  });

  test('one decimal', () {
    expect(formatOneDecimal(80), '80');
    expect(formatOneDecimal(80.25), '80.3');
    expect(formatOneDecimal(79.94), '79.9');
  });

  test('delta shows direction, rounds to one decimal, dash for null', () {
    expect(formatDelta(null), '—');
    expect(formatDelta(0.04), '0');
    expect(formatDelta(1.5), '▲ 1.5');
    expect(formatDelta(-2), '▼ 2');
  });

  test('parseDecimal accepts comma and dot', () {
    expect(parseDecimal(' 80,5 '), 80.5);
    expect(parseDecimal('80.5'), 80.5);
    expect(parseDecimal(''), isNull);
    expect(parseDecimal('abc'), isNull);
  });
}
```

- [ ] **Step 3: Model testlerini yaz**

`test/features/progress/domain/body_models_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:spor_takip/features/progress/domain/body_measurement.dart';
import 'package:spor_takip/features/progress/domain/body_weight_log.dart';

BodyMeasurement _m(int day, Map<MeasurementSite, double> values) =>
    BodyMeasurement(date: DateTime(2026, 9, day), values: values);

void main() {
  group('BodyWeightLog', () {
    test('fromJson parses a local date and a numeric weight', () {
      final log = BodyWeightLog.fromJson({'logged_on': '2026-09-28', 'weight_kg': 80});
      expect(log.date, DateTime(2026, 9, 28));
      expect(log.weightKg, 80.0);
    });

    test('valid weight is strictly between 0 and 500', () {
      expect(isValidBodyWeight(0), isFalse);
      expect(isValidBodyWeight(0.1), isTrue);
      expect(isValidBodyWeight(499.9), isTrue);
      expect(isValidBodyWeight(500), isFalse);
    });
  });

  group('BodyMeasurement', () {
    test('fromJson keeps only filled sites', () {
      final m = BodyMeasurement.fromJson({
        'measured_on': '2026-09-28',
        'waist': 82.5,
        'arm': 35,
        'neck': null,
      });
      expect(m.date, DateTime(2026, 9, 28));
      expect(m.values, {MeasurementSite.waist: 82.5, MeasurementSite.arm: 35.0});
    });

    test('toUpsertJson writes every site, empty ones as null', () {
      final json = _m(28, {MeasurementSite.waist: 82}).toUpsertJson();
      expect(json['measured_on'], '2026-09-28');
      expect(json['waist'], 82);
      expect(json.containsKey('neck'), isTrue);
      expect(json['neck'], isNull);
      expect(json.length, 1 + MeasurementSite.values.length);
    });

    test('valid measurement is strictly between 0 and 300', () {
      expect(isValidMeasurement(0), isFalse);
      expect(isValidMeasurement(299.9), isTrue);
      expect(isValidMeasurement(300), isFalse);
    });

    test('measurementChange compares the two newest values of the site', () {
      final list = [
        _m(1, {MeasurementSite.waist: 85}),
        _m(10, {MeasurementSite.arm: 34}),
        _m(20, {MeasurementSite.waist: 83, MeasurementSite.arm: 35}),
      ];
      expect(measurementChange(list, MeasurementSite.waist), -2);
      expect(measurementChange(list, MeasurementSite.arm), 1);
      expect(measurementChange(list, MeasurementSite.neck), isNull);
      expect(measurementChange([list.first], MeasurementSite.waist), isNull);
    });
  });
}
```

- [ ] **Step 4: Hedef hesabı testini yaz**

`test/features/progress/domain/profile_weight_update_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:spor_takip/features/onboarding/domain/tdee_calculator.dart';
import 'package:spor_takip/features/progress/domain/profile_weight_update.dart';

import '../fixtures.dart';

void main() {
  test('recalculates targets for the new weight with the other profile fields', () {
    final update = profileWeightUpdate(testProfile, 85, currentYear: 2026);
    final expected = const TdeeCalculator().calculate(
      weightKg: 85,
      heightCm: 180,
      birthYear: 1996,
      currentYear: 2026,
      gender: testProfile.gender,
      activityLevel: testProfile.activityLevel,
      goal: testProfile.goal,
    );
    expect(update.weightKg, 85);
    expect(update.calorieTarget, expected.calorieTarget);
    expect(update.proteinTargetG, expected.proteinTargetG);
    expect(update.calorieTarget, isNot(testProfile.dailyCalorieTarget));
  });
}
```

- [ ] **Step 5: Testlerin başarısız olduğunu gör**

Run: `flutter test --no-pub test/features/progress/domain/`
Expected: FAIL — `progress_format.dart`, `body_weight_log.dart` vb. bulunamıyor (derleme hatası).

- [ ] **Step 6: `progress_format.dart`**

```dart
import '../../workout/domain/block_format.dart' show trimNumber;

/// Saatsiz yerel gün.
DateTime dateOnly(DateTime t) => DateTime(t.year, t.month, t.day);

String _two(int n) => n.toString().padLeft(2, '0');

/// Veritabanı `date` biçimi: `2026-09-28`.
String formatDbDate(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${_two(d.month)}-${_two(d.day)}';

/// `2026-09-28` → yerel 28.9.2026 00:00.
DateTime parseDbDate(String value) {
  final parts = value.split('-').map(int.parse).toList();
  return DateTime(parts[0], parts[1], parts[2]);
}

/// `28.9.2026`
String formatShortDate(DateTime d) => '${d.day}.${d.month}.${d.year}';

/// En fazla bir ondalık: 80 → "80", 80.25 → "80.3".
String formatOneDecimal(double value) => trimNumber((value * 10).round() / 10);

/// Fark: null → "—", (yuvarlanmış) 0 → "0", artı → "▲ 1.5", eksi → "▼ 1.5".
String formatDelta(double? delta) {
  if (delta == null) return '—';
  final rounded = (delta * 10).round() / 10;
  if (rounded == 0) return '0';
  return '${rounded > 0 ? '▲' : '▼'} ${formatOneDecimal(rounded.abs())}';
}

/// Kullanıcı girdisi: "80,5" ya da "80.5"; boş ya da geçersiz → null.
double? parseDecimal(String input) => double.tryParse(input.trim().replaceAll(',', '.'));
```

- [ ] **Step 7: `body_weight_log.dart`**

```dart
import 'progress_format.dart';

const maxBodyWeightKg = 500.0;

/// Veritabanındaki `check (weight_kg > 0 and weight_kg < 500)` ile aynı.
bool isValidBodyWeight(double kg) => kg > 0 && kg < maxBodyWeightKg;

/// Bir güne ait tek kilo kaydı.
class BodyWeightLog {
  const BodyWeightLog({required this.date, required this.weightKg});

  /// Yerel gün (saat 00:00).
  final DateTime date;
  final double weightKg;

  factory BodyWeightLog.fromJson(Map<String, dynamic> json) {
    return BodyWeightLog(
      date: parseDbDate(json['logged_on'] as String),
      weightKg: (json['weight_kg'] as num).toDouble(),
    );
  }
}
```

- [ ] **Step 8: `body_measurement.dart`**

```dart
import 'progress_format.dart';

const maxMeasurementCm = 300.0;

/// Veritabanındaki `check (x > 0 and x < 300)` ile aynı.
bool isValidMeasurement(double cm) => cm > 0 && cm < maxMeasurementCm;

/// Ölçü bölgeleri; `name` veritabanındaki sütun adıdır.
enum MeasurementSite { neck, shoulders, chest, waist, hips, arm, forearm, thigh, calf }

/// Bir güne ait ölçüm (cm).
class BodyMeasurement {
  const BodyMeasurement({required this.date, required this.values});

  /// Yerel gün (saat 00:00).
  final DateTime date;

  /// Yalnızca dolu bölgeler.
  final Map<MeasurementSite, double> values;

  factory BodyMeasurement.fromJson(Map<String, dynamic> json) {
    return BodyMeasurement(
      date: parseDbDate(json['measured_on'] as String),
      values: {
        for (final site in MeasurementSite.values)
          if (json[site.name] != null) site: (json[site.name] as num).toDouble(),
      },
    );
  }

  /// Upsert gövdesi (kullanıcı id'si hariç); boş bölgeler null yazılır ki
  /// düzenlemede silinen değerler de temizlensin.
  Map<String, dynamic> toUpsertJson() {
    return {
      'measured_on': formatDbDate(date),
      for (final site in MeasurementSite.values) site.name: values[site],
    };
  }
}

/// [measurements] eskiden yeniye. [site]'in en yeni değeri − bir önceki değeri;
/// bölge iki ölçümde dolu değilse null.
double? measurementChange(List<BodyMeasurement> measurements, MeasurementSite site) {
  final values = [
    for (final m in measurements)
      if (m.values[site] case final value?) value,
  ];
  if (values.length < 2) return null;
  return values.last - values[values.length - 2];
}
```

- [ ] **Step 9: `profile_weight_update.dart`**

```dart
import '../../onboarding/domain/profile.dart';
import '../../onboarding/domain/tdee_calculator.dart';

/// Profilin kilo ve hedef alanlarına yazılacak değerler (RPC parametreleri).
class ProfileWeightUpdate {
  const ProfileWeightUpdate({
    required this.weightKg,
    required this.calorieTarget,
    required this.proteinTargetG,
  });

  final double weightKg;
  final double calorieTarget;
  final double proteinTargetG;
}

/// [profile]'in diğer alanlarıyla [weightKg] için hedefleri yeniden hesaplar;
/// formül yalnızca [TdeeCalculator]'da kalır.
ProfileWeightUpdate profileWeightUpdate(
  Profile profile,
  double weightKg, {
  required int currentYear,
  TdeeCalculator calculator = const TdeeCalculator(),
}) {
  final result = calculator.calculate(
    weightKg: weightKg,
    heightCm: profile.heightCm,
    birthYear: profile.birthYear,
    currentYear: currentYear,
    gender: profile.gender,
    activityLevel: profile.activityLevel,
    goal: profile.goal,
  );
  return ProfileWeightUpdate(
    weightKg: weightKg,
    calorieTarget: result.calorieTarget,
    proteinTargetG: result.proteinTargetG,
  );
}
```

- [ ] **Step 10: Testlerin geçtiğini gör**

Run: `flutter test --no-pub test/features/progress/domain/`
Expected: PASS (tüm testler).

- [ ] **Step 11: Çevirileri ekle**

`assets/translations/tr.json` kök nesnesine (`workout` bölümünden sonra) şu `progress` bölümünü ekle:

```json
"progress": {
  "retry": "Tekrar dene",
  "load_error": "Yüklenemedi",
  "save_error": "Kaydedilemedi, tekrar dene",
  "delete_error": "Silinemedi, tekrar dene",
  "cancel": "Vazgeç",
  "save": "Kaydet",
  "delete": "Sil",
  "delete_confirm": "Bu kayıt silinsin mi?",
  "change_30d": "30 gün: {value}",
  "date": "Tarih: {date}",
  "range": {
    "month": "1 ay",
    "three_months": "3 ay",
    "year": "1 yıl",
    "all": "Tümü"
  },
  "targets": {
    "title": "Günlük hedefler"
  },
  "weekly": {
    "title": "Haftalık özet",
    "so_far": "Bu hafta (şu ana kadar) ve geçen hafta",
    "this_week": "Bu hafta",
    "last_week": "Geçen hafta",
    "change": "Fark",
    "workouts": "Antrenman",
    "sets": "Set",
    "volume": "Hacim (kg)",
    "calories": "Ort. kalori",
    "protein": "Ort. protein (g)",
    "nutrition_days": "Öğün kaydı (gün)",
    "weight": "Kilo (kg)",
    "empty": "Bu hafta ve geçen hafta henüz kayıt yok. Antrenman, öğün ya da kilo kaydettikçe özetin burada görünecek."
  },
  "weight": {
    "title": "Vücut ağırlığı",
    "add": "Kilo ekle",
    "edit": "Kiloyu düzenle",
    "input_label": "Kilo (kg)",
    "invalid": "0 ile 500 arasında bir değer gir",
    "saved": "Kilo kaydedildi",
    "saved_target": "Kilo kaydedildi. Yeni kalori hedefin: {value} kcal",
    "empty": "Henüz kilo kaydın yok. İlk kaydını ekle.",
    "last_log_hint": "Son kalan kilo kaydı silinemez",
    "stale": "Liste güncellendi, tekrar dene"
  },
  "strength": {
    "title": "Güç ilerlemesi",
    "empty": "İlk antrenmanını bitirince burada güç grafiğin görünecek.",
    "exercise": "Hareket",
    "estimated_note": "Tahmini 1RM (Epley): her oturumun en iyi seti; 10 tekrardan fazla ve kilosuz setler sayılmaz."
  },
  "measurements": {
    "title": "Beden ölçüleri",
    "add": "Ölçüm ekle",
    "form_title": "Ölçüm (cm)",
    "empty": "Henüz ölçüm yok. İlk ölçümünü ekle.",
    "last": "Son ölçüm: {date}",
    "need_one": "En az bir ölçü gir",
    "invalid": "0 ile 300 arasında"
  },
  "sites": {
    "neck": "Boyun",
    "shoulders": "Omuz",
    "chest": "Göğüs",
    "waist": "Bel",
    "hips": "Kalça",
    "arm": "Kol",
    "forearm": "Ön kol",
    "thigh": "Uyluk",
    "calf": "Baldır"
  }
}
```

`assets/translations/en.json` kök nesnesine aynı yapıyla:

```json
"progress": {
  "retry": "Retry",
  "load_error": "Could not load",
  "save_error": "Could not save, try again",
  "delete_error": "Could not delete, try again",
  "cancel": "Cancel",
  "save": "Save",
  "delete": "Delete",
  "delete_confirm": "Delete this entry?",
  "change_30d": "30 days: {value}",
  "date": "Date: {date}",
  "range": {
    "month": "1 mo",
    "three_months": "3 mo",
    "year": "1 yr",
    "all": "All"
  },
  "targets": {
    "title": "Daily targets"
  },
  "weekly": {
    "title": "Weekly summary",
    "so_far": "This week (so far) and last week",
    "this_week": "This week",
    "last_week": "Last week",
    "change": "Change",
    "workouts": "Workouts",
    "sets": "Sets",
    "volume": "Volume (kg)",
    "calories": "Avg. calories",
    "protein": "Avg. protein (g)",
    "nutrition_days": "Logged days",
    "weight": "Weight (kg)",
    "empty": "Nothing logged this week or last week yet. Your summary appears here as you log workouts, meals or weight."
  },
  "weight": {
    "title": "Body weight",
    "add": "Log weight",
    "edit": "Edit weight",
    "input_label": "Weight (kg)",
    "invalid": "Enter a value between 0 and 500",
    "saved": "Weight saved",
    "saved_target": "Weight saved. Your new calorie target: {value} kcal",
    "empty": "No weight entries yet. Add your first one.",
    "last_log_hint": "The last remaining weight entry cannot be deleted",
    "stale": "The list was updated, try again"
  },
  "strength": {
    "title": "Strength progress",
    "empty": "Finish your first workout to see your strength chart here.",
    "exercise": "Exercise",
    "estimated_note": "Estimated 1RM (Epley): best set of each session; sets above 10 reps and without weight are not counted."
  },
  "measurements": {
    "title": "Body measurements",
    "add": "Add measurement",
    "form_title": "Measurement (cm)",
    "empty": "No measurements yet. Add your first one.",
    "last": "Last measured: {date}",
    "need_one": "Enter at least one measurement",
    "invalid": "Between 0 and 300"
  },
  "sites": {
    "neck": "Neck",
    "shoulders": "Shoulders",
    "chest": "Chest",
    "waist": "Waist",
    "hips": "Hips",
    "arm": "Arm",
    "forearm": "Forearm",
    "thigh": "Thigh",
    "calf": "Calf"
  }
}
```

İki dosyanın da geçerli JSON olduğunu doğrula:

Run: `python -c "import json; [json.load(open(f'assets/translations/{l}.json', encoding='utf-8'))['progress']['sites']['calf'] for l in ('tr','en')]; print('ok')"`
Expected: `ok`

- [ ] **Step 12: Analiz ve commit**

Run: `flutter analyze --no-pub`
Expected: `No issues found!`

```bash
git add lib/features/progress/domain test/features/progress assets/translations
git commit -m "feat(progress): add body tracking models, formatting and translations"
```

---

## Task 3: Trend ve güç hesapları

**Files:**
- Create: `lib/features/progress/domain/trend.dart`
- Create: `lib/features/progress/domain/strength.dart`
- Test: `test/features/progress/domain/trend_test.dart`, `test/features/progress/domain/strength_test.dart`

**Interfaces:**
- Consumes: `WorkoutSession`, `SessionSet` (`lib/features/workout/domain/workout_session.dart`); fixture'lar `doneSet`, `finishedSession` (Task 2).
- Produces:
  - `trend.dart`: `class ValuePoint { DateTime date; double value; const ValuePoint(date, value) }`, `enum ChartRange { month, threeMonths, year, all }`, `DateTime? rangeStart(ChartRange, DateTime now)`, `bool isInRange(DateTime date, ChartRange, DateTime now)`, `List<ValuePoint> pointsInRange(List<ValuePoint>, ChartRange, DateTime now)`, `double? changeOver30Days(List<ValuePoint>)`.
  - `strength.dart`: `const maxRepsForEstimate = 10`, `double? estimateOneRepMax({required double? weightKg, required int? reps})`, `class StrengthPoint { DateTime date; double estimateKg; double weightKg; int reps }`, `class StrengthSeries { String exerciseId; String exerciseName; List<StrengthPoint> points; StrengthPoint get latest; List<ValuePoint> get valuePoints }`, `List<StrengthSeries> strengthSeries(List<WorkoutSession>)`, `List<StrengthSeries> topStrengthSeries(List<StrengthSeries>, DateTime now, {int count = 3})`.

- [ ] **Step 1: Trend testlerini yaz**

`test/features/progress/domain/trend_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:spor_takip/features/progress/domain/trend.dart';

final _now = DateTime(2026, 9, 28, 15);

ValuePoint _p(int month, int day, double value) => ValuePoint(DateTime(2026, month, day), value);

void main() {
  group('rangeStart', () {
    test('counts days back from today, all has no start', () {
      expect(rangeStart(ChartRange.month, _now), DateTime(2026, 8, 29));
      expect(rangeStart(ChartRange.threeMonths, _now), DateTime(2026, 6, 30));
      expect(rangeStart(ChartRange.year, _now), DateTime(2025, 9, 28));
      expect(rangeStart(ChartRange.all, _now), isNull);
    });

    test('pointsInRange keeps points on or after the start', () {
      final points = [_p(8, 28, 1), _p(8, 29, 2), _p(9, 28, 3)];
      expect(pointsInRange(points, ChartRange.month, _now).map((p) => p.value), [2, 3]);
      expect(pointsInRange(points, ChartRange.all, _now), hasLength(3));
      expect(isInRange(DateTime(2026, 8, 28, 23), ChartRange.month, _now), isFalse);
    });
  });

  group('changeOver30Days', () {
    test('no points or no point old enough → null', () {
      expect(changeOver30Days(const []), isNull);
      expect(changeOver30Days([_p(9, 1, 80), _p(9, 28, 79)]), isNull);
    });

    test('uses the newest point at least 30 days before the last one', () {
      final points = [_p(8, 1, 83), _p(8, 29, 82), _p(9, 10, 81), _p(9, 28, 79.5)];
      // 28.9 − 30 gün = 29.8 → referans 29.8 (82)
      expect(changeOver30Days(points), -2.5);
    });
  });
}
```

- [ ] **Step 2: Güç testlerini yaz**

`test/features/progress/domain/strength_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:spor_takip/features/progress/domain/strength.dart';

import '../fixtures.dart';

void main() {
  group('estimateOneRepMax', () {
    test('Epley, single rep is the weight itself', () {
      expect(estimateOneRepMax(weightKg: 100, reps: 1), 100);
      expect(estimateOneRepMax(weightKg: 100, reps: 5), closeTo(116.67, 0.01));
      expect(estimateOneRepMax(weightKg: 100, reps: 10), closeTo(133.33, 0.01));
    });

    test('ignores sets above 10 reps, without weight or without reps', () {
      expect(estimateOneRepMax(weightKg: 100, reps: 11), isNull);
      expect(estimateOneRepMax(weightKg: null, reps: 5), isNull);
      expect(estimateOneRepMax(weightKg: 0, reps: 5), isNull);
      expect(estimateOneRepMax(weightKg: 100, reps: null), isNull);
      expect(estimateOneRepMax(weightKg: 100, reps: 0), isNull);
    });
  });

  group('strengthSeries', () {
    test('one point per session: its best estimate, dated at the finish', () {
      final series = strengthSeries([
        finishedSession('s1', DateTime(2026, 9, 1, 11), [
          doneSet('squat', kg: 100, reps: 5),
          doneSet('squat', kg: 105, reps: 3, setIndex: 1),
          doneSet('squat', kg: 110, reps: 5, done: false, setIndex: 2), // yapılmadı
        ]),
      ]);
      expect(series, hasLength(1));
      final point = series.single.points.single;
      expect(point.date, DateTime(2026, 9, 1, 11));
      expect(point.estimateKg, closeTo(116.67, 0.01)); // 100×5 > 105×3 (115.5)
      expect(point.weightKg, 100);
      expect(point.reps, 5);
      expect(series.single.exerciseName, 'squat name');
    });

    test('skips in-progress sessions and exercises without countable sets', () {
      final series = strengthSeries([
        finishedSession('s1', DateTime(2026, 9, 1), [
          doneSet('pullup', kg: null, reps: 8), // kilosuz
          doneSet('curl', kg: 15, reps: 12), // 10 tekrardan fazla
        ]),
        finishedSession('s2', null, [doneSet('squat')]), // devam ediyor
      ]);
      expect(series, isEmpty);
    });

    test('sorted by session count, ties by the most recent; points oldest first', () {
      final series = strengthSeries([
        finishedSession('s3', DateTime(2026, 9, 20), [doneSet('bench'), doneSet('row')]),
        finishedSession('s1', DateTime(2026, 9, 1), [doneSet('squat'), doneSet('bench')]),
        finishedSession('s2', DateTime(2026, 9, 10), [doneSet('squat')]),
      ]);
      expect(series.map((s) => s.exerciseId), ['bench', 'squat', 'row']);
      expect(series.first.points.map((p) => p.date), [DateTime(2026, 9, 1), DateTime(2026, 9, 20)]);
      expect(series.first.latest.date, DateTime(2026, 9, 20));
      expect(series.first.valuePoints.last.value, series.first.latest.estimateKg);
    });
  });

  group('topStrengthSeries', () {
    test('counts only the last 90 days and returns at most three', () {
      final now = DateTime(2026, 9, 28);
      final all = strengthSeries([
        // 90 gün öncesinden eski: yalnızca 'old'
        finishedSession('o1', DateTime(2026, 6, 1), [doneSet('old')]),
        finishedSession('o2', DateTime(2026, 6, 2), [doneSet('old')]),
        finishedSession('o3', DateTime(2026, 6, 3), [doneSet('old')]),
        finishedSession('a', DateTime(2026, 9, 1), [doneSet('squat'), doneSet('bench'), doneSet('row')]),
        finishedSession('b', DateTime(2026, 9, 5), [doneSet('squat'), doneSet('press')]),
        finishedSession('c', DateTime(2026, 9, 9), [doneSet('bench')]),
      ]);
      final top = topStrengthSeries(all, now);
      // squat 2, bench 2 (son: 9.9 → önce), sonra row (1.9) ile press (5.9) → press daha yeni
      expect(top.map((s) => s.exerciseId), ['bench', 'squat', 'press']);
    });
  });
}
```

- [ ] **Step 3: Testlerin başarısız olduğunu gör**

Run: `flutter test --no-pub test/features/progress/domain/trend_test.dart test/features/progress/domain/strength_test.dart`
Expected: FAIL — `trend.dart` / `strength.dart` bulunamıyor.

- [ ] **Step 4: `trend.dart`**

```dart
/// Grafikte tek nokta.
class ValuePoint {
  const ValuePoint(this.date, this.value);

  final DateTime date;
  final double value;
}

/// Grafik aralığı seçimi.
enum ChartRange { month, threeMonths, year, all }

/// Aralığın ilk günü (dahil, yerel 00:00); [ChartRange.all] için null.
DateTime? rangeStart(ChartRange range, DateTime now) {
  final days = switch (range) {
    ChartRange.month => 30,
    ChartRange.threeMonths => 90,
    ChartRange.year => 365,
    ChartRange.all => null,
  };
  if (days == null) return null;
  return DateTime(now.year, now.month, now.day - days);
}

bool isInRange(DateTime date, ChartRange range, DateTime now) {
  final start = rangeStart(range, now);
  return start == null || !date.isBefore(start);
}

List<ValuePoint> pointsInRange(List<ValuePoint> points, ChartRange range, DateTime now) =>
    [for (final p in points) if (isInRange(p.date, range, now)) p];

/// Spec §4.3. [points] eskiden yeniye: son değer − (tarihi son tarihten en az
/// 30 gün önce olan en yeni değer). Böyle bir değer yoksa null.
double? changeOver30Days(List<ValuePoint> points) {
  if (points.isEmpty) return null;
  final last = points.last;
  final cutoff = DateTime(last.date.year, last.date.month, last.date.day - 30);
  ValuePoint? reference;
  for (final p in points) {
    if (!p.date.isAfter(cutoff)) reference = p;
  }
  return reference == null ? null : last.value - reference.value;
}
```

Not: `cutoff` gün bazındadır; saatli noktalarda (güç) son noktanın gün başına göre 30 gün geriye bakılır.

- [ ] **Step 5: `strength.dart`**

```dart
import '../../workout/domain/workout_session.dart';
import 'trend.dart';

/// Epley yüksek tekrarda güvenilmez; bundan fazla tekrarlı setler sayılmaz.
const maxRepsForEstimate = 10;

/// Spec §4.1: Epley `kilo × (1 + tekrar / 30)`; tek tekrar → kilonun kendisi.
/// Kilosuz, tekrarsız ya da 10'dan fazla tekrarlı sette null.
double? estimateOneRepMax({required double? weightKg, required int? reps}) {
  if (weightKg == null || reps == null) return null;
  if (weightKg <= 0 || reps < 1 || reps > maxRepsForEstimate) return null;
  return reps == 1 ? weightKg : weightKg * (1 + reps / 30);
}

/// Bir oturumdaki bir hareketin en iyi seti.
class StrengthPoint {
  const StrengthPoint({
    required this.date,
    required this.estimateKg,
    required this.weightKg,
    required this.reps,
  });

  /// Oturumun bitişi (yerel).
  final DateTime date;
  final double estimateKg;
  final double weightKg;
  final int reps;
}

class StrengthSeries {
  const StrengthSeries({required this.exerciseId, required this.exerciseName, required this.points});

  final String exerciseId;
  final String exerciseName;

  /// Oturum başına bir nokta, eskiden yeniye; boş olmaz.
  final List<StrengthPoint> points;

  StrengthPoint get latest => points.last;

  List<ValuePoint> get valuePoints => [for (final p in points) ValuePoint(p.date, p.estimateKg)];
}

int _mostFrequentFirst(StrengthSeries a, StrengthSeries b, int Function(StrengthSeries) count) {
  final byCount = count(b).compareTo(count(a));
  return byCount != 0 ? byCount : b.latest.date.compareTo(a.latest.date);
}

/// Bitmiş oturumlardan hareket başına seri. Sıra: oturum sayısı çoktan aza,
/// eşitlikte en son yapılan önce.
List<StrengthSeries> strengthSeries(List<WorkoutSession> sessions) {
  final points = <String, List<StrengthPoint>>{};
  final names = <String, String>{};
  for (final session in sessions) {
    final finishedAt = session.finishedAt;
    if (finishedAt == null) continue;
    final best = <String, StrengthPoint>{};
    for (final set in session.sets) {
      if (!set.isCompleted) continue;
      final estimate = estimateOneRepMax(weightKg: set.weightKg, reps: set.reps);
      if (estimate == null) continue;
      final current = best[set.exerciseId];
      if (current == null || estimate > current.estimateKg) {
        best[set.exerciseId] = StrengthPoint(
          date: finishedAt.toLocal(),
          estimateKg: estimate,
          weightKg: set.weightKg!,
          reps: set.reps!,
        );
        names[set.exerciseId] = set.exerciseName;
      }
    }
    for (final MapEntry(key: exerciseId, value: point) in best.entries) {
      (points[exerciseId] ??= []).add(point);
    }
  }
  final series = [
    for (final MapEntry(key: exerciseId, value: list) in points.entries)
      StrengthSeries(
        exerciseId: exerciseId,
        exerciseName: names[exerciseId]!,
        points: list..sort((a, b) => a.date.compareTo(b.date)),
      ),
  ];
  return series..sort((a, b) => _mostFrequentFirst(a, b, (s) => s.points.length));
}

/// Spec §4.2: son 90 günde en çok oturumda yapılan [count] hareket.
List<StrengthSeries> topStrengthSeries(List<StrengthSeries> all, DateTime now, {int count = 3}) {
  final since = DateTime(now.year, now.month, now.day - 90);
  int recent(StrengthSeries s) => s.points.where((p) => !p.date.isBefore(since)).length;
  final candidates = [for (final s in all) if (recent(s) > 0) s]
    ..sort((a, b) => _mostFrequentFirst(a, b, recent));
  return candidates.take(count).toList();
}
```

- [ ] **Step 6: Testlerin geçtiğini gör**

Run: `flutter test --no-pub test/features/progress/domain/trend_test.dart test/features/progress/domain/strength_test.dart`
Expected: PASS.

- [ ] **Step 7: Analiz ve commit**

Run: `flutter analyze --no-pub`
Expected: `No issues found!`

```bash
git add lib/features/progress/domain/trend.dart lib/features/progress/domain/strength.dart test/features/progress/domain/trend_test.dart test/features/progress/domain/strength_test.dart
git commit -m "feat(progress): add estimated 1RM series and 30-day trend"
```

---

## Task 4: Haftalık özet hesabı

**Files:**
- Create: `lib/features/progress/domain/weekly_summary.dart`
- Test: `test/features/progress/domain/weekly_summary_test.dart`

**Interfaces:**
- Consumes: `completedSetCount`, `totalVolumeKg` (`lib/features/workout/domain/session_stats.dart`); `sumMealMacros` (`lib/features/nutrition/domain/macro_totals.dart`); `Meal`; `BodyWeightLog` (Task 2); fixture'lar `doneSet`, `finishedSession`, `testMeal` (Task 2).
- Produces: `DateTime startOfWeek(DateTime)`, `class WeekStats { int workouts; int sets; double volumeKg; int nutritionDays; double? avgCalories; double? avgProteinG; double? lastWeightKg; bool get isEmpty }`, `class WeeklySummary { DateTime weekStart; WeekStats thisWeek; WeekStats lastWeek; bool get isEmpty; double? get weightChangeKg }`, `WeeklySummary weeklySummary({required DateTime now, required List<WorkoutSession> sessions, required List<Meal> meals, required List<BodyWeightLog> weights})`.

- [ ] **Step 1: Testleri yaz**

`test/features/progress/domain/weekly_summary_test.dart` (28 Eylül 2026 Pazartesi'dir):

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:spor_takip/features/progress/domain/body_weight_log.dart';
import 'package:spor_takip/features/progress/domain/weekly_summary.dart';

import '../fixtures.dart';

final _now = DateTime(2026, 9, 30, 12); // Çarşamba

void main() {
  test('startOfWeek is Monday 00:00 in local time', () {
    expect(startOfWeek(_now), DateTime(2026, 9, 28));
    expect(startOfWeek(DateTime(2026, 9, 28)), DateTime(2026, 9, 28));
    expect(startOfWeek(DateTime(2026, 9, 27, 23, 59)), DateTime(2026, 9, 21));
    expect(startOfWeek(DateTime(2026, 10, 4, 22)), DateTime(2026, 9, 28));
  });

  test('workouts, sets and volume count finished sessions by their finish time', () {
    final summary = weeklySummary(
      now: _now,
      sessions: [
        // Pazartesi 00:00 tam sınır → bu hafta
        finishedSession('a', DateTime(2026, 9, 28), [
          doneSet('squat', kg: 100, reps: 5),
          doneSet('squat', kg: 100, reps: 5, setIndex: 1),
          doneSet('squat', kg: 100, reps: 5, setIndex: 2, done: false),
        ]),
        // Pazar 23:59 → geçen hafta
        finishedSession('b', DateTime(2026, 9, 27, 23, 59), [doneSet('bench', kg: 60, reps: 10)]),
        // iki hafta önce → hiçbiri
        finishedSession('c', DateTime(2026, 9, 20), [doneSet('bench')]),
        // devam ediyor → sayılmaz
        finishedSession('d', null, [doneSet('bench')]),
      ],
      meals: const [],
      weights: const [],
    );
    expect(summary.weekStart, DateTime(2026, 9, 28));
    expect(summary.thisWeek.workouts, 1);
    expect(summary.thisWeek.sets, 2);
    expect(summary.thisWeek.volumeKg, 1000);
    expect(summary.lastWeek.workouts, 1);
    expect(summary.lastWeek.sets, 1);
    expect(summary.lastWeek.volumeKg, 600);
  });

  test('nutrition averages only over days with at least one meal', () {
    final summary = weeklySummary(
      now: _now,
      sessions: const [],
      meals: [
        testMeal(DateTime(2026, 9, 28, 8), calories: 1000, proteinG: 50),
        testMeal(DateTime(2026, 9, 28, 19), calories: 800, proteinG: 40),
        testMeal(DateTime(2026, 9, 29, 13), calories: 2200, proteinG: 110),
        testMeal(DateTime(2026, 9, 22, 13), calories: 1500, proteinG: 60),
      ],
      weights: const [],
    );
    expect(summary.thisWeek.nutritionDays, 2);
    expect(summary.thisWeek.avgCalories, 2000); // (1800 + 2200) / 2
    expect(summary.thisWeek.avgProteinG, 100); // (90 + 110) / 2
    expect(summary.lastWeek.nutritionDays, 1);
    expect(summary.lastWeek.avgCalories, 1500);
  });

  test('weight change is last entry of this week minus last entry of last week', () {
    final summary = weeklySummary(
      now: _now,
      sessions: const [],
      meals: const [],
      weights: [
        BodyWeightLog(date: DateTime(2026, 9, 29), weightKg: 80),
        BodyWeightLog(date: DateTime(2026, 9, 22), weightKg: 81),
        BodyWeightLog(date: DateTime(2026, 9, 26), weightKg: 80.5),
      ],
    );
    expect(summary.thisWeek.lastWeightKg, 80);
    expect(summary.lastWeek.lastWeightKg, 80.5);
    expect(summary.weightChangeKg, -0.5);
  });

  test('empty weeks have no averages and no weight change', () {
    final summary = weeklySummary(
      now: _now,
      sessions: const [],
      meals: const [],
      weights: [BodyWeightLog(date: DateTime(2026, 9, 29), weightKg: 80)],
    );
    expect(summary.thisWeek.avgCalories, isNull);
    expect(summary.thisWeek.avgProteinG, isNull);
    expect(summary.weightChangeKg, isNull);
    expect(summary.lastWeek.isEmpty, isTrue);
    expect(summary.isEmpty, isFalse);
    expect(
      weeklySummary(now: _now, sessions: const [], meals: const [], weights: const []).isEmpty,
      isTrue,
    );
  });
}
```

- [ ] **Step 2: Testin başarısız olduğunu gör**

Run: `flutter test --no-pub test/features/progress/domain/weekly_summary_test.dart`
Expected: FAIL — `weekly_summary.dart` bulunamıyor.

- [ ] **Step 3: `weekly_summary.dart`**

```dart
import '../../nutrition/domain/macro_totals.dart';
import '../../nutrition/domain/meal.dart';
import '../../workout/domain/session_stats.dart';
import '../../workout/domain/workout_session.dart';
import 'body_weight_log.dart';

/// Yerel saatle haftanın Pazartesi 00:00'ı (gün aritmetiği, DST'den etkilenmez).
DateTime startOfWeek(DateTime t) => DateTime(t.year, t.month, t.day - (t.weekday - 1));

class WeekStats {
  const WeekStats({
    required this.workouts,
    required this.sets,
    required this.volumeKg,
    required this.nutritionDays,
    this.avgCalories,
    this.avgProteinG,
    this.lastWeightKg,
  });

  final int workouts;
  final int sets;
  final double volumeKg;

  /// En az bir öğün kaydedilen gün sayısı.
  final int nutritionDays;

  /// Yalnızca öğün kaydedilen günlerin ortalaması; hiç yoksa null.
  final double? avgCalories;
  final double? avgProteinG;

  /// Haftanın son kilo kaydı.
  final double? lastWeightKg;

  bool get isEmpty => workouts == 0 && nutritionDays == 0 && lastWeightKg == null;
}

class WeeklySummary {
  const WeeklySummary({required this.weekStart, required this.thisWeek, required this.lastWeek});

  /// Bu haftanın Pazartesi'si.
  final DateTime weekStart;
  final WeekStats thisWeek;
  final WeekStats lastWeek;

  bool get isEmpty => thisWeek.isEmpty && lastWeek.isEmpty;

  /// Bu haftanın son kilosu − geçen haftanın son kilosu; biri yoksa null.
  double? get weightChangeKg {
    final current = thisWeek.lastWeightKg;
    final previous = lastWeek.lastWeightKg;
    return current == null || previous == null ? null : current - previous;
  }
}

WeekStats _weekStats({
  required DateTime start,
  required DateTime end,
  required List<WorkoutSession> sessions,
  required List<Meal> meals,
  required List<BodyWeightLog> weights,
}) {
  bool inWeek(DateTime t) => !t.isBefore(start) && t.isBefore(end);

  final weekSessions = [
    for (final s in sessions)
      if (s.finishedAt case final finishedAt? when inWeek(finishedAt.toLocal())) s,
  ];

  final mealsByDay = <DateTime, List<Meal>>{};
  for (final meal in meals) {
    final local = meal.loggedAt.toLocal();
    if (!inWeek(local)) continue;
    (mealsByDay[DateTime(local.year, local.month, local.day)] ??= []).add(meal);
  }
  final dayTotals = [for (final dayMeals in mealsByDay.values) sumMealMacros(dayMeals)];
  final days = dayTotals.length;

  final weekWeights = [for (final w in weights) if (inWeek(w.date)) w]
    ..sort((a, b) => a.date.compareTo(b.date));

  return WeekStats(
    workouts: weekSessions.length,
    sets: weekSessions.fold<int>(0, (sum, s) => sum + completedSetCount(s)),
    volumeKg: weekSessions.fold<double>(0, (sum, s) => sum + totalVolumeKg(s)),
    nutritionDays: days,
    avgCalories: days == 0 ? null : dayTotals.fold<double>(0, (sum, t) => sum + t.calories) / days,
    avgProteinG: days == 0 ? null : dayTotals.fold<double>(0, (sum, t) => sum + t.proteinG) / days,
    lastWeightKg: weekWeights.isEmpty ? null : weekWeights.last.weightKg,
  );
}

/// Spec §4.4: bu hafta (Pazartesi'den [now]'a) ve bir önceki tam hafta.
WeeklySummary weeklySummary({
  required DateTime now,
  required List<WorkoutSession> sessions,
  required List<Meal> meals,
  required List<BodyWeightLog> weights,
}) {
  final start = startOfWeek(now);
  final previous = DateTime(start.year, start.month, start.day - 7);
  final next = DateTime(start.year, start.month, start.day + 7);
  return WeeklySummary(
    weekStart: start,
    thisWeek: _weekStats(start: start, end: next, sessions: sessions, meals: meals, weights: weights),
    lastWeek: _weekStats(start: previous, end: start, sessions: sessions, meals: meals, weights: weights),
  );
}
```

- [ ] **Step 4: Testin geçtiğini gör**

Run: `flutter test --no-pub test/features/progress/domain/weekly_summary_test.dart`
Expected: PASS.

- [ ] **Step 5: Analiz ve commit**

Run: `flutter analyze --no-pub`
Expected: `No issues found!`

```bash
git add lib/features/progress/domain/weekly_summary.dart test/features/progress/domain/weekly_summary_test.dart
git commit -m "feat(progress): add weekly summary calculation"
```

---

## Task 5: Veri katmanı, provider'lar, kilo servisi ve router düzeltmesi

**Files:**
- Create: `lib/features/progress/data/progress_data_repository.dart`
- Create: `lib/features/progress/data/body_weight_repository.dart`
- Create: `lib/features/progress/data/body_measurement_repository.dart`
- Create: `lib/features/progress/application/progress_providers.dart`
- Create: `lib/features/progress/application/body_weight_service.dart`
- Modify: `lib/core/router.dart:23-33` (profil durumunu `select` ile izle)
- Create: `test/features/progress/fakes.dart`
- Test: `test/features/progress/application/body_weight_service_test.dart`, `test/features/progress/application/progress_providers_test.dart`, `test/core/router_test.dart`

**Interfaces:**
- Consumes: Task 2–4'teki tüm domain tipleri; `nowProvider` (`lib/features/workout/application/session_providers.dart`); `isLoggedInProvider` (`lib/features/onboarding/application/auth_providers.dart`); `profileProvider` (`lib/features/onboarding/application/profile_providers.dart`); `AppSupabase.client` (`lib/core/supabase_client.dart`).
- Produces:
  - `ProgressDataRepository { Future<List<WorkoutSession>> fetchFinishedSessions({DateTime? since}); Future<List<Meal>> fetchMeals({required DateTime from, required DateTime to}); }`
  - `BodyWeightRepository { Future<List<BodyWeightLog>> fetchLogs(); Future<void> logWeight({required DateTime date, required ProfileWeightUpdate update}); Future<void> deleteLog({required DateTime date, ProfileWeightUpdate? newLatest}); }`, `LastWeightLogException`, `StaleWeightListException`.
  - `BodyMeasurementRepository { Future<List<BodyMeasurement>> fetchMeasurements(); Future<void> saveMeasurement(BodyMeasurement); Future<void> deleteMeasurement(DateTime date); }`
  - Provider'lar: `progressDataRepositoryProvider`, `bodyWeightRepositoryProvider`, `bodyMeasurementRepositoryProvider`, `weightLogsProvider` (`List<BodyWeightLog>`, eskiden yeniye), `measurementsProvider` (`List<BodyMeasurement>`, eskiden yeniye), `recentSessionsProvider` (son 90 gün), `allSessionsProvider`, `weeklyMealsProvider`, `weeklySummaryProvider` (`WeeklySummary`), `strengthCardProvider` (`List<StrengthSeries>`, en fazla 3), `allStrengthSeriesProvider` (`List<StrengthSeries>`). Hepsi `FutureProvider.autoDispose`.
  - `bodyWeightServiceProvider` → `BodyWeightService { Future<double?> log({required DateTime date, required double weightKg}); Future<void> delete(DateTime date); }`; `Future<void> recordInitialWeight(BodyWeightRepository, Profile, DateTime now)`.
  - `test/features/progress/fakes.dart`: `FakeBodyWeightRepository`, `FakeBodyMeasurementRepository`, `FakeProgressDataRepository`.

- [ ] **Step 1: Repository'leri yaz (Supabase; unit test edilmez)**

`lib/features/progress/data/progress_data_repository.dart`:

```dart
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../nutrition/domain/meal.dart';
import '../../workout/domain/workout_session.dart';

/// Grafik ve özetler için mevcut antrenman ve öğün tablolarından okuma.
abstract interface class ProgressDataRepository {
  /// Bitmiş oturumlar (setleriyle), eskiden yeniye; [since] verilirse
  /// yalnızca `finished_at >= since`.
  Future<List<WorkoutSession>> fetchFinishedSessions({DateTime? since});

  /// `[from, to)` aralığında kaydedilmiş öğünler (kalemleriyle).
  Future<List<Meal>> fetchMeals({required DateTime from, required DateTime to});
}

class SupabaseProgressDataRepository implements ProgressDataRepository {
  SupabaseProgressDataRepository(this._client);

  final SupabaseClient _client;

  // Yalnızca grafik ve özetin kullandığı sütunlar. session_sets'in exercises'a
  // iki FK'si var (exercise_id, percent_ref_exercise_id).
  static const _sessionColumns = 'id, program_id, program_name, workout_name, workout_position, '
      'started_at, finished_at, session_sets(exercise_position, set_index, exercise_id, '
      'target_reps_min, target_reps_max, weight_kg, reps, completed_at, exercises!exercise_id(name))';

  @override
  Future<List<WorkoutSession>> fetchFinishedSessions({DateTime? since}) async {
    var query = _client.from('workout_sessions').select(_sessionColumns).not('finished_at', 'is', null);
    if (since != null) query = query.gte('finished_at', since.toUtc().toIso8601String());
    final rows = await query.order('finished_at');
    return [for (final row in rows) WorkoutSession.fromJson(row)];
  }

  @override
  Future<List<Meal>> fetchMeals({required DateTime from, required DateTime to}) async {
    final rows = await _client
        .from('meals')
        .select('*, meal_items(*)')
        .gte('logged_at', from.toUtc().toIso8601String())
        .lt('logged_at', to.toUtc().toIso8601String())
        .order('logged_at');
    return [for (final row in rows) Meal.fromJson(row)];
  }
}
```

`lib/features/progress/data/body_weight_repository.dart`:

```dart
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/body_weight_log.dart';
import '../domain/profile_weight_update.dart';
import '../domain/progress_format.dart';

/// Kullanıcının tek kilo kaydı silinemez (profildeki kilonun kaynağı).
class LastWeightLogException implements Exception {}

/// Silme sırasında uygulamanın kilo listesi sunucudakiyle uyuşmadı.
class StaleWeightListException implements Exception {}

abstract interface class BodyWeightRepository {
  /// Eskiden yeniye.
  Future<List<BodyWeightLog>> fetchLogs();

  /// `log_body_weight` RPC: [date] gününe yazar (varsa üzerine); kayıt en
  /// yeniyse profil [update] ile güncellenir.
  Future<void> logWeight({required DateTime date, required ProfileWeightUpdate update});

  /// `delete_body_weight` RPC. [newLatest]: silinen kayıt en yeniyse kalan en
  /// yeni kaydın kilosu ve hedefleri, değilse null. Tek kayıtsa
  /// [LastWeightLogException], liste eskiyse [StaleWeightListException].
  Future<void> deleteLog({required DateTime date, ProfileWeightUpdate? newLatest});
}

class SupabaseBodyWeightRepository implements BodyWeightRepository {
  SupabaseBodyWeightRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<BodyWeightLog>> fetchLogs() async {
    // PostgREST en fazla 1000 satır döner: yeniden eskiye çekilir ki sınır
    // aşılırsa en eskiler düşsün.
    final rows = await _client
        .from('body_weight_logs')
        .select('logged_on, weight_kg')
        .order('logged_on', ascending: false);
    return [for (final row in rows.reversed) BodyWeightLog.fromJson(row)];
  }

  @override
  Future<void> logWeight({required DateTime date, required ProfileWeightUpdate update}) async {
    await _client.rpc('log_body_weight', params: {
      'p_date': formatDbDate(date),
      'p_kg': update.weightKg,
      'p_calorie_target': update.calorieTarget,
      'p_protein_target': update.proteinTargetG,
    });
  }

  @override
  Future<void> deleteLog({required DateTime date, ProfileWeightUpdate? newLatest}) async {
    try {
      await _client.rpc('delete_body_weight', params: {
        'p_date': formatDbDate(date),
        'p_new_latest_kg': newLatest?.weightKg,
        'p_calorie_target': newLatest?.calorieTarget,
        'p_protein_target': newLatest?.proteinTargetG,
      });
    } on PostgrestException catch (error) {
      if (error.message.contains('last_weight_log')) throw LastWeightLogException();
      if (error.message.contains('stale_weight_list')) throw StaleWeightListException();
      rethrow;
    }
  }
}
```

`lib/features/progress/data/body_measurement_repository.dart`:

```dart
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/body_measurement.dart';
import '../domain/progress_format.dart';

abstract interface class BodyMeasurementRepository {
  /// Eskiden yeniye.
  Future<List<BodyMeasurement>> fetchMeasurements();

  /// Aynı tarihte ölçüm varsa üzerine yazar.
  Future<void> saveMeasurement(BodyMeasurement measurement);

  Future<void> deleteMeasurement(DateTime date);
}

class SupabaseBodyMeasurementRepository implements BodyMeasurementRepository {
  SupabaseBodyMeasurementRepository(this._client);

  final SupabaseClient _client;

  static const _table = 'body_measurements';

  @override
  Future<List<BodyMeasurement>> fetchMeasurements() async {
    final rows = await _client.from(_table).select().order('measured_on');
    return [for (final row in rows) BodyMeasurement.fromJson(row)];
  }

  @override
  Future<void> saveMeasurement(BodyMeasurement measurement) async {
    await _client.from(_table).upsert(
      {...measurement.toUpsertJson(), 'user_id': _client.auth.currentUser!.id},
      onConflict: 'user_id,measured_on',
    );
  }

  @override
  Future<void> deleteMeasurement(DateTime date) async {
    await _client.from(_table).delete().eq('measured_on', formatDbDate(date));
  }
}
```

- [ ] **Step 2: Fake'leri yaz**

`test/features/progress/fakes.dart`:

```dart
import 'package:spor_takip/features/nutrition/domain/meal.dart';
import 'package:spor_takip/features/progress/data/body_measurement_repository.dart';
import 'package:spor_takip/features/progress/data/body_weight_repository.dart';
import 'package:spor_takip/features/progress/data/progress_data_repository.dart';
import 'package:spor_takip/features/progress/domain/body_measurement.dart';
import 'package:spor_takip/features/progress/domain/body_weight_log.dart';
import 'package:spor_takip/features/progress/domain/profile_weight_update.dart';
import 'package:spor_takip/features/workout/domain/workout_session.dart';

class FakeBodyWeightRepository implements BodyWeightRepository {
  FakeBodyWeightRepository([List<BodyWeightLog>? logs]) : logs = [...?logs];

  final List<BodyWeightLog> logs;
  final List<({DateTime date, ProfileWeightUpdate update})> logged = [];
  final List<({DateTime date, ProfileWeightUpdate? newLatest})> deleted = [];

  /// Doluysa yazma/silme bu hatayı fırlatır.
  Object? error;

  @override
  Future<List<BodyWeightLog>> fetchLogs() async => [...logs]..sort((a, b) => a.date.compareTo(b.date));

  @override
  Future<void> logWeight({required DateTime date, required ProfileWeightUpdate update}) async {
    if (error != null) throw error!;
    logged.add((date: date, update: update));
    logs
      ..removeWhere((l) => l.date == date)
      ..add(BodyWeightLog(date: date, weightKg: update.weightKg));
  }

  @override
  Future<void> deleteLog({required DateTime date, ProfileWeightUpdate? newLatest}) async {
    if (error != null) throw error!;
    deleted.add((date: date, newLatest: newLatest));
    logs.removeWhere((l) => l.date == date);
  }
}

class FakeBodyMeasurementRepository implements BodyMeasurementRepository {
  FakeBodyMeasurementRepository([List<BodyMeasurement>? items]) : items = [...?items];

  final List<BodyMeasurement> items;
  Object? error;

  @override
  Future<List<BodyMeasurement>> fetchMeasurements() async =>
      [...items]..sort((a, b) => a.date.compareTo(b.date));

  @override
  Future<void> saveMeasurement(BodyMeasurement measurement) async {
    if (error != null) throw error!;
    items
      ..removeWhere((m) => m.date == measurement.date)
      ..add(measurement);
  }

  @override
  Future<void> deleteMeasurement(DateTime date) async {
    if (error != null) throw error!;
    items.removeWhere((m) => m.date == date);
  }
}

class FakeProgressDataRepository implements ProgressDataRepository {
  FakeProgressDataRepository({List<WorkoutSession>? sessions, List<Meal>? meals})
      : sessions = [...?sessions],
        meals = [...?meals];

  final List<WorkoutSession> sessions;
  final List<Meal> meals;
  int sessionFetches = 0;

  @override
  Future<List<WorkoutSession>> fetchFinishedSessions({DateTime? since}) async {
    sessionFetches++;
    return [
      for (final s in sessions)
        if (s.finishedAt case final finishedAt? when since == null || !finishedAt.isBefore(since)) s,
    ]..sort((a, b) => a.finishedAt!.compareTo(b.finishedAt!));
  }

  @override
  Future<List<Meal>> fetchMeals({required DateTime from, required DateTime to}) async => [
        for (final m in meals)
          if (!m.loggedAt.isBefore(from) && m.loggedAt.isBefore(to)) m,
      ];
}
```

- [ ] **Step 3: Servis testlerini yaz**

`test/features/progress/application/body_weight_service_test.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spor_takip/features/onboarding/application/auth_providers.dart';
import 'package:spor_takip/features/onboarding/application/profile_providers.dart';
import 'package:spor_takip/features/progress/application/body_weight_service.dart';
import 'package:spor_takip/features/progress/application/progress_providers.dart';
import 'package:spor_takip/features/progress/data/body_weight_repository.dart';
import 'package:spor_takip/features/progress/domain/body_weight_log.dart';
import 'package:spor_takip/features/progress/domain/profile_weight_update.dart';
import 'package:spor_takip/features/workout/application/session_providers.dart';

import '../fakes.dart';
import '../fixtures.dart';

final _now = DateTime(2026, 9, 28, 12);

void main() {
  late FakeBodyWeightRepository repo;
  late ProviderContainer container;

  setUp(() {
    repo = FakeBodyWeightRepository([
      BodyWeightLog(date: DateTime(2026, 9, 10), weightKg: 81),
      BodyWeightLog(date: DateTime(2026, 9, 20), weightKg: 80),
    ]);
    container = ProviderContainer(overrides: [
      isLoggedInProvider.overrideWithValue(true),
      profileProvider.overrideWith((ref) async => testProfile),
      bodyWeightRepositoryProvider.overrideWithValue(repo),
      nowProvider.overrideWithValue(() => _now),
    ]);
    addTearDown(container.dispose);
  });

  BodyWeightService service() => container.read(bodyWeightServiceProvider);

  ProfileWeightUpdate expectedFor(double kg) => profileWeightUpdate(testProfile, kg, currentYear: 2026);

  test('logging the newest entry sends new targets and returns the calorie target', () async {
    final target = await service().log(date: DateTime(2026, 9, 28, 9, 30), weightKg: 79.5);

    final call = repo.logged.single;
    expect(call.date, DateTime(2026, 9, 28)); // saat atılır
    expect(call.update.weightKg, 79.5);
    expect(call.update.calorieTarget, expectedFor(79.5).calorieTarget);
    expect(call.update.proteinTargetG, expectedFor(79.5).proteinTargetG);
    expect(target, expectedFor(79.5).calorieTarget);
  });

  test('overwriting the newest day still counts as newest', () async {
    final target = await service().log(date: DateTime(2026, 9, 20), weightKg: 79);
    expect(target, isNotNull);
  });

  test('a past-dated entry does not change targets (returns null)', () async {
    final target = await service().log(date: DateTime(2026, 9, 15), weightKg: 80.5);
    expect(repo.logged.single.date, DateTime(2026, 9, 15));
    expect(target, isNull);
  });

  test('the first ever entry counts as newest', () async {
    repo.logs.clear();
    expect(await service().log(date: DateTime(2026, 9, 1), weightKg: 82), isNotNull);
  });

  test('deleting the newest entry recalculates targets from the previous one', () async {
    await service().delete(DateTime(2026, 9, 20));

    final call = repo.deleted.single;
    expect(call.date, DateTime(2026, 9, 20));
    expect(call.newLatest!.weightKg, 81);
    expect(call.newLatest!.calorieTarget, expectedFor(81).calorieTarget);
  });

  test('deleting an older entry does not touch the profile', () async {
    await service().delete(DateTime(2026, 9, 10));
    expect(repo.deleted.single.newLatest, isNull);
  });

  test('the only entry cannot be deleted', () async {
    repo.logs.removeAt(0);
    await expectLater(service().delete(DateTime(2026, 9, 20)), throwsA(isA<LastWeightLogException>()));
    expect(repo.deleted, isEmpty);
  });

  test('a stale list error is passed through', () async {
    repo.error = StaleWeightListException();
    await expectLater(service().delete(DateTime(2026, 9, 20)), throwsA(isA<StaleWeightListException>()));
  });

  test('recordInitialWeight logs the onboarding weight with the saved targets', () async {
    await recordInitialWeight(repo, testProfile, DateTime(2026, 9, 28, 18));
    final call = repo.logged.single;
    expect(call.date, DateTime(2026, 9, 28));
    expect(call.update.weightKg, testProfile.weightKg);
    expect(call.update.calorieTarget, testProfile.dailyCalorieTarget);
    expect(call.update.proteinTargetG, testProfile.dailyProteinTargetG);
  });
}
```

- [ ] **Step 4: Provider testlerini yaz**

`test/features/progress/application/progress_providers_test.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spor_takip/features/onboarding/application/auth_providers.dart';
import 'package:spor_takip/features/progress/application/progress_providers.dart';
import 'package:spor_takip/features/progress/domain/body_weight_log.dart';
import 'package:spor_takip/features/workout/application/session_providers.dart';

import '../fakes.dart';
import '../fixtures.dart';

final _now = DateTime(2026, 9, 30, 12); // Çarşamba

void main() {
  late FakeProgressDataRepository data;
  late FakeBodyWeightRepository weights;

  ProviderContainer containerWith({bool loggedIn = true}) {
    final container = ProviderContainer(overrides: [
      isLoggedInProvider.overrideWithValue(loggedIn),
      progressDataRepositoryProvider.overrideWithValue(data),
      bodyWeightRepositoryProvider.overrideWithValue(weights),
      bodyMeasurementRepositoryProvider.overrideWithValue(FakeBodyMeasurementRepository()),
      nowProvider.overrideWithValue(() => _now),
    ]);
    addTearDown(container.dispose);
    return container;
  }

  setUp(() {
    data = FakeProgressDataRepository(
      sessions: [
        finishedSession('old', DateTime(2026, 6, 1), [doneSet('deadlift')]),
        finishedSession('a', DateTime(2026, 9, 22), [doneSet('squat'), doneSet('bench')]),
        finishedSession('b', DateTime(2026, 9, 29), [doneSet('squat')]),
      ],
      meals: [
        testMeal(DateTime(2026, 9, 29, 13), calories: 2000),
        testMeal(DateTime(2026, 9, 14, 13)), // iki hafta önce: çekilmez
      ],
    );
    weights = FakeBodyWeightRepository([BodyWeightLog(date: DateTime(2026, 9, 29), weightKg: 80)]);
  });

  test('recent sessions cover the last 90 days only', () async {
    final sessions = await containerWith().read(recentSessionsProvider.future);
    expect(sessions.map((s) => s.id), ['a', 'b']);
  });

  test('all sessions include older ones', () async {
    final sessions = await containerWith().read(allSessionsProvider.future);
    expect(sessions.map((s) => s.id), ['old', 'a', 'b']);
  });

  test('weekly meals cover last week and this week', () async {
    final meals = await containerWith().read(weeklyMealsProvider.future);
    expect(meals, hasLength(1));
  });

  test('weekly summary combines sessions, meals and weights', () async {
    final summary = await containerWith().read(weeklySummaryProvider.future);
    expect(summary.thisWeek.workouts, 1);
    expect(summary.lastWeek.workouts, 1);
    expect(summary.thisWeek.avgCalories, 2000);
    expect(summary.thisWeek.lastWeightKg, 80);
  });

  test('strength card lists the most frequent recent exercises', () async {
    final series = await containerWith().read(strengthCardProvider.future);
    expect(series.map((s) => s.exerciseId), ['squat', 'bench']);
  });

  test('logged out → empty lists without hitting the repositories', () async {
    final container = containerWith(loggedIn: false);
    expect(await container.read(recentSessionsProvider.future), isEmpty);
    expect(await container.read(weightLogsProvider.future), isEmpty);
    expect(data.sessionFetches, 0);
  });
}
```

- [ ] **Step 5: Router testini yaz**

`test/core/router_test.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spor_takip/core/router.dart';
import 'package:spor_takip/features/onboarding/application/auth_providers.dart';
import 'package:spor_takip/features/onboarding/application/profile_providers.dart';
import 'package:spor_takip/features/onboarding/domain/profile.dart';

import '../features/progress/fixtures.dart';

Profile _withWeight(double kg) => Profile(
      userId: testProfile.userId,
      weightKg: kg,
      heightCm: testProfile.heightCm,
      birthYear: testProfile.birthYear,
      gender: testProfile.gender,
      activityLevel: testProfile.activityLevel,
      doesExercise: testProfile.doesExercise,
      exerciseDaysPerWeek: testProfile.exerciseDaysPerWeek,
      goal: testProfile.goal,
      dailyCalorieTarget: testProfile.dailyCalorieTarget,
      dailyProteinTargetG: testProfile.dailyProteinTargetG,
    );

void main() {
  // GoRouter, WidgetsBinding'e dokunur.
  TestWidgetsFlutterBinding.ensureInitialized();

  test('refreshing profile data keeps the same router (no navigation reset)', () async {
    var weight = 80.0;
    final container = ProviderContainer(overrides: [
      isLoggedInProvider.overrideWithValue(true),
      profileProvider.overrideWith((ref) async => _withWeight(weight)),
    ]);
    addTearDown(container.dispose);

    await container.read(profileProvider.future);
    final first = container.read(routerProvider);

    weight = 81;
    container.invalidate(profileProvider);
    await container.read(profileProvider.future);

    expect(identical(container.read(routerProvider), first), isTrue);
  });
}
```

- [ ] **Step 6: Testlerin başarısız olduğunu gör**

Run: `flutter test --no-pub test/features/progress/application/ test/core/router_test.dart`
Expected: FAIL — `progress_providers.dart` / `body_weight_service.dart` bulunamıyor; router testi derlense bile `identical` false olurdu.

- [ ] **Step 7: `progress_providers.dart`**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase_client.dart';
import '../../nutrition/domain/meal.dart';
import '../../onboarding/application/auth_providers.dart';
import '../../workout/application/session_providers.dart';
import '../../workout/domain/workout_session.dart';
import '../data/body_measurement_repository.dart';
import '../data/body_weight_repository.dart';
import '../data/progress_data_repository.dart';
import '../domain/body_measurement.dart';
import '../domain/body_weight_log.dart';
import '../domain/strength.dart';
import '../domain/weekly_summary.dart';

final progressDataRepositoryProvider = Provider<ProgressDataRepository>((ref) {
  return SupabaseProgressDataRepository(AppSupabase.client);
});

final bodyWeightRepositoryProvider = Provider<BodyWeightRepository>((ref) {
  return SupabaseBodyWeightRepository(AppSupabase.client);
});

final bodyMeasurementRepositoryProvider = Provider<BodyMeasurementRepository>((ref) {
  return SupabaseBodyMeasurementRepository(AppSupabase.client);
});

/// Eskiden yeniye; kilo kaydı/silme sonrası invalidate edilir.
final weightLogsProvider = FutureProvider.autoDispose<List<BodyWeightLog>>((ref) async {
  if (!ref.watch(isLoggedInProvider)) return const [];
  return ref.watch(bodyWeightRepositoryProvider).fetchLogs();
});

/// Eskiden yeniye; ölçüm kaydı/silme sonrası invalidate edilir.
final measurementsProvider = FutureProvider.autoDispose<List<BodyMeasurement>>((ref) async {
  if (!ref.watch(isLoggedInProvider)) return const [];
  return ref.watch(bodyMeasurementRepositoryProvider).fetchMeasurements();
});

/// Son 90 günün bitmiş oturumları (güç kartı, haftalık özet).
/// Antrenman bitince/silinince invalidate edilir.
final recentSessionsProvider = FutureProvider.autoDispose<List<WorkoutSession>>((ref) async {
  if (!ref.watch(isLoggedInProvider)) return const [];
  final now = ref.watch(nowProvider)();
  return ref
      .watch(progressDataRepositoryProvider)
      .fetchFinishedSessions(since: DateTime(now.year, now.month, now.day - 90));
});

/// Tüm bitmiş oturumlar (güç ekranı).
final allSessionsProvider = FutureProvider.autoDispose<List<WorkoutSession>>((ref) async {
  if (!ref.watch(isLoggedInProvider)) return const [];
  return ref.watch(progressDataRepositoryProvider).fetchFinishedSessions();
});

/// Geçen hafta ve bu haftanın öğünleri; öğün kaydedilince invalidate edilir.
final weeklyMealsProvider = FutureProvider.autoDispose<List<Meal>>((ref) async {
  if (!ref.watch(isLoggedInProvider)) return const [];
  final start = startOfWeek(ref.watch(nowProvider)());
  return ref.watch(progressDataRepositoryProvider).fetchMeals(
        from: DateTime(start.year, start.month, start.day - 7),
        to: DateTime(start.year, start.month, start.day + 7),
      );
});

final weeklySummaryProvider = FutureProvider.autoDispose<WeeklySummary>((ref) async {
  final now = ref.watch(nowProvider)();
  final (sessions, meals, weights) = await (
    ref.watch(recentSessionsProvider.future),
    ref.watch(weeklyMealsProvider.future),
    ref.watch(weightLogsProvider.future),
  ).wait;
  return weeklySummary(now: now, sessions: sessions, meals: meals, weights: weights);
});

/// Ana sayfa güç kartı: son 90 günde en sık yapılan 3 hareket.
final strengthCardProvider = FutureProvider.autoDispose<List<StrengthSeries>>((ref) async {
  final now = ref.watch(nowProvider)();
  final sessions = await ref.watch(recentSessionsProvider.future);
  return topStrengthSeries(strengthSeries(sessions), now);
});

/// Güç ekranı: tüm geçmişteki hareketler, en sık yapılan önce.
final allStrengthSeriesProvider = FutureProvider.autoDispose<List<StrengthSeries>>((ref) async {
  return strengthSeries(await ref.watch(allSessionsProvider.future));
});
```

- [ ] **Step 8: `body_weight_service.dart`**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../onboarding/application/profile_providers.dart';
import '../../onboarding/domain/profile.dart';
import '../../workout/application/session_providers.dart';
import '../data/body_weight_repository.dart';
import '../domain/body_weight_log.dart';
import '../domain/profile_weight_update.dart';
import '../domain/progress_format.dart';
import 'progress_providers.dart';

final bodyWeightServiceProvider = Provider<BodyWeightService>(BodyWeightService.new);

/// Kilo kaydı/silme: profildeki kilo ve hedefleri tutarlı tutar (spec §3).
class BodyWeightService {
  BodyWeightService(this._ref);

  final Ref _ref;

  BodyWeightRepository get _repo => _ref.read(bodyWeightRepositoryProvider);

  /// Profil ve sunucudaki güncel liste (servis kararlarını eski önbelleğe dayandırmaz).
  Future<(Profile, List<BodyWeightLog>)> _context() async {
    final (profile, logs) = await (_ref.read(profileProvider.future), _repo.fetchLogs()).wait;
    if (profile == null) throw StateError('Profil yok');
    return (profile, logs);
  }

  ProfileWeightUpdate _update(Profile profile, double weightKg) =>
      profileWeightUpdate(profile, weightKg, currentYear: _ref.read(nowProvider)().year);

  /// [date] gününe [weightKg] yazar. Kayıt en yeniyse (ya da ilkse) profil
  /// güncellenir ve yeni kalori hedefi döner; geçmiş tarihliyse null.
  Future<double?> log({required DateTime date, required double weightKg}) async {
    final day = dateOnly(date);
    final (profile, logs) = await _context();
    final isLatest = logs.isEmpty || !day.isBefore(logs.last.date);
    final update = _update(profile, weightKg);
    await _repo.logWeight(date: day, update: update);
    _ref.invalidate(weightLogsProvider);
    if (!isLatest) return null;
    _ref.invalidate(profileProvider);
    return update.calorieTarget;
  }

  /// [date] günündeki kaydı siler; en yeniyse profil bir önceki kayda göre
  /// güncellenir. Tek kayıtsa [LastWeightLogException].
  Future<void> delete(DateTime date) async {
    final day = dateOnly(date);
    final (profile, logs) = await _context();
    if (logs.length <= 1) throw LastWeightLogException();
    final isLatest = logs.last.date == day;
    final newLatest = isLatest ? _update(profile, logs[logs.length - 2].weightKg) : null;
    try {
      await _repo.deleteLog(date: day, newLatest: newLatest);
    } finally {
      _ref.invalidate(weightLogsProvider);
    }
    if (isLatest) _ref.invalidate(profileProvider);
  }
}

/// Onboarding sonunda profildeki kiloyu ilk kilo kaydı olarak yazar
/// (hedefler profille aynı olduğu için değişmez).
Future<void> recordInitialWeight(BodyWeightRepository repo, Profile profile, DateTime now) {
  return repo.logWeight(
    date: dateOnly(now),
    update: ProfileWeightUpdate(
      weightKg: profile.weightKg,
      calorieTarget: profile.dailyCalorieTarget,
      proteinTargetG: profile.dailyProteinTargetG,
    ),
  );
}
```

- [ ] **Step 9: Router'ı yalnızca profil durumuna bağla**

`lib/core/router.dart` içinde `routerProvider`'ın başındaki blok:

```dart
  final isLoggedIn = ref.watch(isLoggedInProvider);
  final profileAsync = ref.watch(profileProvider);
  // AsyncValue.when correctly avoids re-triggering `loading` during a
  // background refresh that already has data, via Riverpod's default
  // skipLoadingOnRefresh.
  final profileState = profileAsync.when(
    data: (profile) => profile == null ? ProfileState.absent : ProfileState.present,
    loading: () => ProfileState.loading,
    error: (_, _) => ProfileState.error,
  );
```

şununla değişir:

```dart
  final isLoggedIn = ref.watch(isLoggedInProvider);
  // Yalnızca profilin durumu izlenir: kilo kaydı profili yenilediğinde (F4b)
  // yeni bir GoRouter kurulup gezinme yığını sıfırlanmasın. AsyncValue.when,
  // Riverpod'un varsayılan skipLoadingOnRefresh'i sayesinde veri varken
  // yapılan arka plan yenilemesinde `loading`'e düşmez.
  final profileState = ref.watch(profileProvider.select((profileAsync) => profileAsync.when(
        data: (profile) => profile == null ? ProfileState.absent : ProfileState.present,
        loading: () => ProfileState.loading,
        error: (_, _) => ProfileState.error,
      )));
```

- [ ] **Step 10: Testlerin geçtiğini gör**

Run: `flutter test --no-pub test/features/progress/application/ test/core/`
Expected: PASS (router testi dahil; `redirect_logic_test` ve `app_shell_test` de yeşil kalmalı).

- [ ] **Step 11: Analiz ve commit**

Run: `flutter analyze --no-pub`
Expected: `No issues found!`

```bash
git add lib/features/progress/data lib/features/progress/application lib/core/router.dart test/features/progress/fakes.dart test/features/progress/application test/core/router_test.dart
git commit -m "feat(progress): add progress repositories, providers and body weight service"
```

---

## Task 6: `fl_chart`, ortak grafik, aralık seçici ve kart durumları

**Files:**
- Modify: `pubspec.yaml`, `pubspec.lock` (`flutter pub add` ile)
- Create: `lib/features/progress/presentation/widgets/progress_line_chart.dart`
- Create: `lib/features/progress/presentation/widgets/range_selector.dart`
- Create: `lib/features/progress/presentation/widgets/card_states.dart`
- Test: `test/features/progress/presentation/widgets/chart_widgets_test.dart`

**Interfaces:**
- Consumes: `ValuePoint`, `ChartRange` (Task 3); `formatShortDate`, `formatOneDecimal` (Task 2).
- Produces:
  - `ProgressLineChart({Key? key, required List<ValuePoint> points, double height = 200, bool compact = false, String Function(int index)? tooltipLabel})` — `points` eskiden yeniye; boşsa yalnızca boş `SizedBox(height)`; `compact` = eksen/ızgara/dokunma yok (kartlar); `tooltipLabel(i)` = `points[i]` için ipucu metni.
  - `RangeSelector({Key? key, required ChartRange value, required ValueChanged<ChartRange> onChanged})` — `SegmentedButton`; her segmentin anahtarı `Key('range_${range.name}')`.
  - `card_states.dart`: `CardLoading()`, `CardError({required VoidCallback onRetry})` (düğme anahtarı `Key('card_retry')`), `ProgressCardHeader({required String title, Widget? trailing})`.

- [ ] **Step 1: Paketi ekle**

Run: `flutter pub add fl_chart:^1.2.0`
Expected: `+ fl_chart 1.2.0` ve `+ equatable ...` satırları; `pubspec.yaml` `dependencies:` altında `fl_chart: ^1.2.0`. (Ağda takılırsa 5 dk bekleyip bir kez daha dene; yine olmazsa dur ve kullanıcıya bildir.)

- [ ] **Step 2: Widget testlerini yaz**

`test/features/progress/presentation/widgets/chart_widgets_test.dart`:

```dart
import 'package:easy_localization/easy_localization.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spor_takip/features/progress/domain/trend.dart';
import 'package:spor_takip/features/progress/presentation/widgets/card_states.dart';
import 'package:spor_takip/features/progress/presentation/widgets/progress_line_chart.dart';
import 'package:spor_takip/features/progress/presentation/widgets/range_selector.dart';

Widget _wrap(Widget child) => EasyLocalization(
      supportedLocales: const [Locale('tr'), Locale('en')],
      path: 'assets/translations',
      fallbackLocale: const Locale('tr'),
      child: MaterialApp(home: Scaffold(body: child)),
    );

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  testWidgets('draws a line chart for points, nothing for an empty list', (tester) async {
    await tester.pumpWidget(_wrap(Column(children: [
      ProgressLineChart(
        key: const Key('full'),
        points: [ValuePoint(DateTime(2026, 9, 1), 80), ValuePoint(DateTime(2026, 9, 20), 79)],
      ),
      ProgressLineChart(key: const Key('single'), compact: true, height: 60, points: [ValuePoint(DateTime(2026, 9, 1), 80)]),
      const ProgressLineChart(key: Key('empty'), points: []),
    ])));
    await tester.pumpAndSettle();

    expect(find.descendant(of: find.byKey(const Key('full')), matching: find.byType(LineChart)), findsOneWidget);
    expect(find.descendant(of: find.byKey(const Key('single')), matching: find.byType(LineChart)), findsOneWidget);
    expect(find.descendant(of: find.byKey(const Key('empty')), matching: find.byType(LineChart)), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('range selector reports the tapped range', (tester) async {
    ChartRange? picked;
    await tester.pumpWidget(_wrap(RangeSelector(value: ChartRange.threeMonths, onChanged: (r) => picked = r)));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('range_year')));
    await tester.pumpAndSettle();
    expect(picked, ChartRange.year);
  });

  testWidgets('card error calls retry', (tester) async {
    var retried = false;
    await tester.pumpWidget(_wrap(CardError(onRetry: () => retried = true)));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('card_retry')));
    expect(retried, isTrue);
  });
}
```

- [ ] **Step 3: Testin başarısız olduğunu gör**

Run: `flutter test --no-pub test/features/progress/presentation/widgets/chart_widgets_test.dart`
Expected: FAIL — widget dosyaları bulunamıyor.

- [ ] **Step 4: `progress_line_chart.dart`**

```dart
import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../domain/progress_format.dart';
import '../../domain/trend.dart';

/// Tarih eksenli tek çizgi grafik (kilo, tahmini 1RM, ölçü).
class ProgressLineChart extends StatelessWidget {
  const ProgressLineChart({
    super.key,
    required this.points,
    this.height = 200,
    this.compact = false,
    this.tooltipLabel,
  });

  /// Eskiden yeniye.
  final List<ValuePoint> points;
  final double height;

  /// Kartlardaki küçük grafik: eksen, ızgara ve dokunma yok.
  final bool compact;

  /// `points[index]` için ipucu metni; verilmezse "tarih\ndeğer".
  final String Function(int index)? tooltipLabel;

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) return SizedBox(height: height);
    final theme = Theme.of(context);
    final color = theme.colorScheme.primary;
    final labelStyle = theme.textTheme.labelSmall;

    // x = ilk noktadan beri geçen gün (saatli noktalar için kesirli).
    final origin = points.first.date;
    double dayOf(DateTime d) => d.difference(origin).inMinutes / (60 * 24);
    final spots = [for (final p in points) FlSpot(dayOf(p.date), p.value)];

    final values = points.map((p) => p.value);
    final minValue = values.reduce(math.min);
    final maxValue = values.reduce(math.max);
    final pad = math.max((maxValue - minValue) * 0.1, 1.0);
    final minX = spots.first.x;
    final maxX = spots.last.x == minX ? minX + 1 : spots.last.x;

    String label(int index) =>
        tooltipLabel?.call(index) ??
        '${formatShortDate(points[index].date)}\n${formatOneDecimal(points[index].value)}';

    return SizedBox(
      height: height,
      child: LineChart(
        LineChartData(
          minX: minX,
          maxX: maxX,
          minY: minValue - pad,
          maxY: maxValue + pad,
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              color: color,
              barWidth: compact ? 2 : 3,
              dotData: FlDotData(show: !compact && points.length <= 60),
            ),
          ],
          gridData: FlGridData(show: !compact, drawVerticalLine: false),
          borderData: FlBorderData(show: false),
          titlesData: compact
              ? const FlTitlesData(show: false)
              : FlTitlesData(
                  topTitles: const AxisTitles(),
                  rightTitles: const AxisTitles(),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget: (value, meta) => Text(meta.formattedValue, style: labelStyle),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 24,
                      interval: math.max(1, (maxX - minX) / 4),
                      getTitlesWidget: (value, meta) {
                        final date = origin.add(Duration(minutes: (value * 60 * 24).round()));
                        return Text('${date.day}.${date.month}', style: labelStyle);
                      },
                    ),
                  ),
                ),
          lineTouchData: compact
              ? const LineTouchData(enabled: false)
              : LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipItems: (touched) => [
                      for (final spot in touched)
                        LineTooltipItem(
                          label(spot.spotIndex),
                          TextStyle(color: theme.colorScheme.onInverseSurface),
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

Not: `fl_chart` 1.x API adları farklı çıkarsa (ör. `getTooltipColor`, `SideTitleWidget(meta: ...)`) pakette `~/flutter-pub-cache` altındaki `fl_chart-1.2.0/lib/src/chart/line_chart/line_chart_data.dart` dosyasına bakıp aynı davranışı kuran en yakın API'yi kullan; davranış (eksenler, ipucu metni, compact) değişmemeli.

- [ ] **Step 5: `range_selector.dart`**

```dart
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../domain/trend.dart';

class RangeSelector extends StatelessWidget {
  const RangeSelector({super.key, required this.value, required this.onChanged});

  final ChartRange value;
  final ValueChanged<ChartRange> onChanged;

  static String _labelKey(ChartRange range) => switch (range) {
        ChartRange.month => 'progress.range.month',
        ChartRange.threeMonths => 'progress.range.three_months',
        ChartRange.year => 'progress.range.year',
        ChartRange.all => 'progress.range.all',
      };

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<ChartRange>(
      showSelectedIcon: false,
      segments: [
        for (final range in ChartRange.values)
          ButtonSegment(value: range, label: Text(_labelKey(range).tr(), key: Key('range_${range.name}'))),
      ],
      selected: {value},
      onSelectionChanged: (selection) => onChanged(selection.single),
    );
  }
}
```

- [ ] **Step 6: `card_states.dart`**

```dart
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

class CardLoading extends StatelessWidget {
  const CardLoading({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(16),
      child: Center(child: CircularProgressIndicator()),
    );
  }
}

/// Kartın kendi hatası; ana sayfanın geri kalanını bozmaz (spec §7).
class CardError extends StatelessWidget {
  const CardError({super.key, required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.error_outline),
      title: Text('progress.load_error'.tr()),
      trailing: TextButton(
        key: const Key('card_retry'),
        onPressed: onRetry,
        child: Text('progress.retry'.tr()),
      ),
    );
  }
}

class ProgressCardHeader extends StatelessWidget {
  const ProgressCardHeader({super.key, required this.title, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(title, style: Theme.of(context).textTheme.titleMedium)),
        ?trailing,
      ],
    );
  }
}
```

- [ ] **Step 7: Testin geçtiğini gör**

Run: `flutter test --no-pub test/features/progress/presentation/widgets/chart_widgets_test.dart`
Expected: PASS.

- [ ] **Step 8: Analiz ve commit**

Run: `flutter analyze --no-pub`
Expected: `No issues found!`

```bash
git add pubspec.yaml pubspec.lock lib/features/progress/presentation/widgets test/features/progress/presentation/widgets/chart_widgets_test.dart
git commit -m "feat(progress): add fl_chart line chart, range selector and card states"
```

---

## Task 7: Ana sayfa listesi, hedefler kartı ve haftalık özet kartı

**Files:**
- Create: `lib/features/progress/presentation/widgets/targets_card.dart`
- Create: `lib/features/progress/presentation/widgets/weekly_summary_card.dart`
- Modify: `lib/features/onboarding/presentation/home_screen.dart` (ortalanmış `Column` → `ListView`)
- Create: `test/features/progress/presentation/test_app.dart`
- Test: `test/features/progress/presentation/home_cards_test.dart`

**Interfaces:**
- Consumes: `weeklySummaryProvider`, `recentSessionsProvider`, `weeklyMealsProvider`, `weightLogsProvider` (Task 5); `WeeklySummary`, `WeekStats` (Task 4); `formatDelta`, `formatOneDecimal` (Task 2); `CardLoading`, `CardError`, `ProgressCardHeader` (Task 6); `profileProvider`; `TodayWorkoutCard` (F4a).
- Produces:
  - `TargetsCard({required Profile profile})` — anahtarlar `home_targets_card`, `home_calorie_target`, `home_protein_target`.
  - `WeeklySummaryCard()` — anahtarlar `weekly_summary_card`, `weekly_empty`, her metrik için `weekly_<metrik>_this|last|change` (`<metrik>`: `workouts`, `sets`, `volume`, `calories`, `protein`, `nutrition_days`, `weight`).
  - `HomeScreen` gövdesi `ListView(key: Key('home_list'))`; Task 8–10 kartlarını bu listenin sonuna ekler.
  - Test yardımcısı `testApp(Widget home, {List overrides, Map<String, String> stubRoutes, bool scaffold})` ve `initTestLocalization()`.

- [ ] **Step 1: Test yardımcısını yaz**

`test/features/progress/presentation/test_app.dart`:

```dart
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spor_takip/features/onboarding/application/auth_providers.dart';

Future<void> initTestLocalization() async {
  SharedPreferences.setMockInitialValues({});
  await EasyLocalization.ensureInitialized();
}

/// [home] '/' rotasında. [scaffold] true ise (kartlar) kaydırılabilir bir
/// Scaffold içine konur; ekranlar kendi Scaffold'unu getirdiği için false.
/// [stubRoutes]: yol → o rotada gösterilecek düz metin (gezinme doğrulaması).
Widget testApp(
  Widget home, {
  List overrides = const [],
  Map<String, String> stubRoutes = const {},
  bool scaffold = true,
}) {
  final router = GoRouter(routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => scaffold ? Scaffold(body: SingleChildScrollView(child: home)) : home,
    ),
    for (final MapEntry(key: path, value: text) in stubRoutes.entries)
      GoRoute(path: path, builder: (context, state) => Scaffold(body: Text(text))),
  ]);
  return EasyLocalization(
    supportedLocales: const [Locale('tr'), Locale('en')],
    path: 'assets/translations',
    fallbackLocale: const Locale('tr'),
    child: ProviderScope(
      overrides: [isLoggedInProvider.overrideWithValue(true), ...overrides.cast()],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
}
```

- [ ] **Step 2: Kart testlerini yaz**

`test/features/progress/presentation/home_cards_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spor_takip/features/onboarding/application/profile_providers.dart';
import 'package:spor_takip/features/progress/application/progress_providers.dart';
import 'package:spor_takip/features/progress/domain/weekly_summary.dart';
import 'package:spor_takip/features/progress/presentation/widgets/targets_card.dart';
import 'package:spor_takip/features/progress/presentation/widgets/weekly_summary_card.dart';

import '../fixtures.dart';
import 'test_app.dart';

String _text(WidgetTester tester, String key) => tester.widget<Text>(find.byKey(Key(key))).data!;

final _summary = WeeklySummary(
  weekStart: DateTime(2026, 9, 28),
  thisWeek: const WeekStats(
    workouts: 3,
    sets: 45,
    volumeKg: 12000.4,
    nutritionDays: 4,
    avgCalories: 2700,
    avgProteinG: 150,
    lastWeightKg: 80,
  ),
  lastWeek: const WeekStats(workouts: 2, sets: 30, volumeKg: 9000, nutritionDays: 0, lastWeightKg: 80.5),
);

void main() {
  setUpAll(initTestLocalization);

  testWidgets('targets card shows the calorie and protein targets', (tester) async {
    await tester.pumpWidget(testApp(const TargetsCard(profile: testProfile)));
    await tester.pumpAndSettle();

    expect(_text(tester, 'home_calorie_target'), contains('2700'));
    expect(_text(tester, 'home_protein_target'), contains('176'));
  });

  testWidgets('weekly summary shows this week, last week and the change', (tester) async {
    await tester.pumpWidget(testApp(const WeeklySummaryCard(), overrides: [
      weeklySummaryProvider.overrideWith((ref) async => _summary),
      profileProvider.overrideWith((ref) async => testProfile),
    ]));
    await tester.pumpAndSettle();

    expect(_text(tester, 'weekly_workouts_this'), '3');
    expect(_text(tester, 'weekly_workouts_last'), '2');
    expect(_text(tester, 'weekly_workouts_change'), '▲ 1');
    expect(_text(tester, 'weekly_volume_this'), '12000');
    expect(_text(tester, 'weekly_calories_this'), '2700 · %100');
    expect(_text(tester, 'weekly_calories_last'), '—');
    expect(_text(tester, 'weekly_calories_change'), '—');
    expect(_text(tester, 'weekly_nutrition_days_this'), '4');
    expect(_text(tester, 'weekly_weight_this'), '80');
    expect(_text(tester, 'weekly_weight_change'), '▼ 0.5');
  });

  testWidgets('weekly summary empty state', (tester) async {
    await tester.pumpWidget(testApp(const WeeklySummaryCard(), overrides: [
      weeklySummaryProvider.overrideWith((ref) async => weeklySummary(
            now: DateTime(2026, 9, 30),
            sessions: const [],
            meals: const [],
            weights: const [],
          )),
      profileProvider.overrideWith((ref) async => testProfile),
    ]));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('weekly_empty')), findsOneWidget);
    expect(find.byKey(const Key('weekly_workouts_this')), findsNothing);
  });

  testWidgets('weekly summary error shows retry', (tester) async {
    await tester.pumpWidget(testApp(const WeeklySummaryCard(), overrides: [
      weeklySummaryProvider.overrideWith((ref) async => throw Exception('offline')),
      profileProvider.overrideWith((ref) async => testProfile),
    ]));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('card_retry')), findsOneWidget);
  });
}
```

- [ ] **Step 3: Testin başarısız olduğunu gör**

Run: `flutter test --no-pub test/features/progress/presentation/home_cards_test.dart`
Expected: FAIL — `targets_card.dart` / `weekly_summary_card.dart` bulunamıyor.

- [ ] **Step 4: `targets_card.dart`**

```dart
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../onboarding/domain/profile.dart';

/// Ana sayfanın en üstündeki günlük kalori ve protein hedefi (önceden sayfanın tamamıydı).
class TargetsCard extends StatelessWidget {
  const TargetsCard({super.key, required this.profile});

  final Profile profile;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Card(
      key: const Key('home_targets_card'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('progress.targets.title'.tr(), style: textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              'home.calorie_target'.tr(namedArgs: {'value': profile.dailyCalorieTarget.round().toString()}),
              key: const Key('home_calorie_target'),
              style: textTheme.headlineSmall,
            ),
            Text(
              'home.protein_target'.tr(namedArgs: {'value': profile.dailyProteinTargetG.round().toString()}),
              key: const Key('home_protein_target'),
              style: textTheme.titleMedium,
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 5: `weekly_summary_card.dart`**

```dart
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../onboarding/application/profile_providers.dart';
import '../../../onboarding/domain/profile.dart';
import '../../application/progress_providers.dart';
import '../../domain/progress_format.dart';
import '../../domain/weekly_summary.dart';
import 'card_states.dart';

typedef _Row = (String key, String label, String current, String previous, String change);

/// Spec §4.4: bu hafta, geçen hafta ve fark; ayrıntı ekranı yok.
class WeeklySummaryCard extends ConsumerWidget {
  const WeeklySummaryCard({super.key});

  static String _average(double? value) => value == null ? '—' : '${value.round()}';

  /// "2700 · %100"; hedef yoksa yalnızca ortalama.
  static String _withPercent(double? average, double? target) {
    if (average == null || target == null || target <= 0) return _average(average);
    return '${_average(average)} · %${(average / target * 100).round()}';
  }

  static double? _diff(num? current, num? previous) =>
      current == null || previous == null ? null : (current - previous).toDouble();

  static List<_Row> _rows(WeeklySummary summary, Profile? profile) {
    final t = summary.thisWeek;
    final l = summary.lastWeek;
    final calorieTarget = profile?.dailyCalorieTarget;
    final proteinTarget = profile?.dailyProteinTargetG;
    String weight(double? kg) => kg == null ? '—' : formatOneDecimal(kg);
    return [
      ('workouts', 'progress.weekly.workouts', '${t.workouts}', '${l.workouts}', formatDelta(_diff(t.workouts, l.workouts))),
      ('sets', 'progress.weekly.sets', '${t.sets}', '${l.sets}', formatDelta(_diff(t.sets, l.sets))),
      (
        'volume',
        'progress.weekly.volume',
        '${t.volumeKg.round()}',
        '${l.volumeKg.round()}',
        formatDelta(_diff(t.volumeKg.round(), l.volumeKg.round())),
      ),
      (
        'calories',
        'progress.weekly.calories',
        _withPercent(t.avgCalories, calorieTarget),
        _withPercent(l.avgCalories, calorieTarget),
        formatDelta(_diff(t.avgCalories?.round(), l.avgCalories?.round())),
      ),
      (
        'protein',
        'progress.weekly.protein',
        _withPercent(t.avgProteinG, proteinTarget),
        _withPercent(l.avgProteinG, proteinTarget),
        formatDelta(_diff(t.avgProteinG?.round(), l.avgProteinG?.round())),
      ),
      (
        'nutrition_days',
        'progress.weekly.nutrition_days',
        '${t.nutritionDays}',
        '${l.nutritionDays}',
        formatDelta(_diff(t.nutritionDays, l.nutritionDays)),
      ),
      ('weight', 'progress.weekly.weight', weight(t.lastWeightKg), weight(l.lastWeightKg), formatDelta(summary.weightChangeKg)),
    ];
  }

  Widget _content(BuildContext context, WeeklySummary summary, Profile? profile) {
    final small = Theme.of(context).textTheme.bodySmall;
    final header = ProgressCardHeader(title: 'progress.weekly.title'.tr());
    if (summary.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          header,
          const SizedBox(height: 8),
          Text('progress.weekly.empty'.tr(), key: const Key('weekly_empty')),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        header,
        Text('progress.weekly.so_far'.tr(), style: small),
        const SizedBox(height: 8),
        Table(
          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
          columnWidths: const {
            0: FlexColumnWidth(2),
            1: FlexColumnWidth(1.5),
            2: FlexColumnWidth(1.5),
            3: FlexColumnWidth(1.1),
          },
          children: [
            TableRow(children: [
              const SizedBox.shrink(),
              for (final column in const ['this_week', 'last_week', 'change'])
                Text('progress.weekly.$column'.tr(), style: small),
            ]),
            for (final (key, label, current, previous, change) in _rows(summary, profile))
              TableRow(children: [
                Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Text(label.tr())),
                Text(current, key: Key('weekly_${key}_this')),
                Text(previous, key: Key('weekly_${key}_last')),
                Text(change, key: Key('weekly_${key}_change')),
              ]),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(weeklySummaryProvider);
    final profile = ref.watch(profileProvider).value;
    return Card(
      key: const Key('weekly_summary_card'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: summaryAsync.when(
          loading: () => const CardLoading(),
          error: (error, stackTrace) => CardError(
            onRetry: () => ref
              ..invalidate(recentSessionsProvider)
              ..invalidate(weeklyMealsProvider)
              ..invalidate(weightLogsProvider),
          ),
          data: (summary) => _content(context, summary, profile),
        ),
      ),
    );
  }
}
```

- [ ] **Step 6: Ana sayfayı listeye çevir**

`lib/features/onboarding/presentation/home_screen.dart` içinde `data:` dalındaki `return Center(child: Column(... TodayWorkoutCard ...));` bloğunun tamamı şununla değişir:

```dart
          return ListView(
            key: const Key('home_list'),
            padding: const EdgeInsets.all(16),
            children: [
              TargetsCard(profile: profile),
              const SizedBox(height: 12),
              const TodayWorkoutCard(),
              const SizedBox(height: 12),
              const WeeklySummaryCard(),
            ],
          );
```

Import'lar (mevcutların yanına):

```dart
import '../../progress/presentation/widgets/targets_card.dart';
import '../../progress/presentation/widgets/weekly_summary_card.dart';
```

`TodayWorkoutCard` import'u zaten var; artık kullanılmayan `Padding` sarmalayıcısı ListView'ın `padding`'ine taşındı.

- [ ] **Step 7: Testlerin geçtiğini gör**

Run: `flutter test --no-pub test/features/progress/presentation/home_cards_test.dart test/widget_test.dart`
Expected: PASS.

- [ ] **Step 8: Analiz ve commit**

Run: `flutter analyze --no-pub`
Expected: `No issues found!`

```bash
git add lib/features/progress/presentation/widgets/targets_card.dart lib/features/progress/presentation/widgets/weekly_summary_card.dart lib/features/onboarding/presentation/home_screen.dart test/features/progress/presentation/test_app.dart test/features/progress/presentation/home_cards_test.dart
git commit -m "feat(progress): turn home into a card list with targets and weekly summary"
```

---

## Task 8: Vücut ağırlığı — kart, kayıt penceresi ve kilo ekranı

**Files:**
- Create: `lib/features/progress/presentation/widgets/weight_log_dialog.dart`
- Create: `lib/features/progress/presentation/widgets/body_weight_card.dart`
- Create: `lib/features/progress/presentation/weight_screen.dart`
- Modify: `lib/features/onboarding/presentation/home_screen.dart` (listeye `BodyWeightCard`)
- Modify: `lib/core/router.dart` (`/home/weight`)
- Test: `test/features/progress/presentation/weight_test.dart`

**Interfaces:**
- Consumes: `bodyWeightServiceProvider`, `weightLogsProvider`, `LastWeightLogException`, `StaleWeightListException` (Task 5); `nowProvider`; `BodyWeightLog`, `isValidBodyWeight` (Task 2); `ValuePoint`, `ChartRange`, `pointsInRange`, `changeOver30Days` (Task 3); `ProgressLineChart`, `RangeSelector`, `CardLoading`, `CardError`, `ProgressCardHeader` (Task 6); test yardımcıları (Task 7), fake'ler (Task 5).
- Produces:
  - `Future<void> showWeightLogDialog(BuildContext context, {BodyWeightLog? existing})`; `WeightLogDialog` anahtarları `weight_input`, `weight_date_button`, `weight_save_button`, `weight_save_error`.
  - `BodyWeightCard()` anahtarları `weight_card`, `weight_add_button`, `weight_empty`, `weight_latest`, `weight_change`; dokununca `context.push('/home/weight')`.
  - `WeightScreen()` anahtarları `weight_screen`, `weight_screen_add`, `weight_chart`, satır `weight_log_<yyyy-MM-dd>`, sil `weight_delete_<yyyy-MM-dd>`, onay `confirm_delete_button`.

- [ ] **Step 1: Testleri yaz**

`test/features/progress/presentation/weight_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spor_takip/features/onboarding/application/profile_providers.dart';
import 'package:spor_takip/features/progress/application/progress_providers.dart';
import 'package:spor_takip/features/progress/domain/body_weight_log.dart';
import 'package:spor_takip/features/progress/presentation/weight_screen.dart';
import 'package:spor_takip/features/progress/presentation/widgets/body_weight_card.dart';
import 'package:spor_takip/features/workout/application/session_providers.dart';

import '../fakes.dart';
import '../fixtures.dart';
import 'test_app.dart';

final _now = DateTime(2026, 9, 28, 12);

void main() {
  setUpAll(initTestLocalization);

  late FakeBodyWeightRepository repo;

  setUp(() => repo = FakeBodyWeightRepository([
        BodyWeightLog(date: DateTime(2026, 8, 1), weightKg: 82),
        BodyWeightLog(date: DateTime(2026, 9, 20), weightKg: 80),
      ]));

  List overrides() => [
        bodyWeightRepositoryProvider.overrideWithValue(repo),
        profileProvider.overrideWith((ref) async => testProfile),
        nowProvider.overrideWithValue(() => _now),
      ];

  Future<void> openAddDialog(WidgetTester tester) async {
    await tester.pumpWidget(testApp(const BodyWeightCard(), overrides: overrides()));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('weight_add_button')));
    await tester.pumpAndSettle();
  }

  group('card', () {
    testWidgets('shows the latest weight and the 30-day change', (tester) async {
      await tester.pumpWidget(testApp(const BodyWeightCard(), overrides: overrides()));
      await tester.pumpAndSettle();

      expect(tester.widget<Text>(find.byKey(const Key('weight_latest'))).data, '80 kg');
      expect(tester.widget<Text>(find.byKey(const Key('weight_change'))).data, contains('▼ 2 kg'));
    });

    testWidgets('empty state', (tester) async {
      repo.logs.clear();
      await tester.pumpWidget(testApp(const BodyWeightCard(), overrides: overrides()));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('weight_empty')), findsOneWidget);
    });

    testWidgets('tapping the card opens the weight screen', (tester) async {
      await tester.pumpWidget(testApp(
        const BodyWeightCard(),
        overrides: overrides(),
        stubRoutes: {'/home/weight': 'WEIGHT_SCREEN'},
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('weight_latest')));
      await tester.pumpAndSettle();
      expect(find.text('WEIGHT_SCREEN'), findsOneWidget);
    });
  });

  group('log dialog', () {
    testWidgets('saves today with a comma decimal and closes', (tester) async {
      await openAddDialog(tester);

      await tester.enterText(find.byKey(const Key('weight_input')), '79,5');
      await tester.tap(find.byKey(const Key('weight_save_button')));
      await tester.pumpAndSettle();

      expect(repo.logged.single.date, DateTime(2026, 9, 28));
      expect(repo.logged.single.update.weightKg, 79.5);
      expect(find.byKey(const Key('weight_input')), findsNothing);
    });

    testWidgets('rejects an out-of-range value without saving', (tester) async {
      await openAddDialog(tester);

      await tester.enterText(find.byKey(const Key('weight_input')), '600');
      await tester.tap(find.byKey(const Key('weight_save_button')));
      await tester.pumpAndSettle();

      expect(repo.logged, isEmpty);
      expect(find.byKey(const Key('weight_input')), findsOneWidget);
    });

    testWidgets('a save error keeps the dialog open with a message', (tester) async {
      repo.error = Exception('offline');
      await openAddDialog(tester);

      await tester.enterText(find.byKey(const Key('weight_input')), '79');
      await tester.tap(find.byKey(const Key('weight_save_button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('weight_save_error')), findsOneWidget);
      expect(find.byKey(const Key('weight_input')), findsOneWidget);
    });
  });

  group('screen', () {
    Future<void> pumpScreen(WidgetTester tester) async {
      await tester.pumpWidget(testApp(const WeightScreen(), overrides: overrides(), scaffold: false));
      await tester.pumpAndSettle();
    }

    testWidgets('lists entries newest first with a chart', (tester) async {
      await pumpScreen(tester);

      expect(find.byKey(const Key('weight_chart')), findsOneWidget);
      final newest = tester.getTopLeft(find.byKey(const Key('weight_log_2026-09-20')));
      final oldest = tester.getTopLeft(find.byKey(const Key('weight_log_2026-08-01')));
      expect(newest.dy, lessThan(oldest.dy));
    });

    testWidgets('deleting the newest entry asks first and sends the previous weight', (tester) async {
      await pumpScreen(tester);

      await tester.tap(find.byKey(const Key('weight_delete_2026-09-20')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('confirm_delete_button')));
      await tester.pumpAndSettle();

      expect(repo.deleted.single.date, DateTime(2026, 9, 20));
      expect(repo.deleted.single.newLatest!.weightKg, 82);
      expect(find.byKey(const Key('weight_log_2026-09-20')), findsNothing);
    });

    testWidgets('the only entry cannot be deleted', (tester) async {
      repo.logs.removeAt(0);
      await pumpScreen(tester);

      final button = tester.widget<IconButton>(find.byKey(const Key('weight_delete_2026-09-20')));
      expect(button.onPressed, isNull);
    });

    testWidgets('tapping an entry edits its weight with the date fixed', (tester) async {
      await pumpScreen(tester);

      await tester.tap(find.byKey(const Key('weight_log_2026-09-20')));
      await tester.pumpAndSettle();

      final input = tester.widget<TextField>(find.byKey(const Key('weight_input')));
      expect(input.controller!.text, '80');
      final dateButton = tester.widget<TextButton>(find.byKey(const Key('weight_date_button')));
      expect(dateButton.onPressed, isNull);

      await tester.enterText(find.byKey(const Key('weight_input')), '80.4');
      await tester.tap(find.byKey(const Key('weight_save_button')));
      await tester.pumpAndSettle();
      expect(repo.logged.single.date, DateTime(2026, 9, 20));
      expect(repo.logged.single.update.weightKg, 80.4);
    });
  });
}
```

Not: `TextButton.icon` bir `TextButton` alt sınıfı döndürür; `find.byKey` + `tester.widget<TextButton>` bu yüzden çalışır. Çalışmazsa `tester.widget<ButtonStyleButton>` kullan.

- [ ] **Step 2: Testin başarısız olduğunu gör**

Run: `flutter test --no-pub test/features/progress/presentation/weight_test.dart`
Expected: FAIL — `body_weight_card.dart` / `weight_screen.dart` bulunamıyor.

- [ ] **Step 3: `weight_log_dialog.dart`**

```dart
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../workout/application/session_providers.dart';
import '../../application/body_weight_service.dart';
import '../../domain/body_weight_log.dart';
import '../../domain/progress_format.dart';

/// Diyaloğun kaydettikten sonra döndürdüğü sonuç.
class WeightLogResult {
  const WeightLogResult(this.newCalorieTarget);

  /// Profil güncellendiyse yeni kalori hedefi; geçmiş tarihli kayıtta null.
  final double? newCalorieTarget;
}

/// Kilo ekle ya da ([existing] verilirse) düzenle; kaydedince SnackBar gösterir.
Future<void> showWeightLogDialog(BuildContext context, {BodyWeightLog? existing}) async {
  final messenger = ScaffoldMessenger.of(context);
  final result = await showDialog<WeightLogResult>(
    context: context,
    builder: (_) => WeightLogDialog(existing: existing),
  );
  if (result == null) return;
  final target = result.newCalorieTarget;
  // Hedeflerin kendiliğinden değişmesi şaşırtmasın (spec §9).
  messenger.showSnackBar(SnackBar(
    content: Text(target == null
        ? 'progress.weight.saved'.tr()
        : 'progress.weight.saved_target'.tr(namedArgs: {'value': target.round().toString()})),
  ));
}

class WeightLogDialog extends ConsumerStatefulWidget {
  const WeightLogDialog({super.key, this.existing});

  /// Verilirse tarih sabittir (başka güne taşımak = sil + yeni kayıt).
  final BodyWeightLog? existing;

  @override
  ConsumerState<WeightLogDialog> createState() => _WeightLogDialogState();
}

class _WeightLogDialogState extends ConsumerState<WeightLogDialog> {
  late final TextEditingController _controller;
  late DateTime _date;
  String? _inputError;
  bool _saveFailed = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _date = existing?.date ?? dateOnly(ref.read(nowProvider)());
    _controller = TextEditingController(text: existing == null ? '' : formatOneDecimal(existing.weightKg));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final today = dateOnly(ref.read(nowProvider)());
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: today, // gelecek tarih seçilemez
    );
    if (picked != null && mounted) setState(() => _date = dateOnly(picked));
  }

  Future<void> _save() async {
    final kg = parseDecimal(_controller.text);
    if (kg == null || !isValidBodyWeight(kg)) {
      setState(() => _inputError = 'progress.weight.invalid'.tr());
      return;
    }
    setState(() {
      _inputError = null;
      _saveFailed = false;
      _saving = true;
    });
    try {
      final target = await ref.read(bodyWeightServiceProvider).log(date: _date, weightKg: kg);
      if (mounted) Navigator.of(context).pop(WeightLogResult(target));
    } catch (e, st) {
      debugPrint('WeightLogDialog.save failed: $e\n$st');
      if (mounted) {
        setState(() {
          _saveFailed = true;
          _saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text((widget.existing == null ? 'progress.weight.add' : 'progress.weight.edit').tr()),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            key: const Key('weight_input'),
            controller: _controller,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'progress.weight.input_label'.tr(),
              suffixText: 'kg',
              errorText: _inputError,
            ),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            key: const Key('weight_date_button'),
            icon: const Icon(Icons.calendar_today),
            label: Text('progress.date'.tr(namedArgs: {'date': formatShortDate(_date)})),
            onPressed: widget.existing == null && !_saving ? _pickDate : null,
          ),
          if (_saveFailed)
            Text(
              'progress.save_error'.tr(),
              key: const Key('weight_save_error'),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: Text('progress.cancel'.tr()),
        ),
        FilledButton(
          key: const Key('weight_save_button'),
          onPressed: _saving ? null : _save,
          child: Text('progress.save'.tr()),
        ),
      ],
    );
  }
}
```

- [ ] **Step 4: `body_weight_card.dart`**

```dart
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../workout/application/session_providers.dart';
import '../../application/progress_providers.dart';
import '../../domain/body_weight_log.dart';
import '../../domain/progress_format.dart';
import '../../domain/trend.dart';
import 'card_states.dart';
import 'progress_line_chart.dart';
import 'weight_log_dialog.dart';

class BodyWeightCard extends ConsumerWidget {
  const BodyWeightCard({super.key});

  Widget _content(BuildContext context, List<BodyWeightLog> logs, DateTime now) {
    if (logs.isEmpty) return Text('progress.weight.empty'.tr(), key: const Key('weight_empty'));
    final points = [for (final log in logs) ValuePoint(log.date, log.weightKg)];
    final change = changeOver30Days(points);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${formatOneDecimal(logs.last.weightKg)} kg',
          key: const Key('weight_latest'),
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        if (change != null)
          Text(
            'progress.change_30d'.tr(namedArgs: {'value': '${formatDelta(change)} kg'}),
            key: const Key('weight_change'),
          ),
        const SizedBox(height: 8),
        ProgressLineChart(points: pointsInRange(points, ChartRange.threeMonths, now), compact: true, height: 60),
      ],
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logsAsync = ref.watch(weightLogsProvider);
    final now = ref.watch(nowProvider)();
    return Card(
      key: const Key('weight_card'),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/home/weight'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ProgressCardHeader(
                title: 'progress.weight.title'.tr(),
                trailing: IconButton(
                  key: const Key('weight_add_button'),
                  tooltip: 'progress.weight.add'.tr(),
                  icon: const Icon(Icons.add),
                  onPressed: () => showWeightLogDialog(context),
                ),
              ),
              logsAsync.when(
                loading: () => const CardLoading(),
                error: (error, stackTrace) => CardError(onRetry: () => ref.invalidate(weightLogsProvider)),
                data: (logs) => _content(context, logs, now),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 5: `weight_screen.dart`**

```dart
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../workout/application/session_providers.dart';
import '../application/body_weight_service.dart';
import '../application/progress_providers.dart';
import '../data/body_weight_repository.dart';
import '../domain/body_weight_log.dart';
import '../domain/progress_format.dart';
import '../domain/trend.dart';
import 'widgets/card_states.dart';
import 'widgets/progress_line_chart.dart';
import 'widgets/range_selector.dart';
import 'widgets/weight_log_dialog.dart';

class WeightScreen extends ConsumerStatefulWidget {
  const WeightScreen({super.key});

  @override
  ConsumerState<WeightScreen> createState() => _WeightScreenState();
}

class _WeightScreenState extends ConsumerState<WeightScreen> {
  ChartRange _range = ChartRange.threeMonths;

  Future<void> _delete(BodyWeightLog log) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        content: Text('progress.delete_confirm'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text('progress.cancel'.tr()),
          ),
          TextButton(
            key: const Key('confirm_delete_button'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text('progress.delete'.tr()),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    String? message;
    try {
      await ref.read(bodyWeightServiceProvider).delete(log.date);
    } on StaleWeightListException {
      message = 'progress.weight.stale';
    } on LastWeightLogException {
      message = 'progress.weight.last_log_hint';
    } catch (e, st) {
      debugPrint('WeightScreen.delete failed: $e\n$st');
      message = 'progress.delete_error';
    }
    if (message != null) messenger.showSnackBar(SnackBar(content: Text(message.tr())));
  }

  Widget _list(List<BodyWeightLog> logs, DateTime now) {
    if (logs.isEmpty) {
      return Center(child: Text('progress.weight.empty'.tr(), key: const Key('weight_empty')));
    }
    final points = [for (final log in logs) ValuePoint(log.date, log.weightKg)];
    final canDelete = logs.length > 1;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
      children: [
        RangeSelector(value: _range, onChanged: (range) => setState(() => _range = range)),
        const SizedBox(height: 16),
        ProgressLineChart(key: const Key('weight_chart'), points: pointsInRange(points, _range, now)),
        const SizedBox(height: 16),
        for (final log in logs.reversed)
          ListTile(
            key: Key('weight_log_${formatDbDate(log.date)}'),
            title: Text('${formatOneDecimal(log.weightKg)} kg'),
            subtitle: Text(formatShortDate(log.date)),
            onTap: () => showWeightLogDialog(context, existing: log),
            trailing: IconButton(
              key: Key('weight_delete_${formatDbDate(log.date)}'),
              icon: const Icon(Icons.delete_outline),
              tooltip: (canDelete ? 'progress.delete' : 'progress.weight.last_log_hint').tr(),
              onPressed: canDelete ? () => _delete(log) : null,
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final logsAsync = ref.watch(weightLogsProvider);
    final now = ref.watch(nowProvider)();
    return Scaffold(
      key: const Key('weight_screen'),
      appBar: AppBar(title: Text('progress.weight.title'.tr())),
      floatingActionButton: FloatingActionButton(
        key: const Key('weight_screen_add'),
        tooltip: 'progress.weight.add'.tr(),
        onPressed: () => showWeightLogDialog(context),
        child: const Icon(Icons.add),
      ),
      body: logsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(child: CardError(onRetry: () => ref.invalidate(weightLogsProvider))),
        data: (logs) => _list(logs, now),
      ),
    );
  }
}
```

- [ ] **Step 6: Karta ve rotaya bağla**

`home_screen.dart` listesinde `const WeeklySummaryCard(),` satırından sonra:

```dart
              const SizedBox(height: 12),
              const BodyWeightCard(),
```

ve import: `import '../../progress/presentation/widgets/body_weight_card.dart';`

`lib/core/router.dart` içinde `/home` dalı:

```dart
          StatefulShellBranch(
            routes: [GoRoute(path: '/home', builder: (context, state) => const HomeScreen())],
          ),
```

şununla değişir:

```dart
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home',
                builder: (context, state) => const HomeScreen(),
                routes: [
                  GoRoute(path: 'weight', builder: (context, state) => const WeightScreen()),
                ],
              ),
            ],
          ),
```

ve import: `import '../features/progress/presentation/weight_screen.dart';`

- [ ] **Step 7: Testlerin geçtiğini gör**

Run: `flutter test --no-pub test/features/progress/presentation/weight_test.dart test/core/`
Expected: PASS.

- [ ] **Step 8: Analiz ve commit**

Run: `flutter analyze --no-pub`
Expected: `No issues found!`

```bash
git add lib/features/progress/presentation lib/features/onboarding/presentation/home_screen.dart lib/core/router.dart test/features/progress/presentation/weight_test.dart
git commit -m "feat(progress): add body weight card, log dialog and weight screen"
```

---

## Task 9: Güç ilerlemesi — kart ve güç ekranı

**Files:**
- Create: `lib/features/progress/presentation/widgets/strength_card.dart`
- Create: `lib/features/progress/presentation/strength_screen.dart`
- Modify: `lib/features/onboarding/presentation/home_screen.dart` (listeye `StrengthCard`)
- Modify: `lib/core/router.dart` (`/home/strength`)
- Test: `test/features/progress/presentation/strength_test.dart`

**Interfaces:**
- Consumes: `strengthCardProvider`, `allStrengthSeriesProvider`, `recentSessionsProvider`, `allSessionsProvider`, `progressDataRepositoryProvider` (Task 5); `StrengthSeries`, `StrengthPoint` (Task 3); `isInRange`, `changeOver30Days`, `ValuePoint`, `ChartRange` (Task 3); `formatDelta`, `formatOneDecimal`, `formatShortDate` (Task 2); Task 6 widget'ları; test yardımcıları (Task 7).
- Produces:
  - `StrengthCard()` anahtarları `strength_card`, `strength_empty`, `strength_row_<exerciseId>`, `strength_value_<exerciseId>`; dokununca `context.push('/home/strength')`.
  - `StrengthScreen()` anahtarları `strength_screen`, `strength_empty`, `strength_exercise_picker` (`DropdownButton<String>`), `strength_chart`.

- [ ] **Step 1: Testleri yaz**

`test/features/progress/presentation/strength_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spor_takip/features/progress/application/progress_providers.dart';
import 'package:spor_takip/features/progress/presentation/strength_screen.dart';
import 'package:spor_takip/features/progress/presentation/widgets/progress_line_chart.dart';
import 'package:spor_takip/features/progress/presentation/widgets/strength_card.dart';
import 'package:spor_takip/features/workout/application/session_providers.dart';

import '../fakes.dart';
import '../fixtures.dart';
import 'test_app.dart';

final _now = DateTime(2026, 9, 28, 12);

void main() {
  setUpAll(initTestLocalization);

  late FakeProgressDataRepository data;

  setUp(() => data = FakeProgressDataRepository(sessions: [
        finishedSession('old', DateTime(2026, 5, 1), [doneSet('deadlift', kg: 140, reps: 5)]),
        finishedSession('a', DateTime(2026, 8, 20), [doneSet('squat', kg: 100, reps: 5), doneSet('bench', kg: 60, reps: 5)]),
        finishedSession('b', DateTime(2026, 9, 25), [doneSet('squat', kg: 110, reps: 1)]),
      ]));

  List overrides() => [
        progressDataRepositoryProvider.overrideWithValue(data),
        nowProvider.overrideWithValue(() => _now),
      ];

  group('card', () {
    testWidgets('lists recent exercises with the latest estimate and the change', (tester) async {
      await tester.pumpWidget(testApp(const StrengthCard(), overrides: overrides()));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('strength_row_squat')), findsOneWidget);
      expect(find.byKey(const Key('strength_row_bench')), findsOneWidget);
      expect(find.byKey(const Key('strength_row_deadlift')), findsNothing); // 90 günden eski
      expect(tester.widget<Text>(find.byKey(const Key('strength_value_squat'))).data, '110 kg');
      expect(find.text('squat name'), findsOneWidget);
    });

    testWidgets('empty state', (tester) async {
      data.sessions.clear();
      await tester.pumpWidget(testApp(const StrengthCard(), overrides: overrides()));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('strength_empty')), findsOneWidget);
    });

    testWidgets('tapping opens the strength screen', (tester) async {
      await tester.pumpWidget(testApp(
        const StrengthCard(),
        overrides: overrides(),
        stubRoutes: {'/home/strength': 'STRENGTH_SCREEN'},
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('strength_value_squat')));
      await tester.pumpAndSettle();
      expect(find.text('STRENGTH_SCREEN'), findsOneWidget);
    });
  });

  group('screen', () {
    Future<void> pumpScreen(WidgetTester tester) async {
      await tester.pumpWidget(testApp(const StrengthScreen(), overrides: overrides(), scaffold: false));
      await tester.pumpAndSettle();
    }

    DropdownButton<String> picker(WidgetTester tester) =>
        tester.widget<DropdownButton<String>>(find.byKey(const Key('strength_exercise_picker')));

    testWidgets('starts with the most frequent exercise and lists all history', (tester) async {
      await pumpScreen(tester);

      expect(picker(tester).value, 'squat');
      expect(picker(tester).items!.map((i) => i.value), ['squat', 'bench', 'deadlift']);
      expect(find.byKey(const Key('strength_chart')), findsOneWidget);
    });

    testWidgets('picking another exercise switches the chart', (tester) async {
      await pumpScreen(tester);

      await tester.tap(find.byKey(const Key('strength_exercise_picker')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('bench name').last);
      await tester.pumpAndSettle();

      expect(picker(tester).value, 'bench');
      final chart = tester.widget<ProgressLineChart>(find.byKey(const Key('strength_chart')));
      expect(chart.points.single.value, closeTo(70, 0.01)); // 60 × (1 + 5/30)
    });

    testWidgets('empty state', (tester) async {
      data.sessions.clear();
      await pumpScreen(tester);

      expect(find.byKey(const Key('strength_empty')), findsOneWidget);
    });
  });
}
```

- [ ] **Step 2: Testin başarısız olduğunu gör**

Run: `flutter test --no-pub test/features/progress/presentation/strength_test.dart`
Expected: FAIL — `strength_card.dart` / `strength_screen.dart` bulunamıyor.

- [ ] **Step 3: `strength_card.dart`**

```dart
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../application/progress_providers.dart';
import '../../domain/progress_format.dart';
import '../../domain/strength.dart';
import '../../domain/trend.dart';
import 'card_states.dart';

/// Son 90 günde en sık yapılan 3 hareketin tahmini 1RM'i (spec §4.2).
class StrengthCard extends ConsumerWidget {
  const StrengthCard({super.key});

  Widget _row(StrengthSeries series) {
    final change = changeOver30Days(series.valuePoints);
    return ListTile(
      key: Key('strength_row_${series.exerciseId}'),
      contentPadding: EdgeInsets.zero,
      dense: true,
      title: Text(series.exerciseName),
      subtitle: change == null
          ? null
          : Text('progress.change_30d'.tr(namedArgs: {'value': '${formatDelta(change)} kg'})),
      trailing: Text(
        '${formatOneDecimal(series.latest.estimateKg)} kg',
        key: Key('strength_value_${series.exerciseId}'),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final seriesAsync = ref.watch(strengthCardProvider);
    return Card(
      key: const Key('strength_card'),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/home/strength'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ProgressCardHeader(title: 'progress.strength.title'.tr()),
              const SizedBox(height: 8),
              seriesAsync.when(
                loading: () => const CardLoading(),
                error: (error, stackTrace) => CardError(onRetry: () => ref.invalidate(recentSessionsProvider)),
                data: (series) => series.isEmpty
                    ? Text('progress.strength.empty'.tr(), key: const Key('strength_empty'))
                    : Column(children: [for (final s in series) _row(s)]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: `strength_screen.dart`**

```dart
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../workout/application/session_providers.dart';
import '../application/progress_providers.dart';
import '../domain/progress_format.dart';
import '../domain/strength.dart';
import '../domain/trend.dart';
import 'widgets/card_states.dart';
import 'widgets/progress_line_chart.dart';
import 'widgets/range_selector.dart';

class StrengthScreen extends ConsumerStatefulWidget {
  const StrengthScreen({super.key});

  @override
  ConsumerState<StrengthScreen> createState() => _StrengthScreenState();
}

class _StrengthScreenState extends ConsumerState<StrengthScreen> {
  String? _exerciseId;
  ChartRange _range = ChartRange.threeMonths;

  static String _tooltip(StrengthPoint p) => '${formatShortDate(p.date)}\n'
      '${formatOneDecimal(p.weightKg)} kg × ${p.reps}\n'
      '≈ ${formatOneDecimal(p.estimateKg)} kg';

  Widget _content(List<StrengthSeries> all, DateTime now) {
    if (all.isEmpty) {
      return Center(child: Text('progress.strength.empty'.tr(), key: const Key('strength_empty')));
    }
    final selected = all.firstWhere((s) => s.exerciseId == _exerciseId, orElse: () => all.first);
    final points = [for (final p in selected.points) if (isInRange(p.date, _range, now)) p];
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('progress.strength.exercise'.tr(), style: Theme.of(context).textTheme.labelMedium),
        DropdownButton<String>(
          key: const Key('strength_exercise_picker'),
          value: selected.exerciseId,
          isExpanded: true,
          items: [
            for (final s in all)
              DropdownMenuItem(
                value: s.exerciseId,
                child: Text(s.exerciseName, overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: (id) => setState(() => _exerciseId = id),
        ),
        const SizedBox(height: 16),
        RangeSelector(value: _range, onChanged: (range) => setState(() => _range = range)),
        const SizedBox(height: 16),
        ProgressLineChart(
          key: const Key('strength_chart'),
          points: [for (final p in points) ValuePoint(p.date, p.estimateKg)],
          tooltipLabel: (index) => _tooltip(points[index]),
        ),
        const SizedBox(height: 8),
        Text('progress.strength.estimated_note'.tr(), style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final seriesAsync = ref.watch(allStrengthSeriesProvider);
    final now = ref.watch(nowProvider)();
    return Scaffold(
      key: const Key('strength_screen'),
      appBar: AppBar(title: Text('progress.strength.title'.tr())),
      body: seriesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(child: CardError(onRetry: () => ref.invalidate(allSessionsProvider))),
        data: (all) => _content(all, now),
      ),
    );
  }
}
```

- [ ] **Step 5: Karta ve rotaya bağla**

`home_screen.dart` listesinde `const BodyWeightCard(),` satırından sonra:

```dart
              const SizedBox(height: 12),
              const StrengthCard(),
```

ve import: `import '../../progress/presentation/widgets/strength_card.dart';`

`lib/core/router.dart` içinde `/home` rotasının `routes:` listesine (weight'ten sonra):

```dart
                  GoRoute(path: 'strength', builder: (context, state) => const StrengthScreen()),
```

ve import: `import '../features/progress/presentation/strength_screen.dart';`

- [ ] **Step 6: Testlerin geçtiğini gör**

Run: `flutter test --no-pub test/features/progress/presentation/strength_test.dart`
Expected: PASS.

- [ ] **Step 7: Analiz ve commit**

Run: `flutter analyze --no-pub`
Expected: `No issues found!`

```bash
git add lib/features/progress/presentation lib/features/onboarding/presentation/home_screen.dart lib/core/router.dart test/features/progress/presentation/strength_test.dart
git commit -m "feat(progress): add strength progress card and screen"
```

---

## Task 10: Beden ölçüleri — kart, ölçüm formu ve ölçüler ekranı

**Files:**
- Create: `lib/features/progress/presentation/widgets/measurement_form_dialog.dart`
- Create: `lib/features/progress/presentation/widgets/measurements_card.dart`
- Create: `lib/features/progress/presentation/measurements_screen.dart`
- Modify: `lib/features/onboarding/presentation/home_screen.dart` (listeye `MeasurementsCard`)
- Modify: `lib/core/router.dart` (`/home/measurements`)
- Test: `test/features/progress/presentation/measurements_test.dart`

**Interfaces:**
- Consumes: `measurementsProvider`, `bodyMeasurementRepositoryProvider` (Task 5); `BodyMeasurement`, `MeasurementSite`, `isValidMeasurement`, `measurementChange` (Task 2); `nowProvider`; Task 3 trend fonksiyonları; Task 6 widget'ları; test yardımcıları (Task 7), `FakeBodyMeasurementRepository` (Task 5).
- Produces:
  - `Future<void> showMeasurementForm(BuildContext context, {BodyMeasurement? existing})`; `MeasurementFormDialog` anahtarları `measurement_date_button`, `measurement_field_<site>`, `measurement_form_error`, `measurement_save_button`.
  - `MeasurementsCard()` anahtarları `measurements_card`, `measurement_add_button`, `measurements_empty`, `measurements_last`, `measurement_chip_<site>`; dokununca `context.push('/home/measurements')`.
  - `MeasurementsScreen()` anahtarları `measurements_screen`, `measurements_screen_add`, `site_chip_<site>`, `measurement_chart`, satır `measurement_row_<yyyy-MM-dd>`, sil `measurement_delete_<yyyy-MM-dd>`, onay `confirm_delete_button`.

- [ ] **Step 1: Testleri yaz**

`test/features/progress/presentation/measurements_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spor_takip/features/progress/application/progress_providers.dart';
import 'package:spor_takip/features/progress/domain/body_measurement.dart';
import 'package:spor_takip/features/progress/presentation/measurements_screen.dart';
import 'package:spor_takip/features/progress/presentation/widgets/measurements_card.dart';
import 'package:spor_takip/features/progress/presentation/widgets/progress_line_chart.dart';
import 'package:spor_takip/features/workout/application/session_providers.dart';

import '../fakes.dart';
import 'test_app.dart';

final _now = DateTime(2026, 9, 28, 12);

void main() {
  setUpAll(initTestLocalization);

  late FakeBodyMeasurementRepository repo;

  setUp(() => repo = FakeBodyMeasurementRepository([
        BodyMeasurement(date: DateTime(2026, 9, 1), values: {MeasurementSite.waist: 85}),
        BodyMeasurement(
          date: DateTime(2026, 9, 20),
          values: {MeasurementSite.waist: 83, MeasurementSite.arm: 35},
        ),
      ]));

  List overrides() => [
        bodyMeasurementRepositoryProvider.overrideWithValue(repo),
        nowProvider.overrideWithValue(() => _now),
      ];

  TextField field(WidgetTester tester, MeasurementSite site) =>
      tester.widget<TextField>(find.byKey(Key('measurement_field_${site.name}')));

  Future<void> openAddForm(WidgetTester tester) async {
    await tester.pumpWidget(testApp(const MeasurementsCard(), overrides: overrides()));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('measurement_add_button')));
    await tester.pumpAndSettle();
  }

  group('card', () {
    testWidgets('shows the last date and a chip per filled site', (tester) async {
      await tester.pumpWidget(testApp(const MeasurementsCard(), overrides: overrides()));
      await tester.pumpAndSettle();

      expect(tester.widget<Text>(find.byKey(const Key('measurements_last'))).data, contains('20.9.2026'));
      expect(find.byKey(const Key('measurement_chip_waist')), findsOneWidget);
      expect(find.byKey(const Key('measurement_chip_arm')), findsOneWidget);
      expect(find.byKey(const Key('measurement_chip_neck')), findsNothing);
      expect(find.textContaining('83 (▼ 2)'), findsOneWidget);
    });

    testWidgets('empty state', (tester) async {
      repo.items.clear();
      await tester.pumpWidget(testApp(const MeasurementsCard(), overrides: overrides()));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('measurements_empty')), findsOneWidget);
    });

    testWidgets('tapping opens the measurements screen', (tester) async {
      await tester.pumpWidget(testApp(
        const MeasurementsCard(),
        overrides: overrides(),
        stubRoutes: {'/home/measurements': 'MEASUREMENTS_SCREEN'},
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('measurements_last')));
      await tester.pumpAndSettle();
      expect(find.text('MEASUREMENTS_SCREEN'), findsOneWidget);
    });
  });

  group('form', () {
    testWidgets('saves today with the filled sites only', (tester) async {
      await openAddForm(tester);

      await tester.enterText(find.byKey(const Key('measurement_field_waist')), '82,5');
      await tester.enterText(find.byKey(const Key('measurement_field_neck')), '38');
      await tester.tap(find.byKey(const Key('measurement_save_button')));
      await tester.pumpAndSettle();

      final saved = repo.items.firstWhere((m) => m.date == DateTime(2026, 9, 28));
      expect(saved.values, {MeasurementSite.neck: 38.0, MeasurementSite.waist: 82.5});
      expect(find.byKey(const Key('measurement_save_button')), findsNothing);
    });

    testWidgets('an empty form is not saved', (tester) async {
      await openAddForm(tester);

      await tester.tap(find.byKey(const Key('measurement_save_button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('measurement_form_error')), findsOneWidget);
      expect(repo.items, hasLength(2));
    });

    testWidgets('an out-of-range value marks the field and is not saved', (tester) async {
      await openAddForm(tester);

      await tester.enterText(find.byKey(const Key('measurement_field_waist')), '400');
      await tester.tap(find.byKey(const Key('measurement_save_button')));
      await tester.pumpAndSettle();

      expect(field(tester, MeasurementSite.waist).decoration!.errorText, isNotNull);
      expect(repo.items, hasLength(2));
    });

    testWidgets('opening on a day that has a measurement prefills it', (tester) async {
      repo.items.add(BodyMeasurement(date: DateTime(2026, 9, 28), values: {MeasurementSite.chest: 100}));
      await openAddForm(tester);

      expect(field(tester, MeasurementSite.chest).controller!.text, '100');
      expect(field(tester, MeasurementSite.waist).controller!.text, '');
    });
  });

  group('screen', () {
    Future<void> pumpScreen(WidgetTester tester) async {
      await tester.pumpWidget(testApp(const MeasurementsScreen(), overrides: overrides(), scaffold: false));
      await tester.pumpAndSettle();
    }

    testWidgets('chips only for sites with data; picking one switches the chart', (tester) async {
      await pumpScreen(tester);

      expect(find.byKey(const Key('site_chip_waist')), findsOneWidget);
      expect(find.byKey(const Key('site_chip_arm')), findsOneWidget);
      expect(find.byKey(const Key('site_chip_neck')), findsNothing);
      ProgressLineChart chart() => tester.widget(find.byKey(const Key('measurement_chart')));
      expect(chart().points.map((p) => p.value), [85, 83]);

      await tester.tap(find.byKey(const Key('site_chip_arm')));
      await tester.pumpAndSettle();
      expect(chart().points.map((p) => p.value), [35]);
    });

    testWidgets('deleting a row asks first', (tester) async {
      await pumpScreen(tester);

      await tester.tap(find.byKey(const Key('measurement_delete_2026-09-01')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('confirm_delete_button')));
      await tester.pumpAndSettle();

      expect(repo.items.map((m) => m.date), [DateTime(2026, 9, 20)]);
      expect(find.byKey(const Key('measurement_row_2026-09-01')), findsNothing);
    });

    testWidgets('tapping a row edits it with its values', (tester) async {
      await pumpScreen(tester);

      await tester.tap(find.byKey(const Key('measurement_row_2026-09-20')));
      await tester.pumpAndSettle();

      expect(field(tester, MeasurementSite.waist).controller!.text, '83');
      expect(field(tester, MeasurementSite.arm).controller!.text, '35');
    });
  });
}
```

- [ ] **Step 2: Testin başarısız olduğunu gör**

Run: `flutter test --no-pub test/features/progress/presentation/measurements_test.dart`
Expected: FAIL — `measurements_card.dart` / `measurements_screen.dart` bulunamıyor.

- [ ] **Step 3: `measurement_form_dialog.dart`**

```dart
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../workout/application/session_providers.dart';
import '../../application/progress_providers.dart';
import '../../domain/body_measurement.dart';
import '../../domain/progress_format.dart';

/// Ölçüm ekle ya da ([existing] verilirse) düzenle.
Future<void> showMeasurementForm(BuildContext context, {BodyMeasurement? existing}) {
  return showDialog<void>(context: context, builder: (_) => MeasurementFormDialog(existing: existing));
}

class MeasurementFormDialog extends ConsumerStatefulWidget {
  const MeasurementFormDialog({super.key, this.existing});

  /// Verilirse tarih sabittir.
  final BodyMeasurement? existing;

  @override
  ConsumerState<MeasurementFormDialog> createState() => _MeasurementFormDialogState();
}

class _MeasurementFormDialogState extends ConsumerState<MeasurementFormDialog> {
  final _controllers = {for (final site in MeasurementSite.values) site: TextEditingController()};
  final _errors = <MeasurementSite, String>{};
  late DateTime _date;
  String? _formError;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _date = widget.existing?.date ?? dateOnly(ref.read(nowProvider)());
    final initial = widget.existing ?? _measurementOn(_date);
    if (initial != null) _fill(initial);
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  /// Aynı tarihte kayıt varsa form onun değerleriyle açılır (spec §5.4).
  BodyMeasurement? _measurementOn(DateTime date) =>
      ref.read(measurementsProvider).value?.where((m) => m.date == date).firstOrNull;

  void _fill(BodyMeasurement measurement) {
    for (final site in MeasurementSite.values) {
      final value = measurement.values[site];
      _controllers[site]!.text = value == null ? '' : formatOneDecimal(value);
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: dateOnly(ref.read(nowProvider)()), // gelecek tarih seçilemez
    );
    if (picked == null || !mounted) return;
    setState(() {
      _date = dateOnly(picked);
      // Yazılmış değerler, yalnızca o günün kaydı varsa onunla değiştirilir.
      final existing = _measurementOn(_date);
      if (existing != null) _fill(existing);
    });
  }

  Future<void> _save() async {
    final values = <MeasurementSite, double>{};
    _errors.clear();
    for (final site in MeasurementSite.values) {
      final text = _controllers[site]!.text.trim();
      if (text.isEmpty) continue;
      final value = parseDecimal(text);
      if (value == null || !isValidMeasurement(value)) {
        _errors[site] = 'progress.measurements.invalid'.tr();
      } else {
        values[site] = value;
      }
    }
    if (_errors.isNotEmpty) {
      setState(() => _formError = null);
      return;
    }
    if (values.isEmpty) {
      setState(() => _formError = 'progress.measurements.need_one'.tr());
      return;
    }
    setState(() {
      _formError = null;
      _saving = true;
    });
    try {
      await ref
          .read(bodyMeasurementRepositoryProvider)
          .saveMeasurement(BodyMeasurement(date: _date, values: values));
      ref.invalidate(measurementsProvider);
      if (mounted) Navigator.of(context).pop();
    } catch (e, st) {
      debugPrint('MeasurementFormDialog.save failed: $e\n$st');
      if (mounted) {
        setState(() {
          _formError = 'progress.save_error'.tr();
          _saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('progress.measurements.form_title'.tr()),
      content: SizedBox(
        width: 360,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextButton.icon(
                key: const Key('measurement_date_button'),
                icon: const Icon(Icons.calendar_today),
                label: Text('progress.date'.tr(namedArgs: {'date': formatShortDate(_date)})),
                onPressed: widget.existing == null && !_saving ? _pickDate : null,
              ),
              for (final site in MeasurementSite.values)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: TextField(
                    key: Key('measurement_field_${site.name}'),
                    controller: _controllers[site],
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'progress.sites.${site.name}'.tr(),
                      suffixText: 'cm',
                      errorText: _errors[site],
                      isDense: true,
                    ),
                  ),
                ),
              if (_formError != null)
                Text(
                  _formError!,
                  key: const Key('measurement_form_error'),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: Text('progress.cancel'.tr()),
        ),
        FilledButton(
          key: const Key('measurement_save_button'),
          onPressed: _saving ? null : _save,
          child: Text('progress.save'.tr()),
        ),
      ],
    );
  }
}
```

Not: "opening on a day that has a measurement prefills it" testi, kart `measurementsProvider`'ı zaten yüklediği için `ref.read(measurementsProvider).value` dolu olduğunda geçer; form ana sayfadaki karttan ya da ölçüler ekranından açılır, ikisi de provider'ı izler.

- [ ] **Step 4: `measurements_card.dart`**

```dart
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../application/progress_providers.dart';
import '../../domain/body_measurement.dart';
import '../../domain/progress_format.dart';
import 'card_states.dart';
import 'measurement_form_dialog.dart';

class MeasurementsCard extends ConsumerWidget {
  const MeasurementsCard({super.key});

  /// "Bel 83 (▼ 2)"; önceki değer yoksa fark yazılmaz.
  static String _chipText(MeasurementSite site, double cm, double? change) {
    final base = '${'progress.sites.${site.name}'.tr()} ${formatOneDecimal(cm)}';
    return change == null ? base : '$base (${formatDelta(change)})';
  }

  Widget _content(List<BodyMeasurement> list) {
    if (list.isEmpty) return Text('progress.measurements.empty'.tr(), key: const Key('measurements_empty'));
    final latest = list.last;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'progress.measurements.last'.tr(namedArgs: {'date': formatShortDate(latest.date)}),
          key: const Key('measurements_last'),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final MapEntry(key: site, value: cm) in latest.values.entries)
              Chip(
                key: Key('measurement_chip_${site.name}'),
                label: Text(_chipText(site, cm, measurementChange(list, site))),
              ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final measurementsAsync = ref.watch(measurementsProvider);
    return Card(
      key: const Key('measurements_card'),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/home/measurements'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ProgressCardHeader(
                title: 'progress.measurements.title'.tr(),
                trailing: IconButton(
                  key: const Key('measurement_add_button'),
                  tooltip: 'progress.measurements.add'.tr(),
                  icon: const Icon(Icons.add),
                  onPressed: () => showMeasurementForm(context),
                ),
              ),
              measurementsAsync.when(
                loading: () => const CardLoading(),
                error: (error, stackTrace) => CardError(onRetry: () => ref.invalidate(measurementsProvider)),
                data: _content,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 5: `measurements_screen.dart`**

```dart
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../workout/application/session_providers.dart';
import '../application/progress_providers.dart';
import '../domain/body_measurement.dart';
import '../domain/progress_format.dart';
import '../domain/trend.dart';
import 'widgets/card_states.dart';
import 'widgets/measurement_form_dialog.dart';
import 'widgets/progress_line_chart.dart';
import 'widgets/range_selector.dart';

class MeasurementsScreen extends ConsumerStatefulWidget {
  const MeasurementsScreen({super.key});

  @override
  ConsumerState<MeasurementsScreen> createState() => _MeasurementsScreenState();
}

class _MeasurementsScreenState extends ConsumerState<MeasurementsScreen> {
  MeasurementSite? _site;
  ChartRange _range = ChartRange.threeMonths;

  static String _summary(BodyMeasurement m) => [
        for (final MapEntry(key: site, value: cm) in m.values.entries)
          '${'progress.sites.${site.name}'.tr()} ${formatOneDecimal(cm)}',
      ].join(' · ');

  Future<void> _delete(BodyMeasurement measurement) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        content: Text('progress.delete_confirm'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text('progress.cancel'.tr()),
          ),
          TextButton(
            key: const Key('confirm_delete_button'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text('progress.delete'.tr()),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(bodyMeasurementRepositoryProvider).deleteMeasurement(measurement.date);
      ref.invalidate(measurementsProvider);
    } catch (e, st) {
      debugPrint('MeasurementsScreen.delete failed: $e\n$st');
      messenger.showSnackBar(SnackBar(content: Text('progress.delete_error'.tr())));
    }
  }

  Widget _content(List<BodyMeasurement> list, DateTime now) {
    if (list.isEmpty) {
      return Center(child: Text('progress.measurements.empty'.tr(), key: const Key('measurements_empty')));
    }
    final sites = [
      for (final site in MeasurementSite.values)
        if (list.any((m) => m.values.containsKey(site))) site,
    ];
    final site = sites.contains(_site) ? _site! : sites.first;
    final points = [
      for (final m in list)
        if (m.values[site] case final cm?) ValuePoint(m.date, cm),
    ];
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final s in sites)
              ChoiceChip(
                key: Key('site_chip_${s.name}'),
                label: Text('progress.sites.${s.name}'.tr()),
                selected: s == site,
                onSelected: (_) => setState(() => _site = s),
              ),
          ],
        ),
        const SizedBox(height: 12),
        RangeSelector(value: _range, onChanged: (range) => setState(() => _range = range)),
        const SizedBox(height: 16),
        ProgressLineChart(key: const Key('measurement_chart'), points: pointsInRange(points, _range, now)),
        const SizedBox(height: 16),
        for (final m in list.reversed)
          ListTile(
            key: Key('measurement_row_${formatDbDate(m.date)}'),
            title: Text(formatShortDate(m.date)),
            subtitle: Text(_summary(m)),
            onTap: () => showMeasurementForm(context, existing: m),
            trailing: IconButton(
              key: Key('measurement_delete_${formatDbDate(m.date)}'),
              icon: const Icon(Icons.delete_outline),
              tooltip: 'progress.delete'.tr(),
              onPressed: () => _delete(m),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final measurementsAsync = ref.watch(measurementsProvider);
    final now = ref.watch(nowProvider)();
    return Scaffold(
      key: const Key('measurements_screen'),
      appBar: AppBar(title: Text('progress.measurements.title'.tr())),
      floatingActionButton: FloatingActionButton(
        key: const Key('measurements_screen_add'),
        tooltip: 'progress.measurements.add'.tr(),
        onPressed: () => showMeasurementForm(context),
        child: const Icon(Icons.add),
      ),
      body: measurementsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(child: CardError(onRetry: () => ref.invalidate(measurementsProvider))),
        data: (list) => _content(list, now),
      ),
    );
  }
}
```

- [ ] **Step 6: Karta ve rotaya bağla**

`home_screen.dart` listesinde `const StrengthCard(),` satırından sonra:

```dart
              const SizedBox(height: 12),
              const MeasurementsCard(),
```

ve import: `import '../../progress/presentation/widgets/measurements_card.dart';`

`lib/core/router.dart` içinde `/home` rotasının `routes:` listesine (strength'ten sonra):

```dart
                  GoRoute(path: 'measurements', builder: (context, state) => const MeasurementsScreen()),
```

ve import: `import '../features/progress/presentation/measurements_screen.dart';`

- [ ] **Step 7: Testlerin geçtiğini gör**

Run: `flutter test --no-pub test/features/progress/presentation/measurements_test.dart`
Expected: PASS.

- [ ] **Step 8: Analiz ve commit**

Run: `flutter analyze --no-pub`
Expected: `No issues found!`

```bash
git add lib/features/progress/presentation lib/features/onboarding/presentation/home_screen.dart lib/core/router.dart test/features/progress/presentation/measurements_test.dart
git commit -m "feat(progress): add body measurements card, form and screen"
```

---

## Task 11: Bağlantılar — onboarding ilk kilo kaydı ve verilerin yenilenmesi

**Files:**
- Modify: `lib/features/onboarding/presentation/onboarding_wizard_screen.dart:47` (`_finish`)
- Modify: `lib/features/workout/application/session_notifier.dart:114-121` (`finish`)
- Modify: `lib/features/workout/presentation/history_detail_screen.dart:39-40` (silme)
- Modify: `lib/features/nutrition/application/meal_capture_notifier.dart:97` (kaydetme)
- Test: `test/features/workout/application/session_notifier_test.dart`

**Interfaces:**
- Consumes: `recordInitialWeight`, `bodyWeightRepositoryProvider`, `recentSessionsProvider`, `allSessionsProvider`, `weeklyMealsProvider`, `progressDataRepositoryProvider` (Task 5); `FakeProgressDataRepository` (Task 5).
- Produces: davranış — onboarding bitince bugünün tarihiyle ilk kilo kaydı yazılır; antrenman bitince/silinince güç ve haftalık özet verileri, öğün kaydedilince haftalık öğünler yeniden çekilir (spec §3 Onboarding, §5.5).

`recordInitialWeight` Task 5'te birim test edildi; onboarding ekranının kendisi, geçmiş silme ve öğün kaydı için widget testi yok (mevcut testlerde de yok) — bunlar Task 12'deki elle kontrol listesinde doğrulanır. Antrenman bitirme yenilemesi aşağıda test edilir.

- [ ] **Step 1: Başarısız testi yaz**

`test/features/workout/application/session_notifier_test.dart`:

Import'lara ekle:

```dart
import 'package:spor_takip/features/progress/application/progress_providers.dart';

import '../../progress/fakes.dart';
```

`main()` içinde `late ProviderContainer container;` satırından sonra:

```dart
  late FakeProgressDataRepository progressRepo;
```

`setUpWith` içinde `repo = ...` satırından sonra `progressRepo = FakeProgressDataRepository();` ekle ve `ProviderContainer(overrides: [...])` listesine şunu ekle:

```dart
      progressDataRepositoryProvider.overrideWithValue(progressRepo),
```

`'finish rethrows repository errors'` testinden sonra yeni test:

```dart
  test('finish refreshes the progress data', () async {
    setUpWith([_s('a')]);
    await load();
    container.listen(recentSessionsProvider, (_, _) {});
    await container.read(recentSessionsProvider.future);
    expect(progressRepo.sessionFetches, 1);

    await notifier().finish(const {});
    await container.read(recentSessionsProvider.future);

    expect(progressRepo.sessionFetches, 2);
  });
```

- [ ] **Step 2: Testin başarısız olduğunu gör**

Run: `flutter test --no-pub test/features/workout/application/session_notifier_test.dart`
Expected: FAIL — yeni testte `sessionFetches` 1 kalır (Expected: <2> Actual: <1>); diğer testler PASS.

- [ ] **Step 3: Antrenman bitince ilerleme verilerini yenile**

`lib/features/workout/application/session_notifier.dart` içindeki `finish`:

```dart
  Future<void> finish(Map<String, double> oneRepMaxes) async {
    await _repo.finishSession(sessionId, oneRepMaxes);
    ref
      ..invalidate(inProgressSessionProvider)
      ..invalidate(sessionHistoryProvider)
      ..invalidate(activeProgramStateProvider)
      ..invalidate(oneRepMaxesProvider)
      // F4b: güç grafikleri ve haftalık özet
      ..invalidate(recentSessionsProvider)
      ..invalidate(allSessionsProvider);
  }
```

Import: `import '../../progress/application/progress_providers.dart';`

- [ ] **Step 4: Testin geçtiğini gör**

Run: `flutter test --no-pub test/features/workout/application/session_notifier_test.dart`
Expected: PASS.

- [ ] **Step 5: Geçmişten silme ve öğün kaydı**

`lib/features/workout/presentation/history_detail_screen.dart` silme bloğunda:

```dart
      await ref.read(sessionRepositoryProvider).deleteSession(sessionId);
      ref.invalidate(sessionHistoryProvider);
```

şuna dönüşür:

```dart
      await ref.read(sessionRepositoryProvider).deleteSession(sessionId);
      ref
        ..invalidate(sessionHistoryProvider)
        ..invalidate(recentSessionsProvider)
        ..invalidate(allSessionsProvider);
```

Import: `import '../../progress/application/progress_providers.dart';`

`lib/features/nutrition/application/meal_capture_notifier.dart` içinde `ref.invalidate(todayMealsProvider);` satırından sonra:

```dart
      ref.invalidate(weeklyMealsProvider); // F4b haftalık özet
```

Import: `import '../../progress/application/progress_providers.dart';`

- [ ] **Step 6: Onboarding'de ilk kilo kaydı**

`lib/features/onboarding/presentation/onboarding_wizard_screen.dart` `_finish` içinde:

```dart
      await ref.read(profileRepositoryProvider).saveProfile(profile);
      ref.invalidate(profileProvider);
```

şuna dönüşür:

```dart
      await ref.read(profileRepositoryProvider).saveProfile(profile);
      try {
        await recordInitialWeight(ref.read(bodyWeightRepositoryProvider), profile, DateTime.now());
      } catch (e, st) {
        // Profil kaydedildi; ilk kilo kaydı eksik kalırsa kilo kartı boş
        // durumunu gösterir, onboarding'i bunun için durdurmayız.
        debugPrint('Initial weight log failed: $e\n$st');
      }
      ref.invalidate(profileProvider);
```

Import'lar:

```dart
import '../../progress/application/body_weight_service.dart';
import '../../progress/application/progress_providers.dart';
```

- [ ] **Step 7: Tam test paketi ve analiz**

Run: `flutter analyze --no-pub`
Expected: `No issues found!`

Run (arka planda, ~10 dk): `flutter test --no-pub`
Expected: tüm testler PASS (F4a'nın 199 testi + F4b'nin yeni testleri).

- [ ] **Step 8: Commit**

```bash
git add lib/features/onboarding/presentation/onboarding_wizard_screen.dart lib/features/workout/application/session_notifier.dart lib/features/workout/presentation/history_detail_screen.dart lib/features/nutrition/application/meal_capture_notifier.dart test/features/workout/application/session_notifier_test.dart
git commit -m "feat(progress): log initial weight on onboarding and refresh progress data"
```

---

## Task 12: SQL doğrulaması, uçtan uca manuel test ve günlük

**Files:**
- Create: `supabase/migrations/checks/f4b_rls_checks.sql`
- Modify: `PLAN.md` (Değişiklik Günlüğü)

Bu görev kullanıcıyla birlikte yapılır (veritabanı şifresi yok → Dashboard SQL Editor; düşük bellekli makine → release web build'i kullanıcının terminalinden sunulur). F4a'nın bekleyen 11 maddelik listesiyle aynı oturumda yapılabilir.

- [ ] **Step 1: Kontrol betiğini yaz**

`supabase/migrations/checks/f4b_rls_checks.sql`:

```sql
-- F4b RLS / fonksiyon kontrolleri. SQL Editor'da çalıştır (migration değildir).
-- A = profili olan bir kullanıcı, B = başka bir kullanıcı. Sonuç bilerek HATA
-- olarak basılır; hata tüm değişiklikleri geri aldığı için veritabanında
-- hiçbir şey değişmez.
-- Beklenen: backfill=t B_gorulen_kilo=0 B_gorulen_olcu=0 B_guncellenen=0
--           gecmis_profil=70 yeni_profil=82 silince_profil=80
--           eski_liste_engellendi=t tek_kayit_engellendi=t
do $$
declare
  a uuid;
  b uuid;
  has_backfill boolean;
  b_weights int;
  b_measurements int;
  b_updated int;
  kg_after_past numeric;
  kg_after_new numeric;
  kg_after_delete numeric;
  stale_blocked boolean := false;
  last_blocked boolean := false;
begin
  select p.user_id into a from public.profiles p limit 1;
  select u.id into b from auth.users u where u.id <> a limit 1;
  if a is null or b is null then
    raise exception 'Kontrol için iki kullanıcı gerekli (a=%, b=%)', a, b;
  end if;

  select exists (select 1 from public.body_weight_logs where user_id = a) into has_backfill;

  -- A'yı bilinen bir başlangıca getir (hepsi geri alınacak): tek kayıt 10.01 = 80,
  -- profil kilosu kasıtlı olarak farklı (70) ki güncellenip güncellenmediği görülsün.
  delete from public.body_weight_logs where user_id = a;
  delete from public.body_measurements where user_id = a;
  update public.profiles set weight_kg = 70 where user_id = a;
  insert into public.body_weight_logs (user_id, logged_on, weight_kg) values (a, date '2026-01-10', 80);

  -- A olarak
  perform set_config('request.jwt.claims', json_build_object('sub', a, 'role', 'authenticated')::text, true);
  set local role authenticated;

  insert into public.body_measurements (user_id, measured_on, waist) values (a, date '2026-01-10', 82);

  -- Geçmiş tarihli kayıt profile dokunmaz
  perform public.log_body_weight(date '2026-01-01', 78, 2500, 150);
  select weight_kg into kg_after_past from public.profiles where user_id = a;

  -- En yeni kayıt profili günceller
  perform public.log_body_weight(date '2026-01-20', 82, 3000, 180);
  select weight_kg into kg_after_new from public.profiles where user_id = a;

  -- B olarak: A'nın kayıtlarını göremez, değiştiremez
  perform set_config('request.jwt.claims', json_build_object('sub', b, 'role', 'authenticated')::text, true);
  select count(*) into b_weights from public.body_weight_logs where user_id = a;
  select count(*) into b_measurements from public.body_measurements where user_id = a;
  update public.body_weight_logs set weight_kg = 1 where user_id = a;
  get diagnostics b_updated = row_count;

  -- A olarak
  perform set_config('request.jwt.claims', json_build_object('sub', a, 'role', 'authenticated')::text, true);

  -- En yeniyi silerken yanlış "kalan en yeni" kilo → reddedilir
  begin
    perform public.delete_body_weight(date '2026-01-20', 99, 2600, 160);
  exception when others then
    stale_blocked := sqlerrm like '%stale_weight_list%';
  end;

  -- En yeniyi doğru değerle sil → profil bir önceki kayda (10.01 = 80) döner
  perform public.delete_body_weight(date '2026-01-20', 80, 2600, 160);
  select weight_kg into kg_after_delete from public.profiles where user_id = a;

  -- Eskiyi sil (profile dokunmaz), tek kayıt kalır; o da silinemez
  perform public.delete_body_weight(date '2026-01-01', null, null, null);
  begin
    perform public.delete_body_weight(date '2026-01-10', null, null, null);
  exception when others then
    last_blocked := sqlerrm like '%last_weight_log%';
  end;

  reset role;
  raise exception 'SONUC: backfill=% B_gorulen_kilo=% B_gorulen_olcu=% B_guncellenen=% gecmis_profil=% yeni_profil=% silince_profil=% eski_liste_engellendi=% tek_kayit_engellendi=%',
    has_backfill, b_weights, b_measurements, b_updated, kg_after_past, kg_after_new, kg_after_delete,
    stale_blocked, last_blocked;
end $$;
```

- [ ] **Step 2: Migration ve kontroller (kullanıcı)**

Kullanıcıya: Dashboard → SQL Editor'da `0009_create_body_tracking.sql`'i **bir kez** çalıştırması (PowerShell'de `Get-Content D:\spor_takip\supabase\migrations\0009_create_body_tracking.sql -Raw -Encoding UTF8 | Set-Clipboard`, sonra Editor'a yapıştır → Run). "already exists" hatası alırsa migration zaten uygulanmıştır; tekrar çalıştırmaz. Ardından `f4b_rls_checks.sql`'i aynı yolla çalıştırıp çıkan `SONUC:` satırını paylaşması; değerler betik başındaki "Beklenen" satırıyla karşılaştırılır. Uyuşmayan değer varsa SQL'i düzelt, yeni bir `create or replace function` parçası olarak kullanıcıya ver ve kontrolü tekrarla.

- [ ] **Step 3: Release web build ve manuel kontrol listesi (kullanıcı)**

Run (arka planda, ~15–25 dk): `flutter build web --release --no-pub`
Kullanıcı kendi PowerShell'inde: `cd D:\spor_takip\build\web; python -m http.server 5555 --bind 127.0.0.1` → `http://127.0.0.1:5555` (Ctrl+Shift+R).

Kontrol listesi:
1. Ana sayfa sırasıyla: hedefler, bugünkü antrenman, haftalık özet, vücut ağırlığı, güç ilerlemesi, beden ölçüleri kartları. Pencere telefon genişliğine daraltılınca yatay taşma yok.
2. Kilo kartındaki **+** → bugün için kilo gir → "Yeni kalori hedefin: … kcal" mesajı; hedefler kartındaki kalori değişti; kart yeni kiloyu ve küçük grafiği gösteriyor.
3. Kilo ekranı: aralık seçimi grafiği değiştiriyor; noktaya dokununca tarih ve kilo ipucu. Geçmiş bir tarihe kayıt (tarih seç) → "Kilo kaydedildi", hedef değişmiyor. Kilo ekranındayken kayıt sonrası ana sayfaya **atılmıyor**.
4. Kilo ekranında en yeni kaydı sil → hedefler kartı bir önceki kiloya göre güncellendi. Tek kayıt kalınca silme ikonu pasif.
5. Bir antrenman bitir → ana sayfada haftalık özette antrenman/set/hacim arttı; güç kartında o hareketler ve tahmini 1RM.
6. Güç ekranı: hareket seçici, grafik; noktaya dokununca tarih, "kilo × tekrar" ve "≈ tahmini 1RM".
7. Ölçüm ekle (bel + kol) → kartta son ölçüm tarihi ve çipler; başka bir güne ikinci ölçüm → çiplerde fark (▲/▼); ölçüler ekranında bölge çipleri grafiği değiştiriyor; boş form kaydedilmiyor; bir ölçümü sil.
8. Öğün kaydet → haftalık özette ortalama kalori/protein ve gün sayısı güncellendi. Yeni bir hesapla kayıt + onboarding → kilo kartı onboarding'de girilen kiloyu gösteriyor.

- [ ] **Step 4: PLAN.md ve commit**

`PLAN.md` Değişiklik Günlüğü tablosuna, doğrulama sonuçlarını gerçek bulgularla yansıtan bir satır ekle (tarih, tamamlanan kapsam, bulunan/düzeltilen hatalar, test sayıları).

```bash
git add supabase/migrations/checks/f4b_rls_checks.sql PLAN.md
git commit -m "Document F4b verification and add RLS check script"
```
