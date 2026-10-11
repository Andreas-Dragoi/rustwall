#!/usr/bin/env python3
"""Komponiert und rendert die beiden Folgestücke von Rustwall:
  audio/music/meadow_march.ogg  – munterer Marsch (Kampf), C-Dur, 114 BPM
  audio/music/evening_base.ogg  – ruhiges Abendstück (Basis), F-Dur, 76 BPM
Tempo und Tonart sind auf das Lied des Spielers (castle_defense.mp3: C-Dur, ~114 BPM,
-15,4 LUFS) abgestimmt, damit die Übergänge weich klingen.
Aufruf:  python3 tools/make_music.py [meadow|evening]     (braucht numpy, scipy, ffmpeg)"""
import os, sys, subprocess, re, tempfile
import numpy as np
from scipy import signal as sg
from scipy.io import wavfile

SR = 44100
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "audio", "music")
RNG = np.random.default_rng(2024)

NOTE = {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}
CHORDS = {   # Grundton (für den Bass), Akkordtöne
    "C": ("C", ["C", "E", "G"]), "G": ("G", ["G", "B", "D"]), "G/B": ("B", ["G", "B", "D"]), "Am": ("A", ["A", "C", "E"]),
    "F": ("F", ["F", "A", "C"]), "Dm": ("D", ["D", "F", "A"]), "Em": ("E", ["E", "G", "B"]), "C/E": ("E", ["C", "E", "G"]),
    "D7": ("D", ["D", "F#", "A", "C"]), "Bb": ("Bb", ["Bb", "D", "F"]), "Gm": ("G", ["G", "Bb", "D"]), "C7": ("C", ["C", "E", "G", "Bb"]),
    "Fadd9": ("F", ["F", "A", "C", "G"]), "F/A": ("A", ["F", "A", "C"]), "Csus": ("C", ["C", "F", "G"]), "Gsus": ("G", ["G", "C", "D"]),
}


def pc(name):
    return NOTE[name[0]] + (1 if "#" in name else 0) - (1 if "b" in name[1:] else 0)


def midi(n):
    return 12 * (int(n[-1]) + 1) + pc(n[:-1])


def hz(m):
    return 440.0 * 2 ** ((m - 69) / 12.0)


def voicing(chord, center, count=3):
    """Akkordtöne möglichst nah um die Mitte 'center' (MIDI) legen."""
    out = []
    for name in CHORDS[chord][1]:
        m = pc(name) + 12 * round((center - pc(name)) / 12.0)
        out.append(int(m))
    return sorted(out)[:max(count, len(out))]


def bass_note(chord, octave=2):
    m = pc(CHORDS[chord][0]) + 12 * (octave + 1)
    return m if m >= 12 * (octave + 1) + 4 else m + 12      # nicht tiefer als E


def parse(mel):
    """'G4:.5 C5:1 r:2 | ...' -> [(midi oder None, Schläge)]"""
    out = []
    for k, bar in enumerate(mel.split("|")):                 # jeder Takt muss vier Schläge haben
        total = sum(float(tok.split(":")[1]) for tok in bar.split())
        assert abs(total - 4.0) < 1e-6, "Takt %d hat %.2f Schläge: %s" % (k + 1, total, bar)
    for tok in mel.replace("|", " ").split():
        n, d = tok.split(":")
        out.append((None if n == "r" else midi(n), float(d)))
    return out


# ------------------------------------------------------------------ Klangbausteine
def tt(d):
    return np.arange(int(d * SR)) / SR


def adsr(n, a, d, s, r):
    """n Samples insgesamt, die letzten r Sekunden sind der Ausklang."""
    na, nd, nr = int(a * SR), int(d * SR), int(r * SR)
    e = np.full(n, s)
    na = min(na, n)
    e[:na] = np.linspace(0, 1, na)
    nd2 = min(nd, max(n - na, 0))
    e[na:na + nd2] = np.linspace(1, s, nd) [:nd2]
    nr = min(nr, n)
    e[-nr:] *= np.linspace(1, 0, nr) ** 1.3
    return e


def lpf(x, fc, order=2):
    return sg.sosfilt(sg.butter(order, min(fc, SR * 0.45), "low", fs=SR, output="sos"), x)


def hpf(x, fc, order=2):
    return sg.sosfilt(sg.butter(order, fc, "high", fs=SR, output="sos"), x)


def bpf(x, f1, f2):
    return sg.sosfilt(sg.butter(2, [f1, min(f2, SR * 0.45)], "band", fs=SR, output="sos"), x)


def i_lead(f, d, vel=1.0):
    """Spielzeug-Lead: Dreieck + weiches Rechteck, spätes Vibrato."""
    n = int((d + 0.09) * SR)
    t = np.arange(n) / SR
    vib = 1.0 + 0.006 * np.sin(2 * np.pi * 5.6 * t) * np.clip((t - 0.14) / 0.2, 0, 1)
    ph = 2 * np.pi * f * np.cumsum(vib) / SR
    x = 0.62 * (2 / np.pi) * np.arcsin(np.sin(ph)) + 0.3 * np.tanh(2.5 * np.sin(ph)) + 0.12 * np.sin(2 * ph + 0.5)
    ph2 = ph * 1.004
    x += 0.3 * (2 / np.pi) * np.arcsin(np.sin(ph2))
    x = lpf(x, min(7000.0, f * 5.0 + 800.0))
    return x * adsr(n, 0.012, 0.09, 0.72, 0.09) * vel


def i_trumpet(f, d, vel=1.0):
    """Weiche Spielzeug-Trompete (additiv, heller Anschlag)."""
    n = int((d + 0.08) * SR)
    t = np.arange(n) / SR
    vib = 1.0 + 0.005 * np.sin(2 * np.pi * 5.2 * t) * np.clip((t - 0.15) / 0.2, 0, 1)
    ph = 2 * np.pi * f * np.cumsum(vib) / SR
    bright = 0.45 + 0.55 * np.exp(-t * 9.0)
    x = np.zeros(n)
    for h in range(1, 9):
        if f * h > 9000:
            break
        x += np.sin(ph * h) * (1.0 / h) * (bright ** (h - 1)) * (1.0 if h < 4 else 0.7)
    return x * adsr(n, 0.03, 0.1, 0.8, 0.08) * vel * 0.7


def i_flute(f, d, vel=1.0):
    n = int((d + 0.14) * SR)
    t = np.arange(n) / SR
    vib = 1.0 + 0.007 * np.sin(2 * np.pi * 4.8 * t) * np.clip((t - 0.2) / 0.3, 0, 1)
    ph = 2 * np.pi * f * np.cumsum(vib) / SR
    x = np.sin(ph) + 0.22 * np.sin(2 * ph) + 0.07 * np.sin(3 * ph)
    breath = bpf(RNG.uniform(-1, 1, n), f * 1.5, f * 4.0) * (0.25 * np.exp(-t * 14.0) + 0.035)
    return (x + breath) * adsr(n, 0.05, 0.1, 0.85, 0.14) * vel


def i_glock(f, d, vel=1.0):
    n = int(max(d, 0.5) * SR + 0.3 * SR)
    t = np.arange(n) / SR
    mod = np.sin(2 * np.pi * f * 3.5 * t) * 1.6 * np.exp(-t * 16.0)
    x = np.sin(2 * np.pi * f * t + mod) + 0.2 * np.sin(2 * np.pi * f * 4.0 * t) * np.exp(-t * 14.0)
    return x * np.exp(-t * 5.5) * adsr(n, 0.002, 0.01, 1.0, 0.12) * vel


def i_musicbox(f, d, vel=1.0):
    n = int(1.6 * SR)
    t = np.arange(n) / SR
    x = np.sin(2 * np.pi * f * t) * np.exp(-t * 3.6) + 0.35 * np.sin(2 * np.pi * f * 3.0 * t) * np.exp(-t * 9.0) \
        + 0.18 * np.sin(2 * np.pi * f * 5.4 * t) * np.exp(-t * 16.0)
    tick = hpf(RNG.uniform(-1, 1, n), 3500) * np.exp(-t * 400.0) * 0.25
    return (x + tick) * adsr(n, 0.002, 0.01, 1.0, 0.2) * vel


def i_pluck(f, d, vel=1.0):
    """Gezupft (Harfe/Pizzicato): Obertöne klingen schneller ab."""
    n = int(max(d, 0.35) * SR + 0.35 * SR)
    t = np.arange(n) / SR
    x = np.zeros(n)
    for h in range(1, 8):
        if f * h > 8000:
            break
        x += np.sin(2 * np.pi * f * h * t + h) * (1.0 / h ** 1.2) * np.exp(-t * (2.6 + 1.9 * h))
    return x * adsr(n, 0.003, 0.01, 1.0, 0.15) * vel


def i_stab(f, d, vel=1.0):
    """Kurzer Akkordschlag (das 'Pah' im Marsch)."""
    n = int(0.22 * SR)
    t = np.arange(n) / SR
    ph = 2 * np.pi * f * t
    x = 0.6 * (2 / np.pi) * np.arcsin(np.sin(ph)) + 0.3 * np.tanh(2 * np.sin(ph))
    x = lpf(x, 2600)
    return x * np.exp(-t * 16.0) * adsr(n, 0.004, 0.01, 1.0, 0.05) * vel


def i_pad(f, d, vel=1.0):
    n = int((d + 0.6) * SR)
    t = np.arange(n) / SR
    x = np.zeros(n)
    for det in (-0.006, 0.0, 0.007):
        ph = 2 * np.pi * f * (1 + det) * t + RNG.uniform(0, 6.28)
        for h in range(1, 7):
            x += np.sin(ph * h) / h ** 1.6
    x = lpf(x, 1500)
    return x * adsr(n, 0.35, 0.3, 0.85, 0.6) * vel * 0.38


def i_bass(f, d, vel=1.0):
    n = int((d + 0.06) * SR)
    t = np.arange(n) / SR
    ph = 2 * np.pi * f * t
    x = np.sin(ph) + 0.45 * (2 / np.pi) * np.arcsin(np.sin(ph)) + 0.25 * np.sin(2 * ph) * np.exp(-t * 6.0)
    return x * (0.65 + 0.35 * np.exp(-t * 5.0)) * adsr(n, 0.006, 0.05, 0.9, 0.06) * vel * 0.64


def d_kick(vel=1.0, soft=False):
    n = int(0.3 * SR)
    t = np.arange(n) / SR
    f = 46 + (95 if soft else 130) * np.exp(-t * 32.0)
    x = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * (16.0 if soft else 13.0)) * 0.85
    if not soft:
        x += bpf(RNG.uniform(-1, 1, n), 1000, 4000) * np.exp(-t * 300.0) * 0.3
    return x * vel


def d_snare(vel=1.0):
    n = int(0.2 * SR)
    t = np.arange(n) / SR
    x = bpf(RNG.uniform(-1, 1, n), 1400, 7500) * np.exp(-t * 24.0) + 0.5 * np.sin(2 * np.pi * (185 + 60 * np.exp(-t * 60)) * t) * np.exp(-t * 30.0)
    return x * vel


def d_rim(vel=1.0):
    n = int(0.06 * SR)
    t = np.arange(n) / SR
    return (np.sin(2 * np.pi * 1700 * t) * 0.6 + bpf(RNG.uniform(-1, 1, n), 800, 3500)) * np.exp(-t * 90.0) * vel


def d_hat(vel=1.0, open_=False):
    n = int((0.25 if open_ else 0.06) * SR)
    t = np.arange(n) / SR
    return hpf(RNG.uniform(-1, 1, n), 7000) * np.exp(-t * (14.0 if open_ else 70.0)) * vel * 1.5


def d_shaker(vel=1.0):
    n = int(0.09 * SR)
    return bpf(RNG.uniform(-1, 1, n), 4000, 11000) * np.hanning(n) ** 1.5 * vel * 1.5


def d_tamb(vel=1.0):
    n = int(0.16 * SR)
    t = np.arange(n) / SR
    x = hpf(RNG.uniform(-1, 1, n), 5500) * np.exp(-t * 30.0)
    for f in (6100.0, 7350.0, 8800.0):
        x += 0.15 * np.sin(2 * np.pi * f * t) * np.exp(-t * 35.0)
    return x * vel


def d_crash(vel=1.0):
    n = int(1.8 * SR)
    t = np.arange(n) / SR
    return bpf(RNG.uniform(-1, 1, n), 3000, 11000) * np.exp(-t * 3.2) * (1 - np.exp(-t * 200.0)) * vel


def d_timp(f, vel=1.0):
    n = int(0.9 * SR)
    t = np.arange(n) / SR
    x = np.sin(2 * np.pi * f * (1 + 0.08 * np.exp(-t * 30.0)) * t) * np.exp(-t * 4.5) + 0.3 * np.sin(2 * np.pi * f * 1.5 * t) * np.exp(-t * 9.0)
    x += lpf(RNG.uniform(-1, 1, n), 600) * np.exp(-t * 40.0) * 0.5
    return x * vel


def d_tri(vel=1.0):
    n = int(1.2 * SR)
    t = np.arange(n) / SR
    return (np.sin(2 * np.pi * 2950 * t) + 0.5 * np.sin(2 * np.pi * 5320 * t) + 0.3 * np.sin(2 * np.pi * 7700 * t)) * np.exp(-t * 4.5) * vel


def d_block(vel=1.0, f=1150.0):
    n = int(0.08 * SR)
    t = np.arange(n) / SR
    return np.sin(2 * np.pi * f * t) * np.exp(-t * 60.0) * vel


# ------------------------------------------------------------------ Mischpult
class Mix:
    def __init__(self, bpm, bars, beats_per_bar=4, tail=4.0):
        self.bpm = bpm
        self.spb = 60.0 / bpm
        self.bpb = beats_per_bar
        self.n = int((bars * beats_per_bar * self.spb + tail) * SR)
        self.dry = np.zeros((self.n, 2))
        self.wet = np.zeros((self.n, 2))
        self.end_beat = bars * beats_per_bar

    def sec(self, beat):
        return beat * self.spb

    def put(self, sig, beat, gain=1.0, pan=0.0, send=0.2):
        i = int(self.sec(beat) * SR)
        if i >= self.n:
            return
        sig = sig[: self.n - i]
        l = np.cos((pan + 1) * np.pi / 4) * gain
        r = np.sin((pan + 1) * np.pi / 4) * gain
        self.dry[i:i + len(sig), 0] += sig * l
        self.dry[i:i + len(sig), 1] += sig * r
        if send > 0:
            self.wet[i:i + len(sig), 0] += sig * l * send
            self.wet[i:i + len(sig), 1] += sig * r * send

    def note(self, inst, m, beat, beats, gain=1.0, pan=0.0, send=0.2, gate=0.95, vel=1.0):
        self.put(inst(hz(m), beats * self.spb * gate, vel), beat, gain, pan, send)

    def melody(self, inst, mel, beat0, gain=1.0, pan=0.0, send=0.25, gate=0.93, transpose=0):
        b = beat0
        for m, d in parse(mel):
            if m is not None:
                v = 1.0 + RNG.uniform(-0.06, 0.06) + (0.06 if abs((b - beat0) % self.bpb) < 0.01 else 0.0)
                self.note(inst, m + transpose, b, d, gain, pan, send, gate, v)
            b += d
        return b

    def render(self, rt=1.5):
        # Hall: abklingendes Rauschen, links und rechts verschieden
        n = int(rt * 1.3 * SR)
        t = np.arange(n) / SR
        out = self.dry.copy()
        for ch in range(2):
            ir = RNG.normal(0, 1, n) * np.exp(-t * 6.9 / rt)
            ir[: int(0.012 * SR)] = 0.0
            ir = hpf(lpf(ir, 5200), 280)
            ir /= np.sqrt(np.sum(ir ** 2))
            out[:, ch] += sg.fftconvolve(self.wet[:, ch], ir)[: self.n] * 0.9
        return out


# ------------------------------------------------------------------ Stück 1: Meadow March
def meadow_march():
    bars = 64
    M = Mix(114.0, bars, 4, tail=3.6)
    A_CH = ["C", "G/B", "Am", "F", "C", "F", "G", "G"]
    A2_CH = ["C", "G/B", "Am", "F", "Dm", "G", "C", "C"]
    B_CH = ["F", "C/E", "Dm", "G", "F", "C/E", "D7", "G"]
    C_CH = ["Am", "Em", "F", "C", "Am", "Em", "F", "G"]
    A_MEL = ("G4:.5 C5:.5 E5:1 E5:.5 D5:.5 C5:1 | D5:1 B4:.5 G4:.5 D5:1.5 r:.5 | A4:.5 C5:.5 E5:1 E5:.5 F5:.5 E5:1 | D5:.5 C5:.5 A4:1 C5:1.5 r:.5 | "
             "G4:.5 C5:.5 E5:1 G5:1.5 E5:.5 | A5:1 G5:.5 F5:.5 A5:1 F5:1 | G5:1 D5:.5 B4:.5 D5:1 G5:1 | F5:.5 E5:.5 D5:.5 B4:.5 D5:1.5 r:.5")
    A2_MEL = ("G4:.5 C5:.5 E5:1 E5:.5 D5:.5 C5:1 | D5:1 B4:.5 G4:.5 D5:1.5 r:.5 | A4:.5 C5:.5 E5:1 E5:.5 F5:.5 E5:1 | D5:.5 C5:.5 A4:1 C5:1.5 r:.5 | "
              "F5:1 D5:.5 F5:.5 A5:1.5 F5:.5 | G5:.5 A5:.5 B5:1 G5:1 D5:1 | C6:1.5 G5:.5 E5:1 G5:1 | C6:2 r:2")
    B_MEL = ("A5:2 F5:1 A5:1 | G5:2 E5:1 C5:1 | F5:1.5 E5:.5 D5:1 F5:1 | E5:.5 D5:.5 B4:1 D5:2 | "
             "A5:2 C6:1 A5:1 | G5:2 E5:1 G5:1 | F#5:1 A5:1 D6:1.5 C6:.5 | B5:2 G5:1 A5:.5 B5:.5")
    C_MEL = ("E5:1 A5:1 C6:2 | B5:1 G5:1 E5:2 | F5:1 A5:1 C6:1.5 A5:.5 | G5:3 E5:1 | "
             "E5:.5 A5:.5 C6:1 E6:2 | D6:1 B5:1 G5:2 | A5:1 G5:.5 F5:.5 A5:1 C6:1 | D6:2 B5:1 G5:1")
    # Gegenstimme (lange Töne, eine Terz/Sexte unter der Melodie)
    A_CNT = "E4:2 G4:2 | G4:2 B4:2 | C5:2 A4:2 | A4:2 F4:2 | E4:2 G4:2 | F4:2 A4:2 | B4:2 D5:2 | D5:2 B4:2"
    A2_CNT = "E4:2 G4:2 | G4:2 B4:2 | C5:2 A4:2 | A4:2 F4:2 | A4:2 D5:2 | D5:2 B4:2 | E5:2 C5:2 | E5:2 r:2"
    B_CNT = "C5:4 | C5:4 | A4:4 | B4:4 | C5:4 | C5:4 | A4:2 D5:2 | D5:4"

    def comp(bar0, chords, level=1.0, pah=True, arp=0.5, pad=0.5, bass=1.0):
        for i, ch in enumerate(chords):
            b = (bar0 + i) * 4
            root = bass_note(ch, 2)
            tones = voicing(ch, 62)
            if pad > 0:
                for m in voicing(ch, 58):
                    M.note(i_pad, m, b, 4, 0.16 * pad, RNG.uniform(-0.5, 0.5), 0.35, 1.0)
            if bass > 0:
                fifth = root + 7 if root + 7 <= 50 else root - 5
                M.note(i_bass, root, b, 1.0, 0.5 * bass, 0.0, 0.05, 0.85)
                M.note(i_bass, fifth, b + 2, 1.0, 0.44 * bass, 0.0, 0.05, 0.85)
                if i % 4 == 3:                                      # Übergang
                    M.note(i_bass, root + 2, b + 3.5, 0.5, 0.36 * bass, 0.0, 0.05, 0.8)
            if pah:
                for off in (1, 3):
                    for m in tones:
                        M.note(i_stab, m, b + off, 0.5, 0.11 * level, -0.25, 0.2)
            if arp > 0:
                seqn = [tones[0], tones[1], tones[2], tones[1] + 12, tones[2], tones[1], tones[0] + 12, tones[2]]
                for k, m in enumerate(seqn):
                    M.note(i_pluck, m + 12, b + k * 0.5, 0.5, 0.12 * arp * (1.1 if k % 2 == 0 else 0.85), 0.42, 0.3)

    def drums(bar0, n, kind="march", fill_last=True, crash=True):
        for i in range(n):
            b = (bar0 + i) * 4
            last = fill_last and i == n - 1
            if crash and i == 0:
                M.put(d_crash(), b, 0.11, 0.2, 0.4)
            if kind == "march":
                M.put(d_kick(), b, 0.5, 0, 0.05)
                M.put(d_kick(0.9), b + 2, 0.46, 0, 0.05)
                if not last:
                    M.put(d_snare(), b + 1, 0.2, -0.1, 0.25)
                    M.put(d_snare(), b + 3, 0.2, -0.1, 0.25)
                    M.put(d_snare(0.5), b + 3.5, 0.13, -0.1, 0.25)
                    M.put(d_snare(0.35), b + 0.75, 0.1, -0.1, 0.25)
                else:                                               # Wirbel in den nächsten Teil
                    M.put(d_snare(), b + 1, 0.2, -0.1, 0.25)
                    for k in range(8):
                        M.put(d_snare(0.4 + 0.08 * k), b + 2 + k * 0.25, 0.15 + 0.012 * k, -0.1, 0.25)
                for k in range(8):
                    M.put(d_hat(1.0 if k % 2 == 0 else 0.6), b + k * 0.5, 0.055, 0.35, 0.1)
            elif kind == "light":
                M.put(d_kick(0.9, True), b, 0.42, 0, 0.05)
                M.put(d_kick(0.8, True), b + 2.5, 0.3, 0, 0.05)
                M.put(d_rim(), b + 1, 0.12, -0.15, 0.3)
                M.put(d_rim(), b + 3, 0.12, -0.15, 0.3)
                for k in range(8):
                    M.put(d_shaker(1.0 if k % 2 == 0 else 0.7), b + k * 0.5, 0.05, 0.35, 0.1)
                if last:
                    for k in range(6):
                        M.put(d_snare(0.3 + 0.1 * k), b + 2.5 + k * 0.25, 0.12 + 0.012 * k, -0.1, 0.25)
            elif kind == "soft":
                M.put(d_kick(0.8, True), b, 0.36, 0, 0.05)
                for k in range(4):
                    M.put(d_hat(0.7), b + k + 0.5, 0.04, 0.35, 0.1)
                M.put(d_block(), b + 1.5, 0.05, 0.3, 0.3)
                M.put(d_block(1.0, 900.0), b + 3, 0.05, 0.3, 0.3)
                if last:
                    for k in range(8):
                        M.put(d_snare(0.3 + 0.09 * k), b + 2 + k * 0.25, 0.1 + 0.014 * k, -0.1, 0.25)
            if kind == "march" and i % 2 == 1:
                M.put(d_tamb(), b + 1.5, 0.05, 0.4, 0.2)
                M.put(d_tamb(), b + 3.5, 0.05, 0.4, 0.2)

    # --- Vorspiel (4 Takte): Fläche, Zupfer, dann kleines Glockenmotiv und Wirbel
    comp(0, ["C", "C"], pah=False, arp=0.7, pad=0.9, bass=0.0)
    comp(2, ["F", "G"], pah=False, arp=0.9, pad=0.9, bass=0.8)
    M.melody(i_glock, "F5:1 A5:1 C6:2 | D6:1.5 B5:.5 G5:2", 8, 0.2, 0.25, 0.4)
    for k in range(8):
        M.put(d_hat(0.8), 8 + k, 0.045, 0.35, 0.1)
    for k in range(8):
        M.put(d_snare(0.3 + 0.09 * k), 14 + k * 0.25, 0.1 + 0.014 * k, -0.1, 0.25)
    M.put(d_tri(), 0, 0.05, 0.4, 0.5)
    # --- A1
    bar = 4
    comp(bar, A_CH, arp=0.55, pad=0.4)
    drums(bar, 8)
    M.melody(i_lead, A_MEL, bar * 4, 0.3, 0.0, 0.22)
    # --- A2: Glockenspiel verdoppelt
    bar = 12
    comp(bar, A2_CH, arp=0.6, pad=0.45)
    drums(bar, 8)
    M.melody(i_lead, A2_MEL, bar * 4, 0.3, 0.0, 0.22)
    M.melody(i_glock, A2_MEL, bar * 4, 0.12, 0.3, 0.4, transpose=12)
    M.put(d_timp(hz(midi("C2"))), (bar + 7) * 4, 0.3, -0.2, 0.3)
    # --- B1: gesanglich, Flöte
    bar = 20
    comp(bar, B_CH, pah=False, arp=0.95, pad=0.7)
    drums(bar, 8, "light")
    M.melody(i_flute, B_MEL, bar * 4, 0.3, -0.15, 0.35, 0.98)
    M.melody(i_lead, B_MEL, bar * 4, 0.1, 0.15, 0.3, transpose=-12)
    # --- A3: Trompete führt, Flöte spielt Gegenstimme
    bar = 28
    comp(bar, A_CH, arp=0.6, pad=0.45)
    drums(bar, 8)
    M.melody(i_trumpet, A_MEL, bar * 4, 0.3, 0.05, 0.25)
    M.melody(i_lead, A_MEL, bar * 4, 0.12, -0.1, 0.2)
    M.melody(i_flute, A_CNT, bar * 4, 0.13, -0.35, 0.35, 0.98, transpose=12)
    # --- C: ruhige Brücke in a-Moll
    bar = 36
    comp(bar, C_CH, pah=False, arp=1.0, pad=0.9, bass=0.85)
    drums(bar, 8, "soft", crash=False)
    M.melody(i_musicbox, C_MEL, bar * 4, 0.26, 0.2, 0.45)
    M.melody(i_flute, "E5:.5 A5:.5 C6:1 E6:2 | D6:1 B5:1 G5:2 | A5:1 G5:.5 F5:.5 A5:1 C6:1 | D6:2 B5:1 G5:1", (bar + 4) * 4, 0.16, -0.2, 0.4, 0.98, transpose=-12)
    M.put(d_tri(), bar * 4, 0.06, 0.4, 0.5)
    # --- B2: voller, mit Gegenstimme
    bar = 44
    comp(bar, B_CH, pah=True, arp=0.9, pad=0.7)
    drums(bar, 8, "march")
    M.melody(i_flute, B_MEL, bar * 4, 0.26, -0.15, 0.35, 0.98)
    M.melody(i_lead, B_MEL, bar * 4, 0.2, 0.1, 0.25)
    M.melody(i_trumpet, B_CNT, bar * 4, 0.1, 0.3, 0.35, 0.98)
    # --- A4: Schluss-Strophe mit allem
    bar = 52
    comp(bar, A2_CH, arp=0.7, pad=0.5)
    drums(bar, 8, fill_last=False)
    M.melody(i_trumpet, A2_MEL, bar * 4, 0.26, 0.05, 0.25)
    M.melody(i_lead, A2_MEL, bar * 4, 0.2, -0.1, 0.2)
    M.melody(i_glock, A2_MEL, bar * 4, 0.12, 0.3, 0.4, transpose=12)
    M.melody(i_flute, A2_CNT, bar * 4, 0.13, -0.35, 0.35, 0.98, transpose=12)
    for k in range(8):
        M.put(d_snare(0.4 + 0.08 * k), (bar + 7) * 4 + 2 + k * 0.25, 0.14 + 0.012 * k, -0.1, 0.25)
    # --- Ausklang (4 Takte): F | G | C … der Schlussakkord klingt lange aus (hier setzt die Überblendung an)
    bar = 60
    comp(bar, ["F", "G"], arp=0.8, pad=0.7)
    drums(bar, 2, fill_last=True)
    M.melody(i_trumpet, "A5:1 C6:1 F5:1 A5:1 | G5:1 B5:1 D6:1.5 B5:.5", bar * 4, 0.26, 0.05, 0.25)
    M.melody(i_glock, "A5:1 C6:1 F5:1 A5:1 | G5:1 B5:1 D6:1.5 B5:.5", bar * 4, 0.12, 0.3, 0.4, transpose=12)
    b = (bar + 2) * 4
    M.put(d_crash(), b, 0.16, 0.2, 0.5)
    M.put(d_timp(hz(midi("C2"))), b, 0.4, -0.2, 0.35)
    M.put(d_kick(), b, 0.5, 0, 0.05)
    for m in [midi("C3"), midi("G3"), midi("C4"), midi("E4"), midi("G4")]:
        M.note(i_pad, m, b, 9, 0.2, RNG.uniform(-0.5, 0.5), 0.4, 1.0)
    M.note(i_bass, midi("C2"), b, 6, 0.45, 0, 0.1)
    M.note(i_trumpet, midi("C6"), b, 5, 0.22, 0.05, 0.4)
    M.note(i_trumpet, midi("G5"), b, 5, 0.14, -0.2, 0.4)
    M.note(i_trumpet, midi("E5"), b, 5, 0.14, 0.25, 0.4)
    for k, n in enumerate(["C5", "E5", "G5", "C6", "E6", "G6", "C7"]):
        M.note(i_glock, midi(n), b + 0.5 + k * 0.5, 2, 0.12, 0.3, 0.5)
    M.put(d_tri(), b + 4, 0.06, 0.4, 0.6)
    return M, "meadow_march", -15.6


# ------------------------------------------------------------------ Stück 2: Evening at the Base
def evening_base():
    bars = 38
    M = Mix(76.0, bars, 4, tail=4.5)
    A_CH = ["F", "Am", "Bb", "C", "Dm", "Bb", "Gm", "C"]
    A2_CH = ["F", "Am", "Bb", "C", "Dm", "Bb", "C7", "F"]
    B_CH = ["Dm", "C", "Bb", "F/A", "Gm", "Dm", "Bb", "C"]
    A_MEL = ("C5:1 F5:1 A5:1.5 G5:.5 | G5:.5 A5:.5 E5:1 C5:2 | D5:1 F5:1 Bb5:1.5 A5:.5 | G5:2 E5:1 C5:.5 E5:.5 | "
             "F5:1 A5:1 D6:1.5 C6:.5 | Bb5:1 A5:.5 G5:.5 F5:2 | D5:1 G5:1 Bb5:1.5 A5:.5 | G5:3 r:1")
    A2_MEL = ("C5:1 F5:1 A5:1.5 G5:.5 | G5:.5 A5:.5 E5:1 C5:2 | D5:1 F5:1 Bb5:1.5 A5:.5 | G5:2 E5:1 C5:.5 E5:.5 | "
              "F5:1 A5:1 D6:1.5 C6:.5 | Bb5:1 A5:.5 G5:.5 F5:2 | E5:1 G5:1 Bb5:1 A5:.5 G5:.5 | F5:3 r:1")
    B_MEL = ("D5:1 F5:1 A5:2 | G5:1.5 E5:.5 C5:2 | Bb4:1 D5:1 F5:2 | A5:1 G5:.5 F5:.5 C5:2 | "
             "Bb5:1 A5:1 G5:1 D5:1 | F5:1.5 E5:.5 D5:2 | D5:.5 F5:.5 Bb5:1 D6:2 | C6:1 Bb5:.5 A5:.5 G5:1 E5:1")
    A2_LOW = "A4:2 C5:2 | C5:2 A4:2 | Bb4:2 D5:2 | E5:2 C5:2 | D5:2 F5:2 | D5:2 Bb4:2 | C5:2 E5:2 | C5:3 r:1"

    def comp(bar0, chords, harp=1.0, pad=1.0, bass=1.0):
        for i, ch in enumerate(chords):
            b = (bar0 + i) * 4
            root = bass_note(ch, 2)
            if pad > 0:
                for m in voicing(ch, 57):
                    M.note(i_pad, m, b, 4, 0.16 * pad, RNG.uniform(-0.6, 0.6), 0.45, 1.0)
            if bass > 0:
                M.note(i_bass, root, b, 2.4, 0.42 * bass, 0, 0.05, 0.9)
                M.note(i_bass, root + (7 if root + 7 <= 50 else -5), b + 2.5, 1.2, 0.3 * bass, 0, 0.05, 0.9)
            if harp > 0:
                t = voicing(ch, 60)
                seqn = [t[0] - 12, t[2] - 12, t[0], t[1], t[2], t[1], t[0] + 12, t[2]]
                for k, m in enumerate(seqn):
                    M.note(i_pluck, m + 12, b + k * 0.5, 0.5, 0.15 * harp * (1.1 if k % 4 == 0 else 0.85), -0.4 + 0.1 * (k % 3), 0.4, 1.0, 1.0 + RNG.uniform(-0.08, 0.08))

    def perc(bar0, n, level=1.0, rim=True):
        for i in range(n):
            b = (bar0 + i) * 4
            M.put(d_kick(0.8, True), b, 0.34 * level, 0, 0.05)
            M.put(d_kick(0.6, True), b + 2.5, 0.2 * level, 0, 0.05)
            if rim:
                M.put(d_rim(0.8), b + 2, 0.08 * level, -0.2, 0.4)
            for k in range(8):
                M.put(d_shaker(1.0 if k % 2 == 0 else 0.6), b + k * 0.5, 0.03 * level, 0.4, 0.15)
            if i % 4 == 0:
                M.put(d_tri(), b, 0.035, 0.45, 0.6)

    # --- Vorspiel (2 Takte): nur Fläche und Harfe
    comp(0, ["F", "C"], harp=0.8, pad=1.0, bass=0.0)
    M.put(d_tri(), 0, 0.04, 0.45, 0.6)
    # --- A1: Spieluhr
    bar = 2
    comp(bar, A_CH, harp=0.9, pad=0.9, bass=0.9)
    perc(bar, 8, 0.6, rim=False)
    M.melody(i_musicbox, A_MEL, bar * 4, 0.3, 0.1, 0.45)
    # --- A2: Flöte übernimmt, Spieluhr eine Oktave höher dazu
    bar = 10
    comp(bar, A2_CH)
    perc(bar, 8, 1.0)
    M.melody(i_flute, A2_MEL, bar * 4, 0.3, -0.1, 0.4, 0.98)
    M.melody(i_musicbox, A2_MEL, bar * 4, 0.12, 0.3, 0.5, transpose=12)
    M.melody(i_lead, A2_LOW, bar * 4, 0.06, 0.25, 0.4, 0.98)
    # --- B: nachdenklicher Mittelteil
    bar = 18
    comp(bar, B_CH, harp=1.0, pad=1.1)
    perc(bar, 8, 0.8)
    M.melody(i_lead, B_MEL, bar * 4, 0.2, 0.0, 0.4, 0.97)
    M.melody(i_flute, B_MEL, bar * 4, 0.16, -0.2, 0.4, 0.98, transpose=-12)
    M.melody(i_glock, "r:2 A5:1 D6:1 | r:2 G5:1 C6:1 | r:2 F5:1 Bb5:1 | r:3 C6:1 | r:2 D6:1 G6:1 | r:2 A5:1 D6:1 | r:4 | r:3 E6:1", bar * 4, 0.07, 0.4, 0.6)
    # --- A3: alles zusammen, warm
    bar = 26
    comp(bar, A2_CH, harp=1.0, pad=1.0)
    perc(bar, 8, 1.0)
    M.melody(i_flute, A2_MEL, bar * 4, 0.26, -0.1, 0.4, 0.98)
    M.melody(i_musicbox, A2_MEL, bar * 4, 0.2, 0.2, 0.5)
    M.melody(i_lead, A2_LOW, bar * 4, 0.08, 0.3, 0.4, 0.98)
    # --- Ausklang (4 Takte): Bb | C | F … langer Schlussakkord
    bar = 34
    comp(bar, ["Bb", "C"], harp=0.9, pad=1.0)
    perc(bar, 2, 0.6, rim=False)
    M.melody(i_musicbox, "D5:1 F5:1 Bb5:2 | C5:1 E5:1 G5:1 Bb5:1", bar * 4, 0.26, 0.15, 0.5)
    b = (bar + 2) * 4
    for m in [midi("F2"), midi("C3"), midi("F3"), midi("A3"), midi("C4"), midi("G4")]:
        M.note(i_pad, m, b, 9, 0.2, RNG.uniform(-0.6, 0.6), 0.5, 1.0)
    M.note(i_bass, midi("F2"), b, 5, 0.4, 0, 0.1)
    M.note(i_flute, midi("A5"), b, 4, 0.2, -0.1, 0.5)
    for k, n in enumerate(["F4", "A4", "C5", "F5", "A5", "C6", "F6"]):
        M.note(i_pluck, midi(n), b + k * 0.5, 2, 0.16, -0.3 + 0.1 * k, 0.5)
    M.note(i_musicbox, midi("F6"), b + 4, 2, 0.16, 0.2, 0.6)
    M.note(i_musicbox, midi("C7"), b + 5, 2, 0.1, 0.3, 0.6)
    M.put(d_tri(), b, 0.05, 0.45, 0.7)
    return M, "evening_base", -16.6


# ------------------------------------------------------------------ Abmischung
def measure(path):
    r = subprocess.run(["ffmpeg", "-hide_banner", "-nostats", "-i", path, "-af", "ebur128=peak=true", "-f", "null", "-"], capture_output=True, text=True).stderr
    tail = r[r.rfind("Summary:"):]
    i = float(re.search(r"I:\s+(-?[\d.]+) LUFS", tail).group(1))
    pk = float(re.search(r"Peak:\s+(-?[\d.]+) dBFS", tail).group(1))
    lra = float(re.search(r"LRA:\s+(-?[\d.]+) LU", tail).group(1))
    return i, pk, lra


def limiter(x, ceil_db=-2.0, look=0.004, rel=0.12):
    """Vorausschauender Begrenzer (beide Kanäle gemeinsam)."""
    c = 10 ** (ceil_db / 20)
    pk = np.max(np.abs(x), axis=1)
    n = int(look * SR)
    from scipy.ndimage import maximum_filter1d, uniform_filter1d
    env = maximum_filter1d(pk, size=2 * n + 1)
    g = np.minimum(1.0, c / np.maximum(env, 1e-9))
    # weiches Loslassen
    a = np.exp(-1.0 / (rel * SR))
    out = np.empty_like(g)
    cur = 1.0
    for i in range(len(g)):                 # einfache Schleife, läuft nur einmal je Stück
        cur = g[i] if g[i] < cur else a * cur + (1 - a) * g[i]
        out[i] = cur
    out = np.minimum(uniform_filter1d(out, size=n), g)
    return x * out[:, None]


def master(M, name, target):
    x = M.render()
    x = sg.sosfilt(sg.butter(2, 32, "high", fs=SR, output="sos"), x, axis=0)
    # etwas Glanz, damit es neben dem Lied nicht dumpf wirkt
    x = x + 0.45 * sg.sosfilt(sg.butter(1, 5000, "high", fs=SR, output="sos"), x, axis=0)
    fo = int(0.4 * SR)
    x[-fo:] *= np.linspace(1, 0, fo)[:, None] ** 2
    x[:64] *= np.linspace(0, 1, 64)[:, None]
    tmp = os.path.join(tempfile.gettempdir(), name + "_m.wav")
    x = x / np.max(np.abs(x)) * 0.5
    for it in range(3):
        wavfile.write(tmp, SR, (np.clip(x, -1, 1) * 32767).astype(np.int16))
        i, pk, lra = measure(tmp)
        x = limiter(x * 10 ** ((target - i) / 20), -2.2)
    wavfile.write(tmp, SR, (np.clip(x, -1, 1) * 32767).astype(np.int16))
    os.makedirs(OUT, exist_ok=True)
    ogg = os.path.join(OUT, name + ".ogg")
    subprocess.run(["ffmpeg", "-hide_banner", "-loglevel", "error", "-y", "-i", tmp, "-c:a", "libvorbis", "-q:a", "5", "-map_metadata", "-1", ogg], check=True)
    i, pk, lra = measure(ogg)
    # musikalisches Ende = Beginn der Ausblendung des Schlussakkords
    print("%s: %.1f s, %.1f LUFS, Spitze %.1f dBFS, LRA %.1f, %d kB" % (name, len(x) / SR, i, pk, lra, os.path.getsize(ogg) // 1024))
    os.remove(tmp)


if __name__ == "__main__":
    which = sys.argv[1] if len(sys.argv) > 1 else ""
    for fn in (meadow_march, evening_base):
        if which in fn.__name__:
            master(*fn())
