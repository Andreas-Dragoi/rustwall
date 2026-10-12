"""Paket G2 – neue Arten des Sumpfwerks (Mutanten und kaputte Maschinen): Maulwurf-Mutant (Tunnelgräber), EMP-Kriecher
(Turmstörer), Brutkessel (Brutmutter) und der Miniboss Panzerkröte. Abläufe aus enemies2_kit.py.
Aufruf:  python3 blender/enemies2_mutanten.py [art ...] [--notafel]"""
import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from enemies2_kit import *
from enemies_mutanten import TOX, TOX_D, TOX_L, PURP, PURP_D, PIPE, PIPE_D, RUST, MUD, MUD_D, GLOW, INK, WHITE, RED


# ================================================================= Maulwurf-Mutant (Tunnelgräber)
def mutanten_maulwurf():
    rig = Rig("mutanten_maulwurf", role="digger")
    F, F_D, PINK = "8A6AA0", "5E4A70", "F0A0B8"
    rig.node("hips", pivot=(0, 0, 0.45))
    p = Part()                                                                                       # buckliger Leib mit Leuchtwarzen
    lathe(p, [(0.32, 0.35, F_D), (0.48, 0.6, F), (0.5, 0.9, F), (0.4, 1.15, F), (0.22, 1.28, F_D)], sides=10)
    for (x, y, z) in ((0.25, 0.3, 1.05), (-0.3, 0.25, 0.85), (0.05, 0.42, 0.75), (-0.1, 0.32, 1.15)):
        p.ball(0.07, (x, y, z), GLOW, subdiv=1)
    rig.add("body", p, parent="hips", pivot=(0, 0, 0.45))
    p = Part()                                                                                       # Kopf: drei Augen, Rüsselnase
    p.ball(0.3, (0, -0.15, 1.35), F, scale=(1, 1.05, 0.9), subdiv=2)
    lathe(p, [(0.1, 0.0, PINK), (0.09, 0.14, PINK), (0.12, 0.2, "D87A98")], sides=8, loc=(0, -0.42, 1.28), r=rot(90, 0, 0))
    for s in (-1, 1):
        p.ball(0.08, (0.24 * s, -0.08, 1.52), PINK, scale=(1, 0.5, 1), subdiv=1)
    rig.add("head", p, parent="body", pivot=(0, 0, 1.18))
    p = Part()
    for (x, z, r) in ((0.12, 1.47, 0.06), (-0.12, 1.47, 0.06), (0.0, 1.58, 0.07)):
        p.ball(r, (x, -0.38, z), GLOW, subdiv=1)
    rig.add("glow", p, parent="head", pivot=(0, -0.38, 1.5), glow=True)
    for s, nm in ((1, "arm_l"), (-1, "arm_r")):                                                     # riesige Grabklauen
        p = Part()
        capsule(p, (0.42 * s, -0.05, 0.95), (0.55 * s, -0.32, 0.7), 0.1, 0.08, F, sides=5)
        p.ball(0.15, (0.58 * s, -0.38, 0.62), PINK, scale=(1.2, 1, 0.6), subdiv=1)
        for k in range(4):
            p.cone(0.04, 0.2, (0.46 * s + 0.08 * k * s, -0.5, 0.5), "E8E0C8", r=rot(150, 0, 0), sides=4)
        rig.add(nm, p, parent="body", pivot=(0.42 * s, -0.05, 0.95))
    for s, nm in ((1, "leg_l"), (-1, "leg_r")):
        p = Part()
        capsule(p, (0.2 * s, 0, 0.42), (0.22 * s, -0.02, 0.08), 0.09, 0.07, F_D, sides=5)
        p.ball(0.11, (0.22 * s, -0.08, 0.06), PINK, scale=(1, 1.5, 0.5), subdiv=1)
        rig.add(nm, p, parent="hips", pivot=(0.2 * s, 0, 0.45))
    p = Part()                                                                                       # Rohr im Rücken
    capsule(p, (0, 0.38, 0.8), (0.1, 0.55, 1.5), 0.07, 0.06, PIPE, sides=6)
    p.cyl(0.1, 0.08, (0.1, 0.56, 1.52), RUST, sides=8)
    rig.add("prop", p, parent="body", pivot=(0, 0.4, 0.8))
    mound(rig, 0.55, MUD, MUD_D)
    biped(rig, 0.45, 1.7, 2.5, "digger", walk_n=18, leg_swing=32)
    rig.finish(icon_yaw=-24, icon_pitch=12)


# ================================================================= EMP-Kriecher (Turmstörer)
def mutanten_stoerer():
    rig = Rig("mutanten_stoerer", role="jammer")
    rig.node("hips", pivot=(0, 0, 0.6))
    p = Part()                                                                                       # gebückter Leib im Overall
    lathe(p, [(0.24, 0.55, "4A6A8A"), (0.32, 0.7, "5A7A9A"), (0.34, 1.0, "5A7A9A"), (0.26, 1.2, "4A6A8A"), (0.14, 1.3, "4A6A8A")], sides=9)
    p.box((0.46, 0.06, 0.3), (0, -0.3, 0.85), TOX_D, bevel=0.03, segs=1)                            # Warnschild auf der Brust
    p.box((0.12, 0.04, 0.12), (0, -0.34, 0.85), "FFD23E", r=rot(0, 45, 0), bevel=0.0)
    rig.add("body", p, parent="hips", pivot=(0, 0, 0.6))
    p = Part()                                                                                       # Kopf: Taucherhelm-Mutant mit Antenne
    p.ball(0.26, (0, -0.12, 1.45), TOX, scale=(1, 1, 0.95), subdiv=2)
    p.cyl(0.18, 0.06, (0, -0.33, 1.47), PIPE, r=rot(90, 0, 0), sides=10)
    p.cyl(0.14, 0.07, (0, -0.35, 1.47), "2A3A3A", r=rot(90, 0, 0), sides=10)
    capsule(p, (0.1, 0.0, 1.65), (0.2, 0.05, 2.0), 0.02, 0.015, PIPE_D, sides=4)
    rig.add("head", p, parent="body", pivot=(0, 0, 1.28))
    p = Part()
    p.ball(0.06, (0.2, 0.05, 2.02), "8AE8FF", subdiv=1)
    for s in (-1, 1):
        p.ball(0.04, (0.06 * s, -0.4, 1.5), "8AE8FF", subdiv=1)
    rig.add("glow", p, parent="head", pivot=(0, -0.3, 1.6), glow=True)
    p = Part()                                                                                       # Satellitenschüssel auf dem Rücken
    m = T(0, 0.38, 1.45) @ rot(-60, 0, 0)
    lathe(p, [(0.0, 0.0, PIPE_D), (0.3, 0.08, PIPE), (0.42, 0.16, PIPE), (0.44, 0.18, PIPE_D)], sides=12, r=m, cap=False)
    p.cyl(0.03, 0.4, tuple(m @ Vector((0, 0, 0.25))), PIPE_D, r=rot(-60, 0, 0), sides=5)
    p.box((0.2, 0.2, 0.3), (0, 0.3, 1.05), "3A3A42", bevel=0.03, segs=1)
    rig.add("prop", p, parent="body", pivot=(0, 0.35, 1.2))
    p = Part()
    capsule(p, (0.28, 0, 1.12), (0.4, -0.2, 0.82), 0.06, 0.05, "5A7A9A", sides=5)
    p.ball(0.07, (0.42, -0.22, 0.78), TOX_D, subdiv=1)
    rig.add("arm_l", p, parent="body", pivot=(0.28, 0, 1.12))
    p = Part()                                                                                       # Arm mit EMP-Kugel
    capsule(p, (-0.28, 0, 1.12), (-0.4, -0.25, 0.9), 0.06, 0.05, "5A7A9A", sides=5)
    p.ball(0.07, (-0.42, -0.28, 0.86), TOX_D, subdiv=1)
    rig.add("arm_r", p, parent="body", pivot=(-0.28, 0, 1.12))
    p = Part()
    p.ball(0.13, (-0.42, -0.36, 0.95), "8AE8FF", subdiv=1)
    p.torus(0.17, 0.02, (-0.42, -0.36, 0.95), "C8F4FF", r=rot(30, 40, 0), seg=10, tseg=3)
    rig.add("tool", p, parent="arm_r", pivot=(-0.42, -0.36, 0.95), glow=True)
    for s, nm in ((1, "leg_l"), (-1, "leg_r")):
        p = Part()
        capsule(p, (0.13 * s, 0, 0.56), (0.15 * s, 0, 0.08), 0.07, 0.06, "3A4A5A", sides=5)
        p.ball(0.09, (0.15 * s, -0.07, 0.06), INK, scale=(1, 1.4, 0.55), subdiv=1)
        rig.add(nm, p, parent="hips", pivot=(0.13 * s, 0, 0.6))
    biped(rig, 0.6, 2.05, 2.3, "jammer", walk_n=21)
    rig.finish(icon_yaw=-24, icon_pitch=12)


# ================================================================= Brutkessel (Brutmutter)
def mutanten_brutkessel():
    rig = Rig("mutanten_brutkessel", role="brood")
    p = Part()                                                                                       # Kessel mit Nieten, Bullauge und Ventilen
    lathe(p, [(0.55, 0.9, PIPE_D), (0.75, 1.05, PIPE), (0.8, 1.5, PIPE), (0.72, 1.85, PIPE), (0.5, 2.0, PIPE_D), (0.3, 2.05, PIPE_D)], sides=12)
    for k in range(10):
        a = k * math.tau / 10
        p.ball(0.04, (0.8 * math.cos(a), 0.8 * math.sin(a), 1.25), PIPE_D, subdiv=1)
    p.cyl(0.24, 0.1, (0, -0.78, 1.45), RUST, r=rot(90, 0, 0), sides=12)
    p.cyl(0.18, 0.12, (0, -0.8, 1.45), TOX, r=rot(90, 0, 0), sides=12)
    capsule(p, (0.5, 0.3, 1.8), (0.65, 0.4, 2.3), 0.07, 0.06, RUST, sides=6)                        # Schornstein
    p.torus(0.14, 0.03, (-0.5, 0.2, 1.9), RED, r=rot(0, 70, 0), seg=10, tseg=3)                     # Ventilrad
    rig.add("body", p, pivot=(0, 0, 1.2))
    p = Part()                                                                                       # Deckel, der beim Brüten springt
    lathe(p, [(0.32, 2.02, PIPE_D), (0.34, 2.08, PIPE), (0.2, 2.18, PIPE), (0.0, 2.2, PIPE)], sides=10)
    p.ball(0.06, (0, 0, 2.24), RED, subdiv=1)
    rig.add("prop", p, parent="body", pivot=(0, 0, 2.05))
    p = Part()                                                                                       # brodelnde Giftsuppe
    p.ball(0.3, (0, 0, 2.02), TOX_L, scale=(1, 1, 0.3), subdiv=1)
    p.ball(0.08, (0.12, -0.08, 2.1), GLOW, subdiv=1)
    rig.add("glow", p, parent="body", pivot=(0, 0, 2.02), glow=True)
    p = Part()                                                                                       # Augen am Bullauge (Kröte schaut heraus)
    p.ball(0.08, (0.06, -0.86, 1.5), WHITE, subdiv=1)
    p.ball(0.045, (0.06, -0.92, 1.5), INK, subdiv=1)
    rig.add("head", p, parent="body", pivot=(0, -0.86, 1.5))
    legs = []
    for (nm, a, ph, s) in (("leg_fl", -50, 0.0, 1), ("leg_fr", -130, 0.5, -1), ("leg_bl", 50, 0.5, 1), ("leg_br", 130, 0.0, -1)):
        x, y = math.cos(math.radians(a)), math.sin(math.radians(a))
        p = Part()                                                                                   # Stelzbeine aus Rohren
        capsule(p, (0.55 * x, 0.55 * y, 1.0), (0.85 * x, 0.85 * y, 0.55), 0.07, 0.06, PIPE_D, sides=5)
        capsule(p, (0.85 * x, 0.85 * y, 0.55), (0.9 * x, 0.9 * y, 0.05), 0.06, 0.05, RUST, sides=5)
        p.cyl(0.12, 0.06, (0.9 * x, 0.9 * y, 0.03), INK, sides=8)
        rig.add(nm, p, parent="body", pivot=(0.55 * x, 0.55 * y, 1.0))
        legs.append((nm, ph, s))
    def sp(name, c, rig, rest):
        if name == "brood":                                            # Deckel hüpft, Suppe kocht über
            K(c, rig, 12, prop=dict(loc=(0, 0, 0.25), rot=(20, 0, 0), scale=1.0))
            K(c, rig, 16, prop=dict(loc=(0, 0, 0.0), rot=(0, 0, 0)))
            K(c, rig, 18, prop=dict(loc=(0, 0, 0.35), rot=(-25, 0, 10)), glow=dict(scale=1.8), _i="LINEAR")
            K(c, rig, 24, prop=dict(loc=(0, 0, 0), rot=(0, 0, 0), scale=1.0), glow=dict(scale=1.0))
        if name == "idle":
            K(c, rig, 6, prop=dict(loc=(0, 0, 0.05)))
            K(c, rig, 9, prop=dict(loc=(0, 0, 0)))
    quad(rig, legs, 1.0, 2.3, 1.3, "brood", walk_n=24, leg_swing=22, special=sp)
    rig.finish(icon_yaw=-26, icon_pitch=16)


# ================================================================= Panzerkröte (Miniboss)
def mutanten_panzerkroete():
    rig = Rig("mutanten_panzerkroete", role="miniboss")
    p = Part()                                                                                       # massiger Krötenleib mit Panzerplatten
    p.ball(1.2, (0, 0.1, 1.1), TOX_D, scale=(1, 1.1, 0.75), subdiv=2)
    p.ball(0.9, (0, -0.3, 0.75), "D8E8A0", scale=(1, 0.9, 0.6), subdiv=2)                            # heller Bauch
    for (x, y, z, w) in ((0.0, 0.2, 1.95, 1.0), (0.6, 0.3, 1.75, 0.6), (-0.6, 0.3, 1.75, 0.6), (0.0, 0.85, 1.6, 0.8)):
        p.box((w, 0.7, 0.14), (x, y, z), PIPE, r=rot(-8, 6 * x, 0), bevel=0.05, segs=1)
    for (x, y) in ((0.3, 0.5), (-0.35, 0.6), (0.0, -0.1)):                                           # Rohre auf dem Rücken
        capsule(p, (x, y, 1.9), (x * 1.3, y + 0.3, 2.6), 0.1, 0.09, RUST, sides=6)
        p.cyl(0.13, 0.08, (x * 1.3, y + 0.3, 2.62), PIPE_D, sides=8)
    rig.add("body", p, pivot=(0, 0, 1.0))
    p = Part()                                                                                       # breites Maul, Glupschaugen
    p.ball(0.75, (0, -0.95, 1.3), TOX, scale=(1.1, 0.8, 0.6), subdiv=2)
    p.box((1.3, 0.1, 0.06), (0, -1.55, 1.15), "4A2A3A", bevel=0.02, segs=1)
    for s in (-1, 1):
        p.ball(0.28, (0.45 * s, -0.95, 1.75), TOX_L, subdiv=2)
    rig.add("head", p, parent="body", pivot=(0, -0.7, 1.2))
    p = Part()
    for s in (-1, 1):
        p.ball(0.2, (0.45 * s, -1.12, 1.82), WHITE, subdiv=1)
        p.ball(0.1, (0.45 * s, -1.28, 1.84), INK, subdiv=1)
    p.ball(0.12, (0, -1.0, 1.95), GLOW, subdiv=1)                                                    # drittes Auge leuchtet
    rig.add("glow", p, parent="head", pivot=(0, -1.1, 1.85), glow=True)
    legs = []
    for (nm, x, y, ph, s) in (("leg_fl", 0.85, -0.55, 0.0, 1), ("leg_fr", -0.85, -0.55, 0.5, -1), ("leg_bl", 1.0, 0.65, 0.5, 1), ("leg_br", -1.0, 0.65, 0.0, -1)):
        p = Part()
        capsule(p, (x, y, 0.9), (x * 1.25, y - 0.1, 0.15), 0.28, 0.2, TOX_D, sides=7)
        p.ball(0.3, (x * 1.3, y - 0.25, 0.08), TOX, scale=(1.2, 1.4, 0.4), subdiv=1)
        rig.add(nm, p, parent="body", pivot=(x, y, 0.9))
        legs.append((nm, ph, s))
    def sp(name, c, rig, rest):
        if name == "skill":                                            # bläht die Kehle und spuckt Giftblasen
            K(c, rig, 10, head=dict(rot=(-25, 0, 0), scale=(1.15, 1.1, 1.2)))
            K(c, rig, 27, head=dict(rot=(20, 0, 0), scale=(0.95, 1.0, 0.9)), _i="LINEAR")
    quad(rig, legs, 1.0, 2.7, 1.2, "miniboss", walk_n=30, leg_swing=20, special=sp, hop=0.08)
    rig.finish(icon_yaw=-26, icon_pitch=14)


TABLE = {"mutanten_maulwurf": mutanten_maulwurf, "mutanten_stoerer": mutanten_stoerer, "mutanten_brutkessel": mutanten_brutkessel, "mutanten_panzerkroete": mutanten_panzerkroete}

if __name__ == "__main__":
    run(TABLE, [a for a in sys.argv if not a.startswith("--")])
