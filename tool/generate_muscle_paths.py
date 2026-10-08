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
