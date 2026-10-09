"""Synthesise Snag A Goober's original sound effects and music loop.

Outputs (Assets/Audio):
  SAG_SFX.wav     every sound effect back to back (a "sound sprite")
  SAG_SFX.json    { name: [start_seconds, end_seconds] } regions in the sprite
  SAG_Music.wav   a seamless 32-second loop

All audio is generated from scratch here (no samples), so it is ours to use.
"""
import json
import os
import wave

import numpy as np

SR = 22050
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "Assets", "Audio")
os.makedirs(OUT, exist_ok=True)
rng = np.random.default_rng(7)


def t(d):
    return np.arange(int(SR * d)) / SR


def env(n, a=0.005, r=None, decay=None):
    x = np.ones(n)
    na = max(1, int(SR * a))
    x[:na] = np.linspace(0, 1, na)
    if decay:
        x *= np.exp(-np.arange(n) / SR / decay)
    if r:
        nr = min(n, int(SR * r))
        x[-nr:] *= np.linspace(1, 0, nr)
    return x


def note(f):
    return 440 * 2 ** ((f - 69) / 12)


def bell(freq, d, decay=0.25, vol=0.5):
    tt = t(d)
    s = np.sin(2 * np.pi * freq * tt) + 0.35 * np.sin(2 * np.pi * freq * 2.01 * tt) + 0.12 * np.sin(2 * np.pi * freq * 3.02 * tt)
    return vol * s * env(len(tt), 0.002, 0.02, decay)


def sweep(f0, f1, d, shape="sine", vol=0.5, decay=None):
    tt = t(d)
    f = np.geomspace(f0, f1, len(tt))
    ph = 2 * np.pi * np.cumsum(f) / SR
    if shape == "square":
        s = np.tanh(3 * np.sin(ph))
    elif shape == "tri":
        s = 2 / np.pi * np.arcsin(np.sin(ph))
    else:
        s = np.sin(ph)
    return vol * s * env(len(tt), 0.003, 0.03, decay)


def noise(d, vol=0.3, decay=0.1, lp=0.2):
    n = rng.standard_normal(int(SR * d))
    # one-pole low-pass
    y = np.zeros_like(n)
    acc = 0.0
    for i, v in enumerate(n):
        acc += lp * (v - acc)
        y[i] = acc
    return vol * y * env(len(n), 0.002, 0.02, decay)


def mix(*parts_with_offsets):
    end = max(off + len(p) / SR for p, off in parts_with_offsets)
    out = np.zeros(int(SR * end) + 1)
    for p, off in parts_with_offsets:
        i = int(SR * off)
        out[i:i + len(p)] += p
    return out


def chord(notes, d, decay=0.6, vol=0.25, shape="tri"):
    return sum(sweep(note(n), note(n), d, shape, vol, decay) for n in notes)


SFX = {}
# grab a Goober: bubbly rising bloop + pop
SFX["Snag"] = mix((sweep(260, 950, 0.16, "sine", 0.6, 0.12), 0), (noise(0.03, 0.4, 0.01, 0.6), 0.0), (bell(note(84), 0.2, 0.08, 0.25), 0.12))
# place on stand: soft thump + sparkle trio
SFX["Place"] = mix((sweep(180, 70, 0.18, "sine", 0.7, 0.08), 0), (bell(note(84), 0.3, 0.12, 0.3), 0.05), (bell(note(88), 0.3, 0.12, 0.28), 0.1), (bell(note(91), 0.4, 0.15, 0.28), 0.15))
# coins: two bright chimes
SFX["Coin"] = mix((bell(note(83), 0.25, 0.1, 0.45), 0), (bell(note(88), 0.45, 0.2, 0.45), 0.07))
# upgrade: rising arpeggio
SFX["Upgrade"] = mix(*[(sweep(note(n), note(n), 0.14, "square", 0.18, 0.1), i * 0.07) for i, n in enumerate((72, 76, 79, 84))], (bell(note(96), 0.4, 0.2, 0.2), 0.28))
# level up: fanfare + chord
SFX["LevelUp"] = mix(*[(sweep(note(n), note(n), 0.13, "square", 0.2, 0.12), i * 0.09) for i, n in enumerate((67, 72, 76, 79))],
                     (chord((72, 76, 79, 84), 0.7, 0.5, 0.18), 0.38), (bell(note(96), 0.6, 0.3, 0.2), 0.38))
# rare spawn: shimmering sparkles
SFX["Rare"] = mix(*[(bell(note(int(n)), 0.25, 0.08, 0.22), i * 0.05) for i, n in enumerate(rng.choice([84, 86, 88, 91, 93, 96], 12))])
# legendary: big chord swell + sweep
SFX["Legendary"] = mix((chord((60, 64, 67, 72, 76), 1.4, 0.9, 0.16, "square"), 0), (sweep(300, 2400, 0.8, "sine", 0.15, 0.5), 0),
                       *[(bell(note(n), 0.5, 0.25, 0.22), 0.4 + i * 0.08) for i, n in enumerate((84, 88, 91, 96))])
# steal alarm: friendly two-tone siren
SFX["StealAlarm"] = mix(*[(sweep(f, f, 0.18, "square", 0.17, None), i * 0.2) for i, f in enumerate((740, 980, 740, 980))])
# caught: cartoon bonk
SFX["Caught"] = mix((sweep(520, 70, 0.3, "sine", 0.7, 0.15), 0), (noise(0.06, 0.5, 0.02, 0.4), 0), (bell(note(91), 0.3, 0.1, 0.15), 0.08))
# steal success: sneaky "ta-daa"
SFX["StealSuccess"] = mix((sweep(note(67), note(67), 0.1, "square", 0.2, 0.08), 0), (sweep(note(66), note(66), 0.1, "square", 0.2, 0.08), 0.11),
                          (chord((72, 75, 79), 0.5, 0.35, 0.2), 0.24))
# rebirth: whoosh up + chord
SFX["Rebirth"] = mix((noise(1.0, 0.35, 0.6, 0.05) * np.linspace(0, 1, int(SR * 1.0)), 0), (sweep(120, 1600, 1.0, "sine", 0.18, None), 0),
                     (chord((60, 67, 72, 76, 79), 1.0, 0.8, 0.17), 0.9), (bell(note(96), 0.8, 0.4, 0.25), 0.95))
# event: gong + warble
SFX["Event"] = mix((bell(note(43), 1.4, 0.9, 0.6), 0), (sweep(note(72), note(84), 0.5, "tri", 0.2, 0.4), 0.2), (sweep(note(84), note(72), 0.5, "tri", 0.2, 0.4), 0.55))
SFX["Click"] = mix((sweep(1800, 1200, 0.035, "sine", 0.35, 0.02), 0))
SFX["Error"] = mix((sweep(180, 160, 0.1, "square", 0.25, None), 0), (sweep(150, 130, 0.13, "square", 0.25, None), 0.13))


def to_int16(x):
    peak = np.max(np.abs(x)) or 1
    x = x / max(peak, 1.0) * 0.92
    return (x * 32767).astype(np.int16)


def write(path, data):
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(to_int16(data).tobytes())


# sprite
gap = np.zeros(int(SR * 0.3))
regions = {}
chunks = []
pos = 0.0
for name, data in SFX.items():
    data = data / max(1.0, np.max(np.abs(data)))
    regions[name] = [round(pos, 4), round(pos + len(data) / SR, 4)]
    chunks += [data, gap]
    pos += (len(data) + len(gap)) / SR
sprite = np.concatenate(chunks)
write(os.path.join(OUT, "SAG_SFX.wav"), sprite)
json.dump(regions, open(os.path.join(OUT, "SAG_SFX.json"), "w"), indent=1)

# -------------------------------------------------------------- music loop
BPM = 112
beat = 60 / BPM
bars = 16
total = bars * 4 * beat
music = np.zeros(int(SR * total) + SR)
prog = [(60, 64, 67), (57, 60, 64), (53, 57, 60), (55, 59, 62)]  # C Am F G
melody_scale = [72, 74, 76, 79, 81, 84]
mrng = np.random.default_rng(3)
motif = [mrng.choice(melody_scale) for _ in range(8)]


def place(sig, at):
    i = int(SR * at)
    music[i:i + len(sig)] += sig[: max(0, len(music) - i)]


for bar in range(bars):
    c = prog[bar % 4]
    t0 = bar * 4 * beat
    for b in range(4):
        # bass: root on beats, octave bounce
        place(sweep(note(c[0] - 24 + (12 if b % 2 else 0)), note(c[0] - 24 + (12 if b % 2 else 0)), beat * 0.9, "tri", 0.32, beat * 0.6), t0 + b * beat)
        # offbeat chord stabs
        place(chord(c, beat * 0.4, beat * 0.25, 0.07, "square"), t0 + b * beat + beat / 2)
        # soft kick + hat
        place(sweep(140, 45, 0.12, "sine", 0.45, 0.06), t0 + b * beat)
        place(noise(0.04, 0.12, 0.015, 0.9), t0 + b * beat + beat / 2)
    # melody: motif with variation every other bar pair
    for k in range(8):
        n = motif[k] + (2 if (bar // 2) % 2 and k % 3 == 0 else 0)
        if (bar % 4 == 3 and k >= 6) or (k % 4 == 3 and bar % 2):
            continue
        place(bell(note(n), beat * 0.45, beat * 0.3, 0.13), t0 + k * beat / 2)
music = music[: int(SR * total)]
# tiny crossfade at the loop point
fade = int(SR * 0.02)
music[:fade] *= np.linspace(0, 1, fade)
music[-fade:] *= np.linspace(1, 0, fade)
write(os.path.join(OUT, "SAG_Music.wav"), music * 0.8)

print(json.dumps(regions))
print("sprite", round(len(sprite) / SR, 2), "s; music", round(total, 2), "s")
for f in ("SAG_SFX.wav", "SAG_Music.wav"):
    print(f, os.path.getsize(os.path.join(OUT, f)) // 1024, "KB")
