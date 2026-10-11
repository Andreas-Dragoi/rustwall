"""Dämonen (Schleimkrater): sechs Arten + Boss (zweite Phase des Schleimkönigs) und das Höllenportal des Beschwörers
(ein Objekt der Verhaltens-Bausteine), nach dem Muster von enemies_untote.py (siehe blender/GEGNER.md).
Aufruf:  python3 blender/enemies_daemonen.py [art ...] [--notafel]"""
import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from animkit import *

ROCK_C, ROCK_DC, GLUT, RUNE = "3A2A32", "241A22", "FF5A1E", "FF3A8A"


# ================================================================= Höllenportal (Objekt: steht still, spuckt Wichtel aus)
def daemonen_portal():
    rig = Rig("daemonen_portal", role="special")
    # ---- Kreis aus sechs Runensteinen
    for i in range(6):
        a = math.radians(i * 60)
        x, y = math.cos(a) * 0.95, math.sin(a) * 0.95
        p = MPart(T(x, y, 0) @ rot(0, 0, i * 60 + 90))
        p.box((0.34, 0.24, 0.7 + 0.2 * (i % 2)), (0, 0, 0.35 + 0.1 * (i % 2)), ROCK_C if i % 2 else ROCK_DC, r=rot(-10, 0, 4 * (i % 3 - 1)), bevel=0.06, segs=1)
        p.cone(0.1, 0.26, (0, 0, 0.82 + 0.2 * (i % 2)), ROCK_DC, r=rot(-10, 0, 0), sides=4)
        rig.add("stone%d" % i, p, pivot=(x, y, 0))
        p = MPart(T(x, y, 0) @ rot(0, 0, i * 60 + 90))
        p.box((0.14, 0.03, 0.26), (0, -0.14, 0.42 + 0.1 * (i % 2)), RUNE, r=rot(-10, 0, 0), bevel=0.0)
        rig.add("rune%d" % i, p, parent="stone%d" % i, pivot=(x, y, 0.4), glow=True)
    # ---- glühender Strudel in der Mitte
    p = Part()
    lathe(p, [(0.0, 0.06, "FFE08A"), (0.3, 0.08, GLUT), (0.62, 0.05, "C81E3A"), (0.82, 0.03, "5A0F2A")], sides=12, cap=False)
    for i in range(3):
        a = math.radians(i * 120)
        p.ball(0.12, (math.cos(a) * 0.45, math.sin(a) * 0.45, 0.1), "FFE08A", scale=(2.2, 0.7, 0.4), r=rot(0, 0, i * 120 + 70), subdiv=1)
    rig.add("swirl", p, pivot=(0, 0, 0.05), glow=True)
    p = Part()
    lathe(p, [(0.26, 0.1, GLUT), (0.16, 0.7, "FFB03A"), (0.0, 1.3, "FFE08A")], sides=7, cap=False)
    rig.add("flame", p, pivot=(0, 0, 0.1), glow=True)

    all_st = {"stone%d" % i: dict(loc=(0, 0, 0), rot=(0, 0, 0), scale=1.0) for i in range(6)}
    with rig.clip("idle", 36, loop=True) as c:                       # der Strudel dreht sich, die Flamme lodert, Runen pulsieren
        c.key(0, swirl=dict(rot=(0, 0, 0), scale=1.0), flame=dict(scale=(1, 1, 1), rot=(0, 0, 0)), **all_st)
        c.key(12, swirl=dict(rot=(0, 0, 120), scale=1.08), flame=dict(scale=(0.8, 0.8, 1.3), rot=(0, 0, 60)), _i="LINEAR")
        c.key(24, swirl=dict(rot=(0, 0, 240), scale=0.95), flame=dict(scale=(1.15, 1.15, 0.8), rot=(0, 0, 120)), _i="LINEAR")
        c.key(36, swirl=dict(rot=(0, 0, 360), scale=1.0), flame=dict(scale=(1, 1, 1), rot=(0, 0, 180)), _i="LINEAR")
        for i in range(6):
            c.wave("rune%d" % i, scale=(0.25, 0.25, 0.25), phase=i / 6.0)
    with rig.clip("walk", 3, loop=True) as c:                        # (steht immer – nur der Vollständigkeit halber)
        c.key(0, swirl=dict(rot=(0, 0, 0)))
    with rig.clip("attack", 12, hit=6) as c:                         # Ausstoß eines Wichtels: Stichflamme
        c.key(0, flame=dict(scale=1.0), swirl=dict(scale=1.0))
        c.key(6, flame=dict(scale=(1.6, 1.6, 2.2)), swirl=dict(scale=1.3))
        c.key(12, flame=dict(scale=1.0), swirl=dict(scale=1.0))
    with rig.clip("hit", 9) as c:
        c.key(0, **all_st)
        for i in range(6):
            c.key(3, **{"stone%d" % i: dict(rot=(0, 10 * (1 if i % 2 else -1), 0), loc=(0, 0, 0.06))})
        c.key(9, **all_st)
    with rig.clip("death", 24) as c:                                 # erlischt: Flamme fällt zusammen, die Steine kippen nach außen
        c.key(0, flame=dict(scale=1.0), swirl=dict(scale=1.0), **all_st)
        c.key(6, flame=dict(scale=(1.8, 1.8, 0.3)), swirl=dict(scale=1.4))
        c.key(14, flame=dict(scale=0.02), swirl=dict(scale=0.02))
        for i in range(6):
            c.key(8, **{"stone%d" % i: dict(rot=(0, 0, 0))})
            c.key(18 + i % 3, **{"stone%d" % i: dict(rot=(-84, 0, 0), loc=(0, 0, 0.1))})
            c.key(24, **{"stone%d" % i: dict(rot=(-84, 0, 0), loc=(0, 0, 0.1)), "rune%d" % i: dict(scale=0.05)})
    with rig.clip("spawn", 15) as c:                                 # öffnet sich: Steine wachsen aus dem Boden
        for i in range(6):
            c.key(0, **{"stone%d" % i: dict(loc=(0, 0, -1.2), scale=1.0)})
            c.key(8 + i % 3, **{"stone%d" % i: dict(loc=(0, 0, 0.08))})
            c.key(15, **{"stone%d" % i: dict(loc=(0, 0, 0))})
        c.key(0, flame=dict(scale=0.02), swirl=dict(scale=0.02))
        c.key(9, flame=dict(scale=0.02), swirl=dict(scale=0.6))
        c.key(15, flame=dict(scale=1.0), swirl=dict(scale=1.0))
    rig.finish(icon_yaw=-30, icon_pitch=30)


from enemies_daemonen_arten import ARTEN

TABLE = dict(ARTEN)
TABLE["daemonen_portal"] = daemonen_portal

if __name__ == "__main__":
    run(TABLE, [a for a in sys.argv if not a.startswith("--")])
