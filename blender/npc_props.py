"""Getragene Dinge der Bewohner (Paket 2 – Kluge Bewohner) und die Bank für Pausen.
c_* hängen in der Hand (Knochen prop_r): Griff im Ursprung, Vorderseite -Y wie bei Waffen.
p_bench steht am Boden (Ursprung Mitte unten).
Aufruf: python3 blender/npc_props.py [c_log ...]"""
import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from kit import *
from rw_util import *
from mathutils import Matrix, Vector

BARK, CUT, CUT_D = "8A5A30", "EBC07E", "C8924E"
WOOD, WOOD_D, WOOD_L = "B56A32", "7A4522", "D9A05E"
ROCK, ROCK_L, ROCK_D = "9A8F96", "B5ABB0", "6E6672"
STEEL, STEEL_D, DARK = "8A94A8", "5E6678", "2E3340"
RUST, RUST_D = "B8643A", "8A4A2C"
RED, RED_D, GOLD = "DD4343", "A82E38", "FFC824"
GREEN, GREEN_D, BLUE = "5E9A32", "47782A", "4F8FE0"


def T(x, y, z):
    return Matrix.Translation(Vector((x, y, z)))


def done(name, p, yaw=-30.0, pitch=22.0):
    root = empty(name)
    p.build("body", root)
    finish(name, yaw=yaw, pitch=pitch, size=128)


def c_log():
    """Baumstamm auf der Schulter: liegt quer zur Hand."""
    reset(); p = Part()
    m = T(0, 0, 0.05) @ rot(90, 0, 0)
    p.cyl(0.13, 1.1, (0, 0, 0), BARK, r=m, sides=10, bevel=0.02, segs=1)
    p.cyl(0.11, 1.12, (0, 0, 0), CUT, r=m, sides=10)
    p.cyl(0.05, 1.13, (0, 0, 0), CUT_D, r=m, sides=8)
    p.cyl(0.035, 0.18, (0.08, -0.25, 0.14), BARK, r=rot(0, 30, 0), sides=6)
    done("c_log", p)


def c_stone():
    reset(); p = Part()
    p.box((0.32, 0.28, 0.24), (0, 0, 0.02), ROCK, r=rot(8, 12, 20), bevel=0.07, segs=1)
    p.box((0.18, 0.16, 0.14), (0.07, -0.06, 0.13), ROCK_L, r=rot(-10, 5, 40), bevel=0.04, segs=1)
    p.box((0.12, 0.1, 0.1), (-0.1, 0.07, -0.06), ROCK_D, r=rot(20, 0, 10), bevel=0.03, segs=1)
    done("c_stone", p)


def c_scrap():
    reset(); p = Part()
    p.box((0.42, 0.06, 0.26), (0, 0, 0.04), RUST, r=rot(0, 12, 8), bevel=0.02, segs=1)
    p.cyl(0.05, 0.4, (0.05, 0.05, 0.12), STEEL_D, r=rot(70, 0, 30), sides=8)
    p.box((0.16, 0.16, 0.05), (-0.12, -0.04, 0.17), STEEL, r=rot(30, 20, 0), bevel=0.02, segs=1)
    p.cyl(0.08, 0.04, (0.14, -0.06, -0.07), RUST_D, r=rot(90, 0, 0), sides=10)
    done("c_scrap", p)


def c_crate():
    reset(); p = Part()
    s = 0.42
    p.box((s, s, s), (0, 0, 0.0), WOOD, bevel=0.02, segs=1)
    for z in (-s * 0.42, s * 0.42):
        p.box((s + 0.02, s + 0.02, 0.06), (0, 0, z), WOOD_D, bevel=0.01, segs=1)
    p.box((0.06, s + 0.03, s * 0.8), (0, 0, 0), WOOD_D, r=rot(0, 45, 0), bevel=0.01, segs=1)
    p.box((0.12, 0.02, 0.12), (0, -s * 0.52, 0.04), GOLD, r=rot(0, 45, 0))
    done("c_crate", p)


def c_can():
    reset(); p = Part()
    p.box((0.3, 0.16, 0.38), (0, 0, -0.18), RED, bevel=0.04, segs=2)
    p.box((0.22, 0.18, 0.04), (0, 0, -0.08), RED_D, bevel=0.01, segs=1)
    p.box((0.05, 0.05, 0.16), (0, 0, 0.04), DARK, bevel=0.01, segs=1)
    p.box((0.2, 0.05, 0.04), (0, 0, 0.0), DARK, bevel=0.01, segs=1)
    p.cyl(0.035, 0.1, (0.11, 0, 0.04), STEEL, sides=8)
    done("c_can", p)


def c_watering():
    reset(); p = Part()
    p.cyl(0.14, 0.24, (0, -0.02, -0.16), GREEN, sides=14, bevel=0.03, segs=1)
    p.cyl(0.15, 0.03, (0, -0.02, -0.04), GREEN_D, sides=14)
    p.torus(0.1, 0.025, (0, 0.0, 0.02), GREEN_D, r=rot(90, 0, 90), seg=12, tseg=5)
    p.cyl(0.03, 0.34, (0, -0.24, -0.06), GREEN_D, r=rot(-60, 0, 0), sides=8)
    p.cyl(0.06, 0.04, (0, -0.39, 0.03), BLUE, r=rot(-60, 0, 0), sides=10)
    done("c_watering", p)


def c_hammer():
    reset(); p = Part()
    p.cyl(0.03, 0.42, (0, -0.16, 0), WOOD_L, r=rot(90, 0, 0), sides=8, bevel=0.01, segs=1)
    p.box((0.2, 0.09, 0.09), (0, -0.37, 0), STEEL, bevel=0.02, segs=1)
    p.box((0.05, 0.1, 0.1), (0.1, -0.37, 0), STEEL_D, bevel=0.01, segs=1)
    p.box((0.05, 0.06, 0.06), (0, 0.04, 0), WOOD_D, bevel=0.01, segs=1)
    done("c_hammer", p)


def c_broom():
    reset(); p = Part()
    p.cyl(0.025, 1.1, (0, -0.35, 0), WOOD_L, r=rot(90, 0, 0), sides=8)
    p.box((0.28, 0.08, 0.12), (0, -0.92, 0), WOOD_D, bevel=0.02, segs=1)
    p.box((0.3, 0.2, 0.1), (0, -1.05, 0), GOLD, bevel=0.03, segs=1)
    done("c_broom", p)


def p_bench():
    reset(); p = Part()
    for x in (-0.6, 0.6):
        p.box((0.1, 0.36, 0.42), (x, 0, 0.21), WOOD_D, bevel=0.03, segs=1)
    for i, y in enumerate((-0.12, 0.0, 0.12)):
        p.box((1.6, 0.11, 0.06), (0, y, 0.45), (WOOD, WOOD_L, WOOD)[i], r=rot(0, 0, (0.5, -0.4, 0.3)[i]), bevel=0.02, segs=1)
    p.box((1.6, 0.06, 0.18), (0, 0.2, 0.68), WOOD, r=rot(-12, 0, 0), bevel=0.02, segs=1)
    for x in (-0.6, 0.6):
        p.box((0.08, 0.06, 0.32), (x, 0.2, 0.56), WOOD_D, r=rot(-12, 0, 0), bevel=0.02, segs=1)
    done("p_bench", p)


TABLE = {"c_log": c_log, "c_stone": c_stone, "c_scrap": c_scrap, "c_crate": c_crate, "c_can": c_can,
         "c_watering": c_watering, "c_hammer": c_hammer, "c_broom": c_broom, "p_bench": p_bench}

if __name__ == "__main__":
    run(TABLE, sys.argv)
