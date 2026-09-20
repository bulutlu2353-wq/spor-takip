# F1 — Auth + Onboarding + Profil Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Kayıt/giriş (email+şifre, Google), onboarding anketi ve TDEE tabanlı günlük kalori/protein hedefi hesabını uçtan uca çalışır hale getirmek.

**Architecture:** Feature-first mimari (`lib/features/onboarding/{domain,application,data,presentation}`), Riverpod ile state/DI, go_router ile auth+profil durumuna göre otomatik yönlendirme, Supabase Auth+Postgres(RLS) ile kalıcılık, easy_localization ile TR/EN altyapısı (şimdilik sadece TR dolu).

**Tech Stack:** Flutter/Dart, Riverpod (`flutter_riverpod ^3.4.3`), `supabase_flutter ^2.17.2`, `go_router ^18.0.1`, `easy_localization` (yeni eklenecek).

**Spec:** `docs/superpowers/specs/2026-09-20-f1-auth-onboarding-design.md`

## Global Constraints

- Feature-first mimari: `lib/features/onboarding/{domain,application,data,presentation}` (F0'da kurulan iskelet).
- Paket adı `spor_takip`; tüm importlar `package:spor_takip/...`.
- TDEE (Mifflin-St Jeor): erkek `10×kilo + 6.25×boy − 5×yaş + 5`; kadın `10×kilo + 6.25×boy − 5×yaş − 161`; belirtilmemiş: ikisinin ortalaması.
- Aktivite çarpanları: sedentary 1.2, light 1.375, moderate 1.55, active 1.725, very_active 1.9.
- Protein hedefi (g/kg): lose_weight 2.0, gain_muscle 2.2, maintain 1.7.
- Onboarding kaydı: **tek seferde** (Approach A) — ara adımlarda Supabase'e yazma YOK, sadece son adımda tek `profiles` upsert'i.
- i18n: `easy_localization`; sadece `tr.json` gerçek içerikle, `en.json` aynı anahtarlarla TR kopyası (F6'ya kadar).
- Gerçek Supabase'e bağlanan entegrasyon testi YAZILMAYACAK; `ProfileRepository`/`AuthRepository` ince sarmalayıcılardır, ayrı testleri yoktur (mantık domain katmanında test edilir).
- RLS: `auth.uid() = user_id` (select/insert/update).
- E-posta doğrulama Supabase dashboard'ında kapalı olacak (kod değişikliği değil, F0 Task 8 çözülünce kullanıcı tarafından ayarlanacak).
- **F0 Task 8 (gerçek Supabase projesi) hâlâ açık.** Bu plandaki tüm kod/test adımları buna bağımlı değildir (gerçek Supabase'e dokunmaz). Sadece Task 4'teki migration'ın gerçek bir projede çalıştırılması ve uygulamanın gerçek cihazda uçtan uca denenmesi Task 8'in tamamlanmasını bekler — bu ayrıca not edilecek.
- Google Sign-In platform kurulumu (Android SHA-1, iOS URL scheme, Supabase provider Client ID/Secret) kullanıcının Google Cloud Console erişimini gerektirir — email/şifre önce tam çalışır hale getirilir (Task 1-16), Google girişi ayrı ve son bir görevdir (Task 17).
- Makine bellek kısıtlı (~4GB RAM) — `flutter analyze`/`flutter test` yavaş çalışabilir (~1-10dk), tek seferde tek flutter komutu çalıştırılmalı, uzun timeout kullanılmalı.
- Commit mesajları: her task'ın commit adımında verilen mesajı **birebir** kullan (önceki fazda tekrar eden bir hata: bazı implementer'lar kendi model adını yazıp Claude-Session satırını atlamıştı — bunu tekrarlama).

---

## Task 1: i18n altyapısı (easy_localization)

**Files:**
- Modify: `pubspec.yaml` (yeni bağımlılık + assets)
- Create: `assets/translations/tr.json`
- Create: `assets/translations/en.json`
- Modify: `lib/main.dart`

**Interfaces:**
- Consumes: Yok
- Produces: `assets/translations/{tr,en}.json` (sonraki tüm ekran görevleri kendi anahtarlarını buraya ekleyecek), `main()` içinde `EasyLocalization` sarmalayıcısı (Task 8 `SporTakipApp`'i `ConsumerWidget`'a çevirip `context.localizationDelegates` vb. ekleyecek)

- [ ] **Step 1: Bağımlılığı ekle**

Run: `flutter pub add easy_localization`
Expected: `Changed X to Y in pubspec.yaml!`

- [ ] **Step 2: Çeviri dosyalarını oluştur**

`assets/translations/tr.json`:
```json
{
  "app": {
    "title": "Spor Takip"
  }
}
```

`assets/translations/en.json` (F6'ya kadar TR kopyası):
```json
{
  "app": {
    "title": "Spor Takip"
  }
}
```

- [ ] **Step 3: pubspec.yaml'a assets ekle**

`pubspec.yaml`'daki mevcut `flutter: assets:` listesine ekle (satır 64-65, mevcut `- .env` satırının yanına):
```yaml
  assets:
    - .env
    - assets/translations/
```

- [ ] **Step 4: main.dart'ı EasyLocalization ile sarmala**

`lib/main.dart`'ın tamamını şu şekilde değiştir (mevcut Supabase init mantığı korunuyor, sadece `EasyLocalization.ensureInitialized()` ve sarmalayıcı ekleniyor; `SporTakipApp` bu adımda DEĞİŞMİYOR, hâlâ eski haliyle kalıyor):

```dart
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'core/supabase_client.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();
  try {
    await dotenv.load(fileName: '.env');
    await AppSupabase.init();
  } catch (error, stackTrace) {
    debugPrint(
      'Failed to load app config from .env. Check that .env exists and '
      'matches the keys in .env.example (SUPABASE_URL, SUPABASE_ANON_KEY): '
      '$error',
    );
    debugPrint('$stackTrace');
    rethrow;
  }
  runApp(
    EasyLocalization(
      supportedLocales: const [Locale('tr'), Locale('en')],
      path: 'assets/translations',
      fallbackLocale: const Locale('tr'),
      child: const SporTakipApp(),
    ),
  );
}

class SporTakipApp extends StatelessWidget {
  const SporTakipApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Spor Takip',
      home: const Scaffold(
        body: Center(child: Text('F0 iskeleti hazır')),
      ),
    );
  }
}
```

- [ ] **Step 5: flutter pub get**

Run: `flutter pub get`
Expected: `Got dependencies!`

- [ ] **Step 6: flutter analyze**

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 7: flutter test**

Run: `flutter test`
Expected: `All tests passed!` (mevcut `test/widget_test.dart` hâlâ `SporTakipApp()`'i doğrudan pump ediyor, `main()`'i çağırmıyor — EasyLocalization'a dokunmuyor, değişmesine gerek yok)

- [ ] **Step 8: Commit**

```bash
git add pubspec.yaml pubspec.lock assets/translations/tr.json assets/translations/en.json lib/main.dart
git commit -m "$(cat <<'EOF'
Add easy_localization i18n infrastructure

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01PDcH7HBWBdAAUWM5Tnp7GU
EOF
)"
```

---

## Task 2: Profil domain modeli

**Files:**
- Create: `lib/features/onboarding/domain/profile.dart`
- Test: `test/features/onboarding/domain/profile_test.dart`

**Interfaces:**
- Consumes: Yok
- Produces: `Gender` (`male`/`female`/`unspecified`), `ActivityLevel` (`sedentary`/`light`/`moderate`/`active`/`veryActive`), `Goal` (`loseWeight`/`gainMuscle`/`maintain`) enum'ları; `Profile` sınıfı (constructor alanları: `userId, weightKg, heightCm, birthYear, gender, activityLevel, doesExercise, sportType, exerciseDaysPerWeek, goal, healthNotes, dailyCalorieTarget, dailyProteinTargetG`), `Profile.fromJson(Map<String, dynamic>)`, `Profile.toJson()` — Task 3, 5, 6, 11+ bunları kullanacak.

- [ ] **Step 1: Failing test yaz**

`test/features/onboarding/domain/profile_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:spor_takip/features/onboarding/domain/profile.dart';

void main() {
  test('Profile fromJson/toJson round-trips DB column names correctly', () {
    final json = {
      'user_id': 'user-1',
      'weight_kg': 80.5,
      'height_cm': 180.0,
      'birth_year': 1996,
      'gender': 'male',
      'activity_level': 'very_active',
      'does_exercise': true,
      'sport_type': 'Fitness',
      'exercise_days_per_week': 4,
      'goal': 'gain_muscle',
      'health_notes': 'Diz sakatlığı geçmişi',
      'daily_calorie_target': 2858.55,
      'daily_protein_target_g': 154.0,
    };

    final profile = Profile.fromJson(json);

    expect(profile.userId, 'user-1');
    expect(profile.weightKg, 80.5);
    expect(profile.heightCm, 180.0);
    expect(profile.birthYear, 1996);
    expect(profile.gender, Gender.male);
    expect(profile.activityLevel, ActivityLevel.veryActive);
    expect(profile.doesExercise, true);
    expect(profile.sportType, 'Fitness');
    expect(profile.exerciseDaysPerWeek, 4);
    expect(profile.goal, Goal.gainMuscle);
    expect(profile.healthNotes, 'Diz sakatlığı geçmişi');
    expect(profile.dailyCalorieTarget, 2858.55);
    expect(profile.dailyProteinTargetG, 154.0);

    expect(profile.toJson(), json);
  });

  test('Profile.fromJson handles null sport_type and health_notes', () {
    final json = {
      'user_id': 'user-2',
      'weight_kg': 60.0,
      'height_cm': 165.0,
      'birth_year': 2001,
      'gender': 'female',
      'activity_level': 'sedentary',
      'does_exercise': false,
      'sport_type': null,
      'exercise_days_per_week': 0,
      'goal': 'lose_weight',
      'health_notes': null,
      'daily_calorie_target': 1345.25,
      'daily_protein_target_g': 120.0,
    };

    final profile = Profile.fromJson(json);

    expect(profile.sportType, isNull);
    expect(profile.healthNotes, isNull);
    expect(profile.toJson(), json);
  });
}
```

- [ ] **Step 2: Testin başarısız olduğunu doğrula**

Run: `flutter test test/features/onboarding/domain/profile_test.dart`
Expected: FAIL — `Error: Couldn't resolve the package 'spor_takip' in 'package:spor_takip/features/onboarding/domain/profile.dart'` (dosya henüz yok)

- [ ] **Step 3: Profile modelini yaz**

`lib/features/onboarding/domain/profile.dart`:
```dart
enum Gender { male, female, unspecified }

enum ActivityLevel { sedentary, light, moderate, active, veryActive }

enum Goal { loseWeight, gainMuscle, maintain }

class Profile {
  const Profile({
    required this.userId,
    required this.weightKg,
    required this.heightCm,
    required this.birthYear,
    required this.gender,
    required this.activityLevel,
    required this.doesExercise,
    this.sportType,
    required this.exerciseDaysPerWeek,
    required this.goal,
    this.healthNotes,
    required this.dailyCalorieTarget,
    required this.dailyProteinTargetG,
  });

  final String userId;
  final double weightKg;
  final double heightCm;
  final int birthYear;
  final Gender gender;
  final ActivityLevel activityLevel;
  final bool doesExercise;
  final String? sportType;
  final int exerciseDaysPerWeek;
  final Goal goal;
  final String? healthNotes;
  final double dailyCalorieTarget;
  final double dailyProteinTargetG;

  factory Profile.fromJson(Map<String, dynamic> json) {
    return Profile(
      userId: json['user_id'] as String,
      weightKg: (json['weight_kg'] as num).toDouble(),
      heightCm: (json['height_cm'] as num).toDouble(),
      birthYear: json['birth_year'] as int,
      gender: Gender.values.byName(json['gender'] as String),
      activityLevel: _activityLevelFromDb(json['activity_level'] as String),
      doesExercise: json['does_exercise'] as bool,
      sportType: json['sport_type'] as String?,
      exerciseDaysPerWeek: json['exercise_days_per_week'] as int,
      goal: _goalFromDb(json['goal'] as String),
      healthNotes: json['health_notes'] as String?,
      dailyCalorieTarget: (json['daily_calorie_target'] as num).toDouble(),
      dailyProteinTargetG: (json['daily_protein_target_g'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'weight_kg': weightKg,
      'height_cm': heightCm,
      'birth_year': birthYear,
      'gender': gender.name,
      'activity_level': _activityLevelToDb(activityLevel),
      'does_exercise': doesExercise,
      'sport_type': sportType,
      'exercise_days_per_week': exerciseDaysPerWeek,
      'goal': _goalToDb(goal),
      'health_notes': healthNotes,
      'daily_calorie_target': dailyCalorieTarget,
      'daily_protein_target_g': dailyProteinTargetG,
    };
  }
}

String _activityLevelToDb(ActivityLevel level) {
  switch (level) {
    case ActivityLevel.sedentary:
      return 'sedentary';
    case ActivityLevel.light:
      return 'light';
    case ActivityLevel.moderate:
      return 'moderate';
    case ActivityLevel.active:
      return 'active';
    case ActivityLevel.veryActive:
      return 'very_active';
  }
}

ActivityLevel _activityLevelFromDb(String value) {
  switch (value) {
    case 'sedentary':
      return ActivityLevel.sedentary;
    case 'light':
      return ActivityLevel.light;
    case 'moderate':
      return ActivityLevel.moderate;
    case 'active':
      return ActivityLevel.active;
    case 'very_active':
      return ActivityLevel.veryActive;
    default:
      throw ArgumentError('Unknown activity_level: $value');
  }
}

String _goalToDb(Goal goal) {
  switch (goal) {
    case Goal.loseWeight:
      return 'lose_weight';
    case Goal.gainMuscle:
      return 'gain_muscle';
    case Goal.maintain:
      return 'maintain';
  }
}

Goal _goalFromDb(String value) {
  switch (value) {
    case 'lose_weight':
      return Goal.loseWeight;
    case 'gain_muscle':
      return Goal.gainMuscle;
    case 'maintain':
      return Goal.maintain;
    default:
      throw ArgumentError('Unknown goal: $value');
  }
}
```

- [ ] **Step 4: Testin geçtiğini doğrula**

Run: `flutter test test/features/onboarding/domain/profile_test.dart`
Expected: `+2: All tests passed!`

- [ ] **Step 5: flutter analyze**

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 6: Commit**

```bash
git add lib/features/onboarding/domain/profile.dart test/features/onboarding/domain/profile_test.dart
git commit -m "$(cat <<'EOF'
Add Profile domain model with DB (de)serialization

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01PDcH7HBWBdAAUWM5Tnp7GU
EOF
)"
```

---

## Task 3: TDEE / Protein Hesaplayıcı

**Files:**
- Create: `lib/features/onboarding/domain/tdee_calculator.dart`
- Test: `test/features/onboarding/domain/tdee_calculator_test.dart`

**Interfaces:**
- Consumes: `Gender`, `ActivityLevel`, `Goal` (Task 2)
- Produces: `TdeeResult` (alanlar: `calorieTarget`, `proteinTargetG`), `TdeeCalculator.calculate({required weightKg, required heightCm, required birthYear, required currentYear, required gender, required activityLevel, required goal})` — Task 11 (`buildProfileFromAnswers`) bunu kullanacak.

- [ ] **Step 1: Failing test yaz**

`test/features/onboarding/domain/tdee_calculator_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:spor_takip/features/onboarding/domain/profile.dart';
import 'package:spor_takip/features/onboarding/domain/tdee_calculator.dart';

void main() {
  const calculator = TdeeCalculator();

  test('male, sedentary, maintain', () {
    final result = calculator.calculate(
      weightKg: 80,
      heightCm: 180,
      birthYear: 1996,
      currentYear: 2026,
      gender: Gender.male,
      activityLevel: ActivityLevel.sedentary,
      goal: Goal.maintain,
    );
    expect(result.calorieTarget, closeTo(2136.0, 0.01));
    expect(result.proteinTargetG, closeTo(136.0, 0.01));
  });

  test('female, moderate, lose_weight', () {
    final result = calculator.calculate(
      weightKg: 60,
      heightCm: 165,
      birthYear: 2001,
      currentYear: 2026,
      gender: Gender.female,
      activityLevel: ActivityLevel.moderate,
      goal: Goal.loseWeight,
    );
    expect(result.calorieTarget, closeTo(2085.1375, 0.01));
    expect(result.proteinTargetG, closeTo(120.0, 0.01));
  });

  test('unspecified gender averages male/female BMR, very_active, gain_muscle', () {
    final result = calculator.calculate(
      weightKg: 70,
      heightCm: 170,
      birthYear: 1990,
      currentYear: 2026,
      gender: Gender.unspecified,
      activityLevel: ActivityLevel.veryActive,
      goal: Goal.gainMuscle,
    );
    expect(result.calorieTarget, closeTo(2858.55, 0.01));
    expect(result.proteinTargetG, closeTo(154.0, 0.01));
  });
}
```

- [ ] **Step 2: Testin başarısız olduğunu doğrula**

Run: `flutter test test/features/onboarding/domain/tdee_calculator_test.dart`
Expected: FAIL — dosya yok

- [ ] **Step 3: TdeeCalculator'ı yaz**

`lib/features/onboarding/domain/tdee_calculator.dart`:
```dart
import 'profile.dart';

class TdeeResult {
  const TdeeResult({required this.calorieTarget, required this.proteinTargetG});

  final double calorieTarget;
  final double proteinTargetG;
}

class TdeeCalculator {
  const TdeeCalculator();

  static const Map<ActivityLevel, double> _activityMultipliers = {
    ActivityLevel.sedentary: 1.2,
    ActivityLevel.light: 1.375,
    ActivityLevel.moderate: 1.55,
    ActivityLevel.active: 1.725,
    ActivityLevel.veryActive: 1.9,
  };

  static const Map<Goal, double> _proteinPerKgByGoal = {
    Goal.loseWeight: 2.0,
    Goal.gainMuscle: 2.2,
    Goal.maintain: 1.7,
  };

  double _bmr({
    required double weightKg,
    required double heightCm,
    required int age,
    required Gender gender,
  }) {
    final base = 10 * weightKg + 6.25 * heightCm - 5 * age;
    switch (gender) {
      case Gender.male:
        return base + 5;
      case Gender.female:
        return base - 161;
      case Gender.unspecified:
        return ((base + 5) + (base - 161)) / 2;
    }
  }

  TdeeResult calculate({
    required double weightKg,
    required double heightCm,
    required int birthYear,
    required int currentYear,
    required Gender gender,
    required ActivityLevel activityLevel,
    required Goal goal,
  }) {
    final age = currentYear - birthYear;
    final bmr = _bmr(
      weightKg: weightKg,
      heightCm: heightCm,
      age: age,
      gender: gender,
    );
    final calorieTarget = bmr * _activityMultipliers[activityLevel]!;
    final proteinTargetG = weightKg * _proteinPerKgByGoal[goal]!;
    return TdeeResult(calorieTarget: calorieTarget, proteinTargetG: proteinTargetG);
  }
}
```

- [ ] **Step 4: Testin geçtiğini doğrula**

Run: `flutter test test/features/onboarding/domain/tdee_calculator_test.dart`
Expected: `+3: All tests passed!`

- [ ] **Step 5: flutter analyze**

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 6: Commit**

```bash
git add lib/features/onboarding/domain/tdee_calculator.dart test/features/onboarding/domain/tdee_calculator_test.dart
git commit -m "$(cat <<'EOF'
Add Mifflin-St Jeor TDEE and protein target calculator

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01PDcH7HBWBdAAUWM5Tnp7GU
EOF
)"
```

---

## Task 4: Supabase `profiles` tablosu migration'ı

**Files:**
- Create: `supabase/migrations/0001_create_profiles.sql`

**Interfaces:**
- Consumes: Yok
- Produces: `profiles` tablosu şeması (Task 5'in `ProfileRepository`'si bu şemaya göre yazılmış olacak) — **bu SQL, F0 Task 8 tamamlanıp gerçek bir Supabase projesi bağlanana kadar hiçbir yerde ÇALIŞTIRILMAZ**, sadece dosya olarak commit edilir.

- [ ] **Step 1: Migration dosyasını yaz**

`supabase/migrations/0001_create_profiles.sql`:
```sql
create table if not exists public.profiles (
  user_id uuid primary key references auth.users (id) on delete cascade,
  weight_kg numeric not null,
  height_cm numeric not null,
  birth_year integer not null,
  gender text not null check (gender in ('male', 'female', 'unspecified')),
  activity_level text not null check (
    activity_level in ('sedentary', 'light', 'moderate', 'active', 'very_active')
  ),
  does_exercise boolean not null,
  sport_type text,
  exercise_days_per_week integer not null check (exercise_days_per_week between 0 and 7),
  goal text not null check (goal in ('lose_weight', 'gain_muscle', 'maintain')),
  health_notes text,
  daily_calorie_target numeric not null,
  daily_protein_target_g numeric not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.profiles enable row level security;

create policy "Users can view own profile"
  on public.profiles for select
  using (auth.uid() = user_id);

create policy "Users can insert own profile"
  on public.profiles for insert
  with check (auth.uid() = user_id);

create policy "Users can update own profile"
  on public.profiles for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);
```

- [ ] **Step 2: flutter analyze (SQL analyze'ı etkilemez, sadece regresyon kontrolü)**

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 3: Commit**

```bash
git add supabase/migrations/0001_create_profiles.sql
git commit -m "$(cat <<'EOF'
Add profiles table migration with RLS policies

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01PDcH7HBWBdAAUWM5Tnp7GU
EOF
)"
```

**Not:** F0 Task 8 tamamlanınca (kullanıcı gerçek Supabase projesi paylaşınca), bu SQL Supabase Dashboard → SQL Editor'de bir kere çalıştırılmalı. Bu adım implementasyon planının dışında, kullanıcı ile birlikte F0 Task 8'in bir uzantısı olarak ele alınacak.

---

## Task 5: ProfileRepository (data katmanı)

**Files:**
- Create: `lib/features/onboarding/data/profile_repository.dart`

**Interfaces:**
- Consumes: `Profile` (Task 2), `profiles` tablosu şeması (Task 4)
- Produces: `ProfileRepository(SupabaseClient)`, `fetchProfile(String userId) → Future<Profile?>`, `saveProfile(Profile) → Future<void>` — Task 7 (`profileProvider`) ve Task 14 (wizard bitirme) bunları kullanacak.
- **Test yok** (kasıtlı): Bu sınıf ince bir Supabase sarmalayıcısıdır, gerçek ağ çağrısı içerir; spec §9 gereği entegrasyon testi yazılmıyor, mantık zaten Task 2/3'te test edildi.

- [ ] **Step 1: ProfileRepository'yi yaz**

`lib/features/onboarding/data/profile_repository.dart`:
```dart
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/profile.dart';

class ProfileRepository {
  ProfileRepository(this._client);

  final SupabaseClient _client;

  static const _table = 'profiles';

  Future<Profile?> fetchProfile(String userId) async {
    final row = await _client
        .from(_table)
        .select()
        .eq('user_id', userId)
        .maybeSingle();
    if (row == null) return null;
    return Profile.fromJson(row);
  }

  Future<void> saveProfile(Profile profile) {
    return _client.from(_table).upsert(profile.toJson());
  }
}
```

- [ ] **Step 2: flutter analyze**

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 3: flutter test (regresyon)**

Run: `flutter test`
Expected: `All tests passed!`

- [ ] **Step 4: Commit**

```bash
git add lib/features/onboarding/data/profile_repository.dart
git commit -m "$(cat <<'EOF'
Add ProfileRepository for Supabase profiles table access

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01PDcH7HBWBdAAUWM5Tnp7GU
EOF
)"
```

---

## Task 6: Auth provider'ları ve repository

**Files:**
- Create: `lib/features/onboarding/application/auth_providers.dart`

**Interfaces:**
- Consumes: `AppSupabase.client` (F0, `lib/core/supabase_client.dart`)
- Produces: `authStateProvider` (`StreamProvider<AuthState>`), `isLoggedInProvider` (`Provider<bool>`), `authRepositoryProvider` (`Provider<AuthRepository>`), `AuthRepository` sınıfı (metodlar: `signUp`, `signIn`, `signOut`, `resetPassword`, `currentUserId` getter) — Task 7 (`isLoggedInProvider`), Task 8 (router), Task 9/10 (login/register ekranları), Task 14 (wizard bitirme, `currentUserId` için) bunları kullanacak.
- **Test yok** (kasıtlı): `AuthRepository` ince bir Supabase Auth sarmalayıcısıdır, spec §9 gereği entegrasyon testi yazılmıyor.

- [ ] **Step 1: auth_providers.dart'ı yaz**

`lib/features/onboarding/application/auth_providers.dart`:
```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase_client.dart';

/// Supabase auth durumundaki değişiklikleri (giriş/çıkış/oturum yenileme)
/// yayınlayan stream.
final authStateProvider = StreamProvider<AuthState>((ref) {
  return AppSupabase.client.auth.onAuthStateChange;
});

/// Şu anda giriş yapılmış bir kullanıcı var mı.
/// Not: Riverpod 3.x'te `AsyncValue.valueOrNull` kaldırıldı, `.value` artık
/// aynı işi görüyor (error/loading durumunda null döner, throw etmez).
final isLoggedInProvider = Provider<bool>((ref) {
  final session = ref.watch(authStateProvider).value?.session;
  return session != null;
});

class AuthRepository {
  AuthRepository(this._client);

  final SupabaseClient _client;

  String get currentUserId {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw StateError('currentUserId çağrıldı ama giriş yapılmış kullanıcı yok');
    }
    return user.id;
  }

  Future<void> signUp({required String email, required String password}) {
    return _client.auth.signUp(email: email, password: password);
  }

  Future<void> signIn({required String email, required String password}) {
    return _client.auth.signInWithPassword(email: email, password: password);
  }

  Future<void> signOut() => _client.auth.signOut();

  Future<void> resetPassword(String email) {
    return _client.auth.resetPasswordForEmail(email);
  }
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(AppSupabase.client);
});
```

- [ ] **Step 2: flutter analyze**

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 3: flutter test (regresyon)**

Run: `flutter test`
Expected: `All tests passed!`

- [ ] **Step 4: Commit**

```bash
git add lib/features/onboarding/application/auth_providers.dart
git commit -m "$(cat <<'EOF'
Add Supabase auth providers and repository

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01PDcH7HBWBdAAUWM5Tnp7GU
EOF
)"
```

---

## Task 7: Profile provider

**Files:**
- Create: `lib/features/onboarding/application/profile_providers.dart`

**Interfaces:**
- Consumes: `isLoggedInProvider` (Task 6), `ProfileRepository` (Task 5), `AppSupabase.client` (F0)
- Produces: `profileRepositoryProvider` (`Provider<ProfileRepository>`), `profileProvider` (`FutureProvider<Profile?>`, null = profil yok/onboarding gerekli) — Task 8 (router), Task 14 (wizard bitirme, `ref.invalidate` için), Task 15 (home ekranı) bunları kullanacak.
- **Test yok** (kasıtlı): sadece provider bağlama (wiring), gerçek mantık Task 5'te.

- [ ] **Step 1: profile_providers.dart'ı yaz**

`lib/features/onboarding/application/profile_providers.dart`:
```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase_client.dart';
import '../data/profile_repository.dart';
import '../domain/profile.dart';
import 'auth_providers.dart';

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepository(AppSupabase.client);
});

/// Giriş yapılmış kullanıcının profilini getirir. Giriş yapılmamışsa veya
/// henüz profil oluşturulmamışsa null döner (onboarding gerekli demektir).
final profileProvider = FutureProvider<Profile?>((ref) async {
  final isLoggedIn = ref.watch(isLoggedInProvider);
  if (!isLoggedIn) return null;
  final userId = AppSupabase.client.auth.currentUser!.id;
  return ref.watch(profileRepositoryProvider).fetchProfile(userId);
});
```

- [ ] **Step 2: flutter analyze**

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 3: flutter test (regresyon)**

Run: `flutter test`
Expected: `All tests passed!`

- [ ] **Step 4: Commit**

```bash
git add lib/features/onboarding/application/profile_providers.dart
git commit -m "$(cat <<'EOF'
Add profile provider wiring auth state to profile fetch

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01PDcH7HBWBdAAUWM5Tnp7GU
EOF
)"
```

---

## Task 8: Yönlendirme mantığı, router, placeholder ekranlar

**Files:**
- Create: `lib/core/redirect_logic.dart`
- Test: `test/core/redirect_logic_test.dart`
- Create: `lib/core/router.dart`
- Create: `lib/features/onboarding/presentation/login_screen.dart` (placeholder — Task 9'da gerçek içerikle değiştirilecek)
- Create: `lib/features/onboarding/presentation/register_screen.dart` (placeholder — Task 10'da gerçek içerikle değiştirilecek)
- Create: `lib/features/onboarding/presentation/onboarding_wizard_screen.dart` (placeholder — Task 14'te gerçek içerikle değiştirilecek)
- Create: `lib/features/onboarding/presentation/home_screen.dart` (placeholder — Task 15'te gerçek içerikle değiştirilecek)
- Modify: `lib/main.dart`
- Modify: `test/widget_test.dart`

**Interfaces:**
- Consumes: `isLoggedInProvider`, `profileProvider` (Task 6, 7)
- Produces: `computeRedirect({required isLoggedIn, required hasProfile, required location}) → String?` (saf fonksiyon), `routerProvider` (`Provider<GoRouter>`) — Task 9-15 ekranları bu router'daki path'lere (`/login`, `/register`, `/onboarding`, `/home`) bağlanacak. `SporTakipApp` artık `ConsumerWidget` ve `MaterialApp.router` kullanıyor.

**Spec notu:** Spec §9 "go_router redirect mantığı — widget test" diyor; burada bunun yerine `computeRedirect`'i saf bir birim testiyle (Step 1-4) doğruluyoruz. Bu kasıtlı bir sadeleştirme: karar mantığının tamamı zaten saf fonksiyonda, go_router'ın kendisi sadece bu fonksiyonu çağıran ince bir sarmalayıcı — birim test aynı davranışı widget pump'lamadan, Riverpod/go_router mock'lamaya gerek kalmadan doğruluyor. Ayrıca Step 8'deki güncellenmiş `widget_test.dart`, en azından bir uçtan-uca senaryoda (`isLoggedIn=false`) router'ın gerçekten doğru ekranı gösterdiğini widget seviyesinde de doğruluyor.

- [ ] **Step 1: Failing test yaz (redirect_logic)**

`test/core/redirect_logic_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:spor_takip/core/redirect_logic.dart';

void main() {
  group('computeRedirect', () {
    test('sends logged-out users to /login from anywhere except auth routes', () {
      expect(
        computeRedirect(isLoggedIn: false, hasProfile: false, location: '/home'),
        '/login',
      );
      expect(
        computeRedirect(isLoggedIn: false, hasProfile: false, location: '/onboarding'),
        '/login',
      );
    });

    test('does not redirect logged-out users already on /login or /register', () {
      expect(computeRedirect(isLoggedIn: false, hasProfile: false, location: '/login'), isNull);
      expect(computeRedirect(isLoggedIn: false, hasProfile: false, location: '/register'), isNull);
    });

    test('sends logged-in users without a profile to /onboarding', () {
      expect(
        computeRedirect(isLoggedIn: true, hasProfile: false, location: '/home'),
        '/onboarding',
      );
      expect(
        computeRedirect(isLoggedIn: true, hasProfile: false, location: '/login'),
        '/onboarding',
      );
    });

    test('does not redirect logged-in profile-less users already on /onboarding', () {
      expect(
        computeRedirect(isLoggedIn: true, hasProfile: false, location: '/onboarding'),
        isNull,
      );
    });

    test('sends fully set-up users away from auth/onboarding routes to /home', () {
      expect(computeRedirect(isLoggedIn: true, hasProfile: true, location: '/login'), '/home');
      expect(
        computeRedirect(isLoggedIn: true, hasProfile: true, location: '/onboarding'),
        '/home',
      );
    });

    test('does not redirect fully set-up users already on /home', () {
      expect(computeRedirect(isLoggedIn: true, hasProfile: true, location: '/home'), isNull);
    });
  });
}
```

- [ ] **Step 2: Testin başarısız olduğunu doğrula**

Run: `flutter test test/core/redirect_logic_test.dart`
Expected: FAIL — dosya yok

- [ ] **Step 3: redirect_logic.dart'ı yaz**

`lib/core/redirect_logic.dart`:
```dart
const _loginPath = '/login';
const _registerPath = '/register';
const _onboardingPath = '/onboarding';
const _homePath = '/home';

/// go_router'ın `redirect` callback'i için saf karar fonksiyonu.
/// Yönlendirme gerekmiyorsa null döner (kullanıcı olduğu yerde kalır).
String? computeRedirect({
  required bool isLoggedIn,
  required bool hasProfile,
  required String location,
}) {
  final isAuthRoute = location == _loginPath || location == _registerPath;

  if (!isLoggedIn) {
    return isAuthRoute ? null : _loginPath;
  }
  if (!hasProfile) {
    return location == _onboardingPath ? null : _onboardingPath;
  }
  if (isAuthRoute || location == _onboardingPath) {
    return _homePath;
  }
  return null;
}
```

- [ ] **Step 4: Testin geçtiğini doğrula**

Run: `flutter test test/core/redirect_logic_test.dart`
Expected: `+6: All tests passed!`

- [ ] **Step 5: Placeholder ekranları oluştur**

`lib/features/onboarding/presentation/login_screen.dart`:
```dart
import 'package:flutter/material.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      key: Key('login_screen'),
      body: Center(child: Text('Login')),
    );
  }
}
```

`lib/features/onboarding/presentation/register_screen.dart`:
```dart
import 'package:flutter/material.dart';

class RegisterScreen extends StatelessWidget {
  const RegisterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      key: Key('register_screen'),
      body: Center(child: Text('Register')),
    );
  }
}
```

`lib/features/onboarding/presentation/onboarding_wizard_screen.dart`:
```dart
import 'package:flutter/material.dart';

class OnboardingWizardScreen extends StatelessWidget {
  const OnboardingWizardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      key: Key('onboarding_screen'),
      body: Center(child: Text('Onboarding')),
    );
  }
}
```

`lib/features/onboarding/presentation/home_screen.dart`:
```dart
import 'package:flutter/material.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      key: Key('home_screen'),
      body: Center(child: Text('Home')),
    );
  }
}
```

- [ ] **Step 6: router.dart'ı yaz**

`lib/core/router.dart`:
```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/onboarding/application/auth_providers.dart';
import '../features/onboarding/application/profile_providers.dart';
import '../features/onboarding/presentation/home_screen.dart';
import '../features/onboarding/presentation/login_screen.dart';
import '../features/onboarding/presentation/onboarding_wizard_screen.dart';
import '../features/onboarding/presentation/register_screen.dart';
import 'redirect_logic.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final isLoggedIn = ref.watch(isLoggedInProvider);
  // Riverpod 3.x: `.value` (not the removed `valueOrNull`) returns null on
  // error/loading — see the same note in Task 6's `isLoggedInProvider`.
  final hasProfile = ref.watch(profileProvider).value != null;

  return GoRouter(
    initialLocation: '/login',
    redirect: (context, state) {
      return computeRedirect(
        isLoggedIn: isLoggedIn,
        hasProfile: hasProfile,
        location: state.uri.path,
      );
    },
    routes: [
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(path: '/register', builder: (context, state) => const RegisterScreen()),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingWizardScreen(),
      ),
      GoRoute(path: '/home', builder: (context, state) => const HomeScreen()),
    ],
  );
});
```

- [ ] **Step 7: main.dart'ı güncelle**

`lib/main.dart`'ın tamamını şu şekilde değiştir (Task 1'deki EasyLocalization sarmalayıcısı korunuyor, `ProviderScope` ekleniyor, `SporTakipApp` artık `ConsumerWidget` ve `MaterialApp.router` kullanıyor, F0'ın "F0 iskeleti hazır" placeholder'ı kalkıyor):

```dart
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router.dart';
import 'core/supabase_client.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();
  try {
    await dotenv.load(fileName: '.env');
    await AppSupabase.init();
  } catch (error, stackTrace) {
    debugPrint(
      'Failed to load app config from .env. Check that .env exists and '
      'matches the keys in .env.example (SUPABASE_URL, SUPABASE_ANON_KEY): '
      '$error',
    );
    debugPrint('$stackTrace');
    rethrow;
  }
  runApp(
    EasyLocalization(
      supportedLocales: const [Locale('tr'), Locale('en')],
      path: 'assets/translations',
      fallbackLocale: const Locale('tr'),
      child: const ProviderScope(child: SporTakipApp()),
    ),
  );
}

class SporTakipApp extends ConsumerWidget {
  const SporTakipApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'Spor Takip',
      routerConfig: router,
      localizationsDelegates: context.localizationDelegates,
      supportedLocales: context.supportedLocales,
      locale: context.locale,
    );
  }
}
```

- [ ] **Step 8: widget_test.dart'ı güncelle**

F0'ın "F0 iskeleti hazır" testi artık geçersiz (o ekran kalkıyor). Yerine, giriş yapılmamış bir kullanıcının login ekranını gördüğünü doğrulayan bir smoke test yaz — `authStateProvider`'ı sahte bir "signed out" stream'iyle override ederek gerçek Supabase'e dokunulmaz:

`test/widget_test.dart`:
```dart
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:spor_takip/features/onboarding/application/auth_providers.dart';
import 'package:spor_takip/main.dart';

void main() {
  setUpAll(() async {
    await EasyLocalization.ensureInitialized();
  });

  testWidgets('Unauthenticated user sees the login screen', (tester) async {
    await tester.pumpWidget(
      EasyLocalization(
        supportedLocales: const [Locale('tr'), Locale('en')],
        path: 'assets/translations',
        fallbackLocale: const Locale('tr'),
        child: ProviderScope(
          overrides: [
            authStateProvider.overrideWith(
              (ref) => Stream.value(
                const AuthState(AuthChangeEvent.signedOut, null),
              ),
            ),
          ],
          child: const SporTakipApp(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('login_screen')), findsOneWidget);
  });
}
```

- [ ] **Step 9: flutter pub get**

Run: `flutter pub get`
Expected: `Got dependencies!`

- [ ] **Step 10: flutter analyze**

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 11: flutter test**

Run: `flutter test`
Expected: `+7: All tests passed!` (6'sı redirect_logic'ten, 1'i güncellenmiş widget_test'ten — Profile/TDEE testleri Task 2/3'ten ayrı dosyalarda zaten sayılıyor, toplamda daha fazla olabilir; önemli olan hiç FAIL olmaması)

- [ ] **Step 12: Commit**

```bash
git add lib/core/redirect_logic.dart test/core/redirect_logic_test.dart lib/core/router.dart lib/features/onboarding/presentation/login_screen.dart lib/features/onboarding/presentation/register_screen.dart lib/features/onboarding/presentation/onboarding_wizard_screen.dart lib/features/onboarding/presentation/home_screen.dart lib/main.dart test/widget_test.dart
git commit -m "$(cat <<'EOF'
Add auth/profile-aware router with placeholder screens

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01PDcH7HBWBdAAUWM5Tnp7GU
EOF
)"
```

---

## Task 9: Giriş ekranı (Login)

**Files:**
- Modify: `lib/features/onboarding/presentation/login_screen.dart` (Task 8'in placeholder'ını tamamen değiştirir)
- Modify: `assets/translations/tr.json`
- Modify: `assets/translations/en.json`

**Interfaces:**
- Consumes: `authRepositoryProvider` (Task 6)
- Produces: Yok (terminal UI ekranı)

- [ ] **Step 1: tr.json'a auth anahtarlarını ekle**

`assets/translations/tr.json`'ı şu şekilde güncelle (mevcut `app` bloğu korunuyor):
```json
{
  "app": {
    "title": "Spor Takip"
  },
  "auth": {
    "login_title": "Giriş Yap",
    "email_label": "E-posta",
    "password_label": "Şifre",
    "login_button": "Giriş Yap",
    "forgot_password": "Şifremi unuttum",
    "go_to_register": "Hesabın yok mu? Kayıt ol",
    "enter_email_first": "Önce e-posta adresini gir",
    "reset_email_sent": "Şifre sıfırlama e-postası gönderildi",
    "invalid_credentials": "E-posta veya şifre hatalı",
    "unknown_error": "Bir hata oluştu, tekrar dene"
  }
}
```

`assets/translations/en.json`'ı **aynı içerikle** (TR kopyası, F6'ya kadar) güncelle:
```json
{
  "app": {
    "title": "Spor Takip"
  },
  "auth": {
    "login_title": "Giriş Yap",
    "email_label": "E-posta",
    "password_label": "Şifre",
    "login_button": "Giriş Yap",
    "forgot_password": "Şifremi unuttum",
    "go_to_register": "Hesabın yok mu? Kayıt ol",
    "enter_email_first": "Önce e-posta adresini gir",
    "reset_email_sent": "Şifre sıfırlama e-postası gönderildi",
    "invalid_credentials": "E-posta veya şifre hatalı",
    "unknown_error": "Bir hata oluştu, tekrar dene"
  }
}
```

- [ ] **Step 2: LoginScreen'i tam içerikle yaz**

`lib/features/onboarding/presentation/login_screen.dart`'ın tamamını değiştir:
```dart
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../application/auth_providers.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });
    try {
      await ref.read(authRepositoryProvider).signIn(
            email: _emailController.text.trim(),
            password: _passwordController.text,
          );
    } on AuthException catch (error) {
      setState(() => _errorMessage = _messageForAuthError(error));
    } catch (_) {
      setState(() => _errorMessage = 'auth.unknown_error'.tr());
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _forgotPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      setState(() => _errorMessage = 'auth.enter_email_first'.tr());
      return;
    }
    try {
      await ref.read(authRepositoryProvider).resetPassword(email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('auth.reset_email_sent'.tr())),
        );
      }
    } catch (_) {
      setState(() => _errorMessage = 'auth.unknown_error'.tr());
    }
  }

  String _messageForAuthError(AuthException error) {
    switch (error.code) {
      case 'invalid_credentials':
        return 'auth.invalid_credentials'.tr();
      default:
        return error.message;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('login_screen'),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('auth.login_title'.tr(), style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 24),
            TextField(
              key: const Key('login_email_field'),
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(labelText: 'auth.email_label'.tr()),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('login_password_field'),
              controller: _passwordController,
              obscureText: true,
              decoration: InputDecoration(labelText: 'auth.password_label'.tr()),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 24),
            ElevatedButton(
              key: const Key('login_submit_button'),
              onPressed: _isSubmitting ? null : _submit,
              child: _isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text('auth.login_button'.tr()),
            ),
            TextButton(
              onPressed: _isSubmitting ? null : _forgotPassword,
              child: Text('auth.forgot_password'.tr()),
            ),
            TextButton(
              key: const Key('login_go_to_register_button'),
              onPressed: () => context.push('/register'),
              child: Text('auth.go_to_register'.tr()),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 3: flutter analyze**

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 4: flutter test (regresyon)**

Run: `flutter test`
Expected: `All tests passed!` (Task 8'in widget_test'i hâlâ `find.byKey(Key('login_screen'))` arıyor, `Key` korunduğu için geçmeye devam eder)

- [ ] **Step 5: Commit**

```bash
git add lib/features/onboarding/presentation/login_screen.dart assets/translations/tr.json assets/translations/en.json
git commit -m "$(cat <<'EOF'
Implement login screen with email/password and password reset

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01PDcH7HBWBdAAUWM5Tnp7GU
EOF
)"
```

---

## Task 10: Kayıt ekranı (Register)

**Files:**
- Modify: `lib/features/onboarding/presentation/register_screen.dart` (Task 8'in placeholder'ını tamamen değiştirir)
- Modify: `assets/translations/tr.json`
- Modify: `assets/translations/en.json`

**Interfaces:**
- Consumes: `authRepositoryProvider` (Task 6)
- Produces: Yok (terminal UI ekranı). Not: `signUp` başarılı olduğunda (e-posta doğrulama kapalı olduğu için) Supabase oturumu hemen açar; `authStateProvider` bunu otomatik yakalar ve router kullanıcıyı `/onboarding`'e yönlendirir — ekranın kendisi manuel navigasyon yapmaz.

- [ ] **Step 1: tr.json/en.json'a register anahtarlarını ekle**

`assets/translations/tr.json`'daki `auth` bloğuna ekle (mevcut anahtarlar korunuyor):
```json
{
  "app": {
    "title": "Spor Takip"
  },
  "auth": {
    "login_title": "Giriş Yap",
    "email_label": "E-posta",
    "password_label": "Şifre",
    "login_button": "Giriş Yap",
    "forgot_password": "Şifremi unuttum",
    "go_to_register": "Hesabın yok mu? Kayıt ol",
    "enter_email_first": "Önce e-posta adresini gir",
    "reset_email_sent": "Şifre sıfırlama e-postası gönderildi",
    "invalid_credentials": "E-posta veya şifre hatalı",
    "unknown_error": "Bir hata oluştu, tekrar dene",
    "register_title": "Kayıt Ol",
    "confirm_password_label": "Şifre (tekrar)",
    "register_button": "Kayıt Ol",
    "go_to_login": "Zaten hesabın var mı? Giriş yap",
    "passwords_dont_match": "Şifreler eşleşmiyor",
    "email_already_registered": "Bu e-posta zaten kayıtlı",
    "weak_password": "Şifre çok zayıf, daha güçlü bir şifre seç"
  }
}
```

`assets/translations/en.json`'ı **aynı içerikle** güncelle (yukarıdaki JSON'un birebir aynısı).

- [ ] **Step 2: RegisterScreen'i tam içerikle yaz**

`lib/features/onboarding/presentation/register_screen.dart`'ın tamamını değiştir:
```dart
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../application/auth_providers.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_passwordController.text != _confirmPasswordController.text) {
      setState(() => _errorMessage = 'auth.passwords_dont_match'.tr());
      return;
    }
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });
    try {
      await ref.read(authRepositoryProvider).signUp(
            email: _emailController.text.trim(),
            password: _passwordController.text,
          );
    } on AuthException catch (error) {
      setState(() => _errorMessage = _messageForAuthError(error));
    } catch (_) {
      setState(() => _errorMessage = 'auth.unknown_error'.tr());
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  String _messageForAuthError(AuthException error) {
    switch (error.code) {
      case 'user_already_exists':
        return 'auth.email_already_registered'.tr();
      case 'weak_password':
        return 'auth.weak_password'.tr();
      default:
        return error.message;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('register_screen'),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'auth.register_title'.tr(),
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 24),
            TextField(
              key: const Key('register_email_field'),
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(labelText: 'auth.email_label'.tr()),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('register_password_field'),
              controller: _passwordController,
              obscureText: true,
              decoration: InputDecoration(labelText: 'auth.password_label'.tr()),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('register_confirm_password_field'),
              controller: _confirmPasswordController,
              obscureText: true,
              decoration: InputDecoration(labelText: 'auth.confirm_password_label'.tr()),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 24),
            ElevatedButton(
              key: const Key('register_submit_button'),
              onPressed: _isSubmitting ? null : _submit,
              child: _isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text('auth.register_button'.tr()),
            ),
            TextButton(
              onPressed: () => context.pop(),
              child: Text('auth.go_to_login'.tr()),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 3: flutter analyze**

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 4: flutter test (regresyon)**

Run: `flutter test`
Expected: `All tests passed!`

- [ ] **Step 5: Commit**

```bash
git add lib/features/onboarding/presentation/register_screen.dart assets/translations/tr.json assets/translations/en.json
git commit -m "$(cat <<'EOF'
Implement register screen with email/password sign-up

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01PDcH7HBWBdAAUWM5Tnp7GU
EOF
)"
```

---

## Task 11: Onboarding cevapları, adım sıralaması, notifier ve profil oluşturma

**Files:**
- Create: `lib/features/onboarding/domain/onboarding_answers.dart`
- Create: `lib/features/onboarding/domain/onboarding_steps.dart`
- Create: `lib/features/onboarding/application/onboarding_wizard_notifier.dart`
- Test: `test/features/onboarding/domain/onboarding_steps_test.dart`
- Test: `test/features/onboarding/application/onboarding_wizard_notifier_test.dart`

**Interfaces:**
- Consumes: `Gender`, `ActivityLevel`, `Goal`, `Profile` (Task 2), `TdeeCalculator` (Task 3)
- Produces: `OnboardingAnswers` (tüm alanlar nullable, `copyWith`, `isComplete` getter), `OnboardingStepId` enum (10 değer), `visibleSteps(OnboardingAnswers) → List<OnboardingStepId>` (saf fonksiyon, koşullu adım atlama), `onboardingWizardProvider` (`NotifierProvider<OnboardingWizardNotifier, OnboardingAnswers>`), `buildProfileFromAnswers({required answers, required userId, required currentYear}) → Profile` (saf fonksiyon) — Task 12 (step widget'ları), Task 13 (wizard shell) bunları kullanacak.

- [ ] **Step 1: Failing test yaz (visibleSteps)**

`test/features/onboarding/domain/onboarding_steps_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:spor_takip/features/onboarding/domain/onboarding_answers.dart';
import 'package:spor_takip/features/onboarding/domain/onboarding_steps.dart';

void main() {
  group('visibleSteps', () {
    test('excludes sportType and exerciseDays when doesExercise is false', () {
      const answers = OnboardingAnswers(doesExercise: false);
      final steps = visibleSteps(answers);
      expect(steps, isNot(contains(OnboardingStepId.sportType)));
      expect(steps, isNot(contains(OnboardingStepId.exerciseDays)));
    });

    test('includes sportType and exerciseDays when doesExercise is true', () {
      const answers = OnboardingAnswers(doesExercise: true);
      final steps = visibleSteps(answers);
      expect(steps, contains(OnboardingStepId.sportType));
      expect(steps, contains(OnboardingStepId.exerciseDays));
    });

    test('includes all 8 unconditional steps regardless of doesExercise', () {
      const answers = OnboardingAnswers();
      final steps = visibleSteps(answers);
      expect(
        steps,
        containsAll(const [
          OnboardingStepId.weight,
          OnboardingStepId.height,
          OnboardingStepId.birthYear,
          OnboardingStepId.gender,
          OnboardingStepId.activityLevel,
          OnboardingStepId.doesExercise,
          OnboardingStepId.goal,
          OnboardingStepId.healthNotes,
        ]),
      );
    });

    test('healthNotes is always the last step', () {
      expect(visibleSteps(const OnboardingAnswers()).last, OnboardingStepId.healthNotes);
      expect(
        visibleSteps(const OnboardingAnswers(doesExercise: true)).last,
        OnboardingStepId.healthNotes,
      );
    });
  });
}
```

- [ ] **Step 2: Testin başarısız olduğunu doğrula**

Run: `flutter test test/features/onboarding/domain/onboarding_steps_test.dart`
Expected: FAIL — dosyalar yok

- [ ] **Step 3: OnboardingAnswers'ı yaz**

`lib/features/onboarding/domain/onboarding_answers.dart`:
```dart
import 'profile.dart';

class OnboardingAnswers {
  const OnboardingAnswers({
    this.weightKg,
    this.heightCm,
    this.birthYear,
    this.gender,
    this.activityLevel,
    this.doesExercise,
    this.sportType,
    this.exerciseDaysPerWeek,
    this.goal,
    this.healthNotes,
  });

  final double? weightKg;
  final double? heightCm;
  final int? birthYear;
  final Gender? gender;
  final ActivityLevel? activityLevel;
  final bool? doesExercise;
  final String? sportType;
  final int? exerciseDaysPerWeek;
  final Goal? goal;
  final String? healthNotes;

  OnboardingAnswers copyWith({
    double? weightKg,
    double? heightCm,
    int? birthYear,
    Gender? gender,
    ActivityLevel? activityLevel,
    bool? doesExercise,
    String? sportType,
    int? exerciseDaysPerWeek,
    Goal? goal,
    String? healthNotes,
  }) {
    return OnboardingAnswers(
      weightKg: weightKg ?? this.weightKg,
      heightCm: heightCm ?? this.heightCm,
      birthYear: birthYear ?? this.birthYear,
      gender: gender ?? this.gender,
      activityLevel: activityLevel ?? this.activityLevel,
      doesExercise: doesExercise ?? this.doesExercise,
      sportType: sportType ?? this.sportType,
      exerciseDaysPerWeek: exerciseDaysPerWeek ?? this.exerciseDaysPerWeek,
      goal: goal ?? this.goal,
      healthNotes: healthNotes ?? this.healthNotes,
    );
  }

  bool get isComplete =>
      weightKg != null &&
      heightCm != null &&
      birthYear != null &&
      gender != null &&
      activityLevel != null &&
      doesExercise != null &&
      (doesExercise == false ||
          (sportType != null && exerciseDaysPerWeek != null)) &&
      goal != null;
}
```

- [ ] **Step 4: onboarding_steps.dart'ı yaz**

`lib/features/onboarding/domain/onboarding_steps.dart`:
```dart
import 'onboarding_answers.dart';

enum OnboardingStepId {
  weight,
  height,
  birthYear,
  gender,
  activityLevel,
  doesExercise,
  sportType,
  exerciseDays,
  goal,
  healthNotes,
}

/// Mevcut cevaplara göre gösterilecek adımların sırasını döner.
/// [OnboardingStepId.sportType] ve [OnboardingStepId.exerciseDays] sadece
/// `doesExercise == true` ise gösterilir.
List<OnboardingStepId> visibleSteps(OnboardingAnswers answers) {
  return [
    OnboardingStepId.weight,
    OnboardingStepId.height,
    OnboardingStepId.birthYear,
    OnboardingStepId.gender,
    OnboardingStepId.activityLevel,
    OnboardingStepId.doesExercise,
    if (answers.doesExercise == true) OnboardingStepId.sportType,
    if (answers.doesExercise == true) OnboardingStepId.exerciseDays,
    OnboardingStepId.goal,
    OnboardingStepId.healthNotes,
  ];
}
```

- [ ] **Step 5: visibleSteps testinin geçtiğini doğrula**

Run: `flutter test test/features/onboarding/domain/onboarding_steps_test.dart`
Expected: `+4: All tests passed!`

- [ ] **Step 6: Failing test yaz (buildProfileFromAnswers ve notifier)**

`test/features/onboarding/application/onboarding_wizard_notifier_test.dart`:
```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spor_takip/features/onboarding/application/onboarding_wizard_notifier.dart';
import 'package:spor_takip/features/onboarding/domain/onboarding_answers.dart';
import 'package:spor_takip/features/onboarding/domain/profile.dart';

void main() {
  test('buildProfileFromAnswers computes targets and maps fields', () {
    const answers = OnboardingAnswers(
      weightKg: 80,
      heightCm: 180,
      birthYear: 1996,
      gender: Gender.male,
      activityLevel: ActivityLevel.sedentary,
      doesExercise: true,
      sportType: 'Fitness',
      exerciseDaysPerWeek: 3,
      goal: Goal.maintain,
      healthNotes: null,
    );

    final profile = buildProfileFromAnswers(
      answers: answers,
      userId: 'user-1',
      currentYear: 2026,
    );

    expect(profile.userId, 'user-1');
    expect(profile.sportType, 'Fitness');
    expect(profile.exerciseDaysPerWeek, 3);
    expect(profile.dailyCalorieTarget, closeTo(2136.0, 0.01));
    expect(profile.dailyProteinTargetG, closeTo(136.0, 0.01));
  });

  test('buildProfileFromAnswers nulls out sportType when doesExercise is false', () {
    const answers = OnboardingAnswers(
      weightKg: 60,
      heightCm: 165,
      birthYear: 2001,
      gender: Gender.female,
      activityLevel: ActivityLevel.moderate,
      doesExercise: false,
      sportType: null,
      exerciseDaysPerWeek: null,
      goal: Goal.loseWeight,
      healthNotes: 'Diz sakatlığı geçmişi',
    );

    final profile = buildProfileFromAnswers(
      answers: answers,
      userId: 'user-2',
      currentYear: 2026,
    );

    expect(profile.sportType, isNull);
    expect(profile.exerciseDaysPerWeek, 0);
    expect(profile.healthNotes, 'Diz sakatlığı geçmişi');
  });

  test('OnboardingWizardNotifier starts empty and updates via copyWith', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(onboardingWizardProvider).weightKg, isNull);

    container
        .read(onboardingWizardProvider.notifier)
        .update((answers) => answers.copyWith(weightKg: 80));

    expect(container.read(onboardingWizardProvider).weightKg, 80);
  });
}
```

- [ ] **Step 7: Testin başarısız olduğunu doğrula**

Run: `flutter test test/features/onboarding/application/onboarding_wizard_notifier_test.dart`
Expected: FAIL — dosya yok

- [ ] **Step 8: onboarding_wizard_notifier.dart'ı yaz**

`lib/features/onboarding/application/onboarding_wizard_notifier.dart`:
```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/onboarding_answers.dart';
import '../domain/profile.dart';
import '../domain/tdee_calculator.dart';

final onboardingWizardProvider =
    NotifierProvider<OnboardingWizardNotifier, OnboardingAnswers>(
  OnboardingWizardNotifier.new,
);

class OnboardingWizardNotifier extends Notifier<OnboardingAnswers> {
  @override
  OnboardingAnswers build() => const OnboardingAnswers();

  void update(OnboardingAnswers Function(OnboardingAnswers) updater) {
    state = updater(state);
  }
}

/// [answers.isComplete] olduğu varsayılarak, hesaplanan hedeflerle birlikte
/// kaydedilmeye hazır bir [Profile] üretir. Saf fonksiyon — Supabase'e
/// dokunmaz, ayrıca çağıran taraf `saveProfile` ile kaydeder.
Profile buildProfileFromAnswers({
  required OnboardingAnswers answers,
  required String userId,
  required int currentYear,
  TdeeCalculator calculator = const TdeeCalculator(),
}) {
  assert(answers.isComplete, 'buildProfileFromAnswers tamamlanmamış cevaplarla çağrıldı');
  final doesExercise = answers.doesExercise!;
  final result = calculator.calculate(
    weightKg: answers.weightKg!,
    heightCm: answers.heightCm!,
    birthYear: answers.birthYear!,
    currentYear: currentYear,
    gender: answers.gender!,
    activityLevel: answers.activityLevel!,
    goal: answers.goal!,
  );
  return Profile(
    userId: userId,
    weightKg: answers.weightKg!,
    heightCm: answers.heightCm!,
    birthYear: answers.birthYear!,
    gender: answers.gender!,
    activityLevel: answers.activityLevel!,
    doesExercise: doesExercise,
    sportType: doesExercise ? answers.sportType : null,
    exerciseDaysPerWeek: doesExercise ? answers.exerciseDaysPerWeek! : 0,
    goal: answers.goal!,
    healthNotes: answers.healthNotes,
    dailyCalorieTarget: result.calorieTarget,
    dailyProteinTargetG: result.proteinTargetG,
  );
}
```

- [ ] **Step 9: Testin geçtiğini doğrula**

Run: `flutter test test/features/onboarding/application/onboarding_wizard_notifier_test.dart`
Expected: `+3: All tests passed!`

- [ ] **Step 10: flutter analyze**

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 11: flutter test (regresyon, tüm suite)**

Run: `flutter test`
Expected: `All tests passed!`

- [ ] **Step 12: Commit**

```bash
git add lib/features/onboarding/domain/onboarding_answers.dart lib/features/onboarding/domain/onboarding_steps.dart lib/features/onboarding/application/onboarding_wizard_notifier.dart test/features/onboarding/domain/onboarding_steps_test.dart test/features/onboarding/application/onboarding_wizard_notifier_test.dart
git commit -m "$(cat <<'EOF'
Add onboarding wizard state, step sequencing, and profile builder

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01PDcH7HBWBdAAUWM5Tnp7GU
EOF
)"
```

---

## Task 12: Yeniden kullanılabilir onboarding adım iskeletleri

**Files:**
- Create: `lib/features/onboarding/presentation/steps/step_scaffolds.dart`
- Test: `test/features/onboarding/presentation/steps/step_scaffolds_test.dart`
- Modify: `assets/translations/tr.json`
- Modify: `assets/translations/en.json`

**Interfaces:**
- Consumes: Yok (saf Flutter widget'ları)
- Produces: `WizardStepScaffold` (ortak sayfa iskeleti: ilerleme çubuğu, başlık, İleri/Bitir butonu, geri butonu), `NumericStepScreen` (sayısal girdi, min/max validasyonu), `ChoiceStepScreen<T>` (tekli seçim listesi), `TextStepScreen` (serbest metin, `required` bayrağıyla zorunlu/opsiyonel) — Task 13'teki 10 somut adım widget'ı bunları kullanacak.

- [ ] **Step 1: tr.json/en.json'a ortak wizard anahtarlarını ekle**

`assets/translations/tr.json`'a `onboarding` bloğu ekle (mevcut `app`/`auth` blokları korunuyor):
```json
{
  "app": {
    "title": "Spor Takip"
  },
  "auth": {
    "login_title": "Giriş Yap",
    "email_label": "E-posta",
    "password_label": "Şifre",
    "login_button": "Giriş Yap",
    "forgot_password": "Şifremi unuttum",
    "go_to_register": "Hesabın yok mu? Kayıt ol",
    "enter_email_first": "Önce e-posta adresini gir",
    "reset_email_sent": "Şifre sıfırlama e-postası gönderildi",
    "invalid_credentials": "E-posta veya şifre hatalı",
    "unknown_error": "Bir hata oluştu, tekrar dene",
    "register_title": "Kayıt Ol",
    "confirm_password_label": "Şifre (tekrar)",
    "register_button": "Kayıt Ol",
    "go_to_login": "Zaten hesabın var mı? Giriş yap",
    "passwords_dont_match": "Şifreler eşleşmiyor",
    "email_already_registered": "Bu e-posta zaten kayıtlı",
    "weak_password": "Şifre çok zayıf, daha güçlü bir şifre seç"
  },
  "onboarding": {
    "step_of": "Adım {current}/{total}",
    "next": "İleri",
    "finish": "Bitir",
    "retry": "Tekrar dene"
  }
}
```

`assets/translations/en.json`'ı **aynı içerikle** güncelle (yukarıdaki JSON'un birebir aynısı).

- [ ] **Step 2: Failing test yaz (NumericStepScreen validasyonu)**

`test/features/onboarding/presentation/steps/step_scaffolds_test.dart`:
```dart
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spor_takip/features/onboarding/presentation/steps/step_scaffolds.dart';

void main() {
  setUpAll(() async {
    await EasyLocalization.ensureInitialized();
  });

  Widget wrap(Widget child) {
    return EasyLocalization(
      supportedLocales: const [Locale('tr'), Locale('en')],
      path: 'assets/translations',
      fallbackLocale: const Locale('tr'),
      child: MaterialApp(home: child),
    );
  }

  testWidgets('Next button disabled until a value within range is entered', (tester) async {
    double? saved;
    var nextTapped = false;

    await tester.pumpWidget(
      wrap(
        NumericStepScreen(
          title: 'Test',
          hintText: 'Değer gir',
          min: 20,
          max: 300,
          initialValue: null,
          onSave: (value) => saved = value,
          onNext: () => nextTapped = true,
          onBack: null,
          stepNumber: 1,
          totalSteps: 1,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final nextButton = find.byKey(const Key('wizard_next_button'));
    expect(tester.widget<ElevatedButton>(nextButton).onPressed, isNull);

    await tester.enterText(find.byKey(const Key('numeric_step_field')), '75');
    await tester.pump();

    expect(tester.widget<ElevatedButton>(nextButton).onPressed, isNotNull);

    await tester.tap(nextButton);
    expect(saved, 75.0);
    expect(nextTapped, isTrue);
  });

  testWidgets('Next button stays disabled for an out-of-range value', (tester) async {
    await tester.pumpWidget(
      wrap(
        NumericStepScreen(
          title: 'Test',
          hintText: 'Değer gir',
          min: 20,
          max: 300,
          initialValue: null,
          onSave: (_) {},
          onNext: () {},
          onBack: null,
          stepNumber: 1,
          totalSteps: 1,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('numeric_step_field')), '5');
    await tester.pump();

    final nextButton = find.byKey(const Key('wizard_next_button'));
    expect(tester.widget<ElevatedButton>(nextButton).onPressed, isNull);
  });

  testWidgets('ChoiceStepScreen: Next button disabled until an option is selected', (tester) async {
    String? selected;
    await tester.pumpWidget(
      wrap(
        ChoiceStepScreen<String>(
          title: 'Test',
          options: const [('a', 'Seçenek A'), ('b', 'Seçenek B')],
          selected: null,
          onSave: (value) => selected = value,
          onNext: () {},
          onBack: null,
          stepNumber: 1,
          totalSteps: 1,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final nextButton = find.byKey(const Key('wizard_next_button'));
    expect(tester.widget<ElevatedButton>(nextButton).onPressed, isNull);

    await tester.tap(find.byKey(const Key('choice_option_a')));
    await tester.pump();

    expect(selected, 'a');
  });

  testWidgets('TextStepScreen: required=true disables Next until non-empty text', (tester) async {
    await tester.pumpWidget(
      wrap(
        TextStepScreen(
          title: 'Test',
          hintText: 'Yaz',
          initialValue: null,
          required: true,
          onSave: (_) {},
          onNext: () {},
          onBack: null,
          stepNumber: 1,
          totalSteps: 1,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final nextButton = find.byKey(const Key('wizard_next_button'));
    expect(tester.widget<ElevatedButton>(nextButton).onPressed, isNull);

    await tester.enterText(find.byKey(const Key('text_step_field')), 'Fitness');
    await tester.pump();

    expect(tester.widget<ElevatedButton>(nextButton).onPressed, isNotNull);
  });

  testWidgets('TextStepScreen: required=false leaves Next enabled when empty', (tester) async {
    await tester.pumpWidget(
      wrap(
        TextStepScreen(
          title: 'Test',
          hintText: 'Yaz',
          initialValue: null,
          required: false,
          onSave: (_) {},
          onNext: () {},
          onBack: null,
          stepNumber: 1,
          totalSteps: 1,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final nextButton = find.byKey(const Key('wizard_next_button'));
    expect(tester.widget<ElevatedButton>(nextButton).onPressed, isNotNull);
  });
}
```

- [ ] **Step 3: Testin başarısız olduğunu doğrula**

Run: `flutter test test/features/onboarding/presentation/steps/step_scaffolds_test.dart`
Expected: FAIL — dosya yok

- [ ] **Step 4: step_scaffolds.dart'ı yaz**

`lib/features/onboarding/presentation/steps/step_scaffolds.dart`:
```dart
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

class WizardStepScaffold extends StatelessWidget {
  const WizardStepScaffold({
    super.key,
    required this.title,
    required this.child,
    required this.isValid,
    required this.onNext,
    required this.onBack,
    required this.stepNumber,
    required this.totalSteps,
    this.nextLabel,
  });

  final String title;
  final Widget child;
  final bool isValid;
  final VoidCallback onNext;
  final VoidCallback? onBack;
  final int stepNumber;
  final int totalSteps;
  final String? nextLabel;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: onBack == null
            ? null
            : IconButton(icon: const Icon(Icons.arrow_back), onPressed: onBack),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LinearProgressIndicator(value: stepNumber / totalSteps),
            const SizedBox(height: 8),
            Text(
              'onboarding.step_of'.tr(namedArgs: {
                'current': stepNumber.toString(),
                'total': totalSteps.toString(),
              }),
            ),
            const SizedBox(height: 24),
            Text(title, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 24),
            Expanded(child: child),
            ElevatedButton(
              key: const Key('wizard_next_button'),
              onPressed: isValid ? onNext : null,
              child: Text(nextLabel ?? 'onboarding.next'.tr()),
            ),
          ],
        ),
      ),
    );
  }
}

class NumericStepScreen extends StatefulWidget {
  const NumericStepScreen({
    super.key,
    required this.title,
    required this.hintText,
    required this.min,
    required this.max,
    required this.initialValue,
    required this.onSave,
    required this.onNext,
    required this.onBack,
    required this.stepNumber,
    required this.totalSteps,
  });

  final String title;
  final String hintText;
  final double min;
  final double max;
  final double? initialValue;
  final ValueChanged<double> onSave;
  final VoidCallback onNext;
  final VoidCallback? onBack;
  final int stepNumber;
  final int totalSteps;

  @override
  State<NumericStepScreen> createState() => _NumericStepScreenState();
}

class _NumericStepScreenState extends State<NumericStepScreen> {
  late final TextEditingController _controller;
  double? _value;

  @override
  void initState() {
    super.initState();
    _value = widget.initialValue;
    _controller = TextEditingController(text: widget.initialValue?.toString() ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _isValid => _value != null && _value! >= widget.min && _value! <= widget.max;

  @override
  Widget build(BuildContext context) {
    return WizardStepScaffold(
      title: widget.title,
      stepNumber: widget.stepNumber,
      totalSteps: widget.totalSteps,
      isValid: _isValid,
      onBack: widget.onBack,
      onNext: () {
        widget.onSave(_value!);
        widget.onNext();
      },
      child: TextField(
        key: const Key('numeric_step_field'),
        controller: _controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(hintText: widget.hintText),
        onChanged: (text) => setState(() => _value = double.tryParse(text)),
      ),
    );
  }
}

class ChoiceStepScreen<T> extends StatelessWidget {
  const ChoiceStepScreen({
    super.key,
    required this.title,
    required this.options,
    required this.selected,
    required this.onSave,
    required this.onNext,
    required this.onBack,
    required this.stepNumber,
    required this.totalSteps,
  });

  final String title;
  final List<(T value, String label)> options;
  final T? selected;
  final ValueChanged<T> onSave;
  final VoidCallback onNext;
  final VoidCallback? onBack;
  final int stepNumber;
  final int totalSteps;

  @override
  Widget build(BuildContext context) {
    return WizardStepScaffold(
      title: title,
      stepNumber: stepNumber,
      totalSteps: totalSteps,
      isValid: selected != null,
      onBack: onBack,
      onNext: onNext,
      child: ListView(
        children: [
          for (final option in options)
            RadioListTile<T>(
              key: Key('choice_option_${option.$1}'),
              title: Text(option.$2),
              value: option.$1,
              groupValue: selected,
              onChanged: (value) {
                if (value != null) onSave(value);
              },
            ),
        ],
      ),
    );
  }
}

class TextStepScreen extends StatefulWidget {
  const TextStepScreen({
    super.key,
    required this.title,
    required this.hintText,
    required this.initialValue,
    required this.required,
    required this.onSave,
    required this.onNext,
    required this.onBack,
    required this.stepNumber,
    required this.totalSteps,
    this.nextLabel,
  });

  final String title;
  final String hintText;
  final String? initialValue;
  final bool required;
  final ValueChanged<String?> onSave;
  final VoidCallback onNext;
  final VoidCallback? onBack;
  final int stepNumber;
  final int totalSteps;
  final String? nextLabel;

  @override
  State<TextStepScreen> createState() => _TextStepScreenState();
}

class _TextStepScreenState extends State<TextStepScreen> {
  late final TextEditingController _controller;
  late String _text;

  @override
  void initState() {
    super.initState();
    _text = widget.initialValue ?? '';
    _controller = TextEditingController(text: _text);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isValid = !widget.required || _text.trim().isNotEmpty;
    return WizardStepScaffold(
      title: widget.title,
      stepNumber: widget.stepNumber,
      totalSteps: widget.totalSteps,
      isValid: isValid,
      onBack: widget.onBack,
      nextLabel: widget.nextLabel,
      onNext: () {
        final trimmed = _text.trim();
        widget.onSave(trimmed.isEmpty ? null : trimmed);
        widget.onNext();
      },
      child: TextField(
        key: const Key('text_step_field'),
        controller: _controller,
        maxLines: 5,
        decoration: InputDecoration(hintText: widget.hintText),
        onChanged: (value) => setState(() => _text = value),
      ),
    );
  }
}
```

- [ ] **Step 5: Testin geçtiğini doğrula**

Run: `flutter test test/features/onboarding/presentation/steps/step_scaffolds_test.dart`
Expected: `+5: All tests passed!` (2 `NumericStepScreen`, 1 `ChoiceStepScreen`, 2 `TextStepScreen`)

- [ ] **Step 6: flutter analyze**

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 7: flutter test (regresyon, tüm suite)**

Run: `flutter test`
Expected: `All tests passed!`

- [ ] **Step 8: Commit**

```bash
git add lib/features/onboarding/presentation/steps/step_scaffolds.dart test/features/onboarding/presentation/steps/step_scaffolds_test.dart assets/translations/tr.json assets/translations/en.json
git commit -m "$(cat <<'EOF'
Add reusable onboarding step scaffold widgets

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01PDcH7HBWBdAAUWM5Tnp7GU
EOF
)"
```

---

## Task 13: 10 somut onboarding adım widget'ı

**Files:**
- Create: `lib/features/onboarding/presentation/steps/onboarding_step_widgets.dart`
- Modify: `assets/translations/tr.json`
- Modify: `assets/translations/en.json`

**Interfaces:**
- Consumes: `onboardingWizardProvider` (Task 11), `WizardStepScaffold`/`NumericStepScreen`/`ChoiceStepScreen`/`TextStepScreen` (Task 12), `Gender`/`ActivityLevel`/`Goal` (Task 2)
- Produces: `WeightStep`, `HeightStep`, `BirthYearStep`, `GenderStep`, `ActivityLevelStep`, `DoesExerciseStep`, `SportTypeStep`, `ExerciseDaysStep`, `GoalStep`, `HealthNotesStep` — her biri `{stepNumber, totalSteps, onNext, onBack}` alan `ConsumerWidget` — Task 14 (wizard shell) bunları `OnboardingStepId`'ye göre seçip gösterecek.

- [ ] **Step 1: tr.json/en.json'a 10 adımın metinlerini ekle**

`assets/translations/tr.json`'daki `onboarding` bloğunu şu şekilde genişlet (mevcut `step_of`/`next`/`finish`/`retry` korunuyor):
```json
{
  "app": {
    "title": "Spor Takip"
  },
  "auth": {
    "login_title": "Giriş Yap",
    "email_label": "E-posta",
    "password_label": "Şifre",
    "login_button": "Giriş Yap",
    "forgot_password": "Şifremi unuttum",
    "go_to_register": "Hesabın yok mu? Kayıt ol",
    "enter_email_first": "Önce e-posta adresini gir",
    "reset_email_sent": "Şifre sıfırlama e-postası gönderildi",
    "invalid_credentials": "E-posta veya şifre hatalı",
    "unknown_error": "Bir hata oluştu, tekrar dene",
    "register_title": "Kayıt Ol",
    "confirm_password_label": "Şifre (tekrar)",
    "register_button": "Kayıt Ol",
    "go_to_login": "Zaten hesabın var mı? Giriş yap",
    "passwords_dont_match": "Şifreler eşleşmiyor",
    "email_already_registered": "Bu e-posta zaten kayıtlı",
    "weak_password": "Şifre çok zayıf, daha güçlü bir şifre seç"
  },
  "onboarding": {
    "step_of": "Adım {current}/{total}",
    "next": "İleri",
    "finish": "Bitir",
    "retry": "Tekrar dene",
    "save_error": "Kaydedilemedi, tekrar dene",
    "weight_question": "Kilonuz kaç kg?",
    "weight_hint": "Örn. 75",
    "height_question": "Boyunuz kaç cm?",
    "height_hint": "Örn. 175",
    "birth_year_question": "Doğum yılınız nedir?",
    "birth_year_hint": "Örn. 1996",
    "gender_question": "Cinsiyetiniz nedir?",
    "gender_male": "Erkek",
    "gender_female": "Kadın",
    "gender_unspecified": "Belirtmek istemiyorum",
    "activity_question": "Aktivite düzeyiniz nedir?",
    "activity_sedentary": "Hareketsiz",
    "activity_light": "Hafif aktif",
    "activity_moderate": "Orta aktif",
    "activity_active": "Yoğun aktif",
    "activity_very_active": "Çok yoğun aktif",
    "does_exercise_question": "Düzenli spor yapıyor musunuz?",
    "yes": "Evet",
    "no": "Hayır",
    "sport_type_question": "Hangi sporu yapıyorsunuz?",
    "sport_type_hint": "Örn. fitness, koşu, yüzme, bisiklet, futbol",
    "exercise_days_question": "Haftada kaç gün spor yapıyorsunuz?",
    "exercise_days_hint": "0-7 arası bir sayı",
    "goal_question": "Hedefiniz nedir?",
    "goal_lose_weight": "Kilo vermek",
    "goal_gain_muscle": "Kas kazanmak",
    "goal_maintain": "Formda kalmak",
    "health_notes_question": "Belirtmek istediğiniz bir sağlık durumu var mı? (opsiyonel)",
    "health_notes_hint": "Varsa yaz, yoksa boş bırakıp devam edebilirsin"
  }
}
```

`assets/translations/en.json`'ı **aynı içerikle** güncelle (yukarıdaki JSON'un birebir aynısı).

- [ ] **Step 2: 10 adım widget'ını yaz**

`lib/features/onboarding/presentation/steps/onboarding_step_widgets.dart`:
```dart
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/onboarding_wizard_notifier.dart';
import '../../domain/profile.dart';
import 'step_scaffolds.dart';

class WeightStep extends ConsumerWidget {
  const WeightStep({
    super.key,
    required this.stepNumber,
    required this.totalSteps,
    required this.onNext,
    required this.onBack,
  });

  final int stepNumber;
  final int totalSteps;
  final VoidCallback onNext;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final answers = ref.watch(onboardingWizardProvider);
    return NumericStepScreen(
      title: 'onboarding.weight_question'.tr(),
      hintText: 'onboarding.weight_hint'.tr(),
      min: 20,
      max: 300,
      initialValue: answers.weightKg,
      onSave: (value) => ref
          .read(onboardingWizardProvider.notifier)
          .update((a) => a.copyWith(weightKg: value)),
      onNext: onNext,
      onBack: onBack,
      stepNumber: stepNumber,
      totalSteps: totalSteps,
    );
  }
}

class HeightStep extends ConsumerWidget {
  const HeightStep({
    super.key,
    required this.stepNumber,
    required this.totalSteps,
    required this.onNext,
    required this.onBack,
  });

  final int stepNumber;
  final int totalSteps;
  final VoidCallback onNext;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final answers = ref.watch(onboardingWizardProvider);
    return NumericStepScreen(
      title: 'onboarding.height_question'.tr(),
      hintText: 'onboarding.height_hint'.tr(),
      min: 100,
      max: 250,
      initialValue: answers.heightCm,
      onSave: (value) => ref
          .read(onboardingWizardProvider.notifier)
          .update((a) => a.copyWith(heightCm: value)),
      onNext: onNext,
      onBack: onBack,
      stepNumber: stepNumber,
      totalSteps: totalSteps,
    );
  }
}

class BirthYearStep extends ConsumerWidget {
  const BirthYearStep({
    super.key,
    required this.stepNumber,
    required this.totalSteps,
    required this.onNext,
    required this.onBack,
  });

  final int stepNumber;
  final int totalSteps;
  final VoidCallback onNext;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final answers = ref.watch(onboardingWizardProvider);
    return NumericStepScreen(
      title: 'onboarding.birth_year_question'.tr(),
      hintText: 'onboarding.birth_year_hint'.tr(),
      min: 1920,
      max: 2020,
      initialValue: answers.birthYear?.toDouble(),
      onSave: (value) => ref
          .read(onboardingWizardProvider.notifier)
          .update((a) => a.copyWith(birthYear: value.round())),
      onNext: onNext,
      onBack: onBack,
      stepNumber: stepNumber,
      totalSteps: totalSteps,
    );
  }
}

class GenderStep extends ConsumerWidget {
  const GenderStep({
    super.key,
    required this.stepNumber,
    required this.totalSteps,
    required this.onNext,
    required this.onBack,
  });

  final int stepNumber;
  final int totalSteps;
  final VoidCallback onNext;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final answers = ref.watch(onboardingWizardProvider);
    return ChoiceStepScreen<Gender>(
      title: 'onboarding.gender_question'.tr(),
      options: [
        (Gender.male, 'onboarding.gender_male'.tr()),
        (Gender.female, 'onboarding.gender_female'.tr()),
        (Gender.unspecified, 'onboarding.gender_unspecified'.tr()),
      ],
      selected: answers.gender,
      onSave: (value) => ref
          .read(onboardingWizardProvider.notifier)
          .update((a) => a.copyWith(gender: value)),
      onNext: onNext,
      onBack: onBack,
      stepNumber: stepNumber,
      totalSteps: totalSteps,
    );
  }
}

class ActivityLevelStep extends ConsumerWidget {
  const ActivityLevelStep({
    super.key,
    required this.stepNumber,
    required this.totalSteps,
    required this.onNext,
    required this.onBack,
  });

  final int stepNumber;
  final int totalSteps;
  final VoidCallback onNext;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final answers = ref.watch(onboardingWizardProvider);
    return ChoiceStepScreen<ActivityLevel>(
      title: 'onboarding.activity_question'.tr(),
      options: [
        (ActivityLevel.sedentary, 'onboarding.activity_sedentary'.tr()),
        (ActivityLevel.light, 'onboarding.activity_light'.tr()),
        (ActivityLevel.moderate, 'onboarding.activity_moderate'.tr()),
        (ActivityLevel.active, 'onboarding.activity_active'.tr()),
        (ActivityLevel.veryActive, 'onboarding.activity_very_active'.tr()),
      ],
      selected: answers.activityLevel,
      onSave: (value) => ref
          .read(onboardingWizardProvider.notifier)
          .update((a) => a.copyWith(activityLevel: value)),
      onNext: onNext,
      onBack: onBack,
      stepNumber: stepNumber,
      totalSteps: totalSteps,
    );
  }
}

class DoesExerciseStep extends ConsumerWidget {
  const DoesExerciseStep({
    super.key,
    required this.stepNumber,
    required this.totalSteps,
    required this.onNext,
    required this.onBack,
  });

  final int stepNumber;
  final int totalSteps;
  final VoidCallback onNext;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final answers = ref.watch(onboardingWizardProvider);
    return ChoiceStepScreen<bool>(
      title: 'onboarding.does_exercise_question'.tr(),
      options: [
        (true, 'onboarding.yes'.tr()),
        (false, 'onboarding.no'.tr()),
      ],
      selected: answers.doesExercise,
      onSave: (value) => ref
          .read(onboardingWizardProvider.notifier)
          .update((a) => a.copyWith(doesExercise: value)),
      onNext: onNext,
      onBack: onBack,
      stepNumber: stepNumber,
      totalSteps: totalSteps,
    );
  }
}

class SportTypeStep extends ConsumerWidget {
  const SportTypeStep({
    super.key,
    required this.stepNumber,
    required this.totalSteps,
    required this.onNext,
    required this.onBack,
  });

  final int stepNumber;
  final int totalSteps;
  final VoidCallback onNext;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final answers = ref.watch(onboardingWizardProvider);
    return TextStepScreen(
      title: 'onboarding.sport_type_question'.tr(),
      hintText: 'onboarding.sport_type_hint'.tr(),
      initialValue: answers.sportType,
      required: true,
      onSave: (value) => ref
          .read(onboardingWizardProvider.notifier)
          .update((a) => a.copyWith(sportType: value)),
      onNext: onNext,
      onBack: onBack,
      stepNumber: stepNumber,
      totalSteps: totalSteps,
    );
  }
}

class ExerciseDaysStep extends ConsumerWidget {
  const ExerciseDaysStep({
    super.key,
    required this.stepNumber,
    required this.totalSteps,
    required this.onNext,
    required this.onBack,
  });

  final int stepNumber;
  final int totalSteps;
  final VoidCallback onNext;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final answers = ref.watch(onboardingWizardProvider);
    return NumericStepScreen(
      title: 'onboarding.exercise_days_question'.tr(),
      hintText: 'onboarding.exercise_days_hint'.tr(),
      min: 0,
      max: 7,
      initialValue: answers.exerciseDaysPerWeek?.toDouble(),
      onSave: (value) => ref
          .read(onboardingWizardProvider.notifier)
          .update((a) => a.copyWith(exerciseDaysPerWeek: value.round())),
      onNext: onNext,
      onBack: onBack,
      stepNumber: stepNumber,
      totalSteps: totalSteps,
    );
  }
}

class GoalStep extends ConsumerWidget {
  const GoalStep({
    super.key,
    required this.stepNumber,
    required this.totalSteps,
    required this.onNext,
    required this.onBack,
  });

  final int stepNumber;
  final int totalSteps;
  final VoidCallback onNext;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final answers = ref.watch(onboardingWizardProvider);
    return ChoiceStepScreen<Goal>(
      title: 'onboarding.goal_question'.tr(),
      options: [
        (Goal.loseWeight, 'onboarding.goal_lose_weight'.tr()),
        (Goal.gainMuscle, 'onboarding.goal_gain_muscle'.tr()),
        (Goal.maintain, 'onboarding.goal_maintain'.tr()),
      ],
      selected: answers.goal,
      onSave: (value) => ref
          .read(onboardingWizardProvider.notifier)
          .update((a) => a.copyWith(goal: value)),
      onNext: onNext,
      onBack: onBack,
      stepNumber: stepNumber,
      totalSteps: totalSteps,
    );
  }
}

class HealthNotesStep extends ConsumerWidget {
  const HealthNotesStep({
    super.key,
    required this.stepNumber,
    required this.totalSteps,
    required this.onFinish,
    required this.onBack,
  });

  final int stepNumber;
  final int totalSteps;
  final VoidCallback onFinish;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final answers = ref.watch(onboardingWizardProvider);
    return TextStepScreen(
      title: 'onboarding.health_notes_question'.tr(),
      hintText: 'onboarding.health_notes_hint'.tr(),
      initialValue: answers.healthNotes,
      required: false,
      nextLabel: 'onboarding.finish'.tr(),
      onSave: (value) => ref
          .read(onboardingWizardProvider.notifier)
          .update((a) => a.copyWith(healthNotes: value)),
      onNext: onFinish,
      onBack: onBack,
      stepNumber: stepNumber,
      totalSteps: totalSteps,
    );
  }
}
```

- [ ] **Step 3: flutter analyze**

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 4: flutter test (regresyon)**

Run: `flutter test`
Expected: `All tests passed!`

- [ ] **Step 5: Commit**

```bash
git add lib/features/onboarding/presentation/steps/onboarding_step_widgets.dart assets/translations/tr.json assets/translations/en.json
git commit -m "$(cat <<'EOF'
Add the 10 concrete onboarding step widgets

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01PDcH7HBWBdAAUWM5Tnp7GU
EOF
)"
```

---

## Task 14: Onboarding sihirbazı kabuğu (gerçek içerik)

**Files:**
- Modify: `lib/features/onboarding/presentation/onboarding_wizard_screen.dart` (Task 8'in placeholder'ını tamamen değiştirir)

**Interfaces:**
- Consumes: `visibleSteps` (Task 11), `onboardingWizardProvider` (Task 11), `buildProfileFromAnswers` (Task 11), `authRepositoryProvider.currentUserId` (Task 6), `profileRepositoryProvider` (Task 7), 10 adım widget'ı (Task 13)
- Produces: Yok (terminal UI ekranı). Başarılı kayıttan sonra `profileProvider`'ı invalidate eder — router bunu otomatik yakalayıp `/home`'a yönlendirir, ekranın kendisi manuel navigasyon yapmaz.

- [ ] **Step 1: OnboardingWizardScreen'i tam içerikle yaz**

`lib/features/onboarding/presentation/onboarding_wizard_screen.dart`'ın tamamını değiştir:
```dart
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/auth_providers.dart';
import '../application/onboarding_wizard_notifier.dart';
import '../application/profile_providers.dart';
import '../domain/onboarding_steps.dart';
import 'steps/onboarding_step_widgets.dart';

class OnboardingWizardScreen extends ConsumerStatefulWidget {
  const OnboardingWizardScreen({super.key});

  @override
  ConsumerState<OnboardingWizardScreen> createState() => _OnboardingWizardScreenState();
}

class _OnboardingWizardScreenState extends ConsumerState<OnboardingWizardScreen> {
  int _currentIndex = 0;
  bool _isSaving = false;
  String? _saveError;

  void _goBack() {
    setState(() => _currentIndex -= 1);
  }

  void _goNext(int stepCount) {
    if (_currentIndex < stepCount - 1) {
      setState(() => _currentIndex += 1);
    }
  }

  Future<void> _finish() async {
    final answers = ref.read(onboardingWizardProvider);
    if (!answers.isComplete) return;
    setState(() {
      _isSaving = true;
      _saveError = null;
    });
    try {
      final userId = ref.read(authRepositoryProvider).currentUserId;
      final profile = buildProfileFromAnswers(
        answers: answers,
        userId: userId,
        currentYear: DateTime.now().year,
      );
      await ref.read(profileRepositoryProvider).saveProfile(profile);
      ref.invalidate(profileProvider);
    } catch (_) {
      setState(() => _saveError = 'onboarding.save_error'.tr());
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isSaving) {
      return const Scaffold(
        key: Key('onboarding_screen'),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_saveError != null) {
      return Scaffold(
        key: const Key('onboarding_screen'),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_saveError!),
              ElevatedButton(onPressed: _finish, child: Text('onboarding.retry'.tr())),
            ],
          ),
        ),
      );
    }

    final answers = ref.watch(onboardingWizardProvider);
    final steps = visibleSteps(answers);
    final safeIndex = _currentIndex.clamp(0, steps.length - 1);
    final stepId = steps[safeIndex];
    final isLast = safeIndex == steps.length - 1;
    final onBack = safeIndex == 0 ? null : _goBack;
    final onNext = isLast ? _finish : () => _goNext(steps.length);
    final stepNumber = safeIndex + 1;
    final totalSteps = steps.length;

    final stepWidget = switch (stepId) {
      OnboardingStepId.weight => WeightStep(
          stepNumber: stepNumber,
          totalSteps: totalSteps,
          onNext: onNext,
          onBack: onBack,
        ),
      OnboardingStepId.height => HeightStep(
          stepNumber: stepNumber,
          totalSteps: totalSteps,
          onNext: onNext,
          onBack: onBack,
        ),
      OnboardingStepId.birthYear => BirthYearStep(
          stepNumber: stepNumber,
          totalSteps: totalSteps,
          onNext: onNext,
          onBack: onBack,
        ),
      OnboardingStepId.gender => GenderStep(
          stepNumber: stepNumber,
          totalSteps: totalSteps,
          onNext: onNext,
          onBack: onBack,
        ),
      OnboardingStepId.activityLevel => ActivityLevelStep(
          stepNumber: stepNumber,
          totalSteps: totalSteps,
          onNext: onNext,
          onBack: onBack,
        ),
      OnboardingStepId.doesExercise => DoesExerciseStep(
          stepNumber: stepNumber,
          totalSteps: totalSteps,
          onNext: onNext,
          onBack: onBack,
        ),
      OnboardingStepId.sportType => SportTypeStep(
          stepNumber: stepNumber,
          totalSteps: totalSteps,
          onNext: onNext,
          onBack: onBack,
        ),
      OnboardingStepId.exerciseDays => ExerciseDaysStep(
          stepNumber: stepNumber,
          totalSteps: totalSteps,
          onNext: onNext,
          onBack: onBack,
        ),
      OnboardingStepId.goal => GoalStep(
          stepNumber: stepNumber,
          totalSteps: totalSteps,
          onNext: onNext,
          onBack: onBack,
        ),
      OnboardingStepId.healthNotes => HealthNotesStep(
          stepNumber: stepNumber,
          totalSteps: totalSteps,
          onFinish: onNext,
          onBack: onBack,
        ),
    };

    return stepWidget;
  }
}
```

**Not (bilinen kısıt, spec §11'de kabul edildi):** `_currentIndex` sadece bellekte tutuluyor; uygulama onboarding ortasında kapanırsa ilerleme kaybolur. Bu, spec'te onaylanan Yaklaşım A'nın bilinen bir kısıtıdır, bug değildir.

- [ ] **Step 2: flutter analyze**

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 3: flutter test (regresyon)**

Run: `flutter test`
Expected: `All tests passed!` (Task 8'in widget_test'i `Key('login_screen')` arıyor, onboarding ekranına dokunmuyor — etkilenmez)

- [ ] **Step 4: Commit**

```bash
git add lib/features/onboarding/presentation/onboarding_wizard_screen.dart
git commit -m "$(cat <<'EOF'
Implement onboarding wizard shell orchestrating the 10 steps

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01PDcH7HBWBdAAUWM5Tnp7GU
EOF
)"
```

---

## Task 15: Ana ekran (özet)

**Files:**
- Modify: `lib/features/onboarding/presentation/home_screen.dart` (Task 8'in placeholder'ını tamamen değiştirir)
- Modify: `assets/translations/tr.json`
- Modify: `assets/translations/en.json`

**Interfaces:**
- Consumes: `profileProvider` (Task 7), `authRepositoryProvider` (Task 6)
- Produces: Yok (terminal UI ekranı, F2+'da içerik genişletilecek)

- [ ] **Step 1: tr.json/en.json'a home anahtarlarını ekle**

`assets/translations/tr.json`'a `home` bloğu ekle (mevcut `app`/`auth`/`onboarding` blokları korunuyor):
```json
{
  "app": {
    "title": "Spor Takip"
  },
  "auth": {
    "login_title": "Giriş Yap",
    "email_label": "E-posta",
    "password_label": "Şifre",
    "login_button": "Giriş Yap",
    "forgot_password": "Şifremi unuttum",
    "go_to_register": "Hesabın yok mu? Kayıt ol",
    "enter_email_first": "Önce e-posta adresini gir",
    "reset_email_sent": "Şifre sıfırlama e-postası gönderildi",
    "invalid_credentials": "E-posta veya şifre hatalı",
    "unknown_error": "Bir hata oluştu, tekrar dene",
    "register_title": "Kayıt Ol",
    "confirm_password_label": "Şifre (tekrar)",
    "register_button": "Kayıt Ol",
    "go_to_login": "Zaten hesabın var mı? Giriş yap",
    "passwords_dont_match": "Şifreler eşleşmiyor",
    "email_already_registered": "Bu e-posta zaten kayıtlı",
    "weak_password": "Şifre çok zayıf, daha güçlü bir şifre seç"
  },
  "onboarding": {
    "step_of": "Adım {current}/{total}",
    "next": "İleri",
    "finish": "Bitir",
    "retry": "Tekrar dene",
    "save_error": "Kaydedilemedi, tekrar dene",
    "weight_question": "Kilonuz kaç kg?",
    "weight_hint": "Örn. 75",
    "height_question": "Boyunuz kaç cm?",
    "height_hint": "Örn. 175",
    "birth_year_question": "Doğum yılınız nedir?",
    "birth_year_hint": "Örn. 1996",
    "gender_question": "Cinsiyetiniz nedir?",
    "gender_male": "Erkek",
    "gender_female": "Kadın",
    "gender_unspecified": "Belirtmek istemiyorum",
    "activity_question": "Aktivite düzeyiniz nedir?",
    "activity_sedentary": "Hareketsiz",
    "activity_light": "Hafif aktif",
    "activity_moderate": "Orta aktif",
    "activity_active": "Yoğun aktif",
    "activity_very_active": "Çok yoğun aktif",
    "does_exercise_question": "Düzenli spor yapıyor musunuz?",
    "yes": "Evet",
    "no": "Hayır",
    "sport_type_question": "Hangi sporu yapıyorsunuz?",
    "sport_type_hint": "Örn. fitness, koşu, yüzme, bisiklet, futbol",
    "exercise_days_question": "Haftada kaç gün spor yapıyorsunuz?",
    "exercise_days_hint": "0-7 arası bir sayı",
    "goal_question": "Hedefiniz nedir?",
    "goal_lose_weight": "Kilo vermek",
    "goal_gain_muscle": "Kas kazanmak",
    "goal_maintain": "Formda kalmak",
    "health_notes_question": "Belirtmek istediğiniz bir sağlık durumu var mı? (opsiyonel)",
    "health_notes_hint": "Varsa yaz, yoksa boş bırakıp devam edebilirsin"
  },
  "home": {
    "title": "Spor Takip",
    "no_profile": "Profil bulunamadı",
    "calorie_target": "Günlük hedef: {value} kcal",
    "protein_target": "Protein hedefi: {value} g",
    "load_error": "Profil yüklenemedi"
  }
}
```

`assets/translations/en.json`'ı **aynı içerikle** güncelle (yukarıdaki JSON'un birebir aynısı).

- [ ] **Step 2: HomeScreen'i tam içerikle yaz**

`lib/features/onboarding/presentation/home_screen.dart`'ın tamamını değiştir:
```dart
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/auth_providers.dart';
import '../application/profile_providers.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(profileProvider);
    return Scaffold(
      key: const Key('home_screen'),
      appBar: AppBar(
        title: Text('home.title'.tr()),
        actions: [
          IconButton(
            key: const Key('home_sign_out_button'),
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(authRepositoryProvider).signOut(),
          ),
        ],
      ),
      body: profileAsync.when(
        data: (profile) {
          if (profile == null) {
            return Center(child: Text('home.no_profile'.tr()));
          }
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'home.calorie_target'.tr(
                    namedArgs: {'value': profile.dailyCalorieTarget.round().toString()},
                  ),
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'home.protein_target'.tr(
                    namedArgs: {'value': profile.dailyProteinTargetG.round().toString()},
                  ),
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(child: Text('home.load_error'.tr())),
      ),
    );
  }
}
```

- [ ] **Step 3: flutter analyze**

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 4: flutter test (regresyon)**

Run: `flutter test`
Expected: `All tests passed!`

- [ ] **Step 5: Commit**

```bash
git add lib/features/onboarding/presentation/home_screen.dart assets/translations/tr.json assets/translations/en.json
git commit -m "$(cat <<'EOF'
Implement home summary screen showing calorie/protein targets

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01PDcH7HBWBdAAUWM5Tnp7GU
EOF
)"
```

---

## Task 16: F1 (email/şifre bölümü) doğrulama ve kapanış

**Files:** Yok (sadece doğrulama + `PLAN.md` değişikliği)

**Interfaces:**
- Consumes: Task 1-15'in tüm ürünleri
- Produces: F1'in email/şifre auth + onboarding + TDEE hedef hesabı bölümünün tamamlandığını gösteren yeşil doğrulama + `PLAN.md` değişiklik günlüğü güncellemesi. Google Sign-In (Task 17) ayrı ve bu task'tan sonra ele alınacak.

- [ ] **Step 1: Tüm proje için analyze çalıştır**

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 2: Tüm testleri çalıştır**

Run: `flutter test`
Expected: `All tests passed!` (Task 1-15'te eklenen tüm test dosyaları: `profile_test.dart`, `tdee_calculator_test.dart`, `redirect_logic_test.dart`, `onboarding_steps_test.dart`, `onboarding_wizard_notifier_test.dart`, `step_scaffolds_test.dart`, ve güncellenmiş `widget_test.dart`)

- [ ] **Step 3: Git durumunun temiz olduğunu doğrula**

Run: `git status`
Expected: `.env` hariç her şey commit edilmiş (`nothing to commit, working tree clean` veya sadece ignore edilen dosyalar)

- [ ] **Step 4: PLAN.md'nin Değişiklik Günlüğü'nü güncelle**

`PLAN.md` içindeki `## 10. Değişiklik Günlüğü` tablosuna satır ekle (mevcut satırlar korunuyor):
```
| 2026-09-20 | F1 (email/şifre bölümü) tamamlandı: kayıt/giriş/şifre sıfırlama, 10 soruluk onboarding sihirbazı, Mifflin-St Jeor TDEE + protein hedefi hesabı, auth/profil durumuna göre otomatik yönlendirme, TR/EN i18n altyapısı. Google Sign-In (F1'in bir parçası) ayrı bir görev olarak kullanıcının Google Cloud Console kurulumunu bekliyor. Gerçek Supabase projesi bağlantısı (F0 Task 8) hâlâ açık — uçtan uca manuel doğrulama bunu bekliyor. |
```

- [ ] **Step 5: Commit**

```bash
git add PLAN.md
git commit -m "$(cat <<'EOF'
Mark F1 email/password portion complete in PLAN.md changelog

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01PDcH7HBWBdAAUWM5Tnp7GU
EOF
)"
```

---

## Task 17: Google Sign-In (kullanıcı işlemi gerektirir, F1'in son görevi)

**Files:**
- Modify: `lib/features/onboarding/application/auth_providers.dart`
- Modify: `lib/features/onboarding/presentation/login_screen.dart`
- Modify: `assets/translations/tr.json`
- Modify: `assets/translations/en.json`

Not: `android/app/build.gradle.kts` (SHA-1 doğrulaması) ve `ios/Runner/Info.plist` (URL scheme) bu task'ta DEĞİŞTİRİLMEZ — bu dosyalar kullanıcının paylaşacağı gerçek Client ID/SHA-1 değerlerine bağlı, task'ın sonundaki Not'ta ayrı bir takip maddesi olarak bırakıldı.

**Interfaces:**
- Consumes: `AuthRepository` (Task 6), kullanıcının sağlayacağı Google OAuth Client ID'leri (Web, Android, iOS)
- Produces: `AuthRepository.signInWithGoogle()` metodu, login ekranında "Google ile giriş yap" butonu

**Bu görev BAŞLAMADAN önce kullanıcıdan şunlar istenmeli** (bu adımlar implementer tarafından yapılamaz, kullanıcının Google Cloud Console ve Supabase Dashboard erişimi gerekir):
1. Google Cloud Console'da bir proje (veya mevcut projede) OAuth 2.0 Client ID'leri oluşturulmalı: **Web application** tipi (Supabase'in kendi redirect URL'i için) ve gerekirse **Android**/**iOS** tipi client'lar (paket adı `com.sportakip.spor_takip` / bundle ID ile, F0'da not edilen iOS'un `com.sportakip.sporTakip` camelCase varyasyonuna dikkat).
2. Supabase Dashboard → Authentication → Providers → Google altında bu Web Client ID + Client Secret girilmeli, provider aktif edilmeli.
3. Kullanıcı bu Client ID değerlerini (en azından Web Client ID'yi) paylaşmalı.

Bu bilgiler paylaşılmadan bu task'ın kod kısmı yazılabilir (arayüz/metod iskeleti), ancak gerçek bir Google girişi test edilemez — bu, F0 Task 8'deki "gerçek kimlik bilgisi bekleniyor" durumuyla aynı desendedir.

- [ ] **Step 1: Kullanıcıdan Google OAuth kurulumunu iste**

Kullanıcıya şunu ilet: "Google girişi için Google Cloud Console'dan bir Web OAuth Client ID oluşturup, Supabase Dashboard → Authentication → Providers → Google'a ekleyip aktif etmen gerekiyor. Web Client ID'yi paylaşınca kodu buna göre tamamlarım."

- [ ] **Step 2: auth_providers.dart'a Google giriş metodunu ekle**

`lib/features/onboarding/application/auth_providers.dart`'daki `AuthRepository` sınıfına ekle:
```dart
  Future<bool> signInWithGoogle() {
    return _client.auth.signInWithOAuth(OAuthProvider.google);
  }
```

(Bu metod `supabase_flutter`'ın platform tarayıcı akışını kullanır; native Google Sign-In SDK entegrasyonu değildir — F1 kapsamında yeterlidir, daha native bir akış ileride ayrı bir iyileştirme olarak ele alınabilir.)

- [ ] **Step 3: tr.json/en.json'a Google giriş metnini ekle**

`assets/translations/tr.json`'daki `auth` bloğunun İÇİNDE, son alan olan `"weak_password": "Şifre çok zayıf, daha güçlü bir şifre seç"` satırından hemen sonra, o satırın sonuna virgül ekleyip yeni satırı ekle:
```json
    "weak_password": "Şifre çok zayıf, daha güçlü bir şifre seç",
    "google_sign_in": "Google ile giriş yap"
```
(`auth` bloğunun kapanış `}`'ı bu yeni satırdan hemen sonra gelir — JSON söz dizimini bozmadığından emin ol.)

`assets/translations/en.json`'da da `auth` bloğuna aynı iki satırı aynı şekilde ekle.

- [ ] **Step 4: Login ekranına Google butonunu ekle**

`lib/features/onboarding/presentation/login_screen.dart`'daki `_LoginScreenState.build` metodundaki `Column`'un `children` listesine, "Hesabın yok mu?" butonundan önce ekle:
```dart
            const SizedBox(height: 12),
            OutlinedButton.icon(
              key: const Key('login_google_button'),
              onPressed: _isSubmitting
                  ? null
                  : () => ref.read(authRepositoryProvider).signInWithGoogle(),
              icon: const Icon(Icons.login),
              label: Text('auth.google_sign_in'.tr()),
            ),
```

- [ ] **Step 5: flutter analyze**

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 6: flutter test (regresyon)**

Run: `flutter test`
Expected: `All tests passed!`

- [ ] **Step 7: Commit**

```bash
git add lib/features/onboarding/application/auth_providers.dart lib/features/onboarding/presentation/login_screen.dart assets/translations/tr.json assets/translations/en.json
git commit -m "$(cat <<'EOF'
Add Google Sign-In to auth repository and login screen

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01PDcH7HBWBdAAUWM5Tnp7GU
EOF
)"
```

**Not:** Android/iOS platform dosyalarındaki (SHA-1 kaydı, `Info.plist` URL scheme) değişiklikler kullanıcının paylaştığı Client ID'lere göre değişir — bu adım kullanıcı bilgiyi paylaştığında ayrıca ele alınacak, bu plana şimdiden genel bir SHA-1/URL-scheme kodu yazmak (henüz bilinmeyen değerlerle) placeholder olur ve YAPILMAYACAK.

---
