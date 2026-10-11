"""Fallen und Schmuck (Paket 6).
  b_stachel (1 × 1) – Stachelfalle mit Federmechanik: Stachelplatte `bob_spikes` federt auf vier Schraubenfedern
  b_kleb    (2 × 2) – Klebefalle: Pfütze mit Blasen `pulse_bubble1..4`, umgekipptes Fass, Warnschild
  b_mine    (1 × 1) – Mine mit Zündhörnern und Blinklicht `lamp_glow` (das Spiel lässt es blinken)
  b_laterne, b_flagge (Tuch `sway_flag` in Flaggenfarbe), b_blumen
  b_statue  (2 × 2) – Sockel mit Leerobjekt `statue_slot` (dorthin stellt das Spiel die Figur des gewählten Helden)
                      und neutraler steinerner Heldenfigur `statue_default`
Aufruf: python3 blender/def_small.py [namen...]"""
import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from def_kit import *


def begin(name):
    reset()
    return empty(name), Part(), rng_for(name)


# ------------------------------------------------------------------ Fallen (flach, begehbar)
def stachel():
    root, B, rng = begin("b_stachel")
    for i in range(4):                                                         # Holzrahmen aus vier Bohlen
        m = rot(0, 0, i * 90)
        B.box((1.72, 0.26, 0.16), (0, 0, 0), jit(WOOD_D, rng, 0.1), r=m @ T(0, -0.73, 0.08))
        B.box((0.3, 0.05, 0.18), (0, 0, 0), HAZ_Y, r=m @ T(-0.3, -0.865, 0.09))
        B.box((0.3, 0.05, 0.18), (0, 0, 0), HAZ_K, r=m @ T(0.0, -0.865, 0.09))
        B.box((0.3, 0.05, 0.18), (0, 0, 0), HAZ_Y, r=m @ T(0.3, -0.865, 0.09))
    B.box((1.3, 1.3, 0.06), (0, 0, 0.03), "23262E")                            # Grube
    for sx in (-1, 1):
        for sy in (-1, 1):                                                     # Schraubenfedern auf Tellern
            x, y = 0.56 * sx, 0.56 * sy
            B.cyl(0.14, 0.05, (x, y, 0.185), DK, sides=6)
            for k in range(4):
                B.cyl(0.1, 0.035, (x + 0.012 * (k % 2), y, 0.23 + k * 0.055), STEEL_L, r=rot(8 if k % 2 else -8, 0, 0), sides=6)
    B.box((0.12, 0.3, 0.1), (0.8, 0.0, 0.21), DK)                              # Auslöser mit rotem Knauf
    tube(B, (0.8, 0.0, 0.24), (0.98, 0.0, 0.5), 0.03, STEEL, sides=5)
    B.ball(0.07, (0.99, 0.0, 0.52), HOT, subdiv=1)
    B.build("body", root)
    sp = Part()                                                                # federnde Stachelplatte
    z = 0.0
    sp.cyl(0.6, 0.07, (0, 0, z), "566078", r=rot(0, 0, 22.5), sides=8)
    sp.cyl(0.48, 0.03, (0, 0, z + 0.045), STEEL, r=rot(0, 0, 22.5), sides=8)
    for a in (45, 135):
        sp.box((1.72, 0.14, 0.05), (0, 0, z - 0.01), STEEL, r=rot(0, 0, a))    # Kreuzarme zu den Federn
    for i in range(9):
        x, y = -0.34 + (i % 3) * 0.34, -0.34 + (i // 3) * 0.34
        sp.cyl(0.13, 0.05, (x, y, z + 0.07), DK, sides=6)
        sp.cyl(0.1, 0.5, (x, y, z + 0.33), "E4E8F0", r2=0.0, sides=6)
    bob = sp.build("bob_spikes", root, (0, 0, 0.5))
    x4 = Part()
    for sx in (-1, 1):
        for sy in (-1, 1):
            x4.box((0.36, 0.36, 0.2), (0.7 * sx, 0.7 * sy, 0.1), STEEL, bevel=0.04, segs=1)
            rivet(x4, T(0.7 * sx, 0.7 * sy, 0.2), 0.08, STEEL_L)
    x4.build("lv4_corners", root)
    x7 = Part()
    for i in range(9):
        x, y = -0.34 + (i % 3) * 0.34, -0.34 + (i // 3) * 0.34
        x7.cyl(0.055, 0.24, (x, y, 0.48), GOLD, r2=0.0, sides=6)
    x7.build("lv7_tips", bob)
    finish("b_stachel", limit=2500, pitch=34)


def kleb():
    root, B, rng = begin("b_kleb")
    A, Lc, D_ = "B4D62E", "DDF06A", "86A81E"
    for (x, y, r) in ((0, 0, 1.3), (0.75, 0.6, 0.85), (-0.8, 0.55, 0.8), (-0.6, -0.8, 0.9), (0.85, -0.7, 0.75), (0.1, 1.05, 0.6), (1.18, 0.0, 0.5), (-1.18, -0.1, 0.5)):
        B.ball(r + 0.1, (x, y, 0.0), D_, subdiv=1 if r < 1.0 else 2, scale=(1, 1, 0.07 / (r + 0.1) * 1.2))
        B.ball(r, (x, y, 0.02), A, subdiv=2, scale=(1, 1, 0.14 / r))
    for (x, y, r) in ((-0.3, 0.3, 0.42), (0.6, -0.25, 0.3), (-0.55, -0.7, 0.26), (0.5, 0.75, 0.22)):
        B.ball(r, (x, y, 0.12), Lc, subdiv=2, scale=(1, 0.8, 0.16))                    # Glanzflecken
    m = T(-1.1, 1.1, 0.3) @ rot(0, 78, 40)                                             # umgekipptes Fass, aus dem der Kleber läuft
    B.cyl(0.32, 0.8, (0, 0, 0), "F2B21E", r=m, sides=10, bevel=0.05, segs=1)
    for k in (-0.22, 0.22):
        B.cyl(0.335, 0.07, (0, 0, 0), DK, r=m @ T(0, 0, k), sides=10)
    B.cyl(0.26, 0.03, (0, 0, 0), A, r=m @ T(0, 0, 0.41), sides=10)
    B.ball(0.3, (-0.78, 0.82, 0.06), A, subdiv=2, scale=(1.3, 1, 0.3))
    B.cyl(0.04, 1.1, (1.25, 1.2, 0.55), WOOD_D, sides=5)                               # Warnschild
    B.box((0.5, 0.05, 0.5), (1.25, 1.17, 1.05), HAZ_Y, r=rot(0, 45, 0))
    B.box((0.07, 0.06, 0.24), (1.25, 1.15, 1.1), HAZ_K)
    B.box((0.07, 0.06, 0.07), (1.25, 1.15, 0.9), HAZ_K)
    for (x, y, s) in ((-1.3, -1.2, 0.16), (0.3, -1.4, 0.12), (1.45, -0.6, 0.1)):        # festgeklebte Steinchen/Stiefel
        B.box((s * 1.6, s, s), (x, y, s * 0.4), jit(ST_D, rng), r=rot(0, 0, rng.uniform(0, 90)))
    B.build("body", root)
    for i, (x, y, r) in enumerate(((0.2, -0.75, 0.2), (-0.9, 0.3, 0.16), (0.95, 0.4, 0.17), (0.25, 0.2, 0.24))):   # Blasen
        p = Part()
        p.ball(r, (0, 0, 0), Lc, subdiv=2)
        p.ball(r * 0.3, (-r * 0.4, -r * 0.5, r * 0.6), "FFFFFF", subdiv=1)
        p.build("pulse_bubble%d" % (i + 1), root, (x, y, 0.14))
    x4 = Part()
    for (x, y, r) in ((1.3, -1.2, 0.36), (-1.4, -0.9, 0.3), (0.7, 1.3, 0.3)):
        x4.ball(r, (x, y, 0.02), A, subdiv=2, scale=(1, 1, 0.3))
    x4.build("lv4_blobs", root)
    x7 = Part()
    for (x, y, r) in ((0.0, -0.2, 0.12), (-0.7, 0.75, 0.1), (0.9, -0.85, 0.1), (0.7, 0.2, 0.09)):
        x7.ball(r, (x, y, 0.2), GOLD, subdiv=1)
    x7.build("lv7_sparkle", root)
    finish("b_kleb", limit=2500, pitch=34)


def mine():
    root, B, rng = begin("b_mine")
    B.cyl(0.86, 0.06, (0, 0, 0.03), "7A5A3A", sides=10)                                # aufgeworfene Erde
    for i in range(7):
        x, y = ring_xy(0.8, i * 51 + 10)
        B.ball(0.16, (x, y, 0.04), jit("8A6A44", rng, 0.1), subdiv=1, scale=(1.2, 1, 0.5))
    B.cyl(0.7, 0.14, (0, 0, 0.11), "23262E", sides=14, bevel=0.04, segs=1)
    B.cyl(0.62, 0.26, (0, 0, 0.27), "4B5670", sides=14, r2=0.46, bevel=0.05, segs=1)
    B.cyl(0.3, 0.1, (0, 0, 0.42), RED_D, sides=10)
    B.cyl(0.2, 0.08, (0, 0, 0.48), DK, sides=8)
    for i in range(6):                                                                 # Zündhörner, Warnmarken
        m = ring_m(0.54, i * 60, 0.3)
        B.cyl(0.07, 0.2, (0, 0, 0), STEEL_L, r=m @ rot(35, 0, 0), sides=6)
        B.ball(0.08, (0, 0, 0), RED, r=m @ rot(35, 0, 0) @ T(0, 0, 0.13), subdiv=1)
        B.box((0.2, 0.06, 0.03), (0, 0, 0), HAZ_Y, r=ring_m(0.4, i * 60 + 30, 0.385) @ rot(-22, 0, 0))
    tube(B, (0.5, 0.5, 0.1), (1.0, 0.75, 0.03), 0.025, DK, sides=4)                    # Zündkabel
    B.box((0.2, 0.14, 0.1), (1.05, 0.78, 0.05), DK)
    B.build("body", root)
    lp = Part()
    lp.ball(0.13, (0, 0, 0), HOT, subdiv=2)
    lp.build("lamp_glow", root, (0, 0, 0.56))
    x4 = Part()
    x4.torus(0.7, 0.05, (0, 0, 0.18), HAZ_Y, seg=14, tseg=4)
    x4.build("lv4_ring", root)
    x7 = Part()
    x7.torus(0.31, 0.04, (0, 0, 0.47), GOLD, seg=10, tseg=4)
    x7.build("lv7_ring", root)
    finish("b_mine", limit=2500, pitch=34)


# ------------------------------------------------------------------ Schmuck
def laterne():
    root, B, rng = begin("b_laterne")
    B.cyl(0.42, 0.16, (0, 0, 0.08), ST_D, r=rot(0, 0, 22.5), sides=8)
    B.cyl(0.32, 0.2, (0, 0, 0.26), ST, r=rot(0, 0, 22.5), sides=8, bevel=0.04, segs=1)
    B.cyl(0.2, 0.2, (0, 0, 0.44), ST_L, sides=8)
    B.box((0.2, 0.05, 0.1), (0.2, -0.33, 0.1), "6E9A38")                               # Moos
    B.cyl(0.08, 2.5, (0, 0, 1.75), DK, sides=8)                                        # Mast mit Ringen
    for z in (0.62, 1.5, 2.7):
        B.cyl(0.12, 0.08, (0, 0, z), "4A5263", sides=8)
    tube(B, (0, 0, 2.95), (0.45, 0, 3.25), 0.045, DK, sides=5)                         # geschwungener Arm
    tube(B, (0.45, 0, 3.25), (0.75, 0, 3.15), 0.045, DK, sides=5)
    tube(B, (0, 0, 2.5), (0.38, 0, 3.12), 0.03, DK, sides=4)
    B.cyl(0.02, 0.2, (0.75, 0, 3.05), DK, sides=4)                                     # Kette
    B.cyl(0.36, 0.26, (0.75, 0, 2.86), DK, r=rot(0, 0, 45), r2=0.08, sides=4)          # Laternendach
    B.ball(0.06, (0.75, 0, 3.0), GOLD, subdiv=1)
    B.box((0.44, 0.44, 0.06), (0.75, 0, 2.28), DK)
    for sx in (-1, 1):
        for sy in (-1, 1):
            B.box((0.05, 0.05, 0.46), (0.75 + 0.19 * sx, 0.19 * sy, 2.52), DK)
    B.box((0.5, 0.06, 0.3), (-0.02, -0.1, 1.9), WOOD_L, r=rot(0, -5, 0))               # kleines Holzschild
    star(B, (-0.02, -0.14, 1.9), 0.1, BLUE, 0.02, r=STAR_FRONT)
    B.cyl(0.14, 0.2, (-0.34, 0.2, 0.1), "C2613F", r2=0.17, sides=6)                    # Blumentopf am Fuß
    for k in range(3):
        B.ball(0.08, (-0.34 + (k - 1) * 0.08, 0.2, 0.28 + (k % 2) * 0.05), ("F07AB4", "FFD23E", "F4F6FA")[k], subdiv=1)
    B.build("body", root)
    g = Part()
    g.box((0.34, 0.34, 0.44), (0.75, 0, 2.52), GLOW, bevel=0.06, segs=1)
    g.build("lamp_glow", root)
    finish("b_laterne", limit=2500)


def flagge():
    root, B, rng = begin("b_flagge")
    px = -0.4                                                                          # Mast links, damit das Tuch im Feld bleibt
    B.cyl(0.5, 0.18, (px, 0, 0.09), ST_D, r=rot(0, 0, 22.5), sides=8)
    B.cyl(0.38, 0.2, (px, 0, 0.28), ST, r=rot(0, 0, 22.5), sides=8, bevel=0.04, segs=1)
    B.cyl(0.26, 0.2, (px, 0, 0.46), ST_L, sides=8)
    B.cyl(0.13, 0.3, (px, 0, 0.7), GOLD, sides=8)
    B.cyl(0.065, 3.6, (px, 0, 2.3), "E4E8F0", sides=8)
    B.cyl(0.1, 0.06, (px, 0, 4.1), GOLD_D, sides=8)
    B.ball(0.13, (px, 0, 4.22), GOLD, subdiv=2)
    tube(B, (px - 0.08, 0, 1.2), (px - 0.08, 0, 4.0), 0.012, ROPE, sides=3)            # Flaggenleine mit Klampe
    B.box((0.16, 0.05, 0.05), (px - 0.07, 0, 1.2), DK)
    B.box((0.3, 0.05, 0.12), (px + 0.3, -0.4, 0.06), "6E9A38")
    for (x, y, c) in ((px + 0.55, 0.3, "F07AB4"), (px - 0.3, -0.45, "FFD23E"), (px + 0.4, -0.5, "F4F6FA")):   # Blümchen am Fuß
        B.cyl(0.02, 0.2, (x, y, 0.1), "4F7A2A", sides=4)
        B.ball(0.08, (x, y, 0.22), c, subdiv=1)
    c = Part()
    w, hh = 1.3, 0.86
    c.box((w * 0.5, 0.05, hh), (w * 0.25, 0, 0), "flag")
    c.box((w * 0.52, 0.05, hh * 0.94), (w * 0.74, -0.06, -0.03), shade("flag", 0.9), r=rot(0, 0, -9))
    for sy in (-1, 1):
        star(c, (w * 0.4, sy * 0.035, 0), hh * 0.3, "white", 0.03, r=rot(90 * sy, 0, 0))
    c.build("sway_flag", root, (px + 0.065, 0, 3.6))
    B.build("body", root)
    finish("b_flagge", limit=2500)


def blumen():
    root, B, rng = begin("b_blumen")
    for i in range(4):                                                                 # Hochbeet aus Brettern, Eckpfosten
        m = rot(0, 0, i * 90)
        for k in range(3):
            B.box((0.54, 0.09, 0.34 + rng.uniform(-0.03, 0.03)), (0, 0, 0), jit(WOOD, rng, 0.1), r=m @ T(-0.55 + k * 0.55, -0.78, 0.17))
        B.box((0.14, 0.14, 0.44), (0, 0, 0), WOOD_D, r=m @ T(-0.8, -0.8, 0.22))
    B.box((1.5, 1.5, 0.24), (0, 0, 0.16), "6B4A2A")
    B.ball(0.7, (0, 0, 0.24), "7A5632", subdiv=2, scale=(1, 1, 0.14))
    cols = ["F4F6FA", "FFD23E", "F07AB4", "FF7043", "9A7CF0"]
    for i in range(9):
        jx, jy = (hash3(i, 1, 2) - 0.5) * 0.16, (hash3(i, 5, 3) - 0.5) * 0.16
        x, y = -0.42 + (i % 3) * 0.42 + jx, -0.42 + (i // 3) * 0.42 + jy
        h = 0.34 + hash3(i, 7, 9) * 0.34
        c = cols[(i * 2) % 5]
        B.cyl(0.03, h, (x, y, 0.3 + h * 0.5), "4F7A2A", sides=4)
        B.ball(0.13, (x - 0.09, y, 0.4), "8FB02A", subdiv=1, scale=(1, 0.5, 0.35))
        if i % 3 == 1:                                                                 # Tulpe
            B.cyl(0.09, 0.18, (x, y, 0.36 + h), c, r2=0.11, sides=6)
        else:                                                                          # Blüte mit fünf Blättern
            for k in range(5):
                a = math.radians(k * 72 + i * 20)
                B.ball(0.1, (x + math.cos(a) * 0.11, y + math.sin(a) * 0.11, 0.32 + h), c, subdiv=1, scale=(1, 1, 0.5))
            B.ball(0.075, (x, y, 0.35 + h), "FFD23E" if c != "FFD23E" else "FF7043", subdiv=1)
    m = T(0.62, -0.95, 0.0) @ rot(0, 0, 30)                                            # Gießkanne
    B.cyl(0.13, 0.26, (0, 0, 0), "5B93EE", r=m @ T(0, 0, 0.13), sides=8)
    tube(B, m @ Vector((0.1, 0, 0.1)), m @ Vector((0.34, 0, 0.3)), 0.03, "5B93EE", sides=5)
    B.torus(0.09, 0.02, (0, 0, 0), "5B93EE", r=m @ T(-0.14, 0, 0.16) @ rot(90, 0, 0), seg=6, tseg=3)
    tube(B, (-0.9, -0.6, 0.02), (-0.86, -0.92, 0.5), 0.02, WOOD_L, sides=4)            # Schäufelchen
    B.box((0.12, 0.03, 0.18), (-0.9, -0.58, 0.06), STEEL, r=rot(-10, 0, 0))
    B.build("body", root)
    f = Part()                                                                         # Schmetterling (schwebt)
    for s in (-1, 1):
        f.box((0.14, 0.02, 0.16), (s * 0.07, 0, 0.02), "FF9A3A", r=rot(0, s * 28, 0))
    f.box((0.03, 0.03, 0.14), (0, 0, 0), DK)
    f.build("bob_butterfly", root, (0.3, 0.2, 1.15))
    finish("b_blumen", limit=2500, pitch=30)


def stone_hero(p, m, k=1.5, c1="B9BFD2", c2="A2A9C0", c3="CDD2E2"):
    """Neutrale Heldenfigur aus Stein im kantigen Voxel-Stil: großer Kopf mit Helm und Brille, rechte Hand erhoben."""
    def bx(size, loc, c, r=None):
        mm = m @ S(k) @ T(*loc)
        p.box(size, (0, 0, 0), c, r=mm if r is None else mm @ r)
    for s in (-1, 1):
        bx((0.2, 0.26, 0.5), (s * 0.13, 0, 0.25), c2)
        bx((0.22, 0.32, 0.14), (s * 0.13, -0.02, 0.07), c1)
    bx((0.5, 0.3, 0.46), (0, 0, 0.73), c1)
    bx((0.52, 0.32, 0.08), (0, 0, 0.52), c2)
    bx((0.3, 0.05, 0.22), (0, -0.165, 0.78), c3)
    bx((0.6, 0.54, 0.52), (0, -0.02, 1.24), c3)                                        # Kopf
    bx((0.66, 0.6, 0.24), (0, -0.01, 1.44), c1)                                        # Helm
    bx((0.7, 0.64, 0.06), (0, -0.01, 1.33), c2)
    bx((0.44, 0.05, 0.13), (0, -0.31, 1.29), c2)                                       # Brille
    bx((0.16, 0.16, 0.46), (-0.34, 0.0, 0.72), c1, r=rot(0, -8, 0))                    # linker Arm unten
    bx((0.18, 0.18, 0.14), (-0.38, 0.0, 0.46), c2)
    bx((0.16, 0.16, 0.46), (0.36, -0.04, 1.08), c1, r=rot(0, 16, 0))                   # rechter Arm erhoben
    bx((0.18, 0.18, 0.16), (0.43, -0.04, 1.36), c2)
    bx((0.05, 0.05, 1.3), (0.44, -0.04, 1.2), c2)                                      # Fahnenstange
    bx((0.44, 0.04, 0.28), (0.68, -0.04, 1.7), c3)


def statue():
    root, B, rng = begin("b_statue")
    B.box((3.3, 3.3, 0.22), (0, 0, 0.11), ST_D, bevel=0.06, segs=1)                    # Stufen
    for i in range(4):
        for j in range(4):
            if 0 < i < 3 and 0 < j < 3:
                continue
            B.box((0.76, 0.76, 0.06), (-1.2 + i * 0.8, -1.2 + j * 0.8, 0.245), jit((ST, ST_L)[(i + j) % 2], rng))
    B.box((2.4, 2.4, 0.3), (0, 0, 0.37), ST, bevel=0.07, segs=1)
    B.box((1.7, 1.7, 0.9), (0, 0, 0.95), ST_L, bevel=0.1, segs=1)                      # Sockel
    B.box((1.9, 1.9, 0.16), (0, 0, 0.56), ST_D, bevel=0.04, segs=1)
    B.box((1.92, 1.92, 0.2), (0, 0, 1.44), ST, bevel=0.06, segs=1)
    B.box((1.6, 1.6, 0.08), (0, 0, 1.56), ST_D)
    B.box((1.1, 0.07, 0.5), (0, -0.86, 0.98), "026AED", bevel=0.03, segs=1)            # Tafel mit Stern und Schriftzeilen
    star(B, (-0.32, -0.9, 0.98), 0.17, GOLD, 0.03, r=STAR_FRONT)
    for k in range(3):
        B.box((0.5 - k * 0.1, 0.03, 0.05), (0.2 - k * 0.05, -0.9, 1.1 - k * 0.12), GOLD)
    B.torus(0.26, 0.05, (0, 0.87, 1.0), "6E9A38", r=AX_Y, seg=10, tseg=4)              # Kranz hinten
    for sx in (-1, 1):
        for sy in (-1, 1):                                                             # Eckpoller mit Ketten
            B.cyl(0.13, 0.6, (1.42 * sx, 1.42 * sy, 0.52), ST_D, sides=6)
            B.ball(0.16, (1.42 * sx, 1.42 * sy, 0.86), GOLD, subdiv=1)
    for i in range(4):
        m = rot(0, 0, i * 90)
        if i == 0:
            continue                                                                   # vorn offen
        pts = [m @ Vector((-1.42, -1.42, 0.74)), m @ Vector((-0.5, -1.42, 0.52)), m @ Vector((0.5, -1.42, 0.52)), m @ Vector((1.42, -1.42, 0.74))]
        for k in range(3):
            tube(B, pts[k], pts[k + 1], 0.03, DK, sides=4)
    for sx in (-1, 1):                                                                 # Blumenschalen vorn
        B.cyl(0.24, 0.2, (sx * 0.9, -1.38, 0.32), "C2613F", r2=0.3, sides=8)
        for k in range(4):
            B.ball(0.1, (sx * 0.9 + (k % 2 - 0.5) * 0.2, -1.38 + (k // 2 - 0.5) * 0.2, 0.48), ("F07AB4", "FFD23E", "F4F6FA", "FF7043")[k], subdiv=1)
    B.box((0.5, 0.05, 0.14), (-0.9, -1.22, 0.3), "6E9A38")                             # Moos
    B.box((0.05, 0.4, 0.12), (1.22, 0.6, 0.3), "6E9A38")
    B.build("body", root)
    empty("statue_slot", root, (0, 0, 1.6))
    d = Part()
    stone_hero(d, T(0, 0, 1.6))
    d.build("statue_default", root)
    finish("b_statue", limit=2500)


TABLE = {"b_stachel": stachel, "b_kleb": kleb, "b_mine": mine, "b_laterne": laterne, "b_flagge": flagge, "b_blumen": blumen, "b_statue": statue}

if __name__ == "__main__":
    run(TABLE, sys.argv)
