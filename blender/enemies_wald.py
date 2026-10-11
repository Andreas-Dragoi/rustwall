"""Waldgeister und Pilzvolk (Kiefernforst): sechs Arten + Boss nach dem Muster von enemies_untote.py (siehe blender/GEGNER.md).
Aufruf:  python3 blender/enemies_wald.py [art ...] [--notafel]
"""
import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from animkit import *

# Farben der Familie: Moos, Rinde, Fliegenpilz, Glühwürmchen
CAP, CAP_D, DOT = "E2372F", "A9221F", "FFF6E4"
STEM, STEM_D = "F4E2C0", "D8BF95"
BARK, BARK_D, BARK_L = "8A5A32", "5E3B20", "B07A48"
MOSS, MOSS_D, LEAF, LEAF_L = "5FA83A", "3E7A2A", "4FB848", "9BDB5A"
THORN = "E9D79A"
INK = "1A1A22"
WHITE = "F8F8F2"
GLOW_Y, GLOW_B = "FFE04A", "7FD8FF"
PINK = "F08AA0"


def spawn_clip(rig, depth=1.0, n=24):
    """Besonderer Clip „spawn“: taucht wackelnd aus dem Boden auf (wenn ein Boss ruft oder ein Portal ausspuckt)."""
    with rig.clip("spawn", n) as c:
        c.key(0, root=dict(loc=(0, 0, -depth), rot=(0, 0, -40), scale=(0.6, 0.6, 0.6)))
        c.key(int(n * 0.55), root=dict(loc=(0, 0, 0.15 * depth), rot=(0, 0, 15), scale=(0.95, 0.95, 1.12)))
        c.key(int(n * 0.8), root=dict(loc=(0, 0, 0), rot=(0, 0, -5), scale=(1.08, 1.08, 0.92)))
        c.key(n, root=dict(loc=(0, 0, 0), rot=(0, 0, 0), scale=(1, 1, 1)))


def R(x=0, y=0, z=0):
    return dict(rot=(x, y, z))


def eyes(p, x, y, z, r, color=WHITE, sub=1):
    for s in (-1, 1):
        p.ball(r, (x * s, y, z), color, scale=(1, 0.6, 1.1), subdiv=sub)


# ================================================================= Pilzling (Masse): kniehoher Fliegenpilz mit Beinchen
def wald_pilzling():
    rig = Rig("wald_pilzling", role="mass", size=1.0)
    # ---- Stiel = Körper (dicker Bauch, Pilzring als Rüschenkragen)
    p = Part()
    lathe(p, [(0.16, 0.16, STEM_D), (0.24, 0.24, STEM), (0.27, 0.42, STEM), (0.24, 0.58, STEM), (0.3, 0.62, DOT), (0.2, 0.66, STEM), (0.18, 0.78, STEM)], sides=9, sy=0.9)
    p.box((0.13, 0.03, 0.04), (0, -0.25, 0.38), "8A2A2A", bevel=0.0)                         # Mund
    p.cone(0.022, 0.05, (0.03, -0.26, 0.35), WHITE, r=rot(180, 0, 0), sides=3)                # Zähnchen
    p.ball(0.045, (0.13, -0.2, 0.42), PINK, scale=(1, 0.4, 0.7), subdiv=1)                    # Bäckchen
    p.ball(0.045, (-0.13, -0.2, 0.42), PINK, scale=(1, 0.4, 0.7), subdiv=1)
    eyes(p, 0.075, -0.22, 0.5, 0.06, WHITE, 1)
    rig.add("body", p, pivot=(0, 0, 0.2))
    p = Part()
    for s in (-1, 1):
        p.ball(0.032, (0.075 * s, -0.27, 0.49), INK, scale=(1, 0.5, 1.1), subdiv=1)
    rig.add("pupil", p, parent="body", pivot=(0, -0.26, 0.49), look=True)
    # ---- roter Hut mit weißen Punkten (wippt, platzt beim Tod)
    p = Part()
    lathe(p, [(0.2, 0.7, STEM_D), (0.48, 0.7, CAP_D), (0.5, 0.76, CAP), (0.44, 0.9, CAP), (0.3, 1.0, CAP), (0.0, 1.05, CAP)], sides=10, sy=0.95)
    for (x, y, z, r) in ((0.0, 0.0, 1.03, 0.07), (0.27, -0.12, 0.92, 0.06), (-0.25, -0.18, 0.9, 0.065), (0.12, 0.28, 0.95, 0.06), (-0.22, 0.2, 0.93, 0.055), (0.05, -0.33, 0.86, 0.05)):
        p.ball(r, (x, y, z), DOT, scale=(1, 1, 0.45), subdiv=1)
    rig.add("cap", p, parent="body", pivot=(0, 0, 0.72))
    # ---- Ärmchen und Beinchen
    for s, nm in ((1, "arm_l"), (-1, "arm_r")):
        p = Part()
        capsule(p, (0.25 * s, 0, 0.5), (0.36 * s, -0.04, 0.32), 0.04, 0.035, STEM_D, sides=5)
        p.ball(0.05, (0.37 * s, -0.05, 0.29), STEM, subdiv=1)
        rig.add(nm, p, parent="body", pivot=(0.25 * s, 0, 0.5))
    for s, nm in ((1, "leg_l"), (-1, "leg_r")):
        p = Part()
        capsule(p, (0.1 * s, 0, 0.2), (0.11 * s, 0, 0.06), 0.05, 0.045, STEM_D, sides=5)
        p.ball(0.075, (0.11 * s, -0.04, 0.04), "6B4A2E", scale=(0.9, 1.4, 0.55), subdiv=1)  # Holzschühchen
        rig.add(nm, p, pivot=(0.1 * s, 0, 0.2))

    rest = dict(root=dict(loc=(0, 0, 0), rot=(0, 0, 0)), body=dict(loc=(0, 0, 0), rot=(0, 0, 0), scale=1.0), cap=dict(loc=(0, 0, 0), rot=(0, 0, 0), scale=1.0),
                arm_l=R(), arm_r=R(), leg_l=R(), leg_r=R())
    with rig.clip("idle", 36, loop=True) as c:                     # wiegt sich, der Hut wippt nach
        c.key(0, **rest)
        c.key(9, body=dict(rot=(0, 6, 0), scale=(1.03, 1.03, 0.96)), cap=R(0, -8, 0), arm_l=R(0, 20, 0), arm_r=R(0, 10, 0))
        c.key(18, body=dict(rot=(0, 0, 0), scale=(0.97, 0.97, 1.04)), cap=R(4, 0, 0))
        c.key(27, body=dict(rot=(0, -6, 0), scale=(1.03, 1.03, 0.96)), cap=R(0, 8, 0), arm_l=R(0, -10, 0), arm_r=R(0, -20, 0))
    with rig.clip("walk", 15, loop=True, stride=1.1) as c:         # watschelt: Beinchen trippeln, Körper schaukelt
        c.wave("leg_l", rot=(40, 0, 0), phase=0.0)
        c.wave("leg_r", rot=(40, 0, 0), phase=0.5)
        c.wave("body", rot=(0, 9, 0), loc=(0, 0, 0.0), phase=0.25)
        c.wave("cap", rot=(6, -10, 0), phase=0.4)
        c.wave("arm_l", rot=(-35, 0, 0), phase=0.5)
        c.wave("arm_r", rot=(-35, 0, 0), phase=0.0)
        c.wave("root", loc=(0, 0, 0.05), n=2, phase=0.25)
    with rig.clip("attack", 18, hit=10) as c:                       # holt aus und rammt mit dem Hut
        c.key(0, **rest)
        c.key(7, body=dict(rot=(-24, 0, 0), scale=(0.95, 0.95, 1.08)), cap=R(-12, 0, 0), arm_l=R(-60, 0, 30), arm_r=R(-60, 0, -30), root=dict(loc=(0, 0.1, 0)))
        c.key(10, body=dict(rot=(38, 0, 0), scale=(1.05, 1.05, 0.95)), cap=R(16, 0, 0), arm_l=R(30, 0, 0), arm_r=R(30, 0, 0), root=dict(loc=(0, -0.25, 0)), _i="LINEAR")
        c.key(14, body=dict(rot=(20, 0, 0)), root=dict(loc=(0, -0.2, 0)))
        c.key(18, **rest)
    with rig.clip("hit", 9) as c:                                   # Hut springt hoch, Körper staucht
        c.key(0, **rest)
        c.key(3, body=dict(rot=(-14, 0, 0), scale=(1.15, 1.15, 0.8)), cap=dict(loc=(0, 0, 0.14), rot=(-10, 0, 8)))
        c.key(9, **rest)
    with rig.clip("death", 27) as c:                                # bläht sich auf und – puff – platzt in eine Sporenwolke
        c.key(0, **rest)
        c.key(9, body=dict(scale=(1.25, 1.25, 1.1), rot=(0, 10, 0)), cap=dict(scale=(1.12, 1.12, 1.08)), arm_l=R(0, 60, 0), arm_r=R(0, -60, 0))
        c.key(13, body=dict(scale=(1.45, 1.45, 0.8)), cap=dict(scale=(1.2, 1.2, 0.9), loc=(0, 0, 0.1)), _i="LINEAR")
        c.key(16, body=dict(scale=(0.4, 0.4, 0.2)), cap=dict(scale=(0.5, 0.5, 0.2), loc=(0.2, 0.3, 0.3), rot=(70, 0, 30)), leg_l=R(0, -60, 0), leg_r=R(0, 60, 0))
        c.key(27, body=dict(scale=(0.3, 0.3, 0.05)), cap=dict(scale=(0.6, 0.6, 0.5), loc=(0.3, 0.45, -0.5), rot=(170, 0, 30)), root=dict(loc=(0, 0, 0)))
    with rig.clip("spawn", 24) as c:                                # wächst aus dem Boden
        c.key(0, root=dict(loc=(0, 0, -0.9)), body=dict(scale=(0.6, 0.6, 0.6)), cap=dict(scale=0.5))
        c.key(12, root=dict(loc=(0, 0, -0.2)), body=dict(scale=(0.9, 0.9, 1.2)), cap=dict(scale=0.8))
        c.key(18, root=dict(loc=(0, 0, 0.08)), body=dict(scale=(1.1, 1.1, 0.9)), cap=dict(scale=1.15))
        c.key(24, **rest)
    rig.finish()


# ================================================================= Dornenwolf (Flitzer): Wolf aus Ranken und Dornen
def wald_dornenwolf():
    rig = Rig("wald_dornenwolf", role="fast", size=1.0)
    V1, V2 = "4E7A2C", "6A9A34"
    # ---- Rumpf aus zwei verdrehten Rankenbündeln mit Dornen
    p = Part()
    lathe(p, [(0.06, -0.05, V1), (0.2, 0.05, V2), (0.24, 0.3, V1), (0.22, 0.6, V2), (0.14, 0.8, V1), (0.05, 0.86, V1)], sides=7, loc=(0, -0.45, 0.62), r=rot(-92, 0, 0), sy=0.85)
    for i, y in enumerate((-0.34, -0.14, 0.06, 0.26)):
        p.cone(0.045, 0.2, (0.0, y, 0.86 + 0.02 * (i % 2)), THORN, r=rot(-28, 0, 0), sides=4)
        p.cone(0.035, 0.14, (0.17, y + 0.06, 0.74), THORN, r=rot(-20, -60, 0), sides=4)
        p.cone(0.035, 0.14, (-0.17, y + 0.06, 0.74), THORN, r=rot(-20, 60, 0), sides=4)
    p.ball(0.06, (0.12, -0.3, 0.72), "E0507A", subdiv=1)                                         # wilde Rosenblüten
    p.ball(0.05, (-0.1, 0.18, 0.78), "E0507A", subdiv=1)
    rig.add("body", p, pivot=(0, 0, 0.62))
    # ---- Kopf: spitze Schnauze, Blattohren, gelbe Glutaugen
    p = Part()
    p.ball(0.19, (0, -0.58, 0.82), V2, scale=(1, 1.05, 0.9), subdiv=2)
    lathe(p, [(0.12, 0.0, V2), (0.08, 0.18, V1), (0.035, 0.28, INK)], sides=6, loc=(0, -0.68, 0.78), r=rot(98, 0, 0), sy=0.75)
    for s in (-1, 1):
        p.cone(0.08, 0.26, (0.11 * s, -0.52, 1.02), LEAF, r=rot(-10, 20 * s, 0), sides=4)
        p.cone(0.03, 0.08, (0.04 * s, -0.86, 0.71), THORN, r=rot(180, 0, 0), sides=3)            # Fang
    rig.add("head", p, parent="body", pivot=(0, -0.48, 0.78))
    p = Part()
    for s in (-1, 1):
        p.ball(0.045, (0.085 * s, -0.73, 0.87), GLOW_Y, scale=(1.2, 0.5, 0.7), subdiv=1)
    rig.add("eyes", p, parent="head", pivot=(0, -0.72, 0.87), glow=True)
    p = Part()
    lathe(p, [(0.07, 0.0, V1), (0.045, 0.16, V1), (0.02, 0.24, V1)], sides=5, loc=(0, -0.66, 0.7), r=rot(100, 0, 0), sy=0.5)
    rig.add("jaw", p, parent="head", pivot=(0, -0.62, 0.72))
    # ---- buschiger Rankenschwanz (zwei Glieder) mit Dornen
    p = Part()
    capsule(p, (0, 0.38, 0.72), (0, 0.66, 0.76), 0.07, 0.06, V1, sides=5)
    p.cone(0.03, 0.12, (0, 0.52, 0.8), THORN, r=rot(-40, 0, 0), sides=3)
    rig.add("tail1", p, parent="body", pivot=(0, 0.38, 0.72))
    p = Part()
    capsule(p, (0, 0.66, 0.76), (0, 0.9, 0.86), 0.06, 0.03, V2, sides=5)
    p.ball(0.09, (0, 0.95, 0.88), LEAF, scale=(1, 1, 1.4), subdiv=1)
    rig.add("tail2", p, parent="tail1", pivot=(0, 0.66, 0.76))
    # ---- vier Rankenbeine
    for nm, x, y in (("leg_fl", 0.13, -0.32), ("leg_fr", -0.13, -0.32), ("leg_bl", 0.13, 0.3), ("leg_br", -0.13, 0.3)):
        p = Part()
        capsule(p, (x, y, 0.6), (x * 1.1, y + 0.03, 0.06), 0.055, 0.035, V1, sides=5)
        p.ball(0.06, (x * 1.1, y - 0.03, 0.04), BARK_D, scale=(1, 1.4, 0.6), subdiv=1)
        rig.add(nm, p, parent="body", pivot=(x, y, 0.6))

    rest = dict(root=dict(loc=(0, 0, 0), rot=(0, 0, 0)), body=dict(loc=(0, 0, 0), rot=(0, 0, 0)), head=R(), jaw=R(), tail1=R(10, 0, 0), tail2=R(10, 0, 0),
                leg_fl=R(), leg_fr=R(), leg_bl=R(), leg_br=R())
    with rig.clip("idle", 30, loop=True) as c:                      # hechelt, schnüffelt, wedelt
        c.key(0, **rest)
        c.key(6, jaw=R(-14, 0, 0), head=R(-6, 0, 10), tail1=R(10, 0, 20))
        c.key(12, jaw=R(0, 0, 0), body=dict(loc=(0, 0, -0.02)))
        c.key(18, jaw=R(-14, 0, 0), head=R(6, 0, -12), tail1=R(10, 0, -20), tail2=R(10, 0, -20))
        c.key(24, jaw=R(0, 0, 0), body=dict(loc=(0, 0, 0)))
    with rig.clip("walk", 12, loop=True, stride=2.1) as c:          # Galopp
        c.wave("leg_fl", rot=(50, 0, 0), phase=0.0)
        c.wave("leg_fr", rot=(50, 0, 0), phase=0.1)
        c.wave("leg_bl", rot=(50, 0, 0), phase=0.5)
        c.wave("leg_br", rot=(50, 0, 0), phase=0.6)
        c.wave("body", rot=(8, 0, 0), loc=(0, 0, 0.06), phase=0.25)
        c.wave("head", rot=(-10, 0, 0), phase=0.5)
        c.wave("tail1", rot=(16, 0, 0), base_rot=(-20, 0, 0), phase=0.75)
        c.wave("jaw", rot=(-10, 0, 0), base_rot=(-10, 0, 0), phase=0.0)
    with rig.clip("attack", 15, hit=8) as c:                        # schnappt zu
        c.key(0, **rest)
        c.key(5, body=dict(rot=(-10, 0, 0), loc=(0, 0.1, 0)), head=R(-20, 0, 0), jaw=R(-40, 0, 0))
        c.key(8, body=dict(rot=(10, 0, 0), loc=(0, -0.3, 0)), head=R(10, 0, 0), jaw=R(0, 0, 0), leg_fl=R(-50, 0, 0), leg_fr=R(-50, 0, 0), _i="LINEAR")
        c.key(15, **rest)
    with rig.clip("pounce", 15, hit=10) as c:                       # Sprung (0,45 s): duckt sich, fliegt gestreckt, landet
        c.key(0, **rest)
        c.key(3, body=dict(rot=(-8, 0, 0), loc=(0, 0.1, -0.15)), leg_bl=R(30, 0, 0), leg_br=R(30, 0, 0), head=R(-10, 0, 0))
        c.key(7, root=dict(loc=(0, -0.4, 0.8)), body=dict(rot=(-14, 0, 0), loc=(0, 0, 0)), leg_fl=R(-80, 0, 0), leg_fr=R(-80, 0, 0), leg_bl=R(60, 0, 0), leg_br=R(60, 0, 0), jaw=R(-45, 0, 0), tail1=R(-50, 0, 0))
        c.key(11, root=dict(loc=(0, -0.9, 0.1)), body=dict(rot=(16, 0, 0)), jaw=R(0, 0, 0), leg_fl=R(-30, 0, 0), leg_fr=R(-30, 0, 0))
        c.key(15, **rest)
    with rig.clip("hit", 9) as c:
        c.key(0, **rest)
        c.key(3, body=dict(rot=(-12, 0, 10), loc=(0, 0.15, 0.05)), head=R(-20, 0, -14), jaw=R(-30, 0, 0), tail1=R(-40, 0, 0))
        c.key(9, **rest)
    with rig.clip("death", 30) as c:                                # kippt um, die Ranken lösen sich
        c.key(0, **rest)
        c.key(8, root=dict(rot=(0, 30, 0), loc=(0, 0, 0.15)), head=R(-30, 0, 0), jaw=R(-40, 0, 0))
        c.key(16, root=dict(rot=(0, 88, 0), loc=(0, 0, 0.2)), leg_fl=R(-30, 0, 0), leg_bl=R(30, 0, 0), leg_fr=R(-10, 0, 20), leg_br=R(10, 0, 20), tail1=R(0, 0, 0))
        c.key(30, root=dict(rot=(0, 90, 0), loc=(0, 0, 0.16)), body=dict(loc=(0, 0, -0.05)), head=R(10, 0, 0), jaw=R(-20, 0, 0), eyes=dict(scale=0.05))
    rig.finish()


# ================================================================= Baumhüter (Brocken): wandelnder Baumstamm mit Vogelnest
def wald_baumhueter():
    rig = Rig("wald_baumhueter", role="tank", size=1.0)
    rig.node("hips", pivot=(0, 0, 0.9))
    # ---- Stamm mit Rindenringen, Gesicht als Astlöcher
    p = Part()
    lathe(p, [(0.62, 0.8, BARK_D), (0.66, 1.0, BARK), (0.6, 1.4, BARK_L), (0.64, 1.8, BARK), (0.56, 2.2, BARK_L), (0.6, 2.5, BARK), (0.5, 2.75, BARK_D), (0.0, 2.8, "C9A06A")], sides=11, sy=0.92)
    for (x, y, z, rr) in ((0.3, -0.5, 1.2, 0.09), (-0.4, -0.45, 1.6, 0.07), (0.5, 0.2, 2.0, 0.08), (-0.45, 0.3, 1.1, 0.08)):
        p.ball(rr, (x, y, z), BARK_D, scale=(1, 0.5, 1.5), subdiv=1)                        # Rindenknoten
    p.ball(0.15, (0, -0.55, 1.62), INK, scale=(1.6, 0.35, 0.7), subdiv=1)                    # Mundloch
    for s in (-1, 1):
        p.ball(0.12, (0.2 * s, -0.53, 2.08), INK, scale=(1, 0.4, 1.1), subdiv=1)              # Augenhöhlen
        p.box((0.24, 0.06, 0.06), (0.21 * s, -0.56, 2.24), BARK_D, r=rot(0, -18 * s, 0), bevel=0.0)  # finstere Brauen
    # Moospolster und Pilze an der Seite
    p.ball(0.3, (0.35, -0.3, 2.62), MOSS, scale=(1.1, 1, 0.45), subdiv=2)
    p.ball(0.26, (-0.4, 0.1, 2.58), MOSS_D, scale=(1.1, 1.2, 0.45), subdiv=1)
    for (x, y, z) in ((0.6, -0.15, 1.4), (0.62, -0.05, 1.28)):
        p.cyl(0.03, 0.08, (x, y, z), STEM, sides=5)
        p.ball(0.09, (x + 0.02, y, z + 0.05), CAP, scale=(1, 1, 0.45), subdiv=1)
    rig.add("trunk", p, parent="hips", pivot=(0, 0, 0.9))
    p = Part()
    for s in (-1, 1):
        p.ball(0.06, (0.2 * s, -0.6, 2.08), GLOW_Y, subdiv=1)
    rig.add("eyes", p, parent="trunk", pivot=(0, -0.6, 2.08), glow=True)
    # ---- Krone: Vogelnest mit einem frechen Vogel
    p = Part()
    p.torus(0.32, 0.1, (0, 0, 2.86), "9C7444", seg=10, tseg=5)
    p.ball(0.26, (0, 0, 2.86), "6B4A2E", scale=(1, 1, 0.3), subdiv=1)
    for i in range(3):
        a = i * 2.1
        p.ball(0.07, (math.cos(a) * 0.12, math.sin(a) * 0.12, 2.95), "BFE4F2", scale=(1, 1, 1.25), subdiv=1)
    rig.add("nest", p, parent="trunk", pivot=(0, 0, 2.8))
    p = Part()
    p.ball(0.13, (0.12, 0.05, 3.1), "4FA0E0", scale=(1, 1.15, 1), subdiv=1)
    p.ball(0.09, (0.12, -0.08, 3.24), "4FA0E0", subdiv=1)
    p.cone(0.04, 0.12, (0.12, -0.18, 3.23), "FFB020", r=rot(90, 0, 0), sides=4)
    p.ball(0.025, (0.16, -0.14, 3.28), INK, subdiv=1)
    p.ball(0.025, (0.08, -0.14, 3.28), INK, subdiv=1)
    rig.add("bird", p, parent="nest", pivot=(0.12, 0.05, 3.0))
    # ---- Astarme mit Blätterbüscheln
    for s, nm in ((1, "arm_l"), (-1, "arm_r")):
        p = Part()
        capsule(p, (0.55 * s, 0, 2.2), (1.0 * s, -0.1, 1.6), 0.16, 0.12, BARK, sides=6)
        capsule(p, (0.85 * s, -0.05, 1.8), (1.15 * s, -0.05, 2.15), 0.06, 0.04, BARK_L, sides=5)
        p.ball(0.2, (1.17 * s, -0.05, 2.25), LEAF, subdiv=1)
        rig.add(nm, p, parent="trunk", pivot=(0.55 * s, 0, 2.2))
        p = Part()
        capsule(p, (1.0 * s, -0.1, 1.6), (1.05 * s, -0.3, 1.0), 0.12, 0.1, BARK, sides=6)
        for k in range(3):
            capsule(p, (1.05 * s, -0.3, 1.0), (1.05 * s + 0.15 * (k - 1), -0.45, 0.78), 0.06, 0.03, BARK_D, sides=4)   # Zweigfinger
        p.ball(0.18, (1.0 * s, -0.1, 1.38), LEAF_L, scale=(1, 1, 0.8), subdiv=1)
        rig.add(nm.replace("arm", "fore"), p, parent=nm, pivot=(1.0 * s, -0.1, 1.6))
    # ---- Wurzelbeine
    for s, nm in ((1, "leg_l"), (-1, "leg_r")):
        p = Part()
        lathe(p, [(0.1, 0.0, BARK_D), (0.3, 0.05, BARK_D), (0.24, 0.3, BARK), (0.22, 0.9, BARK)], sides=7, loc=(0.32 * s, 0, 0))
        for k in range(3):
            capsule(p, (0.32 * s, 0, 0.1), (0.32 * s + 0.35 * math.cos(k * 1.4 + 0.6) * s, -0.35 * math.sin(k * 1.4 + 0.6), 0.02), 0.07, 0.03, BARK_D, sides=4)
        rig.add(nm, p, parent="hips", pivot=(0.32 * s, 0, 0.9))
    # ---- Wurzeln, die beim Festwurzeln ausfahren
    p = Part()
    for k in range(6):
        a = k * math.pi / 3 + 0.3
        capsule(p, (0.3 * math.cos(a), 0.3 * math.sin(a), 0.1), (1.3 * math.cos(a), 1.3 * math.sin(a), 0.0), 0.09, 0.03, BARK_D, sides=4)
    rig.add("roots", p, pivot=(0, 0, 0.0))

    rest = dict(root=dict(loc=(0, 0, 0), rot=(0, 0, 0)), hips=dict(loc=(0, 0, 0), rot=(0, 0, 0)), trunk=R(), arm_l=R(), arm_r=R(), fore_l=R(), fore_r=R(),
                leg_l=R(), leg_r=R(), nest=R(), bird=dict(loc=(0, 0, 0), rot=(0, 0, 0)), roots=dict(scale=(0.05, 0.05, 0.05), loc=(0, 0, 0)))
    with rig.clip("idle", 48, loop=True) as c:                      # knarzt, der Vogel pickt
        c.key(0, **rest)
        c.key(12, trunk=R(0, 3, 0), arm_l=R(0, 6, 0), bird=dict(rot=(30, 0, 0)))
        c.key(18, bird=dict(rot=(0, 0, 0)))
        c.key(24, trunk=R(0, 0, 0), arm_r=R(0, -6, 0), bird=dict(rot=(30, 0, 40)))
        c.key(30, bird=dict(rot=(0, 0, 40)))
        c.key(36, trunk=R(0, -3, 0), arm_l=R(0, 0, 0))
    with rig.clip("walk", 42, loop=True, stride=1.7) as c:          # schwerfälliges Stapfen
        c.wave("leg_l", rot=(30, 0, 0), phase=0.0)
        c.wave("leg_r", rot=(30, 0, 0), phase=0.5)
        c.wave("hips", rot=(0, 5, 0), phase=0.25)
        c.wave("hips", loc=(0, 0, 0.06), n=2, phase=0.25)
        c.wave("arm_l", rot=(-18, 0, 0), phase=0.5)
        c.wave("arm_r", rot=(-18, 0, 0), phase=0.0)
        c.wave("nest", rot=(0, 6, 0), phase=0.4)
        c.wave("bird", loc=(0, 0, 0.05), n=2, phase=0.0)
        c.key(0, roots=dict(scale=(0.05, 0.05, 0.05)))
    with rig.clip("attack", 39, hit=22) as c:                       # beide Äste hoch – und Doppelschlag auf den Boden
        c.key(0, **rest)
        c.key(14, trunk=R(-14, 0, 0), arm_l=R(-150, 0, -20), arm_r=R(-150, 0, 20), fore_l=R(-30, 0, 0), fore_r=R(-30, 0, 0), bird=dict(loc=(0, 0, 0.3), rot=(-20, 0, 0)))
        c.key(22, trunk=R(24, 0, 0), arm_l=R(-60, 0, 0), arm_r=R(-60, 0, 0), fore_l=R(-10, 0, 0), fore_r=R(-10, 0, 0), hips=dict(loc=(0, -0.2, -0.12)), bird=dict(loc=(0, 0, 0.5)), _i="LINEAR")
        c.key(28, trunk=R(20, 0, 0), bird=dict(loc=(0, 0, 0)))
        c.key(39, **rest)
    with rig.clip("hit", 9) as c:
        c.key(0, **rest)
        c.key(3, trunk=R(-8, 4, 0), bird=dict(loc=(0, 0, 0.3)), nest=R(-8, 0, 0))
        c.key(9, **rest)
    with rig.clip("death", 45) as c:                               # fällt wie ein gefällter Baum, der Vogel flattert davon
        c.key(0, **rest)
        c.key(10, trunk=R(-8, 0, 0), bird=dict(loc=(0, 0, 0.5)), arm_l=R(-40, 0, 20), arm_r=R(-40, 0, -20))
        c.key(30, root=dict(rot=(84, 0, 0), loc=(0, 0, 0.6)), bird=dict(loc=(0.5, 2.0, 1.4), rot=(0, 0, 90)), leg_l=R(30, 0, 0), _i="LINEAR")
        c.key(34, root=dict(rot=(80, 0, 0), loc=(0, 0, 0.7)))
        c.key(38, root=dict(rot=(86, 0, 0), loc=(0, 0, 0.6)), eyes=dict(scale=0.1))
        c.key(45, root=dict(rot=(86, 0, 0), loc=(0, 0, 0.6)), bird=dict(loc=(1.0, 4.0, 3.0), rot=(0, 0, 180)), eyes=dict(scale=0.05))
    with rig.clip("root", 36, loop=True) as c:                      # festgewurzelt und heilend: Wurzeln im Boden, Blätter wiegen, Krone atmet
        c.key(0, **rest)
        c.key(0, roots=dict(scale=1.0), hips=dict(loc=(0, 0, -0.18)), leg_l=R(0, -10, 0), leg_r=R(0, 10, 0), arm_l=R(0, 30, 0), arm_r=R(0, -30, 0))
        c.key(18, roots=dict(scale=(1.06, 1.06, 1.0)), hips=dict(loc=(0, 0, -0.14)), arm_l=R(0, 40, 0), arm_r=R(0, -40, 0), trunk=R(-4, 0, 0), bird=dict(rot=(0, 0, 90)))
    rig.finish(icon_yaw=-28, icon_pitch=12)


# ================================================================= Zapfenwerfer (Fernkampf): Kobold mit Zapfen-Rucksack und Schleuder
def wald_zapfenwerfer():
    rig = Rig("wald_zapfenwerfer", role="ranged", size=1.0)
    SKIN, SKIN_D = "8FCB5A", "6BA344"
    TUNIC = "B8742E"
    rig.node("hips", pivot=(0, 0, 0.55))
    p = Part()
    lathe(p, [(0.2, 0.5, TUNIC), (0.28, 0.6, TUNIC), (0.27, 0.8, "9A5E22"), (0.2, 0.98, TUNIC), (0.1, 1.04, SKIN)], sides=8, sy=0.85)
    p.box((0.4, 0.06, 0.05), (0, -0.21, 0.66), "5A3A1E", bevel=0.0)                            # Gürtel
    # Rucksack: großer Tannenzapfen in Schuppenringen
    for k in range(5):
        z = 0.62 + k * 0.12
        rr = 0.22 - abs(k - 1.6) * 0.04
        lathe(p, [(rr * 0.6, z, "7A4A22"), (rr, z + 0.05, "A0662E"), (rr * 0.5, z + 0.12, "7A4A22")], sides=7, loc=(0, 0.32, 0))
    p.cone(0.06, 0.12, (0, 0.32, 1.25), "7A4A22", sides=5)
    rig.add("body", p, parent="hips", pivot=(0, 0, 0.55))
    # Kopf: groß, Spitzohren, breites Grinsen, Eichelhut
    p = Part()
    p.ball(0.26, (0, -0.02, 1.25), SKIN, scale=(1.05, 0.95, 0.9), subdiv=2)
    for s in (-1, 1):
        p.cone(0.08, 0.34, (0.38 * s, 0.0, 1.3), SKIN_D, r=rot(0, 70 * s, 0) @ rot(0, 0, 0), sides=4)
        p.ball(0.07, (0.1 * s, -0.22, 1.3), WHITE, scale=(1, 0.5, 1.1), subdiv=1)
    p.ball(0.05, (0, -0.27, 1.2), SKIN_D, subdiv=1)                                               # Knubbelnase
    p.box((0.18, 0.03, 0.03), (0, -0.23, 1.11), "6A2A2A", r=rot(0, 0, 0), bevel=0.0)
    lathe(p, [(0.24, 1.38, "6B4A2E"), (0.27, 1.42, "8A6038"), (0.2, 1.52, "6B4A2E"), (0.02, 1.6, "6B4A2E")], sides=9)
    p.cyl(0.02, 0.1, (0, 0, 1.64), "5A3A1E", sides=4)
    rig.add("head", p, parent="body", pivot=(0, 0, 1.04))
    p = Part()
    for s in (-1, 1):
        p.ball(0.035, (0.1 * s, -0.26, 1.3), INK, scale=(1, 0.5, 1), subdiv=1)
    rig.add("pupil", p, parent="head", pivot=(0, -0.25, 1.3), look=True)
    # Arme: links hält die Astgabel-Schleuder, rechts zieht das Gummi
    p = Part()
    capsule(p, (0.25, 0, 0.92), (0.38, -0.25, 0.85), 0.055, 0.05, SKIN, sides=5)
    p.ball(0.07, (0.39, -0.3, 0.85), SKIN_D, subdiv=1)
    capsule(p, (0.39, -0.33, 0.8), (0.39, -0.36, 1.0), 0.03, 0.03, BARK, sides=4)
    capsule(p, (0.39, -0.36, 1.0), (0.29, -0.38, 1.16), 0.025, 0.02, BARK, sides=4)
    capsule(p, (0.39, -0.36, 1.0), (0.49, -0.38, 1.16), 0.025, 0.02, BARK, sides=4)
    rig.add("arm_l", p, parent="body", pivot=(0.25, 0, 0.92))
    p = Part()
    capsule(p, (-0.25, 0, 0.92), (-0.33, -0.2, 0.8), 0.055, 0.05, SKIN, sides=5)
    p.ball(0.07, (-0.34, -0.24, 0.8), SKIN_D, subdiv=1)
    p.ball(0.07, (-0.34, -0.3, 0.86), "A0662E", scale=(0.8, 0.8, 1.2), subdiv=1)              # Zapfen in der Hand
    rig.add("arm_r", p, parent="body", pivot=(-0.25, 0, 0.92))
    for s, nm in ((1, "leg_l"), (-1, "leg_r")):
        p = Part()
        capsule(p, (0.11 * s, 0, 0.52), (0.12 * s, 0, 0.1), 0.06, 0.05, SKIN_D, sides=5)
        p.ball(0.08, (0.12 * s, -0.08, 0.05), "5A3A1E", scale=(0.9, 1.7, 0.6), subdiv=1)        # Schnabelschuhe
        p.cone(0.03, 0.1, (0.12 * s, -0.22, 0.09), "5A3A1E", r=rot(-70, 0, 0), sides=4)
        rig.add(nm, p, parent="hips", pivot=(0.11 * s, 0, 0.55))

    rest = dict(root=dict(loc=(0, 0, 0), rot=(0, 0, 0)), hips=dict(loc=(0, 0, 0), rot=(0, 0, 0)), body=R(), head=R(), arm_l=R(), arm_r=R(), leg_l=R(), leg_r=R())
    with rig.clip("idle", 36, loop=True) as c:                      # schaut sich um, wirft einen Zapfen hoch und fängt ihn
        c.key(0, **rest)
        c.key(8, head=R(0, 0, 25), arm_r=R(-40, 0, 0))
        c.key(14, arm_r=R(-80, 0, 0), head=R(-15, 0, 10))
        c.key(20, arm_r=R(-30, 0, 0), head=R(0, 0, 0))
        c.key(28, head=R(0, 0, -25))
    with rig.clip("walk", 18, loop=True, stride=1.4) as c:          # hüpfender Koboldschritt
        c.wave("leg_l", rot=(40, 0, 0), phase=0.0)
        c.wave("leg_r", rot=(40, 0, 0), phase=0.5)
        c.wave("arm_r", rot=(-30, 0, 0), phase=0.0)
        c.wave("hips", loc=(0, 0, 0.07), n=2, phase=0.25)
        c.wave("body", rot=(0, 6, 0), phase=0.25)
        c.wave("head", rot=(6, 0, 0), n=2, phase=0.0)
    with rig.clip("attack", 30, hit=20) as c:                       # spannt die Schleuder weit und lässt los
        c.key(0, **rest)
        c.key(6, arm_l=R(-80, 0, 0), arm_r=R(-80, 0, 0), body=R(0, 0, 10))
        c.key(16, arm_l=R(-88, 0, 10), arm_r=R(-70, 0, -40), body=R(-8, 0, 20), head=R(0, 0, -10), hips=dict(loc=(0, 0.08, -0.04)))
        c.key(20, arm_r=R(-100, 0, 10), body=R(6, 0, 4), _i="LINEAR")
        c.key(24, arm_l=R(-60, 0, 0), arm_r=R(-30, 0, 0), head=R(-10, 0, 0))
        c.key(30, **rest)
    with rig.clip("hit", 9) as c:
        c.key(0, **rest)
        c.key(3, body=R(-18, 0, 0), head=R(-20, 0, 10), arm_l=R(0, 0, 40), arm_r=R(0, 0, -40), hips=dict(loc=(0, 0.1, 0.06)))
        c.key(9, **rest)
    with rig.clip("death", 30) as c:                                # Purzelbaum rückwärts, liegt mit dem Rucksack oben
        c.key(0, **rest)
        c.key(8, root=dict(rot=(-40, 0, 0), loc=(0, 0.2, 0.3)), arm_l=R(0, 0, 60), arm_r=R(0, 0, -60))
        c.key(16, root=dict(rot=(-80, 0, 30), loc=(0, 0.3, 0.32)), leg_l=R(-40, 0, 0), _i="LINEAR")
        c.key(22, root=dict(rot=(-90, 0, 30), loc=(0, 0.3, 0.38)))
        c.key(30, root=dict(rot=(-90, 0, 30), loc=(0, 0.3, 0.38)), leg_l=R(0, 0, 0), head=R(0, 0, 30))
    spawn_clip(rig, 1.2)
    rig.finish()


# ================================================================= Irrlicht (Flieger): schwebende blaue Flamme mit Gesicht
def wald_irrlicht():
    rig = Rig("wald_irrlicht", role="air", size=1.0)
    F1, F2, F3 = "3E8CFF", "7FC8FF", "D8F4FF"
    p = Part()
    lathe(p, [(0.0, 0.3, F3), (0.22, 0.38, F2), (0.34, 0.6, F1), (0.3, 0.85, F1), (0.18, 1.08, F2), (0.06, 1.3, F3), (0.0, 1.4, F3)], sides=10)
    rig.add("flame", p, pivot=(0, 0, 0.5), glow=True)
    p = Part()                                                                                       # flackernde Spitzen
    for k, (x, y, h) in enumerate(((0.14, 0.05, 0.4), (-0.12, 0.08, 0.34), (0.0, 0.16, 0.48))):
        lathe(p, [(0.09, 0.0, F2), (0.05, h * 0.6, F2), (0.0, h, F3)], sides=5, loc=(x, y, 1.0))
    rig.add("tips", p, parent="flame", pivot=(0, 0, 1.0), glow=True)
    p = Part()                                                                                       # Gesicht: dunkle Augen, keckes Grinsen
    for s in (-1, 1):
        p.ball(0.07, (0.11 * s, -0.31, 0.78), "1A2A6A", scale=(1, 0.4, 1.3), subdiv=1)
    p.ball(0.08, (0, -0.32, 0.6), "1A2A6A", scale=(1.4, 0.35, 0.5), subdiv=1)
    rig.add("face", p, parent="flame", pivot=(0, -0.3, 0.7))
    p = Part()
    for s in (-1, 1):
        p.ball(0.03, (0.11 * s, -0.345, 0.8), WHITE, scale=(1, 0.4, 1), subdiv=1)
    rig.add("pupil", p, parent="face", pivot=(0, -0.34, 0.8), look=True, glow=True)
    p = Part()                                                                                       # zwei Funken umkreisen die Flamme
    p.ball(0.06, (0.5, 0, 0.8), F3, subdiv=1)
    p.ball(0.045, (-0.45, 0.1, 0.6), F3, subdiv=1)
    rig.add("sparks", p, pivot=(0, 0, 0.7), glow=True)

    rest = dict(root=dict(loc=(0, 0, 0), rot=(0, 0, 0)), flame=dict(scale=1.0, rot=(0, 0, 0), loc=(0, 0, 0)), tips=dict(rot=(0, 0, 0), scale=1.0), face=dict(loc=(0, 0, 0), scale=1.0), sparks=dict(rot=(0, 0, 0), scale=1.0))
    with rig.clip("idle", 30, loop=True) as c:                      # lodert und schwebt
        c.key(0, **rest)
        c.key(10, flame=dict(scale=(1.06, 1.06, 0.92), loc=(0, 0, 0.06)), tips=dict(rot=(10, 0, 30), scale=(1, 1, 1.3)), sparks=dict(rot=(0, 0, 120)), _i="LINEAR")
        c.key(20, flame=dict(scale=(0.94, 0.94, 1.1), loc=(0, 0, -0.04)), tips=dict(rot=(-8, 0, -20), scale=(1, 1, 0.8)), sparks=dict(rot=(0, 0, 240)), _i="LINEAR")
        c.key(30, sparks=dict(rot=(0, 0, 360)), _i="LINEAR")
    with rig.clip("walk", 24, loop=True, stride=2.4) as c:          # zieht schräg vorgeneigt, Spitzen wehen nach hinten
        c.key(0, flame=dict(rot=(16, 0, 0), scale=(1, 1, 1.05)), tips=dict(rot=(-30, 0, 0)), sparks=dict(rot=(0, 0, 0)))
        c.key(12, flame=dict(rot=(20, 0, 0), scale=(0.95, 0.95, 1.12), loc=(0, 0, 0.08)), tips=dict(rot=(-40, 0, 10)), sparks=dict(rot=(0, 0, 180)), _i="LINEAR")
        c.key(24, sparks=dict(rot=(0, 0, 360)), _i="LINEAR")
    with rig.clip("attack", 18, hit=9) as c:                        # zuckt vor und faucht
        c.key(0, **rest)
        c.key(6, flame=dict(scale=(0.8, 0.8, 1.2), loc=(0, 0.15, 0)), face=dict(scale=(1, 1, 1.2)))
        c.key(9, flame=dict(scale=(1.3, 1.3, 0.9), loc=(0, -0.35, 0), rot=(25, 0, 0)), tips=dict(scale=(1.3, 1.3, 1.5)), _i="LINEAR")
        c.key(18, **rest)
    with rig.clip("hit", 9) as c:
        c.key(0, **rest)
        c.key(3, flame=dict(scale=(1.3, 1.3, 0.6), rot=(-20, 0, 0)), tips=dict(scale=0.5))
        c.key(9, **rest)
    with rig.clip("death", 24) as c:                                # erlischt mit einem letzten Flackern
        c.key(0, **rest)
        c.key(6, flame=dict(scale=(1.2, 1.2, 1.3)), tips=dict(scale=1.5))
        c.key(12, flame=dict(scale=(0.5, 0.5, 0.7)), tips=dict(scale=0.4))
        c.key(15, flame=dict(scale=(0.7, 0.7, 0.8)))
        c.key(24, flame=dict(scale=(0.05, 0.05, 0.05), loc=(0, 0, -0.4)), sparks=dict(scale=0.05, rot=(0, 0, 200)))
    with rig.clip("blink", 12) as c:                                # nach dem Sprung: taucht aus einem Lichtpunkt auf
        c.key(0, flame=dict(scale=(0.05, 0.05, 0.05)), sparks=dict(scale=1.6, rot=(0, 0, 0)), _i="LINEAR")
        c.key(6, flame=dict(scale=(1.3, 1.3, 1.3)), sparks=dict(scale=1.2, rot=(0, 0, 200)))
        c.key(12, **rest)
    rig.finish(icon_pitch=10)


# ================================================================= Wurzelkriecher (Sonder): Wurzelknäuel, gräbt sich unter Mauern
def wald_wurzelkriecher():
    rig = Rig("wald_wurzelkriecher", role="special", size=1.0)
    p = Part()                                                                                       # Buckel aus verknoteten Wurzeln
    p.ball(0.5, (0, 0, 0.45), BARK, scale=(1.1, 1.2, 0.8), subdiv=2)
    for k in range(7):
        a = k * 0.9
        p.torus(0.36, 0.06, (0.08 * math.cos(a), 0.08 * math.sin(a), 0.48), BARK_D if k % 2 else BARK_L, r=rot(60 + k * 15, k * 25, k * 50), seg=10, tseg=4)
    p.ball(0.22, (0.15, 0.2, 0.83), MOSS, scale=(1.2, 1, 0.4), subdiv=1)
    p.cyl(0.03, 0.12, (-0.2, 0.1, 0.85), STEM, sides=5)
    p.ball(0.08, (-0.2, 0.1, 0.92), CAP, scale=(1, 1, 0.5), subdiv=1)
    rig.add("body", p, pivot=(0, 0, 0.4))
    p = Part()                                                                                       # Augen lugen zwischen den Wurzeln
    for s in (-1, 1):
        p.ball(0.09, (0.14 * s, -0.5, 0.55), "FFF2A0", scale=(1, 0.5, 0.8), subdiv=1)
    rig.add("eyes", p, parent="body", pivot=(0, -0.5, 0.55), glow=True)
    p = Part()
    for s in (-1, 1):
        p.ball(0.04, (0.14 * s, -0.55, 0.55), INK, scale=(1, 0.5, 1), subdiv=1)
    rig.add("pupil", p, parent="eyes", pivot=(0, -0.55, 0.55), look=True)
    # sechs Wurzelbeine (zwei Glieder vorn als Greifer)
    legs = []
    for k in range(6):
        a = math.radians(-150 + k * 60 + (0 if k < 3 else 0))
        x, y = math.cos(a), math.sin(a)
        nm = "root%d" % k
        p = Part()
        capsule(p, (0.4 * x, 0.4 * y, 0.3), (0.85 * x, 0.85 * y, 0.04), 0.07, 0.035, BARK_D if k % 2 else BARK, sides=4)
        capsule(p, (0.85 * x, 0.85 * y, 0.04), (1.0 * x + 0.1 * y, 1.0 * y - 0.1 * x, 0.1), 0.035, 0.015, BARK_D, sides=4)
        rig.add(nm, p, parent="body", pivot=(0.4 * x, 0.4 * y, 0.3))
        legs.append(nm)
    p = Part()                                                                                       # Erdhaufen (nur beim Graben sichtbar)
    p.ball(0.7, (0, 0, 0.0), "7A5A3A", scale=(1.2, 1.4, 0.35), subdiv=2)
    for k in range(5):
        a = k * 1.3
        p.ball(0.12, (0.7 * math.cos(a), 0.8 * math.sin(a), 0.06), "8E6A44", subdiv=1)
    rig.add("dirt", p, pivot=(0, 0, 0.0))

    hidden = dict(scale=(0.02, 0.02, 0.02))
    rest = dict(root=dict(loc=(0, 0, 0), rot=(0, 0, 0)), body=dict(loc=(0, 0, 0), rot=(0, 0, 0), scale=1.0), eyes=dict(scale=1.0), dirt=hidden, **{n: R() for n in legs})
    with rig.clip("idle", 30, loop=True) as c:                      # Wurzeln tasten, Augen blinzeln
        c.key(0, **rest)
        c.key(8, root0=R(0, 0, 20), root3=R(0, 0, -20), body=dict(scale=(1.03, 1.03, 0.96)))
        c.key(14, eyes=dict(scale=(1, 1, 0.1)))
        c.key(16, eyes=dict(scale=1.0))
        c.key(22, root1=R(20, 0, 0), root4=R(-20, 0, 0), body=dict(scale=1.0))
    with rig.clip("walk", 18, loop=True, stride=1.6) as c:          # krabbelt wie eine Spinne aus Wurzeln
        for k, n in enumerate(legs):
            c.wave(n, rot=(0, 25 if k < 3 else -25, 18), phase=(k % 2) * 0.5)
        c.key(0, dirt=hidden, body=dict(scale=1.0), eyes=dict(scale=1.0))
        c.wave("body", rot=(5, 0, 6), loc=(0, 0, 0.05), n=2)
    with rig.clip("attack", 18, hit=10) as c:                       # peitscht mit zwei Wurzeln
        c.key(0, **rest)
        c.key(6, body=dict(rot=(-14, 0, 0)), root1=R(-60, 0, -30), root2=R(-60, 0, 30))
        c.key(10, body=dict(rot=(14, 0, 0), loc=(0, -0.2, 0)), root1=R(30, 0, 10), root2=R(30, 0, -10), _i="LINEAR")
        c.key(18, **rest)
    with rig.clip("hit", 9) as c:
        c.key(0, **rest)
        c.key(3, body=dict(scale=(1.15, 1.15, 0.8)), eyes=dict(scale=(1.3, 1, 1.3)))
        c.key(9, **rest)
    with rig.clip("death", 30) as c:                                # die Wurzeln erschlaffen, der Knäuel sackt zusammen
        c.key(0, **rest)
        c.key(10, body=dict(scale=(1.1, 1.1, 1.1), loc=(0, 0, 0.2)), **{n: R(0, -30 if k < 3 else 30, 0) for k, n in enumerate(legs)})
        c.key(22, body=dict(scale=(1.25, 1.25, 0.45), loc=(0, 0, -0.2)), eyes=dict(scale=(1, 1, 0.1)), **{n: R(0, 20 if k < 3 else -20, 0) for k, n in enumerate(legs)})
        c.key(30, body=dict(scale=(1.25, 1.25, 0.4), loc=(0, 0, -0.22)), eyes=dict(scale=0.02))
    with rig.clip("dig", 21) as c:                                  # wühlt sich in die Erde
        c.key(0, **rest)
        c.key(3, dirt=dict(scale=(0.5, 0.5, 0.5)))
        c.key(9, body=dict(loc=(0, 0, -0.35), rot=(20, 0, 0)), root1=R(-50, 0, 0), root2=R(-50, 0, 0), dirt=dict(scale=1.0))
        c.key(15, body=dict(loc=(0, 0, -0.65), rot=(-10, 0, 0)), root1=R(40, 0, 0), root2=R(40, 0, 0))
        c.key(21, body=dict(loc=(0, 0, -0.75), rot=(0, 0, 0), scale=0.4), eyes=dict(scale=0.02), dirt=dict(scale=(0.8, 0.8, 0.8)))
    with rig.clip("under", 12, loop=True, stride=1.6) as c:         # unter der Erde: nur ein wandernder Erdbuckel
        c.key(0, body=dict(loc=(0, 0, -0.75), scale=0.4), eyes=dict(scale=0.02), dirt=dict(scale=(0.8, 0.8, 0.8)), **{n: R() for n in legs})
        c.key(6, dirt=dict(scale=(0.9, 0.9, 1.1)))
    with rig.clip("rise", 15) as c:                                 # bricht hervor
        c.key(0, body=dict(loc=(0, 0, -0.75), scale=0.4), eyes=dict(scale=0.02), dirt=dict(scale=(0.8, 0.8, 0.8)))
        c.key(6, body=dict(loc=(0, 0, 0.3), scale=(0.9, 0.9, 1.2)), eyes=dict(scale=1.2), dirt=dict(scale=(1.0, 1.0, 0.5)), root0=R(0, 40, 0), root3=R(0, -40, 0))
        c.key(15, **rest)
    rig.finish(icon_pitch=24)


# ================================================================= Boss: Mooskönigin – riesige Pilzdame mit Krone
def boss_wald():
    rig = Rig("boss_wald", role="boss", size=1.0)
    DRESS, DRESS_D = "6FB04A", "4E8A34"
    rig.node("hips", pivot=(0, 0, 1.6))
    # ---- Kleid aus Moos (Glocke) mit Blüten am Saum
    p = Part()
    lathe(p, [(1.3, 0.05, DRESS_D), (1.35, 0.2, DRESS), (1.1, 0.8, DRESS_D), (0.8, 1.4, DRESS), (0.6, 1.9, DRESS_D), (0.5, 2.2, DRESS)], sides=16)
    for k in range(10):
        a = k * math.tau / 10
        p.ball(0.16, (1.3 * math.cos(a), 1.3 * math.sin(a), 0.25), ["F3C94A", "F07AA0", "FFFFFF"][k % 3], scale=(1, 1, 0.6), subdiv=1)
    for k in range(6):
        a = k * math.tau / 6 + 0.3
        p.ball(0.2, (0.95 * math.cos(a), 0.95 * math.sin(a), 0.95), MOSS_D, scale=(1, 1, 0.7), subdiv=1)
    rig.add("skirt", p, parent="hips", pivot=(0, 0, 1.6))
    # ---- Oberkörper: Stiel mit Rüschenkragen
    p = Part()
    lathe(p, [(0.5, 2.15, STEM), (0.58, 2.5, STEM), (0.5, 2.9, STEM), (0.75, 3.0, DOT), (0.8, 3.08, STEM_D), (0.4, 3.15, STEM)], sides=14)
    rig.add("torso", p, parent="hips", pivot=(0, 0, 2.2))
    # ---- Kopf mit großem Pilzhut, Gesicht, Krone
    p = Part()
    p.ball(0.55, (0, -0.05, 3.55), STEM, scale=(1, 0.95, 0.95), subdiv=3)
    for s in (-1, 1):
        p.ball(0.15, (0.2 * s, -0.5, 3.65), WHITE, scale=(1, 0.5, 1.2), subdiv=2)
        p.ball(0.12, (0.33 * s, -0.42, 3.42), PINK, scale=(1, 0.4, 0.7), subdiv=1)
        p.box((0.22, 0.05, 0.05), (0.2 * s, -0.53, 3.88), "6B4A2E", r=rot(0, 12 * s, 0), bevel=0.0)  # strenge Brauen
    p.ball(0.12, (0, -0.52, 3.32), "8A2A3A", scale=(1.5, 0.4, 0.6), subdiv=1)                    # Mund
    p.cone(0.04, 0.07, (0.07, -0.56, 3.36), WHITE, r=rot(180, 0, 0), sides=3)
    p.cone(0.04, 0.07, (-0.07, -0.56, 3.36), WHITE, r=rot(180, 0, 0), sides=3)
    lathe(p, [(0.4, 3.8, CAP_D), (1.15, 3.85, CAP_D), (1.2, 3.95, CAP), (1.05, 4.25, CAP), (0.7, 4.55, CAP), (0.0, 4.7, CAP)], sides=18)
    for (x, y, z, r) in ((0.0, 0.0, 4.68, 0.16), (0.6, -0.45, 4.35, 0.15), (-0.62, -0.4, 4.33, 0.14), (0.65, 0.45, 4.33, 0.15), (-0.55, 0.55, 4.35, 0.13), (0.0, -0.85, 4.15, 0.12), (1.0, 0.0, 4.1, 0.11), (-1.0, 0.0, 4.1, 0.11), (0, 0.9, 4.15, 0.12)):
        p.ball(r, (x, y, z), DOT, scale=(1, 1, 0.45), subdiv=2)
    rig.add("head", p, parent="torso", pivot=(0, 0, 3.15))
    p = Part()
    for s in (-1, 1):
        p.ball(0.07, (0.2 * s, -0.58, 3.65), INK, scale=(1, 0.5, 1.1), subdiv=1)
    rig.add("pupil", p, parent="head", pivot=(0, -0.58, 3.65), look=True)
    p = Part()                                                                                       # goldene Krone mit Glühsteinen
    lathe(p, [(0.42, 4.62, "E8B22A"), (0.44, 4.8, "FFD24A"), (0.4, 4.82, "E8B22A")], sides=10, cap=False)
    for k in range(5):
        a = k * math.tau / 5
        p.cone(0.09, 0.3, (0.42 * math.cos(a), 0.42 * math.sin(a), 4.95), "FFD24A", sides=4)
    rig.add("crown", p, parent="head", pivot=(0, 0, 4.7))
    p = Part()
    for k in range(5):
        a = k * math.tau / 5
        p.ball(0.06, (0.44 * math.cos(a), 0.44 * math.sin(a), 4.72), "5AF0A0", subdiv=1)
    rig.add("gems", p, parent="crown", pivot=(0, 0, 4.72), glow=True)
    # ---- Arme: links ein Zepter mit Glühpilz, rechts die offene Hand
    p = Part()
    capsule(p, (0.55, 0, 2.95), (1.1, -0.2, 2.4), 0.16, 0.13, STEM_D, sides=7)
    rig.add("arm_l", p, parent="torso", pivot=(0.55, 0, 2.95))
    p = Part()
    capsule(p, (1.1, -0.2, 2.4), (1.25, -0.6, 2.25), 0.13, 0.11, STEM, sides=7)
    p.ball(0.16, (1.27, -0.68, 2.23), STEM, subdiv=2)
    capsule(p, (1.27, -0.72, 1.0), (1.27, -0.72, 3.3), 0.06, 0.06, BARK, sides=6)
    p.ball(0.25, (1.27, -0.72, 3.45), "9A6AF0", scale=(1, 1, 0.6), subdiv=2)
    rig.add("fore_l", p, parent="arm_l", pivot=(1.1, -0.2, 2.4))
    p = Part()
    p.ball(0.12, (1.27, -0.72, 3.62), "D8C8FF", subdiv=1)
    rig.add("orb", p, parent="fore_l", pivot=(1.27, -0.72, 3.6), glow=True)
    p = Part()
    capsule(p, (-0.55, 0, 2.95), (-1.1, -0.2, 2.4), 0.16, 0.13, STEM_D, sides=7)
    rig.add("arm_r", p, parent="torso", pivot=(-0.55, 0, 2.95))
    p = Part()
    capsule(p, (-1.1, -0.2, 2.4), (-1.25, -0.6, 2.25), 0.13, 0.11, STEM, sides=7)
    p.ball(0.18, (-1.27, -0.7, 2.22), STEM, scale=(1, 1, 0.7), subdiv=2)
    for k in range(4):
        capsule(p, (-1.27, -0.75, 2.22), (-1.2 - 0.06 * k, -0.95, 2.2 + 0.06 * (k - 1.5)), 0.04, 0.035, STEM, sides=4)
    rig.add("fore_r", p, parent="arm_r", pivot=(-1.1, -0.2, 2.4))
    # ---- kleine Pilzpagen am Saum (wippen mit)
    for s, nm in ((1, "page_l"), (-1, "page_r")):
        p = Part()
        lathe(p, [(0.1, 0.0, STEM), (0.14, 0.2, STEM), (0.1, 0.38, STEM)], sides=7, loc=(1.6 * s, -0.6, 0))
        lathe(p, [(0.08, 0.35, CAP_D), (0.26, 0.37, CAP), (0.2, 0.5, CAP), (0.0, 0.56, CAP)], sides=9, loc=(1.6 * s, -0.6, 0))
        p.ball(0.03, (1.6 * s + 0.05, -0.73, 0.25), INK, subdiv=1)
        p.ball(0.03, (1.6 * s - 0.05, -0.73, 0.25), INK, subdiv=1)
        rig.add(nm, p, parent="root", pivot=(1.6 * s, -0.6, 0))

    rest = dict(root=dict(loc=(0, 0, 0), rot=(0, 0, 0)), hips=dict(loc=(0, 0, 0), rot=(0, 0, 0)), skirt=dict(rot=(0, 0, 0), scale=1.0), torso=R(), head=R(), crown=dict(loc=(0, 0, 0), rot=(0, 0, 0)),
                arm_l=R(), fore_l=R(), arm_r=R(), fore_r=R(), page_l=dict(loc=(0, 0, 0), rot=(0, 0, 0)), page_r=dict(loc=(0, 0, 0), rot=(0, 0, 0)), orb=dict(scale=1.0))
    with rig.clip("idle", 54, loop=True) as c:                      # königliches Wiegen, das Zepter glimmt, Pagen hüpfen
        c.key(0, **rest)
        c.key(14, torso=R(0, 4, 0), head=R(-4, 0, 8), orb=dict(scale=1.3), page_l=dict(loc=(0, 0, 0.2)))
        c.key(20, page_l=dict(loc=(0, 0, 0)))
        c.key(28, torso=R(0, 0, 0), head=R(4, 0, 0), orb=dict(scale=1.0), page_r=dict(loc=(0, 0, 0.2)))
        c.key(34, page_r=dict(loc=(0, 0, 0)))
        c.key(42, torso=R(0, -4, 0), head=R(-4, 0, -8), orb=dict(scale=1.3))
    with rig.clip("walk", 48, loop=True, stride=2.2) as c:          # gleitet wogend: der Rock schwingt, die Pagen trippeln mit
        c.wave("skirt", rot=(0, 5, 0), phase=0.0)
        c.wave("hips", loc=(0, 0, 0.08), n=2, phase=0.25)
        c.wave("torso", rot=(4, -4, 0), phase=0.25)
        c.wave("head", rot=(0, 5, 0), phase=0.5)
        c.wave("arm_r", rot=(-20, 0, 0), phase=0.0)
        c.wave("page_l", loc=(0, 0, 0.15), n=4)
        c.wave("page_r", loc=(0, 0, 0.15), n=4, phase=0.5)
    with rig.clip("attack", 39, hit=21) as c:                       # schlägt mit dem Zepter auf den Boden
        c.key(0, **rest)
        c.key(14, torso=R(-14, 0, -12), head=R(-10, 0, 0), arm_l=R(-150, 0, -10), fore_l=R(-40, 0, 0), crown=dict(rot=(-10, 0, 0)))
        c.key(21, torso=R(22, 0, 10), arm_l=R(-30, 0, 0), fore_l=R(10, 0, 0), hips=dict(loc=(0, -0.2, -0.15)), crown=dict(loc=(0, 0, 0.2)), _i="LINEAR")
        c.key(27, crown=dict(loc=(0, 0, 0)), torso=R(18, 0, 8))
        c.key(39, **rest)
    with rig.clip("hit", 9) as c:
        c.key(0, **rest)
        c.key(3, torso=R(-10, 0, 6), head=R(-14, 0, 6), crown=dict(loc=(0, 0, 0.25), rot=(0, 15, 0)), skirt=dict(scale=(1.05, 1.05, 0.95)))
        c.key(9, **rest)
    with rig.clip("death", 60) as c:                                # taumelt, sinkt im Rock zusammen, die Krone kullert davon
        c.key(0, **rest)
        c.key(14, torso=R(-14, 0, 14), head=R(-20, 0, 20), arm_l=R(-60, 0, 40), arm_r=R(-60, 0, -40), crown=dict(loc=(0, 0, 0.4)))
        c.key(30, hips=dict(loc=(0, 0, -1.0)), skirt=dict(scale=(1.3, 1.3, 0.45)), torso=R(30, 0, 0), head=R(30, 0, 10), crown=dict(loc=(1.0, -1.5, -0.5), rot=(80, 0, 40)), _i="LINEAR")
        c.key(40, hips=dict(loc=(0, 0, -1.25)), torso=R(70, 0, 0), head=R(10, 0, 0), arm_l=R(10, 0, 50), arm_r=R(10, 0, -50))
        c.key(60, hips=dict(loc=(0, 0, -1.3)), skirt=dict(scale=(1.35, 1.35, 0.4)), torso=R(80, 0, 0), crown=dict(loc=(1.6, -2.4, -3.0), rot=(90, 0, 120)), orb=dict(scale=0.1),
              page_l=dict(rot=(0, 90, 0), loc=(0.3, 0, 0.2)), page_r=dict(rot=(0, -90, 0), loc=(-0.3, 0, 0.2)))
    with rig.clip("summon", 42, hit=24) as c:                       # hebt beide Arme, das Zepter strahlt: Pilzlinge wachsen
        c.key(0, **rest)
        c.key(14, arm_l=R(-170, 0, -20), arm_r=R(-150, 0, 30), fore_r=R(-30, 0, 0), head=R(-20, 0, 0), torso=R(-10, 0, 0), orb=dict(scale=1.8))
        c.key(24, orb=dict(scale=2.4), skirt=dict(scale=(1.1, 1.1, 0.95)), hips=dict(loc=(0, 0, 0.1)))
        c.key(30, skirt=dict(scale=1.0), hips=dict(loc=(0, 0, 0)), page_l=dict(loc=(0, 0, 0.4)), page_r=dict(loc=(0, 0, 0.4)))
        c.key(42, **rest)
    with rig.clip("special", 42, hit=20) as c:                     # Sporen: schüttelt den Hut kräftig
        c.key(0, **rest)
        c.key(8, head=R(-20, 0, 0), torso=R(-10, 0, 0))
        for k, f in enumerate((12, 16, 20, 24, 28)):
            c.key(f, head=R(10, 14 * (1 if k % 2 else -1), 0), crown=dict(rot=(0, 18 * (1 if k % 2 else -1), 0)))
        c.key(32, head=R(14, 0, 0), crown=dict(rot=(0, 0, 0)))
        c.key(42, **rest)
    rig.finish(icon_yaw=-26, icon_pitch=10)


TABLE = {"wald_pilzling": wald_pilzling, "wald_dornenwolf": wald_dornenwolf, "wald_baumhueter": wald_baumhueter, "wald_zapfenwerfer": wald_zapfenwerfer,
         "wald_irrlicht": wald_irrlicht, "wald_wurzelkriecher": wald_wurzelkriecher, "boss_wald": boss_wald}

if __name__ == "__main__":
    run(TABLE, [a for a in sys.argv if not a.startswith("--")])
