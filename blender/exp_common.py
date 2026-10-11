"""Gemeinsame Helfer für die Modelle der Expedition und der Außenbasen (outpost.py, exp_nodes.py, exp_barriers.py,
exp_areas.py). Baut auf kit.py und den Helfern aus buildings.py auf."""
import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from buildings import *
from rw_util import MPart, KPart, limb, face_to, AX_X, AX_Y, vary
import rw_util as RU

GREEN, GREEN_D, GREEN_L = "4FA84A", "357A3C", "7CCB52"
LEAF, LEAF_D, LEAF_L = "5E9A32", "47782A", "86BC3C"
BARK, CUT, CUT_D = "8A5A30", "EBC07E", "C8924E"
ROCK, ROCK_L, ROCK_D = "9A8F96", "B5ABB0", "6E6672"
RUST, RUST_D, RUST_L = "A8562A", "7E4424", "C9763A"
SNOW, ICE, ICE_D, ICE_L = "F4F8FF", "8FD6F5", "5FA9DC", "CDEFFF"
TEAL, TEAL_D = "2FC1B0", "1F8F88"
SLIME, SLIME_D, SLIME_L = "8BC43A", "5E9A2C", "C8EE5A"
CONC, CONC_D = "C2BDB2", "9A968E"
BRICK, BRICK_D = "C0603E", "954630"
EARTH, EARTH_D = "D9B37A", "A8824E"
YEL, ORANGE = "F7C531", "F28A1E"

REG = {}


def model(*names):
    """Trägt eine Baufunktion f(name) unter einem oder mehreren Modellnamen ein."""
    def deco(f):
        for n in names:
            REG[n] = (lambda n=n, f=f: f(n))
        return f
    return deco


def _level(o):
    n = o.name
    if n.startswith("lv") and n[2:3].isdigit():
        return int(n[2])
    return 1


def ao_staged():
    """bake_ao() je Ausbaustufe: Teile späterer Stufen (lvN_*) verschatten die früheren nicht, sonst hätte Stufe 1
    dunkle Flecken dort, wo später ein Anbau steht."""
    obs = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    levels = sorted({_level(o) for o in obs})
    if len(levels) <= 1:
        bake_ao()
        return
    for lv in levels:
        saved = []
        for o in obs:
            l = _level(o)
            saved.append((o, o.name, o.hide_render))
            if l > lv:
                o.hide_render = True
            if l != lv and not o.name.endswith("_glow"):
                o.name = o.name + "__skip_glow"          # bake_ao lässt *_glow aus
        bake_ao()
        for o, n, h in saved:
            o.name = n
            o.hide_render = h


def fin(name, yaw=-35.0, pitch=26.0, lv1=False, keep_glb=True, size=256, margin=1.12, ao=True):
    """Verschattung einrechnen, zählen, speichern, Symbol rendern. lv1=True: zusätzlich icons/<name>_1.png ohne lvN-Teile."""
    if ao:
        ao_staged()
    RU.report(name)
    save(name)
    if not keep_glb:
        os.remove(os.path.join(OUT_GLB, name + ".glb"))
    icon(name, size, yaw=yaw, pitch=pitch, margin=margin)
    if lv1:
        for ob in list(bpy.context.scene.objects):
            if ob.name.startswith("lv"):
                bpy.data.objects.remove(ob, do_unlink=True)
        icon(name + "_1", size, yaw=yaw, pitch=pitch, margin=margin)


def pyr(p, c, w, d, h, color, top=0.04, yaw=0.0):
    """Zeltdach (Pyramide) über einem Rechteck w x d, c = Mitte der Unterkante."""
    k = 0.7071
    p.cyl(1.0, h, (0, 0, 0), color, r=T(c[0], c[1], c[2] + h * 0.5) @ rot(0, 0, yaw) @ S(w * k, d * k, 1) @ rot(0, 0, 45), r2=top, sides=4)


def mono(p, c, w, d, drop, color, thick=0.14, rim=None):
    """Pultdach: Platte w x d um c, fällt nach hinten (+Y) um `drop` Meter ab."""
    a = math.degrees(math.atan2(drop, d))
    p.box((w, math.hypot(d, drop), thick), c, color, r=rot(-a, 0, 0), bevel=0.05, segs=1)
    if rim:
        p.box((w + 0.06, 0.12, thick + 0.08), (c[0], c[1] - d * 0.5, c[2] + drop * 0.5), rim, r=rot(-a, 0, 0), bevel=0.03, segs=1)


def door(p, loc, w=0.9, h=1.8, color=WOOD_D, frame=DK, knob=GOLD):
    """Tür an einer Vorderwand (zeigt nach -Y). loc = Mitte der Unterkante auf der Wand."""
    x, y, z = loc
    p.box((w + 0.2, 0.1, h + 0.1), (x, y - 0.02, z + h * 0.5 + 0.05), frame, bevel=0.03, segs=1)
    p.box((w, 0.1, h), (x, y - 0.07, z + h * 0.5), color, bevel=0.03, segs=1)
    p.box((0.04, 0.12, h - 0.2), (x, y - 0.075, z + h * 0.5), shade(color, 0.75))
    p.box((0.1, 0.08, 0.1), (x + w * 0.3, y - 0.13, z + h * 0.48), knob, bevel=0.03, segs=1)


def lamp_post(B, L, loc, h=2.4, pole=DK, glow=GLOW):
    """Laternenmast: Mast in B, Leuchtkörper in L (wird als *_glow gebaut)."""
    x, y, z = loc
    B.cyl(0.14, 0.14, (x, y, z + 0.07), shade(pole, 0.9), sides=8)
    B.cyl(0.055, h, (x, y, z + h * 0.5), pole, sides=6)
    B.box((0.34, 0.34, 0.06), (x, y, z + h + 0.01), pole, bevel=0.02, segs=1)
    L.box((0.24, 0.24, 0.3), (x, y, z + h + 0.19), glow, bevel=0.06, segs=1)
    pyr(B, (x, y, z + h + 0.34), 0.42, 0.42, 0.2, pole)


def pennant(root, B, loc, h=2.0, color=RED, name="sway_flag", size=(0.9, 0.6), emblem=None, pole=WOOD_D):
    """Mast mit Fahne (eigenes sway-Objekt). emblem: None, "star", "cross"."""
    x, y, z = loc
    B.cyl(0.055, h, (x, y, z + h * 0.5), pole, sides=6)
    B.ball(0.1, (x, y, z + h + 0.05), GOLD, subdiv=1)
    c = Part()
    w, hh = size
    c.box((w * 0.55, 0.05, hh), (w * 0.28, 0, 0), color, bevel=0.02, segs=1)
    c.box((w * 0.5, 0.05, hh * 0.92), (w * 0.75, -0.04, -0.03), shade(color, 0.88), bevel=0.02, segs=1, r=rot(0, 0, -8))
    if emblem == "star":
        star(c, (w * 0.4, 0, 0), hh * 0.3, "white", 0.09)
    elif emblem == "cross":
        c.box((hh * 0.5, 0.09, hh * 0.17), (w * 0.4, 0, 0), "white")
        c.box((hh * 0.17, 0.09, hh * 0.5), (w * 0.4, 0, 0), "white")
    return c.build(name, root, (x + 0.05, y, z + h - hh * 0.5 - 0.06))


def rockc(p, size, loc, color, rng, k=0.26):
    p.box(size, loc, color, r=rot(rng.uniform(-12, 12), rng.uniform(-12, 12), rng.uniform(0, 90)), bevel=min(size) * k, segs=1)


def tuft(p, x, y, z=0.0, n=5, k=1.0, seed=1, cols=("8FB02A", "A9CC3C", "6F9A2A")):
    rng = random.Random(seed)
    for i in range(n):
        a = 360.0 * i / n + rng.uniform(-15, 15)
        tilt = rng.uniform(8, 30) if i else 0
        h = rng.uniform(0.34, 0.56) * k
        p.cone(0.075 * k, h, (0, 0, 0), cols[i % len(cols)], r=T(x, y, z) @ rot(0, 0, a) @ T(0.05 * k, 0, 0) @ rot(0, tilt, 0) @ T(0, 0, h * 0.5), sides=4)


def mushroom(p, x, y, z=0.0, k=1.0, cap=RED):
    p.cyl(0.13 * k, 0.4 * k, (x, y, z + 0.2 * k), "F4E8D2", r2=0.1 * k, sides=6)
    p.ball(1.0, (x, y, z + 0.42 * k), cap, scale=(0.36 * k, 0.36 * k, 0.26 * k), subdiv=2)
    for a in (20, 140, 260):
        ra = math.radians(a)
        p.ball(0.06 * k, (x + math.cos(ra) * 0.2 * k, y + math.sin(ra) * 0.2 * k, z + 0.61 * k), "FFFFFF", scale=(1, 1, 0.5), subdiv=1)


def log_(p, m, r, ln, sides=10, bark=BARK):
    """Stamm entlang der lokalen Z-Achse von m mit hellen Schnittflächen."""
    p.cyl(r, ln, (0, 0, 0), bark, r=m, sides=sides)
    p.cyl(r * 0.84, ln + 0.03, (0, 0, 0), CUT, r=m, sides=sides)
    p.cyl(r * 0.42, ln + 0.045, (0, 0, 0), CUT_D, r=m, sides=sides)


def coin_(p, m, r=0.2, h=0.06, lp=False):
    if lp:
        p.cyl(r, h, (0, 0, 0), "FFC824", r=m, sides=8)
        p.cyl(r * 0.62, h + 0.015, (0, 0, 0), "FFE98A", r=m, sides=6)
        return
    p.cyl(r, h, (0, 0, 0), "FFC824", r=m, sides=10, bevel=h * 0.3, segs=1)
    p.cyl(r * 0.66, h + 0.015, (0, 0, 0), "FFE98A", r=m, sides=8)


def tire(p, m, r=0.4, w=0.28, hub=None, lp=False):
    """Reifen um die lokale Z-Achse von m. lp = sparsame Fassung für Haufen."""
    p.cyl(r, w, (0, 0, 0), "23262E", r=m, sides=10 if lp else 12, bevel=r * 0.25, segs=1 if lp else 2)
    p.cyl(r * 0.5, w + 0.02, (0, 0, 0), hub or "3A3E4A", r=m, sides=6 if lp else 8)


def sack(p, loc, k=1.0, color="D9C08A", yaw=0.0):
    x, y, z = loc
    p.ball(1.0, (x, y, z + 0.3 * k), color, r=rot(0, 0, yaw), scale=(0.34 * k, 0.28 * k, 0.34 * k), subdiv=3)
    p.cyl(0.1 * k, 0.14 * k, (x, y, z + 0.66 * k), shade(color, 0.9), r2=0.16 * k, sides=6)
    p.cyl(0.11 * k, 0.05 * k, (x, y, z + 0.6 * k), WOOD_D, sides=6)


def corr(p, size, loc, color, n=6, axis="x", face=-1):
    """Wellblech-Rippen auf einer Wand: n senkrechte Leisten. axis = Richtung, entlang der die Wand läuft."""
    w, t, h = size
    for i in range(n):
        o = -w * 0.5 + (i + 0.5) * w / n
        if axis == "x":
            p.box((w / n * 0.42, t, h), (loc[0] + o, loc[1], loc[2]), color)
        else:
            p.box((t, w / n * 0.42, h), (loc[0], loc[1] + o, loc[2]), color)


def wheel_lp(root, name, x, y, r, w=0.34, hub="C9CED8"):
    """Rad wie vehicles.wheel, aber sparsamer (ca. 400 Dreiecke). Ursprung in der Achse, dreht um X."""
    p = Part()
    p.cyl(r, w, (0, 0, 0), "tire", r=rot(0, 90, 0), sides=14, bevel=r * 0.26, segs=2)
    for i in range(8):
        a = math.radians(i * 45)
        p.box((w * 0.9, 0.13, 0.07), (0, math.cos(a) * r, math.sin(a) * r), "14161C", r=rot(i * 45 + 90, 0, 0))
    p.cyl(r * 0.5, w + 0.04, (0, 0, 0), hub, r=rot(0, 90, 0), sides=10, bevel=0.03, segs=1)
    p.cyl(r * 0.2, w + 0.1, (0, 0, 0), "5E6678", r=rot(0, 90, 0), sides=6)
    return p.build(name, root, (x, y, r))
