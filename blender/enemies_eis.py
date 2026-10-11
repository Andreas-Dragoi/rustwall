"""Eiswesen (Frostpass): sechs Arten + Boss nach dem Muster von enemies_untote.py (siehe blender/GEGNER.md).
Aufruf:  python3 blender/enemies_eis.py [art ...] [--notafel]
"""
import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from animkit import *

# Farben der Familie: Schnee, Eis, Kristall, Mützenrot
SNOW, SNOW_D = "F4F8FF", "D0DCEC"
ICE, ICE_D, ICE_L = "8CD8F8", "5AAEDC", "C8F0FF"
CRYS = "6AC8FF"
FUR, FUR_D = "E8EEF4", "B8C8D8"
RED, RED_D = "D83A3A", "A82A2A"
BLUE = "3A6AC8"
INK = "16202E"
WHITE = "FFFFFF"


def R(x=0, y=0, z=0):
    return dict(rot=(x, y, z))


def spawn_clip(rig, depth=1.0, n=24, **extra):
    """Besonderer Clip „spawn“: taucht wackelnd aus dem Schnee auf."""
    with rig.clip("spawn", n) as c:
        c.key(0, root=dict(loc=(0, 0, -depth), rot=(0, 0, -40), scale=(0.6, 0.6, 0.6)))
        c.key(int(n * 0.55), root=dict(loc=(0, 0, 0.15 * depth), rot=(0, 0, 15), scale=(0.95, 0.95, 1.12)))
        c.key(int(n * 0.8), root=dict(loc=(0, 0, 0), rot=(0, 0, -5), scale=(1.08, 1.08, 0.92)))
        c.key(n, root=dict(loc=(0, 0, 0), rot=(0, 0, 0), scale=(1, 1, 1)))
        if extra:
            c.key(0, **extra)


# ================================================================= Frostwichtel (Masse): Kobold mit Eiszapfen-Mütze, wirft Schneebälle
def eis_frostwichtel():
    rig = Rig("eis_frostwichtel", role="mass")
    SK = "A8C8F0"
    rig.node("hips", pivot=(0, 0, 0.35))
    p = Part()                                                                                       # Körper im dicken Strickpulli
    lathe(p, [(0.2, 0.3, BLUE), (0.28, 0.4, BLUE), (0.3, 0.55, WHITE), (0.28, 0.62, BLUE), (0.22, 0.75, BLUE), (0.15, 0.8, WHITE)], sides=8)
    rig.add("body", p, parent="hips", pivot=(0, 0, 0.35))
    p = Part()                                                                                       # Kopf: Knubbelnase rot, Bart aus Reif
    p.ball(0.24, (0, 0, 0.98), SK, subdiv=2)
    p.ball(0.07, (0, -0.24, 0.94), "F07A8A", subdiv=1)
    p.ball(0.14, (0, -0.15, 0.82), SNOW, scale=(1.3, 0.8, 0.8), subdiv=1)
    for s in (-1, 1):
        p.ball(0.065, (0.09 * s, -0.2, 1.02), WHITE, scale=(1, 0.5, 1.1), subdiv=1)
        p.cone(0.06, 0.22, (0.27 * s, 0, 1.0), SK, r=rot(0, 80 * s, 0), sides=4)                  # Spitzohren
    rig.add("head", p, parent="body", pivot=(0, 0, 0.8))
    p = Part()
    for s in (-1, 1):
        p.ball(0.03, (0.09 * s, -0.235, 1.02), INK, scale=(1, 0.5, 1), subdiv=1)
    rig.add("pupil", p, parent="head", pivot=(0, -0.23, 1.02), look=True)
    p = Part()                                                                                       # Eiszapfen-Mütze mit Bommel
    lathe(p, [(0.24, 1.1, RED), (0.25, 1.15, WHITE), (0.2, 1.2, RED), (0.12, 1.45, RED), (0.05, 1.7, RED_D)], sides=8, loc=(0, 0.04, 0))
    for k in range(6):
        a = k * math.tau / 6
        p.cone(0.035, 0.14, (0.24 * math.cos(a), 0.24 * math.sin(a), 1.08), ICE, r=rot(180, 0, 0), sides=4)
    p.ball(0.07, (0, 0.12, 1.74), WHITE, subdiv=1)
    rig.add("hat", p, parent="head", pivot=(0, 0.04, 1.15))
    p = Part()                                                                                       # rechter Arm mit Schneeball
    capsule(p, (-0.24, 0, 0.7), (-0.36, -0.08, 0.5), 0.05, 0.045, BLUE, sides=5)
    p.ball(0.06, (-0.37, -0.1, 0.46), "7A5A3A", subdiv=1)
    p.ball(0.1, (-0.38, -0.16, 0.5), SNOW, subdiv=1)
    rig.add("arm_r", p, parent="body", pivot=(-0.24, 0, 0.7))
    p = Part()
    capsule(p, (0.24, 0, 0.7), (0.36, -0.08, 0.5), 0.05, 0.045, BLUE, sides=5)
    p.ball(0.06, (0.37, -0.1, 0.46), "7A5A3A", subdiv=1)
    rig.add("arm_l", p, parent="body", pivot=(0.24, 0, 0.7))
    for s, nm in ((1, "leg_l"), (-1, "leg_r")):
        p = Part()
        capsule(p, (0.1 * s, 0, 0.32), (0.1 * s, 0, 0.1), 0.05, 0.05, SK, sides=5)
        p.ball(0.09, (0.1 * s, -0.05, 0.06), "7A5A3A", scale=(1, 1.5, 0.7), subdiv=1)              # Fellstiefel
        rig.add(nm, p, parent="hips", pivot=(0.1 * s, 0, 0.35))
    rest = dict(root=dict(loc=(0, 0, 0), rot=(0, 0, 0)), hips=dict(loc=(0, 0, 0), rot=(0, 0, 0)), body=R(), head=R(), hat=R(), arm_l=R(), arm_r=R(), leg_l=R(), leg_r=R())
    with rig.clip("idle", 30, loop=True) as c:                     # hüpft frierend auf der Stelle, reibt die Hände
        c.key(0, **rest)
        c.key(5, hips=dict(loc=(0, 0, 0.06)), arm_l=R(-40, 0, -30), arm_r=R(-40, 0, 30), hat=R(-8, 0, 0))
        c.key(10, hips=dict(loc=(0, 0, 0)), arm_l=R(-40, 0, -20), arm_r=R(-40, 0, 20), hat=R(6, 0, 0))
        c.key(15, hips=dict(loc=(0, 0, 0.06)), arm_l=R(-40, 0, -30), arm_r=R(-40, 0, 30), head=R(0, 0, 10))
        c.key(20, hips=dict(loc=(0, 0, 0)), head=R(0, 0, -10), hat=R(-6, 0, 0))
    with rig.clip("walk", 15, loop=True, stride=1.1) as c:         # trippelt eilig
        c.wave("leg_l", rot=(45, 0, 0))
        c.wave("leg_r", rot=(45, 0, 0), phase=0.5)
        c.wave("arm_l", rot=(-35, 0, 0), phase=0.5)
        c.wave("arm_r", rot=(-35, 0, 0))
        c.wave("hips", loc=(0, 0, 0.05), n=2, phase=0.25)
        c.wave("hat", rot=(10, 8, 0), phase=0.4)
    with rig.clip("attack", 24, hit=15) as c:                      # wirft den Schneeball über Kopf
        c.key(0, **rest)
        c.key(9, arm_r=R(-170, 0, 20), body=R(-12, 0, 10), hat=R(-12, 0, 0))
        c.key(15, arm_r=R(-40, 0, 0), body=R(14, 0, -6), hat=R(10, 0, 0), _i="LINEAR")
        c.key(24, **rest)
    with rig.clip("hit", 9) as c:
        c.key(0, **rest)
        c.key(3, body=R(-16, 0, 8), head=R(-20, 0, 10), hat=dict(rot=(-30, 0, 0)), hips=dict(loc=(0, 0.08, 0.05)))
        c.key(9, **rest)
    with rig.clip("death", 27) as c:                               # friert ein, kippt steif um
        c.key(0, **rest)
        c.key(8, arm_l=R(0, 0, 40), arm_r=R(0, 0, -40), head=R(10, 0, 0))
        c.key(20, root=dict(rot=(0, 86, 0), loc=(0, 0, 0.22)), _i="LINEAR")
        c.key(23, root=dict(rot=(0, 80, 0), loc=(0, 0, 0.26)))
        c.key(27, root=dict(rot=(0, 88, 0), loc=(0, 0, 0.22)), hat=dict(rot=(0, 0, 30)))
    spawn_clip(rig, 1.0)
    rig.finish()


# ================================================================= Eiswolf (Flitzer): weißer Wolf mit Kristallrücken
def eis_eiswolf():
    rig = Rig("eis_eiswolf", role="fast")
    p = Part()
    lathe(p, [(0.08, -0.05, FUR), (0.22, 0.05, FUR), (0.26, 0.3, FUR), (0.24, 0.6, FUR_D), (0.16, 0.8, FUR), (0.05, 0.86, FUR)], sides=8, loc=(0, -0.45, 0.62), r=rot(-92, 0, 0), sy=0.85)
    for i, (y, h) in enumerate(((-0.3, 0.28), (-0.1, 0.36), (0.1, 0.3), (0.28, 0.22))):            # Eiskristalle auf dem Rücken
        p.cone(0.07, h, (0.0, y, 0.82), CRYS, r=rot(-15, 0, 10 * (i % 2)), sides=4)
        p.cone(0.04, h * 0.6, (0.09, y + 0.07, 0.8), ICE_L, r=rot(-20, 25, 0), sides=4)
    rig.add("body", p, pivot=(0, 0, 0.62))
    p = Part()
    p.ball(0.19, (0, -0.58, 0.82), FUR, scale=(1, 1.05, 0.9), subdiv=2)
    lathe(p, [(0.12, 0.0, FUR), (0.08, 0.18, FUR_D), (0.035, 0.28, INK)], sides=6, loc=(0, -0.68, 0.78), r=rot(98, 0, 0), sy=0.75)
    for s in (-1, 1):
        p.cone(0.07, 0.2, (0.1 * s, -0.5, 1.0), FUR_D, r=rot(-10, 18 * s, 0), sides=4)
    rig.add("head", p, parent="body", pivot=(0, -0.48, 0.78))
    p = Part()
    for s in (-1, 1):
        p.ball(0.04, (0.085 * s, -0.73, 0.87), CRYS, scale=(1.2, 0.5, 0.7), subdiv=1)
    rig.add("eyes", p, parent="head", pivot=(0, -0.72, 0.87), glow=True)
    p = Part()
    lathe(p, [(0.07, 0.0, FUR_D), (0.045, 0.16, FUR_D), (0.02, 0.24, FUR_D)], sides=5, loc=(0, -0.66, 0.7), r=rot(100, 0, 0), sy=0.5)
    rig.add("jaw", p, parent="head", pivot=(0, -0.62, 0.72))
    p = Part()                                                                                       # Atemwolke
    p.ball(0.08, (0, -1.0, 0.75), SNOW, subdiv=1)
    p.ball(0.06, (0.06, -1.1, 0.8), SNOW, subdiv=1)
    rig.add("breath", p, parent="head", pivot=(0, -0.9, 0.75), ghost=True)
    p = Part()                                                                                       # buschiger Schwanz
    lathe(p, [(0.06, 0.0, FUR), (0.14, 0.15, FUR), (0.12, 0.35, FUR), (0.02, 0.5, CRYS)], sides=6, loc=(0, 0.4, 0.72), r=face_to((0, 1, 0.3)))
    rig.add("tail", p, parent="body", pivot=(0, 0.4, 0.72))
    for nm, x, y in (("leg_fl", 0.13, -0.32), ("leg_fr", -0.13, -0.32), ("leg_bl", 0.13, 0.3), ("leg_br", -0.13, 0.3)):
        p = Part()
        capsule(p, (x, y, 0.6), (x * 1.05, y + 0.03, 0.06), 0.06, 0.04, FUR, sides=5)
        p.ball(0.06, (x * 1.05, y - 0.03, 0.04), FUR_D, scale=(1, 1.4, 0.6), subdiv=1)
        rig.add(nm, p, parent="body", pivot=(x, y, 0.6))
    rest = dict(root=dict(loc=(0, 0, 0), rot=(0, 0, 0)), body=dict(loc=(0, 0, 0), rot=(0, 0, 0)), head=R(), jaw=R(), tail=R(), breath=dict(scale=0.02, loc=(0, 0, 0)), leg_fl=R(), leg_fr=R(), leg_bl=R(), leg_br=R())
    with rig.clip("idle", 30, loop=True) as c:                    # hechelt Atemwölkchen
        c.key(0, **rest)
        c.key(6, jaw=R(-14, 0, 0), breath=dict(scale=1.0, loc=(0, 0, 0)), tail=R(0, 0, 20))
        c.key(14, jaw=R(0, 0, 0), breath=dict(scale=1.4, loc=(0, -0.2, 0.15)))
        c.key(16, breath=dict(scale=0.02))
        c.key(22, head=R(0, 0, 15), tail=R(0, 0, -20))
    with rig.clip("walk", 12, loop=True, stride=2.2) as c:
        c.wave("leg_fl", rot=(50, 0, 0))
        c.wave("leg_fr", rot=(50, 0, 0), phase=0.1)
        c.wave("leg_bl", rot=(50, 0, 0), phase=0.5)
        c.wave("leg_br", rot=(50, 0, 0), phase=0.6)
        c.wave("body", rot=(8, 0, 0), loc=(0, 0, 0.06), phase=0.25)
        c.wave("head", rot=(-10, 0, 0), phase=0.5)
        c.wave("tail", rot=(14, 0, 0), base_rot=(-10, 0, 0), phase=0.75)
        c.key(0, breath=dict(scale=0.02))
    with rig.clip("attack", 15, hit=8) as c:
        c.key(0, **rest)
        c.key(5, body=dict(rot=(-10, 0, 0), loc=(0, 0.1, 0)), head=R(-20, 0, 0), jaw=R(-40, 0, 0))
        c.key(8, body=dict(rot=(10, 0, 0), loc=(0, -0.3, 0)), head=R(10, 0, 0), jaw=R(0, 0, 0), leg_fl=R(-50, 0, 0), leg_fr=R(-50, 0, 0), _i="LINEAR")
        c.key(15, **rest)
    with rig.clip("pounce", 15, hit=10) as c:
        c.key(0, **rest)
        c.key(3, body=dict(rot=(-8, 0, 0), loc=(0, 0.1, -0.15)), leg_bl=R(30, 0, 0), leg_br=R(30, 0, 0))
        c.key(7, root=dict(loc=(0, -0.4, 0.8)), body=dict(rot=(-14, 0, 0), loc=(0, 0, 0)), leg_fl=R(-80, 0, 0), leg_fr=R(-80, 0, 0), leg_bl=R(60, 0, 0), leg_br=R(60, 0, 0), jaw=R(-45, 0, 0), tail=R(-40, 0, 0))
        c.key(11, root=dict(loc=(0, -0.9, 0.1)), body=dict(rot=(16, 0, 0)), jaw=R(0, 0, 0), leg_fl=R(-30, 0, 0), leg_fr=R(-30, 0, 0))
        c.key(15, **rest)
    with rig.clip("howl", 36) as c:                                # setzt sich und heult den Mond an
        c.key(0, **rest)
        c.key(9, body=dict(rot=(-35, 0, 0), loc=(0, 0.1, -0.1)), leg_bl=R(70, 0, 0), leg_br=R(70, 0, 0), leg_fl=R(30, 0, 0), leg_fr=R(30, 0, 0), head=R(-30, 0, 0), jaw=R(-30, 0, 0), breath=dict(scale=0.02))
        c.key(18, head=R(-36, 0, 6), jaw=R(-40, 0, 0), breath=dict(scale=1.4, loc=(0, -0.1, 0.4)))
        c.key(27, head=R(-36, 0, -6), jaw=R(-34, 0, 0), breath=dict(scale=2.0, loc=(0, -0.2, 0.7)))
        c.key(36, **rest)
    with rig.clip("hit", 9) as c:
        c.key(0, **rest)
        c.key(3, body=dict(rot=(-12, 0, 10), loc=(0, 0.15, 0.05)), head=R(-20, 0, -14), jaw=R(-30, 0, 0), tail=R(-40, 0, 0))
        c.key(9, **rest)
    with rig.clip("death", 30) as c:
        c.key(0, **rest)
        c.key(8, root=dict(rot=(0, 30, 0), loc=(0, 0, 0.15)), head=R(-30, 0, 0), jaw=R(-40, 0, 0))
        c.key(16, root=dict(rot=(0, 88, 0), loc=(0, 0, 0.2)), leg_fl=R(-30, 0, 0), leg_bl=R(30, 0, 0))
        c.key(30, root=dict(rot=(0, 90, 0), loc=(0, 0, 0.16)), head=R(10, 0, 0), jaw=R(-20, 0, 0), eyes=dict(scale=0.05))
    rig.finish()


# ================================================================= Yeti (Brocken): zotteliger Riese mit Eisbrocken in der Faust
def eis_yeti():
    rig = Rig("eis_yeti", role="tank")
    FACE = "8AA8D8"
    rig.node("hips", pivot=(0, 0, 1.0))
    p = Part()                                                                                       # zotteliger Leib in Fellstufen
    lathe(p, [(0.6, 0.85, FUR_D), (0.8, 1.0, FUR), (0.9, 1.5, FUR), (0.85, 2.0, FUR_D), (0.95, 2.3, FUR), (0.7, 2.75, FUR), (0.3, 2.95, FUR)], sides=12, sy=0.85)
    for k in range(10):
        a = k * math.tau / 10
        p.cone(0.14, 0.3, (0.86 * math.cos(a), 0.72 * math.sin(a), 1.95), FUR, r=rot(180, 0, 0) @ rot(0, 0, 0), sides=4)   # Zotteln
    p.ball(0.45, (0, -0.55, 1.5), "D8E4F0", scale=(1.2, 0.5, 1.0), subdiv=1)                         # Bauch
    rig.add("body", p, parent="hips", pivot=(0, 0, 1.0))
    p = Part()                                                                                       # Gesicht: blaues Maul, Hauer, Brauen voller Eis
    p.ball(0.42, (0, -0.55, 2.6), FACE, scale=(1.1, 0.6, 0.9), subdiv=2)
    p.ball(0.25, (0, -0.8, 2.42), "3A2A4A", scale=(1.3, 0.4, 0.6), subdiv=1)
    for s in (-1, 1):
        p.cone(0.06, 0.2, (0.2 * s, -0.86, 2.36), WHITE, sides=4)
        p.ball(0.09, (0.18 * s, -0.86, 2.72), WHITE, subdiv=1)
        p.box((0.24, 0.1, 0.08), (0.18 * s, -0.86, 2.86), ICE_L, r=rot(0, -14 * s, 0), bevel=0.0)
    rig.add("head", p, parent="body", pivot=(0, -0.3, 2.5))
    p = Part()
    for s in (-1, 1):
        p.ball(0.045, (0.18 * s, -0.94, 2.72), INK, subdiv=1)
    rig.add("pupil", p, parent="head", pivot=(0, -0.94, 2.72), look=True)
    for s, nm in ((1, "arm_l"), (-1, "arm_r")):                                                     # lange Gorillaarme
        p = Part()
        capsule(p, (0.85 * s, 0, 2.45), (1.15 * s, -0.15, 1.6), 0.3, 0.26, FUR, sides=7)
        rig.add(nm, p, parent="body", pivot=(0.85 * s, 0, 2.45))
        p = Part()
        capsule(p, (1.15 * s, -0.15, 1.6), (1.2 * s, -0.35, 0.75), 0.26, 0.22, FUR_D, sides=7)
        p.ball(0.28, (1.2 * s, -0.4, 0.6), FACE, subdiv=1)
        if s < 0:
            p.ball(0.42, (-1.25, -0.62, 0.62), ICE, subdiv=1)                                         # Eisbrocken in der Faust
            p.cone(0.15, 0.3, (-1.4, -0.75, 0.9), ICE_L, r=rot(30, -30, 0), sides=4)
        rig.add(nm.replace("arm", "fore"), p, parent=nm, pivot=(1.15 * s, -0.15, 1.6))
    for s, nm in ((1, "leg_l"), (-1, "leg_r")):
        p = Part()
        capsule(p, (0.4 * s, 0, 0.95), (0.42 * s, 0, 0.25), 0.28, 0.26, FUR, sides=7)
        p.ball(0.3, (0.42 * s, -0.15, 0.1), FACE, scale=(1, 1.4, 0.45), subdiv=1)
        rig.add(nm, p, parent="hips", pivot=(0.4 * s, 0, 1.0))
    rest = dict(root=dict(loc=(0, 0, 0), rot=(0, 0, 0)), hips=dict(loc=(0, 0, 0), rot=(0, 0, 0)), body=R(8, 0, 0), head=R(-8, 0, 0), arm_l=R(), arm_r=R(), fore_l=R(), fore_r=R(), leg_l=R(), leg_r=R())
    with rig.clip("idle", 48, loop=True) as c:                     # trommelt auf die Brust
        c.key(0, **rest)
        c.key(10, arm_l=R(-70, 0, -40), fore_l=R(-60, 0, 0), arm_r=R(-30, 0, 20))
        c.key(14, arm_l=R(-55, 0, -30), body=R(4, 0, 0))
        c.key(18, arm_l=R(-70, 0, -40), body=R(8, 0, 0), head=R(-20, 0, 0))
        c.key(22, arm_l=R(-55, 0, -30))
        c.key(32, arm_l=R(0, 0, 0), fore_l=R(0, 0, 0), arm_r=R(0, 0, 0), head=R(-8, 0, 0))
    with rig.clip("walk", 42, loop=True, stride=1.8) as c:         # stapft, Knöchel schleifen
        c.wave("leg_l", rot=(28, 0, 0))
        c.wave("leg_r", rot=(28, 0, 0), phase=0.5)
        c.wave("arm_l", rot=(-22, 0, 0), phase=0.5)
        c.wave("arm_r", rot=(-16, 0, 0))
        c.wave("hips", rot=(0, 6, 0), phase=0.25)
        c.wave("hips", loc=(0, 0, 0.08), n=2, phase=0.25)
        c.wave("body", rot=(0, 0, 5), base_rot=(10, 0, 0), phase=0.5)
    with rig.clip("attack", 33, hit=18) as c:                      # Faustschlag von der Seite (schleudert den Helden weg)
        c.key(0, **rest)
        c.key(11, body=R(0, 0, 30), arm_l=R(-60, 0, 60), fore_l=R(-40, 0, 0))
        c.key(18, body=R(10, 0, -30), arm_l=R(-80, 0, -30), fore_l=R(0, 0, 0), hips=dict(loc=(0, -0.2, 0)), _i="LINEAR")
        c.key(33, **rest)
    with rig.clip("throw", 42, hit=24) as c:                       # stemmt den Eisbrocken über den Kopf und wirft im Bogen
        c.key(0, **rest)
        c.key(14, arm_r=R(-170, 0, 10), fore_r=R(-40, 0, 0), body=R(-16, 0, 0), head=R(-24, 0, 0), hips=dict(loc=(0, 0.1, -0.1)))
        c.key(24, arm_r=R(-50, 0, 0), fore_r=R(0, 0, 0), body=R(22, 0, 0), head=R(0, 0, 0), hips=dict(loc=(0, -0.1, 0)), _i="LINEAR")
        c.key(42, **rest)
    with rig.clip("hit", 9) as c:
        c.key(0, **rest)
        c.key(3, body=R(-6, 0, 8), head=R(-22, 0, 8), arm_l=R(0, 0, 20))
        c.key(9, **rest)
    with rig.clip("death", 45) as c:                               # brüllt, fällt rücklings in den Schnee
        c.key(0, **rest)
        c.key(10, head=R(-30, 0, 0), arm_l=R(-150, 0, -30), arm_r=R(-150, 0, 30))
        c.key(28, root=dict(rot=(-86, 0, 0), loc=(0, 0, 0.55)), arm_l=R(-170, 0, -60), arm_r=R(-170, 0, 60), leg_l=R(-30, 0, 0), _i="LINEAR")
        c.key(32, root=dict(rot=(-80, 0, 0), loc=(0, 0, 0.65)))
        c.key(45, root=dict(rot=(-88, 0, 0), loc=(0, 0, 0.55)), leg_l=R(0, 0, 10))
    rig.finish(icon_yaw=-28, icon_pitch=12)


# ================================================================= Kristallschütze (Fernkampf): schlanke Eisfigur mit Eisbogen
def eis_kristallschuetze():
    rig = Rig("eis_kristallschuetze", role="ranged")
    rig.node("hips", pivot=(0, 0, 0.75))
    p = Part()                                                                                       # facettierter Kristallleib, Umhang
    lathe(p, [(0.12, 0.7, ICE_D), (0.2, 0.8, ICE), (0.24, 1.15, ICE_L), (0.28, 1.35, ICE), (0.14, 1.5, ICE_D)], sides=6)
    lathe(p, [(0.4, 0.55, BLUE), (0.3, 0.9, BLUE), (0.28, 1.35, "4A7AD8"), (0.12, 1.45, BLUE)], sides=7, loc=(0, 0.06, 0), sy=0.6, cap=False)
    rig.add("body", p, parent="hips", pivot=(0, 0, 0.75))
    p = Part()                                                                                       # Kopf: spitzer Kristall mit Kapuze
    lathe(p, [(0.0, 1.5, ICE_L), (0.16, 1.6, ICE), (0.15, 1.8, ICE_L), (0.0, 2.15, CRYS)], sides=6)
    lathe(p, [(0.2, 1.55, BLUE), (0.22, 1.75, BLUE), (0.1, 1.95, "4A7AD8"), (0.0, 2.05, BLUE)], sides=7, loc=(0, 0.06, 0), sy=0.95)
    rig.add("head", p, parent="body", pivot=(0, 0, 1.5))
    p = Part()
    for s in (-1, 1):
        p.ball(0.035, (0.06 * s, -0.15, 1.73), CRYS, scale=(1.4, 0.5, 0.6), subdiv=1)
    rig.add("eyes", p, parent="head", pivot=(0, -0.15, 1.73), glow=True)
    p = Part()                                                                                       # linker Arm mit dem Eisbogen
    capsule(p, (0.24, 0, 1.35), (0.45, -0.3, 1.25), 0.05, 0.04, ICE, sides=5)
    for k in range(4):
        a0, a1 = -70 + k * 35, -35 + k * 35
        z0, z1 = 1.25 + 0.6 * math.sin(math.radians(a0)), 1.25 + 0.6 * math.sin(math.radians(a1))
        y0, y1 = -0.35 - 0.2 * math.cos(math.radians(a0)), -0.35 - 0.2 * math.cos(math.radians(a1))
        capsule(p, (0.48, y0, z0), (0.48, y1, z1), 0.035, 0.035, ICE_L, sides=4)
    p.cone(0.05, 0.14, (0.48, -0.42, 1.88), CRYS, sides=4)
    p.cone(0.05, 0.14, (0.48, -0.42, 0.62), CRYS, r=rot(180, 0, 0), sides=4)
    rig.add("arm_l", p, parent="body", pivot=(0.24, 0, 1.35))
    p = Part()
    capsule(p, (-0.24, 0, 1.35), (-0.3, -0.25, 1.25), 0.05, 0.04, ICE, sides=5)
    capsule(p, (-0.3, -0.25, 1.25), (0.3, -0.45, 1.25), 0.02, 0.02, "E8F8FF", sides=4)               # Pfeil
    p.cone(0.045, 0.1, (0.36, -0.47, 1.25), CRYS, r=rot(0, 90, 0), sides=4)
    rig.add("arm_r", p, parent="body", pivot=(-0.24, 0, 1.35))
    p = Part()                                                                                       # Köcher mit Kristallpfeilen
    p.cyl(0.08, 0.45, (0.0, 0.22, 1.2), "7A5A3A", r=rot(-15, 0, 15), sides=6)
    for k in range(3):
        p.cone(0.04, 0.16, (-0.05 + 0.05 * k, 0.28, 1.5), CRYS, sides=4)
    rig.add("quiver", p, parent="body", pivot=(0, 0.22, 1.2))
    for s, nm in ((1, "leg_l"), (-1, "leg_r")):
        p = Part()
        capsule(p, (0.1 * s, 0, 0.72), (0.11 * s, 0, 0.08), 0.06, 0.04, ICE_D, sides=5)
        p.cone(0.07, 0.14, (0.11 * s, -0.03, 0.06), ICE, r=rot(-90, 0, 0), sides=4)
        rig.add(nm, p, parent="hips", pivot=(0.1 * s, 0, 0.75))
    rest = dict(root=dict(loc=(0, 0, 0), rot=(0, 0, 0)), hips=dict(loc=(0, 0, 0), rot=(0, 0, 0)), body=R(), head=R(), arm_l=R(), arm_r=R(), leg_l=R(), leg_r=R(), eyes=dict(scale=1.0))
    with rig.clip("idle", 42, loop=True) as c:                     # schwebende Ruhe, blickt umher
        c.key(0, **rest)
        c.key(14, head=R(0, 0, 20), body=R(0, 0, 4), hips=dict(loc=(0, 0, 0.04)))
        c.key(28, head=R(0, 0, -20), body=R(0, 0, -4), hips=dict(loc=(0, 0, 0)))
    with rig.clip("walk", 21, loop=True, stride=1.3) as c:         # gleitende, lange Schritte
        c.wave("leg_l", rot=(30, 0, 0))
        c.wave("leg_r", rot=(30, 0, 0), phase=0.5)
        c.wave("arm_r", rot=(-20, 0, 0))
        c.wave("hips", loc=(0, 0, 0.04), n=2, phase=0.25)
        c.wave("body", rot=(0, 4, 0), phase=0.25)
    with rig.clip("attack", 33, hit=24) as c:                      # dreht sich seitlich, spannt, lässt los
        c.key(0, **rest)
        c.key(10, body=R(0, 0, -50), arm_l=R(-80, 0, -10), head=R(0, 0, 45))
        c.key(20, arm_r=dict(rot=(-80, 0, 30), loc=(0, 0.15, 0)), eyes=dict(scale=1.5))
        c.key(24, arm_r=dict(rot=(-80, 0, 50), loc=(0, 0.25, 0)), eyes=dict(scale=1.0), _i="LINEAR")
        c.key(26, arm_r=dict(rot=(-60, 0, 0), loc=(0, 0, 0)))
        c.key(33, **rest)
    with rig.clip("hit", 9) as c:
        c.key(0, **rest)
        c.key(3, body=R(-14, 0, 10), head=R(-20, 0, 0), eyes=dict(scale=1.6))
        c.key(9, **rest)
    with rig.clip("death", 30) as c:                               # zerspringt: Glieder fallen auseinander
        c.key(0, **rest)
        c.key(6, body=R(-10, 0, 0), eyes=dict(scale=2.0))
        c.key(14, hips=dict(loc=(0, 0, -0.4)), head=dict(rot=(60, 0, 40), loc=(0.3, -0.3, -0.6)), arm_l=dict(rot=(0, 90, 0), loc=(0.3, 0, -0.9)), arm_r=dict(rot=(0, -90, 0), loc=(-0.3, 0, -0.9)), _i="LINEAR")
        c.key(30, hips=dict(loc=(0, 0, -0.6)), body=R(80, 0, 0), head=dict(rot=(90, 0, 60), loc=(0.4, -0.5, -1.3)), eyes=dict(scale=0.05), arm_l=dict(rot=(0, 90, 0), loc=(0.4, 0, -1.1)), arm_r=dict(rot=(0, -90, 0), loc=(-0.4, 0, -1.1)), leg_l=R(0, 0, 40), leg_r=R(0, 0, -40))
    spawn_clip(rig, 1.8)
    rig.finish()


# ================================================================= Eisgeist (Flieger): wehender Schleier mit hohlen Augen
def eis_eisgeist():
    rig = Rig("eis_eisgeist", role="air")
    p = Part()                                                                                       # Schleier: Glocke mit gezacktem Saum
    lathe(p, [(0.0, 1.45, SNOW), (0.3, 1.4, SNOW), (0.42, 1.15, ICE_L), (0.48, 0.8, ICE_L), (0.55, 0.55, ICE)], sides=12, cap=False)
    for k in range(8):
        a = k * math.tau / 8
        p.cone(0.12, 0.3, (0.52 * math.cos(a), 0.52 * math.sin(a), 0.45), ICE, r=rot(180, 0, 0), sides=4)
    rig.add("veil", p, pivot=(0, 0, 1.2), ghost=True)
    p = Part()                                                                                       # hohle Augen und O-Mund
    for s in (-1, 1):
        p.ball(0.09, (0.13 * s, -0.4, 1.12), "1A2A4A", scale=(1, 0.4, 1.4), subdiv=1)
    p.ball(0.07, (0, -0.44, 0.9), "1A2A4A", scale=(1, 0.4, 1.3), subdiv=1)
    rig.add("face", p, parent="veil", pivot=(0, -0.4, 1.0))
    p = Part()
    for s in (-1, 1):
        p.ball(0.03, (0.13 * s, -0.45, 1.12), CRYS, subdiv=1)
    rig.add("pupil", p, parent="face", pivot=(0, -0.45, 1.12), look=True, glow=True)
    for s, nm in ((1, "arm_l"), (-1, "arm_r")):                                                     # wehende Ärmel
        p = Part()
        lathe(p, [(0.08, 0.0, SNOW), (0.12, 0.25, ICE_L), (0.03, 0.5, ICE)], sides=5, loc=(0.4 * s, -0.05, 1.1), r=face_to((0.8 * s, -0.2, -0.4)))
        rig.add(nm, p, parent="veil", pivot=(0.4 * s, -0.05, 1.1), ghost=True)
    p = Part()                                                                                       # Eiskristall-Krone
    for k in range(5):
        a = k * math.tau / 5
        p.cone(0.04, 0.2, (0.12 * math.cos(a), 0.12 * math.sin(a), 1.5), CRYS, r=rot(15 * math.cos(a), 15 * math.sin(a), 0), sides=4)
    rig.add("crown", p, parent="veil", pivot=(0, 0, 1.45), glow=True)
    rest = dict(root=dict(loc=(0, 0, 0), rot=(0, 0, 0)), veil=dict(rot=(0, 0, 0), scale=1.0, loc=(0, 0, 0)), face=dict(scale=1.0), arm_l=R(), arm_r=R(), crown=dict(scale=1.0))
    with rig.clip("idle", 36, loop=True) as c:                     # wabert, Ärmel wehen
        c.wave("veil", scale=(0.05, 0.05, -0.05), loc=(0, 0, 0.08))
        c.wave("arm_l", rot=(20, 0, 15), phase=0.2)
        c.wave("arm_r", rot=(20, 0, -15), phase=0.7)
        c.wave("crown", scale=(0.15, 0.15, 0.15), n=2)
    with rig.clip("walk", 24, loop=True, stride=2.0) as c:          # zieht vorgeneigt, Saum flattert nach hinten
        c.wave("veil", rot=(4, 4, 0), base_rot=(18, 0, 0), scale=(0.04, 0.04, -0.04))
        c.wave("arm_l", rot=(15, 0, 10), base_rot=(30, 0, 0), phase=0.2)
        c.wave("arm_r", rot=(15, 0, -10), base_rot=(30, 0, 0), phase=0.7)
    with rig.clip("attack", 18, hit=9) as c:                       # kalter Hauch
        c.key(0, **rest)
        c.key(6, veil=dict(scale=(0.9, 0.9, 1.1), rot=(-10, 0, 0)), face=dict(scale=(1, 1, 1.3)))
        c.key(9, veil=dict(scale=(1.15, 1.15, 0.9), rot=(20, 0, 0), loc=(0, -0.25, 0)), face=dict(scale=(1.3, 1, 1.6)), arm_l=R(-70, 0, 0), arm_r=R(-70, 0, 0), _i="LINEAR")
        c.key(18, **rest)
    with rig.clip("freeze", 30, hit=16) as c:                      # hebt die Ärmel, die Krone gleißt – der Turm vereist
        c.key(0, **rest)
        c.key(10, arm_l=R(-150, 0, -20), arm_r=R(-150, 0, 20), veil=dict(scale=(1.1, 1.1, 1.15), loc=(0, 0, 0.25)), crown=dict(scale=1.4))
        c.key(16, arm_l=R(-60, 0, 10), arm_r=R(-60, 0, -10), veil=dict(scale=(1.25, 1.25, 0.85), loc=(0, 0, 0)), crown=dict(scale=2.0), _i="LINEAR")
        c.key(30, **rest)
    with rig.clip("hit", 9) as c:
        c.key(0, **rest)
        c.key(3, veil=dict(scale=(1.25, 1.25, 0.7), rot=(-15, 0, 10)), face=dict(scale=0.7))
        c.key(9, **rest)
    with rig.clip("death", 27) as c:                               # verweht in einer Spirale
        c.key(0, **rest)
        c.key(10, veil=dict(rot=(0, 0, 180), scale=(1.2, 1.2, 0.8)), crown=dict(scale=1.6))
        c.key(27, veil=dict(rot=(0, 0, 540), scale=(0.05, 0.05, 0.05), loc=(0, 0, 0.4)), crown=dict(scale=0.05), _i="LINEAR")
    rig.finish(icon_pitch=12)


# ================================================================= Lawinenroller (Sonder): Schneekugel mit Gesicht, wächst beim Rollen
def eis_lawinenroller():
    rig = Rig("eis_lawinenroller", role="special")
    p = Part()                                                                                       # Schneekugel mit Klumpen, Steinchen, Zweigen
    p.ball(0.5, (0, 0, 0.5), SNOW, subdiv=2)
    for (x, y, z, r) in ((0.35, 0.25, 0.75, 0.15), (-0.4, 0.1, 0.65, 0.14), (0.15, 0.4, 0.3, 0.13), (-0.2, 0.35, 0.85, 0.12)):
        p.ball(r, (x, y, z), SNOW_D, subdiv=1)
    for (x, y, z) in ((0.42, -0.1, 0.35), (-0.3, 0.38, 0.4)):
        p.ball(0.05, (x, y, z), "6A6A7A", subdiv=1)
    capsule(p, (0.2, 0.3, 0.9), (0.35, 0.45, 1.15), 0.025, 0.015, "7A5A3A", sides=4)
    capsule(p, (-0.3, -0.2, 0.85), (-0.45, -0.25, 1.05), 0.025, 0.015, "7A5A3A", sides=4)
    for s in (-1, 1):                                                                                # Kohleaugen, Karottennase, Grinsen
        p.ball(0.07, (0.17 * s, -0.45, 0.65), INK, subdiv=1)
    p.cone(0.07, 0.28, (0, -0.52, 0.52), "F28A2A", r=rot(90, 0, 0), sides=6)
    for k in range(5):
        a = math.radians(-50 + k * 25)
        p.ball(0.035, (0.22 * math.sin(a), -0.47, 0.38 - 0.06 * math.cos(a)), INK, subdiv=1)
    rig.add("ball", p, pivot=(0, 0, 0.5))
    p = Part()                                                                                       # Mütze, die oben drauf bleibt
    lathe(p, [(0.22, 0.95, RED), (0.24, 1.0, WHITE), (0.18, 1.05, RED), (0.08, 1.25, RED)], sides=8, loc=(0.05, 0, 0))
    p.ball(0.07, (0.05, 0, 1.3), WHITE, subdiv=1)
    rig.add("hat", p, pivot=(0.05, 0, 0.97))
    p = Part()                                                                                       # Schneespritzer (beim Rollen)
    for k in range(4):
        p.ball(0.1, (0.3 * (k % 2 * 2 - 1), 0.5 + 0.12 * k, 0.1 + 0.05 * k), SNOW, subdiv=1)
    rig.add("spray", p, pivot=(0, 0.5, 0.1), ghost=True)
    hid = dict(scale=0.02)
    rest = dict(root=dict(loc=(0, 0, 0), rot=(0, 0, 0)), ball=dict(rot=(0, 0, 0), scale=1.0, loc=(0, 0, 0)), hat=dict(rot=(0, 0, 0), loc=(0, 0, 0)), spray=hid)
    with rig.clip("idle", 30, loop=True) as c:                     # wippt fröhlich, schaut sich um
        c.key(0, **rest)
        c.key(8, ball=dict(rot=(0, 0, 15), scale=(1.03, 1.03, 0.97)), hat=dict(rot=(0, -10, 10)))
        c.key(15, ball=dict(rot=(0, 0, 0), scale=1.0, loc=(0, 0, 0.05)))
        c.key(22, ball=dict(rot=(0, 0, -15), scale=(1.03, 1.03, 0.97), loc=(0, 0, 0)), hat=dict(rot=(0, 10, -10)))
    with rig.clip("walk", 18, loop=True, stride=1.6) as c:          # hoppelt (vor dem Losrollen)
        c.key(0, ball=dict(loc=(0, 0, 0), scale=(1.08, 1.08, 0.9), rot=(0, 0, 0)), hat=dict(loc=(0, 0, 0)), spray=hid)
        c.key(6, ball=dict(loc=(0, 0, 0.25), scale=(0.95, 0.95, 1.08), rot=(10, 0, 0)), hat=dict(loc=(0, 0, 0.3)))
        c.key(12, ball=dict(loc=(0, 0, 0.1), scale=1.0, rot=(-5, 0, 0)), hat=dict(loc=(0, 0, 0.18)))
    with rig.clip("roll", 12, loop=True, stride=3.1) as c:         # rollt: die Kugel dreht sich vorwärts, Schnee stiebt
        c.key(0, ball=dict(rot=(0, 0, 0), loc=(0, 0, 0)), hat=dict(rot=(-10, 0, 0), loc=(0, 0.05, 0)), spray=dict(scale=1.0), _i="LINEAR")
        c.key(6, ball=dict(rot=(-180, 0, 0)), spray=dict(scale=1.3), hat=dict(rot=(-14, 0, 6), loc=(0, 0.05, 0.05)), _i="LINEAR")
        c.key(12, ball=dict(rot=(-360, 0, 0)), _i="LINEAR")
    with rig.clip("attack", 15, hit=8) as c:                       # stößt mit dem Kopf zu
        c.key(0, **rest)
        c.key(5, ball=dict(rot=(-20, 0, 0), loc=(0, 0.15, 0)))
        c.key(8, ball=dict(rot=(25, 0, 0), loc=(0, -0.3, 0), scale=(1.1, 1.1, 0.9)), _i="LINEAR")
        c.key(15, **rest)
    with rig.clip("hit", 9) as c:
        c.key(0, **rest)
        c.key(3, ball=dict(scale=(1.15, 1.15, 0.8), rot=(-10, 0, 0)), hat=dict(loc=(0, 0, 0.2), rot=(-20, 0, 10)))
        c.key(9, **rest)
    with rig.clip("death", 24) as c:                               # zerplatzt zu einem Schneehaufen, die Mütze bleibt liegen
        c.key(0, **rest)
        c.key(5, ball=dict(scale=(1.3, 1.3, 1.25)), hat=dict(loc=(0, 0, 0.3)))
        c.key(9, ball=dict(scale=(1.8, 1.8, 0.35), loc=(0, 0, -0.3)), spray=dict(scale=1.6), hat=dict(loc=(0.2, -0.1, 0.2), rot=(0, 30, 0)), _i="LINEAR")
        c.key(24, ball=dict(scale=(1.9, 1.9, 0.3), loc=(0, 0, -0.33)), spray=hid, hat=dict(loc=(0.3, -0.2, -0.65), rot=(0, 70, 0)))
    spawn_clip(rig, 1.0, spray=hid)
    rig.finish()


# ================================================================= Boss: Frostbrocken – Eisgolem mit Kristallkrone
def boss_eis():
    rig = Rig("boss_eis", role="boss")
    rig.node("hips", pivot=(0, 0, 1.4))
    p = Part()                                                                                       # Leib aus Eisblöcken, Schnee auf den Schultern
    p.box((2.0, 1.4, 1.6), (0, 0, 2.6), ICE, r=rot(0, 0, 4), bevel=0.25, segs=2)
    p.box((1.6, 1.2, 0.8), (0, 0.05, 1.7), ICE_D, bevel=0.2, segs=1)
    p.ball(0.7, (0, -0.4, 2.5), ICE_L, scale=(1.1, 0.4, 1.0), subdiv=2)                              # durchscheinender Kern
    for (x, y, z) in ((0.9, 0.1, 3.45), (-0.9, 0.1, 3.45)):
        p.ball(0.45, (x, y, z), SNOW, scale=(1.2, 1.1, 0.45), subdiv=2)
    for k in range(5):                                                                                # Kristallzacken auf dem Rücken
        p.cone(0.18, 0.7 + 0.2 * (k % 2), (-0.6 + 0.3 * k, 0.6, 3.3), CRYS, r=rot(-30, 0, -20 + 10 * k), sides=5)
    rig.add("torso", p, parent="hips", pivot=(0, 0, 2.0))
    p = Part()
    p.ball(0.35, (0, -0.45, 2.55), "B8F0FF", subdiv=2)
    rig.add("core", p, parent="torso", pivot=(0, -0.45, 2.55), glow=True)
    p = Part()                                                                                       # Kopf: Eisblock mit Schneebart und Kristallkrone
    p.box((0.9, 0.8, 0.75), (0, -0.15, 3.85), ICE_L, bevel=0.15, segs=1)
    p.ball(0.45, (0, -0.5, 3.6), SNOW, scale=(1.1, 0.5, 0.7), subdiv=2)
    for s in (-1, 1):
        p.box((0.26, 0.08, 0.1), (0.22 * s, -0.57, 4.05), ICE_D, r=rot(0, -16 * s, 0), bevel=0.0)
    for k in range(7):
        a = k * math.tau / 7
        p.cone(0.12, 0.5 + 0.25 * (k % 2), (0.35 * math.cos(a), -0.15 + 0.32 * math.sin(a), 4.35), CRYS, r=rot(12 * math.sin(a), -12 * math.cos(a), 0), sides=5)
    rig.add("head", p, parent="torso", pivot=(0, -0.1, 3.5))
    p = Part()
    for s in (-1, 1):
        p.ball(0.1, (0.22 * s, -0.56, 3.92), CRYS, scale=(1.3, 0.5, 0.8), subdiv=1)
    rig.add("eyes", p, parent="head", pivot=(0, -0.56, 3.92), glow=True)
    for s, nm in ((1, "arm_l"), (-1, "arm_r")):
        p = Part()
        p.ball(0.5, (1.25 * s, 0, 3.15), ICE_D, subdiv=2)
        p.box((0.6, 0.6, 1.0), (1.4 * s, -0.05, 2.45), ICE, r=rot(0, 8 * s, 0), bevel=0.15, segs=1)
        rig.add(nm, p, parent="torso", pivot=(1.25 * s, 0, 3.15))
        p = Part()
        p.box((0.55, 0.55, 0.9), (1.5 * s, -0.15, 1.55), ICE_L, bevel=0.15, segs=1)
        p.box((0.8, 0.75, 0.6), (1.52 * s, -0.25, 0.9), ICE, bevel=0.18, segs=1)                     # Riesenfaust
        for k in range(3):
            p.cone(0.1, 0.3, (1.52 * s + 0.2 * (k - 1), -0.65, 0.95), CRYS, r=rot(90, 0, 0), sides=4)
        rig.add(nm.replace("arm", "fore"), p, parent=nm, pivot=(1.45 * s, -0.1, 1.95))
    for s, nm in ((1, "leg_l"), (-1, "leg_r")):
        p = Part()
        p.box((0.7, 0.7, 1.2), (0.55 * s, 0, 0.75), ICE_D, bevel=0.15, segs=1)
        p.box((0.8, 0.95, 0.3), (0.55 * s, -0.1, 0.15), SNOW_D, bevel=0.1, segs=1)
        rig.add(nm, p, parent="hips", pivot=(0.55 * s, 0, 1.4))
    rest = dict(root=dict(loc=(0, 0, 0), rot=(0, 0, 0)), hips=dict(loc=(0, 0, 0), rot=(0, 0, 0)), torso=R(), head=R(), arm_l=R(), arm_r=R(), fore_l=R(), fore_r=R(), leg_l=R(), leg_r=R(), core=dict(scale=1.0), eyes=dict(scale=1.0))
    with rig.clip("idle", 48, loop=True) as c:                     # knirscht, der Kern pulsiert
        c.key(0, **rest)
        c.key(12, torso=R(0, 3, 0), core=dict(scale=1.2), head=R(0, 0, 8))
        c.key(24, torso=R(-3, 0, 0), core=dict(scale=1.0), head=R(4, 0, 0))
        c.key(36, torso=R(0, -3, 0), core=dict(scale=1.2), head=R(0, 0, -8))
    with rig.clip("walk", 48, loop=True, stride=2.3) as c:
        c.wave("leg_l", rot=(26, 0, 0))
        c.wave("leg_r", rot=(26, 0, 0), phase=0.5)
        c.wave("arm_l", rot=(-18, 0, 0), phase=0.5)
        c.wave("arm_r", rot=(-18, 0, 0))
        c.wave("hips", rot=(0, 6, 0), phase=0.25)
        c.wave("hips", loc=(0, 0, 0.1), n=2, phase=0.25)
        c.wave("head", rot=(0, 0, 5), phase=0.5)
    with rig.clip("attack", 36, hit=20) as c:                      # Hammerfaust
        c.key(0, **rest)
        c.key(12, torso=R(-12, 0, -16), arm_r=R(-160, 0, 10), fore_r=R(-30, 0, 0))
        c.key(20, torso=R(18, 0, 10), arm_r=R(-50, 0, 0), fore_r=R(0, 0, 0), hips=dict(loc=(0, -0.2, -0.15)), _i="LINEAR")
        c.key(36, **rest)
    with rig.clip("hit", 9) as c:
        c.key(0, **rest)
        c.key(3, torso=R(-8, 0, 6), head=R(-16, 0, 8), core=dict(scale=1.4), eyes=dict(scale=1.4))
        c.key(9, **rest)
    with rig.clip("death", 60) as c:                               # Risse, der Kern erlischt, bricht auf die Knie und kippt vornüber
        c.key(0, **rest)
        c.key(12, torso=R(-10, 0, 0), head=R(-20, 0, 0), core=dict(scale=1.6), eyes=dict(scale=1.6))
        c.key(26, hips=dict(loc=(0, 0, -0.75)), leg_l=R(-80, 0, 0), leg_r=R(-80, 0, 0), torso=R(14, 0, 0), arm_l=R(-30, 0, 20), arm_r=R(-30, 0, -20), core=dict(scale=0.8), _i="LINEAR")
        c.key(44, root=dict(rot=(78, 0, 0), loc=(0, 0, 0.0)), hips=dict(loc=(0, 0, -0.75)), torso=R(10, 0, 0), arm_l=R(-160, 0, 20), arm_r=R(-160, 0, -20), _i="LINEAR")
        c.key(60, root=dict(rot=(80, 0, 0), loc=(0, 0, 0.0)), hips=dict(loc=(0, 0, -0.75)), core=dict(scale=0.1), eyes=dict(scale=0.05))
    with rig.clip("special", 45, hit=24) as c:                     # Boden einfrieren: kniet, beide Fäuste auf den Boden, die Krone gleißt
        c.key(0, **rest)
        c.key(12, arm_l=R(-150, 0, -10), arm_r=R(-150, 0, 10), torso=R(-12, 0, 0), core=dict(scale=1.5), eyes=dict(scale=1.5))
        c.key(24, hips=dict(loc=(0, 0, -0.5)), leg_l=R(-40, 0, 0), leg_r=R(20, 0, 0), torso=R(30, 0, 0), arm_l=R(-40, 0, 0), arm_r=R(-40, 0, 0), core=dict(scale=2.0), _i="LINEAR")
        c.key(32, core=dict(scale=1.6))
        c.key(45, **rest)
    with rig.clip("summon", 39, hit=22) as c:                      # brüllt und reißt die Arme hoch: Lawinenroller kommen
        c.key(0, **rest)
        c.key(14, torso=R(-18, 0, 0), head=R(-25, 0, 0), arm_l=R(-170, 0, -30), arm_r=R(-170, 0, 30), core=dict(scale=1.4))
        c.key(22, torso=R(-20, 0, 0), head=R(-30, 0, 6), eyes=dict(scale=1.6))
        c.key(28, head=R(-30, 0, -6))
        c.key(39, **rest)
    rig.finish(icon_yaw=-26, icon_pitch=10)


TABLE = {"eis_frostwichtel": eis_frostwichtel, "eis_eiswolf": eis_eiswolf, "eis_yeti": eis_yeti, "eis_kristallschuetze": eis_kristallschuetze,
         "eis_eisgeist": eis_eisgeist, "eis_lawinenroller": eis_lawinenroller, "boss_eis": boss_eis}

if __name__ == "__main__":
    run(TABLE, [a for a in sys.argv if not a.startswith("--")])
