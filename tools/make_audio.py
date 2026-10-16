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

write("combo.wav", mix((tone(880, 0.16, "bell", r=0.07, vol=0.5), 0), (tone(1320, 0.18, "bell", r=0.08, vol=0.35), 0.05)))
write("coin.wav", mix((tone(1568, 0.12, "bell", r=0.05, vol=0.5), 0), (tone(2093, 0.22, "bell", r=0.1, vol=0.45), 0.06)))
write("bag.wav", mix((noise(0.12, 0.5, 0.04, 7), 0), (noise(0.1, 0.35, 0.03, 8), 0.06), (tone(740, 0.12, "soft", r=0.05, vol=0.35), 0.1)))
write("unlock.wav", mix((noise(0.03, 0.4, 0.01, 9), 0), (tone(523, 0.18, "bell", r=0.08, vol=0.5), 0.04), (tone(784, 0.28, "bell", r=0.12, vol=0.5), 0.12)))

# Music: an original, gentle café tune (jazz-waltz-free 4/4 in F major) with an
# electric-piano comp, a walking bass, a soft brush on 2 and 4, and a melody
# that changes on the second pass. 32 bars at 88 bpm (~87 s), seamless loop.
# 22.05 kHz mono to save space; the importer compresses it to QOA.
MSR = 22050
def ep(freq, dur, vol, r, trem=True):
    n = int(MSR * dur); ph = 0.0; out = []
    for i in range(n):
        t = i / MSR
        ph += 2 * math.pi * freq / MSR
        v = math.sin(ph) + 0.22 * math.sin(2 * ph) * math.exp(-t / 0.3) + 0.06 * math.sin(3 * ph)
        a = min(1.0, i / (0.006 * MSR)); rel = math.exp(-t / r)
        tr = (1 + 0.08 * math.sin(2 * math.pi * 4.5 * t)) if trem else 1.0
        out.append(v * a * rel * vol * tr)
    return out
def bass(freq, dur, vol):
    n = int(MSR * dur); ph = 0.0; out = []
    for i in range(n):
        t = i / MSR
        ph += 2 * math.pi * freq / MSR
        v = math.sin(ph) + 0.3 * math.sin(2 * ph)
        a = min(1.0, i / (0.01 * MSR)); rel = math.exp(-t / 0.35)
        out.append(v * a * rel * vol)
    return out
def brush(dur, vol, seed):
    rnd = random.Random(seed); n = int(MSR * dur); out = []; lp = 0.0; hp = 0.0
    for i in range(n):
        x = rnd.uniform(-1, 1)
        lp += 0.5 * (x - lp); hp = x - lp
        out.append(hp * vol * math.exp(-(i / MSR) / 0.06))
    return out
hz = lambda m: 440 * 2 ** ((m - 69) / 12)
bpm = 88; beat = 60 / bpm
# chords as MIDI notes (root used by the bass)
F7M=[53,57,60,64]; Dm7=[50,53,57,60]; Gm7=[55,58,62,65]; C7=[48,52,55,58]; Am7=[57,60,64,67]
Bb7M=[46,50,53,57]; F7=[53,57,60,63]; Bbm6=[46,49,53,55]; D7=[50,54,57,60]; C7s=[48,52,55,58]
prog = [F7M, Dm7, Gm7, C7, Am7, Dm7, Bb7M, C7, F7M, F7, Bb7M, Bbm6, Am7, D7, Gm7, C7s]
bars = prog * 2
mel_a = [ # (beat offset within bar, midi, beats) per bar
 [(0,72,1.5),(1.5,69,0.5),(2,72,1),(3,74,1)], [(0,77,2),(2,76,1),(3,74,1)], [(0,74,1.5),(1.5,70,0.5),(2,74,2)], [(0,72,3),(3,70,1)],
 [(0,69,1.5),(1.5,72,0.5),(2,76,2)], [(0,74,1),(1,72,1),(2,69,2)], [(0,70,1),(1,74,1),(2,77,1),(3,76,1)], [(0,74,4)],
 [(0,72,1.5),(1.5,74,0.5),(2,76,1),(3,77,1)], [(0,79,2),(2,75,2)], [(0,74,1),(1,77,1),(2,74,1),(3,70,1)], [(0,73,2),(2,72,2)],
 [(0,72,1),(1,76,1),(2,79,2)], [(0,78,1.5),(1.5,74,0.5),(2,72,2)], [(0,70,1),(1,74,1),(2,77,1),(3,74,1)], [(0,72,2),(2,67,2)],
]
mel_b = [ # second pass: higher, sparser, answering phrases
 [(1,77,1),(2,76,1),(3,77,1)], [(0,81,2),(3,79,1)], [(0,77,1),(1,74,1),(2,70,2)], [(1,76,1),(2,79,2)],
 [(0,81,1.5),(1.5,79,0.5),(2,76,2)], [(0,77,1),(1,74,1),(2,72,2)], [(0,74,1),(1,77,1),(2,81,2)], [(0,79,2),(2,76,2)],
 [(0,77,2),(2,81,2)], [(0,84,1.5),(1.5,82,0.5),(2,79,2)], [(0,77,1),(1,74,1),(2,77,2)], [(0,76,1),(1,73,1),(2,72,2)],
 [(0,76,1),(1,79,1),(2,84,2)], [(0,81,1),(1,78,1),(2,74,2)], [(0,74,1),(1,77,1),(2,79,1),(3,76,1)], [(0,77,4)],
]
bar_len = 4 * beat
total = int(MSR * bar_len * len(bars)); buf = [0.0] * (total + MSR * 3)
def add(seg, t):
    o = int(t * MSR)
    for i, v in enumerate(seg): buf[o + i] += v
for bi, ch in enumerate(bars):
    t0 = bi * bar_len
    # comp: chord on beat 1 and the "and" of 2 (light swing feel)
    for off, vol in ((0, 0.075), (1.5, 0.05), (3, 0.04)):
        for m in ch[1:]:
            add(ep(hz(m + 12), beat * 1.4, vol, 0.45), t0 + off * beat)
    # walking bass: root, fifth, root+octave-ish, approach
    root = ch[0] - 12
    walk = [root, root + 7, root + 12 if bi % 2 else root + 4, root + 5 if bi % 4 == 3 else root + 2]
    for k, m in enumerate(walk):
        add(bass(hz(m), beat * 0.95, 0.16), t0 + k * beat)
    # brush on 2 and 4
    for k in (1, 3):
        add(brush(beat * 0.5, 0.05, bi * 4 + k), t0 + k * beat)
    mel = (mel_a if bi < len(prog) else mel_b)[bi % len(prog)]
    for off, m, ln in mel:
        add(ep(hz(m), beat * ln * 1.25, 0.12, 0.5 + ln * 0.15), t0 + off * beat)
# wrap the tail into the start for a seamless loop
for i in range(len(buf) - total): buf[i] += buf[total + i]
write("music_cafe.wav", buf[:total], MSR)
print("audio written to", out_dir)
