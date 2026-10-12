"""Paket G2 – neue Arten der Schrottküste (Untote Seeleute): Schildmatrose (Schildträger), Seehexe (Heilerin),
Plünderer (Dieb) und der Miniboss Bootsmann Knochenhand. Abläufe aus enemies2_kit.py.
Aufruf:  python3 blender/enemies2_untote.py [art ...] [--notafel]"""
import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from enemies2_kit import *
from enemies_untote import SKIN, SKIN_D, SKIN_L, BONE, BONE_D, NAVY, NAVY_D, WHITE, WEED, WEED_L, WOOD_C, WOOD_DC, INK, GOLD_C, RUST, seaweed


def stripes(p, z0, z1, r0, r1, n, c1=NAVY, c2=WHITE, sides=10, sy=0.86):
    prof = []
    for k in range(n + 1):
        t = k / n
        prof.append((r0 + (r1 - r0) * t, z0 + (z1 - z0) * t, c1 if k % 2 == 0 else c2))
    lathe(p, prof, sides=sides, sy=sy)


# ================================================================= Schildmatrose (Schildträger)
def untote_schildmatrose():
    rig = Rig("untote_schildmatrose", role="shield")
    rig.node("hips", pivot=(0, 0, 0.9))
    p = Part()
    lathe(p, [(0.28, 0.82, NAVY_D), (0.34, 0.95, NAVY)], sides=10, sy=0.86)                           # Hose oben
    stripes(p, 0.95, 1.65, 0.36, 0.3, 6)
    p.ball(0.12, (0.12, -0.28, 1.2), SKIN, scale=(1, 0.5, 1), subdiv=1)                              # Loch im Hemd
    rig.add("body", p, parent="hips", pivot=(0, 0, 0.9))
    p = Part()                                                                                       # Zombiekopf mit Matrosenmütze
    p.ball(0.26, (0, -0.02, 1.9), SKIN, scale=(1, 0.95, 1.05), subdiv=2)
    p.box((0.2, 0.04, 0.06), (0, -0.25, 1.8), "4A2A3A", r=rot(0, 0, -8), bevel=0.0)
    lathe(p, [(0.22, 2.08, WHITE), (0.27, 2.14, WHITE), (0.27, 2.18, NAVY), (0.0, 2.2, WHITE)], sides=10)
    seaweed(p, (0.15, 0.1, 2.05), (0.32, 0.25, 1.75), 0.04, WEED)
    rig.add("head", p, parent="body", pivot=(0, 0, 1.65))
    p = Part()
    p.ball(0.06, (0.1, -0.24, 1.94), "E8FFD8", subdiv=1)
    p.ball(0.045, (-0.1, -0.24, 1.94), "E8FFD8", subdiv=1)
    rig.add("glow", p, parent="head", pivot=(0, -0.24, 1.94), glow=True)
    p = Part()                                                                                       # linker Arm hält die Kajütentür
    capsule(p, (0.32, 0, 1.55), (0.38, -0.3, 1.25), 0.08, 0.07, SKIN, sides=5)
    rig.add("arm_l", p, parent="body", pivot=(0.32, 0, 1.55))
    p = Part()                                                                                       # Kajütentür mit Bullauge
    p.box((1.0, 0.1, 1.5), (0.1, -0.5, 1.05), WOOD_C, bevel=0.04, segs=1)
    for z in (0.45, 1.65):
        p.box((1.04, 0.12, 0.1), (0.1, -0.5, z), WOOD_DC, bevel=0.0)
    p.cyl(0.2, 0.14, (0.1, -0.52, 1.3), GOLD_C, r=rot(90, 0, 0), sides=12)
    p.cyl(0.15, 0.16, (0.1, -0.52, 1.3), "5ABCD8", r=rot(90, 0, 0), sides=12)
    p.ball(0.06, (0.45, -0.58, 1.0), GOLD_C, subdiv=1)
    seaweed(p, (-0.3, -0.56, 1.7), (-0.32, -0.6, 1.2), 0.06, WEED_L)
    rig.add("shield", p, parent="arm_l", pivot=(0.38, -0.4, 1.25))
    p = Part()                                                                                       # rechter Arm mit Enterhaken
    capsule(p, (-0.32, 0, 1.55), (-0.42, -0.2, 1.1), 0.08, 0.07, SKIN_D, sides=5)
    capsule(p, (-0.44, -0.22, 1.05), (-0.44, -0.3, 0.8), 0.03, 0.03, "9AA4B4", sides=4)
    p.torus(0.1, 0.025, (-0.44, -0.38, 0.74), "9AA4B4", r=rot(0, 90, 0), seg=8, tseg=3)
    rig.add("arm_r", p, parent="body", pivot=(-0.32, 0, 1.55))
    for s, nm in ((1, "leg_l"), (-1, "leg_r")):
        p = Part()
        capsule(p, (0.15 * s, 0, 0.85), (0.16 * s, 0, 0.12), 0.11, 0.09, NAVY_D, sides=6)
        p.ball(0.12, (0.16 * s, -0.08, 0.08), INK, scale=(1, 1.5, 0.6), subdiv=1)
        rig.add(nm, p, parent="hips", pivot=(0.15 * s, 0, 0.9))
    biped(rig, 0.9, 2.3, 1.7, "shield", walk_n=27, leg_swing=22, arm_swing=0)
    rig.finish(icon_yaw=-24, icon_pitch=12)


# ================================================================= Seehexe (Heilerin)
def untote_seehexe():
    rig = Rig("untote_seehexe", role="healer")
    DRESS, DRESS_D = "3A6A7A", "2A4E5A"
    rig.node("hips", pivot=(0, 0, 0.8))
    p = Part()                                                                                       # zerfetztes Kleid mit Algensaum
    lathe(p, [(0.48, 0.15, DRESS_D), (0.42, 0.5, DRESS), (0.3, 1.1, DRESS), (0.24, 1.5, DRESS_D), (0.16, 1.62, DRESS)], sides=10, sy=0.9)
    for k in range(7):
        a = k * math.tau / 7
        seaweed(p, (0.45 * math.cos(a), 0.4 * math.sin(a), 0.25), (0.5 * math.cos(a), 0.45 * math.sin(a), -0.0), 0.06, WEED if k % 2 else WEED_L)
    for k in range(5):                                                                               # Muschelkette
        a = math.radians(-70 + k * 35)
        p.ball(0.045, (0.2 * math.sin(a), -0.22 * math.cos(a), 1.5 - 0.06 * abs(k - 2)), "F8D8C8", scale=(1, 0.5, 1), subdiv=1)
    rig.add("body", p, parent="hips", pivot=(0, 0, 0.8))
    p = Part()                                                                                       # Kopf mit langem Algenhaar und Krone aus Korallen
    p.ball(0.22, (0, -0.03, 1.82), SKIN_L, scale=(0.95, 0.95, 1.08), subdiv=2)
    p.cone(0.04, 0.1, (0, -0.25, 1.78), SKIN, r=rot(-80, 0, 0), sides=4)                            # Hakennase
    for k in range(7):
        a = math.radians(100 + k * 27)
        seaweed(p, (0.2 * math.cos(a), 0.18 * math.sin(a) + 0.02, 1.95), (0.28 * math.cos(a), 0.3 * math.sin(a) + 0.1, 1.3), 0.06, WEED if k % 2 else WEED_L)
    for k in range(3):
        p.cone(0.04, 0.2, (-0.12 + k * 0.12, 0.0, 2.06), "F27A6A", r=rot(0, (k - 1) * 20, 0), sides=4)
    rig.add("head", p, parent="body", pivot=(0, 0, 1.6))
    p = Part()
    capsule(p, (0.22, 0, 1.45), (0.35, -0.2, 1.15), 0.05, 0.045, SKIN_L, sides=5)
    rig.add("arm_l", p, parent="body", pivot=(0.22, 0, 1.45))
    p = Part()                                                                                       # Arm mit Treibholzstab und Laterne
    capsule(p, (-0.22, 0, 1.45), (-0.36, -0.25, 1.2), 0.05, 0.045, SKIN_L, sides=5)
    capsule(p, (-0.38, -0.3, 0.1), (-0.38, -0.3, 2.05), 0.035, 0.03, WOOD_DC, sides=5)
    p.box((0.18, 0.18, 0.24), (-0.38, -0.3, 2.2), GOLD_C, bevel=0.04, segs=1)
    rig.add("arm_r", p, parent="body", pivot=(-0.22, 0, 1.45))
    p = Part()
    p.ball(0.1, (-0.38, -0.3, 2.2), "7AF0FF", subdiv=1)
    rig.add("glow", p, parent="arm_r", pivot=(-0.38, -0.3, 2.2), glow=True)
    p = Part()
    for s in (-1, 1):
        p.ball(0.04, (0.08 * s, -0.22, 1.86), "7AF0FF", subdiv=1)
    rig.add("eyes", p, parent="head", pivot=(0, -0.22, 1.86), glow=True)
    for s, nm in ((1, "leg_l"), (-1, "leg_r")):                                                      # Füße unter dem Kleid
        p = Part()
        p.ball(0.08, (0.12 * s, -0.12, 0.06), SKIN_D, scale=(1, 1.5, 0.6), subdiv=1)
        rig.add(nm, p, parent="hips", pivot=(0.12 * s, 0, 0.8))
    biped(rig, 0.8, 2.3, 1.9, "healer", walk_n=27, leg_swing=16, arm_swing=12)
    rig.finish(icon_yaw=-24, icon_pitch=12)


# ================================================================= Plünderer (Dieb)
def untote_pluenderer():
    rig = Rig("untote_pluenderer", role="thief")
    RED = "C83A3A"
    rig.node("hips", pivot=(0, 0, 0.8))
    p = Part()                                                                                       # Rippen, Weste, Schärpe
    lathe(p, [(0.2, 0.78, BONE_D), (0.26, 0.9, RED), (0.28, 1.0, RED), (0.24, 1.15, BONE), (0.28, 1.35, BONE), (0.18, 1.5, BONE_D)], sides=8, sy=0.8)
    for k in range(3):
        p.torus(0.24, 0.025, (0, 0, 1.15 + k * 0.1), BONE_D, seg=8, tseg=3)
    p.box((0.12, 0.42, 0.62), (0.18, -0.02, 1.2), "2A2A3A", r=rot(0, 0, 0), bevel=0.03, segs=1)
    rig.add("body", p, parent="hips", pivot=(0, 0, 0.8))
    p = Part()                                                                                       # Schädel mit Augenklappe und Kopftuch
    p.ball(0.22, (0, -0.02, 1.72), BONE, scale=(0.95, 1, 1.05), subdiv=2)
    p.box((0.18, 0.06, 0.06), (0, -0.22, 1.6), INK, bevel=0.0)
    lathe(p, [(0.21, 1.78, RED), (0.23, 1.84, RED), (0.16, 1.95, RED), (0.0, 1.98, RED)], sides=10)
    p.cone(0.06, 0.2, (0, 0.24, 1.82), RED, r=rot(-100, 0, 0), sides=4)
    p.cyl(0.07, 0.03, (0.09, -0.2, 1.74), INK, r=rot(90, 0, 0), sides=8)
    p.box((0.3, 0.02, 0.02), (0.0, -0.18, 1.8), INK, r=rot(0, -25, 0), bevel=0.0)
    rig.add("head", p, parent="body", pivot=(0, 0, 1.5))
    p = Part()
    p.ball(0.045, (-0.09, -0.21, 1.74), "FF6A3A", subdiv=1)
    rig.add("glow", p, parent="head", pivot=(-0.09, -0.21, 1.74), glow=True)
    for s, nm in ((1, "arm_l"), (-1, "arm_r")):
        p = Part()
        capsule(p, (0.24 * s, 0, 1.4), (0.36 * s, -0.15, 1.05), 0.04, 0.035, BONE, sides=4)
        capsule(p, (0.36 * s, -0.15, 1.05), (0.4 * s, -0.25, 0.8), 0.035, 0.03, BONE_D, sides=4)
        if s < 0:
            p.box((0.05, 0.05, 0.55), (-0.4, -0.3, 0.95), "C8D0D8", r=rot(-30, 0, 0), bevel=0.0)    # Säbel
            p.box((0.16, 0.06, 0.04), (-0.4, -0.27, 0.72), GOLD_C, bevel=0.0)
        rig.add(nm, p, parent="body", pivot=(0.24 * s, 0, 1.4))
    for s, nm in ((1, "leg_l"), (-1, "leg_r")):
        p = Part()
        capsule(p, (0.11 * s, 0, 0.78), (0.12 * s, 0, 0.12), 0.08, 0.06, "3A3A4A", sides=5)
        p.ball(0.09, (0.12 * s, -0.08, 0.07), INK, scale=(1, 1.5, 0.6), subdiv=1)
        rig.add(nm, p, parent="hips", pivot=(0.11 * s, 0, 0.8))
    p = Part()                                                                                       # großer Beutesack über der Schulter
    p.ball(0.36, (0.1, 0.38, 1.35), "C8A46A", scale=(1, 0.8, 1.1), subdiv=2)
    p.cone(0.14, 0.2, (0.05, 0.25, 1.75), "B08A50", r=rot(30, 0, 0), sides=6)
    for (x, z) in ((0.25, 1.62), (-0.1, 1.55)):
        p.cyl(0.06, 0.03, (x, 0.12, z), GOLD_C, r=rot(70, 0, 20), sides=8)
    rig.add("prop", p, parent="body", pivot=(0.1, 0.3, 1.35))
    biped(rig, 0.8, 2.0, 3.4, "thief", walk_n=15, leg_swing=38, arm_swing=30, attack="swing")
    rig.finish(icon_yaw=-24, icon_pitch=12)


# ================================================================= Bootsmann Knochenhand (Miniboss)
def untote_bootsmann():
    rig = Rig("untote_bootsmann", role="miniboss")
    COAT, COAT_D = "2A3A6A", "1E2A4E"
    rig.node("hips", pivot=(0, 0, 1.4))
    p = Part()                                                                                       # mächtiger Brustkorb im Mantel
    lathe(p, [(0.5, 1.2, COAT_D), (0.6, 1.5, COAT), (0.8, 2.3, COAT), (0.85, 2.8, COAT), (0.6, 3.1, COAT_D)], sides=12, sy=0.8)
    for k in range(4):
        p.box((0.8, 0.06, 0.06), (0, -0.62, 2.0 + k * 0.22), BONE, bevel=0.02, segs=1)               # Rippen schauen heraus
    for s in (-1, 1):
        p.ball(0.06, (0.3 * s, -0.66, 2.6), GOLD_C, subdiv=1)
        p.box((0.35, 0.3, 0.1), (0.7 * s, 0, 3.05), GOLD_C, bevel=0.04, segs=1)                       # Schulterklappen
    rig.add("body", p, parent="hips", pivot=(0, 0, 1.4))
    p = Part()                                                                                       # Schädel mit Bootsmannsmütze und Pfeife
    p.ball(0.45, (0, -0.05, 3.5), BONE, scale=(1, 1, 1.05), subdiv=2)
    p.box((0.5, 0.08, 0.12), (0, -0.48, 3.3), BONE_D, bevel=0.02, segs=1)
    lathe(p, [(0.42, 3.75, COAT), (0.48, 3.85, COAT), (0.46, 4.0, COAT_D), (0.0, 4.02, COAT)], sides=12)
    p.box((0.7, 0.3, 0.06), (0, -0.4, 3.78), INK, r=rot(-10, 0, 0), bevel=0.02, segs=1)
    p.ball(0.08, (0, -0.42, 3.9), GOLD_C, subdiv=1)
    capsule(p, (0.15, -0.48, 3.26), (0.45, -0.7, 3.2), 0.035, 0.03, GOLD_C, sides=5)
    p.cyl(0.07, 0.1, (0.48, -0.72, 3.2), GOLD_C, sides=8)
    rig.add("head", p, parent="body", pivot=(0, 0, 3.1))
    p = Part()
    for s in (-1, 1):
        p.ball(0.08, (0.17 * s, -0.42, 3.55), "7AF0FF", subdiv=1)
    rig.add("glow", p, parent="head", pivot=(0, -0.42, 3.55), glow=True)
    for s, nm in ((1, "arm_l"), (-1, "arm_r")):
        p = Part()
        capsule(p, (0.75 * s, 0, 2.85), (1.05 * s, -0.25, 2.05), 0.16, 0.13, COAT, sides=6)
        capsule(p, (1.05 * s, -0.25, 2.05), (1.1 * s, -0.5, 1.4), 0.1, 0.08, BONE, sides=5)
        p.ball(0.16, (1.1 * s, -0.55, 1.3), BONE_D, subdiv=1)
        if s < 0:                                                                                    # Anker an der Kette
            for k in range(4):
                p.torus(0.07, 0.022, (-1.1, -0.6, 1.15 - k * 0.12), "6A7484", r=rot(0, 90 * (k % 2), 0), seg=6, tseg=3)
            p.box((0.1, 0.1, 0.8), (-1.1, -0.6, 0.35), "6A7484", bevel=0.02, segs=1)
            p.torus(0.36, 0.07, (-1.1, -0.6, 0.1), "6A7484", r=rot(0, 90, 0), seg=12, tseg=4)
            p.box((0.6, 0.1, 0.08), (-1.1, -0.6, 0.65), "6A7484", r=rot(0, 0, 90), bevel=0.02, segs=1)
        rig.add(nm, p, parent="body", pivot=(0.75 * s, 0, 2.85))
    for s, nm in ((1, "leg_l"), (-1, "leg_r")):
        p = Part()
        capsule(p, (0.35 * s, 0, 1.35), (0.4 * s, 0, 0.2), 0.12, 0.1, BONE, sides=6)
        p.cyl(0.2, 0.5, (0.4 * s, -0.02, 0.3), INK, sides=8)                                         # Stiefel
        p.ball(0.18, (0.4 * s, -0.18, 0.1), INK, scale=(1, 1.4, 0.5), subdiv=1)
        rig.add(nm, p, parent="hips", pivot=(0.35 * s, 0, 1.4))
    def sp(name, c, rig, rest):
        if name == "skill":                                            # Anker kreist um ihn herum
            K(c, rig, 10, arm_r=R(-90, 0, -60))
            K(c, rig, 18, arm_r=R(-90, 0, 40), body=R(0, 0, -40))
            K(c, rig, 27, arm_r=R(-90, 0, 120), body=R(10, 0, 60), _i="LINEAR")
            K(c, rig, 32, arm_r=R(-40, 0, 20), body=R(0, 0, 10))
    biped(rig, 1.4, 4.1, 1.3, "miniboss", walk_n=30, leg_swing=22, arm_swing=14, death_side=True, special=sp)
    rig.finish(icon_yaw=-24, icon_pitch=10)


TABLE = {"untote_schildmatrose": untote_schildmatrose, "untote_seehexe": untote_seehexe, "untote_pluenderer": untote_pluenderer, "untote_bootsmann": untote_bootsmann}

if __name__ == "__main__":
    run(TABLE, [a for a in sys.argv if not a.startswith("--")])
