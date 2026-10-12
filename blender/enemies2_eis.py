"""Paket G2 – neue Arten des Frostpasses (Eiswesen): Eis-Schildwall (Schildträger), Frostschamanin (Heilerin),
Schneemutter (Brutmutter) und der Miniboss Frostmammut. Abläufe aus enemies2_kit.py.
Aufruf:  python3 blender/enemies2_eis.py [art ...] [--notafel]"""
import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from enemies2_kit import *
from enemies_eis import SNOW, SNOW_D, ICE, ICE_D, ICE_L, CRYS, FUR, FUR_D, RED, RED_D, BLUE, INK, WHITE


# ================================================================= Eis-Schildwall (Schildträger)
def eis_schildwall():
    rig = Rig("eis_schildwall", role="shield")
    rig.node("hips", pivot=(0, 0, 0.9))
    p = Part()                                                                                       # Eiskrieger: Kristallrüstung
    lathe(p, [(0.3, 0.85, ICE_D), (0.4, 1.0, ICE), (0.46, 1.4, ICE_L), (0.4, 1.7, ICE), (0.24, 1.85, ICE_D)], sides=7)
    for s in (-1, 1):
        p.cone(0.14, 0.4, (0.42 * s, 0.05, 1.82), CRYS, r=rot(0, 25 * s, 0), sides=5)                # Schulterzacken
    rig.add("body", p, parent="hips", pivot=(0, 0, 0.9))
    p = Part()                                                                                       # Helm mit Visier und Hörnern aus Eis
    lathe(p, [(0.22, 1.85, BLUE), (0.26, 2.0, BLUE), (0.24, 2.2, "4A7AD8"), (0.12, 2.32, BLUE), (0.0, 2.36, BLUE)], sides=10)
    p.box((0.34, 0.06, 0.06), (0, -0.25, 2.06), INK, bevel=0.0)
    for s in (-1, 1):
        p.cone(0.06, 0.32, (0.22 * s, 0.0, 2.32), ICE_L, r=rot(0, 30 * s, 0), sides=5)
    rig.add("head", p, parent="body", pivot=(0, 0, 1.85))
    p = Part()
    for s in (-1, 1):
        p.ball(0.035, (0.08 * s, -0.27, 2.06), "9AF0FF", subdiv=1)
    rig.add("glow", p, parent="head", pivot=(0, -0.27, 2.06), glow=True)
    p = Part()
    capsule(p, (0.4, 0, 1.65), (0.42, -0.35, 1.3), 0.09, 0.08, ICE, sides=5)
    rig.add("arm_l", p, parent="body", pivot=(0.4, 0, 1.65))
    p = Part()                                                                                       # große Eisplatte als Schild
    p.box((1.15, 0.18, 1.55), (0.12, -0.55, 1.2), ICE, r=rot(-4, 0, 0), bevel=0.08, segs=1)
    p.box((0.9, 0.2, 1.25), (0.12, -0.6, 1.2), ICE_L, r=rot(-4, 0, 0), bevel=0.06, segs=1)
    for (x, z) in ((-0.2, 1.6), (0.35, 0.85), (0.1, 1.3)):
        p.cone(0.08, 0.18, (x, -0.72, z), CRYS, r=rot(90, 0, 0), sides=4)
    rig.add("shield", p, parent="arm_l", pivot=(0.42, -0.45, 1.3))
    p = Part()                                                                                       # Eiskeule
    capsule(p, (-0.4, 0, 1.65), (-0.45, -0.3, 1.25), 0.09, 0.08, ICE, sides=5)
    capsule(p, (-0.46, -0.35, 1.15), (-0.46, -0.6, 1.9), 0.05, 0.12, ICE_L, sides=6)
    rig.add("arm_r", p, parent="body", pivot=(-0.4, 0, 1.65))
    for s, nm in ((1, "leg_l"), (-1, "leg_r")):
        p = Part()
        capsule(p, (0.17 * s, 0, 0.85), (0.18 * s, 0, 0.12), 0.12, 0.1, ICE_D, sides=6)
        p.ball(0.13, (0.18 * s, -0.08, 0.08), BLUE, scale=(1, 1.4, 0.55), subdiv=1)
        rig.add(nm, p, parent="hips", pivot=(0.17 * s, 0, 0.9))
    biped(rig, 0.9, 2.4, 1.5, "shield", walk_n=30, leg_swing=24, arm_swing=0)
    rig.finish(icon_yaw=-24, icon_pitch=12)


# ================================================================= Frostschamanin (Heilerin)
def eis_frostschamanin():
    rig = Rig("eis_frostschamanin", role="healer")
    rig.node("hips", pivot=(0, 0, 0.75))
    p = Part()                                                                                       # dicker Fellmantel mit Rautenborte
    lathe(p, [(0.46, 0.15, FUR_D), (0.44, 0.3, FUR), (0.36, 0.9, FUR), (0.3, 1.35, FUR), (0.2, 1.5, FUR_D)], sides=10)
    for k in range(10):
        a = k * math.tau / 10
        p.box((0.1, 0.04, 0.1), (0.45 * math.cos(a), 0.45 * math.sin(a), 0.28), RED if k % 2 else BLUE, r=rot(0, 45, math.degrees(a)), bevel=0.0)
    rig.add("body", p, parent="hips", pivot=(0, 0, 0.75))
    p = Part()                                                                                       # Eulenmaske mit Federohren
    p.ball(0.24, (0, -0.02, 1.7), "D8E4F0", scale=(1, 0.95, 1.05), subdiv=2)
    p.cone(0.05, 0.1, (0, -0.25, 1.65), "F2C230", r=rot(-100, 0, 0), sides=4)
    for s in (-1, 1):
        p.cyl(0.09, 0.04, (0.1 * s, -0.22, 1.76), "F2F8FF", r=rot(90, 0, 0), sides=10)
        p.cone(0.07, 0.24, (0.16 * s, 0.0, 1.95), FUR_D, r=rot(0, 20 * s, 0), sides=4)
    rig.add("head", p, parent="body", pivot=(0, 0, 1.5))
    p = Part()
    for s in (-1, 1):
        p.ball(0.045, (0.1 * s, -0.26, 1.76), "9AF0FF", subdiv=1)
    rig.add("eyes", p, parent="head", pivot=(0, -0.26, 1.76), glow=True)
    p = Part()
    capsule(p, (0.26, 0, 1.35), (0.38, -0.2, 1.05), 0.06, 0.05, FUR, sides=5)
    rig.add("arm_l", p, parent="body", pivot=(0.26, 0, 1.35))
    p = Part()                                                                                       # Kristallstab
    capsule(p, (-0.26, 0, 1.35), (-0.38, -0.25, 1.1), 0.06, 0.05, FUR, sides=5)
    capsule(p, (-0.4, -0.3, 0.1), (-0.4, -0.3, 1.95), 0.03, 0.03, "8A6A4A", sides=5)
    rig.add("arm_r", p, parent="body", pivot=(-0.26, 0, 1.35))
    p = Part()
    p.cone(0.12, 0.38, (-0.4, -0.3, 2.12), CRYS, sides=5)
    p.cone(0.12, 0.2, (-0.4, -0.3, 1.92), CRYS, r=rot(180, 0, 0), sides=5)
    rig.add("glow", p, parent="arm_r", pivot=(-0.4, -0.3, 2.05), glow=True)
    for s, nm in ((1, "leg_l"), (-1, "leg_r")):
        p = Part()
        p.ball(0.1, (0.13 * s, -0.12, 0.07), FUR_D, scale=(1, 1.5, 0.6), subdiv=1)
        rig.add(nm, p, parent="hips", pivot=(0.13 * s, 0, 0.75))
    biped(rig, 0.75, 2.2, 2.0, "healer", walk_n=24, leg_swing=16)
    rig.finish(icon_yaw=-24, icon_pitch=12)


# ================================================================= Schneemutter (Brutmutter)
def eis_schneemutter():
    rig = Rig("eis_schneemutter", role="brood")
    rig.node("hips", pivot=(0, 0, 0.6))
    p = Part()                                                                                       # dicke Schneefrau aus zwei Kugeln
    p.ball(0.75, (0, 0, 0.75), SNOW, scale=(1, 1, 0.9), subdiv=2)
    p.ball(0.55, (0, 0, 1.65), SNOW, subdiv=2)
    p.box((0.9, 0.08, 0.6), (0, -0.66, 0.8), "E87AA0", r=rot(-14, 0, 0), bevel=0.05, segs=1)          # Schürze
    for k in range(3):
        p.ball(0.07, (0, -0.55, 1.45 - k * 0.22), INK, subdiv=1)                                    # Kohleknöpfe
    rig.add("body", p, parent="hips", pivot=(0, 0, 0.6))
    p = Part()                                                                                       # Kopf mit Topfhut und Rübennase
    p.ball(0.4, (0, -0.05, 2.45), SNOW, subdiv=2)
    p.cone(0.08, 0.35, (0, -0.55, 2.42), "F28A2A", r=rot(-90, 0, 0), sides=6)
    lathe(p, [(0.36, 2.72, "6A7484"), (0.38, 2.78, "8A94A8"), (0.3, 3.0, "8A94A8"), (0.0, 3.02, "6A7484")], sides=10)
    p.box((0.7, 0.06, 0.04), (0, 0, 2.78), "4A5264", bevel=0.0)
    rig.add("head", p, parent="body", pivot=(0, 0, 2.15))
    p = Part()
    for s in (-1, 1):
        p.ball(0.06, (0.14 * s, -0.4, 2.55), "9AF0FF", subdiv=1)
    rig.add("eyes", p, parent="head", pivot=(0, -0.4, 2.55), glow=True)
    for s, nm in ((1, "arm_l"), (-1, "arm_r")):                                                     # Zweigarme mit Fäustlingen
        p = Part()
        capsule(p, (0.5 * s, 0, 1.75), (0.85 * s, -0.3, 1.3), 0.05, 0.04, "6A4A2A", sides=4)
        p.ball(0.13, (0.88 * s, -0.33, 1.25), RED, subdiv=1)
        rig.add(nm, p, parent="body", pivot=(0.5 * s, 0, 1.75))
    p = Part()                                                                                       # Schneeballkorb (daraus formt sie die Wichtel)
    p.cyl(0.35, 0.3, (0, 0.65, 1.0), "B08A50", r=rot(-15, 0, 0), sides=10)
    for (x, y) in ((0.12, 0.6), (-0.12, 0.62), (0.0, 0.75)):
        p.ball(0.14, (x, y, 1.2), WHITE, subdiv=1)
    rig.add("prop", p, parent="body", pivot=(0, 0.6, 1.0))
    p = Part()
    p.ball(0.16, (0, 0.62, 1.32), "C8F4FF", subdiv=1)
    rig.add("glow", p, parent="prop", pivot=(0, 0.62, 1.32), glow=True)
    biped(rig, 0.6, 3.0, 1.4, "brood", walk_n=30, leg_swing=0, arm_swing=18)
    rig.finish(icon_yaw=-24, icon_pitch=12)


# ================================================================= Frostmammut (Miniboss)
def eis_mammut():
    rig = Rig("eis_mammut", role="miniboss")
    HAIR, HAIR_D = "8A6A5A", "6A4E42"
    p = Part()                                                                                       # zotteliger Leib mit Schneedecke
    p.ball(1.3, (0, 0.2, 1.9), HAIR, scale=(1, 1.3, 0.95), subdiv=2)
    for k in range(12):
        a = k * math.tau / 12
        p.cone(0.18, 0.5, (1.15 * math.cos(a), 0.2 + 1.45 * math.sin(a), 1.25), HAIR_D, r=rot(180, 0, 0), sides=4)
    p.ball(1.0, (0, 0.3, 2.75), SNOW, scale=(1.05, 1.25, 0.35), subdiv=2)                            # Schnee auf dem Rücken
    for (x, y) in ((0.6, -0.3), (-0.55, 0.5), (0.2, 1.1)):
        p.cone(0.12, 0.45, (x, y, 2.95), ICE_L, sides=5)                                             # Eiszapfen-Kamm
    rig.add("body", p, pivot=(0, 0, 1.8))
    p = Part()                                                                                       # Kopf mit Rüssel und Eiszapfen-Stoßzähnen
    p.ball(0.8, (0, -1.3, 2.4), HAIR, scale=(1, 0.9, 1.0), subdiv=2)
    pts = [(0, -1.9, 2.3), (0, -2.15, 1.7), (0, -2.1, 1.1), (0, -1.9, 0.75)]
    for i in range(len(pts) - 1):
        capsule(p, pts[i], pts[i + 1], 0.24 - 0.05 * i, 0.2 - 0.05 * i, HAIR_D if i % 2 else HAIR, sides=7)
    for s in (-1, 1):
        capsule(p, (0.45 * s, -1.8, 1.95), (0.8 * s, -2.5, 1.5), 0.13, 0.09, ICE_L, sides=6)
        capsule(p, (0.8 * s, -2.5, 1.5), (0.7 * s, -2.75, 2.0), 0.09, 0.03, ICE, sides=6)
        p.ball(0.45, (0.75 * s, -1.0, 2.45), HAIR_D, scale=(0.4, 1, 1.1), subdiv=1)                   # Ohren
    rig.add("head", p, parent="body", pivot=(0, -1.0, 2.3))
    p = Part()
    for s in (-1, 1):
        p.ball(0.1, (0.35 * s, -1.95, 2.6), "9AF0FF", subdiv=1)
    rig.add("glow", p, parent="head", pivot=(0, -1.95, 2.6), glow=True)
    legs = []
    for (nm, x, y, ph, s) in (("leg_fl", 0.75, -0.6, 0.0, 1), ("leg_fr", -0.75, -0.6, 0.5, -1), ("leg_bl", 0.75, 1.0, 0.5, 1), ("leg_br", -0.75, 1.0, 0.0, -1)):
        p = Part()
        capsule(p, (x, y, 1.5), (x, y, 0.3), 0.38, 0.34, HAIR_D, sides=8)
        p.cyl(0.38, 0.25, (x, y, 0.12), SNOW_D, sides=10)
        rig.add(nm, p, parent="body", pivot=(x, y, 1.5))
        legs.append((nm, ph, s))
    p = Part()
    capsule(p, (0, 1.75, 2.0), (0, 2.1, 1.3), 0.08, 0.05, HAIR_D, sides=5)
    rig.add("tail", p, parent="body", pivot=(0, 1.75, 2.0))
    def sp(name, c, rig, rest):
        if name == "skill":                                            # bäumt sich auf und stampft eine Frostwelle
            K(c, rig, 10, body=dict(rot=(-28, 0, 0), loc=(0, 0.3, 0.4)), leg_fl=R(-50, 0, 0), leg_fr=R(-50, 0, 0), head=R(-30, 0, 0))
            K(c, rig, 20, body=dict(rot=(-32, 0, 0), loc=(0, 0.3, 0.5)), root=dict(loc=(0, 0, 0)))
            K(c, rig, 27, body=dict(rot=(8, 0, 0), loc=(0, -0.1, -0.1)), leg_fl=R(10, 0, 0), leg_fr=R(10, 0, 0), head=R(16, 0, 0), _i="LINEAR")
        if name == "attack":
            K(c, rig, 7, head=R(-30, 0, 0))
            K(c, rig, 11, head=R(30, 0, 0), _i="LINEAR")
    quad(rig, legs, 1.6, 3.4, 1.2, "miniboss", walk_n=30, leg_swing=18, special=sp, hop=0.03)
    rig.finish(icon_yaw=-30, icon_pitch=14)


TABLE = {"eis_schildwall": eis_schildwall, "eis_frostschamanin": eis_frostschamanin, "eis_schneemutter": eis_schneemutter, "eis_mammut": eis_mammut}

if __name__ == "__main__":
    run(TABLE, [a for a in sys.argv if not a.startswith("--")])
