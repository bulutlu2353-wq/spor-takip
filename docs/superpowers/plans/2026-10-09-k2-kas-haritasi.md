# K2 — Kas Haritası: Kadın Figürü ve Stitch Yerleşimi Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Kas haritasına profil cinsiyetine göre açılan, ♂/♀ ile değiştirilebilen kadın figürü eklemek. Kas haritası ekranını, "Kas seç" alt sayfasını ve hareket seçiciyi Stitch taslaklarına göre yeniden yerleştirmek.

**Architecture:**
- **Veri:** Python üretici aynı MIT kaynağın kadın dosyalarını da çevirir. `muscle_map_data.dart` figür → görünüm → şekiller haritası olur.
- **Domain:** Figür alan fonksiyonlar, figür başına kırpma ve `figureFor(Gender?)`.
- **Durum:** `mapFigureChoiceProvider` (elle seçim, oturumluk) ve `mapFigureProvider` (seçim ?? profilden varsayılan).
- **Arayüz:** Ortak widget'lar (`FigureToggle`, `MuscleMapControls`, `MuscleMapCard`, `ExerciseIconBadge`) üç ekranda kullanılır.

**Tech Stack:** Flutter (Riverpod 3, go_router, easy_localization), Python 3 (yalnız standart kütüphane).

**Spec:** `docs/superpowers/specs/2026-10-09-k2-kas-haritasi-design.md`

## Global Constraints

- Dal `f5p-kas-haritasi-k2`; açık ve spec commit'li. Göç, deploy ya da yeni paket yok.
- `flutter` komutlarının hepsi `--no-pub` ile çalıştırılır; bu makinede `pub get` takılıyor.
- Görevlerde yalnızca ilgili test dosyaları çalıştırılır. Tam paketi kullanıcı kendi terminalinde çalıştırır (`flutter test --no-pub -j 1`, Task 6).
- `flutter analyze --no-pub` birkaç dakika sürer; arka planda çalıştır. Sonuç "No issues found!" olmalı.
- `dart format` çalıştırılmaz. Mevcut biçime elle uyulur; satırlar en çok ~120 karakter. Üretilen `muscle_map_data.dart` bu kuralın dışındadır.
- Testlerde çeviriler yüklenmez; `testApp` ham anahtarı gösterir. Metinler `Key` ya da ham anahtarla doğrulanır.
- Tuval her iki figür için `0..724 × 0..1448`. Kırpma alanları:
  - erkek `Rect.fromLTWH(40, 120, 644, 1250)`
  - kadın `Rect.fromLTWH(-10, 78, 661, 1365)`
- Kas adları `muscleGroups`'taki 17 değerden biridir; `lower back` ve `middle back` boşlukludur.
- `tool/body_highlighter/` altındaki kaynak dosyalar **değiştirilmez**. Üretilen Dart dosyası elle düzenlenmez.
- Mevcut test anahtarlarının hepsi korunur.
- Yeni anahtarlar: `figure_toggle_male`, `figure_toggle_female`, `muscle_map_card_label`, `muscle_map_sheet_close`, `exercise_search_clear`, `exercise_picker_count`, `exercise_custom_badge_<id>`.
- Profil okuyan ekran testleri `profileProvider`'ı override eder. Override edilmezse Supabase başlatılmamış olduğu için hata durumuna düşer.
- Bash aracı her komutta `commit-graph` / `/etc/...` uyarıları basıyor; bunlar zararsız, yok sayılır.
- Commit mesajları şu satırla biter: `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`

## Spec'ten bilinçli sapmalar (kullanıcıya bildirilecek)

1. **İki provider:** Spec'teki tek `mapFigureProvider` ikiye bölündü.
   - `mapFigureChoiceProvider` (`BodyFigure?`, elle seçim)
   - `mapFigureProvider` (seçim yoksa `figureFor(profil)`)

   Böylece "profil yüklenince, elle seçilmediyse uy" kuralı Notifier içinde ek bayrak tutmadan sağlanır.
2. **Seçici listesi satır başına kart:** Hareket seçicide ~870 hareket var. Liste tek bir `Card` yerine tembel `ListView` olarak kalır; her satır `Material` ile kart rengini ve ilk/son satırda yuvarlak köşeyi alır. Satır dokunma efektleri görünür kalır.
3. **"Haritadan seç" çipi `ActionChip` oldu:** Figür ikonlu ve lime çerçeveli. `AccentChip` değişmedi; anahtar aynı.

## Dosya yapısı

| Dosya | Görev |
|---|---|
| `tool/body_highlighter/bodyFemaleFront.ts`, `bodyFemaleBack.ts`, `SvgFemaleWrapper.tsx` | Yeni kaynak, değiştirilmez |
| `tool/generate_muscle_paths.py` | İki figür üretir; bölme eşiği payı kontrolü |
| `lib/features/workout/domain/muscle_map_data.dart` | Yeniden üretilir: `BodyFigure`, figür → görünüm haritaları |
| `lib/features/workout/domain/muscle_map.dart` | `bodyCrops`, `figureFor`, `BodyFit(size, figure)`, figür alan yol fonksiyonları |
| `lib/features/workout/application/muscle_map_providers.dart` | Yeni: figür seçimi ve varsayılan figür |
| `lib/features/workout/presentation/widgets/muscle_map.dart` | `MuscleMap(figure)` + `FigureToggle`, `MuscleMapControls`, `MuscleMapCard` |
| `lib/features/workout/presentation/widgets/exercise_icon_badge.dart` | Yeni: `equipmentIcon`, `ExerciseIconBadge` |
| `lib/features/workout/presentation/muscle_map_screen.dart` | Yeni yerleşim |
| `lib/features/workout/presentation/widgets/muscle_map_sheet.dart` | Yeni yerleşim |
| `lib/features/workout/presentation/exercise_picker_screen.dart` | Yeni yerleşim |
| `assets/translations/tr.json`, `en.json` | 7 yeni anahtar |
| `test/features/workout/muscle_map_points.dart` | Yardımcılar `figure` alır |
| `test/features/workout/domain/muscle_map_data_test.dart`, `muscle_map_test.dart` | İki figür |
| `test/features/workout/application/muscle_map_providers_test.dart` | Yeni |
| `test/features/workout/presentation/muscle_map_widget_test.dart`, `muscle_map_screen_test.dart`, `exercise_picker_screen_test.dart` | Yeni davranışlar |

---

### Task 1: Kadın figürü verisi ve figür alan domain

**Files:**
- Create: `tool/body_highlighter/bodyFemaleFront.ts`, `tool/body_highlighter/bodyFemaleBack.ts`, `tool/body_highlighter/SvgFemaleWrapper.tsx` (indirilir)
- Modify: `tool/generate_muscle_paths.py`
- Regenerate: `lib/features/workout/domain/muscle_map_data.dart`
- Modify: `lib/features/workout/domain/muscle_map.dart`
- Modify: `lib/features/workout/presentation/widgets/muscle_map.dart`: `MuscleMap`'e `figure` eklenir; derlemenin bozulmaması için bu görevde yapılır.
- Test: `test/features/workout/muscle_map_points.dart`, `test/features/workout/domain/muscle_map_data_test.dart`, `test/features/workout/domain/muscle_map_test.dart`

**Interfaces:**
- Produces:
  - `enum BodyFigure { male, female }`, `muscle_map.dart` üzerinden dışa açılır.
  - `const Map<BodyFigure, Rect> bodyCrops`
  - `BodyFigure figureFor(Gender? gender)`
  - `BodyFit(Size size, BodyFigure figure)`
  - `List<(String?, Path)> musclePaths(BodyFigure figure, BodyView view)`
  - `Path silhouettePath(BodyFigure figure, BodyView view)`
  - `String? muscleAt(BodyFigure figure, BodyView view, Offset canvasPoint)`
  - `Set<String> musclesIn(BodyFigure figure, BodyView view)`
  - `MuscleMap({required BodyView view, BodyFigure figure = BodyFigure.male, String? selected, required ValueChanged<String> onSelected})`
  - Test yardımcıları:
    - `canvasPointFor(BodyView view, String muscle, {BodyFigure figure = BodyFigure.male})`
    - `decorPoint(BodyView view, {BodyFigure figure = BodyFigure.male})`
    - `screenPointFor(WidgetTester tester, Finder map, BodyView view, String muscle, {BodyFigure figure = BodyFigure.male})`

- [ ] **Step 1: Kaynak dosyaları indir**

PowerShell, proje kökünden:

```powershell
$dir = "tool/body_highlighter"
$base = "https://raw.githubusercontent.com/HichamELBSI/react-native-body-highlighter/main"
foreach ($f in @("assets/bodyFemaleFront.ts", "assets/bodyFemaleBack.ts", "components/SvgFemaleWrapper.tsx")) {
  Invoke-WebRequest -UseBasicParsing "$base/$f" -OutFile (Join-Path $dir (Split-Path $f -Leaf)) -ErrorAction Stop
}
Get-ChildItem $dir | Select-Object Name, Length
```

Beklenen boyutlar: `bodyFemaleFront.ts` 32308, `bodyFemaleBack.ts` 22650, `SvgFemaleWrapper.tsx` 21276 bayt. Bunlara ek olarak K1'den kalan dört dosya da listede görünür. Dosyalar değiştirilmez.

- [ ] **Step 2: Veri testlerini yaz (başarısız olmalı)**

`test/features/workout/domain/muscle_map_data_test.dart` içeriğini tamamen şununla değiştir:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:spor_takip/features/workout/domain/exercise_taxonomy.dart';
import 'package:spor_takip/features/workout/domain/muscle_map_data.dart';

const _arity = {0: 2, 1: 2, 2: 6, 3: 4, 4: 0};

void _expectWellFormed(List<double> commands, String label) {
  expect(commands, isNotEmpty, reason: label);
  expect(commands.first, 0, reason: '$label starts with M');
  var i = 0;
  while (i < commands.length) {
    final code = commands[i].toInt();
    expect(commands[i], code.toDouble(), reason: '$label: code at $i is an integer');
    expect(_arity.containsKey(code), isTrue, reason: '$label: unknown code $code at $i');
    i += 1 + _arity[code]!;
  }
  expect(i, commands.length, reason: '$label: argument count matches the codes');
}

Set<String> _muscles(BodyFigure figure, BodyView view) => {for (final s in muscleShapes[figure]![view]!) ?s.muscle};

void main() {
  test('every taxonomy muscle is drawn in at least one view of each figure', () {
    for (final figure in BodyFigure.values) {
      final drawn = {for (final view in BodyView.values) ..._muscles(figure, view)};
      expect(drawn, unorderedEquals(muscleGroups), reason: figure.name);
    }
  });

  test('both figures offer the same muscles in each view', () {
    for (final view in BodyView.values) {
      expect(_muscles(BodyFigure.female, view), _muscles(BodyFigure.male, view), reason: view.name);
    }
  });

  test('shape counts match the source data', () {
    expect(muscleShapes[BodyFigure.male]![BodyView.front], hasLength(88));
    expect(muscleShapes[BodyFigure.male]![BodyView.back], hasLength(69));
    expect(muscleShapes[BodyFigure.female]![BodyView.front], hasLength(90));
    expect(muscleShapes[BodyFigure.female]![BodyView.back], hasLength(64));
  });

  test('silhouettes and shapes are well-formed command lists', () {
    for (final figure in BodyFigure.values) {
      for (final view in BodyView.values) {
        final label = '${figure.name}/${view.name}';
        _expectWellFormed(bodySilhouettes[figure]![view]!, '$label silhouette');
        for (final (i, shape) in muscleShapes[figure]![view]!.indexed) {
          _expectWellFormed(shape.commands, '$label shape $i (${shape.muscle})');
        }
      }
    }
  });

  test('canvas size', () {
    expect(bodyCanvasWidth, 724);
    expect(bodyCanvasHeight, 1448);
  });
}
```

- [ ] **Step 3: Testin başarısız olduğunu doğrula**

Run: `flutter test --no-pub test/features/workout/domain/muscle_map_data_test.dart`
Expected: FAIL. Derleme hatası: `BodyFigure` tanımlı değil.

- [ ] **Step 4: Üretici betiği güncelle**

`tool/generate_muscle_paths.py` dosyasında yapılacak değişiklikler (bu içerik plan yazılırken gerçek kaynakla çalıştırılıp doğrulandı):

1. Docstring'in ilk satırı:

```python
"""Kas haritası yollarını üretir (K1 spec §3.2, K2 spec §3.2: erkek + kadın figürü).
```

2. `BACK_SHIFT = 724.0` satırını sil; yerine şunu koy:

```python
# Figür → (görünüm → (kaynak dosya, x kaydırması)), siluet dosyası. Arka görünüm ön görünümün x aralığına kaydırılır.
FIGURES = {
    'male': ({'front': ('bodyFront.ts', 0.0), 'back': ('bodyBack.ts', 724.0)}, 'SvgMaleWrapper.tsx'),
    'female': ({'front': ('bodyFemaleFront.ts', 0.0), 'back': ('bodyFemaleBack.ts', 822.0)}, 'SvgFemaleWrapper.tsx'),
}
# Bölme eşiğine bundan yakın yükseklik → kaynak değişmiş olabilir, dur.
SPLIT_MARGIN = 0.25
```

3. `muscle_for` içinde bölme dalını şöyle yap:

```python
    if view == 'back' and slug in BACK_SPLIT:
        limit, tall, short = BACK_SPLIT[slug]
        if abs(height - limit) < SPLIT_MARGIN:
            raise SystemExit(f'{view}/{slug}: height {height:.2f} too close to split {limit}')
        return tall if height > limit else short
```

4. `def main():` fonksiyonunu tamamen şununla değiştir (`if __name__ == '__main__':` bloğu aynı kalır):

```python
def main():
    figures = {}
    for figure, (views, wrapper_file) in FIGURES.items():
        wrapper = (SRC / wrapper_file).read_text(encoding='utf-8')
        figures[figure] = {}
        for view, (ts_file, shift) in views.items():
            ts_text = (SRC / ts_file).read_text(encoding='utf-8')
            figures[figure][view] = (shapes_for(view, ts_text, shift), silhouette(wrapper, view, shift))
    lines = [
        '// OTOMATİK ÜRETİLDİ — tool/generate_muscle_paths.py. Elle düzenleme.',
        '// Vücut yolları: react-native-body-highlighter, MIT License, Copyright (c) 2022 ELABBASSI Hicham.',
        '',
        'enum BodyFigure { male, female }',
        '',
        'enum BodyView { front, back }',
        '',
        '/// Komut kodları: 0 = M (x y), 1 = L (x y), 2 = C (x1 y1 x2 y2 x y), 3 = Q (x1 y1 x y), 4 = Z.',
        'class MuscleShape {',
        '  const MuscleShape(this.muscle, this.commands);',
        "  final String? muscle; // muscleGroups'tan biri; süs parçalarında null",
        '  final List<double> commands;',
        '}',
        '',
        'const bodyCanvasWidth = 724.0;',
        'const bodyCanvasHeight = 1448.0;',
        '',
        'const Map<BodyFigure, Map<BodyView, List<double>>> bodySilhouettes = {',
    ]
    for figure, views in figures.items():
        lines.append(f'  BodyFigure.{figure}: {{')
        for view, (_, outline) in views.items():
            lines.append(f'    BodyView.{view}: <double>[{fmt_list(outline)}],')
        lines.append('  },')
    lines += ['};', '', 'const Map<BodyFigure, Map<BodyView, List<MuscleShape>>> muscleShapes = {']
    for figure, views in figures.items():
        lines.append(f'  BodyFigure.{figure}: {{')
        for view, (shapes, _) in views.items():
            lines.append(f'    BodyView.{view}: [')
            for muscle, cmds, slug in shapes:
                name = 'null' if muscle is None else f"'{muscle}'"
                lines.append(f'      // {slug}')
                lines.append(f'      MuscleShape({name}, <double>[{fmt_list(cmds)}]),')
            lines.append('    ],')
        lines.append('  },')
    lines += ['};', '']
    OUT.write_text('\n'.join(lines), encoding='utf-8', newline='\n')
    counts = {f'{f}/{v}': len(s) for f, views in figures.items() for v, (s, _) in views.items()}
    print(f'wrote {OUT.relative_to(ROOT)}: {counts}')
```

- [ ] **Step 5: Üret ve erkek verisinin değişmediğini doğrula**

Bash, proje kökünden:

```bash
git show HEAD:lib/features/workout/domain/muscle_map_data.dart | grep "^    MuscleShape(" | sed 's/^ *//' > /tmp/k2_old.txt
python -I tool/generate_muscle_paths.py
sed -n '/muscleShapes = {/,$p' lib/features/workout/domain/muscle_map_data.dart | awk '/^  BodyFigure.female/{exit} {print}' \
  | grep "^      MuscleShape(" | sed 's/^ *//' > /tmp/k2_new.txt
diff -q /tmp/k2_old.txt /tmp/k2_new.txt && echo MALE_SHAPES_SAME
```

`/tmp` yerine oturumun scratchpad klasörü de kullanılabilir.

Expected:
- Betik çıktısı: `wrote lib\features\workout\domain\muscle_map_data.dart: {'male/front': 88, 'male/back': 69, 'female/front': 90, 'female/back': 64}`
- Ardından `MALE_SHAPES_SAME` yazdırılır.
- Dosya boyutu ~186 KB.

- [ ] **Step 6: Domain ve yardımcı testlerini yaz (başarısız olmalı)**

`test/features/workout/muscle_map_points.dart` içeriğini tamamen şununla değiştir:

```dart
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:spor_takip/features/workout/domain/muscle_map.dart';

const _step = 4.0;

Iterable<Offset> _grid(Rect bounds) sync* {
  yield bounds.center;
  for (var y = bounds.top; y <= bounds.bottom; y += _step) {
    for (var x = bounds.left; x <= bounds.right; x += _step) {
      yield Offset(x, y);
    }
  }
}

/// [muscle]'a düşen bir tuval noktası (önce şeklin merkezi, sonra 4 birimlik ızgara).
Offset? canvasPointFor(BodyView view, String muscle, {BodyFigure figure = BodyFigure.male}) {
  for (final (m, path) in musclePaths(figure, view)) {
    if (m != muscle) continue;
    for (final p in _grid(path.getBounds())) {
      if (path.contains(p) && muscleAt(figure, view, p) == muscle) return p;
    }
  }
  return null;
}

/// Bir süs parçasının (baş, el, diz…) içinde olup hiçbir kas şeklinde olmayan nokta.
Offset? decorPoint(BodyView view, {BodyFigure figure = BodyFigure.male}) {
  final paths = musclePaths(figure, view);
  for (final (m, path) in paths) {
    if (m != null) continue;
    for (final p in _grid(path.getBounds())) {
      if (path.contains(p) && !paths.any((s) => s.$1 != null && s.$2.contains(p))) return p;
    }
  }
  return null;
}

/// [map] (MuscleMap içindeki `muscle_map_<view>` kutusu) üzerinde [muscle]'a dokunulacak genel ekran noktası.
Offset screenPointFor(
  WidgetTester tester,
  Finder map,
  BodyView view,
  String muscle, {
  BodyFigure figure = BodyFigure.male,
}) {
  final rect = tester.getRect(map);
  return rect.topLeft + BodyFit(rect.size, figure).toLocal(canvasPointFor(view, muscle, figure: figure)!);
}
```

`test/features/workout/domain/muscle_map_test.dart` içeriğini tamamen şununla değiştir:

```dart
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:spor_takip/features/onboarding/domain/profile.dart';
import 'package:spor_takip/features/workout/domain/exercise_taxonomy.dart';
import 'package:spor_takip/features/workout/domain/muscle_map.dart';
import 'package:spor_takip/features/workout/domain/muscle_map_data.dart';

import '../muscle_map_points.dart';

void main() {
  test('buildPath handles every command', () {
    final path = buildPath([0, 10, 10, 1, 20, 10, 2, 25, 10, 30, 15, 30, 20, 3, 30, 30, 20, 30, 4]);
    final bounds = path.getBounds();
    expect(bounds.left, 10);
    expect(bounds.top, 10);
    expect(bounds.right, closeTo(30, 0.01));
    expect(bounds.bottom, 30);
    expect(path.contains(const Offset(22, 20)), isTrue);
    expect(() => buildPath([9, 0, 0]), throwsArgumentError);
  });

  test('figureFor picks the female figure only for female profiles', () {
    expect(figureFor(Gender.female), BodyFigure.female);
    expect(figureFor(Gender.male), BodyFigure.male);
    expect(figureFor(Gender.unspecified), BodyFigure.male);
    expect(figureFor(null), BodyFigure.male);
  });

  test('silhouettes stay inside the figure crop and shapes on the canvas', () {
    const canvas = Rect.fromLTWH(0, 0, bodyCanvasWidth, bodyCanvasHeight);
    for (final figure in BodyFigure.values) {
      final crop = bodyCrops[figure]!;
      for (final view in BodyView.values) {
        final label = '${figure.name}/${view.name}';
        final silhouette = silhouettePath(figure, view).getBounds();
        expect(crop.intersect(silhouette), silhouette, reason: '$label silhouette inside crop');
        for (final (muscle, path) in musclePaths(figure, view)) {
          final b = path.getBounds();
          expect(canvas.intersect(b), b, reason: '$label $muscle on canvas');
        }
      }
    }
  });

  test('every drawn muscle can be tapped on both figures', () {
    for (final figure in BodyFigure.values) {
      for (final view in BodyView.values) {
        for (final muscle in musclesIn(figure, view)) {
          expect(canvasPointFor(view, muscle, figure: figure), isNotNull, reason: '${figure.name}/${view.name} $muscle');
        }
      }
    }
  });

  test('views hold the expected muscles', () {
    for (final figure in BodyFigure.values) {
      final front = musclesIn(figure, BodyView.front);
      final back = musclesIn(figure, BodyView.back);
      expect(front, containsAll(['chest', 'abdominals', 'biceps', 'quadriceps']), reason: figure.name);
      expect(front, isNot(contains('lats')), reason: figure.name);
      expect(back, containsAll(['lats', 'middle back', 'lower back', 'glutes', 'abductors']), reason: figure.name);
      expect(back, isNot(contains('chest')), reason: figure.name);
      expect({...front, ...back}, unorderedEquals(muscleGroups), reason: figure.name);
    }
  });

  test('empty canvas and decoration parts return no muscle', () {
    for (final figure in BodyFigure.values) {
      expect(muscleAt(figure, BodyView.front, Offset.zero), isNull);
      for (final view in BodyView.values) {
        final p = decorPoint(view, figure: figure);
        expect(p, isNotNull, reason: '${figure.name}/${view.name} has a decoration-only point');
        expect(muscleAt(figure, view, p!), isNull);
      }
    }
  });

  test('paths are cached per figure and view', () {
    expect(identical(musclePaths(BodyFigure.male, BodyView.back), musclePaths(BodyFigure.male, BodyView.back)), isTrue);
    expect(identical(musclePaths(BodyFigure.male, BodyView.back), musclePaths(BodyFigure.female, BodyView.back)), isFalse);
    expect(
      identical(silhouettePath(BodyFigure.female, BodyView.front), silhouettePath(BodyFigure.female, BodyView.front)),
      isTrue,
    );
  });

  test('BodyFit centers the male crop and round-trips points', () {
    final crop = bodyCrops[BodyFigure.male]!;
    final tall = BodyFit(const Size(322, 1000), BodyFigure.male);
    expect(tall.scale, 0.5);
    expect(tall.toLocal(crop.topLeft), const Offset(0, 187.5));

    final wide = BodyFit(const Size(1000, 625), BodyFigure.male);
    expect(wide.scale, 0.5);
    expect(wide.toLocal(crop.topLeft), const Offset(339, 0));
    final back = wide.toCanvas(wide.toLocal(const Offset(300, 700)));
    expect(back.dx, closeTo(300, 1e-9));
    expect(back.dy, closeTo(700, 1e-9));
  });

  test('BodyFit uses the female crop for the female figure', () {
    final crop = bodyCrops[BodyFigure.female]!;
    final fit = BodyFit(const Size(661, 2000), BodyFigure.female);
    expect(fit.scale, 1);
    expect(fit.toLocal(crop.topLeft), const Offset(0, 317.5));
  });
}
```

- [ ] **Step 7: Testlerin başarısız olduğunu doğrula**

Run: `flutter test --no-pub test/features/workout/domain/muscle_map_test.dart`
Expected: FAIL. Derleme hatası: `figureFor`, `bodyCrops` tanımlı değil; `musclePaths` için argüman sayısı uyuşmuyor.

- [ ] **Step 8: Domain'i güncelle**

`lib/features/workout/domain/muscle_map.dart` içeriğini tamamen şununla değiştir:

```dart
import 'dart:math' as math;
import 'dart:ui';

import '../../onboarding/domain/profile.dart';
import 'muscle_map_data.dart';

export 'muscle_map_data.dart' show BodyFigure, BodyView;

/// Figürün iki görünümde de göründüğü tuval alanı (K1 spec §4, K2 spec §4).
const bodyCrops = <BodyFigure, Rect>{
  BodyFigure.male: Rect.fromLTWH(40, 120, 644, 1250),
  BodyFigure.female: Rect.fromLTWH(-10, 78, 661, 1365),
};

/// Profil cinsiyetinden varsayılan figür: kadın → kadın; erkek, belirtilmemiş ve null → erkek.
BodyFigure figureFor(Gender? gender) => gender == Gender.female ? BodyFigure.female : BodyFigure.male;

/// Figürün kırpma alanını bir boyuta oranı koruyarak ortalar: yerel = tuval × [scale] + [offset].
class BodyFit {
  factory BodyFit(Size size, BodyFigure figure) {
    final crop = bodyCrops[figure]!;
    final scale = math.min(size.width / crop.width, size.height / crop.height);
    final pad = Offset((size.width - crop.width * scale) / 2, (size.height - crop.height * scale) / 2);
    return BodyFit._(scale, pad - crop.topLeft * scale);
  }

  const BodyFit._(this.scale, this.offset);

  final double scale;
  final Offset offset;

  Offset toCanvas(Offset local) => (local - offset) / scale;

  Offset toLocal(Offset canvas) => canvas * scale + offset;
}

/// Üretilen komut listesinden yol (kodlar `muscle_map_data.dart`'ta).
Path buildPath(List<double> commands) {
  final path = Path();
  final c = commands;
  var i = 0;
  while (i < c.length) {
    switch (c[i].toInt()) {
      case 0:
        path.moveTo(c[i + 1], c[i + 2]);
        i += 3;
      case 1:
        path.lineTo(c[i + 1], c[i + 2]);
        i += 3;
      case 2:
        path.cubicTo(c[i + 1], c[i + 2], c[i + 3], c[i + 4], c[i + 5], c[i + 6]);
        i += 7;
      case 3:
        path.quadraticBezierTo(c[i + 1], c[i + 2], c[i + 3], c[i + 4]);
        i += 5;
      case 4:
        path.close();
        i += 1;
      default:
        throw ArgumentError('Unknown path command ${c[i]} at $i');
    }
  }
  return path;
}

final _muscleCache = <(BodyFigure, BodyView), List<(String?, Path)>>{};
final _silhouetteCache = <(BodyFigure, BodyView), Path>{};

/// Görünümün şekilleri, kaynak (çizim) sırasıyla; süs parçalarında kas null.
List<(String?, Path)> musclePaths(BodyFigure figure, BodyView view) => _muscleCache.putIfAbsent(
      (figure, view),
      () => [for (final s in muscleShapes[figure]![view]!) (s.muscle, buildPath(s.commands))],
    );

Path silhouettePath(BodyFigure figure, BodyView view) =>
    _silhouetteCache.putIfAbsent((figure, view), () => buildPath(bodySilhouettes[figure]![view]!));

/// Tuval noktasındaki kas: üstte çizilen (sondaki) şekil önce; süs parçaları atlanır.
String? muscleAt(BodyFigure figure, BodyView view, Offset canvasPoint) {
  for (final (muscle, path) in musclePaths(figure, view).reversed) {
    if (muscle != null && path.contains(canvasPoint)) return muscle;
  }
  return null;
}

Set<String> musclesIn(BodyFigure figure, BodyView view) => {for (final s in muscleShapes[figure]![view]!) ?s.muscle};
```

- [ ] **Step 9: `MuscleMap`'e `figure` ekle**

`lib/features/workout/presentation/widgets/muscle_map.dart` içinde:

Sınıfın kurucusu ve alanları:

```dart
class MuscleMap extends StatelessWidget {
  const MuscleMap({
    super.key,
    required this.view,
    this.figure = BodyFigure.male,
    this.selected,
    required this.onSelected,
  });

  final BodyView view;
  final BodyFigure figure;
  final String? selected;
  final ValueChanged<String> onSelected;
```

`onTapUp` içindeki satır:

```dart
              final muscle = muscleAt(figure, view, BodyFit(size, figure).toCanvas(details.localPosition));
```

`CustomPaint` satırı:

```dart
            child: CustomPaint(
              size: size,
              painter: _MuscleMapPainter(figure: figure, view: view, selected: selected, colors: colors),
            ),
```

`_MuscleMapPainter` sınıfının başı:

```dart
class _MuscleMapPainter extends CustomPainter {
  _MuscleMapPainter({required this.figure, required this.view, required this.selected, required this.colors});

  final BodyFigure figure;
  final BodyView view;
  final String? selected;
  final _MapColors colors;

  @override
  void paint(Canvas canvas, Size size) {
    final fit = BodyFit(size, figure);
```

`paint` içinde:
- `silhouettePath(view)` → `silhouettePath(figure, view)`
- `musclePaths(view)` → `musclePaths(figure, view)`

`shouldRepaint`:

```dart
  @override
  bool shouldRepaint(_MuscleMapPainter old) =>
      old.figure != figure || old.view != view || old.selected != selected || old.colors != colors;
```

- [ ] **Step 10: Testlerin geçtiğini doğrula**

Run:

```
flutter test --no-pub test/features/workout/domain/muscle_map_data_test.dart test/features/workout/domain/muscle_map_test.dart test/features/workout/presentation/muscle_map_widget_test.dart test/features/workout/presentation/muscle_map_screen_test.dart test/features/workout/presentation/exercise_picker_screen_test.dart
```

Expected: Tüm testler geçer. Ekran ve seçici testleri değişmeden geçer; çünkü varsayılan figür erkek ve yardımcıların varsayılan parametresi de erkek.

- [ ] **Step 11: Commit**

```bash
git add tool/body_highlighter tool/generate_muscle_paths.py lib/features/workout/domain/muscle_map_data.dart \
  lib/features/workout/domain/muscle_map.dart lib/features/workout/presentation/widgets/muscle_map.dart \
  test/features/workout/muscle_map_points.dart test/features/workout/domain/muscle_map_data_test.dart \
  test/features/workout/domain/muscle_map_test.dart
git commit -m "feat(workout): add the female body figure to the muscle map data

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 2: Figür durumu, ortak widget'lar ve çeviriler

**Files:**
- Create: `lib/features/workout/application/muscle_map_providers.dart`
- Create: `lib/features/workout/presentation/widgets/exercise_icon_badge.dart`
- Modify: `lib/features/workout/presentation/widgets/muscle_map.dart`: `FigureToggle`, `MuscleMapControls`, `MuscleMapCard` eklenir.
- Modify: `assets/translations/tr.json`, `assets/translations/en.json`
- Test: `test/features/workout/application/muscle_map_providers_test.dart` (yeni), `test/features/workout/presentation/muscle_map_widget_test.dart`

**Interfaces:**
- Consumes: Task 1'deki `BodyFigure`, `figureFor`, `MuscleMap(figure:)`.
- Produces:
  - `final mapFigureChoiceProvider = NotifierProvider<MapFigureChoice, BodyFigure?>(MapFigureChoice.new);` Notifier'da `void choose(BodyFigure figure)` var.
  - `final mapFigureProvider = Provider<BodyFigure>(...)`
  - `FigureToggle({required BodyFigure figure, required ValueChanged<BodyFigure> onChanged})`
  - `MuscleMapControls({required BodyView view, required ValueChanged<BodyView> onViewChanged, required BodyFigure figure, required ValueChanged<BodyFigure> onFigureChanged})`
  - `MuscleMapCard({required Widget child, String? label})`
  - `IconData equipmentIcon(String? equipment)`
  - `ExerciseIconBadge({required String? equipment})`
  - Çeviriler:
    - `workout.muscle_map.pick_title`, `sheet_hint`, `figure_male`, `figure_female`
    - `workout.picker_count` (`{n}`), `workout.picker_search_clear`, `workout.custom_badge_short`

- [ ] **Step 1: Provider testini yaz**

`test/features/workout/application/muscle_map_providers_test.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spor_takip/features/onboarding/application/profile_providers.dart';
import 'package:spor_takip/features/onboarding/domain/profile.dart';
import 'package:spor_takip/features/workout/application/muscle_map_providers.dart';
import 'package:spor_takip/features/workout/domain/muscle_map.dart';

import '../../progress/fixtures.dart';

ProviderContainer _container(Profile? profile) {
  final container = ProviderContainer(overrides: [profileProvider.overrideWith((ref) async => profile)]);
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('defaults to the figure of the profile gender', () async {
    final female = _container(testProfile.copyWith(gender: Gender.female));
    await female.read(profileProvider.future);
    expect(female.read(mapFigureProvider), BodyFigure.female);

    final male = _container(testProfile);
    await male.read(profileProvider.future);
    expect(male.read(mapFigureProvider), BodyFigure.male);
  });

  test('falls back to the male figure without a profile', () async {
    final container = _container(null);
    expect(container.read(mapFigureProvider), BodyFigure.male); // yükleniyor
    await container.read(profileProvider.future);
    expect(container.read(mapFigureProvider), BodyFigure.male);
  });

  test('a manual choice wins over the profile', () async {
    final container = _container(testProfile.copyWith(gender: Gender.female));
    await container.read(profileProvider.future);
    container.read(mapFigureChoiceProvider.notifier).choose(BodyFigure.male);
    expect(container.read(mapFigureProvider), BodyFigure.male);
  });
}
```

- [ ] **Step 2: Widget testlerini ekle**

`test/features/workout/presentation/muscle_map_widget_test.dart` dosyasının en üstündeki import'lara ekle:

```dart
import 'package:spor_takip/features/workout/presentation/widgets/exercise_icon_badge.dart';
```

`main()` içine, mevcut testlerin sonuna ekle:

```dart
  testWidgets('the female figure reports taps on its own shapes', (tester) async {
    final taps = <String>[];
    await tester.pumpWidget(testApp(
      Scaffold(
        body: Center(
          child: SizedBox(
            width: 300,
            height: 500,
            child: MuscleMap(view: BodyView.back, figure: BodyFigure.female, onSelected: taps.add),
          ),
        ),
      ),
      scaffold: false,
    ));
    await tester.pumpAndSettle();
    final map = find.byKey(const Key('muscle_map_back'));
    for (final muscle in ['lats', 'middle back', 'glutes', 'abductors']) {
      await tester.tapAt(screenPointFor(tester, map, BodyView.back, muscle, figure: BodyFigure.female));
    }
    expect(taps, ['lats', 'middle back', 'glutes', 'abductors']);
  });

  testWidgets('figure toggle reports the chosen figure', (tester) async {
    final changes = <BodyFigure>[];
    await tester.pumpWidget(testApp(FigureToggle(figure: BodyFigure.male, onChanged: changes.add)));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('figure_toggle_female')));
    expect(changes, [BodyFigure.female]);
  });

  testWidgets('controls hold both toggles', (tester) async {
    final views = <BodyView>[];
    final figures = <BodyFigure>[];
    await tester.pumpWidget(testApp(MuscleMapControls(
      view: BodyView.front,
      onViewChanged: views.add,
      figure: BodyFigure.female,
      onFigureChanged: figures.add,
    )));
    await tester.pumpAndSettle();
    await tester.tap(find.text('workout.muscle_map.back'));
    await tester.tap(find.byKey(const Key('figure_toggle_male')));
    expect(views, [BodyView.back]);
    expect(figures, [BodyFigure.male]);
  });

  testWidgets('map card shows its label only when given', (tester) async {
    await tester.pumpWidget(testApp(
      const SizedBox(height: 200, child: MuscleMapCard(label: 'Kanat', child: SizedBox.expand())),
    ));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('muscle_map_card_label')), findsOneWidget);
    expect(find.text('Kanat'), findsOneWidget);

    await tester.pumpWidget(testApp(const SizedBox(height: 200, child: MuscleMapCard(child: SizedBox.expand()))));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('muscle_map_card_label')), findsNothing);
  });

  test('equipment icons fall back for unknown equipment', () {
    expect(equipmentIcon('cable'), Icons.cable);
    expect(equipmentIcon('body only'), Icons.accessibility_new);
    expect(equipmentIcon(null), Icons.fitness_center);
    expect(equipmentIcon('unknown'), Icons.fitness_center);
  });
```

- [ ] **Step 3: Testlerin başarısız olduğunu doğrula**

Run: `flutter test --no-pub test/features/workout/application/muscle_map_providers_test.dart test/features/workout/presentation/muscle_map_widget_test.dart`
Expected: FAIL. Derleme hatası: `muscle_map_providers.dart`, `FigureToggle`, `MuscleMapControls`, `MuscleMapCard`, `exercise_icon_badge.dart` yok.

- [ ] **Step 4: Provider'ları yaz**

`lib/features/workout/application/muscle_map_providers.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../onboarding/application/profile_providers.dart';
import '../domain/muscle_map.dart';

/// Haritada elle seçilen figür; null = seçilmedi. Uygulama açık kaldıkça sürer, saklanmaz (K2 spec §5.2).
class MapFigureChoice extends Notifier<BodyFigure?> {
  @override
  BodyFigure? build() => null;

  void choose(BodyFigure figure) => state = figure;
}

final mapFigureChoiceProvider = NotifierProvider<MapFigureChoice, BodyFigure?>(MapFigureChoice.new);

/// Haritada gösterilecek figür: elle seçim, yoksa profil cinsiyetinden (yüklenirken/hata/null → erkek).
final mapFigureProvider = Provider<BodyFigure>((ref) {
  return ref.watch(mapFigureChoiceProvider) ?? figureFor(ref.watch(profileProvider).value?.gender);
});
```

- [ ] **Step 5: Ekipman ikonunu yaz**

`lib/features/workout/presentation/widgets/exercise_icon_badge.dart`:

```dart
import 'package:flutter/material.dart';

/// Ekipman türü (`equipmentTypes`) → liste ikonu; bilinmeyen/null → dambıl.
IconData equipmentIcon(String? equipment) => switch (equipment) {
      'cable' => Icons.cable,
      'machine' => Icons.precision_manufacturing,
      'body only' => Icons.accessibility_new,
      'bands' => Icons.linear_scale,
      'exercise ball' || 'medicine ball' => Icons.sports_volleyball,
      'foam roll' => Icons.view_week,
      _ => Icons.fitness_center, // barbell, dumbbell, e-z curl bar, kettlebells, other
    };

/// Hareket satırının başındaki yuvarlak ikon (K2 spec §5.1).
class ExerciseIconBadge extends StatelessWidget {
  const ExerciseIconBadge({super.key, required this.equipment});

  final String? equipment;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return CircleAvatar(
      radius: 20,
      backgroundColor: scheme.surfaceContainerHighest,
      child: Icon(equipmentIcon(equipment), size: 20, color: scheme.primary),
    );
  }
}
```

- [ ] **Step 6: Ortak harita widget'larını yaz**

`lib/features/workout/presentation/widgets/muscle_map.dart` dosyasının sonuna (BodyViewToggle'dan sonra) ekle:

```dart
/// ♂ / ♀ figür anahtarı.
class FigureToggle extends StatelessWidget {
  const FigureToggle({super.key, required this.figure, required this.onChanged});

  final BodyFigure figure;
  final ValueChanged<BodyFigure> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<BodyFigure>(
      key: const Key('figure_toggle'),
      showSelectedIcon: false,
      segments: [
        ButtonSegment(
          value: BodyFigure.male,
          tooltip: 'workout.muscle_map.figure_male'.tr(),
          label: Icon(Icons.male, key: const Key('figure_toggle_male'), semanticLabel: 'workout.muscle_map.figure_male'.tr()),
        ),
        ButtonSegment(
          value: BodyFigure.female,
          tooltip: 'workout.muscle_map.figure_female'.tr(),
          label: Icon(
            Icons.female,
            key: const Key('figure_toggle_female'),
            semanticLabel: 'workout.muscle_map.figure_female'.tr(),
          ),
        ),
      ],
      selected: {figure},
      onSelectionChanged: (selection) => onChanged(selection.first),
    );
  }
}

/// Solda ÖN/ARKA, sağda ♂/♀ (ekran ve alt sayfa ortak).
class MuscleMapControls extends StatelessWidget {
  const MuscleMapControls({
    super.key,
    required this.view,
    required this.onViewChanged,
    required this.figure,
    required this.onFigureChanged,
  });

  final BodyView view;
  final ValueChanged<BodyView> onViewChanged;
  final BodyFigure figure;
  final ValueChanged<BodyFigure> onFigureChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        BodyViewToggle(view: view, onChanged: onViewChanged),
        const Spacer(),
        FigureToggle(figure: figure, onChanged: onFigureChanged),
      ],
    );
  }
}

/// Figürü saran noktalı koyu kart; [label] sol üstte seçili kas hapı. Sınırlı yükseklik ister.
class MuscleMapCard extends StatelessWidget {
  const MuscleMapCard({super.key, required this.child, this.label});

  final Widget child;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final label = this.label;
    return ClipRRect(
      borderRadius: const BorderRadius.all(Radius.circular(16)),
      child: ColoredBox(
        color: theme.cardTheme.color ?? scheme.surfaceContainer,
        child: Stack(
          children: [
            Positioned.fill(child: CustomPaint(painter: _DotGridPainter(scheme.outlineVariant))),
            Positioned.fill(child: Padding(padding: const EdgeInsets.all(12), child: child)),
            if (label != null)
              Positioned(
                left: 12,
                top: 12,
                child: Container(
                  key: const Key('muscle_map_card_label'),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: theme.scaffoldBackgroundColor,
                    borderRadius: const BorderRadius.all(Radius.circular(999)),
                    border: Border.all(color: scheme.primary.withValues(alpha: 0.6)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.circle, size: 8, color: scheme.primary),
                      const SizedBox(width: 8),
                      Text(label, style: theme.textTheme.labelLarge),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _DotGridPainter extends CustomPainter {
  _DotGridPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color.withValues(alpha: 0.5);
    for (var y = 8.0; y < size.height; y += 16) {
      for (var x = 8.0; x < size.width; x += 16) {
        canvas.drawCircle(Offset(x, y), 1, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DotGridPainter old) => old.color != color;
}
```

- [ ] **Step 7: Çevirileri ekle**

`assets/translations/tr.json`, `workout` nesnesi:
- `"custom_exercise_badge": "Senin hareketin",` satırının hemen altına:

```json
    "custom_badge_short": "Özel",
```

- `"picker_no_results": "Sonuç yok",` satırının hemen altına:

```json
    "picker_count": "{n} hareket",
    "picker_search_clear": "Aramayı temizle",
```

- `muscle_map` içinde `"pick_from_map": "Haritadan seç"` satırını şununla değiştir:

```json
      "pick_from_map": "Haritadan seç",
      "pick_title": "Kas seç",
      "sheet_hint": "Bir kasa dokun — liste o kasa süzülür",
      "figure_male": "Erkek figürü",
      "figure_female": "Kadın figürü"
```

`assets/translations/en.json`, aynı yerler:
- `"custom_exercise_badge": "Your exercise",` altına:

```json
    "custom_badge_short": "Custom",
```

- `"picker_no_results": "No results",` altına:

```json
    "picker_count": "{n} exercises",
    "picker_search_clear": "Clear search",
```

- `"pick_from_map": "Pick on map"` satırını şununla değiştir:

```json
      "pick_from_map": "Pick on map",
      "pick_title": "Pick a muscle",
      "sheet_hint": "Tap a muscle — the list filters to it",
      "figure_male": "Male figure",
      "figure_female": "Female figure"
```

İki dosyanın da geçerli JSON olduğunu doğrula:

```bash
python -I -c "import json; [json.load(open(f, encoding='utf-8')) for f in ('assets/translations/tr.json', 'assets/translations/en.json')]; print('ok')"
```

Expected: `ok`

- [ ] **Step 8: Testlerin geçtiğini doğrula**

Run: `flutter test --no-pub test/features/workout/application/muscle_map_providers_test.dart test/features/workout/presentation/muscle_map_widget_test.dart`
Expected: Tüm testler geçer (4 eski + 5 yeni widget testi; 3 provider testi).

- [ ] **Step 9: Commit**

```bash
git add lib/features/workout/application/muscle_map_providers.dart \
  lib/features/workout/presentation/widgets/exercise_icon_badge.dart \
  lib/features/workout/presentation/widgets/muscle_map.dart assets/translations/tr.json assets/translations/en.json \
  test/features/workout/application/muscle_map_providers_test.dart \
  test/features/workout/presentation/muscle_map_widget_test.dart
git commit -m "feat(workout): add the figure toggle, map card and exercise icon badge

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 3: Kas haritası ekranı yeni yerleşimi

**Files:**
- Modify: `lib/features/workout/presentation/muscle_map_screen.dart`
- Test: `test/features/workout/presentation/muscle_map_screen_test.dart`

**Interfaces:**
- Consumes:
  - `mapFigureProvider`, `mapFigureChoiceProvider` (Task 2)
  - `MuscleMapControls`, `MuscleMapCard`, `ExerciseIconBadge` (Task 2)
  - `MuscleMap(figure:)` (Task 1)
- Produces: Ekran anahtarları değişmez (`muscle_map_screen`, `muscle_map_hint`, `muscle_map_selected`, `muscle_map_count`, `muscle_map_secondary_chip`, `muscle_map_exercise_<id>`, `muscle_map_empty`, `muscle_map_retry`).

- [ ] **Step 1: Testleri güncelle ve ekle**

`test/features/workout/presentation/muscle_map_screen_test.dart` dosyasında:

İmport'lara ekle:

```dart
import 'package:spor_takip/features/onboarding/application/profile_providers.dart';
import 'package:spor_takip/features/onboarding/domain/profile.dart';
import 'package:spor_takip/features/workout/presentation/widgets/exercise_icon_badge.dart';
import 'package:spor_takip/features/workout/presentation/widgets/muscle_map.dart';

import '../../progress/fixtures.dart';
```

`pumpScreen`'i şununla değiştir:

```dart
  Future<void> pumpScreen(
    WidgetTester tester, {
    Future<List<Exercise>> Function()? load,
    Profile? profile = testProfile,
  }) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(testApp(
      const MuscleMapScreen(),
      scaffold: false,
      overrides: [
        exercisesProvider.overrideWith((ref) => (load ?? () async => _all)()),
        profileProvider.overrideWith((ref) async => profile),
      ],
    ));
    await tester.pumpAndSettle();
  }

  BodyFigure shownFigure(WidgetTester tester) => tester.widget<MuscleMap>(find.byType(MuscleMap)).figure;
```

`main()` sonuna ekle:

```dart
  testWidgets('a female profile opens the female figure', (tester) async {
    await pumpScreen(tester, profile: testProfile.copyWith(gender: Gender.female));
    expect(shownFigure(tester), BodyFigure.female);

    await tester.tapAt(screenPointFor(
      tester,
      find.byKey(const Key('muscle_map_front')),
      BodyView.front,
      'chest',
      figure: BodyFigure.female,
    ));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('muscle_map_exercise_bench')), findsOneWidget);
  });

  testWidgets('the figure toggle switches figures and keeps the selection', (tester) async {
    await pumpScreen(tester);
    expect(shownFigure(tester), BodyFigure.male);
    await tapMuscle(tester, BodyView.front, 'chest');

    await tester.tap(find.byKey(const Key('figure_toggle_female')));
    await tester.pumpAndSettle();
    expect(shownFigure(tester), BodyFigure.female);
    expect(find.byKey(const Key('muscle_map_selected')), findsOneWidget);
    expect(find.byKey(const Key('muscle_map_exercise_bench')), findsOneWidget);
  });

  testWidgets('exercise rows lead with an equipment icon', (tester) async {
    await pumpScreen(tester);
    await tapMuscle(tester, BodyView.front, 'chest');
    final row = find.byKey(const Key('muscle_map_exercise_bench'));
    expect(find.descendant(of: row, matching: find.byType(ExerciseIconBadge)), findsOneWidget);
    expect(find.descendant(of: row, matching: find.byIcon(Icons.fitness_center)), findsOneWidget);
  });
```

- [ ] **Step 2: Yeni testlerin başarısız olduğunu doğrula**

Run: `flutter test --no-pub test/features/workout/presentation/muscle_map_screen_test.dart`
Expected: 3 yeni test FAIL. Ekran henüz figürü profilden almıyor, `figure_toggle_female` yok, satırlarda `ExerciseIconBadge` yok. Eski 5 test PASS.

- [ ] **Step 3: Ekranı yeniden yerleştir**

`lib/features/workout/presentation/muscle_map_screen.dart`:

İmport'lara ekle:

```dart
import '../application/muscle_map_providers.dart';
import 'widgets/exercise_icon_badge.dart';
```

`build` metodunu şununla değiştir:

```dart
  @override
  Widget build(BuildContext context) {
    final muscle = _muscle;
    final figure = ref.watch(mapFigureProvider);
    final lang = context.locale.languageCode;
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
                    onSelected: (m) => setState(() => _muscle = m),
                  ),
                ),
              ),
            ),
          ),
          if (muscle == null)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'workout.muscle_map.hint'.tr(),
                  key: const Key('muscle_map_hint'),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
              ),
            )
          else
            ..._results(context, muscle),
        ],
      ),
    );
  }
```

`_header`'ı şununla değiştir (dar ekranda sayı alta kayar):

```dart
  Widget _header(BuildContext context, String muscle, int count) {
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
                  child: Text(
                    'workout.muscle_map.count'.tr(namedArgs: {'n': '$count'}),
                    key: const Key('muscle_map_count'),
                    style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          AccentChip(
            key: const Key('muscle_map_secondary_chip'),
            label: 'workout.muscle_map.include_secondary'.tr(),
            selected: _includeSecondary,
            onSelected: (on) => setState(() => _includeSecondary = on),
          ),
        ],
      ),
    );
  }
```

`_row` içindeki `ListTile`'a `leading` ekle:

```dart
    return ListTile(
      key: Key('muscle_map_exercise_${e.id}'),
      leading: ExerciseIconBadge(equipment: e.equipment),
      title: Text(e.name),
      subtitle: subtitle.isEmpty ? null : Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => showExerciseDetailSheet(context, e, selectable: false),
    );
```

`_results` içindeki `Divider`'ın `indent` değerini 72 yap (ikon hizası):

```dart
                      separatorBuilder: (context, index) => const Divider(height: 1, indent: 72, endIndent: 16),
```

- [ ] **Step 4: Testlerin geçtiğini doğrula**

Run: `flutter test --no-pub test/features/workout/presentation/muscle_map_screen_test.dart`
Expected: 8 testin hepsi PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/workout/presentation/muscle_map_screen.dart test/features/workout/presentation/muscle_map_screen_test.dart
git commit -m "feat(workout): lay out the muscle map screen with the figure toggle and map card

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 4: Kas seç alt sayfası yeni yerleşimi

**Files:**
- Modify: `lib/features/workout/presentation/widgets/muscle_map_sheet.dart`
- Test: `test/features/workout/presentation/exercise_picker_screen_test.dart`

**Interfaces:**
- Consumes: `mapFigureProvider`, `mapFigureChoiceProvider`, `MuscleMapControls`, `MuscleMapCard`, `MuscleMap(figure:)`.
- Produces:
  - `showMuscleMapSheet(BuildContext context, {String? selected})` imzası değişmez.
  - Anahtarlar: `muscle_map_sheet_hint` (korunur), `muscle_map_sheet_close` (yeni), `muscle_map_card_label`.

- [ ] **Step 1: Testleri güncelle ve ekle**

`test/features/workout/presentation/exercise_picker_screen_test.dart` dosyasında:

İmport'lara ekle:

```dart
import 'package:spor_takip/features/onboarding/application/profile_providers.dart';
```

`wrap()` içindeki `overrides` listesine ekle:

```dart
          profileProvider.overrideWith((ref) async => null),
```

`main()` sonuna ekle:

```dart
  testWidgets('the map sheet shows the current muscle and closes with its button', (tester) async {
    await openPicker(tester);
    await tester.tap(find.byKey(const Key('muscle_filter_map')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('muscle_map_card_label')), findsNothing);

    await tester.tapAt(screenPointFor(tester, find.byKey(const Key('muscle_map_front')), BodyView.front, 'chest'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('muscle_filter_map')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('muscle_map_card_label')), findsOneWidget);

    await tester.tap(find.byKey(const Key('muscle_map_sheet_close')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('muscle_map_sheet_hint')), findsNothing);
    expect(find.byKey(const Key('exercise_tile_Pushups')), findsOneWidget);
    expect(find.byKey(const Key('exercise_tile_Barbell_Squat')), findsNothing);
  });

  testWidgets('the map sheet can switch to the female figure', (tester) async {
    await openPicker(tester);
    await tester.tap(find.byKey(const Key('muscle_filter_map')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('figure_toggle_female')));
    await tester.pumpAndSettle();
    await tester.tapAt(screenPointFor(
      tester,
      find.byKey(const Key('muscle_map_front')),
      BodyView.front,
      'chest',
      figure: BodyFigure.female,
    ));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('exercise_tile_Pushups')), findsOneWidget);
    expect(find.byKey(const Key('exercise_tile_Barbell_Squat')), findsNothing);
  });
```

- [ ] **Step 2: Yeni testlerin başarısız olduğunu doğrula**

Run: `flutter test --no-pub test/features/workout/presentation/exercise_picker_screen_test.dart`
Expected: 2 yeni test FAIL. `muscle_map_card_label`, `muscle_map_sheet_close` ve `figure_toggle_female` henüz yok. Eski testler PASS.

- [ ] **Step 3: Alt sayfayı yeniden yaz**

`lib/features/workout/presentation/widgets/muscle_map_sheet.dart` içeriğini tamamen şununla değiştir:

```dart
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/text_case.dart';
import '../../application/muscle_map_providers.dart';
import '../../domain/exercise_taxonomy.dart';
import '../../domain/muscle_map.dart';
import 'muscle_map.dart';

/// Haritadan kas seçtirir; kasa dokununca o kas, kapatılırsa null döner.
Future<String?> showMuscleMapSheet(BuildContext context, {String? selected}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _MuscleMapSheet(selected: selected),
  );
}

class _MuscleMapSheet extends ConsumerStatefulWidget {
  const _MuscleMapSheet({required this.selected});

  final String? selected;

  @override
  ConsumerState<_MuscleMapSheet> createState() => _MuscleMapSheetState();
}

class _MuscleMapSheetState extends ConsumerState<_MuscleMapSheet> {
  BodyView _view = BodyView.front;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final figure = ref.watch(mapFigureProvider);
    final selected = widget.selected;
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.8,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      upperCaseFor('workout.muscle_map.pick_title'.tr(), context.locale.languageCode),
                      style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                    ),
                  ),
                  IconButton.filledTonal(
                    key: const Key('muscle_map_sheet_close'),
                    tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              MuscleMapControls(
                view: _view,
                onViewChanged: (v) => setState(() => _view = v),
                figure: figure,
                onFigureChanged: (f) => ref.read(mapFigureChoiceProvider.notifier).choose(f),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: MuscleMapCard(
                  label: selected == null ? null : muscleLabelKey(selected).tr(),
                  child: MuscleMap(
                    view: _view,
                    figure: figure,
                    selected: selected,
                    onSelected: (muscle) => Navigator.of(context).pop(muscle),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'workout.muscle_map.sheet_hint'.tr(),
                key: const Key('muscle_map_sheet_hint'),
                textAlign: TextAlign.center,
                style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Testlerin geçtiğini doğrula**

Run: `flutter test --no-pub test/features/workout/presentation/exercise_picker_screen_test.dart`
Expected: Tüm testler geçer. "closing the map sheet keeps the current filter" testi de geçer; bu test `(5, 5)` noktasına dokunuyor ve o nokta sayfanın dışında kalıyor.

- [ ] **Step 5: Commit**

```bash
git add lib/features/workout/presentation/widgets/muscle_map_sheet.dart \
  test/features/workout/presentation/exercise_picker_screen_test.dart
git commit -m "feat(workout): lay out the pick-a-muscle sheet with a title, close button and figure toggle

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 5: Hareket seçici yeni yerleşimi

**Files:**
- Modify: `lib/features/workout/presentation/exercise_picker_screen.dart`
- Test: `test/features/workout/presentation/exercise_picker_screen_test.dart`

**Interfaces:**
- Consumes: `ExerciseIconBadge` (Task 2); çeviriler `workout.picker_count`, `workout.picker_search_clear`, `workout.custom_badge_short` (Task 2).
- Produces: Yeni anahtarlar `exercise_search_clear`, `exercise_picker_count`, `exercise_custom_badge_<id>`. Mevcut anahtarlar korunur.

- [ ] **Step 1: Testleri ekle**

`test/features/workout/presentation/exercise_picker_screen_test.dart` dosyasında:

İmport'lara ekle:

```dart
import 'package:spor_takip/features/workout/presentation/widgets/exercise_icon_badge.dart';
```

`main()` sonuna ekle:

```dart
  testWidgets('the clear button empties the search', (tester) async {
    await openPicker(tester);
    expect(find.byKey(const Key('exercise_search_clear')), findsNothing);

    await tester.enterText(find.byKey(const Key('exercise_search_field')), 'push');
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('exercise_tile_Barbell_Squat')), findsNothing);

    await tester.tap(find.byKey(const Key('exercise_search_clear')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('exercise_search_clear')), findsNothing);
    expect(find.byKey(const Key('exercise_tile_Barbell_Squat')), findsOneWidget);
    expect(tester.widget<TextField>(find.byKey(const Key('exercise_search_field'))).controller!.text, isEmpty);
  });

  testWidgets('the count follows the filtered list', (tester) async {
    await openPicker(tester);
    expect(find.byKey(const Key('exercise_picker_count')), findsOneWidget);

    await tester.enterText(find.byKey(const Key('exercise_search_field')), 'zzz');
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('exercise_picker_count')), findsNothing);
    expect(find.text('workout.picker_no_results'), findsOneWidget);
  });

  testWidgets('rows show an equipment icon and only custom ones a badge', (tester) async {
    await openPicker(tester);
    final squat = find.byKey(const Key('exercise_tile_Barbell_Squat'));
    expect(find.descendant(of: squat, matching: find.byType(ExerciseIconBadge)), findsOneWidget);
    expect(find.byKey(const Key('exercise_custom_badge_custom-0')), findsOneWidget);
    expect(find.byKey(const Key('exercise_custom_badge_Barbell_Squat')), findsNothing);
    expect(find.text('workout.custom_exercise_badge'), findsNothing);
  });
```

- [ ] **Step 2: Yeni testlerin başarısız olduğunu doğrula**

Run: `flutter test --no-pub test/features/workout/presentation/exercise_picker_screen_test.dart`
Expected: 3 yeni test FAIL. Eski testler PASS.

- [ ] **Step 3: Seçiciyi yeniden yerleştir**

`lib/features/workout/presentation/exercise_picker_screen.dart`:

İmport'lara ekle:

```dart
import '../../../shared/text_case.dart';
import 'widgets/exercise_icon_badge.dart';
```

State sınıfına arama denetleyicisini ekle (`String _query = '';` satırının üstüne):

```dart
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }
```

`build` içindeki `appBar` satırını değiştir:

```dart
      appBar: AppBar(
        title: Text(
          upperCaseFor('workout.picker_title'.tr(), context.locale.languageCode),
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
        ),
      ),
```

Arama alanının `Padding`'ini değiştir:

```dart
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              key: const Key('exercise_search_field'),
              controller: _search,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: 'workout.picker_search'.tr(),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        key: const Key('exercise_search_clear'),
                        tooltip: 'workout.picker_search_clear'.tr(),
                        icon: const Icon(Icons.cancel_outlined),
                        onPressed: () {
                          _search.clear();
                          setState(() => _query = '');
                        },
                      ),
                enabledBorder: _pill(Theme.of(context).colorScheme.outlineVariant, 1),
                focusedBorder: _pill(Theme.of(context).colorScheme.primary, 2),
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
```

Kas çip satırının `leading` değerini değiştir:

```dart
            leading: ActionChip(
              key: const Key('muscle_filter_map'),
              avatar: Icon(Icons.accessibility_new, size: 18, color: Theme.of(context).colorScheme.primary),
              label: Text(
                'workout.muscle_map.pick_from_map'.tr(),
                style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w600),
              ),
              side: BorderSide(color: Theme.of(context).colorScheme.primary),
              onPressed: _pickFromMap,
            ),
```

`Expanded` içindeki `data:` dalını şununla değiştir:

```dart
              data: (all) {
                final results = filterExercises(all, query: _query, muscle: _muscle, equipment: _equipment);
                if (results.isEmpty) return Center(child: Text('workout.picker_no_results'.tr()));
                final theme = Theme.of(context);
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                      child: Text(
                        upperCaseFor(
                          'workout.picker_count'.tr(namedArgs: {'n': '${results.length}'}),
                          context.locale.languageCode,
                        ),
                        key: const Key('exercise_picker_count'),
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 88),
                        itemCount: results.length,
                        separatorBuilder: (context, index) => ColoredBox(
                          color: _cardColor(theme),
                          child: const Divider(height: 1, indent: 72, endIndent: 16),
                        ),
                        itemBuilder: (context, index) => _tile(context, results[index], index, results.length),
                      ),
                    ),
                  ],
                );
              },
```

State sınıfına, `_chipRow`'un üstüne şu yardımcıları ekle:

```dart
  static OutlineInputBorder _pill(Color color, double width) => OutlineInputBorder(
        borderRadius: const BorderRadius.all(Radius.circular(28)),
        borderSide: BorderSide(color: color, width: width),
      );

  static Color _cardColor(ThemeData theme) => theme.cardTheme.color ?? theme.colorScheme.surfaceContainer;

  /// Kart görünümlü satır: ilk ve son satır yuvarlak köşeli (liste tembel kalır).
  Widget _tile(BuildContext context, Exercise e, int index, int count) {
    final theme = Theme.of(context);
    const radius = Radius.circular(16);
    return Material(
      color: _cardColor(theme),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: index == 0 ? radius : Radius.zero,
          bottom: index == count - 1 ? radius : Radius.zero,
        ),
      ),
      child: ListTile(
        key: Key('exercise_tile_${e.id}'),
        leading: ExerciseIconBadge(equipment: e.equipment),
        title: Row(
          children: [
            Flexible(child: Text(e.name, overflow: TextOverflow.ellipsis)),
            if (e.isCustom) ...[
              const SizedBox(width: 8),
              Container(
                key: Key('exercise_custom_badge_${e.id}'),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.12),
                  borderRadius: const BorderRadius.all(Radius.circular(999)),
                  border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.6)),
                ),
                child: Text(
                  upperCaseFor('workout.custom_badge_short'.tr(), context.locale.languageCode),
                  style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.primary, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ],
        ),
        subtitle: Text(e.primaryMuscles.map((m) => muscleLabelKey(m).tr()).join(' · ')),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => _openDetail(e),
        onLongPress: e.isCustom ? () => _deleteCustom(e) : null,
      ),
    );
  }
```

`_chipRow` içindeki yatay `padding` değerini `const EdgeInsets.symmetric(horizontal: 12)` yap; böylece çipler arama alanıyla hizalanır.

- [ ] **Step 4: Testlerin geçtiğini doğrula**

Run: `flutter test --no-pub test/features/workout/presentation/exercise_picker_screen_test.dart`
Expected: Tüm testler geçer.

- [ ] **Step 5: Kas haritası ve diğer seçici kullanıcılarının testleri**

Run:

```
flutter test --no-pub test/features/workout/presentation/muscle_map_screen_test.dart test/features/workout/presentation/muscle_map_widget_test.dart test/features/workout/presentation/programs_screen_test.dart
```

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/features/workout/presentation/exercise_picker_screen.dart \
  test/features/workout/presentation/exercise_picker_screen_test.dart
git commit -m "feat(workout): lay out the exercise picker with a clear button, count, icons and custom badge

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
Expected: Hepsi geçer. Beklenen sayı yaklaşık 500 + bu plandaki yeni testler: domain +2, provider +3, widget +5, ekran +3, seçici +5, yani ~518. Kesin sayı kullanıcının çıktısından alınır.

- [ ] **Step 3: Kullanıcıdan web release derlemesi ve manuel kontrol**

Kullanıcı `flutter build web --release --no-pub` çalıştırır ve `build/web`'i kendi terminalinden sunar: `python -m http.server 5555 --bind 127.0.0.1`.

Kontrol listesi (spec §8):
1. Kadın profilinde harita kadın figürüyle açılıyor; ön ve arka görünüm düzgün, kesik ya da kayma yok.
2. ♂/♀ geçişi figürü değiştiriyor ve seçili kas korunuyor; seçim ekrandan alt sayfaya taşınıyor.
3. Kadın figüründe göğüs, kanat, kalça ve abdüktör dokunuşları doğru kası seçiyor.
4. Kas haritası ekranı taslağa benziyor: figür kartı, parlama, başlık satırı, ikonlu liste.
5. Alt sayfa taslağa benziyor; etiket hapı ve kapatma düğmesi çalışıyor.
6. Hareket seçici taslağa benziyor; arama temizleme, sonuç sayısı, ÖZEL rozeti ve ikonlar doğru.
7. Haritadan seçilen kas listeyi süzüyor; ilgili çip seçili görünüyor.
8. Yaklaşık 360 px genişlikte taşma yok.

- [ ] **Step 4: PLAN.md satırı**

`PLAN.md` değişiklik günlüğü tablosunun sonuna, K1 satırının biçiminde bir satır ekle. İçeriği:
- tarih
- "**F5+ K2 (kas haritası: kadın figürü + Stitch yerleşimi) tamamlandı** (`f5p-kas-haritasi-k2` dalı, 6 görev)"
- özet: kadın figürü profilden + ♂/♀ oturumluk geçiş; ekran, alt sayfa ve seçici Stitch taslaklarına göre; ekipman ikonları, ÖZEL rozeti, arama temizleme, sonuç sayısı
- sapmalar (bu plandaki 3 madde)
- otomatik test sayısı
- manuel kontrol sonucu
- "Sıradaki: K3 (ısı haritası, programdan haritaya) ya da oyunlaştırma."

```bash
git add PLAN.md
git commit -m "docs: record K2 muscle map verification

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

- [ ] **Step 5: Dalı bitir**

superpowers:finishing-a-development-branch: Kullanıcı onay verirse `f5p-kas-haritasi-k2` master'a fast-forward ile birleştirilir, push edilir ve dal silinir.
