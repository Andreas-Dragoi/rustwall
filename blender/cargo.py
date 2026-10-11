"""Ladung auf dem Rücken (Paket B – Begleiter): ein Teil-Modell je Rohstoff und die Kraxe des Helden.
cg_<rohstoff> ist ein Ladungsstück von ca. 0,32 × 0,32 m Grundfläche, Ursprung unten in der Mitte,
Vorderseite -Y. Godot (src/backpack.gd, src/companion.gd) stapelt die Stücke in Fächer.
  cg_wood    Bündel aus drei Stämmen mit Seil (liegt quer, entlang X)
  cg_stone   zwei runde Feldsteine
  cg_metal   zwei Barren auf einer Blechplatte
  cg_fuel    roter Kanister
  cg_cells   Energiezelle (leuchtender Ring `band_glow`)
  cg_parts   Zahnrad mit Schrauben und Feder
  cg_shards  Sternsplitter-Kristall (`crystal_glow`)
  cg_kraxe   Holz-Kraxe des Helden: Rahmen mit Gurten, Leerobjekt `load` (Boden der Ladefläche).
             Gurt-Seite vorn (-Y, liegt am Rücken), Ladefläche nach hinten (+Y).
Aufruf: python3 blender/cargo.py [cg_wood ...]"""
import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from kit import *
from rw_util import *

BARK, CUT, CUT_D, ROPE = "8A5A30", "EBC07E", "C8924E", "D9C27E"
ROCK, ROCK_L, ROCK_D = "9A8F96", "B9B0B6", "6E6672"
STEEL, STEEL_L, STEEL_D, BLUE_M = "8A94A8", "B8C2D4", "5E6678", "6F8FC0"
RED, RED_D, DARK = "E0473C", "A82E38", "2E3340"
CYAN, CYAN_D = "3FD2F5", "1E7FA8"
GOLD, BRASS = "FFC824", "E0A82E"
SHARD, SHARD_D = "FFE98A", "F5B53A"
WOOD, WOOD_D, WOOD_L, LEATHER = "B56A32", "7A4522", "D9A05E", "8A4A2C"


def done(name, parts, empties=(), yaw=-35.0, pitch=26.0):
    root = empty(name)
    for nm, p in parts:
        p.build(nm, root)
    for nm, loc in empties:
        empty(nm, root, loc)
    finish(name, yaw=yaw, pitch=pitch, size=128)


def cg_wood():
    p = Part()
    for x, y, z, rr in ((0, -0.08, 0.08, 0.075), (0, 0.08, 0.08, 0.07), (0.02, 0.0, 0.2, 0.072)):
        m = T(x, y, z) @ rot(0, 90, 0)
        p.cyl(rr, 0.46, (0, 0, 0), BARK, r=m, sides=9, bevel=0.012, segs=1)
        p.cyl(rr * 0.82, 0.47, (0, 0, 0), CUT, r=m, sides=9)
        p.cyl(rr * 0.35, 0.475, (0, 0, 0), CUT_D, r=m, sides=6)
    for x in (-0.13, 0.13):
        p.torus(0.13, 0.016, (x, 0, 0.12), ROPE, r=rot(0, 90, 0), seg=12, tseg=4)
    p.cyl(0.02, 0.1, (0.1, 0.05, 0.28), BARK, r=rot(30, 0, 0), sides=5)
    done("cg_wood", [("body", p)])


def cg_stone():
    p = Part()
    p.box((0.26, 0.24, 0.17), (-0.03, 0.02, 0.09), ROCK, r=rot(4, 8, 14), bevel=0.07, segs=2)
    p.box((0.17, 0.16, 0.13), (0.07, -0.05, 0.22), ROCK_L, r=rot(-8, 6, 38), bevel=0.05, segs=2)
    p.box((0.1, 0.09, 0.08), (0.11, 0.09, 0.05), ROCK_D, r=rot(10, 0, 12), bevel=0.03, segs=1)
    done("cg_stone", [("body", p)])


def cg_metal():
    p = Part()
    p.box((0.34, 0.3, 0.04), (0, 0, 0.02), STEEL_D, bevel=0.012, segs=1)
    for y, c in ((-0.07, BLUE_M), (0.07, STEEL_L)):
        p.box((0.3, 0.12, 0.09), (0, y, 0.09), c, bevel=0.025, segs=1)
        p.box((0.24, 0.08, 0.02), (0, y, 0.14), shade(c, 1.15), bevel=0.008, segs=1)
    p.box((0.28, 0.11, 0.08), (0.01, 0.0, 0.19), STEEL, r=rot(0, 0, 8), bevel=0.022, segs=1)
    p.cyl(0.018, 0.012, (-0.1, 0.0, 0.235), STEEL_D, sides=6)
    p.cyl(0.018, 0.012, (0.11, 0.015, 0.235), STEEL_D, sides=6)
    done("cg_metal", [("body", p)])


def cg_fuel():
    p = Part()
    p.box((0.26, 0.15, 0.3), (0, 0, 0.15), RED, bevel=0.04, segs=2)
    p.box((0.2, 0.16, 0.04), (0, 0, 0.2), RED_D, bevel=0.01, segs=1)
    p.box((0.2, 0.16, 0.04), (0, 0, 0.1), RED_D, bevel=0.01, segs=1)
    p.box((0.14, 0.05, 0.05), (-0.03, 0, 0.32), DARK, bevel=0.012, segs=1)
    p.cyl(0.03, 0.08, (0.08, 0, 0.33), STEEL, sides=8)
    p.cyl(0.034, 0.02, (0.08, 0, 0.375), "F2D04A", sides=8)
    done("cg_fuel", [("body", p)])


def cg_cells():
    p = Part()
    p.cyl(0.11, 0.28, (0, 0, 0.14), STEEL_D, sides=12, bevel=0.02, segs=1)
    p.cyl(0.115, 0.04, (0, 0, 0.03), DARK, sides=12)
    p.cyl(0.115, 0.04, (0, 0, 0.26), DARK, sides=12)
    p.cyl(0.04, 0.05, (0, 0, 0.3), BRASS, sides=8)
    p.box((0.03, 0.02, 0.14), (0.0, -0.112, 0.14), STEEL_L)
    g = Part()
    g.cyl(0.118, 0.07, (0, 0, 0.14), CYAN, sides=12)
    g.cyl(0.03, 0.02, (0, 0, 0.33), CYAN, sides=8)
    done("cg_cells", [("body", p), ("band_glow", g)])


def cg_parts():
    p = Part()
    # Zahnrad liegt flach
    p.cyl(0.12, 0.06, (0, 0, 0.04), STEEL, sides=16)
    for i in range(8):
        a = i * 45.0
        p.box((0.06, 0.05, 0.06), (0, 0, 0.04), STEEL, r=rot(0, 0, a) @ T(0.135, 0, 0))
    p.cyl(0.045, 0.07, (0, 0, 0.045), DARK, sides=10)
    # Schrauben und Feder obenauf
    for x, y, a in ((-0.06, 0.04, 20), (0.07, -0.05, -40)):
        p.cyl(0.016, 0.14, (x, y, 0.11), BRASS, r=rot(0, 80, a), sides=6)
        p.cyl(0.03, 0.025, (x - 0.06, y, 0.11), BRASS, r=rot(0, 80, a), sides=6)
    p.torus(0.04, 0.012, (0.02, 0.06, 0.13), STEEL_L, r=rot(70, 0, 0), seg=10, tseg=4)
    p.torus(0.04, 0.012, (0.02, 0.08, 0.13), STEEL_L, r=rot(70, 0, 0), seg=10, tseg=4)
    done("cg_parts", [("body", p)])


def cg_shards():
    p = Part()
    p.cyl(0.13, 0.05, (0, 0, 0.025), WOOD_D, sides=8, bevel=0.01, segs=1)
    g = Part()
    g.cone(0.07, 0.3, (0, 0, 0.2), SHARD, sides=5)
    g.cone(0.07, 0.12, (0, 0, 0.0), SHARD_D, r=T(0, 0, 0.05) @ rot(180, 0, 0) @ T(0, 0, 0), sides=5)
    g.cone(0.04, 0.17, (0.08, 0.03, 0.14), SHARD, r=rot(0, 30, 0), sides=5)
    g.cone(0.035, 0.14, (-0.07, -0.03, 0.12), SHARD_D, r=rot(10, -35, 0), sides=5)
    done("cg_shards", [("body", p), ("crystal_glow", g)])


def cg_kraxe():
    """Kraxe: Höhe 0,62 m über dem Rückenpunkt (Knochen prop_back), Ladefläche 0,36 × 0,3 m."""
    p = Part()
    # zwei senkrechte Holme (an der Rückenseite), unten Querbrett = Ladeboden
    for x in (-0.17, 0.17):
        p.box((0.045, 0.045, 0.66), (x, 0.05, 0.2), WOOD, bevel=0.012, segs=1)
        p.ball(0.03, (x, 0.05, 0.54), WOOD_L, subdiv=1)
    for z in (0.02, 0.3):
        p.box((0.38, 0.04, 0.04), (0, 0.05, z), WOOD_D, bevel=0.01, segs=1)
    # Ladeboden ragt nach hinten
    p.box((0.4, 0.32, 0.035), (0, 0.2, -0.12), WOOD_D, bevel=0.01, segs=1)
    for x in (-0.17, 0.17):
        p.box((0.035, 0.035, 0.18), (x, 0.33, -0.05), WOOD, r=rot(-20, 0, 0), bevel=0.01, segs=1)
        p.box((0.035, 0.25, 0.035), (x, 0.2, -0.12), WOOD, bevel=0.01, segs=1)
    # Gurte vorn (am Rücken)
    for x in (-0.11, 0.11):
        p.box((0.06, 0.03, 0.4), (x, -0.005, 0.18), LEATHER, bevel=0.01, segs=1)
        p.box((0.05, 0.035, 0.04), (x, -0.012, 0.3), BRASS, bevel=0.008, segs=1)
    p.box((0.3, 0.02, 0.06), (0, 0.075, 0.42), LEATHER, bevel=0.008, segs=1)
    done("cg_kraxe", [("body", p)], empties=[("load", (0, 0.2, -0.1))], yaw=145.0)


TABLE = {"cg_wood": cg_wood, "cg_stone": cg_stone, "cg_metal": cg_metal, "cg_fuel": cg_fuel, "cg_cells": cg_cells,
         "cg_parts": cg_parts, "cg_shards": cg_shards, "cg_kraxe": cg_kraxe}

def _fresh(f):
    def g():
        reset()
        f()
    return g


TABLE = {k: _fresh(v) for k, v in TABLE.items()}

if __name__ == "__main__":
    run(TABLE, sys.argv)
