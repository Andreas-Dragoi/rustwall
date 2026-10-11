"""Rustwall – Prüfskript für die Gebäude-Modelle (Auftrag V3, Kapitel 6, Abnahme).
Meldet je GLB in models/: Dreiecke, Zahl der Objekte, Größe, bewegte Teile, Effektpunkte, Ausbau-/Schadens-Teile,
fehlende Pflicht-Leerobjekte (door, work_1, work_2, drop, bubble) bei Gebäuden (b_*) und Überschreitungen der Grenzen.
Aufruf: python3 blender/check_models.py [namen...]   (ohne Namen: alle b_*.glb; --alle: jede GLB in models/)
Rückgabewert 1, wenn ein geprüftes Gebäude eine Grenze überschreitet oder ein Pflichtteil fehlt.
Liest die GLB-Dateien direkt (ohne Blender)."""
import sys, os, json, struct, glob

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
NEED = ("door", "work_1", "work_2", "drop", "bubble")
# Grundfläche in Feldern (1 Feld = 2 m); das Modell darf je Seite 0,2 m Rand lassen -> Breite höchstens Felder * 2 - 0,4 m
SIZE = {"b_bunker": (4, 4), "b_saege": (3, 3), "b_steinbruch": (3, 3), "b_presse": (3, 3), "b_raffinerie": (3, 3), "b_generator": (2, 2),
        "b_lager": (3, 3), "b_quartier": (3, 2), "b_kistenlager": (2, 2), "b_werkstatt": (3, 3), "b_garage": (4, 3), "b_funkturm": (2, 2),
        "b_clanhalle": (4, 4), "b_labor": (3, 3), "b_schild": (3, 3), "b_training": (3, 3)}
# Gebäude nach dem Detail-Katalog (Teil 1 von Paket 6); alle anderen b_*-Modelle werden nur gezählt
KATALOG = tuple(SIZE)
TRI_MAX, TRI_MAX_BUNKER = 12000, 18000


def read_glb(path):
    with open(path, "rb") as f:
        data = f.read()
    magic, ver, length = struct.unpack_from("<4sII", data, 0)
    if magic != b"glTF":
        raise ValueError("keine GLB-Datei")
    off = 12
    js = None
    while off < length:
        clen, ctype = struct.unpack_from("<I4s", data, off)
        if ctype == b"JSON":
            js = json.loads(data[off + 8:off + 8 + clen].decode("utf-8"))
        off += 8 + clen
    return js


def mat_mul(a, b):
    return [[sum(a[i][k] * b[k][j] for k in range(4)) for j in range(4)] for i in range(4)]


def node_matrix(n):
    if "matrix" in n:
        m = n["matrix"]
        return [[m[c * 4 + r] for c in range(4)] for r in range(4)]
    t = n.get("translation", [0, 0, 0]); q = n.get("rotation", [0, 0, 0, 1]); s = n.get("scale", [1, 1, 1])
    x, y, z, w = q
    r = [[1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w)],
         [2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w)],
         [2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y)]]
    return [[r[0][0] * s[0], r[0][1] * s[1], r[0][2] * s[2], t[0]], [r[1][0] * s[0], r[1][1] * s[1], r[1][2] * s[2], t[1]],
            [r[2][0] * s[0], r[2][1] * s[1], r[2][2] * s[2], t[2]], [0, 0, 0, 1]]


def check(path):
    """Liefert (Kennzahlen, Fehlerliste) für eine GLB-Datei."""
    name = os.path.splitext(os.path.basename(path))[0]
    g = read_glb(path)
    nodes = g.get("nodes", [])
    acc = g.get("accessors", [])
    tris = 0
    per = {}
    names = []
    lo = [1e9] * 3; hi = [-1e9] * 3
    ident = [[1.0 if i == j else 0.0 for j in range(4)] for i in range(4)]

    def walk(i, pm, depth):
        nonlocal tris
        n = nodes[i]
        m = mat_mul(pm, node_matrix(n))
        nm = n.get("name", "")
        if depth > 0:
            names.append(nm)
        if "mesh" in n:
            t = 0
            for p in g["meshes"][n["mesh"]]["primitives"]:
                cnt = acc[p["indices"]]["count"] if "indices" in p else acc[p["attributes"]["POSITION"]]["count"]
                t += cnt // 3
                a = acc[p["attributes"]["POSITION"]]
                mn, mx = a["min"], a["max"]
                for cx in (mn[0], mx[0]):
                    for cy in (mn[1], mx[1]):
                        for cz in (mn[2], mx[2]):
                            v = [m[r][0] * cx + m[r][1] * cy + m[r][2] * cz + m[r][3] for r in range(3)]
                            for k in range(3):
                                lo[k] = min(lo[k], v[k]); hi[k] = max(hi[k], v[k])
            tris += t
            key = nm.split("_")[0] if nm.startswith(("lv", "dmg", "fill")) else "basis"
            per[key] = per.get(key, 0) + t
        for c in n.get("children", []):
            walk(c, m, depth + 1)

    for sc in g.get("scenes", []):
        for r in sc.get("nodes", []):
            walk(r, ident, 0 if "children" in nodes[r] and "mesh" not in nodes[r] else 1)
    info = {"name": name, "tris": tris, "objects": len(names), "per": per, "names": names,
            "size": (hi[0] - lo[0], hi[2] - lo[2], hi[1] - lo[1]) if tris else (0, 0, 0), "lo": lo, "hi": hi}
    errs = []
    key = "b_bunker" if name.startswith("b_bunker_") else name
    if key in KATALOG:
        lim = TRI_MAX_BUNKER if key == "b_bunker" else TRI_MAX
        if tris > lim:
            errs.append("Dreiecke %d > %d" % (tris, lim))
        for k in NEED:
            if k not in names:
                errs.append("Leerobjekt fehlt: %s" % k)
        fx, fz = SIZE[key][0] * 2 - 0.4, SIZE[key][1] * 2 - 0.4
        # glTF: X = Breite, Z = Tiefe (Vorderseite +Z), Y = Höhe
        if max(-lo[0], hi[0]) > fx / 2 + 0.01 or max(-lo[2], hi[2]) > fz / 2 + 0.01:
            errs.append("Grundfläche: x %.2f..%.2f, z %.2f..%.2f (erlaubt +-%.1f / +-%.1f)" % (lo[0], hi[0], lo[2], hi[2], fx / 2, fz / 2))
        if "body" not in names:
            errs.append("Objekt body fehlt")
        mv = [n for n in names if n.startswith(("spin_", "bob_", "sway_", "pulse_"))]
        if len(mv) < 2:
            errs.append("weniger als 2 bewegte Teile (%d)" % len(mv))
        if not [n for n in names if n.startswith("fx_") and n != "fx_smoke_dmg"]:
            errs.append("kein Effektpunkt fx_*")
        if not [n for n in names if "lamp" in n and "_glow" in n]:
            errs.append("keine Außenlampe (lamp_glow)")
        if not [n for n in names if n.startswith("dmg1_")] or not [n for n in names if n.startswith("dmg2_")]:
            errs.append("Schadens-Teile dmg1_*/dmg2_* fehlen")
        if "fx_smoke_dmg" not in names:
            errs.append("Leerobjekt fx_smoke_dmg fehlt")
        if key != "b_bunker" and not [n for n in names if n.startswith("lv4_")]:
            errs.append("Ausbau-Teile lv4_* fehlen")
    return info, errs


def main(argv):
    alle = "--alle" in argv
    args = [a for a in argv if not a.startswith("--")]
    if args:
        paths = [os.path.join(ROOT, "models", a + ".glb") for a in args]
    else:
        paths = sorted(glob.glob(os.path.join(ROOT, "models", "*.glb" if alle else "b_*.glb")))
    bad = 0
    print("%-16s %6s %4s  %-17s %s" % ("Modell", "Dreie.", "Obj.", "B x T x H (m)", "Teile"))
    for p in paths:
        try:
            info, errs = check(p)
        except Exception as e:
            print("%-16s FEHLER beim Lesen: %s" % (os.path.basename(p), e))
            bad += 1
            continue
        nm = info["names"]
        mv = len([n for n in nm if n.startswith(("spin_", "bob_", "sway_", "pulse_"))])
        fx = len([n for n in nm if n.startswith("fx_")])
        leer = [k for k in NEED if k in nm]
        extra = " ".join("%s:%d" % kv for kv in sorted(info["per"].items()))
        print("%-16s %6d %4d  %4.1f x %4.1f x %4.1f  bewegt:%d fx:%d leer:%d/5  %s" % (info["name"], info["tris"], info["objects"], info["size"][0], info["size"][1],
                                                                                 info["size"][2], mv, fx, len(leer), extra))
        for e in errs:
            print("    !! " + e)
        bad += 1 if errs else 0
    print("%d Modelle geprüft, %d mit Beanstandung" % (len(paths), bad))
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
