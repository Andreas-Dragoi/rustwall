"""Spezialbauten der sieben Außenbasen (o_special_<gebiet>), Grundfläche höchstens 3,4 x 4 m.
Fünf Ausbaustufen: Stufe 1 = body (+ bewegte Teile), dazu lv2_* (Anbau), lv3_* (zweite Etage / Turm),
lv4_* (Verstärkung), lv5_* (goldene Zier). Leerobjekte: door, bubble, ein fx_*-Punkt."""
from exp_common import *


def tri_prism(p, c, span, h, length, color, yaw=0.0):
    """Giebeldreieck als Körper: Dreieck in der XZ-Ebene (Grundlinie `span` auf Höhe c.z, Spitze h darüber), Tiefe `length` entlang Y."""
    p.cyl(1.0, length, (0, 0, 0), color, r=T(c[0], c[1], c[2] + h / 3.0) @ rot(0, 0, yaw) @ rot(90, 0, 0) @ S(span * 0.5 / 0.866, h / 1.5, 1), sides=3)


def snow_roof(p, c, w, d, h, over=0.28, k=0.62):
    """Schneedecke auf einem Satteldach (gleiche Maße wie gable(), First entlang X)."""
    pitch = math.atan2(h, d * 0.5)
    sl = (math.hypot(d * 0.5, h) + over) * k
    for s in (-1, 1):
        cy = s * math.cos(pitch) * sl * 0.5
        cz = h - math.sin(pitch) * sl * 0.5 + 0.34
        p.box((w + over * 2 - 0.2, sl, 0.2), (c[0], c[1] + cy, c[2] + cz), SNOW, r=rot(-s * math.degrees(pitch), 0, 0), bevel=0.09, segs=2)


def stakes(p, a, b, n, h=1.2, r=0.11, color=WOOD):
    """Reihe angespitzter Pfähle von a nach b."""
    for i in range(n):
        t = i / max(n - 1, 1)
        x, y, z = a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t, a[2]
        hh = h * (1.0 - 0.12 * (i % 2))
        p.cyl(r, hh, (x, y, z + hh * 0.5), shade(color, 1.0 - 0.1 * (i % 2)), sides=6)
        p.cone(r, 0.24, (x, y, z + hh + 0.12), CUT, sides=6)


def finish_special(name, root, B, G, X2, X3, X4, X5, G3=None, G2=None):
    B.build("body", root)
    G.build("win_glow", root)
    X2.build("lv2_annex", root)
    X3.build("lv3_upper", root)
    X4.build("lv4_armor", root)
    X5.build("lv5_gold", root)
    if G2 is not None:
        G2.build("lv2_win_glow", root)
    if G3 is not None:
        G3.build("lv3_win_glow", root)
    fin(name, lv1=True)


# ------------------------------------------------------------------ Grüntal: Holzfällerlager
@model("o_special_gruental")
def sp_gruental(name):
    root, B, G = start(name)
    X2, X3, X4, X5, G3 = Part(), Part(), Part(), Part(), Part()
    base(B, 3.3, 3.9, EARTH, 0.16)
    cx, cy = -0.42, 0.75                                                   # Blockhaus 2.1 x 2.0, Front bei y = -0.25
    B.box((2.1, 2.0, 1.7), (cx, cy, 1.0), WOOD, bevel=0.08, segs=1)
    for i in range(4):
        B.box((2.13, 2.03, 0.045), (cx, cy, 0.5 + i * 0.36), shade(WOOD, 0.68))
    for sx in (-1, 1):
        for sy in (-1, 1):
            B.cyl(0.13, 1.66, (cx + 1.03 * sx, cy + 0.98 * sy, 1.0), WOOD_D, sides=7)
    gable(B, (cx, cy, 1.8), 2.1, 2.0, 0.95, GREEN, over=0.2, thick=0.2, fill=WOOD)
    door(B, (cx + 0.55, cy - 1.0, 0.16), 0.75, 1.45, WOOD_D, "5A3A22")
    window(G, B, (cx - 0.5, cy - 1.02, 1.15), 0.55, 0.55, frame=WOOD_D)
    chimney(root, B, (cx - 0.65, cy + 0.45, 2.1), 1.2, 0.2, ROCK, square=True)
    # Sägebock mit Kreissäge vorn rechts
    sx0, sy0 = 0.85, -1.15
    B.box((1.4, 0.7, 0.14), (sx0, sy0, 0.72), WOOD_L, bevel=0.04, segs=1)
    for dx in (-0.55, 0.55):
        for dy in (-0.25, 0.25):
            B.box((0.12, 0.12, 0.5), (sx0 + dx, sy0 + dy, 0.41), WOOD_D)
    B.box((0.4, 0.4, 0.36), (sx0 + 0.45, sy0 + 0.05, 0.97), RED_D, bevel=0.07, segs=1)
    log_(B, T(sx0 - 0.25, sy0 + 0.16, 0.97) @ rot(0, 90, 0), 0.18, 0.8, 8)
    s = Part()
    s.cyl(0.5, 0.05, (0, 0, 0), STEEL_L, sides=16)
    for i in range(10):
        a = math.radians(i * 36)
        s.cyl(0.11, 0.05, (math.cos(a) * 0.52, math.sin(a) * 0.52, 0), STEEL_L, r=rot(0, 0, i * 36 - 50), sides=3)
    s.cyl(0.2, 0.09, (0, 0, 0), RED, sides=10)
    s.cyl(0.07, 0.13, (0, 0, 0), DK, sides=6)
    o = s.build("spin_blade", root, (sx0 + 0.05, sy0 - 0.12, 0.92))
    o.rotation_euler = (math.radians(90), 0, 0)
    # Holzstapel, Hackklotz mit Axt
    logs(B, (-0.95, -1.2, 0.16), 3, 1.2, 0.2)
    B.cyl(0.26, 0.4, (0.05, -1.55, 0.36), BARK, sides=9)
    B.cyl(0.22, 0.02, (0.05, -1.55, 0.565), CUT, sides=9)
    beam(B, (0.05, -1.55, 0.62), (0.34, -1.6, 1.12), 0.06, WOOD_L)
    B.box((0.26, 0.06, 0.2), (0.03, -1.55, 0.68), STEEL_L, r=rot(0, 30, 0), bevel=0.02, segs=1)
    pennant(root, B, (cx - 0.92, cy, 2.85), 1.3, GREEN_D, size=(0.8, 0.5), emblem="star")
    # Stufe 2: Unterstand mit Stämmen rechts
    for y in (0.1, 1.7):
        X2.box((0.14, 0.14, 1.5), (1.5, y, 0.9), WOOD_D)
    X2.box((0.1, 1.7, 0.12), (1.5, 0.9, 1.6), WOOD_D)
    X2.box((1.1, 2.0, 0.14), (1.1, 0.9, 1.82), GREEN, r=rot(0, 16, 0), bevel=0.05, segs=1)
    logs(X2, (1.12, 0.9, 0.16), 2, 1.5, 0.21)
    for i in range(3):
        X2.box((1.0, 0.5, 0.1), (1.05, -0.3, 0.22 + i * 0.12), shade(WOOD_L, 1.0 - i * 0.07), r=rot(0, 0, i * 5 - 5), bevel=0.02, segs=1)
    # Stufe 3: Ausguck durch das Dach
    X3.box((1.4, 1.3, 1.5), (cx, cy, 2.9), WOOD_L, bevel=0.08, segs=1)
    for i in range(3):
        X3.box((1.43, 1.33, 0.04), (cx, cy, 2.55 + i * 0.36), shade(WOOD_L, 0.7))
    gable(X3, (cx, cy, 3.62), 1.4, 1.3, 0.75, GREEN, over=0.22, thick=0.18, fill=WOOD_L)
    window(G3, X3, (cx, cy - 0.67, 3.05), 0.6, 0.5, frame=WOOD_D)
    window(G3, X3, (cx + 0.72, cy, 3.05), 0.5, 0.5, "r", frame=WOOD_D, bars=False)
    X3.box((1.7, 0.3, 0.08), (cx, cy - 0.8, 2.5), WOOD_D)
    X3.box((1.7, 0.06, 0.08), (cx, cy - 0.93, 2.86), WOOD_D)
    for i in range(4):
        X3.box((0.06, 0.06, 0.36), (cx - 0.8 + i * 0.533, cy - 0.93, 2.7), WOOD_D)
    # Stufe 4: Steinsockel, Palisade
    X4.box((2.3, 2.2, 0.62), (cx, cy, 0.47), ST, bevel=0.07, segs=1)
    for (x, w) in ((-1.2, 0.5), (-0.55, 0.4), (0.45, 0.45)):
        X4.box((w, 0.06, 0.22), (x + cx + 0.5, cy - 1.1, 0.5), ST_L, bevel=0.03, segs=1)
    stakes(X4, (-1.5, 1.82, 0.16), (1.5, 1.82, 0.16), 10, 1.5)
    stakes(X4, (-1.55, -1.8, 0.16), (-1.55, -0.6, 0.16), 4, 0.9)
    for sx in (-1, 1):
        X4.box((0.12, 0.12, 1.5), (cx + 0.7 * sx, cy - 0.65, 2.9), STEEL)
    # Stufe 5: Gold
    X5.cyl(0.13, 2.0, (cx, cy, 4.56), GOLD, r=rot(0, 90, 0), sides=8, bevel=0.04, segs=1)
    for sx in (-1, 1):
        X5.ball(0.17, (cx + 1.02 * sx, cy, 4.58), GOLD, subdiv=2)
    X5.box((2.54, 0.1, 0.12), (cx, cy - 1.18, 1.74), GOLD, bevel=0.03, segs=1)
    X5.box((1.9, 0.1, 0.1), (cx, cy - 0.86, 3.56), GOLD, bevel=0.03, segs=1)
    star(X5, (cx, cy - 0.69, 3.52), 0.16, GOLD, 0.08)
    X5.cyl(0.26, 0.08, (cx + 0.55, cy - 1.1, 1.92), GOLD, r=rot(90, 0, 0), sides=10)
    X5.cyl(0.09, 0.1, (cx + 0.55, cy - 1.1, 1.92), WOOD_D, r=rot(90, 0, 0), sides=6)
    empty("door", root, (cx + 0.55, -0.9, 0))
    empty("bubble", root, (0, 0, 5.3))
    finish_special(name, root, B, G, X2, X3, X4, X5, G3)


# ------------------------------------------------------------------ Kiefernforst: Jägerhütte
def antlers(p, c, k, color):
    x, y, z = c
    for s in (-1, 1):
        limb(p, (x + 0.06 * s, y, z), (x + 0.3 * s * k, y - 0.03, z + 0.3 * k), 0.045 * k, 0.035 * k, color, 5)
        limb(p, (x + 0.3 * s * k, y - 0.03, z + 0.3 * k), (x + 0.38 * s * k, y - 0.03, z + 0.62 * k), 0.035 * k, 0.015 * k, color, 5)
        limb(p, (x + 0.22 * s * k, y - 0.03, z + 0.22 * k), (x + 0.5 * s * k, y - 0.05, z + 0.34 * k), 0.03 * k, 0.012 * k, color, 5)
        limb(p, (x + 0.33 * s * k, y - 0.03, z + 0.44 * k), (x + 0.14 * s * k, y - 0.05, z + 0.6 * k), 0.028 * k, 0.012 * k, color, 5)
    p.box((0.2 * k, 0.07, 0.16 * k), (x, y + 0.02, z - 0.02), color, bevel=0.03, segs=1)


@model("o_special_forst")
def sp_forst(name):
    root, B, G = start(name)
    X2, X3, X4, X5, G3 = Part(), Part(), Part(), Part(), Part()
    roofc, roofd = "2F7650", "235A3E"
    base(B, 3.3, 3.9, "9A8456", 0.16)
    cx, cy = -0.42, 0.45                                                   # Nurdachhaus, Front bei y = -0.75
    B.box((1.7, 2.3, 0.66), (cx, cy, 0.48), WOOD_D, bevel=0.05, segs=1)
    tri_prism(B, (cx, cy, 0.78), 1.85, 2.1, 2.3, WOOD)
    gable(B, (cx, cy, 0.72), 2.5, 2.0, 2.25, roofc, over=0.25, thick=0.2, yaw=90, ridge=roofd)
    for s in (-1, 1):                                                      # Schindelreihen
        for k in (0.3, 0.55, 0.8):
            B.box((0.07, 2.82, 0.07), (cx + s * (1.0 - k * 1.0 + 0.16), cy, 0.72 + k * 2.25 + 0.12), roofd)
    fy = cy - 1.16
    door(B, (cx, fy, 0.16), 0.75, 1.45, "6A3E22", "3E2616")
    antlers(B, (cx, fy - 0.08, 1.86), 0.9, "F1E3C4")
    G.cyl(0.17, 0.1, (cx, fy, 2.5), GLOW, r=rot(90, 0, 0), sides=10)
    B.torus(0.19, 0.04, (cx, fy - 0.04, 2.5), "3E2616", r=rot(90, 0, 0), seg=10, tseg=4)
    for sx in (-1, 1):
        B.box((0.3, 0.06, 0.4), (cx + 0.6 * sx, fy, 0.95), "3E2616")
        G.box((0.2, 0.08, 0.3), (cx + 0.6 * sx, fy - 0.01, 0.95), GLOW)
    chimney(root, B, (cx + 0.45, cy + 0.6, 1.9), 1.3, 0.2, ROCK, square=True)
    # Laterne am Galgen (schwingt)
    B.cyl(0.06, 2.0, (-1.45, -1.5, 1.16), WOOD_D, sides=6)
    B.box((0.6, 0.07, 0.07), (-1.2, -1.5, 2.1), WOOD_D)
    lt = Part()
    lt.cyl(0.012, 0.25, (0, 0, -0.125), DK, sides=4)
    lt.box((0.24, 0.24, 0.05), (0, 0, -0.27), DK)
    lt.box((0.24, 0.24, 0.05), (0, 0, -0.6), DK)
    for dx in (-1, 1):
        for dy in (-1, 1):
            lt.box((0.03, 0.03, 0.3), (0.1 * dx, 0.1 * dy, -0.44), DK)
    lo = lt.build("sway_lantern", root, (-0.95, -1.5, 2.07))
    lg = Part()
    lg.box((0.17, 0.17, 0.26), (0, 0, -0.44), "FFC24D", bevel=0.04, segs=1)
    lg.build("lamp_glow", lo)
    # Wetterfahne auf dem First
    B.cyl(0.03, 0.5, (cx, cy - 1.0, 3.42), DK, sides=5)
    v = Part()
    v.box((0.8, 0.04, 0.05), (0, 0, 0.1), DK)
    v.cyl(0.14, 0.04, (0.42, 0, 0.1), DK, r=rot(90, 0, 0) @ rot(0, 0, -90), sides=3)
    v.box((0.2, 0.04, 0.24), (-0.36, 0, 0.14), DK)
    v.ball(0.06, (0, 0, 0.1), GOLD, subdiv=2)
    vo = v.build("spin_vane", root, (cx, cy - 1.0, 3.62))
    # Trockengestell mit Fellen, Hackklotz
    for x in (0.75, 1.5):
        B.cyl(0.05, 1.5, (x, -1.4, 0.9), WOOD_D, sides=5)
    B.cyl(0.04, 1.0, (1.125, -1.4, 1.62), WOOD, r=rot(0, 90, 0), sides=5)
    B.box((0.3, 0.05, 0.7), (0.95, -1.4, 1.26), "B5743A", bevel=0.1, segs=1)
    B.box((0.26, 0.05, 0.56), (1.32, -1.4, 1.32), "D9C3A0", bevel=0.09, segs=1)
    B.cyl(0.24, 0.36, (0.2, -1.5, 0.34), BARK, sides=8)
    B.cyl(0.2, 0.02, (0.2, -1.5, 0.525), CUT, sides=8)
    mushroom(B, -1.3, -0.9, 0.16, 0.7)
    mushroom(B, -1.05, -1.05, 0.16, 0.45, "E8862A")
    # Stufe 2: Holzschuppen und Räuchertonne rechts
    for y in (-0.2, 1.3):
        X2.box((0.12, 0.12, 1.3), (1.5, y, 0.8), WOOD_D)
    X2.box((0.1, 1.5, 0.1), (1.5, 0.55, 1.42), WOOD_D)
    X2.box((0.75, 1.9, 0.12), (1.25, 0.55, 1.56), roofc, r=rot(0, 14, 0), bevel=0.04, segs=1)
    for r in range(3):
        for i in range(5):
            y = -0.1 + i * 0.3 + (0.15 if r % 2 else 0)
            X2.cyl(0.14, 0.5, (1.25, y, 0.3 + r * 0.27), BARK, r=rot(0, 90, 0), sides=6)
            X2.cyl(0.11, 0.52, (1.25, y, 0.3 + r * 0.27), CUT, r=rot(0, 90, 0), sides=6)
    barrel(X2, (1.25, 1.62, 0.16), "6A4A32", 0.26, 0.7)
    # Stufe 3: Hochsitz über dem Schuppen
    hx, hy = 1.05, 0.55
    for sx in (-1, 1):
        for sy in (-1, 1):
            beam(X3, (hx + 0.5 * sx, hy + 0.75 * sy, 0.16), (hx + 0.38 * sx, hy + 0.55 * sy, 3.1), 0.1, WOOD_D)
    for sy in (-1, 1):
        beam(X3, (hx - 0.48, hy + 0.72 * sy, 1.9), (hx + 0.42, hy + 0.6 * sy, 2.95), 0.07, WOOD)
    X3.box((1.1, 1.5, 0.12), (hx, hy, 3.12), WOOD_L, bevel=0.03, segs=1)
    X3.box((0.85, 1.1, 0.95), (hx, hy + 0.1, 3.65), WOOD, bevel=0.06, segs=1)
    gable(X3, (hx, hy + 0.1, 4.1), 1.2, 0.9, 0.55, roofc, over=0.12, thick=0.12, yaw=90, ridge=roofd)
    tri_prism(X3, (hx, hy + 0.1, 4.1), 0.85, 0.5, 1.1, WOOD)
    G3.box((0.5, 0.08, 0.34), (hx, hy - 0.46, 3.72), GLOW)
    X3.box((0.6, 0.06, 0.06), (hx, hy - 0.47, 3.52), WOOD_D)
    for s in (-1, 1):                                                      # Leiter vorn
        beam(X3, (hx + 0.18 * s, -1.0, 0.16), (hx + 0.18 * s, hy - 0.78, 3.1), 0.05, WOOD_L)
    for i in range(7):
        t = (i + 0.7) / 8
        X3.box((0.4, 0.05, 0.05), (hx, -1.0 + (hy - 0.78 + 1.0) * t, 0.16 + 2.94 * t), WOOD_L)
    # Stufe 4: Steinsockel und Zaun
    for sx in (-1, 1):
        X4.box((0.5, 0.5, 1.0), (cx + 0.92 * sx, fy + 0.12, 0.62), ST, bevel=0.1, segs=1)
        X4.box((0.56, 0.56, 0.14), (cx + 0.92 * sx, fy + 0.12, 1.16), ST_D, bevel=0.04, segs=1)
    X4.box((2.0, 0.24, 0.5), (cx, cy + 1.2, 0.4), ST, bevel=0.06, segs=1)
    stakes(X4, (-1.55, -1.1, 0.16), (-1.55, 1.8, 0.16), 9, 1.1)
    stakes(X4, (-1.2, 1.82, 0.16), (0.5, 1.82, 0.16), 6, 1.1)
    # Stufe 5: goldenes Geweih, First, Zier
    antlers(X5, (cx, fy - 0.12, 1.84), 1.25, GOLD)
    X5.cyl(0.14, 3.2, (cx, cy, 3.16), GOLD, r=rot(90, 0, 0), sides=8, bevel=0.04, segs=1)
    X5.ball(0.16, (cx, cy - 1.62, 3.16), GOLD, subdiv=2)
    X5.box((0.08, 0.1, 0.1), (cx, fy - 0.06, 2.5), GOLD)
    X5.torus(0.2, 0.05, (cx, fy - 0.08, 2.5), GOLD, r=rot(90, 0, 0), seg=10, tseg=4)
    for sx in (-1, 1):
        X5.cone(0.12, 0.3, (cx + 0.92 * sx, fy + 0.12, 1.38), GOLD, sides=6)
    X5.cyl(0.1, 1.5, (hx, hy + 0.1, 4.78), GOLD, r=rot(90, 0, 0), sides=6)
    empty("door", root, (cx, fy - 0.7, 0))
    empty("bubble", root, (0, 0, 5.3))
    finish_special(name, root, B, G, X2, X3, X4, X5, G3)


# ------------------------------------------------------------------ Staubebene: Tankstelle
def fuel_drop(p, m, k, color):
    p.ball(0.5 * k, (0, 0, 0), color, r=m @ T(0, 0, -0.12 * k) @ S(1, 0.3, 1), subdiv=2)
    p.cone(0.36 * k, 0.6 * k, (0, 0, 0), color, r=m @ T(0, 0, 0.42 * k) @ S(1, 0.3, 1), sides=8)


@model("o_special_staub")
def sp_staub(name):
    root, B, G = start(name)
    X2, X3, X4, X5, G3 = Part(), Part(), Part(), Part(), Part()
    cream, white = "F6E7C4", "FFF6E0"
    base(B, 3.3, 3.9, CONC, 0.14)
    kx, ky = -0.4, 1.2                                                     # Kassenhaus, Front bei y = 0.55
    B.box((2.3, 1.3, 1.9), (kx, ky, 1.09), cream, bevel=0.12)
    B.box((2.34, 1.34, 0.3), (kx, ky, 0.3), "C9B28A", bevel=0.04, segs=1)
    B.box((2.34, 1.34, 0.26), (kx, ky, 1.86), RED, bevel=0.05, segs=1)
    B.box((2.5, 1.5, 0.14), (kx, ky, 2.1), "E9EDF3", bevel=0.05, segs=1)
    G.box((1.05, 0.1, 0.66), (kx - 0.5, 0.53, 1.25), GLOW, bevel=0.03, segs=1)
    B.box((1.2, 0.08, 0.8), (kx - 0.5, 0.56, 1.25), DK)
    B.box((0.05, 0.08, 0.66), (kx - 0.5, 0.5, 1.25), DK)
    door(B, (kx + 0.7, 0.55, 0.14), 0.65, 1.5, "3F8FD0", DK)
    B.cyl(0.07, 0.6, (kx - 0.9, ky + 0.35, 2.4), STEEL, sides=6)                                   # Entlüftung
    B.cyl(0.12, 0.08, (kx - 0.9, ky + 0.35, 2.72), STEEL_L, sides=6)
    empty("fx_steam", root, (kx - 0.9, ky + 0.35, 2.9))
    # Vordach auf zwei Säulen
    B.box((3.1, 2.2, 0.32), (0, -0.7, 2.76), RED, bevel=0.1)
    B.box((3.14, 2.24, 0.1), (0, -0.7, 2.76), white, bevel=0.03, segs=1)
    G.box((1.6, 0.6, 0.04), (0, -0.9, 2.59), "FFF3B8")
    for sx in (-1, 1):
        B.cyl(0.11, 2.5, (1.25 * sx, -1.5, 1.39), white, sides=8)
        B.cyl(0.17, 0.4, (1.25 * sx, -1.5, 0.34), RED, sides=8, bevel=0.04, segs=1)
    # Zapfsäulen
    B.box((1.9, 0.8, 0.14), (0, -0.85, 0.2), CONC_D, bevel=0.05, segs=1)
    for sx, c in ((-1, RED), (1, YEL)):
        x = 0.52 * sx
        B.box((0.46, 0.38, 1.1), (x, -0.85, 0.82), c, bevel=0.1)
        B.box((0.5, 0.42, 0.14), (x, -0.85, 1.42), white, bevel=0.05, segs=1)
        B.box((0.34, 0.05, 0.3), (x, -1.05, 1.08), DK)
        G.box((0.26, 0.05, 0.14), (x, -1.07, 1.14), "9CFF6A")
        tube(B, (x + 0.25 * sx, -0.85, 1.2), (x + 0.36 * sx, -0.85, 0.75), 0.035, DK, 5)
        tube(B, (x + 0.36 * sx, -0.85, 0.75), (x + 0.26 * sx, -0.95, 0.95), 0.035, DK, 5)
        B.box((0.08, 0.2, 0.1), (x + 0.26 * sx, -1.0, 0.98), STEEL)
    # hoher Mast mit drehendem Schild
    px, py = -1.1, -1.75
    B.cyl(0.08, 3.7, (px, py, 1.99), STEEL, sides=6)
    B.cyl(0.16, 0.2, (px, py, 0.24), DK, sides=6)
    sg = Part()
    sg.cyl(0.55, 0.14, (0, 0, 0.6), YEL, r=rot(90, 0, 0), sides=14, bevel=0.03, segs=1)
    sg.torus(0.55, 0.06, (0, 0, 0.6), RED, r=rot(90, 0, 0), seg=14, tseg=5)
    for s in (-1, 1):
        fuel_drop(sg, T(0, 0.08 * s, 0.56), 0.5, RED)
    sg.cyl(0.05, 0.1, (0, 0, 0.02), DK, sides=6)
    sg.build("spin_sign", root, (px, py, 3.82))
    # Fahnenkette am Vordach (schwingt)
    bn = Part()
    bn.box((1.5, 0.03, 0.03), (0, 0, -0.02), DK)
    for i in range(5):
        bn.cyl(0.16, 0.03, (-0.6 + i * 0.3, 0, -0.14), (RED, YEL, "3F8FD0")[i % 3], r=rot(90, 0, 0) @ rot(0, 0, 180), sides=3)
    bn.build("sway_banner", root, (0, -1.82, 2.6))
    # Stufe 2: liegender Tank rechts hinten
    tx, ty = 1.18, 1.15
    X2.cyl(0.42, 1.5, (tx, ty, 0.8), white, r=rot(90, 0, 0), sides=12, bevel=0.14, segs=2)
    X2.cyl(0.43, 0.3, (tx, ty, 0.8), RED, r=rot(90, 0, 0), sides=12)
    for dy in (-0.45, 0.45):
        X2.box((0.7, 0.2, 0.45), (tx, ty + dy, 0.38), CONC_D, bevel=0.04, segs=1)
    X2.cyl(0.09, 0.2, (tx, ty + 0.3, 1.28), STEEL, sides=6)
    tube(X2, (tx, ty - 0.2, 1.2), (tx, ty - 0.2, 1.5), 0.05, STEEL, 5)
    tube(X2, (tx, ty - 0.2, 1.5), (kx + 1.1, ty - 0.2, 1.5), 0.05, STEEL, 5)
    barrel(X2, (1.3, 0.1, 0.14), RED, 0.25, 0.7)
    # Stufe 3: Obergeschoss mit Leuchtband
    X3.box((1.9, 1.1, 1.25), (kx, ky + 0.05, 2.78), cream, bevel=0.1)
    X3.box((1.94, 1.14, 0.22), (kx, ky + 0.05, 3.3), RED, bevel=0.04, segs=1)
    X3.box((2.1, 1.3, 0.12), (kx, ky + 0.05, 3.5), "E9EDF3", bevel=0.04, segs=1)
    G3.box((1.4, 0.08, 0.34), (kx, ky - 0.5, 3.02), GLOW, bevel=0.03, segs=1)
    X3.box((1.5, 0.06, 0.44), (kx, ky - 0.47, 3.02), DK)
    G3.box((0.08, 0.7, 0.34), (kx - 0.95, ky + 0.05, 3.0), GLOW)
    fuel_drop(G3, T(kx, ky - 0.2, 4.0), 0.55, "FF6A3A")
    X3.cyl(0.04, 0.3, (kx, ky - 0.2, 3.66), DK, sides=5)
    # Stufe 4: Poller, Stahlmanschetten, Reifen
    for (x, y) in ((-1.5, -0.9), (1.52, -0.9), (-0.52, -1.75), (0.52, -1.75)):
        X4.cyl(0.1, 0.7, (x, y, 0.49), YEL, sides=7)
        X4.cyl(0.105, 0.16, (x, y, 0.6), "23262E", sides=7)
    for sx in (-1, 1):
        X4.cyl(0.15, 0.24, (1.25 * sx, -1.5, 2.44), STEEL, sides=8)
        X4.cyl(0.15, 0.18, (1.25 * sx, -1.5, 1.3), STEEL, sides=8)
        for y in (-1.7, 0.3):
            X4.box((0.3, 0.3, 0.38), (1.45 * sx, y, 2.76), STEEL, bevel=0.04, segs=1)
        beam(X4, (1.25 * sx, -1.5, 2.1), (0.85 * sx, -1.5, 2.58), 0.07, STEEL)
    for i in range(2):
        tire(X4, T(1.32, -0.15, 0.27 + i * 0.25), 0.33, 0.24)
    # Stufe 5: Gold
    X5.box((3.2, 2.3, 0.07), (0, -0.7, 2.65), GOLD, bevel=0.03, segs=1)
    X5.box((3.2, 2.3, 0.07), (0, -0.7, 2.86), GOLD, bevel=0.03, segs=1)
    star(X5, (0, -1.83, 2.76), 0.2, GOLD, 0.08)
    for sx in (-1, 1):
        X5.box((0.52, 0.44, 0.08), (0.52 * sx, -0.85, 1.52), GOLD, bevel=0.03, segs=1)
        X5.ball(0.12, (0.52 * sx, -0.85, 1.62), GOLD, subdiv=2)
    X5.box((2.16, 1.36, 0.06), (kx, ky + 0.05, 3.5), GOLD, bevel=0.02, segs=1)
    X5.ball(0.14, (px, py, 4.98), GOLD, subdiv=2)
    X5.cyl(0.04, 0.12, (px, py, 4.9), GOLD, sides=5)
    empty("door", root, (kx + 0.7, 0.2, 0))
    empty("bubble", root, (0, 0, 5.4))
    finish_special(name, root, B, G, X2, X3, X4, X5, G3)


# ------------------------------------------------------------------ Schrottküste: Schrotthafen
def anchor(p, m, k, color):
    p.box((0.1 * k, 0.08 * k, 1.0 * k), (0, 0, 0), color, r=m @ T(0, 0, 0.55 * k))
    p.box((0.5 * k, 0.08 * k, 0.09 * k), (0, 0, 0), color, r=m @ T(0, 0, 0.88 * k))
    p.torus(0.11 * k, 0.035 * k, (0, 0, 0), color, r=m @ T(0, 0, 1.14 * k) @ rot(90, 0, 0), seg=8, tseg=4)
    for s in (-1, 1):
        p.box((0.42 * k, 0.08 * k, 0.1 * k), (0, 0, 0), color, r=m @ T(0.17 * k * s, 0, 0.14 * k) @ rot(0, -32 * s, 0))
        p.cone(0.1 * k, 0.2 * k, (0, 0, 0), color, r=m @ T(0.36 * k * s, 0, 0.3 * k) @ rot(0, 20 * s, 0), sides=4)


@model("o_special_kueste")
def sp_kueste(name):
    root, B, G = start(name)
    X2, X3, X4, X5, G3 = Part(), Part(), Part(), Part(), Part()
    teal = "3FA7A0"
    # Steg: Bohlen auf Pfählen
    B.box((3.3, 3.9, 0.2), (0, 0, 0.3), WOOD_L, bevel=0.04, segs=1)
    for i in range(1, 9):
        B.box((3.28, 0.03, 0.02), (0, -1.95 + i * 3.9 / 9, 0.405), shade(WOOD_L, 0.68))
    for (x, y) in ((-1.55, -1.85), (1.55, -1.85), (-1.55, 1.85), (1.55, 1.85), (-1.55, 0), (1.55, 0), (0, -1.85)):
        B.cyl(0.15, 1.0, (x, y, 0.5), WOOD_D, sides=7)
        B.cyl(0.16, 0.08, (x, y, 0.92), "D9D2C0", sides=7)
    B.box((3.1, 0.1, 0.2), (0, -1.88, 0.14), WOOD_D)
    # Wellblechbude hinten rechts, Front bei y = 0.3
    sx0, sy0 = 0.75, 1.05
    B.box((1.6, 1.5, 1.6), (sx0, sy0, 1.2), teal, bevel=0.06, segs=1)
    corr(B, (1.6, 0.04, 1.5), (sx0, sy0 - 0.76, 1.2), shade(teal, 0.8), 8)
    corr(B, (1.5, 0.04, 1.5), (sx0 - 0.81, sy0, 1.2), shade(teal, 0.8), 7, "y")
    mono(B, (sx0, sy0, 2.18), 1.9, 1.8, 0.3, RUST, 0.12, rim=RUST_D)
    door(B, (sx0 + 0.35, sy0 - 0.77, 0.4), 0.6, 1.3, RUST_D, DK)
    window(G, B, (sx0 - 0.4, sy0 - 0.78, 1.4), 0.4, 0.45, frame=DK, bars=False)
    B.torus(0.2, 0.065, (sx0 - 0.4, sy0 - 0.82, 0.75), RED, r=rot(90, 0, 0), seg=10, tseg=5)       # Rettungsring
    for a in (0, 90, 180, 270):
        B.box((0.1, 0.05, 0.14), (sx0 - 0.4 + math.cos(math.radians(a)) * 0.2, sy0 - 0.86, 0.75 + math.sin(math.radians(a)) * 0.2), "FFFFFF", r=rot(0, a + 90, 0))
    # drehendes Radar auf der Bude
    B.cyl(0.05, 0.4, (sx0 + 0.4, sy0 + 0.3, 2.4), DK, sides=5)
    rd = Part()
    rd.box((0.9, 0.12, 0.16), (0, 0, 0.08), "F4F6FA", bevel=0.04, segs=1)
    rd.cyl(0.07, 0.1, (0, 0, -0.02), DK, sides=6)
    rd.build("spin_radar", root, (sx0 + 0.4, sy0 + 0.3, 2.62))
    # Kran links, Ausleger nach vorn rechts
    kx, ky = -0.95, 0.75
    B.box((1.0, 1.0, 0.5), (kx, ky, 0.65), DK, bevel=0.08, segs=1)
    B.cyl(0.3, 0.3, (kx, ky, 1.02), STEEL, sides=10)
    B.box((0.9, 0.9, 0.85), (kx, ky, 1.58), YEL, bevel=0.12)
    B.box((0.92, 0.5, 0.36), (kx + 0.1, ky - 0.22, 1.72), "2E4A66", bevel=0.05, segs=1)
    B.box((0.5, 0.94, 0.36), (kx + 0.22, ky - 0.1, 1.72), "2E4A66", bevel=0.05, segs=1)
    B.box((0.4, 0.7, 0.5), (kx - 0.5, ky + 0.2, 1.4), CONC_D, bevel=0.06, segs=1)                    # Gegengewicht
    tip = (0.75, -0.55, 3.5)
    foot = (kx + 0.1, ky - 0.1, 2.0)
    dv = (Vector(tip) - Vector(foot)); side = Vector((-dv.y, dv.x, 0)).normalized()
    for s in (-1, 1):
        beam(B, Vector(foot) + side * 0.2 * s, Vector(tip) + side * 0.06 * s, 0.09, YEL)
        beam(B, Vector(foot) + side * 0.2 * s + Vector((0, 0, 0.0)), Vector(foot) + dv * 0.5 + Vector((0, 0, 0.32)), 0.06, YEL)
    beam(B, Vector(foot) + dv * 0.5 + Vector((0, 0, 0.32)), Vector(tip), 0.06, YEL)
    for i in range(1, 6):
        t = i / 6.0
        q = Vector(foot) + dv * t
        beam(B, q - side * (0.24 - 0.15 * t), q + side * (0.24 - 0.15 * t), 0.07, "23262E")
    top = (kx - 0.3, ky + 0.15, 3.1)
    for s in (-1, 1):
        beam(B, (kx - 0.3, ky + 0.15 + 0.25 * s, 2.0), top, 0.08, YEL)
    tube(B, top, tip, 0.02, DK, 4)
    tube(B, top, (kx - 0.5, ky + 0.2, 1.6), 0.02, DK, 4)
    B.cyl(0.12, 0.2, tip, DK, r=face_to(side), sides=8)
    hk = Part()
    hk.cyl(0.015, 1.3, (0, 0, -0.65), DK, sides=4)
    hk.box((0.2, 0.14, 0.24), (0, 0, -1.36), YEL, bevel=0.04, segs=1)
    hk.cyl(0.32, 0.16, (0, 0, -1.58), "3A3E4A", sides=10, bevel=0.03, segs=1)
    hk.box((0.5, 0.36, 0.1), (0.05, 0, -1.72), RUST, r=rot(0, 8, 20), bevel=0.02, segs=1)
    hk.cyl(0.14, 0.08, (-0.14, 0.05, -1.78), STEEL, sides=8)
    hk.build("sway_hook", root, tip)
    # Schrotthaufen und Anker vorn rechts unter dem Haken
    rng = random.Random(7)
    for i, (x, y, z, s) in enumerate(((0.95, -0.95, 0.6, 0.66), (0.5, -1.2, 0.56, 0.5), (1.2, -0.5, 0.55, 0.45), (0.75, -0.8, 0.95, 0.46), (0.3, -0.7, 0.5, 0.36))):
        rockc(B, (s, s * 0.8, s * 0.6), (x, y, z), (RUST, RUST_D, STEEL, RUST_L, "3FA7A0")[i], rng, 0.1)
    B.cyl(0.07, 0.9, (0.6, -0.9, 0.8), STEEL_L, r=rot(60, 0, 30), sides=6)
    tire(B, T(1.25, -1.3, 0.52) @ rot(20, 10, 0), 0.3, 0.22)
    anchor(B, T(0.1, -1.6, 0.4) @ rot(-14, 0, 0) @ rot(0, 10, 0), 0.9, "4A5068")
    empty("fx_spark", root, (0.75, -0.85, 1.3))
    # Stufe 2: Container vorn links
    cxx, cyy = -1.0, -1.15
    X2.box((1.1, 1.4, 1.0), (cxx, cyy, 0.9), ORANGE, bevel=0.04, segs=1)
    corr(X2, (1.4, 0.03, 0.86), (cxx - 0.56, cyy, 0.9), shade(ORANGE, 0.78), 7, "y")
    corr(X2, (1.1, 0.03, 0.86), (cxx, cyy - 0.71, 0.9), shade(ORANGE, 0.78), 5)
    X2.box((0.8, 1.0, 0.7), (cxx, cyy + 0.1, 1.75), BLUE, r=rot(0, 0, 12), bevel=0.04, segs=1)
    X2.box((0.03, 0.9, 0.6), (cxx - 0.42, cyy + 0.02, 1.75), shade(BLUE, 0.75), r=rot(0, 0, 12))
    X2.box((0.7, 0.03, 0.6), (cxx + 0.09, cyy - 0.4, 1.75), shade(BLUE, 0.75), r=rot(0, 0, 12))
    # Stufe 3: Obergeschoss mit Leuchtfeuer
    X3.box((1.4, 1.25, 1.1), (sx0, sy0, 2.75), CREAM, bevel=0.08, segs=1)
    X3.box((1.5, 1.35, 0.12), (sx0, sy0, 2.24), WOOD_D)
    mono(X3, (sx0, sy0, 3.42), 1.7, 1.55, 0.25, BLUE, 0.12, rim=BLUE_D)
    window(G3, X3, (sx0, sy0 - 0.64, 2.8), 0.8, 0.45, frame=DK)
    window(G3, X3, (sx0 - 0.71, sy0, 2.8), 0.6, 0.45, "l", frame=DK, bars=False)
    X3.cyl(0.12, 0.3, (sx0 - 0.35, sy0 + 0.2, 3.6), DK, sides=6)
    G3.cyl(0.14, 0.26, (sx0 - 0.35, sy0 + 0.2, 3.86), "FF5A4A", sides=8)
    X3.cone(0.18, 0.16, (sx0 - 0.35, sy0 + 0.2, 4.06), DK, sides=8)
    # Stufe 4: Spundwand hinten und rechts, Reifenfender, Stahlecken
    for i in range(7):
        X4.box((0.44, 0.18, 1.0 + 0.1 * (i % 2)), (-1.4 + i * 0.46, 1.84, 0.9), STEEL if i % 2 else "6E7890", bevel=0.03, segs=1)
    for i in range(4):
        X4.box((0.18, 0.44, 1.0 + 0.1 * (i % 2)), (1.6, 0.2 + i * 0.46, 0.9), "6E7890" if i % 2 else STEEL, bevel=0.03, segs=1)
    for x in (-0.9, 0.1, 1.0):
        tire(X4, T(x, -1.9, 0.42) @ rot(90, 0, 0), 0.3, 0.2)
    for y in (-1.2, -0.4):
        tire(X4, T(-1.6, y, 0.42) @ rot(0, 90, 0), 0.3, 0.2)
    for s in (-1, 1):
        X4.box((0.14, 0.14, 1.7), (sx0 + 0.78 * s, sy0 - 0.74, 1.25), STEEL, bevel=0.03, segs=1)
        beam(X4, (kx + 0.5 * s, ky - 0.52, 0.42), (kx - 0.5 * s, ky - 0.52, 0.9), 0.07, STEEL_L)
    # Stufe 5: Gold
    anchor(X5, T(sx0 + 0.0, sy0 - 0.72, 3.5), 0.55, GOLD)
    X5.cyl(0.16, 0.26, tip, GOLD, r=face_to(side), sides=8)
    X5.ball(0.14, top, GOLD, subdiv=2)
    for (x, y) in ((-1.55, -1.85), (1.55, -1.85), (0, -1.85), (-1.55, 0), (1.55, 0)):
        X5.cyl(0.17, 0.1, (x, y, 1.0), GOLD, sides=7)
        X5.ball(0.1, (x, y, 1.1), GOLD, subdiv=2)
    X5.box((1.74, 0.1, 0.1), (sx0, sy0 - 0.78, 3.56), GOLD, bevel=0.03, segs=1)
    X5.box((0.96, 0.96, 0.08), (kx, ky, 2.02), GOLD, bevel=0.03, segs=1)
    empty("door", root, (sx0 + 0.35, -0.2, 0))
    empty("bubble", root, (0, 0, 5.0))
    finish_special(name, root, B, G, X2, X3, X4, X5, G3)


# ------------------------------------------------------------------ Sumpfwerk: Pumpwerk
def pipe(p, pts, r, color, flange=STEEL, sides=8):
    for i in range(len(pts) - 1):
        tube(p, pts[i], pts[i + 1], r, color, sides)
        if 0 < i:
            p.ball(r * 1.12, pts[i], color, subdiv=2)
    for q, d in ((pts[0], Vector(pts[1]) - Vector(pts[0])), (pts[-1], Vector(pts[-2]) - Vector(pts[-1]))):
        p.cyl(r * 1.3, 0.08, (0, 0, 0), flange, r=T(*q) @ face_to(d) @ T(0, 0, 0.04), sides=sides)


@model("o_special_sumpf")
def sp_sumpf(name):
    root, B, G = start(name)
    X2, X3, X4, X5, G3, G2 = Part(), Part(), Part(), Part(), Part(), Part()
    pg, tank = "4FA36A", "DDE8E0"
    base(B, 3.3, 3.9, "A3A78E", 0.16)
    B.cyl(0.5, 0.02, (-0.9, -1.35, 0.17), "7FB03A", r=S(1.2, 0.8, 1), sides=10)                    # Tümpel
    B.cyl(0.3, 0.025, (-0.8, -1.4, 0.172), "A9D24A", r=S(1.2, 0.8, 1), sides=8)
    hx, hy = -0.6, 0.95                                                    # Backsteinhaus, Front bei y = 0.1
    B.box((1.9, 1.7, 1.9), (hx, hy, 1.1), BRICK, bevel=0.08, segs=1)
    for i in range(4):
        B.box((1.92, 1.72, 0.035), (hx, hy, 0.55 + i * 0.4), BRICK_D)
    B.box((1.96, 1.76, 0.3), (hx, hy, 0.3), CONC_D, bevel=0.04, segs=1)
    B.box((2.1, 1.9, 0.18), (hx, hy, 2.12), "6E7890", bevel=0.05, segs=1)
    door(B, (hx - 0.45, hy - 0.86, 0.16), 0.7, 1.45, "4F6A5C", DK)
    G.cyl(0.25, 0.1, (hx + 0.45, hy - 0.84, 1.45), "C8F26A", r=rot(90, 0, 0), sides=10)
    B.torus(0.27, 0.05, (hx + 0.45, hy - 0.88, 1.45), DK, r=rot(90, 0, 0), seg=10, tseg=4)
    B.box((0.56, 0.06, 0.05), (hx + 0.45, hy - 0.9, 1.45), DK)
    B.box((0.05, 0.06, 0.56), (hx + 0.45, hy - 0.9, 1.45), DK)
    B.cyl(0.17, 0.9, (hx - 0.55, hy + 0.4, 2.6), "6E7890", sides=8)                                # Schlot
    B.cyl(0.22, 0.12, (hx - 0.55, hy + 0.4, 3.02), DK, sides=8)
    empty("fx_steam", root, (hx - 0.55, hy + 0.4, 3.25))
    # Pumpe vorn rechts: Zylinder mit Kolben, Schwungrad
    px, py = 0.85, -1.0
    B.box((1.3, 1.1, 0.26), (px - 0.1, py, 0.29), DK, bevel=0.05, segs=1)
    B.cyl(0.36, 1.0, (px, py, 0.9), ORANGE, sides=12, bevel=0.06, segs=1)
    B.cyl(0.4, 0.12, (px, py, 1.36), STEEL, sides=12)
    B.cyl(0.4, 0.1, (px, py, 0.5), STEEL, sides=12)
    G.cyl(0.11, 0.05, (px, py - 0.36, 1.0), "C8F26A", r=rot(90, 0, 0), sides=8)
    pi = Part()
    pi.cyl(0.09, 0.9, (0, 0, 0.1), STEEL_L, sides=7)
    pi.box((0.56, 0.2, 0.16), (0, 0, 0.6), RED, bevel=0.05, segs=1)
    pi.cyl(0.14, 0.1, (0, 0, 0.72), DK, sides=7)
    pi.build("bob_piston", root, (px, py, 1.42))
    B.box((0.24, 0.3, 0.7), (px - 0.75, py + 0.12, 0.72), DK, bevel=0.05, segs=1)
    w = Part()
    w.torus(0.5, 0.07, (0, 0, 0), RED, seg=16, tseg=6)
    for k in range(3):
        w.box((1.0, 0.09, 0.07), (0, 0, 0), RED_D, r=rot(0, 0, k * 60))
    w.cyl(0.14, 0.14, (0, 0, 0), STEEL_L, sides=8)
    wo = w.build("spin_wheel", root, (px - 0.75, py - 0.12, 0.98))
    wo.rotation_euler = (math.radians(90), 0, 0)
    # Rohr von der Pumpe ins Haus
    pipe(B, [(px + 0.1, py + 0.36, 0.6), (px + 0.1, 0.55, 0.6), (px + 0.1, 0.55, 1.35), (hx + 0.95, 0.55, 1.35)], 0.17, pg)
    B.cyl(0.03, 0.3, (px + 0.1, 0.0, 0.88), DK, sides=4)                                           # Ventil
    B.torus(0.16, 0.03, (px + 0.1, 0.0, 1.04), RED, seg=8, tseg=4)
    # Stufe 2: Tank rechts hinten mit Füllstandsanzeige
    tx, ty = 1.02, 1.28
    X2.cyl(0.56, 1.7, (tx, ty, 1.05), tank, sides=14, bevel=0.1, segs=2)
    X2.cyl(0.575, 0.14, (tx, ty, 0.6), pg, sides=14)
    X2.cyl(0.575, 0.14, (tx, ty, 1.5), pg, sides=14)
    X2.cyl(0.2, 0.12, (tx, ty, 1.95), STEEL, sides=8)
    G2.box((0.1, 0.06, 0.9), (tx - 0.2, ty - 0.55, 1.05), "9CFF6A")
    X2.box((0.16, 0.05, 1.0), (tx - 0.2, ty - 0.53, 1.05), DK)
    for s in (-1, 1):
        X2.box((0.04, 0.04, 1.7), (tx + 0.3 + 0.12 * s, ty - 0.52, 1.05), STEEL_L)
    for i in range(6):
        X2.box((0.26, 0.04, 0.04), (tx + 0.3, ty - 0.52, 0.4 + i * 0.27), STEEL_L)
    # Stufe 3: Obergeschoss mit Hochbehälter
    X3.box((1.5, 1.35, 1.0), (hx, hy, 2.68), BRICK, bevel=0.07, segs=1)
    for i in range(2):
        X3.box((1.52, 1.37, 0.035), (hx, hy, 2.5 + i * 0.4), BRICK_D)
    G3.cyl(0.2, 0.08, (hx, hy - 0.67, 2.72), "C8F26A", r=rot(90, 0, 0), sides=10)
    X3.torus(0.22, 0.045, (hx, hy - 0.69, 2.72), DK, r=rot(90, 0, 0), seg=10, tseg=4)
    X3.cyl(0.85, 0.16, (hx, hy, 3.26), "6E7890", sides=12)
    X3.cyl(0.78, 0.8, (hx, hy, 3.72), pg, sides=12, bevel=0.06, segs=1)
    X3.cone(0.86, 0.5, (hx, hy, 4.37), "6E7890", sides=12)
    # Stufe 4: Stützpfeiler, Stahlbänder, Rohrbrücke
    for sx in (-1, 1):
        X4.box((0.3, 0.5, 1.3), (hx + 0.98 * sx, hy - 0.8, 0.8), CONC, r=rot(0, 0, 0), bevel=0.06, segs=1)
        X4.box((0.34, 0.54, 0.16), (hx + 0.98 * sx, hy - 0.8, 0.3), CONC_D)
    X4.cyl(0.8, 0.1, (hx, hy, 3.5), STEEL, sides=12)
    X4.cyl(0.8, 0.1, (hx, hy, 3.94), STEEL, sides=12)
    for i in range(6):
        X4.box((0.22, 0.02, 0.1), (px - 0.6 + i * 0.22, py - 0.56, 0.3), YEL if i % 2 == 0 else "23262E")
    for y in (-0.2, 0.3):
        X4.box((0.5, 0.1, 0.5), (px + 0.1, y, 0.36), STEEL, bevel=0.03, segs=1)
    pipe(X4, [(hx + 0.6, hy - 0.88, 0.6), (hx + 0.6, -0.3, 0.6), (px - 0.4, -0.3, 0.6)], 0.11, "E9EDF3")
    # Stufe 5: Gold
    X5.cyl(0.8, 0.09, (hx, hy, 3.72), GOLD, sides=12)
    X5.cone(0.3, 0.34, (hx, hy, 4.62), GOLD, sides=8)
    X5.ball(0.12, (hx, hy, 4.84), GOLD, subdiv=2)
    X5.box((2.14, 1.94, 0.08), (hx, hy, 2.22), GOLD, bevel=0.03, segs=1)
    X5.cyl(0.42, 0.08, (px, py, 1.3), GOLD, sides=12)
    X5.torus(0.18, 0.04, (px + 0.1, 0.0, 1.06), GOLD, seg=8, tseg=4)
    X5.cyl(0.6, 0.07, (tx, ty, 1.05), GOLD, sides=14)
    hub = Part()
    hub.cyl(0.18, 0.18, (0, 0, 0), GOLD, sides=8)
    hub.build("lv5_hub", wo)
    empty("door", root, (hx - 0.45, -0.4, 0))
    empty("bubble", root, (0, 0, 5.3))
    finish_special(name, root, B, G, X2, X3, X4, X5, G3, G2)


# ------------------------------------------------------------------ Frostpass: Bergwacht
def red_cross(p, c, k, color=RED, thick=0.06):
    p.box((0.5 * k, thick, 0.17 * k), c, color)
    p.box((0.17 * k, thick, 0.5 * k), c, color)


@model("o_special_frost")
def sp_frost(name):
    root, B, G = start(name)
    X2, X3, X4, X5, G3 = Part(), Part(), Part(), Part(), Part()
    base(B, 3.3, 3.9, "E3ECF8", 0.18)
    cx, cy = -0.3, 0.75                                                    # Hütte 2.2 x 2.0, Front bei y = -0.25
    B.box((2.2, 2.0, 1.0), (cx, cy, 0.66), ST, bevel=0.1, segs=1)
    for (x, z, w) in ((-0.8, 0.5, 0.5), (0.9, 0.85, 0.4), (-0.3, 0.9, 0.36), (0.75, 0.42, 0.44)):
        B.box((w, 0.06, 0.22), (cx + x, cy - 1.0, z), ST_L, bevel=0.03, segs=1)
    B.box((2.1, 1.9, 0.8), (cx, cy, 1.5), WOOD, bevel=0.06, segs=1)
    for i in range(2):
        B.box((2.12, 1.92, 0.035), (cx, cy, 1.35 + i * 0.3), shade(WOOD, 0.7))
    gable(B, (cx, cy, 1.85), 2.2, 2.0, 1.0, RED, over=0.22, thick=0.2, fill=WOOD)
    snow_roof(B, (cx, cy, 1.85), 2.2, 2.0, 1.0, over=0.22)
    door(B, (cx + 0.6, cy - 1.0, 0.18), 0.75, 1.45, "8A4A2A", "4A2C1A")
    window(G, B, (cx - 0.55, cy - 1.02, 1.3), 0.6, 0.55, frame="4A2C1A")
    B.box((0.56, 0.07, 0.56), (cx + 0.6, cy - 1.08, 2.0), "FFFFFF", bevel=0.05, segs=1)             # Schild mit rotem Kreuz
    red_cross(B, (cx + 0.6, cy - 1.12, 2.0), 0.8)
    chimney(root, B, (cx + 0.75, cy + 0.5, 2.2), 1.15, 0.2, ROCK, square=True)
    # Skier an der Wand, Schlitten, Schneehaufen
    for i, c in enumerate((RED, "3F8FD0")):
        B.box((0.1, 0.04, 1.7), (cx - 0.95 + i * 0.16, cy - 1.12, 1.0), c, r=rot(-8, 0, 3 - i * 6), bevel=0.02, segs=1)
    m = T(-0.75, -1.4, 0.18) @ rot(0, 0, 25)
    for s in (-1, 1):
        B.box((0.05, 1.0, 0.05), (0, 0, 0), STEEL_L, r=m @ T(0.22 * s, 0, 0.03))
        B.box((0.05, 0.05, 0.2), (0, 0, 0), WOOD_D, r=m @ T(0.22 * s, 0.3, 0.14))
        B.box((0.05, 0.05, 0.2), (0, 0, 0), WOOD_D, r=m @ T(0.22 * s, -0.3, 0.14))
    for i in range(4):
        B.box((0.52, 0.2, 0.04), (0, 0, 0), WOOD_L, r=m @ T(0, -0.36 + i * 0.24, 0.26))
    B.ball(1.0, (1.2, -0.75, 0.2), SNOW, scale=(0.4, 0.5, 0.26), subdiv=3)
    B.ball(1.0, (1.4, 0.2, 0.2), SNOW, scale=(0.3, 0.45, 0.22), subdiv=2)
    pennant(root, B, (0.72, -1.72, 0.18), 3.0, RED, size=(0.85, 0.58), emblem="cross")
    # Windmesser (dreht sich)
    B.cyl(0.035, 0.9, (cx - 0.95, cy, 3.3), DK, sides=5)
    an = Part()
    for k in range(3):
        a = math.radians(k * 120)
        an.box((0.3, 0.035, 0.035), (math.cos(a) * 0.15, math.sin(a) * 0.15, 0), DK, r=rot(0, 0, k * 120))
        an.ball(0.09, (math.cos(a) * 0.32, math.sin(a) * 0.32, 0), RED, subdiv=2)
    an.cyl(0.05, 0.08, (0, 0, 0), DK, sides=6)
    an.build("spin_anemo", root, (cx - 0.95, cy, 3.78))
    # Stufe 2: Anbau rechts mit Schneedach und Brennholz
    X2.box((0.9, 1.5, 1.3), (1.2, 0.95, 0.82), WOOD, bevel=0.06, segs=1)
    X2.box((0.94, 1.54, 0.4), (1.2, 0.95, 0.38), ST, bevel=0.05, segs=1)
    X2.box((1.0, 1.8, 0.14), (1.2, 0.95, 1.6), RED, r=rot(0, 14, 0), bevel=0.05, segs=1)
    X2.box((0.85, 1.6, 0.16), (1.18, 0.95, 1.72), SNOW, r=rot(0, 14, 0), bevel=0.07, segs=2)
    X2.box((0.5, 0.07, 0.9), (1.2, 0.18, 0.72), "8A4A2A", bevel=0.03, segs=1)
    for r in range(2):
        for i in range(3):
            X2.cyl(0.12, 0.45, (0.95 + i * 0.25 + 0.12 * r, -0.2, 0.3 + r * 0.22), BARK, r=rot(90, 0, 0), sides=6)
            X2.cyl(0.095, 0.47, (0.95 + i * 0.25 + 0.12 * r, -0.2, 0.3 + r * 0.22), CUT, r=rot(90, 0, 0), sides=6)
    # Stufe 3: Wachturm durch das Dach
    X3.box((1.25, 1.25, 1.6), (cx, cy, 3.1), WOOD_L, bevel=0.08, segs=1)
    X3.box((1.6, 1.6, 0.12), (cx, cy, 3.3), WOOD_D, bevel=0.03, segs=1)
    for s in (-1, 1):
        X3.box((1.6, 0.06, 0.06), (cx, cy + 0.77 * s, 3.66), WOOD_D)
        X3.box((0.06, 1.6, 0.06), (cx + 0.77 * s, cy, 3.66), WOOD_D)
        for s2 in (-1, 1):
            X3.box((0.07, 0.07, 0.36), (cx + 0.77 * s, cy + 0.77 * s2, 3.5), WOOD_D)
    pyr(X3, (cx, cy, 3.9), 1.7, 1.7, 0.85, RED)
    pyr(X3, (cx, cy, 4.22), 1.1, 1.1, 0.6, SNOW)
    window(G3, X3, (cx, cy - 0.64, 3.62), 0.55, 0.36, frame="4A2C1A", bars=False)
    window(G3, X3, (cx + 0.64, cy, 3.62), 0.55, 0.36, "r", frame="4A2C1A", bars=False)
    mm = T(cx - 0.5, cy - 0.85, 3.55) @ rot(0, 0, -20) @ rot(75, 0, 0)                              # Suchscheinwerfer
    X3.cyl(0.2, 0.3, (0, 0, 0), DK, r=mm, sides=8)
    G3.cyl(0.16, 0.06, (0, 0, 0), "FFF3B8", r=mm @ T(0, 0, 0.16), sides=8)
    # Stufe 4: Steinpfeiler und Schneemauer
    for sx in (-1, 1):
        for sy in (-1, 1):
            X4.box((0.42, 0.42, 1.75), (cx + 1.05 * sx, cy + 0.94 * sy, 1.04), ST_D, bevel=0.08, segs=1)
            X4.box((0.5, 0.5, 0.16), (cx + 1.05 * sx, cy + 0.94 * sy, 0.26), ST, bevel=0.04, segs=1)
    rng = random.Random(3)
    for i in range(6):
        rockc(X4, (0.5, 0.36, 0.5), (-1.3 + i * 0.52, 1.7, 0.42), (ST, ST_D, ST_L)[i % 3], rng)
    X4.box((2.9, 0.36, 0.14), (-0.1, 1.72, 0.7), SNOW, bevel=0.06, segs=2)
    for i in range(3):
        rockc(X4, (0.4, 0.45, 0.42), (-1.42, -0.9 + i * 0.45, 0.38), (ST_D, ST, ST_L)[i % 3], rng)
    # Stufe 5: Gold
    X5.cyl(0.12, 2.66, (cx, cy, 3.02), GOLD, r=rot(0, 90, 0), sides=8, bevel=0.04, segs=1)
    X5.box((0.66, 0.05, 0.66), (cx + 0.6, cy - 1.06, 2.0), GOLD, bevel=0.05, segs=1)
    X5.cone(0.16, 0.4, (cx, cy, 4.92), GOLD, sides=8)
    X5.ball(0.1, (cx, cy, 5.14), GOLD, subdiv=2)
    X5.box((1.66, 1.66, 0.08), (cx, cy, 3.9), GOLD, bevel=0.03, segs=1)
    X5.cyl(0.13, 0.18, (cx + 0.5, cy - 0.85, 3.42), GOLD, r2=0.07, sides=8)                        # Glocke
    X5.cyl(0.015, 0.2, (cx + 0.5, cy - 0.85, 3.6), GOLD, sides=4)
    X5.box((2.66, 0.1, 0.1), (cx, cy - 1.2, 1.76), GOLD, bevel=0.03, segs=1)
    empty("door", root, (cx + 0.6, -0.9, 0))
    empty("bubble", root, (0, 0, 5.6))
    finish_special(name, root, B, G, X2, X3, X4, X5, G3)


# ------------------------------------------------------------------ Schleimkrater: Forschungsstation
@model("o_special_krater")
def sp_krater(name):
    root, B, G = start(name)
    X2, X3, X4, X5, G3, G2 = Part(), Part(), Part(), Part(), Part(), Part()
    white, gl = "EEF2F8", "9CFF6A"
    base(B, 3.3, 3.9, "4A5068", 0.16)
    B.box((3.0, 3.6, 0.03), (0, 0, 0.165), "5E6680")
    for i in range(10):
        B.box((0.3, 0.14, 0.03), (-1.35 + i * 0.3, -1.82, 0.17), YEL if i % 2 == 0 else "23262E")
    lx, ly = -0.5, 0.9                                                     # Labormodul, Front bei y = 0.0
    B.box((2.2, 1.8, 1.6), (lx, ly, 1.02), white, bevel=0.22, segs=3)
    B.box((2.24, 1.84, 0.24), (lx, ly, 0.34), DK, bevel=0.04, segs=1)
    B.box((2.23, 1.83, 0.2), (lx, ly, 1.5), TEAL, bevel=0.03, segs=1)
    door(B, (lx + 0.55, ly - 0.9, 0.2), 0.7, 1.2, TEAL_D, DK, gl)
    G.box((0.85, 0.1, 0.45), (lx - 0.45, ly - 0.89, 1.0), gl, bevel=0.03, segs=1)
    B.box((1.0, 0.08, 0.6), (lx - 0.45, ly - 0.86, 1.0), DK, bevel=0.03, segs=1)
    G.box((0.1, 0.9, 0.4), (lx - 1.09, ly, 1.0), gl)
    B.ball(1.0, (lx - 0.3, ly, 1.78), "8FE3E0", scale=(0.62, 0.62, 0.42), subdiv=3)                # kleine Kuppel
    B.cyl(0.66, 0.1, (lx - 0.3, ly, 1.84), DK, sides=12)
    # Radar auf dem Dach
    B.cyl(0.04, 0.4, (lx + 0.75, ly + 0.45, 2.0), STEEL, sides=5)
    d = Part()
    mm = T(0, -0.06, 0.18) @ rot(60, 0, 0)
    d.cyl(0.1, 0.2, (0, 0, 0), white, r=mm, r2=0.38, sides=10)
    d.cyl(0.02, 0.3, (0, 0, 0), STEEL, r=mm @ T(0, 0, 0.16), sides=4)
    d.ball(0.05, (0, 0, 0), RED, r=mm @ T(0, 0, 0.32), subdiv=2)
    d.build("spin_dish", root, (lx + 0.75, ly + 0.45, 2.2))
    # Energiekugel im Haltering vorn rechts
    ox, oy, oz = 0.9, -0.95, 1.45
    B.cyl(0.5, 0.36, (ox, oy, 0.34), DK, sides=10, bevel=0.06, segs=1)
    B.cyl(0.4, 0.1, (ox, oy, 0.56), TEAL, sides=10)
    for a in (45, 165, 285):
        ra = math.radians(a)
        q1 = (ox + math.cos(ra) * 0.4, oy + math.sin(ra) * 0.4, 0.55)
        q2 = (ox + math.cos(ra) * 0.62, oy + math.sin(ra) * 0.62, 1.3)
        q3 = (ox + math.cos(ra) * 0.4, oy + math.sin(ra) * 0.4, 1.95)
        tube(B, q1, q2, 0.06, white, 5)
        tube(B, q2, q3, 0.06, white, 5)
        B.ball(0.09, q2, TEAL, subdiv=2)
        B.ball(0.07, q3, TEAL, subdiv=2)
    orb = Part()
    orb.ball(0.3, (0, 0, 0), "C8FF7A", subdiv=3)
    orb.build("pulse_orb_glow", root, (ox, oy, oz))
    rg = Part()
    rg.torus(0.46, 0.04, (0, 0, 0), TEAL, seg=14, tseg=4)
    rg.ball(0.07, (0.46, 0, 0), white, subdiv=2)
    ro = rg.build("spin_ring", root, (ox, oy, oz))
    ro.rotation_euler = (math.radians(24), 0, 0)
    empty("fx_spark", root, (ox, oy, 2.0))
    tube(B, (ox - 0.45, oy + 0.1, 0.2), (lx + 0.9, ly - 0.95, 0.2), 0.05, "23262E", 5)             # Kabel
    # Probenkiste mit Scherben vorn links
    B.box((0.7, 0.5, 0.36), (-1.0, -1.2, 0.34), "6E7890", bevel=0.05, segs=1)
    for i, (dx, hh) in enumerate(((-0.18, 0.4), (0.02, 0.55), (0.2, 0.34))):
        G.cone(0.1, hh, (-1.0 + dx, -1.2, 0.5 + hh * 0.5), "7CFF5A", r=rot(8 * (i - 1), 6, 0), sides=5)
    # Stufe 2: Tankmodul rechts hinten
    tx, ty = 1.12, 1.15
    X2.cyl(0.46, 1.7, (tx, ty, 1.03), white, sides=12, bevel=0.14, segs=2)
    X2.cyl(0.48, 0.14, (tx, ty, 0.5), TEAL, sides=12)
    X2.cyl(0.48, 0.14, (tx, ty, 1.56), TEAL, sides=12)
    G2.box((0.2, 0.08, 0.76), (tx, ty - 0.45, 1.03), gl, bevel=0.03, segs=1)
    tube(X2, (tx - 0.4, ty, 1.3), (lx + 1.05, ty, 1.3), 0.08, TEAL_D, 6)
    X2.box((0.5, 0.5, 0.5), (1.25, 0.2, 0.41), "6E7890", bevel=0.06, segs=1)
    G2.box((0.3, 0.05, 0.14), (1.25, -0.06, 0.5), gl)
    # Stufe 3: Sternwarte auf dem Dach
    cx3, cy3 = lx - 0.3, ly
    X3.cyl(0.84, 0.95, (cx3, cy3, 2.25), white, sides=14, bevel=0.05, segs=1)
    X3.cyl(0.87, 0.16, (cx3, cy3, 2.1), TEAL, sides=14)
    X3.ball(1.0, (cx3, cy3, 2.7), "5FD6CE", scale=(0.82, 0.82, 0.68), subdiv=3)
    X3.box((0.3, 1.2, 0.5), (cx3, cy3 - 0.3, 3.05), DK, r=rot(-38, 0, 0), bevel=0.05, segs=1)       # Spalt
    X3.cyl(0.13, 0.9, (cx3, cy3 - 0.7, 3.35), white, r=rot(52, 0, 0), sides=8)                      # Fernrohr
    X3.cyl(0.15, 0.1, (cx3, cy3 - 1.03, 3.61), TEAL, r=rot(52, 0, 0), sides=8)
    for a in (200, 250, 290, 340):
        ra = math.radians(a)
        G3.box((0.26, 0.08, 0.3), (cx3 + math.cos(ra) * 0.82, cy3 + math.sin(ra) * 0.82, 2.4), gl, r=rot(0, 0, a + 90))
    # Stufe 4: Stützstreben, Panzerplatten, Mast
    for sx in (-1, 1):
        beam(X4, (lx + 1.13 * sx, ly - 1.05, 0.16), (lx + 1.0 * sx, ly - 0.8, 1.7), 0.14, "6E7890")
        beam(X4, (lx + 1.13 * sx, ly + 0.98, 0.16), (lx + 1.0 * sx, ly + 0.8, 1.7), 0.14, "6E7890")
    X4.box((1.2, 0.1, 0.5), (lx - 0.4, ly - 0.94, 0.5), "6E7890", bevel=0.03, segs=1)
    for x in (-0.85, 0.05):
        X4.cyl(0.05, 0.06, (lx + x, ly - 1.0, 0.5), STEEL_L, r=rot(90, 0, 0), sides=6)
    for (x, y) in ((0.25, -1.75), (1.5, -1.75), (1.5, -0.3)):
        X4.cyl(0.1, 0.6, (x, y, 0.46), YEL, sides=7)
        X4.cyl(0.105, 0.14, (x, y, 0.55), "23262E", sides=7)
    X4.cyl(0.035, 1.6, (lx + 0.9, ly - 0.6, 2.6), STEEL, sides=5)
    for k in range(3):
        X4.box((0.4 - k * 0.1, 0.03, 0.03), (lx + 0.9, ly - 0.6, 2.9 + k * 0.2), STEEL)
    # Stufe 5: Gold
    X5.torus(0.86, 0.06, (cx3, cy3, 2.74), GOLD, seg=16, tseg=5)
    X5.ball(0.14, (cx3, cy3, 3.4), GOLD, subdiv=2)
    X5.ball(0.1, (lx + 0.9, ly - 0.6, 3.45), GOLD, subdiv=2)
    X5.cyl(0.52, 0.08, (ox, oy, 0.5), GOLD, sides=10)
    for a in (45, 165, 285):
        ra = math.radians(a)
        X5.ball(0.1, (ox + math.cos(ra) * 0.4, oy + math.sin(ra) * 0.4, 1.95), GOLD, subdiv=2)
    X5.box((2.26, 1.86, 0.07), (lx, ly, 1.64), GOLD, bevel=0.03, segs=1)
    star(X5, (lx - 0.45, ly - 0.93, 1.5), 0.13, GOLD, 0.06)
    gr = Part()
    gr.torus(0.56, 0.035, (0, 0, 0), GOLD, r=rot(0, 70, 0), seg=14, tseg=4)
    gr.build("lv5_ring", ro)
    empty("door", root, (lx + 0.55, -0.5, 0))
    empty("bubble", root, (0, 0, 4.6))
    finish_special(name, root, B, G, X2, X3, X4, X5, G3, G2)
