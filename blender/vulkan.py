"""Paket Z – Vulkaninsel (Gebiet 8): alle festen Modelle der Zone.

Aufruf:  python3 blender/vulkan.py [namen…]     (ohne Namen: alle; "list" zeigt die Namen)

| Name | Bedeutung | Objekte mit Wirkung |
|---|---|---|
| p_tree_lava_1, _2 | verkohlter Baum mit Glutrissen (Kulisse, ein Objekt body) | – |
| p_rock_lava_1 … _3 | Basaltfelsen mit Obsidiankanten und Glutfugen (Kulisse) | – |
| p_vk_ashgrass, p_vk_firebloom, p_vk_fumarole | Aschegras, Feuerblume, Schwefel-Fumarole (Kulissen) | – |
| p_vk_spring | kühle Quelle (Hitze sinkt dort) | water_glow, Leerobjekt fx_steam1 |
| n_obsidian_1 … _3 | Obsidianbrocken in drei Größen (voll → fast abgebaut), gibt Stein | obsidian_glow |
| n_sulfur | Schwefelquelle, gibt Treibstoff | sulfur_glow, Leerobjekt fx_steam1 |
| n_src_vulkan | Glutgeode (gebietseigene Quelle, Glutzange nötig) | pulse_core_glow |
| n_lavabomb | Lavabombe (Rest eines Einschlags beim Ausbruch, abbaubar) | crack_glow |
| lm_vulkan | Wahrzeichen „Feuerschlund“ (kleiner Vulkan mit Lavasee) | lava_glow, pulse_core_glow, Leerobjekte fx_smoke1, fx_smoke2 |
| x_barrier_vulkan | Sperre: erstarrter Lavastrom mit glühenden Spalten (8 m) | crack_glow, pulse_bubble1 … 3 |
| o_special_vulkan | Spezialbau „Obsidianschmiede“ (5 Stufen: lv2_annex, lv3_upper, lv4_armor, lv5_gold) | win_glow, pulse_forge_glow, spin_wheel, sway_sign, Leerobjekte fx_smoke, door, bubble |
| tool_tongs | Werkzeug Glutzange (nur Symbol) | – |
| area_vulkan | Schaubild für die Weltkarte (nur Symbol) | – |
| b_trophy_brodel | Trophäe: Obsidiankrone des Magmafürsten | pulse_gem_glow |
"""
import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from exp_common import *
from exp_areas import clod

BAS, BAS_D, BAS_L = "3E383C", "2A2529", "5A5258"
OBS, OBS_D, OBS_L = "262234", "17141F", "6A6488"
LAVA, LAVA_D, LAVA_L = "FF6A1A", "D23A16", "FFC23A"
ASH, ASH_D = "8E8682", "6A6260"
SULF, SULF_D = "F2D43A", "C8A02A"
CHAR = "2E2622"


def lava_rock(p, size, loc, rng, col=BAS, k=0.22):
    rockc(p, size, loc, col, rng, k)


def obsidian_shard(p, m, r, h, col=OBS):
    """Glänzende Obsidiansäule: sechseckig mit schräger Spitze und hellem Glanzstreifen."""
    p.cyl(r, h * 0.72, (0, 0, 0), col, r=m @ T(0, 0, h * 0.36), r2=r * 0.86, sides=6)
    p.cone(r * 0.86, h * 0.36, (0, 0, 0), shade(col, 1.25), r=m @ T(0, 0, h * 0.72 + h * 0.18), sides=6)
    p.box((r * 0.18, r * 0.12, h * 0.55), (0, 0, 0), OBS_L, r=m @ T(r * 0.55, -r * 0.55, h * 0.4) @ rot(0, 0, 45))


def glow_crack(G, a, b, w=0.07, col=LAVA):
    beam(G, a, b, w, col)


# ================================================================== Kulissen (ein Objekt body)
def _one(name, p, yaw=-30, pitch=18):
    root = empty(name)
    p.build("body", root)
    fin(name, yaw=yaw, pitch=pitch)


def tree_lava(name, seed):
    reset()
    rng = random.Random(seed)
    p = Part()
    h = 3.6 if seed == 1 else 2.8
    limb(p, (0, 0, 0), (0.1, 0.05, h), 0.32, 0.12, CHAR, 7)                      # Stamm
    for (z, ang, ln) in ((h * 0.45, 30, 1.3), (h * 0.62, 160, 1.1), (h * 0.8, 260, 0.9), (h * 0.55, 330, 0.8)):
        a = math.radians(ang + seed * 20)
        tip = (math.cos(a) * ln, math.sin(a) * ln, z + ln * 0.55)
        limb(p, (0.05, 0.02, z), tip, 0.11, 0.04, CHAR, 5)
        limb(p, tip, (tip[0] * 1.3, tip[1] * 1.3, tip[2] + 0.35), 0.04, 0.015, "1E1814", 4)
    for (z, a) in ((0.6, 0), (1.3, 120), (2.0, 240)):                             # Glutrisse in der Rinde
        ra = math.radians(a + seed * 33)
        p.box((0.06, 0.05, 0.5), (math.cos(ra) * 0.26, math.sin(ra) * 0.26, z), LAVA, r=rot(0, 8, a + seed * 33))
    for i in range(4):                                                            # Wurzeln und Asche
        a = math.radians(i * 90 + 20)
        limb(p, (0, 0, 0.25), (math.cos(a) * 0.7, math.sin(a) * 0.7, 0.0), 0.12, 0.05, CHAR, 5)
    p.cyl(0.9, 0.08, (0, 0, 0.03), ASH, sides=9)
    lava_rock(p, (0.5, 0.45, 0.3), (0.6, -0.5, 0.12), rng, BAS_L)
    _one(name, p, pitch=14)


def rock_lava(name, seed):
    reset()
    rng = random.Random(seed)
    p = Part()
    lay = [((1.9, 1.6, 1.3), (0, 0, 0.6)), ((1.2, 1.1, 0.95), (0.8, -0.35, 0.42)), ((1.0, 0.9, 0.8), (-0.75, 0.45, 0.35)), ((1.0, 0.95, 0.7), (0.1, 0.1, 1.2))]
    if seed == 2:
        lay = [((2.1, 1.5, 1.0), (0, 0, 0.45)), ((1.3, 1.2, 0.9), (-0.3, 0.1, 1.0)), ((0.9, 0.8, 0.6), (0.85, -0.5, 0.25))]
    if seed == 3:
        lay = [((1.5, 1.7, 1.7), (0, 0.1, 0.78)), ((1.0, 1.0, 0.8), (-0.8, -0.3, 0.38)), ((0.7, 0.7, 0.5), (0.8, -0.6, 0.2))]
    for i, (size, loc) in enumerate(lay):
        lava_rock(p, size, loc, rng, (BAS, BAS_D, BAS_L, BAS)[i % 4])
    top = max(l[1][2] + l[0][2] * 0.5 for l in lay)
    for k in range(3 if seed != 2 else 2):                                        # Obsidiankanten
        a = math.radians(k * 120 + seed * 40)
        obsidian_shard(p, T(math.cos(a) * 0.65, math.sin(a) * 0.55, 0.2) @ rot(18 * math.cos(a), 18 * math.sin(a), k * 30), 0.2, 0.9 + 0.3 * (k % 2))
    for k in range(3):                                                            # Glutfugen
        a = math.radians(k * 110 + seed * 25)
        x, y = math.cos(a) * 0.8, math.sin(a) * 0.7
        p.box((0.6, 0.06, 0.07), (x, y - 0.05, top * 0.45 + k * 0.15), LAVA, r=rot(0, 20 - k * 15, k * 60 + seed * 25))
    p.cyl(1.4, 0.06, (0, 0, 0.02), ASH_D, sides=10)
    _one(name, p)


@model("p_vk_ashgrass")
def ashgrass(name):
    reset()
    p = Part()
    for (x, y, n, k) in ((0, 0, 7, 1.0), (0.5, 0.3, 5, 0.8), (-0.45, 0.25, 5, 0.75)):
        tuft(p, x, y, 0.0, n, k, int(x * 10 + 3), cols=("8E8682", "A49C96", "6E6662"))
    for (x, y) in ((0.05, 0.02), (0.5, 0.3), (-0.43, 0.27), (0.2, -0.2)):         # Glutspitzen
        p.ball(0.05, (x, y, 0.52), LAVA_L, subdiv=1)
    _one(name, p, pitch=24)


@model("p_vk_firebloom")
def firebloom(name):
    reset()
    rng = random.Random(4)
    p = Part()
    for i in range(4):
        a = math.radians(i * 90 + 15)
        x, y = math.cos(a) * 0.3, math.sin(a) * 0.3
        h = rng.uniform(0.4, 0.65)
        p.cyl(0.03, h, (x, y, h * 0.5), "4A3A2A", sides=4)
        for k in range(5):                                                        # Blütenblätter wie Flammen
            b = math.radians(k * 72 + i * 20)
            p.cone(0.07, 0.24, (0, 0, 0), (LAVA, LAVA_L, "E8401A")[k % 3], r=T(x, y, h) @ rot(0, 0, math.degrees(b)) @ rot(0, 50, 0) @ T(0, 0, 0.12), sides=4)
        p.ball(0.06, (x, y, h + 0.02), "FFE070", subdiv=1)
    p.cyl(0.5, 0.06, (0, 0, 0.03), ASH, sides=8)
    _one(name, p, pitch=26)


@model("p_vk_fumarole")
def fumarole(name):
    reset()
    rng = random.Random(6)
    p = Part()
    p.cyl(0.95, 0.5, (0, 0, 0.25), BAS, r2=0.45, sides=10)
    p.cyl(0.48, 0.12, (0, 0, 0.52), SULF, r2=0.38, sides=10)
    p.cyl(0.32, 0.14, (0, 0, 0.55), "2A2220", sides=8)
    for i in range(6):                                                            # gelbe Krusten und Brocken
        a = math.radians(i * 60 + 10)
        p.ball(0.16, (math.cos(a) * 0.62, math.sin(a) * 0.62, 0.3), (SULF, SULF_D)[i % 2], scale=(1, 1, 0.55), subdiv=1)
    for i in range(3):
        a = math.radians(i * 120 + 40)
        lava_rock(p, (0.4, 0.35, 0.3), (math.cos(a) * 1.05, math.sin(a) * 1.05, 0.12), rng, BAS_D)
    _one(name, p, pitch=24)


@model("p_vk_spring")
def spring(name):
    """Kühle Quelle: Steinkranz mit blauem Wasser (Hitze sinkt hier)."""
    root, B, G = start(name)
    rng = random.Random(12)
    for k in range(10):
        a = math.radians(k * 36)
        lava_rock(B, (0.62, 0.5, 0.42), (math.cos(a) * 1.35, math.sin(a) * 1.35, 0.18), rng, (BAS_L, BAS, "6E6A78")[k % 3])
    B.cyl(1.25, 0.12, (0, 0, 0.04), "2A3A48", sides=14)
    for (x, y) in ((1.6, -0.9), (-1.5, 1.0), (0.3, 1.7)):                          # Farn und Moos (es ist kühl hier)
        tuft(B, x, y, 0.1, 6, 0.9, int(x * 7 + 11), cols=("4F9A5A", "6FBF6A", "3E7A48"))
    B.box((0.5, 0.08, 0.7), (0.0, 1.55, 0.55), "8A6A4A", r=rot(-10, 0, 0), bevel=0.03, segs=1)    # Schild mit Tropfen
    B.ball(0.12, (0.0, 1.5, 0.62), "5DB2EA", scale=(1, 0.4, 1.3), subdiv=1)
    B.build("body", root)
    G.cyl(1.15, 0.08, (0, 0, 0.14), "5DC8F5", sides=14)
    G.cyl(0.55, 0.09, (0.15, -0.1, 0.15), "B8EEFF", sides=10)
    G.build("water_glow", root)
    empty("fx_steam1", root, (0, 0, 0.4))
    fin(name, yaw=-30, pitch=26)


# ================================================================== Quellen
def obsidian_node(name, stage):
    root, B, G = start(name)
    rng = random.Random(90 + stage)
    k = (1.0, 0.72, 0.45)[stage - 1]
    for i in range((6, 5, 4)[stage - 1]):                                         # Basaltsockel
        a = math.radians(i * 60 + 10)
        s = rng.uniform(0.45, 0.7) * (0.6 + 0.4 * k)
        lava_rock(B, (s, s * 0.9, s * 0.6), (math.cos(a) * 0.62 * k, math.sin(a) * 0.62 * k, s * 0.22), rng, (BAS, BAS_D, BAS_L)[i % 3])
    full = [(0.0, 0.0, 0.36, 1.7, 0, 0), (0.45, -0.2, 0.26, 1.2, 18, 15), (-0.45, -0.1, 0.27, 1.3, -16, -10), (0.15, 0.48, 0.24, 1.05, 8, -22),
            (-0.25, -0.5, 0.2, 0.8, -10, 26), (0.62, 0.32, 0.18, 0.7, 26, -12)]
    lst = full if stage == 1 else (full[:4] if stage == 2 else full[:2])
    for i, (x, y, r, h, ry, rx) in enumerate(lst):
        hh = h * (1.0 if stage == 1 else (0.7 if stage == 2 else 0.5))
        obsidian_shard(B, T(x * k, y * k, 0.1 * k) @ rot(rx, ry, i * 25), r, hh, (OBS, OBS_D, "322C44")[i % 3])
    for i in range(5 - stage):                                                    # glühende Fugen am Fuß
        a = rng.uniform(0, 6.28)
        G.box((0.4 * k + 0.1, 0.06, 0.06), (math.cos(a) * 0.5 * k, math.sin(a) * 0.5 * k, 0.12), LAVA, r=rot(0, 0, math.degrees(a) + 90))
    for i in range(1 + (3 - stage) * 2):                                          # Splitter am Boden
        a = rng.uniform(0, 6.28)
        rr = 0.95 * k + 0.2
        B.cyl(0.07, 0.22, (math.cos(a) * rr, math.sin(a) * rr, 0.05), OBS, r=rot(80, 0, rng.uniform(0, 180)), r2=0.01, sides=5)
    B.build("body", root)
    G.build("obsidian_glow", root)
    fin(name, yaw=-30, pitch=20)


for _i in (1, 2, 3):
    REG["n_obsidian_%d" % _i] = (lambda i=_i: obsidian_node("n_obsidian_%d" % i, i))


@model("n_sulfur")
def sulfur(name):
    """Schwefelquelle: gelbe Kruste um einen dampfenden Spalt, Schwefelbrocken in Kisten."""
    root, B, G = start(name)
    rng = random.Random(21)
    B.cyl(1.1, 0.3, (0, 0, 0.15), BAS, r2=0.85, sides=12)
    for i in range(9):
        a = math.radians(i * 40)
        B.ball(0.26, (math.cos(a) * 0.75, math.sin(a) * 0.75, 0.32), (SULF, SULF_D, "E8C030")[i % 3], scale=(1, 1, 0.5), subdiv=1)
    for i in range(4):
        a = math.radians(i * 90 + 30)
        lava_rock(B, (0.35, 0.3, 0.3), (math.cos(a) * 0.4, math.sin(a) * 0.4, 0.45), rng, SULF)
    crate(B, (1.1, -0.5, 0.0), 0.6, WOOD, 12)                                      # Kiste mit Brocken
    for (x, y) in ((1.0, -0.6), (1.2, -0.4), (1.1, -0.5)):
        B.ball(0.14, (x, y, 0.66), SULF, subdiv=1)
    B.build("body", root)
    G.cyl(0.38, 0.06, (0, 0, 0.33), "FFE24A", sides=10)
    G.build("sulfur_glow", root)
    empty("fx_steam1", root, (0, 0, 0.6))
    fin(name, yaw=-30, pitch=22)


@model("n_src_vulkan")
def src_vulkan(name):
    """Glutgeode: aufgebrochene Basaltkugel, die beiden Hälften liegen auseinander, dazwischen glühende Kristalle."""
    root, B, G = start(name)
    rng = random.Random(31)
    for s in (-1, 1):                                                           # zwei Schalenhälften, innen dunkelrot
        B.ball(1.0, (0.62 * s, 0.1, 0.5), BAS, r=rot(0, 0, 0), scale=(0.42, 0.75, 0.6), subdiv=2)
        B.ball(1.0, (0.36 * s, 0.05, 0.52), "4A1E16", scale=(0.12, 0.62, 0.48), subdiv=2)
        for k in range(4):
            B.cone(0.1, 0.3, (0.4 * s, -0.55 + k * 0.35, 0.95 - abs(k - 1.5) * 0.12), BAS_L, r=rot(0, -40 * s, 0), sides=4)
    B.ball(0.5, (0, 0.1, 0.12), "3A1A14", scale=(1.0, 1.2, 0.35), subdiv=2)       # Glutbett
    for i in range(3):
        a = math.radians(i * 120 + 60)
        lava_rock(B, (0.45, 0.4, 0.3), (math.cos(a) * 1.15, math.sin(a) * 1.15, 0.12), rng, BAS_D)
    B.build("body", root)
    c = Part()
    for i, (x, y, h, rx, ry) in enumerate(((0.0, 0.0, 0.75, 0, 0), (0.18, -0.25, 0.55, 20, 18), (-0.2, -0.2, 0.6, 18, -20), (0.1, 0.3, 0.5, -18, 10),
                                         (-0.15, 0.25, 0.45, -16, -14), (0.0, -0.45, 0.4, 30, 0))):
        c.cyl(0.11, h * 0.75, (0, 0, 0), (LAVA_L, LAVA, "FF8A2A")[i % 3], r=T(x, y, 0) @ rot(rx, ry, i * 30) @ T(0, 0, h * 0.37), r2=0.09, sides=6)
        c.cone(0.09, h * 0.3, (0, 0, 0), LAVA_L, r=T(x, y, 0) @ rot(rx, ry, i * 30) @ T(0, 0, h * 0.75 + h * 0.15), sides=6)
    c.build("pulse_core_glow", root, (0, 0, 0.15))
    fin(name, yaw=-30, pitch=24)


@model("n_lavabomb")
def lavabomb(name):
    """Lavabombe: noch warmer Brocken im kleinen Krater (Fund beim Ausbruch)."""
    root, B, G = start(name)
    rng = random.Random(41)
    B.cyl(1.0, 0.1, (0, 0, 0.03), ASH_D, sides=12)
    for i in range(8):
        a = math.radians(i * 45)
        lava_rock(B, (0.35, 0.3, 0.22), (math.cos(a) * 0.95, math.sin(a) * 0.95, 0.1), rng, (BAS, BAS_L)[i % 2])
    B.ball(0.62, (0, 0, 0.5), BAS_D, scale=(1, 0.9, 0.85), subdiv=2)
    for k in range(3):
        obsidian_shard(B, T(0.25 * math.cos(k * 2.1), 0.25 * math.sin(k * 2.1), 0.6) @ rot(30 * math.cos(k * 2.1), 30 * math.sin(k * 2.1), 0), 0.12, 0.45)
    B.build("body", root)
    for k in range(4):
        a = k * 1.57 + 0.3
        glow_crack(G, (math.cos(a) * 0.15, -0.5 + math.sin(a) * 0.05, 0.75), (math.cos(a) * 0.5, -0.35, 0.35), 0.06)
    G.build("crack_glow", root)
    fin(name, yaw=-30, pitch=20)


# ================================================================== Wahrzeichen
@model("lm_vulkan")
def lm_vulkan(name):
    """Feuerschlund: kleiner Vulkan mit Lavasee im Krater, Lavafall vorn, Steinwächter am Fuß."""
    root, B, G = start(name)
    rng = random.Random(51)
    B.cyl(4.2, 1.8, (0, 0, 0.9), BAS_D, r2=3.2, sides=16)                          # Berg in drei Ringen
    B.cyl(3.2, 2.4, (0, 0, 3.0), BAS, r2=2.2, sides=14)
    B.cyl(2.2, 1.8, (0, 0, 5.1), BAS_L, r2=1.7, sides=12)
    B.torus(1.6, 0.35, (0, 0, 6.0), BAS_D, seg=14, tseg=5)                          # Kraterrand
    for k in range(12):                                                           # Felsrippen
        a = math.radians(k * 30 + 8)
        lava_rock(B, (0.9, 0.7, 2.2), (math.cos(a) * 3.3, math.sin(a) * 3.3, 1.0), rng, (BAS, BAS_D, BAS_L)[k % 3])
    for k in range(5):                                                            # Obsidianzacken
        a = math.radians(40 + k * 70)
        obsidian_shard(B, T(math.cos(a) * 2.6, math.sin(a) * 2.6, 2.2) @ rot(25 * math.cos(a), 25 * math.sin(a), 0), 0.35, 1.6)
    for s in (-1, 1):                                                             # Steinwächter mit Glutaugen
        x = 3.7 * s
        B.box((0.9, 0.8, 1.6), (x, -2.6, 0.8), BAS_L, bevel=0.15, segs=1)
        B.box((0.7, 0.7, 0.6), (x, -2.65, 1.9), BAS, bevel=0.12, segs=1)
        G.box((0.14, 0.05, 0.08), (x - 0.15, -3.02, 1.95), LAVA_L)
        G.box((0.14, 0.05, 0.08), (x + 0.15, -3.02, 1.95), LAVA_L)
    B.build("body", root)
    L = Part()
    L.cyl(1.35, 0.15, (0, 0, 6.05), LAVA, sides=14)                              # Lavasee
    L.cyl(0.7, 0.16, (0.2, -0.1, 6.07), LAVA_L, sides=10)
    pts = [(0.0, -1.5, 6.0), (0.2, -2.4, 4.6), (-0.2, -3.2, 3.0), (0.3, -3.9, 1.2), (0.0, -4.5, 0.1)]
    for i in range(len(pts) - 1):                                                 # Lavafall nach vorn
        beam(L, pts[i], pts[i + 1], 0.75 - 0.08 * i, (LAVA, "FF8A2A")[i % 2], d=0.25)
    L.cyl(1.4, 0.08, (0.0, -4.7, 0.04), LAVA, r=S(1.0, 0.65, 1.0), sides=12)
    L.build("lava_glow", root)
    c = Part()
    c.ball(0.6, (0, 0, 0), LAVA_L, scale=(1, 1, 0.6), subdiv=2)
    c.build("pulse_core_glow", root, (0, 0, 6.25))
    empty("fx_smoke1", root, (0, 0, 6.6))
    empty("fx_smoke2", root, (0.6, 0.3, 6.4))
    fin(name, yaw=-30, pitch=16)


# ================================================================== Sperre
@model("x_barrier_vulkan")
def b_vulkan(name):
    """Erstarrter Lavastrom: wulstige Basaltwand mit glühenden Spalten und Lavablasen (8 m breit)."""
    root, B, G = start(name)
    rng = random.Random(61)
    B.box((7.4, 1.6, 1.6), (0, 0, 0.8), BAS_D, bevel=0.4, segs=1)
    for i in range(7):                                                            # Wülste aus Pahoehoe-Lava
        x = -3.2 + i * 1.07
        z = rng.uniform(1.3, 1.9) + (0.3 if i % 2 else 0)
        B.ball(1.0, (x, rng.uniform(-0.2, 0.2), z), (BAS, BAS_L, BAS_D)[i % 3], scale=(0.75, 0.9, 0.7 + 0.15 * (i % 2)), subdiv=2)
        B.ball(1.0, (x + 0.4, rng.choice((-1, 1)) * 0.95, 0.4), (BAS_D, BAS)[i % 2], scale=(0.55, 0.45, 0.4), subdiv=1)
    for i in range(4):
        a = -2.6 + i * 1.7
        obsidian_shard(B, T(a, -0.5, 1.6) @ rot(-15, 10 * (i % 2 * 2 - 1), 0), 0.22, 1.1)
    for x in (-3.4, 3.4):                                                         # Warnstangen
        B.cyl(0.05, 1.8, (x, -1.25, 0.9), "D9D2C0", sides=6)
        B.box((0.5, 0.04, 0.3), (x, -1.27, 1.65), RED, bevel=0.02, segs=1)
    B.build("body", root)
    for i in range(6):                                                            # glühende Spalten
        x = -3.0 + i * 1.2
        glow_crack(G, (x, -0.85, 0.3), (x + 0.3, -0.92, 1.3 + 0.3 * (i % 2)), 0.1)
        glow_crack(G, (x + 0.3, -0.92, 1.3 + 0.3 * (i % 2)), (x + 0.1, -0.7, 2.0), 0.08)
    G.cyl(1.0, 0.04, (0, -1.25, 0.03), LAVA_D, r=S(3.2, 0.25, 1), sides=12)
    G.build("crack_glow", root)
    for i, (x, y, z, r) in enumerate(((-2.4, -0.6, 2.4, 0.28), (0.4, -0.7, 2.6, 0.34), (2.6, -0.6, 2.35, 0.26))):
        p = Part()
        p.ball(r, (0, 0, 0), LAVA, subdiv=2)
        p.ball(r * 0.35, (-r * 0.35, -r * 0.6, r * 0.4), LAVA_L, subdiv=1)
        p.build("pulse_bubble%d" % (i + 1), root, (x, y, z))
    fin(name, yaw=-28, pitch=22)


# ================================================================== Spezialbau der Außenbasis
@model("o_special_vulkan")
def sp_vulkan(name):
    """Obsidianschmiede: Steinesse mit Glut, Amboss, Wasserrad zum Abkühlen; Stufen bis zur goldenen Esse."""
    root, B, G = start(name)
    X2, X3, X4, X5, G3, G2 = Part(), Part(), Part(), Part(), Part(), Part()
    base(B, 3.3, 3.9, BAS_D, 0.16)
    B.box((3.0, 3.6, 0.03), (0, 0, 0.165), "4A4248")
    for i in range(10):                                                           # Warnstreifen vorn
        B.box((0.3, 0.14, 0.03), (-1.35 + i * 0.3, -1.82, 0.17), YEL if i % 2 == 0 else "23262E")
    # Schmiedehaus hinten links: Basaltquader, Holzdach
    hx, hy = -0.55, 0.8
    B.box((2.0, 2.0, 1.7), (hx, hy, 1.0), BAS_L, bevel=0.12, segs=1)
    for z in (0.5, 1.0, 1.5):
        B.box((2.04, 2.04, 0.06), (hx, hy, z), BAS, bevel=0.01, segs=1)
    gable(B, (hx, hy, 1.85), 2.4, 2.4, 0.9, "8A4A2A", over=0.25, thick=0.18)
    door(B, (hx + 0.45, hy - 1.0, 0.2), 0.75, 1.25, WOOD_D, DK, GOLD)
    G.box((0.6, 0.08, 0.5), (hx - 0.45, hy - 0.99, 1.15), "FFB040", bevel=0.03, segs=1)     # Fenster mit Glutlicht
    B.box((0.72, 0.06, 0.6), (hx - 0.45, hy - 0.97, 1.15), DK, bevel=0.03, segs=1)
    # Esse vorn rechts: Steinkegel mit Glutmaul und Kamin
    ex_, ey = 0.85, -0.6
    B.cyl(0.75, 1.1, (ex_, ey, 0.72), BAS, r2=0.6, sides=10, bevel=0.06, segs=1)
    B.box((0.55, 0.2, 0.45), (ex_, ey - 0.62, 0.7), DK, bevel=0.04, segs=1)
    B.cyl(0.25, 1.3, (ex_ + 0.1, ey + 0.15, 1.9), BAS_D, r2=0.2, sides=8)
    B.cyl(0.3, 0.12, (ex_ + 0.1, ey + 0.15, 2.58), "5A5258", sides=8)
    f = Part()
    f.ball(0.26, (0, 0, 0), LAVA, scale=(1.0, 0.6, 0.7), subdiv=2)
    f.ball(0.14, (0.05, -0.1, 0.05), LAVA_L, subdiv=1)
    f.build("pulse_forge_glow", root, (ex_, ey - 0.6, 0.72))
    empty("fx_smoke", root, (ex_ + 0.1, ey + 0.15, 2.7))
    # Amboss mit glühendem Obsidian-Barren
    B.box((0.35, 0.3, 0.4), (-0.3, -1.1, 0.38), BAS_D, bevel=0.04, segs=1)
    B.box((0.7, 0.32, 0.18), (-0.3, -1.1, 0.66), "4A5060", bevel=0.04, segs=1)
    B.cone(0.15, 0.3, (0.1, -1.1, 0.66), "4A5060", r=rot(0, 90, 0), sides=6)
    G.box((0.34, 0.12, 0.06), (-0.35, -1.1, 0.78), LAVA_L, bevel=0.02, segs=1)
    # Löschtrog mit Wasserrad (dreht sich)
    B.box((0.9, 0.5, 0.4), (-1.1, -0.2, 0.36), WOOD_D, bevel=0.04, segs=1)
    B.box((0.8, 0.4, 0.05), (-1.1, -0.2, 0.55), "5DB2EA")
    w = Part()
    w.cyl(0.42, 0.1, (0, 0, 0), WOOD, r=rot(0, 90, 0), sides=12)
    for k in range(6):
        w.box((0.12, 0.08, 0.36), (0, 0, 0), WOOD_L, r=rot(k * 60, 0, 0) @ T(0, 0, 0.32))
    w.cyl(0.08, 0.16, (0, 0, 0), DK, r=rot(0, 90, 0), sides=6)
    o = w.build("spin_wheel", root, (-1.6, -0.2, 0.5))
    o.rotation_euler = (0, math.radians(90), 0)
    # Schild an Kette
    B.cyl(0.04, 1.6, (1.4, -1.55, 0.95), DK, sides=5)
    B.box((0.5, 0.06, 0.06), (1.2, -1.55, 1.75), DK)
    sg = Part()
    sg.box((0.5, 0.05, 0.36), (0, 0, -0.25), WOOD, bevel=0.03, segs=1)
    sg.box((0.25, 0.06, 0.12), (0, -0.01, -0.25), OBS, bevel=0.02, segs=1)
    sg.build("sway_sign", root, (1.05, -1.55, 1.7))
    # Stufe 2: Kohlenbunker und Barrenregal
    X2.box((0.9, 0.9, 0.7), (1.15, 1.2, 0.55), WOOD_D, bevel=0.05, segs=1)
    for k in range(5):
        X2.ball(0.16, (0.95 + (k % 3) * 0.2, 1.1 + (k // 3) * 0.2, 0.95), "2A2622", subdiv=1)
    for k in range(3):
        X2.box((0.36, 0.14, 0.1), (1.15, 0.6 + k * 0.0, 0.3 + k * 0.12), OBS, bevel=0.02, segs=1)
    G2.box((0.3, 0.1, 0.06), (1.15, 0.6, 0.66), LAVA_L)
    # Stufe 3: Obergeschoss mit Glutfenstern
    X3.box((1.6, 1.6, 1.0), (hx, hy + 0.1, 2.75), BAS, bevel=0.1, segs=1)
    gable(X3, (hx, hy + 0.1, 3.25), 2.0, 2.0, 0.7, "8A4A2A", over=0.2, thick=0.16)
    for x in (-0.35, 0.35):
        G3.box((0.3, 0.06, 0.35), (hx + x, hy - 0.71, 2.8), "FFB040")
    # Stufe 4: Basaltplatten und Stützen
    for sx in (-1, 1):
        beam(X4, (hx + 1.05 * sx, hy - 1.05, 0.16), (hx + 0.95 * sx, hy - 0.9, 1.7), 0.14, OBS)
    X4.box((3.2, 0.12, 0.45), (0, 1.9, 0.38), OBS, bevel=0.03, segs=1)
    X4.box((0.12, 1.6, 0.45), (1.62, 1.1, 0.38), OBS, bevel=0.03, segs=1)
    # Stufe 5: goldene Esse und Krone auf dem Kamin
    X5.cyl(0.33, 0.1, (ex_ + 0.1, ey + 0.15, 2.64), GOLD, sides=8)
    for k in range(5):
        a = math.radians(k * 72)
        X5.cone(0.06, 0.2, (ex_ + 0.1 + math.cos(a) * 0.3, ey + 0.15 + math.sin(a) * 0.3, 2.78), GOLD, sides=4)
    X5.box((0.62, 0.08, 0.08), (ex_, ey - 0.73, 0.98), GOLD, bevel=0.02, segs=1)
    star(X5, (hx, hy - 1.02, 1.62), 0.18, GOLD, 0.05)
    B.build("body", root)
    G.build("win_glow", root)
    X2.build("lv2_annex", root)
    G2.build("lv2_win_glow", root)
    X3.build("lv3_upper", root)
    G3.build("lv3_win_glow", root)
    X4.build("lv4_armor", root)
    X5.build("lv5_gold", root)
    empty("door", root, (hx + 0.45, hy - 1.4, 0))
    empty("bubble", root, (0, 0, 3.6))
    fin(name, yaw=-35, pitch=26, lv1=True)


# ================================================================== Werkzeug, Gebietsbild, Trophäe
@model("tool_tongs")
def tool_tongs(name):
    root, B, G = start(name)
    for s in (-1, 1):
        limb(B, (0.05 * s, 0, 0.0), (0.03 * s, 0, 0.45), 0.03, 0.025, "4A5060", 6)
        limb(B, (0.03 * s, 0, 0.45), (0.1 * s, 0, 0.75), 0.025, 0.02, "4A5060", 6)
        B.box((0.05, 0.06, 0.12), (0.11 * s, 0, 0.8), "4A5060", bevel=0.01, segs=1)
    B.cyl(0.035, 0.12, (0, 0, 0.45), GOLD, r=rot(90, 0, 0), sides=8)
    limb(B, (0.05, 0, 0.0), (0.05, 0, 0.18), 0.04, 0.04, WOOD, 6)
    limb(B, (-0.05, 0, 0.0), (-0.05, 0, 0.18), 0.04, 0.04, WOOD, 6)
    B.ball(0.08, (0, 0, 0.82), LAVA_L, subdiv=1)
    B.build("body", root)
    fin(name, keep_glb=False, size=128, ao=False)


@model("area_vulkan")
def a_vulkan(name):
    root, B, G = start(name)
    clod(B, BAS, soil="3A3036", soil_d="2A2228", rim=BAS_D)
    rng = random.Random(71)
    B.cyl(2.0, 1.2, (0.3, 0.6, 0.6), BAS_D, r2=1.2, sides=12)                       # Vulkan
    B.cyl(1.2, 1.0, (0.3, 0.6, 1.7), BAS, r2=0.65, sides=10)
    B.torus(0.6, 0.18, (0.3, 0.6, 2.2), BAS_D, seg=10, tseg=4)
    for k in range(5):
        a = math.radians(k * 72 + 20)
        lava_rock(B, (0.5, 0.45, 0.6), (math.cos(a) * 2.4, math.sin(a) * 2.4, 0.2), rng, (BAS_L, BAS)[k % 2])
    obsidian_shard(B, T(-1.6, -1.2, 0.0), 0.25, 1.0)
    obsidian_shard(B, T(-1.3, -1.55, 0.0) @ rot(0, 20, 0), 0.18, 0.7)
    limb(B, (1.8, -1.4, 0), (1.85, -1.4, 1.2), 0.1, 0.05, CHAR, 6)                 # verkohlter Baum
    limb(B, (1.84, -1.4, 0.8), (2.2, -1.6, 1.3), 0.04, 0.02, CHAR, 5)
    G.cyl(0.5, 0.08, (0.3, 0.6, 2.25), LAVA, sides=10)
    G.ball(0.32, (0.3, 0.6, 2.32), LAVA_L, scale=(1, 1, 0.5), subdiv=2)
    for i, (a, b) in enumerate((((0.3, -0.05, 2.1), (0.0, -1.1, 0.9)), ((0.0, -1.1, 0.9), (-0.4, -2.2, 0.05)))):
        beam(G, a, b, 0.35 - 0.05 * i, LAVA, d=0.15)
    G.cyl(0.6, 0.06, (-0.45, -2.3, 0.03), LAVA, r=S(1.0, 0.6, 1.0), sides=10)
    for (x, y, z, r) in ((0.3, 0.7, 2.9, 0.3), (0.5, 0.8, 3.5, 0.24), (0.2, 1.0, 4.0, 0.18)):
        B.ball(r, (x, y, z), "6E6668", subdiv=2)                                   # Rauchwolke
    B.build("body", root)
    G.build("lava_glow", root)
    fin(name, yaw=-30, pitch=30, keep_glb=False)


def _piece_brodel(B):
    from animkit import lathe
    lathe(B, [(0.5, 1.3, OBS_D), (0.58, 1.55, OBS)], sides=10)                     # Obsidiankrone
    for i in range(7):
        a = math.radians(i * 360 / 7)
        obsidian_shard(B, T(0.5 * math.sin(a), 0.5 * math.cos(a), 1.5) @ rot(12 * math.cos(a), -12 * math.sin(a), 0), 0.11, 0.55 + 0.15 * (i % 2))
    B.ball(0.42, (0, 0, 1.42), LAVA, subdiv=1, scale=(1.2, 1.2, 0.4))              # Glutkissen
    for i in range(3):
        a = math.radians(i * 120 + 30)
        B.ball(0.07, (0.56 * math.sin(a), 0.56 * math.cos(a), 1.42), LAVA_L, subdiv=1)


def _trophy():
    import def_g2
    def_g2.trophy("b_trophy_brodel", _piece_brodel, "FF7A1E")()


REG["b_trophy_brodel"] = _trophy

for _i, _s in ((1, 1), (2, 2)):
    REG["p_tree_lava_%d" % _i] = (lambda i=_i, s=_s: tree_lava("p_tree_lava_%d" % i, s))
for _i in (1, 2, 3):
    REG["p_rock_lava_%d" % _i] = (lambda i=_i: rock_lava("p_rock_lava_%d" % i, i))

MODELS = REG
VULKAN = ["p_tree_lava_1", "p_tree_lava_2", "p_rock_lava_1", "p_rock_lava_2", "p_rock_lava_3", "p_vk_ashgrass", "p_vk_firebloom", "p_vk_fumarole",
          "p_vk_spring", "n_obsidian_1", "n_obsidian_2", "n_obsidian_3", "n_sulfur", "n_src_vulkan", "n_lavabomb", "lm_vulkan", "x_barrier_vulkan",
          "o_special_vulkan", "tool_tongs", "area_vulkan", "b_trophy_brodel"]

if __name__ == "__main__":
    args = sys.argv[1:]
    if args == ["list"]:
        print("\n".join(VULKAN))
        sys.exit(0)
    for n in (args or VULKAN):
        if n not in MODELS:
            print("unbekannt:", n, flush=True)
            continue
        MODELS[n]()
        print("ok", n, flush=True)
