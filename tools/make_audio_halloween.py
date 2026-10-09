"""Synthesise the Halloween update audio (all from scratch, no samples).

Outputs (Assets/Audio):
  SAG_MainTheme.wav     refreshed main-world music, seamless 48 s loop (F major, 120 BPM)
  SAG_HalloweenTheme.wav  Halloween Island music, seamless loop (D minor, 96 BPM, swung triplets)
  SAG_SFX2.wav          Halloween sound effects back to back (a "sound sprite")
  SAG_SFX2.json         { name: [start_seconds, end_seconds] }
"""
import json
import os
import wave

import numpy as np

SR = 32000
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "Assets", "Audio")
os.makedirs(OUT, exist_ok=True)
rng = np.random.default_rng(31)


def t(d):
    return np.arange(int(SR * d)) / SR


def hz(m):
    return 440 * 2 ** ((m - 69) / 12)


def env(n, a=0.005, r=0.02, decay=None, hold=None):
    x = np.ones(n)
    na = max(1, int(SR * a))
    x[:na] = np.linspace(0, 1, na)
    if decay:
        x *= np.exp(-np.arange(n) / SR / decay)
    nr = min(n, max(1, int(SR * r)))
    x[-nr:] *= np.linspace(1, 0, nr)
    return x


def lowpass(x, a):
    # one-pole low-pass, vectorised enough via scipy-free recursion in chunks
    y = np.empty_like(x)
    acc = 0.0
    for i in range(len(x)):
        acc += a * (x[i] - acc)
        y[i] = acc
    return y


_ks_cache = {}


def pluck(m, d, bright=0.5, vol=0.5, decay=0.996):
    """Karplus-Strong plucked string (cached per pitch/length)."""
    key = (m, round(d, 3), bright, decay)
    if key not in _ks_cache:
        n = int(SR * d)
        p = max(2, int(SR / hz(m)))
        buf = rng.uniform(-1, 1, p)
        buf = lowpass(buf, 0.3 + 0.7 * bright)
        out = np.empty(n)
        idx = 0
        for i in range(n):
            v = buf[idx]
            nxt = buf[(idx + 1) % p]
            buf[idx] = decay * 0.5 * (v + nxt)
            out[i] = v
            idx = (idx + 1) % p
        out *= env(n, 0.001, 0.03)
        _ks_cache[key] = out / (np.max(np.abs(out)) or 1)
    return vol * _ks_cache[key]


def osc(m, d, shape="sine", vol=0.3, a=0.01, r=0.05, decay=None, vib=0.0, vib_rate=5.5, glide_from=None, glide_t=0.08):
    tt = t(d)
    f = np.full(len(tt), hz(m))
    if glide_from is not None:
        g = np.clip(tt / glide_t, 0, 1)
        f = hz(glide_from) * (1 - g) + f * g
    if vib:
        f = f * (1 + vib * np.sin(2 * np.pi * vib_rate * tt) * np.clip(tt / 0.25, 0, 1))
    ph = 2 * np.pi * np.cumsum(f) / SR
    if shape == "square":
        s = np.tanh(2.5 * np.sin(ph))
    elif shape == "tri":
        s = 2 / np.pi * np.arcsin(np.sin(ph))
    elif shape == "saw":
        s = 2 * ((ph / (2 * np.pi)) % 1) - 1
    elif shape == "organ":
        s = np.sin(ph) + 0.5 * np.sin(2 * ph) + 0.25 * np.sin(3 * ph) + 0.18 * np.sin(4 * ph) + 0.1 * np.sin(6 * ph)
        s /= 2.0
    else:
        s = np.sin(ph)
    return vol * s * env(len(tt), a, r, decay)


def bell(m, d, vol=0.3, decay=0.35):
    tt = t(d)
    f = hz(m)
    s = np.sin(2 * np.pi * f * tt) + 0.4 * np.sin(2 * np.pi * f * 2.0 * tt) * np.exp(-tt / 0.15) + 0.2 * np.sin(2 * np.pi * f * 3.01 * tt) * np.exp(-tt / 0.08)
    return vol * s * env(len(tt), 0.001, 0.03, decay)


def noise(d, vol=0.3, decay=0.05, lp=0.5, hp=False):
    n = rng.standard_normal(int(SR * d))
    if hp:
        n = np.diff(n, prepend=0)
    y = lowpass(n, lp) if lp < 1 else n
    return vol * y * env(len(y), 0.001, 0.01, decay)


def kick(vol=0.6):
    tt = t(0.22)
    f = 45 + 110 * np.exp(-tt / 0.03)
    ph = 2 * np.pi * np.cumsum(f) / SR
    return vol * np.sin(ph) * env(len(tt), 0.001, 0.02, 0.09)


def snare(vol=0.3):
    n = noise(0.16, vol, 0.05, 0.7)
    n[: int(SR * 0.1)] += osc(50, 0.1, "tri", vol * 0.6, 0.001, 0.02, 0.04)
    return n


def hat(vol=0.08, d=0.05):
    return noise(d, vol, 0.015, 1.0, hp=True)


class Track:
    def __init__(self, seconds):
        self.n = int(SR * seconds)
        self.buf = np.zeros(self.n + SR * 4)

    def put(self, sig, at):
        i = int(SR * at)
        self.buf[i:i + len(sig)] += sig

    def loop(self):
        # fold the tail (reverb/decays past the loop end) back onto the start: seamless
        out = self.buf[: self.n].copy()
        tail = self.buf[self.n:]
        k = min(len(tail), self.n)
        out[:k] += tail[:k]
        return out


def echo(x, delay, fb=0.35, mix=0.3, n=4):
    y = x.copy()
    d = int(SR * delay)
    g = mix
    for i in range(1, n + 1):
        y[d * i:] += x[: len(x) - d * i] * g
        g *= fb
    return y


def reverb(x, mix=0.25):
    # cheap multi-tap room
    y = x.copy()
    for dl, g in ((0.029, 0.5), (0.037, 0.45), (0.053, 0.4), (0.079, 0.3), (0.113, 0.22), (0.161, 0.15)):
        d = int(SR * dl)
        y[d:] += x[:-d] * g * mix
    return y


def dc_block(x, r=0.997):
    # one-pole high-pass (~15 Hz): removes the DC offset plucks/pads leave behind
    y = np.empty_like(x)
    prev_x = prev_y = 0.0
    for i in range(len(x)):
        prev_y = x[i] - prev_x + r * prev_y
        prev_x = x[i]
        y[i] = prev_y
    return y


def to_int16(x, peak_to=0.9):
    x = x - np.mean(x)
    peak = np.max(np.abs(x)) or 1
    x = x / peak * peak_to
    return (x * 32767).astype(np.int16)


def write(path, data):
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(to_int16(data).tobytes())


# ======================================================== main theme (F major)
def main_theme():
    bpm = 120
    b = 60 / bpm
    bars = 24
    tr = Track(bars * 4 * b)
    F, C, Dm, Bb, Am, Gm = (53, 57, 60), (48, 52, 55), (50, 53, 57), (46, 50, 53), (45, 48, 52), (43, 46, 50)
    prog = [F, C, Dm, Bb] * 2 + [Bb, C, Am, Dm, Gm, C, F, C] + [F, C, Dm, Bb] * 2
    # lead melody per 4-bar phrase: (beat, midi, beats)
    A = [(0, 72, 1), (1, 74, 0.5), (1.5, 76, 0.5), (2, 77, 1), (3, 76, 1),
         (4, 74, 1), (5, 72, 0.5), (5.5, 74, 0.5), (6, 76, 2),
         (8, 74, 1), (9, 76, 0.5), (9.5, 77, 0.5), (10, 81, 1.5), (11.5, 79, 0.5),
         (12, 77, 1), (13, 76, 1), (14, 74, 2)]
    A2 = A[:13] + [(12, 77, 0.5), (12.5, 79, 0.5), (13, 81, 1), (14, 84, 2)]
    B = [(0, 77, 1.5), (1.5, 76, 0.5), (2, 74, 1), (3, 72, 1), (4, 76, 1.5), (5.5, 77, 0.5), (6, 79, 2),
         (8, 81, 1), (9, 79, 1), (10, 77, 1), (11, 76, 1), (12, 74, 1), (13, 76, 0.5), (13.5, 77, 0.5), (14, 74, 2)]
    B2 = [(0, 74, 1), (1, 77, 1), (2, 81, 1.5), (3.5, 79, 0.5), (4, 77, 1), (5, 76, 1), (6, 79, 2),
          (8, 77, 1), (9, 76, 0.5), (9.5, 74, 0.5), (10, 72, 1), (11, 76, 1), (12, 77, 3)]
    phrases = [A, A2, B, B2, A, A2]
    lead = Track(bars * 4 * b)
    for pi, ph in enumerate(phrases):
        t0 = pi * 16 * b
        for beat, m, dur in ph:
            lead.put(pluck(m, dur * b + 0.25, 0.7, 0.32, 0.997), t0 + beat * b)
            lead.put(osc(m + 12, dur * b, "sine", 0.05, 0.01, 0.05, vib=0.004), t0 + beat * b)
    for bar, ch in enumerate(prog):
        t0 = bar * 4 * b
        root = ch[0]
        for k in range(4):
            # bass: root / fifth bounce
            m = root - 12 + (7 if k == 2 else 0)
            tr.put(osc(m, b * 0.9, "tri", 0.34, 0.004, 0.06, 0.35), t0 + k * b)
            tr.put(osc(m + 12, b * 0.25, "square", 0.04, 0.002, 0.03, 0.06), t0 + k * b + b / 2)
            # drums
            tr.put(kick(0.5 if k % 2 == 0 else 0.32), t0 + k * b)
            if k % 2 == 1:
                tr.put(snare(0.22), t0 + k * b)
            tr.put(hat(0.07), t0 + k * b + b / 2)
            tr.put(hat(0.035), t0 + k * b + b * 0.75)
            # marimba chord stabs on the off-beats
            for m2 in ch:
                tr.put(bell(m2 + 12, b * 0.5, 0.055, 0.12), t0 + k * b + b / 2)
        # warm pad (two detuned saws, low-passed)
        pad = sum(osc(m2, 4 * b, "saw", 0.03, 0.3, 0.4) + osc(m2 + 0.08, 4 * b, "saw", 0.03, 0.3, 0.4) for m2 in ch)
        tr.put(lowpass(pad, 0.08), t0)
        # sparkle on phrase starts
        if bar % 4 == 0:
            for i, m2 in enumerate((84, 88, 91)):
                tr.put(bell(m2, 0.6, 0.06, 0.25), t0 + i * 0.07)
    mix = tr.loop() + reverb(echo(lead.loop(), b * 0.75, 0.3, 0.22), 0.3)
    return mix


# ================================================ Halloween theme (D minor)
def halloween_theme():
    bpm = 96
    b = 60 / bpm
    trip = b / 3
    bars = 16
    tr = Track(bars * 4 * b)
    Dm, Bb, Gm, A7, F, C = (50, 53, 57), (46, 50, 53), (43, 46, 50), (45, 49, 52, 55), (41, 45, 48), (48, 52, 55)
    prog = [Dm, Dm, Bb, A7, Dm, Gm, Bb, A7, Gm, Dm, Bb, F, Gm, A7, Dm, A7]
    # harpsichord triplet arpeggios
    for bar, ch in enumerate(prog):
        t0 = bar * 4 * b
        tones = [m + 12 for m in ch]
        pattern = [0, 1, 2, 1, 2, 3 if len(tones) > 3 else 0]
        for k in range(12):
            m = tones[pattern[k % 6] % len(tones)] + (12 if k % 6 == 2 else 0)
            tr.put(pluck(m, trip + 0.18, 0.95, 0.12 if k % 3 == 0 else 0.08, 0.993), t0 + k * trip)
        # pizzicato bass on the beat (swung)
        for k in range(4):
            m = ch[0] - 12 + (7 if k == 2 else 0)
            tr.put(pluck(m, b * 0.8, 0.35, 0.36, 0.990), t0 + k * b)
        # low tom "boom" on 1 and 3, rattle shaker on the swung offbeat
        tr.put(kick(0.55), t0)
        tr.put(kick(0.38), t0 + 2 * b)
        for k in range(4):
            tr.put(hat(0.05, 0.07), t0 + k * b + 2 * trip)
        # organ pad, swelling
        pad = sum(osc(m, 4 * b, "organ", 0.05, 0.6, 0.5, vib=0.002, vib_rate=4.5) for m in ch)
        tr.put(lowpass(pad, 0.12), t0)
    # theremin lead (glides + vibrato), enters bar 4
    mel = [(0, 74, 2), (2, 77, 1), (3, 76, 1), (4, 74, 1.5), (5.5, 73, 0.5), (6, 74, 2),
           (8, 70, 2), (10, 69, 1), (11, 70, 1), (12, 69, 4),
           (16, 74, 2), (18, 77, 1), (19, 81, 1), (20, 79, 1.5), (21.5, 77, 0.5), (22, 76, 2),
           (24, 77, 1), (25, 76, 1), (26, 74, 1), (27, 73, 1), (28, 74, 4)]
    lead = Track(bars * 4 * b)
    for rep in range(2):  # 8 bars each: the whole loop
        prev = None
        for beat, m, dur in mel:
            at = (rep * 32 + beat) * b
            lead.put(osc(m, dur * b + 0.05, "sine", 0.16, 0.06, 0.12, vib=0.012, vib_rate=5.0, glide_from=prev, glide_t=0.12), at)
            lead.put(osc(m + 12, dur * b + 0.05, "sine", 0.025, 0.06, 0.12, vib=0.012, vib_rate=5.0), at)
            prev = m
    # celesta "ding" accents and a ghostly whoo every 4 bars
    for bar in range(0, bars, 4):
        t0 = bar * 4 * b
        for i, m in enumerate((86, 89, 93, 98)):
            tr.put(bell(m, 0.9, 0.05, 0.4), t0 + 3 * b + i * trip)
        whoo = osc(62, 1.6, "sine", 0.06, 0.5, 0.6, vib=0.03, vib_rate=3.0, glide_from=57, glide_t=0.8)
        tr.put(lowpass(whoo + noise(1.6, 0.02, 1.2, 0.05), 0.2), t0 + 8 * b)
    return tr.loop() + reverb(echo(lead.loop(), b * 1.5, 0.3, 0.25), 0.45)


# ================================================================== SFX
SFX = {}


def mixs(*parts):
    end = max(off + len(p) / SR for p, off in parts)
    out = np.zeros(int(SR * end) + 1)
    for p, off in parts:
        i = int(SR * off)
        out[i:i + len(p)] += p
    return out


# portal: deep whoosh rising + shimmer cascade
whoosh = noise(1.2, 0.35, 0.8, 0.06) * np.linspace(0.2, 1, int(SR * 1.2)) ** 2
SFX["Portal"] = mixs((whoosh, 0), (osc(48, 1.2, "sine", 0.3, 0.2, 0.3, glide_from=36, glide_t=1.0), 0),
                     *[(bell(m, 0.6, 0.12, 0.25), 0.55 + i * 0.06) for i, m in enumerate((79, 83, 86, 91, 95))])
# candy found: crinkle + sparkly major arpeggio
SFX["Candy"] = mixs((noise(0.12, 0.25, 0.04, 0.9, hp=True), 0),
                    *[(bell(m, 0.35, 0.28, 0.14), 0.05 + i * 0.06) for i, m in enumerate((84, 88, 91, 96))])
# candy bucket: rattle + two chimes
SFX["Bucket"] = mixs(*[(noise(0.05, 0.25, 0.02, 0.8, hp=True), i * 0.05) for i in range(4)],
                     (bell(81, 0.4, 0.3, 0.15), 0.2), (bell(86, 0.5, 0.3, 0.2), 0.28))
# quest complete: spooky-happy fanfare (minor -> major)
SFX["Quest"] = mixs(*[(osc(m, 0.16, "square", 0.12, 0.004, 0.04, 0.12), i * 0.11) for i, m in enumerate((62, 65, 69, 74))],
                    *[(osc(m, 0.7, "organ", 0.16, 0.01, 0.3, 0.5), 0.46) for m in (62, 66, 69, 74)],
                    (bell(98, 0.7, 0.18, 0.3), 0.46))
# event level up: organ chord swell + bell cascade
SFX["EventLevel"] = mixs(*[(osc(m, 1.3, "organ", 0.14, 0.15, 0.4, 0.8, vib=0.004), 0) for m in (50, 57, 62, 66, 69)],
                         *[(bell(m, 0.7, 0.2, 0.3), 0.35 + i * 0.08) for i, m in enumerate((81, 86, 90, 93, 98))])
# reward claim: chest pop + coin shower
SFX["Reward"] = mixs((kick(0.4), 0), (noise(0.08, 0.3, 0.03, 0.5), 0),
                     *[(bell(m, 0.3, 0.2, 0.12), 0.08 + i * 0.045) for i, m in enumerate((88, 91, 93, 96, 100, 96, 100))])
# locked gate: low "nuh-uh" buzz
SFX["Locked"] = mixs((osc(45, 0.14, "square", 0.22, 0.004, 0.03), 0), (osc(42, 0.2, "square", 0.22, 0.004, 0.05), 0.16))
# area enter: soft mysterious chime
SFX["Area"] = mixs(*[(bell(m, 0.9, 0.16, 0.5), i * 0.12) for i, m in enumerate((74, 77, 81, 86))])


if __name__ == "__main__":
    write(os.path.join(OUT, "SAG_MainTheme.wav"), dc_block(main_theme()))
    write(os.path.join(OUT, "SAG_HalloweenTheme.wav"), dc_block(halloween_theme()))
    gap = np.zeros(int(SR * 0.3))
    regions, chunks, pos = {}, [], 0.0
    for name, data in SFX.items():
        data = data / max(1.0, np.max(np.abs(data)))
        regions[name] = [round(pos, 4), round(pos + len(data) / SR, 4)]
        chunks += [data, gap]
        pos += (len(data) + len(gap)) / SR
    write(os.path.join(OUT, "SAG_SFX2.wav"), np.concatenate(chunks))
    json.dump(regions, open(os.path.join(OUT, "SAG_SFX2.json"), "w"), indent=1)
    print(json.dumps(regions))
    for f in ("SAG_MainTheme.wav", "SAG_HalloweenTheme.wav", "SAG_SFX2.wav"):
        p = os.path.join(OUT, f)
        with wave.open(p) as w:
            print(f, round(w.getnframes() / w.getframerate(), 2), "s", os.path.getsize(p) // 1024, "KB")
