#!/usr/bin/env python3
"""Store-Material (Paket Q, Kapitel 7.4): Bildschirmfotos in den Store-Formaten und ein Vorschau-Video, Deutsch und Englisch.

Alles wird aus dem Spiel selbst gerendert (Linux mit xvfb-run, OpenGL):
  Bilder:  --autotest=storeshot --motif=<motiv> (src/tests_qualitaet.gd) in vier Seitenverhältnissen, danach mit
           Überschrift (Schrift fonts/fredoka.ttf) auf die genauen Store-Größen gebracht.
  Video:   --autotest=trailer mit --write-movie (feste 30 Bilder/s, 1920×1080), danach mit ffmpeg kodiert (H.264) und
           mit Texteinblendungen je Sprache versehen.

Aufruf:
  python3 tools/store_material.py --godot PFAD/Godot [--only shots|compose|video] [--langs de,en] [--motifs basis,flut]
Ergebnis: docs/store/screenshots/<sprache>/<format>/NN_<motiv>.jpg (JPEG 92, von App Store und Google Play angenommen) und docs/store/video/rustwall_vorschau_<sprache>.mp4
Rohbilder liegen in build/store_raw (nicht im Repository).
"""
import os
import shutil
import subprocess
import sys

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RAW = os.path.join(ROOT, "build", "store_raw")
OUT = os.path.join(ROOT, "docs", "store", "screenshots")
VID = os.path.join(ROOT, "docs", "store", "video")
FONT = os.path.join(ROOT, "fonts", "fredoka.ttf")

# Motiv: Spiel-Argumente und Überschrift je Sprache
MOTIFS = [
    ("basis", ["--setup=8"], {"de": "Baue deine Festung", "en": "Build your stronghold"}),
    ("flut", ["--setup=5", "--week=12", "--crowd=35"], {"de": "Halte die Schleimflut auf", "en": "Hold back the slime flood"}),
    ("expedition", ["--setup=6", "--area=3", "--mission=expedition", "--wait=60"],
     {"de": "Erkunde wilde Gebiete", "en": "Explore wild lands"}),
    ("boss", ["--setup=8"], {"de": "Besiege mächtige Bosse", "en": "Defeat mighty bosses"}),
    ("helden", ["--setup=8"], {"de": "Sieben Helden, eigene Waffen", "en": "Seven heroes, own weapons"}),
]
# Rohbild je Seitenverhältnis (so groß wie das größte Zielformat)
ASPECTS = {"wide": (2796, 1290), "hd": (2208, 1242), "ipad": (2732, 2048), "tab": (2560, 1600)}
# Store-Formate (quer, das Spiel läuft nur quer): Name, Größe, Rohbild
FORMATS = [
    ("iphone_6.7", (2796, 1290), "wide"),
    ("iphone_5.5", (2208, 1242), "hd"),
    ("ipad_12.9", (2732, 2048), "ipad"),
    ("android_telefon", (1920, 1080), "hd"),
    ("android_tablet", (2560, 1600), "tab"),
]
# Texte im Video: (von s, bis s, de, en)
VIDEO_TEXTS = [
    (0.6, 5.6, "Rustwall", "Rustwall"),
    (6.6, 15.4, "Halte die Schleimflut auf", "Hold back the slime flood"),
    (17.2, 25.6, "Erkunde wilde Gebiete", "Explore wild lands"),
]
VIDEO_END = {"de": "Jetzt spielen", "en": "Play now"}


def godot_run(godot, res, args, timeout=600):
    cmd = ["xvfb-run", "-a", "-s", "-screen 0 %dx%dx24" % res, godot, "--rendering-driver", "opengl3",
           "--resolution", "%dx%d" % res, "--path", ROOT, "--"] + args
    try:
        p = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout)
        return p.stdout + p.stderr
    except subprocess.TimeoutExpired:
        return "TIMEOUT"


def shots(godot, langs, motifs):
    os.makedirs(RAW, exist_ok=True)
    for lang in langs:
        for m, args, _t in MOTIFS:
            if motifs and m not in motifs:
                continue
            for ak, res in ASPECTS.items():
                out = os.path.join(RAW, "%s_%s_%s.png" % (m, lang, ak))
                if os.path.exists(out):
                    continue
                txt = godot_run(godot, res, ["--autotest=storeshot", "--motif=" + m, "--out=" + out, "--lang=" + lang] + args)
                ok = "STORESHOT" in txt and os.path.exists(out)
                print("%s %s %s: %s" % (m, lang, ak, "ok" if ok else "FEHLER " + txt[-300:]), flush=True)


def _font(size):
    return ImageFont.truetype(FONT, size)


def headline(img, text):
    """Überschrift oben: dunkler Verlauf, goldene Schrift mit Umriss."""
    w, h = img.size
    band = int(h * 0.24)
    over = Image.new("RGBA", (w, band), (0, 0, 0, 0))
    d = ImageDraw.Draw(over)
    for y in range(band):
        a = int(235 * (1.0 - (y / band) ** 1.6))
        d.line([(0, y), (w, y)], fill=(10, 27, 48, a))
    img = img.convert("RGBA")
    img.alpha_composite(over, (0, 0))
    size = int(h * 0.085)
    f = _font(size)
    d = ImageDraw.Draw(img)
    while d.textlength(text, font=f) > w * 0.9 and size > 20:
        size -= 4
        f = _font(size)
    tw = d.textlength(text, font=f)
    x = (w - tw) / 2
    y = int(h * 0.035)
    # Schatten
    sh = Image.new("RGBA", img.size, (0, 0, 0, 0))
    ImageDraw.Draw(sh).text((x + size * 0.05, y + size * 0.07), text, font=f, fill=(0, 0, 0, 170))
    img.alpha_composite(sh.filter(ImageFilter.GaussianBlur(size * 0.06)))
    d.text((x, y), text, font=f, fill=(255, 210, 62, 255), stroke_width=max(3, size // 14), stroke_fill=(20, 30, 60, 255))
    return img.convert("RGB")


def fit(img, size):
    """Auf die Zielgröße bringen (Seitenverhältnis gleich; sonst mittig zuschneiden)."""
    tw, th = size
    w, h = img.size
    k = max(tw / w, th / h)
    img = img.resize((max(tw, round(w * k)), max(th, round(h * k))), Image.LANCZOS)
    w, h = img.size
    l = (w - tw) // 2
    t = (h - th) // 2
    return img.crop((l, t, l + tw, t + th))


def compose(langs, motifs):
    n = 0
    for lang in langs:
        for i, (m, _a, titles) in enumerate(MOTIFS):
            if motifs and m not in motifs:
                continue
            for fname, size, ak in FORMATS:
                src = os.path.join(RAW, "%s_%s_%s.png" % (m, lang, ak))
                if not os.path.exists(src):
                    print("fehlt:", src)
                    continue
                img = headline(fit(Image.open(src).convert("RGB"), size), titles[lang])
                od = os.path.join(OUT, lang, fname)
                os.makedirs(od, exist_ok=True)
                img.save(os.path.join(od, "%02d_%s.jpg" % (i + 1, m)), quality=92, optimize=True, subsampling=0)
                n += 1
    print("Store-Bilder:", n)


def video(godot, langs):
    os.makedirs(VID, exist_ok=True)
    tmpd = os.path.join(ROOT, "build", "store_video")
    os.makedirs(tmpd, exist_ok=True)
    for lang in langs:
        avi = os.path.join(tmpd, "trailer_%s.avi" % lang)
        if not os.path.exists(avi):
            # Movie-Maker: feste 30 Bilder/s, unabhängig davon, wie schnell der Rechner ist. Die Fenstergröße 1920×1080 kommt
            # über override.cfg (die Projekt-Einstellung window_*_override = 1280×720 ginge sonst vor --resolution).
            ov = os.path.join(ROOT, "override.cfg")
            with open(ov, "w") as f:
                f.write("[display]\nwindow/size/window_width_override=1920\nwindow/size/window_height_override=1080\n")
            cmd = ["xvfb-run", "-a", "-s", "-screen 0 1920x1080x24", godot, "--rendering-driver", "opengl3", "--resolution", "1920x1080",
                   "--path", ROOT, "--write-movie", avi, "--fixed-fps", "30", "--", "--autotest=trailer", "--setup=8", "--week=8", "--lang=" + lang]
            try:
                p = subprocess.run(cmd, capture_output=True, text=True, timeout=7200)
            finally:
                os.remove(ov)
            print("Aufnahme %s:" % lang, "ok" if "TRAILER OK" in p.stdout else "FEHLER " + (p.stdout + p.stderr)[-400:], flush=True)
        fl = FONT.replace(":", "\\:")
        dr = []
        for a, b, de, en in VIDEO_TEXTS:
            t = (de if lang == "de" else en).replace("'", "’")
            alpha = "if(lt(t,%.2f),(t-%.2f)/0.4,if(gt(t,%.2f),(%.2f-t)/0.4,1))" % (a + 0.4, a, b - 0.4, b)
            dr.append("drawtext=fontfile='%s':text='%s':fontsize=82:fontcolor=0xFFD23E:borderw=6:bordercolor=0x14203C:"
                      "x=(w-text_w)/2:y=h*0.08:enable='between(t,%.2f,%.2f)':alpha='%s'" % (fl, t, a, b, alpha))
        end = VIDEO_END[lang]
        dr.append("fade=t=out:st=26.0:d=0.5")
        vf = ",".join(dr)
        mp4 = os.path.join(VID, "rustwall_vorschau_%s.mp4" % lang)
        cmd = ["ffmpeg", "-v", "error", "-y", "-i", avi, "-t", "26.5", "-vf", vf, "-c:v", "libx264", "-preset", "slow", "-crf", "21",
               "-pix_fmt", "yuv420p", "-r", "30", "-an", "-movflags", "+faststart", mp4]
        r = subprocess.run(cmd, capture_output=True, text=True)
        print("Video %s:" % lang, "ok" if r.returncode == 0 else "FEHLER " + r.stderr[-400:])
        # Endtafel (2 s) mit Titel anhängen
        card = os.path.join(tmpd, "end_%s.png" % lang)
        im = Image.new("RGB", (1920, 1080), (11, 36, 74))
        d = ImageDraw.Draw(im)
        for y in range(1080):
            c = (int(11 + 10 * y / 1080), int(36 + 20 * y / 1080), int(74 + 30 * y / 1080))
            d.line([(0, y), (1920, y)], fill=c)
        f1 = _font(190)
        f2 = _font(80)
        for txt, f, y, col in [("Rustwall", f1, 330, (255, 210, 62)), (end, f2, 610, (255, 255, 255))]:
            tw = d.textlength(txt, font=f)
            d.text(((1920 - tw) / 2, y), txt, font=f, fill=col, stroke_width=8, stroke_fill=(20, 30, 60))
        im.save(card)
        final = os.path.join(VID, "rustwall_vorschau_%s.mp4" % lang)
        tmp_main = os.path.join(tmpd, "main_%s.mp4" % lang)
        shutil.move(mp4, tmp_main)
        cmd = ["ffmpeg", "-v", "error", "-y", "-i", tmp_main, "-loop", "1", "-t", "2.5", "-framerate", "30", "-i", card,
               "-filter_complex", "[0:v]scale=1920:1080,setsar=1[m];[1:v]scale=1920:1080,setsar=1,fade=t=in:st=0:d=0.5,format=yuv420p[c];[m][c]concat=n=2:v=1:a=0[v]", "-map", "[v]",
               "-c:v", "libx264", "-preset", "slow", "-crf", "21", "-pix_fmt", "yuv420p", "-r", "30", "-movflags", "+faststart", final]
        r = subprocess.run(cmd, capture_output=True, text=True)
        print("Video mit Endtafel %s:" % lang, "ok" if r.returncode == 0 else "FEHLER " + r.stderr[-400:])
        # Vorschaubild (Poster) für die Doku
        subprocess.run(["ffmpeg", "-v", "error", "-y", "-ss", "9", "-i", final, "-frames:v", "1", "-vf", "scale=960:-1",
                        os.path.join(VID, "poster_%s.jpg" % lang)])


def main():
    a = sys.argv[1:]
    godot = a[a.index("--godot") + 1] if "--godot" in a else "godot"
    only = a[a.index("--only") + 1] if "--only" in a else ""
    langs = (a[a.index("--langs") + 1] if "--langs" in a else "de,en").split(",")
    motifs = (a[a.index("--motifs") + 1].split(",") if "--motifs" in a else [])
    if only in ("", "shots"):
        shots(godot, langs, motifs)
    if only in ("", "compose", "shots"):
        compose(langs, motifs)
    if only in ("", "video"):
        video(godot, langs)


if __name__ == "__main__":
    main()
