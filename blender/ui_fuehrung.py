"""Symbole für Spielerführung und Komfort (Paket F): Zeigefinger des Tutorials, Hilfe, Bau-Warteschlange, Akku.
Gleicher Stil wie ui_icons.py (ui_<name>, 128 px, ein Objekt `body`).
Aufruf: python3 blender/ui_fuehrung.py [ui_finger ...]   (ohne Namen: alle)"""
import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from kit import *
from weapons import prism, sweep, arc, toon, tris, scale_all, Y, args, BLUE, BLUE_L, BLUE_D, YEL, YEL_L, ORG, GRN, GRN_D, RED, WHITE, GREY, GREY_L, DGREY, HOLE
from ui_icons import X, D, gleam, FLAT

GLOVE, GLOVE_D = "FFFFFF", "D9E2F2"


def finger(p):
    """Weißer Comic-Handschuh, Zeigefinger zeigt nach oben (Spitze oben in der Mitte)."""
    p.box((0.46, 0.3, 0.4), (0.02, 0, -0.16), GLOVE, bevel=0.13, segs=3)                         # Handfläche
    p.cyl(0.085, 0.5, (-0.08, -0.01, 0.22), GLOVE, bevel=0.08, segs=3, sides=16)                  # Zeigefinger
    for i, x in enumerate((0.05, 0.15, 0.24)):                                                    # eingerollte Finger
        p.ball(0.085, (x, -0.13, 0.03 - i * 0.03), GLOVE_D, scale=(1, 0.9, 0.8), subdiv=2)
    p.box((0.13, 0.16, 0.3), (-0.27, -0.05, -0.08), GLOVE, r=rot(0, -35, 0), bevel=0.06, segs=2)   # Daumen
    p.cyl(0.25, 0.14, (0.02, 0, -0.42), YEL, bevel=0.05, segs=2, sides=20)                        # Stulpe
    p.cyl(0.26, 0.04, (0.02, 0, -0.36), ORG, bevel=0.01, segs=1, sides=20)
    for i in range(3):                                                                            # Nähte auf dem Rücken
        p.box((0.02, 0.02, 0.18), (-0.04 + i * 0.1, -0.155, -0.2), GLOVE_D, bevel=0.008, segs=1)
    gleam(p, -0.12, 0.36, -0.09, 0.03, 0.08, a=0)


def help_sign(p):
    """Blaue Kugel mit weißem Fragezeichen."""
    D(p, 0.48, 0.24, 0, 0, BLUE, bevel=0.07, segs=3)
    pts = arc(0.0, 0.14, 0.14, 170, -60, 10, y=-0.13) + [(0.02, -0.13, -0.06)]
    sweep(p, pts, 0.055, WHITE, sides=10, ref=(0, 1, 0))
    p.ball(0.065, (0.02, -0.13, -0.24), WHITE, scale=(1, 0.6, 1), subdiv=2)
    gleam(p, -0.26, 0.26, -0.125, 0.1, 0.03, color=BLUE_L)


def queue(p):
    """Klemmbrett mit drei Zeilen und einer kleinen Uhr: vorgemerkte Bauaufträge."""
    p.box((0.62, 0.1, 0.82), (-0.06, 0.04, 0), "B8742F", bevel=0.04, segs=2)
    p.box((0.52, 0.04, 0.68), (-0.06, -0.02, -0.04), "FFF2D0", bevel=0.015, segs=1)
    p.box((0.26, 0.08, 0.1), (-0.06, -0.03, 0.4), GREY_L, bevel=0.03, segs=1)
    for i in range(3):
        z = 0.18 - i * 0.2
        p.box((0.08, 0.03, 0.08), (-0.24, -0.05, z), GRN if i == 0 else BLUE, bevel=0.02, segs=1)
        p.box((0.28, 0.03, 0.05), (0.0, -0.05, z), DGREY, bevel=0.01, segs=1)
    D(p, 0.2, 0.12, 0.24, -0.3, YEL, y=-0.1, bevel=0.03, segs=2)
    D(p, 0.15, 0.13, 0.24, -0.3, WHITE, y=-0.11, sides=20)
    p.box((0.025, 0.02, 0.1), (0.24, -0.18, -0.26), HOLE)
    p.box((0.08, 0.02, 0.025), (0.27, -0.18, -0.3), HOLE)


def battery(p):
    """Grüne Batterie mit Blatt: Akku sparen."""
    p.box((0.8, 0.3, 0.46), (-0.04, 0, 0), DGREY, bevel=0.07, segs=2)
    p.box((0.68, 0.32, 0.34), (-0.04, 0, 0), "1B2A44", bevel=0.04, segs=1)
    for i in range(3):
        p.box((0.18, 0.34, 0.28), (-0.27 + i * 0.22, 0, 0), GRN, bevel=0.03, segs=1)
    p.box((0.08, 0.2, 0.2), (0.4, 0, 0), GREY_L, bevel=0.03, segs=1)
    prism(p, [(0.0, 0.0), (0.12, 0.08), (0.2, 0.22), (0.14, 0.3), (0.02, 0.22)], 0.05, (0.06, -0.2, 0.12), GRN_D, bevel=0.015, segs=1)
    gleam(p, -0.3, 0.16, -0.17, 0.12, 0.025, a=-90)


ALL = dict(finger=(finger, (-14, 10)), help=(help_sign, FLAT), queue=(queue, (-16, 10)), battery=(battery, (-20, 12)))


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
