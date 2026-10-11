"""Die neun Schleime e_0 … e_8. Ein Objekt `body` (Helm-Schleim zusätzlich `helm`), Vorderseite -Y,
Radius ca. 0,5 m, sitzt auf dem Boden. Aufruf: python3 blender/enemies.py [e_0 ...]"""
import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from kit import *
from rw_util import *

GREEN, GREEN_L = "9DC42C", "D3EA5A"
INK = "1B2410"


class Blob:
    """Runder Schleimkörper (Ellipsoid) mit Hilfen, um Teile auf seine Oberfläche zu setzen."""

    def __init__(self, p, color, rx=0.5, ry=0.5, rz=0.425, y0=0.0):
        self.p, self.rx, self.ry, self.rz, self.y0, self.cz = p, rx, ry, rz, y0, rz
        self.color = color
        p.ball(1.0, (0, y0, rz), color, scale=(rx, ry, rz), subdiv=3)

    def pt(self, x, z, out=0.0, back=False):
        u, w = x / self.rx, (z - self.cz) / self.rz
        v = math.sqrt(max(1.0 - u * u - w * w, 0.0)) * (1.0 if back else -1.0)
        n = Vector((u / self.rx, v / self.ry, w / self.rz)).normalized()
        return Vector((x, self.y0 + v * self.ry, z)) + n * out, n

    def stick(self, x, z, radius, color, flat=0.4, sx=1.0, sz=1.0, subdiv=2, out=0.0, back=False, roll=0.0):
        """Flache Linse auf der Oberfläche (Auge, Wange, Glanzlicht)."""
        q, n = self.pt(x, z, out, back)
        self.p.ball(radius, (0, 0, 0), color, r=T(*q) @ face_to(n) @ rot(0, 0, roll), scale=(sx, sz, flat), subdiv=subdiv)

    def slab(self, x, z, size, color, roll=0.0, out=0.0, bevel=0.015):
        q, n = self.pt(x, z, out)
        self.p.box(size, (0, 0, 0), color, r=T(*q) @ face_to(n) @ rot(0, 0, roll), bevel=bevel, segs=1)

    def highlight(self, x=-0.2, z=None, k=1.0):
        z = self.cz + self.rz * 0.62 if z is None else z
        self.stick(x, z, 0.1 * k, mix(self.color, "FFFFFF", 0.3), flat=0.2, sx=1.3, sz=0.75, roll=-25)

    def face(self, z=None, w=1.0, dx=0.17, angry=False, mouth="smile", cheeks=True, mz=None):
        z = self.cz + 0.05 if z is None else z
        for s in (-1, 1):
            self.stick(dx * w * s, z, 0.088 * w, INK, flat=0.42, sz=1.2, out=-0.004)
            q, n = self.pt(dx * w * s + 0.028 * w, z + 0.045 * w, 0.033 * w)
            self.p.ball(0.03 * w, tuple(q), "FFFFFF", subdiv=1)
            if angry:
                self.slab(dx * w * s * 0.98, z + 0.13 * w, (0.2 * w, 0.06 * w, 0.05), INK, roll=26 * s, out=0.022)
            if cheeks:
                self.stick((dx + 0.135) * w * s, z - 0.1 * w, 0.045 * w, "F58A8A", flat=0.3, subdiv=1, out=0.0)
        mz = z - 0.17 * w if mz is None else mz
        if mouth == "smile":
            self.stick(0, mz, 0.075 * w, "4A1420", flat=0.4, sx=1.15, sz=0.8)
            q, n = self.pt(0, mz - 0.025 * w, 0.022 * w)
            self.p.ball(0.036 * w, tuple(q), "F27A8C", scale=(1.2, 0.8, 0.7), subdiv=1)
        elif mouth == "grim":
            self.slab(0, mz, (0.2 * w, 0.045 * w, 0.04), INK, out=0.012)
        elif mouth == "o":
            self.stick(0, mz, 0.05 * w, "4A1420", flat=0.5)

    def feet(self, k=1.0, col=None):
        c = shade(self.color, 0.82) if col is None else col
        for s in (-1, 1):
            self.p.ball(0.13 * k, (0.2 * s * self.rx / 0.5, self.y0 - 0.3 * self.ry / 0.5, 0.075 * k), c, scale=(1.0, 1.35, 0.58), subdiv=2)

    def arms(self, z=None, k=1.0):
        z = self.cz - 0.05 if z is None else z
        for s in (-1, 1):
            q, n = self.pt(self.rx * 0.93 * s, z)
            self.p.ball(0.085 * k, (q.x + 0.0 * s, q.y - 0.14, q.z), shade(self.color, 0.9), scale=(1.1, 1.0, 0.85), subdiv=2)


def done(name, p, extra=None, yaw=-24, pitch=14):
    root = empty(name)
    p.build("body", root)
    if extra:
        extra(root)
    finish(name, yaw=yaw, pitch=pitch)


def e_0():
    reset(); p = Part()
    b = Blob(p, GREEN)
    b.highlight(); b.face(); b.feet(); b.arms()
    done("e_0", p)


def e_1():
    reset(); p = Part()
    yl = "DDE646"
    b = Blob(p, yl, rx=0.4, ry=0.54, rz=0.36)
    # nach hinten gekämmte Stacheln + spitzer Schwanz: sieht schnell aus
    for i, (y, z, h, a) in enumerate(((-0.12, 0.66, 0.34, -38), (0.1, 0.66, 0.42, -52), (0.3, 0.56, 0.36, -66))):
        p.cone(0.13, h, (0, y + 0.08, z + 0.05), "F6F79A", r=rot(a, 0, 0), sides=6)
    p.cone(0.15, 0.4, (0, 0.62, 0.3), shade(yl, 0.9), r=rot(-100, 0, 0), sides=6)
    for s in (-1, 1):                                    # kleine Flossen wie Rennstreifen
        p.cone(0.08, 0.3, (0.37 * s, 0.22, 0.34), "F6F79A", r=rot(-80, 0, -22 * s), sides=5)
    b.highlight(x=-0.15, k=0.8); b.face(z=0.42, w=0.86, angry=True, mouth="smile", cheeks=False); b.feet(0.85)
    done("e_1", p)


def e_2():
    reset(); p = Part()
    og = "F08A26"
    b = Blob(p, og)
    b.face(z=0.42, angry=True, mouth="o"); b.feet()
    # rotes Sprengfass auf dem Rücken, mit Gurt und Lunte
    m = T(0, 0.2, 0.74) @ rot(-18, 0, 0)
    p.cyl(0.27, 0.56, (0, 0, 0), "D8343A", r=m, sides=12, bevel=0.06)
    p.cyl(0.29, 0.14, (0, 0, 0), "FFD23E", r=m, sides=12)
    p.cyl(0.03, 0.2, (0, 0, 0), "3A2A20", r=m @ T(0.05, 0, 0.36) @ rot(0, 20, 0), sides=5)
    p.ball(0.06, (0, 0, 0), "FFE25A", r=m @ T(0.1, 0, 0.47), subdiv=1)
    done("e_2", p)


def e_3():
    reset(); p = Part()
    dg = "5E8F22"
    b = Blob(p, dg, rx=0.52, ry=0.52, rz=0.44)
    for i, (x, y, z, s, a) in enumerate(((0.0, 0.1, 0.86, 0.32, 20), (-0.29, 0.06, 0.74, 0.26, 50), (0.3, 0.08, 0.74, 0.28, -30),
                                         (0.02, 0.4, 0.58, 0.26, 70), (-0.3, 0.34, 0.48, 0.2, 10), (0.32, 0.34, 0.46, 0.2, 40))):
        p.box((s, s * 0.95, s * 0.85), (x, y, z), ("9A8F96", "837985", "ADA3A8")[i % 3], r=rot(12 * (i % 3), 8 * i, a), bevel=s * 0.22, segs=1)
    b.face(z=0.5, w=0.95, angry=True, mouth="grim", cheeks=False, mz=0.3)
    for s in (-1, 1):                                    # Hauer
        q, n = b.pt(0.15 * s, 0.31, 0.0)
        p.cone(0.055, 0.2, (q.x, q.y - 0.03, q.z + 0.07), "FFFDF0", r=rot(8, 6 * s, 0), sides=6)
    b.feet(1.1)
    done("e_3", p)


def e_4():
    reset(); p = Part()
    tq = "35B79A"
    b = Blob(p, tq, rx=0.47, ry=0.47, rz=0.43)
    b.highlight()
    b.face(z=0.6, w=0.85, dx=0.18, mouth="none", cheeks=False)
    # Rüssel-Mund zum Spucken
    p.cyl(0.19, 0.3, (0, -0.5, 0.33), "23876F", r=AX_Y, r2=0.15, sides=12)
    p.torus(0.155, 0.045, (0, -0.65, 0.33), "1C6E5B", r=AX_Y, seg=10, tseg=4)
    p.cyl(0.12, 0.02, (0, -0.655, 0.33), "0E2E28", r=AX_Y, sides=10)
    for x, y, z, r in ((0.2, 0.22, 0.82, 0.13), (-0.2, 0.3, 0.72, 0.1), (0.0, 0.42, 0.62, 0.08)):   # Giftblasen
        p.ball(r, (x, y, z), "CDF24A", subdiv=2)
    b.feet()
    done("e_4", p)


def e_5():
    reset(); p = Part()
    b = Blob(p, GREEN)
    b.face(z=0.38, mouth="smile"); b.feet()

    def helm(root):
        h = Part()
        h.cyl(0.52, 0.16, (0, 0, 0.64), "8A94A8", sides=14)
        h.cyl(0.52, 0.26, (0, 0, 0.83), "8A94A8", r2=0.24, sides=14, bevel=0.09, segs=2)
        h.cyl(0.6, 0.07, (0, 0, 0.6), "6C7689", sides=14, bevel=0.03, segs=1)
        h.box((0.09, 0.5, 0.14), (0, 0.0, 0.97), "D54144", bevel=0.04, segs=1)
        h.build("helm", root)
    done("e_5", p, helm)


def e_6():
    reset(); p = Part()
    lg = "B4E070"
    b = Blob(p, lg, rx=0.42, ry=0.42, rz=0.38)
    b.highlight(k=0.85); b.face(z=0.4, w=0.9)
    for s in (-1, 1):                                    # Flügelchen: je zwei Blätter
        p.ball(1.0, (0, 0, 0), "F1FADC", r=T(0.56 * s, 0.1, 0.64) @ rot(0, -32 * s, 14 * s), scale=(0.34, 0.2, 0.045), subdiv=2)
        p.ball(1.0, (0, 0, 0), "DDF0BE", r=T(0.5 * s, 0.14, 0.44) @ rot(0, 6 * s, 20 * s), scale=(0.24, 0.15, 0.04), subdiv=2)
    for s in (-1, 1):                                    # Fühler
        p.cyl(0.018, 0.2, (0.1 * s, -0.05, 0.84), shade(lg, 0.7), r=rot(10, 18 * s, 0), sides=4)
        p.ball(0.045, (0.135 * s, -0.07, 0.95), "FFE25A", subdiv=1)
    done("e_6", p)


def e_7():
    reset(); p = Part()
    pu, hat = "9670DC", "5A3FA0"
    b = Blob(p, pu, rx=0.48, ry=0.48, rz=0.43)
    b.face(z=0.42, w=0.92, mouth="smile"); b.feet()
    m = T(0, 0.03, 0.7) @ rot(-8, 0, 0)
    p.cyl(0.46, 0.05, (0, 0, 0), hat, r=m, sides=14, bevel=0.02, segs=1)          # Krempe
    p.cyl(0.3, 0.36, (0, 0, 0), hat, r=m @ T(0, 0, 0.19), r2=0.13, sides=10)
    p.cone(0.13, 0.3, (0, 0, 0), hat, r=m @ T(0, 0.05, 0.48) @ rot(-35, 0, 0), sides=8)  # geknickte Spitze
    p.cyl(0.305, 0.07, (0, 0, 0), "FFD23E", r=m @ T(0, 0, 0.07), r2=0.28, sides=10)   # Hutband
    star(p, (0, 0, 0), 0.09, "FFD23E", 0.03, r=m @ T(0, -0.24, 0.22) @ rot(72, 0, 0))
    # Stab mit leuchtender Kugel
    p.cyl(0.035, 1.05, (0.62, -0.12, 0.53), "7A4522", r=rot(0, 6, 0), sides=6)
    p.ball(0.12, (0.675, -0.12, 1.12), "CDF24A", subdiv=2)
    done("e_7", p)


def e_8():
    reset(); p = Part()
    kg = "7FA524"
    b = Blob(p, kg, rx=0.53, ry=0.53, rz=0.44)
    b.highlight(x=-0.26, z=0.66, k=0.9)
    b.face(z=0.5, w=0.9, dx=0.19, angry=True, mouth="none", cheeks=False)
    # breites Maul mit Zähnen
    b.stick(0, 0.28, 0.17, "3A0F18", flat=0.3, sx=1.25, sz=0.55)
    for i in range(4):
        x = -0.135 + i * 0.09
        b.slab(x, 0.335, (0.07, 0.085, 0.05), "FFFDF0", out=0.022, bevel=0.0)
    for s in (-1, 1):
        q, n = b.pt(0.2 * s, 0.25, 0.0)
        p.cone(0.05, 0.17, (q.x, q.y - 0.03, q.z + 0.05), "FFFDF0", r=rot(8, 8 * s, 0), sides=6)
    # goldene Krone
    gold = "FFCB2E"
    p.cyl(0.25, 0.14, (0, 0.02, 0.88), gold, r2=0.29, sides=12)
    for i in range(6):
        a = math.radians(i * 60 + 30)
        x, y = math.sin(a) * 0.265, -math.cos(a) * 0.265 + 0.02
        p.cone(0.075, 0.2, (x, y, 1.03), gold, sides=4, r=rot(0, 0, i * 60 + 30))
    for i, c in enumerate(("E23B3B", "3FA8F5", "E23B3B")):
        a = math.radians(-60 + i * 60)
        p.ball(0.045, (math.sin(a) * 0.275, -math.cos(a) * 0.275 + 0.02, 0.88), c, subdiv=1)
    b.feet(1.1)
    done("e_8", p)


TABLE = {"e_0": e_0, "e_1": e_1, "e_2": e_2, "e_3": e_3, "e_4": e_4, "e_5": e_5, "e_6": e_6, "e_7": e_7, "e_8": e_8}

if __name__ == "__main__":
    run(TABLE, sys.argv)
