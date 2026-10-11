"""Ausrüstung: Helme, Westen, Glücksbringer in je vier Seltenheiten (gear_<helmet|vest|charm>_<0..3>).
Je ein Objekt `body`, etwa 0,5 m groß, Vorderseite -Y, Ursprung am Boden.
Aufruf: python3 blender/gear.py [gear_helmet_0 ...]   (ohne Namen: alle)"""
import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from kit import *
from weapons import (prism, star, lathe, sweep, arc, toon, tris, sparkle, merge, Y, hole, ring, args,
                     BLUE, BLUE_L, BLUE_D, NAVY, YEL, YEL_L, ORG, RED, RED_D, GRN, GRN_D, PINK, PINK_D, VIO, VIO_D,
                     WHITE, GREY, GREY_L, DGREY, HOLE, CYAN, TAN, WOOD, TEAL)

LEATHER, LEATHER_D, CREAM, GOLD_D = "B8703C", "8A4E28", "F6E8CC", "FFAE1F"


def gfinish(name, p, yaw=-28.0, pitch=16.0, render=True):
    toon(p)
    n = tris(p)
    reset()
    root = empty(name)
    p.build("body", root)
    save(name)
    if render:
        icon(name, 256, yaw=yaw, pitch=pitch, margin=1.08)
    return n


def dome(p, R, H, z0, color, n=5, sides=16, sy=1.0, loc=(0, 0, 0)):
    prof = [(R * math.cos(math.radians(90.0 * i / n)), z0 + H * math.sin(math.radians(90.0 * i / n))) for i in range(n + 1)]
    lathe(p, prof, loc, color, r=Matrix.Diagonal(Vector((1, sy, 1, 1))), sides=sides)


def over(R, H, z0, a0=0.0, a1=180.0, n=10, sy=1.0, x=0.0):
    """Punkte eines Bogens über die Kuppel von vorn (-Y) nach hinten."""
    return [(x, -R * sy * math.cos(math.radians(a0 + (a1 - a0) * i / n)), z0 + H * math.sin(math.radians(a0 + (a1 - a0) * i / n))) for i in range(n + 1)]


# ------------------------------------------------------------------ Helme
def helmet_0(p):
    """Blechtopf: umgedrehter Kochtopf mit zwei Henkeln."""
    lathe(p, [(0.26, 0.0), (0.26, 0.05), (0.235, 0.06), (0.235, 0.3), (0.2, 0.35), (0.0, 0.36)], (0, 0, 0),
          [GREY, GREY, GREY_L, GREY_L, GREY_L, GREY], sides=18)
    p.torus(0.255, 0.03, (0, 0, 0.03), GREY, seg=18, tseg=6)
    for sx in (-1, 1):
        p.torus(0.075, 0.026, (sx * 0.26, 0, 0.2), DGREY, seg=12, tseg=6)
    p.cyl(0.05, 0.03, (0, 0, 0.365), DGREY, sides=10)
    p.box((0.13, 0.03, 0.035), (0.03, -0.235, 0.19), TAN, r=rot(0, 35, 0), bevel=0.01, segs=1)     # Pflaster
    p.box((0.13, 0.03, 0.035), (0.03, -0.235, 0.19), TAN, r=rot(0, -35, 0), bevel=0.01, segs=1)
    p.ball(1.0, (-0.1, -0.2, 0.2), WHITE, scale=(0.02, 0.012, 0.09), subdiv=1)                      # Glanz
    for a in (-60, -20, 20, 60):
        p.ball(0.016, (0.24 * math.sin(math.radians(a)), -0.24 * math.cos(math.radians(a)), 0.09), DGREY, subdiv=1)


def helmet_1(p):
    """Bauhelm: gelber Schutzhelm mit Stirnlampe."""
    R, H, z0, sy = 0.24, 0.25, 0.07, 1.1
    dome(p, R, H, z0, YEL, sy=sy)
    lathe(p, [(0.0, 0.05), (0.3, 0.05), (0.31, 0.075), (0.24, 0.1)], (0, -0.035, 0), "F7B21E", r=Matrix.Diagonal(Vector((1, 1.16, 1, 1))), sides=18)
    lathe(p, [(0.0, 0.0), (0.22, 0.0), (0.24, 0.07)], (0, 0, 0), ["3A4460", "3A4460"], r=Matrix.Diagonal(Vector((1, sy, 1, 1))), sides=14)
    sweep(p, over(R, H, z0, 12, 172, sy=sy), 0.04, YEL_L, sides=6)                                   # Mittelrippe
    for sx in (-1, 1):
        sweep(p, over(R * 0.9, H * 0.9, z0, 25, 160, sy=sy, x=sx * 0.11), 0.028, "F7B21E", sides=6)
    Y(p, 0.07, -0.2, -0.3, 0.2, DGREY, bevel=0.015, sides=12, segs=1)                                # Lampe
    hole(p, 0.052, -0.3, 0.2, "FFF6C8")
    p.torus(0.245, 0.02, (0, 0, 0.115), ORG, r=Matrix.Diagonal(Vector((1, sy, 1, 1))), seg=18, tseg=5)


def helmet_2(p):
    """Fliegerkappe: Lederkappe mit Ohrenklappen und Fliegerbrille."""
    R, H, z0 = 0.24, 0.25, 0.16
    dome(p, R, H, z0, LEATHER)
    lathe(p, [(0.0, z0 - 0.02), (0.22, z0 - 0.02), (0.24, z0)], (0, 0, 0), "3A2A22", sides=14)
    p.torus(0.235, 0.042, (0, 0, z0 + 0.01), CREAM, seg=18, tseg=6)                                  # Fellrand
    for sx in (-1, 1):
        p.box((0.08, 0.2, 0.26), (sx * 0.225, 0.02, 0.09), LEATHER, bevel=0.035)                    # Ohrenklappen
        p.box((0.09, 0.08, 0.05), (sx * 0.23, 0.02, 0.03), YEL, bevel=0.015, segs=1)
        Y(p, 0.092, -0.17, -0.265, 0.3, "E0A82E", bevel=0.02, sides=12, x=sx * 0.1, segs=1)        # Brille
        hole(p, 0.066, -0.265, 0.3, CYAN, x=sx * 0.1)
        p.ball(0.022, (sx * 0.08, -0.275, 0.325), WHITE, subdiv=1)
    p.torus(0.218, 0.026, (0, 0, 0.3), NAVY, seg=18, tseg=5)                                        # Brillenband
    sweep(p, over(R, H, z0, 35, 170), 0.022, LEATHER_D, sides=5)                                    # Naht
    p.ball(0.035, (0, 0, z0 + H), LEATHER_D, subdiv=1)


def helmet_3(p):
    """Sturmhaube: gepanzerter Helm mit Visierschlitz, Goldkamm und Federbusch."""
    R, H, z0, sy = 0.25, 0.26, 0.15, 1.06
    c = "5A6FE8"
    dome(p, R, H, z0, c, sy=sy, sides=18)
    lathe(p, [(0.0, 0.0), (0.24, 0.0), (0.275, 0.02), (0.25, z0)], (0, 0, 0), ["2A3260", "2A3260", c], r=Matrix.Diagonal(Vector((1, sy, 1, 1))), sides=18)
    p.torus(0.272, 0.028, (0, 0, 0.025), YEL, r=Matrix.Diagonal(Vector((1, sy, 1, 1))), seg=18, tseg=6)
    p.box((0.3, 0.1, 0.075), (0, -0.225, 0.2), HOLE, bevel=0.02, segs=1)                             # Sehschlitz
    p.box((0.07, 0.1, 0.17), (0, -0.235, 0.105), HOLE, bevel=0.02, segs=1)
    p.box((0.36, 0.09, 0.04), (0, -0.235, 0.255), YEL, bevel=0.015, segs=1)                          # Stirnband
    for sx in (-1, 1):
        p.box((0.035, 0.09, 0.2), (sx * 0.055, -0.245, 0.1), YEL, bevel=0.012, segs=1)
        p.ball(0.03, (sx * 0.2, -0.17, 0.1), YEL, subdiv=1)
    sweep(p, over(R, H, z0, 22, 175, sy=sy), 0.032, YEL, sides=6)                                    # Kamm
    fin = [(0.26 * math.cos(math.radians(a)), 0.12 * math.sin(math.radians(a))) for a in range(0, 181, 20)]
    prism(p, fin, 0.05, (0, 0.03, z0 + H - 0.02), RED, r=rot(0, 0, 90), bevel=0.012, segs=1)        # Federbusch
    star(p, 0.06, 0.04, (0, -0.24, 0.31), YEL_L, r=rot(-25, 0, 0))


# ------------------------------------------------------------------ Westen
VEST = [(-0.23, 0.0), (0.23, 0.0), (0.235, 0.27), (0.19, 0.33), (0.185, 0.4), (0.215, 0.5), (0.11, 0.5), (0.075, 0.4), (0.0, 0.345),
        (-0.075, 0.4), (-0.11, 0.5), (-0.215, 0.5), (-0.185, 0.4), (-0.19, 0.33), (-0.235, 0.27)]


def vest_base(p, c, c2="2A3260", w=0.46, d=0.25):
    """Westenform als dickes, gerundetes Profil; dunkles Futter hinter dem Halsausschnitt."""
    prism(p, VEST, d, (0, 0, 0), c, bevel=0.06, segs=3)
    prism(p, [(-0.2, 0.05), (0.2, 0.05), (0.19, 0.47), (-0.19, 0.47)], d * 0.5, (0, d * 0.2, 0), c2)


def vest_0(p):
    """Flickenweste: braune Weste mit bunten Flicken."""
    d = 0.25
    vest_base(p, LEATHER, "4A2E1E")
    p.box((0.022, 0.02, 0.3), (0, -d / 2 - 0.002, 0.16), LEATHER_D)
    for (x, z, sx_, sz, cc, a) in ((-0.11, 0.13, 0.13, 0.12, RED, 12), (0.11, 0.22, 0.11, 0.1, BLUE_L, -9), (0.11, 0.08, 0.1, 0.08, YEL, 6),
                                   (-0.15, 0.4, 0.08, 0.08, GRN, -8)):
        m = rot(0, a, 0)
        p.box((sx_, 0.024, sz), (x, -d / 2 + 0.002, z), cc, r=m)
        for i in (-1, 1):                                                                             # Nähte
            for j in (-1, 1):
                q = m @ Vector((i * (sx_ * 0.5 - 0.012), -0.02, j * (sz * 0.5 - 0.012)))
                p.box((0.034, 0.012, 0.014), (x + q.x, -d / 2 + 0.004 + q.y * 0.6, z + q.z), WHITE, r=rot(0, a + 45 * i * j, 0))
    for z in (0.26, 0.17):
        p.ball(0.022, (-0.04, -d / 2 - 0.005, z), TAN, subdiv=1)
    sweep(p, [(-0.24, 0, 0.03), (-0.17, -0.13, 0.03), (0.0, -0.14, 0.035), (0.17, -0.13, 0.03), (0.24, 0, 0.03)], 0.018, TAN, sides=5, ref=(0, 0, 1))  # Strick


def vest_1(p):
    """Taschenweste: grüne Weste mit vielen Taschen."""
    d = 0.25
    c, cd, cl = "8FB93A", "6C9324", "B4D95A"
    vest_base(p, c, "33421C")
    p.box((0.024, 0.02, 0.32), (0, -d / 2 - 0.003, 0.17), GREY_L)                                    # Reißverschluss
    for sx in (-1, 1):
        p.box((0.16, 0.06, 0.14), (sx * 0.115, -d / 2, 0.1), cd, bevel=0.025, segs=1)               # große Taschen
        p.box((0.175, 0.07, 0.05), (sx * 0.115, -d / 2, 0.165), cl, bevel=0.015, segs=1)
        p.ball(0.02, (sx * 0.115, -d / 2 - 0.035, 0.155), YEL, subdiv=1)
        p.box((0.115, 0.05, 0.09), (sx * 0.145, -d / 2 + 0.008, 0.3), cd, bevel=0.02, segs=1)       # Brusttaschen
        p.box((0.125, 0.06, 0.035), (sx * 0.145, -d / 2 + 0.008, 0.345), cl, bevel=0.012, segs=1)
        p.ball(0.016, (sx * 0.145, -d / 2 - 0.022, 0.335), YEL, subdiv=1)
    p.box((0.47, 0.26, 0.045), (0, 0, 0.03), "5A4630", bevel=0.012, segs=1)                          # Gürtel
    p.box((0.07, 0.03, 0.06), (0, -d / 2 - 0.005, 0.03), YEL, bevel=0.012, segs=1)


def vest_2(p):
    """Polsterjacke: dick gesteppte blaue Jacke."""
    for i in range(4):
        p.box((0.48 - (0.04 if i == 3 else 0.0), 0.29, 0.128), (0, 0, 0.062 + i * 0.105), BLUE if i % 2 == 0 else "4FA0FF", bevel=0.058, segs=3)
    for sx in (-1, 1):
        p.ball(0.125, (sx * 0.27, 0, 0.345), BLUE, scale=(1.15, 1.0, 0.95), subdiv=2)               # Puffärmel
        p.torus(0.085, 0.032, (sx * 0.37, 0, 0.32), ORG, r=rot(0, 90 + sx * 12, 0), seg=12, tseg=5)
    p.torus(0.1, 0.048, (0, 0, 0.455), ORG, seg=14, tseg=6)                                          # Kragen
    p.cyl(0.085, 0.03, (0, 0, 0.44), "2A3260", sides=12)
    p.box((0.035, 0.02, 0.4), (0, -0.147, 0.22), YEL, bevel=0.008, segs=1)                           # Reißverschluss
    p.box((0.05, 0.03, 0.06), (0, -0.155, 0.39), YEL_L, bevel=0.012, segs=1)


def vest_3(p):
    """Panzerweste: schwere Plattenweste mit Gold."""
    d = 0.25
    c = "4A5AB8"
    vest_base(p, c, "20264A")
    p.box((0.38, 0.07, 0.19), (0, -d / 2, 0.245), VIO, bevel=0.03)                                   # Brustplatte
    p.box((0.4, 0.075, 0.03), (0, -d / 2, 0.345), YEL, bevel=0.01, segs=1)
    p.box((0.4, 0.075, 0.03), (0, -d / 2, 0.15), YEL, bevel=0.01, segs=1)
    star(p, 0.07, 0.04, (0, -d / 2 - 0.04, 0.245), YEL, color2=GOLD_D)
    for i, z in enumerate((0.1, 0.045)):
        p.box((0.34 - i * 0.04, 0.06, 0.05), (0, -d / 2, z), "7A8CF0", bevel=0.015, segs=1)          # Bauchplatten
    for sx in (-1, 1):
        p.ball(0.1, (sx * 0.19, 0, 0.49), VIO, scale=(1.2, 1.3, 0.6), subdiv=2)                     # Schulterstücke
        p.torus(0.1, 0.02, (sx * 0.19, 0, 0.475), YEL, r=Matrix.Diagonal(Vector((1.2, 1.3, 1, 1))), seg=14, tseg=5)
        p.ball(0.028, (sx * 0.19, 0, 0.55), YEL, subdiv=1)
    p.box((0.475, 0.265, 0.05), (0, 0, 0.0 + 0.025), "2A3260", bevel=0.012, segs=1)


# ------------------------------------------------------------------ Glücksbringer
def charm_0(p):
    """Glücksmünze."""
    z = 0.26
    Y(p, 0.25, 0.04, -0.04, z, YEL, bevel=0.02, sides=24)
    Y(p, 0.195, 0.048, -0.048, z, GOLD_D, sides=24)
    for sy in (-1, 1):
        star(p, 0.15, 0.05, (0, sy * 0.05, z), YEL_L, color2=YEL)
    p.ball(1.0, (-0.14, -0.045, z + 0.15), WHITE, scale=(0.05, 0.012, 0.022), r=rot(0, -40, 0), subdiv=1)
    star(p, 0.06, 0.04, (0.2, -0.06, z + 0.2), WHITE, n=4, inner=0.36)


def charm_1(p):
    """Hasenpfote mit Messingkappe und Ring."""
    p.ball(0.14, (0, 0, 0.21), CREAM, scale=(0.9, 0.8, 1.45), subdiv=3)
    for x, zz in ((-0.075, 0.05), (0.0, 0.025), (0.075, 0.05)):
        p.ball(0.06, (x, -0.035, zz), WHITE, scale=(1, 1, 1.2), subdiv=2)
        p.ball(0.03, (x, -0.085, zz + 0.005), PINK, scale=(1, 0.5, 1.1), subdiv=1)
    p.cyl(0.095, 0.1, (0, 0, 0.4), YEL, sides=14, bevel=0.02)
    p.torus(0.096, 0.016, (0, 0, 0.37), GOLD_D, seg=14, tseg=4)
    p.torus(0.055, 0.02, (0, 0, 0.49), GREY_L, r=rot(90, 0, 0), seg=12, tseg=5)
    p.torus(0.045, 0.016, (0.0, 0, 0.57), GREY_L, r=rot(90, 0, 90), seg=10, tseg=5)


def heart_pts(n=22, s=1.0):
    """Herzumriss, Spitze unten bei (0, -0.5*s), Breite etwa s."""
    out = []
    for i in range(n):
        t = 2 * math.pi * i / n
        out.append((16 * math.sin(t) ** 3 / 33.0 * s, (13 * math.cos(t) - 5 * math.cos(2 * t) - 2 * math.cos(3 * t) - math.cos(4 * t) + 2.5) / 33.0 * s))
    return out


def clover(p, c=(0, 0, 0.33), s=1.0):
    """Vierblättriges Kleeblatt in der X-Z-Ebene: vier Herzblätter, Spitzen zur Mitte."""
    cx, cy, cz = c
    leaf = [(x, z + 0.5 * 0.3 * s - 0.03 * s) for x, z in heart_pts(18, 0.3 * s) if z > -0.5 * 0.3 * s + 0.07 * s]   # stumpfe Spitze
    p.ball(0.075 * s, (cx, cy, cz), "36B552", scale=(1, 0.62, 1), subdiv=2)
    for k in range(4):
        prism(p, leaf, 0.11 * s, (cx, cy, cz), GRN if k % 2 == 0 else "36B552", r=rot(0, 45 + 90 * k, 0), bevel=0.028 * s, segs=2)
        a = math.radians(45 + 90 * k)
        p.ball(1.0, (cx + math.sin(a) * 0.2 * s - 0.05 * s, cy - 0.055 * s, cz + math.cos(a) * 0.2 * s + 0.04 * s), "A6F29A", scale=(0.035 * s, 0.01 * s, 0.022 * s), subdiv=1)
    sweep(p, [(cx - 0.0 * s, cy + 0.01 * s, cz - 0.02 * s), (cx + 0.03 * s, cy + 0.01 * s, cz - 0.2 * s), (cx + 0.1 * s, cy + 0.01 * s, cz - 0.33 * s)], [0.03 * s, 0.03 * s, 0.026 * s], GRN_D, sides=6, ref=(0, 1, 0))


def charm_2(p):
    """Vierblatt."""
    clover(p)


def charm_3(p):
    """Sternanhänger: Goldstern mit Edelstein an einem Band."""
    z = 0.22
    star(p, 0.22, 0.14, (0, 0, z), YEL, color2=GOLD_D)
    p.ball(0.065, (0, -0.045, z), CYAN, scale=(1, 0.6, 1), subdiv=2)
    p.ball(0.02, (-0.02, -0.085, z + 0.025), WHITE, subdiv=1)
    p.torus(0.04, 0.016, (0, 0, z + 0.235), GREY_L, r=rot(90, 0, 0), seg=10, tseg=5)
    sweep(p, [(0.0, 0, z + 0.25)] + arc(0, z + 0.36, 0.1, -60, 240, 10)[1:-1] + [(0.0, 0, z + 0.25)], 0.02, VIO, sides=5, ref=(0, 1, 0))   # Band
    star(p, 0.05, 0.035, (0.2, -0.03, z + 0.2), WHITE, n=4, inner=0.36)
    star(p, 0.035, 0.025, (-0.21, -0.03, z - 0.12), YEL_L, n=4, inner=0.36)


ALL = dict(gear_helmet_0=helmet_0, gear_helmet_1=helmet_1, gear_helmet_2=helmet_2, gear_helmet_3=helmet_3,
           gear_vest_0=vest_0, gear_vest_1=vest_1, gear_vest_2=vest_2, gear_vest_3=vest_3,
           gear_charm_0=charm_0, gear_charm_1=charm_1, gear_charm_2=charm_2, gear_charm_3=charm_3)

if __name__ == "__main__":
    for n in (args() or list(ALL)):
        p = Part()
        ALL[n](p)
        t = gfinish(n, p, yaw=-24 if "charm" in n else -30, pitch=10 if "charm" in n else 18)
        print("ok %s  %d Dreiecke" % (n, t))
