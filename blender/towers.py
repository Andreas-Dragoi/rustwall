"""Verteidigungstürme t_*. Aufbau (Godot richtet sie aus):
  base  – fester Sockel            head  – dreht um Z, Ursprung oben auf dem Sockel
  pitch – Kind von head, neigt um X, trägt die Läufe (zeigen nach -Y)
  muzzle, muzzle2, muzzle3 – Leerobjekte an den Mündungen (Kinder von pitch)
  lv4_trim / lv7_trim – Ausbauteile am Sockel (Kinder der Wurzel)
Tesla/Mini: Spulenmast in head, Kugel `pulse_orb_glow`, muzzle an der Kugel.
Aufruf: python3 blender/towers.py [t_mg ...]"""
import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from kit import *
from rw_util import *

STONE, STONE_L, STONE_D = "A7ADC6", "BCC2D8", "7F86A6"
BLUE, BLUE_D = "3C5CA4", "2C447E"
RED, RED_D = "DD4343", "A82E38"
DARK, STEEL, STEEL_L = "2E3340", "8A94A8", "B9C1D0"
GOLD, GOLD_D = "FFC62E", "E09A1E"


def round_base(root, R, h, blocks=8):
    """Runder Steinsockel mit Blockkranz, blauer Deckplatte und Stern-Plakette. Oberkante = h + 0.22."""
    b = Part()
    b.cyl(R, 0.36, (0, 0, 0.18), STONE_D, sides=24, bevel=0.1)
    for i in range(blocks):
        a = 360.0 / blocks * (i + 0.5)
        ra = math.radians(a)
        b.box((R * 0.56, R * 0.3, 0.58), (math.sin(ra) * R * 0.93, -math.cos(ra) * R * 0.93, 0.29), (STONE, STONE_L)[i % 2], r=rot(0, 0, a), bevel=0.1, segs=2)
    b.cyl(R * 0.86, h - 0.16, (0, 0, 0.16 + (h - 0.16) * 0.5), STONE, r2=R * 0.78, sides=24, bevel=0.08)
    b.cyl(R * 0.83, 0.24, (0, 0, h + 0.1), BLUE, sides=24, bevel=0.08)
    # Plakette mit Stern vorn
    ph = min(h * 0.62, 0.9)
    pz = 0.5 + (h - 0.5) * 0.5 + 0.06
    b.box((R * 0.62, 0.2, ph), (0, -R * 0.8, pz), BLUE, bevel=0.08, segs=2)
    star(b, (0, -R * 0.8 - 0.1, pz), min(ph * 0.42, R * 0.24), "FFFFFF", 0.06, r=STAR_FRONT)
    base = b.build("base", root)
    # Stufe 4: goldener Reif + Kappen auf den Blöcken
    t = Part()
    t.torus(R * 0.84, 0.07, (0, 0, h - 0.12), GOLD, seg=24, tseg=6)
    for i in range(blocks):
        ra = math.radians(360.0 / blocks * (i + 0.5))
        t.cyl(0.14, 0.1, (math.sin(ra) * R * 0.93, -math.cos(ra) * R * 0.93, 0.62), GOLD, r2=0.08, sides=8)
    t.build("lv4_trim", root)
    # Stufe 7: goldener Deckring + Panzerplatten in den Diagonalen
    t = Part()
    t.torus(R * 0.83, 0.09, (0, 0, h + 0.2), GOLD, seg=24, tseg=6)
    for i in range(4):
        a = 45 + i * 90
        ra = math.radians(a)
        m = T(math.sin(ra) * R * 0.86, -math.cos(ra) * R * 0.86, 0.45 + (h - 0.45) * 0.5) @ rot(0, 0, a)
        t.box((R * 0.5, 0.16, (h - 0.3) * 0.8), (0, 0, 0), "5E79B8", r=m, bevel=0.07, segs=2)
        t.ball(0.09, (0, 0, 0), GOLD, r=m @ T(0, -0.08, 0), subdiv=2)
    t.build("lv7_trim", root)
    return base


def barrel(p, x, z, y0, y1, r, color=DARK, tip=STEEL, tip_r=None, tip_len=0.18, sides=12, r_front=None):
    """Lauf entlang -Y von y0 (hinten) bis y1 (vorn, y1 < y0), mit Mündungsring."""
    ln = y0 - y1
    p.cyl(r, ln, (x, (y0 + y1) * 0.5, z), color, r=AX_Y, r2=r_front, sides=sides)
    tr = (r_front or r) * 1.35 if tip_r is None else tip_r
    p.cyl(tr, tip_len, (x, y1, z), tip, r=AX_Y, sides=sides, bevel=0.03, segs=1)
    p.cyl(tr * 0.6, 0.02, (x, y1 - tip_len * 0.5 - 0.005, z), "14161C", r=AX_Y, sides=sides)


def yoke(hd, half, z_ax, depth=0.5, th=0.18, color=STEEL, y=0.0):
    """Gabel, in der das Geschütz hängt."""
    for s in (-1, 1):
        hd.box((th, depth, z_ax + 0.2), (s * half, y, (z_ax + 0.2) * 0.5), color, bevel=0.06, segs=2)
        hd.cyl(0.12, th + 0.08, (s * half, y, z_ax), GOLD_D, r=AX_X, sides=10, bevel=0.02, segs=1)


K = 1.0


def kv(x, y, z):
    return (x * K, y * K, z * K)


def start(name, R, h, blocks=8, k=1.0):
    global K
    K = k
    reset()
    root = empty(name)
    round_base(root, R, h, blocks)
    return root, h + 0.22


def muzzles(pitch, pts):
    for i, q in enumerate(pts):
        empty("muzzle" if i == 0 else "muzzle%d" % (i + 1), pitch, kv(*q))


# ------------------------------------------------------------------ MG / Flak
def gun_turret(name, body_col, pitch_deg=0.0, copies=(), aa=False):
    root, hz = start(name, 1.5, 1.5, k=1.3)
    hd = KPart(K)
    hd.cyl(0.66, 0.36, (0, 0, 0.18), DARK, r2=0.56, sides=16, bevel=0.06)
    yoke(hd, 0.7, 0.75, y=-0.1)
    head = hd.build("head", root, (0, 0, hz))
    p = KPart(K)
    p.box((1.16, 1.3, 0.84), (0, 0.12, 0), body_col, bevel=0.28, segs=4)
    p.box((0.9, 0.3, 0.6), (0, -0.5, -0.02), shade(body_col, 0.78), bevel=0.1, segs=2)     # Blende
    p.cyl(0.14, 1.36, (0, 0, 0), STEEL, r=AX_X, sides=10)
    star(p, (0, 0.14, 0.425), 0.3, "FFFFFF", 0.05)
    if aa:
        for sx in (-0.26, 0.26):
            barrel(p, sx, 0.0, -0.5, -1.9, 0.105, DARK, STEEL, tip_r=0.15, tip_len=0.3)
            p.cyl(0.13, 0.5, (sx, -0.85, 0), shade(body_col, 0.7), r=AX_Y, sides=10, bevel=0.03, segs=1)
        p.torus(0.2, 0.03, (0, -0.3, 0.72), GOLD, r=AX_Y, seg=12, tseg=4)                   # Ringvisier
        p.cyl(0.03, 0.3, (0, -0.3, 0.5), DARK, sides=5)
        p.box((0.3, 0.6, 0.5), (0.72, 0.2, 0.0), "5A6B3A", bevel=0.08, segs=2)             # Munitionskasten
        mz = [(-0.26, -2.07, 0), (0.26, -2.07, 0)]
    else:
        for sx in (-0.25, 0.25):
            barrel(p, sx, 0.0, -0.5, -1.4, 0.13, DARK, STEEL, tip_r=0.185, tip_len=0.2)
            p.cyl(0.175, 0.34, (sx, -0.78, 0), "4A5263", r=AX_Y, sides=10, bevel=0.03, segs=1)  # Kühlmantel
        p.box((0.32, 0.62, 0.5), (0.72, 0.2, 0.0), "E0A82E", bevel=0.08, segs=2)           # Munitionskasten
        p.box((0.34, 0.2, 0.16), (0.72, 0.2, 0.26), DARK, bevel=0.04, segs=1)
        mz = [(-0.25, -1.52, 0), (0.25, -1.52, 0)]
    pitch = p.build("pitch", head, kv(0, -0.1, 0.75))
    pitch.rotation_euler = (math.radians(pitch_deg), 0, 0)
    muzzles(pitch, mz)
    finish(name, copies=copies, hide=("lv",))


def t_mg():
    gun_turret("t_mg", RED, copies=("b_mg",))


def t_aa():
    gun_turret("t_aa", "3FA35A", pitch_deg=-28, copies=("b_luftabwehr",), aa=True)


# ------------------------------------------------------------------ Wachturm
def t_watch():
    global K
    K = 1.0
    reset(); root = empty("t_watch")
    wood, wood_d, wood_l = "B56A32", "8A4E26", "CC8444"
    b = Part()
    b.box((3.0, 3.0, 0.4), (0, 0, 0.2), STONE_D, bevel=0.14, segs=3)
    b.box((2.5, 2.5, 0.3), (0, 0, 0.5), STONE, bevel=0.12, segs=2)
    for sx in (-1, 1):
        for sy in (-1, 1):
            b.box((0.36, 0.36, 3.1), (sx * 1.02, sy * 1.02, 1.95), wood_d, r=rot(-5 * sy, 5 * sx, 0), bevel=0.08, segs=2)
    for i in range(4):                                                     # Kreuzstreben
        m = rot(0, 0, i * 90)
        for s in (-1, 1):
            b.box((2.9, 0.12, 0.2), (0, 0, 0), wood, r=m @ T(0, -1.02, 2.0) @ rot(0, 40 * s, 0), bevel=0.04, segs=1)
        b.box((2.3, 0.16, 0.22), (0, 0, 0), wood_d, r=m @ T(0, -1.06, 0.95), bevel=0.05, segs=1)
    b.box((3.0, 3.0, 0.3), (0, 0, 3.47), wood, bevel=0.1, segs=2)          # Plattform (Oberkante 3.62)
    for i in range(5):
        b.box((0.5, 3.04, 0.06), (-1.2 + i * 0.6, 0, 3.6), (wood_l, wood)[i % 2], bevel=0.02, segs=1)
    for i in range(6):                                                     # Leiter hinten
        b.box((0.6, 0.08, 0.08), (0, 1.5, 0.75 + i * 0.5), wood_l)
    for s in (-1, 1):
        b.box((0.09, 0.09, 3.2), (0.32 * s, 1.5, 1.95), wood_d)
    b.box((0.9, 0.16, 0.9), (0, -1.12, 2.0), BLUE, bevel=0.07, segs=2)     # Schild mit Stern
    star(b, (0, -1.22, 2.0), 0.32, "FFFFFF", 0.06, r=STAR_FRONT)
    b.build("base", root)
    t = Part()
    for sx in (-1, 1):
        for sy in (-1, 1):
            t.cyl(0.24, 0.16, (sx * 1.0, sy * 1.0, 1.3), GOLD, sides=10, bevel=0.03, segs=1)
            t.cyl(0.24, 0.16, (sx * 0.93, sy * 0.93, 2.7), GOLD, sides=10, bevel=0.03, segs=1)
    t.build("lv4_trim", root)
    t = Part()
    for i in range(4):
        m = rot(0, 0, i * 90)
        t.box((3.1, 0.12, 0.14), (0, 0, 0), GOLD, r=m @ T(0, -1.48, 3.47), bevel=0.04, segs=1)
        t.box((0.7, 0.5, 0.5), (0, 0, 0), "5E79B8", r=m @ T(1.2, -1.2, 0.55) @ rot(0, 0, 45), bevel=0.12, segs=2)
    t.build("lv7_trim", root)
    hd = KPart(K)
    for i in range(4):                                                     # Brüstung
        m = rot(0, 0, i * 90)
        hd.box((2.6, 0.16, 0.56), (0, 0, 0), wood, r=m @ T(0, -1.26, 0.3), bevel=0.06, segs=2)
        hd.box((2.7, 0.2, 0.12), (0, 0, 0), wood_d, r=m @ T(0, -1.26, 0.62), bevel=0.04, segs=1)
    for sx in (-1, 1):
        for sy in (-1, 1):
            hd.box((0.22, 0.22, 2.1), (sx * 1.22, sy * 1.22, 1.05), wood_d, bevel=0.06, segs=1)
    hd.cyl(2.25, 1.1, (0, 0, 2.6), RED, r=rot(0, 0, 45), r2=0.22, sides=4, bevel=0.1, segs=2)   # Dach
    hd.cyl(2.3, 0.14, (0, 0, 2.08), RED_D, r=rot(0, 0, 45), sides=4, bevel=0.04, segs=1)
    hd.ball(0.2, (0, 0, 3.2), GOLD, subdiv=2)
    hd.cyl(0.1, 0.9, (0, -0.2, 0.45), DARK, sides=8)                       # Lafette
    hd.cyl(0.2, 0.14, (0, -0.2, 0.9), STEEL, sides=10, bevel=0.03, segs=1)
    head = hd.build("head", root, (0, 0, 3.62))
    p = KPart(K)
    p.box((0.3, 0.8, 0.3), (0, 0.15, 0.02), DARK, bevel=0.08, segs=2)
    p.box((0.2, 0.36, 0.24), (0, 0.66, -0.06), "8A4E26", bevel=0.06, segs=1)   # Schulterstütze
    barrel(p, 0, 0.02, -0.2, -1.35, 0.075, "3A4152", STEEL, tip_r=0.11, tip_len=0.22, sides=8)
    p.cyl(0.07, 0.5, (0, 0.05, 0.24), STEEL, r=AX_Y, sides=8)              # Zielfernrohr
    p.cyl(0.09, 0.08, (0, -0.2, 0.24), "8FD3F5", r=AX_Y, sides=8)
    pitch = p.build("pitch", head, kv(0, -0.2, 1.0))
    muzzles(pitch, [(0, -1.5, 0.02)])
    finish("t_watch", copies=("b_wachturm",), hide=("lv",))


# ------------------------------------------------------------------ Kanone
def t_cannon():
    root, hz = start("t_cannon", 2.15, 0.9, 10, k=1.25)
    hd = KPart(K)
    hd.cyl(1.36, 0.5, (0, 0, 0.25), DARK, r2=1.16, sides=20, bevel=0.08)
    yoke(hd, 1.14, 0.95, depth=0.8, th=0.24)
    head = hd.build("head", root, (0, 0, hz))
    p = KPart(K)
    p.box((1.9, 1.9, 1.24), (0, 0.2, 0), RED, bevel=0.42, segs=5)
    p.cyl(0.2, 2.3, (0, 0, 0), STEEL, r=AX_X, sides=10)
    p.cyl(0.62, 0.4, (0, -0.8, 0.05), RED_D, r=AX_Y, sides=16, bevel=0.1)      # Rohrwiege
    star(p, (0, 0.25, 0.63), 0.46, "FFFFFF", 0.06)
    p.cyl(0.36, 1.3, (0, -1.45, 0.05), DARK, r=AX_Y, r2=0.31, sides=16)
    p.cyl(0.4, 0.16, (0, -1.25, 0.05), "4A5263", r=AX_Y, sides=16, bevel=0.03, segs=1)
    p.cyl(0.44, 0.34, (0, -2.12, 0.05), STEEL, r=AX_Y, sides=16, bevel=0.06)
    p.cyl(0.27, 0.02, (0, -2.3, 0.05), "14161C", r=AX_Y, sides=14)
    for s in (-1, 1):
        p.box((0.2, 0.9, 0.5), (0.9 * s, 0.75, 0.0), RED_D, bevel=0.08, segs=2)
    pitch = p.build("pitch", head, kv(0, 0, 0.95))
    muzzles(pitch, [(0, -2.35, 0.05)])
    finish("t_cannon", copies=("b_kanone",), hide=("lv",))


# ------------------------------------------------------------------ Flammenturm
def t_flame():
    root, hz = start("t_flame", 1.5, 1.5, k=1.3)
    hd = KPart(K)
    hd.cyl(0.6, 0.36, (0, 0, 0.18), DARK, r2=0.5, sides=16, bevel=0.06)
    yoke(hd, 0.52, 0.7, depth=0.4, th=0.16, y=-0.1)
    # Brennstofftank hinten
    hd.cyl(0.46, 1.1, (0, 0.72, 0.62), "F2A81E", sides=16, bevel=0.2, segs=4)
    hd.cyl(0.475, 0.12, (0, 0.72, 0.62), RED, sides=16)
    hd.cyl(0.16, 0.14, (0, 0.72, 1.22), DARK, sides=10, bevel=0.03, segs=1)
    hd.cyl(0.07, 0.6, (0.3, 0.42, 0.95), STEEL, r=rot(70, 0, 0), sides=6)          # Schlauch
    head = hd.build("head", root, (0, 0, hz))
    p = KPart(K)
    p.box((0.78, 1.0, 0.66), (0, 0.0, 0), RED, bevel=0.22, segs=4)
    p.cyl(0.1, 1.0, (0, 0, 0), STEEL, r=AX_X, sides=8)
    p.cyl(0.15, 0.7, (0, -0.8, 0), DARK, r=AX_Y, sides=12)
    p.cyl(0.19, 0.12, (0, -0.62, 0), GOLD_D, r=AX_Y, sides=12, bevel=0.02, segs=1)
    p.cyl(0.17, 0.36, (0, -1.3, 0), STEEL, r=AX_Y, r2=0.32, sides=14)              # Trichter
    p.torus(0.32, 0.045, (0, -1.48, 0), DARK, r=AX_Y, seg=14, tseg=5)
    p.cyl(0.04, 0.5, (0, -1.05, 0.26), "4A5263", r=AX_Y, sides=5)                  # Zündflamme
    star(p, (0, 0.05, 0.335), 0.2, "FFFFFF", 0.04)
    pitch = p.build("pitch", head, kv(0, -0.1, 0.7))
    g = KPart(K)
    g.ball(0.09, (0, 0, 0), "FFB03A", scale=(1, 1.5, 1), subdiv=2)
    g.build("pilot_glow", pitch, kv(0, -1.36, 0.26))
    muzzles(pitch, [(0, -1.5, 0)])
    finish("t_flame", copies=("b_flammenturm",), hide=("lv",))


# ------------------------------------------------------------------ Mörser
def t_mortar():
    root, hz = start("t_mortar", 2.15, 0.9, 10, k=1.3)
    hd = KPart(K)
    hd.cyl(1.5, 0.3, (0, 0, 0.15), DARK, r2=1.4, sides=20, bevel=0.07)
    yoke(hd, 0.86, 0.6, depth=0.7, th=0.22)
    for i in range(3):                                                             # Granaten
        hd.cyl(0.2, 0.36, (1.2, 0.5 - i * 0.5, 0.48), "3A4152", sides=10, bevel=0.03, segs=1)
        hd.cone(0.2, 0.26, (1.2, 0.5 - i * 0.5, 0.79), RED, sides=10)
    hd.box((0.5, 1.5, 0.12), (1.2, 0.0, 0.34), "8A4E26", bevel=0.04, segs=1)
    head = hd.build("head", root, (0, 0, hz))
    p = KPart(K)
    p.cyl(0.66, 0.5, (0, 0.45, 0), RED_D, r=AX_Y, sides=16, bevel=0.2, segs=4)     # Bodenstück
    p.cyl(0.6, 1.7, (0, -0.4, 0), RED, r=AX_Y, r2=0.54, sides=16)
    p.cyl(0.64, 0.2, (0, -0.2, 0), GOLD_D, r=AX_Y, sides=16, bevel=0.04, segs=1)
    p.cyl(0.64, 0.3, (0, -1.3, 0), STEEL, r=AX_Y, sides=16, bevel=0.07)
    p.cyl(0.45, 0.02, (0, -1.455, 0), "14161C", r=AX_Y, sides=14)
    p.cyl(0.16, 1.6, (0, 0, 0), STEEL, r=AX_X, sides=10)
    star(p, (0, -0.72, 0.0), 0.3, "FFFFFF", 0.05, r=T(0, 0, 0.575))
    pitch = p.build("pitch", head, kv(0, 0, 0.6))
    pitch.rotation_euler = (math.radians(-55), 0, 0)
    muzzles(pitch, [(0, -1.7, 0)])
    finish("t_mortar", copies=("b_moerser",), hide=("lv",))


# ------------------------------------------------------------------ Tesla / Mini
def coil_tower(name, R, h, th, k, blocks, copies=()):
    global K
    K = 1.0
    reset(); root = empty(name)
    if R > 1.0:
        round_base(root, R, h, blocks)
    else:                                                                          # Mini: schlichter kleiner Sockel
        b = Part()
        b.cyl(R, h * 0.5, (0, 0, h * 0.25), STONE_D, sides=14, bevel=0.06)
        b.cyl(R * 0.82, h * 0.6, (0, 0, h * 0.7), STONE, r2=R * 0.7, sides=14, bevel=0.05)
        b.cyl(R * 0.72, 0.2, (0, 0, h + 0.12), BLUE, sides=14, bevel=0.05)
        star(b, (0, -R * 0.8, h * 0.62), 0.14, "FFFFFF", 0.04, r=STAR_FRONT)
        b.build("base", root)
        t = Part(); t.torus(R * 0.8, 0.04, (0, 0, h * 0.52), GOLD, seg=14, tseg=5); t.build("lv4_trim", root)
        t = Part(); t.torus(R * 0.72, 0.05, (0, 0, h + 0.2), GOLD, seg=14, tseg=5); t.build("lv7_trim", root)
    hz = h + 0.22
    hd = KPart(K)
    hd.cyl(0.74 * k, 0.3 * k, (0, 0, 0.15 * k), DARK, r2=0.6 * k, sides=14, bevel=0.05 * k)
    hd.cyl(0.46 * k, th, (0, 0, th * 0.5), BLUE, r2=0.24 * k, sides=12)
    n = 5 if k >= 1.0 else 3
    for i in range(n):
        rr = (0.8 - i * 0.11) * k
        hd.torus(rr, 0.11 * k, (0, 0, 0.5 * k + i * th * 0.17), GOLD, seg=18, tseg=6)
    hd.cyl(0.3 * k, 0.16 * k, (0, 0, th), DARK, sides=12, bevel=0.03 * k, segs=1)
    for i in range(3):                                                             # Halteklauen um die Kugel
        m = rot(0, 0, i * 120 + 60)
        hd.box((0.1 * k, 0.1 * k, 0.6 * k), (0, 0, 0), STEEL, r=m @ T(0, -0.5 * k, th + 0.3 * k) @ rot(-18, 0, 0), bevel=0.03 * k, segs=1)
        hd.ball(0.09 * k, (0, 0, 0), GOLD, r=m @ T(0, -0.58 * k, th + 0.62 * k), subdiv=2)
    head = hd.build("head", root, (0, 0, hz))
    o = Part()
    o.ball(0.5 * k if k >= 1.0 else 0.28, (0, 0, 0), "2FB4FF", subdiv=3)
    o.build("pulse_orb_glow", head, (0, 0, th + 0.4 * (k if k >= 1 else 1.0)))
    pitch = empty("pitch", head, (0, 0, th + 0.4 * (k if k >= 1 else 1.0)))
    muzzles(pitch, [(0, 0, 0)])
    finish(name, copies=copies, hide=("lv",))


def t_tesla():
    coil_tower("t_tesla", 1.5, 0.9, 3.0, 1.0, 8, copies=("b_tesla",))


def t_mini():
    coil_tower("t_mini", 0.58, 0.5, 1.4, 0.5, 0)


# ------------------------------------------------------------------ Raketenwerfer
def t_rocket():
    root, hz = start("t_rocket", 2.15, 0.9, 10, k=1.15)
    hd = KPart(K)
    hd.cyl(1.2, 0.3, (0, 0, 0.15), DARK, r2=1.05, sides=20, bevel=0.07)
    hd.cyl(0.62, 0.8, (0, 0, 0.55), "4A5263", r2=0.5, sides=14, bevel=0.06)
    yoke(hd, 1.26, 1.2, depth=0.6, th=0.22)
    hd.box((2.6, 0.5, 0.2), (0, 0, 0.4), STEEL, bevel=0.07, segs=2)
    head = hd.build("head", root, (0, 0, hz))
    p = KPart(K)
    p.box((2.2, 2.0, 1.3), (0, 0, 0), RED, bevel=0.3, segs=4)
    p.box((2.24, 0.3, 1.34), (0, 0.45, 0), RED_D, bevel=0.1, segs=2)
    p.cyl(0.18, 2.6, (0, 0, 0), STEEL, r=AX_X, sides=10)
    star(p, (0, -0.25, 0.655), 0.42, "FFFFFF", 0.06)
    for gx in (-0.66, 0.0, 0.66):
        for gz in (-0.3, 0.3):
            p.cyl(0.27, 0.14, (gx, -0.98, gz), DARK, r=AX_Y, sides=12, bevel=0.03, segs=1)
            p.cyl(0.19, 0.2, (gx, -1.02, gz), "F4F6FA", r=AX_Y, sides=10)
            p.cone(0.19, 0.3, (gx, -1.27, gz), RED_D if gz < 0 else "F4F6FA", r=AX_Y, sides=10)
    pitch = p.build("pitch", head, kv(0, 0, 1.2))
    pitch.rotation_euler = (math.radians(-20), 0, 0)
    muzzles(pitch, [(-0.66, -1.3, 0.3), (0.66, -1.3, 0.3), (0, -1.3, -0.3)])
    finish("t_rocket", copies=("b_rakete",), hide=("lv",))


# ------------------------------------------------------------------ Eisturm
def t_ice():
    root, hz = start("t_ice", 2.15, 0.9, 10, k=1.25)
    ice, ice_l, ice_d = "5DB2EA", "DDF2FF", "3A86C8"
    hd = KPart(K)
    hd.cyl(1.36, 0.5, (0, 0, 0.25), DARK, r2=1.16, sides=20, bevel=0.08)
    yoke(hd, 1.1, 0.95, depth=0.8, th=0.24, color=STEEL_L)
    head = hd.build("head", root, (0, 0, hz))
    p = KPart(K)
    p.box((1.8, 1.8, 1.2), (0, 0.2, 0), ice, bevel=0.4, segs=5)
    p.cyl(0.2, 2.2, (0, 0, 0), STEEL_L, r=AX_X, sides=10)
    p.cyl(0.56, 0.4, (0, -0.75, 0.05), ice_d, r=AX_Y, sides=16, bevel=0.1)
    p.cyl(0.3, 1.4, (0, -1.5, 0.05), ice_l, r=AX_Y, r2=0.46, sides=14)             # Trichterrohr
    p.torus(0.46, 0.07, (0, -2.2, 0.05), ice_d, r=AX_Y, seg=16, tseg=6)
    p.cyl(0.4, 0.02, (0, -2.19, 0.05), "1E4E86", r=AX_Y, sides=14)
    p.torus(0.36, 0.05, (0, -1.5, 0.05), ice_d, r=AX_Y, seg=14, tseg=5)
    for x, y, h, a in ((-0.45, 0.3, 0.75, -14), (0.0, 0.45, 1.0, 0), (0.45, 0.3, 0.7, 14), (0.0, -0.1, 0.55, 0)):   # Eiskristalle
        p.cyl(0.2, h, (x, y, 0.55 + h * 0.5), ice_l, r=rot(0, a, 0), r2=0.02, sides=6)
    pitch = p.build("pitch", head, kv(0, 0, 0.95))
    muzzles(pitch, [(0, -2.3, 0.05)])
    finish("t_ice", copies=("b_eis",), hide=("lv",))


TABLE = {"t_mg": t_mg, "t_watch": t_watch, "t_cannon": t_cannon, "t_flame": t_flame, "t_mortar": t_mortar,
         "t_tesla": t_tesla, "t_rocket": t_rocket, "t_ice": t_ice, "t_aa": t_aa, "t_mini": t_mini}

if __name__ == "__main__":
    run(TABLE, sys.argv)
