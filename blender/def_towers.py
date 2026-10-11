"""Verteidigungstürme t_* (Paket 6) – ersetzt die Modelle aus towers.py. Aufbau, den src/tower.gd erwartet:
  base  – fester Sockel                 head  – dreht um Z, Ursprung oben auf dem Sockel
  pitch – Kind von head, neigt um X, trägt die Läufe (zeigen nach -Y); Rückstoß verschiebt pitch
  muzzle, muzzle2, muzzle3 – Leerobjekte an den Mündungen (Kinder von pitch)
  fx_shell – Hülsenauswurf (Kind von pitch)      work_1 – hier bringt ein Bewohner Munition (am Boden)
  fx_smoke_dmg – Rauch bei schwerem Schaden      gunner – Platz des Schützen (nur Wachturm, Kind von head)
Ausbau-Aussehen:  lvmax3_* (nur Stufe 1–3: Holz), lv4_* (ab 4: Stein, Schutzschild), lvmax6_* (bis 6), lv7_* (ab 7: Panzerung, Gold)
Schaden:          dmg1_* (unter 60 % Leben: Ruß, Brocken), dmg2_* (unter 30 %: Brandflecken, verbogene Teile)
Aufruf: python3 blender/def_towers.py [t_mg ...]"""
import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from def_kit import *

AMMO = {  # Munition neben dem Sockel: (Anzahl, Hülsenfarbe, Spitzenfarbe, Kistenfarbe)
    "mg": (6, BRASS, "B8862A", OLIVE), "aa": (5, BRASS, RED, OLIVE), "cannon": (3, "3A4152", GOLD, OLIVE), "flame": (3, RED, "23262E", "8A5A2E"),
    "mortar": (3, "4B5670", RED, OLIVE), "tesla": (4, "2A86E8", CYAN, "566078"), "rocket": (3, "F4F6FA", RED, OLIVE),
    "ice": (4, "BFE8FF", "3A86C8", "566078"), "watch": (6, BRASS, "B8862A", WOOD)}


K = 1.0      # Vergrößerung von Kopf und Geschütz (große Türme); der Sockel bleibt unvergrößert


class HPart(KPart):
    """Teil von Kopf/Geschütz: Geometrie und Lage (bei Kindern von head/pitch) werden mit K vergrößert."""

    def build(self, name, parent=None, loc=(0, 0, 0), **kw):
        if parent is not None and parent.parent is not None:
            loc = (loc[0] * K, loc[1] * K, loc[2] * K)
        return super().build(name, parent, loc, **kw)


def HP():
    return HPart(K)


def hempty(name, parent, loc):
    return empty(name, parent, (loc[0] * K, loc[1] * K, loc[2] * K))


def tower_base(root, kind, R, h, rng, bags="front"):
    """Sockel mit Fundament, Trommel, Sandsäcken und Munitionskisten; Leiter, Holz-/Stein-/Panzer-Ausbau als Zustands-Objekte.
    R = Radius der Trommel, h = Höhe der Trommel. Oberkante (Ursprung von head) = h + 0.22."""
    big = R > 1.6
    Rs = R + 0.6
    z0 = 0.27
    b = Part()
    b.cyl(Rs, 0.2, (0, 0, 0.1), ST_D, sides=20, bevel=0.06, segs=1)                                  # Fundament
    block_ring(b, Rs - 0.31, 0.2, 0.07, 16 if big else 12, (ST, ST_L, ST), rng, depth=0.5, bevel=0.0, gap=0.94)   # Pflaster mit Fugen
    b.cyl(R, h - 0.2, (0, 0, 0.2 + (h - 0.2) * 0.5), shade(ST, 0.88), r2=R * 0.97, sides=20)          # Trommel
    b.cyl(R + 0.06, 0.22, (0, 0, h + 0.11), "9A6A3C", sides=20, bevel=0.04, segs=1)                   # Deckplatte
    if bags == "front":
        sandbag_arc(b, R + 0.42, -62, 62, 2, z0, rng)
    else:
        sandbag_arc(b, R + 0.42, -72, -22, 2, z0, rng)
        sandbag_arc(b, R + 0.42, 22, 72, 2, z0, rng)
    n, shell, tip, cc = AMMO[kind]
    ammo_crate(b, ring_m(R + 0.33, -112, z0), color=cc)
    ammo_crate(b, ring_m(R + 0.36, -112, z0 + 0.36) @ rot(0, 0, 9), size=(0.6, 0.4, 0.3), color=shade(cc, 1.12), stripe=RED)
    ammo_open(b, ring_m(R + 0.36, 118, z0) @ rot(0, 0, 180), size=(0.8, 0.5, 0.36) if big else (0.72, 0.46, 0.34), color=cc, n=n, shell=shell, tip=tip)
    wx, wy = ring_xy(R + 0.36, -112)
    base = b.build("base", root)
    wk = (Rs + 0.35) / (R + 0.36)
    empty("work_1", root, (wx * wk, wy * wk, 0.0))                                                      # hier steht der Träger mit der Munition
    # ---- Stufe 1–3: Holzverkleidung, Eisenreifen, Holzschild mit Stern
    t = Part()
    plank_ring(t, R + 0.035, z0, h + 0.0, 22 if big else 16, WOOD, rng)
    for z in (z0 + 0.14, h - 0.16):
        t.cyl(R + 0.085, 0.07, (0, 0, z), DK, sides=18)
    m = ring_m(R + 0.1, 0, min(h * 0.5 + 0.34, h - 0.3))
    sh = min(0.6, h - 0.45)
    t.box((sh * 1.15, 0.07, sh), (0, 0, 0), WOOD_L, r=m)
    star(t, (0, -0.05, 0), sh * 0.36, "white", 0.03, r=m @ STAR_FRONT)
    for a in (48, -48, 132, -132):                                                                      # schräge Stützbalken
        x1, y1 = ring_xy(R + 0.52, a); x2, y2 = ring_xy(R + 0.1, a)
        beam(t, (x1, y1, 0.22), (x2, y2, h * 0.72), 0.13, jit(WOOD_D, rng))
    t.build("lvmax3_wood", base)
    # ---- ab Stufe 4: Steinkranz, blaue Deckplatte, Plakette
    t = Part()
    block_ring(t, R + 0.1, z0 - 0.02, 0.55, 12 if big else 8, (ST, ST_L), rng, depth=0.36, bevel=0.08)
    if h - 0.84 > 0.25:
        block_ring(t, R + 0.03, 0.82, h - 0.84, 13 if big else 10, (ST_L, ST, ST_D), rng, depth=0.2, bevel=0.0, off=0.5, gap=0.95)
    t.cyl(R + 0.13, 0.26, (0, 0, h + 0.11), BLUE, sides=20, bevel=0.06, segs=1)
    m = ring_m(R + (0.14 if h - 0.84 > 0.25 else 0.29), 0, min(h * 0.5 + 0.36, h - 0.28))
    t.box((sh * 1.1, 0.12, sh), (0, 0, 0), BLUE, r=m, bevel=0.05, segs=1)
    star(t, (0, -0.07, 0), sh * 0.34, "white", 0.03, r=m @ STAR_FRONT)
    t.build("lv4_stone", base)
    # ---- bis Stufe 6: Holzleiter / ab 7: Stahlleiter
    for nm, c in (("lvmax6_ladder", WOOD_D), ("lv7_ladder", STEEL)):
        t = Part()
        ladder(t, (0, R + 0.62, 0.22), (0, R + 0.2, h + 0.34), 0.52, c)
        t.build(nm, base)
    # ---- ab Stufe 7: Panzerplatten, goldener Reif, Nieten
    t = Part()
    ph = h - 0.3
    for a in (45, 135, -45, -135):
        m = ring_m(R + 0.3, a, 0.3 + ph * 0.5)
        t.box((R * 0.62, 0.14, ph), (0, 0, 0), "5E79B8", r=m, bevel=0.05, segs=1)
        t.box((R * 0.64, 0.17, 0.09), (0, 0, 0), GOLD, r=m @ T(0, 0, ph * 0.5 - 0.1))
        for sx in (-1, 1):
            rivet(t, m @ T(sx * R * 0.24, -0.08, -ph * 0.22), 0.08, GOLD)
    t.cyl(R + 0.18, 0.1, (0, 0, h + 0.1), GOLD, sides=20)
    t.build("lv7_armor", base)
    # ---- Schaden
    t = Part()
    soot_flat(t, (ring_xy(Rs - 0.3, 150) + (0.275,)), 0.42, 0.3, yaw=20)
    soot_flat(t, (ring_xy(Rs - 0.28, -80) + (0.275,)), 0.3, 0.24, yaw=70)
    soot(t, ring_m(R + 0.62, 30 if bags == "front" else 48, z0 + 0.22), 0.3, 0.2)
    debris(t, [ring_xy(Rs - 0.2, a) + (0.25,) for a in (165, 95, -75)], rng)
    t.build("dmg1_base", base)
    t = Part()
    soot_flat(t, (ring_xy(Rs - 0.35, 90) + (0.28,)), 0.55, 0.4, yaw=40)
    soot_flat(t, (ring_xy(Rs - 0.3, -150) + (0.28,)), 0.45, 0.34)
    soot(t, ring_m(R + 0.62, -35 if bags == "front" else -50, z0 + 0.2), 0.34, 0.22)
    debris(t, [ring_xy(Rs - 0.15, a) + (0.25,) for a in (80, 105, -140, -165, 20)], rng, s=0.27)
    x1, y1 = ring_xy(Rs - 0.1, -160)
    beam(t, (x1, y1, 0.3), (x1 * 0.75, y1 * 0.75 + 0.3, 0.36), 0.14, WOOD_D, d=0.06)                    # herausgebrochenes Brett
    t.build("dmg2_base", base)
    return base, h + 0.22


def head_damage(parent, spots1, spots2, extra=None):
    """Ruß am Geschütz: spots = Liste (Matrix, rx, rz) – Scheiben schauen nach lokal -Y der Matrix."""
    t = HP()
    for m, rx, rz in spots1:
        soot(t, m, rx, rz)
    t.build("dmg1_head", parent)
    t = HP()
    for m, rx, rz in spots2:
        soot(t, m, rx, rz)
    if extra:
        extra(t)
    t.build("dmg2_head", parent)


UP = rot(-90, 0, 0)        # Rußscheibe schaut nach oben
LEFT = rot(0, 0, -90)      # ... nach -X
RIGHT = rot(0, 0, 90)      # ... nach +X


def barrel(p, x, z, y0, y1, r, color=DARK, tip=STEEL, tip_r=None, tip_len=0.2, sides=8, r_front=None):
    """Lauf entlang -Y von y0 (hinten) bis y1 (vorn, y1 < y0), mit Mündungsstück und dunkler Bohrung."""
    p.cyl(r, y0 - y1, (x, (y0 + y1) * 0.5, z), color, r=AX_Y, r2=r_front, sides=sides)
    tr = (r_front or r) * 1.4 if tip_r is None else tip_r
    p.cyl(tr, tip_len, (x, y1, z), tip, r=AX_Y, sides=sides, bevel=0.03, segs=1)
    p.cyl(tr * 0.62, 0.02, (x, y1 - tip_len * 0.5 - 0.005, z), "14161C", r=AX_Y, sides=sides)


def yoke(hd, half, z_ax, depth=0.5, th=0.2, color=STEEL, y=0.0):
    """Gabel, in der das Geschütz hängt."""
    for s in (-1, 1):
        hd.box((th, depth, z_ax + 0.22), (s * half, y, (z_ax + 0.22) * 0.5), color, bevel=0.06, segs=1)
        hd.cyl(0.13, th + 0.1, (s * half, y, z_ax), GOLD_D, r=AX_X, sides=8)


def muzzles(pitch, pts):
    for i, q in enumerate(pts):
        hempty("muzzle" if i == 0 else "muzzle%d" % (i + 1), pitch, q)


def begin(name, kind, R, h, bags="front", k=1.0):
    global K
    reset()
    root = empty(name)
    rng = rng_for(name)
    K = 1.0
    base, hz = tower_base(root, kind, R, h, rng, bags)
    K = k
    return root, base, hz, rng


def smoke(root, loc):
    empty("fx_smoke_dmg", root, loc)


# ------------------------------------------------------------------ MG-Turm
def t_mg():
    root, base, hz, rng = begin("t_mg", "mg", 1.1, 1.5)
    hd = HP()
    hd.cyl(0.86, 0.3, (0, 0, 0.15), DARK, r2=0.74, sides=16, bevel=0.05, segs=1)
    hd.cyl(0.9, 0.08, (0, 0, 0.05), STEEL, sides=16)
    yoke(hd, 0.93, 1.0, depth=0.56, y=-0.1)
    hd.box((1.3, 0.3, 0.12), (0, 0.62, 0.36), STEEL, bevel=0.04, segs=1)                 # Trittblech hinten
    head = hd.build("head", root, (0, 0, hz))
    p = HP()
    p.box((1.46, 1.66, 1.02), (0, 0.15, 0), RED, bevel=0.3, segs=3)                      # Gehäuse
    p.box((1.16, 0.4, 0.78), (0, -0.7, -0.03), RED_D, bevel=0.1, segs=1)                 # Blende
    p.cyl(0.17, 2.02, (0, 0, 0), STEEL, r=AX_X, sides=8)                                 # Schildzapfen
    star(p, (0, 0.22, 0.515), 0.4, "white", 0.04)
    p.box((0.9, 0.5, 0.1), (0, 0.72, 0.5), RED_D, bevel=0.04, segs=1)                    # Wartungsklappe
    for sx in (-0.33, 0.33):
        barrel(p, sx, 0.0, -0.8, -2.0, 0.12, DARK, STEEL, tip_r=0.19, tip_len=0.26)
        p.cyl(0.21, 0.62, (sx, -1.16, 0), "4A5263", r=AX_Y, sides=10, bevel=0.03, segs=1)    # Kühlmantel
        for y in (-0.98, -1.16, -1.34):
            p.cyl(0.235, 0.05, (sx, y, 0), STEEL, r=AX_Y, sides=10)
    p.box((0.06, 0.06, 0.24), (0, -0.5, 0.6), DARK)                                      # Visier
    p.torus(0.12, 0.028, (0, -0.5, 0.8), DARK, r=AX_Y, seg=8, tseg=4)
    for sx in (-0.26, 0.26):                                                             # Spatengriffe
        tube(p, (sx, 0.95, 0.12), (sx, 1.3, 0.12), 0.045, DARK, sides=5)
    tube(p, (-0.3, 1.3, 0.12), (0.3, 1.3, 0.12), 0.055, WOOD_D, sides=6)
    p.box((0.42, 0.78, 0.64), (0.98, 0.2, -0.02), OLIVE, bevel=0.06, segs=1)             # Gurtkasten
    p.box((0.44, 0.8, 0.1), (0.98, 0.2, 0.26), OLIVE_D)
    for i in range(4):                                                                   # Patronengurt
        p.box((0.11, 0.2, 0.07), (0.9 - i * 0.045, -0.3 - i * 0.02, 0.36 + (0.06 if i in (1, 2) else 0.0)), BRASS, r=rot(0, 12, 0))
    p.box((0.06, 0.34, 0.22), (-0.735, -0.1, 0.06), "14161C")                            # Auswurfschacht
    pitch = p.build("pitch", head, (0, -0.1, 1.0))
    muzzles(pitch, [(-0.33, -2.14, 0), (0.33, -2.14, 0)])
    hempty("fx_shell", pitch, (-0.86, -0.1, 0.06))
    t = HP()                                                                           # ab 4: Schutzschild
    m = T(0, -0.86, 0.16) @ rot(-10, 0, 0)
    t.box((2.1, 0.1, 1.3), (0, 0, 0), RED_D, r=m, bevel=0.05, segs=1)
    t.box((1.86, 0.12, 0.24), (0, 0, 0), RED, r=m @ T(0, -0.01, 0.42))
    for sx in (-0.55, 0.55):
        t.box((0.4, 0.13, 0.1), (0, 0, 0), "14161C", r=m @ T(sx, -0.01, 0.42))           # Sehschlitze
    for sx in (-0.95, 0.95):
        for sz in (-0.5, 0.0, 0.5):
            rivet(t, m @ T(sx, -0.06, sz), 0.07)
    t.build("lv4_shield", pitch)
    t = HP()                                                                           # ab 7: Goldbänder, Mündungsringe
    t.box((1.5, 0.14, 1.06), (0, 0.62, 0), GOLD, bevel=0.04, segs=1)
    t.box((1.5, 0.1, 1.06), (0, -0.28, 0), GOLD, bevel=0.03, segs=1)
    for sx in (-0.33, 0.33):
        t.torus(0.2, 0.045, (sx, -1.86, 0), GOLD, r=AX_Y, seg=10, tseg=4)
    t.build("lv7_trim", pitch)
    head_damage(pitch, [(T(0.4, 0.5, 0.52) @ UP, 0.3, 0.24), (T(-0.735, 0.4, 0.1) @ LEFT, 0.3, 0.22)],
                [(T(-0.3, -0.2, 0.52) @ UP, 0.36, 0.3), (T(0.735, -0.45, -0.1) @ RIGHT, 0.26, 0.2), (T(0.33, -1.16, 0.24) @ UP, 0.18, 0.22)])
    smoke(root, (0.2, 0.5, hz + 1.5))
    finish("t_mg", copies=("b_mg",))


# ------------------------------------------------------------------ Luftabwehr
def t_aa():
    root, base, hz, rng = begin("t_aa", "aa", 1.1, 1.5)
    G1, G2 = "3FA35A", "2E7A44"
    hd = HP()
    hd.cyl(0.86, 0.3, (0, 0, 0.15), DARK, r2=0.74, sides=16, bevel=0.05, segs=1)
    hd.cyl(0.9, 0.08, (0, 0, 0.05), STEEL, sides=16)
    yoke(hd, 0.86, 1.05, depth=0.56, y=-0.05)
    hd.cyl(0.05, 1.2, (-0.7, 0.72, 0.8), STEEL, sides=6)                                 # Radarmast
    hd.box((0.5, 0.4, 0.3), (0.55, 0.7, 0.42), G2, bevel=0.06, segs=1)                   # Richtgerät
    head = hd.build("head", root, (0, 0, hz))
    g = HP(); g.box((0.3, 0.05, 0.16), (0.55, 0.49, 0.44), CYAN); g.build("scope_glow", head)
    r = HP()                                                                           # Radarschüssel (dreht)
    r.cyl(0.42, 0.14, (0, -0.1, 0.22), STEEL_L, r=rot(60, 0, 0), r2=0.1, sides=10)
    r.cyl(0.03, 0.3, (0, -0.24, 0.3), DARK, r=rot(60, 0, 0), sides=4)
    r.ball(0.06, (0, -0.37, 0.38), RED, subdiv=1)
    r.box((0.1, 0.1, 0.2), (0, 0, 0.1), DARK)
    r.build("spin_radar", head, (-0.7, 0.72, 1.4))
    p = HP()
    p.box((1.3, 1.5, 0.96), (0, 0.2, 0), G1, bevel=0.26, segs=3)
    p.box((1.0, 0.4, 0.8), (0, -0.62, 0.0), G2, bevel=0.1, segs=1)
    p.cyl(0.16, 1.9, (0, 0, 0), STEEL, r=AX_X, sides=8)
    star(p, (0, 0.3, 0.485), 0.36, "white", 0.04)
    pts = []
    for sx in (-0.3, 0.3):
        for sz in (-0.17, 0.2):
            barrel(p, sx, sz, -0.7, -2.5, 0.075, DARK, STEEL, tip_r=0.125, tip_len=0.34, sides=6)
            p.cyl(0.12, 0.5, (sx, -1.0, sz), "4A5263", r=AX_Y, sides=6)
            if sz > 0:
                pts.append((sx, -2.68, sz))
        p.box((0.2, 0.08, 0.6), (sx, -1.5, 0.015), STEEL)                                # Laufklammer
    for s in (-1, 1):                                                                    # Trommelmagazine
        p.cyl(0.36, 0.26, (s * 0.8, 0.25, 0.1), OLIVE, r=AX_X, sides=12, bevel=0.04, segs=1)
        p.cyl(0.14, 0.3, (s * 0.8, 0.25, 0.1), OLIVE_D, r=AX_X, sides=8)
    p.torus(0.22, 0.03, (0, -0.4, 0.8), GOLD, r=AX_Y, seg=10, tseg=4)                    # Ringvisier
    tube(p, (-0.22, -0.4, 0.8), (0.22, -0.4, 0.8), 0.015, GOLD, sides=4)
    tube(p, (0, -0.4, 0.58), (0, -0.4, 1.02), 0.015, GOLD, sides=4)
    p.box((0.06, 0.3, 0.2), (-0.655, -0.2, -0.1), "14161C")
    pitch = p.build("pitch", head, (0, -0.05, 1.05))
    pitch.rotation_euler = (math.radians(-28), 0, 0)
    muzzles(pitch, pts)
    hempty("fx_shell", pitch, (-0.8, -0.2, -0.1))
    t = HP()                                                                           # ab 4: Splitterschutz links/rechts
    for s in (-1, 1):
        m = T(s * 0.62, -0.95, 0.1) @ rot(0, 0, -s * 18)
        t.box((0.7, 0.09, 1.1), (0, 0, 0), G2, r=m, bevel=0.04, segs=1)
        for sz in (-0.4, 0.4):
            rivet(t, m @ T(s * 0.22, -0.05, sz), 0.07)
    t.build("lv4_shield", pitch)
    t = HP()
    t.box((1.34, 0.12, 1.0), (0, 0.66, 0), GOLD, bevel=0.03, segs=1)
    for sx in (-0.3, 0.3):
        for sz in (-0.17, 0.2):
            t.cyl(0.14, 0.1, (sx, -2.3, sz), GOLD, r=AX_Y, sides=6)
    t.build("lv7_trim", pitch)
    head_damage(pitch, [(T(-0.35, 0.6, 0.485) @ UP, 0.28, 0.22), (T(0.655, -0.2, 0.0) @ RIGHT, 0.26, 0.2)],
                [(T(0.3, -0.1, 0.485) @ UP, 0.34, 0.26), (T(-0.655, 0.5, 0.0) @ LEFT, 0.3, 0.24)])
    smoke(root, (0.2, 0.5, hz + 1.6))
    finish("t_aa", copies=("b_luftabwehr",))


# ------------------------------------------------------------------ Flammenturm
def t_flame():
    root, base, hz, rng = begin("t_flame", "flame", 1.1, 1.5)
    TANK = "F2A81E"
    hd = HP()
    hd.cyl(0.8, 0.3, (0, 0, 0.15), DARK, r2=0.68, sides=16, bevel=0.05, segs=1)
    hd.cyl(0.84, 0.08, (0, 0, 0.05), STEEL, sides=16)
    yoke(hd, 0.66, 0.92, depth=0.46, th=0.18, y=-0.2)
    for sx in (-0.36, 0.36):                                                             # zwei Brennstofftanks
        hd.cyl(0.33, 1.3, (sx, 0.62, 0.9), TANK, sides=12, bevel=0.14, segs=2)
        hd.cyl(0.345, 0.14, (sx, 0.62, 0.95), RED, sides=12)
        hd.cyl(0.11, 0.12, (sx, 0.62, 1.6), DARK, sides=8)
        hd.box((0.22, 0.03, 0.22), (sx, 0.285, 1.25), HAZ_K, r=rot(0, 45, 0))            # Warnzeichen
        hd.box((0.15, 0.035, 0.15), (sx, 0.283, 1.25), HAZ_Y, r=rot(0, 45, 0))
    hd.box((1.1, 0.5, 0.16), (0, 0.62, 0.3), STEEL, bevel=0.04, segs=1)                  # Tankträger
    tube(hd, (-0.36, 0.62, 1.66), (0.36, 0.62, 1.66), 0.05, STEEL, sides=6)              # Verbindungsrohr
    hd.torus(0.13, 0.03, (0, 0.62, 1.74), RED, seg=8, tseg=4)                            # Ventilrad
    hd.cyl(0.025, 0.1, (0, 0.62, 1.7), DARK, sides=4)
    tube(hd, (0.36, 0.5, 1.62), (0.5, 0.0, 1.3), 0.055, DARK, sides=6)                   # Schlauch
    tube(hd, (0.5, 0.0, 1.3), (0.42, -0.2, 1.05), 0.055, DARK, sides=6)
    head = hd.build("head", root, (0, 0, hz))
    g = HP(); g.cyl(0.1, 0.04, (0, 0.27, 0.62), GREEN, r=AX_Y, sides=8); g.build("gauge_glow", head)
    p = HP()
    p.box((0.96, 1.1, 0.74), (0, 0.0, 0), RED, bevel=0.22, segs=3)
    p.cyl(0.12, 1.4, (0, 0, 0), STEEL, r=AX_X, sides=8)
    star(p, (0, 0.05, 0.375), 0.26, "white", 0.04)
    p.cyl(0.17, 0.9, (0, -0.95, 0), DARK, r=AX_Y, sides=10)                              # Rohr
    p.cyl(0.21, 0.12, (0, -0.66, 0), GOLD_D, r=AX_Y, sides=10)
    p.cyl(0.24, 0.5, (0, -1.1, 0), "6A7288", r=AX_Y, sides=8)                            # Hitzeschild
    for y in (-0.95, -1.1, -1.25):
        p.cyl(0.255, 0.05, (0, y, 0), DARK, r=AX_Y, sides=8)
    p.cyl(0.19, 0.4, (0, -1.6, 0), STEEL, r=AX_Y, r2=0.36, sides=12)                     # Trichter
    p.torus(0.36, 0.045, (0, -1.8, 0), DARK, r=AX_Y, seg=12, tseg=4)
    p.cyl(0.3, 0.02, (0, -1.79, 0), "14161C", r=AX_Y, sides=10)
    tube(p, (0, -0.5, 0.3), (0, -1.62, 0.34), 0.04, "4A5263", sides=5)                   # Zündleitung
    pitch = p.build("pitch", head, (0, -0.2, 0.92))
    g = HP()
    g.ball(0.1, (0, 0, 0), "FFB03A", scale=(1, 1.6, 1), subdiv=2)
    g.build("pilot_glow", pitch, (0, -1.72, 0.34))
    muzzles(pitch, [(0, -1.84, 0)])
    hempty("fx_shell", pitch, (0.3, -0.6, -0.3))
    t = HP()                                                                           # ab 4: Hitzeblech um die Düse
    t.cyl(0.5, 0.1, (0, -1.4, 0), RED_D, r=AX_Y, sides=8)
    t.cyl(0.52, 0.04, (0, -1.46, 0), STEEL, r=AX_Y, sides=8)
    t.box((1.0, 0.5, 0.08), (0, 0.1, 0.42), RED_D, bevel=0.03, segs=1)
    t.build("lv4_shield", pitch)
    t = HP()
    t.box((1.0, 0.12, 0.78), (0, 0.38, 0), GOLD, bevel=0.03, segs=1)
    t.torus(0.37, 0.06, (0, -1.8, 0), GOLD, r=AX_Y, seg=12, tseg=4)
    for sx in (-0.36, 0.36):
        t.torus(0.34, 0.04, (sx, 0.82, 0.38), GOLD, seg=12, tseg=4)
    t.build("lv7_trim", pitch)
    head_damage(pitch, [(T(0.2, -0.2, 0.375) @ UP, 0.26, 0.2), (T(-0.485, 0.1, 0.0) @ LEFT, 0.26, 0.2)],
                [(T(-0.2, 0.3, 0.375) @ UP, 0.3, 0.22), (T(0.485, -0.2, 0.05) @ RIGHT, 0.28, 0.22), (T(0, -1.1, 0.26) @ UP, 0.2, 0.26)])
    smoke(root, (-0.3, 0.6, hz + 1.9))
    finish("t_flame", copies=("b_flammenturm",))


# ------------------------------------------------------------------ Tesla / Mini
def coil_head(hd, th, k, rings):
    """Spulenmast: Isolatoren, blauer Kegel, goldene Spulenringe, Halteklauen. Rückgabe: Höhe der Kugel."""
    hd.cyl(0.78 * k, 0.3 * k, (0, 0, 0.15 * k), DARK, r2=0.64 * k, sides=14, bevel=0.05 * k, segs=1)
    for i in range(3):                                                                   # Porzellan-Isolatoren
        hd.cyl((0.56 - i * 0.05) * k, 0.1 * k, (0, 0, (0.36 + i * 0.13) * k), "F4F6FA", sides=12, bevel=0.03 * k, segs=1)
    hd.cyl(0.42 * k, th, (0, 0, th * 0.5), BLUE, r2=0.2 * k, sides=10)
    for i in range(rings):
        rr = (0.78 - i * 0.105) * k
        hd.torus(rr, 0.1 * k, (0, 0, 0.8 * k + i * (th - 1.0 * k) / max(rings - 1, 1)), GOLD, seg=12, tseg=4)
    hd.cyl(0.28 * k, 0.16 * k, (0, 0, th), DARK, sides=10, bevel=0.03 * k, segs=1)
    for i in range(3):
        m = rot(0, 0, i * 120 + 60)
        hd.box((0.1 * k, 0.1 * k, 0.6 * k), (0, 0, 0), STEEL, r=m @ T(0, -0.5 * k, th + 0.3 * k) @ rot(-18, 0, 0))
        hd.ball(0.09 * k, (0, 0, 0), GOLD, r=m @ T(0, -0.58 * k, th + 0.62 * k), subdiv=1)
    return th + 0.42 * k


def t_tesla():
    root, base, hz, rng = begin("t_tesla", "tesla", 1.1, 0.9)
    hd = HP()
    oz = coil_head(hd, 3.0, 1.0, 5)
    for s in (-1, 1):                                                                    # Kondensatoren mit Kabeln
        hd.cyl(0.2, 0.7, (s * 0.72, 0.42, 0.62), "566078", sides=8, bevel=0.05, segs=1)
        hd.cyl(0.21, 0.08, (s * 0.72, 0.42, 0.8), HAZ_Y, sides=8)
        hd.cyl(0.07, 0.14, (s * 0.72, 0.42, 1.03), "F4F6FA", sides=6)
        tube(hd, (s * 0.72, 0.42, 1.08), (s * 0.3, 0.2, 1.5), 0.035, DARK, sides=5)
    hd.box((0.5, 0.2, 0.46), (0, -0.7, 0.52), "566078", bevel=0.05, segs=1)              # Schaltkasten
    head = hd.build("head", root, (0, 0, hz))
    g = HP()
    for i, c in enumerate((GREEN, GLOW, HOT)):
        g.box((0.09, 0.04, 0.09), (-0.14 + i * 0.14, -0.81, 0.6), c)
    g.build("panel_glow", head)
    o = HP()
    o.ball(0.5, (0, 0, 0), "2FB4FF", subdiv=3)
    o.build("pulse_orb_glow", head, (0, 0, oz))
    pitch = empty("pitch", head, (0, 0, oz))
    muzzles(pitch, [(0, 0, 0)])
    t = HP()                                                                           # ab 4: zwei Nebenspulen
    for s in (-1, 1):
        t.cyl(0.12, 1.2, (s * 0.72, -0.35, 0.9), BLUE, r2=0.07, sides=6)
        for i in range(3):
            t.torus(0.2 - i * 0.03, 0.04, (s * 0.72, -0.35, 0.75 + i * 0.25), GOLD, seg=8, tseg=4)
    t.build("lv4_coils", head)
    g = HP()
    for s in (-1, 1):
        g.ball(0.13, (s * 0.72, -0.35, 1.6), "8FE0FF", subdiv=1)
    g.build("lv4_orbs_glow", head)
    t = HP()                                                                           # ab 7: großer Goldreif, Krone
    t.torus(0.92, 0.07, (0, 0, 0.5), GOLD, seg=18, tseg=4)
    for i in range(6):
        m = rot(0, 0, i * 60)
        t.cyl(0.07, 0.3, (0, 0, 0), GOLD, r=m @ T(0, -0.92, 0.66), r2=0.01, sides=5)
    t.torus(0.36, 0.05, (0, 0, 3.08), GOLD, seg=12, tseg=4)
    t.build("lv7_trim", head)
    head_damage(head, [(T(0, -0.81, 0.4) @ rot(0, 0, 0), 0.22, 0.12), (T(0.25, -0.25, 1.6) @ rot(0, 0, 35), 0.18, 0.3)],
                [(T(-0.3, -0.12, 1.2) @ rot(0, 0, -50), 0.2, 0.34), (T(0.72, 0.21, 0.6) @ rot(0, 0, 0), 0.16, 0.2)])
    smoke(root, (0.3, 0.3, hz + 2.2))
    finish("t_tesla", copies=("b_tesla",))


def t_mini():
    """Kleiner Tesla-Turm, den eine Fähigkeit aufstellt: Dreibein, Batterie, kurze Spule."""
    global K
    K = 1.0
    reset(); root = empty("t_mini")
    b = HP()
    b.cyl(0.56, 0.12, (0, 0, 0.06), ST_D, sides=12, bevel=0.04, segs=1)
    b.cyl(0.4, 0.38, (0, 0, 0.3), "566078", r2=0.34, sides=10)
    b.cyl(0.42, 0.06, (0, 0, 0.3), HAZ_Y, sides=10)
    for i in range(3):
        x, y = ring_xy(0.62, i * 120 + 60)
        beam(b, (x, y, 0.03), (x * 0.4, y * 0.4, 0.46), 0.08, STEEL)
        b.cyl(0.1, 0.05, (x, y, 0.025), DARK, sides=6)
    b.box((0.3, 0.2, 0.26), (0, -0.44, 0.2), BLUE, bevel=0.04, segs=1)                   # Batterie
    star(b, (0, -0.545, 0.2), 0.09, "white", 0.02, r=STAR_FRONT)
    b.cyl(0.36, 0.2, (0, 0, 0.6), BLUE, sides=10, bevel=0.04, segs=1)
    b.build("base", root)
    hd = HP()
    oz = coil_head(hd, 1.4, 0.5, 3)
    head = hd.build("head", root, (0, 0, 0.72))
    o = HP()
    o.ball(0.28, (0, 0, 0), "2FB4FF", subdiv=2)
    o.build("pulse_orb_glow", head, (0, 0, oz + 0.1))
    pitch = empty("pitch", head, (0, 0, oz + 0.1))
    muzzles(pitch, [(0, 0, 0)])
    finish("t_mini", limit=2500)


# ------------------------------------------------------------------ Wachturm
def soldier(p, m, k=1.3):
    """Schütze im Voxel-Stil (kantige Quader): Stiefel, Tarnanzug, großer Kopf mit blauem Helm und Brille. Schaut nach -Y."""
    def bx(size, loc, c, r=None):
        mm = m @ S(k) @ T(*loc)
        p.box(size, (0, 0, 0), c, r=mm if r is None else mm @ r)
    for s in (-1, 1):
        bx((0.2, 0.24, 0.5), (s * 0.13, 0, 0.25), "6A6A3A")
        bx((0.22, 0.3, 0.14), (s * 0.13, -0.02, 0.07), "4A3A2A")
    bx((0.5, 0.3, 0.44), (0, 0, 0.72), "9C9A4A")
    bx((0.52, 0.32, 0.08), (0, 0, 0.52), "2E3340")
    bx((0.3, 0.06, 0.2), (0, -0.17, 0.76), "6A6A3A")
    bx((0.6, 0.54, 0.52), (0, -0.02, 1.22), "F2C29B")                                    # Kopf
    bx((0.66, 0.6, 0.24), (0, -0.01, 1.42), "0469CC")                                    # Helm
    bx((0.7, 0.64, 0.06), (0, -0.01, 1.31), "0A5CB4")
    bx((0.44, 0.05, 0.13), (0, -0.31, 1.27), "7FE3FF")                                   # Brille
    bx((0.6, 0.04, 0.05), (0, -0.3, 1.27), "2E3340")
    for s, a in ((-1, -62), (1, -78)):                                                   # Arme nach vorn am Gewehr
        bx((0.16, 0.16, 0.42), (s * 0.33, -0.14, 0.82), "9C9A4A", r=rot(a, 0, s * 14))
        bx((0.18, 0.18, 0.16), (s * 0.27, -0.36, 0.86 if s > 0 else 0.92), "2E3340")


def t_watch():
    global K
    K = 1.0
    reset(); root = empty("t_watch")
    rng = rng_for("t_watch")
    PZ = 3.3                                                                             # Oberkante der Plattform
    b = HP()
    b.box((3.4, 3.4, 0.2), (0, 0, 0.1), ST_D, bevel=0.06, segs=1)                        # Fundament mit Fugen
    for i in range(4):
        for j in range(4):
            b.box((0.78, 0.78, 0.07), (-1.215 + i * 0.81, -1.215 + j * 0.81, 0.235), jit((ST, ST_L)[(i + j) % 2], rng))
    for sx in (-1, 1):                                                                   # vier Eckstämme, leicht nach innen geneigt
        for sy in (-1, 1):
            beam(b, (sx * 1.3, sy * 1.3, 0.2), (sx * 1.12, sy * 1.12, PZ - 0.2), 0.3, jit(WOOD, rng), bevel=0.05)
            b.box((0.46, 0.46, 0.22), (sx * 1.3, sy * 1.3, 0.36), ST, bevel=0.05, segs=1)
    for i in range(4):
        m = rot(0, 0, i * 90)
        b.box((2.5, 0.14, 0.2), (0, 0, 0), jit(WOOD_D, rng), r=m @ T(0, -1.2, 1.7))        # Querriegel
    b.box((3.1, 3.1, 0.14), (0, 0, PZ - 0.21), WOOD_D)                                   # Plattform: Träger + Bohlen
    for i in range(8):
        b.box((0.37, 3.16, 0.14), (-1.365 + i * 0.39, 0, PZ - 0.07), jit(WOOD_L, rng, 0.09))
    for i in range(4):                                                                   # Brüstung aus Brettern
        m = rot(0, 0, i * 90)
        for j in range(6):
            if i == 2 and j in (2, 3):
                continue                                                                 # Einstieg hinten (Leiter)
            b.box((0.44, 0.08, 0.86 + rng.uniform(-0.05, 0.05)), (0, 0, 0), jit(WOOD, rng, 0.09), r=m @ T(-1.2 + j * 0.48, -1.5, PZ + 0.43))
        if i != 2:
            b.box((3.1, 0.14, 0.1), (0, 0, 0), WOOD_D, r=m @ T(0, -1.5, PZ + 0.9))
    for sx in (-1, 1):
        for sy in (-1, 1):
            b.box((0.2, 0.2, 2.9), (sx * 1.46, sy * 1.46, PZ + 1.45), jit(WOOD_D, rng), bevel=0.04, segs=1)   # Dachpfosten
    sandbag_row(b, (-0.9, -1.3, PZ), (0.9, -1.3, PZ), 1, rng)                            # Sandsäcke auf der Brüstungsseite
    sandbag_row(b, (-1.6, -1.72, 0.27), (0.3, -1.72, 0.27), 2, rng)                      # ... und am Fuß
    n, shell, tip, cc = AMMO["watch"]
    ammo_crate(b, T(1.15, -1.45, 0.27) @ rot(0, 0, 12), color=OLIVE)
    ammo_open(b, T(0.95, -0.95, PZ) @ rot(0, 0, 90), size=(0.6, 0.4, 0.3), color=OLIVE, n=5)
    b.box((0.5, 0.36, 0.5), (-1.1, 1.05, PZ + 0.25), WOOD, bevel=0.04, segs=1)           # Hocker / Kiste oben
    b.cyl(0.05, 0.5, (1.46, -1.46, PZ + 2.4), DARK, r=rot(0, 90, 45), sides=5)            # Lampenarm
    flag(root, b, (-1.46, 1.46, PZ + 2.6), h=2.5, size=(0.95, 0.62))
    base = b.build("base", root)
    g = HP(); g.box((0.22, 0.22, 0.26), (1.22, -1.22, PZ + 2.26), GLOW, bevel=0.05, segs=1); g.build("lamp_glow", base)
    empty("work_1", root, (1.9, -1.9, 0.0))
    # Leiter hinten
    for nm, c in (("lvmax6_ladder", WOOD_D), ("lv7_ladder", STEEL)):
        t = HP(); ladder(t, (0, 1.95, 0.2), (0, 1.56, PZ + 0.5), 0.6, c, step=0.4); t.build(nm, base)
    # Stufe 1–3: Kreuzstreben aus Holz, Seilbindungen, Holzschild
    t = HP()
    for i in range(4):
        m = rot(0, 0, i * 90)
        for s in (-1, 1):
            if i == 2:
                continue
            a = m @ Vector((-1.2 * s, -1.26, 0.45)); c2 = m @ Vector((1.12 * s, -1.2, 1.62))
            beam(t, a, c2, 0.12, jit(WOOD, rng))
            a = m @ Vector((-1.14 * s, -1.2, 1.8)); c2 = m @ Vector((1.1 * s, -1.14, PZ - 0.3))
            beam(t, a, c2, 0.12, jit(WOOD, rng))
    for sx in (-1, 1):
        for sy in (-1, 1):
            t.cyl(0.2, 0.12, (sx * 1.21, sy * 1.21, 1.7), ROPE, sides=6)
    t.box((0.8, 0.07, 0.6), (0, -1.56, PZ + 0.4), WOOD_L)
    star(t, (0, -1.6, PZ + 0.4), 0.22, "white", 0.03, r=STAR_FRONT)
    t.build("lvmax3_wood", base)
    # ab 4: gemauerter Fuß, Eisenwinkel, blaues Schild
    t = HP()
    for i in range(4):
        m = rot(0, 0, i * 90)
        for j in range(4):
            t.box((0.6, 0.3, 0.42), (0, 0, 0), jit((ST, ST_L)[j % 2], rng), r=m @ T(-0.98 + j * 0.65, -1.36, 0.5), bevel=0.06, segs=1)
        for j in range(3):
            t.box((0.6, 0.26, 0.4), (0, 0, 0), jit((ST_L, ST)[j % 2], rng), r=m @ T(-0.65 + j * 0.65, -1.34, 0.92), bevel=0.06, segs=1)
        for s in (-1, 1):
            if i != 2:
                a = m @ Vector((-1.16 * s, -1.24, 1.8)); c2 = m @ Vector((1.1 * s, -1.14, PZ - 0.3))
                beam(t, a, c2, 0.1, STEEL, d=0.06)
    t.box((0.86, 0.1, 0.66), (0, -1.58, PZ + 0.4), BLUE, bevel=0.05, segs=1)
    star(t, (0, -1.64, PZ + 0.4), 0.24, "white", 0.03, r=STAR_FRONT)
    t.build("lv4_stone", base)
    # Dach: bis 6 rote Schindeln, ab 7 blaues Blech mit Gold
    for nm, c1, c2 in (("lvmax6_roof", RED, RED_D), ("lv7_roof", BLUE, BLUE_D)):
        t = HP()
        t.cyl(2.5, 0.14, (0, 0, PZ + 2.94), c2, r=rot(0, 0, 45), sides=4)
        for i in range(3):                                                               # Schindelreihen
            t.cyl(2.42 - i * 0.74, 0.44, (0, 0, PZ + 3.2 + i * 0.36), c1 if i % 2 == 0 else shade(c1, 0.9), r=rot(0, 0, 45), r2=1.72 - i * 0.74, sides=4)
        t.cyl(0.14, 0.3, (0, 0, PZ + 4.25), GOLD if nm.startswith("lv7") else WOOD_D, sides=6)
        t.ball(0.16, (0, 0, PZ + 4.45), GOLD, subdiv=1)
        if nm.startswith("lv7"):
            for i in range(4):
                beam(t, rot(0, 0, i * 90) @ Vector((1.72, 1.72, PZ + 3.0)), rot(0, 0, i * 90) @ Vector((0.2, 0.2, PZ + 4.1)), 0.1, GOLD)
        else:
            t.box((0.7, 0.5, 0.06), (0.5, -1.2, PZ + 3.34), WOOD_L, r=rot(27, 0, 0))    # Flicken auf dem Dach
        t.build(nm, base)
    t = HP()                                                                           # ab 7: Panzerblech an der Brüstung, Goldkante
    for i in (0, 1, 3):
        m = rot(0, 0, i * 90)
        t.box((2.7, 0.08, 0.7), (0, 0, 0), "5E79B8", r=m @ T(0, -1.57, PZ + 0.42), bevel=0.03, segs=1)
        t.box((2.9, 0.1, 0.08), (0, 0, 0), GOLD, r=m @ T(0, -1.58, PZ + 0.84))
        for j in range(4):
            rivet(t, m @ T(-1.1 + j * 0.73, -1.62, PZ + 0.2), 0.08, GOLD)
    star(t, (0, -1.66, PZ + 0.46), 0.26, "white", 0.03, r=STAR_FRONT)
    t.build("lv7_armor", base)
    # Schaden
    t = HP()
    soot_flat(t, (1.0, 0.9, 0.275), 0.4, 0.3, yaw=30)
    soot(t, T(-0.5, -1.545, PZ + 0.5), 0.3, 0.22)
    soot(t, T(1.545, 0.3, PZ + 0.4) @ RIGHT, 0.28, 0.24)
    debris(t, [(1.4, 0.6, 0.25), (-1.5, -0.4, 0.25)], rng, cols=(WOOD, WOOD_D))
    t.build("dmg1_base", base)
    t = HP()
    soot_flat(t, (-0.9, 1.0, 0.275), 0.5, 0.36)
    soot(t, T(0.7, -1.545, PZ + 0.3), 0.34, 0.26)
    soot(t, T(-1.545, -0.5, PZ + 0.5) @ LEFT, 0.3, 0.3)
    beam(t, (-1.3, 0.3, 1.9), (-1.75, 0.9, 0.3), 0.12, WOOD)                             # abgebrochene Strebe
    debris(t, [(-1.6, 1.1, 0.25), (1.2, 1.5, 0.25), (0.2, -1.9, 0.25)], rng, cols=(WOOD, WOOD_D, WOOD_L), s=0.28)
    t.build("dmg2_base", base)
    smoke(root, (-0.6, 0.6, PZ + 1.2))
    # Kopf: Schütze auf Drehschemel, Gewehr auf Lafette
    hd = HP()
    hd.cyl(0.5, 0.08, (0, 0, 0.04), DARK, sides=10)
    soldier(hd, T(0, 0.3, 0.06))
    hd.cyl(0.06, 1.0, (0, -0.42, 0.5), DARK, sides=6)                                    # Lafette
    hd.cyl(0.12, 0.1, (0, -0.42, 1.02), STEEL, sides=6)
    head = hd.build("head", root, (0, 0, PZ))
    empty("gunner", head, (0, 0.3, 0.06))
    p = HP()
    p.box((0.2, 0.9, 0.22), (0, 0.1, 0.02), DARK, bevel=0.05, segs=1)
    p.box((0.16, 0.4, 0.2), (0, 0.66, -0.05), WOOD_D, bevel=0.04, segs=1)                # Schulterstütze
    barrel(p, 0, 0.03, -0.3, -1.5, 0.06, "3A4152", STEEL, tip_r=0.095, tip_len=0.24, sides=6)
    p.cyl(0.06, 0.5, (0, 0.0, 0.22), STEEL, r=AX_Y, sides=6)                             # Zielfernrohr
    p.cyl(0.075, 0.06, (0, -0.26, 0.22), "8FD3F5", r=AX_Y, sides=6)
    p.box((0.1, 0.24, 0.26), (0, -0.05, -0.2), "4A5263")                                 # Magazin
    for s in (-1, 1):
        tube(p, (0, -1.0, 0.0), (s * 0.2, -1.1, -0.42), 0.022, DARK, sides=4)            # Zweibein
    pitch = p.build("pitch", head, (0, -0.42, 1.14))
    muzzles(pitch, [(0, -1.66, 0.03)])
    hempty("fx_shell", pitch, (0.14, 0.0, 0.05))
    finish("t_watch", copies=("b_wachturm",))


# ------------------------------------------------------------------ Kanone
def dome_pt(c, r, sz, d):
    """Punkt und Normale auf einer abgeflachten Kuppel (Mitte c, Radius r, Z-Faktor sz) in Richtung d."""
    d = Vector(d).normalized()
    t = 1.0 / math.sqrt((d.x * d.x + d.y * d.y) / (r * r) + d.z * d.z / (sz * r * sz * r))
    p = d * t
    n = Vector((p.x / (r * r), p.y / (r * r), p.z / (sz * r * sz * r))).normalized()
    return Vector(c) + p, n


def t_cannon():
    root, base, hz, rng = begin("t_cannon", "cannon", 1.9, 1.15, bags="split", k=1.2)
    hd = HP()
    hd.cyl(1.56, 0.34, (0, 0, 0.17), DARK, r2=1.4, sides=20, bevel=0.06, segs=1)
    hd.cyl(1.6, 0.08, (0, 0, 0.05), STEEL, sides=20)
    C0, R0, SZ = (0, 0.1, 0.34), 1.36, 0.86
    hd.ball(R0, C0, BLUE, scale=(1, 1.06, SZ), subdiv=3)                                  # Panzerkuppel
    hd.cyl(1.4, 0.2, (0, 0.1, 0.42), BLUE_D, sides=20)
    for i in range(6):
        rivet(hd, T(0, 0.1, 0) @ ring_m(1.41, i * 60 + 30, 0.42), 0.09, STEEL_L)
    hd.cyl(0.4, 0.14, (0.2, 0.5, 0.34 + R0 * SZ - 0.1), BLUE_D, sides=10)   # Luke
    hd.torus(0.12, 0.03, (0.2, 0.5, 0.34 + R0 * SZ + 0.0), STEEL_L, seg=8, tseg=4)
    for s in (-1, 1):                                                                    # Sterne auf den Flanken
        q, n = dome_pt(C0, R0 * 1.0, SZ, (s * 0.8, -0.25, 0.62))
        star(hd, tuple(q + n * 0.02), 0.34, "white", 0.04, r=face_to(n) @ rot(0, 0, 180 if s < 0 else 0))
    hd.box((1.2, 0.5, 0.9), (0, -1.0, 0.72), BLUE_D, bevel=0.14, segs=1)                 # Rohrwiegen-Kasten
    for s in (-1, 1):
        hd.box((0.2, 0.6, 0.5), (s * 0.7, -0.95, 0.75), STEEL, bevel=0.05, segs=1)
    hd.cyl(0.05, 0.9, (-0.6, 0.9, 1.5), DARK, sides=5)                                   # Antenne
    hd.ball(0.07, (-0.6, 0.9, 1.97), RED, subdiv=1)
    head = hd.build("head", root, (0, 0, hz))
    p = HP()
    p.cyl(0.6, 0.5, (0, -0.3, 0), BLUE, r=AX_Y, sides=14, bevel=0.1, segs=1)             # Blende
    p.cyl(0.36, 1.5, (0, -1.25, 0), DARK, r=AX_Y, r2=0.3, sides=12)
    p.cyl(0.42, 0.5, (0, -0.85, 0), "4A5263", r=AX_Y, sides=12, bevel=0.03, segs=1)      # Rücklaufzylinder
    for y in (-0.7, -1.0):
        p.cyl(0.44, 0.06, (0, y, 0), STEEL, r=AX_Y, sides=12)
    p.cyl(0.42, 0.42, (0, -2.15, 0), STEEL, r=AX_Y, sides=12)        # Mündungsbremse
    for s in (-1, 1):
        p.box((0.1, 0.2, 0.3), (s * 0.4, -2.15, 0), "14161C")
    p.cyl(0.25, 0.02, (0, -2.37, 0), "14161C", r=AX_Y, sides=12)
    pitch = p.build("pitch", head, (0, -1.0, 0.75))
    muzzles(pitch, [(0, -2.42, 0)])
    hempty("fx_shell", pitch, (0.75, 0.3, -0.1))
    t = HP()                                                                           # ab 4: Zusatzpanzer vorn, Suchscheinwerfer-Halter
    for s in (-1, 1):
        m = T(s * 0.95, -0.75, 0.75) @ rot(0, 0, -s * 30)
        t.box((0.8, 0.12, 0.8), (0, 0, 0), BLUE_D, r=m, bevel=0.05, segs=1)
        for sz in (-0.28, 0.28):
            rivet(t, m @ T(s * 0.26, -0.07, sz), 0.08)
    t.box((0.3, 0.3, 0.3), (0.75, 0.2, 1.52), DARK, bevel=0.06, segs=1)
    t.build("lv4_shield", head)
    g = HP(); g.cyl(0.12, 0.04, (0.75, 0.04, 1.52), "FFF2B8", r=AX_Y, sides=8); g.build("lv4_spot_glow", head)
    t = HP()
    t.torus(1.4, 0.07, (0, 0.1, 0.56), GOLD, seg=20, tseg=4)
    t.torus(0.41, 0.06, (0.2, 0.5, 0.34 + R0 * SZ - 0.05), GOLD, seg=10, tseg=4)
    t.build("lv7_trim", head)
    t = HP()
    t.cyl(0.45, 0.12, (0, -2.0, 0), GOLD, r=AX_Y, sides=12)
    t.build("lv7_gun", pitch)
    s1, s2 = [], []
    for d, lst, rx in (((0.5, 0.6, 0.6), s1, 0.34), ((-0.7, 0.3, 0.5), s1, 0.28), ((-0.2, -0.3, 0.9), s2, 0.4), ((0.8, -0.2, 0.4), s2, 0.3), ((-0.4, 0.8, 0.5), s2, 0.32)):
        q, n = dome_pt(C0, R0, SZ, d)
        lst.append((T(*(q + n * 0.015)) @ face_to(n) @ rot(90, 0, 0), rx, rx * 0.8))
    head_damage(head, s1, s2)
    smoke(root, (0.3, 0.6, hz + 1.5))
    finish("t_cannon", copies=("b_kanone",))


# ------------------------------------------------------------------ Mörser
def bomb(p, m, r=0.17, body="4B5670", tip=RED):
    """Mörsergranate, steht auf den Flossen."""
    p.cyl(r * 0.5, r * 1.2, (0, 0, 0), DARK, r=m @ T(0, 0, r * 0.6), sides=6)
    for a in (0, 90):
        p.box((r * 1.9, 0.03, r * 1.0), (0, 0, 0), STEEL, r=m @ T(0, 0, r * 0.5) @ rot(0, 0, a))
    p.cyl(r, r * 1.7, (0, 0, 0), body, r=m @ T(0, 0, r * 2.0), sides=8, bevel=r * 0.3, segs=1)
    p.cyl(r * 0.92, r * 1.1, (0, 0, 0), tip, r=m @ T(0, 0, r * 3.35), r2=r * 0.2, sides=8)
    p.cyl(r * 1.03, r * 0.24, (0, 0, 0), GOLD, r=m @ T(0, 0, r * 2.2), sides=8)


def t_mortar():
    root, base, hz, rng = begin("t_mortar", "mortar", 1.9, 1.15, bags="split", k=1.22)
    M1, M2 = "6F8A4A", "4E6634"
    hd = HP()
    hd.cyl(1.6, 0.3, (0, 0, 0.15), DARK, r2=1.5, sides=20, bevel=0.06, segs=1)
    hd.cyl(1.64, 0.08, (0, 0, 0.05), STEEL, sides=20)
    hd.cyl(0.9, 0.16, (0, 0.2, 0.38), STEEL, sides=14)               # Bodenplatte
    yoke(hd, 0.92, 0.75, depth=0.7, th=0.22, y=0.1)
    for s in (-1, 1):                                                                    # Zweibein nach vorn
        tube(hd, (s * 0.3, -0.5, 1.5), (s * 1.0, -1.15, 0.3), 0.06, STEEL, sides=6)
        hd.cyl(0.14, 0.06, (s * 1.0, -1.15, 0.33), DARK, sides=6)
    tube(hd, (-0.62, -0.8, 0.95), (0.62, -0.8, 0.95), 0.035, DARK, sides=5)              # Kette
    hd.box((0.56, 1.5, 0.1), (1.22, 0.1, 0.35), WOOD, bevel=0.03, segs=1)                # Granatenbrett
    for i in range(3):
        bomb(hd, T(1.22, 0.6 - i * 0.5, 0.4))
    hd.box((0.5, 0.5, 0.44), (-1.15, 0.5, 0.52), OLIVE, bevel=0.05, segs=1)              # Zünderkiste
    hd.box((0.52, 0.52, 0.08), (-1.15, 0.5, 0.66), OLIVE_D)
    head = hd.build("head", root, (0, 0, hz))
    p = HP()
    p.cyl(0.6, 0.5, (0, 0.5, 0), M2, r=AX_Y, sides=14, bevel=0.2, segs=1)                # Bodenstück
    p.ball(0.3, (0, 0.82, 0), STEEL, subdiv=1)
    p.cyl(0.54, 1.9, (0, -0.5, 0), M1, r=AX_Y, r2=0.5, sides=14)
    for y in (-0.1, -0.75):
        p.cyl(0.58, 0.16, (0, y, 0), M2, r=AX_Y, sides=14)
    p.cyl(0.6, 0.3, (0, -1.45, 0), STEEL, r=AX_Y, sides=14)
    p.cyl(0.43, 0.02, (0, -1.605, 0), "14161C", r=AX_Y, sides=12)
    p.cyl(0.15, 1.7, (0, 0.1, 0), STEEL, r=AX_X, sides=8)
    star(p, (0, -0.42, 0.0), 0.28, "white", 0.04, r=T(0, 0, 0.54))
    p.box((0.12, 0.3, 0.3), (0.6, -0.3, 0.2), DARK, bevel=0.03, segs=1)                  # Richtaufsatz
    p.cyl(0.05, 0.2, (0.6, -0.5, 0.26), "8FD3F5", r=AX_Y, sides=6)
    pitch = p.build("pitch", head, (0, 0.1, 0.75))
    pitch.rotation_euler = (math.radians(-55), 0, 0)
    muzzles(pitch, [(0, -1.75, 0)])
    hempty("fx_shell", pitch, (0, -1.6, 0.4))
    t = HP()                                                                           # ab 4: Splitterschutz-Wand hinten, vierte Granate
    for i in range(5):
        m = ring_m(1.5, 130 + i * 25, 0.72)
        t.box((0.62, 0.1, 0.9), (0, 0, 0), jit(M2, rng), r=m)
        rivet(t, m @ T(0, -0.06, 0.3), 0.07)
    bomb(t, T(1.22, -0.9, 0.4))
    t.build("lv4_shield", head)
    t = HP()
    t.torus(0.6, 0.06, (0, -1.4, 0), GOLD, r=AX_Y, seg=14, tseg=4)
    t.torus(0.59, 0.05, (0, 0.3, 0), GOLD, r=AX_Y, seg=14, tseg=4)
    t.build("lv7_trim", pitch)
    head_damage(pitch, [(T(0.2, -0.9, 0.52) @ UP, 0.24, 0.3), (T(-0.555, -0.4, 0.0) @ LEFT, 0.3, 0.24)],
                [(T(-0.25, -0.3, 0.55) @ UP, 0.28, 0.36), (T(0.555, 0.1, -0.1) @ RIGHT, 0.3, 0.26)])
    smoke(root, (-0.4, 0.5, hz + 1.2))
    finish("t_mortar", copies=("b_moerser",))


# ------------------------------------------------------------------ Raketenwerfer
def t_rocket():
    root, base, hz, rng = begin("t_rocket", "rocket", 1.9, 1.15, bags="split", k=1.2)
    hd = HP()
    hd.cyl(1.3, 0.3, (0, 0, 0.15), DARK, r2=1.16, sides=18, bevel=0.06, segs=1)
    hd.cyl(1.34, 0.08, (0, 0, 0.05), STEEL, sides=18)
    hd.cyl(0.66, 0.9, (0, 0, 0.7), "4A5263", r2=0.5, sides=12, bevel=0.05, segs=1)
    yoke(hd, 1.42, 1.5, depth=0.64, th=0.22)
    hd.box((3.0, 0.5, 0.2), (0, 0, 0.42), STEEL, bevel=0.06, segs=1)
    hd.box((0.5, 0.4, 0.5), (-1.0, 0.75, 0.55), "566078", bevel=0.06, segs=1)            # Zielrechner
    hd.cyl(0.03, 0.8, (-1.15, 0.85, 1.2), DARK, sides=4)
    head = hd.build("head", root, (0, 0, hz))
    g = HP(); g.box((0.3, 0.04, 0.2), (-1.0, 0.54, 0.6), GREEN); g.build("screen_glow", head)
    p = HP()
    p.box((2.5, 2.1, 1.4), (0, 0, 0), RED, bevel=0.16, segs=2)                            # Werferkasten
    p.box((2.56, 0.26, 1.46), (0, 0.5, 0), RED_D, bevel=0.06, segs=1)
    p.box((2.56, 0.2, 1.46), (0, -0.7, 0), RED_D, bevel=0.06, segs=1)
    p.cyl(0.17, 2.9, (0, 0, 0), STEEL, r=AX_X, sides=8)
    star(p, (0, -0.1, 0.705), 0.42, "white", 0.04)
    for gx in (-0.78, 0.0, 0.78):
        for gz in (-0.33, 0.33):
            p.cyl(0.3, 0.12, (gx, -1.04, gz), DARK, r=AX_Y, sides=10)
            p.cyl(0.2, 0.2, (gx, -1.1, gz), "F4F6FA", r=AX_Y, sides=8)
            p.cyl(0.2, 0.34, (gx, -1.37, gz), RED_D if gz < 0 else "F4F6FA", r=AX_Y, r2=0.02, sides=8)
            p.cyl(0.22, 0.06, (gx, 1.06, gz), "14161C", r=AX_Y, sides=8)                 # Abgasöffnungen hinten
    for s in (-1, 1):
        hazard(p, (s * 1.26, -0.5, -0.5), (s * 1.26, 0.3, -0.5), 4, 0.16, 0.03)
    pitch = p.build("pitch", head, (0, 0, 1.5))
    pitch.rotation_euler = (math.radians(-20), 0, 0)
    muzzles(pitch, [(-0.78, -1.5, 0.33), (0.78, -1.5, 0.33), (0, -1.5, -0.33)])
    hempty("fx_shell", pitch, (0, 1.2, 0))
    t = HP()                                                                           # ab 4: Zusatzraketen an den Seiten
    for s in (-1, 1):
        t.box((0.3, 1.5, 0.3), (s * 1.44, -0.1, 0.5), "566078", bevel=0.05, segs=1)
        t.cyl(0.13, 1.5, (s * 1.44, -0.3, 0.82), "F4F6FA", r=AX_Y, sides=8)
        t.cyl(0.13, 0.3, (s * 1.44, -1.2, 0.82), RED, r=AX_Y, r2=0.02, sides=8)
        for a in (0, 90):
            t.box((0.5, 0.2, 0.03), (s * 1.44, 0.4, 0.82), RED, r=rot(0, a, 0))
    t.build("lv4_pods", pitch)
    t = HP()
    t.box((2.6, 0.1, 1.5), (0, -1.0, 0), GOLD, bevel=0.03, segs=1)
    t.box((2.58, 0.12, 1.48), (0, 0.9, 0), GOLD, bevel=0.03, segs=1)
    t.build("lv7_trim", pitch)
    head_damage(pitch, [(T(0.7, 0.2, 0.705) @ UP, 0.36, 0.28), (T(-1.255, -0.2, 0.2) @ LEFT, 0.3, 0.26)],
                [(T(-0.6, -0.4, 0.705) @ UP, 0.4, 0.3), (T(1.255, 0.4, 0.0) @ RIGHT, 0.36, 0.3), (T(0.78, -0.985, 0.33), 0.3, 0.3)])
    smoke(root, (0.4, 0.6, hz + 2.0))
    finish("t_rocket", copies=("b_rakete",))


# ------------------------------------------------------------------ Eisturm
def t_ice():
    root, base, hz, rng = begin("t_ice", "ice", 1.9, 1.15, bags="split", k=1.2)
    ICE, ICE_L, ICE_D = "5DB2EA", "DDF2FF", "3A86C8"
    hd = HP()
    hd.cyl(1.5, 0.34, (0, 0, 0.17), DARK, r2=1.34, sides=20, bevel=0.06, segs=1)
    hd.cyl(1.54, 0.08, (0, 0, 0.05), STEEL_L, sides=20)
    yoke(hd, 1.2, 1.15, depth=0.8, th=0.24, color=STEEL_L)
    for sx in (-0.5, 0.5):                                                               # Kältetanks hinten
        hd.cyl(0.4, 1.3, (sx, 1.0, 0.95), "F4F6FA", sides=12, bevel=0.16, segs=2)
        hd.cyl(0.415, 0.12, (sx, 1.0, 0.75), ICE_D, sides=12)
        hd.cyl(0.12, 0.14, (sx, 1.0, 1.66), STEEL, sides=6)
        hd.ball(0.2, (sx + 0.1, 0.85, 1.55), ICE_L, scale=(1.2, 1, 0.4), subdiv=1)        # Reifkappe
    tube(hd, (0.5, 1.0, 1.7), (0.6, 0.4, 1.5), 0.06, ICE_D, sides=6)
    tube(hd, (0.6, 0.4, 1.5), (0.5, 0.2, 1.2), 0.06, ICE_D, sides=6)
    head = hd.build("head", root, (0, 0, hz))
    g = HP(); g.cyl(0.1, 0.04, (0, 0.585, 0.95), CYAN, r=AX_Y, sides=8); g.build("gauge_glow", head)
    p = HP()
    p.box((2.0, 1.9, 1.3), (0, 0.15, 0), ICE, bevel=0.4, segs=3)
    p.cyl(0.2, 2.4, (0, 0, 0), STEEL_L, r=AX_X, sides=8)
    p.cyl(0.6, 0.44, (0, -0.85, 0.02), ICE_D, r=AX_Y, sides=14, bevel=0.1, segs=1)
    p.cyl(0.32, 1.5, (0, -1.7, 0.02), ICE_L, r=AX_Y, r2=0.5, sides=12)                   # Trichterrohr
    for y, rr in ((-1.3, 0.36), (-1.8, 0.42)):
        p.torus(rr, 0.05, (0, y, 0.02), ICE_D, r=AX_Y, seg=12, tseg=4)
    p.torus(0.5, 0.07, (0, -2.45, 0.02), ICE_D, r=AX_Y, seg=14, tseg=4)
    p.cyl(0.44, 0.02, (0, -2.44, 0.02), "1E4E86", r=AX_Y, sides=12)
    for x, y, hh, a in ((-0.5, 0.35, 0.8, -14), (0.0, 0.55, 1.1, 0), (0.5, 0.35, 0.75, 14), (0.05, -0.1, 0.55, 4), (-0.3, 0.75, 0.5, -20)):   # Eiskristalle
        p.cyl(0.2, hh, (x, y, 0.6 + hh * 0.5), ICE_L, r=rot(0, a, 0), r2=0.02, sides=6)
    for sx in (-0.7, 0.7):                                                               # Eiszapfen am Rohr
        p.cyl(0.06, 0.3, (sx * 0.3, -1.9, -0.5), ICE_L, r=rot(180, 0, 0), r2=0.005, sides=5)
    pitch = p.build("pitch", head, (0, 0, 1.15))
    g = HP()
    g.box((0.5, 0.05, 0.3), (0, -0.82, 0.38), "9FF0FF", r=rot(-20, 0, 0))
    g.build("core_glow", pitch)
    muzzles(pitch, [(0, -2.55, 0.02)])
    hempty("fx_shell", pitch, (0, -2.0, -0.4))
    t = HP()                                                                           # ab 4: Kühlrippen an den Seiten
    for s in (-1, 1):
        for i in range(4):
            t.box((0.12, 0.2, 0.9), (s * 1.04, -0.3 + i * 0.32, 0.0), STEEL_L)
    t.build("lv4_fins", pitch)
    t = HP()
    t.box((2.04, 0.12, 1.34), (0, 0.72, 0), GOLD, bevel=0.03, segs=1)
    t.torus(0.52, 0.08, (0, -2.4, 0.02), GOLD, r=AX_Y, seg=14, tseg=4)
    for x, y, hh in ((-0.75, -0.2, 0.5), (0.75, -0.2, 0.5)):
        t.cyl(0.16, hh, (x, y, 0.6 + hh * 0.5), "BFE8FF", r2=0.02, sides=6)
    t.build("lv7_trim", pitch)
    head_damage(pitch, [(T(0.5, -0.2, 0.655) @ UP, 0.3, 0.24), (T(-1.005, 0.3, 0.0) @ LEFT, 0.3, 0.26)],
                [(T(-0.5, -0.3, 0.655) @ UP, 0.34, 0.26), (T(1.005, -0.1, 0.1) @ RIGHT, 0.34, 0.28)])
    smoke(root, (0.3, 0.7, hz + 1.9))
    finish("t_ice", copies=("b_eis",))


TABLE = {"t_mg": t_mg, "t_watch": t_watch, "t_cannon": t_cannon, "t_flame": t_flame, "t_mortar": t_mortar,
         "t_tesla": t_tesla, "t_rocket": t_rocket, "t_ice": t_ice, "t_aa": t_aa, "t_mini": t_mini}

if __name__ == "__main__":
    run(TABLE, sys.argv)
