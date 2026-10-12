"""Paket G2 – neue Schleim-Arten (Kapitel 6.3): Brutschleim (Brutmutter), Deckelschild (Schildträger), Klauschleim (Dieb)
und der Miniboss Glibberkoloss. Gebaut mit dem Schleim-Bauplan aus enemies_schleim.py (slime) plus eigenem Zubehör
und den besonderen Clips der Rolle (brood, block, grab, skill).
Aufruf:  python3 blender/enemies2_schleim.py [art ...] [--notafel]"""
import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from animkit import *
from enemies_schleim import slime, INK


def R(x=0, y=0, z=0):
    return dict(rot=(x, y, z))


# ================================================================= Brutschleim: durchsichtiger Riesenschleim mit Jungen im Bauch
def acc_brut(rig, pt):
    p = Part()                                                       # drei kleine Schleimlinge reiten auf dem Rücken
    for (x, y, z, r, c) in ((0.2, 0.12, 0.8, 0.13, "B8E05A"), (-0.2, 0.18, 0.78, 0.12, "D6EE5A"), (0.0, 0.34, 0.74, 0.11, "C6E86A")):
        p.ball(r, (x, y, z), c, scale=(1, 1, 0.85), subdiv=1)
        for s in (-1, 1):
            p.ball(r * 0.22, (x + s * r * 0.35, y - r * 0.85, z + r * 0.25), "FFFFFF", subdiv=1)
    rig.add("kids", p, parent="body", pivot=(0, 0.2, 0.75), glow=False)
    p = Part()                                                       # Blasen auf dem Rücken (pulsieren beim Brüten)
    for (x, y, z, r) in ((0.22, 0.3, 0.72, 0.09), (-0.24, 0.26, 0.7, 0.07), (0.05, 0.4, 0.8, 0.06), (-0.05, 0.44, 0.55, 0.08)):
        p.ball(r, (x, y, z), "E6FF9A", subdiv=1)
    rig.add("bubbles", p, parent="body", pivot=(0, 0.35, 0.7), glow=True)
    return {"kids": "kid", "bubbles": "bob"}


def more_brut(rig, rest, extra, closed):
    with rig.clip("brood", 30, hit=18) as c:                         # zieht sich zusammen, würgt und spuckt Junge aus
        c.key(0, **rest)
        c.key(8, body=dict(scale=(1.12, 1.12, 0.84)), kids=dict(scale=1.25, loc=(0, 0, -0.05)), bubbles=dict(scale=1.4), eyes=dict(scale=(1, 1, 0.4)))
        c.key(14, body=dict(scale=(0.86, 0.86, 1.22), rot=(-10, 0, 0)), kids=dict(scale=1.35, loc=(0, -0.12, 0.12)), mouth=dict(scale=(1.4, 1, 2.4)))
        c.key(18, body=dict(scale=(1.2, 1.2, 0.8), rot=(14, 0, 0)), kids=dict(scale=0.6, loc=(0, -0.2, 0.0)), mouth=dict(scale=(1.6, 1, 2.8)), _i="LINEAR")
        c.key(24, body=dict(scale=(0.96, 0.96, 1.05)), kids=dict(scale=0.85), mouth=closed, bubbles=dict(scale=1.0))
        c.key(30, **rest)


# ================================================================= Deckelschild: Schleim mit Mülltonnendeckel als Schild
def acc_deckel(rig, pt):
    q = pt(0, 0.42, 0.08)
    m = T(q.x, q.y - 0.06, q.z) @ rot(82, 0, 0)
    p = MPart(m)                                                     # gewölbter Blechdeckel mit Griff, Dellen und Rostflecken
    lathe(p, [(0.44, -0.03, "8C95A6"), (0.47, 0.0, "B2BACB"), (0.42, 0.06, "A0A9BA"), (0.25, 0.12, "B2BACB"), (0.0, 0.15, "C4CCDA")], sides=14)
    p.box((0.2, 0.06, 0.06), (0, 0, 0.19), "5A6274", bevel=0.02, segs=1)
    for (x, y, r) in ((0.18, 0.12, 0.07), (-0.2, -0.1, 0.06), (0.05, -0.25, 0.05)):
        p.ball(r, (x, y, 0.07), "A8683A", scale=(1, 1, 0.25), subdiv=1)
    rig.add("lid", p, parent="body", pivot=(q.x, q.y, q.z))
    p = Part()                                                       # Ärmchen, das den Deckel hält
    for s in (-1, 1):
        capsule(p, (0.36 * s, -0.2, 0.42), (0.22 * s, -0.42, 0.44), 0.05, 0.045, "7FA524", sides=5)
    rig.add("arms", p, parent="body", pivot=(0, -0.3, 0.43))
    p = Part()                                                       # Augen lugen über den Deckelrand: Stirnband
    p.box((0.6, 0.06, 0.07), (0, -0.33, 0.8), "D54144", r=rot(-20, 0, 0), bevel=0.02, segs=1)
    rig.add("band", p, parent="body", pivot=(0, -0.3, 0.8))
    return {"lid": "shield", "band": "bob"}


def more_deckel(rig, rest, extra, closed):
    with rig.clip("block", 15) as c:                                 # duckt sich hinter den Deckel, ein Treffer scheppert
        c.key(0, **rest)
        c.key(3, body=dict(scale=(1.1, 1.1, 0.82), rot=(6, 0, 0)), lid=dict(loc=(0, -0.08, -0.05), rot=(-10, 0, 0)), eyes=dict(scale=(1, 1, 0.2)), _i="LINEAR")
        c.key(5, lid=dict(loc=(0.03, -0.02, -0.05), rot=(-4, 0, 8)), _i="LINEAR")
        c.key(7, lid=dict(loc=(-0.03, -0.06, -0.05), rot=(-8, 0, -8)))
        c.key(15, **rest)


# ================================================================= Klauschleim: Ganovenmaske und Beutesack
def acc_klau(rig, pt):
    p = Part()                                                       # schwarze Augenmaske mit Bändern
    q = pt(0, 0.5, 0.02)
    p.box((0.72, 0.08, 0.15), (q.x, q.y + 0.02, q.z), INK, r=rot(-12, 0, 0), bevel=0.03, segs=1)
    for s in (-1, 1):
        p.box((0.05, 0.22, 0.04), (0.33 * s, 0.1, 0.62), INK, r=rot(30, 0, 20 * s))
    rig.add("mask", p, parent="body", pivot=(0, -0.3, 0.5))
    p = Part()                                                       # Schiebermütze
    lathe(p, [(0.32, 0.7, "6B5A4A"), (0.34, 0.76, "7D6A58"), (0.28, 0.86, "7D6A58"), (0.0, 0.9, "7D6A58")], sides=10, loc=(0, 0.03, 0.0))
    p.box((0.36, 0.22, 0.04), (0, -0.28, 0.73), "5E4E40", r=rot(-14, 0, 0), bevel=0.02, segs=1)
    rig.add("cap", p, parent="body", pivot=(0, 0, 0.75))
    p = Part()                                                       # Beutesack auf dem Rücken mit Münz-Zeichen
    p.ball(0.3, (0.05, 0.42, 0.52), "C8A46A", scale=(1, 0.85, 1.05), subdiv=2)
    p.cone(0.12, 0.16, (0.05, 0.42, 0.86), "B08A50", sides=6)
    p.box((0.16, 0.03, 0.16), (0.05, 0.16, 0.56), "FFD23E", r=rot(0, 45, 0), bevel=0.02, segs=1)
    rig.add("sack", p, parent="body", pivot=(0.05, 0.3, 0.5))
    return {"mask": "none", "cap": "bob", "sack": "bob"}


def more_klau(rig, rest, extra, closed):
    with rig.clip("grab", 24, hit=10) as c:                          # schnappt sich die Beute und stopft sie in den Sack
        c.key(0, **rest)
        c.key(6, root=dict(loc=(0, -0.2, 0)), body=dict(scale=(0.9, 1.18, 0.9), rot=(24, 0, 0)), mouth=dict(scale=(1.3, 1, 2.0)))
        c.key(10, root=dict(loc=(0, -0.25, 0)), body=dict(rot=(30, 0, 0)), mouth=closed, _i="LINEAR")
        c.key(16, root=dict(loc=(0, 0.05, 0.12)), body=dict(rot=(-20, 0, 0), scale=(1.05, 1.05, 0.95)), sack=dict(scale=1.35, rot=(-16, 0, 0)))
        c.key(24, **rest)


# ================================================================= Glibberkoloss (Miniboss): turmhoher Wackelpudding mit Topfhelm
def acc_koloss(rig, pt):
    p = Part()                                                       # verbeulter Kochtopf als Helm, Kochlöffel als Feder
    lathe(p, [(0.36, 0.72, "8A93A6"), (0.38, 0.74, "A5AEC2"), (0.37, 0.94, "B8C0D2"), (0.33, 0.96, "8A93A6"), (0.0, 0.97, "8A93A6")], sides=12)
    for s in (-1, 1):
        p.box((0.16, 0.06, 0.05), (0.42 * s, 0, 0.86), "4A5264", bevel=0.02, segs=1)
    p.cyl(0.025, 0.42, (0.12, 0.12, 1.12), "B07A48", r=rot(16, 18, 0), sides=5)
    p.ball(0.07, (0.18, 0.18, 1.3), "B07A48", scale=(1, 0.6, 1.3), subdiv=1)
    rig.add("pot", p, parent="body", pivot=(0, 0, 0.8))
    p = Part()                                                       # Schleimfäuste
    for s in (-1, 1):
        p.ball(0.15, (0.55 * s, -0.12, 0.32), "6F9A22", scale=(1, 1, 0.9), subdiv=2)
    rig.add("fists", p, parent="body", pivot=(0, -0.1, 0.35))
    p = Part()                                                       # verschluckter Kram schimmert durch
    p.box((0.14, 0.06, 0.2), (0.12, 0.05, 0.42), "D54144", r=rot(20, 10, 30), bevel=0.02, segs=1)
    p.cyl(0.06, 0.16, (-0.14, 0.1, 0.5), "FFD23E", r=rot(70, 0, 20), sides=6)
    p.ball(0.06, (0.0, 0.18, 0.28), "3FA8F5", subdiv=1)
    rig.add("junk", p, parent="body", pivot=(0, 0.1, 0.4))
    return {"pot": "bob", "fists": "swing", "junk": "none"}


def more_koloss(rig, rest, extra, closed):
    with rig.clip("skill", 39, hit=27) as c:                         # duckt sich, springt hoch und landet mit voller Wucht
        c.key(0, **rest)
        c.key(10, body=dict(scale=(1.3, 1.3, 0.62)), fists=dict(loc=(0, 0, 0.25), rot=(-30, 0, 0)), eyes=dict(scale=(1, 1, 0.5)), mouth=dict(scale=(1.4, 1, 1.4)))
        c.key(18, root=dict(loc=(0, 0, 0.7)), body=dict(scale=(0.86, 0.86, 1.3)), fists=dict(loc=(0, 0, 0.4), rot=(-60, 0, 0)), pot=dict(loc=(0, 0, 0.1)))
        c.key(24, root=dict(loc=(0, 0, 0.5)), body=dict(scale=(0.95, 0.95, 1.1)))
        c.key(27, root=dict(loc=(0, 0, 0)), body=dict(scale=(1.45, 1.45, 0.55)), fists=dict(loc=(0, -0.15, -0.15), rot=(30, 0, 0)), pot=dict(loc=(0, 0, -0.1)), mouth=dict(scale=(1.6, 1, 2.0)), _i="LINEAR")
        c.key(33, body=dict(scale=(0.92, 0.92, 1.12)), mouth=closed)
        c.key(39, **rest)


TABLE = {
    "schleim_brutschleim": lambda: slime("schleim_brutschleim", "brood", "86C83A", 1.8, 1.4, rx=0.52, ry=0.52, rz=0.42, hop=0.12, hop_frames=21, eye_dx=0.2, acc=acc_brut, more=more_brut),
    "schleim_deckel": lambda: slime("schleim_deckel", "shield", "8FBE2C", 1.1, 2.0, hop=0.18, hop_frames=15, eye_z=0.62, angry=True, acc=acc_deckel, more=more_deckel),
    "schleim_klauschleim": lambda: slime("schleim_klauschleim", "thief", "6FC48A", 0.95, 3.4, rx=0.46, ry=0.5, rz=0.4, hop=0.24, hop_frames=11, acc=acc_klau, more=more_klau, highlight=False),
    "schleim_koloss": lambda: slime("schleim_koloss", "miniboss", "6F9A22", 2.5, 1.3, rx=0.54, ry=0.54, rz=0.45, hop=0.12, hop_frames=24, angry=True, mouth_col="3A0F18", eye_dx=0.2, acc=acc_koloss, more=more_koloss, highlight=False),
}

if __name__ == "__main__":
    run(TABLE, [a for a in sys.argv if not a.startswith("--")])
