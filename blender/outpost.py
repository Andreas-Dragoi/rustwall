"""Rustwall V3 – Modelle für die Expedition und die Außenbasen (Pakete 3 und 4).
  o_*  Gebäude und Zubehör der Außenbasis (Zentrale, Depot, Feuer, Parkplatz, Spezialbauten mit fünf Stufen, Bauplatz,
       Lieferwagen, Händler)                                              -> diese Datei und exp_special.py
  x_barrier_*  Sperren der Durchgänge                                     -> exp_barriers.py
  n_*  Rohstoffquellen zum Abbauen                                        -> exp_nodes.py
  area_*  Schaubilder der sieben Gebiete (nur Symbol für die Weltkarte)   -> exp_areas.py
Aufruf: python3 blender/outpost.py [namen...]   (ohne Namen: alles bauen; "list" zeigt die Namen)"""
import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from exp_common import *
from vehicles import lights


# ------------------------------------------------------------------ Zentrale
@model("o_zentrale")
def zentrale(name):
    root, B, G = start(name)
    L = Part()
    base(B, 5.5, 5.5, "CDBB93", 0.2)
    B.box((4.5, 3.7, 0.12), (0, 0.6, 0.24), ST_D, bevel=0.04, segs=1)
    # Hauptblock: Front bei y = -0.9
    B.box((3.9, 3.0, 2.3), (0, 0.6, 1.4), ST, bevel=0.22)
    B.box((4.0, 3.1, 0.5), (0, 0.6, 0.52), ST_D, bevel=0.1, segs=1)
    for (x, z, w) in ((-1.5, 1.25, 0.6), (1.45, 2.0, 0.5), (-0.95, 2.2, 0.4), (1.6, 1.1, 0.4)):      # helle Steine
        B.box((w, 0.08, 0.26), (x, -0.9, z), ST_L, bevel=0.03, segs=1)
    B.box((4.4, 3.5, 0.42), (0, 0.6, 2.72), BLUE, bevel=0.16)                                       # Dachkante
    B.box((3.6, 2.7, 0.2), (0, 0.6, 2.98), BLUE_L, bevel=0.07, segs=1)
    for sx in (-1, 1):
        for sy in (-1, 1):
            B.box((0.36, 0.36, 0.5), (2.06 * sx, 0.6 + 1.61 * sy, 2.76), GOLD, bevel=0.08, segs=1)
    # Tür mit Vordach
    B.box((1.5, 0.3, 2.1), (0, -0.92, 1.3), ST_D, bevel=0.1, segs=1)
    door(B, (0, -1.06, 0.3), 0.95, 1.75, WOOD, DK)
    B.box((1.8, 0.7, 0.14), (0, -1.3, 2.36), BLUE, r=rot(-14, 0, 0), bevel=0.05, segs=1)
    B.box((1.7, 0.9, 0.12), (0, -1.5, 0.26), ST_L, bevel=0.04, segs=1)
    star(B, (0, -1.16, 2.74), 0.24, GOLD, 0.08)
    L.box((0.3, 0.14, 0.2), (0, -1.1, 2.14), GLOW, bevel=0.05, segs=1)
    for sx in (-1, 1):
        window(G, B, (1.35 * sx, -0.92, 1.6), 0.6, 0.7)
    window(G, B, (-1.97, 0.6, 1.6), 0.9, 0.7, "l")
    window(G, B, (1.97, 0.6, 1.6), 0.9, 0.7, "r")
    # Ausguck auf dem Dach
    B.box((1.8, 1.8, 1.3), (-0.85, 0.9, 3.65), ST, bevel=0.18)
    B.box((2.1, 2.1, 0.26), (-0.85, 0.9, 4.32), BLUE_D, bevel=0.08, segs=1)
    pyr(B, (-0.85, 0.9, 4.42), 2.0, 2.0, 0.95, BLUE)
    window(G, B, (-0.85, -0.02, 3.7), 0.9, 0.55)
    window(G, B, (-1.77, 0.9, 3.7), 0.8, 0.55, "l", bars=False)
    flag(root, B, (-0.85, 0.9, 5.25), 1.7, size=(1.0, 0.68))
    # Funkmast mit drehender Schüssel
    ax, ay, az = 1.2, 1.3, 3.05
    B.box((0.8, 0.8, 0.14), (ax, ay, az + 0.05), DK, bevel=0.04, segs=1)
    for sx in (-1, 1):
        for sy in (-1, 1):
            beam(B, (ax + 0.3 * sx, ay + 0.3 * sy, az), (ax + 0.07 * sx, ay + 0.07 * sy, az + 2.1), 0.07, STEEL)
    for k in range(3):
        s = 0.56 - k * 0.14
        B.box((s, s, 0.06), (ax, ay, az + 0.5 + k * 0.6), RED if k % 2 == 0 else "F4F6FA")
    B.cyl(0.1, 0.2, (ax, ay, az + 2.15), DK, sides=8)
    d = Part()
    d.cyl(0.05, 0.3, (0, 0, 0.15), STEEL, sides=6)
    m = T(0, -0.1, 0.5) @ rot(58, 0, 0)
    d.cyl(0.16, 0.34, (0, 0, 0), "F4F6FA", r=m, r2=0.72, sides=14)
    d.cyl(0.6, 0.03, (0, 0, 0), "DCE4F0", r=m @ T(0, 0, 0.13), sides=14)
    d.cyl(0.025, 0.5, (0, 0, 0), STEEL, r=m @ T(0, 0, 0.3), sides=5)
    d.ball(0.08, (0, 0, 0), RED, r=m @ T(0, 0, 0.56), subdiv=2)
    d.build("spin_dish", root, (ax, ay, az + 2.25))
    # Sandsäcke, Kisten, Funkkiste
    sandbags(B, (-2.5, -2.45, 0.2), 1, 0, 3)
    sandbags(B, (1.25, -2.45, 0.2), 1, 0, 3)
    sandbags(B, (-2.5, -2.0, 0.2), 0, 1, 2, 1)
    sandbags(B, (2.5, -2.0, 0.2), 0, 1, 2, 1)
    crate(B, (2.35, -0.6, 0.2), 0.75, WOOD, 10)
    crate(B, (2.4, 0.2, 0.2), 0.55, OLIVE, -8)
    barrel(B, (-2.4, -0.4, 0.2), BLUE_L, 0.3, 0.8)
    B.box((0.7, 0.5, 0.5), (-2.35, 0.5, 0.45), OLIVE, bevel=0.06, segs=1)                           # Funkgerät
    B.cyl(0.02, 0.9, (-2.6, 0.6, 1.1), DK, sides=4)
    L.box((0.12, 0.06, 0.12), (-2.2, 0.24, 0.5), "6FE86A")
    B.build("body", root)
    G.build("win_glow", root)
    L.build("lamp_glow", root)
    empty("door", root, (0, -1.9, 0))
    empty("bubble", root, (0, 0, 6.0))
    fin(name)


# ------------------------------------------------------------------ Depot
@model("o_depot")
def depot(name):
    root, B, G = start(name)
    base(B, 3.0, 3.4, WOOD_L, 0.16)
    for i in range(1, 6):                                                                           # Dielenfugen
        B.box((0.03, 3.3, 0.02), (-1.5 + i * 3.0 / 6, 0, 0.165), shade(WOOD_L, 0.72))
    for sx in (-1, 1):
        B.box((0.2, 0.2, 2.75), (1.36 * sx, -1.5, 1.5), WOOD_D, bevel=0.04, segs=1)
        B.box((0.2, 0.2, 2.25), (1.36 * sx, 1.5, 1.25), WOOD_D, bevel=0.04, segs=1)
        B.box((0.1, 2.9, 0.14), (1.36 * sx, 0, 1.25), WOOD)                                         # Seitenriegel
        beam(B, (1.36 * sx, -1.45, 2.2), (1.36 * sx, -0.9, 2.76), 0.1, WOOD_D)
    B.box((2.7, 0.12, 1.7), (0, 1.5, 1.0), WOOD, bevel=0.03, segs=1)                               # Rückwand
    for i in range(1, 5):
        B.box((0.03, 0.14, 1.66), (-1.35 + i * 0.54, 1.5, 1.0), shade(WOOD, 0.7))
    B.box((2.9, 0.16, 0.2), (0, -1.5, 2.7), WOOD_D, bevel=0.04, segs=1)
    mono(B, (0, 0, 2.72), 3.1, 3.42, 0.55, RED, 0.16, rim=shade(RED, 0.75))
    for i in range(3):
        mono(B, (-1.0 + i * 1.0, 0, 2.735), 0.3, 3.42, 0.55, "F06A60", 0.16)
    # Schild: Kiste mit Pfeil nach unten
    B.box((0.9, 0.08, 0.6), (0, -1.6, 2.3), CREAM, bevel=0.04, segs=1)
    B.box((0.16, 0.06, 0.26), (0, -1.65, 2.4), BLUE)
    B.cyl(0.19, 0.06, (0, -1.65, 2.2), BLUE, r=rot(90, 0, 0) @ rot(0, 0, 180), sides=3)
    # Ladung
    crate(B, (-0.9, 1.0, 0.16), 0.8, WOOD, 4)
    crate(B, (-0.86, 0.98, 0.96), 0.66, "C98A48", -10)
    crate(B, (-0.05, 1.05, 0.16), 0.7, OLIVE, 0)
    crate(B, (-0.95, 0.2, 0.16), 0.62, "C98A48", 14)
    crate(B, (-0.1, 1.05, 0.86), 0.5, WOOD, 22)
    barrel(B, (0.92, 1.0, 0.16), BLUE_L, 0.33, 0.9)
    barrel(B, (0.98, 0.3, 0.16), RED, 0.33, 0.9)
    barrel(B, (0.4, 0.72, 0.16), GOLD, 0.3, 0.8)
    sack(B, (-1.0, -0.55, 0.16), 0.9, yaw=20)
    sack(B, (-0.55, -0.3, 0.16), 0.8, "CDB07A", 70)
    # Sackkarre vorn rechts
    m = T(0.85, -0.95, 0.16) @ rot(0, 0, -25) @ rot(14, 0, 0)
    for sx in (-1, 1):
        B.cyl(0.03, 1.3, (0, 0, 0), RED_D, r=m @ T(0.22 * sx, 0.12, 0.8), sides=5)
        B.cyl(0.17, 0.09, (0, 0, 0), "23262E", r=m @ T(0.3 * sx, 0.14, 0.17) @ rot(0, 90, 0), sides=10, bevel=0.03, segs=1)
    for z in (0.5, 0.95, 1.4):
        B.box((0.47, 0.04, 0.05), (0, 0, 0), RED_D, r=m @ T(0, 0.12, z))
    B.box((0.5, 0.36, 0.04), (0, 0, 0), STEEL, r=m @ T(0, -0.06, 0.12))
    B.box((0.44, 0.34, 0.4), (0, 0, 0), "C98A48", r=m @ T(0, -0.07, 0.34), bevel=0.04, segs=1)
    B.box((0.46, 0.36, 0.06), (0, 0, 0), shade("C98A48", 0.7), r=m @ T(0, -0.07, 0.34))
    G.box((0.2, 0.2, 0.26), (-1.1, -1.4, 2.3), GLOW, bevel=0.05, segs=1)                           # Laterne am Pfosten
    B.box((0.28, 0.28, 0.06), (-1.1, -1.4, 2.46), DK)
    B.box((0.06, 0.3, 0.06), (-1.24, -1.45, 2.5), DK)
    B.build("body", root)
    G.build("lamp_glow", root)
    empty("drop", root, (0, -2.3, 0))
    empty("bubble", root, (0, 0, 3.7))
    fin(name)


# ------------------------------------------------------------------ Lagerfeuer
@model("o_feuer")
def feuer(name):
    root, B, G = start(name)
    rng = random.Random(4)
    B.cyl(1.45, 0.06, (0, 0, 0.03), "B89A68", sides=14)
    B.cyl(0.62, 0.08, (0, 0, 0.05), "3A3238", sides=12)
    for i in range(9):
        a = math.radians(i * 40)
        rockc(B, (0.36, 0.3, 0.26), (math.cos(a) * 0.68, math.sin(a) * 0.68, 0.14), (ROCK, ROCK_L, ROCK_D)[i % 3], rng)
    for i in range(4):
        a = i * 90 + 30
        log_(B, T(math.cos(math.radians(a)) * 0.24, math.sin(math.radians(a)) * 0.24, 0.3) @ rot(0, 0, a) @ rot(0, -52, 0), 0.1, 0.85, 7, "5A3A26")
    # Dreibein mit Kessel
    top = (0, 0, 2.0)
    for a in (90, 210, 330):
        tube(B, (math.cos(math.radians(a)) * 0.95, math.sin(math.radians(a)) * 0.95, 0.05), top, 0.04, WOOD_D, 5)
    B.cyl(0.07, 0.12, (0, 0, 1.98), DK, sides=6)
    B.cyl(0.015, 0.62, (0, 0, 1.66), DK, sides=4)
    B.ball(1.0, (0, 0, 1.18), "3A3E4A", scale=(0.34, 0.34, 0.28), subdiv=3)
    B.cyl(0.3, 0.08, (0, 0, 1.33), "23262E", sides=10)
    B.cyl(0.25, 0.02, (0, 0, 1.375), "E8B04A", sides=10)                                           # Suppe
    B.torus(0.3, 0.018, (0, 0, 1.36), DK, r=rot(90, 0, 0), seg=10, tseg=4)
    # Sitzstämme
    log_(B, T(-0.98, -0.6, 0.24) @ rot(0, 0, -32) @ rot(90, 0, 0), 0.24, 1.05, 9)
    log_(B, T(1.0, -0.5, 0.24) @ rot(0, 0, 28) @ rot(90, 0, 0), 0.24, 1.05, 9)
    B.cyl(0.3, 0.44, (0.1, 1.15, 0.22), BARK, sides=9)
    B.cyl(0.25, 0.02, (0.1, 1.15, 0.45), CUT, sides=9)
    B.cyl(0.12, 0.022, (0.1, 1.15, 0.452), CUT_D, sides=7)
    # Holzvorrat und Becher
    for i, (x, y) in enumerate(((-0.95, 0.85), (-0.75, 1.0), (-0.86, 0.92))):
        log_(B, T(x, y, 0.12 + (0.2 if i == 2 else 0)) @ rot(0, 0, 40) @ rot(90, 0, 0), 0.1, 0.6, 6)
    B.cyl(0.07, 0.12, (0.1, 1.12, 0.52), "E04848", sides=7)
    f = Part()
    f.ball(1.0, (0, 0, 0.42), "FF8A1E", scale=(0.3, 0.3, 0.38), subdiv=2)
    f.cone(0.26, 0.62, (0.02, 0, 0.84), "FF8A1E", sides=8)
    f.cone(0.15, 0.4, (-0.2, 0.08, 0.6), "FF6A1E", r=rot(0, -14, 0), sides=6)
    f.cone(0.15, 0.44, (0.2, -0.08, 0.62), "FF6A1E", r=rot(0, 14, 0), sides=6)
    f.ball(1.0, (0, -0.02, 0.38), "FFE25A", scale=(0.18, 0.18, 0.26), subdiv=2)
    f.cone(0.15, 0.3, (0, -0.02, 0.66), "FFE25A", sides=6)
    B.build("body", root)
    f.build("fire_glow", root)
    empty("fx_smoke", root, (0, 0, 2.2))
    fin(name, pitch=30)


# ------------------------------------------------------------------ Parkplatz
@model("o_parkplatz")
def parkplatz(name):
    root, B, G = start(name)
    B.box((3.2, 3.2, 0.14), (0, 0, 0.07), CONC, bevel=0.05, segs=1)
    B.box((2.9, 2.9, 0.02), (0, 0, 0.145), "A9A59C")
    for i in range(10):                                                                             # gelb-schwarzer Rand vorn/hinten
        for sy in (-1, 1):
            B.box((0.3, 0.14, 0.03), (-1.35 + i * 0.3, 1.5 * sy, 0.15), YEL if i % 2 == 0 else "23262E")
    for sx in (-1, 1):                                                                              # Stellplatzlinien
        B.box((0.1, 2.4, 0.03), (0.95 * sx, -0.05, 0.155), "F4F6FA")
    # Schraubenschlüssel als Bodenzeichen
    m = T(0, -0.1, 0.16) @ rot(0, 0, 40)
    B.box((0.16, 1.1, 0.02), (0, 0, 0), YEL, r=m)
    for s in (-1, 1):
        B.cyl(0.24, 0.02, (0, 0, 0), YEL, r=m @ T(0, 0.62 * s, 0), sides=8)
        B.box((0.16, 0.26, 0.03), (0, 0, 0), "A9A59C", r=m @ T(0, 0.76 * s, 0))
    # Werkzeugkiste
    B.box((0.8, 0.42, 0.42), (-1.1, 1.15, 0.36), RED, bevel=0.06, segs=1)
    B.box((0.84, 0.46, 0.12), (-1.1, 1.15, 0.6), RED_D, bevel=0.04, segs=1)
    B.box((0.3, 0.06, 0.06), (-1.1, 1.15, 0.72), STEEL)
    for sx in (-1, 1):
        B.box((0.05, 0.05, 0.1), (-1.1 + 0.13 * sx, 1.15, 0.68), STEEL)
        B.box((0.1, 0.04, 0.12), (-1.1 + 0.26 * sx, 0.93, 0.5), GOLD)
    B.box((0.5, 0.08, 0.03), (-0.45, 1.2, 0.16), STEEL_L, r=rot(0, 0, 25))                         # Schlüssel am Boden
    # Reifenstapel
    for i in range(3):
        tire(B, T(1.12 + 0.04 * (i % 2), 1.12, 0.28 + i * 0.27) @ rot(0, 0, i * 20), 0.38, 0.26)
    tire(B, T(0.5, 1.32, 0.52) @ rot(72, 0, 0), 0.38, 0.26, "C9CED8")
    # Wagenheber
    B.box((0.5, 0.3, 0.1), (1.2, -1.05, 0.2), BLUE, bevel=0.03, segs=1)
    for s in (-1, 1):
        beam(B, (1.2 - 0.2 * s, -1.05, 0.25), (1.2 + 0.12 * s, -1.05, 0.5), 0.06, BLUE_L)
    B.box((0.3, 0.26, 0.06), (1.2, -1.05, 0.53), STEEL)
    tube(B, (0.98, -1.05, 0.25), (0.6, -1.2, 0.5), 0.025, DK, 5)
    # Ölfass und Kanister
    barrel(B, (-1.25, -1.2, 0.14), "3FA7A0", 0.26, 0.7)
    B.box((0.3, 0.2, 0.4), (-0.85, -1.3, 0.34), RED, bevel=0.05, segs=1)
    B.cyl(0.04, 0.08, (-0.78, -1.3, 0.57), DK, sides=5)
    L = Part()
    lamp_post(B, L, (-1.36, 0.3, 0.14), 2.5)
    B.cyl(0.05, 2.0, (1.25, 0.34, 1.1), DK, sides=6)
    B.box((0.6, 0.06, 0.44), (1.25, 0.33, 1.8), BLUE_D, bevel=0.03, segs=1)
    B.box((0.07, 0.03, 0.24), (1.18, 0.26, 1.8), "F4F6FA")
    B.box((0.15, 0.03, 0.05), (1.27, 0.26, 1.9), "F4F6FA")
    B.box((0.15, 0.03, 0.05), (1.27, 0.26, 1.8), "F4F6FA")
    B.box((0.05, 0.03, 0.14), (1.33, 0.26, 1.85), "F4F6FA")
    B.build("body", root)
    L.build("lamp_glow", root)
    empty("bubble", root, (0, 0, 3.2))
    fin(name, pitch=32)


# ------------------------------------------------------------------ Bauplatz
@model("o_pad")
def pad(name):
    root, B, G = start(name)
    B.cyl(1.6, 0.1, (0, 0, 0.05), "566078", sides=28, bevel=0.03, segs=1)
    B.cyl(1.42, 0.03, (0, 0, 0.105), "7286B8", sides=28)
    B.cyl(1.12, 0.03, (0, 0, 0.11), "5B6FA6", sides=24)
    for i in range(12):                                                                             # Randmarken
        a = i * 30
        B.box((0.2, 0.08, 0.03), (math.cos(math.radians(a)) * 1.28, math.sin(math.radians(a)) * 1.28, 0.115), "C9D4F0", r=rot(0, 0, a + 90))
    c = "E8EEFF"
    for sx in (-1, 1):                                                                              # Stiefelabdrücke
        m = T(0.3 * sx, 0.2, 0.125) @ rot(0, 0, -8 * sx)
        B.cyl(1.0, 0.03, (0, 0, 0), c, r=m @ T(0, 0.12, 0) @ S(0.2, 0.32, 1), sides=10)
        B.cyl(1.0, 0.03, (0, 0, 0), c, r=m @ T(0, -0.36, 0) @ S(0.16, 0.15, 1), sides=8)
    for k in range(2):                                                                              # Pfeilwinkel zeigen in den Platz
        y = -0.62 - k * 0.3
        for sx in (-1, 1):
            beam(B, (0.34 * sx, y - 0.2, 0.125), (0, y, 0.125), 0.1, GOLD, d=0.03)
    R = Part()
    R.torus(1.5, 0.06, (0, 0, 0.14), "7FE0FF", seg=32, tseg=5)
    B.build("body", root)
    R.build("ring_glow", root)
    fin(name, pitch=48)


# ------------------------------------------------------------------ Lieferwagen
@model("o_truck")
def truck(name):
    reset(); root = empty(name)
    b = Part()
    c1, c2, dk = "F2A024", "FFF1D0", "23262E"
    b.box((1.8, 3.6, 0.5), (0, 0, 0.82), c1, bevel=0.16, segs=3)                                    # Rahmen
    b.box((1.76, 1.25, 1.05), (0, -1.0, 1.52), c1, bevel=0.26, segs=3)                              # Kabine
    b.box((1.5, 0.5, 0.42), (0, -1.6, 1.02), c2, bevel=0.14, segs=2)                                # Schnauze
    b.box((1.78, 0.8, 0.4), (0, -1.02, 1.72), "BFE6FA", bevel=0.1, segs=1)                          # Seitenfenster
    b.box((1.44, 0.06, 0.42), (0, -1.6, 1.74), "BFE6FA", r=rot(-12, 0, 0), bevel=0.02, segs=1)      # Frontscheibe
    b.box((1.84, 0.2, 0.2), (0, -1.86, 0.68), "8A94A8", bevel=0.07, segs=1)                         # Stoßstange
    b.box((0.9, 0.06, 0.22), (0, -1.86, 1.0), dk, bevel=0.02, segs=1)
    b.box((1.6, 1.3, 0.1), (0, -1.0, 2.08), c2, bevel=0.04, segs=1)                                 # Dach hell
    b.box((1.7, 2.1, 0.12), (0, 0.72, 1.12), shade(c1, 0.72), bevel=0.03, segs=1)                   # Pritsche
    for sx in (-1, 1):
        b.box((0.1, 2.14, 0.4), (0.86 * sx, 0.72, 1.36), c2, bevel=0.04, segs=1)
        for i in range(3):
            b.box((0.12, 0.08, 0.42), (0.86 * sx, 0.0 + i * 0.72, 1.36), shade(c1, 0.85))
        b.box((0.5, 1.0, 0.1), (0.95 * sx, -1.15, 1.02), shade(c1, 0.8), bevel=0.04, segs=1)        # Kotflügel
        b.box((0.5, 0.95, 0.1), (0.95 * sx, 1.1, 1.02), shade(c1, 0.8), bevel=0.04, segs=1)
    b.box((1.8, 0.1, 0.4), (0, 1.78, 1.36), c2, bevel=0.04, segs=1)
    b.box((1.7, 0.1, 0.7), (0, -0.32, 1.5), shade(c1, 0.8), bevel=0.04, segs=1)
    star(b, (0, 1.84, 1.36), 0.14, BLUE, 0.03)
    crate(b, (-0.38, 0.35, 1.18), 0.72, WOOD, 4)                                                    # Ladung
    crate(b, (0.4, 0.45, 1.18), 0.66, "C98A48", -6)
    crate(b, (-0.3, 1.2, 1.18), 0.66, OLIVE, 8)
    crate(b, (0.05, 0.42, 1.88), 0.56, "C98A48", 18)
    barrel(b, (0.45, 1.25, 1.18), BLUE_L, 0.27, 0.72)
    b.build("body", root)
    lights(root, [(0.55, -1.87, 1.0), (-0.55, -1.87, 1.0)], size=(0.26, 0.08, 0.2))
    for n, x, y in (("wheel_fl", -0.92, -1.15), ("wheel_fr", 0.92, -1.15), ("wheel_bl", -0.92, 1.1), ("wheel_br", 0.92, 1.1)):
        wheel_lp(root, n, x, y, 0.48, 0.36, hub=c2)
    empty("seat", root, (0, -1.0, 1.2))
    fin(name, yaw=-40, pitch=22)


# ------------------------------------------------------------------ Händlerkarren
@model("o_trader")
def trader(name):
    root, B, G = start(name)
    # Wagenkasten
    B.box((2.0, 1.2, 0.16), (0, 0, 0.85), WOOD, bevel=0.04, segs=1)
    for sy in (-1, 1):
        B.box((2.0, 0.1, 0.4), (0, 0.56 * sy, 1.1), WOOD_L, bevel=0.03, segs=1)
        for i in range(3):
            B.box((0.03, 0.12, 0.36), (-0.5 + i * 0.5, 0.56 * sy, 1.1), shade(WOOD_L, 0.7))
    for sx in (-1, 1):
        B.box((0.1, 1.2, 0.4), (0.96 * sx, 0, 1.1), WOOD_L, bevel=0.03, segs=1)
    B.cyl(0.05, 1.7, (0.15, 0, 0.6), DK, r=rot(90, 0, 0), sides=6)                                  # Achse
    for sy in (-1, 1):
        m = T(0.15, 0.82 * sy, 0.6) @ rot(90, 0, 0)
        B.torus(0.56, 0.06, (0, 0, 0), WOOD_D, r=m, seg=14, tseg=5)
        B.cyl(0.12, 0.14, (0, 0, 0), GOLD, r=m, sides=8)
        for k in range(4):
            B.box((1.06, 0.06, 0.06), (0, 0, 0), WOOD, r=m @ rot(0, 0, k * 45))
    tube(B, (-0.95, 0.4, 0.85), (-2.0, 0.4, 0.55), 0.045, WOOD_D, 5)                                # Deichseln
    tube(B, (-0.95, -0.4, 0.85), (-2.0, -0.4, 0.55), 0.045, WOOD_D, 5)
    B.box((0.12, 0.12, 0.8), (-0.85, 0, 0.4), WOOD_D)                                               # Stütze
    # Waren
    crate(B, (-0.55, 0.15, 0.93), 0.6, "C98A48", 6)
    sack(B, (0.2, 0.2, 0.93), 0.8, yaw=30)
    B.cyl(0.2, 0.36, (0.6, -0.2, 1.11), "3FA7A0", r2=0.15, sides=9)                                 # Krug
    B.cyl(0.11, 0.1, (0.6, -0.2, 1.33), "3FA7A0", sides=7)
    for i, c in enumerate(("E04848", "F2B92E", "7CCB52", "E04848", "F28A1E")):                       # Obst in der Kiste
        B.ball(0.11, (-0.72 + (i % 3) * 0.17, 0.06 + (i // 3) * 0.17, 1.58), c, subdiv=2)
    B.box((0.5, 0.34, 0.2), (-0.1, -0.3, 1.03), BLUE_L, bevel=0.04, segs=1)
    for i in range(3):
        B.cyl(0.06, 0.26, (-0.25 + i * 0.15, -0.3, 1.24), ("B77BFF", "FF6FA8", "5FE3FF")[i], sides=6)   # Fläschchen
        B.cyl(0.03, 0.08, (-0.25 + i * 0.15, -0.3, 1.4), WOOD_L, sides=5)
    chest(B, (0.62, 0.22, 0.93), 0.5, GOLD, RED_D, 10)
    # Sonnenschirm
    B.cyl(0.045, 2.6, (0.85, 0.48, 2.2), WOOD_D, sides=6)
    ax, ay, az, R, H = 0.85, 0.48, 3.5, 1.35, 0.55                                                  # Spitze, Radius, Höhe
    B.cone(R, H, (ax, ay, az - H * 0.5), RED, sides=16)
    B.cyl(R, 0.1, (ax, ay, az - H - 0.03), RED_D, sides=16, r2=R * 0.97)
    L = math.hypot(R, H)
    for i in range(8):                                                                              # helle Felder und Bommeln
        am = i * 45 + 11.25
        B.cyl(1.0, 0.03, (0, 0, 0), "FFF1D0", r=T(ax, ay, az) @ rot(0, 0, am) @ rot(0, math.degrees(math.atan2(H, R * 0.98)), 0) @ T(L * 0.65, 0, 0.02)
              @ S(L * 0.65, R * 0.2 / 0.866 * 0.95, 1) @ rot(0, 0, 90), sides=3)
        a = math.radians(i * 45 + 11.25 + 22.5)
        B.ball(0.07, (ax + math.cos(a) * R, ay + math.sin(a) * R, az - H - 0.08), GOLD, subdiv=2)
    B.ball(0.1, (0.85, 0.48, 3.52), GOLD, subdiv=2)
    # Laterne an einer Stange
    B.cyl(0.04, 1.5, (-0.9, -0.5, 1.75), WOOD_D, sides=5)
    B.box((0.5, 0.05, 0.05), (-0.7, -0.5, 2.46), WOOD_D)
    B.box((0.22, 0.22, 0.05), (-0.5, -0.5, 2.36), DK)
    B.box((0.22, 0.22, 0.05), (-0.5, -0.5, 2.06), DK)
    G.box((0.17, 0.17, 0.26), (-0.5, -0.5, 2.21), GLOW, bevel=0.04, segs=1)
    # Preisschild
    B.box((0.6, 0.05, 0.36), (0.3, -0.66, 1.05), CREAM, bevel=0.03, segs=1)
    coin_(B, T(0.3, -0.7, 1.05) @ rot(90, 0, 0), 0.12, 0.03)
    B.build("body", root)
    G.build("lamp_glow", root)
    empty("bubble", root, (0, 0, 4.2))
    fin(name, yaw=-30, pitch=24)


import exp_special, exp_barriers, exp_nodes, exp_areas   # tragen sich in REG ein

MODELS = REG

if __name__ == "__main__":
    args = sys.argv[1:]
    if args == ["list"]:
        print("\n".join(MODELS))
        sys.exit(0)
    for n in (args or list(MODELS)):
        if n not in MODELS:
            print("unbekannt:", n, flush=True)
            continue
        MODELS[n]()
        print("ok", n, flush=True)
