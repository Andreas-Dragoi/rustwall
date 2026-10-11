"""Tiere der lebendigen Basis (Auftrag V3, Paket 5). Vorderseite -Y, Ursprung am Boden.
Bewegliche Teile sind eigene Objekte, deren Ursprung im Gelenk liegt; src/wildlife.gd dreht sie:
  a_butterfly – ein Objekt `body`; die Flügel (|x| > 0,03) klappt der Shader (MultiMesh)
  a_bird, a_gull – `body`, `wing_l`, `wing_r` (Gelenk an der Schulter, Flügel entlang ∓X)
  a_chicken, a_duck – `body`, `head` (Gelenk am Hals)
  a_rabbit – `body`, `ears` (Gelenk am Kopf)
  a_cat – `body`, `head`, `tail`
  a_dog – `body`, `head`, `tail`, `leg_fl`, `leg_fr`, `leg_bl`, `leg_br` (Gelenk an der Hüfte)
Aufruf: python3 blender/animals.py [a_bird ...]"""
import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from kit import *
from rw_util import *


def done(name, root_parts, icon_too=False):
    root = empty(name)
    for nm, part, loc in root_parts:
        part.build(nm, root, loc)
    report(name)
    save(name)


def butterfly():
    reset(); p = Part()
    p.cyl(0.018, 0.16, (0, 0, 0.0), "2E3340", r=rot(90, 0, 0), sides=5)
    for s in (-1, 1):
        p.ball(1.0, (s * 0.085, -0.03, 0.0), "FF9A2E", scale=(0.08, 0.065, 0.008), subdiv=1)
        p.ball(1.0, (s * 0.065, 0.05, 0.0), "FFD23E", scale=(0.06, 0.05, 0.008), subdiv=1)
        p.ball(0.018, (s * 0.1, -0.04, 0.006), "FFFFFF", subdiv=1)
    done("a_butterfly", [("body", p, (0, 0, 0))])


def bird(name, big=False):
    reset()
    k = 1.8 if big else 1.0
    c_body, c_belly, c_wing = ("F4F6FA", "FFFFFF", "AEB6C4") if big else ("C8743A", "F2C27A", "8A5230")
    b = Part()
    b.ball(0.1 * k, (0, 0, 0.12 * k), c_body, scale=(0.9, 1.4, 0.9), subdiv=2)
    b.ball(0.07 * k, (0, -0.02 * k, 0.1 * k), c_belly, scale=(0.9, 1.2, 0.8), subdiv=1)
    b.ball(0.065 * k, (0, -0.13 * k, 0.2 * k), c_body, subdiv=2)
    b.cone(0.025 * k, 0.07 * k, (0, -0.2 * k, 0.2 * k), "FFB020", r=rot(90, 0, 0), sides=4)
    for s in (-1, 1):
        b.ball(0.012 * k, (s * 0.04 * k, -0.17 * k, 0.225 * k), "181A22", subdiv=1)
        b.cyl(0.008 * k, 0.06 * k, (s * 0.03 * k, 0, 0.03 * k), "FFB020", sides=4)
    b.box((0.08 * k, 0.12 * k, 0.02 * k), (0, 0.15 * k, 0.15 * k), c_wing, r=rot(-15, 0, 0), bevel=0.01, segs=1)
    parts = [("body", b, (0, 0, 0))]
    for nm, s in (("wing_l", -1), ("wing_r", 1)):
        w = Part()
        w.ball(1.0, (s * 0.09 * k, 0.01 * k, 0), c_wing, scale=(0.1 * k, 0.06 * k, 0.012 * k), subdiv=1)
        if big:
            w.ball(1.0, (s * 0.17 * k, 0.02 * k, 0), "3A3F4C", scale=(0.03 * k, 0.04 * k, 0.012 * k), subdiv=1)
        parts.append((nm, w, (s * 0.06 * k, 0.0, 0.15 * k)))
    done(name, parts)


def chicken():
    reset()
    b = Part()
    b.ball(0.2, (0, 0.02, 0.26), "F4F2EA", scale=(0.85, 1.15, 0.9), subdiv=2)
    b.box((0.14, 0.12, 0.18), (0, 0.22, 0.36), "E8E4D8", r=rot(-30, 0, 0), bevel=0.05, segs=1)
    for s in (-1, 1):
        b.ball(1.0, (s * 0.16, 0.03, 0.27), "E2DED0", scale=(0.04, 0.14, 0.09), subdiv=1)
        b.cyl(0.018, 0.14, (s * 0.06, 0.0, 0.07), "F2A02E", sides=4)
    h = Part()
    h.ball(0.09, (0, -0.02, 0.07), "F4F2EA", subdiv=2)
    h.cone(0.03, 0.07, (0, -0.12, 0.06), "F2A02E", r=rot(90, 0, 0), sides=4)
    h.box((0.03, 0.09, 0.06), (0, -0.03, 0.16), "E23B3B", bevel=0.012, segs=1)
    h.ball(0.025, (0, -0.1, 0.01), "E23B3B", subdiv=1)
    for s in (-1, 1):
        h.ball(0.012, (s * 0.06, -0.07, 0.09), "181A22", subdiv=1)
    done("a_chicken", [("body", b, (0, 0, 0)), ("head", h, (0, -0.16, 0.4))])


def duck():
    reset()
    b = Part()
    b.ball(0.18, (0, 0.03, 0.07), "8A6A4A", scale=(0.85, 1.3, 0.62), subdiv=2)
    b.ball(0.12, (0, 0.06, 0.13), "A88A62", scale=(1.15, 1.2, 0.45), subdiv=1)
    b.box((0.1, 0.08, 0.04), (0, 0.24, 0.13), "5A4632", r=rot(-25, 0, 0), bevel=0.02, segs=1)
    h = Part()
    h.cyl(0.04, 0.12, (0, 0, 0.05), "2F7A4A", sides=6)
    h.ball(0.075, (0, -0.02, 0.13), "2F7A4A", subdiv=2)
    h.box((0.06, 0.1, 0.025), (0, -0.11, 0.12), "F2A02E", bevel=0.012, segs=1)
    h.cyl(0.042, 0.02, (0, 0, 0.03), "FFFFFF", sides=8)
    for s in (-1, 1):
        h.ball(0.01, (s * 0.05, -0.06, 0.15), "181A22", subdiv=1)
    done("a_duck", [("body", b, (0, 0, 0)), ("head", h, (0, -0.14, 0.13))])


def rabbit():
    reset()
    b = Part()
    b.ball(0.17, (0, 0.06, 0.17), "B8A08A", scale=(0.85, 1.2, 0.95), subdiv=2)
    b.ball(0.11, (0, -0.12, 0.27), "B8A08A", subdiv=2)
    b.ball(0.06, (0, 0.24, 0.2), "F4F6FA", subdiv=1)
    b.ball(0.02, (0, -0.225, 0.27), "E28AA0", subdiv=1)
    for s in (-1, 1):
        b.ball(0.016, (s * 0.06, -0.19, 0.3), "181A22", subdiv=1)
        b.ball(1.0, (s * 0.09, -0.02, 0.05), "A89078", scale=(0.05, 0.12, 0.05), subdiv=1)
    e = Part()
    for s in (-1, 1):
        e.ball(1.0, (s * 0.045, 0, 0.1), "B8A08A", r=rot(0, s * 10, 0), scale=(0.035, 0.022, 0.11), subdiv=1)
        e.ball(1.0, (s * 0.045, -0.008, 0.1), "E8B0B8", r=rot(0, s * 10, 0), scale=(0.02, 0.016, 0.08), subdiv=1)
    done("a_rabbit", [("body", b, (0, 0, 0)), ("ears", e, (0, -0.12, 0.34))])


def cat():
    reset()
    fur, fur_l = "E8963A", "F8D0A0"
    b = Part()
    b.ball(0.16, (0, 0.04, 0.22), fur, scale=(0.8, 1.5, 0.8), subdiv=2)
    b.ball(0.1, (0, -0.05, 0.18), fur_l, scale=(0.8, 1.2, 0.7), subdiv=1)
    for x, y in ((-0.07, -0.13), (0.07, -0.13), (-0.07, 0.18), (0.07, 0.18)):
        b.cyl(0.032, 0.16, (x, y, 0.08), fur, sides=6)
        b.ball(0.035, (x, y, 0.02), fur_l, subdiv=1)
    h = Part()
    h.ball(0.11, (0, -0.04, 0.04), fur, scale=(1.05, 0.95, 0.9), subdiv=2)
    h.ball(0.05, (0, -0.12, 0.01), fur_l, scale=(1.0, 0.8, 0.7), subdiv=1)
    for s in (-1, 1):
        h.cone(0.045, 0.08, (s * 0.06, -0.03, 0.14), fur, r=rot(0, s * 15, 0), sides=4)
        h.ball(0.018, (s * 0.045, -0.13, 0.06), "4A8A2A", subdiv=1)
    h.ball(0.012, (0, -0.15, 0.03), "E28AA0", subdiv=1)
    t = Part()
    t.cyl(0.025, 0.3, (0, 0.13, 0.08), fur, r=rot(-60, 0, 0), sides=5)
    t.ball(0.03, (0, 0.26, 0.16), fur_l, subdiv=1)
    done("a_cat", [("body", b, (0, 0, 0)), ("head", h, (0, -0.2, 0.3)), ("tail", t, (0, 0.24, 0.24))])


def dog():
    reset()
    fur, fur_d, fur_l = "B8743A", "7A4A26", "F2DCB8"
    b = Part()
    b.ball(0.2, (0, 0.02, 0.42), fur, scale=(0.75, 1.55, 0.78), subdiv=2)
    b.ball(0.12, (0, -0.12, 0.36), fur_l, scale=(0.8, 1.1, 0.7), subdiv=1)
    b.torus(0.08, 0.02, (0, -0.24, 0.52), "D9443A", r=rot(70, 0, 0), seg=10, tseg=4)
    parts = [("body", b, (0, 0, 0))]
    h = Part()
    h.ball(0.13, (0, -0.04, 0.06), fur, subdiv=2)
    h.box((0.12, 0.14, 0.1), (0, -0.17, 0.02), fur_l, bevel=0.04, segs=1)
    h.ball(0.03, (0, -0.25, 0.05), "181A22", subdiv=1)
    for s in (-1, 1):
        h.ball(0.02, (s * 0.06, -0.14, 0.11), "181A22", subdiv=1)
        h.ball(1.0, (s * 0.12, -0.0, 0.04), fur_d, r=rot(0, s * 20, 0), scale=(0.035, 0.07, 0.12), subdiv=1)
    parts.append(("head", h, (0, -0.3, 0.58)))
    t = Part()
    t.cyl(0.03, 0.22, (0, 0.06, 0.08), fur, r=rot(-50, 0, 0), sides=5)
    parts.append(("tail", t, (0, 0.3, 0.48)))
    for nm, x, y in (("leg_fl", -0.08, -0.18), ("leg_fr", 0.08, -0.18), ("leg_bl", -0.08, 0.2), ("leg_br", 0.08, 0.2)):
        l = Part()
        l.cyl(0.04, 0.32, (0, 0, -0.16), fur, sides=6)
        l.ball(0.045, (0, -0.02, -0.31), fur_l, scale=(1, 1.3, 0.6), subdiv=1)
        parts.append((nm, l, (x, y, 0.34)))
    done("a_dog", parts)


TABLE = {"a_butterfly": butterfly, "a_bird": (bird, "a_bird", False), "a_gull": (bird, "a_gull", True), "a_chicken": chicken,
         "a_duck": duck, "a_rabbit": rabbit, "a_cat": cat, "a_dog": dog}

if __name__ == "__main__":
    run(TABLE, sys.argv)
