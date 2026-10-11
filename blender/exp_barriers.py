"""Sperren der Durchgänge (x_barrier_<gebiet>): 8 m breit entlang X, etwa 3 m tief, 2,5–3,5 m hoch, blickdicht.
Ein Objekt `body`; Sumpf zusätzlich Leerobjekte fx_steam1..4 und `ooze_glow`, Krater zusätzlich pulse_bubble1..3."""
from exp_common import *


def _fin(name, root, B):
    B.build("body", root)
    fin(name, yaw=-28, pitch=22)


# ------------------------------------------------------------------ Grüntal: Dornenhecke
@model("x_barrier_gruental")
def b_gruental(name):
    root, B, G = start(name)
    rng = random.Random(11)
    g = ("2F6B34", "3A7D3A", "2A5C30", "44893C")
    B.box((7.4, 1.5, 1.8), (0, 0, 0.9), "23482A", bevel=0.3, segs=1)                                # dunkler Kern
    k = 0
    for row, (y, z, rr) in enumerate(((-0.6, 0.75, 0.9), (0.6, 0.8, 0.9), (0.0, 1.7, 0.95))):
        n = 5
        for i in range(n):
            x = -2.85 + i * 5.7 / (n - 1) + rng.uniform(-0.1, 0.1)
            r = rr * rng.uniform(0.98, 1.08)
            B.ball(r, (x, y + rng.uniform(-0.15, 0.15), z + rng.uniform(-0.1, 0.25)), g[k % 4], r=rot(rng.uniform(0, 90), rng.uniform(0, 90), 0),
                   scale=(1.0, 0.9, 0.9), subdiv=2)
            k += 1
    # Dornenranken: braune Bögen mit Stacheln
    vine, thorn = "6A4A2A", "E8D9B0"
    for j in range(6):
        x0 = -3.3 + j * 1.2 + rng.uniform(-0.15, 0.15)
        s = -1 if j % 2 == 0 else 1
        pts = []
        for t in range(6):
            a = math.pi * t / 5.0
            pts.append(Vector((x0 + t * 0.22 * (1 if j % 3 else -1), -s * 1.3 * math.cos(a), 0.1 + 2.7 * math.sin(a) + rng.uniform(-0.05, 0.05))))
        for t in range(5):
            limb(B, pts[t], pts[t + 1], 0.085, 0.085, vine, 5)
            mid = (pts[t] + pts[t + 1]) * 0.5
            d = (pts[t + 1] - pts[t]).normalized()
            for q in range(1):
                n = Vector((rng.uniform(-1, 1), rng.uniform(-1, 1), rng.uniform(-0.2, 1))).cross(d).normalized()
                B.cone(0.085, 0.5, (0, 0, 0), thorn, r=T(*(mid + n * 0.28)) @ face_to(n), sides=4)
    for i in range(9):                                                                              # rote Beeren
        x = rng.uniform(-3.4, 3.4)
        s = rng.choice((-1, 1))
        z = rng.uniform(0.5, 2.5)
        y = s * (1.38 if z < 1.3 else 0.85) * rng.uniform(0.9, 1.0)
        B.ball(0.11, (x, y, z), "E0334A" if i % 3 else "FF6FA8", subdiv=1)
    for x in (-3.7, -0.5, 3.4):
        tuft(B, x, -1.42, 0, 5, 1.2, int(x * 10) + 60, cols=("3A7D3A", "5E9A32", "2F6B34"))
    _fin(name, root, B)


# ------------------------------------------------------------------ Kiefernforst: umgestürzte Stämme
@model("x_barrier_forst")
def b_forst(name):
    root, B, G = start(name)
    rng = random.Random(5)
    bark = ("6E4A2C", "7A5230", "5E3E26")
    lay = ((-0.92, 0.56, 0.56, 7.4, 2), (0.05, 0.6, 0.6, 7.7, -1.5), (0.98, 0.54, 0.54, 7.2, 2.5),
           (-0.45, 1.52, 0.52, 7.4, -2.5), (0.55, 1.55, 0.5, 7.0, 3), (0.05, 2.42, 0.5, 6.6, -2))
    for i, (y, z, r, ln, yaw) in enumerate(lay):
        m = T(rng.uniform(-0.12, 0.12), y, z) @ rot(0, 0, yaw) @ rot(0, 90 + rng.uniform(-2, 2), 0)
        log_(B, m, r, ln, 10, bark[i % 3])
        for q in range(1):                                                                          # Aststummel
            zz = rng.uniform(-ln * 0.4, ln * 0.4)
            a = rng.uniform(20, 160) if y <= 0 else rng.uniform(200, 340)
            mm = m @ T(0, 0, zz) @ rot(0, 0, a) @ rot(0, 90, 0) @ T(0, 0, r + 0.2)
            B.cyl(0.13, 0.5, (0, 0, 0), bark[(i + 1) % 3], r=mm, r2=0.1, sides=6)
            B.cyl(0.085, 0.02, (0, 0, 0), CUT, r=mm @ T(0, 0, 0.255), sides=6)
    # Wurzelteller am linken Ende des großen Stamms
    wm = T(-3.82, 0.05, 0.75) @ rot(0, -90, 0)
    B.cyl(0.85, 0.3, (0, 0, 0), "4A3524", r=wm, sides=9)
    for k in range(7):
        a = k * 51 + 10
        B.cyl(0.14, 0.7, (0, 0, 0), "5E3E26", r=wm @ rot(0, 0, a) @ T(0.8, 0, 0.0) @ rot(0, 90, 0), r2=0.04, sides=5)
    # abgebrochene Stümpfe an den Enden
    for (x, y, h) in ((3.45, -0.95, 2.2), (-3.3, 1.0, 2.5)):
        B.cyl(0.42, h, (x, y, h * 0.5), bark[1], r2=0.34, sides=9)
        for k in range(5):
            a = math.radians(k * 72)
            B.cone(0.12, 0.5 + 0.2 * (k % 2), (x + math.cos(a) * 0.2, y + math.sin(a) * 0.2, h + 0.2), CUT, sides=4)
        B.cyl(0.52, 0.24, (x, y, 0.12), bark[2], r2=0.42, sides=9)
    # Moos, Pilze, Farn
    for (x, y, z, s) in ((-1.5, 0.0, 2.86, 0.7), (1.2, 0.1, 2.88, 0.55), (2.3, -0.5, 1.98, 0.6), (-2.6, 0.6, 2.0, 0.65), (0.2, -1.0, 1.08, 0.7)):
        B.ball(1.0, (x, y, z), "5E9A32" if int(x * 10) % 2 else "7AAE3A", scale=(s, s * 0.6, 0.14), subdiv=2)
    mushroom(B, -0.6, -1.2, 0.9, 0.7)
    mushroom(B, 2.0, -1.22, 0.85, 0.5, "E8862A")
    mushroom(B, -3.0, -1.3, 0.0, 0.8)
    for x in (-2.0, 3.0):
        tuft(B, x, -1.45, 0, 6, 1.2, int(x) + 9, cols=("3A7D3A", "5E9A32", "2F6B34"))
    _fin(name, root, B)


# ------------------------------------------------------------------ Staubebene: Schrottwall
def car_hull(p, m, color, ln=2.5, cab=True):
    p.box((ln, 1.5, 0.7), (0, 0, 0), color, r=m @ T(0, 0, 0.4), bevel=0.16, segs=1)
    if cab:
        p.box((ln * 0.5, 1.36, 0.6), (0, 0, 0), shade(color, 0.86), r=m @ T(-ln * 0.06, 0, 0.98), bevel=0.16, segs=1)
        p.box((ln * 0.36, 1.4, 0.3), (0, 0, 0), "2E3340", r=m @ T(-ln * 0.06, 0, 1.02))
    for s in (-1, 1):
        p.cyl(0.3, 1.56, (0, 0, 0), "23262E", r=m @ T(ln * 0.3 * s, 0, 0.2) @ rot(90, 0, 0), sides=8)
    p.box((0.5, 0.04, 0.3), (0, 0, 0), RUST, r=m @ T(ln * 0.2, -0.76, 0.45))
    p.box((0.4, 0.04, 0.24), (0, 0, 0), RUST_D, r=m @ T(-ln * 0.3, 0.76, 0.5))


@model("x_barrier_staub")
def b_staub(name):
    root, B, G = start(name)
    rng = random.Random(8)
    bale = ("8A5A3A", "6E7F86", "B08A3A", "7A6A62", "9A4A34")                                       # Kern: gepresste Schrottballen
    for row, (n, z, w, d, h) in enumerate(((5, 0.0, 1.5, 1.7, 1.15), (4, 1.15, 1.45, 1.5, 1.0))):
        for i in range(n):
            x = (i - (n - 1) * 0.5) * (w + 0.02) + rng.uniform(-0.05, 0.05)
            c = bale[(i + row * 2) % 5]
            B.box((w, d, h), (x, 0.15, z + h * 0.5), c, r=rot(0, 0, rng.uniform(-4, 4)), bevel=0.07, segs=1)
            B.box((w + 0.03, d + 0.03, 0.08), (x, 0.15, z + h * 0.5), shade(c, 0.6))
    cols = ("E2B648", "5FA3A0", "C0503A", "7C8FB0", "E28A3A")
    for i, (x, y, yaw) in enumerate(((-2.55, -0.7, 4), (0.0, -0.78, -5), (2.55, -0.68, 6))):        # untere Reihe vorn
        car_hull(B, T(x, y, 0.1) @ rot(4 * (i - 1), 0, yaw), cols[i], 2.55)
    car_hull(B, T(-1.5, 0.1, 2.05) @ rot(0, 6, -6), cols[4], 2.5)                                    # obenauf
    car_hull(B, T(1.6, 0.2, 1.98) @ rot(180, -5, 8) @ T(0, 0, -1.3), cols[3], 2.4)                    # eins auf dem Dach
    # Wellblech, Träger, Fässer, Reifen
    for (x, y, z, w, h, ry, rz, c) in ((-3.78, 0.2, 1.1, 1.5, 2.2, 0, 88, RUST), (3.78, 0.2, 1.2, 1.5, 2.3, 0, 92, RUST_L), (0.2, 1.12, 1.2, 1.8, 2.3, 0, 182, RUST_D),
                                       (-2.2, 1.12, 1.05, 1.6, 2.0, 0, 178, RUST_L), (2.4, 1.12, 1.0, 1.5, 1.9, 0, 183, RUST)):
        m = T(x, y, z) @ rot(0, ry, rz) @ rot(-7, 0, 0)
        B.box((w, 0.07, h), (0, 0, 0), c, r=m, bevel=0.02, segs=1)
        for q in range(3):
            B.box((w / 6, 0.11, h * 0.96), (0, 0, 0), shade(c, 0.8), r=m @ T(-w * 0.5 + (q + 0.5) * w / 3, 0, 0))
    beam(B, (-3.4, 0.5, 1.4), (-2.6, 0.6, 3.1), 0.16, "8A94A8")
    beam(B, (3.5, 0.6, 1.2), (2.9, 0.5, 3.1), 0.14, RUST_D)
    B.box((0.9, 0.06, 0.6), (0.1, -0.78, 1.75), YEL, r=rot(-8, -12, 5), bevel=0.03, segs=1)           # Schild
    B.box((0.5, 0.07, 0.12), (0.1, -0.8, 1.75), "23262E", r=rot(-8, -12, 5))
    for (x, y, z, rx) in ((-1.3, -1.42, 0.42, 78), (1.3, -1.25, 0.14, 0), (1.32, -1.25, 0.42, 4), (0.1, 0.1, 2.3, 10)):
        tire(B, T(x, y, z) @ rot(rx, 0, 15), 0.42, 0.3, lp=True)
    for i in range(2):
        rockc(B, (0.5, 0.4, 0.3), (rng.uniform(-3.6, 3.6), rng.choice((-1.5, 1.4)), 0.15), (RUST, RUST_D, STEEL, "7E8798")[i % 4], rng, 0.1)
    _fin(name, root, B)


# ------------------------------------------------------------------ Schrottküste: Containerwand
def container(p, m, ln, d, h, color):
    dk = shade(color, 0.72)
    p.box((ln, d, h), (0, 0, 0), color, r=m @ T(0, 0, h * 0.5), bevel=0.05, segs=1)
    n = int(ln / 0.56)
    for s in (-1, 1):
        for i in range(n):
            p.box((ln / n * 0.42, 0.05, h * 0.84), (0, 0, 0), dk, r=m @ T(-ln * 0.5 + (i + 0.5) * ln / n, s * d * 0.5, h * 0.5))
        p.box((ln + 0.04, d + 0.04, 0.12), (0, 0, 0), dk, r=m @ T(0, 0, 0.07 if s < 0 else h - 0.08))
        # Türen an einem Ende
        p.box((0.05, d * 0.42, h * 0.8), (0, 0, 0), shade(color, 1.12), r=m @ T(ln * 0.5 + 0.01, s * d * 0.23, h * 0.5))
        p.cyl(0.025, h * 0.8, (0, 0, 0), "C9D0DE", r=m @ T(ln * 0.5 + 0.05, s * d * 0.1, h * 0.5), sides=4)


@model("x_barrier_kueste")
def b_kueste(name):
    root, B, G = start(name)
    rng = random.Random(2)
    container(B, T(-2.0, 0.05, 0) @ rot(0, 0, 1.5), 3.9, 2.1, 1.95, "D8483F")
    container(B, T(2.0, -0.05, 0) @ rot(0, 0, 181), 3.9, 2.1, 1.95, "3B7FD0")
    container(B, T(-1.25, 0.1, 1.95) @ rot(0, 0, -4), 4.3, 2.0, 1.45, "2FA79A")
    container(B, T(2.72, 0.0, 1.95) @ rot(0, 0, 93), 2.1, 2.2, 1.45, "F2A024")
    star(B, (-2.0, -1.06, 1.0), 0.4, "FFFFFF", 0.05)
    B.box((1.0, 0.05, 0.2), (2.0, -1.13, 1.3), "FFFFFF")
    B.box((0.7, 0.05, 0.2), (1.85, -1.13, 0.95), "FFFFFF")
    B.box((0.6, 0.04, 0.5), (-0.6, -0.9, 2.6), RUST, r=rot(0, 0, -4))          # Rostflecken
    B.box((0.5, 0.04, 0.4), (-3.2, -1.05, 0.5), RUST_D)
    B.box((0.7, 0.04, 0.3), (3.0, -1.12, 0.4), RUST)
    # Kleinkram davor und dahinter: Paletten, Kisten, Reifen, Poller mit Tau
    for (x, y) in ((-3.3, -1.3), (-2.5, 1.3), (1.2, 1.3)):
        for k in range(2):
            B.box((1.0, 0.5, 0.07), (x, y, 0.05 + k * 0.14), WOOD_L)
        for dx in (-0.4, 0, 0.4):
            B.box((0.1, 0.5, 0.07), (x + dx, y, 0.12), WOOD_D)
    crate(B, (-3.3, -1.3, 0.22), 0.45, WOOD, 4)
    crate(B, (1.3, 1.3, 0.22), 0.45, "C98A48", -4)
    for (x, y, z) in ((0.2, -1.25, 0.3), (0.5, -1.25, 0.3), (3.3, 1.25, 0.3)):
        tire(B, T(x, y, z) @ rot(80, 0, 0), 0.3, 0.2, lp=True)
    B.cyl(0.14, 0.8, (2.9, -1.3, 0.4), "3A3E4A", sides=8, bevel=0.05, segs=1)
    B.cyl(0.2, 0.12, (2.9, -1.3, 0.78), "3A3E4A", sides=8)
    B.torus(0.2, 0.06, (2.9, -1.3, 0.3), "D9C08A", seg=10, tseg=4)
    B.torus(0.19, 0.06, (2.9, -1.3, 0.43), "CDB07A", seg=10, tseg=4)
    barrel(B, (-0.9, -1.28, 0.0), "F2A024", 0.24, 0.8)
    _fin(name, root, B)


# ------------------------------------------------------------------ Sumpfwerk: Giftnebel-Rohre
@model("x_barrier_sumpf")
def b_sumpf(name):
    root, B, G = start(name)
    pg, pd = "4FA36A", "357A50"
    O = Part()
    B.box((8.0, 1.5, 1.5), (0, 0.1, 0.75), CONC, bevel=0.08, segs=1)                                # Betonsockel
    B.box((8.04, 1.6, 0.3), (0, 0.1, 0.15), CONC_D, bevel=0.04, segs=1)
    for i in range(5):
        x = -3.6 + i * 1.8
        B.box((0.5, 2.1, 1.2), (x, 0.05, 0.6), CONC_D, bevel=0.07, segs=1)                           # Stützen
        B.box((0.56, 1.3, 0.5), (x, 0.1, 1.7), "6E7890", bevel=0.06, segs=1)                        # Rohrsattel
    for i in range(8):
        B.box((0.5, 0.03, 0.12), (-3.5 + i * 1.0, -0.66, 1.3), YEL if i % 2 == 0 else "23262E")
    # Hauptrohr oben, zwei Rohre davor und dahinter
    B.cyl(0.72, 8.0, (0, 0.1, 2.35), pg, r=rot(0, 90, 0), sides=12)
    for x in (-4.0, -2.0, 0.0, 2.0, 4.0):
        B.cyl(0.84, 0.16, (x * 0.985, 0.1, 2.35), "6E7890", r=rot(0, 90, 0), sides=12)
    B.cyl(0.42, 8.0, (0, -1.05, 0.72), pd, r=rot(0, 90, 0), sides=10)
    B.cyl(0.42, 8.0, (0, 1.05, 0.9), pd, r=rot(0, 90, 0), sides=10)
    for x in (-3.0, -1.0, 1.0, 3.0):
        B.cyl(0.5, 0.12, (x, -1.05, 0.72), STEEL, r=rot(0, 90, 0), sides=10)
        B.cyl(0.5, 0.12, (x, 1.05, 0.9), STEEL, r=rot(0, 90, 0), sides=10)
        B.box((0.3, 0.5, 0.36), (x + 0.5, -1.05, 0.18), CONC_D, bevel=0.04, segs=1)
    # Abluftstutzen mit grünem Dampf
    for i, x in enumerate((-3.0, -1.0, 1.0, 3.0)):
        h = 0.32 + 0.13 * (i % 2)
        B.cyl(0.26, h, (x, 0.1, 3.0 + h * 0.5), "6E7890", sides=8)
        B.cyl(0.34, 0.14, (x, 0.1, 3.0 + h), "3A3E4A", sides=8)
        O.cyl(0.2, 0.05, (x, 0.1, 3.0 + h + 0.06), "9CFF6A", sides=8)
        empty("fx_steam%d" % (i + 1), root, (x, 0.1, 3.25 + h))
    # Ventile, Warnschild
    for x in (-2.0, 2.0):
        B.cyl(0.05, 0.5, (x, -1.05, 1.3), "3A3E4A", sides=5)
        B.torus(0.28, 0.05, (x, -1.05, 1.56), RED, seg=10, tseg=4)
        B.box((0.56, 0.05, 0.05), (x, -1.05, 1.56), RED)
        B.box((0.05, 0.56, 0.05), (x, -1.05, 1.56), RED)
    B.cyl(0.5, 0.06, (0, -0.68, 2.3), YEL, r=rot(90, 0, 0) @ rot(0, 0, 0), sides=3)
    B.box((0.08, 0.05, 0.3), (0, -0.73, 2.34), "23262E")
    B.box((0.08, 0.05, 0.08), (0, -0.73, 2.12), "23262E")
    # Giftschleim: Lecks und Pfützen (leuchten)
    for (x, y, s) in ((-2.6, -1.42, 0.45), (0.6, -1.45, 0.5), (3.2, -1.4, 0.4), (-1.0, 1.42, 0.45), (2.2, 1.45, 0.4)):
        O.cyl(1.0, 0.03, (x, y, 0.02), "7CFF5A", r=S(s, s * 0.6, 1), sides=9)
    for (x, z0) in ((-2.6, 0.5), (0.6, 0.5), (3.2, 0.5)):
        O.cyl(0.07, z0, (x, -1.42, z0 * 0.5), "7CFF5A", r2=0.04, sides=5)
        O.ball(0.12, (x, -1.4, z0), "9CFF6A", subdiv=1)
    for (x, z) in ((-1.5, 2.2), (2.6, 2.1)):
        O.ball(1.0, (x, -0.58, z), "9CFF6A", scale=(0.2, 0.08, 0.34), subdiv=2)
    B.build("body", root)
    O.build("ooze_glow", root)
    fin(name, yaw=-28, pitch=22)


# ------------------------------------------------------------------ Frostpass: Eisbarriere
@model("x_barrier_frost")
def b_frost(name):
    root, B, G = start(name)
    rng = random.Random(21)
    ice = (ICE, ICE_D, "A9E2FA", "74BDEA")
    B.box((7.5, 1.5, 1.9), (0, 0, 0.95), ICE_D, bevel=0.2, segs=1)                                  # Kern
    for i in range(7):                                                                              # Eisblöcke
        x = -3.2 + i * 1.07
        for s in (-1, 1):
            w, d, h = rng.uniform(1.1, 1.4), rng.uniform(0.9, 1.2), rng.uniform(1.5, 2.3)
            B.box((w, d, h), (x + rng.uniform(-0.1, 0.1), s * 0.5, h * 0.5 - 0.1), ice[(i + (s > 0)) % 4],
                  r=rot(rng.uniform(-6, 6), rng.uniform(-7, 7), rng.uniform(-20, 20)), bevel=0.14, segs=1)
    for i in range(9):                                                                              # Eiszacken
        x = -3.3 + i * 0.825 + rng.uniform(-0.12, 0.12)
        h = rng.uniform(2.1, 2.6) if i % 2 == 0 else rng.uniform(1.5, 2.0)
        r = rng.uniform(0.5, 0.75)
        m = T(x, rng.uniform(-0.3, 0.3), 0.6) @ rot(rng.uniform(-8, 8), rng.uniform(-9, 9), rng.uniform(0, 60))
        B.cyl(r, h, (0, 0, 0), ice[i % 4], r=m @ T(0, 0, h * 0.5), r2=0.03, sides=5)
        B.cyl(r * 0.5, h * 0.5, (0, 0, 0), ICE_L, r=m @ T(r * 0.18, -r * 0.18, h * 0.5), r2=0.02, sides=4)
    for i in range(8):                                                                              # kleine Zacken am Fuß
        s = -1 if i % 2 == 0 else 1
        x = -3.3 + i * 0.94
        h = rng.uniform(0.9, 1.4)
        B.cyl(0.3, h, (0, 0, 0), ice[(i + 2) % 4], r=T(x, s * 1.12, 0) @ rot(s * rng.uniform(4, 14), rng.uniform(-8, 8), 0) @ T(0, 0, h * 0.5), r2=0.02, sides=5)
    for i in range(6):                                                                              # Schneewehen
        s = -1 if i % 2 == 0 else 1
        B.ball(1.0, (-2.9 + i * 1.16, s * 1.15, 0.05), SNOW, scale=(rng.uniform(0.8, 1.0), 0.4, 0.36), subdiv=2)
    for i in range(4):
        B.ball(1.0, (-2.8 + i * 1.9 + rng.uniform(-0.2, 0.2), 0, 1.95), SNOW, scale=(0.8, 0.7, 0.22), subdiv=2)
    _fin(name, root, B)


# ------------------------------------------------------------------ Schleimkrater: Schleimwand
@model("x_barrier_krater")
def b_krater(name):
    root, B, G = start(name)
    rng = random.Random(17)
    sl = (SLIME, "7AB534", "9CCF3E", SLIME_D)
    B.box((7.2, 1.5, 1.8), (0, 0, 0.9), SLIME_D, bevel=0.4, segs=1)                                 # Kern
    spots = []
    for i in range(6):                                                                              # große Blasen
        x = -2.85 + i * 1.14
        r = rng.uniform(1.05, 1.2)
        z = rng.uniform(0.95, 1.3) + (0.35 if i % 2 else 0)
        B.ball(r, (x, rng.uniform(-0.15, 0.15), z), sl[i % 3], scale=(1.0, 0.95, 1.0 + 0.22 * (i % 2)), subdiv=3 if i == 3 else 2)
        spots.append((x, z, r))
    for i in range(6):                                                                              # Wülste am Fuß
        s = -1 if i % 2 == 0 else 1
        B.ball(1.0, (-3.1 + i * 1.24, s * rng.uniform(0.9, 1.0), 0.25), sl[(i + 1) % 4], scale=(0.7, 0.5, 0.5), subdiv=2)
    for i, (x, z, r) in enumerate(spots):                                                           # Glanzlichter und Tropfen
        B.ball(1.0, (x - r * 0.35, -r * 0.72, z + r * 0.5), SLIME_L, scale=(0.3, 0.12, 0.2), subdiv=1)
        B.cyl(0.1, 0.7, (x + r * 0.3, -r * 0.8, z - r * 0.55), sl[2], r2=0.05, sides=5)
        B.ball(0.14, (x + r * 0.3, -r * 0.8, z - r * 0.9), sl[2], subdiv=1)
    # eingeschlossener Schrott: Reifen, Fass, Knochen
    tire(B, T(-2.0, -1.05, 0.9) @ rot(70, 20, 0), 0.42, 0.28, lp=True)
    B.cyl(0.3, 0.8, (1.9, -1.0, 0.7), "C0503A", r=rot(60, 30, 0), sides=8, bevel=0.05, segs=1)
    limb(B, (0.2, -1.15, 1.5), (0.8, -1.2, 1.9), 0.06, 0.06, "F1E3C4", 5)
    B.ball(0.1, (0.2, -1.15, 1.5), "F1E3C4", subdiv=1)
    B.ball(0.1, (0.8, -1.2, 1.9), "F1E3C4", subdiv=1)
    for (x, y, s) in ((-3.0, -1.3, 0.5), (0.4, -1.35, 0.6), (3.0, -1.3, 0.45), (-1.2, 1.3, 0.5), (2.0, 1.3, 0.45)):
        B.cyl(1.0, 0.04, (x, y, 0.02), sl[2], r=S(s, s * 0.6, 1), sides=9)
    B.build("body", root)
    for i, (x, y, z, r) in enumerate(((-2.5, -0.7, 2.45, 0.32), (0.5, -0.8, 2.75, 0.4), (2.6, -0.65, 2.5, 0.3))):
        p = Part()
        p.ball(r, (0, 0, 0), SLIME_L, subdiv=2)
        p.ball(r * 0.3, (-r * 0.4, -r * 0.6, r * 0.45), "F2FFC0", subdiv=1)
        p.build("pulse_bubble%d" % (i + 1), root, (x, y, z))
    fin(name, yaw=-28, pitch=22)
