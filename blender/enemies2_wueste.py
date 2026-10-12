"""Paket G2 – neue Arten der Staubebene (Wüstenmonster und Schrottvieh): Rostmaulwurf (Tunnelgräber), Schrott-Waschbär
(Dieb), Radkappen-Schildkröte (Schildträger) und der Miniboss Schrottskorpion. Abläufe aus enemies2_kit.py.
Aufruf:  python3 blender/enemies2_wueste.py [art ...] [--notafel]"""
import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from enemies2_kit import *
from enemies_wueste import RUST, RUST_D, RUST_L, TEAL, TEAL_D, YEL, RED, CHROME, CHROME_D, SAND, SAND_D, TIRE, INK, WHITE


# ================================================================= Rostmaulwurf (Tunnelgräber)
def wueste_maulwurf():
    rig = Rig("wueste_maulwurf", role="digger")
    FUR, FUR_D, PINK = "7A6A5E", "5A4C42", "F0A8A0"
    rig.node("hips", pivot=(0, 0, 0.45))
    p = Part()                                                                                       # birnenförmiger Leib mit Lederschürze
    lathe(p, [(0.3, 0.35, FUR_D), (0.42, 0.55, FUR), (0.44, 0.85, FUR), (0.36, 1.1, FUR), (0.2, 1.25, FUR_D)], sides=10)
    p.box((0.5, 0.06, 0.5), (0, -0.4, 0.72), "8A5A32", r=rot(-6, 0, 0), bevel=0.04, segs=1)
    for (x, z) in ((-0.12, 0.85), (0.14, 0.62)):
        p.box((0.1, 0.04, 0.12), (x, -0.44, z), CHROME_D, bevel=0.0)                                # Werkzeug in der Schürze
    rig.add("body", p, parent="hips", pivot=(0, 0, 0.45))
    p = Part()                                                                                       # Kopf mit Bohrer-Nase und Schweißerbrille
    p.ball(0.28, (0, -0.12, 1.32), FUR, scale=(1, 1.05, 0.9), subdiv=2)
    lathe(p, [(0.14, 0.0, CHROME_D), (0.12, 0.12, CHROME), (0.08, 0.24, CHROME_D), (0.0, 0.36, CHROME)], sides=8, loc=(0, -0.38, 1.28), r=rot(90, 0, 0))
    for k in range(3):
        p.torus(0.11 - 0.025 * k, 0.018, (0, -0.42 - 0.08 * k, 1.28), YEL, r=rot(90, 0, 0), seg=8, tseg=3)
    p.box((0.46, 0.06, 0.08), (0, -0.3, 1.46), TIRE, bevel=0.02, segs=1)
    for s in (-1, 1):
        p.cyl(0.08, 0.06, (0.11 * s, -0.33, 1.46), "4AC8E8", r=rot(90, 0, 0), sides=8)
        p.ball(0.07, (0.24 * s, 0.0, 1.5), PINK, scale=(1, 0.5, 1), subdiv=1)                        # Ohren
    rig.add("head", p, parent="body", pivot=(0, 0, 1.15))
    p = Part()
    for s in (-1, 1):
        p.ball(0.035, (0.11 * s, -0.37, 1.46), WHITE, subdiv=1)
    rig.add("glow", p, parent="head", pivot=(0, -0.37, 1.46), glow=True)
    for s, nm in ((1, "arm_l"), (-1, "arm_r")):                                                     # breite Grabschaufeln
        p = Part()
        capsule(p, (0.38 * s, -0.05, 0.95), (0.5 * s, -0.3, 0.7), 0.08, 0.07, FUR, sides=5)
        p.box((0.3, 0.06, 0.26), (0.55 * s, -0.36, 0.62), PINK, r=rot(20, 0, 20 * s), bevel=0.03, segs=1)
        for k in range(3):
            p.cone(0.035, 0.12, (0.47 * s + 0.08 * k * s, -0.42, 0.5), WHITE, r=rot(170, 0, 0), sides=4)
        rig.add(nm, p, parent="body", pivot=(0.38 * s, -0.05, 0.95))
    for s, nm in ((1, "leg_l"), (-1, "leg_r")):
        p = Part()
        capsule(p, (0.18 * s, 0, 0.42), (0.2 * s, -0.02, 0.08), 0.08, 0.06, FUR_D, sides=5)
        p.ball(0.1, (0.2 * s, -0.08, 0.06), PINK, scale=(1, 1.5, 0.5), subdiv=1)
        rig.add(nm, p, parent="hips", pivot=(0.18 * s, 0, 0.45))
    p = Part()                                                                                       # Ladung auf dem Rücken: Grubenlampe
    p.cyl(0.12, 0.2, (0, 0.38, 1.0), CHROME_D, r=rot(80, 0, 0), sides=8)
    rig.add("prop", p, parent="body", pivot=(0, 0.35, 1.0))
    mound(rig, 0.55, SAND_D, RUST_D)
    biped(rig, 0.45, 1.6, 2.6, "digger", walk_n=18, leg_swing=34)
    rig.finish(icon_yaw=-24, icon_pitch=12)


# ================================================================= Schrott-Waschbär (Dieb)
def wueste_waschbaer():
    rig = Rig("wueste_waschbaer", role="thief")
    G1, G2, G3 = "8A8E96", "5E626A", "D8DAE0"
    rig.node("hips", pivot=(0, 0, 0.5))
    p = Part()
    lathe(p, [(0.22, 0.42, G2), (0.3, 0.55, G1), (0.3, 0.8, G1), (0.24, 0.98, G1), (0.14, 1.05, G2)], sides=10, sy=0.9)
    p.ball(0.22, (0, -0.16, 0.72), G3, scale=(1, 0.6, 1.2), subdiv=1)                                # heller Bauch
    rig.add("body", p, parent="hips", pivot=(0, 0, 0.5))
    p = Part()                                                                                       # Kopf mit Räubermaske
    p.ball(0.25, (0, -0.04, 1.25), G1, scale=(1.1, 1, 0.9), subdiv=2)
    lathe(p, [(0.14, 0.0, G3), (0.08, 0.14, G3), (0.03, 0.2, INK)], sides=7, loc=(0, -0.24, 1.2), r=rot(90, 0, 0))
    p.box((0.5, 0.06, 0.12), (0, -0.25, 1.3), INK, r=rot(-8, 0, 0), bevel=0.03, segs=1)
    for s in (-1, 1):
        p.cone(0.09, 0.18, (0.17 * s, 0.0, 1.5), G2, r=rot(0, 16 * s, 0), sides=4)
        p.ball(0.04, (0.17 * s, -0.06, 1.48), G3, subdiv=1)
    rig.add("head", p, parent="body", pivot=(0, 0, 1.05))
    p = Part()
    for s in (-1, 1):
        p.ball(0.04, (0.1 * s, -0.29, 1.31), "FFE04A", subdiv=1)
    rig.add("glow", p, parent="head", pivot=(0, -0.29, 1.31), glow=True)
    p = Part()                                                                                       # linker Arm
    capsule(p, (0.26, 0, 0.92), (0.38, -0.15, 0.65), 0.06, 0.05, G1, sides=5)
    p.ball(0.06, (0.4, -0.18, 0.62), INK, subdiv=1)
    rig.add("arm_l", p, parent="body", pivot=(0.26, 0, 0.92))
    p = Part()                                                                                       # rechter Arm mit Schraubenschlüssel
    capsule(p, (-0.26, 0, 0.92), (-0.38, -0.2, 0.7), 0.06, 0.05, G1, sides=5)
    p.ball(0.06, (-0.4, -0.22, 0.67), INK, subdiv=1)
    p.box((0.06, 0.06, 0.5), (-0.4, -0.3, 0.85), CHROME, r=rot(-20, 0, 0), bevel=0.02, segs=1)
    p.torus(0.07, 0.025, (-0.4, -0.38, 1.08), CHROME, r=rot(70, 0, 0), seg=8, tseg=3)
    rig.add("arm_r", p, parent="body", pivot=(-0.26, 0, 0.92))
    for s, nm in ((1, "leg_l"), (-1, "leg_r")):
        p = Part()
        capsule(p, (0.13 * s, 0, 0.45), (0.15 * s, 0, 0.08), 0.06, 0.05, G2, sides=5)
        p.ball(0.08, (0.15 * s, -0.06, 0.05), INK, scale=(1, 1.4, 0.5), subdiv=1)
        rig.add(nm, p, parent="hips", pivot=(0.13 * s, 0, 0.5))
    p = Part()                                                                                       # Ringelschwanz
    lathe(p, [(0.1, 0.0, G2), (0.12, 0.12, INK), (0.12, 0.24, G2), (0.1, 0.36, INK), (0.07, 0.48, G2), (0.0, 0.56, INK)], sides=7, loc=(0, 0.25, 0.55), r=rot(-120, 0, 0))
    rig.add("tail", p, parent="hips", pivot=(0, 0.22, 0.55))
    p = Part()                                                                                       # Rucksack voller Beute
    p.box((0.4, 0.26, 0.42), (0, 0.32, 0.85), "C8A46A", bevel=0.06, segs=1)
    p.ball(0.08, (0.1, 0.32, 1.12), YEL, subdiv=1)
    p.cyl(0.05, 0.2, (-0.1, 0.32, 1.12), RUST, sides=6)
    rig.add("prop", p, parent="body", pivot=(0, 0.3, 0.85))
    biped(rig, 0.5, 1.55, 3.8, "thief", walk_n=15, leg_swing=36, arm_swing=26, attack="swing")
    rig.finish(icon_yaw=-24, icon_pitch=12)


# ================================================================= Radkappen-Schildkröte (Schildträger)
def wueste_radkappe():
    rig = Rig("wueste_radkappe", role="shield")
    SK, SK_D = "8AB04A", "6A8A36"
    p = Part()                                                                                       # Panzer aus Blechplatten mit Nieten
    p.ball(0.62, (0, 0.1, 0.62), RUST, scale=(1, 1.15, 0.75), subdiv=2)
    lathe(p, [(0.66, 0.32, RUST_D), (0.7, 0.42, RUST_D), (0.62, 0.48, RUST)], sides=12, loc=(0, 0.1, 0), sy=1.15, cap=False)
    for k in range(6):
        a = k * math.tau / 6
        p.ball(0.06, (0.4 * math.cos(a), 0.1 + 0.48 * math.sin(a), 0.94), CHROME_D, subdiv=1)
    p.box((0.4, 0.04, 0.3), (0, 0.1, 1.06), TEAL, r=rot(0, 0, 10), bevel=0.04, segs=1)               # aufgeschweißtes Blech
    rig.add("body", p, pivot=(0, 0, 0.55))
    p = Part()                                                                                       # Kopf (zieht sich beim Blocken zurück)
    p.ball(0.2, (0, -0.68, 0.62), SK, scale=(1, 1.15, 0.9), subdiv=2)
    p.box((0.26, 0.05, 0.03), (0, -0.88, 0.56), "4A2A2A", bevel=0.0)
    rig.add("head", p, parent="body", pivot=(0, -0.55, 0.6))
    p = Part()
    for s in (-1, 1):
        p.ball(0.045, (0.09 * s, -0.84, 0.7), WHITE, subdiv=1)
    rig.add("glow", p, parent="head", pivot=(0, -0.84, 0.7))
    p = Part()                                                                                       # Radkappe als Schild vor dem Kopf
    m = T(0, -1.0, 0.62) @ rot(90, 0, 0)
    lathe(p, [(0.46, 0.0, CHROME_D), (0.48, 0.04, CHROME), (0.4, 0.08, CHROME), (0.18, 0.12, CHROME_D), (0.0, 0.14, CHROME)], sides=14, r=m)
    for k in range(5):
        a = k * math.tau / 5
        p.box((0.06, 0.03, 0.16), tuple(m @ Vector((0.28 * math.cos(a), 0.28 * math.sin(a), 0.1))), CHROME_D, r=rot(90, 0, 0) @ rot(0, 0, math.degrees(a) + 90), bevel=0.0)
    rig.add("shield", p, parent="body", pivot=(0, -0.95, 0.62))
    legs = []
    for (nm, x, y, ph, s) in (("leg_fl", 0.45, -0.35, 0.0, 1), ("leg_fr", -0.45, -0.35, 0.5, -1), ("leg_bl", 0.45, 0.55, 0.5, 1), ("leg_br", -0.45, 0.55, 0.0, -1)):
        p = Part()
        capsule(p, (x, y, 0.45), (x * 1.15, y, 0.08), 0.12, 0.11, SK_D, sides=6)
        rig.add(nm, p, parent="body", pivot=(x, y, 0.45))
        legs.append((nm, ph, s))
    p = Part()
    p.cone(0.08, 0.25, (0, 0.85, 0.42), SK_D, r=rot(-100, 0, 0), sides=5)
    rig.add("tail", p, parent="body", pivot=(0, 0.75, 0.42))
    def sp(name, c, rig, rest):
        if name == "block":
            K(c, rig, 3, head=dict(loc=(0, 0.25, -0.05), scale=0.7), body=dict(loc=(0, 0, -0.12), rot=(6, 0, 0)), _i="LINEAR")
    quad(rig, legs, 0.55, 1.15, 1.6, "shield", walk_n=24, leg_swing=26, special=sp)
    rig.finish(icon_yaw=-26, icon_pitch=18)


# ================================================================= Schrottskorpion (Miniboss)
def wueste_skorpion():
    rig = Rig("wueste_skorpion", role="miniboss")
    p = Part()                                                                                       # Leib: Motorhaube und Kühlergrill
    p.box((1.5, 2.2, 0.7), (0, 0.2, 0.95), RED, bevel=0.22, segs=2)
    p.box((1.2, 0.1, 0.4), (0, -0.92, 0.9), CHROME, bevel=0.04, segs=1)
    for k in range(5):
        p.box((0.06, 0.04, 0.32), (-0.48 + k * 0.24, -0.98, 0.9), CHROME_D, bevel=0.0)
    for s in (-1, 1):
        p.cyl(0.15, 0.08, (0.5 * s, -0.95, 1.12), "FFF2B0", r=rot(90, 0, 0), sides=10)               # Scheinwerfer
    p.box((1.3, 1.1, 0.12), (0, 0.4, 1.33), RUST, bevel=0.05, segs=1)
    rig.add("body", p, pivot=(0, 0, 0.9))
    p = Part()
    for s in (-1, 1):
        p.ball(0.1, (0.5 * s, -1.0, 1.12), "FFF8C0", subdiv=1)
    rig.add("glow", p, parent="body", pivot=(0, -1.0, 1.12), glow=True)
    p = Part()                                                                                       # Kopf mit Zangen-Mundwerkzeug
    p.box((0.7, 0.4, 0.4), (0, -1.2, 0.78), RUST_D, bevel=0.1, segs=1)
    rig.add("head", p, parent="body", pivot=(0, -1.0, 0.8))
    for s, nm in ((1, "arm_l"), (-1, "arm_r")):                                                     # Scheren aus Baggerschaufeln
        p = Part()
        capsule(p, (0.65 * s, -0.7, 0.9), (1.1 * s, -1.4, 0.95), 0.14, 0.12, RUST_D, sides=6)
        p.box((0.5, 0.6, 0.3), (1.15 * s, -1.75, 0.95), YEL, r=rot(0, 0, 20 * s), bevel=0.06, segs=1)
        p.box((0.16, 0.5, 0.16), (1.35 * s, -2.05, 1.0), YEL, r=rot(0, 0, -15 * s), bevel=0.04, segs=1)
        p.box((0.16, 0.5, 0.16), (0.95 * s, -2.05, 1.0), YEL, r=rot(0, 0, 15 * s), bevel=0.04, segs=1)
        rig.add(nm, p, parent="body", pivot=(0.65 * s, -0.7, 0.9))
    p = Part()                                                                                       # Schwanz aus Auspuffrohren mit Zapfpistole
    pts = [(0, 1.25, 1.1), (0, 1.9, 1.6), (0, 2.1, 2.4), (0, 1.8, 3.1), (0, 1.2, 3.35)]
    for i in range(len(pts) - 1):
        capsule(p, pts[i], pts[i + 1], 0.2 - 0.025 * i, 0.18 - 0.025 * i, CHROME_D if i % 2 else RUST, sides=7)
    p.box((0.22, 0.4, 0.3), (0, 0.95, 3.25), TEAL, r=rot(30, 0, 0), bevel=0.05, segs=1)
    p.cone(0.08, 0.45, (0, 0.68, 3.0), CHROME, r=rot(-60, 0, 0), sides=6)
    rig.add("tail", p, parent="body", pivot=(0, 1.2, 1.1))
    legs = []
    for k in range(3):
        for s in (-1, 1):
            nm = "leg_%d%s" % (k, "l" if s > 0 else "r")
            y = -0.4 + k * 0.6
            p = Part()
            capsule(p, (0.7 * s, y, 0.85), (1.3 * s, y + 0.1, 1.15), 0.09, 0.08, TIRE, sides=5)
            capsule(p, (1.3 * s, y + 0.1, 1.15), (1.55 * s, y + 0.2, 0.05), 0.08, 0.05, CHROME_D, sides=5)
            rig.add(nm, p, parent="body", pivot=(0.7 * s, y, 0.85))
            legs.append((nm, (k % 2) * 0.5 + (0 if s > 0 else 0.5), s))
    def sp(name, c, rig, rest):
        if name == "idle":
            K(c, rig, 18, tail=R(-12, 0, 6))
        if name == "skill":                                            # Stachel sticht von oben in den Boden
            K(c, rig, 12, tail=R(-30, 0, 0), arm_l=R(0, 0, 20), arm_r=R(0, 0, -20))
            K(c, rig, 27, tail=R(55, 0, 0), _i="LINEAR")
            K(c, rig, 33, tail=R(30, 0, 0))
        if name == "attack":
            K(c, rig, 7, arm_l=R(0, 0, 30), arm_r=R(0, 0, -30))
            K(c, rig, 11, arm_l=R(0, 0, -20), arm_r=R(0, 0, 20), _i="LINEAR")
    quad(rig, legs, 0.9, 3.4, 1.6, "miniboss", walk_n=21, leg_swing=16, side_legs=True, special=sp)
    rig.finish(icon_yaw=-30, icon_pitch=20)


TABLE = {"wueste_maulwurf": wueste_maulwurf, "wueste_waschbaer": wueste_waschbaer, "wueste_radkappe": wueste_radkappe, "wueste_skorpion": wueste_skorpion}

if __name__ == "__main__":
    run(TABLE, [a for a in sys.argv if not a.startswith("--")])
