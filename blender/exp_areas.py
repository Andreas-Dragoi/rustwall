"""Schaubilder der sieben Gebiete für die Weltkarte: kleine Dioramen auf einer runden Scholle (Durchmesser 6 m).
Es wird nur das Symbol icons/area_<gebiet>.png gebraucht; die .glb wird nach dem Rendern wieder gelöscht."""
from exp_common import *


def clod(B, top, soil="8A5A3A", soil_d="6A4630", rim=None):
    """Runde Scholle: Oberseite bei z = 0, Erdkegel darunter."""
    B.cyl(3.0, 0.34, (0, 0, -0.17), top, sides=28, bevel=0.1, segs=2)
    if rim:
        B.cyl(3.02, 0.12, (0, 0, -0.26), rim, sides=28)
    B.cyl(1.7, 1.2, (0, 0, -0.9), soil, r2=2.85, sides=14)
    B.cyl(0.6, 0.7, (0, 0, -1.8), soil_d, r2=1.7, sides=10)
    rng = random.Random(1)
    for i in range(7):
        a = math.radians(i * 51 + 10)
        rr = 2.2 - (i % 3) * 0.35
        s = 0.5 + 0.2 * (i % 2)
        rockc(B, (s, s, s * 0.8), (math.cos(a) * rr, math.sin(a) * rr, -0.8 - (i % 3) * 0.35), (ROCK, ROCK_D, soil_d)[i % 3], rng)


def fir(B, x, y, h, g="3F9148", snow=False, trunk=WOOD_D):
    B.cyl(0.13, h * 0.3, (x, y, h * 0.15), trunk, r2=0.09, sides=6)
    n = 3
    for i in range(n):
        r = h * 0.3 * (1.0 - 0.3 * i)
        z = h * 0.2 + i * h * 0.24
        th = h * 0.42
        c = shade(g, 1.0 + 0.12 * i)
        B.cone(r, th, (x, y, z + th * 0.5), c, sides=8)
        if snow:
            B.cone(r * 0.62, th * 0.6, (x, y, z + th * 0.72), SNOW, sides=8)


def area_fin(name, root, B, G=None, glow="glow"):
    B.build("body", root)
    if G is not None:
        G.build(glow + "_glow", root)
    fin(name, yaw=-30, pitch=30, keep_glb=False)


# ------------------------------------------------------------------ Grüntal
@model("area_gruental")
def a_gruental(name):
    root, B, G = start(name)
    clod(B, "8FC23A", rim="6FA02E")
    # Bach: von hinten links nach vorn rechts
    pts = [(-2.6, 1.5), (-1.6, 1.0), (-0.7, 0.2), (0.3, -0.3), (1.2, -1.1), (1.9, -2.2)]
    for i in range(len(pts) - 1):
        a, b = Vector((pts[i][0], pts[i][1], 0.012)), Vector((pts[i + 1][0], pts[i + 1][1], 0.012))
        beam(B, a, b, 0.85, "4FA8E8", d=0.03)
        beam(B, a + Vector((0, 0, 0.012)), b + Vector((0, 0, 0.012)), 0.4, "8FD0F5", d=0.03)
        B.cyl(0.42, 0.03, a, "4FA8E8", sides=10)
    for (x, y) in ((-1.1, 0.75), (0.75, -0.55), (-2.0, 1.45)):
        B.ball(0.14, (x, y, 0.05), ROCK_L, scale=(1, 1, 0.6), subdiv=2)
    # Holzbrücke über die Mitte
    m = T(-0.2, -0.05, 0) @ rot(0, 0, 48)
    for i in range(7):
        t = (i - 3) / 3.0
        B.box((0.26, 1.0, 0.08), (0, 0, 0), WOOD_L if i % 2 else "C98A48", r=m @ T(t * 0.85, 0, 0.42 - 0.3 * t * t) @ rot(0, t * 28, 0), bevel=0.02, segs=1)
    for s in (-1, 1):
        for i in (-1, 1):
            B.box((0.1, 0.1, 0.62), (0, 0, 0), WOOD_D, r=m @ T(i * 0.86, s * 0.47, 0.34))
        for i in range(4):
            t0, t1 = (i - 2) / 2.0, (i - 1) / 2.0
            a = m @ Vector((t0 * 0.86, s * 0.47, 0.84 - 0.24 * t0 * t0))
            b = m @ Vector((t1 * 0.86, s * 0.47, 0.84 - 0.24 * t1 * t1))
            beam(B, a, b, 0.07, WOOD_D)
    # Tannen, Büsche, Blumen
    for (x, y, h) in ((1.6, 1.5, 2.9), (0.6, 2.1, 2.3), (2.2, 0.4, 2.2), (-1.9, -0.9, 2.6), (-0.9, -1.9, 2.0)):
        fir(B, x, y, h)
    B.ball(0.42, (-2.2, 0.2, 0.25), LEAF, scale=(1, 1, 0.8), subdiv=2)
    B.ball(0.34, (1.3, 0.55, 0.2), LEAF_D, scale=(1, 1, 0.8), subdiv=2)
    rockc(B, (0.6, 0.5, 0.45), (0.2, -2.2, 0.18), ROCK, random.Random(2))
    for i, (x, y) in enumerate(((-1.4, -0.3), (-0.6, -1.1), (0.9, 1.1), (2.0, -0.6), (-0.3, 1.7), (-2.4, -0.4), (1.0, -1.9), (0.1, 1.0))):
        c = ("FFFFFF", "FFD23E", "F07AB4", "FF8A3A")[i % 4]
        B.cyl(0.02, 0.2, (x, y, 0.1), "4F8A2E", sides=4)
        B.ball(0.09, (x, y, 0.23), c, scale=(1, 1, 0.6), subdiv=1)
    tuft(B, -1.3, 1.9, 0, 5, 0.9, 3)
    tuft(B, 2.3, -1.1, 0, 5, 0.9, 4)
    area_fin(name, root, B)


# ------------------------------------------------------------------ Kiefernforst
@model("area_forst")
def a_forst(name):
    root, B, G = start(name)
    clod(B, "3F7040", rim="2F5632")
    for i, (x, y, h) in enumerate(((1.7, 1.5, 3.6), (0.3, 2.0, 3.1), (-1.4, 1.6, 3.4), (2.3, 0.0, 2.9), (-2.3, 0.3, 3.0), (0.6, 0.6, 3.3), (-0.8, 0.5, 2.8),
                                   (1.6, -1.3, 2.5), (-1.8, -1.2, 2.6))):
        fir(B, x, y, h, ("245C3C", "2B6844", "1F5236")[i % 3], trunk="4A3020")
    for (x, y, k, c) in ((0.0, -1.6, 1.7, RED), (-0.8, -2.0, 1.1, RED), (0.9, -2.1, 1.0, "E8862A"), (2.2, -1.0, 0.8, RED), (-2.3, -0.6, 0.9, "E8862A")):
        mushroom(B, x, y, 0, k, c)
    log_(B, T(-0.6, -0.9, 0.2) @ rot(0, 0, 20) @ rot(0, 90, 0), 0.2, 1.3, 8, "5E3E26")
    for (x, y, z, sx, sy) in ((0.6, -0.5, 1.15, 1.5, 0.7), (-1.6, 0.4, 1.35, 1.3, 0.6), (1.7, 0.7, 1.5, 1.2, 0.6), (-0.3, 1.5, 1.7, 1.4, 0.6), (-2.1, -1.2, 0.9, 0.9, 0.45), (2.2, -1.5, 0.95, 0.8, 0.4)):
        B.ball(1.0, (x, y, z), "B4CBD6", scale=(sx, sy, 0.13), subdiv=2)                            # Nebelbänke zwischen den Stämmen
        B.ball(1.0, (x + 0.5, y - 0.1, z + 0.12), "C6D9E2", scale=(sx * 0.5, sy * 0.6, 0.1), subdiv=2)
    tuft(B, 1.5, -2.0, 0, 5, 1.0, 3, cols=("3A7D3A", "5E9A32", "2F6B34"))
    area_fin(name, root, B)


# ------------------------------------------------------------------ Staubebene
def cactus(B, x, y, h):
    g = "5FA04C"
    B.cyl(0.2, h, (x, y, h * 0.5), g, sides=8, bevel=0.15, segs=2)
    for s, z, up in ((1, h * 0.45, h * 0.35), (-1, h * 0.6, h * 0.25)):
        B.cyl(0.11, 0.36, (x + s * 0.26, y, z), g, r=rot(0, 90, 0), sides=6)
        B.cyl(0.11, up, (x + s * 0.42, y, z + up * 0.5), g, sides=6, bevel=0.08, segs=1)
    B.ball(0.08, (x, y, h + 0.02), "F07AB4", subdiv=1)


@model("area_staub")
def a_staub(name):
    root, B, G = start(name)
    clod(B, "E6BA6E", soil="B5743A", soil_d="8A5228", rim="C99A52")
    # Straße quer
    m = T(0, -1.2, 0.012) @ rot(0, 0, 14)
    B.box((6.4, 1.1, 0.03), (0, 0, 0), "6E6A6E", r=m)
    for i in range(6):
        B.box((0.5, 0.1, 0.035), (0, 0, 0), "F4E9C8", r=m @ T(-2.5 + i * 1.0, 0, 0))
    # Tankstelle
    B.box((1.5, 1.0, 1.1), (-0.3, 1.5, 0.55), "F6E7C4", bevel=0.08, segs=1)
    B.box((1.54, 1.04, 0.2), (-0.3, 1.5, 1.05), RED, bevel=0.03, segs=1)
    B.box((0.5, 0.05, 0.6), (0.05, 0.98, 0.42), "3F8FD0")
    G.box((0.6, 0.05, 0.36), (-0.6, 0.98, 0.65), GLOW)
    B.box((2.4, 1.6, 0.22), (-0.2, 0.2, 1.75), RED, bevel=0.07, segs=1)
    B.box((2.44, 1.64, 0.08), (-0.2, 0.2, 1.75), "FFF6E0")
    for sx in (-1, 1):
        B.cyl(0.08, 1.7, (-0.2 + sx * 0.95, -0.35, 0.85), "FFF6E0", sides=6)
    B.box((1.3, 0.5, 0.1), (-0.2, 0.2, 0.05), CONC_D)
    for sx, c in ((-1, RED), (1, YEL)):
        B.box((0.3, 0.26, 0.75), (-0.2 + sx * 0.35, 0.2, 0.47), c, bevel=0.07, segs=1)
        B.box((0.2, 0.04, 0.16), (-0.2 + sx * 0.35, 0.06, 0.62), "2E3340")
    B.cyl(0.06, 2.6, (1.5, -0.2, 1.3), STEEL, sides=6)
    B.cyl(0.42, 0.12, (1.5, -0.2, 2.75), YEL, r=rot(90, 0, 0), sides=12)
    B.torus(0.42, 0.05, (1.5, -0.2, 2.75), RED, r=rot(90, 0, 0), seg=12, tseg=4)
    B.ball(1.0, (1.5, -0.27, 2.7), RED, scale=(0.16, 0.04, 0.16), subdiv=2)
    B.cyl(1.0, 0.04, (1.5, -0.27, 2.9), RED, r=rot(90, 0, 0) @ S(0.12, 0.16, 1), sides=3)
    # Autowrack an der Straße
    cm = T(-1.6, -1.55, 0.02) @ rot(4, 0, 30)
    B.box((1.5, 0.75, 0.32), (0, 0, 0), "E2B648", r=cm @ T(0, 0, 0.3), bevel=0.1, segs=2)
    B.box((0.7, 0.66, 0.3), (0, 0, 0), "C99A38", r=cm @ T(-0.1, 0, 0.58), bevel=0.1, segs=2)
    B.box((0.5, 0.68, 0.14), (0, 0, 0), "2E3340", r=cm @ T(-0.1, 0, 0.6))
    B.box((0.45, 0.62, 0.04), (0, 0, 0), "E2B648", r=cm @ T(0.55, 0, 0.6) @ rot(0, -40, 0))
    for (x, y) in ((0.45, -0.38), (-0.45, 0.38), (0.45, 0.38)):
        B.cyl(0.17, 0.12, (0, 0, 0), "23262E", r=cm @ T(x, y, 0.17) @ rot(90, 0, 0), sides=8)
    B.box((0.3, 0.03, 0.2), (0, 0, 0), RUST, r=cm @ T(0.2, -0.385, 0.32))
    # Kakteen, Felsen, Strauchkugel
    cactus(B, 2.2, 1.0, 1.4)
    cactus(B, -2.3, 0.6, 1.1)
    cactus(B, 0.9, -2.2, 0.9)
    rng = random.Random(4)
    for (x, y, s) in ((2.3, -0.9, 0.6), (1.9, -1.2, 0.4), (-2.0, 1.7, 0.5), (1.4, 2.0, 0.45)):
        rockc(B, (s, s * 0.9, s * 0.7), (x, y, s * 0.3), ("C98A5A", "B5743A")[int(s * 10) % 2], rng)
    B.ball(0.26, (0.4, -2.0, 0.26), "B08A4A", subdiv=2)
    for a in range(0, 360, 60):
        B.torus(0.26, 0.02, (0.4, -2.0, 0.26), "8A6A32", r=rot(a, a * 0.5, 0), seg=8, tseg=3)
    area_fin(name, root, B, G, "win")


# ------------------------------------------------------------------ Schrottküste
@model("area_kueste")
def a_kueste(name):
    root, B, G = start(name)
    clod(B, "4FA8E8", soil="C9A46A", soil_d="A8824E", rim="3B8AD0")
    # Strand: hintere rechte Hälfte
    B.ball(1.0, (1.1, 1.3, -0.1), "EBCB8A", scale=(2.5, 2.2, 0.3), subdiv=3)
    for (x, y, s) in ((-1.1, 1.0, 1.5), (0.6, -0.9, 1.3), (-0.3, 0.1, 1.6)):                        # Brandung
        B.cyl(1.0, 0.03, (x, y, 0.012), "DFF3FF", r=rot(0, 0, 40) @ S(s * 0.16, s * 0.6, 1), sides=10)
    # Schiffswrack im Wasser, schräg auf Grund
    sm = T(-1.2, -0.9, 0.0) @ rot(0, 0, 28) @ rot(14, -10, 0)
    B.box((2.6, 0.95, 0.75), (0, 0, 0), "2E3340", r=sm @ T(0, 0, 0.25), bevel=0.18, segs=2)
    B.box((2.62, 0.97, 0.28), (0, 0, 0), "A8402E", r=sm @ T(0, 0, 0.0), bevel=0.08, segs=1)
    B.cyl(0.48, 0.74, (0, 0, 0), "2E3340", r=sm @ T(1.3, 0, 0.26) @ S(1.4, 1, 1), sides=3)
    B.box((1.0, 0.75, 0.55), (0, 0, 0), "F4F6FA", r=sm @ T(-0.55, 0, 0.9), bevel=0.08, segs=1)
    B.box((0.8, 0.77, 0.16), (0, 0, 0), "2E4A66", r=sm @ T(-0.5, 0, 1.0))
    B.box((0.6, 0.5, 0.3), (0, 0, 0), "F4F6FA", r=sm @ T(-0.6, 0, 1.3), bevel=0.06, segs=1)
    B.cyl(0.17, 0.6, (0, 0, 0), RED, r=sm @ T(-0.75, 0, 1.7), sides=8)
    B.cyl(0.18, 0.14, (0, 0, 0), "2E3340", r=sm @ T(-0.75, 0, 1.95), sides=8)
    B.cyl(0.03, 0.9, (0, 0, 0), STEEL, r=sm @ T(0.6, 0, 1.05), sides=5)
    for (x, s) in ((0.5, 0.4), (-0.2, 0.3), (1.0, 0.3)):
        B.box((s, 0.03, s * 0.6), (0, 0, 0), RUST, r=sm @ T(x, -0.485, 0.35))
    # Container am Strand
    for (x, y, z, rz, c, ln) in ((1.6, 1.6, 0.12, 20, "D8483F", 1.7), (0.5, 2.1, 0.12, -30, "3B7FD0", 1.6), (1.4, 1.7, 0.92, 32, "F2A024", 1.5), (2.2, 0.2, 0.1, 80, "2FA79A", 1.3)):
        cm = T(x, y, z) @ rot(0, 0, rz)
        B.box((ln, 0.75, 0.8), (0, 0, 0), c, r=cm @ T(0, 0, 0.4), bevel=0.04, segs=1)
        for i in range(5):
            B.box((ln / 12, 0.78, 0.66), (0, 0, 0), shade(c, 0.75), r=cm @ T(-ln * 0.5 + (i + 0.5) * ln / 5, 0, 0.4))
    # Palme, Reifen, Fass
    px, py = 0.0, 1.0
    pts = [Vector((px, py, 0.1)), Vector((px - 0.1, py - 0.05, 0.9)), Vector((px - 0.3, py - 0.15, 1.6)), Vector((px - 0.6, py - 0.25, 2.2))]
    for i in range(3):
        limb(B, pts[i], pts[i + 1], 0.12 - i * 0.02, 0.1 - i * 0.02, "A8824E", 6)
    for k in range(6):
        a = math.radians(k * 60 + 15)
        e = pts[3] + Vector((math.cos(a) * 0.95, math.sin(a) * 0.95, -0.3))
        beam(B, pts[3] + Vector((0, 0, 0.05)), e, 0.34, "4FA84A" if k % 2 else "3F9148", d=0.05)
    B.ball(0.1, pts[3] + Vector((0.1, 0, -0.1)), "7A4522", subdiv=1)
    tire(B, T(2.1, -0.9, 0.16), 0.24, 0.16, lp=True)
    barrel(B, (0.95, 0.5, 0.12), ORANGE, 0.18, 0.45)
    anchor_x = T(-0.3, 1.9, 0.12) @ rot(-30, 20, 40)
    B.box((0.07, 0.07, 0.8), (0, 0, 0), "4A5068", r=anchor_x @ T(0, 0, 0.4))
    B.box((0.5, 0.07, 0.07), (0, 0, 0), "4A5068", r=anchor_x @ T(0, 0, 0.08))
    area_fin(name, root, B)


# ------------------------------------------------------------------ Sumpfwerk
@model("area_sumpf")
def a_sumpf(name):
    root, B, G = start(name)
    clod(B, "71804A", soil="6A5A3A", soil_d="4E4028", rim="566238")
    for (x, y, s, e) in ((-1.4, -1.3, 1.1, 0.7), (1.5, -0.6, 0.9, 0.8), (0.2, -2.1, 0.7, 0.6), (-2.1, 0.6, 0.6, 0.9), (1.9, 1.5, 0.6, 0.7)):   # grüne Tümpel
        B.cyl(1.0, 0.03, (x, y, 0.012), "5E9A2C", r=S(s, s * e, 1), sides=12)
        G.cyl(1.0, 0.03, (x, y, 0.02), "8FE04A", r=S(s * 0.8, s * e * 0.78, 1), sides=12)
        G.ball(0.1, (x + s * 0.3, y, 0.05), "C8FF7A", subdiv=1)
    # halb versunkene Fabrik, schief
    fm = T(0.1, 1.0, -0.25) @ rot(-5, 7, -12)
    B.box((2.8, 1.7, 1.6), (0, 0, 0), BRICK, r=fm @ T(0, 0, 0.8), bevel=0.06, segs=1)
    for i in range(3):
        B.box((2.82, 1.72, 0.035), (0, 0, 0), BRICK_D, r=fm @ T(0, 0, 0.5 + i * 0.4))
    for i in range(3):                                                                              # Sheddach
        B.cyl(1.0, 1.7, (0, 0, 0), "6E7890", r=fm @ T(-0.93 + i * 0.93, 0, 1.6 + 0.16) @ rot(90, 0, 0) @ S(0.5, 0.5, 1) @ rot(0, 0, 30), sides=3)
    for i in range(3):
        G.box((0.4, 0.05, 0.34), (0, 0, 0), "C8F26A", r=fm @ T(-0.9 + i * 0.9, -0.86, 1.05))
        B.box((0.5, 0.04, 0.44), (0, 0, 0), "2E3340", r=fm @ T(-0.9 + i * 0.9, -0.845, 1.05))
    B.cyl(0.26, 2.6, (0, 0, 0), "8A5A4A", r=fm @ T(1.0, 0.4, 2.2), r2=0.2, sides=8)                 # Schlot
    B.cyl(0.25, 0.2, (0, 0, 0), "F4F6FA", r=fm @ T(1.0, 0.4, 3.0), sides=8)
    B.cyl(0.25, 0.14, (0, 0, 0), "3A3238", r=fm @ T(1.0, 0.4, 3.48), sides=8)
    for (dx, dz, r) in ((0.15, 0.4, 0.32), (0.45, 0.85, 0.4), (0.3, 1.35, 0.3)):                    # grüner Qualm
        q = fm @ Vector((1.0 + dx, 0.4, 3.5 + dz))
        B.ball(r, q, "A9D25A", subdiv=2)
    # Rohre in den Tümpel
    pg = "4FA36A"
    pts = [(-0.9, 0.2, 0.75), (-1.3, -0.5, 0.75), (-1.3, -0.5, 0.25), (-1.4, -1.0, 0.25)]
    for i in range(3):
        tube(B, pts[i], pts[i + 1], 0.2, pg, 8)
        B.ball(0.23, pts[i + 1], pg, subdiv=2)
    B.cyl(0.26, 0.1, (-1.4, -1.0, 0.25), STEEL, r=rot(90, 0, 10), sides=8)
    G.cyl(0.1, 0.4, (-1.42, -1.15, 0.12), "8FE04A", r=rot(40, 0, 10), sides=5)
    tube(B, (1.2, 0.5, 0.5), (2.2, -0.2, 0.5), 0.16, "357A50", 8)
    for x in (1.5, 1.9):
        B.box((0.12, 0.3, 0.5), (x, 0.3 - (x - 1.2) * 0.7, 0.25), CONC_D)
    # toter Baum, Schilf
    tx, ty = -2.0, -0.4
    limb(B, (tx, ty, 0), (tx + 0.1, ty, 1.5), 0.14, 0.08, "5A4636", 6)
    limb(B, (tx + 0.06, ty, 0.9), (tx + 0.6, ty + 0.2, 1.5), 0.06, 0.03, "5A4636", 5)
    limb(B, (tx + 0.08, ty, 1.2), (tx - 0.4, ty - 0.1, 1.8), 0.06, 0.03, "5A4636", 5)
    for (x, y) in ((0.9, -1.4), (2.2, 0.6), (-0.6, -2.3), (-2.5, 1.2)):
        for k in range(3):
            B.cyl(0.02, 0.7, (x + k * 0.1, y + (k % 2) * 0.08, 0.35), "6F9A2A", sides=4)
            B.cyl(0.045, 0.2, (x + k * 0.1, y + (k % 2) * 0.08, 0.72), "6A4A2A", sides=5)
    area_fin(name, root, B, G, "ooze")


# ------------------------------------------------------------------ Frostpass
@model("area_frost")
def a_frost(name):
    root, B, G = start(name)
    clod(B, "F1F6FC", soil="7E88A0", soil_d="5E6880", rim="C9DCF0")
    rng = random.Random(6)
    # Eishöhle: Eisberg mit dunklem Eingang
    B.ball(1.0, (0.3, 0.9, -0.1), ICE_D, scale=(2.0, 1.5, 1.9), subdiv=2)
    B.ball(1.0, (0.2, 0.95, 0.5), SNOW, scale=(1.7, 1.3, 1.5), subdiv=2)
    for (x, y, z, s, c) in ((-1.2, 0.6, 0.5, 1.1, ICE), (1.6, 0.9, 0.5, 1.2, "74BDEA"), (0.5, 1.8, 0.8, 1.2, ICE_D), (-0.6, 1.5, 1.2, 1.0, "A9E2FA")):
        rockc(B, (s, s * 0.9, s * 1.1), (x, y, z), c, rng, 0.14)
    B.ball(1.0, (0.25, -0.38, 0.5), "1E2A44", scale=(0.72, 0.3, 0.82), subdiv=3)                    # Höhleneingang
    B.torus(0.78, 0.2, (0.25, -0.3, 0.42), ICE, r=rot(90, 0, 0) @ S(1.0, 1.15, 1), seg=12, tseg=5)
    G.ball(1.0, (0.25, -0.52, 0.3), "5FE3FF", scale=(0.3, 0.1, 0.3), subdiv=2)                      # Schimmer in der Höhle
    for i, x in enumerate((-0.3, 0.0, 0.3, 0.6, 0.85)):                                             # Eiszapfen
        h = 0.3 + 0.2 * (i % 2)
        B.cone(0.08, h, (x, -0.58, 1.18 - 0.1 * abs(i - 2) - h * 0.5), ICE_L, r=rot(180, 0, 0), sides=5)
    # Eiszacken, Schneetannen, Schneemann
    for (x, y, h, r) in ((2.1, -0.6, 1.7, 0.36), (2.4, -0.2, 1.1, 0.28), (1.8, -1.0, 0.9, 0.24), (-2.2, 1.3, 1.3, 0.3)):
        B.cyl(r, h, (x, y, h * 0.5), (ICE, "74BDEA", ICE_L)[int(h * 10) % 3], r=rot(rng.uniform(-10, 10), rng.uniform(-10, 10), 0), r2=0.02, sides=5)
    fir(B, -1.9, -0.6, 2.4, "3C7A55", snow=True)
    fir(B, -1.0, -1.7, 1.8, "3C7A55", snow=True)
    fir(B, 2.0, 1.7, 2.0, "3C7A55", snow=True)
    sx, sy = 1.0, -1.7
    B.ball(0.34, (sx, sy, 0.28), SNOW, subdiv=2)
    B.ball(0.25, (sx, sy, 0.72), SNOW, subdiv=2)
    B.ball(0.18, (sx, sy, 1.05), SNOW, subdiv=2)
    B.cone(0.04, 0.2, (sx, sy - 0.24, 1.05), ORANGE, r=rot(90, 0, 0), sides=5)
    B.cyl(0.15, 0.2, (sx, sy, 1.28), "2E3340", sides=8)
    B.cyl(0.22, 0.03, (sx, sy, 1.19), "2E3340", sides=8)
    B.cyl(0.26, 0.07, (sx, sy, 0.9), RED, sides=8)
    for (x, y, s) in ((-0.5, -2.2, 0.6), (2.3, 0.8, 0.5), (-2.4, 0.3, 0.5)):
        B.ball(1.0, (x, y, 0.0), SNOW, scale=(s, s * 0.8, 0.24), subdiv=2)
    area_fin(name, root, B, G, "ice")


# ------------------------------------------------------------------ Schleimkrater
@model("area_krater")
def a_krater(name):
    root, B, G = start(name)
    clod(B, "5E5674", soil="4A4460", soil_d="34304A", rim="4A4460")
    rng = random.Random(13)
    rk = ("6E6688", "5A5272", "7E7698", "4A4460")
    # Kraterrand aus Felsbrocken
    for i in range(12):
        a = math.radians(i * 30 + rng.uniform(-6, 6))
        s = rng.uniform(0.75, 1.1)
        rockc(B, (s, s * 0.8, s * (0.8 + 0.5 * (i % 2))), (math.cos(a) * 1.75, math.sin(a) * 1.75, s * 0.3), rk[i % 4], rng)
    B.torus(1.75, 0.42, (0, 0, 0.05), rk[1], seg=14, tseg=5)
    # leuchtender Schleimsee
    G.cyl(1.55, 0.1, (0, 0, 0.3), "6FE03A", sides=18)
    G.cyl(1.0, 0.1, (0.1, 0.05, 0.31), "9CFF5A", sides=14)
    G.cyl(0.45, 0.1, (0.15, 0.1, 0.32), "D8FF9A", sides=10)
    for (x, y, r) in ((-0.7, -0.5, 0.2), (0.6, -0.7, 0.26), (0.8, 0.5, 0.16), (-0.4, 0.8, 0.22)):
        G.ball(r, (x, y, 0.36), "C8FF7A", subdiv=2)
    # Schleim läuft über den Rand, grüne Scherben, Dampf
    for a_deg, ln in ((250, 1.3), (300, 0.9), (200, 0.8), (340, 0.7)):
        a = math.radians(a_deg)
        x, y = math.cos(a) * 2.6, math.sin(a) * 2.6
        B.ball(1.0, (x, y, 0.02), SLIME, scale=(0.5, 0.5, 0.12), subdiv=2)
        B.cyl(0.2, ln, (math.cos(a) * 2.98, math.sin(a) * 2.98, -ln * 0.5), SLIME, r2=0.12, sides=6)
        B.ball(0.17, (math.cos(a) * 2.98, math.sin(a) * 2.98, -ln), SLIME_L, subdiv=2)
        beam(B, (math.cos(a) * 1.9, math.sin(a) * 1.9, 0.35), (x, y, 0.03), 0.4, SLIME, d=0.08)
    for (x, y, h, r, rx, ry) in ((2.3, 1.0, 1.1, 0.2, 10, 15), (2.5, 0.6, 0.7, 0.15, -10, 25), (-2.2, 1.4, 0.9, 0.18, 12, -18), (-2.5, -0.2, 0.6, 0.14, -8, -22), (1.4, 2.3, 0.7, 0.15, 20, 5)):
        G.cyl(r, h, (x, y, h * 0.5), "5FE04A", r=rot(rx, ry, 0), r2=0.02, sides=5)
    for (x, y, z, r) in ((0.0, 0.2, 1.3, 0.36), (0.4, -0.1, 2.0, 0.3), (-0.2, 0.3, 2.6, 0.22)):
        B.ball(r, (x, y, z), "B8E86A", subdiv=2)
    limb(B, (-2.0, -1.6, 0), (-1.9, -1.6, 1.3), 0.12, 0.06, "3A3248", 6)                            # verkohlter Baum
    limb(B, (-1.92, -1.6, 0.8), (-1.4, -1.8, 1.4), 0.05, 0.02, "3A3248", 5)
    limb(B, (-1.9, -1.6, 1.0), (-2.3, -1.3, 1.6), 0.05, 0.02, "3A3248", 5)
    area_fin(name, root, B, G, "pool")
