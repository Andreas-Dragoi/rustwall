"""Dämonen (Schleimkrater): die sechs Arten und der Boss. Wird von enemies_daemonen.py eingebunden
(Aufruf dort:  python3 blender/enemies_daemonen.py [art ...] [--notafel])."""
import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from animkit import *

# Farben der Familie: Höllenrot, Glut, Ruß, Horn
DRED, DRED_D, DRED_L = "D8343A", "A8222A", "F2605A"
GLUT, GLUT_L = "FF7A1E", "FFD24A"
SOOT, SOOT_D = "3A2A32", "241A22"
HORN, HORN_D = "F2E2C0", "C8B490"
PURP, PURP_D = "6A3A8A", "4A2464"
GOLD = "F2C230"
INK = "16101A"
WHITE = "FFFFFF"


def R(x=0, y=0, z=0):
    return dict(rot=(x, y, z))


def spawn_clip(rig, depth=1.0, n=24, **extra):
    """Besonderer Clip „spawn“: steigt wackelnd aus dem Boden (oder aus dem Portal)."""
    with rig.clip("spawn", n) as c:
        c.key(0, root=dict(loc=(0, 0, -depth), rot=(0, 0, -40), scale=(0.6, 0.6, 0.6)))
        c.key(int(n * 0.55), root=dict(loc=(0, 0, 0.15 * depth), rot=(0, 0, 15), scale=(0.95, 0.95, 1.12)))
        c.key(int(n * 0.8), root=dict(loc=(0, 0, 0), rot=(0, 0, -5), scale=(1.08, 1.08, 0.92)))
        c.key(n, root=dict(loc=(0, 0, 0), rot=(0, 0, 0), scale=(1, 1, 1)))
        if extra:
            c.key(0, **extra)


# ================================================================= Höllenwichtel (Masse): roter Wicht mit Hörnchen, Dreizack, Grinsen
def daemonen_hoellenwichtel():
    rig = Rig("daemonen_hoellenwichtel", role="mass")
    rig.node("hips", pivot=(0, 0, 0.42))
    p = Part()
    lathe(p, [(0.16, 0.38, DRED_D), (0.24, 0.48, DRED), (0.26, 0.62, DRED), (0.2, 0.78, DRED), (0.12, 0.84, DRED)], sides=8)
    p.ball(0.15, (0, -0.12, 0.56), "F28A7A", scale=(1.1, 0.6, 1.0), subdiv=1)                      # Bäuchlein
    rig.add("body", p, parent="hips", pivot=(0, 0, 0.42))
    p = Part()                                                                                       # großer Kopf, breites Grinsen, Hörnchen, Spitzohren
    p.ball(0.27, (0, -0.02, 1.02), DRED, scale=(1.05, 0.95, 0.92), subdiv=2)
    p.ball(0.14, (0, -0.2, 0.92), WHITE, scale=(1.4, 0.5, 0.5), subdiv=1)                          # Zähne
    p.box((0.32, 0.04, 0.03), (0, -0.25, 0.93), INK, bevel=0.0)
    for s in (-1, 1):
        p.ball(0.075, (0.1 * s, -0.22, 1.1), GLUT_L, scale=(1, 0.5, 1.1), subdiv=1)
        lathe(p, [(0.06, 0.0, HORN), (0.04, 0.12, HORN), (0.0, 0.24, HORN_D)], sides=5, loc=(0.15 * s, 0.0, 1.22), r=rot(0, 25 * s, 0) @ rot(-15, 0, 0))
        p.cone(0.06, 0.2, (0.3 * s, 0.0, 1.05), DRED_D, r=rot(0, 75 * s, 0), sides=4)
        p.box((0.12, 0.03, 0.03), (0.1 * s, -0.24, 1.2), INK, r=rot(0, -25 * s, 0), bevel=0.0)    # fiese Brauen
    rig.add("head", p, parent="body", pivot=(0, 0, 0.82))
    p = Part()
    for s in (-1, 1):
        p.ball(0.035, (0.1 * s, -0.26, 1.1), INK, scale=(1, 0.5, 1), subdiv=1)
    rig.add("pupil", p, parent="head", pivot=(0, -0.26, 1.1), look=True)
    p = Part()                                                                                       # Arm mit Dreizack
    capsule(p, (-0.24, 0, 0.72), (-0.34, -0.12, 0.55), 0.045, 0.04, DRED, sides=5)
    p.ball(0.055, (-0.35, -0.15, 0.52), DRED_D, subdiv=1)
    capsule(p, (-0.35, -0.16, 0.1), (-0.35, -0.16, 1.15), 0.02, 0.02, SOOT, sides=4)
    p.box((0.22, 0.03, 0.03), (-0.35, -0.16, 1.15), GOLD, bevel=0.0)
    for k in range(3):
        p.cone(0.025, 0.14, (-0.45 + 0.1 * k, -0.16, 1.22), GOLD, sides=4)
    rig.add("arm_r", p, parent="body", pivot=(-0.24, 0, 0.72))
    p = Part()
    capsule(p, (0.24, 0, 0.72), (0.34, -0.06, 0.52), 0.045, 0.04, DRED, sides=5)
    p.ball(0.055, (0.35, -0.08, 0.5), DRED_D, subdiv=1)
    rig.add("arm_l", p, parent="body", pivot=(0.24, 0, 0.72))
    p = Part()                                                                                       # Teufelsschwanz
    capsule(p, (0, 0.18, 0.5), (0, 0.45, 0.35), 0.03, 0.025, DRED_D, sides=4)
    capsule(p, (0, 0.45, 0.35), (0, 0.55, 0.6), 0.025, 0.02, DRED_D, sides=4)
    p.cone(0.07, 0.12, (0, 0.56, 0.66), DRED_D, sides=3)
    rig.add("tail", p, parent="body", pivot=(0, 0.18, 0.5))
    for s, nm in ((1, "leg_l"), (-1, "leg_r")):
        p = Part()
        capsule(p, (0.1 * s, 0, 0.4), (0.12 * s, 0, 0.08), 0.05, 0.04, DRED_D, sides=5)
        p.ball(0.06, (0.12 * s, -0.04, 0.04), SOOT, scale=(0.8, 1.2, 0.7), subdiv=1)                 # Hufe
        rig.add(nm, p, parent="hips", pivot=(0.1 * s, 0, 0.42))
    rest = dict(root=dict(loc=(0, 0, 0), rot=(0, 0, 0)), hips=dict(loc=(0, 0, 0), rot=(0, 0, 0)), body=R(), head=R(), arm_l=R(), arm_r=R(), tail=R(), leg_l=R(), leg_r=R())
    with rig.clip("idle", 30, loop=True) as c:                     # kichert: Schultern zucken, Schwanz wedelt
        c.key(0, **rest)
        c.key(4, body=R(0, 0, 0), head=R(-10, 0, 6), hips=dict(loc=(0, 0, 0.04)))
        c.key(8, head=R(0, 0, -4), hips=dict(loc=(0, 0, 0)))
        c.key(12, head=R(-10, 0, 6), hips=dict(loc=(0, 0, 0.04)), tail=R(0, 0, 30))
        c.key(18, hips=dict(loc=(0, 0, 0)), head=R(0, 0, 0), tail=R(0, 0, -30), arm_l=R(-30, 0, -20))
    with rig.clip("walk", 12, loop=True, stride=1.25) as c:        # flitzt hüpfend, der Dreizack wippt
        c.wave("leg_l", rot=(50, 0, 0))
        c.wave("leg_r", rot=(50, 0, 0), phase=0.5)
        c.wave("arm_l", rot=(-35, 0, 0), phase=0.5)
        c.wave("arm_r", rot=(-15, 0, 0))
        c.wave("hips", loc=(0, 0, 0.07), n=2, phase=0.25)
        c.wave("body", rot=(0, 8, 0), base_rot=(12, 0, 0), phase=0.25)
        c.wave("tail", rot=(0, 0, 30), phase=0.5)
    with rig.clip("attack", 18, hit=9) as c:                       # sticht mit dem Dreizack und lacht
        c.key(0, **rest)
        c.key(5, arm_r=R(-30, 0, -20), body=R(-10, 0, -15))
        c.key(9, arm_r=R(-80, 0, 10), body=R(15, 0, 10), hips=dict(loc=(0, -0.2, 0)), _i="LINEAR")
        c.key(12, head=R(-20, 0, 0))
        c.key(14, head=R(-5, 0, 0))
        c.key(16, head=R(-20, 0, 0))
        c.key(18, **rest)
    with rig.clip("hit", 9) as c:
        c.key(0, **rest)
        c.key(3, body=R(-16, 0, 10), head=R(-20, 0, -10), hips=dict(loc=(0, 0.1, 0.06)), tail=R(-40, 0, 0))
        c.key(9, **rest)
    with rig.clip("death", 27) as c:                               # dreht sich und verpufft zu einem Rußhäufchen
        c.key(0, **rest)
        c.key(8, root=dict(rot=(0, 0, 200), loc=(0, 0, 0.3)), arm_l=R(0, 0, 70), arm_r=R(0, 0, -70))
        c.key(14, root=dict(rot=(0, 0, 360), loc=(0, 0, 0.0), scale=(1.2, 1.2, 0.8)), _i="LINEAR")
        c.key(27, root=dict(rot=(0, 0, 380), loc=(0, 0, 0.0), scale=(1.4, 1.4, 0.05)))
    spawn_clip(rig, 1.2)
    rig.finish()


# ================================================================= Dämonenhund (Flitzer): schwarz, Glutadern, zwei Köpfe
def daemonen_hund():
    rig = Rig("daemonen_hund", role="fast")
    p = Part()
    lathe(p, [(0.08, -0.05, SOOT), (0.24, 0.05, SOOT), (0.28, 0.3, SOOT_D), (0.26, 0.6, SOOT), (0.16, 0.8, SOOT), (0.05, 0.86, SOOT)], sides=8, loc=(0, -0.45, 0.62), r=rot(-92, 0, 0), sy=0.85)
    for k in range(4):                                                                               # Stachelkamm
        p.cone(0.05, 0.18, (0, -0.3 + 0.2 * k, 0.88), SOOT_D, r=rot(-25, 0, 0), sides=4)
    rig.add("body", p, pivot=(0, 0, 0.62))
    p = Part()                                                                                       # Glutadern
    for (a, b) in (((0.2, -0.35, 0.7), (0.24, 0.0, 0.62)), ((0.24, 0.0, 0.62), (0.2, 0.3, 0.72)), ((-0.2, -0.3, 0.72), (-0.24, 0.1, 0.6)), ((-0.24, 0.1, 0.6), (-0.18, 0.35, 0.7))):
        capsule(p, a, b, 0.025, 0.02, GLUT, sides=4)
    rig.add("veins", p, parent="body", pivot=(0, 0, 0.65), glow=True)
    heads = []
    for s, nm in ((1, "head_l"), (-1, "head_r")):                                                   # zwei Köpfe auf kurzen Hälsen
        p = Part()
        capsule(p, (0.1 * s, -0.4, 0.72), (0.18 * s, -0.55, 0.88), 0.1, 0.09, SOOT, sides=6)
        p.ball(0.17, (0.2 * s, -0.62, 0.92), SOOT, scale=(1, 1.05, 0.9), subdiv=1)
        lathe(p, [(0.1, 0.0, SOOT), (0.07, 0.16, SOOT_D), (0.03, 0.24, DRED_D)], sides=6, loc=(0.2 * s, -0.7, 0.88), r=rot(98, 0, 0), sy=0.75)
        p.cone(0.06, 0.16, (0.27 * s, -0.56, 1.06), SOOT_D, r=rot(-10, 30 * s, 0), sides=4)
        p.ball(0.035, (0.26 * s, -0.76, 0.97), GLUT_L, subdiv=1)
        p.ball(0.035, (0.14 * s, -0.76, 0.97), GLUT_L, subdiv=1)
        p.cone(0.022, 0.06, (0.24 * s, -0.86, 0.84), WHITE, r=rot(180, 0, 0), sides=3)
        p.cone(0.022, 0.06, (0.16 * s, -0.86, 0.84), WHITE, r=rot(180, 0, 0), sides=3)
        rig.add(nm, p, parent="body", pivot=(0.1 * s, -0.4, 0.72))
        heads.append(nm)
        p = Part()
        lathe(p, [(0.07, 0.0, SOOT_D), (0.04, 0.16, SOOT_D), (0.015, 0.22, DRED)], sides=5, loc=(0.2 * s, -0.68, 0.8), r=rot(100, 0, 0), sy=0.5)
        rig.add(nm.replace("head", "jaw"), p, parent=nm, pivot=(0.2 * s, -0.64, 0.82))
    p = Part()
    capsule(p, (0, 0.4, 0.72), (0, 0.75, 0.8), 0.05, 0.03, SOOT, sides=5)
    p.cone(0.08, 0.16, (0, 0.82, 0.82), GLUT, r=rot(-80, 0, 0), sides=4)
    rig.add("tail", p, parent="body", pivot=(0, 0.4, 0.72))
    for nm, x, y in (("leg_fl", 0.14, -0.32), ("leg_fr", -0.14, -0.32), ("leg_bl", 0.14, 0.3), ("leg_br", -0.14, 0.3)):
        p = Part()
        capsule(p, (x, y, 0.6), (x * 1.05, y + 0.03, 0.06), 0.065, 0.04, SOOT, sides=5)
        p.ball(0.06, (x * 1.05, y - 0.03, 0.04), SOOT_D, scale=(1, 1.4, 0.6), subdiv=1)
        rig.add(nm, p, parent="body", pivot=(x, y, 0.6))
    rest = dict(root=dict(loc=(0, 0, 0), rot=(0, 0, 0)), body=dict(loc=(0, 0, 0), rot=(0, 0, 0)), head_l=R(), head_r=R(), jaw_l=R(), jaw_r=R(), tail=R(), veins=dict(scale=1.0), leg_fl=R(), leg_fr=R(), leg_bl=R(), leg_br=R())
    with rig.clip("idle", 30, loop=True) as c:                     # die zwei Köpfe zanken sich
        c.key(0, **rest)
        c.key(6, head_l=R(0, 0, -20), head_r=R(0, 0, 10), jaw_l=R(-25, 0, 0))
        c.key(10, jaw_l=R(0, 0, 0), head_r=R(0, 0, 25), jaw_r=R(-25, 0, 0))
        c.key(15, jaw_r=R(0, 0, 0), head_l=R(0, 0, 0), head_r=R(0, 0, 0), veins=dict(scale=1.06))
        c.key(22, head_l=R(-14, 0, 10), head_r=R(-14, 0, -10), tail=R(0, 0, 25), veins=dict(scale=1.0))
    with rig.clip("walk", 12, loop=True, stride=2.3) as c:
        c.wave("leg_fl", rot=(52, 0, 0))
        c.wave("leg_fr", rot=(52, 0, 0), phase=0.1)
        c.wave("leg_bl", rot=(52, 0, 0), phase=0.5)
        c.wave("leg_br", rot=(52, 0, 0), phase=0.6)
        c.wave("body", rot=(8, 0, 0), loc=(0, 0, 0.06), phase=0.25)
        c.wave("head_l", rot=(-10, 0, 0), phase=0.5)
        c.wave("head_r", rot=(-10, 0, 0), phase=0.6)
        c.wave("tail", rot=(14, 0, 0), phase=0.75)
    with rig.clip("attack", 12, hit=6) as c:                       # beide Köpfe beißen abwechselnd (sehr schnell)
        c.key(0, **rest)
        c.key(3, head_l=R(-20, 0, 0), jaw_l=R(-40, 0, 0), body=dict(loc=(0, 0.08, 0)))
        c.key(6, head_l=R(14, 0, 0), jaw_l=R(0, 0, 0), head_r=R(-20, 0, 0), jaw_r=R(-40, 0, 0), body=dict(loc=(0, -0.2, 0)), _i="LINEAR")
        c.key(9, head_r=R(14, 0, 0), jaw_r=R(0, 0, 0))
        c.key(12, **rest)
    with rig.clip("charge", 9, loop=True, stride=2.0) as c:         # Sturm: geduckt, Köpfe vor, Adern glühen
        c.wave("leg_fl", rot=(60, 0, 0))
        c.wave("leg_fr", rot=(60, 0, 0), phase=0.1)
        c.wave("leg_bl", rot=(60, 0, 0), phase=0.5)
        c.wave("leg_br", rot=(60, 0, 0), phase=0.6)
        c.wave("body", rot=(6, 0, 0), base_rot=(8, 0, 0), loc=(0, 0, 0.05), base_loc=(0, 0, -0.1), phase=0.25)
        c.key(0, head_l=R(20, 0, 10), head_r=R(20, 0, -10), jaw_l=R(-30, 0, 0), jaw_r=R(-30, 0, 0), veins=dict(scale=1.25), tail=R(-50, 0, 0))
    with rig.clip("hit", 9) as c:
        c.key(0, **rest)
        c.key(3, body=dict(rot=(-12, 0, 10), loc=(0, 0.15, 0.05)), head_l=R(-25, 0, -10), head_r=R(-25, 0, 10), veins=dict(scale=1.3))
        c.key(9, **rest)
    with rig.clip("death", 30) as c:                               # jault, kippt um, die Glut erlischt
        c.key(0, **rest)
        c.key(8, root=dict(rot=(0, 30, 0), loc=(0, 0, 0.15)), head_l=R(-40, 0, 0), head_r=R(-40, 0, 0), jaw_l=R(-40, 0, 0), jaw_r=R(-40, 0, 0))
        c.key(16, root=dict(rot=(0, 88, 0), loc=(0, 0, 0.22)))
        c.key(30, root=dict(rot=(0, 90, 0), loc=(0, 0, 0.18)), head_l=R(10, 0, 0), head_r=R(10, 0, 0), veins=dict(scale=0.05))
    rig.finish()


# ================================================================= Gehörnter Wächter (Brocken): drei Meter, Stierhörner, Zweihandhammer
def daemonen_waechter():
    rig = Rig("daemonen_waechter", role="tank")
    ARM = "4A3A4A"
    rig.node("hips", pivot=(0, 0, 1.1))
    p = Part()                                                                                       # massiger Oberkörper mit Rüstung
    lathe(p, [(0.5, 1.0, SOOT), (0.62, 1.2, DRED_D), (0.75, 1.7, DRED), (0.9, 2.15, DRED), (0.7, 2.45, DRED_D), (0.35, 2.55, DRED)], sides=12, sy=0.8)
    p.box((1.0, 0.25, 0.6), (0, -0.55, 1.95), ARM, bevel=0.08, segs=1)                               # Brustpanzer
    p.ball(0.12, (0, -0.68, 1.95), GLUT, subdiv=1)
    p.box((1.1, 0.7, 0.25), (0, 0, 1.15), SOOT_D, bevel=0.06, segs=1)                                # Gürtel
    p.box((0.3, 0.06, 0.2), (0, -0.37, 1.15), GOLD, bevel=0.0)
    for s in (-1, 1):
        p.ball(0.4, (0.9 * s, 0, 2.35), ARM, scale=(1, 1, 0.6), subdiv=2)                            # Schulterplatten
        p.cone(0.1, 0.35, (0.95 * s, 0, 2.6), HORN, sides=5)
    rig.add("body", p, parent="hips", pivot=(0, 0, 1.1))
    p = Part()                                                                                       # Stierkopf mit großen Hörnern und Nasenring
    p.ball(0.36, (0, -0.25, 2.75), DRED, scale=(1, 1.1, 0.95), subdiv=2)
    p.ball(0.22, (0, -0.55, 2.62), DRED_L, scale=(1.2, 0.8, 0.8), subdiv=1)
    p.torus(0.08, 0.02, (0, -0.72, 2.55), GOLD, r=rot(90, 0, 0), seg=8, tseg=3)
    for s in (-1, 1):
        capsule(p, (0.3 * s, -0.2, 2.9), (0.75 * s, -0.25, 3.0), 0.1, 0.08, HORN, sides=6)
        capsule(p, (0.75 * s, -0.25, 3.0), (0.85 * s, -0.4, 3.35), 0.08, 0.03, HORN_D, sides=6)
        p.box((0.2, 0.06, 0.06), (0.15 * s, -0.55, 2.9), INK, r=rot(0, -22 * s, 0), bevel=0.0)
    rig.add("head", p, parent="body", pivot=(0, -0.15, 2.5))
    p = Part()
    for s in (-1, 1):
        p.ball(0.06, (0.14 * s, -0.56, 2.82), GLUT_L, scale=(1.2, 0.5, 0.7), subdiv=1)
    rig.add("eyes", p, parent="head", pivot=(0, -0.56, 2.82), glow=True)
    for s, nm in ((1, "arm_l"), (-1, "arm_r")):
        p = Part()
        capsule(p, (0.85 * s, 0, 2.2), (1.05 * s, -0.25, 1.6), 0.2, 0.18, DRED, sides=7)
        rig.add(nm, p, parent="body", pivot=(0.85 * s, 0, 2.2))
        p = Part()
        capsule(p, (1.05 * s, -0.25, 1.6), (0.6 * s, -0.7, 1.45), 0.17, 0.15, DRED_D, sides=7)
        p.ball(0.18, (0.5 * s, -0.75, 1.45), DRED, subdiv=1)
        p.cyl(0.2, 0.18, (0.85 * s, -0.45, 1.53), ARM, r=face_to((-0.45 * s, -0.45, -0.15)), sides=8)   # Armschiene
        rig.add(nm.replace("arm", "fore"), p, parent=nm, pivot=(1.05 * s, -0.25, 1.6))
    p = Part()                                                                                       # Zweihandhammer
    capsule(p, (0, -0.8, 0.6), (0, -0.8, 2.6), 0.06, 0.06, "6A4A2E", sides=6)
    p.box((0.9, 0.5, 0.5), (0, -0.8, 2.75), "5A5A6A", bevel=0.08, segs=1)
    p.box((0.95, 0.52, 0.12), (0, -0.8, 2.75), GOLD, bevel=0.0)
    for s in (-1, 1):
        p.cone(0.12, 0.2, (0.55 * s, -0.8, 2.75), "8A8A9A", r=rot(0, 90 * s, 0), sides=5)
    rig.add("hammer", p, parent="fore_r", pivot=(0, -0.8, 1.45))
    p = Part()
    p.box((0.4, 0.06, 0.2), (0, -1.06, 2.75), GLUT, bevel=0.0)                                       # glühende Rune am Hammer
    rig.add("rune", p, parent="hammer", pivot=(0, -1.06, 2.75), glow=True)
    p = Part()
    capsule(p, (0, 0.4, 1.2), (0, 0.9, 0.6), 0.06, 0.04, DRED_D, sides=5)
    p.cone(0.12, 0.2, (0, 0.95, 0.5), DRED_D, r=rot(160, 0, 0), sides=3)
    rig.add("tail", p, parent="body", pivot=(0, 0.4, 1.2))
    for s, nm in ((1, "leg_l"), (-1, "leg_r")):
        p = Part()
        capsule(p, (0.35 * s, 0, 1.05), (0.4 * s, 0.1, 0.55), 0.22, 0.17, SOOT, sides=7)
        capsule(p, (0.4 * s, 0.1, 0.55), (0.4 * s, -0.05, 0.15), 0.15, 0.13, DRED_D, sides=6)
        p.box((0.32, 0.45, 0.2), (0.4 * s, -0.12, 0.1), INK, bevel=0.06, segs=1)                     # Hufe
        rig.add(nm, p, parent="hips", pivot=(0.35 * s, 0, 1.1))
    rest = dict(root=dict(loc=(0, 0, 0), rot=(0, 0, 0)), hips=dict(loc=(0, 0, 0), rot=(0, 0, 0)), body=R(), head=R(), arm_l=R(), arm_r=R(), fore_l=R(), fore_r=R(), hammer=R(), tail=R(), leg_l=R(), leg_r=R(), eyes=dict(scale=1.0), rune=dict(scale=1.0))
    with rig.clip("idle", 48, loop=True) as c:                     # schnaubt, der Hammer ruht, die Rune pulsiert
        c.key(0, **rest)
        c.key(12, body=R(-4, 0, 0), head=R(-10, 0, 0), rune=dict(scale=1.3))
        c.key(18, head=R(4, 0, 0))
        c.key(30, body=R(0, 3, 0), head=R(0, 0, 14), tail=R(0, 0, 25), rune=dict(scale=1.0))
        c.key(40, head=R(0, 0, -10), tail=R(0, 0, -25))
    with rig.clip("walk", 45, loop=True, stride=1.9) as c:
        c.wave("leg_l", rot=(26, 0, 0))
        c.wave("leg_r", rot=(26, 0, 0), phase=0.5)
        c.wave("hips", rot=(0, 6, 0), phase=0.25)
        c.wave("hips", loc=(0, 0, 0.08), n=2, phase=0.25)
        c.wave("body", rot=(0, 0, 4), phase=0.5)
        c.wave("arm_l", rot=(-10, 0, 0), phase=0.5)
        c.wave("tail", rot=(0, 0, 20))
    with rig.clip("attack", 45, hit=26) as c:                      # holt weit über den Kopf aus – Hammerschlag mit Druckwelle
        c.key(0, **rest)
        c.key(16, body=R(-18, 0, 0), arm_l=R(-170, 0, -10), arm_r=R(-170, 0, 10), fore_l=R(-20, 0, 0), fore_r=R(-20, 0, 0), head=R(-20, 0, 0), rune=dict(scale=1.6), hips=dict(loc=(0, 0.1, 0.05)))
        c.key(26, body=R(30, 0, 0), arm_l=R(-60, 0, 0), arm_r=R(-60, 0, 0), fore_l=R(0, 0, 0), fore_r=R(0, 0, 0), head=R(10, 0, 0), hips=dict(loc=(0, -0.25, -0.2)), _i="LINEAR")
        c.key(34, body=R(26, 0, 0), rune=dict(scale=1.0))
        c.key(45, **rest)
    with rig.clip("hit", 9) as c:
        c.key(0, **rest)
        c.key(3, body=R(-8, 0, 6), head=R(-18, 0, 8), eyes=dict(scale=1.4))
        c.key(9, **rest)
    with rig.clip("death", 48) as c:                               # lässt den Hammer fallen, sinkt auf die Knie, kippt vornüber
        c.key(0, **rest)
        c.key(12, head=R(-30, 0, 0), arm_r=R(-30, 0, 30), fore_r=R(30, 0, 0), eyes=dict(scale=1.5))
        c.key(24, hips=dict(loc=(0, 0, -0.55)), leg_l=R(-80, 0, 0), leg_r=R(-80, 0, 0), body=R(16, 0, 0), _i="LINEAR")
        c.key(38, root=dict(rot=(78, 0, 0), loc=(0, 0, 0.0)), hips=dict(loc=(0, 0, -0.55)), arm_l=R(-150, 0, 20), arm_r=R(-150, 0, -20), _i="LINEAR")
        c.key(48, root=dict(rot=(80, 0, 0), loc=(0, 0, 0.0)), hips=dict(loc=(0, 0, -0.55)), eyes=dict(scale=0.05), rune=dict(scale=0.05))
    spawn_clip(rig, 3.0, 30)
    rig.finish(icon_yaw=-28, icon_pitch=12)


# ================================================================= Feuerspeier (Fernkampf): dicker Dämon mit Glutbauch, bläht sich auf
def daemonen_feuerspeier():
    rig = Rig("daemonen_feuerspeier", role="ranged")
    p = Part()                                                                                       # kugelrunder Leib
    p.ball(0.6, (0, 0, 0.85), DRED, scale=(1.05, 1.0, 0.95), subdiv=2)
    for k in range(4):
        a = k * math.tau / 4 + 0.4
        p.cone(0.08, 0.22, (0.4 * math.cos(a), 0.3 + 0.2 * math.sin(a), 1.35), DRED_D, r=rot(-30, 0, math.degrees(a)), sides=4)   # Rückenstacheln
    rig.add("body", p, pivot=(0, 0, 0.6))
    p = Part()                                                                                       # Glutbauch
    p.ball(0.4, (0, -0.32, 0.8), GLUT, scale=(1.0, 0.6, 1.0), subdiv=2)
    p.ball(0.22, (0, -0.48, 0.82), GLUT_L, scale=(1, 0.5, 1), subdiv=1)
    rig.add("belly", p, parent="body", pivot=(0, -0.3, 0.8), glow=True)
    p = Part()                                                                                       # kleiner Kopf obenauf, dicke Lippen, Hörnchen
    p.ball(0.25, (0, -0.2, 1.48), DRED_L, subdiv=2)
    p.ball(0.12, (0, -0.42, 1.38), DRED_D, scale=(1.4, 0.7, 0.8), subdiv=1)
    p.ball(0.07, (0, -0.48, 1.38), INK, scale=(1.3, 0.5, 0.7), subdiv=1)
    for s in (-1, 1):
        p.ball(0.06, (0.1 * s, -0.4, 1.55), GLUT_L, scale=(1, 0.5, 1), subdiv=1)
        lathe(p, [(0.05, 0.0, HORN), (0.0, 0.18, HORN_D)], sides=5, loc=(0.16 * s, -0.15, 1.66), r=rot(0, 30 * s, 0))
    rig.add("head", p, parent="body", pivot=(0, -0.2, 1.35))
    p = Part()
    for s in (-1, 1):
        p.ball(0.025, (0.1 * s, -0.43, 1.55), INK, subdiv=1)
    rig.add("pupil", p, parent="head", pivot=(0, -0.43, 1.55), look=True)
    for s, nm in ((1, "arm_l"), (-1, "arm_r")):
        p = Part()
        capsule(p, (0.55 * s, -0.05, 1.0), (0.75 * s, -0.25, 0.75), 0.08, 0.07, DRED, sides=5)
        p.ball(0.09, (0.77 * s, -0.28, 0.72), DRED_D, subdiv=1)
        rig.add(nm, p, parent="body", pivot=(0.55 * s, -0.05, 1.0))
    for s, nm in ((1, "leg_l"), (-1, "leg_r")):
        p = Part()
        capsule(p, (0.25 * s, 0, 0.35), (0.27 * s, 0, 0.1), 0.1, 0.09, DRED_D, sides=5)
        p.ball(0.12, (0.27 * s, -0.08, 0.06), SOOT, scale=(1, 1.4, 0.6), subdiv=1)
        rig.add(nm, p, pivot=(0.25 * s, 0, 0.4))
    rest = dict(root=dict(loc=(0, 0, 0), rot=(0, 0, 0)), body=dict(rot=(0, 0, 0), scale=1.0, loc=(0, 0, 0)), belly=dict(scale=1.0), head=R(), arm_l=R(), arm_r=R(), leg_l=R(), leg_r=R())
    with rig.clip("idle", 42, loop=True) as c:                     # rülpst Funken, tätschelt den Bauch
        c.key(0, **rest)
        c.key(12, arm_l=R(-30, 0, -30), belly=dict(scale=1.1), body=dict(scale=(1.03, 1.03, 0.97)))
        c.key(18, arm_l=R(-20, 0, -20), belly=dict(scale=1.0))
        c.key(26, head=R(-20, 0, 0), body=dict(scale=(0.97, 0.97, 1.04)))
        c.key(30, head=R(4, 0, 0), body=dict(scale=1.0))
    with rig.clip("walk", 27, loop=True, stride=1.3) as c:         # watschelt, der Bauch wabbelt
        c.wave("leg_l", rot=(30, 0, 0))
        c.wave("leg_r", rot=(30, 0, 0), phase=0.5)
        c.wave("body", rot=(0, 9, 0), phase=0.25)
        c.wave("body", loc=(0, 0, 0.05), n=2, phase=0.25)
        c.wave("belly", scale=(0.05, 0.0, -0.05), n=2)
        c.wave("arm_l", rot=(0, 0, 15), phase=0.5)
        c.wave("arm_r", rot=(0, 0, -15))
    with rig.clip("attack", 42, hit=30) as c:                      # bläht sich auf, der Bauch glüht hell – spuckt den Feuerball
        c.key(0, **rest)
        c.key(14, body=dict(scale=(1.15, 1.15, 1.1), rot=(-12, 0, 0)), belly=dict(scale=1.25), head=R(-25, 0, 0), arm_l=R(0, 0, -40), arm_r=R(0, 0, 40))
        c.key(26, body=dict(scale=(1.3, 1.3, 1.22), rot=(-16, 0, 0)), belly=dict(scale=1.5), head=R(-30, 0, 0))
        c.key(30, body=dict(scale=(0.9, 0.9, 0.95), rot=(16, 0, 0)), belly=dict(scale=0.9), head=R(20, 0, 0), arm_l=R(-40, 0, 0), arm_r=R(-40, 0, 0), _i="LINEAR")
        c.key(42, **rest)
    with rig.clip("hit", 9) as c:
        c.key(0, **rest)
        c.key(3, body=dict(scale=(1.15, 1.15, 0.85), rot=(-10, 0, 8)), belly=dict(scale=1.3))
        c.key(9, **rest)
    with rig.clip("death", 30) as c:                               # bläht sich bis zum Platzen und fällt leer in sich zusammen
        c.key(0, **rest)
        c.key(10, body=dict(scale=(1.35, 1.35, 1.3)), belly=dict(scale=1.6), arm_l=R(0, 0, -70), arm_r=R(0, 0, 70))
        c.key(14, body=dict(scale=(1.6, 1.6, 0.45), loc=(0, 0, -0.35)), belly=dict(scale=0.4), _i="LINEAR")
        c.key(30, body=dict(scale=(1.7, 1.7, 0.35), loc=(0, 0, -0.4)), belly=dict(scale=0.05), head=R(40, 0, 0), leg_l=R(0, -30, 0), leg_r=R(0, 30, 0))
    spawn_clip(rig, 1.6)
    rig.finish()


# ================================================================= Schattenschwinge (Flieger): Fledermausdämon mit zerfetzten Flügeln
def daemonen_schattenschwinge():
    rig = Rig("daemonen_schattenschwinge", role="air")
    WING = "4A2A4A"
    p = Part()
    p.ball(0.3, (0, 0.05, 0.75), SOOT, scale=(0.85, 1.1, 1.0), subdiv=2)
    p.ball(0.2, (0, -0.12, 0.65), PURP_D, scale=(1.0, 0.6, 1.1), subdiv=1)
    rig.add("body", p, pivot=(0, 0, 0.75))
    p = Part()                                                                                       # Fledermauskopf: Riesenohren, Glutaugen, Fangzähne
    p.ball(0.2, (0, -0.2, 1.05), SOOT, subdiv=2)
    for s in (-1, 1):
        p.cone(0.11, 0.38, (0.15 * s, -0.15, 1.3), SOOT, r=rot(0, 25 * s, 0), sides=4)
        p.cone(0.06, 0.24, (0.15 * s, -0.19, 1.28), PURP, r=rot(0, 25 * s, 0), sides=4)
        p.cone(0.025, 0.08, (0.05 * s, -0.37, 0.95), WHITE, r=rot(180, 0, 0), sides=3)
    p.ball(0.05, (0, -0.39, 1.02), PURP_D, subdiv=1)
    rig.add("head", p, parent="body", pivot=(0, -0.1, 0.95))
    p = Part()
    for s in (-1, 1):
        p.ball(0.045, (0.08 * s, -0.37, 1.1), DRED_L, scale=(1.2, 0.5, 0.8), subdiv=1)
    rig.add("eyes", p, parent="head", pivot=(0, -0.37, 1.1), glow=True)
    for s, nm in ((1, "wing_l"), (-1, "wing_r")):                                                   # Flügel: Knochenfinger mit zerfetzter Haut
        p = Part()
        capsule(p, (0.2 * s, 0, 0.9), (0.75 * s, 0.05, 1.1), 0.04, 0.03, SOOT, sides=4)
        p.box((0.55, 0.45, 0.03), (0.5 * s, 0.2, 0.95), WING, r=rot(0, -10 * s, 0), bevel=0.0)
        rig.add(nm, p, parent="body", pivot=(0.2 * s, 0, 0.9))
        p = Part()
        for k in range(3):
            capsule(p, (0.75 * s, 0.05, 1.1), ((0.95 + 0.15 * k) * s, 0.15 + 0.2 * k, 0.9 - 0.12 * k), 0.025, 0.012, SOOT, sides=4)
        for k in range(2):
            p.box((0.3, 0.3, 0.02), ((0.95 + 0.12 * k) * s, 0.25 + 0.2 * k, 0.95 - 0.1 * k), WING, r=rot(0, -15 * s, 25 * s * k), bevel=0.0)
        rig.add(nm.replace("wing", "tip"), p, parent=nm, pivot=(0.75 * s, 0.05, 1.1))
    p = Part()
    for s in (-1, 1):
        capsule(p, (0.1 * s, 0.1, 0.5), (0.12 * s, 0.15, 0.25), 0.035, 0.03, SOOT, sides=4)
        p.cone(0.04, 0.1, (0.12 * s, 0.1, 0.2), HORN, r=rot(160, 0, 0), sides=3)
    capsule(p, (0, 0.3, 0.6), (0, 0.65, 0.5), 0.03, 0.015, SOOT, sides=4)
    p.cone(0.06, 0.1, (0, 0.7, 0.5), DRED, r=rot(-90, 0, 0), sides=3)
    rig.add("feet", p, parent="body", pivot=(0, 0.1, 0.5))
    rest = dict(root=dict(loc=(0, 0, 0), rot=(0, 0, 0)), body=dict(rot=(0, 0, 0), loc=(0, 0, 0)), head=R(), wing_l=R(), wing_r=R(), tip_l=R(), tip_r=R(), feet=R(), eyes=dict(scale=1.0))
    with rig.clip("idle", 18, loop=True) as c:                     # flattert auf der Stelle
        c.wave("wing_l", rot=(0, -50, 0))
        c.wave("wing_r", rot=(0, 50, 0))
        c.wave("tip_l", rot=(0, -30, 0), phase=0.15)
        c.wave("tip_r", rot=(0, 30, 0), phase=0.15)
        c.wave("body", loc=(0, 0, 0.1), phase=0.5)
        c.wave("head", rot=(0, 0, 12), n=1, steps=4)
    with rig.clip("walk", 15, loop=True, stride=2.4) as c:
        c.wave("wing_l", rot=(0, -55, 0))
        c.wave("wing_r", rot=(0, 55, 0))
        c.wave("tip_l", rot=(0, -30, 0), phase=0.15)
        c.wave("tip_r", rot=(0, 30, 0), phase=0.15)
        c.wave("body", rot=(4, 0, 0), base_rot=(24, 0, 0), loc=(0, 0, 0.08), phase=0.5)
        c.key(0, feet=R(40, 0, 0))
    with rig.clip("attack", 15, hit=8) as c:                       # krallt zu
        c.key(0, **rest)
        c.key(5, wing_l=R(0, -60, 0), wing_r=R(0, 60, 0), feet=R(-60, 0, 0), body=dict(rot=(-20, 0, 0)))
        c.key(8, wing_l=R(0, 40, 0), wing_r=R(0, -40, 0), feet=R(30, 0, 0), body=dict(rot=(20, 0, 0), loc=(0, -0.3, -0.2)), _i="LINEAR")
        c.key(15, **rest)
    with rig.clip("dive", 21, hit=14) as c:                        # Sturzflug: Flügel angelegt, Kopf voran
        c.key(0, **rest)
        c.key(5, wing_l=R(0, -70, 0), wing_r=R(0, 70, 0), body=dict(rot=(-15, 0, 0)), eyes=dict(scale=1.5))
        c.key(10, wing_l=R(-30, 60, 40), wing_r=R(-30, -60, -40), tip_l=R(0, 40, 0), tip_r=R(0, -40, 0), body=dict(rot=(60, 0, 0)), feet=R(-60, 0, 0))
        c.key(14, body=dict(rot=(70, 0, 0), loc=(0, -0.3, -0.3)), _i="LINEAR")
        c.key(21, **rest)
    with rig.clip("hit", 9) as c:
        c.key(0, **rest)
        c.key(3, body=dict(rot=(-20, 0, 20), loc=(0, 0.1, 0.1)), wing_l=R(0, -80, 0), wing_r=R(0, 20, 0), eyes=dict(scale=1.5))
        c.key(9, **rest)
    with rig.clip("death", 27) as c:                               # trudelt, landet mit ausgebreiteten Flügeln
        c.key(0, **rest)
        c.key(8, root=dict(rot=(0, 0, 180)), body=dict(rot=(20, 40, 0)), wing_l=R(0, -80, 0), wing_r=R(0, 30, 0))
        c.key(18, root=dict(rot=(-80, 0, 300), loc=(0, 0, 0.0)), body=dict(rot=(0, 0, 0)), wing_l=R(0, 10, 0), wing_r=R(0, -10, 0), _i="LINEAR")
        c.key(27, root=dict(rot=(-85, 0, 320), loc=(0, 0, 0.0)), eyes=dict(scale=0.05), tip_l=R(0, 20, 0), tip_r=R(0, -20, 0))
    rig.finish(icon_pitch=18)


# ================================================================= Beschwörer (Sonder): hagerer Dämon in Robe, schwebendes Buch, Runenkreis
def daemonen_beschwoerer():
    rig = Rig("daemonen_beschwoerer", role="special")
    ROBE, ROBE_D = PURP, PURP_D
    rig.node("hips", pivot=(0, 0, 0.9))
    p = Part()                                                                                       # lange Robe mit Goldsaum
    lathe(p, [(0.45, 0.06, GOLD), (0.46, 0.14, ROBE_D), (0.36, 0.6, ROBE), (0.26, 1.2, ROBE), (0.3, 1.5, ROBE_D), (0.2, 1.62, ROBE)], sides=10, sy=0.85)
    p.box((0.08, 0.04, 1.3), (0, -0.32, 0.75), GOLD, r=rot(-8, 0, 0), bevel=0.0)
    rig.add("body", p, parent="hips", pivot=(0, 0, 0.9))
    p = Part()                                                                                       # Kopf in der Kapuze: hager, lange Hörner, Ziegenbart
    lathe(p, [(0.24, 1.55, ROBE_D), (0.27, 1.75, ROBE), (0.2, 1.98, ROBE), (0.0, 2.05, ROBE_D)], sides=10, loc=(0, 0.04, 0))
    p.ball(0.17, (0, -0.1, 1.76), DRED_L, scale=(0.85, 0.9, 1.1), subdiv=2)
    p.cone(0.06, 0.2, (0, -0.2, 1.55), SOOT, r=rot(170, 0, 0), sides=4)
    for s in (-1, 1):
        capsule(p, (0.12 * s, -0.05, 1.92), (0.3 * s, 0.05, 2.25), 0.05, 0.02, HORN, sides=5)
        p.box((0.1, 0.03, 0.03), (0.07 * s, -0.25, 1.83), INK, r=rot(0, -25 * s, 0), bevel=0.0)
    rig.add("head", p, parent="body", pivot=(0, 0, 1.55))
    p = Part()
    for s in (-1, 1):
        p.ball(0.03, (0.07 * s, -0.25, 1.78), GLUT_L, scale=(1.3, 0.5, 0.8), subdiv=1)
    rig.add("eyes", p, parent="head", pivot=(0, -0.25, 1.78), glow=True)
    for s, nm in ((1, "arm_l"), (-1, "arm_r")):                                                     # weite Ärmel, Krallenhände
        p = Part()
        lathe(p, [(0.08, 0.0, ROBE), (0.14, 0.35, ROBE_D), (0.16, 0.42, GOLD)], sides=6, loc=(0.27 * s, 0, 1.45), r=face_to((0.3 * s, -0.4, -0.5)))
        p.ball(0.06, (0.45 * s, -0.25, 1.15), DRED_L, subdiv=1)
        for k in range(3):
            p.cone(0.015, 0.1, (0.45 * s + 0.03 * (k - 1), -0.3, 1.1), SOOT, r=rot(150, 0, 0), sides=3)
        rig.add(nm, p, parent="body", pivot=(0.27 * s, 0, 1.45))
    p = Part()                                                                                       # schwebendes Zauberbuch
    p.box((0.38, 0.28, 0.06), (0, -0.55, 1.3), DRED_D, r=rot(20, 0, 0), bevel=0.02, segs=1)
    p.box((0.34, 0.26, 0.05), (0, -0.55, 1.34), "F4E8C8", r=rot(20, 0, 0), bevel=0.0)
    rig.add("book", p, pivot=(0, -0.55, 1.3))
    p = Part()
    p.box((0.12, 0.12, 0.02), (0, -0.55, 1.38), GLUT, r=rot(20, 0, 45), bevel=0.0)
    rig.add("bookrune", p, parent="book", pivot=(0, -0.55, 1.38), glow=True)
    p = Part()                                                                                       # Runenkreis am Boden
    p.torus(0.75, 0.025, (0, 0, 0.03), DRED_L, seg=16, tseg=3)
    for k in range(6):
        a = k * math.tau / 6
        p.box((0.12, 0.12, 0.015), (0.75 * math.cos(a), 0.75 * math.sin(a), 0.03), GLUT, r=rot(0, 0, math.degrees(a) + 45), bevel=0.0)
    rig.add("circle", p, pivot=(0, 0, 0.03), glow=True)
    rest = dict(root=dict(loc=(0, 0, 0), rot=(0, 0, 0)), hips=dict(loc=(0, 0, 0), rot=(0, 0, 0)), body=R(), head=R(), arm_l=R(), arm_r=R(), book=dict(loc=(0, 0, 0), rot=(0, 0, 0)), circle=dict(rot=(0, 0, 0), scale=1.0), eyes=dict(scale=1.0), bookrune=dict(scale=1.0))
    with rig.clip("idle", 48, loop=True) as c:                     # schwebt, das Buch blättert, der Runenkreis dreht sich
        c.key(0, **rest)
        c.key(12, hips=dict(loc=(0, 0, 0.06)), book=dict(loc=(0, 0, 0.08), rot=(0, 10, 0)), circle=dict(rot=(0, 0, 30)), arm_l=R(-30, 0, 0))
        c.key(24, hips=dict(loc=(0, 0, 0)), book=dict(loc=(0, 0, 0), rot=(0, 0, 0)), circle=dict(rot=(0, 0, 60)), bookrune=dict(scale=1.4), _i="LINEAR")
        c.key(36, hips=dict(loc=(0, 0, 0.06)), book=dict(loc=(0, 0, 0.08), rot=(0, -10, 0)), circle=dict(rot=(0, 0, 90)), arm_l=R(0, 0, 0), bookrune=dict(scale=1.0))
        c.key(48, circle=dict(rot=(0, 0, 120)), _i="LINEAR")
    with rig.clip("walk", 30, loop=True, stride=1.6) as c:          # gleitet (die Robe verdeckt die Füße), das Buch folgt
        c.wave("hips", loc=(0, 0, 0.05), n=2)
        c.wave("body", rot=(0, 4, 0), base_rot=(8, 0, 0))
        c.wave("book", loc=(0, 0, 0.06), phase=0.3)
        c.wave("arm_l", rot=(-10, 0, 0), phase=0.5)
        c.wave("arm_r", rot=(-10, 0, 0))
        c.key(0, circle=dict(scale=0.02))
    with rig.clip("attack", 24, hit=14) as c:                      # Fluch: zeigt mit der Kralle
        c.key(0, **rest)
        c.key(10, arm_r=R(-90, 0, 10), body=R(-6, 0, 0), eyes=dict(scale=1.6), bookrune=dict(scale=1.6))
        c.key(14, arm_r=R(-100, 0, 0), body=R(8, 0, 0), _i="LINEAR")
        c.key(24, **rest)
    with rig.clip("summon", 39, hit=24) as c:                      # Portal öffnen: hebt die Arme, das Buch steigt, der Kreis lodert
        c.key(0, **rest)
        c.key(12, arm_l=R(-160, 0, -20), arm_r=R(-160, 0, 20), head=R(-20, 0, 0), book=dict(loc=(0, 0.1, 0.6), rot=(-30, 0, 0)), circle=dict(scale=1.3, rot=(0, 0, 90)), eyes=dict(scale=1.6))
        c.key(24, book=dict(loc=(0, 0.1, 0.8), rot=(-30, 0, 180)), circle=dict(scale=1.6, rot=(0, 0, 270)), bookrune=dict(scale=2.0), hips=dict(loc=(0, 0, 0.15)), _i="LINEAR")
        c.key(39, **rest)
    with rig.clip("hit", 9) as c:
        c.key(0, **rest)
        c.key(3, body=R(-14, 0, 10), head=R(-20, 0, 0), book=dict(loc=(0.2, 0.1, -0.1), rot=(0, 30, 0)))
        c.key(9, **rest)
    with rig.clip("death", 33) as c:                               # die Robe fällt leer zusammen, das Buch klappt zu und fällt
        c.key(0, **rest)
        c.key(10, hips=dict(loc=(0, 0, 0.2)), arm_l=R(-60, 0, 40), arm_r=R(-60, 0, -40), eyes=dict(scale=1.8))
        c.key(22, hips=dict(loc=(0, 0, -0.6)), body=dict(rot=(0, 0, 40), scale=(1.2, 1.2, 0.5)), head=R(30, 0, 0), book=dict(loc=(0, 0, -1.2), rot=(-20, 0, 40)), circle=dict(scale=0.4), _i="LINEAR")
        c.key(33, hips=dict(loc=(0, 0, -0.75)), body=dict(rot=(0, 0, 50), scale=(1.3, 1.3, 0.35)), eyes=dict(scale=0.05), book=dict(loc=(0, 0, -1.27), rot=(-20, 0, 40)), circle=dict(scale=0.02))
    rig.finish()


# ================================================================= Boss: Schleimkönig, zweite Phase – Dämon mit Flügeln (bricht aus dem Schleimriesen)
def boss_daemonen():
    rig = Rig("boss_daemonen", role="boss")
    WING = "5A1A2A"
    rig.node("hips", pivot=(0, 0, 1.5))
    p = Part()                                                                                       # Oberkörper, Schleimreste auf den Schultern
    lathe(p, [(0.6, 1.4, SOOT), (0.75, 1.7, DRED_D), (0.95, 2.3, DRED), (1.1, 2.9, DRED), (0.85, 3.25, DRED_D), (0.4, 3.35, DRED)], sides=14, sy=0.85)
    p.ball(0.5, (0, -0.6, 2.5), DRED_L, scale=(1.3, 0.4, 1.0), subdiv=2)                              # Brustmuskeln
    for (x, y, z, r) in ((0.85, -0.2, 3.1, 0.25), (-0.8, 0.1, 3.15, 0.3), (0.5, 0.5, 3.2, 0.2)):
        p.ball(r, (x, y, z), "7ADC5A", subdiv=1)                                                     # grüne Schleimreste
    p.box((1.3, 0.8, 0.3), (0, 0, 1.55), SOOT_D, bevel=0.08, segs=1)
    p.ball(0.18, (0, -0.42, 1.55), GOLD, scale=(1, 0.5, 1), subdiv=1)
    rig.add("torso", p, parent="hips", pivot=(0, 0, 1.6))
    p = Part()
    p.ball(0.3, (0, -0.55, 2.0), GLUT, scale=(1.2, 0.4, 0.9), subdiv=1)                               # glühender Bauchspalt
    rig.add("glow", p, parent="torso", pivot=(0, -0.55, 2.0), glow=True)
    p = Part()                                                                                       # Kopf: Krone aus Hörnern, Schleimkönigs-Krone (verbeult)
    p.ball(0.5, (0, -0.25, 3.7), DRED, scale=(1, 0.95, 0.95), subdiv=2)
    p.ball(0.25, (0, -0.65, 3.5), DRED_L, scale=(1.3, 0.6, 0.6), subdiv=1)
    for k in range(5):
        p.cone(0.05, 0.14, (-0.24 + 0.12 * k, -0.78, 3.42), WHITE, r=rot(180, 0, 0), sides=3)
    for s in (-1, 1):
        capsule(p, (0.4 * s, -0.2, 3.95), (0.9 * s, -0.1, 4.2), 0.12, 0.09, HORN, sides=6)
        capsule(p, (0.9 * s, -0.1, 4.2), (1.0 * s, -0.25, 4.6), 0.09, 0.03, HORN_D, sides=6)
        p.box((0.3, 0.08, 0.08), (0.2 * s, -0.7, 3.88), INK, r=rot(0, -20 * s, 0), bevel=0.0)
    lathe(p, [(0.28, 4.1, GOLD), (0.3, 4.3, "FFD24A"), (0.27, 4.32, GOLD)], sides=10, loc=(0.05, -0.2, 0), cap=False)
    for k in range(5):
        a = k * math.tau / 5
        p.cone(0.07, 0.2, (0.05 + 0.29 * math.cos(a), -0.2 + 0.29 * math.sin(a), 4.42), "FFD24A", r=rot(0, 0, 0) @ rot(-12 * math.sin(a), 12 * math.cos(a), 0), sides=4)
    rig.add("head", p, parent="torso", pivot=(0, -0.2, 3.3))
    p = Part()
    for s in (-1, 1):
        p.ball(0.1, (0.2 * s, -0.7, 3.78), GLUT_L, scale=(1.3, 0.5, 0.8), subdiv=1)
    rig.add("eyes", p, parent="head", pivot=(0, -0.7, 3.78), glow=True)
    for s, nm in ((1, "wing_l"), (-1, "wing_r")):                                                   # große Fledermausflügel
        p = Part()
        capsule(p, (0.5 * s, 0.4, 3.0), (1.6 * s, 0.8, 3.9), 0.1, 0.07, SOOT, sides=5)
        for k in range(3):
            capsule(p, (1.6 * s, 0.8, 3.9), ((2.0 + 0.3 * k) * s, 0.9 + 0.1 * k, 3.4 - 0.6 * k), 0.06, 0.03, SOOT, sides=4)
        for k in range(3):
            p.box((1.0, 0.04, 0.9), ((1.2 + 0.4 * k) * s, 0.8 + 0.05 * k, 3.35 - 0.3 * k), WING, r=rot(0, (25 - 15 * k) * s, 0), bevel=0.0)
        rig.add(nm, p, parent="torso", pivot=(0.5 * s, 0.4, 3.0))
    for s, nm in ((1, "arm_l"), (-1, "arm_r")):
        p = Part()
        p.ball(0.35, (1.05 * s, 0, 3.0), DRED_D, subdiv=2)
        capsule(p, (1.1 * s, 0, 2.9), (1.35 * s, -0.2, 2.2), 0.25, 0.22, DRED, sides=7)
        rig.add(nm, p, parent="torso", pivot=(1.05 * s, 0, 3.0))
        p = Part()
        capsule(p, (1.35 * s, -0.2, 2.2), (1.4 * s, -0.55, 1.5), 0.22, 0.18, DRED_D, sides=7)
        p.ball(0.25, (1.42 * s, -0.62, 1.38), DRED, subdiv=2)
        for k in range(3):
            p.cone(0.05, 0.22, (1.42 * s + 0.12 * (k - 1), -0.82, 1.3), INK, r=rot(150, 0, 0), sides=4)
        rig.add(nm.replace("arm", "fore"), p, parent=nm, pivot=(1.35 * s, -0.2, 2.2))
    p = Part()
    capsule(p, (0, 0.5, 1.6), (0, 1.3, 0.9), 0.1, 0.06, DRED_D, sides=6)
    capsule(p, (0, 1.3, 0.9), (0, 1.8, 1.1), 0.06, 0.04, DRED_D, sides=6)
    p.cone(0.2, 0.3, (0, 1.95, 1.15), DRED, r=rot(-70, 0, 0), sides=3)
    rig.add("tail", p, parent="torso", pivot=(0, 0.5, 1.6))
    for s, nm in ((1, "leg_l"), (-1, "leg_r")):
        p = Part()
        capsule(p, (0.45 * s, 0, 1.45), (0.5 * s, 0.15, 0.75), 0.3, 0.22, SOOT, sides=7)
        capsule(p, (0.5 * s, 0.15, 0.75), (0.5 * s, -0.05, 0.2), 0.2, 0.16, DRED_D, sides=6)
        p.box((0.4, 0.55, 0.25), (0.5 * s, -0.15, 0.12), INK, bevel=0.06, segs=1)
        rig.add(nm, p, parent="hips", pivot=(0.45 * s, 0, 1.5))
    rest = dict(root=dict(loc=(0, 0, 0), rot=(0, 0, 0)), hips=dict(loc=(0, 0, 0), rot=(0, 0, 0)), torso=R(), head=R(), wing_l=R(), wing_r=R(), arm_l=R(), arm_r=R(), fore_l=R(), fore_r=R(), tail=R(), leg_l=R(), leg_r=R(), glow=dict(scale=1.0), eyes=dict(scale=1.0))
    with rig.clip("idle", 48, loop=True) as c:                     # Flügel falten sich auf und zu, der Bauch glüht
        c.key(0, **rest)
        c.key(12, wing_l=R(0, -20, 15), wing_r=R(0, 20, -15), glow=dict(scale=1.2), torso=R(-4, 0, 0))
        c.key(24, wing_l=R(0, 10, 0), wing_r=R(0, -10, 0), glow=dict(scale=1.0), torso=R(0, 0, 0), head=R(0, 0, 10))
        c.key(36, wing_l=R(0, -15, 10), wing_r=R(0, 15, -10), head=R(0, 0, -10), tail=R(0, 0, 25))
    with rig.clip("walk", 42, loop=True, stride=2.6) as c:
        c.wave("leg_l", rot=(28, 0, 0))
        c.wave("leg_r", rot=(28, 0, 0), phase=0.5)
        c.wave("hips", rot=(0, 6, 0), phase=0.25)
        c.wave("hips", loc=(0, 0, 0.1), n=2, phase=0.25)
        c.wave("arm_l", rot=(-20, 0, 0), phase=0.5)
        c.wave("arm_r", rot=(-20, 0, 0))
        c.wave("wing_l", rot=(0, -12, 0), n=2)
        c.wave("wing_r", rot=(0, 12, 0), n=2)
        c.wave("tail", rot=(0, 0, 18))
    with rig.clip("attack", 33, hit=18) as c:                      # Prankenhieb
        c.key(0, **rest)
        c.key(11, torso=R(-10, 0, -20), arm_r=R(-140, 0, 30), fore_r=R(-40, 0, 0), wing_l=R(0, -30, 0), wing_r=R(0, 30, 0))
        c.key(18, torso=R(16, 0, 20), arm_r=R(-60, 0, -20), fore_r=R(0, 0, 0), hips=dict(loc=(0, -0.2, 0)), _i="LINEAR")
        c.key(33, **rest)
    with rig.clip("hit", 9) as c:
        c.key(0, **rest)
        c.key(3, torso=R(-8, 0, 8), head=R(-18, 0, 8), wing_l=R(0, -30, 0), wing_r=R(0, 30, 0), eyes=dict(scale=1.4))
        c.key(9, **rest)
    with rig.clip("death", 60) as c:                               # Flügel zucken, sinkt auf die Knie, fällt vornüber, Glut erlischt
        c.key(0, **rest)
        c.key(12, head=R(-30, 0, 0), wing_l=R(0, -40, 30), wing_r=R(0, 40, -30), glow=dict(scale=1.6), eyes=dict(scale=1.6))
        c.key(26, hips=dict(loc=(0, 0, -0.7)), leg_l=R(-80, 0, 0), leg_r=R(-80, 0, 0), torso=R(14, 0, 0), wing_l=R(0, 30, 0), wing_r=R(0, -30, 0), _i="LINEAR")
        c.key(42, root=dict(rot=(78, 0, 0), loc=(0, 0, 0.0)), hips=dict(loc=(0, 0, -0.7)), arm_l=R(-150, 0, 20), arm_r=R(-150, 0, -20), _i="LINEAR")
        c.key(60, root=dict(rot=(80, 0, 0), loc=(0, 0, 0.0)), hips=dict(loc=(0, 0, -0.7)), glow=dict(scale=0.05), eyes=dict(scale=0.05), wing_l=R(0, 50, 0), wing_r=R(0, -50, 0))
    with rig.clip("summon", 39, hit=22) as c:                      # breitet die Flügel aus und brüllt: Wichtel kommen
        c.key(0, **rest)
        c.key(14, wing_l=R(0, -50, 30), wing_r=R(0, 50, -30), arm_l=R(-60, 0, -60), arm_r=R(-60, 0, 60), head=R(-25, 0, 0), glow=dict(scale=1.5), torso=R(-10, 0, 0))
        c.key(22, head=R(-30, 0, 6), eyes=dict(scale=1.6))
        c.key(28, head=R(-30, 0, -6))
        c.key(39, **rest)
    with rig.clip("special", 36, hit=20) as c:                     # Feuerspucke: holt Luft, der Bauch lodert, speit nach vorn
        c.key(0, **rest)
        c.key(12, torso=R(-16, 0, 0), head=R(-30, 0, 0), glow=dict(scale=1.8), wing_l=R(0, -20, 0), wing_r=R(0, 20, 0))
        c.key(20, torso=R(18, 0, 0), head=R(16, 0, 0), glow=dict(scale=1.0), hips=dict(loc=(0, -0.2, 0)), _i="LINEAR")
        c.key(36, **rest)
    with rig.clip("slam", 42, hit=24) as c:                        # springt mit Flügelschlag hoch und landet mit beiden Fäusten
        c.key(0, **rest)
        c.key(10, hips=dict(loc=(0, 0, -0.3)), leg_l=R(-30, 0, 0), leg_r=R(-30, 0, 0), wing_l=R(0, -50, 0), wing_r=R(0, 50, 0))
        c.key(18, root=dict(loc=(0, 0, 1.2)), hips=dict(loc=(0, 0, 0)), leg_l=R(20, 0, 0), leg_r=R(20, 0, 0), arm_l=R(-170, 0, -10), arm_r=R(-170, 0, 10), wing_l=R(0, 40, 0), wing_r=R(0, -40, 0))
        c.key(24, root=dict(loc=(0, 0, 0)), hips=dict(loc=(0, 0, -0.4)), torso=R(30, 0, 0), arm_l=R(-50, 0, 0), arm_r=R(-50, 0, 0), leg_l=R(-40, 0, 0), leg_r=R(-40, 0, 0), _i="LINEAR")
        c.key(42, **rest)
    rig.finish(icon_yaw=-26, icon_pitch=10)


ARTEN = {"daemonen_hoellenwichtel": daemonen_hoellenwichtel, "daemonen_hund": daemonen_hund, "daemonen_waechter": daemonen_waechter, "daemonen_feuerspeier": daemonen_feuerspeier,
         "daemonen_schattenschwinge": daemonen_schattenschwinge, "daemonen_beschwoerer": daemonen_beschwoerer, "boss_daemonen": boss_daemonen}
