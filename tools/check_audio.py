#!/usr/bin/env python3
"""Ton-Prüfung ohne Ohren: misst alle Klänge in audio/sfx (WAV und OGG) und die Musik in audio/music.

Je Klang: Länge, Spitze (dBFS), übersteuerte Abtastwerte, Kurzzeit-Lautheit (wie tools/make_sfx.py: größte
gehörrichtig gewichtete Lautheit in 80-ms-Fenstern), Stille am Anfang und Ende, Gleichanteil, bei Schleifen der
Sprung an der Nahtstelle. Die Klänge werden in Gruppen eingeteilt (Oberfläche, Waffen, Einschläge, Gegner, Umgebung,
Stimmen …); je Gruppe gibt es einen Zielwert (GROUP_TARGET, dieselbe Tabelle nutzt make_sfx.py) und eine erlaubte
Abweichung. Ausreißer werden aufgelistet; mit --fix werden sie mit make_sfx.py neu erzeugt.

Aufruf:  python3 tools/check_audio.py            (Bericht)
         python3 tools/check_audio.py --fix      (Ausreißer neu erzeugen und erneut prüfen)
         python3 tools/check_audio.py --music    (zusätzlich die Musikstücke: Lautheit EBU R128, Spitze, Länge)
Rückgabewert 0 = alles im Rahmen, 1 = es gibt Ausreißer oder Fehler."""
import os, sys, glob, re, subprocess
import numpy as np
from scipy import signal as sg

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
SFX = os.path.join(ROOT, "audio", "sfx")
MUSIC = os.path.join(ROOT, "audio", "music")
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

# Gruppen: (Name, Präfixe, Zielwert in dB, erlaubte Abweichung in dB). Reihenfolge = Vorrang.
GROUPS = [
    ("Stimmen", ("v_",), -15.0, 3.5),
    ("Umgebung", ("amb_", "ev_amb"), -19.0, 3.5),
    ("Oberfläche", ("click", "ui_", "pay", "error", "chest", "level_up", "hero_level_up", "hero_unlock", "quest_", "coin", "gem", "toast", "build",
                    "journal", "tool_", "quest", "wish", "egg_"), -16.0, 4.0),
    ("Waffen", ("w_", "t_", "shot", "reload", "empty", "flame", "water_loop", "sk_", "skill"), -14.5, 4.5),
    ("Einschläge", ("explosion", "boom", "impact", "ice_shatter", "splash", "glue", "wall_", "struct_", "hit_", "node_", "tree_fall", "crit"), -14.0, 4.5),
    ("Gegner", ("e_", "slime", "boss", "enemy", "spit", "elite", "nest"), -15.0, 4.5),
    ("Ereignisse", ("ev_", "flood", "raid", "siege", "dusk", "outpost", "zentrale", "barrier", "extract", "win", "lose", "rescue", "trade", "caravan",
                    "landmark", "meteor", "avalanche"), -14.5, 4.5),
    ("Begleiter", ("comp_",), -15.5, 4.0),
    ("Held", ("step_", "hop", "dash", "hurt", "hero_", "respawn", "heartbeat", "veh_", "engine"), -16.0, 4.5),
    ("Sonstiges", ("",), -15.5, 5.0),
]
GROUP_TARGET = {g[0]: g[2] for g in GROUPS}


def group_of(name):
    for g in GROUPS:
        for pre in g[1]:
            if name.startswith(pre):
                return g
    return GROUPS[-1]


def hp(x, fc, order, sr):
    return sg.sosfilt(sg.butter(order, fc, "high", fs=sr, output="sos"), x)


def loud(x, sr):
    """Wie make_sfx.loud(): größte Kurzzeit-Lautheit, grob gehörrichtig gewichtet (dB)."""
    y = hp(x, 120.0, 2, sr)
    y = y + 0.6 * hp(y, 1800.0, 1, sr)
    w = int(0.08 * sr)
    if len(y) <= w:
        return 10 * np.log10(np.mean(y ** 2) * len(y) / w + 1e-12)
    p = np.convolve(y ** 2, np.ones(w) / w, "valid")
    return 10 * np.log10(p.max() + 1e-12)


def load(path):
    """Mono-Float und Abtastrate (WAV direkt, OGG über ffmpeg)."""
    if path.endswith(".wav"):
        from scipy.io import wavfile
        import warnings
        with warnings.catch_warnings():
            warnings.simplefilter("ignore")
            sr, x = wavfile.read(path)
        x = x.astype(np.float64)
        if x.ndim > 1:
            x = x.mean(axis=1)
        return x / 32768.0, sr
    pr = subprocess.run(["ffprobe", "-v", "error", "-show_entries", "stream=sample_rate", "-of", "csv=p=0", path], capture_output=True, text=True)
    sr = int(pr.stdout.strip().split("\n")[0] or 22050)
    r = subprocess.run(["ffmpeg", "-hide_banner", "-loglevel", "error", "-i", path, "-ac", "1", "-f", "f32le", "-"], capture_output=True)
    return np.frombuffer(r.stdout, dtype=np.float32).astype(np.float64), sr


def is_loop(name, path):
    if name.endswith("_loop") or name.startswith("amb_") or name.startswith("engine_") or name.startswith("ev_amb"):
        return True
    if path.endswith(".wav"):
        with open(path, "rb") as f:
            return b"smpl" in f.read()[-120:]
    return False


def measure(path):
    name = os.path.basename(path)[:-4]
    base = re.sub(r"_\d+$", "", name)
    x, sr = load(path)
    out = {"name": name, "base": base, "file": os.path.basename(path), "len": len(x) / max(sr, 1), "sr": sr, "problems": []}
    if len(x) == 0:
        out.update(peak=-99.0, loud=-99.0, clip=0, lead=0.0, trail=0.0, dc=0.0, seam=0.0, loop=False)
        out["problems"].append("leer")
        return out
    pk = np.max(np.abs(x))
    out["peak"] = 20 * np.log10(pk + 1e-12)
    out["clip"] = int(np.sum(np.abs(x) >= 0.999))
    out["loud"] = loud(x, sr)
    thr = pk * 0.02
    idx = np.nonzero(np.abs(x) > thr)[0]
    out["lead"] = idx[0] / sr if len(idx) else out["len"]
    out["trail"] = (len(x) - 1 - idx[-1]) / sr if len(idx) else out["len"]
    out["dc"] = float(np.mean(x))
    out["loop"] = is_loop(base, path)
    step = np.percentile(np.abs(np.diff(x)), 99.5) + 1e-9   # großer, aber im Klang üblicher Schritt zwischen zwei Abtastwerten
    out["seam"] = abs(x[-1] - x[0]) / step if out["loop"] else 0.0
    g = group_of(base)
    out["group"] = g[0]
    dev = out["loud"] - g[2]
    out["dev"] = dev
    if out["clip"] > 2:
        out["problems"].append("übersteuert (%d Werte)" % out["clip"])
    if pk < 10 ** (-40 / 20):
        out["problems"].append("fast stumm")
    if not out["loop"] and out["lead"] > 0.08:
        out["problems"].append("Stille am Anfang %.2f s" % out["lead"])
    if not out["loop"] and out["trail"] > 0.25:
        out["problems"].append("Stille am Ende %.2f s" % out["trail"])
    if out["len"] > 8.0 and not out["loop"]:
        out["problems"].append("sehr lang (%.1f s)" % out["len"])
    if abs(out["dc"]) > 0.02:
        out["problems"].append("Gleichanteil %.3f" % out["dc"])
    if out["loop"] and out["seam"] > 2.0:
        out["problems"].append("Schleife springt (%.1f × üblicher Schritt)" % out["seam"])
    if abs(dev) > g[3]:
        out["problems"].append("Lautheit %+.1f dB neben dem Gruppenziel %.0f" % (dev, g[2]))
    return out


def report(rows):
    bad = [r for r in rows if r["problems"]]
    print("%d Klangdateien, %d Namen geprüft" % (len(rows), len({r["base"] for r in rows})))
    print("%-12s %5s %7s %7s %6s %7s" % ("Gruppe", "Zahl", "Median", "Ziel", "Streu", "Größte"))
    for g in GROUPS:
        gr = [r for r in rows if r.get("group") == g[0]]
        if not gr:
            continue
        ls = np.array([r["loud"] for r in gr])
        print("%-12s %5d %7.1f %7.1f %6.1f %7.1f" % (g[0], len(gr), np.median(ls), g[2], np.std(ls), np.max(np.abs(ls - g[2]))))
    tot = sum(os.path.getsize(os.path.join(SFX, r["file"])) for r in rows)
    print("Größe: %.2f MB (WAV %d, OGG %d)" % (tot / 1e6, sum(1 for r in rows if r["file"].endswith(".wav")), sum(1 for r in rows if r["file"].endswith(".ogg"))))
    if bad:
        print("\nAusreißer / Auffälligkeiten (%d):" % len(bad))
        for r in sorted(bad, key=lambda r: r["name"]):
            print("  %-26s %-11s %5.2fs  laut %6.1f  Spitze %5.1f  %s" % (r["file"], r.get("group", "?"), r["len"], r["loud"], r["peak"], "; ".join(r["problems"])))
    else:
        print("\nKeine Ausreißer.")
    return bad


def check_music():
    print("\nMusik:")
    ok = True
    for p in sorted(glob.glob(os.path.join(MUSIC, "*.ogg")) + glob.glob(os.path.join(MUSIC, "*.mp3"))):
        r = subprocess.run(["ffmpeg", "-hide_banner", "-nostats", "-i", p, "-af", "ebur128=peak=true", "-f", "null", "-"], capture_output=True, text=True).stderr
        tail = r[r.rfind("Summary:"):]
        i = float(re.search(r"I:\s+(-?[\d.]+) LUFS", tail).group(1))
        pk = float(re.search(r"Peak:\s+(-?[\d.]+) dBFS", tail).group(1))
        d = float(re.search(r"Duration: (\d+):(\d+):([\d.]+)", r).group(2)) * 60 + float(re.search(r"Duration: (\d+):(\d+):([\d.]+)", r).group(3))
        flag = ""
        name = os.path.basename(p)
        stinger = name.startswith("win") or name.startswith("lose")
        if pk > 0.0:
            flag += " übersteuert"
        if not stinger and not name.endswith("_fight.ogg") and not (-19.0 <= i <= -14.0):
            flag += " Lautheit außerhalb -19..-14"
        if not stinger and d < 100.0:
            flag += " kürzer als 100 s"
        ok = ok and flag == ""
        print("  %-28s %6.1f s  %6.1f LUFS  Spitze %5.1f dBFS  %5d kB%s" % (name, d, i, pk, os.path.getsize(p) // 1024, flag))
    return ok


def main():
    files = sorted(glob.glob(os.path.join(SFX, "*.wav")) + glob.glob(os.path.join(SFX, "*.ogg")))
    rows = [measure(p) for p in files]
    bad = report(rows)
    if "--fix" in sys.argv and bad:
        names = sorted({r["base"] for r in bad})
        print("\nNeu erzeugen: %s" % ", ".join(names))
        for n in names:
            subprocess.run([sys.executable, os.path.join(ROOT, "tools", "make_sfx.py"), "^" + n + "$"], check=False)
        rows = [measure(p) for p in sorted(glob.glob(os.path.join(SFX, "*.wav")) + glob.glob(os.path.join(SFX, "*.ogg")))]
        bad = report(rows)
    ok = not bad
    if "--music" in sys.argv:
        ok = check_music() and ok
    sys.exit(0 if ok else 1)


if __name__ == "__main__":
    main()
