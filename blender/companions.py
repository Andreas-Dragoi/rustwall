"""Begleiter (Paket B): zwölf kleine Helfer, die dem Helden folgen und den Rucksack tragen.
Vorderseite -Y, Ursprung am Boden in der Mitte. Maßstab = Spielgröße (kein Vergrößern in Godot).
Bewegliche Teile sind eigene Objekte mit dem Ursprung im Gelenk; src/companion.gd bewegt sie (wie wildlife.gd):
  body                Rumpf (Ursprung in Hüfthöhe; wippt, neigt sich, fällt beim Umfallen zur Seite)
  head                Kopf (Kind von body, Ursprung am Hals)
  tail                Schwanz (Kind von body)
  leg_fl/fr/bl/br     Beine (Kind der Wurzel, Ursprung an der Hüfte); Käfer zusätzlich leg_ml/leg_mr
  leg_l/leg_r, arm_l/arm_r   Golem (zweibeinig)
  wing_l/wing_r       Flügel (Kind von body, Ursprung an der Schulter, Flügel entlang ∓X)
  spin_rotor_1..4     Rotoren der Drohne (drehen um die eigene Z-Achse)
  sled                Schlitten des Huskys (Kind der Wurzel)
  *_glow              leuchtet (Augen, Laterne, Kern)
  Leerobjekt cargo    Boden der Ladefläche (Kind von body bzw. sled): hier stapelt Godot die Ladung (blender/cargo.py)
Dazu je Begleiter das Symbol icons/comp_<key>.png.
Aufruf: python3 blender/companions.py [comp_esel ...]"""
import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from kit import *
from rw_util import *

WHITE, BLACK, DARK = "FFFFFF", "181A22", "2E3340"
PINK, NOSE = "E88AA0", "2A2228"
WOOD, WOOD_D, WOOD_L = "B56A32", "7A4522", "D9A05E"
LEATHER, LEATHER_D, ROPE = "9A5A32", "6E3E22", "D9C27E"
STEEL, STEEL_L, STEEL_D = "8A94A8", "B8C2D4", "5E6678"
BRASS, GOLD = "E0A82E", "FFC824"


def eye(p, x, y, z, r, iris=BLACK, white=WHITE, look=(0, -1, 0)):
    """Kulleraugen: weiß, Pupille nach vorn, Lichtpunkt."""
    p.ball(r, (x, y, z), white, subdiv=2)
    p.ball(r * 0.62, (x + look[0] * r * 0.5, y + look[1] * r * 0.5, z + look[2] * r * 0.5), iris, subdiv=2)
    p.ball(r * 0.2, (x + r * 0.18, y - r * 0.92, z + r * 0.28), WHITE, subdiv=1)


def leg(color, length, r, foot=None, foot_r=None, r2=None):
    """Bein, das vom Gelenk (Ursprung) nach unten hängt."""
    p = Part()
    p.cyl(r, length, (0, 0, -length * 0.5), color, r2=r2, sides=8)
    if foot:
        fr = foot_r or r * 1.25
        p.ball(fr, (0, -fr * 0.25, -length + fr * 0.55), foot, scale=(1.0, 1.25, 0.7), subdiv=1)
    return p


def build(name, nodes, yaw=-35.0, pitch=24.0):
    """nodes = [(name, Part | None, parent | None, loc)] – None als Part = Leerobjekt."""
    root = empty(name)
    obs = {None: root}
    for nm, part, par, loc in nodes:
        if part is None:
            obs[nm] = empty(nm, obs[par], loc)
        else:
            obs[nm] = part.build(nm, obs[par], loc)
    finish(name, yaw=yaw, pitch=pitch, size=256)


# ---------------------------------------------------------------------------------------------- 1 Laufkiste
def kistenbein():
    c, cd, cl = "C8823C", "8A5228", "E8B470"
    b = Part()
    b.box((0.62, 0.66, 0.42), (0, 0, 0.21), c, bevel=0.04, segs=2)
    for z in (0.05, 0.37):
        b.box((0.64, 0.68, 0.06), (0, 0, z), cd, bevel=0.015, segs=1)
    for x in (-0.3, 0.3):
        for y in (-0.32, 0.32):
            b.box((0.07, 0.07, 0.44), (x, y, 0.21), cd, bevel=0.015, segs=1)
    b.box((0.52, 0.56, 0.06), (0, 0, 0.39), "7A4E2A")                 # offenes Inneres
    b.box((0.08, 0.6, 0.06), (0, 0, 0.215), cl, r=rot(0, 0, 0), bevel=0.01, segs=1)
    # Gesicht vorn
    for s in (-1, 1):
        eye(b, s * 0.13, -0.345, 0.25, 0.075)
        b.ball(0.035, (s * 0.21, -0.335, 0.16), "F2A0A0", scale=(1.2, 0.4, 0.8), subdiv=1)
    b.box((0.12, 0.02, 0.025), (0, -0.338, 0.15), DARK, bevel=0.008, segs=1)
    # Seilgriffe an den Seiten
    for s in (-1, 1):
        b.torus(0.07, 0.016, (s * 0.33, 0, 0.27), ROPE, r=rot(0, 90, 0) @ rot(0, 0, 0), seg=12, tseg=4)
    nodes = [("body", b, None, (0, 0, 0.3)), ("cargo", None, "body", (0, 0, 0.4))]
    for nm, x, y in (("leg_fl", -0.2, -0.22), ("leg_fr", 0.2, -0.22), ("leg_bl", -0.2, 0.22), ("leg_br", 0.2, 0.22)):
        nodes.append((nm, leg("5E3A22", 0.26, 0.03, "3C5CA4", 0.065), None, (x, y, 0.32)))
    build("comp_kistenbein", nodes)


# ---------------------------------------------------------------------------------------------- 2 Blechesel
def esel():
    m, ml, md, acc = "6F8FC0", "A9C0E0", "3C5CA4", "E08A2E"
    b = Part()
    b.box((0.36, 0.78, 0.34), (0, 0.02, 0.12), m, bevel=0.1, segs=2)
    b.box((0.38, 0.5, 0.1), (0, 0.02, 0.27), acc, bevel=0.03, segs=1)                   # Sattel
    for s in (-1, 1):
        b.box((0.1, 0.36, 0.26), (s * 0.24, 0.02, 0.1), LEATHER, bevel=0.04, segs=1)     # Satteltaschen
        b.box((0.11, 0.3, 0.08), (s * 0.245, 0.02, 0.19), LEATHER_D, bevel=0.02, segs=1)
        b.box((0.02, 0.05, 0.04), (s * 0.3, 0.02, 0.15), BRASS)
        for y in (-0.3, 0.32):
            b.cyl(0.02, 0.02, (s * 0.18, y, 0.2), STEEL_L, r=rot(0, 90, 0), sides=6)
    b.box((0.2, 0.2, 0.06), (0, 0.3, 0.27), md, bevel=0.02, segs=1)
    b.cyl(0.05, 0.06, (0, -0.32, 0.31), STEEL_D, sides=8)                              # Halsgelenk
    h = Part()
    h.cyl(0.07, 0.24, (0, -0.02, 0.06), STEEL, r=rot(-30, 0, 0), sides=8)
    h.box((0.22, 0.3, 0.22), (0, -0.1, 0.2), m, bevel=0.07, segs=2)
    h.box((0.18, 0.16, 0.14), (0, -0.25, 0.14), ml, bevel=0.05, segs=2)
    for s in (-1, 1):
        h.ball(0.02, (s * 0.05, -0.33, 0.16), DARK, subdiv=1)
        h.box((0.05, 0.04, 0.26), (s * 0.07, -0.02, 0.4), md, r=rot(-15, s * 12, 0), bevel=0.02, segs=1)
        h.box((0.03, 0.02, 0.18), (s * 0.07, -0.04, 0.4), acc, r=rot(-15, s * 12, 0), bevel=0.008, segs=1)
    h.box((0.06, 0.02, 0.02), (0, -0.335, 0.1), DARK)
    e = Part()
    for s in (-1, 1):
        e.box((0.06, 0.02, 0.05), (s * 0.06, -0.255, 0.24), "7FF0FF", bevel=0.01, segs=1)
    t = Part()
    t.cyl(0.018, 0.26, (0, 0.1, -0.08), DARK, r=rot(50, 0, 0), sides=6)
    t.ball(0.04, (0, 0.2, -0.17), "FD5050", subdiv=1)
    nodes = [("body", b, None, (0, 0, 0.6)), ("cargo", None, "body", (0, 0.03, 0.3)),
             ("head", h, "body", (0, -0.36, 0.24)), ("eyes_glow", e, "head", (0, 0, 0)), ("tail", t, "body", (0, 0.4, 0.18))]
    for nm, x, y in (("leg_fl", -0.12, -0.26), ("leg_fr", 0.12, -0.26), ("leg_bl", -0.12, 0.28), ("leg_br", 0.12, 0.28)):
        lp = Part()
        lp.ball(0.06, (0, 0, 0), STEEL_D, subdiv=1)
        lp.cyl(0.045, 0.28, (0, 0, -0.14), STEEL, sides=8)
        lp.ball(0.045, (0, 0, -0.28), STEEL_D, subdiv=1)
        lp.cyl(0.03, 0.26, (0, 0, -0.41), STEEL_L, sides=8)
        lp.box((0.1, 0.12, 0.06), (0, -0.01, -0.54), DARK, bevel=0.02, segs=1)
        nodes.append((nm, lp, None, (x, y, 0.57)))
    build("comp_esel", nodes)


# ---------------------------------------------------------------------------------------------- 3 Lastschnecke
def schnecke():
    sk, skd, sh, shd, shl = "B9D86A", "8FB04A", "E08A2E", "A85A22", "F5B868"
    b = Part()
    b.ball(1.0, (0, 0.06, 0.12), sk, scale=(0.26, 0.72, 0.14), subdiv=2)
    b.ball(1.0, (0, 0.6, 0.08), skd, scale=(0.14, 0.2, 0.08), subdiv=1)
    # Haus: stehende Spirale
    hm = T(0, 0.14, 0.42) @ rot(0, 90, 0)
    b.cyl(0.32, 0.36, (0, 0, 0), sh, r=hm, sides=18, bevel=0.1, segs=2)
    b.cyl(0.24, 0.38, (0, 0, 0), shd, r=hm, sides=16, bevel=0.06, segs=1)
    b.cyl(0.17, 0.4, (0, 0, 0), shl, r=hm, sides=14, bevel=0.05, segs=1)
    b.cyl(0.09, 0.42, (0, 0, 0), shd, r=hm, sides=12, bevel=0.03, segs=1)
    # Korb auf dem Haus
    b.cyl(0.2, 0.1, (0, 0.14, 0.76), WOOD_L, r2=0.23, sides=12)
    b.torus(0.225, 0.02, (0, 0.14, 0.81), WOOD, seg=14, tseg=4)
    for s in (-1, 1):
        b.cyl(0.012, 0.42, (s * 0.19, 0.14, 0.6), ROPE, sides=4)
    h = Part()
    h.ball(0.15, (0, -0.06, 0.06), sk, scale=(1.0, 1.0, 0.9), subdiv=2)
    h.ball(0.03, (0, -0.2, 0.03), skd, subdiv=1)
    h.box((0.08, 0.02, 0.02), (0, -0.205, 0.0), DARK, bevel=0.006, segs=1)
    for s in (-1, 1):
        h.cyl(0.022, 0.22, (s * 0.07, -0.06, 0.22), sk, r=rot(0, s * 18, 0), sides=6)
        eye(h, s * 0.105, -0.07, 0.33, 0.05)
        h.ball(0.025, (s * 0.12, -0.18, 0.02), "F2A0A0", scale=(1.2, 0.4, 0.8), subdiv=1)
    nodes = [("body", b, None, (0, 0, 0.0)), ("cargo", None, "body", (0, 0.14, 0.78)), ("head", h, "body", (0, -0.62, 0.14))]
    build("comp_schnecke", nodes)


# ---------------------------------------------------------------------------------------------- 4 Kistenkäfer
def kaefer():
    sh, shl, dk = "2F9A5A", "5CC27E", "253040"
    b = Part()
    b.ball(1.0, (0, 0.04, 0.0), dk, scale=(0.3, 0.44, 0.16), subdiv=2)
    b.ball(1.0, (0, 0.06, 0.06), sh, scale=(0.34, 0.48, 0.22), subdiv=2)
    b.box((0.02, 0.86, 0.06), (0, 0.06, 0.26), "1E6A3E", bevel=0.008, segs=1)
    for x, y in ((-0.17, -0.1), (0.17, 0.05), (-0.13, 0.25), (0.15, 0.3), (-0.2, 0.1)):
        b.ball(0.05, (x, y, 0.23), shl, scale=(1, 1, 0.4), subdiv=1)
    # Rahmen aus Holzlatten obenauf
    for y in (-0.16, 0.24):
        b.box((0.42, 0.04, 0.04), (0, y, 0.27), WOOD, bevel=0.01, segs=1)
    for x in (-0.2, 0.2):
        b.box((0.04, 0.44, 0.04), (x, 0.04, 0.27), WOOD_D, bevel=0.01, segs=1)
    h = Part()
    h.ball(0.15, (0, -0.08, 0.02), dk, scale=(1.1, 1.0, 0.85), subdiv=2)
    for s in (-1, 1):
        eye(h, s * 0.08, -0.17, 0.08, 0.05)
        h.cone(0.035, 0.16, (s * 0.06, -0.26, -0.03), "D9B860", r=rot(90, 0, 0) @ rot(0, s * 20, 0), sides=6)
        limb(h, (s * 0.05, -0.12, 0.12), (s * 0.13, -0.25, 0.3), 0.012, color=DARK, sides=4)
        h.ball(0.03, (s * 0.13, -0.25, 0.3), "FFD23E", subdiv=1)
    nodes = [("body", b, None, (0, 0, 0.32)), ("cargo", None, "body", (0, 0.04, 0.3)), ("head", h, "body", (0, -0.42, 0.0))]
    for nm, x, y in (("leg_fl", -0.22, -0.2), ("leg_fr", 0.22, -0.2), ("leg_ml", -0.24, 0.04), ("leg_mr", 0.24, 0.04), ("leg_bl", -0.22, 0.28), ("leg_br", 0.22, 0.28)):
        s = -1 if x < 0 else 1
        lp = Part()
        limb(lp, (0, 0, 0), (s * 0.14, 0, 0.04), 0.025, color=dk, sides=6)
        limb(lp, (s * 0.14, 0, 0.04), (s * 0.2, 0, -0.3), 0.022, 0.016, color=dk, sides=6)
        lp.ball(0.03, (s * 0.14, 0, 0.04), dk, subdiv=1)
        nodes.append((nm, lp, None, (x, y, 0.3)))
    build("comp_kaefer", nodes)


# ---------------------------------------------------------------------------------------------- 5 Bergziege
def ziege():
    f, fl, fd, horn = "F2E8D5", "FFF8EC", "C8B898", "8A8070"
    b = Part()
    b.ball(1.0, (0, 0.02, 0.06), f, scale=(0.2, 0.36, 0.2), subdiv=2)
    b.ball(1.0, (0, 0.0, 0.02), fl, scale=(0.17, 0.28, 0.16), subdiv=1)
    b.box((0.44, 0.34, 0.05), (0, 0.02, 0.22), "D54144", bevel=0.02, segs=1)          # Decke
    b.box((0.45, 0.3, 0.02), (0, 0.02, 0.25), GOLD, bevel=0.008, segs=1)
    for s in (-1, 1):
        b.box((0.09, 0.26, 0.22), (s * 0.23, 0.02, 0.06), LEATHER, bevel=0.04, segs=1)
        b.box((0.1, 0.2, 0.06), (s * 0.235, 0.02, 0.14), LEATHER_D, bevel=0.015, segs=1)
    h = Part()
    h.cyl(0.07, 0.2, (0, -0.02, 0.06), f, r=rot(-35, 0, 0), sides=8)
    h.box((0.17, 0.24, 0.17), (0, -0.1, 0.18), f, bevel=0.07, segs=2)
    h.box((0.13, 0.12, 0.11), (0, -0.21, 0.13), fd, bevel=0.05, segs=1)
    h.cone(0.04, 0.12, (0, -0.2, 0.02), fd, r=rot(180, 0, 0), sides=6)               # Bart
    for s in (-1, 1):
        eye(h, s * 0.075, -0.17, 0.21, 0.035, iris="6A4A20")
        h.ball(1.0, (s * 0.12, -0.08, 0.22), fd, r=rot(0, s * -30, 0), scale=(0.08, 0.03, 0.03), subdiv=1)
        for i in range(4):
            h.cyl(0.03 - i * 0.005, 0.08, (s * (0.05 + i * 0.012), -0.02 + i * 0.05, 0.3 + 0.04 * (i < 2) - 0.02 * i), horn,
                  r=rot(-60 + i * 35, 0, 0), sides=6)
    h.ball(0.015, (0, -0.27, 0.15), NOSE, subdiv=1)
    t = Part()
    t.cone(0.04, 0.12, (0, 0.03, 0.05), fl, r=rot(-35, 0, 0), sides=6)
    nodes = [("body", b, None, (0, 0, 0.55)), ("cargo", None, "body", (0, 0.02, 0.25)),
             ("head", h, "body", (0, -0.3, 0.12)), ("tail", t, "body", (0, 0.34, 0.12))]
    for nm, x, y in (("leg_fl", -0.09, -0.2), ("leg_fr", 0.09, -0.2), ("leg_bl", -0.09, 0.22), ("leg_br", 0.09, 0.22)):
        nodes.append((nm, leg(f, 0.46, 0.035, "4A3A30", 0.04, r2=0.03), None, (x, y, 0.5)))
    build("comp_ziege", nodes)


# ---------------------------------------------------------------------------------------------- 6 Flugdrohne
def drohne():
    y1, dk = "FFD23E", "2E3340"
    b = Part()
    b.box((0.36, 0.36, 0.14), (0, 0, 0), y1, bevel=0.05, segs=2)
    b.box((0.3, 0.3, 0.08), (0, 0, -0.08), dk, bevel=0.03, segs=1)
    b.box((0.38, 0.06, 0.02), (0, 0.0, 0.072), dk)
    for a in (45, 135, 225, 315):
        b.box((0.42, 0.06, 0.04), (0, 0, 0.02), STEEL_D, r=rot(0, 0, a) @ T(0.2, 0, 0), bevel=0.01, segs=1)
    for x, y in ((-0.3, -0.3), (0.3, -0.3), (-0.3, 0.3), (0.3, 0.3)):
        b.torus(0.14, 0.018, (x, y, 0.06), STEEL, seg=16, tseg=4)
        b.cyl(0.03, 0.07, (x, y, 0.04), dk, sides=8)
    # Korb an Seilen darunter
    for x, y in ((-0.12, -0.12), (0.12, -0.12), (-0.12, 0.12), (0.12, 0.12)):
        b.cyl(0.008, 0.3, (x, y, -0.25), ROPE, sides=4)
    b.box((0.36, 0.36, 0.04), (0, 0, -0.42), WOOD_D, bevel=0.01, segs=1)
    for s in (-1, 1):
        b.box((0.36, 0.03, 0.12), (0, s * 0.17, -0.37), WOOD, bevel=0.01, segs=1)
        b.box((0.03, 0.36, 0.12), (s * 0.17, 0, -0.37), WOOD, bevel=0.01, segs=1)
    e = Part()
    e.cyl(0.05, 0.03, (0, -0.19, -0.02), "7FF0FF", r=rot(90, 0, 0), sides=12)
    e.ball(0.02, (0.12, -0.185, 0.03), "FF5050", subdiv=1)
    nodes = [("body", b, None, (0, 0, 1.5)), ("cargo", None, "body", (0, 0, -0.4)), ("eye_glow", e, "body", (0, 0, 0))]
    i = 1
    for x, y in ((-0.3, -0.3), (0.3, -0.3), (-0.3, 0.3), (0.3, 0.3)):
        r = Part()
        r.box((0.24, 0.04, 0.01), (0, 0, 0), "F4F6FA", r=rot(6, 0, 0))
        r.box((0.04, 0.24, 0.01), (0, 0, 0), "F4F6FA", r=rot(0, 6, 0))
        nodes.append(("spin_rotor_%d" % i, r, "body", (x, y, 0.085)))
        i += 1
    build("comp_drohne", nodes)


# ---------------------------------------------------------------------------------------------- 7 Biber
def biber():
    f, fl, fd = "8A5A30", "C8915A", "4A3226"
    b = Part()
    b.ball(1.0, (0, 0.02, 0.06), f, scale=(0.24, 0.34, 0.22), subdiv=2)
    b.ball(1.0, (0, -0.06, 0.0), fl, scale=(0.18, 0.24, 0.16), subdiv=1)
    # Weidenkorb auf dem Rücken
    b.cyl(0.17, 0.16, (0, 0.06, 0.28), WOOD_L, r2=0.2, sides=12)
    for z in (0.22, 0.28, 0.34):
        b.torus(0.18 + (z - 0.22) * 0.25, 0.012, (0, 0.06, z), WOOD, seg=14, tseg=3)
    for s in (-1, 1):
        b.box((0.03, 0.03, 0.26), (s * 0.15, -0.02, 0.17), LEATHER, r=rot(0, s * 25, 0), bevel=0.008, segs=1)
    h = Part()
    h.ball(0.16, (0, -0.06, 0.04), f, subdiv=2)
    h.ball(0.1, (0, -0.17, -0.01), fl, scale=(1.1, 0.9, 0.75), subdiv=1)
    h.ball(0.035, (0, -0.255, 0.03), NOSE, scale=(1.3, 1, 0.8), subdiv=1)
    h.box((0.07, 0.03, 0.07), (0, -0.25, -0.06), WHITE, bevel=0.01, segs=1)
    h.box((0.004, 0.032, 0.07), (0, -0.252, -0.06), "C8C8C8")
    for s in (-1, 1):
        eye(h, s * 0.08, -0.16, 0.09, 0.035)
        h.ball(0.04, (s * 0.12, -0.02, 0.15), fd, scale=(1, 0.6, 1), subdiv=1)
    t = Part()
    t.box((0.2, 0.34, 0.05), (0, 0.17, 0), fd, bevel=0.025, segs=1)
    for i in range(3):
        t.box((0.18, 0.01, 0.052), (0, 0.06 + i * 0.1, 0), "3A2820")
    nodes = [("body", b, None, (0, 0, 0.26)), ("cargo", None, "body", (0, 0.06, 0.24)),
             ("head", h, "body", (0, -0.3, 0.1)), ("tail", t, "body", (0, 0.3, -0.12))]
    for nm, x, y in (("leg_fl", -0.13, -0.14), ("leg_fr", 0.13, -0.14), ("leg_bl", -0.14, 0.16), ("leg_br", 0.14, 0.16)):
        nodes.append((nm, leg(fd, 0.14, 0.05, fd, 0.06), None, (x, y, 0.17)))
    build("comp_biber", nodes)


# ---------------------------------------------------------------------------------------------- 8 Waschbär
def waschbaer():
    f, fl, fd, mask = "8C8C9A", "E4E4EA", "4A4A56", "2A2A32"
    b = Part()
    b.ball(1.0, (0, 0.02, 0.06), f, scale=(0.2, 0.3, 0.2), subdiv=2)
    b.ball(1.0, (0, -0.06, 0.0), fl, scale=(0.14, 0.2, 0.14), subdiv=1)
    # Rucksack
    b.box((0.32, 0.3, 0.2), (0, 0.06, 0.24), "5E8A3A", bevel=0.07, segs=2)
    b.box((0.34, 0.16, 0.1), (0, -0.03, 0.31), "47702A", bevel=0.04, segs=1)
    b.box((0.05, 0.03, 0.05), (0, -0.12, 0.27), BRASS, bevel=0.01, segs=1)
    for s in (-1, 1):
        b.box((0.03, 0.03, 0.24), (s * 0.13, -0.1, 0.13), LEATHER, r=rot(-20, 0, 0), bevel=0.008, segs=1)
        b.box((0.06, 0.18, 0.12), (s * 0.17, 0.08, 0.2), "47702A", bevel=0.03, segs=1)
    h = Part()
    h.ball(0.15, (0, -0.04, 0.04), f, scale=(1.1, 1, 0.9), subdiv=2)
    h.ball(0.08, (0, -0.16, 0.0), fl, scale=(1, 1.2, 0.7), subdiv=1)
    h.box((0.3, 0.06, 0.06), (0, -0.155, 0.06), mask, bevel=0.025, segs=1)
    h.ball(0.03, (0, -0.255, 0.01), NOSE, subdiv=1)
    for s in (-1, 1):
        eye(h, s * 0.065, -0.175, 0.065, 0.032)
        h.cone(0.05, 0.1, (s * 0.1, -0.02, 0.16), f, r=rot(0, s * 20, 0), sides=4)
        h.cone(0.03, 0.07, (s * 0.1, -0.035, 0.155), fl, r=rot(0, s * 20, 0), sides=4)
        h.ball(0.04, (s * 0.07, -0.16, 0.13), fl, scale=(1.4, 0.5, 0.5), subdiv=1)
    t = Part()
    for i in range(6):
        c = fd if i % 2 == 0 else f
        t.ball(0.078 - i * 0.004, (0, 0.04 + i * 0.058, 0.02 + i * 0.03), c, scale=(1, 1.15, 1), subdiv=2)
    nodes = [("body", b, None, (0, 0, 0.34)), ("cargo", None, "body", (0, 0.06, 0.34)),
             ("head", h, "body", (0, -0.28, 0.12)), ("tail", t, "body", (0, 0.28, 0.0))]
    for nm, x, y in (("leg_fl", -0.1, -0.14), ("leg_fr", 0.1, -0.14), ("leg_bl", -0.1, 0.16), ("leg_br", 0.1, 0.16)):
        nodes.append((nm, leg(fd, 0.26, 0.035, mask, 0.045), None, (x, y, 0.28)))
    build("comp_waschbaer", nodes)


# ---------------------------------------------------------------------------------------------- 9 Mini-Golem
def golem():
    r, rl, rd, moss = "9A8F96", "B9B0B6", "6E6672", "6E9A3A"
    b = Part()
    b.box((0.72, 0.5, 0.6), (0, 0.02, 0.3), r, bevel=0.14, segs=2)
    b.box((0.3, 0.2, 0.22), (-0.18, -0.12, 0.48), rl, r=rot(0, 0, 10), bevel=0.06, segs=1)
    b.box((0.26, 0.2, 0.2), (0.22, 0.12, 0.12), rd, r=rot(0, 0, -15), bevel=0.06, segs=1)
    b.ball(1.0, (-0.24, 0.0, 0.6), moss, scale=(0.18, 0.2, 0.06), subdiv=1)
    b.ball(1.0, (0.2, 0.2, 0.58), moss, scale=(0.14, 0.12, 0.05), subdiv=1)
    # Tragegestell aus Holz auf dem Rücken
    for x in (-0.24, 0.24):
        b.box((0.05, 0.05, 0.36), (x, 0.24, 0.66), WOOD, bevel=0.012, segs=1)
    b.box((0.6, 0.36, 0.04), (0, 0.2, 0.62), WOOD_D, bevel=0.01, segs=1)
    b.box((0.56, 0.04, 0.04), (0, 0.38, 0.78), WOOD, bevel=0.01, segs=1)
    k = Part()
    k.ball(0.09, (0, -0.25, 0.32), "6FF0C8", scale=(1, 0.5, 1), subdiv=1)
    h = Part()
    h.box((0.28, 0.26, 0.22), (0, -0.04, 0.1), rl, bevel=0.07, segs=1)
    h.box((0.3, 0.06, 0.05), (0, -0.16, 0.16), rd, bevel=0.015, segs=1)
    e = Part()
    for s in (-1, 1):
        e.box((0.06, 0.02, 0.04), (s * 0.065, -0.175, 0.1), "6FF0C8", bevel=0.008, segs=1)
    nodes = [("body", b, None, (0, 0, 0.5)), ("cargo", None, "body", (0, 0.2, 0.64)), ("core_glow", k, "body", (0, 0, 0)),
             ("head", h, "body", (0, -0.18, 0.58)), ("eyes_glow", e, "head", (0, 0, 0))]
    for nm, s in (("arm_l", -1), ("arm_r", 1)):
        a = Part()
        a.box((0.16, 0.18, 0.3), (s * 0.04, 0, -0.14), r, bevel=0.06, segs=1)
        a.box((0.22, 0.22, 0.2), (s * 0.05, -0.02, -0.36), rl, bevel=0.07, segs=1)
        a.ball(1.0, (s * 0.06, 0.0, -0.02), moss, scale=(0.07, 0.08, 0.03), subdiv=1)
        nodes.append((nm, a, "body", (s * 0.44, 0.0, 0.46)))
    for nm, s in (("leg_l", -1), ("leg_r", 1)):
        lp = Part()
        lp.box((0.2, 0.22, 0.34), (0, 0, -0.2), rd, bevel=0.06, segs=1)
        lp.box((0.24, 0.3, 0.12), (0, -0.04, -0.46), r, bevel=0.05, segs=1)
        nodes.append((nm, lp, None, (s * 0.18, 0.0, 0.52)))
    build("comp_golem", nodes)


# ---------------------------------------------------------------------------------------------- 10 Schlittenhund
def husky():
    f, fl, fd, harness = "7A8494", "F4F6FA", "3A4250", "2F7AE0"
    b = Part()
    b.ball(1.0, (0, 0.02, 0.0), f, scale=(0.17, 0.34, 0.17), subdiv=2)
    b.ball(1.0, (0, -0.04, -0.05), fl, scale=(0.14, 0.26, 0.12), subdiv=1)
    b.box((0.38, 0.08, 0.36), (0, -0.14, 0.0), harness, bevel=0.03, segs=1)        # Geschirr
    b.box((0.06, 0.4, 0.05), (0, 0.04, 0.17), harness, bevel=0.015, segs=1)
    b.ball(0.03, (0, 0.24, 0.17), BRASS, subdiv=1)
    h = Part()
    h.ball(0.14, (0, -0.04, 0.06), f, subdiv=2)
    h.ball(0.1, (0, -0.1, 0.02), fl, scale=(0.95, 1, 0.85), subdiv=1)
    h.box((0.1, 0.14, 0.08), (0, -0.19, 0.0), fl, bevel=0.035, segs=1)
    h.ball(0.03, (0, -0.265, 0.03), NOSE, subdiv=1)
    for s in (-1, 1):
        eye(h, s * 0.06, -0.14, 0.1, 0.032, iris="2F7AE0")
        h.cone(0.06, 0.13, (s * 0.075, -0.0, 0.2), f, r=rot(0, s * 12, 0), sides=4)
        h.cone(0.035, 0.09, (s * 0.075, -0.02, 0.19), PINK, r=rot(0, s * 12, 0), sides=4)
    t = Part()
    t.torus(0.08, 0.04, (0, 0.06, 0.07), f, r=rot(0, 90, 0), seg=10, tseg=6)
    t.ball(0.045, (0, 0.0, 0.14), fl, subdiv=1)
    sl = Part()
    for s in (-1, 1):
        sl.box((0.04, 0.8, 0.04), (s * 0.2, 0.0, 0.03), WOOD_D, bevel=0.012, segs=1)
        sl.cyl(0.05, 0.04, (s * 0.2, -0.4, 0.07), WOOD_D, r=rot(0, 90, 0), sides=10)
        for y in (-0.25, 0.25):
            sl.box((0.03, 0.03, 0.14), (s * 0.2, y, 0.12), WOOD, bevel=0.008, segs=1)
        sl.box((0.03, 0.03, 0.32), (s * 0.2, 0.38, 0.28), WOOD, bevel=0.008, segs=1)
    sl.box((0.48, 0.66, 0.04), (0, 0.02, 0.2), WOOD, bevel=0.012, segs=1)
    for y in (-0.2, 0.0, 0.2):
        sl.box((0.5, 0.05, 0.045), (0, y, 0.205), WOOD_L, bevel=0.01, segs=1)
    sl.box((0.44, 0.03, 0.03), (0, 0.38, 0.44), WOOD, bevel=0.008, segs=1)
    sl.cyl(0.012, 0.42, (0, -0.55, 0.3), ROPE, r=rot(80, 0, 0), sides=4)
    nodes = [("body", b, None, (0, 0, 0.52)), ("head", h, "body", (0, -0.34, 0.14)), ("tail", t, "body", (0, 0.32, 0.1)),
             ("sled", sl, None, (0, 0.95, 0)), ("cargo", None, "sled", (0, 0.02, 0.23))]
    for nm, x, y in (("leg_fl", -0.08, -0.2), ("leg_fr", 0.08, -0.2), ("leg_bl", -0.08, 0.22), ("leg_br", 0.08, 0.22)):
        nodes.append((nm, leg(f, 0.42, 0.035, fl, 0.045), None, (x, y, 0.46)))
    build("comp_husky", nodes)


# ---------------------------------------------------------------------------------------------- 11 Eule
def eule():
    f, fl, fd = "A8743A", "F2D8A8", "6E4A26"
    b = Part()
    b.ball(1.0, (0, 0, 0), f, scale=(0.2, 0.18, 0.22), subdiv=2)
    b.ball(1.0, (0, -0.06, -0.03), fl, scale=(0.15, 0.13, 0.16), subdiv=2)
    for i in range(3):
        for s in (-1, 1):
            b.box((0.03, 0.01, 0.03), (s * 0.04 * (i % 2 + 0.5), -0.185, -0.08 + i * 0.06), fd, r=rot(0, 45, 0))
    for s in (-1, 1):
        b.cyl(0.015, 0.08, (s * 0.06, -0.04, -0.22), "F2A02E", sides=5)
    b.box((0.04, 0.12, 0.05), (0, 0.18, -0.12), fd, r=rot(-30, 0, 0), bevel=0.015, segs=1)
    # Netz unter den Krallen
    for x, y in ((-0.08, -0.08), (0.08, -0.08), (-0.08, 0.08), (0.08, 0.08)):
        b.cyl(0.007, 0.16, (x * 0.8, y * 0.8, -0.3), ROPE, sides=4)
    b.cyl(0.15, 0.08, (0, 0, -0.42), WOOD_L, r2=0.17, sides=10)
    b.torus(0.17, 0.014, (0, 0, -0.38), WOOD, seg=12, tseg=3)
    h = Part()
    h.ball(0.17, (0, 0, 0.07), f, scale=(1.1, 0.95, 0.9), subdiv=2)
    h.ball(1.0, (0, -0.1, 0.06), fl, scale=(0.15, 0.06, 0.11), subdiv=2)
    for s in (-1, 1):
        eye(h, s * 0.065, -0.14, 0.08, 0.055, iris=BLACK, white="FFD23E")
        h.cone(0.05, 0.12, (s * 0.11, 0.0, 0.22), fd, r=rot(0, s * 25, 0), sides=4)
    h.cone(0.025, 0.06, (0, -0.17, 0.02), "F2A02E", r=rot(110, 0, 0), sides=4)
    nodes = [("body", b, None, (0, 0, 1.3)), ("cargo", None, "body", (0, 0, -0.42)), ("head", h, "body", (0, -0.01, 0.17))]
    for nm, s in (("wing_l", -1), ("wing_r", 1)):
        w = Part()
        w.ball(1.0, (s * 0.17, 0.02, -0.02), f, r=rot(0, s * -10, 0), scale=(0.18, 0.12, 0.03), subdiv=2)
        w.ball(1.0, (s * 0.24, 0.05, -0.03), fd, r=rot(0, s * -10, 0), scale=(0.1, 0.08, 0.025), subdiv=1)
        nodes.append((nm, w, "body", (s * 0.15, 0.0, 0.04)))
    build("comp_eule", nodes)


# ---------------------------------------------------------------------------------------------- 12 Glühwürmchen
def gluehwurm():
    f, fd, wing = "3E5A3A", "253A28", "CDEBFF"
    b = Part()
    b.ball(1.0, (0, -0.02, 0.0), f, scale=(0.12, 0.14, 0.12), subdiv=2)
    # Laternen-Gestell um den Leuchtkörper
    for a in (0, 90):
        b.torus(0.16, 0.012, (0, 0.24, -0.05), BRASS, r=rot(90, 0, a), seg=14, tseg=4)
    b.cyl(0.07, 0.04, (0, 0.24, 0.12), BRASS, sides=8)
    b.torus(0.04, 0.01, (0, 0.24, 0.16), BRASS, r=rot(90, 0, 0), seg=10, tseg=3)
    for s in (-1, 1):
        limb(b, (s * 0.06, -0.02, -0.08), (s * 0.12, -0.04, -0.2), 0.012, color=fd, sides=4)
    # Körbchen am Faden
    b.cyl(0.006, 0.2, (0, 0.0, -0.22), ROPE, sides=4)
    b.cyl(0.12, 0.08, (0, 0.0, -0.38), WOOD_L, r2=0.14, sides=10)
    b.torus(0.14, 0.012, (0, 0, -0.34), WOOD, seg=12, tseg=3)
    g = Part()
    g.ball(0.14, (0, 0.24, -0.05), "D8FF6A", scale=(0.95, 1.15, 0.95), subdiv=2)
    h = Part()
    h.ball(0.12, (0, -0.06, 0.03), f, subdiv=2)
    for s in (-1, 1):
        eye(h, s * 0.055, -0.14, 0.05, 0.045)
        limb(h, (s * 0.04, -0.08, 0.12), (s * 0.1, -0.16, 0.26), 0.008, color=fd, sides=4)
    h.box((0.05, 0.015, 0.012), (0, -0.175, -0.02), "E88AA0", bevel=0.004, segs=1)
    ag = Part()
    for s in (-1, 1):
        ag.ball(0.025, (s * 0.1, -0.16, 0.26), "D8FF6A", subdiv=1)
    nodes = [("body", b, None, (0, 0, 1.2)), ("lamp_glow", g, "body", (0, 0, 0)), ("cargo", None, "body", (0, 0, -0.38)),
             ("head", h, "body", (0, -0.12, 0.04)), ("tips_glow", ag, "head", (0, 0, 0))]
    for nm, s in (("wing_l", -1), ("wing_r", 1)):
        w = Part()
        w.ball(1.0, (s * 0.15, 0.04, 0.02), wing, r=rot(0, s * -15, s * 15), scale=(0.16, 0.07, 0.01), subdiv=2)
        w.ball(1.0, (s * 0.12, 0.13, 0.0), wing, r=rot(0, s * -10, s * -20), scale=(0.12, 0.05, 0.01), subdiv=1)
        nodes.append((nm, w, "body", (s * 0.06, 0.02, 0.1)))
    build("comp_gluehwurm", nodes)


TABLE = {"comp_kistenbein": kistenbein, "comp_esel": esel, "comp_schnecke": schnecke, "comp_kaefer": kaefer, "comp_ziege": ziege,
         "comp_drohne": drohne, "comp_biber": biber, "comp_waschbaer": waschbaer, "comp_golem": golem, "comp_husky": husky,
         "comp_eule": eule, "comp_gluehwurm": gluehwurm}


def _fresh(f):
    def g():
        reset()
        f()
    return g


TABLE = {k: _fresh(v) for k, v in TABLE.items()}

if __name__ == "__main__":
    run(TABLE, sys.argv)
