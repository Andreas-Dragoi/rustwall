"""Fahrzeuge im runden Spielzeug-Stil des Garagen-Bildes. Vorderseite = -Y.
Objekte: body, wheel_* (Ursprung in der Achse, dreht um X), fan (dreht um Y), Leerobjekt seat."""
import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from kit import *


def wheel(root, name, x, y, r, w=0.34, hub="C9CED8"):
    p = Part()
    p.cyl(r, w, (0, 0, 0), "tire", r=rot(0, 90, 0), sides=18, bevel=r * 0.28, segs=3)
    for i in range(10):                                   # Stollen
        a = math.radians(i * 36)
        p.box((w * 0.9, 0.12, 0.07), (0, math.cos(a) * r, math.sin(a) * r), "14161C", r=rot(i * 36 + 90, 0, 0) @ rot(0, 0, 0), bevel=0.02)
    p.cyl(r * 0.5, w + 0.04, (0, 0, 0), hub, r=rot(0, 90, 0), sides=12, bevel=0.03)
    p.cyl(r * 0.2, w + 0.1, (0, 0, 0), "5E6678", r=rot(0, 90, 0), sides=8)
    return p.build(name, root, (x, y, r))


def lights(root, pts, color="FFE9A0", size=(0.22, 0.06, 0.14)):
    p = Part()
    for q in pts:
        p.box(size, q, color, bevel=0.03)
    p.build("lamp_glow", root)


def quad():
    reset(); root = empty("v_quad")
    b = Part()
    red, dk = "E23B3B", "2A2D36"
    b.box((0.9, 1.9, 0.42), (0, 0, 0.72), red, bevel=0.16, segs=4)
    b.box((1.5, 0.6, 0.16), (0, -0.62, 0.86), red, bevel=0.07, segs=3)       # Kotflügel vorn
    b.box((1.5, 0.6, 0.16), (0, 0.62, 0.86), red, bevel=0.07, segs=3)
    b.box((0.6, 0.8, 0.22), (0, 0.25, 1.02), dk, bevel=0.1, segs=3)          # Sitz
    b.box((0.7, 0.5, 0.3), (0, -0.55, 1.0), shade(red, 0.85), bevel=0.12, segs=3)
    b.cyl(0.04, 0.5, (0, -0.5, 1.3), "steel", r=rot(-25, 0, 0))
    b.cyl(0.035, 1.0, (0, -0.4, 1.52), dk, r=rot(0, 90, 0))                  # Lenker
    b.box((0.16, 0.14, 0.14), (0.5, -0.4, 1.52), dk, bevel=0.04)
    b.box((0.16, 0.14, 0.14), (-0.5, -0.4, 1.52), dk, bevel=0.04)
    b.box((0.8, 0.12, 0.12), (0, -1.0, 0.6), "steel", bevel=0.04)            # Stoßstange
    b.box((0.7, 0.5, 0.06), (0, 0.95, 0.98), "steel", bevel=0.02)            # Gepäckträger
    b.build("body", root)
    lights(root, [(0.22, -0.97, 0.86), (-0.22, -0.97, 0.86)])
    for n, x, y in (("wheel_fl", -0.72, -0.62), ("wheel_fr", 0.72, -0.62), ("wheel_bl", -0.72, 0.62), ("wheel_br", 0.72, 0.62)):
        wheel(root, n, x, y, 0.46, 0.36)
    empty("seat", root, (0, 0.25, 0.86))
    save("v_quad"); icon("v_quad", 384, yaw=-40, pitch=22)


def bike():
    reset(); root = empty("v_bike")
    b = Part()
    yl, dk = "F2B21E", "2A2D36"
    b.box((0.42, 1.5, 0.4), (-0.35, 0, 0.78), yl, bevel=0.14, segs=4)        # Tank/Rumpf
    b.box((0.4, 0.7, 0.18), (-0.35, 0.3, 1.04), "7A4522", bevel=0.08, segs=3)  # Sattel
    b.cyl(0.04, 0.7, (-0.35, -0.72, 0.95), "steel", r=rot(-28, 0, 0))        # Gabel
    b.cyl(0.035, 0.9, (-0.35, -0.6, 1.36), dk, r=rot(0, 90, 0))
    b.box((0.3, 0.2, 0.26), (-0.35, -0.86, 1.12), yl, bevel=0.08)
    b.cyl(0.07, 0.9, (-0.62, 0.55, 0.5), "steel", r=rot(90, 0, 0), bevel=0.02)  # Auspuff
    # Beiwagen
    b.box((0.85, 1.5, 0.5), (0.72, -0.05, 0.62), shade(yl, 0.92), bevel=0.22, segs=4)
    b.box((0.6, 0.7, 0.2), (0.72, 0.15, 0.88), dk, bevel=0.08, segs=3)
    b.box((0.62, 0.06, 0.3), (0.72, -0.42, 1.0), "8FD3F5", bevel=0.03, r=rot(-20, 0, 0))
    b.box((0.5, 0.1, 0.1), (0.2, 0.0, 0.5), "steel", bevel=0.03)
    b.build("body", root)
    lights(root, [(-0.35, -0.98, 1.12)], size=(0.2, 0.06, 0.2))
    wheel(root, "wheel_fl", -0.35, -0.95, 0.45, 0.22)
    wheel(root, "wheel_bl", -0.35, 0.85, 0.45, 0.24)
    wheel(root, "wheel_br", 1.22, 0.1, 0.38, 0.2)
    empty("seat", root, (-0.35, 0.3, 0.92))
    save("v_bike"); icon("v_bike", 384, yaw=-40, pitch=22)


def buggy():
    reset(); root = empty("v_buggy")
    b = Part()
    og, dk = "F28A1E", "23262E"
    b.box((1.6, 2.7, 0.5), (0, 0, 0.8), og, bevel=0.2, segs=4)
    b.box((1.3, 0.9, 0.3), (0, -0.95, 1.02), shade(og, 1.08), bevel=0.14, segs=3)  # Haube
    b.box((1.2, 0.9, 0.2), (0, 0.15, 0.98), dk, bevel=0.06)                     # Sitzwanne
    for sx in (-0.72, 0.72):                                                    # Überrollkäfig
        b.cyl(0.06, 1.0, (sx, -0.3, 1.5), dk, r=rot(-18, 0, 0))
        b.cyl(0.06, 1.0, (sx, 0.7, 1.5), dk, r=rot(12, 0, 0))
        b.cyl(0.06, 1.25, (sx, 0.2, 1.98), dk, r=rot(90, 0, 0))
    b.cyl(0.06, 1.5, (0, -0.46, 1.96), dk, r=rot(0, 90, 0))
    b.cyl(0.06, 1.5, (0, 0.82, 1.96), dk, r=rot(0, 90, 0))
    b.box((1.8, 0.2, 0.2), (0, -1.45, 0.66), "steel", bevel=0.07)               # Rammbügel
    b.box((1.2, 0.5, 0.36), (0, 1.2, 1.12), dk, bevel=0.1)                      # Motor
    b.cyl(0.07, 0.5, (0.35, 1.5, 1.3), "steel", r=rot(60, 0, 0))
    b.cyl(0.07, 0.5, (-0.35, 1.5, 1.3), "steel", r=rot(60, 0, 0))
    b.build("body", root)
    lights(root, [(0.45, -1.42, 0.98), (-0.45, -1.42, 0.98)], size=(0.26, 0.08, 0.2))
    for n, x, y in (("wheel_fl", -0.98, -0.95), ("wheel_fr", 0.98, -0.95), ("wheel_bl", -0.98, 0.95), ("wheel_br", 0.98, 0.95)):
        wheel(root, n, x, y, 0.56, 0.42, hub="F2B21E")
    empty("seat", root, (0, 0.15, 0.78))
    save("v_buggy"); icon("v_buggy", 384, yaw=-40, pitch=22)


def pickup():
    reset(); root = empty("v_pickup")
    b = Part()
    bl, dk = "3F9BE8", "23262E"
    b.box((1.9, 3.7, 0.62), (0, 0, 0.92), bl, bevel=0.2, segs=4)
    b.box((1.7, 1.3, 0.72), (0, -0.55, 1.52), shade(bl, 1.06), bevel=0.24, segs=4)  # Kabine
    b.box((1.72, 0.9, 0.36), (0, -0.62, 1.58), "BFE6FA", bevel=0.1)                 # Fenster
    b.box((1.5, 0.06, 0.4), (0, -1.2, 1.56), "BFE6FA", bevel=0.02, r=rot(-18, 0, 0))
    b.box((1.6, 1.5, 0.12), (0, 1.0, 1.26), shade(bl, 0.7), bevel=0.03)             # Ladefläche
    for sx in (-0.9, 0.9):
        b.box((0.12, 1.6, 0.34), (sx, 1.0, 1.4), bl, bevel=0.05)
    b.box((1.9, 0.12, 0.34), (0, 1.8, 1.4), bl, bevel=0.05)
    b.box((2.0, 0.22, 0.22), (0, -1.9, 0.72), "steel", bevel=0.08)
    b.box((1.2, 0.08, 0.3), (0, -1.86, 1.0), dk, bevel=0.03)                        # Kühlergrill
    b.build("body", root)
    lights(root, [(0.68, -1.87, 1.0), (-0.68, -1.87, 1.0)], size=(0.3, 0.08, 0.22))
    for n, x, y in (("wheel_fl", -1.0, -1.2), ("wheel_fr", 1.0, -1.2), ("wheel_bl", -1.0, 1.2), ("wheel_br", 1.0, 1.2)):
        wheel(root, n, x, y, 0.55, 0.4)
    empty("seat", root, (0, -0.55, 1.2))
    empty("turret", root, (0, 1.0, 1.32))
    save("v_pickup"); icon("v_pickup", 384, yaw=-40, pitch=22)


def hover():
    reset(); root = empty("v_hover")
    b = Part()
    og, dk = "F28A1E", "33363F"
    b.box((2.5, 3.7, 0.62), (0, 0, 0.42), dk, bevel=0.3, segs=5)                 # Luftkissen
    b.box((2.3, 3.5, 0.1), (0, 0, 0.7), "23262E", bevel=0.04)
    b.box((1.8, 2.5, 0.34), (0, -0.2, 0.9), og, bevel=0.15, segs=4)              # Deck
    b.box((1.1, 1.0, 0.3), (0, -0.2, 1.16), shade(og, 1.1), bevel=0.12, segs=3)  # Aufbau
    b.cyl(0.035, 0.7, (0.5, -1.0, 1.4), "3FD2F5")                                # Antenne
    # Mantel des Propellers
    b.torus(0.95, 0.16, (0, 1.25, 1.55), "9AA4B8", r=rot(90, 0, 0), seg=24, tseg=8)
    b.cyl(0.14, 0.9, (0, 1.25, 0.9), "7C879C", bevel=0.03)
    b.box((1.9, 0.08, 0.08), (0, 1.3, 1.55), "5E6678")
    b.build("body", root)
    f = Part()
    f.cyl(0.2, 0.22, (0, 0, 0), "5E6678", r=rot(90, 0, 0), sides=12, bevel=0.04)
    for i in range(6):
        a = i * 60
        f.box((0.26, 0.05, 0.78), (math.sin(math.radians(a)) * 0.46, 0, math.cos(math.radians(a)) * 0.46), "2A2D36", r=rot(0, a, 0) @ rot(0, 0, 22), bevel=0.02)
    f.build("fan", root, (0, 1.2, 1.55))
    lights(root, [(0.7, -1.82, 0.5), (-0.7, -1.82, 0.5)], size=(0.3, 0.08, 0.16))
    empty("seat", root, (0, -0.2, 1.1))
    save("v_hover"); icon("v_hover", 384, yaw=-40, pitch=22)


if __name__ == "__main__":
    for f in (quad, bike, buggy, pickup, hover):
        f(); print("ok", f.__name__)
