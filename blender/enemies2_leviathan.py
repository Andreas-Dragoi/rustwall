"""Paket G2 – Weltboss „Schleim-Leviathan“ (Kapitel 6.5, für Clan-Raids und Ereignisse): gewaltige Schleimschlange,
die in Bögen aus dem Boden ragt, mit einer Krone aus Wrackteilen. Echte Boss-Figur (Teile mit Objekt-Animationen,
wie alle Bosse; siehe blender/GEGNER.md Kapitel 4).
Aufruf:  python3 blender/enemies2_leviathan.py [--notafel]"""
import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from enemies2_kit import *

SL, SL_D, SL_L = "7FB52A", "5E8F1E", "B8E05A"
BELLY = "D8F07A"
RUSTC, STEEL, GOLD = "B5652E", "8A94A8", "FFCB2E"
INK = "1B2410"


def boss_leviathan():
    rig = Rig("boss_leviathan", role="boss")
    # ---- Körper: drei Bögen, die aus dem Schleimsee ragen (vorn der Hals, dahinter Rückenbögen und Schwanzspitze)
    p = Part()                                                                                       # Schleimsee am Boden
    p.ball(3.2, (0, 1.2, 0.0), SL_D, scale=(1, 1.5, 0.08), subdiv=3)
    for (x, y, r) in ((2.2, -1.2, 0.5), (-2.4, 0.4, 0.6), (1.6, 3.6, 0.45), (-1.4, 4.2, 0.4)):
        p.ball(r, (x, y, 0.12), SL_L, scale=(1, 1, 0.3), subdiv=1)
    rig.add("pool", p, pivot=(0, 1.2, 0))
    arcs = [("arc_a", (0, 2.6), 2.4, 0.9), ("arc_b", (0, 5.0), 1.8, 0.7)]
    for nm, (x, y), h, r in arcs:
        p = Part()
        for k in range(9):
            a = math.pi * k / 8
            p.ball(r * (0.85 + 0.15 * math.sin(a)), (x, y - 1.2 * math.cos(a), h * math.sin(a)), SL if k % 2 else SL_L, subdiv=2)
        for k in range(3):                                                                           # Rückenflossen
            a = math.pi * (k + 2.5) / 8
            p.cone(0.3, 0.7, (x, y - 1.2 * math.cos(a), h * math.sin(a) + r * 0.8), "4A7A1A", r=rot(0, 0, 0), sides=4)
        rig.add(nm, p, pivot=(x, y, 0))
    p = Part()                                                                                       # Schwanzspitze mit Wrack-Rassel
    capsule(p, (0, 6.6, 0.0), (0, 7.1, 1.6), 0.45, 0.2, SL, sides=8)
    p.cyl(0.4, 0.3, (0, 7.15, 1.75), "2A2A30", r=rot(90, 0, 0), sides=10)                           # Autoreifen
    rig.add("tail", p, pivot=(0, 6.6, 0))
    # ---- Hals und Kopf
    p = Part()
    capsule(p, (0, 0.6, 0.0), (0, 0.2, 2.2), 1.15, 1.0, SL, sides=12)
    capsule(p, (0, 0.2, 2.2), (0, -0.4, 4.2), 1.0, 0.95, SL_L, sides=12)
    for k in range(5):
        p.ball(0.5, (0, -0.55 - 0.05 * k, 0.6 + k * 0.8), BELLY, scale=(1.2, 0.5, 0.7), subdiv=1)    # heller Bauch
    rig.add("neck", p, pivot=(0, 0.6, 0.2))
    p = Part()
    p.ball(1.5, (0, -0.9, 5.0), SL, scale=(1.0, 1.15, 0.85), subdiv=3)
    p.ball(0.45, (0.6, -2.1, 5.35), SL_L, scale=(1, 0.7, 0.6), subdiv=2)                             # Augenwülste
    p.ball(0.45, (-0.6, -2.1, 5.35), SL_L, scale=(1, 0.7, 0.6), subdiv=2)
    for s in (-1, 1):
        p.cone(0.18, 0.5, (0.5 * s, -2.45, 4.6), "FFFDF0", r=rot(180, 0, 0), sides=5)                 # Hauer
    rig.add("head", p, parent="neck", pivot=(0, -0.4, 4.2))
    p = Part()                                                                                       # Unterkiefer
    p.ball(1.1, (0, -1.3, 4.25), SL_D, scale=(0.95, 1.15, 0.4), subdiv=2)
    p.ball(0.7, (0, -1.6, 4.45), "6A1A2A", scale=(1, 1.1, 0.3), subdiv=2)
    rig.add("jaw", p, parent="head", pivot=(0, -0.5, 4.5))
    p = Part()
    for s in (-1, 1):
        p.ball(0.36, (0.6 * s, -2.25, 5.4), "FFFFFF", subdiv=2)
        p.ball(0.18, (0.6 * s, -2.55, 5.42), INK, subdiv=1)
    rig.add("eyes", p, parent="head", pivot=(0, -2.25, 5.4))
    p = Part()                                                                                       # Krone aus Wrackteilen: Anker, Steuerrad, Blech
    for k in range(5):
        a = math.radians(-60 + k * 30)
        p.box((0.3, 0.12, 0.9), (1.0 * math.sin(a), -0.6 - 0.2 * math.cos(a), 6.2 + 0.2 * (2 - abs(k - 2))), [RUSTC, STEEL, GOLD, STEEL, RUSTC][k], r=rot(0, math.degrees(a) * 0.6, 0), bevel=0.05, segs=1)
    p.torus(0.45, 0.07, (0, -0.2, 6.6), "8A5A32", r=rot(70, 0, 0), seg=14, tseg=4)
    p.box((0.12, 0.12, 1.2), (0.0, 0.1, 6.7), STEEL, bevel=0.03, segs=1)
    p.torus(0.35, 0.07, (0.0, 0.1, 6.15), STEEL, r=rot(90, 0, 90), seg=12, tseg=4)
    rig.add("crown", p, parent="head", pivot=(0, -0.6, 6.0))
    p = Part()                                                                                       # leuchtende Kiemen (Schwachstelle)
    for s in (-1, 1):
        for k in range(3):
            p.box((0.08, 0.5, 0.14), (1.42 * s, -0.6 + k * 0.3, 4.9), "E6FF5A", r=rot(0, 0, 10 * s), bevel=0.0)
    rig.add("gills", p, parent="head", pivot=(0, -0.3, 4.9), glow=True)
    rest = rest_pose(rig)
    with rig.clip("idle", 60, loop=True) as c:                     # wiegt den Kopf, die Bögen wogen
        c.key(0, **rest)
        c.key(20, neck=R(-4, 0, 6), head=R(6, 0, -8), jaw=R(10, 0, 0), arc_a=dict(scale=(1, 1, 1.06)), arc_b=dict(scale=(1, 1, 0.94)))
        c.key(40, neck=R(3, 0, -6), head=R(-4, 0, 8), jaw=R(0, 0, 0), arc_a=dict(scale=(1, 1, 0.95)), arc_b=dict(scale=(1, 1, 1.08)), gills=dict(scale=1.2))
    with rig.clip("walk", 48, loop=True, stride=1.3) as c:          # gleitet wellenförmig voran
        c.key(0, **rest)
        c.wave("arc_a", scale=(0, 0, 0.12), loc=(0, 0, 0.0), base_scale=(1, 1, 1))
        c.wave("arc_b", scale=(0, 0, 0.12), phase=0.33, base_scale=(1, 1, 1))
        c.wave("tail", rot=(10, 0, 14), phase=0.66)
        c.wave("neck", rot=(6, 0, 4), phase=0.15)
        c.wave("pool", scale=(0.04, 0.04, 0), base_scale=(1, 1, 1))
    with rig.clip("attack", 39, hit=22) as c:                     # holt mit dem Kopf aus und schnappt zu
        c.key(0, **rest)
        c.key(14, neck=R(-22, 0, 0), head=R(-18, 0, 0), jaw=R(30, 0, 0))
        c.key(22, neck=R(30, 0, 0), head=R(20, 0, 0), jaw=R(45, 0, 0), _i="LINEAR")
        c.key(26, jaw=R(0, 0, 0), neck=R(24, 0, 0))
        c.key(39, **rest)
    with rig.clip("hit", 12) as c:
        c.key(0, **rest)
        c.key(4, neck=R(-10, 0, 8), head=R(-14, 0, -10), eyes=dict(scale=(1, 1, 0.3)), jaw=R(20, 0, 0))
        c.key(12, **rest)
    with rig.clip("death", 75) as c:                               # bäumt sich auf und zerfließt zu einer Pfütze
        c.key(0, **rest)
        c.key(18, neck=R(-24, 0, 0), head=R(-30, 0, 0), jaw=R(50, 0, 0), crown=dict(loc=(0, 0, 0.4)))
        c.key(40, neck=dict(rot=(60, 0, 20), scale=(1.2, 1.2, 0.6)), head=R(20, 0, 0), jaw=R(10, 0, 0), arc_a=dict(scale=(1.3, 1, 0.3)), arc_b=dict(scale=(1.3, 1, 0.3)), tail=dict(rot=(60, 0, 0)), crown=dict(loc=(0.5, -0.5, -1.2), rot=(40, 0, 30)), _i="LINEAR")
        c.key(75, neck=dict(rot=(80, 0, 24), scale=(1.4, 1.4, 0.35)), head=dict(rot=(30, 0, 0), scale=(1.1, 1.1, 0.7)), arc_a=dict(scale=(1.4, 1, 0.12)), arc_b=dict(scale=(1.4, 1, 0.1)), tail=dict(rot=(80, 0, 0), scale=0.6),
              pool=dict(scale=(1.3, 1.2, 1.5)), crown=dict(loc=(0.6, -0.8, -1.6), rot=(70, 0, 40)), eyes=dict(scale=(1, 1, 0.1)), gills=dict(scale=0.05))
    with rig.clip("special", 45, hit=27) as c:                    # richtet sich hoch auf, bläht die Kehle und speit/schmettert
        c.key(0, **rest)
        c.key(16, neck=R(-26, 0, 0), head=R(-24, 0, 0), jaw=R(40, 0, 0), gills=dict(scale=1.8), arc_a=dict(scale=(1, 1, 1.2)))
        c.key(27, neck=R(28, 0, 0), head=R(14, 0, 0), jaw=R(55, 0, 0), gills=dict(scale=1.0), _i="LINEAR")
        c.key(33, jaw=R(10, 0, 0))
        c.key(45, **rest)
    with rig.clip("slam", 42, hit=26) as c:                       # schlägt mit dem ganzen Hals auf den Boden
        c.key(0, **rest)
        c.key(14, neck=R(-30, 0, 0), head=R(-10, 0, 0), root=dict(loc=(0, 0.4, 0.2)))
        c.key(26, neck=R(55, 0, 0), head=R(10, 0, 0), root=dict(loc=(0, -0.2, 0)), _i="LINEAR")
        c.key(32, neck=R(48, 0, 0))
        c.key(42, **rest)
    with rig.clip("summon", 45, hit=24) as c:                     # brüllt, der See blubbert
        c.key(0, **rest)
        c.key(12, neck=R(-16, 0, 0), head=R(-30, 0, 0), jaw=R(50, 0, 0), pool=dict(scale=(1.1, 1.1, 2.0)))
        c.key(24, head=R(-30, 0, 10), jaw=R(55, 0, 0), pool=dict(scale=(1.15, 1.15, 3.0)), gills=dict(scale=1.6))
        c.key(45, **rest)
    rig.finish(icon_yaw=-30, icon_pitch=14)


TABLE = {"boss_leviathan": boss_leviathan}

if __name__ == "__main__":
    run(TABLE, [a for a in sys.argv if not a.startswith("--")])
