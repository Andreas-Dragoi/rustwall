"""V4 Waffen-Arsenal – Jona (Soldat und Postbote): Blau, Gelb, Postgelb, Briefumschläge, Stempel, Anker.
Aufruf: python3 blender/weapons_v4_jona.py [j_pistol ...]"""
import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from weapons_v4_kit import *


def envelope(p, loc, s=1.0, r=None):
    x, y, z = loc
    p.box((0.03 * s, 0.2 * s, 0.13 * s), loc, WHITE, r=r, bevel=0.01, segs=1)
    prism(p, [(-0.1 * s, 0.065 * s), (0.1 * s, 0.065 * s), (0, -0.02 * s)], 0.012, (x + 0.017 * s, y, z), RED, r=rot(0, 0, 90))


def j_pistol():
    p = Part()
    z = 0.12
    p.box((0.13, 0.44, 0.17), (0, -0.16, z), BLUE, bevel=0.06, segs=3)              # Schlitten
    p.box((0.136, 0.28, 0.035), (0, -0.16, z + 0.065), BLUE_L, bevel=0.012, segs=1)
    Y(p, 0.05, -0.38, -0.62, z, GREY, sides=12)                                    # Lauf
    Y(p, 0.065, -0.56, -0.66, z, YEL, bevel=0.015, sides=12, segs=1)
    hole(p, 0.035, -0.66, z)
    p.cyl(0.05, 0.08, (0, -0.06, z + 0.12), RED_D, sides=10, bevel=0.015, segs=1)  # Stempel obendrauf
    p.ball(0.06, (0, -0.06, z + 0.2), RED, subdiv=2)
    p.box((0.1, 0.12, 0.03), (0, -0.06, z + 0.085), DGREY, bevel=0.01, segs=1)
    envelope(p, (0.07, -0.2, z - 0.01), 0.8)
    grip(p, NAVY, h=0.24)
    trigger(p, -0.08)
    done("j_pistol", p, (0, -0.66, z))


def j_shotgun():
    p = Part()
    z = 0.13
    p.box((0.11, 0.26, 0.16), (0, 0.17, 0.08), WOOD, bevel=0.05)                  # Holzschaft
    p.box((0.12, 0.05, 0.19), (0, 0.29, 0.07), "7A4522", bevel=0.02, segs=1)
    p.box((0.15, 0.24, 0.17), (0, -0.07, z), NAVY, bevel=0.05, segs=2)            # Gehäuse
    for sx in (-1, 1):                                                              # Doppellauf
        Y(p, 0.045, -0.15, -0.7, z + 0.02, GREY_L, sides=10, x=sx * 0.045)
        hole(p, 0.03, -0.7, z + 0.02, x=sx * 0.045)
    Y(p, 0.07, -0.32, -0.52, z - 0.06, YEL, bevel=0.02, sides=12)                 # Pumpe
    for y in (-0.36, -0.42, -0.48):
        ring(p, 0.072, 0.012, y, z - 0.06, ORG, seg=12, tseg=4)
    envelope(p, (0.08, -0.07, z), 0.9)
    envelope(p, (-0.08, -0.07, z), 0.9, r=rot(0, 0, 180))
    grip(p, NAVY)
    trigger(p, -0.02)
    done("j_shotgun", p, (0, -0.7, z + 0.02), tilt=20)


def boomerang(p, col, band, tip, span=0.25, depth=0.45, w=0.11, n=3):
    """V-förmiger Bumerang, flach in der X-Y-Ebene, Spitze vorn (y = -depth), Enden hinten (x = ±span, y = 0)."""
    L = math.hypot(span, depth)
    ang = math.degrees(math.atan2(span, depth))
    for s in (-1, 1):
        k = rot(0, 0, -s * ang)
        dx, dy = s * span / L, depth / L                     # Richtung von der Spitze zum Ende
        p.box((w, L + 0.04, 0.045), (s * span * 0.5, -depth * 0.5, 0.0), col, r=k, bevel=0.02, segs=2)
        for i in range(n):
            t = 0.25 + 0.2 * i
            p.box((w + 0.006, 0.035, 0.05), (dx * L * t, -depth + dy * L * t, 0.0), band, r=k, bevel=0.01, segs=1)
        p.ball(w * 0.55, (s * span, 0.0, 0.0), tip, scale=(1, 1, 0.5), subdiv=2)
    p.ball(w * 0.62, (0, -depth, 0), tip, scale=(1.1, 1, 0.55), subdiv=2)


def j_boomerang():
    p = Part()
    boomerang(p, YEL, BLUE, RED)
    star(p, 0.06, 0.03, (0, -0.3, 0.03), WHITE, r=rot(90, 0, 0))
    done("j_boomerang", p, (0, -0.45, 0), tilt=0, yaw=-20, pitch=62)


def j_mortar():
    p = Part()
    z = 0.2
    Y(p, 0.16, 0.12, -0.52, z, YEL, bevel=0.03, sides=16)                         # Rohr (Briefkastengelb)
    Y(p, 0.175, -0.4, -0.54, z, BLUE, bevel=0.02, sides=16, segs=1)
    Y(p, 0.13, 0.22, 0.1, z, NAVY, bevel=0.03, sides=14)
    hole(p, 0.13, -0.54, z)
    p.torus(0.08, 0.025, (0.16, -0.18, z), BLUE_D, r=rot(0, 90, 0), seg=14, tseg=5)   # Posthorn
    p.ball(0.04, (0.17, -0.1, z + 0.08), BLUE_D, subdiv=1)
    p.box((0.05, 0.16, 0.05), (0, -0.05, z + 0.17), DGREY, bevel=0.015, segs=1)   # Visier
    for sx in (-1, 1):                                                              # Zweibein
        sweep(p, [(sx * 0.05, -0.36, z - 0.1), (sx * 0.18, -0.42, -0.08), (sx * 0.22, -0.44, -0.2)], 0.025, DGREY, sides=6)
    p.box((0.32, 0.16, 0.04), (0, 0.2, 0.02), GREY, bevel=0.015, segs=1)          # Bodenplatte
    grip(p, NAVY)
    trigger(p)
    done("j_mortar", p, (0, -0.54, z))


def j_smg():
    p = Part()
    z = 0.13
    p.box((0.12, 0.38, 0.17), (0, -0.1, z), "5E9A2E", bevel=0.06, segs=3)        # Gehäuse in Jonas Grün
    p.box((0.126, 0.24, 0.035), (0, -0.1, z + 0.065), "8FCB55", bevel=0.012, segs=1)
    Y(p, 0.058, -0.3, -0.56, z, NAVY, sides=10)                                    # Mantel mit Löchern
    for y in (-0.34, -0.4, -0.46, -0.52):
        ring(p, 0.06, 0.012, y, z, GREY, seg=10, tseg=4)
    Y(p, 0.04, -0.54, -0.68, z, GREY, sides=10)
    hole(p, 0.03, -0.68, z)
    p.box((0.07, 0.1, 0.32), (0, -0.16, -0.12), YEL, r=rot(-8, 0, 0), bevel=0.025, segs=1)   # langes Magazin
    Y(p, 0.045, 0.06, -0.24, z + 0.13, CYAN, sides=10)                             # Rohrpost-Kapsel
    p.ball(0.045, (0, 0.06, z + 0.13), BLUE, subdiv=1)
    p.ball(0.045, (0, -0.24, z + 0.13), BLUE, subdiv=1)
    p.box((0.04, 0.24, 0.07), (0, 0.18, z - 0.02), DGREY, bevel=0.02, segs=1)     # Klappschaft
    grip(p, NAVY)
    trigger(p)
    done("j_smg", p, (0, -0.68, z))


def j_mine():
    p = Part()
    c = (0, -0.2, 0.06)
    p.box((0.34, 0.34, 0.24), c, TAN, bevel=0.03, segs=2)                         # Paket
    p.box((0.35, 0.07, 0.25), c, RED, bevel=0.01, segs=1)                         # Schnur
    p.box((0.07, 0.35, 0.25), c, RED, bevel=0.01, segs=1)
    p.torus(0.05, 0.016, (0.0, -0.2, 0.2), RED, r=rot(90, 0, 0), seg=10, tseg=4)  # Schleife
    p.torus(0.05, 0.016, (0.0, -0.2, 0.2), RED, r=rot(90, 0, 90), seg=10, tseg=4)
    p.ball(0.045, (0.11, -0.31, 0.19), "FF3030", subdiv=2)                        # Warnlampe
    p.cyl(0.05, 0.03, (0.11, -0.31, 0.17), DGREY, sides=10)
    p.box((0.14, 0.03, 0.08), (-0.08, -0.37, 0.08), WHITE, bevel=0.008, segs=1)   # Adressaufkleber
    p.box((0.05, 0.1, 0.05), (0, 0.0, 0.0), NAVY, bevel=0.02, segs=1)             # Griffschlaufe
    done("j_mine", p, (0, -0.37, 0.06), tilt=10, pitch=26)


def j_flare():
    p = Part()
    z = 0.14
    p.box((0.13, 0.24, 0.21), (0, -0.06, z - 0.02), ORG, bevel=0.06, segs=3)             # Gehäuse
    Y(p, 0.1, -0.15, -0.6, z, RED, bevel=0.02, sides=16)                            # dicker Lauf
    Y(p, 0.115, -0.52, -0.62, z, YEL, bevel=0.02, sides=16, segs=1)
    hole(p, 0.075, -0.62, z, "FFE98A")
    ring(p, 0.105, 0.018, -0.25, z, YEL, seg=14, tseg=5)
    star(p, 0.065, 0.03, (0.1, -0.38, z), YEL, r=rot(0, 0, 90))
    star(p, 0.065, 0.03, (-0.1, -0.38, z), YEL, r=rot(0, 0, 90))
    p.box((0.04, 0.1, 0.05), (0, 0.06, z + 0.11), DGREY, bevel=0.012, segs=1)      # Hahn
    grip(p, RED_D, h=0.25)
    trigger(p, -0.04)
    done("j_flare", p, (0, -0.62, z))


def j_harpoon():
    p = Part()
    z = 0.12
    p.box((0.1, 0.24, 0.14), (0, 0.17, 0.08), NAVY, bevel=0.045)                   # Schaft
    Y(p, 0.08, 0.06, -0.42, z, BLUE, bevel=0.02, sides=14)                         # Rohr
    ring(p, 0.082, 0.016, -0.1, z, YEL, seg=12, tseg=4)
    ring(p, 0.082, 0.016, -0.36, z, YEL, seg=12, tseg=4)
    Y(p, 0.022, -0.4, -0.6, z, GREY_L, sides=8)                                    # Ankerschaft
    p.torus(0.035, 0.012, (0, -0.44, z), GREY_L, r=rot(0, 90, 0), seg=10, tseg=4)
    sweep(p, [(-0.12, -0.6, z + 0.05), (-0.08, -0.66, z), (0, -0.69, z), (0.08, -0.66, z), (0.12, -0.6, z + 0.05)], 0.02, GREY_L, sides=6)
    for sx in (-1, 1):                                                              # Flunken
        prism(p, [(0, 0), (0.05, 0.02), (0.0, 0.07)], 0.03, (sx * 0.12, -0.6, z + 0.05), GREY, r=rot(0, 0, 0))
    p.ball(0.02, (0, -0.7, z), GREY_L, subdiv=1)
    p.torus(0.07, 0.022, (0.12, -0.12, z - 0.02), TAN, r=rot(0, 90, 0), seg=14, tseg=5)   # Leine
    p.torus(0.05, 0.02, (0.12, -0.12, z - 0.02), TAN, r=rot(0, 90, 0), seg=12, tseg=5)
    grip(p, NAVY)
    trigger(p)
    done("j_harpoon", p, (0, -0.7, z), tilt=18)


def j_tesla():
    p = Part()
    z = 0.15
    p.box((0.18, 0.34, 0.24), (0, -0.04, z + 0.02), "5E9A2E", bevel=0.05, segs=2)   # Funkgerät
    p.box((0.186, 0.12, 0.12), (0, 0.04, z + 0.06), DGREY, bevel=0.02, segs=1)       # Lautsprecher
    for i in range(3):
        p.box((0.19, 0.012, 0.09), (0, 0.0 + i * 0.035, z + 0.06), GREY, bevel=0.004, segs=1)
    for i, c in enumerate((RED, YEL)):                                                 # Drehknöpfe
        p.cyl(0.03, 0.03, (0.1, -0.1 - 0.07 * i, z + 0.06), c, r=rot(0, 90, 0), sides=10)
    sweep(p, [(-0.06, 0.08, z + 0.14), (-0.07, 0.1, z + 0.32), (-0.08, 0.13, z + 0.46)], 0.012, GREY_L, sides=5)   # Antenne
    p.ball(0.03, (-0.08, 0.13, z + 0.47), RED, subdiv=1)
    Y(p, 0.05, -0.2, -0.44, z, NAVY, sides=10)
    lathe(p, [(0.02, 0.0), (0.13, 0.02), (0.16, 0.08), (0.0, 0.05)], (0, -0.5, z), [GREY_L, CYAN, CYAN], r=rot(90, 0, 0), sides=14)  # Sendeschüssel
    prism(p, [(-0.03, 0.06), (0.02, 0.06), (0.0, 0.0), (0.03, 0.0), (-0.02, -0.07), (0.0, -0.01), (-0.03, -0.01)], 0.02, (0.095, -0.1, z + 0.0), YEL, r=rot(0, 0, 90))
    grip(p, NAVY)
    trigger(p)
    done("j_tesla", p, (0, -0.55, z))


def j_turret():
    p = Part()
    c = (0, -0.18, 0.06)
    p.box((0.32, 0.36, 0.26), c, TAN, bevel=0.03, segs=2)                         # Paket
    p.box((0.33, 0.07, 0.27), c, BLUE, bevel=0.01, segs=1)
    Y(p, 0.045, -0.3, -0.52, 0.12, DGREY, sides=10)                                # MG-Lauf schaut heraus
    Y(p, 0.06, -0.48, -0.54, 0.12, YEL, sides=10)
    hole(p, 0.03, -0.54, 0.12)
    for sx in (-1, 1):                                                              # eingeklappte Beine
        sweep(p, [(sx * 0.17, -0.05, 0.12), (sx * 0.2, -0.15, -0.05), (sx * 0.19, -0.3, -0.06)], 0.02, GREY, sides=5)
    p.box((0.16, 0.03, 0.09), (-0.06, -0.37, 0.15), WHITE, bevel=0.008, segs=1)
    star(p, 0.04, 0.02, (-0.06, -0.39, 0.15), RED, r=rot(0, 0, 0))
    p.box((0.05, 0.1, 0.05), (0, 0.0, 0.0), NAVY, bevel=0.02, segs=1)
    done("j_turret", p, (0, -0.54, 0.12), tilt=10, pitch=26)


def j_rocket():
    p = Part()
    z = 0.2
    p.box((0.3, 0.6, 0.12), (0, -0.2, z - 0.1), NAVY, bevel=0.04, segs=2)          # Träger
    for i, x in enumerate((-0.09, 0.0, 0.09)):                                      # drei Rohre
        zz = z + (0.05 if i == 1 else 0.0)
        Y(p, 0.06, 0.08, -0.55, zz, BLUE if i != 1 else YEL, sides=12, x=x)
        Y(p, 0.045, -0.48, -0.66, zz, RED, r2=0.0, sides=10, x=x)                   # Raketenspitzen
        ring(p, 0.062, 0.012, -0.4, zz, WHITE, seg=10, tseg=4, x=x)
    p.box((0.05, 0.12, 0.08), (0.17, -0.15, z + 0.08), DGREY, bevel=0.015, segs=1)  # Visier
    Y(p, 0.03, -0.1, -0.2, z + 0.13, CYAN, sides=8, x=0.17)
    p.box((0.085, 0.1, 0.16), (0, -0.32, -0.04), DGREY, bevel=0.035, segs=1)
    grip(p, NAVY)
    trigger(p)
    done("j_rocket", p, (0, -0.66, z))


def j_railgun():
    p = Part()
    z = 0.11
    p.box((0.09, 0.26, 0.13), (0, 0.17, 0.07), NAVY, bevel=0.04)                   # Schaft
    p.box((0.12, 0.3, 0.16), (0, -0.08, z), WHITE, bevel=0.05, segs=2)             # Gehäuse
    for sx in (-1, 1):                                                              # Schienen
        p.box((0.025, 0.46, 0.05), (sx * 0.04, -0.46, z), BLUE, bevel=0.01, segs=1)
    for y in (-0.3, -0.4, -0.5, -0.6):                                              # Spulen
        ring(p, 0.065, 0.016, y, z, CYAN, seg=12, tseg=4)
    Y(p, 0.02, -0.25, -0.7, z, GREY_L, sides=8)
    p.box((0.05, 0.16, 0.05), (0, -0.02, z + 0.11), YEL, bevel=0.015, segs=1)     # Zielfernrohr
    Y(p, 0.035, 0.06, -0.12, z + 0.17, NAVY, sides=10)
    hole(p, 0.03, -0.12, z + 0.17, CYAN)
    p.box((0.07, 0.1, 0.12), (0, -0.14, -0.02), DGREY, bevel=0.02, segs=1)
    grip(p, NAVY, h=0.2, w=0.08, d=0.1)
    trigger(p, -0.04)
    done("j_railgun", p, (0, -0.7, z), tilt=18)


ALL = dict(j_pistol=j_pistol, j_shotgun=j_shotgun, j_boomerang=j_boomerang, j_mortar=j_mortar, j_smg=j_smg, j_mine=j_mine,
           j_flare=j_flare, j_harpoon=j_harpoon, j_tesla=j_tesla, j_turret=j_turret, j_rocket=j_rocket, j_railgun=j_railgun)

if __name__ == "__main__":
    main(ALL)
