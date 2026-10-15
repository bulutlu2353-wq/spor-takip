# N1 Yerel Hatırlatıcılar — Uygulama Planı

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Antrenman, öğün, akşam beslenme özeti ve haftalık hedef için cihazda zamanlanan, ayarlar sayfasından yönetilen yerel hatırlatıcılar.

**Architecture:** Saf bir planlayıcı (`planReminders`) ayarlar + bugünün verisinden önümüzdeki 7 günün bildirim listesini üretir. AppShell'in izlediği `notificationSyncProvider` bu listeyi, bir öncekinden farklıysa `ReminderScheduler.replaceAll` ile kurar. Zamanlayıcı mobilde `flutter_local_notifications`, web'de ve testlerde boş (Noop) uygulamadır. Ayarlar SharedPreferences'ta JSON olarak durur.

**Tech Stack:** Flutter 3.47, flutter_riverpod 3.4.3, go_router, easy_localization, shared_preferences, flutter_local_notifications 22.x, timezone, flutter_timezone 5.x, app_settings 9.x.

**Spec:** `docs/superpowers/specs/2026-10-11-n1-hatirlaticilar-design.md`

## Global Constraints

- Yeni kod `lib/features/notifications/{domain,data,application,presentation}` altında; testler `test/features/notifications/` altında.
- Hepsi varsayılan kapalı (opt-in). Varsayılan saatler: antrenman 18:00, kahvaltı 09:00, öğle 13:00, akşam 19:30, beslenme özeti 21:00, haftalık hedef Cuma 19:00.
- Ufuk: bugün + 6 gün (7 gün). Saati geçmiş bugünkü bildirimler kurulmaz.
- Zamanlama `AndroidScheduleMode.inexactAllowWhileIdle`; tam alarm izni istenmez.
- SharedPreferences anahtarı: `notification_settings_v1`.
- Dokunma rotaları: antrenman ve haftalık hedef `/home`, öğün ve beslenme özeti `/nutrition`.
- Çeviriler üst düzey `notifications.` bölümünde, TR + EN. Ayarlar satırı anahtarları `settings.` bölümünde.
- Düşük bellekli makine: yalnız hedef testler `flutter test --no-pub -j 1 <dosya>` ile. Tam paketi kullanıcı kendi terminalinde çalıştırır.
- Commit mesajları İngilizce, sonunda `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- Bazı dosyalar CRLF satır sonlu (`app_shell.dart`, `router.dart`, `settings_screen.dart`, `main.dart`, `tr.json`, `en.json`, `PLAN.md`). Düzenlemede satır sonu korunur; Python ile düzenleme eşleşmezse Edit aracı kullanılır.

## Plan kararları (spec'ten sapmalar)

1. **Rota `/home/settings/notifications`.** Ayarlar ekranı `/home/settings` altında olduğu için spec'teki `/settings/notifications` bu yola taşınır.
2. **`ReminderScheduler.init` `Future<String?>` döndürür** (uygulama bir bildirimle açıldıysa onun rotası). Arayüze ayrıca `openSystemSettings()` eklenir (izin uyarısındaki düğme). Bunun için `app_settings` paketi eklenir.
3. **Öğün kartında ana anahtar `mealsEnabled`** var; kahvaltı/öğle/akşam anahtarları varsayılan açık, ana anahtar kapalı.
4. **Kalori hedefi `profile.dailyCalorieTarget`**: beslenme ekranı da bunu kullanıyor (uyarlama zaten içinde).
5. **Antrenman günlerinin ilk doldurulması ekranda:** sayfa, kaydedilmemiş günleri `withWorkoutDaysFrom(program)` ile programdan gösterir; ilk kayıtta bu günler ve `workoutDaysInitialized = true` saklanır. Bildirim ayarlar sağlayıcısı programa bağımlı olmaz (çevrimdışı yeniden denemede takılmasın).
6. **Dil:** `notificationSyncProvider` bir `family<void, String>`; AppShell `context.locale.languageCode` ile izler. Dil değişince yeni örnek çalışır ve plan yeniden kurulur. Çeviri `reminderTranslatorProvider` üzerinden (testlerde değiştirilir).
7. **Gün değişimi:** sync, uygulama ön plana dönünce kendini yeniler. Gün değiştiyse önce `todayMealsProvider` ve `todayWorkoutProvider` geçersiz kılınır.
8. **Çıkış:** `notificationBootstrapProvider` `isLoggedInProvider`'ı dinler; true → false geçişinde `cancelAll` çağırır. Sync de oturum yokken `cancelAll` yapar.
9. **Bildirime dokunma:** rota `pendingNotificationRouteProvider`'a yazılır, AppShell onu dinleyip `go` eder. Hem soğuk açılış hem arka plandan dönüş aynı yoldan geçer.
10. **Planlayıcı girdisi `workoutNames: Map<int, String>`** (ISO hafta günü → antrenman adı). Sabit günlüde programın günleri, döngüselde sıradaki antrenman yedi güne birden yazılır. Bugünün toplamları için var olan `MacroTotals` kullanılır.

## Dosya yapısı

| Dosya | Sorumluluk |
|---|---|
| `lib/features/notifications/domain/notification_settings.dart` | `ReminderTime`, `MealReminder`, `NotificationSettings` (JSON, `copyWith`, eşitlik), `defaultWorkoutDays`, `withWorkoutDaysFrom` |
| `lib/features/notifications/domain/planned_reminder.dart` | `ReminderKind`, `PlannedReminder`, `reminderId` |
| `lib/features/notifications/domain/reminder_planner.dart` | `NutritionTargets`, `planReminders` (spec §3.2 kurallarının hepsi) |
| `lib/features/notifications/domain/reminder_inputs.dart` | `programOf`, `workoutNamesByWeekday`, `finishedOn`, `finishedThisWeek` |
| `lib/features/notifications/data/reminder_scheduler.dart` | `ReminderTranslator`, `ReminderScheduler` arayüzü, `NoopReminderScheduler` |
| `lib/features/notifications/data/local_reminder_scheduler.dart` | eklenti uygulaması |
| `lib/features/notifications/data/notification_settings_store.dart` | SharedPreferences okuma/yazma |
| `lib/features/notifications/application/notification_providers.dart` | sağlayıcılar, bootstrap, sync |
| `lib/features/notifications/presentation/notifications_screen.dart` | sayfa |
| Değişen: `pubspec.yaml`, `android/app/build.gradle.kts`, `android/app/src/main/AndroidManifest.xml`, `lib/main.dart`, `lib/core/app_shell.dart`, `lib/core/router.dart`, `lib/features/settings/presentation/settings_screen.dart`, `assets/translations/{tr,en}.json`, `test/core/app_shell_test.dart`, `test/widget_test.dart`, `test/features/settings/presentation/settings_screen_test.dart`, `PLAN.md` | |

---

### Task 1: Paketler ve Android ayarı

**Files:**
- Modify: `pubspec.yaml`
- Modify: `android/app/build.gradle.kts`
- Modify: `android/app/src/main/AndroidManifest.xml`

**Interfaces:**
- Produces: `flutter_local_notifications`, `timezone`, `flutter_timezone`, `app_settings` paketleri kullanılabilir.

- [ ] **Step 1: Paketleri ekle**

Run: `flutter pub add flutter_local_notifications timezone flutter_timezone app_settings`
Expected: `pubspec.yaml`'a dört satır eklenir: `flutter_local_notifications: ^22.x`, `timezone: ^0.x`, `flutter_timezone: ^5.x`, `app_settings: ^9.x`. `pubspec.lock` güncellenir.

- [ ] **Step 2: Desugaring'i aç (`android/app/build.gradle.kts`)**

`compileOptions` bloğunu şöyle yap:

```kotlin
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // flutter_local_notifications için gerekli.
        isCoreLibraryDesugaringEnabled = true
    }
```

Dosyanın sonuna, `flutter { ... }` bloğunun altına ekle:

```kotlin
dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
```

- [ ] **Step 3: Manifest izinleri ve alıcılar (`AndroidManifest.xml`)**

`<manifest ...>` açılışının hemen altına:

```xml
    <uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
    <uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>
```

`<application>` içinde, `flutterEmbedding` meta-data'sının üstüne:

```xml
        <!-- flutter_local_notifications: zamanlanmış bildirimler ve yeniden başlatma sonrası geri yükleme. -->
        <receiver
            android:exported="false"
            android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver" />
        <receiver
            android:exported="false"
            android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver">
            <intent-filter>
                <action android:name="android.intent.action.BOOT_COMPLETED"/>
                <action android:name="android.intent.action.MY_PACKAGE_REPLACED"/>
                <action android:name="android.intent.action.QUICKBOOT_POWERON"/>
                <action android:name="com.htc.intent.action.QUICKBOOT_POWERON"/>
            </intent-filter>
        </receiver>
```

- [ ] **Step 4: Doğrula**

Run: `flutter pub get` ve `flutter analyze`
Expected: ikisi de hatasız. Android derlemesi Task 7'de, kullanıcının telefonunda `flutter run --release` ile doğrulanır.

- [ ] **Step 5: Commit**

```bash
git add pubspec.yaml pubspec.lock android/app/build.gradle.kts android/app/src/main/AndroidManifest.xml
git commit -m "build: add local notification packages and Android setup"
```

---

### Task 2: Bildirim ayarları modeli

**Files:**
- Create: `lib/features/notifications/domain/notification_settings.dart`
- Test: `test/features/notifications/domain/notification_settings_test.dart`

**Interfaces:**
- Consumes: `MealType` (`lib/features/nutrition/domain/meal_type.dart`), `Program`, `ProgramWorkout`, `ScheduleMode`.
- Produces:
  - `class ReminderTime { const ReminderTime(int hour, int minute); int get minutes; String get label; static ReminderTime? fromMinutes(Object?) }`
  - `class MealReminder { bool enabled; ReminderTime time; copyWith }`
  - `const reminderMealTypes = [MealType.breakfast, MealType.lunch, MealType.dinner]`
  - `class NotificationSettings` alanları: `workoutEnabled, workoutDays (Set<int>), workoutTime, workoutDaysInitialized, mealsEnabled, meals (Map<MealType, MealReminder>), nutritionEnabled, nutritionTime, weeklyEnabled, weeklyDay, weeklyTime`; `static const defaults`; `bool get anyEnabled`; `toJson()`; `factory fromJson(Object?)`; `copyWith(...)`; `withWorkoutDaysFrom(Program?)`.
  - `Set<int> defaultWorkoutDays(Program? program)`

- [ ] **Step 1: Başarısız testi yaz**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:spor_takip/features/notifications/domain/notification_settings.dart';
import 'package:spor_takip/features/nutrition/domain/meal_type.dart';
import 'package:spor_takip/features/workout/domain/program.dart';
import 'package:spor_takip/features/workout/domain/program_workout.dart';
import 'package:spor_takip/features/workout/domain/schedule_mode.dart';

Program _program(ScheduleMode mode, List<int?> weekdays) => Program(
      name: 'P',
      scheduleMode: mode,
      workouts: [for (final day in weekdays) ProgramWorkout(name: 'W$day', exercises: const [], weekday: day)],
    );

void main() {
  test('defaults are all off with the spec times', () {
    const s = NotificationSettings.defaults;
    expect(s.anyEnabled, isFalse);
    expect(s.workoutDays, {1, 3, 5});
    expect(s.workoutTime.label, '18:00');
    expect(s.meals[MealType.breakfast]!.time.label, '09:00');
    expect(s.meals[MealType.lunch]!.time.label, '13:00');
    expect(s.meals[MealType.dinner]!.time.label, '19:30');
    expect(reminderMealTypes.every((type) => s.meals[type]!.enabled), isTrue);
    expect(s.nutritionTime.label, '21:00');
    expect(s.weeklyDay, DateTime.friday);
    expect(s.weeklyTime.label, '19:00');
  });

  test('round-trips through JSON', () {
    final s = NotificationSettings.defaults.copyWith(
      workoutEnabled: true,
      workoutDays: {2, 6},
      workoutTime: const ReminderTime(7, 5),
      workoutDaysInitialized: true,
      mealsEnabled: true,
      meals: {
        ...NotificationSettings.defaults.meals,
        MealType.lunch: const MealReminder(enabled: false, time: ReminderTime(12, 15)),
      },
      nutritionEnabled: true,
      nutritionTime: const ReminderTime(22, 0),
      weeklyEnabled: true,
      weeklyDay: DateTime.sunday,
      weeklyTime: const ReminderTime(10, 30),
    );
    expect(NotificationSettings.fromJson(s.toJson()), s);
    expect(NotificationSettings.fromJson(s.toJson()).workoutTime.label, '07:05');
  });

  test('broken data falls back to the defaults field by field', () {
    expect(NotificationSettings.fromJson(null), NotificationSettings.defaults);
    expect(NotificationSettings.fromJson('x'), NotificationSettings.defaults);
    expect(
      NotificationSettings.fromJson({
        'workout': 'x',
        'meals': {'lunch': {'time': 9999}},
        'weekly': {'day': 9},
      }),
      NotificationSettings.defaults,
    );
    final partial = NotificationSettings.fromJson({
      'workout': {'on': true, 'days': [2, 9, 'a']},
    });
    expect(partial.workoutEnabled, isTrue);
    expect(partial.workoutDays, {2});
    expect(partial.workoutTime, NotificationSettings.defaults.workoutTime);
  });

  test('meals count as enabled only with the card switch and one meal on', () {
    final allMealsOff = {
      for (final type in reminderMealTypes) type: NotificationSettings.defaults.meals[type]!.copyWith(enabled: false),
    };
    expect(NotificationSettings.defaults.copyWith(mealsEnabled: true, meals: allMealsOff).anyEnabled, isFalse);
    expect(NotificationSettings.defaults.copyWith(mealsEnabled: true).anyEnabled, isTrue);
    expect(NotificationSettings.defaults.copyWith(weeklyEnabled: true).anyEnabled, isTrue);
  });

  test('default workout days come from a fixed-day program', () {
    expect(defaultWorkoutDays(_program(ScheduleMode.weekdays, [2, 4])), {2, 4});
    expect(defaultWorkoutDays(_program(ScheduleMode.weekdays, [null])), {1, 3, 5});
    expect(defaultWorkoutDays(_program(ScheduleMode.rotation, [null, null])), {1, 3, 5});
    expect(defaultWorkoutDays(null), {1, 3, 5});
  });

  test('workout days are filled from the program only until saved once', () {
    final program = _program(ScheduleMode.weekdays, [2, 4]);
    final filled = NotificationSettings.defaults.withWorkoutDaysFrom(program);
    expect(filled.workoutDays, {2, 4});
    expect(filled.workoutDaysInitialized, isTrue);
    final saved = NotificationSettings.defaults.copyWith(workoutDays: {7}, workoutDaysInitialized: true);
    expect(saved.withWorkoutDaysFrom(program).workoutDays, {7});
  });
}
```

- [ ] **Step 2: Testin başarısız olduğunu gör**

Run: `flutter test --no-pub -j 1 test/features/notifications/domain/notification_settings_test.dart`
Expected: FAIL (dosya yok, derleme hatası).

- [ ] **Step 3: Modeli yaz**

```dart
import 'dart:convert';

import '../../nutrition/domain/meal_type.dart';
import '../../workout/domain/program.dart';
import '../../workout/domain/schedule_mode.dart';

/// Günün yerel saati; JSON'da gün başından dakika olarak saklanır.
class ReminderTime {
  const ReminderTime(this.hour, this.minute);

  final int hour;
  final int minute;

  int get minutes => hour * 60 + minute;

  String get label => '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

  static ReminderTime? fromMinutes(Object? value) {
    if (value is! int || value < 0 || value >= 24 * 60) return null;
    return ReminderTime(value ~/ 60, value % 60);
  }

  @override
  bool operator ==(Object other) => other is ReminderTime && other.hour == hour && other.minute == minute;

  @override
  int get hashCode => Object.hash(hour, minute);
}

class MealReminder {
  const MealReminder({required this.enabled, required this.time});

  final bool enabled;
  final ReminderTime time;

  MealReminder copyWith({bool? enabled, ReminderTime? time}) =>
      MealReminder(enabled: enabled ?? this.enabled, time: time ?? this.time);
}

/// Hatırlatıcısı olan öğün tipleri (ara öğün yok, N1 spec §3.2).
const reminderMealTypes = [MealType.breakfast, MealType.lunch, MealType.dinner];

const _defaultMeals = {
  MealType.breakfast: MealReminder(enabled: true, time: ReminderTime(9, 0)),
  MealType.lunch: MealReminder(enabled: true, time: ReminderTime(13, 0)),
  MealType.dinner: MealReminder(enabled: true, time: ReminderTime(19, 30)),
};

/// Cihazdaki hatırlatıcı ayarları (N1 spec §3.1); hepsi varsayılan kapalı.
class NotificationSettings {
  const NotificationSettings({
    this.workoutEnabled = false,
    this.workoutDays = const {1, 3, 5},
    this.workoutTime = const ReminderTime(18, 0),
    this.workoutDaysInitialized = false,
    this.mealsEnabled = false,
    this.meals = _defaultMeals,
    this.nutritionEnabled = false,
    this.nutritionTime = const ReminderTime(21, 0),
    this.weeklyEnabled = false,
    this.weeklyDay = DateTime.friday,
    this.weeklyTime = const ReminderTime(19, 0),
  });

  static const defaults = NotificationSettings();

  final bool workoutEnabled;

  /// ISO hafta günleri (1=Pzt … 7=Paz).
  final Set<int> workoutDays;
  final ReminderTime workoutTime;

  /// Günler bir kez kaydedildiyse true; o zamana kadar ekran günleri programdan gösterir.
  final bool workoutDaysInitialized;
  final bool mealsEnabled;
  final Map<MealType, MealReminder> meals;
  final bool nutritionEnabled;
  final ReminderTime nutritionTime;
  final bool weeklyEnabled;
  final int weeklyDay;
  final ReminderTime weeklyTime;

  bool get anyEnabled =>
      workoutEnabled ||
      (mealsEnabled && reminderMealTypes.any((type) => meals[type]!.enabled)) ||
      nutritionEnabled ||
      weeklyEnabled;

  Map<String, Object?> toJson() => {
        'workout': {
          'on': workoutEnabled,
          'days': [...workoutDays]..sort(),
          'time': workoutTime.minutes,
          'init': workoutDaysInitialized,
        },
        'meals': {
          'on': mealsEnabled,
          for (final type in reminderMealTypes)
            type.name: {'on': meals[type]!.enabled, 'time': meals[type]!.time.minutes},
        },
        'nutrition': {'on': nutritionEnabled, 'time': nutritionTime.minutes},
        'weekly': {'on': weeklyEnabled, 'day': weeklyDay, 'time': weeklyTime.minutes},
      };

  /// Bozuk ya da eksik alanlar tek tek varsayılana düşer.
  factory NotificationSettings.fromJson(Object? json) {
    const d = defaults;
    Map<String, Object?> section(Object? value) =>
        value is Map ? value.map((key, v) => MapEntry('$key', v)) : const <String, Object?>{};
    bool flag(Map<String, Object?> m, String key, bool fallback) => m[key] is bool ? m[key] as bool : fallback;
    ReminderTime time(Map<String, Object?> m, ReminderTime fallback) => ReminderTime.fromMinutes(m['time']) ?? fallback;

    final root = section(json);
    final workout = section(root['workout']);
    final meals = section(root['meals']);
    final nutrition = section(root['nutrition']);
    final weekly = section(root['weekly']);
    final days = workout['days'];
    final weeklyDay = weekly['day'];
    return NotificationSettings(
      workoutEnabled: flag(workout, 'on', d.workoutEnabled),
      workoutDays: days is List ? {for (final v in days) if (v is int && v >= 1 && v <= 7) v} : d.workoutDays,
      workoutTime: time(workout, d.workoutTime),
      workoutDaysInitialized: flag(workout, 'init', d.workoutDaysInitialized),
      mealsEnabled: flag(meals, 'on', d.mealsEnabled),
      meals: {
        for (final type in reminderMealTypes)
          type: MealReminder(
            enabled: flag(section(meals[type.name]), 'on', d.meals[type]!.enabled),
            time: time(section(meals[type.name]), d.meals[type]!.time),
          ),
      },
      nutritionEnabled: flag(nutrition, 'on', d.nutritionEnabled),
      nutritionTime: time(nutrition, d.nutritionTime),
      weeklyEnabled: flag(weekly, 'on', d.weeklyEnabled),
      weeklyDay: weeklyDay is int && weeklyDay >= 1 && weeklyDay <= 7 ? weeklyDay : d.weeklyDay,
      weeklyTime: time(weekly, d.weeklyTime),
    );
  }

  NotificationSettings copyWith({
    bool? workoutEnabled,
    Set<int>? workoutDays,
    ReminderTime? workoutTime,
    bool? workoutDaysInitialized,
    bool? mealsEnabled,
    Map<MealType, MealReminder>? meals,
    bool? nutritionEnabled,
    ReminderTime? nutritionTime,
    bool? weeklyEnabled,
    int? weeklyDay,
    ReminderTime? weeklyTime,
  }) {
    return NotificationSettings(
      workoutEnabled: workoutEnabled ?? this.workoutEnabled,
      workoutDays: workoutDays ?? this.workoutDays,
      workoutTime: workoutTime ?? this.workoutTime,
      workoutDaysInitialized: workoutDaysInitialized ?? this.workoutDaysInitialized,
      mealsEnabled: mealsEnabled ?? this.mealsEnabled,
      meals: meals ?? this.meals,
      nutritionEnabled: nutritionEnabled ?? this.nutritionEnabled,
      nutritionTime: nutritionTime ?? this.nutritionTime,
      weeklyEnabled: weeklyEnabled ?? this.weeklyEnabled,
      weeklyDay: weeklyDay ?? this.weeklyDay,
      weeklyTime: weeklyTime ?? this.weeklyTime,
    );
  }

  /// Günler hiç kaydedilmediyse programdan doldurulmuş kopya (N1 spec §3.1).
  NotificationSettings withWorkoutDaysFrom(Program? program) => workoutDaysInitialized
      ? this
      : copyWith(workoutDays: defaultWorkoutDays(program), workoutDaysInitialized: true);

  // JSON biçimi sıralı ve tam olduğu için eşitlik onun üzerinden.
  @override
  bool operator ==(Object other) =>
      other is NotificationSettings && jsonEncode(other.toJson()) == jsonEncode(toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;
}

/// Sabit günlü programda programın günleri, aksi halde Pzt/Çar/Cum.
Set<int> defaultWorkoutDays(Program? program) {
  if (program != null && program.scheduleMode == ScheduleMode.weekdays) {
    final days = {for (final workout in program.workouts) ?workout.weekday};
    if (days.isNotEmpty) return days;
  }
  return const {1, 3, 5};
}
```

- [ ] **Step 4: Testin geçtiğini gör**

Run: `flutter test --no-pub -j 1 test/features/notifications/domain/notification_settings_test.dart`
Expected: PASS (6 test).

- [ ] **Step 5: Commit**

```bash
git add lib/features/notifications/domain/notification_settings.dart test/features/notifications/domain/notification_settings_test.dart
git commit -m "feat(notifications): add the reminder settings model"
```

---

### Task 3: Planlayıcı ve girdi yardımcıları

**Files:**
- Create: `lib/features/notifications/domain/planned_reminder.dart`
- Create: `lib/features/notifications/domain/reminder_planner.dart`
- Create: `lib/features/notifications/domain/reminder_inputs.dart`
- Test: `test/features/notifications/domain/reminder_planner_test.dart`
- Test: `test/features/notifications/domain/reminder_inputs_test.dart`

**Interfaces:**
- Consumes: Task 2'deki `NotificationSettings`, `ReminderTime`, `reminderMealTypes`. Ayrıca `MacroTotals` (`nutrition/domain/macro_totals.dart`), `TodayWorkout` ailesi (`workout/domain/today_workout.dart`), `WorkoutSession`, `startOfWeek` (`progress/domain/weekly_summary.dart`).
- Produces:
  - `enum ReminderKind { workout, meal, nutrition, weekly }`
  - `int reminderId(ReminderKind kind, DateTime day, [MealType? mealType])`
  - `class PlannedReminder { int id; ReminderKind kind; DateTime at; String titleKey; String bodyKey; Map<String, String> args; String route; }` (değer eşitliği; `toString` deterministik)
  - `class NutritionTargets { const NutritionTargets({required double calories, required double proteinG}) }`
  - `const reminderHorizonDays = 7`
  - `List<PlannedReminder> planReminders({required NotificationSettings settings, required DateTime now, Map<int, String> workoutNames = const {}, bool workoutDoneToday = false, Set<MealType> mealTypesToday = const {}, MacroTotals nutritionToday = const MacroTotals(), NutritionTargets? targets, int? weeklyGoal, int weeklyDone = 0})`
  - `Program? programOf(TodayWorkout today)`, `Map<int, String> workoutNamesByWeekday(TodayWorkout today)`, `bool finishedOn(List<WorkoutSession> sessions, DateTime day)`, `int finishedThisWeek(List<WorkoutSession> sessions, DateTime now)`

- [ ] **Step 1: Planlayıcı testlerini yaz (`reminder_planner_test.dart`)**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:spor_takip/features/notifications/domain/notification_settings.dart';
import 'package:spor_takip/features/notifications/domain/planned_reminder.dart';
import 'package:spor_takip/features/notifications/domain/reminder_planner.dart';
import 'package:spor_takip/features/nutrition/domain/macro_totals.dart';
import 'package:spor_takip/features/nutrition/domain/meal_type.dart';

// Pazartesi öğlen.
final _now = DateTime(2026, 10, 12, 12);
const _off = NotificationSettings.defaults;
const _targets = NutritionTargets(calories: 2700, proteinG: 176);

List<PlannedReminder> _plan(
  NotificationSettings settings, {
  DateTime? now,
  Map<int, String> workoutNames = const {},
  bool workoutDoneToday = false,
  Set<MealType> mealTypesToday = const {},
  MacroTotals nutritionToday = const MacroTotals(),
  NutritionTargets? targets = _targets,
  int? weeklyGoal,
  int weeklyDone = 0,
}) =>
    planReminders(
      settings: settings,
      now: now ?? _now,
      workoutNames: workoutNames,
      workoutDoneToday: workoutDoneToday,
      mealTypesToday: mealTypesToday,
      nutritionToday: nutritionToday,
      targets: targets,
      weeklyGoal: weeklyGoal,
      weeklyDone: weeklyDone,
    );

List<DateTime> _times(List<PlannedReminder> plan) => [for (final r in plan) r.at];

void main() {
  test('the fixture day is a Monday', () => expect(_now.weekday, DateTime.monday));

  test('nothing is planned while every card is off', () {
    expect(_plan(_off), isEmpty);
  });

  group('workout', () {
    final on = _off.copyWith(workoutEnabled: true);

    test('lands on the chosen days within seven days', () {
      final plan = _plan(on);
      expect(_times(plan), [DateTime(2026, 10, 12, 18), DateTime(2026, 10, 14, 18), DateTime(2026, 10, 16, 18)]);
      expect(plan.every((r) => r.kind == ReminderKind.workout && r.route == '/home'), isTrue);
      expect(plan.first.titleKey, 'notifications.workout_title');
    });

    test('skips today when the time has passed or a workout is done', () {
      final early = on.copyWith(workoutTime: const ReminderTime(9, 0));
      expect(_times(_plan(early)), [DateTime(2026, 10, 14, 9), DateTime(2026, 10, 16, 9)]);
      expect(_times(_plan(on, workoutDoneToday: true)), [DateTime(2026, 10, 14, 18), DateTime(2026, 10, 16, 18)]);
    });

    test('names the workout when the day has one', () {
      final plan = _plan(on, workoutNames: {DateTime.monday: 'Push A'});
      expect(plan[0].bodyKey, 'notifications.workout_body_named');
      expect(plan[0].args, {'name': 'Push A'});
      expect(plan[1].bodyKey, 'notifications.workout_body');
      expect(plan[1].args, isEmpty);
    });
  });

  group('meals', () {
    final on = _off.copyWith(mealsEnabled: true);

    test('skips today for logged meal types and passed times', () {
      final plan = _plan(on, mealTypesToday: {MealType.lunch});
      final today = plan.where((r) => r.at.day == 12).toList();
      expect(today, hasLength(1));
      expect(today.single.titleKey, 'notifications.meal_title_dinner');
      expect(today.single.route, '/nutrition');
      expect(today.single.bodyKey, 'notifications.meal_body');
      expect(plan, hasLength(1 + 6 * 3));
    });

    test('respects the per-meal and card switches', () {
      final noLunch = on.copyWith(meals: {..._off.meals, MealType.lunch: _off.meals[MealType.lunch]!.copyWith(enabled: false)});
      expect(_plan(noLunch).where((r) => r.titleKey == 'notifications.meal_title_lunch'), isEmpty);
      expect(_plan(_off.copyWith(mealsEnabled: false)), isEmpty);
    });
  });

  group('nutrition summary', () {
    final on = _off.copyWith(nutritionEnabled: true);
    PlannedReminder? today(List<PlannedReminder> plan) => plan.where((r) => r.at.day == 12).firstOrNull;

    test('reminds every day; future days say no meal yet', () {
      final plan = _plan(on);
      expect(plan, hasLength(7));
      expect(plan.every((r) => r.bodyKey == 'notifications.nutrition_none'), isTrue);
      expect(plan.first.at, DateTime(2026, 10, 12, 21));
      expect(plan.first.titleKey, 'notifications.nutrition_title');
    });

    test('protein comes before calories', () {
      final plan = _plan(on,
          mealTypesToday: {MealType.lunch}, nutritionToday: const MacroTotals(calories: 1500, proteinG: 100.4));
      expect(today(plan)!.bodyKey, 'notifications.nutrition_protein');
      expect(today(plan)!.args, {'g': '76'});
    });

    test('calories when protein is met', () {
      final plan = _plan(on,
          mealTypesToday: {MealType.lunch}, nutritionToday: const MacroTotals(calories: 2000, proteinG: 180));
      expect(today(plan)!.bodyKey, 'notifications.nutrition_kcal');
      expect(today(plan)!.args, {'kcal': '700'});
    });

    test('nothing today when both are met or there is no profile', () {
      final met = _plan(on,
          mealTypesToday: {MealType.lunch}, nutritionToday: const MacroTotals(calories: 2800, proteinG: 180));
      expect(today(met), isNull);
      expect(met, hasLength(6));
      expect(today(_plan(on, mealTypesToday: {MealType.lunch}, targets: null)), isNull);
      expect(today(_plan(on, targets: null))!.bodyKey, 'notifications.nutrition_none');
    });
  });

  group('weekly goal', () {
    final on = _off.copyWith(weeklyEnabled: true);

    test('reminds on the chosen day of this week with the remaining days', () {
      final plan = _plan(on, weeklyGoal: 4, weeklyDone: 1);
      expect(plan, hasLength(1));
      expect(plan.single.at, DateTime(2026, 10, 16, 19));
      expect(plan.single.bodyKey, 'notifications.weekly_body');
      expect(plan.single.args, {'done': '1', 'goal': '4', 'left': '3'});
      expect(plan.single.route, '/home');
    });

    test('nothing when the goal is met or unknown', () {
      expect(_plan(on, weeklyGoal: 4, weeklyDone: 4), isEmpty);
      expect(_plan(on, weeklyGoal: null), isEmpty);
    });

    test('only this ISO week counts', () {
      final monday = on.copyWith(weeklyDay: DateTime.monday);
      expect(_plan(monday, weeklyGoal: 3).single.args['left'], '7');
      expect(_plan(monday, weeklyGoal: 3, now: DateTime(2026, 10, 13, 12)), isEmpty);
    });
  });

  test('ids are unique, stable per day and the plan is sorted by time', () {
    final all = _off.copyWith(workoutEnabled: true, mealsEnabled: true, nutritionEnabled: true, weeklyEnabled: true);
    final plan = _plan(all, weeklyGoal: 3);
    expect({for (final r in plan) r.id}, hasLength(plan.length));
    expect(_times(plan), [..._times(plan)]..sort());
    expect(reminderId(ReminderKind.workout, DateTime(2026, 10, 12)),
        reminderId(ReminderKind.workout, DateTime(2026, 10, 12, 23, 59)));
    expect(reminderId(ReminderKind.meal, DateTime(2026, 10, 12), MealType.lunch),
        isNot(reminderId(ReminderKind.meal, DateTime(2026, 10, 12), MealType.dinner)));
    expect(plan.every((r) => r.id > 0 && r.id < 1 << 31), isTrue);
    expect(_plan(all, weeklyGoal: 3), plan);
  });
}
```

- [ ] **Step 2: Girdi yardımcıları testini yaz (`reminder_inputs_test.dart`)**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:spor_takip/features/notifications/domain/reminder_inputs.dart';
import 'package:spor_takip/features/workout/domain/program.dart';
import 'package:spor_takip/features/workout/domain/program_workout.dart';
import 'package:spor_takip/features/workout/domain/schedule_mode.dart';
import 'package:spor_takip/features/workout/domain/today_workout.dart';

import '../../gamification/game_fixtures.dart';

const _push = ProgramWorkout(name: 'Push', exercises: [], weekday: 1);
const _pull = ProgramWorkout(name: 'Pull', exercises: [], weekday: 4);
const _fixed = Program(name: 'Fixed', scheduleMode: ScheduleMode.weekdays, workouts: [_push, _pull]);
const _rotation = Program(
  name: 'Rot',
  scheduleMode: ScheduleMode.rotation,
  workouts: [ProgramWorkout(name: 'A', exercises: []), ProgramWorkout(name: 'B', exercises: [])],
);

void main() {
  test('programOf unwraps every state', () {
    expect(programOf(const NoActiveProgram()), isNull);
    expect(programOf(const RestDay(_fixed)), _fixed);
    expect(programOf(const EmptyProgram(_fixed)), _fixed);
    expect(programOf(const ScheduledWorkout(_fixed, 0, _push)), _fixed);
  });

  test('fixed-day programs name their days, rotations name the next workout every day', () {
    expect(workoutNamesByWeekday(const RestDay(_fixed)), {1: 'Push', 4: 'Pull'});
    expect(
      workoutNamesByWeekday(ScheduledWorkout(_rotation, 1, _rotation.workouts[1])),
      {for (var d = 1; d <= 7; d++) d: 'B'},
    );
    expect(workoutNamesByWeekday(const EmptyProgram(_rotation)), isEmpty);
    expect(workoutNamesByWeekday(const NoActiveProgram()), isEmpty);
  });

  test('finished sessions are counted by local day and ISO week', () {
    final sessions = [
      gameSession('sun', DateTime(2026, 10, 11, 20), const []),
      gameSession('mon', DateTime(2026, 10, 12, 8), const []),
      gameSession('open', null, const []),
    ];
    final now = DateTime(2026, 10, 12, 12);
    expect(finishedOn(sessions, now), isTrue);
    expect(finishedOn(sessions, DateTime(2026, 10, 13)), isFalse);
    expect(finishedThisWeek(sessions, now), 1);
    expect(finishedThisWeek(sessions, DateTime(2026, 10, 11, 23)), 1);
  });
}
```

Not: `gameSession(id, finishedAt, sets)` imzası `test/features/gamification/game_fixtures.dart:26`'da. `Program`/`ProgramWorkout` kurucularının `const` olup olmadığını kontrol et; değilse `const` yerine `final` kullan.

- [ ] **Step 3: Testlerin başarısız olduğunu gör**

Run: `flutter test --no-pub -j 1 test/features/notifications/domain/reminder_planner_test.dart test/features/notifications/domain/reminder_inputs_test.dart`
Expected: FAIL (dosyalar yok).

- [ ] **Step 4: `planned_reminder.dart`**

```dart
import 'package:flutter/foundation.dart';

import '../../nutrition/domain/meal_type.dart';

enum ReminderKind { workout, meal, nutrition, weekly }

/// Gün + tür (+ öğün) başına sabit, 32 bit'e sığan bildirim kimliği.
int reminderId(ReminderKind kind, DateTime day, [MealType? mealType]) {
  final dayNumber = DateTime.utc(day.year, day.month, day.day).difference(DateTime.utc(1970)).inDays;
  final slot = kind.index * 10 + (mealType?.index ?? 0);
  return (dayNumber % 10000) * 100 + slot + 1;
}

/// Kurulacak tek bildirim; metinler zamanlama anında çevrilir.
class PlannedReminder {
  const PlannedReminder({
    required this.id,
    required this.kind,
    required this.at,
    required this.titleKey,
    required this.bodyKey,
    required this.route,
    this.args = const {},
  });

  final int id;
  final ReminderKind kind;

  /// Yerel saat.
  final DateTime at;
  final String titleKey;
  final String bodyKey;
  final Map<String, String> args;

  /// Dokununca açılacak rota.
  final String route;

  @override
  bool operator ==(Object other) =>
      other is PlannedReminder &&
      other.id == id &&
      other.kind == kind &&
      other.at == at &&
      other.titleKey == titleKey &&
      other.bodyKey == bodyKey &&
      other.route == route &&
      mapEquals(other.args, args);

  @override
  int get hashCode => Object.hash(id, kind, at, titleKey, bodyKey, route, Object.hashAllUnordered(args.entries.map((e) => '${e.key}=${e.value}')));

  @override
  String toString() => 'PlannedReminder($id, ${kind.name}, ${at.toIso8601String()}, $titleKey, $bodyKey, $args, $route)';
}
```

(`+ 1`: kimlik 0 olmasın; testteki `r.id > 0` bunu doğrular.)

- [ ] **Step 5: `reminder_planner.dart`**

```dart
import '../../nutrition/domain/macro_totals.dart';
import '../../nutrition/domain/meal_type.dart';
import 'notification_settings.dart';
import 'planned_reminder.dart';

class NutritionTargets {
  const NutritionTargets({required this.calories, required this.proteinG});

  final double calories;
  final double proteinG;
}

/// Bugün + 6 gün.
const reminderHorizonDays = 7;

/// Ayarlar ve bugünün verisinden kurulacak bildirimler (N1 spec §3.2), zamana göre sıralı.
/// [workoutNames]: ISO hafta günü → antrenman adı. [mealTypesToday]: bugün kaydedilen öğün
/// tipleri (ara öğün dahil). [targets] null ise profil yok. [weeklyGoal] null ise hedef yok.
List<PlannedReminder> planReminders({
  required NotificationSettings settings,
  required DateTime now,
  Map<int, String> workoutNames = const {},
  bool workoutDoneToday = false,
  Set<MealType> mealTypesToday = const {},
  MacroTotals nutritionToday = const MacroTotals(),
  NutritionTargets? targets,
  int? weeklyGoal,
  int weeklyDone = 0,
}) {
  final plan = <PlannedReminder>[];
  void add(
    ReminderKind kind,
    DateTime day,
    ReminderTime time, {
    required String titleKey,
    required String bodyKey,
    required String route,
    MealType? mealType,
    Map<String, String> args = const {},
  }) {
    final at = DateTime(day.year, day.month, day.day, time.hour, time.minute);
    if (!at.isAfter(now)) return;
    plan.add(PlannedReminder(
      id: reminderId(kind, day, mealType),
      kind: kind,
      at: at,
      titleKey: titleKey,
      bodyKey: bodyKey,
      route: route,
      args: args,
    ));
  }

  for (var offset = 0; offset < reminderHorizonDays; offset++) {
    final day = DateTime(now.year, now.month, now.day + offset);
    final isToday = offset == 0;

    if (settings.workoutEnabled && settings.workoutDays.contains(day.weekday) && !(isToday && workoutDoneToday)) {
      final name = workoutNames[day.weekday];
      add(
        ReminderKind.workout,
        day,
        settings.workoutTime,
        titleKey: 'notifications.workout_title',
        bodyKey: name == null ? 'notifications.workout_body' : 'notifications.workout_body_named',
        route: '/home',
        args: {'name': ?name},
      );
    }

    if (settings.mealsEnabled) {
      for (final type in reminderMealTypes) {
        final meal = settings.meals[type]!;
        if (!meal.enabled || (isToday && mealTypesToday.contains(type))) continue;
        add(
          ReminderKind.meal,
          day,
          meal.time,
          titleKey: 'notifications.meal_title_${type.name}',
          bodyKey: 'notifications.meal_body',
          route: '/nutrition',
          mealType: type,
        );
      }
    }

    if (settings.nutritionEnabled) {
      final body = isToday
          ? _nutritionBody(mealTypesToday, nutritionToday, targets)
          : ('notifications.nutrition_none', const <String, String>{});
      if (body != null) {
        add(
          ReminderKind.nutrition,
          day,
          settings.nutritionTime,
          titleKey: 'notifications.nutrition_title',
          bodyKey: body.$1,
          route: '/nutrition',
          args: body.$2,
        );
      }
    }

    final sameWeek = offset <= DateTime.sunday - now.weekday;
    if (settings.weeklyEnabled &&
        sameWeek &&
        day.weekday == settings.weeklyDay &&
        weeklyGoal != null &&
        weeklyGoal > 0 &&
        weeklyDone < weeklyGoal) {
      add(
        ReminderKind.weekly,
        day,
        settings.weeklyTime,
        titleKey: 'notifications.weekly_title',
        bodyKey: 'notifications.weekly_body',
        route: '/home',
        args: {'done': '$weeklyDone', 'goal': '$weeklyGoal', 'left': '${DateTime.sunday - day.weekday + 1}'},
      );
    }
  }
  plan.sort((a, b) {
    final byTime = a.at.compareTo(b.at);
    return byTime != 0 ? byTime : a.id.compareTo(b.id);
  });
  return plan;
}

/// Bugünkü özetin metni; null ise bugün kurulmaz.
(String, Map<String, String>)? _nutritionBody(Set<MealType> mealTypes, MacroTotals totals, NutritionTargets? targets) {
  if (mealTypes.isEmpty) return ('notifications.nutrition_none', const {});
  if (targets == null) return null;
  final protein = (targets.proteinG - totals.proteinG).round();
  if (protein > 0) return ('notifications.nutrition_protein', {'g': '$protein'});
  final kcal = (targets.calories - totals.calories).round();
  if (kcal > 0) return ('notifications.nutrition_kcal', {'kcal': '$kcal'});
  return null;
}
```

(`{'name': ?name}` null-farkında harita girdisi; Dart 3.8+ ile derlenir, proje SDK'sı `^3.13.3`.)

- [ ] **Step 6: `reminder_inputs.dart`**

```dart
import '../../progress/domain/weekly_summary.dart';
import '../../workout/domain/program.dart';
import '../../workout/domain/schedule_mode.dart';
import '../../workout/domain/today_workout.dart';
import '../../workout/domain/workout_session.dart';

Program? programOf(TodayWorkout today) => switch (today) {
      NoActiveProgram() => null,
      EmptyProgram(:final program) => program,
      RestDay(:final program) => program,
      ScheduledWorkout(:final program) => program,
    };

/// ISO hafta günü → antrenman adı (N1 spec §3.2): sabit günlüde programın günleri,
/// döngüselde sıradaki antrenman her gün.
Map<int, String> workoutNamesByWeekday(TodayWorkout today) {
  final program = programOf(today);
  if (program == null) return const {};
  switch (program.scheduleMode) {
    case ScheduleMode.weekdays:
      return {
        for (final workout in program.workouts)
          if (workout.weekday case final weekday?) weekday: workout.name,
      };
    case ScheduleMode.rotation:
      if (today is! ScheduledWorkout) return const {};
      return {for (var day = DateTime.monday; day <= DateTime.sunday; day++) day: today.workout.name};
  }
}

bool _sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

/// O (yerel) gün bitmiş bir oturum var mı.
bool finishedOn(List<WorkoutSession> sessions, DateTime day) =>
    sessions.any((s) => s.finishedAt != null && _sameDay(s.finishedAt!.toLocal(), day));

/// Bu ISO haftada [now]'a kadar bitmiş oturum sayısı.
int finishedThisWeek(List<WorkoutSession> sessions, DateTime now) {
  final start = startOfWeek(now);
  return sessions.where((s) {
    final finished = s.finishedAt?.toLocal();
    return finished != null && !finished.isBefore(start) && !finished.isAfter(now);
  }).length;
}
```

- [ ] **Step 7: Testlerin geçtiğini gör**

Run: `flutter test --no-pub -j 1 test/features/notifications/domain/reminder_planner_test.dart test/features/notifications/domain/reminder_inputs_test.dart`
Expected: PASS.

- [ ] **Step 8: Commit**

```bash
git add lib/features/notifications/domain test/features/notifications/domain
git commit -m "feat(notifications): plan the week's reminders from settings and today's data"
```

---

### Task 4: Zamanlayıcı ve ayar deposu

**Files:**
- Create: `lib/features/notifications/data/reminder_scheduler.dart`
- Create: `lib/features/notifications/data/local_reminder_scheduler.dart`
- Create: `lib/features/notifications/data/notification_settings_store.dart`
- Test: `test/features/notifications/data/notification_settings_store_test.dart`
- Create (test yardımcısı): `test/features/notifications/fakes.dart`

**Interfaces:**
- Consumes: `PlannedReminder` (Task 3), `NotificationSettings` (Task 2).
- Produces:
  - `typedef ReminderTranslator = String Function(String key, Map<String, String> args);`
  - `abstract interface class ReminderScheduler { Future<String?> init(void Function(String route) onTap); Future<bool> hasPermission(); Future<bool> requestPermission(); Future<void> openSystemSettings(); Future<void> replaceAll(List<PlannedReminder> plan, ReminderTranslator tr); Future<void> cancelAll(); }`
  - `class NoopReminderScheduler implements ReminderScheduler` (`const` kurucu)
  - `class LocalReminderScheduler implements ReminderScheduler { static final instance; }`
  - `const notificationSettingsKey = 'notification_settings_v1'`; `class NotificationSettingsStore { const; Future<NotificationSettings> load(); Future<void> save(NotificationSettings) }`
  - Test: `FakeReminderScheduler` (alanlar: `permission`, `requestResult`, `launchRoute`, `onTap`, `replaced`, `translated`, `cancels`, `permissionRequests`, `settingsOpened`)

- [ ] **Step 1: Depo testini yaz**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spor_takip/features/notifications/data/notification_settings_store.dart';
import 'package:spor_takip/features/notifications/domain/notification_settings.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('missing settings load as the defaults', () async {
    expect(await const NotificationSettingsStore().load(), NotificationSettings.defaults);
  });

  test('saved settings load back', () async {
    final settings = NotificationSettings.defaults.copyWith(nutritionEnabled: true, nutritionTime: const ReminderTime(20, 15));
    await const NotificationSettingsStore().save(settings);
    expect(await const NotificationSettingsStore().load(), settings);
  });

  test('unreadable data loads as the defaults', () async {
    SharedPreferences.setMockInitialValues({notificationSettingsKey: 'not json'});
    expect(await const NotificationSettingsStore().load(), NotificationSettings.defaults);
  });
}
```

- [ ] **Step 2: Testin başarısız olduğunu gör**

Run: `flutter test --no-pub -j 1 test/features/notifications/data/notification_settings_store_test.dart`
Expected: FAIL.

- [ ] **Step 3: `reminder_scheduler.dart`**

```dart
import '../domain/planned_reminder.dart';

typedef ReminderTranslator = String Function(String key, Map<String, String> args);

/// Bildirim zamanlayıcısı (N1 spec §4.2). Mobilde `LocalReminderScheduler`, web'de Noop.
abstract interface class ReminderScheduler {
  /// Eklentiyi kurar; dokunulan bildirimin rotası [onTap]'e gelir. Uygulama bir
  /// bildirimle açıldıysa o bildirimin rotasını döndürür.
  Future<String?> init(void Function(String route) onTap);

  Future<bool> hasPermission();

  Future<bool> requestPermission();

  /// Uygulamanın sistem bildirim ayarlarını açar.
  Future<void> openSystemSettings();

  /// Bekleyen her şeyi iptal edip [plan]'ı kurar; metinler [tr] ile çevrilir.
  Future<void> replaceAll(List<PlannedReminder> plan, ReminderTranslator tr);

  Future<void> cancelAll();
}

/// Web için: hiçbir şey zamanlamaz.
class NoopReminderScheduler implements ReminderScheduler {
  const NoopReminderScheduler();

  @override
  Future<String?> init(void Function(String route) onTap) async => null;

  @override
  Future<bool> hasPermission() async => false;

  @override
  Future<bool> requestPermission() async => false;

  @override
  Future<void> openSystemSettings() async {}

  @override
  Future<void> replaceAll(List<PlannedReminder> plan, ReminderTranslator tr) async {}

  @override
  Future<void> cancelAll() async {}
}
```

- [ ] **Step 4: `notification_settings_store.dart`**

```dart
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/notification_settings.dart';

const notificationSettingsKey = 'notification_settings_v1';

/// Ayarlar cihazda (N1 spec §2.3); okunamazsa varsayılanlar.
class NotificationSettingsStore {
  const NotificationSettingsStore();

  Future<NotificationSettings> load() async {
    try {
      final raw = (await SharedPreferences.getInstance()).getString(notificationSettingsKey);
      return raw == null ? NotificationSettings.defaults : NotificationSettings.fromJson(jsonDecode(raw));
    } catch (e) {
      debugPrint('notification settings load failed: $e');
      return NotificationSettings.defaults;
    }
  }

  Future<void> save(NotificationSettings settings) async {
    try {
      await (await SharedPreferences.getInstance()).setString(notificationSettingsKey, jsonEncode(settings.toJson()));
    } catch (e) {
      debugPrint('notification settings save failed: $e');
    }
  }
}
```

- [ ] **Step 5: `local_reminder_scheduler.dart`**

Önce kurulu sürümlerin API'sini doğrula: `flutter pub deps --style=compact | grep -E "flutter_local_notifications|flutter_timezone|app_settings|timezone"`. Bu plan şu imzalara göre yazıldı: `flutter_local_notifications` 22.x'te `initialize({required InitializationSettings settings, onDidReceiveNotificationResponse})` ve `zonedSchedule({required int id, required TZDateTime scheduledDate, required NotificationDetails notificationDetails, required AndroidScheduleMode androidScheduleMode, String? title, String? body, String? payload})`. `flutter_timezone` 5.x'te `getLocalTimezone()` → `TimezoneInfo` (`.identifier`). `app_settings` 9.x'te `AppSettings.openAppSettings(type: AppSettingsType.notification)`. Pub önbelleğindeki kaynakta farklıysa çağrıyı kurulu sürüme uydur; davranış aynı kalsın.

```dart
import 'dart:async';

import 'package:app_settings/app_settings.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../domain/planned_reminder.dart';
import 'reminder_scheduler.dart';

/// `flutter_local_notifications` ile yerel zamanlama (N1 spec §4.2). `init` bitmeden
/// gelen çağrılar onu bekler.
class LocalReminderScheduler implements ReminderScheduler {
  LocalReminderScheduler._();

  static final instance = LocalReminderScheduler._();

  static const _channelId = 'reminders';

  final _plugin = FlutterLocalNotificationsPlugin();
  final _ready = Completer<void>();

  AndroidFlutterLocalNotificationsPlugin? get _android =>
      _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

  @override
  Future<String?> init(void Function(String route) onTap) async {
    try {
      tz_data.initializeTimeZones();
      try {
        final zone = await FlutterTimezone.getLocalTimezone();
        tz.setLocalLocation(tz.getLocation(zone.identifier));
      } catch (e) {
        debugPrint('local time zone unavailable, using UTC: $e');
      }
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
        ),
        onDidReceiveNotificationResponse: (response) {
          final route = response.payload;
          if (route != null && route.isNotEmpty) onTap(route);
        },
      );
      final launch = await _plugin.getNotificationAppLaunchDetails();
      final route = launch?.notificationResponse?.payload;
      return launch?.didNotificationLaunchApp == true && route != null && route.isNotEmpty ? route : null;
    } finally {
      if (!_ready.isCompleted) _ready.complete();
    }
  }

  @override
  Future<bool> hasPermission() async {
    await _ready.future;
    return await _android?.areNotificationsEnabled() ?? false;
  }

  @override
  Future<bool> requestPermission() async {
    await _ready.future;
    final android = _android;
    if (android != null) return await android.requestNotificationsPermission() ?? false;
    final ios = _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
    return await ios?.requestPermissions(alert: true, badge: true, sound: true) ?? false;
  }

  @override
  Future<void> openSystemSettings() => AppSettings.openAppSettings(type: AppSettingsType.notification);

  @override
  Future<void> replaceAll(List<PlannedReminder> plan, ReminderTranslator tr) async {
    await _ready.future;
    await _plugin.cancelAll();
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        tr('notifications.channel_name', const {}),
        channelDescription: tr('notifications.channel_desc', const {}),
      ),
      iOS: const DarwinNotificationDetails(),
    );
    for (final reminder in plan) {
      final at = reminder.at;
      await _plugin.zonedSchedule(
        id: reminder.id,
        title: tr(reminder.titleKey, reminder.args),
        body: tr(reminder.bodyKey, reminder.args),
        scheduledDate: tz.TZDateTime(tz.local, at.year, at.month, at.day, at.hour, at.minute),
        notificationDetails: details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: reminder.route,
      );
    }
  }

  @override
  Future<void> cancelAll() async {
    await _ready.future;
    await _plugin.cancelAll();
  }
}
```

- [ ] **Step 6: Test sahtesi (`test/features/notifications/fakes.dart`)**

```dart
import 'package:spor_takip/features/notifications/data/reminder_scheduler.dart';
import 'package:spor_takip/features/notifications/domain/planned_reminder.dart';

class FakeReminderScheduler implements ReminderScheduler {
  FakeReminderScheduler({this.permission = true, this.requestResult = true, this.launchRoute});

  bool permission;
  bool requestResult;
  String? launchRoute;
  void Function(String route)? onTap;
  final replaced = <List<PlannedReminder>>[];
  final translated = <List<String>>[];
  int cancels = 0;
  int permissionRequests = 0;
  int settingsOpened = 0;

  @override
  Future<String?> init(void Function(String route) onTap) async {
    this.onTap = onTap;
    return launchRoute;
  }

  @override
  Future<bool> hasPermission() async => permission;

  @override
  Future<bool> requestPermission() async {
    permissionRequests++;
    permission = requestResult;
    return requestResult;
  }

  @override
  Future<void> openSystemSettings() async => settingsOpened++;

  @override
  Future<void> replaceAll(List<PlannedReminder> plan, ReminderTranslator tr) async {
    replaced.add(plan);
    translated.add([for (final r in plan) tr(r.bodyKey, r.args)]);
  }

  @override
  Future<void> cancelAll() async => cancels++;
}
```

- [ ] **Step 7: Doğrula**

Run: `flutter test --no-pub -j 1 test/features/notifications/data/notification_settings_store_test.dart` ve `flutter analyze lib/features/notifications test/features/notifications`
Expected: PASS (3 test); analiz temiz.

- [ ] **Step 8: Commit**

```bash
git add lib/features/notifications/data test/features/notifications/data test/features/notifications/fakes.dart
git commit -m "feat(notifications): add the local scheduler and the settings store"
```

---

### Task 5: Sağlayıcılar, senkron, AppShell ve uygulama kurulumu

**Files:**
- Create: `lib/features/notifications/application/notification_providers.dart`
- Modify: `lib/core/app_shell.dart`
- Modify: `lib/main.dart`
- Modify: `test/core/app_shell_test.dart`
- Modify: `test/widget_test.dart`
- Test: `test/features/notifications/application/notification_providers_test.dart`

**Interfaces:**
- Consumes: Task 2–4'teki her şey. Ayrıca `isLoggedInProvider`, `nowProvider`, `todayWorkoutProvider`, `recentSessionsProvider` (`progress/application/progress_providers.dart`), `todayMealsProvider`, `profileProvider`, `sumMealMacros`.
- Produces:
  - `notificationsSupportedProvider` (`Provider<bool>`, `!kIsWeb`)
  - `reminderSchedulerProvider` (`Provider<ReminderScheduler>`)
  - `reminderTranslatorProvider` (`Provider<ReminderTranslator>`)
  - `notificationSettingsStoreProvider`
  - `notificationSettingsProvider` (`AsyncNotifierProvider<NotificationSettingsNotifier, NotificationSettings>`; `Future<void> save(NotificationSettings next)`)
  - `notificationPermissionProvider` (`AsyncNotifierProvider<NotificationPermissionNotifier, bool>`; `Future<bool> request()`)
  - `pendingNotificationRouteProvider` (`NotifierProvider<PendingNotificationRoute, String?>`; `open(String)`, `String? take()`)
  - `lastScheduledRemindersProvider` (`NotifierProvider<LastScheduledReminders, String?>`)
  - `notificationBootstrapProvider` (`FutureProvider<void>`)
  - `notificationSyncProvider` (`FutureProvider.autoDispose.family<void, String>`; parametre dil kodu)

- [ ] **Step 1: Sağlayıcı testlerini yaz**

```dart
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spor_takip/features/notifications/application/notification_providers.dart';
import 'package:spor_takip/features/notifications/data/notification_settings_store.dart';
import 'package:spor_takip/features/notifications/domain/notification_settings.dart';
import 'package:spor_takip/features/nutrition/application/today_meals_provider.dart';
import 'package:spor_takip/features/onboarding/application/auth_providers.dart';
import 'package:spor_takip/features/onboarding/application/profile_providers.dart';
import 'package:spor_takip/features/progress/application/progress_providers.dart';
import 'package:spor_takip/features/workout/application/session_providers.dart';
import 'package:spor_takip/features/workout/application/workout_providers.dart';
import 'package:spor_takip/features/workout/domain/program.dart';
import 'package:spor_takip/features/workout/domain/program_workout.dart';
import 'package:spor_takip/features/workout/domain/schedule_mode.dart';
import 'package:spor_takip/features/workout/domain/today_workout.dart';
import 'package:spor_takip/features/workout/domain/workout_session.dart';

import '../../gamification/game_fixtures.dart';
import '../../progress/fixtures.dart';
import '../fakes.dart';

const _push = ProgramWorkout(name: 'Push A', exercises: [], weekday: 1);
const _legs = ProgramWorkout(name: 'Legs', exercises: [], weekday: 3);
const _program = Program(name: 'P', scheduleMode: ScheduleMode.weekdays, workouts: [_push, _legs]);

void _store(NotificationSettings settings) =>
    SharedPreferences.setMockInitialValues({notificationSettingsKey: jsonEncode(settings.toJson())});

ProviderContainer _container(
  FakeReminderScheduler scheduler, {
  bool loggedIn = true,
  TodayWorkout today = const NoActiveProgram(),
  List<WorkoutSession> sessions = const [],
}) {
  final container = ProviderContainer(
    retry: (retryCount, error) => null,
    overrides: [
      reminderSchedulerProvider.overrideWithValue(scheduler),
      reminderTranslatorProvider.overrideWithValue((key, args) => '$key$args'),
      isLoggedInProvider.overrideWithValue(loggedIn),
      nowProvider.overrideWithValue(() => DateTime(2026, 10, 12, 12)),
      todayWorkoutProvider.overrideWith((ref) async => today),
      recentSessionsProvider.overrideWith((ref) async => sessions),
      todayMealsProvider.overrideWith((ref) async => const []),
      profileProvider.overrideWith((ref) async => testProfile),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

Future<void> _sync(ProviderContainer container, [String lang = 'tr']) async {
  container.listen(notificationSyncProvider(lang), (_, _) {});
  await container.read(notificationSyncProvider(lang).future);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('with every card off it only cancels, once', () async {
    final scheduler = FakeReminderScheduler();
    final container = _container(scheduler);
    await _sync(container);
    container.invalidate(notificationSyncProvider('tr'));
    await _sync(container);
    expect(scheduler.replaced, isEmpty);
    expect(scheduler.cancels, 1);
  });

  test('schedules the plan once and again only when it changes', () async {
    _store(NotificationSettings.defaults.copyWith(workoutEnabled: true, workoutDaysInitialized: true));
    final scheduler = FakeReminderScheduler();
    final container = _container(scheduler);

    await _sync(container);
    expect(scheduler.replaced, hasLength(1));
    expect(scheduler.replaced.single, hasLength(3));
    expect(scheduler.translated.single.first, 'notifications.workout_body{}');

    container.invalidate(notificationSyncProvider('tr'));
    await _sync(container);
    expect(scheduler.replaced, hasLength(1));

    final settings = await container.read(notificationSettingsProvider.future);
    await container.read(notificationSettingsProvider.notifier).save(settings.copyWith(workoutTime: const ReminderTime(19, 0)));
    await _sync(container);
    expect(scheduler.replaced, hasLength(2));
    expect(scheduler.replaced.last.first.at, DateTime(2026, 10, 12, 19));
  });

  test('a language change reschedules', () async {
    _store(NotificationSettings.defaults.copyWith(nutritionEnabled: true));
    final scheduler = FakeReminderScheduler();
    final container = _container(scheduler);
    await _sync(container, 'tr');
    await _sync(container, 'en');
    expect(scheduler.replaced, hasLength(2));
  });

  test('without permission or a session nothing is scheduled', () async {
    _store(NotificationSettings.defaults.copyWith(workoutEnabled: true));
    final denied = FakeReminderScheduler(permission: false);
    await _sync(_container(denied));
    expect(denied.replaced, isEmpty);
    expect(denied.cancels, 1);

    final loggedOut = FakeReminderScheduler();
    await _sync(_container(loggedOut, loggedIn: false));
    expect(loggedOut.replaced, isEmpty);
    expect(loggedOut.cancels, 1);
  });

  test('uses the program, the finished workout and the weekly goal', () async {
    _store(NotificationSettings.defaults.copyWith(
      workoutEnabled: true,
      workoutDays: {1, 3},
      workoutDaysInitialized: true,
      weeklyEnabled: true,
    ));
    final scheduler = FakeReminderScheduler();
    final container = _container(
      scheduler,
      today: const ScheduledWorkout(_program, 0, _push),
      sessions: [gameSession('s', DateTime(2026, 10, 12, 10), const [])],
    );
    await _sync(container);
    final plan = scheduler.replaced.single;
    expect([for (final r in plan) r.at], [DateTime(2026, 10, 14, 18), DateTime(2026, 10, 16, 19)]);
    expect(plan.first.args, {'name': 'Legs'});
    expect(plan.last.args, {'done': '1', 'goal': '2', 'left': '3'});
  });

  test('saved settings survive a new container', () async {
    final first = _container(FakeReminderScheduler());
    await first.read(notificationSettingsProvider.future);
    await first.read(notificationSettingsProvider.notifier).save(NotificationSettings.defaults.copyWith(weeklyEnabled: true));
    final second = _container(FakeReminderScheduler());
    expect((await second.read(notificationSettingsProvider.future)).weeklyEnabled, isTrue);
  });

  test('requesting permission updates its state', () async {
    final scheduler = FakeReminderScheduler(permission: false, requestResult: true);
    final container = _container(scheduler);
    container.listen(notificationPermissionProvider, (_, _) {});
    expect(await container.read(notificationPermissionProvider.future), isFalse);
    expect(await container.read(notificationPermissionProvider.notifier).request(), isTrue);
    expect(container.read(notificationPermissionProvider).value, isTrue);
  });

  test('bootstrap passes the launch and tapped routes on, and cancels on sign-out', () async {
    final scheduler = FakeReminderScheduler(launchRoute: '/nutrition');
    final container = _container(scheduler);
    await container.read(notificationBootstrapProvider.future);
    expect(container.read(pendingNotificationRouteProvider.notifier).take(), '/nutrition');
    expect(container.read(pendingNotificationRouteProvider), isNull);
    scheduler.onTap!('/home');
    expect(container.read(pendingNotificationRouteProvider), '/home');
  });
}
```

Not: Çıkışta iptal (`isLoggedInProvider` true → false) `overrideWithValue` ile değiştirilemediği için birim testte yok. Sync'in oturum yokken iptal ettiği yukarıda test ediliyor; geçiş elle kontrolde (madde 8) doğrulanır.

- [ ] **Step 2: Testin başarısız olduğunu gör**

Run: `flutter test --no-pub -j 1 test/features/notifications/application/notification_providers_test.dart`
Expected: FAIL (dosya yok).

- [ ] **Step 3: `notification_providers.dart`**

```dart
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../nutrition/application/today_meals_provider.dart';
import '../../nutrition/domain/macro_totals.dart';
import '../../onboarding/application/auth_providers.dart';
import '../../onboarding/application/profile_providers.dart';
import '../../progress/application/progress_providers.dart';
import '../../workout/application/session_providers.dart';
import '../../workout/application/workout_providers.dart';
import '../data/local_reminder_scheduler.dart';
import '../data/notification_settings_store.dart';
import '../data/reminder_scheduler.dart';
import '../domain/notification_settings.dart';
import '../domain/reminder_inputs.dart';
import '../domain/reminder_planner.dart';

/// Yerel bildirimler yalnız mobilde (N1 spec §3.3); testlerde değiştirilir.
final notificationsSupportedProvider = Provider<bool>((ref) => !kIsWeb);

final reminderSchedulerProvider = Provider<ReminderScheduler>((ref) =>
    ref.watch(notificationsSupportedProvider) ? LocalReminderScheduler.instance : const NoopReminderScheduler());

/// Bildirim metinleri uygulamanın seçili dilinde.
final reminderTranslatorProvider = Provider<ReminderTranslator>((ref) => (key, args) => key.tr(namedArgs: args));

final notificationSettingsStoreProvider = Provider<NotificationSettingsStore>((ref) => const NotificationSettingsStore());

class NotificationSettingsNotifier extends AsyncNotifier<NotificationSettings> {
  @override
  Future<NotificationSettings> build() => ref.watch(notificationSettingsStoreProvider).load();

  Future<void> save(NotificationSettings next) async {
    state = AsyncData(next);
    await ref.read(notificationSettingsStoreProvider).save(next);
  }
}

final notificationSettingsProvider =
    AsyncNotifierProvider<NotificationSettingsNotifier, NotificationSettings>(NotificationSettingsNotifier.new);

class NotificationPermissionNotifier extends AsyncNotifier<bool> {
  @override
  Future<bool> build() async {
    try {
      return await ref.watch(reminderSchedulerProvider).hasPermission();
    } catch (e) {
      debugPrint('notification permission check failed: $e');
      return false;
    }
  }

  Future<bool> request() async {
    var granted = false;
    try {
      granted = await ref.read(reminderSchedulerProvider).requestPermission();
    } catch (e) {
      debugPrint('notification permission request failed: $e');
    }
    state = AsyncData(granted);
    return granted;
  }
}

final notificationPermissionProvider =
    AsyncNotifierProvider<NotificationPermissionNotifier, bool>(NotificationPermissionNotifier.new);

/// Dokunulan (ya da uygulamayı açan) bildirimin rotası; AppShell alır ve gider.
class PendingNotificationRoute extends Notifier<String?> {
  @override
  String? build() => null;

  void open(String route) => state = route;

  String? take() {
    final route = state;
    state = null;
    return route;
  }
}

final pendingNotificationRouteProvider =
    NotifierProvider<PendingNotificationRoute, String?>(PendingNotificationRoute.new);

/// Son kurulan planın imzası (bellekte); `''` = hepsi iptal. Aynıysa yeniden kurulmaz.
class LastScheduledReminders extends Notifier<String?> {
  @override
  String? build() => null;

  void remember(String? signature) => state = signature;
}

final lastScheduledRemindersProvider =
    NotifierProvider<LastScheduledReminders, String?>(LastScheduledReminders.new);

/// Eklentiyi bir kez kurar ve çıkışta bildirimleri iptal eder (SporTakipApp izler).
final notificationBootstrapProvider = FutureProvider<void>((ref) async {
  final scheduler = ref.watch(reminderSchedulerProvider);
  final pending = ref.read(pendingNotificationRouteProvider.notifier);
  ref.listen(isLoggedInProvider, (previous, next) {
    if (previous != true || next) return;
    ref.read(lastScheduledRemindersProvider.notifier).remember('');
    scheduler.cancelAll().catchError((Object e) => debugPrint('cancel reminders failed: $e'));
  });
  try {
    final launch = await scheduler.init(pending.open);
    if (launch != null) pending.open(launch);
  } catch (e, st) {
    debugPrint('notification init failed: $e\n$st');
  }
});

/// Önümüzdeki 7 günün hatırlatıcılarını kurar (N1 spec §4.3); AppShell dil koduyla izler.
/// Plan bir öncekinden farklıysa `replaceAll`; kapalıyken, izin ya da oturum yokken `cancelAll`.
final notificationSyncProvider = FutureProvider.autoDispose.family<void, String>((ref, languageCode) async {
  final scheduler = ref.watch(reminderSchedulerProvider);
  Future<void> apply(String signature, Future<void> Function() action) async {
    if (ref.read(lastScheduledRemindersProvider) == signature) return;
    try {
      await action();
      ref.read(lastScheduledRemindersProvider.notifier).remember(signature);
    } catch (e, st) {
      debugPrint('notificationSync failed: $e\n$st');
    }
  }

  final loggedIn = ref.watch(isLoggedInProvider);
  final settings = await ref.watch(notificationSettingsProvider.future);
  final allowed = await ref.watch(notificationPermissionProvider.future);
  if (!loggedIn || !settings.anyEnabled || !allowed) return apply('', scheduler.cancelAll);

  final now = ref.read(nowProvider)();
  _refreshOnResume(ref, now);
  final (today, sessions, meals, profile) = await (
    ref.watch(todayWorkoutProvider.future),
    ref.watch(recentSessionsProvider.future),
    ref.watch(todayMealsProvider.future),
    ref.watch(profileProvider.future),
  ).wait;
  final plan = planReminders(
    settings: settings,
    now: now,
    workoutNames: workoutNamesByWeekday(today),
    workoutDoneToday: finishedOn(sessions, now),
    mealTypesToday: {for (final meal in meals) meal.mealType},
    nutritionToday: sumMealMacros(meals),
    targets: profile == null
        ? null
        : NutritionTargets(calories: profile.dailyCalorieTarget, proteinG: profile.dailyProteinTargetG),
    weeklyGoal: programOf(today)?.effectiveDaysPerWeek,
    weeklyDone: finishedThisWeek(sessions, now),
  );
  final tr = ref.read(reminderTranslatorProvider);
  await apply('$languageCode|${plan.join(';')}', () => scheduler.replaceAll(plan, tr));
});

/// Uygulama ön plana dönünce yeniden planlar; gün değiştiyse bugünün verisi tazelenir.
void _refreshOnResume(Ref ref, DateTime plannedAt) {
  final listener = AppLifecycleListener(onResume: () {
    if (!DateUtils.isSameDay(ref.read(nowProvider)(), plannedAt)) {
      ref
        ..invalidate(todayMealsProvider)
        ..invalidate(todayWorkoutProvider);
    }
    ref.invalidateSelf();
  });
  ref.onDispose(listener.dispose);
}
```

`macro_totals.dart` importu `sumMealMacros` için; `kIsWeb` `material.dart` üzerinden gelir.

- [ ] **Step 4: Testin geçtiğini gör**

Run: `flutter test --no-pub -j 1 test/features/notifications/application/notification_providers_test.dart`
Expected: PASS (8 test). Riverpod yeniden denemesi kapatıldı (`retry: null`); bir test takılırsa önce `.future` beklenen sağlayıcının override edilip edilmediğine bak.

- [ ] **Step 5: AppShell (`lib/core/app_shell.dart`, CRLF)**

Importlara ekle:

```dart
import '../features/notifications/application/notification_providers.dart';
```

`build`'in başındaki iki `ref.watch` satırının altına:

```dart
    // Yerel hatırlatıcılar seçili dilde kurulur (N1 spec §4.3).
    ref.watch(notificationSyncProvider(context.locale.languageCode));
    // Dokunulan bildirimin rotasına git (N1 spec §3.3).
    ref.listen(pendingNotificationRouteProvider, (_, route) {
      if (route == null) return;
      Future.microtask(() {
        if (!context.mounted) return;
        final next = ref.read(pendingNotificationRouteProvider.notifier).take();
        if (next != null) GoRouter.of(context).go(next);
      });
    }, fireImmediately: true);
```

Ayrıca yorum satırını güncelle: "Kabuk açıkken oyuncu özeti (S1 spec §6.1), meydan okuma değerlerim (S3) ve hatırlatıcılar (N1) güncel tutulur."

- [ ] **Step 6: AppShell testi (`test/core/app_shell_test.dart`)**

Importlara ekle:

```dart
import 'package:spor_takip/features/notifications/application/notification_providers.dart';
```

`overrides` listesine:

```dart
          notificationSyncProvider.overrideWith((ref, languageCode) async {}),
```

Dosyanın sonuna, son testten sonra (main'in kapanışından önce) yeni test:

```dart
  testWidgets('a tapped notification opens its route', (tester) async {
    await tester.pumpWidget(buildTestRouter());
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(tester.element(find.byType(AppShell)));
    container.read(pendingNotificationRouteProvider.notifier).open('/nutrition');
    await tester.pumpAndSettle();
    expect(find.text('NUTRITION_SCREEN'), findsOneWidget);
    expect(container.read(pendingNotificationRouteProvider), isNull);
  });
```

- [ ] **Step 7: main.dart (CRLF)**

Importlara ekle:

```dart
import 'features/notifications/application/notification_providers.dart';
```

`SporTakipApp.build` içinde `final router = ...` satırının altına:

```dart
    // Mobilde bildirim eklentisi bir kez kurulur; çıkışta hatırlatıcılar iptal edilir.
    ref.watch(notificationBootstrapProvider);
```

- [ ] **Step 8: widget_test.dart**

Importlara ekle:

```dart
import 'package:spor_takip/features/notifications/application/notification_providers.dart';
import 'package:spor_takip/features/notifications/data/reminder_scheduler.dart';
```

`overrides` listesine:

```dart
            reminderSchedulerProvider.overrideWithValue(const NoopReminderScheduler()),
```

- [ ] **Step 9: Etkilenen testleri çalıştır**

Run: `flutter test --no-pub -j 1 test/core/app_shell_test.dart test/widget_test.dart test/core/router_test.dart test/features/notifications`
Expected: PASS. `router_test.dart` AppShell'i kuruyorsa ve sync gerçek sağlayıcılara gidiyorsa aynı `notificationSyncProvider` override'ını oraya da ekle.

- [ ] **Step 10: Commit**

```bash
git add lib/features/notifications/application lib/core/app_shell.dart lib/main.dart test/core/app_shell_test.dart test/widget_test.dart test/features/notifications/application
git commit -m "feat(notifications): keep reminders in sync from the app shell"
```

---

### Task 6: Bildirimler sayfası, Ayarlar satırı, rota ve çeviriler

**Files:**
- Create: `lib/features/notifications/presentation/notifications_screen.dart`
- Modify: `lib/features/settings/presentation/settings_screen.dart` (CRLF)
- Modify: `lib/core/router.dart` (CRLF)
- Modify: `assets/translations/tr.json`, `assets/translations/en.json` (CRLF)
- Test: `test/features/notifications/presentation/notifications_screen_test.dart`
- Modify: `test/features/settings/presentation/settings_screen_test.dart`

**Interfaces:**
- Consumes: `notificationSettingsProvider`, `notificationPermissionProvider`, `notificationsSupportedProvider`, `reminderSchedulerProvider`, `todayWorkoutProvider`, `programOf`, `reminderMealTypes`, `ReminderTime`, `CardError` (`progress/presentation/widgets/card_states.dart`).
- Produces: `NotificationsScreen({Key? key, TimePickerFn pickTime})`, `typedef TimePickerFn = Future<TimeOfDay?> Function(BuildContext context, TimeOfDay initial)`. Rota `/home/settings/notifications`. Anahtarlar: `notifications_screen`, `notifications_web_note`, `notifications_permission_warning`, `notifications_open_settings`, `notif_<kart>_switch` (kart: workout, meals, nutrition, weekly), `notif_workout_day_<1-7>`, `notif_<kart>_time` (workout, nutrition, weekly), `notif_meal_<tip>_switch`, `notif_meal_<tip>_time`, `notif_weekly_day`, `settings_notifications`.

- [ ] **Step 1: Çevirileri ekle**

Senaryoyu scratchpad'e `add_notification_strings.py` olarak yaz ve `python -I <yol> assets/translations` ile çalıştır. Senaryo sırayı korur, CRLF ve 2 boşluklu girinti ile yazar:

```python
import json, sys
from pathlib import Path

root = Path(sys.argv[1])
strings = {
    'tr': {
        'settings': {'section_notifications': 'Bildirimler', 'row_notifications': 'Hatırlatıcılar'},
        'notifications': {
            'title': 'Bildirimler',
            'web_note': 'Bildirimler yalnız mobil uygulamada çalışır.',
            'permission_missing': 'Bildirim izni yok. Hatırlatıcıların gelmesi için izin ver.',
            'open_settings': 'Ayarları aç',
            'time': 'Saat',
            'workout': 'Antrenman',
            'workout_desc': 'Antrenman günlerinde hatırlatır; o gün antrenmanı bitirdiysen gelmez.',
            'meals': 'Öğünler',
            'meals_desc': 'Öğünü kaydetmediysen saatinde hatırlatır.',
            'meal_breakfast': 'Kahvaltı',
            'meal_lunch': 'Öğle',
            'meal_dinner': 'Akşam',
            'nutrition': 'Akşam beslenme özeti',
            'nutrition_desc': 'Günün sonunda kalan protein ya da kaloriyi söyler.',
            'weekly': 'Haftalık hedef',
            'weekly_desc': 'Haftalık antrenman hedefinin gerisindeysen hatırlatır.',
            'weekly_day': 'Gün',
            'day_1': 'Pzt', 'day_2': 'Sal', 'day_3': 'Çar', 'day_4': 'Per',
            'day_5': 'Cum', 'day_6': 'Cmt', 'day_7': 'Paz',
            'channel_name': 'Hatırlatıcılar',
            'channel_desc': 'Antrenman ve beslenme hatırlatıcıları',
            'workout_title': 'Antrenman zamanı',
            'workout_body_named': 'Bugün {name} günü. Hadi başlayalım!',
            'workout_body': 'Bugün antrenman günü. Hadi başlayalım!',
            'meal_title_breakfast': 'Kahvaltı zamanı',
            'meal_title_lunch': 'Öğle yemeği zamanı',
            'meal_title_dinner': 'Akşam yemeği zamanı',
            'meal_body': 'Öğününü kaydetmeyi unutma.',
            'nutrition_title': 'Günün beslenmesi',
            'nutrition_none': 'Bugün öğün kaydetmedin.',
            'nutrition_protein': 'Proteinine {g} g kaldı.',
            'nutrition_kcal': 'Hedefine {kcal} kcal kaldı.',
            'weekly_title': 'Haftalık hedef',
            'weekly_body': 'Bu hafta {done}/{goal} antrenman, {left} gün kaldı.',
        },
    },
    'en': {
        'settings': {'section_notifications': 'Notifications', 'row_notifications': 'Reminders'},
        'notifications': {
            'title': 'Notifications',
            'web_note': 'Notifications only work in the mobile app.',
            'permission_missing': 'Notifications are not allowed. Allow them to get your reminders.',
            'open_settings': 'Open settings',
            'time': 'Time',
            'workout': 'Workout',
            'workout_desc': 'Reminds you on workout days; skipped once you finish a workout that day.',
            'meals': 'Meals',
            'meals_desc': "Reminds you at meal time if you haven't logged it.",
            'meal_breakfast': 'Breakfast',
            'meal_lunch': 'Lunch',
            'meal_dinner': 'Dinner',
            'nutrition': 'Evening nutrition summary',
            'nutrition_desc': 'Tells you the protein or calories left at the end of the day.',
            'weekly': 'Weekly goal',
            'weekly_desc': "Reminds you when you're behind your weekly workout goal.",
            'weekly_day': 'Day',
            'day_1': 'Mon', 'day_2': 'Tue', 'day_3': 'Wed', 'day_4': 'Thu',
            'day_5': 'Fri', 'day_6': 'Sat', 'day_7': 'Sun',
            'channel_name': 'Reminders',
            'channel_desc': 'Workout and nutrition reminders',
            'workout_title': 'Time to train',
            'workout_body_named': "Today is {name} day. Let's go!",
            'workout_body': "Today is a workout day. Let's go!",
            'meal_title_breakfast': 'Breakfast time',
            'meal_title_lunch': 'Lunch time',
            'meal_title_dinner': 'Dinner time',
            'meal_body': "Don't forget to log your meal.",
            'nutrition_title': "Today's nutrition",
            'nutrition_none': "You haven't logged a meal today.",
            'nutrition_protein': '{g} g of protein left.',
            'nutrition_kcal': '{kcal} kcal left to your target.',
            'weekly_title': 'Weekly goal',
            'weekly_body': '{done}/{goal} workouts this week, {left} days left.',
        },
    },
}
for lang, sections in strings.items():
    path = root / f'{lang}.json'
    data = json.loads(path.read_text(encoding='utf-8'))
    for section, values in sections.items():
        data.setdefault(section, {}).update(values)
    with path.open('w', encoding='utf-8', newline='\r\n') as f:
        f.write(json.dumps(data, ensure_ascii=False, indent=2) + '\n')
```

Run: `git diff --stat assets/translations`
Expected: yalnız eklemeler (her dosyada ~45 satır). Mevcut satırlarda değişiklik görünüyorsa (kaçış ya da girinti farkı) dosyayı geri al ve anahtarları Edit aracıyla elle ekle.

- [ ] **Step 2: Ekran testini yaz**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spor_takip/features/notifications/application/notification_providers.dart';
import 'package:spor_takip/features/notifications/data/notification_settings_store.dart';
import 'package:spor_takip/features/notifications/domain/notification_settings.dart';
import 'package:spor_takip/features/notifications/presentation/notifications_screen.dart';
import 'package:spor_takip/features/nutrition/domain/meal_type.dart';
import 'package:spor_takip/features/workout/application/workout_providers.dart';
import 'package:spor_takip/features/workout/domain/program.dart';
import 'package:spor_takip/features/workout/domain/program_workout.dart';
import 'package:spor_takip/features/workout/domain/schedule_mode.dart';
import 'package:spor_takip/features/workout/domain/today_workout.dart';

import '../../progress/presentation/test_app.dart';
import '../fakes.dart';

const _program = Program(
  name: 'P',
  scheduleMode: ScheduleMode.weekdays,
  workouts: [
    ProgramWorkout(name: 'A', exercises: [], weekday: 2),
    ProgramWorkout(name: 'B', exercises: [], weekday: 4),
  ],
);

void main() {
  setUpAll(initTestLocalization);
  setUp(() => SharedPreferences.setMockInitialValues({}));

  late FakeReminderScheduler scheduler;

  Future<void> pump(
    WidgetTester tester, {
    bool supported = true,
    bool permission = true,
    bool requestResult = true,
    TimeOfDay? picked,
    double width = 800,
  }) async {
    scheduler = FakeReminderScheduler(permission: permission, requestResult: requestResult);
    tester.view.physicalSize = Size(width, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(testApp(
      NotificationsScreen(pickTime: (context, initial) async => picked),
      scaffold: false,
      overrides: [
        reminderSchedulerProvider.overrideWithValue(scheduler),
        notificationsSupportedProvider.overrideWithValue(supported),
        todayWorkoutProvider.overrideWith((ref) async => const RestDay(_program)),
      ],
    ));
    await tester.pumpAndSettle();
  }

  Future<NotificationSettings> stored() => const NotificationSettingsStore().load();

  bool switchValue(WidgetTester tester, String key) => tester.widget<SwitchListTile>(find.byKey(Key(key))).value;

  testWidgets('shows four cards, all off, with the default times', (tester) async {
    await pump(tester);
    for (final card in ['workout', 'meals', 'nutrition', 'weekly']) {
      expect(switchValue(tester, 'notif_${card}_switch'), isFalse);
    }
    String time(String key) => tester.widget<Text>(find.descendant(of: find.byKey(Key(key)), matching: find.byType(Text))).data!;
    expect(time('notif_workout_time'), '18:00');
    expect(time('notif_meal_breakfast_time'), '09:00');
    expect(time('notif_meal_lunch_time'), '13:00');
    expect(time('notif_meal_dinner_time'), '19:30');
    expect(time('notif_nutrition_time'), '21:00');
    expect(time('notif_weekly_time'), '19:00');
    expect(find.byKey(const Key('notifications_web_note')), findsNothing);
    expect(find.byKey(const Key('notifications_permission_warning')), findsNothing);
  });

  testWidgets('workout days start from the program and turning on saves them', (tester) async {
    await pump(tester, permission: false);
    bool selected(int day) => tester.widget<FilterChip>(find.byKey(Key('notif_workout_day_$day'))).selected;
    expect([for (var d = 1; d <= 7; d++) if (selected(d)) d], [2, 4]);

    await tester.tap(find.byKey(const Key('notif_workout_switch')));
    await tester.pumpAndSettle();
    expect(scheduler.permissionRequests, 1);
    final saved = await stored();
    expect(saved.workoutEnabled, isTrue);
    expect(saved.workoutDays, {2, 4});
    expect(saved.workoutDaysInitialized, isTrue);

    await tester.tap(find.byKey(const Key('notif_workout_day_1')));
    await tester.pumpAndSettle();
    expect((await stored()).workoutDays, {1, 2, 4});
  });

  testWidgets('a picked time is shown and saved', (tester) async {
    await pump(tester, picked: const TimeOfDay(hour: 7, minute: 45));
    await tester.tap(find.byKey(const Key('notif_nutrition_time')));
    await tester.pumpAndSettle();
    expect(find.text('07:45'), findsOneWidget);
    expect((await stored()).nutritionTime, const ReminderTime(7, 45));
  });

  testWidgets('a single meal can be turned off', (tester) async {
    await pump(tester);
    await tester.tap(find.byKey(const Key('notif_meals_switch')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('notif_meal_lunch_switch')));
    await tester.pumpAndSettle();
    final saved = await stored();
    expect(saved.mealsEnabled, isTrue);
    expect(saved.meals[MealType.lunch]!.enabled, isFalse);
    expect(saved.meals[MealType.dinner]!.enabled, isTrue);
  });

  testWidgets('the weekly day can be changed', (tester) async {
    await pump(tester);
    await tester.tap(find.byKey(const Key('notif_weekly_day')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('home.weekday_3').last);
    await tester.pumpAndSettle();
    expect((await stored()).weeklyDay, DateTime.wednesday);
  });

  testWidgets('a denied permission shows the warning with a settings button', (tester) async {
    await pump(tester, permission: false, requestResult: false);
    await tester.tap(find.byKey(const Key('notif_weekly_switch')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('notifications_permission_warning')), findsOneWidget);
    expect((await stored()).weeklyEnabled, isTrue);
    await tester.tap(find.byKey(const Key('notifications_open_settings')));
    await tester.pumpAndSettle();
    expect(scheduler.settingsOpened, 1);
  });

  testWidgets('on the web the page explains and the switches are off', (tester) async {
    await pump(tester, supported: false);
    expect(find.byKey(const Key('notifications_web_note')), findsOneWidget);
    expect(tester.widget<SwitchListTile>(find.byKey(const Key('notif_workout_switch'))).onChanged, isNull);
  });

  testWidgets('fits a 360 px wide phone', (tester) async {
    await pump(tester, width: 360);
    expect(tester.takeException(), isNull);
  });
}
```

- [ ] **Step 3: Testin başarısız olduğunu gör**

Run: `flutter test --no-pub -j 1 test/features/notifications/presentation/notifications_screen_test.dart`
Expected: FAIL (ekran yok).

- [ ] **Step 4: `notifications_screen.dart`**

```dart
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../progress/presentation/widgets/card_states.dart';
import '../../workout/application/workout_providers.dart';
import '../../workout/domain/today_workout.dart';
import '../application/notification_providers.dart';
import '../domain/notification_settings.dart';
import '../domain/reminder_inputs.dart';

typedef TimePickerFn = Future<TimeOfDay?> Function(BuildContext context, TimeOfDay initial);

Future<TimeOfDay?> _showPicker(BuildContext context, TimeOfDay initial) =>
    showTimePicker(context: context, initialTime: initial);

/// Hatırlatıcı ayarları (N1 spec §3.1): dört kart, izin uyarısı, web notu.
class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key, this.pickTime = _showPicker});

  /// Testlerde saat seçici yerine enjekte edilir.
  final TimePickerFn pickTime;

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  // Sistem ayarlarından dönünce izin yeniden okunur.
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onResume: () => ref.invalidate(notificationPermissionProvider));
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  Future<void> _save(NotificationSettings next, {bool turningOn = false}) async {
    if (turningOn && ref.read(notificationPermissionProvider).value != true) {
      await ref.read(notificationPermissionProvider.notifier).request();
    }
    await ref.read(notificationSettingsProvider.notifier).save(next);
  }

  Future<void> _pick(ReminderTime current, NotificationSettings Function(ReminderTime time) apply) async {
    final picked = await widget.pickTime(context, TimeOfDay(hour: current.hour, minute: current.minute));
    if (picked != null) await _save(apply(ReminderTime(picked.hour, picked.minute)));
  }

  @override
  Widget build(BuildContext context) {
    final supported = ref.watch(notificationsSupportedProvider);
    final permission = ref.watch(notificationPermissionProvider).value;
    final program = programOf(ref.watch(todayWorkoutProvider).value ?? const NoActiveProgram());
    return Scaffold(
      key: const Key('notifications_screen'),
      appBar: AppBar(title: Text('notifications.title'.tr())),
      body: ref.watch(notificationSettingsProvider).when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stackTrace) =>
                Center(child: CardError(onRetry: () => ref.invalidate(notificationSettingsProvider))),
            data: (stored) {
              final s = stored.withWorkoutDaysFrom(program);
              VoidCallback? pickFor(ReminderTime time, NotificationSettings Function(ReminderTime) apply) =>
                  supported ? () => _pick(time, apply) : null;
              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
                  if (!supported)
                    _Banner(
                      key: const Key('notifications_web_note'),
                      icon: Icons.info_outline,
                      text: 'notifications.web_note'.tr(),
                    ),
                  if (supported && permission == false && stored.anyEnabled)
                    _Banner(
                      key: const Key('notifications_permission_warning'),
                      icon: Icons.notifications_off_outlined,
                      text: 'notifications.permission_missing'.tr(),
                      action: TextButton(
                        key: const Key('notifications_open_settings'),
                        onPressed: () => ref.read(reminderSchedulerProvider).openSystemSettings(),
                        child: Text('notifications.open_settings'.tr()),
                      ),
                    ),
                  _ReminderCard(
                    id: 'workout',
                    icon: Icons.fitness_center,
                    title: 'notifications.workout'.tr(),
                    subtitle: 'notifications.workout_desc'.tr(),
                    value: s.workoutEnabled,
                    onChanged: supported ? (on) => _save(s.copyWith(workoutEnabled: on), turningOn: on) : null,
                    children: [
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (var day = DateTime.monday; day <= DateTime.sunday; day++)
                            FilterChip(
                              key: Key('notif_workout_day_$day'),
                              label: Text('notifications.day_$day'.tr()),
                              selected: s.workoutDays.contains(day),
                              onSelected: supported
                                  ? (on) => _save(s.copyWith(
                                        workoutDays: on ? {...s.workoutDays, day} : ({...s.workoutDays}..remove(day)),
                                      ))
                                  : null,
                            ),
                        ],
                      ),
                      _TimeRow(
                        id: 'workout',
                        label: 'notifications.time'.tr(),
                        time: s.workoutTime,
                        onTap: pickFor(s.workoutTime, (t) => s.copyWith(workoutTime: t)),
                      ),
                    ],
                  ),
                  _ReminderCard(
                    id: 'meals',
                    icon: Icons.restaurant,
                    title: 'notifications.meals'.tr(),
                    subtitle: 'notifications.meals_desc'.tr(),
                    value: s.mealsEnabled,
                    onChanged: supported ? (on) => _save(s.copyWith(mealsEnabled: on), turningOn: on) : null,
                    children: [
                      for (final type in reminderMealTypes)
                        Row(
                          children: [
                            Expanded(child: Text('notifications.meal_${type.name}'.tr())),
                            _TimeButton(
                              buttonKey: Key('notif_meal_${type.name}_time'),
                              time: s.meals[type]!.time,
                              onTap: pickFor(
                                s.meals[type]!.time,
                                (t) => s.copyWith(meals: {...s.meals, type: s.meals[type]!.copyWith(time: t)}),
                              ),
                            ),
                            Switch(
                              key: Key('notif_meal_${type.name}_switch'),
                              value: s.meals[type]!.enabled,
                              onChanged: supported
                                  ? (on) => _save(
                                        s.copyWith(meals: {...s.meals, type: s.meals[type]!.copyWith(enabled: on)}),
                                        turningOn: on && s.mealsEnabled,
                                      )
                                  : null,
                            ),
                          ],
                        ),
                    ],
                  ),
                  _ReminderCard(
                    id: 'nutrition',
                    icon: Icons.nightlight_outlined,
                    title: 'notifications.nutrition'.tr(),
                    subtitle: 'notifications.nutrition_desc'.tr(),
                    value: s.nutritionEnabled,
                    onChanged: supported ? (on) => _save(s.copyWith(nutritionEnabled: on), turningOn: on) : null,
                    children: [
                      _TimeRow(
                        id: 'nutrition',
                        label: 'notifications.time'.tr(),
                        time: s.nutritionTime,
                        onTap: pickFor(s.nutritionTime, (t) => s.copyWith(nutritionTime: t)),
                      ),
                    ],
                  ),
                  _ReminderCard(
                    id: 'weekly',
                    icon: Icons.flag_outlined,
                    title: 'notifications.weekly'.tr(),
                    subtitle: 'notifications.weekly_desc'.tr(),
                    value: s.weeklyEnabled,
                    onChanged: supported ? (on) => _save(s.copyWith(weeklyEnabled: on), turningOn: on) : null,
                    children: [
                      Row(
                        children: [
                          Expanded(child: Text('notifications.weekly_day'.tr())),
                          DropdownButton<int>(
                            key: const Key('notif_weekly_day'),
                            value: s.weeklyDay,
                            items: [
                              for (var day = DateTime.monday; day <= DateTime.sunday; day++)
                                DropdownMenuItem(value: day, child: Text('home.weekday_$day'.tr())),
                            ],
                            onChanged: supported
                                ? (day) {
                                    if (day != null) _save(s.copyWith(weeklyDay: day));
                                  }
                                : null,
                          ),
                        ],
                      ),
                      _TimeRow(
                        id: 'weekly',
                        label: 'notifications.time'.tr(),
                        time: s.weeklyTime,
                        onTap: pickFor(s.weeklyTime, (t) => s.copyWith(weeklyTime: t)),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({super.key, required this.icon, required this.text, this.action});

  final IconData icon;
  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: scheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        child: Row(
          children: [
            Icon(icon, color: scheme.onSurfaceVariant),
            const SizedBox(width: 12),
            Expanded(child: Text(text)),
            ?action,
          ],
        ),
      ),
    );
  }
}

class _ReminderCard extends StatelessWidget {
  const _ReminderCard({
    required this.id,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    required this.children,
  });

  final String id;
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 8, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SwitchListTile(
              key: Key('notif_${id}_switch'),
              contentPadding: EdgeInsets.zero,
              secondary: Icon(icon),
              title: Text(title),
              subtitle: Text(subtitle),
              value: value,
              onChanged: onChanged,
            ),
            for (final child in children) Padding(padding: const EdgeInsets.only(top: 8), child: child),
          ],
        ),
      ),
    );
  }
}

class _TimeRow extends StatelessWidget {
  const _TimeRow({required this.id, required this.label, required this.time, required this.onTap});

  final String id;
  final String label;
  final ReminderTime time;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(label)),
        _TimeButton(buttonKey: Key('notif_${id}_time'), time: time, onTap: onTap),
      ],
    );
  }
}

class _TimeButton extends StatelessWidget {
  const _TimeButton({required this.buttonKey, required this.time, required this.onTap});

  final Key buttonKey;
  final ReminderTime time;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      key: buttonKey,
      icon: const Icon(Icons.schedule, size: 18),
      label: Text(time.label),
      onPressed: onTap,
    );
  }
}
```

Notlar:
- `?action` null-farkında liste girdisi (Dart 3.8+).
- Testteki `time(...)` yardımcısı `OutlinedButton.icon` içindeki `Text`'i okur. Düğmede başka `Text` olmadığı için tek eşleşme beklenir.

- [ ] **Step 5: Ekran testinin geçtiğini gör**

Run: `flutter test --no-pub -j 1 test/features/notifications/presentation/notifications_screen_test.dart`
Expected: PASS (8 test). 360 px'te taşma çıkarsa `_TimeButton`'ı `ConstrainedBox`/`Flexible` ile daralt (S3'teki çözüm gibi). Testi gevşetme.

- [ ] **Step 6: Rota (`lib/core/router.dart`, CRLF)**

Importlara ekle:

```dart
import '../features/notifications/presentation/notifications_screen.dart';
```

Ayarlar rotasının alt rotalarını şu hale getir:

```dart
                    routes: [
                      GoRoute(path: 'goals', builder: (context, state) => const GoalsScreen()),
                      GoRoute(path: 'notifications', builder: (context, state) => const NotificationsScreen()),
                    ],
```

- [ ] **Step 7: Ayarlar satırı testini yaz (`settings_screen_test.dart`)**

`stubRoutes`'a `'/home/settings/notifications': 'notifications-stub'` ekle. Yeni test:

```dart
  testWidgets('the notifications row opens the reminders page', (tester) async {
    await pump(tester);
    await tester.ensureVisible(find.byKey(const Key('settings_notifications')));
    await tester.tap(find.byKey(const Key('settings_notifications')));
    await tester.pumpAndSettle();
    expect(find.text('notifications-stub'), findsOneWidget);
  });
```

Run: `flutter test --no-pub -j 1 test/features/settings/presentation/settings_screen_test.dart`
Expected: yeni test FAIL (satır yok), diğerleri PASS.

- [ ] **Step 8: Ayarlar satırı (`settings_screen.dart`, CRLF)**

`const _LanguageSelector(),` satırının altına, `SectionHeader('settings.section_account'.tr()),` satırının üstüne:

```dart
        SectionHeader('settings.section_notifications'.tr()),
        Card(
          clipBehavior: Clip.antiAlias,
          child: ListTile(
            key: const Key('settings_notifications'),
            leading: const Icon(Icons.notifications_outlined),
            title: Text('settings.row_notifications'.tr()),
            trailing: Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
            onTap: () => context.push('/home/settings/notifications'),
          ),
        ),
```

Dosyanın başındaki yorumu güncelle: "Profil ve ayarlar (G2 spec §4.1): hedef kartı, profil satırları, dil, bildirimler (N1), hesap."

- [ ] **Step 9: Testlerin geçtiğini gör**

Run: `flutter test --no-pub -j 1 test/features/settings/presentation/settings_screen_test.dart test/features/notifications test/core/router_test.dart`
Expected: PASS.

- [ ] **Step 10: Commit**

```bash
git add lib/features/notifications/presentation lib/features/settings/presentation/settings_screen.dart lib/core/router.dart assets/translations test/features/notifications/presentation test/features/settings/presentation/settings_screen_test.dart
git commit -m "feat(notifications): add the reminders page and its settings entry"
```

---

### Task 7: Doğrulama, PLAN.md ve elle kontrol

**Files:**
- Modify: `PLAN.md` (CRLF)

- [ ] **Step 1: Analiz**

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 2: Tam test paketi (kullanıcı)**

Kullanıcıdan kendi terminalinde `flutter test -j 1` çalıştırmasını iste. Beklenen: hepsi geçer (696 + yeni testler).

- [ ] **Step 3: Elle kontrol (kullanıcı, Android telefon USB, `flutter run --release`)**

Spec §7'deki 9 maddelik listeyi kullanıcıya ver:
1. İlk anahtar açılışında izin istenir; reddedince uyarı ve ayarlar düğmesi çıkar.
2. Antrenman: bugünü seç, saati 2 dk sonraya kur → bildirim gelir, metinde antrenman adı var; dokununca Ana sayfa açılır.
3. Antrenmanı bitir → aynı gün yeni saatle kurulan antrenman bildirimi gelmez.
4. Öğün: öğle saatini 2 dk sonraya kur → gelir; öğle öğünü kaydedip tekrar kur → gelmez.
5. Beslenme özeti: öğün yokken "öğün kaydetmedin", protein eksikken "{g} g kaldı"; dokununca Beslenme açılır.
6. Haftalık hedef: bugünü seç → "x/y antrenman" metni.
7. Telefonu yeniden başlat → bekleyen bildirim yine gelir.
8. Dili EN yap → yeni bildirimler İngilizce; çıkış yap → hiçbir bildirim gelmez.
9. Web release'te sayfa "yalnız mobil" notuyla açılır; ~360 px'te taşma yok.

Bir madde başarısız olursa superpowers:systematic-debugging ile kök nedeni bul, düzelt ve hedef testleri yeniden çalıştır.

- [ ] **Step 4: PLAN.md**

`PLAN.md`'deki son günlük satırının (2026-10-11 S3) altına, aynı tablo biçiminde bir satır ekle: `| 2026-10-xx | **F6 N1 (yerel hatırlatıcılar) tamamlandı** (`n1-hatirlaticilar` dalı, 7 görev). ... |`. İçerik: dört hatırlatıcı ve kuralları, 7 günlük ufuk, cihazda ayarlar, Android izin/desugaring, bu plandaki sapmalar (bölüm "Plan kararları"), uygulamada çıkan düzeltmeler, test sayısı, elle kontrol sonucu. Sıradaki: N2 (sosyal push) ya da F6'nın diğer parçaları. Tarihi tamamlanma gününe göre yaz.

- [ ] **Step 5: Commit**

```bash
git add PLAN.md
git commit -m "docs: record N1 local reminders in the plan"
```

Ardından superpowers:finishing-a-development-branch.
