#!/usr/bin/env python3
"""Прозрачный PNG из двух рендеров одной картинки: на белом и на чёрном фоне.

    png_matte.py <на_белом.png> <на_чёрном.png> <out.png> [высота]

`qlmanage` отдаёт миниатюру с непрозрачным белым фоном. Если отрисовать SVG на
белом (W) и на чёрном (B) и сравнить, получается точная альфа и цвет:

    W = a·C + (1-a)·255,  B = a·C   →   a = 1 - (W-B)/255,  C = B/a

[высота] — оставить только верхние N строк (qlmanage кладёт SVG в верхний левый
угол квадратного холста). Только стандартная библиотека, 8-битный RGB/RGBA.
"""
import struct
import sys
import zlib


def chunks_of(data):
    assert data[:8] == b'\x89PNG\r\n\x1a\n', 'не PNG'
    pos = 8
    while pos < len(data):
        (length,) = struct.unpack('>I', data[pos:pos + 4])
        yield data[pos + 4:pos + 8], data[pos + 8:pos + 8 + length]
        pos += 12 + length


def paeth(a, b, c):
    p = a + b - c
    pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
    if pa <= pb and pa <= pc:
        return a
    return b if pb <= pc else c


def load(path):
    """Возвращает (ширина, высота, каналов, [строки bytearray])."""
    chunks = list(chunks_of(open(path, 'rb').read()))
    ihdr = next(p for k, p in chunks if k == b'IHDR')
    width, height, depth, ctype, _, _, interlace = struct.unpack('>IIBBBBB', ihdr)
    assert depth == 8 and interlace == 0 and ctype in (2, 6), (
        f'{path}: нужен 8-битный RGB/RGBA без чересстрочности '
        f'(depth={depth} colortype={ctype} interlace={interlace})')
    bpp = 4 if ctype == 6 else 3
    raw = zlib.decompress(b''.join(p for k, p in chunks if k == b'IDAT'))

    stride = width * bpp
    rows, prev, pos = [], bytearray(stride), 0
    for _ in range(height):
        ftype = raw[pos]
        line = bytearray(raw[pos + 1:pos + 1 + stride])
        pos += 1 + stride
        for i in range(stride):
            left = line[i - bpp] if i >= bpp else 0
            up = prev[i]
            upleft = prev[i - bpp] if i >= bpp else 0
            if ftype == 1:
                line[i] = (line[i] + left) & 255
            elif ftype == 2:
                line[i] = (line[i] + up) & 255
            elif ftype == 3:
                line[i] = (line[i] + ((left + up) >> 1)) & 255
            elif ftype == 4:
                line[i] = (line[i] + paeth(left, up, upleft)) & 255
        rows.append(line)
        prev = line
    return width, height, bpp, rows


def chunk(kind, payload):
    body = kind + payload
    return struct.pack('>I', len(payload)) + body + struct.pack(
        '>I', zlib.crc32(body) & 0xFFFFFFFF)


def main(white_path, black_path, out_path, height=None):
    w, h, bpp, white = load(white_path)
    w2, h2, bpp2, black = load(black_path)
    assert (w, h) == (w2, h2), 'рендеры разного размера'
    rows_count = min(h, height) if height else h

    out_rows = []
    for y in range(rows_count):
        src_w, src_b = white[y], black[y]
        line = bytearray(b'\x00')  # фильтр 0
        for x in range(w):
            o = x * bpp
            # Альфа — по среднему от трёх каналов (шум квантования усредняется).
            diff = sum(src_w[o + c] - src_b[o + c] for c in range(3)) / 3.0
            a = max(0.0, min(1.0, 1.0 - diff / 255.0))
            if a < 1 / 255:
                line += b'\x00\x00\x00\x00'
                continue
            rgb = [min(255, int(round(src_b[o + c] / a))) for c in range(3)]
            line += bytes(rgb) + bytes([int(round(a * 255))])
        out_rows.append(bytes(line))

    png = b'\x89PNG\r\n\x1a\n'
    png += chunk(b'IHDR', struct.pack('>IIBBBBB', w, rows_count, 8, 6, 0, 0, 0))
    png += chunk(b'IDAT', zlib.compress(b''.join(out_rows), 9))
    png += chunk(b'IEND', b'')
    open(out_path, 'wb').write(png)


if __name__ == '__main__':
    args = sys.argv[1:]
    main(args[0], args[1], args[2], int(args[3]) if len(args) > 3 else None)
