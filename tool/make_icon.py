"""ポケピコのアプリアイコン（ボールをモチーフにしたオリジナル）を描いて PNG で書き出す。

追加のライブラリなしで動く（形は「距離」で描き、ふちを 1px でぼかしてなめらかにする）。
使い方: python3 -I tool/make_icon.py <出力する PNG のパス>
"""
import math
import struct
import sys
import zlib

SIZE = 1024
CX, CY, R = 512, 528, 352  # ボールの中心と半径
OUTLINE = 15  # ふちどりの太さ（半分）
BAND = 30  # まん中の帯の太さ（半分）

DARK = (38, 50, 56)
RED_TOP = (255, 105, 97)
RED_BOTTOM = (211, 36, 36)
WHITE = (250, 250, 250)
WHITE_SHADE = (214, 222, 228)
SKY_TOP = (92, 200, 250)
SKY_BOTTOM = (190, 236, 255)


def mix(a, b, t):
    return tuple(a[i] + (b[i] - a[i]) * t for i in range(3))


def cover(d):
    """距離 d（内側がマイナス）から、その点がどれだけ図形に入っているか（0〜1）"""
    return max(0.0, min(1.0, 0.5 - d))


def star(px, py, sx, sy, r):
    """4つのとがりがある「きらっ」の形の、おおよその距離"""
    dx, dy = abs(px - sx) / r, abs(py - sy) / r
    return (math.sqrt(dx) + math.sqrt(dy) - 1) * r * 0.5


SPARKLES = [(170, 190, 70), (860, 230, 52), (880, 860, 40), (150, 820, 34)]


def pixel(x, y):
    px, py = x + 0.5, y + 0.5
    # 背景：上から下へ空色のグラデーション
    col = mix(SKY_TOP, SKY_BOTTOM, py / SIZE)

    # きらきら
    for sx, sy, r in SPARKLES:
        col = mix(col, (255, 255, 255), cover(star(px, py, sx, sy, r)) * 0.9)

    # ボールの下の、ぼんやりした影
    sd = math.hypot((px - CX) / 1.0, (py - (CY + R + 30)) / 0.18) - R * 0.85
    col = mix(col, (40, 110, 150), max(0.0, min(1.0, -sd / 60)) * 0.35)

    dist = math.hypot(px - CX, py - CY)
    ball = cover(dist - R - OUTLINE)
    if ball <= 0:
        return col

    # ボールの中身：上は赤、下は白（右下ほど少し暗く）
    shade = max(0.0, min(1.0, ((px - CX) + (py - CY)) / (2 * R) + 0.5))
    if py < CY:
        fill = mix(RED_TOP, RED_BOTTOM, shade)
    else:
        fill = mix(WHITE, WHITE_SHADE, shade)
    # 左上のつや
    gloss = math.hypot((px - (CX - 150)) / 1.4, (py - (CY - 190)) / 0.8) - 90
    fill = mix(fill, (255, 255, 255), cover(gloss / 6) * 0.45)

    inner = mix(col, fill, ball)

    # まん中の帯
    band = cover(abs(py - CY) - BAND) * ball
    inner = mix(inner, DARK, band)
    # ふちどり
    inner = mix(inner, DARK, cover(abs(dist - R) - OUTLINE))

    # まん中のボタン：黒いふち → 白 → 細い灰色の輪 → 白
    inner = mix(inner, DARK, cover(dist - 112))
    inner = mix(inner, WHITE, cover(dist - 84))
    inner = mix(inner, (190, 200, 206), cover(abs(dist - 54) - 4))
    # ボタンのつや
    inner = mix(inner, (255, 255, 255),
                cover(math.hypot(px - (CX - 22), py - (CY - 24)) - 14) * 0.9)
    return inner


def main(path):
    rows = []
    for y in range(SIZE):
        row = bytearray(b"\x00")  # 各行の先頭は PNG のフィルタ番号（0 = なし）
        for x in range(SIZE):
            row.extend(max(0, min(255, round(c))) for c in pixel(x, y))
        rows.append(bytes(row))

    def chunk(kind, data):
        body = kind + data
        return struct.pack(">I", len(data)) + body + struct.pack(">I", zlib.crc32(body))

    png = b"\x89PNG\r\n\x1a\n"
    png += chunk(b"IHDR", struct.pack(">IIBBBBB", SIZE, SIZE, 8, 2, 0, 0, 0))  # RGB・透明なし
    png += chunk(b"IDAT", zlib.compress(b"".join(rows), 9))
    png += chunk(b"IEND", b"")
    with open(path, "wb") as f:
        f.write(png)
    print(path)


if __name__ == "__main__":
    main(sys.argv[1])
