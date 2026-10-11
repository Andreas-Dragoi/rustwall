"""V4 Waffen-Arsenal – Ada (Erfinderin): Violett, Weiß, Kupferspulen, Glaskolben, Blitze.
Aufruf: python3 blender/weapons_v4_ada.py [a_zapper ...]"""
import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from weapons_v4_kit import *

COPPER = "D9824A"


def bolt_icon(p, loc, s=1.0, r=None, col=YEL):
    pts = [(-0.03, 0.06), (0.02, 0.06), (0.0, 0.0), (0.03, 0.0), (-0.02, -0.07), (0.0, -0.01), (-0.03, -0.01)]
    prism(p, [(x * s, z * s) for x, z in pts], 0.02, loc, col, r=r if r is not None else rot(0, 0, 90))


def a_zapper():
    p = Part()
    z = 0.12
    p.box((0.13, 0.36, 0.17), (0, -0.12, z), VIO, bevel=0.06, segs=3)
    p.box((0.136, 0.2, 0.035), (0, -0.12, z + 0.07), "B9A4FF", bevel=0.012, segs=1)
    Y(p, 0.03, -0.3, -0.5, z, GREY, sides=8)
    for y in (-0.34, -0.39, -0.44):                                                 # Kupferspule
        ring(p, 0.045, 0.014, y, z, COPPER, seg=10, tseg=4)
    p.ball(0.07, (0, -0.56, z), CYAN, subdiv=2)                                     # Ladekugel
    p.ball(0.03, (-0.03, -0.58, z + 0.04), WHITE, subdiv=1)
    bolt_icon(p, (0.07, -0.12, z), 0.9)
    grip(p, NAVY, h=0.24)
    trigger(p, -0.06)
    done("a_zapper", p, (0, -0.6, z))


def a_magnet():
    p = Part()
    z = 0.13
    p.box((0.14, 0.36, 0.18), (0, -0.04, z), WHITE, bevel=0.06, segs=3)
    p.box((0.146, 0.2, 0.04), (0, -0.04, z + 0.06), VIO, bevel=0.012, segs=1)
    Y(p, 0.05, -0.2, -0.36, z, DGREY, sides=10)
    # Hufeisenmagnet: zwei Schenkel nach vorn, Bogen hinten
    sweep(p, [(-0.13, -0.6, z), (-0.13, -0.44, z)], 0.05, RED, sides=8)
    sweep(p, [(0.13, -0.6, z), (0.13, -0.44, z)], 0.05, RED, sides=8)
    sweep(p, [(-0.13, -0.44, z), (-0.09, -0.36, z), (0.0, -0.33, z), (0.09, -0.36, z), (0.13, -0.44, z)], 0.05, RED, sides=8)
    for sx in (-1, 1):
        Y(p, 0.052, -0.6, -0.68, z, GREY_L, sides=8, x=sx * 0.13)                  # Polschuhe
    p.cyl(0.08, 0.03, (0, -0.62, z), GREY, r=rot(0, 90, 0), sides=14)              # Scheibe
    p.cyl(0.03, 0.035, (0, -0.62, z), YEL, r=rot(0, 90, 0), sides=10)
    grip(p, NAVY)
    trigger(p)
    done("a_magnet", p, (0, -0.68, z))


def a_laser():
    p = Part()
    z = 0.12
    p.box((0.1, 0.24, 0.13), (0, 0.17, 0.07), NAVY, bevel=0.04)                     # Schaft
    p.box((0.13, 0.44, 0.17), (0, -0.16, z), WHITE, bevel=0.06, segs=3)             # Gehäuse
    for i in range(4):                                                              # Kühlrippen
        p.box((0.17, 0.025, 0.1), (0, -0.06 - i * 0.06, z + 0.04), VIO, bevel=0.008, segs=1)
    Y(p, 0.045, -0.38, -0.62, z, GREY_L, sides=12)
    Y(p, 0.065, -0.6, -0.68, z, VIO_D, bevel=0.015, sides=12, segs=1)
    p.ball(0.045, (0, -0.68, z), "FF4D6D", subdiv=2)                                # rote Linse
    p.box((0.05, 0.14, 0.05), (0, -0.1, z + 0.12), YEL, bevel=0.015, segs=1)
    grip(p, NAVY)
    trigger(p)
    done("a_laser", p, (0, -0.7, z))


def a_drone():
    p = Part()
    c = (0, -0.22, 0.08)
    p.cyl(0.17, 0.09, c, WHITE, sides=18, bevel=0.03)                               # Körper (Rauchmelder)
    p.cyl(0.1, 0.03, (0, -0.22, 0.14), GREY_L, sides=16)
    p.ball(0.04, (0, -0.22, 0.16), "FF3030", subdiv=2)
    for a in (45, 135, 225, 315):                                                   # Ausleger und Propeller
        x, y = math.cos(math.radians(a)) * 0.22, -0.22 + math.sin(math.radians(a)) * 0.22
        p.box((0.2, 0.035, 0.03), ((x) * 0.6, -0.22 + (y + 0.22) * 0.6, 0.1), VIO, r=rot(0, 0, a), bevel=0.01, segs=1)
        p.cyl(0.025, 0.05, (x, y, 0.13), DGREY, sides=8)
        p.box((0.16, 0.035, 0.012), (x, y, 0.16), CYAN, r=rot(0, 0, a + 30), bevel=0.006, segs=1)
    for sx in (-1, 1):
        p.ball(0.03, (sx * 0.06, -0.37, 0.08), NAVY, subdiv=1)                      # Augen
    p.box((0.05, 0.12, 0.05), (0, 0.0, 0.0), NAVY, bevel=0.02, segs=1)
    done("a_drone", p, (0, -0.4, 0.08), tilt=0, pitch=44)


def a_coil():
    p = Part()
    Y(p, 0.035, 0.3, -0.36, 0, NAVY, sides=8)
    p.ball(0.05, (0, 0.31, 0), YEL, subdiv=2)
    for i in range(5):                                                              # Spulenturm, nach vorn kleiner
        ring(p, 0.11 - i * 0.012, 0.025, -0.24 - i * 0.07, 0, COPPER if i % 2 == 0 else "B8652F", seg=14, tseg=5)
    Y(p, 0.05, -0.2, -0.56, 0, GREY, sides=10)
    p.ball(0.11, (0, -0.64, 0), "C9B8FF", subdiv=3)                                 # Kugel
    p.ball(0.04, (-0.05, -0.68, 0.06), WHITE, subdiv=1)
    for a in (30, 150, 270):
        bolt_icon(p, (0.16 * math.cos(math.radians(a)), -0.62, 0.16 * math.sin(math.radians(a))), 1.0, rot(0, a, 90))
    done("a_coil", p, (0, -0.74, 0), tilt=30)


def a_freeze():
    p = Part()
    z = 0.13
    p.box((0.15, 0.4, 0.2), (0, -0.06, z), WHITE, bevel=0.07, segs=3)
    p.box((0.156, 0.22, 0.04), (0, -0.06, z + 0.075), CYAN, bevel=0.012, segs=1)
    p.ball(0.09, (0, 0.06, z + 0.17), CYAN, scale=(0.9, 1.3, 0.9), subdiv=2)        # Kühltank
    p.cyl(0.04, 0.04, (0, 0.06, z + 0.27), GREY, sides=10)
    Y(p, 0.05, -0.26, -0.5, z, GREY_L, sides=12)
    for y in (-0.32, -0.42):
        ring(p, 0.06, 0.016, y, z, CYAN, seg=12, tseg=4)
    star(p, 0.12, 0.08, (0, -0.58, z), ICE, r=rot(0, 0, 90), n=6, inner=0.4, color2=CYAN)   # Eiskristall
    grip(p, NAVY)
    trigger(p, color=CYAN)
    done("a_freeze", p, (0, -0.66, z))


def a_gravity():
    p = Part()
    z = 0.2
    Y(p, 0.12, 0.2, -0.36, z, VIO_D, bevel=0.03, sides=16)
    Y(p, 0.14, -0.3, -0.42, z, YEL, bevel=0.02, sides=16, segs=1)
    p.ball(0.14, (0, -0.54, z), "7A3FD9", subdiv=3)                                  # Schwerkraftkugel
    p.ball(0.05, (-0.05, -0.6, z + 0.07), "C9B8FF", subdiv=1)
    p.torus(0.2, 0.014, (0, -0.54, z), CYAN, r=rot(70, 20, 0), seg=20, tseg=4)     # Bahnen
    p.torus(0.2, 0.014, (0, -0.54, z), PINK, r=rot(-30, 60, 0), seg=20, tseg=4)
    p.box((0.11, 0.3, 0.09), (0, -0.04, 0.045), NAVY, bevel=0.035, segs=1)
    grip(p)
    trigger(p)
    done("a_gravity", p, (0, -0.6, z))


def a_railgun():
    p = Part()
    z = 0.12
    p.box((0.1, 0.24, 0.14), (0, 0.17, 0.08), NAVY, bevel=0.045)
    p.box((0.14, 0.3, 0.18), (0, -0.06, z), VIO, bevel=0.06, segs=3)
    for sx in (-1, 1):
        p.box((0.03, 0.5, 0.06), (sx * 0.05, -0.44, z), WHITE, bevel=0.012, segs=1)
    for i in range(6):
        ring(p, 0.075, 0.016, -0.24 - i * 0.075, z, CYAN if i % 2 == 0 else COPPER, seg=12, tseg=4)
    Y(p, 0.022, -0.2, -0.72, z, GREY_L, sides=8)
    p.box((0.085, 0.1, 0.18), (0, -0.14, -0.04), DGREY, r=rot(-10, 0, 0), bevel=0.025, segs=1)
    grip(p, NAVY)
    trigger(p)
    done("a_railgun", p, (0, -0.72, z), tilt=18)


def a_mine():
    p = Part()
    c = (0, -0.22, 0.05)
    p.cyl(0.18, 0.08, c, VIO_D, sides=18, bevel=0.03)                               # Scheibe
    p.cyl(0.13, 0.03, (0, -0.22, 0.1), YEL, sides=16)
    bolt_icon(p, (0, -0.22, 0.12), 1.2, rot(90, 0, 0), NAVY)
    p.ball(0.035, (0.1, -0.32, 0.11), CYAN, subdiv=1)                               # Lämpchen
    for a in (0, 120, 240):                                                         # Saugnäpfe
        x, y = math.cos(math.radians(a)) * 0.16, -0.22 + math.sin(math.radians(a)) * 0.16
        p.cyl(0.05, 0.03, (x, y, 0.0), "4C5878", sides=10)
    p.box((0.05, 0.12, 0.05), (0, 0.0, 0.03), NAVY, bevel=0.02, segs=1)
    done("a_mine", p, (0, -0.4, 0.05), tilt=0, pitch=48)


def a_plasma():
    p = Part()
    z = 0.15
    p.box((0.16, 0.4, 0.2), (0, -0.02, z), VIO, bevel=0.07, segs=3)
    p.box((0.166, 0.22, 0.04), (0, -0.02, z + 0.07), WHITE, bevel=0.012, segs=1)
    Y(p, 0.08, -0.22, -0.36, z, GREY, sides=14)
    p.ball(0.15, (0, -0.48, z), "8FF0FF", scale=(1, 1.15, 1), subdiv=3)             # Glaskolben
    p.ball(0.07, (0, -0.48, z), "E0FFFF", subdiv=2)
    ring(p, 0.15, 0.02, -0.48, z, COPPER, seg=16, tseg=5)
    Y(p, 0.05, -0.6, -0.68, z, COPPER, sides=10)
    p.box((0.085, 0.1, 0.16), (0, -0.2, z - 0.17), DGREY, bevel=0.03, segs=1)
    grip(p, NAVY)
    trigger(p)
    done("a_plasma", p, (0, -0.68, z))


def a_swarm():
    p = Part()
    z = 0.1
    p.box((0.26, 0.42, 0.14), (0, -0.2, z), WHITE, bevel=0.04, segs=2)              # Startkiste
    p.box((0.265, 0.1, 0.145), (0, -0.2, z), VIO, bevel=0.01, segs=1)
    for i, (x, y) in enumerate(((-0.08, -0.08), (0.08, -0.08), (0.0, -0.22), (-0.08, -0.34), (0.08, -0.34))):   # fünf Mini-Drohnen
        p.ball(0.045, (x, y, z + 0.1), CYAN if i % 2 == 0 else YEL, scale=(1, 1, 0.6), subdiv=2)
        p.box((0.12, 0.02, 0.008), (x, y, z + 0.14), DGREY, r=rot(0, 0, 30 + i * 20))
    Y(p, 0.035, -0.4, -0.5, z, GREY, sides=8)
    grip(p, NAVY)
    trigger(p)
    done("a_swarm", p, (0, -0.5, z), pitch=34)


def a_storm():
    p = Part()
    Y(p, 0.035, 0.3, -0.38, 0, VIO_D, sides=8)
    for y in (0.2, 0.1):
        ring(p, 0.04, 0.012, y, 0, YEL, seg=10, tseg=4)
    p.ball(0.05, (0, 0.31, 0), YEL, subdiv=2)
    for (x, y, zz), rr in (((0, -0.5, 0.06), 0.13), ((0.1, -0.45, 0.12), 0.1), ((-0.1, -0.46, 0.11), 0.1),
                           ((0, -0.6, 0.14), 0.09), ((0, -0.44, 0.18), 0.09)):              # Gewitterwolke
        p.ball(rr, (x, y, zz), "8E9AB4", subdiv=2)
    bolt_icon(p, (0, -0.55, -0.12), 2.0, rot(0, 0, 90))
    bolt_icon(p, (0.08, -0.62, -0.06), 1.2, rot(0, 0, 90))
    done("a_storm", p, (0, -0.65, 0), tilt=24)


ALL = dict(a_zapper=a_zapper, a_magnet=a_magnet, a_laser=a_laser, a_drone=a_drone, a_coil=a_coil, a_freeze=a_freeze,
           a_gravity=a_gravity, a_railgun=a_railgun, a_mine=a_mine, a_plasma=a_plasma, a_swarm=a_swarm, a_storm=a_storm)

if __name__ == "__main__":
    main(ALL)
