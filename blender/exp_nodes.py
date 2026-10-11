"""Rohstoffquellen der Expedition (n_*): werden Schlag für Schlag abgebaut.
Stufen _1 -> _3 sind dieselbe Quelle, immer kleiner. Bäume: Stamm = body, Krone = sway_crown; n_stump bleibt stehen.
Leuchtende Teile: crystal_glow, vein_glow, lamp_glow."""
from exp_common import *


# ------------------------------------------------------------------ Bäume und Stumpf
@model("n_tree_small")
def tree_small(name):
    root, B, G = start(name)
    rng = random.Random(3)
    B.cyl(0.24, 2.0, (0, 0, 1.0), BARK, r2=0.17, sides=8)
    B.cyl(0.36, 0.3, (0, 0, 0.15), shade(BARK, 0.85), r2=0.24, sides=8)
    for a in (30, 150, 270):
        limb(B, (0, 0, 0.2), (math.cos(math.radians(a)) * 0.5, math.sin(math.radians(a)) * 0.5, 0.0), 0.12, 0.05, shade(BARK, 0.85), 5)
    limb(B, (0, 0, 1.4), (0.5, 0.1, 2.0), 0.09, 0.06, BARK, 5)
    limb(B, (0, 0, 1.55), (-0.45, -0.15, 2.1), 0.09, 0.06, BARK, 5)
    tuft(B, 0.4, -0.35, 0, 5, 0.9, 4)
    B.build("body", root)
    c = Part()
    c.ball(1.12, (0, 0, 1.05), LEAF, scale=(1.0, 1.0, 0.9), subdiv=3)
    for (x, y, z, r, col) in ((0.75, -0.2, 0.55, 0.68, LEAF_D), (-0.72, 0.25, 0.6, 0.7, LEAF_D), (0.1, 0.7, 0.7, 0.62, "538C2E"), (-0.2, -0.7, 0.8, 0.6, "6AA836"),
                              (0.35, -0.25, 1.75, 0.55, LEAF_L), (-0.45, 0.2, 1.6, 0.5, "78B43A")):
        c.ball(r, (x, y, z), col, r=rot(rng.uniform(0, 90), rng.uniform(0, 90), 0), subdiv=2)
    for (x, y, z) in ((0.5, -0.75, 1.2), (-0.8, -0.5, 1.0), (0.95, 0.1, 1.1)):                      # rote Äpfel als Farbtupfer
        c.ball(0.1, (x, y, z), "E0334A", subdiv=1)
    c.build("sway_crown", root, (0, 0, 1.75))
    fin(name, yaw=-30, pitch=16)


@model("n_tree_big")
def tree_big(name):
    root, B, G = start(name)
    rng = random.Random(12)
    B.cyl(0.4, 2.6, (0, 0, 1.3), WOOD_D, r2=0.26, sides=9)
    B.cyl(0.56, 0.36, (0, 0, 0.18), shade(WOOD_D, 0.85), r2=0.4, sides=9)
    for a in (10, 100, 190, 280):
        limb(B, (0, 0, 0.25), (math.cos(math.radians(a)) * 0.75, math.sin(math.radians(a)) * 0.75, 0.0), 0.16, 0.06, shade(WOOD_D, 0.85), 5)
    mushroom(B, 0.6, -0.5, 0, 0.6)
    tuft(B, -0.6, -0.5, 0, 5, 1.0, 9)
    B.build("body", root)
    c = Part()
    g = "3F9148"
    n, span = 4, 5.5
    th = span * 0.42
    for i in range(n):
        r = 2.0 * (1.0 - 0.62 * i / (n - 1))
        zb = i * (span - th) / (n - 1)
        m = T(rng.uniform(-0.06, 0.06), rng.uniform(-0.06, 0.06), zb) @ rot(rng.uniform(-4, 4), rng.uniform(-4, 4), rng.uniform(0, 360))
        col_ = shade(g, 1.0 + 0.13 * i)
        c.cyl(r * 0.7, 0.3, (0, 0, 0), shade(col_, 0.72), r=m, r2=r, sides=12)
        c.cone(r, th, (0, 0, 0), col_, r=m @ T(0, 0, 0.15 + th * 0.5), sides=12)
    c.build("sway_crown", root, (0, 0, 1.5))
    fin(name, yaw=-30, pitch=14)


@model("n_stump")
def stump(name):
    root, B, G = start(name)
    B.cyl(0.4, 0.55, (0, 0, 0.3), BARK, r2=0.33, sides=10)
    B.cyl(0.52, 0.22, (0, 0, 0.11), shade(BARK, 0.85), r2=0.4, sides=10)
    for a in (20, 110, 200, 290):
        limb(B, (0, 0, 0.2), (math.cos(math.radians(a)) * 0.72, math.sin(math.radians(a)) * 0.72, 0.0), 0.14, 0.05, shade(BARK, 0.85), 5)
    B.cyl(0.3, 0.03, (0, 0, 0.585), CUT, sides=10)
    B.cyl(0.2, 0.035, (0, 0, 0.587), CUT_D, sides=10)
    B.cyl(0.1, 0.04, (0, 0, 0.589), CUT, sides=8)
    for k in range(4):                                                                              # Bruchkante (Scharnier beim Fällen)
        B.cone(0.07, 0.22 + 0.1 * (k % 2), (-0.2 + k * 0.13, 0.24, 0.68), CUT, r=rot(-10, 0, 0), sides=4)
    # Axtkerbe vorn: heller Keil
    B.box((0.34, 0.1, 0.2), (0.03, -0.325, 0.38), CUT)
    B.box((0.3, 0.1, 0.05), (0.03, -0.332, 0.38), "7A4A26")
    for (x, y, rz) in ((0.4, -0.6, 20), (-0.25, -0.7, -30), (0.1, -0.85, 70)):                      # Späne
        B.box((0.2, 0.09, 0.03), (x, y, 0.02), CUT, r=rot(0, 0, rz))
    tuft(B, -0.55, 0.3, 0, 5, 0.8, 2)
    B.build("body", root)
    fin(name, yaw=-25, pitch=28)


# ------------------------------------------------------------------ Felsbrocken (3 Stufen)
def rock_node(name, stage):
    root, B, G = start(name)
    B = KPart((0.9, 0.86, 0.72)[stage - 1])                                                        # Zielbreite 2,4 / 1,6 / 0,9 m
    rng = random.Random(40 + stage)
    c0, c1, c2, cl, cut = ROCK, shade(ROCK, 0.9), shade(ROCK, 0.8), mix(ROCK, "FFFFFF", 0.25), "CFC6CC"
    if stage == 1:
        lay = [((1.7, 1.5, 1.7), (0, 0.1, 0.8), c0), ((1.1, 1.0, 1.1), (0.72, -0.3, 0.5), c1), ((1.0, 0.9, 0.9), (-0.7, 0.35, 0.42), c2),
               ((1.0, 0.9, 0.7), (0.1, 0.15, 1.6), cl), ((0.6, 0.55, 0.45), (-0.6, -0.65, 0.2), c1)]
        rub = [(0.9, -0.95), (-1.05, -0.3)]
    elif stage == 2:
        lay = [((1.2, 1.1, 1.05), (0, 0.1, 0.5), c0), ((0.8, 0.7, 0.7), (0.5, -0.25, 0.32), c1), ((0.7, 0.65, 0.6), (-0.5, 0.25, 0.28), c2)]
        rub = [(0.75, -0.7), (-0.8, -0.45), (0.0, -0.85), (0.85, 0.4)]
    else:
        lay = [((0.72, 0.62, 0.52), (0, 0.05, 0.25), c0), ((0.4, 0.36, 0.3), (0.34, -0.2, 0.14), c2)]
        rub = [(0.5, 0.3), (-0.45, -0.3), (0.0, -0.5), (-0.4, 0.35), (0.6, -0.4)]
    for size, loc, c in lay:
        rockc(B, size, loc, c, rng)
    # Abbruchkanten: helle, scharfkantige Blöcke dort, wo schon abgeschlagen wurde
    if stage == 1:
        B.box((0.5, 0.45, 0.4), (0.78, -0.62, 0.92), cut, r=rot(10, 14, 25), bevel=0.03, segs=1)
    elif stage == 2:
        B.box((0.8, 0.7, 0.5), (0.1, 0.0, 0.92), cut, r=rot(8, -10, 30), bevel=0.04, segs=1)
        B.box((0.45, 0.4, 0.4), (-0.4, -0.3, 0.62), shade(cut, 0.92), r=rot(-12, 6, 60), bevel=0.03, segs=1)
    else:
        B.box((0.5, 0.42, 0.3), (0.0, 0.02, 0.42), cut, r=rot(10, -8, 30), bevel=0.03, segs=1)
        B.box((0.26, 0.24, 0.2), (0.3, -0.22, 0.26), shade(cut, 0.92), r=rot(-12, 6, 60), bevel=0.02, segs=1)
    for i, (x, y) in enumerate(rub):                                                                # Bruchstücke am Boden
        s = rng.uniform(0.2, 0.32)
        rockc(B, (s, s * 0.9, s * 0.7), (x, y, s * 0.3), (cut, c1, cl)[i % 3], rng, 0.18)
    tuft(B, -0.4 - 0.25 * (3 - stage), -0.5 - 0.15 * (3 - stage), 0, 4, 0.8, stage)
    B.build("body", root)
    fin(name, yaw=-30, pitch=22)


for _i in (1, 2, 3):
    REG["n_rock_%d" % _i] = (lambda i=_i: rock_node("n_rock_%d" % i, i))


# ------------------------------------------------------------------ Schrotthaufen (3 Stufen)
def cog(p, m, R, th, color, teeth=8):
    p.cyl(R * 0.8, th, (0, 0, 0), color, r=m, sides=12)
    for i in range(teeth):
        p.box((R * 0.36, R * 0.36, th * 0.9), (0, 0, 0), color, r=m @ rot(0, 0, i * 360.0 / teeth) @ T(R * 0.86, 0, 0))
    p.cyl(R * 0.3, th * 1.2, (0, 0, 0), "2E3340", r=m, sides=8)


def scrap_node(name, stage):
    root, B, G = start(name)
    rng = random.Random(60 + stage)
    k = (1.0, 0.72, 0.45)[stage - 1]
    B.ball(1.0, (0, 0, 0.0), "6A4632", scale=(1.15 * k, 1.0 * k, 0.6 * k), subdiv=2)                # dunkler Hügel
    pal = (RUST, "7E8798", RUST_L, "5FA3A0", RUST_D, "E2B648", STEEL, "C0503A")
    for i in range((14, 9, 5)[stage - 1]):                                                          # Blechbrocken
        a = math.radians(i * 137.5)
        rr = (0.2 + 0.85 * ((i * 5) % 7) / 7.0) * k
        s = rng.uniform(0.4, 0.62) * (0.7 + 0.3 * k)
        rockc(B, (s, s * 0.8, s * 0.4), (math.cos(a) * rr, math.sin(a) * rr * 0.9, 0.6 * k * math.sqrt(max(0.0, 1 - (rr / (1.2 * k)) ** 2)) + 0.04), pal[i % 8], rng, 0.08)
    if stage == 1:
        B.box((0.9, 0.08, 0.8), (-0.55, -0.72, 0.5), "5FA3A0", r=rot(-28, 0, 14), bevel=0.05, segs=1)   # Autotür
        B.box((0.5, 0.1, 0.3), (-0.55, -0.66, 0.74), "2E3340", r=rot(-28, 0, 14))
        cog(B, T(0.5, -0.6, 0.72) @ rot(55, 10, 0), 0.4, 0.12, STEEL_L)
        tube(B, (-0.2, 0.3, 0.6), (0.7, 0.5, 1.5), 0.09, STEEL, 6)
        tire(B, T(0.95, 0.2, 0.3) @ rot(70, 0, 30), 0.38, 0.26, lp=True)
        B.cyl(0.26, 0.7, (-0.7, 0.5, 0.52), "C0503A", r=rot(50, 20, 0), sides=8, bevel=0.05, segs=1)
        beam(B, (0.1, -0.1, 0.5), (-0.3, 0.1, 1.45), 0.1, RUST_D)
        B.box((0.7, 0.5, 0.05), (0.15, 0.1, 1.02), RUST_L, r=rot(12, -18, 30))
    elif stage == 2:
        cog(B, T(0.35, -0.45, 0.5) @ rot(60, 10, 0), 0.34, 0.12, STEEL_L)
        tube(B, (-0.3, 0.2, 0.4), (0.4, 0.3, 1.0), 0.08, STEEL, 6)
        tire(B, T(-0.6, -0.3, 0.26) @ rot(72, 0, -30), 0.34, 0.24, lp=True)
        B.box((0.6, 0.45, 0.05), (0.0, 0.1, 0.68), RUST_L, r=rot(12, -18, 30))
    else:
        cog(B, T(0.2, -0.25, 0.26) @ rot(70, 10, 0), 0.24, 0.1, STEEL_L)
        tube(B, (-0.3, 0.1, 0.2), (0.2, 0.2, 0.5), 0.06, STEEL, 6)
    for i in range(3 + stage):                                                                      # Schrauben und Kleinteile
        a = rng.uniform(0, 6.28)
        rr = (1.1 * k + 0.15) * rng.uniform(0.9, 1.1)
        if i % 2:
            B.cyl(0.07, 0.05, (math.cos(a) * rr, math.sin(a) * rr, 0.025), STEEL_L, sides=6)
        else:
            B.box((0.22, 0.12, 0.04), (math.cos(a) * rr, math.sin(a) * rr, 0.02), RUST_L, r=rot(0, 0, rng.uniform(0, 90)))
    B.build("body", root)
    fin(name, yaw=-30, pitch=24)


for _i in (1, 2, 3):
    REG["n_scrap_%d" % _i] = (lambda i=_i: scrap_node("n_scrap_%d" % i, i))


# ------------------------------------------------------------------ Autowrack zum Ausschlachten
@model("n_wreck")
def wreck(name):
    root, B, G = start(name)
    P = MPart(rot(0, 2, 0))
    paint, dk = "D9603C", "2E3340"
    # Karosserie entlang X (vorn = -X), aufgebockt auf Ziegeln
    P.box((3.5, 1.7, 0.66), (0, 0, 0.72), paint, bevel=0.2, segs=3)
    P.box((1.7, 1.52, 0.66), (0.3, 0, 1.3), shade(paint, 0.88), bevel=0.22, segs=3)
    P.box((1.2, 1.56, 0.34), (0.3, 0, 1.34), dk, bevel=0.06, segs=1)
    P.box((1.76, 1.15, 0.34), (0.3, 0, 1.34), dk, bevel=0.06, segs=1)
    P.box((0.95, 1.4, 0.3), (-1.2, 0, 0.92), dk, bevel=0.05, segs=1)                                # Motorraum
    P.box((0.5, 0.6, 0.3), (-1.2, -0.1, 1.05), STEEL, bevel=0.06, segs=1)                           # Motorblock
    P.cyl(0.1, 0.2, (-1.2, 0.35, 1.1), RED, sides=6)
    P.box((0.95, 1.45, 0.07), (-0.85, 0, 1.55), shade(paint, 1.06), r=rot(0, 52, 0), bevel=0.03, segs=1)   # Haube steht offen
    P.cyl(0.02, 0.6, (-1.25, 0.6, 1.3), STEEL_L, r=rot(0, -20, 0), sides=4)
    P.box((0.14, 1.76, 0.2), (-1.78, 0, 0.52), "6E7890", r=rot(5, 0, 0), bevel=0.05, segs=1)        # Stoßstange hängt
    P.box((0.12, 1.7, 0.18), (1.78, 0, 0.56), "6E7890", bevel=0.05, segs=1)
    for sy in (-0.55, 0.55):
        P.cyl(0.14, 0.06, (-1.76, sy, 0.8), "D9D2B0" if sy > 0 else dk, r=AX_X, sides=8)
    for (x, y, z, s) in ((0.9, -0.86, 0.75, 0.5), (-0.6, 0.86, 0.8, 0.4), (1.4, 0.86, 0.62, 0.34), (0.3, -0.78, 1.5, 0.3)):   # Rost
        P.box((s, 0.04, s * 0.55), (x, y, z), RUST, bevel=0.015, segs=1)
    P.box((0.9, 0.05, 0.02), (0.2, 0.0, 1.64), RUST_D)
    for (x, y) in ((1.1, -0.86), (1.1, 0.86)):                                                      # hinten noch Räder
        tire(P, T(x, y, 0.4) @ rot(90, 0, 0), 0.4, 0.3)
    for sy in (-1, 1):                                                                              # vorn auf Ziegeln
        P.box((0.5, 0.36, 0.2), (-1.1, 0.6 * sy, 0.1), "A65A44", bevel=0.03, segs=1)
        P.box((0.44, 0.36, 0.2), (-1.1, 0.6 * sy, 0.3), "B8684E", r=rot(0, 0, 12 * sy), bevel=0.03, segs=1)
    P.cyl(0.14, 0.1, (-1.1, 0.88, 0.5), STEEL, r=rot(90, 0, 0), sides=8)                            # nackte Radnabe
    # Tür liegt ausgehängt daneben, Rad, Werkzeug
    P.m = Matrix.Identity(4)
    B = P
    B.box((1.0, 0.08, 0.8), (0.2, -1.25, 0.42), paint, r=rot(-62, 0, 8), bevel=0.05, segs=1)
    B.box((0.6, 0.1, 0.3), (0.2, -1.12, 0.68), dk, r=rot(-62, 0, 8))
    tire(B, T(-1.5, -1.3, 0.15), 0.4, 0.3, "C9CED8")
    cog(B, T(-0.7, -1.35, 0.05), 0.2, 0.08, STEEL_L)
    B.box((0.45, 0.08, 0.03), (-0.6, 1.3, 0.02), STEEL_L, r=rot(0, 0, 30))
    tuft(B, 1.7, -1.1, 0, 5, 1.0, 5)
    tuft(B, -1.9, 0.9, 0, 4, 0.8, 6)
    B.build("body", root)
    fin(name, yaw=-150, pitch=22)


# ------------------------------------------------------------------ Fassgruppe mit Zapfhahn
def drum(p, m, color, r=0.36, h=1.0):
    p.cyl(r, h, (0, 0, 0), color, r=m, sides=12, bevel=0.06, segs=1)
    for k in (-0.22, 0.22):
        p.cyl(r + 0.025, 0.07, (0, 0, 0), shade(color, 0.68), r=m @ T(0, 0, h * k), sides=12)
    p.cyl(r * 0.72, 0.03, (0, 0, 0), shade(color, 1.2), r=m @ T(0, 0, h * 0.5), sides=10)
    p.cyl(0.06, 0.05, (0, 0, 0), "2E3340", r=m @ T(r * 0.45, 0, h * 0.5 + 0.02), sides=5)


@model("n_barrel_fuel")
def barrel_fuel(name):
    root, B, G = start(name)
    for k in range(2):                                                                              # Palette
        B.box((1.9, 1.3, 0.06), (0, 0.15, 0.03 + k * 0.14), WOOD_L)
    for dx in (-0.8, 0, 0.8):
        B.box((0.12, 1.3, 0.08), (dx, 0.15, 0.1), WOOD_D)
    drum(B, T(-0.5, 0.4, 0.7), RED)
    drum(B, T(0.35, 0.45, 0.7), "E8A020")
    for a in (0, 1):                                                                                # Tropfen-Zeichen
        x, c = (-0.5, "FFF1D0") if a == 0 else (0.35, RED_D)
        B.ball(1.0, (x, 0.4 - 0.36 + 0.05 * a, 0.72), c, scale=(0.13, 0.03, 0.13), subdiv=2)
        B.cyl(1.0, 0.03, (x, 0.4 - 0.37 + 0.05 * a, 0.88), c, r=rot(90, 0, 0) @ S(0.1, 0.13, 1), sides=3)
    # liegendes Fass auf Bock mit Zapfhahn
    m = T(0.3, -0.55, 0.78) @ rot(0, 90, 0)
    for dx in (-0.32, 0.32):
        B.box((0.12, 0.9, 0.12), (0.3 + dx, -0.55, 0.26), WOOD_D)
        for s in (-1, 1):
            beam(B, (0.3 + dx, -0.55 + 0.42 * s, 0.26), (0.3 + dx, -0.55 + 0.2 * s, 0.56), 0.12, WOOD)
    drum(B, m, RED, 0.36, 1.0)
    B.cyl(0.07, 0.26, (0.92, -0.55, 0.62), "E0A82E", r=rot(0, 90, 0), sides=6)                       # Hahn
    B.cyl(0.055, 0.2, (1.02, -0.55, 0.54), "E0A82E", sides=6)
    B.box((0.06, 0.3, 0.06), (0.98, -0.55, 0.72), RED_D)
    # Kanister unter dem Hahn, Trichter
    B.box((0.34, 0.2, 0.42), (1.0, -0.55, 0.21), "3FA34D", bevel=0.05, segs=1)
    B.box((0.2, 0.06, 0.05), (1.0, -0.55, 0.47), "3FA34D")
    B.cyl(0.04, 0.08, (1.1, -0.55, 0.45), "23262E", sides=5)
    B.cyl(1.0, 0.012, (0.7, -1.0, 0.006), "3A3238", r=S(0.34, 0.22, 1), sides=8)                    # Ölfleck
    B.build("body", root)
    fin(name, yaw=-30, pitch=24)


# ------------------------------------------------------------------ alte Zapfsäule
@model("n_pump")
def pump(name):
    root, B, G = start(name)
    P = MPart()
    c = "D9503E"
    P.box((1.5, 1.0, 0.16), (0, 0, 0.08), CONC, bevel=0.05, segs=1)
    P.box((0.3, 0.02, 0.16), (-0.5, -0.5, 0.08), YEL)
    P.box((0.3, 0.02, 0.16), (0.3, -0.5, 0.08), YEL)
    P.m = rot(0, 3, 0)                                                                              # die Säule steht leicht schief
    P.box((0.72, 0.5, 1.5), (0, 0, 0.92), c, bevel=0.14, segs=3)
    P.box((0.76, 0.54, 0.2), (0, 0, 0.28), "8A2F2A", bevel=0.04, segs=1)
    P.box((0.78, 0.56, 0.12), (0, 0, 1.36), "FFF1D0", bevel=0.03, segs=1)
    P.cyl(0.23, 0.06, (0, -0.25, 1.05), "FFF6E0", r=rot(90, 0, 0), sides=12)                       # Zifferblatt
    P.torus(0.23, 0.03, (0, -0.27, 1.05), "2E3340", r=rot(90, 0, 0), seg=12, tseg=4)
    P.box((0.03, 0.03, 0.18), (0.04, -0.29, 1.1), RED_D, r=rot(0, 25, 0))
    P.box((0.4, 0.04, 0.16), (0, -0.26, 0.66), "2E3340")
    for i in range(3):
        P.box((0.09, 0.05, 0.1), (-0.12 + i * 0.12, -0.27, 0.66), "FFF6E0")
    P.cyl(0.16, 0.14, (0, 0, 1.74), "8A2F2A", sides=10)
    P.box((0.3, 0.04, 0.3), (0.22, -0.26, 0.5), RUST, bevel=0.02, segs=1)                           # Rost
    P.box((0.04, 0.24, 0.4), (-0.37, 0.05, 1.2), RUST_D, bevel=0.02, segs=1)
    # Schlauch und Zapfpistole
    pts = [(0.37, 0, 1.3), (0.62, 0, 1.2), (0.7, 0, 0.6), (0.55, -0.1, 0.4), (0.44, -0.16, 0.8)]
    for i in range(4):
        tube(P, pts[i], pts[i + 1], 0.04, "23262E", 5)
        P.ball(0.045, pts[i + 1], "23262E", subdiv=1)
    P.box((0.1, 0.24, 0.12), (0.44, -0.22, 0.86), STEEL, bevel=0.03, segs=1)
    P.cyl(0.03, 0.2, (0.44, -0.36, 0.84), STEEL_L, r=rot(100, 0, 0), sides=5)
    P.box((0.12, 0.1, 0.2), (0.4, -0.1, 0.84), "8A2F2A")
    P.m = Matrix.Identity(4)
    tuft(P, -0.6, 0.35, 0.16, 5, 0.9, 3)
    tuft(P, 0.85, -0.6, 0.0, 4, 0.8, 4)
    P.cyl(1.0, 0.012, (0.5, -0.7, 0.006), "3A3238", r=S(0.3, 0.2, 1), sides=8)
    # die Kugel obendrauf leuchtet matt
    g = Part()
    g.ball(0.24, (0, 0, 0), "F2D9A0", subdiv=3)
    g.cyl(0.245, 0.09, (0, 0, 0), "E0702A", sides=12)
    P.build("body", root)
    g.build("globe_glow", root, (0.1, 0, 2.02))
    fin(name, yaw=-30, pitch=18)


# ------------------------------------------------------------------ Energiekristalle (3 Stufen)
def shard(p, m, r, h, color, sides=6):
    p.cyl(r, h, (0, 0, 0), color, r=m @ T(0, 0, h * 0.5), r2=r * 0.86, sides=sides)
    p.cyl(r * 0.86, r * 0.9, (0, 0, 0), mix(color, "C8F6FF", 0.5), r=m @ T(0, 0, h + r * 0.45), r2=0.01, sides=sides)


def crystal_node(name, stage):
    root, B, G = start(name)
    rng = random.Random(80 + stage)
    cy = ("22C4F5", "1596DC", "3FD6FF", "1286CC", "2AB4EE", "55DCFF")
    rk = ("5A5670", "6E6A86", "4A4660")
    k = (1.0, 0.72, 0.45)[stage - 1]
    for i in range((6, 5, 4)[stage - 1]):                                                           # dunkler Felssockel
        a = math.radians(i * 60 + 15)
        s = rng.uniform(0.45, 0.7) * (0.6 + 0.4 * k)
        rockc(B, (s, s * 0.9, s * 0.6), (math.cos(a) * 0.6 * k, math.sin(a) * 0.6 * k, s * 0.22), rk[i % 3], rng)
    rockc(B, (0.9 * k, 0.8 * k, 0.5 * k), (0, 0, 0.2 * k), rk[1], rng)
    C = Part()
    full = [(0.0, 0.05, 0.32, 1.85, 0, 0), (0.42, -0.2, 0.24, 1.3, 16, 20), (-0.45, -0.1, 0.25, 1.4, -18, -10), (0.15, 0.45, 0.22, 1.2, 8, -22),
            (-0.2, -0.5, 0.18, 0.8, -8, 28), (0.62, 0.3, 0.16, 0.7, 26, -12), (-0.6, 0.4, 0.15, 0.65, -28, -16)]
    if stage == 1:
        lst = full
    elif stage == 2:
        lst = [(0.0, 0.05, 0.27, 1.2, 4, 0), (0.36, -0.2, 0.2, 0.85, 18, 20), (-0.35, -0.05, 0.2, 0.9, -20, -10), (0.1, 0.38, 0.16, 0.6, 8, -24)]
        B.cyl(0.26, 0.12, (-0.45, 0.4, 0.3), "1286CC", r=rot(10, -12, 0), sides=6)                 # abgeschlagene Stümpfe
    else:
        lst = [(0.02, 0.0, 0.2, 0.62, 6, 4), (0.26, -0.14, 0.14, 0.42, 22, 18), (-0.22, 0.12, 0.13, 0.36, -24, -14)]
        B.cyl(0.2, 0.1, (0.1, 0.3, 0.22), "1286CC", r=rot(-14, 10, 0), sides=6)
    for i, (x, y, r, h, ry, rx) in enumerate(lst):
        shard(C, T(x, y, 0.12 * k) @ rot(rx, ry, i * 25), r, h, cy[i % 6])
    for i in range(1 + (3 - stage) * 2):                                                            # Splitter am Boden
        a = rng.uniform(0, 6.28)
        rr = 0.95 * k + 0.2
        C.cyl(0.07, 0.24, (math.cos(a) * rr, math.sin(a) * rr, 0.05), cy[i % 6], r=rot(80, 0, rng.uniform(0, 180)), r2=0.01, sides=5)
    B.build("body", root)
    C.build("crystal_glow", root)
    fin(name, yaw=-30, pitch=20)


for _i in (1, 2, 3):
    REG["n_crystal_%d" % _i] = (lambda i=_i: crystal_node("n_crystal_%d" % i, i))


# ------------------------------------------------------------------ Batteriestapel
@model("n_battery")
def battery(name):
    root, B, G = start(name)
    for k in range(2):
        B.box((1.7, 1.3, 0.06), (0, 0, 0.03 + k * 0.14), WOOD_L)
    for dx in (-0.7, 0, 0.7):
        B.box((0.12, 1.3, 0.08), (dx, 0, 0.1), WOOD_D)

    def cell(x, y, z, yaw, body, w=0.7, d=0.42, h=0.46, led="6FE86A"):
        m = T(x, y, z) @ rot(0, 0, yaw)
        B.box((w, d, h), (0, 0, 0), body, r=m @ T(0, 0, h * 0.5), bevel=0.05, segs=1)
        B.box((w + 0.02, d + 0.02, 0.1), (0, 0, 0), "2E3340", r=m @ T(0, 0, h - 0.07))
        B.box((w * 0.5, 0.02, h * 0.3), (0, 0, 0), "FFE25A", r=m @ T(-w * 0.1, -d * 0.5 - 0.005, h * 0.4))     # Blitz-Etikett
        B.cyl(0.07, 0.03, (0, 0, 0), "2E3340", r=m @ T(-w * 0.1, -d * 0.5 - 0.02, h * 0.4) @ rot(90, 0, 0) @ S(0.6, 1.3, 1), sides=3)
        B.cyl(0.05, 0.1, (0, 0, 0), RED, r=m @ T(-w * 0.28, 0, h + 0.04), sides=6)
        B.cyl(0.05, 0.1, (0, 0, 0), "3F8FD0", r=m @ T(w * 0.28, 0, h + 0.04), sides=6)
        G.box((0.08, 0.03, 0.08), (0, 0, 0), led, r=m @ T(w * 0.33, -d * 0.5 - 0.01, h * 0.62))

    cell(-0.42, -0.3, 0.2, 4, "3F8FD0")
    cell(0.4, -0.32, 0.2, -6, "E8A020")
    cell(-0.4, 0.3, 0.2, -3, "4A5068")
    cell(0.42, 0.3, 0.2, 8, "3F8FD0", led="FFD24D")
    cell(-0.05, -0.05, 0.68, 14, "D9503E", led="FF5A4A")
    cell(0.5, 0.25, 0.68, -20, "4A5068", 0.6, 0.4, 0.4)
    # große Zelle mit Ladeanzeige daneben
    B.cyl(0.26, 0.9, (-1.0, -0.55, 0.45), "2FC1B0", sides=10, bevel=0.05, segs=1)
    B.cyl(0.275, 0.12, (-1.0, -0.55, 0.15), "2E3340", sides=10)
    B.cyl(0.275, 0.12, (-1.0, -0.55, 0.78), "2E3340", sides=10)
    B.cyl(0.1, 0.1, (-1.0, -0.55, 0.94), STEEL_L, sides=6)
    for i in range(3):
        G.box((0.14, 0.03, 0.12), (-1.0, -0.82, 0.3 + i * 0.16), "7CFF5A" if i < 2 else "5FE3FF")
    pts = [(-0.7, -0.3, 0.76), (-0.95, -0.5, 1.1), (-1.0, -0.55, 1.0)]                              # Kabel
    for i in range(2):
        tube(B, pts[i], pts[i + 1], 0.025, RED_D, 4)
    tube(B, (0.68, -0.3, 0.7), (1.05, -0.5, 0.05), 0.025, "23262E", 4)
    tube(B, (1.05, -0.5, 0.05), (1.3, -0.1, 0.03), 0.025, "23262E", 4)
    B.build("body", root)
    G.build("lamp_glow", root)
    fin(name, yaw=-30, pitch=24)


# ------------------------------------------------------------------ Scherbenader
@model("n_shard_vein")
def shard_vein(name):
    root, B, G = start(name)
    rng = random.Random(9)
    rk = ("4E4862", "5E5878", "3E3A50", "6E6888")
    V = Part()
    # Hauptblöcke nur um Z gedreht, damit die Adern sauber auf den Flächen liegen
    blocks = [((1.5, 1.2, 1.6), (0, 0.1, 0.8), 12, 0), ((1.0, 0.95, 1.0), (0.8, -0.2, 0.5), -20, 1), ((0.95, 0.9, 0.8), (-0.8, 0.0, 0.4), 30, 2)]
    for size, loc, rz, ci in blocks:
        B.box(size, loc, rk[ci], r=rot(0, 0, rz), bevel=min(size) * 0.2, segs=1)
    rockc(B, (0.8, 0.7, 0.6), (0.1, 0.2, 1.7), rk[3], rng)
    rockc(B, (0.5, 0.45, 0.4), (-0.5, -0.7, 0.18), rk[1], rng)
    rockc(B, (0.4, 0.4, 0.3), (0.9, 0.6, 0.14), rk[2], rng)
    gcol = ("7CFF5A", "A8FF7A", "4FE04A")
    for size, loc, rz, ci in blocks:                                                                # Adern auf Vorder- und Seitenfläche
        m = T(*loc) @ rot(0, 0, rz)
        w, d, h = size
        for face in range(2):
            fm = m @ (T(0, -d * 0.5 - 0.005, 0) if face == 0 else T(w * 0.5 + 0.005, 0, 0) @ rot(0, 0, 90))
            span = (w if face == 0 else d) * 0.36
            x, z = rng.uniform(-span, span), -h * 0.36
            while z < h * 0.34:
                nx, nz = max(-span, min(span, x + rng.uniform(-0.3, 0.3))), z + rng.uniform(0.18, 0.34)
                a, b = Vector((x, 0, z)), Vector((nx, 0, nz))
                dd = b - a
                V.box((0.07, 0.03, dd.length + 0.05), (0, 0, 0), gcol[(ci + face) % 3], r=fm @ T(*((a + b) * 0.5)) @ rot(0, math.degrees(math.atan2(dd.x, dd.z)), 0))
                if rng.random() < 0.4:                                                              # Seitenast
                    V.box((0.05, 0.03, 0.22), (0, 0, 0), gcol[ci % 3], r=fm @ T(nx, 0, nz) @ rot(0, rng.choice((-60, 60)), 0) @ T(0, 0, 0.11))
                x, z = nx, nz
    for (x, y, z, r, h, rx, ry) in ((0.35, -0.75, 0.85, 0.12, 0.5, 60, 10), (-0.2, -0.6, 1.3, 0.1, 0.4, 50, -20), (0.2, 0.0, 1.95, 0.13, 0.55, 5, 12),
                                    (-0.95, -0.5, 0.6, 0.09, 0.36, 40, -40), (1.15, -0.55, 0.75, 0.09, 0.34, 50, 40), (-0.2, 0.2, 1.9, 0.09, 0.36, -10, -25)):
        V.cyl(r, h, (0, 0, 0), gcol[int(abs(x * 10)) % 3], r=T(x, y, z) @ rot(rx, ry, 0) @ T(0, 0, h * 0.5), r2=0.01, sides=5)
    V.cyl(1.0, 0.02, (0.2, -1.05, 0.01), "4FE04A", r=S(0.3, 0.18, 1), sides=7)
    B.build("body", root)
    V.build("vein_glow", root)
    fin(name, yaw=-30, pitch=20)


# ------------------------------------------------------------------ Münzhaufen
@model("n_coinpile")
def coinpile(name):
    root, B, G = start(name)
    rng = random.Random(14)
    B.ball(1.0, (0, 0, 0.0), "EBA91A", scale=(0.85, 0.76, 0.5), subdiv=3)
    for i in range(18):                                                                             # Münzen auf dem Hügel
        a = i * 2.39996
        rr = 0.12 + 0.68 * (i / 18.0)
        z = 0.5 * math.sqrt(max(0.0, 1 - (rr / 0.8) ** 2)) + 0.01
        coin_(B, T(math.cos(a) * rr, math.sin(a) * rr * 0.9, z) @ rot(rng.uniform(-30, 30) + 28 * rr * math.sin(a), rng.uniform(-30, 30) - 28 * rr * math.cos(a), rng.uniform(0, 90)), 0.17, 0.05, lp=True)
    for i in range(5):                                                                              # lose Münzen am Boden
        a = rng.uniform(0, 6.28)
        coin_(B, T(math.cos(a) * 1.0, math.sin(a) * 0.9, 0.03) @ rot(0, 0, rng.uniform(0, 90)), 0.16, 0.05, lp=True)
    for k in range(5):                                                                              # Münzstapel
        coin_(B, T(0.75, -0.55, 0.03 + k * 0.058) @ rot(0, 0, k * 17), 0.17, 0.05, lp=True)
    coin_(B, T(-0.2, -0.86, 0.17) @ rot(72, 0, 20), 0.17, 0.05, lp=True)                                     # eine steht hochkant
    # Säckchen: eins zugebunden, eins offen mit Münzen
    sack(B, (-0.7, 0.3, 0.0), 1.1, "C9A46A", 20)
    coin_(B, T(-0.7, -0.03, 0.34) @ rot(90, 0, 14), 0.13, 0.03, lp=True)
    B.ball(1.0, (0.55, 0.45, 0.3), "B8905A", scale=(0.36, 0.32, 0.34), subdiv=2)
    B.cyl(0.24, 0.12, (0.55, 0.45, 0.6), "A67C48", r2=0.28, sides=8)
    B.cyl(0.24, 0.03, (0.55, 0.45, 0.65), "F0B21A", sides=8)
    for (dx, dy, t) in ((0.0, 0.0, 0), (0.1, -0.08, 30), (-0.09, 0.07, -24)):
        coin_(B, T(0.55 + dx, 0.45 + dy, 0.68) @ rot(t, t * 0.5, 0), 0.13, 0.04, lp=True)
    B.ball(0.09, (0.1, -0.2, 0.56), "FF5A6A", subdiv=2)                                             # ein Edelstein obenauf
    B.build("body", root)
    fin(name, yaw=-30, pitch=26)
