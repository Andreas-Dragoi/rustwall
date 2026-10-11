"""Rustwall V3 – neue Modelle für Etappe A: Tore (drei Bauarten), Mauer-Baustelle, Trainingsplatz, Juwel.
Aufruf: python3 blender/v3_assets.py [namen...]"""
import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from buildings import *


def tor(tier):
    """Tor über zwei Felder (4 m entlang X). Flügel door_l / door_r haben ihren Ursprung am Scharnier."""
    name = "b_tor_%d" % tier
    root, B, G = start(name)
    if tier == 0:
        post, cap, leaf, band, roofc = WOOD, WOOD_L, "C98A48", STEEL, RED
        pw, ph = 0.56, 3.0
    elif tier == 1:
        post, cap, leaf, band, roofc = ST, ST_D, WOOD, STEEL, BLUE
        pw, ph = 0.8, 3.3
    else:
        post, cap, leaf, band, roofc = "5F74A6", GOLD, "7286B8", GOLD, "3F4F7A"
        pw, ph = 0.9, 3.6
    for s in (-1, 1):
        x = s * (2.0 - pw * 0.5)
        B.box((pw, pw + 0.3, ph), (x, 0, ph * 0.5), post, bevel=0.12)
        B.box((pw + 0.16, pw + 0.46, 0.26), (x, 0, 0.13), shade(post, 0.8), bevel=0.06, segs=1)
        B.box((pw + 0.14, pw + 0.44, 0.22), (x, 0, ph - 0.1), cap, bevel=0.06, segs=1)
        if tier == 1:
            for (dy, z, w) in ((-1, 0.9, 0.5), (1, 1.6, 0.4), (-1, 2.2, 0.36), (1, 0.7, 0.44)):
                B.box((w, 0.06, 0.24), (x, dy * (pw * 0.5 + 0.15), z), ST_L, bevel=0.03, segs=1)
        if tier == 2:
            for z in (0.8, 1.6, 2.4):
                for dy in (-1, 1):
                    B.cyl(0.07, 0.06, (x, dy * (pw * 0.5 + 0.16), z), "C9D0DE", r=rot(90, 0, 0), sides=6)
    # Querbalken und kleines Dach
    B.box((4.2, 0.5, 0.36), (0, 0, ph + 0.12), shade(post, 0.9), bevel=0.08, segs=1)
    gable(B, (0, 0, ph + 0.3), 4.0, 1.5, 0.62, roofc, over=0.22, thick=0.16, fill=shade(roofc, 0.8))
    if tier == 2:
        gold_band(B, (4.24, 0.56, 0.12), (0, 0, ph + 0.02))
    # Schild über der Durchfahrt
    B.box((0.9, 0.1, 0.5), (0, -0.3, ph - 0.36), CREAM, bevel=0.05, segs=1)
    star(B, (0, -0.36, ph - 0.36), 0.18, BLUE, 0.05)
    # Laternen: grün = offen, rot = zu
    for s, nm, c in ((-1, "lamp_open_glow", "58E86A"), (1, "lamp_closed_glow", "FF5A4A")):
        B.box((0.3, 0.3, 0.1), (s * 1.2, -0.42, ph - 0.12), DK, bevel=0.03, segs=1)
        g = Part()
        g.box((0.22, 0.22, 0.28), (s * 1.2, -0.42, ph - 0.32), c, bevel=0.06)
        g.build(nm, root)
    # Flügel
    inner = 2.0 - pw
    for s, nm in ((-1, "door_l"), (1, "door_r")):
        d = Part()
        w = inner - 0.04
        cx = -s * w * 0.5
        h = ph - 0.75
        d.box((w, 0.16, h), (cx, 0, h * 0.5 + 0.12), leaf, bevel=0.05, segs=1)
        if tier < 2:
            n = 4
            for i in range(n):                      # Bretterfugen
                d.box((0.03, 0.18, h - 0.1), (cx - w * 0.5 + (i + 1) * w / (n + 1), 0, h * 0.5 + 0.12), shade(leaf, 0.72))
        for z in (0.5, h - 0.25):
            d.box((w + 0.02, 0.2, 0.14), (cx, 0, z + 0.12), band, bevel=0.03, segs=1)
        beam(d, (cx - w * 0.42, -0.1, 0.55), (cx + w * 0.42, -0.1, h - 0.2), 0.1, shade(leaf, 0.8), d=0.06)
        d.cyl(0.07, 0.1, (-s * (w - 0.18), -0.12, h * 0.5), GOLD, r=rot(90, 0, 0), sides=8)
        if tier == 2:
            for z in (0.9, 1.7):
                d.box((w * 0.7, 0.2, 0.3), (cx, 0, z + 0.12), "8FA4D6", bevel=0.04, segs=1)
        d.build(nm, root, (s * inner, 0, 0))
    flag(root, B, (-1.9 + pw * 0.2, 0, ph + 0.2), h=1.5, size=(0.8, 0.52))
    B.build("body", root)
    empty("bubble", root, (0, 0, ph + 1.6))
    finish(name, hide=("lamp_closed",))


def wall_site():
    """Gerüst um ein Mauerstück im Bau (1 Feld)."""
    reset()
    B = Part()
    for sx in (-1, 1):
        for sy in (-1, 1):
            B.cyl(0.06, 2.3, (0.8 * sx, 0.55 * sy, 1.15), WOOD_L, sides=6)
    for sy in (-1, 1):
        B.box((1.8, 0.07, 0.1), (0, 0.55 * sy, 2.0), WOOD_D)
        B.box((1.8, 0.07, 0.1), (0, 0.55 * sy, 1.0), WOOD_D)
        beam(B, (-0.8, 0.55 * sy, 1.0), (0.8, 0.55 * sy, 2.0), 0.06, WOOD_D, d=0.06)
    B.box((1.7, 1.2, 0.07), (0, 0, 2.08), "D9A05A", bevel=0.02, segs=1)
    B.box((0.5, 0.36, 0.3), (0.4, 0.2, 2.26), "E0A82E", bevel=0.04, segs=1)
    for s in (-1, 1):                                  # gelb-schwarzes Band
        for i in range(6):
            B.box((0.28, 0.03, 0.1), (-0.7 + i * 0.28, 0.6 * s, 0.6), "F2B92E" if i % 2 == 0 else "23262E")
    B.build("body")
    finish("wall_site")


def training():
    """Trainingsplatz 3x3: Sandplatz mit Zaun, Übungspuppen, Zielscheibe, Hanteln, Unterstand."""
    root, B, G = start("b_training")
    base(B, 5.5, 5.5, "E2C58A", 0.16)
    B.box((4.6, 4.6, 0.08), (0, 0, 0.2), "EBD79A", bevel=0.03, segs=1)
    # Zaun rundum, vorn offen
    for i in range(7):
        t = -2.55 + i * 0.85
        for (x, y) in ((t, 2.55), (-2.55, t), (2.55, t)):
            B.box((0.14, 0.14, 0.95), (x, y, 0.62), WOOD, bevel=0.04, segs=1)
        if abs(t) > 0.9:
            B.box((0.14, 0.14, 0.95), (t, -2.55, 0.62), WOOD, bevel=0.04, segs=1)
    for z in (0.5, 0.9):
        B.box((5.2, 0.08, 0.12), (0, 2.55, z), WOOD_L)
        B.box((0.08, 5.2, 0.12), (-2.55, 0, z), WOOD_L)
        B.box((0.08, 5.2, 0.12), (2.55, 0, z), WOOD_L)
        for s in (-1, 1):
            B.box((1.6, 0.08, 0.12), (s * 1.75, -2.55, z), WOOD_L)
    # Unterstand hinten links
    for (x, y) in ((-2.1, 2.1), (-0.5, 2.1), (-2.1, 0.9), (-0.5, 0.9)):
        B.cyl(0.08, 2.2, (x, y, 1.3), WOOD_D, sides=8)
    gable(B, (-1.3, 1.5, 2.4), 2.0, 1.7, 0.6, BLUE, over=0.2, thick=0.14, fill=shade(BLUE, 0.8))
    B.box((1.5, 0.5, 0.1), (-1.3, 1.9, 0.75), WOOD_L, bevel=0.03, segs=1)                 # Bank
    for x in (-1.9, -0.7):
        B.box((0.1, 0.4, 0.5), (x, 1.9, 0.48), WOOD_D)
    # Hantelständer
    B.box((1.2, 0.4, 0.1), (-1.3, 1.1, 0.6), STEEL, bevel=0.03, segs=1)
    for x in (-1.7, -1.3, -0.9):
        B.cyl(0.05, 0.5, (x, 1.1, 0.78), DK, r=rot(90, 0, 0), sides=8)
        for s in (-1, 1):
            B.cyl(0.16, 0.1, (x, 1.1 + 0.22 * s, 0.78), RED if x < -1.4 else (BLUE_L if x < -1.0 else GOLD), r=rot(90, 0, 0), sides=10)
    # zwei Übungspuppen (eine dreht sich)
    def dummy(p, loc):
        x, y, z = loc
        p.cyl(0.08, 1.5, (x, y, z + 0.75), WOOD_D, sides=8)
        p.cyl(0.3, 0.7, (x, y, z + 1.15), "D9B37A", sides=10, bevel=0.1)
        p.ball(0.24, (x, y, z + 1.75), "E6D2A4", subdiv=2)
        p.box((1.2, 0.12, 0.12), (x, y, z + 1.3), WOOD, bevel=0.03, segs=1)
        p.cyl(0.32, 0.08, (x, y - 0.3, z + 1.15), RED, r=rot(90, 0, 0), sides=12)
        p.cyl(0.18, 0.1, (x, y - 0.31, z + 1.15), "white", r=rot(90, 0, 0), sides=12)
    dummy(B, (1.4, 1.5, 0.2))
    B.cyl(0.3, 0.14, (1.4, 1.5, 0.27), ST_D, sides=10)
    sp = Part()
    dummy(sp, (0, 0, 0))
    sp.build("spin_dummy", root, (0.4, -0.4, 0.24))
    B.cyl(0.34, 0.16, (0.4, -0.4, 0.28), ST_D, sides=10)
    # Zielscheibe mit Pfeilen
    for s in (-1, 1):
        beam(B, (1.9 + 0.3 * s, 0.2, 0.2), (1.9, 0.0, 1.7), 0.08, WOOD_D, d=0.08)
    for (rr, c, o) in ((0.6, "white", 0.0), (0.44, RED, 0.02), (0.28, "white", 0.04), (0.13, RED, 0.06)):
        B.cyl(rr, 0.1, (1.9, -0.12 - o, 1.35), c, r=rot(90, 0, 0), sides=16)
    for (dx, dz) in ((0.05, 0.03), (-0.2, 0.18)):
        B.cyl(0.02, 0.5, (1.9 + dx, -0.45, 1.35 + dz), WOOD_L, r=rot(90, 0, 0), sides=6)
        B.box((0.1, 0.06, 0.1), (1.9 + dx, -0.7, 1.35 + dz), RED)
    # Sandsack am Galgen (schwingt)
    B.cyl(0.09, 2.6, (-1.9, -1.2, 1.5), WOOD_D, sides=8)
    B.box((1.0, 0.12, 0.12), (-1.45, -1.2, 2.7), WOOD_D)
    sw = Part()
    sw.cyl(0.02, 0.6, (0, 0, -0.3), DK, sides=6)
    sw.cyl(0.26, 0.95, (0, 0, -1.05), RED_D, sides=12, bevel=0.1)
    sw.box((0.56, 0.56, 0.1), (0, 0, -0.9), GOLD, bevel=0.03, segs=1)
    sw.build("sway_bag", root, (-1.1, -1.2, 2.65))
    crate(B, (2.0, -1.9, 0.2), 0.6, WOOD, 15)
    barrel(B, (-2.0, -2.0, 0.2), BLUE)
    flag(root, B, (2.3, 2.3, 0.2), h=3.0)
    B.build("body", root)
    empty("door", root, (0, -2.9, 0))
    empty("work_1", root, (0.4, -1.4, 0))
    empty("work_2", root, (1.9, -1.2, 0))
    empty("bubble", root, (0, 0, 4.2))
    finish("b_training")


def gem():
    """Juwel als Symbol (icons/res_gems.png)."""
    reset()
    p = Part()
    c1, c2, c3 = "4FB8FF", "2A86E8", "BFE8FF"
    p.cone(0.5, 0.62, (0, 0, -0.31), c2, r=rot(180, 0, 22.5), sides=8)
    p.cyl(0.5, 0.2, (0, 0, 0.1), c1, r=rot(0, 0, 22.5), r2=0.32, sides=8)
    p.cyl(0.32, 0.03, (0, 0, 0.21), c3, r=rot(0, 0, 22.5), sides=8)
    ob = p.build("body", sharp_angle=5.0)
    save("res_gems")
    icon("res_gems", 256, yaw=20, pitch=38)
    os.remove(os.path.join(OUT_GLB, "res_gems.glb"))


MODELS3 = {"b_tor_0": lambda: tor(0), "b_tor_1": lambda: tor(1), "b_tor_2": lambda: tor(2), "wall_site": wall_site, "b_training": training, "res_gems": gem}

if __name__ == "__main__":
    for n in (sys.argv[1:] or list(MODELS3)):
        MODELS3[n]()
