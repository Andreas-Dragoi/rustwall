"""Paket Z2 – Maschinen der Stadtruinen (Gebiet 9): sechs Arten, drei Rollen aus G2 (Reparatur-Bot, Schild-Bot, Störsender),
Miniboss Abrisskran und Boss Bürgermeister Bolzen (echte Boss-Figur).

| Art | Rolle | besondere Clips |
|---|---|---|
| maschinen_maeher | mass | rev (Motor heult auf), mow (Mähsturm, Schleife), spawn |
| maschinen_funkenspinne | fast | pounce, climb (klettert an der Fassade hoch), spawn |
| maschinen_baggergolem | tank | scoop (schaufelt Schutt und schleudert ihn), spawn |
| maschinen_ampelwaechter | ranged | signal (schaltet Rot/Grün), spawn |
| maschinen_drohne | air | zap (Schuss aus dem Elektroschocker), spawn |
| maschinen_muellpresse | special | grab (Greifarm schnappt und zieht), spawn |
| maschinen_reparaturbot | healer | repair (schweißt Freunde heil), spawn |
| maschinen_schildbot | shield | block, spawn |
| maschinen_stoersender | jammer | jam (schleudert eine Störscheibe), spawn |
| maschinen_abrisskran | miniboss | skill (Abrissbirne), spawn |
| boss_maschinen | boss | special (Stromstoß), summon (läutet die Rathausglocke), slam |

Aufruf:  python3 blender/enemies_maschinen.py [art ...] [--notafel]"""
import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from enemies2_kit import *

# Farben der Familie: Baustellengelb, Stahl, Rost, Gummi, Signalfarben, Leuchtdioden
YEL, YEL_D = "F2B81E", "C88E14"
STL, STL_D, STL_L = "7A8290", "565C68", "A2AAB6"
RST, RST_D = "A4562C", "7A3E20"
RUB = "26282E"
RED, RED_D = "D8403A", "A02A26"
WHT = "EEEEE8"
ORA = "F07A1E"
CYAN, CYAN_L = "4AD8FF", "B8F4FF"
LED_R, LED_G, LED_Y = "FF3A2A", "3AFF6A", "FFC21A"
INK = "16181C"
GOLD = "F2C230"
GRN = "3A8A4A"


def bolts(p, pts, r=0.03, color=STL_D):
    for q in pts:
        p.ball(r, q, color, subdiv=1)


# ================================================================= Rasenmäher-Bot (Masse)
def maschinen_maeher():
    rig = Rig("maschinen_maeher", role="mass", size=1.3)
    p = Part()                                                                                       # Gehäuse mit Grasfangkorb
    p.box((0.78, 0.95, 0.32), (0, -0.05, 0.3), RED, bevel=0.0)
    p.box((0.7, 0.85, 0.06), (0, -0.05, 0.47), RED_D, bevel=0.0)
    p.box((0.6, 0.45, 0.38), (0, 0.6, 0.38), "4A8A3A", bevel=0.0)                                   # Fangkorb
    p.box((0.62, 0.06, 0.4), (0, 0.38, 0.38), STL_D, bevel=0.0)
    for (x, y) in ((-0.42, -0.38), (0.42, -0.38), (-0.42, 0.3), (0.42, 0.3)):                        # Räder
        p.cyl(0.14, 0.1, (x, y, 0.14), RUB, r=rot(0, 90, 0), sides=8)
        p.cyl(0.06, 0.12, (x, y, 0.14), STL_L, r=rot(0, 90, 0), sides=6)
    rig.add("body", p, pivot=(0, 0, 0.3))
    p = Part()                                                                                       # Kopf: Kuppel mit Kamera-Augen
    p.ball(0.2, (0, -0.15, 0.55), STL, scale=(1.2, 1.0, 0.7), subdiv=1)
    p.box((0.34, 0.08, 0.1), (0, -0.33, 0.58), INK, bevel=0.0)
    rig.add("head", p, parent="body", pivot=(0, -0.15, 0.5))
    p = Part()
    for s in (-1, 1):
        p.ball(0.045, (0.09 * s, -0.38, 0.59), CYAN, subdiv=1)
    rig.add("glow", p, parent="head", pivot=(0, -0.38, 0.59), glow=True)
    p = Part()                                                                                       # Schiebebügel als Antennen
    capsule(p, (-0.25, 0.3, 0.45), (-0.3, 0.55, 1.0), 0.025, 0.02, STL_D, sides=4)
    capsule(p, (0.25, 0.3, 0.45), (0.3, 0.55, 1.0), 0.025, 0.02, STL_D, sides=4)
    capsule(p, (-0.3, 0.55, 1.0), (0.3, 0.55, 1.0), 0.03, 0.03, RUB, sides=4)
    rig.add("handle", p, parent="body", pivot=(0, 0.3, 0.45))
    p = Part()                                                                                       # Messer vorn (Scheibe mit Zacken)
    p.cyl(0.3, 0.03, (0, -0.55, 0.12), STL_L, sides=8)
    for k in range(4):
        a = k * math.tau / 4
        p.box((0.16, 0.05, 0.03), (0.3 * math.cos(a), -0.55 + 0.3 * math.sin(a), 0.12), WHT, r=rot(0, 0, math.degrees(a)))
    rig.add("blade", p, parent="body", pivot=(0, -0.55, 0.12))
    rest = rest_pose(rig)
    with rig.clip("idle", 24, loop=True) as c:                     # Motor tuckert, Bügel wippt
        K(c, rig, 0, **rest)
        K(c, rig, 6, body=dict(loc=(0, 0, 0.015), rot=(0, 2, 0)), handle=R(-4, 0, 0), blade=R(0, 0, 40))
        K(c, rig, 12, body=dict(loc=(0, 0, 0.0), rot=(0, -2, 0)), handle=R(3, 0, 0), head=R(0, 0, 12), blade=R(0, 0, 80))
        K(c, rig, 18, body=dict(loc=(0, 0, 0.015)), head=R(0, 0, -12), blade=R(0, 0, 40))
    with rig.clip("walk", 15, loop=True, stride=2.1 * 15 / 30.0) as c:    # rattert über den Asphalt
        K(c, rig, 0, **rest)
        c.wave("body", loc=(0, 0, 0.03), rot=(3, 2, 0), n=2)
        c.wave("handle", rot=(8, 0, 0), n=2, phase=0.25)
        c.wave("head", rot=(0, 0, 10))
        c.wave("blade", rot=(0, 0, 30), n=2)
    with rig.clip("attack", 18, hit=9) as c:                       # ruckt vor, das Messer schnappt zu
        K(c, rig, 0, **rest)
        K(c, rig, 5, body=dict(rot=(-10, 0, 0), loc=(0, 0.12, 0.05)), head=R(-15, 0, 0))
        K(c, rig, 9, _i="LINEAR", body=dict(rot=(12, 0, 0), loc=(0, -0.25, 0)), blade=dict(rot=(0, 0, 160), scale=1.2))
        K(c, rig, 18, **rest)
    with rig.clip("hit", 9) as c:
        K(c, rig, 0, **rest)
        K(c, rig, 3, body=dict(rot=(-8, 6, 0), loc=(0, 0.06, 0.08)), handle=R(-14, 0, 0), glow=dict(scale=0.4))
        K(c, rig, 9, **rest)
    with rig.clip("death", 27) as c:                               # kippt um, der Korb fliegt weg, die Augen gehen aus
        K(c, rig, 0, **rest)
        K(c, rig, 6, body=dict(rot=(0, 20, 0), loc=(0, 0, 0.15)), handle=R(-30, 0, 20), glow=dict(scale=1.5))
        K(c, rig, 15, _i="LINEAR", body=dict(rot=(0, 85, 0), loc=(0.2, 0, 0.1)), handle=dict(rot=(-60, 0, 40), loc=(0.1, 0.3, -0.2)), blade=dict(loc=(-0.2, -0.3, -0.05)))
        K(c, rig, 27, body=dict(rot=(0, 90, 0), loc=(0.25, 0, 0.12)), handle=dict(rot=(-80, 0, 50), loc=(0.15, 0.4, -0.3)), glow=dict(scale=0.05))
    with rig.clip("rev", 18) as c:                                 # Motor heult auf: zittert, das Messer dreht hoch
        K(c, rig, 0, **rest)
        K(c, rig, 4, body=dict(rot=(-6, 3, 0), loc=(0, 0.06, 0.03)), blade=R(0, 0, 120), glow=dict(scale=1.6))
        K(c, rig, 8, body=dict(rot=(-6, -3, 0)), blade=R(0, 0, 240))
        K(c, rig, 12, body=dict(rot=(-7, 3, 0)), blade=R(0, 0, 360), head=R(-10, 0, 0))
        K(c, rig, 18, body=dict(rot=(-4, 0, 0)), blade=R(0, 0, 480), glow=dict(scale=1.3))
    with rig.clip("mow", 12, loop=True) as c:                      # Mähsturm: hüpft, das Messer ist ein Wirbel
        K(c, rig, 0, **dict(rest, body=dict(rot=(8, 0, 0)), blade=dict(scale=(1.25, 1.25, 1.0))))
        K(c, rig, 3, body=dict(loc=(0, 0, 0.06), rot=(6, 4, 0)), blade=dict(rot=(0, 0, 90), scale=(1.25, 1.25, 1.0)), handle=R(12, 0, 0))
        K(c, rig, 6, body=dict(loc=(0, 0, 0.0), rot=(8, -4, 0)), blade=dict(rot=(0, 0, 180), scale=(1.25, 1.25, 1.0)))
        K(c, rig, 9, body=dict(loc=(0, 0, 0.06), rot=(6, 4, 0)), blade=dict(rot=(0, 0, 270), scale=(1.25, 1.25, 1.0)), handle=R(4, 0, 0))
    spawn_clip(rig, rest, 0.8)
    rig.finish(icon_yaw=-35, icon_pitch=22)


# ================================================================= Funkenspinne (Flitzer)
def maschinen_funkenspinne():
    rig = Rig("maschinen_funkenspinne", role="fast", size=1.2)
    p = Part()                                                                                       # Rumpf: Stahlkugel mit Warnstreifen
    p.ball(0.3, (0, 0.05, 0.45), STL_D, scale=(1.0, 1.2, 0.7), subdiv=1)
    p.box((0.62, 0.12, 0.05), (0, 0.05, 0.62), ORA, bevel=0.0)
    p.box((0.42, 0.1, 0.05), (0, 0.32, 0.56), ORA, bevel=0.0)
    rig.add("body", p, pivot=(0, 0, 0.45))
    p = Part()                                                                                       # Kopf mit roten Leuchtaugen
    p.ball(0.16, (0, -0.33, 0.45), STL, scale=(1.1, 0.9, 0.8), subdiv=1)
    for s in (-1, 1):
        capsule(p, (0.07 * s, -0.42, 0.38), (0.12 * s, -0.56, 0.3), 0.025, 0.015, STL_L, sides=4)     # Zangen
    rig.add("head", p, parent="body", pivot=(0, -0.22, 0.45))
    p = Part()
    for (x, z) in ((-0.06, 0.5), (0.06, 0.5), (-0.1, 0.44), (0.1, 0.44)):
        p.ball(0.03, (x, -0.47, z), LED_R, subdiv=1)
    p.ball(0.07, (0, 0.05, 0.92), CYAN_L, subdiv=1)                                                  # Funkenkugel
    rig.add("glow", p, parent="body", pivot=(0, 0.05, 0.9), glow=True)
    p = Part()                                                                                       # Teslaspule auf dem Rücken
    p.cyl(0.05, 0.3, (0, 0.05, 0.72), STL_L, sides=6)
    for k in range(3):
        p.cyl(0.08 - k * 0.012, 0.03, (0, 0.05, 0.64 + k * 0.08), GOLD, sides=6)
    rig.add("coil", p, parent="body", pivot=(0, 0.05, 0.62))
    legs = []
    for i, y in enumerate((-0.18, 0.06, 0.3)):
        for s in (1, -1):
            nm = "leg_%d%s" % (i, "l" if s > 0 else "r")
            p = Part()
            capsule(p, (0.22 * s, y, 0.45), (0.48 * s, y - 0.04, 0.62), 0.03, 0.025, STL_D, sides=4)
            capsule(p, (0.48 * s, y - 0.04, 0.62), (0.6 * s, y - 0.06, 0.0), 0.025, 0.012, STL, sides=4)
            rig.add(nm, p, parent="body", pivot=(0.22 * s, y, 0.45))
            legs.append((nm, (i * 0.33 + (0.0 if s > 0 else 0.5)) % 1.0, s))

    def sp(name, c, rig, rest):
        if name == "idle":
            K(c, rig, 6, glow=dict(scale=1.4))
            K(c, rig, 18, glow=dict(scale=0.8))
    rest = quad(rig, legs, 0.45, 0.95, 5.2, "fast", walk_n=12, leg_swing=26, side_legs=True, special=sp, hop=0.05)
    with rig.clip("pounce", 15) as c:                              # duckt sich, Funken, Sprung
        K(c, rig, 0, **rest)
        K(c, rig, 4, body=dict(rot=(-12, 0, 0), loc=(0, 0.08, -0.12)), glow=dict(scale=1.8))
        K(c, rig, 8, _i="LINEAR", root=dict(loc=(0, -0.4, 0.6)), body=dict(rot=(12, 0, 0)))
        K(c, rig, 12, root=dict(loc=(0, -0.7, 0.1)), body=dict(rot=(16, 0, 0)))
        K(c, rig, 15, **rest)
    with rig.clip("climb", 24, loop=True) as c:                    # klettert an einer Wand hoch: aufgerichtet, Beine greifen
        up = dict(rest, root=dict(rot=(-70, 0, 0), loc=(0, 0.15, 0.25)))
        K(c, rig, 0, **up)
        for (nm, ph, s) in legs:
            c.wave(nm, rot=(30, 0, 18 * s), phase=ph)
        c.wave("body", loc=(0, 0, 0.05), n=2)
        c.wave("glow", scale=(0.4, 0.4, 0.4), base_scale=(1.2, 1.2, 1.2), n=2)
    rig.finish(icon_yaw=-35, icon_pitch=24)


# ================================================================= Bagger-Golem (Brocken)
def maschinen_baggergolem():
    rig = Rig("maschinen_baggergolem", role="tank")
    rig.node("hips", pivot=(0, 0, 1.15))
    p = Part()                                                                                       # Rumpf: Baggeroberwagen
    p.box((1.7, 1.3, 1.2), (0, 0.1, 1.85), YEL, bevel=0.12, segs=1)
    p.box((1.5, 0.9, 0.5), (0, 0.65, 1.55), RUB, bevel=0.0)                                          # Gegengewicht
    p.box((1.72, 0.1, 0.2), (0, -0.56, 2.2), INK, bevel=0.0)                                         # Warnstreifen
    for k in range(5):
        p.box((0.2, 0.11, 0.21), (-0.7 + k * 0.35, -0.57, 2.2), YEL_D if k % 2 else YEL, r=rot(0, 30, 0))
    p.cyl(0.08, 0.6, (0.6, 0.55, 2.7), STL_D, sides=6)                                               # Auspuff
    bolts(p, [(-0.7, -0.56, 1.5), (0.7, -0.56, 1.5), (-0.7, -0.56, 1.95), (0.7, -0.56, 1.95)])
    rig.add("body", p, parent="hips", pivot=(0, 0, 1.15))
    p = Part()                                                                                       # Kopf: Fahrerkabine
    p.box((0.75, 0.7, 0.65), (0, -0.2, 2.75), YEL_D, bevel=0.08, segs=1)
    p.box((0.62, 0.06, 0.4), (0, -0.56, 2.8), "2A3440", bevel=0.0)
    p.box((0.8, 0.75, 0.08), (0, -0.2, 3.1), RUB, bevel=0.0)
    rig.add("head", p, parent="body", pivot=(0, -0.1, 2.45))
    p = Part()
    for s in (-1, 1):
        p.box((0.14, 0.05, 0.1), (0.2 * s, -0.6, 2.85), "FFF2B0", bevel=0.0)                        # Scheinwerfer-Augen
    p.ball(0.07, (0, -0.2, 3.18), ORA, subdiv=1)                                                     # Rundumleuchte
    rig.add("glow", p, parent="head", pivot=(0, -0.6, 2.85), glow=True)
    p = Part()                                                                                       # rechter Arm: Baggerschaufel
    capsule(p, (-0.95, 0.0, 2.3), (-1.15, -0.4, 1.5), 0.2, 0.17, YEL, sides=6)
    capsule(p, (-1.15, -0.4, 1.5), (-1.15, -0.9, 1.05), 0.16, 0.14, YEL_D, sides=6)
    p.box((0.8, 0.6, 0.45), (-1.15, -1.1, 0.85), STL_D, bevel=0.06, segs=1)
    for k in range(4):
        p.cone(0.07, 0.22, (-1.43 + k * 0.19, -1.42, 0.7), STL_L, r=rot(-110, 0, 0), sides=4)
    rig.add("arm_r", p, parent="body", pivot=(-0.95, 0.0, 2.3))
    p = Part()                                                                                       # linker Arm: Hydraulikklaue
    capsule(p, (0.95, 0.0, 2.3), (1.15, -0.3, 1.5), 0.2, 0.17, YEL, sides=6)
    capsule(p, (1.15, -0.3, 1.5), (1.15, -0.5, 0.95), 0.12, 0.12, STL, sides=6)
    for s in (-1, 1):
        capsule(p, (1.15 + 0.12 * s, -0.5, 0.95), (1.15 + 0.2 * s, -0.7, 0.6), 0.07, 0.04, STL_D, sides=4)
    rig.add("arm_l", p, parent="body", pivot=(0.95, 0.0, 2.3))
    for s, nm in ((1, "leg_l"), (-1, "leg_r")):                                                     # Beine: Kettenlaufwerke
        p = Part()
        p.box((0.5, 1.2, 0.5), (0.5 * s, -0.05, 0.3), RUB, bevel=0.1, segs=1)
        for k in range(4):
            p.box((0.52, 0.1, 0.52), (0.5 * s, -0.5 + k * 0.3, 0.3), STL_D, bevel=0.0)
        capsule(p, (0.45 * s, 0, 1.1), (0.5 * s, 0, 0.55), 0.18, 0.16, YEL_D, sides=6)
        rig.add(nm, p, parent="hips", pivot=(0.45 * s, 0, 1.15))
    rest = biped(rig, 1.15, 3.2, 1.2, "tank", walk_n=30, leg_swing=18, arm_swing=10, death_side=True)
    with rig.clip("scoop", 33, hit=21) as c:                       # gräbt mit der Schaufel und schleudert den Schutt nach vorn
        K(c, rig, 0, **rest)
        K(c, rig, 9, body=R(24, 0, -10), arm_r=R(30, 0, -10), head=R(10, 0, 0), hips=dict(loc=(0, 0, -0.15)))
        K(c, rig, 15, body=R(18, 0, -14), arm_r=R(-20, 0, -15))
        K(c, rig, 21, _i="LINEAR", body=R(-14, 0, 10), arm_r=R(-165, 0, 5), head=R(-10, 0, 0), glow=dict(scale=1.4))
        K(c, rig, 27, body=R(-6, 0, 4), arm_r=R(-120, 0, 0))
        K(c, rig, 33, **rest)
    rig.finish(icon_yaw=-28, icon_pitch=12)


# ================================================================= Ampelwächter (Fernkämpfer)
def maschinen_ampelwaechter():
    rig = Rig("maschinen_ampelwaechter", role="ranged")
    rig.node("hips", pivot=(0, 0, 0.85))
    p = Part()                                                                                       # Rumpf: rot-weißer Mast im Mantel
    lathe(p, [(0.28, 0.8, RUB), (0.32, 0.95, STL_D), (0.3, 1.5, STL), (0.22, 1.65, STL_D)], sides=8)
    for k in range(3):
        p.cyl(0.31, 0.1, (0, 0, 1.0 + k * 0.2), (RED, WHT, RED)[k], sides=8)
    rig.add("body", p, parent="hips", pivot=(0, 0, 0.85))
    p = Part()                                                                                       # Kopf: Ampelgehäuse mit drei Lichtern
    p.box((0.42, 0.34, 1.0), (0, -0.02, 2.15), "2A2C30", bevel=0.0)
    for k in range(3):
        z = 2.48 - k * 0.32
        p.box((0.36, 0.16, 0.05), (0, -0.25, z + 0.15), INK, bevel=0.0)
        p.cyl(0.11, 0.03, (0, -0.2, z), ("5A2020", "5A4A18", "1E4A24")[k], r=rot(90, 0, 0), sides=10)
    rig.add("head", p, parent="body", pivot=(0, 0, 1.65))
    for k, (nm, colr) in enumerate((("lamp_r", LED_R), ("lamp_y", LED_Y), ("lamp_g", LED_G))):
        p = Part()
        p.cyl(0.11, 0.04, (0, -0.22, 2.48 - k * 0.32), colr, r=rot(90, 0, 0), sides=10)
        rig.add(nm, p, parent="head", pivot=(0, -0.22, 2.48 - k * 0.32), glow=True)
    for s, nm in ((1, "arm_l"), (-1, "arm_r")):                                                     # Arme mit Signalkellen
        p = Part()
        capsule(p, (0.3 * s, 0, 1.55), (0.42 * s, -0.2, 1.1), 0.06, 0.05, STL_D, sides=5)
        p.cyl(0.04, 0.35, (0.45 * s, -0.25, 0.95), WHT, sides=5)
        p.cyl(0.16, 0.04, (0.45 * s, -0.27, 0.72), (RED if s > 0 else GRN), r=rot(90, 0, 0), sides=10)
        p.cyl(0.08, 0.05, (0.45 * s, -0.29, 0.72), WHT, r=rot(90, 0, 0), sides=8)
        rig.add(nm, p, parent="body", pivot=(0.3 * s, 0, 1.55))
    for s, nm in ((1, "leg_l"), (-1, "leg_r")):
        p = Part()
        capsule(p, (0.15 * s, 0, 0.82), (0.17 * s, 0, 0.12), 0.08, 0.07, STL_D, sides=5)
        p.box((0.24, 0.36, 0.12), (0.17 * s, -0.06, 0.06), RUB, bevel=0.0)
        rig.add(nm, p, parent="hips", pivot=(0.15 * s, 0, 0.85))
    rest = rest_pose(rig, {"lamp_y": dict(scale=0.3), "lamp_g": dict(scale=0.3)})

    def sp(name, c, rig, rest):
        if name == "attack":                                           # Rot leuchtet beim Schuss
            K(c, rig, 6, lamp_r=dict(scale=1.6))
            K(c, rig, 12, lamp_r=dict(scale=2.0), arm_l=R(-95, 0, 10))
            K(c, rig, 20, lamp_r=dict(scale=1.0))
    biped(rig, 0.85, 2.7, 1.9, "ranged", walk_n=24, leg_swing=24, arm_swing=14, attack="thrust",
          rest_extra={"lamp_y": dict(scale=0.3), "lamp_g": dict(scale=0.3)}, special=sp)
    with rig.clip("signal", 30) as c:                              # schaltet um: Kellen hoch, Lichter wechseln
        K(c, rig, 0, **rest)
        K(c, rig, 6, arm_l=R(-160, 0, -10), arm_r=R(-160, 0, 10), lamp_r=dict(scale=0.3), lamp_y=dict(scale=1.6))
        K(c, rig, 12, lamp_y=dict(scale=0.3), lamp_g=dict(scale=1.8), head=R(0, 0, 15))
        K(c, rig, 18, lamp_g=dict(scale=0.3), lamp_r=dict(scale=1.8), head=R(0, 0, -15), arm_l=R(-60, 0, 30), arm_r=R(-60, 0, -30))
        K(c, rig, 24, lamp_r=dict(scale=1.2), head=R(0, 0, 0))
        K(c, rig, 30, **rest)
    spawn_clip(rig, rest, 1.4)
    rig.finish(icon_yaw=-24, icon_pitch=12)


# ================================================================= Drohne (Flieger, im Schwarm)
def maschinen_drohne():
    rig = Rig("maschinen_drohne", role="air", size=1.25)
    p = Part()                                                                                       # Rumpf
    p.ball(0.26, (0, 0, 0.75), STL_L, scale=(1.0, 1.25, 0.6), subdiv=1)
    p.box((0.3, 0.3, 0.06), (0, 0.05, 0.92), ORA, bevel=0.0)
    for (x, y) in ((0.42, -0.42), (-0.42, -0.42), (0.42, 0.42), (-0.42, 0.42)):                       # Ausleger und Motoren
        capsule(p, (0, 0, 0.78), (x, y, 0.82), 0.035, 0.03, STL_D, sides=4)
        p.cyl(0.06, 0.1, (x, y, 0.85), RUB, sides=6)
    p.box((0.08, 0.08, 0.25), (0, -0.05, 0.5), STL_D, bevel=0.0)                                     # Elektroschocker
    for s in (-1, 1):
        p.cone(0.025, 0.12, (0.04 * s, -0.05, 0.33), STL_L, r=rot(180, 0, 0), sides=4)
    rig.add("body", p, pivot=(0, 0, 0.75))
    p = Part()                                                                                       # vier Rotoren (durchscheinend)
    for (x, y) in ((0.42, -0.42), (-0.42, -0.42), (0.42, 0.42), (-0.42, 0.42)):
        p.cyl(0.15, 0.02, (x, y, 0.92), "AEB8C4", sides=8)
    rig.add("rotors", p, parent="body", pivot=(0, 0, 0.92), ghost=True)
    p = Part()
    p.ball(0.08, (0, -0.3, 0.72), LED_R, subdiv=1)                                                   # Kamera-Auge
    p.ball(0.035, (0, -0.05, 0.36), CYAN_L, subdiv=1)                                                # Funke am Schocker
    rig.add("glow", p, parent="body", pivot=(0, -0.3, 0.72), glow=True)
    rest = rest_pose(rig)
    with rig.clip("idle", 18, loop=True) as c:                     # schwebt, Rotoren flirren
        K(c, rig, 0, **rest)
        K(c, rig, 6, body=dict(loc=(0, 0, 0.06), rot=(3, -3, 0)), rotors=dict(scale=(1.08, 1.08, 1.0)))
        K(c, rig, 12, body=dict(loc=(0, 0, -0.03), rot=(-3, 3, 0)), rotors=dict(scale=(0.94, 0.94, 1.0)), glow=dict(scale=1.3))
    with rig.clip("walk", 18, loop=True, stride=3.8 * 18 / 30.0) as c:    # fliegt nach vorn geneigt
        K(c, rig, 0, **dict(rest, body=dict(rot=(16, 0, 0))))
        c.wave("body", loc=(0, 0, 0.05), rot=(2, 4, 0), n=2, base_rot=(16, 0, 0))
        c.wave("rotors", scale=(0.06, 0.06, 0.0), n=3, base_scale=(1, 1, 1))
    with rig.clip("attack", 15, hit=8) as c:                       # stößt hinab und schockt
        K(c, rig, 0, **rest)
        K(c, rig, 5, body=dict(rot=(-10, 0, 0), loc=(0, 0.15, 0.1)))
        K(c, rig, 8, _i="LINEAR", body=dict(rot=(25, 0, 0), loc=(0, -0.25, -0.2)), glow=dict(scale=2.2))
        K(c, rig, 15, **rest)
    with rig.clip("hit", 9) as c:
        K(c, rig, 0, **rest)
        K(c, rig, 3, body=dict(rot=(-18, 20, 0), loc=(0, 0.1, 0.1)), glow=dict(scale=0.4))
        K(c, rig, 9, **rest)
    with rig.clip("death", 24) as c:                               # trudelt, raucht und stürzt
        K(c, rig, 0, **rest)
        K(c, rig, 8, body=dict(rot=(30, 40, 120), loc=(0.1, 0, 0.1)), glow=dict(scale=1.6))
        K(c, rig, 16, _i="LINEAR", body=dict(rot=(60, 80, 300), loc=(0.2, 0.1, -0.4)), rotors=dict(scale=0.6))
        K(c, rig, 24, body=dict(rot=(85, 90, 360), loc=(0.25, 0.1, -0.62)), rotors=dict(scale=0.4), glow=dict(scale=0.05))
    with rig.clip("zap", 15, hit=9) as c:                          # schießt einen Blitz aus dem Schocker
        K(c, rig, 0, **rest)
        K(c, rig, 5, body=dict(rot=(-14, 0, 0), loc=(0, 0.1, 0.05)), glow=dict(scale=1.6))
        K(c, rig, 9, _i="LINEAR", body=dict(rot=(10, 0, 0), loc=(0, 0.12, 0.0)), glow=dict(scale=2.6))
        K(c, rig, 15, **rest)
    spawn_clip(rig, rest, 0.4)
    rig.finish(icon_yaw=-30, icon_pitch=20)


# ================================================================= Müllpresse (Sonderling)
def maschinen_muellpresse():
    rig = Rig("maschinen_muellpresse", role="special", size=1.1)
    p = Part()                                                                                       # Pressbehälter auf Ketten
    p.box((1.1, 1.3, 0.95), (0, 0.15, 0.85), GRN, bevel=0.0)
    p.box((1.15, 0.12, 0.1), (0, -0.5, 1.25), YEL, bevel=0.0)
    for k in range(3):                                                                               # Sicken
        p.box((0.05, 1.32, 0.6), (-0.4 + k * 0.4, 0.15, 0.85), "2E6E3C", bevel=0.0)
    for s in (-1, 1):
        p.box((0.28, 1.5, 0.38), (0.5 * s, 0.1, 0.22), RUB, bevel=0.0)
        for k in range(4):
            p.cyl(0.12, 0.3, (0.5 * s, -0.45 + k * 0.36, 0.2), STL_D, r=rot(0, 90, 0), sides=6)
    p.box((0.9, 0.08, 0.3), (0, 0.82, 1.15), "2A2C30", bevel=0.0)                                    # Mülltonnen-Schütte hinten
    rig.add("body", p, pivot=(0, 0, 0.6))
    p = Part()                                                                                       # Maul: Pressplatte oben (Kopf)
    p.box((1.15, 0.7, 0.18), (0, -0.25, 1.4), "2E6E3C", bevel=0.0)
    for k in range(5):                                                                               # Zähne
        p.cone(0.06, 0.18, (-0.42 + k * 0.21, -0.55, 1.26), WHT, r=rot(180, 0, 0), sides=4)
    rig.add("head", p, parent="body", pivot=(0, 0.1, 1.4))
    p = Part()                                                                                       # Unterkiefer mit Zähnen
    p.box((1.05, 0.3, 0.12), (0, -0.62, 0.75), STL_D, bevel=0.0)
    for k in range(5):
        p.cone(0.05, 0.15, (-0.42 + k * 0.21, -0.68, 0.85), WHT, sides=4)
    rig.add("jaw", p, parent="body", pivot=(0, -0.45, 0.75))
    p = Part()
    for s in (-1, 1):
        p.ball(0.06, (0.3 * s, -0.56, 1.55), LED_Y, subdiv=1)                                        # Warnleuchten-Augen
    rig.add("glow", p, parent="head", pivot=(0, -0.56, 1.55), glow=True)
    p = Part()                                                                                       # Greifarm oben (zieht den Helden heran)
    capsule(p, (0.3, 0.4, 1.35), (0.35, 0.0, 2.0), 0.07, 0.06, YEL, sides=5)
    capsule(p, (0.35, 0.0, 2.0), (0.35, -0.6, 2.05), 0.06, 0.05, YEL_D, sides=5)
    for s in (-1, 1):
        capsule(p, (0.35, -0.6, 2.05), (0.35 + 0.12 * s, -0.8, 1.85), 0.04, 0.025, STL_L, sides=4)
    rig.add("arm_r", p, parent="body", pivot=(0.3, 0.4, 1.35))
    rest = rest_pose(rig)
    with rig.clip("idle", 30, loop=True) as c:                     # das Maul mahlt
        K(c, rig, 0, **rest)
        K(c, rig, 8, head=R(-8, 0, 0), jaw=R(6, 0, 0), arm_r=R(-6, 0, 5))
        K(c, rig, 16, head=R(0, 0, 0), jaw=R(0, 0, 0), body=dict(scale=(1.02, 1.02, 0.98)))
        K(c, rig, 23, head=R(-6, 0, 0), jaw=R(4, 0, 0), glow=dict(scale=1.3))
    with rig.clip("walk", 24, loop=True, stride=1.6 * 24 / 30.0) as c:    # rollt auf Ketten, schaukelt
        K(c, rig, 0, **rest)
        c.wave("body", loc=(0, 0, 0.03), rot=(2, 2, 0), n=2)
        c.wave("arm_r", rot=(6, 0, 4), phase=0.25)
        c.wave("head", rot=(-4, 0, 0), n=2, phase=0.5)
    with rig.clip("attack", 21, hit=12) as c:                      # beißt mit dem Pressmaul zu
        K(c, rig, 0, **rest)
        K(c, rig, 7, head=R(-30, 0, 0), jaw=R(20, 0, 0), body=dict(rot=(-6, 0, 0), loc=(0, 0.1, 0)))
        K(c, rig, 12, _i="LINEAR", head=R(6, 0, 0), jaw=R(-4, 0, 0), body=dict(rot=(8, 0, 0), loc=(0, -0.2, 0)))
        K(c, rig, 21, **rest)
    with rig.clip("hit", 9) as c:
        K(c, rig, 0, **rest)
        K(c, rig, 3, body=dict(rot=(-6, 0, 6), loc=(0, 0.08, 0)), head=R(-12, 0, 0), glow=dict(scale=0.5))
        K(c, rig, 9, **rest)
    with rig.clip("death", 30) as c:                               # das Maul klappt auf, der Arm fällt ab, sackt zusammen
        K(c, rig, 0, **rest)
        K(c, rig, 8, head=R(-45, 0, 0), jaw=R(25, 0, 0), glow=dict(scale=1.6))
        K(c, rig, 18, _i="LINEAR", head=R(-70, 0, 10), arm_r=dict(rot=(60, 0, 40), loc=(0.2, 0, -0.6)), body=dict(rot=(0, 12, 0), loc=(0, 0, -0.2), scale=(1.05, 1.05, 0.85)))
        K(c, rig, 30, head=R(-75, 0, 12), arm_r=dict(rot=(80, 0, 50), loc=(0.3, 0, -0.9)), body=dict(rot=(0, 14, 0), loc=(0, 0, -0.25), scale=(1.05, 1.05, 0.8)), glow=dict(scale=0.05))
    with rig.clip("grab", 24, hit=10) as c:                        # schleudert den Greifarm nach vorn und zieht ein
        K(c, rig, 0, **rest)
        K(c, rig, 5, arm_r=R(-40, 0, 0), head=R(-20, 0, 0))
        K(c, rig, 10, _i="LINEAR", arm_r=dict(rot=(55, 0, 0), loc=(0, -0.3, -0.1), scale=(1.0, 1.4, 1.0)), head=R(-35, 0, 0), jaw=R(18, 0, 0))
        K(c, rig, 18, arm_r=R(-30, 0, 0), head=R(-30, 0, 0))
        K(c, rig, 24, **rest)
    spawn_clip(rig, rest, 1.2)
    rig.finish(icon_yaw=-35, icon_pitch=16)


# ================================================================= Reparatur-Bot (Heiler)
def maschinen_reparaturbot():
    rig = Rig("maschinen_reparaturbot", role="healer")
    rig.node("hips", pivot=(0, 0, 0.7))
    p = Part()                                                                                       # Rumpf: Werkzeugkiste
    p.box((0.62, 0.48, 0.7), (0, 0, 1.08), WHT, bevel=0.0)
    p.box((0.64, 0.5, 0.1), (0, 0, 1.4), RED, bevel=0.0)
    p.box((0.3, 0.06, 0.1), (0, 0.25, 1.48), STL_D, bevel=0.0)                                        # Griff
    rig.add("body", p, parent="hips", pivot=(0, 0, 0.7))
    p = Part()                                                                                       # Kopf: Schweißerhelm
    p.ball(0.22, (0, -0.02, 1.68), STL, scale=(1.0, 1.0, 0.95), subdiv=1)
    p.box((0.3, 0.08, 0.16), (0, -0.22, 1.66), INK, bevel=0.0)
    p.cyl(0.03, 0.25, (0.12, 0.05, 1.95), STL_D, sides=4)
    rig.add("head", p, parent="body", pivot=(0, 0, 1.45))
    p = Part()                                                                                       # grünes Kreuz und Augenschlitz
    p.box((0.22, 0.03, 0.07), (0, -0.26, 1.08), LED_G, bevel=0.0)
    p.box((0.07, 0.03, 0.22), (0, -0.26, 1.08), LED_G, bevel=0.0)
    p.box((0.24, 0.03, 0.05), (0, -0.27, 1.67), CYAN, bevel=0.0)
    rig.add("eyes", p, parent="body", pivot=(0, -0.26, 1.2), glow=True)
    for s, nm in ((1, "arm_l"), (-1, "arm_r")):
        p = Part()
        capsule(p, (0.34 * s, 0, 1.3), (0.4 * s, -0.25, 1.0), 0.05, 0.05, STL_D, sides=5)
        if s > 0:                                                                                    # Schraubenschlüssel
            p.box((0.06, 0.06, 0.4), (0.42, -0.3, 0.8), STL_L, bevel=0.0)
            p.box((0.16, 0.06, 0.08), (0.42, -0.3, 0.6), STL_L, bevel=0.0)
        rig.add(nm, p, parent="body", pivot=(0.34 * s, 0, 1.3))
    p = Part()                                                                                       # Schweißbrenner in der rechten Hand
    capsule(p, (-0.4, -0.28, 0.98), (-0.42, -0.5, 0.82), 0.04, 0.03, RUB, sides=4)
    rig.add("tool", p, parent="arm_r", pivot=(-0.4, -0.28, 0.98))
    p = Part()
    p.cone(0.05, 0.16, (-0.43, -0.58, 0.76), CYAN_L, r=rot(-60, 0, 0), sides=5)
    rig.add("glow", p, parent="tool", pivot=(-0.43, -0.56, 0.78), glow=True)
    for s, nm in ((1, "leg_l"), (-1, "leg_r")):                                                     # Beine mit Rollen
        p = Part()
        capsule(p, (0.15 * s, 0, 0.7), (0.17 * s, 0, 0.18), 0.06, 0.05, STL_D, sides=5)
        p.cyl(0.12, 0.08, (0.17 * s, -0.02, 0.12), RUB, r=rot(0, 90, 0), sides=8)
        rig.add(nm, p, parent="hips", pivot=(0.15 * s, 0, 0.7))
    biped(rig, 0.7, 2.0, 2.0, "healer", walk_n=24, leg_swing=20, arm_swing=10,
          rest_extra={"arm_l": dict(rot=(-25, 0, -15)), "arm_r": dict(rot=(-35, 0, 15))})
    with rig.clip("repair", 30, hit=15) as c:                      # schweißt: Brenner nach vorn, Funken, Kreuz leuchtet
        rest = rest_pose(rig, {"arm_l": dict(rot=(-25, 0, -15)), "arm_r": dict(rot=(-35, 0, 15))})
        K(c, rig, 0, **rest)
        K(c, rig, 8, arm_r=R(-80, 0, 10), body=R(14, 0, 0), head=R(16, 0, 0), glow=dict(scale=1.5))
        K(c, rig, 12, arm_r=R(-90, 0, 4), glow=dict(scale=2.4), eyes=dict(scale=1.3))
        K(c, rig, 15, arm_r=R(-80, 0, 16), glow=dict(scale=1.6), eyes=dict(scale=1.6))
        K(c, rig, 20, arm_r=R(-90, 0, 4), glow=dict(scale=2.4))
        K(c, rig, 30, **rest)
    rig.finish(icon_yaw=-24, icon_pitch=12)


# ================================================================= Schild-Bot (Schildträger)
def maschinen_schildbot():
    rig = Rig("maschinen_schildbot", role="shield")
    rig.node("hips", pivot=(0, 0, 0.85))
    p = Part()                                                                                       # gedrungener Panzerleib
    lathe(p, [(0.32, 0.8, STL_D), (0.46, 1.0, STL), (0.48, 1.45, STL), (0.38, 1.7, STL_D)], sides=8)
    p.box((0.5, 0.1, 0.3), (0, -0.42, 1.25), YEL, bevel=0.0)
    rig.add("body", p, parent="hips", pivot=(0, 0, 0.85))
    p = Part()                                                                                       # Helmkopf mit Visier
    lathe(p, [(0.22, 1.7, STL_D), (0.26, 1.85, STL), (0.22, 2.05, STL), (0.0, 2.12, STL)], sides=8)
    p.box((0.34, 0.06, 0.1), (0, -0.25, 1.92), INK, bevel=0.0)
    p.cyl(0.04, 0.25, (0, 0.0, 2.2), STL_D, sides=4)
    rig.add("head", p, parent="body", pivot=(0, 0, 1.7))
    p = Part()
    p.box((0.28, 0.04, 0.05), (0, -0.28, 1.92), LED_R, bevel=0.0)
    p.ball(0.05, (0, 0, 2.35), LED_R, subdiv=1)
    rig.add("glow", p, parent="head", pivot=(0, -0.28, 1.92), glow=True)
    p = Part()
    capsule(p, (0.42, 0, 1.55), (0.45, -0.32, 1.2), 0.1, 0.09, STL, sides=5)
    rig.add("arm_l", p, parent="body", pivot=(0.42, 0, 1.55))
    p = Part()                                                                                       # Schild: Absperrschranke mit Warnstreifen
    p.box((1.25, 0.12, 1.25), (0.12, -0.62, 1.15), WHT, bevel=0.0)
    for k in range(4):
        p.box((0.22, 0.13, 1.4), (-0.36 + k * 0.32, -0.63, 1.15), RED, r=rot(0, 35, 0))
    p.box((1.3, 0.14, 0.1), (0.12, -0.64, 1.8), STL_D, bevel=0.0)
    p.box((1.3, 0.14, 0.1), (0.12, -0.64, 0.5), STL_D, bevel=0.0)
    p.box((0.4, 0.13, 0.12), (0.12, -0.7, 1.15), YEL, bevel=0.0)
    rig.add("shield", p, parent="arm_l", pivot=(0.45, -0.45, 1.2))
    p = Part()                                                                                       # Schlagstock
    capsule(p, (-0.42, 0, 1.55), (-0.46, -0.3, 1.2), 0.1, 0.09, STL, sides=5)
    capsule(p, (-0.47, -0.35, 1.1), (-0.47, -0.6, 1.8), 0.05, 0.06, RUB, sides=5)
    rig.add("arm_r", p, parent="body", pivot=(-0.42, 0, 1.55))
    for s, nm in ((1, "leg_l"), (-1, "leg_r")):
        p = Part()
        capsule(p, (0.18 * s, 0, 0.82), (0.2 * s, 0, 0.12), 0.12, 0.1, STL_D, sides=6)
        p.box((0.3, 0.42, 0.14), (0.2 * s, -0.07, 0.07), RUB, bevel=0.0)
        rig.add(nm, p, parent="hips", pivot=(0.18 * s, 0, 0.85))
    biped(rig, 0.85, 2.3, 1.5, "shield", walk_n=30, leg_swing=22, arm_swing=0)
    rig.finish(icon_yaw=-24, icon_pitch=12)


# ================================================================= Störsender (Turmstörer)
def maschinen_stoersender():
    rig = Rig("maschinen_stoersender", role="jammer")
    rig.node("hips", pivot=(0, 0, 0.75))
    p = Part()                                                                                       # Rumpf: Funkkasten
    p.box((0.6, 0.45, 0.65), (0, 0, 1.1), STL, bevel=0.0)
    for k in range(4):
        p.box((0.06, 0.03, 0.4), (-0.2 + k * 0.13, -0.24, 1.1), INK, bevel=0.0)
    rig.add("body", p, parent="hips", pivot=(0, 0, 0.75))
    p = Part()                                                                                       # Kopf: Parabolschüssel
    p.cyl(0.08, 0.2, (0, 0, 1.52), STL_D, sides=6)
    lathe(p, [(0.05, 1.62, STL_L), (0.3, 1.66, STL_L), (0.42, 1.78, WHT)], sides=10, cap=False)
    p.cyl(0.02, 0.3, (0, 0, 1.8), STL_D, sides=4)
    rig.add("head", p, parent="body", pivot=(0, 0, 1.42))
    p = Part()
    p.ball(0.06, (0, 0, 1.97), CYAN, subdiv=1)
    p.box((0.3, 0.03, 0.06), (0, -0.24, 1.3), CYAN, bevel=0.0)
    rig.add("glow", p, parent="head", pivot=(0, 0, 1.9), glow=True)
    p = Part()                                                                                       # Antenne auf dem Rücken
    p.cyl(0.02, 0.9, (0.2, 0.2, 1.8), STL_D, sides=4)
    p.ball(0.04, (0.2, 0.2, 2.25), RED, subdiv=1)
    rig.add("prop", p, parent="body", pivot=(0.2, 0.2, 1.4))
    p = Part()
    capsule(p, (0.34, 0, 1.3), (0.42, -0.2, 0.95), 0.05, 0.045, STL_D, sides=5)
    rig.add("arm_l", p, parent="body", pivot=(0.34, 0, 1.3))
    p = Part()
    capsule(p, (-0.34, 0, 1.3), (-0.42, -0.2, 0.95), 0.05, 0.045, STL_D, sides=5)
    rig.add("arm_r", p, parent="body", pivot=(-0.34, 0, 1.3))
    p = Part()                                                                                       # Störscheibe in der Hand
    p.cyl(0.16, 0.05, (-0.44, -0.3, 0.86), "2A2C30", r=rot(90, 0, 0), sides=8)
    p.cyl(0.08, 0.06, (-0.44, -0.32, 0.86), CYAN, r=rot(90, 0, 0), sides=6)
    rig.add("tool", p, parent="arm_r", pivot=(-0.42, -0.22, 0.95))
    for s, nm in ((1, "leg_l"), (-1, "leg_r")):
        p = Part()
        capsule(p, (0.15 * s, 0, 0.75), (0.2 * s, 0, 0.1), 0.06, 0.05, STL_D, sides=5)
        p.box((0.22, 0.32, 0.1), (0.2 * s, -0.05, 0.05), RUB, bevel=0.0)
        rig.add(nm, p, parent="hips", pivot=(0.15 * s, 0, 0.75))

    def sp(name, c, rig, rest):
        if name == "idle":                                             # die Schüssel sucht nach Türmen
            K(c, rig, 12, head=R(0, 0, 35))
            K(c, rig, 26, head=R(0, 0, -35))
    biped(rig, 0.75, 2.2, 2.3, "jammer", walk_n=24, leg_swing=26, arm_swing=14, special=sp)
    rig.finish(icon_yaw=-24, icon_pitch=12)


# ================================================================= Abrisskran (Miniboss)
def maschinen_abrisskran():
    rig = Rig("maschinen_abrisskran", role="miniboss")
    p = Part()                                                                                       # Oberwagen
    p.box((2.0, 2.4, 1.2), (0, 0.2, 1.75), YEL, bevel=0.15, segs=1)
    p.box((1.8, 1.0, 0.8), (0, 1.2, 1.6), RUB, bevel=0.0)                                            # Gegengewicht
    p.box((2.02, 0.1, 0.25), (0, -1.0, 2.2), INK, bevel=0.0)
    for k in range(6):
        p.box((0.2, 0.11, 0.26), (-0.85 + k * 0.34, -1.01, 2.2), YEL_D if k % 2 else YEL, r=rot(0, 30, 0))
    p.cyl(0.12, 0.8, (0.7, 1.1, 2.4), STL_D, sides=6)
    rig.add("body", p, pivot=(0, 0, 1.6))
    p = Part()                                                                                       # Kabine (Kopf)
    p.box((0.9, 0.9, 0.9), (-0.45, -0.75, 2.75), YEL_D, bevel=0.1, segs=1)
    p.box((0.75, 0.06, 0.5), (-0.45, -1.21, 2.8), "2A3440", bevel=0.0)
    rig.add("head", p, parent="body", pivot=(-0.45, -0.5, 2.3))
    p = Part()                                                                                       # Ausleger mit Seil
    for s in (-1, 1):
        capsule(p, (0.45 + 0.18 * s, -0.2, 2.3), (0.45 + 0.1 * s, -2.2, 4.6), 0.07, 0.06, YEL, sides=4)
    for k in range(5):
        capsule(p, (0.27, -0.4 - k * 0.4, 2.55 + k * 0.45), (0.63, -0.6 - k * 0.4, 2.8 + k * 0.45), 0.03, 0.03, YEL_D, sides=4)
    capsule(p, (0.45, -2.25, 4.6), (0.45, -2.25, 3.0), 0.025, 0.025, RUB, sides=4)
    rig.add("boom", p, parent="body", pivot=(0.45, -0.2, 2.3))
    p = Part()                                                                                       # Abrissbirne (pendelt)
    p.ball(0.5, (0.45, -2.25, 2.55), RUB, subdiv=2)
    p.cyl(0.12, 0.15, (0.45, -2.25, 3.05), STL_D, sides=6)
    rig.add("tail", p, parent="boom", pivot=(0.45, -2.25, 3.0))
    p = Part()
    p.box((0.18, 0.05, 0.12), (-0.25, -1.24, 2.95), "FFF2B0", bevel=0.0)
    p.box((0.18, 0.05, 0.12), (-0.65, -1.24, 2.95), "FFF2B0", bevel=0.0)
    p.ball(0.1, (-0.45, -0.75, 3.27), ORA, subdiv=1)
    rig.add("glow", p, parent="head", pivot=(-0.45, -1.24, 2.95), glow=True)
    legs = []
    for (nm, x, y, ph, s) in (("leg_fl", 0.8, -0.7, 0.0, 1), ("leg_fr", -0.8, -0.7, 0.5, -1), ("leg_bl", 0.8, 1.0, 0.5, 1), ("leg_br", -0.8, 1.0, 0.0, -1)):
        p = Part()                                                                                   # Kettenfüße
        capsule(p, (x, y, 1.3), (x, y, 0.5), 0.22, 0.2, STL_D, sides=6)
        p.box((0.6, 0.95, 0.45), (x, y, 0.25), RUB, bevel=0.1, segs=1)
        rig.add(nm, p, parent="body", pivot=(x, y, 1.3))
        legs.append((nm, ph, s))

    def sp(name, c, rig, rest):
        if name == "skill":                                            # Ausleger hoch, die Birne schwingt über und schmettert nieder
            K(c, rig, 10, boom=R(-25, 0, 0), tail=R(-70, 0, 0), body=R(-10, 0, 0), glow=dict(scale=1.6))
            K(c, rig, 20, boom=R(-35, 0, 0), tail=R(-140, 0, 0))
            K(c, rig, 27, boom=R(20, 0, 0), tail=R(30, 0, 0), body=R(8, 0, 0), _i="LINEAR")
        if name == "attack":
            K(c, rig, 7, tail=R(-60, 0, 0))
            K(c, rig, 11, tail=R(40, 0, 0), boom=R(10, 0, 0), _i="LINEAR")
        if name == "idle":
            K(c, rig, 12, tail=R(10, 0, 8))
            K(c, rig, 24, tail=R(-10, 0, -8))
    quad(rig, legs, 1.3, 4.6, 1.3, "miniboss", walk_n=30, leg_swing=16, special=sp, hop=0.02)
    rig.finish(icon_yaw=-30, icon_pitch=14)


# ================================================================= Boss: Bürgermeister Bolzen
def boss_maschinen():
    rig = Rig("boss_maschinen", role="boss")
    rig.node("hips", pivot=(0, 0, 1.6))
    p = Part()                                                                                       # Rumpf: Straßenbahnwagen, aufrecht
    lathe(p, [(1.0, 1.4, RUB), (1.45, 1.7, RED_D), (1.55, 2.6, RED), (1.5, 3.6, WHT), (1.2, 4.1, RED), (0.85, 4.25, RED_D)], sides=10, sy=0.8)
    for k in range(4):                                                                               # Fensterband
        a = math.radians(-120 + k * 20)
        p.box((0.42, 0.1, 0.6), (1.5 * math.sin(a) * 0.95, -1.2 * math.cos(a) * 0.95, 3.2), "2A3440", r=rot(0, 0, -math.degrees(a)), bevel=0.0)
    for k in range(8):                                                                               # Nieten
        a = k * math.tau / 8
        p.ball(0.06, (1.52 * math.cos(a), 1.22 * math.sin(a), 2.0), STL_L, subdiv=1)
    p.box((0.9, 0.12, 0.35), (0, -1.25, 3.9), YEL, bevel=0.0)                                        # Liniennummer
    p.box((0.2, 0.13, 0.25), (-0.15, -1.3, 3.9), INK, bevel=0.0)
    p.box((0.2, 0.13, 0.25), (0.15, -1.3, 3.9), INK, bevel=0.0)
    rig.add("torso", p, parent="hips", pivot=(0, 0, 1.6))
    p = Part()                                                                                       # Sternsplitter-Akku in der Brust (Schwachstelle) und Amtskette
    p.box((0.7, 0.2, 0.7), (0, -1.25, 2.55), CYAN, bevel=0.0)
    p.box((0.4, 0.22, 0.4), (0, -1.28, 2.55), CYAN_L, bevel=0.0)
    rig.add("core", p, parent="torso", pivot=(0, -1.25, 2.55), glow=True)
    p = Part()
    p.torus(0.9, 0.06, (0, -0.45, 3.95), GOLD, r=rot(55, 0, 0), seg=14, tseg=4)
    p.cyl(0.25, 0.08, (0, -1.15, 3.35), GOLD, r=rot(75, 0, 0), sides=12)
    rig.add("chain", p, parent="torso", pivot=(0, -0.5, 3.9))
    p = Part()                                                                                       # Kopf: Uhrengesicht, Bürstenbart, Blech-Zylinder
    p.ball(0.75, (0, -0.25, 4.75), STL, scale=(1.0, 0.85, 0.9), subdiv=2)
    p.cyl(0.55, 0.1, (0, -0.85, 4.8), WHT, r=rot(90, 0, 0), sides=14)
    p.box((0.05, 0.03, 0.35), (0, -0.92, 4.9), INK, bevel=0.0)                                         # Uhrzeiger
    p.box((0.28, 0.03, 0.05), (0.12, -0.92, 4.8), INK, bevel=0.0)
    for k in range(5):                                                                               # Bürstenbart
        p.box((0.12, 0.12, 0.3), (-0.3 + k * 0.15, -0.88, 4.35), "6A5038", r=rot(0, (k - 2) * 8, 0), bevel=0.0)
    lathe(p, [(0.62, 5.35, RUB), (0.9, 5.37, RUB), (0.9, 5.45, "3A3E48"), (0.55, 5.45, "3A3E48"), (0.58, 6.35, "4A4E58"),
              (0.6, 6.45, "3A3E48"), (0.0, 6.47, "3A3E48")], sides=12)
    p.cyl(0.58, 0.15, (0, 0, 5.62), RED, sides=12)
    rig.add("head", p, parent="torso", pivot=(0, -0.2, 4.2))
    p = Part()                                                                                       # Monokel und Augen
    p.torus(0.17, 0.035, (0.32, -0.95, 4.98), GOLD, r=rot(90, 0, 0), seg=10, tseg=3)
    p.ball(0.12, (0.32, -0.9, 4.98), CYAN, scale=(1, 0.5, 1), subdiv=1)
    p.ball(0.1, (-0.32, -0.9, 4.98), CYAN, scale=(1, 0.5, 1), subdiv=1)
    rig.add("eyes", p, parent="head", pivot=(0, -0.9, 4.98), glow=True)
    for s, nm in ((1, "arm_l"), (-1, "arm_r")):                                                     # Arme: Kranarme mit Schilderfäusten
        p = Part()
        p.ball(0.5, (1.75 * s, 0.0, 3.7), YEL, subdiv=2)
        capsule(p, (1.8 * s, 0.0, 3.5), (2.05 * s, -0.3, 2.5), 0.35, 0.3, YEL_D, sides=8)
        rig.add(nm, p, parent="torso", pivot=(1.75 * s, 0.0, 3.7))
        p = Part()
        capsule(p, (2.05 * s, -0.3, 2.5), (2.1 * s, -0.55, 1.6), 0.3, 0.28, STL_D, sides=8)
        p.box((0.9, 0.9, 0.8), (2.1 * s, -0.65, 1.15), STL, bevel=0.15, segs=1)
        p.cyl(0.5, 0.08, (2.1 * s, -1.12, 1.25), (RED if s > 0 else SIGN_BLUE), r=rot(90, 0, 0), sides=10)   # Verkehrsschilder als Knöchelschutz
        p.box((0.5, 0.1, 0.12), (2.1 * s, -1.17, 1.25), WHT, bevel=0.0)
        rig.add(nm.replace("arm", "fore"), p, parent=nm, pivot=(2.05 * s, -0.3, 2.5))
    for s, nm in ((1, "leg_l"), (-1, "leg_r")):                                                     # Beine: Litfaßsäulen-Stümpfe
        p = Part()
        capsule(p, (0.75 * s, 0, 1.55), (0.8 * s, 0, 0.5), 0.48, 0.44, "4A6A4A", sides=8)
        p.box((1.0, 1.3, 0.45), (0.8 * s, -0.15, 0.22), RUB, bevel=0.12, segs=1)
        rig.add(nm, p, parent="hips", pivot=(0.75 * s, 0, 1.6))
    rest = dict(root=dict(loc=(0, 0, 0), rot=(0, 0, 0)), hips=dict(loc=(0, 0, 0), rot=(0, 0, 0)), torso=R(), head=R(), arm_l=R(), arm_r=R(),
                fore_l=R(), fore_r=R(), leg_l=R(), leg_r=R(), core=dict(scale=1.0), eyes=dict(scale=1.0), chain=R())
    with rig.clip("idle", 48, loop=True) as c:                     # steht stramm, der Akku pulsiert, die Kette wippt
        c.key(0, **rest)
        c.key(12, torso=R(0, 3, 0), core=dict(scale=1.25), head=R(0, 0, 8), chain=R(6, 0, 0))
        c.key(24, torso=R(-3, 0, 0), core=dict(scale=1.0), head=R(4, 0, 0))
        c.key(36, torso=R(0, -3, 0), core=dict(scale=1.25), head=R(0, 0, -8), chain=R(-4, 0, 0))
    with rig.clip("walk", 48, loop=True, stride=1.2 * 48 / 30.0) as c:
        c.wave("leg_l", rot=(26, 0, 0))
        c.wave("leg_r", rot=(26, 0, 0), phase=0.5)
        c.wave("arm_l", rot=(-18, 0, 0), phase=0.5)
        c.wave("arm_r", rot=(-18, 0, 0))
        c.wave("hips", rot=(0, 6, 0), phase=0.25)
        c.wave("hips", loc=(0, 0, 0.12), n=2, phase=0.25)
        c.wave("chain", rot=(8, 0, 0), n=2)
    with rig.clip("attack", 36, hit=20) as c:                      # Schilderfaust
        c.key(0, **rest)
        c.key(12, torso=R(-12, 0, -16), arm_r=R(-160, 0, 10), fore_r=R(-30, 0, 0))
        c.key(20, torso=R(18, 0, 10), arm_r=R(-50, 0, 0), fore_r=R(0, 0, 0), hips=dict(loc=(0, -0.2, -0.15)), _i="LINEAR")
        c.key(36, **rest)
    with rig.clip("hit", 9) as c:
        c.key(0, **rest)
        c.key(3, torso=R(-8, 0, 6), head=R(-16, 0, 8), core=dict(scale=1.5), eyes=dict(scale=1.4))
        c.key(9, **rest)
    with rig.clip("death", 60) as c:                               # der Zylinder fällt, der Akku flackert, er setzt sich und kippt nach hinten
        c.key(0, **rest)
        c.key(12, torso=R(-12, 0, 0), head=R(-24, 0, 10), core=dict(scale=1.8), eyes=dict(scale=1.6))
        c.key(26, hips=dict(loc=(0, 0, -0.9)), leg_l=R(-80, 0, 0), leg_r=R(-80, 0, 0), torso=R(-14, 0, 0), arm_l=R(-30, 0, 20), arm_r=R(-30, 0, -20), core=dict(scale=0.9), _i="LINEAR")
        c.key(44, root=dict(rot=(-78, 0, 0), loc=(0, 2.2, 0.0)), hips=dict(loc=(0, 0, -0.9)), torso=R(-10, 0, 0), arm_l=R(-160, 0, 20), arm_r=R(-160, 0, -20), _i="LINEAR")
        c.key(60, root=dict(rot=(-80, 0, 0), loc=(0, 2.2, 0.0)), hips=dict(loc=(0, 0, -0.9)), core=dict(scale=0.1), eyes=dict(scale=0.05))
    with rig.clip("special", 45, hit=24) as c:                     # Stromstoß: reißt die Arme hoch, der Akku gleißt
        c.key(0, **rest)
        c.key(12, arm_l=R(-170, 0, -25), arm_r=R(-170, 0, 25), torso=R(-16, 0, 0), head=R(-20, 0, 0), core=dict(scale=1.6), eyes=dict(scale=1.4))
        c.key(24, torso=R(-22, 0, 0), core=dict(scale=2.3), hips=dict(loc=(0, 0, 0.2)), _i="LINEAR")
        c.key(32, torso=R(-10, 0, 0), core=dict(scale=1.5))
        c.key(45, **rest)
    with rig.clip("summon", 39, hit=22) as c:                      # zieht den Zylinder, läutet: Maschinen kommen
        c.key(0, **rest)
        c.key(14, arm_l=R(-150, 0, -30), fore_l=R(-40, 0, 0), head=R(-10, 0, 0), chain=R(15, 0, 0))
        c.key(22, arm_l=R(-170, 0, -20), head=R(-14, 0, 8), eyes=dict(scale=1.6), core=dict(scale=1.4))
        c.key(28, arm_l=R(-150, 0, -30), head=R(-14, 0, -8), chain=R(-10, 0, 0))
        c.key(39, **rest)
    with rig.clip("slam", 39, hit=24) as c:                        # beide Fäuste auf den Boden
        c.key(0, **rest)
        c.key(12, arm_l=R(-160, 0, -10), arm_r=R(-160, 0, 10), torso=R(-14, 0, 0), core=dict(scale=1.4))
        c.key(24, hips=dict(loc=(0, 0, -0.6)), leg_l=R(-40, 0, 0), leg_r=R(20, 0, 0), torso=R(34, 0, 0), arm_l=R(-40, 0, 0), arm_r=R(-40, 0, 0), core=dict(scale=2.0), _i="LINEAR")
        c.key(30, core=dict(scale=1.5))
        c.key(39, **rest)
    rig.finish(icon_yaw=-26, icon_pitch=10)


SIGN_BLUE = "2A6AD0"

TABLE = {"maschinen_maeher": maschinen_maeher, "maschinen_funkenspinne": maschinen_funkenspinne, "maschinen_baggergolem": maschinen_baggergolem,
         "maschinen_ampelwaechter": maschinen_ampelwaechter, "maschinen_drohne": maschinen_drohne, "maschinen_muellpresse": maschinen_muellpresse,
         "maschinen_reparaturbot": maschinen_reparaturbot, "maschinen_schildbot": maschinen_schildbot, "maschinen_stoersender": maschinen_stoersender,
         "maschinen_abrisskran": maschinen_abrisskran, "boss_maschinen": boss_maschinen}

if __name__ == "__main__":
    run(TABLE, [a for a in sys.argv if not a.startswith("--")])
