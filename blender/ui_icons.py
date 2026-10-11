"""Kleine glänzende 3D-Symbole für die Menüs (ui_<name>, 128 px), im Stil der Waffen.
Jedes Symbol ist auch ein Modell (ein Objekt `body`, etwa 0,5 m, Vorderseite -Y).
Aufruf: python3 blender/ui_icons.py [ui_heart ...]   (ohne Namen: alle)

Gebaut wird im Einheitsraum (etwa -0,5 .. 0,5, Symbolfläche = X-Z-Ebene), am Ende auf 0,5 m skaliert."""
import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from kit import *
from weapons import (prism, star, star_pts, lathe, sweep, arc, arc2, toon, tris, scale_all, merge, Y, hole, ring, args,
                     BLUE, BLUE_L, BLUE_D, NAVY, YEL, YEL_L, ORG, RED, RED_D, GRN, GRN_D, PINK, PINK_D, VIO, VIO_D,
                     WHITE, GREY, GREY_L, DGREY, HOLE, CYAN, TAN, WOOD, TEAL)
from gear import heart_pts, clover, vest_base, dome, over, VEST

GOLD_D, STEEL, DARK, PAPER, PAPER_D, BROWN = "FFAE1F", "A9BCEB", "3A4670", "FFF2D0", "EBCF9A", "9A5A2C"
FLAT = (-18.0, 10.0)          # Blick für flache Zeichen
SOLID = (-34.0, 24.0)         # Blick für körperhafte Dinge


def X(p, rad, x0, x1, y, z, color, sides=14, bevel=0.0, segs=1, r2=None):
    """Zylinder entlang X von x0 nach x1."""
    p.cyl(rad, abs(x1 - x0), ((x0 + x1) * 0.5, y, z), color, r=rot(0, 90, 0), sides=sides, bevel=bevel, segs=segs, r2=r2)


def D(p, rad, depth, x, z, color, y=0.0, sides=24, bevel=0.0, segs=2):
    """Scheibe in der X-Z-Ebene (Achse Y)."""
    Y(p, rad, y + depth * 0.5, y - depth * 0.5, z, color, sides=sides, bevel=bevel, x=x, segs=segs)


def bar(p, size, c, a, d, color, bevel=0.0, segs=1):
    """Stab in der X-Z-Ebene: beginnt bei c = (x, y, z), zeigt in Richtung a (Grad, 0 = oben, im Uhrzeigersinn), Länge size[2]."""
    m = rot(0, a, 0)
    q = m @ Vector((0, 0, size[2] * 0.5 + d))
    p.box(size, (c[0] + q.x, c[1], c[2] + q.z), color, r=m, bevel=bevel, segs=segs)


def part(p, fn, m):
    """Baut fn(q) in ein eigenes Teil, wendet die Matrix m an und hängt es an p."""
    q = Part()
    fn(q)
    for v in q.bm.verts:
        v.co = m @ v.co
    merge(p, q)


def gleam(p, x, z, y, w=0.1, h=0.04, a=-35, color=WHITE):
    p.ball(1.0, (x, y, z), color, scale=(w, 0.012, h), r=rot(0, a, 0), subdiv=1)


T = Matrix.Translation
S = lambda k: Matrix.Diagonal(Vector((k, k, k, 1)))


# ------------------------------------------------------------------ Zeichen
def heart(p):
    a = 0.58                                             # Quadrat auf der Spitze + zwei Kugeln
    p.box((a, 0.36, a), (0, 0, -0.07), RED, r=rot(0, 45, 0), bevel=0.1, segs=3)
    for sx in (-1, 1):
        p.ball(a * 0.5, (sx * a * 0.354, 0, -0.07 + a * 0.354), RED, scale=(1, 0.62, 1), subdiv=3)
    gleam(p, -0.27, 0.24, -0.15, 0.1, 0.045)


SHIELD = [(0, 0.5), (0.2, 0.44), (0.42, 0.4), (0.42, 0.05), (0.36, -0.16), (0.22, -0.36), (0, -0.52), (-0.22, -0.36), (-0.36, -0.16), (-0.42, 0.05), (-0.42, 0.4), (-0.2, 0.44)]


def shield(p):
    prism(p, SHIELD, 0.22, (0, 0, 0), GREY_L, bevel=0.06, segs=2)
    prism(p, [(x * 0.76, z * 0.76 - 0.005) for x, z in SHIELD], 0.3, (0, 0, 0), BLUE, bevel=0.04, segs=2)
    prism(p, [(x * 0.76, z * 0.76 - 0.005) for x, z in SHIELD[:7]], 0.31, (0, 0, 0), BLUE_D)
    gleam(p, -0.18, 0.2, -0.16, 0.09, 0.035)


def ustar(p):
    star(p, 0.54, 0.36, (0, 0, 0), YEL, color2=GOLD_D)
    gleam(p, -0.1, 0.12, -0.14, 0.07, 0.03)


def clock(p):
    D(p, 0.45, 0.2, 0, 0, BLUE, bevel=0.05)
    D(p, 0.35, 0.24, 0, 0, WHITE)
    for a in range(0, 360, 90):
        bar(p, (0.05, 0.03, 0.08), (0, -0.115, 0), a, 0.24, DARK)
    bar(p, (0.07, 0.04, 0.26), (0, -0.125, 0), 0, -0.02, NAVY, bevel=0.015)
    bar(p, (0.07, 0.04, 0.2), (0, -0.125, 0), 115, -0.02, NAVY, bevel=0.015)
    p.ball(0.055, (0, -0.13, 0), RED, subdiv=1)
    p.cyl(0.07, 0.1, (0, 0, 0.5), YEL, sides=10, bevel=0.02, segs=1)
    for sx in (-1, 1):
        p.ball(0.07, (sx * 0.36, 0, 0.4), YEL, subdiv=1)


def lock(p):
    sweep(p, [(0.2, 0, 0.0)] + arc(0, 0.2, 0.2, 0, 180, 10) + [(-0.2, 0, 0.0)], 0.07, GREY_L, sides=8, ref=(0, 1, 0))
    p.box((0.68, 0.32, 0.52), (0, 0, -0.2), YEL, bevel=0.1, segs=3)
    p.box((0.7, 0.33, 0.08), (0, 0, -0.03), GOLD_D, bevel=0.02, segs=1)
    D(p, 0.075, 0.04, 0, -0.18, HOLE, y=-0.16, sides=12)
    p.box((0.06, 0.04, 0.16), (0, -0.16, -0.27), HOLE)
    gleam(p, -0.2, -0.1, -0.165, 0.07, 0.03)


def skull(p):
    p.ball(0.42, (0, 0, 0.1), WHITE, scale=(1, 0.9, 0.9), subdiv=3)
    p.box((0.46, 0.44, 0.3), (0, -0.03, -0.28), WHITE, bevel=0.09, segs=3)
    for sx in (-1, 1):
        p.ball(0.13, (sx * 0.17, -0.3, 0.04), HOLE, scale=(1, 0.5, 1.1), subdiv=2)
        p.box((0.03, 0.05, 0.13), (sx * 0.085, -0.235, -0.36), HOLE)
    p.box((0.03, 0.05, 0.13), (0, -0.235, -0.36), HOLE)
    prism(p, [(-0.055, -0.05), (0.055, -0.05), (0, 0.06)], 0.06, (0, -0.33, -0.13), HOLE)


def pack(p):
    p.box((0.66, 0.4, 0.74), (0, 0, -0.08), ORG, bevel=0.15, segs=3)
    p.box((0.69, 0.43, 0.3), (0, 0, 0.17), "E8641A", bevel=0.11, segs=3)
    p.box((0.42, 0.14, 0.26), (0, -0.21, -0.22), "FFAE4A", bevel=0.06)
    p.box((0.44, 0.15, 0.07), (0, -0.215, -0.1), "E8641A", bevel=0.02, segs=1)
    p.box((0.1, 0.08, 0.2), (0, -0.2, 0.06), DARK, bevel=0.02, segs=1)
    p.box((0.14, 0.09, 0.1), (0, -0.22, 0.02), YEL, bevel=0.025, segs=1)
    X(p, 0.12, -0.36, 0.36, 0.02, 0.4, GRN, bevel=0.03)                                   # Schlafrolle
    for sx in (-1, 1):
        X(p, 0.127, sx * 0.2 - 0.03, sx * 0.2 + 0.03, 0.02, 0.4, DARK, sides=14)
        p.box((0.1, 0.26, 0.3), (sx * 0.36, 0, -0.22), "E8641A", bevel=0.04, segs=1)


def drone(p):
    p.ball(0.27, (0, 0, 0), WHITE, scale=(1.1, 1.1, 0.75), subdiv=3)
    p.torus(0.28, 0.045, (0, 0, 0), BLUE, seg=16, tseg=5)
    for a in (45, 135, 225, 315):
        ca, sa = math.cos(math.radians(a)), math.sin(math.radians(a))
        p.box((0.34, 0.09, 0.07), (ca * 0.3, sa * 0.3, 0.02), DARK, r=rot(0, 0, a), bevel=0.02, segs=1)
        p.cyl(0.06, 0.16, (ca * 0.44, sa * 0.44, 0.07), BLUE, sides=8)
        p.cyl(0.23, 0.04, (ca * 0.44, sa * 0.44, 0.16), CYAN, sides=14, bevel=0.012, segs=1)
        p.ball(0.06, (ca * 0.44, sa * 0.44, 0.18), YEL, subdiv=1)
    p.ball(0.13, (0, -0.24, -0.03), NAVY, subdiv=2)
    p.ball(0.065, (0, -0.35, -0.03), RED, subdiv=1)
    for sx in (-1, 1):
        p.box((0.06, 0.34, 0.06), (sx * 0.15, 0, -0.27), DARK, bevel=0.02, segs=1)
        p.box((0.05, 0.05, 0.16), (sx * 0.15, 0, -0.19), DARK)


def badge(p):
    prism(p, [(-0.34, 0.52), (-0.1, 0.52), (0.12, 0.02), (-0.12, 0.02)], 0.08, (0, 0.02, 0), VIO_D, bevel=0.02, segs=1)
    prism(p, [(0.34, 0.52), (0.1, 0.52), (-0.12, 0.02), (0.12, 0.02)], 0.08, (0, -0.02, 0), PINK, bevel=0.02, segs=1)
    D(p, 0.34, 0.2, 0, -0.18, YEL, bevel=0.05)
    D(p, 0.26, 0.24, 0, -0.18, VIO)
    star(p, 0.19, 0.1, (0, -0.12, -0.18), YEL_L, color2=YEL)


def bolt(p):
    prism(p, [(0.14, 0.54), (-0.3, -0.06), (-0.04, -0.06), (-0.18, -0.54), (0.32, 0.1), (0.05, 0.1), (0.3, 0.54)], 0.26, (0, 0, 0), YEL, bevel=0.05, segs=2)
    gleam(p, -0.02, 0.3, -0.135, 0.09, 0.025, a=-52, color=YEL_L)


def up(p):
    prism(p, [(0, 0.52), (0.44, 0.04), (0.19, 0.04), (0.19, -0.48), (-0.19, -0.48), (-0.19, 0.04), (-0.44, 0.04)], 0.28, (0, 0, 0), GRN, bevel=0.07, segs=3)
    gleam(p, -0.13, 0.24, -0.145, 0.09, 0.03, a=-45, color="B6F5B0")


def speed(p):
    D(p, 0.48, 0.2, 0, 0, NAVY, bevel=0.05)
    D(p, 0.39, 0.24, 0, 0, WHITE)
    for i, a in enumerate(range(-120, 121, 30)):
        bar(p, (0.085, 0.03, 0.1), (0, -0.115, 0), a, 0.24, GRN if i < 3 else (YEL if i < 6 else RED), bevel=0.01)
    bar(p, (0.07, 0.05, 0.3), (0, -0.13, 0), 55, -0.04, RED, bevel=0.02)
    p.ball(0.075, (0, -0.13, 0), NAVY, subdiv=2)
    p.box((0.26, 0.03, 0.1), (0, -0.115, -0.24), DARK, bevel=0.02, segs=1)


def crate(p):
    s = 0.4
    p.box((0.78, 0.78, 0.78), (0, 0, 0), TAN, bevel=0.02, segs=1)
    for a in (-1, 1):
        for b in (-1, 1):
            p.box((0.88, 0.12, 0.12), (0, a * s, b * s), WOOD, bevel=0.025, segs=1)
            p.box((0.12, 0.88, 0.12), (a * s, 0, b * s), WOOD, bevel=0.025, segs=1)
            p.box((0.12, 0.12, 0.88), (a * s, b * s, 0), WOOD, bevel=0.025, segs=1)
    p.box((0.1, 0.05, 1.0), (0, -0.4, 0), WOOD, r=rot(0, 45, 0), bevel=0.02, segs=1)
    p.box((0.05, 0.1, 1.0), (-0.4, 0, 0), WOOD, r=rot(45, 0, 0), bevel=0.02, segs=1)
    p.box((1.0, 0.1, 0.05), (0, 0, 0.4), WOOD, r=rot(0, 0, 45), bevel=0.02, segs=1)


def water(p):
    for k, (z, c, ph) in enumerate(((0.3, CYAN, 0.0), (0.0, BLUE, 1.6), (-0.3, "3F7BFF", 3.2))):
        pts = [(-0.5 + i / 16.0, 0, z + 0.085 * math.sin(i / 16.0 * 4 * math.pi + ph)) for i in range(17)]
        sweep(p, pts, 0.1, c, sides=8, ref=(0, 1, 0))
        p.ball(0.1, pts[0], c, subdiv=1)
        p.ball(0.1, pts[-1], c, subdiv=1)


def hammer(p):
    c = "6C7CA8"
    p.box((0.66, 0.34, 0.17), (0.06, 0, -0.1), c, bevel=0.04)
    p.cone(0.085, 0.3, (-0.4, 0, -0.085), c, r=rot(0, -90, 0), sides=10)
    p.box((0.3, 0.26, 0.16), (0.06, 0, -0.25), DARK, bevel=0.03, segs=1)
    p.box((0.6, 0.34, 0.15), (0.06, 0, -0.4), c, bevel=0.04)

    def h(q):
        q.cyl(0.05, 0.62, (0, 0, 0), ORG, sides=8)
        q.box((0.44, 0.22, 0.24), (0, 0, 0.3), GREY_L, bevel=0.05)
        q.box((0.1, 0.23, 0.25), (0, 0, 0.3), YEL, bevel=0.02, segs=1)
    part(p, h, T(Vector((0.22, -0.02, 0.28))) @ rot(0, 52, 0))
    star(p, 0.1, 0.07, (-0.2, -0.1, 0.12), YEL_L, n=4, inner=0.36)


def wrench(p):
    def w(q):
        q.box((0.17, 0.14, 0.62), (0, 0, -0.05), GREY_L, bevel=0.05)
        prism(q, [(-0.24, 0.2), (-0.24, 0.47), (-0.11, 0.56), (-0.09, 0.34), (0.09, 0.34), (0.11, 0.56), (0.24, 0.47), (0.24, 0.2), (0.11, 0.1), (-0.11, 0.1)], 0.15, (0, 0, 0), GREY_L, bevel=0.03, segs=1)
        ring(q, 0.13, 0.065, 0, -0.42, GREY_L, seg=14, tseg=6)
        q.box((0.175, 0.145, 0.2), (0, 0, -0.08), BLUE, bevel=0.03, segs=1)
    part(p, w, rot(0, 40, 0))


def sword(p):
    def w(q):
        prism(q, [(-0.1, -0.2), (0.1, -0.2), (0.1, 0.5), (0, 0.66), (-0.1, 0.5)], 0.08, (0, 0, 0), "DCE8FF", bevel=0.02, segs=1)
        q.box((0.035, 0.1, 0.62), (0, 0, 0.14), BLUE_L, bevel=0.012, segs=1)
        q.box((0.44, 0.14, 0.1), (0, 0, -0.22), YEL, bevel=0.04)
        q.cyl(0.055, 0.2, (0, 0, -0.36), BLUE, sides=8)
        q.ball(0.085, (0, 0, -0.5), YEL, subdiv=2)
    part(p, w, rot(0, 42, 0) @ T(Vector((0, 0, -0.06))))


def helmet(p):
    R, H, z0 = 0.42, 0.46, -0.1
    dome(p, R, H, z0, STEEL, sides=18)
    lathe(p, [(0.0, -0.4), (0.4, -0.4), (0.46, -0.36), (0.42, z0)], (0, 0, 0), ["2A3260", "2A3260", STEEL], sides=18)
    p.torus(0.45, 0.045, (0, 0, -0.36), BLUE, seg=18, tseg=6)
    p.box((0.5, 0.16, 0.11), (0, -0.37, -0.02), HOLE, bevel=0.03, segs=1)
    p.box((0.1, 0.16, 0.28), (0, -0.39, -0.2), HOLE, bevel=0.03, segs=1)
    p.box((0.6, 0.14, 0.06), (0, -0.39, 0.08), BLUE, bevel=0.02, segs=1)
    sweep(p, over(R, H, z0, 22, 175), 0.05, BLUE, sides=6)


def vest(p):
    def v(q):
        vest_base(q, STEEL, "2A3260")
        q.box((0.03, 0.02, 0.33), (0, -0.127, 0.17), BLUE)
        for sx in (-1, 1):
            q.box((0.13, 0.05, 0.1), (sx * 0.12, -0.12, 0.1), BLUE, bevel=0.02, segs=1)
            q.box((0.14, 0.055, 0.035), (sx * 0.12, -0.12, 0.15), BLUE_L, bevel=0.01, segs=1)
    part(p, v, S(2.0) @ T(Vector((0, 0, -0.25))))


def uclover(p):
    clover(p, (0, 0, 0.08), 1.55)


def grid(p):
    for i, (sx, sz) in enumerate(((-1, 1), (1, 1), (-1, -1), (1, -1))):
        p.box((0.42, 0.2, 0.42), (sx * 0.25, 0, sz * 0.25), YEL if i in (0, 3) else GOLD_D, bevel=0.1, segs=3)


def recycle(p):
    for k in range(3):
        a0 = 90 + 120 * k
        pts = arc(0, 0, 0.36, a0 + 12, a0 + 82, 6)
        sweep(p, pts, 0.085, WHITE, sides=8, ref=(0, 1, 0))
        a = a0 + 88
        e = Vector((0.36 * math.cos(math.radians(a)), 0, 0.36 * math.sin(math.radians(a))))
        t = Vector((-math.sin(math.radians(a)), 0, math.cos(math.radians(a))))
        p.cone(0.19, 0.26, e + t * 0.08, WHITE, r=rot(0, -a, 0), sides=10)


def merge_icon(p):
    for sx, c in ((-1, CYAN), (0, YEL), (1, PINK)):
        pts = [(sx * 0.38, 0, -0.5), (sx * 0.36, 0, -0.32), (sx * 0.2, 0, -0.14), (0, 0, 0.0)] if sx else [(0, 0, -0.5), (0, 0, 0.0)]
        sweep(p, pts, 0.075, c, sides=8, ref=(0, 1, 0))
        p.ball(0.11, (sx * 0.38, 0, -0.5), c, subdiv=2)
    p.cyl(0.085, 0.3, (0, 0, 0.12), WHITE, sides=10)
    p.ball(0.085, (0, 0, 0.0), WHITE, subdiv=1)
    p.cone(0.24, 0.32, (0, 0, 0.4), WHITE, sides=12)


def info(p):
    D(p, 0.48, 0.24, 0, 0, BLUE, bevel=0.07, segs=3)
    p.box((0.14, 0.1, 0.36), (0, -0.11, -0.12), WHITE, bevel=0.04)
    p.ball(0.095, (0, -0.13, 0.22), WHITE, scale=(1, 0.6, 1), subdiv=2)
    gleam(p, -0.26, 0.26, -0.125, 0.1, 0.03, color=BLUE_L)


def check(p):
    prism(p, [(-0.5, -0.02), (-0.33, 0.16), (-0.13, -0.06), (0.32, 0.46), (0.5, 0.29), (-0.13, -0.44)], 0.28, (0, 0, 0), GRN, bevel=0.06, segs=2)


def close(p):
    for a in (45, -45):
        p.box((0.25, 0.24 if a > 0 else 0.25, 1.1), (0, 0, 0), WHITE, r=rot(0, a, 0), bevel=0.09, segs=3)   # ungleich dick: keine deckungsgleichen Flächen


def gear(p):
    pts = []
    n = 8
    for i in range(n):
        for da, rr in ((-0.3, 0.36), (-0.2, 0.5), (0.2, 0.5), (0.3, 0.36)):
            a = (i + da) * 2 * math.pi / n
            pts.append((rr * math.cos(a), rr * math.sin(a)))
    prism(p, pts, 0.22, (0, 0, 0), GREY_L, bevel=0.03, segs=1)
    D(p, 0.27, 0.28, 0, 0, STEEL, sides=16)
    D(p, 0.14, 0.29, 0, 0, DARK, sides=14)


def flag(p):
    p.cyl(0.045, 1.02, (-0.36, 0, 0), GREY_L, sides=8)
    p.ball(0.08, (-0.36, 0, 0.53), YEL, subdiv=2)
    p.cyl(0.18, 0.09, (-0.36, 0, -0.5), DARK, sides=12, bevel=0.03, segs=1)
    n = 8
    top = [(-0.34 + 0.8 * i / n, 0.44 + 0.055 * math.sin(i / n * 2 * math.pi)) for i in range(n + 1)]
    bot = [(x, z - 0.46) for x, z in top]
    prism(p, top[::-1] + bot, 0.09, (0, 0, 0), RED, bevel=0.02, segs=1)
    star(p, 0.11, 0.06, (0.06, -0.04, 0.2), YEL)


def umap(p):
    for k in (-1, 0, 1):
        p.box((0.31, 0.04, 0.78), (k * 0.28, 0.04 if k == 0 else -0.0, 0), PAPER if k != 0 else PAPER_D, r=rot(0, 0, -20 if k == 0 else 20) if False else rot(0, 0, 0), bevel=0.012, segs=1)
    y = -0.03
    p.ball(1.0, (-0.28, y, 0.16), GRN, scale=(0.1, 0.012, 0.13), subdiv=1)
    p.ball(1.0, (0.02, y + 0.04, -0.22), BLUE_L, scale=(0.1, 0.012, 0.08), subdiv=1)
    for (x, z, a) in ((-0.26, -0.2, 30), (-0.12, -0.05, 60), (0.02, 0.1, 40), (0.14, 0.22, 60)):
        p.box((0.035, 0.02, 0.09), (x, y + (0.04 if abs(x) < 0.14 else 0.0), z), DARK, r=rot(0, a, 0))
    for a in (45, -45):
        p.box((0.05, 0.03, 0.2), (0.29, y, 0.25), RED, r=rot(0, a, 0))
    for k in (-0.14, 0.14):
        p.box((0.012, 0.03, 0.78), (k, 0.0, 0), PAPER_D)


def trophy(p):
    lathe(p, [(0.0, 0.0), (0.14, 0.02), (0.28, 0.14), (0.34, 0.5), (0.3, 0.5), (0.0, 0.46)], (0, 0, 0), [YEL, YEL, YEL, YEL_L, GOLD_D], sides=16)
    p.torus(0.335, 0.03, (0, 0, 0.5), YEL_L, seg=16, tseg=5)
    for sx in (-1, 1):
        sweep(p, arc(sx * 0.32, 0.28, 0.15, -90 * sx + (0 if sx > 0 else 180), 90 * sx + (0 if sx > 0 else 180), 7), 0.045, YEL, sides=6, ref=(0, 1, 0))
    p.cyl(0.07, 0.2, (0, 0, -0.08), YEL, sides=10)
    p.cyl(0.16, 0.06, (0, 0, -0.17), YEL, sides=12)
    p.box((0.46, 0.34, 0.2), (0, 0, -0.3), NAVY, bevel=0.04)
    p.box((0.26, 0.03, 0.09), (0, -0.17, -0.3), YEL, bevel=0.01, segs=1)
    star(p, 0.13, 0.06, (0, -0.31, 0.3), WHITE, r=rot(8, 0, 0))


def mail(p):
    p.box((0.96, 0.16, 0.64), (0, 0, 0), PAPER, bevel=0.05)
    prism(p, [(-0.46, 0.3), (0.46, 0.3), (0, -0.08)], 0.05, (0, -0.075, 0), PAPER_D, bevel=0.015, segs=1)
    prism(p, [(-0.46, -0.3), (0.46, -0.3), (0, 0.02)], 0.03, (0, -0.07, 0), "F6E3B4")
    D(p, 0.1, 0.05, 0, -0.03, RED, y=-0.105, sides=12, bevel=0.015, segs=1)


def friends(p):
    def f(q, c, cs):
        q.ball(0.2, (0, 0, 0.24), cs, subdiv=3)
        lathe(q, [(0.0, -0.5), (0.3, -0.5), (0.31, -0.25), (0.22, -0.06), (0.0, -0.0)], (0, 0, 0), c, r=Matrix.Diagonal(Vector((1, 0.62, 1, 1))), sides=14)
    part(p, lambda q: f(q, GRN, "FFD9B0"), T(Vector((0.22, 0.14, 0.1))) @ S(0.88))
    part(p, lambda q: f(q, BLUE, "FFE0BC"), T(Vector((-0.14, -0.08, 0.0))))


def clan(p):
    X(p, 0.045, -0.48, 0.48, 0, 0.46, YEL, sides=8)
    for sx in (-1, 1):
        p.ball(0.075, (sx * 0.48, 0, 0.46), YEL, subdiv=1)
    prism(p, [(-0.38, 0.46), (0.38, 0.46), (0.38, -0.46), (0, -0.26), (-0.38, -0.46)], 0.1, (0, 0, 0), RED, bevel=0.025, segs=1)
    p.box((0.77, 0.11, 0.1), (0, 0, 0.36), BLUE, bevel=0.02, segs=1)
    prism(p, [(x * 0.42, z * 0.42 + 0.03) for x, z in SHIELD], 0.14, (0, 0, 0), YEL, bevel=0.02, segs=1)
    star(p, 0.1, 0.06, (0, -0.07, 0.05), RED_D)


def quest(p):
    p.box((0.62, 0.06, 0.8), (0, 0, 0), PAPER, bevel=0.012, segs=1)
    for sz in (-1, 1):
        X(p, 0.09, -0.36, 0.36, 0, sz * 0.42, PAPER_D, sides=10)
        for sx in (-1, 1):
            p.ball(0.07, (sx * 0.39, 0, sz * 0.42), BROWN, subdiv=1)
    for i, z in enumerate((0.2, 0.07, -0.06)):
        p.box((0.4 if i < 2 else 0.24, 0.02, 0.05), (0 if i < 2 else -0.08, -0.035, z), BROWN)
    D(p, 0.09, 0.04, 0.14, -0.22, RED, y=-0.04, sides=12)
    star(p, 0.05, 0.03, (0.14, -0.06, -0.22), YEL_L)


def chest(p):
    p.box((0.9, 0.6, 0.42), (0, 0, -0.22), WOOD, bevel=0.04, segs=1)
    X(p, 0.3, -0.44, 0.44, 0, -0.02, "C98548", sides=16)
    for x in (-0.3, 0.3):
        p.box((0.12, 0.64, 0.45), (x, 0, -0.22), YEL, bevel=0.02, segs=1)
        X(p, 0.32, x - 0.06, x + 0.06, 0, -0.02, YEL, sides=16)
    p.box((0.94, 0.64, 0.07), (0, 0, -0.02), GOLD_D, bevel=0.02, segs=1)
    p.box((0.18, 0.1, 0.22), (0, -0.31, -0.06), YEL, bevel=0.04)
    p.box((0.05, 0.04, 0.1), (0, -0.36, -0.08), HOLE)


def fuel(p):
    p.box((0.64, 0.34, 0.74), (0, 0, -0.1), RED, bevel=0.1, segs=3)
    p.cyl(0.09, 0.18, (0.17, 0, 0.34), YEL, sides=10, bevel=0.02, segs=1)
    sweep(p, [(-0.26, 0, 0.26)] + arc(-0.1, 0.27, 0.16, 180, 20, 6), 0.05, RED_D, sides=6, ref=(0, 1, 0))
    p.ball(0.13, (0, -0.17, -0.2), YEL, scale=(1, 0.35, 1), subdiv=2)                       # Tropfen
    p.cone(0.11, 0.22, (0, -0.17, -0.06), YEL, r=Matrix.Diagonal(Vector((1, 0.35, 1, 1))), sides=10)
    gleam(p, -0.2, 0.12, -0.175, 0.07, 0.03, color="FF9A8A")


def target(p):
    ring(p, 0.4, 0.07, 0, 0, RED, seg=24, tseg=6)
    ring(p, 0.2, 0.055, 0, 0, WHITE, seg=16, tseg=6)
    p.ball(0.08, (0, 0, 0), RED, subdiv=2)
    for a in range(0, 360, 90):
        bar(p, (0.09, 0.1, 0.24), (0, 0, 0), a, 0.3, WHITE, bevel=0.03)


def boot(p):
    prism(p, [(-0.32, 0.46), (0.02, 0.46), (0.03, 0.02), (0.36, -0.1), (0.46, -0.26), (0.46, -0.36), (-0.32, -0.36)], 0.32, (0, 0, 0), ORG, bevel=0.07, segs=2)
    p.box((0.84, 0.35, 0.1), (0.07, 0, -0.41), DARK, bevel=0.03, segs=1)
    p.box((0.4, 0.36, 0.13), (-0.15, 0, 0.42), YEL, bevel=0.04)
    for z in (0.2, 0.06):
        p.box((0.14, 0.04, 0.045), (-0.02, -0.16, z), WHITE, r=rot(0, 20, 0))
    prism(p, [(0.0, 0.0), (-0.3, 0.2), (-0.22, 0.07), (-0.36, 0.05), (-0.22, -0.04), (-0.3, -0.12), (0.0, -0.12)], 0.1, (-0.28, -0.1, 0.02), WHITE, bevel=0.02, segs=1)


def fire(p):
    prism(p, [(0.02, 0.58), (0.18, 0.32), (0.32, 0.12), (0.38, -0.12), (0.3, -0.36), (0.1, -0.48), (-0.1, -0.48), (-0.3, -0.36), (-0.38, -0.1), (-0.33, 0.12),
              (-0.24, 0.28), (-0.17, 0.08), (-0.08, 0.3)], 0.3, (0, 0, 0), "FF6A1A", bevel=0.06, segs=2)
    prism(p, [(0.02, 0.16), (0.17, -0.1), (0.19, -0.28), (0.08, -0.41), (-0.08, -0.41), (-0.19, -0.28), (-0.15, -0.1)], 0.36, (0, 0, 0), YEL, bevel=0.04, segs=1)


def snow(p):
    c = "BFF0FF"
    for k in range(3):
        p.box((0.11, 0.14 + 0.008 * k, 1.04), (0, 0, 0), c, r=rot(0, 60 * k, 0), bevel=0.04, segs=1)
    for k in range(6):
        for s in (-1, 1):
            m = rot(0, 60 * k, 0)
            q = m @ Vector((0, 0, 0.3))
            bar(p, (0.08, 0.12, 0.2), (q.x, 0, q.z), 60 * k + s * 50, 0.0, c, bevel=0.025)
    p.ball(0.11, (0, -0.02, 0), WHITE, scale=(1, 0.8, 1), subdiv=2)


def walk(p):
    c = WHITE
    p.ball(0.14, (0.06, 0, 0.42), c, subdiv=2)
    hip, sh = (0.0, 0, -0.04), (0.035, 0, 0.24)
    p.box((0.2, 0.17, 0.36), (0.02, 0, 0.12), c, r=rot(0, 8, 0), bevel=0.07)
    bar(p, (0.115, 0.15, 0.27), hip, 150, -0.03, c, bevel=0.04)                          # vorderes Bein
    bar(p, (0.105, 0.15, 0.24), (0.13, 0, -0.26), 185, -0.03, c, bevel=0.04)
    bar(p, (0.115, 0.15, 0.27), hip, 205, -0.03, BLUE_L, bevel=0.04)                     # hinteres Bein
    bar(p, (0.105, 0.15, 0.24), (-0.1, 0, -0.26), 235, -0.03, BLUE_L, bevel=0.04)
    bar(p, (0.085, 0.13, 0.22), sh, 135, -0.02, c, bevel=0.03)                           # Arme
    bar(p, (0.08, 0.13, 0.18), (0.18, 0, 0.1), 70, -0.03, c, bevel=0.03)
    bar(p, (0.085, 0.13, 0.22), sh, 215, -0.02, BLUE_L, bevel=0.03)
    bar(p, (0.08, 0.13, 0.17), (-0.09, 0, 0.07), 180, -0.03, BLUE_L, bevel=0.03)
    p.box((0.2, 0.15, 0.08), (0.19, 0, -0.47), c, bevel=0.03, segs=1)
    p.box((0.18, 0.15, 0.08), (-0.33, 0, -0.4), BLUE_L, r=rot(0, 40, 0), bevel=0.03, segs=1)


def garage(p):
    prism(p, [(-0.46, -0.42), (0.46, -0.42), (0.46, 0.1), (0, 0.42), (-0.46, 0.1)], 0.76, (0, 0, 0), STEEL)
    for sx in (-1, 1):
        p.box((0.66, 0.86, 0.09), (sx * 0.25, 0, 0.3), RED, r=rot(0, sx * 34.8, 0), bevel=0.03, segs=1)
    p.box((0.6, 0.05, 0.46), (0, -0.37, -0.19), GREY_L, bevel=0.015, segs=1)
    for z in (-0.3, -0.19, -0.08):
        p.box((0.6, 0.06, 0.025), (0, -0.375, z), DARK)
    p.box((0.68, 0.06, 0.06), (0, -0.38, 0.06), YEL, bevel=0.015, segs=1)
    D(p, 0.07, 0.04, 0, 0.21, YEL_L, y=-0.385, sides=10)


def build(p):
    c, m = "E8603A", "F0D8B0"
    p.box((0.86, 0.3, 0.42), (0, 0, -0.29), m, bevel=0.012, segs=1)
    for x, z, w in ((-0.22, -0.39, 0.4), (0.22, -0.39, 0.4), (0.0, -0.18, 0.4), (-0.36, -0.18, 0.2), (0.36, -0.18, 0.2)):
        p.box((w, 0.34, 0.18), (x, 0, z), c, bevel=0.03, segs=1)

    def t(q):
        prism(q, [(0, 0.34), (0.19, 0.0), (0, -0.12), (-0.19, 0.0)], 0.05, (0, 0, 0.2), GREY_L, bevel=0.015, segs=1)
        q.box((0.05, 0.05, 0.14), (0, -0.04, 0.03), GREY)
        q.cyl(0.06, 0.26, (0, -0.08, -0.14), ORG, sides=8, bevel=0.02, segs=1)
    part(p, t, T(Vector((0.08, -0.06, 0.22))) @ rot(0, 125, 0))


def expedition(p):
    D(p, 0.45, 0.2, 0, -0.04, YEL, bevel=0.05)
    D(p, 0.36, 0.24, 0, -0.04, WHITE)
    ring(p, 0.09, 0.035, 0, 0.47, YEL, seg=10, tseg=5)
    for a in range(0, 360, 90):
        bar(p, (0.045, 0.03, 0.07), (0, -0.115, -0.04), a, 0.26, DARK)
    m = T(Vector((0, -0.14, -0.04))) @ rot(0, 38, 0)
    prism(p, [(-0.085, 0), (0.085, 0), (0, 0.3)], 0.06, (0, 0, 0), RED, r=m)
    prism(p, [(-0.085, 0), (0.085, 0), (0, -0.3)], 0.06, (0, 0, 0), BLUE, r=m)
    p.ball(0.05, (0, -0.16, -0.04), YEL, subdiv=1)


def flood(p):
    s, sl = "8DB82A", "C8E24A"
    prism(p, [(-0.5, -0.46), (0.5, -0.46), (0.5, -0.2), (0.32, -0.16), (0.17, 0.0), (0.13, 0.18), (0.2, 0.3), (0.33, 0.31), (0.43, 0.22), (0.45, 0.38), (0.3, 0.51),
              (0.08, 0.55), (-0.14, 0.47), (-0.32, 0.27), (-0.43, 0.02), (-0.5, -0.2)], 0.32, (0, 0, 0), s, bevel=0.035, segs=1)
    prism(p, [(-0.53, -0.49), (0.53, -0.49), (0.53, -0.28), (0.25, -0.34), (0, -0.22), (-0.25, -0.34), (-0.53, -0.24)], 0.4, (0, 0, 0), sl, bevel=0.02, segs=1)
    for sx in (-1, 1):                                                                          # Schleimaugen
        p.ball(0.085, (-0.1 + sx * 0.12, -0.15, 0.2), WHITE, scale=(1, 0.5, 1.15), subdiv=2)
        p.ball(0.04, (-0.08 + sx * 0.12, -0.19, 0.19), HOLE, scale=(1, 0.5, 1.1), subdiv=1)
    p.ball(0.05, (-0.3, -0.16, -0.06), sl, scale=(1, 0.5, 1), subdiv=1)
    p.ball(0.06, (0.36, 0, 0.06), s, scale=(1, 1, 1.4), subdiv=1)


def alarm(p):
    lathe(p, [(0.0, 0.42), (0.1, 0.4), (0.2, 0.28), (0.26, -0.02), (0.4, -0.24), (0.42, -0.32), (0.0, -0.3)], (0, 0, 0), [YEL, YEL, YEL, YEL, GOLD_D, GOLD_D], sides=16)
    p.ball(0.1, (0, 0, -0.38), ORG, subdiv=2)
    ring(p, 0.07, 0.03, 0, 0.47, YEL, seg=10, tseg=5)
    for sx in (-1, 1):
        for rr in (0.5, 0.62):
            a0 = 0 if sx > 0 else 180
            sweep(p, arc(0, 0.02, rr, a0 - 24, a0 + 24, 5), 0.04, "FF5A4A", sides=6, ref=(0, 1, 0))
    gleam(p, -0.12, 0.1, -0.22, 0.08, 0.03, a=-70, color=YEL_L)


def pause(p):
    for sx in (-1, 1):
        p.box((0.3, 0.24, 0.9), (sx * 0.23, 0, 0), WHITE, bevel=0.09, segs=3)


def play(p):
    prism(p, [(-0.34, 0.46), (0.46, 0), (-0.34, -0.46)], 0.26, (0, 0, 0), WHITE, bevel=0.08, segs=3)


def motor(p):
    p.box((0.74, 0.5, 0.4), (0, 0, -0.14), GREY, bevel=0.05)
    p.box((0.56, 0.42, 0.1), (0, 0, -0.38), DARK, bevel=0.03, segs=1)
    p.box((0.64, 0.42, 0.17), (0, 0, 0.13), RED, bevel=0.06)
    for x in (-0.2, 0.0, 0.2):
        p.cyl(0.075, 0.1, (x, 0, 0.24), YEL, sides=10, bevel=0.02, segs=1)
    Y(p, 0.17, -0.25, -0.32, -0.2, DARK, sides=14, x=-0.15, bevel=0.02, segs=1)
    Y(p, 0.07, -0.3, -0.35, -0.2, GREY_L, sides=10, x=-0.15)
    Y(p, 0.1, -0.25, -0.32, 0.02, DARK, sides=12, x=0.2)
    Y(p, 0.045, -0.3, -0.35, 0.02, GREY_L, sides=8, x=0.2)
    for y in (-0.12, 0.12):
        sweep(p, [(0.3, y, -0.08), (0.48, y, -0.08), (0.54, y, 0.0), (0.54, y, 0.22)], 0.055, ORG, sides=6, ref=(0, 1, 0))
    p.box((0.76, 0.2, 0.05), (0, -0.16, -0.02), GREY_L, bevel=0.015, segs=1)


def body(p):
    p.box((0.56, 1.04, 0.28), (0, 0, -0.12), BLUE, bevel=0.11, segs=3)
    p.box((0.5, 0.52, 0.26), (0, 0.1, 0.13), BLUE, bevel=0.1, segs=3)
    p.box((0.4, 0.04, 0.15), (0, -0.155, 0.14), CYAN, r=rot(-18, 0, 0), bevel=0.015, segs=1)
    for sx in (-1, 1):
        p.box((0.04, 0.34, 0.13), (sx * 0.245, 0.1, 0.15), CYAN, bevel=0.015, segs=1)
        p.box((0.14, 0.05, 0.08), (sx * 0.17, -0.515, -0.08), YEL_L, bevel=0.02, segs=1)
        for y in (-0.3, 0.32):
            X(p, 0.15, sx * 0.2, sx * 0.29, y, -0.24, HOLE, sides=12)
    p.box((0.5, 0.06, 0.07), (0, -0.52, -0.2), GREY_L, bevel=0.02, segs=1)
    p.box((0.2, 0.3, 0.02), (0, -0.3, 0.025), BLUE_L, bevel=0.005, segs=1)


def bed(p):
    c = ORG
    p.box((0.66, 0.9, 0.1), (0, 0, -0.2), c, bevel=0.03, segs=1)
    for sx in (-1, 1):
        p.box((0.08, 0.9, 0.34), (sx * 0.31, 0, -0.06), c, bevel=0.03, segs=1)
        X(p, 0.19, sx * 0.25, sx * 0.4, 0.12, -0.3, DARK, sides=14, bevel=0.04)
        X(p, 0.09, sx * 0.3, sx * 0.42, 0.12, -0.3, GREY_L, sides=10)
    p.box((0.66, 0.08, 0.4), (0, -0.42, -0.03), "E8641A", bevel=0.03, segs=1)
    p.box((0.66, 0.08, 0.3), (0, 0.42, -0.08), c, bevel=0.03, segs=1)
    p.box((0.4, 0.03, 0.08), (0, 0.465, -0.06), YEL, bevel=0.01, segs=1)
    p.box((0.3, 0.3, 0.3), (-0.1, -0.18, 0.02), TAN, bevel=0.02, segs=1)                  # Ladung
    p.box((0.32, 0.06, 0.06), (-0.1, -0.18, 0.18), WOOD)
    p.box((0.06, 0.32, 0.06), (-0.1, -0.18, 0.18), WOOD)
    X(p, 0.11, -0.2, 0.22, 0.2, -0.04, GRN, sides=10, bevel=0.02)


ALL = dict(heart=(heart, FLAT), shield=(shield, FLAT), star=(ustar, FLAT), clock=(clock, FLAT), lock=(lock, FLAT), skull=(skull, (-20, 8)),
           pack=(pack, (-30, 16)), drone=(drone, (-24, 38)), badge=(badge, FLAT), bolt=(bolt, FLAT), up=(up, FLAT), speed=(speed, FLAT),
           crate=(crate, SOLID), water=(water, FLAT), hammer=(hammer, FLAT), wrench=(wrench, FLAT), sword=(sword, FLAT), helmet=(helmet, (-30, 14)),
           vest=(vest, (-24, 12)), clover=(uclover, FLAT), grid=(grid, FLAT), recycle=(recycle, (-10, 6)), merge=(merge_icon, (-12, 8)),
           info=(info, FLAT), check=(check, FLAT), close=(close, FLAT), gear=(gear, FLAT), flag=(flag, FLAT), map=(umap, (-22, 16)),
           trophy=(trophy, (-18, 14)), mail=(mail, (-20, 14)), friends=(friends, (-16, 10)), clan=(clan, FLAT), quest=(quest, FLAT),
           chest=(chest, SOLID), fuel=(fuel, (-26, 12)), target=(target, FLAT), boot=(boot, FLAT), fire=(fire, FLAT), snow=(snow, (-12, 8)),
           walk=(walk, (-12, 6)), garage=(garage, (-32, 20)), build=(build, (-24, 16)), expedition=(expedition, FLAT), flood=(flood, FLAT),
           alarm=(alarm, (-12, 8)), pause=(pause, FLAT), play=(play, FLAT), motor=(motor, SOLID), body=(body, (-40, 24)), bed=(bed, (-140, 34)))


def make(name):
    fn, (yaw, pitch) = ALL[name]
    p = Part()
    fn(p)
    scale_all(p, 0.5)
    zmin = min(v.co.z for v in p.bm.verts)
    for v in p.bm.verts:
        v.co.z -= zmin
    toon(p, 0.82, 1.1)
    n = tris(p)
    reset()
    root = empty("ui_" + name)
    p.build("body", root)
    save("ui_" + name)
    icon("ui_" + name, 128, yaw=yaw, pitch=pitch, margin=1.08)
    return n


if __name__ == "__main__":
    want = [n[3:] if n.startswith("ui_") else n for n in args()] or list(ALL)
    for n in want:
        print("ok ui_%s  %d Dreiecke" % (n, make(n)))
