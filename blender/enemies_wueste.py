"""Wüstenmonster und Schrottvieh (Staubebene): sechs Arten + Boss nach dem Muster von enemies_untote.py (siehe blender/GEGNER.md).
Aufruf:  python3 blender/enemies_wueste.py [art ...] [--notafel]
"""
import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from animkit import *

# Farben der Familie: Rost, Lack, Sand, Chrom
RUST, RUST_D, RUST_L = "B8642E", "8A4522", "D8884A"
TEAL, TEAL_D = "3FA6A0", "2C7A76"
YEL, RED = "F2C230", "D8423A"
CHROME, CHROME_D = "C8D0D8", "8A949E"
SAND, SAND_D = "E8C888", "C8A060"
TIRE = "2A2A30"
INK = "15161C"
WHITE = "F8F6EE"
CACT, CACT_D = "5DAA4A", "3E8034"


def spawn_clip(rig, depth=1.0, n=24):
    """Besonderer Clip „spawn“: taucht wackelnd aus dem Boden auf (wenn ein Boss ruft oder ein Portal ausspuckt)."""
    with rig.clip("spawn", n) as c:
        c.key(0, root=dict(loc=(0, 0, -depth), rot=(0, 0, -40), scale=(0.6, 0.6, 0.6)))
        c.key(int(n * 0.55), root=dict(loc=(0, 0, 0.15 * depth), rot=(0, 0, 15), scale=(0.95, 0.95, 1.12)))
        c.key(int(n * 0.8), root=dict(loc=(0, 0, 0), rot=(0, 0, -5), scale=(1.08, 1.08, 0.92)))
        c.key(n, root=dict(loc=(0, 0, 0), rot=(0, 0, 0), scale=(1, 1, 1)))


def R(x=0, y=0, z=0):
    return dict(rot=(x, y, z))


# ================================================================= Schrottkäfer (Masse): Autotür als Panzer, Auspuff-Fühler
def wueste_schrottkaefer():
    rig = Rig("wueste_schrottkaefer", role="mass")
    p = Part()                                                                                      # Unterleib
    p.ball(0.42, (0, 0.05, 0.38), RUST_D, scale=(0.95, 1.2, 0.6), subdiv=2)
    rig.add("body", p, pivot=(0, 0, 0.38))
    p = Part()                                                                                      # Panzer: zwei Autotürhälften mit Fenster und Griff
    for s in (-1, 1):
        p.box((0.42, 0.95, 0.08), (0.22 * s, 0.08, 0.66), TEAL, r=rot(0, 22 * s, 0), bevel=0.0)
        p.box((0.28, 0.4, 0.02), (0.22 * s + 0.03 * s, -0.08, 0.715), "A8E0F0", r=rot(0, 22 * s, 0), bevel=0.0)  # Fenster
        p.box((0.12, 0.03, 0.03), (0.3 * s, 0.38, 0.69), CHROME, r=rot(0, 22 * s, 0), bevel=0.0)                # Türgriff
    p.box((0.06, 0.95, 0.05), (0, 0.08, 0.76), CHROME_D, bevel=0.0)                                 # Naht
    rig.add("shell", p, parent="body", pivot=(0, 0.4, 0.66))
    p = Part()                                                                                      # Kopf mit Scheinwerfer-Augen und Stoßstangen-Kiefer
    p.ball(0.24, (0, -0.48, 0.42), RUST, scale=(1.1, 0.9, 0.85), subdiv=2)
    for s in (-1, 1):
        p.cyl(0.09, 0.06, (0.13 * s, -0.66, 0.5), CHROME, r=rot(90, 0, 0), sides=6)
        p.box((0.08, 0.16, 0.04), (0.12 * s, -0.66, 0.28), CHROME_D, r=rot(0, 0, 20 * s), bevel=0.0)   # Mandibeln
    rig.add("head", p, parent="body", pivot=(0, -0.35, 0.42))
    p = Part()
    for s in (-1, 1):
        p.ball(0.065, (0.13 * s, -0.7, 0.5), "FFF2A0", subdiv=1)
    rig.add("eyes", p, parent="head", pivot=(0, -0.7, 0.5), glow=True)
    p = Part()
    for s in (-1, 1):
        p.ball(0.03, (0.13 * s, -0.75, 0.5), INK, subdiv=1)
    rig.add("pupil", p, parent="eyes", pivot=(0, -0.75, 0.5), look=True)
    for s, nm in ((1, "ant_l"), (-1, "ant_r")):                                                    # Auspuffrohre als Fühler, qualmen
        p = Part()
        capsule(p, (0.1 * s, -0.55, 0.6), (0.3 * s, -0.75, 1.0), 0.03, 0.03, CHROME_D, sides=5)
        lathe(p, [(0.045, 0, CHROME), (0.06, 0.08, CHROME_D), (0.04, 0.09, INK)], sides=6, loc=(0.3 * s, -0.75, 0.98), r=face_to((0.2 * s, -0.2, 0.4)))
        rig.add(nm, p, parent="head", pivot=(0.1 * s, -0.55, 0.6))
    for k, (nm, x, y) in enumerate((("leg_fl", 0.3, -0.25), ("leg_fr", -0.3, -0.25), ("leg_ml", 0.34, 0.05), ("leg_mr", -0.34, 0.05), ("leg_bl", 0.3, 0.35), ("leg_br", -0.3, 0.35))):
        p = Part()
        capsule(p, (x, y, 0.36), (x * 1.6, y, 0.2), 0.04, 0.035, RUST_D, sides=4)
        p.cone(0.035, 0.22, (x * 1.68, y - 0.02, 0.1), TIRE, r=rot(180, 0, 0), sides=4)
        rig.add(nm, p, parent="body", pivot=(x, y, 0.36))
    legs = ["leg_fl", "leg_fr", "leg_ml", "leg_mr", "leg_bl", "leg_br"]
    rest = dict(root=dict(loc=(0, 0, 0), rot=(0, 0, 0)), body=dict(loc=(0, 0, 0), rot=(0, 0, 0)), shell=R(), head=R(), ant_l=R(), ant_r=R(), **{n: R() for n in legs})
    with rig.clip("idle", 30, loop=True) as c:                     # Fühler wippen, Türen klappern
        c.key(0, **rest)
        c.key(8, ant_l=R(-14, 0, 10), ant_r=R(10, 0, -6), shell=R(-4, 0, 0))
        c.key(15, head=R(0, 0, 12), shell=R(0, 0, 0))
        c.key(22, ant_l=R(10, 0, 0), ant_r=R(-14, 0, -10), head=R(0, 0, -10))
    with rig.clip("walk", 15, loop=True, stride=1.1) as c:         # krabbelt dreibeinig
        for k, n in enumerate(legs):
            c.wave(n, rot=(30, 0, 0), phase=0.5 * ((k // 2 + k % 2) % 2))
        c.wave("body", rot=(0, 5, 0), loc=(0, 0, 0.03), n=2)
        c.wave("ant_l", rot=(14, 0, 0), phase=0.2)
        c.wave("ant_r", rot=(14, 0, 0), phase=0.7)
        c.wave("shell", rot=(3, 0, 0), n=2)
    with rig.clip("attack", 18, hit=10) as c:                      # Türen klappen auf, Mandibeln zwicken
        c.key(0, **rest)
        c.key(6, shell=R(-30, 0, 0), head=R(-18, 0, 0), body=dict(loc=(0, 0.1, 0)))
        c.key(10, shell=R(-10, 0, 0), head=R(16, 0, 0), body=dict(loc=(0, -0.25, 0)), _i="LINEAR")
        c.key(18, **rest)
    with rig.clip("hit", 9) as c:
        c.key(0, **rest)
        c.key(3, shell=dict(rot=(-20, 0, 8), loc=(0, 0, 0.12)), body=dict(loc=(0, 0.08, 0.04)), ant_l=R(-30, 0, 20), ant_r=R(-30, 0, -20))
        c.key(9, **rest)
    with rig.clip("death", 27) as c:                               # kippt auf den Rücken, Beinchen zappeln, der Panzer klappt ab
        c.key(0, **rest)
        c.key(8, root=dict(rot=(0, 90, 0), loc=(0, 0, 0.4)))
        c.key(14, root=dict(rot=(0, 180, 0), loc=(0, 0, 0.8)), shell=dict(rot=(-40, 0, 0)), _i="LINEAR")
        for f, a in ((16, 30), (19, -20), (22, 20), (27, 0)):
            c.key(f, **{n: R(a * (1 if i % 2 else -1), 0, 0) for i, n in enumerate(legs)})
        c.key(27, root=dict(rot=(0, 180, 0), loc=(0, 0, 0.8)), shell=dict(rot=(-50, 0, 0), loc=(0, 0, -0.1)), eyes=dict(scale=0.1))
    spawn_clip(rig, 1.2)
    rig.finish()


# ================================================================= Staubteufel (Flitzer): Wirbelwind mit Schrott und zwei Augen
def wueste_staubteufel():
    rig = Rig("wueste_staubteufel", role="fast")
    p = Part()                                                                                      # Trichter aus Sandringen
    lathe(p, [(0.05, 0.0, SAND_D), (0.18, 0.15, SAND), (0.28, 0.45, SAND_D), (0.42, 0.85, SAND), (0.55, 1.2, SAND_D), (0.5, 1.4, SAND), (0.2, 1.45, SAND)], sides=9)
    rig.add("funnel", p, pivot=(0, 0, 0.2), ghost=True)
    p = Part()                                                                                      # zwei Drehringe
    p.torus(0.36, 0.05, (0, 0, 0.7), SAND_D, seg=10, tseg=4)
    p.torus(0.5, 0.05, (0, 0, 1.15), SAND, seg=10, tseg=4)
    rig.add("ring", p, parent="funnel", pivot=(0, 0, 0.7))
    p = Part()                                                                                      # mitgewirbelter Schrott: Zahnrad, Dose, Schraube, Radkappe
    p.cyl(0.12, 0.04, (0.6, 0, 0.9), CHROME_D, sides=8)
    p.cyl(0.07, 0.16, (-0.5, 0.25, 1.15), RED, sides=6)
    p.box((0.05, 0.05, 0.2), (0.1, 0.55, 0.6), CHROME, r=rot(30, 40, 0), bevel=0.0)
    p.cyl(0.14, 0.03, (-0.3, -0.45, 0.5), CHROME, r=rot(40, 0, 0), sides=8)
    rig.add("junk", p, pivot=(0, 0, 0.8))
    p = Part()                                                                                      # zwei große, verdrehte Augen
    for s in (-1, 1):
        p.ball(0.11, (0.15 * s, -0.42, 1.12), WHITE, scale=(1, 0.5, 1.1), subdiv=1)
    p.ball(0.06, (0, -0.44, 0.95), INK, scale=(1.6, 0.4, 0.4), subdiv=1)
    rig.add("face", p, parent="funnel", pivot=(0, -0.42, 1.1))
    p = Part()
    for s in (-1, 1):
        p.ball(0.05, (0.15 * s, -0.48, 1.12), INK, scale=(1, 0.5, 1), subdiv=1)
    rig.add("pupil", p, parent="face", pivot=(0, -0.48, 1.12), look=True)
    rest = dict(root=dict(loc=(0, 0, 0), rot=(0, 0, 0)), funnel=dict(rot=(0, 0, 0), scale=1.0), ring=R(), junk=dict(rot=(0, 0, 0), scale=1.0), face=dict(loc=(0, 0, 0), scale=1.0))
    with rig.clip("idle", 18, loop=True) as c:                     # dreht sich auf der Stelle, der Schrott kreist
        c.key(0, funnel=R(0, 0, 0), ring=R(0, 0, 0), junk=R(0, 0, 0))
        c.key(9, funnel=dict(rot=(4, 0, 0), scale=(1.05, 1.05, 0.95)), ring=R(0, 0, 180), junk=R(0, 0, 180), _i="LINEAR")
        c.key(18, funnel=R(0, 0, 0), ring=R(0, 0, 360), junk=R(0, 0, 360), _i="LINEAR")
    with rig.clip("walk", 12, loop=True, stride=2.4) as c:         # schräg vorgeneigt, sehr schnell
        c.key(0, funnel=dict(rot=(18, 0, 0)), ring=R(0, 0, 0), junk=R(0, 0, 0), face=dict(loc=(0, 0, 0)))
        c.key(6, funnel=dict(rot=(22, 6, 0)), ring=R(0, 0, 180), junk=R(0, 0, 200), face=dict(loc=(0.04, 0, 0.03)), _i="LINEAR")
        c.key(12, ring=R(0, 0, 360), junk=R(0, 0, 400), _i="LINEAR")
    with rig.clip("attack", 15, hit=8) as c:                       # bläst den Helden weg: dehnt sich breit
        c.key(0, **rest)
        c.key(5, funnel=dict(scale=(0.8, 0.8, 1.2)), junk=dict(rot=(0, 0, 180), scale=0.8))
        c.key(8, funnel=dict(scale=(1.4, 1.4, 0.8), rot=(-15, 0, 0)), junk=dict(rot=(0, 0, 300), scale=1.4), _i="LINEAR")
        c.key(15, **rest)
    with rig.clip("hit", 9) as c:
        c.key(0, **rest)
        c.key(3, funnel=dict(rot=(-20, 0, 15), scale=(1.1, 1.1, 0.85)), face=dict(loc=(0, 0.1, -0.1)))
        c.key(9, **rest)
    with rig.clip("death", 24) as c:                               # fällt in sich zusammen, der Schrott plumpst herunter
        c.key(0, **rest)
        c.key(8, funnel=dict(scale=(1.3, 1.3, 0.6), rot=(0, 0, 200)), junk=dict(rot=(0, 0, 120)))
        c.key(16, funnel=dict(scale=(1.4, 1.4, 0.1)), junk=dict(rot=(0, 0, 160), scale=(1, 1, 0.3)), face=dict(scale=0.4, loc=(0, 0, -0.9)))
        c.key(24, funnel=dict(scale=(1.4, 1.4, 0.05)), junk=dict(rot=(0, 0, 170), scale=(1.0, 1.0, 0.1)), face=dict(scale=0.05, loc=(0, 0, -1.0)))
    spawn_clip(rig, 1.2)
    rig.finish()


# ================================================================= Rostbulle (Brocken): Stier aus Blechplatten mit Stoßstangen-Hörnern
def wueste_rostbulle():
    rig = Rig("wueste_rostbulle", role="tank")
    p = Part()                                                                                      # Rumpf aus genieteten Blechplatten
    p.box((1.3, 2.0, 1.15), (0, 0.15, 1.35), RUST, bevel=0.22, segs=2)
    p.box((1.36, 0.5, 1.2), (0, -0.55, 1.45), RUST_L, bevel=0.12, segs=1)                          # breite Brust
    p.box((1.32, 0.5, 0.3), (0, 0.6, 1.95), TEAL, bevel=0.06, segs=1)                              # aufgenietete Lackplatte
    p.box((0.5, 0.6, 0.06), (0.67, 0.1, 1.3), YEL, r=rot(0, 90, 0), bevel=0.0)                     # gelbes Warnschild
    p.box((0.5, 0.6, 0.06), (-0.67, 0.1, 1.3), YEL, r=rot(0, 90, 0), bevel=0.0)
    for x in (-0.66, 0.66):
        for y in (-0.3, 0.5):
            for z in (1.0, 1.7):
                p.ball(0.04, (x, y, z), CHROME_D, subdiv=1)
    p.cyl(0.08, 0.5, (0.35, 0.75, 2.1), CHROME_D, sides=6)                                         # Auspuff auf dem Rücken
    p.cyl(0.11, 0.08, (0.35, 0.75, 2.38), INK, sides=6)
    rig.add("body", p, pivot=(0, 0, 1.3))
    p = Part()                                                                                      # Kopf: Kühlergrill-Schnauze, Nasenring, Stoßstangen-Hörner
    p.box((0.9, 0.8, 0.75), (0, -1.15, 1.45), RUST_D, bevel=0.15, segs=1)
    for k in range(5):
        p.box((0.06, 0.04, 0.4), (-0.24 + k * 0.12, -1.56, 1.35), CHROME, bevel=0.0)              # Kühlergrill
    p.torus(0.13, 0.03, (0, -1.6, 1.12), YEL, r=rot(90, 0, 0), seg=10, tseg=4)                    # Nasenring
    for s in (-1, 1):
        capsule(p, (0.4 * s, -1.1, 1.75), (0.95 * s, -1.25, 1.85), 0.08, 0.07, CHROME, sides=6)   # Stoßstangenhorn
        capsule(p, (0.95 * s, -1.25, 1.85), (1.05 * s, -1.55, 2.15), 0.07, 0.04, CHROME, sides=6)
        p.box((0.2, 0.06, 0.14), (0.2 * s, -1.56, 1.7), INK, r=rot(0, -20 * s, 0), bevel=0.0)       # finstere Brauen
    rig.add("head", p, parent="body", pivot=(0, -0.8, 1.55))
    p = Part()
    for s in (-1, 1):
        p.ball(0.1, (0.22 * s, -1.56, 1.58), "FF5A2A", scale=(1, 0.4, 0.8), subdiv=1)              # Glutaugen (Rücklichter)
    rig.add("eyes", p, parent="head", pivot=(0, -1.56, 1.58), glow=True)
    p = Part()                                                                                      # Schwanz: Abschleppkette mit Haken
    for k in range(4):
        p.torus(0.07, 0.025, (0, 1.2 + k * 0.13, 1.6 - k * 0.12), CHROME_D, r=rot(90 * (k % 2), 0, 90), seg=6, tseg=3)
    p.cone(0.1, 0.2, (0, 1.75, 1.08), CHROME, r=rot(180, 0, 0), sides=5)
    rig.add("tail", p, parent="body", pivot=(0, 1.15, 1.65))
    for nm, x, y in (("leg_fl", 0.42, -0.5), ("leg_fr", -0.42, -0.5), ("leg_bl", 0.42, 0.75), ("leg_br", -0.42, 0.75)):
        p = Part()
        lathe(p, [(0.17, 0.0, TIRE), (0.2, 0.12, TIRE), (0.15, 0.2, CHROME_D), (0.16, 0.8, RUST_D), (0.2, 0.95, RUST_D)], sides=7, loc=(x, y, 0))
        rig.add(nm, p, parent="body", pivot=(x, y, 0.9))
    legs = ["leg_fl", "leg_fr", "leg_bl", "leg_br"]
    rest = dict(root=dict(loc=(0, 0, 0), rot=(0, 0, 0)), body=dict(loc=(0, 0, 0), rot=(0, 0, 0)), head=R(), tail=R(), eyes=dict(scale=1.0), **{n: R() for n in legs})
    with rig.clip("idle", 42, loop=True) as c:                     # schnaubt Dampf, scharrt mit dem Huf
        c.key(0, **rest)
        c.key(10, head=R(-10, 0, 0), body=dict(loc=(0, 0, 0.04)))
        c.key(16, head=R(4, 0, 0), leg_fr=R(-26, 0, 0), body=dict(loc=(0, 0, 0)))
        c.key(22, leg_fr=R(14, 0, 0), tail=R(0, 0, 25))
        c.key(28, leg_fr=R(-20, 0, 0))
        c.key(34, leg_fr=R(0, 0, 0), tail=R(0, 0, -20))
    with rig.clip("walk", 36, loop=True, stride=1.9) as c:         # schwerer Trott
        c.wave("leg_fl", rot=(24, 0, 0), phase=0.0)
        c.wave("leg_br", rot=(24, 0, 0), phase=0.0)
        c.wave("leg_fr", rot=(24, 0, 0), phase=0.5)
        c.wave("leg_bl", rot=(24, 0, 0), phase=0.5)
        c.wave("body", rot=(0, 3, 0), loc=(0, 0, 0.05), n=2)
        c.wave("head", rot=(6, 0, 4), phase=0.25)
        c.wave("tail", rot=(0, 0, 20))
    with rig.clip("attack", 30, hit=16) as c:                      # Kopfstoß von unten nach oben
        c.key(0, **rest)
        c.key(10, head=R(26, 0, 0), body=dict(rot=(4, 0, 0), loc=(0, 0.15, -0.08)))
        c.key(16, head=R(-36, 0, 0), body=dict(rot=(-6, 0, 0), loc=(0, -0.35, 0.06)), leg_fl=R(-30, 0, 0), leg_fr=R(-30, 0, 0), _i="LINEAR")
        c.key(30, **rest)
    with rig.clip("hit", 9) as c:
        c.key(0, **rest)
        c.key(3, body=dict(rot=(-5, 0, 4), loc=(0, 0.12, 0)), head=R(-14, 0, 8), tail=R(30, 0, 0))
        c.key(9, **rest)
    with rig.clip("death", 42) as c:                               # knickt vorne ein, kippt zur Seite, die Augen gehen aus
        c.key(0, **rest)
        c.key(10, body=dict(rot=(10, 0, 0), loc=(0, 0, -0.3)), leg_fl=R(-70, 0, 0), leg_fr=R(-70, 0, 0), head=R(20, 0, 0))
        c.key(24, root=dict(rot=(0, 80, 0), loc=(0, 0, 0.6)), body=dict(rot=(4, 0, 0), loc=(0, 0, -0.3)), _i="LINEAR")
        c.key(28, root=dict(rot=(0, 74, 0), loc=(0, 0, 0.7)))
        c.key(32, root=dict(rot=(0, 82, 0), loc=(0, 0, 0.6)), leg_bl=R(30, 0, 0), leg_br=R(-20, 0, 0))
        c.key(42, root=dict(rot=(0, 82, 0), loc=(0, 0, 0.6)), eyes=dict(scale=0.05), tail=R(0, 0, 40))
    with rig.clip("windup", 18) as c:                              # Anlauf: senkt die Hörner, scharrt zweimal
        c.key(0, **rest)
        c.key(4, head=R(24, 0, 0), body=dict(rot=(6, 0, 0), loc=(0, 0.2, -0.1)), leg_fr=R(-34, 0, 0), eyes=dict(scale=1.4))
        c.key(8, leg_fr=R(20, 0, 0))
        c.key(12, leg_fr=R(-34, 0, 0))
        c.key(18, leg_fr=R(10, 0, 0), head=R(26, 0, 0), body=dict(rot=(8, 0, 0), loc=(0, 0.25, -0.12)), eyes=dict(scale=1.4))
    with rig.clip("charge", 12, loop=True, stride=2.6) as c:        # Sturm: Hörner gesenkt, gestreckter Galopp
        c.wave("leg_fl", rot=(50, 0, 0), base_rot=(0, 0, 0), phase=0.0)
        c.wave("leg_fr", rot=(50, 0, 0), phase=0.1)
        c.wave("leg_bl", rot=(50, 0, 0), phase=0.5)
        c.wave("leg_br", rot=(50, 0, 0), phase=0.6)
        c.wave("body", rot=(6, 0, 0), base_rot=(6, 0, 0), loc=(0, 0, 0.12), n=1, phase=0.25)
        c.key(0, head=R(26, 0, 0), eyes=dict(scale=1.4), tail=R(-50, 0, 0))
    with rig.clip("dazed", 30, loop=True) as c:                    # benommen: Kopf kreist, Augen flackern
        c.key(0, head=R(10, 0, 20), body=dict(rot=(0, 6, 0), loc=(0, 0, -0.1)), eyes=dict(scale=0.4), leg_fl=R(0, 10, 0), leg_fr=R(0, -10, 0))
        c.key(8, head=R(20, 10, 0), eyes=dict(scale=1.0))
        c.key(15, head=R(10, 0, -20), body=dict(rot=(0, -6, 0)), eyes=dict(scale=0.4))
        c.key(22, head=R(0, -10, 0), eyes=dict(scale=1.0))
    rig.finish(icon_yaw=-40, icon_pitch=14)


# ================================================================= Kaktusschütze (Fernkampf): laufender Kaktus mit Sombrero-Blüte
def wueste_kaktusschuetze():
    rig = Rig("wueste_kaktusschuetze", role="ranged")
    rig.node("hips", pivot=(0, 0, 0.45))
    p = Part()                                                                                      # Säulenkörper mit Rippen und Stacheln
    lathe(p, [(0.22, 0.4, CACT_D), (0.33, 0.5, CACT), (0.36, 0.9, CACT), (0.33, 1.4, CACT), (0.24, 1.6, CACT), (0.0, 1.66, CACT)], sides=8)
    for k in range(8):
        a = k * math.tau / 8
        for z in (0.7, 1.05, 1.4):
            p.cone(0.022, 0.1, (0.36 * math.cos(a), 0.36 * math.sin(a), z + 0.05 * (k % 2)), "F4EDC0", r=face_to((math.cos(a), math.sin(a), 0.2)), sides=3)
    for s in (-1, 1):                                                                               # Gesicht: Kulleraugen, Schnurrbart
        p.ball(0.08, (0.11 * s, -0.31, 1.25), WHITE, scale=(1, 0.5, 1.15), subdiv=1)
        capsule(p, (0.02 * s, -0.37, 1.08), (0.2 * s, -0.34, 1.02), 0.035, 0.02, "3A2A1A", sides=4)
    p.box((0.12, 0.03, 0.04), (0, -0.35, 0.98), "6A2A2A", bevel=0.0)
    rig.add("body", p, parent="hips", pivot=(0, 0, 0.45))
    p = Part()
    for s in (-1, 1):
        p.ball(0.038, (0.11 * s, -0.355, 1.25), INK, scale=(1, 0.5, 1), subdiv=1)
    rig.add("pupil", p, parent="body", pivot=(0, -0.35, 1.25), look=True)
    p = Part()                                                                                      # Sombrero aus einer großen Blüte
    lathe(p, [(0.0, 1.6, "F070A0"), (0.65, 1.62, "F070A0"), (0.7, 1.68, "FFB0C8"), (0.24, 1.72, "F070A0"), (0.2, 1.9, "D84A80"), (0.0, 1.96, "D84A80")], sides=12)
    for k in range(6):
        a = k * math.tau / 6
        p.ball(0.05, (0.45 * math.cos(a), 0.45 * math.sin(a), 1.69), YEL, subdiv=1)
    rig.add("hat", p, parent="body", pivot=(0, 0, 1.62))
    for s, nm in ((1, "arm_l"), (-1, "arm_r")):                                                    # Kaktusarme (Ellbogen nach oben)
        p = Part()
        capsule(p, (0.3 * s, 0, 1.0), (0.55 * s, 0, 1.0), 0.1, 0.1, CACT, sides=6)
        capsule(p, (0.55 * s, 0, 1.0), (0.55 * s, 0, 1.35), 0.1, 0.08, CACT, sides=6)
        p.cone(0.02, 0.08, (0.65 * s, 0, 1.2), "F4EDC0", r=rot(0, 90 * s, 0), sides=3)
        rig.add(nm, p, parent="body", pivot=(0.3 * s, 0, 1.0))
    for s, nm in ((1, "leg_l"), (-1, "leg_r")):                                                    # Wurzelfüße in Stiefelchen
        p = Part()
        capsule(p, (0.13 * s, 0, 0.44), (0.14 * s, 0, 0.1), 0.07, 0.06, CACT_D, sides=5)
        p.ball(0.1, (0.14 * s, -0.07, 0.06), "8A5A30", scale=(0.9, 1.5, 0.6), subdiv=1)
        rig.add(nm, p, parent="hips", pivot=(0.13 * s, 0, 0.45))
    rest = dict(root=dict(loc=(0, 0, 0), rot=(0, 0, 0)), hips=dict(loc=(0, 0, 0), rot=(0, 0, 0)), body=dict(rot=(0, 0, 0), scale=1.0), hat=R(), arm_l=R(), arm_r=R(), leg_l=R(), leg_r=R())
    with rig.clip("idle", 42, loop=True) as c:                     # wackelt im Takt, lupft den Hut
        c.key(0, **rest)
        c.key(10, body=R(0, 5, 0), arm_l=R(0, 0, 15), hat=R(0, -6, 0))
        c.key(21, body=R(0, -5, 0), arm_r=R(0, 0, -15), hat=R(0, 6, 0))
        c.key(30, hat=dict(rot=(-14, 0, 0), loc=(0, 0, 0)))
        c.key(36, hat=R(0, 0, 0))
    with rig.clip("walk", 21, loop=True, stride=1.3) as c:         # stelzt mit steifen Beinen
        c.wave("leg_l", rot=(36, 0, 0), phase=0.0)
        c.wave("leg_r", rot=(36, 0, 0), phase=0.5)
        c.wave("body", rot=(0, 7, 0), phase=0.25)
        c.wave("hips", loc=(0, 0, 0.05), n=2, phase=0.25)
        c.wave("arm_l", rot=(0, 0, 14), phase=0.5)
        c.wave("arm_r", rot=(0, 0, -14), phase=0.0)
        c.wave("hat", rot=(0, 6, 0), phase=0.5)
    with rig.clip("attack", 30, hit=17) as c:                      # holt Luft, plustert sich auf, schießt einen Stachelfächer
        c.key(0, **rest)
        c.key(10, body=dict(rot=(-10, 0, 0), scale=(1.1, 1.1, 0.95)), arm_l=R(0, 0, 40), arm_r=R(0, 0, -40), hat=R(-12, 0, 0))
        c.key(17, body=dict(rot=(14, 0, 0), scale=(0.92, 0.92, 1.08)), arm_l=R(-60, 0, -10), arm_r=R(-60, 0, 10), hat=R(10, 0, 0), _i="LINEAR")
        c.key(22, body=dict(rot=(8, 0, 0), scale=1.0))
        c.key(30, **rest)
    with rig.clip("hit", 9) as c:
        c.key(0, **rest)
        c.key(3, body=dict(rot=(-14, 0, 6), scale=(1.06, 1.06, 0.92)), hat=dict(rot=(-20, 0, 10), loc=(0, 0, 0.15)))
        c.key(9, **rest)
    with rig.clip("death", 33) as c:                               # fällt um wie ein Baum, der Hut segelt davon
        c.key(0, **rest)
        c.key(8, body=R(-8, 0, 0), hat=dict(loc=(0, 0, 0.3), rot=(0, 0, 40)))
        c.key(22, root=dict(rot=(82, 0, 0), loc=(0, 0, 0.3)), hat=dict(loc=(0.4, 0.1, -0.3), rot=(-60, 0, 120)), arm_l=R(0, 0, 30), _i="LINEAR")
        c.key(26, root=dict(rot=(76, 0, 0), loc=(0, 0, 0.35)))
        c.key(33, root=dict(rot=(84, 0, 0), loc=(0, 0, 0.3)), hat=dict(loc=(0.5, -0.25, -0.9), rot=(-90, 0, 160)))
    spawn_clip(rig, 1.2)
    rig.finish()


# ================================================================= Geier (Flieger): zerzaust, mit Fliegerbrille
def wueste_geier():
    rig = Rig("wueste_geier", role="air")
    FE, FE_D, NECK = "6A4A3A", "4A3428", "E89A88"
    p = Part()                                                                                      # Rumpf
    p.ball(0.36, (0, 0.1, 0.55), FE, scale=(0.9, 1.3, 0.85), subdiv=2)
    p.ball(0.24, (0, -0.25, 0.68), "F0E2C8", scale=(1.1, 0.7, 0.7), subdiv=1)                        # weiße Halskrause
    for k in range(3):
        p.cone(0.07, 0.35, (-0.1 + k * 0.1, 0.55, 0.55), FE_D, r=rot(-95 + k * 8, 0, -15 + k * 15), sides=4)   # Schwanzfedern
    rig.add("body", p, pivot=(0, 0, 0.55))
    p = Part()                                                                                      # nackter Hals, Kahlkopf, Hakenschnabel, Fliegerbrille
    capsule(p, (0, -0.25, 0.7), (0, -0.45, 1.0), 0.07, 0.06, NECK, sides=5)
    p.ball(0.15, (0, -0.48, 1.05), NECK, subdiv=2)
    p.cone(0.07, 0.24, (0, -0.68, 1.02), YEL, r=rot(100, 0, 0), sides=5)
    p.ball(0.04, (0, -0.79, 0.97), YEL, subdiv=1)
    p.torus(0.155, 0.025, (0, -0.48, 1.12), "6A3A1A", seg=10, tseg=3)                             # Brillenband
    for s in (-1, 1):
        p.cyl(0.07, 0.06, (0.075 * s, -0.6, 1.12), "B8742E", r=rot(90, 0, 0), sides=8)
        p.cyl(0.055, 0.02, (0.075 * s, -0.635, 1.12), "9FE4FF", r=rot(90, 0, 0), sides=8)
    for k in range(3):
        p.cone(0.03, 0.12, (-0.04 + k * 0.04, -0.45, 1.2), "D8C8B0", r=rot(-20, 0, -20 + k * 20), sides=3)   # Federschopf
    rig.add("head", p, parent="body", pivot=(0, -0.25, 0.75))
    p = Part()
    for s in (-1, 1):
        p.ball(0.03, (0.075 * s, -0.65, 1.12), INK, subdiv=1)
    rig.add("pupil", p, parent="head", pivot=(0, -0.65, 1.12), look=True)
    for s, nm in ((1, "wing_l"), (-1, "wing_r")):                                                  # zerzauste Flügel mit Fingerfedern
        p = Part()
        p.box((0.75, 0.42, 0.06), (0.62 * s, 0.05, 0.65), FE, bevel=0.03, segs=1)
        for k in range(4):
            p.box((0.1, 0.32, 0.04), (0.82 * s + 0.08 * k * s, 0.3 + 0.04 * k, 0.64), FE_D if k % 2 else FE, r=rot(0, 0, (8 + 6 * k) * s), bevel=0.0)
        rig.add(nm, p, parent="body", pivot=(0.25 * s, 0.05, 0.65))
        p = Part()
        p.box((0.4, 0.3, 0.05), (1.12 * s, 0.05, 0.65), FE_D, bevel=0.0)
        for k in range(4):
            p.box((0.07, 0.3, 0.035), (1.25 * s + 0.05 * k * s, 0.15 + 0.08 * k - 0.15, 0.65), FE, r=rot(0, 0, (-30 + 20 * k) * s), bevel=0.0)
        rig.add(nm.replace("wing", "tip"), p, parent=nm, pivot=(0.95 * s, 0.05, 0.65))
    p = Part()                                                                                      # Krallen
    for s in (-1, 1):
        capsule(p, (0.12 * s, 0.1, 0.3), (0.13 * s, 0.0, 0.08), 0.035, 0.03, YEL, sides=4)
        p.ball(0.05, (0.13 * s, -0.04, 0.06), YEL, scale=(1, 1.4, 0.5), subdiv=1)
    rig.add("feet", p, parent="body", pivot=(0, 0.1, 0.3))
    rest = dict(root=dict(loc=(0, 0, 0), rot=(0, 0, 0)), body=dict(rot=(0, 0, 0), loc=(0, 0, 0)), head=R(), wing_l=R(), wing_r=R(), tip_l=R(), tip_r=R(), feet=R())
    with rig.clip("idle", 24, loop=True) as c:                     # kreist mit trägem Flügelschlag, späht umher
        c.key(0, **rest, )
        c.key(6, wing_l=R(0, -30, 0), wing_r=R(0, 30, 0), tip_l=R(0, -15, 0), tip_r=R(0, 15, 0), body=dict(loc=(0, 0, 0.08)), head=R(0, 0, 20))
        c.key(12, wing_l=R(0, 0, 0), wing_r=R(0, 0, 0), tip_l=R(0, 10, 0), tip_r=R(0, -10, 0))
        c.key(18, wing_l=R(0, 30, 0), wing_r=R(0, -30, 0), tip_l=R(0, 15, 0), tip_r=R(0, -15, 0), body=dict(loc=(0, 0, -0.06)), head=R(0, 0, -20))
    with rig.clip("walk", 15, loop=True, stride=1.6) as c:         # schneller Flügelschlag, nach vorn gelehnt
        c.wave("wing_l", rot=(0, -45, 0))
        c.wave("wing_r", rot=(0, 45, 0))
        c.wave("tip_l", rot=(0, -25, 0), phase=0.15)
        c.wave("tip_r", rot=(0, 25, 0), phase=0.15)
        c.wave("body", rot=(4, 0, 0), base_rot=(14, 0, 0), loc=(0, 0, 0.08), phase=0.5)
        c.key(0, head=R(-10, 0, 0), feet=R(40, 0, 0))
    with rig.clip("attack", 18, hit=10) as c:                      # stößt mit dem Schnabel und schnappt nach den Münzen
        c.key(0, **rest)
        c.key(6, head=R(-30, 0, 0), wing_l=R(0, -50, 0), wing_r=R(0, 50, 0), body=dict(rot=(-10, 0, 0)))
        c.key(10, head=R(40, 0, 0), wing_l=R(0, 30, 0), wing_r=R(0, -30, 0), body=dict(rot=(25, 0, 0), loc=(0, -0.2, -0.15)), feet=R(-50, 0, 0), _i="LINEAR")
        c.key(18, **rest)
    with rig.clip("hit", 9) as c:                                   # Federn stieben
        c.key(0, **rest)
        c.key(3, body=dict(rot=(-20, 0, 15), loc=(0, 0.1, 0.1)), head=R(-30, 0, 0), wing_l=R(0, -70, 0), wing_r=R(0, 70, 0))
        c.key(9, **rest)
    with rig.clip("death", 27) as c:                                # trudelt, Flügel schlaff, landet auf dem Rücken
        c.key(0, **rest)
        c.key(8, root=dict(rot=(0, 120, 0)), wing_l=R(0, -80, 0), wing_r=R(0, 40, 0), head=R(-40, 0, 0))
        c.key(18, root=dict(rot=(0, 180, 0), loc=(0, 0, 0.9)), wing_l=R(0, 30, 0), wing_r=R(0, -30, 0), tip_l=R(0, 40, 0), tip_r=R(0, -40, 0), _i="LINEAR")
        c.key(27, root=dict(rot=(0, 180, 0), loc=(0, 0, 0.95)), head=R(30, 0, 30), feet=R(-30, 0, 0))
    spawn_clip(rig, 0.6)
    rig.finish(icon_pitch=20)


# ================================================================= Sandwurm (Sonder): Wurm aus Reifen-Segmenten, Zahnrad-Maul
def wueste_sandwurm():
    rig = Rig("wueste_sandwurm", role="special")
    segs = []
    par = "root"
    # sechs Reifen-Segmente, vom Kopf (vorn, hoch aufgerichtet) zum Schwanz
    pts = [(0, -0.55, 1.35), (0, -0.35, 0.95), (0, -0.05, 0.6), (0, 0.35, 0.4), (0, 0.75, 0.32), (0, 1.1, 0.26)]
    for i in range(1, 6):
        x, y, z = pts[i]
        r = 0.42 - i * 0.045
        p = Part()
        p.torus(r * 0.75, r * 0.38, (x, y, z), TIRE, r=face_to(Vector(pts[i - 1]) - Vector(pts[i])), seg=12, tseg=5)
        p.cyl(r * 0.62, 0.5, (x, y, z), RUST_D if i % 2 else RUST, r=face_to(Vector(pts[i - 1]) - Vector(pts[i])), sides=8)
        nm = "seg%d" % i
        segs.append((nm, p, pts[i]))
    # Kopf zuerst als Wurzel des Körpers, dann die Segmente als Kette nach hinten
    rig.node("neck", pivot=pts[2])
    p = Part()
    p.torus(0.36, 0.17, pts[0], TIRE, r=face_to((0, -0.6, 0.6)), seg=14, tseg=6)
    p.cyl(0.36, 0.3, pts[0], RUST, r=face_to((0, -0.6, 0.6)), sides=10)
    lathe(p, [(0.0, -0.02, "6A1A2A"), (0.28, 0.0, "6A1A2A")], sides=10, loc=(0, -0.68, 1.48), r=face_to((0, -0.6, 0.6)))    # Maul-Schlund
    for k in range(8):                                                                               # Zahnrad-Zähne rund ums Maul
        a = k * math.tau / 8
        q = Vector((math.cos(a) * 0.3, math.sin(a) * 0.3, 0.0))
        m = face_to((0, -0.6, 0.6))
        v = m @ q
        p.box((0.08, 0.08, 0.14), (v.x, -0.66 + v.y, 1.48 + v.z), CHROME, r=m @ rot(0, 0, math.degrees(a)), bevel=0.0)
    for s in (-1, 1):
        capsule(p, (0.15 * s, -0.4, 1.6), (0.22 * s, -0.42, 1.88), 0.04, 0.035, TIRE, sides=5)
        p.ball(0.12, (0.22 * s, -0.44, 1.95), WHITE, subdiv=1)
    rig.add("head", p, parent="neck", pivot=pts[1])
    p = Part()
    for s in (-1, 1):
        p.ball(0.055, (0.22 * s, -0.55, 1.95), INK, subdiv=1)
    rig.add("pupil", p, parent="head", pivot=(0, -0.55, 1.95), look=True)
    p = Part()                                                                                       # Zahnrad im Maul dreht sich
    p.cyl(0.18, 0.06, (0, -0.6, 1.42), CHROME_D, r=face_to((0, -0.6, 0.6)), sides=10)
    rig.add("gear", p, parent="head", pivot=(0, -0.6, 1.42))
    prev = "neck"
    for i, (nm, part, pt) in enumerate(segs):
        if i == 0:
            rig.add(nm, part, parent="neck", pivot=pts[1])
            prev = nm
            continue
        rig.add(nm, part, parent=prev, pivot=pts[i])
        prev = nm
    p = Part()                                                                                       # Sandhaufen (nur unter der Erde sichtbar)
    p.ball(0.6, (0, 0, 0.0), SAND, scale=(1.0, 1.6, 0.35), subdiv=2)
    for k in range(5):
        p.ball(0.12, (0.4 * math.cos(k * 1.3), 0.9 * math.sin(k * 1.3), 0.08), SAND_D, subdiv=1)
    rig.add("sand", p, pivot=(0, 0, 0))
    hid = dict(scale=(0.02, 0.02, 0.02))
    rest = dict(root=dict(loc=(0, 0, 0), rot=(0, 0, 0)), neck=dict(loc=(0, 0, 0), rot=(0, 0, 0), scale=1.0), head=R(), gear=R(), sand=hid, **{s[0]: R() for s in segs})
    with rig.clip("idle", 36, loop=True) as c:                      # wiegt sich wie eine Kobra, das Zahnrad mahlt
        c.key(0, **rest)
        c.key(9, neck=R(0, 0, 14), head=R(0, 0, -10), seg2=R(0, 0, -8), gear=R(0, 0, 90))
        c.key(18, neck=R(6, 0, 0), head=R(-10, 0, 0), gear=R(0, 0, 180))
        c.key(27, neck=R(0, 0, -14), head=R(0, 0, 10), seg2=R(0, 0, 8), gear=R(0, 0, 270))
    with rig.clip("walk", 18, loop=True, stride=1.8) as c:          # schlängelt
        c.wave("neck", rot=(0, 0, 14))
        for i, s in enumerate(segs[1:]):
            c.wave(s[0], rot=(0, 0, 22), phase=0.15 * (i + 1))
        c.wave("head", rot=(0, 0, -10), phase=0.1)
        c.key(0, sand=hid)
    with rig.clip("attack", 18, hit=10) as c:                       # stößt zu und schnappt
        c.key(0, **rest)
        c.key(6, neck=R(-25, 0, 0), head=R(-20, 0, 0), gear=R(0, 0, 120))
        c.key(10, neck=R(35, 0, 0), head=R(10, 0, 0), root=dict(loc=(0, -0.3, 0)), gear=R(0, 0, 360), _i="LINEAR")
        c.key(18, **rest)
    with rig.clip("hit", 9) as c:
        c.key(0, **rest)
        c.key(3, neck=R(-20, 0, 12), head=R(-20, 0, 0), seg3=R(0, 0, -16))
        c.key(9, **rest)
    with rig.clip("death", 33) as c:                                # sackt zusammen, die Reifen rollen auseinander
        c.key(0, **rest)
        c.key(10, neck=R(-20, 0, 0), head=R(-30, 0, 0))
        c.key(22, neck=dict(rot=(60, 0, 0), loc=(0, 0, -0.3)), head=R(30, 0, 20), seg2=R(-20, 0, 20), seg3=R(-10, 0, -20), _i="LINEAR")
        c.key(33, neck=dict(rot=(62, 0, 10), loc=(0, 0, -0.35)), head=R(36, 0, 30), gear=R(0, 0, 40))
    with rig.clip("dig", 21) as c:                                  # bohrt sich kopfüber in den Sand
        c.key(0, **rest)
        c.key(3, sand=dict(scale=0.5))
        c.key(8, neck=R(70, 0, 0), head=R(30, 0, 0), sand=dict(scale=1.0), gear=R(0, 0, 360))
        c.key(15, neck=dict(rot=(90, 0, 0), loc=(0, 0, -1.0)), head=R(20, 0, 0), gear=R(0, 0, 720))
        c.key(21, neck=dict(rot=(90, 0, 0), loc=(0, 0, -1.6), scale=0.3), sand=dict(scale=(0.8, 0.8, 0.8)))
    with rig.clip("under", 12, loop=True, stride=1.8) as c:         # nur die Sandspur
        c.key(0, neck=dict(rot=(90, 0, 0), loc=(0, 0, -1.6), scale=0.3), sand=dict(scale=(0.8, 0.8, 0.8)))
        c.key(6, sand=dict(scale=(0.9, 0.9, 1.1)))
    with rig.clip("rise", 15) as c:                                  # bricht senkrecht hervor
        c.key(0, neck=dict(rot=(-10, 0, 0), loc=(0, 0, -1.6), scale=0.3), sand=dict(scale=(0.8, 0.8, 0.8)), head=R(-30, 0, 0))
        c.key(6, neck=dict(rot=(-20, 0, 0), loc=(0, 0, 0.4), scale=1.0), head=R(-40, 0, 0), sand=dict(scale=(1.2, 1.2, 0.6)), gear=R(0, 0, 360))
        c.key(15, **rest)
    rig.finish(icon_pitch=14)


# ================================================================= Boss: Rostbrocken – Schrottgolem mit Abrissbirne
def boss_wueste():
    rig = Rig("boss_wueste", role="boss")
    rig.node("hips", pivot=(0, 0, 1.4))
    p = Part()                                                                                      # Rumpf: zusammengepresstes Auto
    p.box((2.0, 1.4, 1.6), (0, 0, 2.5), TEAL, bevel=0.2, segs=2)
    p.box((1.6, 1.0, 0.6), (0, 0.05, 3.5), TEAL_D, bevel=0.12, segs=1)                              # Dach
    p.box((1.3, 0.05, 0.45), (0, -0.53, 3.5), "9FE4FF", bevel=0.0)                                   # Windschutzscheibe
    p.box((2.05, 0.2, 0.25), (0, -0.75, 2.0), CHROME, bevel=0.06, segs=1)                           # Stoßstange als Gürtel
    for s in (-1, 1):
        p.cyl(0.18, 0.1, (0.7 * s, -0.72, 2.45), "FFF2A0", r=rot(90, 0, 0), sides=10)               # Scheinwerfer
        p.torus(0.45, 0.16, (1.02 * s, 0.1, 1.9), TIRE, r=rot(0, 90, 0), seg=12, tseg=5)            # Reifen an der Hüfte
    p.box((0.5, 0.06, 0.25), (0, -0.72, 1.7), YEL, bevel=0.0)                                         # Nummernschild
    for (x, y, z) in ((0.6, -0.71, 3.0), (-0.5, 0.71, 2.8), (0.9, 0.3, 3.2)):
        p.ball(0.18, (x, y, z), RUST, scale=(1, 0.4, 1), subdiv=1)
    p.cyl(0.12, 0.8, (-0.6, 0.6, 4.0), CHROME_D, sides=6)                                            # Auspuff-Schlote
    p.cyl(0.1, 0.6, (-0.3, 0.65, 3.9), CHROME_D, sides=6)
    rig.add("torso", p, parent="hips", pivot=(0, 0, 1.9))
    p = Part()                                                                                      # Kopf: Ölfass mit Schlitzaugen und Kühlergrill-Gebiss
    lathe(p, [(0.45, 3.8, RED), (0.5, 3.9, RED), (0.5, 4.3, RED), (0.52, 4.35, CHROME_D), (0.5, 4.4, RED), (0.48, 4.7, RED), (0.0, 4.72, RUST_D)], sides=14)
    for k in range(6):
        p.box((0.06, 0.05, 0.28), (-0.25 + k * 0.1, -0.5, 4.0), CHROME, bevel=0.0)
    p.box((0.75, 0.08, 0.12), (0, -0.48, 4.45), INK, bevel=0.0)
    rig.add("head", p, parent="torso", pivot=(0, 0, 3.8))
    p = Part()
    for s in (-1, 1):
        p.box((0.2, 0.06, 0.08), (0.18 * s, -0.53, 4.45), "FF6A2A", bevel=0.0)
    rig.add("eyes", p, parent="head", pivot=(0, -0.53, 4.45), glow=True)
    for s, nm in ((1, "arm_l"), (-1, "arm_r")):                                                    # Arme aus Rohren
        p = Part()
        p.ball(0.4, (1.25 * s, 0, 3.2), RUST, subdiv=2)
        capsule(p, (1.3 * s, 0, 3.1), (1.6 * s, -0.1, 2.3), 0.22, 0.2, CHROME_D, sides=7)
        rig.add(nm, p, parent="torso", pivot=(1.25 * s, 0, 3.2))
        p = Part()
        capsule(p, (1.6 * s, -0.1, 2.3), (1.65 * s, -0.3, 1.5), 0.2, 0.18, RUST_D, sides=7)
        if s > 0:
            p.box((0.5, 0.5, 0.45), (1.65 * s, -0.32, 1.3), YEL, bevel=0.08, segs=1)                 # Schaufelfaust
        else:
            p.ball(0.3, (1.65 * s, -0.32, 1.32), RUST, subdiv=2)
            for k in range(5):
                p.torus(0.1, 0.035, (1.65 * s, -0.32 - 0.0, 1.0 - k * 0.18), CHROME_D, r=rot(90 * (k % 2), 0, 0), seg=6, tseg=3)
        rig.add(nm.replace("arm", "fore"), p, parent=nm, pivot=(1.6 * s, -0.1, 2.3))
    p = Part()                                                                                      # Abrissbirne an der Kette
    p.ball(0.55, (-1.65, -0.32, 0.4), INK, subdiv=2)
    p.cyl(0.12, 0.15, (-1.65, -0.32, 0.98), CHROME_D, sides=6)
    for (x, y, z) in ((0.3, -0.4, 0.5), (-0.4, -0.2, 0.6), (0, 0.45, 0.2)):
        p.ball(0.08, (-1.65 + x, -0.32 + y, z + 0.1), RUST, subdiv=1)
    rig.add("ball", p, parent="fore_r", pivot=(-1.65, -0.32, 1.05))
    for s, nm in ((1, "leg_l"), (-1, "leg_r")):
        p = Part()
        lathe(p, [(0.42, 0.0, TIRE), (0.45, 0.25, TIRE), (0.35, 0.35, CHROME_D), (0.3, 1.3, RUST_D), (0.36, 1.45, RUST_D)], sides=9, loc=(0.6 * s, 0, 0))
        rig.add(nm, p, parent="hips", pivot=(0.6 * s, 0, 1.4))
    rest = dict(root=dict(loc=(0, 0, 0), rot=(0, 0, 0)), hips=dict(loc=(0, 0, 0), rot=(0, 0, 0)), torso=R(), head=R(), arm_l=R(), arm_r=R(), fore_l=R(), fore_r=R(), ball=R(), leg_l=R(), leg_r=R(), eyes=dict(scale=1.0))
    with rig.clip("idle", 48, loop=True) as c:                      # brummt, die Birne pendelt
        c.key(0, **rest)
        c.key(12, torso=R(0, 3, 0), ball=R(14, 0, 0), head=R(0, 0, 10))
        c.key(24, torso=R(0, 0, 0), ball=R(0, 0, 0), eyes=dict(scale=(1, 1, 0.3)))
        c.key(27, eyes=dict(scale=1.0))
        c.key(36, torso=R(0, -3, 0), ball=R(-14, 0, 0), head=R(0, 0, -10))
    with rig.clip("walk", 48, loop=True, stride=2.4) as c:          # stampft, schaukelt, die Birne schwingt
        c.wave("leg_l", rot=(26, 0, 0))
        c.wave("leg_r", rot=(26, 0, 0), phase=0.5)
        c.wave("hips", rot=(0, 6, 0), phase=0.25)
        c.wave("hips", loc=(0, 0, 0.1), n=2, phase=0.25)
        c.wave("arm_l", rot=(-16, 0, 0), phase=0.5)
        c.wave("arm_r", rot=(-12, 0, 0), phase=0.0)
        c.wave("ball", rot=(26, 0, 0), phase=0.1)
        c.wave("head", rot=(0, 0, 6), phase=0.5)
    with rig.clip("attack", 36, hit=19) as c:                       # Schaufelfaust von oben
        c.key(0, **rest)
        c.key(12, torso=R(-12, 0, 14), arm_l=R(-160, 0, -10), fore_l=R(-30, 0, 0))
        c.key(19, torso=R(18, 0, -6), arm_l=R(-40, 0, 10), fore_l=R(0, 0, 0), hips=dict(loc=(0, -0.2, -0.15)), _i="LINEAR")
        c.key(36, **rest)
    with rig.clip("hit", 9) as c:
        c.key(0, **rest)
        c.key(3, torso=R(-8, 0, 6), head=dict(rot=(-14, 0, 10)), ball=R(-30, 0, 0))
        c.key(9, **rest)
    with rig.clip("death", 60) as c:                                # Funken, Augen aus, fällt auseinander und auf den Rücken
        c.key(0, **rest)
        c.key(12, torso=R(-10, 0, 10), head=R(-20, 0, 20), eyes=dict(scale=1.5))
        c.key(18, eyes=dict(scale=0.3))
        c.key(22, eyes=dict(scale=1.2))
        c.key(36, root=dict(rot=(-84, 0, 0), loc=(0, 0, 1.0)), head=dict(rot=(-30, 0, 40)), arm_l=R(-120, 0, 30), arm_r=R(-120, 0, -30), ball=R(80, 0, 0), _i="LINEAR")
        c.key(42, root=dict(rot=(-78, 0, 0), loc=(0, 0, 1.15)))
        c.key(60, root=dict(rot=(-86, 0, 0), loc=(0, 0, 1.0)), eyes=dict(scale=0.05), head=R(-40, 0, 60))
    with rig.clip("slam", 42, hit=22) as c:                         # Bodenschlag mit beiden Armen
        c.key(0, **rest)
        c.key(14, torso=R(-18, 0, 0), arm_l=R(-170, 0, -20), arm_r=R(-170, 0, 20), fore_l=R(-30, 0, 0), fore_r=R(-30, 0, 0), ball=R(-90, 0, 0), hips=dict(loc=(0, 0, 0.2)))
        c.key(22, torso=R(30, 0, 0), arm_l=R(-40, 0, 0), arm_r=R(-40, 0, 0), fore_l=R(0, 0, 0), fore_r=R(0, 0, 0), ball=R(20, 0, 0), hips=dict(loc=(0, -0.3, -0.4)), _i="LINEAR")
        c.key(30, torso=R(24, 0, 0))
        c.key(42, **rest)
    with rig.clip("special", 45, hit=26) as c:                     # Autowrack werfen: wirbelt die Birne über dem Kopf und schleudert
        c.key(0, **rest)
        c.key(10, arm_r=R(-170, 0, 10), fore_r=R(0, 0, 0), ball=R(0, 0, 0), torso=R(-10, 0, 0))
        c.key(16, ball=R(0, 120, 0), torso=R(-10, 0, 20), _i="LINEAR")
        c.key(22, ball=R(0, 240, 0), torso=R(-10, 0, -20), _i="LINEAR")
        c.key(26, arm_r=R(-60, 0, 0), ball=R(-80, 360, 0), torso=R(20, 0, 0), _i="LINEAR")
        c.key(45, **rest)
    rig.finish(icon_yaw=-26, icon_pitch=10)


TABLE = {"wueste_schrottkaefer": wueste_schrottkaefer, "wueste_staubteufel": wueste_staubteufel, "wueste_rostbulle": wueste_rostbulle, "wueste_kaktusschuetze": wueste_kaktusschuetze,
         "wueste_geier": wueste_geier, "wueste_sandwurm": wueste_sandwurm, "boss_wueste": boss_wueste}

if __name__ == "__main__":
    run(TABLE, [a for a in sys.argv if not a.startswith("--")])
