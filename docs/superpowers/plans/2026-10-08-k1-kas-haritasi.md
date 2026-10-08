# K1 — Kas Haritası Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Antrenman sekmesine ön/arka 2D kas haritası eklemek: kasa dokununca o kası çalıştıran hareketler listelenir; egzersiz seçicide "Haritadan seç" kas filtresini haritadan ayarlar.

**Architecture:** MIT lisanslı `react-native-body-highlighter` SVG yolları bir Python betiğiyle (yalnız standart kütüphane) mutlak `M/L/C/Q/Z` sayı listelerine çevrilip `muscle_map_data.dart` olarak üretilir. Saf alan katmanı (`domain/muscle_map.dart`) bu listelerden `Path` kurar, önbellekler ve dokunma noktasını kasa çevirir (`Path.contains`). `MuscleMap` widget'ı `CustomPainter` ile çizer; `MuscleMapScreen` (`/workout/muscles`) ve seçicideki alt sayfa bu widget'ı kullanır.

**Tech Stack:** Flutter (Riverpod 3, go_router, easy_localization), Python 3 (standart kütüphane).

**Spec:** `docs/superpowers/specs/2026-10-08-k1-kas-haritasi-design.md`

## Global Constraints

- Dal: `f5p-kas-haritasi` (açık, spec commit'li). Göç/deploy/yeni paket yok.
- Tüm `flutter` komutları `--no-pub` ile (bu makinede `pub get` takılıyor). Görevlerde yalnız ilgili test dosyaları çalıştırılır; tam paketi kullanıcı kendi terminalinde çalıştırır (`flutter test --no-pub -j 1`, Task 7). `flutter analyze --no-pub` birkaç dakika sürer (arka planda çalıştır); "No issues found!" vermeli.
- `dart format` çalıştırılmaz; mevcut biçime elle uyulur (satırlar ~120 karaktere kadar). Üretilen `muscle_map_data.dart` bu kuralın dışında (uzun satırlar).
- Testlerde çeviriler yüklenmez (`testApp` ham anahtar gösterir); metinler `Key` ve ham anahtarlarla doğrulanır.
- Tuval: `0..724 × 0..1448` (iki görünüm); görünür alan `bodyCrop = Rect.fromLTWH(40, 120, 644, 1250)`.
- Kas adları `muscleGroups`'taki 17 değerden biri (`lower back`, `middle back` boşluklu).
- Kaynak dosyalar `tool/body_highlighter/` altında **değiştirilmez**; üretilen Dart elle düzenlenmez.
- Bash aracı her komutta `/etc/...` izin uyarıları basıyor; zararsız, yok sayılır.
- Commit mesajları şu satırla biter: `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`

## Spec'ten bilinçli sapmalar (kullanıcıya bildirilecek)

1. **`BodyFit` sınıfı** (alan katmanında): `bodyCrop`'u bir boyuta oranı koruyarak ortalayan dönüşüm (`toCanvas` / `toLocal`). Widget dokunmayı, testler dokunulacak ekran noktasını aynı sınıfla hesaplar.
2. **`BodyViewToggle` ortak widget'ı:** ÖN/ARKA `SegmentedButton`'ı ekran ve alt sayfada aynı.
3. **Liste `Card` yerine `DecoratedSliver`:** göğüs gibi kaslarda ~80 hareket var; kart görünümlü ama tembel (`SliverList.separated`) liste.
4. **Yükleme/hata durumu yalnız kas seçiliyken görünür:** seçim yokken ipucu gösterilir, hareket verisine o an gerek yok.
5. **Üretici öz kontrolü örneklemeyle:** kaynak eğriler (yaylar dahil, kübiğe çevirmeden) ve üretilen eğriler 16–32 noktadan örneklenip sınır kutuları karşılaştırılır (≤2 birim). Betik bu planı yazarken gerçek kaynakla çalıştırıldı: ön 88, arka 69 şekil; `upper-back` yükseklikleri 51/74 (orta sırt) ve 183/184 (kanat), `gluteal` 49 (abdüktör) ve 141/142 (kalça).
6. **Lisans testi `LicenseRegistry.reset()` ile başlar:** test ortamında Flutter'ın kendi NOTICES toplayıcısı asset bulamayabilir.
7. **Web derlemesi `--no-pub`:** `pubspec.yaml`'a asset eklendiği için `flutter build web` aksi halde `pub get` dener.

## Dosya haritası

| Dosya | Sorumluluk |
|---|---|
| `tool/body_highlighter/{bodyFront.ts,bodyBack.ts,SvgMaleWrapper.tsx,LICENSE}` (yeni) | Değiştirilmemiş MIT kaynak |
| `tool/generate_muscle_paths.py` (yeni) | SVG → mutlak komut listeleri, kas eşlemesi, öz kontrol, Dart üretimi |
| `lib/features/workout/domain/muscle_map_data.dart` (üretilen) | `BodyView`, `MuscleShape`, siluetler, şekiller |
| `lib/features/workout/domain/muscle_map.dart` (yeni) | `bodyCrop`, `BodyFit`, `buildPath`, önbellek, `muscleAt`, `musclesIn` |
| `lib/features/workout/domain/exercise_filter.dart` | `exercisesForMuscle` |
| `lib/features/workout/presentation/widgets/muscle_map.dart` (yeni) | `MuscleMap` (çizim + dokunma), `BodyViewToggle` |
| `lib/features/workout/presentation/muscle_map_screen.dart` (yeni) | Göz atma ekranı |
| `lib/features/workout/presentation/widgets/muscle_map_sheet.dart` (yeni) | `showMuscleMapSheet` |
| `lib/features/workout/presentation/exercise_picker_screen.dart` | "Haritadan seç" çipi |
| `lib/features/workout/presentation/programs_screen.dart` | Harita ikonu |
| `lib/core/router.dart` | `/workout/muscles` |
| `lib/core/licenses.dart` (yeni), `lib/main.dart`, `LICENSES/body-highlighter.txt` (yeni), `pubspec.yaml` | Lisans kaydı |
| `assets/translations/tr.json`, `en.json` | `workout.muscle_map.*` |
| `test/features/workout/muscle_map_points.dart` (yeni) | Testlerde dokunulacak nokta bulucu |

---

### Task 1: Kaynak dosyalar, üretici betik ve üretilen veri

**Files:**
- Create: `tool/body_highlighter/bodyFront.ts`, `bodyBack.ts`, `SvgMaleWrapper.tsx`, `LICENSE` (indirilir)
- Create: `tool/generate_muscle_paths.py`
- Create (üretilen): `lib/features/workout/domain/muscle_map_data.dart`
- Test: `test/features/workout/domain/muscle_map_data_test.dart`

**Interfaces:**
- Produces (`muscle_map_data.dart`): `enum BodyView { front, back }`; `class MuscleShape { const MuscleShape(this.muscle, this.commands); final String? muscle; final List<double> commands; }`; `const bodyCanvasWidth = 724.0`; `const bodyCanvasHeight = 1448.0`; `const Map<BodyView, List<double>> bodySilhouettes`; `const Map<BodyView, List<MuscleShape>> muscleShapes`. Komut kodları: 0 = M (x y), 1 = L (x y), 2 = C (x1 y1 x2 y2 x y), 3 = Q (x1 y1 x y), 4 = Z.

- [ ] **Step 1: Write the failing test**

`test/features/workout/domain/muscle_map_data_test.dart`:

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

void main() {
  test('every taxonomy muscle is drawn in at least one view', () {
    final drawn = {
      for (final view in BodyView.values)
        for (final shape in muscleShapes[view]!) ?shape.muscle,
    };
    expect(drawn, unorderedEquals(muscleGroups));
  });

  test('shape counts match the source data', () {
    expect(muscleShapes[BodyView.front], hasLength(88));
    expect(muscleShapes[BodyView.back], hasLength(69));
  });

  test('silhouettes and shapes are well-formed command lists', () {
    for (final view in BodyView.values) {
      _expectWellFormed(bodySilhouettes[view]!, '${view.name} silhouette');
      for (final (i, shape) in muscleShapes[view]!.indexed) {
        _expectWellFormed(shape.commands, '${view.name} shape $i (${shape.muscle})');
      }
    }
  });

  test('canvas size', () {
    expect(bodyCanvasWidth, 724);
    expect(bodyCanvasHeight, 1448);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test --no-pub test/features/workout/domain/muscle_map_data_test.dart`
Expected: FAIL — derleme hatası, `muscle_map_data.dart` yok.

- [ ] **Step 3: Kaynak dosyaları indir**

PowerShell, proje kökünden:

```powershell
$dir = "tool/body_highlighter"; New-Item -ItemType Directory -Force $dir | Out-Null
$base = "https://raw.githubusercontent.com/HichamELBSI/react-native-body-highlighter/main"
foreach ($f in @("assets/bodyFront.ts", "assets/bodyBack.ts", "components/SvgMaleWrapper.tsx", "LICENSE")) {
  Invoke-WebRequest -UseBasicParsing "$base/$f" -OutFile (Join-Path $dir (Split-Path $f -Leaf)) -ErrorAction Stop
}
Get-ChildItem $dir | Select-Object Name, Length
```

Expected: dört dosya; boyutlar yaklaşık `bodyFront.ts` 25205, `bodyBack.ts` 21468, `SvgMaleWrapper.tsx` 19124, `LICENSE` 1073 bayt. `LICENSE` içinde `Copyright (c) 2022 ELABBASSI Hicham` satırı olmalı. Dosyalar **değiştirilmez** (yalnız veri olarak okunur; çalıştırılmaz).

- [ ] **Step 4: Üretici betiği yaz**

`tool/generate_muscle_paths.py` (bu içerik plan yazılırken gerçek kaynakla çalıştırılıp doğrulandı):

```python
"""Kas haritası yollarını üretir (K1 spec §3.2).

Proje kökünden: python tool/generate_muscle_paths.py
Kaynak: tool/body_highlighter/ (react-native-body-highlighter, MIT, © 2022 ELABBASSI Hicham).
Çıktı: lib/features/workout/domain/muscle_map_data.dart — yalnız mutlak M/L/C/Q/Z.
"""
import math
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / 'tool' / 'body_highlighter'
OUT = ROOT / 'lib' / 'features' / 'workout' / 'domain' / 'muscle_map_data.dart'
BACK_SHIFT = 724.0
TOLERANCE = 2.0

M, L, C, Q, Z = 0, 1, 2, 3, 4
ARITY = {M: 2, L: 2, C: 6, Q: 4, Z: 0}

FRONT_MUSCLES = {
    'chest': 'chest', 'deltoids': 'shoulders', 'biceps': 'biceps', 'triceps': 'triceps',
    'forearm': 'forearms', 'abs': 'abdominals', 'obliques': 'abdominals', 'quadriceps': 'quadriceps',
    'adductors': 'adductors', 'calves': 'calves', 'tibialis': 'calves', 'trapezius': 'traps', 'neck': 'neck',
}
BACK_MUSCLES = {
    'deltoids': 'shoulders', 'trapezius': 'traps', 'triceps': 'triceps', 'lower-back': 'lower back',
    'forearm': 'forearms', 'adductors': 'adductors', 'hamstring': 'hamstrings', 'calves': 'calves', 'neck': 'neck',
}
# Yüksekliğe göre bölünen arka parçalar: (eşik, uzunsa, kısaysa).
BACK_SPLIT = {'upper-back': (120, 'lats', 'middle back'), 'gluteal': (80, 'glutes', 'abductors')}
DECOR = {'head', 'hands', 'knees', 'ankles', 'feet'}
SKIP = {'hair'}

_NUM = re.compile(r'[-+]?(?:\d+\.?\d*|\.\d+)(?:[eE][-+]?\d+)?')


def tokenize(d):
    """Komut harfleri ve sayılar; yay bayrakları tek karakter ('012.89' → 0, 1, 2.89)."""
    tokens, i, cmd, argi = [], 0, None, 0
    while i < len(d):
        ch = d[i]
        if ch.isalpha():
            cmd, argi = ch, 0
            tokens.append(ch)
            i += 1
        elif ch in ' ,\t\r\n':
            i += 1
        else:
            if cmd in 'Aa' and argi % 7 in (3, 4):
                if ch not in '01':
                    raise ValueError(f'bad arc flag at {i}: {d[i:i + 10]}')
                tokens.append(float(ch))
                i += 1
            else:
                m = _NUM.match(d, i)
                if not m:
                    raise ValueError(f'bad number at {i}: {d[i:i + 10]}')
                tokens.append(float(m.group()))
                i = m.end()
            argi += 1
    return tokens


def _arc_center(x1, y1, rx, ry, phi_deg, fa, fs, x2, y2):
    """SVG 1.1 F.6.5 endpoint→center: (cx, cy, rx, ry, cos φ, sin φ, θ1, Δθ)."""
    rx, ry = abs(rx), abs(ry)
    phi = math.radians(phi_deg)
    cp, sp = math.cos(phi), math.sin(phi)
    dx, dy = (x1 - x2) / 2, (y1 - y2) / 2
    x1p, y1p = cp * dx + sp * dy, -sp * dx + cp * dy
    lam = (x1p / rx) ** 2 + (y1p / ry) ** 2
    if lam > 1:
        rx, ry = rx * math.sqrt(lam), ry * math.sqrt(lam)
    num = rx * rx * ry * ry - rx * rx * y1p * y1p - ry * ry * x1p * x1p
    den = rx * rx * y1p * y1p + ry * ry * x1p * x1p
    coef = math.sqrt(max(0.0, num / den)) if den else 0.0
    if fa == fs:
        coef = -coef
    cxp, cyp = coef * rx * y1p / ry, -coef * ry * x1p / rx
    cx = cp * cxp - sp * cyp + (x1 + x2) / 2
    cy = sp * cxp + cp * cyp + (y1 + y2) / 2
    t1 = math.atan2((y1p - cyp) / ry, (x1p - cxp) / rx)
    dt = math.atan2((-y1p - cyp) / ry, (-x1p - cxp) / rx) - t1
    if fs and dt < 0:
        dt += 2 * math.pi
    elif not fs and dt > 0:
        dt -= 2 * math.pi
    return cx, cy, rx, ry, cp, sp, t1, dt


def _is_line_arc(x1, y1, rx, ry, x2, y2):
    return rx == 0 or ry == 0 or (x1, y1) == (x2, y2)


def _arc_point(cx, cy, rx, ry, cp, sp, t):
    ct, st = math.cos(t), math.sin(t)
    return cx + rx * ct * cp - ry * st * sp, cy + rx * ct * sp + ry * st * cp


def _arc_to_cubics(x1, y1, rx, ry, phi_deg, fa, fs, x2, y2):
    """SVG yayı → ≤90° dilimli kübikler."""
    if _is_line_arc(x1, y1, rx, ry, x2, y2):
        return [] if (x1, y1) == (x2, y2) else [(x1, y1, x2, y2, x2, y2)]
    cx, cy, rx, ry, cp, sp, t1, dt = _arc_center(x1, y1, rx, ry, phi_deg, fa, fs, x2, y2)
    n = max(1, math.ceil(abs(dt) / (math.pi / 2) - 1e-9))
    step = dt / n
    k = 4 / 3 * math.tan(step / 4)

    def deriv(t):
        ct, st = math.cos(t), math.sin(t)
        return -rx * st * cp - ry * ct * sp, -rx * st * sp + ry * ct * cp

    out = []
    for i in range(n):
        a, b = t1 + i * step, t1 + (i + 1) * step
        p0, p3 = _arc_point(cx, cy, rx, ry, cp, sp, a), _arc_point(cx, cy, rx, ry, cp, sp, b)
        d0, d3 = deriv(a), deriv(b)
        out.append((p0[0] + k * d0[0], p0[1] + k * d0[1], p3[0] - k * d3[0], p3[1] - k * d3[1], p3[0], p3[1]))
    out[-1] = (*out[-1][:4], x2, y2)
    return out


def _arc_samples(x1, y1, rx, ry, phi_deg, fa, fs, x2, y2, steps=32):
    """Öz kontrol için yayın kendisinden noktalar (kübik yaklaşım olmadan)."""
    if _is_line_arc(x1, y1, rx, ry, x2, y2):
        return [(x2, y2)]
    cx, cy, rx, ry, cp, sp, t1, dt = _arc_center(x1, y1, rx, ry, phi_deg, fa, fs, x2, y2)
    return [_arc_point(cx, cy, rx, ry, cp, sp, t1 + dt * i / steps) for i in range(1, steps + 1)]


def convert(d, shift=0.0):
    """SVG yolu → (komut listesi, kaynak örnek noktaları). Kaydırma x'ten çıkarılır."""
    tokens = tokenize(d)
    out, samples = [], []
    x = y = sx = sy = 0.0
    last_c = last_q = None  # yansıtma için önceki kontrol noktası
    i, cmd = 0, None

    def nums(n):
        nonlocal i
        vals = tokens[i:i + n]
        if len(vals) < n or any(isinstance(v, str) for v in vals):
            raise ValueError(f'missing args for {cmd} at token {i}')
        i += n
        return vals

    def emit(code, *pts):
        out.append(code)
        for j, v in enumerate(pts):
            out.append(v - shift if j % 2 == 0 else v)

    def quad_samples(x0, y0, qx, qy, ex, ey):
        for s in range(1, 17):
            t = s / 16
            u = 1 - t
            samples.append((u * u * x0 + 2 * u * t * qx + t * t * ex, u * u * y0 + 2 * u * t * qy + t * t * ey))

    def cubic_samples(x0, y0, ax, ay, bx, by, ex, ey):
        for s in range(1, 17):
            t = s / 16
            u = 1 - t
            samples.append((u ** 3 * x0 + 3 * u * u * t * ax + 3 * u * t * t * bx + t ** 3 * ex,
                            u ** 3 * y0 + 3 * u * u * t * ay + 3 * u * t * t * by + t ** 3 * ey))

    while i < len(tokens):
        if isinstance(tokens[i], str):
            cmd = tokens[i]
            i += 1
            if cmd in 'Zz':
                out.append(Z)
                x, y = sx, sy
                last_c = last_q = None
                continue
        elif cmd is None:
            raise ValueError('path does not start with a command')
        rel = cmd.islower()
        ox, oy = (x, y) if rel else (0.0, 0.0)
        up = cmd.upper()
        if up == 'M':
            px, py = nums(2)
            x, y = px + ox, py + oy
            sx, sy = x, y
            emit(M, x, y)
            samples.append((x, y))
            cmd = 'l' if rel else 'L'  # ardışık çiftler L sayılır
            last_c = last_q = None
        elif up in 'LHV':
            if up == 'L':
                px, py = nums(2)
                nx, ny = px + ox, py + oy
            elif up == 'H':
                (px,) = nums(1)
                nx, ny = px + ox, y
            else:
                (py,) = nums(1)
                nx, ny = x, py + oy
            x, y = nx, ny
            emit(L, x, y)
            samples.append((x, y))
            last_c = last_q = None
        elif up in 'CS':
            if up == 'C':
                ax, ay, bx, by, ex, ey = nums(6)
                ax, ay = ax + ox, ay + oy
            else:
                bx, by, ex, ey = nums(4)
                ax, ay = (2 * x - last_c[0], 2 * y - last_c[1]) if last_c else (x, y)
            bx, by, ex, ey = bx + ox, by + oy, ex + ox, ey + oy
            emit(C, ax, ay, bx, by, ex, ey)
            cubic_samples(x, y, ax, ay, bx, by, ex, ey)
            x, y = ex, ey
            last_c, last_q = (bx, by), None
        elif up in 'QT':
            if up == 'Q':
                qx, qy, ex, ey = nums(4)
                qx, qy = qx + ox, qy + oy
            else:
                ex, ey = nums(2)
                qx, qy = (2 * x - last_q[0], 2 * y - last_q[1]) if last_q else (x, y)
            ex, ey = ex + ox, ey + oy
            emit(Q, qx, qy, ex, ey)
            quad_samples(x, y, qx, qy, ex, ey)
            x, y = ex, ey
            last_q, last_c = (qx, qy), None
        elif up == 'A':
            rx, ry, rot, fa, fs, ex, ey = nums(7)
            ex, ey = ex + ox, ey + oy
            samples.extend(_arc_samples(x, y, rx, ry, rot, fa, fs, ex, ey))
            for c in _arc_to_cubics(x, y, rx, ry, rot, fa, fs, ex, ey):
                emit(C, *c)
            x, y = ex, ey
            last_c = last_q = None
        else:
            raise ValueError(f'unsupported command {cmd}')
    samples = [(px - shift, py) for px, py in samples]
    return out, samples


def bbox_of_commands(cmds):
    """Üretilen komutları örnekleyerek sınır kutusu (çıktının bağımsız kontrolü)."""
    pts, i, cur, start = [], 0, (0.0, 0.0), (0.0, 0.0)
    while i < len(cmds):
        code = cmds[i]
        args = cmds[i + 1:i + 1 + ARITY[code]]
        i += 1 + ARITY[code]
        if code == M:
            cur = start = (args[0], args[1])
            pts.append(cur)
        elif code == L:
            cur = (args[0], args[1])
            pts.append(cur)
        elif code == C:
            for s in range(1, 17):
                t = s / 16
                u = 1 - t
                pts.append((u ** 3 * cur[0] + 3 * u * u * t * args[0] + 3 * u * t * t * args[2] + t ** 3 * args[4],
                            u ** 3 * cur[1] + 3 * u * u * t * args[1] + 3 * u * t * t * args[3] + t ** 3 * args[5]))
            cur = (args[4], args[5])
        elif code == Q:
            for s in range(1, 17):
                t = s / 16
                u = 1 - t
                pts.append((u * u * cur[0] + 2 * u * t * args[0] + t * t * args[2],
                            u * u * cur[1] + 2 * u * t * args[1] + t * t * args[3]))
            cur = (args[2], args[3])
        else:
            cur = start
    return _bbox(pts)


def _bbox(pts):
    xs, ys = [p[0] for p in pts], [p[1] for p in pts]
    return min(xs), min(ys), max(xs), max(ys)


def rounded(cmds):
    out, i = [], 0
    while i < len(cmds):
        code = cmds[i]
        out.append(code)
        out.extend(round(v, 1) for v in cmds[i + 1:i + 1 + ARITY[code]])
        i += 1 + ARITY[code]
    return out


def checked(d, shift, label):
    cmds, samples = convert(d, shift)
    cmds = rounded(cmds)
    got, want = bbox_of_commands(cmds), _bbox(samples)
    if max(abs(a - b) for a, b in zip(got, want)) > TOLERANCE:
        raise SystemExit(f'{label}: bbox mismatch generated={got} source={want}')
    return cmds, got


_PART = re.compile(r'slug:\s*"([^"]+)"(.*?)(?=slug:|\Z)', re.S)
_SIDE = re.compile(r'(left|right|common)\s*:\s*\[(.*?)\]', re.S)
_STR = re.compile(r'"([^"]+)"')


def parse_parts(ts_text):
    """[(slug, [d, ...])] — dosyadaki sırayla; her parçada left, right, common sırası kaynaktaki gibi."""
    parts = []
    for m in _PART.finditer(ts_text):
        slug, body = m.group(1), m.group(2)
        paths = [s for side in _SIDE.finditer(body) for s in _STR.findall(side.group(2))]
        parts.append((slug, paths))
    return parts


def muscle_for(view, slug, height):
    if slug in DECOR:
        return None
    table = FRONT_MUSCLES if view == 'front' else BACK_MUSCLES
    if slug in table:
        return table[slug]
    if view == 'back' and slug in BACK_SPLIT:
        limit, tall, short = BACK_SPLIT[slug]
        return tall if height > limit else short
    raise SystemExit(f'unknown slug for {view}: {slug}')


def shapes_for(view, ts_text, shift):
    shapes = []
    for slug, paths in parse_parts(ts_text):
        if slug in SKIP:
            continue
        for n, d in enumerate(paths):
            cmds, (x0, y0, x1, y1) = checked(d, shift, f'{view}/{slug}#{n}')
            shapes.append((muscle_for(view, slug, y1 - y0), cmds, slug))
    return shapes


def silhouette(tsx_text, view, shift):
    paths = re.findall(r'd="([^"]+)"', tsx_text)
    if len(paths) != 2:
        raise SystemExit(f'expected 2 outline paths, found {len(paths)}')
    d = paths[0] if view == 'front' else paths[1]
    cmds, _ = checked(d, shift, f'{view}/outline')
    return cmds


def fmt_list(cmds):
    """Kodlar tamsayı, sayılar bir ondalık ('.0' atılır)."""
    parts = []
    for v in cmds:
        if isinstance(v, int):
            parts.append(str(v))
        else:
            text = f'{v:.1f}'
            parts.append(text[:-2] if text.endswith('.0') else text)
    return ', '.join(parts)


def main():
    front_ts = (SRC / 'bodyFront.ts').read_text(encoding='utf-8')
    back_ts = (SRC / 'bodyBack.ts').read_text(encoding='utf-8')
    wrapper = (SRC / 'SvgMaleWrapper.tsx').read_text(encoding='utf-8')
    views = {
        'front': (shapes_for('front', front_ts, 0.0), silhouette(wrapper, 'front', 0.0)),
        'back': (shapes_for('back', back_ts, BACK_SHIFT), silhouette(wrapper, 'back', BACK_SHIFT)),
    }
    lines = [
        '// OTOMATİK ÜRETİLDİ — tool/generate_muscle_paths.py. Elle düzenleme.',
        '// Vücut yolları: react-native-body-highlighter, MIT License, Copyright (c) 2022 ELABBASSI Hicham.',
        '',
        'enum BodyView { front, back }',
        '',
        '/// Komut kodları: 0 = M (x y), 1 = L (x y), 2 = C (x1 y1 x2 y2 x y), 3 = Q (x1 y1 x y), 4 = Z.',
        'class MuscleShape {',
        '  const MuscleShape(this.muscle, this.commands);',
        '  final String? muscle; // muscleGroups\'tan biri; süs parçalarında null',
        '  final List<double> commands;',
        '}',
        '',
        'const bodyCanvasWidth = 724.0;',
        'const bodyCanvasHeight = 1448.0;',
        '',
        'const Map<BodyView, List<double>> bodySilhouettes = {',
    ]
    for view, (_, outline) in views.items():
        lines.append(f'  BodyView.{view}: <double>[{fmt_list(outline)}],')
    lines += ['};', '', 'const Map<BodyView, List<MuscleShape>> muscleShapes = {']
    for view, (shapes, _) in views.items():
        lines.append(f'  BodyView.{view}: [')
        for muscle, cmds, slug in shapes:
            name = 'null' if muscle is None else f"'{muscle}'"
            lines.append(f'    // {slug}')
            lines.append(f'    MuscleShape({name}, <double>[{fmt_list(cmds)}]),')
        lines.append('  ],')
    lines += ['};', '']
    OUT.write_text('\n'.join(lines), encoding='utf-8', newline='\n')
    counts = {v: len(s) for v, (s, _) in views.items()}
    print(f'wrote {OUT.relative_to(ROOT)}: {counts}')


if __name__ == '__main__':
    sys.exit(main())
```

- [ ] **Step 5: Betiği çalıştır**

Run: `python tool/generate_muscle_paths.py`
Expected: `wrote lib\features\workout\domain\muscle_map_data.dart: {'front': 88, 'back': 69}` (Windows'ta ters bölü). Dosya ~92 KB; başı:

```dart
// OTOMATİK ÜRETİLDİ — tool/generate_muscle_paths.py. Elle düzenleme.
// Vücut yolları: react-native-body-highlighter, MIT License, Copyright (c) 2022 ELABBASSI Hicham.

enum BodyView { front, back }
```

Betik `bbox mismatch` ya da `unknown slug` ile çıkarsa kaynak beklenenden farklıdır: dur ve bildir (eşikleri/eşlemeyi tahminle değiştirme).

- [ ] **Step 6: Run test to verify it passes**

Run: `flutter test --no-pub test/features/workout/domain/muscle_map_data_test.dart`
Expected: PASS (4 test).

- [ ] **Step 7: Commit**

```bash
git add tool/body_highlighter tool/generate_muscle_paths.py lib/features/workout/domain/muscle_map_data.dart test/features/workout/domain/muscle_map_data_test.dart
git commit -m "feat(workout): generate muscle map paths from body-highlighter data

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 2: Alan katmanı — yol kurma, dokunma, kasa göre hareketler

**Files:**
- Create: `lib/features/workout/domain/muscle_map.dart`
- Modify: `lib/features/workout/domain/exercise_filter.dart`
- Create: `test/features/workout/muscle_map_points.dart`
- Test: `test/features/workout/domain/muscle_map_test.dart`, `test/features/workout/domain/exercise_filter_test.dart`

**Interfaces:**
- Consumes: Task 1'in `BodyView`, `MuscleShape`, `bodySilhouettes`, `muscleShapes`, `bodyCanvasWidth`, `bodyCanvasHeight`.
- Produces (`domain/muscle_map.dart`, `BodyView`'ı da export eder):
  - `const Rect bodyCrop`
  - `class BodyFit { factory BodyFit(Size size); final double scale; final Offset offset; Offset toCanvas(Offset local); Offset toLocal(Offset canvas); }` — yerel = tuval × `scale` + `offset`
  - `Path buildPath(List<double> commands)`
  - `List<(String?, Path)> musclePaths(BodyView view)` (önbellekli, kaynak sırası)
  - `Path silhouettePath(BodyView view)` (önbellekli)
  - `String? muscleAt(BodyView view, Offset canvasPoint)`
  - `Set<String> musclesIn(BodyView view)`
- Produces (`exercise_filter.dart`): `List<Exercise> exercisesForMuscle(List<Exercise> all, String muscle, {bool includeSecondary = false})`
- Produces (test yardımcısı `test/features/workout/muscle_map_points.dart`): `Offset? canvasPointFor(BodyView view, String muscle)`, `Offset? decorPoint(BodyView view)`, `Offset screenPointFor(WidgetTester tester, Finder map, BodyView view, String muscle)`

- [ ] **Step 1: Write the failing tests**

`test/features/workout/muscle_map_points.dart`:

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
Offset? canvasPointFor(BodyView view, String muscle) {
  for (final (m, path) in musclePaths(view)) {
    if (m != muscle) continue;
    for (final p in _grid(path.getBounds())) {
      if (path.contains(p) && muscleAt(view, p) == muscle) return p;
    }
  }
  return null;
}

/// Bir süs parçasının (baş, el, diz…) içinde olup hiçbir kas şeklinde olmayan nokta.
Offset? decorPoint(BodyView view) {
  final paths = musclePaths(view);
  for (final (m, path) in paths) {
    if (m != null) continue;
    for (final p in _grid(path.getBounds())) {
      if (path.contains(p) && !paths.any((s) => s.$1 != null && s.$2.contains(p))) return p;
    }
  }
  return null;
}

/// [map] (MuscleMap içindeki `muscle_map_<view>` kutusu) üzerinde [muscle]'a dokunulacak genel ekran noktası.
Offset screenPointFor(WidgetTester tester, Finder map, BodyView view, String muscle) {
  final rect = tester.getRect(map);
  return rect.topLeft + BodyFit(rect.size).toLocal(canvasPointFor(view, muscle)!);
}
```

`test/features/workout/domain/muscle_map_test.dart`:

```dart
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
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

  test('all paths stay on the canvas and inside the crop', () {
    const canvas = Rect.fromLTWH(0, 0, bodyCanvasWidth, bodyCanvasHeight);
    for (final view in BodyView.values) {
      final silhouette = silhouettePath(view).getBounds();
      expect(bodyCrop.intersect(silhouette), silhouette, reason: '${view.name} silhouette inside crop');
      for (final (muscle, path) in musclePaths(view)) {
        final b = path.getBounds();
        expect(canvas.intersect(b), b, reason: '${view.name} $muscle on canvas');
      }
    }
  });

  test('every drawn muscle can be tapped', () {
    for (final view in BodyView.values) {
      for (final muscle in musclesIn(view)) {
        expect(canvasPointFor(view, muscle), isNotNull, reason: '${view.name} $muscle');
      }
    }
  });

  test('views hold the expected muscles', () {
    expect(musclesIn(BodyView.front), containsAll(['chest', 'abdominals', 'biceps', 'quadriceps']));
    expect(musclesIn(BodyView.front), isNot(contains('lats')));
    expect(musclesIn(BodyView.back), containsAll(['lats', 'middle back', 'lower back', 'glutes', 'abductors']));
    expect(musclesIn(BodyView.back), isNot(contains('chest')));
    expect({...musclesIn(BodyView.front), ...musclesIn(BodyView.back)}, unorderedEquals(muscleGroups));
  });

  test('empty canvas and decoration parts return no muscle', () {
    expect(muscleAt(BodyView.front, Offset.zero), isNull);
    for (final view in BodyView.values) {
      final p = decorPoint(view);
      expect(p, isNotNull, reason: '${view.name} has a decoration-only point');
      expect(muscleAt(view, p!), isNull);
    }
  });

  test('paths are cached', () {
    expect(identical(musclePaths(BodyView.back), musclePaths(BodyView.back)), isTrue);
    expect(identical(silhouettePath(BodyView.front), silhouettePath(BodyView.front)), isTrue);
  });

  test('BodyFit centers the crop and round-trips points', () {
    final tall = BodyFit(const Size(322, 1000));
    expect(tall.scale, 0.5);
    expect(tall.toLocal(bodyCrop.topLeft), const Offset(0, 187.5));

    final wide = BodyFit(const Size(1000, 625));
    expect(wide.scale, 0.5);
    expect(wide.toLocal(bodyCrop.topLeft), const Offset(339, 0));
    final back = wide.toCanvas(wide.toLocal(const Offset(300, 700)));
    expect(back.dx, closeTo(300, 1e-9));
    expect(back.dy, closeTo(700, 1e-9));
  });
}
```

`test/features/workout/domain/exercise_filter_test.dart` — `main()` içinde mevcut testlerin ardına ekle:

```dart
  test('exercisesForMuscle lists primary movers by name, secondary ones after', () {
    const all = [
      Exercise(id: 'pu', name: 'pushups', primaryMuscles: ['chest'], secondaryMuscles: ['triceps']),
      Exercise(id: 'dp', name: 'Dips', primaryMuscles: ['triceps'], secondaryMuscles: ['chest']),
      Exercise(id: 'bp', name: 'Bench Press', primaryMuscles: ['chest']),
      Exercise(id: 'cf', name: 'Cable Fly', primaryMuscles: ['shoulders'], secondaryMuscles: ['chest']),
      Exercise(id: 'sq', name: 'Squat', primaryMuscles: ['quadriceps']),
    ];
    expect(exercisesForMuscle(all, 'chest').map((e) => e.id), ['bp', 'pu']);
    expect(exercisesForMuscle(all, 'chest', includeSecondary: true).map((e) => e.id), ['bp', 'pu', 'cf', 'dp']);
    expect(exercisesForMuscle(all, 'lats'), isEmpty);
  });
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test --no-pub test/features/workout/domain/muscle_map_test.dart test/features/workout/domain/exercise_filter_test.dart`
Expected: FAIL — derleme hatası (`muscle_map.dart` yok, `exercisesForMuscle` tanımsız).

- [ ] **Step 3: Write minimal implementation**

`lib/features/workout/domain/muscle_map.dart`:

```dart
import 'dart:math' as math;
import 'dart:ui';

import 'muscle_map_data.dart';

export 'muscle_map_data.dart' show BodyView;

/// İki görünümde de figürün göründüğü tuval alanı (spec §4).
const bodyCrop = Rect.fromLTWH(40, 120, 644, 1250);

/// [bodyCrop]'u bir boyuta oranı koruyarak ortalar: yerel = tuval × [scale] + [offset].
class BodyFit {
  factory BodyFit(Size size) {
    final scale = math.min(size.width / bodyCrop.width, size.height / bodyCrop.height);
    final pad = Offset((size.width - bodyCrop.width * scale) / 2, (size.height - bodyCrop.height * scale) / 2);
    return BodyFit._(scale, pad - bodyCrop.topLeft * scale);
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

final _muscleCache = <BodyView, List<(String?, Path)>>{};
final _silhouetteCache = <BodyView, Path>{};

/// Görünümün şekilleri, kaynak (çizim) sırasıyla; süs parçalarında kas null.
List<(String?, Path)> musclePaths(BodyView view) => _muscleCache.putIfAbsent(
      view,
      () => [for (final s in muscleShapes[view]!) (s.muscle, buildPath(s.commands))],
    );

Path silhouettePath(BodyView view) => _silhouetteCache.putIfAbsent(view, () => buildPath(bodySilhouettes[view]!));

/// Tuval noktasındaki kas: üstte çizilen (sondaki) şekil önce; süs parçaları atlanır.
String? muscleAt(BodyView view, Offset canvasPoint) {
  for (final (muscle, path) in musclePaths(view).reversed) {
    if (muscle != null && path.contains(canvasPoint)) return muscle;
  }
  return null;
}

Set<String> musclesIn(BodyView view) => {for (final s in muscleShapes[view]!) ?s.muscle};
```

`lib/features/workout/domain/exercise_filter.dart` — dosyanın sonuna ekle:

```dart

/// [muscle]'ı birincil çalıştıranlar (ada göre); [includeSecondary] ise ardından
/// yalnız ikincil çalıştıranlar (ada göre).
List<Exercise> exercisesForMuscle(List<Exercise> all, String muscle, {bool includeSecondary = false}) {
  int byName(Exercise a, Exercise b) => a.name.toLowerCase().compareTo(b.name.toLowerCase());
  final primary = all.where((e) => e.primaryMuscles.contains(muscle)).toList()..sort(byName);
  if (!includeSecondary) return primary;
  final secondary = all
      .where((e) => !e.primaryMuscles.contains(muscle) && e.secondaryMuscles.contains(muscle))
      .toList()
    ..sort(byName);
  return [...primary, ...secondary];
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test --no-pub test/features/workout/domain/muscle_map_test.dart test/features/workout/domain/exercise_filter_test.dart test/features/workout/domain/muscle_map_data_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/workout/domain/muscle_map.dart lib/features/workout/domain/exercise_filter.dart test/features/workout/muscle_map_points.dart test/features/workout/domain/muscle_map_test.dart test/features/workout/domain/exercise_filter_test.dart
git commit -m "feat(workout): build muscle map paths and resolve taps to muscles

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 3: `MuscleMap` widget'ı ve ÖN/ARKA anahtarı

**Files:**
- Create: `lib/features/workout/presentation/widgets/muscle_map.dart`
- Test: `test/features/workout/presentation/muscle_map_widget_test.dart`

**Interfaces:**
- Consumes: Task 2'nin `BodyFit`, `musclePaths`, `silhouettePath`, `muscleAt`, `BodyView`; test yardımcısı `screenPointFor`.
- Produces:
  - `MuscleMap({Key? key, required BodyView view, String? selected, required ValueChanged<String> onSelected})` — sınırlı boyut ister (ör. `SizedBox`); içindeki dokunma kutusunun anahtarı `muscle_map_${view.name}`.
  - `BodyViewToggle({Key? key, required BodyView view, required ValueChanged<BodyView> onChanged})` — `SegmentedButton` anahtarı `muscle_map_view_toggle`, etiketler `workout.muscle_map.front` / `back`.

- [ ] **Step 1: Write the failing test**

`test/features/workout/presentation/muscle_map_widget_test.dart`:

```dart
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spor_takip/features/workout/domain/muscle_map.dart';
import 'package:spor_takip/features/workout/presentation/widgets/muscle_map.dart';

import '../../progress/presentation/test_app.dart';
import '../muscle_map_points.dart';

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  Future<List<String>> pumpMap(WidgetTester tester, BodyView view, {String? selected}) async {
    final taps = <String>[];
    await tester.pumpWidget(testApp(
      Scaffold(
        body: Center(
          child: SizedBox(width: 300, height: 500, child: MuscleMap(view: view, selected: selected, onSelected: taps.add)),
        ),
      ),
      scaffold: false,
    ));
    await tester.pumpAndSettle();
    return taps;
  }

  testWidgets('tapping the chest reports chest', (tester) async {
    final taps = await pumpMap(tester, BodyView.front);
    await tester.tapAt(screenPointFor(tester, find.byKey(const Key('muscle_map_front')), BodyView.front, 'chest'));
    expect(taps, ['chest']);
  });

  testWidgets('back view reports lats', (tester) async {
    final taps = await pumpMap(tester, BodyView.back, selected: 'lats');
    await tester.tapAt(screenPointFor(tester, find.byKey(const Key('muscle_map_back')), BodyView.back, 'lats'));
    expect(taps, ['lats']);
  });

  testWidgets('tapping empty space reports nothing', (tester) async {
    final taps = await pumpMap(tester, BodyView.front);
    await tester.tapAt(tester.getTopLeft(find.byKey(const Key('muscle_map_front'))) + const Offset(2, 2));
    expect(taps, isEmpty);
  });

  testWidgets('view toggle reports the chosen side', (tester) async {
    final changes = <BodyView>[];
    await tester.pumpWidget(testApp(BodyViewToggle(view: BodyView.front, onChanged: changes.add)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('workout.muscle_map.back'));
    expect(changes, [BodyView.back]);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test --no-pub test/features/workout/presentation/muscle_map_widget_test.dart`
Expected: FAIL — derleme hatası (`widgets/muscle_map.dart` yok).

- [ ] **Step 3: Write minimal implementation**

`lib/features/workout/presentation/widgets/muscle_map.dart`:

```dart
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../domain/muscle_map.dart';

typedef _MapColors = ({
  Color silhouette,
  Color outline,
  Color decor,
  Color muscle,
  Color selected,
  Color edge,
});

/// Ön ya da arka vücut figürü; kasa dokununca [onSelected]. Sınırlı boyut ister.
class MuscleMap extends StatelessWidget {
  const MuscleMap({super.key, required this.view, this.selected, required this.onSelected});

  final BodyView view;
  final String? selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final _MapColors colors = (
      silhouette: scheme.surfaceContainerLowest,
      outline: scheme.outlineVariant,
      decor: scheme.surfaceContainer,
      muscle: scheme.surfaceContainerHighest,
      selected: scheme.primary,
      edge: theme.scaffoldBackgroundColor,
    );
    return Semantics(
      label: 'workout.muscle_map.title'.tr(),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = constraints.biggest;
          return GestureDetector(
            key: Key('muscle_map_${view.name}'),
            behavior: HitTestBehavior.opaque,
            onTapUp: (details) {
              final muscle = muscleAt(view, BodyFit(size).toCanvas(details.localPosition));
              if (muscle != null) onSelected(muscle);
            },
            child: CustomPaint(size: size, painter: _MuscleMapPainter(view: view, selected: selected, colors: colors)),
          );
        },
      ),
    );
  }
}

class _MuscleMapPainter extends CustomPainter {
  _MuscleMapPainter({required this.view, required this.selected, required this.colors});

  final BodyView view;
  final String? selected;
  final _MapColors colors;

  @override
  void paint(Canvas canvas, Size size) {
    final fit = BodyFit(size);
    canvas.save();
    canvas.translate(fit.offset.dx, fit.offset.dy);
    canvas.scale(fit.scale);

    final silhouette = silhouettePath(view);
    canvas.drawPath(silhouette, Paint()..color = colors.silhouette);
    canvas.drawPath(
      silhouette,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = colors.outline,
    );

    final edge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..color = colors.edge;
    for (final (muscle, path) in musclePaths(view)) {
      final isSelected = muscle != null && muscle == selected;
      if (isSelected) {
        canvas.drawPath(
          path,
          Paint()
            ..color = colors.selected.withValues(alpha: 0.6)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
        );
      }
      final fill = isSelected ? colors.selected : (muscle == null ? colors.decor : colors.muscle);
      canvas.drawPath(path, Paint()..color = fill);
      canvas.drawPath(path, edge);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_MuscleMapPainter old) => old.view != view || old.selected != selected || old.colors != colors;
}

/// ÖN / ARKA anahtarı (ekran ve alt sayfa ortak).
class BodyViewToggle extends StatelessWidget {
  const BodyViewToggle({super.key, required this.view, required this.onChanged});

  final BodyView view;
  final ValueChanged<BodyView> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<BodyView>(
      key: const Key('muscle_map_view_toggle'),
      showSelectedIcon: false,
      segments: [
        ButtonSegment(value: BodyView.front, label: Text('workout.muscle_map.front'.tr())),
        ButtonSegment(value: BodyView.back, label: Text('workout.muscle_map.back'.tr())),
      ],
      selected: {view},
      onSelectionChanged: (selection) => onChanged(selection.first),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test --no-pub test/features/workout/presentation/muscle_map_widget_test.dart`
Expected: PASS (4 test).

- [ ] **Step 5: Commit**

```bash
git add lib/features/workout/presentation/widgets/muscle_map.dart test/features/workout/presentation/muscle_map_widget_test.dart
git commit -m "feat(workout): add the muscle map widget and front/back toggle

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 4: Kas haritası ekranı, rota, giriş ikonu ve çeviriler

**Files:**
- Create: `lib/features/workout/presentation/muscle_map_screen.dart`
- Modify: `lib/core/router.dart:111` (rota), `lib/features/workout/presentation/programs_screen.dart:35-42` (ikon)
- Modify: `assets/translations/tr.json`, `assets/translations/en.json` (`workout` içinde `"muscle": {` satırından önce)
- Test: `test/features/workout/presentation/muscle_map_screen_test.dart`, `test/features/workout/presentation/programs_screen_test.dart`

**Interfaces:**
- Consumes: `MuscleMap`, `BodyViewToggle` (Task 3); `exercisesForMuscle` (Task 2); `exercisesProvider` (`lib/features/workout/application/workout_providers.dart`, `FutureProvider<List<Exercise>>`); `showExerciseDetailSheet(context, exercise, selectable: false)`; `upperCaseFor(String text, String languageCode)` (`lib/shared/text_case.dart`); `AccentChip`; `muscleLabelKey`, `equipmentLabelKey`.
- Produces: `MuscleMapScreen` (`/workout/muscles`); çeviri anahtarları `workout.muscle_map.{title,front,back,hint,count,include_secondary,empty,pick_from_map}`. Anahtarlar: `muscle_map_screen`, `muscle_map_hint`, `muscle_map_selected`, `muscle_map_count`, `muscle_map_secondary_chip`, `muscle_map_exercise_<id>`, `muscle_map_empty`, `muscle_map_retry`, `programs_muscle_map_button`.

- [ ] **Step 1: Write the failing tests**

`test/features/workout/presentation/muscle_map_screen_test.dart`:

```dart
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spor_takip/features/workout/application/workout_providers.dart';
import 'package:spor_takip/features/workout/domain/exercise.dart';
import 'package:spor_takip/features/workout/domain/muscle_map.dart';
import 'package:spor_takip/features/workout/presentation/muscle_map_screen.dart';

import '../../progress/presentation/test_app.dart';
import '../muscle_map_points.dart';

const _bench = Exercise(
  id: 'bench',
  name: 'Barbell Bench Press',
  equipment: 'barbell',
  level: 'expert',
  primaryMuscles: ['chest'],
  secondaryMuscles: ['triceps'],
  instructions: ['Lower the bar.'],
);
const _pushups = Exercise(id: 'pushups', name: 'Pushups', equipment: 'body only', primaryMuscles: ['chest']);
const _dips = Exercise(id: 'dips', name: 'Dips', primaryMuscles: ['triceps'], secondaryMuscles: ['chest']);
const _squat = Exercise(id: 'squat', name: 'Squat', primaryMuscles: ['quadriceps']);
const _all = [_bench, _pushups, _dips, _squat];

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  Future<void> pumpScreen(WidgetTester tester, {Future<List<Exercise>> Function()? load}) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(testApp(
      const MuscleMapScreen(),
      scaffold: false,
      overrides: [exercisesProvider.overrideWith((ref) => (load ?? () async => _all)())],
    ));
    await tester.pumpAndSettle();
  }

  Future<void> tapMuscle(WidgetTester tester, BodyView view, String muscle) async {
    await tester.tapAt(screenPointFor(tester, find.byKey(Key('muscle_map_${view.name}')), view, muscle));
    await tester.pumpAndSettle();
  }

  testWidgets('shows a hint until a muscle is chosen', (tester) async {
    await pumpScreen(tester);
    expect(find.byKey(const Key('muscle_map_screen')), findsOneWidget);
    expect(find.byKey(const Key('muscle_map_hint')), findsOneWidget);
    expect(find.byKey(const Key('muscle_map_selected')), findsNothing);
  });

  testWidgets('choosing a muscle lists its exercises; the chip adds secondary ones', (tester) async {
    await pumpScreen(tester);
    await tapMuscle(tester, BodyView.front, 'chest');

    expect(find.byKey(const Key('muscle_map_hint')), findsNothing);
    expect(find.byKey(const Key('muscle_map_selected')), findsOneWidget);
    expect(find.byKey(const Key('muscle_map_count')), findsOneWidget);
    expect(find.byKey(const Key('muscle_map_exercise_bench')), findsOneWidget);
    expect(find.byKey(const Key('muscle_map_exercise_pushups')), findsOneWidget);
    expect(find.byKey(const Key('muscle_map_exercise_dips')), findsNothing);
    expect(find.byKey(const Key('muscle_map_exercise_squat')), findsNothing);
    // Ekipman · seviye ('expert' → İleri).
    expect(find.text('workout.equipment.barbell · workout.level_advanced'), findsOneWidget);

    await tester.tap(find.byKey(const Key('muscle_map_secondary_chip')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('muscle_map_exercise_dips')), findsOneWidget);
  });

  testWidgets('a row opens the detail sheet without a select button', (tester) async {
    await pumpScreen(tester);
    await tapMuscle(tester, BodyView.front, 'chest');

    await tester.tap(find.byKey(const Key('muscle_map_exercise_bench')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Lower the bar.'), findsOneWidget);
    expect(find.byKey(const Key('exercise_select_button')), findsNothing);
  });

  testWidgets('switching to the back keeps the selection and the list', (tester) async {
    await pumpScreen(tester);
    await tapMuscle(tester, BodyView.front, 'chest');

    await tester.tap(find.text('workout.muscle_map.back'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('muscle_map_back')), findsOneWidget);
    expect(find.byKey(const Key('muscle_map_selected')), findsOneWidget);
    expect(find.byKey(const Key('muscle_map_exercise_bench')), findsOneWidget);

    // Örnek veride hamstring hareketi yok → boş liste mesajı.
    await tapMuscle(tester, BodyView.back, 'hamstrings');
    expect(find.byKey(const Key('muscle_map_empty')), findsOneWidget);
  });

  testWidgets('a load error offers a retry', (tester) async {
    var calls = 0;
    await pumpScreen(tester, load: () async {
      calls++;
      if (calls == 1) throw Exception('offline');
      return _all;
    });
    await tapMuscle(tester, BodyView.front, 'chest');
    expect(find.byKey(const Key('muscle_map_retry')), findsOneWidget);

    await tester.tap(find.byKey(const Key('muscle_map_retry')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('muscle_map_exercise_bench')), findsOneWidget);
  });
}
```

`test/features/workout/presentation/programs_screen_test.dart` — `wrap` içindeki rotalara `/workout/history` satırının altına ekle:

```dart
      GoRoute(path: '/workout/muscles', builder: (context, state) => const Text('MUSCLES')),
```

ve dosyanın sonundaki `}`'den önce yeni test:

```dart
  testWidgets('muscle map button opens the muscle map', (tester) async {
    await tester.pumpWidget(wrap(programs: [_stronglifts]));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('programs_muscle_map_button')));
    await tester.pumpAndSettle();

    expect(find.text('MUSCLES'), findsOneWidget);
  });
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test --no-pub test/features/workout/presentation/muscle_map_screen_test.dart test/features/workout/presentation/programs_screen_test.dart`
Expected: FAIL — `muscle_map_screen.dart` yok (derleme hatası).

- [ ] **Step 3: Çevirileri ekle**

`assets/translations/tr.json` — `workout` içinde `"muscle": {` satırının hemen üstüne (aynı girinti, 4 boşluk):

```json
    "muscle_map": {
      "title": "Kas haritası",
      "front": "ÖN",
      "back": "ARKA",
      "hint": "Bir kasa dokun",
      "count": "{n} hareket",
      "include_secondary": "İkincil dahil",
      "empty": "Bu kas için hareket yok",
      "pick_from_map": "Haritadan seç"
    },
```

`assets/translations/en.json` — aynı yere:

```json
    "muscle_map": {
      "title": "Muscle map",
      "front": "FRONT",
      "back": "BACK",
      "hint": "Tap a muscle",
      "count": "{n} exercises",
      "include_secondary": "Include secondary",
      "empty": "No exercises for this muscle",
      "pick_from_map": "Pick on map"
    },
```

Doğrula: `python -c "import json; [json.load(open(f, encoding='utf-8')) for f in ('assets/translations/tr.json', 'assets/translations/en.json')]; print('ok')"` → `ok`.

- [ ] **Step 4: Ekranı yaz**

`lib/features/workout/presentation/muscle_map_screen.dart`:

```dart
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/text_case.dart';
import '../../../shared/widgets/accent_chip.dart';
import '../application/workout_providers.dart';
import '../domain/exercise.dart';
import '../domain/exercise_filter.dart';
import '../domain/exercise_taxonomy.dart';
import '../domain/muscle_map.dart';
import 'widgets/exercise_detail_sheet.dart';
import 'widgets/muscle_map.dart';

/// Kas haritası: kasa dokun → o kası çalıştıran hareketler (yalnız göz atma).
class MuscleMapScreen extends ConsumerStatefulWidget {
  const MuscleMapScreen({super.key});

  @override
  ConsumerState<MuscleMapScreen> createState() => _MuscleMapScreenState();
}

class _MuscleMapScreenState extends ConsumerState<MuscleMapScreen> {
  BodyView _view = BodyView.front;
  String? _muscle;
  bool _includeSecondary = false;

  @override
  Widget build(BuildContext context) {
    final muscle = _muscle;
    return Scaffold(
      key: const Key('muscle_map_screen'),
      appBar: AppBar(title: Text('workout.muscle_map.title'.tr())),
      body: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            sliver: SliverToBoxAdapter(
              child: Center(child: BodyViewToggle(view: _view, onChanged: (v) => setState(() => _view = v))),
            ),
          ),
          SliverToBoxAdapter(
            child: SizedBox(
              height: MediaQuery.sizeOf(context).height * 0.45,
              child: MuscleMap(view: _view, selected: muscle, onSelected: (m) => setState(() => _muscle = m)),
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

  List<Widget> _results(BuildContext context, String muscle) {
    return ref.watch(exercisesProvider).when(
          loading: () => const [
            SliverToBoxAdapter(
              child: Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator())),
            ),
          ],
          error: (error, stackTrace) => [
            SliverToBoxAdapter(
              child: Center(
                child: TextButton(
                  key: const Key('muscle_map_retry'),
                  onPressed: () => ref.invalidate(exercisesProvider),
                  child: Text('workout.picker_load_error'.tr()),
                ),
              ),
            ),
          ],
          data: (all) {
            final list = exercisesForMuscle(all, muscle, includeSecondary: _includeSecondary);
            return [
              SliverToBoxAdapter(child: _header(context, muscle, list.length)),
              if (list.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'workout.muscle_map.empty'.tr(),
                      key: const Key('muscle_map_empty'),
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  sliver: DecoratedSliver(
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardTheme.color,
                      borderRadius: const BorderRadius.all(Radius.circular(16)),
                    ),
                    sliver: SliverList.separated(
                      itemCount: list.length,
                      separatorBuilder: (context, index) => const Divider(height: 1, indent: 16, endIndent: 16),
                      itemBuilder: (context, index) => _row(context, list[index]),
                    ),
                  ),
                ),
            ];
          },
        );
  }

  Widget _header(BuildContext context, String muscle, int count) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  upperCaseFor(muscleLabelKey(muscle).tr(), context.locale.languageCode),
                  key: const Key('muscle_map_selected'),
                  style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                ),
                Text(
                  'workout.muscle_map.count'.tr(namedArgs: {'n': '$count'}),
                  key: const Key('muscle_map_count'),
                  style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
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

  Widget _row(BuildContext context, Exercise e) {
    final subtitle = [
      if (e.equipment case final equipment?) equipmentLabelKey(equipment).tr(),
      if (_levelKey(e.level) case final level?) level.tr(),
      if (e.isCustom) 'workout.custom_exercise_badge'.tr(),
    ].join(' · ');
    return ListTile(
      key: Key('muscle_map_exercise_${e.id}'),
      title: Text(e.name),
      subtitle: subtitle.isEmpty ? null : Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => showExerciseDetailSheet(context, e, selectable: false),
    );
  }
}

/// Veritabanı seviyesi → çeviri anahtarı ('expert' → İleri); bilinmeyen/null atlanır.
String? _levelKey(String? level) => switch (level) {
      'beginner' => 'workout.level_beginner',
      'intermediate' => 'workout.level_intermediate',
      'expert' => 'workout.level_advanced',
      _ => null,
    };
```

- [ ] **Step 5: Rota ve giriş ikonu**

`lib/core/router.dart` — `exercises` rotasının altına:

```dart
                  GoRoute(path: 'muscles', builder: (context, state) => const MuscleMapScreen()),
```

ve importlara (diğer workout ekran importlarının yanına, alfabetik):

```dart
import '../features/workout/presentation/muscle_map_screen.dart';
```

`lib/features/workout/presentation/programs_screen.dart` — `actions` listesinde geçmiş ikonundan **önce**:

```dart
          IconButton(
            key: const Key('programs_muscle_map_button'),
            icon: const Icon(Icons.accessibility_new),
            tooltip: 'workout.muscle_map.title'.tr(),
            onPressed: () => context.push('/workout/muscles'),
          ),
```

- [ ] **Step 6: Run tests to verify they pass**

Run: `flutter test --no-pub test/features/workout/presentation/muscle_map_screen_test.dart test/features/workout/presentation/programs_screen_test.dart`
Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add lib/features/workout/presentation/muscle_map_screen.dart lib/core/router.dart lib/features/workout/presentation/programs_screen.dart assets/translations/tr.json assets/translations/en.json test/features/workout/presentation/muscle_map_screen_test.dart test/features/workout/presentation/programs_screen_test.dart
git commit -m "feat(workout): add the muscle map screen

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 5: Seçicide "Haritadan seç"

**Files:**
- Create: `lib/features/workout/presentation/widgets/muscle_map_sheet.dart`
- Modify: `lib/features/workout/presentation/exercise_picker_screen.dart` (`_chipRow` + kas satırı)
- Test: `test/features/workout/presentation/exercise_picker_screen_test.dart`

**Interfaces:**
- Consumes: `MuscleMap`, `BodyViewToggle` (Task 3); `BodyView`; `workout.muscle_map.pick_from_map` / `hint` (Task 4); test yardımcısı `screenPointFor`.
- Produces: `Future<String?> showMuscleMapSheet(BuildContext context, {String? selected})`; çip anahtarı `muscle_filter_map`; alt sayfa ipucu anahtarı `muscle_map_sheet_hint`.

- [ ] **Step 1: Write the failing test**

`test/features/workout/presentation/exercise_picker_screen_test.dart` — importlara ekle:

```dart
import 'package:spor_takip/features/workout/domain/muscle_map.dart';

import '../muscle_map_points.dart';
```

ve `muscle filter chip narrows the list` testinin altına:

```dart
  testWidgets('picking a muscle on the map filters the list', (tester) async {
    await openPicker(tester);

    await tester.tap(find.byKey(const Key('muscle_filter_map')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('muscle_map_sheet_hint')), findsOneWidget);

    await tester.tapAt(screenPointFor(tester, find.byKey(const Key('muscle_map_front')), BodyView.front, 'chest'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('muscle_map_sheet_hint')), findsNothing);
    expect(find.byKey(const Key('exercise_tile_Pushups')), findsOneWidget);
    expect(find.byKey(const Key('exercise_tile_Barbell_Squat')), findsNothing);
  });

  testWidgets('closing the map sheet keeps the current filter', (tester) async {
    await openPicker(tester);

    await tester.tap(find.byKey(const Key('muscle_filter_map')));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(5, 5)); // alt sayfanın dışı
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('exercise_tile_Pushups')), findsOneWidget);
    expect(find.byKey(const Key('exercise_tile_Barbell_Squat')), findsOneWidget);
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test --no-pub test/features/workout/presentation/exercise_picker_screen_test.dart`
Expected: FAIL — `muscle_filter_map` bulunamaz.

- [ ] **Step 3: Write minimal implementation**

`lib/features/workout/presentation/widgets/muscle_map_sheet.dart`:

```dart
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../domain/muscle_map.dart';
import 'muscle_map.dart';

/// Haritadan kas seçtirir; kasa dokununca o kas, kapatılırsa null döner.
Future<String?> showMuscleMapSheet(BuildContext context, {String? selected}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _MuscleMapSheet(selected: selected),
  );
}

class _MuscleMapSheet extends StatefulWidget {
  const _MuscleMapSheet({required this.selected});

  final String? selected;

  @override
  State<_MuscleMapSheet> createState() => _MuscleMapSheetState();
}

class _MuscleMapSheetState extends State<_MuscleMapSheet> {
  BodyView _view = BodyView.front;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            BodyViewToggle(view: _view, onChanged: (v) => setState(() => _view = v)),
            const SizedBox(height: 8),
            SizedBox(
              height: MediaQuery.sizeOf(context).height * 0.6,
              child: MuscleMap(
                view: _view,
                selected: widget.selected,
                onSelected: (muscle) => Navigator.of(context).pop(muscle),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'workout.muscle_map.hint'.tr(),
              key: const Key('muscle_map_sheet_hint'),
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
```

`lib/features/workout/presentation/exercise_picker_screen.dart`:

1. Import ekle (`widgets/exercise_detail_sheet.dart` satırının altına):

```dart
import 'widgets/muscle_map_sheet.dart';
```

2. `_createCustom`'dan önce:

```dart
  Future<void> _pickFromMap() async {
    final muscle = await showMuscleMapSheet(context, selected: _muscle);
    if (muscle != null && mounted) setState(() => _muscle = muscle);
  }
```

3. Kas satırı çağrısına `leading` ekle:

```dart
          _chipRow(
            rowKey: 'muscle_filter_row',
            values: muscleGroups,
            selected: _muscle,
            keyPrefix: 'muscle_filter_',
            label: (m) => muscleLabelKey(m).tr(),
            onSelected: (m) => setState(() => _muscle = m),
            leading: AccentChip(
              key: const Key('muscle_filter_map'),
              label: 'workout.muscle_map.pick_from_map'.tr(),
              selected: false,
              onSelected: (_) => _pickFromMap(),
            ),
          ),
```

4. `_chipRow` imzasına `Widget? leading,` (son parametre) ekle ve `children`'ın başına:

```dart
          if (leading != null) Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: leading),
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test --no-pub test/features/workout/presentation/exercise_picker_screen_test.dart`
Expected: PASS (mevcut 5 + yeni 2 test).

- [ ] **Step 5: Commit**

```bash
git add lib/features/workout/presentation/widgets/muscle_map_sheet.dart lib/features/workout/presentation/exercise_picker_screen.dart test/features/workout/presentation/exercise_picker_screen_test.dart
git commit -m "feat(workout): pick the muscle filter on the map in the exercise picker

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 6: Lisans kaydı

**Files:**
- Create: `LICENSES/body-highlighter.txt` (`tool/body_highlighter/LICENSE`'ın birebir kopyası)
- Create: `lib/core/licenses.dart`
- Modify: `pubspec.yaml:69-71` (`assets`), `lib/main.dart` (çağrı)
- Test: `test/core/licenses_test.dart`

**Interfaces:**
- Produces: `void registerLicenses()`; `const bodyHighlighterLicenseAsset = 'LICENSES/body-highlighter.txt'`.

- [ ] **Step 1: Write the failing test**

`test/core/licenses_test.dart`:

```dart
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spor_takip/core/licenses.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('registers the body-highlighter MIT license', () async {
    // Flutter'ın NOTICES toplayıcısı test paketinde olmayabilir; yalnız bizimkini ölç.
    LicenseRegistry.reset();
    registerLicenses();

    final entries = await LicenseRegistry.licenses.toList();
    final entry = entries.singleWhere((e) => e.packages.contains('react-native-body-highlighter'));
    final text = entry.paragraphs.map((p) => p.text).join('\n');
    expect(text, contains('MIT License'));
    expect(text, contains('Copyright (c) 2022 ELABBASSI Hicham'));
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test --no-pub test/core/licenses_test.dart`
Expected: FAIL — `lib/core/licenses.dart` yok.

- [ ] **Step 3: Write minimal implementation**

Lisans dosyası: `Copy-Item tool/body_highlighter/LICENSE LICENSES/body-highlighter.txt` (önce `New-Item -ItemType Directory -Force LICENSES`).

`pubspec.yaml` — `assets` listesine:

```yaml
    - LICENSES/body-highlighter.txt
```

`lib/core/licenses.dart`:

```dart
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

const bodyHighlighterLicenseAsset = 'LICENSES/body-highlighter.txt';

/// Uygulamaya gömülü üçüncü taraf verilerin lisansları (Flutter lisans sayfasında görünür).
void registerLicenses() {
  LicenseRegistry.addLicense(() async* {
    final text = await rootBundle.loadString(bodyHighlighterLicenseAsset);
    yield LicenseEntryWithLineBreaks(const ['react-native-body-highlighter'], text);
  });
}
```

`lib/main.dart` — import (`core/router.dart`'tan önce):

```dart
import 'core/licenses.dart';
```

ve `WidgetsFlutterBinding.ensureInitialized();` satırının hemen altına:

```dart
  registerLicenses();
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test --no-pub test/core/licenses_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add LICENSES/body-highlighter.txt lib/core/licenses.dart lib/main.dart pubspec.yaml test/core/licenses_test.dart
git commit -m "feat: register the body-highlighter MIT license

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 7: Doğrulama, PLAN.md ve dalın kapanışı

**Files:**
- Modify: `PLAN.md` (değişiklik günlüğü tablosunun sonuna bir satır)

- [ ] **Step 1: Statik analiz**

Run (arka planda): `flutter analyze --no-pub`
Expected: `No issues found!` Uyarı çıkarsa düzelt, ilgili testleri yeniden çalıştır, ayrı commit at.

- [ ] **Step 2: Kullanıcıdan tam test paketi**

Kullanıcıdan kendi terminalinde çalıştırmasını iste: `flutter test --no-pub -j 1`. Beklenen: hepsi geçer (G3 sonrası 475 + K1'in yeni testleri). Sonucu sayısıyla kaydet.

- [ ] **Step 3: Kullanıcıdan web release derlemesi ve manuel kontrol**

Kullanıcı: `flutter build web --release --no-pub` ve derlemeyi kendi terminalinden sunar. Kontrol listesi:

1. Antrenman sekmesi → AppBar'daki figür ikonu → Kas haritası açılır; figür ön görünümde düzgün (siluet + kaslar, kesik/kayık yok).
2. ÖN/ARKA geçişi; arka figür düzgün; seçim korunur.
3. Göğüs, kanat (lats), kalça dışı (abdüktör) seçimlerinde listeler mantıklı; başlık büyük harf ve sayı doğru.
4. "İkincil dahil" listeyi genişletir.
5. Satır → detay sayfası, "Seç" butonu yok.
6. Hareket seçicide "Haritadan seç" → alt sayfa → kasa dokun → liste o kasa süzülür (ilgili çip seçili).
7. Lisans kaydı: (lisans sayfasına giriş yoksa) Task 6 testiyle doğrulandı; kullanıcıya not edilir.
8. Dar ekranda (tarayıcı ~360 px) taşma yok; ipucu ve liste okunur.

- [ ] **Step 4: PLAN.md satırı**

`PLAN.md` değişiklik günlüğü tablosunun sonuna, G3 satırının biçiminde: tarih, "**F5+ K1 (kas haritası) tamamlandı** (`f5p-kas-haritasi` dalı, 7 görev)", özet (2D ön/arka harita, MIT kaynak + Python üretici, ekran + seçicide haritadan seç, lisans kaydı), sapmalar, otomatik test sayısı, manuel kontrol sonucu, "Sıradaki: K2 (kadın figürü, ısı haritası, programdan haritaya, Stitch ile yerleşim) ya da oyunlaştırma."

```bash
git add PLAN.md
git commit -m "docs: record K1 muscle map verification

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

- [ ] **Step 5: Dalı kapat**

REQUIRED SUB-SKILL: superpowers:finishing-a-development-branch (önceki fazlardaki gibi: master'a fast-forward birleştirme + push, kullanıcı onayıyla).
