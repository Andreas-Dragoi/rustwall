"""V6 Paket B (Basis- und Flut-Tiefe): Modelle und Symbole.
  wall_dmg_<0..2>_<1|2>  Schaden über einem Mauerpfosten (Bauart Holz/Stein/Metall; 1 = leicht: Ruß, Risse, ein paar Brocken;
                         2 = schwer: dazu Löcher, abgeplatzte Kappe, Trümmer, Notbrett). Ein Mesh `body`, wird per MultiMesh gezeichnet.
  fx_ladder              Sturmleiter der Belagerer: 2,6 m, Ursprung am Fuß in der Mitte, lange Achse = oben (Z).
  c_bandage              Kopfverband verletzter Bewohner (hängt am Knochen `head`, Ursprung = Kopfgelenk wie in heroes.py).
  ui_research, ui_replay, ui_rain, ui_fog, ui_moon, ui_sun   Symbole (128 px, Stil wie ui_icons.py)
Aufruf: python3 blender/basis6.py [namen...]   (ohne Namen: alle)"""
import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from def_kit import *
from weapons import prism, sweep, arc, arc2, toon, scale_all, star, Y as YCYL
from weapons import BLUE, BLUE_L, BLUE_D, YEL, YEL_L, ORG, RED as WRED, GRN, GRN_D, WHITE, GREY, GREY_L, DGREY, CYAN
import weapons
from ui_icons import D as DISC, gleam, FLAT, SOLID

# Maße der Mauerpfosten aus def_walls.py: halbe Breite, Höhe des Schafts, Farben
POST = [
    {"hw": 0.23, "h": 1.95, "cols": (WOOD, WOOD_D, "BE7638"), "deb": ("BE7638", WOOD_D, WOOD_L)},
    {"hw": 0.45, "h": 2.2, "cols": (ST, ST_D, ST_L), "deb": (ST, ST_D, ST_L)},
    {"hw": 0.5, "h": 2.6, "cols": ("5F74A6", METAL_D, METAL_L), "deb": (METAL, METAL_D, STEEL)},
]


def wall_dmg(tier, stage):
    rng = rng_for("wall_dmg_%d_%d" % (tier, stage))
    c = POST[tier]
    hw, h = c["hw"], c["h"]
    B = Part()
    # Ruß und Risse auf den vier Seiten des Pfostens (knapp vor der Fläche)
    for i in range(4):
        m = rot(0, 0, i * 90) @ T(0, -hw - 0.012, 0)
        if i in (0, 1) or stage == 2:
            soot(B, m @ T(rng.uniform(-hw * 0.3, hw * 0.3), 0, rng.uniform(h * 0.3, h * 0.7)), hw * rng.uniform(0.45, 0.7), rng.uniform(0.22, 0.36))
        pts = [(rng.uniform(-hw * 0.4, hw * 0.4), h * rng.uniform(0.75, 0.9))]
        for k in range(3 if stage == 1 else 5):
            x, z = pts[-1]
            pts.append((max(-hw * 0.8, min(hw * 0.8, x + rng.uniform(-hw * 0.5, hw * 0.5))), z - rng.uniform(0.18, 0.32)))
        crack(B, m, pts, w=0.035 if tier == 0 else 0.05)
    # Brocken und Splitter am Fuß
    pts = []
    for k in range(5 if stage == 1 else 10):
        a = rng.uniform(0, math.tau)
        r = hw + rng.uniform(0.15, 0.55 if stage == 1 else 0.8)
        pts.append((math.cos(a) * r, math.sin(a) * r, 0.0))
    debris(B, pts, rng, cols=c["deb"], s=0.13 if tier == 0 else 0.18)
    soot_flat(B, (0.05, 0.04, 0.012), hw + 0.45, hw + 0.38, color="3A3A42", yaw=rng.uniform(0, 90))
    if stage == 2:
        # Loch (dunkle Aussparung) vorn und rechts, abgeplatzte Ecke oben, Notbrett quer
        for i in (0, 1):
            m = rot(0, 0, i * 90) @ T(0, -hw - 0.014, 0)
            B.box((hw * 0.7, 0.03, 0.34), (0, 0, 0), "1A1C24", r=m @ T(rng.uniform(-hw * 0.2, hw * 0.2), 0, h * 0.45) @ rot(0, rng.uniform(-14, 14), 0), bevel=0.01, segs=1)
            B.box((hw * 0.5, 0.035, 0.2), (0, 0, 0), "2A2C36", r=m @ T(hw * 0.25, -0.004, h * 0.62) @ rot(0, 30, 0))
        k = 0.2 if tier == 0 else 0.3
        B.box((k * 1.4, k * 1.1, k * 0.7), (hw * 0.9, -hw - 0.35, k * 0.35), c["deb"][1], r=rot(12, 8, 35), bevel=0.04, segs=1)
        board = WOOD_L if tier > 0 else "D9A05A"
        B.box((hw * 2.6, 0.06, 0.16), (0, 0, 0), board, r=T(0, -hw - 0.06, h * 0.55) @ rot(0, 18, 0), bevel=0.015, segs=1)
        for sx in (-1, 1):
            B.box((0.05, 0.05, 0.05), (0, 0, 0), STEEL_L, r=T(sx * hw * 0.95, -hw - 0.1, h * 0.55 + sx * hw * 0.32))
    reset()
    root = empty("wall_dmg_%d_%d" % (tier, stage))
    B.build("body", root)
    finish("wall_dmg_%d_%d" % (tier, stage), limit=700, ao=False, do_icon=False)


def ladder_model():
    B = Part()
    ladder(B, (0, 0, 0.02), (0, 0, 2.6), w=0.56, color=WOOD, rung=WOOD_L, th=0.075, step=0.36)
    for sx in (-1, 1):                                                           # Eisenkappen an den Holmen
        B.box((0.1, 0.1, 0.08), (sx * 0.28, 0, 2.6), STEEL, bevel=0.02, segs=1)
        B.box((0.1, 0.1, 0.06), (sx * 0.28, 0, 0.04), DARK, bevel=0.02, segs=1)
    for z in (0.7, 1.9):                                                         # Seilwicklungen
        for sx in (-1, 1):
            B.cyl(0.06, 0.08, (sx * 0.28, 0, z), ROPE, sides=8)
    reset()
    root = empty("fx_ladder")
    B.build("body", root)
    finish("fx_ladder", limit=1500, ao=False, yaw=-30.0, pitch=18.0, size=192)


def bandage_model():
    # Kopf der Figuren (heroes.py): x -0,30…0,30, y -0,30 (Gesicht) … 0,24, z 0 … 0,54 über dem Kopfgelenk; Helm ab z 0,42
    V = 0.06
    W = "F7F4EC"
    B = Part()
    z = 0.39
    th = 0.035
    x0, x1, y0, y1 = -0.33, 0.33, -0.335, 0.275
    B.box((x1 - x0, th, 0.09), ((x0 + x1) * 0.5, y0, z), W, bevel=0.012, segs=1)
    B.box((x1 - x0, th, 0.09), ((x0 + x1) * 0.5, y1, z), W, bevel=0.012, segs=1)
    B.box((th, y1 - y0, 0.09), (x0, (y0 + y1) * 0.5, z), W, bevel=0.012, segs=1)
    B.box((th, y1 - y0, 0.09), (x1, (y0 + y1) * 0.5, z), W, bevel=0.012, segs=1)
    # Knoten mit zwei Enden hinten
    B.ball(0.05, (0.08, y1 + 0.03, z), W, subdiv=1)
    B.box((0.05, 0.02, 0.16), (0, 0, 0), W, r=T(0.03, y1 + 0.05, z - 0.08) @ rot(0, 22, 0))
    B.box((0.05, 0.02, 0.14), (0, 0, 0), W, r=T(0.13, y1 + 0.05, z - 0.07) @ rot(0, -18, 0))
    # roter Fleck vorn rechts
    B.box((0.07, 0.01, 0.05), (0.16, y0 - 0.02, z + 0.005), "D8434A", bevel=0.01, segs=1)
    # Pflaster-Kreuz oben auf dem Helm und an der Wange
    for a in (45, -45):
        B.box((0.42, 0.1, 0.022), (0, 0, 0), W, r=T(0.02, -0.04, 0.672) @ rot(0, 0, a), bevel=0.01, segs=1)
    B.box((0.07, 0.07, 0.01), (0, 0, 0), "D8434A", r=T(0.02, -0.04, 0.686) @ rot(0, 0, 45))
    for a in (40, -40):
        B.box((0.14, 0.012, 0.045), (0, 0, 0), W, r=T(-0.16, -0.31, 0.16) @ rot(0, a, 0), bevel=0.005, segs=1)
    reset()
    root = empty("c_bandage")
    B.build("body", root)
    finish("c_bandage", limit=800, ao=False, yaw=-30.0, pitch=20.0, size=128)


# ------------------------------------------------------------------ Symbole (Einheitsraum, Symbolfläche X-Z)
def i_research(p):
    """Erlenmeyerkolben: unten grüne Flüssigkeit, oben Glas, Blasen steigen auf."""
    p.cyl(0.36, 0.26, (0, 0, -0.3), GRN, r2=0.26, sides=24, bevel=0.03, segs=2)
    p.cyl(0.36, 0.03, (0, 0, -0.44), GRN_D, sides=24)
    p.cyl(0.26, 0.26, (0, 0, -0.04), "CFE8FF", r2=0.12, sides=24)
    p.cyl(0.11, 0.24, (0, 0, 0.2), "CFE8FF", sides=18)
    p.cyl(0.14, 0.06, (0, 0, 0.33), GREY_L, sides=18, bevel=0.015, segs=1)
    for (x, z, r) in ((-0.08, 0.42, 0.045), (0.05, 0.53, 0.06), (-0.02, 0.67, 0.075)):
        p.ball(r, (x, -0.02, z), "9BF5A8", subdiv=2)
    for (x, z, r) in ((-0.14, -0.3, 0.045), (0.12, -0.24, 0.035), (0.0, -0.36, 0.04)):
        p.ball(r, (x, -0.3, z), "C8FFD0", subdiv=1)
    gleam(p, -0.14, -0.02, -0.2, 0.04, 0.1, a=-20)


def i_replay(p):
    """Karte mit rotem Kreuz und Rückspul-Pfeil."""
    p.box((0.72, 0.06, 0.6), (-0.04, 0.02, -0.06), "FFF2D0", bevel=0.03, segs=1)
    for (x, z, w) in ((-0.22, 0.1, 0.18), (0.1, -0.2, 0.22), (-0.15, -0.25, 0.14)):
        p.box((w, 0.02, 0.05), (x, -0.02, z), "B8D08A", bevel=0.01, segs=1)
    for a in (45, -45):
        p.box((0.24, 0.04, 0.06), (0, 0, 0), WRED, r=T(0.12, -0.04, 0.06) @ rot(0, a, 0), bevel=0.012, segs=1)
    pts = arc(-0.02, 0.06, 0.46, 200, 340, 14, y=-0.08)
    sweep(p, pts, 0.055, BLUE, sides=8, ref=(0, 1, 0))
    tip = pts[0]
    prism(p, [(-0.11, 0.0), (0.11, 0.0), (0.0, 0.16)], 0.1, (tip[0], -0.08, tip[2]), BLUE, r=rot(0, 60, 0), bevel=0.02, segs=1)


def cloud(p, z0, col=GREY_L):
    for (x, z, r) in ((-0.22, z0, 0.2), (0.0, z0 + 0.1, 0.26), (0.24, z0 + 0.02, 0.19), (0.05, z0 - 0.06, 0.2)):
        p.ball(r, (x, 0, z), col, scale=(1, 0.65, 1), subdiv=2)


def i_rain(p):
    cloud(p, 0.22, "D9E2F2")
    for (x, z) in ((-0.22, -0.2), (0.04, -0.3), (0.26, -0.18)):
        p.ball(0.07, (x, -0.02, z), BLUE_L, scale=(1, 0.7, 1.25), subdiv=2)
        p.cone(0.066, 0.12, (x, -0.02, z + 0.1), BLUE_L, sides=10)


def i_fog(p):
    cloud(p, 0.24, "C5CEDF")
    for k, z in enumerate((-0.08, -0.24, -0.4)):
        x0 = -0.4 + 0.08 * (k % 2)
        p.box((0.72, 0.08, 0.07), (x0 + 0.36, -0.04, z), "AEB8CC", bevel=0.03, segs=2)


def i_moon(p):
    """Mondsichel aus schmalen Vierecken (jedes für sich konvex), dazu zwei Sterne."""
    n = 16
    for i in range(n):
        a0 = math.radians(70 + 220.0 * i / n)
        a1 = math.radians(70 + 220.0 * (i + 1) / n)
        def inner(a):
            # innere Kante: Kreis um (0,18 | 0) mit Radius 0,34, auf den Winkel des äußeren Kreises abgebildet
            return (0.16 + 0.3 * math.cos(a), 0.36 * math.sin(a))
        o0 = (0.42 * math.cos(a0), 0.42 * math.sin(a0))
        o1 = (0.42 * math.cos(a1), 0.42 * math.sin(a1))
        i0 = inner(a0)
        i1 = inner(a1)
        t = abs(math.sin((a0 + a1) * 0.5 - math.radians(180)))
        prism(p, [o0, o1, i1, i0], 0.16 if t < 0.95 else 0.18, (0, 0, 0), YEL, segs=1)
    star(p, 0.1, 0.06, (0.3, -0.04, 0.3), YEL_L, n=4, inner=0.4)
    star(p, 0.07, 0.05, (0.36, -0.04, -0.12), YEL_L, n=4, inner=0.4)


def i_sun(p):
    DISC(p, 0.26, 0.16, 0, 0, YEL, bevel=0.04, segs=2)
    for i in range(8):
        a = i * 45.0
        prism(p, [(-0.07, 0.0), (0.07, 0.0), (0.0, 0.14)], 0.1, (0, 0, 0), ORG, r=rot(0, -a, 0) @ T(0, 0, 0.32), bevel=0.02, segs=1)
    gleam(p, -0.1, 0.12, -0.09, 0.07, 0.03)


ICONS = dict(research=(i_research, (-14, 8)), replay=(i_replay, FLAT), rain=(i_rain, FLAT), fog=(i_fog, FLAT), moon=(i_moon, FLAT), sun=(i_sun, FLAT))


def make_icon(name):
    fn, (yaw, pitch) = ICONS[name]
    p = Part()
    fn(p)
    scale_all(p, 0.5)
    zmin = min(v.co.z for v in p.bm.verts)
    for v in p.bm.verts:
        v.co.z -= zmin
    toon(p, 0.82, 1.1)
    reset()
    root = empty("ui_" + name)
    p.build("body", root)
    save("ui_" + name)
    icon("ui_" + name, 128, yaw=yaw, pitch=pitch, margin=1.08)


TABLE = {}
for _t in range(3):
    for _s in (1, 2):
        TABLE["wall_dmg_%d_%d" % (_t, _s)] = (lambda t=_t, s=_s: wall_dmg(t, s))
TABLE["fx_ladder"] = ladder_model
TABLE["c_bandage"] = bandage_model
for _n in ICONS:
    TABLE["ui_" + _n] = (lambda n=_n: make_icon(n))

if __name__ == "__main__":
    run(TABLE, sys.argv)
