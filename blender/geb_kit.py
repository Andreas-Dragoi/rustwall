"""Rustwall – Baukasten für die detailreichen Gebäude (Paket 6 des Entwicklungsauftrags V3).

Baut auf kit.py auf und ergänzt, was der Detail-Katalog 6.2 verlangt:
Fundament mit Fugen, Wände mit erkennbarem Baustoff (Bretter, Ziegel, Stein, Wellblech, Betonplatten),
Dächer mit Ziegel-/Blechreihen, First, Dachrinne, Türen und Fenster mit Rahmen, Lampen, Gebrauchsspuren,
Schadens-Teile und die Verwaltung der Objektnamen (body, *_glow, lv4_*, lv7_*, lvmax3_*, lvmax6_*, dmg1_*, dmg2_*, fillN_*).

Ein Gebäude wird als `Model` gebaut:  M = Model("b_saege", 5.6, 5.6);  M["body"].box(...);  M.finish()
`M["name"]` liefert das Sammel-Teil (kit.Part) für das Objekt dieses Namens und legt es bei Bedarf an.
"""
import sys, os, math, random
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import kit
from kit import *

I4 = Matrix.Identity(4)
RNG = random.Random(1)

# ---------------------------------------------------------------- Farben
ST, ST_D, ST_L = "AEB6D2", "8690B0", "C6CDE4"        # blaugrauer Stein
PAVE, MORTAR = "CFC8BC", "6E675F"                     # Pflaster, Fugen
BLUE, BLUE_L, BLUE_D = "3B6FD0", "5B93EE", "2C4F9E"
GOLD, GOLD_D, DK = "F2B92E", "C58A1E", "363D52"
WOOD, WOOD_D, WOOD_L, WOOD_P = "B5682F", "7A4522", "D9A05A", "C98A4B"
RED, RED_D, OLIVE, CREAM, STEEL, STEEL_L, STEEL_D = "E04848", "A82F3A", "8FA043", "EADBB4", "8A94A8", "C9D0DE", "5A6274"
GLOW, CYAN, PURPLE, HOT = "FFD24D", "5FE3FF", "B77BFF", "FF4A3A"
BRICK, PLASTER, CONCRETE, CONC_D = "C2603F", "F0E6CC", "B9BDC4", "8C919C"
MOSS, SOOT, CRACK, RUST = "6F9A35", "38322E", "24211F", "A5532A"
JOINT = "4A4038"                                     # dunkler Kern hinter Brettern/Steinen (Fugenfarbe)
SACK = "E8B76E"


def T(x, y, z):
    return Matrix.Translation(Vector((x, y, z)))


def S(x, y, z):
    return Matrix.Diagonal(Vector((x, y, z, 1.0)))


def jit(c, amt=0.06):
    """Leichte Farbschwankung je Brett/Ziegel (Vorgabe ±6 %)."""
    return shade(c, 1.0 + RNG.uniform(-amt, amt))


# ---------------------------------------------------------------- Teile in einem verschobenen/gedrehten Bezug
class At:
    """Stellvertreter für ein Part: gleiche Aufrufe (box, cyl, cone, ball, torus), aber in einem eigenen Bezugssystem m."""

    def __init__(self, part, m):
        if isinstance(part, At):
            m = part.m @ m
            part = part.part
        self.part, self.m = part, m

    def _r(self, loc, r):
        return self.m @ T(*loc) @ (r if r is not None else I4)

    def box(self, size, loc=(0, 0, 0), color="stone", r=None, bevel=0.0, segs=2):
        self.part.box(size, (0, 0, 0), color, r=self._r(loc, r), bevel=bevel, segs=segs)
        return self

    def cyl(self, radius, height, loc=(0, 0, 0), color="steel", r=None, r2=None, sides=20, bevel=0.0, segs=2):
        self.part.cyl(radius, height, (0, 0, 0), color, r=self._r(loc, r), r2=r2, sides=sides, bevel=bevel, segs=segs)
        return self

    def cone(self, radius, height, loc=(0, 0, 0), color="pine", r=None, sides=12):
        self.part.cone(radius, height, (0, 0, 0), color, r=self._r(loc, r), sides=sides)
        return self

    def ball(self, radius, loc=(0, 0, 0), color="slime", r=None, scale=(1, 1, 1), subdiv=3):
        self.part.ball(radius, (0, 0, 0), color, r=self._r(loc, r), scale=scale, subdiv=subdiv)
        return self

    def torus(self, radius, tube, loc=(0, 0, 0), color="tire", r=None, seg=20, tseg=8):
        self.part.torus(radius, tube, (0, 0, 0), color, r=self._r(loc, r), seg=seg, tseg=tseg)
        return self


def _pm(p):
    return (p.part, p.m) if isinstance(p, At) else (p, I4)


def _track(a, b):
    a = Vector(a); b = Vector(b)
    d = b - a
    return (a + b) * 0.5, d.length, d.to_track_quat("Z", "Y").to_matrix().to_4x4()


def beam(p, a, b, w, color, bevel=0.0, d=None):
    """Balken (Quader) von Punkt a nach b."""
    c, l, m = _track(a, b)
    p.box((w, d or w, l), c, color, r=m, bevel=bevel, segs=1)


def tube(p, a, b, rad, color, sides=8, bevel=0.0):
    """Rohr (Zylinder) von Punkt a nach b."""
    c, l, m = _track(a, b)
    p.cyl(rad, l, c, color, r=m, sides=sides, bevel=bevel, segs=1)


def pipe(p, pts, rad, color, sides=8, joints=True):
    """Rohrleitung durch mehrere Punkte, mit Kugelgelenken an den Knicken."""
    for i in range(len(pts) - 1):
        tube(p, pts[i], pts[i + 1], rad, color, sides)
        if joints and i > 0:
            p.ball(rad * 1.25, pts[i], shade(color, 0.85), subdiv=1)


# ---------------------------------------------------------------- Ebenen (Wände, Dachflächen, Boden)
class Plane:
    """Ebene mit eigenem Bezug: u entlang ex, v entlang ey, 'out' entlang der Normalen ez = ex x ey."""

    def __init__(self, o, ex, ey, length=0.0, height=0.0):
        self.o = Vector(o)
        self.ex = Vector(ex).normalized()
        self.ey = Vector(ey).normalized()
        self.ez = self.ex.cross(self.ey)
        self.len = length
        self.h = height

    def pt(self, u, v, out=0.0):
        return self.o + self.ex * u + self.ey * v + self.ez * out

    def M(self, u=0.0, v=0.0, out=0.0):
        """Matrix für kit-Körper: lokales X = entlang der Wand, lokales -Y = nach außen, lokales Z = v-Richtung."""
        m = Matrix.Identity(4)
        nz = -self.ez
        for i in range(3):
            m[i][0] = self.ex[i]; m[i][1] = nz[i]; m[i][2] = self.ey[i]
        p = self.pt(u, v, out)
        m[0][3], m[1][3], m[2][3] = p.x, p.y, p.z
        return m

    def moved(self, m):
        r = m.to_3x3()
        return Plane(m @ self.o, r @ self.ex, r @ self.ey, self.len, self.h)


def wand(a, b, z=0.0, h=0.0):
    """Wand von a nach b (2D-Punkte, von außen gesehen von links nach rechts), Unterkante in Höhe z."""
    d = Vector((b[0] - a[0], b[1] - a[1], 0.0))
    return Plane((a[0], a[1], z), d, (0, 0, 1), d.length, h)


def boden(x0, y0, z, w=0.0, d=0.0):
    """Waagerechte Ebene (u = +X, v = +Y, out = nach oben)."""
    return Plane((x0, y0, z), (1, 0, 0), (0, 1, 0), w, d)


class Haus:
    """Quaderförmiger Baukörper: Mitte (cx, cy), Breite w (X), Tiefe d (Y), Unterkante z0, Wandhöhe h."""

    def __init__(self, cx, cy, w, d, z0=0.25, h=3.2):
        self.cx, self.cy, self.w, self.d, self.z0, self.h = cx, cy, w, d, z0, h
        x0, x1, y0, y1 = cx - w / 2, cx + w / 2, cy - d / 2, cy + d / 2
        self.x0, self.x1, self.y0, self.y1 = x0, x1, y0, y1
        self.walls = {"f": wand((x0, y0), (x1, y0), z0, h), "r": wand((x1, y0), (x1, y1), z0, h),
                      "b": wand((x1, y1), (x0, y1), z0, h), "l": wand((x0, y1), (x0, y0), z0, h)}

    def W(self, side):
        return self.walls[side]

    @property
    def top(self):
        return self.z0 + self.h

    def kern(self, p, color=JOINT, inset=0.0):
        """Massiver Kern (Fugenfarbe); die Verkleidung liegt davor."""
        p.box((self.w - inset * 2, self.d - inset * 2, self.h), (self.cx, self.cy, self.z0 + self.h / 2), color)


# ---------------------------------------------------------------- Grundformen aus Einzelflächen (sparsam: ohne Rückseite)
def slab(p, pl, pts, out, th, color, side=0.78):
    """Platte mit Vieleck-Umriss pts [(u, v), ...] (gegen den Uhrzeiger von außen gesehen), Oberfläche bei 'out', Dicke th.
    Erzeugt nur Vorderseite und Ränder (keine Rückseite)."""
    part, m = _pm(p)
    bm, lay = part.bm, part.layer
    c = col(color)
    cs = (c[0] * side, c[1] * side, c[2] * side, 1.0)
    top = [bm.verts.new(m @ pl.pt(u, v, out)) for (u, v) in pts]
    f = bm.faces.new(top)
    f.smooth = True
    for l in f.loops:
        l[lay] = c
    if th > 0.0:
        bot = [bm.verts.new(m @ pl.pt(u, v, out - th)) for (u, v) in pts]
        n = len(pts)
        for i in range(n):
            j = (i + 1) % n
            f = bm.faces.new((top[i], bot[i], bot[j], top[j]))
            f.smooth = True
            for l in f.loops:
                l[lay] = cs


def tile(p, pl, u0, v0, u1, v1, out, th, color, side=0.78):
    slab(p, pl, [(u0, v0), (u1, v0), (u1, v1), (u0, v1)], out, th, color, side)


def wedge(p, pl, u0, v0, u1, v1, out0, out1, base, color, side=0.7):
    """Keil (Dachziegel): Oberfläche bei v0 in Höhe out0, bei v1 in Höhe out1, Unterkante bei 'base'."""
    part, m = _pm(p)
    bm, lay = part.bm, part.layer
    c = col(color)
    cs = (c[0] * side, c[1] * side, c[2] * side, 1.0)
    top = [bm.verts.new(m @ pl.pt(u0, v0, out0)), bm.verts.new(m @ pl.pt(u1, v0, out0)),
           bm.verts.new(m @ pl.pt(u1, v1, out1)), bm.verts.new(m @ pl.pt(u0, v1, out1))]
    bot = [bm.verts.new(m @ pl.pt(u0, v0, base)), bm.verts.new(m @ pl.pt(u1, v0, base)),
           bm.verts.new(m @ pl.pt(u1, v1, base)), bm.verts.new(m @ pl.pt(u0, v1, base))]
    f = bm.faces.new(top)
    f.smooth = True
    for l in f.loops:
        l[lay] = c
    for i in range(4):
        j = (i + 1) % 4
        f = bm.faces.new((top[i], bot[i], bot[j], top[j]))
        f.smooth = True
        for l in f.loops:
            l[lay] = cs


def stud(p, pl, u, v, out, r=0.05, color=STEEL_L, h=0.035):
    """Niete: flache vierseitige Pyramide."""
    part, m = _pm(p)
    bm, lay = part.bm, part.layer
    c = col(color)
    tip = bm.verts.new(m @ pl.pt(u, v, out + h))
    ring = [bm.verts.new(m @ pl.pt(u + dx * r, v + dv * r, out)) for (dx, dv) in ((-1, -1), (1, -1), (1, 1), (-1, 1))]
    for i in range(4):
        f = bm.faces.new((ring[i], ring[(i + 1) % 4], tip))
        f.smooth = True
        for l in f.loops:
            l[lay] = c


def _rect_sub(r, h):
    u0, v0, u1, v1 = r
    a0, b0, a1, b1 = h
    if a0 >= u1 or a1 <= u0 or b0 >= v1 or b1 <= v0:
        return [r]
    out = []
    if a0 > u0:
        out.append((u0, v0, a0, v1))
    if a1 < u1:
        out.append((a1, v0, u1, v1))
    lo, hi = max(u0, a0), min(u1, a1)
    if b0 > v0:
        out.append((lo, v0, hi, b0))
    if b1 < v1:
        out.append((lo, b1, hi, v1))
    return out


def cut(rects, holes, eps=0.035):
    for h in holes:
        nxt = []
        for r in rects:
            nxt += _rect_sub(r, h)
        rects = nxt
    return [r for r in rects if r[2] - r[0] > eps and r[3] - r[1] > eps]


def _clip(pts, a, b, c):
    """Schneidet ein konvexes Vieleck auf a*u + b*v <= c zu."""
    out = []
    n = len(pts)
    for i in range(n):
        p, q = pts[i], pts[(i + 1) % n]
        dp, dq = a * p[0] + b * p[1] - c, a * q[0] + b * q[1] - c
        if dp <= 0:
            out.append(p)
        if (dp < 0 < dq) or (dq < 0 < dp):
            t = dp / (dp - dq)
            out.append((p[0] + (q[0] - p[0]) * t, p[1] + (q[1] - p[1]) * t))
    return out


def giebel(u0, u1, v_eave, v_apex):
    """Schnittlinien für ein Giebeldreieck über der Wand von u0 bis u1 (für clad(..., lines=...))."""
    um = (u0 + u1) * 0.5
    s = (v_apex - v_eave) / (um - u0)
    return [(-s, 1.0, v_eave - s * u0), (s, 1.0, v_eave + s * u1)]


def pult(u0, u1, v0, v1):
    """Schnittlinie für eine schräge Oberkante (Pultdach): Höhe v0 bei u0, v1 bei u1."""
    s = (v1 - v0) / (u1 - u0)
    return [(-s, 1.0, v0 - s * u0)]


def _emit(p, pl, r, out, th, color, lines, side=0.78):
    if lines:
        pts = [(r[0], r[1]), (r[2], r[1]), (r[2], r[3]), (r[0], r[3])]
        for (a, b, c) in lines:
            pts = _clip(pts, a, b, c)
            if len(pts) < 3:
                return
        area = 0.0
        for i in range(len(pts)):
            q = pts[(i + 1) % len(pts)]
            area += pts[i][0] * q[1] - q[0] * pts[i][1]
        if area * 0.5 < 0.004:
            return
        slab(p, pl, pts, out, th, color, side)
    else:
        tile(p, pl, r[0], r[1], r[2], r[3], out, th, color, side)


def clad(p, pl, style, color, u0=0.0, u1=None, v0=0.0, v1=None, holes=(), out=0.06, lines=None, amt=0.06, size=None, color2=None):
    """Verkleidet eine Wandfläche mit erkennbarem Baustoff.
    style: plank_v (senkrechte Bretter), plank_h (waagerechte Bretter), brick (Ziegelreihen), stone (Quader),
           panel (Betonplatten mit Nieten), blech (Wellblech-Rippen), putz (glatte Putzfläche).
    holes: ausgesparte Rechtecke (u0, v0, u1, v1) für Tür und Fenster. lines: schräge Oberkanten (giebel(), pult())."""
    u1 = pl.len if u1 is None else u1
    v1 = pl.h if v1 is None else v1
    W, H = u1 - u0, v1 - v0
    if W <= 0.02 or H <= 0.02:
        return
    rects = []      # (rect, farbe, out)
    if style == "plank_v":
        bw = size or 0.3
        n = max(1, round(W / bw)); bw = W / n
        for i in range(n):
            o = out + RNG.uniform(-0.012, 0.012)
            rects.append(((u0 + i * bw + 0.012, v0, u0 + (i + 1) * bw - 0.012, v1), jit(color, amt), o))
    elif style == "plank_h":
        bh = size or 0.27
        n = max(1, round(H / bh)); bh = H / n
        for i in range(n):
            o = out + RNG.uniform(-0.01, 0.01)
            # lange Bretter mit einem versetzten Stoß
            js = u0 + W * RNG.uniform(0.3, 0.7) if W > 2.4 else None
            segs = [(u0, js), (js, u1)] if js else [(u0, u1)]
            for (a, b) in segs:
                rects.append(((a + 0.01, v0 + i * bh + 0.012, b - 0.01, v0 + (i + 1) * bh - 0.012), jit(color, amt), o))
    elif style in ("brick", "stone"):
        bh = size or (0.2 if style == "brick" else 0.36)
        bl = bh * 2.3 if style == "brick" else bh * 1.95
        g = 0.016 if style == "brick" else 0.022
        n = max(1, round(H / bh)); bh = H / n
        for i in range(n):
            x = u0 - (bl * 0.5 if i % 2 else 0.0)
            while x < u1 - 0.01:
                l = bl if style == "brick" else bl * RNG.uniform(0.7, 1.3)
                a, b = max(x, u0), min(x + l, u1)
                if u1 - b < 0.12:
                    b = u1
                if b - a > 0.05:
                    cc = jit(color, amt)
                    if color2 and RNG.random() < 0.14:
                        cc = jit(color2, amt)
                    rects.append(((a + g, v0 + i * bh + g, b - g, v0 + (i + 1) * bh - g), cc, out + RNG.uniform(-0.01, 0.01)))
                x = b if b == u1 else x + l
    elif style == "panel":
        pw = size or 1.25
        nx = max(1, round(W / pw)); pw = W / nx
        ny = max(1, round(H / 1.05)); ph = H / ny
        for j in range(ny):
            for i in range(nx):
                rects.append(((u0 + i * pw + 0.025, v0 + j * ph + 0.025, u0 + (i + 1) * pw - 0.025, v0 + (j + 1) * ph - 0.025), jit(color, amt * 0.7), out))
    elif style == "blech":
        bw = size or 0.2
        n = max(2, round(W / bw)); bw = W / n
        for i in range(n):
            hi = i % 2 == 0
            cc = jit(color, amt * 0.5)
            rects.append(((u0 + i * bw, v0, u0 + (i + 1) * bw, v1), cc if hi else shade(cc, 0.8), out if hi else out - 0.035))
    else:   # putz
        rects.append(((u0, v0, u1, v1), color, out))
    for (r, cc, o) in rects:
        for q in cut([r], holes):
            _emit(p, pl, q, o, o + 0.02 if style != "blech" else 0.05, cc, lines)
            if style == "panel" and not lines and q[2] - q[0] > 0.5 and q[3] - q[1] > 0.5:
                for (du, dv) in ((0.1, 0.1), (-0.1, 0.1), (0.1, -0.1), (-0.1, -0.1)):
                    stud(p, pl, (q[0] if du > 0 else q[2]) + du, (q[1] if dv > 0 else q[3]) + dv, o, 0.04, shade(cc, 1.25))


def ecken(p, H, color=WOOD_D, w=0.2, out=0.1, style="balken", v1=None, sides="frbl", amt=0.05):
    """Eckbalken (style balken) oder Ecksteine (style stein) an den vier Hauskanten."""
    v1 = H.h if v1 is None else v1
    for (x, y, k) in ((H.x0, H.y0, "fl"), (H.x1, H.y0, "fr"), (H.x1, H.y1, "br"), (H.x0, H.y1, "bl")):
        if k[0] not in sides and k[1] not in sides:
            continue
        sx = 1 if x == H.x0 else -1
        sy = 1 if y == H.y0 else -1
        if style == "balken":
            p.box((w, w, v1), (x + sx * (w / 2 - out), y + sy * (w / 2 - out), H.z0 + v1 / 2), jit(color, amt))
        else:
            n = max(2, round(v1 / 0.4)); bh = v1 / n
            for i in range(n):
                lx, ly = (0.5, 0.32) if i % 2 else (0.32, 0.5)
                p.box((lx + out, ly + out, bh - 0.03), (x + sx * (lx - out) / 2, y + sy * (ly - out) / 2, H.z0 + (i + 0.5) * bh), jit(color, amt), bevel=0.03, segs=1)


def fachwerk(p, pl, u0, u1, v0, v1, color=WOOD_D, out=0.1, w=0.16, posts=(), diag=(), rails=()):
    """Fachwerk-Balken auf einer Wand: Rahmen, Pfosten (u), Riegel (v) und Streben ((ua, va, ub, vb))."""
    tile(p, pl, u0, v0, u1, v0 + w, out, out, jit(color, 0.05))
    tile(p, pl, u0, v1 - w, u1, v1, out, out, jit(color, 0.05))
    for u in (u0 + w / 2, u1 - w / 2) + tuple(posts):
        tile(p, pl, u - w / 2, v0, u + w / 2, v1, out + 0.01, out, jit(color, 0.05))
    for v in rails:
        tile(p, pl, u0, v - w / 2, u1, v + w / 2, out - 0.005, out, jit(color, 0.05))
    for (ua, va, ub, vb) in diag:
        d = Vector((ub - ua, vb - va)); l = d.length
        nx, ny = -d.y / l * w / 2, d.x / l * w / 2
        slab(p, pl, [(ua - nx, va - ny), (ub - nx, vb - ny), (ub + nx, vb + ny), (ua + nx, va + ny)], out - 0.01, out, jit(color, 0.05))


# ---------------------------------------------------------------- Fundament
def fundament(p, w, d, h=0.25, c=(0.0, 0.0), color=PAVE, ts=0.92, skip=(), mortar=MORTAR, style="stein", amt=0.06):
    """Stein- oder Bretterplatte mit sichtbaren Fugen. skip: Rechtecke (x0, y0, x1, y1), unter denen nichts zu sehen ist."""
    cx, cy = c
    p.box((w, d, h - 0.05), (cx, cy, (h - 0.05) / 2), mortar, bevel=0.04, segs=1)
    pl = boden(cx - w / 2, cy - d / 2, h - 0.05)
    holes = [(a - (cx - w / 2), b - (cy - d / 2), a2 - (cx - w / 2), b2 - (cy - d / 2)) for (a, b, a2, b2) in skip]
    if style == "stein":
        ny = max(1, round(d / ts)); th = d / ny
        for j in range(ny):
            x = -(ts * 0.5 if j % 2 else 0.0)
            while x < w - 0.01:
                l = ts * RNG.uniform(0.8, 1.2)
                a, b = max(x, 0.0), min(x + l, w)
                if w - b < 0.2:
                    b = w
                for q in cut([(a + 0.02, j * th + 0.02, b - 0.02, (j + 1) * th - 0.02)], holes):
                    tile(p, pl, q[0], q[1], q[2], q[3], 0.05 + RNG.uniform(-0.008, 0.008), 0.06, jit(color, amt), 0.7)
                x = b if b == w else x + l
    else:
        n = max(1, round(w / 0.34)); bw = w / n
        for i in range(n):
            for q in cut([(i * bw + 0.015, 0.0, (i + 1) * bw - 0.015, d)], holes):
                tile(p, pl, q[0], q[1], q[2], q[3], 0.05 + RNG.uniform(-0.008, 0.008), 0.06, jit(color, amt), 0.7)


def stufe(p, x, y, w=1.9, d=0.5, h=0.13, color=ST_L, yaw=0.0):
    """Stufe vor der Tür (Mitte x, y; liegt auf dem Boden)."""
    a = At(p, T(x, y, 0) @ rot(0, 0, yaw))
    a.box((w, d, h), (0, 0, h / 2), color, bevel=0.03, segs=1)


def schwelle(p, pl, u, w=1.7, d=0.42, h=0.1, color=ST_L, v=0.0):
    """Türschwelle/Stufe direkt vor einer Wandöffnung."""
    At(p, pl.M(u, v, 0)).box((w, d, h), (0, -d / 2, h / 2), color, bevel=0.03, segs=1)


# ---------------------------------------------------------------- Dach
class Dach:
    pass


def dach(p, c, L, span, h, color, over=0.4, over_g=0.3, yaw=0.0, style="ziegel", trim=CREAM, rinne=True, fallrohr=True,
         ridge=None, tw=0.5, row=0.46, ground=0.0, amt=0.06, under=None):
    """Satteldach mit Ziegel-/Blech-/Bretterreihen, First, Ortgang und Dachrinne.
    c = Mitte in Traufhöhe, L = Firstlänge, span = Spannweite, h = Dachhöhe. yaw=90: First entlang Y.
    style: ziegel, blech, brett. Liefert ein Dach-Objekt (planes, base, ...), um Aufbauten und Flicken zu setzen."""
    base = T(*c) @ rot(0, 0, yaw)
    pitch = math.atan2(h, span * 0.5)
    cs, sn = math.cos(pitch), math.sin(pitch)
    SL = math.hypot(span * 0.5, h) + over
    LW = L + over_g * 2
    R = Dach()
    R.base, R.pitch, R.SL, R.LW, R.L, R.span, R.h, R.c, R.over = base, pitch, SL, LW, L, span, h, c, over
    R.planes = []
    und = under or shade(color, 0.5)
    a = At(p, base)
    for sgn in (-1, 1):
        ex = Vector((-sgn, 0, 0))
        ey = Vector((0, -sgn * cs, sn))
        o = Vector((sgn * LW / 2, sgn * span / 2, 0)) - ey * over
        pl = Plane(o, ex, ey, LW, SL).moved(base)
        R.planes.append(pl)
        tile(p, pl, 0.0, 0.0, LW, SL, 0.05, 0.16, und, 0.9)
        if style == "ziegel":
            n = max(2, round(SL / row)); rl = SL / n
            m = max(2, round(LW / tw)); w = LW / m
            for k in range(n):
                off = w * 0.5 if k % 2 else 0.0
                x = -off
                while x < LW - 0.01:
                    u0, u1 = max(x, 0.0), min(x + w, LW)
                    if u1 - u0 > 0.04:
                        wedge(p, pl, u0 + 0.012, k * rl, u1 - 0.012, min((k + 1) * rl + 0.05, SL), 0.15, 0.075, 0.04, jit(color, amt))
                    x += w
        elif style == "blech":
            m = max(2, round(LW / 0.62)); w = LW / m
            for i in range(m):
                cc = jit(color, amt * 0.6)
                wedge(p, pl, i * w + 0.01, 0.0, (i + 1) * w - 0.01, SL * 0.52, 0.115, 0.085, 0.04, cc)
                wedge(p, pl, i * w + 0.01, SL * 0.5, (i + 1) * w - 0.01, SL, 0.1, 0.07, 0.04, shade(cc, 0.96))
            for i in range(m + 1):
                u = min(max(i * w, 0.04), LW - 0.04)
                tile(p, pl, u - 0.04, 0.0, u + 0.04, SL, 0.16, 0.08, shade(color, 0.8), 0.85)
        else:   # brett
            m = max(2, round(LW / 0.36)); w = LW / m
            for i in range(m):
                d0 = RNG.uniform(-0.04, 0.02)
                tile(p, pl, i * w + 0.015, d0 * 0 - 0.0, (i + 1) * w - 0.015, SL, 0.1 + RNG.uniform(-0.012, 0.012), 0.07, jit(color, amt))
        if rinne:
            g0, g1 = pl.pt(0.02, -0.03, -0.04), pl.pt(LW - 0.02, -0.03, -0.04)
            tube(p, g0, g1, 0.085, STEEL_D, sides=6)
    rc = ridge or shade(color, 0.72)
    a.cyl(0.14, LW + 0.08, (0, 0, h + 0.1), rc, r=rot(0, 90, 0), sides=6)
    n = max(2, round(LW / 0.6))
    for i in range(n + 1):
        a.cyl(0.17, 0.1, (min(max(-LW / 2 + i * LW / n, -LW / 2 + 0.03), LW / 2 - 0.03), 0, h + 0.1), shade(rc, 0.85), r=rot(0, 90, 0), sides=6)
    if trim:
        for sx in (-1, 1):
            for sgn in (-1, 1):
                ey = Vector((0, -sgn * cs, sn))
                e0 = Vector((sx * (LW / 2 + 0.02), sgn * span / 2, 0)) - ey * (over + 0.02) + Vector((0, 0, -0.02))
                e1 = Vector((sx * (LW / 2 + 0.02), 0, h - 0.02))
                c0, l0, m0 = _track(e0, e1)
                a.box((0.07, 0.24, l0), c0, trim, r=m0)
    if rinne and fallrohr:
        fx = LW / 2 - 0.14
        zt = -over * sn - 0.06
        zg = ground - c[2]
        tube(a, (fx, -(span / 2 + over * cs + 0.02), zt), (fx, -(span / 2 + 0.13), zt - 0.3), 0.055, STEEL_D, sides=6)
        a.cyl(0.055, zt - 0.3 - zg, (fx, -(span / 2 + 0.13), (zt - 0.3 + zg) / 2), STEEL_D, sides=6)
    return R


def dach_z(R, dy):
    """Höhe der Dachoberfläche (Welt-Z) im Abstand dy vom First (lokal, quer zum First)."""
    return R.c[2] + R.h - abs(dy) * R.h / (R.span * 0.5) + 0.12


def dach_pos(R, dx, dy, dz=0.0):
    """Weltpunkt auf dem Dach: dx entlang des Firsts, dy quer dazu (von der Mitte)."""
    v = R.base @ Vector((dx, dy, R.h - abs(dy) * R.h / (R.span * 0.5) + 0.12 + dz))
    return (v.x, v.y, v.z)


def flicken(p, pl, u, v, w=0.7, h=0.6, color=WOOD_P, out=0.19, ang=8.0):
    """Flicken (Brett/Blechstück) auf einer Dach- oder Wandfläche, leicht schief."""
    a = math.radians(ang)
    pts = []
    for (du, dv) in ((-w / 2, -h / 2), (w / 2, -h / 2), (w / 2, h / 2), (-w / 2, h / 2)):
        pts.append((u + du * math.cos(a) - dv * math.sin(a), v + du * math.sin(a) + dv * math.cos(a)))
    slab(p, pl, pts, out, 0.05, color)
    for q in pts:
        stud(p, pl, u + (q[0] - u) * 0.8, v + (q[1] - v) * 0.8, out, 0.03, STEEL_D, 0.02)


def pultdach(p, c, w, d, h, color, over=0.3, yaw=0.0, style="blech", amt=0.06, rinne=True, under=None):
    """Pultdach: Mitte c in Höhe der unteren Kante; Breite w (lokal X), Tiefe d (lokal Y), steigt nach +Y um h."""
    base = T(*c) @ rot(0, 0, yaw)
    pitch = math.atan2(h, d)
    cs, sn = math.cos(pitch), math.sin(pitch)
    SL = math.hypot(d, h) + over * 2
    LW = w + over * 2
    ey = Vector((0, cs, sn))
    o = Vector((-LW / 2, -d / 2, 0)) - ey * over
    pl = Plane(o, (1, 0, 0), ey, LW, SL).moved(base)
    tile(p, pl, 0, 0, LW, SL, 0.04, 0.12, under or shade(color, 0.5), 0.9)
    if style == "blech":
        m = max(2, round(LW / 0.3)); bw = LW / m
        for i in range(m):
            hi = i % 2 == 0
            cc = jit(color, amt * 0.6)
            tile(p, pl, i * bw, 0.0, (i + 1) * bw, SL, 0.1 if hi else 0.065, 0.06, cc if hi else shade(cc, 0.82), 0.85)
    elif style == "ziegel":
        n = max(2, round(SL / 0.46)); rl = SL / n
        m = max(2, round(LW / 0.5)); tw = LW / m
        for k in range(n):
            x = -(tw * 0.5 if k % 2 else 0.0)
            while x < LW - 0.01:
                u0, u1 = max(x, 0.0), min(x + tw, LW)
                if u1 - u0 > 0.04:
                    wedge(p, pl, u0 + 0.012, k * rl, u1 - 0.012, min((k + 1) * rl + 0.05, SL), 0.14, 0.07, 0.03, jit(color, amt))
                x += tw
    else:
        m = max(2, round(LW / 0.36)); bw = LW / m
        for i in range(m):
            tile(p, pl, i * bw + 0.015, 0.0, (i + 1) * bw - 0.015, SL, 0.09 + RNG.uniform(-0.012, 0.012), 0.06, jit(color, amt))
    if rinne:
        tube(p, pl.pt(0.02, -0.03, -0.03), pl.pt(LW - 0.02, -0.03, -0.03), 0.075, STEEL_D, sides=6)
    return pl


def schornstein(M, p, loc, h=1.3, w=0.5, color=BRICK, fx="fx_smoke", rund=False):
    """Gemauerter Schornstein mit Ziegelreihen und Abdeckung; Leerobjekt fx für Rauch."""
    x, y, z = loc
    if rund:
        p.cyl(w / 2, h, (x, y, z + h / 2), color, sides=10, r2=w * 0.43)
        p.cyl(w / 2 + 0.05, 0.14, (x, y, z + h - 0.05), shade(color, 0.7), sides=10)
    else:
        p.box((w - 0.04, w - 0.04, h), (x, y, z + h / 2), shade(color, 0.55))
        hh = Haus(x, y, w, w, z, h - 0.12)
        for s in "frbl":
            clad(p, hh.W(s), "brick", color, out=0.02, size=0.2)
        p.box((w + 0.14, w + 0.14, 0.14), (x, y, z + h - 0.05), ST_D, bevel=0.03, segs=1)
    p.cyl(w * 0.3, 0.05, (x, y, z + h + 0.03), "181A22", sides=8)
    if fx:
        M.empty(fx, (x, y, z + h + 0.15))


# ---------------------------------------------------------------- Tür, Tor, Fenster, Lampe
def tuer(p, pl, u, v=0.0, w=1.4, h=2.6, color=WOOD, frame=WOOD_D, knob=GOLD, fw=0.14, luke=False):
    """Brettertür mit Rahmen, Querriegeln und Griff. u = Mitte, v = Unterkante. Liefert die Aussparung für clad()."""
    a = At(p, pl.M(u, v, 0))
    a.box((w, 0.1, h), (0, 0.0, h / 2), shade(color, 0.6))
    n = 4
    for i in range(n):
        bw = w / n
        tile(p, pl, u - w / 2 + i * bw + 0.012, v + 0.02, u - w / 2 + (i + 1) * bw - 0.012, v + h - 0.02, 0.085, 0.04, jit(color, 0.07))
    for z in (0.5, h - 0.5):
        a.box((w - 0.08, 0.05, 0.16), (0, -0.1, z), shade(color, 0.78))
    a.box((0.09, 0.05, math.hypot(w - 0.2, h - 1.16)), (0.0, -0.1, h / 2), shade(color, 0.78), r=rot(0, math.degrees(math.atan2(w - 0.2, h - 1.16)), 0))
    a.ball(0.075, (w / 2 - 0.2, -0.16, h * 0.45), knob, subdiv=1)
    a.box((0.05, 0.03, 0.22), (w / 2 - 0.2, -0.12, h * 0.45), shade(knob, 0.7))
    if luke:
        a.box((0.5, 0.05, 0.4), (0, -0.11, h - 0.75), DK)
    # Rahmen
    a.box((fw, 0.26, h + fw), (-w / 2 - fw / 2, -0.07, (h + fw) / 2), frame)
    a.box((fw, 0.26, h + fw), (w / 2 + fw / 2, -0.07, (h + fw) / 2), frame)
    a.box((w + fw * 2 + 0.12, 0.3, fw + 0.02), (0, -0.07, h + fw / 2), shade(frame, 1.12))
    return (u - w / 2 - fw, v, u + w / 2 + fw, v + h + fw)


def fenster(p, g, pl, u, v, w=0.9, h=1.0, frame=CREAM, laden=None, kasten=False, kreuz=True, bank=True, fw=0.1, glow=GLOW):
    """Fenster mit Rahmen, Kreuz und Bank; Scheibe im Leucht-Teil g. u = Mitte, v = Unterkante. Liefert die Aussparung."""
    a = At(p, pl.M(u, v, 0))
    At(g, pl.M(u, v, 0)).box((w, 0.06, h), (0, -0.045, h / 2), glow)
    a.box((fw, 0.2, h + fw * 2), (-w / 2 - fw / 2, -0.06, h / 2), frame)
    a.box((fw, 0.2, h + fw * 2), (w / 2 + fw / 2, -0.06, h / 2), frame)
    a.box((w + fw * 2, 0.2, fw), (0, -0.06, h + fw / 2), frame)
    a.box((w + fw * 2, 0.2, fw), (0, -0.06, -fw / 2), frame)
    if kreuz:
        a.box((0.055, 0.07, h), (0, -0.1, h / 2), frame)
        a.box((w, 0.07, 0.055), (0, -0.1, h * 0.56), frame)
    if bank:
        a.box((w + fw * 2 + 0.2, 0.3, 0.07), (0, -0.14, -fw - 0.035), shade(frame, 0.82))
    if laden:
        for s in (-1, 1):
            x = s * (w / 2 + fw + w * 0.24 + 0.02)
            a.box((w * 0.46, 0.06, h + 0.08), (x, -0.1, h / 2), laden)
            for k in (0.25, 0.75):
                a.box((w * 0.46 + 0.02, 0.04, 0.07), (x, -0.14, h * k), shade(laden, 0.75))
    if kasten:
        a.box((w + 0.25, 0.26, 0.2), (0, -0.3, -fw - 0.16), WOOD)
        cols = (RED, GOLD, "F48BB0", "white", PURPLE)
        n = 5
        for i in range(n):
            x = -w / 2 + (i + 0.5) * w / n
            a.ball(0.11, (x, -0.3, -fw - 0.02), jit("5E9A3A", 0.1), subdiv=1)
            a.ball(0.07, (x + 0.02, -0.33, -fw + 0.09), cols[i % len(cols)], subdiv=1)
    ext = (w * 0.5 if laden else 0.0)
    return (u - w / 2 - fw - ext, v - fw - (0.07 if bank else 0), u + w / 2 + fw + ext, v + h + fw)


def lampe(p, g, pl, u, v, color=DK, arm=0.3):
    """Wandlampe: Arm und Schirm in p, Birne im Leucht-Teil g."""
    a = At(p, pl.M(u, v, 0))
    a.box((0.07, arm, 0.07), (0, -arm / 2, 0.2), color)
    a.box((0.12, 0.05, 0.3), (0, -0.03, 0.12), color)
    a.cyl(0.21, 0.16, (0, -arm, 0.1), color, r2=0.07, sides=8)
    At(g, pl.M(u, v, 0)).ball(0.12, (0, -arm, -0.02), GLOW, subdiv=1)


def laterne(p, g, x, y, z=0.0, h=2.3, color=DK):
    """Stehende Laterne."""
    p.cyl(0.13, 0.16, (x, y, z + 0.08), color, sides=8)
    p.cyl(0.055, h, (x, y, z + h / 2), color, sides=6)
    p.box((0.34, 0.34, 0.06), (x, y, z + h), color)
    for sx in (-1, 1):
        for sy in (-1, 1):
            p.box((0.035, 0.035, 0.3), (x + sx * 0.13, y + sy * 0.13, z + h + 0.17), color)
    p.cyl(0.26, 0.16, (x, y, z + h + 0.39), color, r2=0.05, sides=4, r=rot(0, 0, 45))
    g.box((0.22, 0.22, 0.26), (x, y, z + h + 0.17), GLOW)


def schild(p, pl, u, v, w=1.0, h=0.45, color=WOOD_L, rand=WOOD_D, out=0.0):
    """Schildbrett an der Wand; liefert ein At für Zeichen darauf (lokal: x rechts, z hoch, -y nach vorn)."""
    a = At(p, pl.M(u, v, out))
    a.box((w + 0.1, 0.07, h + 0.1), (0, -0.05, 0), rand)
    a.box((w, 0.07, h), (0, -0.08, 0), color)
    return At(a, T(0, -0.13, 0))


# ---------------------------------------------------------------- Kleinteile
def crate(p, loc, s=0.8, color=WOOD, yaw=0.0, band=None):
    """Holzkiste mit Leisten."""
    x, y, z = loc
    a = At(p, T(x, y, z) @ rot(0, 0, yaw))
    c = jit(color, 0.07)
    a.box((s, s, s), (0, 0, s / 2), c)
    e = s * 0.11
    cd = shade(c, 0.72) if band is None else band
    for sx in (-1, 1):
        for sy in (-1, 1):
            a.box((e, e, s + 0.02), (sx * (s - e + 0.03) / 2, sy * (s - e + 0.03) / 2, s / 2), cd)
    for zz in (e / 2, s - e / 2):
        a.box((s + 0.03, s + 0.03, e), (0, 0, zz), cd)


def barrel(p, loc, color=RED, r=0.34, h=0.9, sides=10):
    x, y, z = loc
    p.cyl(r, h, (x, y, z + h * 0.5), color, sides=sides, bevel=0.05, segs=1)
    for k in (0.28, 0.72):
        p.cyl(r + 0.025, 0.08, (x, y, z + h * k), shade(color, 0.68), sides=sides)
    p.cyl(r * 0.7, 0.03, (x, y, z + h), shade(color, 1.25), sides=sides)


def sack(p, loc, color=SACK, yaw=0.0, s=1.0, lie=False):
    x, y, z = loc
    if lie:
        p.ball(0.3 * s, (x, y, z + 0.17 * s), jit(color, 0.07), r=rot(0, 0, yaw), scale=(1.5, 0.95, 0.6), subdiv=2)
    else:
        p.ball(0.3 * s, (x, y, z + 0.32 * s), jit(color, 0.07), scale=(1.0, 0.9, 1.15), subdiv=2)
        p.cyl(0.1 * s, 0.14 * s, (x, y, z + 0.7 * s), shade(color, 0.8), sides=6, r2=0.14 * s)


def sandbags(p, a, dx, dy, n, rows=2, color=SACK):
    yaw = math.degrees(math.atan2(dy, dx))
    for r in range(rows):
        for i in range(n - r):
            k = i * 0.62 + r * 0.31
            p.box((0.64, 0.4, 0.3), (a[0] + dx * k, a[1] + dy * k, 0.15 + r * 0.26 + a[2]), jit(color, 0.08), r=rot(0, 0, yaw), bevel=0.11, segs=1)


def stamm(p, a, b, r=0.26, bark="8A5030", cutc="E8C088", sides=9):
    """Baumstamm von a nach b mit hellen Schnittflächen."""
    c, l, m = _track(a, b)
    p.cyl(r, l, c, jit(bark, 0.08), r=m, sides=sides)
    p.cyl(r * 0.8, l + 0.03, c, cutc, r=m, sides=sides)


def bretter(p, loc, n=4, length=1.7, w=0.9, color=WOOD_L, yaw=0.0, th=0.11):
    """Bretterstapel (n Lagen)."""
    x, y, z = loc
    for i in range(n):
        a = At(p, T(x, y, z + i * (th + 0.02)) @ rot(0, 0, yaw + RNG.uniform(-3, 3)))
        for k in range(3):
            a.box((length + RNG.uniform(-0.1, 0.1), w / 3 - 0.03, th), (RNG.uniform(-0.05, 0.05), (k - 1) * w / 3, th / 2), jit(color, 0.08))


def star(p, loc, rad, color="white", thick=0.05):
    """Fünfzackiger Stern in der XZ-Ebene (zeigt nach vorn und hinten)."""
    x, y, z = loc
    rp = rad / 1.83
    p.cyl(rp, thick, loc, color, r=rot(90, 0, 0) @ rot(0, 0, 36), sides=5)
    for i in range(5):
        a = math.radians(90 + 72 * i)
        p.cyl(rp * 0.68, thick, (x + math.cos(a) * rp * 1.15, y, z + math.sin(a) * rp * 1.15), color,
              r=rot(90, 0, 0) @ rot(0, 0, 72 * i), sides=3)


def fahne(M, p, loc, h=2.6, name="sway_flag", size=(1.15, 0.78), with_star=True, pole=WOOD_D, yaw=0.0):
    """Mast in p, Tuch als eigenes sway-Objekt in der Flaggenfarbe (bekommt im Spiel die Farbe des Spielers)."""
    x, y, z = loc
    p.cyl(0.06, h, (x, y, z + h * 0.5), pole, sides=6)
    p.ball(0.11, (x, y, z + h + 0.05), GOLD, subdiv=1)
    w, hh = size
    org = (x, y, z + h - hh * 0.5 - 0.08)
    M.origin(name, org, (0, 0, math.radians(yaw)), local=True)
    c = M[name]
    c.box((w * 0.52, 0.05, hh), (0.06 + w * 0.27, 0, 0), "flag", bevel=0.02, segs=1)
    c.box((w * 0.52, 0.05, hh * 0.94), (0.06 + w * 0.74, -0.04, -0.03), "flag", bevel=0.02, segs=1, r=rot(0, 0, -8))
    if with_star:
        star(c, (0.06 + w * 0.42, 0, 0), hh * 0.3, "white", 0.09)


def banner(M, name, loc, w=0.85, h=1.9, yaw=0.0, zeichen=True):
    """Hängendes Banner (sway-Objekt, Ursprung oben an der Stange) in der Flaggenfarbe."""
    M.origin(name, loc, (0, 0, math.radians(yaw)), local=True)
    c = M[name]
    c.cyl(0.05, w + 0.3, (0, 0, 0), GOLD, r=rot(0, 90, 0), sides=6)
    c.box((w, 0.05, h), (0, 0, -h / 2), "flag")
    c.cyl(w * 0.5, 0.05, (0, 0, -h), "flag", r=rot(90, 0, 0) @ rot(0, 0, 0), sides=3)
    c.box((w, 0.07, 0.12), (0, 0, -0.14), GOLD)
    if zeichen:
        star(c, (0, -0.02, -h * 0.5), w * 0.3, "white", 0.09)


def gear(p, rad, thick, color, teeth=10, hub=DK):
    """Zahnrad um die lokale Z-Achse im Ursprung."""
    p.cyl(rad, thick, (0, 0, 0), color, sides=16)
    for i in range(teeth):
        a = 360.0 * i / teeth
        p.box((rad * 0.34, rad * 0.3, thick), (math.cos(math.radians(a)) * rad * 1.08, math.sin(math.radians(a)) * rad * 1.08, 0), color, r=rot(0, 0, a))
    p.cyl(rad * 0.62, thick + 0.04, (0, 0, 0), shade(color, 0.72), sides=12)
    p.cyl(rad * 0.24, thick + 0.12, (0, 0, 0), hub, sides=8)


def leiter(p, a, b, w=0.45, color=WOOD_L, step=0.34, th=0.06):
    """Leiter von a (unten) nach b (oben)."""
    a = Vector(a); b = Vector(b)
    d = b - a
    side = Vector((d.y, -d.x, 0))
    if side.length < 1e-4:
        side = Vector((1, 0, 0))
    side = side.normalized() * w / 2
    beam(p, a - side, b - side, th, color)
    beam(p, a + side, b + side, th, color)
    n = int(d.length / step)
    for i in range(1, n + 1):
        q = a + d * (i / (n + 1))
        beam(p, q - side, q + side, th * 0.8, shade(color, 0.85))


def fass_liegend(p, loc, color=RED, r=0.34, h=0.9, yaw=0.0):
    x, y, z = loc
    a = At(p, T(x, y, z + r) @ rot(0, 0, yaw) @ rot(0, 90, 0))
    a.cyl(r, h, (0, 0, 0), color, sides=10)
    for k in (-0.22, 0.22):
        a.cyl(r + 0.025, 0.08, (0, 0, h * k), shade(color, 0.68), sides=10)


def reifen(p, loc, n=3, r=0.36):
    x, y, z = loc
    for i in range(n):
        p.torus(r - 0.13, 0.13, (x + RNG.uniform(-0.03, 0.03), y + RNG.uniform(-0.03, 0.03), z + 0.13 + i * 0.25), "tire", seg=12, tseg=6)


def warnstreifen(p, pl, u0, u1, v0, v1, out=0.1, n=None, c1=GOLD, c2="22252E"):
    """Schräge gelb-schwarze Warnstreifen als flache Platten."""
    W = u1 - u0
    n = n or max(2, round(W / 0.3))
    w = W / n
    k = (v1 - v0) * 0.7
    for i in range(-1, n):
        a, b = u0 + i * w, u0 + (i + 1) * w
        pts = [(a, v0), (b, v0), (b + k, v1), (a + k, v1)]
        pts = _clip(_clip(pts, 1.0, 0.0, u1), -1.0, 0.0, -u0)
        if len(pts) >= 3:
            slab(p, pl, pts, out, 0.03, c1 if i % 2 == 0 else c2)


def kabel(p, a, b, sag=0.4, rad=0.03, color="22252E", n=6):
    """Durchhängendes Kabel/Seil von a nach b."""
    a = Vector(a); b = Vector(b)
    pts = []
    for i in range(n + 1):
        t = i / n
        q = a + (b - a) * t
        q.z -= sag * 4 * t * (1 - t)
        pts.append(q)
    for i in range(n):
        tube(p, pts[i], pts[i + 1], rad, color, sides=4)


# ---------------------------------------------------------------- Gebrauchsspuren und Schaden
def moos(p, pl, u, n=4, w=0.9, color=MOSS, out=0.08):
    """Moos am Sockel einer Wand."""
    for i in range(n):
        q = pl.pt(u + RNG.uniform(-w / 2, w / 2), RNG.uniform(0.02, 0.2), out)
        p.ball(RNG.uniform(0.12, 0.2), q, jit(color, 0.12), scale=(1.2, 1.2, 0.7), subdiv=1)


def fleck(p, x, y, z, r=0.5, color="2B2A30", n=7):
    """Flacher Fleck am Boden (Ölfleck, Pfütze, Sägemehl)."""
    pl = boden(x, y, z)
    pts = []
    for i in range(n):
        a = 2 * math.pi * i / n
        rr = r * RNG.uniform(0.65, 1.1)
        pts.append((math.cos(a) * rr, math.sin(a) * rr * 0.8))
    slab(p, pl, pts, 0.012, 0.0, color)


def riss(p, pl, u, v, size=1.0, out=0.14, color=CRACK, w=0.045):
    """Gezackter Riss auf einer Wand (für dmg1_*)."""
    pts = [(u, v)]
    ang = RNG.uniform(60, 120)
    for i in range(5):
        a = math.radians(ang + RNG.uniform(-55, 55))
        q = pts[-1]
        nu = q[0] + math.cos(a) * size / 5
        if pl.len > 0.5:                                    # der Riss bleibt auf der Wand
            nu = min(max(nu, 0.12), pl.len - 0.3)
        pts.append((nu, q[1] + math.sin(a) * size / 5))
    for i in range(5):
        a, b = pts[i], pts[i + 1]
        d = Vector((b[0] - a[0], b[1] - a[1])); l = d.length
        ww = w * (1.0 - i * 0.15)
        nx, ny = -d.y / l * ww, d.x / l * ww
        slab(p, pl, [(a[0] - nx, a[1] - ny), (b[0] - nx * 0.8, b[1] - ny * 0.8), (b[0] + nx * 0.8, b[1] + ny * 0.8), (a[0] + nx, a[1] + ny)], out, 0.0, color)
        if i == 2:
            c2 = (min(b[0] + size * 0.22, pl.len - 0.1) if pl.len > 0.5 else b[0] + size * 0.22, b[1] - size * 0.08)
            slab(p, pl, [(b[0], b[1] - ww), (c2[0], c2[1]), (b[0], b[1] + ww)], out, 0.0, color)


def russ(p, pl, u, v, r=0.5, out=0.13, color=SOOT):
    """Rußfleck (für dmg1_*): unregelmäßiges dunkles Vieleck, nach oben ausgezogen."""
    for (k, cc, o) in ((1.0, color, out), (0.55, shade(color, 0.6), out + 0.006)):
        pts = []
        n = 8
        for i in range(n):
            a = 2 * math.pi * i / n
            rr = r * k * RNG.uniform(0.7, 1.1)
            pts.append((u + math.cos(a) * rr * 0.8, v + math.sin(a) * rr * (1.35 if math.sin(a) > 0 else 0.8)))
        slab(p, pl, pts, o, 0.0, cc)


def loch(p, pl, u, v, r=0.45, out=0.15, splitter=WOOD_D):
    """Loch in Wand oder Dach (für dmg2_*): schwarzes Vieleck mit abgebrochenen Brettern am Rand."""
    pts = []
    n = 7
    for i in range(n):
        a = 2 * math.pi * i / n
        rr = r * RNG.uniform(0.7, 1.15)
        pts.append((u + math.cos(a) * rr, v + math.sin(a) * rr))
    slab(p, pl, pts, out, 0.0, "0E0D10")
    for i in range(4):
        a = 2 * math.pi * (i + RNG.random()) / 4
        cu, cv = u + math.cos(a) * r * 0.95, v + math.sin(a) * r * 0.95
        w, h = 0.13, r * 0.9
        ca, sa = math.cos(a + 0.5), math.sin(a + 0.5)
        q = [(cu + (du * ca - dv * sa), cv + (du * sa + dv * ca)) for (du, dv) in ((-h / 2, -w / 2), (h / 2, -w / 2), (h / 2, w / 2), (-h / 2, w / 2))]
        slab(p, pl, q, out + 0.03, 0.04, jit(splitter, 0.1))


def stuetze(p, a, b, w=0.16, color=WOOD_L):
    """Stützbalken von a (Boden) schräg nach b (Wand), mit Fußklotz."""
    beam(p, a, b, w, color)
    p.box((0.5, 0.3, 0.14), (a[0], a[1], a[2] + 0.02), shade(color, 0.75), r=rot(0, 0, math.degrees(math.atan2(b[1] - a[1], b[0] - a[0])) + 90))


def brett_quer(p, pl, u, v, w=1.1, h=0.2, ang=12.0, color=WOOD_L, out=0.16):
    """Schief aufgenageltes Brett (Flicken an der Wand)."""
    a = math.radians(ang)
    pts = [(u + du * math.cos(a) - dv * math.sin(a), v + du * math.sin(a) + dv * math.cos(a)) for (du, dv) in ((-w / 2, -h / 2), (w / 2, -h / 2), (w / 2, h / 2), (-w / 2, h / 2))]
    slab(p, pl, pts, out, 0.05, jit(color, 0.08))
    stud(p, pl, pts[0][0] * 0.88 + pts[2][0] * 0.12, pts[0][1] * 0.88 + pts[2][1] * 0.12, out, 0.03, STEEL_D, 0.02)
    stud(p, pl, pts[0][0] * 0.12 + pts[2][0] * 0.88, pts[0][1] * 0.12 + pts[2][1] * 0.88, out, 0.03, STEEL_D, 0.02)


# ---------------------------------------------------------------- Modell: Objektnamen, Leerobjekte, Schattierung, Ausgabe
NEED = ("door", "work_1", "work_2", "drop", "bubble")


def look_visible(name, look, dmg=0):
    """Ist das Objekt im Ausbau-Aussehen look (1: Stufe 1-3, 2: Stufe 4-6, 3: Stufe 7-10) sichtbar?"""
    if name.startswith("lvmax3_"):
        return look == 1
    if name.startswith("lvmax6_"):
        return look <= 2
    if name.startswith("lv"):
        num = name[2:].split("_")[0]
        if num.isdigit():
            n = int(num)
            return True if n <= 3 else (look >= 2 if n <= 6 else look >= 3)
    if name.startswith("dmg1_"):
        return dmg >= 1
    if name.startswith("dmg2_") or name == "fx_smoke_dmg":
        return dmg >= 2
    return True


class Model:
    def __init__(self, name, fx, fy, tri_max=12000, looks=3):
        reset()
        RNG.seed(name)
        self.name, self.fx, self.fy, self.tri_max, self.looks = name, fx, fy, tri_max, looks
        self.root = empty(name)
        self.parts = {}
        self.org = {}
        self.empties = {}
        self.objs = {}

    def __getitem__(self, key):
        if key not in self.parts:
            self.parts[key] = Part()
        return self.parts[key]

    def origin(self, key, loc, euler=(0, 0, 0), local=False):
        """Legt Ursprung (Drehpunkt) und Drehung des Objekts fest. local=False: die Geometrie wird in Weltlage gebaut und
        beim Erzeugen in den Bezug des Objekts umgerechnet; local=True: die Geometrie wird direkt im Objektbezug gebaut."""
        self.org[key] = (tuple(loc), tuple(euler), local)
        return self[key]

    def empty(self, name, loc):
        self.empties[name] = tuple(loc)

    def punkte(self, door, work_1, work_2, drop, bubble):
        for k, v in (("door", door), ("work_1", work_1), ("work_2", work_2), ("drop", drop)):
            self.empty(k, (v[0], v[1], v[2] if len(v) > 2 else 0.0))
        self.empty("bubble", bubble)

    # ------------------------------------------------------------
    def build(self):
        for key, part in self.parts.items():
            if len(part.bm.verts) == 0:
                part.bm.free()
                continue
            loc, eul, local = self.org.get(key, ((0, 0, 0), (0, 0, 0), True))
            if not local:
                inv = (Matrix.Translation(Vector(loc)) @ Euler(eul, "XYZ").to_matrix().to_4x4()).inverted()
                for v in part.bm.verts:
                    v.co = inv @ v.co
            ob = part.build(key, self.root, loc)
            ob.rotation_euler = eul
            self.objs[key] = ob
        for k, loc in self.empties.items():
            self.objs[k] = empty(k, self.root, loc)
        bpy.context.view_layer.update()

    def set_look(self, look, dmg=0, fill=9):
        for k, ob in self.objs.items():
            vis = look_visible(k, look, dmg)
            if k.startswith("fill") and k[4:5].isdigit() and int(k[4:5]) > fill:
                vis = False
            ob.hide_render = not vis

    def _bake(self, keys):
        """kit.bake_ao() nur für die Objekte keys; alle sichtbaren Objekte werfen Schatten."""
        tmp = []
        for k, ob in self.objs.items():
            if ob.type != "MESH" or k in keys or ob.hide_render:
                continue
            if "Col" in ob.data.color_attributes:
                ob.data.color_attributes["Col"].name = "ColX"
                tmp.append(ob)
        hid = [ob for ob in self.objs.values() if ob.type == "MESH" and ob.hide_render]
        for ob in hid:
            if "Col" in ob.data.color_attributes:
                ob.data.color_attributes["Col"].name = "ColX"
                tmp.append(ob)
        if any(k in self.objs for k in keys):
            kit.bake_ao()
        for ob in tmp:
            ob.data.color_attributes["ColX"].name = "Col"
            ob.data.color_attributes.active_color = ob.data.color_attributes["Col"]
            ob.data.color_attributes.render_color_index = 0

    def bake(self):
        """Umgebungsverschattung je Ausbau-Aussehen: jedes Objekt wird in dem Aussehen schattiert, in dem es zuletzt sichtbar ist.
        Drehende Teile und Fahnentücher bleiben ohne Verschattung (Flaggenfarbe muss rein bleiben)."""
        me = bpy.data.meshes.new("tmp_ground")
        me.from_pydata([(-30, -30, -0.01), (30, -30, -0.01), (30, 30, -0.01), (-30, 30, -0.01)], [], [(0, 1, 2, 3)])
        gnd = bpy.data.objects.new("tmp_ground", me)
        bpy.context.scene.collection.objects.link(gnd)
        def skip(k):
            return k.startswith("spin_") or "flag" in k or "banner" in k or k.endswith("_glow")
        mesh = [k for k, ob in self.objs.items() if ob.type == "MESH" and not skip(k)]
        groups = [(1, 0, [k for k in mesh if k.startswith("lvmax3_")]), (2, 0, [k for k in mesh if k.startswith("lvmax6_")]),
                  (3, 2, [k for k in mesh if k.startswith("dmg")]),
                  (3, 0, [k for k in mesh if not k.startswith(("lvmax", "dmg"))])]
        for (look, dmg, keys) in groups:
            if keys:
                self.set_look(look, dmg)
                self._bake(set(keys))
        bpy.data.objects.remove(gnd, do_unlink=True)
        self.set_look(3, 0)

    def tris(self, keys=None):
        n = 0
        for k, o in self.objs.items():
            if o.type == "MESH" and (keys is None or k in keys):
                o.data.calc_loop_triangles()
                n += len(o.data.loop_triangles)
        return n

    def check(self):
        msg = []
        lo = Vector((9, 9, 9)); hi = Vector((-9, -9, -9))
        bad = []
        for k, o in self.objs.items():
            if o.type == "MESH":
                l2 = Vector((9, 9, 9)); h2 = Vector((-9, -9, -9))
                for v in o.data.vertices:
                    w = o.matrix_world @ v.co
                    for i in range(3):
                        l2[i] = min(l2[i], w[i]); h2[i] = max(h2[i], w[i])
                for i in range(3):
                    lo[i] = min(lo[i], l2[i]); hi[i] = max(hi[i], h2[i])
                if max(-l2.x, h2.x) > self.fx / 2 + 0.005 or max(-l2.y, h2.y) > self.fy / 2 + 0.005:
                    bad.append("%s x %.2f..%.2f y %.2f..%.2f" % (k, l2.x, h2.x, l2.y, h2.y))
        if bad:
            msg.append("GRUNDFLAECHE ueberschritten (erlaubt +-%.2f / +-%.2f): %s" % (self.fx / 2, self.fy / 2, "; ".join(bad)))
        n = self.tris()
        if n > self.tri_max:
            msg.append("DREIECKE %d > %d" % (n, self.tri_max))
        for k in NEED:
            if k not in self.objs:
                msg.append("Leerobjekt fehlt: " + k)
        mv = [k for k in self.objs if k.startswith(("spin_", "bob_", "sway_", "pulse_"))]
        fxs = [k for k in self.objs if k.startswith("fx_") and k != "fx_smoke_dmg"]
        if len(mv) < 2:
            msg.append("weniger als 2 bewegte Teile")
        if not fxs:
            msg.append("kein Effektpunkt")
        if "body" not in self.objs:
            msg.append("body fehlt")
        if not any("lamp" in k and k.endswith("_glow") for k in self.objs):
            msg.append("keine Lampe (lamp_glow)")
        per = {}
        for k in self.objs:
            if self.objs[k].type == "MESH":
                pre = k.split("_")[0] if k.startswith(("lv", "dmg", "fill")) else "basis"
                per[pre] = per.get(pre, 0) + self.tris({k})
        print("MODEL %-13s tris %5d  hoehe %.1f  %s" % (self.name, n, hi.z, " ".join("%s:%d" % kv for kv in sorted(per.items()))), flush=True)
        print("   objekte: " + ", ".join(sorted(self.objs)), flush=True)
        for m in msg:
            print("   !! " + m, flush=True)
        return msg

    def finish(self, yaw=35.0, pitch=30.0):
        self.build()
        self.check()
        if not os.environ.get("GEB_NOAO"):
            self.bake()
        self.set_look(3, 0)
        for ob in self.objs.values():
            ob.hide_render = False
        pv = os.environ.get("GEB_PREVIEW")
        if pv:
            # Nur zum Ansehen im Spiel, solange das Spiel lvmax*/dmg* noch nicht selbst schaltet: schreibt die GLB mit genau
            # einem Ausbau-Aussehen ("<aussehen>,<schaden>", z. B. "2,0"). Danach die echten Modelle wiederherstellen (git checkout models/).
            look, dmg = [int(x) for x in pv.split(",")]
            for k in list(self.objs):
                if self.objs[k].type == "MESH" and not look_visible(k, min(look, self.looks), dmg):
                    bpy.data.objects.remove(self.objs.pop(k), do_unlink=True)
            bpy.ops.export_scene.gltf(filepath=os.path.join(kit.OUT_GLB, self.name + ".glb"), export_format="GLB", export_apply=True,
                                      export_vertex_color="ACTIVE", export_all_vertex_colors=False, export_materials="EXPORT",
                                      export_cameras=False, export_lights=False, export_yup=True, export_animations=False)
            return
        save(self.name)
        self.set_look(min(self.looks, 3), 0)
        if not os.environ.get("GEB_NOICON"):
            icon(self.name, 256, yaw=yaw, pitch=pitch, samples=int(os.environ.get("GEB_SAMPLES", "24")))
        d = os.environ.get("GEB_SHOTS")
        if d:
            self.shots(d)

    # ------------------------------------------------------------ Prüfbilder (nicht fürs Spiel)
    def shots(self, outdir, size=360, samples=10):
        from PIL import Image
        os.makedirs(outdir, exist_ok=True)
        top = 3 if self.looks >= 3 else 2
        views = [("vorn", top, 0, 0.0, 30.0), ("rechts", top, 0, 90.0, 30.0), ("hinten", top, 0, 180.0, 30.0), ("links", top, 0, -90.0, 30.0),
                 ("spiel", top, 0, 40.0, 52.0)]
        looks = [("stufe1", 1, 0, 35.0, 40.0)] + ([("stufe4", 2, 0, 35.0, 40.0)] if self.looks >= 2 else []) + \
                ([("stufe7", 3, 0, 35.0, 40.0)] if self.looks >= 3 else []) + [("schaden1", top, 1, 35.0, 40.0), ("schaden2", top, 2, 35.0, 40.0)]
        for tag, lst in (("sicht", views), ("stufen", looks)):
            ims = []
            for (nm, look, dmg, yw, pt) in lst:
                self.set_look(look, dmg, fill=9 if tag == "sicht" else {1: 1, 2: 2, 3: 9}[look])
                kit_out = kit.OUT_ICON
                kit.OUT_ICON = outdir
                icon("_tmp_" + self.name, size, yaw=yw, pitch=pt, samples=samples, margin=1.06)
                kit.OUT_ICON = kit_out
                im = Image.open(os.path.join(outdir, "_tmp_" + self.name + ".png")).convert("RGBA")
                bg = Image.new("RGBA", im.size, (150, 176, 110, 255))
                bg.alpha_composite(im)
                ims.append(bg.convert("RGB"))
            sheet = Image.new("RGB", (size * len(ims), size), (0, 0, 0))
            for i, im in enumerate(ims):
                sheet.paste(im, (i * size, 0))
            sheet.save(os.path.join(outdir, "%s_%s.png" % (self.name, tag)))
        os.remove(os.path.join(outdir, "_tmp_" + self.name + ".png"))
        self.set_look(top, 0)


# ---------------------------------------------------------------- Zusammengesetztes
def giebelfeld(p, H, rh, style, color, sides="lr", out=0.06, v0=None, fenster_=None):
    """Giebeldreiecke über den Wänden 'sides' eines Hauses (Dachhöhe rh), mit dunklem Kern dahinter."""
    v0 = H.h if v0 is None else v0
    for s in sides:
        pl = H.W(s)
        slab(p, pl, [(0, v0), (pl.len, v0), (pl.len / 2, v0 + rh)], 0.0, 0.0, JOINT)
        clad(p, pl, style, color, v0=v0, v1=v0 + rh, out=out, lines=giebel(0, pl.len, v0, v0 + rh), holes=fenster_ or ())


def saegeblatt(p, r=0.62, color=STEEL_L, hub=RED, teeth=14, th=0.05):
    """Kreissägeblatt um die lokale Z-Achse."""
    p.cyl(r, th, (0, 0, 0), color, sides=teeth)
    for i in range(teeth):
        a = math.radians(i * 360.0 / teeth)
        p.cyl(r * 0.2, th, (math.cos(a) * r * 1.0, math.sin(a) * r * 1.0, 0), color, r=rot(0, 0, i * 360.0 / teeth - 50), sides=3)
    p.cyl(r * 0.36, th + 0.05, (0, 0, 0), hub, sides=10)
    p.cyl(r * 0.12, th + 0.12, (0, 0, 0), DK, sides=6)
    for i in range(4):
        a = math.radians(i * 90 + 20)
        p.cyl(r * 0.07, th + 0.01, (math.cos(a) * r * 0.62, math.sin(a) * r * 0.62, 0), shade(color, 0.6), sides=5)


def axtklotz(p, loc):
    """Hackklotz mit Axt."""
    x, y, z = loc
    p.cyl(0.34, 0.5, (x, y, z + 0.25), "8A5030", sides=9)
    p.cyl(0.29, 0.02, (x, y, z + 0.51), "E8C088", sides=9)
    p.cyl(0.2, 0.01, (x, y, z + 0.525), "D4A56A", sides=9)
    beam(p, (x - 0.02, y, z + 0.6), (x + 0.42, y - 0.1, z + 1.25), 0.07, WOOD_L)
    p.box((0.32, 0.06, 0.24), (x - 0.06, y + 0.01, z + 0.66), STEEL_L, r=rot(0, 32, -12))
    p.box((0.1, 0.07, 0.25), (x + 0.03, y - 0.01, z + 0.72), STEEL_D, r=rot(0, 32, -12))


def scheit(p, loc, n=5):
    """Ein paar Holzscheite am Boden."""
    x, y, z = loc
    for i in range(n):
        a = RNG.uniform(0, 180)
        p.box((0.42, 0.14, 0.13), (x + RNG.uniform(-0.3, 0.3), y + RNG.uniform(-0.25, 0.25), z + 0.07 + (0.12 if i > 2 else 0)), jit("D9A05A", 0.1), r=rot(0, 0, a))


def sockel(p, H, holes=None, color=None, v1=0.42, sides="frbl", out=0.13):
    """Dunkler Steinsockel rund um das Haus."""
    holes = holes or {}
    for s in sides:
        clad(p, H.W(s), "stone", color or shade(ST_D, 0.8), v1=v1, out=out, holes=holes.get(s, ()), size=v1 / 2)


def wandsatz(p, H, style, holes=None, color=None, v0=0.42, v1=None, sides="frbl", color2=None, eck=True, size=None):
    """Kompletter Wandaufbau eines Hauses über dem Sockel.
    style: bretter, bretter_h, fachwerk, stein, ziegel, beton, blech."""
    holes = holes or {}
    v1 = H.h if v1 is None else v1
    for s in sides:
        pl = H.W(s)
        hs = holes.get(s, ())
        if style in ("bretter", "bretter_h"):
            clad(p, pl, "plank_v" if style == "bretter" else "plank_h", color or WOOD, v0=v0, v1=v1, holes=hs, out=0.07)
            tile(p, pl, 0.0, v1 - 0.18, pl.len, v1, 0.1, 0.1, WOOD_D)
        elif style == "fachwerk":
            vm = max(v0, min(1.3, v1 - 1.0))
            if vm > v0:
                clad(p, pl, "stone", color2 or ST, v0=v0, v1=vm, holes=hs, out=0.1, color2=ST_L)
            clad(p, pl, "putz", color or PLASTER, v0=vm, v1=v1, holes=hs, out=0.06)
            n = max(1, round(pl.len / 1.25))
            posts = []
            for i in range(1, n):
                u = pl.len * i / n
                if not any(h[0] - 0.12 < u < h[2] + 0.12 and h[3] > vm for h in hs):
                    posts.append(u)
            diag = []
            bw = pl.len / n
            def free(a, b):
                return not any(h[0] < b and h[2] > a and h[3] > vm for h in hs)
            if n >= 2 and free(0, bw):
                diag.append((0.17, vm + 0.17, bw - 0.09, v1 - 0.17))
            if n >= 2 and free(pl.len - bw, pl.len):
                diag.append((pl.len - 0.17, vm + 0.17, pl.len - bw + 0.09, v1 - 0.17))
            fachwerk(p, pl, 0.0, pl.len, vm, v1, WOOD_D, out=0.1, w=0.17, posts=tuple(posts), diag=tuple(diag))
        elif style == "stein":
            clad(p, pl, "stone", color or ST, v0=v0, v1=v1, holes=hs, out=0.1, color2=color2 or ST_L, size=size)
        elif style == "ziegel":
            clad(p, pl, "brick", color or BRICK, v0=v0, v1=v1, holes=hs, out=0.09, color2=color2 or shade(BRICK, 0.8), size=size)
            tile(p, pl, 0.0, v1 - 0.16, pl.len, v1, 0.12, 0.1, ST_L)
        elif style == "beton":
            clad(p, pl, "panel", color or CONCRETE, v0=v0, v1=v1, holes=hs, out=0.08)
        elif style == "blech":
            clad(p, pl, "blech", color or "8FA0B8", v0=v0, v1=v1, holes=hs, out=0.08)
            tile(p, pl, 0.0, v1 - 0.14, pl.len, v1, 0.11, 0.1, STEEL_D)
            tile(p, pl, 0.0, v0, pl.len, v0 + 0.1, 0.11, 0.1, STEEL_D)
    if eck:
        if style in ("bretter", "bretter_h", "fachwerk"):
            if style == "fachwerk":
                ecken(p, H, color2 or ST_L, out=0.13, style="stein", v1=max(v0, min(1.3, v1 - 1.0)), sides=sides)
            else:
                ecken(p, H, WOOD_D, 0.22, 0.11, v1=v1, sides=sides)
        elif style in ("stein", "ziegel"):
            ecken(p, H, ST_L if style == "ziegel" else shade(color or ST, 1.12), out=0.14, style="stein", v1=v1, sides=sides)
        else:
            ecken(p, H, STEEL_D if style == "blech" else CONC_D, 0.2, 0.1, v1=v1, sides=sides)


def fels(p, loc, size, color="9A8F96", tilt=8.0):
    """Felsblock: kantiger Quader, leicht verdreht."""
    x, y, z = loc
    p.box(size, (x, y, z + size[2] / 2), jit(color, 0.08), r=rot(RNG.uniform(-tilt, tilt), RNG.uniform(-tilt, tilt), RNG.uniform(-25, 25)), bevel=min(size) * 0.22, segs=1)


def steinhaufen(p, loc, n=7, s=0.3, color="A9A2AA", r=0.5):
    x, y, z = loc
    for i in range(n):
        a = RNG.uniform(0, 6.28); d = RNG.uniform(0, r) * (0.5 if i >= n * 0.6 else 1.0)
        ss = s * RNG.uniform(0.75, 1.2)
        zz = z + (s * 0.75 if i >= n * 0.6 else 0.0)
        p.box((ss, ss * RNG.uniform(0.8, 1.1), ss * 0.8), (x + math.cos(a) * d, y + math.sin(a) * d, zz + ss * 0.4), jit(color, 0.1),
              r=rot(RNG.uniform(-15, 15), RNG.uniform(-15, 15), RNG.uniform(0, 90)), bevel=ss * 0.18, segs=1)


def lore(p, loc, yaw=0.0, color=STEEL_D, load=None):
    """Lore (Kippwagen) – Fahrtrichtung lokal Y."""
    a = At(p, T(*loc) @ rot(0, 0, yaw))
    a.box((0.7, 1.0, 0.1), (0, 0, 0.3), DK)
    for sx in (-1, 1):
        a.box((0.06, 1.05, 0.5), (sx * 0.42, 0, 0.62), color, r=rot(0, sx * 14, 0))
        for sy in (-0.32, 0.32):
            a.cyl(0.17, 0.07, (sx * 0.36, sy, 0.17), "22252E", r=rot(0, 90, 0), sides=8)
    for sy in (-1, 1):
        a.box((0.82, 0.06, 0.5), (0, sy * 0.52, 0.62), shade(color, 0.9))
    a.box((0.74, 1.0, 0.06), (0, 0, 0.4), shade(color, 0.8))
    if load:
        for i in range(5):
            a.box((0.3, 0.3, 0.26), (RNG.uniform(-0.2, 0.2), RNG.uniform(-0.3, 0.3), 0.85 + RNG.uniform(0, 0.1)), jit(load, 0.1), r=rot(RNG.uniform(-20, 20), 0, RNG.uniform(0, 90)), bevel=0.05, segs=1)


def schienen(p, a, b, z, gauge=0.72):
    """Gleis von a nach b (2D) mit Schwellen."""
    a = Vector((a[0], a[1], z)); b = Vector((b[0], b[1], z))
    d = b - a; l = d.length
    side = Vector((d.y, -d.x, 0)).normalized() * gauge / 2
    for s in (-1, 1):
        beam(p, a + side * s + Vector((0, 0, 0.09)), b + side * s + Vector((0, 0, 0.09)), 0.06, STEEL)
    n = int(l / 0.42)
    for i in range(n + 1):
        q = a + d * ((i + 0.5) / (n + 1))
        beam(p, q - side * 1.35 + Vector((0, 0, 0.03)), q + side * 1.35 + Vector((0, 0, 0.03)), 0.12, jit(WOOD_D, 0.1), d=0.07)


def truhe(p, loc, s=1.0, color=GOLD, wood=WOOD, yaw=0.0, offen=False):
    """Beutekiste mit gewölbtem Deckel und Beschlägen."""
    a = At(p, T(*loc) @ rot(0, 0, yaw) @ S(s, s, s))
    a.box((1.0, 0.7, 0.5), (0, 0, 0.25), wood)
    a.cyl(0.35, 0.97, (0, 0, 0.5), shade(wood, 1.12), r=rot(0, 90, 0), sides=10)
    for sx in (-0.36, 0.36):
        a.box((0.12, 0.74, 0.52), (sx, 0, 0.26), color)
        a.cyl(0.37, 0.12, (sx, 0, 0.5), color, r=rot(0, 90, 0), sides=10)
    a.box((0.2, 0.1, 0.24), (0, -0.36, 0.48), color)
    a.box((1.03, 0.73, 0.06), (0, 0, 0.5), color)


def bank(p, loc, w=1.4, yaw=0.0, color=WOOD_L):
    a = At(p, T(*loc) @ rot(0, 0, yaw))
    for i in range(2):
        a.box((w, 0.2, 0.06), (0, -0.11 + i * 0.22, 0.48), jit(color, 0.07))
        a.box((w, 0.05, 0.16), (0, 0.24, 0.72 + i * 0.2), jit(color, 0.07))
    for sx in (-1, 1):
        a.box((0.08, 0.44, 0.45), (sx * (w / 2 - 0.12), 0, 0.23), WOOD_D)
        a.box((0.07, 0.06, 0.6), (sx * (w / 2 - 0.12), 0.26, 0.75), WOOD_D)


def blume(p, loc, n=5, r=0.3):
    """Kleines Blumenbüschel."""
    x, y, z = loc
    cols = (RED, GOLD, "F48BB0", "white", PURPLE)
    for i in range(n):
        a = RNG.uniform(0, 6.28); d = RNG.uniform(0, r)
        q = (x + math.cos(a) * d, y + math.sin(a) * d, z)
        p.ball(0.12, (q[0], q[1], z + 0.1), jit("5E9A3A", 0.1), subdiv=1)
        p.ball(0.07, (q[0], q[1], z + 0.24), cols[i % 5], subdiv=1)


def zaun(p, a, b, z, h=0.9, color=WOOD_L, n=None):
    """Lattenzaun von a nach b (2D)."""
    a = Vector((a[0], a[1], z)); b = Vector((b[0], b[1], z))
    d = b - a; l = d.length
    n = n or max(2, round(l / 0.8))
    yaw = math.degrees(math.atan2(d.y, d.x))
    for i in range(n + 1):
        q = a + d * (i / n)
        p.box((0.12, 0.12, h), (q.x, q.y, z + h / 2), jit(WOOD, 0.07), r=rot(0, 0, yaw))
    for k in (0.45, 0.85):
        beam(p, a + Vector((0, 0, h * k)), b + Vector((0, 0, h * k)), 0.09, jit(color, 0.07), d=0.05)


def amboss(p, loc, yaw=0.0):
    a = At(p, T(*loc) @ rot(0, 0, yaw))
    a.cyl(0.36, 0.5, (0, 0, 0.25), "8A5030", sides=9)
    a.cyl(0.31, 0.02, (0, 0, 0.51), "E8C088", sides=9)
    a.box((0.34, 0.26, 0.14), (0, 0, 0.59), "3A3F4C")
    a.box((0.2, 0.18, 0.16), (0, 0, 0.73), "3A3F4C")
    a.box((0.62, 0.26, 0.16), (0, 0, 0.88), "4A5060", bevel=0.02, segs=1)
    a.cone(0.11, 0.34, (0.45, 0, 0.88), "4A5060", r=rot(0, 90, 0), sides=6)


def wappen(p, m, s=1.0, color="flag", rand=GOLD, stern=True):
    """Schildwappen (lokal: x rechts, z hoch, -y nach vorn), Mitte im Ursprung."""
    pl = Plane((m @ Vector((0, 0, 0))), m.to_3x3() @ Vector((1, 0, 0)), m.to_3x3() @ Vector((0, 0, 1)))
    def shape(k):
        return [(-0.5 * k, 0.5 * k), (-0.5 * k, -0.1 * k), (-0.3 * k, -0.42 * k), (0, -0.62 * k), (0.3 * k, -0.42 * k), (0.5 * k, -0.1 * k), (0.5 * k, 0.5 * k)]
    slab(p, pl, shape(s * 1.16), 0.06, 0.06, rand)
    slab(p, pl, shape(s), 0.1, 0.05, color)
    if stern:
        star(At(p, m), (0, -0.13, 0.0), 0.3 * s, "white", 0.05)
