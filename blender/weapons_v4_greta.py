"""V4 Waffen-Arsenal – Oma Greta (Feuerwerk und Party): Rosa, Bonbonfarben, Sterne, Blümchen.
Aufruf: python3 blender/weapons_v4_greta.py [g_popper ...]"""
import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from weapons_v4_kit import *

PARTY = [PINK, YEL, CYAN, GRN, ORG, VIO]


def confetti(p, c, n=8, spread=0.12, seed=3):
    rng = random.Random(seed)
    for i in range(n):
        x = c[0] + rng.uniform(-spread, spread)
        y = c[1] + rng.uniform(-spread, spread)
        z = c[2] + rng.uniform(-spread, spread)
        p.box((0.03, 0.012, 0.03), (x, y, z), PARTY[i % len(PARTY)], r=rot(rng.uniform(0, 90), rng.uniform(0, 90), 0))


def rocket(p, x, y0, y1, z, body, tip, fin=BLUE, rad=0.045):
    """Kleine Rakete entlang -Y von y0 (hinten) bis y1 (Spitze)."""
    Y(p, rad, y0, y1 + rad * 2.2, z, body, sides=10, x=x)
    Y(p, rad, y1 + rad * 2.2, y1, z, tip, r2=0.0, sides=10, x=x)
    for a in (0, 120, 240):
        prism(p, [(0.0, 0.0), (0.0, 0.06), (0.05, 0.08), (0.05, 0.03)], 0.012, (x, y0 - 0.02, z), fin,
              r=rot(0, a, 0) @ Matrix.Translation(Vector((rad, 0, 0))) @ rot(-90, 0, 0))


def g_popper():
    p = Part()
    lathe(p, [(0.03, 0.2), (0.05, 0.1), (0.1, -0.2), (0.15, -0.46), (0.0, -0.4)], (0, 0, 0.12), [PINK, PINK, YEL, HOLE], r=rot(-90, 0, 0), sides=16)   # Knallertüte
    for y in (-0.05, -0.2, -0.35):
        ring(p, 0.05 + (-y) * 0.22, 0.012, y, 0.12, WHITE, seg=14, tseg=4)
    sweep(p, [(0, 0.2, 0.12), (0.0, 0.28, 0.08), (0.04, 0.32, 0.0)], 0.01, WHITE, sides=4)   # Zugschnur
    p.ball(0.03, (0.04, 0.33, -0.01), RED, subdiv=1)
    confetti(p, (0, -0.58, 0.14), 10, 0.11)
    grip(p, PINK_D, h=0.22)
    done("g_popper", p, (0, -0.5, 0.12))


def g_balloon():
    p = Part()
    for (x, y, z), c in (((0.0, -0.28, 0.06), "3C9BFF"), ((0.1, -0.18, 0.12), PINK), ((-0.1, -0.2, 0.1), YEL)):   # drei Wasserbomben
        p.ball(0.12, (x, y, z), c, scale=(1, 1.1, 1), subdiv=2)
        p.cone(0.03, 0.05, (x, y + 0.13, z), c, r=rot(-90, 0, 0), sides=8)
        p.ball(0.03, (x - 0.04, y - 0.05, z + 0.07), WHITE, subdiv=1)
    for x in (0.0, 0.1, -0.1):
        sweep(p, [(x, -0.1, 0.06), (x * 0.5, 0.0, 0.02), (0, 0.08, 0.0)], 0.008, WHITE, sides=4)
    p.box((0.06, 0.1, 0.06), (0, 0.06, 0.0), PINK_D, bevel=0.02, segs=1)
    done("g_balloon", p, (0, -0.42, 0.06), tilt=10, pitch=30)


def g_roman():
    p = Part()
    z = 0.06
    stripes(p, 0.28, -0.6, z, 0.06, 9, RED, WHITE, sides=12)                        # Feuerwerksrohr
    Y(p, 0.068, -0.58, -0.64, z, YEL, sides=12)
    hole(p, 0.04, -0.64, z)
    for i, c in enumerate((PINK, CYAN, YEL)):                                       # bunte Kugeln
        p.ball(0.04, (0.0, -0.7 - i * 0.06, z + 0.02 * i), c, subdiv=1)
    sparkle(p, 0.06, (0, -0.86, z + 0.08), YEL)
    sweep(p, [(0, 0.28, z), (0, 0.34, z + 0.05), (0.02, 0.38, z + 0.1)], 0.01, WHITE, sides=4)
    p.box((0.075, 0.1, 0.14), (0, 0.02, z - 0.08), PINK_D, bevel=0.02, segs=1)
    done("g_roman", p, (0, -0.66, z), tilt=26)


def g_pinata():
    p = Part()
    c = (0, -0.22, 0.12)
    for i, col in enumerate((PINK, YEL, CYAN, PINK, YEL)):                          # Körper mit Fransenstreifen
        p.box((0.2, 0.06, 0.18), (0, -0.1 - i * 0.06, 0.12), col, bevel=0.02, segs=1)
    for sx in (-1, 1):                                                              # Beine
        for y in (-0.12, -0.32):
            p.box((0.05, 0.05, 0.14), (sx * 0.07, y, -0.02), PARTY[(y < -0.2) + 2], bevel=0.012, segs=1)
    p.box((0.12, 0.12, 0.2), (0, -0.4, 0.26), PINK, r=rot(20, 0, 0), bevel=0.03, segs=1)   # Hals und Kopf
    p.box((0.12, 0.14, 0.1), (0, -0.48, 0.34), YEL, bevel=0.03, segs=1)
    for sx in (-1, 1):
        p.box((0.03, 0.03, 0.1), (sx * 0.04, -0.42, 0.44), CYAN, bevel=0.01, segs=1)   # Ohren
        p.ball(0.018, (sx * 0.05, -0.53, 0.36), BLACK, subdiv=1)
    p.box((0.04, 0.08, 0.03), (0, 0.0, 0.2), GRN, bevel=0.01, segs=1)              # Schwanz
    p.box((0.05, 0.1, 0.05), (0, 0.06, 0.0), PINK_D, bevel=0.02, segs=1)
    done("g_pinata", p, (0, -0.55, 0.3), tilt=0, yaw=-60, pitch=20)


def g_umbrella():
    p = Part()
    Y(p, 0.022, 0.24, -0.72, 0, DGREY, sides=8)                                    # Stock
    lathe(p, [(0.0, -0.14), (0.05, -0.2), (0.11, -0.36), (0.09, -0.56), (0.03, -0.66), (0.0, -0.7)], (0, 0, 0), PINK, r=rot(-90, 0, 0), sides=8)   # Schirm zu
    for a in range(0, 360, 90):
        x, z = math.cos(math.radians(a)) * 0.1, math.sin(math.radians(a)) * 0.1
        p.ball(0.025, (x, -0.38, z), WHITE, subdiv=1)                               # Blümchen
        p.ball(0.012, (x * 1.15, -0.38, z * 1.15), YEL, subdiv=1)
    p.box((0.03, 0.06, 0.03), (0, -0.38, 0.0), PINK_D)
    p.ball(0.07, (0, 0.28, 0.02), YEL, subdiv=2)                                     # Entenkopf-Griff
    p.cone(0.04, 0.08, (0, 0.24, 0.0), ORG, r=rot(90, 0, 0), sides=8)
    for sx in (-1, 1):
        p.ball(0.014, (sx * 0.04, 0.24, 0.05), BLACK, subdiv=1)
    done("g_umbrella", p, (0, -0.72, 0), tilt=30)


def g_battery():
    p = Part()
    p.box((0.32, 0.36, 0.2), (0, -0.18, 0.06), "C98548", bevel=0.025, segs=1)    # Holzkiste
    p.box((0.33, 0.06, 0.21), (0, -0.18, 0.06), RED, bevel=0.01, segs=1)
    star(p, 0.06, 0.03, (0.17, -0.18, 0.06), YEL, r=rot(0, 0, 90))
    for i in range(6):                                                              # sechs Raketen
        x = -0.1 + (i % 3) * 0.1
        y = -0.12 - (i // 3) * 0.14
        rocket(p, x, y + 0.1, y - 0.24, 0.2 + (i // 3) * 0.04, PARTY[i], RED if i % 2 else YEL, rad=0.032)
    p.box((0.05, 0.12, 0.05), (0, 0.04, 0.0), PINK_D, bevel=0.02, segs=1)
    done("g_battery", p, (0, -0.52, 0.22), tilt=10, pitch=34)


def g_kettle():
    p = Part()
    lathe(p, [(0.0, 0.17), (0.08, 0.16), (0.16, 0.06), (0.17, -0.04), (0.14, -0.14), (0.0, -0.15)], (0, -0.18, 0.1), [GREY_L, PINK, PINK, WHITE, WHITE], sides=16)   # Kessel
    for a in range(0, 360, 60):
        p.ball(0.022, (math.cos(math.radians(a)) * 0.165, -0.18 + math.sin(math.radians(a)) * 0.165, 0.11), WHITE, subdiv=1)
    p.ball(0.03, (0, -0.18, 0.28), RED, subdiv=1)
    sweep(p, [(0, -0.3, 0.06), (0, -0.42, 0.1), (0, -0.5, 0.18), (0, -0.56, 0.22)], [0.045, 0.04, 0.03, 0.025], PINK, sides=8)   # Tülle
    sweep(p, [(0.0, -0.06, 0.24), (0, -0.18, 0.36), (0, -0.3, 0.24)], 0.02, DGREY, sides=6)   # Henkel
    for (x, y, z), rr in (((0, -0.62, 0.28), 0.05), ((0.03, -0.68, 0.34), 0.04), ((-0.02, -0.66, 0.38), 0.035)):   # Dampf
        p.ball(rr, (x, y, z), WHITE, subdiv=1)
    p.box((0.05, 0.12, 0.05), (0, 0.0, 0.0), PINK_D, bevel=0.02, segs=1)
    done("g_kettle", p, (0, -0.56, 0.22), tilt=0, pitch=26)


def g_wheel():
    p = Part()
    c = (0, -0.22, 0.0)
    p.cyl(0.07, 0.06, c, YEL, sides=12)                                             # Nabe
    p.torus(0.18, 0.025, c, PINK, seg=20, tseg=5)                                    # Rad
    for a in range(0, 360, 60):                                                     # Speichen mit Hülsen
        r = rot(0, 0, a)
        v = r @ Vector((0, 0.13, 0))
        p.box((0.025, 0.12, 0.025), (v.x * 0.55, -0.22 + v.y * 0.55, 0.0), WHITE, r=r)
        q = r @ Vector((0.0, 0.2, 0.0))
        p.cyl(0.028, 0.1, (q.x, -0.22 + q.y, 0.0), RED if a % 120 else CYAN, r=r @ rot(0, 90, 0), sides=8)
    sparkle(p, 0.06, (0.22, -0.3, 0.05), YEL, face="z")
    sparkle(p, 0.05, (-0.2, -0.1, 0.05), WHITE, face="z")
    p.box((0.05, 0.12, 0.05), (0, 0.02, 0.0), PINK_D, bevel=0.02, segs=1)
    done("g_wheel", p, (0, -0.44, 0), tilt=0, yaw=-20, pitch=60)


def g_candy():
    p = Part()
    z = 0.13
    p.box((0.15, 0.34, 0.18), (0, -0.04, z), PINK, bevel=0.07, segs=3)
    stripes(p, -0.2, -0.64, z, 0.06, 8, RED, WHITE, sides=12)                        # Zuckerstangen-Lauf
    Y(p, 0.075, -0.62, -0.7, z, PINK_D, bevel=0.015, sides=12, segs=1)
    hole(p, 0.045, -0.7, z)
    p.ball(0.12, (0, -0.02, z + 0.2), "E8F8FF", subdiv=2)                           # Kaugummi-Glas
    for i, (x, y, zz) in enumerate(((0.04, 0.0, 0.16), (-0.05, -0.03, 0.18), (0.0, 0.05, 0.22), (0.02, -0.06, 0.25), (-0.03, 0.03, 0.27))):
        p.ball(0.04, (x, y - 0.02, z + zz), PARTY[i], subdiv=1)
    p.cyl(0.06, 0.03, (0, -0.02, z + 0.33), RED, sides=10)
    grip(p, PINK_D)
    trigger(p)
    done("g_candy", p, (0, -0.7, z))


def g_bigrocket():
    p = Part()
    z = 0.22
    p.box((0.1, 0.62, 0.06), (0, -0.16, 0.06), DGREY, bevel=0.02, segs=1)        # Startschiene
    rocket(p, 0.0, 0.26, -0.72, z, RED, YEL, fin=BLUE, rad=0.1)
    ring(p, 0.102, 0.02, -0.2, z, WHITE, seg=14, tseg=4)
    ring(p, 0.102, 0.02, -0.34, z, WHITE, seg=14, tseg=4)
    star(p, 0.06, 0.03, (0.1, -0.06, z), YEL, r=rot(0, 0, 90))
    star(p, 0.06, 0.03, (-0.1, -0.06, z), YEL, r=rot(0, 0, 90))
    sweep(p, [(0, 0.28, z), (0, 0.34, z + 0.06), (0.03, 0.36, z + 0.12)], 0.012, WHITE, sides=4)
    sparkle(p, 0.05, (0.03, 0.37, z + 0.16), YEL)
    grip(p, PINK_D)
    trigger(p)
    done("g_bigrocket", p, (0, -0.72, z))


def g_disco():
    p = Part()
    Y(p, 0.03, 0.3, -0.36, 0, PINK_D, sides=8)
    p.ball(0.05, (0, 0.31, 0), YEL, subdiv=2)
    p.ball(0.2, (0, -0.56, 0), GREY_L, subdiv=1)                                      # Diskokugel (Facetten)
    for f in list(p.bm.faces)[-80:]:
        c = f.calc_center_median()
        k = int((c.x * 31 + c.y * 17 + c.z * 23) * 100) % 4
        if c.y < -0.3:
            for l in f.loops:
                l[p.layer] = col([WHITE, CYAN, PINK, YEL][k])
        f.smooth = False
    p.cyl(0.03, 0.08, (0, -0.56, 0.22), DGREY, sides=8)
    done("g_disco", p, (0, -0.76, 0), tilt=24)


def g_finale():
    p = Part()
    p.box((0.34, 0.32, 0.12), (0, -0.16, 0.0), PINK_D, bevel=0.03, segs=2)        # Gestell
    for i in range(3):
        for j in range(3):
            x = -0.1 + i * 0.1
            zz = 0.1 + j * 0.1
            Y(p, 0.042, 0.06, -0.5 - 0.04 * ((i + j) % 2), zz, PARTY[(i + j * 3) % 6], sides=10, x=x)   # Rohre
            hole(p, 0.026, -0.5 - 0.04 * ((i + j) % 2), zz, x=x)
    p.box((0.36, 0.06, 0.34), (0, 0.08, 0.2), PINK, bevel=0.02, segs=1)
    star(p, 0.07, 0.03, (0, 0.12, 0.2), YEL, r=rot(0, 0, 0))
    sparkle(p, 0.06, (0.12, -0.6, 0.34), YEL)
    sparkle(p, 0.05, (-0.12, -0.62, 0.3), WHITE)
    grip(p, PINK_D)
    trigger(p)
    done("g_finale", p, (0, -0.54, 0.2), pitch=24)


ALL = dict(g_popper=g_popper, g_balloon=g_balloon, g_roman=g_roman, g_pinata=g_pinata, g_umbrella=g_umbrella, g_battery=g_battery,
           g_kettle=g_kettle, g_wheel=g_wheel, g_candy=g_candy, g_bigrocket=g_bigrocket, g_disco=g_disco, g_finale=g_finale)

if __name__ == "__main__":
    main(ALL)
