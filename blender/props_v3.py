"""Kulissen der lebendigen Basis (Auftrag V3, Paket 5).
Blumen (6 Sorten), Grasbüschel, Klee, hohe Halme, Laubbäume, Büsche, Farn, Strandfelsen, Holzsteg, Boot,
Weglaterne, Fußspur. Jede Kulisse besteht aus EINEM Objekt `body` (MultiMesh im Spiel); die Weglaterne hat
zusätzlich `lamp_glow`, das Boot schaukelt im Spiel als Ganzes.
Sehr sparsam gebaut: Gras und Blumen erscheinen tausendfach (Grasbüschel unter 30 Dreiecke, Blume unter 120).
Aufruf: python3 blender/props_v3.py [p_flower_1 ...]"""
import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from kit import *
from rw_util import *

WOOD, WOOD_D, WOOD_L = "B56A32", "7A4522", "D9A05E"
ROCK, ROCK_L, ROCK_D = "9A8F96", "B5ABB0", "6E6672"
STEM = "5E9A32"


def strip_bottom(p):
    """Entfernt nach unten zeigende Deckel (unsichtbar, spart bei Gras ein Drittel der Dreiecke)."""
    p.bm.normal_update()
    dead = [f for f in p.bm.faces if f.normal.z < -0.95]
    bmesh.ops.delete(p.bm, geom=dead, context="FACES")


def done(name, p, extra=None, strip=True):
    """Speichert eine Kulisse ohne Symbol (Kulissen erscheinen in keinem Menü)."""
    if strip:
        strip_bottom(p)
    root = empty(name)
    p.build("body", root)
    if extra:
        extra(root)
    report(name)
    save(name)


def blade(p, x, y, h, w, col, lean, az):
    """Ein Grashalm: dreiseitiger, spitzer Kegel."""
    m = T(x, y, 0) @ rot(0, 0, az) @ rot(0, lean, 0) @ T(0, 0, h * 0.5)
    p.cone(w, h, (0, 0, 0), col, r=m, sides=3)


# ================================================================== Gras, Klee, Halme
def gtuft(name, seed):
    reset(); rng = random.Random(seed); p = Part()
    cols = ("8FB02A", "A2C23A", "76A02C", "B4CF48")
    n = 4
    for i in range(n):
        a = 360.0 * i / n + rng.uniform(-25, 25)
        d = 0.0 if i == 0 else rng.uniform(0.05, 0.12)
        blade(p, math.cos(math.radians(a)) * d, math.sin(math.radians(a)) * d, rng.uniform(0.26, 0.42), 0.06,
              cols[(i + seed) % 4], rng.uniform(6, 26) if i else 4, a)
    done(name, p)


def clover():
    reset(); rng = random.Random(5); p = Part()
    for i in range(5):
        a = math.radians(i * 72 + rng.uniform(-20, 20))
        d = rng.uniform(0.08, 0.22)
        x, y = math.cos(a) * d, math.sin(a) * d
        z = rng.uniform(0.07, 0.12)
        for j in range(3):
            b = math.radians(j * 120 + i * 30)
            p.cyl(0.06, 0.02, (x + math.cos(b) * 0.05, y + math.sin(b) * 0.05, z), ("5FA832", "6DB83A")[j % 2], sides=5)
    p.cyl(0.035, 0.02, (0.05, 0.02, 0.17), "FFFFFF", sides=5)                      # weiße Kleeblüte
    p.cyl(0.03, 0.02, (-0.12, 0.1, 0.15), "F2B8D8", sides=5)
    done("p_clover", p)


def tallgrass():
    reset(); rng = random.Random(9); p = Part()
    for i in range(5):
        a = i * 72 + rng.uniform(-20, 20)
        d = rng.uniform(0.02, 0.1)
        blade(p, math.cos(math.radians(a)) * d, math.sin(math.radians(a)) * d, rng.uniform(0.6, 0.85), 0.045,
              ("9DBA3A", "B8C95A", "86A836")[i % 3], rng.uniform(5, 16), a)
    for i in range(2):                                                                 # Rispen
        a = math.radians(i * 170 + 30)
        p.ball(0.05, (math.cos(a) * 0.12, math.sin(a) * 0.12, 0.78 + i * 0.06), "D8CC7A", scale=(0.7, 0.7, 1.8), subdiv=1)
    done("p_tallgrass", p)


# ================================================================== Blumen (6 Sorten)
def stem(p, x, y, h, lean=(0.0, 0.0)):
    m = T(x, y, 0) @ rot(lean[0], lean[1], 0)
    p.cyl(0.022, h, (0, 0, 0), STEM, r=m @ T(0, 0, h * 0.5), sides=4)
    return m @ T(0, 0, h)


def flower_kind(name, kind, seed):
    reset(); rng = random.Random(seed); p = Part()
    spots = [(0.0, 0.0), (0.16, 0.08), (-0.1, 0.14)]
    if kind in ("lavendel", "sonne"):
        spots = [(0.0, 0.0), (0.14, -0.06)]
    for i, (x, y) in enumerate(spots):
        lean = (rng.uniform(-9, 9), rng.uniform(-9, 9))
        k = 1.0 - 0.15 * i
        if kind == "margerite":
            hm = stem(p, x, y, 0.36 * k, lean) @ rot(-15, 0, 0)
            p.cyl(0.12 * k, 0.025, (0, 0, 0), "FFFFFF", r=hm, sides=8)
            p.cyl(0.05 * k, 0.05, (0, 0, 0), "FFD23E", r=hm @ T(0, 0, 0.02), sides=6)
        elif kind == "mohn":
            hm = stem(p, x, y, 0.42 * k, lean)
            p.cyl(0.08 * k, 0.1 * k, (0, 0, 0), "E2332B", r=hm @ T(0, 0, 0.04), r2=0.13 * k, sides=6)
            p.cyl(0.035 * k, 0.04, (0, 0, 0), "2A1E22", r=hm @ T(0, 0, 0.09), sides=5)
        elif kind == "glocke":
            hm = stem(p, x, y, 0.38 * k, lean) @ rot(0, 70, 0) @ T(0, 0, 0.05)
            p.cyl(0.03, 0.12 * k, (0, 0, 0), "6E7FF0", r=hm @ rot(0, 180, 0) @ T(0, 0, 0.06), r2=0.08 * k, sides=6)
            p.cyl(0.03, 0.1 * k, (0, 0, 0), "8A96F5", r=T(x, y, 0.3 * k) @ rot(0, -60, 40) @ rot(0, 180, 0) @ T(0, 0, 0.05), r2=0.07 * k, sides=6)
        elif kind == "loewenzahn":
            hm = stem(p, x, y, 0.28 * k, lean)
            if i == 2:
                p.ball(0.08, (0, 0, 0), "F4F6FA", r=hm @ T(0, 0, 0.05), subdiv=1)        # Pusteblume
            else:
                p.cyl(0.09 * k, 0.05, (0, 0, 0), "FFC81E", r=hm, r2=0.07 * k, sides=8)
            p.ball(0.12, (0, 0, 0), "5FA832", r=T(x, y, 0.03) @ rot(0, 0, i * 70), scale=(1.5, 0.4, 0.15), subdiv=1)
        elif kind == "lavendel":
            for j in range(3):
                a = math.radians(j * 120 + i * 40)
                hm = stem(p, x + math.cos(a) * 0.04, y + math.sin(a) * 0.04, 0.32, (math.cos(a) * 10, math.sin(a) * 10))
                p.cyl(0.035, 0.2, (0, 0, 0), ("9C6FD8", "B48AE8", "8257C8")[j], r=hm @ T(0, 0, 0.08), r2=0.015, sides=5)
        else:  # sonnenblume
            hm = stem(p, x, y, (0.9 if i == 0 else 0.7), (lean[0] * 0.4, lean[1] * 0.4)) @ rot(-35, 0, 0)
            p.cyl(0.07, 0.025, (0, 0, 0), "5FA832", r=T(x, y, 0.35) @ rot(0, 70, 0), r2=0.02, sides=4)
            p.cyl(0.2 if i == 0 else 0.16, 0.04, (0, 0, 0), "FFC21E", r=hm, sides=10)
            p.cyl(0.1 if i == 0 else 0.08, 0.06, (0, 0, 0), "6B3A1E", r=hm @ T(0, 0, 0.02), sides=8)
    done(name, p)


# ================================================================== Bäume, Büsche, Farn
def leaf_tree(name, h, seed):
    reset(); rng = random.Random(seed); p = Part()
    g = ("4E9A34", "5DA83A")[seed % 2]
    p.cyl(0.24, h * 0.5, (0, 0, h * 0.25), "8A5A30", r2=0.17, sides=7)
    p.cyl(0.34, 0.16, (0, 0, 0.08), "7A4E2A", r2=0.24, sides=7)
    limb(p, (0, 0, h * 0.38), (0.45, 0.1, h * 0.58), 0.09, 0.06, "8A5A30", sides=5)
    blobs = [(0, 0, h * 0.68, 1.35), (0.7, 0.2, h * 0.58, 0.95), (-0.65, -0.3, h * 0.6, 0.95), (0.1, -0.6, h * 0.62, 0.85),
             (-0.2, 0.6, h * 0.66, 0.9), (0.15, 0.1, h * 0.88, 0.85)]
    for i, (x, y, z, r) in enumerate(blobs):
        p.ball(r * h / 4.8, (x, y, z), shade(g, (1.0, 0.86, 0.92, 1.08, 0.95, 1.18)[i]), scale=(1, 1, 0.86), subdiv=2)
    for i in range(6):                                                                  # Äpfel / Blüten
        a = math.radians(i * 60 + seed * 13)
        p.ball(0.08, (math.cos(a) * 1.05, math.sin(a) * 1.05, h * (0.58 + 0.04 * (i % 3))), ("E23B3B", "FFFFFF")[seed % 2], subdiv=1)
    done(name, p, strip=False)


def shrub(name, seed):
    reset(); rng = random.Random(seed); p = Part()
    g = ("4F8A2E", "5E9A32", "6AA83C")[seed % 3]
    n = 3 + seed % 2
    for i in range(n):
        a = math.radians(i * 360.0 / n + rng.uniform(-20, 20))
        d = 0.0 if i == 0 else 0.35
        r = rng.uniform(0.38, 0.5) * (1.15 if i == 0 else 1.0)
        p.ball(r, (math.cos(a) * d, math.sin(a) * d, r * 0.75), shade(g, rng.uniform(0.88, 1.15)), scale=(1, 1, 0.85), subdiv=2)
    if seed == 3:                                                                       # Beeren
        for i in range(5):
            a = math.radians(i * 72)
            p.ball(0.06, (math.cos(a) * 0.45, math.sin(a) * 0.45, 0.55), "3C4FC8", subdiv=1)
    done(name, p)


def fern():
    reset(); rng = random.Random(4); p = Part()
    for i in range(7):
        a = i * 360.0 / 7 + rng.uniform(-10, 10)
        m = rot(0, 0, a) @ rot(0, -48, 0) @ T(0, 0, 0.32)
        p.ball(1.0, (0, 0, 0), ("4E8F34", "5EA03C")[i % 2], r=T(0, 0, 0.05) @ m, scale=(0.13, 0.05, 0.4), subdiv=1)
    done("p_fern", p)


# ================================================================== Küste
def beach_rock(name, seed):
    reset(); rng = random.Random(seed); p = Part()
    base = ("8E8A92", "9A9198")[seed % 2]
    lay = [((1.6, 1.3, 1.1), (0, 0, 0.45)), ((1.0, 0.9, 0.8), (0.8, 0.4, 0.3)), ((0.8, 0.7, 0.55), (-0.7, -0.4, 0.22))]
    for i, (s, loc) in enumerate(lay):
        p.box(s, loc, shade(base, (1.0, 1.12, 0.9)[i]), r=rot(rng.uniform(-8, 8), rng.uniform(-8, 8), rng.uniform(0, 90)), bevel=min(s) * 0.3, segs=1)
    p.ball(0.3, (0.1, -0.3, 0.95), "6FAE3A", scale=(1.4, 1.0, 0.25), subdiv=1)              # Algen / Moos
    done(name, p)


def jetty():
    """Holzsteg 3 m breit, 12 m lang entlang -Y (vorn = See), Ursprung am Landende."""
    reset(); p = Part()
    n = 20
    for i in range(n):
        y = -0.3 - i * 0.6
        p.box((3.0, 0.54, 0.14), (0, y, 0.55), (WOOD, shade(WOOD, 1.12), shade(WOOD, 0.9))[i % 3],
              r=rot(0, 0, (0.8, -0.6, 0.4, -0.9)[i % 4]), bevel=0.03, segs=1)
    for sx in (-1.2, 1.2):
        p.box((0.22, 12.0, 0.18), (sx, -6.0, 0.4), WOOD_D)
        for y in (-0.4, -4.0, -8.0, -11.7):
            p.cyl(0.16, 2.2, (sx * 1.08, y, -0.5), "6B4424", sides=8)
            p.cyl(0.19, 0.08, (sx * 1.08, y, 0.62), WOOD_L, sides=8)
    for y in (-11.7,):                                                                  # Poller mit Tau
        p.cyl(0.13, 0.5, (1.0, y + 0.4, 0.85), "5E3A20", sides=8)
        p.torus(0.15, 0.04, (1.0, y + 0.4, 0.8), "E8D9A8", seg=10, tseg=4)
    for i in range(3):                                                                  # Kisten und Netz
        p.box((0.5, 0.5, 0.5), (-0.9 + i * 0.05, -2.5 - i * 0.55, 0.88 + (0.0 if i < 2 else 0.0)), (WOOD_L, WOOD, WOOD_L)[i], bevel=0.04, segs=1)
    p.cyl(0.32, 0.25, (0.8, -5.5, 0.75), "3E7FA8", sides=10)
    p.cyl(0.3, 0.3, (-0.9, -9.0, 0.78), "D9443A", sides=10, bevel=0.05, segs=1)
    done("p_jetty", p, strip=False)


def boat():
    """Kleines Fischerboot (Rumpf blau-weiß, Steuerhaus), 6 m lang entlang Y, Wasserlinie bei z = 0."""
    reset(); p = Part()
    p.box((2.2, 5.4, 0.9), (0, 0, 0.1), "2F6FC8", bevel=0.4, segs=3)
    p.box((2.0, 5.0, 0.25), (0, 0, 0.62), "F4F6FA", bevel=0.1, segs=1)
    p.cone(1.1, 1.3, (0, -3.1, 0.25), "2F6FC8", r=rot(90, 0, 0) @ S(1.0, 0.55, 1.0), sides=8)
    p.box((1.8, 4.6, 0.12), (0, 0.1, 0.72), WOOD_L)
    p.box((1.3, 1.4, 1.2), (0, 0.9, 1.35), "F4F6FA", bevel=0.1, segs=1)
    p.box((1.45, 1.6, 0.16), (0, 0.9, 2.0), "D9443A", bevel=0.06, segs=1)
    p.box((1.1, 0.06, 0.45), (0, 0.18, 1.5), "6FC0F0")
    p.cyl(0.06, 2.4, (0, -1.0, 1.9), WOOD_D, sides=6)
    p.box((0.9, 0.04, 0.5), (0.45, -1.0, 2.7), "026AED")
    p.cyl(0.2, 0.3, (0.6, 2.0, 0.95), "FFD23E", sides=8)
    p.torus(0.3, 0.07, (-1.12, -0.6, 0.65), "D9443A", r=rot(0, 90, 0), seg=12, tseg=5)
    done("p_boat", p, strip=False)


# ================================================================== Kleinteile
def path_lamp():
    reset(); p = Part()
    p.cyl(0.2, 0.25, (0, 0, 0.12), "5A5F70", r2=0.15, sides=8)
    p.cyl(0.07, 2.2, (0, 0, 1.3), "3A4152", sides=8)
    p.box((0.3, 0.3, 0.08), (0, 0, 2.38), "3A4152", bevel=0.03, segs=1)
    for sx in (-1, 1):                                       # schmale Eckstreben, das Glas bleibt sichtbar
        for sy in (-1, 1):
            p.box((0.04, 0.04, 0.42), (sx * 0.18, sy * 0.18, 2.62), "3A4152")
    p.box((0.3, 0.3, 0.05), (0, 0, 2.85), "3A4152")
    p.cone(0.2, 0.2, (0, 0, 2.97), "3A4152", sides=4)
    g = Part()
    g.box((0.34, 0.34, 0.4), (0, 0, 0), "FFD24D", bevel=0.03, segs=1)
    def extra(root):
        g.build("lamp_glow", root, (0, 0, 2.62))
    done("p_path_lamp", p, extra, strip=False)


def footprint():
    reset(); p = Part()
    for sx, y in ((-0.12, 0.0), (0.12, 0.3)):
        p.box((0.13, 0.26, 0.02), (sx, y, 0.01), "6B4A2A", bevel=0.05, segs=1)
    done("p_footprint", p)


TABLE = {
    "p_gtuft_1": (gtuft, "p_gtuft_1", 1), "p_gtuft_2": (gtuft, "p_gtuft_2", 2),
    "p_clover": clover, "p_tallgrass": tallgrass,
    "p_flower_1": (flower_kind, "p_flower_1", "margerite", 1), "p_flower_2": (flower_kind, "p_flower_2", "mohn", 2),
    "p_flower_3": (flower_kind, "p_flower_3", "glocke", 3), "p_flower_4": (flower_kind, "p_flower_4", "loewenzahn", 4),
    "p_flower_5": (flower_kind, "p_flower_5", "lavendel", 5), "p_flower_6": (flower_kind, "p_flower_6", "sonne", 6),
    "p_tree_leaf_1": (leaf_tree, "p_tree_leaf_1", 4.6, 1), "p_tree_leaf_2": (leaf_tree, "p_tree_leaf_2", 5.6, 2),
    "p_shrub_1": (shrub, "p_shrub_1", 1), "p_shrub_2": (shrub, "p_shrub_2", 2), "p_shrub_3": (shrub, "p_shrub_3", 3),
    "p_fern": fern, "p_beach_rock_1": (beach_rock, "p_beach_rock_1", 1), "p_beach_rock_2": (beach_rock, "p_beach_rock_2", 2),
    "p_jetty": jetty, "p_boat": boat, "p_path_lamp": path_lamp, "p_footprint": footprint,
}

if __name__ == "__main__":
    run(TABLE, sys.argv)
