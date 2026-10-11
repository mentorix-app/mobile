#!/usr/bin/env bash
# Рендерит прозрачные PNG для нативного сплеша (flutter_native_splash) из SVG
# в assets/icons. Только macOS: qlmanage (WebKit) + python3 без зависимостей.
# Запуск из корня проекта:
#
#   tool/generate_splash_assets.sh && dart run flutter_native_splash:create
#
# Размеры: пакет считает картинку «4x», поэтому 960 px по ширине = 240 dp —
# столько же, сколько у логотипа в SplashScreen (SvgPicture width: 240).
#
# qlmanage отдаёт миниатюру с непрозрачным белым фоном, поэтому каждый SVG
# рисуется дважды (на белом и на чёрном) и прозрачность восстанавливается
# попиксельно — см. tool/png_matte.py.
set -euo pipefail

cd "$(dirname "$0")/.."

OUT=assets/splash
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$OUT"

# render <svg> <имя> [высота]: пишет $OUT/<имя>.png
render() {
  local svg=$1 name=$2 height=${3:-}
  local base
  base=$(basename "$svg")

  # Вариант на чёрном: чёрный прямоугольник на всю область SVG первым элементом.
  python3 - "$svg" "$TMP/black-$base" <<'PY'
import re, sys
src = open(sys.argv[1], encoding='utf-8').read()
tag = re.search(r'<svg\b[^>]*>', src).group(0)
view = re.search(r'viewBox="([^"]+)"', tag)
if view:
    x, y, w, h = view.group(1).split()
else:
    x, y = '0', '0'
    w = re.search(r'width="([\d.]+)', tag).group(1)
    h = re.search(r'height="([\d.]+)', tag).group(1)
rect = f'<rect x="{x}" y="{y}" width="{w}" height="{h}" fill="#000000"/>'
open(sys.argv[2], 'w', encoding='utf-8').write(src.replace(tag, tag + rect, 1))
PY

  cp "$svg" "$TMP/white-$base"
  qlmanage -t -s 960 -o "$TMP" "$TMP/white-$base" >/dev/null 2>&1
  qlmanage -t -s 960 -o "$TMP" "$TMP/black-$base" >/dev/null 2>&1
  python3 tool/png_matte.py "$TMP/white-$base.png" "$TMP/black-$base.png" \
    "$OUT/$name.png" $height
}

# Полный логотип: рамка viewBox 460×108 → при ширине 960 высота 225.4 px.
# qlmanage кладёт SVG в левый верхний угол квадрата — оставляем верхние 225 строк (последняя, 226-я, — граничный артефакт).
render assets/icons/full-logo.svg full-logo 225
render assets/icons/full-logo-dark.svg full-logo-dark 225

# Android 12+: иконка в круге диаметром 640 px из холста 960×960. Иконка
# mini-logo (скруглённый квадрат 52 из 64) сжимается до 500 px по стороне,
# чтобы углы не обрезались кругом, и центрируется на холсте.
python3 - "$TMP/android12.svg" <<'PY'
import re, sys
src = open('assets/icons/mini-logo.svg', encoding='utf-8').read()
inner = re.search(r'<svg[^>]*>(.*)</svg>', src, re.S).group(1)
inner = re.sub(r'<title>.*?</title>', '', inner, flags=re.S)
side = 500                      # сторона скруглённого квадрата на холсте
scale = side / 52               # в исходнике квадрат занимает 52 из 64 единиц
offset = (960 - 64 * scale) / 2
open(sys.argv[1], 'w', encoding='utf-8').write(
    '<svg width="960" height="960" viewBox="0 0 960 960" fill="none" '
    'xmlns="http://www.w3.org/2000/svg">'
    f'<g transform="translate({offset} {offset}) scale({scale})">{inner}</g></svg>'
)
PY
render "$TMP/android12.svg" android12

echo "Готово:"
for f in "$OUT"/*.png; do
  sips -g pixelWidth -g pixelHeight "$f" | tail -2 | tr '\n' ' '
  echo "$f"
done
