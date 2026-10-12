"""Paket G2 – neue Arten des Kiefernforsts (Waldgeister und Pilzvolk): Waldgeist-Druide (Heiler), Moosspinnen-Mutter
(Brutmutter), Rankenschleuderer (Turmstörer) und der Miniboss Alter Eichbart. Abläufe aus enemies2_kit.py.
Aufruf:  python3 blender/enemies2_wald.py [art ...] [--notafel]"""
import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from enemies2_kit import *
from enemies_wald import CAP, CAP_D, DOT, STEM, STEM_D, BARK, BARK_D, BARK_L, MOSS, MOSS_D, LEAF, LEAF_L, THORN, INK, WHITE, GLOW_Y, GLOW_B, PINK


def leaf_clump(p, c, r, n=5, col=LEAF, col2=LEAF_L):
    for k in range(n):
        a = k * math.tau / n
        p.ball(r, (c[0] + math.cos(a) * r * 0.8, c[1] + math.sin(a) * r * 0.8, c[2] + (k % 2) * r * 0.3), col if k % 2 else col2, scale=(1, 1, 0.7), subdiv=1)


# ================================================================= Waldgeist-Druide (Heiler)
def wald_druide():
    rig = Rig("wald_druide", role="healer")
    ROBE, ROBE_D = "4E8A3A", "3A6A2C"
    rig.node("hips", pivot=(0, 0, 0.7))
    p = Part()                                                                                       # Mantel aus Moos, Saum mit Farn
    lathe(p, [(0.42, 0.25, ROBE_D), (0.4, 0.5, ROBE), (0.32, 1.0, ROBE), (0.26, 1.35, ROBE_D), (0.18, 1.5, ROBE)], sides=10, sy=0.9)
    for k in range(8):
        a = k * math.tau / 8
        p.cone(0.1, 0.22, (0.42 * math.cos(a), 0.38 * math.sin(a), 0.22), LEAF if k % 2 else MOSS_D, r=rot(180, 0, 0), sides=4)
    p.box((0.3, 0.05, 0.08), (0, -0.33, 0.9), BARK_L, bevel=0.02, segs=1)                            # Gürtel mit Eichel
    p.ball(0.06, (0.1, -0.36, 0.88), "C08A3A", subdiv=1)
    rig.add("body", p, parent="hips", pivot=(0, 0, 0.7))
    p = Part()                                                                                       # Kopf: Rindengesicht, Blätterbart, Geweih
    p.ball(0.24, (0, -0.05, 1.68), BARK, scale=(0.9, 0.85, 1.05), subdiv=2)
    leaf_clump(p, (0, -0.2, 1.48), 0.1, 5, LEAF, MOSS)
    p.box((0.22, 0.04, 0.05), (0, -0.25, 1.78), BARK_D, bevel=0.0)
    for s in (-1, 1):
        capsule(p, (0.12 * s, 0, 1.86), (0.36 * s, 0.05, 2.25), 0.035, 0.025, BARK_L, sides=5)
        capsule(p, (0.24 * s, 0.02, 2.04), (0.38 * s, -0.12, 2.12), 0.025, 0.018, BARK_L, sides=4)
        capsule(p, (0.3 * s, 0.04, 2.15), (0.24 * s, 0.1, 2.38), 0.022, 0.016, BARK_L, sides=4)
    rig.add("head", p, parent="body", pivot=(0, 0, 1.5))
    p = Part()
    for s in (-1, 1):
        p.ball(0.045, (0.08 * s, -0.24, 1.7), GLOW_B, scale=(1.2, 0.5, 0.8), subdiv=1)
    rig.add("eyes", p, parent="head", pivot=(0, -0.24, 1.7), glow=True)
    p = Part()                                                                                       # linker Arm
    capsule(p, (0.26, 0, 1.3), (0.4, -0.15, 0.95), 0.07, 0.06, ROBE, sides=5)
    p.ball(0.07, (0.42, -0.18, 0.9), BARK, subdiv=1)
    rig.add("arm_l", p, parent="body", pivot=(0.26, 0, 1.3))
    p = Part()                                                                                       # rechter Arm mit Laternenstab
    capsule(p, (-0.26, 0, 1.3), (-0.4, -0.25, 1.05), 0.07, 0.06, ROBE, sides=5)
    p.ball(0.07, (-0.42, -0.28, 1.02), BARK, subdiv=1)
    capsule(p, (-0.42, -0.3, 0.1), (-0.42, -0.3, 2.0), 0.03, 0.03, BARK_D, sides=5)
    capsule(p, (-0.42, -0.3, 2.0), (-0.32, -0.3, 2.12), 0.025, 0.02, BARK_D, sides=4)
    p.box((0.16, 0.16, 0.2), (-0.32, -0.3, 1.96), "7A5A2A", bevel=0.03, segs=1)
    rig.add("arm_r", p, parent="body", pivot=(-0.26, 0, 1.3))
    p = Part()
    p.ball(0.08, (-0.32, -0.3, 1.96), "B8FF8A", subdiv=1)
    rig.add("glow", p, parent="arm_r", pivot=(-0.32, -0.3, 1.96), glow=True)
    for s, nm in ((1, "leg_l"), (-1, "leg_r")):
        p = Part()
        capsule(p, (0.12 * s, 0, 0.6), (0.13 * s, 0, 0.08), 0.06, 0.05, BARK_D, sides=5)
        p.ball(0.08, (0.13 * s, -0.06, 0.05), BARK, scale=(1, 1.5, 0.6), subdiv=1)
        rig.add(nm, p, parent="hips", pivot=(0.12 * s, 0, 0.7))
    biped(rig, 0.7, 2.3, 2.0, "healer", walk_n=24, leg_swing=24)
    rig.finish(icon_yaw=-24, icon_pitch=12)


# ================================================================= Moosspinnen-Mutter (Brutmutter)
def wald_spinnenmutter():
    rig = Rig("wald_spinnenmutter", role="brood")
    FUR, FUR_D = "5E7A3A", "45602A"
    p = Part()                                                                                       # Vorderleib und Hinterleib mit Moospelz
    p.ball(0.36, (0, -0.35, 0.62), FUR, scale=(1, 1.1, 0.85), subdiv=2)
    p.ball(0.62, (0, 0.45, 0.78), FUR_D, scale=(1, 1.15, 0.85), subdiv=2)
    for k in range(9):
        a = k * math.tau / 9
        p.ball(0.12, (0.5 * math.cos(a), 0.45 + 0.55 * math.sin(a), 1.02), MOSS if k % 2 else LEAF, scale=(1, 1, 0.5), subdiv=1)
    p.ball(0.1, (0.18, 0.2, 1.24), CAP, scale=(1, 1, 0.5), subdiv=1)                               # Pilzchen im Pelz
    p.cyl(0.03, 0.1, (0.18, 0.2, 1.17), STEM, sides=5)
    rig.add("body", p, pivot=(0, 0, 0.6))
    p = Part()                                                                                       # Kopf mit Kieferklauen
    p.ball(0.24, (0, -0.72, 0.6), FUR, scale=(1, 0.9, 0.85), subdiv=2)
    for s in (-1, 1):
        capsule(p, (0.09 * s, -0.9, 0.5), (0.05 * s, -1.02, 0.36), 0.04, 0.02, THORN, sides=4)
    rig.add("head", p, parent="body", pivot=(0, -0.55, 0.6))
    p = Part()                                                                                       # sechs Leuchtaugen
    for (x, z, r) in ((0.08, 0.7, 0.05), (-0.08, 0.7, 0.05), (0.15, 0.63, 0.035), (-0.15, 0.63, 0.035), (0.04, 0.78, 0.03), (-0.04, 0.78, 0.03)):
        p.ball(r, (x, -0.92, z), GLOW_Y, subdiv=1)
    rig.add("eyes", p, parent="head", pivot=(0, -0.92, 0.7), glow=True)
    p = Part()                                                                                       # Eiersack auf dem Rücken
    p.ball(0.34, (0, 0.62, 1.32), "F2EEE0", scale=(1, 1.1, 0.8), subdiv=2)
    for (x, y, z) in ((0.15, 0.5, 1.45), (-0.12, 0.7, 1.48), (0.05, 0.8, 1.38), (-0.18, 0.5, 1.4)):
        p.ball(0.08, (x, y, z), "E8D8F0", subdiv=1)
    rig.add("prop", p, parent="body", pivot=(0, 0.6, 1.2))
    p = Part()
    p.ball(0.12, (0, 0.62, 1.36), "E0FF9A", subdiv=1)
    rig.add("glow", p, parent="prop", pivot=(0, 0.62, 1.36), glow=True)
    legs = []
    for k in range(4):
        for s in (-1, 1):
            nm = "leg_%d%s" % (k, "l" if s > 0 else "r")
            y0 = -0.45 + k * 0.28
            p = Part()
            capsule(p, (0.25 * s, y0, 0.66), (0.85 * s, y0 + (k - 1.5) * 0.25, 1.05), 0.06, 0.05, FUR_D, sides=5)
            capsule(p, (0.85 * s, y0 + (k - 1.5) * 0.25, 1.05), (1.25 * s, y0 + (k - 1.5) * 0.45, 0.04), 0.05, 0.025, BARK_D, sides=5)
            rig.add(nm, p, parent="body", pivot=(0.25 * s, y0, 0.66))
            legs.append((nm, (k % 2) * 0.5 + (0.0 if s > 0 else 0.25), s))
    quad(rig, legs, 0.6, 1.6, 1.6, "brood", walk_n=18, leg_swing=18, side_legs=True)
    rig.finish(icon_yaw=-30, icon_pitch=22)


# ================================================================= Rankenschleuderer (Turmstörer)
def wald_rankenwerfer():
    rig = Rig("wald_rankenwerfer", role="jammer")
    rig.node("hips", pivot=(0, 0, 0.55))
    p = Part()                                                                                       # Leib aus gebündelten Zweigen
    lathe(p, [(0.18, 0.5, BARK_D), (0.24, 0.62, BARK), (0.25, 0.9, BARK_L), (0.2, 1.08, BARK), (0.12, 1.15, BARK_D)], sides=7)
    for k in range(5):
        a = k * math.tau / 5
        capsule(p, (0.2 * math.cos(a), 0.2 * math.sin(a), 0.6), (0.24 * math.cos(a), 0.24 * math.sin(a), 1.05), 0.03, 0.025, BARK_D, sides=4)
    p.cyl(0.26, 0.06, (0, 0, 0.98), "3A8A3A", sides=8)                                              # Rankengürtel
    rig.add("body", p, parent="hips", pivot=(0, 0, 0.55))
    p = Part()                                                                                       # Kopf: Eichel mit Blätterschopf
    p.ball(0.22, (0, 0, 1.36), "C89A5A", scale=(1, 0.95, 1.05), subdiv=2)
    lathe(p, [(0.24, 1.42, "8A6A3A"), (0.24, 1.5, "9A7A4A"), (0.12, 1.6, "8A6A3A"), (0.0, 1.62, "8A6A3A")], sides=10)
    p.cyl(0.025, 0.16, (0, 0, 1.7), BARK_D, sides=5)
    leaf_clump(p, (0.05, 0.05, 1.68), 0.09, 4)
    p.box((0.12, 0.03, 0.03), (0, -0.21, 1.27), "6B3A2A", r=rot(0, 0, 8), bevel=0.0)
    for s in (-1, 1):
        p.cone(0.06, 0.18, (0.24 * s, 0.0, 1.38), "C89A5A", r=rot(0, 80 * s, 0), sides=4)           # spitze Ohren
    rig.add("head", p, parent="body", pivot=(0, 0, 1.15))
    p = Part()
    for s in (-1, 1):
        p.ball(0.05, (0.08 * s, -0.19, 1.38), GLOW_Y, scale=(1, 0.5, 1.1), subdiv=1)
    rig.add("eyes", p, parent="head", pivot=(0, -0.19, 1.38), glow=True)
    p = Part()
    capsule(p, (0.22, 0, 1.0), (0.38, -0.12, 0.72), 0.045, 0.04, BARK, sides=5)
    rig.add("arm_l", p, parent="body", pivot=(0.22, 0, 1.0))
    p = Part()                                                                                       # Arm mit Astgabel-Schleuder
    capsule(p, (-0.22, 0, 1.0), (-0.36, -0.22, 0.85), 0.045, 0.04, BARK, sides=5)
    capsule(p, (-0.38, -0.25, 0.83), (-0.38, -0.25, 1.15), 0.035, 0.03, BARK_D, sides=4)
    capsule(p, (-0.38, -0.25, 1.15), (-0.28, -0.25, 1.32), 0.025, 0.02, BARK_D, sides=4)
    capsule(p, (-0.38, -0.25, 1.15), (-0.48, -0.25, 1.32), 0.025, 0.02, BARK_D, sides=4)
    rig.add("arm_r", p, parent="body", pivot=(-0.22, 0, 1.0))
    p = Part()                                                                                       # Rankenknäuel als Geschoss
    p.ball(0.11, (-0.38, -0.3, 1.32), "3FA83A", subdiv=1)
    for k in range(3):
        p.torus(0.1, 0.02, (-0.38, -0.3, 1.32), LEAF_L, r=rot(60 * k, 30 * k, 0), seg=8, tseg=3)
    rig.add("tool", p, parent="arm_r", pivot=(-0.38, -0.3, 1.32))
    p = Part()
    p.ball(0.05, (-0.38, -0.36, 1.36), "D8FF6A", subdiv=1)
    rig.add("glow", p, parent="tool", pivot=(-0.38, -0.36, 1.36), glow=True)
    for s, nm in ((1, "leg_l"), (-1, "leg_r")):
        p = Part()
        capsule(p, (0.1 * s, 0, 0.5), (0.12 * s, 0, 0.06), 0.045, 0.035, BARK_D, sides=5)
        p.ball(0.06, (0.12 * s, -0.05, 0.04), BARK, scale=(1, 1.6, 0.5), subdiv=1)
        rig.add(nm, p, parent="hips", pivot=(0.1 * s, 0, 0.55))
    biped(rig, 0.55, 1.75, 2.2, "jammer", walk_n=21)
    rig.finish(icon_yaw=-24, icon_pitch=12)


# ================================================================= Alter Eichbart (Miniboss)
def wald_eichbart():
    rig = Rig("wald_eichbart", role="miniboss")
    rig.node("hips", pivot=(0, 0, 1.3))
    p = Part()                                                                                       # knorriger Eichenstamm
    lathe(p, [(0.75, 1.0, BARK_D), (0.8, 1.4, BARK), (0.7, 2.2, BARK_L), (0.75, 2.8, BARK), (0.85, 3.2, BARK_D), (0.7, 3.4, BARK)], sides=11, sy=0.85)
    for k in range(8):
        a = k * math.tau / 8
        capsule(p, (0.72 * math.cos(a), 0.62 * math.sin(a), 1.05), (0.7 * math.cos(a), 0.6 * math.sin(a), 3.1), 0.06, 0.06, BARK_D, sides=4)
    for (x, y, z) in ((0.55, -0.4, 1.8), (-0.6, -0.2, 2.4), (0.4, 0.5, 2.7)):                         # Baumpilze
        p.cyl(0.22, 0.06, (x, y, z), "D8B26A", r2=0.12, sides=8)
    rig.add("body", p, parent="hips", pivot=(0, 0, 1.3))
    p = Part()                                                                                       # Krone aus Laub mit Eichhörnchennest
    leaf_clump(p, (0, 0.1, 3.75), 0.55, 7, LEAF, MOSS_D)
    p.ball(0.5, (0, 0.1, 4.1), LEAF_L, subdiv=2, scale=(1.1, 1.1, 0.7))
    p.torus(0.2, 0.08, (0.4, 0.3, 4.3), BARK_L, seg=10, tseg=4)
    rig.add("crown", p, parent="body", pivot=(0, 0, 3.4))
    p = Part()                                                                                       # Gesicht mit buschigem Moosbart
    p.box((0.7, 0.08, 0.14), (0, -0.66, 3.05), BARK_D, r=rot(0, 0, 0), bevel=0.04, segs=1)           # Brauen
    p.ball(0.12, (0, -0.72, 2.75), BARK_L, scale=(1, 1.3, 1.2), subdiv=1)                           # Knollennase
    lathe(p, [(0.45, 2.55, MOSS), (0.5, 2.3, MOSS_D), (0.42, 1.9, MOSS), (0.2, 1.6, MOSS_D), (0.0, 1.5, MOSS)], sides=9, loc=(0, -0.45, 0), sy=0.5)
    rig.add("head", p, parent="body", pivot=(0, -0.5, 2.6))
    p = Part()
    for s in (-1, 1):
        p.ball(0.1, (0.24 * s, -0.7, 2.9), "FFE07A", scale=(1.2, 0.5, 0.8), subdiv=1)
    rig.add("glow", p, parent="head", pivot=(0, -0.7, 2.9), glow=True)
    for s, nm in ((1, "arm_l"), (-1, "arm_r")):                                                     # Astarme mit Laubfäusten
        p = Part()
        capsule(p, (0.75 * s, 0, 2.9), (1.35 * s, -0.3, 2.0), 0.2, 0.15, BARK, sides=7)
        capsule(p, (1.35 * s, -0.3, 2.0), (1.45 * s, -0.55, 1.3), 0.15, 0.13, BARK_D, sides=7)
        capsule(p, (1.1 * s, -0.15, 2.4), (1.55 * s, 0.1, 2.9), 0.06, 0.03, BARK_D, sides=4)      # Zweig
        leaf_clump(p, (1.55 * s, 0.1, 2.95), 0.14, 4)
        p.ball(0.28, (1.45 * s, -0.6, 1.15), BARK_L, scale=(1, 1, 0.9), subdiv=1)
        rig.add(nm, p, parent="body", pivot=(0.75 * s, 0, 2.9))
    for s, nm in ((1, "leg_l"), (-1, "leg_r")):                                                     # Wurzelbeine
        p = Part()
        capsule(p, (0.4 * s, 0, 1.2), (0.45 * s, -0.05, 0.25), 0.26, 0.22, BARK_D, sides=7)
        for k in range(3):
            a = math.radians(-60 + k * 60)
            capsule(p, (0.45 * s, -0.05, 0.2), (0.45 * s + math.sin(a) * 0.45, -0.05 - math.cos(a) * 0.45, 0.04), 0.1, 0.05, BARK, sides=4)
        rig.add(nm, p, parent="hips", pivot=(0.4 * s, 0, 1.3))
    biped(rig, 1.3, 4.4, 1.1, "miniboss", walk_n=36, leg_swing=20, arm_swing=14, death_side=True)
    rig.finish(icon_yaw=-24, icon_pitch=10)


TABLE = {"wald_druide": wald_druide, "wald_spinnenmutter": wald_spinnenmutter, "wald_rankenwerfer": wald_rankenwerfer, "wald_eichbart": wald_eichbart}

if __name__ == "__main__":
    run(TABLE, [a for a in sys.argv if not a.startswith("--")])
