#!/usr/bin/env python3
"""Synthesises all game audio from scratch (original, no samples).
Usage: python3 tools/make_audio.py game/assets/audio
Deterministic: same script -> same files."""
import math, random, struct, sys, wave, os

SR = 44100
out_dir = sys.argv[1] if len(sys.argv) > 1 else "game/assets/audio"
os.makedirs(out_dir, exist_ok=True)

def write(name, samples, sr=SR):
    peak = max(1e-9, max(abs(s) for s in samples))
    gain = min(1.0, 0.89 / peak)
    with wave.open(os.path.join(out_dir, name), "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(sr)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1, min(1, s * gain)) * 32767)) for s in samples))

def env(i, n, a=0.005, r=None):
    t = i / SR; dur = n / SR
    att = min(1.0, t / a) if a > 0 else 1.0
    rel = math.exp(-t / r) if r else max(0.0, 1 - t / dur)
    return att * rel

def tone(freq, dur, kind="sine", a=0.004, r=0.08, vol=1.0, bend=0.0):
    n = int(SR * dur); out = []; ph = 0.0
    for i in range(n):
        f = freq * (1 + bend * i / n)
        ph += 2 * math.pi * f / SR
        if kind == "sine": v = math.sin(ph)
        elif kind == "soft": v = math.sin(ph) + 0.25 * math.sin(2 * ph) + 0.08 * math.sin(3 * ph)
        elif kind == "bell": v = math.sin(ph) + 0.4 * math.sin(2.76 * ph) * math.exp(-i / SR / 0.05)
        out.append(v * env(i, n, a, r) * vol)
    return out

def mix(*parts):
    n = max(len(p) for p, _ in parts)
    out = [0.0] * n
    for p, off in parts:
        o = int(off * SR)
        for i, v in enumerate(p):
            if o + i < n + o and o + i < len(out): out[o + i] += v
            elif o + i >= len(out): out.append(v)
    return out

def noise(dur, vol=0.3, r=0.03, seed=1):
    rnd = random.Random(seed); n = int(SR * dur); out = []; lp = 0.0
    for i in range(n):
        lp += 0.25 * (rnd.uniform(-1, 1) - lp)
        out.append(lp * vol * env(i, n, 0.001, r))
    return out

# UI / gameplay effects ------------------------------------------------------
write("tap.wav", mix((tone(660, 0.09, "soft", r=0.03, vol=0.6), 0), (noise(0.03, 0.25, 0.01), 0)))
write("place.wav", mix((tone(520, 0.14, "soft", r=0.05, vol=0.7), 0), (tone(780, 0.1, "sine", r=0.04, vol=0.3), 0.03)))
write("counter.wav", mix((tone(330, 0.16, "soft", r=0.06, vol=0.7), 0), (noise(0.05, 0.2, 0.02, 2), 0)))
write("invalid.wav", mix((tone(220, 0.16, "soft", r=0.07, vol=0.55, bend=-0.08), 0), (tone(208, 0.16, "sine", r=0.07, vol=0.35), 0.06)))
write("stage.wav", mix((tone(784, 0.18, "bell", r=0.09, vol=0.6), 0), (tone(988, 0.2, "bell", r=0.1, vol=0.5), 0.07)))
write("deliver.wav", mix((tone(659, 0.25, "bell", r=0.12, vol=0.6), 0), (tone(831, 0.25, "bell", r=0.12, vol=0.55), 0.07), (tone(988, 0.35, "bell", r=0.16, vol=0.55), 0.14)))
write("win.wav", mix(*[(tone(f, 0.6, "bell", r=0.25, vol=0.5), d) for f, d in [(523, 0), (659, 0.1), (784, 0.2), (1047, 0.32), (784, 0.48), (1047, 0.6)]]))
write("star.wav", mix((tone(1175, 0.25, "bell", r=0.1, vol=0.5), 0), (tone(1568, 0.3, "bell", r=0.12, vol=0.35), 0.05)))
write("lose.wav", mix((tone(392, 0.35, "soft", r=0.18, vol=0.5), 0), (tone(330, 0.45, "soft", r=0.22, vol=0.5), 0.18)))
write("restore.wav", mix(*[(tone(f, 0.9, "bell", r=0.35, vol=0.45), d) for f, d in [(392, 0), (494, 0.12), (587, 0.24), (784, 0.36), (988, 0.5)]] + [(noise(0.6, 0.12, 0.3, 5), 0.3)]))
write("undo.wav", tone(500, 0.12, "soft", r=0.05, vol=0.5, bend=-0.25))
write("warn.wav", mix((tone(440, 0.12, "sine", r=0.05, vol=0.35), 0), (tone(440, 0.12, "sine", r=0.05, vol=0.3), 0.16)))

# Music: gentle café waltz-ish loop (I-vi-IV-V in C), 22.05 kHz to save space.
MSR = 22050
def mtone(freq, dur, vol, r):
    n = int(MSR * dur); ph = 0.0; out = []
    for i in range(n):
        ph += 2 * math.pi * freq / MSR
        v = math.sin(ph) + 0.18 * math.sin(2 * ph) + 0.05 * math.sin(3 * ph)
        a = min(1.0, i / (0.01 * MSR)); rel = math.exp(-(i / MSR) / r)
        out.append(v * a * rel * vol)
    return out
bpm = 84; beat = 60 / bpm
chords = [[60, 64, 67], [57, 60, 64], [53, 57, 60], [55, 59, 62]] * 2
melody = [72, 74, 76, 74, 72, 69, 72, 71, 69, 67, 69, 72, 74, 72, 71, 67,
          76, 77, 79, 76, 72, 74, 76, 72, 69, 72, 69, 65, 67, 71, 74, 72]
hz = lambda m: 440 * 2 ** ((m - 69) / 12)
total = int(MSR * beat * 4 * len(chords)); buf = [0.0] * (total + MSR * 2)
for ci, ch in enumerate(chords):
    t0 = ci * 4 * beat
    for k in range(4):
        notes = [ch[0] - 12] if k == 0 else ch
        for m in notes:
            seg = mtone(hz(m), beat * 1.6, 0.11 if k else 0.16, 0.5)
            o = int((t0 + k * beat) * MSR)
            for i, v in enumerate(seg): buf[o + i] += v
for mi, m in enumerate(melody):
    seg = mtone(hz(m), beat * 1.8, 0.13, 0.35)
    o = int(mi * 2 * beat * MSR * len(chords) * 4 / (2 * len(melody)))
    for i, v in enumerate(seg): buf[o + i] += v
# wrap the tail into the start for a seamless loop
for i in range(len(buf) - total): buf[i] += buf[total + i]
write("music_cafe.wav", buf[:total], MSR)
print("audio written to", out_dir)
