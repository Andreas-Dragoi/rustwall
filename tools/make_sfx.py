#!/usr/bin/env python3
"""Rendert alle Soundeffekte von Rustwall nach audio/sfx/<name>.wav (16 Bit, mono;
Effekte bis 0,2 s mit 44,1 kHz, längere Klänge und Schleifen mit 22,05 kHz, Umgebung 16 kHz).
Aufruf:  python3 tools/make_sfx.py [name-filter]
Jeder Effekt ist eine kleine Funktion aus Bausteinen (Anschlag + Körper + Ausklang).
Alles ist bewusst weich und freundlich gehalten (Kinderspiel)."""
import os, sys, struct
import numpy as np
from scipy import signal as sg

SR = 44100
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "audio", "sfx")
REG = []            # (name, fn, opts)
_seed = [1]


def snd(name, **opts):
    def deco(fn):
        REG.append((name, fn, opts))
        return fn
    return deco


def rng():
    _seed[0] += 1
    return np.random.default_rng(_seed[0] * 7919)


# ------------------------------------------------------------------ Bausteine
def tt(d, sr=SR):
    return np.arange(int(d * sr)) / sr


def ramp(d, a, b, curve=1.0, sr=SR):
    """Verlauf a -> b; curve > 1: schnell am Anfang (exponentiell wirkend)."""
    n = int(d * sr)
    k = np.linspace(0.0, 1.0, n) ** (1.0 / curve) if curve != 1.0 else np.linspace(0.0, 1.0, n)
    return a + (b - a) * k


def gliss(d, f0, f1, sr=SR):
    """Geometrischer Tonhöhenverlauf (klingt gleichmäßig)."""
    n = int(d * sr)
    return f0 * (f1 / f0) ** np.linspace(0.0, 1.0, n)


def osc(freq, shape="sin", sr=SR, ph0=0.0):
    ph = ph0 + 2 * np.pi * np.cumsum(freq) / sr
    if shape == "sin":
        return np.sin(ph)
    if shape == "tri":
        return 2 / np.pi * np.arcsin(np.sin(ph))
    if shape == "sq":
        return np.tanh(3.0 * np.sin(ph))          # weiches Rechteck
    if shape == "saw":
        x = (ph / (2 * np.pi)) % 1.0
        return 2 * x - 1
    raise ValueError(shape)


def tone(d, f0, f1=None, shape="sin", sr=SR):
    return osc(gliss(d, f0, f1 if f1 else f0, sr), shape, sr)


def dec(d, rate, sr=SR):
    return np.exp(-tt(d, sr) * rate)


def ar(d, a=0.005, r=0.05, sr=SR):
    n = int(d * sr)
    e = np.ones(n)
    na = max(1, min(n, int(a * sr)))
    nr = max(1, min(n, int(r * sr)))
    e[:na] *= np.linspace(0, 1, na)
    e[-nr:] *= np.linspace(1, 0, nr) ** 1.5
    return e


def hann(d, sr=SR):
    n = int(d * sr)
    return 0.5 - 0.5 * np.cos(2 * np.pi * np.arange(n) / max(n - 1, 1))


def noise(d, sr=SR):
    return rng().uniform(-1, 1, int(d * sr))


def lp(x, fc, order=2, sr=SR):
    return sg.sosfilt(sg.butter(order, min(fc, sr * 0.45), "low", fs=sr, output="sos"), x)


def hp(x, fc, order=2, sr=SR):
    return sg.sosfilt(sg.butter(order, fc, "high", fs=sr, output="sos"), x)


def bp(x, f1, f2, order=2, sr=SR):
    return sg.sosfilt(sg.butter(order, [f1, min(f2, sr * 0.45)], "band", fs=sr, output="sos"), x)


def reso(x, fc, q=6.0, sr=SR):
    b, a = sg.iirpeak(fc, q, fs=sr)
    return sg.lfilter(b, a, x)


def mix(*parts):
    """parts: (signal, offset_s, gain) oder nur signal."""
    items = []
    for p in parts:
        if isinstance(p, tuple):
            s, off, g = (p + (1.0,))[:3] if len(p) == 2 else p
        else:
            s, off, g = p, 0.0, 1.0
        items.append((np.asarray(s, dtype=np.float64), int(off * SR), g))
    n = max(o + len(s) for s, o, g in items)
    out = np.zeros(n)
    for s, o, g in items:
        out[o:o + len(s)] += s * g
    return out


def seq(parts):
    return np.concatenate(parts)


def soft(x, drive=1.0):
    return np.tanh(x * drive) / np.tanh(drive)


def echo(x, delay, fb=0.35, n=3, lp_fc=3000):
    out = [x]
    cur = x
    for i in range(n):
        cur = lp(cur, lp_fc) * fb
        out.append((cur, delay * (i + 1), 1.0))
    return mix(*out)


def band_noise(d, f0, f1, bw, sr=SR):
    """Rauschband, dessen Mitte von f0 nach f1 wandert (Wusch)."""
    base = lp(noise(d, sr), bw, 2, sr)
    return base * osc(gliss(d, f0, f1, sr), "sin", sr) * 3.0


def whoosh(d, f0, f1, bw=400.0, a=0.3):
    n = int(d * SR)
    e = np.interp(np.linspace(0, 1, n), [0, a, 1], [0, 1, 0]) ** 1.5
    return band_noise(d, f0, f1, bw) * e


def thump(d, f0, f1, rate=18.0, shape="sin"):
    return osc(gliss(d, f0, f1), shape) * dec(d, rate) * ar(d, 0.002, 0.02)


def click(d=0.02, f1=1500, f2=6000, rate=200.0):
    return bp(noise(d), f1, f2) * dec(d, rate)


def pluck(f, d, rate=9.0, shape="tri", bright=0.3):
    x = tone(d, f, shape=shape) + bright * tone(d, f * 2, shape="sin") * dec(d, rate * 2)
    return x * dec(d, rate) * ar(d, 0.003, 0.03)


def bell(f, d, rate=5.0, ratio=3.5, index=2.0, idec=14.0):
    t = tt(d)
    mod = np.sin(2 * np.pi * f * ratio * t) * index * np.exp(-t * idec)
    x = np.sin(2 * np.pi * f * t + mod) + 0.25 * np.sin(2 * np.pi * f * 2.01 * t) * np.exp(-t * rate * 2)
    return x * np.exp(-t * rate) * ar(d, 0.002, 0.04)


def brass(f, d, a=0.03):
    """Weiche Spielzeug-Trompete."""
    t = tt(d)
    vib = 1.0 + 0.004 * np.sin(2 * np.pi * 5.5 * t) * np.minimum(t * 4, 1)
    x = osc(f * vib * np.ones(len(t)), "saw") * 0.6 + osc(f * vib * np.ones(len(t)), "sq") * 0.4
    cut = 900 + 2200 * np.minimum(t / a, 1.0) * np.exp(-t * 1.2)
    y = lp(x, float(np.mean(cut)) + 600)
    return y * ar(d, a, min(0.12, d * 0.4))


def blub(d, f0, f1, wob=0.0, wob_f=18.0):
    """Schleim-Laut: Sinus mit Tonhöhenverlauf, leichtem Wabbeln und einem Formanten."""
    f = gliss(d, f0, f1)
    if wob:
        f = f * (1.0 + wob * np.sin(2 * np.pi * wob_f * tt(d)))
    x = osc(f, "sin") + 0.35 * osc(f * 2.0, "sin") + 0.15 * osc(f * 3.0, "tri")
    return x * hann(d) ** 0.6


def bubble(f=500.0, d=0.07, up=2.2):
    return osc(gliss(d, f, f * up), "sin") * dec(d, 30.0) * ar(d, 0.002, 0.02)


def squish(d, fc=900.0, rate=20.0):
    return lp(noise(d), fc) * dec(d, rate) * ar(d, 0.004, 0.03) * 2.0


def boing(d, f, depth=0.5, wf=14.0):
    t = tt(d)
    fr = f * (1.0 + depth * np.sin(2 * np.pi * wf * t) * np.exp(-t * 6.0))
    return osc(fr, "sin") * np.exp(-t * 6.0) * ar(d, 0.003, 0.05)


def crackle(d, density=120.0, fc=3000.0):
    r = rng()
    n = int(d * SR)
    x = np.zeros(n)
    k = int(d * density)
    idx = r.integers(0, max(n - 1, 1), k)
    x[idx] = r.uniform(-1, 1, k)
    return hp(lp(x, 9000), fc) * 6.0


def sparkle(d, f_lo=2500, f_hi=6000, count=8):
    r = rng()
    parts = []
    for i in range(count):
        f = r.uniform(f_lo, f_hi)
        parts.append((bell(f, 0.18, 22.0, 2.0, 1.0), r.uniform(0, max(d - 0.18, 0.01)), r.uniform(0.3, 0.8)))
    return mix(np.zeros(int(d * SR)), *parts)


def boom(size=1.0):
    """Weiche Explosion: Druckstoß + Grollen + Knistern.  size 0.5 klein … 2 riesig."""
    d = 0.45 + 0.45 * size
    body = thump(d, 150.0 / size ** 0.5, 38.0, 7.0 / size ** 0.5)
    rumble = lp(noise(d), 500.0 / size ** 0.3) * dec(d, 6.0 / size ** 0.5) * 1.6
    snap = bp(noise(0.08), 600, 3500) * dec(0.08, 45.0) * 0.8
    crk = crackle(d * 0.8, 90.0, 1500.0) * dec(d * 0.8, 6.0) * 0.12
    return soft(mix(body, rumble, snap, (crk, 0.04, 1.0)), 1.4)


NOTE = {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}


def hz(n):
    """'C5', 'F#4', 'Bb3' -> Hz"""
    name, octv = n[:-1], int(n[-1])
    s = NOTE[name[0]] + (1 if "#" in name else 0) - (1 if "b" in name else 0)
    return 440.0 * 2 ** ((s - 9) / 12 + octv - 4)


def jingle(notes, inst="bell", step=0.1, last=0.6, rate=6.0):
    """notes: Liste von Notennamen oder Tupeln (gleichzeitig)."""
    parts = []
    for i, nn in enumerate(notes):
        d = last if i == len(notes) - 1 else max(step * 2.5, 0.25)
        for n in (nn if isinstance(nn, tuple) else (nn,)):
            f = hz(n)
            if inst == "bell":
                s = bell(f, d, rate)
            elif inst == "brass":
                s = brass(f, step * 0.95 if i < len(notes) - 1 else last)
            else:
                s = pluck(f, d, rate)
            parts.append((s, i * step, 0.7))
    return mix(*parts)


def loopify(x, xf):
    """Macht ein Rauschsignal nahtlos: das Ende wird in den Anfang geblendet."""
    n = int(xf * SR) if xf < 50 else int(xf)
    k = np.linspace(0, 1, n)
    y = x[:-n].copy()
    y[:n] = x[:n] * np.sin(k * np.pi / 2) + x[-n:] * np.cos(k * np.pi / 2)
    return y


def wrap_add(buf, s, pos):
    n = len(buf)
    idx = (pos + np.arange(len(s))) % n
    np.add.at(buf, idx, s)


# ------------------------------------------------------------------ Ausgabe
def loud(x, sr):
    """Größte Kurzzeit-Lautheit (grob gehörrichtig gewichtet), in dB."""
    y = hp(x, 120.0, 2, sr)
    y = y + 0.6 * hp(y, 1800.0, 1, sr)
    w = int(0.08 * sr)
    if len(y) <= w:
        return 10 * np.log10(np.mean(y ** 2) * len(y) / w + 1e-12)
    p = np.convolve(y ** 2, np.ones(w) / w, "valid")
    return 10 * np.log10(p.max() + 1e-12)


def write_wav(path, x, sr, loop=False):
    pcm = (np.clip(x, -1, 1) * 32767.0).astype("<i2").tobytes()
    fmt = struct.pack("<4sIHHIIHH", b"fmt ", 16, 1, 1, sr, sr * 2, 2, 16)
    data = struct.pack("<4sI", b"data", len(pcm)) + pcm
    smpl = b""
    if loop:
        n = len(x)
        smpl = struct.pack("<4sI9I6I", b"smpl", 60, 0, 0, int(1e9 / sr), 60, 0, 0, 0, 1, 0, 0, 0, 0, n - 1, 0, 0)
    body = b"WAVE" + fmt + data + smpl
    with open(path, "wb") as f:
        f.write(struct.pack("<4sI", b"RIFF", len(body)) + body)


def finish(x, opts):
    sr = opts.get("sr", SR)
    x = np.asarray(x, dtype=np.float64)
    x = x - np.mean(x)
    is_loop = opts.get("loop", False)
    if not is_loop:
        # Stille am Ende abschneiden, kurze Blenden gegen Knackser
        peak = np.max(np.abs(x)) + 1e-9
        idx = np.nonzero(np.abs(x) > peak * 0.02)[0]
        end = min(len(x), idx[-1] + int(0.03 * sr))
        x = x[:end]
        fi = min(len(x) // 4, int(0.0015 * sr))
        fo = min(len(x) // 3, int(opts.get("fade", 0.045) * sr))
        x[:fi] *= np.linspace(0, 1, fi)
        x[-fo:] *= np.linspace(1, 0, fo)
    # lange Klänge (Fanfaren, Fähigkeiten, Schleifen) mit halber Abtastrate: spart Platz
    if sr == SR and (len(x) > 0.2 * SR or is_loop) and not opts.get("full", False):
        if is_loop:
            x = sg.resample(x, len(x) // 2)          # periodisch -> bleibt nahtlos
        else:
            x = sg.resample_poly(x, 1, 2)
        sr = SR // 2
    target = -15.0 + opts.get("g", 0.0)
    x = x * 10 ** ((target - loud(x, sr)) / 20)
    pk = np.max(np.abs(x))
    if pk > 0.84:                       # Spitzen weich begrenzen statt alles leiser zu machen
        x = np.tanh(x / pk * 1.6) / np.tanh(1.6) * min(pk, 0.84)
        x = x * 10 ** ((target - loud(x, sr)) / 20)
        pk = np.max(np.abs(x))
        if pk > 0.89:
            x *= 0.89 / pk
    return x, sr


# ================================================================== Bedienung
@snd("click")
def _():
    return mix(pluck(1250, 0.05, 60.0, "sin"), (click(0.012, 2000, 7000), 0, 0.5))

@snd("ui_open")
def _():
    return mix(whoosh(0.16, 500, 1600, 500) * 0.5, (pluck(660, 0.12, 22.0), 0.02, 0.8), (pluck(990, 0.14, 20.0), 0.07, 0.7))

@snd("ui_close")
def _():
    return mix(whoosh(0.14, 1500, 450, 500) * 0.5, (pluck(880, 0.1, 24.0), 0.0, 0.7), (pluck(587, 0.14, 20.0), 0.05, 0.8))

@snd("ui_tab")
def _():
    return mix(pluck(784, 0.07, 40.0, "sin"), (click(0.01, 1500, 5000), 0, 0.5), (pluck(1175, 0.08, 34.0, "sin"), 0.035, 0.7))

@snd("ui_select")
def _():
    return mix(bell(988, 0.14, 22.0, 2.0, 1.0), (click(0.01, 2500, 8000), 0, 0.3))

@snd("ui_equip")
def _():
    return mix(thump(0.09, 300, 140, 30.0) * 0.8, (click(0.03, 1800, 6000, 90), 0.0, 0.7), (bell(1320, 0.22, 14.0, 1.4, 1.6), 0.05, 0.6), (click(0.02, 3000, 8000), 0.09, 0.4))

@snd("ui_upgrade")
def _():
    return mix(jingle(["C5", "E5", "G5", "C6"], "bell", 0.07, 0.45, 7.0), (sparkle(0.4, 3000, 6500, 6), 0.2, 0.25), whoosh(0.25, 400, 2400, 600) * 0.3)

@snd("ui_buy")
def _():
    return mix(bell(1568, 0.1, 30.0, 2.0, 1.2), (bell(2093, 0.3, 11.0, 2.0, 1.2), 0.07, 1.0), (click(0.02, 3000, 9000), 0.0, 0.4), (bell(2637, 0.25, 14.0), 0.12, 0.4))

@snd("ui_dismantle")
def _():
    r = rng()
    parts = [thump(0.12, 200, 80, 22.0)]
    for i in range(5):
        parts.append((bell(r.uniform(900, 2400), 0.09, 40.0, 1.4, 2.5), 0.02 + i * 0.035 + r.uniform(0, 0.01), 0.5))
    parts.append((bp(noise(0.2), 800, 4000) * dec(0.2, 18.0), 0.0, 0.5))
    return mix(*parts)

@snd("ui_merge")
def _():
    return mix(whoosh(0.35, 300, 2600, 500, 0.8) * 0.6, (bell(784, 0.5, 6.0), 0.3, 0.8), (bell(1175, 0.5, 6.0), 0.3, 0.7), (bell(1568, 0.55, 5.0), 0.33, 0.7), (sparkle(0.4, 3000, 7000, 7), 0.32, 0.3))

@snd("ui_claim")
def _():
    return mix(jingle(["G5", "C6", "E6"], "bell", 0.065, 0.4, 8.0), (bell(2093, 0.3, 12.0), 0.0, 0.3), (sparkle(0.3, 3500, 7000, 5), 0.12, 0.25))

@snd("ui_error")
def _():
    a = lp(tone(0.09, 196, shape="sq"), 1200) * ar(0.09, 0.004, 0.03)
    b = lp(tone(0.14, 156, shape="sq"), 1100) * ar(0.14, 0.004, 0.06)
    return mix(a, (b, 0.1, 1.0))

@snd("ui_toggle")
def _():
    return mix(click(0.015, 1200, 5000, 150), (pluck(520, 0.05, 50.0, "sin"), 0.0, 0.8), (pluck(780, 0.06, 45.0, "sin"), 0.03, 0.6))

@snd("ui_slider", g=-3)
def _():
    return pluck(1050, 0.035, 80.0, "sin")

@snd("ui_toast")
def _():
    return mix(bell(880, 0.12, 22.0, 2.0, 0.8), (bell(1320, 0.22, 14.0, 2.0, 0.8), 0.06, 0.8))

@snd("pay")
def _():
    return mix(bell(1760, 0.08, 34.0, 2.0, 1.0), (bell(2349, 0.2, 16.0, 2.0, 1.0), 0.05, 0.9), (click(0.015, 3000, 9000), 0, 0.3))

@snd("error")
def _():
    a = lp(tone(0.08, 185, shape="sq"), 1000) * ar(0.08, 0.004, 0.03)
    return mix(a, (a, 0.1, 0.9))

@snd("chest_open")
def _():
    creak = reso(osc(gliss(0.28, 160, 330) * (1 + 0.05 * np.sin(2 * np.pi * 37 * tt(0.28))), "saw"), 900, 4.0) * hann(0.28) * 0.5
    return mix(creak, (thump(0.1, 180, 80, 25.0), 0.26, 0.9), (click(0.03, 1500, 5000, 80), 0.26, 0.6),
               (whoosh(0.4, 600, 3500, 700, 0.5), 0.28, 0.5), (jingle(["C5", "G5", "C6", "E6"], "bell", 0.06, 0.6, 5.0), 0.32, 0.9),
               (sparkle(0.6, 3000, 7500, 10), 0.4, 0.3))

for _r, (_notes, _extra) in enumerate([(["E5", "G5"], 0), (["E5", "G5", "C6"], 4), (["C5", "E5", "G5", "C6", "E6"], 8), (["C5", "G5", "C6", "E6", "G6", "C7"], 14)]):
    def _mk(notes=_notes, extra=_extra, r=_r):
        parts = [jingle(notes, "bell", 0.055, 0.35 + 0.15 * r, 9.0 - 1.5 * r)]
        if extra:
            parts.append((sparkle(0.25 + 0.12 * r, 3000, 8000, extra), 0.1, 0.3))
        if r >= 2:
            parts.append((whoosh(0.3, 500, 3000, 600, 0.6), 0.0, 0.35))
            parts.append((bell(hz("C4"), 0.7, 4.0, 1.0, 1.5), 0.05 * len(notes), 0.5))
        if r >= 3:
            parts.append((brass(hz("C5"), 0.5), 0.3, 0.35))
            parts.append((brass(hz("G5"), 0.5), 0.3, 0.3))
            parts.append((brass(hz("E5"), 0.5), 0.3, 0.3))
        return mix(*parts)
    REG.append(("chest_item_%d" % _r, _mk, {"g": -1 + _r}))

@snd("chest")
def _():
    return mix(thump(0.1, 220, 90, 24.0), (jingle(["G5", "C6", "E6", "G6"], "bell", 0.06, 0.5, 6.0), 0.04, 0.9), (sparkle(0.5, 3200, 7000, 8), 0.15, 0.3))

@snd("level_up", g=1)
def _():
    arp = jingle(["C5", "E5", "G5", "C6", "E6", "G6"], "bell", 0.075, 0.9, 3.5)
    chord = mix(brass(hz("C5"), 0.9), brass(hz("E5"), 0.9), brass(hz("G5"), 0.9), brass(hz("C4"), 0.9)) * 0.3
    return mix(arp, (chord, 0.42, 1.0), (whoosh(0.5, 300, 3000, 600, 0.8), 0.0, 0.35), (sparkle(0.9, 3000, 8000, 16), 0.4, 0.25))

@snd("hero_level_up")
def _():
    return mix(jingle(["G4", "C5", "E5", "G5"], "pluck", 0.08, 0.5, 5.0), (jingle(["G5", "C6", "E6", "G6"], "bell", 0.08, 0.6, 5.0), 0.0, 0.5), (sparkle(0.5, 3000, 7000, 8), 0.3, 0.25))

@snd("hero_unlock", g=1)
def _():
    fan = seq([brass(hz("G4"), 0.14), brass(hz("G4"), 0.1), brass(hz("C5"), 0.14), brass(hz("E5"), 0.14)])
    end = mix(brass(hz("G5"), 0.9), brass(hz("E5"), 0.9) * 0.7, brass(hz("C5"), 0.9) * 0.7, brass(hz("C4"), 0.9) * 0.6)
    return mix(fan, (end, 0.52, 0.8), (jingle(["C6", "E6", "G6", "C7"], "bell", 0.08, 0.7, 4.0), 0.52, 0.5), (sparkle(0.8, 3000, 8000, 14), 0.6, 0.25))

@snd("quest_done")
def _():
    return mix(jingle(["E5", "G5", "C6", ("E6", "G6")], "bell", 0.09, 0.6, 5.0), (click(0.02, 2000, 7000), 0, 0.3), (sparkle(0.4, 3500, 7000, 6), 0.25, 0.25))

# ================================================================== Held
def _step(kind, i):
    r = rng()
    if kind == "grass":
        return mix(thump(0.06, 130 + 12 * i, 70, 45.0) * 0.8, bp(noise(0.09), 1200 + 250 * i, 5500) * dec(0.09, 38.0) * hann(0.09) ** 0.3 * 0.9)
    if kind == "sand":
        return mix(thump(0.05, 110, 65, 50.0) * 0.5, bp(noise(0.13), 2200 + 300 * i, 8000) * hann(0.13) * dec(0.13, 16.0) * 1.2)
    # Schnee: Knirschen
    cr = crackle(0.12, 500.0 + 80 * i, 900.0) * hann(0.12)
    return mix(thump(0.05, 100, 60, 50.0) * 0.5, bp(cr + noise(0.12) * 0.25, 700, 3800) * 1.2)

for _k in ("grass", "sand", "snow"):
    for _i in range(3):
        REG.append(("step_%s_%d" % (_k, _i + 1), (lambda k=_k, i=_i: _step(k, i)), {"g": -4}))

@snd("hop")
def _():
    return mix(osc(gliss(0.14, 320, 760), "sin") * hann(0.14), (whoosh(0.14, 600, 1800, 500), 0, 0.5))

@snd("dash")
def _():
    return mix(whoosh(0.26, 500, 2800, 700, 0.25), (osc(gliss(0.16, 500, 1100), "sin") * hann(0.16), 0.0, 0.35), (thump(0.06, 160, 80, 40.0), 0, 0.5))

for _i in range(2):
    def _mk(i=_i):
        f = 400 - 50 * i
        voice = reso(osc(gliss(0.16, f, f * 0.62), "saw"), 950, 3.0) * hann(0.16) ** 0.5 * 0.4 + osc(gliss(0.16, f, f * 0.62), "sin") * hann(0.16) ** 0.5
        return mix(voice, (thump(0.07, 190, 80, 35.0), 0, 0.9), (click(0.02, 800, 3000, 90), 0, 0.5))
    REG.append(("hurt_%d" % (_i + 1), _mk, {}))

@snd("hero_down")
def _():
    f = gliss(0.7, 620, 150) * (1 + 0.04 * np.sin(2 * np.pi * 9 * tt(0.7)))
    w = (osc(f, "tri") + 0.3 * osc(f * 2, "sin")) * ar(0.7, 0.01, 0.3)
    return mix(w, (thump(0.2, 140, 50, 14.0), 0.62, 1.0), (squish(0.12, 700), 0.62, 0.5))

@snd("respawn")
def _():
    return mix(whoosh(0.5, 300, 3200, 600, 0.85) * 0.6, (jingle(["C5", "G5", "C6"], "bell", 0.1, 0.6, 5.0), 0.2, 0.9), (sparkle(0.5, 3000, 7000, 8), 0.35, 0.3))

@snd("heartbeat", g=-2)
def _():
    return mix(thump(0.12, 75, 45, 22.0), (thump(0.14, 62, 40, 18.0), 0.19, 0.75))

@snd("reload")
def _():
    return mix(click(0.03, 1500, 5000, 120), (thump(0.05, 260, 150, 50.0), 0.0, 0.5), (click(0.025, 900, 3500, 110), 0.11, 0.8), (osc(gliss(0.1, 500, 900), "sin") * hann(0.1), 0.16, 0.25))

@snd("reload_done")
def _():
    return mix(click(0.025, 1200, 4500, 130), (thump(0.05, 320, 180, 55.0), 0.0, 0.6), (click(0.03, 2200, 7000, 110), 0.06, 0.9), (bell(1760, 0.1, 30.0, 2.0, 0.8), 0.06, 0.3))

@snd("empty", g=-3)
def _():
    return mix(click(0.02, 1800, 6000, 180), (pluck(420, 0.04, 70.0, "sin"), 0, 0.5))

@snd("crit")
def _():
    return mix(click(0.03, 1500, 7000, 80), (bell(1568, 0.25, 12.0, 2.76, 2.5), 0.0, 0.9), (bell(2349, 0.25, 12.0), 0.03, 0.5), (thump(0.08, 240, 100, 30.0), 0, 0.6))

# ================================================================== Waffen
for _i in range(3):
    def _mk(i=_i):
        return mix(click(0.025, 1400 + 200 * i, 5500, 150) * 0.8, osc(gliss(0.075, 720 + 40 * i, 210), "tri") * dec(0.075, 40.0), (thump(0.06, 190, 85, 45.0), 0.0, 0.8))
    REG.append(("w_rifle_%d" % (_i + 1), _mk, {}))

for _i in range(3):
    def _mk(i=_i):
        return mix(click(0.02, 2200, 8000, 170) * 0.8, osc(gliss(0.06, 1150 + 60 * i, 380), "tri") * dec(0.06, 48.0), (thump(0.05, 240, 110, 50.0), 0.0, 0.6), (bell(2400 + 150 * i, 0.06, 50.0, 2.0, 1.0), 0, 0.2))
    REG.append(("w_burst_%d" % (_i + 1), _mk, {}))

@snd("w_parcel")
def _():
    return mix(thump(0.18, 230, 70, 16.0), lp(noise(0.14), 1100) * dec(0.14, 22.0) * 1.2, (reso(noise(0.05), 420, 5.0) * dec(0.05, 50.0), 0.0, 0.4), (whoosh(0.2, 400, 900, 300), 0.03, 0.3))

@snd("w_fireball")
def _():
    return mix(whoosh(0.32, 250, 1500, 500, 0.2), (thump(0.14, 200, 70, 18.0), 0, 0.9), (crackle(0.3, 160.0, 1200.0) * dec(0.3, 9.0), 0.02, 0.25), (lp(noise(0.3), 700) * dec(0.3, 10.0), 0, 0.8))

for _i in range(2):
    def _mk(i=_i):
        r = rng()
        parts = [thump(0.09, 210, 85, 28.0), bp(noise(0.1), 900, 4500) * dec(0.1, 40.0)]
        for k in range(4):
            parts.append((bell(r.uniform(2600, 4200), 0.05, 70.0, 1.4, 2.0), 0.004 + k * 0.012 + r.uniform(0, 0.006), 0.35))
        return mix(*parts)
    REG.append(("w_nailer_%d" % (_i + 1), _mk, {}))

@snd("w_ball_swing")
def _():
    r = rng()
    parts = [whoosh(0.3, 260, 620, 220, 0.55) * 1.2, (whoosh(0.3, 700, 1500, 300, 0.55), 0, 0.3)]
    for k in range(6):
        parts.append((bell(r.uniform(2800, 4800), 0.035, 90.0, 1.4, 2.0), 0.03 + k * 0.04 + r.uniform(0, 0.015), 0.12))
    return mix(*parts)

@snd("w_ball_thud")
def _():
    return mix(thump(0.22, 125, 42, 13.0), lp(noise(0.14), 600) * dec(0.14, 22.0) * 1.5, (bell(310, 0.25, 14.0, 1.4, 3.0), 0.0, 0.3), (click(0.02, 800, 3000, 120), 0, 0.5))

@snd("w_cement")
def _():
    return mix(blub(0.2, 270, 105) * 0.9, (squish(0.2, 800, 16.0), 0.0, 0.8), (thump(0.12, 150, 60, 20.0), 0, 0.8), (bubble(380, 0.06), 0.13, 0.5))

for _i in range(2):
    def _mk(i=_i):
        r = rng()
        d = 0.13
        f = gliss(d, 2300 - 250 * i, 520) * (1.0 + 0.35 * lp(r.uniform(-1, 1, int(d * SR)), 900))
        z = lp(osc(f, "sq"), 5000) * dec(d, 20.0)
        return mix(z * 0.8, (crackle(d, 500.0, 3500.0) * dec(d, 22.0), 0, 0.25), (osc(gliss(0.08, 1500, 3000), "sin") * dec(0.08, 40.0), 0, 0.35))
    REG.append(("w_spark_%d" % (_i + 1), _mk, {}))

@snd("w_shrink", g=-2)
def _():
    d = 0.1
    f = gliss(d, 1900, 620) * (1 + 0.06 * np.sin(2 * np.pi * 38 * tt(d)))
    return (osc(f, "sin") + 0.25 * osc(f * 1.5, "sin")) * hann(d) ** 0.5

@snd("w_cloud")
def _():
    return mix(thump(0.16, 170, 60, 16.0), (lp(noise(0.3), 1400) * hann(0.3) ** 2 * dec(0.3, 5.0) * 1.5, 0, 1.0), (osc(gliss(0.3, 420, 980), "sin") * hann(0.3) * 0.35, 0.02, 1.0), (whoosh(0.3, 500, 1800, 500, 0.3), 0, 0.5))

@snd("w_sniper")
def _():
    body = mix(click(0.03, 2000, 9000, 120), osc(gliss(0.2, 2600, 280), "tri") * dec(0.2, 20.0) * 0.9, (thump(0.12, 200, 60, 22.0), 0, 1.0))
    tail = lp(noise(0.4), 1800) * dec(0.4, 9.0) * 0.35
    return echo(mix(body, tail), 0.11, 0.3, 2, 2500)

for _i in range(2):
    def _mk(i=_i):
        d = 0.2
        f = (236 + 22 * i) * (1 + 0.5 * np.exp(-tt(d) * 60.0)) * (1 + 0.02 * np.sin(2 * np.pi * 55 * tt(d)))
        tw = (osc(f, "tri") + 0.4 * osc(f * 2, "sin")) * dec(d, 22.0)
        return mix(tw, (whoosh(0.16, 1500, 4200, 900, 0.2), 0.01, 0.55), (click(0.012, 1000, 4000, 200), 0, 0.5))
    REG.append(("w_bow_%d" % (_i + 1), _mk, {}))

@snd("w_swarm")
def _():
    parts = []
    for k in range(4):
        f = (220 + 30 * k) * (1 + 0.5 * np.exp(-tt(0.16) * 60.0))
        parts.append((osc(f, "tri") * dec(0.16, 26.0), k * 0.028, 0.6))
        parts.append((whoosh(0.18, 1400 + 300 * k, 4500, 900, 0.2), 0.01 + k * 0.028, 0.4))
    return mix(*parts)

@snd("w_cracker")
def _():
    return mix(thump(0.14, 260, 80, 20.0), (lp(noise(0.1), 1500) * dec(0.1, 28.0), 0, 1.0), (hp(noise(0.3), 4000) * dec(0.3, 9.0) * hann(0.3) ** 0.3, 0.03, 0.3), (osc(gliss(0.2, 500, 1300), "sin") * hann(0.2), 0.02, 0.3))

@snd("w_sparkler")
def _():
    return mix(whoosh(0.3, 700, 3800, 900, 0.3), (osc(gliss(0.26, 600, 1900), "sin") * hann(0.26), 0.0, 0.3), (sparkle(0.3, 3500, 8000, 9), 0.02, 0.35), (thump(0.07, 220, 100, 35.0), 0, 0.6))

@snd("w_cake")
def _():
    return mix(boing(0.3, 330, 0.45, 16.0), (thump(0.1, 190, 75, 26.0), 0, 0.9), (squish(0.08, 1200, 35.0), 0, 0.4), (osc(gliss(0.2, 500, 1000), "sin") * hann(0.2), 0.03, 0.25))

@snd("flame_loop", loop=True)
def _():
    d = 1.2
    n = noise(d + 0.4)
    flut = 0.65 + 0.35 * lp(noise(d + 0.4), 14.0) * 8.0
    x = (bp(n, 180, 1500) * 2.0 + bp(noise(d + 0.4), 1500, 5000) * 0.35) * np.clip(flut, 0.2, 1.6)
    return loopify(x, 0.4)

@snd("water_loop", loop=True)
def _():
    d = 1.2
    flut = 0.75 + 0.25 * lp(noise(d + 0.4), 9.0) * 8.0
    x = (bp(noise(d + 0.4), 1500, 7500) + bp(noise(d + 0.4), 300, 900) * 0.7 * (0.6 + 0.4 * lp(noise(d + 0.4), 30.0) * 6.0)) * np.clip(flut, 0.3, 1.5)
    return loopify(x, 0.4)

# ================================================================== Fähigkeiten
@snd("skill_ready", g=-2)
def _():
    return mix(bell(1319, 0.12, 20.0, 2.0, 0.8), (bell(1976, 0.3, 10.0, 2.0, 0.8), 0.07, 0.9))

@snd("sk_rally", g=1)
def _():
    horn = seq([brass(hz("G4"), 0.12), brass(hz("C5"), 0.12), brass(hz("E5"), 0.12), mix(brass(hz("G5"), 0.5), brass(hz("C5"), 0.5) * 0.6)])
    return mix(horn, (whoosh(0.5, 300, 1500, 400, 0.5), 0.0, 0.3), (thump(0.1, 180, 80, 25.0), 0.36, 0.6))

@snd("sk_roll")
def _():
    return mix(whoosh(0.35, 400, 2400, 600, 0.3), (boing(0.3, 420, 0.3, 11.0), 0.02, 0.5), (click(0.03, 1500, 6000, 100), 0.26, 0.7), (bell(1760, 0.12, 25.0), 0.27, 0.3))

@snd("sk_delivery")
def _():
    fall = osc(gliss(0.4, 1800, 500), "sin") * ar(0.4, 0.05, 0.02) * 0.5
    return mix(fall, (thump(0.2, 150, 50, 14.0), 0.4, 1.2), (lp(noise(0.2), 900) * dec(0.2, 16.0), 0.4, 1.0), (bell(1047, 0.3, 10.0), 0.45, 0.5), (bell(1568, 0.35, 9.0), 0.52, 0.5))

@snd("sk_firewall", g=1)
def _():
    d = 0.9
    roar = bp(noise(d), 150, 1800) * np.interp(np.linspace(0, 1, int(d * SR)), [0, 0.15, 1], [0, 1, 0]) ** 1.3 * 2.0
    return mix(roar, (whoosh(0.5, 300, 2400, 600, 0.3), 0, 0.7), (crackle(0.8, 140.0, 1500.0) * dec(0.8, 4.0), 0.05, 0.3), (thump(0.2, 120, 50, 12.0), 0, 0.8))

@snd("sk_heatshield")
def _():
    hum = (tone(0.6, 220, 330, "tri") + tone(0.6, 331, 496, "sin") * 0.5) * hann(0.6)
    return mix(hum * 0.8, (whoosh(0.5, 400, 2000, 500, 0.6), 0, 0.5), (bell(880, 0.4, 8.0), 0.3, 0.4), (crackle(0.5, 100.0, 2000.0) * hann(0.5), 0.05, 0.2))

@snd("sk_inferno", g=2)
def _():
    return mix((boom(1.8), 0.22, 1.0), osc(gliss(0.25, 300, 1200), "sin") * hann(0.25) * 0.5, whoosh(0.3, 300, 2500, 600, 0.8) * 0.8, (crackle(0.9, 150.0, 1200.0) * dec(0.9, 4.0), 0.25, 0.3))

@snd("sk_shieldup")
def _():
    return mix(bell(392, 0.8, 4.0, 1.4, 3.0), (bell(587, 0.8, 4.0, 1.4, 2.5), 0.0, 0.7), (click(0.03, 800, 4000, 80), 0, 0.8), (thump(0.15, 160, 60, 16.0), 0, 0.9), (whoosh(0.4, 300, 1200, 300, 0.2), 0, 0.4))

@snd("sk_patch")
def _():
    r = rng()
    parts = []
    for k in range(3):
        parts.append((mix(click(0.02, 1200, 5000, 150), thump(0.05, 380, 240, 50.0) * 0.7, bell(1250 + 90 * k, 0.07, 40.0, 1.4, 2.0) * 0.4), k * 0.11, 1.0))
    parts.append((jingle(["E5", "A5", "C#6"], "bell", 0.07, 0.4, 8.0), 0.34, 0.8))
    return mix(*parts)

@snd("sk_berta", g=2)
def _():
    rumble = lp(noise(0.9), 300) * hann(0.9) ** 0.5 * 2.5
    roll = np.zeros(int(0.9 * SR))
    for k in range(7):
        wrap_add(roll, thump(0.12, 110, 50, 18.0) * (0.5 + 0.07 * k), int((0.05 + k * 0.11) * SR))
    return mix(rumble, roll, (whoosh(0.8, 200, 900, 300, 0.7), 0, 0.6), (boom(1.2), 0.75, 0.8))

@snd("sk_turret")
def _():
    servo = osc(gliss(0.25, 300, 700), "sq") * 0.12 * hann(0.25)
    return mix(lp(servo, 2500), (click(0.03, 1500, 6000, 100), 0.25, 0.8), (thump(0.08, 220, 100, 30.0), 0.25, 0.8), (pluck(988, 0.08, 30.0, "sq", 0.0) * 0.4, 0.32, 1.0), (pluck(1319, 0.12, 22.0, "sq", 0.0) * 0.4, 0.4, 1.0))

@snd("sk_overload")
def _():
    d = 0.6
    f = gliss(d, 200, 1600)
    whine = (osc(f, "saw") * 0.3 + osc(f * 1.5, "sin") * 0.4) * np.linspace(0.2, 1, int(d * SR)) ** 1.5
    return mix(lp(whine, 4000), (crackle(d, 300.0, 3000.0) * np.linspace(0, 1, int(d * SR)), 0, 0.2), (bell(1760, 0.4, 8.0, 2.76, 3.0), d - 0.02, 0.9), (click(0.03, 2000, 9000), d - 0.02, 0.6))

@snd("sk_pieps")
def _():
    parts = []
    for k, n in enumerate(["E6", "G6", "E6", "C7", "G6"]):
        f = hz(n)
        parts.append((osc(gliss(0.07, f * 0.9, f * 1.05), "sin") * hann(0.07), k * 0.075, 1.0))
    return mix(*parts, (crackle(0.4, 200.0, 4000.0) * hann(0.4), 0, 0.12))

@snd("sk_kiko")
def _():
    # Falkenruf (freundlich) + Markierungston
    d = 0.35
    f = np.interp(np.linspace(0, 1, int(d * SR)), [0, 0.2, 1], [2400, 3100, 1700])
    cry = (osc(f, "sin") + 0.3 * osc(f * 2, "sin")) * hann(d) ** 0.6
    return mix(cry, (whoosh(0.3, 800, 2500, 600, 0.5), 0.1, 0.4), (bell(1175, 0.3, 10.0), 0.36, 0.6), (bell(880, 0.35, 9.0), 0.44, 0.6))

@snd("sk_smoke")
def _():
    return mix(lp(noise(0.7), 2200) * np.interp(np.linspace(0, 1, int(0.7 * SR)), [0, 0.08, 1], [0, 1, 0]) ** 1.5 * 2.0, (thump(0.1, 200, 90, 26.0), 0, 0.7), (osc(gliss(0.3, 900, 400), "sin") * hann(0.3), 0.02, 0.2))

@snd("sk_flock", g=1)
def _():
    parts = []
    r = rng()
    for k in range(7):
        parts.append((whoosh(0.3, 1200 + 200 * k, 4500, 900, 0.2), k * 0.035, 0.45))
        f = r.uniform(2200, 3400)
        parts.append((osc(gliss(0.08, f, f * 1.25), "sin") * hann(0.08), 0.02 + k * 0.05, 0.25))
    parts.append((osc((230) * (1 + 0.5 * np.exp(-tt(0.25) * 50.0)), "tri") * dec(0.25, 16.0), 0, 0.9))
    return mix(*parts)

@snd("sk_crackers", g=1)
def _():
    r = rng()
    parts = []
    for k in range(9):
        t0 = k * 0.045 + r.uniform(0, 0.02)
        parts.append((mix(click(0.03, 900, 5000, 110), thump(0.05, r.uniform(260, 420), 120, 45.0) * 0.8), t0, r.uniform(0.6, 1.0)))
    parts.append((sparkle(0.5, 3000, 7000, 8), 0.1, 0.3))
    return mix(*parts)

@snd("sk_thermos")
def _():
    pour = np.zeros(int(0.5 * SR))
    for k in range(9):
        wrap_add(pour, bubble(380 + 60 * k, 0.06, 1.8) * 0.6, int((0.02 + k * 0.045) * SR))
    return mix(pour, (bp(noise(0.4), 800, 3000) * hann(0.4) * 0.3, 0, 1.0), (jingle(["C5", "E5", "G5", "C6"], "bell", 0.08, 0.6, 5.0), 0.3, 0.9))

@snd("sk_festival", g=1)
def _():
    whistle = osc(gliss(0.45, 700, 2600) * (1 + 0.02 * np.sin(2 * np.pi * 24 * tt(0.45))), "sin") * ar(0.45, 0.03, 0.05) * 0.5
    return mix(whistle, (whoosh(0.45, 500, 3000, 700, 0.9), 0, 0.4), (boom(0.8), 0.45, 0.9), (sparkle(0.8, 2500, 8000, 22), 0.5, 0.4), (crackle(0.7, 200.0, 3000.0) * dec(0.7, 4.0), 0.5, 0.2))

@snd("sk_airstrike", g=1)
def _():
    d = 1.0
    f = gliss(d, 1500, 420) * (1 + 0.01 * np.sin(2 * np.pi * 18 * tt(d)))
    w = (osc(f, "sin") + 0.2 * osc(f * 2, "sin")) * np.linspace(0.15, 1.0, int(d * SR)) ** 1.5 * ar(d, 0.05, 0.03)
    prop = lp(osc(np.full(int(d * SR), 95.0), "saw"), 500) * (0.6 + 0.4 * np.sin(2 * np.pi * 31 * tt(d))) * hann(d) * 0.5
    return mix(w * 0.7, prop)

@snd("sk_supply")
def _():
    return mix(whoosh(0.3, 1500, 500, 500, 0.6) * 0.5, (thump(0.14, 170, 60, 18.0), 0.28, 1.0), (click(0.03, 900, 3500, 90), 0.28, 0.6), (jingle(["G5", "C6", "E6", "G6"], "bell", 0.07, 0.6, 5.0), 0.36, 0.9), (sparkle(0.4, 3000, 7000, 6), 0.5, 0.25))

@snd("sk_barrier", g=1)
def _():
    d = 1.0
    t = tt(d)
    hum = (np.sin(2 * np.pi * 196 * t) + 0.6 * np.sin(2 * np.pi * 294 * t) + 0.4 * np.sin(2 * np.pi * 392.5 * t)) * (0.8 + 0.2 * np.sin(2 * np.pi * 7 * t)) * ar(d, 0.15, 0.5)
    return mix(hum * 0.6, (whoosh(0.6, 300, 3500, 700, 0.8), 0, 0.5), (bell(784, 0.9, 3.5, 2.0, 2.0), 0.3, 0.6), (bell(1175, 0.9, 3.5), 0.3, 0.5), (sparkle(0.6, 3000, 7000, 8), 0.35, 0.2))

@snd("sk_backup", g=1)
def _():
    whistle = seq([osc(gliss(0.12, 1800, 2400), "sin") * hann(0.12), osc(gliss(0.2, 2400, 1900), "sin") * hann(0.2)]) * 0.6
    steps = np.zeros(int(0.6 * SR))
    for k in range(6):
        wrap_add(steps, mix(thump(0.05, 150, 80, 45.0), click(0.02, 1000, 4000, 150) * 0.5), int((0.02 + k * 0.09) * SR))
    return mix(whistle, (steps, 0.25, 0.9), (seq([brass(hz("C5"), 0.1), brass(hz("G5"), 0.3)]), 0.5, 0.6))

# ================================================================== Türme
for _i in range(3):
    def _mk(i=_i):
        return mix(click(0.02, 1000 + 150 * i, 4500, 170) * 0.8, osc(gliss(0.06, 520 + 30 * i, 170), "tri") * dec(0.06, 48.0), (thump(0.06, 170, 80, 45.0), 0.0, 0.9))
    REG.append(("t_mg_%d" % (_i + 1), _mk, {}))

for _i in range(2):
    def _mk(i=_i):
        return mix(click(0.025, 1300, 5500, 150), osc(gliss(0.08, 880 + 50 * i, 300), "tri") * dec(0.08, 34.0) * 0.8, (thump(0.08, 200, 80, 34.0), 0, 1.0), (bp(noise(0.12), 700, 2500) * dec(0.12, 25.0), 0, 0.4))
    REG.append(("t_aa_%d" % (_i + 1), _mk, {}))

@snd("t_watch")
def _():
    return echo(mix(click(0.03, 1800, 8000, 120), osc(gliss(0.16, 2000, 260), "tri") * dec(0.16, 22.0) * 0.8, (thump(0.12, 180, 60, 22.0), 0, 1.0)), 0.1, 0.28, 2, 2200)

@snd("t_cannon", g=1)
def _():
    return mix(thump(0.3, 150, 42, 11.0) * 1.2, lp(noise(0.3), 900) * dec(0.3, 13.0) * 1.5, (bp(noise(0.06), 800, 4000) * dec(0.06, 50.0), 0, 0.6), (bell(260, 0.3, 12.0, 1.4, 3.0), 0, 0.2))

@snd("t_mortar", g=1)
def _():
    return mix(thump(0.2, 190, 55, 14.0), (lp(noise(0.16), 1300) * dec(0.16, 20.0), 0, 1.2), (reso(noise(0.08), 330, 6.0) * dec(0.08, 30.0), 0, 0.5), (osc(gliss(0.5, 500, 1500), "sin") * hann(0.5) ** 1.5 * 0.25, 0.05, 1.0), (whoosh(0.5, 400, 1600, 400, 0.4), 0.05, 0.3))

for _nm, _hi in (("t_tesla", 1.0), ("t_mini", 1.5)):
    def _mk(hi=_hi):
        r = rng()
        d = 0.2 / hi ** 0.5
        f = gliss(d, 1700 * hi, 380 * hi) * (1.0 + 0.4 * lp(r.uniform(-1, 1, int(d * SR)), 700))
        z = lp(osc(f, "sq"), 4500) * dec(d, 13.0)
        hum = tone(d, 110 * hi, shape="saw") * dec(d, 10.0) * 0.3
        return mix(z * 0.7, lp(hum, 900), (crackle(d, 600.0, 3000.0) * dec(d, 15.0), 0, 0.3))
    REG.append((_nm, _mk, {}))

@snd("t_rocket", g=1)
def _():
    return mix(whoosh(0.5, 400, 3200, 800, 0.25) * 1.2, (thump(0.12, 200, 70, 22.0), 0, 0.9), (lp(noise(0.5), 1200) * dec(0.5, 6.0), 0, 0.9), (osc(gliss(0.4, 400, 1500), "sin") * hann(0.4), 0.02, 0.2))

@snd("t_ice")
def _():
    return mix(thump(0.1, 240, 100, 26.0) * 0.8, (whoosh(0.3, 3000, 1200, 800, 0.2), 0, 0.6), (bell(2093, 0.3, 12.0, 2.76, 2.0), 0, 0.5), (bell(3136, 0.25, 14.0, 2.76, 2.0), 0.03, 0.35), (sparkle(0.25, 4000, 8000, 6), 0.02, 0.3))

@snd("tower_buff")
def _():
    return mix(osc(gliss(0.3, 400, 1200), "tri") * hann(0.3) * 0.6, (bell(1319, 0.3, 10.0), 0.22, 0.7), (bell(1976, 0.35, 9.0), 0.28, 0.6), (whoosh(0.3, 500, 2500, 500, 0.8), 0, 0.3))

@snd("tower_spawn")
def _():
    return mix(thump(0.14, 170, 60, 18.0), (click(0.03, 1000, 4500, 100), 0, 0.7), (lp(noise(0.15), 1000) * dec(0.15, 20.0), 0, 0.8), (click(0.02, 2000, 7000, 150), 0.12, 0.5), (bell(1175, 0.15, 20.0), 0.12, 0.3))

# ================================================================== Einschläge
for _i in range(2):
    REG.append(("explosion_small_%d" % (_i + 1), (lambda i=_i: boom(0.55 + 0.15 * i)), {"g": 1}))

@snd("explosion_big", g=3)
def _():
    return boom(1.5)

@snd("ice_shatter", g=1)
def _():
    r = rng()
    parts = [thump(0.12, 180, 70, 22.0) * 0.7, bp(noise(0.25), 2500, 9000) * dec(0.25, 14.0) * 0.8]
    for k in range(10):
        parts.append((bell(r.uniform(2200, 6000), 0.12, 30.0, 2.76, 2.0), r.uniform(0, 0.22), r.uniform(0.2, 0.5)))
    return mix(*parts)

@snd("splash")
def _():
    drops = np.zeros(int(0.35 * SR))
    r = rng()
    for k in range(7):
        wrap_add(drops, bubble(r.uniform(500, 1100), 0.05, 1.6) * 0.4, int(r.uniform(0.08, 0.3) * SR))
    return mix(bp(noise(0.3), 700, 5000) * np.interp(np.linspace(0, 1, int(0.3 * SR)), [0, 0.1, 1], [0, 1, 0]) ** 2 * 1.5, (thump(0.1, 160, 70, 24.0), 0, 0.7), drops)

@snd("glue_splat")
def _():
    return mix(squish(0.3, 700, 10.0) * 1.2, (blub(0.22, 240, 90), 0.0, 0.9), (bubble(300, 0.07, 1.8), 0.16, 0.5), (bubble(420, 0.06, 1.8), 0.24, 0.4), (thump(0.1, 140, 60, 22.0), 0, 0.7))

@snd("cake_splat")
def _():
    return mix(squish(0.2, 1500, 16.0), (thump(0.1, 180, 70, 24.0), 0, 0.9), (boing(0.25, 520, 0.3, 18.0), 0.02, 0.4), (bell(1568, 0.2, 14.0), 0.05, 0.3), (bell(2093, 0.25, 12.0), 0.11, 0.3))

@snd("fire_whoosh")
def _():
    return mix(bp(noise(0.5), 150, 1600) * np.interp(np.linspace(0, 1, int(0.5 * SR)), [0, 0.12, 1], [0, 1, 0]) ** 1.5 * 2.0, (thump(0.14, 150, 55, 16.0), 0, 0.8), (crackle(0.45, 140.0, 1500.0) * dec(0.45, 6.0), 0.03, 0.25))

@snd("thunder", g=1)
def _():
    d = 0.9
    r = lp(noise(d), 350) * dec(d, 3.5) * (0.7 + 0.3 * lp(noise(d), 12.0) * 6.0) * 3.0
    return mix(r, (crackle(0.15, 500.0, 2500.0) * dec(0.15, 18.0), 0, 0.4), (thump(0.3, 90, 40, 9.0), 0.02, 1.0))

@snd("whoosh", g=-2)
def _():
    return whoosh(0.28, 500, 1700, 450, 0.45)

@snd("rocket_fly", g=-2)
def _():
    return mix(whoosh(0.4, 900, 3000, 800, 0.3), osc(gliss(0.35, 700, 1700), "sin") * hann(0.35) * 0.15)

@snd("heal")
def _():
    return mix(jingle(["E5", "G#5", "B5", "E6"], "bell", 0.075, 0.55, 5.0), (osc(gliss(0.4, 500, 1000), "sin") * hann(0.4) * 0.2, 0, 1.0), (sparkle(0.4, 3500, 7000, 6), 0.2, 0.2))

@snd("zone_heal", g=-2)
def _():
    return mix(bell(1319, 0.3, 9.0, 2.0, 0.8), (bell(1661, 0.35, 8.0, 2.0, 0.8), 0.1, 0.8))

# ================================================================== Schleimlinge
for _i in range(3):
    REG.append(("slime_hop_%d" % (_i + 1), (lambda i=_i: mix(blub(0.09, 210 + 40 * i, 120 + 20 * i) * 0.8, squish(0.07, 900 + 200 * i, 40.0) * 0.6)), {"g": -4}))

for _i in range(3):
    REG.append(("slime_hit_%d" % (_i + 1), (lambda i=_i: mix(squish(0.06, 1400 + 300 * i, 50.0), blub(0.07, 340 + 50 * i, 190) * 0.7, thump(0.04, 200, 110, 60.0) * 0.5)), {"g": -2}))

for _i in range(3):
    def _mk(i=_i):
        f = 420 + 70 * i
        return mix(osc(gliss(0.045, f, f * 2.6), "sin") * dec(0.045, 30.0) * ar(0.045, 0.001, 0.01), (click(0.015, 1200, 6000, 220), 0.0, 0.7), (squish(0.1, 1300, 30.0), 0.02, 0.6), (bubble(700 + 90 * i, 0.05, 1.7), 0.05, 0.3))
    REG.append(("pop_small_%d" % (_i + 1), _mk, {}))

for _i in range(2):
    def _mk(i=_i):
        f = 190 + 30 * i
        return mix(osc(gliss(0.08, f, f * 2.4), "sin") * dec(0.08, 16.0), (thump(0.14, 150, 55, 18.0), 0, 1.0), (squish(0.3, 800, 10.0), 0.03, 1.0), (bubble(330, 0.07, 1.8), 0.1, 0.5), (bubble(450, 0.06, 1.8), 0.17, 0.4), (bubble(390, 0.06, 1.8), 0.24, 0.3))
    REG.append(("pop_big_%d" % (_i + 1), _mk, {"g": 2}))

@snd("pop_boss", g=4)
def _():
    d = 0.8
    f = gliss(d, 300, 70) * (1 + 0.15 * np.sin(2 * np.pi * 21 * tt(d)))
    defl = reso(osc(f, "saw"), 600, 2.5) * 0.4 * ar(d, 0.01, 0.4) + bp(noise(d), 300, 2500) * ar(d, 0.01, 0.5) * 0.8
    bubs = np.zeros(int(0.9 * SR))
    r = rng()
    for k in range(14):
        wrap_add(bubs, bubble(r.uniform(250, 700), 0.07, 1.8) * 0.4, int(r.uniform(0.1, 0.8) * SR))
    return mix(osc(gliss(0.1, 140, 360), "sin") * dec(0.1, 12.0), thump(0.3, 120, 40, 9.0), (defl, 0.06, 1.0), (squish(0.5, 700, 6.0), 0.05, 1.0), (bubs, 0.1, 1.0))

for _i in range(2):
    REG.append(("spit_%d" % (_i + 1), (lambda i=_i: mix(osc(gliss(0.1, 300 + 40 * i, 780), "sin") * hann(0.1) * 0.8, (squish(0.1, 1600, 28.0), 0.03, 0.9), (click(0.015, 1000, 4000, 200), 0.09, 0.6), (whoosh(0.15, 600, 1500, 400, 0.3), 0.08, 0.4))), {}))

@snd("spit_land")
def _():
    return mix(squish(0.16, 1100, 18.0), (thump(0.07, 170, 80, 32.0), 0, 0.6), (bubble(520, 0.05, 1.7), 0.06, 0.4))

@snd("fuse", g=-1)
def _():
    d = 0.7
    hiss = hp(noise(d), 3500) * (0.6 + 0.4 * lp(noise(d), 40.0) * 5.0) * ar(d, 0.02, 0.05) * 0.6
    beeps = np.zeros(int(d * SR))
    for k, t0 in enumerate([0.0, 0.22, 0.4, 0.53, 0.62]):
        wrap_add(beeps, osc(np.full(int(0.05 * SR), 1300.0 + 90 * k), "sin") * hann(0.05) * 0.6, int(t0 * SR))
    return mix(hiss, beeps)

@snd("barrel_boom", g=2)
def _():
    return mix(boom(0.9), (squish(0.3, 900, 9.0), 0.02, 0.6), (bubble(400, 0.07, 1.8), 0.15, 0.3))

for _i in range(2):
    REG.append(("shield_clank_%d" % (_i + 1), (lambda i=_i: mix(bell(820 + 140 * i, 0.22, 16.0, 1.41, 3.5), (bell(1740 + 200 * i, 0.15, 22.0, 2.76, 2.0), 0, 0.5), (click(0.015, 1500, 6000, 200), 0, 0.7))), {"g": -1}))

@snd("shaman_heal", g=-1)
def _():
    return mix(bell(659, 0.5, 5.0, 2.0, 1.5), (bell(988, 0.5, 5.0, 2.0, 1.2), 0.08, 0.8), (bell(1319, 0.5, 5.0, 2.0, 1.0), 0.16, 0.6), (blub(0.2, 200, 300) * 0.3, 0, 1.0))

@snd("boss_arrive", g=3)
def _():
    steps = mix(thump(0.3, 80, 35, 9.0), (thump(0.3, 75, 33, 9.0), 0.42, 1.0), (thump(0.35, 70, 30, 8.0), 0.84, 1.1))
    horn = mix(brass(hz("C3"), 0.9, 0.12), brass(hz("G3"), 0.9, 0.12) * 0.7, brass(hz("Eb3"), 0.9, 0.12) * 0.5)
    return mix(steps, (horn, 0.25, 0.5), (lp(noise(1.2), 300) * hann(1.2), 0, 1.0), (squish(0.2, 600, 12.0), 0.84, 0.5))

@snd("boss_roar", g=3)
def _():
    d = 0.95
    t = tt(d)
    f = np.interp(t / d, [0, 0.25, 0.7, 1], [95, 150, 120, 70]) * (1 + 0.03 * np.sin(2 * np.pi * 27 * t))
    src = osc(f, "saw") * (0.75 + 0.25 * np.sin(2 * np.pi * 23 * t))
    voc = reso(src, 650, 3.0) + reso(src, 1050, 4.0) * 0.6 + lp(src, 300) * 0.5
    bubs = np.zeros(len(t))
    r = rng()
    for k in range(8):
        wrap_add(bubs, bubble(r.uniform(260, 600), 0.07, 1.8) * 0.5, int(r.uniform(0.1, 0.8) * SR))
    return mix(voc * ar(d, 0.08, 0.3), bubs * 0.5, bp(noise(d), 400, 2000) * ar(d, 0.1, 0.4) * 0.4)

@snd("boss_slam", g=3)
def _():
    return mix(thump(0.5, 110, 30, 7.0) * 1.3, lp(noise(0.5), 500) * dec(0.5, 7.0) * 2.0, (squish(0.3, 900, 10.0), 0.02, 0.7), (crackle(0.4, 80.0, 800.0) * dec(0.4, 7.0), 0.05, 0.3))

@snd("boss_summon", g=1)
def _():
    parts = [blub(0.4, 130, 260, 0.08, 14.0) * 0.9, (squish(0.3, 800, 9.0), 0.05, 0.6)]
    for k in range(5):
        parts.append((osc(gliss(0.05, 400 + 60 * k, 1100 + 100 * k), "sin") * dec(0.05, 28.0), 0.3 + k * 0.07, 0.6))
        parts.append((squish(0.05, 1500, 45.0), 0.31 + k * 0.07, 0.4))
    return mix(*parts)

@snd("boss_defeat", g=3)
def _():
    fan = jingle(["C5", "E5", "G5", ("C6", "E6", "G5")], "brass", 0.14, 0.9)
    return mix(fan, (jingle(["C6", "E6", "G6", "C7"], "bell", 0.14, 0.9, 3.5), 0.0, 0.5), (sparkle(1.0, 3000, 8000, 20), 0.4, 0.25), (thump(0.3, 110, 40, 9.0), 0.42, 0.7))

# ================================================================== Münzen, Rohstoffe
for _i in range(3):
    def _mk(i=_i):
        f = [1568, 1760, 1976][i]
        return mix(bell(f, 0.07, 36.0, 2.76, 1.6), (bell(f * 1.5, 0.22, 15.0, 2.76, 1.2), 0.045, 0.9), (click(0.01, 3000, 9000, 250), 0, 0.3))
    REG.append(("coin_%d" % (_i + 1), _mk, {"g": -2}))

for _i in range(2):
    REG.append(("coin_drop_%d" % (_i + 1), (lambda i=_i: mix(bell(1900 + 250 * i, 0.06, 45.0, 2.0, 0.8), (bell(2300 + 250 * i, 0.05, 50.0, 2.0, 0.8), 0.07, 0.6), (bell(2100 + 250 * i, 0.05, 55.0, 2.0, 0.8), 0.12, 0.35))), {"g": -5}))

@snd("pickup")
def _():
    return mix(osc(gliss(0.08, 700, 1500), "sin") * hann(0.08), (bell(1760, 0.2, 14.0), 0.05, 0.7))

@snd("res_coins")
def _():
    return mix(bell(1568, 0.07, 36.0, 2.76, 1.6), (bell(2093, 0.07, 36.0, 2.76, 1.6), 0.05, 0.9), (bell(2637, 0.25, 13.0, 2.76, 1.2), 0.1, 0.9))

@snd("res_wood")
def _():
    k = lambda f: mix(reso(noise(0.06), f, 8.0) * dec(0.06, 45.0) * 2.0, thump(0.05, f * 0.5, f * 0.35, 50.0), click(0.01, 1000, 4000, 250) * 0.5)
    return mix(k(520), (k(660), 0.09, 0.9))

@snd("res_stone")
def _():
    k = lambda f: mix(bp(noise(0.05), 1500, 5000) * dec(0.05, 60.0), thump(0.06, f, f * 0.5, 45.0), bell(f * 6, 0.05, 60.0, 1.41, 3.0) * 0.3)
    return mix(k(170), (k(140), 0.1, 0.9), (crackle(0.15, 150.0, 1500.0) * dec(0.15, 20.0), 0.1, 0.3))

@snd("res_metal")
def _():
    return mix(bell(740, 0.3, 11.0, 1.41, 4.0), (click(0.015, 2000, 8000, 200), 0, 0.6), (bell(1110, 0.25, 13.0, 2.76, 3.0), 0.09, 0.7), (click(0.015, 2000, 8000, 200), 0.09, 0.4))

@snd("res_fuel")
def _():
    g = np.zeros(int(0.3 * SR))
    for k in range(5):
        wrap_add(g, blub(0.07, 190 + 25 * k, 300 + 30 * k) * 0.8, int((0.01 + k * 0.055) * SR))
    return mix(g, (bubble(600, 0.06, 1.7), 0.26, 0.5))

@snd("res_cells")
def _():
    return mix(osc(gliss(0.14, 500, 1500), "sq") * hann(0.14) * 0.3, (osc(gliss(0.14, 1000, 3000), "sin") * hann(0.14), 0, 0.5), (bell(1976, 0.2, 14.0), 0.12, 0.7), (crackle(0.12, 300.0, 4000.0) * hann(0.12), 0, 0.15))

@snd("res_parts")
def _():
    r = rng()
    parts = []
    for k in range(4):
        parts.append((mix(click(0.012, 2500, 9000, 250), bell(r.uniform(1800, 3200), 0.06, 45.0, 1.41, 2.5) * 0.6), k * 0.045, 1.0 - 0.15 * k))
    parts.append((thump(0.05, 300, 180, 50.0), 0, 0.5))
    return mix(*parts)

@snd("res_shards")
def _():
    return mix(bell(2093, 0.4, 7.0, 2.76, 1.5), (bell(2637, 0.4, 7.0, 2.76, 1.5), 0.06, 0.8), (bell(3136, 0.45, 6.0, 2.76, 1.5), 0.12, 0.7), (sparkle(0.35, 4000, 8500, 7), 0.05, 0.3))

@snd("backpack_full")
def _():
    return mix(lp(noise(0.12), 900) * dec(0.12, 22.0), thump(0.12, 160, 70, 20.0), (pluck(392, 0.12, 18.0, "sq", 0.0) * 0.5, 0.1, 1.0), (pluck(311, 0.2, 12.0, "sq", 0.0) * 0.5, 0.22, 1.0))

# ================================================================== Bauen, Gebäude
@snd("build")
def _():
    return mix(thump(0.14, 170, 60, 18.0), (reso(noise(0.06), 480, 7.0) * dec(0.06, 40.0) * 1.5, 0, 1.0), (lp(noise(0.18), 900) * dec(0.18, 18.0), 0, 0.8), (bell(1047, 0.25, 12.0), 0.08, 0.4))

@snd("build_place")
def _():
    return mix(thump(0.16, 150, 55, 16.0), (reso(noise(0.06), 440, 7.0) * dec(0.06, 40.0) * 1.5, 0, 1.0), (lp(noise(0.2), 800) * dec(0.2, 16.0), 0, 0.9), (click(0.02, 1500, 5000, 150), 0.1, 0.4), (click(0.02, 1800, 6000, 150), 0.17, 0.3))

@snd("build_done", g=1)
def _():
    ham = lambda f: mix(click(0.02, 1200, 5000, 150), reso(noise(0.05), f, 8.0) * dec(0.05, 50.0) * 1.5)
    return mix(ham(600), (ham(700), 0.1, 1.0), (jingle(["C5", "E5", "G5", ("C6", "E6")], "bell", 0.08, 0.7, 4.5), 0.2, 1.0), (sparkle(0.5, 3000, 7000, 8), 0.45, 0.25))

@snd("upgrade", g=1)
def _():
    return mix(jingle(["G4", "C5", "E5", "G5", ("C6", "G5")], "pluck", 0.075, 0.7, 4.0), (jingle(["G5", "C6", "E6", "G6", "C7"], "bell", 0.075, 0.7, 4.5), 0, 0.5), (whoosh(0.4, 300, 2500, 500, 0.8), 0, 0.3), (sparkle(0.6, 3000, 8000, 10), 0.35, 0.25))

@snd("upgrade_done", g=1)
def _():
    return mix(whoosh(0.35, 300, 3000, 600, 0.85) * 0.5, (jingle(["E5", "G5", "C6", ("E6", "G6")], "bell", 0.08, 0.8, 4.0), 0.15, 1.0), (brass(hz("C5"), 0.5) * 0.3, 0.39, 1.0), (sparkle(0.6, 3000, 8000, 12), 0.4, 0.25))

@snd("upgrade_start")
def _():
    ham = lambda f: mix(click(0.02, 1200, 5000, 150), reso(noise(0.05), f, 8.0) * dec(0.05, 50.0) * 1.5, thump(0.05, 200, 110, 50.0) * 0.5)
    return mix(ham(560), (ham(640), 0.12, 0.9), (ham(720), 0.24, 0.8), (osc(gliss(0.2, 300, 700), "sq") * hann(0.2) * 0.1, 0.3, 1.0))

@snd("build_move")
def _():
    return mix(whoosh(0.2, 400, 1400, 400, 0.5), (thump(0.12, 160, 65, 20.0), 0.16, 1.0), (lp(noise(0.12), 900) * dec(0.12, 24.0), 0.16, 0.8))

@snd("build_remove")
def _():
    r = rng()
    parts = [thump(0.12, 190, 70, 20.0), lp(noise(0.25), 1200) * dec(0.25, 12.0)]
    for k in range(4):
        parts.append((reso(noise(0.05), r.uniform(350, 700), 7.0) * dec(0.05, 45.0) * 1.2, 0.04 + k * 0.05, 0.7))
    parts.append((bell(1568, 0.1, 30.0), 0.2, 0.3))
    parts.append((bell(2093, 0.2, 16.0), 0.26, 0.3))
    return mix(*parts)

def _wall_hit(kind, i):
    if kind == "wood":
        return mix(reso(noise(0.07), 380 + 60 * i, 6.0) * dec(0.07, 40.0) * 2.0, thump(0.07, 190, 90, 36.0), click(0.015, 1000, 4000, 200) * 0.6)
    if kind == "stone":
        return mix(bp(noise(0.06), 1200, 5000) * dec(0.06, 55.0), thump(0.08, 140 + 20 * i, 60, 32.0) * 1.2, (crackle(0.1, 150.0, 1500.0) * dec(0.1, 25.0), 0.02, 0.3))
    return mix(bell(430 + 70 * i, 0.25, 14.0, 1.41, 4.0), thump(0.07, 170, 80, 36.0) * 0.8, click(0.015, 2000, 8000, 200) * 0.6)

def _wall_break(kind):
    r = rng()
    parts = [thump(0.25, 130, 45, 11.0), lp(noise(0.4), 900) * dec(0.4, 9.0) * 1.3]
    for k in range(7):
        t0 = 0.02 + r.uniform(0, 0.3)
        if kind == "wood":
            parts.append((reso(noise(0.06), r.uniform(300, 800), 7.0) * dec(0.06, 40.0) * 1.5, t0, 0.6))
        elif kind == "stone":
            parts.append((mix(bp(noise(0.05), 1000, 4500) * dec(0.05, 50.0), thump(0.06, r.uniform(110, 190), 60, 40.0)), t0, 0.6))
        else:
            parts.append((bell(r.uniform(350, 1100), 0.2, 16.0, 1.41, 4.0), t0, 0.4))
    return mix(*parts)

for _k in ("wood", "stone", "metal"):
    for _i in range(2):
        REG.append(("wall_hit_%s_%d" % (_k, _i + 1), (lambda k=_k, i=_i: _wall_hit(k, i)), {"g": -2}))
    REG.append(("wall_break_%s" % _k, (lambda k=_k: _wall_break(k)), {"g": 1}))

for _i in range(2):
    REG.append(("struct_hit_%d" % (_i + 1), (lambda i=_i: mix(thump(0.09, 150 + 25 * i, 65, 28.0) * 1.2, lp(noise(0.08), 1400) * dec(0.08, 35.0), bell(520 + 80 * i, 0.1, 30.0, 1.41, 3.0) * 0.25, click(0.015, 1200, 5000, 200) * 0.5)), {"g": -1}))

@snd("struct_destroy", g=3)
def _():
    return mix(boom(1.1), (_wall_break("stone"), 0.05, 0.6), (_wall_break("wood"), 0.15, 0.4))

@snd("repair")
def _():
    ham = lambda f: mix(click(0.02, 1200, 5000, 150), reso(noise(0.05), f, 8.0) * dec(0.05, 50.0) * 1.5, bell(f * 3, 0.06, 40.0, 1.41, 2.0) * 0.3)
    return mix(ham(520), (ham(620), 0.1, 0.9), (osc(gliss(0.2, 600, 1300), "sin") * hann(0.2) * 0.3, 0.18, 1.0), (bell(1568, 0.25, 12.0), 0.3, 0.5))

@snd("trap_spike", g=-1)
def _():
    return mix(osc(gliss(0.05, 900, 2600), "saw") * dec(0.05, 40.0) * 0.3, click(0.02, 2500, 9000, 180), (bell(2200, 0.12, 28.0, 1.41, 3.0), 0.01, 0.6), (thump(0.05, 220, 120, 50.0), 0, 0.5))

@snd("glue_step", g=-3)
def _():
    return mix(squish(0.14, 900, 18.0), (blub(0.1, 260, 170) * 0.6, 0.02, 1.0), (bubble(480, 0.05, 1.6), 0.1, 0.4))

@snd("mine_beep")
def _():
    b = lambda f: osc(np.full(int(0.06 * SR), f), "sin") * hann(0.06) ** 0.5
    return mix(b(1480.0), (b(1480.0), 0.1, 1.0), (b(1976.0), 0.2, 1.0))

@snd("shield_hum", g=1)
def _():
    d = 1.4
    t = tt(d)
    f = np.interp(t / d, [0, 0.5, 1], [80, 196, 196])
    hum = (osc(f, "sin") + 0.5 * osc(f * 1.5, "sin") + 0.3 * osc(f * 2.01, "tri")) * (0.85 + 0.15 * np.sin(2 * np.pi * 8 * t)) * ar(d, 0.2, 0.6)
    return mix(hum, (whoosh(0.7, 300, 3000, 600, 0.9), 0, 0.4), (bell(1175, 0.8, 4.0, 2.0, 1.5), 0.65, 0.5), (bell(1568, 0.8, 4.0), 0.65, 0.4))

# ================================================================== Flut, Wellen, Ergebnis
@snd("flood_horn", g=3)
def _():
    def horn(f, d):
        t = tt(d)
        x = osc(f * (1 + 0.003 * np.sin(2 * np.pi * 5 * t)), "saw")
        return lp(x, 1100) * ar(d, 0.12, 0.35)
    a = mix(horn(hz("C3"), 1.0), horn(hz("G3"), 1.0) * 0.8, horn(hz("C4"), 1.0) * 0.5)
    b = mix(horn(hz("C3"), 1.4), horn(hz("G3"), 1.4) * 0.8, horn(hz("E4"), 1.4) * 0.5)
    return echo(mix(a, (b, 0.85, 1.0), (lp(noise(2.2), 250) * hann(2.2) * 1.5, 0, 0.6)), 0.19, 0.3, 2, 1500)

@snd("wave", g=2)
def _():
    return mix(seq([brass(hz("G3"), 0.22, 0.04), mix(brass(hz("C4"), 0.6, 0.04), brass(hz("G4"), 0.6, 0.04) * 0.6)]), (thump(0.2, 100, 45, 12.0), 0.22, 0.8), (thump(0.15, 110, 50, 14.0), 0.0, 0.6))

@snd("wave_clear", g=1)
def _():
    return mix(jingle(["G5", "C6", "E6", ("G6", "C6")], "bell", 0.085, 0.8, 4.0), (jingle(["G4", "C5", "E5", "G5"], "pluck", 0.085, 0.6, 5.0), 0, 0.6), (sparkle(0.5, 3000, 7000, 8), 0.3, 0.2))

@snd("win", g=3)
def _():
    fan = seq([brass(hz("C5"), 0.16), brass(hz("C5"), 0.1), brass(hz("C5"), 0.1), brass(hz("E5"), 0.2), brass(hz("G5"), 0.2), brass(hz("E5"), 0.14)])
    end = mix(brass(hz("C6"), 1.3), brass(hz("G5"), 1.3) * 0.75, brass(hz("E5"), 1.3) * 0.75, brass(hz("C4"), 1.3) * 0.7, brass(hz("C3"), 1.3) * 0.5)
    low = seq([brass(hz("C4"), 0.36), brass(hz("G3"), 0.34), brass(hz("C4"), 0.2)]) * 0.5
    drum = mix(thump(0.2, 110, 45, 12.0), (thump(0.2, 110, 45, 12.0), 0.36, 1.0), (thump(0.2, 110, 45, 12.0), 0.7, 0.8), (thump(0.4, 100, 40, 7.0), 0.9, 1.2))
    return mix(fan, low, (end, 0.9, 0.9), (drum, 0, 0.6), (jingle(["C6", "E6", "G6", "C7"], "bell", 0.1, 1.2, 2.5), 0.9, 0.5), (sparkle(1.4, 3000, 8500, 26), 0.9, 0.22), (bp(noise(0.5), 3000, 9000) * dec(0.5, 6.0), 0.9, 0.15))

@snd("lose", g=2)
def _():
    def wah(n, d):
        f = hz(n)
        t = tt(d)
        x = osc(gliss(d, f, f * 0.94) * (1 + 0.012 * np.sin(2 * np.pi * 5 * t)), "saw")
        return lp(x, 900) * ar(d, 0.04, 0.12)
    mel = seq([wah("G4", 0.32), wah("F4", 0.32), wah("Eb4", 0.32), wah("C4", 1.0)])
    low = seq([np.zeros(int(0.96 * SR)), mix(wah("C3", 1.0), wah("G3", 1.0) * 0.6)]) * 0.6
    return mix(mel, low, (thump(0.3, 90, 40, 8.0), 0.96, 0.8))

@snd("practice_done", g=1)
def _():
    return mix(jingle(["E5", "G5", "C6", "G5", ("C6", "E6")], "pluck", 0.1, 0.7, 4.0), (jingle(["E6", "G6", "C7"], "bell", 0.1, 0.7, 4.0), 0.2, 0.4), (brass(hz("C4"), 0.5) * 0.4, 0.4, 1.0))

@snd("flood_alarm", g=1)
def _():
    def two(f1, f2):
        return seq([lp(osc(np.full(int(0.16 * SR), f1), "sq"), 2500) * hann(0.16) ** 0.3, lp(osc(np.full(int(0.16 * SR), f2), "sq"), 2500) * hann(0.16) ** 0.3])
    al = seq([two(659.0, 523.0), two(659.0, 523.0), two(659.0, 523.0)]) * 0.5
    return mix(al, (bell(1047, 0.8, 4.0, 2.0, 2.0), 0.96, 0.9), (bell(784, 0.8, 4.0, 2.0, 2.0), 0.96, 0.7))

# ================================================================== Expedition
@snd("chest_found", g=1)
def _():
    return mix(thump(0.1, 200, 90, 24.0), (click(0.03, 1200, 5000, 100), 0, 0.6), (jingle(["D5", "G5", "B5", "D6", "G6"], "bell", 0.065, 0.7, 4.5), 0.05, 1.0), (sparkle(0.6, 3200, 7500, 10), 0.25, 0.3))

@snd("nest_destroyed", g=3)
def _():
    bubs = np.zeros(int(0.7 * SR))
    r = rng()
    for k in range(12):
        wrap_add(bubs, bubble(r.uniform(280, 800), 0.07, 1.8) * 0.4, int(r.uniform(0.05, 0.6) * SR))
    return mix(boom(1.0), (squish(0.5, 800, 6.0), 0.03, 0.9), (bubs, 0.1, 1.0), (jingle(["G5", "C6", "E6"], "bell", 0.08, 0.5, 6.0), 0.5, 0.5))

@snd("cage_rattle", g=-1)
def _():
    r = rng()
    parts = []
    for k in range(5):
        parts.append((mix(bell(r.uniform(700, 1500), 0.08, 35.0, 1.41, 4.0), click(0.012, 2000, 8000, 250) * 0.6), k * 0.06 + r.uniform(0, 0.02), r.uniform(0.5, 1.0)))
    return mix(*parts)

@snd("cage_open", g=1)
def _():
    creak = reso(osc(gliss(0.3, 220, 480) * (1 + 0.06 * np.sin(2 * np.pi * 41 * tt(0.3))), "saw"), 1300, 5.0) * hann(0.3) * 0.4
    return mix(bell(880, 0.3, 12.0, 1.41, 4.0), (click(0.03, 1500, 7000, 100), 0, 0.8), (creak, 0.08, 1.0), (thump(0.12, 160, 60, 20.0), 0.38, 0.8))

@snd("rescue_cheer", g=2)
def _():
    def yay(f0, d):
        t = tt(d)
        f = np.interp(t / d, [0, 0.3, 1], [f0, f0 * 1.5, f0 * 1.25]) * (1 + 0.02 * np.sin(2 * np.pi * 7 * t))
        src = osc(f, "saw")
        return (reso(src, 900, 3.0) + reso(src, 1400, 4.0) * 0.6 + lp(src, 500) * 0.3) * ar(d, 0.04, 0.2)
    return mix(yay(330, 0.5), (yay(415, 0.45), 0.05, 0.7), (jingle(["C5", "E5", "G5", ("C6", "E6")], "bell", 0.08, 0.8, 4.0), 0.3, 0.9), (sparkle(0.6, 3000, 8000, 10), 0.5, 0.25))

@snd("gate_pass")
def _():
    return mix(whoosh(0.2, 600, 2500, 600, 0.4) * 0.6, (bell(1047, 0.1, 25.0), 0.02, 0.9), (bell(1568, 0.35, 9.0), 0.09, 0.9), (sparkle(0.25, 3500, 7000, 5), 0.1, 0.25))

@snd("race_beep", g=-1)
def _():
    return lp(osc(np.full(int(0.09 * SR), 880.0), "sq"), 3000) * ar(0.09, 0.003, 0.03)

@snd("race_beep_last")
def _():
    return lp(osc(np.full(int(0.35 * SR), 1318.5), "sq"), 3500) * ar(0.35, 0.003, 0.2)

@snd("pad_build", g=1)
def _():
    return mix(bell(1568, 0.08, 34.0, 2.76, 1.6), (bell(2093, 0.1, 30.0, 2.76, 1.6), 0.05, 0.8), (thump(0.14, 170, 60, 18.0), 0.12, 1.0), (click(0.03, 1000, 4500, 100), 0.12, 0.7), (osc(gliss(0.2, 300, 800), "sq") * hann(0.2) * 0.12, 0.14, 1.0), (jingle(["C5", "G5", "C6"], "bell", 0.07, 0.4, 7.0), 0.3, 0.8))

@snd("extract_loop", loop=True, g=-2)
def _():
    d = 1.0                       # alle Frequenzen ganzzahlig -> nahtlos
    t = tt(d)
    x = (np.sin(2 * np.pi * 220 * t) + 0.5 * np.sin(2 * np.pi * 330 * t) + 0.3 * np.sin(2 * np.pi * 440 * t)) * (0.7 + 0.3 * np.sin(2 * np.pi * 8 * t))
    return x + 0.2 * np.sin(2 * np.pi * 880 * t) * (0.5 + 0.5 * np.sin(2 * np.pi * 4 * t))

@snd("extract_success", g=2)
def _():
    return mix(whoosh(0.6, 300, 4000, 700, 0.9) * 0.7, (osc(gliss(0.5, 300, 1800), "sin") * hann(0.5) * 0.4, 0, 1.0), (jingle(["C5", "G5", "C6", "E6", "G6"], "bell", 0.07, 0.8, 4.0), 0.4, 1.0), (sparkle(0.7, 3000, 8000, 14), 0.5, 0.25))

@snd("outpost_alarm", g=2)
def _():
    s = lp(osc(np.interp(tt(1.2) / 1.2, [0, 0.25, 0.5, 0.75, 1], [520, 780, 520, 780, 520]), "tri"), 2500) * ar(1.2, 0.05, 0.2)
    return mix(s, (brass(hz("G3"), 0.5, 0.05) * 0.5, 0.0, 1.0))

# ================================================================== Fahrzeuge
def _engine(base, rough, kind):
    d = 0.5
    t = tt(d)
    f0 = base                                   # Vielfache von 2 Hz -> nahtlos
    x = np.zeros(len(t))
    for h, a in enumerate([1.0, 0.55, 0.4, 0.22, 0.15, 0.08], start=1):
        x += a * np.sin(2 * np.pi * f0 * h * t + h * 0.7)
    putt = 0.55 + 0.45 * np.sign(np.sin(2 * np.pi * (f0 / 2) * t)) * np.abs(np.sin(2 * np.pi * (f0 / 2) * t)) ** 0.5
    x = x * (1 - rough + rough * putt)
    n = loopify(lp(noise(d + 0.1), 1800 if kind != "hover" else 3500), 0.1)
    if kind == "hover":
        fan = n * (0.7 + 0.3 * np.sin(2 * np.pi * 24 * t)) * 2.5
        return 0.35 * lp(x, 600) + fan
    return lp(x, 1400) + 0.25 * n * putt

for _nm, _b, _r in (("quad", 84.0, 0.7), ("bike", 64.0, 0.9), ("buggy", 96.0, 0.6), ("pickup", 52.0, 0.5), ("hover", 112.0, 0.2)):
    REG.append(("engine_%s" % _nm, (lambda b=_b, r=_r, k=_nm: _engine(b, r, k)), {"loop": True, "g": -2}))

@snd("veh_mount")
def _():
    d = 0.5
    f = gliss(d, 40, 130)
    rev = lp(osc(f, "saw") * (0.6 + 0.4 * np.sin(np.cumsum(f) / SR * np.pi)), 1200) * ar(d, 0.02, 0.2)
    return mix(click(0.03, 1000, 4000, 100), (thump(0.08, 200, 90, 30.0), 0, 0.8), (rev, 0.06, 1.0))

@snd("veh_dismount")
def _():
    d = 0.35
    f = gliss(d, 110, 40)
    rev = lp(osc(f, "saw"), 900) * ar(d, 0.01, 0.2)
    return mix(rev, (click(0.03, 900, 3500, 100), 0.3, 0.9), (thump(0.08, 180, 80, 30.0), 0.3, 0.8))

@snd("veh_broken", g=2)
def _():
    d = 0.6
    f = gliss(d, 120, 30) * (1 + 0.2 * np.sign(np.sin(2 * np.pi * 11 * tt(d))))
    sput = lp(osc(f, "saw"), 800) * ar(d, 0.01, 0.3)
    return mix(boom(0.7), (sput, 0.2, 0.7), (boing(0.5, 300, 0.6, 9.0), 0.25, 0.5), (crackle(0.5, 80.0, 1500.0) * dec(0.5, 5.0), 0.1, 0.3))

@snd("ram_bump", g=-1)
def _():
    return mix(thump(0.1, 170, 70, 26.0), (squish(0.08, 1300, 35.0), 0, 0.8), (osc(gliss(0.06, 300, 700), "sin") * dec(0.06, 30.0), 0, 0.5))

# ================================================================== Umgebung (22 kHz, nahtlos)
ASR = 16000
ALEN = 4.2

def _bed(fc_lo, fc_hi, mod_hz=0.4, depth=0.5):
    d = ALEN + 1.0
    n = sg.sosfilt(sg.butter(2, [fc_lo, fc_hi], "band", fs=ASR, output="sos"), rng().uniform(-1, 1, int(d * ASR)))
    m = sg.sosfilt(sg.butter(2, mod_hz, "low", fs=ASR, output="sos"), rng().uniform(-1, 1, int(d * ASR)))
    m = m / (np.max(np.abs(m)) + 1e-9)
    x = n * (1.0 - depth + depth * (0.5 + 0.5 * m))
    k = int(1.0 * ASR)
    kk = np.linspace(0, 1, k)
    y = x[:-k].copy()
    y[:k] = x[:k] * np.sin(kk * np.pi / 2) + x[-k:] * np.cos(kk * np.pi / 2)
    return y / (np.sqrt(np.mean(y ** 2)) + 1e-9)

def _chirp(f0, f1, d, vib=0.0):
    t = tt(d, ASR)
    f = gliss(d, f0, f1, ASR) * (1 + vib * np.sin(2 * np.pi * 30 * t))
    return osc(f, "sin", ASR) * hann(d, ASR)

def _place(buf, s, at, gain=1.0):
    wrap_add(buf, s * gain, int(at * ALEN / 6.0 * ASR))      # Zeiten sind für 6 s entworfen

@snd("amb_meadow", loop=True, sr=ASR, g=-4)
def _():
    x = _bed(150, 900, 0.3, 0.5) * 0.25
    r = rng()
    for t0 in (0.5, 2.6, 4.4):
        f = r.uniform(2800, 3800)
        for k in range(int(r.integers(3, 6))):
            _place(x, _chirp(f, f * r.uniform(1.1, 1.35), 0.07), t0 + k * 0.11, 0.5)
    for t0 in (1.5, 3.7):
        _place(x, _chirp(2200, 1700, 0.18, 0.03), t0, 0.35)
        _place(x, _chirp(2000, 2500, 0.14), t0 + 0.24, 0.35)
    return x

@snd("amb_forest", loop=True, sr=ASR, g=-4)
def _():
    x = _bed(400, 2600, 0.5, 0.7) * 0.22 + _bed(80, 400, 0.2, 0.4) * 0.18
    for t0 in (1.0, 4.0):                         # Kuckuck
        _place(x, _chirp(659, 650, 0.2), t0, 0.35)
        _place(x, _chirp(523, 515, 0.3), t0 + 0.3, 0.35)
    r = rng()
    for k in range(7):                            # Specht
        _place(x, sg.sosfilt(sg.butter(2, [700, 1800], "band", fs=ASR, output="sos"), rng().uniform(-1, 1, int(0.02 * ASR))) * dec(0.02, 150, ASR), 2.5 + k * 0.06, 0.6)
    _place(x, _chirp(3200, 3900, 0.08), 5.2, 0.3)
    _place(x, _chirp(3300, 4000, 0.08), 5.33, 0.3)
    return x

@snd("amb_desert", loop=True, sr=ASR, g=-4)
def _():
    d = ALEN
    t = tt(d, ASR)
    base = sg.sosfilt(sg.butter(2, 250, "low", fs=ASR, output="sos"), rng().uniform(-1, 1, len(t) + ASR))
    k = ASR
    kk = np.linspace(0, 1, k)
    b = base[:-k].copy()
    b[:k] = base[:k] * np.sin(kk * np.pi / 2) + base[-k:] * np.cos(kk * np.pi / 2)
    fc = 520 + 240 * np.sin(2 * np.pi * t / d) + 90 * np.sin(2 * np.pi * 3 * t / d)
    whistle = b * osc(fc, "sin", ASR) * (0.6 + 0.4 * np.sin(2 * np.pi * t / d - 1.0))
    whistle = whistle / (np.sqrt(np.mean(whistle ** 2)) + 1e-9)
    return whistle * 0.3 + _bed(100, 700, 0.3, 0.6) * 0.25

@snd("amb_coast", loop=True, sr=ASR, g=-4)
def _():
    d = ALEN
    t = tt(d, ASR)
    swell = (0.5 - 0.5 * np.cos(2 * np.pi * t / d)) ** 2
    x = _bed(200, 1800, 0.3, 0.2) * (0.12 + 0.5 * swell) + _bed(1500, 6000, 0.5, 0.3) * 0.25 * np.roll(swell, int(0.6 * ASR)) ** 2
    for t0, f in ((1.2, 1500), (1.6, 1400), (4.9, 1600)):       # Möwe (weit weg)
        _place(x, _chirp(f, f * 0.75, 0.22, 0.02), t0, 0.12)
    return x

@snd("amb_swamp", loop=True, sr=ASR, g=-4)
def _():
    x = _bed(100, 600, 0.3, 0.4) * 0.18
    t = tt(ALEN, ASR)
    crick = np.sin(2 * np.pi * 4300 * t) * (np.sin(2 * np.pi * 32 * t) > 0.3) * (np.sin(2 * np.pi * 0.5 * t) > 0.2) * 0.05
    x = x + crick
    def frog(f):
        tq = tt(0.16, ASR)
        s = sg.sosfilt(sg.butter(2, [300, 1400], "band", fs=ASR, output="sos"), np.sign(np.sin(2 * np.pi * f * tq)) * (0.5 + 0.5 * np.sin(2 * np.pi * 36 * tq)))
        return s * hann(0.16, ASR)
    for t0, f in ((0.8, 150), (1.05, 170), (3.4, 130), (3.65, 150), (3.9, 150)):
        _place(x, frog(f), t0, 0.3)
    r = rng()
    for k in range(6):
        f = r.uniform(300, 700)
        _place(x, _chirp(f, f * 2.0, 0.06) * dec(0.06, 25, ASR), r.uniform(0, ALEN), 0.35)
    return x

@snd("amb_snow", loop=True, sr=ASR, g=-4)
def _():
    d = ALEN
    t = tt(d, ASR)
    base = sg.sosfilt(sg.butter(2, 180, "low", fs=ASR, output="sos"), rng().uniform(-1, 1, len(t) + ASR))
    k = ASR
    kk = np.linspace(0, 1, k)
    b = base[:-k].copy()
    b[:k] = base[:k] * np.sin(kk * np.pi / 2) + base[-k:] * np.cos(kk * np.pi / 2)
    fc = 900 + 350 * np.sin(2 * np.pi * t / d) + 150 * np.sin(2 * np.pi * 2 * t / d + 1.0)
    howl = b * osc(fc, "sin", ASR) * (0.55 + 0.45 * np.sin(2 * np.pi * t / d + 0.5))
    howl = howl / (np.sqrt(np.mean(howl ** 2)) + 1e-9)
    x = howl * 0.3 + _bed(1500, 5000, 0.4, 0.6) * 0.14
    for t0, f in ((2.0, 2637), (2.3, 3136), (4.6, 2349)):
        tq = tt(0.5, ASR)
        _place(x, np.sin(2 * np.pi * f * tq) * np.exp(-tq * 9.0), t0, 0.08)
    return x

@snd("amb_crater", loop=True, sr=ASR, g=-4)
def _():
    t = tt(ALEN, ASR)
    x = _bed(80, 500, 0.3, 0.4) * 0.15 + (np.sin(2 * np.pi * 82 * t) + 0.5 * np.sin(2 * np.pi * 123 * t)) * (0.6 + 0.4 * np.sin(2 * np.pi * t / ALEN * 2)) * 0.12
    r = rng()
    for k in range(22):
        f = r.uniform(220, 800)
        dd = r.uniform(0.05, 0.1)
        _place(x, _chirp(f, f * r.uniform(1.6, 2.4), dd) * dec(dd, 20, ASR), r.uniform(0, ALEN), r.uniform(0.2, 0.5))
    for t0, f in ((1.3, 2093), (3.1, 2637), (4.8, 1760)):
        tq = tt(0.6, ASR)
        _place(x, np.sin(2 * np.pi * f * tq) * np.exp(-tq * 7.0), t0, 0.07)
    return x


# ------------------------------------------------------------------ Version 3: Tore, Sammelblasen, Juwelen
@snd("gate_open")
def _():
    creak = reso(noise(0.34), 520, 14.0) * ramp(0.34, 0.2, 1.0) * ar(0.34, 0.05, 0.1) * 0.5
    return mix(creak, (gliss(0.34, 180, 260) * ar(0.34, 0.03, 0.1) * 0.25, 0, 1.0), (thump(0.12, 150, 70, 20.0), 0.3, 0.9), (click(0.02, 900, 3000), 0.31, 0.5))

@snd("gate_close")
def _():
    creak = reso(noise(0.3), 460, 14.0) * ramp(0.3, 1.0, 0.3) * ar(0.3, 0.03, 0.08) * 0.45
    return mix(creak, (thump(0.16, 130, 55, 16.0), 0.26, 1.0), (click(0.03, 600, 2500), 0.27, 0.7), (reso(noise(0.08), 240, 6.0) * dec(0.08, 40.0), 0.28, 0.6))

@snd("bubble_pop")
def _():
    return mix(bubble(700.0, 0.06, 2.6), (click(0.015, 2500, 8000), 0.05, 0.5), (sparkle(0.25, 3000, 7000, 5), 0.06, 0.3))

@snd("bubble_show")
def _():
    return mix(bubble(380.0, 0.09, 1.9), (bell(1319, 0.2, 14.0), 0.07, 0.35))

@snd("gem_get", g=1)
def _():
    return mix(jingle(["E6", "G6", ("B6", "E7")], "bell", 0.06, 0.5, 6.0), (sparkle(0.4, 4000, 9000, 8), 0.1, 0.3))

@snd("gem_spend", g=1)
def _():
    return mix(jingle(["B6", "G6", "E6"], "bell", 0.05, 0.3, 9.0), (whoosh(0.3, 2500, 500, 600, 0.6), 0.05, 0.3), (bell(1047, 0.4, 7.0), 0.2, 0.6))

@snd("hero_xp_tick")
def _():
    return bell(1760, 0.06, 40.0, 2.0, 0.8) * 0.5


# ------------------------------------------------------------------ V3: Expedition, Bewohner, Basis, Gegnerfamilien
@snd("pad_pay")
def _():
    return mix(jingle(["C6", "E6"], "bell", 0.05, 0.25, 10.0), (click(0.03, 2000, 7000), 0.0, 0.5))

@snd("pad_hammer")
def _():
    return mix(thump(0.15, 260, 120, 30), (click(0.03, 1500, 6000, 120), 0, 0.8), (thump(0.15, 250, 120, 30), 0.22, 0.8), (click(0.03, 1500, 6000, 120), 0.22, 0.6))

@snd("tree_fall", g=1)
def _():
    crk = crackle(0.8, 160, 1200) * dec(0.8, 3)
    return mix(crk * 0.3, (whoosh(0.5, 300, 900, 300, 0.7), 0.6, 0.6), (thump(0.5, 90, 40, 8), 1.1, 1.0), (lp(noise(0.4), 600) * dec(0.4, 8), 1.1, 0.8))

@snd("node_break")
def _():
    return mix(thump(0.25, 180, 60, 14), (crackle(0.3, 200, 1500) * dec(0.3, 10), 0, 0.3), (click(0.05, 800, 5000, 60), 0, 0.8))

@snd("depot_drop")
def _():
    return mix(thump(0.2, 140, 70, 16), (jingle(["G5", "C6"], "bell", 0.06, 0.3, 9.0), 0.08, 0.5))

def _horn(f, d, bend=0.97):
    x = brass(f, d) + 0.5 * brass(f * 1.5, d)
    return soft(lp(x, 1400), 1.3)

@snd("raid_horn", g=1)
def _():
    return mix(_horn(196, 0.6), (_horn(196, 1.0), 0.75, 1.0))

@snd("siege_horn", g=2)
def _():
    return mix(_horn(130.8, 1.4), (_horn(98, 1.4), 0.2, 0.7), (thump(0.4, 80, 40, 6), 0, 0.8))

@snd("elite_arrive", g=1)
def _():
    return mix(thump(0.6, 70, 35, 5), (whoosh(0.7, 200, 1200, 500, 0.8), 0, 0.5), (_horn(110, 0.5), 0.35, 0.5))

@snd("zentrale_down", g=2)
def _():
    return mix(boom(1.4), (jingle(["E5", "C5", "A4"], "bell", 0.18, 0.8, 4.0), 0.5, 0.5))

@snd("outpost_done", g=1)
def _():
    return mix(jingle(["C5", "E5", "G5", ("C6", "E6")], "bell", 0.1, 0.8, 4.5), (sparkle(0.6), 0.3, 0.3))

@snd("outpost_level", g=1)
def _():
    return mix(jingle(["G5", "B5", "D6", ("G6", "B6")], "bell", 0.08, 0.7, 5.0), (sparkle(0.5, 3000, 8000, 10), 0.25, 0.3))

@snd("barrier_dissolve", g=1)
def _():
    return mix(whoosh(1.2, 2000, 300, 900, 0.2), (sparkle(1.0, 2000, 7000, 14), 0.1, 0.4), (tone(1.0, 880, 220) * dec(1.0, 3) * 0.3, 0, 1.0))

@snd("dusk_bell")
def _():
    return mix(bell(392, 1.6, 2.2, 2.0, 1.5), (bell(392, 1.4, 2.2, 2.0, 1.5), 0.9, 0.7))

@snd("trade")
def _():
    return mix(jingle(["E6", "A6"], "bell", 0.07, 0.3, 9.0), (click(0.04, 3000, 8000), 0.1, 0.5), (jingle(["C#6", "E6"], "bell", 0.07, 0.3, 9.0), 0.2, 0.6))

@snd("npc_greet")
def _():
    return mix(_chirp(1400, 2100, 0.12), (_chirp(2100, 1500, 0.18), 0.16, 1.0)) * 0.6

@snd("npc_cheer")
def _():
    r = rng()
    parts = [(blub(0.25, r.uniform(350, 520), r.uniform(600, 800), 0.03, 7.0) * 0.4, r.uniform(0, 0.2), 1.0) for _ in range(5)]
    return mix(*parts, (sparkle(0.4, 3000, 7000, 5), 0.1, 0.2))

@snd("plant_puff")
def _():
    return mix(whoosh(0.25, 1800, 600, 700, 0.15) * 0.8, (bubble(600, 0.08, 1.8), 0.02, 0.5))

@snd("bird_chirp")
def _():
    r = rng(); f = r.uniform(3000, 3800)
    return mix(*[(_chirp(f, f * 1.3, 0.06), i * 0.09, 0.6) for i in range(4)])

@snd("bird_flap")
def _():
    return mix(*[(bp(noise(0.06), 400, 2500) * hann(0.06), i * 0.08, 0.8 - i * 0.12) for i in range(5)])

@snd("gull_call")
def _():
    return mix(*[(soft((tone(0.22, 1500, 1050, "saw") * hann(0.22)), 1.5) * 0.35, i * 0.25, 1.0) for i in range(3)])

@snd("chicken_cluck")
def _():
    return mix(*[(lp(tone(0.07, 700, 520, "saw"), 1800) * hann(0.07) * 0.6, t, 1.0) for t in (0, 0.12, 0.2, 0.38)])

@snd("duck_quack")
def _():
    x = reso(tone(0.22, 480, 380, "saw"), 1100, 4) * hann(0.22) ** 0.5
    return mix(x * 0.5, (x * 0.4, 0.28, 1.0))

@snd("cat_meow")
def _():
    d = 0.6; f = np.interp(np.linspace(0, 1, int(d * SR)), [0, 0.4, 1], [500, 760, 420])
    x = reso(osc(f, "saw"), 1300, 3) + reso(osc(f, "saw"), 2600, 4) * 0.4
    return lp(x, 3500) * hann(d) ** 0.7 * 0.4

@snd("dog_bark")
def _():
    b = lambda: mix(soft(lp(tone(0.14, 420, 260, "saw"), 1600) * dec(0.14, 14) * 1.5, 1.5), (lp(noise(0.05), 1500) * dec(0.05, 40), 0, 0.3))
    return mix(b(), (b(), 0.22, 0.9))

@snd("amb_birds", loop=True, sr=ASR, g=-4)
def _():
    x = _bed(200, 1200, 0.3, 0.4) * 0.15
    r = rng()
    for t0 in (0.3, 1.4, 2.3, 3.3, 4.6, 5.4):
        f = r.uniform(2600, 4200)
        for k in range(int(r.integers(2, 6))):
            _place(x, _chirp(f, f * r.uniform(0.85, 1.35), r.uniform(0.05, 0.1)), t0 + k * 0.1, 0.45)
    return x

@snd("amb_crickets", loop=True, sr=ASR, g=-6)
def _():
    x = _bed(100, 600, 0.2, 0.3) * 0.12
    r = rng()
    for t0 in np.arange(0.0, 6.0, 0.35):
        f = 4300 + r.uniform(-150, 150)
        for k in range(3):
            _place(x, osc(np.full(int(0.025 * ASR), f), "sin", ASR) * hann(0.025, ASR), t0 + k * 0.04, 0.25)
    return x

@snd("amb_wind_trees", loop=True, sr=ASR, g=-4)
def _():
    return _bed(300, 2200, 0.25, 0.8) * 0.4 + _bed(80, 400, 0.15, 0.6) * 0.2

@snd("amb_waves", loop=True, sr=ASR, g=-4)
def _():
    return _bed(150, 1600, 0.25, 0.95) * 0.45 + _bed(1500, 5000, 0.25, 0.9) * 0.12

@snd("amb_rain", loop=True, sr=ASR, g=-5)
def _():
    x = _bed(800, 6000, 1.5, 0.2) * 0.35
    r = rng()
    for t0 in r.uniform(0, 6, 40):
        _place(x, bp(rng().uniform(-1, 1, int(0.01 * ASR)), 1500, 6000, 2, ASR) * dec(0.01, 300, ASR), t0, r.uniform(0.1, 0.4))
    return x

# Gegnerfamilien: <sound>_spawn/attack/hit/death/special/shot/laugh (Klangfarbe je Familie)
FAM_VOICE = {
    "e_schleim":  ("blub", 260, 0.08),
    "e_untote":   ("groan", 110, 0.0),
    "e_wald":     ("wood", 300, 0.0),
    "e_wueste":   ("hiss", 180, 0.0),
    "e_mutanten": ("growl", 140, 0.04),
    "e_eis":      ("ice", 700, 0.0),
    "e_daemonen": ("demon", 90, 0.02),
}

def _voice(kind, f, d, up=1.0, wob=0.0):
    if kind == "blub":
        return blub(d, f, f * up * 1.6, 0.08, 16) * 0.6
    if kind == "groan":
        x = reso(tone(d, f, f * up, "saw"), 600, 3) + reso(tone(d, f, f * up, "saw"), 1100, 5) * 0.5
        return lp(x, 1800) * hann(d) ** 0.5 * 0.5
    if kind == "wood":
        return mix(crackle(d, 140, 900) * dec(d, 5) * 0.3, (bp(noise(d), f, f * 4) * hann(d) * 0.8, 0, 1.0), (tone(d, f * 0.5, f * 0.5 * up, "tri") * hann(d) * 0.3, 0, 1.0))
    if kind == "hiss":
        return mix(hp(noise(d), 2500) * hann(d) * 0.4, (lp(tone(d, f, f * up, "saw"), 900) * hann(d) * 0.3, 0, 1.0))
    if kind == "growl":
        t = tt(d)
        x = osc(gliss(d, f, f * up) * (1 + 0.08 * np.sin(2 * np.pi * 28 * t)), "saw")
        return soft(lp(x, 1200) * hann(d) ** 0.5, 2.0) * 0.5
    if kind == "ice":
        return mix(sparkle(d, f * 3, f * 9, 6) * 0.5, (whoosh(d, f * 2, f * 4 * up, 600, 0.3) * 0.5, 0, 1.0), (bell(f * up, d, 8, 2.7, 1.0) * 0.3, 0, 1.0))
    if kind == "demon":
        x = osc(gliss(d, f, f * up), "saw") + osc(gliss(d, f * 0.5, f * 0.5 * up), "sq") * 0.6
        return mix(soft(lp(x, 900) * hann(d) ** 0.4, 2.5) * 0.5, (crackle(d, 80, 1500) * dec(d, 4) * 0.15, 0, 1.0))
    raise ValueError(kind)

def _fam(name, kind, f, wob, what, var):
    sc = 1.0 + 0.07 * var
    if what == "spawn":
        return mix(_voice(kind, f * sc, 0.45, 1.3), (whoosh(0.3, 300, 900, 300, 0.5) * 0.3, 0, 1.0))
    if what == "attack":
        return mix(_voice(kind, f * 1.3 * sc, 0.2, 0.8), (whoosh(0.15, 1500, 400, 600, 0.3) * 0.5, 0.03, 1.0))
    if what == "hit":
        return mix(_voice(kind, f * 1.6 * sc, 0.12, 0.7) * 0.8, (click(0.03, 600, 4000, 80), 0, 0.6))
    if what == "death":
        return mix(_voice(kind, f * 1.1 * sc, 0.6, 0.5), (thump(0.3, 140, 50, 10), 0.3, 0.6))
    if what == "special":
        return mix(_voice(kind, f * 0.8 * sc, 0.5, 1.6), (sparkle(0.4, 1500, 4000, 4) * 0.2, 0.1, 1.0))
    if what == "shot":
        return mix(whoosh(0.25, 600, 2500, 700, 0.2) * 0.6, (_voice(kind, f * 2 * sc, 0.1, 1.2) * 0.5, 0, 1.0))
    if what == "laugh":
        return mix(*[(_voice(kind, f * 1.4 * sc, 0.1, 1.1), i * 0.14, 1.0 - i * 0.15) for i in range(4)])

for _n, (_k, _f, _w) in FAM_VOICE.items():
    for _what, _nv in (("spawn", 1), ("attack", 2), ("hit", 3), ("death", 2), ("special", 1), ("shot", 1), ("laugh", 1)):
        for _v in range(_nv):
            _nm = "%s_%s" % (_n, _what) + ("_%d" % (_v + 1) if _nv > 1 else "")
            snd(_nm, g=-2)((lambda n=_n, k=_k, f=_f, w=_w, what=_what, v=_v: _fam(n, k, f, w, what, v)))



# ------------------------------------------------------------------ V4: Waffen-Arsenal
def _shot(f0=900, f1=200, body=0.12, bright=2500, tail=0.15, boomk=0.0):
    x = mix(click(0.03, bright * 0.6, bright * 2.5, 90) * 1.2, (thump(body, f0 * 0.25, f1 * 0.25, 22), 0, 0.9),
            (bp(noise(tail), 300, bright) * dec(tail, 18), 0.01, 0.6))
    if boomk:
        x = mix(x, (boom(boomk) * 0.6, 0, 1.0))
    return soft(x, 1.3)

def _loopn(lo, hi, mod=6.0, tone_f=0.0, d=1.2):
    n = bp(noise(d + 0.4), lo, hi) * 2.0
    m = 0.7 + 0.3 * np.sin(2 * np.pi * mod * tt(d + 0.4))
    x = n * m
    if tone_f:
        x = x + osc(np.full(len(x), tone_f), "saw") * 0.15
    return loopify(x, 0.4)

V4 = {
    "w_pistol": lambda: mix(_shot(1200, 300, 0.08, 3000, 0.1), (click(0.02, 1500, 4000, 150), 0.06, 0.5)),
    "w_shotgun": lambda: _shot(500, 80, 0.25, 2000, 0.35, 0.5),
    "w_smg": lambda: _shot(1400, 500, 0.05, 3500, 0.06),
    "w_rail": lambda: mix(tone(0.25, 3000, 400, "saw") * dec(0.25, 8) * 0.4, (_shot(900, 200, 0.1, 5000, 0.2), 0.02, 1.0)),
    "w_rivet": lambda: mix(squish(0.1, 1500, 30), (click(0.03, 2000, 6000, 100), 0.02, 1.0)),
    "w_crossbow": lambda: mix(click(0.03, 800, 3000, 120), (pluck(180, 0.25, 14, "tri"), 0, 0.8)),
    "w_longbow": lambda: mix(pluck(110, 0.4, 8, "tri"), (whoosh(0.3, 600, 2000, 300, 0.2) * 0.5, 0.03, 1.0)),
    "w_bow_ice": lambda: mix(pluck(150, 0.3, 10, "tri"), (sparkle(0.4, 3000, 8000, 8) * 0.5, 0.05, 1.0)),
    "w_candy": lambda: mix(bubble(500, 0.08, 2.5), (sparkle(0.2, 2500, 6000, 3) * 0.3, 0.03, 1.0)),
    "w_popper": lambda: mix(click(0.04, 1000, 6000, 60) * 1.3, (sparkle(0.4, 2000, 7000, 10) * 0.5, 0.03, 1.0)),
    "w_mortar": lambda: mix(thump(0.3, 160, 50, 10), (whoosh(0.4, 400, 1500, 300, 0.3) * 0.4, 0.05, 1.0)),
    "w_flare": lambda: mix(thump(0.2, 200, 80, 14), (bp(noise(0.6), 2000, 6000) * dec(0.6, 4) * 0.5, 0.05, 1.0)),
    "w_rocket": lambda: mix(*[(whoosh(0.5, 300, 1800, 500, 0.15) * 0.6, i * 0.09, 1.0) for i in range(3)]),
    "w_seek": lambda: mix(*[(whoosh(0.35, 800, 2600, 500, 0.1) * 0.4, i * 0.05, 1.0) for i in range(6)]),
    "w_bigrocket": lambda: mix(thump(0.4, 120, 40, 6), (whoosh(1.0, 200, 1500, 600, 0.1) * 0.9, 0.0, 1.0)),
    "w_finale": lambda: mix(*[(_shot(700, 150, 0.1, 2500, 0.1) * 0.6, i * 0.12, 1.0) for i in range(5)]),
    "w_roman": lambda: mix(thump(0.15, 220, 90, 18), (bp(noise(0.3), 1500, 5000) * dec(0.3, 10) * 0.4, 0.02, 1.0)),
    "w_demolish": lambda: mix(boom(1.3), (thump(0.5, 80, 30, 6), 0, 0.8)),
    "w_dragon": lambda: mix(_loopn(150, 1500, 9, 0, 0.6)[:int(0.6 * SR)] * hann(0.6), (thump(0.2, 180, 60, 12), 0, 0.6)),
    "w_balloon": lambda: mix(tone(0.25, 300, 700, "sq") * hann(0.25) * 0.3, (whoosh(0.25, 500, 1200, 300, 0.3) * 0.3, 0, 1.0)),
    "w_bottle": lambda: mix(bell(2400, 0.2, 18, 3.1, 1.0) * 0.4, (whoosh(0.4, 400, 1500, 400, 0.5) * 0.5, 0.05, 1.0)),
    "w_toss": lambda: mix(whoosh(0.3, 300, 900, 300, 0.3) * 0.6, (squish(0.08, 600, 30) * 0.5, 0, 1.0)),
    "w_vortex": lambda: mix(tone(0.8, 120, 600, "saw") * hann(0.8) * 0.2, (whoosh(0.8, 1500, 300, 600, 0.6) * 0.7, 0, 1.0)),
    "w_harpoon": lambda: mix(_shot(600, 150, 0.12, 2000, 0.1), (bp(noise(0.5), 2000, 5000) * dec(0.5, 6) * 0.3, 0.05, 1.0)),
    "w_sling": lambda: mix(pluck(260, 0.15, 25, "sq") * 0.6, (whoosh(0.2, 800, 2000, 400, 0.2) * 0.5, 0.02, 1.0)),
    "w_blowpipe": lambda: bp(noise(0.18), 600, 3000) * hann(0.18) * 1.3,
    "w_arrow_rain": lambda: mix(pluck(130, 0.3, 10, "tri"), (whoosh(0.6, 800, 3000, 400, 0.4) * 0.6, 0.05, 1.0)),
    "w_star": lambda: mix(*[(whoosh(0.2, 2500, 4000, 800, 0.2) * 0.5, i * 0.06, 1.0) for i in range(3)]),
    "w_boomerang": lambda: mix(*[(whoosh(0.15, 600, 1500, 300, 0.5) * 0.7, i * 0.13, 1.0) for i in range(5)]),
    "w_wheel": lambda: mix(_loopn(2000, 7000, 20, 0, 0.6)[:int(0.6 * SR)] * hann(0.6) * 0.6, (sparkle(0.6, 2500, 6000, 8) * 0.3, 0, 1.0)),
    "w_chain": lambda: mix(crackle(0.5, 80, 2500) * dec(0.5, 3) * 0.5, (click(0.05, 800, 4000, 60), 0.4, 1.0)),
    "w_disc": lambda: mix(bell(1400, 0.4, 7, 2.4, 1.2) * 0.5, (whoosh(0.3, 1000, 2500, 400, 0.3) * 0.4, 0, 1.0)),
    "w_hawk": lambda: mix(soft(tone(0.4, 2400, 1600, "saw") * hann(0.4), 1.4) * 0.3, (whoosh(0.3, 400, 1200, 300, 0.4) * 0.5, 0.1, 1.0)),
    "w_bounce": lambda: bell(1800, 0.15, 25, 2.0, 0.8) * 0.5,
    "w_axe": lambda: mix(whoosh(0.25, 400, 1500, 400, 0.6), (thump(0.15, 220, 90, 20), 0.2, 0.8)),
    "w_shovel": lambda: mix(whoosh(0.25, 500, 1800, 400, 0.6), (bell(900, 0.3, 10, 2.7, 1.0) * 0.3, 0.2, 1.0)),
    "w_heavy_swing": lambda: whoosh(0.45, 150, 700, 300, 0.6) * 1.2,
    "w_umbrella": lambda: mix(whoosh(0.3, 600, 1600, 400, 0.5), (crackle(0.2, 100, 2000) * 0.2, 0.05, 1.0)),
    "w_thrust": lambda: whoosh(0.18, 800, 2500, 500, 0.2) * 1.1,
    "w_slam": lambda: mix(whoosh(0.35, 400, 1500, 400, 0.6) * 0.5, (boom(0.8), 0.3, 1.0)),
    "w_stomp": lambda: mix(*[(thump(0.12, 120, 50, 25), i * 0.09, 1.0) for i in range(4)]),
    "w_siren": lambda: osc(np.interp(np.linspace(0, 1, int(0.8 * SR)), [0, 0.5, 1], [500, 900, 500]), "sq") * hann(0.8) * 0.3,
    "w_nova": lambda: mix(crackle(0.4, 250, 2500) * dec(0.4, 6) * 0.6, (tone(0.4, 200, 1200, "saw") * hann(0.4) * 0.2, 0, 1.0)),
    "w_disco": lambda: mix(sparkle(0.6, 2000, 8000, 14) * 0.6, (tone(0.3, 400, 800, "sq") * hann(0.3) * 0.15, 0, 1.0)),
    "w_jammer": lambda: crackle(0.5, 200, 1500) * hann(0.5) * 0.7,
    "w_zap": lambda: mix(crackle(0.15, 400, 3000) * 0.6, (tone(0.15, 1500, 300, "saw") * hann(0.15) * 0.2, 0, 1.0)),
    "w_freeze": lambda: mix(sparkle(0.4, 3000, 9000, 10) * 0.6, (whoosh(0.3, 2000, 600, 600, 0.3) * 0.4, 0, 1.0)),
    "w_plasma": lambda: mix(blub(0.25, 300, 900, 0.1, 20) * 0.5, (bp(noise(0.3), 2000, 6000) * dec(0.3, 10) * 0.4, 0.03, 1.0)),
    "w_mine_drop": lambda: mix(thump(0.1, 300, 150, 30), (click(0.03, 2000, 5000, 100), 0.08, 0.8), (bell(2200, 0.1, 30, 2, 0.5) * 0.3, 0.15, 1.0)),
    "w_turret_deploy": lambda: mix(*[(click(0.04, 800, 4000, 80), i * 0.1, 1.0) for i in range(4)], (bell(1200, 0.3, 10, 2, 0.6) * 0.3, 0.45, 1.0)),
    "craft_weapon": lambda: mix(*[(thump(0.12, 300, 150, 25), i * 0.18, 0.8) for i in range(3)], (jingle(["C6", "G6"], "bell", 0.08, 0.4, 7.0), 0.6, 0.6)),
    "blueprint_found": lambda: mix(whoosh(0.3, 800, 2500, 600, 0.3) * 0.4, (jingle(["E5", "A5", "E6"], "bell", 0.08, 0.5, 6.0), 0.1, 0.6)),
    "weapon_found": lambda: mix(jingle(["G5", "C6", "E6", ("G6", "C7")], "bell", 0.08, 0.6, 5.0), (sparkle(0.5), 0.2, 0.3)),
}
V4_LOOPS = {
    "w_foam_loop": (300, 2500, 4, 0), "w_jet_loop": (500, 4000, 10, 0), "w_frost_loop": (2000, 8000, 3, 0),
    "w_heat_loop": (80, 600, 2, 110), "w_laser_loop": (800, 2500, 5, 880), "w_storm_loop": (1000, 6000, 15, 0),
    "w_tar_loop": (100, 800, 7, 0), "w_steam_loop": (1500, 5000, 2, 1760), "w_wind_loop": (200, 1500, 0.8, 0),
    "w_drill_loop": (150, 2000, 30, 0), "w_charge_loop": (300, 2000, 3, 440),
}
for _n, _f in V4.items():
    snd(_n)(_f)
for _n, _p in V4_LOOPS.items():
    snd(_n, loop=True)((lambda p=_p: _loopn(*p)))

# ------------------------------------------------------------------ V4: Begleiter
COMP = {
    "comp_kistenbein": lambda: mix(*[(click(0.04, 500, 2500, 70), i * 0.07, 1.0) for i in range(3)], (tone(0.12, 900, 1400, "sq") * hann(0.12) * 0.2, 0.2, 1.0)),
    "comp_esel": lambda: mix(soft(tone(0.35, 500, 300, "saw") * hann(0.35), 1.5) * 0.3, (soft(tone(0.4, 300, 450, "saw") * hann(0.4), 1.5) * 0.3, 0.38, 1.0)),
    "comp_schnecke": lambda: mix(*[(blub(0.12, 200, 300, 0.1, 15) * 0.4, i * 0.12, 1.0) for i in range(3)]),
    "comp_kaefer": lambda: mix(*[(click(0.02, 3000, 7000, 200), i * 0.04, 1.0) for i in range(6)]),
    "comp_ziege": lambda: mix(soft(osc(gliss(0.4, 600, 500) * (1 + 0.06 * np.sin(2 * np.pi * 25 * tt(0.4))), "saw") * hann(0.4), 1.4) * 0.25, (bell(2600, 0.3, 10) * 0.3, 0.05, 1.0)),
    "comp_drohne": lambda: mix(osc(np.interp(np.linspace(0, 1, int(0.6 * SR)), [0, 0.5, 1], [220, 330, 220]), "saw") * hann(0.6) * 0.15, (bell(1800, 0.1, 30) * 0.3, 0.5, 1.0)),
    "comp_biber": lambda: mix(crackle(0.4, 150, 1500) * hann(0.4) * 0.5, (tone(0.1, 700, 1000, "sq") * hann(0.1) * 0.2, 0.42, 1.0)),
    "comp_waschbaer": lambda: mix(*[(tone(0.06, 1200, 1700, "sq") * hann(0.06) * 0.25, i * 0.08, 1.0) for i in range(5)]),
    "comp_golem": lambda: mix(lp(noise(0.7), 300) * hann(0.7) * 1.5, (tone(0.7, 70, 55, "saw") * hann(0.7) * 0.3, 0, 1.0)),
    "comp_husky": lambda: soft(osc(np.interp(np.linspace(0, 1, int(0.9 * SR)), [0, 0.3, 1], [500, 900, 700]), "saw") * hann(0.9), 1.3) * 0.2,
    "comp_eule": lambda: mix(tone(0.25, 420, 400) * hann(0.25) * 0.5, (tone(0.35, 400, 380) * hann(0.35) * 0.5, 0.35, 1.0)),
    "comp_gluehwurm": lambda: mix(sparkle(0.5, 3000, 8000, 8) * 0.5, (tone(0.5, 600, 650, "tri") * hann(0.5) * 0.1, 0, 1.0)),
    "comp_pickup": lambda: mix(thump(0.12, 220, 110, 20), (click(0.03, 800, 3000, 100) * 0.5, 0.02, 1.0)),
    "comp_blink": lambda: mix(whoosh(0.25, 2000, 500, 600, 0.3) * 0.6, (bubble(700, 0.08, 2.0), 0.15, 0.5)),
    "comp_down": lambda: mix(tone(0.3, 400, 200, "sq") * hann(0.3) * 0.15, (thump(0.25, 150, 60, 10), 0.25, 1.0)),
    "comp_getup": lambda: mix(*[(bp(noise(0.06), 800, 3000) * hann(0.06), i * 0.07, 0.7) for i in range(4)]),
    "comp_levelup": lambda: mix(jingle(["C5", "E5", "G5", ("C6", "E6")], "bell", 0.09, 0.6, 5.0), (sparkle(0.5), 0.3, 0.3)),
    "comp_punch": lambda: mix(thump(0.2, 180, 60, 14), (crackle(0.2, 150, 1500) * dec(0.2, 12) * 0.4, 0, 1.0)),
    "comp_mine": lambda: mix(*[(click(0.03, 1500, 5000, 120), i * 0.09, 0.8) for i in range(4)]),
    "comp_found_chest": lambda: mix(jingle(["A5", "E6"], "bell", 0.1, 0.5, 6.0), (sparkle(0.4), 0.1, 0.3)),
    "comp_free": lambda: mix(click(0.05, 600, 3000, 60), (jingle(["C5", "G5", "C6", "E6"], "bell", 0.08, 0.6, 5.0), 0.1, 0.7)),
    "comp_craft": lambda: mix(*[(thump(0.12, 280, 140, 25), i * 0.16, 0.8) for i in range(3)], (bell(1568, 0.4, 6) * 0.4, 0.55, 1.0)),
    "comp_select": lambda: mix(bubble(600, 0.07, 1.8), (bell(1200, 0.2, 12) * 0.3, 0.05, 1.0)),
}
for _n, _f in COMP.items():
    snd(_n)(_f)



# ------------------------------------------------------------------ Hauptprogramm
def main():
    flt = sys.argv[1] if len(sys.argv) > 1 else ""
    os.makedirs(OUT, exist_ok=True)
    total = 0
    names = []
    for i, (name, fn, opts) in enumerate(REG):
        _seed[0] = 1000 + i * 37                  # jeder Effekt ist für sich reproduzierbar
        if flt and flt not in name:
            continue
        x, sr = finish(fn(), opts)
        path = os.path.join(OUT, name + ".wav")
        write_wav(path, x, sr, opts.get("loop", False))
        total += os.path.getsize(path)
        names.append(name)
        print("%-22s %5.2fs  peak %.2f  loud %6.1f dB%s" % (name, len(x) / sr, np.max(np.abs(x)), loud(x, sr), "  loop" if opts.get("loop") else ""))
    print("%d Dateien, %.2f MB" % (len(names), total / 1e6))


if __name__ == "__main__":
    main()
