"""Paket G2 – neue Arten des Schleimkraters (Dämonen): Glutkobold (Turmstörer), Gierteufel (Dieb), Höllengräber
(Tunnelgräber) und der Miniboss Kettenteufel. Abläufe aus enemies2_kit.py.
Aufruf:  python3 blender/enemies2_daemonen.py [art ...] [--notafel]"""
import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from enemies2_kit import *
from enemies_daemonen_arten import DRED, DRED_D, DRED_L, GLUT, GLUT_L, SOOT, SOOT_D, HORN, HORN_D, PURP, PURP_D, GOLD, INK, WHITE


def horns(p, x, z, y=0.0, l=0.25, r=0.07, spread=30, col=HORN):
    for s in (-1, 1):
        capsule(p, (x * s, y, z), (x * s + 0.1 * s, y + 0.04, z + l), r, r * 0.3, col, sides=5)


# ================================================================= Glutkobold (Turmstörer)
def daemonen_glutkobold():
    rig = Rig("daemonen_glutkobold", role="jammer")
    rig.node("hips", pivot=(0, 0, 0.5))
    p = Part()
    lathe(p, [(0.22, 0.45, DRED_D), (0.3, 0.6, DRED), (0.3, 0.85, DRED), (0.22, 1.0, DRED_D), (0.14, 1.06, DRED_D)], sides=9)
    p.box((0.42, 0.06, 0.28), (0, -0.28, 0.7), SOOT, bevel=0.03, segs=1)                             # Lederschürze
    rig.add("body", p, parent="hips", pivot=(0, 0, 0.5))
    p = Part()                                                                                       # grinsender Kopf mit Hörnchen
    p.ball(0.24, (0, -0.04, 1.28), DRED_L, scale=(1.1, 1, 0.95), subdiv=2)
    p.box((0.24, 0.04, 0.05), (0, -0.25, 1.2), INK, r=rot(0, 0, 0), bevel=0.0)
    for k in range(3):
        p.cone(0.02, 0.04, (-0.06 + k * 0.06, -0.26, 1.18), WHITE, r=rot(180, 0, 0), sides=3)
    horns(p, 0.13, 1.42, l=0.18, r=0.05)
    rig.add("head", p, parent="body", pivot=(0, 0, 1.06))
    p = Part()
    for s in (-1, 1):
        p.ball(0.045, (0.09 * s, -0.24, 1.33), GLUT_L, subdiv=1)
    rig.add("eyes", p, parent="head", pivot=(0, -0.24, 1.33), glow=True)
    p = Part()                                                                                       # Lavaeimer auf dem Rücken
    p.cyl(0.24, 0.42, (0, 0.34, 0.95), SOOT_D, r2=0.28, sides=10)
    p.torus(0.27, 0.03, (0, 0.34, 1.15), "8A8E96", seg=10, tseg=3)
    rig.add("prop", p, parent="body", pivot=(0, 0.32, 0.8))
    p = Part()
    p.ball(0.24, (0, 0.34, 1.17), GLUT, scale=(1, 1, 0.3), subdiv=1)
    rig.add("glow", p, parent="prop", pivot=(0, 0.34, 1.17), glow=True)
    p = Part()
    capsule(p, (0.26, 0, 0.92), (0.38, -0.15, 0.62), 0.05, 0.045, DRED, sides=5)
    rig.add("arm_l", p, parent="body", pivot=(0.26, 0, 0.92))
    p = Part()                                                                                       # Arm mit Schöpfkelle voller Glutschleim
    capsule(p, (-0.26, 0, 0.92), (-0.38, -0.25, 0.75), 0.05, 0.045, DRED, sides=5)
    capsule(p, (-0.4, -0.28, 0.72), (-0.4, -0.5, 1.15), 0.025, 0.025, "8A8E96", sides=4)
    p.cyl(0.12, 0.08, (-0.4, -0.52, 1.2), "8A8E96", sides=8)
    rig.add("arm_r", p, parent="body", pivot=(-0.26, 0, 0.92))
    p = Part()
    p.ball(0.1, (-0.4, -0.52, 1.25), GLUT_L, scale=(1, 1, 0.6), subdiv=1)
    rig.add("tool", p, parent="arm_r", pivot=(-0.4, -0.52, 1.25), glow=True)
    for s, nm in ((1, "leg_l"), (-1, "leg_r")):
        p = Part()
        capsule(p, (0.1 * s, 0, 0.46), (0.12 * s, 0, 0.08), 0.05, 0.04, DRED_D, sides=5)
        p.cone(0.07, 0.14, (0.12 * s, -0.04, 0.06), SOOT, r=rot(-90, 0, 0), sides=4)                # Hufe
        rig.add(nm, p, parent="hips", pivot=(0.1 * s, 0, 0.5))
    p = Part()
    capsule(p, (0, 0.2, 0.55), (0, 0.6, 0.35), 0.03, 0.02, DRED_D, sides=4)
    p.cone(0.06, 0.12, (0, 0.65, 0.33), DRED_D, r=rot(-100, 0, 0), sides=3)
    rig.add("tail", p, parent="hips", pivot=(0, 0.2, 0.55))
    biped(rig, 0.5, 1.6, 2.4, "jammer", walk_n=18, leg_swing=34)
    rig.finish(icon_yaw=-24, icon_pitch=12)


# ================================================================= Gierteufel (Dieb)
def daemonen_gierteufel():
    rig = Rig("daemonen_gierteufel", role="thief")
    rig.node("hips", pivot=(0, 0, 0.55))
    p = Part()                                                                                       # Frack mit Goldknöpfen
    lathe(p, [(0.22, 0.5, INK), (0.3, 0.62, SOOT), (0.3, 0.9, SOOT), (0.22, 1.08, SOOT_D), (0.14, 1.14, SOOT_D)], sides=9)
    p.box((0.16, 0.05, 0.42), (0, -0.28, 0.85), WHITE, bevel=0.02, segs=1)
    for k in range(3):
        p.ball(0.035, (0.05, -0.31, 0.72 + k * 0.12), GOLD, subdiv=1)
    for s in (-1, 1):
        p.box((0.14, 0.06, 0.4), (0.18 * s, 0.22, 0.5), SOOT_D, r=rot(-12, 0, 0), bevel=0.02, segs=1)  # Frackschöße
    rig.add("body", p, parent="hips", pivot=(0, 0, 0.55))
    p = Part()                                                                                       # Kopf mit Zylinder, Monokel und Spitzbart
    p.ball(0.23, (0, -0.03, 1.36), DRED, scale=(1, 1, 1.05), subdiv=2)
    p.cone(0.06, 0.18, (0, -0.16, 1.12), DRED_D, r=rot(180, 0, 0), sides=4)
    p.cyl(0.16, 0.36, (0, 0.0, 1.72), INK, sides=10)
    p.cyl(0.26, 0.04, (0, 0.0, 1.55), INK, sides=12)
    p.cyl(0.165, 0.06, (0, 0.0, 1.6), GOLD, sides=10)
    p.torus(0.07, 0.015, (0.09, -0.22, 1.4), GOLD, r=rot(90, 0, 0), seg=8, tseg=3)
    horns(p, 0.15, 1.5, l=0.12, r=0.04)
    rig.add("head", p, parent="body", pivot=(0, 0, 1.14))
    p = Part()
    for s in (-1, 1):
        p.ball(0.04, (0.09 * s, -0.23, 1.4), GLUT_L, subdiv=1)
    rig.add("glow", p, parent="head", pivot=(0, -0.23, 1.4), glow=True)
    for s, nm in ((1, "arm_l"), (-1, "arm_r")):
        p = Part()
        capsule(p, (0.26 * s, 0, 1.0), (0.38 * s, -0.18, 0.72), 0.05, 0.045, SOOT, sides=5)
        p.ball(0.06, (0.4 * s, -0.2, 0.68), WHITE, subdiv=1)                                         # weiße Handschuhe
        rig.add(nm, p, parent="body", pivot=(0.26 * s, 0, 1.0))
    for s, nm in ((1, "leg_l"), (-1, "leg_r")):
        p = Part()
        capsule(p, (0.1 * s, 0, 0.5), (0.12 * s, 0, 0.08), 0.05, 0.045, INK, sides=5)
        p.ball(0.08, (0.12 * s, -0.07, 0.05), SOOT_D, scale=(1, 1.6, 0.5), subdiv=1)
        rig.add(nm, p, parent="hips", pivot=(0.1 * s, 0, 0.55))
    p = Part()                                                                                       # praller Geldsack mit Münzzeichen
    p.ball(0.3, (0.0, 0.4, 0.9), "D8B86A", scale=(1, 0.85, 1.05), subdiv=2)
    p.cone(0.11, 0.16, (0.0, 0.4, 1.22), "B8964A", sides=6)
    p.box((0.16, 0.03, 0.16), (0.0, 0.14, 0.92), GOLD, r=rot(0, 45, 0), bevel=0.02, segs=1)
    rig.add("prop", p, parent="body", pivot=(0, 0.35, 0.9))
    p = Part()
    capsule(p, (0, 0.15, 0.55), (0, 0.5, 0.25), 0.03, 0.02, DRED, sides=4)
    p.cone(0.06, 0.12, (0, 0.55, 0.22), DRED, r=rot(-120, 0, 0), sides=3)
    rig.add("tail", p, parent="hips", pivot=(0, 0.15, 0.55))
    biped(rig, 0.55, 1.95, 3.6, "thief", walk_n=15, leg_swing=36, arm_swing=26)
    rig.finish(icon_yaw=-24, icon_pitch=12)


# ================================================================= Höllengräber (Tunnelgräber)
def daemonen_hoellengraeber():
    rig = Rig("daemonen_hoellengraeber", role="digger")
    rig.node("hips", pivot=(0, 0, 0.6))
    p = Part()                                                                                       # breiter Rücken voller Glutrisse
    lathe(p, [(0.32, 0.55, SOOT), (0.45, 0.75, SOOT), (0.5, 1.1, SOOT_D), (0.42, 1.4, SOOT), (0.24, 1.5, SOOT_D)], sides=10)
    for (x, z) in ((0.2, 0.9), (-0.25, 1.15), (0.05, 1.3)):
        p.box((0.24, 0.04, 0.05), (x, -0.44, z), GLUT, r=rot(0, 30, 0), bevel=0.0)
    rig.add("body", p, parent="hips", pivot=(0, 0, 0.6))
    p = Part()                                                                                       # gesenkter Kopf mit Widderhörnern
    p.ball(0.26, (0, -0.25, 1.48), DRED_D, scale=(1, 1.05, 0.9), subdiv=2)
    for s in (-1, 1):
        p.torus(0.14, 0.05, (0.24 * s, -0.15, 1.58), HORN, r=rot(0, 90, 0), seg=10, tseg=4)
    rig.add("head", p, parent="body", pivot=(0, -0.1, 1.38))
    p = Part()
    for s in (-1, 1):
        p.ball(0.045, (0.1 * s, -0.48, 1.52), GLUT_L, subdiv=1)
    rig.add("glow", p, parent="head", pivot=(0, -0.48, 1.52), glow=True)
    p = Part()
    capsule(p, (0.45, 0, 1.25), (0.55, -0.3, 0.9), 0.09, 0.08, DRED, sides=5)
    p.ball(0.11, (0.57, -0.34, 0.84), DRED_D, subdiv=1)
    rig.add("arm_l", p, parent="body", pivot=(0.45, 0, 1.25))
    p = Part()                                                                                       # glühende Schaufel
    capsule(p, (-0.45, 0, 1.25), (-0.55, -0.3, 0.95), 0.09, 0.08, DRED, sides=5)
    capsule(p, (-0.57, -0.35, 0.4), (-0.57, -0.35, 1.5), 0.035, 0.035, SOOT_D, sides=5)
    p.box((0.3, 0.06, 0.38), (-0.57, -0.37, 0.25), "8A8E96", bevel=0.03, segs=1)
    rig.add("arm_r", p, parent="body", pivot=(-0.45, 0, 1.25))
    p = Part()
    p.box((0.22, 0.07, 0.25), (-0.57, -0.4, 0.22), GLUT, bevel=0.02, segs=1)
    rig.add("tool", p, parent="arm_r", pivot=(-0.57, -0.4, 0.22), glow=True)
    for s, nm in ((1, "leg_l"), (-1, "leg_r")):
        p = Part()
        capsule(p, (0.18 * s, 0, 0.56), (0.2 * s, 0, 0.1), 0.1, 0.08, SOOT_D, sides=5)
        p.cone(0.11, 0.2, (0.2 * s, -0.05, 0.07), INK, r=rot(-90, 0, 0), sides=4)
        rig.add(nm, p, parent="hips", pivot=(0.18 * s, 0, 0.6))
    mound(rig, 0.55, "4A2A2A", GLUT)
    biped(rig, 0.6, 1.8, 2.6, "digger", walk_n=18, leg_swing=30)
    rig.finish(icon_yaw=-24, icon_pitch=12)


# ================================================================= Kettenteufel (Miniboss)
def daemonen_kettenteufel():
    rig = Rig("daemonen_kettenteufel", role="miniboss")
    CHAIN = "7A808A"
    rig.node("hips", pivot=(0, 0, 1.3))
    p = Part()                                                                                       # muskulöser Oberkörper in Ketten
    lathe(p, [(0.45, 1.2, SOOT_D), (0.6, 1.5, DRED_D), (0.85, 2.3, DRED), (0.9, 2.8, DRED), (0.6, 3.1, DRED_D)], sides=12, sy=0.8)
    for k in range(2):
        p.torus(0.8 - 0.05 * k, 0.06, (0, 0, 2.2 + k * 0.45), CHAIN, r=rot(10 - 20 * k, 0, 20 - 40 * k), seg=14, tseg=4)
    lathe(p, [(0.5, 2.95, CHAIN), (0.55, 3.05, "9AA0AA"), (0.5, 3.15, CHAIN)], sides=12, cap=False)  # Halsband
    p.ball(0.12, (0, -0.55, 3.05), GLUT_L, subdiv=1)
    rig.add("body", p, parent="hips", pivot=(0, 0, 1.3))
    p = Part()                                                                                       # Kopf mit großen Hörnern
    p.ball(0.42, (0, -0.1, 3.5), DRED, scale=(1, 1, 1.05), subdiv=2)
    p.box((0.4, 0.06, 0.08), (0, -0.48, 3.35), INK, bevel=0.02, segs=1)
    for s in (-1, 1):
        capsule(p, (0.3 * s, -0.05, 3.75), (0.65 * s, 0.05, 4.1), 0.11, 0.07, HORN, sides=6)
        capsule(p, (0.65 * s, 0.05, 4.1), (0.6 * s, -0.15, 4.45), 0.07, 0.02, HORN_D, sides=5)
    rig.add("head", p, parent="body", pivot=(0, 0, 3.1))
    p = Part()
    for s in (-1, 1):
        p.ball(0.08, (0.15 * s, -0.47, 3.58), GLUT_L, subdiv=1)
    rig.add("glow", p, parent="head", pivot=(0, -0.47, 3.58), glow=True)
    for s, nm in ((1, "arm_l"), (-1, "arm_r")):
        p = Part()
        capsule(p, (0.8 * s, 0, 2.85), (1.15 * s, -0.25, 2.1), 0.2, 0.17, DRED, sides=7)
        capsule(p, (1.15 * s, -0.25, 2.1), (1.2 * s, -0.55, 1.45), 0.17, 0.14, DRED_D, sides=7)
        p.ball(0.22, (1.2 * s, -0.6, 1.35), SOOT, subdiv=1)
        p.torus(0.2, 0.05, (1.17 * s, -0.4, 1.8), CHAIN, r=rot(70, 0, 0), seg=10, tseg=4)            # Handschellen
        if s < 0:                                                                                    # Kette mit Glühkugel
            for k in range(5):
                p.torus(0.08, 0.025, (-1.2, -0.65 - k * 0.13, 1.25 - k * 0.12), CHAIN, r=rot(0, 90 * (k % 2), 30), seg=6, tseg=3)
            p.ball(0.3, (-1.2, -1.35, 0.6), SOOT_D, subdiv=1)
            for k in range(6):
                a = k * math.tau / 6
                p.cone(0.07, 0.18, (-1.2 + 0.3 * math.cos(a), -1.35 + 0.3 * math.sin(a), 0.6), SOOT, r=rot(0, 90, math.degrees(a)), sides=4)
        rig.add(nm, p, parent="body", pivot=(0.8 * s, 0, 2.85))
    for s, nm in ((1, "leg_l"), (-1, "leg_r")):
        p = Part()
        capsule(p, (0.35 * s, 0, 1.25), (0.4 * s, 0.05, 0.25), 0.2, 0.15, SOOT_D, sides=7)
        p.cone(0.22, 0.35, (0.4 * s, -0.08, 0.12), INK, r=rot(-90, 0, 0), sides=5)
        rig.add(nm, p, parent="hips", pivot=(0.35 * s, 0, 1.3))
    p = Part()
    capsule(p, (0, 0.4, 1.4), (0, 1.3, 0.6), 0.08, 0.05, DRED_D, sides=5)
    p.cone(0.15, 0.3, (0, 1.38, 0.5), DRED_D, r=rot(-130, 0, 0), sides=3)
    rig.add("tail", p, parent="hips", pivot=(0, 0.4, 1.4))
    def sp(name, c, rig, rest):
        if name == "skill":                                            # wirbelt die Glühkugel über dem Kopf und schmettert sie herab
            K(c, rig, 14, arm_r=R(-150, 0, -40), body=R(-10, 0, -30))
            K(c, rig, 20, arm_r=R(-170, 0, 40), body=R(-14, 0, 30))
    biped(rig, 1.3, 4.4, 1.4, "miniboss", walk_n=30, leg_swing=22, arm_swing=14, death_side=True, special=sp)
    # Kette auswerfen (zieht den Helden heran)
    rest = rest_pose(rig)
    with rig.clip("throw", 30, hit=15) as c:
        K(c, rig, 0, **rest)
        K(c, rig, 9, arm_r=R(-160, 0, -20), body=R(-12, 0, -20))
        K(c, rig, 15, _i="LINEAR", arm_r=R(-80, 0, 10), body=R(14, 0, 14))
        K(c, rig, 22, arm_r=R(-40, 0, 0), body=R(-8, 0, 0), hips=dict(loc=(0, 0.15, 0)))
        K(c, rig, 30, **rest)
    rig.finish(icon_yaw=-24, icon_pitch=10)


TABLE = {"daemonen_glutkobold": daemonen_glutkobold, "daemonen_gierteufel": daemonen_gierteufel, "daemonen_hoellengraeber": daemonen_hoellengraeber, "daemonen_kettenteufel": daemonen_kettenteufel}

if __name__ == "__main__":
    run(TABLE, [a for a in sys.argv if not a.startswith("--")])
