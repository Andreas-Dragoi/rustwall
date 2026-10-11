"""Gebäude, Fallen, Deko und Mauern für Rustwall. Vorderseite = -Y, Ursprung am Boden in der Mitte der Grundfläche.
Aufruf: python3 blender/buildings.py [namen...]   (ohne Namen: alles bauen)
Je Modell: statische Teile in `body`, Fenster/Lampen in `win_glow`, dazu die Sonderobjekte laut README
(spin_*, bob_*, sway_*, pulse_*, lvN_*, Leerobjekte fx_*)."""
import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from kit import *

ST, ST_D, ST_L = "AEB6D2", "8690B0", "C6CDE4"       # blaugrauer Stein
BLUE, BLUE_L, BLUE_D = "3B6FD0", "5B93EE", "2C4F9E"  # blaues Metall
GOLD, DK, WOOD, WOOD_D, WOOD_L = "F2B92E", "363D52", "B5682F", "7A4522", "D9A05A"
RED, RED_D, OLIVE, CREAM, STEEL, STEEL_L = "E04848", "A82F3A", "8FA043", "E6D2A4", "8A94A8", "C9D0DE"
GLOW, CYAN, PURPLE, HOT = "FFD24D", "5FE3FF", "B77BFF", "FF4A3A"


# ------------------------------------------------------------------ Helfer
def T(x, y, z):
    return Matrix.Translation(Vector((x, y, z)))


def S(x, y, z):
    return Matrix.Diagonal(Vector((x, y, z, 1.0)))


def _track(a, b):
    a = Vector(a); b = Vector(b)
    d = b - a
    return (a + b) * 0.5, d.length, d.to_track_quat("Z", "Y").to_matrix().to_4x4()


def beam(p, a, b, w, color, bevel=0.0, d=None):
    """Balken (Quader) von Punkt a nach b."""
    c, l, m = _track(a, b)
    p.box((w, d or w, l), c, color, r=m, bevel=bevel, segs=1)


def tube(p, a, b, rad, color, sides=8, bevel=0.0):
    """Rohr (Zylinder) von Punkt a nach b."""
    c, l, m = _track(a, b)
    p.cyl(rad, l, c, color, r=m, sides=sides, bevel=bevel, segs=1)


def gable(p, c, w, d, h, color, over=0.3, thick=0.24, yaw=0.0, fill=None, ridge=None):
    """Satteldach. c = Mitte der Traufhöhe, w = Firstlänge, d = Spannweite, h = Dachhöhe. yaw=90: First entlang Y."""
    m0 = T(*c) @ rot(0, 0, yaw)
    pitch = math.atan2(h, d * 0.5)
    sl = math.hypot(d * 0.5, h) + over
    for s in (-1, 1):
        cy = s * math.cos(pitch) * sl * 0.5 + s * math.sin(pitch) * thick * 0.5
        cz = h - math.sin(pitch) * sl * 0.5 + math.cos(pitch) * thick * 0.5
        p.box((w + over * 2, sl, thick), (0, 0, 0), color, r=m0 @ T(0, cy, cz) @ rot(-s * math.degrees(pitch), 0, 0), bevel=0.08)
    if fill:
        p.cyl(1.0, w - 0.08, (0, 0, 0), fill, r=m0 @ rot(0, 90, 0) @ S(h, d * 0.5, 1), sides=4)
    p.cyl(0.16, w + over * 2 + 0.06, (0, 0, 0), ridge or shade(color, 0.78), r=m0 @ T(0, 0, h + thick * 0.8) @ rot(0, 90, 0), sides=8, bevel=0.05, segs=1)


def crate(p, loc, s=0.8, color=WOOD, yaw=0.0):
    x, y, z = loc
    m = rot(0, 0, yaw)
    p.box((s, s, s), (x, y, z + s * 0.5), color, r=m, bevel=0.05, segs=1)
    p.box((s * 1.04, s * 1.04, s * 0.14), (x, y, z + s * 0.5), shade(color, 0.7), r=m, bevel=0.02, segs=1)
    p.box((s * 0.8, s * 0.8, 0.04), (x, y, z + s), shade(color, 1.2), r=m)


def barrel(p, loc, color=RED, r=0.34, h=0.9):
    x, y, z = loc
    p.cyl(r, h, (x, y, z + h * 0.5), color, sides=12, bevel=0.07)
    for k in (0.28, 0.72):
        p.cyl(r + 0.025, 0.08, (x, y, z + h * k), shade(color, 0.68), sides=12)
    p.cyl(r * 0.7, 0.03, (x, y, z + h), shade(color, 1.25), sides=12)


def sandbags(p, a, dx, dy, n, rows=2):
    yaw = math.degrees(math.atan2(dy, dx))
    for r in range(rows):
        for i in range(n - r):
            k = i * 0.62 + r * 0.31
            c = shade("E8B76E", 1.0 - 0.1 * ((i + r) % 2))
            p.box((0.64, 0.4, 0.3), (a[0] + dx * k, a[1] + dy * k, 0.15 + r * 0.26 + a[2]), c, r=rot(0, 0, yaw), bevel=0.12)


def window(G, B, loc, w=0.6, h=0.7, face="f", frame=DK, bars=True):
    """Leuchtendes Fenster mit Rahmen. face: f = Vorderseite (-Y), b, l (-X), r (+X)."""
    x, y, z = loc
    if face in "fb":
        s = -1 if face == "f" else 1
        G.box((w, 0.1, h), (x, y + s * 0.02, z), GLOW, bevel=0.03, segs=1)
        B.box((w + 0.2, 0.1, h + 0.2), (x, y - s * 0.03, z), frame)
        if bars:
            B.box((0.06, 0.06, h), (x, y + s * 0.06, z), frame)
            B.box((w + 0.3, 0.2, 0.08), (x, y + s * 0.04, z - h * 0.5 - 0.1), shade(frame, 1.3))
    else:
        s = -1 if face == "l" else 1
        G.box((0.1, w, h), (x + s * 0.02, y, z), GLOW, bevel=0.03, segs=1)
        B.box((0.1, w + 0.2, h + 0.2), (x - s * 0.03, y, z), frame)
        if bars:
            B.box((0.06, 0.06, h), (x + s * 0.06, y, z), frame)
            B.box((0.2, w + 0.3, 0.08), (x + s * 0.04, y, z - h * 0.5 - 0.1), shade(frame, 1.3))


def star(p, loc, rad, color="white", thick=0.05):
    """Fünfzackiger Stern in der XZ-Ebene (zeigt nach vorn und hinten)."""
    x, y, z = loc
    rp = rad / 1.83
    p.cyl(rp, thick, loc, color, r=rot(90, 0, 0) @ rot(0, 0, 36), sides=5)   # Blender: erste Ecke eines n-Ecks liegt bei +Y
    for i in range(5):
        a = math.radians(90 + 72 * i)
        p.cyl(rp * 0.68, thick, (x + math.cos(a) * rp * 1.15, y, z + math.sin(a) * rp * 1.15), color,
              r=rot(90, 0, 0) @ rot(0, 0, 72 * i), sides=3)


def flag(root, B, loc, h=2.6, color="flag", name="sway_flag", size=(1.15, 0.78), with_star=True, pole=WOOD_D):
    """Mast in B, Tuch als eigenes sway-Objekt (Ursprung am Mast)."""
    x, y, z = loc
    B.cyl(0.07, h, (x, y, z + h * 0.5), pole, sides=8)
    B.ball(0.12, (x, y, z + h + 0.06), GOLD, subdiv=2)
    c = Part()
    w, hh = size
    c.box((w * 0.52, 0.06, hh), (w * 0.27, 0, 0), color, bevel=0.025, segs=1)
    c.box((w * 0.52, 0.06, hh * 0.94), (w * 0.74, -0.05, -0.03), shade(color, 0.9), bevel=0.025, segs=1, r=rot(0, 0, -8))
    if with_star:
        star(c, (w * 0.42, 0, 0), hh * 0.3, "white", 0.1)
    return c.build(name, root, (x + 0.06, y, z + h - hh * 0.5 - 0.08))


def chest(p, loc, s=1.0, color=GOLD, wood=WOOD, yaw=0.0):
    m = T(*loc) @ rot(0, 0, yaw) @ S(s, s, s)
    p.box((1.0, 0.7, 0.5), (0, 0, 0), wood, r=m @ T(0, 0, 0.25), bevel=0.05, segs=1)
    p.cyl(0.35, 0.97, (0, 0, 0), shade(wood, 1.12), r=m @ T(0, 0, 0.5) @ rot(0, 90, 0), sides=12, bevel=0.04, segs=1)
    for sx in (-0.36, 0.36):
        p.box((0.12, 0.74, 0.52), (0, 0, 0), color, r=m @ T(sx, 0, 0.26), bevel=0.02, segs=1)
        p.cyl(0.37, 0.12, (0, 0, 0), color, r=m @ T(sx, 0, 0.5) @ rot(0, 90, 0), sides=12)
    p.box((0.2, 0.1, 0.24), (0, 0, 0), color, r=m @ T(0, -0.36, 0.48), bevel=0.03, segs=1)
    p.box((1.03, 0.73, 0.06), (0, 0, 0), color, r=m @ T(0, 0, 0.5), bevel=0.02, segs=1)


def gear(p, rad, thick, color, teeth=10, hub=DK):
    """Zahnrad um die lokale Z-Achse im Ursprung."""
    p.cyl(rad, thick, (0, 0, 0), color, sides=20, bevel=0.03, segs=1)
    for i in range(teeth):
        a = 360.0 * i / teeth
        p.box((rad * 0.34, rad * 0.3, thick), (math.cos(math.radians(a)) * rad * 1.08, math.sin(math.radians(a)) * rad * 1.08, 0), color,
              r=rot(0, 0, a), bevel=0.03, segs=1)
    p.cyl(rad * 0.62, thick + 0.04, (0, 0, 0), shade(color, 0.72), sides=16)
    p.cyl(rad * 0.24, thick + 0.12, (0, 0, 0), hub, sides=10, bevel=0.02, segs=1)


def chimney(root, B, loc, h=1.4, r=0.26, color="8A5A4A", fx="fx_smoke", square=False):
    x, y, z = loc
    if square:
        B.box((r * 2, r * 2, h), (x, y, z + h * 0.5), color, bevel=0.06, segs=1)
        B.box((r * 2 + 0.16, r * 2 + 0.16, 0.18), (x, y, z + h - 0.06), shade(color, 0.75), bevel=0.04, segs=1)
    else:
        B.cyl(r, h, (x, y, z + h * 0.5), color, sides=12, r2=r * 0.86)
        B.cyl(r + 0.05, 0.16, (x, y, z + h - 0.06), shade(color, 0.7), sides=12, bevel=0.03, segs=1)
    B.cyl(r * 0.6, 0.04, (x, y, z + h + 0.03), "181A22", sides=10)
    empty(fx, root, (x, y, z + h + 0.15))


def tris():
    n = 0
    for o in bpy.context.scene.objects:
        if o.type == "MESH":
            o.data.calc_loop_triangles()
            n += len(o.data.loop_triangles)
    return n


def finish(name, hide=()):
    names = sorted(o.name for o in bpy.context.scene.objects if o.name not in (name,))
    print("MODEL %-14s tris %5d  objects: %s" % (name, tris(), ", ".join(names)), flush=True)
    save(name)
    for o in bpy.context.scene.objects:
        if o.name.startswith(tuple(hide)) if hide else False:
            o.hide_render = True
    icon(name, 256, yaw=-35, pitch=26)


def start(name):
    reset()
    return empty(name), Part(), Part()


def gold_band(p, size, loc, color=GOLD):
    p.box(size, loc, color, bevel=0.05, segs=1)


# ------------------------------------------------------------------ Bunker
def bunker(stage):
    name = "b_bunker_%d" % stage
    root, B, G = start(name)
    X = Part()                                                      # lv10: Goldschmuck (nur Stufe 5)
    B.box((7.5, 7.3, 0.4), (0, 0, 0.2), ST_D, bevel=0.14)                            # Sockel
    B.box((5.8, 4.6, 2.6), (0, 0.5, 1.6), ST, bevel=0.3)                    # Hauptblock, Front bei y=-1.8
    B.box((1.1, 0.12, 0.5), (-2.0, -1.79, 0.8), ST_L, bevel=0.04, segs=1)             # helle Steine
    B.box((0.9, 0.1, 0.42), (2.05, -1.8, 0.85), ST_L, bevel=0.04, segs=1)
    for sx in (-1, 1):
        for y in (-1.72, 2.72):
            B.box((0.8, 0.8, 2.75), (2.72 * sx, y, 1.72), ST_D, bevel=0.14)        # Eckpfeiler
            B.box((0.86, 0.86, 0.5), (2.72 * sx, y, 0.72), BLUE, bevel=0.1, segs=1)
    B.box((6.5, 5.4, 0.5), (0, 0.5, 3.05), BLUE, bevel=0.2)                  # Dachkante
    B.box((5.2, 4.1, 0.34), (0, 0.5, 3.38), BLUE_L, bevel=0.12)
    B.box((1.3, 1.3, 0.16), (0.2, 1.2, 3.58), STEEL, bevel=0.05, segs=1)               # Dachluke
    for i in range(7 if stage < 5 else 0):                                            # Nieten
        B.cyl(0.09, 0.08, (-2.7 + i * 0.9, -2.2, 3.05), BLUE_L, r=rot(90, 0, 0), sides=8)
    # Tor
    B.box((2.5, 0.6, 2.4), (0, -1.9, 1.55), ST_D, bevel=0.16)
    B.box((2.7, 0.7, 0.4), (0, -1.9, 2.72), BLUE, bevel=0.12)
    B.box((0.96, 0.2, 1.8), (-0.5, -2.16, 1.32), DK, bevel=0.05, segs=1)
    B.box((0.96, 0.2, 1.8), (0.5, -2.16, 1.32), DK, bevel=0.05, segs=1)
    for sx in (-1, 1):
        B.box((0.1, 0.1, 0.3), (0.14 * sx, -2.28, 1.3), GOLD, bevel=0.03, segs=1)
        B.box((0.7, 0.06, 0.08), (0.5 * sx, -2.27, 1.9), "566078")
        B.box((0.7, 0.06, 0.08), (0.5 * sx, -2.27, 0.8), "566078")
    G.box((1.5, 0.1, 0.2), (0, -2.2, 2.46), GLOW, bevel=0.04, segs=1)
    B.box((2.9, 1.0, 0.2), (0, -2.6, 0.48), ST_L, bevel=0.06, segs=1)                # Stufe
    for sx in (-1, 1):
        window(G, B, (1.78 * sx, -1.82, 1.8), 0.62, 0.72)
    window(G, B, (-2.92, 0.5, 1.8), 0.9, 0.7, "l")
    window(G, B, (2.92, 0.5, 1.8), 0.9, 0.7, "r", bars=False)
    if stage < 4:
        sandbags(B, (-3.4, -3.2, 0.4), 1, 0, 3)
        sandbags(B, (2.1, -3.2, 0.4), 1, 0, 3)
    elif stage == 4:                                                                  # vor den Türmen ist weniger Platz
        sandbags(B, (-1.95, -3.3, 0.4), 1, 0, 2, 1)
        sandbags(B, (1.33, -3.3, 0.4), 1, 0, 2, 1)
    crate(B, (-3.15, -0.3, 0.4), 0.8, WOOD, 12)
    if stage < 5:
        crate(B, (-3.2, 0.65, 0.4), 0.62, OLIVE, -8)
    barrel(B, (3.2, -1.0, 0.4), RED)
    top = 3.55
    fpos = (-1.7, 1.4, top)
    if stage >= 2:                                                                    # Anbau links hinten mit olivem Dach
        B.box((2.5, 2.5, 1.5), (-1.55, 1.35, top + 0.65), ST, bevel=0.2)
        B.box((2.9, 2.9, 0.4), (-1.55, 1.35, top + 1.55), OLIVE, bevel=0.14)
        B.box((2.2, 2.2, 0.2), (-1.55, 1.35, top + 1.8), shade(OLIVE, 0.8), bevel=0.06, segs=1)
        window(G, B, (-1.55, 0.08, top + 0.75), 0.9, 0.6)
        fpos = (-2.4, 2.2, top + 1.85)
        dz = top + (1.85 if stage >= 3 else 0.0)                                      # Funkschüssel
        dx, dy = (2.2, 1.7) if stage >= 3 else (1.7, 1.3)
        B.cyl(0.3, 0.2, (dx, dy, dz + 0.1), DK, sides=10, bevel=0.04, segs=1)
        B.cyl(0.07, 0.8, (dx, dy, dz + 0.5), STEEL, sides=8)
        m = T(dx, dy - 0.1, dz + 1.05) @ rot(55, 0, 20)
        B.cyl(0.2, 0.36, (0, 0, 0), "F4F6FA", r=m, r2=0.8, sides=14)
        B.cyl(0.03, 0.5, (0, 0, 0), STEEL, r=m @ T(0, 0, 0.3), sides=6)
        B.ball(0.08, (0, 0, 0), RED, r=m @ T(0, 0, 0.55), subdiv=2)
    if stage >= 3:                                                                    # zweites Stockwerk rechts
        B.box((3.1, 3.1, 1.75), (1.35, 0.95, top + 0.78), ST, bevel=0.22)
        B.box((3.5, 3.5, 0.42), (1.35, 0.95, top + 1.75), BLUE, bevel=0.16)
        B.box((2.7, 2.7, 0.2), (1.35, 0.95, top + 2.0), ST_L, bevel=0.06, segs=1)
        window(G, B, (0.75, -0.62, top + 0.85), 0.6, 0.66)
        window(G, B, (1.95, -0.62, top + 0.85), 0.6, 0.66)
        for i in range(3 if stage < 5 else 0):                                        # Zinnen vorn am Hauptdach
            B.box((0.6, 0.4, 0.4), (-2.4 + i * 1.2, -1.75, top + 0.15), ST_L, bevel=0.08, segs=1)
    if stage >= 4:                                                                    # Wachtürme vorn
        for sx in (-1, 1):
            B.box((1.35, 1.35, 4.9), (2.95 * sx, -2.2, 2.85), ST, bevel=0.18)
            B.box((1.65, 1.65, 0.42), (2.95 * sx, -2.2, 5.3), BLUE, bevel=0.14, segs=1)
            for k in range(4):
                B.box((0.4, 0.4, 0.36), (2.95 * sx + (0.5 if k % 2 else -0.5), -2.2 + (0.5 if k < 2 else -0.5), 5.62), ST_L, bevel=0.07, segs=1)
            window(G, B, (2.95 * sx, -2.89, 4.2), 0.5, 0.62)
            if stage < 5:
                window(G, B, (2.95 * sx, -2.89, 2.2), 0.5, 0.62, bars=False)
        # Suchscheinwerfer auf dem linken Turm
        m = T(-2.95, -2.2, 5.95) @ rot(0, 0, -25) @ rot(72, 0, 0)
        B.cyl(0.07, 0.5, (-2.95, -2.2, 5.7), DK, sides=8)
        B.cyl(0.34, 0.5, (0, 0, 0), DK, r=m, sides=12, bevel=0.06, segs=1)
        G.cyl(0.27, 0.08, (0, 0, 0), "FFF3B8", r=m @ T(0, 0, 0.26), sides=12)
    if stage >= 5:                                                                    # Kommandoturm mit Spitzdach, Antenne
        B.box((2.1, 2.1, 1.6), (1.35, 0.95, top + 2.85), ST, bevel=0.2)
        B.box((2.5, 2.5, 0.3), (1.35, 0.95, top + 3.7), BLUE_D, bevel=0.1, segs=1)
        B.cyl(1.75, 1.5, (1.35, 0.95, top + 4.6), BLUE, r=rot(0, 0, 45), r2=0.12, sides=4)
        window(G, B, (1.35, -0.12, top + 2.9), 1.0, 0.6)
        window(G, B, (0.28, 0.95, top + 2.9), 1.0, 0.6, "l")
        B.cyl(0.05, 1.5, (1.35, 0.95, top + 6.0), STEEL, sides=6)
        G.ball(0.13, (1.35, 0.95, top + 6.8), HOT, subdiv=2)
        ax, ay, az = -0.75, 0.55, top + 1.9                                           # Gittermast auf dem Anbau
        for k in range(3):
            B.box((0.5 - k * 0.12, 0.5 - k * 0.12, 0.06), (ax, ay, az + 0.5 + k * 0.6), RED if k % 2 == 0 else "F4F6FA")
        for sx in (-1, 1):
            for sy in (-1, 1):
                beam(B, (ax + 0.26 * sx, ay + 0.26 * sy, az), (ax + 0.06 * sx, ay + 0.06 * sy, az + 2.0), 0.07, STEEL)
        B.cyl(0.03, 0.9, (ax, ay, az + 2.4), STEEL, sides=6)
        for sx in (-1, 1):                                                            # hintere Ecktürmchen
            B.box((1.2, 1.2, 1.3), (2.85 * sx, 3.0, 3.6), ST, bevel=0.16, segs=1)
            B.box((1.45, 1.45, 0.34), (2.85 * sx, 3.0, 4.35), BLUE, bevel=0.12, segs=1)
        # ---- Gold ab Stufe 10
        X.box((6.6, 5.5, 0.16), (0, 0.5, 3.05), GOLD, bevel=0.06, segs=1)
        X.box((3.6, 3.6, 0.14), (1.35, 0.95, top + 1.75), GOLD, bevel=0.05, segs=1)
        for sx in (-1, 1):
            X.box((1.7, 1.7, 0.14), (2.95 * sx, -2.2, 5.3), GOLD, bevel=0.05, segs=1)
            X.cyl(0.2, 0.5, (2.85 * sx, 3.0, 4.75), GOLD, r2=0.02, sides=8)
        X.cyl(0.34, 0.6, (1.35, 0.95, top + 5.35), GOLD, r2=0.03, sides=8)
        star(X, (0, -2.26, 2.95), 0.5, GOLD, 0.14)
        X.box((2.7, 0.16, 0.14), (0, -2.16, 2.68), GOLD, bevel=0.04, segs=1)
    flag(root, B, fpos, 2.5)
    B.build("body", root)
    G.build("win_glow", root)
    if stage >= 5:
        X.build("lv10_gold", root)
    finish(name, hide=("lv10_",))


# ------------------------------------------------------------------ Produktion
def base(B, sx, sy, color="D9B37A", h=0.18):
    B.box((sx, sy, h), (0, 0, h * 0.5), color, bevel=0.07, segs=1)


def logs(p, loc, n_bottom=3, length=2.2, r=0.28, along="y"):
    """Holzstapel (Pyramide)."""
    x, y, z = loc
    m = rot(90, 0, 0) if along == "y" else rot(0, 90, 0)
    for row in range(n_bottom):
        for i in range(n_bottom - row):
            o = (i - (n_bottom - row - 1) * 0.5) * r * 2.05
            c = (x + o, y, z + r + row * r * 1.75) if along == "y" else (x, y + o, z + r + row * r * 1.75)
            p.cyl(r, length, c, WOOD_D if (i + row) % 2 else "8A5030", r=m, sides=10)
            p.cyl(r * 0.8, length + 0.04, c, "E8C088", r=m, sides=10)


def saege():
    root, B, G = start("b_saege")
    base(B, 5.6, 5.6)
    # Schuppen hinten rechts
    B.box((3.4, 2.5, 2.1), (0.8, 1.15, 1.2), WOOD, bevel=0.14)
    for i in range(5):
        B.box((0.06, 0.06, 1.8), (-0.55 + i * 0.68, -0.12, 1.2), WOOD_D)
    gable(B, (0.8, 1.15, 2.2), 3.4, 2.5, 1.15, RED, over=0.28, fill=WOOD)
    B.box((0.95, 0.12, 1.6), (1.6, -0.12, 1.0), WOOD_D, bevel=0.04, segs=1)          # Tür
    B.box((0.1, 0.08, 0.1), (1.3, -0.2, 1.0), GOLD)
    window(G, B, (0.2, -0.12, 1.35), 0.7, 0.7)
    chimney(root, B, (1.85, 1.7, 2.6), 1.3, 0.24, square=True)
    # Sägetisch vorn links
    B.box((2.9, 1.3, 0.22), (-1.2, -1.55, 0.85), WOOD_L, bevel=0.06, segs=1)
    for sx in (-1, 1):
        for sy in (-1, 1):
            B.box((0.2, 0.2, 0.7), (-1.2 + 1.2 * sx, -1.55 + 0.45 * sy, 0.5), WOOD_D, bevel=0.04, segs=1)
    B.box((0.9, 0.5, 0.5), (-0.4, -1.1, 1.2), RED_D, bevel=0.1)                        # Motor
    B.cyl(0.3, 1.0, (-2.05, -1.55, 1.24), WOOD_D, r=rot(0, 90, 0), sides=10)           # Stamm auf dem Tisch
    B.cyl(0.24, 1.04, (-2.05, -1.55, 1.24), "E8C088", r=rot(0, 90, 0), sides=10)
    s = Part()
    s.cyl(0.78, 0.07, (0, 0, 0), STEEL_L, sides=20)
    for i in range(12):
        a = math.radians(i * 30)
        s.cyl(0.16, 0.07, (math.cos(a) * 0.8, math.sin(a) * 0.8, 0), STEEL_L, r=rot(0, 0, i * 30 - 50), sides=3)
    s.cyl(0.3, 0.12, (0, 0, 0), RED, sides=12, bevel=0.02, segs=1)
    s.cyl(0.1, 0.18, (0, 0, 0), DK, sides=8)
    o = s.build("spin_blade", root, (-1.05, -1.55, 1.1))
    o.rotation_euler = (math.radians(90), 0, 0)
    logs(B, (-1.9, 1.3, 0.18), 3, 2.3, 0.3)
    for i in range(3):                                                                 # Bretterstapel
        B.box((1.7, 0.9, 0.13), (1.6, -1.9 + i * 0.04, 0.26 + i * 0.15), shade(WOOD_L, 1.0 - i * 0.06), bevel=0.03, segs=1, r=rot(0, 0, i * 4 - 4))
    B.cyl(0.32, 0.45, (0.2, -2.2, 0.4), WOOD_D, sides=10)                              # Hackklotz mit Axt
    B.cyl(0.27, 0.02, (0.2, -2.2, 0.635), "E8C088", sides=10)
    beam(B, (0.2, -2.2, 0.7), (0.55, -2.2, 1.3), 0.07, WOOD_L)
    B.box((0.3, 0.07, 0.24), (0.18, -2.2, 0.76), STEEL_L, r=rot(0, 30, 0), bevel=0.02, segs=1)
    x4 = Part()
    for i in range(3):
        x4.box((1.7, 0.9, 0.13), (1.6, -1.86, 0.72 + i * 0.15), shade(WOOD_L, 1.05 - i * 0.07), bevel=0.03, segs=1, r=rot(0, 0, 5 - i * 5))
    x4.cyl(0.3, 2.3, (-1.9, 1.3, 2.0), "8A5030", r=rot(90, 0, 0), sides=10)
    x4.cyl(0.24, 2.34, (-1.9, 1.3, 2.0), "E8C088", r=rot(90, 0, 0), sides=10)
    x7 = Part()
    x7.cyl(0.18, 3.96, (0.8, 1.15, 3.55), GOLD, r=rot(0, 90, 0), sides=8, bevel=0.05, segs=1)
    x7.cyl(0.04, 0.7, (-1.05, 1.15, 3.9), DK, sides=6)
    x7.box((0.6, 0.05, 0.3), (-0.75, 1.15, 4.1), GOLD, bevel=0.02, segs=1)
    x7.cyl(0.32, 0.14, (-1.05, -1.62, 1.1), GOLD, r=rot(90, 0, 0), sides=12)
    B.build("body", root); G.build("win_glow", root)
    x4.build("lv4_stock", root); x7.build("lv7_trim", root)
    finish("b_saege")


def steinbruch():
    root, B, G = start("b_steinbruch")
    base(B, 5.6, 5.6, "B9A58C")
    R, RL, RD = "9A93A6", "BDB8C8", "756E84"
    # Felswand in Stufen
    B.box((5.3, 2.3, 1.5), (0, 1.55, 0.8), R, bevel=0.3)
    B.box((3.7, 1.9, 1.4), (-0.75, 1.75, 2.1), RL, bevel=0.3)
    B.box((1.9, 1.5, 1.1), (-1.5, 1.9, 3.2), R, bevel=0.28)
    B.box((1.3, 1.3, 0.9), (2.0, 1.9, 1.9), RD, bevel=0.25, r=rot(0, 0, 12))
    B.box((1.5, 1.2, 0.2), (-1.5, 1.95, 3.78), "8FB02A", bevel=0.08)                   # Gras obenauf
    B.box((1.4, 1.0, 0.18), (0.4, 2.0, 2.82), "8FB02A", bevel=0.08)
    B.ball(0.3, (-2.0, 1.6, 3.95), "4F7A2A", subdiv=2, scale=(1, 1, 0.8))
    for (x, y, z, s, a, c) in ((-2.1, 0.0, 0.18, 0.7, 15, RL), (-1.3, 0.15, 0.18, 0.55, -20, R), (0.3, 0.2, 0.18, 0.6, 8, RL), (-1.7, 0.1, 0.86, 0.5, 30, "D6D2E0")):
        B.box((s * 1.25, s, s), (x, y, z + s * 0.5), c, bevel=0.07, r=rot(0, 0, a), segs=1)  # gebrochene Blöcke
    # Kran
    mx, my = 1.75, -0.35
    B.box((1.0, 1.0, 0.4), (mx, my, 0.38), WOOD_D, bevel=0.08, segs=1)
    B.box((0.26, 0.26, 3.3), (mx, my, 2.0), WOOD, bevel=0.05, segs=1)
    beam(B, (mx + 0.45, my, 0.6), (mx, my, 1.9), 0.14, WOOD_D)
    beam(B, (mx, my + 0.45, 0.6), (mx, my, 1.9), 0.14, WOOD_D)
    B.box((0.7, 0.6, 0.6), (mx + 0.55, my + 0.75, 0.48), DK, bevel=0.1)                 # Dampfwinde
    B.cyl(0.24, 0.5, (mx + 0.55, my + 0.4, 0.55), STEEL_L, r=rot(0, 90, 0), sides=10)
    chimney(root, B, (mx + 0.7, my + 0.9, 0.7), 0.9, 0.13, color=DK)
    a = Part()
    d = Vector((-2.3, -0.75, 0.55))
    beam(a, (0.5, 0.16, -0.12), d, 0.2, WOOD, bevel=0.04)
    beam(a, (0, 0, 0.5), d * 0.6, 0.08, WOOD_D)
    a.box((0.34, 0.34, 0.6), (0, 0, 0.2), STEEL, bevel=0.06, segs=1)
    a.box((0.5, 0.4, 0.4), (0.62, 0.2, -0.15), ST_D, bevel=0.08, segs=1)                # Gegengewicht
    a.cyl(0.025, 1.2, (d.x, d.y, d.z - 0.6), "E8D8B0", sides=6)
    a.box((0.62, 0.62, 0.55), (d.x, d.y, d.z - 1.45), "D6D2E0", bevel=0.09)             # Steinblock am Seil
    a.box((0.66, 0.1, 0.59), (d.x, d.y, d.z - 1.45), WOOD_D)
    a.box((0.1, 0.66, 0.59), (d.x, d.y, d.z - 1.45), WOOD_D)
    a.build("sway_arm", root, (mx, my, 3.65))
    # Lore auf Schienen vorn
    for sy in (-0.32, 0.32):
        B.box((4.6, 0.09, 0.09), (-0.4, -1.95 + sy, 0.27), STEEL)
    for i in range(6):
        B.box((0.2, 1.0, 0.07), (-2.5 + i * 0.84, -1.95, 0.2), WOOD_D)
    B.box((1.3, 0.95, 0.6), (-1.2, -1.95, 0.82), "4F7FD0", bevel=0.12)
    B.box((1.4, 1.05, 0.12), (-1.2, -1.95, 1.1), BLUE_D, bevel=0.03, segs=1)
    for sx in (-0.4, 0.4):
        for sy in (-0.42, 0.42):
            B.cyl(0.22, 0.1, (-1.2 + sx, -1.95 + sy, 0.5), DK, r=rot(90, 0, 0), sides=10)
    for (x, y, z, r) in ((-1.5, -2.0, 1.2, 0.3), (-1.0, -1.85, 1.22, 0.32), (-1.25, -2.1, 1.42, 0.24)):
        B.ball(r, (x, y, z), RL if r > 0.25 else "D6D2E0", subdiv=2, scale=(1.1, 1, 0.8))
    # Spitzhacke am Fels
    beam(B, (0.9, 0.25, 0.2), (1.05, 0.5, 1.5), 0.08, WOOD_L)
    B.cyl(0.07, 0.8, (1.05, 0.5, 1.5), STEEL_L, r=rot(0, 80, 20), sides=6, r2=0.02)
    G.box((0.26, 0.26, 0.3), (mx - 0.3, my - 0.2, 2.3), GLOW, bevel=0.05, segs=1)       # Laterne am Mast
    B.box((0.34, 0.34, 0.08), (mx - 0.3, my - 0.2, 2.5), DK)
    B.box((0.2, 0.1, 0.06), (mx - 0.15, my - 0.1, 2.5), DK)
    x4 = Part()
    for (x, y, z, s, a_) in ((0.6, -0.9, 0.18, 0.6, 10), (-0.1, -0.85, 0.18, 0.6, -6), (0.25, -0.88, 0.78, 0.56, 20)):
        x4.box((s * 1.2, s, s), (x, y, z + s * 0.5), "D6D2E0", bevel=0.07, r=rot(0, 0, a_), segs=1)
    x7 = Part()
    x7.box((1.44, 1.09, 0.1), (-1.2, -1.95, 1.17), GOLD, bevel=0.03, segs=1)
    x7.box((0.38, 0.38, 0.14), (0, 0, 0), GOLD, r=T(mx, my, 3.72), bevel=0.04, segs=1)
    x7.ball(0.22, (-1.2, -1.95, 1.5), GOLD, subdiv=2)
    x7.ball(0.16, (-0.85, -2.1, 1.38), GOLD, subdiv=2)
    B.build("body", root); G.build("win_glow", root)
    x4.build("lv4_blocks", root); x7.build("lv7_trim", root)
    finish("b_steinbruch")


def presse():
    root, B, G = start("b_presse")
    base(B, 5.6, 5.6, "8A94A8")
    F, Y = "6F7C96", "F2B21E"
    py = 0.7
    B.box((3.6, 2.0, 0.6), (0, py, 0.48), DK, bevel=0.12)                               # Pressentisch
    for sx in (-1, 1):
        B.box((0.75, 1.3, 3.7), (1.6 * sx, py, 2.05), F, bevel=0.16)
        B.box((0.3, 1.34, 0.5), (1.6 * sx - 0.24 * sx, py, 1.2), Y, bevel=0.05, segs=1)
    B.box((4.4, 1.7, 1.0), (0, py, 4.2), BLUE, bevel=0.22, segs=3)                      # Querhaupt
    for i in range(6):                                                                  # Warnstreifen
        B.box((0.34, 0.08, 0.26), (-1.5 + i * 0.6, py - 0.86, 3.86), Y if i % 2 == 0 else "23262E", r=rot(0, 25, 0))
    B.cyl(0.5, 0.7, (0, py, 4.95), STEEL_L, sides=14, bevel=0.1)
    B.cyl(0.2, 0.3, (0, py, 5.4), DK, sides=10)
    B.box((0.7, 0.7, 0.34), (0, py, 0.95), STEEL, bevel=0.06, segs=1)                   # Würfel unter der Presse
    h = Part()
    h.cyl(0.26, 1.5, (0, 0, 1.0), STEEL_L, sides=12)
    h.box((2.2, 1.3, 0.8), (0, 0, 0.1), Y, bevel=0.16, segs=3)
    h.box((2.3, 1.4, 0.2), (0, 0, -0.36), DK, bevel=0.05, segs=1)
    for sx in (-0.7, 0.7):
        h.cyl(0.14, 0.1, (sx, -0.66, 0.15), "23262E", r=rot(90, 0, 0), sides=8)
    h.build("bob_head", root, (0, py, 2.25))
    empty("fx_spark", root, (0, py - 0.5, 1.2))
    chimney(root, B, (2.1, 2.2, 0.18), 4.4, 0.3, color=DK)
    B.cyl(0.34, 0.3, (2.1, 2.2, 3.4), RED, sides=12)
    # Steuerpult vorn rechts
    B.box((0.9, 0.7, 1.2), (2.1, -1.2, 0.78), BLUE_D, bevel=0.12)
    B.box((0.8, 0.5, 0.3), (2.1, -1.3, 1.42), F, bevel=0.06, segs=1, r=rot(35, 0, 0))
    G.box((0.5, 0.06, 0.3), (2.1, -1.57, 1.05), CYAN)
    G.cyl(0.09, 0.08, (1.9, -1.42, 1.56), HOT, sides=8, r=rot(35, 0, 0))
    G.cyl(0.09, 0.08, (2.25, -1.42, 1.56), "7CFF6A", sides=8, r=rot(35, 0, 0))
    window(G, B, (-1.6, py - 0.66, 2.9), 0.36, 0.5, bars=False)
    window(G, B, (1.6, py - 0.66, 2.9), 0.36, 0.5, bars=False)
    # Schrotthaufen links, gepresste Würfel vorn
    for (x, y, z, s, c, a) in ((-2.1, -0.6, 0.18, 0.7, "B5562F", 10), (-1.9, -1.4, 0.18, 0.6, STEEL, -15), (-2.2, -1.0, 0.8, 0.5, "4F7FD0", 30),
                               (-0.9, -1.9, 0.18, 0.62, STEEL_L, 0), (-0.2, -1.95, 0.18, 0.62, "B5562F", 5), (0.5, -1.9, 0.18, 0.62, STEEL, -4), (-0.55, -1.93, 0.8, 0.62, "E0A82E", 8)):
        B.box((s, s, s), (x, y, z + s * 0.5), c, bevel=0.06, segs=1, r=rot(0, 0, a))
        B.box((s * 1.03, s * 0.2, s * 1.03), (x, y, z + s * 0.5), shade(c, 0.75), r=rot(0, 0, a))
    B.torus(0.3, 0.13, (-2.2, -2.1, 0.32), "23262E", seg=12, tseg=6, r=rot(20, 0, 0))
    x4 = Part()
    for (x, y, z, c) in ((0.5, -1.9, 0.8, "4F7FD0"), (-0.9, -1.9, 0.8, RED)):
        x4.box((0.62, 0.62, 0.62), (x, y, z + 0.31), c, bevel=0.06, segs=1, r=rot(0, 0, 12))
        x4.box((0.64, 0.14, 0.64), (x, y, z + 0.31), shade(c, 0.75), r=rot(0, 0, 12))
    x7 = Part()
    x7.box((4.48, 1.78, 0.14), (0, py, 4.36), GOLD, bevel=0.05, segs=1)
    x7.cyl(0.36, 0.14, (2.1, 2.2, 4.5), GOLD, sides=12)
    star(x7, (0, py - 0.87, 4.05), 0.26, GOLD, 0.1)
    B.build("body", root); G.build("win_glow", root)
    x4.build("lv4_cubes", root); x7.build("lv7_trim", root)
    finish("b_presse")


def raffinerie():
    root, B, G = start("b_raffinerie")
    base(B, 5.6, 5.6, "A7ADC6")
    # großer roter Tank
    tx, ty = -1.2, 1.1
    B.cyl(1.35, 2.5, (tx, ty, 1.5), RED, sides=20, bevel=0.1)
    B.ball(1.33, (tx, ty, 2.7), "EE5A55", subdiv=3, scale=(1, 1, 0.5))
    for z in (0.75, 2.2):
        B.cyl(1.4, 0.16, (tx, ty, z), RED_D, sides=20)
    B.cyl(0.25, 0.3, (tx, ty, 3.45), STEEL_L, sides=10, bevel=0.05, segs=1)
    for i in range(6):                                                                  # Leiter
        B.box((0.5, 0.06, 0.06), (tx - 0.6, ty - 1.3, 0.6 + i * 0.4), STEEL_L, r=rot(0, 0, -25))
    # weißer hoher Tank
    wx, wy = 1.55, 1.6
    B.cyl(0.85, 3.3, (wx, wy, 1.85), "F4F6FA", sides=16, bevel=0.08)
    B.ball(0.84, (wx, wy, 3.45), STEEL_L, subdiv=2, scale=(1, 1, 0.5))
    for z in (1.0, 2.0, 3.0):
        B.cyl(0.89, 0.12, (wx, wy, z), "4F7FD0", sides=16)
    # Fackelschornstein
    cx, cy = 2.2, -0.3
    B.cyl(0.42, 0.5, (cx, cy, 0.42), DK, sides=12, bevel=0.06, segs=1)
    chimney(root, B, (cx, cy, 0.5), 4.3, 0.2, color=STEEL)
    for i, z in enumerate((2.2, 3.0, 3.8)):
        B.cyl(0.215, 0.4, (cx, cy, z), RED if i % 2 == 0 else "F4F6FA", sides=12)
    # Rohre
    P = "E0A82E"
    tube(B, (tx, ty - 1.3, 0.9), (tx, -1.0, 0.9), 0.14, P, 10)
    B.ball(0.18, (tx, -1.0, 0.9), P, subdiv=2)
    tube(B, (tx, -1.0, 0.9), (cx, -1.0, 0.9), 0.14, P, 10)
    B.ball(0.18, (cx, -1.0, 0.9), P, subdiv=2)
    tube(B, (cx, -1.0, 0.9), (cx, cy, 0.9), 0.14, P, 10)
    tube(B, (0.7, -1.0, 0.9), (0.7, -1.0, 2.6), 0.12, P, 10)
    B.ball(0.16, (0.7, -1.0, 2.6), P, subdiv=2)
    tube(B, (0.7, -1.0, 2.6), (wx - 0.5, wy - 0.6, 2.6), 0.12, P, 10)
    for x in (-0.6, 1.4):
        B.cyl(0.2, 0.12, (x, -1.0, 0.9), STEEL, r=rot(0, 90, 0), sides=10)
        B.box((0.16, 0.16, 0.8), (x, -1.0, 0.45), DK)
    B.box((0.7, 0.6, 0.7), (0.2, -1.0, 0.75), "4F7FD0", bevel=0.12)                     # Pumpe
    v = Part()
    v.torus(0.3, 0.055, (0, 0, 0), RED, seg=12, tseg=6)
    v.box((0.6, 0.07, 0.05), (0, 0, 0), RED)
    v.box((0.07, 0.6, 0.05), (0, 0, 0), RED)
    v.cyl(0.08, 0.2, (0, 0, -0.06), DK, sides=8)
    o = v.build("spin_valve", root, (0.2, -1.42, 0.8))
    o.rotation_euler = (math.radians(90), 0, 0)
    G.cyl(0.2, 0.08, (tx + 0.55, ty - 1.27, 1.5), GLOW, r=rot(90, 0, 0) , sides=10)     # Anzeige am Tank
    B.cyl(0.26, 0.06, (tx + 0.55, ty - 1.24, 1.5), DK, r=rot(90, 0, 0), sides=10)
    barrel(B, (-2.2, -1.9, 0.18), RED)
    barrel(B, (-1.45, -2.15, 0.18), DK)
    barrel(B, (-2.3, -1.1, 0.18), "F2B21E")
    x4 = Part()
    barrel(x4, (-1.9, -1.55, 1.08), "4F7FD0")
    barrel(x4, (1.2, -2.1, 0.18), RED)
    x7 = Part()
    x7.cyl(1.42, 0.14, (tx, ty, 1.48), GOLD, sides=20)
    x7.cyl(0.9, 0.12, (wx, wy, 3.38), GOLD, sides=16)
    x7.ball(0.2, (tx, ty, 3.7), GOLD, subdiv=2)
    B.build("body", root); G.build("win_glow", root)
    x4.build("lv4_barrels", root); x7.build("lv7_trim", root)
    finish("b_raffinerie")


def generator():
    root, B, G = start("b_generator")
    base(B, 3.6, 3.6, "8A94A8", 0.2)
    H, Y = "4B5F8C", "F2B21E"
    B.box((3.1, 2.5, 1.6), (0, 0.35, 1.0), H, bevel=0.26, segs=3)
    B.box((3.3, 2.7, 0.28), (0, 0.35, 1.9), Y, bevel=0.1)
    B.box((3.3, 2.7, 0.2), (0, 0.35, 0.36), DK, bevel=0.06, segs=1)
    # Kern in einem Ring an der Vorderseite
    B.box((1.5, 0.3, 1.25), (-0.55, -0.9, 1.05), "23262E", bevel=0.08, segs=1)
    B.torus(0.56, 0.1, (-0.55, -1.08, 1.05), Y, r=rot(90, 0, 0), seg=14, tseg=6)
    c = Part()
    c.ball(0.44, (0, 0, 0), CYAN, subdiv=3)
    c.build("pulse_core_glow", root, (-0.55, -1.1, 1.05))
    G.box((0.7, 0.08, 0.3), (0.95, -0.92, 1.3), CYAN)                                   # Anzeige
    for i in range(3):
        G.box((0.16, 0.08, 0.16), (0.72 + i * 0.24, -0.92, 0.85), (HOT, GLOW, "7CFF6A")[i])
    B.box((0.9, 0.1, 0.9), (0.95, -0.9, 1.1), DK, bevel=0.04, segs=1)
    # Rotor oben
    B.cyl(0.95, 0.4, (-0.5, 0.35, 2.2), DK, sides=18, bevel=0.08, segs=1)
    B.cyl(0.8, 0.06, (-0.5, 0.35, 2.4), "181A22", sides=18)
    r = Part()
    r.cyl(0.2, 0.3, (0, 0, 0), Y, sides=10, bevel=0.05, segs=1)
    for i in range(4):
        a = i * 90
        r.box((0.72, 0.3, 0.06), (math.cos(math.radians(a)) * 0.45, math.sin(math.radians(a)) * 0.45, 0.05), STEEL_L, r=rot(0, 0, a) @ rot(18, 0, 0), bevel=0.02, segs=1)
    r.build("spin_rotor", root, (-0.5, 0.35, 2.55))
    chimney(root, B, (1.0, 0.9, 2.0), 1.3, 0.2, color=STEEL)
    B.box((0.7, 0.7, 0.3), (1.0, 0.9, 2.1), DK, bevel=0.08, segs=1)
    # Kabel und Batterie links
    B.box((0.5, 0.9, 1.0), (1.35, -1.35, 0.6), "5A6A8C", bevel=0.1)
    G.box((0.3, 0.08, 0.5), (1.35, -1.64, 0.62), CYAN)
    for i in range(4):                                                                  # Kühlrippen an der linken Seite
        B.box((0.12, 0.34, 1.0), (-1.6, -0.3 + i * 0.44, 1.05), DK, bevel=0.04, segs=1)
    x4 = Part()
    x4.box((0.5, 0.5, 0.9), (0.6, -1.4, 0.6), "5A6A8C", bevel=0.1)
    x4.cyl(0.08, 0.2, (0.6, -1.4, 1.12), Y, sides=8)
    x7 = Part()
    x7.box((3.38, 2.78, 0.1), (0, 0.35, 1.74), GOLD, bevel=0.03, segs=1)
    x7.cyl(0.26, 0.12, (1.0, 0.9, 3.2), GOLD, sides=12)
    x7.torus(0.7, 0.07, (-0.55, -1.1, 1.05), GOLD, r=rot(90, 0, 0), seg=14, tseg=6)
    B.build("body", root); G.build("win_glow", root)
    x4.build("lv4_cell", root); x7.build("lv7_trim", root)
    finish("b_generator")


# ------------------------------------------------------------------ Lager, Quartier, Sondergebäude
def lager():
    root, B, G = start("b_lager")
    base(B, 5.6, 5.6)
    W = "E2C27C"
    B.box((4.6, 3.1, 2.3), (0.15, 0.85, 1.3), W, bevel=0.16)
    gable(B, (0.15, 0.85, 2.4), 4.6, 3.1, 1.35, OLIVE, over=0.3, fill=W)
    for x in (-2.0, 2.4):                                                              # Eckbalken
        B.box((0.24, 0.2, 2.2), (x - 0.05, -0.7, 1.3), WOOD_D, bevel=0.04, segs=1)
    # Schiebetor: links offen (dunkel), rechts Holztor
    B.box((2.5, 0.12, 1.95), (0.55, -0.7, 1.15), "23262E")
    B.box((1.35, 0.14, 1.95), (1.2, -0.78, 1.15), WOOD, bevel=0.04, segs=1)
    beam(B, (0.63, -0.87, 0.3), (1.77, -0.87, 2.0), 0.12, WOOD_D, d=0.06)
    beam(B, (1.77, -0.87, 0.3), (0.63, -0.87, 2.0), 0.12, WOOD_D, d=0.06)
    B.box((2.9, 0.16, 0.16), (0.55, -0.8, 2.2), STEEL, bevel=0.03, segs=1)               # Laufschiene
    crate(B, (0.05, -0.4, 0.18), 0.7, "4F7FD0", 8)                                       # Kiste im Tor
    G.box((0.3, 0.2, 0.26), (-1.05, -0.82, 1.9), GLOW, bevel=0.05, segs=1)               # Lampe neben dem Tor
    B.box((0.44, 0.3, 0.08), (-1.05, -0.82, 2.07), DK)
    window(G, B, (-2.17, 0.8, 1.5), 0.8, 0.6, "l")
    # Kisten und Fässer davor
    crate(B, (-1.9, -1.7, 0.18), 0.85, WOOD, 6)
    crate(B, (-0.95, -1.9, 0.18), 0.8, OLIVE, -10)
    crate(B, (-1.5, -1.75, 1.03), 0.7, "4F7FD0", 20)
    barrel(B, (2.1, -1.7, 0.18), RED)
    barrel(B, (1.4, -2.05, 0.18), "4F7FD0")
    B.box((1.2, 0.8, 0.3), (-2.1, -0.45, 0.33), "E8B76E", bevel=0.12)                    # Säcke
    B.box((1.0, 0.7, 0.3), (-2.1, -0.45, 0.6), "D9A55E", bevel=0.12)
    x4 = Part()
    crate(x4, (-0.15, -2.2, 0.18), 0.7, WOOD, 14)
    crate(x4, (-0.9, -1.9, 0.98), 0.62, RED, 25)
    barrel(x4, (2.15, -1.75, 1.08), "F2B21E", r=0.3, h=0.75)
    x7 = Part()
    x7.cyl(0.18, 5.3, (0.15, 0.85, 3.95), GOLD, r=rot(0, 90, 0), sides=8, bevel=0.05, segs=1)
    x7.box((3.0, 0.2, 0.14), (0.55, -0.8, 2.32), GOLD, bevel=0.04, segs=1)
    x7.ball(0.22, (-2.55, 0.85, 3.98), GOLD, subdiv=2)
    B.build("body", root); G.build("win_glow", root)
    x4.build("lv4_stock", root); x7.build("lv7_trim", root)
    finish("b_lager")


def quartier():
    root, B, G = start("b_quartier")
    base(B, 5.6, 3.6)
    W = "F0DDB0"
    hx, hy = 0.78, 0.25
    B.box((3.5, 2.5, 2.0), (hx, hy, 1.15), W, bevel=0.16)
    B.box((3.56, 2.56, 0.5), (hx, hy, 0.42), ST, bevel=0.08, segs=1)                    # Steinsockel
    gable(B, (hx, hy, 2.15), 3.5, 2.5, 1.15, BLUE, over=0.22, fill=W)
    fy = hy - 1.25
    B.box((0.9, 0.14, 1.6), (-0.25, fy - 0.02, 0.98), WOOD, bevel=0.05, segs=1)         # Tür
    G.cyl(0.17, 0.1, (-0.25, fy - 0.08, 1.4), GLOW, r=rot(90, 0, 0), sides=10)
    B.box((0.08, 0.08, 0.12), (0.05, fy - 0.1, 1.0), GOLD)
    B.box((1.1, 0.5, 0.14), (-0.25, fy - 0.3, 0.25), ST_L, bevel=0.04, segs=1)
    window(G, B, (0.95, fy, 1.4), 0.66, 0.7)
    window(G, B, (2.0, fy, 1.4), 0.66, 0.7)
    for x in (0.95, 2.0):                                                               # Blumenkästen
        B.box((0.8, 0.22, 0.18), (x, fy - 0.16, 0.86), WOOD_D, bevel=0.03, segs=1)
        for k in range(3):
            B.ball(0.1, (x - 0.25 + k * 0.25, fy - 0.18, 1.0), ("F07AB4", "FFD23E", "F4F6FA")[k], subdiv=2)
    G.box((0.2, 0.16, 0.24), (-0.9, fy - 0.12, 1.75), GLOW, bevel=0.04, segs=1)         # Laterne neben der Tür
    B.box((0.3, 0.26, 0.07), (-0.9, fy - 0.12, 1.9), DK)
    chimney(root, B, (2.0, 0.85, 2.5), 1.25, 0.24, square=True)
    # Schlafplatz unter dem Vordach links: Etagenbett
    bx, by = -2.0, 0.3
    B.box((1.6, 2.5, 0.14), (bx - 0.02, by, 2.2), BLUE_D, bevel=0.05, segs=1, r=rot(0, -14, 0))
    for sy in (-1.05, 1.05):
        B.box((0.16, 0.16, 1.85), (bx - 0.6, by + sy, 1.1), WOOD_D, bevel=0.03, segs=1)
        B.box((0.14, 0.14, 1.6), (bx + 0.5, by + sy, 1.0), WOOD_D)
    for i, z in enumerate((0.48, 1.3)):
        B.box((1.2, 2.2, 0.14), (bx - 0.05, by, z), WOOD, bevel=0.03, segs=1)
        B.box((1.05, 2.0, 0.2), (bx - 0.05, by, z + 0.16), "F4F6FA", bevel=0.07)
        B.box((1.1, 1.3, 0.24), (bx - 0.05, by + 0.3, z + 0.18), (RED, "4F9BE8")[i], bevel=0.08)
        B.box((0.8, 0.4, 0.2), (bx - 0.05, by - 0.75, z + 0.3), "FFFFFF", bevel=0.08)
    for k in range(3):                                                                  # Leiter
        B.box((0.08, 0.5, 0.06), (bx - 0.68, by - 0.4, 0.75 + k * 0.3), WOOD_L)
    x4 = Part()
    x4.box((1.3, 0.45, 0.12), (1.5, fy - 0.5, 0.55), WOOD, bevel=0.03, segs=1)          # Bank
    for sx in (-0.5, 0.5):
        x4.box((0.12, 0.4, 0.4), (1.5 + sx, fy - 0.5, 0.36), WOOD_D)
    x7 = Part()
    x7.cyl(0.18, 4.0, (hx, hy, 3.5), GOLD, r=rot(0, 90, 0), sides=8, bevel=0.05, segs=1)
    star(x7, (-0.25, fy - 0.06, 2.1), 0.26, GOLD, 0.1)
    B.build("body", root); G.build("win_glow", root)
    x4.build("lv4_bench", root); x7.build("lv7_trim", root)
    finish("b_quartier")


def kistenlager():
    root, B, G = start("b_kistenlager")
    base(B, 3.6, 3.6, WOOD_D, 0.24)
    B.box((3.2, 3.2, 0.1), (0, 0, 0.27), WOOD_L, bevel=0.03, segs=1)
    ry = 0.6                                                                           # Unterstand über der hinteren Hälfte
    B.box((3.0, 0.2, 2.0), (0, 1.5, 1.3), WOOD, bevel=0.05, segs=1)
    for i in range(5):
        B.box((0.05, 0.06, 1.9), (-1.2 + i * 0.6, 1.39, 1.3), WOOD_D)
    for sx in (-1, 1):
        for y in (-0.3, 1.5):
            B.box((0.3, 0.3, 2.3), (1.4 * sx, y, 1.4), WOOD_D, bevel=0.07, segs=1)
    B.box((3.5, 2.2, 0.24), (0, ry, 2.62), RED_D, bevel=0.08)
    gable(B, (0, ry, 2.7), 3.2, 1.9, 0.8, RED, over=0.15, thick=0.2, fill=WOOD, ridge=GOLD)
    chest(B, (0, -0.85, 0.32), 1.5, GOLD, "C9772F")                                     # die große Schatzkiste
    chest(B, (-0.8, 0.85, 0.32), 0.85, STEEL_L, "4F7FD0", 12)
    chest(B, (0.75, 0.9, 0.32), 0.8, GOLD, WOOD, -10)
    chest(B, (0.7, 0.9, 0.9), 0.6, GOLD, RED, 8)
    for i, (x, y) in enumerate(((-1.25, -1.2), (-1.05, -1.4), (-1.35, -1.45), (1.3, -1.3))):  # Münzen
        B.cyl(0.15, 0.06 + (i % 3) * 0.04, (x, y, 0.36 + (i % 3) * 0.02), GOLD, sides=10)
    G.box((0.28, 0.28, 0.32), (0, 0.3, 2.2), GLOW, bevel=0.06, segs=1)                  # Laterne unterm Dach
    B.box((0.38, 0.38, 0.08), (0, 0.3, 2.4), DK)
    G.ball(0.13, (0, -1.42, 0.95), "FFF3B8", subdiv=2)                                  # funkelndes Schloss
    x4 = Part()
    chest(x4, (-0.8, 0.85, 0.94), 0.62, GOLD, "8A4FD0", -8)
    x7 = Part()
    x7.box((3.56, 2.26, 0.1), (0, ry, 2.62), GOLD, bevel=0.03, segs=1)
    star(x7, (0, ry - 0.96, 3.02), 0.26, GOLD, 0.1)
    B.build("body", root); G.build("win_glow", root)
    x4.build("lv4_chest", root); x7.build("lv7_trim", root)
    finish("b_kistenlager")


def werkstatt():
    root, B, G = start("b_werkstatt")
    base(B, 5.6, 5.6, "A7ADC6")
    W = "97A3C0"
    hx, hy = 0.65, 0.9
    B.box((3.7, 3.3, 2.4), (hx, hy, 1.35), W, bevel=0.18)
    gable(B, (hx, hy, 2.5), 3.3, 3.7, 1.35, RED, over=0.2, yaw=90, fill=W)
    fy = hy - 1.65
    B.box((2.0, 0.14, 1.9), (hx, fy, 1.12), "23262E")                                   # offenes Tor
    B.box((2.3, 0.3, 0.22), (hx, fy - 0.06, 2.15), WOOD_D, bevel=0.05, segs=1)
    for sx in (-1, 1):
        B.box((0.22, 0.3, 2.0), (hx + 1.1 * sx, fy - 0.06, 1.15), WOOD_D, bevel=0.05, segs=1)
    G.box((0.9, 0.1, 0.6), (hx + 0.3, fy - 0.04, 0.6), "FF8A2A", bevel=0.1)             # Esse glüht im Inneren
    G.box((0.5, 0.1, 0.4), (hx + 0.3, fy - 0.07, 0.55), GLOW, bevel=0.08)
    g = Part()
    gear(g, 0.62, 0.16, "F2B21E", 9)
    o = g.build("spin_gear", root, (hx, fy - 0.2, 3.05))
    o.rotation_euler = (math.radians(90), 0, 0)
    window(G, B, (hx - 1.87, hy, 1.6), 0.9, 0.7, "l")
    chimney(root, B, (hx + 1.0, hy + 0.9, 2.8), 1.6, 0.28, color=DK)
    # Amboss auf Klotz vorn links
    ax, ay = -1.75, -1.75
    B.cyl(0.42, 0.5, (ax, ay, 0.43), WOOD_D, sides=12)
    B.box((0.5, 0.4, 0.16), (ax, ay, 0.76), DK, bevel=0.03, segs=1)
    B.box((0.3, 0.26, 0.2), (ax, ay, 0.9), DK)
    B.box((0.85, 0.42, 0.24), (ax, ay, 1.1), "566078", bevel=0.05, segs=1)
    B.cyl(0.13, 0.5, (ax - 0.6, ay, 1.12), "566078", r=rot(0, -90, 0), r2=0.02, sides=8)
    beam(B, (ax + 0.1, ay - 0.1, 1.26), (ax + 0.7, ay - 0.3, 1.5), 0.06, WOOD_L)       # Hammer
    B.box((0.2, 0.34, 0.2), (ax + 0.12, ay - 0.1, 1.3), STEEL_L, bevel=0.04, segs=1, r=rot(0, 20, -18))
    empty("fx_spark", root, (ax, ay, 1.3))
    # Werkbank links an der Wand
    wx, wy = -1.95, 0.5
    B.box((1.0, 2.2, 0.16), (wx, wy, 1.0), WOOD_L, bevel=0.04, segs=1)
    for sy in (-0.95, 0.95):
        B.box((0.9, 0.14, 0.85), (wx, wy + sy, 0.55), WOOD_D)
    B.box((0.3, 0.4, 0.3), (wx - 0.2, wy + 0.7, 1.22), RED, bevel=0.06, segs=1)          # Schraubstock
    B.box((0.6, 0.4, 0.3), (wx, wy - 0.5, 1.2), "4F7FD0", bevel=0.08, segs=1)           # Werkzeugkasten
    B.box((0.4, 0.06, 0.1), (wx, wy - 0.5, 1.4), DK)
    B.torus(0.36, 0.15, (wx + 0.2, -0.95, 0.52), "23262E", seg=12, tseg=6, r=rot(0, 78, 15))  # Reifen
    x4 = Part()
    x4.box((0.6, 0.6, 0.7), (2.2, -1.85, 0.5), RED, bevel=0.08, segs=1)                  # Werkzeugwagen
    x4.box((0.66, 0.66, 0.08), (2.2, -1.85, 0.88), STEEL_L)
    for k in range(2):
        x4.box((0.5, 0.05, 0.08), (2.2, -2.16, 0.45 + k * 0.25), STEEL_L)
    x7 = Part()
    x7.cyl(0.18, 3.74, (hx, hy, 4.05), GOLD, r=rot(90, 0, 0), sides=8, bevel=0.05, segs=1)
    x7.cyl(0.24, 0.22, (hx, fy - 0.34, 3.05), GOLD, r=rot(90, 0, 0), sides=10)
    x7.cyl(0.32, 0.14, (hx + 1.0, hy + 0.9, 4.2), GOLD, sides=12)
    B.build("body", root); G.build("win_glow", root)
    x4.build("lv4_cart", root); x7.build("lv7_trim", root)
    finish("b_werkstatt")


def garage():
    root, B, G = start("b_garage")
    base(B, 7.6, 5.6, "A7ADC6")
    W = "B4BED4"
    hx, hy = 0.2, 0.68
    B.box((6.6, 3.7, 2.7), (hx, hy, 1.5), W, bevel=0.2)
    B.box((7.0, 4.1, 0.5), (hx, hy, 3.05), BLUE, bevel=0.2, segs=3)
    B.box((5.8, 3.0, 0.24), (hx, hy, 3.36), BLUE_L, bevel=0.1)
    fy = hy - 1.85
    dx = -0.9                                                                           # Rolltor
    B.box((3.7, 0.2, 2.3), (dx, fy - 0.02, 1.3), ST_D, bevel=0.06, segs=1)
    B.box((3.3, 0.16, 2.0), (dx, fy - 0.06, 1.2), "23262E")
    for i in range(4):
        B.box((3.3, 0.12, 0.25), (dx, fy - 0.14, 2.05 - i * 0.27), STEEL_L if i % 2 == 0 else "AEB6C8", bevel=0.04, segs=1)
    B.box((3.4, 0.2, 0.14), (dx, fy - 0.14, 1.12), "F2B21E", bevel=0.03, segs=1)        # Torkante
    # Auto schaut heraus
    B.box((2.0, 0.5, 0.6), (dx, fy - 0.02, 0.62), "F28A1E", bevel=0.16)
    B.box((2.2, 0.2, 0.18), (dx, fy - 0.3, 0.4), STEEL, bevel=0.05, segs=1)
    for sx in (-1, 1):
        G.box((0.34, 0.08, 0.22), (dx + 0.65 * sx, fy - 0.28, 0.72), "FFF3B8", bevel=0.04, segs=1)
    # Seitentür und Schild
    B.box((0.9, 0.12, 1.7), (2.5, fy - 0.02, 1.05), BLUE_D, bevel=0.05, segs=1)
    G.box((0.5, 0.1, 0.4), (2.5, fy - 0.06, 1.5), GLOW)
    G.box((0.24, 0.16, 0.24), (2.5, fy - 0.1, 2.3), GLOW, bevel=0.05, segs=1)
    B.box((1.9, 0.2, 0.8), (dx, fy - 0.3, 3.2), "F2B21E", bevel=0.1)                    # Schild mit Rad
    B.torus(0.22, 0.09, (dx, fy - 0.42, 3.2), "23262E", r=rot(90, 0, 0), seg=12, tseg=6)
    B.cyl(0.1, 0.1, (dx, fy - 0.42, 3.2), STEEL_L, r=rot(90, 0, 0), sides=8)
    window(G, B, (hx - 3.32, hy + 0.2, 1.8), 1.3, 0.7, "l")
    # Zapfsäule links vorn
    px, py = -3.1, -1.95
    B.box((1.1, 0.9, 0.2), (px, py, 0.28), ST_L, bevel=0.05, segs=1)
    B.box((0.7, 0.5, 1.35), (px, py, 1.0), RED, bevel=0.12)
    B.box((0.76, 0.56, 0.3), (px, py, 1.75), "F4F6FA", bevel=0.1)
    G.box((0.44, 0.06, 0.3), (px, py - 0.26, 1.3), CYAN)
    tube(B, (px + 0.36, py, 1.4), (px + 0.5, py, 0.9), 0.04, "23262E", 6)
    tube(B, (px + 0.5, py, 0.9), (px + 0.36, py, 0.6), 0.04, "23262E", 6)
    B.box((0.1, 0.1, 0.3), (px + 0.38, py, 1.45), STEEL)
    # Reifenstapel und Fass rechts vorn
    for i in range(3):
        B.torus(0.36, 0.17, (3.0 + (0.05 if i == 1 else 0), -2.0, 0.36 + i * 0.33), "23262E", seg=12, tseg=6)
    B.torus(0.36, 0.17, (2.1, -2.25, 0.55), "23262E", seg=12, tseg=6, r=rot(75, 0, 20))
    barrel(B, (3.3, -1.1, 0.18), RED)
    B.cyl(0.08, 0.9, (hx + 2.4, hy + 1.0, 3.9), STEEL, sides=6)                         # Lüfter auf dem Dach
    B.box((1.0, 0.8, 0.4), (hx + 1.6, hy + 0.6, 3.65), STEEL, bevel=0.1)
    x4 = Part()
    x4.box((0.8, 0.5, 0.7), (1.45, -1.75, 0.55), RED, bevel=0.08, segs=1)                # Werkzeugwagen
    x4.box((0.86, 0.56, 0.08), (1.45, -1.75, 0.93), STEEL_L)
    x4.cyl(0.16, 0.5, (1.45, -1.75, 1.2), "4F7FD0", sides=8, bevel=0.04, segs=1)
    x7 = Part()
    x7.box((7.1, 4.2, 0.14), (hx, hy, 3.05), GOLD, bevel=0.05, segs=1)
    x7.box((2.0, 0.14, 0.9), (dx, fy - 0.26, 3.2), GOLD, bevel=0.1)
    x7.box((0.5, 0.05, 0.3), (hx + 2.65, hy + 1.0, 4.2), GOLD, bevel=0.02, segs=1)
    B.build("body", root); G.build("win_glow", root)
    x4.build("lv4_cart", root); x7.build("lv7_trim", root)
    finish("b_garage")


def funkturm():
    root, B, G = start("b_funkturm")
    base(B, 3.6, 3.6, "A7ADC6", 0.2)
    B.box((2.7, 2.7, 1.3), (0, 0, 0.82), ST, bevel=0.2)
    B.box((3.0, 3.0, 0.34), (0, 0, 1.55), BLUE, bevel=0.14)
    B.box((0.7, 0.12, 0.95), (-0.55, -1.36, 0.68), DK, bevel=0.04, segs=1)
    window(G, B, (0.55, -1.36, 0.9), 0.6, 0.45)
    window(G, B, (-1.37, 0.0, 0.9), 0.7, 0.45, "l")
    z0, z1, r0, r1 = 1.7, 6.7, 0.85, 0.2
    def rad(z):
        return r0 + (r1 - r0) * (z - z0) / (z1 - z0)
    for sx in (-1, 1):
        for sy in (-1, 1):
            beam(B, (r0 * sx, r0 * sy, z0), (r1 * sx, r1 * sy, z1), 0.13, STEEL_L)
    lv = [z0 + i * 1.25 for i in range(5)]
    for i, z in enumerate(lv[1:]):
        w = rad(z) * 2 + 0.16
        c = RED if i % 2 == 0 else "F4F6FA"
        for s in (-1, 1):
            B.box((w, 0.1, 0.12), (0, s * rad(z), z), c)
            B.box((0.1, w, 0.12), (s * rad(z), 0, z), c)
    for i in range(4):
        za, zb = lv[i], lv[i + 1]
        ra, rb = rad(za), rad(zb)
        s = 1 if i % 2 == 0 else -1
        beam(B, (-ra * s, -ra, za), (rb * s, -rb, zb), 0.07, STEEL)
        beam(B, (-ra, ra * s, za), (-rb, -rb * s, zb), 0.07, STEEL)
        beam(B, (ra * s, ra, za), (-rb * s, rb, zb), 0.07, STEEL)
        beam(B, (ra, -ra * s, za), (rb, rb * s, zb), 0.07, STEEL)
    B.box((0.7, 0.7, 0.14), (0, 0, z1), DK, bevel=0.04, segs=1)
    B.cyl(0.05, 1.5, (0, 0, z1 + 0.75), STEEL, sides=6)
    # Drehradar oben
    d = Part()
    d.cyl(0.14, 0.3, (0, 0, 0.1), DK, sides=10)
    d.box((0.14, 0.5, 0.14), (0, 0.15, 0.3), STEEL)
    m = T(0, 0.3, 0.55) @ rot(68, 0, 0)
    d.cyl(0.18, 0.34, (0, 0, 0), "F4F6FA", r=m, r2=0.78, sides=14)
    d.cyl(0.03, 0.5, (0, 0, 0), STEEL, r=m @ T(0, 0, 0.3), sides=6)
    d.ball(0.08, (0, 0, 0), RED, r=m @ T(0, 0, 0.55), subdiv=2)
    d.build("spin_dish", root, (0, 0, z1 + 0.08))
    lp = Part()
    lp.ball(0.22, (0, 0, 0), HOT, subdiv=2)
    lp.build("pulse_lamp_glow", root, (0, 0, z1 + 1.65))
    # feste Richtschüssel am Mast
    m = T(-rad(4.3) - 0.2, -0.1, 4.3) @ rot(0, -75, 0)
    B.cyl(0.12, 0.26, (0, 0, 0), STEEL_L, r=m, r2=0.5, sides=12)
    x4 = Part()
    m = T(0.1, -rad(3.2) - 0.22, 3.2) @ rot(78, 0, 0)
    x4.cyl(0.12, 0.26, (0, 0, 0), "F4F6FA", r=m, r2=0.46, sides=12)
    x4.ball(0.07, (0, 0, 0), RED, r=m @ T(0, 0, 0.2), subdiv=2)
    x7 = Part()
    x7.box((3.06, 3.06, 0.1), (0, 0, 1.55), GOLD, bevel=0.03, segs=1)
    x7.box((0.76, 0.76, 0.08), (0, 0, z1 - 0.1), GOLD)
    x7.box((0.5, 0.04, 0.26), (0.3, 0, z1 + 1.1), GOLD, bevel=0.02, segs=1)
    B.build("body", root); G.build("win_glow", root)
    x4.build("lv4_dish", root); x7.build("lv7_trim", root)
    finish("b_funkturm")


def banner(root, name, loc, color, w=0.85, h=1.9):
    c = Part()
    c.box((w, 0.06, h), (0, 0, -h * 0.5), color, bevel=0.025, segs=1)
    c.cyl(w * 0.5 / math.cos(math.radians(45)) * 0.72, 0.06, (0, 0, -h), color, r=rot(90, 0, 0), sides=4)
    c.box((w + 0.04, 0.07, 0.12), (0, 0, -0.12), GOLD)
    star(c, (0, 0, -h * 0.5), w * 0.34, "white", 0.1)
    c.cyl(0.04, w + 0.2, (0, 0, 0), WOOD_D, r=rot(0, 90, 0), sides=6)
    return c.build(name, root, loc)


def shield(p, loc, color, r=0.42, m=None):
    mm = T(*loc) @ (m if m is not None else rot(90, 0, 0))
    p.cyl(r, 0.1, (0, 0, 0), color, r=mm, sides=12, bevel=0.03, segs=1)
    p.cyl(r + 0.05, 0.06, (0, 0, 0), STEEL_L, r=mm, sides=12)
    p.ball(r * 0.32, (0, 0, 0), GOLD, r=mm @ T(0, 0, 0.05), subdiv=2)


def clanhalle():
    root, B, G = start("b_clanhalle")
    B.box((7.5, 7.5, 0.4), (0, 0, 0.2), ST_D, bevel=0.14)
    W = "F0DDB0"
    hy = 0.75
    B.box((5.5, 5.3, 2.9), (0, hy, 1.8), W, bevel=0.2)
    B.box((5.6, 5.4, 0.7), (0, hy, 0.7), ST, bevel=0.1, segs=1)
    gable(B, (0, hy, 3.2), 5.3, 5.5, 2.1, RED_D, over=0.34, thick=0.3, yaw=90, fill=W, ridge=WOOD_D)
    fy = hy - 2.65
    for x in (-2.6, 2.6):                                                               # Fachwerk
        B.box((0.3, 0.3, 2.9), (x, fy + 0.05, 1.8), WOOD_D, bevel=0.05, segs=1)
    B.box((5.5, 0.3, 0.3), (0, fy + 0.02, 3.25), WOOD_D, bevel=0.05, segs=1)
    # gekreuzte Giebelbalken (Drachenköpfe angedeutet)
    for s in (-1, 1):
        beam(B, (0.5 * s, fy - 0.42, 4.75), (-0.55 * s, fy - 0.42, 6.15), 0.2, WOOD_D, bevel=0.04)
    # großes Rundbogentor
    B.box((2.1, 0.3, 2.0), (0, fy - 0.05, 1.4), WOOD_D, bevel=0.05, segs=1)
    B.cyl(1.05, 0.3, (0, fy - 0.05, 2.4), WOOD_D, r=rot(90, 0, 0), sides=16)
    B.box((1.8, 0.3, 1.9), (0, fy - 0.12, 1.35), WOOD, bevel=0.04, segs=1)
    B.cyl(0.9, 0.3, (0, fy - 0.12, 2.3), WOOD, r=rot(90, 0, 0), sides=16)
    B.box((0.07, 0.34, 2.75), (0, fy - 0.12, 1.8), WOOD_D)
    for z in (0.9, 1.9):
        B.box((1.8, 0.34, 0.12), (0, fy - 0.13, z), GOLD)
    for sx in (-1, 1):
        B.torus(0.11, 0.035, (0.22 * sx, fy - 0.3, 1.4), GOLD, r=rot(90, 0, 0), seg=8, tseg=4)
    B.box((3.2, 1.3, 0.2), (0, fy - 0.7, 0.5), ST_L, bevel=0.06, segs=1)                # Stufen
    B.box((2.6, 0.7, 0.2), (0, fy - 0.5, 0.7), ST_L, bevel=0.06, segs=1)
    # Säulen mit Feuerschalen
    for sx in (-1, 1):
        B.cyl(0.36, 2.2, (1.75 * sx, fy - 0.75, 1.5), ST, sides=12, bevel=0.06, segs=1)
        B.box((0.95, 0.95, 0.3), (1.75 * sx, fy - 0.75, 0.55), ST_L, bevel=0.07, segs=1)
        B.cyl(0.5, 0.3, (1.75 * sx, fy - 0.75, 2.7), DK, sides=12, r2=0.62)
        G.ball(0.36, (1.75 * sx, fy - 0.75, 2.92), "FF9A2A", subdiv=2, scale=(1, 1, 0.9))
        G.ball(0.2, (1.75 * sx, fy - 0.75, 3.2), GLOW, subdiv=2, scale=(1, 1, 1.4))
        window(G, B, (1.75 * sx, fy, 2.0), 0.6, 0.9)
    # großes Wappenschild im Giebel
    shield(B, (0, fy - 0.12, 4.15), "026AED", 0.62)
    star(B, (0, fy - 0.2, 4.15), 0.36, "white", 0.12)
    # Schilde an der linken Wand, Fenster
    for i, c in enumerate((RED, "F2B21E", "3FA35A")):
        shield(B, (-2.78, hy - 1.5 + i * 1.5, 2.3), c, 0.42, rot(0, -90, 0))
    for i in range(2):
        window(G, B, (-2.77, hy - 0.75 + i * 1.5, 1.45), 0.5, 0.5, "l", bars=False)
        window(G, B, (2.77, hy - 0.75 + i * 1.5, 1.8), 0.5, 0.7, "r", bars=False)
    # Bannermasten
    for i, (sx, c) in enumerate(((-1, RED), (1, "026AED"))):
        x = 3.15 * sx
        B.cyl(0.09, 4.4, (x, fy - 0.75, 2.6), WOOD_D, sides=8)
        B.ball(0.15, (x, fy - 0.75, 4.85), GOLD, subdiv=2)
        B.box((0.7, 0.7, 0.3), (x, fy - 0.75, 0.55), ST_L, bevel=0.06, segs=1)
        banner(root, "sway_banner%d" % (i + 1), (x, fy - 0.86, 4.5), c)
    x4 = Part()
    for sx in (-1, 1):
        shield(x4, (0.95 * sx + (0.5 * sx), fy - 0.1, 3.55), (RED, "3FA35A")[sx > 0], 0.34)
    x7 = Part()
    x7.cyl(0.2, 6.1, (0, hy, 5.52), GOLD, r=rot(90, 0, 0), sides=8, bevel=0.05, segs=1)
    for s in (-1, 1):
        x7.ball(0.2, (-0.62 * s, fy - 0.42, 6.25), GOLD, subdiv=2)
    x7.torus(0.7, 0.06, (0, fy - 0.2, 4.15), GOLD, r=rot(90, 0, 0), seg=14, tseg=4)
    B.build("body", root); G.build("win_glow", root)
    x4.build("lv4_shields", root); x7.build("lv7_trim", root)
    finish("b_clanhalle")


def labor():
    root, B, G = start("b_labor")
    base(B, 5.6, 5.6, "A7ADC6")
    W, PU = "F2F2F7", "9A5CE0"
    hx, hy = -0.3, 0.6
    B.box((4.3, 3.7, 2.2), (hx, hy, 1.25), W, bevel=0.22, segs=3)
    B.box((4.36, 3.76, 0.34), (hx, hy, 2.0), PU, bevel=0.06, segs=1)
    B.box((4.36, 3.76, 0.4), (hx, hy, 0.4), ST, bevel=0.06, segs=1)
    # Kuppel mit Spalt und Fernrohr
    B.cyl(1.6, 0.3, (hx, hy, 2.45), STEEL_L, sides=20, bevel=0.06, segs=1)
    B.ball(1.5, (hx, hy, 2.55), PU, subdiv=3, scale=(1, 1, 0.92))
    B.box((0.5, 1.9, 1.5), (0, 0, 0), "23262E", r=T(hx, hy - 0.72, 3.15) @ rot(-38, 0, 0), bevel=0.1)
    tube(B, (hx, hy - 0.4, 3.1), (hx, hy - 1.75, 4.15), 0.2, STEEL_L, 10)
    B.cyl(0.26, 0.2, (0, 0, 0), "F2B21E", r=T(hx, hy - 1.75, 4.15) @ rot(52, 0, 0), sides=10)
    fy = hy - 1.85
    B.box((1.0, 0.14, 1.6), (hx - 0.9, fy - 0.02, 1.0), DK, bevel=0.05, segs=1)         # Tür
    G.box((0.5, 0.1, 0.4), (hx - 0.9, fy - 0.06, 1.4), PURPLE)
    G.cyl(0.36, 0.1, (hx + 0.8, fy - 0.02, 1.25), PURPLE, r=rot(90, 0, 0), sides=14)     # Bullauge
    B.torus(0.38, 0.07, (hx + 0.8, fy - 0.04, 1.25), STEEL, r=rot(90, 0, 0), seg=14, tseg=6)
    window(G, B, (hx - 2.17, hy, 1.25), 1.0, 0.6, "l")
    # Dampfrohr und Kolben auf dem Dach
    B.cyl(0.2, 0.9, (hx + 1.7, hy + 1.3, 2.75), STEEL, sides=10)
    B.cyl(0.26, 0.14, (hx + 1.7, hy + 1.3, 3.2), DK, sides=10)
    empty("fx_steam", root, (hx + 1.7, hy + 1.3, 3.4))
    B.ball(0.42, (hx - 1.6, hy - 1.25, 2.72), "7CFF6A", subdiv=2)                       # grüner Glaskolben
    B.cyl(0.14, 0.5, (hx - 1.6, hy - 1.25, 3.2), "CFFFC8", sides=8)
    B.cyl(0.3, 0.16, (hx - 1.6, hy - 1.25, 2.38), DK, sides=10)
    # Tesla-Spule vorn rechts
    tx, ty = 2.05, -1.75
    B.cyl(0.6, 0.4, (tx, ty, 0.38), DK, sides=14, bevel=0.08, segs=1)
    B.cyl(0.2, 2.3, (tx, ty, 1.6), "E0A82E", sides=10)
    for i in range(4):
        B.torus(0.34 - i * 0.03, 0.08, (tx, ty, 0.95 + i * 0.5), "C96A2A", seg=12, tseg=6)
    B.torus(0.42, 0.13, (tx, ty, 2.8), STEEL_L, seg=14, tseg=6)
    o = Part()
    o.ball(0.34, (0, 0, 0), PURPLE, subdiv=3)
    o.build("pulse_orb_glow", root, (tx, ty, 3.15))
    tube(B, (tx - 0.5, ty, 0.3), (hx + 1.6, fy, 0.3), 0.09, DK, 8)                      # Kabel
    x4 = Part()
    x4.cyl(0.4, 0.3, (2.1, -0.2, 0.33), DK, sides=12, bevel=0.06, segs=1)
    x4.cyl(0.13, 1.3, (2.1, -0.2, 1.1), "E0A82E", sides=8)
    x4.torus(0.24, 0.06, (2.1, -0.2, 1.0), "C96A2A", seg=10, tseg=4)
    x4.torus(0.24, 0.06, (2.1, -0.2, 1.4), "C96A2A", seg=10, tseg=4)
    x4.ball(0.24, (2.1, -0.2, 1.9), STEEL_L, subdiv=2)
    x7 = Part()
    x7.torus(1.56, 0.1, (hx, hy, 2.62), GOLD, seg=20, tseg=6)
    x7.box((4.42, 3.82, 0.1), (hx, hy, 2.2), GOLD, bevel=0.03, segs=1)
    B.build("body", root); G.build("win_glow", root)
    x4.build("lv4_coil", root); x7.build("lv7_trim", root)
    finish("b_labor")


def schild():
    root, B, G = start("b_schild")
    B.cyl(2.7, 0.5, (0, 0, 0.25), ST, sides=20, bevel=0.14)
    B.cyl(2.15, 0.3, (0, 0, 0.6), ST_L, sides=20, bevel=0.08, segs=1)
    B.cyl(1.3, 1.5, (0, 0, 1.4), BLUE, sides=16, r2=0.85, bevel=0.1, segs=1)
    B.cyl(1.0, 0.24, (0, 0, 2.2), "F2B21E", sides=16, bevel=0.06, segs=1)
    B.cyl(0.6, 0.3, (0, 0, 2.4), DK, sides=14, r2=0.75)
    for i in range(8):                                                                  # Lichtschlitze am Sockel
        a = math.radians(i * 45 + 22.5)
        G.box((0.14, 0.3, 0.5), (math.cos(a) * 1.12, math.sin(a) * 1.12, 1.25), CYAN, r=rot(0, 0, i * 45 + 22.5))
    for i in range(4):                                                                  # gebogene Pylone
        a = math.radians(i * 90 + 45)
        ca, sa = math.cos(a), math.sin(a)
        p0, p1, p2 = (ca * 2.15, sa * 2.15, 0.6), (ca * 2.25, sa * 2.25, 2.5), (ca * 1.75, sa * 1.75, 3.7)
        beam(B, p0, p1, 0.44, BLUE_L, bevel=0.1)
        beam(B, p1, p2, 0.36, BLUE_L, bevel=0.08)
        B.ball(0.3, p1, "F2B21E", subdiv=2)
        G.ball(0.2, p2, CYAN, subdiv=2)
        B.box((0.7, 0.7, 0.3), (p0[0], p0[1], 0.75), DK, r=rot(0, 0, i * 90 + 45), bevel=0.08, segs=1)
    rg = Part()
    rg.torus(1.3, 0.13, (0, 0, 0), "F2B21E", seg=24, tseg=6)
    for i in range(4):
        a = math.radians(i * 90)
        rg.box((0.4, 0.5, 0.36), (math.cos(a) * 1.3, math.sin(a) * 1.3, 0), "5A6A8C", r=rot(0, 0, i * 90), bevel=0.08, segs=1)
    rg.build("spin_ring", root, (0, 0, 3.15))
    c = Part()
    c.ball(0.72, (0, 0, 0), CYAN, subdiv=3)
    c.build("pulse_core_glow", root, (0, 0, 3.2))
    x4 = Part()
    for i in range(4):
        a = math.radians(i * 90)
        x4.box((0.5, 0.9, 0.5), (math.cos(a) * 2.1, math.sin(a) * 2.1, 0.85), "5A6A8C", r=rot(0, 0, i * 90), bevel=0.1, segs=1)
        x4.box((0.3, 0.5, 0.1), (math.cos(a) * 2.1, math.sin(a) * 2.1, 1.12), "F2B21E", r=rot(0, 0, i * 90))
    x7 = Part()
    x7.torus(2.2, 0.09, (0, 0, 0.75), GOLD, seg=24, tseg=4)
    x7.torus(1.02, 0.07, (0, 0, 2.32), GOLD, seg=16, tseg=4)
    for i in range(4):
        a = math.radians(i * 90 + 45)
        x7.cyl(0.14, 0.4, (math.cos(a) * 1.75, math.sin(a) * 1.75, 4.05), GOLD, r2=0.01, sides=6)
    B.build("body", root); G.build("win_glow", root)
    x4.build("lv4_cells", root); x7.build("lv7_trim", root)
    finish("b_schild")


# ------------------------------------------------------------------ Fallen (flach, begehbar)
def stachel():
    root, B, G = start("b_stachel")
    B.box((1.6, 1.6, 0.16), (0, 0, 0.08), WOOD_D, bevel=0.05, segs=1)
    B.box((1.38, 1.38, 0.08), (0, 0, 0.17), "566078", bevel=0.03, segs=1)
    for i in range(9):
        x, y = -0.43 + (i % 3) * 0.43, -0.43 + (i // 3) * 0.43
        B.cyl(0.17, 0.06, (x, y, 0.22), DK, sides=8)
        B.cyl(0.13, 0.5, (x, y, 0.46), "E4E8F0", r2=0.0, sides=8)
    for sx in (-1, 1):
        for sy in (-1, 1):
            B.cyl(0.07, 0.05, (0.7 * sx, 0.7 * sy, 0.17), STEEL_L, sides=6)
    x4 = Part()
    for sx in (-1, 1):
        for sy in (-1, 1):
            x4.box((0.32, 0.32, 0.2), (0.63 * sx, 0.63 * sy, 0.1), STEEL, bevel=0.04, segs=1)
    x7 = Part()
    for i in range(9):
        x, y = -0.43 + (i % 3) * 0.43, -0.43 + (i // 3) * 0.43
        x7.cyl(0.07, 0.26, (x, y, 0.6), GOLD, r2=0.0, sides=8)
    B.build("body", root); x4.build("lv4_corners", root); x7.build("lv7_tips", root)
    finish("b_stachel")


def kleb():
    root, B, G = start("b_kleb")
    A, L, D_ = "B4D62E", "DDF06A", "86A81E"
    for (x, y, r) in ((0, 0, 1.3), (0.75, 0.6, 0.85), (-0.8, 0.55, 0.8), (-0.6, -0.8, 0.9), (0.85, -0.7, 0.75), (0.1, 1.05, 0.6), (1.18, 0.0, 0.5), (-1.18, -0.1, 0.5)):
        B.ball(r + 0.1, (x, y, 0.0), D_, subdiv=2, scale=(1, 1, 0.07 / (r + 0.1) * 1.2))
        B.ball(r, (x, y, 0.02), A, subdiv=2, scale=(1, 1, 0.14 / r))
    for (x, y, r) in ((-0.3, 0.3, 0.42), (0.6, -0.25, 0.3), (-0.55, -0.7, 0.26), (0.5, 0.75, 0.22)):
        B.ball(r, (x, y, 0.12), L, subdiv=2, scale=(1, 0.8, 0.16))
    for (x, y, r) in ((0.2, -0.75, 0.16), (-0.9, 0.3, 0.13), (0.95, 0.4, 0.14), (-0.1, 0.85, 0.1), (0.25, 0.15, 0.2)):
        B.ball(r, (x, y, 0.13), L, subdiv=2)                                            # Blasen
        B.ball(r * 0.3, (x - r * 0.4, y - r * 0.5, 0.13 + r * 0.6), "FFFFFF", subdiv=2)
    m = T(-1.15, 1.15, 0.26) @ rot(0, 90, 40)                                           # umgekippter Eimer
    B.cyl(0.26, 0.55, (0, 0, 0), "F2B21E", r=m, sides=10, bevel=0.04, segs=1)
    B.cyl(0.2, 0.03, (0, 0, 0), A, r=m @ T(0, 0, 0.28), sides=10)
    x4 = Part()
    for (x, y, r) in ((1.3, -1.2, 0.36), (-1.4, -0.9, 0.3), (1.2, 1.2, 0.34)):
        x4.ball(r, (x, y, 0.02), A, subdiv=2, scale=(1, 1, 0.3))
    x7 = Part()
    for (x, y, r) in ((0.0, -0.2, 0.12), (-0.7, 0.75, 0.1), (0.9, -0.85, 0.1), (0.7, 0.2, 0.09)):
        x7.ball(r, (x, y, 0.2), GOLD, subdiv=2)
    B.build("body", root); x4.build("lv4_blobs", root); x7.build("lv7_sparkle", root)
    finish("b_kleb")


def mine():
    root, B, G = start("b_mine")
    B.cyl(0.74, 0.14, (0, 0, 0.07), "23262E", sides=16, bevel=0.04, segs=1)
    B.cyl(0.66, 0.26, (0, 0, 0.22), "4B5670", sides=16, r2=0.5, bevel=0.05, segs=1)
    B.cyl(0.3, 0.12, (0, 0, 0.38), RED, sides=12, bevel=0.03, segs=1)
    for i in range(6):
        a = math.radians(i * 60)
        B.cyl(0.09, 0.14, (math.cos(a) * 0.6, math.sin(a) * 0.6, 0.2), STEEL_L, sides=8, bevel=0.03, segs=1)
        B.box((0.2, 0.08, 0.03), (math.cos(a + 0.52) * 0.5, math.sin(a + 0.52) * 0.5, 0.3), "F2B21E", r=rot(0, 0, i * 60 + 30))
    lp = Part()
    lp.ball(0.14, (0, 0, 0), HOT, subdiv=2)
    lp.build("pulse_lamp_glow", root, (0, 0, 0.5))
    x4 = Part()
    x4.torus(0.72, 0.05, (0, 0, 0.16), "F2B21E", seg=16, tseg=4)
    x7 = Part()
    x7.torus(0.31, 0.04, (0, 0, 0.45), GOLD, seg=12, tseg=4)
    B.build("body", root); x4.build("lv4_ring", root); x7.build("lv7_ring", root)
    finish("b_mine")


# ------------------------------------------------------------------ Deko
def laterne():
    root, B, G = start("b_laterne")
    B.cyl(0.36, 0.2, (0, 0, 0.1), ST, sides=12, bevel=0.06, segs=1)
    B.cyl(0.2, 0.2, (0, 0, 0.28), ST_D, sides=10)
    B.cyl(0.1, 2.0, (0, 0, 1.3), WOOD_D, sides=8)
    B.cyl(0.16, 0.12, (0, 0, 1.3), DK, sides=8)
    B.box((0.6, 0.6, 0.12), (0, 0, 2.3), DK, bevel=0.04, segs=1)
    for sx in (-1, 1):
        for sy in (-1, 1):
            B.box((0.07, 0.07, 0.52), (0.24 * sx, 0.24 * sy, 2.6), DK)
    B.cyl(0.5, 0.3, (0, 0, 3.0), DK, r=rot(0, 0, 45), r2=0.1, sides=4)
    B.ball(0.08, (0, 0, 3.2), GOLD, subdiv=2)
    g = Part()
    g.box((0.44, 0.44, 0.5), (0, 0, 2.6), GLOW, bevel=0.08)
    g.build("lamp_glow", root)
    B.build("body", root)
    finish("b_laterne")


def flagge():
    root, B, G = start("b_flagge")
    px = -0.36                                                                          # Mast links, damit das Tuch im Feld bleibt
    B.cyl(0.42, 0.24, (px, 0, 0.12), ST, sides=12, bevel=0.07, segs=1)
    B.cyl(0.28, 0.22, (px, 0, 0.34), ST_L, sides=12, bevel=0.05, segs=1)
    B.cyl(0.13, 0.3, (px, 0, 0.6), "F2B21E", sides=8)
    flag(root, B, (px, 0, 0.3), 3.3, "026AED", "sway_cloth", size=(1.08, 0.78), pole="E4E8F0")
    B.build("body", root)
    finish("b_flagge")


def blumen():
    root, B, G = start("b_blumen")
    B.box((1.6, 1.6, 0.3), (0, 0, 0.15), WOOD, bevel=0.07)
    for s in (-1, 1):
        B.box((1.62, 0.1, 0.1), (0, 0.74 * s, 0.26), WOOD_D)
        B.box((0.1, 1.6, 0.09), (0.74 * s, 0, 0.26), WOOD_D)
    B.box((1.36, 1.36, 0.12), (0, 0, 0.28), "6B4A2A", bevel=0.04, segs=1)
    cols = ["F4F6FA", "FFD23E", "F07AB4", "FF7043", "9A7CF0"]
    for i in range(9):
        jx, jy = (hash3(i, 1, 2) - 0.5) * 0.16, (hash3(i, 5, 3) - 0.5) * 0.16
        x, y = -0.4 + (i % 3) * 0.4 + jx, -0.4 + (i // 3) * 0.4 + jy
        h = 0.34 + hash3(i, 7, 9) * 0.3
        c = cols[(i * 2) % 5]
        B.cyl(0.035, h, (x, y, 0.3 + h * 0.5), "4F7A2A", sides=5)
        B.ball(0.14, (x - 0.1, y, 0.42), "8FB02A", subdiv=2, scale=(1, 0.5, 0.35))
        for k in range(5):
            a = math.radians(k * 72 + i * 20)
            B.ball(0.1, (x + math.cos(a) * 0.11, y + math.sin(a) * 0.11, 0.32 + h), c, subdiv=1, scale=(1, 1, 0.6))
        B.ball(0.08, (x, y, 0.35 + h), "FFD23E" if c != "FFD23E" else "FF7043", subdiv=2)
    B.build("body", root)
    finish("b_blumen")


def statue():
    root, B, G = start("b_statue")
    A, A2 = "F2B92E", "D99A1E"
    B.box((3.2, 3.2, 0.3), (0, 0, 0.15), ST_D, bevel=0.1)
    B.box((2.5, 2.5, 0.5), (0, 0, 0.5), ST, bevel=0.12)
    B.box((1.9, 1.9, 1.0), (0, 0, 1.2), ST_L, bevel=0.14)
    B.box((2.1, 2.1, 0.2), (0, 0, 1.75), ST, bevel=0.07, segs=1)
    B.box((1.2, 0.08, 0.5), (0, -0.96, 1.2), "026AED", bevel=0.03, segs=1)              # Tafel mit Stern
    star(B, (0, -1.0, 1.2), 0.2, GOLD, 0.06)
    z = 1.85                                                                            # Heldenfigur (großer Kopf, Helm)
    for sx in (-1, 1):
        B.box((0.34, 0.4, 0.6), (0.24 * sx, 0, z + 0.3), A2, bevel=0.1)
        B.box((0.38, 0.5, 0.2), (0.24 * sx, -0.05, z + 0.1), A2, bevel=0.07, segs=1)
    B.box((0.95, 0.6, 0.85), (0, 0, z + 0.95), A, bevel=0.2, segs=3)
    B.box((1.0, 0.64, 0.14), (0, 0, z + 0.62), A2, bevel=0.04, segs=1)
    B.box((1.05, 0.95, 0.9), (0, -0.02, z + 1.85), A, bevel=0.28, segs=3)               # Kopf
    B.ball(0.62, (0, 0.0, z + 2.05), A2, subdiv=3, scale=(1, 1, 0.75))                  # Helm
    B.box((1.14, 1.0, 0.14), (0, -0.02, z + 2.02), A2, bevel=0.05, segs=1)
    B.box((0.8, 0.14, 0.26), (0, -0.5, z + 2.12), A, bevel=0.07, segs=1)                # Brille
    beam(B, (-0.56, 0, z + 1.25), (-0.72, -0.1, z + 0.65), 0.3, A, bevel=0.1)           # linker Arm unten
    beam(B, (0.56, 0, z + 1.25), (0.95, -0.1, z + 2.0), 0.3, A, bevel=0.1)              # rechter Arm erhoben
    B.ball(0.2, (0.98, -0.1, z + 2.08), A2, subdiv=2)
    B.cyl(0.05, 2.3, (0.98, -0.1, z + 2.0), A2, sides=6)                                # Fahne in der Hand
    B.box((0.8, 0.06, 0.5), (1.4, -0.1, z + 2.85), A, bevel=0.03, segs=1)
    for sx in (-1, 1):
        for sy in (-1, 1):
            B.ball(0.2, (1.3 * sx, 1.3 * sy, 0.42), ST_L, subdiv=2)
    B.build("body", root)
    finish("b_statue")


# ------------------------------------------------------------------ Mauern (je EIN Objekt `body`, für MultiMesh)
def wall(kind, tier):
    name = "wall_%s_%d" % (kind, tier)
    reset()
    B = Part()
    L = 2.0
    if kind == "post":
        if tier == 0:
            B.box((0.5, 0.5, 1.7), (0, 0, 0.85), WOOD, bevel=0.1)
            B.cyl(0.36, 0.3, (0, 0, 1.78), WOOD_L, r=rot(0, 0, 45), r2=0.1, sides=4)
            B.box((0.58, 0.58, 0.16), (0, 0, 1.5), STEEL, bevel=0.04, segs=1)
            B.box((0.56, 0.56, 0.14), (0, 0, 0.12), WOOD_D, bevel=0.04, segs=1)
        elif tier == 1:
            B.box((0.9, 0.9, 2.1), (0, 0, 1.05), ST, bevel=0.14)
            B.box((1.04, 1.04, 0.26), (0, 0, 2.12), ST_D, bevel=0.08)
            B.box((0.6, 0.6, 0.16), (0, 0, 2.3), ST_L, bevel=0.05, segs=1)
            B.box((1.0, 1.0, 0.3), (0, 0, 0.15), ST_D, bevel=0.07, segs=1)
            for (x, y, z) in ((0.2, -0.46, 0.9), (-0.15, -0.46, 1.5), (0.46, 0.1, 1.3), (-0.46, -0.1, 0.8), (0.1, 0.46, 1.1)):
                if abs(y) > 0.4:
                    B.box((0.4, 0.06, 0.24), (x, y, z), ST_L, bevel=0.03, segs=1)
                else:
                    B.box((0.06, 0.4, 0.24), (x, y, z), ST_L, bevel=0.03, segs=1)
        else:
            B.box((1.0, 1.0, 2.5), (0, 0, 1.25), "5F74A6", bevel=0.16)
            B.box((1.14, 1.14, 0.26), (0, 0, 2.52), GOLD, bevel=0.08)
            B.cyl(0.5, 0.34, (0, 0, 2.8), "5F74A6", r=rot(0, 0, 45), r2=0.2, sides=4)
            B.ball(0.17, (0, 0, 3.02), GOLD, subdiv=2)
            B.box((1.1, 1.1, 0.34), (0, 0, 0.17), "3F4F7A", bevel=0.07, segs=1)
            for s in (-1, 1):
                B.box((0.5, 0.06, 1.2), (0, 0.5 * s, 1.35), "7C92C8", bevel=0.03, segs=1)
                B.box((0.06, 0.5, 1.2), (0.5 * s, 0, 1.35), "7C92C8", bevel=0.03, segs=1)
    else:
        if tier == 0:
            B.box((L, 0.16, 0.3), (0, 0, 1.25), WOOD, bevel=0.05, segs=1)
            B.box((L - 0.02, 0.16, 0.3), (0, 0, 0.6), shade(WOOD, 0.9), bevel=0.05, segs=1)
            beam(B, (-0.92, 0.0, 0.5), (0.92, 0.0, 1.32), 0.12, WOOD_D, d=0.12)
            for x in (-0.5, 0.5):                                                       # Zaunlatten
                B.box((0.22, 0.1, 1.45), (x, -0.1, 0.78), WOOD_L, bevel=0.04, segs=1)
                B.cyl(0.155, 0.09, (x, -0.1, 1.5), WOOD_L, r=rot(90, 0, 0), sides=4)
        elif tier == 1:
            B.box((L, 0.6, 1.8), (0, 0, 0.9), shade(ST, 0.95), bevel=0.08, segs=1)
            B.box((L - 0.02, 0.72, 0.22), (0, 0, 1.75), ST_D, bevel=0.06, segs=1)
            B.box((L - 0.02, 0.7, 0.26), (0, 0, 0.13), ST_D, bevel=0.06, segs=1)
            for s in (-1, 1):
                for (x, z, w) in ((-0.5, 0.75, 0.6), (0.35, 1.2, 0.7), (0.55, 0.6, 0.45), (-0.4, 1.35, 0.4)):
                    B.box((w, 0.06, 0.26), (x * s, 0.3 * s, z), ST_L, bevel=0.03, segs=1)
        else:
            B.box((L, 0.66, 2.2), (0, 0, 1.1), "7286B8", bevel=0.08, segs=1)
            B.box((L - 0.02, 0.74, 0.16), (0, 0, 1.7), GOLD, bevel=0.04, segs=1)
            B.box((L - 0.02, 0.76, 0.3), (0, 0, 0.15), "3F4F7A", bevel=0.06, segs=1)
            B.box((L - 0.02, 0.74, 0.14), (0, 0, 2.16), "4F6294", bevel=0.04, segs=1)
            for s in (-1, 1):
                B.box((1.3, 0.06, 0.8), (0, 0.33 * s, 1.0), "8FA4D6", bevel=0.04, segs=1)
                for x in (-0.82, 0.82):
                    for z in (0.6, 1.4, 1.95):
                        B.cyl(0.07, 0.06, (x, 0.34 * s, z), "C9D0DE", r=rot(90, 0, 0), sides=6)
    B.build("body")
    finish(name)


# ------------------------------------------------------------------ Verzeichnis
MODELS = {}
for _i in range(1, 6):
    MODELS["b_bunker_%d" % _i] = (lambda i=_i: bunker(i))
for _f in (saege, steinbruch, presse, raffinerie, generator, lager, quartier, kistenlager, werkstatt, garage, funkturm, clanhalle,
           labor, schild, stachel, kleb, mine, laterne, flagge, blumen, statue):
    MODELS["b_" + _f.__name__] = _f
for _t in range(3):
    MODELS["wall_post_%d" % _t] = (lambda t=_t: wall("post", t))
    MODELS["wall_link_%d" % _t] = (lambda t=_t: wall("link", t))

# Paket 6 (Auftrag V3): Bunker, Produktion, Lager und besondere Gebäude werden nach dem Detail-Katalog in blender/geb.py gebaut.
# Die alten Funktionen oben (bunker … schild) bleiben nur zum Nachschlagen stehen und werden nicht mehr aufgerufen.
import geb as _geb
MODELS.update(_geb.MODELS)

if __name__ == "__main__":
    for n in (sys.argv[1:] or list(MODELS)):
        MODELS[n]()
