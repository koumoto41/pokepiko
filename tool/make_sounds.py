"""ポケピコ用のオリジナル効果音・BGMを合成して WAV で書き出す。

使い方: python3 -I make_sounds.py <出力先の assets フォルダ>
"""
import math
import random
import struct
import sys
import wave
from pathlib import Path

RATE = 22050

NOTE_INDEX = {"C": 0, "C#": 1, "D": 2, "D#": 3, "E": 4, "F": 5,
              "F#": 6, "G": 7, "G#": 8, "A": 9, "A#": 10, "B": 11}


def freq(name):
    """'A4' -> 440Hz"""
    pitch, octave = name[:-1], int(name[-1])
    midi = 12 * (octave + 1) + NOTE_INDEX[pitch]
    return 440.0 * 2 ** ((midi - 69) / 12)


def tone(buf, start, dur, f, vol, wave_fn, attack=0.01, release=0.08,
         decay=None, loop=False):
    """buf に1音を足す。loop=True なら末尾からはみ出た分を先頭に回す（つなぎ目なしのループ用）"""
    n = int((dur + release) * RATE)
    s0 = int(start * RATE)
    for i in range(n):
        t = i / RATE
        if t < attack:
            env = t / attack
        elif t < dur:
            env = math.exp(-(t - attack) * decay) if decay else 1.0
        else:
            last = math.exp(-(dur - attack) * decay) if decay else 1.0
            env = last * max(0.0, 1 - (t - dur) / release)
        idx = s0 + i
        if loop:
            idx %= len(buf)
        elif idx >= len(buf):
            break
        buf[idx] += vol * env * wave_fn(f * t)


def sine(x):
    return math.sin(2 * math.pi * x)


def bell(x):  # 少し倍音のある、きらっとした音
    return 0.7 * sine(x) + 0.2 * sine(2 * x) + 0.1 * sine(3 * x)


def triangle(x):
    p = x % 1.0
    return 4 * p - 1 if p < 0.5 else 3 - 4 * p


def soft_square(x):  # 角を丸めた矩形波（ピコピコ音、耳が痛くならない程度）
    return math.tanh(4 * sine(x))


def save(path, buf, peak=0.8):
    m = max(abs(v) for v in buf) or 1.0
    scale = peak / m
    path.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(path), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(b"".join(
            struct.pack("<h", int(max(-1, min(1, v * scale)) * 32767))
            for v in buf))
    print(f"{path}  {len(buf) / RATE:.1f}s  {path.stat().st_size // 1024}KB")


def make_correct():
    """せいかい：ドミソド↑ のきらきら"""
    buf = [0.0] * int(0.9 * RATE)
    for i, n in enumerate(["C6", "E6", "G6", "C7"]):
        tone(buf, i * 0.07, 0.5 - i * 0.05, freq(n), 0.5, bell,
             decay=5, release=0.2)
    return buf


def make_wrong():
    """ざんねん：やさしく下がる2音（こわくない音）"""
    buf = [0.0] * int(0.7 * RATE)
    tone(buf, 0.0, 0.22, freq("E4"), 0.5, triangle, release=0.05)
    tone(buf, 0.25, 0.35, freq("C4"), 0.5, triangle, decay=3, release=0.1)
    return buf


def render_song(melody, bass, eighth, hat=False):
    """melody: 小節ごとの8分音符のリスト（'-' はのばす、'.' は休み）
    bass: 小節ごとの4分音符のリスト"""
    bars = len(melody)
    total = bars * 8 * eighth
    buf = [0.0] * int(round(total * RATE))

    # メロディ：'-' の数だけ音をのばす
    steps = [n for bar in melody for n in bar.split()]
    i = 0
    while i < len(steps):
        n = steps[i]
        length = 1
        while i + length < len(steps) and steps[i + length] == "-":
            length += 1
        if n not in ("-", "."):
            tone(buf, i * eighth, length * eighth * 0.9, freq(n), 0.30,
                 soft_square, release=0.05, loop=True)
        i += length

    # ベース
    for b, bar in enumerate(bass):
        for q, n in enumerate(bar.split()):
            tone(buf, (b * 8 + q * 2) * eighth, eighth * 1.6, freq(n), 0.45,
                 triangle, release=0.04, loop=True)

    # ハイハット（8分のうら拍に小さなノイズ）
    if hat:
        rnd = random.Random(1)
        for k in range(bars * 8):
            if k % 2 == 1:
                s0 = int(k * eighth * RATE)
                for j in range(int(0.03 * RATE)):
                    buf[(s0 + j) % len(buf)] += 0.06 * (1 - j / (0.03 * RATE)) * rnd.uniform(-1, 1)
    return buf


def make_title_bgm():
    """タイトル・設定画面：ゆったり明るい（ハ長調・120BPM・8小節ループ）"""
    melody = [
        "C5 E5 G5 E5 C5 E5 G5 -",
        "A5 G5 F5 E5 D5 - . .",
        "F5 A5 C6 A5 F5 A5 C6 -",
        "B5 A5 G5 F5 E5 - . .",
        "E5 G5 C6 G5 E5 G5 C6 -",
        "D6 C6 B5 A5 G5 - A5 B5",
        "C6 - G5 - E5 - G5 -",
        "C6 - - - . . . .",
    ]
    bass = [
        "C3 G3 C3 G3", "G2 D3 G2 D3", "F2 C3 F2 C3", "G2 D3 G2 B2",
        "C3 G3 C3 G3", "G2 D3 G2 D3", "C3 G3 E3 G3", "C3 G3 C3 G2",
    ]
    return render_song(melody, bass, eighth=0.25)


def make_quiz_bgm():
    """クイズ画面：はずむ感じ（ト長調・140BPM・8小節ループ）"""
    melody = [
        "G5 . D5 . G5 A5 B5 .",
        "A5 . D5 . A5 B5 C6 .",
        "B5 . G5 . B5 C6 D6 .",
        "C6 B5 A5 G5 A5 - . .",
        "G5 . D5 . G5 A5 B5 .",
        "C6 . E5 . C6 B5 A5 .",
        "B5 A5 G5 A5 B5 C6 D6 -",
        "G5 - - . D5 E5 F#5 .",
    ]
    bass = [
        "G2 D3 G2 D3", "D3 A2 D3 A2", "G2 D3 G2 D3", "C3 G2 D3 A2",
        "G2 D3 G2 D3", "C3 G2 C3 G2", "G2 D3 E3 D3", "G2 D3 D3 D3",
    ]
    return render_song(melody, bass, eighth=60 / 140 / 2, hat=True)


if __name__ == "__main__":
    out = Path(sys.argv[1])
    save(out / "se" / "correct.wav", make_correct())
    save(out / "se" / "wrong.wav", make_wrong())
    save(out / "bgm" / "title.wav", make_title_bgm(), peak=0.6)
    save(out / "bgm" / "quiz.wav", make_quiz_bgm(), peak=0.6)
