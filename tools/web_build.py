#!/usr/bin/env python3
"""Baut die Web-Version kleiner und sparsamer (Paket Q, Kapitel 3.2/12.2) – ohne die PC-/Handy-Fassung anzufassen.

Arbeitet in einer Kopie des Projekts (build/web_src) und ändert dort nur, was fürs Web gilt:
  1. Symbole (icons/**/*.png): verlustbehaftet als WebP importiert (Qualität 0,9 statt verlustfrei, ~4× kleiner).
     Animations-Texturen der Gegner (models/*_vat.png) bleiben verlustfrei – sie enthalten Positionen, keine Bilder.
  2. Modelle (models/*.glb): ohne eigene Schatten-Meshes (Godot legt sonst je Mesh eine zweite Fassung nur für den
     Schattenwurf an; im Browser zeichnet „Niedrig“ ohnehin keine Schatten). Gleiche Optik, ~30 % kleiner.
  3. Musik: neu kodiert mit geringerer Bitrate (OGG Vorbis Qualität 0 ≈ 40 kbit/s statt ~80, MP3 80 kbit/s statt 190).
  4. Import und Export „Web“ in der Kopie; Ergebnis nach build/web (oder --out).
Die Quell-Dateien des Projekts bleiben unverändert – am PC sieht und klingt alles wie vorher.

Aufruf:
  python3 tools/web_build.py --godot PFAD/Godot_v4.6.3-stable_linux.x86_64 [--out build/web] [--work build/web_src]
  python3 tools/web_build.py --prepare-only ...     # nur die Kopie vorbereiten (zum Prüfen)
Braucht ffmpeg (Musik). Ohne ffmpeg bleibt die Musik wie sie ist (Hinweis in der Ausgabe).
"""
import os
import re
import shutil
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SKIP_DIRS = {".git", "build", "blender", "docs", "server", "tools", "__pycache__", ".github"}
ICON_QUALITY = 0.9
MUSIC_OGG_Q = "0"
MUSIC_MP3_KBPS = "80k"


def copy_project(work):
    os.makedirs(work, exist_ok=True)
    # das Hauptprojekt soll die Kopie nie importieren
    gi = os.path.join(os.path.dirname(work), ".gdignore")
    if not os.path.exists(gi):
        open(gi, "w").close()
    for name in os.listdir(ROOT):
        if name in SKIP_DIRS:
            continue
        src = os.path.join(ROOT, name)
        dst = os.path.join(work, name)
        if name == ".godot":
            if not os.path.exists(dst):      # Import-Zwischenstand einmal übernehmen (spart Zeit), danach behalten
                shutil.copytree(src, dst, symlinks=True)
            continue
        if os.path.isdir(src):
            shutil.copytree(src, dst, dirs_exist_ok=True, symlinks=True)
        else:
            shutil.copy2(src, dst)


def set_params(imp_path, importer, typ, params):
    """Setzt Werte im Abschnitt [params] einer .import-Datei (legt sie an, falls es sie nicht gibt)."""
    if os.path.exists(imp_path):
        txt = open(imp_path, encoding="utf-8").read()
    else:
        txt = '[remap]\n\nimporter="%s"\ntype="%s"\n\n[params]\n' % (importer, typ)
    if "[params]" not in txt:
        txt += "\n[params]\n"
    head, body = txt.split("[params]", 1)
    for k, v in params.items():
        line = "%s=%s" % (k, v)
        if re.search(r"(?m)^%s=.*$" % re.escape(k), body):
            body = re.sub(r"(?m)^%s=.*$" % re.escape(k), line, body)
        else:
            body = body.rstrip("\n") + "\n" + line + "\n"
    open(imp_path, "w", encoding="utf-8").write(head + "[params]" + body)


def prep_icons(work):
    n = 0
    for dp, _dn, fn in os.walk(os.path.join(work, "icons")):
        for f in fn:
            if f.endswith(".png"):
                set_params(os.path.join(dp, f + ".import"), "texture", "CompressedTexture2D",
                           {"compress/mode": "1", "compress/lossy_quality": str(ICON_QUALITY), "mipmaps/generate": "false"})
                n += 1
    return n


def prep_models(work):
    n = 0
    md = os.path.join(work, "models")
    for f in os.listdir(md):
        if f.endswith(".glb"):
            set_params(os.path.join(md, f + ".import"), "scene", "PackedScene", {"meshes/create_shadow_meshes": "false"})
            n += 1
        elif f.endswith("_vat.png"):
            # ausdrücklich verlustfrei, falls jemand die Grundeinstellung für Texturen ändert
            set_params(os.path.join(md, f + ".import"), "texture", "CompressedTexture2D", {"compress/mode": "0"})
    return n


def prep_music(work):
    if shutil.which("ffmpeg") is None:
        print("Hinweis: ffmpeg fehlt – Musik bleibt in voller Qualität.")
        return 0
    md = os.path.join(work, "audio", "music")
    n = 0
    stamp = os.path.join(md, ".web_reduced")
    # Merker „name:größe“ – nur überspringen, wenn die Datei noch die verkleinerte Fassung ist
    # (copy_project kopiert bei jedem Lauf die Originale erneut in die Arbeitskopie)
    done = {}
    if os.path.exists(stamp):
        for tok in open(stamp).read().split():
            if ":" in tok:
                k, v = tok.rsplit(":", 1)
                done[k] = int(v) if v.isdigit() else -1
    for f in sorted(os.listdir(md)):
        p = os.path.join(md, f)
        if f.endswith(".import") or f.startswith("."):
            continue
        if done.get(f, -2) == os.path.getsize(p):
            continue
        tmp = p + ".tmp" + os.path.splitext(f)[1]
        if f.endswith(".ogg"):
            cmd = ["ffmpeg", "-v", "error", "-y", "-i", p, "-c:a", "libvorbis", "-q:a", MUSIC_OGG_Q, "-ar", "32000", tmp]
        elif f.endswith(".mp3"):
            cmd = ["ffmpeg", "-v", "error", "-y", "-i", p, "-c:a", "libmp3lame", "-b:a", MUSIC_MP3_KBPS, "-ar", "32000", tmp]
        else:
            continue
        if subprocess.run(cmd).returncode == 0 and os.path.exists(tmp) and os.path.getsize(tmp) < os.path.getsize(p):
            os.replace(tmp, p)
            n += 1
        elif os.path.exists(tmp):
            os.remove(tmp)
        done[f] = os.path.getsize(p)
    open(stamp, "w").write("\n".join("%s:%d" % (k, v) for k, v in sorted(done.items())))
    return n


def run(cmd, cwd):
    print("+", " ".join(cmd), flush=True)
    return subprocess.run(cmd, cwd=cwd).returncode


def main():
    a = sys.argv[1:]
    godot = a[a.index("--godot") + 1] if "--godot" in a else "godot"
    out = os.path.abspath(a[a.index("--out") + 1]) if "--out" in a else os.path.join(ROOT, "build", "web")
    work = os.path.abspath(a[a.index("--work") + 1]) if "--work" in a else os.path.join(ROOT, "build", "web_src")
    copy_project(work)
    print("Symbole verlustbehaftet:", prep_icons(work))
    print("Modelle ohne Schatten-Meshes:", prep_models(work))
    print("Musikstücke neu kodiert:", prep_music(work))
    if "--prepare-only" in a:
        return
    run([godot, "--headless", "--path", work, "--import"], work)
    os.makedirs(out, exist_ok=True)
    rc = run([godot, "--headless", "--path", work, "--export-release", "Web", os.path.join(out, "index.html")], work)
    pck = os.path.join(out, "index.pck")
    if rc != 0 or not os.path.exists(pck):
        print("FEHLER: Export fehlgeschlagen")
        sys.exit(1)
    print("index.pck: %.1f MB" % (os.path.getsize(pck) / 1048576.0))


if __name__ == "__main__":
    main()
