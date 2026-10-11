"""V4 Waffen-Arsenal – Bruno (Bauarbeiter): Baustellenorange, Gelb-Schwarz, Stahl, Holz, Ziegel.
Aufruf: python3 blender/weapons_v4_bruno.py [b_shovel ...]"""
import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from weapons_v4_kit import *


def b_shovel():
    p = Part()
    Y(p, 0.04, 0.22, -0.4, 0, WOOD, sides=10)                                      # Stiel
    p.torus(0.07, 0.022, (0, 0.3, 0), ORG, r=rot(0, 90, 0), seg=12, tseg=5)       # D-Griff
    p.box((0.16, 0.04, 0.04), (0, 0.24, 0), ORG, bevel=0.012, segs=1)
    Y(p, 0.05, -0.36, -0.44, 0, GREY, sides=10)                                    # Tülle
    blade(p, [(-0.14, 0.0), (0.14, 0.0), (0.15, 0.22), (0.0, 0.3), (-0.15, 0.22)], 0.03, (0, -0.42, 0.0), GREY_L, r=rot(90, 0, 0))   # Blatt
    p.box((0.2, 0.06, 0.04), (0, -0.47, 0.02), GREY, bevel=0.01, segs=1)
    done("b_shovel", p, (0, -0.74, 0), tilt=20, pitch=52)


def b_hammer():
    p = Part()
    Y(p, 0.045, 0.3, -0.44, 0, WOOD, sides=10)
    for y in (0.26, 0.18, 0.1):
        ring(p, 0.048, 0.012, y, 0, BLACK, seg=10, tseg=4)
    p.box((0.32, 0.2, 0.2), (0, -0.56, 0.0), "5A678F", bevel=0.04, segs=2)        # Kopf quer
    p.box((0.322, 0.06, 0.202), (0, -0.56, 0.0), ORG, bevel=0.012, segs=1)
    for sx in (-1, 1):
        p.box((0.04, 0.21, 0.21), (sx * 0.17, -0.56, 0.0), GREY_L, bevel=0.02, segs=1)
    done("b_hammer", p, (0, -0.66, 0), tilt=28, yaw=-40)


def b_rivet():
    p = Part()
    z = 0.15
    p.box((0.16, 0.36, 0.22), (0, -0.04, z), YEL, bevel=0.07, segs=3)             # Gehäuse
    p.box((0.166, 0.14, 0.05), (0, -0.04, z + 0.07), BLACK, bevel=0.015, segs=1)
    for i in range(4):
        p.box((0.168, 0.02, 0.048), (0, -0.08 + i * 0.03, z + 0.07), YEL, bevel=0.005, segs=1)
    Y(p, 0.06, -0.22, -0.52, z, GREY, sides=12)
    Y(p, 0.075, -0.5, -0.6, z, DGREY, bevel=0.02, sides=12, segs=1)
    p.ball(0.045, (0, -0.63, z), "FF8A1F", subdiv=2)                                 # glühende Niete
    sweep(p, [(0, 0.14, z - 0.06), (0, 0.24, z - 0.14), (0.08, 0.3, z - 0.26), (0.18, 0.26, z - 0.36)], 0.03, "3C7CFF", sides=6)   # Luftschlauch
    p.box((0.085, 0.1, 0.16), (0, -0.3, z - 0.18), BLACK, bevel=0.03, segs=1)
    grip(p, BLACK)
    trigger(p, color=ORG)
    done("b_rivet", p, (0, -0.64, z))


def b_drill():
    p = Part()
    z = 0.12
    p.box((0.17, 0.34, 0.22), (0, 0.04, z), YEL, bevel=0.07, segs=3)              # Motor
    for i in range(3):
        p.box((0.18, 0.02, 0.12), (0, 0.12 - i * 0.04, z + 0.02), BLACK, bevel=0.005, segs=1)
    Y(p, 0.08, -0.13, -0.24, z, BLACK, sides=12)                                    # Futter
    for i in range(5):                                                              # Bohrer (Wendel)
        y0 = -0.24 - i * 0.09
        Y(p, 0.055 - i * 0.008, y0, y0 - 0.06, z, GREY_L, sides=8)
        Y(p, 0.04 - i * 0.006, y0 - 0.06, y0 - 0.09, z, GREY, sides=8)
    Y(p, 0.02, -0.69, -0.74, z, GREY_L, r2=0.0, sides=8)
    p.box((0.22, 0.05, 0.05), (0.0, -0.08, z - 0.06), BLACK, r=rot(0, 0, 0), bevel=0.02, segs=1)   # Seitengriff
    p.ball(0.04, (0.12, -0.08, z - 0.06), ORG, subdiv=1)
    grip(p, BLACK)
    trigger(p, color=ORG)
    done("b_drill", p, (0, -0.74, z))


def b_brick():
    p = Part()
    Y(p, 0.045, 0.24, -0.1, 0, WOOD, sides=10)                                     # Griff
    sweep(p, [(0, -0.1, 0), (-0.06, -0.2, 0.02), (-0.13, -0.32, 0.06)], 0.035, WOOD, sides=8)   # Gabel
    sweep(p, [(0, -0.1, 0), (0.06, -0.2, 0.02), (0.13, -0.32, 0.06)], 0.035, WOOD, sides=8)
    for sx in (-1, 1):
        p.ball(0.04, (sx * 0.13, -0.32, 0.06), ORG, subdiv=1)
    sweep(p, [(-0.13, -0.32, 0.06), (-0.08, -0.42, 0.06), (0.08, -0.42, 0.06), (0.13, -0.32, 0.06)], 0.014, "C93F3F", sides=5)   # Gummi
    p.box((0.2, 0.1, 0.09), (0, -0.46, 0.08), "C2502E", bevel=0.015, segs=1)      # Ziegel
    for x in (-0.05, 0.05):
        p.box((0.06, 0.102, 0.03), (x, -0.46, 0.13), "E07A52", bevel=0.005, segs=1)
    done("b_brick", p, (0, -0.5, 0.08), tilt=24, pitch=30)


def b_wrecker():
    p = Part()
    Y(p, 0.05, 0.3, -0.3, 0, ORG, sides=10)                                         # Arm
    p.box((0.1, 0.36, 0.1), (0, -0.2, 0.06), YEL, bevel=0.03, segs=1)
    Y(p, 0.035, -0.12, -0.36, 0.14, GREY, sides=8)                                  # Hydraulik
    p.cyl(0.05, 0.14, (0, -0.4, 0.06), BLACK, r=rot(0, 90, 0), sides=10)           # Gelenk
    p.box((0.36, 0.26, 0.035), (0, -0.56, -0.14), YEL, bevel=0.012, segs=1)      # Schaufel: Boden
    p.box((0.36, 0.04, 0.26), (0, -0.43, -0.02), YEL, r=rot(-12, 0, 0), bevel=0.015, segs=1)   # Rückwand
    for sx in (-1, 1):
        p.box((0.035, 0.26, 0.2), (sx * 0.17, -0.55, -0.05), ORG, bevel=0.01, segs=1)   # Seiten
    for x in (-0.12, -0.04, 0.04, 0.12):                                            # Zähne
        p.cone(0.035, 0.12, (x, -0.72, -0.14), GREY_L, r=rot(90, 0, 0), sides=6)
    done("b_wrecker", p, (0, -0.7, -0.05), tilt=26, yaw=-46)


def b_plate():
    p = Part()
    Y(p, 0.035, 0.3, -0.4, 0.05, GREY, sides=8)                                     # Stange
    p.box((0.3, 0.05, 0.05), (0, 0.28, 0.05), BLACK, bevel=0.02, segs=1)           # Querbügel
    for sx in (-1, 1):
        p.ball(0.04, (sx * 0.15, 0.28, 0.05), ORG, subdiv=1)
    p.box((0.18, 0.16, 0.16), (0, -0.4, 0.08), ORG, bevel=0.04, segs=2)            # Motor
    p.box((0.185, 0.04, 0.12), (0, -0.4, 0.09), BLACK, bevel=0.01, segs=1)
    p.box((0.32, 0.32, 0.05), (0, -0.6, -0.04), GREY, bevel=0.015, segs=1)         # Stampfplatte
    for sx in (-1, 1):
        p.box((0.05, 0.3, 0.06), (sx * 0.14, -0.6, -0.0), YEL, bevel=0.01, segs=1)
    done("b_plate", p, (0, -0.6, -0.06), tilt=20, pitch=30)


def b_crane():
    p = Part()
    p.box((0.16, 0.18, 0.16), (0, 0.15, 0), YEL, bevel=0.03, segs=2)              # Hakenblock
    for i in range(3):
        p.box((0.165, 0.035, 0.165), (0, 0.09 + i * 0.06, 0), BLACK, r=rot(0, 0, 0), bevel=0.006, segs=1)
    for i in range(3):                                                              # Kette
        p.torus(0.045, 0.016, (0, 0.0 - i * 0.07, 0), GREY_L, r=rot(0, 90, 0) if i % 2 == 0 else None, seg=10, tseg=4)
    Y(p, 0.045, -0.2, -0.3, 0, GREY, sides=10)
    sweep(p, [(0, -0.3, 0), (0, -0.48, 0.0), (0, -0.6, -0.06), (0, -0.62, -0.16), (0, -0.54, -0.24), (0, -0.44, -0.2), (0, -0.42, -0.12)],
          [0.05, 0.05, 0.045, 0.04, 0.035, 0.03, 0.02], "E8B100", sides=8)        # Haken
    p.cone(0.03, 0.06, (0, -0.42, -0.08), GREY_L, sides=6)
    done("b_crane", p, (0, -0.62, -0.1), tilt=10, yaw=-70, pitch=18)


def b_turret():
    p = Part()
    Y(p, 0.06, -0.05, -0.5, 0.18, DGREY, sides=12)                                 # Kanonenrohr
    Y(p, 0.08, -0.44, -0.54, 0.18, ORG, bevel=0.02, sides=12, segs=1)
    hole(p, 0.045, -0.54, 0.18)
    p.box((0.24, 0.24, 0.14), (0, -0.05, 0.12), ORG, bevel=0.04, segs=2)          # Lafette
    for sx in (-1, 1):
        p.torus(0.08, 0.03, (sx * 0.15, -0.08, 0.06), BLACK, r=rot(0, 90, 0), seg=12, tseg=5)   # Räder
        p.cyl(0.05, 0.03, (sx * 0.15, -0.08, 0.06), YEL, r=rot(0, 90, 0), sides=10)
    p.box((0.2, 0.05, 0.03), (0, 0.06, 0.2), YEL, bevel=0.01, segs=1)
    for i in range(3):
        p.box((0.05, 0.052, 0.032), (-0.075 + i * 0.075, 0.06, 0.2), BLACK, bevel=0.004, segs=1)
    p.box((0.05, 0.12, 0.05), (0, 0.06, 0.0), BLACK, bevel=0.02, segs=1)
    done("b_turret", p, (0, -0.54, 0.18), tilt=10, pitch=26)


def b_tar():
    p = Part()
    z = 0.18
    lathe(p, [(0.0, 0.24), (0.1, 0.22), (0.15, 0.1), (0.15, -0.1), (0.12, -0.18), (0.0, -0.2)], (0, 0.04, z), [BLACK, BLACK, DGREY, BLACK, BLACK], r=rot(-90, 0, 0), sides=16)   # Kessel
    ring(p, 0.152, 0.02, 0.04, z, YEL, seg=16, tseg=5)
    p.cyl(0.02, 0.16, (0, 0.04, z + 0.22), GREY, sides=6)                           # Schornstein
    p.ball(0.05, (0, 0.04, z + 0.32), "5E5868", subdiv=1)
    Y(p, 0.045, -0.16, -0.52, z - 0.04, GREY, sides=10)                             # Spritzrohr
    Y(p, 0.06, -0.5, -0.6, z - 0.04, ORG, bevel=0.015, sides=10, segs=1)
    p.ball(0.045, (0, -0.64, z - 0.09), BLACK, scale=(1, 1, 1.4), subdiv=1)       # Teertropfen
    p.box((0.2, 0.5, 0.05), (0, -0.1, 0.0), YEL, bevel=0.015, segs=1)             # Rahmen
    grip(p, BLACK)
    trigger(p, color=ORG)
    done("b_tar", p, (0, -0.6, z - 0.04))


def b_pile():
    p = Part()
    Y(p, 0.04, 0.3, -0.24, 0.0, GREY, sides=8)
    for sx in (-1, 1):                                                              # Griffe
        sweep(p, [(sx * 0.0, 0.1, 0.0), (sx * 0.12, 0.1, 0.04), (sx * 0.16, 0.18, 0.06)], 0.025, BLACK, sides=6)
    stripes(p, -0.22, -0.66, 0.0, 0.14, 6, YEL, BLACK, sides=16)                    # Rammbär
    Y(p, 0.15, -0.64, -0.7, 0.0, GREY, bevel=0.02, sides=16, segs=1)
    p.cyl(0.05, 0.04, (0, -0.44, 0.14), ORG, sides=10)
    done("b_pile", p, (0, -0.7, 0), tilt=24)


def b_demolition():
    p = Part()
    z = 0.2
    Y(p, 0.13, 0.12, -0.56, z, "5A678F", bevel=0.03, sides=16)                     # Rohr
    stripes(p, -0.42, -0.62, z, 0.15, 4, YEL, BLACK, sides=16)
    hole(p, 0.1, -0.62, z)
    for i, x in enumerate((-0.08, 0.0, 0.08)):                                       # Sprengstangen hinten
        Y(p, 0.045, 0.32, 0.06, z + 0.16, RED, sides=10, x=x)
        sweep(p, [(x, 0.33, z + 0.16), (x, 0.38, z + 0.22), (x * 1.5, 0.4, z + 0.28)], 0.008, WHITE, sides=4)
    p.box((0.26, 0.08, 0.06), (0, 0.2, z + 0.16), BLACK, bevel=0.01, segs=1)
    p.box((0.12, 0.5, 0.08), (0, -0.12, 0.04), DGREY, bevel=0.03, segs=1)
    p.box((0.085, 0.1, 0.16), (0, -0.3, -0.04), BLACK, bevel=0.035, segs=1)
    grip(p, BLACK)
    trigger(p, color=RED)
    done("b_demolition", p, (0, -0.62, z))


ALL = dict(b_shovel=b_shovel, b_hammer=b_hammer, b_rivet=b_rivet, b_drill=b_drill, b_brick=b_brick, b_wrecker=b_wrecker,
           b_plate=b_plate, b_crane=b_crane, b_turret=b_turret, b_tar=b_tar, b_pile=b_pile, b_demolition=b_demolition)

if __name__ == "__main__":
    main(ALL)
