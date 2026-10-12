#!/usr/bin/env python3
"""Prüft, dass es für jeden im Code benutzten Klangnamen eine Datei in audio/sfx gibt.
Sucht alle Sfx.play / play_at / loop / loop_at-Aufrufe in src/, die "sound"-Felder in data.gd,
zusammengesetzte Namen (sk_<Fähigkeit>, res_<Rohstoff>, engine_<Fahrzeug>) und die Namen,
die die Oberfläche benutzen soll.  Aufruf: python3 tools/check_sounds.py"""
import os, re, glob, sys

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
SFX = os.path.join(ROOT, "audio", "sfx")
UI = ["click", "ui_open", "ui_close", "ui_tab", "ui_select", "ui_equip", "ui_upgrade", "ui_buy", "ui_dismantle", "ui_merge",
      "ui_claim", "ui_error", "ui_toggle", "ui_slider", "ui_toast", "chest_open", "chest_item_0", "chest_item_1", "chest_item_2",
      "chest_item_3", "level_up"]

files = {os.path.basename(p)[:-4] for p in glob.glob(os.path.join(SFX, "*.wav")) + glob.glob(os.path.join(SFX, "*.ogg"))}
sfx_src = open(os.path.join(ROOT, "src", "sfx.gd")).read()
alias = dict(re.findall(r'"(\w+)": "(\w+)"', sfx_src[sfx_src.index("const ALIAS"):sfx_src.index("const WARM")]))


def resolve(name, depth=0):
    if name in files:
        return name + (".wav" if os.path.exists(os.path.join(SFX, name + ".wav")) else ".ogg")
    if name + "_1" in files:
        n = 1
        while "%s_%d" % (name, n + 1) in files:
            n += 1
        return "%s_1..%d" % (name, n)
    if name in alias and alias[name] != name and depth < 3:
        r = resolve(alias[name], depth + 1)
        return ("-> " + r) if r else None
    return None


used = {}          # Name -> Fundstellen
def add(name, where):
    used.setdefault(name, set()).add(where)

for path in sorted(glob.glob(os.path.join(ROOT, "src", "**", "*.gd"), recursive=True)):
    rel = os.path.relpath(path, ROOT)
    src = open(path).read()
    for ln, line in enumerate(src.split("\n"), 1):
        if "Sfx." not in line and '"sound"' not in line and "snd" not in line and '"sfx"' not in line:
            continue
        w = "%s:%d" % (rel, ln)
        for m in re.finditer(r'Sfx\.(play_at|play|loop_at|loop)\(', line):
            fn = m.group(1)
            # Argumente bis zur passenden Klammer, an Kommas der obersten Ebene getrennt
            args, cur, depth = [], "", 0
            for ch in line[m.end():]:
                if ch in "([":
                    depth += 1
                elif ch in ")]":
                    if depth == 0:
                        break
                    depth -= 1
                if ch == "," and depth == 0:
                    args.append(cur)
                    cur = ""
                else:
                    cur += ch
            args.append(cur)
            arg = args[1] if fn in ("loop", "loop_at") and len(args) > 1 else args[0]
            arg = re.sub(r'\([^()]*\)', "", arg)        # innere Aufrufe wie b.get("up", false) ausblenden
            for l in re.findall(r'"([a-z0-9_]+)"', arg):
                if not l.endswith("_"):               # "sk_" + … wird unten aus data.gd ergänzt
                    add(l, w)
        for m in re.finditer(r'(?:snd = |opts\["sfx"\] = )"(\w+)"', line):
            if not m.group(1).endswith("_"):
                add(m.group(1), w)
        for m in re.finditer(r'"sound": "(\w+)"', line):
            add(m.group(1), w)
        if "_snd" in line and "[" in line:            # Tabellen wie wall_hit_snd = [...]
            for l in re.findall(r'"((?:wall|step|amb)_[a-z0-9_]+)"', line):
                add(l, w)

data = open(os.path.join(ROOT, "src", "data.gd")).read()
def block_keys(const):
    blk = data[data.index("const %s := {" % const):]
    blk = blk[:blk.index("\n}")]
    return re.findall(r'^\t"(\w+)": \{', blk, re.M)
for k in block_keys("SKILLS"):
    add("sk_" + k, "data.gd SKILLS")
for k in block_keys("CMD_ACTIVES"):
    add("sk_" + k, "data.gd CMD_ACTIVES")
for k in re.findall(r'"(\w+)"', re.search(r'const RES := \[([^\]]*)\]', data).group(1)):
    add("res_" + k, "data.gd RES")
for k in re.findall(r'"(\w+)"', re.search(r'const VEHICLE_ORDER := \[([^\]]*)\]', data).group(1)):
    add("engine_" + k, "data.gd VEHICLE_ORDER")
for l in re.findall(r'return "(\w+)"', sfx_src):
    add(l, "sfx.gd ground/ambience")
for l in re.findall(r'"(\w+)"', sfx_src[sfx_src.index("const WARM"):sfx_src.index("var _cache")]):
    add(l, "sfx.gd WARM")
for l in UI:
    add(l, "Oberfläche (UI)")

missing = []
for name in sorted(used):
    r = resolve(name)
    if r is None:
        missing.append(name)
    if "-v" in sys.argv or r is None:
        print("%-22s %-28s %s" % (name, r or "FEHLT", ", ".join(sorted(used[name]))[:90]))
unused = sorted(f for f in files if not any(resolve(n) and (f == n or re.fullmatch(re.escape(n) + r"_\d", f) or (n in alias and (f == alias[n] or re.fullmatch(re.escape(alias[n]) + r"_\d", f)))) for n in used))
print("%d Namen benutzt, %d Dateien, %d fehlen%s" % (len(used), len(files), len(missing), (": " + ", ".join(missing)) if missing else ""))
print("Dateien ohne Aufruf im Code (%d): %s" % (len(unused), ", ".join(unused)))
print("Größe audio/sfx: %.2f MB" % (sum(os.path.getsize(p) for p in glob.glob(os.path.join(SFX, "*.wav")) + glob.glob(os.path.join(SFX, "*.ogg"))) / 1e6))
sys.exit(1 if missing else 0)
