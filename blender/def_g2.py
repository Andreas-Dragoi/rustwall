"""Paket G2 – Fallen, Deko, Boss-Trophäen, Trümmer, Bauteile und Effekt-Modelle (Kapitel 4.1, 6.2, 6.5, 7.2).
Fallen (Baumenü „Fallen“):
  b_teer (2 × 2) Teergrube mit Blasen `pulse_bubble1..3` · b_feder (1 × 1) Federbrett, Brett `board` (das Spiel klappt es hoch)
  b_koeder (1 × 1) Lockköder: Kiste mit Wurst, Fähnchen `sway_flag` · b_zaun (2 × 1) Elektrozaun, Drähte `wire_glow`, `pulse_spark_glow`
  b_eisfalle (1 × 1) Eisplatte mit Kristallkern `pulse_core_glow`
Deko (Baumenü „Schmuck“, Deko-Punkte in src/data.gd):
  b_bank, b_gartenzaun, b_platte, b_holzstapel, b_heu, b_waesche (`sway_laundry`), b_beet, b_kuebel, b_vogelhaus,
  b_picknick (`sway_umbrella`), b_windrad (`spin_wheel`), b_brunnen (`water_glow`, `pulse_jet`)
Trophäen: b_trophy_bert / _moos / _rost / _glibber / _schlund / _frost / _koenig – Sockel mit Schild, Ausstellungsstück, `pulse_gem_glow`
Trümmer: b_rubble_1 … b_rubble_4 (Grundfläche 1 × 1 bis 4 × 4 Felder) – ersetzen ein zerstörtes Gebäude
Bauteile: fx_build_parts (sechs Einzelteile part_1 … part_6, fliegen bei Fertigstellung ein – src/build_fx.gd)
Effekte: fx_elite_crown (Krone der Elite-Gegner), fx_elite_aura (Ring am Boden), fx_weakspot (Zielzeichen der Schwachstelle),
  fx_boss_rage (Wut-Aura der Bosse)
Aufruf: python3 blender/def_g2.py [namen...]"""
import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from def_kit import *
from animkit import lathe, capsule


def begin(name):
    reset()
    return empty(name), Part(), rng_for(name)


def plank_frame(B, w, d, h, rng, col=WOOD, col_d=WOOD_D):
    for (sx, sy, lx, ly) in ((0, -1, w, 0.12), (0, 1, w, 0.12), (-1, 0, 0.12, d), (1, 0, 0.12, d)):
        B.box((lx, ly, h), (sx * (w - 0.12) * 0.5, sy * (d - 0.12) * 0.5, h * 0.5), jit(col, rng, 0.08))
    for sx in (-1, 1):
        for sy in (-1, 1):
            B.box((0.16, 0.16, h + 0.06), (sx * (w - 0.12) * 0.5, sy * (d - 0.12) * 0.5, (h + 0.06) * 0.5), col_d)


# ================================================================= Fallen
def teer():
    root, B, rng = begin("b_teer")
    plank_frame(B, 3.6, 3.6, 0.22, rng)
    B.box((3.3, 3.3, 0.06), (0, 0, 0.05), "15161C")
    for (x, y, r) in ((0, 0, 1.3), (0.8, 0.7, 0.8), (-0.9, 0.6, 0.75), (-0.6, -0.8, 0.9), (0.8, -0.7, 0.7)):
        B.ball(r, (x, y, 0.08), "22232C", subdiv=2, scale=(1, 1, 0.08 / r))
    for (x, y, r) in ((-0.3, 0.3, 0.35), (0.6, -0.2, 0.22), (-0.6, -0.6, 0.2)):
        B.ball(r, (x, y, 0.13), "4A4E62", subdiv=1, scale=(1, 0.8, 0.12))                             # Glanz
    m = T(1.25, 1.35, 0.35) @ rot(0, 80, 30)                                                         # umgekipptes Teerfass
    B.cyl(0.3, 0.75, (0, 0, 0), "3A3A42", r=m, sides=10, bevel=0.04, segs=1)
    for k in (-0.22, 0.22):
        B.cyl(0.31, 0.06, (0, 0, 0), HAZ_Y, r=m @ T(0, 0, k), sides=10)
    B.cyl(0.04, 1.1, (-1.55, 1.55, 0.55), WOOD_D, sides=5)                                          # Warnschild mit Flamme
    B.box((0.5, 0.05, 0.5), (-1.55, 1.52, 1.05), HAZ_Y, r=rot(0, 45, 0))
    B.cone(0.1, 0.22, (-1.55, 1.49, 1.04), "E85A1E", sides=5)
    B.build("body", root)
    for i, (x, y) in enumerate(((0.3, 0.2), (-0.5, -0.3), (0.6, -0.8))):
        p = Part()
        p.ball(0.12, (0, 0, 0), "3A3E4E", subdiv=1, scale=(1, 1, 0.7))
        p.build("pulse_bubble%d" % (i + 1), root, (x, y, 0.15))
    finish("b_teer", limit=2500, pitch=40)


def feder():
    root, B, rng = begin("b_feder")
    B.box((1.7, 1.7, 0.16), (0, 0, 0.08), DK, bevel=0.03, segs=1)
    B.box((1.5, 1.5, 0.04), (0, 0, 0.17), STEEL)
    hazard(B, (-0.85, -0.86, 0.12), (0.85, -0.86, 0.12), 6, 0.12, 0.04)
    for sx in (-1, 1):                                                                               # dicke Schraubenfedern
        for k in range(5):
            B.cyl(0.18, 0.05, (0.4 * sx, 0.1, 0.24 + k * 0.08), STEEL_L, r=rot(8 if k % 2 else -8, 0, 0), sides=8)
    B.box((0.3, 0.2, 0.2), (0, 0.72, 0.25), DK)                                                      # Scharnier hinten
    B.build("body", root)
    p = Part()                                                                                       # Brett (Drehpunkt am Scharnier)
    p.box((1.5, 1.4, 0.12), (0, -0.7, 0.0), WOOD, bevel=0.03, segs=1)
    for k in range(3):
        p.box((1.5, 0.04, 0.13), (0, -0.25 - k * 0.45, 0.0), WOOD_D)
    p.box((0.5, 0.06, 0.3), (0, -1.38, 0.15), RED, bevel=0.02, segs=1)
    p.build("board", root, (0, 0.7, 0.62))
    finish("b_feder", limit=2500, pitch=34)


def koeder():
    root, B, rng = begin("b_koeder")
    B.box((1.2, 1.0, 0.5), (0, 0.1, 0.25), WOOD, bevel=0.04, segs=1)                               # Kiste
    for k in range(3):
        B.box((1.22, 0.04, 0.08), (0, -0.41, 0.1 + k * 0.15), WOOD_D)
    B.box((1.3, 1.1, 0.06), (0, 0.1, 0.52), WOOD_D)
    m = T(0, -0.05, 0.7) @ rot(0, 0, 20)                                                             # Riesenwurst
    B.cyl(0.18, 0.9, (0, 0, 0), "C8584A", r=m @ rot(0, 90, 0), sides=10)
    for s in (-1, 1):
        B.ball(0.18, (0, 0, 0), "C8584A", r=m @ T(0.45 * s, 0, 0), subdiv=1)
    B.ball(0.25, (0.35, 0.3, 0.68), "F2D04A", subdiv=1, scale=(1, 1, 0.6))                          # Käse
    for (x, y) in ((0.3, 0.2), (0.42, 0.38)):
        B.ball(0.06, (x, y, 0.8), "C8A43A", subdiv=1)
    for k in range(3):                                                                               # Duftwolken
        B.ball(0.12 + 0.04 * k, (-0.35 + 0.1 * k, 0.1, 1.05 + 0.25 * k), "F8E8C0", subdiv=1, scale=(1, 0.6, 0.7))
    flag(root, B, (-0.62, 0.42, 0.0), h=1.5, size=(0.5, 0.34), with_star=False)
    B.build("body", root)
    finish("b_koeder", limit=2500, pitch=30)


def zaun():
    root, B, rng = begin("b_zaun")
    for x in (-1.6, 1.6):                                                                            # zwei Isolatorpfosten
        B.box((0.36, 0.36, 0.2), (x, 0, 0.1), DK, bevel=0.03, segs=1)
        B.cyl(0.08, 1.7, (x, 0, 1.0), STEEL, sides=8)
        for z in (0.55, 1.0, 1.45):
            B.cyl(0.11, 0.1, (x, 0, z), "F2F2E8", sides=8, r2=0.07)
        B.ball(0.12, (x, 0, 1.9), HAZ_Y, subdiv=1)
    B.box((0.5, 0.3, 0.4), (1.6, 0.35, 0.3), "3A4152", bevel=0.03, segs=1)                           # Generator
    B.box((0.3, 0.05, 0.3), (1.6, 0.18, 0.35), HAZ_Y, r=rot(0, 45, 0))
    B.build("body", root)
    w = Part()
    for z in (0.55, 1.0, 1.45):
        w.cyl(0.025, 3.2, (0, 0, z), "8AE8FF", r=rot(0, 90, 0), sides=4)
    w.build("wire_glow", root)
    s = Part()
    s.ball(0.1, (0, 0, 0), "D8F8FF", subdiv=1)
    s.build("pulse_spark_glow", root, (1.6, 0, 1.9))
    finish("b_zaun", limit=2500, pitch=24)


def eisfalle():
    root, B, rng = begin("b_eisfalle")
    B.cyl(0.85, 0.12, (0, 0, 0.06), "8690B0", sides=8, r=rot(0, 0, 22.5))
    B.cyl(0.75, 0.06, (0, 0, 0.14), "C8F0FF", sides=8, r=rot(0, 0, 22.5))
    for k in range(8):
        a = k * math.tau / 8
        B.cone(0.12, 0.45 + 0.15 * (k % 2), (0.65 * math.cos(a), 0.65 * math.sin(a), 0.32), "8CD8F8", r=rot(0, 0, 0), sides=5)
    B.build("body", root)
    c = Part()
    c.cone(0.22, 0.6, (0, 0, 0.3), "6AC8FF", sides=6)
    c.cone(0.22, 0.25, (0, 0, -0.12), "6AC8FF", r=rot(180, 0, 0), sides=6)
    c.build("pulse_core_glow", root, (0, 0, 0.25))
    finish("b_eisfalle", limit=2500, pitch=30)


# ================================================================= Deko
def bank():
    root, B, rng = begin("b_bank")
    for k in range(3):
        B.box((1.6, 0.16, 0.06), (0, -0.2 + k * 0.18, 0.48), jit(WOOD, rng, 0.08), bevel=0.02, segs=1)
    for k in range(2):
        B.box((1.6, 0.06, 0.14), (0, 0.22, 0.75 + k * 0.2), jit(WOOD, rng, 0.08), r=rot(-10, 0, 0), bevel=0.02, segs=1)
    for sx in (-1, 1):
        B.box((0.08, 0.5, 0.06), (0.7 * sx, 0, 0.42), DK)
        B.box((0.08, 0.08, 0.45), (0.7 * sx, -0.18, 0.22), DK)
        B.box((0.08, 0.08, 0.95), (0.7 * sx, 0.2, 0.47), DK, r=rot(-10, 0, 0))
    B.ball(0.08, (0.4, -0.1, 0.56), "F07AB4", subdiv=1)                                              # vergessene Mütze
    B.build("body", root)
    finish("b_bank", limit=1500, pitch=26)


def gartenzaun():
    root, B, rng = begin("b_gartenzaun")
    for k in range(5):
        x = -0.72 + k * 0.36
        B.box((0.14, 0.06, 0.9), (x, 0, 0.45), "F4F2EA", bevel=0.02, segs=1)
        B.cone(0.1, 0.12, (x, 0, 0.96), "F4F2EA", r=rot(0, 0, 45), sides=4)
    for z in (0.3, 0.7):
        B.box((1.9, 0.05, 0.08), (0, 0.05, z), "E2DED2")
    B.ball(0.12, (0.3, -0.15, 0.1), "8FB02A", subdiv=1, scale=(1.5, 1, 0.7))
    B.ball(0.06, (0.33, -0.2, 0.18), "FFD23E", subdiv=1)
    B.build("body", root)
    finish("b_gartenzaun", limit=1500, pitch=22)


def platte():
    root, B, rng = begin("b_platte")
    for i in range(2):
        for j in range(2):
            B.box((0.9, 0.9, 0.12), (-0.46 + i * 0.92, -0.46 + j * 0.92, 0.06), jit(ST_L, rng, 0.06), bevel=0.03, segs=1)
    B.ball(0.06, (0.0, 0.0, 0.1), "6E9A38", subdiv=1, scale=(1.6, 1, 0.4))
    B.build("body", root)
    finish("b_platte", limit=800, pitch=50, ao=False)


def holzstapel():
    root, B, rng = begin("b_holzstapel")
    for row in range(3):
        n = 4 - row
        for k in range(n):
            x = (k - (n - 1) * 0.5) * 0.36
            B.cyl(0.17, 1.4, (x, 0, 0.17 + row * 0.3), jit(WOOD, rng, 0.1), r=rot(90, 0, 0), sides=8)
            B.cyl(0.13, 1.42, (x, 0, 0.17 + row * 0.3), "E8C48A", r=rot(90, 0, 0), sides=8)
    for sx in (-1, 1):
        B.box((0.08, 0.08, 1.1), (0.78 * sx, 0, 0.55), WOOD_D)
    B.box((0.35, 0.06, 0.08), (0.55, -0.6, 0.12), STEEL, r=rot(0, 0, 30))                            # Axt
    B.box((0.06, 0.6, 0.06), (0.55, -0.35, 0.12), WOOD_D, r=rot(0, 0, 30))
    B.build("body", root)
    finish("b_holzstapel", limit=1500, pitch=26)


def heu():
    root, B, rng = begin("b_heu")
    B.cyl(0.65, 1.0, (0, 0, 0.65), "E8C460", r=rot(90, 0, 0), sides=14)
    for k in (-0.3, 0.3):
        B.cyl(0.66, 0.05, (0, k, 0.65), "C8A040", r=rot(90, 0, 0), sides=14)
    for k in range(6):
        a = k * math.tau / 6
        B.cone(0.05, 0.25, (0.5 * math.cos(a), -0.52, 0.65 + 0.5 * math.sin(a)), "F2D670", r=rot(90, 0, 0), sides=3)
    m = T(0.55, -0.35, 0.8) @ rot(20, 0, -25)                                                       # Mistgabel
    B.cyl(0.03, 1.5, (0, 0, 0), WOOD_D, r=m, sides=5)
    for k in range(3):
        B.cyl(0.015, 0.3, (0, 0, 0), STEEL, r=m @ T(-0.06 + 0.06 * k, 0, 0.85), sides=4)
    B.build("body", root)
    finish("b_heu", limit=1500, pitch=24)


def waesche():
    root, B, rng = begin("b_waesche")
    for x in (-1.6, 1.6):
        B.cyl(0.06, 2.0, (x, 0, 1.0), WOOD_D, sides=6)
        B.box((0.5, 0.06, 0.06), (x, 0, 1.9), WOOD_D)
    B.cyl(0.012, 3.2, (0, 0, 1.85), "F2F2E8", r=rot(0, 90, 0), sides=4)
    B.cyl(0.25, 0.5, (1.3, -0.4, 0.25), "D8C08A", r2=0.3, sides=10)                                 # Wäschekorb
    B.build("body", root)
    L = Part()
    for i, (x, w, h, c) in enumerate(((-1.1, 0.5, 0.7, "E86A6A"), (-0.45, 0.55, 0.45, "F4F6FA"), (0.2, 0.45, 0.8, "5B93EE"), (0.85, 0.5, 0.55, "FFD23E"))):
        L.box((w, 0.03, h), (x, 0, 1.82 - h * 0.5), c, bevel=0.01, segs=1)
        L.box((0.04, 0.05, 0.08), (x - w * 0.3, 0, 1.86), "C8A060")
    L.build("sway_laundry", root)
    finish("b_waesche", limit=1500, pitch=20)


def beet():
    root, B, rng = begin("b_beet")
    plank_frame(B, 3.5, 1.6, 0.3, rng)
    B.box((3.3, 1.4, 0.24), (0, 0, 0.14), "6B4A2A")
    for k in range(4):                                                                               # Kohlköpfe
        B.ball(0.22, (-1.3 + k * 0.4, -0.35, 0.36), "7FB84A", subdiv=2, scale=(1, 1, 0.8))
        B.ball(0.14, (-1.3 + k * 0.4, -0.35, 0.46), "A8D86A", subdiv=1)
    for k in range(4):                                                                               # Möhrengrün
        for j in range(3):
            B.cone(0.05, 0.25, (0.3 + k * 0.3 + j * 0.05, 0.3, 0.42), "5FA83A", r=rot(0, (j - 1) * 20, 0), sides=3)
        B.cone(0.06, 0.08, (0.32 + k * 0.3, 0.27, 0.27), "F28A2A", r=rot(180, 0, 0), sides=5)
    B.ball(0.32, (1.4, -0.3, 0.42), "F28A2A", subdiv=2, scale=(1.1, 1, 0.8))                         # Kürbis
    B.cyl(0.04, 0.12, (1.4, -0.3, 0.72), "4F7A2A", sides=5)
    B.build("body", root)
    finish("b_beet", limit=2000, pitch=30)


def kuebel():
    root, B, rng = begin("b_kuebel")
    B.cyl(0.45, 0.6, (0, 0, 0.3), ST, r2=0.55, sides=10, bevel=0.04, segs=1)
    B.cyl(0.58, 0.08, (0, 0, 0.62), ST_L, sides=10)
    B.ball(0.5, (0, 0, 0.62), "6B4A2A", subdiv=1, scale=(1, 1, 0.15))
    cols = ["F07AB4", "FFD23E", "9A7CF0", "F4F6FA", "FF7043"]
    for i in range(7):
        a = i * math.tau / 7
        x, y = 0.3 * math.cos(a), 0.3 * math.sin(a)
        B.cyl(0.025, 0.35, (x, y, 0.82), "4F7A2A", sides=4)
        B.ball(0.12, (x, y, 1.02), cols[i % 5], subdiv=1, scale=(1, 1, 0.6))
    B.ball(0.25, (0, 0, 0.75), "8FB02A", subdiv=1, scale=(1.5, 1.5, 0.5))
    B.build("body", root)
    finish("b_kuebel", limit=1500, pitch=26)


def vogelhaus():
    root, B, rng = begin("b_vogelhaus")
    B.cyl(0.06, 2.2, (0, 0, 1.1), WOOD_D, sides=6)
    B.box((0.6, 0.5, 0.5), (0, 0, 2.4), "5B93EE", bevel=0.03, segs=1)
    for s in (-1, 1):
        B.box((0.4, 0.62, 0.05), (0.18 * s, 0, 2.78), RED, r=rot(0, 40 * s, 0), bevel=0.01, segs=1)
    B.cyl(0.09, 0.06, (0, -0.25, 2.45), "15161C", r=rot(90, 0, 0), sides=10)
    B.cyl(0.02, 0.18, (0, -0.32, 2.3), WOOD_D, r=rot(90, 0, 0), sides=4)
    B.ball(0.1, (0.15, -0.3, 2.62), "FFD23E", subdiv=1)                                              # Vogel
    B.cone(0.03, 0.06, (0.15, -0.4, 2.62), "F28A2A", r=rot(-90, 0, 0), sides=3)
    B.cyl(0.3, 0.06, (0, 0, 0.03), "8FB02A", sides=10)
    B.build("body", root)
    finish("b_vogelhaus", limit=1500, pitch=20)


def picknick():
    root, B, rng = begin("b_picknick")
    B.box((2.0, 0.9, 0.08), (0, 0, 0.8), jit(WOOD, rng, 0.06), bevel=0.02, segs=1)
    for sx in (-1, 1):
        B.box((0.1, 0.8, 0.76), (0.8 * sx, 0, 0.38), WOOD_D)
        B.box((2.0, 0.3, 0.06), (0, 0.75 * sx, 0.45), jit(WOOD, rng, 0.06), bevel=0.02, segs=1)
        B.box((0.08, 0.1, 0.45), (0.8 * sx, 0.75, 0.22), WOOD_D)
        B.box((0.08, 0.1, 0.45), (0.8 * sx, -0.75, 0.22), WOOD_D)
    B.box((0.9, 0.7, 0.02), (0, 0, 0.85), "E86A6A")                                                  # Tischdecke
    B.cyl(0.12, 0.2, (0.3, 0.1, 0.95), "F4F6FA", sides=8)
    B.ball(0.15, (-0.35, -0.1, 0.92), "F2B24A", subdiv=1, scale=(1, 1, 0.5))
    B.cyl(0.04, 2.3, (0, 0, 1.15), STEEL, sides=6)
    B.build("body", root)
    U = Part()
    U.cyl(1.3, 0.35, (0, 0, 0.0), "FFD23E", r2=0.05, sides=8)
    U.cyl(1.31, 0.08, (0, 0, -0.17), "E85A3A", sides=8)
    U.build("sway_umbrella", root, (0, 0, 2.35))
    finish("b_picknick", limit=2000, pitch=28)


def windrad():
    root, B, rng = begin("b_windrad")
    B.cyl(0.07, 2.6, (0, 0, 1.3), "F4F6FA", sides=6)
    B.cyl(0.4, 0.08, (0, 0, 0.04), ST, sides=8)
    B.box((0.12, 0.3, 0.12), (0, -0.1, 2.6), DK)
    B.box((0.05, 0.6, 0.3), (0, 0.4, 2.6), RED)                                                      # Fahne
    B.build("body", root)
    W = Part()
    cols = ["E85A3A", "FFD23E", "5B93EE", "58E86A"]
    for k in range(4):
        m = rot(0, 0, k * 90)
        W.box((0.2, 0.8, 0.04), (0, 0, 0), cols[k], r=m @ T(0.0, 0.45, 0.0) @ rot(0, 25, 0), bevel=0.01, segs=1)
    W.ball(0.08, (0, 0, 0), GOLD, subdiv=1)
    ob = W.build("spin_wheel", root, (0, -0.28, 2.6))
    ob.rotation_euler = (math.radians(90), 0, 0)
    finish("b_windrad", limit=1500, pitch=16)


def brunnen():
    root, B, rng = begin("b_brunnen")
    block_ring(B, 1.5, 0.0, 0.5, 14, (ST, ST_D, ST_L), rng, depth=0.32)
    B.cyl(1.4, 0.1, (0, 0, 0.05), ST_D, sides=14)
    B.cyl(0.25, 1.1, (0, 0, 0.75), ST, sides=8)
    B.cyl(0.6, 0.12, (0, 0, 1.3), ST_L, sides=10)
    B.cyl(0.15, 0.4, (0, 0, 1.55), ST, sides=8)
    B.ball(0.14, (0, 0, 1.8), GOLD, subdiv=1)
    for k in range(4):
        a = k * math.tau / 4
        B.cyl(0.04, 0.3, (0.55 * math.cos(a), 0.55 * math.sin(a), 1.25), GOLD, r=rot(90, 0, math.degrees(a) + 90), sides=5)
    B.ball(0.12, (1.1, -0.9, 0.12), "6E9A38", subdiv=1, scale=(1.5, 1, 0.5))
    B.build("body", root)
    Wt = Part()
    Wt.cyl(1.28, 0.06, (0, 0, 0.0), "5DB2EA", sides=14)
    Wt.cyl(0.52, 0.04, (0, 0, 0.95), "7CC8F2", sides=10)
    Wt.build("water_glow", root, (0, 0, 0.42))
    J = Part()
    J.cone(0.12, 0.35, (0, 0, 0), "BFE8FF", sides=6)
    J.build("pulse_jet", root, (0, 0, 2.0))
    finish("b_brunnen", limit=2500, pitch=28)


# ================================================================= Boss-Trophäen
def _pedestal(B, title_col):
    B.box((2.4, 2.4, 0.3), (0, 0, 0.15), ST_D, bevel=0.06, segs=1)
    B.box((1.6, 1.6, 0.9), (0, 0, 0.75), ST, bevel=0.08, segs=1)
    B.box((1.8, 1.8, 0.12), (0, 0, 1.24), ST_L, bevel=0.04, segs=1)
    B.box((1.0, 0.05, 0.36), (0, -0.82, 0.75), GOLD_D, bevel=0.02, segs=1)                           # Messingschild
    B.box((0.7, 0.02, 0.08), (0, -0.85, 0.8), title_col)
    B.box((0.5, 0.02, 0.06), (0, -0.85, 0.66), title_col)
    for sx in (-1, 1):
        B.cyl(0.08, 0.4, (1.0 * sx, -1.0, 0.5), GOLD, sides=6)
        B.ball(0.12, (1.0 * sx, -1.0, 0.75), GOLD, subdiv=1)


def _gem(root, z, col):
    g = Part()
    g.ball(0.14, (0, 0, 0), col, subdiv=1)
    g.build("pulse_gem_glow", root, (0, -0.82, z))


def trophy(name, build_piece, gem_col, title_col="3A2A1A"):
    def f():
        root, B, rng = begin(name)
        _pedestal(B, title_col)
        build_piece(B)
        B.build("body", root)
        _gem(root, 1.06, gem_col)
        finish(name, limit=3500, pitch=22)
    return f


def piece_bert(B):                                                                                   # Krone von Dicker Bert
    lathe(B, [(0.55, 1.3, GOLD_D), (0.6, 1.62, GOLD)], sides=12)
    for i in range(6):
        a = math.radians(i * 60)
        B.cone(0.14, 0.42, (0.56 * math.sin(a), 0.56 * math.cos(a), 1.82), GOLD, sides=4)
        B.ball(0.08, (0.6 * math.sin(a), 0.6 * math.cos(a), 1.45), ("E23B3B", "3FA8F5")[i % 2], subdiv=1)
    B.ball(0.35, (0, 0, 1.45), "9DC42C", subdiv=1, scale=(1.4, 1.4, 0.4))                             # Schleimkissen


def piece_moos(B):                                                                                   # Pilzhut unter Glasglocke
    B.cyl(0.08, 0.5, (0, 0, 1.55), "F4E2C0", sides=6)
    lathe(B, [(0.2, 1.75, "A9221F"), (0.75, 1.75, "A9221F"), (0.78, 1.82, "E2372F"), (0.55, 2.05, "E2372F"), (0.0, 2.15, "E2372F")], sides=14)
    for (x, y) in ((0.3, 0.2), (-0.35, -0.1), (0.05, -0.4), (0.0, 0.0)):
        B.ball(0.08, (x, y, 2.04), "FFF6E4", subdiv=1, scale=(1, 1, 0.45))
    B.ball(0.6, (0, 0, 1.32), "5FA83A", subdiv=2, scale=(1, 1, 0.25))                                # Mooskissen
    for k in range(6):                                                                               # goldene Ranken statt Glasglocke
        a = k * math.tau / 6
        capsule(B, (0.7 * math.cos(a), 0.7 * math.sin(a), 1.3), (0.55 * math.cos(a), 0.55 * math.sin(a), 2.3), 0.03, 0.02, GOLD, sides=4)


def piece_rost(B):                                                                                   # Abrissbirne an Kette
    B.box((0.15, 0.15, 1.6), (0.55, 0.3, 2.1), STEEL, bevel=0.03, segs=1)
    B.box((0.7, 0.15, 0.15), (0.25, 0.3, 2.85), STEEL, bevel=0.03, segs=1)
    for k in range(4):
        B.torus(0.07, 0.025, (-0.05, 0.3, 2.7 - k * 0.14), "6A7484", r=rot(0, 90 * (k % 2), 0), seg=6, tseg=3)
    B.ball(0.42, (-0.05, 0.3, 1.75), "4A4E5A", subdiv=2)
    B.ball(0.1, (0.2, 0.0, 1.95), "B5652E", subdiv=1)


def piece_glibber(B):                                                                                # Steuerrad mit Dreispitz
    B.torus(0.55, 0.07, (0, 0, 2.0), "A9622F", r=rot(90, 0, 0), seg=16, tseg=4)
    for k in range(8):
        a = k * math.tau / 8
        B.cyl(0.035, 1.3, (0, 0, 2.0), "7A4522", r=rot(90, 0, 0) @ rot(0, math.degrees(a), 0) @ rot(90, 0, 0), sides=5)
    B.cyl(0.12, 0.2, (0, 0, 2.0), GOLD, r=rot(90, 0, 0), sides=8)
    B.box((0.3, 0.3, 0.6), (0, 0.1, 1.55), "7A4522")
    m = T(0.0, -0.1, 2.75) @ rot(-10, 0, 0)
    for k in range(3):
        B.box((0.7, 0.12, 0.2), (0, 0, 0), "22355F", r=m @ rot(0, 0, k * 60) @ T(0, 0.2, 0), bevel=0.04, segs=1)
    B.ball(0.25, (0, 0, 0), "22355F", r=m, subdiv=1, scale=(1, 1, 0.6))


def piece_schlund(B):                                                                                # Riesenzahn und Ventilrad
    B.cone(0.3, 1.2, (-0.25, 0, 1.9), "F8F4E0", sides=8)
    B.ball(0.3, (-0.25, 0, 1.35), "E8C8C8", subdiv=1, scale=(1, 1, 0.5))
    B.torus(0.35, 0.06, (0.45, -0.1, 1.75), "FF3A2A", r=rot(70, 0, 0), seg=12, tseg=4)
    for k in range(4):
        B.cyl(0.03, 0.7, (0.45, -0.1, 1.75), "8E9AA6", r=rot(70, 0, 0) @ rot(0, k * 45, 0) @ rot(90, 0, 0), sides=4)
    B.ball(0.12, (0.15, -0.3, 1.38), "C8FF3A", subdiv=1)


def piece_frost(B):                                                                                  # Kristallkrone
    lathe(B, [(0.5, 1.3, "5AAEDC"), (0.55, 1.5, "8CD8F8")], sides=10)
    for i in range(7):
        a = math.radians(i * 360 / 7)
        B.cone(0.13, 0.5 + 0.3 * (i % 2), (0.5 * math.sin(a), 0.5 * math.cos(a), 1.75 + 0.15 * (i % 2)), "C8F0FF", sides=5)
    B.cone(0.22, 0.9, (0, 0, 1.95), "6AC8FF", sides=6)


def piece_koenig(B):                                                                                 # glühende Dämonenhörner
    B.ball(0.4, (0, 0, 1.45), "3A2A32", subdiv=1, scale=(1.2, 1, 0.5))
    for s in (-1, 1):
        pts = [(0.3 * s, 0, 1.5), (0.7 * s, 0.05, 1.85), (0.85 * s, 0.0, 2.35), (0.7 * s, -0.1, 2.75)]
        for i in range(len(pts) - 1):
            capsule(B, pts[i], pts[i + 1], 0.18 - 0.05 * i, 0.14 - 0.05 * i, ("F2E2C0", "C8B490", "FF7A1E")[i], sides=7)
    B.ball(0.16, (0, -0.3, 1.55), "FFD24A", subdiv=1)


# ================================================================= Trümmer je Größe
def rubble(n):
    def f():
        name = "b_rubble_%d" % n
        root, B, rng = begin(name)
        half = n * 2.0 * 0.5 - 0.15
        cnt = 6 + n * 5
        cols = (ST, ST_D, ST_L, WOOD, WOOD_D, "6A6E80", "8A5A3A")
        B.ball(half * 0.9, (0, 0, 0.0), "6E6A66", subdiv=2, scale=(1, 1, 0.18))                      # Schutthaufen
        for i in range(cnt):
            x, y = rng.uniform(-half, half) * 0.8, rng.uniform(-half, half) * 0.8
            s = rng.uniform(0.25, 0.55) * (0.8 + 0.12 * n)
            B.box((s, s * rng.uniform(0.6, 1.2), s * rng.uniform(0.35, 0.8)), (x, y, s * 0.25 + rng.uniform(0.0, 0.25 * n * 0.3)), jit(rng.choice(cols), rng, 0.08),
                  r=rot(rng.uniform(-25, 25), rng.uniform(-25, 25), rng.uniform(0, 360)), bevel=min(0.06, s * 0.15), segs=1)
        for i in range(n + 1):                                                                       # Balken ragen heraus
            x, y = rng.uniform(-half, half) * 0.6, rng.uniform(-half, half) * 0.6
            L = rng.uniform(0.8, 1.2) * (0.8 + 0.4 * n)
            B.box((0.18, 0.18, L), (x, y, L * 0.35), WOOD_D, r=rot(rng.uniform(30, 60), 0, rng.uniform(0, 360)), bevel=0.03, segs=1)
        for i in range(n):                                                                           # Ruß und ein verbogenes Blech
            soot_flat(B, (rng.uniform(-half, half) * 0.7, rng.uniform(-half, half) * 0.7, 0.03), 0.4 * n, 0.3 * n, yaw=rng.uniform(0, 180))
            B.box((0.8, 0.05, 0.5), (rng.uniform(-half, half) * 0.5, rng.uniform(-half, half) * 0.5, 0.35), BLUE_D, r=rot(rng.uniform(-40, 40), 30, rng.uniform(0, 360)), bevel=0.0)
        B.build("body", root)
        sm = empty("fx_smoke_dmg", root, (0, 0, 0.6))
        finish(name, limit=1800 + 600 * n, pitch=34, hide=())
    return f


# ================================================================= Bauteile und Effekt-Modelle
def build_parts():
    root, B, rng = begin("fx_build_parts")
    items = []
    p = Part(); p.box((1.0, 0.22, 0.06), (0, 0, 0), WOOD, bevel=0.02, segs=1); items.append(p)                     # Brett
    p = Part(); p.box((0.36, 0.18, 0.16), (0, 0, 0), "C8584A", bevel=0.02, segs=1); items.append(p)                # Ziegel
    p = Part(); p.box((0.16, 0.16, 1.1), (0, 0, 0), WOOD_D, bevel=0.03, segs=1); items.append(p)                   # Balken
    p = Part(); p.box((0.7, 0.04, 0.5), (0, 0, 0), BLUE, bevel=0.0); items.append(p)                               # Blech
    p = Part(); p.cyl(0.08, 0.9, (0, 0, 0), STEEL, r=rot(0, 90, 0), sides=8); items.append(p)                       # Rohr
    p = Part(); p.box((0.4, 0.4, 0.4), (0, 0, 0), WOOD_L, bevel=0.03, segs=1); p.box((0.42, 0.06, 0.06), (0, -0.2, 0), WOOD_D); items.append(p)   # Kiste
    for i, q in enumerate(items):
        q.build("part_%d" % (i + 1), root, (i * 1.3 - 3.2, 0, 0.6))
    finish("fx_build_parts", limit=1500, pitch=20, ao=False)


def elite_crown():
    root, B, rng = begin("fx_elite_crown")
    lathe(B, [(0.22, 0.0, GOLD_D), (0.25, 0.14, GOLD)], sides=10)
    for i in range(5):
        a = math.radians(i * 72)
        B.cone(0.07, 0.2, (0.23 * math.sin(a), 0.23 * math.cos(a), 0.24), GOLD, sides=4)
        B.ball(0.04, (0.25 * math.sin(a), 0.25 * math.cos(a), 0.07), ("E23B3B", "3FA8F5")[i % 2], subdiv=1)
    B.build("body", root)
    finish("fx_elite_crown", limit=600, pitch=30, ao=False)


def elite_aura():
    root, B, rng = begin("fx_elite_aura")
    B.torus(1.0, 0.06, (0, 0, 0.02), GOLD, seg=24, tseg=3)
    for i in range(8):
        a = math.radians(i * 45)
        B.cone(0.1, 0.25, (1.05 * math.cos(a), 1.05 * math.sin(a), 0.02), GOLD, r=rot(0, 90, i * 45), sides=3)
    B.build("body", root)
    finish("fx_elite_aura", limit=600, pitch=60, ao=False, do_icon=False)


def weakspot():
    root, B, rng = begin("fx_weakspot")
    B.torus(0.5, 0.07, (0, 0, 0), "FFD24A", r=rot(90, 0, 0), seg=20, tseg=4)
    B.torus(0.25, 0.05, (0, 0, 0), "FF4A3A", r=rot(90, 0, 0), seg=16, tseg=4)
    for i in range(4):
        B.box((0.08, 0.06, 0.3), (0, 0, 0), "FFD24A", r=rot(0, i * 90, 0) @ T(0, 0, 0.62))
    B.ball(0.1, (0, 0, 0), "FF4A3A", subdiv=1)
    B.build("body_glow", root)
    finish("fx_weakspot", limit=600, pitch=10, ao=False, do_icon=False)


def boss_rage():
    root, B, rng = begin("fx_boss_rage")
    B.torus(1.0, 0.08, (0, 0, 0.03), "FF3A2A", seg=28, tseg=3)
    for i in range(12):
        a = math.radians(i * 30)
        B.cone(0.12, 0.45, (1.0 * math.cos(a), 1.0 * math.sin(a), 0.2), "FF7A1E", r=rot(0, -25, i * 30), sides=4)
    B.build("body_glow", root)
    finish("fx_boss_rage", limit=800, pitch=50, ao=False, do_icon=False)


TABLE = {"b_teer": teer, "b_feder": feder, "b_koeder": koeder, "b_zaun": zaun, "b_eisfalle": eisfalle,
         "b_bank": bank, "b_gartenzaun": gartenzaun, "b_platte": platte, "b_holzstapel": holzstapel, "b_heu": heu, "b_waesche": waesche,
         "b_beet": beet, "b_kuebel": kuebel, "b_vogelhaus": vogelhaus, "b_picknick": picknick, "b_windrad": windrad, "b_brunnen": brunnen,
         "b_trophy_bert": trophy("b_trophy_bert", piece_bert, "FFD24A"), "b_trophy_moos": trophy("b_trophy_moos", piece_moos, "5AF0A0"),
         "b_trophy_rost": trophy("b_trophy_rost", piece_rost, "FF7A1E"), "b_trophy_glibber": trophy("b_trophy_glibber", piece_glibber, "7AF0FF"),
         "b_trophy_schlund": trophy("b_trophy_schlund", piece_schlund, "C8FF3A"), "b_trophy_frost": trophy("b_trophy_frost", piece_frost, "9AF0FF"),
         "b_trophy_koenig": trophy("b_trophy_koenig", piece_koenig, "FF4A3A"),
         "b_rubble_1": rubble(1), "b_rubble_2": rubble(2), "b_rubble_3": rubble(3), "b_rubble_4": rubble(4),
         "fx_build_parts": build_parts, "fx_elite_crown": elite_crown, "fx_elite_aura": elite_aura, "fx_weakspot": weakspot, "fx_boss_rage": boss_rage}

if __name__ == "__main__":
    run(TABLE, sys.argv)
