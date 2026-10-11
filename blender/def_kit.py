"""Rustwall – gemeinsame Helfer für def_towers.py, def_walls.py und def_small.py (Paket 6, Verteidigung).
Baut nur auf kit.py und rw_util.py auf. Enthält: Balken/Rohre, Bretter mit Farbschwankung, Steinkränze, Sandsäcke,
Leitern, Munitionskisten, Ruß/Risse für die Schadensstufen, Fahnen und ein finish(), das die Umgebungsverschattung
(kit.bake_ao) getrennt für Grundmodell und Zustands-Objekte (lvN_, lvmaxN_, dmgN_) einrechnet.

Als Programm:  python3 blender/def_kit.py check [name ...]   -> Prüfliste (Dreiecke, Objekte, Pflicht-Leerobjekte)
"""
import sys, os, re, random, shutil
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import kit
from kit import *
from rw_util import T, S, KPart, MPart, AX_X, AX_Y, face_to, star, STAR_FRONT, tris, glb_nodes, sheet

# Farben (wie buildings.py, damit Türme und Gebäude zusammenpassen)
ST, ST_D, ST_L = "AEB6D2", "8690B0", "C6CDE4"        # blaugrauer Stein
BLUE, BLUE_L, BLUE_D = "3B6FD0", "5B93EE", "2C4F9E"   # blaues Metall
GOLD, GOLD_D = "F2B92E", "D99A1E"
DK, DARK, STEEL, STEEL_L = "363D52", "2E3340", "8A94A8", "C9D0DE"
WOOD, WOOD_D, WOOD_L = "B5682F", "7A4522", "D9A05A"
RED, RED_D, OLIVE, OLIVE_D, CREAM = "E04848", "A82F3A", "7F9040", "5C6B30", "E6D2A4"
SAND, SAND_D, ROPE = "E8B76E", "C99650", "D8C08A"
GLOW, CYAN, HOT, GREEN = "FFD24D", "5FE3FF", "FF4A3A", "58E86A"
SOOT, BRASS, HAZ_Y, HAZ_K = "1F2028", "E8B33A", "F2B92E", "23262E"
METAL, METAL_D, METAL_L = "7286B8", "3F4F7A", "8FA4D6"  # Metallmauer / Panzerplatten


def rng_for(name):
    return random.Random(sum((i + 1) * ord(c) for i, c in enumerate(name)))


def jit(c, rng, amt=0.06):
    """Leichte Farbschwankung je Brett/Stein (±6 %)."""
    return shade(c, 1.0 + rng.uniform(-amt, amt))


def _track(a, b):
    a = Vector(a); b = Vector(b)
    d = b - a
    return (a + b) * 0.5, d.length, d.to_track_quat("Z", "Y").to_matrix().to_4x4()


def beam(p, a, b, w, color, d=None, bevel=0.0):
    """Balken (Quader) von Punkt a nach b."""
    c, l, m = _track(a, b)
    p.box((w, d or w, l), (0, 0, 0), color, r=T(*c) @ m, bevel=bevel, segs=1)


def tube(p, a, b, rad, color, sides=6, r2=None, bevel=0.0):
    """Rohr (Zylinder) von Punkt a nach b."""
    c, l, m = _track(a, b)
    p.cyl(rad, l, (0, 0, 0), color, r=T(*c) @ m, r2=r2, sides=sides, bevel=bevel, segs=1)


def ring_m(R, deg, z=0.0):
    """Lage auf einem Kreis: 0° = vorn (-Y), positiv Richtung +X. Lokales -Y zeigt nach außen, X entlang des Kreises."""
    a = math.radians(deg)
    return T(math.sin(a) * R, -math.cos(a) * R, z) @ rot(0, 0, deg)


def ring_xy(R, deg):
    a = math.radians(deg)
    return math.sin(a) * R, -math.cos(a) * R


def plank_ring(p, R, z0, z1, n, color, rng, th=0.07, gap=0.93, skip=()):
    """Senkrechte Bretter rund um eine Trommel."""
    w = 2 * math.pi * R / n * gap
    for i in range(n):
        if i in skip:
            continue
        dz = rng.uniform(-0.05, 0.03)
        p.box((w, th, z1 - z0 + dz), (0, 0, 0), jit(color, rng, 0.09), r=ring_m(R, 360.0 / n * i, (z0 + z1 + dz) * 0.5))


def block_ring(p, R, z, h, n, cols, rng, depth=0.34, off=0.0, bevel=0.07, gap=0.9, segs=1):
    """Kranz aus Steinquadern."""
    w = 2 * math.pi * R / n * gap
    for i in range(n):
        p.box((w, depth, h), (0, 0, 0), jit(cols[i % len(cols)], rng), r=ring_m(R, 360.0 / n * (i + off), z + h * 0.5), bevel=bevel, segs=segs)


def sandbag(p, m, rng, size=(0.62, 0.36, 0.25)):
    c = jit(SAND if rng.random() < 0.7 else SAND_D, rng, 0.07)
    p.box(size, (0, 0, 0), c, r=m @ rot(0, 0, rng.uniform(-7, 7)), bevel=0.11, segs=1)


def sandbag_arc(p, R, a0, a1, rows, z0, rng):
    """Sandsack-Wall auf einem Kreisbogen (Winkel in Grad), Reihen versetzt gestapelt."""
    step = math.degrees(0.6 / R)
    for r in range(rows):
        n = max(1, int((a1 - a0) / step) - r)
        st = a0 + (a1 - a0 - (n - 1) * step) * 0.5
        for i in range(n):
            sandbag(p, ring_m(R - r * 0.03, st + i * step, z0 + 0.125 + r * 0.22), rng)


def sandbag_row(p, a, b, rows, rng):
    """Gerader Sandsack-Wall von a nach b (auf Höhe a.z)."""
    a = Vector(a); b = Vector(b)
    d = b - a
    yaw = math.degrees(math.atan2(d.y, d.x))
    n0 = max(1, int(round(d.length / 0.6)))
    for r in range(rows):
        n = n0 - r
        for i in range(n):
            q = a + d * ((i + 0.5 + r * 0.5) / n0)
            sandbag(p, T(q.x, q.y, q.z + 0.125 + r * 0.22) @ rot(0, 0, yaw), rng)


def ladder(p, a, b, w=0.5, color=WOOD_D, rung=None, th=0.07, step=0.34):
    """Leiter von Fußpunkt a nach Kopfpunkt b (Mitte der Leiter)."""
    a = Vector(a); b = Vector(b)
    d = b - a
    side = Vector((d.y, -d.x, 0.0))
    side = side.normalized() if side.length > 1e-4 else Vector((1, 0, 0))
    for s in (-1, 1):
        beam(p, a + side * (s * w * 0.5), b + side * (s * w * 0.5), th, color, d=th)
    n = max(2, int(d.length / step))
    for i in range(n):
        q = a + d * ((i + 0.6) / n)
        beam(p, q - side * (w * 0.5), q + side * (w * 0.5), th * 0.8, rung or shade(color, 1.25))


def ammo_crate(p, m, size=(0.72, 0.46, 0.36), color=OLIVE, stripe=HAZ_Y):
    """Geschlossene Munitionskiste mit Deckelband, Verschlüssen und Farbstreifen."""
    x, y, z = size
    p.box(size, (0, 0, 0), color, r=m @ T(0, 0, z * 0.5), bevel=0.04, segs=1)
    p.box((x * 1.03, y * 1.03, z * 0.14), (0, 0, 0), shade(color, 0.7), r=m @ T(0, 0, z * 0.74))
    p.box((x * 0.5, y * 1.05, z * 0.2), (0, 0, 0), stripe, r=m @ T(0, 0, z * 0.36))
    for s in (-1, 1):
        p.box((0.07, 0.05, 0.12), (0, 0, 0), STEEL_L, r=m @ T(s * x * 0.3, -y * 0.52, z * 0.72))


def ammo_open(p, m, size=(0.72, 0.46, 0.34), color=OLIVE, n=5, shell=BRASS, tip=None):
    """Offene Kiste mit sichtbaren Patronen/Granaten."""
    x, y, z = size
    p.box((x, y, z * 0.3), (0, 0, 0), shade(color, 0.8), r=m @ T(0, 0, z * 0.15))
    for s in (-1, 1):
        p.box((x, 0.05, z), (0, 0, 0), color, r=m @ T(0, s * (y * 0.5 - 0.025), z * 0.5))
        p.box((0.05, y, z), (0, 0, 0), color, r=m @ T(s * (x * 0.5 - 0.025), 0, z * 0.5))
    p.box((x * 1.0, 0.06, y * 0.95), (0, 0, 0), shade(color, 0.85), r=m @ T(0, y * 0.5 + 0.1, z * 0.75) @ rot(-62, 0, 0))   # aufgeklappter Deckel
    rr = min(x / n * 0.4, y * 0.3)
    for i in range(n):
        cx = -x * 0.5 + (i + 0.5) * x / n
        p.cyl(rr, z * 0.75, (0, 0, 0), shell, r=m @ T(cx, 0, z * 0.6), sides=6)
        p.cyl(rr, rr * 1.6, (0, 0, 0), tip or shade(shell, 0.7), r=m @ T(cx, 0, z * 0.975 + rr * 0.8), r2=0.01, sides=6)


def rivet(p, m, s=0.07, color=STEEL_L):
    p.box((s, s, s), (0, 0, 0), color, r=m @ rot(0, 45, 0))


def hazard(p, a, b, n, h, d, c1=HAZ_Y, c2=HAZ_K):
    """Gelb-schwarzer Warnstreifen von a nach b (n Abschnitte, Höhe h, Tiefe d)."""
    a = Vector(a); b = Vector(b)
    dv = b - a
    yaw = math.degrees(math.atan2(dv.y, dv.x))
    L = dv.length / n
    for i in range(n):
        q = a + dv * ((i + 0.5) / n)
        p.box((L, d, h), (0, 0, 0), c1 if i % 2 == 0 else c2, r=T(*q) @ rot(0, 0, yaw))


def soot(p, m, rx, rz, color=SOOT, sides=7):
    """Rußfleck: zwei flache, versetzte Scheiben in der lokalen XZ-Ebene (schaut nach lokal -Y)."""
    p.cyl(1.0, 0.016, (0, 0, 0), "34343E", r=m @ rot(90, 0, 0) @ S(rx, rz, 1.0), sides=sides)
    p.cyl(1.0, 0.016, (0, 0, 0), color, r=m @ T(rx * 0.12, -0.006, rz * 0.1) @ rot(90, 0, 0) @ rot(0, 0, 25) @ S(rx * 0.62, rz * 0.66, 1.0), sides=sides - 1)


def soot_flat(p, loc, rx, ry, color=SOOT, sides=8, yaw=0.0):
    """Brandfleck auf dem Boden / auf einer waagerechten Fläche."""
    p.cyl(1.0, 0.02, (0, 0, 0), color, r=T(*loc) @ rot(0, 0, yaw) @ S(rx, ry, 1.0), sides=sides)


def crack(p, m, pts, w=0.045, color=SOOT):
    """Riss: Linienzug in der lokalen XZ-Ebene (Punkte (x, z)), liegt knapp vor der Fläche."""
    for i in range(len(pts) - 1):
        a = m @ Vector((pts[i][0], -0.012, pts[i][1]))
        b = m @ Vector((pts[i + 1][0], -0.012, pts[i + 1][1]))
        c, l, tm = _track(a, b)
        p.box((w, 0.02, l + w * 0.6), (0, 0, 0), color, r=T(*c) @ tm)


def debris(p, pts, rng, cols=(ST, ST_D, ST_L), s=0.22):
    """Lose Brocken auf dem Boden."""
    for (x, y, z) in pts:
        k = s * rng.uniform(0.6, 1.25)
        p.box((k * 1.3, k, k * 0.8), (x, y, z + k * 0.3), jit(rng.choice(cols), rng, 0.1),
              r=rot(rng.uniform(-25, 25), rng.uniform(-25, 25), rng.uniform(0, 180)))


def flag(root, B, loc, h=2.6, size=(1.0, 0.66), name="sway_flag", pole=WOOD_D, color="flag", with_star=True, parent=None):
    """Mast in B, Tuch als eigenes Objekt `sway_flag*` in der Flaggenfarbe (Godot färbt es in der Spielerfarbe)."""
    x, y, z = loc
    B.cyl(0.055, h, (x, y, z + h * 0.5), pole, sides=6)
    B.ball(0.1, (x, y, z + h + 0.05), GOLD, subdiv=1)
    c = Part()
    w, hh = size
    c.box((w * 0.52, 0.05, hh), (w * 0.27, 0, 0), color)
    c.box((w * 0.52, 0.05, hh * 0.92), (w * 0.75, -0.05, -0.03), shade(color, 0.9), r=rot(0, 0, -9))
    if with_star:
        for sy in (-1, 1):
            star(c, (w * 0.36, sy * 0.035, 0), hh * 0.3, "white", 0.03, r=rot(90 * sy, 0, 0))
    return c.build(name, parent or root, (x + 0.05, y, z + h - hh * 0.5 - 0.06))


# ------------------------------------------------------------------ Verschattung, Speichern, Prüfen
_STATE = re.compile(r"^(lvmax\d+|lv\d+|dmg\d+|fill\d+)_")


def is_state(name):
    return _STATE.match(name) is not None


def _park(obs, on):
    """Blendet Objekte für kit.bake_ao aus (Attribut Col umbenennen = wird nicht eingerechnet, verschattet aber weiter)."""
    for o in obs:
        ca = o.data.color_attributes
        if on and "Col" in ca:
            ca["Col"].name = "ColP"
        elif not on and "ColP" in ca:
            ca["ColP"].name = "Col"
            ca.active_color = ca["Col"]
            ca.render_color_index = 0


def bake(strength=0.45, samples=12, distance=1.1, extra_occluders=(), gain=1.16):
    """Umgebungsverschattung in drei Durchgängen: Grundmodell ohne Zustands-Objekte, dann lvmax*/dmg*, dann lv*.
    So verdunkeln ausgeblendete Ausbau- und Schadensteile das Grundmodell nicht. Flaggen bleiben unverschattet
    (Godot tauscht ihre Farbe anhand des genauen Flaggenblaus)."""
    sc = bpy.context.scene
    meshes = [o for o in sc.objects if o.type == "MESH"]
    never = [o for o in meshes if "flag" in o.name or "banner" in o.name or o.name.endswith("_glow") or o in extra_occluders]
    state = [o for o in meshes if is_state(o.name) and o not in never]
    core = [o for o in meshes if o not in state and o not in never]
    g_low = [o for o in state if o.name.startswith("lvmax") or o.name.startswith("dmg") or o.name.startswith("fill")]
    g_up = [o for o in state if o not in g_low]
    _park(never, True)
    for grp in (core, g_low, g_up):
        if not grp:
            continue
        others = [o for o in core + state if o not in grp]
        _park(others, True)
        for o in state:                       # Zustands-Objekte anderer Gruppen verschatten nicht
            o.hide_render = o not in grp
        kit.bake_ao(strength=strength, samples=samples, distance=distance)
        _park(others, False)
    for o in state:
        o.hide_render = False
    _park(never, False)
    # Ausgleich: die Verschattung soll Fugen und Ecken abdunkeln, das Modell insgesamt aber nicht düsterer machen
    for o in core + state:
        colr = o.data.color_attributes["Col"]
        for d in colr.data:
            c = d.color
            d.color = (min(c[0] * gain, 1.0), min(c[1] * gain, 1.0), min(c[2] * gain, 1.0), c[3])


def report(name, limit=None):
    parts, total = [], 0
    for ob in bpy.context.scene.objects:
        if ob.type == "MESH" and not ob.hide_viewport:
            n = tris(ob)
            total += n
            parts.append("%s=%d" % (ob.name, n))
    empties = [ob.name for ob in bpy.context.scene.objects if ob.type == "EMPTY" and ob.parent is not None]
    warn = "  !!! ÜBER GRENZE %d" % limit if limit and total > limit else ""
    print("TRIS %-16s %5d%s  [%s]%s" % (name, total, warn, ", ".join(parts), ("  leer: " + ", ".join(empties)) if empties else ""), flush=True)
    return total


def finish(name, yaw=-35.0, pitch=24.0, size=256, copies=(), margin=1.12, hide=("lv4", "lv7", "dmg"), limit=6000, ao=True,
           strength=0.45, do_icon=True, extra_occluders=()):
    """Zählt Dreiecke, rechnet die Verschattung ein, speichert .blend/.glb und rendert das Symbol.
    hide = Namensanfänge von Objekten, die im Symbol fehlen (Ausbau ab Stufe 4/7, Schaden): das Symbol zeigt Stufe 1."""
    for ob in extra_occluders:
        ob.hide_viewport = True
    report(name, limit)
    if ao:
        bake(strength=strength, extra_occluders=extra_occluders)
    for ob in extra_occluders:
        bpy.data.objects.remove(ob, do_unlink=True)
    save(name)
    if not do_icon or os.environ.get("RW_NOICON"):
        return
    for ob in list(bpy.context.scene.objects):
        if hide and ob.name.startswith(tuple(hide)):
            bpy.data.objects.remove(ob, do_unlink=True)
    icon(name, size, yaw=yaw, pitch=pitch, margin=margin, samples=int(os.environ.get("RW_SAMPLES", "20")))
    for c in copies:
        shutil.copyfile(os.path.join(OUT_ICON, name + ".png"), os.path.join(OUT_ICON, c + ".png"))


def run(table, argv):
    for n in (argv[1:] or list(table.keys())):
        if n not in table:
            print("unbekannt:", n)
            continue
        table[n]()
        print("ok", n, flush=True)


# ------------------------------------------------------------------ Prüfliste der fertigen .glb-Dateien
TOWERS = ["t_mg", "t_watch", "t_cannon", "t_flame", "t_mortar", "t_tesla", "t_rocket", "t_ice", "t_aa", "t_mini"]
WALLS = ["wall_post_0", "wall_link_0", "wall_post_1", "wall_link_1", "wall_post_2", "wall_link_2", "wall_site"]
GATES = ["b_tor_0", "b_tor_1", "b_tor_2"]
SCAFFOLDS = ["b_scaffold_2x2", "b_scaffold_3x3", "b_scaffold_4x4", "b_scaffold_3x2", "b_scaffold_4x3", "b_scaffold_2x1"]
SMALL = ["b_stachel", "b_kleb", "b_mine", "b_laterne", "b_flagge", "b_blumen", "b_statue"]
NEED = {"t_": ["base", "head", "pitch", "muzzle", "work_1"], "wall_": ["body"], "b_tor": ["body", "door_l", "door_r", "lamp_open_glow", "lamp_closed_glow", "sway_flag", "bubble"],
        "b_scaffold": ["body", "sway_tarp"], "b_statue": ["body", "statue_slot", "statue_default"], "b_mine": ["body", "lamp_glow"], "b_flagge": ["body", "sway_flag"]}
LIMIT = {"t_": 6000, "wall_": 500, "b_tor": 6000, "b_scaffold": 2500, "b_": 2500}


def glb_tris(name):
    """Dreiecke und Knoten einer .glb-Datei (liest nur den JSON-Teil)."""
    import json, struct
    with open(os.path.join(OUT_GLB, name + ".glb"), "rb") as f:
        f.read(12)
        ln, _ = struct.unpack("<II", f.read(8))
        js = json.loads(f.read(ln))
    total = 0
    for m in js.get("meshes", []):
        for pr in m["primitives"]:
            acc = js["accessors"][pr["indices"]] if "indices" in pr else js["accessors"][pr["attributes"]["POSITION"]]
            total += acc["count"] // 3
    nodes = [n.get("name", "") for n in js.get("nodes", [])]
    meshes = [n.get("name", "") for n in js.get("nodes", []) if "mesh" in n]
    return total, nodes, meshes


def check(names):
    bad = 0
    print("%-16s %6s %4s  %s" % ("Modell", "Dreie.", "Obj", "Pflichtteile / Zustände"))
    for n in names:
        if not os.path.exists(os.path.join(OUT_GLB, n + ".glb")):
            print("%-16s FEHLT" % n); bad += 1
            continue
        t, nodes, meshes = glb_tris(n)
        need = next((v for k, v in NEED.items() if n.startswith(k)), ["body"])
        if n == "t_mini":
            need = [x for x in need if x != "work_1"]      # der Mini-Turm ist eine Fähigkeit: niemand bringt Munition
        lim = next((v for k, v in LIMIT.items() if n.startswith(k)), 6000)
        miss = [x for x in need if not any(nn == x or nn.startswith(x) for nn in nodes)]
        states = sorted({m.group(1) for m in (_STATE.match(x) for x in nodes) if m})
        extra = [x for x in nodes if x.startswith(("fx_", "work_", "bubble", "statue_slot", "muzzle"))]
        ok = not miss and t <= lim
        bad += 0 if ok else 1
        print("%-16s %6d %4d  %s%s  %s %s" % (n, t, len(meshes), "ok" if ok else "FEHLER", (" fehlt: " + ",".join(miss)) if miss else "",
                                              ",".join(states), ",".join(extra)))
    print("PRÜFUNG", "OK" if bad == 0 else "%d FEHLER" % bad)
    return bad


if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "check":
        sys.exit(1 if check(sys.argv[2:] or TOWERS + WALLS + GATES + SCAFFOLDS + SMALL) else 0)
