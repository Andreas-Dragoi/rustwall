"""Mauern, Tore und Baugerüste (Paket 6 / 8).
  wall_post_<0..2>, wall_link_<0..2> – je EIN Mesh `body` (werden per MultiMesh gezeichnet), höchstens 500 Dreiecke.
      Pfosten steht in der Feldmitte; Verbindung liegt entlang X, genau 2 m lang, mittig zwischen zwei Feldmitten.
      0 Holz: Palisade mit Querbalken und Seil · 1 Stein: Quader mit Zinnen · 2 Metall: Platten mit Nieten und Warnstreifen
  wall_site – Gerüst um ein Mauerstück im Bau (ein Mesh)
  b_tor_<0..2> – Tor über 2 × 1 Felder (4 m entlang X, 2 m tief): `body`, Flügel `door_l`/`door_r` (Ursprung am Scharnier),
      `lamp_open_glow` (grün) / `lamp_closed_glow` (rot), `lamp_glow`, `sway_flag`, Leerobjekt `bubble`; Durchfahrt 2,68 m × 3,05 m
  b_scaffold_<w>x<h> – Baugerüst um eine Grundfläche von w × h Feldern: `body` + `sway_tarp*`; innen frei
Aufruf: python3 blender/def_walls.py [namen...]"""
import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from def_kit import *

L = 2.0


# ------------------------------------------------------------------ Mauern
def post_part(tier, rng):
    B = Part()
    if tier == 0:                                                              # Holzpfahl mit Eisenkappe und Seil
        B.box((0.62, 0.62, 0.22), (0, 0, 0.11), ST_D, bevel=0.05, segs=1)
        B.box((0.46, 0.46, 1.95), (0, 0, 1.0), "BE7638", bevel=0.07, segs=1)
        for z in (0.72, 1.42):
            B.cyl(0.3, 0.1, (0, 0, z), ROPE, r=rot(0, 0, 22.5), sides=8)
        B.box((0.54, 0.54, 0.12), (0, 0, 1.93), STEEL)
        B.cyl(0.38, 0.34, (0, 0, 2.15), STEEL_L, r=rot(0, 0, 45), r2=0.05, sides=4)
        B.box((0.06, 0.5, 0.06), (0.1, 0, 1.15), WOOD_D, r=rot(0, 0, 0))       # Riss / Astloch
    elif tier == 1:                                                            # Steinpfeiler mit Kappe
        B.box((1.04, 1.04, 0.3), (0, 0, 0.15), ST_D, bevel=0.06, segs=1)
        B.box((0.9, 0.9, 2.2), (0, 0, 1.1), ST, bevel=0.1, segs=1)
        for (x, y, z, w) in ((0.18, -1, 0.75, 0.42), (-0.16, -1, 1.45, 0.4), (0.12, 1, 1.05, 0.44), (-0.2, 1, 1.7, 0.36)):
            B.box((w, 0.06, 0.26), (x, y * 0.455, z), jit(ST_L, rng))
        for (x, y, z, w) in ((1, 0.14, 1.25, 0.42), (1, -0.18, 0.7, 0.38), (-1, -0.1, 0.9, 0.44), (-1, 0.16, 1.6, 0.38)):
            B.box((0.06, w, 0.26), (x * 0.455, y, z), jit(ST_L, rng))
        B.box((1.08, 1.08, 0.22), (0, 0, 2.2), ST_D, bevel=0.06, segs=1)
        B.box((0.84, 0.84, 0.14), (0, 0, 2.38), BLUE)
        B.cyl(0.5, 0.3, (0, 0, 2.6), GOLD, r=rot(0, 0, 45), r2=0.12, sides=4)
        B.box((0.5, 0.05, 0.14), (0.25, -0.53, 0.2), "6E9A38")                 # Moos am Sockel
    else:                                                                      # Stahlpfeiler mit Goldkappe, Nieten, Warnband
        B.box((1.12, 1.12, 0.34), (0, 0, 0.17), METAL_D)
        B.box((1.0, 1.0, 2.6), (0, 0, 1.3), "5F74A6", bevel=0.1, segs=1)
        for i in range(4):
            m = rot(0, 0, i * 90)
            B.box((0.6, 0.06, 1.1), (0, 0, 0), METAL_L, r=m @ T(0, -0.5, 1.7))
            for sx in (-0.38, 0.38):
                for z in (1.05, 2.3):
                    rivet(B, m @ T(sx, -0.51, z), 0.08, STEEL_L)
            B.box((0.45, 0.05, 0.2), (0, 0, 0), HAZ_Y, r=m @ T(-0.225, -0.505, 0.62))
            B.box((0.45, 0.05, 0.2), (0, 0, 0), HAZ_K, r=m @ T(0.225, -0.505, 0.62))
        B.box((1.14, 1.14, 0.24), (0, 0, 2.62), GOLD, bevel=0.06, segs=1)
        B.cyl(0.56, 0.34, (0, 0, 2.9), "5F74A6", r=rot(0, 0, 45), r2=0.2, sides=4)
        B.ball(0.17, (0, 0, 3.12), GOLD, subdiv=1)
    return B


def link_part(tier, rng):
    B = Part()
    if tier == 0:                                                              # Palisade: angespitzte Pfähle, Querbalken, Seil
        for i in range(5):
            x = -0.6 + i * 0.3
            h = 1.5 + rng.uniform(-0.1, 0.14)
            c = jit("C27A3C" if i % 2 else "D08C4A", rng, 0.09)
            B.cyl(0.145, h, (x, 0, h * 0.5), c, r=rot(0, 0, 30), sides=6)
            B.cyl(0.145, 0.28, (x, 0, h + 0.14), shade(c, 1.15), r=rot(0, 0, 30), r2=0.02, sides=6)
        B.box((L, 0.1, 0.16), (0, -0.17, 1.12), WOOD_D)                        # Querbalken vorn und hinten
        B.box((L, 0.1, 0.16), (0, 0.17, 0.5), WOOD_D)
        for i in range(5):                                                     # Seilbindungen
            B.box((0.11, 0.05, 0.24), (-0.6 + i * 0.3, -0.225, 1.12), ROPE, r=rot(0, 35 if i % 2 else -35, 0))
        pts = [(-0.77, -0.24, 1.5), (-0.38, -0.25, 1.36), (0.0, -0.25, 1.31), (0.38, -0.25, 1.36), (0.77, -0.24, 1.5)]
        for i in range(4):                                                     # durchhängendes Seil
            tube(B, pts[i], pts[i + 1], 0.03, ROPE, sides=4)
        beam(B, (-0.7, 0.19, 0.3), (0.7, 0.19, 1.2), 0.1, shade(WOOD_D, 0.9), d=0.06)   # Strebe hinten
    elif tier == 1:                                                            # Quadermauer mit Zinne
        B.box((L, 0.78, 0.26), (0, 0, 0.13), ST_D)
        B.box((L, 0.62, 1.75), (0, 0, 0.875), shade(ST, 0.95), bevel=0.05, segs=1)
        B.box((L, 0.76, 0.16), (0, 0, 1.75), ST_D)
        for s in (-1, 1):
            for (x, z, w) in ((-0.45, 0.62, 0.5), (0.3, 0.62, 0.62), (-0.05, 0.98, 0.56), (0.62, 0.98, 0.4), (-0.6, 0.98, 0.36),
                              (0.4, 1.34, 0.5), (-0.3, 1.34, 0.6)):
                B.box((w, 0.05, 0.28), (x * s, 0.315 * s, z), jit((ST_L, ST, ST_L)[int(abs(x * 10)) % 3], rng))
        B.box((0.56, 0.7, 0.44), (0, 0, 2.03), ST, bevel=0.06, segs=1)         # Zinne mit blau-goldener Kappe
        B.box((0.46, 0.6, 0.07), (0, 0, 2.28), BLUE)
        B.box((0.3, 0.44, 0.07), (0, 0, 2.34), GOLD)
        B.box((0.4, 0.05, 0.12), (-0.5, -0.4, 0.3), "6E9A38")                  # Moos
        B.box((0.3, 0.05, 0.1), (0.4, 0.4, 0.3), "6E9A38")
    else:                                                                      # Stahlplatten mit Nieten und Warnstreifen
        B.box((L, 0.76, 0.3), (0, 0, 0.15), METAL_D)
        B.box((L, 0.6, 2.2), (0, 0, 1.1), METAL)
        hazard(B, (-1.0, 0, 0.46), (1.0, 0, 0.46), 6, 0.22, 0.64)
        B.box((L, 0.7, 0.14), (0, 0, 2.2), "4F6294")
        B.box((L, 0.66, 0.1), (0, 0, 2.02), GOLD)
        for s in (-1, 1):
            for px in (-0.5, 0.5):
                B.box((0.9, 0.05, 1.2), (px, 0.31 * s, 1.3), jit(METAL_L, rng, 0.04))
                for rx in (-0.36, 0.36):
                    for rz in (0.8, 1.8):
                        rivet(B, T(px + rx, 0.335 * s, rz), 0.075, STEEL_L)
            beam(B, (-0.05, 0.345 * s, 0.75), (0.05, 0.345 * s, 1.85), 0.1, "5F74A6", d=0.05)   # Stoßblech
    return B


def wall(kind, tier):
    name = "wall_%s_%d" % (kind, tier)
    reset()
    rng = rng_for(name)
    occ = []
    if kind == "post":
        post_part(tier, rng).build("body")
    else:
        link_part(tier, rng).build("body")
        for i, x in enumerate((-1.0, 1.0)):                                    # Pfosten nur als Schattenwerfer für die Verschattung
            o = post_part(tier, rng_for("occ")).build("occ%d" % i)
            o.location = (x, 0, 0)
            occ.append(o)
    finish(name, limit=500, hide=(), extra_occluders=occ)


def wall_site():
    """Gerüst um ein Mauerstück im Bau (1 Feld, ein Mesh)."""
    reset()
    rng = rng_for("wall_site")
    B = Part()
    for sx in (-1, 1):
        for sy in (-1, 1):
            B.cyl(0.055, 2.6, (0.86 * sx, 0.62 * sy, 1.3), STEEL_L, sides=6)
            B.box((0.2, 0.2, 0.04), (0.86 * sx, 0.62 * sy, 0.02), DK)
    for sy in (-1, 1):
        for z in (1.2, 2.3):
            B.box((1.84, 0.06, 0.08), (0, 0.62 * sy, z), STEEL)
        beam(B, (-0.86, 0.62 * sy, 1.2), (0.86, 0.62 * sy, 2.3), 0.05, STEEL)
    for sx in (-1, 1):
        B.box((0.06, 1.3, 0.08), (0.86 * sx, 0, 2.3), STEEL)
    for i in range(3):                                                         # Laufbretter
        B.box((1.8, 0.38, 0.06), (0, -0.42 + i * 0.42, 2.37), jit(WOOD_L, rng, 0.1))
    B.cyl(0.14, 0.24, (0.5, 0.2, 2.52), "4A5263", r2=0.17, sides=6)             # Eimer
    for i in range(2):                                                         # Steine / Bretter zum Verbauen
        B.box((0.3, 0.18, 0.12), (-0.5 + (i % 2) * 0.32, -0.1, 2.46 + (i // 2) * 0.12), jit(ST, rng))
    hazard(B, (-0.86, -0.66, 0.7), (0.86, -0.66, 0.7), 6, 0.12, 0.03)
    hazard(B, (-0.86, 0.66, 0.7), (0.86, 0.66, 0.7), 6, 0.12, 0.03)
    ladder(B, (0.8, -0.2, 0.0), (0.76, 0.3, 2.4), 0.36, WOOD_D, step=0.8)
    B.box((0.6, 0.03, 0.7), (-0.5, -0.66, 1.75), "E8943A")                     # Plane
    B.build("body")
    finish("wall_site", limit=500, hide=())


# ------------------------------------------------------------------ Tore
def roof_gable(p, c, w, d, h, color, rng, over=0.25, thick=0.12, rows=3, ridge=None):
    """Satteldach (First entlang X) mit abgesetzten Schindelreihen."""
    m0 = T(*c)
    pitch = math.atan2(h, d * 0.5)
    sl = math.hypot(d * 0.5, h) + over
    for s in (-1, 1):
        for i in range(rows):
            k0 = i / rows
            ln = sl / rows + 0.06
            mid = sl * (k0 + 0.5 / rows)                                       # Abstand vom First entlang der Schräge
            cy = s * math.cos(pitch) * mid
            cz = h - math.sin(pitch) * mid + i * 0.012
            p.box((w + over * 2 - i * 0.04, ln, thick), (0, 0, 0), jit(color, rng, 0.07), r=m0 @ T(0, cy, cz) @ rot(-s * math.degrees(pitch), 0, 0))
    p.cyl(1.0, w - 0.06, (0, 0, 0), shade(color, 0.72), r=m0 @ rot(0, 90, 0) @ S(h, d * 0.5, 1), sides=4)   # Giebelfüllung
    p.box((w + over * 2 + 0.06, 0.2, 0.14), (0, 0, 0), ridge or shade(color, 0.7), r=m0 @ T(0, 0, h + thick * 0.6))


def door_leaf(tier, s, w, h, rng):
    """Torflügel; Ursprung am Scharnier (x = 0), Blatt reicht nach -s·x."""
    d = Part()
    cx = -s * w * 0.5
    z0 = 0.1
    if tier == 0:
        n = 5
        for i in range(n):                                                     # Bretter mit Farbschwankung
            bw = w / n
            d.box((bw - 0.02, 0.14, h + rng.uniform(-0.04, 0.02)), (cx - w * 0.5 + (i + 0.5) * bw, 0, z0 + h * 0.5), jit("C98A48", rng, 0.09))
        for z in (0.5, h - 0.4):
            d.box((w, 0.2, 0.14), (cx, 0, z0 + z), STEEL, bevel=0.03, segs=1)
            for i in range(3):
                rivet(d, T(cx - w * 0.36 + i * w * 0.36, -0.105, z0 + z), 0.06, STEEL_L)
        for sy in (-1, 1):
            beam(d, (cx - w * 0.42, sy * 0.09, z0 + 0.6), (cx + w * 0.42, sy * 0.09, z0 + h - 0.5), 0.14, WOOD_D, d=0.05)
        d.torus(0.11, 0.025, (-s * (w - 0.2), -0.11, z0 + h * 0.45), DK, r=AX_Y, seg=8, tseg=4)
    elif tier == 1:
        d.box((w, 0.16, h), (cx, 0, z0 + h * 0.5), WOOD, bevel=0.04, segs=1)
        for i in range(4):
            d.box((0.03, 0.18, h - 0.1), (cx - w * 0.5 + (i + 1) * w / 5, 0, z0 + h * 0.5), shade(WOOD, 0.68))
        d.box((w - 0.24, 0.2, h * 0.36), (cx, 0, z0 + h * 0.68), BLUE, bevel=0.04, segs=1)      # blaues Feld
        for sy in (-1, 1):
            star(d, (cx, sy * 0.11, z0 + h * 0.68), 0.2, "white", 0.03, r=rot(90 * -sy, 0, 0))
        for z in (0.35, h * 0.42, h - 0.2):
            d.box((w + 0.02, 0.22, 0.12), (cx, 0, z0 + z), STEEL, bevel=0.03, segs=1)
        for i in range(3):
            for z in (0.35, h * 0.42):
                for sy in (-1, 1):
                    rivet(d, T(cx - w * 0.34 + i * w * 0.34, sy * 0.115, z0 + z), 0.07, GOLD)
        d.torus(0.12, 0.03, (-s * (w - 0.2), -0.12, z0 + h * 0.3), GOLD, r=AX_Y, seg=8, tseg=4)
    else:
        d.box((w, 0.18, h), (cx, 0, z0 + h * 0.5), METAL, bevel=0.04, segs=1)
        for z, hh in ((0.75, 1.0), (2.05, 1.0)):
            d.box((w - 0.24, 0.24, hh), (cx, 0, z0 + z), METAL_L, bevel=0.04, segs=1)
        for sy in (-1, 1):
            beam(d, (cx - w * 0.36, sy * 0.125, z0 + 0.35), (cx + w * 0.36, sy * 0.125, z0 + 1.15), 0.1, "5F74A6", d=0.03)
            beam(d, (cx + w * 0.36, sy * 0.125, z0 + 0.35), (cx - w * 0.36, sy * 0.125, z0 + 1.15), 0.1, "5F74A6", d=0.03)
            d.box((w * 0.5, 0.03, 0.12), (cx, sy * 0.125, z0 + 2.25), "14161C")                # Sehschlitz
            for ix in (-1, 1):
                for z in (0.2, 1.4, 2.7):
                    rivet(d, T(cx + ix * w * 0.42, sy * 0.1, z0 + z), 0.07, STEEL_L)
        d.box((w + 0.02, 0.22, 0.12), (cx, 0, z0 + 1.4), GOLD)
        hazard(d, (cx - w * 0.5, 0, z0 + 0.1), (cx + w * 0.5, 0, z0 + 0.1), 4, 0.18, 0.2)
        d.box((0.1, 0.3, 0.4), (-s * (w - 0.1), 0, z0 + 1.4), DK, bevel=0.03, segs=1)          # Riegel
    for z in (0.5, h - 0.5):                                                   # Scharniere
        d.cyl(0.07, 0.3, (0, -0.02, z0 + z), DK, sides=6)
    return d


def tor(tier):
    name = "b_tor_%d" % tier
    reset()
    root = empty(name)
    rng = rng_for(name)
    B = Part()
    pw = 0.66                                                                  # Pfostenbreite -> Durchfahrt 4 - 2·0,66 = 2,68 m
    ph = 3.15                                                                  # Unterkante des Sturzes (Durchfahrtshöhe 3,05 über der Schwelle)
    px = 2.0 - pw * 0.5
    inner = 2.0 - pw
    post = (WOOD, ST, "5F74A6")[tier]
    pd = (0.9, 1.2, 1.2)[tier]
    B.box((2.7, 0.5, 0.07), (0, 0, 0.035), (WOOD_D, ST_D, METAL_D)[tier])     # Schwelle
    for s in (-1, 1):
        x = s * px
        if tier == 0:                                                          # Holz: Balkenpfosten auf Steinfuß, Seilbindung, Streben
            B.box((pw + 0.1, pd + 0.16, 0.34), (x, 0, 0.17), ST_D, bevel=0.06, segs=1)
            B.box((pw - 0.06, pd - 0.1, ph), (x, 0, ph * 0.5), jit("BE7638", rng), bevel=0.07, segs=1)
            for z in (1.0, 2.5):
                B.box((pw, pd - 0.04, 0.12), (x, 0, z), ROPE)
            for sy in (-1, 1):
                beam(B, (x, sy * (pd * 0.5 + 0.38), 0.1), (x, sy * (pd * 0.5 - 0.1), 1.6), 0.14, WOOD_D)
            B.box((0.3, 0.05, 0.9), (x, -pd * 0.5 + 0.03, 1.7), "C98A48", r=rot(0, 4 * s, 0))   # geflicktes Brett
        elif tier == 1:                                                        # Stein: zwei Türmchen mit Zinnen und blau-goldener Kappe
            B.box((pw + 0.12, pd + 0.14, 0.34), (x, 0, 0.17), ST_D, bevel=0.06, segs=1)
            B.box((pw, pd, 4.1), (x, 0, 2.05), ST, bevel=0.08, segs=1)
            for (dy, z, w) in ((-1, 0.9, 0.4), (-1, 1.7, 0.34), (-1, 3.5, 0.4), (1, 1.3, 0.4), (1, 2.4, 0.36), (1, 3.3, 0.4)):
                B.box((w, 0.06, 0.26), (x + rng.uniform(-0.1, 0.1), dy * pd * 0.5, z), jit(ST_L, rng))
            for (dz, w) in ((0.7, 0.5), (1.5, 0.44), (2.3, 0.5), (3.0, 0.4)):
                B.box((0.06, w, 0.26), (x + s * pw * 0.5, rng.uniform(-0.25, 0.25), dz), jit(ST_L, rng))
            B.box((pw + 0.2, pd + 0.2, 0.2), (x, 0, 4.1), ST_D, bevel=0.05, segs=1)
            for sy in (-1, 1):
                for sx in (-1, 1):
                    B.box((0.26, 0.34, 0.3), (x + sx * 0.26, sy * 0.5, 4.35), ST_L, bevel=0.04, segs=1)
            B.box((0.5, 0.8, 0.12), (x, 0, 4.26), BLUE)
            B.cyl(0.36, 0.3, (x, 0, 4.46), GOLD, r=rot(0, 0, 45) @ S(1, 1.4, 1), r2=0.1, sides=4)
            B.box((0.3, 0.05, 0.14), (x, -pd * 0.5 - 0.07, 0.22), "6E9A38")
        else:                                                                  # Metall: Panzerpfeiler mit Nieten, Warnstreifen, Goldkappe
            B.box((pw + 0.14, pd + 0.16, 0.36), (x, 0, 0.18), METAL_D)
            B.box((pw, pd, 3.9), (x, 0, 1.95), "5F74A6", bevel=0.07, segs=1)
            for sy in (-1, 1):
                B.box((pw - 0.2, 0.06, 1.5), (x, sy * pd * 0.5, 2.0), METAL_L)
                hazard(B, (x - pw * 0.5, sy * (pd * 0.5 + 0.005), 0.62), (x + pw * 0.5, sy * (pd * 0.5 + 0.005), 0.62), 3, 0.22, 0.05)
                for sx in (-1, 1):
                    for z in (1.05, 2.0, 2.95):
                        rivet(B, T(x + sx * 0.25, sy * (pd * 0.5 + 0.01), z), 0.08, STEEL_L)
            B.box((0.06, pd - 0.3, 1.5), (x + s * pw * 0.5, 0, 2.0), METAL_L)
            B.box((pw + 0.16, pd + 0.16, 0.22), (x, 0, 3.92), GOLD, bevel=0.05, segs=1)
            B.cyl(0.4, 0.3, (x, 0, 4.18), "5F74A6", r=rot(0, 0, 45) @ S(1, 1.5, 1), r2=0.16, sides=4)
            B.ball(0.14, (x, 0, 4.38), GOLD, subdiv=1)
    # Sturz und Dach
    if tier == 0:
        B.box((4.3, 0.5, 0.34), (0, 0, ph + 0.17), jit(WOOD_D, rng), bevel=0.06, segs=1)
        for s in (-1, 1):
            beam(B, (s * (px - 0.3), 0, ph - 0.55), (s * (px - 0.95), 0, ph + 0.02), 0.14, WOOD_D, d=0.3)   # Kopfbänder
        roof_gable(B, (0, 0, ph + 0.34), 4.1, 1.8, 0.75, RED, rng)
        B.box((0.5, 0.36, 0.05), (0.9, -0.6, ph + 0.75), "C98A48", r=rot(40, 0, 6))            # Flicken auf dem Dach
        top = ph + 1.2
    elif tier == 1:
        B.box((2.9, 0.8, 0.5), (0, 0, ph + 0.25), ST, bevel=0.06, segs=1)                      # Steinsturz
        for i in range(5):
            B.box((0.5, 0.86, 0.2), (-1.1 + i * 0.55, 0, ph + 0.6), jit((ST_L, ST_D)[i % 2], rng), bevel=0.04, segs=1)
        for sy in (-1, 1):
            B.box((0.5, 0.1, 0.56), (0, sy * 0.44, ph + 0.3), ST_D, bevel=0.04, segs=1)        # Schlussstein
        roof_gable(B, (0, 0, ph + 0.7), 2.9, 1.3, 0.5, BLUE, rng, over=0.16, ridge=GOLD)
        top = 4.7
    else:
        B.box((2.9, 0.9, 0.5), (0, 0, ph + 0.25), METAL, bevel=0.05, segs=1)                   # Stahlträger
        B.box((2.94, 0.96, 0.1), (0, 0, ph + 0.08), GOLD)
        for sy in (-1, 1):
            hazard(B, (-1.34, sy * 0.455, ph + 0.32), (1.34, sy * 0.455, ph + 0.32), 8, 0.2, 0.03)
            for i in range(5):
                rivet(B, T(-1.2 + i * 0.6, sy * 0.46, ph + 0.5), 0.07, STEEL_L)
        B.box((3.1, 1.3, 0.12), (0, 0, ph + 0.62), "4F6294", bevel=0.04, segs=1)              # Panzerdach
        B.box((3.14, 1.34, 0.06), (0, 0, ph + 0.56), GOLD)
        for sx in (-1.0, 1.0):
            B.box((0.3, 0.3, 0.2), (sx, -0.3, ph + 0.78), DK, bevel=0.04, segs=1)             # Scheinwerfer
        top = 4.6
    # Schild mit Stern über der Durchfahrt
    for sy in (-1, 1):
        if tier == 0:
            B.box((1.0, 0.06, 0.5), (0, sy * 0.28, ph + 0.17), CREAM)
            star(B, (0, sy * 0.32, ph + 0.17), 0.19, BLUE, 0.03, r=rot(90 * -sy, 0, 0))
        else:
            B.cyl(0.26, 0.08, (0, sy * (0.5 if tier == 1 else 0.48), ph + 0.3), BLUE, r=AX_Y, sides=8)
            star(B, (0, sy * (0.56 if tier == 1 else 0.54), ph + 0.3), 0.17, "white" if tier == 1 else GOLD, 0.03, r=rot(90 * -sy, 0, 0))
    # Laternen: links Zustandslampe (grün = offen, rot = zu), rechts warme Laterne
    lz = 2.55
    for s in (-1, 1):
        x = s * (px - 0.02)
        y = -pd * 0.5 - 0.2
        B.box((0.08, 0.3, 0.08), (x, -pd * 0.5 - 0.1, lz + 0.28), DK)
        B.box((0.3, 0.3, 0.07), (x, y, lz + 0.2), DK)
        B.box((0.26, 0.26, 0.05), (x, y, lz - 0.2), DK)
        B.cyl(0.2, 0.14, (x, y, lz + 0.3), DK, r=rot(0, 0, 45), r2=0.04, sides=4)
    for nm, c in (("lamp_open_glow", GREEN), ("lamp_closed_glow", "FF5A4A")):
        g = Part()
        g.box((0.22, 0.22, 0.34), (-(px - 0.02), -pd * 0.5 - 0.2, lz), c)
        g.build(nm, root)
    g = Part()
    g.box((0.22, 0.22, 0.34), (px - 0.02, -pd * 0.5 - 0.2, lz), GLOW)
    if tier == 2:
        for sx in (-1.0, 1.0):
            g.box((0.2, 0.04, 0.12), (sx, -0.46, ph + 0.78), "FFF2B8")
    g.build("lamp_glow", root)
    # Kleinkram am Fuß (außerhalb der Durchfahrt)
    if tier == 0:
        sandbag_row(B, (px - 0.35, -0.95, 0.0), (px + 0.3, -0.95, 0.0), 1, rng)
        B.cyl(0.2, 0.5, (-px, -0.82, 0.25), "8A5A2E", sides=8)                 # Fass
        B.cyl(0.21, 0.05, (-px, -0.82, 0.36), DK, sides=8)
    elif tier == 1:
        for sx in (-1, 1):
            B.box((0.44, 0.3, 0.3), (sx * px, -0.82, 0.15), jit(ST_L, rng), bevel=0.05, segs=1)
    else:
        for sx in (-1, 1):
            B.box((0.5, 0.26, 0.5), (sx * px, -0.8, 0.25), HAZ_Y, bevel=0.04, segs=1)
            B.box((0.52, 0.28, 0.12), (sx * px, -0.8, 0.25), HAZ_K)
    # Banner an den Pfosten (Stein/Metall) – eigene Objekte in Flaggenfarbe
    if tier >= 1:
        for s, nm in ((-1, "banner_l"), (1, "banner_r")):
            c = Part()
            c.box((0.46, 0.04, 1.1), (0, 0, -0.55), "flag")
            c.cyl(0.23, 0.04, (0, 0, -1.1), "flag", r=AX_Y @ rot(0, 0, 45) @ S(1, 0.7, 1), sides=4)
            star(c, (0, -0.03, -0.5), 0.15, "white", 0.02, r=STAR_FRONT)
            c.build(nm, root, (s * px, -pd * 0.5 - 0.04, 3.6))
            B.box((0.56, 0.08, 0.06), (s * px, -pd * 0.5 - 0.04, 3.62), GOLD_D)
    # Flügel
    h = 2.95
    for s, nm in ((-1, "door_l"), (1, "door_r")):
        door_leaf(tier, s, inner - 0.03, h, rng).build(nm, root, (s * inner, 0, 0))
    flag(root, B, (-px, 0.2, top - 0.2), h=1.6, size=(0.86, 0.56))
    # Schaden: Ruß und Brocken an den Pfosten
    t = Part()
    soot(t, T(px, -pd * 0.5 - 0.01, 1.3), 0.24, 0.34)
    soot(t, T(-px, pd * 0.5 + 0.01, 1.8) @ rot(0, 0, 180), 0.24, 0.3)
    debris(t, [(px + 0.1, -0.9, 0.0), (-px - 0.1, 0.9, 0.0)], rng, cols=((WOOD, WOOD_D), (ST, ST_D), (METAL, METAL_D))[tier])
    t.build("dmg1_body", root)
    t = Part()
    soot(t, T(-px, -pd * 0.5 - 0.01, 2.0), 0.26, 0.4)
    soot(t, T(px, pd * 0.5 + 0.01, 1.1) @ rot(0, 0, 180), 0.26, 0.36)
    soot(t, T(0.6, -0.26 if tier == 0 else -0.42, ph + 0.2), 0.3, 0.14)
    debris(t, [(px - 0.2, 0.9, 0.0), (-px + 0.2, -0.95, 0.0), (-px - 0.2, -0.7, 0.0)], rng, cols=((WOOD, WOOD_D), (ST, ST_D), (METAL, METAL_D))[tier], s=0.28)
    t.build("dmg2_body", root)
    empty("fx_smoke_dmg", root, (px, 0, top - 0.6))
    B.build("body", root)
    empty("bubble", root, (0, 0, top + 1.4))
    finish(name, hide=("lamp_closed", "dmg"), limit=6000)


# ------------------------------------------------------------------ Baugerüste
def scaffold(w, h):
    """Gerüst um w × h Felder: Stangen am Rand, Riegel in Etagen, Laufbretter, Leitern, Planen, Warnband. Innen frei."""
    name = "b_scaffold_%dx%d" % (w, h)
    reset()
    root = empty(name)
    rng = rng_for(name)
    B = Part()
    X, Y = w * 1.0 - 0.06, h * 1.0 - 0.06                                      # halbe Außenmaße
    top = {1: 3.5, 2: 4.0, 3: 4.9, 4: 5.6}[max(w, h)] if min(w, h) > 1 else 3.5
    levels = [1.7, 3.3] + ([4.8] if top > 5.2 else [])
    pole, led = STEEL_L, STEEL
    # Stangen am Rand, alle 2 m
    xs = [-X + i * (2 * X / w) for i in range(w + 1)]
    ys = [-Y + i * (2 * Y / h) for i in range(h + 1)]
    pts = [(x, -Y) for x in xs] + [(x, Y) for x in xs] + [(-X, y) for y in ys[1:-1]] + [(X, y) for y in ys[1:-1]]
    for (x, y) in pts:
        hh = top + rng.uniform(-0.15, 0.25)
        B.cyl(0.055, hh, (x, y, hh * 0.5), jit(pole, rng, 0.05), sides=6)
        B.box((0.22, 0.22, 0.05), (x, y, 0.025), WOOD_D)
    # Riegel je Etage (vorn nur oben, damit das Gebäude sichtbar bleibt)
    for i, z in enumerate(levels):
        B.box((2 * X, 0.07, 0.07), (0, Y, z), led)
        B.box((0.07, 2 * Y, 0.07), (-X, 0, z), led)
        B.box((0.07, 2 * Y, 0.07), (X, 0, z), led)
        B.box((2 * X, 0.07, 0.07), (0, -Y, z), led)
        B.box((2 * X, 0.05, 0.05), (0, Y, z + 0.9), led)                       # Geländer hinten
    # Schrägstreben
    for i in range(w):
        a, b_ = xs[i], xs[i + 1]
        if i % 2 == 0:
            beam(B, (a, Y, 0.1), (b_, Y, levels[0]), 0.05, led)
        else:
            beam(B, (b_, Y, 0.1), (a, Y, levels[0]), 0.05, led)
    for sx in (-1, 1):
        for i in range(h):
            a, b_ = ys[i], ys[i + 1]
            lo, hi = (0.1, levels[0]) if (i + (sx > 0)) % 2 == 0 else (levels[0], levels[1])
            beam(B, (sx * X, a, lo), (sx * X, b_, hi), 0.05, led)
    # Laufbretter: hinten auf beiden Etagen, rechts unten, vorn oben ein kurzes Stück
    def deck(x0, x1, y0, y1, z):
        n = max(1, int(round((x1 - x0) / 1.0))) if abs(x1 - x0) > abs(y1 - y0) else max(1, int(round((y1 - y0) / 1.0)))
        for k in range(n):
            if abs(x1 - x0) > abs(y1 - y0):
                a = x0 + (x1 - x0) * k / n; b2 = x0 + (x1 - x0) * (k + 1) / n
                B.box((b2 - a - 0.03, y1 - y0, 0.05), ((a + b2) * 0.5, (y0 + y1) * 0.5, z + 0.06 + rng.uniform(-0.012, 0.012)), jit(WOOD_L, rng, 0.1))
            else:
                a = y0 + (y1 - y0) * k / n; b2 = y0 + (y1 - y0) * (k + 1) / n
                B.box((x1 - x0, b2 - a - 0.03, 0.05), ((x0 + x1) * 0.5, (a + b2) * 0.5, z + 0.06 + rng.uniform(-0.012, 0.012)), jit(WOOD_L, rng, 0.1))
    dw = 0.42
    deck(-X, X, Y - dw, Y, levels[0])
    deck(-X, X, Y - dw, Y, levels[1])
    if h > 1:
        deck(X - dw, X, -Y, Y - dw, levels[0])
        deck(-X, -X + dw, -Y + (2 * Y / h), Y - dw, levels[1])
    deck(-X, -X + 2 * X / w, -Y, -Y + dw, levels[1])
    # Leitern
    ladder(B, (-X + 0.5, -Y - 0.25, 0.0), (-X + 0.5, -Y + 0.08, levels[1] + 0.3), 0.44, WOOD_D, step=0.42)
    ladder(B, (X - 0.3, Y + 0.3, 0.0), (X - 0.3, Y + 0.02, levels[0] + 0.3), 0.44, WOOD_D, step=0.42)
    # Warnband vorn und an den Seiten, Schild
    hazard(B, (-X, -Y - 0.04, 0.95), (X, -Y - 0.04, 0.95), max(6, w * 4), 0.13, 0.03)
    if h > 1:
        for sx in (-1, 1):
            hazard(B, (sx * (X + 0.04), -Y, 0.95), (sx * (X + 0.04), Y, 0.95), h * 4, 0.13, 0.03)
    m = T(X - 0.5, -Y - 0.06, 1.55) @ rot(0, 45, 0)
    B.box((0.5, 0.04, 0.5), (0, 0, 0), HAZ_Y, r=m)
    B.box((0.08, 0.05, 0.26), (0, 0, 0), HAZ_K, r=T(X - 0.5, -Y - 0.08, 1.6))
    B.box((0.08, 0.05, 0.08), (0, 0, 0), HAZ_K, r=T(X - 0.5, -Y - 0.08, 1.4))
    # Material auf den Brettern: Ziegelstapel, Eimer, Bretterstapel, Mörtelsack
    bx = -X + 0.7
    for k in range(6):
        B.box((0.34, 0.17, 0.12), (bx + (k % 2) * 0.36, Y - 0.22, levels[0] + 0.15 + (k // 2) * 0.125), jit("C2613F", rng, 0.1))
    B.cyl(0.13, 0.24, (X - 0.9, Y - 0.2, levels[0] + 0.21), "4A5263", r2=0.16, sides=6)
    for k in range(3):
        B.box((1.5, 0.2, 0.05), (0.1, Y - 0.2, levels[1] + 0.115 + k * 0.055), jit(WOOD, rng, 0.1), r=rot(0, 0, rng.uniform(-4, 4)))
    B.box((0.5, 0.3, 0.2), (X - 0.5, Y - 0.2, levels[1] + 0.19), CREAM, bevel=0.07, segs=1)
    # Flaschenzug mit Eimer an der höchsten Stange vorn rechts
    B.box((0.07, 0.9, 0.07), (X, -Y + 0.4, top - 0.2), led)
    tube(B, (X, -Y + 0.75, top - 0.22), (X, -Y + 0.75, top - 1.6), 0.015, ROPE, sides=4)
    B.cyl(0.15, 0.26, (X, -Y + 0.75, top - 1.72), "E8943A", r2=0.18, sides=6)
    B.cyl(0.09, 0.06, (X, -Y + 0.75, top - 0.2), DK, r=AX_X, sides=6)
    B.build("body", root)
    # Planen (wiegen sich): hinten breit, links schmal, vorn ein Stück
    def tarp(nm, a, b_, z_top, drop, color, strips=4):
        a = Vector(a); b2 = Vector(b_)
        d = b2 - a
        yaw = math.degrees(math.atan2(d.y, d.x))
        c = Part()
        for k in range(strips):
            ln = d.length / strips
            dz = drop * (1.0 - (0.12 if k % 2 else 0.0)) - (0.1 if k == strips - 1 else 0)
            c.box((ln + 0.01, 0.03, dz), (0, 0, 0), shade(color, 1.0 if k % 2 == 0 else 0.9),
                  r=rot(0, 0, yaw) @ T(-d.length * 0.5 + (k + 0.5) * ln, 0.03 * (1 if k % 2 else -1), -dz * 0.5))
        c.box((d.length, 0.06, 0.06), (0, 0, 0), ROPE, r=rot(0, 0, yaw))
        mid = (a + b2) * 0.5
        c.build(nm, root, (mid.x, mid.y, z_top))
    tarp("sway_tarp1", (xs[w // 2], Y + 0.06, 0), (X, Y + 0.06, 0), levels[1] + 0.85, 1.75, "3B8FD0", 4)
    if w > 2:
        tarp("sway_tarp2", (-X, Y + 0.06, 0), (-X + 2 * X / w, Y + 0.06, 0), levels[0] - 0.05, 1.45, "E8943A", 3)
    if h > 1:
        tarp("sway_tarp3", (-X - 0.06, Y - 2 * Y / h, 0), (-X - 0.06, Y, 0), levels[1] + 0.85, 1.7, "E8943A", 3)
    else:
        tarp("sway_tarp3", (-X - 0.06, -Y, 0), (-X - 0.06, Y, 0), levels[1] + 0.85, 1.5, "E8943A", 3)
    finish(name, hide=(), limit=2500, yaw=-35, pitch=28)


TABLE = {}
for _t in range(3):
    TABLE["wall_post_%d" % _t] = (lambda t=_t: wall("post", t))
    TABLE["wall_link_%d" % _t] = (lambda t=_t: wall("link", t))
TABLE["wall_site"] = wall_site
for _t in range(3):
    TABLE["b_tor_%d" % _t] = (lambda t=_t: tor(t))
for _w, _h in ((2, 2), (3, 3), (4, 4), (3, 2), (4, 3), (2, 1)):
    TABLE["b_scaffold_%dx%d" % (_w, _h)] = (lambda w=_w, h=_h: scaffold(w, h))

if __name__ == "__main__":
    run(TABLE, sys.argv)
