"""Paket H (V6): Neles 15 Waffen – Taucherin von der Schrottküste. Petrol, Gelb (Pressluft), Messing, Eis, Muscheln.
Regeln wie in weapons_v4_kit.py (Einheitsraum: hinten y = +0,3, Mündung y = -0,7, Griff im Ursprung, Lauf nach -Y,
Objekte body + Leerobjekt muzzle; Länge `len` aus src/data.gd).
Aufruf: python3 blender/weapons_v6_nele.py [n_harpoon ...]   (ohne Namen: alle)"""
import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from weapons_v4_kit import *

PET, PET_D, PET_L = "1F6E8C", "164E66", "3FA0C0"
SUB, BRASS, BRASS_D = "F2C230", "D9A84A", "A87A2A"
SEA, FOAM = "4FD8FF", "E8FBFF"
CORAL, SHELL = "FF7A6A", "F6D8C0"


def tank(p, y0, y1, z, rad=0.07, col=SUB, x=0.0):
    """Kleine Pressluftflasche entlang Y mit Ventil."""
    Y(p, rad, y0, y1, z, col, sides=14, bevel=0.02, x=x)
    p.cyl(0.02, 0.05, (x, y0 + 0.02, z + rad + 0.01), GREY, sides=8)


def harpoon_tip(p, y, z, col=GREY_L, s=1.0, x=0.0):
    p.cone(0.045 * s, 0.12 * s, (x, y - 0.05 * s, z), col, r=rot(90, 0, 0), sides=8)
    for sx in (-1, 1):                                                   # Widerhaken
        prism(p, [(0, 0), (0.05 * s, 0.05 * s), (0.015 * s, 0.0)], 0.014, (x + sx * 0.03 * s, y + 0.015, z), col, r=rot(0, 0, 90 * sx) @ rot(90, 0, 0))


def n_harpoon():
    p = Part()
    z = 0.12
    p.box((0.1, 0.24, 0.14), (0, 0.18, 0.08), PET_D, bevel=0.05)                    # Schaft
    p.box((0.13, 0.36, 0.16), (0, -0.1, z), PET, bevel=0.06, segs=3)                # Gehäuse
    tank(p, 0.04, -0.3, z - 0.1, 0.055)                                             # Druckluft unten
    Y(p, 0.035, -0.28, -0.66, z, GREY, sides=10)                                    # Führungsrohr
    for sx in (-1, 1):                                                              # Gummizüge
        sweep(p, [(sx * 0.05, -0.28, z + 0.02), (sx * 0.06, -0.48, z + 0.03), (sx * 0.04, -0.6, z + 0.02)], 0.014, "2E3340", sides=5)
    Y(p, 0.014, -0.2, -0.62, z + 0.06, GREY_L, sides=6)                             # Pfeil
    harpoon_tip(p, -0.64, z + 0.06)
    p.box((0.04, 0.1, 0.04), (0, -0.05, z + 0.1), SUB, bevel=0.012, segs=1)
    grip(p, PET_D)
    trigger(p, color=SUB)
    done("n_harpoon", p, (0, -0.7, z + 0.06))


def n_bubble():
    p = Part()
    z = 0.15
    Y(p, 0.12, 0.26, -0.42, z, PET_L, bevel=0.03, sides=16)                         # Rohr
    Y(p, 0.14, -0.38, -0.52, z, SUB, bevel=0.025, sides=16)                          # Trichter
    hole(p, 0.1, -0.52, z, "2A6A80")
    p.ball(0.13, (0, 0.04, z + 0.17), FOAM, subdiv=2)                                # Seifenblasen-Tank
    p.ball(0.07, (0.07, 0.0, z + 0.27), "BFF0FF", subdiv=2)
    for i, (x, y, zz, r) in enumerate(((0.05, -0.62, z + 0.08, 0.06), (-0.04, -0.7, z + 0.14, 0.045), (0.0, -0.58, z + 0.2, 0.035))):
        p.ball(r, (x, y, zz), "D8F8FF", subdiv=2)
    p.box((0.1, 0.3, 0.07), (0, -0.1, z - 0.13), PET_D, bevel=0.03, segs=1)
    grip(p, PET_D)
    trigger(p, color=SUB)
    done("n_bubble", p, (0, -0.52, z))


def n_ice():
    p = Part()
    z = 0.12
    p.box((0.1, 0.22, 0.14), (0, 0.19, 0.08), "D8E8F4", bevel=0.05)
    p.box((0.13, 0.4, 0.16), (0, -0.12, z), PET, bevel=0.06, segs=3)
    for i in range(3):                                                              # Kühlrippen aus Eis
        p.box((0.17, 0.03, 0.11), (0, -0.04 - i * 0.07, z + 0.03), ICE, bevel=0.01, segs=1)
    Y(p, 0.035, -0.3, -0.66, z, GREY_L, sides=10)
    Y(p, 0.018, -0.3, -0.62, z + 0.06, ICE, sides=6)
    p.cone(0.05, 0.16, (0, -0.68, z + 0.06), ICE, r=rot(90, 0, 0), sides=6)        # Eisspitze
    for a in (0, 120, 240):
        p.cone(0.02, 0.08, (0.04 * math.cos(math.radians(a)), -0.6, z + 0.06 + 0.04 * math.sin(math.radians(a))), "FFFFFF", r=rot(90, 0, 0) @ rot(0, a, 0), sides=4)
    grip(p, PET_D)
    trigger(p, color=SEA)
    done("n_ice", p, (0, -0.76, z + 0.06))


def n_shell():
    p = Part()
    Y(p, 0.04, 0.24, -0.1, 0, "D9B47A", sides=10)                                  # Treibholz-Griff
    for sx in (-1, 1):
        sweep(p, [(0, -0.1, 0), (sx * 0.07, -0.2, 0.02), (sx * 0.11, -0.32, 0.06)], 0.032, "D9B47A", sides=8)
        p.ball(0.035, (sx * 0.11, -0.32, 0.06), CORAL, subdiv=1)
    sweep(p, [(-0.11, -0.32, 0.06), (-0.04, -0.4, 0.06), (0.04, -0.4, 0.06), (0.11, -0.32, 0.06)], 0.012, PET, sides=5)
    for i in range(5):                                                              # Muschel im Leder
        a = math.radians(-50 + i * 25)
        p.box((0.035, 0.012, 0.11), (0.05 * math.sin(a), -0.44, 0.06 + 0.05 * math.cos(a) - 0.04), SHELL if i % 2 else "F0B8A0", r=rot(90, 0, 0) @ rot(0, math.degrees(a), 0), bevel=0.008, segs=1)
    for y in (0.16, 0.06):
        ring(p, 0.043, 0.012, y, 0, PET, seg=10, tseg=4)
    done("n_shell", p, (0, -0.48, 0.06), tilt=24, pitch=30)


def n_squid():
    p = Part()
    z = 0.12
    p.ball(0.15, (0, 0.02, z + 0.06), "8C5DF2", scale=(1, 1.3, 1), subdiv=3)       # Tintenfisch-Tank
    for sx in (-1, 1):
        p.ball(0.04, (sx * 0.07, -0.12, z + 0.12), WHITE, subdiv=2)
        p.ball(0.022, (sx * 0.075, -0.155, z + 0.12), "1E2028", subdiv=1)
    for i in range(6):                                                              # Arme um die Düse
        a = math.radians(i * 60)
        sweep(p, [(0.06 * math.cos(a), -0.16, z + 0.06 * math.sin(a)), (0.1 * math.cos(a), -0.3, z + 0.1 * math.sin(a)), (0.07 * math.cos(a), -0.44, z + 0.07 * math.sin(a))], [0.03, 0.022, 0.012], "7A4AE0", sides=6)
    Y(p, 0.04, -0.14, -0.6, z, "2E3340", sides=10)                                   # Düse
    Y(p, 0.055, -0.56, -0.62, z, SUB, sides=10)
    hole(p, 0.03, -0.62, z, "1E1A30")
    grip(p, PET_D)
    trigger(p, color=SUB)
    done("n_squid", p, (0, -0.62, z))


def n_anchor():
    p = Part()
    Y(p, 0.035, 0.12, -0.42, 0, "6F7C96", sides=10)                                 # Schaft
    ring(p, 0.06, 0.016, 0.16, 0, "6F7C96", seg=12, tseg=5)                         # Ring oben
    p.box((0.28, 0.04, 0.04), (0, 0.04, 0), "6F7C96", bevel=0.012, segs=1)           # Stock (quer)
    for sx in (-1, 1):
        sweep(p, [(0, -0.42, 0), (sx * 0.12, -0.38, 0), (sx * 0.2, -0.26, 0)], 0.032, "6F7C96", sides=8)
        p.cone(0.05, 0.1, (sx * 0.22, -0.22, 0), "8A94A8", r=rot(-90, 0, 0) @ rot(0, -sx * 40, 0), sides=6)
    sweep(p, [(0, 0.2, 0), (0.06, 0.3, 0.02), (-0.02, 0.36, 0.0)], 0.012, SUB, sides=5)   # Leine
    done("n_anchor", p, (0, -0.44, 0), tilt=0, yaw=-24, pitch=60)


def n_torpedo():
    p = Part()
    z = 0.13
    p.box((0.2, 0.5, 0.2), (0, -0.12, z), PET_D, bevel=0.06, segs=2)                # Rohrgehäuse
    for sx in (-1, 1):
        Y(p, 0.07, 0.1, -0.58, z, PET, sides=14, x=sx * 0.08)                       # zwei Rohre
        hole(p, 0.055, -0.58, z, "142A36", x=sx * 0.08)
        p.ball(1.0, (sx * 0.08, -0.6, z), SUB, scale=(0.05, 0.06, 0.05), subdiv=2)  # Torpedospitzen
        p.cone(0.03, 0.04, (sx * 0.08, -0.62, z), CORAL, r=rot(90, 0, 0), sides=8)
    p.box((0.05, 0.16, 0.06), (0, -0.2, z + 0.13), SUB, bevel=0.015, segs=1)         # Periskop
    p.box((0.05, 0.05, 0.12), (0, -0.25, z + 0.2), SUB, bevel=0.015, segs=1)
    grip(p, PET_D)
    trigger(p, color=SUB)
    done("n_torpedo", p, (0, -0.62, z))


def n_trident():
    p = Part()
    Y(p, 0.026, 0.3, -0.42, 0, "D9B47A", sides=8)                                   # Stiel
    for y in (0.1, -0.05):
        ring(p, 0.03, 0.01, y, 0, PET, seg=10, tseg=4)
    p.box((0.22, 0.04, 0.04), (0, -0.44, 0), BRASS, bevel=0.012, segs=1)             # Querstück
    for x in (-0.09, 0.0, 0.09):
        Y(p, 0.016, -0.44, -0.62, 0, BRASS, sides=6, x=x)
        p.cone(0.03, 0.09, (x, -0.66, 0), BRASS_D if x else SUB, r=rot(90, 0, 0), sides=6)
    p.ball(0.03, (0, 0.31, 0), CORAL, subdiv=1)
    done("n_trident", p, (0, -0.7, 0), tilt=16, pitch=45)


def n_geyser():
    p = Part()
    z = 0.13
    tank(p, 0.24, -0.04, z + 0.02, 0.09, SUB)                                       # Kessel
    Y(p, 0.05, -0.04, -0.56, z, GREY, sides=12)                                      # Strahlrohr
    for y in (-0.16, -0.32, -0.48):
        ring(p, 0.055, 0.014, y, z, PET, seg=12, tseg=4)
    Y(p, 0.07, -0.54, -0.66, z, BRASS, sides=12, bevel=0.015)
    hole(p, 0.04, -0.66, z, "1A5A70")
    p.cyl(0.05, 0.03, (0, 0.1, z + 0.12), "D54144", sides=10)                        # Ventilrad
    sweep(p, [(0.06, 0.1, z - 0.04), (0.1, -0.02, z - 0.08), (0.04, -0.14, z - 0.03)], 0.02, "2E3340", sides=6)
    grip(p, PET_D)
    trigger(p, color=SUB)
    done("n_geyser", p, (0, -0.68, z))


def n_frostnet():
    p = Part()
    z = 0.15
    Y(p, 0.13, 0.22, -0.4, z, PET, bevel=0.03, sides=16)
    Y(p, 0.15, -0.36, -0.48, z, ICE, bevel=0.02, sides=16)
    hole(p, 0.11, -0.48, z, "2E5468")
    for i in range(4):                                                               # Netzknoten schauen heraus
        a = math.radians(45 + i * 90)
        p.ball(0.03, (0.08 * math.cos(a), -0.5, z + 0.08 * math.sin(a)), "C9F2FF", subdiv=1)
    for i in range(4):
        a = math.radians(i * 90)
        sweep(p, [(0.08 * math.cos(a), -0.5, z + 0.08 * math.sin(a)), (0.08 * math.cos(a + 1.57), -0.5, z + 0.08 * math.sin(a + 1.57))], 0.008, "E8FBFF", sides=4)
    for x in (-0.06, 0.06):                                                          # Eiszapfen
        p.cone(0.025, 0.08, (x, -0.44, z - 0.15), ICE, r=rot(180, 0, 0), sides=5)
    grip(p, PET_D)
    trigger(p, color=SEA)
    done("n_frostnet", p, (0, -0.5, z))


def n_whirl():
    p = Part()
    z = 0.15
    Y(p, 0.11, 0.24, -0.36, z, PET_D, bevel=0.03, sides=16)
    p.ball(0.15, (0, -0.48, z + 0.02), "6FC8FF", scale=(1, 1, 1.15), subdiv=2)      # Flasche voll Meer
    p.cyl(0.05, 0.08, (0, -0.48, z + 0.2), SHELL, sides=10)                          # Korken
    sweep(p, [(0.12 * math.cos(a * 0.5), -0.48 + 0.12 * math.sin(a * 0.5), z - 0.06 + a * 0.012) for a in range(0, 25)], 0.012, FOAM, sides=4)   # Strudel
    grip(p, PET_D)
    trigger(p, color=SUB)
    done("n_whirl", p, (0, -0.6, z))


def n_jelly():
    p = Part()
    p.ball(0.2, (0, 0, 0.08), "FF8AD8", scale=(1, 1, 0.75), subdiv=3)               # Quallenschirm
    p.ball(0.14, (0, 0, 0.1), "FFC8F0", scale=(1, 1, 0.7), subdiv=2)
    p.cyl(0.19, 0.03, (0, 0, -0.04), "E060B8", sides=16)
    for i in range(6):
        a = math.radians(i * 60 + 30)
        sweep(p, [(0.12 * math.cos(a), 0.12 * math.sin(a), -0.04), (0.14 * math.cos(a + 0.4), 0.14 * math.sin(a + 0.4), -0.16), (0.1 * math.cos(a + 0.8), 0.1 * math.sin(a + 0.8), -0.28)], [0.02, 0.016, 0.01], "FFB0E8", sides=5)
    p.ball(0.04, (0, -0.14, 0.12), SUB, subdiv=2)                                   # Blitz-Licht
    done("n_jelly", p, (0, -0.2, 0.08), tilt=0, yaw=-30, pitch=30)


def n_icebreaker():
    p = Part()
    Y(p, 0.03, 0.3, -0.5, 0, "6B4A2E", sides=8)                                      # Stiel
    for y in (0.22, 0.12):
        ring(p, 0.034, 0.012, y, 0, PET, seg=10, tseg=4)
    p.box((0.08, 0.1, 0.1), (0, -0.52, 0), "6F7C96", bevel=0.02, segs=1)             # Kopf
    sweep(p, [(0, -0.52, 0.04), (0, -0.56, 0.18), (0, -0.66, 0.28)], [0.04, 0.03, 0.012], GREY_L, sides=6)   # Hacke
    p.box((0.16, 0.06, 0.06), (0, -0.5, -0.08), "6F7C96", bevel=0.015, segs=1)       # Breitseite
    for x in (-0.05, 0.03):
        p.cone(0.035, 0.12, (x, -0.6, 0.06), ICE, r=rot(-30, 0, 0), sides=5)        # Eiskristalle
    p.cone(0.04, 0.16, (0.0, -0.52, -0.16), ICE, r=rot(180, 0, 0), sides=5)
    done("n_icebreaker", p, (0, -0.66, 0.2), tilt=10, pitch=40)


def n_kraken():
    p = Part()
    lathe(p, [(0.0, 0.0), (0.05, 0.02), (0.1, 0.12), (0.14, 0.3), (0.1, 0.46), (0.06, 0.6), (0.0, 0.64)], (0, 0.3, 0.06), [SHELL, SHELL, "F0B8A0", SHELL, "F0B8A0", SHELL], r=rot(90, 0, 0), sides=12)   # Muschelhorn
    for i in range(5):
        y = 0.22 - i * 0.12
        ring(p, 0.11 - abs(i - 2) * 0.02, 0.012, y, 0.06, CORAL, seg=12, tseg=4)
    p.ball(0.06, (0, -0.36, 0.06), "6FC8FF", subdiv=2)                              # Wasserkugel
    for i in range(3):
        a = math.radians(i * 120)
        sweep(p, [(0, -0.36, 0.06), (0.1 * math.cos(a), -0.46, 0.06 + 0.1 * math.sin(a)), (0.05 * math.cos(a), -0.58, 0.06 + 0.05 * math.sin(a))], [0.025, 0.018, 0.01], PET_L, sides=6)
    done("n_kraken", p, (0, -0.6, 0.06), tilt=18)


def n_tsunami():
    p = Part()
    z = 0.15
    p.box((0.22, 0.5, 0.22), (0, -0.1, z), PET_D, bevel=0.07, segs=2)
    Y(p, 0.13, -0.3, -0.6, z, PET, sides=16)                                         # Mündung, weit
    Y(p, 0.16, -0.56, -0.68, z, BRASS, sides=16, bevel=0.02)
    hole(p, 0.12, -0.68, z, "1A5A70")
    for i in range(4):                                                               # Wellenkamm oben
        p.ball(0.06, (0, -0.32 + i * 0.12, z + 0.14 + 0.03 * (i % 2)), FOAM, scale=(1.4, 1, 0.7), subdiv=2)
    tank(p, 0.22, -0.1, z - 0.15, 0.06, SUB)
    for sx in (-1, 1):
        p.box((0.03, 0.26, 0.08), (sx * 0.12, -0.12, z), SEA, bevel=0.01, segs=1)      # Ladeanzeige
    grip(p, PET_D)
    trigger(p, color=SUB)
    done("n_tsunami", p, (0, -0.7, z))


TABLE = {k: globals()[k] for k in ["n_harpoon", "n_bubble", "n_ice", "n_shell", "n_squid", "n_anchor", "n_torpedo", "n_trident", "n_geyser",
                                    "n_frostnet", "n_whirl", "n_jelly", "n_icebreaker", "n_kraken", "n_tsunami"]}

if __name__ == "__main__":
    main(TABLE)
