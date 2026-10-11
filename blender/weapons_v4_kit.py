"""V4 Waffen-Arsenal: gemeinsame Helfer für blender/weapons_v4_<held>.py.

Die Waffen folgen den Regeln aus weapons.py (Einheitsraum: hinten y = +0,3, Mündung y = -0,7, Griff im Ursprung,
Lauf nach -Y, Objekte body + Leerobjekt muzzle). Die Länge `len` steht in src/data.gd WEAPONS und wird hier gelesen,
damit Modell und Spiel nie auseinanderlaufen.
Aufruf je Held: python3 blender/weapons_v4_jona.py [j_pistol j_smg ...]   (ohne Namen: alle des Helden)"""
import sys, os, re
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from weapons import *            # noqa: F401,F403  (Part, Y, ring, grip, trigger, prism, star, sweep, lathe, finish, Farben ...)
import weapons as _w

_DATA = os.path.join(ROOT, "src", "data.gd")


def _lengths():
    out = {}
    for line in open(_DATA, encoding="utf-8"):
        m = re.match(r'\s*"([a-z]_[a-z0-9_]+)": \{.*"len": ([0-9.]+)', line)
        if m:
            out[m.group(1)] = float(m.group(2))
    return out


LEN = _lengths()
BLACK, BROWN, LEAF, ICE, GOLDEN = "23262E", "8A5A32", "5BB04A", "CFF6FF", "F5B41E"


def done(key, p, muzzle, **kw):
    """Wie weapons.finish, mit der Länge aus data.gd."""
    _w.WLEN[key] = LEN[key]
    finish(key, p, muzzle, **kw)
    print("ok w_%s  %d Dreiecke" % (key, _w.TRIS[key]))


def stripes(p, y0, y1, z, rad, n, c1, c2, sides=12, x=0.0):
    """Rohr mit n Ringen im Wechsel zweier Farben (Zuckerstange, Warnstreifen)."""
    for i in range(n):
        a = y0 + (y1 - y0) * i / n
        b = y0 + (y1 - y0) * (i + 1) / n
        Y(p, rad, a, b, z, c1 if i % 2 == 0 else c2, sides=sides, x=x)


def blade(p, pts, depth, loc, color, r=None, bevel=0.008):
    """Flache Klinge: Umriss (x, z) in der X-Z-Ebene, dünn entlang Y; mit r drehen."""
    prism(p, pts, depth, loc, color, r=r, bevel=bevel, segs=1)


def main(table):
    want = [n[2:] if n.startswith("w_") else n for n in args()] or list(table)
    for n in want:
        table[n]()
