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


def make_zukan_bgm():
    """図鑑の画面：オルゴールのような音の、ゆったりしたワルツ（ヘ長調・3拍子・8小節ループ）"""
    beat = 0.6  # 4分音符1つ（3拍で1小節）
    bars = 8
    buf = [0.0] * int(round(bars * 3 * beat * RATE))
    # 小節ごとのメロディ（3拍。'-' はのばす）
    melody = [
        "A5 C6 A5", "G5 - E5", "F5 A5 D6", "C6 - -",
        "D6 C6 A#5", "A5 F5 A5", "G5 E5 G5", "F5 - -",
    ]
    # 小節ごとの和音（1拍目にベース、2・3拍目に和音を小さく）
    chords = [
        ("F3", ["A4", "C5"]), ("C3", ["G4", "C5"]), ("D3", ["F4", "A4"]),
        ("C3", ["E4", "G4"]), ("A#2", ["D5", "F4"]), ("F3", ["A4", "C5"]),
        ("C3", ["E4", "A#4"]), ("F3", ["A4", "C5"]),
    ]
    steps = [n for bar in melody for n in bar.split()]
    i = 0
    while i < len(steps):
        length = 1
        while i + length < len(steps) and steps[i + length] == "-":
            length += 1
        # オルゴールは「ポーン」と鳴って消えていく音なので decay をつける
        tone(buf, i * beat, length * beat, freq(steps[i]), 0.35, bell,
             attack=0.005, decay=1.2, release=0.4, loop=True)
        i += length
    for b, (bass, chord) in enumerate(chords):
        start = b * 3 * beat
        tone(buf, start, 2.6 * beat, freq(bass), 0.3, triangle,
             attack=0.01, release=0.2, loop=True)
        for k in (1, 2):
            for n in chord:
                tone(buf, start + k * beat, 0.8 * beat, freq(n), 0.08, bell,
                     attack=0.005, decay=3, release=0.2, loop=True)
    return buf


# ---------------------------------------------------------------
# タイトル画面：昔の携帯ゲーム機のような「ピコピコ」した曲（チップチューン風）
# ---------------------------------------------------------------

TABLE = 2048  # 波の形を、この数の点で1周期ぶん表にしておく


def pulse_table(duty, harmonics=24):
    """パルス波（細い矩形波）の表。倍音の数をしぼって、耳に痛い雑音を出にくくする
    duty：1周期のうち「上」にいる割合（0.125 や 0.25 が昔のゲーム機らしい音）"""
    table = []
    for i in range(TABLE):
        x = i / TABLE
        v = sum(math.sin(math.pi * k * duty) / k
                * math.cos(2 * math.pi * k * (x - duty / 2))
                for k in range(1, harmonics + 1))
        table.append(v)
    m = max(abs(v) for v in table)
    return [v / m for v in table]


def wave_table():
    """ベース用：16段階の階段になった三角波（昔のゲーム機の「波形メモリ音源」風）"""
    return [round(triangle(i / TABLE) * 7.5) / 7.5 for i in range(TABLE)]


def chip(buf, start, dur, f, vol, table, loop=True):
    """表を読み出して1音鳴らす。鳴りはじめが少し強く、すぐ一定の大きさになる"""
    n = int(dur * RATE)
    s0 = int(start * RATE)
    step = f * TABLE / RATE
    phase = 0.0
    for i in range(n):
        t = i / RATE
        env = 0.75 + 0.25 * math.exp(-t * 12)  # 鳴りはじめだけ少し強い
        if i > n - 200:  # 最後はプツッと鳴らないよう、短く消す
            env *= (n - i) / 200
        idx = s0 + i
        if loop:
            idx %= len(buf)
        elif idx >= len(buf):
            break
        buf[idx] += vol * env * table[int(phase) % TABLE]
        phase += step


def chip_noise(buf, start, length, vol, seed, loop=True):
    """ドラム用のノイズ（ハイハット・スネア）"""
    rnd = random.Random(seed)
    s0 = int(start * RATE)
    n = int(length * RATE)
    held = 0.0
    for i in range(n):
        if i % 3 == 0:  # 少し粗いノイズにして、昔のゲーム機らしく
            held = rnd.uniform(-1, 1)
        idx = s0 + i
        if loop:
            idx %= len(buf)
        buf[idx] += vol * (1 - i / n) ** 2 * held


def chip_kick(buf, start, vol, loop=True):
    """バスドラム：音程が急に下がる短い音"""
    s0 = int(start * RATE)
    phase = 0.0
    for i in range(int(0.12 * RATE)):
        t = i / RATE
        phase += (55 + 180 * math.exp(-t * 40)) / RATE
        idx = (s0 + i) % len(buf) if loop else s0 + i
        buf[idx] += vol * math.exp(-t * 25) * (1 if (phase % 1) < 0.5 else -1)


def make_home_bgm():
    """タイトル画面：冒険に出かけるような、わくわくする曲（ニ長調・150BPM・16小節ループ）"""
    eighth = 60 / 150 / 2
    bars = 16
    buf = [0.0] * int(round(bars * 8 * eighth * RATE))
    lead = pulse_table(0.25)
    harmony = pulse_table(0.125)
    bass = wave_table()

    melody = [
        "D5 - A4 D5 F#5 - E5 D5", "E5 - F#5 - A5 - - -",
        "B5 - A5 G5 F#5 - G5 A5", "E5 - - - . E5 F#5 G5",
        "F#5 - D5 F#5 B5 - A5 F#5", "G5 - F#5 - E5 - D5 -",
        "E5 G#5 B5 - G#5 - E5 F#5", "A5 - - - A4 C#5 E5 G5",
        "F#5 - D5 F#5 A5 - F#5 A5", "D6 - C#6 - B5 - A5 -",
        "B5 - G5 B5 D6 - B5 G5", "A5 - E5 - C#5 - A4 -",
        "B4 D5 F#5 - B5 - A5 -", "G5 - B5 - D6 - B5 -",
        "A5 - G5 - F#5 - E5 -", "D5 - - - A4 - C#5 -",
    ]
    # 小節ごとの和音（根音と、伴奏の2音）
    chords = [
        ("D", ["F#4", "A4"]), ("D", ["F#4", "A4"]), ("G", ["G4", "B4"]),
        ("A", ["E4", "A4"]), ("B", ["F#4", "B4"]), ("G", ["G4", "B4"]),
        ("E", ["G#4", "B4"]), ("A", ["E4", "C#5"]), ("D", ["F#4", "A4"]),
        ("D", ["F#4", "A4"]), ("G", ["G4", "B4"]), ("A", ["E4", "C#5"]),
        ("B", ["F#4", "B4"]), ("G", ["G4", "B4"]), ("A", ["E4", "C#5"]),
        ("D", ["F#4", "A4"]),
    ]

    # メロディ（'-' はのばす、'.' は休み）
    steps = [n for bar in melody for n in bar.split()]
    i = 0
    while i < len(steps):
        length = 1
        while i + length < len(steps) and steps[i + length] == "-":
            length += 1
        if steps[i] not in ("-", "."):
            chip(buf, i * eighth, length * eighth * 0.92, freq(steps[i]), 0.22, lead)
        i += length

    for b, (root, pair) in enumerate(chords):
        bar = b * 8 * eighth
        # 伴奏：4分音符で和音の2音を交互に（細い音で小さめ）
        for q in range(4):
            chip(buf, bar + q * 2 * eighth, eighth * 1.6, freq(pair[q % 2]), 0.10, harmony)
        # ベース：8分音符で、根音と1オクターブ上を行ったり来たり
        low = "B2" if root == "B" else root + "3"
        high = "B3" if root == "B" else root + "4"
        for e in range(8):
            chip(buf, bar + e * eighth, eighth * 0.8, freq(low if e % 2 == 0 else high), 0.28, bass)
        # ドラム：1・3拍目にバスドラム、2・4拍目にスネア、8分でハイハット
        for q in range(4):
            if q % 2 == 0:
                chip_kick(buf, bar + q * 2 * eighth, 0.25)
            else:
                chip_noise(buf, bar + q * 2 * eighth, 0.10, 0.22, seed=b * 4 + q)
        for e in range(8):
            chip_noise(buf, bar + e * eighth, 0.025, 0.06, seed=1000 + b * 8 + e)
    return buf


# ---------------------------------------------------------------
# 結果画面のジングル（正解数の段ごとに1曲。くり返さず1回だけ鳴らす）
# ---------------------------------------------------------------

def brass(x):
    """ラッパ風の音：倍音を多めに重ねて、明るく張りのある音にする"""
    return sum(math.sin(2 * math.pi * x * k) / k for k in range(1, 7))


def snare(buf, start, vol=0.35, length=0.12, seed=0):
    """小太鼓：ザッと鳴ってすぐ消えるノイズ"""
    rnd = random.Random(seed)
    s0 = int(start * RATE)
    n = int(length * RATE)
    for j in range(n):
        if s0 + j < len(buf):
            buf[s0 + j] += vol * (1 - j / n) ** 2 * rnd.uniform(-1, 1)


def timpani(buf, start, f=65.0, vol=0.6, length=0.6):
    """ティンパニ：低い音が「ドーン」と鳴って、音程が少し下がりながら消える"""
    s0 = int(start * RATE)
    phase = 0.0
    for j in range(int(length * RATE)):
        t = j / RATE
        phase += (f * (1 + 0.5 * math.exp(-t * 20))) / RATE
        if s0 + j < len(buf):
            buf[s0 + j] += vol * math.exp(-t * 5) * math.sin(2 * math.pi * phase)


def cymbal(buf, start, vol=0.18, length=2.0):
    """シンバル：長く残る「シャーン」。ノイズを少しなめらかにして耳に痛くないようにする"""
    rnd = random.Random(7)
    s0 = int(start * RATE)
    prev = 0.0
    for j in range(int(length * RATE)):
        t = j / RATE
        prev = prev * 0.3 + rnd.uniform(-1, 1) * 0.7
        if s0 + j < len(buf):
            buf[s0 + j] += vol * math.exp(-t * 2.2) * prev


def play(buf, notes, wave_fn, vol, beat, release=0.06, decay=None):
    """notes: (開始の拍, 長さの拍, 音名) のリスト。和音は同じ開始の拍に並べる"""
    for start, length, name in notes:
        tone(buf, start * beat, length * beat * 0.95, freq(name), vol, wave_fn,
             attack=0.015, release=release, decay=decay)


def make_result_perfect():
    """全問正解：小太鼓のロール → ラッパのファンファーレ → 大きな和音とシンバル（約7秒）"""
    beat = 0.22  # 8分音符1つの長さ（秒）
    buf = [0.0] * int(7.2 * RATE)
    # 小太鼓のロール（だんだん速く、だんだん強く）
    t = 0.0
    k = 0
    while t < 0.85:
        snare(buf, t, vol=0.12 + 0.25 * t, length=0.08, seed=k)
        t += 0.09 - 0.05 * t
        k += 1
    o = 0.9 / beat  # ロールのあとから始める（拍の単位）
    melody = [
        (0, 1, "G4"), (1, 1, "G4"), (2, 1, "G4"), (3, 3, "C5"),
        (6, 1, "E5"), (7, 1, "D5"), (8, 1, "C5"), (9, 1, "E5"), (10, 3, "G5"),
        (13, 1, "A5"), (14, 1, "G5"), (15, 1, "E5"), (16, 1, "F5"), (17, 1, "D5"),
        (18, 8, "C6"),
    ]
    # 最後の和音は、ゆっくり小さくなって消えるように（release を長く）
    play(buf, [(o + s, l, n) for s, l, n in melody], brass, 0.30, beat,
         release=0.6)
    # 下で支える和音（ラッパの合奏っぽく）
    chords = [
        (3, 3, ["E4", "G4"]), (10, 3, ["B4", "D5"]), (13, 5, ["C5", "F5"]),
        (18, 8, ["E5", "G5", "C5"]),
    ]
    for s, l, names in chords:
        play(buf, [(o + s, l, n) for n in names], brass, 0.14, beat,
             release=0.6)
    # ベースとティンパニ
    for s, n in [(3, "C3"), (6, "C3"), (10, "G2"), (13, "F2"), (16, "G2")]:
        play(buf, [(o + s, 2.5, n)], triangle, 0.35, beat)
    for s, f in [(0, 98), (3, 65), (10, 98), (13, 87), (16, 98)]:
        timpani(buf, (o + s) * beat, f=f, vol=0.45)
    # 最後：ティンパニのロール → ドーン ＋ シンバル
    for j in range(8):
        timpani(buf, (o + 16) * beat + j * 0.055, f=65, vol=0.18, length=0.2)
    timpani(buf, (o + 18) * beat, f=65, vol=0.45, length=1.5)
    play(buf, [(o + 18, 8, "C3")], triangle, 0.45, beat)
    cymbal(buf, (o + 18) * beat, vol=0.22, length=2.5)
    return buf


def make_result_great():
    """8〜9問：きらきらした音で駆けあがる、明るいジングル（約3.5秒）"""
    beat = 0.14
    buf = [0.0] * int(3.6 * RATE)
    notes = [(i, 1.5, n) for i, n in enumerate(
        ["C5", "E5", "G5", "C6", "E6", "G6"])]
    notes += [(7, 2, "E6"), (9, 2, "D6"), (11, 10, "C6")]
    play(buf, notes, bell, 0.4, beat, release=0.3, decay=2.5)
    play(buf, [(11, 10, n) for n in ["E5", "G5"]], bell, 0.2, beat,
         release=0.4, decay=1.5)
    play(buf, [(0, 6, "C3"), (7, 4, "G2"), (11, 10, "C3")], triangle, 0.4, beat)
    snare(buf, 11 * beat, vol=0.2)
    cymbal(buf, 11 * beat, vol=0.1, length=1.5)
    return buf


def make_result_good():
    """5〜7問：はずむような、楽しいジングル（約2.5秒）"""
    beat = 0.16
    buf = [0.0] * int(2.6 * RATE)
    melody = [(0, 1, "F5"), (1, 1, "A5"), (2, 1, "G5"), (3, 1, "F5"),
              (4, 1, "D5"), (5, 1, "G5"), (6, 2, "A5"), (8, 6, "F5")]
    play(buf, melody, soft_square, 0.3, beat)
    play(buf, [(8, 6, n) for n in ["A4", "C5"]], soft_square, 0.12, beat)
    play(buf, [(0, 2, "F3"), (2, 2, "C3"), (4, 2, "G3"), (6, 2, "C3"),
               (8, 6, "F3")], triangle, 0.4, beat)
    for s in [1, 3, 5, 7]:
        snare(buf, s * beat, vol=0.08, length=0.05, seed=s)
    return buf


def make_result_try():
    """0〜4問：ゆったりした、前向きなジングル（悲しくしない。約2.5秒）"""
    beat = 0.22
    buf = [0.0] * int(2.7 * RATE)
    melody = [(0, 1, "C5"), (1, 1, "E5"), (2, 1, "D5"), (3, 1, "G4"),
              (4, 1, "A4"), (5, 1, "B4"), (6, 5, "C5")]
    play(buf, melody, triangle, 0.45, beat, release=0.15)
    play(buf, [(6, 5, n) for n in ["E4", "G4"]], triangle, 0.18, beat,
         release=0.2)
    play(buf, [(0, 3, "C3"), (3, 3, "G2"), (6, 5, "C3")], triangle, 0.35, beat)
    return buf


if __name__ == "__main__":
    out = Path(sys.argv[1])
    save(out / "se" / "correct.wav", make_correct())
    save(out / "se" / "wrong.wav", make_wrong())
    save(out / "bgm" / "title.wav", make_title_bgm(), peak=0.6)
    save(out / "bgm" / "quiz.wav", make_quiz_bgm(), peak=0.6)
    save(out / "bgm" / "zukan.wav", make_zukan_bgm(), peak=0.6)
    save(out / "bgm" / "home.wav", make_home_bgm(), peak=0.6)
    save(out / "se" / "result_perfect.wav", make_result_perfect(), peak=0.85)
    save(out / "se" / "result_great.wav", make_result_great(), peak=0.7)
    save(out / "se" / "result_good.wav", make_result_good(), peak=0.7)
    save(out / "se" / "result_try.wav", make_result_try(), peak=0.7)
