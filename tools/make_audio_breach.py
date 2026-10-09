"""Synthesise the Goober Breach / Goober Blaster sound effects (from scratch).

Outputs (Assets/Audio):
  SAG_SFX3.wav   effects back to back (a "sound sprite")
  SAG_SFX3.json  { name: [start_seconds, end_seconds] }
Reuses the synth helpers in make_audio_halloween.py.
"""
import json
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import make_audio_halloween as A  # noqa: E402

SR = A.SR
mixs, osc, bell, noise, kick, write, lowpass = A.mixs, A.osc, A.bell, A.noise, A.kick, A.write, A.lowpass
OUT = A.OUT

SFX = {}
# breach charging: a rising electric hum with a pulsing shimmer
t = A.t(2.2)
f = 70 * (1 + 2.2 * (t / 2.2) ** 1.6)
ph = 2 * np.pi * np.cumsum(f) / SR
hum = 0.22 * (np.sin(ph) + 0.4 * np.sin(2 * ph) + 0.15 * np.sin(3.01 * ph)) * A.env(len(t), 0.3, 0.2)
pulse = 0.5 + 0.5 * np.sin(2 * np.pi * (3 + 9 * t / 2.2) * t)
SFX["BreachCharge"] = mixs((hum * (0.6 + 0.4 * pulse), 0), (lowpass(noise(2.2, 0.06, 2.0, 1.0, hp=True), 0.5) * np.linspace(0.2, 1, int(SR * 2.2)), 0))
# rare rift alarm: two-tone warble over a rumble
SFX["BreachAlarm"] = mixs(*[(osc(m, 0.22, "square", 0.14, 0.01, 0.04), i * 0.24) for i, m in enumerate((79, 74, 79, 74, 79, 74))],
                          (osc(36, 1.5, "sine", 0.25, 0.1, 0.3), 0))
# breach blast: boom + whoosh + sparkle cascade
boom = kick(0.9)
whoosh = noise(1.0, 0.45, 0.45, 0.12) * np.linspace(1, 0.1, int(SR * 1.0))
SFX["BreachOpen"] = mixs((boom, 0), (osc(40, 0.9, "sine", 0.4, 0.002, 0.3, 0.35), 0), (whoosh, 0.02),
                         *[(bell(m, 0.5, 0.11, 0.25), 0.12 + i * 0.05) for i, m in enumerate((84, 88, 91, 96, 100))])
# blaster shot: wet "splurt" (falling pitch + gurgle noise)
SFX["Blast"] = mixs((osc(60, 0.28, "square", 0.18, 0.002, 0.06, 0.12, glide_from=72, glide_t=0.2), 0),
                    (lowpass(noise(0.3, 0.3, 0.12, 0.6), 0.35), 0))
# hit on a carrier: splat thwack
SFX["Hit"] = mixs((kick(0.6), 0), (noise(0.25, 0.5, 0.06, 0.8), 0), (osc(55, 0.3, "tri", 0.3, 0.002, 0.08, 0.1, glide_from=67, glide_t=0.25), 0.02))
# hit confirmed (for the shooter): bright double ding
SFX["HitConfirm"] = mixs((bell(91, 0.25, 0.25, 0.08), 0), (bell(96, 0.35, 0.25, 0.12), 0.07))
# goober dropped: bonk + boing
SFX["Drop"] = mixs((osc(48, 0.15, "sine", 0.45, 0.001, 0.05, 0.06, glide_from=60, glide_t=0.1), 0),
                   (osc(72, 0.45, "sine", 0.2, 0.005, 0.1, vib=0.06, vib_rate=14.0, glide_from=60, glide_t=0.3), 0.1))
# delivered home: rising sparkle chord
SFX["Deliver"] = mixs(*[(bell(m, 0.6, 0.2, 0.35), i * 0.07) for i, m in enumerate((72, 76, 79, 84, 88))],
                      (osc(60, 0.8, "tri", 0.1, 0.05, 0.3), 0.25), (osc(64, 0.8, "tri", 0.08, 0.05, 0.3), 0.25))

if __name__ == "__main__":
    gap = np.zeros(int(SR * 0.3))
    regions, chunks, pos = {}, [], 0.0
    for name, data in SFX.items():
        data = data / max(1.0, np.max(np.abs(data)))
        regions[name] = [round(pos, 4), round(pos + len(data) / SR, 4)]
        chunks += [data, gap]
        pos += (len(data) + len(gap)) / SR
    write(os.path.join(OUT, "SAG_SFX3.wav"), np.concatenate(chunks))
    json.dump(regions, open(os.path.join(OUT, "SAG_SFX3.json"), "w"), indent=1)
    print(json.dumps(regions))
