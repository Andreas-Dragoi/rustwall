"""Kulissen p_*, Rohstoff-Symbole res_* und Kisten-Symbole chest_*.
Kulissen bestehen aus EINEM Objekt `body` (MultiMesh), Ursprung am Boden; interaktive Modelle dürfen mehr Objekte haben.
Aufruf: python3 blender/props.py [p_rock_1 ...]"""
import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from kit import *
from rw_util import *

WOOD, WOOD_D, WOOD_L, BARK = "B56A32", "7A4522", "D9A05E", "8A5A30"
CUT, CUT_D = "EBC07E", "C8924E"
ROCK, ROCK_L, ROCK_D = "9A8F96", "B5ABB0", "6E6672"
STEEL, STEEL_D, DARK = "8A94A8", "5E6678", "2E3340"
GOLD, GOLD_D, GOLD_L = "FFC824", "E0961A", "FFE98A"
RED, RED_D = "DD4343", "A82E38"
LEAF, LEAF_D, LEAF_L = "5E9A32", "47782A", "86BC3C"


def one(name, p, yaw=-30.0, pitch=20.0, extra=None, **kw):
    """Schließt eine Kulisse aus einem Objekt `body` ab."""
    root = empty(name)
    p.build("body", root)
    if extra:
        extra(root)
    finish(name, yaw=yaw, pitch=pitch, **kw)


def chunk(p, size, loc, color, rz=0.0, rx=0.0, ry=0.0, k=0.24):
    """Kantiger Brocken (Fels, Stein)."""
    p.box(size, loc, color, r=rot(rx, ry, rz), bevel=min(size) * k, segs=1)


def coin(p, m, r=0.26, h=0.065, face=True):
    p.cyl(r, h, (0, 0, 0), GOLD, r=m, sides=14, bevel=h * 0.3, segs=1)
    if face:
        p.cyl(r * 0.72, h + 0.012, (0, 0, 0), GOLD_D, r=m, sides=12)
        p.cyl(r * 0.6, h + 0.02, (0, 0, 0), GOLD_L, r=m, sides=12)


def log(p, m, r, ln, sides=10, bark=BARK):
    """Baumstamm entlang der lokalen Z-Achse von m, mit hellen Schnittflächen."""
    p.cyl(r, ln, (0, 0, 0), bark, r=m, sides=sides)
    p.cyl(r * 0.86, ln + 0.03, (0, 0, 0), CUT, r=m, sides=sides)
    p.cyl(r * 0.45, ln + 0.045, (0, 0, 0), CUT_D, r=m, sides=sides)


def gear(p, m, R, th, color, teeth=8, hole="2E3340"):
    p.cyl(R * 0.8, th, (0, 0, 0), color, r=m, sides=16, bevel=th * 0.2, segs=1)
    for i in range(teeth):
        p.box((R * 0.36, R * 0.36, th * 0.9), (0, 0, 0), color, r=m @ rot(0, 0, i * 360.0 / teeth) @ T(R * 0.86, 0, 0), bevel=R * 0.07, segs=1)
    p.cyl(R * 0.5, th * 1.25, (0, 0, 0), shade(color, 1.18), r=m, sides=14, bevel=th * 0.15, segs=1)
    p.cyl(R * 0.24, th * 1.3, (0, 0, 0), hole, r=m, sides=10)


def puffy_star(p, m, R, color=GOLD, thick=0.14):
    """Dicker Stern in der lokalen XY-Ebene von m."""
    star(p, (0, 0, 0), R, color, R * 0.42, r=m, inner=0.45)


def mushroom(p, x, y, k=1.0, cap=RED, lean=0.0):
    m = T(x, y, 0) @ rot(lean, lean * 0.5, 0)
    p.cyl(0.15 * k, 0.42 * k, (0, 0, 0), "F4E8D2", r=m @ T(0, 0, 0.21 * k), r2=0.11 * k, sides=8, bevel=0.03 * k, segs=1)
    p.cyl(0.36 * k, 0.05 * k, (0, 0, 0), "EAD9BC", r=m @ T(0, 0, 0.43 * k), sides=10)
    p.ball(1.0, (0, 0, 0), cap, r=m @ T(0, 0, 0.44 * k), scale=(0.4 * k, 0.4 * k, 0.3 * k), subdiv=3 if k >= 1.0 else 2)
    for a, e in ((20, 50), (140, 40), (260, 55), (80, 82)):
        ra, re = math.radians(a), math.radians(e)
        n = Vector((math.cos(ra) * math.cos(re), math.sin(ra) * math.cos(re), math.sin(re)))
        q = Vector((n.x * 0.4 * k, n.y * 0.4 * k, n.z * 0.3 * k))
        nn = Vector((n.x / 0.4, n.y / 0.4, n.z / 0.3)).normalized()
        p.ball(0.07 * k, (0, 0, 0), "FFFFFF", r=m @ T(q.x, q.y, 0.44 * k + q.z) @ face_to(nn), scale=(1, 1, 0.3), subdiv=1)


def grass_tuft(p, x, y, n=7, k=1.0, seed=1, cols=("8FB02A", "A9CC3C", "6F9A2A")):
    rng = random.Random(seed)
    for i in range(n):
        a = 360.0 * i / n + rng.uniform(-15, 15)
        tilt = rng.uniform(8, 30) if i else 0
        h = rng.uniform(0.34, 0.56) * k
        m = T(x, y, 0) @ rot(0, 0, a) @ T(0.05 * k, 0, 0) @ rot(0, tilt, 0) @ T(0, 0, h * 0.5)
        p.cone(0.075 * k, h, (0, 0, 0), cols[i % len(cols)], r=m, sides=4)


# ================================================================== Bäume
def pine(name, h, seed, kind="pine"):
    reset(); rng = random.Random(seed); p = Part()
    g = {"pine": "3F9148", "dense": "2B6140", "snow": "3C7A55"}[kind]
    p.cyl(0.32, h * 0.3, (0, 0, h * 0.15), WOOD_D, r2=0.2, sides=8)
    p.cyl(0.42, 0.2, (0, 0, 0.1), shade(WOOD_D, 0.85), r2=0.3, sides=8)
    n = 3 if h < 5.2 else 4
    z0 = h * 0.17
    span = h - z0
    th = span * (0.52 if n == 3 else 0.43)
    R0 = h * (0.3 if kind != "dense" else 0.33)
    for i in range(n):
        r = R0 * (1.0 - 0.62 * i / (n - 1))
        zb = z0 + i * (span - th) / (n - 1)
        m = T(rng.uniform(-0.06, 0.06), rng.uniform(-0.06, 0.06), zb) @ rot(rng.uniform(-4, 4), rng.uniform(-4, 4), rng.uniform(0, 360))
        c = shade(g, 1.0 + 0.13 * i)
        p.cyl(r * 0.7, 0.26, (0, 0, 0), shade(c, 0.72), r=m, r2=r, sides=12)
        p.cone(r, th, (0, 0, 0), c, r=m @ T(0, 0, 0.13 + th * 0.5), sides=12)
        if kind == "snow":
            k = 0.66 if i < n - 1 else 0.8
            p.cone(r * k, th * k, (0, 0, 0), "F4F8FF", r=m @ T(0, 0, 0.13 + th - th * k * 0.5 + 0.05), sides=12)
    if kind == "dense":
        mushroom(p, 0.75, -0.55, 0.7, lean=6)
        mushroom(p, -0.6, -0.75, 0.5, lean=-8)
        mushroom(p, 0.25 + 0.3 * (seed % 2), -0.95, 0.4, cap="E8862A")
    if kind == "snow":
        p.ball(1.0, (0.2, -0.3, 0.05), "F4F8FF", scale=(1.0, 0.9, 0.22), subdiv=2)
    one(name, p, pitch=14)


def cactus(name, h, seed):
    reset(); rng = random.Random(seed); p = Part()
    g, gl = "5FA04C", "7DBE5C"
    p.cyl(0.5, h, (0, 0, h * 0.5), g, sides=12, bevel=0.5, segs=4)
    for i in range(6):                                                    # helle Rippen
        a = math.radians(i * 60)
        p.box((0.09, 0.09, h * 0.74), (math.cos(a) * 0.47, math.sin(a) * 0.47, h * 0.46), gl, r=rot(0, 0, i * 60), bevel=0.04, segs=1)
    arms = ((1, h * 0.42, 1.5, 0.3), (-1, h * 0.56, 1.1, 0.26)) if seed % 2 else ((-1, h * 0.38, 1.7, 0.3), (1, h * 0.6, 0.9, 0.24), (0, h * 0.3, 0.0, 0.0))
    for s, z, up, r in arms:
        if r == 0.0:
            continue
        p.cyl(r, 0.9, (s * 0.6, 0, z), g, r=AX_X, sides=10)
        p.ball(r * 1.08, (s * 1.02, 0, z), g, subdiv=2)
        p.cyl(r, up, (s * 1.02, 0, z + up * 0.5), g, sides=10, bevel=r, segs=3)
    if seed % 2 == 0:                                                     # Kugelkaktus daneben
        p.ball(0.42, (0.85, -0.7, 0.3), shade(g, 1.08), scale=(1, 1, 0.85), subdiv=3)
        p.ball(0.12, (0.85, -0.7, 0.68), "F07AB4", scale=(1, 1, 0.7), subdiv=2)
    for k in range(5):                                                    # Blüte oben
        a = math.radians(k * 72)
        p.ball(0.13, (math.cos(a) * 0.14, math.sin(a) * 0.14, h + 0.02), "F07AB4", scale=(1, 1, 0.6), subdiv=1)
    p.ball(0.1, (0, 0, h + 0.07), "FFD23E", subdiv=1)
    one(name, p, pitch=14)


def palm(name, h, seed):
    reset(); rng = random.Random(seed); p = Part()
    bend = 0.9 if seed % 2 else -0.7
    n = 7
    top = Vector((0, 0, 0))
    for i in range(n):
        t0, t1 = i / n, (i + 1) / n
        a = Vector((bend * t0 * t0, 0, h * t0))
        b = Vector((bend * t1 * t1, 0, h * t1 + 0.04))
        r = 0.34 - 0.14 * t0
        limb(p, a, b, r, r * 0.9, ("C29A62", "A8824E")[i % 2], sides=9)
        top = b
    p.cyl(0.5, 0.24, (0, 0, 0.12), "A8824E", r2=0.36, sides=9)
    for i in range(3):
        a = math.radians(i * 120 + 40)
        p.ball(0.2, (top.x + math.cos(a) * 0.24, math.sin(a) * 0.24, top.z - 0.22), "6B4426", subdiv=2)
    nl = 7
    for i in range(nl):
        a = i * 360.0 / nl + rng.uniform(-8, 8)
        c = (LEAF, "4FA34A", LEAF_L)[i % 3]
        m = T(top.x, 0, top.z - 0.05) @ rot(0, 0, a)
        ln = rng.uniform(1.0, 1.2)
        p.ball(1.0, (0, 0, 0), c, r=m @ rot(0, -22, 0) @ T(ln * 0.85, 0, 0), scale=(ln, 0.36, 0.07), subdiv=2)
        p.ball(1.0, (0, 0, 0), shade(c, 0.9), r=m @ T(ln * 1.62, 0, 0.62) @ rot(0, 38, 0) @ T(ln * 0.75, 0, 0), scale=(ln * 0.95, 0.3, 0.06), subdiv=2)
    one(name, p, pitch=14)


def dead_tree(name, h, seed):
    reset(); rng = random.Random(seed); p = Part()
    c = "74604E"
    pts = [Vector((0, 0, 0)), Vector((0.12, 0.05, h * 0.36)), Vector((-0.1, -0.08, h * 0.68)), Vector((0.15, 0.0, h * 0.9))]
    rr = [0.36, 0.27, 0.18, 0.07]
    for i in range(3):
        limb(p, pts[i], pts[i + 1], rr[i], rr[i + 1], c, sides=8)
        p.ball(rr[i + 1] * 1.02, tuple(pts[i + 1]), c, subdiv=1 if i == 2 else 2)
    p.cyl(0.5, 0.26, (0, 0, 0.13), shade(c, 0.85), r2=0.34, sides=8)
    nb = 4 if seed % 2 else 3
    for i in range(nb):
        t = 0.42 + 0.5 * i / nb
        base = pts[1].lerp(pts[2], (t - 0.36) / 0.32) if t < 0.68 else pts[2].lerp(pts[3], (t - 0.68) / 0.22 * 0.8)
        a = math.radians(i * 137 + seed * 60)
        ln = h * rng.uniform(0.26, 0.36)
        d = Vector((math.cos(a), math.sin(a), 0.75)).normalized()
        mid = base + d * ln
        limb(p, base, mid, 0.13, 0.08, c, sides=6)
        p.ball(0.085, tuple(mid), c, subdiv=1)
        tip = mid + Vector((d.x * 0.4, d.y * 0.4, 1.0)).normalized() * ln * 0.6
        limb(p, mid, tip, 0.08, 0.02, shade(c, 1.1), sides=5)
        tip2 = mid + Vector((d.x * 1.6 + d.y, d.y * 1.6 - d.x, 0.3)).normalized() * ln * 0.45
        limb(p, mid, tip2, 0.07, 0.02, shade(c, 1.1), sides=5)
    one(name, p, pitch=14)


def crystal_tree(name, h, seed):
    reset(); rng = random.Random(seed); p = Part()
    g, gl, gd = "8DF03C", "DDFF9A", "4FBF2E"
    spec = [(0, 0, h, 0.48, 0, 0)]
    k = 4 if seed % 2 else 5
    for i in range(k):
        a = math.radians(i * 360.0 / k + seed * 37)
        spec.append((math.cos(a) * 0.55, math.sin(a) * 0.55, h * rng.uniform(0.35, 0.62), rng.uniform(0.26, 0.36), rng.uniform(18, 34), math.degrees(a)))
    for x, y, ln, r, tilt, az in spec:
        m = T(x, y, -0.1) @ rot(0, 0, az) @ rot(0, tilt, 0) @ rot(0, 0, rng.uniform(0, 60))
        tip = r * 1.9
        p.cyl(r * 0.8, ln - tip, (0, 0, 0), g, r=m @ T(0, 0, (ln - tip) * 0.5), r2=r, sides=6)
        p.cyl(r * 0.82, (ln - tip) * 0.3, (0, 0, 0), gd, r=m @ T(0, 0, (ln - tip) * 0.15), r2=r * 0.87, sides=6)
        p.cone(r, tip, (0, 0, 0), gl, r=m @ T(0, 0, ln - tip * 0.5), sides=6)
    for i in range(4):
        a = math.radians(i * 90 + 45)
        chunk(p, (0.6, 0.5, 0.4), (math.cos(a) * 0.9, math.sin(a) * 0.9, 0.16), ("5A6074", "474C5E")[i % 2], rz=i * 50)
    one(name, p, pitch=14)


# ================================================================== Felsen, Büsche, Kleinzeug
def rock(name, seed, snow=False):
    reset(); rng = random.Random(seed); p = Part()
    base = "8E94AA" if snow else ROCK
    lay = [((1.9, 1.6, 1.35), (0, 0, 0.6), 0), ((1.2, 1.1, 1.0), (0.75, -0.35, 0.42), 1), ((1.0, 0.9, 0.8), (-0.7, 0.45, 0.35), 2),
           ((0.6, 0.55, 0.45), (-0.55, -0.75, 0.18), 3), ((1.1, 0.95, 0.7), (0.1, 0.1, 1.2), 4)]
    if seed % 3 == 1:
        lay = [((1.6, 1.9, 1.6), (0, 0.1, 0.72), 0), ((1.1, 1.0, 0.9), (-0.8, -0.3, 0.4), 1), ((0.7, 0.7, 0.5), (0.8, -0.6, 0.2), 3), ((0.9, 1.0, 0.7), (0.15, 0.2, 1.45), 4)]
    if seed % 3 == 2:
        lay = [((2.1, 1.5, 1.0), (0, 0, 0.45), 0), ((1.3, 1.2, 0.9), (-0.3, 0.1, 1.0), 4), ((0.9, 0.8, 0.6), (0.85, -0.5, 0.25), 1), ((0.6, 0.6, 0.4), (-0.95, -0.5, 0.16), 3)]
    for size, loc, i in lay:
        c = (base, shade(base, 0.9), shade(base, 0.82), shade(base, 0.75), mix(base, "FFFFFF", 0.22))[i]
        chunk(p, size, loc, c, rz=rng.uniform(0, 90), rx=rng.uniform(-10, 10), ry=rng.uniform(-10, 10), k=0.26)
    if snow:
        top = max(l[1][2] + l[0][2] * 0.5 for l in lay)
        for size, loc, i in lay:
            if i in (0, 4, 1):
                p.box((size[0] * 0.86, size[1] * 0.86, 0.34), (loc[0], loc[1], loc[2] + size[2] * 0.5 - 0.02), "F4F8FF", r=rot(0, 0, rng.uniform(0, 90)), bevel=0.15, segs=3)
    else:
        grass_tuft(p, 0.95, -0.95, 5, 0.9, seed)
    one(name, p)


def bush(name, seed):
    reset(); rng = random.Random(seed); p = Part()
    g = "4F8A2E" if seed % 2 else "5E9A32"
    p.ball(1.0, (0, 0, 0.55), g, scale=(0.85, 0.8, 0.68), subdiv=3)
    for i, (x, y, z, r) in enumerate(((0.6, -0.2, 0.36, 0.5), (-0.55, -0.3, 0.34, 0.48), (0.1, 0.5, 0.4, 0.5), (-0.1, -0.55, 0.3, 0.4))):
        p.ball(r, (x, y, z), shade(g, (1.12, 0.9, 0.96, 1.2)[i]), scale=(1, 1, 0.85), subdiv=3 if i < 2 else 2)
    dots = "E23B3B" if seed % 2 else "FFFFFF"
    for i in range(7):
        a, e = math.radians(i * 51 + 200 * (i % 2)), math.radians(25 + (i * 37) % 50)
        n = Vector((math.cos(a) * math.cos(e), math.sin(a) * math.cos(e), math.sin(e)))
        p.ball(0.085, (n.x * 0.86, n.y * 0.8, 0.55 + n.z * 0.68), dots, subdiv=1)
    one(name, p)


def flower(p, x, y, h, col, mid, k=1.0, lean=(0, 0)):
    m = T(x, y, 0) @ rot(lean[0], lean[1], 0)
    p.cyl(0.03 * k, h, (0, 0, 0), "5E9A32", r=m @ T(0, 0, h * 0.5), sides=5)
    p.ball(0.12 * k, (0, 0, 0), "6FAE3A", r=m @ T(0.08 * k, 0.02, 0.05) @ rot(0, -25, 30), scale=(1.2, 0.5, 0.2), subdiv=1)
    hm = m @ T(0, 0, h) @ rot(-18, 0, 0)
    for i in range(5):
        p.ball(0.095 * k, (0, 0, 0), col, r=hm @ rot(0, 0, i * 72) @ T(0.105 * k, 0, 0), scale=(1.1, 0.85, 0.4), subdiv=1)
    p.ball(0.07 * k, (0, 0, 0), mid, r=hm @ T(0, 0, 0.02 * k), scale=(1, 1, 0.75), subdiv=2)


def flowers(name, seed, cols):
    reset(); rng = random.Random(seed); p = Part()
    n = 5
    for i in range(n):
        a = math.radians(i * 360.0 / n + rng.uniform(-20, 20))
        d = rng.uniform(0.2, 0.46) if i else 0.0
        col, mid = cols[i % len(cols)]
        flower(p, math.cos(a) * d, math.sin(a) * d, rng.uniform(0.26, 0.44), col, mid, rng.uniform(0.9, 1.15), (rng.uniform(-10, 10), rng.uniform(-10, 10)))
    grass_tuft(p, 0.05, 0.1, 4, 0.55, seed)
    one(name, p, pitch=30)


def grass(name, seed):
    reset(); p = Part()
    grass_tuft(p, 0, 0, 8, 1.0, seed)
    grass_tuft(p, 0.2, -0.14, 5, 0.7, seed + 5)
    if seed % 2 == 0:
        grass_tuft(p, -0.22, 0.1, 5, 0.75, seed + 9, cols=("A9CC3C", "C4DB45", "8FB02A"))
    one(name, p)


def mushroom_1():
    reset(); p = Part()
    mushroom(p, 0, 0, 1.25)
    mushroom(p, 0.45, -0.3, 0.6, lean=10)
    mushroom(p, -0.4, -0.25, 0.42, lean=-12)
    one("p_mushroom_1", p)


def stump_1():
    reset(); p = Part()
    p.cyl(0.6, 0.62, (0, 0, 0.31), BARK, r2=0.5, sides=12, bevel=0.05, segs=1)
    p.cyl(0.44, 0.04, (0, 0, 0.63), CUT, sides=12)
    p.cyl(0.3, 0.05, (0, 0, 0.63), CUT_D, sides=12)
    p.cyl(0.16, 0.06, (0, 0, 0.63), CUT, sides=10)
    for i in range(5):                                                    # Wurzeln
        a = i * 72 + 15
        p.box((0.6, 0.26, 0.3), (0, 0, 0), shade(BARK, 0.9), r=rot(0, 0, a) @ T(0.6, 0, 0.12) @ rot(0, 22, 0), bevel=0.1, segs=2)
    mushroom(p, 0.72, -0.5, 0.4, lean=8)
    p.ball(0.2, (-0.2, 0.3, 0.64), "6FAE3A", scale=(1.3, 1, 0.3), subdiv=2)    # Moos
    one("p_stump_1", p)


def log_1():
    reset(); p = Part()
    log(p, T(0, 0, 0.4) @ AX_X, 0.4, 2.4, sides=12)
    limb(p, (0.5, 0, 0.6), (0.75, -0.2, 1.0), 0.12, 0.1, BARK, sides=7)
    p.cyl(0.085, 0.02, (0, 0, 0), CUT, r=T(0.756, -0.205, 1.01) @ face_to((0.25, -0.2, 0.4)), sides=7)
    p.ball(0.4, (-0.4, 0, 0.74), "6FAE3A", scale=(1.5, 0.9, 0.22), subdiv=2)
    p.ball(0.25, (0.2, 0.2, 0.72), "86BC3C", scale=(1.3, 0.9, 0.22), subdiv=2)
    mushroom(p, -0.9, -0.5, 0.42, lean=6)
    one("p_log_1", p)


def fence():
    reset(); p = Part()
    for i, x in enumerate((-1.333, 0.0, 1.333)):
        p.box((0.26, 0.26, 1.2), (x, 0, 0.6), WOOD, r=rot(0, (3, -2, 2)[i], (4, -6, 8)[i]), bevel=0.07, segs=2)
        p.box((0.3, 0.3, 0.12), (x + (0.03, -0.02, 0.02)[i], 0, 1.22), WOOD_L, bevel=0.05, segs=1)
    p.box((4.0, 0.12, 0.2), (0, -0.14, 0.86), WOOD_D, r=rot(0, 1.2, 0), bevel=0.05, segs=1)
    p.box((4.0, 0.12, 0.2), (0, -0.14, 0.44), WOOD_D, r=rot(0, -1.0, 0), bevel=0.05, segs=1)
    for x in (-1.333, 0.0, 1.333):
        for z in (0.86, 0.44):
            p.ball(0.045, (x, -0.21, z), STEEL, subdiv=1)
    one("p_fence", p)


def wreck(name, variant):
    reset()
    p = MPart(T(0, 0, 0) @ rot(3, -2 if variant == 1 else 2, 0))
    rust, rust_d = "A8562A", "7E4424"
    paint = "E2B648" if variant == 1 else "5FA3A0"
    if variant == 1:                                                      # Limousine, vorn = +X
        p.box((3.8, 1.75, 0.72), (0, 0, 0.66), paint, bevel=0.24, segs=4)
        p.box((1.9, 1.56, 0.68), (-0.25, 0, 1.28), shade(paint, 0.88), bevel=0.24, segs=4)
        p.box((1.3, 1.6, 0.34), (-0.25, 0, 1.32), DARK, bevel=0.08, segs=1)
        p.box((1.96, 1.2, 0.34), (-0.25, 0, 1.32), DARK, bevel=0.08, segs=1)
        p.box((1.0, 1.5, 0.08), (1.3, 0, 1.2), shade(paint, 1.05), r=rot(0, -28, 0), bevel=0.03, segs=1)   # offene Haube
        p.box((0.9, 1.3, 0.3), (1.25, 0, 0.9), DARK, bevel=0.06, segs=1)
        p.box((0.9, 0.9, 0.05), (-1.4, 0.1, 1.03), rust, bevel=0.02, segs=1)
    else:                                                                 # Pritschenwagen
        p.box((4.0, 1.8, 0.66), (0, 0, 0.7), paint, bevel=0.2, segs=4)
        p.box((1.4, 1.66, 0.84), (0.55, 0, 1.36), shade(paint, 0.9), bevel=0.26, segs=4)
        p.box((0.9, 1.7, 0.4), (0.55, 0, 1.44), DARK, bevel=0.08, segs=1)
        p.box((1.46, 1.3, 0.4), (0.55, 0, 1.44), DARK, bevel=0.08, segs=1)
        for sy in (-0.82, 0.82):
            p.box((1.7, 0.12, 0.4), (-1.05, sy, 1.2), paint, bevel=0.04, segs=1)
        p.box((0.12, 1.7, 0.4), (-1.92, 0, 1.2), rust, bevel=0.04, segs=1)
        p.box((1.6, 1.5, 0.06), (-1.05, 0, 1.05), rust_d)
        chunk(p, (0.6, 0.6, 0.5), (-1.2, 0.2, 1.3), WOOD, rz=20, k=0.08)
        p.box((0.8, 0.7, 0.05), (1.55, 0.2, 1.04), rust, bevel=0.02, segs=1)
    for x, y, z, s in ((0.6, -0.88, 0.75, 0.5), (-0.9, 0.88, 0.8, 0.4), (1.5, 0.89, 0.6, 0.36), (-1.5, -0.89, 0.62, 0.3)):  # Rostflecken
        p.box((s, 0.04, s * 0.6), (x, y, z), rust, bevel=0.015, segs=1)
    p.box((0.14, 1.85, 0.2), (1.92 if variant == 1 else 2.02, 0, 0.5), STEEL_D, r=rot(6, 0, 0), bevel=0.05, segs=1)
    for sy in (-0.6, 0.6):
        p.cyl(0.14, 0.06, (1.91 if variant == 1 else 2.0, sy, 0.78), "D9D2B0" if sy < 0 else DARK, r=AX_X, sides=8)
    wh = [(1.2, -0.88), (1.2, 0.88), (-1.2, 0.88)]                         # ein Rad fehlt
    for x, y in wh:
        p.cyl(0.4, 0.3, (x, y, 0.4), "23262E", r=AX_Y, sides=12, bevel=0.1, segs=2)
        p.cyl(0.2, 0.34, (x, y, 0.4), rust_d, r=AX_Y, sides=8)
    p.m = Matrix.Identity(4)
    chunk(p, (0.5, 0.4, 0.34), (-1.2, -0.8, 0.17), "A65A44", rz=15, k=0.08)       # Ziegel statt Rad
    p.cyl(0.4, 0.28, (-1.9, -1.4, 0.14), "23262E", sides=12, bevel=0.1, segs=2)   # Rad liegt daneben
    p.cyl(0.2, 0.3, (-1.9, -1.4, 0.14), rust_d, sides=8)
    grass_tuft(p, 1.7, -1.2, 5, 1.0, variant)
    one(name, p, yaw=-145 if variant == 1 else -150)


def container_1():
    reset(); p = Part()
    c, cd = "2F9DB5", "22788C"
    p.box((6.0, 2.4, 2.5), (0, 0, 1.35), c, bevel=0.05, segs=1)
    for i in range(14):
        p.box((0.2, 2.5, 2.1), (-2.6 + i * 0.4, 0, 1.35), cd, bevel=0.04, segs=1)
    for z in (0.18, 2.56):
        p.box((6.1, 2.5, 0.2), (0, 0, z), cd, bevel=0.05, segs=1)
    for sx in (-1, 1):
        for sy in (-1, 1):
            p.box((0.24, 0.24, 2.6), (sx * 2.94, sy * 1.14, 1.35), cd, bevel=0.04, segs=1)
    for sy in (-0.56, 0.56):                                              # Türen an der Stirnseite (-X)
        p.box((0.08, 1.02, 2.1), (-3.02, sy, 1.35), shade(c, 1.1), bevel=0.03, segs=1)
        p.cyl(0.04, 2.2, (-3.08, sy * 0.5, 1.35), "DCE2EC", sides=6)
        p.box((0.1, 0.3, 0.1), (-3.1, sy * 0.5, 1.2), STEEL_D)
    for sy in (-1.26, 1.26):                                              # weißer Streifen mit Stern
        p.box((2.2, 0.04, 0.8), (0.6, sy, 1.5), "F4F6FA", bevel=0.01, segs=1)
    star(p, (0.6, -1.29, 1.5), 0.3, c, 0.03, r=STAR_FRONT)
    p.box((1.0, 0.04, 0.6), (-1.9, -1.26, 0.7), "B5622E", bevel=0.01, segs=1)   # Rost
    one("p_container_1", p, yaw=-130)


def barrel_1():
    reset(); p = Part()
    p.cyl(0.44, 1.12, (0, 0, 0.56), RED, sides=16, bevel=0.07, segs=2)
    for z in (0.32, 0.8):
        p.torus(0.44, 0.04, (0, 0, z), RED_D, seg=16, tseg=5)
    p.cyl(0.36, 0.03, (0, 0, 1.115), RED_D, sides=14)
    p.cyl(0.08, 0.06, (0.18, -0.1, 1.14), STEEL, sides=8)
    p.box((0.4, 0.06, 0.4), (0, -0.425, 0.56), GOLD, r=rot(0, 45, 0), bevel=0.02, segs=1)       # Warnzeichen
    p.box((0.07, 0.07, 0.2), (0, -0.46, 0.6), DARK, bevel=0.02, segs=1)
    p.box((0.07, 0.07, 0.07), (0, -0.46, 0.44), DARK, bevel=0.02, segs=1)
    one("p_barrel_1", p)


def crate_box(p, m, s, wood=WOOD, frame=WOOD_D):
    p.box((s, s, s), (0, 0, 0), wood, r=m @ T(0, 0, s * 0.5), bevel=s * 0.03, segs=1)
    w = s * 0.14
    for a in (-1, 1):
        for b in (-1, 1):
            o = (s - w) * 0.5 + s * 0.015
            p.box((w, w, s * 1.03), (0, 0, 0), frame, r=m @ T(a * o, b * o, s * 0.5), bevel=w * 0.2, segs=1)
            p.box((s * 1.0, w, w), (0, 0, 0), frame, r=m @ T(0, a * o, s * 0.5 + b * o), bevel=w * 0.2, segs=1)
            p.box((w, s * 1.0, w), (0, 0, 0), frame, r=m @ T(a * o, 0, s * 0.5 + b * o), bevel=w * 0.2, segs=1)
    for i in range(4):
        p.box((s * 1.1, w * 0.5, w * 0.9), (0, 0, 0), shade(wood, 0.82), r=m @ rot(0, 0, i * 90) @ T(0, -s * 0.5 - 0.005, s * 0.5) @ rot(0, 45, 0), bevel=0.01, segs=1)


def crate_1():
    reset(); p = Part()
    crate_box(p, Matrix.Identity(4), 1.0)
    one("p_crate_1", p)


def bridge():
    reset(); p = Part()
    n = 15
    for i in range(n):
        y = -4.2 + i * 0.6
        p.box((5.0, 0.54, 0.16), (0, y, 0.1), (WOOD, shade(WOOD, 1.12), shade(WOOD, 0.92))[i % 3], r=rot(0, 0, (0.6, -0.8, 0.3, -0.4)[i % 4]), bevel=0.04, segs=1)
    for sx in (-2.0, 0.0, 2.0):                                           # Längsbalken darunter
        p.box((0.3, 9.0, 0.16), (sx, 0, -0.04), WOOD_D)
    for sx in (-2.42, 2.42):
        for y in (-4.3, -2.15, 0.0, 2.15, 4.3):
            p.box((0.24, 0.24, 1.2), (sx, y, 0.66), WOOD_D, bevel=0.06, segs=1)
            p.box((0.3, 0.3, 0.1), (sx, y, 1.28), WOOD_L, bevel=0.04, segs=1)
        p.box((0.14, 9.0, 0.18), (sx, 0, 1.0), WOOD, bevel=0.05, segs=1)
        p.box((0.12, 9.0, 0.14), (sx, 0, 0.6), WOOD, bevel=0.04, segs=1)
    one("p_bridge", p, yaw=-40, pitch=32)


def signpost():
    reset(); p = Part()
    p.box((0.2, 0.2, 2.3), (0, 0, 1.15), WOOD_D, r=rot(2, -3, 0), bevel=0.06, segs=2)
    for z, s, c in ((1.9, 1, WOOD_L), (1.4, -1, WOOD)):
        m = T(0.05 * s, -0.13, z) @ rot(0, 4 * s, 0)
        p.box((1.1, 0.1, 0.4), (0, 0, 0), c, r=m, bevel=0.04, segs=1)
        p.box((0.4, 0.1, 0.4), (0, 0, 0), c, r=m @ T(0.55 * s, 0, 0) @ rot(0, 45, 0) @ S(0.82, 1, 0.82), bevel=0.04, segs=1)
        p.box((0.6, 0.03, 0.1), (0, 0, 0), "F4F6FA", r=m @ T(-0.05 * s, -0.055, 0))
        p.box((0.2, 0.03, 0.2), (0, 0, 0), "F4F6FA", r=m @ T(0.3 * s, -0.055, 0) @ rot(0, 45, 0))
    chunk(p, (0.5, 0.45, 0.3), (0.2, 0.1, 0.12), ROCK, rz=20)
    chunk(p, (0.36, 0.34, 0.24), (-0.22, -0.1, 0.1), ROCK_L, rz=50)
    one("p_signpost", p, yaw=-20)


def campfire():
    reset(); p = Part()
    for i in range(8):
        a = math.radians(i * 45)
        chunk(p, (0.38, 0.32, 0.26), (math.cos(a) * 0.72, math.sin(a) * 0.72, 0.11), (ROCK, ROCK_L, ROCK_D)[i % 3], rz=i * 45 + 20)
    p.cyl(0.6, 0.06, (0, 0, 0.03), "3A3238", sides=12)
    for i in range(4):
        a = math.radians(i * 90 + 30)
        m = T(math.cos(a) * 0.26, math.sin(a) * 0.26, 0.3) @ rot(0, 0, i * 90 + 30) @ rot(0, -52, 0)
        log(p, m, 0.11, 0.9, sides=7, bark="5A3A26")

    def extra(root):
        f = Part()
        f.ball(1.0, (0, 0, 0.42), "FF8A1E", scale=(0.3, 0.3, 0.38), subdiv=2)
        f.cone(0.26, 0.6, (0.02, 0, 0.9), "FF8A1E", sides=8)
        f.cone(0.15, 0.4, (-0.2, 0.08, 0.62), "FF6A1E", r=rot(0, -14, 0), sides=6)
        f.cone(0.15, 0.44, (0.2, -0.08, 0.66), "FF6A1E", r=rot(0, 14, 0), sides=6)
        f.ball(1.0, (0, -0.02, 0.4), "FFE25A", scale=(0.18, 0.18, 0.26), subdiv=2)
        f.cone(0.15, 0.34, (0, -0.02, 0.72), "FFE25A", sides=6)
        f.build("fire_glow", root)
        empty("fx_smoke", root, (0, 0, 1.3))
    one("p_campfire", p, extra=extra)


def cloud(name, seed):
    reset(); p = Part()
    lay = (((0, 0, 0.1), 1.9), ((-1.9, 0.1, -0.2), 1.45), ((1.9, -0.1, -0.15), 1.5), ((-3.0, 0, -0.45), 0.95), ((3.0, 0.1, -0.4), 1.0), ((0.9, -0.7, -0.3), 1.2)) if seed == 1 else \
          (((-0.6, 0, 0.1), 1.7), ((1.3, 0.2, 0.0), 1.6), ((-2.4, -0.1, -0.3), 1.2), ((2.9, 0, -0.4), 1.05), ((0.3, -0.8, -0.35), 1.1), ((-3.3, 0.2, -0.5), 0.75))
    for i, (c, r) in enumerate(lay):
        p.ball(r, c, "FFFFFF" if i < 3 else "EEF4FC", scale=(1.0, 0.8, 0.6), subdiv=3)
    one(name, p, pitch=18)


# ================================================================== Kisten
def chest(name, lid_col, trim=GOLD, wood=WOOD, style="", glb=True, open_deg=0.0):
    reset(); root = empty(name)
    b = Part()
    b.box((1.2, 0.84, 0.58), (0, 0, 0.33), wood, bevel=0.07, segs=2)
    for x in (-0.3, 0.0, 0.3):                                            # Bretterfugen
        b.box((0.03, 0.86, 0.5), (x, 0, 0.33), shade(wood, 0.72))
    for sx in (-1, 1):
        b.box((0.16, 0.9, 0.62), (sx * 0.47, 0, 0.33), trim, bevel=0.03, segs=1)
        for sy in (-1, 1):
            b.box((0.2, 0.2, 0.1), (sx * 0.5, sy * 0.33, 0.05), shade(trim, 0.8), bevel=0.03, segs=1)
    b.box((0.3, 0.1, 0.3), (0, -0.43, 0.5), trim, bevel=0.05, segs=2)       # Schloss
    b.cyl(0.05, 0.12, (0, -0.43, 0.52), DARK, r=AX_Y, sides=8)
    b.box((0.04, 0.12, 0.1), (0, -0.43, 0.45), DARK)
    if style == "gold":
        for x, c in ((-0.25, "E23B3B"), (0.25, "3FA8F5")):
            b.ball(0.07, (x, -0.43, 0.36), c, subdiv=2)
    b.build("body", root)
    l = Part()
    l.box((1.24, 0.88, 0.46), (0, -0.42, 0.13), lid_col, bevel=0.2, segs=4)
    for sx in (-1, 1):
        l.box((0.17, 0.92, 0.5), (sx * 0.47, -0.42, 0.13), trim if style != "plain" else shade(lid_col, 0.86), bevel=0.2, segs=4)
    if style == "plain":
        l.box((0.9, 0.9, 0.04), (0, -0.42, -0.07), shade(lid_col, 0.86))
    else:
        l.box((1.26, 0.9, 0.07), (0, -0.42, -0.06), trim, bevel=0.02, segs=1)
    if style in ("star", "gold"):
        star(l, (0, -0.42, 0.37), 0.2, "FFFFFF" if style == "star" else "FFF3B0", 0.04)
    if style == "boss":                                                   # Totenkopf + Hörner
        l.ball(1.0, (0, -0.88, 0.14), "F4F0E6", scale=(0.17, 0.08, 0.16), subdiv=2)
        l.box((0.16, 0.1, 0.1), (0, -0.88, 0.0), "F4F0E6", bevel=0.03, segs=1)
        for s in (-1, 1):
            l.ball(0.045, (0.07 * s, -0.95, 0.15), DARK, subdiv=1)
            l.cone(0.09, 0.34, (0.5 * s, -0.42, 0.42), "F4F0E6", r=rot(0, 24 * s, 0), sides=6)
    if style == "gift":                                                   # Schleife
        l.box((0.2, 0.94, 0.52), (0, -0.42, 0.13), "FFFFFF", bevel=0.2, segs=4)
        for s in (-1, 1):
            l.ball(1.0, (0.17 * s, -0.42, 0.46), "FFFFFF", r=rot(0, -25 * s, 0), scale=(0.2, 0.12, 0.11), subdiv=2)
        l.ball(0.08, (0, -0.42, 0.42), "FFE25A", subdiv=2)
    if style == "clan":                                                   # Wappen
        l.box((0.34, 0.08, 0.36), (0, -0.87, 0.12), GOLD, bevel=0.08, segs=2)
        star(l, (0, -0.92, 0.12), 0.11, "FFFFFF", 0.03, r=STAR_FRONT)
    if style == "silver":
        for x in (-0.2, 0.2):
            l.ball(0.05, (x, -0.42, 0.365), "FFFFFF", subdiv=1)
    lid = l.build("lid", root, (0, 0.42, 0.62))
    lid.rotation_euler = (math.radians(open_deg), 0, 0)
    finish(name, yaw=-28, pitch=22, glb=glb)


CHESTS = {"daily": ("B8742F", GOLD, WOOD, "trim"), "find": ("9C9A4A", STEEL, "8A6A3A", "trim"), "quest": ("3C5CA4", GOLD, WOOD, "trim"),
          "level": ("0A78E0", GOLD, WOOD, "star"), "flood_wood": ("A9622F", "6B3E20", "C08040", "trim"),
          "flood_silver": ("C9CED8", "8A94A8", "9AA2B4", "silver"), "boss": ("B02A38", "2E3340", "4A3A3A", "boss"),
          "flood_gold": ("FDCA14", "FFE98A", "E09A1E", "gold"), "clan": ("B46CFF", GOLD, WOOD, "clan"), "gift": ("F07AB4", "FFFFFF", "F7A8CE", "gift")}


# ================================================================== Rohstoffhaufen + Symbole
def heap_wood(p, k=1.0):
    r = 0.25 * k
    for i, (y, z) in enumerate(((-0.52, 0), (0, 0), (0.52, 0), (-0.26, 1), (0.26, 1), (0, 2))):
        log(p, T(0.04 * ((i * 7) % 3 - 1), y * k, r + z * r * 1.74) @ AX_X, r, 1.5 * k, sides=10, bark=(BARK, shade(BARK, 1.12), shade(BARK, 0.9))[i % 3])


def heap_stone(p):
    for size, loc, rz, c in (((0.85, 0.75, 0.6), (-0.35, 0.1, 0.3), 10, "A7ADC6"), ((0.75, 0.7, 0.55), (0.42, -0.1, 0.27), 50, "BCC2D8"),
                             ((0.6, 0.55, 0.45), (0.05, -0.55, 0.22), 25, "8F96B2"), ((0.7, 0.65, 0.5), (0.02, 0.1, 0.78), 70, "C6CCE0"), ((0.4, 0.4, 0.3), (-0.6, -0.5, 0.15), 40, "A7ADC6")):
        chunk(p, size, loc, c, rz=rz, rx=8, ry=-6, k=0.26)


def ingot(p, m, c="7F9BC8"):
    p.box((0.74, 0.36, 0.2), (0, 0, 0), c, r=m, bevel=0.06, segs=2)
    p.box((0.6, 0.24, 0.06), (0, 0, 0), shade(c, 1.22), r=m @ T(0, 0, 0.1), bevel=0.02, segs=1)


def heap_metal(p):
    for i, (x, y, z, a) in enumerate(((-0.4, -0.2, 0.1, 0), (0.4, -0.2, 0.1, 0), (-0.4, 0.22, 0.1, 0), (0.4, 0.22, 0.1, 0), (0.0, -0.2, 0.31, 0), (0.0, 0.22, 0.31, 4), (0.0, 0.0, 0.52, 90))):
        ingot(p, T(x, y, z) @ rot(0, 0, a + (i % 3 - 1) * 4), ("7F9BC8", "8FA9D4", "6F8BBA")[i % 3])


def jerrycan(p, m, k=1.0):
    p.box((0.56 * k, 0.3 * k, 0.7 * k), (0, 0, 0), RED, r=m @ T(0, 0, 0.35 * k), bevel=0.09 * k, segs=3)
    for a in (35, -35):
        p.box((0.5 * k, 0.32 * k, 0.07 * k), (0, 0, 0), RED_D, r=m @ T(0, 0, 0.33 * k) @ rot(0, a, 0), bevel=0.02 * k, segs=1)
    p.box((0.3 * k, 0.12 * k, 0.12 * k), (0, 0, 0), RED_D, r=m @ T(-0.04 * k, 0, 0.76 * k), bevel=0.04 * k, segs=1)
    p.cyl(0.07 * k, 0.14 * k, (0, 0, 0), "FFD23E", r=m @ T(0.2 * k, 0, 0.74 * k) @ rot(0, 30, 0), sides=8, bevel=0.02 * k, segs=1)


def battery(p, g, m, k=1.0):
    p.cyl(0.2 * k, 0.6 * k, (0, 0, 0), "3A4152", r=m @ T(0, 0, 0.3 * k), sides=12, bevel=0.04 * k, segs=1)
    p.cyl(0.1 * k, 0.1 * k, (0, 0, 0), GOLD_D, r=m @ T(0, 0, 0.63 * k), sides=8, bevel=0.02 * k, segs=1)
    g.cyl(0.21 * k, 0.26 * k, (0, 0, 0), "3FD2F5", r=m @ T(0, 0, 0.3 * k), sides=12)
    g.box((0.07 * k, 0.03 * k, 0.2 * k), (0, 0, 0), "EFFFFF", r=m @ T(0, -0.205 * k, 0.3 * k) @ rot(0, 20, 0))


def pile(name, kind):
    reset(); p = Part(); g = None
    if kind == "wood":
        heap_wood(p)
    elif kind == "stone":
        heap_stone(p)
    elif kind == "metal":
        heap_metal(p)
    elif kind == "fuel":
        jerrycan(p, T(-0.36, 0.1, 0) @ rot(0, 0, 10), 1.15)
        jerrycan(p, T(0.36, 0.12, 0) @ rot(0, 0, -14), 1.15)
        jerrycan(p, T(0.05, -0.42, 0.18) @ rot(90, 0, 8) @ T(0, 0, -0.35), 1.0)
    elif kind == "cells":
        g = Part()
        battery(p, g, T(-0.3, 0.12, 0), 1.25)
        battery(p, g, T(0.28, 0.16, 0), 1.25)
        battery(p, g, T(0.0, -0.3, 0), 1.1)
        battery(p, g, T(0.75, -0.3, 0.2) @ rot(90, 0, 60) @ T(0, 0, -0.3), 1.0)
    elif kind == "parts":
        gear(p, T(0, 0, 0.09), 0.62, 0.18, "A9B4C8")
        gear(p, T(0.2, 0.25, 0.5) @ rot(62, 0, 20), 0.46, 0.15, "E0A82E", teeth=7)
        gear(p, T(-0.55, -0.4, 0.07), 0.3, 0.12, "7F8CA6", teeth=6)
        p.cyl(0.07, 0.5, (0.6, -0.45, 0.07), STEEL, r=rot(90, 0, 40), sides=6)
        p.cyl(0.12, 0.1, (0.76, -0.26, 0.07), STEEL_D, r=rot(90, 0, 40), sides=6)
    elif kind == "shards":
        puffy_star(p, T(0, 0.1, 0.62) @ rot(0, 0, -30) @ rot(78, 0, 0) @ rot(0, 0, 8), 0.66)
        puffy_star(p, T(0.5, -0.45, 0.3) @ rot(0, 0, -10) @ rot(62, 0, 0) @ rot(0, 0, 30), 0.36, GOLD_L)
        puffy_star(p, T(-0.55, -0.3, 0.26) @ rot(0, 0, -55) @ rot(58, 0, 0) @ rot(0, 0, -14), 0.32, GOLD_L)
    elif kind == "coins":
        for x, y, n in ((-0.3, 0.15, 6), (0.3, 0.2, 4), (0.0, -0.3, 3)):
            for i in range(n):
                coin(p, T(x + 0.03 * ((i * 5) % 3 - 1), y + 0.03 * ((i * 3) % 3 - 1), 0.045 + i * 0.09), 0.3, 0.09, face=(i == n - 1))
        coin(p, T(0.62, -0.25, 0.3) @ rot(70, 0, 30), 0.3, 0.09)
        coin(p, T(-0.62, -0.35, 0.05), 0.3, 0.09)
        star(p, (-0.3, 0.15, 0.555), 0.14, GOLD_D, 0.03)
    root = empty(name)
    p.build("body", root)
    if g is not None:
        g.build("cell_glow", root)
    finish(name, yaw=-30, pitch=24)


def res(name):
    reset(); p = Part()
    kind = name[4:]
    if kind == "coins":
        for i in range(4):
            coin(p, T(0.02 * (i % 2), 0, 0.06 + i * 0.12), 0.42, 0.12, face=(i == 3))
        star(p, (0.02, 0, 0.49), 0.2, GOLD_D, 0.03)
        coin(p, T(0.5, -0.3, 0.42) @ rot(78, 0, 28), 0.42, 0.12)
        star(p, (0, 0, 0), 0.2, GOLD_D, 0.03, r=T(0.5, -0.3, 0.42) @ rot(78, 0, 28) @ T(0, 0, 0.066))
    elif kind == "wood":
        for y, z in ((-0.3, 0.3), (0.3, 0.3), (0, 0.8)):
            log(p, T(0, y, z) @ rot(0, 0, 8) @ AX_X, 0.3, 1.3, sides=12)
    elif kind == "stone":
        chunk(p, (1.0, 0.9, 0.8), (-0.15, 0.1, 0.4), "A7ADC6", rz=15, rx=6, k=0.27)
        chunk(p, (0.7, 0.65, 0.55), (0.5, -0.3, 0.27), "C6CCE0", rz=50, k=0.27)
        chunk(p, (0.5, 0.45, 0.4), (-0.1, 0.15, 0.95), "8F96B2", rz=35, ry=8, k=0.27)
    elif kind == "metal":
        ingot(p, T(-0.2, 0.2, 0.1) @ rot(0, 0, 8))
        ingot(p, T(0.25, -0.2, 0.1) @ rot(0, 0, -4), "8FA9D4")
        ingot(p, T(0.02, 0.0, 0.31) @ rot(0, 0, 24), "9FB7DE")
    elif kind == "fuel":
        jerrycan(p, rot(0, 0, 18), 1.3)
    elif kind == "cells":
        battery(p, p, rot(0, -14, 0) @ rot(0, 0, 20), 1.6)
    elif kind == "parts":
        gear(p, T(0, 0, 0.75) @ rot(72, 0, 0) @ rot(0, 0, 11), 0.72, 0.22, "9FB0CC")
    elif kind == "shards":
        puffy_star(p, T(0, 0, 0.72) @ rot(0, 0, -24) @ rot(70, 0, 0), 0.75)
    one(name, p, yaw=-24, pitch=26)


# ================================================================== Interaktive Kulissen
def nest():
    reset(); root = empty("p_nest"); p = Part()
    g, gd, gl = "6FA022", "4A7418", "9DC42C"
    p.ball(1.0, (0, 0, 0.75), g, scale=(1.9, 1.85, 1.5), subdiv=4)
    p.ball(1.0, (1.35, -0.6, 0.3), gl, scale=(0.85, 0.8, 0.62), subdiv=3)
    p.ball(1.0, (-1.3, 0.5, 0.3), gl, scale=(0.9, 0.85, 0.7), subdiv=3)
    p.ball(1.0, (-0.9, -1.25, 0.2), shade(gl, 0.92), scale=(0.6, 0.55, 0.45), subdiv=2)
    p.ball(1.0, (0.5, 1.5, 0.2), shade(gl, 0.92), scale=(0.6, 0.6, 0.45), subdiv=2)
    for az, el, r in ((-90, 22, 0.5), (-38, 42, 0.34), (-150, 40, 0.36), (30, 30, 0.4), (150, 28, 0.36)):   # Löcher
        a, e = math.radians(az), math.radians(el)
        n = Vector((math.cos(a) * math.cos(e), math.sin(a) * math.cos(e), math.sin(e)))
        q = Vector((n.x * 1.9, n.y * 1.85, 0.75 + n.z * 1.5))
        nn = Vector((n.x / 1.9, n.y / 1.85, n.z / 1.5)).normalized()
        m = T(*q) @ face_to(nn)
        p.torus(r, r * 0.3, (0, 0, 0), gl, r=m, seg=10, tseg=4)
        p.ball(r, (0, 0, 0), "1E2A12", r=m @ T(0, 0, -0.02), scale=(1, 1, 0.3), subdiv=2)
    p.torus(0.62, 0.24, (0, 0, 2.2), gd, seg=14, tseg=6)                  # Schlot oben
    for s in (-1, 1):                                                     # Augen im großen Loch
        p.ball(0.07, (0.14 * s, -1.74, 1.38), "E8F58A", subdiv=1)
    p.build("body", root)
    t = Part()
    t.ball(0.5, (0, 0, 0), "C8F04A", scale=(1, 1, 0.7), subdiv=3)
    t.build("pulse_top_glow", root, (0, 0, 2.28))
    finish("p_nest", yaw=-25, pitch=24)


def cage():
    reset(); p = Part()
    p.cyl(1.2, 0.26, (0, 0, 0.13), WOOD_D, sides=18, bevel=0.07, segs=2)
    p.cyl(1.1, 0.04, (0, 0, 0.27), WOOD, sides=18)
    p.cyl(1.2, 0.26, (0, 0, 2.45), WOOD_D, sides=18, bevel=0.07, segs=2)
    p.cyl(0.7, 0.14, (0, 0, 2.62), WOOD, sides=14, bevel=0.05, segs=1)
    for i in range(12):
        a = math.radians(i * 30 + 15)
        p.cyl(0.06, 2.1, (math.cos(a) * 1.05, math.sin(a) * 1.05, 1.3), STEEL, sides=6)
    p.torus(1.05, 0.05, (0, 0, 1.3), STEEL_D, seg=18, tseg=5)
    p.torus(0.22, 0.05, (0, 0, 2.82), STEEL_D, r=rot(90, 0, 0), seg=12, tseg=5)
    p.box((0.3, 0.12, 0.3), (0, -1.1, 1.3), GOLD, bevel=0.05, segs=2)       # Schloss
    p.cyl(0.05, 0.14, (0, -1.1, 1.3), DARK, r=AX_Y, sides=6)
    one("p_cage", p)


def gate():
    reset(); p = Part()
    for s in (-1, 1):
        x = 3.0 * s
        p.box((0.8, 0.8, 0.4), (x, 0, 0.2), "7F86A6", bevel=0.12, segs=2)
        for i in range(6):
            p.cyl(0.2, 0.52, (x, 0, 0.64 + i * 0.5), ("E23B3B", "F4F6FA")[i % 2], sides=12)
        p.ball(0.26, (x, 0, 3.64), GOLD, subdiv=3)
    p.box((6.0, 0.14, 0.84), (0, 0, 3.06), "F4F6FA", bevel=0.03, segs=1)
    for i in range(10):
        for j in range(2):
            if (i + j) % 2 == 0:
                p.box((0.56, 0.17, 0.4), (-2.52 + i * 0.56, 0, 2.86 + j * 0.4), "23262E")
    p.box((6.1, 0.2, 0.08), (0, 0, 3.5), GOLD_D, bevel=0.02, segs=1)
    p.box((6.1, 0.2, 0.08), (0, 0, 2.62), GOLD_D, bevel=0.02, segs=1)
    one("p_gate", p, yaw=-22, pitch=14)


def enemy_tower():
    reset(); root = empty("p_enemy_tower"); p = Part()
    dk, md = "6B4A32", "8A6240"
    legs = ((-0.95, -0.95, 4, -5), (0.95, -0.9, 6, 4), (-0.9, 0.95, -5, -3), (1.0, 0.95, -3, 6))
    for x, y, ax, ay in legs:
        p.box((0.32, 0.32, 4.5), (x, y, 2.2), dk, r=rot(ax, ay, 0), bevel=0.08, segs=1)
    for i in range(4):
        m = rot(0, 0, i * 90)
        p.box((2.6, 0.12, 0.18), (0, 0, 0), md, r=m @ T(0, -0.98, 1.5 + 0.3 * (i % 2)) @ rot(0, 32 * (1 if i % 2 else -1), 0), bevel=0.04, segs=1)
        p.box((2.3, 0.14, 0.2), (0, 0, 0), dk, r=m @ T(0, -1.0, 3.2) @ rot(0, 5 * (1 if i % 2 else -1), 0), bevel=0.04, segs=1)
    pm = T(0, 0, 4.4) @ rot(3, -4, 0)
    p.box((2.9, 2.9, 0.28), (0, 0, 0), md, r=pm, bevel=0.08, segs=1)
    for i in range(4):                                                    # schiefe Brüstung aus Latten
        for k in range(4):
            h = (0.7, 0.95, 0.6, 0.85)[(i + k) % 4]
            p.box((0.5, 0.1, h), (0, 0, 0), (dk, md)[k % 2], r=pm @ rot(0, 0, i * 90) @ T(-0.95 + k * 0.63, -1.38, 0.1 + h * 0.5) @ rot(0, (6, -5, 3, -7)[k], 0), bevel=0.03, segs=1)
    for i in range(4):                                                    # Stachelpfähle
        a = math.radians(i * 90 + 45)
        p.cone(0.14, 0.7, (0, 0, 0), "D9D2B0", r=pm @ T(math.cos(a) * 1.9, math.sin(a) * 1.9, 0.5) @ rot(0, 0, i * 90 + 45) @ rot(0, 28, 0), sides=6)
    # rotes Banner mit Schädel
    p.box((1.5, 0.06, 0.12), (0, -1.08, 3.7), dk)
    p.box((1.3, 0.07, 1.7), (0, -1.1, 2.82), RED_D, bevel=0.02, segs=1)
    for i in range(3):
        p.cone(0.22, 0.4, (-0.43 + i * 0.43, -1.1, 1.82), RED_D, r=rot(180, 0, 0) @ S(1, 0.16, 1), sides=4)
    p.ball(1.0, (0, -1.15, 3.0), "F4EDE0", scale=(0.36, 0.06, 0.34), subdiv=2)
    p.box((0.34, 0.08, 0.2), (0, -1.15, 2.68), "F4EDE0", bevel=0.03, segs=1)
    for s in (-1, 1):
        p.ball(0.1, (0.14 * s, -1.19, 3.02), "3A1418", scale=(1, 0.4, 1.2), subdiv=1)
    # Schleim-Ausguck
    sm = pm @ T(0.1, -0.2, 0.14)
    p.ball(1.0, (0, 0, 0), "9DC42C", r=sm @ T(0, 0, 0.5), scale=(0.62, 0.62, 0.52), subdiv=3)
    for s in (-1, 1):
        p.ball(0.11, (0, 0, 0), "1B2410", r=sm @ T(0.2 * s, -0.55, 0.6), scale=(1, 0.5, 1.2), subdiv=2)
        p.ball(0.035, (0, 0, 0), "FFFFFF", r=sm @ T(0.2 * s + 0.03, -0.61, 0.66), subdiv=1)
        p.box((0.24, 0.06, 0.07), (0, 0, 0), "1B2410", r=sm @ T(0.2 * s, -0.56, 0.8) @ rot(0, 22 * s, 0))
    # krummer Mast mit Wimpel
    limb(p, pm @ Vector((1.2, 1.2, 0.1)), pm @ Vector((1.35, 1.3, 2.0)), 0.07, 0.05, dk, sides=6)
    p.cone(0.36, 0.9, (0, 0, 0), RED, r=pm @ T(0.9, 1.3, 1.7) @ rot(0, -90, 0) @ S(1, 0.12, 1), sides=4)
    p.build("body", root)
    finish("p_enemy_tower", yaw=-28, pitch=16)


def flag_exit():
    reset(); root = empty("p_flag_exit"); p = Part()
    p.cyl(0.6, 0.3, (0, 0, 0.15), "7F86A6", sides=12, bevel=0.1, segs=2)
    p.cyl(0.36, 0.3, (0, 0, 0.4), "A7ADC6", sides=12, bevel=0.08, segs=2)
    p.cyl(0.085, 5.2, (0, 0, 2.9), "DCE2EC", sides=8)
    p.ball(0.2, (0, 0, 5.56), GOLD, subdiv=2)
    p.torus(0.11, 0.035, (0, 0, 5.2), GOLD_D, seg=8, tseg=4)
    p.torus(0.11, 0.035, (0, 0, 3.9), GOLD_D, seg=8, tseg=4)
    p.build("body", root)
    c = Part()
    blue = "0A72F0"
    segs = ((0.5, 0, 6), (1.5, 0.05, -8), (2.4, -0.02, 7))
    for i, (x, y, a) in enumerate(segs):
        c.box((1.02 if i < 2 else 0.9, 0.07, 1.3), (x, y, 0), shade(blue, (1.0, 1.12, 0.94)[i]), r=rot(0, 0, a), bevel=0.03, segs=1)
    for s in (-1, 1):
        star(c, (1.4, 0.05 + 0.06 * s * -1, 0), 0.42, "FFFFFF", 0.04, r=rot(90 * s * -1, 0, 0) @ rot(0, 0, 0))
    c.build("sway_cloth", root, (0.08, 0, 4.55))
    finish("p_flag_exit", yaw=-12, pitch=12)


def drone():
    reset(); root = empty("p_drone"); p = Part()
    w = "F4F6FA"
    p.ball(1.0, (0, 0, 0.36), w, scale=(0.36, 0.4, 0.28), subdiv=3)
    p.torus(0.345, 0.05, (0, 0, 0.26), "F28A1E", r=S(0.98, 1.08, 1), seg=16, tseg=5)
    p.cyl(0.06, 0.22, (0, 0, 0.7), STEEL, sides=8)
    for s in (-1, 1):                                                     # Greifer + Kufen
        p.box((0.06, 0.06, 0.2), (0.16 * s, -0.05, 0.1), STEEL_D, r=rot(0, -14 * s, 0), bevel=0.02, segs=1)
        p.box((0.07, 0.3, 0.05), (0.19 * s, -0.05, 0.025), "F28A1E", bevel=0.02, segs=1)
    p.cyl(0.015, 0.26, (0.2, 0.2, 0.66), DARK, r=rot(-14, 14, 0), sides=4)
    p.ball(0.04, (0.235, 0.235, 0.79), RED, subdiv=1)
    p.box((0.34, 0.1, 0.17), (0, -0.33, 0.39), "23303E", bevel=0.05, segs=2)    # Visier
    p.build("body", root)
    e = Part()
    for s in (-1, 1):
        e.ball(0.045, (0.08 * s, -0.385, 0.39), "5FE6FF", scale=(1, 0.5, 1.2), subdiv=2)
    e.build("eye_glow", root)
    r = Part()
    r.cyl(0.09, 0.07, (0, 0, 0), DARK, sides=8, bevel=0.02, segs=1)
    for i in range(3):
        r.box((0.5, 0.11, 0.025), (0, 0, 0), "5E6678", r=rot(0, 0, i * 120) @ T(0.3, 0, 0) @ rot(12, 0, 0), bevel=0.01, segs=1)
    r.build("spin_rotor", root, (0, 0, 0.83))
    finish("p_drone", yaw=-28, pitch=20)


def coin_single():
    reset(); p = Part()
    coin(p, T(0, 0, 0.035), 0.26, 0.07)
    star(p, (0, 0, 0.082), 0.12, GOLD_D, 0.016)
    one("p_coin", p, pitch=40)


TABLE = {}
for _i, _h in enumerate((4.6, 5.6, 6.6)):
    TABLE["p_tree_pine_%d" % (_i + 1)] = (pine, "p_tree_pine_%d" % (_i + 1), _h, 11 + _i, "pine")
for _i, _h in enumerate((5.4, 6.8)):
    TABLE["p_tree_pine_dense_%d" % (_i + 1)] = (pine, "p_tree_pine_dense_%d" % (_i + 1), _h, 21 + _i, "dense")
for _i, _h in enumerate((4.8, 6.2)):
    TABLE["p_tree_snowpine_%d" % (_i + 1)] = (pine, "p_tree_snowpine_%d" % (_i + 1), _h, 31 + _i, "snow")
for _i, _h in enumerate((4.0, 4.8)):
    TABLE["p_tree_cactus_%d" % (_i + 1)] = (cactus, "p_tree_cactus_%d" % (_i + 1), _h, 1 + _i)
for _i, _h in enumerate((5.2, 6.4)):
    TABLE["p_tree_palm_%d" % (_i + 1)] = (palm, "p_tree_palm_%d" % (_i + 1), _h, 1 + _i)
for _i, _h in enumerate((4.4, 5.6)):
    TABLE["p_tree_dead_%d" % (_i + 1)] = (dead_tree, "p_tree_dead_%d" % (_i + 1), _h, 1 + _i)
for _i, _h in enumerate((4.2, 5.4)):
    TABLE["p_tree_crystal_%d" % (_i + 1)] = (crystal_tree, "p_tree_crystal_%d" % (_i + 1), _h, 1 + _i)
for _i in range(3):
    TABLE["p_rock_%d" % (_i + 1)] = (rock, "p_rock_%d" % (_i + 1), 3 + _i)
for _i in range(2):
    TABLE["p_rock_snow_%d" % (_i + 1)] = (rock, "p_rock_snow_%d" % (_i + 1), 6 + _i * 2, True)
    TABLE["p_bush_%d" % (_i + 1)] = (bush, "p_bush_%d" % (_i + 1), 1 + _i)
    TABLE["p_grass_%d" % (_i + 1)] = (grass, "p_grass_%d" % (_i + 1), 1 + _i)
    TABLE["p_wreck_%d" % (_i + 1)] = (wreck, "p_wreck_%d" % (_i + 1), 1 + _i)
    TABLE["p_cloud_%d" % (_i + 1)] = (cloud, "p_cloud_%d" % (_i + 1), 1 + _i)
_FL = ((("FFFFFF", "FFD23E"), ("FFFFFF", "FFD23E"), ("FFF3B0", "F28A1E")), (("F07AB4", "FFE25A"), ("F9A8CE", "FFE25A"), ("C97AF0", "FFE25A")),
       (("FFD23E", "F28A1E"), ("6FA8F5", "FFFFFF"), ("FF8A3A", "FFE25A")))
for _i in range(3):
    TABLE["p_flowers_%d" % (_i + 1)] = (flowers, "p_flowers_%d" % (_i + 1), 1 + _i, _FL[_i])
TABLE.update({"p_mushroom_1": mushroom_1, "p_stump_1": stump_1, "p_log_1": log_1, "p_fence": fence, "p_container_1": container_1,
              "p_barrel_1": barrel_1, "p_crate_1": crate_1, "p_bridge": bridge, "p_signpost": signpost, "p_campfire": campfire,
              "p_chest": (chest, "p_chest", "E8E2D4", GOLD, WOOD, "plain"), "p_nest": nest, "p_cage": cage, "p_gate": gate,
              "p_enemy_tower": enemy_tower, "p_flag_exit": flag_exit, "p_drone": drone, "p_coin": coin_single})
for _k in ("wood", "stone", "metal", "fuel", "cells", "parts", "shards", "coins"):
    TABLE["p_pile_" + _k] = (pile, "p_pile_" + _k, _k)
for _k in ("coins", "wood", "stone", "metal", "fuel", "cells", "parts", "shards"):
    TABLE["res_" + _k] = (res, "res_" + _k)
for _k, _v in CHESTS.items():
    TABLE["chest_" + _k] = (chest, "chest_" + _k, _v[0], _v[1], _v[2], _v[3], False, -14.0 if _k == "flood_gold" else 0.0)

if __name__ == "__main__":
    run(TABLE, sys.argv)
