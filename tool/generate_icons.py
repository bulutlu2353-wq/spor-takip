"""LevelUp Fit ikonlarını üretir (G2 spec §9.4).

Proje kökünden: python tool/generate_icons.py
Logo 1024 px'te çizilip LANCZOS ile küçültülür; renkler AppColors ile aynı.
"""
import json
from pathlib import Path

from PIL import Image, ImageDraw

BG = (0x0E, 0x0F, 0x12, 255)
LINE = (0x26, 0x28, 0x30, 255)
ACCENT = (0xC6, 0xFF, 0x00, 255)
ACCENT_DIM = (0xC6, 0xFF, 0x00, 140)  # %55 opak
BASE = 1024
ROOT = Path(__file__).resolve().parent.parent


def chevrons(scale=1.0):
    """Şeffaf zeminde iki şerit; scale < 1 maskable güvenli alan için küçültür."""
    img = Image.new('RGBA', (BASE, BASE), (0, 0, 0, 0))
    unit = BASE / 100 * scale
    offset = BASE * (1 - scale) / 2
    width = round(12 * unit)
    for top, color in ((52, ACCENT_DIM), (28, ACCENT)):
        layer = Image.new('RGBA', img.size, (0, 0, 0, 0))
        draw = ImageDraw.Draw(layer)
        points = [
            (offset + 22 * unit, offset + (top + 24) * unit),
            (offset + 50 * unit, offset + top * unit),
            (offset + 78 * unit, offset + (top + 24) * unit),
        ]
        draw.line(points, fill=color, width=width, joint='curve')
        radius = width / 2
        for x, y in (points[0], points[2]):
            draw.ellipse((x - radius, y - radius, x + radius, y + radius), fill=color)
        img = Image.alpha_composite(img, layer)
    return img


def tile(size, rounded=True, scale=1.0, border=True):
    big = Image.new('RGBA', (BASE, BASE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(big)
    if rounded:
        draw.rounded_rectangle(
            (0, 0, BASE - 1, BASE - 1),
            radius=round(BASE * 0.22),
            fill=BG,
            outline=LINE if border else None,
            width=round(BASE * 0.015) if border else 0,
        )
    else:
        draw.rectangle((0, 0, BASE, BASE), fill=BG)
    big = Image.alpha_composite(big, chevrons(scale))
    return big.resize((size, size), Image.LANCZOS)


def save(img, rel, opaque=False):
    if opaque:
        img = img.convert('RGB')
    img.save(ROOT / rel)
    print(rel, img.size)


def main():
    save(tile(16, border=False), 'web/favicon.png')
    for size in (192, 512):
        save(tile(size), f'web/icons/Icon-{size}.png')
        save(tile(size, rounded=False, scale=0.7), f'web/icons/Icon-maskable-{size}.png')
    for folder, size in {'mdpi': 48, 'hdpi': 72, 'xhdpi': 96, 'xxhdpi': 144, 'xxxhdpi': 192}.items():
        save(tile(size), f'android/app/src/main/res/mipmap-{folder}/ic_launcher.png')
    iconset = 'ios/Runner/Assets.xcassets/AppIcon.appiconset'
    contents = json.loads((ROOT / iconset / 'Contents.json').read_text(encoding='utf-8'))
    for image in contents['images']:
        name = image.get('filename')
        if not name:
            continue
        points = float(image['size'].split('x')[0])
        scale = int(image['scale'].rstrip('x'))
        # iOS köşeleri kendisi yuvarlar; şeffaflık olmamalı.
        save(tile(round(points * scale), rounded=False), f'{iconset}/{name}', opaque=True)


if __name__ == '__main__':
    main()
