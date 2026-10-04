# F5+ R2 — Beslenme Ekranı ve Fotoğrafla Öğün Ekleme Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Beslenme ekranını "kalan odaklı" düzene, öğün ekleme ekranını "fotoğraf önde, kompakt" düzene geçirmek. Düzeltme ekranında gram değişince kcal ve makrolar orantılı güncellensin, makro yazarken alanlar kaybolmasın.

**Architecture:** Ölçekleme saf fonksiyonlarla yapılıyor (`food_item_scaling.dart`). Gram başı değerler `MealCaptureReviewing` durumunda, sadece istemcide tutulan bir listede duruyor; notifier gramı `updateItemGrams` ile güncelliyor. Ekranlar R1 tasarım sistemini (`AppTheme.dark()`, `SectionHeader`, `RingProgress` yardımcıları) kullanıyor. Yeni bileşenler: `RemainingCaloriesCard` ve açılır satır olarak yeniden yazılan `FoodItemEditTile`. Veritabanı, edge function ve rotalar değişmiyor.

**Tech Stack:** Flutter (Material 3), flutter_riverpod 3, go_router, easy_localization, image_picker.

**Spec:** `docs/superpowers/specs/2026-10-04-f5plus-r2-beslenme-design.md` (çerçeve: `docs/superpowers/specs/2026-10-03-f5plus-r1-tasarim-temeli-design.md`)

## Global Constraints

- Dal: `r2-beslenme` (master'dan açıldı, spec commit'i `fa5ad34` üstünde).
- Tüm `flutter` komutları `--no-pub` ile çalışır (`pub get` bu makinede takılıyor). **Yeni paket eklenmez.**
- Düşük bellekli makine: görev içinde sadece ilgili test dosyaları çalıştırılır. Tam paketi kullanıcı kendi terminalinde çalıştırır (`flutter test --no-pub -j 1`, Task 6).
- `flutter analyze --no-pub` "No issues found!" vermeli (info dahil). `await`'ten sonra `context` kullanmadan önce `mounted` / `context.mounted` kontrolü yapılır.
- Widget testlerinde `.tr()` çıktısına güvenilmez. Bulma işi `Key`, ikon ya da veri metniyle yapılır. Metin karşılaştırması gerekiyorsa beklenen değer testte de `.tr()` ile üretilir.
- Ekran/bileşen kodunda elle renk (`Color(0x…)`, `Colors.x`) yazılmaz. Renkler `Theme.of(context).colorScheme`'den alınır: vurgu = `primary`, vurgu üstü metin = `onPrimary`, ana metin = `onSurface`, ikincil metin = `onSurfaceVariant`, çizgi/boş çubuk = `outlineVariant`, kutu zemini = `surfaceContainer`, hata/aşım = `error`. Saydamlık için `withValues(alpha: …)`.
- Büyük harfe çevirme sadece `upperCaseFor(text, languageCode)` ile yapılır (`lib/shared/text_case.dart`). Buton metinleri büyük harfe çevrilmez (R1 kararı).
- "Şimdi"ye bağlı kod `nowProvider` kullanır (`lib/features/workout/application/session_providers.dart`).
- Korunan anahtarlar: `nutrition_screen`, `nutrition_add_meal_fab`, `nutrition_empty_state`, `meal_capture_screen`, `meal_type_*_chip`, `capture_take_photo_button`, `capture_gallery_button`, `capture_upload_error`, `capture_retry_button`, `capture_ai_failure_banner`, `capture_add_item_button`, `capture_save_button`, `food_item_{name|grams|calories|protein|carbs|fat}_field_$index`, `food_item_remove_button_$index`, `food_item_needs_review_badge_$index`.
- Commit mesajları İngilizce, `feat(nutrition): …` biçiminde. Sonuna boş satır + `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.

## Spec'ten küçük netleştirmeler (kullanıcıya bildirilecek)

1. Öğün ekleme ekranının sabit alt barı ayrı bir `surface` zemin yerine üstte `outlineVariant` çizgisiyle ayrılıyor. Ekran gövdesi zaten 16 px kenar boşluklu olduğu için, zemin rengi verilirse bar kenarlara kadar uzanmıyor ve kopuk görünüyor.
2. Tarih metni ana sayfayla aynı yerden üretilsin diye `lib/shared/day_label.dart` (`dayLabel`) çıkarılıyor; ana sayfa da bunu kullanacak.
3. `SectionHeader`'a isteğe bağlı `trailing` (sağdaki metin) ekleniyor. Öğün ara toplamı burada gösterilecek.

## Dosya Haritası

```
lib/features/nutrition/domain/food_item_scaling.dart            # Task 1 (yeni)
lib/features/nutrition/application/meal_capture_state.dart      # Task 2
lib/features/nutrition/application/meal_capture_notifier.dart   # Task 2
assets/translations/tr.json, en.json                            # Task 3–5
lib/features/nutrition/presentation/widgets/remaining_calories_card.dart  # Task 3 (yeni)
lib/shared/day_label.dart                                       # Task 4 (yeni)
lib/shared/widgets/section_header.dart                          # Task 4
lib/features/onboarding/presentation/home_screen.dart           # Task 4 (dayLabel kullanımı)
lib/features/nutrition/presentation/nutrition_screen.dart       # Task 4
lib/features/nutrition/presentation/widgets/food_item_edit_tile.dart      # Task 5 (yeniden yazım)
lib/features/nutrition/presentation/meal_capture_screen.dart    # Task 5
PLAN.md                                                         # Task 6

test/features/nutrition/domain/food_item_scaling_test.dart      # Task 1 (yeni)
test/features/nutrition/application/meal_capture_notifier_test.dart       # Task 2
test/features/nutrition/presentation/widgets/remaining_calories_card_test.dart  # Task 3 (yeni)
test/shared/widgets/stat_tile_test.dart                         # Task 4 (SectionHeader trailing)
test/features/nutrition/presentation/nutrition_screen_test.dart # Task 4
test/features/nutrition/presentation/widgets/food_item_edit_tile_test.dart      # Task 5
test/features/nutrition/presentation/meal_capture_screen_test.dart        # Task 5
```

---

### Task 1: Gram ölçekleme fonksiyonları

**Files:**
- Create: `lib/features/nutrition/domain/food_item_scaling.dart`
- Test: `test/features/nutrition/domain/food_item_scaling_test.dart`

**Interfaces:**
- Consumes: `FoodItem` (`lib/features/nutrition/domain/food_item.dart`, `copyWith`), `MacroTotals` (`lib/features/nutrition/domain/macro_totals.dart`, alanlar `calories`, `proteinG`, `carbsG`, `fatG`).
- Produces: `MacroTotals? perGramOf(FoodItem item)`, `FoodItem withGrams(FoodItem item, double grams, MacroTotals? perGram)`.

- [ ] **Step 1: Write the failing test**

`test/features/nutrition/domain/food_item_scaling_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:spor_takip/features/nutrition/domain/food_item.dart';
import 'package:spor_takip/features/nutrition/domain/food_item_scaling.dart';

void main() {
  const chicken = FoodItem(name: 'Tavuk', grams: 200, calories: 330, proteinG: 62, carbsG: 0, fatG: 7);

  group('perGramOf', () {
    test('is null when grams is zero', () {
      expect(perGramOf(const FoodItem(name: 'X', grams: 0, calories: 100)), isNull);
    });

    test('divides calories and macros by grams', () {
      final perGram = perGramOf(chicken)!;
      expect(perGram.calories, closeTo(1.65, 1e-9));
      expect(perGram.proteinG, closeTo(0.31, 1e-9));
      expect(perGram.carbsG, 0);
      expect(perGram.fatG, closeTo(0.035, 1e-9));
    });
  });

  group('withGrams', () {
    test('scales calories and macros with the per-gram values', () {
      final scaled = withGrams(chicken, 300, perGramOf(chicken));
      expect(scaled.grams, 300);
      expect(scaled.calories, closeTo(495, 1e-9));
      expect(scaled.proteinG, closeTo(93, 1e-9));
      expect(scaled.fatG, closeTo(10.5, 1e-9));
      expect(scaled.name, 'Tavuk');
    });

    test('without per-gram values only grams change', () {
      final scaled = withGrams(chicken, 300, null);
      expect(scaled.grams, 300);
      expect(scaled.calories, 330);
      expect(scaled.proteinG, 62);
    });

    test('going through zero grams and back keeps the ratio', () {
      final perGram = perGramOf(chicken);
      final zero = withGrams(chicken, 0, perGram);
      expect(zero.calories, 0);
      final back = withGrams(zero, 250, perGram);
      expect(back.calories, closeTo(412.5, 1e-9));
      expect(back.proteinG, closeTo(77.5, 1e-9));
    });

    test('keeps the needsReview flag', () {
      const item = FoodItem(name: 'Sos', grams: 50, calories: 100, needsReview: true);
      expect(withGrams(item, 100, perGramOf(item)).needsReview, isTrue);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test --no-pub test/features/nutrition/domain/food_item_scaling_test.dart`
Expected: FAIL (`food_item_scaling.dart` bulunamadı / `perGramOf` tanımsız).

- [ ] **Step 3: Write minimal implementation**

`lib/features/nutrition/domain/food_item_scaling.dart`:

```dart
import 'food_item.dart';
import 'macro_totals.dart';

/// 1 gram başına kcal/makro (R2 spec §4.4). Gram 0 ise oran bilinemez → null.
MacroTotals? perGramOf(FoodItem item) {
  if (item.grams <= 0) return null;
  return MacroTotals(
    calories: item.calories / item.grams,
    proteinG: item.proteinG / item.grams,
    carbsG: item.carbsG / item.grams,
    fatG: item.fatG / item.grams,
  );
}

/// Gramı değiştirir; [perGram] varsa kcal/makroları da `perGram × grams` yapar.
/// Oran dışarıda tutulduğu için gram geçici olarak 0'a inse de kaybolmaz.
FoodItem withGrams(FoodItem item, double grams, MacroTotals? perGram) {
  if (perGram == null) return item.copyWith(grams: grams);
  return item.copyWith(
    grams: grams,
    calories: perGram.calories * grams,
    proteinG: perGram.proteinG * grams,
    carbsG: perGram.carbsG * grams,
    fatG: perGram.fatG * grams,
  );
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test --no-pub test/features/nutrition/domain/food_item_scaling_test.dart`
Expected: PASS (6 test).

- [ ] **Step 5: Analyze and commit**

Run: `flutter analyze --no-pub lib/features/nutrition/domain test/features/nutrition/domain` → "No issues found!"

```bash
git add lib/features/nutrition/domain/food_item_scaling.dart test/features/nutrition/domain/food_item_scaling_test.dart
git commit -m "feat(nutrition): add per-gram food item scaling helpers

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 2: Düzeltme durumunda gram başı değerler ve `updateItemGrams`

**Files:**
- Modify: `lib/features/nutrition/application/meal_capture_state.dart` (`MealCaptureReviewing`)
- Modify: `lib/features/nutrition/application/meal_capture_notifier.dart`
- Test: `test/features/nutrition/application/meal_capture_notifier_test.dart`

**Interfaces:**
- Consumes: Task 1 `perGramOf`, `withGrams`.
- Produces:
  - `MealCaptureReviewing.perGram` (`List<MacroTotals?>`, varsayılan `const []`), `MealCaptureReviewing.totalCalories` (`double`), `copyWith({List<FoodItem>? items, List<Key>? itemKeys, List<MacroTotals?>? perGram})`.
  - `MealCaptureNotifier.updateItemGrams(int index, double grams)` (yeni).
  - `MealCaptureNotifier.updateItem(int index, FoodItem updated)`: imza aynı; kcal veya makro değişince oranı yeniler.

- [ ] **Step 1: Write the failing tests**

`test/features/nutrition/application/meal_capture_notifier_test.dart` dosyasında:

(a) `group('MealCaptureReviewing.canSave', …)` bloğunun sonuna (kapanış `});`'ından önce) şu testi ekle:

```dart
    test('totalCalories sums item calories', () {
      const state = MealCaptureReviewing(
        mealType: MealType.lunch,
        mealId: 'm',
        photoPath: 'p',
        items: [
          FoodItem(name: 'A', grams: 100, calories: 120.5),
          FoodItem(name: 'B', grams: 50, calories: 80),
        ],
        itemKeys: [ValueKey('a'), ValueKey('b')],
      );
      expect(state.totalCalories, 200.5);
    });
```

(b) `_registerNotifierTests()` içindeki `group('MealCaptureNotifier', …)` bloğunda `test('addManualItem appends a needs-review placeholder item', …)` testinden sonra şu testleri ekle:

```dart
    Future<MealCaptureNotifier> reviewWith(List<FoodItem> items) async {
      fakeRepo.analyzeResult = MealAnalysisResult(items: items, failureReason: AiFailureReason.none);
      final notifier = container.read(mealCaptureProvider.notifier);
      await notifier.startCapture(mealType: MealType.lunch, photoBytes: Uint8List(0));
      return notifier;
    }

    MealCaptureReviewing reviewing() => container.read(mealCaptureProvider) as MealCaptureReviewing;

    test('startCapture stores per-gram values for reviewed items only', () async {
      await reviewWith(const [
        FoodItem(name: 'Tavuk', grams: 200, calories: 330, proteinG: 62),
        FoodItem(name: 'Sos', grams: 0, needsReview: true),
      ]);

      final state = reviewing();
      expect(state.perGram, hasLength(2));
      expect(state.perGram[0]!.calories, closeTo(1.65, 1e-9));
      expect(state.perGram[1], isNull);
    });

    test('updateItemGrams scales calories and macros', () async {
      final notifier = await reviewWith(const [FoodItem(name: 'Tavuk', grams: 200, calories: 330, proteinG: 62)]);

      notifier.updateItemGrams(0, 300);

      final item = reviewing().items.single;
      expect(item.grams, 300);
      expect(item.calories, closeTo(495, 1e-9));
      expect(item.proteinG, closeTo(93, 1e-9));
      expect(reviewing().totalCalories, closeTo(495, 1e-9));
    });

    test('updateItemGrams keeps the ratio when grams pass through zero', () async {
      final notifier = await reviewWith(const [FoodItem(name: 'Tavuk', grams: 200, calories: 330)]);

      notifier.updateItemGrams(0, 0);
      notifier.updateItemGrams(0, 250);

      expect(reviewing().items.single.calories, closeTo(412.5, 1e-9));
    });

    test('updateItemGrams on an item without a ratio only changes grams', () async {
      final notifier = await reviewWith(const [FoodItem(name: 'Sos', grams: 0, calories: 0, needsReview: true)]);

      notifier.updateItemGrams(0, 40);

      final item = reviewing().items.single;
      expect(item.grams, 40);
      expect(item.calories, 0);
      expect(item.needsReview, isTrue);
    });

    test('updateItem with new calories refreshes the ratio', () async {
      final notifier = await reviewWith(const [FoodItem(name: 'Tavuk', grams: 200, calories: 330)]);

      notifier.updateItem(0, reviewing().items.single.copyWith(calories: 400));
      notifier.updateItemGrams(0, 100);

      expect(reviewing().items.single.calories, closeTo(200, 1e-9));
    });

    test('updateItem with only a new name keeps the ratio', () async {
      final notifier = await reviewWith(const [FoodItem(name: 'Tavuk', grams: 200, calories: 330)]);

      notifier.updateItemGrams(0, 0);
      notifier.updateItem(0, reviewing().items.single.copyWith(name: 'Izgara tavuk'));
      notifier.updateItemGrams(0, 200);

      expect(reviewing().items.single.calories, closeTo(330, 1e-9));
    });

    test('removeItem and addManualItem keep perGram aligned with items', () async {
      final notifier = await reviewWith(const [
        FoodItem(name: 'A', grams: 100, calories: 100),
        FoodItem(name: 'B', grams: 100, calories: 300),
      ]);

      notifier.removeItem(0);
      expect(reviewing().perGram, hasLength(1));
      expect(reviewing().perGram.single!.calories, closeTo(3, 1e-9));

      notifier.addManualItem();
      expect(reviewing().perGram, hasLength(2));
      expect(reviewing().perGram[1], isNull);
    });
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test --no-pub test/features/nutrition/application/meal_capture_notifier_test.dart`
Expected: FAIL (derleme hatası: `totalCalories`, `perGram`, `updateItemGrams` tanımsız).

- [ ] **Step 3: Update the state**

`lib/features/nutrition/application/meal_capture_state.dart`:

Importlara ekle:

```dart
import '../domain/macro_totals.dart';
```

`MealCaptureReviewing` sınıfını şununla değiştir:

```dart
class MealCaptureReviewing extends MealCaptureState {
  const MealCaptureReviewing({
    required this.mealType,
    required this.mealId,
    required this.photoPath,
    required this.items,
    required this.itemKeys,
    this.perGram = const [],
    this.aiFailureReason = AiFailureReason.none,
  });

  final MealType mealType;
  final String mealId;
  final String photoPath;
  final List<FoodItem> items;

  /// Her `items[i]` için istikrarlı, sadece istemci tarafında kullanılan bir
  /// anahtar (asla kaydedilmez). `FoodItemEditTile`'ı bununla anahtarlamak,
  /// bir öğe silindiğinde Flutter'ın o listedeki konumdaki widget'ı yanlış
  /// öğe için yeniden kullanmasını (ve dolayısıyla eski metnin görünmeye
  /// devam etmesini) engeller.
  final List<Key> itemKeys;

  /// Her `items[i]` için 1 gram başına kcal/makro (R2 spec §4.4); oran
  /// bilinmiyorsa null. Yalnız istemcide, kaydedilmez. Notifier'ın ürettiği
  /// durumlarda `items` ile aynı uzunluktadır.
  final List<MacroTotals?> perGram;
  final AiFailureReason aiFailureReason;

  bool get canSave =>
      items.isNotEmpty && items.every((item) => item.grams > 0 && !item.needsReview);

  double get totalCalories => items.fold(0, (sum, item) => sum + item.calories);

  MealCaptureReviewing copyWith({
    List<FoodItem>? items,
    List<Key>? itemKeys,
    List<MacroTotals?>? perGram,
  }) {
    return MealCaptureReviewing(
      mealType: mealType,
      mealId: mealId,
      photoPath: photoPath,
      items: items ?? this.items,
      itemKeys: itemKeys ?? this.itemKeys,
      perGram: perGram ?? this.perGram,
      aiFailureReason: aiFailureReason,
    );
  }
}
```

- [ ] **Step 4: Update the notifier**

`lib/features/nutrition/application/meal_capture_notifier.dart`:

Importlara ekle (alfabetik olarak `../domain/food_item.dart` satırından sonra):

```dart
import '../domain/food_item_scaling.dart';
import '../domain/macro_totals.dart';
```

`startCapture` içindeki `state = MealCaptureReviewing(…)` çağrısına `itemKeys` satırından sonra ekle:

```dart
      perGram: [for (final item in result.items) item.needsReview ? null : perGramOf(item)],
```

`updateItem`, `removeItem` ve `addManualItem` metotlarını şunlarla değiştir; `updateItemGrams` ve `_alignedPerGram` metotlarını ekle:

```dart
  /// Ad / kcal / makro değişimi. Kcal veya makro değiştiyse gram başı oran
  /// yeni değerlerden yeniden hesaplanır (gram 0 ise oran null olur).
  void updateItem(int index, FoodItem updated) {
    final current = state;
    if (current is! MealCaptureReviewing) return;
    final old = current.items[index];
    final items = [...current.items];
    items[index] = updated;
    final perGram = _alignedPerGram(current);
    final macrosChanged = old.calories != updated.calories ||
        old.proteinG != updated.proteinG ||
        old.carbsG != updated.carbsG ||
        old.fatG != updated.fatG;
    if (macrosChanged) perGram[index] = perGramOf(updated);
    state = current.copyWith(items: items, perGram: perGram);
  }

  /// Gram değişimi: oran varsa kcal/makrolar orantılı güncellenir; oran
  /// değişmez, böylece alan geçici olarak boşalsa da kaybolmaz.
  void updateItemGrams(int index, double grams) {
    final current = state;
    if (current is! MealCaptureReviewing) return;
    final perGram = _alignedPerGram(current);
    final items = [...current.items];
    items[index] = withGrams(items[index], grams, perGram[index]);
    state = current.copyWith(items: items, perGram: perGram);
  }

  void removeItem(int index) {
    final current = state;
    if (current is! MealCaptureReviewing) return;
    final items = [...current.items]..removeAt(index);
    final itemKeys = [...current.itemKeys]..removeAt(index);
    final perGram = _alignedPerGram(current)..removeAt(index);
    state = current.copyWith(items: items, itemKeys: itemKeys, perGram: perGram);
  }

  void addManualItem() {
    final current = state;
    if (current is! MealCaptureReviewing) return;
    state = current.copyWith(
      items: [...current.items, const FoodItem(name: '', grams: 0, needsReview: true)],
      itemKeys: [...current.itemKeys, UniqueKey()],
      perGram: [..._alignedPerGram(current), null],
    );
  }

  /// `perGram`'ı `items` uzunluğuna getirir (elle kurulmuş durumlarda liste
  /// boş olabilir); eksik oranlar null.
  List<MacroTotals?> _alignedPerGram(MealCaptureReviewing current) => [
        for (var i = 0; i < current.items.length; i++)
          i < current.perGram.length ? current.perGram[i] : null,
      ];
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `flutter test --no-pub test/features/nutrition/application/meal_capture_notifier_test.dart`
Expected: PASS (mevcut testler + 8 yeni test).

- [ ] **Step 6: Analyze and commit**

Run: `flutter analyze --no-pub lib/features/nutrition test/features/nutrition` → "No issues found!"

```bash
git add lib/features/nutrition/application/meal_capture_state.dart lib/features/nutrition/application/meal_capture_notifier.dart test/features/nutrition/application/meal_capture_notifier_test.dart
git commit -m "feat(nutrition): scale macros with grams during meal review

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 3: `RemainingCaloriesCard` ve R2 çevirileri

**Files:**
- Create: `lib/features/nutrition/presentation/widgets/remaining_calories_card.dart`
- Modify: `assets/translations/tr.json`, `assets/translations/en.json` (`nutrition` bölümü)
- Test: `test/features/nutrition/presentation/widgets/remaining_calories_card_test.dart`

**Interfaces:**
- Consumes: `MacroTotals`, `RingProgress.fraction(double value, double target)` (0–1, hedef ≤ 0 → 0, aşımda 1), `RingProgress.isOver(double value, double target)`, `upperCaseFor`.
- Produces: `RemainingCaloriesCard({required MacroTotals eaten, required double calorieTarget, required double proteinTarget})`, `enum RemainingMode { remaining, over, noTarget }`, `static RemainingMode RemainingCaloriesCard.modeFor(double eaten, double target)`. Anahtarlar: `remaining_calories_card`, `remaining_calories_label`, `remaining_calories_value`, `remaining_calories_bar`, `remaining_macro_protein`, `remaining_macro_carbs`, `remaining_macro_fat` (her birinin içinde `ValueKey('macro_chip_value')`).
- Çeviri anahtarları (bu ve sonraki görevler kullanır): `nutrition.remaining`, `over`, `eaten_label`, `eaten_of_target`, `kcal`, `protein_short`, `carbs_short`, `fat_short`, `empty_hint`, `item_grams`, `which_meal`, `take_photo_hint`, `items_found`, `new_item`, `grams_hint`, `needs_review_short`, `row_summary`, `total`.

- [ ] **Step 1: Add translations**

`assets/translations/tr.json` içinde şu satırı:

```json
    "item_summary": "{grams} g · {calories} kcal"
```

şununla değiştir:

```json
    "item_summary": "{grams} g · {calories} kcal",
    "remaining": "Kalan",
    "over": "Aşım",
    "eaten_label": "Yenen",
    "eaten_of_target": "{eaten} yenen / {target} hedef",
    "kcal": "kcal",
    "protein_short": "Protein",
    "carbs_short": "Karb.",
    "fat_short": "Yağ",
    "empty_hint": "Kamera butonuyla ilk öğününü ekle",
    "item_grams": "· {grams} g",
    "which_meal": "Hangi öğün?",
    "take_photo_hint": "Yapay zekâ yemekleri tanır",
    "items_found": "{count} yemek bulundu",
    "new_item": "Yeni yemek",
    "grams_hint": "Gram gir",
    "needs_review_short": "Kontrol",
    "row_summary": "{grams} g · P {protein} g",
    "total": "Toplam"
```

`assets/translations/en.json` içinde aynı satırı (`"item_summary": "{grams} g · {calories} kcal"`) şununla değiştir:

```json
    "item_summary": "{grams} g · {calories} kcal",
    "remaining": "Remaining",
    "over": "Over",
    "eaten_label": "Eaten",
    "eaten_of_target": "{eaten} eaten / {target} goal",
    "kcal": "kcal",
    "protein_short": "Protein",
    "carbs_short": "Carbs",
    "fat_short": "Fat",
    "empty_hint": "Add your first meal with the camera button",
    "item_grams": "· {grams} g",
    "which_meal": "Which meal?",
    "take_photo_hint": "AI recognises the foods",
    "items_found": "{count} foods found",
    "new_item": "New food",
    "grams_hint": "Enter grams",
    "needs_review_short": "Check",
    "row_summary": "{grams} g · P {protein} g",
    "total": "Total"
```

İki dosyanın da geçerli JSON kaldığını kontrol et:
Run: `node -e "JSON.parse(require('fs').readFileSync('assets/translations/tr.json'));JSON.parse(require('fs').readFileSync('assets/translations/en.json'));console.log('ok')"`
Expected: `ok` (Node yoksa: `powershell -Command "Get-Content assets/translations/tr.json -Raw | ConvertFrom-Json | Out-Null; Get-Content assets/translations/en.json -Raw | ConvertFrom-Json | Out-Null; 'ok'"`).

- [ ] **Step 2: Write the failing test**

`test/features/nutrition/presentation/widgets/remaining_calories_card_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spor_takip/core/theme/app_theme.dart';
import 'package:spor_takip/features/nutrition/domain/macro_totals.dart';
import 'package:spor_takip/features/nutrition/presentation/widgets/remaining_calories_card.dart';

import '../../../progress/presentation/test_app.dart';

void main() {
  setUpAll(initTestLocalization);

  final scheme = AppTheme.dark().colorScheme;

  Future<void> pump(WidgetTester tester, {required double kcal, required double target, double proteinTarget = 150}) async {
    await tester.pumpWidget(testApp(RemainingCaloriesCard(
      eaten: MacroTotals(calories: kcal, proteinG: 96, carbsG: 150, fatG: 42),
      calorieTarget: target,
      proteinTarget: proteinTarget,
    )));
    await tester.pumpAndSettle();
  }

  Text value(WidgetTester tester) => tester.widget<Text>(find.byKey(const Key('remaining_calories_value')));

  String chip(WidgetTester tester, String key) => tester
      .widget<Text>(find.descendant(of: find.byKey(Key(key)), matching: find.byKey(const ValueKey('macro_chip_value'))))
      .data!;

  test('modeFor picks remaining, over or no target', () {
    expect(RemainingCaloriesCard.modeFor(1420, 2100), RemainingMode.remaining);
    expect(RemainingCaloriesCard.modeFor(2100, 2100), RemainingMode.remaining);
    expect(RemainingCaloriesCard.modeFor(2220, 2100), RemainingMode.over);
    expect(RemainingCaloriesCard.modeFor(1420, 0), RemainingMode.noTarget);
  });

  testWidgets('under the target shows remaining calories and a bar', (tester) async {
    await pump(tester, kcal: 1420, target: 2100);

    expect(value(tester).data, '680');
    expect(value(tester).style!.color, scheme.onSurface);
    expect(find.byKey(const Key('remaining_calories_bar')), findsOneWidget);
  });

  testWidgets('over the target shows the excess in the error color', (tester) async {
    await pump(tester, kcal: 2220, target: 2100);

    expect(value(tester).data, '120');
    expect(value(tester).style!.color, scheme.error);
    final bar = tester.widget<LinearProgressIndicator>(find.byKey(const Key('remaining_calories_bar')));
    expect(bar.value, 1);
    expect(bar.color, scheme.error);
  });

  testWidgets('without a target shows eaten calories and no bar', (tester) async {
    await pump(tester, kcal: 1420, target: 0);

    expect(value(tester).data, '1420');
    expect(find.byKey(const Key('remaining_calories_bar')), findsNothing);
  });

  testWidgets('macro chips show protein against its target and grams for the rest', (tester) async {
    await pump(tester, kcal: 1420, target: 2100);

    expect(chip(tester, 'remaining_macro_protein'), '96/150 g');
    expect(chip(tester, 'remaining_macro_carbs'), '150 g');
    expect(chip(tester, 'remaining_macro_fat'), '42 g');
  });

  testWidgets('protein chip without a target shows grams only', (tester) async {
    await pump(tester, kcal: 1420, target: 2100, proteinTarget: 0);

    expect(chip(tester, 'remaining_macro_protein'), '96 g');
  });
}
```

- [ ] **Step 3: Run test to verify it fails**

Run: `flutter test --no-pub test/features/nutrition/presentation/widgets/remaining_calories_card_test.dart`
Expected: FAIL (`remaining_calories_card.dart` bulunamadı).

- [ ] **Step 4: Write the implementation**

`lib/features/nutrition/presentation/widgets/remaining_calories_card.dart`:

```dart
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../shared/text_case.dart';
import '../../../../shared/widgets/ring_progress.dart';
import '../../domain/macro_totals.dart';

enum RemainingMode { remaining, over, noTarget }

/// Beslenme ekranı üst kartı (R2 spec §3): kalan / aşım / yenen kcal, bar ve
/// üç makro kutusu.
class RemainingCaloriesCard extends StatelessWidget {
  const RemainingCaloriesCard({
    super.key,
    required this.eaten,
    required this.calorieTarget,
    required this.proteinTarget,
  });

  final MacroTotals eaten;
  final double calorieTarget;
  final double proteinTarget;

  static RemainingMode modeFor(double eaten, double target) {
    if (target <= 0) return RemainingMode.noTarget;
    return RingProgress.isOver(eaten, target) ? RemainingMode.over : RemainingMode.remaining;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final languageCode = Localizations.localeOf(context).languageCode;
    final kcal = eaten.calories;
    final mode = modeFor(kcal, calorieTarget);
    final (labelKey, value) = switch (mode) {
      RemainingMode.remaining => ('nutrition.remaining', calorieTarget - kcal),
      RemainingMode.over => ('nutrition.over', kcal - calorieTarget),
      RemainingMode.noTarget => ('nutrition.eaten_label', kcal),
    };
    final isOver = mode == RemainingMode.over;
    final muted = scheme.onSurfaceVariant;

    return Card(
      key: const Key('remaining_calories_card'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              upperCaseFor(labelKey.tr(), languageCode),
              key: const Key('remaining_calories_label'),
              style: theme.textTheme.labelMedium?.copyWith(color: muted, letterSpacing: 1),
            ),
            const SizedBox(height: 4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  '${value.round()}',
                  key: const Key('remaining_calories_value'),
                  style: theme.textTheme.displaySmall?.copyWith(color: isOver ? scheme.error : scheme.onSurface),
                ),
                const SizedBox(width: 6),
                Text('nutrition.kcal'.tr(), style: theme.textTheme.bodyMedium?.copyWith(color: muted)),
              ],
            ),
            if (mode != RemainingMode.noTarget) ...[
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  key: const Key('remaining_calories_bar'),
                  value: RingProgress.fraction(kcal, calorieTarget),
                  minHeight: 7,
                  color: isOver ? scheme.error : scheme.primary,
                  backgroundColor: scheme.outlineVariant,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'nutrition.eaten_of_target'.tr(namedArgs: {
                  'eaten': '${kcal.round()}',
                  'target': '${calorieTarget.round()}',
                }),
                style: theme.textTheme.bodySmall?.copyWith(color: muted),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _MacroChip(
                    key: const Key('remaining_macro_protein'),
                    label: 'nutrition.protein_short'.tr(),
                    value: proteinTarget > 0
                        ? '${eaten.proteinG.round()}/${proteinTarget.round()} g'
                        : '${eaten.proteinG.round()} g',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _MacroChip(
                    key: const Key('remaining_macro_carbs'),
                    label: 'nutrition.carbs_short'.tr(),
                    value: '${eaten.carbsG.round()} g',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _MacroChip(
                    key: const Key('remaining_macro_fat'),
                    label: 'nutrition.fat_short'.tr(),
                    value: '${eaten.fatG.round()} g',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MacroChip extends StatelessWidget {
  const _MacroChip({super.key, required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.outlineVariant,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(value, key: const ValueKey('macro_chip_value'), style: theme.textTheme.titleSmall),
          const SizedBox(height: 2),
          Text(label, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}
```

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter test --no-pub test/features/nutrition/presentation/widgets/remaining_calories_card_test.dart`
Expected: PASS (6 test).

- [ ] **Step 6: Analyze and commit**

Run: `flutter analyze --no-pub lib/features/nutrition test/features/nutrition` → "No issues found!"

```bash
git add assets/translations/tr.json assets/translations/en.json lib/features/nutrition/presentation/widgets/remaining_calories_card.dart test/features/nutrition/presentation/widgets/remaining_calories_card_test.dart
git commit -m "feat(nutrition): add remaining calories card

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 4: Beslenme ekranı yeni düzeni

**Files:**
- Create: `lib/shared/day_label.dart`
- Modify: `lib/shared/widgets/section_header.dart` (`trailing`)
- Modify: `lib/features/onboarding/presentation/home_screen.dart` (`_HomeHeader` içinde `dayLabel`)
- Modify: `lib/features/nutrition/presentation/nutrition_screen.dart` (tamamen yeniden yazılır)
- Modify: `assets/translations/tr.json`, `en.json` (`daily_totals_with_target`, `item_summary` silinir)
- Test: `test/shared/widgets/stat_tile_test.dart`, `test/features/nutrition/presentation/nutrition_screen_test.dart`

**Interfaces:**
- Consumes: Task 3 `RemainingCaloriesCard`, çeviri anahtarları `nutrition.kcal`, `nutrition.empty_hint`, `nutrition.item_grams`. Mevcut olanlar: `todayMealsProvider`, `profileProvider`, `nowProvider`, `sumMealMacros(List<Meal>)`, `MealType.values`.
- Produces: `String dayLabel(DateTime day)`, `SectionHeader(String title, {Key? key, String? trailing})` (trailing metni `ValueKey('section_header_trailing')` ile). Ekran anahtarları: `nutrition_date`, `nutrition_section_<type.name>`, `nutrition_food_row`.

- [ ] **Step 1: Write the failing SectionHeader test**

`test/shared/widgets/stat_tile_test.dart` dosyasının sonundaki `main` kapanışından önce ekle:

```dart
  testWidgets('section header shows an optional trailing text in the normal text color', (tester) async {
    await tester.pumpWidget(themed(const SectionHeader('Kahvaltı', trailing: '520 kcal')));

    final trailing = tester.widget<Text>(find.byKey(const ValueKey('section_header_trailing')));
    expect(trailing.data, '520 kcal');
    expect(trailing.style!.color, AppColors.text);
  });
```

- [ ] **Step 2: Update the nutrition screen test**

`test/features/nutrition/presentation/nutrition_screen_test.dart` içinde:

`shows empty state when there are no meals today` testini şununla değiştir:

```dart
  testWidgets('with no meals shows the remaining card and the empty state', (tester) async {
    await tester.pumpWidget(wrap(const NutritionScreen(), meals: const []));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('remaining_calories_card')), findsOneWidget);
    expect(tester.widget<Text>(find.byKey(const Key('remaining_calories_value'))).data, '2500');
    expect(find.byKey(const Key('nutrition_empty_state')), findsOneWidget);
  });
```

`lists meals grouped by meal type and shows daily totals` testindeki son satırı:

```dart
    expect(find.byKey(const Key('nutrition_daily_totals')), findsOneWidget);
```

şununla değiştir:

```dart
    // 2500 hedef − (380 + 250) yenen
    expect(tester.widget<Text>(find.byKey(const Key('remaining_calories_value'))).data, '1870');
    String subtotal(String type) => tester
        .widget<Text>(find.descendant(
          of: find.byKey(Key('nutrition_section_$type')),
          matching: find.byKey(const ValueKey('section_header_trailing')),
        ))
        .data!;
    expect(subtotal('breakfast'), startsWith('380'));
    expect(subtotal('lunch'), startsWith('250'));
    expect(find.byKey(const Key('nutrition_section_dinner')), findsNothing);
    expect(find.byKey(const Key('nutrition_empty_state')), findsNothing);
```

- [ ] **Step 3: Run tests to verify they fail**

Run: `flutter test --no-pub test/shared/widgets/stat_tile_test.dart test/features/nutrition/presentation/nutrition_screen_test.dart`
Expected: FAIL (`trailing` parametresi yok; `remaining_calories_card` bulunamadı).

- [ ] **Step 4: Add `trailing` to SectionHeader**

`lib/shared/widgets/section_header.dart` dosyasını şununla değiştir:

```dart
import 'package:flutter/material.dart';

import '../../core/theme/app_fonts.dart';
import '../text_case.dart';

/// Küçük, büyük harfli, gri bölüm başlığı (spec §4.2); isteğe bağlı sağda
/// normal renkte kısa metin (ör. öğün kalori ara toplamı).
class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.trailing});

  final String title;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.labelLarge?.copyWith(
      fontFamily: AppFonts.heading,
      fontWeight: FontWeight.w800,
      letterSpacing: 1.2,
      color: theme.colorScheme.onSurfaceVariant,
    );
    final trailing = this.trailing;
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(upperCaseFor(title, Localizations.localeOf(context).languageCode), style: style),
          ),
          if (trailing != null)
            Text(
              trailing,
              key: const ValueKey('section_header_trailing'),
              style: style?.copyWith(color: theme.colorScheme.onSurface),
            ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 5: Extract `dayLabel` and use it on the home screen**

`lib/shared/day_label.dart`:

```dart
import 'package:easy_localization/easy_localization.dart';

/// "Cumartesi, 4 Ekim" — ana sayfa ve beslenme ekranı başlığındaki tarih.
String dayLabel(DateTime day) =>
    '${'home.weekday_${day.weekday}'.tr()}, ${day.day} ${'home.month_${day.month}'.tr()}';
```

`lib/features/onboarding/presentation/home_screen.dart` içinde:
- Importlara `import '../../../shared/day_label.dart';` ekle (`text_case.dart` importunun üstüne).
- `_HomeHeader.build` içindeki satırı:

```dart
    final date = '${'home.weekday_${now.weekday}'.tr()}, ${now.day} ${'home.month_${now.month}'.tr()}';
```

şununla değiştir:

```dart
    final date = dayLabel(now);
```

- [ ] **Step 6: Rewrite the nutrition screen**

`lib/features/nutrition/presentation/nutrition_screen.dart`:

```dart
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/day_label.dart';
import '../../../shared/text_case.dart';
import '../../../shared/widgets/section_header.dart';
import '../../onboarding/application/profile_providers.dart';
import '../../onboarding/domain/profile.dart';
import '../../workout/application/session_providers.dart';
import '../application/today_meals_provider.dart';
import '../domain/food_item.dart';
import '../domain/macro_totals.dart';
import '../domain/meal.dart';
import '../domain/meal_type.dart';
import 'widgets/remaining_calories_card.dart';

/// Beslenme ekranı (R2 spec §3): tarih, kalan kalori kartı, öğün tipi başına
/// ara toplamlı kartlar.
class NutritionScreen extends ConsumerWidget {
  const NutritionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mealsAsync = ref.watch(todayMealsProvider);
    // Profil henüz yüklenmediyse kart "hedefsiz" (YENEN) durumunda görünür.
    final profile = ref.watch(profileProvider).value;
    final now = ref.watch(nowProvider)();

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
        data: (meals) => _NutritionBody(meals: meals, profile: profile, now: now),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(child: Text('nutrition.load_error'.tr())),
      ),
    );
  }
}

class _NutritionBody extends StatelessWidget {
  const _NutritionBody({required this.meals, required this.profile, required this.now});

  final List<Meal> meals;
  final Profile? profile;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return ListView(
      // Alt boşluk: son satır FAB'ın altında kalmasın.
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
      children: [
        Text(
          upperCaseFor(dayLabel(now), context.locale.languageCode),
          key: const Key('nutrition_date'),
          style: theme.textTheme.labelMedium?.copyWith(color: muted, letterSpacing: 1),
        ),
        const SizedBox(height: 12),
        RemainingCaloriesCard(
          eaten: sumMealMacros(meals),
          calorieTarget: profile?.dailyCalorieTarget ?? 0,
          proteinTarget: profile?.dailyProteinTargetG ?? 0,
        ),
        if (meals.isEmpty)
          Padding(
            key: const Key('nutrition_empty_state'),
            padding: const EdgeInsets.only(top: 32),
            child: Column(
              children: [
                Text('nutrition.no_meals_today'.tr(), style: theme.textTheme.titleMedium, textAlign: TextAlign.center),
                const SizedBox(height: 4),
                Text(
                  'nutrition.empty_hint'.tr(),
                  style: theme.textTheme.bodySmall?.copyWith(color: muted),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          )
        else
          for (final type in MealType.values) ..._section(context, type),
      ],
    );
  }

  List<Widget> _section(BuildContext context, MealType type) {
    final mealsOfType = meals.where((meal) => meal.mealType == type).toList();
    if (mealsOfType.isEmpty) return const [];
    final items = [for (final meal in mealsOfType) ...meal.items];
    final subtotal = sumMealMacros(mealsOfType).calories;
    final divider = Theme.of(context).colorScheme.outlineVariant;
    return [
      SectionHeader(
        'nutrition.meal_type_${type.name}'.tr(),
        key: Key('nutrition_section_${type.name}'),
        trailing: '${subtotal.round()} ${'nutrition.kcal'.tr()}',
      ),
      Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Column(
            children: [
              for (var i = 0; i < items.length; i++) ...[
                if (i > 0) Divider(height: 1, color: divider),
                _FoodRow(item: items[i]),
              ],
            ],
          ),
        ),
      ),
    ];
  }
}

class _FoodRow extends StatelessWidget {
  const _FoodRow({required this.item});

  final FoodItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      key: const Key('nutrition_food_row'),
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Flexible(child: Text(item.name, overflow: TextOverflow.ellipsis)),
          const SizedBox(width: 6),
          Text(
            'nutrition.item_grams'.tr(namedArgs: {'grams': '${item.grams.round()}'}),
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const Spacer(),
          Text('${item.calories.round()}', style: theme.textTheme.titleSmall),
        ],
      ),
    );
  }
}
```

- [ ] **Step 7: Remove unused translations**

`assets/translations/tr.json` ve `en.json` içinden `nutrition.daily_totals_with_target` ve `nutrition.item_summary` satırlarını sil. `item_summary` silinince bir önceki satırın sonundaki virgülün hâlâ doğru olduğuna dikkat et (sonraki satır `"remaining": …`).

Run: `git grep -n "daily_totals_with_target\|item_summary" -- lib test` → çıktı boş.
Task 3 Step 1'deki JSON doğrulama komutunu tekrar çalıştır → `ok`.

- [ ] **Step 8: Run tests to verify they pass**

Run: `flutter test --no-pub test/shared/widgets/stat_tile_test.dart test/features/nutrition/presentation/nutrition_screen_test.dart test/features/onboarding`
Expected: PASS (ana sayfa testleri de geçmeli; tarih metni aynı).

- [ ] **Step 9: Analyze and commit**

Run: `flutter analyze --no-pub` → "No issues found!"

```bash
git add lib/shared/day_label.dart lib/shared/widgets/section_header.dart lib/features/onboarding/presentation/home_screen.dart lib/features/nutrition/presentation/nutrition_screen.dart assets/translations/tr.json assets/translations/en.json test/shared/widgets/stat_tile_test.dart test/features/nutrition/presentation/nutrition_screen_test.dart
git commit -m "feat(nutrition): switch nutrition screen to remaining-calories layout

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 5: Öğün ekleme ekranı — açılır satırlar, fotoğraf önizleme, sabit toplam

**Files:**
- Modify: `lib/features/nutrition/presentation/widgets/food_item_edit_tile.dart` (tamamen yeniden yazılır)
- Modify: `lib/features/nutrition/presentation/meal_capture_screen.dart` (tamamen yeniden yazılır)
- Modify: `assets/translations/tr.json`, `en.json` (`select_meal_type`, `item_needs_review` silinir)
- Test: `test/features/nutrition/presentation/widgets/food_item_edit_tile_test.dart` (yeniden yazılır), `test/features/nutrition/presentation/meal_capture_screen_test.dart`

**Interfaces:**
- Consumes: Task 2 `MealCaptureNotifier.updateItem`, `updateItemGrams`, `removeItem`, `addManualItem`, `confirmSave`, `MealCaptureReviewing.totalCalories`, `.canSave`, `.itemKeys`. Task 3 çeviri anahtarları `which_meal`, `take_photo_hint`, `items_found`, `new_item`, `grams_hint`, `needs_review_short`, `row_summary`, `total`, `kcal`.
- Produces: `FoodItemEditTile({Key? key, required FoodItem item, required int index, required ValueChanged<FoodItem> onChanged, required ValueChanged<double> onGramsChanged, required VoidCallback onRemove})`. Yeni anahtarlar: `food_item_row_$index`, `food_item_kcal_$index`, `food_item_grams_hint_$index`, `capture_photo_preview`, `capture_total_calories`. Kaydet ve Tekrar dene artık `FilledButton`.

- [ ] **Step 1: Rewrite the tile test**

`test/features/nutrition/presentation/widgets/food_item_edit_tile_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spor_takip/features/nutrition/domain/food_item.dart';
import 'package:spor_takip/features/nutrition/presentation/widgets/food_item_edit_tile.dart';

import '../../../progress/presentation/test_app.dart';

void main() {
  setUpAll(initTestLocalization);

  Future<void> pump(
    WidgetTester tester,
    FoodItem item, {
    int index = 0,
    ValueChanged<FoodItem>? onChanged,
    ValueChanged<double>? onGramsChanged,
    VoidCallback? onRemove,
  }) async {
    await tester.pumpWidget(testApp(FoodItemEditTile(
      item: item,
      index: index,
      onChanged: onChanged ?? (_) {},
      onGramsChanged: onGramsChanged ?? (_) {},
      onRemove: onRemove ?? () {},
    )));
    await tester.pumpAndSettle();
  }

  /// Ebeveyn gibi davranan sarmalayıcı: tile'ın bildirdiği değişikliği
  /// [item]'a yazar ve yeniden çizer (notifier akışının taklidi).
  Future<ValueNotifier<FoodItem>> pumpLive(WidgetTester tester, FoodItem initial) async {
    final item = ValueNotifier(initial);
    await tester.pumpWidget(testApp(ValueListenableBuilder<FoodItem>(
      valueListenable: item,
      builder: (context, value, _) => FoodItemEditTile(
        item: value,
        index: 0,
        onChanged: (updated) => item.value = updated,
        onGramsChanged: (grams) => item.value = value.copyWith(grams: grams),
        onRemove: () {},
      ),
    )));
    await tester.pumpAndSettle();
    return item;
  }

  testWidgets('a reviewed item starts collapsed with a one-line summary', (tester) async {
    await pump(tester, const FoodItem(name: 'Tavuk', grams: 200, calories: 330, proteinG: 62));

    expect(find.text('Tavuk'), findsOneWidget);
    expect(tester.widget<Text>(find.byKey(const Key('food_item_kcal_0'))).data, '330');
    expect(find.byKey(const Key('food_item_name_field_0')), findsNothing);
  });

  testWidgets('tapping the row expands and collapses the fields', (tester) async {
    await pump(tester, const FoodItem(name: 'Tavuk', grams: 200, calories: 330));

    await tester.tap(find.byKey(const Key('food_item_row_0')));
    await tester.pumpAndSettle();
    for (final field in ['name', 'grams', 'calories', 'protein', 'carbs', 'fat']) {
      expect(find.byKey(Key('food_item_${field}_field_0')), findsOneWidget, reason: field);
    }

    await tester.tap(find.byKey(const Key('food_item_row_0')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('food_item_name_field_0')), findsNothing);
  });

  testWidgets('an item that needs review starts expanded with a badge and no calories', (tester) async {
    await pump(tester, const FoodItem(name: 'Sos', grams: 30, needsReview: true));

    expect(find.byKey(const Key('food_item_needs_review_badge_0')), findsOneWidget);
    expect(find.byKey(const Key('food_item_calories_field_0')), findsOneWidget);
    expect(tester.widget<Text>(find.byKey(const Key('food_item_kcal_0'))).data, '—');
  });

  testWidgets('zero grams shows the grams hint', (tester) async {
    await pump(tester, const FoodItem(name: '', grams: 0, needsReview: true));

    expect(find.byKey(const Key('food_item_grams_hint_0')), findsOneWidget);
  });

  // Gram düzenlemesi tek başına "incelendi" sinyali değildir; ölçekleme
  // notifier'da yapılır, tile yalnız yeni gramı bildirir.
  testWidgets('editing grams reports the new grams through onGramsChanged only', (tester) async {
    double? grams;
    FoodItem? changed;
    await pump(
      tester,
      const FoodItem(name: 'Sos', grams: 0, needsReview: true),
      onGramsChanged: (value) => grams = value,
      onChanged: (value) => changed = value,
    );

    await tester.enterText(find.byKey(const Key('food_item_grams_field_0')), '30');
    await tester.pump();

    expect(grams, 30);
    expect(changed, isNull);
  });

  testWidgets('typing a macro clears needsReview but the fields stay visible', (tester) async {
    final item = await pumpLive(tester, const FoodItem(name: 'Sos', grams: 30, needsReview: true));

    await tester.enterText(find.byKey(const Key('food_item_calories_field_0')), '1');
    await tester.pumpAndSettle();

    expect(item.value.needsReview, isFalse);
    expect(item.value.calories, 1);
    expect(find.byKey(const Key('food_item_calories_field_0')), findsOneWidget);
    expect(find.byKey(const Key('food_item_protein_field_0')), findsOneWidget);
    expect(find.byKey(const Key('food_item_needs_review_badge_0')), findsNothing);
  });

  testWidgets('values changed from outside appear in fields that are not focused', (tester) async {
    final item = await pumpLive(tester, const FoodItem(name: 'Tavuk', grams: 200, calories: 330));
    await tester.tap(find.byKey(const Key('food_item_row_0')));
    await tester.pumpAndSettle();

    item.value = item.value.copyWith(grams: 300, calories: 495);
    await tester.pumpAndSettle();

    String fieldText(String field) =>
        tester.widget<TextField>(find.byKey(Key('food_item_${field}_field_0'))).controller!.text;
    expect(fieldText('grams'), '300');
    expect(fieldText('calories'), '495');
  });

  testWidgets('tapping remove calls onRemove', (tester) async {
    var removed = false;
    await pump(tester, const FoodItem(name: 'Tavuk', grams: 150), index: 2, onRemove: () => removed = true);

    await tester.tap(find.byKey(const Key('food_item_row_2')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('food_item_remove_button_2')));
    await tester.pump();

    expect(removed, isTrue);
  });
}
```

- [ ] **Step 2: Update the capture screen test**

`test/features/nutrition/presentation/meal_capture_screen_test.dart` içinde:

(a) Importlara `import 'dart:convert';` ekle (`dart:typed_data`'dan önce) ve `void main()`'den önce şunu ekle:

```dart
/// 1×1 saydam PNG — önizlemenin gerçek bir görüntüyle çizildiğini doğrular.
final _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
);
```

(b) `selecting meal type then picking a photo shows detected items` testinde

```dart
    expect(find.byKey(const Key('food_item_name_field_0')), findsOneWidget);
    final saveButton = find.byKey(const Key('capture_save_button'));
    expect(tester.widget<ElevatedButton>(saveButton).onPressed, isNotNull);
```

satırlarını şununla değiştir:

```dart
    // İncelenmiş yemek kapalı satır olarak gelir; alanlar dokununca açılır.
    expect(find.byKey(const Key('food_item_name_field_0')), findsNothing);
    await tester.tap(find.byKey(const Key('food_item_row_0')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('food_item_name_field_0')), findsOneWidget);
    final saveButton = find.byKey(const Key('capture_save_button'));
    expect(tester.widget<FilledButton>(saveButton).onPressed, isNotNull);
```

(c) Dosyanın sonundaki `main` kapanışından önce şu testleri ekle:

```dart
  Future<void> reviewWith(WidgetTester tester, List<FoodItem> items, {Uint8List? photo}) async {
    final repo = FakeMealRepository()
      ..analyzeResult = MealAnalysisResult(items: items, failureReason: AiFailureReason.none);
    await tester.pumpWidget(wrap(
      MealCaptureScreen(pickImageOverride: (_) async => photo ?? Uint8List(0)),
      repo: repo,
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('meal_type_lunch_chip')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('capture_take_photo_button')));
    await tester.pumpAndSettle();
  }

  testWidgets('review shows the photo preview and the meal type in the app bar', (tester) async {
    await reviewWith(tester, const [FoodItem(name: 'Tavuk', grams: 200, calories: 330)], photo: _png);

    expect(find.byKey(const Key('capture_photo_preview')), findsOneWidget);
    expect(
      find.descendant(of: find.byType(AppBar), matching: find.text('nutrition.meal_type_lunch'.tr())),
      findsOneWidget,
    );
  });

  testWidgets('changing grams updates the live total', (tester) async {
    await reviewWith(tester, const [FoodItem(name: 'Tavuk', grams: 200, calories: 330)]);

    Text total() => tester.widget<Text>(find.byKey(const Key('capture_total_calories')));
    expect(total().data, startsWith('330'));

    await tester.tap(find.byKey(const Key('food_item_row_0')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('food_item_grams_field_0')), '300');
    await tester.pumpAndSettle();

    expect(total().data, startsWith('495'));
  });

  testWidgets('typing a macro for an item that needs review keeps its fields open', (tester) async {
    await reviewWith(tester, const [FoodItem(name: 'Sos', grams: 30, needsReview: true)]);

    await tester.enterText(find.byKey(const Key('food_item_calories_field_0')), '1');
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('food_item_protein_field_0')), findsOneWidget);
    expect(tester.widget<FilledButton>(find.byKey(const Key('capture_save_button'))).onPressed, isNotNull);
  });
```

- [ ] **Step 3: Run tests to verify they fail**

Run: `flutter test --no-pub test/features/nutrition/presentation/widgets/food_item_edit_tile_test.dart test/features/nutrition/presentation/meal_capture_screen_test.dart`
Expected: FAIL (`onGramsChanged` parametresi yok; `food_item_row_0` bulunamadı).

- [ ] **Step 4: Rewrite the tile**

`lib/features/nutrition/presentation/widgets/food_item_edit_tile.dart`:

```dart
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../domain/food_item.dart';

/// Düzenlenebilir alanlar. [keyName] mevcut test anahtarlarıyla aynı
/// (`food_item_<keyName>_field_<index>`); `title` değeri bilerek `name`
/// değil (enum'un `.name` getter'ıyla karışmasın).
enum _Field {
  title('name', 'nutrition.item_name_label'),
  grams('grams', 'nutrition.item_grams_label'),
  calories('calories', 'nutrition.item_calories_label'),
  protein('protein', 'nutrition.item_protein_label'),
  carbs('carbs', 'nutrition.item_carbs_label'),
  fat('fat', 'nutrition.item_fat_label');

  const _Field(this.keyName, this.labelKey);

  final String keyName;
  final String labelKey;
}

/// Düzeltme ekranında bir yemek (R2 spec §4.3): kapalıyken tek satır özet,
/// dokununca tüm alanlar. Açık/kapalı durumu burada tutulur; böylece
/// `needsReview` false olunca alanlar kaybolmaz.
class FoodItemEditTile extends StatefulWidget {
  const FoodItemEditTile({
    super.key,
    required this.item,
    required this.index,
    required this.onChanged,
    required this.onGramsChanged,
    required this.onRemove,
  });

  final FoodItem item;
  final int index;

  /// Ad, kcal veya makro değişimi (makro değişimi `needsReview`'u kapatır).
  final ValueChanged<FoodItem> onChanged;

  /// Gram değişimi; kcal/makro ölçeklemesini çağıran taraf yapar.
  final ValueChanged<double> onGramsChanged;
  final VoidCallback onRemove;

  @override
  State<FoodItemEditTile> createState() => _FoodItemEditTileState();
}

class _FoodItemEditTileState extends State<FoodItemEditTile> {
  late bool _expanded = widget.item.needsReview || widget.item.grams <= 0;
  late final Map<_Field, TextEditingController> _controllers = {
    for (final field in _Field.values) field: TextEditingController(text: _textFor(widget.item, field)),
  };
  final Map<_Field, FocusNode> _focusNodes = {for (final field in _Field.values) field: FocusNode()};

  static String _number(double value) {
    if (value == 0) return '';
    return value == value.roundToDouble() ? value.toInt().toString() : value.toStringAsFixed(1);
  }

  static String _textFor(FoodItem item, _Field field) => switch (field) {
        _Field.title => item.name,
        _Field.grams => _number(item.grams),
        _Field.calories => _number(item.calories),
        _Field.protein => _number(item.proteinG),
        _Field.carbs => _number(item.carbsG),
        _Field.fat => _number(item.fatG),
      };

  @override
  void didUpdateWidget(covariant FoodItemEditTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Dışarıdan gelen değişikliği (gram ölçeklemesi) odakta olmayan alanlara
    // yaz; kullanıcının o an yazdığı alana dokunma (imleç kaçmasın).
    for (final field in _Field.values) {
      if (_focusNodes[field]!.hasFocus) continue;
      final text = _textFor(widget.item, field);
      if (_controllers[field]!.text != text) _controllers[field]!.text = text;
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    for (final node in _focusNodes.values) {
      node.dispose();
    }
    super.dispose();
  }

  void _onFieldChanged(_Field field, String text) {
    final item = widget.item;
    if (field == _Field.title) {
      widget.onChanged(item.copyWith(name: text));
      return;
    }
    final value = double.tryParse(text) ?? 0;
    switch (field) {
      case _Field.grams:
        widget.onGramsChanged(value);
      case _Field.calories:
        widget.onChanged(item.copyWith(calories: value, needsReview: false));
      case _Field.protein:
        widget.onChanged(item.copyWith(proteinG: value, needsReview: false));
      case _Field.carbs:
        widget.onChanged(item.copyWith(carbsG: value, needsReview: false));
      case _Field.fat:
        widget.onChanged(item.copyWith(fatG: value, needsReview: false));
      case _Field.title:
        break;
    }
  }

  Widget _field(_Field field) {
    return TextField(
      key: Key('food_item_${field.keyName}_field_${widget.index}'),
      controller: _controllers[field],
      focusNode: _focusNodes[field],
      keyboardType: field == _Field.title ? TextInputType.text : TextInputType.number,
      decoration: InputDecoration(labelText: field.labelKey.tr(), isDense: true),
      onChanged: (text) => _onFieldChanged(field, text),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final item = widget.item;
    final index = widget.index;
    final muted = scheme.onSurfaceVariant;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            key: Key('food_item_row_$index'),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                item.name.isEmpty ? 'nutrition.new_item'.tr() : item.name,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodyLarge?.copyWith(color: item.name.isEmpty ? muted : null),
                              ),
                            ),
                            if (item.needsReview) ...[
                              const SizedBox(width: 8),
                              Container(
                                key: Key('food_item_needs_review_badge_$index'),
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: scheme.error.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'nutrition.needs_review_short'.tr(),
                                  style: theme.textTheme.labelSmall?.copyWith(color: scheme.error),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        if (item.grams <= 0)
                          Text(
                            'nutrition.grams_hint'.tr(),
                            key: Key('food_item_grams_hint_$index'),
                            style: theme.textTheme.bodySmall?.copyWith(color: scheme.error),
                          )
                        else
                          Text(
                            'nutrition.row_summary'.tr(namedArgs: {
                              'grams': '${item.grams.round()}',
                              'protein': '${item.proteinG.round()}',
                            }),
                            style: theme.textTheme.bodySmall?.copyWith(color: muted),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    item.needsReview ? '—' : '${item.calories.round()}',
                    key: Key('food_item_kcal_$index'),
                    style: theme.textTheme.titleLarge,
                  ),
                  Icon(_expanded ? Icons.expand_less : Icons.expand_more, color: muted),
                ],
              ),
            ),
          ),
          if (_expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(child: _field(_Field.title)),
                      IconButton(
                        key: Key('food_item_remove_button_$index'),
                        icon: const Icon(Icons.delete_outline),
                        tooltip: 'nutrition.item_remove'.tr(),
                        onPressed: widget.onRemove,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _field(_Field.grams),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(child: _field(_Field.calories)),
                      const SizedBox(width: 8),
                      Expanded(child: _field(_Field.protein)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(child: _field(_Field.carbs)),
                      const SizedBox(width: 8),
                      Expanded(child: _field(_Field.fat)),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 5: Rewrite the capture screen**

`lib/features/nutrition/presentation/meal_capture_screen.dart`:

```dart
import 'dart:typed_data';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../shared/text_case.dart';
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

  /// Düzeltme adımındaki önizleme için seçilen fotoğraf (R2 spec §4.3).
  Uint8List? _photoBytes;

  @override
  void initState() {
    super.initState();
    // Bir önceki, tamamlanmamış çekimden kalan Reviewing/Error durumunu
    // temizle — kullanıcı geri gidip yeniden girdiğinde her zaman temiz
    // (Idle) bir ekranla karşılaşsın.
    Future.microtask(() => ref.read(mealCaptureProvider.notifier).reset());
  }

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
    setState(() => _photoBytes = bytes);
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
    final title = state is MealCaptureReviewing
        ? 'nutrition.meal_type_${state.mealType.name}'.tr()
        : 'nutrition.capture_title'.tr();

    return Scaffold(
      key: const Key('meal_capture_screen'),
      appBar: AppBar(title: Text(title)),
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
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final enabled = _selectedType != null;
    return ListView(
      children: [
        Text(
          upperCaseFor('nutrition.which_meal'.tr(), context.locale.languageCode),
          style: theme.textTheme.labelMedium?.copyWith(color: scheme.onSurfaceVariant, letterSpacing: 1),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: MealType.values.map((type) {
            final selected = _selectedType == type;
            return ChoiceChip(
              key: Key('meal_type_${type.name}_chip'),
              label: Text(
                'nutrition.meal_type_${type.name}'.tr(),
                style: TextStyle(
                  color: selected ? scheme.onPrimary : scheme.onSurface,
                  fontWeight: selected ? FontWeight.w600 : null,
                ),
              ),
              selected: selected,
              showCheckmark: false,
              selectedColor: scheme.primary,
              onSelected: (_) => setState(() => _selectedType = type),
            );
          }).toList(),
        ),
        const SizedBox(height: 20),
        _CaptureTile(
          key: const Key('capture_take_photo_button'),
          icon: Icons.photo_camera_outlined,
          title: 'nutrition.take_photo'.tr(),
          subtitle: 'nutrition.take_photo_hint'.tr(),
          primary: true,
          onTap: enabled ? () => _capture(ImageSource.camera) : null,
        ),
        const SizedBox(height: 12),
        _CaptureTile(
          key: const Key('capture_gallery_button'),
          icon: Icons.photo_library_outlined,
          title: 'nutrition.pick_from_gallery'.tr(),
          primary: false,
          onTap: enabled ? () => _capture(ImageSource.gallery) : null,
        ),
      ],
    );
  }

  Widget _buildUploadError() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('nutrition.upload_error'.tr(), key: const Key('capture_upload_error')),
          const SizedBox(height: 12),
          FilledButton(
            key: const Key('capture_retry_button'),
            onPressed: () => ref.read(mealCaptureProvider.notifier).reset(),
            child: Text('nutrition.retry'.tr()),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewing(MealCaptureReviewing state) {
    final notifier = ref.read(mealCaptureProvider.notifier);
    final scheme = Theme.of(context).colorScheme;
    final photo = _photoBytes;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: ListView(
            children: [
              if (photo != null) _PhotoPreview(bytes: photo, itemCount: state.items.length),
              if (state.aiFailureReason != AiFailureReason.none)
                Container(
                  key: const Key('capture_ai_failure_banner'),
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: scheme.error.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    state.aiFailureReason == AiFailureReason.quotaExceeded
                        ? 'nutrition.ai_quota_exceeded'.tr()
                        : 'nutrition.ai_unavailable'.tr(),
                    style: TextStyle(color: scheme.error),
                  ),
                ),
              for (var i = 0; i < state.items.length; i++)
                Padding(
                  key: state.itemKeys[i],
                  padding: const EdgeInsets.only(bottom: 8),
                  child: FoodItemEditTile(
                    item: state.items[i],
                    index: i,
                    onChanged: (updated) => notifier.updateItem(i, updated),
                    onGramsChanged: (grams) => notifier.updateItemGrams(i, grams),
                    onRemove: () => notifier.removeItem(i),
                  ),
                ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  key: const Key('capture_add_item_button'),
                  onPressed: notifier.addManualItem,
                  icon: const Icon(Icons.add),
                  label: Text('nutrition.add_item_manually'.tr()),
                ),
              ),
            ],
          ),
        ),
        _TotalBar(totalCalories: state.totalCalories, onSave: state.canSave ? notifier.confirmSave : null),
      ],
    );
  }
}

/// Seçim adımındaki büyük dokunma kutusu; [onTap] null ise soluk ve pasif.
class _CaptureTile extends StatelessWidget {
  const _CaptureTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    required this.primary,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final bool primary;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final foreground = primary ? scheme.onPrimary : scheme.onSurface;
    final subtitle = this.subtitle;
    return Opacity(
      opacity: onTap == null ? 0.4 : 1,
      child: Material(
        color: primary ? scheme.primary : scheme.surfaceContainer,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: primary ? BorderSide.none : BorderSide(color: scheme.outlineVariant),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            height: 120,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 32, color: foreground),
                const SizedBox(height: 6),
                Text(title, style: theme.textTheme.titleMedium?.copyWith(color: foreground)),
                if (subtitle != null)
                  Text(subtitle, style: theme.textTheme.bodySmall?.copyWith(color: foreground)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PhotoPreview extends StatelessWidget {
  const _PhotoPreview({required this.bytes, required this.itemCount});

  final Uint8List bytes;
  final int itemCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      key: const Key('capture_photo_preview'),
      height: 140,
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(color: scheme.surfaceContainer, borderRadius: BorderRadius.circular(16)),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.memory(
            bytes,
            fit: BoxFit.cover,
            // Çözülemeyen görüntüde boş zemin kalsın, hata fırlatılmasın.
            errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
          ),
          Positioned(
            left: 8,
            bottom: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: scheme.surface.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'nutrition.items_found'.tr(namedArgs: {'count': '$itemCount'}),
                style: theme.textTheme.bodySmall,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Düzeltme adımının altındaki sabit toplam + Kaydet.
class _TotalBar extends StatelessWidget {
  const _TotalBar({required this.totalCalories, required this.onSave});

  final double totalCalories;
  final VoidCallback? onSave;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.only(top: 12),
      decoration: BoxDecoration(border: Border(top: BorderSide(color: scheme.outlineVariant))),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                upperCaseFor('nutrition.total'.tr(), context.locale.languageCode),
                style: theme.textTheme.labelMedium?.copyWith(color: scheme.onSurfaceVariant, letterSpacing: 1),
              ),
              const Spacer(),
              Text(
                '${totalCalories.round()} ${'nutrition.kcal'.tr()}',
                key: const Key('capture_total_calories'),
                style: theme.textTheme.titleLarge,
              ),
            ],
          ),
          const SizedBox(height: 8),
          FilledButton(
            key: const Key('capture_save_button'),
            onPressed: onSave,
            child: Text('nutrition.save'.tr()),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 6: Remove unused translations**

`assets/translations/tr.json` ve `en.json` içinden `nutrition.select_meal_type` ve `nutrition.item_needs_review` satırlarını sil.

Run: `git grep -n "select_meal_type\|item_needs_review" -- lib test` → çıktı boş.
Task 3 Step 1'deki JSON doğrulama komutunu tekrar çalıştır → `ok`.

- [ ] **Step 7: Run tests to verify they pass**

Run: `flutter test --no-pub test/features/nutrition`
Expected: PASS (nutrition klasöründeki tüm testler).

Bir test `capture_take_photo_button`'a dokunamazsa (kutu ekran dışında kaldıysa) dokunmadan önce `await tester.ensureVisible(find.byKey(const Key('capture_take_photo_button')));` ekle. Bu durum ancak test penceresi 800×600'den küçükse olur.

- [ ] **Step 8: Analyze and commit**

Run: `flutter analyze --no-pub` → "No issues found!"

```bash
git add lib/features/nutrition/presentation/widgets/food_item_edit_tile.dart lib/features/nutrition/presentation/meal_capture_screen.dart assets/translations/tr.json assets/translations/en.json test/features/nutrition/presentation/widgets/food_item_edit_tile_test.dart test/features/nutrition/presentation/meal_capture_screen_test.dart
git commit -m "feat(nutrition): redesign meal capture with photo preview and compact rows

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 6: Doğrulama, elle kontrol ve PLAN.md

**Files:**
- Modify: `PLAN.md` (sona tarihli satır)

- [ ] **Step 1: Static analysis**

Run: `flutter analyze --no-pub`
Expected: "No issues found!"

- [ ] **Step 2: Full test suite (user's terminal)**

Kullanıcıdan kendi terminalinde çalıştırmasını iste (bu makinede arka plan koşusu bellek yüzünden kesiliyor):

```
flutter test --no-pub -j 1
```

Expected: `All tests passed!`. Toplam test sayısını not et (R1 sonunda +351 idi; R2 net artışı yaklaşık +27).

- [ ] **Step 3: Release web build + manual check (user's terminal)**

Kullanıcıdan şunu iste: `flutter build web --release --no-pub`, ardından build'i her zamanki gibi kendi terminalinden sunması ve tarayıcıda önbelleği temizleyerek açması (R1'de eski `tr.json` önbellekte kalmıştı). Elle kontrol listesi:

1. Beslenme ekranı: tarih, KALAN kartı, bar, üç makro kutusu, öğün kartlarında ara toplam.
2. Hedef aşılınca AŞIM ve kırmızı rakam/bar (gerekirse test öğünüyle).
3. Boş gün: kart + "Bugün henüz öğün eklenmedi" ve ipucu.
4. Öğün ekle: öğün seçilmeden kutular soluk; seçilince neon çip ve aktif kutular.
5. Fotoğraf çek/seç → analiz → üstte önizleme ve "N yemek bulundu".
6. Satıra dokununca açılıp kapanıyor.
7. Gram değişince satırdaki kcal ve alttaki toplam güncelleniyor.
8. "Kontrol" rozetli yemekte kcal yazarken alanlar açık kalıyor, Kaydet aktif oluyor.
9. Kaydet → beslenme ekranına dönüş, yeni öğün listede.

- [ ] **Step 4: PLAN.md row and commit**

`PLAN.md` dosyasındaki tarihçe tablosunun son satırının altına, R1 satırının biçimiyle ekle (test sayısı ve elle kontrol sonucu Step 2–3'ten):

```
| 2026-10-04 | **F5+ R2 (beslenme ekranları) tamamlandı** (`r2-beslenme` dalı, 6 görev). Beslenme ekranı "kalan odaklı" düzende: tarih, KALAN/AŞIM/YENEN kartı (bar + protein/karb./yağ kutuları), öğün tipi başına ara toplamlı kartlar; boş günde kart kalır. Öğün ekleme: seçimde iki büyük kutu, düzeltmede fotoğraf önizleme, açılır yemek satırları, sabit toplam + Kaydet. Davranış düzeltmeleri: gram değişince kcal/makrolar orantılı güncellenir (gram başı oran istemcide tutulur, gram 0'a inse de kaybolmaz); "kontrol gerekli" yemekte ilk rakamda alanların kaybolması giderildi. `dayLabel` ortak yardımcıya çıkarıldı, `SectionHeader`'a `trailing` eklendi. Otomatik: <N> Flutter testi geçiyor (kullanıcının terminalinde `-j 1`), `flutter analyze` temiz. Manuel: <sonuç>. Sıradaki: R3 (antrenman ekranları). |
```

`<N>` ve `<sonuç>` yerine gerçek değerleri yaz.

```bash
git add PLAN.md
git commit -m "docs: record F5+ R2 verification

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

- [ ] **Step 5: Finish the branch**

superpowers:finishing-a-development-branch becerisiyle devam et (R1'de: yerelde master'a fast-forward, dal silindi, kullanıcı onayıyla push).
