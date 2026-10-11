#!/usr/bin/env python3
"""Исходники иконки приложения для flutter_launcher_icons из assets/icons/mini-logo.svg.

    python3 tool/generate_app_icons.py && dart run flutter_launcher_icons

Только macOS (`qlmanage`) и стандартная библиотека. Результат:

  assets/app_icon/icon.png        1024×1024, без прозрачности: фон на весь квадрат
                                  + знак. iOS сам скругляет углы и не принимает
                                  иконки с альфа-каналом; Android до 8.0 — то же.
  assets/app_icon/foreground.png  1024×1024, прозрачный: только знак для
                                  adaptive-иконки Android. Знак вписан в круг
                                  безопасной зоны (66 из 108 dp) с учётом инсета
                                  16%, который добавляет flutter_launcher_icons.

Фон взят из самого логотипа (скруглённый квадрат #263449), поэтому
`adaptive_icon_background` в flutter_launcher_icons.yaml совпадает с ним.
"""
import os
import re
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import png_matte  # noqa: E402

ROOT = os.path.dirname(HERE)
SOURCE = os.path.join(ROOT, 'assets', 'icons', 'mini-logo.svg')
OUT = os.path.join(ROOT, 'assets', 'app_icon')
SIZE = 1024

# Доля стороны холста, которую занимает знак (длинная сторона его рамки).
ICON_MARK_SHARE = 0.58        # iOS и legacy Android: знак как в плитке логотипа

# Adaptive: круг безопасной зоны — 66 из 108 dp. flutter_launcher_icons сам
# оборачивает передний план в `inset 16%` (ic_launcher.xml), поэтому картинка
# показывается в 68% холста: безопасная зона от её ширины — 66 / (108 · 0.68).
ADAPTIVE_INSET = 0.16
SAFE_ZONE_DIAMETER = 66 / (108 * (1 - 2 * ADAPTIVE_INSET))


def render(svg_text, out_png, workdir):
    """SVG → PNG с настоящей прозрачностью (рендер на белом и на чёрном)."""
    view = re.search(r'viewBox="([^"]+)"', svg_text).group(1).split()
    tag = re.search(r'<svg\b[^>]*>', svg_text).group(0)
    black = svg_text.replace(
        tag,
        tag + f'<rect x="{view[0]}" y="{view[1]}" width="{view[2]}" '
        f'height="{view[3]}" fill="#000000"/>',
        1,
    )
    paths = {}
    for kind, text in (('white', svg_text), ('black', black)):
        path = os.path.join(workdir, f'{kind}-{os.path.basename(out_png)}.svg')
        open(path, 'w', encoding='utf-8').write(text)
        subprocess.run(
            ['qlmanage', '-t', '-s', str(SIZE), '-o', workdir, path],
            check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
        )
        paths[kind] = path + '.png'
    png_matte.main(paths['white'], paths['black'], out_png)


def bounding_box(png_path):
    """Рамка непрозрачных пикселей: (x0, y0, x1, y1) в пикселях."""
    width, height, bpp, rows = png_matte.load(png_path)
    xs, ys = [], []
    for y, row in enumerate(rows):
        for x in range(width):
            if row[x * bpp + 3] > 8:
                xs.append(x)
                ys.append(y)
    return min(xs), min(ys), max(xs) + 1, max(ys) + 1


def main():
    src = open(SOURCE, encoding='utf-8').read()
    background = re.search(r'<rect[^>]*rx="[^"]*"[^>]*fill="(#[0-9A-Fa-f]{6})"', src)
    assert background, 'в mini-logo.svg не найден фон-плитка (rect с rx)'
    inner = re.search(r'<svg[^>]*>(.*)</svg>', src, re.S).group(1)
    inner = re.sub(r'<title>.*?</title>', '', inner, flags=re.S)
    # Знак — всё, кроме плитки-фона.
    mark = re.sub(r'<rect[^>]*rx="[^"]*"[^>]*/>', '', inner, count=1).strip()

    os.makedirs(OUT, exist_ok=True)
    with tempfile.TemporaryDirectory() as work:
        # 1. Рамка знака: рендерим его отдельно в масштабе 16 px на единицу.
        probe = os.path.join(work, 'probe.png')
        scale_probe = SIZE / 64
        render(
            f'<svg width="{SIZE}" height="{SIZE}" viewBox="0 0 64 64" fill="none" '
            f'xmlns="http://www.w3.org/2000/svg">{mark}</svg>',
            probe, work,
        )
        x0, y0, x1, y1 = bounding_box(probe)
        box_w, box_h = (x1 - x0) / scale_probe, (y1 - y0) / scale_probe
        cx, cy = (x0 + x1) / 2 / scale_probe, (y0 + y1) / 2 / scale_probe
        long_side = max(box_w, box_h)
        # Диагональ рамки должна влезть в круг безопасной зоны: углы маской
        # лаунчера обрезаются.
        diagonal = (box_w ** 2 + box_h ** 2) ** 0.5

        def compose(target_px, with_background):
            s = target_px / long_side
            tx, ty = SIZE / 2 - cx * s, SIZE / 2 - cy * s
            bg = (f'<rect width="{SIZE}" height="{SIZE}" fill="{background.group(1)}"/>'
                  if with_background else '')
            return (
                f'<svg width="{SIZE}" height="{SIZE}" viewBox="0 0 {SIZE} {SIZE}" '
                f'fill="none" xmlns="http://www.w3.org/2000/svg">{bg}'
                f'<g transform="translate({tx} {ty}) scale({s})">{mark}</g></svg>'
            )

        icon_target = SIZE * ICON_MARK_SHARE
        safe_target = SIZE * SAFE_ZONE_DIAMETER * long_side / diagonal

        render(compose(icon_target, True), os.path.join(OUT, 'icon.png'), work)
        render(compose(safe_target, False), os.path.join(OUT, 'foreground.png'), work)

    print(f'знак: {box_w:.1f}×{box_h:.1f} ед., фон {background.group(1)}')
    print(f'icon.png: знак {icon_target:.0f} px; foreground.png: {safe_target:.0f} px '
          f'(круг безопасной зоны на холсте картинки: {SIZE * SAFE_ZONE_DIAMETER:.0f} px)')


if __name__ == '__main__':
    main()
