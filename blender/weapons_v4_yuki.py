"""V4 Waffen-Arsenal – Yuki (Falknerin, Wind): Holz, Grün, Federn, Eis, Wind.
Aufruf: python3 blender/weapons_v4_yuki.py [y_sling ...]"""
import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from weapons_v4_kit import *
from weapons_v4_jona import boomerang

FEATHER = [(0.0, 0.0), (0.05, -0.05), (0.06, -0.16), (0.0, -0.27), (-0.06, -0.16), (-0.05, -0.05)]


def feather(p, loc, r, col=WHITE, tip=RED, s=1.0):
    prism(p, [(x * s, z * s) for x, z in FEATHER], 0.02, loc, col, r=r)
    prism(p, [(0.045 * s, -0.2 * s), (0.0, -0.27 * s), (-0.045 * s, -0.2 * s), (0, -0.17 * s)], 0.026, loc, tip, r=r)


def bow(p, col, h=0.5, bend=0.3, grip_col=NAVY, flick=0.07, string=0.26):
    pts = bow_curve(h=h, bend=bend, flick=flick)
    n = len(pts)
    rads = [0.03 + 0.028 * (1 - abs(-1 + 2 * i / (n - 1))) for i in range(n)]
    sweep(p, pts, rads, col, sides=8)
    p.cyl(0.056, 0.2, (0, 0.0, 0), grip_col, sides=10, bevel=0.02)
    sweep(p, [pts[0], (0, string, 0), pts[-1]], 0.013, WHITE, sides=5)
    return pts


def y_sling():
    p = Part()
    Y(p, 0.04, 0.24, -0.1, 0, WOOD, sides=10)
    for sx in (-1, 1):
        sweep(p, [(0, -0.1, 0), (sx * 0.06, -0.2, 0.02), (sx * 0.1, -0.32, 0.06)], 0.032, WOOD, sides=8)
        p.ball(0.035, (sx * 0.1, -0.32, 0.06), LEAF, subdiv=1)
    sweep(p, [(-0.1, -0.32, 0.06), (-0.04, -0.4, 0.06), (0.04, -0.4, 0.06), (0.1, -0.32, 0.06)], 0.012, BROWN, sides=5)
    p.ball(0.05, (0, -0.42, 0.06), GREY_L, scale=(1, 0.9, 0.8), subdiv=2)          # Kiesel
    for y in (0.16, 0.06):
        ring(p, 0.043, 0.012, y, 0, LEAF, seg=10, tseg=4)
    feather(p, (0.05, 0.2, 0.02), rot(0, 0, 90) @ rot(0, 30, 0), WHITE, "3FA35A", 0.7)
    done("y_sling", p, (0, -0.46, 0.06), tilt=24, pitch=30)


def y_crossbow():
    p = Part()
    z = 0.1
    p.box((0.09, 0.6, 0.1), (0, -0.05, z), WOOD, bevel=0.03, segs=2)              # Säule
    p.box((0.1, 0.18, 0.15), (0, 0.18, 0.06), BROWN, bevel=0.04, segs=1)
    pts = [(x, -0.38 + 0.12 * (x / 0.3) ** 2, z) for x in (-0.3, -0.2, -0.1, 0.0, 0.1, 0.2, 0.3)]   # Bogen quer
    sweep(p, pts, 0.03, "3FA35A", sides=8, ref=(0, 0, 1))
    sweep(p, [pts[0], (0, -0.1, z + 0.02), pts[-1]], 0.01, WHITE, sides=4, ref=(0, 0, 1))
    Y(p, 0.016, -0.06, -0.56, z + 0.06, BROWN, sides=6)                           # Bolzen
    Y(p, 0.035, -0.54, -0.62, z + 0.06, GREY_L, r2=0.0, sides=6)
    for a in (0, 90):
        p.box((0.012, 0.08, 0.06), (0, -0.04, z + 0.06), WHITE, r=rot(0, a, 0))
    grip(p, BROWN)
    trigger(p, 0.0)
    done("y_crossbow", p, (0, -0.62, z + 0.06), tilt=10, pitch=45)


def y_spear():
    p = Part()
    Y(p, 0.03, 0.3, -0.5, 0, WOOD, sides=8)
    for y in (0.0, -0.1):
        ring(p, 0.034, 0.012, y, 0, LEAF, seg=10, tseg=4)
    p.box((0.06, 0.06, 0.06), (0, -0.5, 0), BROWN, bevel=0.015, segs=1)
    blade(p, [(0.0, 0.0), (0.1, 0.08), (0.07, 0.22), (0.0, 0.3), (-0.07, 0.22), (-0.1, 0.08)], 0.03, (0, -0.52, 0.0), GREY_L, r=rot(90, 0, 0))   # Blatt
    p.box((0.02, 0.24, 0.035), (0, -0.62, 0.0), WHITE, bevel=0.008, segs=1)
    for a in (-30, 30):                                                             # Federn am Schaft
        feather(p, (0.0, -0.44, -0.04), rot(0, a, 0) @ rot(0, 0, 90) @ rot(0, 70, 0), WHITE, "3FA35A", 0.6)
    p.ball(0.04, (0, 0.31, 0), GREY, subdiv=1)
    done("y_spear", p, (0, -0.78, 0), tilt=16, pitch=45)


def y_boomerang():
    p = Part()
    boomerang(p, WOOD, "3FA35A", WHITE, span=0.27, depth=0.42, w=0.12)
    feather(p, (0.27, 0.02, 0.0), rot(90, 0, 0) @ rot(0, 0, 0), WHITE, RED, 0.6)
    feather(p, (-0.27, 0.02, 0.0), rot(90, 0, 0), WHITE, RED, 0.6)
    done("y_boomerang", p, (0, -0.42, 0), tilt=0, yaw=-20, pitch=62)


def y_blowpipe():
    p = Part()
    z = 0.08
    Y(p, 0.035, 0.3, -0.7, z, "B5A24A", sides=10)                                  # Bambusrohr
    for y in (0.16, -0.04, -0.24, -0.44, -0.62):
        ring(p, 0.038, 0.012, y, z, "8C7A2E", seg=10, tseg=4)
    Y(p, 0.05, 0.3, 0.24, z, LEAF, sides=10)                                        # Mundstück
    hole(p, 0.022, -0.7, z)
    sweep(p, [(0, 0.1, z - 0.03), (0.04, 0.06, z - 0.12), (0.06, -0.02, z - 0.16)], 0.012, BROWN, sides=4)   # Pfeiltasche
    p.box((0.06, 0.12, 0.08), (0.06, -0.05, z - 0.18), BROWN, bevel=0.02, segs=1)
    for i in range(3):
        Y(p, 0.008, -0.0 - i * 0.02, -0.12 - i * 0.02, z - 0.1, LEAF, sides=4, x=0.06 + (i - 1) * 0.015)
    p.box((0.075, 0.08, 0.14), (0, 0.0, z - 0.08), BROWN, bevel=0.02, segs=1)
    done("y_blowpipe", p, (0, -0.7, z), tilt=18)


def y_fan():
    p = Part()
    p.cyl(0.04, 0.05, (0, 0.0, 0), NAVY, r=rot(0, 90, 0), sides=10)               # Gelenk
    for i in range(7):                                                              # Fächerblätter
        a = -60 + i * 20
        r = rot(0, 0, a)
        prism(p, [(-0.045, 0.0), (0.045, 0.0), (0.05, -0.42), (-0.05, -0.42)], 0.015, (0, 0, 0), "DFF5E8" if i % 2 == 0 else "9CDDB8", r=r @ rot(-90, 0, 0) @ Matrix.Translation(Vector((0, 0, -0.0))))
        fe = r @ Vector((0, -0.46, 0))
        feather(p, (fe.x, fe.y, 0.0), r @ rot(-90, 0, 0) @ rot(180, 0, 0), WHITE, "3FA35A", 0.5)
    sweep(p, [(math.sin(math.radians(-a)) * 0.3, -math.cos(math.radians(a)) * 0.3, 0.01) for a in range(-60, 61, 20)], 0.012, YEL, sides=4, ref=(0, 0, 1))
    Y(p, 0.035, 0.24, 0.0, 0, NAVY, sides=8)
    done("y_fan", p, (0, -0.5, 0), tilt=0, pitch=58)


def y_frostbow():
    p = Part()
    bow(p, "9FE8FF", grip_col="2C6E9A")
    for s in (-1, 1):
        star(p, 0.06, 0.04, (0, 0.18, s * 0.36), ICE, r=rot(0, 0, 90), n=6, inner=0.4, color2=CYAN)
    arrow(p, 0.3, -0.62, color=WHITE, head=ICE, feather=CYAN)
    star(p, 0.05, 0.03, (0, -0.6, 0.0), ICE, r=rot(0, 0, 90), n=6, inner=0.4)
    done("y_frostbow", p, (0, -0.62, 0), tilt=22, yaw=-66)


def y_rain():
    p = Part()
    bow(p, "3FA35A", grip_col=BROWN)
    for a, fc in ((-20, RED), (-10, YEL), (0, RED), (10, YEL), (20, RED)):         # Pfeilfächer
        arrow(p, 0.33, -0.6, color=WOOD, head=GREY_L, feather=fc, r=rot(a, 0, 0), piv=(0, 0.3, 0))
    done("y_rain", p, (0, -0.6, 0), tilt=22, yaw=-66)


def y_hawk():
    """Paket H: deutlicher – Falknerhandschuh (Stulpe + Finger) mit Falke Kiko, Flügel weit nach oben gespreizt,
    gelber Hakenschnabel und große Augen."""
    p = Part()
    p.box((0.16, 0.2, 0.14), (0, 0.12, -0.02), BROWN, bevel=0.05, segs=2)         # Stulpe
    p.box((0.17, 0.05, 0.15), (0, 0.22, -0.02), "D9B47A", bevel=0.02, segs=1)
    p.box((0.15, 0.14, 0.09), (0, -0.04, 0.0), "8A5A32", bevel=0.04, segs=2)        # Faust
    for x in (-0.045, 0.0, 0.045):
        p.box((0.04, 0.05, 0.05), (x, -0.11, 0.0), "8A5A32", bevel=0.015, segs=1)
    c = (0, -0.06, 0.2)
    p.ball(0.11, c, "8A6A4A", scale=(0.9, 0.85, 1.2), subdiv=2)                     # Körper aufrecht
    p.ball(0.07, (0, -0.1, 0.18), "F2E6D0", scale=(1, 0.6, 1.3), subdiv=1)        # Brust
    for z in (0.14, 0.19, 0.24):
        p.box((0.05, 0.01, 0.008), (0, -0.145, z), "8A6A4A", segs=1)
    p.ball(0.075, (0, -0.07, 0.36), "8A6A4A", subdiv=2)                              # Kopf
    p.ball(0.04, (0, -0.12, 0.33), "F2E6D0", subdiv=1)
    p.cone(0.03, 0.06, (0, -0.15, 0.34), YEL, r=rot(110, 0, 0), sides=6)            # Hakenschnabel
    p.cone(0.012, 0.03, (0, -0.17, 0.31), "2E3340", r=rot(180, 0, 0), sides=4)
    for sx in (-1, 1):
        p.ball(0.022, (sx * 0.04, -0.12, 0.38), YEL, subdiv=1)                       # Augen
        p.ball(0.012, (sx * 0.042, -0.137, 0.38), BLACK, subdiv=1)
        prism(p, [(0.0, 0.0), (0.12, 0.16), (0.26, 0.24), (0.3, 0.16), (0.2, 0.04), (0.06, -0.06)], 0.025, (sx * 0.07, -0.04, 0.24),
              "6B5A45", r=rot(0, 0, 0 if sx > 0 else 180))                                   # Flügel hoch gespreizt
        for k in range(3):
            p.box((0.012, 0.03, 0.06), (sx * (0.25 + k * 0.03), -0.04, 0.42 - k * 0.04), WHITE, bevel=0.004, segs=1)   # Schwungfedern hell
        p.cone(0.012, 0.04, (sx * 0.03, -0.1, 0.06), YEL, r=rot(180, 0, 0), sides=4)   # Krallen am Handschuh
    prism(p, [(-0.05, 0.0), (0.05, 0.0), (0.04, -0.14), (-0.04, -0.14)], 0.02, (0, 0.03, 0.12), "6B5A45", r=rot(-60, 0, 0))   # Schwanz
    done("y_hawk", p, (0, -0.16, 0.34), tilt=0, yaw=-30, pitch=8)


def y_longbow():
    p = Part()
    pts = bow(p, WOOD, h=0.72, bend=0.34, grip_col="3FA35A", string=0.3)
    for s in (-1, 1):
        p.ball(0.04, pts[0 if s < 0 else -1], WHITE, subdiv=2)
        feather(p, (0, 0.24, s * 0.5), rot(0, 0, 90) @ rot(0, 25 * s, 0), WHITE, RED, 0.8)
    arrow(p, 0.32, -0.64, color=WHITE, head=GREY_L, feather=RED)
    done("y_longbow", p, (0, -0.64, 0), tilt=22, yaw=-66)


def y_stars():
    p = Part()
    for i, (dz, col) in enumerate(((0.0, "3FA35A"), (0.05, WHITE), (0.1, "3FA35A"))):   # drei Wurfsterne gestapelt
        star(p, 0.2, 0.03, (0.0, -0.24 + i * 0.03, dz), col, r=rot(90, 0, i * 15), n=4, inner=0.32, color2=GREY_L)
        p.cyl(0.04, 0.035, (0.0, -0.24 + i * 0.03, dz), YEL, sides=10)
    for a in (0, 90, 180, 270):
        x, y = math.cos(math.radians(a + 45)) * 0.17, -0.24 + math.sin(math.radians(a + 45)) * 0.17
        feather(p, (x, y, 0.12), rot(90, 0, 0) @ rot(0, a + 135, 0), WHITE, RED, 0.35)
    done("y_stars", p, (0, -0.42, 0.05), tilt=0, pitch=60)


def y_tornado():
    p = Part()
    bow(p, "22C7B8", grip_col=NAVY)
    for i in range(3):                                                               # Wirbel
        rr = 0.06 + i * 0.03
        p.torus(rr, 0.012, (0, -0.52 + i * 0.07, 0.0), WHITE if i % 2 == 0 else CYAN, r=rot(90, 0, i * 25), seg=14, tseg=4)
    arrow(p, 0.3, -0.62, color=WHITE, head=CYAN, feather=TEAL)
    done("y_tornado", p, (0, -0.62, 0), tilt=22, yaw=-66)


ALL = dict(y_sling=y_sling, y_crossbow=y_crossbow, y_spear=y_spear, y_boomerang=y_boomerang, y_blowpipe=y_blowpipe, y_fan=y_fan,
           y_frostbow=y_frostbow, y_rain=y_rain, y_hawk=y_hawk, y_longbow=y_longbow, y_stars=y_stars, y_tornado=y_tornado)

if __name__ == "__main__":
    main(ALL)
