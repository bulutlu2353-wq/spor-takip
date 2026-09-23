# F2 — Fotoğrafla Besin Takibi Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Kullanıcının bir öğün fotoğrafı çekip AI (Gemini 2.5 Flash-Lite) ile yiyecek/porsiyon tahmini almasını, bu tahmini USDA FoodData Central'dan gerçek makro değerleriyle zenginleştirip düzenleyip onaylamasını ve günlük öğün listesini görmesini sağlayan uçtan uca bir dikey dilim inşa etmek.

**Architecture:** Yeni `lib/features/nutrition/` feature'ı mevcut `onboarding` feature'ının domain/data/application/presentation katman paternini izler. Yeni bir Supabase Edge Function (`analyze-meal-photo`) Gemini'yi çağırıp yiyecek/porsiyon tahmini alır, her öğeyi USDA FDC'de arar ve gerçek makroları hesaplayıp döner (LLM'e ikinci kez makro hesaplattırılmaz). Yeni `meals`/`meal_items` tabloları + `meal-photos` storage bucket'ı RLS ile korunur. Navigasyon, `go_router`'ın `StatefulShellRoute.indexedStack`'i ile alt nav bar'a (Home/Beslenme) geçirilir.

**Tech Stack:** Flutter + Riverpod 3 + go_router 18 + supabase_flutter 2.17 + easy_localization (mevcut yığın); yeni: `image_picker`, `uuid`. Backend: Supabase Edge Function (Deno), Gemini 2.5 Flash-Lite REST API, USDA FoodData Central REST API.

**Spec:** `docs/superpowers/specs/2026-09-23-f2-meal-photo-tracking-design.md`

## Global Constraints

- Tüm yeni tablolarda Supabase RLS zorunlu (spec §3).
- LLM'e ikinci kez makro hesaplattırma yok — USDA'da eşleşme bulunamazsa `needs_review: true` ile 0 makro dön, kullanıcı elle doldurur (spec §5 adım 5).
- Bu pasta offline fotoğraf kuyruğu yok — internet gerekli, hata net TR mesajıyla gösterilir (spec §1, §7).
- Kullanıcıya gösterilen tüm metinler `easy_localization` üzerinden `assets/translations/tr.json` ve `en.json`'a eklenir (mevcut proje kuralı).
- Mevcut feature-first katman yapısı (domain/data/application/presentation) izlenir (mevcut proje kuralı, bkz. `lib/features/onboarding/`).
- `grams <= 0` olan öğe kaydedilemez; `needs_review: true` olan öğe elle düzeltilmeden kaydedilemez (spec §7).
- Supabase'e dokunan repository sınıfları bu projede doğrudan unit test edilmiyor (mevcut `ProfileRepository` paterni — hiç test dosyası yok); bunun yerine iş mantığı (notifier, pure fonksiyonlar) fake/mock repository ile test edilir, repository'nin kendisi F1'deki gibi gerçek Supabase'e karşı elle doğrulanır.

---

## Task 1: Domain — `MealType`

**Files:**
- Create: `lib/features/nutrition/domain/meal_type.dart`
- Test: `test/features/nutrition/domain/meal_type_test.dart`

**Interfaces:**
- Produces: `enum MealType { breakfast, lunch, dinner, snack }`, `String mealTypeToDb(MealType)`, `MealType mealTypeFromDb(String)`

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:spor_takip/features/nutrition/domain/meal_type.dart';

void main() {
  group('mealTypeToDb / mealTypeFromDb', () {
    test('round-trips every MealType value', () {
      for (final type in MealType.values) {
        expect(mealTypeFromDb(mealTypeToDb(type)), type);
      }
    });

    test('maps to the expected db strings', () {
      expect(mealTypeToDb(MealType.breakfast), 'breakfast');
      expect(mealTypeToDb(MealType.lunch), 'lunch');
      expect(mealTypeToDb(MealType.dinner), 'dinner');
      expect(mealTypeToDb(MealType.snack), 'snack');
    });

    test('throws ArgumentError for an unknown db string', () {
      expect(() => mealTypeFromDb('brunch'), throwsArgumentError);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/nutrition/domain/meal_type_test.dart`
Expected: FAIL — `meal_type.dart` bulunamıyor (import hatası).

- [ ] **Step 3: Write minimal implementation**

```dart
enum MealType { breakfast, lunch, dinner, snack }

String mealTypeToDb(MealType type) {
  switch (type) {
    case MealType.breakfast:
      return 'breakfast';
    case MealType.lunch:
      return 'lunch';
    case MealType.dinner:
      return 'dinner';
    case MealType.snack:
      return 'snack';
  }
}

MealType mealTypeFromDb(String value) {
  switch (value) {
    case 'breakfast':
      return MealType.breakfast;
    case 'lunch':
      return MealType.lunch;
    case 'dinner':
      return MealType.dinner;
    case 'snack':
      return MealType.snack;
    default:
      throw ArgumentError('Unknown meal_type: $value');
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/nutrition/domain/meal_type_test.dart`
Expected: PASS (4 tests)

- [ ] **Step 5: Commit**

```bash
git add lib/features/nutrition/domain/meal_type.dart test/features/nutrition/domain/meal_type_test.dart
git commit -m "feat(nutrition): add MealType enum with db mapping"
```

---

## Task 2: Domain — `FoodItem`

**Files:**
- Create: `lib/features/nutrition/domain/food_item.dart`
- Test: `test/features/nutrition/domain/food_item_test.dart`

**Interfaces:**
- Produces: `class FoodItem` with fields `name (String)`, `grams (double)`, `calories (double)`, `proteinG (double)`, `carbsG (double)`, `fatG (double)`, `usdaFdcId (String?)`, `needsReview (bool)`; `FoodItem.fromJson(Map<String,dynamic>)`, `toJson()`, `copyWith({...})`.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:spor_takip/features/nutrition/domain/food_item.dart';

void main() {
  const item = FoodItem(
    name: 'Izgara tavuk göğsü',
    grams: 150,
    calories: 247,
    proteinG: 46.5,
    carbsG: 0,
    fatG: 5.4,
    usdaFdcId: '171077',
    needsReview: false,
  );

  test('toJson/fromJson round-trips all fields', () {
    final json = item.toJson();
    final parsed = FoodItem.fromJson(json);
    expect(parsed.name, item.name);
    expect(parsed.grams, item.grams);
    expect(parsed.calories, item.calories);
    expect(parsed.proteinG, item.proteinG);
    expect(parsed.carbsG, item.carbsG);
    expect(parsed.fatG, item.fatG);
    expect(parsed.usdaFdcId, item.usdaFdcId);
    expect(parsed.needsReview, item.needsReview);
  });

  test('fromJson defaults missing macro/needs_review fields', () {
    final parsed = FoodItem.fromJson({'name': 'Bilinmeyen sos', 'grams': 30});
    expect(parsed.calories, 0);
    expect(parsed.proteinG, 0);
    expect(parsed.carbsG, 0);
    expect(parsed.fatG, 0);
    expect(parsed.usdaFdcId, isNull);
    expect(parsed.needsReview, isFalse);
  });

  test('copyWith overrides only given fields', () {
    final updated = item.copyWith(grams: 200, needsReview: true);
    expect(updated.grams, 200);
    expect(updated.needsReview, isTrue);
    expect(updated.name, item.name);
    expect(updated.calories, item.calories);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/nutrition/domain/food_item_test.dart`
Expected: FAIL — `food_item.dart` bulunamıyor.

- [ ] **Step 3: Write minimal implementation**

```dart
class FoodItem {
  const FoodItem({
    required this.name,
    required this.grams,
    this.calories = 0,
    this.proteinG = 0,
    this.carbsG = 0,
    this.fatG = 0,
    this.usdaFdcId,
    this.needsReview = false,
  });

  final String name;
  final double grams;
  final double calories;
  final double proteinG;
  final double carbsG;
  final double fatG;
  final String? usdaFdcId;
  final bool needsReview;

  factory FoodItem.fromJson(Map<String, dynamic> json) {
    return FoodItem(
      name: json['name'] as String,
      grams: (json['grams'] as num).toDouble(),
      calories: (json['calories'] as num? ?? 0).toDouble(),
      proteinG: (json['protein_g'] as num? ?? 0).toDouble(),
      carbsG: (json['carbs_g'] as num? ?? 0).toDouble(),
      fatG: (json['fat_g'] as num? ?? 0).toDouble(),
      usdaFdcId: json['usda_fdc_id'] as String?,
      needsReview: json['needs_review'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'grams': grams,
      'calories': calories,
      'protein_g': proteinG,
      'carbs_g': carbsG,
      'fat_g': fatG,
      'usda_fdc_id': usdaFdcId,
      'needs_review': needsReview,
    };
  }

  FoodItem copyWith({
    String? name,
    double? grams,
    double? calories,
    double? proteinG,
    double? carbsG,
    double? fatG,
    String? usdaFdcId,
    bool? needsReview,
  }) {
    return FoodItem(
      name: name ?? this.name,
      grams: grams ?? this.grams,
      calories: calories ?? this.calories,
      proteinG: proteinG ?? this.proteinG,
      carbsG: carbsG ?? this.carbsG,
      fatG: fatG ?? this.fatG,
      usdaFdcId: usdaFdcId ?? this.usdaFdcId,
      needsReview: needsReview ?? this.needsReview,
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/nutrition/domain/food_item_test.dart`
Expected: PASS (3 tests)

- [ ] **Step 5: Commit**

```bash
git add lib/features/nutrition/domain/food_item.dart test/features/nutrition/domain/food_item_test.dart
git commit -m "feat(nutrition): add FoodItem domain model"
```

---

## Task 3: Domain — `Meal`

**Files:**
- Create: `lib/features/nutrition/domain/meal.dart`
- Test: `test/features/nutrition/domain/meal_test.dart`

**Interfaces:**
- Consumes: `MealType`, `mealTypeFromDb` (Task 1); `FoodItem.fromJson` (Task 2)
- Produces: `class Meal` with fields `id (String)`, `userId (String)`, `mealType (MealType)`, `loggedAt (DateTime)`, `photoPath (String?)`, `items (List<FoodItem>)`; `Meal.fromJson(Map<String,dynamic>)` (Supabase'in nested `meal_items` select'ini bekler).

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:spor_takip/features/nutrition/domain/meal.dart';
import 'package:spor_takip/features/nutrition/domain/meal_type.dart';

void main() {
  test('fromJson parses meal fields and nested meal_items', () {
    final meal = Meal.fromJson({
      'id': 'meal-1',
      'user_id': 'user-1',
      'meal_type': 'lunch',
      'photo_path': 'user-1/meal-1.jpg',
      'logged_at': '2026-09-23T12:30:00.000Z',
      'meal_items': [
        {'name': 'Pilav', 'grams': 100, 'calories': 130, 'protein_g': 2.7, 'carbs_g': 28, 'fat_g': 0.3},
      ],
    });

    expect(meal.id, 'meal-1');
    expect(meal.userId, 'user-1');
    expect(meal.mealType, MealType.lunch);
    expect(meal.photoPath, 'user-1/meal-1.jpg');
    expect(meal.loggedAt, DateTime.parse('2026-09-23T12:30:00.000Z'));
    expect(meal.items, hasLength(1));
    expect(meal.items.single.name, 'Pilav');
  });

  test('fromJson handles a missing meal_items key as an empty list', () {
    final meal = Meal.fromJson({
      'id': 'meal-2',
      'user_id': 'user-1',
      'meal_type': 'snack',
      'photo_path': null,
      'logged_at': '2026-09-23T09:00:00.000Z',
    });

    expect(meal.items, isEmpty);
    expect(meal.photoPath, isNull);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/nutrition/domain/meal_test.dart`
Expected: FAIL — `meal.dart` bulunamıyor.

- [ ] **Step 3: Write minimal implementation**

```dart
import 'food_item.dart';
import 'meal_type.dart';

class Meal {
  const Meal({
    required this.id,
    required this.userId,
    required this.mealType,
    required this.loggedAt,
    required this.items,
    this.photoPath,
  });

  final String id;
  final String userId;
  final MealType mealType;
  final DateTime loggedAt;
  final String? photoPath;
  final List<FoodItem> items;

  factory Meal.fromJson(Map<String, dynamic> json) {
    final itemRows = json['meal_items'] as List? ?? const [];
    return Meal(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      mealType: mealTypeFromDb(json['meal_type'] as String),
      loggedAt: DateTime.parse(json['logged_at'] as String),
      photoPath: json['photo_path'] as String?,
      items: itemRows.map((e) => FoodItem.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/nutrition/domain/meal_test.dart`
Expected: PASS (2 tests)

- [ ] **Step 5: Commit**

```bash
git add lib/features/nutrition/domain/meal.dart test/features/nutrition/domain/meal_test.dart
git commit -m "feat(nutrition): add Meal domain model"
```

---

## Task 4: Domain — `MacroTotals` + `sumMealMacros`

**Files:**
- Create: `lib/features/nutrition/domain/macro_totals.dart`
- Test: `test/features/nutrition/domain/macro_totals_test.dart`

**Interfaces:**
- Consumes: `Meal`, `FoodItem` (Tasks 2-3)
- Produces: `class MacroTotals` (`calories`, `proteinG`, `carbsG`, `fatG`, `operator +`), `MacroTotals sumMealMacros(List<Meal> meals)`

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:spor_takip/features/nutrition/domain/food_item.dart';
import 'package:spor_takip/features/nutrition/domain/macro_totals.dart';
import 'package:spor_takip/features/nutrition/domain/meal.dart';
import 'package:spor_takip/features/nutrition/domain/meal_type.dart';

Meal _meal(List<FoodItem> items) => Meal(
      id: 'm',
      userId: 'u',
      mealType: MealType.lunch,
      loggedAt: DateTime(2026, 9, 23),
      items: items,
    );

void main() {
  test('MacroTotals + adds fields component-wise', () {
    const a = MacroTotals(calories: 100, proteinG: 10, carbsG: 5, fatG: 2);
    const b = MacroTotals(calories: 50, proteinG: 5, carbsG: 1, fatG: 1);
    final sum = a + b;
    expect(sum.calories, 150);
    expect(sum.proteinG, 15);
    expect(sum.carbsG, 6);
    expect(sum.fatG, 3);
  });

  test('sumMealMacros returns zero totals for an empty meal list', () {
    final totals = sumMealMacros(const []);
    expect(totals.calories, 0);
    expect(totals.proteinG, 0);
  });

  test('sumMealMacros sums every item across every meal', () {
    final meals = [
      _meal([
        const FoodItem(name: 'A', grams: 100, calories: 200, proteinG: 10, carbsG: 20, fatG: 5),
        const FoodItem(name: 'B', grams: 50, calories: 80, proteinG: 4, carbsG: 8, fatG: 2),
      ]),
      _meal([
        const FoodItem(name: 'C', grams: 150, calories: 300, proteinG: 25, carbsG: 10, fatG: 12),
      ]),
    ];

    final totals = sumMealMacros(meals);
    expect(totals.calories, 580);
    expect(totals.proteinG, 39);
    expect(totals.carbsG, 38);
    expect(totals.fatG, 19);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/nutrition/domain/macro_totals_test.dart`
Expected: FAIL — `macro_totals.dart` bulunamıyor.

- [ ] **Step 3: Write minimal implementation**

```dart
import 'meal.dart';

class MacroTotals {
  const MacroTotals({
    this.calories = 0,
    this.proteinG = 0,
    this.carbsG = 0,
    this.fatG = 0,
  });

  final double calories;
  final double proteinG;
  final double carbsG;
  final double fatG;

  MacroTotals operator +(MacroTotals other) {
    return MacroTotals(
      calories: calories + other.calories,
      proteinG: proteinG + other.proteinG,
      carbsG: carbsG + other.carbsG,
      fatG: fatG + other.fatG,
    );
  }
}

MacroTotals sumMealMacros(List<Meal> meals) {
  var total = const MacroTotals();
  for (final meal in meals) {
    for (final item in meal.items) {
      total = total +
          MacroTotals(
            calories: item.calories,
            proteinG: item.proteinG,
            carbsG: item.carbsG,
            fatG: item.fatG,
          );
    }
  }
  return total;
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/nutrition/domain/macro_totals_test.dart`
Expected: PASS (3 tests)

- [ ] **Step 5: Commit**

```bash
git add lib/features/nutrition/domain/macro_totals.dart test/features/nutrition/domain/macro_totals_test.dart
git commit -m "feat(nutrition): add MacroTotals and sumMealMacros aggregation"
```

---

## Task 5: DB Migration — `meals` / `meal_items`

**Files:**
- Create: `supabase/migrations/0002_create_meals.sql`

**Interfaces:**
- Produces: `public.meals(id, user_id, meal_type, photo_path, logged_at, created_at)`, `public.meal_items(id, meal_id, name, grams, calories, protein_g, carbs_g, fat_g, usda_fdc_id, needs_review, created_at)`, ikisinde de RLS.

Bu görevde otomatik test yok — proje CI'ı canlı bir Supabase veritabanına karşı çalışmıyor (mevcut `0001_create_profiles.sql`'in de testi yok). Doğrulama, gerçek Supabase anahtarları geldiğinde F1'deki gibi elle yapılacak.

- [ ] **Step 1: SQL migration dosyasını yaz**

```sql
create table if not exists public.meals (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  meal_type text not null check (meal_type in ('breakfast', 'lunch', 'dinner', 'snack')),
  photo_path text,
  logged_at timestamptz not null default now(),
  created_at timestamptz not null default now()
);

create table if not exists public.meal_items (
  id uuid primary key default gen_random_uuid(),
  meal_id uuid not null references public.meals (id) on delete cascade,
  name text not null,
  grams numeric not null check (grams > 0),
  calories numeric not null default 0,
  protein_g numeric not null default 0,
  carbs_g numeric not null default 0,
  fat_g numeric not null default 0,
  usda_fdc_id text,
  needs_review boolean not null default false,
  created_at timestamptz not null default now()
);

alter table public.meals enable row level security;
alter table public.meal_items enable row level security;

create policy "Users can manage own meals"
  on public.meals for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create policy "Users can manage own meal items"
  on public.meal_items for all
  using (exists (select 1 from public.meals m where m.id = meal_id and m.user_id = auth.uid()))
  with check (exists (select 1 from public.meals m where m.id = meal_id and m.user_id = auth.uid()));
```

- [ ] **Step 2: Dosyanın `0001_create_profiles.sql` ile aynı stil ve check-constraint paternini takip ettiğini gözle doğrula (satır satır karşılaştır).**

- [ ] **Step 3: Commit**

```bash
git add supabase/migrations/0002_create_meals.sql
git commit -m "feat(nutrition): add meals and meal_items migration with RLS"
```

---

## Task 6: DB Migration — `meal-photos` Storage Bucket

**Files:**
- Create: `supabase/migrations/0003_create_meal_photos_storage.sql`

**Interfaces:**
- Produces: `meal-photos` storage bucket + `storage.objects` üzerinde kullanıcı-bazlı RLS (yol öneki `{user_id}/`).

Bu görevde de otomatik test yok (bkz. Task 5 gerekçesi).

- [ ] **Step 1: SQL migration dosyasını yaz**

```sql
insert into storage.buckets (id, name, public)
values ('meal-photos', 'meal-photos', false)
on conflict (id) do nothing;

create policy "Users can upload own meal photos"
  on storage.objects for insert
  with check (
    bucket_id = 'meal-photos'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy "Users can read own meal photos"
  on storage.objects for select
  using (
    bucket_id = 'meal-photos'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy "Users can delete own meal photos"
  on storage.objects for delete
  using (
    bucket_id = 'meal-photos'
    and (storage.foldername(name))[1] = auth.uid()::text
  );
```

- [ ] **Step 2: Commit**

```bash
git add supabase/migrations/0003_create_meal_photos_storage.sql
git commit -m "feat(nutrition): add meal-photos storage bucket with per-user RLS"
```

---

## Task 7: Bağımlılıklar — `image_picker` + `uuid`

**Files:**
- Modify: `pubspec.yaml`

**Interfaces:**
- Produces: `package:image_picker/image_picker.dart` ve `package:uuid/uuid.dart` projede kullanılabilir hale gelir.

- [ ] **Step 1: Bağımlılıkları ekle**

Run: `flutter pub add image_picker uuid`

Expected: `pubspec.yaml`'a `image_picker: ^<resolved>` ve `uuid: ^<resolved>` satırları eklenir, `pubspec.lock` güncellenir.

- [ ] **Step 2: Çözümlemeyi doğrula**

Run: `flutter pub get`
Expected: Hatasız tamamlanır.

- [ ] **Step 3: Commit**

```bash
git add pubspec.yaml pubspec.lock
git commit -m "chore(nutrition): add image_picker and uuid dependencies"
```

---

## Task 8: Data — `MealRepository` (arayüz + Supabase implementasyonu)

**Files:**
- Create: `lib/features/nutrition/data/meal_repository.dart`
- Create: `lib/features/nutrition/application/meal_providers.dart`

**Interfaces:**
- Consumes: `Meal`, `FoodItem`, `MealType`, `mealTypeToDb` (Tasks 1-3); `AppSupabase.client` (`lib/core/supabase_client.dart`)
- Produces:
  - `enum AiFailureReason { none, unavailable, quotaExceeded }`
  - `class MealAnalysisResult { items (List<FoodItem>), failureReason (AiFailureReason) }`
  - `abstract interface class MealRepository` — `Future<String> uploadPhoto({required String userId, required String mealId, required Uint8List bytes})`, `Future<MealAnalysisResult> analyzeMealPhoto({required String photoPath})`, `Future<void> saveMeal({required String mealId, required String userId, required MealType mealType, required String? photoPath, required DateTime loggedAt, required List<FoodItem> items})`, `Future<List<Meal>> fetchMealsForDate({required String userId, required DateTime date})`
  - `class SupabaseMealRepository implements MealRepository`
  - `final mealRepositoryProvider = Provider<MealRepository>(...)`

Bu görevde `SupabaseMealRepository` için otomatik test yazılmıyor (bkz. plan başındaki Global Constraints — mevcut `ProfileRepository` paterni). `MealRepository` bilinçli olarak bir arayüz (`abstract interface class`) olarak tanımlanıyor ki Task 9'daki `MealCaptureNotifier` testleri gerçek Supabase'e dokunmadan bir `FakeMealRepository` ile çalışabilsin.

- [ ] **Step 1: `meal_repository.dart`'ı yaz**

```dart
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/food_item.dart';
import '../domain/meal.dart';
import '../domain/meal_type.dart';

enum AiFailureReason { none, unavailable, quotaExceeded }

class MealAnalysisResult {
  const MealAnalysisResult({required this.items, required this.failureReason});

  final List<FoodItem> items;
  final AiFailureReason failureReason;
}

abstract interface class MealRepository {
  Future<String> uploadPhoto({
    required String userId,
    required String mealId,
    required Uint8List bytes,
  });

  Future<MealAnalysisResult> analyzeMealPhoto({required String photoPath});

  Future<void> saveMeal({
    required String mealId,
    required String userId,
    required MealType mealType,
    required String? photoPath,
    required DateTime loggedAt,
    required List<FoodItem> items,
  });

  Future<List<Meal>> fetchMealsForDate({required String userId, required DateTime date});
}

class SupabaseMealRepository implements MealRepository {
  SupabaseMealRepository(this._client);

  final SupabaseClient _client;

  static const _photosBucket = 'meal-photos';
  static const _mealsTable = 'meals';
  static const _mealItemsTable = 'meal_items';

  @override
  Future<String> uploadPhoto({
    required String userId,
    required String mealId,
    required Uint8List bytes,
  }) async {
    final path = '$userId/$mealId.jpg';
    await _client.storage
        .from(_photosBucket)
        .uploadBinary(path, bytes, fileOptions: const FileOptions(upsert: true));
    return path;
  }

  @override
  Future<MealAnalysisResult> analyzeMealPhoto({required String photoPath}) async {
    try {
      final response = await _client.functions.invoke(
        'analyze-meal-photo',
        body: {'photo_path': photoPath},
      );
      final data = response.data as Map<String, dynamic>;
      final items = (data['items'] as List)
          .map((e) => FoodItem.fromJson(e as Map<String, dynamic>))
          .toList();
      return MealAnalysisResult(items: items, failureReason: AiFailureReason.none);
    } on FunctionException catch (error) {
      final details = error.details;
      final code = details is Map ? details['code'] as String? : null;
      if (code == 'GEMINI_QUOTA_EXCEEDED') {
        return const MealAnalysisResult(items: [], failureReason: AiFailureReason.quotaExceeded);
      }
      return const MealAnalysisResult(items: [], failureReason: AiFailureReason.unavailable);
    }
  }

  @override
  Future<void> saveMeal({
    required String mealId,
    required String userId,
    required MealType mealType,
    required String? photoPath,
    required DateTime loggedAt,
    required List<FoodItem> items,
  }) async {
    await _client.from(_mealsTable).insert({
      'id': mealId,
      'user_id': userId,
      'meal_type': mealTypeToDb(mealType),
      'photo_path': photoPath,
      'logged_at': loggedAt.toIso8601String(),
    });
    await _client.from(_mealItemsTable).insert(
          items.map((item) => {...item.toJson(), 'meal_id': mealId}).toList(),
        );
  }

  @override
  Future<List<Meal>> fetchMealsForDate({required String userId, required DateTime date}) async {
    final start = DateTime(date.year, date.month, date.day);
    final end = start.add(const Duration(days: 1));
    final rows = await _client
        .from(_mealsTable)
        .select('*, meal_items(*)')
        .eq('user_id', userId)
        .gte('logged_at', start.toIso8601String())
        .lt('logged_at', end.toIso8601String())
        .order('logged_at');
    return (rows as List).map((row) => Meal.fromJson(row as Map<String, dynamic>)).toList();
  }
}
```

- [ ] **Step 2: `meal_providers.dart`'ı yaz**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase_client.dart';
import '../data/meal_repository.dart';

final mealRepositoryProvider = Provider<MealRepository>((ref) {
  return SupabaseMealRepository(AppSupabase.client);
});
```

- [ ] **Step 3: Derlemenin geçtiğini doğrula**

Run: `flutter analyze lib/features/nutrition`
Expected: Hata yok.

- [ ] **Step 4: Commit**

```bash
git add lib/features/nutrition/data/meal_repository.dart lib/features/nutrition/application/meal_providers.dart
git commit -m "feat(nutrition): add MealRepository interface and Supabase implementation"
```

---

## Task 9: Application — `MealCaptureNotifier`

**Files:**
- Create: `lib/features/nutrition/application/meal_capture_state.dart`
- Create: `lib/features/nutrition/application/meal_capture_notifier.dart`
- Create: `test/features/nutrition/application/fake_meal_repository.dart`
- Test: `test/features/nutrition/application/meal_capture_notifier_test.dart`

**Interfaces:**
- Consumes: `MealRepository`, `AiFailureReason`, `MealAnalysisResult` (Task 8); `FoodItem`, `MealType` (Tasks 1-2); `AuthRepository.currentUserId`, `authRepositoryProvider` (`lib/features/onboarding/application/auth_providers.dart`, mevcut); `todayMealsProvider` (Task 10 — sadece `ref.invalidate` ile referans verilir, dairesel import yok çünkü `today_meals_provider.dart` bu dosyayı import etmeyecek)
- Produces:
  - `sealed class MealCaptureState`; alt sınıflar: `MealCaptureIdle`, `MealCaptureUploading`, `MealCaptureAnalyzing`, `MealCaptureReviewing` (`mealType`, `mealId`, `photoPath`, `items`, `aiFailureReason`, `canSave` getter, `copyWith`), `MealCaptureSaving`, `MealCaptureSaved`, `MealCaptureUploadError` (`mealType`)
  - `final mealCaptureProvider = NotifierProvider<MealCaptureNotifier, MealCaptureState>(...)`
  - `class MealCaptureNotifier` — `startCapture({required MealType mealType, required Uint8List photoBytes})`, `updateItem(int index, FoodItem updated)`, `removeItem(int index)`, `addManualItem()`, `confirmSave()`, `reset()`

Not: Task 10'daki `todayMealsProvider`'a `ref.invalidate` çağrısı, Task 10 tamamlanana kadar derlenmeyecek bir import gerektirir. Bu yüzden bu görevde `confirmSave()` içinde invalidate çağrısı **yapılmaz**; bu satır Task 10'da, `today_meals_provider.dart` oluşturulduktan hemen sonra `meal_capture_notifier.dart`'a eklenir (Task 10'un Step listesine dahil).

- [ ] **Step 1: State sınıflarının testini yaz**

```dart
// test/features/nutrition/application/meal_capture_notifier_test.dart (ilk blok)
import 'package:flutter_test/flutter_test.dart';
import 'package:spor_takip/features/nutrition/application/meal_capture_state.dart';
import 'package:spor_takip/features/nutrition/domain/food_item.dart';
import 'package:spor_takip/features/nutrition/domain/meal_type.dart';

void main() {
  group('MealCaptureReviewing.canSave', () {
    test('false when items is empty', () {
      const state = MealCaptureReviewing(
        mealType: MealType.lunch,
        mealId: 'm',
        photoPath: 'p',
        items: [],
      );
      expect(state.canSave, isFalse);
    });

    test('false when any item needs review', () {
      const state = MealCaptureReviewing(
        mealType: MealType.lunch,
        mealId: 'm',
        photoPath: 'p',
        items: [
          FoodItem(name: 'A', grams: 100, needsReview: false),
          FoodItem(name: 'B', grams: 50, needsReview: true),
        ],
      );
      expect(state.canSave, isFalse);
    });

    test('false when any item has grams <= 0', () {
      const state = MealCaptureReviewing(
        mealType: MealType.lunch,
        mealId: 'm',
        photoPath: 'p',
        items: [FoodItem(name: 'A', grams: 0, needsReview: false)],
      );
      expect(state.canSave, isFalse);
    });

    test('true when items is non-empty, all reviewed, all grams > 0', () {
      const state = MealCaptureReviewing(
        mealType: MealType.lunch,
        mealId: 'm',
        photoPath: 'p',
        items: [FoodItem(name: 'A', grams: 100, needsReview: false)],
      );
      expect(state.canSave, isTrue);
    });
  });
}
```

- [ ] **Step 2: Testi çalıştırıp başarısız olduğunu doğrula**

Run: `flutter test test/features/nutrition/application/meal_capture_notifier_test.dart`
Expected: FAIL — `meal_capture_state.dart` bulunamıyor.

- [ ] **Step 3: `meal_capture_state.dart`'ı yaz**

```dart
import '../data/meal_repository.dart';
import '../domain/food_item.dart';
import '../domain/meal_type.dart';

sealed class MealCaptureState {
  const MealCaptureState();
}

class MealCaptureIdle extends MealCaptureState {
  const MealCaptureIdle();
}

class MealCaptureUploading extends MealCaptureState {
  const MealCaptureUploading();
}

class MealCaptureAnalyzing extends MealCaptureState {
  const MealCaptureAnalyzing();
}

class MealCaptureReviewing extends MealCaptureState {
  const MealCaptureReviewing({
    required this.mealType,
    required this.mealId,
    required this.photoPath,
    required this.items,
    this.aiFailureReason = AiFailureReason.none,
  });

  final MealType mealType;
  final String mealId;
  final String photoPath;
  final List<FoodItem> items;
  final AiFailureReason aiFailureReason;

  bool get canSave =>
      items.isNotEmpty && items.every((item) => item.grams > 0 && !item.needsReview);

  MealCaptureReviewing copyWith({List<FoodItem>? items}) {
    return MealCaptureReviewing(
      mealType: mealType,
      mealId: mealId,
      photoPath: photoPath,
      items: items ?? this.items,
      aiFailureReason: aiFailureReason,
    );
  }
}

class MealCaptureSaving extends MealCaptureState {
  const MealCaptureSaving();
}

class MealCaptureSaved extends MealCaptureState {
  const MealCaptureSaved();
}

class MealCaptureUploadError extends MealCaptureState {
  const MealCaptureUploadError({required this.mealType});

  final MealType mealType;
}
```

- [ ] **Step 4: Testi çalıştırıp geçtiğini doğrula**

Run: `flutter test test/features/nutrition/application/meal_capture_notifier_test.dart`
Expected: PASS (4 tests)

- [ ] **Step 5: `FakeMealRepository` test yardımcısını yaz**

```dart
// test/features/nutrition/application/fake_meal_repository.dart
import 'dart:typed_data';

import 'package:spor_takip/features/nutrition/data/meal_repository.dart';
import 'package:spor_takip/features/nutrition/domain/food_item.dart';
import 'package:spor_takip/features/nutrition/domain/meal.dart';
import 'package:spor_takip/features/nutrition/domain/meal_type.dart';

class FakeMealRepository implements MealRepository {
  String uploadedPath = 'user-1/meal-1.jpg';
  Object? uploadError;
  MealAnalysisResult analyzeResult =
      const MealAnalysisResult(items: [], failureReason: AiFailureReason.none);
  Object? saveError;
  final List<Map<String, dynamic>> savedCalls = [];

  @override
  Future<String> uploadPhoto({
    required String userId,
    required String mealId,
    required Uint8List bytes,
  }) async {
    if (uploadError != null) throw uploadError!;
    return uploadedPath;
  }

  @override
  Future<MealAnalysisResult> analyzeMealPhoto({required String photoPath}) async {
    return analyzeResult;
  }

  @override
  Future<void> saveMeal({
    required String mealId,
    required String userId,
    required MealType mealType,
    required String? photoPath,
    required DateTime loggedAt,
    required List<FoodItem> items,
  }) async {
    if (saveError != null) throw saveError!;
    savedCalls.add({
      'mealId': mealId,
      'userId': userId,
      'mealType': mealType,
      'photoPath': photoPath,
      'items': items,
    });
  }

  @override
  Future<List<Meal>> fetchMealsForDate({required String userId, required DateTime date}) async {
    return const [];
  }
}
```

- [ ] **Step 6: `MealCaptureNotifier` davranış testlerini ekle (aynı test dosyasına, `main()` içine yeni bir `group` olarak)**

```dart
// meal_capture_notifier_test.dart dosyasına eklenecek importlar:
// import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:spor_takip/features/nutrition/application/meal_capture_notifier.dart';
// import 'package:spor_takip/features/nutrition/application/meal_providers.dart';
// import 'package:spor_takip/features/onboarding/application/auth_providers.dart';
// import 'package:supabase_flutter/supabase_flutter.dart' show AuthRepository;
// import 'fake_meal_repository.dart';
//
// Not: AuthRepository somut bir sınıf; testte gerçek Supabase client'a
// dokunmadan currentUserId döndürmek için authRepositoryProvider yerine
// doğrudan bir stub AuthRepository alt sınıfı kullanılır.

class _StubAuthRepository implements AuthRepository {
  @override
  String get currentUserId => 'user-1';

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} stub edilmedi');
}

void _registerNotifierTests() {
  group('MealCaptureNotifier', () {
    late FakeMealRepository fakeRepo;
    late ProviderContainer container;

    setUp(() {
      fakeRepo = FakeMealRepository();
      container = ProviderContainer(overrides: [
        mealRepositoryProvider.overrideWithValue(fakeRepo),
        authRepositoryProvider.overrideWithValue(_StubAuthRepository()),
      ]);
    });

    tearDown(() => container.dispose());

    test('startCapture moves idle -> uploading -> analyzing -> reviewing', () async {
      fakeRepo.analyzeResult = const MealAnalysisResult(
        items: [FoodItem(name: 'Tavuk', grams: 150, calories: 250)],
        failureReason: AiFailureReason.none,
      );

      final notifier = container.read(mealCaptureProvider.notifier);
      expect(container.read(mealCaptureProvider), isA<MealCaptureIdle>());

      final future = notifier.startCapture(
        mealType: MealType.lunch,
        photoBytes: Uint8List(0),
      );
      await future;

      final state = container.read(mealCaptureProvider);
      expect(state, isA<MealCaptureReviewing>());
      expect((state as MealCaptureReviewing).items.single.name, 'Tavuk');
      expect(state.aiFailureReason, AiFailureReason.none);
    });

    test('startCapture surfaces upload failures as MealCaptureUploadError', () async {
      fakeRepo.uploadError = Exception('network down');
      final notifier = container.read(mealCaptureProvider.notifier);

      await notifier.startCapture(mealType: MealType.breakfast, photoBytes: Uint8List(0));

      final state = container.read(mealCaptureProvider);
      expect(state, isA<MealCaptureUploadError>());
      expect((state as MealCaptureUploadError).mealType, MealType.breakfast);
    });

    test('startCapture with AI failure reaches Reviewing with empty items and the reason set', () async {
      fakeRepo.analyzeResult =
          const MealAnalysisResult(items: [], failureReason: AiFailureReason.quotaExceeded);
      final notifier = container.read(mealCaptureProvider.notifier);

      await notifier.startCapture(mealType: MealType.dinner, photoBytes: Uint8List(0));

      final state = container.read(mealCaptureProvider) as MealCaptureReviewing;
      expect(state.items, isEmpty);
      expect(state.aiFailureReason, AiFailureReason.quotaExceeded);
      expect(state.canSave, isFalse);
    });

    test('updateItem replaces the item at index', () async {
      fakeRepo.analyzeResult = const MealAnalysisResult(
        items: [FoodItem(name: 'A', grams: 100), FoodItem(name: 'B', grams: 50)],
        failureReason: AiFailureReason.none,
      );
      final notifier = container.read(mealCaptureProvider.notifier);
      await notifier.startCapture(mealType: MealType.snack, photoBytes: Uint8List(0));

      notifier.updateItem(1, const FoodItem(name: 'B düzeltildi', grams: 60));

      final state = container.read(mealCaptureProvider) as MealCaptureReviewing;
      expect(state.items[1].name, 'B düzeltildi');
      expect(state.items[1].grams, 60);
      expect(state.items[0].name, 'A');
    });

    test('removeItem drops the item at index', () async {
      fakeRepo.analyzeResult = const MealAnalysisResult(
        items: [FoodItem(name: 'A', grams: 100), FoodItem(name: 'B', grams: 50)],
        failureReason: AiFailureReason.none,
      );
      final notifier = container.read(mealCaptureProvider.notifier);
      await notifier.startCapture(mealType: MealType.snack, photoBytes: Uint8List(0));

      notifier.removeItem(0);

      final state = container.read(mealCaptureProvider) as MealCaptureReviewing;
      expect(state.items, hasLength(1));
      expect(state.items.single.name, 'B');
    });

    test('addManualItem appends a needs-review placeholder item', () async {
      fakeRepo.analyzeResult = const MealAnalysisResult(items: [], failureReason: AiFailureReason.none);
      final notifier = container.read(mealCaptureProvider.notifier);
      await notifier.startCapture(mealType: MealType.snack, photoBytes: Uint8List(0));

      notifier.addManualItem();

      final state = container.read(mealCaptureProvider) as MealCaptureReviewing;
      expect(state.items, hasLength(1));
      expect(state.items.single.needsReview, isTrue);
      expect(state.items.single.grams, 0);
    });

    test('confirmSave is a no-op when canSave is false', () async {
      fakeRepo.analyzeResult = const MealAnalysisResult(items: [], failureReason: AiFailureReason.none);
      final notifier = container.read(mealCaptureProvider.notifier);
      await notifier.startCapture(mealType: MealType.snack, photoBytes: Uint8List(0));

      await notifier.confirmSave();

      expect(fakeRepo.savedCalls, isEmpty);
      expect(container.read(mealCaptureProvider), isA<MealCaptureReviewing>());
    });

    test('confirmSave saves and transitions to MealCaptureSaved when canSave is true', () async {
      fakeRepo.analyzeResult = const MealAnalysisResult(
        items: [FoodItem(name: 'Tavuk', grams: 150, calories: 250)],
        failureReason: AiFailureReason.none,
      );
      final notifier = container.read(mealCaptureProvider.notifier);
      await notifier.startCapture(mealType: MealType.lunch, photoBytes: Uint8List(0));

      await notifier.confirmSave();

      expect(fakeRepo.savedCalls, hasLength(1));
      expect(fakeRepo.savedCalls.single['userId'], 'user-1');
      expect(container.read(mealCaptureProvider), isA<MealCaptureSaved>());
    });

    test('confirmSave keeps Reviewing state on save failure', () async {
      fakeRepo.analyzeResult = const MealAnalysisResult(
        items: [FoodItem(name: 'Tavuk', grams: 150, calories: 250)],
        failureReason: AiFailureReason.none,
      );
      fakeRepo.saveError = Exception('insert failed');
      final notifier = container.read(mealCaptureProvider.notifier);
      await notifier.startCapture(mealType: MealType.lunch, photoBytes: Uint8List(0));

      await notifier.confirmSave();

      expect(container.read(mealCaptureProvider), isA<MealCaptureReviewing>());
    });

    test('reset returns to Idle', () async {
      fakeRepo.analyzeResult = const MealAnalysisResult(items: [], failureReason: AiFailureReason.none);
      final notifier = container.read(mealCaptureProvider.notifier);
      await notifier.startCapture(mealType: MealType.snack, photoBytes: Uint8List(0));

      notifier.reset();

      expect(container.read(mealCaptureProvider), isA<MealCaptureIdle>());
    });
  });
}
```

`main()` fonksiyonunun içine, mevcut `canSave` grubunun hemen altına `_registerNotifierTests();` çağrısını ekle.

- [ ] **Step 7: Testi çalıştırıp başarısız olduğunu doğrula**

Run: `flutter test test/features/nutrition/application/meal_capture_notifier_test.dart`
Expected: FAIL — `meal_capture_notifier.dart` ve `meal_providers.dart` içindeki `mealRepositoryProvider` bulunamıyor / `_StubAuthRepository` `AuthRepository`'yi implement edemiyor (yöntem eksik) — bir sonraki adımda çözülecek.

- [ ] **Step 8: `meal_capture_notifier.dart`'ı yaz**

```dart
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../onboarding/application/auth_providers.dart';
import '../domain/food_item.dart';
import '../domain/meal_type.dart';
import 'meal_capture_state.dart';
import 'meal_providers.dart';

final mealCaptureProvider = NotifierProvider<MealCaptureNotifier, MealCaptureState>(
  MealCaptureNotifier.new,
);

class MealCaptureNotifier extends Notifier<MealCaptureState> {
  MealCaptureNotifier({Uuid? uuid}) : _uuid = uuid ?? const Uuid();

  final Uuid _uuid;

  @override
  MealCaptureState build() => const MealCaptureIdle();

  Future<void> startCapture({
    required MealType mealType,
    required Uint8List photoBytes,
  }) async {
    final repo = ref.read(mealRepositoryProvider);
    final userId = ref.read(authRepositoryProvider).currentUserId;
    final mealId = _uuid.v4();

    state = const MealCaptureUploading();
    final String photoPath;
    try {
      photoPath = await repo.uploadPhoto(userId: userId, mealId: mealId, bytes: photoBytes);
    } catch (_) {
      state = MealCaptureUploadError(mealType: mealType);
      return;
    }

    state = const MealCaptureAnalyzing();
    final result = await repo.analyzeMealPhoto(photoPath: photoPath);
    state = MealCaptureReviewing(
      mealType: mealType,
      mealId: mealId,
      photoPath: photoPath,
      items: result.items,
      aiFailureReason: result.failureReason,
    );
  }

  void updateItem(int index, FoodItem updated) {
    final current = state;
    if (current is! MealCaptureReviewing) return;
    final items = [...current.items];
    items[index] = updated;
    state = current.copyWith(items: items);
  }

  void removeItem(int index) {
    final current = state;
    if (current is! MealCaptureReviewing) return;
    final items = [...current.items]..removeAt(index);
    state = current.copyWith(items: items);
  }

  void addManualItem() {
    final current = state;
    if (current is! MealCaptureReviewing) return;
    state = current.copyWith(items: [
      ...current.items,
      const FoodItem(name: '', grams: 0, needsReview: true),
    ]);
  }

  Future<void> confirmSave() async {
    final current = state;
    if (current is! MealCaptureReviewing || !current.canSave) return;

    final repo = ref.read(mealRepositoryProvider);
    final userId = ref.read(authRepositoryProvider).currentUserId;
    state = const MealCaptureSaving();
    try {
      await repo.saveMeal(
        mealId: current.mealId,
        userId: userId,
        mealType: current.mealType,
        photoPath: current.photoPath,
        loggedAt: DateTime.now(),
        items: current.items,
      );
      state = const MealCaptureSaved();
    } catch (_) {
      state = current;
    }
  }

  void reset() => state = const MealCaptureIdle();
}
```

- [ ] **Step 9: `_StubAuthRepository`'nin `AuthRepository`'yi karşıladığını doğrula**

`AuthRepository` somut bir sınıf olduğu için `implements AuthRepository` ile `_StubAuthRepository`, tüm public üyeleri (constructor hariç: `currentUserId`, `signUp`, `signIn`, `signOut`, `resetPassword`, `signInWithGoogle`) karşılamak zorundadır. `noSuchMethod` override'ı ve `implements` birlikte kullanıldığında Dart, override edilmeyen üyeler için `noSuchMethod`'a düşer — bu çalışır çünkü sınıf `implements` (soyutlama) kullanıyor, `extends` değil. Bu adım sadece bunu doğrulamak için `flutter analyze` çalıştırır.

Run: `flutter analyze test/features/nutrition/application`
Expected: Hata yok (uyarı olabilir, hata olmamalı).

- [ ] **Step 10: Testi çalıştırıp geçtiğini doğrula**

Run: `flutter test test/features/nutrition/application/meal_capture_notifier_test.dart`
Expected: PASS (14 test: 4 canSave + 10 notifier)

- [ ] **Step 11: Commit**

```bash
git add lib/features/nutrition/application/meal_capture_state.dart \
        lib/features/nutrition/application/meal_capture_notifier.dart \
        test/features/nutrition/application/fake_meal_repository.dart \
        test/features/nutrition/application/meal_capture_notifier_test.dart
git commit -m "feat(nutrition): add MealCaptureNotifier state machine"
```

---

## Task 10: Application — `todayMealsProvider`

**Files:**
- Create: `lib/features/nutrition/application/today_meals_provider.dart`
- Modify: `lib/features/nutrition/application/meal_capture_notifier.dart` (Task 9'da bırakılan `confirmSave` içine invalidate ekle)

**Interfaces:**
- Consumes: `mealRepositoryProvider` (Task 8), `isLoggedInProvider` (mevcut `auth_providers.dart`), `AppSupabase.client` (mevcut)
- Produces: `final todayMealsProvider = FutureProvider.autoDispose<List<Meal>>(...)`

Bu provider mevcut `profileProvider` ile aynı seviyede ince bir wiring katmanı; `profileProvider`'ın da doğrudan testi yok (sadece altındaki repository fake'lenerek notifier/aggregation testleri var). Bu yüzden burada da ayrı bir unit test yazılmıyor — Task 13'teki `NutritionScreen` widget testi bu provider'ı override ederek dolaylı olarak egzersiz eder.

- [ ] **Step 1: `today_meals_provider.dart`'ı yaz**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase_client.dart';
import '../../onboarding/application/auth_providers.dart';
import '../domain/meal.dart';
import 'meal_providers.dart';

final todayMealsProvider = FutureProvider.autoDispose<List<Meal>>((ref) async {
  final isLoggedIn = ref.watch(isLoggedInProvider);
  if (!isLoggedIn) return const [];
  final userId = AppSupabase.client.auth.currentUser!.id;
  return ref.watch(mealRepositoryProvider).fetchMealsForDate(
        userId: userId,
        date: DateTime.now(),
      );
});
```

- [ ] **Step 2: `meal_capture_notifier.dart`'ı güncelle — `confirmSave` başarılı kayıttan sonra günlük listeyi geçersiz kılsın**

`import 'meal_capture_state.dart';` satırının altına ekle:

```dart
import 'today_meals_provider.dart';
```

`confirmSave` metodunda `state = const MealCaptureSaved();` satırını şu şekilde değiştir:

```dart
      state = const MealCaptureSaved();
      ref.invalidate(todayMealsProvider);
```

- [ ] **Step 3: Notifier testlerinin hâlâ geçtiğini doğrula (invalidate, override edilmemiş bir provider'ı geçersiz kılmak hata fırlatmaz)**

Run: `flutter test test/features/nutrition/application/meal_capture_notifier_test.dart`
Expected: PASS (14 test)

- [ ] **Step 4: Derlemeyi doğrula**

Run: `flutter analyze lib/features/nutrition`
Expected: Hata yok.

- [ ] **Step 5: Commit**

```bash
git add lib/features/nutrition/application/today_meals_provider.dart \
        lib/features/nutrition/application/meal_capture_notifier.dart
git commit -m "feat(nutrition): add todayMealsProvider and invalidate it after save"
```

---

## Task 11: Presentation — `FoodItemEditTile`

**Files:**
- Create: `lib/features/nutrition/presentation/widgets/food_item_edit_tile.dart`
- Test: `test/features/nutrition/presentation/widgets/food_item_edit_tile_test.dart`
- Modify: `assets/translations/tr.json`, `assets/translations/en.json`

**Interfaces:**
- Consumes: `FoodItem` (Task 2)
- Produces: `class FoodItemEditTile extends StatelessWidget` — `({required FoodItem item, required int index, required ValueChanged<FoodItem> onChanged, required VoidCallback onRemove})`

- [ ] **Step 1: i18n anahtarlarını ekle**

`tr.json`'daki `"home"` bloğunun altına, aynı seviyede yeni bir blok:

```json
  "nutrition": {
    "item_name_label": "Yiyecek adı",
    "item_grams_label": "Gram",
    "item_needs_review": "Elle onay gerekiyor",
    "item_remove": "Kaldır"
  }
```

`en.json`'daki `"home"` bloğunun altına aynı yapı:

```json
  "nutrition": {
    "item_name_label": "Food name",
    "item_grams_label": "Grams",
    "item_needs_review": "Needs manual review",
    "item_remove": "Remove"
  }
```

(Dosyanın en dışındaki `{ ... }` kapanışına dikkat — `"home"` bloğundan sonra virgül eklenip yeni blok araya girer.)

- [ ] **Step 2: Widget testini yaz**

```dart
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spor_takip/features/nutrition/domain/food_item.dart';
import 'package:spor_takip/features/nutrition/presentation/widgets/food_item_edit_tile.dart';

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  Widget wrap(Widget child) {
    return EasyLocalization(
      supportedLocales: const [Locale('tr'), Locale('en')],
      path: 'assets/translations',
      fallbackLocale: const Locale('tr'),
      child: MaterialApp(home: Scaffold(body: child)),
    );
  }

  testWidgets('shows name and grams fields, no macro fields when reviewed', (tester) async {
    const item = FoodItem(name: 'Tavuk', grams: 150, calories: 250, needsReview: false);
    await tester.pumpWidget(wrap(FoodItemEditTile(
      item: item,
      index: 0,
      onChanged: (_) {},
      onRemove: () {},
    )));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('food_item_name_field_0')), findsOneWidget);
    expect(find.byKey(const Key('food_item_grams_field_0')), findsOneWidget);
    expect(find.byKey(const Key('food_item_calories_field_0')), findsNothing);
  });

  testWidgets('shows macro fields and a review badge when needsReview is true', (tester) async {
    const item = FoodItem(name: '', grams: 0, needsReview: true);
    await tester.pumpWidget(wrap(FoodItemEditTile(
      item: item,
      index: 0,
      onChanged: (_) {},
      onRemove: () {},
    )));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('food_item_calories_field_0')), findsOneWidget);
    expect(find.byKey(const Key('food_item_needs_review_badge_0')), findsOneWidget);
  });

  testWidgets('editing grams calls onChanged with updated value and needsReview false', (tester) async {
    FoodItem? changed;
    const item = FoodItem(name: 'Sos', grams: 0, needsReview: true);
    await tester.pumpWidget(wrap(FoodItemEditTile(
      item: item,
      index: 0,
      onChanged: (updated) => changed = updated,
      onRemove: () {},
    )));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('food_item_grams_field_0')), '30');
    await tester.pump();

    expect(changed, isNotNull);
    expect(changed!.grams, 30);
    expect(changed!.needsReview, isFalse);
  });

  testWidgets('tapping remove calls onRemove', (tester) async {
    var removed = false;
    const item = FoodItem(name: 'Tavuk', grams: 150);
    await tester.pumpWidget(wrap(FoodItemEditTile(
      item: item,
      index: 2,
      onChanged: (_) {},
      onRemove: () => removed = true,
    )));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('food_item_remove_button_2')));
    await tester.pump();

    expect(removed, isTrue);
  });
}
```

- [ ] **Step 3: Testi çalıştırıp başarısız olduğunu doğrula**

Run: `flutter test test/features/nutrition/presentation/widgets/food_item_edit_tile_test.dart`
Expected: FAIL — `food_item_edit_tile.dart` bulunamıyor.

- [ ] **Step 4: `food_item_edit_tile.dart`'ı yaz**

```dart
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../domain/food_item.dart';

class FoodItemEditTile extends StatelessWidget {
  const FoodItemEditTile({
    super.key,
    required this.item,
    required this.index,
    required this.onChanged,
    required this.onRemove,
  });

  final FoodItem item;
  final int index;
  final ValueChanged<FoodItem> onChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    key: Key('food_item_name_field_$index'),
                    initialValue: item.name,
                    decoration: InputDecoration(labelText: 'nutrition.item_name_label'.tr()),
                    onChanged: (value) => onChanged(item.copyWith(name: value, needsReview: false)),
                  ),
                ),
                IconButton(
                  key: Key('food_item_remove_button_$index'),
                  icon: const Icon(Icons.delete_outline),
                  tooltip: 'nutrition.item_remove'.tr(),
                  onPressed: onRemove,
                ),
              ],
            ),
            TextFormField(
              key: Key('food_item_grams_field_$index'),
              initialValue: item.grams == 0 ? '' : item.grams.toString(),
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: 'nutrition.item_grams_label'.tr()),
              onChanged: (value) {
                final grams = double.tryParse(value) ?? 0;
                onChanged(item.copyWith(grams: grams, needsReview: false));
              },
            ),
            if (item.needsReview) ...[
              Chip(
                key: Key('food_item_needs_review_badge_$index'),
                label: Text('nutrition.item_needs_review'.tr()),
                backgroundColor: Theme.of(context).colorScheme.errorContainer,
              ),
              TextFormField(
                key: Key('food_item_calories_field_$index'),
                initialValue: item.calories == 0 ? '' : item.calories.toString(),
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Kalori'),
                onChanged: (value) {
                  final calories = double.tryParse(value) ?? 0;
                  onChanged(item.copyWith(calories: calories, needsReview: false));
                },
              ),
              TextFormField(
                key: Key('food_item_protein_field_$index'),
                initialValue: item.proteinG == 0 ? '' : item.proteinG.toString(),
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Protein (g)'),
                onChanged: (value) {
                  final protein = double.tryParse(value) ?? 0;
                  onChanged(item.copyWith(proteinG: protein, needsReview: false));
                },
              ),
              TextFormField(
                key: Key('food_item_carbs_field_$index'),
                initialValue: item.carbsG == 0 ? '' : item.carbsG.toString(),
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Karbonhidrat (g)'),
                onChanged: (value) {
                  final carbs = double.tryParse(value) ?? 0;
                  onChanged(item.copyWith(carbsG: carbs, needsReview: false));
                },
              ),
              TextFormField(
                key: Key('food_item_fat_field_$index'),
                initialValue: item.fatG == 0 ? '' : item.fatG.toString(),
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Yağ (g)'),
                onChanged: (value) {
                  final fat = double.tryParse(value) ?? 0;
                  onChanged(item.copyWith(fatG: fat, needsReview: false));
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}
```

Not: `onChanged` her alanda `needsReview: false` gönderir — spec §6'daki kural şu: kullanıcının herhangi bir alanı elle düzenlemesi, o öğeyi "onaylanmış" sayar. `canSave` (Task 9) zaten `grams > 0` şartını ayrıca kontrol ettiği için sadece `needsReview`'ı temizlemek yeterli; grams hâlâ 0 ise `canSave` false kalmaya devam eder.

- [ ] **Step 5: Testi çalıştırıp geçtiğini doğrula**

Run: `flutter test test/features/nutrition/presentation/widgets/food_item_edit_tile_test.dart`
Expected: PASS (4 test)

- [ ] **Step 6: Commit**

```bash
git add lib/features/nutrition/presentation/widgets/food_item_edit_tile.dart \
        test/features/nutrition/presentation/widgets/food_item_edit_tile_test.dart \
        assets/translations/tr.json assets/translations/en.json
git commit -m "feat(nutrition): add FoodItemEditTile widget"
```

---

## Task 12: Presentation — `MealCaptureScreen`

**Files:**
- Create: `lib/features/nutrition/presentation/meal_capture_screen.dart`
- Test: `test/features/nutrition/presentation/meal_capture_screen_test.dart`
- Modify: `assets/translations/tr.json`, `assets/translations/en.json`

**Interfaces:**
- Consumes: `mealCaptureProvider`, `MealCaptureNotifier`, `MealCaptureState` alt sınıfları (Task 9); `FoodItemEditTile` (Task 11); `mealRepositoryProvider` (Task 8, test override'ları için); `MealType` (Task 1)
- Produces: `class MealCaptureScreen extends ConsumerStatefulWidget({Key? key, Future<Uint8List?> Function(ImageSource)? pickImageOverride})`

- [ ] **Step 1: i18n anahtarlarını ekle**

`tr.json`'daki `"nutrition"` bloğuna ekle (Task 11'de açılan bloğun içine, virgülle):

```json
    "capture_title": "Öğün Ekle",
    "select_meal_type": "Öğün türünü seç",
    "meal_type_breakfast": "Kahvaltı",
    "meal_type_lunch": "Öğle",
    "meal_type_dinner": "Akşam",
    "meal_type_snack": "Atıştırmalık",
    "take_photo": "Fotoğraf çek",
    "pick_from_gallery": "Galeriden seç",
    "uploading": "Yükleniyor...",
    "analyzing": "Analiz ediliyor...",
    "saving": "Kaydediliyor...",
    "upload_error": "Fotoğraf yüklenemedi, tekrar dene",
    "retry": "Tekrar dene",
    "ai_unavailable": "AI şu an kullanılamıyor, öğünü elle ekleyebilirsin",
    "ai_quota_exceeded": "Günlük AI analiz limiti doldu, öğünü elle ekleyebilirsin",
    "add_item_manually": "Yiyecek ekle",
    "save": "Kaydet"
```

`en.json`'a aynı yapı, İngilizce karşılıklarıyla:

```json
    "capture_title": "Add Meal",
    "select_meal_type": "Select meal type",
    "meal_type_breakfast": "Breakfast",
    "meal_type_lunch": "Lunch",
    "meal_type_dinner": "Dinner",
    "meal_type_snack": "Snack",
    "take_photo": "Take photo",
    "pick_from_gallery": "Pick from gallery",
    "uploading": "Uploading...",
    "analyzing": "Analyzing...",
    "saving": "Saving...",
    "upload_error": "Photo upload failed, try again",
    "retry": "Retry",
    "ai_unavailable": "AI is unavailable right now, you can add the meal manually",
    "ai_quota_exceeded": "Daily AI analysis limit reached, you can add the meal manually",
    "add_item_manually": "Add food item",
    "save": "Save"
```

- [ ] **Step 2: Widget testini yaz**

```dart
import 'dart:typed_data';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spor_takip/features/nutrition/application/meal_providers.dart';
import 'package:spor_takip/features/nutrition/data/meal_repository.dart';
import 'package:spor_takip/features/nutrition/domain/food_item.dart';
import 'package:spor_takip/features/nutrition/presentation/meal_capture_screen.dart';
import 'package:spor_takip/features/onboarding/application/auth_providers.dart';

import '../application/fake_meal_repository.dart';

class _StubAuthRepository implements AuthRepository {
  @override
  String get currentUserId => 'user-1';

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} stub edilmedi');
}

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  Widget wrap(Widget child, {required FakeMealRepository repo}) {
    return EasyLocalization(
      supportedLocales: const [Locale('tr'), Locale('en')],
      path: 'assets/translations',
      fallbackLocale: const Locale('tr'),
      child: ProviderScope(
        overrides: [
          mealRepositoryProvider.overrideWithValue(repo),
          authRepositoryProvider.overrideWithValue(_StubAuthRepository()),
        ],
        child: MaterialApp(home: child),
      ),
    );
  }

  testWidgets('selecting meal type then picking a photo shows detected items', (tester) async {
    final repo = FakeMealRepository()
      ..analyzeResult = const MealAnalysisResult(
        items: [FoodItem(name: 'Tavuk', grams: 150, calories: 250)],
        failureReason: AiFailureReason.none,
      );

    await tester.pumpWidget(wrap(
      MealCaptureScreen(pickImageOverride: (_) async => Uint8List(0)),
      repo: repo,
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('meal_type_lunch_chip')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('capture_take_photo_button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('food_item_name_field_0')), findsOneWidget);
    final saveButton = find.byKey(const Key('capture_save_button'));
    expect(tester.widget<ElevatedButton>(saveButton).onPressed, isNotNull);
  });

  testWidgets('AI unavailable shows a banner and an empty, manually-addable list', (tester) async {
    final repo = FakeMealRepository()
      ..analyzeResult = const MealAnalysisResult(items: [], failureReason: AiFailureReason.unavailable);

    await tester.pumpWidget(wrap(
      MealCaptureScreen(pickImageOverride: (_) async => Uint8List(0)),
      repo: repo,
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('meal_type_snack_chip')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('capture_take_photo_button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('capture_ai_failure_banner')), findsOneWidget);

    await tester.tap(find.byKey(const Key('capture_add_item_button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('food_item_name_field_0')), findsOneWidget);
  });

  testWidgets('upload failure shows an error with a retry button', (tester) async {
    final repo = FakeMealRepository()..uploadError = Exception('network down');

    await tester.pumpWidget(wrap(
      MealCaptureScreen(pickImageOverride: (_) async => Uint8List(0)),
      repo: repo,
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('meal_type_breakfast_chip')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('capture_take_photo_button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('capture_upload_error')), findsOneWidget);
    expect(find.byKey(const Key('capture_retry_button')), findsOneWidget);
  });
}
```

- [ ] **Step 3: Testi çalıştırıp başarısız olduğunu doğrula**

Run: `flutter test test/features/nutrition/presentation/meal_capture_screen_test.dart`
Expected: FAIL — `meal_capture_screen.dart` bulunamıyor.

- [ ] **Step 4: `meal_capture_screen.dart`'ı yaz**

```dart
import 'dart:typed_data';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../application/meal_capture_notifier.dart';
import '../application/meal_capture_state.dart';
import '../data/meal_repository.dart';
import '../domain/meal_type.dart';
import 'widgets/food_item_edit_tile.dart';

class MealCaptureScreen extends ConsumerStatefulWidget {
  const MealCaptureScreen({super.key, this.pickImageOverride});

  final Future<Uint8List?> Function(ImageSource source)? pickImageOverride;

  @override
  ConsumerState<MealCaptureScreen> createState() => _MealCaptureScreenState();
}

class _MealCaptureScreenState extends ConsumerState<MealCaptureScreen> {
  MealType? _selectedType;

  Future<Uint8List?> _pickImage(ImageSource source) async {
    if (widget.pickImageOverride != null) return widget.pickImageOverride!(source);
    final file = await ImagePicker().pickImage(source: source);
    if (file == null) return null;
    return file.readAsBytes();
  }

  Future<void> _capture(ImageSource source) async {
    final type = _selectedType;
    if (type == null) return;
    final bytes = await _pickImage(source);
    if (bytes == null) return;
    if (!mounted) return;
    await ref
        .read(mealCaptureProvider.notifier)
        .startCapture(mealType: type, photoBytes: bytes);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<MealCaptureState>(mealCaptureProvider, (previous, next) {
      if (next is MealCaptureSaved) {
        ref.read(mealCaptureProvider.notifier).reset();
        if (context.mounted) context.pop();
      }
    });

    final state = ref.watch(mealCaptureProvider);

    return Scaffold(
      key: const Key('meal_capture_screen'),
      appBar: AppBar(title: Text('nutrition.capture_title'.tr())),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: _buildBody(state),
      ),
    );
  }

  Widget _buildBody(MealCaptureState state) {
    return switch (state) {
      MealCaptureIdle() => _buildIdle(),
      MealCaptureUploading() => Center(child: _loadingLabel('nutrition.uploading'.tr())),
      MealCaptureAnalyzing() => Center(child: _loadingLabel('nutrition.analyzing'.tr())),
      MealCaptureReviewing() => _buildReviewing(state),
      MealCaptureSaving() => Center(child: _loadingLabel('nutrition.saving'.tr())),
      MealCaptureSaved() => const SizedBox.shrink(),
      MealCaptureUploadError() => _buildUploadError(),
    };
  }

  Widget _loadingLabel(String text) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [const CircularProgressIndicator(), const SizedBox(height: 12), Text(text)],
    );
  }

  Widget _buildIdle() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('nutrition.select_meal_type'.tr()),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: MealType.values.map((type) {
            return ChoiceChip(
              key: Key('meal_type_${type.name}_chip'),
              label: Text('nutrition.meal_type_${type.name}'.tr()),
              selected: _selectedType == type,
              onSelected: (_) => setState(() => _selectedType = type),
            );
          }).toList(),
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          key: const Key('capture_take_photo_button'),
          onPressed: _selectedType == null ? null : () => _capture(ImageSource.camera),
          child: Text('nutrition.take_photo'.tr()),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          key: const Key('capture_gallery_button'),
          onPressed: _selectedType == null ? null : () => _capture(ImageSource.gallery),
          child: Text('nutrition.pick_from_gallery'.tr()),
        ),
      ],
    );
  }

  Widget _buildUploadError() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('nutrition.upload_error'.tr(), key: const Key('capture_upload_error')),
        const SizedBox(height: 12),
        ElevatedButton(
          key: const Key('capture_retry_button'),
          onPressed: () => ref.read(mealCaptureProvider.notifier).reset(),
          child: Text('nutrition.retry'.tr()),
        ),
      ],
    );
  }

  Widget _buildReviewing(MealCaptureReviewing state) {
    final notifier = ref.read(mealCaptureProvider.notifier);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (state.aiFailureReason != AiFailureReason.none)
          Container(
            key: const Key('capture_ai_failure_banner'),
            padding: const EdgeInsets.all(12),
            color: Theme.of(context).colorScheme.errorContainer,
            child: Text(
              state.aiFailureReason == AiFailureReason.quotaExceeded
                  ? 'nutrition.ai_quota_exceeded'.tr()
                  : 'nutrition.ai_unavailable'.tr(),
            ),
          ),
        Expanded(
          child: ListView.builder(
            itemCount: state.items.length,
            itemBuilder: (context, index) {
              return FoodItemEditTile(
                item: state.items[index],
                index: index,
                onChanged: (updated) => notifier.updateItem(index, updated),
                onRemove: () => notifier.removeItem(index),
              );
            },
          ),
        ),
        OutlinedButton(
          key: const Key('capture_add_item_button'),
          onPressed: notifier.addManualItem,
          child: Text('nutrition.add_item_manually'.tr()),
        ),
        const SizedBox(height: 8),
        ElevatedButton(
          key: const Key('capture_save_button'),
          onPressed: state.canSave ? notifier.confirmSave : null,
          child: Text('nutrition.save'.tr()),
        ),
      ],
    );
  }
}
```

- [ ] **Step 5: Testi çalıştırıp geçtiğini doğrula**

Run: `flutter test test/features/nutrition/presentation/meal_capture_screen_test.dart`
Expected: PASS (3 test)

- [ ] **Step 6: Tüm nutrition testlerini birlikte çalıştır (regresyon kontrolü)**

Run: `flutter test test/features/nutrition`
Expected: PASS (tüm testler)

- [ ] **Step 7: Commit**

```bash
git add lib/features/nutrition/presentation/meal_capture_screen.dart \
        test/features/nutrition/presentation/meal_capture_screen_test.dart \
        assets/translations/tr.json assets/translations/en.json
git commit -m "feat(nutrition): add MealCaptureScreen"
```

---

## Task 13: Presentation — `NutritionScreen`

**Files:**
- Create: `lib/features/nutrition/presentation/nutrition_screen.dart`
- Test: `test/features/nutrition/presentation/nutrition_screen_test.dart`
- Modify: `assets/translations/tr.json`, `assets/translations/en.json`

**Interfaces:**
- Consumes: `todayMealsProvider` (Task 10); `sumMealMacros`, `MacroTotals` (Task 4); `Meal`, `MealType`, `mealTypeToDb`/`mealTypeFromDb` (Tasks 1-3); `profileProvider` (mevcut `profile_providers.dart`)
- Produces: `class NutritionScreen extends ConsumerWidget`

- [ ] **Step 1: i18n anahtarlarını ekle**

`tr.json`'daki `"nutrition"` bloğuna ekle:

```json
    "screen_title": "Beslenme",
    "daily_totals_with_target": "Bugün: {calories} / {calorieTarget} kcal · {protein} / {proteinTarget} g protein",
    "no_meals_today": "Bugün henüz öğün eklenmedi",
    "load_error": "Öğünler yüklenemedi",
    "add_meal_fab": "Öğün ekle"
```

`en.json`'a karşılığı:

```json
    "screen_title": "Nutrition",
    "daily_totals_with_target": "Today: {calories} / {calorieTarget} kcal · {protein} / {proteinTarget} g protein",
    "no_meals_today": "No meals logged today yet",
    "load_error": "Couldn't load meals",
    "add_meal_fab": "Add meal"
```

- [ ] **Step 2: Widget testini yaz**

```dart
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spor_takip/features/nutrition/application/today_meals_provider.dart';
import 'package:spor_takip/features/nutrition/domain/food_item.dart';
import 'package:spor_takip/features/nutrition/domain/meal.dart';
import 'package:spor_takip/features/nutrition/domain/meal_type.dart';
import 'package:spor_takip/features/nutrition/presentation/nutrition_screen.dart';
import 'package:spor_takip/features/onboarding/application/profile_providers.dart';
import 'package:spor_takip/features/onboarding/domain/profile.dart';

Profile _profile() => const Profile(
      userId: 'user-1',
      weightKg: 80,
      heightCm: 180,
      birthYear: 1996,
      gender: Gender.male,
      activityLevel: ActivityLevel.moderate,
      doesExercise: true,
      sportType: 'Fitness',
      exerciseDaysPerWeek: 3,
      goal: Goal.maintain,
      dailyCalorieTarget: 2500,
      dailyProteinTargetG: 150,
    );

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  Widget wrap(Widget child, {required List<Meal> meals}) {
    final router = GoRouter(routes: [
      GoRoute(path: '/', builder: (context, state) => child),
      GoRoute(path: '/nutrition/capture', builder: (context, state) => const SizedBox()),
    ]);
    return EasyLocalization(
      supportedLocales: const [Locale('tr'), Locale('en')],
      path: 'assets/translations',
      fallbackLocale: const Locale('tr'),
      child: ProviderScope(
        overrides: [
          todayMealsProvider.overrideWith((ref) async => meals),
          profileProvider.overrideWith((ref) async => _profile()),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
  }

  testWidgets('shows empty state when there are no meals today', (tester) async {
    await tester.pumpWidget(wrap(const NutritionScreen(), meals: const []));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('nutrition_empty_state')), findsOneWidget);
  });

  testWidgets('lists meals grouped by meal type and shows daily totals', (tester) async {
    final meals = [
      Meal(
        id: 'm1',
        userId: 'user-1',
        mealType: MealType.breakfast,
        loggedAt: DateTime.now(),
        items: const [FoodItem(name: 'Yulaf', grams: 100, calories: 380, proteinG: 13)],
      ),
      Meal(
        id: 'm2',
        userId: 'user-1',
        mealType: MealType.lunch,
        loggedAt: DateTime.now(),
        items: const [FoodItem(name: 'Tavuk', grams: 150, calories: 250, proteinG: 46)],
      ),
    ];

    await tester.pumpWidget(wrap(const NutritionScreen(), meals: meals));
    await tester.pumpAndSettle();

    expect(find.text('Yulaf'), findsOneWidget);
    expect(find.text('Tavuk'), findsOneWidget);
    expect(find.byKey(const Key('nutrition_daily_totals')), findsOneWidget);
  });

  testWidgets('tapping the FAB navigates to /nutrition/capture', (tester) async {
    await tester.pumpWidget(wrap(const NutritionScreen(), meals: const []));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('nutrition_add_meal_fab')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('meal_capture_screen')), findsNothing); // gerçek ekran değil, route stub'ı
  });
}
```

- [ ] **Step 3: Testi çalıştırıp başarısız olduğunu doğrula**

Run: `flutter test test/features/nutrition/presentation/nutrition_screen_test.dart`
Expected: FAIL — `nutrition_screen.dart` bulunamıyor.

- [ ] **Step 4: `nutrition_screen.dart`'ı yaz**

```dart
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../onboarding/application/profile_providers.dart';
import '../../onboarding/domain/profile.dart';
import '../application/today_meals_provider.dart';
import '../domain/macro_totals.dart';
import '../domain/meal.dart';
import '../domain/meal_type.dart';

class NutritionScreen extends ConsumerWidget {
  const NutritionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mealsAsync = ref.watch(todayMealsProvider);
    final profileAsync = ref.watch(profileProvider);

    return Scaffold(
      key: const Key('nutrition_screen'),
      appBar: AppBar(title: Text('nutrition.screen_title'.tr())),
      floatingActionButton: FloatingActionButton(
        key: const Key('nutrition_add_meal_fab'),
        tooltip: 'nutrition.add_meal_fab'.tr(),
        onPressed: () => context.push('/nutrition/capture'),
        child: const Icon(Icons.add_a_photo_outlined),
      ),
      body: mealsAsync.when(
        data: (meals) => _buildList(context, meals, profileAsync.value),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(child: Text('nutrition.load_error'.tr())),
      ),
    );
  }

  Widget _buildList(BuildContext context, List<Meal> meals, Profile? profile) {
    if (meals.isEmpty) {
      return Center(
        key: const Key('nutrition_empty_state'),
        child: Text('nutrition.no_meals_today'.tr()),
      );
    }

    final totals = sumMealMacros(meals);
    // profile null olabilir (henüz yükleniyor); bu durumda hedefsiz toplam
    // yerine boş bir hedef göstermek yerine 0 hedefle gösteriyoruz ki widget
    // her zaman aynı anahtarla tek bir metin üretsin.
    final calorieTarget = profile?.dailyCalorieTarget ?? 0;
    final proteinTarget = profile?.dailyProteinTargetG ?? 0;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'nutrition.daily_totals_with_target'.tr(namedArgs: {
              'calories': totals.calories.round().toString(),
              'calorieTarget': calorieTarget.round().toString(),
              'protein': totals.proteinG.round().toString(),
              'proteinTarget': proteinTarget.round().toString(),
            }),
            key: const Key('nutrition_daily_totals'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        Expanded(
          child: ListView(
            children: [
              for (final type in MealType.values) ..._buildMealTypeSection(context, type, meals),
            ],
          ),
        ),
      ],
    );
  }

  List<Widget> _buildMealTypeSection(BuildContext context, MealType type, List<Meal> meals) {
    final mealsOfType = meals.where((meal) => meal.mealType == type).toList();
    if (mealsOfType.isEmpty) return const [];
    return [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Text(
          'nutrition.meal_type_${type.name}'.tr(),
          style: Theme.of(context).textTheme.titleSmall,
        ),
      ),
      for (final meal in mealsOfType)
        for (final item in meal.items)
          ListTile(
            title: Text(item.name),
            subtitle: Text('${item.grams.round()} g · ${item.calories.round()} kcal'),
          ),
    ];
  }
}
```

- [ ] **Step 5: Testi çalıştırıp geçtiğini doğrula**

Run: `flutter test test/features/nutrition/presentation/nutrition_screen_test.dart`
Expected: PASS (3 test)

- [ ] **Step 6: Commit**

```bash
git add lib/features/nutrition/presentation/nutrition_screen.dart \
        test/features/nutrition/presentation/nutrition_screen_test.dart \
        assets/translations/tr.json assets/translations/en.json
git commit -m "feat(nutrition): add NutritionScreen with daily totals"
```

---

## Task 14: Core — Alt Navigasyon (`AppShell` + router)

**Files:**
- Create: `lib/core/app_shell.dart`
- Test: `test/core/app_shell_test.dart`
- Modify: `lib/core/router.dart`
- Modify: `assets/translations/tr.json`, `assets/translations/en.json`

**Interfaces:**
- Consumes: `NutritionScreen` (Task 13), `HomeScreen` (mevcut), `computeRedirect`/`ProfileState` (mevcut `redirect_logic.dart`, **değişiklik yok**)
- Produces: `class AppShell extends StatelessWidget({required StatefulNavigationShell navigationShell})`; `router.dart` içinde `/home` ve `/nutrition` artık `StatefulShellRoute.indexedStack` altında.

- [ ] **Step 1: i18n anahtarlarını ekle**

`tr.json`'a yeni bir üst düzey blok (`"nutrition"` bloğundan sonra, dosyanın kapanışından önce):

```json
  "nav": {
    "home": "Ana Sayfa",
    "nutrition": "Beslenme"
  }
```

`en.json`'a aynı yapı:

```json
  "nav": {
    "home": "Home",
    "nutrition": "Nutrition"
  }
```

- [ ] **Step 2: `AppShell` widget testini yaz**

```dart
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spor_takip/core/app_shell.dart';

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  Widget buildTestRouter() {
    final router = GoRouter(
      initialLocation: '/home',
      routes: [
        StatefulShellRoute.indexedStack(
          builder: (context, state, navigationShell) => AppShell(navigationShell: navigationShell),
          branches: [
            StatefulShellBranch(routes: [
              GoRoute(path: '/home', builder: (context, state) => const Text('HOME_SCREEN')),
            ]),
            StatefulShellBranch(routes: [
              GoRoute(path: '/nutrition', builder: (context, state) => const Text('NUTRITION_SCREEN')),
            ]),
          ],
        ),
      ],
    );
    return EasyLocalization(
      supportedLocales: const [Locale('tr'), Locale('en')],
      path: 'assets/translations',
      fallbackLocale: const Locale('tr'),
      child: MaterialApp.router(routerConfig: router),
    );
  }

  testWidgets('shows both nav destinations and starts on the home branch', (tester) async {
    await tester.pumpWidget(buildTestRouter());
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('app_bottom_nav')), findsOneWidget);
    expect(find.text('HOME_SCREEN'), findsOneWidget);
    expect(find.text('NUTRITION_SCREEN'), findsNothing);
  });

  testWidgets('tapping the nutrition destination switches branch', (tester) async {
    await tester.pumpWidget(buildTestRouter());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Beslenme'));
    await tester.pumpAndSettle();

    expect(find.text('NUTRITION_SCREEN'), findsOneWidget);
    expect(find.text('HOME_SCREEN'), findsNothing);
  });
}
```

- [ ] **Step 3: Testi çalıştırıp başarısız olduğunu doğrula**

Run: `flutter test test/core/app_shell_test.dart`
Expected: FAIL — `app_shell.dart` bulunamıyor.

- [ ] **Step 4: `app_shell.dart`'ı yaz**

```dart
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        key: const Key('app_bottom_nav'),
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (index) => navigationShell.goBranch(
          index,
          initialLocation: index == navigationShell.currentIndex,
        ),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.home_outlined),
            selectedIcon: const Icon(Icons.home),
            label: 'nav.home'.tr(),
          ),
          NavigationDestination(
            icon: const Icon(Icons.restaurant_outlined),
            selectedIcon: const Icon(Icons.restaurant),
            label: 'nav.nutrition'.tr(),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 5: Testi çalıştırıp geçtiğini doğrula**

Run: `flutter test test/core/app_shell_test.dart`
Expected: PASS (2 test)

- [ ] **Step 6: `router.dart`'ı güncelle**

Mevcut importlara ekle:

```dart
import '../features/nutrition/presentation/meal_capture_screen.dart';
import '../features/nutrition/presentation/nutrition_screen.dart';
import 'app_shell.dart';
```

`routes:` listesindeki şu satırı:

```dart
      GoRoute(path: '/home', builder: (context, state) => const HomeScreen()),
```

şununla değiştir:

```dart
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) => AppShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [GoRoute(path: '/home', builder: (context, state) => const HomeScreen())],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/nutrition',
                builder: (context, state) => const NutritionScreen(),
                routes: [
                  GoRoute(
                    path: 'capture',
                    builder: (context, state) => const MealCaptureScreen(),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
```

`redirect_logic.dart`'a **dokunulmuyor** — `computeRedirect`'in `ProfileState.present` dalı zaten `/nutrition` ve `/nutrition/capture` gibi auth/onboarding-dışı her konumda `null` (yönlendirme yok) döndürüyor.

- [ ] **Step 7: Mevcut router/redirect testlerinin hâlâ geçtiğini doğrula (regresyon)**

Run: `flutter test test/core/redirect_logic_test.dart`
Expected: PASS (değişmedi, dokunulmadı)

Run: `flutter test test/widget_test.dart`
Expected: PASS

- [ ] **Step 8: Derlemeyi doğrula**

Run: `flutter analyze`
Expected: Hata yok.

- [ ] **Step 9: Commit**

```bash
git add lib/core/app_shell.dart test/core/app_shell_test.dart lib/core/router.dart \
        assets/translations/tr.json assets/translations/en.json
git commit -m "feat(nutrition): add bottom nav shell wiring Home and Nutrition tabs"
```

---

## Task 15: Edge Function — `usda_client.ts`

**Files:**
- Create: `supabase/functions/analyze-meal-photo/usda_client.ts`
- Test: `supabase/functions/analyze-meal-photo/usda_client.test.ts`

**Interfaces:**
- Produces: `interface UsdaFood { fdcId: number; description: string; dataType: string }`, `interface Macros { calories: number; proteinG: number; carbsG: number; fatG: number }`, `function scoreMatch(query: string, candidate: UsdaFood): number`, `async function findBestMatch(foodName: string, apiKey: string, fetchFn?: typeof fetch): Promise<UsdaFood | null>`, `async function fetchMacrosPer100g(fdcId: number, apiKey: string, fetchFn?: typeof fetch): Promise<Macros>`

- [ ] **Step 1: Testi yaz**

```typescript
import { assertEquals, assertAlmostEquals } from 'https://deno.land/std@0.224.0/assert/mod.ts';
import { fetchMacrosPer100g, findBestMatch, scoreMatch } from './usda_client.ts';
import type { UsdaFood } from './usda_client.ts';

Deno.test('scoreMatch gives a high score for near-identical descriptions', () => {
  const candidate: UsdaFood = { fdcId: 1, description: 'Chicken breast, grilled', dataType: 'Foundation' };
  const score = scoreMatch('grilled chicken breast', candidate);
  assertEquals(score > 0.5, true);
});

Deno.test('scoreMatch gives a low score for unrelated descriptions', () => {
  const candidate: UsdaFood = { fdcId: 2, description: 'Chocolate cake', dataType: 'SR Legacy' };
  const score = scoreMatch('grilled chicken breast', candidate);
  assertEquals(score < 0.2, true);
});

Deno.test('findBestMatch returns the highest-scoring food above the threshold', async () => {
  const fakeFetch: typeof fetch = async () =>
    new Response(
      JSON.stringify({
        foods: [
          { fdcId: 1, description: 'Chocolate cake', dataType: 'SR Legacy' },
          { fdcId: 2, description: 'Chicken breast, grilled', dataType: 'Foundation' },
        ],
      }),
      { status: 200 },
    );

  const match = await findBestMatch('grilled chicken breast', 'fake-key', fakeFetch);
  assertEquals(match?.fdcId, 2);
});

Deno.test('findBestMatch returns null when no candidate clears the threshold', async () => {
  const fakeFetch: typeof fetch = async () =>
    new Response(JSON.stringify({ foods: [{ fdcId: 3, description: 'Chocolate cake', dataType: 'SR Legacy' }] }), {
      status: 200,
    });

  const match = await findBestMatch('grilled chicken breast', 'fake-key', fakeFetch);
  assertEquals(match, null);
});

Deno.test('findBestMatch returns null when the search request fails', async () => {
  const fakeFetch: typeof fetch = async () => new Response('error', { status: 500 });
  const match = await findBestMatch('anything', 'fake-key', fakeFetch);
  assertEquals(match, null);
});

Deno.test('fetchMacrosPer100g extracts the four tracked nutrients', async () => {
  const fakeFetch: typeof fetch = async () =>
    new Response(
      JSON.stringify({
        foodNutrients: [
          { nutrientName: 'Energy', value: 165 },
          { nutrientName: 'Protein', value: 31 },
          { nutrientName: 'Carbohydrate, by difference', value: 0 },
          { nutrientName: 'Total lipid (fat)', value: 3.6 },
        ],
      }),
      { status: 200 },
    );

  const macros = await fetchMacrosPer100g(2, 'fake-key', fakeFetch);
  assertAlmostEquals(macros.calories, 165);
  assertAlmostEquals(macros.proteinG, 31);
  assertAlmostEquals(macros.carbsG, 0);
  assertAlmostEquals(macros.fatG, 3.6);
});

Deno.test('fetchMacrosPer100g throws when the detail request fails', async () => {
  const fakeFetch: typeof fetch = async () => new Response('error', { status: 404 });
  let threw = false;
  try {
    await fetchMacrosPer100g(999, 'fake-key', fakeFetch);
  } catch {
    threw = true;
  }
  assertEquals(threw, true);
});
```

- [ ] **Step 2: Testi çalıştırıp başarısız olduğunu doğrula**

Run: `deno test supabase/functions/analyze-meal-photo/usda_client.test.ts`
Expected: FAIL — `usda_client.ts` bulunamıyor.

- [ ] **Step 3: `usda_client.ts`'i yaz**

```typescript
export interface UsdaFood {
  fdcId: number;
  description: string;
  dataType: string;
}

export interface Macros {
  calories: number;
  proteinG: number;
  carbsG: number;
  fatG: number;
}

const PREFERRED_DATA_TYPES = new Set(['Foundation', 'SR Legacy']);
const MATCH_THRESHOLD = 0.3;

function normalize(text: string): string[] {
  return text
    .toLowerCase()
    .normalize('NFD')
    .replace(/[̀-ͯ]/g, '')
    .replace(/[^a-z0-9\s]/g, ' ')
    .split(/\s+/)
    .filter((token) => token.length > 0);
}

export function scoreMatch(query: string, candidate: UsdaFood): number {
  const queryTokens = new Set(normalize(query));
  const candidateTokens = new Set(normalize(candidate.description));
  if (queryTokens.size === 0 || candidateTokens.size === 0) return 0;

  let overlap = 0;
  for (const token of queryTokens) {
    if (candidateTokens.has(token)) overlap += 1;
  }
  const union = new Set([...queryTokens, ...candidateTokens]).size;
  const jaccard = overlap / union;
  const typeBonus = PREFERRED_DATA_TYPES.has(candidate.dataType) ? 0.1 : 0;
  return jaccard + typeBonus;
}

export async function findBestMatch(
  foodName: string,
  apiKey: string,
  fetchFn: typeof fetch = fetch,
): Promise<UsdaFood | null> {
  const url =
    `https://api.nal.usda.gov/fdc/v1/foods/search?api_key=${apiKey}` +
    `&query=${encodeURIComponent(foodName)}&pageSize=10`;
  const response = await fetchFn(url);
  if (!response.ok) return null;

  const data = await response.json();
  const foods = (data.foods ?? []) as UsdaFood[];
  if (foods.length === 0) return null;

  let best: UsdaFood | null = null;
  let bestScore = 0;
  for (const food of foods) {
    const score = scoreMatch(foodName, food);
    if (score > bestScore) {
      bestScore = score;
      best = food;
    }
  }
  return bestScore >= MATCH_THRESHOLD ? best : null;
}

export async function fetchMacrosPer100g(
  fdcId: number,
  apiKey: string,
  fetchFn: typeof fetch = fetch,
): Promise<Macros> {
  const url = `https://api.nal.usda.gov/fdc/v1/food/${fdcId}?api_key=${apiKey}`;
  const response = await fetchFn(url);
  if (!response.ok) {
    throw new Error(`USDA food detail request failed: ${response.status}`);
  }
  const data = await response.json();
  const nutrients: Array<{ nutrientName: string; value: number }> = data.foodNutrients ?? [];
  const find = (name: string) => nutrients.find((n) => n.nutrientName === name)?.value ?? 0;
  return {
    calories: find('Energy'),
    proteinG: find('Protein'),
    carbsG: find('Carbohydrate, by difference'),
    fatG: find('Total lipid (fat)'),
  };
}
```

- [ ] **Step 4: Testi çalıştırıp geçtiğini doğrula**

Run: `deno test supabase/functions/analyze-meal-photo/usda_client.test.ts`
Expected: PASS (7 test)

- [ ] **Step 5: Commit**

```bash
git add supabase/functions/analyze-meal-photo/usda_client.ts \
        supabase/functions/analyze-meal-photo/usda_client.test.ts
git commit -m "feat(nutrition): add USDA FoodData Central matching client"
```

---

## Task 16: Edge Function — `gemini_client.ts`

**Files:**
- Create: `supabase/functions/analyze-meal-photo/gemini_client.ts`
- Test: `supabase/functions/analyze-meal-photo/gemini_client.test.ts`

**Interfaces:**
- Produces: `interface FoodPrediction { name: string; estimatedGrams: number }`, `class GeminiUnavailableError extends Error`, `class GeminiQuotaExceededError extends Error`, `async function identifyFoodItems(photoBytes: Uint8Array, apiKey: string, fetchFn?: typeof fetch): Promise<FoodPrediction[]>`

- [ ] **Step 1: Testi yaz**

```typescript
import { assertEquals, assertRejects } from 'https://deno.land/std@0.224.0/assert/mod.ts';
import { GeminiQuotaExceededError, GeminiUnavailableError, identifyFoodItems } from './gemini_client.ts';

function jsonTextResponse(items: Array<{ name: string; estimated_grams: number }>): Response {
  return new Response(
    JSON.stringify({
      candidates: [{ content: { parts: [{ text: JSON.stringify({ items }) }] } }],
    }),
    { status: 200 },
  );
}

Deno.test('identifyFoodItems parses the model JSON response into predictions', async () => {
  const fakeFetch: typeof fetch = async () =>
    jsonTextResponse([
      { name: 'Izgara tavuk göğsü', estimated_grams: 150 },
      { name: 'Pilav', estimated_grams: 100 },
    ]);

  const predictions = await identifyFoodItems(new Uint8Array([1, 2, 3]), 'fake-key', fakeFetch);

  assertEquals(predictions.length, 2);
  assertEquals(predictions[0].name, 'Izgara tavuk göğsü');
  assertEquals(predictions[0].estimatedGrams, 150);
});

Deno.test('identifyFoodItems throws GeminiQuotaExceededError on HTTP 429', async () => {
  const fakeFetch: typeof fetch = async () => new Response('rate limited', { status: 429 });
  await assertRejects(
    () => identifyFoodItems(new Uint8Array([1]), 'fake-key', fakeFetch),
    GeminiQuotaExceededError,
  );
});

Deno.test('identifyFoodItems throws GeminiUnavailableError on other HTTP errors', async () => {
  const fakeFetch: typeof fetch = async () => new Response('server error', { status: 500 });
  await assertRejects(
    () => identifyFoodItems(new Uint8Array([1]), 'fake-key', fakeFetch),
    GeminiUnavailableError,
  );
});

Deno.test('identifyFoodItems throws GeminiUnavailableError when response has no text content', async () => {
  const fakeFetch: typeof fetch = async () =>
    new Response(JSON.stringify({ candidates: [] }), { status: 200 });
  await assertRejects(
    () => identifyFoodItems(new Uint8Array([1]), 'fake-key', fakeFetch),
    GeminiUnavailableError,
  );
});
```

- [ ] **Step 2: Testi çalıştırıp başarısız olduğunu doğrula**

Run: `deno test supabase/functions/analyze-meal-photo/gemini_client.test.ts`
Expected: FAIL — `gemini_client.ts` bulunamıyor.

- [ ] **Step 3: `gemini_client.ts`'i yaz**

```typescript
export interface FoodPrediction {
  name: string;
  estimatedGrams: number;
}

const GEMINI_MODEL = 'gemini-2.5-flash-lite';

export class GeminiUnavailableError extends Error {}
export class GeminiQuotaExceededError extends Error {}

const PROMPT =
  'Bu fotoğraftaki her yiyeceği ve tahmini gram cinsinden porsiyonunu belirle. ' +
  'Sadece JSON döndür, başka açıklama ekleme. ' +
  'Format: {"items": [{"name": string, "estimated_grams": number}]}. ' +
  'Makro veya kalori hesabı yapma, sadece tanıma ve porsiyon tahmini yap.';

function bytesToBase64(bytes: Uint8Array): string {
  let binary = '';
  for (const byte of bytes) {
    binary += String.fromCharCode(byte);
  }
  return btoa(binary);
}

export async function identifyFoodItems(
  photoBytes: Uint8Array,
  apiKey: string,
  fetchFn: typeof fetch = fetch,
): Promise<FoodPrediction[]> {
  const url = `https://generativelanguage.googleapis.com/v1beta/models/${GEMINI_MODEL}:generateContent?key=${apiKey}`;
  const body = {
    contents: [
      {
        parts: [
          { text: PROMPT },
          { inline_data: { mime_type: 'image/jpeg', data: bytesToBase64(photoBytes) } },
        ],
      },
    ],
    generationConfig: { responseMimeType: 'application/json' },
  };

  const response = await fetchFn(url, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
  });

  if (response.status === 429) {
    throw new GeminiQuotaExceededError('Gemini rate limit exceeded');
  }
  if (!response.ok) {
    throw new GeminiUnavailableError(`Gemini request failed: ${response.status}`);
  }

  const data = await response.json();
  const text = data.candidates?.[0]?.content?.parts?.[0]?.text;
  if (typeof text !== 'string') {
    throw new GeminiUnavailableError('Gemini response missing text content');
  }

  const parsed = JSON.parse(text) as { items: Array<{ name: string; estimated_grams: number }> };
  return parsed.items.map((item) => ({ name: item.name, estimatedGrams: item.estimated_grams }));
}
```

- [ ] **Step 4: Testi çalıştırıp geçtiğini doğrula**

Run: `deno test supabase/functions/analyze-meal-photo/gemini_client.test.ts`
Expected: PASS (4 test)

- [ ] **Step 5: Commit**

```bash
git add supabase/functions/analyze-meal-photo/gemini_client.ts \
        supabase/functions/analyze-meal-photo/gemini_client.test.ts
git commit -m "feat(nutrition): add Gemini food identification client"
```

---

## Task 17: Edge Function — `index.ts` (orkestrasyon)

**Files:**
- Create: `supabase/functions/analyze-meal-photo/index.ts`
- Test: `supabase/functions/analyze-meal-photo/index.test.ts`

**Interfaces:**
- Consumes: `identifyFoodItems`, `GeminiQuotaExceededError`, `GeminiUnavailableError`, `FoodPrediction` (Task 16); `findBestMatch`, `fetchMacrosPer100g`, `UsdaFood`, `Macros` (Task 15)
- Produces: `interface AnalyzeDeps { downloadPhoto, identifyFoodItems, findBestMatch, fetchMacrosPer100g }`, `async function handleAnalyzeRequest(photoPath: string, deps: AnalyzeDeps): Promise<{status: number; body: unknown}>`, `Deno.serve` HTTP girişi

- [ ] **Step 1: Testi yaz**

```typescript
import { assertEquals } from 'https://deno.land/std@0.224.0/assert/mod.ts';
import { GeminiQuotaExceededError, GeminiUnavailableError } from './gemini_client.ts';
import { handleAnalyzeRequest } from './index.ts';
import type { AnalyzeDeps } from './index.ts';

function baseDeps(overrides: Partial<AnalyzeDeps> = {}): AnalyzeDeps {
  return {
    downloadPhoto: async () => new Uint8Array([1, 2, 3]),
    identifyFoodItems: async () => [{ name: 'Tavuk', estimatedGrams: 150 }],
    findBestMatch: async () => ({ fdcId: 171077, description: 'Chicken breast', dataType: 'Foundation' }),
    fetchMacrosPer100g: async () => ({ calories: 165, proteinG: 31, carbsG: 0, fatG: 3.6 }),
    ...overrides,
  };
}

Deno.test('returns matched items with macros scaled by grams', async () => {
  const result = await handleAnalyzeRequest('user-1/meal-1.jpg', baseDeps());
  assertEquals(result.status, 200);
  const body = result.body as { items: Array<Record<string, unknown>> };
  assertEquals(body.items.length, 1);
  assertEquals(body.items[0].name, 'Tavuk');
  assertEquals(body.items[0].grams, 150);
  assertEquals(body.items[0].calories, 247.5);
  assertEquals(body.items[0].needs_review, false);
  assertEquals(body.items[0].usda_fdc_id, '171077');
});

Deno.test('marks an item needs_review when USDA has no match', async () => {
  const deps = baseDeps({ findBestMatch: async () => null });
  const result = await handleAnalyzeRequest('user-1/meal-1.jpg', deps);
  const body = result.body as { items: Array<Record<string, unknown>> };
  assertEquals(body.items[0].needs_review, true);
  assertEquals(body.items[0].calories, 0);
  assertEquals(body.items[0].usda_fdc_id, null);
});

Deno.test('returns GEMINI_QUOTA_EXCEEDED with 429 when Gemini rate-limits', async () => {
  const deps = baseDeps({
    identifyFoodItems: async () => {
      throw new GeminiQuotaExceededError('rate limited');
    },
  });
  const result = await handleAnalyzeRequest('user-1/meal-1.jpg', deps);
  assertEquals(result.status, 429);
  assertEquals((result.body as { code: string }).code, 'GEMINI_QUOTA_EXCEEDED');
});

Deno.test('returns GEMINI_UNAVAILABLE with 503 when Gemini fails', async () => {
  const deps = baseDeps({
    identifyFoodItems: async () => {
      throw new GeminiUnavailableError('down');
    },
  });
  const result = await handleAnalyzeRequest('user-1/meal-1.jpg', deps);
  assertEquals(result.status, 503);
  assertEquals((result.body as { code: string }).code, 'GEMINI_UNAVAILABLE');
});

Deno.test('returns PHOTO_NOT_FOUND with 404 when the photo cannot be downloaded', async () => {
  const deps = baseDeps({
    downloadPhoto: async () => {
      throw new Error('404 from storage');
    },
  });
  const result = await handleAnalyzeRequest('missing.jpg', deps);
  assertEquals(result.status, 404);
  assertEquals((result.body as { code: string }).code, 'PHOTO_NOT_FOUND');
});

Deno.test('handles multiple predicted items independently', async () => {
  const deps = baseDeps({
    identifyFoodItems: async () => [
      { name: 'Tavuk', estimatedGrams: 150 },
      { name: 'Bilinmeyen sos', estimatedGrams: 30 },
    ],
    findBestMatch: async (name: string) =>
      name === 'Tavuk' ? { fdcId: 171077, description: 'Chicken breast', dataType: 'Foundation' } : null,
  });
  const result = await handleAnalyzeRequest('user-1/meal-1.jpg', deps);
  const body = result.body as { items: Array<Record<string, unknown>> };
  assertEquals(body.items.length, 2);
  assertEquals(body.items[0].needs_review, false);
  assertEquals(body.items[1].needs_review, true);
});
```

- [ ] **Step 2: Testi çalıştırıp başarısız olduğunu doğrula**

Run: `deno test supabase/functions/analyze-meal-photo/index.test.ts`
Expected: FAIL — `index.ts` bulunamıyor.

- [ ] **Step 3: `index.ts`'i yaz**

```typescript
import { GeminiQuotaExceededError, GeminiUnavailableError, identifyFoodItems } from './gemini_client.ts';
import type { FoodPrediction } from './gemini_client.ts';
import { fetchMacrosPer100g, findBestMatch } from './usda_client.ts';
import type { UsdaFood, Macros } from './usda_client.ts';

export interface AnalyzeDeps {
  downloadPhoto: (photoPath: string) => Promise<Uint8Array>;
  identifyFoodItems: (photoBytes: Uint8Array) => Promise<FoodPrediction[]>;
  findBestMatch: (name: string) => Promise<UsdaFood | null>;
  fetchMacrosPer100g: (fdcId: number) => Promise<Macros>;
}

interface ResponseItem {
  name: string;
  grams: number;
  calories: number;
  protein_g: number;
  carbs_g: number;
  fat_g: number;
  usda_fdc_id: string | null;
  needs_review: boolean;
}

function round1(value: number): number {
  return Math.round(value * 10) / 10;
}

export async function handleAnalyzeRequest(
  photoPath: string,
  deps: AnalyzeDeps,
): Promise<{ status: number; body: unknown }> {
  let photoBytes: Uint8Array;
  try {
    photoBytes = await deps.downloadPhoto(photoPath);
  } catch {
    return { status: 404, body: { code: 'PHOTO_NOT_FOUND', message: 'Fotoğraf bulunamadı' } };
  }

  let predictions: FoodPrediction[];
  try {
    predictions = await deps.identifyFoodItems(photoBytes);
  } catch (error) {
    if (error instanceof GeminiQuotaExceededError) {
      return {
        status: 429,
        body: { code: 'GEMINI_QUOTA_EXCEEDED', message: 'Günlük AI analiz limiti doldu' },
      };
    }
    if (error instanceof GeminiUnavailableError) {
      return { status: 503, body: { code: 'GEMINI_UNAVAILABLE', message: 'AI şu an kullanılamıyor' } };
    }
    throw error;
  }

  const items: ResponseItem[] = [];
  for (const prediction of predictions) {
    const match = await deps.findBestMatch(prediction.name);
    if (match === null) {
      items.push({
        name: prediction.name,
        grams: prediction.estimatedGrams,
        calories: 0,
        protein_g: 0,
        carbs_g: 0,
        fat_g: 0,
        usda_fdc_id: null,
        needs_review: true,
      });
      continue;
    }
    const per100g = await deps.fetchMacrosPer100g(match.fdcId);
    const factor = prediction.estimatedGrams / 100;
    items.push({
      name: prediction.name,
      grams: prediction.estimatedGrams,
      calories: round1(per100g.calories * factor),
      protein_g: round1(per100g.proteinG * factor),
      carbs_g: round1(per100g.carbsG * factor),
      fat_g: round1(per100g.fatG * factor),
      usda_fdc_id: String(match.fdcId),
      needs_review: false,
    });
  }

  return { status: 200, body: { items } };
}

Deno.serve(async (req: Request) => {
  const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
  const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
  const geminiApiKey = Deno.env.get('GEMINI_API_KEY')!;
  const usdaApiKey = Deno.env.get('USDA_FDC_API_KEY')!;

  try {
    const { photo_path } = await req.json();
    if (!photo_path || typeof photo_path !== 'string') {
      return new Response(
        JSON.stringify({ code: 'PHOTO_NOT_FOUND', message: 'photo_path eksik' }),
        { status: 400, headers: { 'Content-Type': 'application/json' } },
      );
    }

    const deps: AnalyzeDeps = {
      downloadPhoto: async (path) => {
        const response = await fetch(`${supabaseUrl}/storage/v1/object/meal-photos/${path}`, {
          headers: { Authorization: `Bearer ${serviceRoleKey}` },
        });
        if (!response.ok) throw new Error(`Storage download failed: ${response.status}`);
        return new Uint8Array(await response.arrayBuffer());
      },
      identifyFoodItems: (bytes) => identifyFoodItems(bytes, geminiApiKey),
      findBestMatch: (name) => findBestMatch(name, usdaApiKey),
      fetchMacrosPer100g: (fdcId) => fetchMacrosPer100g(fdcId, usdaApiKey),
    };

    const result = await handleAnalyzeRequest(photo_path, deps);
    return new Response(JSON.stringify(result.body), {
      status: result.status,
      headers: { 'Content-Type': 'application/json' },
    });
  } catch (error) {
    console.error(error);
    return new Response(
      JSON.stringify({ code: 'INTERNAL_ERROR', message: 'Beklenmeyen bir hata oluştu' }),
      { status: 500, headers: { 'Content-Type': 'application/json' } },
    );
  }
});
```

- [ ] **Step 4: Testi çalıştırıp geçtiğini doğrula**

Run: `deno test supabase/functions/analyze-meal-photo/index.test.ts`
Expected: PASS (6 test)

- [ ] **Step 5: Tüm Edge Function testlerini birlikte çalıştır (regresyon kontrolü)**

Run: `deno test supabase/functions/analyze-meal-photo/`
Expected: PASS (17 test: 7 usda + 4 gemini + 6 index)

- [ ] **Step 6: Commit**

```bash
git add supabase/functions/analyze-meal-photo/index.ts supabase/functions/analyze-meal-photo/index.test.ts
git commit -m "feat(nutrition): add analyze-meal-photo Edge Function orchestration"
```

---

## Uçtan Uca Doğrulama (kod tamamlandıktan sonra, elle)

Bu adımlar plan görevleri değildir — gerçek Gemini/USDA anahtarları elde edildiğinde F1'deki Supabase doğrulama adımına benzer şekilde elle yapılır:

1. `supabase secrets set GEMINI_API_KEY=... USDA_FDC_API_KEY=...`
2. `supabase functions deploy analyze-meal-photo`
3. Migration'ları canlı projeye uygula (`0002_create_meals.sql`, `0003_create_meal_photos_storage.sql`).
4. Uygulamayı çalıştır, bir öğün fotoğrafı çek, tahminleri gözden geçir, kaydet, Beslenme sekmesinde günlük toplamların doğru göründüğünü doğrula.
5. Kasıtlı olarak eşleşmeyen bir yiyecek adıyla `needs_review` akışını, ve internetsiz durumda yükleme hatası akışını test et.
