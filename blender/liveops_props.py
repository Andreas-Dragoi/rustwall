"""Paket L (Live-Betrieb): Kosmetik und Feiertage aus Blender.
  lo_flag_<k>     Fahnen (Mast + wehendes Tuch `sway_cloth` mit Wappen)            – stehen neben dem Bunker
  lo_hat_<k>      Begleiter-Hüte (Ursprung unten Mitte, ca. 0,5 m breit)           – sitzen auf dem Kopf des Begleiters
  lo_bskin_<k>    Bunker-Skins: Anbauten an den vier Ecken des 8 x 8 m großen Bunkers (dazu färbt Godot den Bunker um)
  lo_pumpkin, lo_pumpkins, lo_pumpkin_hat, lo_gift, lo_gifts, lo_xmas_tree, lo_snowman, lo_snowpile, lo_egg_1..4   Feiertage
  lo_wskin_<k>    Sprühdose in der Farbe eines Waffen-Skins (nur Symbol)
  ui_season, ui_wardrobe, ui_event, ui_news, ui_calendar, ui_prestige, ui_nightmare, ui_boost   Symbole der Menüs
Aufruf: python3 blender/liveops_props.py [name ...]   (ohne Namen: alle)"""
import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from kit import *
from weapons import prism, star, toon, scale_all, tris, BLUE, BLUE_L, BLUE_D, YEL, YEL_L, ORG, RED, RED_D, GRN, GRN_D, PINK, VIO, VIO_D, WHITE, GREY, GREY_L, DGREY, HOLE, CYAN, TAN, WOOD
from ui_icons import D, gleam, FLAT, SOLID

GOLD, GOLD_D = "FFD23E", "C9961E"
BLACK = "2A2D3A"
ORANGE, ORANGE_D = "FF8A1F", "D9661A"

# ================================================================== Wappen (7 x 7 Punkte, "#" = Farbe 1, "+" = Farbe 2)
EMBLEM = {
    "blitz": ["...##..", "..##...", ".####..", "...##..", "..##...", ".##....", "##....."],
    "schaedel": [".#####.", "#######", "#+#+#+#", "#######", ".#####.", ".#.#.#.", "......."],
    "schleim": ["...#...", "..###..", ".#####.", "##+#+##", "#######", "#######", ".#####."],
    "zahnrad": ["#.###.#", ".#####.", "###+###", "##+++##", "###+###", ".#####.", "#.###.#"],
    "krone": ["#..#..#", "#.###.#", "#######", "#+#+#+#", "#######", ".......", "......."],
    "flamme": ["...#...", "..##...", "..###..", ".##+##.", ".#+++#.", "#+++++#", ".#####."],
    "flocke": ["#..#..#", ".#.#.#.", "..###..", "#######", "..###..", ".#.#.#.", "#..#..#"],
    "kuerbis": ["...+...", "..###..", ".#####.", "##.#.##", "#######", "#.#.#.#", ".#####."],
    "stern": ["...#...", "...#...", "#######", ".#####.", "..###..", ".##.##.", "#.....#"],
}
# Schlüssel: (Tuchfarbe, Wappen, Wappenfarbe 1, Wappenfarbe 2)
FLAGS = {
    "sturm": (BLUE, "blitz", YEL, YEL),
    "schaedel": (BLACK, "schaedel", WHITE, HOLE),
    "schleim": (GRN, "schleim", "C4FF6A", HOLE),
    "zahnrad": (ORANGE, "zahnrad", DGREY, ORANGE),
    "krone": (VIO, "krone", GOLD, RED),
    "flamme": (RED, "flamme", YEL, "FFF2A0"),
    "flocke": (BLUE_L, "flocke", WHITE, WHITE),
    "kuerbis": ("3A2A5E", "kuerbis", ORANGE, GRN),
    "saison": ("1F56C4", "stern", GOLD, GOLD),
}


def flag(k):
    cloth_col, em, c1, c2 = FLAGS[k]
    reset()
    root = empty("lo_flag_" + k)
    p = Part()
    p.box((0.7, 0.7, 0.3), (0, 0, 0.15), "8A8F9E", bevel=0.08)                 # Sockel
    p.box((0.5, 0.5, 0.12), (0, 0, 0.36), "A7ADC6", bevel=0.04)
    p.cyl(0.06, 3.4, (0, 0, 2.0), "C5CEDF", sides=12)                           # Mast
    p.ball(0.13, (0, 0, 3.75), GOLD, subdiv=2)                                   # Knauf
    p.cyl(0.09, 0.08, (0, 0, 3.0), DGREY, sides=12)
    toon(p)
    p.build("body", root)
    c = Part()                                                                   # Tuch: Ursprung am Mast
    W, H = 1.5, 1.0
    c.box((W, 0.05, H), (W * 0.5 + 0.07, 0, -H * 0.5), cloth_col, bevel=0.02, segs=1)
    c.box((0.08, 0.07, H), (0.07, 0, -H * 0.5), shade(cloth_col, 0.7), bevel=0.01, segs=1)
    s = 0.11
    rows = EMBLEM[em]
    for zi, row in enumerate(rows):
        for xi, ch in enumerate(row):
            if ch == ".":
                continue
            cc = c1 if ch == "#" else c2
            x = W * 0.5 + 0.07 + (xi - 3) * s
            z = -H * 0.5 - (zi - 3) * s
            c.box((s, 0.08, s), (x, 0, z), cc)
    for i in range(4):                                                           # Zacken am Ende
        c.box((0.16, 0.05, 0.16), (W + 0.07, 0, -0.12 - i * 0.25), cloth_col, r=rot(0, 45, 0))
    toon(c, 0.85, 1.08)
    c.build("sway_cloth", root, (0, 0, 3.55))
    save("lo_flag_" + k)
    icon("lo_flag_" + k, 192, yaw=-20, pitch=8, margin=1.06)


# ================================================================== Begleiter-Hüte
def hat_zylinder(p):
    p.cyl(0.3, 0.05, (0, 0, 0.025), BLACK, bevel=0.02)
    p.cyl(0.19, 0.38, (0, 0, 0.23), BLACK, r2=0.2, bevel=0.03)
    p.cyl(0.195, 0.07, (0, 0, 0.09), RED, sides=20)
    gleam(p, -0.08, 0.3, -0.19, 0.03, 0.08, a=0)


def hat_party(p):
    for i in range(5):
        z0 = i * 0.09
        r0 = 0.22 * (1 - i / 5)
        r1 = 0.22 * (1 - (i + 1) / 5)
        p.cyl(r0, 0.09, (0, 0, z0 + 0.045), PINK if i % 2 == 0 else YEL, r2=max(r1, 0.01), sides=16)
    p.ball(0.07, (0, 0, 0.47), CYAN, subdiv=2)
    p.torus(0.21, 0.025, (0, 0, 0.02), BLUE_L, seg=18, tseg=6)


def hat_krone(p):
    p.cyl(0.22, 0.14, (0, 0, 0.07), GOLD, sides=20, bevel=0.02)
    for i in range(6):
        a = i * math.pi / 3
        p.cone(0.06, 0.16, (math.cos(a) * 0.19, math.sin(a) * 0.19, 0.22), GOLD, sides=8)
        p.ball(0.03, (math.cos(a) * 0.19, math.sin(a) * 0.19, 0.31), YEL_L, subdiv=1)
    for i, cc in enumerate((RED, BLUE, GRN)):
        a = -math.pi / 2 + (i - 1) * 0.7
        p.ball(0.035, (math.cos(a) * 0.22, math.sin(a) * 0.22, 0.07), cc, subdiv=2)


def hat_kuerbis(p):
    for i in range(6):
        a = i * math.pi / 3
        p.ball(0.13, (math.cos(a) * 0.1, math.sin(a) * 0.1, 0.12), ORANGE if i % 2 else ORANGE_D, scale=(1, 1, 0.9), subdiv=2)
    p.ball(0.17, (0, 0, 0.13), ORANGE, scale=(1, 1, 0.85), subdiv=2)
    p.cyl(0.035, 0.12, (0, 0, 0.3), GRN_D, r=rot(10, 0, 0), sides=8)
    p.ball(0.06, (0.07, 0, 0.3), GRN, scale=(1.4, 0.5, 0.3), subdiv=1)


def hat_weihnacht(p):
    p.torus(0.2, 0.06, (0, 0, 0.05), WHITE, seg=20, tseg=8)
    p.cyl(0.2, 0.22, (0, 0, 0.16), RED, r2=0.12, sides=16)
    p.cyl(0.12, 0.16, (0.04, 0, 0.33), RED, r2=0.05, r=rot(0, 25, 0), sides=12)
    p.ball(0.06, (0.13, 0, 0.42), WHITE, subdiv=2)


def hat_cowboy(p):
    p.cyl(0.36, 0.04, (0, 0, 0.03), "8A5A32", bevel=0.015)
    for sx in (-1, 1):
        p.box((0.12, 0.6, 0.04), (sx * 0.32, 0, 0.08), "8A5A32", r=rot(0, sx * 30, 0), bevel=0.015)
    p.cyl(0.18, 0.2, (0, 0, 0.14), "A86E3E", r2=0.16, bevel=0.04)
    p.box((0.1, 0.38, 0.06), (0, 0, 0.25), "8A5A32", bevel=0.03)
    p.cyl(0.185, 0.05, (0, 0, 0.07), "4A3020", sides=20)


def hat_wikinger(p):
    p.ball(0.22, (0, 0, 0.0), "9AA4B8", scale=(1, 1, 0.9), subdiv=3)
    p.box((0.46, 0.46, 0.2), (0, 0, -0.12), "9AA4B8")              # unten wird abgeschnitten (liegt im Kopf)
    p.torus(0.215, 0.025, (0, 0, 0.02), "C9963E", seg=20, tseg=6)
    p.box((0.04, 0.03, 0.22), (0, -0.21, 0.08), "C9963E")
    for sx in (-1, 1):
        p.cyl(0.07, 0.12, (sx * 0.22, 0, 0.1), "C9963E", r=rot(0, sx * 90, 0), sides=10)
        p.cone(0.07, 0.34, (sx * 0.36, 0, 0.24), "F4ECD8", r=rot(0, sx * 35, 0), sides=10)


def hat_propeller(p):
    p.ball(0.2, (0, 0, 0.0), BLUE, scale=(1, 1, 0.75), subdiv=3)
    p.box((0.42, 0.42, 0.16), (0, 0, -0.1), BLUE)
    for i in range(4):
        a = i * math.pi / 2
        p.box((0.05, 0.2, 0.01), (math.cos(a) * 0.1, math.sin(a) * 0.1, 0.14), YEL if i % 2 else RED, r=rot(0, 0, math.degrees(a) + 90))
    p.box((0.2, 0.08, 0.03), (0, -0.22, 0.0), BLUE_D, bevel=0.01)
    p.cyl(0.02, 0.1, (0, 0, 0.19), DGREY, sides=8)


def propeller_blades(q):
    q.cyl(0.03, 0.03, (0, 0, 0), RED, sides=8)
    for sx, cc in ((-1, YEL), (1, GRN)):
        q.box((0.26, 0.07, 0.015), (sx * 0.14, 0, 0), cc, r=rot(sx * 12, 0, 0), bevel=0.01, segs=1)


HATS = dict(zylinder=hat_zylinder, party=hat_party, krone=hat_krone, kuerbis=hat_kuerbis, weihnacht=hat_weihnacht,
            cowboy=hat_cowboy, wikinger=hat_wikinger, propeller=hat_propeller)


def cut_below(p, z=0.0):
    """Teile unterhalb von z wegschneiden (Hüte sitzen auf dem Kopf)."""
    geom = list(p.bm.verts) + list(p.bm.edges) + list(p.bm.faces)
    bmesh.ops.bisect_plane(p.bm, geom=geom, plane_co=(0, 0, z), plane_no=(0, 0, 1), clear_inner=True)


def hat(k):
    reset()
    root = empty("lo_hat_" + k)
    p = Part()
    HATS[k](p)
    cut_below(p, 0.0)
    toon(p, 0.82, 1.1)
    p.build("body", root)
    if k == "propeller":
        q = Part()
        propeller_blades(q)
        q.build("spin_prop", root, (0, 0, 0.25))
    save("lo_hat_" + k)
    icon("lo_hat_" + k, 160, yaw=-28, pitch=18, margin=1.1)


# ================================================================== Bunker-Skins (Anbauten an den Ecken, Bunker 8 x 8 m)
CORNERS = [(-3.7, -3.7), (3.7, -3.7), (-3.7, 3.7), (3.7, 3.7)]


def bskin_rostfestung(p, root):
    for (x, y) in CORNERS:
        p.box((0.9, 0.9, 0.5), (x, y, 0.25), "6B4A32", bevel=0.06)
        p.cyl(0.32, 2.4, (x, y, 1.6), "A0522D", r2=0.26, sides=8, bevel=0.03)
        for i in range(3):
            p.cyl(0.36, 0.12, (x, y, 0.9 + i * 0.7), "5A3A28", sides=8)
        for i in range(6):
            a = i * math.pi / 3
            p.cone(0.07, 0.4, (x + math.cos(a) * 0.35, y + math.sin(a) * 0.35, 2.2), "C9CED8", r=rot(0, 90, math.degrees(a)), sides=6)
        p.cone(0.18, 0.5, (x, y, 3.05), "8A8F9E", sides=8)
    # Schädelschild vorn über dem Eingang
    p.box((1.6, 0.14, 0.9), (0, -4.15, 2.6), "5A3A28", bevel=0.05)
    p.ball(0.3, (0, -4.25, 2.65), "E8DCC0", scale=(1, 0.6, 1), subdiv=2)
    for sx in (-1, 1):
        p.box((0.12, 0.05, 0.12), (sx * 0.11, -4.43, 2.68), HOLE)
        p.box((0.9, 0.1, 0.12), (sx * 0.0, -4.2, 2.6), "E8DCC0", r=rot(0, sx * 45, 0))
    for sx in (-1, 1):                                            # Ketten
        for i in range(5):
            p.torus(0.08, 0.025, (sx * (1.0 + i * 0.5), -4.1, 2.95 - abs(i - 2) * 0.12), "6F7C96", r=rot(90, 0, 0), seg=10, tseg=5)


def bskin_polarstation(p, root):
    for (x, y) in CORNERS:
        p.ball(0.75, (x, y, 0.1), WHITE, scale=(1, 1, 0.6), subdiv=2)
        p.box((0.5, 0.5, 1.6), (x, y, 1.0), "7CC2FF", bevel=0.08)
        p.box((0.6, 0.6, 0.15), (x, y, 1.85), WHITE, bevel=0.05)
        for i in range(3):
            p.cone(0.12, 0.45, (x + (i - 1) * 0.25, y + 0.2, 0.55), "BDEBFF", sides=6)
    lamps = Part()
    for (x, y) in CORNERS:
        lamps.ball(0.18, (x, y, 2.1), "9FE8FF", subdiv=2)
    lamps.build("lamp_glow", root)
    # Antennenmast hinten links mit drehender Schüssel
    p.cyl(0.07, 3.8, (-3.7, 3.7, 3.8), "C5CEDF", sides=8)
    for i in range(4):
        p.box((0.6, 0.04, 0.04), (-3.7, 3.7, 2.4 + i * 0.7), "C5CEDF", r=rot(0, 0, 45 * i))
    dish = Part()
    dish.cyl(0.5, 0.14, (0, -0.1, 0), WHITE, r=rot(80, 0, 0), r2=0.2, sides=16)
    dish.cyl(0.03, 0.4, (0, -0.35, 0.03), DGREY, r=rot(80, 0, 0), sides=6)
    dish.build("spin_dish", root, (-3.7, 3.7, 5.8))


def bskin_goldpalast(p, root):
    for (x, y) in CORNERS:
        p.box((0.9, 0.9, 0.35), (x, y, 0.18), "F4ECD8", bevel=0.06)
        p.cyl(0.3, 2.6, (x, y, 1.65), GOLD, r2=0.18, sides=4, bevel=0.02, r=rot(0, 0, 45))
        p.torus(0.33, 0.05, (x, y, 0.45), GOLD_D, seg=16, tseg=6)
    tips = Part()
    for (x, y) in CORNERS:
        tips.cone(0.2, 0.4, (x, y, 3.15), "FFF2A0", sides=4)
    tips.build("pulse_tip_glow", root)
    for i, (x, y) in enumerate(CORNERS[:2]):                      # Banner vorn
        b = Part()
        b.box((0.8, 0.05, 1.5), (0, 0, -0.75), RED, bevel=0.02, segs=1)
        b.box((0.82, 0.07, 0.1), (0, 0, -0.05), GOLD)
        b.box((0.82, 0.07, 0.1), (0, 0, -1.45), GOLD)
        star(b, 0.22, 0.08, (0, -0.02, -0.7), GOLD)
        b.build("sway_banner_%d" % i, root, (x + (0.5 if x < 0 else -0.5), y - 0.45, 3.0))


BSKINS = dict(rostfestung=bskin_rostfestung, polarstation=bskin_polarstation, goldpalast=bskin_goldpalast)


def bskin(k):
    reset()
    root = empty("lo_bskin_" + k)
    p = Part()
    BSKINS[k](p, root)
    toon(p, 0.82, 1.08)
    p.build("body", root)
    save("lo_bskin_" + k)
    stand = Part()                                                # nur fürs Symbol: grauer Bunker als Platzhalter
    stand.box((6.8, 6.8, 3.0), (0, 0, 1.5), "8A94A8", bevel=0.4)
    stand.box((7.4, 7.4, 0.3), (0, 0, 0.15), "6F7C96", bevel=0.1)
    stand.build("stand", root)
    icon("lo_bskin_" + k, 192, yaw=-30, pitch=24, margin=1.04)


# ================================================================== Feiertage
def pumpkin(p, x=0.0, y=0.0, s=1.0, carved=True, z=0.0):
    for i in range(8):
        a = i * math.pi / 4
        p.ball(0.26 * s, (x + math.cos(a) * 0.2 * s, y + math.sin(a) * 0.2 * s, z + 0.32 * s), ORANGE if i % 2 else ORANGE_D, scale=(1, 1, 0.92), subdiv=2)
    p.ball(0.36 * s, (x, y, z + 0.33 * s), ORANGE, scale=(1, 1, 0.85), subdiv=2)
    p.cyl(0.05 * s, 0.18 * s, (x, y, z + 0.66 * s), GRN_D, r=rot(12, 0, 0), sides=8)
    p.ball(0.09 * s, (x + 0.1 * s, y, z + 0.66 * s), GRN, scale=(1.5, 0.6, 0.35), subdiv=1)


def face(q, x=0.0, y=0.0, s=1.0, z=0.0):
    """Leuchtendes Gesicht einer Kürbislaterne (Vorderseite -Y)."""
    fy = y - 0.43 * s
    for sx in (-1, 1):
        prism(q, [(-0.07, -0.05), (0.07, -0.05), (0.0, 0.07)], 0.06 * s, (x + sx * 0.14 * s, fy, z + 0.42 * s), "FFC23E", r=Matrix.Diagonal(Vector((s, 1, s, 1))))
    prism(q, [(-0.2, 0.0), (0.2, 0.0), (0.14, -0.08), (0.07, -0.03), (0.0, -0.09), (-0.07, -0.03), (-0.14, -0.08)], 0.06 * s, (x, fy, z + 0.26 * s), "FFC23E", r=Matrix.Diagonal(Vector((s, 1, s, 1))))


def lo_pumpkin(root):
    p = Part()
    pumpkin(p)
    toon(p)
    p.build("body", root)
    q = Part()
    face(q)
    q.build("face_glow", root)


def lo_pumpkins(root):
    p = Part()
    pumpkin(p, -0.45, 0.15, 0.8, z=0.0)
    pumpkin(p, 0.45, 0.25, 0.65)
    pumpkin(p, 0.0, -0.3, 1.0)
    p.box((1.6, 1.1, 0.12), (0.0, 0.0, 0.06), "C9A86A", bevel=0.05)        # Strohballen-Platte
    toon(p)
    p.build("body", root)
    q = Part()
    face(q, 0.0, -0.3, 1.0)
    q.build("face_glow", root)


def lo_pumpkin_hat(root):
    """Hexenhut der Kürbis-Schleime (Halloween): schwarz mit orangem Band und kleinem Kürbis – hebt sich vom orangen Schleim ab."""
    p = Part()
    p.cyl(0.42, 0.05, (0, 0, 0.025), BLACK, bevel=0.02, sides=20)
    p.cyl(0.22, 0.3, (0, 0, 0.2), BLACK, r2=0.13, sides=16)
    p.cyl(0.13, 0.22, (0.03, 0, 0.45), BLACK, r2=0.03, r=rot(0, 18, 0), sides=12)
    p.cyl(0.225, 0.07, (0, 0, 0.09), ORANGE, sides=16)
    pumpkin(p, 0.0, -0.22, 0.22, z=0.04)
    toon(p)
    p.build("body", root)


def gift(p, x, y, s, c1, c2, z=0.0, a=0.0):
    m = rot(0, 0, a)
    def L(v):
        w = m @ Vector(v)
        return (x + w.x, y + w.y, z + w.z)
    p.box((0.6 * s, 0.6 * s, 0.5 * s), L((0, 0, 0.25 * s)), c1, r=m, bevel=0.03)
    p.box((0.64 * s, 0.1 * s, 0.52 * s), L((0, 0, 0.25 * s)), c2, r=m)
    p.box((0.1 * s, 0.64 * s, 0.52 * s), L((0, 0, 0.25 * s)), c2, r=m)
    for sx in (-1, 1):
        p.torus(0.09 * s, 0.03 * s, L((sx * 0.08 * s, 0, 0.55 * s)), c2, r=m @ rot(90, 0, 0) @ rot(0, sx * 30, 0), seg=10, tseg=5)


def lo_gift(root):
    p = Part()
    gift(p, 0, 0, 1.0, RED, GOLD)
    toon(p)
    p.build("body", root)


def lo_gifts(root):
    p = Part()
    gift(p, -0.35, 0.1, 1.0, RED, GOLD, a=10)
    gift(p, 0.4, 0.15, 0.8, GRN, WHITE, a=-15)
    gift(p, 0.0, -0.4, 0.7, BLUE, YEL, a=30)
    gift(p, -0.32, 0.12, 0.6, VIO, YEL_L, z=0.5, a=40)
    toon(p)
    p.build("body", root)


def lo_xmas_tree(root):
    p = Part()
    p.cyl(0.18, 0.5, (0, 0, 0.25), "7A4522", sides=10)
    p.box((0.7, 0.7, 0.35), (0, 0, 0.17), RED, bevel=0.05)
    for i, (r, z) in enumerate(((1.15, 0.9), (0.9, 1.65), (0.62, 2.3))):
        p.cone(r, 1.1, (0, 0, z), "2E7A3A" if i % 2 == 0 else "3D8A44", sides=12)
    import random
    rnd = random.Random(7)
    for i in range(16):
        h = rnd.uniform(0.6, 2.4)
        r = 1.1 * (2.9 - h) / 2.5
        a = rnd.uniform(0, math.tau)
        p.ball(0.08, (math.cos(a) * r * 0.8, math.sin(a) * r * 0.8, h), [RED, BLUE, GOLD, WHITE][i % 4], subdiv=1)
    toon(p)
    p.build("body", root)
    g = Part()
    for i in range(20):
        h = 0.55 + i * 0.1
        r = 1.15 * (2.9 - h) / 2.5
        a = i * 2.2
        g.ball(0.045, (math.cos(a) * r * 0.85, math.sin(a) * r * 0.85, h), "FFE98A", subdiv=1)
    star(g, 0.25, 0.08, (0, 0, 3.05), "FFE98A")
    g.build("pulse_lights_glow", root)


def lo_snowman(root):
    p = Part()
    p.ball(0.55, (0, 0, 0.45), WHITE, subdiv=3)
    p.ball(0.4, (0, 0, 1.15), WHITE, subdiv=3)
    p.ball(0.3, (0, 0, 1.68), WHITE, subdiv=3)
    p.cone(0.06, 0.3, (0, -0.4, 1.68), ORANGE, r=rot(90, 0, 0), sides=8)
    for sx in (-1, 1):
        p.ball(0.04, (sx * 0.1, -0.26, 1.78), HOLE, subdiv=1)
    for i in range(3):
        p.ball(0.045, (0, -0.39, 1.0 + i * 0.15), HOLE, subdiv=1)
    p.torus(0.27, 0.06, (0, 0, 1.47), RED, seg=16, tseg=6)
    p.box((0.12, 0.08, 0.35), (0.18, -0.25, 1.32), RED, r=rot(0, -15, 0))
    p.cyl(0.25, 0.04, (0, 0, 1.94), BLACK)
    p.cyl(0.16, 0.3, (0, 0, 2.1), BLACK)
    for sx in (-1, 1):
        p.cyl(0.03, 0.6, (sx * 0.55, 0, 1.3), "7A4522", r=rot(0, sx * 60, 0), sides=6)
    toon(p, 0.88, 1.05)
    p.build("body", root)


def lo_snowpile(root):
    p = Part()
    p.ball(0.9, (0, 0, -0.35), WHITE, scale=(1.2, 1.0, 0.6), subdiv=2)
    p.ball(0.5, (0.6, 0.3, -0.1), "EAF4FF", scale=(1, 1, 0.6), subdiv=2)
    p.ball(0.45, (-0.7, -0.2, -0.12), "EAF4FF", scale=(1, 1, 0.6), subdiv=2)
    cut_below(p, 0.0)
    toon(p, 0.86, 1.04)
    p.build("body", root)


EGG_COLS = {1: (PINK, YEL, BLUE), 2: (CYAN, WHITE, VIO), 3: (YEL, RED, GRN), 4: (GRN, YEL_L, ORANGE)}


def egg(root, n):
    c1, c2, c3 = EGG_COLS[n]
    p = Part()
    p.ball(0.24, (0, 0, 0.0), c1, scale=(1, 1, 1.3), subdiv=3)
    p.torus(0.235, 0.03, (0, 0, 0.05), c2, seg=20, tseg=5)
    p.torus(0.2, 0.03, (0, 0, 0.18), c3, seg=20, tseg=5)
    p.torus(0.21, 0.03, (0, 0, -0.1), c3, seg=20, tseg=5)
    for i in range(6):
        a = i * math.pi / 3
        p.ball(0.03, (math.cos(a) * 0.235, math.sin(a) * 0.235, -0.02), c2, subdiv=1)
    toon(p, 0.85, 1.12)
    p.build("bob_egg", root, (0, 0, 0.45))
    g = Part()
    g.cyl(0.3, 0.04, (0, 0, 0.02), "C9A86A", sides=16)
    for i in range(10):
        a = i * math.tau / 10
        g.box((0.25, 0.03, 0.03), (math.cos(a) * 0.25, math.sin(a) * 0.25, 0.06), "B8904E", r=rot(0, 0, math.degrees(a) + 70))
    g.build("body", root)


# ================================================================== Waffen-Skins: Sprühdosen (Symbol)
WSKIN_COLS = {"gold": ("FFD23E", "FFF2A0"), "chrom": ("C5CEDF", "F4F6FA"), "tarn": ("4C7426", "8A8F5A"), "neon": ("FF4FD8", "42E07A"),
              "obsidian": ("2A2D3A", "8C5DF2"), "frost": ("7CC2FF", "F4F6FA"), "lava": ("EC3B33", "FFCB2E")}


def wskin(root, k):
    c1, c2 = WSKIN_COLS[k]
    p = Part()
    p.cyl(0.22, 0.7, (0, 0, 0.35), c1, bevel=0.04)
    p.cyl(0.225, 0.12, (0, 0, 0.45), c2, sides=20)
    p.cyl(0.2, 0.12, (0, 0, 0.76), "C5CEDF", r2=0.08, sides=16)
    p.box((0.1, 0.1, 0.1), (0, 0, 0.86), WHITE, bevel=0.03)
    p.cyl(0.02, 0.06, (0, -0.07, 0.86), HOLE, r=rot(90, 0, 0), sides=6)
    for i in range(5):                                            # Farbnebel
        p.ball(0.06 + i * 0.015, (0, -0.2 - i * 0.1, 0.86 + i * 0.03), c1 if i % 2 else c2, subdiv=1)
    gleam(p, -0.12, 0.35, -0.19, 0.03, 0.15, a=0)
    toon(p)
    p.build("body", root)


# ================================================================== Menü-Symbole
def ui_season(p):
    """Goldene Medaille mit Stern an blauem Band: Saison-Pass."""
    prism(p, [(-0.28, 0.5), (-0.08, 0.5), (0.08, 0.05), (-0.12, 0.05)], 0.06, (0, 0.04, 0), BLUE, bevel=0.01, segs=1)
    prism(p, [(0.28, 0.5), (0.08, 0.5), (-0.08, 0.05), (0.12, 0.05)], 0.06, (0, 0.06, 0), BLUE_D, bevel=0.01, segs=1)
    D(p, 0.3, 0.12, 0, -0.18, GOLD, bevel=0.03)
    D(p, 0.23, 0.14, 0, -0.18, GOLD_D)
    star(p, 0.17, 0.16, (0, -0.02, -0.18), YEL_L)
    gleam(p, -0.13, -0.05, -0.08, 0.06, 0.025)


def ui_wardrobe(p):
    """Kleiderbügel mit rotem Hemd: Garderobe."""
    p.torus(0.06, 0.02, (0, 0, 0.44), GREY_L, r=rot(90, 0, 0), seg=12, tseg=5)
    prism(p, [(-0.42, 0.18), (0.42, 0.18), (0.0, 0.36)], 0.05, (0, 0, 0), "B9733A", bevel=0.015, segs=1)
    prism(p, [(-0.34, 0.18), (0.34, 0.18), (0.42, 0.0), (0.26, -0.06), (0.24, -0.42), (-0.24, -0.42), (-0.26, -0.06), (-0.42, 0.0)], 0.1, (0, -0.03, 0), RED, bevel=0.03, segs=2)
    prism(p, [(-0.08, 0.18), (0.08, 0.18), (0.0, 0.05)], 0.12, (0, -0.04, 0), WHITE)
    for i in range(3):
        p.ball(0.025, (0, -0.1, 0.0 - i * 0.12), YEL, subdiv=1)
    gleam(p, -0.2, 0.05, -0.09, 0.04, 0.1, a=0)


def ui_event(p):
    """Goldene Glocke mit Ausrufezeichen-Strahlen: Ereignis."""
    p.cyl(0.32, 0.12, (0, 0, -0.3), GOLD_D, r2=0.3, sides=24)
    p.cyl(0.3, 0.42, (0, 0, -0.04), GOLD, r2=0.16, sides=24, bevel=0.04)
    p.ball(0.16, (0, 0, 0.18), GOLD, scale=(1, 1, 0.7), subdiv=2)
    p.torus(0.06, 0.02, (0, 0, 0.32), GOLD_D, r=rot(90, 0, 0), seg=12, tseg=5)
    p.ball(0.07, (0, 0, -0.38), DGREY, subdiv=2)
    for sx in (-1, 1):
        p.box((0.05, 0.05, 0.16), (sx * 0.43, -0.05, 0.08), RED, r=rot(0, sx * 30, 0), bevel=0.02)
        p.box((0.05, 0.05, 0.12), (sx * 0.46, -0.05, -0.15), RED, r=rot(0, sx * 70, 0), bevel=0.02)
    gleam(p, -0.12, 0.0, -0.22, 0.04, 0.12, a=-10)


def ui_news(p):
    """Anschlagtafel mit Zetteln: Neuigkeiten."""
    p.box((0.86, 0.1, 0.62), (0, 0.04, 0.06), "B9733A", bevel=0.04)
    p.box((0.76, 0.06, 0.52), (0, -0.0, 0.06), "E8C890", bevel=0.01, segs=1)
    for sx in (-1, 1):
        p.box((0.07, 0.07, 0.4), (sx * 0.3, 0.04, -0.38), "7A4522", bevel=0.02)
    for i, (x, z, c) in enumerate(((-0.18, 0.14, WHITE), (0.17, 0.18, YEL_L), (0.05, -0.1, "BDEBFF"))):
        p.box((0.28, 0.02, 0.24), (x, -0.04, z), c, r=rot(0, (i - 1) * 8, 0))
        p.ball(0.03, (x, -0.07, z + 0.1), RED, subdiv=1)
        for j in range(3):
            p.box((0.18, 0.01, 0.02), (x, -0.055, z + 0.03 - j * 0.05), DGREY, r=rot(0, (i - 1) * 8, 0))


def ui_calendar(p):
    """Kalenderblatt mit Häkchen: Login-Kalender."""
    p.box((0.8, 0.12, 0.74), (0, 0, -0.04), WHITE, bevel=0.06)
    p.box((0.8, 0.14, 0.2), (0, -0.01, 0.27), RED, bevel=0.05)
    for sx in (-1, 1):
        p.cyl(0.04, 0.2, (sx * 0.2, -0.02, 0.4), GREY, sides=10)
    for i in range(3):
        for j in range(3):
            p.box((0.14, 0.02, 0.1), (-0.22 + i * 0.22, -0.07, 0.05 - j * 0.17), GREY_L if (i + j) % 3 else GOLD)
    prism(p, [(-0.18, -0.02), (-0.06, -0.12), (0.2, 0.16), (0.14, 0.2), (-0.06, -0.02), (-0.13, 0.04)], 0.06, (0.08, -0.1, -0.12), GRN, bevel=0.01, segs=1)


def ui_prestige(p):
    """Silberner Stern im Lorbeerkranz: Prestige."""
    for sx in (-1, 1):
        for i in range(6):
            a = math.radians(-70 + i * 26)
            x = sx * math.cos(a) * 0.38
            z = math.sin(a) * 0.38 - 0.02
            p.ball(0.07, (x, 0, z), GRN if i % 2 else GRN_D, scale=(1, 0.5, 1.6), r=rot(0, sx * (90 - math.degrees(a)), 0), subdiv=1)
    star(p, 0.3, 0.16, (0, -0.02, 0.0), "DDE3EE", color2=GREY)
    p.box((0.3, 0.06, 0.08), (0, 0, -0.42), RED, bevel=0.02)
    gleam(p, -0.08, 0.1, -0.11, 0.05, 0.02)


def ui_nightmare(p):
    """Violetter Totenkopf in Flammen: Albtraum+."""
    for i, (x, h) in enumerate(((-0.24, 0.5), (0.0, 0.66), (0.24, 0.5), (-0.36, 0.32), (0.36, 0.32))):
        p.cone(0.14, h, (x, 0.06, -0.05 + h * 0.5), VIO if i % 2 else "B48CFF", sides=10)
    p.ball(0.28, (0, -0.02, -0.02), "F4ECF8", scale=(1, 0.85, 0.95), subdiv=3)
    p.box((0.3, 0.25, 0.16), (0, -0.02, -0.26), "F4ECF8", bevel=0.05)
    for sx in (-1, 1):
        p.ball(0.08, (sx * 0.11, -0.22, 0.0), VIO_D, scale=(1, 0.5, 1.1), subdiv=2)
    p.box((0.05, 0.05, 0.08), (0, -0.25, -0.12), VIO_D)
    for i in range(3):
        p.box((0.04, 0.04, 0.08), ((i - 1) * 0.09, -0.16, -0.32), VIO_D)


def ui_boost(p):
    """Sanduhr mit Blitz: Zeitschub."""
    for z in (0.38, -0.38):
        p.cyl(0.3, 0.08, (0, 0, z), "B9733A", bevel=0.02)
    for sx in (-1, 1):
        p.cyl(0.03, 0.72, (sx * 0.24, 0, 0), "7A4522", sides=8)
    p.cyl(0.2, 0.34, (0, 0, 0.17), "DFF4FF", r2=0.03, sides=16)
    p.cyl(0.2, 0.34, (0, 0, -0.17), "DFF4FF", r2=0.03, sides=16, r=rot(180, 0, 0))
    p.cyl(0.14, 0.12, (0, 0, -0.27), YEL, r2=0.08, sides=16)
    prism(p, [(0.0, 0.2), (0.12, 0.2), (0.04, 0.02), (0.14, 0.02), (-0.04, -0.24), (0.0, -0.04), (-0.1, -0.04)], 0.08, (0.32, -0.12, 0.05), ORANGE, bevel=0.015, segs=1)


UI = dict(season=(ui_season, FLAT), wardrobe=(ui_wardrobe, FLAT), event=(ui_event, (-20, 14)), news=(ui_news, (-18, 10)),
          calendar=(ui_calendar, (-18, 12)), prestige=(ui_prestige, FLAT), nightmare=(ui_nightmare, (-16, 10)), boost=(ui_boost, (-20, 12)))


def ui_icon(k):
    fn, (yaw, pitch) = UI[k]
    p = Part()
    fn(p)
    scale_all(p, 0.5)
    zmin = min(v.co.z for v in p.bm.verts)
    for v in p.bm.verts:
        v.co.z -= zmin
    toon(p, 0.82, 1.1)
    reset()
    root = empty("ui_" + k)
    p.build("body", root)
    save("ui_" + k)
    icon("ui_" + k, 128, yaw=yaw, pitch=pitch, margin=1.08)


PROPS = dict(lo_pumpkin=lo_pumpkin, lo_pumpkins=lo_pumpkins, lo_pumpkin_hat=lo_pumpkin_hat, lo_gift=lo_gift, lo_gifts=lo_gifts,
             lo_xmas_tree=lo_xmas_tree, lo_snowman=lo_snowman, lo_snowpile=lo_snowpile)


def prop(name):
    reset()
    root = empty(name)
    if name.startswith("lo_egg_"):
        egg(root, int(name[-1]))
    elif name.startswith("lo_wskin_"):
        wskin(root, name[9:])
    else:
        PROPS[name](root)
    save(name)
    icon(name, 160, yaw=-28, pitch=18, margin=1.08)


def all_names():
    out = ["lo_flag_" + k for k in FLAGS] + ["lo_hat_" + k for k in HATS] + ["lo_bskin_" + k for k in BSKINS]
    out += list(PROPS.keys()) + ["lo_egg_%d" % i for i in EGG_COLS] + ["lo_wskin_" + k for k in WSKIN_COLS] + ["ui_" + k for k in UI]
    return out


def make(name):
    if name.startswith("lo_flag_"):
        flag(name[8:])
    elif name.startswith("lo_hat_"):
        hat(name[7:])
    elif name.startswith("lo_bskin_"):
        bskin(name[9:])
    elif name.startswith("ui_"):
        ui_icon(name[3:])
    else:
        prop(name)


if __name__ == "__main__":
    for n in (sys.argv[1:] or all_names()):
        make(n)
        print("ok", n, flush=True)
