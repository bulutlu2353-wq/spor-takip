# F5+ R4a — İlerleme Ekranları Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Kilo, güç ve ölçüler ekranlarını "büyük sayı üstte" düzenine (güncel değer + aralıktaki değişim, grafik kartı, kayıt listesi) geçirmek.

**Architecture:** Yalnız sunum katmanı değişir. `trend.dart`'a saf `changeInRange` eklenir; `historyDateLabel` `lib/shared/date_label.dart`'a `shortDateLabel` olarak taşınır. İki yeni ilerleme bileşeni (`ProgressHero`, `ChartCard`) üç ekranda ortak kullanılır; `RangeSelector` silinir. Provider, servis, diyalog ve kayıt mantığı değişmez.

**Tech Stack:** Flutter, Riverpod 3, easy_localization, fl_chart, flutter_test.

**Spec:** `docs/superpowers/specs/2026-10-05-f5plus-r4a-ilerleme-design.md` (çerçeve: `docs/superpowers/specs/2026-10-03-f5plus-r1-tasarim-temeli-design.md` §3–§4)

## Global Constraints

- Düşük bellekli makine: görev içinde sadece ilgili test dosyaları çalıştırılır (`flutter test --no-pub <dosyalar>`). Tam paketi kullanıcı kendi terminalinde çalıştırır (`flutter test --no-pub -j 1`, Task 5). `flutter analyze --no-pub` birkaç dakika sürebilir; gerekirse arka planda çalıştır.
- `flutter analyze --no-pub` "No issues found!" vermeli (info dahil). `dart format` çalıştırılmaz (projede satır genişliği ayarı yok; dosyaları 80 sütuna göre yeniden sarar), mevcut biçime elle uyulur. `await`'ten sonra `context` kullanmadan önce `mounted` / `context.mounted` kontrolü yapılır.
- Widget testlerinde `.tr()` çıktısına güvenilmez; test yerel ayarı `en`. Bulma işi `Key`, ikon ya da veri metniyle yapılır. Çevrilmiş metin karşılaştırması gerekiyorsa beklenen değer testte de `.tr()` ile üretilir.
- Ekran/bileşen kodunda elle renk (`Color(0x…)`, `Colors.x`) yazılmaz. Renkler `Theme.of(context).colorScheme`'den: vurgu = `primary`, ana metin = `onSurface`, ikincil metin = `onSurfaceVariant`, kutu zemini = `surfaceContainer`. Testlerde beklenen renkler `AppColors.accent` (= `primary`) ve `AppColors.muted` (= `onSurfaceVariant`).
- Başlık yazı tipi `AppFonts.heading`; temadaki `displaySmall` zaten Montserrat 900. Büyük harfe çevirme yalnız `upperCaseFor(text, languageCode)` ile (`lib/shared/text_case.dart`).
- Fark metni mevcut `formatDelta` ile: `▼ 2`, `▲ 3.3`, `0`, null → `—` (`lib/features/progress/domain/progress_format.dart`).
- Korunan anahtarlar (testler kullanıyor): `weight_screen`, `weight_screen_add`, `weight_chart`, `weight_empty`, `weight_log_<yyyy-mm-dd>`, `weight_delete_<yyyy-mm-dd>`, `confirm_delete_button`, `strength_screen`, `strength_exercise_picker`, `strength_chart`, `strength_empty`, `measurements_screen`, `measurements_screen_add`, `measurement_chart`, `measurements_empty`, `site_chip_<site>`, `measurement_row_<yyyy-mm-dd>`, `measurement_delete_<yyyy-mm-dd>`, `range_<month|threeMonths|year|all>`, `history_*`.
- Commit mesajları İngilizce, `feat(progress): …` biçiminde. Sonuna boş satır + `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.

## Spec'ten küçük netleştirmeler (kullanıcıya bildirilecek)

1. Kısa aralık çevirilerinin alt anahtarları `ChartRange` adlarıyla aynı: `progress.range_short.month` / `threeMonths` / `year` / `all` (spec'te `three_months` yazıyordu); çip kodu `'progress.range_short.${range.name}'` ile okur.
2. Değişim metnindeki fark, uygulamanın her yerindeki gibi okla yazılır: "▼ 2 kg · 3 ay" (spec'teki "−1,6 kg" örneği yerine `formatDelta`).
3. Aralık çipleri dar ekranda tek satıra sığmazsa ikinci satıra kayar (çipler `Flexible` + sağa yaslı `Wrap` içinde); taşma hatası olmaz.
4. Değişim metnini kuran `rangeChangeLabel(...)` ve aralık etiketi `rangeLabelKey(...)` `progress_hero.dart`'ta durur (silinen `RangeSelector`'daki eşleme buraya taşınır).

## Dosya Haritası

```
lib/features/progress/domain/trend.dart                          # Task 1 (changeInRange)
lib/shared/date_label.dart                                       # Task 1 (yeni: shortDateLabel)
lib/features/workout/presentation/history_screen.dart            # Task 1 (historyDateLabel kalkar)
lib/features/workout/presentation/history_detail_screen.dart     # Task 1
lib/features/progress/presentation/widgets/progress_hero.dart    # Task 2 (yeni: ProgressHero, rangeChangeLabel, rangeLabelKey)
lib/features/progress/presentation/widgets/chart_card.dart       # Task 2 (yeni)
assets/translations/tr.json, en.json                             # Task 2 (ekleme), Task 4 (silme)
lib/features/progress/presentation/weight_screen.dart            # Task 3 (yeniden yazım)
lib/features/progress/presentation/strength_screen.dart          # Task 4
lib/features/progress/presentation/measurements_screen.dart      # Task 4
lib/features/progress/presentation/widgets/range_selector.dart   # Task 4 (silinir)
PLAN.md                                                          # Task 5

test/features/progress/domain/trend_test.dart                    # Task 1
test/shared/date_label_test.dart                                 # Task 1 (yeni)
test/features/progress/presentation/widgets/progress_hero_test.dart  # Task 2 (yeni)
test/features/progress/presentation/widgets/chart_widgets_test.dart  # Task 2 (ChartCard), Task 4 (RangeSelector testi silinir)
test/features/progress/presentation/weight_test.dart             # Task 3
test/features/progress/presentation/strength_test.dart           # Task 4
test/features/progress/presentation/measurements_test.dart       # Task 4
```

---

### Task 1: `changeInRange` ve ortak kısa tarih

**Files:**
- Modify: `lib/features/progress/domain/trend.dart`, `lib/features/workout/presentation/history_screen.dart`, `lib/features/workout/presentation/history_detail_screen.dart`
- Create: `lib/shared/date_label.dart`
- Test: `test/features/progress/domain/trend_test.dart`, `test/shared/date_label_test.dart`

**Interfaces:**
- Produces: `double? changeInRange(List<ValuePoint> points)` (`trend.dart`); `String shortDateLabel(DateTime date, DateTime now)` (`lib/shared/date_label.dart`). `historyDateLabel` kaldırılır.

- [ ] **Step 1: Write the failing tests**

`test/features/progress/domain/trend_test.dart` içinde `main()`'in kapanış `}`'inden hemen önce ekle:

```dart

  group('changeInRange', () {
    test('needs two points, then last minus first', () {
      expect(changeInRange(const <ValuePoint>[]), isNull);
      expect(changeInRange([_p(9, 1, 80)]), isNull);
      expect(changeInRange([_p(8, 1, 82), _p(9, 1, 81), _p(9, 20, 80)]), -2);
    });
  });
```

Yeni dosya `test/shared/date_label_test.dart`:

```dart
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spor_takip/shared/date_label.dart';

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  final now = DateTime(2026, 10, 5);

  test('day and month, the year only when it differs', () {
    expect(shortDateLabel(DateTime(2026, 10, 4), now), '4 ${'home.month_10'.tr()}');
    expect(shortDateLabel(DateTime(2025, 12, 30), now), '30 ${'home.month_12'.tr()} 2025');
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test --no-pub test/features/progress/domain/trend_test.dart test/shared/date_label_test.dart`
Expected: derleme hatası — `changeInRange` ve `package:spor_takip/shared/date_label.dart` yok.

- [ ] **Step 3: Implement**

`lib/features/progress/domain/trend.dart` içinde `pointsInRange` tanımının altına ekle:

```dart

/// [points] aralığa süzülmüş, eskiden yeniye: son − ilk. 2'den az nokta → null.
double? changeInRange(List<ValuePoint> points) =>
    points.length < 2 ? null : points.last.value - points.first.value;
```

Yeni dosya `lib/shared/date_label.dart`:

```dart
import 'package:easy_localization/easy_localization.dart';

/// "4 Ekim"; yıl [now]'ınkinden farklıysa "30 Aralık 2025".
String shortDateLabel(DateTime date, DateTime now) {
  final d = date.toLocal();
  final label = '${d.day} ${'home.month_${d.month}'.tr()}';
  return d.year == now.year ? label : '$label ${d.year}';
}
```

`lib/features/workout/presentation/history_screen.dart`:
- Importlara `import '../../../shared/date_label.dart';` ekle (`import '../../../core/theme/app_fonts.dart';` satırının altına).
- Şu bloğu sil:

```dart
/// "4 Ekim"; yıl [now]'ınkinden farklıysa "30 Aralık 2025".
String historyDateLabel(DateTime startedAt, DateTime now) {
  final d = startedAt.toLocal();
  final label = '${d.day} ${'home.month_${d.month}'.tr()}';
  return d.year == now.year ? label : '$label ${d.year}';
}

```

- `historyListSubtitle` içinde `historyDateLabel(session.startedAt, now)` → `shortDateLabel(session.startedAt, now)`.

`lib/features/workout/presentation/history_detail_screen.dart`:
- `import 'history_screen.dart';` satırını sil (yalnız `historyDateLabel` için vardı) ve `import '../../../shared/text_case.dart';` satırının üstüne `import '../../../shared/date_label.dart';` ekle.
- `historyDateLabel(session.startedAt, now)` → `shortDateLabel(session.startedAt, now)`.

Run: `grep -rn "historyDateLabel" lib test`
Expected: çıktı yok.

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test --no-pub test/features/progress/domain/trend_test.dart test/shared/date_label_test.dart test/features/workout/presentation/history_screen_test.dart`
Expected: PASS.

Run: `flutter analyze --no-pub`
Expected: No issues found!

- [ ] **Step 5: Commit**

```bash
git add lib/features/progress/domain/trend.dart lib/shared/date_label.dart lib/features/workout/presentation/history_screen.dart lib/features/workout/presentation/history_detail_screen.dart test/features/progress/domain/trend_test.dart test/shared/date_label_test.dart
git commit -m "feat(progress): add range change helper and shared short date label

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 2: `ProgressHero`, `ChartCard` ve çeviriler

**Files:**
- Create: `lib/features/progress/presentation/widgets/progress_hero.dart`, `lib/features/progress/presentation/widgets/chart_card.dart`
- Modify: `assets/translations/tr.json`, `assets/translations/en.json`
- Test: `test/features/progress/presentation/widgets/progress_hero_test.dart` (yeni), `test/features/progress/presentation/widgets/chart_widgets_test.dart`

**Interfaces:**
- Consumes: `AccentChip({key, required String label, required bool selected, required ValueChanged<bool> onSelected})` (`lib/shared/widgets/accent_chip.dart`); `ChartRange`, `formatDelta`.
- Produces:
  - `ProgressHero({Key? key, required String label, required String value, required String unit, String? change, bool highlight = false, Key? valueKey, Key? changeKey})`
  - `String rangeLabelKey(ChartRange range)` → `'progress.range.month'` vb.
  - `String? rangeChangeLabel(double? change, String unit, ChartRange range)` → `"▼ 2 kg · 3 ay"`; `change == null` → `null`.
  - `ChartCard({Key? key, required ChartRange range, required ValueChanged<ChartRange> onRangeChanged, required Widget chart})`; çip anahtarları `range_${range.name}`.
  - Çeviri anahtarları: `progress.trend`, `progress.records`, `progress.change_in_range`, `progress.range_short.*`, `progress.weight.current`, `progress.strength.estimated_1rm`.

- [ ] **Step 1: Write the failing tests**

Yeni dosya `test/features/progress/presentation/widgets/progress_hero_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spor_takip/core/theme/app_colors.dart';
import 'package:spor_takip/features/progress/presentation/widgets/progress_hero.dart';

import '../../../../shared/widgets/themed.dart';

void main() {
  testWidgets('shows the upper-cased label, the value and a highlighted change', (tester) async {
    await tester.pumpWidget(themed(const ProgressHero(
      label: 'Current',
      value: '78.4',
      unit: 'kg',
      change: '▼ 1.6 kg · 3 mo',
      highlight: true,
      valueKey: Key('v'),
      changeKey: Key('c'),
    )));

    expect(find.text('CURRENT'), findsOneWidget);
    expect(tester.widget<Text>(find.byKey(const Key('v'))).data, '78.4');
    expect(find.text('kg'), findsOneWidget);
    expect(tester.widget<Text>(find.byKey(const Key('c'))).style!.color, AppColors.accent);
  });

  testWidgets('a plain change is muted and a missing change is not drawn', (tester) async {
    await tester.pumpWidget(themed(const Column(children: [
      ProgressHero(label: 'A', value: '1', unit: 'kg', change: '▲ 1 kg · 3 mo', changeKey: Key('muted')),
      ProgressHero(label: 'B', value: '2', unit: 'kg', changeKey: Key('none')),
    ])));

    expect(tester.widget<Text>(find.byKey(const Key('muted'))).style!.color, AppColors.muted);
    expect(find.byKey(const Key('none')), findsNothing);
  });
}
```

`test/features/progress/presentation/widgets/chart_widgets_test.dart` içinde:
- Importlara ekle: `import 'package:spor_takip/features/progress/presentation/widgets/chart_card.dart';`
- `'range selector reports the tapped range'` testinin altına ekle:

```dart

  testWidgets('chart card shows the chart and reports the tapped range', (tester) async {
    ChartRange? picked;
    await tester.pumpWidget(_wrap(ChartCard(
      range: ChartRange.threeMonths,
      onRangeChanged: (r) => picked = r,
      chart: const SizedBox(key: Key('chart'), height: 50),
    )));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('chart')), findsOneWidget);
    expect(find.byKey(const Key('range_all')), findsOneWidget);
    await tester.tap(find.byKey(const Key('range_year')));
    await tester.pumpAndSettle();
    expect(picked, ChartRange.year);
  });
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test --no-pub test/features/progress/presentation/widgets/progress_hero_test.dart test/features/progress/presentation/widgets/chart_widgets_test.dart`
Expected: derleme hatası — `progress_hero.dart` ve `chart_card.dart` yok.

- [ ] **Step 3: Add translations**

`assets/translations/tr.json` içinde:

```json
    "change_30d": "30 gün: {value}",
```

satırının altına ekle:

```json
    "change_in_range": "{delta} · {range}",
    "trend": "Trend",
    "records": "Kayıtlar",
    "range_short": {
      "month": "1A",
      "threeMonths": "3A",
      "year": "1Y",
      "all": "Tümü"
    },
```

Aynı dosyada `"stale": "Liste güncellendi, tekrar dene"` satırını şununla değiştir:

```json
      "stale": "Liste güncellendi, tekrar dene",
      "current": "Güncel"
```

ve `"estimated_note": "Tahmini 1RM (Epley): …"` satırının (sonunda virgül yok) üstüne ekle:

```json
      "estimated_1rm": "Tahmini 1RM",
```

`assets/translations/en.json` içinde aynı yerlere:

```json
    "change_30d": "30 days: {value}",
```

altına:

```json
    "change_in_range": "{delta} · {range}",
    "trend": "Trend",
    "records": "Records",
    "range_short": {
      "month": "1M",
      "threeMonths": "3M",
      "year": "1Y",
      "all": "All"
    },
```

`"stale": "The list was updated, try again"` →

```json
      "stale": "The list was updated, try again",
      "current": "Current"
```

`"estimated_note": "Estimated 1RM (Epley): …"` satırının üstüne:

```json
      "estimated_1rm": "Estimated 1RM",
```

JSON doğrulaması (iki dosya da `ok` vermeli):

```powershell
foreach ($f in 'assets/translations/tr.json','assets/translations/en.json') { Get-Content $f -Raw -Encoding utf8 | ConvertFrom-Json | Out-Null; "ok $f" }
```

- [ ] **Step 4: Create `progress_hero.dart`**

`lib/features/progress/presentation/widgets/progress_hero.dart`:

```dart
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../shared/text_case.dart';
import '../../domain/progress_format.dart';
import '../../domain/trend.dart';

String rangeLabelKey(ChartRange range) => switch (range) {
      ChartRange.month => 'progress.range.month',
      ChartRange.threeMonths => 'progress.range.three_months',
      ChartRange.year => 'progress.range.year',
      ChartRange.all => 'progress.range.all',
    };

/// "▼ 2 kg · 3 ay"; [change] null → null (satır çizilmez).
String? rangeChangeLabel(double? change, String unit, ChartRange range) {
  if (change == null) return null;
  return 'progress.change_in_range'.tr(namedArgs: {
    'delta': '${formatDelta(change)} $unit',
    'range': rangeLabelKey(range).tr(),
  });
}

/// İlerleme ekranlarının üstündeki büyük sayı: etiket, değer + birim, değişim.
class ProgressHero extends StatelessWidget {
  const ProgressHero({
    super.key,
    required this.label,
    required this.value,
    required this.unit,
    this.change,
    this.highlight = false,
    this.valueKey,
    this.changeKey,
  });

  final String label;
  final String value;
  final String unit;

  /// Hazır değişim metni; null ise satır çizilmez.
  final String? change;

  /// Değişim olumlu mu (vurgu rengi)?
  final bool highlight;
  final Key? valueKey;
  final Key? changeKey;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final change = this.change;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          upperCaseFor(label, Localizations.localeOf(context).languageCode),
          style: theme.textTheme.labelMedium?.copyWith(color: scheme.onSurfaceVariant, letterSpacing: 1),
        ),
        const SizedBox(height: 2),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(value, key: valueKey, style: theme.textTheme.displaySmall),
            const SizedBox(width: 6),
            Text(unit, style: theme.textTheme.titleMedium?.copyWith(color: scheme.onSurfaceVariant)),
          ],
        ),
        if (change != null) ...[
          const SizedBox(height: 4),
          Text(
            change,
            key: changeKey,
            style: theme.textTheme.bodySmall?.copyWith(
              color: highlight ? scheme.primary : scheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );
  }
}
```

- [ ] **Step 5: Create `chart_card.dart`**

`lib/features/progress/presentation/widgets/chart_card.dart`:

```dart
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../shared/text_case.dart';
import '../../../../shared/widgets/accent_chip.dart';
import '../../domain/trend.dart';

/// "TREND" başlığı, sağda aralık çipleri, altında grafik.
class ChartCard extends StatelessWidget {
  const ChartCard({super.key, required this.range, required this.onRangeChanged, required this.chart});

  final ChartRange range;
  final ValueChanged<ChartRange> onRangeChanged;
  final Widget chart;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text(
                  upperCaseFor('progress.trend'.tr(), Localizations.localeOf(context).languageCode),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(width: 8),
                // Dar ekranda çipler ikinci satıra kayar.
                Flexible(
                  child: Wrap(
                    alignment: WrapAlignment.end,
                    spacing: 4,
                    runSpacing: 4,
                    children: [
                      for (final r in ChartRange.values)
                        AccentChip(
                          key: Key('range_${r.name}'),
                          label: 'progress.range_short.${r.name}'.tr(),
                          selected: r == range,
                          onSelected: (_) => onRangeChanged(r),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            chart,
          ],
        ),
      ),
    );
  }
}
```

`Text` (TREND) `Row` içinde esnek değil; `Flexible` + `Wrap` kalan genişliği alır. `Row`'un `mainAxisAlignment`'ı varsayılan (`start`); `Wrap` sağa yaslandığı için çipler sağda durur.

- [ ] **Step 6: Run tests to verify they pass**

Run: `flutter test --no-pub test/features/progress/presentation/widgets/progress_hero_test.dart test/features/progress/presentation/widgets/chart_widgets_test.dart`
Expected: PASS (hero 2, chart widgets 4).

Run: `flutter analyze --no-pub`
Expected: No issues found!

- [ ] **Step 7: Commit**

```bash
git add assets/translations/tr.json assets/translations/en.json lib/features/progress/presentation/widgets/progress_hero.dart lib/features/progress/presentation/widgets/chart_card.dart test/features/progress/presentation/widgets/progress_hero_test.dart test/features/progress/presentation/widgets/chart_widgets_test.dart
git commit -m "feat(progress): add progress hero and chart card widgets

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 3: Kilo ekranı

**Files:**
- Rewrite: `lib/features/progress/presentation/weight_screen.dart`
- Test: `test/features/progress/presentation/weight_test.dart`

**Interfaces:**
- Consumes: `ProgressHero`, `rangeChangeLabel`, `ChartCard` (Task 2); `changeInRange` (Task 1); `shortDateLabel` (Task 1); `weightChangeIsGood(double change, Goal goal)` (`widgets/home_stat_grid.dart`); `profileProvider` (`FutureProvider<Profile?>`, `lib/features/onboarding/application/profile_providers.dart`).
- Produces: yeni anahtarlar `weight_current`, `weight_change`, `weight_delta_<yyyy-mm-dd>`.

- [ ] **Step 1: Write the failing tests**

`test/features/progress/presentation/weight_test.dart` importlarına ekle:

```dart
import 'package:easy_localization/easy_localization.dart';
import 'package:spor_takip/core/theme/app_colors.dart';
import 'package:spor_takip/features/onboarding/domain/profile.dart';
import 'package:spor_takip/shared/date_label.dart';
```

(`easy_localization` ilk satıra, diğerleri `package:spor_takip/...` importları arasına alfabetik sırayla.)

`group('screen', ...)` içinde, `'tapping an entry edits its weight with the date fixed'` testinin altına ekle:

```dart

    testWidgets('shows the latest weight, the change in range and per-entry differences', (tester) async {
      await pumpScreen(tester);

      Text text(String key) => tester.widget<Text>(find.byKey(Key(key)));
      expect(text('weight_current').data, '80');
      expect(
        text('weight_change').data,
        'progress.change_in_range'.tr(namedArgs: {'delta': '▼ 2 kg', 'range': 'progress.range.three_months'.tr()}),
      );
      // Test profilinin hedefi kas kazanmak: düşüş olumlu sayılmaz.
      expect(text('weight_change').style!.color, AppColors.muted);
      expect(text('weight_delta_2026-09-20').data, '▼ 2');
      expect(find.byKey(const Key('weight_delta_2026-08-01')), findsNothing);
      expect(find.text(shortDateLabel(DateTime(2026, 9, 20), _now)), findsOneWidget);
    });

    testWidgets('a loss is highlighted when the goal is losing weight', (tester) async {
      await tester.pumpWidget(testApp(
        const WeightScreen(),
        overrides: [
          bodyWeightRepositoryProvider.overrideWithValue(repo),
          profileProvider.overrideWith((ref) async => testProfile.copyWith(goal: Goal.loseWeight)),
          nowProvider.overrideWithValue(() => _now),
        ],
        scaffold: false,
      ));
      await tester.pumpAndSettle();

      Color? color(String key) => tester.widget<Text>(find.byKey(Key(key))).style!.color;
      expect(color('weight_change'), AppColors.accent);
      expect(color('weight_delta_2026-09-20'), AppColors.accent);
    });
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test --no-pub test/features/progress/presentation/weight_test.dart`
Expected: 2 yeni test FAIL (`weight_current` bulunamıyor); eski 7 test PASS.

- [ ] **Step 3: Rewrite the screen**

`lib/features/progress/presentation/weight_screen.dart` dosyasının tamamını şununla değiştir:

```dart
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/date_label.dart';
import '../../../shared/widgets/section_header.dart';
import '../../onboarding/application/profile_providers.dart';
import '../../onboarding/domain/profile.dart';
import '../../workout/application/session_providers.dart';
import '../application/body_weight_service.dart';
import '../application/progress_providers.dart';
import '../data/body_weight_repository.dart';
import '../domain/body_weight_log.dart';
import '../domain/progress_format.dart';
import '../domain/trend.dart';
import 'widgets/card_states.dart';
import 'widgets/chart_card.dart';
import 'widgets/home_stat_grid.dart' show weightChangeIsGood;
import 'widgets/progress_hero.dart';
import 'widgets/progress_line_chart.dart';
import 'widgets/weight_log_dialog.dart';

class WeightScreen extends ConsumerStatefulWidget {
  const WeightScreen({super.key});

  @override
  ConsumerState<WeightScreen> createState() => _WeightScreenState();
}

class _WeightScreenState extends ConsumerState<WeightScreen> {
  ChartRange _range = ChartRange.threeMonths;

  /// Fark kullanıcının amacına göre olumlu mu? Profil yoksa hayır.
  static bool _isGood(double? delta, Goal? goal) =>
      delta != null && goal != null && weightChangeIsGood(delta, goal);

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

  Widget _list(List<BodyWeightLog> logs, DateTime now, Goal? goal) {
    if (logs.isEmpty) {
      return Center(child: Text('progress.weight.empty'.tr(), key: const Key('weight_empty')));
    }
    final points = [for (final log in logs) ValuePoint(log.date, log.weightKg)];
    final inRange = pointsInRange(points, _range, now);
    final change = changeInRange(inRange);
    final canDelete = logs.length > 1;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
      children: [
        ProgressHero(
          label: 'progress.weight.current'.tr(),
          value: formatOneDecimal(logs.last.weightKg),
          unit: 'kg',
          change: rangeChangeLabel(change, 'kg', _range),
          highlight: _isGood(change, goal),
          valueKey: const Key('weight_current'),
          changeKey: const Key('weight_change'),
        ),
        const SizedBox(height: 16),
        ChartCard(
          range: _range,
          onRangeChanged: (range) => setState(() => _range = range),
          chart: ProgressLineChart(key: const Key('weight_chart'), points: inRange),
        ),
        SectionHeader('progress.records'.tr()),
        Card(
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              // Yeniden eskiye; fark bir önceki (daha eski) kayda göre.
              for (var i = logs.length - 1; i >= 0; i--) ...[
                if (i < logs.length - 1) const Divider(height: 1),
                _row(
                  logs[i],
                  delta: i > 0 ? logs[i].weightKg - logs[i - 1].weightKg : null,
                  now: now,
                  goal: goal,
                  canDelete: canDelete,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _row(
    BodyWeightLog log, {
    required double? delta,
    required DateTime now,
    required Goal? goal,
    required bool canDelete,
  }) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final day = formatDbDate(log.date);
    return InkWell(
      key: Key('weight_log_$day'),
      onTap: () => showWeightLogDialog(context, existing: log),
      child: Padding(
        padding: const EdgeInsets.only(left: 16),
        child: Row(
          children: [
            Text(
              '${formatOneDecimal(log.weightKg)} kg',
              style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(width: 12),
            if (delta != null)
              Text(
                formatDelta(delta),
                key: Key('weight_delta_$day'),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: _isGood(delta, goal) ? scheme.primary : scheme.onSurfaceVariant,
                ),
              ),
            const Spacer(),
            Text(
              shortDateLabel(log.date, now),
              style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
            IconButton(
              key: Key('weight_delete_$day'),
              icon: const Icon(Icons.delete_outline),
              color: scheme.onSurfaceVariant,
              tooltip: (canDelete ? 'progress.delete' : 'progress.weight.last_log_hint').tr(),
              onPressed: canDelete ? () => _delete(log) : null,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final logsAsync = ref.watch(weightLogsProvider);
    final goal = ref.watch(profileProvider).value?.goal;
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
        data: (logs) => _list(logs, now, goal),
      ),
    );
  }
}
```

Not: `weightLogsProvider` kayıtları eskiden yeniye döndürür (grafik ve eski kod `logs.reversed` ile buna dayanıyordu); `logs.last` en yeni kayıttır.

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test --no-pub test/features/progress/presentation/weight_test.dart`
Expected: PASS (9 test).

Run: `flutter analyze --no-pub`
Expected: No issues found!

- [ ] **Step 5: Commit**

```bash
git add lib/features/progress/presentation/weight_screen.dart test/features/progress/presentation/weight_test.dart
git commit -m "feat(progress): redesign weight screen with current value and record list

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 4: Güç ve ölçüler ekranları, `RangeSelector`'ın kaldırılması

**Files:**
- Modify: `lib/features/progress/presentation/strength_screen.dart`, `lib/features/progress/presentation/measurements_screen.dart`, `assets/translations/tr.json`, `assets/translations/en.json`, `test/features/progress/presentation/widgets/chart_widgets_test.dart`
- Delete: `lib/features/progress/presentation/widgets/range_selector.dart`
- Test: `test/features/progress/presentation/strength_test.dart`, `test/features/progress/presentation/measurements_test.dart`

**Interfaces:**
- Consumes: `ProgressHero`, `rangeChangeLabel`, `ChartCard` (Task 2); `changeInRange`, `shortDateLabel` (Task 1); `AccentChip`; `SectionHeader`.
- Produces: yeni anahtarlar `strength_current`, `strength_change`, `measurement_current`, `measurement_change`.

- [ ] **Step 1: Write the failing tests**

`test/features/progress/presentation/strength_test.dart` importlarına ekle (`easy_localization` en üste, diğerleri alfabetik):

```dart
import 'package:easy_localization/easy_localization.dart';
import 'package:spor_takip/core/theme/app_colors.dart';
```

`'empty state'` testinin üstüne ekle:

```dart
    testWidgets('shows the latest estimate; a drop is not highlighted', (tester) async {
      await pumpScreen(tester);

      Text text(String key) => tester.widget<Text>(find.byKey(Key(key)));
      // Squat: 20 Ağu 100 × 5 ≈ 116.7, 25 Eyl 110 × 1 = 110.
      expect(text('strength_current').data, '110');
      expect(
        text('strength_change').data,
        'progress.change_in_range'.tr(namedArgs: {'delta': '▼ 6.7 kg', 'range': 'progress.range.three_months'.tr()}),
      );
      expect(text('strength_change').style!.color, AppColors.muted);
    });

    testWidgets('a gain is highlighted', (tester) async {
      data.sessions.add(finishedSession('c', DateTime(2026, 9, 27), [doneSet('squat', kg: 120, reps: 1)]));
      await pumpScreen(tester);

      expect(tester.widget<Text>(find.byKey(const Key('strength_change'))).style!.color, AppColors.accent);
    });

```

`test/features/progress/presentation/measurements_test.dart` importlarına ekle:

```dart
import 'package:easy_localization/easy_localization.dart';
import 'package:spor_takip/core/theme/app_colors.dart';
import 'package:spor_takip/shared/date_label.dart';
```

`group('screen', ...)` içinde `'tapping a row edits it with its values'` testinin altına ekle:

```dart

    testWidgets('shows the latest value of the site; the change is never highlighted', (tester) async {
      await pumpScreen(tester);

      Text text(String key) => tester.widget<Text>(find.byKey(Key(key)));
      expect(text('measurement_current').data, '83');
      expect(
        text('measurement_change').data,
        'progress.change_in_range'.tr(namedArgs: {'delta': '▼ 2 cm', 'range': 'progress.range.three_months'.tr()}),
      );
      expect(text('measurement_change').style!.color, AppColors.muted);
      expect(find.text(shortDateLabel(DateTime(2026, 9, 20), _now)), findsOneWidget);
    });
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test --no-pub test/features/progress/presentation/strength_test.dart test/features/progress/presentation/measurements_test.dart`
Expected: 3 yeni test FAIL (`strength_current` / `measurement_current` bulunamıyor); eski testler PASS.

- [ ] **Step 3: Update `strength_screen.dart`**

Importlarda `import 'widgets/range_selector.dart';` satırını şu iki satırla değiştir (alfabetik sıra: `card_states` → `chart_card` → `progress_hero` → `progress_line_chart`):

```dart
import 'widgets/chart_card.dart';
import 'widgets/progress_hero.dart';
```

`import 'widgets/chart_card.dart';` `import 'widgets/card_states.dart';` satırının hemen altına, `import 'widgets/progress_hero.dart';` `import 'widgets/progress_line_chart.dart';` satırının hemen üstüne gelecek.

`_content` fonksiyonunun tamamını şununla değiştir:

```dart
  Widget _content(List<StrengthSeries> all, DateTime now) {
    if (all.isEmpty) {
      return Center(child: Text('progress.strength.empty'.tr(), key: const Key('strength_empty')));
    }
    final selected = all.firstWhere((s) => s.exerciseId == _exerciseId, orElse: () => all.first);
    final points = [for (final p in selected.points) if (isInRange(p.date, _range, now)) p];
    final values = [for (final p in points) ValuePoint(p.date, p.estimateKg)];
    final change = changeInRange(values);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        DecoratedBox(
          decoration: BoxDecoration(color: scheme.surfaceContainer, borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: DropdownButton<String>(
              key: const Key('strength_exercise_picker'),
              value: selected.exerciseId,
              isExpanded: true,
              underline: const SizedBox.shrink(),
              items: [
                for (final s in all)
                  DropdownMenuItem(
                    value: s.exerciseId,
                    child: Text(s.exerciseName, overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: (id) => setState(() => _exerciseId = id),
            ),
          ),
        ),
        const SizedBox(height: 16),
        ProgressHero(
          label: 'progress.strength.estimated_1rm'.tr(),
          value: formatOneDecimal(selected.points.last.estimateKg),
          unit: 'kg',
          change: rangeChangeLabel(change, 'kg', _range),
          highlight: change != null && change > 0,
          valueKey: const Key('strength_current'),
          changeKey: const Key('strength_change'),
        ),
        const SizedBox(height: 16),
        ChartCard(
          range: _range,
          onRangeChanged: (range) => setState(() => _range = range),
          chart: ProgressLineChart(
            key: const Key('strength_chart'),
            points: values,
            tooltipLabel: (index) => _tooltip(points[index]),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'progress.strength.estimated_note'.tr(),
          style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
        ),
      ],
    );
  }
```

- [ ] **Step 4: Update `measurements_screen.dart`**

Importlarda:
- `import '../../workout/application/session_providers.dart';` satırının üstüne ekle:

```dart
import '../../../shared/date_label.dart';
import '../../../shared/widgets/accent_chip.dart';
import '../../../shared/widgets/section_header.dart';
```

- `import 'widgets/range_selector.dart';` satırını sil; `import 'widgets/card_states.dart';` altına `import 'widgets/chart_card.dart';`, `import 'widgets/measurement_form_dialog.dart';` altına `import 'widgets/progress_hero.dart';` ekle.

`_content` fonksiyonunun tamamını şununla değiştir ve hemen altına `_row` fonksiyonunu ekle:

```dart
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
    final inRange = pointsInRange(points, _range, now);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final s in sites)
              AccentChip(
                key: Key('site_chip_${s.name}'),
                label: 'progress.sites.${s.name}'.tr(),
                selected: s == site,
                onSelected: (_) => setState(() => _site = s),
              ),
          ],
        ),
        const SizedBox(height: 16),
        // Hangi yönün iyi olduğu bölgeye ve amaca bağlı: değişim hep gri.
        ProgressHero(
          label: 'progress.sites.${site.name}'.tr(),
          value: formatOneDecimal(points.last.value),
          unit: 'cm',
          change: rangeChangeLabel(changeInRange(inRange), 'cm', _range),
          valueKey: const Key('measurement_current'),
          changeKey: const Key('measurement_change'),
        ),
        const SizedBox(height: 16),
        ChartCard(
          range: _range,
          onRangeChanged: (range) => setState(() => _range = range),
          chart: ProgressLineChart(key: const Key('measurement_chart'), points: inRange),
        ),
        SectionHeader('progress.records'.tr()),
        Card(
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (final (index, m) in list.reversed.indexed) ...[
                if (index > 0) const Divider(height: 1),
                _row(m, now),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _row(BodyMeasurement m, DateTime now) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final day = formatDbDate(m.date);
    return InkWell(
      key: Key('measurement_row_$day'),
      onTap: () => showMeasurementForm(context, existing: m),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 0, 8),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    shortDateLabel(m.date, now),
                    style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  Text(_summary(m), style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
                ],
              ),
            ),
            IconButton(
              key: Key('measurement_delete_$day'),
              icon: const Icon(Icons.delete_outline),
              color: scheme.onSurfaceVariant,
              tooltip: 'progress.delete'.tr(),
              onPressed: () => _delete(m),
            ),
          ],
        ),
      ),
    );
  }
```

- [ ] **Step 5: Remove `RangeSelector` and the unused translation**

Run: `grep -rn "RangeSelector\|range_selector" lib test`
Expected: yalnız `range_selector.dart`'ın kendisi ve `chart_widgets_test.dart`.

- Dosyayı sil: `git rm lib/features/progress/presentation/widgets/range_selector.dart`
- `test/features/progress/presentation/widgets/chart_widgets_test.dart`: `import 'package:spor_takip/features/progress/presentation/widgets/range_selector.dart';` satırını ve `'range selector reports the tapped range'` testinin tamamını (önündeki boş satırla) sil.

Run: `grep -rn "progress.strength.exercise'" lib test`
Expected: çıktı yok.

`assets/translations/tr.json`'dan `      "exercise": "Hareket",` satırını, `assets/translations/en.json`'dan `      "exercise": "Exercise",` satırını sil (ikisi de `"strength"` bloğunda; başka `"exercise"` anahtarına dokunma — silmeden önce satır numarasını `grep -n` ile `"strength": {` bloğu içinde olduğunu doğrula). JSON doğrulaması: Task 2 Step 3'teki `powershell` komutu → iki `ok`.

- [ ] **Step 6: Run tests to verify they pass**

Run: `flutter test --no-pub test/features/progress/presentation/strength_test.dart test/features/progress/presentation/measurements_test.dart test/features/progress/presentation/widgets/chart_widgets_test.dart`
Expected: PASS.

Run: `flutter analyze --no-pub`
Expected: No issues found!

- [ ] **Step 7: Commit**

```bash
git add -A lib/features/progress/presentation assets/translations/tr.json assets/translations/en.json test/features/progress/presentation
git commit -m "feat(progress): redesign strength and measurement screens

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 5: Doğrulama, elle kontrol ve PLAN.md

**Files:**
- Modify: `PLAN.md` (sona tarihli satır)

- [ ] **Step 1: Static analysis**

Run: `flutter analyze --no-pub`
Expected: "No issues found!"

- [ ] **Step 2: Full test suite (user's terminal)**

Kullanıcıdan kendi terminalinde çalıştırmasını iste:

```
flutter test --no-pub -j 1
```

Expected: `All tests passed!`. Toplam test sayısını not et (R3 sonunda +389; R4a net artışı yaklaşık +9: trend 1, tarih 1, hero 2, chart card 1, kilo 2, güç 2, ölçü 1, range selector −1).

- [ ] **Step 3: Release web build + manual check (user's terminal)**

Kullanıcıdan: `flutter build web --release --no-pub`, ardından `build\web` klasöründen `python -m http.server 5555 --bind 127.0.0.1` ve tarayıcıda önbelleği temizleyerek açması (yeni çeviriler). Elle kontrol listesi:

1. Kilo: üstte GÜNCEL + büyük sayı + "▼/▲ x kg · 3 ay" satırı; kilo vermek hedefindeysen düşüş neon, kas kazanmaksa gri.
2. Kilo: TREND kartında 1A/3A/1Y/Tümü çipleri; seçince grafik ve değişim satırı güncelleniyor.
3. Kilo: KAYITLAR kartında "78.4 kg · ▼ 0.3 · 4 Ekim · 🗑"; satıra dokununca düzenleme, 🗑 silme (son kayıtta pasif) çalışıyor; + ile ekleme çalışıyor.
4. Güç: hareket seçici kart görünümünde; TAHMİNİ 1RM büyük sayı; artış neon.
5. Güç: hareket değişince sayı, değişim ve grafik değişiyor; grafiğe dokununca ipucu çıkıyor.
6. Ölçüler: bölge çipleri neon; seçili bölgenin son değeri büyük; değişim gri.
7. Ölçüler: KAYITLAR kartında "4 Ekim" + gri özet + 🗑; düzenleme, silme ve ekleme çalışıyor.
8. Ana sayfadaki kilo / güç / ölçü kutuları ilgili ekranları açıyor; geçmiş ekranında tarihler hâlâ "4 Ekim" biçiminde.

- [ ] **Step 4: PLAN.md row and commit**

`PLAN.md` dosyasındaki tarihçe tablosunun son satırının altına (CRLF satır sonu) ekle:

```
| <tarih> | **F5+ R4a (ilerleme ekranları) tamamlandı** (`r4a-ilerleme` dalı, 5 görev). R4 ikiye bölündü (R4a ilerleme, R4b antrenör + giriş/kayıt/onboarding). Kilo, güç ve ölçüler ekranları "büyük sayı üstte" düzeninde: güncel değer + seçili aralıktaki değişim (kiloda renk hedefe göre, güçte artış neon, ölçüde gri), "TREND" kartında 1A/3A/1Y/Tümü çipleri, "KAYITLAR" kartında satır başına fark ve "4 Ekim" biçiminde tarih. Yeni bileşenler: `ProgressHero`, `ChartCard`; `RangeSelector` kaldırıldı; kısa tarih `lib/shared/date_label.dart`'a taşındı. Otomatik: <N> Flutter testi geçiyor (kullanıcının terminalinde `-j 1`), `flutter analyze` temiz. Manuel: <sonuç>. Sıradaki: R4b (antrenör, giriş/kayıt/onboarding). |
```

`<tarih>`, `<N>` ve `<sonuç>` yerine gerçek değerleri yaz.

```bash
git add PLAN.md
git commit -m "docs: record F5+ R4a verification

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

- [ ] **Step 5: Finish the branch**

superpowers:finishing-a-development-branch becerisiyle devam et (R1–R3'te: yerelde master'a fast-forward, dal silindi, kullanıcı onayıyla push).
