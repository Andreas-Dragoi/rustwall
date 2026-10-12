"""Schleimlinge (Grüntal und Grundlage jeder Flut), überarbeitet nach Kapitel 11.3: Augen, die dem Helden folgen,
ein Mund, der sich beim Angriff öffnet, je Art ein Zubehör als echtes Modellteil, dazu neue Bewegungen aus Blender:
Anlauf vor dem Sprung, Stauchen bei der Landung, Zittern bei Treffern, Zerplatzen in Tropfen, die kurz liegen bleiben.
Alle neun Arten entstehen aus EINEM Bauplan (slime) mit anderem Zubehör.
Aufruf:  python3 blender/enemies_schleim.py [art ...] [--notafel]"""
import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from animkit import *

INK = "1B2410"
CHAR = 1.5          # Figuren-Maßstab des Spiels (D.CHAR_SCALE)


def slime(key, role, color, scale, speed, rx=0.5, ry=0.5, rz=0.425, hop=0.3, hop_frames=15, angry=False, mouth_col="4A1420",
          eye_dx=0.17, eye_z=None, eye_r=0.1, acc=None, fly=False, feet=True, highlight=True, more=None):
    """Baut einen Schleimling. scale/speed wie in D.ENEMIES (Größe gegenüber dem Schleimling, m/s).
    acc(rig, pt) fügt Zubehör hinzu und liefert {teil: art} für die Mitbewegung: "bob" (wippt nach), "flap" (Flügel), "swing" (Stab)."""
    rig = Rig(key, role=role, size=CHAR * scale)
    dark, light = shade(color, 0.8), mix(color, "FFFFFF", 0.32)

    def pt(x, z, out=0.0):
        """Punkt auf der Vorderseite des Körpers."""
        u, w = x / rx, (z - rz) / rz
        v = -math.sqrt(max(1.0 - u * u - w * w, 0.0))
        n = Vector((u / rx, v / ry, w / rz)).normalized()
        return Vector((x, v * ry, z)) + n * out

    # ---- Körper (Drehpunkt am Boden: Stauchen und Strecken bleiben auf dem Boden)
    p = Part()
    p.ball(1.0, (0, 0, rz), color, scale=(rx, ry, rz), subdiv=3)
    if highlight:
        q = pt(-0.2 * rx / 0.5, rz * 1.62, -0.01)
        p.ball(0.1, tuple(q), light, scale=(1.3, 0.8, 0.5), subdiv=1)
    ez = rz + 0.07 if eye_z is None else eye_z
    for s in (-1, 1):
        q = pt((eye_dx + 0.14) * s, ez - 0.11, -0.012)
        p.ball(0.05, tuple(q), "F58A8A", scale=(1, 0.5, 0.8), subdiv=1)                      # Wangen
        if angry:
            q = pt(eye_dx * s, ez + 0.14, 0.02)
            p.box((0.2, 0.07, 0.055), tuple(q), INK, r=rot(0, -24 * s, 0), bevel=0.0)         # Zornesfalten
    rig.add("body", p, pivot=(0, 0, 0))
    if feet and not fly:
        for nm, s in (("foot_l", 1), ("foot_r", -1)):
            p = Part()
            p.ball(0.13, (0.2 * s * rx / 0.5, -0.3 * ry / 0.5, 0.07), dark, scale=(1.0, 1.35, 0.58), subdiv=1)
            rig.add(nm, p, parent="body", pivot=(0.2 * s * rx / 0.5, -0.2 * ry / 0.5, 0.07))
    # ---- Augen: weiße Augäpfel, Pupillen folgen im Spiel dem Helden
    p = Part()
    for s in (-1, 1):
        q = pt(eye_dx * s, ez, -0.035)
        p.ball(eye_r, tuple(q), "FFFFFF", scale=(1, 0.7, 1.15), subdiv=2)
    rig.add("eyes", p, parent="body", pivot=(0, pt(0, ez).y, ez))
    p = Part()
    for s in (-1, 1):
        q = pt(eye_dx * s, ez, 0.025)
        p.ball(eye_r * 0.56, tuple(q), INK, scale=(1, 0.5, 1.15), subdiv=1)
        p.ball(eye_r * 0.2, (q.x + 0.02, q.y - 0.02, q.z + 0.035), "FFFFFF", subdiv=1)
    rig.add("pupils", p, parent="eyes", pivot=(0, pt(0, ez).y - 0.03, ez), look=True)
    # ---- Mund: öffnet sich beim Angriff
    mz = ez - 0.2
    p = Part()
    q = pt(0, mz, -0.03)
    p.ball(0.1, tuple(q), mouth_col, scale=(1.25, 0.55, 0.8), subdiv=2)
    p.ball(0.045, (q.x, q.y - 0.02, q.z - 0.035), "F27A8C", scale=(1.3, 0.6, 0.6), subdiv=1)   # Zunge
    for s in (-1, 1):
        p.cone(0.022, 0.05, (0.055 * s, q.y - 0.03, q.z + 0.05), "FFFDF0", r=rot(180, 0, 0), sides=4)
    rig.add("mouth", p, parent="body", pivot=tuple(q))
    # ---- Tropfen für das Zerplatzen (im Körper versteckt)
    DN = 6
    for i in range(DN):
        p = Part()
        p.ball(0.11 - 0.012 * (i % 3), (0, 0, 0.3), color if i % 2 else light, scale=(1, 1, 0.75), subdiv=1)
        rig.add("drop%d" % i, p, pivot=(0, 0, 0.3))
    extra = acc(rig, pt) if acc else {}

    # ---------------------------------------------------------------- Clips
    HID = dict(scale=0.01, loc=(0, 0, 0))
    drops_hidden = {"drop%d" % i: HID for i in range(DN)}
    closed = dict(scale=(1.0, 1.0, 0.22))
    rest = dict(root=dict(loc=(0, 0, 0), rot=(0, 0, 0)), body=dict(scale=1.0, rot=(0, 0, 0), loc=(0, 0, 0)), eyes=dict(scale=1.0), mouth=closed, **drops_hidden)
    for a in extra:
        rest[a] = dict(rot=(0, 0, 0), loc=(0, 0, 0), scale=1.0)
    has_feet = feet and not fly

    def acc_keys(c, f, k):
        """Zubehör bewegt sich mit Verzögerung nach (k = -1 … 1)."""
        for a, kind in extra.items():
            if kind == "bob":
                c.key(f, **{a: dict(loc=(0, 0, 0.05 * k), rot=(6 * k, 0, 0))})
            elif kind == "swing":
                c.key(f, **{a: dict(rot=(10 * k, 0, 8 * k))})

    with rig.clip("idle", 36, loop=True) as c:                       # atmet, blinzelt, schaut
        c.key(0, **rest)
        c.key(12, body=dict(scale=(1.05, 1.05, 0.94)))
        c.key(24, body=dict(scale=(0.97, 0.97, 1.05)))
        c.key(26, eyes=dict(scale=1.0))
        c.key(28, eyes=dict(scale=(1, 1, 0.1)))                       # Blinzeln
        c.key(30, eyes=dict(scale=1.0))
        acc_keys(c, 0, 0); acc_keys(c, 14, 1); acc_keys(c, 26, -1)
        for a, kind in extra.items():
            if kind == "flap":
                c.wave(a, rot=(0, 34 if a.endswith("_l") else -34, 0), n=4)
    stride = speed * hop_frames / 30.0
    with rig.clip("walk", hop_frames, loop=True, stride=stride) as c:
        if fly:                                                        # flattert und wippt
            c.wave("body", loc=(0, 0, 0.1), scale=(0.03, 0.03, -0.04), rot=(0, 0, 0), base_rot=(10, 0, 0))
            for a, kind in extra.items():
                if kind == "flap":
                    c.wave(a, rot=(0, 44 if a.endswith("_l") else -44, 0), n=3)
        else:                                                          # Hüpfer: Anlauf – Absprung – Flug – Landung mit Stauchen
            f = lambda k: round(hop_frames * k)
            c.key(0, root=dict(loc=(0, 0, 0)), body=dict(scale=(1.2, 1.2, 0.74), rot=(-6, 0, 0)), mouth=closed, eyes=dict(scale=(1, 1, 0.8)))
            c.key(f(0.22), root=dict(loc=(0, 0, hop * 0.35)), body=dict(scale=(0.86, 0.86, 1.24), rot=(10, 0, 0)), eyes=dict(scale=1.0))
            c.key(f(0.5), root=dict(loc=(0, 0, hop)), body=dict(scale=(0.97, 0.97, 1.06), rot=(4, 0, 0)), mouth=dict(scale=(0.8, 1, 0.6)))
            c.key(f(0.78), root=dict(loc=(0, 0, hop * 0.3)), body=dict(scale=(0.92, 0.92, 1.14), rot=(-4, 0, 0)), mouth=closed)
            c.key(f(0.9), root=dict(loc=(0, 0, 0)), body=dict(scale=(1.26, 1.26, 0.66), rot=(-2, 0, 0)), eyes=dict(scale=(1, 1, 0.7)))
            if has_feet:
                for nm in ("foot_l", "foot_r"):
                    c.key(0, **{nm: dict(rot=(0, 0, 0))})
                    c.key(f(0.3), **{nm: dict(rot=(40, 0, 0))})
                    c.key(f(0.7), **{nm: dict(rot=(-30, 0, 0))})
                    c.key(f(0.9), **{nm: dict(rot=(0, 0, 0))})
            acc_keys(c, 0, 0); acc_keys(c, f(0.3), -1); acc_keys(c, f(0.6), 1); acc_keys(c, f(0.92), -0.6)
    with rig.clip("attack", 15, hit=8) as c:                         # holt aus, schnappt mit weit offenem Mund zu
        c.key(0, **rest)
        c.key(5, root=dict(loc=(0, 0.14, 0)), body=dict(scale=(1.12, 1.12, 0.86), rot=(-14, 0, 0)), mouth=dict(scale=(1.2, 1.0, 1.9)), eyes=dict(scale=(1, 1, 1.15)))
        c.key(8, root=dict(loc=(0, -0.36, 0.06)), body=dict(scale=(0.9, 1.12, 1.08), rot=(18, 0, 0)), mouth=dict(scale=(1.5, 1.0, 2.6)))
        c.key(10, root=dict(loc=(0, -0.3, 0)), mouth=dict(scale=(1.2, 1.0, 0.3)), body=dict(scale=(1.08, 1.0, 0.94), rot=(12, 0, 0)))
        c.key(15, **rest)
        acc_keys(c, 5, -1); acc_keys(c, 8, 1)
    with rig.clip("hit", 9) as c:                                    # zittert und wird kurz platt
        c.key(0, **rest)
        c.key(2, root=dict(loc=(0.07, 0.05, 0)), body=dict(scale=(1.18, 1.18, 0.78)), eyes=dict(scale=(1, 1, 0.3)), mouth=dict(scale=(1, 1, 1.3)), _i="LINEAR")
        c.key(3, root=dict(loc=(-0.07, 0.07, 0)), _i="LINEAR")
        c.key(4, root=dict(loc=(0.06, 0.06, 0)), _i="LINEAR")
        c.key(5, root=dict(loc=(-0.05, 0.04, 0)), body=dict(scale=(0.94, 0.94, 1.1)), _i="LINEAR")
        c.key(6, root=dict(loc=(0.03, 0.02, 0)), _i="LINEAR")
        c.key(9, **rest)
    with rig.clip("death", 27) as c:                                 # bläht sich auf, zerplatzt; Tropfen bleiben kurz liegen
        c.key(0, **rest)
        c.key(4, body=dict(scale=(1.3, 1.3, 1.28)), eyes=dict(scale=1.3), mouth=dict(scale=(1.3, 1, 2.2)))
        c.key(6, body=dict(scale=0.01), _i="LINEAR")
        for i in range(DN):
            a = math.radians(i * 60 + 20)
            d = 0.55 + 0.25 * (i % 3)
            nm = "drop%d" % i
            c.key(4, **{nm: dict(scale=0.01, loc=(0, 0, 0.1))})
            c.key(6, **{nm: dict(scale=1.0, loc=(math.cos(a) * 0.2, math.sin(a) * 0.2, 0.35))})
            c.key(10, **{nm: dict(scale=1.0, loc=(math.cos(a) * d * 0.7, math.sin(a) * d * 0.7, 0.4))})
            c.key(14, **{nm: dict(scale=(1.25, 1.25, 0.45), loc=(math.cos(a) * d, math.sin(a) * d, -0.25))})
            c.key(22, **{nm: dict(scale=(1.3, 1.3, 0.4), loc=(math.cos(a) * d, math.sin(a) * d, -0.25))})
            c.key(27, **{nm: dict(scale=0.01, loc=(math.cos(a) * d, math.sin(a) * d, -0.28))})
        for a, kind in extra.items():                                # Zubehör fällt zu Boden und bleibt liegen
            c.key(6, **{a: dict(loc=(0, 0, 0), rot=(0, 0, 0), scale=1.0)})
            c.key(13, **{a: dict(scale=(1.0 / 0.01,) * 3)}, _i="CONSTANT")
            c.key(27, **{a: dict(scale=(1.0 / 0.01,) * 3)})
        c.key(6, root=dict(loc=(0, 0, 0)))
    with rig.clip("spawn", 15) as c:                                 # ploppt aus dem Boden (wenn der Boss ruft)
        c.key(0, root=dict(loc=(0, 0, -0.1)), body=dict(scale=(0.4, 0.4, 0.05)), eyes=dict(scale=(1, 1, 0.1)), mouth=closed, **drops_hidden)
        c.key(7, root=dict(loc=(0, 0, 0.25)), body=dict(scale=(0.85, 0.85, 1.3)), eyes=dict(scale=1.2))
        c.key(11, root=dict(loc=(0, 0, 0)), body=dict(scale=(1.2, 1.2, 0.76)))
        c.key(15, **rest)
    if more:                                                         # Paket G2: besondere Clips der neuen Rollen (enemies2_schleim.py)
        more(rig, rest, extra, closed)
    rig.finish(icon_yaw=-24, icon_pitch=14)


# ================================================================= Zubehör der neun Arten
def acc_flitzer(rig, pt):
    p = Part()                                                       # nach hinten gekämmte Stacheln
    for (y, z, hh, a) in ((-0.04, 0.71, 0.34, -38), (0.18, 0.71, 0.42, -52), (0.38, 0.61, 0.36, -66)):
        p.cone(0.13, hh, (0, y, z), "F6F79A", r=rot(a, 0, 0), sides=6)
    p.cone(0.15, 0.4, (0, 0.62, 0.3), "C6CE3E", r=rot(-100, 0, 0), sides=6)
    rig.add("spikes", p, parent="body", pivot=(0, 0.1, 0.6))
    return {"spikes": "bob"}


def acc_fass(rig, pt):
    m = T(0, 0.2, 0.74) @ rot(-18, 0, 0)
    p = MPart(m)                                                     # rotes Sprengfass mit Gurt
    lathe(p, [(0.2, -0.28, "B0282E"), (0.27, -0.2, "D8343A"), (0.29, -0.07, "FFD23E"), (0.29, 0.07, "D8343A"), (0.27, 0.2, "B0282E"), (0.2, 0.28, "B0282E")], sides=10)
    p.cyl(0.03, 0.2, (0.05, 0, 0.36), "3A2A20", r=rot(0, 20, 0), sides=5)
    rig.add("barrel", p, parent="body", pivot=(0, 0.2, 0.5))
    p = MPart(m)
    p.ball(0.07, (0.1, 0, 0.47), "FFE25A", subdiv=1)                 # glimmende Lunte
    rig.add("fuse", p, parent="barrel", pivot=tuple((m @ Vector((0.1, 0, 0.47)))), glow=True)
    return {"barrel": "bob"}


def acc_brocken(rig, pt):
    p = Part()
    for i, (x, y, z, s, a) in enumerate(((0.0, 0.1, 0.86, 0.32, 20), (-0.29, 0.06, 0.74, 0.26, 50), (0.3, 0.08, 0.74, 0.28, -30),
                                         (0.02, 0.4, 0.58, 0.26, 70), (-0.3, 0.34, 0.48, 0.2, 10), (0.32, 0.34, 0.46, 0.2, 40))):
        p.box((s, s * 0.95, s * 0.85), (x, y, z), ("9A8F96", "837985", "ADA3A8")[i % 3], r=rot(12 * (i % 3), 8 * i, a), bevel=s * 0.22, segs=1)
    rig.add("rocks", p, parent="body", pivot=(0, 0.1, 0.6))
    p = Part()                                                       # Hauer
    for s in (-1, 1):
        q = pt(0.15 * s, 0.3)
        p.cone(0.055, 0.2, (q.x, q.y - 0.03, q.z + 0.07), "FFFDF0", r=rot(8, 6 * s, 0), sides=6)
    rig.add("tusks", p, parent="body", pivot=(0, -0.4, 0.3))
    return {"rocks": "bob"}


def acc_spucker(rig, pt):
    p = Part()                                                       # Rüssel zum Spucken
    lathe(p, [(0.19, 0.0, "23876F"), (0.16, 0.26, "23876F"), (0.2, 0.3, "1C6E5B"), (0.2, 0.34, "1C6E5B"), (0.12, 0.34, "0E2E28"), (0.1, 0.2, "0E2E28")], sides=10, loc=(0, -0.36, 0.3), r=rot(90, 0, 0), cap=False)
    rig.add("snout", p, parent="body", pivot=(0, -0.36, 0.3))
    p = Part()                                                       # Giftblasen
    for x, y, z, r in ((0.2, 0.22, 0.82, 0.13), (-0.2, 0.3, 0.72, 0.1), (0.0, 0.42, 0.62, 0.08)):
        p.ball(r, (x, y, z), "CDF24A", subdiv=1)
    rig.add("blisters", p, parent="body", pivot=(0, 0.3, 0.7), glow=True)
    return {"snout": "bob", "blisters": "bob"}


def acc_helm(rig, pt):
    p = Part()                                                       # Stahlhelm (das Spiel blendet ihn aus, wenn der Schild bricht)
    lathe(p, [(0.6, 0.57, "6C7689"), (0.6, 0.63, "8A94A8"), (0.52, 0.64, "8A94A8"), (0.5, 0.84, "8A94A8"), (0.36, 0.95, "8A94A8"), (0.0, 0.99, "8A94A8")], sides=12)
    p.box((0.09, 0.5, 0.14), (0, 0.0, 0.98), "D54144", bevel=0.04, segs=1)
    rig.add("helm", p, parent="body", pivot=(0, 0, 0.62), hide=True)
    return {"helm": "bob"}


def acc_flatter(rig, pt):
    for nm, s in (("wing_l", 1), ("wing_r", -1)):
        p = Part()
        p.ball(1.0, (0, 0, 0), "F1FADC", r=T(0.56 * s, 0.1, 0.64) @ rot(0, -32 * s, 14 * s), scale=(0.34, 0.2, 0.045), subdiv=2)
        p.ball(1.0, (0, 0, 0), "DDF0BE", r=T(0.5 * s, 0.14, 0.44) @ rot(0, 6 * s, 20 * s), scale=(0.24, 0.15, 0.04), subdiv=1)
        rig.add(nm, p, parent="body", pivot=(0.3 * s, 0.1, 0.5))
    p = Part()                                                       # Fühler
    for s in (-1, 1):
        p.cyl(0.018, 0.2, (0.1 * s, -0.05, 0.84), "7E9D4E", r=rot(10, 18 * s, 0), sides=4)
        p.ball(0.045, (0.135 * s, -0.07, 0.95), "FFE25A", subdiv=1)
    rig.add("feelers", p, parent="body", pivot=(0, -0.05, 0.76))
    return {"wing_l": "flap", "wing_r": "flap", "feelers": "bob"}


def acc_schamane(rig, pt):
    hat = "5A3FA0"
    p = MPart(T(0, 0.03, 0.74) @ rot(-8, 0, 0))                      # Federschmuck: Stirnband mit bunten Federn
    lathe(p, [(0.44, 0.0, "FFD23E"), (0.45, 0.07, "FFD23E"), (0.4, 0.1, hat), (0.2, 0.16, hat), (0.0, 0.18, hat)], sides=12)
    for i, cc in enumerate(("E23B3B", "3FA8F5", "FFFFFF", "3FA8F5", "E23B3B")):
        a = math.radians(-50 + i * 25)
        p.cone(0.075, 0.5 - 0.06 * abs(i - 2), (math.sin(a) * 0.36, 0.26, 0.26 + 0.06 * (2 - abs(i - 2))), cc, r=rot(-22, math.degrees(a) * 0.5, 0), sides=4)
    rig.add("feathers", p, parent="body", pivot=(0, 0.03, 0.74))
    p = Part()                                                       # Stab mit leuchtender Kugel
    p.cyl(0.035, 1.05, (0.62, -0.12, 0.53), "7A4522", r=rot(0, 6, 0), sides=6)
    rig.add("staff", p, parent="body", pivot=(0.6, -0.12, 0.05))
    p = Part()
    p.ball(0.12, (0.675, -0.12, 1.12), "CDF24A", subdiv=2)
    rig.add("orb", p, parent="staff", pivot=(0.675, -0.12, 1.12), glow=True)
    return {"feathers": "bob", "staff": "swing"}


def acc_boss(rig, pt):
    gold = "FFCB2E"
    p = Part()                                                       # goldene Krone mit Edelsteinen
    lathe(p, [(0.25, 0.81, gold), (0.29, 0.95, gold)], sides=12)
    for i in range(6):
        a = math.radians(i * 60 + 30)
        p.cone(0.075, 0.2, (math.sin(a) * 0.265, -math.cos(a) * 0.265 + 0.02, 1.03), gold, sides=4, r=rot(0, 0, i * 60 + 30))
    for i, cc in enumerate(("E23B3B", "3FA8F5", "E23B3B")):
        a = math.radians(-60 + i * 60)
        p.ball(0.045, (math.sin(a) * 0.275, -math.cos(a) * 0.275 + 0.02, 0.88), cc, subdiv=1)
    rig.add("crown", p, parent="body", pivot=(0, 0.02, 0.84))
    p = Part()                                                       # Hauer
    for s in (-1, 1):
        q = pt(0.2 * s, 0.25)
        p.cone(0.05, 0.17, (q.x, q.y - 0.03, q.z + 0.05), "FFFDF0", r=rot(8, 8 * s, 0), sides=6)
    rig.add("tusks", p, parent="body", pivot=(0, -0.4, 0.25))
    return {"crown": "bob"}


GREEN = "9DC42C"
# Werte (scale, speed) wie in src/data.gd, damit Größe und Schrittlänge stimmen
TABLE = {
    "schleim_schleimling": lambda: slime("schleim_schleimling", "mass", GREEN, 1.0, 2.3),
    "schleim_flitzer": lambda: slime("schleim_flitzer", "fast", "DDE646", 0.8, 4.6, rx=0.4, ry=0.54, rz=0.36, hop=0.22, hop_frames=9, angry=True, acc=acc_flitzer),
    "schleim_fass": lambda: slime("schleim_fass", "special", "F08A26", 1.05, 3.0, hop=0.26, hop_frames=12, angry=True, acc=acc_fass),
    "schleim_brocken": lambda: slime("schleim_brocken", "tank", "5E8F22", 2.3, 1.6, rx=0.52, ry=0.52, rz=0.44, hop=0.14, hop_frames=21, angry=True, acc=acc_brocken, highlight=False),
    "schleim_spucker": lambda: slime("schleim_spucker", "ranged", "35B79A", 1.1, 2.0, rx=0.47, ry=0.47, rz=0.43, hop=0.22, hop_frames=15, eye_z=0.62, eye_dx=0.19, acc=acc_spucker),
    "schleim_helm": lambda: slime("schleim_helm", "mass", GREEN, 1.05, 2.2, hop=0.28, eye_z=0.42, acc=acc_helm, highlight=False),
    "schleim_flatter": lambda: slime("schleim_flatter", "air", "B4E070", 0.9, 3.2, rx=0.42, ry=0.42, rz=0.38, fly=True, hop_frames=12, acc=acc_flatter),
    "schleim_schamane": lambda: slime("schleim_schamane", "special", "9670DC", 1.15, 2.0, rx=0.48, ry=0.48, rz=0.43, hop=0.2, acc=acc_schamane, highlight=False),
    "schleim_boss": lambda: slime("schleim_boss", "tank", "7FA524", 4.6, 1.3, rx=0.53, ry=0.53, rz=0.44, hop=0.1, hop_frames=27, angry=True, mouth_col="3A0F18", eye_dx=0.19, acc=acc_boss),
}

if __name__ == "__main__":
    run(TABLE, [a for a in sys.argv if not a.startswith("--")])
