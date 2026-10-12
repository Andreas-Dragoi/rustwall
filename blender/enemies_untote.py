"""Untote Seeleute (Schrottküste): sechs Arten + Boss – das MUSTER für alle weiteren Familien (siehe blender/GEGNER.md).

Jede Art: Teile bauen (Rig.add), Clips mit Keyframes (rig.clip … c.key), rig.finish() brennt die Animations-Textur
und rendert Symbol + Bildtafel.   Aufruf:  python3 blender/enemies_untote.py [art ...] [--notafel]
"""
import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from animkit import *

# gemeinsame Farben der Familie: nass, algig, Piraten
SKIN, SKIN_D, SKIN_L = "7DBE9C", "5A9A7E", "A5DDBF"
BONE, BONE_D = "F1EAD2", "CFC4A2"
NAVY, NAVY_D = "2F4E96", "22355F"
WHITE = "F4F6FA"
WEED, WEED_L = "3F8A3C", "6FB84A"
WOOD_C, WOOD_DC = "A9622F", "7A4522"
INK = "151A22"
GOLD_C = "FFCB2E"
RUST = "B5652E"


def seaweed(p, a, b, w=0.05, color=WEED, sides=4):
    """Ein Algenstreifen von a nach b (flaches, spitz zulaufendes Band)."""
    a, b = Vector(a), Vector(b)
    d = b - a
    lathe(p, [(w, 0.0, color), (w * 0.8, d.length * 0.6, color), (0.004, d.length, color)], sides=sides, loc=tuple(a), r=face_to(d), sy=0.35, cap=False)


# ================================================================= Matrosen-Zombie (Masse)
def untote_matrose():
    rig = Rig("untote_matrose", role="mass")
    rig.node("hips", pivot=(0, 0, 0.74))
    # ---- Rumpf: aufgedunsen, Ringelhemd
    p = Part()
    st = [WHITE, NAVY]
    prof = [(0.26, 0.66, NAVY_D), (0.36, 0.74, st[0]), (0.43, 0.86, st[1]), (0.45, 0.98, st[0]), (0.43, 1.10, st[1]),
            (0.38, 1.21, st[0]), (0.30, 1.31, st[1]), (0.17, 1.39, SKIN)]
    lathe(p, prof, sides=10, sy=0.86, loc=(0, -0.03, 0))
    p.box((0.5, 0.1, 0.16), (0, 0.24, 1.28), NAVY, r=rot(18, 0, 0), bevel=0.03, segs=1)      # Matrosenkragen hinten
    rig.add("body", p, parent="hips", pivot=(0, 0, 0.74))
    # ---- Kopf: schief, ein großes Glotzauge, eine leere Höhle
    p = Part()
    p.ball(0.3, (0, -0.02, 1.62), SKIN, scale=(1.0, 0.95, 0.92), subdiv=2)
    p.ball(0.105, (-0.115, -0.25, 1.67), WHITE, scale=(1, 0.7, 1), subdiv=2)                 # Glotzauge
    p.ball(0.07, (0.13, -0.255, 1.65), INK, scale=(1, 0.45, 1.1), subdiv=1)                  # leere Augenhöhle
    p.ball(0.06, (0.2, 0.02, 1.86), SKIN_D, subdiv=1)                                        # Beule
    p.ball(0.05, (-0.27, -0.02, 1.6), SKIN_D, scale=(0.6, 1, 1.2), subdiv=1)                 # Ohr
    p.ball(0.05, (0.27, -0.02, 1.6), SKIN_D, scale=(0.6, 1, 1.2), subdiv=1)
    p.box((0.2, 0.05, 0.05), (0.0, -0.275, 1.515), "3A1A24", bevel=0.0)                      # Mundhöhle
    p.cone(0.028, 0.07, (-0.05, -0.285, 1.5), BONE, sides=4)                                 # schiefer Zahn
    rig.add("head", p, parent="body", pivot=(0, 0, 1.4))
    p = Part()
    p.ball(0.048, (-0.115, -0.325, 1.67), INK, scale=(1, 0.5, 1), subdiv=1)
    rig.add("pupil", p, parent="head", pivot=(-0.115, -0.3, 1.67), look=True)
    p = Part()                                                                               # Unterkiefer klappt auf
    p.ball(0.15, (0, -0.16, 1.45), SKIN_D, scale=(1.0, 0.9, 0.5), subdiv=1)
    p.cone(0.026, 0.07, (0.06, -0.27, 1.49), BONE, sides=4)
    rig.add("jaw", p, parent="head", pivot=(0, -0.02, 1.47))
    # ---- Matrosenmütze mit Bommel (fällt beim Tod herunter)
    p = Part()
    lathe(p, [(0.25, 1.83, NAVY), (0.26, 1.88, WHITE), (0.33, 1.95, WHITE), (0.3, 2.02, WHITE), (0.1, 2.05, WHITE)], sides=9, loc=(0.02, 0, 0))
    p.ball(0.06, (0.02, 0, 2.08), "D54144", subdiv=1)
    rig.add("hat", p, parent="head", pivot=(0.02, 0, 1.85))
    # ---- rechter Arm (zwei Glieder), linker Arm fehlt: Stumpf mit Knochen
    p = Part()
    capsule(p, (-0.44, 0, 1.24), (-0.5, -0.02, 0.92), 0.105, 0.09, WHITE, sides=6)
    paint(p, NAVY, zmin=1.02, zmax=1.12)
    rig.add("arm_r", p, parent="body", pivot=(-0.42, 0, 1.24))
    p = Part()
    capsule(p, (-0.5, -0.02, 0.9), (-0.52, -0.1, 0.62), 0.085, 0.075, SKIN, sides=6)
    p.ball(0.11, (-0.52, -0.13, 0.54), SKIN_D, scale=(0.9, 1.0, 1.1), subdiv=1)              # Pranke
    rig.add("fore_r", p, parent="arm_r", pivot=(-0.5, -0.02, 0.9))
    p = Part()
    capsule(p, (0.43, 0, 1.24), (0.52, 0, 1.08), 0.11, 0.1, WHITE, sides=6)
    lathe(p, [(0.03, 0.0, BONE), (0.03, 0.14, BONE), (0.05, 0.17, BONE)], sides=5, loc=(0.52, 0, 1.08), r=face_to((0.5, 0, -0.85)))
    rig.add("stump", p, parent="body", pivot=(0.42, 0, 1.24))
    # ---- Beine: links Hose und Schuh, rechts Holzbein (das zieht er nach)
    p = Part()
    capsule(p, (0.18, 0, 0.7), (0.19, 0, 0.16), 0.14, 0.115, NAVY_D, sides=6)
    p.ball(0.13, (0.19, -0.07, 0.075), INK, scale=(0.95, 1.5, 0.58), subdiv=1)
    rig.add("leg_l", p, parent="hips", pivot=(0.18, 0, 0.72))
    p = Part()
    capsule(p, (-0.18, 0, 0.7), (-0.18, 0, 0.44), 0.14, 0.12, NAVY_D, sides=6)
    lathe(p, [(0.05, 0.0, WOOD_DC), (0.07, 0.06, WOOD_C), (0.085, 0.42, WOOD_C)], sides=6, loc=(-0.18, 0, 0.0))
    rig.add("leg_r", p, parent="hips", pivot=(-0.18, 0, 0.72))
    # ---- Algen über der Schulter
    p = Part()
    seaweed(p, (0.3, -0.1, 1.33), (0.4, -0.3, 0.86), 0.06)
    seaweed(p, (0.2, 0.12, 1.34), (0.3, 0.34, 0.92), 0.05, WEED_L)
    seaweed(p, (-0.05, -0.2, 1.36), (-0.12, -0.42, 1.04), 0.045, WEED_L)
    rig.add("weed", p, parent="body", pivot=(0.2, 0, 1.33))

    # ---------------------------------------------------------------- Clips
    lean = dict(rot=(10, 0, 4))                                   # Grundhaltung: vornübergebeugt, schief
    with rig.clip("idle", 42, loop=True) as c:
        c.key(0, body=lean, head=dict(rot=(-6, 0, 10)), arm_r=dict(rot=(-8, 0, -4)), fore_r=dict(rot=(-14, 0, 0)), stump=dict(rot=(0, 0, 0)), jaw=dict(rot=(0, 0, 0)), weed=dict(rot=(0, 0, 0)))
        c.key(12, body=dict(rot=(12, 0, 1)), head=dict(rot=(-2, 0, 14)), stump=dict(rot=(-20, 0, 8)))
        c.key(21, body=dict(rot=(9, 0, -3)), head=dict(rot=(-8, 6, 8)), arm_r=dict(rot=(-14, 0, -8)), jaw=dict(rot=(-16, 0, 0)), stump=dict(rot=(6, 0, 0)), weed=dict(rot=(4, 0, 5)))
        c.key(32, body=dict(rot=(11, 0, 5)), head=dict(rot=(-4, -4, 12)), jaw=dict(rot=(0, 0, 0)), weed=dict(rot=(-3, 0, -4)))
    # Schlurfen: linkes Bein macht den Schritt, das Holzbein wird steif nachgezogen, der Körper kippt über das Holzbein
    with rig.clip("walk", 30, loop=True, stride=1.25) as c:
        c.key(0, hips=dict(loc=(0, 0, 0), rot=(0, 0, 0)), body=dict(rot=(14, 0, 6)), head=dict(rot=(-8, 0, 8)), leg_l=dict(rot=(-34, 0, 0)), leg_r=dict(rot=(14, 0, 6)),
              arm_r=dict(rot=(-50, 0, -6)), fore_r=dict(rot=(-30, 0, 0)), stump=dict(rot=(-30, 0, 6)), jaw=dict(rot=(-10, 0, 0)), weed=dict(rot=(6, 0, 0)), hat=dict(rot=(0, 0, 0)))
        c.key(8, hips=dict(loc=(0.03, 0, -0.03), rot=(0, 0, 3)), body=dict(rot=(18, 0, 2)), leg_l=dict(rot=(2, 0, 0)), leg_r=dict(rot=(24, 0, 8)), head=dict(rot=(-4, 0, 14)), arm_r=dict(rot=(-58, 0, -4)), jaw=dict(rot=(-2, 0, 0)), weed=dict(rot=(-5, 0, 3)))
        c.key(15, hips=dict(loc=(-0.05, 0, 0.03), rot=(0, 0, -7)), body=dict(rot=(10, 0, -5)), leg_l=dict(rot=(26, 0, 0)), leg_r=dict(rot=(-10, 0, 12)), head=dict(rot=(-10, 0, -2)), stump=dict(rot=(-44, 0, 10)), hat=dict(rot=(0, 0, 5)))
        c.key(23, hips=dict(loc=(-0.02, 0, 0.0), rot=(0, 0, -2)), body=dict(rot=(12, 0, 2)), leg_l=dict(rot=(-14, 0, 0)), leg_r=dict(rot=(-4, 0, 4)), arm_r=dict(rot=(-44, 0, -8)), jaw=dict(rot=(-14, 0, 0)), weed=dict(rot=(4, 0, -3)), hat=dict(rot=(0, 0, 0)))
    # Angriff: holt mit der Pranke über Kopf aus, schlägt und schnappt
    with rig.clip("attack", 24, hit=13) as c:
        c.key(0, body=lean, head=dict(rot=(-6, 0, 10)), arm_r=dict(rot=(-8, 0, -4)), fore_r=dict(rot=(-14, 0, 0)), jaw=dict(rot=(0, 0, 0)), hips=dict(loc=(0, 0, 0)), stump=dict(rot=(0, 0, 0)))
        c.key(8, body=dict(rot=(-12, 0, -8)), head=dict(rot=(-18, 0, 0)), arm_r=dict(rot=(-165, 0, -16)), fore_r=dict(rot=(-40, 0, 0)), jaw=dict(rot=(-34, 0, 0)), hips=dict(loc=(0, 0.06, 0)), stump=dict(rot=(30, 0, 10)))
        c.key(13, body=dict(rot=(30, 0, 8)), head=dict(rot=(14, 0, 4)), arm_r=dict(rot=(-62, 0, 10)), fore_r=dict(rot=(-8, 0, 0)), jaw=dict(rot=(4, 0, 0)), hips=dict(loc=(0, -0.16, -0.04)), stump=dict(rot=(-50, 0, 0)))
        c.key(17, body=dict(rot=(26, 0, 8)), arm_r=dict(rot=(-40, 0, 6)))
        c.key(24, body=lean, head=dict(rot=(-6, 0, 10)), arm_r=dict(rot=(-8, 0, -4)), fore_r=dict(rot=(-14, 0, 0)), jaw=dict(rot=(0, 0, 0)), hips=dict(loc=(0, 0, 0)), stump=dict(rot=(0, 0, 0)))
    # Treffer: zuckt zurück, Mütze hüpft
    with rig.clip("hit", 9) as c:
        c.key(0, body=lean, head=dict(rot=(-6, 0, 10)), hat=dict(loc=(0, 0, 0)), arm_r=dict(rot=(-8, 0, -4)), hips=dict(loc=(0, 0, 0)))
        c.key(3, body=dict(rot=(-16, 0, -6)), head=dict(rot=(-24, 0, -8)), hat=dict(loc=(0, 0, 0.09)), arm_r=dict(rot=(-50, 0, -30)), hips=dict(loc=(0, 0.08, 0)))
        c.key(9, body=lean, head=dict(rot=(-6, 0, 10)), hat=dict(loc=(0, 0, 0)), arm_r=dict(rot=(-8, 0, -4)), hips=dict(loc=(0, 0, 0)))
    # Tod: kippt steif nach hinten um, die Mütze fliegt davon, ein letztes Zucken
    with rig.clip("death", 33) as c:
        c.key(0, root=dict(rot=(0, 0, 0), loc=(0, 0, 0)), body=lean, head=dict(rot=(-6, 0, 10)), arm_r=dict(rot=(-8, 0, -4)), fore_r=dict(rot=(-14, 0, 0)), stump=dict(rot=(0, 0, 0)),
              leg_l=dict(rot=(0, 0, 0)), leg_r=dict(rot=(0, 0, 0)), hat=dict(loc=(0, 0, 0), rot=(0, 0, 0)), jaw=dict(rot=(0, 0, 0)))
        c.key(6, root=dict(rot=(8, 0, 0)), body=dict(rot=(-14, 0, 0)), head=dict(rot=(-24, 0, 0)), arm_r=dict(rot=(-120, 0, -30)), stump=dict(rot=(-100, 0, 30)), jaw=dict(rot=(-36, 0, 0)), hat=dict(loc=(0, 0.1, 0.2), rot=(-30, 0, 0)))
        c.key(16, root=dict(rot=(-86, 0, 0), loc=(0, 0, 0.2)), body=dict(rot=(-4, 0, 0)), head=dict(rot=(10, 0, 0)), arm_r=dict(rot=(-150, 0, -50)), fore_r=dict(rot=(0, 0, 0)), stump=dict(rot=(-60, 0, 40)),
              leg_l=dict(rot=(-30, 0, 0)), leg_r=dict(rot=(-12, 0, -8)), hat=dict(loc=(0.05, -0.5, 0.5), rot=(60, 0, 20)))
        c.key(20, root=dict(rot=(-80, 0, 0), loc=(0, 0, 0.27)), leg_l=dict(rot=(-44, 0, 0)), head=dict(rot=(-6, 0, 0)))
        c.key(24, root=dict(rot=(-88, 0, 0), loc=(0, 0, 0.19)), leg_l=dict(rot=(-4, 0, 6)), leg_r=dict(rot=(-2, 0, -10)), head=dict(rot=(8, 0, 12)), arm_r=dict(rot=(-160, 0, -60)),
              hat=dict(loc=(0.15, 0.1, 0.6), rot=(108, 0, 30)), jaw=dict(rot=(-10, 0, 0)))
        c.key(33, root=dict(rot=(-88, 0, 0), loc=(0, 0, 0.19)), hat=dict(loc=(0.15, 0.1, 0.6), rot=(108, 0, 30)))
    # Wiederauferstehen: der Arm zuckt, er stemmt sich hoch, schüttelt den Kopf – die Mütze sitzt wieder
    with rig.clip("revive", 45) as c:
        c.key(0, root=dict(rot=(-88, 0, 0), loc=(0, 0, 0.19)), body=dict(rot=(-4, 0, 0)), head=dict(rot=(8, 0, 12)), arm_r=dict(rot=(-160, 0, -60)), fore_r=dict(rot=(0, 0, 0)), stump=dict(rot=(-60, 0, 40)),
              leg_l=dict(rot=(-4, 0, 6)), leg_r=dict(rot=(-2, 0, -10)), hat=dict(loc=(0.15, 0.1, 0.6), rot=(108, 0, 30), scale=1.0), jaw=dict(rot=(-10, 0, 0)))
        c.key(6, arm_r=dict(rot=(-120, 0, -70)), hat=dict(scale=0.01), _i="LINEAR")
        c.key(7, hat=dict(loc=(0, 0, 0.4), rot=(0, 0, 0), scale=0.01), _i="CONSTANT")
        c.key(10, arm_r=dict(rot=(-170, 0, -50)), root=dict(rot=(-88, 0, 0), loc=(0, 0, 0.19)))
        c.key(22, root=dict(rot=(-40, 0, 0), loc=(0, 0, 0.05)), body=dict(rot=(40, 0, 0)), head=dict(rot=(30, 0, 0)), arm_r=dict(rot=(-40, 0, -10)), stump=dict(rot=(-20, 0, 10)), leg_l=dict(rot=(-50, 0, 0)), leg_r=dict(rot=(10, 0, 0)))
        c.key(32, root=dict(rot=(4, 0, 0), loc=(0, 0, 0)), body=dict(rot=(22, 0, 0)), head=dict(rot=(-10, 0, -16)), leg_l=dict(rot=(0, 0, 0)), leg_r=dict(rot=(0, 0, 0)), hat=dict(loc=(0, 0, 0.3), scale=1.0), jaw=dict(rot=(-30, 0, 0)))
        c.key(37, head=dict(rot=(-8, 0, 24)), hat=dict(loc=(0, 0, 0), rot=(0, 0, 0)))
        c.key(45, root=dict(rot=(0, 0, 0), loc=(0, 0, 0)), body=lean, head=dict(rot=(-6, 0, 10)), arm_r=dict(rot=(-8, 0, -4)), fore_r=dict(rot=(-14, 0, 0)), stump=dict(rot=(0, 0, 0)), jaw=dict(rot=(0, 0, 0)))
    rig.finish()


# ================================================================= Deckratte (Flitzer, kommt im Schwarm)
def untote_deckratte():
    rig = Rig("untote_deckratte", role="fast", size=1.4)
    RED_T = "D8343A"
    # ---- Rumpf: Rückgrat mit drei Rippenbögen, Becken, Schultern
    p = Part()
    capsule(p, (0, -0.2, 0.33), (0, 0.3, 0.3), 0.04, 0.035, BONE, sides=5)
    for i, (y, r) in enumerate(((-0.1, 0.12), (0.04, 0.135), (0.17, 0.115))):
        p.torus(r, 0.024, (0, y, 0.3), BONE if i != 1 else BONE_D, r=rot(90, 0, 0), seg=8, tseg=4)
    p.ball(0.085, (0, 0.3, 0.3), BONE_D, scale=(1.2, 0.9, 0.9), subdiv=1)
    p.ball(0.075, (0, -0.2, 0.33), BONE_D, scale=(1.3, 0.8, 0.9), subdiv=1)
    rig.add("body", p, pivot=(0, 0.05, 0.3))
    # ---- Schädel mit langer Schnauze, großen Ohren, rotem Piratentuch
    p = Part()
    p.ball(0.15, (0, -0.4, 0.42), BONE, scale=(0.95, 1.15, 0.9), subdiv=2)
    lathe(p, [(0.1, 0.0, BONE), (0.065, 0.14, BONE), (0.03, 0.22, "E88A9A")], sides=6, loc=(0, -0.48, 0.38), r=rot(96, 0, 0))   # Schnauze, rosa Nasenspitze
    for s in (-1, 1):
        p.ball(0.095, (0.14 * s, -0.33, 0.56), BONE_D, scale=(1.0, 0.3, 1.0), subdiv=1)      # Ohren
        p.ball(0.045, (0.075 * s, -0.5, 0.46), INK, scale=(0.8, 0.6, 1.0), subdiv=1)         # Augenhöhlen
        p.cone(0.02, 0.07, (0.022 * s, -0.69, 0.335), WHITE, r=rot(180, 0, 0), sides=4)      # Nagezähne
    lathe(p, [(0.15, 0.0, RED_T), (0.158, 0.05, RED_T), (0.11, 0.12, RED_T), (0.0, 0.15, RED_T)], sides=8, loc=(0, -0.39, 0.45), r=rot(-12, 0, 0), sy=1.1)   # Tuch
    p.cone(0.045, 0.16, (0.06, -0.22, 0.47), RED_T, r=rot(-115, 0, 20), sides=4)                # Knoten-Zipfel
    p.cone(0.04, 0.13, (-0.02, -0.22, 0.5), RED_T, r=rot(-100, 0, -25), sides=4)
    rig.add("head", p, parent="body", pivot=(0, -0.24, 0.36))
    p = Part()
    for s in (-1, 1):
        p.ball(0.022, (0.075 * s, -0.535, 0.46), "9DFF6A", subdiv=1)
    rig.add("eyes", p, parent="head", pivot=(0, -0.53, 0.46), glow=True, look=True)
    p = Part()
    lathe(p, [(0.055, 0.0, BONE_D), (0.035, 0.15, BONE_D), (0.012, 0.2, BONE_D)], sides=5, loc=(0, -0.47, 0.33), r=rot(98, 0, 0), sy=0.5)
    rig.add("jaw", p, parent="head", pivot=(0, -0.45, 0.34))
    # ---- Schwanz aus drei Knochengliedern
    pv = [(0, 0.36, 0.3), (0, 0.6, 0.31), (0, 0.84, 0.33), (0, 1.08, 0.36)]
    par = "body"
    for i in range(3):
        p = Part()
        capsule(p, pv[i], pv[i + 1], 0.04 - i * 0.01, 0.032 - i * 0.01, BONE if i % 2 == 0 else BONE_D, sides=5)
        rig.add("tail%d" % (i + 1), p, parent=par, pivot=pv[i])
        par = "tail%d" % (i + 1)
    # ---- vier Knochenbeinchen
    for nm, x, y in (("leg_fl", 0.11, -0.2), ("leg_fr", -0.11, -0.2), ("leg_bl", 0.12, 0.3), ("leg_br", -0.12, 0.3)):
        p = Part()
        capsule(p, (x, y, 0.3), (x * 1.5, y - 0.04, 0.05), 0.03, 0.024, BONE, sides=5)
        p.ball(0.045, (x * 1.5, y - 0.09, 0.03), BONE_D, scale=(0.9, 1.5, 0.55), subdiv=1)
        rig.add(nm, p, parent="body", pivot=(x, y, 0.3))

    # ---------------------------------------------------------------- Clips
    with rig.clip("idle", 30, loop=True) as c:                       # schnuppert, Schwanz zuckt
        c.key(0, body=dict(rot=(0, 0, 0), loc=(0, 0, 0)), head=dict(rot=(0, 0, 0)), jaw=dict(rot=(0, 0, 0)), tail1=dict(rot=(8, 0, 0)), tail2=dict(rot=(10, 0, 0)), tail3=dict(rot=(12, 0, 0)))
        c.key(6, head=dict(rot=(-14, 0, 8)), jaw=dict(rot=(10, 0, 0)), tail1=dict(rot=(8, 0, 14)), tail2=dict(rot=(10, 0, 18)))
        c.key(10, head=dict(rot=(-6, 0, 12)), jaw=dict(rot=(0, 0, 0)))
        c.key(14, head=dict(rot=(-16, 0, -4)), jaw=dict(rot=(12, 0, 0)), body=dict(rot=(-4, 0, 0)))
        c.key(22, head=dict(rot=(4, 0, -10)), jaw=dict(rot=(0, 0, 0)), tail1=dict(rot=(8, 0, -14)), tail2=dict(rot=(10, 0, -20)), tail3=dict(rot=(12, 0, -16)), body=dict(rot=(0, 0, 0)))
    with rig.clip("walk", 12, loop=True, stride=1.1) as c:           # Trippeln: kreuzweise, sehr schnell
        c.wave("leg_fl", rot=(42, 0, 0), phase=0.0)
        c.wave("leg_br", rot=(42, 0, 0), phase=0.0)
        c.wave("leg_fr", rot=(42, 0, 0), phase=0.5)
        c.wave("leg_bl", rot=(42, 0, 0), phase=0.5)
        c.wave("body", loc=(0, 0, 0.025), rot=(3, 0, 0), n=2, phase=0.1)
        c.wave("head", rot=(5, 0, 0), n=2, phase=0.3, base_rot=(-6, 0, 0))
        c.wave("tail1", rot=(0, 0, 16), base_rot=(14, 0, 0))
        c.wave("tail2", rot=(0, 0, 22), phase=0.8, base_rot=(8, 0, 0))
        c.wave("tail3", rot=(0, 0, 26), phase=0.6, base_rot=(6, 0, 0))
    with rig.clip("attack", 15, hit=7) as c:                         # duckt sich, springt vor und beißt
        c.key(0, root=dict(loc=(0, 0, 0)), body=dict(rot=(0, 0, 0)), head=dict(rot=(0, 0, 0)), jaw=dict(rot=(0, 0, 0)), leg_fl=dict(rot=(0, 0, 0)), leg_fr=dict(rot=(0, 0, 0)), tail1=dict(rot=(8, 0, 0)))
        c.key(4, root=dict(loc=(0, 0.1, -0.04)), body=dict(rot=(-14, 0, 0)), head=dict(rot=(-20, 0, 0)), jaw=dict(rot=(38, 0, 0)), tail1=dict(rot=(40, 0, 0)))
        c.key(7, root=dict(loc=(0, -0.32, 0.1)), body=dict(rot=(12, 0, 0)), head=dict(rot=(16, 0, 0)), jaw=dict(rot=(-4, 0, 0)), leg_fl=dict(rot=(-60, 0, 0)), leg_fr=dict(rot=(-60, 0, 0)), tail1=dict(rot=(-10, 0, 0)))
        c.key(10, root=dict(loc=(0, -0.2, 0.0)), jaw=dict(rot=(20, 0, 0)))
        c.key(15, root=dict(loc=(0, 0, 0)), body=dict(rot=(0, 0, 0)), head=dict(rot=(0, 0, 0)), jaw=dict(rot=(0, 0, 0)), leg_fl=dict(rot=(0, 0, 0)), leg_fr=dict(rot=(0, 0, 0)), tail1=dict(rot=(8, 0, 0)))
    with rig.clip("hit", 9) as c:                                    # hüpft erschrocken hoch, Knochen klappern
        c.key(0, root=dict(loc=(0, 0, 0), rot=(0, 0, 0)), head=dict(rot=(0, 0, 0)), tail1=dict(rot=(8, 0, 0)))
        c.key(3, root=dict(loc=(0, 0.12, 0.22), rot=(-18, 0, 10)), head=dict(rot=(-30, 0, 0)), tail1=dict(rot=(60, 0, 0)))
        c.key(9, root=dict(loc=(0, 0, 0), rot=(0, 0, 0)), head=dict(rot=(0, 0, 0)), tail1=dict(rot=(8, 0, 0)))
    with rig.clip("death", 27) as c:                                 # zerfällt in einen Knochenhaufen, der Schädel kullert davon
        c.key(0, root=dict(loc=(0, 0, 0)), body=dict(loc=(0, 0, 0), rot=(0, 0, 0)), head=dict(loc=(0, 0, 0), rot=(0, 0, 0)), jaw=dict(rot=(0, 0, 0)),
              tail1=dict(rot=(8, 0, 0)), tail2=dict(rot=(10, 0, 0)), tail3=dict(rot=(12, 0, 0)),
              leg_fl=dict(rot=(0, 0, 0)), leg_fr=dict(rot=(0, 0, 0)), leg_bl=dict(rot=(0, 0, 0)), leg_br=dict(rot=(0, 0, 0)))
        c.key(5, body=dict(loc=(0, 0, 0.18), rot=(-10, 0, 0)), head=dict(rot=(-30, 0, 0)), jaw=dict(rot=(40, 0, 0)))
        c.key(12, body=dict(loc=(0, 0, -0.17), rot=(0, 70, 0)), head=dict(loc=(0, -0.1, 0.25), rot=(120, 0, 30)),
              leg_fl=dict(rot=(0, 80, 0)), leg_fr=dict(rot=(0, -80, 0)), leg_bl=dict(rot=(0, 85, 0)), leg_br=dict(rot=(0, -85, 0)),
              tail1=dict(rot=(-2, 0, 30)), tail2=dict(rot=(0, 0, 40)), tail3=dict(rot=(0, 0, 50)))
        c.key(18, body=dict(loc=(0, 0, -0.2), rot=(0, 86, 0)), head=dict(loc=(0.25, -0.35, 0.0), rot=(300, 0, 60)))
        c.key(27, head=dict(loc=(0.3, -0.5, 0.02), rot=(450, 0, 70)), jaw=dict(rot=(40, 0, 0)))
    with rig.clip("busy", 12, loop=True) as c:                       # knabbert an Türmen: Kopf rattert, Kiefer klappert
        c.key(0, body=dict(rot=(-18, 0, 0), loc=(0, 0, 0.05)), leg_fl=dict(rot=(-70, 0, 0)), leg_fr=dict(rot=(-70, 0, 0)), tail1=dict(rot=(30, 0, 0)))
        c.wave("head", rot=(9, 0, 0), n=3, base_rot=(12, 0, 0))
        c.wave("jaw", rot=(16, 0, 0), n=3, base_rot=(18, 0, 0), phase=0.25)
        c.wave("tail2", rot=(0, 0, 20), base_rot=(10, 0, 0))
    rig.finish(icon_yaw=-40, icon_pitch=20)


# ================================================================= Ertrunkener Taucher (Brocken)
def untote_taucher():
    rig = Rig("untote_taucher", role="tank")
    SUIT, SUIT_D, SUIT_L = "B49A62", "8C7648", "CDB884"
    COPPER, COPPER_D, BRASS = "C9793A", "9A5524", "E8B33A"
    LEAD, GLOVE = "4A505E", "3A3F4C"
    IRON, IRON_D = "5C6474", "3E4452"
    rig.node("hips", pivot=(0, 0, 1.05))
    # ---- Rumpf: praller Segeltuch-Anzug, Bleigürtel, Kupferkragen, zwei Luftflaschen
    p = Part()
    lathe(p, [(0.46, 0.92, SUIT_D), (0.64, 1.12, SUIT), (0.74, 1.5, SUIT), (0.7, 1.86, SUIT), (0.56, 2.1, SUIT_L), (0.4, 2.2, COPPER_D)], sides=12, sy=0.82)
    lathe(p, [(0.69, 1.1, GLOVE), (0.74, 1.16, GLOVE), (0.74, 1.3, GLOVE), (0.7, 1.34, GLOVE)], sides=12, sy=0.84, cap=False)                     # Gürtel
    for i in range(6):                                                                                                                         # Bleigewichte
        a = math.radians(i * 60 + 30)
        p.box((0.2, 0.12, 0.24), (math.cos(a) * 0.76, math.sin(a) * 0.63, 1.22), LEAD, r=rot(0, 0, i * 60 + 120), bevel=0.03, segs=1)
    lathe(p, [(0.5, 2.06, COPPER_D), (0.6, 2.14, COPPER), (0.58, 2.24, COPPER), (0.4, 2.32, COPPER_D)], sides=12, sy=0.9)                       # Kupferkragen
    for i in range(6):
        a = math.radians(i * 60)
        p.ball(0.04, (math.cos(a) * 0.59, math.sin(a) * 0.53, 2.19), BRASS, subdiv=1)                                                           # Nieten
    for s in (-1, 1):                                                                                                                          # Luftflaschen
        lathe(p, [(0.1, 0.0, IRON_D), (0.17, 0.08, IRON), (0.17, 0.7, IRON), (0.08, 0.8, IRON_D), (0.05, 0.88, BRASS)], sides=8, loc=(0.2 * s, 0.6, 1.3))
    p.box((0.28, 0.04, 0.24), (0.3, -0.585, 1.62), SUIT_D, r=rot(-8, 0, 12), bevel=0.0)                                                         # Flicken
    p.box((0.2, 0.04, 0.2), (-0.34, -0.56, 1.42), "7C8A66", r=rot(-4, 0, -20), bevel=0.0)
    star(p, (-0.52, -0.32, 1.98), 0.15, "F08A3A", 0.07, r=rot(60, 30, 0))                                                                      # Seestern
    rig.add("body", p, parent="hips", pivot=(0, 0, 1.05))
    # ---- Kupferhelm mit drei Bullaugen; innen glühen zwei Augen
    p = Part()
    p.ball(0.5, (0, 0, 2.66), COPPER, scale=(1.0, 1.0, 0.96), subdiv=3)
    p.torus(0.23, 0.055, (0, -0.47, 2.66), BRASS, r=rot(90, 0, 0), seg=12, tseg=5)
    p.cyl(0.22, 0.04, (0, -0.46, 2.66), "10242A", r=rot(90, 0, 0), sides=12)
    for s in (-1, 1):
        p.torus(0.13, 0.04, (0.45 * s, -0.1, 2.72), BRASS, r=rot(90, 0, 78 * s), seg=10, tseg=4)
        p.cyl(0.125, 0.04, (0.44 * s, -0.1, 2.72), "10242A", r=rot(90, 0, 78 * s), sides=10)
    lathe(p, [(0.1, 0.0, BRASS), (0.12, 0.06, BRASS), (0.07, 0.1, COPPER_D), (0.07, 0.16, COPPER_D), (0.13, 0.19, BRASS), (0.13, 0.23, BRASS)], sides=8, loc=(0, 0.05, 3.12))   # Ventil
    for i in range(5):
        a = math.radians(-60 + i * 30)
        p.ball(0.035, (math.sin(a) * 0.36, -0.33, 2.66 + math.cos(a) * 0.36 * 0.9), BRASS, subdiv=1)
    p.cone(0.06, 0.12, (0.3, 0.2, 3.02), "E9E3D0", r=rot(-20, 30, 0), sides=5)                                                                 # Seepocken
    p.cone(0.05, 0.1, (0.2, 0.32, 2.98), "D6CFBA", r=rot(-35, 20, 0), sides=5)
    p.cone(0.045, 0.09, (-0.34, 0.12, 3.0), "E9E3D0", r=rot(-10, -36, 0), sides=5)
    rig.add("helmet", p, parent="body", pivot=(0, 0, 2.26))
    p = Part()
    for s in (-1, 1):
        p.ball(0.055, (0.085 * s, -0.47, 2.68), "9DFF6A", scale=(1, 0.5, 1.2), subdiv=1)
    rig.add("eyes", p, parent="helmet", pivot=(0, -0.45, 2.68), glow=True, look=True)
    p = Part()                                                                                                                                 # Algen am Helm
    seaweed(p, (-0.3, -0.25, 3.02), (-0.62, -0.42, 2.4), 0.08)
    seaweed(p, (-0.38, 0.1, 2.98), (-0.72, 0.2, 2.3), 0.07, WEED_L)
    seaweed(p, (0.1, 0.4, 2.95), (0.2, 0.75, 2.2), 0.07)
    rig.add("weed", p, parent="helmet", pivot=(-0.2, 0, 3.0))
    # ---- Arme: dicke Ärmel, dunkle Handschuhe
    for nm, s in (("l", 1), ("r", -1)):
        p = Part()
        capsule(p, (0.74 * s, 0, 2.0), (0.92 * s, 0, 1.52), 0.23, 0.2, SUIT, sides=8)
        lathe(p, [(0.24, 0.0, SUIT_D), (0.25, 0.1, SUIT_D)], sides=8, loc=(0.9 * s, 0, 1.56), r=face_to((0.18 * s, 0, -0.48)), cap=False)
        rig.add("arm_" + nm, p, parent="body", pivot=(0.72 * s, 0, 2.0))
        p = Part()
        capsule(p, (0.92 * s, 0, 1.5), (0.98 * s, -0.08, 1.12), 0.19, 0.17, SUIT_L, sides=8)
        lathe(p, [(0.2, 0.0, BRASS), (0.2, 0.07, BRASS)], sides=8, loc=(0.975 * s, -0.07, 1.16), r=face_to((0.06 * s, -0.08, -0.38)), cap=False)   # Manschette
        p.ball(0.22, (1.0 * s, -0.1, 0.98), GLOVE, scale=(0.9, 1.0, 1.05), subdiv=2)
        rig.add("fore_" + nm, p, parent="arm_" + nm, pivot=(0.92 * s, 0, 1.5))
    # ---- Anker an der Kette: hängt an der rechten Hand, Schaft in Verlängerung des Arms
    hx, hy, hz = -1.0, -0.1, 0.92
    p = Part()
    p.torus(0.12, 0.035, (hx, hy, hz - 0.1), IRON, r=rot(90, 0, 90), seg=10, tseg=4)                                                           # Ring
    capsule(p, (hx, hy, hz - 0.2), (hx, hy, hz - 0.82), 0.055, 0.065, IRON, sides=6)                                                           # Schaft
    capsule(p, (hx, hy - 0.26, hz - 0.3), (hx, hy + 0.26, hz - 0.3), 0.04, 0.04, WOOD_DC, sides=5)                                              # Ankerstock
    for s in (-1, 1):                                                                                                                          # Arme und Flunken
        capsule(p, (hx, hy, hz - 0.84), (hx + 0.34 * s, hy, hz - 0.62), 0.065, 0.05, IRON_D, sides=6)
        p.cone(0.11, 0.2, (hx + 0.4 * s, hy, hz - 0.52), IRON, r=rot(0, -38 * s, 0), sides=4)
    p.ball(0.09, (hx, hy, hz - 0.86), IRON_D, subdiv=1)
    rig.add("anchor", p, parent="fore_r", pivot=(hx, hy, hz))
    p = Part()                                                                                                                                 # Kette (im Ruhezustand eingezogen)
    for i in range(5):
        p.torus(0.055, 0.02, (hx, hy, hz - 0.1 - i * 0.2), IRON if i % 2 else IRON_D, r=rot(90, 0, 90 * (i % 2)), seg=6, tseg=3)
    rig.add("chain", p, parent="fore_r", pivot=(hx, hy, hz))
    # ---- Beine mit Bleischuhen
    for nm, s in (("l", 1), ("r", -1)):
        p = Part()
        capsule(p, (0.3 * s, 0, 1.0), (0.32 * s, 0, 0.34), 0.26, 0.22, SUIT_D, sides=8)
        p.box((0.2, 0.04, 0.2), (0.32 * s, -0.235, 0.62), SUIT_L, r=rot(4, 0, 10 * s), bevel=0.0)                                               # Knieflicken
        p.box((0.46, 0.68, 0.26), (0.33 * s, -0.1, 0.13), LEAD, bevel=0.08, segs=2)
        p.box((0.48, 0.2, 0.07), (0.33 * s, -0.3, 0.2), BRASS, bevel=0.02, segs=1)
        rig.add("leg_" + nm, p, parent="hips", pivot=(0.3 * s, 0, 1.02))

    # ---------------------------------------------------------------- Clips
    HIDE = dict(scale=(1, 1, 0.02))
    rest = dict(hips=dict(loc=(0, 0, 0), rot=(0, 0, 0)), body=dict(rot=(6, 0, 0), scale=1.0), helmet=dict(rot=(4, 0, 0)), arm_l=dict(rot=(0, 0, 6)), fore_l=dict(rot=(-10, 0, 0)),
                arm_r=dict(rot=(0, 0, -6)), fore_r=dict(rot=(-6, 0, 0)), anchor=dict(loc=(0, 0, 0), rot=(0, 0, 0)), chain=HIDE, leg_l=dict(rot=(0, 0, 0)), leg_r=dict(rot=(0, 0, 0)),
                weed=dict(rot=(0, 0, 0)), root=dict(loc=(0, 0, 0), rot=(0, 0, 0)))
    with rig.clip("idle", 48, loop=True) as c:                       # schweres Atmen im Anzug, der Anker pendelt
        c.key(0, **rest)
        c.key(14, body=dict(rot=(4, 0, 0), scale=(1.035, 1.045, 1.01)), helmet=dict(rot=(-2, 0, 5)), anchor=dict(rot=(0, 10, 0)), arm_l=dict(rot=(0, 0, 10)), weed=dict(rot=(0, 4, 3)))
        c.key(28, body=dict(rot=(7, 0, 0), scale=1.0), helmet=dict(rot=(6, 0, -6)), anchor=dict(rot=(0, -8, 0)), arm_l=dict(rot=(0, 0, 5)), weed=dict(rot=(0, -4, -3)))
        c.key(38, helmet=dict(rot=(2, 0, -8)), anchor=dict(rot=(0, 4, 0)))
    # Stampfen: bei jedem Schritt wankt der ganze Kerl zur Seite, der Anker schleift hinterher
    with rig.clip("walk", 48, loop=True, stride=1.7) as c:
        c.key(0, hips=dict(loc=(0.07, 0, 0), rot=(0, 5, 0)), body=dict(rot=(10, 0, 3)), helmet=dict(rot=(2, 0, -4)), leg_l=dict(rot=(-30, 0, 0)), leg_r=dict(rot=(22, 0, 0)),
              arm_l=dict(rot=(24, 0, 8)), fore_l=dict(rot=(-20, 0, 0)), arm_r=dict(rot=(-14, 0, -6)), fore_r=dict(rot=(-10, 0, 0)), anchor=dict(rot=(26, 0, 0), loc=(0, 0, 0)), chain=HIDE, weed=dict(rot=(8, 0, 0)))
        c.key(8, hips=dict(loc=(0.1, 0, -0.07), rot=(0, 7, 0)), leg_l=dict(rot=(-6, 0, 0)), leg_r=dict(rot=(30, 0, 0)), body=dict(rot=(13, 0, 4)))
        c.key(16, hips=dict(loc=(0.04, 0, 0.03), rot=(0, 2, 0)), leg_l=dict(rot=(10, 0, 0)), leg_r=dict(rot=(-20, 0, 0)), helmet=dict(rot=(4, 0, 2)))
        c.key(24, hips=dict(loc=(-0.07, 0, 0), rot=(0, -5, 0)), body=dict(rot=(10, 0, -3)), helmet=dict(rot=(2, 0, 4)), leg_l=dict(rot=(22, 0, 0)), leg_r=dict(rot=(-30, 0, 0)),
              arm_l=dict(rot=(-18, 0, 8)), arm_r=dict(rot=(10, 0, -6)), anchor=dict(rot=(12, 0, 0)), weed=dict(rot=(-6, 0, 0)))
        c.key(32, hips=dict(loc=(-0.1, 0, -0.07), rot=(0, -7, 0)), leg_r=dict(rot=(-6, 0, 0)), leg_l=dict(rot=(30, 0, 0)), body=dict(rot=(13, 0, -4)))
        c.key(40, hips=dict(loc=(-0.04, 0, 0.03), rot=(0, -2, 0)), leg_r=dict(rot=(10, 0, 0)), leg_l=dict(rot=(-20, 0, 0)), helmet=dict(rot=(4, 0, -2)))
    # Angriff: Anker über den Kopf und mit Wucht herunter
    with rig.clip("attack", 33, hit=18) as c:
        c.key(0, **rest)
        c.key(11, body=dict(rot=(-14, 0, -8)), helmet=dict(rot=(-10, 0, 0)), arm_r=dict(rot=(-175, 0, -14)), fore_r=dict(rot=(-20, 0, 0)), anchor=dict(rot=(-20, 0, 0)), arm_l=dict(rot=(30, 0, 20)), hips=dict(loc=(0, 0.1, 0)))
        c.key(14, arm_r=dict(rot=(-185, 0, -14)))
        c.key(18, body=dict(rot=(34, 0, 6)), helmet=dict(rot=(12, 0, 0)), arm_r=dict(rot=(-62, 0, 4)), fore_r=dict(rot=(-4, 0, 0)), anchor=dict(rot=(24, 0, 0)), arm_l=dict(rot=(-30, 0, 16)), hips=dict(loc=(0, -0.2, -0.1)))
        c.key(21, body=dict(rot=(30, 0, 6)), anchor=dict(rot=(10, 0, 0)), hips=dict(loc=(0, -0.18, -0.06)))
        c.key(33, **rest)
    with rig.clip("hit", 9) as c:
        c.key(0, **rest)
        c.key(3, body=dict(rot=(-10, 0, 5), scale=(1.05, 1.05, 0.96)), helmet=dict(rot=(-14, 0, 10)), arm_l=dict(rot=(-20, 0, 26)), arm_r=dict(rot=(-20, 0, -26)), hips=dict(loc=(0, 0.1, 0)))
        c.key(9, **rest)
    # Tod: wankt, sinkt auf die Knie, kippt nach vorn – der Helm scheppert auf den Boden
    with rig.clip("death", 42) as c:
        c.key(0, **rest)
        c.key(8, body=dict(rot=(-12, 0, 8)), helmet=dict(rot=(-16, 0, 14)), arm_l=dict(rot=(-40, 0, 40)), arm_r=dict(rot=(-30, 0, -30)), hips=dict(loc=(0, 0.1, 0)))
        c.key(18, root=dict(loc=(0, 0, -0.5), rot=(0, 0, 0)), leg_l=dict(rot=(-80, 0, 0)), leg_r=dict(rot=(-80, 0, 0)), body=dict(rot=(18, 0, -6)), helmet=dict(rot=(20, 0, -10)), arm_l=dict(rot=(10, 0, 20)), arm_r=dict(rot=(10, 0, -20)), anchor=dict(rot=(40, 0, 0)))
        c.key(22, root=dict(loc=(0, 0, -0.5), rot=(4, 0, 0)), body=dict(rot=(10, 0, 0)))
        c.key(31, root=dict(loc=(0, -0.2, 0.45), rot=(84, 0, 0)), leg_l=dict(rot=(-10, 0, 8)), leg_r=dict(rot=(-4, 0, -8)), body=dict(rot=(2, 0, 0)), helmet=dict(rot=(-18, 0, 20)),
              arm_l=dict(rot=(-150, 0, 30)), arm_r=dict(rot=(-130, 0, -40)), fore_r=dict(rot=(-10, 0, 0)), anchor=dict(rot=(0, 0, 0)), _i="LINEAR")
        c.key(34, root=dict(loc=(0, -0.2, 0.55), rot=(80, 0, 0)), helmet=dict(rot=(-8, 0, 24)))
        c.key(38, root=dict(loc=(0, -0.2, 0.45), rot=(84, 0, 0)), helmet=dict(rot=(-18, 0, 20)))
        c.key(42, root=dict(loc=(0, -0.2, 0.45), rot=(84, 0, 0)))
    # Ankerwurf (Baustein pull): ausholen, werfen – die Kette spannt sich –, dann holt er sie Hand über Hand ein
    with rig.clip("throw", 36, hit=15) as c:
        c.key(0, **rest)
        c.key(8, body=dict(rot=(-10, 0, -24)), helmet=dict(rot=(0, 0, 14)), arm_r=dict(rot=(40, 0, -20)), fore_r=dict(rot=(-30, 0, 0)), anchor=dict(loc=(0, 0, 0), rot=(0, 0, 0)), chain=HIDE, arm_l=dict(rot=(-50, 0, 10)), hips=dict(loc=(0, 0.12, 0)))
        c.key(13, body=dict(rot=(22, 0, 14)), helmet=dict(rot=(4, 0, -8)), arm_r=dict(rot=(-96, 0, 0)), fore_r=dict(rot=(0, 0, 0)), anchor=dict(loc=(0, 0, 0)), chain=HIDE, hips=dict(loc=(0, -0.14, -0.04)), _i="LINEAR")
        c.key(17, anchor=dict(loc=(0, 0, -5.2)), chain=dict(scale=(1, 1, 5.2)), arm_r=dict(rot=(-92, 0, 0)))
        c.key(22, anchor=dict(loc=(0, 0, -5.0)), chain=dict(scale=(1, 1, 5.0)), body=dict(rot=(4, 0, 6)), arm_l=dict(rot=(-80, 0, -20)), hips=dict(loc=(0, 0.05, 0)))
        c.key(31, anchor=dict(loc=(0, 0, -0.3)), chain=dict(scale=(1, 1, 0.3)), body=dict(rot=(-6, 0, -6)), arm_r=dict(rot=(-50, 0, -4)), arm_l=dict(rot=(-30, 0, 4)))
        c.key(36, **rest)
    rig.finish(icon_yaw=-28, icon_pitch=12)


# ================================================================= Kanonier-Skelett (Fernkämpfer)
def untote_kanonier():
    rig = Rig("untote_kanonier", role="ranged")
    HAT, COAT, COAT_D, SASH = "23262E", "2F4E96", "22355F", "D8343A"
    BOOT = "3A2A22"
    # ---- Becken mit roter Schärpe
    p = Part()
    p.ball(0.17, (0, 0, 0.95), BONE, scale=(1.35, 0.85, 0.75), subdiv=2)
    lathe(p, [(0.2, 0.98, SASH), (0.23, 1.04, SASH), (0.2, 1.1, SASH)], sides=8, sy=0.75)
    p.cone(0.06, 0.3, (0.2, -0.08, 0.88), SASH, r=rot(180, 12, 0), sides=4)                       # Schärpen-Ende
    rig.add("hips", p, pivot=(0, 0, 0.95))
    # ---- Brustkorb: Rückgrat, drei Rippenbögen, Schulterbalken, zerfetzte Rockschöße
    p = Part()
    capsule(p, (0, 0.02, 1.05), (0, 0, 1.58), 0.045, 0.04, BONE_D, sides=5)
    for i, (z, r) in enumerate(((1.2, 0.19), (1.33, 0.225), (1.46, 0.2))):
        p.torus(r, 0.03, (0, -0.02, z), BONE, seg=10, tseg=4)
    capsule(p, (-0.3, 0, 1.57), (0.3, 0, 1.57), 0.05, 0.05, BONE, sides=5)
    for s in (-1, 1):
        p.ball(0.085, (0.3 * s, 0, 1.6), "E8B33A", scale=(1.1, 1.0, 0.6), subdiv=1)                # Epauletten
    rig.add("chest", p, parent="hips", pivot=(0, 0, 1.02))
    p = Part()                                                                                    # Rockschöße (wehen)
    p.box((0.26, 0.04, 0.62), (0.15, 0.2, 1.2), COAT, r=rot(-10, 0, 6), bevel=0.0)
    p.box((0.24, 0.04, 0.5), (-0.15, 0.2, 1.26), COAT_D, r=rot(-10, 0, -6), bevel=0.0)
    p.cone(0.1, 0.24, (0.16, 0.26, 0.8), COAT, r=rot(170, 0, 0), sides=3)
    rig.add("coat", p, parent="chest", pivot=(0, 0.15, 1.55))
    # ---- Schädel mit Dreispitz
    p = Part()
    p.ball(0.2, (0, -0.02, 1.8), BONE, scale=(1.0, 1.05, 1.0), subdiv=2)
    p.box((0.2, 0.14, 0.1), (0, -0.1, 1.64), BONE, bevel=0.03, segs=1)                             # Oberkiefer
    for s in (-1, 1):
        p.ball(0.06, (0.08 * s, -0.185, 1.82), INK, scale=(1, 0.5, 1.15), subdiv=1)
    p.cone(0.03, 0.06, (0, -0.21, 1.73), INK, sides=3)
    p.box((0.17, 0.02, 0.035), (0, -0.175, 1.6), WHITE, bevel=0.0)                                 # Zahnreihe
    rig.add("skull", p, parent="chest", pivot=(0, 0, 1.62))
    p = Part()
    for s in (-1, 1):
        p.ball(0.028, (0.08 * s, -0.215, 1.82), "FFB03A", subdiv=1)
    rig.add("eyes", p, parent="skull", pivot=(0, -0.2, 1.82), glow=True, look=True)
    p = Part()
    p.box((0.19, 0.15, 0.07), (0, -0.09, 1.555), BONE_D, bevel=0.025, segs=1)
    p.box((0.16, 0.02, 0.03), (0, -0.165, 1.59), WHITE, bevel=0.0)
    rig.add("jaw", p, parent="skull", pivot=(0, 0.0, 1.6))
    p = Part()                                                                                    # Dreispitz: drei hochgeklappte Krempen, Goldborte, Feder
    lathe(p, [(0.4, 0.0, HAT), (0.45, 0.05, HAT), (0.35, 0.17, "E8B33A"), (0.31, 0.21, HAT), (0.19, 0.16, HAT)], sides=3, loc=(0, 0, 1.92), r=rot(0, 0, 90), cap=False)
    lathe(p, [(0.2, 0.0, HAT), (0.19, 0.14, HAT), (0.12, 0.2, HAT)], sides=8, loc=(0, 0, 1.92))
    p.ball(0.05, (0, -0.21, 2.03), BONE, subdiv=1)                                                 # Totenkopf-Abzeichen
    p.cone(0.06, 0.34, (0.16, 0.1, 2.16), SASH, r=rot(-24, 14, 0), sides=4)                        # Feder
    rig.add("hat", p, parent="skull", pivot=(0, 0, 1.94))
    # ---- linker Arm (frei), rechter Arm hält die Kanone auf der Schulter
    p = Part(); capsule(p, (0.32, 0, 1.56), (0.4, 0, 1.2), 0.04, 0.035, BONE, sides=5); p.ball(0.05, (0.4, 0, 1.2), BONE_D, subdiv=1)
    rig.add("arm_l", p, parent="chest", pivot=(0.32, 0, 1.56))
    p = Part(); capsule(p, (0.4, 0, 1.2), (0.42, -0.1, 0.88), 0.035, 0.03, BONE, sides=5); p.ball(0.07, (0.42, -0.12, 0.82), BONE_D, scale=(0.8, 1.0, 1.2), subdiv=1)
    rig.add("fore_l", p, parent="arm_l", pivot=(0.4, 0, 1.2))
    p = Part(); capsule(p, (-0.32, 0, 1.56), (-0.52, -0.06, 1.36), 0.04, 0.035, BONE, sides=5); p.ball(0.05, (-0.52, -0.06, 1.36), BONE_D, subdiv=1)
    rig.add("arm_r", p, parent="chest", pivot=(-0.32, 0, 1.56))
    p = Part(); capsule(p, (-0.52, -0.06, 1.36), (-0.44, -0.22, 1.62), 0.035, 0.03, BONE, sides=5); p.ball(0.065, (-0.43, -0.24, 1.66), BONE_D, subdiv=1)
    rig.add("fore_r", p, parent="arm_r", pivot=(-0.52, -0.06, 1.36))
    # ---- Kanone: schwarzes Rohr mit Goldringen, glimmende Lunte
    p = Part()
    lathe(p, [(0.07, 0.0, "E8B33A"), (0.13, 0.04, HAT), (0.14, 0.12, "E8B33A"), (0.125, 0.18, HAT), (0.105, 0.72, HAT), (0.13, 0.76, "E8B33A"), (0.135, 0.86, "E8B33A"), (0.085, 0.86, "0A0C10"), (0.08, 0.7, "0A0C10")],
          sides=10, loc=(-0.3, 0.42, 1.74), r=rot(96, 0, 0), cap=False)
    p.ball(0.075, (-0.3, 0.45, 1.74), "E8B33A", subdiv=1)
    rig.add("cannon", p, parent="chest", pivot=(-0.3, 0.0, 1.7))
    p = Part()
    p.ball(0.04, (-0.3, 0.33, 1.9), "FF8A2A", subdiv=1)
    rig.add("fuse", p, parent="cannon", pivot=(-0.3, 0.33, 1.9), glow=True)
    # ---- Beine: Oberschenkelknochen, Stulpenstiefel
    for nm, s in (("l", 1), ("r", -1)):
        p = Part(); capsule(p, (0.14 * s, 0, 0.9), (0.15 * s, -0.02, 0.5), 0.045, 0.04, BONE, sides=5); p.ball(0.06, (0.15 * s, -0.02, 0.5), BONE_D, subdiv=1)
        rig.add("thigh_" + nm, p, parent="hips", pivot=(0.14 * s, 0, 0.9))
        p = Part()
        lathe(p, [(0.075, 0.06, BOOT), (0.08, 0.3, BOOT), (0.12, 0.42, BOOT), (0.125, 0.46, "5A4032")], sides=7, loc=(0.15 * s, 0, 0.0))
        p.ball(0.1, (0.15 * s, -0.08, 0.06), BOOT, scale=(0.9, 1.7, 0.6), subdiv=1)
        rig.add("shin_" + nm, p, parent="thigh_" + nm, pivot=(0.15 * s, -0.02, 0.5))

    # ---------------------------------------------------------------- Clips
    rest = dict(root=dict(loc=(0, 0, 0), rot=(0, 0, 0)), hips=dict(loc=(0, 0, 0), rot=(0, 0, 0)), chest=dict(rot=(4, 0, 0), loc=(0, 0, 0)), skull=dict(rot=(0, 0, 0), loc=(0, 0, 0)), jaw=dict(rot=(0, 0, 0)),
                hat=dict(rot=(0, 0, 0), loc=(0, 0, 0)), arm_l=dict(rot=(0, 0, 0)), fore_l=dict(rot=(-12, 0, 0)), arm_r=dict(rot=(0, 0, 0)), fore_r=dict(rot=(0, 0, 0)),
                cannon=dict(rot=(0, 0, 0), loc=(0, 0, 0), scale=1.0), coat=dict(rot=(0, 0, 0)), thigh_l=dict(rot=(0, 0, 0)), shin_l=dict(rot=(0, 0, 0)), thigh_r=dict(rot=(0, 0, 0)), shin_r=dict(rot=(0, 0, 0)), fuse=dict(scale=1.0))
    with rig.clip("idle", 36, loop=True) as c:                       # klappert: Schädel wackelt, Kiefer klackt, die Lunte glimmt
        c.key(0, **rest)
        c.key(6, skull=dict(rot=(0, 0, 9)), jaw=dict(rot=(14, 0, 0)), fuse=dict(scale=1.5))
        c.key(10, jaw=dict(rot=(0, 0, 0)))
        c.key(14, skull=dict(rot=(3, 0, -7)), jaw=dict(rot=(12, 0, 0)), chest=dict(rot=(6, 0, 3)), arm_l=dict(rot=(8, 0, 0)), fuse=dict(scale=0.8))
        c.key(18, jaw=dict(rot=(0, 0, 0)))
        c.key(26, skull=dict(rot=(-4, 0, 3)), chest=dict(rot=(3, 0, -2)), coat=dict(rot=(5, 0, 0)), fuse=dict(scale=1.4))
    with rig.clip("walk", 24, loop=True, stride=1.35) as c:           # Stechschritt mit hohen Knien, die Kanone wippt
        c.key(0, hips=dict(loc=(0, 0, 0.0), rot=(0, 0, 4)), chest=dict(rot=(6, 0, -5)), thigh_l=dict(rot=(-46, 0, 0)), shin_l=dict(rot=(50, 0, 0)), thigh_r=dict(rot=(22, 0, 0)), shin_r=dict(rot=(10, 0, 0)),
              arm_l=dict(rot=(30, 0, 0)), fore_l=dict(rot=(-20, 0, 0)), skull=dict(rot=(0, 0, 4)), cannon=dict(rot=(-3, 0, 0)), coat=dict(rot=(14, 0, 0)), jaw=dict(rot=(6, 0, 0)))
        c.key(6, hips=dict(loc=(0, 0, 0.05)), thigh_l=dict(rot=(-14, 0, 0)), shin_l=dict(rot=(4, 0, 0)), thigh_r=dict(rot=(8, 0, 0)), shin_r=dict(rot=(40, 0, 0)), cannon=dict(rot=(3, 0, 0)), jaw=dict(rot=(0, 0, 0)))
        c.key(12, hips=dict(loc=(0, 0, 0.0), rot=(0, 0, -4)), chest=dict(rot=(6, 0, 5)), thigh_l=dict(rot=(22, 0, 0)), shin_l=dict(rot=(10, 0, 0)), thigh_r=dict(rot=(-46, 0, 0)), shin_r=dict(rot=(50, 0, 0)),
              arm_l=dict(rot=(-30, 0, 0)), skull=dict(rot=(0, 0, -4)), cannon=dict(rot=(-3, 0, 0)), coat=dict(rot=(4, 0, 0)), jaw=dict(rot=(6, 0, 0)))
        c.key(18, hips=dict(loc=(0, 0, 0.05)), thigh_r=dict(rot=(-14, 0, 0)), shin_r=dict(rot=(4, 0, 0)), thigh_l=dict(rot=(8, 0, 0)), shin_l=dict(rot=(40, 0, 0)), cannon=dict(rot=(3, 0, 0)), jaw=dict(rot=(0, 0, 0)))
    # Schuss: kniet nieder, richtet das Rohr nach oben, feuert (Rückstoß wirft ihn fast um), steht wieder auf
    kneel = dict(hips=dict(loc=(0, 0.05, -0.42)), thigh_l=dict(rot=(-88, 0, 0)), shin_l=dict(rot=(86, 0, 0)), thigh_r=dict(rot=(6, 0, 0)), shin_r=dict(rot=(84, 0, 0)))
    aim = dict(chest=dict(rot=(14, 0, 0)), skull=dict(rot=(-8, 0, 0)), arm_l=dict(rot=(-70, 0, -20)), fore_l=dict(rot=(-50, 0, 0)), **kneel)
    # Paket G2: „kneel“ = kniet zum Schuss (wird vor jedem Schuss gespielt), „attack“ beginnt kniend
    with rig.clip("kneel", 15) as c:
        c.key(0, **rest)
        c.key(6, hips=dict(loc=(0, 0.03, -0.2)), thigh_l=dict(rot=(-50, 0, 0)), shin_l=dict(rot=(50, 0, 0)), chest=dict(rot=(10, 0, 0)))
        c.key(12, **aim)
        c.key(15, **aim)
    with rig.clip("attack", 39, hit=13) as c:
        c.key(0, **aim)
        c.key(9, chest=dict(rot=(-6, 0, 0)), cannon=dict(rot=(-18, 0, 0), loc=(0, 0, 0), scale=1.0), skull=dict(rot=(2, 0, -10)), jaw=dict(rot=(0, 0, 0)), fuse=dict(scale=2.2))
        c.key(12, cannon=dict(rot=(-18, 0, 0), loc=(0, 0, 0), scale=(1.0, 1.0, 1.0)))
        c.key(14, chest=dict(rot=(-24, 0, 0)), cannon=dict(rot=(-30, 0, 0), loc=(0, 0.22, 0.02), scale=(1.25, 0.9, 1.25)), skull=dict(rot=(-16, 0, 0)), jaw=dict(rot=(30, 0, 0)), hat=dict(loc=(0, 0, 0.12)),
              arm_l=dict(rot=(-20, 0, 30)), coat=dict(rot=(-30, 0, 0)), fuse=dict(scale=0.3), hips=dict(loc=(0, 0.14, -0.42)), _i="LINEAR")
        c.key(20, chest=dict(rot=(2, 0, 0)), cannon=dict(rot=(-6, 0, 0), loc=(0, 0, 0), scale=1.0), skull=dict(rot=(4, 0, 0)), jaw=dict(rot=(0, 0, 0)), hat=dict(loc=(0, 0, 0)), coat=dict(rot=(10, 0, 0)), **kneel)
        c.key(26, **kneel)
        c.key(39, **rest)
    with rig.clip("hit", 9) as c:                                    # der Schädel dreht sich einmal um sich selbst
        c.key(0, **rest)
        c.key(3, chest=dict(rot=(-12, 0, 6)), skull=dict(rot=(0, 0, 120)), jaw=dict(rot=(24, 0, 0)), hat=dict(loc=(0, 0, 0.1)), arm_l=dict(rot=(-30, 0, 30)), hips=dict(loc=(0, 0.06, 0)), _i="LINEAR")
        c.key(7, skull=dict(rot=(0, 0, 350)), _i="LINEAR")
        c.key(9, root=dict(loc=(0, 0, 0), rot=(0, 0, 0)), hips=dict(loc=(0, 0, 0), rot=(0, 0, 0)), chest=dict(rot=(4, 0, 0)), skull=dict(rot=(0, 0, 360)), jaw=dict(rot=(0, 0, 0)), hat=dict(loc=(0, 0, 0)), arm_l=dict(rot=(0, 0, 0)))
    # Tod: fällt zu einem Knochenhaufen zusammen, die Kanone plumpst daneben, der Hut landet obenauf
    pile = dict(hips=dict(loc=(0, 0, -0.74), rot=(70, 0, 0)), chest=dict(loc=(0, -0.1, -0.2), rot=(40, 0, 30)), skull=dict(loc=(0.25, -0.5, -0.4), rot=(60, 0, 80)), jaw=dict(rot=(40, 0, 0)),
                hat=dict(loc=(-0.3, 0.5, 0.2), rot=(-50, 0, 0)), arm_l=dict(rot=(-80, 0, 70)), fore_l=dict(rot=(-90, 0, 0)), arm_r=dict(rot=(60, 0, -80)), fore_r=dict(rot=(-120, 0, 0)),
                cannon=dict(loc=(-0.25, -0.75, -0.2), rot=(-40, 0, 60), scale=1.0), coat=dict(rot=(-70, 0, 0)), thigh_l=dict(rot=(-100, 0, 40)), shin_l=dict(rot=(120, 0, 0)), thigh_r=dict(rot=(-80, 0, -50)), shin_r=dict(rot=(110, 0, 0)), fuse=dict(scale=0.1))
    with rig.clip("death", 36) as c:
        c.key(0, **rest)
        c.key(5, chest=dict(rot=(-14, 0, 0)), skull=dict(rot=(-20, 0, 0), loc=(0, 0, 0.12)), jaw=dict(rot=(40, 0, 0)), hat=dict(loc=(0, 0, 0.3)), hips=dict(loc=(0, 0, 0.05)))
        c.key(17, _i="LINEAR", **pile)
        c.key(20, hips=dict(loc=(0, 0, -0.7), rot=(70, 0, 0)), skull=dict(loc=(0.32, -0.62, -0.34), rot=(100, 0, 110)), cannon=dict(loc=(-0.25, -0.75, -0.14), rot=(-36, 0, 60)))
        c.key(24, skull=dict(loc=(0.36, -0.7, -0.4), rot=(140, 0, 130)), cannon=dict(loc=(-0.25, -0.75, -0.2), rot=(-40, 0, 60)), hips=dict(loc=(0, 0, -0.74), rot=(70, 0, 0)))
        c.key(36, skull=dict(loc=(0.36, -0.7, -0.4), rot=(140, 0, 130)))
    # Auftauchen (wenn er gerufen wird): der Knochenhaufen setzt sich klappernd zusammen
    with rig.clip("spawn", 30) as c:
        c.key(0, **pile)
        c.key(0, skull=dict(loc=(0.36, -0.7, -0.4), rot=(140, 0, 130)))
        c.key(8, skull=dict(loc=(0.2, -0.3, 0.3), rot=(40, 0, 60)), hat=dict(loc=(-0.3, 0.5, 0.2), rot=(-50, 0, 0)))
        c.key(20, root=dict(loc=(0, 0, 0)), hips=dict(loc=(0, 0, 0.08), rot=(0, 0, 0)), chest=dict(loc=(0, 0, 0), rot=(-8, 0, 0)), skull=dict(loc=(0, 0, 0.1), rot=(0, 0, -20)), jaw=dict(rot=(20, 0, 0)), hat=dict(loc=(0, 0, 0.5), rot=(0, 0, 0)),
              arm_l=dict(rot=(-30, 0, 20)), fore_l=dict(rot=(-12, 0, 0)), arm_r=dict(rot=(0, 0, 0)), fore_r=dict(rot=(0, 0, 0)), cannon=dict(loc=(0, 0, 0.2), rot=(0, 0, 0)), coat=dict(rot=(-20, 0, 0)),
              thigh_l=dict(rot=(0, 0, 0)), shin_l=dict(rot=(0, 0, 0)), thigh_r=dict(rot=(0, 0, 0)), shin_r=dict(rot=(0, 0, 0)), fuse=dict(scale=1.0))
        c.key(30, **rest)
    rig.finish(icon_yaw=-30, icon_pitch=12)


# ================================================================= Geisterqualle (Flieger)
def untote_qualle():
    rig = Rig("untote_qualle", role="air")
    BELL, BELL_L, PINK, TENT = "8FE6DC", "C8FFF4", "FF8FC8", "BFF7EE"
    # ---- Glocke (durchscheinend) mit hellem Saum
    p = Part()
    lathe(p, [(0.46, 0.94, BELL_L), (0.56, 1.02, BELL), (0.6, 1.16, BELL), (0.54, 1.34, BELL), (0.4, 1.48, BELL_L), (0.2, 1.57, BELL_L), (0.0, 1.6, BELL_L)], sides=14, cap=False)
    rig.add("bell", p, pivot=(0, 0, 1.1), ghost=True)
    # ---- leuchtender Kern, den man durch die Glocke sieht
    p = Part()
    p.ball(0.24, (0, 0, 1.24), PINK, scale=(1, 1, 0.85), subdiv=2)
    p.ball(0.1, (0.12, 0.05, 1.42), "FFD0EA", subdiv=1)
    rig.add("core", p, parent="bell", pivot=(0, 0, 1.24), glow=True)
    # ---- Gesicht: große freundlich-gruselige Augen, kleiner Mund
    p = Part()
    for s in (-1, 1):
        p.ball(0.1, (0.2 * s, -0.5, 1.2), "1B2B3A", scale=(1, 0.5, 1.2), subdiv=2)
    p.ball(0.055, (0, -0.565, 1.06), "1B2B3A", scale=(1.3, 0.5, 0.7), subdiv=1)
    rig.add("face", p, parent="bell", pivot=(0, -0.5, 1.2))
    p = Part()
    for s in (-1, 1):
        p.ball(0.04, (0.2 * s + 0.02, -0.555, 1.23), WHITE, scale=(1, 0.5, 1), subdiv=1)
    rig.add("glint", p, parent="face", pivot=(0, -0.55, 1.23), look=True)
    # ---- Kapitänsmütze, keck schief
    p = MPart(T(0.03, -0.02, 1.5) @ rot(-10, 0, -8))
    lathe(p, [(0.25, 0.0, "22355F"), (0.26, 0.07, "22355F"), (0.3, 0.1, WHITE), (0.39, 0.18, WHITE), (0.36, 0.25, WHITE), (0.0, 0.28, WHITE)], sides=10)
    p.ball(0.2, (0, -0.24, 0.03), INK, scale=(1.1, 0.9, 0.16), subdiv=1)                         # Schirm
    p.ball(0.06, (0, -0.27, 0.12), GOLD_C, scale=(1, 0.5, 1), subdiv=1)                          # Abzeichen
    rig.add("hat", p, parent="bell", pivot=(0.03, 0, 1.52))
    # ---- sechs Tentakel aus je zwei Gliedern
    for i in range(6):
        a = math.radians(i * 60 + 30)
        x, y = math.cos(a) * 0.34, math.sin(a) * 0.34
        c1, c2 = (TENT, PINK) if i % 2 == 0 else (PINK, TENT)
        p = Part(); capsule(p, (x, y, 0.98), (x * 1.08, y * 1.08, 0.56), 0.06, 0.045, c1, sides=5)
        rig.add("t%da" % i, p, parent="bell", pivot=(x, y, 0.98))
        p = Part(); capsule(p, (x * 1.08, y * 1.08, 0.56), (x * 1.0, y * 1.0, 0.12), 0.045, 0.018, c2, sides=5)
        rig.add("t%db" % i, p, parent="t%da" % i, pivot=(x * 1.08, y * 1.08, 0.56))
    # ---- zwei krause Mundarme in der Mitte
    p = Part()
    lathe(p, [(0.02, 0.2, BELL_L), (0.09, 0.4, BELL_L), (0.05, 0.56, PINK), (0.11, 0.74, BELL_L), (0.07, 0.96, BELL_L)], sides=6, loc=(0.06, 0, 0), cap=False)
    lathe(p, [(0.02, 0.32, PINK), (0.08, 0.5, PINK), (0.05, 0.66, BELL_L), (0.09, 0.82, PINK), (0.06, 0.96, PINK)], sides=6, loc=(-0.08, 0.04, 0), cap=False)
    rig.add("arms", p, parent="bell", pivot=(0, 0, 0.96))

    # ---------------------------------------------------------------- Clips
    def tent(c, amp_a, amp_b, base_a=0.0, base_b=0.0, n=1, spread=0.0):
        """Alle Tentakel schwingen nach außen/innen, reihum versetzt."""
        for i in range(6):
            a = math.radians(i * 60 + 30)
            ax = (-math.sin(a), math.cos(a))                 # Achse quer zur Richtung nach außen
            ph = i / 6.0
            c.wave("t%da" % i, rot=(ax[0] * amp_a, ax[1] * amp_a, 0), n=n, phase=ph, base_rot=(ax[0] * (base_a + spread), ax[1] * (base_a + spread), 0))
            c.wave("t%db" % i, rot=(ax[0] * amp_b, ax[1] * amp_b, 0), n=n, phase=ph + 0.25, base_rot=(ax[0] * base_b, ax[1] * base_b, 0))

    def tent_key(c, f, a, b):
        for i in range(6):
            an = math.radians(i * 60 + 30)
            ax = (-math.sin(an), math.cos(an))
            c.key(f, **{"t%da" % i: dict(rot=(ax[0] * a, ax[1] * a, 0)), "t%db" % i: dict(rot=(ax[0] * b, ax[1] * b, 0))})

    with rig.clip("idle", 36, loop=True) as c:                       # pulsiert gemächlich, Tentakel wehen
        c.wave("bell", scale=(0.06, 0.06, -0.07), loc=(0, 0, 0.04))
        c.wave("core", scale=(0.1, 0.1, 0.1), phase=0.3)
        c.wave("hat", rot=(4, 0, 3), phase=0.2)
        c.wave("arms", rot=(5, 4, 0), phase=0.4)
        tent(c, 10, 14)
    with rig.clip("walk", 30, loop=True, stride=1.5) as c:           # Schwimmstoß: zusammenziehen, vorschnellen, treiben lassen
        c.key(0, bell=dict(scale=(1.12, 1.12, 0.86), rot=(14, 0, 0), loc=(0, 0, 0)), hat=dict(rot=(0, 0, 0)), core=dict(scale=0.95), arms=dict(rot=(10, 0, 0)))
        c.key(8, bell=dict(scale=(0.84, 0.84, 1.18), rot=(22, 0, 0), loc=(0, 0, 0.14)), hat=dict(rot=(-8, 0, 0)), core=dict(scale=1.2), arms=dict(rot=(30, 0, 0)))
        c.key(18, bell=dict(scale=(1.02, 1.02, 0.98), rot=(16, 0, 0), loc=(0, 0, 0.08)), hat=dict(rot=(4, 0, 0)), core=dict(scale=1.0), arms=dict(rot=(16, 0, 0)))
        tent_key(c, 0, 26, 10)
        tent_key(c, 8, -12, -22)
        tent_key(c, 18, 8, 12)
    with rig.clip("attack", 18, hit=8) as c:                         # zwei vordere Tentakel peitschen nach vorn
        c.key(0, bell=dict(rot=(0, 0, 0), scale=1.0), core=dict(scale=1.0))
        tent_key(c, 0, 0, 0)
        c.key(5, bell=dict(rot=(-16, 0, 0), scale=(1.08, 1.08, 0.92)), core=dict(scale=1.3), t4a=dict(rot=(40, 0, 0)), t4b=dict(rot=(30, 0, 0)), t5a=dict(rot=(40, 0, 0)), t5b=dict(rot=(30, 0, 0)))
        c.key(8, bell=dict(rot=(24, 0, 0), scale=(0.92, 0.92, 1.1)), core=dict(scale=1.6), t4a=dict(rot=(-80, 0, 0)), t4b=dict(rot=(-30, 0, 0)), t5a=dict(rot=(-80, 0, 0)), t5b=dict(rot=(-30, 0, 0)))
        c.key(11, t4a=dict(rot=(-60, 0, 0)), t5a=dict(rot=(-60, 0, 0)))
        c.key(18, bell=dict(rot=(0, 0, 0), scale=1.0), core=dict(scale=1.0))
        tent_key(c, 18, 0, 0)
    with rig.clip("hit", 9) as c:                                    # wird platt gedrückt und federt zurück
        c.key(0, bell=dict(scale=1.0, loc=(0, 0, 0), rot=(0, 0, 0)), hat=dict(loc=(0, 0, 0)))
        c.key(3, bell=dict(scale=(1.3, 1.3, 0.6), loc=(0, 0.1, -0.05), rot=(-10, 0, 0)), hat=dict(loc=(0, 0, 0.16)))
        c.key(6, bell=dict(scale=(0.92, 0.92, 1.1)), hat=dict(loc=(0, 0, 0)))
        c.key(9, bell=dict(scale=1.0, loc=(0, 0, 0), rot=(0, 0, 0)))
    with rig.clip("death", 36) as c:                                 # die Luft ist raus: sackt zusammen, die Mütze segelt hinterher
        c.key(0, bell=dict(scale=1.0, loc=(0, 0, 0), rot=(0, 0, 0)), core=dict(scale=1.0), hat=dict(loc=(0, 0, 0), rot=(0, 0, 0)), arms=dict(scale=1.0))
        tent_key(c, 0, 0, 0)
        c.key(5, bell=dict(scale=(1.2, 1.2, 1.15), loc=(0, 0, 0.12)), core=dict(scale=1.7), hat=dict(loc=(0, 0, 0.25), rot=(0, 0, 0)))
        tent_key(c, 5, -30, -20)
        c.key(16, bell=dict(scale=(1.35, 1.35, 0.22), loc=(0, 0, -0.98), rot=(0, 0, 30)), core=dict(scale=0.3), hat=dict(loc=(0, 0.1, 1.4), rot=(20, 0, 60)), arms=dict(scale=(1.5, 1.5, 0.1)))
        tent_key(c, 16, 70, 10)
        c.key(28, hat=dict(loc=(0.1, -0.1, 0.25), rot=(-8, 0, 200)))
        c.key(36, bell=dict(scale=(1.4, 1.4, 0.16), loc=(0, 0, -0.99), rot=(0, 0, 30)), hat=dict(loc=(0.1, -0.1, 0.2), rot=(0, 0, 220)))
        tent_key(c, 36, 74, 12)
    with rig.clip("zap", 21, hit=10) as c:                           # Stromschlag: zieht sich zusammen und entlädt sich, Tentakel sternförmig
        c.key(0, bell=dict(scale=1.0, loc=(0, 0, 0)), core=dict(scale=1.0), hat=dict(loc=(0, 0, 0)))
        tent_key(c, 0, 0, 0)
        c.key(7, bell=dict(scale=(0.78, 0.78, 0.86), loc=(0, 0, -0.06)), core=dict(scale=0.7), hat=dict(loc=(0, 0, 0)))
        tent_key(c, 7, 28, 30)
        c.key(10, bell=dict(scale=(1.3, 1.3, 1.1), loc=(0, 0, 0.1)), core=dict(scale=2.3), hat=dict(loc=(0, 0, 0.3)), _i="LINEAR")
        tent_key(c, 10, -78, -10)
        c.key(13, bell=dict(scale=(1.22, 1.22, 1.05)), core=dict(scale=1.9))
        tent_key(c, 14, -70, 20)
        c.key(21, bell=dict(scale=1.0, loc=(0, 0, 0)), core=dict(scale=1.0), hat=dict(loc=(0, 0, 0)))
        tent_key(c, 21, 0, 0)
    rig.finish(icon_yaw=-24, icon_pitch=8)


# ================================================================= Krabbenpanzer (Sonderling)
def untote_krabbe():
    # yaw=90: Die Krabbe ist mit dem Gesicht nach vorn gebaut, läuft im Spiel aber seitwärts.
    rig = Rig("untote_krabbe", role="special", yaw=90)
    SHELL, SHELL_D, SHELL_L = "E2522E", "B8381E", "F58A5A"
    WOODC, WOODD, GOLDB = "A9622F", "7A4522", "F5C02E"
    # ---- Krabbenkörper (flach, rot) – darauf sitzt die Schatzkiste
    p = Part()
    p.ball(0.5, (0, 0, 0.4), SHELL, scale=(1.2, 0.85, 0.5), subdiv=2)
    p.ball(0.3, (0, -0.2, 0.33), SHELL_L, scale=(1.3, 0.8, 0.5), subdiv=1)                       # heller Bauch
    p.ball(0.07, (0, -0.42, 0.3), "3A0F18", scale=(1.6, 0.5, 0.6), subdiv=1)                     # Mund
    rig.add("body", p, pivot=(0, 0, 0.4))
    # ---- Kiste: Holz mit Goldbeschlägen, Seepocken, Algen
    p = Part()
    p.box((1.0, 0.72, 0.36), (0, 0.04, 0.74), WOODC, bevel=0.05, segs=1)
    for x in (-0.36, 0.36):
        p.box((0.1, 0.76, 0.4), (x, 0.04, 0.74), GOLDB, bevel=0.02, segs=1)
    p.cone(0.07, 0.12, (0.2, -0.34, 0.8), "E9E3D0", r=rot(70, 0, 0), sides=5)
    p.cone(0.05, 0.09, (-0.14, -0.34, 0.68), "D6CFBA", r=rot(80, 0, 0), sides=5)
    seaweed(p, (0.5, 0.2, 0.9), (0.62, 0.3, 0.42), 0.07)
    rig.add("chest", p, parent="body", pivot=(0, 0.04, 0.56))
    p = Part()                                                                                    # Deckel (hinten angeschlagen)
    lathe(p, [(0.36, -0.5, WOODD), (0.37, -0.42, GOLDB), (0.38, -0.3, WOODC), (0.38, 0.3, GOLDB), (0.37, 0.42, WOODD), (0.36, 0.5, WOODD)],
          sides=10, loc=(0, 0.04, 0.92), r=rot(0, 90, 0), sy=0.55)
    p.box((0.16, 0.08, 0.2), (0, -0.34, 0.95), GOLDB, bevel=0.03, segs=1)                         # Schloss
    p.ball(0.035, (0, -0.39, 0.93), INK, subdiv=1)
    star(p, (-0.2, 0.0, 1.12), 0.13, "F08A3A", 0.06, r=rot(10, -20, 0))                           # Seestern
    rig.add("lid", p, parent="chest", pivot=(0, 0.4, 0.92))
    p = Part()                                                                                    # Goldschatz, der unter dem Deckel hervorblitzt
    p.box((0.86, 0.6, 0.08), (0, 0.04, 0.9), GOLDB, bevel=0.03, segs=1)
    p.ball(0.08, (0.2, -0.1, 0.94), "FFE56A", scale=(1, 1, 0.5), subdiv=1)
    p.ball(0.08, (-0.15, 0.1, 0.94), "FFE56A", scale=(1, 1, 0.5), subdiv=1)
    rig.add("gold", p, parent="chest", pivot=(0, 0.04, 0.9), glow=True)
    # ---- Stielaugen, die zwischen Kiste und Körper hervorlugen
    p = Part()
    for s in (-1, 1):
        capsule(p, (0.16 * s, -0.36, 0.5), (0.2 * s, -0.5, 0.74), 0.04, 0.035, SHELL_D, sides=5)
        p.ball(0.1, (0.2 * s, -0.52, 0.8), WHITE, subdiv=2)
    rig.add("eyes", p, parent="body", pivot=(0, -0.36, 0.5))
    p = Part()
    for s in (-1, 1):
        p.ball(0.05, (0.2 * s, -0.6, 0.81), INK, scale=(1, 0.5, 1), subdiv=1)
    rig.add("pupils", p, parent="eyes", pivot=(0, -0.58, 0.81), look=True)
    # ---- Scheren: die große (rechts, -X) führt beim Seitwärtslauf; jede mit beweglichem Finger
    for nm, s, k in (("l", 1, 0.8), ("r", -1, 1.25)):
        p = Part()
        capsule(p, (0.5 * s, -0.22, 0.4), (0.78 * s, -0.46, 0.5), 0.08, 0.07, SHELL_D, sides=6)
        p.ball(0.2 * k, (0.86 * s, -0.56, 0.52), SHELL, scale=(1.0, 1.25, 0.8), subdiv=2)
        p.cone(0.1 * k, 0.34 * k, (0.9 * s, -0.86 * (0.9 + 0.1 * k), 0.46), SHELL_L, r=rot(96, 0, 0), sides=5)   # fester Finger
        rig.add("claw_" + nm, p, parent="body", pivot=(0.5 * s, -0.22, 0.4))
        p = Part()
        p.cone(0.09 * k, 0.36 * k, (0.86 * s, -0.84 * (0.9 + 0.1 * k), 0.62), SHELL, r=rot(84, 0, 0), sides=5)   # beweglicher Finger
        rig.add("pin_" + nm, p, parent="claw_" + nm, pivot=(0.86 * s, -0.62, 0.6))
    # ---- sechs Beine (je ein geknicktes Teil)
    for i, y in enumerate((-0.12, 0.1, 0.3)):
        for nm, s in (("l", 1), ("r", -1)):
            p = Part()
            capsule(p, (0.48 * s, y, 0.38), (0.84 * s, y * 1.3, 0.52), 0.065, 0.055, SHELL_D, sides=5)
            lathe(p, [(0.055, 0.0, SHELL), (0.04, 0.3, SHELL), (0.012, 0.55, SHELL_L)], sides=5, loc=(0.84 * s, y * 1.3, 0.52), r=face_to((0.2 * s, 0.03 * (i - 1), -0.52)))
            rig.add("leg_%s%d" % (nm, i), p, parent="body", pivot=(0.48 * s, y, 0.38))

    # ---------------------------------------------------------------- Clips
    LEGS = ["leg_%s%d" % (nm, i) for nm in ("l", "r") for i in range(3)]
    rest = dict(root=dict(loc=(0, 0, 0), rot=(0, 0, 0)), body=dict(loc=(0, 0, 0), rot=(0, 0, 0)), chest=dict(rot=(0, 0, 0), loc=(0, 0, 0)), lid=dict(rot=(0, 0, 0)), eyes=dict(rot=(0, 0, 0), scale=1.0, loc=(0, 0, 0)),
                claw_l=dict(rot=(0, 0, 0), scale=1.0), claw_r=dict(rot=(0, 0, 0), scale=1.0), pin_l=dict(rot=(0, 0, 0)), pin_r=dict(rot=(0, 0, 0)), gold=dict(scale=1.0))
    for l in LEGS:
        rest[l] = dict(rot=(0, 0, 0), scale=1.0)
    with rig.clip("idle", 36, loop=True) as c:                       # lugt umher, schnappt mit der Schere, der Deckel hebt sich
        c.key(0, **rest)
        c.key(8, eyes=dict(rot=(0, 0, 22)), lid=dict(rot=(-12, 0, 0)), body=dict(loc=(0, 0, 0.03)), pin_r=dict(rot=(-30, 0, 0)))
        c.key(12, pin_r=dict(rot=(0, 0, 0)))
        c.key(15, pin_r=dict(rot=(-30, 0, 0)))
        c.key(18, eyes=dict(rot=(0, 0, -20)), lid=dict(rot=(-3, 0, 0)), body=dict(loc=(0, 0, 0)), pin_r=dict(rot=(0, 0, 0)), claw_l=dict(rot=(0, 0, 14)))
        c.key(27, eyes=dict(rot=(-10, 0, 0)), lid=dict(rot=(-16, 0, 0)), pin_l=dict(rot=(-34, 0, 0)), claw_l=dict(rot=(0, 0, 0)))
        c.key(31, pin_l=dict(rot=(0, 0, 0)))
    # Seitwärtsgang: die Beine greifen reihum zur Seite, der Körper wippt und kippt in Laufrichtung
    with rig.clip("walk", 18, loop=True, stride=1.1) as c:
        for i in range(3):
            c.wave("leg_r%d" % i, rot=(0, 26, 12), phase=i / 3.0)
            c.wave("leg_l%d" % i, rot=(0, 26, -12), phase=i / 3.0 + 0.5)
        c.wave("body", loc=(0, 0, 0.035), rot=(0, 0, 0), n=2, base_rot=(0, -7, 0))
        c.wave("chest", rot=(0, 3, 0), n=2, phase=0.3)
        c.wave("lid", rot=(5, 0, 0), n=2, base_rot=(-6, 0, 0), phase=0.5)
        c.wave("eyes", rot=(0, 0, 6), base_rot=(0, 0, 24))
        c.key(0, claw_r=dict(rot=(0, -14, -20)), claw_l=dict(rot=(0, 0, 10)), pin_r=dict(rot=(-18, 0, 0)))
    with rig.clip("attack", 15, hit=7) as c:                         # die große Schere schnellt zur Seite und kneift zu
        c.key(0, **rest)
        c.key(4, body=dict(rot=(0, 10, 0), loc=(0.08, 0, 0)), claw_r=dict(rot=(0, 20, 30), scale=1.0), pin_r=dict(rot=(-48, 0, 0)), eyes=dict(rot=(0, 0, 30)), lid=dict(rot=(-14, 0, 0)))
        c.key(7, body=dict(rot=(0, -14, 0), loc=(-0.2, 0, 0)), claw_r=dict(rot=(0, -10, -64), scale=1.25), pin_r=dict(rot=(6, 0, 0)), lid=dict(rot=(0, 0, 0)))
        c.key(10, claw_r=dict(rot=(0, -6, -56), scale=1.15), pin_r=dict(rot=(0, 0, 0)))
        c.key(15, **rest)
    with rig.clip("hit", 9) as c:
        c.key(0, **rest)
        c.key(3, body=dict(loc=(0, 0.06, 0.1), rot=(-8, 0, 0)), lid=dict(rot=(-26, 0, 0)), eyes=dict(scale=(1, 1, 1.3)), claw_l=dict(rot=(0, 0, 30)), claw_r=dict(rot=(0, 0, -30)))
        c.key(9, **rest)
    # Tod: purzelt auf den Rücken, die Beine zappeln und rollen sich ein, der Deckel klappt auf – Gold!
    with rig.clip("death", 36) as c:
        c.key(0, **rest)
        c.key(6, root=dict(loc=(0, 0, 0.5), rot=(0, 60, 0)), lid=dict(rot=(-20, 0, 0)))
        flip = dict(root=dict(loc=(0, 0, 1.2), rot=(0, 180, 0)))
        c.key(13, lid=dict(rot=(-110, 0, 0)), eyes=dict(rot=(30, 0, 0)), gold=dict(scale=1.0), **flip)
        for i, l in enumerate(LEGS):
            s = 1 if l.startswith("leg_l") else -1
            c.key(13, **{l: dict(rot=(0, -30 * s, 0))})
            c.key(18 + (i % 3), **{l: dict(rot=(0, 20 * s, 0))})
            c.key(24 + (i % 3), **{l: dict(rot=(0, -20 * s, 0))})
            c.key(36, **{l: dict(rot=(0, 46 * s, 0))})
        c.key(18, root=dict(loc=(0, 0, 1.27), rot=(0, 174, 0)), claw_l=dict(rot=(0, 0, 40)), claw_r=dict(rot=(0, 0, -40)))
        c.key(24, lid=dict(rot=(-124, 0, 0)), **flip)
        c.key(36, claw_l=dict(rot=(0, 30, 60)), claw_r=dict(rot=(0, -30, -60)), lid=dict(rot=(-124, 0, 0)), **flip)
    # Rückzug in die Kiste (Baustein shell): Beine, Scheren und Augen verschwinden, die Kiste plumpst zu Boden, Deckel zu
    with rig.clip("hide", 12) as c:
        c.key(0, **rest)
        tuck = dict(body=dict(loc=(0, 0, -0.24)), eyes=dict(scale=0.05, loc=(0, 0.3, -0.1)), claw_l=dict(rot=(0, 0, 70), scale=0.3), claw_r=dict(rot=(0, 0, -70), scale=0.3), lid=dict(rot=(4, 0, 0)), chest=dict(loc=(0, 0, -0.12)))
        for l in LEGS:
            s = 1 if l.startswith("leg_l") else -1
            tuck[l] = dict(rot=(0, 50 * s, 0), scale=0.3)
        c.key(3, lid=dict(rot=(-30, 0, 0)), body=dict(loc=(0, 0, 0.08)))
        c.key(8, **tuck)
        c.key(10, chest=dict(loc=(0, 0, -0.08)))
        c.key(12, **tuck)
    rig.finish(icon_yaw=-120, icon_pitch=18)


# ================================================================= Boss: Kapitän Glibber (echte Figur mit Objekt-Animationen)
def boss_untote():
    rig = Rig("boss_untote", role="boss")
    COAT, COAT_D, GOLDB = "2A3F7E", "1C2B58", "F5C02E"
    HAT = "1E2028"
    rig.node("hips", pivot=(0, 0, 1.7))
    # ---- langer Kapitänsrock (unten), Gürtel mit Schnalle
    p = Part()
    lathe(p, [(1.0, 0.95, GOLDB), (0.98, 1.03, COAT_D), (0.82, 1.5, COAT), (0.72, 1.86, "3A2A22"), (0.74, 2.0, "3A2A22")], sides=16, sy=0.8)
    p.box((0.34, 0.1, 0.26), (0, -0.6, 1.93), GOLDB, bevel=0.04, segs=1)
    rig.add("skirt", p, parent="hips", pivot=(0, 0, 1.9))
    # ---- Rumpf: tonnenförmig, Goldknöpfe, weißes Halstuch, Epauletten
    p = Part()
    lathe(p, [(0.72, 1.9, COAT), (0.96, 2.25, COAT), (1.02, 2.75, COAT), (0.9, 3.1, COAT_D), (0.55, 3.32, WHITE), (0.34, 3.4, SKIN_D)], sides=16, sy=0.82)
    for i in range(4):
        for s in (-1, 1):
            p.ball(0.07, (0.2 * s, -0.78 - 0.04 * math.sin(i * 0.9), 2.2 + i * 0.27), GOLDB, subdiv=1)
    for s in (-1, 1):
        lathe(p, [(0.3, 0.0, GOLDB), (0.34, 0.06, GOLDB), (0.2, 0.14, GOLDB)], sides=10, loc=(0.92 * s, 0, 3.12))
        for k in range(5):
            a = math.radians(k * 36 - 72)
            p.cone(0.05, 0.22, (0.92 * s + math.sin(a) * 0.3 * s, -math.cos(a) * 0.3, 3.02), GOLDB, r=rot(180, 0, 0), sides=4)
    p.box((0.5, 0.16, 0.5), (0, -0.74, 3.0), WHITE, r=rot(-10, 0, 0), bevel=0.07, segs=1)                     # Halstuch
    rig.add("torso", p, parent="hips", pivot=(0, 0, 1.9))
    # ---- Kopf: aufgedunsen, Augenklappe, ein Glühauge, Unterbiss
    p = Part()
    p.ball(0.56, (0, -0.04, 3.82), SKIN, scale=(1.0, 0.95, 0.94), subdiv=3)
    p.ball(0.16, (0.0, -0.56, 3.78), SKIN_D, scale=(1.0, 0.8, 0.9), subdiv=1)                                  # Knollennase
    p.ball(0.17, (0.22, -0.5, 3.95), WHITE, scale=(1, 0.6, 1), subdiv=2)                                       # Auge
    p.ball(0.18, (-0.22, -0.5, 3.95), INK, scale=(1, 0.4, 1), subdiv=1)                                        # Augenklappe
    p.torus(0.555, 0.03, (0, -0.03, 3.98), INK, r=rot(12, 14, 0), seg=18, tseg=4)
    for s in (-1, 1):
        p.ball(0.12, (0.54 * s, 0.0, 3.82), SKIN_D, scale=(0.5, 1, 1.3), subdiv=1)
    p.box((0.5, 0.1, 0.1), (0, -0.5, 3.56), "3A1A24", bevel=0.0)
    rig.add("head", p, parent="torso", pivot=(0, 0, 3.36))
    p = Part()
    p.ball(0.075, (0.22, -0.6, 3.95), "9DFF6A", scale=(1, 0.5, 1), subdiv=1)
    rig.add("eye", p, parent="head", pivot=(0.22, -0.58, 3.95), glow=True)
    p = Part()                                                                                                # Unterkiefer mit Hauern
    p.ball(0.34, (0, -0.26, 3.5), SKIN_D, scale=(1.05, 0.9, 0.45), subdiv=2)
    for s in (-1, 1):
        p.cone(0.06, 0.2, (0.2 * s, -0.5, 3.62), BONE, sides=5)
    p.cone(0.05, 0.13, (0.0, -0.55, 3.58), BONE, sides=5)
    rig.add("jaw", p, parent="head", pivot=(0, 0.0, 3.52))
    p = Part()                                                                                                # Bart aus Algen
    for i, (x, l, cc) in enumerate(((-0.28, 0.7, WEED), (-0.14, 0.95, WEED_L), (0.0, 1.1, WEED), (0.14, 0.9, WEED_L), (0.28, 0.72, WEED))):
        seaweed(p, (x, -0.5, 3.42), (x * 1.2, -0.74, 3.42 - l), 0.11, cc, sides=5)
    rig.add("beard", p, parent="jaw", pivot=(0, -0.45, 3.42))
    # ---- Zweispitz quer, mit Goldborte, Totenkopf und roter Feder
    p = Part()
    p.ball(0.7, (0, 0, 4.42), HAT, scale=(1.45, 0.42, 0.62), subdiv=2)
    lathe(p, [(0.58, 4.22, GOLDB), (0.6, 4.3, HAT)], sides=14, sy=0.7, cap=False)
    p.ball(0.14, (0, -0.3, 4.5), BONE, subdiv=1)
    capsule(p, (-0.2, -0.3, 4.36), (0.2, -0.3, 4.64), 0.035, 0.035, BONE, sides=4)
    capsule(p, (0.2, -0.3, 4.36), (-0.2, -0.3, 4.64), 0.035, 0.035, BONE, sides=4)
    p.cone(0.13, 0.8, (0.7, 0.1, 4.95), "D8343A", r=rot(-16, 30, 0), sides=5)
    rig.add("hat", p, parent="head", pivot=(0, 0, 4.25))
    # ---- linker Arm mit Steuerrad-Schild
    p = Part(); capsule(p, (1.0, 0, 3.05), (1.3, -0.05, 2.4), 0.3, 0.26, COAT, sides=10)
    rig.add("arm_l", p, parent="torso", pivot=(0.98, 0, 3.05))
    p = Part()
    capsule(p, (1.3, -0.05, 2.4), (1.3, -0.5, 2.0), 0.25, 0.22, COAT_D, sides=10)
    lathe(p, [(0.27, 0.0, GOLDB), (0.27, 0.12, GOLDB)], sides=10, loc=(1.3, -0.42, 2.07), r=face_to((0, -0.45, -0.4)), cap=False)
    p.ball(0.27, (1.3, -0.6, 1.92), SKIN_D, subdiv=2)
    rig.add("fore_l", p, parent="arm_l", pivot=(1.3, -0.05, 2.4))
    p = Part()                                                                                                # Steuerrad
    wm = T(1.3, -0.95, 1.95) @ rot(90, 0, 0)
    p.torus(0.72, 0.085, (0, 0, 0), WOOD_C, r=wm, seg=20, tseg=6)
    p.cyl(0.2, 0.2, (0, 0, 0), WOOD_DC, r=wm, sides=10, bevel=0.03, segs=1)
    p.cyl(0.1, 0.24, (0, 0, 0), GOLDB, r=wm, sides=8)
    for i in range(8):
        m2 = wm @ rot(0, 0, i * 45)
        p.cyl(0.05, 0.98, (0, 0, 0), WOOD_C, r=m2 @ T(0, 0.5, 0) @ rot(90, 0, 0), sides=6)
        p.ball(0.085, (0, 0, 0), WOOD_DC, r=m2 @ T(0, 1.0, 0), scale=(1, 1.3, 1), subdiv=1)
    rig.add("wheel", p, parent="fore_l", pivot=(1.3, -0.95, 1.95))
    # ---- rechter Arm mit Entersäbel
    p = Part(); capsule(p, (-1.0, 0, 3.05), (-1.32, 0, 2.4), 0.3, 0.26, COAT, sides=10)
    rig.add("arm_r", p, parent="torso", pivot=(-0.98, 0, 3.05))
    p = Part()
    capsule(p, (-1.32, 0, 2.4), (-1.36, -0.25, 1.85), 0.25, 0.22, COAT_D, sides=10)
    lathe(p, [(0.27, 0.0, GOLDB), (0.27, 0.12, GOLDB)], sides=10, loc=(-1.355, -0.2, 1.96), r=face_to((-0.04, -0.25, -0.55)), cap=False)
    p.ball(0.27, (-1.37, -0.3, 1.74), SKIN_D, subdiv=2)
    rig.add("fore_r", p, parent="arm_r", pivot=(-1.32, 0, 2.4))
    p = Part()                                                                                                # Säbel: breite, gebogene Klinge
    sm = T(-1.37, -0.32, 1.74) @ rot(-70, 0, 0)
    p.cyl(0.07, 0.4, (0, 0, 0), WOOD_DC, r=sm, sides=6)
    p.torus(0.2, 0.04, (0, 0, 0), GOLDB, r=sm @ T(0, -0.1, 0.12) @ rot(0, 90, 0), seg=10, tseg=4)
    for i in range(5):
        p.box((0.34 - i * 0.035, 0.07, 0.42), (0, 0, 0), "C9D2E0", r=sm @ T(0, -0.02 - i * i * 0.022, 0.42 + i * 0.36) @ rot(-6 * i, 0, 0), bevel=0.0)
    p.cone(0.13, 0.34, (0, 0, 0), "C9D2E0", r=sm @ T(0, -0.42, 2.18) @ rot(-34, 0, 0) @ S(1.0, 0.3, 1.0), sides=4)
    rig.add("sword", p, parent="fore_r", pivot=(-1.37, -0.32, 1.74))
    # ---- Beine: Stulpenstiefel und Holzbein
    p = Part()
    capsule(p, (0.42, 0, 1.7), (0.44, 0, 0.9), 0.3, 0.26, "E8E2D0", sides=10)
    lathe(p, [(0.27, 0.12, INK), (0.28, 0.7, INK), (0.36, 0.9, INK), (0.38, 0.98, GOLDB)], sides=10, loc=(0.44, 0, 0))
    p.ball(0.3, (0.44, -0.22, 0.16), INK, scale=(0.95, 1.6, 0.55), subdiv=2)
    rig.add("leg_l", p, parent="hips", pivot=(0.42, 0, 1.75))
    p = Part()
    capsule(p, (-0.42, 0, 1.7), (-0.44, 0, 1.1), 0.3, 0.26, "E8E2D0", sides=10)
    lathe(p, [(0.1, 0.0, WOOD_DC), (0.14, 0.1, WOOD_C), (0.2, 0.95, WOOD_C), (0.26, 1.02, GOLDB), (0.26, 1.1, GOLDB)], sides=8, loc=(-0.44, 0, 0))
    rig.add("leg_r", p, parent="hips", pivot=(-0.42, 0, 1.75))
    # ---- Breitseite: drei Kanonenrohre auf dem Rücken, nach links (+X) gerichtet
    p = Part()
    p.box((0.5, 0.3, 1.5), (0.1, 0.78, 2.6), WOOD_DC, r=rot(0, 0, 0), bevel=0.05, segs=1)
    rig.add("rack", p, parent="torso", pivot=(0, 0.7, 2.6))
    for i in range(3):
        p = Part()
        z = 2.1 + i * 0.5
        lathe(p, [(0.1, 0.0, GOLDB), (0.19, 0.06, HAT), (0.2, 0.2, GOLDB), (0.18, 0.28, HAT), (0.15, 1.1, HAT), (0.19, 1.16, GOLDB), (0.19, 1.3, GOLDB), (0.12, 1.3, "0A0C10"), (0.11, 1.0, "0A0C10")],
              sides=10, loc=(0.0, 0.8, z), r=rot(0, 80, 0), cap=False)
        rig.add("gun%d" % i, p, parent="rack", pivot=(0.2, 0.8, z))

    # ---------------------------------------------------------------- Clips
    rest = dict(root=dict(loc=(0, 0, 0), rot=(0, 0, 0)), hips=dict(loc=(0, 0, 0), rot=(0, 0, 0)), torso=dict(rot=(5, 0, 0), scale=1.0), skirt=dict(rot=(0, 0, 0)), head=dict(rot=(0, 0, 4)), jaw=dict(rot=(0, 0, 0)),
                beard=dict(rot=(0, 0, 0)), hat=dict(rot=(0, 0, 0), loc=(0, 0, 0)), arm_l=dict(rot=(0, 0, 0)), fore_l=dict(rot=(0, 0, 0)), wheel=dict(rot=(0, 0, 0)), arm_r=dict(rot=(0, 0, 0)), fore_r=dict(rot=(0, 0, 0)),
                sword=dict(rot=(0, 0, 0)), leg_l=dict(rot=(0, 0, 0)), leg_r=dict(rot=(0, 0, 0)), gun0=dict(loc=(0, 0, 0), scale=1.0), gun1=dict(loc=(0, 0, 0), scale=1.0), gun2=dict(loc=(0, 0, 0), scale=1.0), eye=dict(scale=1.0))
    with rig.clip("idle", 48, loop=True) as c:                       # schnauft, der Bart weht, das Glühauge flackert
        c.key(0, **rest)
        c.key(12, torso=dict(rot=(3, 0, 2), scale=(1.03, 1.04, 1.01)), head=dict(rot=(-4, 0, 10)), jaw=dict(rot=(8, 0, 0)), beard=dict(rot=(6, 0, 4)), wheel=dict(rot=(0, 20, 0)), sword=dict(rot=(8, 0, 0)), eye=dict(scale=1.4))
        c.key(24, torso=dict(rot=(6, 0, -2), scale=1.0), head=dict(rot=(2, 0, -6)), jaw=dict(rot=(0, 0, 0)), beard=dict(rot=(-4, 0, -4)), wheel=dict(rot=(0, -10, 0)), eye=dict(scale=0.9))
        c.key(36, head=dict(rot=(-2, 0, -10)), jaw=dict(rot=(10, 0, 0)), beard=dict(rot=(5, 0, 2)), sword=dict(rot=(-4, 0, 0)), eye=dict(scale=1.3))
    with rig.clip("walk", 48, loop=True, stride=2.3) as c:            # schwerer Seemannsgang, das Holzbein stampft
        c.key(0, hips=dict(loc=(0.12, 0, 0), rot=(0, 6, 0)), torso=dict(rot=(8, 0, 4)), head=dict(rot=(0, 0, -4)), leg_l=dict(rot=(-28, 0, 0)), leg_r=dict(rot=(20, 0, 0)), arm_l=dict(rot=(16, 0, 0)), arm_r=dict(rot=(-20, 0, 0)),
              beard=dict(rot=(10, 0, 0)), wheel=dict(rot=(0, 0, 0)), skirt=dict(rot=(4, 0, 0)), jaw=dict(rot=(4, 0, 0)))
        c.key(12, hips=dict(loc=(0.05, 0, -0.1), rot=(0, 2, 0)), leg_l=dict(rot=(0, 0, 0)), leg_r=dict(rot=(-4, 0, 0)), beard=dict(rot=(-6, 0, 0)), skirt=dict(rot=(-3, 0, 0)), jaw=dict(rot=(12, 0, 0)))
        c.key(24, hips=dict(loc=(-0.14, 0, 0.04), rot=(0, -8, 0)), torso=dict(rot=(8, 0, -5)), head=dict(rot=(0, 0, 6)), leg_l=dict(rot=(22, 0, 0)), leg_r=dict(rot=(-24, 0, 6)), arm_l=dict(rot=(-14, 0, 0)), arm_r=dict(rot=(18, 0, 0)),
              beard=dict(rot=(10, 0, 0)), wheel=dict(rot=(0, 90, 0)), skirt=dict(rot=(4, 0, 0)), jaw=dict(rot=(4, 0, 0)))
        c.key(36, hips=dict(loc=(-0.05, 0, -0.14), rot=(0, -3, 0)), leg_l=dict(rot=(4, 0, 0)), leg_r=dict(rot=(0, 0, 0)), beard=dict(rot=(-8, 0, 0)), skirt=dict(rot=(-3, 0, 0)), wheel=dict(rot=(0, 135, 0)), jaw=dict(rot=(12, 0, 0)))
        c.key(48, wheel=dict(rot=(0, 180, 0)))
    with rig.clip("attack", 33, hit=17) as c:                        # Säbelhieb von oben, das Rad deckt
        c.key(0, **rest)
        c.key(10, torso=dict(rot=(-12, 0, -14)), head=dict(rot=(-8, 0, 8)), arm_r=dict(rot=(-150, 0, -20)), fore_r=dict(rot=(-30, 0, 0)), sword=dict(rot=(-40, 0, 0)), arm_l=dict(rot=(-40, 0, 0)), fore_l=dict(rot=(-30, 0, 0)), jaw=dict(rot=(24, 0, 0)), hips=dict(loc=(0, 0.15, 0)))
        c.key(13, arm_r=dict(rot=(-160, 0, -20)))
        c.key(17, torso=dict(rot=(26, 0, 16)), head=dict(rot=(10, 0, -6)), arm_r=dict(rot=(-40, 0, 16)), fore_r=dict(rot=(-10, 0, 0)), sword=dict(rot=(30, 0, 0)), arm_l=dict(rot=(10, 0, 10)), jaw=dict(rot=(0, 0, 0)), hips=dict(loc=(0, -0.3, -0.12)), beard=dict(rot=(-20, 0, 0)))
        c.key(21, torso=dict(rot=(22, 0, 14)), sword=dict(rot=(22, 0, 0)), beard=dict(rot=(14, 0, 0)))
        c.key(33, **rest)
    with rig.clip("hit", 9) as c:
        c.key(0, **rest)
        c.key(3, torso=dict(rot=(-8, 0, 5), scale=(1.04, 1.04, 0.97)), head=dict(rot=(-16, 0, -8)), hat=dict(loc=(0, 0, 0.18), rot=(0, 0, 10)), jaw=dict(rot=(26, 0, 0)), beard=dict(rot=(-20, 0, 0)), hips=dict(loc=(0, 0.12, 0)))
        c.key(9, **rest)
    # Tod: taumelt, lässt Rad und Säbel sinken, dreht sich und kracht auf den Rücken; der Hut rollt davon
    with rig.clip("death", 60) as c:
        c.key(0, **rest)
        c.key(10, torso=dict(rot=(-14, 0, 12)), head=dict(rot=(-20, 0, 20)), jaw=dict(rot=(30, 0, 0)), arm_l=dict(rot=(-30, 0, 40)), arm_r=dict(rot=(-40, 0, -50)), hips=dict(loc=(0.1, 0.2, 0)), hat=dict(loc=(0, 0, 0.3), rot=(0, 0, 20)))
        c.key(22, root=dict(rot=(0, 0, 50)), torso=dict(rot=(18, 0, -16)), head=dict(rot=(16, 0, -16)), arm_l=dict(rot=(20, 0, 20)), arm_r=dict(rot=(10, 0, -20)), hips=dict(loc=(-0.1, -0.1, -0.1)), wheel=dict(rot=(0, 200, 0)), hat=dict(loc=(0, 0.2, 0.6), rot=(-30, 0, 60)))
        c.key(32, root=dict(rot=(-20, 0, 80), loc=(0, 0, 0)), torso=dict(rot=(-16, 0, 0)), head=dict(rot=(-24, 0, 0)), arm_l=dict(rot=(-70, 0, 50)), arm_r=dict(rot=(-80, 0, -60)), jaw=dict(rot=(34, 0, 0)), leg_l=dict(rot=(-20, 0, 0)), _i="LINEAR")
        c.key(42, root=dict(rot=(-88, 0, 90), loc=(0, 0, 0.72)), torso=dict(rot=(0, 0, 0)), head=dict(rot=(6, 0, 10)), arm_l=dict(rot=(-120, 0, 70)), arm_r=dict(rot=(-140, 0, -70)), leg_l=dict(rot=(-40, 0, 10)), leg_r=dict(rot=(-14, 0, -10)),
              beard=dict(rot=(-60, 0, 0)), hat=dict(loc=(0.6, -1.0, 0.9), rot=(100, 0, 100)), wheel=dict(rot=(0, 360, 0)), _i="LINEAR")
        c.key(46, root=dict(rot=(-82, 0, 90), loc=(0, 0, 0.84)), leg_l=dict(rot=(-56, 0, 10)), head=dict(rot=(-6, 0, 10)), jaw=dict(rot=(10, 0, 0)))
        c.key(51, root=dict(rot=(-88, 0, 90), loc=(0, 0, 0.72)), leg_l=dict(rot=(-6, 0, 12)), head=dict(rot=(8, 0, 14)), jaw=dict(rot=(24, 0, 0)), hat=dict(loc=(0.9, -1.2, 0.9), rot=(100, 0, 190)))
        c.key(60, root=dict(rot=(-88, 0, 90), loc=(0, 0, 0.72)), eye=dict(scale=0.1), hat=dict(loc=(1.0, -1.25, 0.9), rot=(100, 0, 230)))
    # Matrosen rufen: reckt den Säbel in den Himmel, brüllt, stampft mit dem Holzbein – der Sand bricht auf
    with rig.clip("summon", 39, hit=22) as c:
        c.key(0, **rest)
        c.key(10, torso=dict(rot=(-14, 0, 0)), head=dict(rot=(-26, 0, 0)), jaw=dict(rot=(40, 0, 0)), arm_r=dict(rot=(-170, 0, -10)), fore_r=dict(rot=(-10, 0, 0)), sword=dict(rot=(-60, 0, 0)), arm_l=dict(rot=(-30, 0, 30)), leg_r=dict(rot=(-50, 0, 0)), beard=dict(rot=(-30, 0, 0)), hips=dict(loc=(0.1, 0, 0)))
        c.key(14, head=dict(rot=(-26, 0, 8)), jaw=dict(rot=(46, 0, 0)), sword=dict(rot=(-60, 0, 14)))
        c.key(18, head=dict(rot=(-26, 0, -8)), sword=dict(rot=(-60, 0, -14)), leg_r=dict(rot=(-56, 0, 0)))
        c.key(22, leg_r=dict(rot=(0, 0, 0)), hips=dict(loc=(0, 0, -0.16)), torso=dict(rot=(12, 0, 0)), jaw=dict(rot=(10, 0, 0)), beard=dict(rot=(16, 0, 0)), _i="LINEAR")
        c.key(27, hips=dict(loc=(0, 0, 0.04)), head=dict(rot=(-10, 0, 0)))
        c.key(39, **rest)
    # Breitseite: dreht die linke Seite zum Ziel, drei Rohre feuern nacheinander und stoßen zurück
    with rig.clip("broadside", 45, hit=16) as c:
        side = dict(root=dict(rot=(0, 0, -78)), torso=dict(rot=(4, -14, 0)), head=dict(rot=(0, 0, 60)), arm_l=dict(rot=(-20, 0, 60)), fore_l=dict(rot=(-50, 0, 0)), arm_r=dict(rot=(20, 0, -20)))
        c.key(0, **rest)
        c.key(11, **side)
        for i in range(3):
            g = "gun%d" % i
            f = 15 + i * 5
            c.key(f - 1, **{g: dict(loc=(0, 0, 0), scale=1.0)})
            c.key(f + 1, _i="LINEAR", **{g: dict(loc=(-0.5, 0, 0), scale=(1.25, 1.25, 1.25))})
            c.key(f + 7, **{g: dict(loc=(0, 0, 0), scale=1.0)})
            c.key(f + 1, torso=dict(rot=(4, -14 + 10, 0)))
            c.key(f + 4, torso=dict(rot=(4, -14, 0)))
        c.key(34, **side)
        c.key(45, **rest)
    rig.finish(icon_yaw=-26, icon_pitch=10)


TABLE = {"untote_matrose": untote_matrose, "untote_deckratte": untote_deckratte, "untote_taucher": untote_taucher, "untote_kanonier": untote_kanonier, "untote_qualle": untote_qualle, "untote_krabbe": untote_krabbe, "boss_untote": boss_untote}

if __name__ == "__main__":
    run(TABLE, [a for a in sys.argv if not a.startswith("--")])
