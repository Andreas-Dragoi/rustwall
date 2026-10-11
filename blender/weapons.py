"""Die 18 Heldenwaffen im dicken, bunten Spielzeug-Stil des Werkstatt-Bildes.
Lauf zeigt nach -Y, Griff im Ursprung. Objekte: body, Leerobjekt muzzle.
Aufruf: python3 blender/weapons.py [j_rifle a_cloud ...]   (ohne Namen: alle)

Die Waffen werden in einem Einheitsraum gebaut (Gesamtlänge 1: hinten y = +0,3, Mündung y = -0,7)
und am Ende auf die Länge `len` aus src/data.gd WEAPONS skaliert.

Dieses Skript enthält auch die Hilfsformen (Stern, Prisma, Drehkörper, Schlauch, Tönung),
die gear.py und ui_icons.py mitbenutzen."""
import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from kit import *

# ------------------------------------------------------------------ Farben
BLUE, BLUE_L, BLUE_D, NAVY = "2E86F0", "7CC2FF", "1F56C4", "2C3F80"
YEL, YEL_L, ORG, RED, RED_D = "FFCB2E", "FFE98A", "FF8A1F", "EC3B33", "B8242B"
GRN, GRN_D, PINK, PINK_D, VIO, VIO_D = "42C95E", "1F8E4C", "FF74B4", "C93F8E", "8C5DF2", "5B3BB8"
WHITE, GREY, GREY_L, DGREY, HOLE = "F4F6FA", "8E9AB4", "C5CEDF", "4C5878", "1A2140"
CYAN, TAN, WOOD, TEAL = "66DBFF", "D9A066", "B9733A", "22C7B8"


# ------------------------------------------------------------------ Hilfsformen (über Part.bm)
def tris(p):
    return sum(len(f.verts) - 2 for f in p.bm.faces)


def _M(loc, r):
    return Matrix.Translation(Vector(loc)) @ (r if r is not None else Matrix.Identity(4))


def prism(p, pts, depth, loc=(0, 0, 0), color="gold", r=None, bevel=0.0, segs=2):
    """Flaches Vieleck (Punkte (x, z), von vorn gesehen) mit Dicke `depth` entlang Y."""
    bm = p.bm
    before = set(bm.faces)
    h = depth * 0.5
    front = [bm.verts.new((x, -h, z)) for x, z in pts]
    back = [bm.verts.new((x, h, z)) for x, z in pts]
    n = len(pts)
    caps = [bm.faces.new(front), bm.faces.new(back[::-1])]
    faces = list(caps)
    for i in range(n):
        j = (i + 1) % n
        faces.append(bm.faces.new((front[j], front[i], back[i], back[j])))
    bmesh.ops.recalc_face_normals(bm, faces=faces)
    if bevel > 0.0:
        edges = list({e for f in caps for e in f.edges})
        bmesh.ops.bevel(bm, geom=edges, offset=min(bevel, h * 0.9), segments=segs, profile=0.5, affect="EDGES")
    p._finish([f for f in bm.faces if f not in before], color, _M(loc, r))
    return p


def star_pts(n=5, R=1.0, r=0.45, a0=90.0):
    out = []
    for i in range(n * 2):
        a = math.radians(a0 + i * 180.0 / n)
        rr = R if i % 2 == 0 else r
        out.append((math.cos(a) * rr, math.sin(a) * rr))
    return out


def star(p, R, depth, loc=(0, 0, 0), color=YEL, r=None, n=5, inner=0.48, a0=90.0, color2=None):
    """Praller Stern in der X-Z-Ebene (Mitte gewölbt), 4*n Dreiecke."""
    bm = p.bm
    before = set(bm.faces)
    rim = [bm.verts.new((x, 0, z)) for x, z in star_pts(n, R, R * inner, a0)]
    cf = bm.verts.new((0, -depth * 0.5, 0))
    cb = bm.verts.new((0, depth * 0.5, 0))
    m = len(rim)
    faces = []
    for i in range(m):
        j = (i + 1) % m
        faces.append(bm.faces.new((cf, rim[i], rim[j])))
        faces.append(bm.faces.new((cb, rim[j], rim[i])))
    bmesh.ops.recalc_face_normals(bm, faces=faces)
    p._finish(faces, color, _M(loc, r))
    if color2 is not None:                      # jede zweite Facette dunkler: wirkt wie geschliffen
        c2 = col(color2)
        for k, f in enumerate(faces):
            if (k // 2) % 2 == 1:
                for l in f.loops:
                    l[p.layer] = c2
    for f in faces:
        f.smooth = False
    return p


def lathe(p, prof, loc=(0, 0, 0), color="steel", r=None, sides=16):
    """Drehkörper um Z. prof = [(Radius, z), ...]; Radius 0 = Pol. color: eine Farbe oder je Abschnitt eine."""
    bm = p.bm
    rings = []
    for rad, z in prof:
        if rad <= 1e-6:
            rings.append([bm.verts.new((0, 0, z))])
        else:
            rings.append([bm.verts.new((rad * math.cos(2 * math.pi * i / sides), rad * math.sin(2 * math.pi * i / sides), z)) for i in range(sides)])
    allf = []
    segf = []
    for k in range(len(rings) - 1):
        a, b = rings[k], rings[k + 1]
        fs = []
        for i in range(sides):
            j = (i + 1) % sides
            if len(a) == 1 and len(b) == 1:
                continue
            if len(a) == 1:
                fs.append(bm.faces.new((a[0], b[i], b[j])))
            elif len(b) == 1:
                fs.append(bm.faces.new((a[i], a[j], b[0])))
            else:
                fs.append(bm.faces.new((a[i], a[j], b[j], b[i])))
        segf.append(fs)
        allf += fs
    for end in (rings[0], rings[-1]):
        if len(end) > 1:
            allf.append(bm.faces.new(end))
            segf.append([allf[-1]])
    bmesh.ops.recalc_face_normals(bm, faces=allf)
    single = isinstance(color, str) or (isinstance(color, (tuple, list)) and len(color) == 4 and not isinstance(color[0], (str, tuple, list)))
    p._finish(allf, color if single else color[0], _M(loc, r))
    if not single:
        for k, fs in enumerate(segf):
            c = col(color[min(k, len(color) - 1)])
            for f in fs:
                for l in f.loops:
                    l[p.layer] = c
    return p


def sweep(p, pts, rad, color="steel", sides=8, ref=(1, 0, 0), loc=(0, 0, 0), r=None, closed=False):
    """Schlauch entlang einer Punktfolge. rad = Zahl oder Liste. ref = Achse senkrecht zur Kurvenebene."""
    bm = p.bm
    pts = [Vector(q) for q in pts]
    n = len(pts)
    rads = list(rad) if isinstance(rad, (list, tuple)) else [rad] * n
    ref = Vector(ref)
    rings = []
    for i in range(n):
        if closed:
            t = pts[(i + 1) % n] - pts[(i - 1) % n]
        else:
            t = pts[min(i + 1, n - 1)] - pts[max(i - 1, 0)]
        t.normalize()
        a = t.cross(ref)
        if a.length < 1e-4:
            a = t.cross(Vector((0, 0, 1)))
        a.normalize()
        b = t.cross(a)
        rings.append([bm.verts.new(pts[i] + (a * math.cos(2 * math.pi * j / sides) + b * math.sin(2 * math.pi * j / sides)) * rads[i]) for j in range(sides)])
    faces = []
    for i in range(n if closed else n - 1):
        a, b = rings[i], rings[(i + 1) % n]
        for j in range(sides):
            k = (j + 1) % sides
            faces.append(bm.faces.new((a[j], a[k], b[k], b[j])))
    if not closed:
        faces.append(bm.faces.new(rings[0]))
        faces.append(bm.faces.new(rings[-1]))
    bmesh.ops.recalc_face_normals(bm, faces=faces)
    p._finish(faces, color, _M(loc, r))
    return p


def arc(cx, cz, rad, a0, a1, n, y=0.0):
    """Punkte eines Kreisbogens in der X-Z-Ebene (Grad)."""
    return [(cx + rad * math.cos(math.radians(a0 + (a1 - a0) * i / n)), y, cz + rad * math.sin(math.radians(a0 + (a1 - a0) * i / n))) for i in range(n + 1)]


def arc2(cx, cz, rad, a0, a1, n):
    return [(q[0], q[2]) for q in arc(cx, cz, rad, a0, a1, n)]


def toon(p, lo=0.80, hi=1.10):
    """Tönt die Vertex-Farben nach der Flächenneigung: oben heller, unten dunkler (Spielzeug-Glanz)."""
    p.bm.normal_update()
    for f in p.bm.faces:
        for l in f.loops:
            nz = l.vert.normal.z * 0.6 + f.normal.z * 0.4
            k = lo + (hi - lo) * (nz * 0.5 + 0.5)
            c = l[p.layer]
            l[p.layer] = (min(c[0] * k, 1.0), min(c[1] * k, 1.0), min(c[2] * k, 1.0), 1.0)


def scale_all(p, s):
    bmesh.ops.scale(p.bm, vec=Vector((s, s, s)), verts=list(p.bm.verts))


def sparkle(p, R, loc, color=YEL_L, face="x", a0=90.0):
    """Kleines Funkel-Sternchen (vier Zacken)."""
    star(p, R, R * 0.7, loc, color, r=rot(0, 0, 90) if face == "x" else None, n=4, inner=0.36, a0=a0)


def Y(p, rad, y0, y1, z, color, r2=None, sides=14, bevel=0.0, x=0.0, segs=2):
    """Zylinder entlang Y von hinten (y0) nach vorn (y1 < y0); r2 = Radius vorn."""
    p.cyl(rad, y0 - y1, (x, (y0 + y1) * 0.5, z), color, r=rot(90, 0, 0), r2=r2, sides=sides, bevel=bevel, segs=segs)


def shine(p, y0, y1, z, rad, color=WHITE, w=0.022):
    """Glanzlicht: schmaler heller Streifen oben links und rechts auf einem Rohr."""
    for sx in (-1, 1):
        p.ball(1.0, (sx * rad * 0.66, (y0 + y1) * 0.5, z + rad * 0.7), color, scale=(w, abs(y0 - y1) * 0.5, w * 0.6), subdiv=1)


def hole(p, rad, y, z, color=HOLE, x=0.0):
    Y(p, rad, y + 0.02, y - 0.006, z, color, sides=12, x=x)


def ring(p, rad, tube, y, z, color=YEL, seg=14, tseg=6, x=0.0):
    p.torus(rad, tube, (x, y, z), color, r=rot(90, 0, 0), seg=seg, tseg=tseg)


def grip(p, color=NAVY, y=0.04, h=0.27, w=0.1, d=0.125, tilt=14):
    p.box((w, d, h), (0, y + 0.025, -h * 0.5 + 0.05), color, r=rot(tilt, 0, 0), bevel=0.04, segs=2)


def trigger(p, y=-0.06, color=YEL):
    p.box((0.035, 0.035, 0.09), (0, y, -0.015), color, r=rot(-18, 0, 0), bevel=0.012, segs=1)


WLEN = {"j_rifle": 0.9, "j_parcel": 0.8, "j_burst": 1.0, "m_flame": 0.9, "m_water": 0.9, "m_fireball": 0.8,
        "b_nailer": 0.8, "b_ball": 0.5, "b_cement": 0.85, "a_spark": 0.9, "a_shrink": 0.8, "a_cloud": 0.9,
        "y_rifle": 1.3, "y_bow": 0.7, "y_swarm": 0.7, "g_cracker": 0.8, "g_sparkler": 0.9, "g_cake": 0.8}
TRIS = {}


def finish(key, p, muzzle, yaw=-58.0, pitch=12.0, tilt=24.0, render=True):
    """Skaliert auf die Solllänge, tönt, baut body + muzzle, speichert und rendert das Symbol."""
    L = WLEN[key]
    scale_all(p, L)
    toon(p)
    TRIS[key] = tris(p)
    reset()
    root = empty("w_" + key)
    body = p.build("body", root)
    empty("muzzle", root, (muzzle[0] * L, muzzle[1] * L, muzzle[2] * L))
    save("w_" + key)
    if render:
        body.data.transform(Matrix.Rotation(math.radians(-tilt), 4, "X"))   # nur fürs Symbol (nach dem Speichern): Lauf nach rechts oben
        body.data.update()
        bpy.context.view_layer.update()
        icon("w_" + key, 256, yaw=yaw, pitch=pitch, margin=1.06)


# ------------------------------------------------------------------ Jona
def j_rifle():
    p = Part()
    z = 0.13
    p.box((0.1, 0.24, 0.15), (0, 0.19, 0.085), NAVY, bevel=0.05)                 # Schaft
    p.box((0.115, 0.07, 0.21), (0, 0.275, 0.075), BLUE_D, bevel=0.03, segs=1)
    p.box((0.15, 0.4, 0.2), (0, -0.12, z), BLUE, bevel=0.07, segs=3)             # Gehäuse
    p.box((0.158, 0.26, 0.04), (0, -0.12, 0.175), BLUE_L, bevel=0.015, segs=1)   # Glanzstreifen
    p.box((0.07, 0.24, 0.055), (0, -0.1, 0.25), YEL, bevel=0.02, segs=1)         # Visierschiene
    p.box((0.05, 0.05, 0.07), (0, 0.0, 0.285), YEL, bevel=0.015, segs=1)
    Y(p, 0.068, -0.3, -0.52, z, NAVY, bevel=0.02, sides=12)                      # Handschutz
    Y(p, 0.04, -0.5, -0.64, z, GREY, sides=10)
    Y(p, 0.06, -0.6, -0.7, z, YEL, bevel=0.015, sides=12)                        # Mündung
    hole(p, 0.035, -0.7, z)
    p.box((0.085, 0.11, 0.25), (0, -0.2, -0.06), DGREY, r=rot(-12, 0, 0), bevel=0.03)   # Magazin
    grip(p)
    trigger(p)
    finish("j_rifle", p, (0, -0.7, z))


def j_parcel():
    p = Part()
    z = 0.17
    Y(p, 0.14, 0.24, -0.46, z, BLUE, bevel=0.03, sides=16)                       # Rohr
    Y(p, 0.158, 0.2, 0.1, z, YEL, bevel=0.02, sides=16)
    Y(p, 0.158, -0.36, -0.5, z, YEL, bevel=0.025, sides=16)
    Y(p, 0.1, 0.3, 0.22, z, NAVY, bevel=0.03, sides=12)
    hole(p, 0.12, -0.5, z)
    shine(p, 0.08, -0.34, z, 0.14, BLUE_L)
    for sx in (-1, 1):                                                           # Briefumschlag als Emblem
        p.box((0.03, 0.2, 0.14), (sx * 0.135, -0.12, z), WHITE, bevel=0.012, segs=1)
        prism(p, [(-0.1, 0.07), (0.1, 0.07), (0, -0.02)], 0.012, (sx * 0.152, -0.12, z), RED, r=rot(0, 0, 90))
    k = rot(18, 10, 24)                                                          # Paket schaut aus der Mündung
    c = (0, -0.57, z + 0.02)
    p.box((0.2, 0.2, 0.2), c, TAN, r=k, bevel=0.025, segs=1)
    p.box((0.21, 0.05, 0.21), c, RED, r=k, bevel=0.01, segs=1)
    p.box((0.05, 0.21, 0.21), c, RED, r=k, bevel=0.01, segs=1)
    p.box((0.1, 0.34, 0.07), (0, -0.1, 0.02), NAVY, bevel=0.03, segs=1)          # Träger
    p.box((0.085, 0.1, 0.17), (0, -0.3, -0.04), DGREY, bevel=0.035)              # Vordergriff
    grip(p)
    trigger(p)
    finish("j_parcel", p, (0, -0.5, z))


def j_burst():
    p = Part()
    z = 0.12
    p.box((0.1, 0.22, 0.14), (0, 0.19, 0.08), WHITE, bevel=0.045)                # Schaft: Streifen
    for i in range(3):
        p.box((0.106, 0.035, 0.146), (0, 0.13 + i * 0.065, 0.08), RED, bevel=0.012, segs=1)
    p.box((0.13, 0.36, 0.18), (0, -0.1, z), BLUE, bevel=0.06, segs=3)            # Gehäuse
    for sx in (-1, 1):
        star(p, 0.075, 0.035, (sx * 0.068, -0.1, z), YEL, r=rot(0, 0, 90))
    p.box((0.06, 0.3, 0.04), (0, -0.1, 0.225), YEL, bevel=0.015, segs=1)
    p.box((0.045, 0.045, 0.06), (0, 0.02, 0.25), NAVY, bevel=0.012, segs=1)
    Y(p, 0.058, -0.26, -0.44, z, NAVY, bevel=0.02, sides=12)
    Y(p, 0.038, -0.42, -0.64, z, BLUE_D, sides=10)
    ring(p, 0.045, 0.016, -0.5, z, YEL, seg=10, tseg=5)
    ring(p, 0.045, 0.016, -0.57, z, YEL, seg=10, tseg=5)
    Y(p, 0.045, -0.62, -0.7, z, YEL, r2=0.07, sides=12)                          # Trichter-Mündung
    hole(p, 0.045, -0.7, z)
    p.box((0.075, 0.1, 0.2), (0, -0.2, -0.04), YEL, r=rot(-18, 0, 0), bevel=0.03, segs=1)   # Magazin
    grip(p, NAVY)
    trigger(p, color=RED)
    finish("j_burst", p, (0, -0.7, z))


# ------------------------------------------------------------------ Mika
def flame(p, c, s=1.0, core=True):
    """Flamme mit Spitze nach -Y/oben."""
    x, y, z = c
    p.ball(0.085 * s, (x, y, z), ORG, scale=(0.9, 1.25, 0.9), subdiv=2)
    p.cone(0.07 * s, 0.2 * s, (x, y - 0.11 * s, z + 0.055 * s), ORG, r=rot(62, 0, 0), sides=8)
    p.cone(0.04 * s, 0.11 * s, (x, y - 0.02 * s, z + 0.1 * s), "FF5A1F", r=rot(25, 0, 0), sides=6)
    if core:
        p.ball(0.055 * s, (x, y - 0.045 * s, z + 0.0 * s), YEL, scale=(0.9, 1.3, 0.9), subdiv=2)
        p.cone(0.04 * s, 0.12 * s, (x, y - 0.14 * s, z + 0.03 * s), YEL_L, r=rot(70, 0, 0), sides=6)


def m_flame():
    p = Part()
    z = 0.1
    Y(p, 0.1, 0.3, -0.04, 0.22, RED, bevel=0.045, sides=14, segs=3)              # Tank
    ring(p, 0.1, 0.02, 0.13, 0.22, YEL, seg=14, tseg=5)
    Y(p, 0.035, -0.04, -0.09, 0.22, GREY, sides=8)
    p.box((0.14, 0.42, 0.16), (0, -0.08, z), ORG, bevel=0.06, segs=3)            # Gehäuse
    p.box((0.148, 0.24, 0.035), (0, -0.08, 0.125), YEL_L, bevel=0.012, segs=1)
    Y(p, 0.05, -0.28, -0.5, z, DGREY, sides=10)                                  # Rohr
    ring(p, 0.055, 0.018, -0.38, z, YEL, seg=10, tseg=5)
    Y(p, 0.06, -0.48, -0.6, z, NAVY, r2=0.1, sides=12)                           # Düse
    hole(p, 0.075, -0.6, z, "FF5A1F")
    sweep(p, [(0, -0.09, 0.22), (0, -0.2, 0.24), (0, -0.34, 0.2), (0, -0.44, 0.15)], 0.02, YEL, sides=6)   # Zündleitung
    flame(p, (0, -0.7, z + 0.01), 1.35)
    p.box((0.085, 0.1, 0.16), (0, -0.24, -0.04), NAVY, bevel=0.035, segs=1)
    grip(p)
    trigger(p)
    finish("m_flame", p, (0, -0.6, z))


def m_water():
    p = Part()
    z = 0.12
    p.box((0.14, 0.4, 0.19), (0, -0.04, z), GRN, bevel=0.07, segs=3)             # Gehäuse
    p.box((0.148, 0.22, 0.035), (0, -0.04, 0.16), "A9F0A0", bevel=0.012, segs=1)
    p.ball(0.125, (0, 0.05, 0.31), CYAN, scale=(0.95, 1.25, 0.95), subdiv=3)     # Wassertank
    p.ball(0.045, (-0.05, -0.0, 0.37), WHITE, scale=(1, 1.4, 0.8), subdiv=1)     # Glanzlicht
    p.cyl(0.05, 0.05, (0, 0.05, 0.43), YEL, sides=10, bevel=0.012, segs=1)
    Y(p, 0.045, 0.3, 0.14, z, YEL, sides=8)                                  # Pumpe
    p.ball(0.06, (0, 0.3, z), ORG, subdiv=2)
    Y(p, 0.072, -0.22, -0.58, z, BLUE, bevel=0.02, sides=14)                     # Rohr
    ring(p, 0.075, 0.02, -0.36, z, GRN, seg=12, tseg=5)
    Y(p, 0.095, -0.56, -0.7, z, YEL, bevel=0.025, sides=14)                      # Düse
    hole(p, 0.07, -0.7, z, "9FE8FF")
    shine(p, -0.26, -0.54, z, 0.072, BLUE_L, w=0.016)
    p.box((0.085, 0.1, 0.16), (0, -0.3, -0.03), GRN_D, bevel=0.035, segs=1)
    grip(p, GRN_D)
    trigger(p)
    finish("m_water", p, (0, -0.7, z))


def m_fireball():
    p = Part()
    z = 0.17
    Y(p, 0.1, 0.2, -0.46, z, RED, r2=0.165, sides=16)                            # Trichterrohr
    p.ball(0.105, (0, 0.2, z), ORG, scale=(1, 0.8, 1), subdiv=2)
    ring(p, 0.115, 0.024, 0.02, z, YEL, seg=14, tseg=5)
    ring(p, 0.165, 0.03, -0.46, z, YEL, seg=16, tseg=6)
    shine(p, -0.04, -0.4, z, 0.14, "FF9A8A")
    p.box((0.05, 0.12, 0.05), (0, 0.06, z + 0.13), YEL, bevel=0.018, segs=1)     # Kimme
    # Feuerball in der Mündung
    p.ball(0.14, (0, -0.55, z + 0.01), ORG, subdiv=3)
    p.ball(0.1, (0, -0.63, z + 0.0), YEL, subdiv=2)
    p.cone(0.09, 0.22, (0, -0.5, z + 0.17), ORG, r=rot(-28, 0, 0), sides=8)
    p.cone(0.06, 0.17, (0.07, -0.44, z + 0.13), "FF5A1F", r=rot(-40, 20, 0), sides=6)
    p.cone(0.06, 0.17, (-0.07, -0.44, z + 0.13), "FF5A1F", r=rot(-40, -20, 0), sides=6)
    p.cone(0.045, 0.12, (0, -0.6, z + 0.14), YEL, r=rot(-15, 0, 0), sides=6)
    p.box((0.1, 0.3, 0.07), (0, -0.08, 0.035), NAVY, bevel=0.03, segs=1)
    p.box((0.085, 0.1, 0.17), (0, -0.26, -0.04), DGREY, bevel=0.035, segs=1)
    grip(p)
    trigger(p)
    finish("m_fireball", p, (0, -0.5, z))


# ------------------------------------------------------------------ Bruno
def b_nailer():
    p = Part()
    z = 0.14
    p.box((0.17, 0.4, 0.22), (0, -0.04, z), BLUE, bevel=0.07, segs=3)            # Gehäuse
    p.box((0.178, 0.2, 0.04), (0, -0.02, 0.19), BLUE_L, bevel=0.014, segs=1)
    p.box((0.13, 0.1, 0.18), (0, 0.2, z), NAVY, bevel=0.04, segs=1)
    p.box((0.2, 0.17, 0.27), (0, -0.33, z), ORG, bevel=0.055)                    # Frontblock
    for sx in (-1, 1):                                                           # Doppellauf
        Y(p, 0.058, -0.38, -0.64, z, GREY, sides=10, x=sx * 0.052)
        Y(p, 0.068, -0.6, -0.7, z, DGREY, bevel=0.015, sides=10, x=sx * 0.052, segs=1)
        hole(p, 0.04, -0.7, z, x=sx * 0.052)
    sweep(p, [(0, 0.12, 0.24), (0, 0.08, 0.34), (0, -0.2, 0.34), (0, -0.28, 0.26)], 0.03, ORG, sides=6)   # Tragebügel
    p.box((0.075, 0.34, 0.075), (0, -0.2, -0.07), YEL, r=rot(-24, 0, 0), bevel=0.025, segs=1)   # Nagelstreifen
    for i in range(4):
        p.box((0.082, 0.02, 0.082), (0, -0.09 - i * 0.07, -0.12 + i * 0.031), GREY_L, r=rot(-24, 0, 0))
    grip(p)
    trigger(p)
    finish("b_nailer", p, (0, -0.7, z))


def b_ball():
    p = Part()
    Y(p, 0.06, 0.28, -0.06, 0, ORG, sides=10)                                    # Griff
    for y in (0.16, 0.08, 0.0):
        ring(p, 0.06, 0.018, y, 0, NAVY, seg=10, tseg=4)
    p.ball(0.07, (0, 0.29, 0), YEL, subdiv=2)
    Y(p, 0.068, -0.03, -0.09, 0, YEL, bevel=0.015, sides=12, segs=1)
    for i in range(3):                                                           # Kette
        p.torus(0.058, 0.024, (0, -0.12 - i * 0.075, 0), GREY_L, r=rot(0, 90, 0) if i % 2 == 0 else None, seg=10, tseg=5)
    p.ball(0.235, (0, -0.5, 0), "5A678F", subdiv=3)                                 # Eisenkugel
    p.ball(0.07, (-0.11, -0.56, 0.12), GREY_L, scale=(0.6, 1.0, 0.8), subdiv=1)  # Glanzlicht
    Y(p, 0.07, -0.27, -0.33, 0, GREY, bevel=0.015, sides=10, segs=1)
    ring(p, 0.215, 0.035, -0.5, 0, GREY, seg=14, tseg=4)                          # Band um die Kugel
    finish("b_ball", p, (0, -0.7, 0), tilt=30)


def b_cement():
    p = Part()
    z = 0.24
    Y(p, 0.11, 0.18, -0.06, z, ORG, r2=0.2, sides=16)                            # Trommel
    Y(p, 0.2, -0.06, -0.3, z, ORG, sides=16)
    Y(p, 0.2, -0.3, -0.56, z, ORG, r2=0.125, sides=16)
    ring(p, 0.2, 0.026, -0.06, z, WHITE, seg=16, tseg=5)
    ring(p, 0.2, 0.026, -0.3, z, WHITE, seg=16, tseg=5)
    Y(p, 0.14, -0.54, -0.62, z, GREY_L, bevel=0.02, sides=14, segs=1)
    shine(p, -0.1, -0.26, z, 0.2, "FFC27A")
    hole(p, 0.105, -0.62, z)
    p.ball(0.07, (0.03, -0.63, z - 0.04), GREY, scale=(1, 0.7, 0.8), subdiv=1)   # Betonklecks
    p.box((0.16, 0.14, 0.2), (0, 0.23, 0.17), YEL, bevel=0.045)                  # Motor
    p.box((0.168, 0.05, 0.208), (0, 0.23, 0.17), NAVY, bevel=0.012, segs=1)
    p.box((0.11, 0.56, 0.07), (0, -0.06, 0.035), DGREY, bevel=0.03, segs=1)      # Rahmen
    p.box((0.09, 0.1, 0.17), (0, -0.28, -0.05), NAVY, bevel=0.035, segs=1)
    grip(p)
    trigger(p)
    finish("b_cement", p, (0, -0.62, z))


# ------------------------------------------------------------------ Ada
def a_spark():
    p = Part()
    Y(p, 0.04, 0.28, -0.4, 0, VIO, sides=10)                                     # Stab
    Y(p, 0.052, 0.12, -0.1, 0, NAVY, bevel=0.02, sides=10)                       # Griff
    p.ball(0.065, (0, 0.29, 0), YEL, subdiv=2)
    ring(p, 0.045, 0.018, -0.2, 0, YEL, seg=10, tseg=5)
    ring(p, 0.045, 0.018, -0.3, 0, YEL, seg=10, tseg=5)
    Y(p, 0.045, -0.36, -0.44, 0, YEL, r2=0.08, sides=10)
    star(p, 0.19, 0.11, (0, -0.56, 0), YEL, r=rot(0, 0, 90), a0=180, color2="FFAE1F")   # Stern
    sparkle(p, 0.06, (0, -0.4, 0.17), WHITE)
    sparkle(p, 0.045, (0, -0.72, 0.16), YEL_L)
    sparkle(p, 0.04, (0, -0.42, -0.15), CYAN)
    finish("a_spark", p, (0, -0.7, 0), tilt=32)


def a_shrink():
    p = Part()
    z = 0.14
    p.ball(0.15, (0, 0.04, z), GRN, scale=(0.82, 1.5, 0.95), subdiv=3)           # Rumpf
    p.ball(0.07, (0, 0.06, z + 0.115), CYAN, subdiv=2)                           # Kuppel
    prism(p, [(-0.12, 0.0), (0.1, 0.0), (0.14, 0.12)], 0.04, (0, 0.16, z + 0.1), YEL, r=rot(0, 0, 90), bevel=0.012, segs=1)  # Flosse
    p.ball(0.06, (0, 0.27, z), YEL, subdiv=2)
    Y(p, 0.055, -0.12, -0.58, z, GRN_D, r2=0.035, sides=10)                      # Strahlrohr
    for y, rr in ((-0.24, 0.115), (-0.37, 0.092), (-0.49, 0.07)):                # Ringe
        ring(p, rr, 0.026, y, z, YEL, seg=14, tseg=6)
    p.ball(0.062, (0, -0.63, z), "B8FF5A", subdiv=2)                             # Strahlkugel
    grip(p, GRN_D)
    trigger(p)
    finish("a_shrink", p, (0, -0.69, z))


def a_cloud():
    p = Part()
    z = 0.2
    Y(p, 0.135, 0.2, -0.4, z, BLUE, sides=16)                                    # Kanonenrohr
    Y(p, 0.156, 0.22, 0.1, z, YEL, bevel=0.025, sides=16, segs=1)
    Y(p, 0.156, -0.3, -0.44, z, YEL, bevel=0.025, sides=16, segs=1)
    Y(p, 0.142, -0.06, -0.14, z, BLUE_D, sides=16)
    p.ball(0.11, (0, 0.23, z), NAVY, scale=(1, 0.75, 1), subdiv=2)
    p.cyl(0.05, 0.08, (0, 0.0, z + 0.16), YEL, sides=10, bevel=0.015, segs=1)    # Knauf
    p.ball(0.055, (0, 0.0, z + 0.22), YEL, subdiv=2)
    hole(p, 0.115, -0.44, z)
    for (x, y, zz), rr in (((0, -0.58, 0.0), 0.185), ((0.1, -0.52, 0.13), 0.13), ((-0.1, -0.54, 0.12), 0.13),
                           ((0, -0.7, 0.12), 0.13), ((0, -0.5, 0.2), 0.11), ((0, -0.68, -0.1), 0.11)):   # Wolke
        p.ball(rr, (x, y, z + zz), WHITE, subdiv=2)
    shine(p, 0.06, -0.26, z, 0.135, BLUE_L)
    p.box((0.11, 0.3, 0.09), (0, -0.04, 0.045), NAVY, bevel=0.035, segs=1)
    grip(p)
    trigger(p)
    finish("a_cloud", p, (0, -0.46, z))


# ------------------------------------------------------------------ Yuki
def y_rifle():
    p = Part()
    z = 0.085
    p.box((0.075, 0.24, 0.11), (0, 0.17, 0.05), NAVY, bevel=0.035)               # Schaft
    p.box((0.085, 0.05, 0.15), (0, 0.275, 0.04), YEL, bevel=0.02, segs=1)
    p.box((0.06, 0.12, 0.035), (0, 0.16, 0.12), YEL, bevel=0.012, segs=1)
    p.box((0.095, 0.3, 0.13), (0, -0.07, z), VIO, bevel=0.045, segs=3)           # Gehäuse
    Y(p, 0.045, -0.2, -0.4, z, VIO_D, bevel=0.015, sides=10, segs=1)
    Y(p, 0.03, -0.38, -0.63, z, GREY, sides=8)                                   # Lauf
    Y(p, 0.045, -0.6, -0.7, z, YEL, bevel=0.012, sides=10, segs=1)
    hole(p, 0.024, -0.7, z)
    zs = 0.215                                                                   # Zielfernrohr
    Y(p, 0.042, 0.08, -0.2, zs, NAVY, sides=12)
    Y(p, 0.042, -0.18, -0.27, zs, YEL, r2=0.062, sides=12)
    Y(p, 0.055, 0.12, 0.06, zs, YEL, bevel=0.012, sides=12, segs=1)
    hole(p, 0.05, -0.27, zs, CYAN)
    Y(p, 0.045, 0.125, 0.115, zs, CYAN, sides=12)
    for y in (0.0, -0.13):
        p.box((0.04, 0.05, 0.07), (0, y, 0.16), GREY_L, bevel=0.012, segs=1)
    p.box((0.06, 0.07, 0.13), (0, -0.14, -0.02), DGREY, bevel=0.02, segs=1)      # Magazin
    grip(p, NAVY, h=0.2, w=0.075, d=0.09)
    trigger(p, -0.04)
    finish("y_rifle", p, (0, -0.7, z), tilt=20)


def bow_curve(n=12, h=0.5, bend=0.3, flick=0.07):
    pts = []
    for i in range(n + 1):
        t = -1.0 + 2.0 * i / n
        y = bend * t * t - flick * max(abs(t) - 0.75, 0.0) / 0.25 * 1.0
        pts.append((0, y, t * h))
    return pts


def arrow(p, y0, y1, color=WOOD, head=GREY_L, feather=RED, r=None, piv=(0, 0, 0)):
    """Pfeil entlang -Y von y0 (hinten) bis y1 (Spitze); r dreht um piv."""
    q = Part()
    Y(q, 0.024, y0, y1 + 0.08, 0, color, sides=6)
    Y(q, 0.058, y1 + 0.12, y1, 0, head, r2=0.0, sides=6)
    for a in (0, 90):
        q.box((0.016, 0.14, 0.12), (0, y0 - 0.09, 0), feather, r=rot(0, a, 0))
    m = Matrix.Translation(Vector(piv)) @ (r if r is not None else Matrix.Identity(4)) @ Matrix.Translation(-Vector(piv))
    for v in q.bm.verts:
        v.co = m @ v.co
    merge(p, q)


def merge(p, q):
    """Hängt die Geometrie von Part q an Part p an."""
    vm = {v: p.bm.verts.new(v.co) for v in q.bm.verts}
    for f in q.bm.faces:
        nf = p.bm.faces.new([vm[v] for v in f.verts])
        nf.smooth = f.smooth
        for l0, l1 in zip(f.loops, nf.loops):
            l1[p.layer] = l0[q.layer]
    q.bm.free()


def y_bow():
    p = Part()
    pts = bow_curve()
    n = len(pts)
    rads = [0.032 + 0.03 * (1 - abs(-1 + 2 * i / (n - 1))) for i in range(n)]
    sweep(p, pts, rads, RED, sides=8)                                            # Bogen
    p.cyl(0.058, 0.2, (0, 0.0, 0), NAVY, sides=10, bevel=0.02)                   # Griff
    for s in (-1, 1):
        p.torus(0.045, 0.018, (0, 0.035, s * 0.17), YEL, r=rot(s * -22, 0, 0), seg=10, tseg=5)
        p.ball(0.04, pts[0 if s < 0 else -1], YEL, subdiv=2)
    sweep(p, [pts[0], (0, 0.26, 0), pts[-1]], 0.015, WHITE, sides=5)             # Sehne
    arrow(p, 0.3, -0.62, feather=WHITE)
    # Feder am oberen Bogenarm
    fe = [(0.0, 0.0), (0.05, -0.05), (0.06, -0.16), (0.0, -0.27), (-0.06, -0.16), (-0.05, -0.05)]
    prism(p, fe, 0.02, (0, 0.2, 0.36), WHITE, r=rot(0, 0, 90) @ rot(0, 25, 0))
    prism(p, [(0.045, -0.2), (0.0, -0.27), (-0.045, -0.2), (0, -0.17)], 0.026, (0, 0.2, 0.36), RED, r=rot(0, 0, 90) @ rot(0, 25, 0))
    finish("y_bow", p, (0, -0.62, 0), tilt=22, yaw=-66)


def y_swarm():
    p = Part()
    pts = bow_curve(h=0.48, bend=0.34, flick=0.12)
    n = len(pts)
    rads = [0.032 + 0.03 * (1 - abs(-1 + 2 * i / (n - 1))) for i in range(n)]
    sweep(p, pts, rads, TEAL, sides=8)
    p.cyl(0.06, 0.18, (0, 0.0, 0), VIO_D, sides=10, bevel=0.02)
    for s in (-1, 1):
        prism(p, [(-0.1, 0.0), (0.1, 0.0), (0.0, 0.11)], 0.035, (0, 0.045, s * 0.2), YEL, r=rot(0, 0, 90) @ rot(0, 90 + s * 62, 0), bevel=0.01, segs=1)   # Zierklingen
        p.ball(0.042, pts[0 if s < 0 else -1], YEL, subdiv=2)
    star(p, 0.07, 0.05, (-0.062, 0, 0), YEL, r=rot(0, 0, 90))
    star(p, 0.07, 0.05, (0.062, 0, 0), YEL, r=rot(0, 0, 90))
    sweep(p, [pts[0], (0, 0.3, 0), pts[-1]], 0.015, WHITE, sides=5)
    for a, fc in ((-16, YEL), (0, PINK), (16, YEL)):                             # drei Pfeile
        arrow(p, 0.33, -0.6, color=VIO, head=YEL_L, feather=fc, r=rot(a, 0, 0), piv=(0, 0.3, 0))
    finish("y_swarm", p, (0, -0.6, 0), tilt=22, yaw=-66)


# ------------------------------------------------------------------ Greta
def g_cracker():
    p = Part()
    z = 0.15
    p.box((0.14, 0.26, 0.19), (0, 0.13, 0.12), RED, bevel=0.06, segs=3)          # Gehäuse
    p.box((0.1, 0.08, 0.16), (0, 0.27, 0.1), NAVY, bevel=0.035, segs=1)
    Y(p, 0.16, 0.0, -0.26, z, RED_D, bevel=0.03, sides=16)                       # Trommel
    ring(p, 0.16, 0.022, -0.06, z, YEL, seg=16, tseg=5)
    ring(p, 0.16, 0.022, -0.2, z, YEL, seg=16, tseg=5)
    Y(p, 0.105, -0.24, -0.6, z, RED, sides=14)                                   # Rohr
    Y(p, 0.13, -0.56, -0.7, z, YEL, bevel=0.03, sides=14)
    hole(p, 0.095, -0.7, z)
    shine(p, -0.3, -0.54, z, 0.105, "FF9A8A", w=0.018)
    for sx in (-1, 1):
        star(p, 0.065, 0.03, (sx * 0.073, 0.13, 0.13), YEL, r=rot(0, 0, 90))
    p.box((0.05, 0.07, 0.06), (0, -0.52, z + 0.12), YEL, bevel=0.015, segs=1)    # Korn
    sweep(p, [(0, 0.2, 0.2), (0, 0.24, 0.3), (0, 0.32, 0.34)], 0.016, WHITE, sides=5)   # Zündschnur
    sparkle(p, 0.06, (0, 0.34, 0.36), YEL)
    p.box((0.085, 0.1, 0.16), (0, -0.36, 0.0), NAVY, bevel=0.035, segs=1)
    grip(p)
    trigger(p)
    finish("g_cracker", p, (0, -0.7, z))


def g_sparkler():
    p = Part()
    Y(p, 0.036, 0.28, -0.24, 0, WHITE, sides=8)                                  # Stab, rot-weiß geringelt
    for i in range(5):
        Y(p, 0.04, 0.24 - i * 0.1, 0.19 - i * 0.1, 0, RED, sides=8)
    p.ball(0.055, (0, 0.29, 0), YEL, subdiv=2)
    Y(p, 0.095, -0.24, -0.52, 0, RED, bevel=0.02, sides=12)                      # Rakete
    Y(p, 0.1, -0.34, -0.4, 0, WHITE, sides=12)
    Y(p, 0.095, -0.52, -0.72, 0, YEL, r2=0.0, sides=12)
    Y(p, 0.06, -0.2, -0.25, 0, DGREY, sides=10)
    for a in (0, 90, 180, 270):                                                  # Flossen
        prism(p, [(0.0, -0.1), (0.0, 0.08), (0.11, 0.12), (0.11, 0.04)], 0.03, (0, -0.32, 0), BLUE,
              r=rot(0, a + 45, 0) @ Matrix.Translation(Vector((0.08, 0, 0))) @ rot(-90, 0, 0) @ rot(0, 0, 0))
    sparkle(p, 0.07, (0, -0.12, 0.16), YEL)                                      # Funken
    sparkle(p, 0.05, (0, -0.02, 0.1), WHITE)
    sparkle(p, 0.055, (0, -0.1, -0.15), YEL_L)
    sparkle(p, 0.04, (0, 0.02, -0.09), ORG)
    finish("g_sparkler", p, (0, -0.72, 0), tilt=32)


def g_cake():
    p = Part()
    z = 0.12
    p.box((0.15, 0.36, 0.19), (0, 0.0, z), PINK, bevel=0.07, segs=3)             # Gehäuse
    p.box((0.16, 0.3, 0.05), (0, 0.0, 0.215), WHITE, bevel=0.02, segs=1)         # Sahnehaube
    for y in (-0.1, 0.0, 0.1):
        p.ball(0.045, (0, y, 0.25), WHITE, subdiv=1)
    p.box((0.11, 0.09, 0.15), (0, 0.2, 0.11), PINK_D, bevel=0.035, segs=1)
    p.ball(0.045, (0, 0.0, 0.29), RED, subdiv=1)
    Y(p, 0.06, -0.16, -0.26, z, YEL, bevel=0.015, sides=10, segs=1)
    # Tortenheber-Blatt
    prism(p, [(-0.07, 0.26), (0.07, 0.26), (0.17, -0.02), (0.0, -0.24), (-0.17, -0.02)], 0.03, (0, -0.46, 0.08), GREY_L, r=rot(-90, 0, 0), bevel=0.01, segs=1)
    # Tortenstück (Keil, Spitze nach vorn)
    tri = [(-0.13, 0.17), (0.13, 0.17), (0.0, -0.2)]
    for zz, hh, cc in ((0.135, 0.07, "C98548"), (0.185, 0.035, WHITE), (0.235, 0.07, "C98548"), (0.29, 0.045, PINK)):
        prism(p, tri, hh, (0, -0.47, zz), cc, r=rot(-90, 0, 0))
    p.ball(0.05, (0, -0.4, 0.34), RED, subdiv=2)
    p.ball(0.04, (0.0, -0.33, 0.32), WHITE, subdiv=1)
    grip(p, PINK_D)
    trigger(p)
    finish("g_cake", p, (0, -0.7, z), yaw=-52, pitch=20)


ALL = dict(j_rifle=j_rifle, j_parcel=j_parcel, j_burst=j_burst, m_flame=m_flame, m_water=m_water, m_fireball=m_fireball,
           b_nailer=b_nailer, b_ball=b_ball, b_cement=b_cement, a_spark=a_spark, a_shrink=a_shrink, a_cloud=a_cloud,
           y_rifle=y_rifle, y_bow=y_bow, y_swarm=y_swarm, g_cracker=g_cracker, g_sparkler=g_sparkler, g_cake=g_cake)


def args():
    a = sys.argv[1:]
    if "--" in a:
        a = a[a.index("--") + 1:]
    return [x for x in a if not x.startswith("-") and not x.endswith(".py")]


if __name__ == "__main__":
    want = [n[2:] if n.startswith("w_") else n for n in args()] or list(ALL)
    for n in want:
        ALL[n]()
        print("ok w_%s  %d Dreiecke" % (n, TRIS[n]))
