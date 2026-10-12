"""Paket Z – Magma-Wesen der Vulkaninsel (Gebiet 8): sechs Arten, drei Rollen aus G2 (Heilerin, Schildträger, Brutmutter),
Miniboss Glutbrecher und Boss Magmafürst Brodel (echte Boss-Figur).

| Art | Rolle | besondere Clips |
|---|---|---|
| magma_lavaschnecke | mass | steam (badet nahe der Lava), spawn |
| magma_feuerkaefer | fast | pounce, spawn |
| magma_obsidiangolem | tank | harden (Schleife: Kruste verhärtet), spawn |
| magma_glutspucker | ranged | erupt (bläht sich vor dem Schuss auf), spawn |
| magma_aschegeist | air | blink, spawn |
| magma_schlackenkriecher | special | steam, spawn |
| magma_glutpriesterin | healer | heal, spawn |
| magma_basaltschild | shield | block, spawn |
| magma_lavamutter | brood | brood, steam, spawn |
| magma_glutbrecher | miniboss | skill, spawn |
| boss_magma | boss | special (Ausbruch), summon, slam |

Aufruf:  python3 blender/enemies_magma.py [art ...] [--notafel]"""
import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from enemies2_kit import *

# Farben der Familie: Basalt, Obsidian, Glut, Asche
BAS, BAS_D, BAS_L = "3E383C", "2A2529", "5E565C"
OBS, OBS_D, OBS_L = "2A2438", "18141F", "6E6890"
GLUT, GLUT_L, GLUT_D = "FF6A1A", "FFC23A", "D23A16"
ASH, ASH_D, ASH_L = "8E8682", "6A6260", "B8B0AA"
SKIN, SKIN_D = "C8642E", "9A4422"
INK = "16101A"
WHITE = "FFFFFF"
GOLD = "F2C230"


def lava_veins(p, pts, w=0.035):
    for i in range(len(pts) - 1):
        capsule(p, pts[i], pts[i + 1], w, w, GLUT, sides=4)


# ================================================================= Lavaschnecke (Masse)
def magma_lavaschnecke():
    rig = Rig("magma_lavaschnecke", role="mass")
    p = Part()                                                                                       # Fuß: lange, glühende Unterseite
    lathe(p, [(0.0, -0.62, SKIN_D), (0.2, -0.55, SKIN), (0.27, -0.3, SKIN), (0.28, 0.1, SKIN), (0.22, 0.4, SKIN_D), (0.0, 0.62, SKIN_D)],
          sides=8, loc=(0, 0, 0.2), r=rot(-90, 0, 0), sx=1.25, sy=0.7)
    rig.add("body", p, pivot=(0, 0, 0.2))
    p = Part()                                                                                       # Kopf mit Maul
    p.ball(0.24, (0, -0.55, 0.36), SKIN, scale=(1.0, 1.1, 0.9), subdiv=2)
    p.box((0.22, 0.04, 0.04), (0, -0.78, 0.32), INK, bevel=0.0)
    rig.add("head", p, parent="body", pivot=(0, -0.4, 0.3))
    for s, nm in ((1, "stalk_l"), (-1, "stalk_r")):                                               # Augenstiele mit Glutaugen
        p = Part()
        capsule(p, (0.1 * s, -0.6, 0.52), (0.18 * s, -0.66, 0.85), 0.04, 0.03, SKIN_D, sides=5)
        p.ball(0.08, (0.19 * s, -0.67, 0.9), "F8E8D0", subdiv=1)
        p.ball(0.04, (0.2 * s, -0.74, 0.91), INK, subdiv=1)
        rig.add(nm, p, parent="head", pivot=(0.1 * s, -0.6, 0.52))
    p = Part()                                                                                       # Vulkanhaus auf dem Rücken
    lathe(p, [(0.42, 0.28, BAS_D), (0.45, 0.38, BAS), (0.34, 0.7, BAS_L), (0.2, 0.95, BAS), (0.16, 1.0, BAS_D)], sides=9, loc=(0, 0.12, 0))
    for k in range(4):
        a = k * math.tau / 4 + 0.4
        p.cone(0.09, 0.2, (0.36 * math.cos(a), 0.12 + 0.36 * math.sin(a), 0.5), BAS_L, r=rot(0, 50, math.degrees(a)), sides=4)
    rig.add("shell", p, parent="body", pivot=(0, 0.12, 0.3))
    p = Part()                                                                                       # glühender Krater und Lavaspur am Haus
    p.cyl(0.14, 0.06, (0, 0.12, 0.98), GLUT_L, sides=8)
    lava_veins(p, [(0.0, 0.12, 0.95), (0.12, -0.08, 0.7), (0.25, -0.1, 0.45)], 0.03)
    rig.add("glow", p, parent="shell", pivot=(0, 0.12, 0.98), glow=True)
    rest = rest_pose(rig)
    with rig.clip("idle", 36, loop=True) as c:                     # Augenstiele tasten, das Haus qualmt
        K(c, rig, 0, **rest)
        K(c, rig, 12, stalk_l=R(-14, 0, 10), stalk_r=R(8, 0, -6), shell=dict(scale=(1.03, 1.03, 0.98)), glow=dict(scale=1.25))
        K(c, rig, 24, stalk_l=R(6, 0, -6), stalk_r=R(-12, 0, 12), head=R(0, 0, 8), glow=dict(scale=0.9))
    with rig.clip("walk", 24, loop=True, stride=1.9 * 24 / 30.0) as c:     # Kriechwelle läuft durch den Fuß
        K(c, rig, 0, **rest)
        c.wave("body", scale=(0.0, 0.1, -0.06), n=2, base_scale=(1, 1, 1))
        c.wave("head", rot=(6, 0, 4), phase=0.25)
        c.wave("shell", rot=(4, 0, 0), loc=(0, 0.03, 0.02), n=2, phase=0.5)
        c.wave("stalk_l", rot=(10, 0, 0))
        c.wave("stalk_r", rot=(10, 0, 0), phase=0.5)
    with rig.clip("attack", 21, hit=11) as c:                      # zieht den Kopf zurück und beißt zu
        K(c, rig, 0, **rest)
        K(c, rig, 7, head=dict(rot=(-20, 0, 0), loc=(0, 0.12, 0.06)), stalk_l=R(-20, 0, 0), stalk_r=R(-20, 0, 0))
        K(c, rig, 11, _i="LINEAR", head=dict(rot=(18, 0, 0), loc=(0, -0.22, -0.04)), body=dict(scale=(0.95, 1.12, 0.95)))
        K(c, rig, 21, **rest)
    with rig.clip("hit", 9) as c:                                  # zieht die Augen ein
        K(c, rig, 0, **rest)
        K(c, rig, 3, stalk_l=dict(scale=0.4), stalk_r=dict(scale=0.4), head=dict(loc=(0, 0.1, -0.05)), shell=dict(rot=(-8, 0, 6)))
        K(c, rig, 9, **rest)
    with rig.clip("death", 30) as c:                               # Haus kippt, der Fuß zerfließt
        K(c, rig, 0, **rest)
        K(c, rig, 10, shell=dict(rot=(-10, 30, 0)), stalk_l=dict(scale=0.5), stalk_r=dict(scale=0.5), glow=dict(scale=1.6))
        K(c, rig, 20, _i="LINEAR", shell=dict(rot=(10, 75, 0), loc=(-0.25, 0, -0.1)), body=dict(scale=(1.35, 1.2, 0.35)), head=dict(loc=(0, 0, -0.15)))
        K(c, rig, 30, shell=dict(rot=(10, 82, 0), loc=(-0.3, 0, -0.14)), body=dict(scale=(1.45, 1.25, 0.25)), glow=dict(scale=0.05))
    with rig.clip("steam", 30) as c:                               # badet nahe der Lava: Haus brodelt, Glut lodert
        K(c, rig, 0, **rest)
        K(c, rig, 8, shell=dict(scale=(1.08, 1.08, 1.1)), glow=dict(scale=1.8), stalk_l=R(-25, 0, 20), stalk_r=R(-25, 0, -20))
        K(c, rig, 16, shell=dict(scale=(0.97, 0.97, 0.95)), glow=dict(scale=1.2))
        K(c, rig, 22, shell=dict(scale=(1.05, 1.05, 1.06)), glow=dict(scale=1.6))
        K(c, rig, 30, **rest)
    spawn_clip(rig, rest, 0.9)
    rig.finish(icon_yaw=-35, icon_pitch=18)


# ================================================================= Feuerkäfer (Flitzer)
def magma_feuerkaefer():
    rig = Rig("magma_feuerkaefer", role="fast", size=1.25)
    p = Part()                                                                                       # Panzer aus Kohle
    p.ball(0.36, (0, 0.05, 0.42), BAS_D, scale=(0.95, 1.25, 0.62), subdiv=2)
    p.box((0.03, 0.8, 0.05), (0, 0.05, 0.64), INK, bevel=0.0)                                       # Naht der Flügeldecken
    rig.add("body", p, pivot=(0, 0, 0.4))
    p = Part()                                                                                       # glühender Hinterleib
    p.ball(0.24, (0, 0.42, 0.36), GLUT, scale=(0.95, 1.0, 0.75), subdiv=2)
    rig.add("glow", p, parent="body", pivot=(0, 0.42, 0.36), glow=True)
    p = Part()                                                                                       # Kopf mit Zangen
    p.ball(0.17, (0, -0.42, 0.38), BAS, scale=(1.1, 0.9, 0.8), subdiv=1)
    for s in (-1, 1):
        capsule(p, (0.08 * s, -0.55, 0.34), (0.16 * s, -0.72, 0.3), 0.035, 0.02, GLUT_D, sides=4)
        capsule(p, (0.16 * s, -0.72, 0.3), (0.05 * s, -0.82, 0.3), 0.02, 0.01, GLUT_D, sides=4)
        capsule(p, (0.06 * s, -0.5, 0.48), (0.2 * s, -0.7, 0.66), 0.015, 0.01, INK, sides=3)        # Fühler
        p.ball(0.045, (0.09 * s, -0.55, 0.43), GLUT_L, subdiv=1)
    rig.add("head", p, parent="body", pivot=(0, -0.3, 0.4))
    legs = []
    for i, y in enumerate((-0.2, 0.05, 0.3)):
        for s in (1, -1):
            nm = "leg_%d%s" % (i, "l" if s > 0 else "r")
            p = Part()
            capsule(p, (0.25 * s, y, 0.35), (0.45 * s, y - 0.05, 0.3), 0.035, 0.03, INK, sides=4)
            capsule(p, (0.45 * s, y - 0.05, 0.3), (0.52 * s, y - 0.08, 0.0), 0.03, 0.02, INK, sides=4)
            rig.add(nm, p, parent="body", pivot=(0.25 * s, y, 0.35))
            legs.append((nm, (i * 0.5 + (0.0 if s > 0 else 0.5)) % 1.0, s))

    def sp(name, c, rig, rest):
        if name == "idle":
            K(c, rig, 6, glow=dict(scale=1.25))
            K(c, rig, 18, glow=dict(scale=0.9))
    rest = quad(rig, legs, 0.4, 0.7, 5.0, "fast", walk_n=12, leg_swing=30, side_legs=True, special=sp, hop=0.06)
    with rig.clip("pounce", 15) as c:                              # duckt sich und springt
        K(c, rig, 0, **rest)
        K(c, rig, 4, body=dict(rot=(-14, 0, 0), loc=(0, 0.1, -0.08)), glow=dict(scale=1.5))
        K(c, rig, 8, _i="LINEAR", root=dict(loc=(0, -0.4, 0.55)), body=dict(rot=(10, 0, 0)))
        K(c, rig, 12, root=dict(loc=(0, -0.7, 0.1)), body=dict(rot=(16, 0, 0)))
        K(c, rig, 15, **rest)
    rig.finish(icon_yaw=-35, icon_pitch=22)


# ================================================================= Obsidian-Golem (Brocken)
def magma_obsidiangolem():
    rig = Rig("magma_obsidiangolem", role="tank")
    rig.node("hips", pivot=(0, 0, 1.2))
    p = Part()                                                                                       # Rumpf aus schwarzem Glas
    p.box((1.6, 1.1, 1.3), (0, 0, 1.95), OBS, r=rot(0, 0, 3), bevel=0.22, segs=1)
    p.box((1.2, 0.9, 0.6), (0, 0.05, 1.25), OBS_D, bevel=0.15, segs=1)
    for k in range(4):                                                                               # Obsidianzacken auf den Schultern
        x = (-0.65, -0.35, 0.35, 0.65)[k]
        p.cone(0.16, 0.55 + 0.15 * (k % 2), (x, 0.15, 2.7), OBS_L if k % 2 else OBS, r=rot(-15, 18 * (1 if x > 0 else -1), 0), sides=5)
    rig.add("body", p, parent="hips", pivot=(0, 0, 1.2))
    p = Part()                                                                                       # Lavaadern
    lava_veins(p, [(-0.5, -0.56, 1.5), (-0.2, -0.57, 1.9), (0.1, -0.57, 1.7), (0.45, -0.56, 2.2)], 0.05)
    lava_veins(p, [(-0.1, -0.57, 2.4), (0.2, -0.57, 2.2)], 0.04)
    p.ball(0.18, (0, -0.55, 2.0), GLUT_L, scale=(1, 0.4, 1), subdiv=1)
    rig.add("glow", p, parent="body", pivot=(0, -0.55, 2.0), glow=True)
    p = Part()                                                                                       # kleiner Kopf mit Glutschlitz
    p.box((0.55, 0.5, 0.45), (0, -0.25, 2.85), BAS, bevel=0.12, segs=1)
    p.box((0.38, 0.06, 0.07), (0, -0.51, 2.88), GLUT_L)
    rig.add("head", p, parent="body", pivot=(0, -0.1, 2.65))
    for s, nm in ((1, "arm_l"), (-1, "arm_r")):                                                    # Arme mit Basaltfäusten
        p = Part()
        p.ball(0.36, (0.95 * s, 0, 2.4), OBS, subdiv=1)
        capsule(p, (0.98 * s, 0, 2.3), (1.1 * s, -0.15, 1.5), 0.26, 0.24, OBS_D, sides=6)
        p.box((0.62, 0.62, 0.62), (1.12 * s, -0.25, 1.1), BAS_L, bevel=0.14, segs=1)
        p.cone(0.1, 0.25, (1.12 * s, -0.6, 1.2), OBS_L, r=rot(90, 0, 0), sides=4)
        rig.add(nm, p, parent="body", pivot=(0.95 * s, 0, 2.4))
    for s, nm in ((1, "leg_l"), (-1, "leg_r")):
        p = Part()
        capsule(p, (0.42 * s, 0, 1.15), (0.45 * s, 0, 0.35), 0.28, 0.25, BAS, sides=6)
        p.box((0.6, 0.75, 0.3), (0.45 * s, -0.1, 0.15), BAS_D, bevel=0.1, segs=1)
        rig.add(nm, p, parent="hips", pivot=(0.42 * s, 0, 1.2))
    rest = biped(rig, 1.2, 3.1, 1.2, "tank", walk_n=30, leg_swing=22, arm_swing=12, death_side=True)
    with rig.clip("harden", 24, loop=True) as c:                   # Arme vor dem Körper, Glut leuchtet, Kruste knistert
        hard = dict(rest, arm_l=R(-60, 0, -40), arm_r=R(-60, 0, 40), hips=dict(loc=(0, 0, -0.15)), body=R(12, 0, 0), head=R(10, 0, 0), glow=dict(scale=1.4))
        K(c, rig, 0, **hard)
        K(c, rig, 8, glow=dict(scale=1.9), body=dict(rot=(12, 0, 2), scale=(1.02, 1.02, 1.0)))
        K(c, rig, 16, glow=dict(scale=1.5), body=dict(rot=(12, 0, -2), scale=1.0))
    rig.finish(icon_yaw=-28, icon_pitch=12)


# ================================================================= Glutspucker (Fernkämpfer)
def magma_glutspucker():
    rig = Rig("magma_glutspucker", role="ranged")
    rig.node("hips", pivot=(0, 0, 0.35))
    p = Part()                                                                                       # kleiner Vulkan als Körper
    lathe(p, [(0.55, 0.3, BAS_D), (0.6, 0.4, BAS), (0.45, 0.9, BAS_L), (0.3, 1.3, BAS), (0.24, 1.38, BAS_D)], sides=10)
    for k in range(5):
        a = k * math.tau / 5 + 0.3
        p.cone(0.1, 0.3, (0.48 * math.cos(a), 0.48 * math.sin(a), 0.75), BAS_L, r=rot(0, 60, math.degrees(a)), sides=4)
    for s in (-1, 1):                                                                                # Gesicht: Glupschaugen und Mund
        p.ball(0.11, (0.17 * s, -0.42, 0.95), "F8E8D0", subdiv=1)
        p.ball(0.05, (0.17 * s, -0.51, 0.95), INK, subdiv=1)
    p.box((0.26, 0.05, 0.08), (0, -0.48, 0.72), INK, bevel=0.0)
    rig.add("body", p, parent="hips", pivot=(0, 0, 0.35))
    p = Part()                                                                                       # Krater voller Glut, Lavatropfen außen
    p.cyl(0.22, 0.08, (0, 0, 1.38), GLUT_L, sides=8)
    lava_veins(p, [(0.1, -0.2, 1.36), (0.25, -0.35, 1.0), (0.32, -0.38, 0.75)], 0.035)
    rig.add("glow", p, parent="body", pivot=(0, 0, 1.38), glow=True)
    for s, nm in ((1, "arm_l"), (-1, "arm_r")):
        p = Part()
        capsule(p, (0.48 * s, 0, 0.7), (0.62 * s, -0.15, 0.48), 0.06, 0.05, BAS, sides=5)
        p.ball(0.08, (0.64 * s, -0.17, 0.45), BAS_L, subdiv=1)
        rig.add(nm, p, parent="body", pivot=(0.48 * s, 0, 0.7))
    for s, nm in ((1, "leg_l"), (-1, "leg_r")):
        p = Part()
        capsule(p, (0.22 * s, 0, 0.36), (0.24 * s, 0, 0.1), 0.1, 0.09, BAS_D, sides=6)
        p.ball(0.12, (0.24 * s, -0.08, 0.07), BAS, scale=(1, 1.4, 0.55), subdiv=1)
        rig.add(nm, p, parent="hips", pivot=(0.22 * s, 0, 0.35))
    rest = rest_pose(rig)
    with rig.clip("idle", 36, loop=True) as c:
        K(c, rig, 0, **rest)
        K(c, rig, 12, body=dict(scale=(1.03, 1.03, 0.97)), glow=dict(scale=1.25), arm_l=R(0, 0, 10))
        K(c, rig, 24, body=dict(scale=(0.98, 0.98, 1.03)), glow=dict(scale=0.9), arm_r=R(0, 0, -10))
    with rig.clip("walk", 18, loop=True, stride=1.9 * 18 / 30.0) as c:    # watschelt
        K(c, rig, 0, **rest)
        c.wave("leg_l", rot=(36, 0, 0))
        c.wave("leg_r", rot=(36, 0, 0), phase=0.5)
        c.wave("body", rot=(0, 9, 0), phase=0.25)
        c.wave("hips", loc=(0, 0, 0.05), n=2, phase=0.25)
        c.wave("arm_l", rot=(-25, 0, 0), phase=0.5)
        c.wave("arm_r", rot=(-25, 0, 0))
    with rig.clip("attack", 24, hit=14) as c:                      # spuckt einen Glutbrocken
        K(c, rig, 0, **rest)
        K(c, rig, 8, body=dict(rot=(-14, 0, 0), scale=(1.1, 1.1, 0.85)), glow=dict(scale=1.6), arm_l=R(-40, 0, 30), arm_r=R(-40, 0, -30))
        K(c, rig, 14, _i="LINEAR", body=dict(rot=(10, 0, 0), scale=(0.92, 0.92, 1.18)), glow=dict(scale=2.2), hips=dict(loc=(0, 0.06, 0)))
        K(c, rig, 24, **rest)
    with rig.clip("hit", 9) as c:
        K(c, rig, 0, **rest)
        K(c, rig, 3, body=dict(rot=(-12, 0, 8), scale=(1.06, 1.06, 0.92)), glow=dict(scale=0.6))
        K(c, rig, 9, **rest)
    with rig.clip("death", 30) as c:                               # bricht in sich zusammen, der Krater erlischt
        K(c, rig, 0, **rest)
        K(c, rig, 8, body=dict(scale=(1.15, 1.15, 0.8)), glow=dict(scale=1.8))
        K(c, rig, 18, _i="LINEAR", body=dict(rot=(0, 25, 0), scale=(1.3, 1.3, 0.45)), hips=dict(loc=(0, 0, -0.2)), leg_l=R(0, -60, 0), leg_r=R(0, 60, 0))
        K(c, rig, 30, body=dict(rot=(0, 28, 0), scale=(1.35, 1.35, 0.38)), hips=dict(loc=(0, 0, -0.24)), glow=dict(scale=0.05))
    with rig.clip("erupt", 18) as c:                               # bläht sich vor dem Schuss auf
        K(c, rig, 0, **rest)
        K(c, rig, 9, body=dict(scale=(1.15, 1.15, 0.9)), glow=dict(scale=1.9), arm_l=R(-20, 0, 40), arm_r=R(-20, 0, -40))
        K(c, rig, 18, body=dict(scale=(1.08, 1.08, 0.95)), glow=dict(scale=1.6))
    spawn_clip(rig, rest, 1.2)
    rig.finish(icon_yaw=-30, icon_pitch=16)


# ================================================================= Aschegeist (Flieger)
def magma_aschegeist():
    rig = Rig("magma_aschegeist", role="air")
    p = Part()                                                                                       # Aschewolke (durchscheinend)
    for (x, y, z, r) in ((0, 0, 0.75, 0.4), (0.28, 0.05, 0.62, 0.28), (-0.3, 0.05, 0.66, 0.3), (0.1, 0.2, 1.0, 0.28), (-0.12, 0.12, 0.98, 0.25)):
        p.ball(r, (x, y, z), ASH if r > 0.3 else ASH_L, subdiv=2)
    rig.add("body", p, pivot=(0, 0, 0.75), ghost=True)
    p = Part()                                                                                       # Schweif aus Asche
    for i, (y, z, r) in enumerate(((0.38, 0.55, 0.2), (0.62, 0.42, 0.15), (0.82, 0.32, 0.1))):
        p.ball(r, (0, y, z), ASH_D if i % 2 else ASH, subdiv=1)
    rig.add("tail", p, parent="body", pivot=(0, 0.3, 0.6), ghost=True)
    p = Part()                                                                                       # glühende Augen und Glutfunken
    for s in (-1, 1):
        p.ball(0.08, (0.13 * s, -0.36, 0.85), GLUT_L, scale=(1, 0.5, 1.2), subdiv=1)
    p.ball(0.05, (0.0, -0.38, 0.62), GLUT, scale=(2.0, 0.5, 0.6), subdiv=1)                          # Mund
    rig.add("glow", p, parent="body", pivot=(0, -0.36, 0.8), glow=True)
    for s, nm in ((1, "arm_l"), (-1, "arm_r")):                                                    # Rauchärmchen
        p = Part()
        capsule(p, (0.35 * s, -0.05, 0.75), (0.6 * s, -0.25, 0.55), 0.09, 0.05, ASH_D, sides=5)
        rig.add(nm, p, parent="body", pivot=(0.35 * s, -0.05, 0.75), ghost=True)
    rest = rest_pose(rig)
    with rig.clip("idle", 36, loop=True) as c:                     # wabert
        K(c, rig, 0, **rest)
        K(c, rig, 12, body=dict(scale=(1.06, 1.0, 0.95), loc=(0, 0, 0.06)), tail=R(0, 0, 18), glow=dict(scale=1.2))
        K(c, rig, 24, body=dict(scale=(0.96, 1.0, 1.05), loc=(0, 0, -0.04)), tail=R(0, 0, -18), arm_l=R(-10, 0, 20), arm_r=R(-10, 0, -20))
    with rig.clip("walk", 24, loop=True, stride=3.2 * 24 / 30.0) as c:    # treibt vorwärts, der Schweif peitscht
        K(c, rig, 0, **dict(rest, body=dict(rot=(14, 0, 0))))
        c.wave("tail", rot=(0, 0, 26))
        c.wave("body", loc=(0, 0, 0.08), n=2, base_rot=(14, 0, 0))
        c.wave("arm_l", rot=(-30, 0, 0), phase=0.5)
        c.wave("arm_r", rot=(-30, 0, 0))
    with rig.clip("attack", 21, hit=11) as c:                      # stößt vor und faucht Asche
        K(c, rig, 0, **rest)
        K(c, rig, 6, body=dict(rot=(-12, 0, 0), loc=(0, 0.2, 0.1)), arm_l=R(-60, 0, 30), arm_r=R(-60, 0, -30))
        K(c, rig, 11, _i="LINEAR", body=dict(rot=(20, 0, 0), loc=(0, -0.4, -0.1), scale=(1.1, 1.2, 0.9)), glow=dict(scale=1.7), arm_l=R(-100, 0, 0), arm_r=R(-100, 0, 0))
        K(c, rig, 21, **rest)
    with rig.clip("hit", 9) as c:
        K(c, rig, 0, **rest)
        K(c, rig, 3, body=dict(scale=(1.2, 1.2, 0.8), loc=(0, 0.1, 0)), glow=dict(scale=0.5))
        K(c, rig, 9, **rest)
    with rig.clip("death", 27) as c:                               # zerstäubt
        K(c, rig, 0, **rest)
        K(c, rig, 8, body=dict(scale=(1.3, 1.3, 1.2)), glow=dict(scale=1.6))
        K(c, rig, 18, _i="LINEAR", body=dict(scale=(1.6, 1.6, 0.6), loc=(0, 0, -0.3)), tail=dict(scale=0.4), glow=dict(scale=0.4))
        K(c, rig, 27, body=dict(scale=(1.8, 1.8, 0.1), loc=(0, 0, -0.6)), tail=dict(scale=0.05), glow=dict(scale=0.05), arm_l=dict(scale=0.05), arm_r=dict(scale=0.05))
    with rig.clip("blink", 15) as c:                               # nach dem Sprung: wirbelt aus dem Nichts zusammen
        K(c, rig, 0, **dict(rest, body=dict(scale=(0.2, 0.2, 0.2), rot=(0, 0, -120)), glow=dict(scale=0.2)))
        K(c, rig, 8, body=dict(scale=(1.15, 1.15, 1.15), rot=(0, 0, 20)), glow=dict(scale=1.4))
        K(c, rig, 15, **rest)
    spawn_clip(rig, rest, 0.4)
    rig.finish(icon_yaw=-30, icon_pitch=16)


# ================================================================= Schlackenkriecher (Sonderling)
def magma_schlackenkriecher():
    rig = Rig("magma_schlackenkriecher", role="special", size=1.4)
    segs = []
    for i in range(4):                                                                               # vier Schlackebrocken, von vorn nach hinten
        y = -0.55 + i * 0.42
        r = 0.36 - 0.04 * i
        p = Part()
        p.ball(r, (0, y, r * 0.95), (BAS, BAS_L, BAS, BAS_D)[i], scale=(1.05, 0.95, 0.9), subdiv=1)
        for k in range(3):
            a = k * 2.1 + i
            p.cone(0.07, 0.18, (r * 0.8 * math.cos(a), y + r * 0.4 * math.sin(a), r * 1.55), BAS_L, r=rot(0, 30 * math.cos(a), 0), sides=4)
        nm = "seg%d" % i
        rig.add(nm, p, parent=("seg%d" % (i - 1)) if i > 0 else None, pivot=(0, y - 0.2, r * 0.9))
        segs.append(nm)
    p = Part()                                                                                       # Gesicht vorn
    for s in (-1, 1):
        p.ball(0.07, (0.14 * s, -0.86, 0.45), "F8E8D0", subdiv=1)
        p.ball(0.035, (0.15 * s, -0.92, 0.45), INK, subdiv=1)
    p.box((0.24, 0.04, 0.05), (0, -0.88, 0.28), INK, bevel=0.0)
    for s in (-1, 1):
        p.cone(0.04, 0.14, (0.1 * s, -0.9, 0.24), ASH_L, r=rot(180, 0, 0), sides=3)
    rig.add("head", p, parent="seg0", pivot=(0, -0.75, 0.35))
    p = Part()                                                                                       # glühende Fugen zwischen den Brocken
    for i in range(3):
        y = -0.55 + i * 0.42 + 0.21
        p.torus(0.26 - 0.03 * i, 0.04, (0, y, 0.32), GLUT, r=rot(90, 0, 0), seg=10, tseg=3)
    rig.add("glow", p, parent="seg0", pivot=(0, -0.2, 0.32), glow=True)
    for i in range(4):                                                                               # Stummelbeine je Brocken
        y = -0.55 + i * 0.42
        for s in (1, -1):
            nm = "leg_%d%s" % (i, "l" if s > 0 else "r")
            p = Part()
            capsule(p, (0.26 * s, y, 0.18), (0.36 * s, y - 0.05, 0.02), 0.06, 0.05, BAS_D, sides=4)
            rig.add(nm, p, parent=segs[i], pivot=(0.26 * s, y, 0.18))
    rest = rest_pose(rig)
    with rig.clip("idle", 36, loop=True) as c:
        K(c, rig, 0, **rest)
        K(c, rig, 12, seg0=R(-6, 0, 6), head=R(-8, 0, 10), glow=dict(scale=1.2))
        K(c, rig, 24, seg0=R(4, 0, -6), seg2=R(0, 0, 8), glow=dict(scale=0.95))
    with rig.clip("walk", 24, loop=True, stride=2.2 * 24 / 30.0) as c:   # Raupenwelle
        K(c, rig, 0, **rest)
        for i, nm in enumerate(segs):
            c.wave(nm, rot=(10, 0, 4), loc=(0, 0, 0.05), phase=i * 0.22)
        for i in range(4):
            c.wave("leg_%dl" % i, rot=(40, 0, 0), phase=i * 0.25)
            c.wave("leg_%dr" % i, rot=(40, 0, 0), phase=i * 0.25 + 0.5)
    with rig.clip("attack", 24, hit=13) as c:                      # bäumt sich auf und kracht nieder
        K(c, rig, 0, **rest)
        K(c, rig, 8, seg0=R(-30, 0, 0), seg1=R(-20, 0, 0), head=R(-15, 0, 0))
        K(c, rig, 13, _i="LINEAR", seg0=R(18, 0, 0), seg1=R(8, 0, 0), head=R(10, 0, 0), glow=dict(scale=1.5))
        K(c, rig, 24, **rest)
    with rig.clip("hit", 9) as c:
        K(c, rig, 0, **rest)
        K(c, rig, 3, seg0=R(-10, 0, 12), seg1=R(0, 0, -10), seg2=R(0, 0, 10))
        K(c, rig, 9, **rest)
    with rig.clip("death", 30) as c:                               # zerfällt in einzelne Brocken
        K(c, rig, 0, **rest)
        K(c, rig, 8, glow=dict(scale=1.8), seg0=R(-10, 0, 0))
        K(c, rig, 18, _i="LINEAR", seg0=dict(rot=(0, 30, 20), loc=(0.2, 0, 0)), seg1=dict(rot=(0, -40, -30), loc=(-0.25, 0.05, 0)),
          seg2=dict(rot=(0, 45, 25), loc=(0.25, 0.05, 0)), seg3=dict(rot=(0, -35, -20), loc=(-0.2, 0.1, 0)), glow=dict(scale=0.3))
        K(c, rig, 30, seg0=dict(rot=(0, 34, 24), loc=(0.25, 0, -0.08)), seg1=dict(rot=(0, -44, -34), loc=(-0.3, 0.05, -0.06)),
          seg2=dict(rot=(0, 50, 28), loc=(0.3, 0.05, -0.06)), seg3=dict(rot=(0, -40, -22), loc=(-0.25, 0.1, -0.05)), glow=dict(scale=0.05))
    with rig.clip("steam", 30) as c:                               # Fugen glühen auf, die Brocken heben sich
        K(c, rig, 0, **rest)
        K(c, rig, 10, glow=dict(scale=1.8), seg1=dict(loc=(0, 0, 0.06)), seg3=dict(loc=(0, 0, 0.06)))
        K(c, rig, 20, glow=dict(scale=1.3), seg2=dict(loc=(0, 0, 0.06)))
        K(c, rig, 30, **rest)
    spawn_clip(rig, rest, 0.8)
    rig.finish(icon_yaw=-45, icon_pitch=20)


# ================================================================= Glutpriesterin (Heilerin)
def magma_glutpriesterin():
    rig = Rig("magma_glutpriesterin", role="healer")
    rig.node("hips", pivot=(0, 0, 0.75))
    p = Part()                                                                                       # Aschemantel mit Glutsaum
    lathe(p, [(0.5, 0.12, ASH_D), (0.46, 0.3, ASH), (0.36, 0.9, ASH), (0.3, 1.35, ASH_L), (0.2, 1.5, ASH)], sides=10)
    lathe(p, [(0.51, 0.1, GLUT_D), (0.51, 0.18, GLUT_D)], sides=10, cap=False)
    p.box((0.12, 0.04, 0.9), (0, -0.4, 0.75), SKIN_D, r=rot(-12, 0, 0), bevel=0.0)
    rig.add("body", p, parent="hips", pivot=(0, 0, 0.75))
    p = Part()                                                                                       # Kapuze mit Obsidianmaske
    p.ball(0.26, (0, 0.0, 1.7), ASH_D, scale=(1, 1, 1.15), subdiv=2)
    p.cone(0.18, 0.35, (0, 0.12, 1.98), ASH_D, r=rot(-30, 0, 0), sides=6)
    p.box((0.3, 0.06, 0.34), (0, -0.25, 1.66), OBS, bevel=0.05, segs=1)
    for s in (-1, 1):
        p.cone(0.04, 0.18, (0.12 * s, -0.22, 1.86), OBS_L, r=rot(-20, 25 * s, 0), sides=4)
    rig.add("head", p, parent="body", pivot=(0, 0, 1.5))
    p = Part()
    for s in (-1, 1):
        p.box((0.08, 0.03, 0.04), (0.08 * s, -0.29, 1.7), GLUT_L)
    rig.add("eyes", p, parent="head", pivot=(0, -0.29, 1.7), glow=True)
    for s, nm in ((1, "arm_l"), (-1, "arm_r")):
        p = Part()
        capsule(p, (0.26 * s, 0, 1.35), (0.22 * s, -0.32, 1.05), 0.07, 0.06, ASH, sides=5)
        p.ball(0.06, (0.2 * s, -0.36, 1.02), SKIN, subdiv=1)
        rig.add(nm, p, parent="body", pivot=(0.26 * s, 0, 1.35))
    p = Part()                                                                                       # Glutschale vor dem Bauch
    p.cyl(0.2, 0.12, (0, -0.42, 1.05), BAS_D, r2=0.12, sides=8)
    rig.add("tool", p, parent="arm_r", pivot=(0, -0.42, 1.05))
    p = Part()
    p.ball(0.15, (0, -0.42, 1.14), GLUT_L, scale=(1, 1, 0.6), subdiv=1)
    rig.add("glow", p, parent="tool", pivot=(0, -0.42, 1.14), glow=True)
    for s, nm in ((1, "leg_l"), (-1, "leg_r")):
        p = Part()
        capsule(p, (0.13 * s, 0, 0.72), (0.14 * s, 0, 0.1), 0.07, 0.06, BAS_D, sides=5)
        rig.add(nm, p, parent="hips", pivot=(0.13 * s, 0, 0.75))
    biped(rig, 0.75, 2.0, 2.0, "healer", walk_n=24, leg_swing=20, arm_swing=8, rest_extra={"arm_l": dict(rot=(-35, 0, -20)), "arm_r": dict(rot=(-35, 0, 20))})
    rig.finish(icon_yaw=-24, icon_pitch=12)


# ================================================================= Basaltschildträger (Schildträger)
def magma_basaltschild():
    rig = Rig("magma_basaltschild", role="shield")
    rig.node("hips", pivot=(0, 0, 0.8))
    p = Part()                                                                                       # gedrungener Leib aus Schlacke
    lathe(p, [(0.32, 0.75, BAS_D), (0.46, 0.95, BAS), (0.5, 1.35, BAS_L), (0.42, 1.65, BAS), (0.26, 1.78, BAS_D)], sides=8)
    lava_veins(p, [(0.2, -0.42, 1.0), (0.05, -0.47, 1.3), (0.22, -0.44, 1.55)], 0.03)
    rig.add("body", p, parent="hips", pivot=(0, 0, 0.8))
    p = Part()                                                                                       # Helmkopf mit Hörnern aus Obsidian
    lathe(p, [(0.22, 1.75, OBS), (0.27, 1.9, OBS), (0.24, 2.1, OBS_D), (0.1, 2.2, OBS), (0.0, 2.24, OBS)], sides=8)
    p.box((0.34, 0.06, 0.06), (0, -0.26, 1.96), INK, bevel=0.0)
    for s in (-1, 1):
        p.cone(0.06, 0.32, (0.24 * s, 0.0, 2.18), OBS_L, r=rot(0, 35 * s, 0), sides=4)
    rig.add("head", p, parent="body", pivot=(0, 0, 1.75))
    p = Part()
    for s in (-1, 1):
        p.ball(0.035, (0.08 * s, -0.28, 1.96), GLUT_L, subdiv=1)
    rig.add("glow", p, parent="head", pivot=(0, -0.28, 1.96), glow=True)
    p = Part()
    capsule(p, (0.42, 0, 1.55), (0.44, -0.35, 1.2), 0.1, 0.09, BAS, sides=5)
    rig.add("arm_l", p, parent="body", pivot=(0.42, 0, 1.55))
    p = Part()                                                                                       # sechseckige Basaltplatte als Schild
    p.cyl(0.72, 0.2, (0, 0, 0), BAS_L, r=T(0.12, -0.6, 1.15) @ rot(90, 0, 0), sides=6, bevel=0.05, segs=1)
    p.cyl(0.5, 0.22, (0, 0, 0), BAS, r=T(0.12, -0.62, 1.15) @ rot(90, 0, 0), sides=6)
    p.cyl(0.14, 0.26, (0, 0, 0), OBS, r=T(0.12, -0.66, 1.15) @ rot(90, 0, 0), sides=6)
    for k in range(3):
        a = k * 2.1 + 0.5
        p.box((0.36, 0.04, 0.04), (0.12 + 0.3 * math.cos(a), -0.72, 1.15 + 0.3 * math.sin(a)), GLUT, r=rot(0, math.degrees(a), 0))
    rig.add("shield", p, parent="arm_l", pivot=(0.44, -0.45, 1.2))
    p = Part()                                                                                       # Keule aus Schlacke
    capsule(p, (-0.42, 0, 1.55), (-0.46, -0.3, 1.2), 0.1, 0.09, BAS, sides=5)
    capsule(p, (-0.47, -0.35, 1.1), (-0.47, -0.55, 1.85), 0.05, 0.14, BAS_D, sides=6)
    rig.add("arm_r", p, parent="body", pivot=(-0.42, 0, 1.55))
    for s, nm in ((1, "leg_l"), (-1, "leg_r")):
        p = Part()
        capsule(p, (0.18 * s, 0, 0.78), (0.2 * s, 0, 0.12), 0.13, 0.11, BAS_D, sides=6)
        p.ball(0.14, (0.2 * s, -0.08, 0.08), OBS, scale=(1, 1.4, 0.55), subdiv=1)
        rig.add(nm, p, parent="hips", pivot=(0.18 * s, 0, 0.8))
    biped(rig, 0.8, 2.3, 1.5, "shield", walk_n=30, leg_swing=24, arm_swing=0)
    rig.finish(icon_yaw=-24, icon_pitch=12)


# ================================================================= Lavamutter (Brutmutter)
def magma_lavamutter():
    rig = Rig("magma_lavamutter", role="brood")
    p = Part()                                                                                       # mächtiger Fuß
    lathe(p, [(0.0, -1.1, SKIN_D), (0.36, -1.0, SKIN), (0.5, -0.5, SKIN), (0.52, 0.2, SKIN), (0.4, 0.75, SKIN_D), (0.0, 1.1, SKIN_D)],
          sides=9, loc=(0, 0, 0.35), r=rot(-90, 0, 0), sx=1.3, sy=0.7)
    rig.add("body", p, pivot=(0, 0, 0.35))
    p = Part()
    p.ball(0.42, (0, -0.98, 0.62), SKIN, scale=(1.0, 1.05, 0.9), subdiv=2)
    p.box((0.36, 0.05, 0.06), (0, -1.38, 0.55), INK, bevel=0.0)
    for s in (-1, 1):
        capsule(p, (0.18 * s, -1.08, 0.92), (0.3 * s, -1.2, 1.45), 0.06, 0.05, SKIN_D, sides=5)
        p.ball(0.13, (0.31 * s, -1.22, 1.52), "F8E8D0", subdiv=1)
        p.ball(0.06, (0.32 * s, -1.33, 1.53), INK, subdiv=1)
    rig.add("head", p, parent="body", pivot=(0, -0.75, 0.55))
    p = Part()                                                                                       # Kraterhaus (Brutsack)
    lathe(p, [(0.82, 0.5, BAS_D), (0.88, 0.7, BAS), (0.7, 1.3, BAS_L), (0.48, 1.75, BAS), (0.42, 1.84, BAS_D)], sides=10, loc=(0, 0.2, 0))
    for k in range(6):
        a = k * math.tau / 6 + 0.3
        p.cone(0.14, 0.32, (0.72 * math.cos(a), 0.2 + 0.72 * math.sin(a), 1.0), OBS, r=rot(0, 55, math.degrees(a)), sides=4)
    rig.add("prop", p, parent="body", pivot=(0, 0.2, 0.55))
    p = Part()                                                                                       # Eier im Krater und Lavarinnen
    p.cyl(0.38, 0.08, (0, 0.2, 1.82), GLUT, sides=10)
    for (x, y) in ((0.12, 0.25), (-0.14, 0.12), (0.0, 0.38)):
        p.ball(0.12, (x, y, 1.9), GLUT_L, scale=(1, 1, 1.25), subdiv=1)
    lava_veins(p, [(0.25, 0.0, 1.8), (0.5, -0.2, 1.3), (0.62, -0.3, 0.8)], 0.05)
    rig.add("glow", p, parent="prop", pivot=(0, 0.2, 1.82), glow=True)
    rest = rest_pose(rig)
    with rig.clip("idle", 42, loop=True) as c:
        K(c, rig, 0, **rest)
        K(c, rig, 14, prop=dict(scale=(1.03, 1.03, 0.98)), glow=dict(scale=1.25), head=R(0, 0, 10))
        K(c, rig, 28, prop=dict(scale=(0.98, 0.98, 1.03)), glow=dict(scale=0.95), head=R(-6, 0, -8))
    with rig.clip("walk", 30, loop=True, stride=1.3 * 30 / 30.0) as c:
        K(c, rig, 0, **rest)
        c.wave("body", scale=(0.0, 0.08, -0.05), n=2)
        c.wave("prop", rot=(4, 0, 3), loc=(0, 0.04, 0.03), n=2, phase=0.5)
        c.wave("head", rot=(6, 0, 6), phase=0.25)
    with rig.clip("attack", 24, hit=13) as c:
        K(c, rig, 0, **rest)
        K(c, rig, 8, head=dict(rot=(-24, 0, 0), loc=(0, 0.2, 0.12)))
        K(c, rig, 13, _i="LINEAR", head=dict(rot=(20, 0, 0), loc=(0, -0.35, -0.05)), body=dict(scale=(0.95, 1.1, 0.95)))
        K(c, rig, 24, **rest)
    with rig.clip("hit", 9) as c:
        K(c, rig, 0, **rest)
        K(c, rig, 3, head=dict(loc=(0, 0.15, -0.08)), prop=dict(rot=(-6, 0, 6)), glow=dict(scale=0.7))
        K(c, rig, 9, **rest)
    with rig.clip("death", 36) as c:
        K(c, rig, 0, **rest)
        K(c, rig, 12, prop=dict(rot=(-10, 25, 0)), glow=dict(scale=1.6))
        K(c, rig, 24, _i="LINEAR", prop=dict(rot=(10, 70, 0), loc=(-0.4, 0, -0.2)), body=dict(scale=(1.3, 1.15, 0.35)), head=dict(loc=(0, 0, -0.3)))
        K(c, rig, 36, prop=dict(rot=(10, 78, 0), loc=(-0.5, 0, -0.25)), body=dict(scale=(1.4, 1.2, 0.25)), glow=dict(scale=0.05))
    with rig.clip("brood", 30, hit=18) as c:                       # der Krater bebt, Junge kriechen heraus
        K(c, rig, 0, **rest)
        K(c, rig, 9, prop=dict(scale=(1.12, 1.12, 1.05)), glow=dict(scale=1.6), head=R(-14, 0, 0))
        K(c, rig, 14, prop=dict(scale=(1.25, 1.25, 1.15)), glow=dict(scale=2.0))
        K(c, rig, 18, _i="LINEAR", prop=dict(scale=(0.92, 0.92, 0.9)), glow=dict(scale=0.9))
        K(c, rig, 30, **rest)
    with rig.clip("steam", 30) as c:
        K(c, rig, 0, **rest)
        K(c, rig, 10, glow=dict(scale=1.7), prop=dict(scale=(1.05, 1.05, 1.06)))
        K(c, rig, 30, **rest)
    spawn_clip(rig, rest, 1.8)
    rig.finish(icon_yaw=-35, icon_pitch=16)


# ================================================================= Glutbrecher (Miniboss)
def magma_glutbrecher():
    rig = Rig("magma_glutbrecher", role="miniboss")
    p = Part()                                                                                       # Stier aus Basalt
    p.ball(1.15, (0, 0.2, 1.75), BAS, scale=(1, 1.35, 0.9), subdiv=2)
    p.ball(0.95, (0, -0.6, 2.0), BAS_L, scale=(1.1, 0.8, 0.95), subdiv=2)                              # Nackenbuckel
    for k in range(5):
        p.cone(0.16, 0.5, (0.0, -0.8 + k * 0.4, 2.75 - abs(k - 1) * 0.12), OBS, r=rot(-20 + k * 8, 0, 0), sides=5)
    rig.add("body", p, pivot=(0, 0, 1.7))
    p = Part()
    lava_veins(p, [(0.9, -0.3, 1.9), (1.0, 0.3, 1.6), (0.85, 0.9, 1.9)], 0.06)
    lava_veins(p, [(-0.9, -0.3, 1.9), (-1.0, 0.3, 1.6), (-0.85, 0.9, 1.9)], 0.06)
    rig.add("veins", p, parent="body", pivot=(0, 0, 1.7), glow=True)
    p = Part()                                                                                       # Kopf mit Magmahörnern
    p.ball(0.62, (0, -1.45, 1.75), BAS, scale=(1.0, 1.0, 0.95), subdiv=2)
    p.ball(0.42, (0, -1.92, 1.55), BAS_L, scale=(1.0, 0.8, 0.75), subdiv=1)                            # Schnauze
    for s in (-1, 1):
        capsule(p, (0.45 * s, -1.4, 2.05), (1.0 * s, -1.6, 2.35), 0.16, 0.11, OBS, sides=6)
        capsule(p, (1.0 * s, -1.6, 2.35), (1.05 * s, -1.9, 2.75), 0.11, 0.04, GLUT_D, sides=6)
    rig.add("head", p, parent="body", pivot=(0, -1.1, 1.85))
    p = Part()                                                                                       # Glutaugen, Nasenring, Hornspitzen
    for s in (-1, 1):
        p.ball(0.09, (0.3 * s, -1.98, 1.95), GLUT_L, subdiv=1)
        p.ball(0.09, (1.05 * s, -1.92, 2.78), GLUT_L, subdiv=1)
    p.torus(0.16, 0.04, (0, -2.25, 1.38), GLUT_L, r=rot(90, 0, 0), seg=10, tseg=3)
    rig.add("glow", p, parent="head", pivot=(0, -1.98, 1.9), glow=True)
    legs = []
    for (nm, x, y, ph, s) in (("leg_fl", 0.65, -0.65, 0.0, 1), ("leg_fr", -0.65, -0.65, 0.5, -1), ("leg_bl", 0.65, 1.0, 0.5, 1), ("leg_br", -0.65, 1.0, 0.0, -1)):
        p = Part()
        capsule(p, (x, y, 1.45), (x, y, 0.35), 0.3, 0.25, BAS_D, sides=7)
        p.cyl(0.3, 0.3, (x, y, 0.15), OBS, sides=8)                                                   # Hufe aus Obsidian
        rig.add(nm, p, parent="body", pivot=(x, y, 1.45))
        legs.append((nm, ph, s))
    p = Part()
    capsule(p, (0, 1.6, 1.9), (0, 2.1, 1.2), 0.07, 0.05, BAS_D, sides=5)
    p.ball(0.14, (0, 2.12, 1.12), GLUT, subdiv=1)
    rig.add("tail", p, parent="body", pivot=(0, 1.6, 1.9))

    def sp(name, c, rig, rest):
        if name == "skill":                                            # bäumt sich auf und stampft: Lava quillt
            K(c, rig, 10, body=dict(rot=(-30, 0, 0), loc=(0, 0.3, 0.45)), leg_fl=R(-55, 0, 0), leg_fr=R(-55, 0, 0), head=R(-30, 0, 0), glow=dict(scale=1.6))
            K(c, rig, 20, body=dict(rot=(-34, 0, 0), loc=(0, 0.3, 0.55)))
            K(c, rig, 27, body=dict(rot=(10, 0, 0), loc=(0, -0.1, -0.12)), leg_fl=R(12, 0, 0), leg_fr=R(12, 0, 0), head=R(18, 0, 0), _i="LINEAR")
        if name == "attack":
            K(c, rig, 7, head=R(-32, 0, 0))
            K(c, rig, 11, head=R(28, 0, 0), _i="LINEAR")
    quad(rig, legs, 1.45, 3.1, 1.4, "miniboss", walk_n=30, leg_swing=20, special=sp, hop=0.03)
    rig.finish(icon_yaw=-30, icon_pitch=14)


# ================================================================= Boss: Magmafürst Brodel
def boss_magma():
    rig = Rig("boss_magma", role="boss")
    rig.node("hips", pivot=(0, 0, 1.7))
    p = Part()                                                                                       # Vulkanleib
    lathe(p, [(0.9, 1.5, BAS_D), (1.3, 1.9, BAS), (1.55, 2.6, BAS_L), (1.45, 3.4, BAS), (1.05, 4.0, BAS_D), (0.7, 4.2, BAS_D)], sides=12, sy=0.85)
    for k in range(8):                                                                               # Felsplatten
        a = k * math.tau / 8 + 0.2
        p.box((0.6, 0.35, 0.7), (1.4 * math.cos(a), 1.2 * math.sin(a), 2.6 + 0.3 * (k % 2)), (BAS, BAS_L, BAS_D)[k % 3], r=rot(8 * (k % 3 - 1), 6, math.degrees(a) + 90), bevel=0.12, segs=1)
    for k in range(5):                                                                               # Obsidianzacken auf Rücken und Schultern
        x = -1.0 + k * 0.5
        p.cone(0.25, 0.9 + 0.3 * (k % 2), (x, 0.6, 3.9 - abs(k - 2) * 0.2), OBS, r=rot(-30, 12 * (k - 2), 0), sides=5)
    rig.add("torso", p, parent="hips", pivot=(0, 0, 1.7))
    p = Part()                                                                                       # Glutkern in der Brust (Schwachstelle) und Adern
    p.ball(0.55, (0, -1.15, 2.9), GLUT_L, scale=(1, 0.45, 1.1), subdiv=2)
    lava_veins(p, [(0, -1.2, 2.9), (0.6, -1.1, 3.5), (1.1, -0.95, 3.7)], 0.08)
    lava_veins(p, [(0, -1.2, 2.9), (-0.6, -1.1, 3.4), (-1.1, -0.95, 3.6)], 0.08)
    lava_veins(p, [(0, -1.2, 2.9), (0.3, -1.15, 2.2), (0.1, -1.1, 1.8)], 0.07)
    rig.add("core", p, parent="torso", pivot=(0, -1.15, 2.9), glow=True)
    p = Part()                                                                                       # Kopf: Kraterschädel, Lavabart, Obsidiankrone
    p.ball(0.75, (0, -0.4, 4.6), BAS, scale=(1.0, 0.9, 0.9), subdiv=2)
    p.box((0.7, 0.12, 0.12), (0, -1.08, 4.75), INK, bevel=0.0)                                         # Brauen
    for k in range(7):
        a = k * math.tau / 7
        obs = (0.55 * math.cos(a), -0.4 + 0.5 * math.sin(a), 5.2)
        p.cone(0.14, 0.7 + 0.3 * (k % 2), obs, OBS if k % 2 else OBS_L, r=rot(12 * math.sin(a), -12 * math.cos(a), 0), sides=5)
    p.cyl(0.62, 0.2, (0, -0.4, 5.05), OBS_D, sides=10)
    rig.add("head", p, parent="torso", pivot=(0, -0.3, 4.1))
    p = Part()                                                                                       # Augen und Lavabart
    for s in (-1, 1):
        p.ball(0.14, (0.28 * s, -1.05, 4.6), GLUT_L, scale=(1.2, 0.5, 0.9), subdiv=1)
    for k in range(5):
        x = -0.4 + k * 0.2
        p.cone(0.14, 0.7 - 0.12 * abs(k - 2), (x, -0.95, 4.0), (GLUT, GLUT_L)[k % 2], r=rot(180, 0, 0), sides=5)
    rig.add("eyes", p, parent="head", pivot=(0, -1.0, 4.4), glow=True)
    for s, nm in ((1, "arm_l"), (-1, "arm_r")):
        p = Part()
        p.ball(0.6, (1.7 * s, -0.1, 3.7), BAS_L, subdiv=2)
        capsule(p, (1.75 * s, -0.1, 3.5), (2.0 * s, -0.35, 2.5), 0.45, 0.4, BAS, sides=8)
        rig.add(nm, p, parent="torso", pivot=(1.7 * s, -0.1, 3.7))
        p = Part()
        capsule(p, (2.0 * s, -0.35, 2.5), (2.05 * s, -0.6, 1.6), 0.4, 0.36, BAS_D, sides=8)
        p.box((1.0, 1.0, 0.9), (2.05 * s, -0.7, 1.1), OBS, bevel=0.2, segs=1)                       # Faust aus Obsidian
        lava_veins(p, [(2.05 * s - 0.4, -1.21, 1.3), (2.05 * s, -1.22, 1.0), (2.05 * s + 0.35, -1.21, 1.25)], 0.06)
        rig.add(nm.replace("arm", "fore"), p, parent=nm, pivot=(2.0 * s, -0.35, 2.5))
    for s, nm in ((1, "leg_l"), (-1, "leg_r")):
        p = Part()
        capsule(p, (0.75 * s, 0, 1.6), (0.8 * s, 0, 0.5), 0.5, 0.45, BAS_D, sides=8)
        p.box((1.0, 1.2, 0.45), (0.8 * s, -0.15, 0.22), OBS, bevel=0.15, segs=1)
        rig.add(nm, p, parent="hips", pivot=(0.75 * s, 0, 1.7))
    rest = dict(root=dict(loc=(0, 0, 0), rot=(0, 0, 0)), hips=dict(loc=(0, 0, 0), rot=(0, 0, 0)), torso=R(), head=R(), arm_l=R(), arm_r=R(),
                fore_l=R(), fore_r=R(), leg_l=R(), leg_r=R(), core=dict(scale=1.0), eyes=dict(scale=1.0))
    with rig.clip("idle", 48, loop=True) as c:                     # brodelt, der Kern pulsiert
        c.key(0, **rest)
        c.key(12, torso=R(0, 3, 0), core=dict(scale=1.25), head=R(0, 0, 8))
        c.key(24, torso=R(-3, 0, 0), core=dict(scale=1.0), head=R(4, 0, 0))
        c.key(36, torso=R(0, -3, 0), core=dict(scale=1.25), head=R(0, 0, -8))
    with rig.clip("walk", 48, loop=True, stride=1.2 * 48 / 30.0) as c:
        c.wave("leg_l", rot=(26, 0, 0))
        c.wave("leg_r", rot=(26, 0, 0), phase=0.5)
        c.wave("arm_l", rot=(-18, 0, 0), phase=0.5)
        c.wave("arm_r", rot=(-18, 0, 0))
        c.wave("hips", rot=(0, 6, 0), phase=0.25)
        c.wave("hips", loc=(0, 0, 0.12), n=2, phase=0.25)
        c.wave("head", rot=(0, 0, 5), phase=0.5)
    with rig.clip("attack", 36, hit=20) as c:                      # Hammerfaust
        c.key(0, **rest)
        c.key(12, torso=R(-12, 0, -16), arm_r=R(-160, 0, 10), fore_r=R(-30, 0, 0))
        c.key(20, torso=R(18, 0, 10), arm_r=R(-50, 0, 0), fore_r=R(0, 0, 0), hips=dict(loc=(0, -0.2, -0.15)), _i="LINEAR")
        c.key(36, **rest)
    with rig.clip("hit", 9) as c:
        c.key(0, **rest)
        c.key(3, torso=R(-8, 0, 6), head=R(-16, 0, 8), core=dict(scale=1.5), eyes=dict(scale=1.4))
        c.key(9, **rest)
    with rig.clip("death", 60) as c:                               # der Kern erlischt, er sinkt auf die Knie und kippt vornüber
        c.key(0, **rest)
        c.key(12, torso=R(-12, 0, 0), head=R(-24, 0, 0), core=dict(scale=1.8), eyes=dict(scale=1.6))
        c.key(26, hips=dict(loc=(0, 0, -0.9)), leg_l=R(-80, 0, 0), leg_r=R(-80, 0, 0), torso=R(14, 0, 0), arm_l=R(-30, 0, 20), arm_r=R(-30, 0, -20), core=dict(scale=0.9), _i="LINEAR")
        c.key(44, root=dict(rot=(78, 0, 0), loc=(0, 2.2, 0.0)), hips=dict(loc=(0, 0, -0.9)), torso=R(10, 0, 0), arm_l=R(-160, 0, 20), arm_r=R(-160, 0, -20), _i="LINEAR")
        c.key(60, root=dict(rot=(80, 0, 0), loc=(0, 2.2, 0.0)), hips=dict(loc=(0, 0, -0.9)), core=dict(scale=0.1), eyes=dict(scale=0.05))
    with rig.clip("special", 45, hit=24) as c:                     # Ausbruch: reißt die Arme hoch, der Kern gleißt, Krone glüht
        c.key(0, **rest)
        c.key(12, arm_l=R(-170, 0, -25), arm_r=R(-170, 0, 25), torso=R(-16, 0, 0), head=R(-20, 0, 0), core=dict(scale=1.6), eyes=dict(scale=1.4))
        c.key(24, torso=R(-22, 0, 0), core=dict(scale=2.3), hips=dict(loc=(0, 0, 0.2)), _i="LINEAR")
        c.key(32, torso=R(-10, 0, 0), core=dict(scale=1.5))
        c.key(45, **rest)
    with rig.clip("summon", 39, hit=22) as c:                      # brüllt, Lavaschnecken kriechen aus dem Boden
        c.key(0, **rest)
        c.key(14, torso=R(-18, 0, 0), head=R(-28, 0, 0), arm_l=R(-120, 0, -50), arm_r=R(-120, 0, 50), core=dict(scale=1.4))
        c.key(22, torso=R(-20, 0, 0), head=R(-30, 0, 6), eyes=dict(scale=1.6))
        c.key(28, head=R(-30, 0, -6))
        c.key(39, **rest)
    with rig.clip("slam", 39, hit=24) as c:                        # beide Fäuste auf den Boden
        c.key(0, **rest)
        c.key(12, arm_l=R(-160, 0, -10), arm_r=R(-160, 0, 10), torso=R(-14, 0, 0), core=dict(scale=1.4))
        c.key(24, hips=dict(loc=(0, 0, -0.6)), leg_l=R(-40, 0, 0), leg_r=R(20, 0, 0), torso=R(34, 0, 0), arm_l=R(-40, 0, 0), arm_r=R(-40, 0, 0), core=dict(scale=2.0), _i="LINEAR")
        c.key(30, core=dict(scale=1.5))
        c.key(39, **rest)
    rig.finish(icon_yaw=-26, icon_pitch=10)


TABLE = {"magma_lavaschnecke": magma_lavaschnecke, "magma_feuerkaefer": magma_feuerkaefer, "magma_obsidiangolem": magma_obsidiangolem,
         "magma_glutspucker": magma_glutspucker, "magma_aschegeist": magma_aschegeist, "magma_schlackenkriecher": magma_schlackenkriecher,
         "magma_glutpriesterin": magma_glutpriesterin, "magma_basaltschild": magma_basaltschild, "magma_lavamutter": magma_lavamutter,
         "magma_glutbrecher": magma_glutbrecher, "boss_magma": boss_magma}

if __name__ == "__main__":
    run(TABLE, [a for a in sys.argv if not a.startswith("--")])
