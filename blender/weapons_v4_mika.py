"""V4 Waffen-Arsenal – Mika (Feuerwehr): Feuerwehrrot, Gelb, Messing, Flammen, Schaum und Eis.
Aufruf: python3 blender/weapons_v4_mika.py [m_axe ...]"""
import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from weapons_v4_kit import *

BRASS = "E0A82E"


def m_axe():
    p = Part()
    Y(p, 0.045, 0.3, -0.62, 0, RED, sides=10)                                      # Stiel
    for y in (0.26, 0.2, 0.14):
        ring(p, 0.047, 0.012, y, 0, DGREY, seg=10, tseg=4)
    p.ball(0.06, (0, 0.31, 0), YEL, subdiv=2)
    p.box((0.075, 0.13, 0.15), (0, -0.56, 0.02), GREY, bevel=0.02, segs=1)        # Kopf
    blade(p, [(-0.07, 0.0), (0.07, 0.0), (0.13, 0.2), (0.0, 0.25), (-0.13, 0.2)], 0.035, (0, -0.56, 0.08), GREY_L, r=rot(0, 0, 90))   # Schneide
    p.box((0.03, 0.14, 0.04), (0, -0.56, 0.31), WHITE, bevel=0.01, segs=1)        # Glanz der Schneide
    p.cone(0.04, 0.18, (0, -0.56, -0.12), RED_D, r=rot(180, 0, 0), sides=8)       # Pickel hinten
    p.box((0.08, 0.06, 0.16), (0, -0.48, 0.02), YEL, bevel=0.015, segs=1)
    done("m_axe", p, (0, -0.7, 0), tilt=30)


def m_extinguisher():
    p = Part()
    z = 0.22
    Y(p, 0.13, 0.24, -0.26, z, RED, bevel=0.06, sides=16, segs=3)                 # Behälter
    p.box((0.27, 0.12, 0.08), (0, -0.0, z), WHITE, bevel=0.02, segs=1)           # Schild
    p.box((0.272, 0.04, 0.03), (0, 0.0, z + 0.005), RED, bevel=0.008, segs=1)
    p.cyl(0.05, 0.06, (0, -0.2, z + 0.15), BLACK, sides=10)                        # Ventil
    p.box((0.06, 0.16, 0.03), (0, -0.14, z + 0.19), DGREY, r=rot(-10, 0, 0), bevel=0.01, segs=1)
    sweep(p, [(0, -0.26, z + 0.06), (0, -0.36, z + 0.0), (0, -0.46, z - 0.04), (0, -0.56, z - 0.02)], 0.03, BLACK, sides=6)
    Y(p, 0.04, -0.54, -0.64, z - 0.02, BLACK, r2=0.07, sides=10)                    # Düse
    for (x, y, zz), rr in (((0, -0.7, -0.01), 0.07), ((0.05, -0.66, 0.04), 0.05), ((-0.05, -0.68, 0.03), 0.045)):   # Schaum
        p.ball(rr, (x, y, z + zz), WHITE, subdiv=2)
    p.box((0.085, 0.1, 0.16), (0, -0.3, z - 0.18), DGREY, bevel=0.03, segs=1)
    grip(p, BLACK)
    trigger(p)
    done("m_extinguisher", p, (0, -0.68, z - 0.02))


def m_hose():
    p = Part()
    z = 0.12
    lathe(p, [(0.075, 0.3), (0.085, 0.18), (0.07, 0.0), (0.06, -0.3), (0.045, -0.52), (0.06, -0.58), (0.05, -0.7), (0.0, -0.7)],
          (0, 0, z), [BRASS, BRASS, RED, BRASS, YEL, BRASS, HOLE], r=rot(-90, 0, 0), sides=14)   # Strahlrohr (Messing)
    for y in (-0.06, -0.14):
        ring(p, 0.075, 0.02, y, z, BLACK, seg=14, tseg=5)
    p.box((0.05, 0.18, 0.05), (0, -0.2, z + 0.1), BLACK, r=rot(-15, 0, 0), bevel=0.015, segs=1)    # Hebel
    sweep(p, [(0, 0.3, z), (0.0, 0.42, z - 0.05), (0.1, 0.48, z - 0.15), (0.2, 0.42, z - 0.25)], 0.06, RED, sides=8)   # Schlauch
    p.ball(0.06, (0, -0.74, z), "9FE8FF", scale=(1, 1.5, 1), subdiv=2)
    grip(p, RED_D)
    done("m_hose", p, (0, -0.72, z))


def m_molotov():
    p = Part()
    lathe(p, [(0.0, 0.18), (0.13, 0.16), (0.14, 0.0), (0.12, -0.12), (0.05, -0.2), (0.045, -0.34), (0.055, -0.36), (0.0, -0.36)],
          (0, -0.1, 0.02), ["2F9A55", "2F9A55", "3CB868", GRN_D, GRN_D, BRASS, BRASS], r=rot(-90, 0, 0), sides=12)   # Flasche
    p.box((0.2, 0.14, 0.12), (0, -0.1, 0.02), WHITE, bevel=0.02, segs=1)                        # Etikett
    star(p, 0.045, 0.02, (0, -0.1, 0.09), RED, r=rot(90, 0, 0))
    sweep(p, [(0, -0.46, 0.02), (0.02, -0.52, 0.05), (-0.02, -0.58, 0.04)], 0.035, "F4E0B0", sides=6)   # Lappen
    flame(p, (0, -0.64, 0.08), 0.7)
    done("m_molotov", p, (0, -0.6, 0.05), tilt=34, pitch=18)


def m_halligan():
    p = Part()
    Y(p, 0.035, 0.3, -0.56, 0, GREY_L, sides=10)                                    # Stange
    for y in (0.22, 0.1, -0.02):
        ring(p, 0.04, 0.014, y, 0, RED, seg=10, tseg=4)
    for sx in (-1, 1):                                                              # Gabel hinten
        p.cone(0.03, 0.14, (sx * 0.035, 0.36, -0.01), GREY, r=rot(-95, 0, 0), sides=6)
    p.box((0.07, 0.08, 0.07), (0, -0.56, 0), GREY, bevel=0.015, segs=1)            # Kopf
    p.cone(0.035, 0.22, (0, -0.56, 0.13), GREY_L, sides=8)                          # Dorn
    blade(p, [(-0.05, 0.0), (0.05, 0.0), (0.03, 0.18), (-0.03, 0.18)], 0.03, (0, -0.6, 0.0), GREY_L, r=rot(90, 0, 0))   # Keil
    p.box((0.075, 0.1, 0.04), (0, 0.04, 0.0), YEL, bevel=0.01, segs=1)
    done("m_halligan", p, (0, -0.74, 0), tilt=26)


def m_napalm():
    p = Part()
    z = 0.2
    Y(p, 0.14, 0.18, -0.5, z, RED, bevel=0.03, sides=16)
    Y(p, 0.155, -0.42, -0.54, z, YEL, bevel=0.02, sides=16, segs=1)
    hole(p, 0.12, -0.54, z, "4A1A10")
    for (x, zz) in ((0.0, 0.0), (0.05, 0.05), (-0.05, 0.04), (0.02, -0.06)):        # Glut im Rohr
        p.ball(0.045, (x, -0.52, z + zz), ORG if x != 0.05 else YEL, subdiv=1)
    Y(p, 0.08, 0.16, -0.16, z + 0.17, ORG, bevel=0.03, sides=12)                  # Brennstofftank
    ring(p, 0.082, 0.014, 0.0, z + 0.17, BLACK, seg=12, tseg=4)
    flame(p, (0.15, -0.2, z), 0.55, core=False)
    flame(p, (-0.15, -0.2, z), 0.55, core=False)
    p.box((0.1, 0.3, 0.07), (0, -0.06, 0.04), NAVY, bevel=0.03, segs=1)
    grip(p, RED_D)
    trigger(p)
    done("m_napalm", p, (0, -0.54, z))


def m_ice():
    p = Part()
    z = 0.2
    Y(p, 0.12, 0.26, -0.18, z, DGREY, bevel=0.05, sides=16, segs=3)               # CO2-Flasche
    Y(p, 0.122, 0.12, 0.02, z, CYAN, sides=16)
    p.cyl(0.04, 0.08, (0, -0.16, z + 0.14), BLACK, sides=10)
    sweep(p, [(0, -0.18, z), (0, -0.28, z - 0.02), (0, -0.36, z - 0.03)], 0.03, BLACK, sides=6)
    lathe(p, [(0.035, 0.0), (0.06, -0.1), (0.11, -0.26), (0.1, -0.27), (0.0, -0.2)], (0, -0.36, z - 0.03), [BLACK, BLACK, DGREY, HOLE], r=rot(-90, 0, 0), sides=14)   # Horn
    for (x, y, zz), rr in (((0.08, -0.6, 0.06), 0.05), ((-0.07, -0.58, 0.07), 0.045), ((0.0, -0.56, -0.08), 0.04)):   # Eiskristalle
        star(p, rr, rr * 0.6, (x, y, z + zz), "CFF6FF", r=rot(0, 0, 90), n=6, inner=0.4, color2=CYAN)
    p.box((0.085, 0.1, 0.16), (0, -0.28, z - 0.17), DGREY, bevel=0.03, segs=1)
    grip(p, NAVY)
    trigger(p)
    done("m_ice", p, (0, -0.63, z - 0.03))


def m_ladder():
    p = Part()
    for sx in (-1, 1):                                                              # Holme
        p.box((0.04, 1.0, 0.06), (sx * 0.12, -0.2, 0.0), RED, bevel=0.015, segs=1)
        p.box((0.045, 0.06, 0.065), (sx * 0.12, -0.66, 0.0), YEL, bevel=0.012, segs=1)
        sweep(p, [(sx * 0.12, -0.7, 0.0), (sx * 0.12, -0.78, 0.04), (sx * 0.12, -0.78, 0.1)], 0.018, GREY, sides=5)   # Haken
    for i in range(6):                                                              # Sprossen
        p.cyl(0.02, 0.24, (0, 0.24 - i * 0.17, 0.0), GREY_L, r=rot(0, 90, 0), sides=8)
    p.box((0.3, 0.05, 0.05), (0, 0.3, 0.0), YEL, bevel=0.015, segs=1)
    done("m_ladder", p, (0, -0.78, 0.05), tilt=30, yaw=-50, pitch=30)


def m_siren():
    p = Part()
    z = 0.15
    lathe(p, [(0.06, 0.12), (0.07, 0.0), (0.09, -0.15), (0.16, -0.38), (0.24, -0.5), (0.22, -0.52), (0.0, -0.4)],
          (0, 0, z), [RED, RED, WHITE, RED, WHITE, HOLE], r=rot(-90, 0, 0), sides=16)   # Schalltrichter
    p.box((0.1, 0.26, 0.12), (0, 0.1, z), DGREY, bevel=0.04, segs=2)
    p.ball(0.06, (0, -0.02, z + 0.12), "3C7CFF", subdiv=2)                           # Blaulicht
    p.cyl(0.05, 0.03, (0, -0.02, z + 0.07), GREY, sides=10)
    for i in range(3):
        sweep(p, arc(0, z, 0.3 + i * 0.07, 60, 120, 6, y=-0.6 - i * 0.04), 0.012, WHITE, sides=4)   # Schallwellen
    grip(p, RED_D)
    trigger(p)
    done("m_siren", p, (0, -0.52, z), tilt=14)


def m_inferno():
    p = Part()
    z = 0.15
    p.box((0.16, 0.42, 0.2), (0, -0.06, z), ORG, bevel=0.06, segs=3)             # Gehäuse
    for i in range(4):                                                              # Kühlrippen
        p.box((0.2, 0.025, 0.14), (0, 0.04 - i * 0.06, z + 0.02), DGREY, bevel=0.008, segs=1)
    Y(p, 0.06, -0.26, -0.44, z, NAVY, sides=12)
    lathe(p, [(0.05, 0.0), (0.14, -0.08), (0.17, -0.18), (0.15, -0.19), (0.0, -0.1)], (0, -0.44, z), [GREY_L, GREY_L, GREY, HOLE], r=rot(-90, 0, 0), sides=16)   # Spiegel
    p.ball(0.06, (0, -0.58, z), "FF5A1F", subdiv=2)                                  # Glutkern
    p.ball(0.035, (0, -0.63, z), YEL_L, subdiv=1)
    p.box((0.085, 0.1, 0.16), (0, -0.24, z - 0.17), DGREY, bevel=0.03, segs=1)
    grip(p, RED_D)
    trigger(p)
    done("m_inferno", p, (0, -0.64, z))


def m_hammer():
    p = Part()
    stripes(p, 0.3, -0.42, 0, 0.045, 8, RED, YEL, sides=10)                        # Stiel
    p.ball(0.06, (0, 0.31, 0), DGREY, subdiv=2)
    p.box((0.22, 0.24, 0.24), (0, -0.56, 0.0), GREY, bevel=0.05, segs=2)          # Kopf
    for sx in (-1, 1):
        p.box((0.23, 0.06, 0.25), (0, -0.56 + sx * 0.09, 0.0), RED, bevel=0.015, segs=1)
        flame(p, (sx * 0.115, -0.56, -0.02), 0.5, core=False)
    done("m_hammer", p, (0, -0.68, 0), tilt=28)


def m_dragon():
    p = Part()
    z = 0.16
    Y(p, 0.11, 0.24, -0.3, z, RED, bevel=0.03, sides=14)                           # Hals
    for y in (0.14, 0.0, -0.14):                                                    # Schuppen
        p.cone(0.04, 0.08, (0, y, z + 0.12), YEL, r=rot(-20, 0, 0), sides=6)
    p.box((0.2, 0.28, 0.17), (0, -0.42, z + 0.02), RED, bevel=0.07, segs=2)       # Kopf
    p.box((0.18, 0.2, 0.06), (0, -0.48, z - 0.08), RED_D, bevel=0.025, segs=1)    # Unterkiefer
    for sx in (-1, 1):
        p.ball(0.04, (sx * 0.08, -0.38, z + 0.11), WHITE, subdiv=2)               # Augen
        p.ball(0.022, (sx * 0.09, -0.41, z + 0.12), BLACK, subdiv=1)
        p.cone(0.03, 0.14, (sx * 0.07, -0.26, z + 0.14), YEL, r=rot(-60, sx * 15, 0), sides=6)   # Hörner
        p.ball(0.02, (sx * 0.05, -0.56, z + 0.06), BLACK, subdiv=1)              # Nüstern
    flame(p, (0, -0.68, z - 0.02), 0.9)
    p.box((0.085, 0.1, 0.16), (0, -0.16, z - 0.17), DGREY, bevel=0.03, segs=1)
    grip(p, RED_D)
    trigger(p)
    done("m_dragon", p, (0, -0.58, z))


ALL = dict(m_axe=m_axe, m_extinguisher=m_extinguisher, m_hose=m_hose, m_molotov=m_molotov, m_halligan=m_halligan, m_napalm=m_napalm,
           m_ice=m_ice, m_ladder=m_ladder, m_siren=m_siren, m_inferno=m_inferno, m_hammer=m_hammer, m_dragon=m_dragon)

if __name__ == "__main__":
    main(ALL)
