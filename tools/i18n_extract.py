#!/usr/bin/env python3
"""Sammelt alle Spieltexte aus src/**/*.gd und aktualisiert locale/rustwall.pot und locale/en.po.

Quelle ist der deutsche Text (msgid = deutscher Text). Vorhandene Übersetzungen in en.po bleiben erhalten.
Zusammengesetzte Texte ("Stufe " + str(n)) werden als Vorlage "Stufe %s" erfasst; die Laufzeit-Übersetzung
(src/i18n.gd) erkennt solche Vorlagen auch in fertig zusammengesetzten Texten.

Aufruf:
  python3 tools/i18n_extract.py                 # pot + en.po schreiben, Bericht ausgeben
  python3 tools/i18n_extract.py --missing       # zusätzlich alle fehlenden Übersetzungen auflisten
  python3 tools/i18n_extract.py --todo F.json   # fehlende als nummerierte Liste nach F.json (zum Übersetzen)
  python3 tools/i18n_extract.py --apply F.json --answers A.json   # Antworten {"nr": "english"} übernehmen
  python3 tools/i18n_extract.py --set D.json   # {"deutsch": "english"} direkt übernehmen
  python3 tools/i18n_extract.py --check         # nur prüfen (Platzhalter, Abdeckung), nichts schreiben
"""
import glob
import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
POT = os.path.join(ROOT, "locale", "rustwall.pot")
# Hilfsvorlagen für Teile zusammengesetzter Texte, die so nicht wörtlich im Code stehen ({deutsch: englisch})
EXTRA = os.path.join(ROOT, "tools", "i18n_extra.json")
PO_EN = os.path.join(ROOT, "locale", "en.po")

# Dateien ohne Spielertexte (Tests, Admin-Menü, Animationsdaten, Rechtstexte haben eigene englische Fassung)
SKIP_FILES = re.compile(r"(/tests[^/]*\.gd$|/admin\.gd$|/liveops_admin\.gd$|/ui_test\.gd$|/anim_test\.gd$|/anim_human_data\.gd$|/legal_texts\.gd$|/i18n\.gd$)")
# Aufrufe, deren Text-Argumente keine Spielertexte sind
SKIP_CALLS = {
    "print", "prints", "printerr", "print_rich", "push_error", "push_warning", "assert", "load", "preload", "get_node",
    "get_node_or_null", "has_node", "find_child", "find_children", "find", "play", "play_at", "loop", "stop_loop", "loop_stop",
    "has_meta", "get_meta", "set_meta", "remove_meta", "has_method", "connect",
    "is_connected", "disconnect", "add_theme_color_override", "add_theme_font_size_override", "add_theme_constant_override",
    "add_theme_stylebox_override", "add_theme_font_override", "add_theme_icon_override", "get_theme_color", "get_theme_font",
    "set", "get", "has", "erase", "arg", "ch", "pic", "tex", "icon", "tile", "has_pic", "glb", "has_glb", "building", "Color",
    "is_action_pressed", "is_action_just_pressed", "is_action_just_released", "get_axis", "get_vector", "action_press", "action_release",
    "get_shader_parameter", "set_shader_parameter", "set_instance_shader_parameter", "begins_with", "ends_with", "contains",
    "split", "replace", "count_up", "stat", "outpost_bonus", "res", "cap", "add", "pay", "_act", "count", "file_exists",
    "open", "get_file_as_string", "dir_exists", "make_dir_recursive", "get_setting", "set_setting", "has_feature", "tween_property",
    "tween_method", "create_tween", "is_in_group", "add_to_group", "get_nodes_in_group", "get_tree", "set_cursor", "material",
    "_mat", "mat", "pic_name", "sfx", "Sfx", "item_pic", "chest_pic", "hero_pic", "vehicle_pic", "building_pic", "has_skin",
    "rarity_dot", "anim", "play_anim", "_play", "travel", "seek", "_clip", "clip", "request", "post", "_post", "_get", "_req",
    "log_event", "event", "track", "send_event", "setting", "flag", "has_flag", "set_flag", "quality", "has_action", "_mesh",
    "mesh", "_load", "_tex", "parse_string", "stringify", "OS.get_environment", "get_environment", "open_menu", "open",
    "get_bus_index", "ensure_bus", "set_bus_send", "add_bus", "set_bus_name", "set_stylebox", "set_color", "set_constant", "set_font_size", "set_font",
    "set_type_variation", "set_icon", "class_exists", "has_theme_stylebox", "get_theme_stylebox", "set_theme_type_variation",
    "add_user_signal", "has_signal", "get_class", "is_class", "find_bone", "get_bone_pose", "bone", "has_animation", "get_animation",
}
EXT = re.compile(r"\.(png|glb|ogg|wav|mp3|json|gd|tscn|tres|svg|ttf|otf|po|pot|txt|cfg|md|webp|jpg|gdshader|res)$", re.I)
NOT_TEXT_WORDS = {
    "Col", "Label", "Button", "Panel", "Control", "Node", "Node3D", "Color", "Vector2", "Vector3", "MultiMesh", "Mesh",
    "Camera3D", "Timer", "Tween", "Area3D", "Skeleton3D", "AnimationPlayer", "Theme", "Font", "SubViewport", "TextureRect",
    "Texture2D", "Image", "Body", "Root", "Armature", "Head", "Hips", "Spine", "Chest", "Neck", "RigidBody3D", "HTTPRequest",
    "AudioStreamPlayer", "TouchScreenButton", "PanelContainer", "VBoxContainer", "HBoxContainer", "ScrollContainer",
    "LineEdit", "RichTextLabel", "ProgressBar", "GridContainer", "MarginContainer", "OmniLight3D", "SpotLight3D",
    "MeshInstance3D", "GPUParticles3D", "CPUParticles3D", "Sprite3D", "Label3D", "Engine", "OS", "JSON", "GET", "POST", "PUT", "DELETE",
    "Content-Type: application/json", "Authorization", "Bearer", "PATCH", "HEAD", "Row", "RowOn", "Tab", "TabOn", "unshaded", ", unshaded",
}
GERMAN_HINT = re.compile(r"[äöüÄÖÜß]|\b(der|die|das|und|ist|nicht|ein|eine|mit|für|auf|zu|von|im|den|dem|des|bei|noch|jetzt|neu|alle|kein|keine)\b", re.I)


# kleingeschriebene Einzelwörter, die im Spiel als Text erscheinen (sonst gelten solche Wörter als Schlüssel)
LOWER_TEXT = {"ja", "nein", "gesperrt", "gratis", "ihn", "sie", "immun", "nichts", "frei", "unbekannt", "verschickt",
              "spendet", "abgewehrt", "besiegt", "offen", "normal", "groß", "angelegt", "verschmelzbar", "verbesserbar",
              "ausgerüstet", "herstellbar", "keine", "laden"}


def is_text(s):
    t = s.strip()
    if t in LOWER_TEXT:
        return True
    if not re.search(r"[A-Za-zÄÖÜäöüß]{2}", t):
        return False
    if ("://" in t and " " not in t) or t.startswith("res:") or t.startswith("user:"):
        return False
    if EXT.search(t) and " " not in t:
        return False
    if re.fullmatch(r"[a-z0-9_.\-/:%#]+", t):          # Schlüssel, Bezeichner, Pfade
        return False
    if re.fullmatch(r"[A-Z0-9_]+_[A-Z0-9_]+", t):      # KONSTANTEN_NAMEN
        return False
    if t in NOT_TEXT_WORDS:
        return False
    if re.fullmatch(r"#?[0-9A-Fa-f]{6,8}", t):
        return False
    if re.fullmatch(r"[a-z]+[A-Z]\w*", t):              # camelCase
        return False
    if re.fullmatch(r"[A-Z][a-z]+[A-Z]\w*", t) and not GERMAN_HINT.search(t):   # CamelCase-Typen
        return False
    if re.fullmatch(r"[a-z_]+\.[a-z_.]+", t):           # punkt.pfad
        return False
    if re.fullmatch(r"[a-z0-9_]+(,[a-z0-9_]+)+", t):    # Listen von Schlüsseln
        return False
    if t.startswith("[") and t.endswith("]") and " " not in t and "=" in t:   # einzelne BBCode-Marke
        return False
    if re.search(r"shader_type|render_mode|uniform |void fragment|void vertex", t):   # Shader-Quelltext
        return False
    if " " not in t and ("_" in t or "@" in t or "|" in t or re.fullmatch(r"[\w.]*/[\w./]*", t) and not re.search("[äöüÄÖÜß]", t) and (t[0].islower() or t[0] in "./")):      # Pfade, Knoten, Schlüssel
        return False
    if "=%" in t or t.startswith("/") or re.match(r"(X-[\w-]+|Accept|Authorization|Content-Type):", t):
        return False
    return True


def unescape(s):
    out = []
    i = 0
    while i < len(s):
        c = s[i]
        if c == "\\" and i + 1 < len(s):
            n = s[i + 1]
            out.append({"n": "\n", "t": "\t", '"': '"', "'": "'", "\\": "\\", "r": ""}.get(n, "\\" + n))
            i += 2
            continue
        out.append(c)
        i += 1
    return "".join(out)


class Tok:
    __slots__ = ("kind", "val", "pos", "depth", "line")

    def __init__(self, kind, val, pos, depth, line):
        self.kind, self.val, self.pos, self.depth, self.line = kind, val, pos, depth, line


def tokenize(src):
    """Sehr einfacher GDScript-Zerleger: Strings, Bezeichner, Zahlen, Zeichen, Zeilenenden, Klammertiefe."""
    toks = []
    i, n, depth, line = 0, len(src), 0, 1
    while i < n:
        c = src[i]
        if c == "\n":
            if depth == 0:
                toks.append(Tok("nl", "\n", i, depth, line))
            line += 1
            i += 1
            continue
        if c in " \t\r":
            i += 1
            continue
        if c == "\\" and i + 1 < n and src[i + 1] == "\n":
            i += 2
            line += 1
            continue
        if c == "#":
            while i < n and src[i] != "\n":
                i += 1
            continue
        if c in "\"'" or (c in "&^" and i + 1 < n and src[i + 1] in "\"'"):
            prefix = ""
            if c in "&^":
                prefix = c
                i += 1
                c = src[i]
            if src.startswith(c * 3, i):
                j = src.find(c * 3, i + 3)
                raw = src[i + 3:j]
                line_start = line
                line += raw.count("\n")
                toks.append(Tok("str" if not prefix else "sname", unescape(raw), i, depth, line_start))
                i = j + 3
                continue
            j = i + 1
            while j < n and src[j] != c:
                if src[j] == "\\":
                    j += 1
                if src[j] == "\n":
                    break
                j += 1
            toks.append(Tok("str" if not prefix else "sname", unescape(src[i + 1:j]), i, depth, line))
            i = j + 1
            continue
        if c.isalpha() or c == "_":
            j = i
            while j < n and (src[j].isalnum() or src[j] == "_"):
                j += 1
            toks.append(Tok("id", src[i:j], i, depth, line))
            i = j
            continue
        if c.isdigit():
            j = i
            while j < n and (src[j].isalnum() or src[j] in "._"):
                j += 1
            toks.append(Tok("num", src[i:j], i, depth, line))
            i = j
            continue
        if c in "([{":
            toks.append(Tok("open", c, i, depth, line))
            depth += 1
            i += 1
            continue
        if c in ")]}":
            depth = max(0, depth - 1)
            toks.append(Tok("close", c, i, depth, line))
            i += 1
            continue
        two = src[i:i + 2]
        if two in ("==", "!=", "<=", ">=", "+=", "-=", "*=", "/=", ":=", "->", "&&", "||", "**", "%="):
            toks.append(Tok("op", two, i, depth, line))
            i += 2
            continue
        toks.append(Tok("op", c, i, depth, line))
        i += 1
    return toks


STOP_IDS = {"if", "else", "elif", "and", "or", "not", "return", "in", "var", "const", "for", "while", "match", "when", "is", "as", "await", "func"}
STOP_OPS = {",", "=", ":=", "+=", ":", "==", "!=", "<", ">", "<=", ">=", "->", "%", "&&", "||", "-=", "*", "/", "*=", "/="}


def enclosing_call(toks, k):
    """Name der Funktion, in deren Klammern Token k steht (oder '')."""
    d = toks[k].depth
    j = k - 1
    while j >= 0:
        t = toks[j]
        if t.kind == "nl" and t.depth == 0:
            return ""
        if t.kind == "open" and t.depth < d:
            if t.val == "(" and j > 0 and toks[j - 1].kind == "id":
                name = toks[j - 1].val
                if j > 2 and toks[j - 2].val == "." and toks[j - 3].kind == "id":
                    return toks[j - 3].val + "." + name if toks[j - 3].val in ("OS",) else name
                return name
            return "(" if t.val == "(" else t.val
        j -= 1
    return ""


def operand_span(toks, k, step):
    """Läuft von Token k aus über ein Operanden-Stück (bis zum nächsten + oder einer Grenze) in Richtung step."""
    d = toks[k].depth
    j = k
    while True:
        nj = j + step
        if nj < 0 or nj >= len(toks):
            return j
        t = toks[nj]
        if t.kind == "nl":
            return j
        if t.depth < d:
            return j
        if t.depth == d:
            if t.kind == "op" and (t.val == "+" or t.val in STOP_OPS):
                return j
            if t.kind == "id" and t.val in STOP_IDS:
                return j
            if t.kind == "close" and step > 0:
                pass
        j = nj


def concat_template(toks, k, used):
    """Baut aus einer +-Kette um den String k eine Vorlage ("Stufe %s"), sonst None."""
    d = toks[k].depth
    # nach links / rechts über "+" laufen
    parts = []
    # Start der Kette suchen
    start = operand_span(toks, k, -1)
    while start - 1 >= 0 and toks[start - 1].kind == "op" and toks[start - 1].val == "+" and toks[start - 1].depth == d:
        if start - 2 < 0:
            break
        start = operand_span(toks, start - 2, -1)
    pos = start
    has_lit = False
    has_var = False
    while True:
        end = operand_span(toks, pos, 1)
        seg = toks[pos:end + 1]
        if len(seg) == 1 and seg[0].kind == "str":
            parts.append(("lit", seg[0].val))
            used.add(pos)
            if is_text(seg[0].val):
                has_lit = True
        else:
            parts.append(("var", None))
            has_var = True
        nxt = end + 1
        if nxt < len(toks) and toks[nxt].kind == "op" and toks[nxt].val == "+" and toks[nxt].depth == d and nxt + 1 < len(toks) and toks[nxt + 1].kind != "nl":
            pos = nxt + 1
            continue
        break
    if not (has_lit and has_var):
        return None
    out = ""
    for kind, v in parts:
        out += v.replace("%", "%%") if kind == "lit" and "%" not in v else (v if kind == "lit" else "%s")
    return out


def find_line_text(src, pos):
    a = src.rfind("\n", 0, pos) + 1
    b = src.find("\n", pos)
    return src[a:b if b >= 0 else len(src)]


def collect():
    entries = {}   # msgid -> set(refs)
    order = []
    files = sorted(glob.glob(os.path.join(ROOT, "src", "**", "*.gd"), recursive=True))
    for f in files:
        rel = os.path.relpath(f, ROOT).replace(os.sep, "/")
        if SKIP_FILES.search("/" + rel):
            continue
        src = open(f, encoding="utf-8").read()
        toks = tokenize(src)
        used = set()
        for k, t in enumerate(toks):
            if t.kind != "str":
                continue
            if k in used:
                continue
            if k >= 2 and toks[k - 1].val == "=" and toks[k - 2].kind == "id" and toks[k - 2].val in ("name", "type", "key", "id", "kind"):
                continue
            call = enclosing_call(toks, k)
            if call in SKIP_CALLS:
                continue
            # Dictionary-Schlüssel ("name": ...) überspringen
            if k + 1 < len(toks) and toks[k + 1].kind == "op" and toks[k + 1].val == ":" and toks[k - 1].val in ("{", ",") and re.fullmatch(r"[\w ]+", t.val) and not GERMAN_HINT.search(t.val) and " " not in t.val:
                continue
            # Vergleiche mit Schlüsseln ( == "x" ) überspringen, wenn kein Satz
            prev = toks[k - 1] if k > 0 else None
            if prev is not None and prev.kind == "op" and prev.val in ("==", "!=") and " " not in t.val.strip():
                continue
            if prev is not None and prev.kind == "id" and prev.val in ("in",) and " " not in t.val.strip():
                continue
            ids = []
            nxt = toks[k + 1] if k + 1 < len(toks) else None
            near_plus = (prev is not None and prev.kind == "op" and prev.val == "+" and prev.depth == t.depth) or \
                        (nxt is not None and nxt.kind == "op" and nxt.val == "+" and nxt.depth == t.depth)
            if near_plus and k not in used:
                tpl = concat_template(toks, k, used)
                if tpl is not None and len(re.sub(r"%[sd]|[^A-Za-zÄÖÜäöüß]", "", tpl)) >= 3:
                    ids.append(tpl)
                    used.add(k)
            if k not in used and is_text(t.val):
                ids.append(t.val)
            for s in ids:
                for piece in split_for_po(s):
                    if piece not in entries:
                        entries[piece] = []
                        order.append(piece)
                    if len(entries[piece]) < 4:
                        entries[piece].append("%s:%d" % (rel, t.line))
    return entries, order


def split_for_po(s):
    """Leerraum am Rand gehört nicht zum Text; reine Satzzeichen/Abstände fallen weg."""
    t = s.strip()
    if not t or not is_text(t):
        return []
    return [t]


# ------------------------------------------------------------------ PO lesen / schreiben
def po_escape(s):
    return s.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n").replace("\t", "\\t")


def po_lines(key, val):
    if "\n" in val and len(val) > 60:
        parts = val.split("\n")
        out = ['%s ""' % key]
        for i, p in enumerate(parts):
            out.append('"%s"' % po_escape(p + ("\n" if i < len(parts) - 1 else "")))
        return [o for o in out if o != '""']
    return ['%s "%s"' % (key, po_escape(val))]


def read_po(path):
    res = {}
    if not os.path.exists(path):
        return res
    cur = None
    mid, mstr = "", ""
    def flush():
        if mid:
            res[mid] = mstr
    for line in open(path, encoding="utf-8"):
        line = line.rstrip("\n")
        if line.startswith("#~ "):          # veraltete Einträge (nicht mehr im Code) – Übersetzung bleibt gemerkt
            line = line[3:]
        if line.startswith("msgid "):
            flush()
            mid, mstr = "", ""
            cur = "id"
            mid = json.loads(line[6:].replace("\\t", "\\t")) if False else po_unq(line[6:])
        elif line.startswith("msgstr "):
            cur = "str"
            mstr = po_unq(line[7:])
        elif line.startswith('"'):
            if cur == "id":
                mid += po_unq(line)
            elif cur == "str":
                mstr += po_unq(line)
        elif line.startswith("#") or not line.strip():
            if cur == "str":
                flush()
                mid, mstr, cur = "", "", None
    flush()
    return res


def po_unq(s):
    s = s.strip()
    assert s.startswith('"') and s.endswith('"'), s
    return unescape(s[1:-1])


HEADER = ('msgid ""\nmsgstr ""\n"Project-Id-Version: Rustwall\\n"\n"MIME-Version: 1.0\\n"\n'
          '"Content-Type: text/plain; charset=UTF-8\\n"\n"Content-Transfer-Encoding: 8bit\\n"\n"Language: %s\\n"\n'
          '"Plural-Forms: nplurals=2; plural=(n != 1);\\n"\n')


def write_po(path, order, entries, trans, lang):
    out = [HEADER % lang]
    for mid in order:
        out.append("#: " + " ".join(entries[mid]))
        out.extend(po_lines("msgid", mid))
        out.extend(po_lines("msgstr", trans.get(mid, "") if trans is not None else ""))
        out.append("")
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        f.write("\n".join(out))


PH = re.compile(r"%(?:%|[-+0]*\d*(?:\.\d+)?[sdifxXcov])")


def placeholders(s):
    return sorted(p for p in PH.findall(s) if p != "%%")


def main():
    args = sys.argv[1:]
    entries, order = collect()
    old = read_po(PO_EN)
    if "--set" in args:   # Datei {deutsch: englisch} direkt übernehmen
        for de, en in json.load(open(args[args.index("--set") + 1], encoding="utf-8")).items():
            old[de] = en
    if "--apply" in args:
        todo = json.load(open(args[args.index("--apply") + 1], encoding="utf-8"))
        ans = json.load(open(args[args.index("--answers") + 1], encoding="utf-8"))
        n = 0
        for num, eng in ans.items():
            mid = todo.get(num)
            if mid is None:
                print("unbekannte Nummer", num)
                continue
            old[mid] = eng
            n += 1
        print("%d Übersetzungen übernommen" % n)
    if os.path.exists(EXTRA):
        for de, en in json.load(open(EXTRA, encoding="utf-8")).items():
            if de.startswith("_"):
                continue
            if de not in entries:
                entries[de] = ["tools/i18n_extra.json"]
                order.append(de)
            old[de] = old.get(de) or en
    # gleiche Texte, die sich nur im Leerraum am Rand unterscheiden, übernehmen
    stripped = {}
    for k, v in old.items():
        if v and k.strip() != k:
            stripped.setdefault(k.strip(), v.strip())
    for m in order:
        if not old.get(m) and m in stripped:
            old[m] = stripped[m]
    trans = {m: old.get(m, "") for m in order}
    # Übersetzungen, die im Code nicht mehr vorkommen, bleiben als veraltet (#~) am Ende gemerkt
    extra = []
    obsolete = {m: old[m] for m in old if m not in entries and old[m]}
    missing = [m for m in order if not trans.get(m)]
    bad_ph = [m for m in order if trans.get(m) and placeholders(m) != placeholders(trans[m].replace("||", ""))
              and placeholders(m) != placeholders(trans[m].split("||")[0])]
    found = len([m for m in order if m not in extra])
    if "--check" not in args:
        write_po(POT, [m for m in order if m not in extra], entries, None, "")
        write_po(PO_EN, order, entries, trans, "en")
        if obsolete:
            with open(PO_EN, "a", encoding="utf-8") as f:
                f.write("\n# Veraltet: nicht mehr im Code gefunden (bleibt gemerkt, falls der Text zurückkommt)\n")
                for m, v in obsolete.items():
                    f.write("\n".join("#~ " + l for l in po_lines("msgid", m) + po_lines("msgstr", v)) + "\n\n")
    print("Texte gefunden: %d, übersetzt: %d (%.1f %%), fehlen: %d, veraltet (gemerkt): %d, Platzhalter falsch: %d" % (
        found, found - len(missing), 100.0 * (found - len(missing)) / max(1, found), len(missing), len(obsolete), len(bad_ph)))
    for m in bad_ph:
        print("PLATZHALTER:", json.dumps(m, ensure_ascii=False), "->", json.dumps(trans[m], ensure_ascii=False))
    if "--missing" in args:
        for m in missing:
            print("FEHLT:", json.dumps(m, ensure_ascii=False), entries[m][0])
    if "--todo" in args:
        path = args[args.index("--todo") + 1]
        lim = int(args[args.index("--limit") + 1]) if "--limit" in args else 100000
        todo = {str(i + 1): m for i, m in enumerate(missing[:lim])}
        json.dump(todo, open(path, "w", encoding="utf-8"), ensure_ascii=False, indent=0)
        print("Liste mit %d Einträgen nach %s" % (len(todo), path))
    return 0 if not bad_ph else 1


if __name__ == "__main__":
    sys.exit(main())
