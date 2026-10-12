"""Mutanten und kaputte Maschinen (Sumpfwerk): sechs Arten + Boss nach dem Muster von enemies_untote.py (siehe blender/GEGNER.md).
Aufruf:  python3 blender/enemies_mutanten.py [art ...] [--notafel]
"""
import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from animkit import *

# Farben der Familie: giftgrün, violett, Rohre, Blasen
TOX, TOX_D, TOX_L = "7ACC2E", "4E9A22", "C8FF5A"
PURP, PURP_D = "8A5AC8", "5E3A94"
PIPE, PIPE_D = "8E9AA6", "5E6A76"
RUST = "B5652E"
MUD, MUD_D = "7A5A3A", "5A4028"
GLOW = "C8FF3A"
INK = "16181E"
WHITE = "F8F8F0"
RED = "FF3A2A"


def R(x=0, y=0, z=0):
    return dict(rot=(x, y, z))


def spawn_clip(rig, depth=1.0, n=24):
    """Besonderer Clip „spawn“: taucht wackelnd aus dem Boden auf."""
    with rig.clip("spawn", n) as c:
        c.key(0, root=dict(loc=(0, 0, -depth), rot=(0, 0, -40), scale=(0.6, 0.6, 0.6)))
        c.key(int(n * 0.55), root=dict(loc=(0, 0, 0.15 * depth), rot=(0, 0, 15), scale=(0.95, 0.95, 1.12)))
        c.key(int(n * 0.8), root=dict(loc=(0, 0, 0), rot=(0, 0, -5), scale=(1.08, 1.08, 0.92)))
        c.key(n, root=dict(loc=(0, 0, 0), rot=(0, 0, 0), scale=(1, 1, 1)))


# ================================================================= Giftkröte (Masse): fett, drei Augen, leuchtende Warzen
def mutanten_giftkroete():
    rig = Rig("mutanten_giftkroete", role="mass")
    p = Part()
    p.ball(0.45, (0, 0.05, 0.42), TOX, scale=(1.1, 1.05, 0.8), subdiv=2)
    p.ball(0.36, (0, -0.15, 0.3), "E8F0A0", scale=(1.1, 0.9, 0.6), subdiv=1)                         # heller Bauch
    rig.add("body", p, pivot=(0, 0, 0.35))
    p = Part()                                                                                       # Warzen (leuchten)
    for (x, y, z) in ((0.25, 0.15, 0.7), (-0.3, 0.05, 0.68), (0.05, 0.35, 0.72), (0.38, -0.1, 0.55), (-0.38, 0.3, 0.55), (-0.1, 0.1, 0.78)):
        p.ball(0.06, (x, y, z), GLOW, subdiv=1)
    rig.add("warts", p, parent="body", pivot=(0, 0.1, 0.7), glow=True)
    p = Part()                                                                                       # Kopf: breites Maul, drei Glubschaugen
    p.ball(0.34, (0, -0.35, 0.55), TOX_D, scale=(1.2, 0.9, 0.7), subdiv=2)
    for (x, z) in ((-0.2, 0.78), (0.2, 0.78), (0.0, 0.88)):
        p.ball(0.11, (x, -0.42, z), TOX_D, subdiv=1)
        p.ball(0.09, (x, -0.49, z + 0.01), WHITE, scale=(1, 0.6, 1), subdiv=1)
    rig.add("head", p, parent="body", pivot=(0, -0.2, 0.5))
    p = Part()
    for (x, z) in ((-0.2, 0.79), (0.2, 0.79), (0.0, 0.89)):
        p.ball(0.045, (x, -0.55, z), INK, scale=(1, 0.5, 1.2), subdiv=1)
    rig.add("pupil", p, parent="head", pivot=(0, -0.55, 0.82), look=True)
    p = Part()                                                                                       # Unterkiefer mit Zunge
    p.ball(0.3, (0, -0.42, 0.42), TOX, scale=(1.2, 0.9, 0.35), subdiv=1)
    p.ball(0.08, (0, -0.62, 0.45), "F07AA0", scale=(1, 1.5, 0.4), subdiv=1)
    rig.add("jaw", p, parent="head", pivot=(0, -0.2, 0.45))
    for s, nm in ((1, "leg_bl"), (-1, "leg_br")):                                                   # kräftige Sprungbeine
        p = Part()
        p.ball(0.2, (0.38 * s, 0.25, 0.25), TOX_D, scale=(0.8, 1.2, 0.9), subdiv=1)
        p.ball(0.12, (0.45 * s, -0.05, 0.05), TOX, scale=(1.2, 1.8, 0.4), subdiv=1)
        rig.add(nm, p, parent="body", pivot=(0.35 * s, 0.25, 0.3))
    for s, nm in ((1, "leg_fl"), (-1, "leg_fr")):
        p = Part()
        capsule(p, (0.28 * s, -0.3, 0.3), (0.34 * s, -0.42, 0.05), 0.06, 0.05, TOX_D, sides=5)
        p.ball(0.08, (0.35 * s, -0.48, 0.03), TOX, scale=(1.2, 1.2, 0.4), subdiv=1)
        rig.add(nm, p, parent="body", pivot=(0.28 * s, -0.3, 0.3))
    legs = ["leg_bl", "leg_br", "leg_fl", "leg_fr"]
    rest = dict(root=dict(loc=(0, 0, 0), rot=(0, 0, 0)), body=dict(loc=(0, 0, 0), rot=(0, 0, 0), scale=1.0), head=R(), jaw=R(), warts=dict(scale=1.0), **{n: R() for n in legs})
    with rig.clip("idle", 36, loop=True) as c:                     # Kehle pumpt, Warzen pulsieren
        c.key(0, **rest)
        c.key(9, body=dict(scale=(1.04, 1.04, 0.96)), jaw=R(-8, 0, 0), warts=dict(scale=1.25))
        c.key(18, body=dict(scale=1.0), jaw=R(0, 0, 0), warts=dict(scale=1.0), head=R(0, 0, 8))
        c.key(27, body=dict(scale=(1.04, 1.04, 0.96)), jaw=R(-8, 0, 0), warts=dict(scale=1.25), head=R(0, 0, -6))
    with rig.clip("walk", 21, loop=True, stride=1.8) as c:         # hüpft in Sätzen
        c.key(0, root=dict(loc=(0, 0, 0)), body=dict(rot=(0, 0, 0), scale=(1.1, 1.1, 0.85)), leg_bl=R(0, 0, 0), leg_br=R(0, 0, 0), leg_fl=R(0, 0, 0), leg_fr=R(0, 0, 0))
        c.key(4, root=dict(loc=(0, 0, 0.2)), body=dict(rot=(-20, 0, 0), scale=(0.92, 0.92, 1.12)), leg_bl=R(50, 0, 0), leg_br=R(50, 0, 0), leg_fl=R(-30, 0, 0), leg_fr=R(-30, 0, 0))
        c.key(10, root=dict(loc=(0, 0, 0.55)), body=dict(rot=(-5, 0, 0), scale=1.0), leg_bl=R(70, 0, 0), leg_br=R(70, 0, 0))
        c.key(16, root=dict(loc=(0, 0, 0.12)), body=dict(rot=(15, 0, 0)), leg_fl=R(-50, 0, 0), leg_fr=R(-50, 0, 0), leg_bl=R(20, 0, 0), leg_br=R(20, 0, 0))
    with rig.clip("attack", 18, hit=9) as c:                       # Zungenschnapp
        c.key(0, **rest)
        c.key(6, head=R(-20, 0, 0), jaw=R(-10, 0, 0), body=dict(loc=(0, 0.1, 0)))
        c.key(9, head=R(10, 0, 0), jaw=R(30, 0, 0), body=dict(loc=(0, -0.25, 0)), _i="LINEAR")
        c.key(18, **rest)
    with rig.clip("hit", 9) as c:
        c.key(0, **rest)
        c.key(3, body=dict(scale=(1.2, 1.2, 0.75)), warts=dict(scale=1.6), head=R(-14, 0, 0))
        c.key(9, **rest)
    with rig.clip("death", 27) as c:                               # bläht sich auf und plumpst platt hin
        c.key(0, **rest)
        c.key(8, body=dict(scale=(1.3, 1.3, 1.3)), warts=dict(scale=1.8), jaw=R(20, 0, 0))
        c.key(14, body=dict(scale=(1.5, 1.5, 0.35), loc=(0, 0, -0.15)), head=R(30, 0, 0), _i="LINEAR")
        c.key(27, body=dict(scale=(1.5, 1.5, 0.3), loc=(0, 0, -0.18)), warts=dict(scale=0.2), **{n: R(0, 0, 0) for n in legs})
    spawn_clip(rig, 1.0)
    rig.finish()


# ================================================================= Blutegel-Schwarm (Flitzer): 8 Egel als kriechender Teppich
def mutanten_egelschwarm():
    rig = Rig("mutanten_egelschwarm", role="fast", size=1.6)
    rig.node("swarm", pivot=(0, 0, 0))
    names = []
    spots = [(0, -0.45), (0.3, -0.2), (-0.32, -0.15), (0.05, 0.05), (0.35, 0.25), (-0.3, 0.3), (0.0, 0.45), (0.15, -0.0)]
    for i, (x, y) in enumerate(spots):
        a = math.radians(i * 47 % 60 - 30)
        col = PURP if i % 2 else "B04A8A"
        p = Part()
        lathe(p, [(0.03, 0.0, col), (0.075, 0.08, col), (0.08, 0.2, PURP_D), (0.06, 0.32, col), (0.035, 0.38, "F07AA0")], sides=6, loc=(x, y + 0.2, 0.07), r=rot(90, 0, math.degrees(a)), sy=0.7)
        p.ball(0.022, (x + 0.03 * math.cos(a + 1.57), y - 0.17, 0.12), GLOW, subdiv=1)                # Leuchtpunkt-Augen
        p.ball(0.022, (x - 0.03 * math.cos(a + 1.57), y - 0.17, 0.12), GLOW, subdiv=1)
        nm = "leech%d" % i
        rig.add(nm, p, parent="swarm", pivot=(x, y, 0.07))
        names.append(nm)
    p = Part()                                                                                       # Schleimspur
    p.ball(0.5, (0, 0, 0.0), "6A8A3A", scale=(1.0, 1.15, 0.03), subdiv=1)
    rig.add("slime", p, parent="swarm", pivot=(0, 0, 0), ghost=True)
    rest = dict(root=dict(loc=(0, 0, 0), rot=(0, 0, 0)), swarm=dict(rot=(0, 0, 0), scale=1.0), **{n: dict(loc=(0, 0, 0), rot=(0, 0, 0), scale=1.0) for n in names})
    with rig.clip("idle", 30, loop=True) as c:                    # die Egel ringeln sich
        for i, n in enumerate(names):
            c.wave(n, rot=(0, 0, 25), scale=(0.0, 0.18, -0.1), phase=i / 8.0)
    with rig.clip("walk", 15, loop=True, stride=1.5) as c:         # raupenartig: strecken und stauchen versetzt
        for i, n in enumerate(names):
            c.wave(n, rot=(10, 0, 15), scale=(0.0, 0.35, 0.15), loc=(0, 0.04, 0.02), phase=i / 8.0)
        c.wave("swarm", rot=(0, 0, 6))
    with rig.clip("attack", 15, hit=8) as c:                       # springen gemeinsam nach vorn
        c.key(0, **rest)
        c.key(5, **{n: dict(rot=(-40, 0, 0), loc=(0, 0.05, 0.05)) for n in names})
        c.key(8, swarm=dict(scale=(1.1, 1.3, 1.0)), _i="LINEAR", **{n: dict(rot=(20, 0, 0), loc=(0, -0.3, 0.25)) for n in names})
        c.key(15, **rest)
    with rig.clip("hit", 9) as c:                                  # stieben kurz auseinander
        c.key(0, **rest)
        c.key(3, swarm=dict(scale=(1.35, 1.35, 1.0)), **{n: dict(loc=(0, 0, 0.12), rot=(0, 0, 40 * (1 if i % 2 else -1))) for i, n in enumerate(names)})
        c.key(9, **rest)
    with rig.clip("death", 24) as c:                               # rollen sich ein und verschrumpeln
        c.key(0, **rest)
        c.key(8, swarm=dict(scale=1.3), **{n: dict(rot=(0, 90, 30 * i), loc=(0, 0, 0.05)) for i, n in enumerate(names)})
        c.key(24, swarm=dict(scale=1.4), slime=dict(scale=(1.2, 1.2, 1.0)), **{n: dict(rot=(0, 90, 30 * i), loc=(0, 0, 0.0), scale=(0.6, 0.6, 0.3)) for i, n in enumerate(names)})
    spawn_clip(rig, 0.4, 15)
    rig.finish(icon_pitch=36)


# ================================================================= Schlammgolem (Brocken): Schlammberg mit Rohren und Ventilrad
def mutanten_schlammgolem():
    rig = Rig("mutanten_schlammgolem", role="tank")
    rig.node("hips", pivot=(0, 0, 1.0))
    p = Part()                                                                                       # Schlammleib, buckelig
    p.ball(1.05, (0, 0, 1.75), MUD, scale=(1.05, 0.95, 0.95), subdiv=3)
    for (x, y, z, r) in ((0.6, -0.4, 2.45, 0.35), (-0.55, 0.2, 2.5, 0.4), (0.1, 0.5, 2.6, 0.32), (-0.7, -0.5, 1.4, 0.3)):
        p.ball(r, (x, y, z), MUD_D, subdiv=1)
    for (x, y, z) in ((0.4, -0.8, 1.2), (-0.3, -0.85, 2.1), (0.8, -0.3, 1.9)):
        p.ball(0.1, (x, y, z), TOX_L, scale=(1, 0.5, 1), subdiv=1)                                    # Giftblasen
    capsule(p, (0.5, 0.3, 2.7), (0.6, 0.6, 3.25), 0.1, 0.1, PIPE, sides=6)                            # Rohr aus dem Rücken
    lathe(p, [(0.13, 3.25, PIPE_D), (0.16, 3.32, PIPE_D), (0.1, 3.36, INK)], sides=6, loc=(0.1, 0.3, 0))
    capsule(p, (-0.6, 0.4, 2.3), (-1.1, 0.6, 2.7), 0.08, 0.08, RUST, sides=6)
    rig.add("body", p, parent="hips", pivot=(0, 0, 1.2))
    p = Part()                                                                                       # Ventilrad im Bauch (dreht sich)
    p.torus(0.32, 0.05, (0, -0.98, 1.6), RED, r=rot(90, 0, 0), seg=12, tseg=4)
    for k in range(4):
        p.box((0.6, 0.05, 0.05), (0, -0.98, 1.6), RED, r=rot(0, k * 45, 0), bevel=0.0)
    p.cyl(0.08, 0.1, (0, -0.98, 1.6), PIPE, r=rot(90, 0, 0), sides=6)
    rig.add("valve", p, parent="body", pivot=(0, -0.98, 1.6))
    p = Part()                                                                                       # Gesicht: zwei leuchtende Glotzaugen, triefendes Maul
    for s in (-1, 1):
        p.ball(0.16, (0.3 * s, -0.86, 2.35), "FFF2A0", subdiv=1)
    rig.add("eyes", p, parent="body", pivot=(0, -0.86, 2.35), glow=True)
    p = Part()
    for s in (-1, 1):
        p.ball(0.07, (0.3 * s, -1.0, 2.35), INK, subdiv=1)
    rig.add("pupil", p, parent="eyes", pivot=(0, -1.0, 2.35), look=True)
    p = Part()
    p.ball(0.25, (0, -0.92, 2.05), "3A2418", scale=(1.4, 0.4, 0.5), subdiv=1)
    p.cone(0.06, 0.3, (0.15, -0.95, 1.85), MUD_D, r=rot(180, 0, 0), sides=5)
    rig.add("mouth", p, parent="body", pivot=(0, -0.9, 2.1))
    for s, nm in ((1, "arm_l"), (-1, "arm_r")):                                                     # Schlammarme mit Rohrstück
        p = Part()
        p.ball(0.4, (1.0 * s, -0.1, 2.0), MUD_D, subdiv=2)
        capsule(p, (1.05 * s, -0.1, 1.8), (1.25 * s, -0.3, 1.0), 0.32, 0.28, MUD, sides=7)
        p.ball(0.4, (1.27 * s, -0.35, 0.85), MUD_D, scale=(1, 1, 0.8), subdiv=2)
        p.cyl(0.2, 0.25, (1.25 * s, -0.25, 1.35), PIPE_D, r=face_to((0.2 * s, -0.2, -0.8)), sides=8)
        rig.add(nm, p, parent="body", pivot=(1.0 * s, -0.1, 2.0))
    for s, nm in ((1, "leg_l"), (-1, "leg_r")):
        p = Part()
        p.ball(0.42, (0.48 * s, 0, 0.42), MUD_D, scale=(1, 1.1, 1.0), subdiv=2)
        p.ball(0.36, (0.5 * s, -0.12, 0.14), MUD, scale=(1.1, 1.3, 0.4), subdiv=1)
        rig.add(nm, p, parent="hips", pivot=(0.48 * s, 0, 0.9))
    rest = dict(root=dict(loc=(0, 0, 0), rot=(0, 0, 0)), hips=dict(loc=(0, 0, 0), rot=(0, 0, 0)), body=dict(rot=(0, 0, 0), scale=1.0), valve=R(), arm_l=R(), arm_r=R(), leg_l=R(), leg_r=R(), mouth=dict(rot=(0, 0, 0), scale=1.0), eyes=dict(scale=1.0))
    with rig.clip("idle", 48, loop=True) as c:                     # blubbert, das Ventil dreht sich, Schlamm tropft
        c.key(0, **rest)
        c.key(12, body=dict(scale=(1.03, 1.03, 0.97)), valve=R(0, 90, 0), mouth=dict(scale=(1.1, 1, 1.3)))
        c.key(24, body=dict(scale=(0.98, 0.98, 1.03)), valve=R(0, 180, 0), mouth=dict(scale=1.0))
        c.key(36, body=dict(scale=(1.03, 1.03, 0.97)), valve=R(0, 270, 0), eyes=dict(scale=(1, 1, 0.3)))
        c.key(39, eyes=dict(scale=1.0))
    with rig.clip("walk", 45, loop=True, stride=1.6) as c:         # wälzt sich vorwärts
        c.wave("leg_l", rot=(26, 0, 0))
        c.wave("leg_r", rot=(26, 0, 0), phase=0.5)
        c.wave("hips", rot=(0, 7, 0), phase=0.25)
        c.wave("body", scale=(0.04, 0.04, -0.04), n=2)
        c.wave("arm_l", rot=(-18, 0, 0), phase=0.5)
        c.wave("arm_r", rot=(-18, 0, 0))
        c.wave("valve", rot=(0, 60, 0), n=1)
    with rig.clip("attack", 39, hit=22) as c:                      # Doppelfaust von oben
        c.key(0, **rest)
        c.key(14, body=dict(rot=(-14, 0, 0)), arm_l=R(-150, 0, -20), arm_r=R(-150, 0, 20), mouth=dict(scale=(1.2, 1, 1.6)))
        c.key(22, body=dict(rot=(20, 0, 0)), arm_l=R(-50, 0, 0), arm_r=R(-50, 0, 0), hips=dict(loc=(0, -0.2, -0.15)), _i="LINEAR")
        c.key(39, **rest)
    with rig.clip("hit", 9) as c:
        c.key(0, **rest)
        c.key(3, body=dict(rot=(-8, 0, 6), scale=(1.1, 1.1, 0.88)), valve=R(0, 60, 0))
        c.key(9, **rest)
    with rig.clip("death", 42) as c:                               # zerfließt (teilt sich danach in zwei Kleine)
        c.key(0, **rest)
        c.key(12, body=dict(scale=(1.15, 1.15, 0.85)), arm_l=R(0, 30, 0), arm_r=R(0, -30, 0), eyes=dict(scale=1.4))
        c.key(30, hips=dict(loc=(0, 0, -0.8)), body=dict(scale=(1.6, 1.6, 0.35)), arm_l=R(0, 70, 0), arm_r=R(0, -70, 0), valve=R(0, 300, 0), _i="LINEAR")
        c.key(42, hips=dict(loc=(0, 0, -0.9)), body=dict(scale=(1.7, 1.7, 0.25)), eyes=dict(scale=0.1), valve=R(0, 340, 0))
    spawn_clip(rig, 2.0, 30)
    rig.finish(icon_yaw=-28, icon_pitch=12)


# ================================================================= Rohrspucker (Fernkampf): Mutant mit Rohr aus dem Rücken
def mutanten_rohrspucker():
    rig = Rig("mutanten_rohrspucker", role="ranged")
    SK, SK_D = "A8D86A", "7AAE48"
    rig.node("hips", pivot=(0, 0, 0.65))
    p = Part()                                                                                       # bucklig, Latzhose
    lathe(p, [(0.24, 0.6, "3A6AA8"), (0.32, 0.72, "3A6AA8"), (0.36, 0.95, "4A7AB8"), (0.34, 1.15, SK), (0.24, 1.32, SK)], sides=8, sy=0.85)
    p.ball(0.3, (0, 0.18, 1.2), SK_D, scale=(1.1, 0.9, 0.9), subdiv=1)                               # Buckel
    for s in (-1, 1):
        p.box((0.06, 0.04, 0.4), (0.15 * s, -0.27, 1.05), "2A4A80", bevel=0.0)                     # Träger
    rig.add("body", p, parent="hips", pivot=(0, 0, 0.65))
    p = Part()                                                                                       # das Rohr: Krümmer mit Ventil und Trichtermündung
    capsule(p, (0, 0.3, 1.25), (0, 0.45, 1.75), 0.1, 0.1, PIPE, sides=7)
    capsule(p, (0, 0.45, 1.75), (0, 0.15, 2.05), 0.1, 0.1, PIPE, sides=7)
    lathe(p, [(0.1, 0.0, PIPE_D), (0.16, 0.12, PIPE_D), (0.2, 0.2, RUST)], sides=8, loc=(0, 0.12, 2.06), r=face_to((0, -0.6, 0.5)))
    p.torus(0.11, 0.035, (0, 0.38, 1.55), RED, r=face_to((0, 0.3, 1.0)), seg=8, tseg=3)
    p.ball(0.06, (0.07, -0.0, 2.15), TOX_L, subdiv=1)                                                 # Säuretropfen
    rig.add("pipe", p, parent="body", pivot=(0, 0.3, 1.25))
    p = Part()                                                                                       # Kopf: schief, Gasmaske halb, ein großes Auge
    p.ball(0.24, (0, -0.05, 1.45), SK, scale=(1, 0.95, 1), subdiv=2)
    p.ball(0.11, (0.08, -0.24, 1.52), WHITE, scale=(1, 0.5, 1), subdiv=1)
    p.ball(0.05, (-0.1, -0.23, 1.5), WHITE, scale=(1, 0.5, 1), subdiv=1)
    p.cyl(0.1, 0.12, (0, -0.25, 1.33), PIPE_D, r=rot(90, 0, 0), sides=7)                            # Maskenfilter
    p.cyl(0.06, 0.02, (0, -0.32, 1.33), TOX_D, r=rot(90, 0, 0), sides=7)
    rig.add("head", p, parent="body", pivot=(0, 0, 1.3))
    p = Part()
    p.ball(0.05, (0.08, -0.29, 1.52), INK, scale=(1, 0.5, 1), subdiv=1)
    p.ball(0.025, (-0.1, -0.26, 1.5), INK, scale=(1, 0.5, 1), subdiv=1)
    rig.add("pupil", p, parent="head", pivot=(0, -0.28, 1.51), look=True)
    for s, nm in ((1, "arm_l"), (-1, "arm_r")):                                                     # lange Arme, Knöchel schleifen fast
        p = Part()
        capsule(p, (0.3 * s, 0, 1.2), (0.42 * s, -0.1, 0.75), 0.07, 0.06, SK, sides=5)
        capsule(p, (0.42 * s, -0.1, 0.75), (0.44 * s, -0.15, 0.4), 0.06, 0.05, SK_D, sides=5)
        p.ball(0.1, (0.45 * s, -0.17, 0.33), SK, subdiv=1)
        rig.add(nm, p, parent="body", pivot=(0.3 * s, 0, 1.2))
    for s, nm in ((1, "leg_l"), (-1, "leg_r")):
        p = Part()
        capsule(p, (0.14 * s, 0, 0.62), (0.16 * s, 0, 0.12), 0.08, 0.07, "3A6AA8", sides=5)
        p.ball(0.11, (0.16 * s, -0.08, 0.06), "4A3A2A", scale=(1, 1.5, 0.6), subdiv=1)                  # Gummistiefel
        rig.add(nm, p, parent="hips", pivot=(0.14 * s, 0, 0.65))
    rest = dict(root=dict(loc=(0, 0, 0), rot=(0, 0, 0)), hips=dict(loc=(0, 0, 0), rot=(0, 0, 0)), body=dict(rot=(10, 0, 0), scale=1.0), pipe=dict(rot=(0, 0, 0), scale=1.0), head=R(-10, 0, 0), arm_l=R(), arm_r=R(), leg_l=R(), leg_r=R())
    with rig.clip("idle", 36, loop=True) as c:                     # das Rohr gluckert, er kratzt sich
        c.key(0, **rest)
        c.key(9, pipe=dict(scale=(1.06, 1.06, 1.0)), head=R(-10, 0, 12))
        c.key(14, arm_r=R(-120, 0, 30), pipe=dict(scale=1.0))
        c.key(20, arm_r=R(-130, 0, 20))
        c.key(26, arm_r=R(0, 0, 0), head=R(-6, 0, -8))
    with rig.clip("walk", 24, loop=True, stride=1.4) as c:          # watschelt bucklig
        c.wave("leg_l", rot=(34, 0, 0))
        c.wave("leg_r", rot=(34, 0, 0), phase=0.5)
        c.wave("arm_l", rot=(-26, 0, 0), phase=0.5)
        c.wave("arm_r", rot=(-26, 0, 0))
        c.wave("body", rot=(0, 7, 0), base_rot=(14, 0, 0), phase=0.25)
        c.wave("hips", loc=(0, 0, 0.05), n=2, phase=0.25)
        c.wave("pipe", rot=(6, 0, 0), n=2)
    with rig.clip("attack", 36, hit=22) as c:                      # beugt sich vor, das Rohr bläht sich und spuckt im Bogen
        c.key(0, **rest)
        c.key(12, body=dict(rot=(40, 0, 0)), pipe=dict(scale=(1.0, 1.0, 1.0)), arm_l=R(-20, 0, 20), arm_r=R(-20, 0, -20), head=R(-30, 0, 0))
        c.key(19, pipe=dict(scale=(1.25, 1.25, 0.9)), body=dict(rot=(46, 0, 0)))
        c.key(22, pipe=dict(scale=(0.85, 0.85, 1.15)), body=dict(rot=(30, 0, 0)), _i="LINEAR")
        c.key(36, **rest)
    with rig.clip("hit", 9) as c:
        c.key(0, **rest)
        c.key(3, body=dict(rot=(-8, 0, 8)), head=R(-30, 0, 10), pipe=dict(rot=(10, 0, 0)))
        c.key(9, **rest)
    with rig.clip("death", 33) as c:                               # kippt aufs Gesicht, das Rohr pfeift aus
        c.key(0, **rest)
        c.key(8, body=dict(rot=(-10, 0, 0)), head=R(-30, 0, 0), arm_l=R(-60, 0, 30), arm_r=R(-60, 0, -30))
        c.key(20, root=dict(rot=(84, 0, 0), loc=(0, 0, 0.3)), body=dict(rot=(0, 0, 0)), _i="LINEAR")
        c.key(24, root=dict(rot=(78, 0, 0), loc=(0, 0, 0.36)), pipe=dict(scale=1.2))
        c.key(33, root=dict(rot=(86, 0, 0), loc=(0, 0, 0.3)), pipe=dict(scale=0.8), arm_l=R(-150, 0, 20), arm_r=R(-150, 0, -20))
    spawn_clip(rig, 1.6)
    rig.finish()


# ================================================================= Werksdrohne (Flieger): verrostet, rotes Auge, Funkenschweif
def mutanten_werksdrohne():
    rig = Rig("mutanten_werksdrohne", role="air")
    p = Part()                                                                                       # Gehäuse: verbeulte Kugel mit Ringen
    p.ball(0.36, (0, 0, 0.8), PIPE, scale=(1, 1, 0.85), subdiv=2)
    p.torus(0.37, 0.04, (0, 0, 0.8), RUST, seg=14, tseg=4)
    p.box((0.2, 0.15, 0.1), (0, 0.3, 0.95), "F2C230", bevel=0.0)              # Warnplakette
    p.ball(0.1, (0.22, 0.2, 1.0), RUST, scale=(1, 1, 0.4), subdiv=1)                                 # Rostfleck
    p.cyl(0.03, 0.25, (0.12, 0.05, 1.18), PIPE_D, sides=4)                                            # Antenne
    p.ball(0.04, (0.12, 0.05, 1.32), RED, subdiv=1)
    p.cyl(0.07, 0.12, (0, 0, 0.42), PIPE_D, sides=6)                                                 # Kanone unten
    capsule(p, (0, -0.05, 0.42), (0, -0.4, 0.42), 0.035, 0.03, INK, sides=5)
    rig.add("body", p, pivot=(0, 0, 0.8))
    p = Part()                                                                                       # großes rotes Auge
    p.cyl(0.17, 0.08, (0, -0.33, 0.82), PIPE_D, r=rot(90, 0, 0), sides=10)
    rig.add("socket", p, parent="body", pivot=(0, -0.33, 0.82))
    p = Part()
    p.ball(0.12, (0, -0.37, 0.82), RED, scale=(1, 0.5, 1), subdiv=1)
    rig.add("eye", p, parent="socket", pivot=(0, -0.38, 0.82), glow=True, look=True)
    for k, (x, y) in enumerate(((0.45, 0.3), (-0.45, 0.3), (0.45, -0.3), (-0.45, -0.3))):         # vier Rotoren an Armen
        p = Part()
        capsule(p, (0, 0, 0.9), (x, y, 1.0), 0.035, 0.035, PIPE_D, sides=4)
        p.cyl(0.06, 0.08, (x, y, 1.02), PIPE_D, sides=6)
        rig.add("arm%d" % k, p, parent="body", pivot=(0, 0, 0.9))
        p = Part()
        p.box((0.42, 0.06, 0.015), (x, y, 1.08), "D8D8D8" if k % 2 else RUST, bevel=0.0)
        p.box((0.06, 0.42, 0.015), (x, y, 1.08), "D8D8D8" if k % 2 else RUST, bevel=0.0)
        rig.add("rotor%d" % k, p, parent="arm%d" % k, pivot=(x, y, 1.08))
    p = Part()                                                                                       # Funkenschweif
    for k in range(4):
        p.ball(0.05 - k * 0.008, (0.04 * (k % 2), 0.35 + k * 0.14, 0.7 - k * 0.04), ["FFE04A", "FFB03A", "FF7A2A", "FF5A2A"][k], subdiv=1)
    rig.add("sparks", p, parent="body", pivot=(0, 0.35, 0.7), glow=True)
    rotors = ["rotor%d" % k for k in range(4)]
    rest = dict(root=dict(loc=(0, 0, 0), rot=(0, 0, 0)), body=dict(rot=(0, 0, 0), loc=(0, 0, 0)), socket=R(), sparks=dict(scale=1.0, rot=(0, 0, 0)))

    def spin(c, n):
        for k, r in enumerate(rotors):
            c.key(0, _i="LINEAR", **{r: R(0, 0, 0)})
            c.key(n, _i="LINEAR", **{r: R(0, 0, 720 * (1 if k % 2 else -1))})
    with rig.clip("idle", 24, loop=True) as c:                     # schwebt, wackelt, das Auge sucht
        spin(c, 24)
        c.key(0, body=dict(rot=(0, 0, 0), loc=(0, 0, 0)), socket=R(0, 0, 0), sparks=dict(scale=1.0))
        c.key(8, body=dict(rot=(4, 6, 0), loc=(0, 0, 0.06)), socket=R(0, 0, 25), sparks=dict(scale=0.6))
        c.key(16, body=dict(rot=(-4, -6, 0), loc=(0, 0, -0.04)), socket=R(0, 0, -25), sparks=dict(scale=1.2))
    with rig.clip("walk", 18, loop=True, stride=1.8) as c:          # nach vorn gekippt, Funken sprühen
        spin(c, 18)
        c.key(0, body=dict(rot=(-18, 0, 0), loc=(0, 0, 0)), sparks=dict(scale=1.2, rot=(0, 0, 0)))
        c.key(9, body=dict(rot=(-22, 4, 0), loc=(0, 0, 0.05)), sparks=dict(scale=0.8, rot=(0, 0, 40)))
    with rig.clip("attack", 21, hit=10) as c:                      # zielt, Rückstoß, weicht seitlich aus
        spin(c, 21)
        c.key(0, **rest)
        c.key(7, body=dict(rot=(14, 0, 0)), socket=dict(rot=(0, 0, 0)))
        c.key(10, body=dict(rot=(-14, 0, 0), loc=(0, 0.2, 0)), _i="LINEAR")
        c.key(16, body=dict(rot=(0, 30, 0), loc=(0.5, 0.1, 0)))
        c.key(21, **rest)
    with rig.clip("hit", 9) as c:
        spin(c, 9)
        c.key(0, **rest)
        c.key(3, body=dict(rot=(20, -25, 10), loc=(0, 0.12, 0.08)), sparks=dict(scale=2.0))
        c.key(9, **rest)
    with rig.clip("death", 27) as c:                               # qualmt, trudelt, Rotoren bleiben stehen
        c.key(0, **rest)
        c.key(10, body=dict(rot=(30, 80, 0)), sparks=dict(scale=2.4), **{r: R(0, 0, 400) for r in rotors})
        c.key(20, root=dict(rot=(0, 160, 40), loc=(0, 0, 1.3)), body=dict(rot=(40, 90, 0)), **{r: R(0, 0, 480) for r in rotors})
        c.key(27, root=dict(rot=(0, 170, 40), loc=(0, 0, 1.35)), sparks=dict(scale=0.05), socket=dict(rot=(0, 0, 0)))
    spawn_clip(rig, 0.6, 18)
    rig.finish(icon_pitch=22)


# ================================================================= Seuchenarzt (Sonder): Schnabelmaske, Laterne, Kanister
def mutanten_seuchenarzt():
    rig = Rig("mutanten_seuchenarzt", role="special")
    COAT, COAT_D = "3A3A4A", "26262E"
    LEATHER = "8A5A30"
    rig.node("hips", pivot=(0, 0, 0.8))
    p = Part()                                                                                       # langer Mantel
    lathe(p, [(0.42, 0.12, COAT_D), (0.4, 0.3, COAT), (0.32, 0.9, COAT), (0.3, 1.3, COAT_D), (0.34, 1.5, COAT), (0.2, 1.62, COAT)], sides=10, sy=0.85)
    p.box((0.5, 0.06, 0.06), (0, -0.28, 0.95), LEATHER, bevel=0.0)                                  # Gürtel
    p.box((0.1, 0.07, 0.08), (0, -0.3, 0.95), "F2C230", bevel=0.0)
    for k in range(3):
        p.ball(0.04, (0, -0.31, 1.15 + k * 0.13), "C8C0A8", subdiv=1)                               # Knöpfe
    lathe(p, [(0.2, 0.0, TOX_D), (0.22, 0.4, TOX), (0.18, 0.5, PIPE)], sides=8, loc=(0, 0.38, 0.85))   # Giftkanister auf dem Rücken
    p.box((0.3, 0.06, 0.06), (0, 0.38, 1.3), PIPE_D, bevel=0.0)
    rig.add("body", p, parent="hips", pivot=(0, 0, 0.8))
    p = Part()                                                                                       # Kanister-Inhalt leuchtet
    p.ball(0.14, (0, 0.2, 1.05), TOX_L, scale=(1, 0.4, 1.3), subdiv=1)
    rig.add("tank", p, parent="body", pivot=(0, 0.2, 1.05), glow=True)
    p = Part()                                                                                       # Kopf: Hut, Schnabelmaske, Brillengläser
    p.ball(0.22, (0, 0, 1.78), "D8CDB0", subdiv=2)
    lathe(p, [(0.1, 0.0, "D8CDB0"), (0.07, 0.25, "C8BC9C"), (0.0, 0.45, "B8AC8C")], sides=7, loc=(0, -0.17, 1.72), r=rot(100, 0, 0), sy=0.8)
    lathe(p, [(0.36, 1.92, COAT_D), (0.37, 1.95, COAT), (0.2, 1.97, COAT_D), (0.2, 2.25, COAT), (0.21, 2.28, COAT_D)], sides=10)
    p.torus(0.205, 0.03, (0, 0, 2.0), RED, seg=10, tseg=3)                                            # Hutband
    for s in (-1, 1):
        p.cyl(0.07, 0.04, (0.09 * s, -0.18, 1.83), LEATHER, r=rot(80, 0, 0), sides=8)
    rig.add("head", p, parent="body", pivot=(0, 0, 1.6))
    p = Part()
    for s in (-1, 1):
        p.cyl(0.055, 0.02, (0.09 * s, -0.205, 1.83), GLOW, r=rot(80, 0, 0), sides=8)
    rig.add("eyes", p, parent="head", pivot=(0, -0.21, 1.83), glow=True)
    p = Part()                                                                                       # Arm mit Laterne
    capsule(p, (0.32, 0, 1.45), (0.45, -0.2, 1.1), 0.07, 0.06, COAT, sides=5)
    p.ball(0.07, (0.46, -0.24, 1.07), "2A2A2A", subdiv=1)
    capsule(p, (0.46, -0.26, 1.05), (0.46, -0.28, 0.9), 0.015, 0.015, PIPE_D, sides=4)
    lathe(p, [(0.0, 0.0, PIPE_D), (0.08, 0.02, PIPE_D), (0.08, 0.05, TOX_L), (0.07, 0.2, TOX_L), (0.09, 0.22, PIPE_D), (0.0, 0.28, PIPE_D)], sides=6, loc=(0.46, -0.28, 0.6))
    rig.add("arm_l", p, parent="body", pivot=(0.32, 0, 1.45))
    p = Part()
    p.ball(0.07, (0.46, -0.28, 0.72), "E8FF8A", subdiv=1)
    rig.add("lamp", p, parent="arm_l", pivot=(0.46, -0.28, 0.72), glow=True)
    p = Part()                                                                                       # Arm mit Spritze
    capsule(p, (-0.32, 0, 1.45), (-0.45, -0.2, 1.1), 0.07, 0.06, COAT, sides=5)
    p.ball(0.07, (-0.46, -0.24, 1.07), "2A2A2A", subdiv=1)
    capsule(p, (-0.46, -0.3, 1.07), (-0.46, -0.6, 1.07), 0.04, 0.04, "C8F0FF", sides=6)
    p.cone(0.01, 0.15, (-0.46, -0.68, 1.07), PIPE, r=rot(90, 0, 0), sides=4)
    rig.add("arm_r", p, parent="body", pivot=(-0.32, 0, 1.45))
    for s, nm in ((1, "leg_l"), (-1, "leg_r")):
        p = Part()
        capsule(p, (0.12 * s, 0, 0.3), (0.13 * s, 0, 0.1), 0.07, 0.07, LEATHER, sides=5)
        p.ball(0.1, (0.13 * s, -0.08, 0.06), "3A2A1A", scale=(0.9, 1.6, 0.6), subdiv=1)
        rig.add(nm, p, parent="hips", pivot=(0.12 * s, 0, 0.35))
    rest = dict(root=dict(loc=(0, 0, 0), rot=(0, 0, 0)), hips=dict(loc=(0, 0, 0), rot=(0, 0, 0)), body=dict(rot=(4, 0, 0)), head=R(), arm_l=R(), arm_r=R(), leg_l=R(), leg_r=R(), lamp=dict(scale=1.0), tank=dict(scale=1.0))
    with rig.clip("idle", 42, loop=True) as c:                     # schwenkt die Laterne, Kopf nickt
        c.key(0, **rest)
        c.key(10, arm_l=R(-20, 0, 10), head=R(10, 0, 10), lamp=dict(scale=1.3), tank=dict(scale=1.2))
        c.key(21, arm_l=R(10, 0, -5), head=R(0, 0, 0), lamp=dict(scale=1.0), tank=dict(scale=1.0))
        c.key(31, arm_l=R(-20, 0, 10), head=R(10, 0, -12), lamp=dict(scale=1.3))
    with rig.clip("walk", 24, loop=True, stride=1.4) as c:          # schleicht geduckt, die Laterne pendelt
        c.wave("leg_l", rot=(32, 0, 0))
        c.wave("leg_r", rot=(32, 0, 0), phase=0.5)
        c.wave("arm_l", rot=(16, 0, 0), base_rot=(-30, 0, 0), phase=0.3)
        c.wave("arm_r", rot=(-20, 0, 0), phase=0.0)
        c.wave("body", rot=(0, 6, 0), base_rot=(12, 0, 0), phase=0.25)
        c.wave("hips", loc=(0, 0, 0.04), n=2, phase=0.25)
        c.wave("head", rot=(8, 0, 0), n=2)
    with rig.clip("attack", 24, hit=12) as c:                      # sticht mit der Spritze zu
        c.key(0, **rest)
        c.key(8, arm_r=R(-40, 0, -40), body=dict(rot=(-6, 0, -12)))
        c.key(12, arm_r=R(-90, 0, 20), body=dict(rot=(16, 0, 10)), hips=dict(loc=(0, -0.2, 0)), _i="LINEAR")
        c.key(24, **rest)
    with rig.clip("hit", 9) as c:
        c.key(0, **rest)
        c.key(3, body=dict(rot=(-14, 0, 8)), head=R(-24, 0, 14), lamp=dict(scale=0.5))
        c.key(9, **rest)
    with rig.clip("death", 33) as c:                               # dreht sich, der Hut rutscht, sackt im Mantel zusammen
        c.key(0, **rest)
        c.key(10, root=dict(rot=(0, 0, 60)), head=R(-30, 0, 20), arm_l=R(-80, 0, 40))
        c.key(22, hips=dict(loc=(0, 0, -0.45)), body=dict(rot=(30, 0, 0)), root=dict(rot=(0, 0, 90)), lamp=dict(scale=0.3))
        c.key(33, root=dict(rot=(88, 0, 100), loc=(0, 0, 0.3)), hips=dict(loc=(0, 0, 0)), body=dict(rot=(0, 0, 0)), lamp=dict(scale=0.05), tank=dict(scale=0.4))
    with rig.clip("buff", 30) as c:                                # (Aura) hebt die Laterne, der Kanister brodelt
        c.key(0, **rest)
        c.key(12, arm_l=R(-150, 0, 0), lamp=dict(scale=1.8), tank=dict(scale=1.4), head=R(-20, 0, 0))
        c.key(30, **rest)
    rig.finish()


# ================================================================= Boss: Der Schlund – Riesenmaul im Fabrikbecken mit Rohr-Fangarmen
def boss_mutanten():
    rig = Rig("boss_mutanten", role="boss")
    p = Part()                                                                                       # Becken: Betonring mit Warnstreifen
    lathe(p, [(2.2, 0.0, "8A8A8A"), (2.3, 0.4, "9A9A9A"), (2.25, 0.6, "F2C230"), (2.0, 0.65, "2A2A2A"), (1.9, 0.5, "5A6A3A")], sides=20)
    for k in range(10):
        a = k * math.tau / 10
        p.box((0.35, 0.12, 0.22), (2.27 * math.cos(a), 2.27 * math.sin(a), 0.5), INK, r=rot(0, 0, math.degrees(a) + 90) @ rot(0, 30, 0), bevel=0.0)
    lathe(p, [(1.95, 0.45, TOX_D), (1.0, 0.5, TOX), (0.0, 0.52, TOX_L)], sides=20, cap=False)        # Giftbrühe
    for (x, y) in ((1.2, 0.6), (-1.1, 0.9), (0.6, -1.3), (-1.4, -0.6)):
        p.ball(0.15, (x, y, 0.55), TOX_L, scale=(1, 1, 0.5), subdiv=1)
    rig.add("basin", p, pivot=(0, 0, 0))
    rig.node("hips", pivot=(0, 0, 0.5))
    p = Part()                                                                                       # der Schlund: Riesenkörper mit Oberlippe
    lathe(p, [(1.3, 0.3, PURP_D), (1.45, 1.0, PURP), (1.4, 1.8, PURP), (1.2, 2.5, PURP_D), (0.9, 2.9, PURP), (0.3, 3.15, PURP), (0.0, 3.2, PURP)], sides=18)
    for (x, y, z, r) in ((0.9, 0.6, 2.6, 0.25), (-0.8, 0.8, 2.4, 0.3), (1.2, -0.2, 1.4, 0.22), (-1.25, 0.1, 1.6, 0.26)):
        p.ball(r, (x, y, z), TOX_L, subdiv=2)
    for s in (-1, 1):                                                                                # Glupschaugen auf Stielen
        capsule(p, (0.5 * s, -0.4, 2.8), (0.75 * s, -0.6, 3.6), 0.12, 0.1, PURP_D, sides=7)
    rig.add("body", p, parent="hips", pivot=(0, 0, 1.0))
    p = Part()
    for s in (-1, 1):
        p.ball(0.3, (0.75 * s, -0.65, 3.75), WHITE, subdiv=2)
    rig.add("eyeballs", p, parent="body", pivot=(0, -0.65, 3.75))
    p = Part()
    for s in (-1, 1):
        p.ball(0.13, (0.75 * s, -0.92, 3.77), INK, scale=(1, 0.5, 1), subdiv=1)
    rig.add("pupil", p, parent="eyeballs", pivot=(0, -0.92, 3.77), look=True)
    p = Part()                                                                                       # Oberkiefer mit Zahnreihe
    p.ball(1.0, (0, -1.0, 1.95), PURP, scale=(1.25, 0.6, 0.45), subdiv=2)
    for k in range(7):
        x = -0.9 + k * 0.3
        p.cone(0.11, 0.35, (x, -1.35, 1.72), WHITE, r=rot(180, 0, 0), sides=5)
    rig.add("lip", p, parent="body", pivot=(0, -0.5, 2.1))
    p = Part()                                                                                       # Unterkiefer, Rachen, Zunge
    p.ball(1.0, (0, -1.0, 1.05), PURP_D, scale=(1.2, 0.6, 0.4), subdiv=2)
    p.ball(0.8, (0, -0.85, 1.45), "4A0A2A", scale=(1.1, 0.4, 0.5), subdiv=2)
    p.ball(0.4, (0, -1.3, 1.25), "F07AA0", scale=(1.0, 1.0, 0.35), subdiv=1)
    for k in range(6):
        x = -0.75 + k * 0.3
        p.cone(0.1, 0.3, (x, -1.35, 1.32), WHITE, sides=5)
    rig.add("jaw", p, parent="body", pivot=(0, -0.4, 1.2))
    tent = []
    for s in (-1, 1):                                                                                # Fangarme aus Rohren, je drei Glieder mit Greifer
        pts = [(1.3 * s, -0.3, 1.6), (2.0 * s, -0.6, 2.2), (2.6 * s, -1.2, 2.0), (2.9 * s, -1.9, 1.2)]
        par = "body"
        for i in range(3):
            p = Part()
            capsule(p, pts[i], pts[i + 1], 0.24 - i * 0.04, 0.2 - i * 0.04, PIPE if i % 2 == 0 else PIPE_D, sides=7)
            p.torus(0.22 - i * 0.04, 0.05, pts[i + 1], RUST, r=face_to(Vector(pts[i + 1]) - Vector(pts[i])), seg=10, tseg=3)
            if i == 2:
                for k in range(3):
                    p.cone(0.07, 0.35, (pts[3][0] + 0.12 * (k - 1), pts[3][1] - 0.05, pts[3][2] - 0.1), RED, r=rot(180, 0, 0), sides=4)
            nm = "t%s%d" % ("l" if s > 0 else "r", i)
            rig.add(nm, p, parent=par, pivot=pts[i])
            tent.append(nm)
            par = nm
    rest = dict(root=dict(loc=(0, 0, 0), rot=(0, 0, 0)), hips=dict(loc=(0, 0, 0), rot=(0, 0, 0)), body=dict(rot=(0, 0, 0), scale=1.0), lip=R(), jaw=R(), eyeballs=dict(rot=(0, 0, 0), scale=1.0), basin=dict(scale=1.0), **{n: R() for n in tent})
    with rig.clip("idle", 54, loop=True) as c:                     # schmatzt, Fangarme schlängeln, Augen rollen
        c.key(0, **rest)
        c.key(14, jaw=R(18, 0, 0), lip=R(-6, 0, 0), eyeballs=dict(rot=(0, 0, 10)), tl0=R(0, 10, 0), tr0=R(0, -10, 0), tl1=R(10, 0, 0), tr1=R(-10, 0, 0))
        c.key(27, jaw=R(0, 0, 0), lip=R(0, 0, 0), body=dict(scale=(1.03, 1.03, 0.97)))
        c.key(40, jaw=R(10, 0, 0), eyeballs=dict(rot=(0, 0, -10)), tl0=R(0, -8, 0), tr0=R(0, 8, 0), tl2=R(20, 0, 0), tr2=R(20, 0, 0), body=dict(scale=1.0))
    with rig.clip("walk", 54, loop=True, stride=1.6) as c:          # das Becken rutscht schwer voran, der Körper schwankt
        c.wave("body", rot=(4, 5, 0), phase=0.0)
        c.wave("hips", loc=(0, 0, 0.12), n=2)
        for i, n in enumerate(tent):
            c.wave(n, rot=(16, 0, 10), phase=0.12 * i)
        c.wave("jaw", rot=(8, 0, 0), base_rot=(6, 0, 0), n=2)
    with rig.clip("attack", 36, hit=20) as c:                      # Fangarm-Peitsche
        c.key(0, **rest)
        c.key(12, tl0=R(-40, 0, -30), tl1=R(-30, 0, 0), tl2=R(-40, 0, 0), body=dict(rot=(-6, 0, 10)))
        c.key(20, tl0=R(30, 0, 30), tl1=R(30, 0, 0), tl2=R(20, 0, 0), body=dict(rot=(8, 0, -10)), jaw=R(25, 0, 0), _i="LINEAR")
        c.key(36, **rest)
    with rig.clip("hit", 9) as c:
        c.key(0, **rest)
        c.key(3, body=dict(rot=(-8, 0, 6), scale=(1.06, 1.06, 0.94)), eyeballs=dict(scale=1.3), jaw=R(20, 0, 0))
        c.key(9, **rest)
    with rig.clip("death", 60) as c:                               # brüllt, sinkt ins Becken, die Arme erschlaffen
        c.key(0, **rest)
        c.key(14, jaw=R(40, 0, 0), lip=R(-20, 0, 0), body=dict(rot=(-14, 0, 0)), eyeballs=dict(scale=1.4), **{n: R(-30, 0, 0) for n in tent})
        # sackt über den Beckenrand zusammen (Paket G2: versank vorher unter dem Boden)
        c.key(40, hips=dict(loc=(0, 0, -0.9)), body=dict(rot=(48, 0, 16), scale=(1.12, 1.12, 0.72)), jaw=R(10, 0, 0), _i="LINEAR", **{n: R(40, 0, 0) for n in tent})
        c.key(60, hips=dict(loc=(0, 0, -1.0)), body=dict(rot=(56, 0, 20), scale=(1.15, 1.15, 0.65)), eyeballs=dict(scale=0.4), **{n: R(50, 0, 0) for n in tent})
    with rig.clip("slam", 42, hit=24) as c:                        # beide Fangarme hoch und auf den Boden
        c.key(0, **rest)
        c.key(14, body=dict(rot=(-12, 0, 0)), jaw=R(30, 0, 0), **{n: R(-50, 0, 0) for n in tent})
        c.key(24, body=dict(rot=(14, 0, 0)), jaw=R(0, 0, 0), hips=dict(loc=(0, 0, -0.2)), _i="LINEAR", **{n: R(30, 0, 0) for n in tent})
        c.key(42, **rest)
    with rig.clip("special", 42, hit=22) as c:                     # Giftkröten spucken: würgt, reißt das Maul weit auf
        c.key(0, **rest)
        c.key(10, body=dict(scale=(1.12, 1.12, 0.9), rot=(-10, 0, 0)), jaw=R(-5, 0, 0))
        c.key(16, body=dict(scale=(0.95, 0.95, 1.1)), jaw=R(10, 0, 0))
        c.key(22, body=dict(rot=(16, 0, 0), scale=1.0), jaw=R(45, 0, 0), lip=R(-25, 0, 0), eyeballs=dict(scale=1.3), _i="LINEAR")
        c.key(30, jaw=R(30, 0, 0))
        c.key(42, **rest)
    rig.finish(icon_yaw=-24, icon_pitch=18)


TABLE = {"mutanten_giftkroete": mutanten_giftkroete, "mutanten_egelschwarm": mutanten_egelschwarm, "mutanten_schlammgolem": mutanten_schlammgolem, "mutanten_rohrspucker": mutanten_rohrspucker,
         "mutanten_werksdrohne": mutanten_werksdrohne, "mutanten_seuchenarzt": mutanten_seuchenarzt, "boss_mutanten": boss_mutanten}

if __name__ == "__main__":
    run(TABLE, [a for a in sys.argv if not a.startswith("--")])
