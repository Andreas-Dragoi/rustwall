"""Paket Z2 – Stadtruinen (Gebiet 9): alle festen Modelle der Zone.

Aufruf:  python3 blender/stadt.py [namen…]     (ohne Namen: alle; "list" zeigt die Namen)

| Name | Bedeutung | Objekte mit Wirkung |
|---|---|---|
| p_tree_city_1, _2 | überwucherter Straßenbaum im zerbrochenen Kübel / Mauerecke mit Efeu und Birke (Kulisse) | – |
| p_st_rubble_1 … _3 | Schutthaufen aus Betonbrocken, Ziegeln und Bewehrungseisen (Kulisse, „Felsen“ des Gebiets) | – |
| p_st_road, p_st_cross | Straßenstück 8 × 8 m (Fahrbahn, Gehwege, Mittellinie, Risse) und Kreuzung mit Zebrastreifen | – |
| p_st_car_1, p_st_car_2 | Autowrack (rostige Limousine) und umgekippter Lieferwagen | – |
| p_st_bushalt, p_st_litfass, p_st_laterne | Bushaltestelle, Litfaßsäule, verbogene Straßenlaterne | – |
| p_st_weed | Unkraut aus den Asphaltrissen (Löwenzahn, Gras) | – |
| p_st_hochhaus_1, _2 | Hochhausruine (zerbrochene obere Stockwerke) | – |
| p_st_roof_1, _2 | Dachhaus mit Feuertreppe: Grundfläche 10 × 8 m (x ±5, y ±4), Treppe vorn rechts (x 1…5, y −8…−4), Dach auf 3,4 m – begehbar | – |
| p_st_ampel | funktionierende Ampel (Lichter einzeln schaltbar) | red_glow, yellow_glow, green_glow |
| p_st_generator | Notstromaggregat (schaltet die U-Bahn und die Ampeln ein) | lamp_glow (an), fan (Lüfter, dreht im Spiel) |
| p_st_ubahn | U-Bahn-Eingang: Treppe nach unten, Geländer, U-Schild | sign_glow (Strom an), gate (Rollgitter, zu ohne Strom); Leerobjekt door (Einstieg) |
| n_ewaste_1 … _3 | Elektroschrott in drei Größen (Fernseher, Rechner, Platinen) – gibt Metall | screen_glow |
| n_copper | Kabeltrommel mit Kupferkabel – gibt Bauteile | – |
| n_akku | Stapel Autobatterien und Akkus – gibt Energiezellen | lamp_glow |
| n_src_stadt | Umspannkasten (gebietseigene Quelle, Bolzenschneider nötig) | pulse_core_glow |
| lm_stadt | Wahrzeichen „Gestürzter Fernsehturm“ (Stumpf, abgestürzte Kugel, Antenne) | pulse_light_glow, win_glow, Leerobjekt fx_smoke1 |
| x_barrier_stadt | Sperre: Schuttberg mit Bauzaun, Baken und Betonplatten (8 m) | lamp_glow (Warnleuchten), sway_tape |
| o_special_stadt | Spezialbau „Umspannwerk“ (5 Stufen: lv2_annex, lv3_upper, lv4_armor, lv5_gold) | win_glow, pulse_coil_glow, spin_fan, sway_sign, Leerobjekte fx_spark, door, bubble |
| tool_cutter | Werkzeug Bolzenschneider (nur Symbol) | – |
| area_stadt | Schaubild für die Weltkarte (nur Symbol) | – |
| b_trophy_bolzen | Trophäe: Blech-Zylinder und Amtskette von Bürgermeister Bolzen | pulse_gem_glow |
"""
import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from exp_common import *
from exp_areas import clod

CONC, CONC_D, CONC_L = "B4AFA6", "8C877F", "D2CDC2"
ASPH, ASPH_D, ASPH_L = "45474C", "36383C", "5C5F64"
WALK, WALK_D = "A8A398", "8A857B"
LINE_W, LINE_Y = "ECE8DA", "F2C531"
BRK, BRK_D, BRK_L = "B4583A", "8E432C", "CC7454"
RST, RST_D, RST_L = "A0522A", "74391E", "C2703A"
STEELC, STEEL_D = "6C7380", "4E5460"
GLASS_D = "26303C"
IVY, IVY_D, IVY_L = "4E8A3A", "3A6A2C", "74AE4A"
WEED_C = ("7FA83A", "96BE46", "5E8A2E")
SIGN_B = "2A6AD0"
WHITE_C = "F2F2EE"
YELLOW_C = "F2C531"
RED_C = "D8403A"
CU, CU_L = "D2803A", "F0A458"
PCB = "2E8A4A"


def _one(name, p, yaw=-30, pitch=18):
    root = empty(name)
    p.build("body", root)
    fin(name, yaw=yaw, pitch=pitch)


def chunk(p, size, loc, rng, col=CONC, k=0.12):
    """Betonbrocken: grober Quader mit leichter Rundung, zufällig gedreht."""
    p.box(size, loc, col, r=rot(rng.uniform(-25, 25), rng.uniform(-25, 25), rng.uniform(0, 90)), bevel=min(size) * k, segs=1)


def rebar(p, a, b, r=0.025):
    tube(p, a, b, r, RST_D, sides=4)


def ivy(p, x, y, z, w, h, rng, face="f", n=7):
    """Efeu-Fleck an einer Wand: flache Blattkugeln. face: f (−Y), b (+Y), l (−X), r (+X)."""
    for i in range(n):
        u = rng.uniform(-w * 0.5, w * 0.5)
        v = rng.uniform(0.0, h)
        s = rng.uniform(0.18, 0.34)
        c = (IVY, IVY_D, IVY_L)[i % 3]
        if face in "fb":
            yy = y + (-0.06 if face == "f" else 0.06)
            p.ball(s, (x + u, yy, z + v), c, scale=(1.0, 0.35, 0.8), subdiv=1)
        else:
            xx = x + (-0.06 if face == "l" else 0.06)
            p.ball(s, (xx, y + u, z + v), c, scale=(0.35, 1.0, 0.8), subdiv=1)


def crack_line(p, pts, w=0.05, col="22242A", z=0.0):
    for i in range(len(pts) - 1):
        a = (pts[i][0], pts[i][1], z)
        b = (pts[i + 1][0], pts[i + 1][1], z)
        beam(p, a, b, w, col, d=0.02)


def dark_window(p, x, y, z, w, h, face="f", frame=CONC_D, broken=False, rng=None, board=False):
    """Fensterhöhle (dunkel) mit Rahmen; broken: Scherbenrest, board: zugenagelt."""
    if face in "fb":
        s = -1 if face == "f" else 1
        p.box((w + 0.16, 0.08, h + 0.16), (x, y + s * 0.02, z), frame)
        p.box((w, 0.1, h), (x, y + s * 0.05, z), GLASS_D)
        if broken:
            p.cone(w * 0.22, h * 0.45, (x - w * 0.3, y + s * 0.09, z + h * 0.25), "8FB2C4", r=rot(90 * s, 0, 0) @ rot(0, 0, 180), sides=3)
        if board:
            for k in (-0.2, 0.15):
                p.box((w + 0.2, 0.06, 0.16), (x, y + s * 0.11, z + k * h), WOOD, r=rot(0, 8 if k < 0 else -6, 0))
    else:
        s = -1 if face == "l" else 1
        p.box((0.08, w + 0.16, h + 0.16), (x + s * 0.02, y, z), frame)
        p.box((0.1, w, h), (x + s * 0.05, y, z), GLASS_D)
        if board:
            for k in (-0.2, 0.15):
                p.box((0.06, w + 0.2, 0.16), (x + s * 0.11, y, z + k * h), WOOD, r=rot(8 if k < 0 else -6, 0, 0))


# ================================================================== Bäume und Schutt (ein Objekt body)
def tree_city(name, seed):
    reset()
    rng = random.Random(seed * 7 + 3)
    p = Part()
    if seed == 1:
        # Straßenbaum im zerbrochenen Betonkübel, Efeu klettert hoch, Krone zerzaust
        p.cyl(0.85, 0.7, (0, 0, 0.35), CONC, sides=8, bevel=0.06, segs=1)
        p.cyl(0.7, 0.72, (0, 0, 0.38), "5A4632", sides=8)
        chunk(p, (0.6, 0.35, 0.5), (0.8, -0.55, 0.2), rng, CONC_D)
        chunk(p, (0.45, 0.3, 0.3), (-0.95, 0.3, 0.12), rng, CONC)
        limb(p, (0, 0, 0.6), (0.15, 0.1, 3.0), 0.2, 0.11, "6A5038", 7)
        for (z, a, ln) in ((1.9, 20, 1.1), (2.3, 140, 1.0), (2.6, 250, 0.9), (2.1, 320, 0.8)):
            ra = math.radians(a)
            tip = (math.cos(ra) * ln, math.sin(ra) * ln, z + ln * 0.5)
            limb(p, (0.1, 0.05, z), tip, 0.08, 0.03, "6A5038", 5)
            p.ball(0.62, tip, (LEAF, LEAF_D, LEAF_L)[int(a) % 3], scale=(1.0, 1.0, 0.75), subdiv=2)
        p.ball(0.85, (0.15, 0.1, 3.2), LEAF, scale=(1.1, 1.0, 0.8), subdiv=2)
        for k in range(6):                                                             # Efeu am Stamm
            p.ball(0.14, (0.18 * math.cos(k * 2.0), 0.18 * math.sin(k * 2.0), 0.8 + k * 0.32), (IVY, IVY_L)[k % 2], subdiv=1)
        tuft(p, 0.5, 0.4, 0.72, 5, 0.8, 11, cols=WEED_C)
    else:
        # Mauerecke einer Ruine mit Efeu, dazwischen eine junge Birke
        p.box((2.4, 0.4, 2.2), (0.0, 0.8, 1.1), BRK, bevel=0.04, segs=1)
        p.box((0.4, 1.8, 1.6), (-1.0, -0.1, 0.8), BRK_D, bevel=0.04, segs=1)
        for k in range(5):                                                             # abgebrochene Oberkante
            p.box((0.42, 0.42, 0.25), (-0.9 + k * 0.45, 0.8, 2.25 + (k % 2) * 0.12), (BRK, BRK_L)[k % 2], r=rot(0, (k - 2) * 6, 0), bevel=0.03, segs=1)
        dark_window(p, 0.4, 0.58, 1.3, 0.6, 0.7, "f", BRK_D)
        ivy(p, 0.0, 0.58, 0.1, 2.0, 1.9, rng, "f", 9)
        ivy(p, -0.78, -0.1, 0.1, 1.4, 1.3, rng, "r", 5)
        limb(p, (0.7, -0.3, 0), (0.85, -0.25, 3.1), 0.09, 0.05, "F0EEE6", 6)          # Birke
        for k in range(4):
            p.box((0.1, 0.06, 0.03), (0.73 + k * 0.03, -0.37, 0.5 + k * 0.6), "2A2A2A")
        for (dx, dy, dz, r) in ((0.2, 0.0, 3.0, 0.55), (-0.25, 0.1, 2.6, 0.45), (0.3, -0.3, 2.45, 0.42)):
            p.ball(r, (0.85 + dx, -0.25 + dy, dz), ("A6C83C", "88B030", "BCD84A")[int(r * 10) % 3], scale=(1, 1, 0.8), subdiv=2)
        for k in range(4):
            chunk(p, (0.35, 0.25, 0.2), (rng.uniform(-1.2, 1.4), rng.uniform(-0.9, 0.2), 0.08), rng, BRK)
        tuft(p, -0.3, -0.5, 0.0, 6, 0.9, 13, cols=WEED_C)
    _one(name, p, pitch=16)


def rubble(name, seed):
    reset()
    rng = random.Random(seed * 13 + 1)
    p = Part()
    n = (9, 7, 11)[seed - 1]
    hk = (1.0, 0.8, 1.15)[seed - 1]
    for i in range(n):                                                                 # Betonbrocken zu einem Hügel
        a = rng.uniform(0, 6.28)
        rr = rng.uniform(0.0, 1.2)
        s = rng.uniform(0.45, 0.9) * (1.2 - rr * 0.35)
        z = (1.0 - rr / 1.4) * 0.8 * hk
        chunk(p, (s, s * rng.uniform(0.6, 1.0), s * 0.55), (math.cos(a) * rr, math.sin(a) * rr, z), rng, (CONC, CONC_D, CONC_L)[i % 3])
    for i in range(5):                                                                 # Ziegel
        a = rng.uniform(0, 6.28)
        rr = rng.uniform(0.6, 1.4)
        p.box((0.3, 0.15, 0.1), (math.cos(a) * rr, math.sin(a) * rr, 0.08), (BRK, BRK_L)[i % 2], r=rot(0, rng.uniform(-20, 20), rng.uniform(0, 180)))
    if seed != 2:                                                                      # Betonplatte mit Bewehrung
        p.box((1.4, 0.9, 0.16), (0.3, 0.2, 0.75 * hk), CONC_L, r=rot(18, -12, 35), bevel=0.03, segs=1)
        for k in range(3):
            rebar(p, (0.0 + k * 0.25, 0.45, 0.9 * hk), (-0.2 + k * 0.3, 0.75, 1.5 * hk))
    else:
        tire(p, T(0.9, -0.6, 0.18) @ rot(70, 0, 20), 0.35, 0.22, lp=True)
    p.box((1.0, 0.04, 0.6), (-0.5, -0.9, 0.35), YELLOW_C if seed == 3 else SIGN_B, r=rot(-60, 0, 25))   # Schild im Schutt
    tuft(p, 0.9, 0.7, 0.05, 5, 0.8, seed + 20, cols=WEED_C)
    p.cyl(1.55, 0.05, (0, 0, 0.02), "6E6A64", sides=10)
    _one(name, p, pitch=20)


# ================================================================== Straßen (flache Kacheln 8 × 8 m)
@model("p_st_road")
def road(name):
    reset()
    rng = random.Random(81)
    p = Part()
    p.box((6.0, 8.0, 0.04), (0, 0, 0.02), ASPH)
    for s in (-1, 1):                                                                  # Gehwege mit Bordstein
        p.box((1.0, 8.0, 0.13), (s * 3.5, 0, 0.065), WALK)
        p.box((0.16, 8.0, 0.15), (s * 3.02, 0, 0.075), CONC_L)
        for k in range(4):                                                             # Gehwegplatten-Fugen
            p.box((0.96, 0.04, 0.01), (s * 3.5, -3.0 + k * 2.0, 0.135), WALK_D)
    for k in range(2):                                                                 # Mittellinie (gestrichelt, verblasst)
        p.box((0.16, 2.2, 0.01), (0, -2.0 + k * 4.0, 0.045), LINE_W if k == 0 else "C8C4B6")
    crack_line(p, [(-1.6, -3.4), (-1.1, -2.2), (-1.4, -1.0), (-0.8, 0.4)], 0.06, ASPH_D, 0.045)
    crack_line(p, [(1.2, 1.0), (1.8, 2.2), (1.4, 3.6)], 0.05, ASPH_D, 0.045)
    p.cyl(0.55, 0.012, (1.2, -1.8, 0.042), ASPH_D, r=S(1.3, 0.8, 1), sides=9)          # Schlagloch und Flicken
    p.box((1.1, 0.9, 0.012), (-1.6, 2.6, 0.042), ASPH_L, r=rot(0, 0, 8))
    p.box((0.5, 0.5, 0.02), (2.4, -3.4, 0.045), "6A6E74")                              # Gully
    for k in range(3):
        p.box((0.06, 0.42, 0.01), (2.28 + k * 0.12, -3.4, 0.056), "2A2C30")
    for (x, y, sd) in ((-0.9, 0.5, 3), (1.6, 2.5, 4), (-2.9, -2.0, 5), (2.95, 1.2, 6)):  # Unkraut in den Rissen
        tuft(p, x, y, 0.04, 4, 0.55, sd, cols=WEED_C)
    root = empty(name)
    p.build("body", root)
    fin(name, yaw=-30, pitch=55, ao=False)


@model("p_st_cross")
def cross(name):
    reset()
    p = Part()
    p.box((8.0, 8.0, 0.04), (0, 0, 0.02), ASPH)
    for sx in (-1, 1):                                                                 # Gehweg-Ecken
        for sy in (-1, 1):
            p.box((1.0, 1.0, 0.13), (sx * 3.5, sy * 3.5, 0.065), WALK)
    for side in range(4):                                                              # Zebrastreifen an allen vier Seiten
        for k in range(4):
            o = -1.8 + k * 1.2
            c = LINE_W if k % 2 == 0 else "DAD6C8"
            if side < 2:
                p.box((0.55, 1.1, 0.012), (o, (2.75 if side == 0 else -2.75), 0.046), c)
            else:
                p.box((1.1, 0.55, 0.012), ((2.75 if side == 2 else -2.75), o, 0.046), c)
    crack_line(p, [(-0.6, -0.9), (0.2, -0.2), (0.0, 0.8), (0.7, 1.3)], 0.06, ASPH_D, 0.045)
    p.cyl(0.4, 0.012, (-0.8, 0.9, 0.042), ASPH_D, r=S(1.2, 0.8, 1), sides=8)
    tuft(p, 0.15, 0.1, 0.04, 5, 0.6, 9, cols=WEED_C)
    root = empty(name)
    p.build("body", root)
    fin(name, yaw=-30, pitch=55, ao=False)


# ================================================================== Stadtmöbel und Wracks
def car(name, kind):
    reset()
    rng = random.Random(31 + kind)
    p = Part()
    if kind == 1:
        # rostige Limousine, platte Reifen, keine Scheiben
        body_c = ("8A3A30", "4A6A8A")[0]
        p.box((1.75, 4.2, 0.65), (0, 0, 0.62), body_c, bevel=0.14, segs=1)
        p.box((1.55, 2.1, 0.55), (0, 0.25, 1.18), shade(body_c, 0.9), bevel=0.12, segs=1)
        for (y, w) in ((-0.82, 1.4), (1.32, 1.4)):                                    # Scheibenhöhlen
            p.box((w, 0.08, 0.38), (0, y, 1.2), GLASS_D, r=rot(-25 if y < 0 else 25, 0, 0))
        for s in (-1, 1):
            p.box((0.06, 1.7, 0.36), (s * 0.79, 0.25, 1.2), GLASS_D)
        for (x, y) in ((-0.86, -1.3), (0.86, -1.3), (-0.86, 1.35), (0.86, 1.35)):
            tire(p, T(x, y, 0.28) @ rot(0, 90, 0), 0.33, 0.24, lp=True)
        for k in range(6):                                                             # Rostflecken
            p.ball(0.18, (rng.choice((-0.88, 0.88)), rng.uniform(-1.8, 1.8), rng.uniform(0.5, 0.85)), RST, scale=(0.2, 1.0, 0.7), subdiv=1)
        p.box((1.6, 0.12, 0.2), (0, -2.12, 0.45), STEELC, bevel=0.04, segs=1)          # Stoßstangen
        p.box((1.6, 0.12, 0.2), (0, 2.12, 0.45), STEELC, bevel=0.04, segs=1)
        for s in (-1, 1):
            p.box((0.32, 0.06, 0.16), (s * 0.6, -2.14, 0.7), "E8E2C0")
        ivy(p, 0.0, 1.95, 0.4, 1.0, 0.7, rng, "b", 4)
        tuft(p, -1.2, 0.4, 0.0, 5, 0.8, 7, cols=WEED_C)
    else:
        # umgekippter Lieferwagen (liegt auf der Seite)
        m = T(0, 0, 1.0) @ rot(0, 88, 0)
        p.box((2.0, 5.0, 2.0), (0, 0, 0), "A8A496", r=m @ T(0, 0.3, 0), bevel=0.15, segs=1)
        p.box((1.9, 1.4, 1.4), (0, 0, 0), "A8A496", r=m @ T(0, -2.7, -0.3), bevel=0.15, segs=1)
        p.box((1.6, 0.08, 0.7), (0, 0, 0), GLASS_D, r=m @ T(0, -3.42, 0.0) @ rot(-15, 0, 0))
        p.box((0.06, 3.5, 0.8), (0, 0, 0), "A8483A", r=m @ T(-1.02, 0.4, 0.2))            # rote Firmen-Streifen
        p.box((0.06, 3.5, 0.2), (0, 0, 0), "3A5A90", r=m @ T(-1.02, 0.4, -0.45))
        for k in range(5):
            p.ball(0.25, (0, 0, 0), RST, r=m @ T(-1.0, rng.uniform(-1.8, 2.4), rng.uniform(-0.7, 0.7)), scale=(0.2, 1.0, 0.8), subdiv=1)
        for (x, y) in ((-0.9, -2.4), (0.9, -2.4), (-0.9, 1.8), (0.9, 1.8)):
            tire(p, m @ T(x, y, -1.05) @ rot(0, 90, 0), 0.38, 0.26, lp=True)
        for k in range(4):
            chunk(p, (0.6, 0.4, 0.3), (rng.uniform(-1.6, 1.6), rng.uniform(-2.5, 2.8), 0.12), rng, ("C8C2B4", "8C877F")[k % 2])
        for k in range(3):                                                             # verlorene Pakete
            crate(p, (1.4 + k * 0.3, 2.6 - k * 0.7, 0.0), 0.5, "C8A06A", yaw=k * 20)
        ivy(p, -0.4, 0.0, 0.0, 3.0, 1.1, rng, "l", 5)
    p.cyl(2.4, 0.03, (0, 0, 0.01), "5A5650", r=S(0.8, 1.2, 1), sides=10)
    _one(name, p, pitch=22)


@model("p_st_bushalt")
def bushalt(name):
    reset()
    rng = random.Random(41)
    p = Part()
    p.box((3.6, 1.6, 0.12), (0, 0, 0.06), WALK)
    for x in (-1.65, 1.65):                                                            # Pfosten
        for y in (0.55, -0.45):
            p.box((0.1, 0.1, 2.3), (x, y, 1.21), STEELC)
    p.box((3.8, 1.5, 0.12), (0.1, 0.05, 2.4), STEELC, r=rot(-4, 6, 0), bevel=0.03, segs=1)   # schiefes Dach
    p.box((3.3, 0.05, 1.7), (0, 0.6, 1.15), "9CC2D4")                                  # Rückwand aus Glas (gesprungen)
    p.box((1.3, 0.06, 1.0), (-0.9, 0.58, 1.3), "6A8EA4")
    crack_line(p, [(0.2, 0.57), (0.7, 0.57)], 0.04, "E8F4FA", 1.5)
    p.box((2.2, 0.45, 0.1), (0, 0.25, 0.55), WOOD, bevel=0.03, segs=1)                 # Bank
    for x in (-0.9, 0.9):
        p.box((0.08, 0.35, 0.45), (x, 0.25, 0.3), STEEL_D)
    p.box((0.8, 0.06, 1.1), (1.62, -0.05, 1.3), "E8C040", bevel=0.02, segs=1)         # Fahrplan-Kasten
    p.box((0.62, 0.07, 0.8), (1.62, -0.08, 1.35), WHITE_C)
    p.cyl(0.05, 2.8, (-2.1, -0.6, 1.4), STEELC, sides=6)                               # H-Schild
    p.cyl(0.32, 0.06, (-2.1, -0.6, 2.75), "3A9A4A", r=rot(90, 0, 0), sides=14)
    p.cyl(0.25, 0.07, (-2.1, -0.6, 2.75), YELLOW_C, r=rot(90, 0, 0), sides=14)
    p.box((0.06, 0.08, 0.26), (-2.18, -0.65, 2.75), "3A9A4A")
    p.box((0.06, 0.08, 0.26), (-2.02, -0.65, 2.75), "3A9A4A")
    p.box((0.12, 0.08, 0.05), (-2.1, -0.65, 2.75), "3A9A4A")
    ivy(p, 1.0, 0.62, 0.1, 1.6, 1.4, rng, "b", 6)
    tuft(p, -1.2, -0.3, 0.1, 5, 0.7, 4, cols=WEED_C)
    _one(name, p, pitch=20)


@model("p_st_litfass")
def litfass(name):
    reset()
    rng = random.Random(51)
    p = Part()
    p.cyl(0.62, 0.25, (0, 0, 0.12), "4A6A4A", sides=14)
    p.cyl(0.55, 2.5, (0, 0, 1.45), "E0D8C4", sides=14)
    cols = ("E8483A", "2A6AD0", "F2C531", "3A9A4A", "E87ACA", "F28A1E")
    for k in range(7):                                                                 # Plakate, teils abgerissen
        a = k * 51.0
        z = 0.7 + (k % 3) * 0.75
        p.box((0.5, 0.05, 0.62), (0, 0, 0), cols[k % len(cols)], r=rot(0, 0, a) @ T(0, -0.57, z) @ rot(0, (k % 2) * 6 - 3, 0))
        if k % 3 == 1:
            p.box((0.2, 0.04, 0.2), (0, 0, 0), WHITE_C, r=rot(0, 0, a) @ T(0.12, -0.6, z + 0.15))
    p.cyl(0.66, 0.15, (0, 0, 2.75), "4A6A4A", sides=14)
    p.ball(0.62, (0, 0, 2.8), "4A6A4A", scale=(1, 1, 0.5), subdiv=2)
    p.cone(0.08, 0.35, (0, 0, 3.25), "4A6A4A", sides=6)
    ivy(p, 0.0, 0.0, 0.2, 0.8, 1.2, rng, "f", 5)
    _one(name, p, pitch=18)


@model("p_st_laterne")
def laterne(name):
    reset()
    p = Part()
    p.cyl(0.18, 0.4, (0, 0, 0.2), STEEL_D, sides=8)
    limb(p, (0, 0, 0.3), (0.25, 0.0, 3.4), 0.08, 0.06, STEELC, 6)                     # leicht schief
    limb(p, (0.25, 0, 3.4), (1.0, 0, 3.6), 0.05, 0.04, STEELC, 6)
    p.box((0.55, 0.3, 0.14), (1.15, 0, 3.55), STEEL_D, r=rot(0, 12, 0), bevel=0.04, segs=1)
    p.box((0.42, 0.22, 0.04), (1.15, 0, 3.47), "8A8A80", r=rot(0, 12, 0))              # zerbrochene Leuchte
    p.box((0.2, 0.06, 0.3), (0.05, -0.1, 1.2), "E8C040", r=rot(0, 0, 8))               # Aufkleber
    tuft(p, 0.2, 0.15, 0.0, 4, 0.6, 3, cols=WEED_C)
    _one(name, p, pitch=14)


@model("p_st_weed")
def weed(name):
    reset()
    rng = random.Random(61)
    p = Part()
    for (x, y, n, k) in ((0, 0, 7, 1.0), (0.45, 0.25, 5, 0.7), (-0.4, 0.3, 5, 0.75), (0.15, -0.45, 4, 0.6)):
        tuft(p, x, y, 0.0, n, k, int(x * 10 + 30), cols=WEED_C)
    for (x, y, h) in ((0.1, 0.05, 0.6), (0.48, 0.3, 0.45), (-0.35, 0.2, 0.5)):        # Löwenzahn
        p.cyl(0.02, h, (x, y, h * 0.5), "5E8A2E", sides=4)
        p.ball(0.07, (x, y, h + 0.03), YELLOW_C, scale=(1, 1, 0.5), subdiv=1)
    p.ball(0.08, (-0.1, -0.2, 0.55), "F4F4F0", subdiv=1)                               # Pusteblume
    crack_line(p, [(-0.7, -0.3), (-0.2, 0.0), (0.3, -0.1), (0.8, 0.2)], 0.05, ASPH_D, 0.01)
    _one(name, p, pitch=30)


# ================================================================== Gebäude: Hochhausruinen, Dachhäuser
def hochhaus(name, kind):
    reset()
    rng = random.Random(71 + kind)
    p = Part()
    W = 11.0
    floors = 5 if kind == 1 else 4
    fh = 3.2
    wall = CONC if kind == 1 else BRK
    wall_d = CONC_D if kind == 1 else BRK_D
    p.box((W + 0.6, W + 0.6, 0.3), (0, 0, 0.15), WALK)
    for f in range(floors):                                                            # Stockwerke, oben zerbrochen
        z0 = 0.3 + f * fh
        broken = f >= floors - 2
        for side in range(4):
            for k in range(4):
                if broken and rng.random() < (0.35 if f == floors - 2 else 0.6):
                    continue
                u = -W * 0.5 + (k + 0.5) * W / 4
                hh = fh if not broken else fh * rng.uniform(0.4, 1.0)
                if side == 0:
                    p.box((W / 4 - 0.02, 0.4, hh), (u, -W * 0.5, z0 + hh * 0.5), wall)
                    dark_window(p, u, -W * 0.5 - 0.15, z0 + 1.6, 1.4, 1.5, "f", wall_d, broken=rng.random() < 0.3, rng=rng, board=f == 0 and k % 2 == 0)
                elif side == 1:
                    p.box((W / 4 - 0.02, 0.4, hh), (u, W * 0.5, z0 + hh * 0.5), wall)
                elif side == 2:
                    p.box((0.4, W / 4 - 0.02, hh), (-W * 0.5, u, z0 + hh * 0.5), wall)
                else:
                    p.box((0.4, W / 4 - 0.02, hh), (W * 0.5, u, z0 + hh * 0.5), wall)
                    dark_window(p, W * 0.5 + 0.15, u, z0 + 1.6, 1.4, 1.5, "r", wall_d, rng=rng)
        if f < floors - 1 or rng.random() < 0.5:                                       # Decke (teilweise eingestürzt)
            p.box((W - 0.4, W - 0.4, 0.25), (0, 0, z0 + fh), CONC_L if f % 2 else CONC)
        p.box((W + 0.1, 0.25, 0.3), (0, -W * 0.5 - 0.05, z0 + fh), wall_d)              # Gesims
    top = 0.3 + floors * fh
    for k in range(10):                                                                # Bewehrung ragt oben heraus
        rebar(p, (rng.uniform(-W * 0.45, W * 0.45), -W * 0.5, top - 1.4), (rng.uniform(-W * 0.45, W * 0.45), -W * 0.52, top + rng.uniform(0.2, 1.2)), 0.04)
    for k in range(6):                                                                 # Trümmer am Fuß
        chunk(p, (rng.uniform(0.8, 1.6), rng.uniform(0.6, 1.2), 0.6), (rng.uniform(-W * 0.6, W * 0.6), -W * 0.55 - rng.uniform(0.3, 1.5), 0.25), rng, (CONC, CONC_D, wall)[k % 3])
    ivy(p, -3.0, -W * 0.5 - 0.25, 0.3, 3.5, 6.5, rng, "f", 12)
    ivy(p, W * 0.5 + 0.25, 2.5, 0.3, 3.0, 5.0, rng, "r", 9)
    if kind == 1:                                                                      # Leuchtreklame (dunkel)
        p.box((4.2, 0.2, 1.0), (1.5, -W * 0.5 - 0.3, 0.3 + fh * 2 + 1.4), "2A2C34")
        for k in range(4):
            p.box((0.7, 0.22, 0.6), (0.2 + k * 0.95, -W * 0.5 - 0.42, 0.3 + fh * 2 + 1.4), ("E8483A", "F2C531", "2A6AD0", "E87ACA")[k])
    else:                                                                              # Balkone
        for f in range(1, floors - 1):
            p.box((2.6, 1.0, 0.15), (-2.0, -W * 0.5 - 0.6, 0.3 + f * fh), CONC, bevel=0.03, segs=1)
            for k in range(6):
                p.box((0.05, 0.05, 0.9), (-3.2 + k * 0.48, -W * 0.5 - 1.05, 0.75 + f * fh), STEELC)
            p.box((2.6, 0.06, 0.06), (-2.0, -W * 0.5 - 1.05, 1.2 + f * fh), STEELC)
    _one(name, p, yaw=-35, pitch=16)


def roof_house(name, kind):
    """Dachhaus mit Feuertreppe: Haus x ±5, y ±4, Dach (begehbar) bei z = 3,4; Treppe x 1…5, y −8…−4."""
    reset()
    rng = random.Random(91 + kind)
    p = Part()
    H = 3.4
    wall = CONC if kind == 1 else BRK
    wall_d = CONC_D if kind == 1 else BRK_D
    p.box((10.4, 8.4, 0.16), (0, 0, 0.08), WALK)
    p.box((10.0, 8.0, H - 0.2), (0, 0, 0.16 + (H - 0.2) * 0.5 - 0.08), wall)
    p.box((10.3, 8.3, 0.16), (0, 0, H - 0.08), CONC_D)                                  # Dachplatte
    p.box((9.6, 7.6, 0.03), (0, 0, H + 0.01), "8E8C86")                                 # Kies
    for k in range(9):                                                                 # Kiesflecken
        p.box((rng.uniform(0.6, 1.6), rng.uniform(0.5, 1.2), 0.02), (rng.uniform(-4, 4), rng.uniform(-3, 3), H + 0.025), ("7C7A74", "9E9C96")[k % 2], r=rot(0, 0, rng.uniform(0, 90)))
    # Brüstung, mit Lücke über der Treppe und abgebrochenen Stücken
    for (x0, x1) in ((-5.0, -3.2), (-2.4, 0.9)):
        p.box((x1 - x0, 0.22, 0.38), ((x0 + x1) * 0.5, -4.04, H + 0.19), wall_d)
    p.box((10.0, 0.22, 0.38), (0, 4.04, H + 0.19), wall_d)
    p.box((0.22, 8.0, 0.38), (-5.04, 0, H + 0.19), wall_d)
    p.box((0.22, 3.0, 0.38), (5.04, 2.4, H + 0.19), wall_d)
    p.box((0.22, 2.0, 0.38), (5.04, -2.8, H + 0.19), wall_d)
    for k in range(4):                                                                 # Bewehrung an den Bruchstellen
        rebar(p, (-3.2 + k * 0.15, -4.04, H + 0.3), (-3.0 + k * 0.2, -4.1, H + 0.75))
    # Vorderseite (−Y): Laden mit Schaufenster und zerfetzter Markise (1) / Haustür mit Fenstern (2)
    if kind == 1:
        p.box((4.6, 0.12, 2.0), (-2.2, -4.06, 1.25), GLASS_D)
        p.box((4.8, 0.16, 0.16), (-2.2, -4.08, 2.3), STEEL_D)
        p.cone(1.0, 1.4, (-3.1, -4.12, 0.9), "8FB2C4", r=rot(90, 0, 0) @ rot(0, 0, 200) @ S(0.7, 1.0, 1), sides=3)
        for k in range(6):                                                             # Markise in Streifen
            ln = rng.uniform(0.5, 1.2)
            p.box((0.8, ln, 0.05), (-4.2 + k * 0.82, -4.1 - ln * 0.45, 2.55 - ln * 0.25), ("E8483A", WHITE_C)[k % 2], r=rot(-28, 0, rng.uniform(-6, 6)))
        p.box((3.4, 0.12, 0.6), (-2.2, -4.1, 2.95), "2A6AD0", bevel=0.03, segs=1)       # Ladenschild
        for k in range(4):
            p.box((0.4, 0.13, 0.36), (-3.3 + k * 0.72, -4.13, 2.95), (YELLOW_C, WHITE_C)[k % 2])
        door(p, (-0.2, -4.0, 0.16), 0.9, 2.0, STEEL_D, DK, GOLD)
        dark_window(p, 0.4, -4.0, 1.7, 0.9, 1.0, "f", wall_d, broken=True, rng=rng)
    else:
        door(p, (-3.6, -4.0, 0.16), 1.0, 2.1, WOOD_D, DK, GOLD)
        for x in (-1.8, 0.2):
            dark_window(p, x, -4.0, 1.8, 1.1, 1.1, "f", wall_d, broken=x > 0, rng=rng, board=x < 0)
        p.box((1.6, 0.6, 0.12), (-3.6, -4.35, 2.45), CONC, bevel=0.03, segs=1)          # Vordach
        p.box((0.5, 0.08, 0.35), (-2.6, -4.08, 2.0), SIGN_B)                            # Hausnummer
        p.box((0.2, 0.09, 0.2), (-2.6, -4.12, 2.0), WHITE_C)
    for (x, face) in ((-2.5, "b"), (2.5, "b")):                                        # Rückseite und Seiten
        dark_window(p, x, 4.0, 1.9, 1.2, 1.1, face, wall_d, rng=rng, board=x > 0)
    for y in (-1.5, 1.8):
        dark_window(p, -5.0, y, 1.9, 1.2, 1.1, "l", wall_d, rng=rng)
        dark_window(p, 5.0, y + 0.6, 1.9, 1.2, 1.1, "r", wall_d, rng=rng, board=y > 0)
    for k in range(5):                                                                 # Risse
        x = rng.uniform(-4.5, 4.5)
        crack_line(p, [(x, -4.03), (x + 0.3, -4.03)], 0.04, "2A2622", rng.uniform(0.6, 2.8))
    ivy(p, -4.0, -4.06, 0.2, 2.2, 2.6, rng, "f", 9)
    ivy(p, -5.06, 1.5, 0.2, 3.0, 3.0, rng, "l", 8)
    ivy(p, 2.0, 4.06, 0.2, 3.0, 2.2, rng, "b", 6)
    # Dachaufbauten (niedrig, am Rand): Lüftung, Oberlicht, Pfütze, Antenne
    p.box((1.0, 0.7, 0.55), (-4.0, 3.2, H + 0.28), STEELC, bevel=0.06, segs=1)
    p.cyl(0.25, 0.08, (-4.0, 3.2, H + 0.58), STEEL_D, sides=8)
    p.box((1.4, 1.0, 0.25), (-1.5, 2.0, H + 0.12), "9CC2D4", r=rot(0, 0, 0), bevel=0.04, segs=1)
    p.cyl(0.9, 0.02, (2.0, 1.2, H + 0.035), "6E8AA0", r=S(1.4, 0.8, 1), sides=10)
    limb(p, (4.5, 3.5, H), (4.5, 3.5, H + 1.6), 0.04, 0.03, STEEL_D, 5)
    p.box((0.9, 0.05, 0.05), (4.5, 3.5, H + 1.3), STEEL_D)
    p.box((0.6, 0.05, 0.05), (4.5, 3.5, H + 1.55), STEEL_D)
    if kind == 2:                                                                      # Rest des zweiten Stocks hinten links
        p.box((2.0, 0.3, 1.4), (-4.0, 3.85, H + 0.7), wall, bevel=0.03, segs=1)
        p.box((0.3, 1.2, 1.0), (-4.85, 3.1, H + 0.5), wall_d, bevel=0.03, segs=1)
    # Feuertreppe vorn rechts: von (y −8, z 0) hinauf auf das Dach (y −4, z 3,4)
    paint_c = "4A5A6A" if kind == 1 else "2F5A4A"
    for x in (1.15, 4.85):
        beam(p, (x, -8.0, 0.0), (x, -4.1, H), 0.12, paint_c, d=0.28)
        for k in range(4):                                                             # Geländerpfosten
            t = (k + 0.5) / 4.0
            y = -8.0 + 3.9 * t
            z = H * t
            p.box((0.05, 0.05, 1.0), (x, y, z + 0.6), paint_c)
        beam(p, (x, -8.0, 1.05), (x, -4.1, H + 1.05), 0.05, paint_c)
    n = 10
    for k in range(n):                                                                 # Stufen (Gitterroste)
        t = (k + 0.5) / n
        y = -8.0 + 3.9 * t
        z = H * t
        p.box((3.6, 0.36, 0.06), (3.0, y, z - 0.03), STEEL_D if k % 2 else STEELC)
    p.box((3.9, 0.5, 0.08), (3.0, -4.15, H - 0.04), paint_c)                            # Austritt oben
    for x in (1.15, 4.85):                                                             # Stützen
        p.box((0.1, 0.1, H * 0.5), (x, -5.6, H * 0.25), paint_c)
    p.box((0.7, 0.5, 0.06), (3.0, -8.25, 0.03), "E8C040")                              # gelbe Markierung am Fuß
    tuft(p, 0.6, -6.5, 0.0, 5, 0.8, 17, cols=WEED_C)
    tuft(p, -4.6, -4.8, 0.0, 6, 0.9, 19, cols=WEED_C)
    _one(name, p, yaw=-40, pitch=26)


# ================================================================== Ampel, Notstrom, U-Bahn (mit Schaltteilen)
@model("p_st_ampel")
def ampel(name):
    root, B, G = start(name)
    B.cyl(0.16, 0.2, (0, 0, 0.1), STEEL_D, sides=10)
    B.cyl(0.07, 3.0, (0, 0, 1.6), STEELC, sides=8)
    for k in range(5):                                                                 # weiß-rote Ringe am Mast
        B.cyl(0.075, 0.12, (0, 0, 0.5 + k * 0.25), (WHITE_C, RED_C)[k % 2], sides=8)
    B.box((0.42, 0.34, 1.25), (0, -0.12, 2.7), "2A2C30", bevel=0.05, segs=1)           # Gehäuse
    for k in range(3):                                                                 # Schirme und dunkle Gläser
        z = 3.08 - k * 0.38
        B.box((0.36, 0.2, 0.06), (0, -0.36, z + 0.17), "1A1C20")
        B.cyl(0.13, 0.04, (0, -0.31, z), ("5A2020", "5A4A18", "1E4A24")[k], r=rot(90, 0, 0), sides=12)
    B.box((0.2, 0.14, 0.3), (0.0, 0.1, 1.15), YELLOW_C, bevel=0.03, segs=1)            # Drücker-Kasten
    B.cyl(0.04, 0.03, (0.0, 0.02, 1.2), "1A1C20", r=rot(90, 0, 0), sides=8)
    tuft(B, 0.2, 0.15, 0.0, 4, 0.6, 7, cols=WEED_C)
    B.build("body", root)
    for k, nm in enumerate(("red_glow", "yellow_glow", "green_glow")):
        g = Part()
        g.cyl(0.13, 0.05, (0, 0, 0), ("FF3A2A", "FFC21A", "3AFF6A")[k], r=rot(90, 0, 0), sides=12)
        g.build(nm, root, (0, -0.34, 3.08 - k * 0.38))
    fin(name, yaw=-30, pitch=12)


@model("p_st_generator")
def generator(name):
    root, B, G = start(name)
    B.box((2.4, 1.5, 0.15), (0, 0, 0.1), STEEL_D)                                       # Kufen
    for x in (-1.1, 1.1):
        B.box((0.12, 1.6, 0.18), (x, 0, 0.09), DK)
    B.box((2.0, 1.2, 1.15), (0, 0, 0.78), YELLOW_C, bevel=0.1, segs=1)                  # Gehäuse
    for k in range(6):                                                                 # Lüftungsschlitze
        B.box((0.05, 0.03, 0.55), (-0.75 + k * 0.12, -0.61, 0.8), "3A3A30")
    B.box((0.7, 0.06, 0.5), (0.45, -0.62, 0.9), "2A2C30", bevel=0.03, segs=1)            # Schalttafel
    B.cyl(0.05, 0.05, (0.3, -0.66, 0.95), RED_C, r=rot(90, 0, 0), sides=8)
    B.box((0.08, 0.06, 0.16), (0.6, -0.67, 0.85), WHITE_C)
    B.box((0.18, 0.06, 0.12), (0.45, -0.66, 1.08), "1E4A24")                             # dunkle Lampe (aus)
    B.cyl(0.36, 0.9, (0, 0.3, 1.55), "B8B8B0", r=rot(0, 90, 0), sides=12)               # Tank oben
    B.cyl(0.08, 0.6, (0.75, 0.35, 1.7), STEEL_D, sides=6)                                # Auspuff
    B.cyl(0.1, 0.12, (0.75, 0.35, 2.05), DK, sides=6)
    B.box((0.06, 1.0, 0.8), (-1.03, 0, 0.8), "2A2C30")                                   # Kühler-Gitter
    for k in range(4):
        B.box((0.07, 0.9, 0.05), (-1.04, 0, 0.5 + k * 0.2), STEEL_D)
    B.cyl(0.35, 0.25, (1.4, -0.3, 0.25), WOOD, r=rot(90, 0, 0), sides=12)                # Kabeltrommel
    B.cyl(0.24, 0.3, (1.4, -0.3, 0.25), RED_C, r=rot(90, 0, 0), sides=12)
    B.box((0.5, 0.06, 0.4), (-0.2, -0.62, 1.15), "F2C531")                               # Warnschild Blitz
    B.cone(0.1, 0.3, (-0.2, -0.66, 1.15), DK, r=rot(90, 0, 0) @ rot(0, 0, 25), sides=3)
    B.build("body", root)
    G.box((0.17, 0.06, 0.11), (0.45, -0.69, 1.08), "5AFF7A")
    G.build("lamp_glow", root)
    f = Part()                                                                         # Lüfter (dreht im Spiel, wenn Strom da ist)
    f.cyl(0.36, 0.04, (0, 0, 0), STEELC, r=rot(0, 90, 0), sides=10)
    for k in range(4):
        f.box((0.03, 0.12, 0.62), (0, 0, 0), "3A3A40", r=rot(k * 45, 0, 0))
    f.build("fan", root, (-1.1, 0, 0.8))
    fin(name, yaw=-30, pitch=20)


@model("p_st_ubahn")
def ubahn(name):
    """U-Bahn-Eingang: Grundfläche 3,6 × 5 m, Einstieg vorn (−Y), die Treppe führt nach hinten hinab."""
    root, B, G = start(name)
    rng = random.Random(77)
    B.box((3.8, 5.4, 0.14), (0, 0, 0.07), WALK)
    B.box((2.6, 4.4, 0.05), (0, 0.2, 0.15), "0E0F12")                                   # dunkler Schacht
    for k in range(4):                                                                 # die ersten Stufen
        B.box((2.4, 0.42, 0.06), (0, -1.6 + k * 0.42, 0.14 - k * 0.03), ("8C877F", "6E6A64")[k % 2])
    for s in (-1, 1):                                                                  # Seitenwände mit Kacheln
        B.box((0.4, 5.0, 1.1), (s * 1.6, 0.0, 0.62), "D8D4C8", bevel=0.04, segs=1)
        B.box((0.42, 5.02, 0.12), (s * 1.6, 0.0, 1.2), STEELC)
        for k in range(5):
            B.box((0.44, 0.5, 0.25), (s * 1.6, -2.0 + k * 1.0, 0.55), ("2A6AD0", "D8D4C8")[k % 2])
        for k in range(4):                                                             # Geländer
            B.box((0.05, 0.05, 0.75), (s * 1.6, -2.2 + k * 1.45, 1.6), STEELC)
        B.box((0.06, 4.6, 0.06), (s * 1.6, 0.0, 1.95), STEELC)
    B.box((3.6, 0.4, 1.1), (0, 2.5, 0.62), "D8D4C8", bevel=0.04, segs=1)               # Rückwand
    B.cyl(0.07, 3.4, (-1.8, -2.6, 1.7), STEELC, sides=6)                                 # Schildmast
    B.box((0.9, 0.12, 0.9), (-1.8, -2.66, 3.45), "1A3A70", bevel=0.05, segs=1)           # Schild (dunkel)
    B.box((0.12, 0.13, 0.6), (-2.0, -2.7, 3.45), "6A8AB0")
    B.box((0.12, 0.13, 0.6), (-1.6, -2.7, 3.45), "6A8AB0")
    B.box((0.4, 0.13, 0.12), (-1.8, -2.7, 3.2), "6A8AB0")
    B.box((1.6, 0.08, 0.4), (0.6, -2.55, 1.35), SIGN_B)                                 # Hinweistafel
    ivy(B, 1.62, 1.0, 0.2, 2.0, 0.8, rng, "r", 5)
    tuft(B, -1.4, -2.9, 0.1, 5, 0.7, 23, cols=WEED_C)
    B.build("body", root)
    sg = Part()                                                                        # leuchtendes U (nur mit Strom)
    sg.box((0.92, 0.1, 0.92), (0, 0, 0), "3A7AFF", bevel=0.05, segs=1)
    sg.box((0.13, 0.12, 0.62), (-0.2, -0.06, 0.0), WHITE_C)
    sg.box((0.13, 0.12, 0.62), (0.2, -0.06, 0.0), WHITE_C)
    sg.box((0.53, 0.12, 0.13), (0.0, -0.06, -0.25), WHITE_C)
    sg.build("sign_glow", root, (-1.8, -2.74, 3.45))
    gt = Part()                                                                        # Rollgitter vor dem Einstieg
    for k in range(9):
        gt.box((0.05, 0.05, 1.1), (-1.2 + k * 0.3, 0, 0.55), "8A8E96")
    for k in range(4):
        gt.box((2.6, 0.06, 0.05), (0, 0, 0.15 + k * 0.3), "6A6E76")
    gt.box((2.8, 0.25, 0.25), (0, 0, 1.2), STEEL_D, bevel=0.03, segs=1)
    gt.build("gate", root, (0, -2.3, 0.0))
    empty("door", root, (0, -3.2, 0))
    fin(name, yaw=-30, pitch=24)


# ================================================================== Quellen
def ewaste_node(name, stage):
    root, B, G = start(name)
    rng = random.Random(110 + stage)
    k = (1.0, 0.75, 0.5)[stage - 1]
    B.cyl(1.3 * k + 0.3, 0.05, (0, 0, 0.02), "5A5650", sides=10)
    items = [("tv", -0.4, -0.2, 0.0, 15), ("pc", 0.55, 0.1, 0.0, -10), ("tv", 0.1, 0.45, 0.55, 30), ("board", -0.6, 0.5, 0.1, 20),
             ("pc", -0.2, -0.75, 0.0, 70), ("tv", 0.7, -0.6, 0.0, -35), ("board", 0.2, -0.2, 0.75, -15), ("keys", 0.9, 0.6, 0.0, 60)]
    n = (8, 5, 3)[stage - 1]
    for i, (kind, x, y, z, yaw) in enumerate(items[:n]):
        m = T(x * k * 1.2, y * k * 1.2, z * k) @ rot(rng.uniform(-8, 8), rng.uniform(-8, 8), yaw)
        if kind == "tv":                                                               # Röhrenfernseher
            B.box((0.75, 0.6, 0.6), (0, 0, 0), "5A5650", r=m @ T(0, 0, 0.3), bevel=0.06, segs=1)
            B.box((0.6, 0.05, 0.45), (0, 0, 0), "1A1E24", r=m @ T(0, -0.31, 0.32))
            if i == 0:
                G.box((0.55, 0.04, 0.4), (0, 0, 0), "6AD8FF", r=m @ T(0, -0.34, 0.32))
        elif kind == "pc":                                                             # Rechner-Turm
            B.box((0.3, 0.6, 0.6), (0, 0, 0), "D8D4C8", r=m @ T(0, 0, 0.3), bevel=0.03, segs=1)
            B.box((0.2, 0.04, 0.1), (0, 0, 0), "3A3A40", r=m @ T(0, -0.31, 0.45))
        elif kind == "board":                                                          # Platinen
            B.box((0.5, 0.35, 0.03), (0, 0, 0), PCB, r=m @ T(0, 0, 0.05) @ rot(0, 30, 0))
            for j in range(3):
                B.box((0.08, 0.08, 0.04), (0, 0, 0), ("2A2C30", GOLD)[j % 2], r=m @ T(-0.12 + j * 0.12, 0, 0.08) @ rot(0, 30, 0))
        else:                                                                          # Tastatur
            B.box((0.6, 0.2, 0.05), (0, 0, 0), "3A3A40", r=m @ T(0, 0, 0.04))
    for i in range(4 - stage):                                                         # Kabelsalat
        a = rng.uniform(0, 6.28)
        tube(B, (math.cos(a) * 0.3, math.sin(a) * 0.3, 0.1), (math.cos(a) * 1.1 * k, math.sin(a) * 1.1 * k, 0.03), 0.03, ("2A2C30", RED_C, SIGN_B)[i % 3], sides=4)
    B.build("body", root)
    if G.bm.faces:
        G.build("screen_glow", root)
    else:
        G.box((0.06, 0.06, 0.04), (0.3, -0.2, 0.1), "6AD8FF")
        G.build("screen_glow", root)
    fin(name, yaw=-30, pitch=24)


for _i in (1, 2, 3):
    REG["n_ewaste_%d" % _i] = (lambda i=_i: ewaste_node("n_ewaste_%d" % i, i))


@model("n_copper")
def copper(name):
    root, B, G = start(name)
    B.cyl(0.95, 0.05, (0, 0, 0.02), "5A5650", sides=10)
    m = T(0, 0, 0.75) @ rot(0, 90, 0)                                                   # Kabeltrommel auf der Seite
    for s in (-0.42, 0.42):
        B.cyl(0.75, 0.08, (0, 0, 0), WOOD, r=m @ T(0, 0, s), sides=14)
    B.cyl(0.55, 0.78, (0, 0, 0), CU, r=m, sides=14)
    for k in range(5):                                                                 # Windungen
        B.cyl(0.57, 0.06, (0, 0, 0), CU_L if k % 2 else shade(CU, 0.85), r=m @ T(0, 0, -0.32 + k * 0.16), sides=14)
    B.cyl(0.12, 0.95, (0, 0, 0), WOOD_D, r=m, sides=8)
    for k in range(3):                                                                 # lose Rollen am Boden
        a = k * 2.1 + 0.4
        B.torus(0.24, 0.05, (math.cos(a) * 0.8, math.sin(a) * 0.8 - 0.2, 0.06), (CU, CU_L)[k % 2], seg=12, tseg=4)
    tube(B, (0.0, -0.55, 0.3), (0.5, -0.85, 0.04), 0.04, CU, sides=5)
    B.build("body", root)
    fin(name, yaw=-30, pitch=22)


@model("n_akku")
def akku(name):
    root, B, G = start(name)
    B.cyl(1.0, 0.05, (0, 0, 0.02), "5A5650", sides=10)
    pos = [(-0.35, -0.2, 0), (0.35, -0.2, 0), (0.0, 0.35, 0), (0.0, 0.0, 0.48), (-0.65, 0.4, 0)]
    for i, (x, y, z) in enumerate(pos):                                                # Autobatterien
        B.box((0.62, 0.38, 0.45), (x, y, z + 0.23), ("2A2C30", "3A3E48")[i % 2], bevel=0.03, segs=1)
        for s in (-0.18, 0.18):
            B.cyl(0.05, 0.08, (x + s, y, z + 0.49), (RED_C if s > 0 else "2A2C30"), sides=8)
        B.box((0.3, 0.02, 0.15), (x, y - 0.2, z + 0.26), YELLOW_C)
    for k in range(4):                                                                 # kleine Akkus
        B.cyl(0.07, 0.3, (0.75, -0.5 + k * 0.17, 0.15), ("3A9A4A", SIGN_B)[k % 2], r=rot(90, 0, 0), sides=8)
    tube(B, (-0.35, -0.2, 0.5), (0.35, -0.2, 0.5), 0.025, RED_C, sides=4)
    B.build("body", root)
    for (x, y, z) in pos[:4]:
        G.box((0.06, 0.03, 0.06), (x + 0.2, y - 0.2, z + 0.38), "5AFF7A")
    G.build("lamp_glow", root)
    fin(name, yaw=-30, pitch=22)


@model("n_src_stadt")
def src_stadt(name):
    """Umspannkasten: grauer Schaltschrank mit Vorhängeschloss und Blitzschild, innen glühende Sicherungen."""
    root, B, G = start(name)
    B.box((1.6, 1.2, 0.15), (0, 0, 0.08), CONC)
    B.box((1.3, 0.7, 1.6), (0, 0, 0.95), "7A8088", bevel=0.05, segs=1)
    B.box((1.4, 0.8, 0.1), (0, 0, 1.8), "6A7078", bevel=0.03, segs=1)
    for s in (-1, 1):                                                                  # zwei Türen, eine steht offen
        if s < 0:
            B.box((0.6, 0.05, 1.4), (-0.33, -0.37, 0.95), "8A9098")
        else:
            B.box((0.6, 0.05, 1.4), (0.92, -0.62, 0.95), "8A9098", r=rot(0, 0, -55))
    B.box((0.6, 0.08, 1.3), (0.33, -0.3, 0.95), "1E2026")                                # Innenraum
    B.box((0.3, 0.06, 0.3), (-0.33, -0.41, 1.3), YELLOW_C)                               # Blitzschild
    B.cone(0.07, 0.22, (-0.33, -0.45, 1.3), DK, r=rot(90, 0, 0) @ rot(0, 0, 25), sides=3)
    B.torus(0.07, 0.02, (0.0, -0.42, 1.05), GOLD, r=rot(90, 0, 0), seg=10, tseg=3)        # Vorhängeschloss
    B.box((0.16, 0.08, 0.14), (0.0, -0.43, 0.96), GOLD, bevel=0.02, segs=1)
    tube(B, (0.0, 0.3, 0.2), (0.0, 0.9, 0.03), 0.06, "2A2C30", sides=6)
    tube(B, (0.3, 0.3, 0.2), (0.7, 0.8, 0.03), 0.05, "2A2C30", sides=6)
    tuft(B, -0.8, 0.5, 0.12, 5, 0.7, 31, cols=WEED_C)
    B.build("body", root)
    c = Part()
    for k in range(3):                                                                 # glühende Sicherungen
        c.cyl(0.06, 0.22, (0.2 + (k % 2) * 0.2 - 0.1, 0.0, 0.3 * k), ("6AD8FF", "B8F0FF", "6AD8FF")[k], r=rot(0, 90, 0), sides=8)
    c.build("pulse_core_glow", root, (0.33, -0.36, 0.65))
    fin(name, yaw=-35, pitch=20)


# ================================================================== Wahrzeichen
@model("lm_stadt")
def lm_stadt(name):
    """Gestürzter Fernsehturm: Betonstumpf mit gezacktem Bruch, die abgestürzte Turmkugel daneben, ein Schaftstück und die Antenne."""
    root, B, G = start(name)
    rng = random.Random(121)
    B.cyl(3.0, 0.4, (0, 0, 0.2), CONC_D, sides=16)                                      # Sockel
    B.cyl(1.25, 7.2, (0, 0, 4.0), CONC, r2=1.0, sides=14)                              # Stumpf
    for k in range(7):                                                                 # Bruchkante
        a = k * math.tau / 7
        B.cone(0.32, rng.uniform(0.5, 1.3), (0.95 * math.cos(a), 0.95 * math.sin(a), 7.8), CONC_L, r=rot(rng.uniform(-15, 15), rng.uniform(-15, 15), 0), sides=4)
    for k in range(6):
        rebar(B, (0.6 * math.cos(k), 0.6 * math.sin(k), 7.4), (0.9 * math.cos(k + 0.3), 0.9 * math.sin(k + 0.3), 8.9), 0.05)
    for k in range(3):                                                                 # Ringe am Schaft
        B.cyl(1.32 - k * 0.07, 0.25, (0, 0, 2.0 + k * 2.0), CONC_D, sides=14)
    B.box((0.8, 0.12, 1.6), (0, -1.15, 1.2), "2A2C34")                                  # Tür
    # abgestürzte Kugel (halb im Boden), mit Fensterband
    kx, ky = 3.0, -1.6
    B.ball(2.0, (kx, ky, 1.0), "C8CCD2", scale=(1, 1, 0.92), subdiv=2)
    B.torus(2.0, 0.22, (kx, ky, 1.0), "8A9098", r=rot(25, 10, 0), seg=18, tseg=5)
    B.cyl(0.5, 0.6, (kx - 0.6, ky - 0.5, 2.6), "8A9098", r=rot(25, 10, 0), sides=10)     # Ansatz des Schafts
    for k in range(6):                                                                 # Dellen und Risse
        a = k * 1.05
        B.ball(0.35, (kx + 1.6 * math.cos(a), ky + 1.6 * math.sin(a), 1.0 + 0.6 * math.sin(a * 2)), "9EA2A8", scale=(0.5, 0.5, 0.3), subdiv=1)
    for k in range(5):                                                                 # Schutt um die Kugel
        chunk(B, (0.9, 0.7, 0.5), (kx + rng.uniform(-2.5, 2.5), ky + rng.uniform(-2.5, 2.5), 0.2), rng, (CONC, CONC_D)[k % 2])
    # Schaftstück liegt am Boden, Antenne (rot-weiß) quer darüber
    B.cyl(0.8, 3.8, (0, 0, 0), CONC, r=T(-3.0, 1.6, 0.75) @ rot(0, 90, 28), sides=12)
    for k in range(6):
        B.cyl(0.12, 0.8, (0, 0, 0), (RED_C, WHITE_C)[k % 2], r=T(-1.8 - k * 0.55, -1.2 - k * 0.38, 0.3 + k * 0.05) @ rot(0, 90, 35), sides=6)
    B.ball(0.25, (1.45, 0.3, 7.6), "4A4E56", subdiv=1)
    ivy(B, -1.0, -1.15, 0.4, 1.6, 4.5, rng, "f", 10)
    ivy(B, 1.1, 0.0, 0.4, 1.5, 3.5, rng, "r", 7)
    tuft(B, 2.5, 1.8, 0.4, 6, 1.1, 41, cols=WEED_C)
    tuft(B, -2.4, -1.9, 0.4, 6, 1.0, 43, cols=WEED_C)
    B.build("body", root)
    G.box((0.5, 0.06, 0.4), (kx - 1.1, ky - 1.62, 1.6), "FFE08A", r=rot(0, 0, -25))      # Notlicht in der Kugel
    G.box((0.5, 0.06, 0.4), (kx + 0.3, ky - 1.98, 1.4), "FFE08A", r=rot(0, 0, 5))
    G.build("win_glow", root)
    L = Part()                                                                         # Flugwarnlicht (blinkt)
    L.ball(0.22, (0, 0, 0), "FF3A2A", subdiv=1)
    L.build("pulse_light_glow", root, (1.45, 0.3, 7.95))
    empty("fx_smoke1", root, (kx + 0.4, ky + 0.2, 2.6))
    fin(name, yaw=-30, pitch=18)


# ================================================================== Sperre
@model("x_barrier_stadt")
def b_stadt(name):
    """Schuttberg mit Bauzaun: Betonbrocken, Platten, rot-weiße Baken mit Warnleuchten und Absperrband (8 m)."""
    root, B, G = start(name)
    rng = random.Random(131)
    B.box((7.4, 1.8, 1.2), (0, 0.2, 0.6), CONC_D, bevel=0.3, segs=1)
    for i in range(10):
        x = -3.4 + i * 0.75
        chunk(B, (rng.uniform(0.9, 1.4), rng.uniform(0.8, 1.2), rng.uniform(0.7, 1.1)), (x, rng.uniform(-0.2, 0.6), rng.uniform(1.0, 1.9)), rng, (CONC, CONC_D, CONC_L)[i % 3])
    for i in range(3):                                                                 # schräg stehende Platten mit Bewehrung
        x = -2.5 + i * 2.5
        B.box((1.8, 0.2, 1.4), (x, 0.3, 2.3), CONC_L, r=rot(15 * (1 if i % 2 else -1), 20 * (i - 1), 0), bevel=0.04, segs=1)
        for k in range(3):
            rebar(B, (x - 0.5 + k * 0.4, 0.3, 2.8), (x - 0.6 + k * 0.45, 0.1, 3.5))
    for i in range(4):                                                                 # Bauzaun-Felder vorn
        x = -3.0 + i * 2.0
        B.box((1.9, 0.05, 1.3), (x, -0.95, 0.85), "C8CCD2")
        for k in range(5):
            B.box((0.03, 0.06, 1.2), (x - 0.8 + k * 0.4, -0.95, 0.85), "8A9098")
        B.box((0.35, 0.5, 0.18), (x - 0.9, -0.95, 0.09), CONC_L, bevel=0.03, segs=1)    # Zaunfüße
    for x in (-3.6, 0.0, 3.6):                                                         # Baken
        B.box((0.25, 0.25, 0.12), (x, -1.45, 0.06), DK)
        B.box((0.22, 0.12, 1.0), (x, -1.45, 0.6), WHITE_C, bevel=0.02, segs=1)
        for k in range(3):
            B.box((0.24, 0.13, 0.12), (x, -1.45, 0.25 + k * 0.3), RED_C, r=rot(0, 30, 0))
    for (x, y) in ((-1.8, -1.6), (1.9, -1.7), (2.8, -1.3)):                             # Pylonen
        B.cone(0.22, 0.6, (x, y, 0.32), "F28A1E", sides=8)
        B.cyl(0.13, 0.08, (x, y, 0.35), WHITE_C, sides=8)
        B.box((0.4, 0.4, 0.04), (x, y, 0.02), "F28A1E")
    B.box((1.0, 0.06, 0.7), (1.0, -1.05, 1.8), "2A6AD0", r=rot(0, 12, 0))                # Umleitungsschild
    B.cone(0.15, 0.4, (1.15, -1.1, 1.8), WHITE_C, r=rot(90, 0, 0) @ rot(0, 0, -90), sides=3)
    tuft(B, -3.2, -1.4, 0.0, 6, 0.9, 51, cols=WEED_C)
    tuft(B, 2.4, 1.0, 0.8, 5, 0.9, 53, cols=WEED_C)
    B.build("body", root)
    for x in (-3.6, 0.0, 3.6):
        G.ball(0.1, (x, -1.45, 1.18), "FFB01A", subdiv=1)
    G.build("lamp_glow", root)
    t = Part()                                                                         # Absperrband
    for k in range(6):
        t.box((0.6, 0.02, 0.1), (-3.0 + k * 0.6, 0, 0), (RED_C, WHITE_C)[k % 2])
    t.build("sway_tape", root, (1.8, -1.47, 0.95))
    fin(name, yaw=-28, pitch=22)


# ================================================================== Spezialbau der Außenbasis
@model("o_special_stadt")
def sp_stadt(name):
    """Umspannwerk: Trafo mit Kühlrippen und Isolatoren, Schalthäuschen, Lüfter; Stufen bis zu goldenen Isolatoren."""
    root, B, G = start(name)
    X2, X3, X4, X5, G3, G2 = Part(), Part(), Part(), Part(), Part(), Part()
    base(B, 3.3, 3.9, CONC_D, 0.16)
    B.box((3.0, 3.6, 0.03), (0, 0, 0.165), "5A5C60")
    for i in range(10):                                                                # Warnstreifen vorn
        B.box((0.3, 0.14, 0.03), (-1.35 + i * 0.3, -1.82, 0.17), YEL if i % 2 == 0 else "23262E")
    # Trafo vorn links
    tx, ty = -0.6, -0.4
    B.box((1.4, 1.1, 1.3), (tx, ty, 0.82), "6E8A6A", bevel=0.06, segs=1)
    for k in range(6):                                                                 # Kühlrippen
        B.box((0.08, 1.2, 1.0), (tx - 0.72, ty - 0.5 + k * 0.2, 0.8), "7E9C7A")
    for k in range(3):                                                                 # Isolatoren
        x = tx - 0.45 + k * 0.45
        for j in range(4):
            B.cyl(0.13 - j * 0.015, 0.08, (x, ty, 1.55 + j * 0.13), "F0EEE6", sides=10)
        B.cyl(0.03, 0.55, (x, ty, 1.8), STEEL_D, sides=5)
    B.box((0.4, 0.06, 0.35), (tx, ty - 0.57, 0.9), YELLOW_C)                             # Blitzschild
    B.cone(0.08, 0.26, (tx, ty - 0.61, 0.9), DK, r=rot(90, 0, 0) @ rot(0, 0, 25), sides=3)
    # Schalthaus hinten rechts
    hx, hy = 0.75, 0.9
    B.box((1.5, 1.6, 1.8), (hx, hy, 1.06), CONC, bevel=0.06, segs=1)
    B.box((1.7, 1.8, 0.14), (hx, hy, 2.0), "4A4E56", bevel=0.03, segs=1)
    door(B, (hx + 0.3, hy - 0.8, 0.16), 0.7, 1.4, STEEL_D, DK, GOLD)
    B.box((0.5, 0.08, 0.36), (hx - 0.35, hy - 0.81, 1.35), DK)
    G.box((0.4, 0.06, 0.28), (hx - 0.35, hy - 0.84, 1.35), "9CE8FF")
    # Mast mit Leitungen zum Rand
    B.cyl(0.08, 2.6, (-1.3, 1.4, 1.46), STEEL_D, sides=6)
    B.box((1.2, 0.08, 0.08), (-1.3, 1.4, 2.6), STEEL_D)
    for s in (-0.5, 0.5):
        B.cyl(0.07, 0.18, (-1.3 + s, 1.4, 2.5), "F0EEE6", sides=8)
        tube(B, (-1.3 + s, 1.4, 2.45), (tx + s * 0.9, ty, 2.0), 0.02, "2A2C30", sides=4)
    # Kabeltrommel, Lüfter, Schild an Kette
    B.cyl(0.32, 0.3, (1.2, -1.2, 0.36), WOOD, r=rot(90, 0, 0), sides=12)
    B.cyl(0.22, 0.32, (1.2, -1.2, 0.36), CU, r=rot(90, 0, 0), sides=12)
    f = Part()
    f.cyl(0.3, 0.05, (0, 0, 0), STEELC, r=rot(90, 0, 0), sides=10)
    for k in range(4):
        f.box((0.55, 0.03, 0.1), (0, 0, 0), "3A3A40", r=rot(0, k * 45, 0))
    f.build("spin_fan", root, (hx + 0.2, hy - 0.83, 2.45))
    sg = Part()
    sg.box((0.5, 0.05, 0.36), (0, 0, -0.25), WHITE_C, bevel=0.03, segs=1)
    sg.box((0.36, 0.06, 0.1), (0, -0.01, -0.25), RED_C)
    sg.build("sway_sign", root, (0.1, -1.6, 1.4))
    B.cyl(0.04, 1.4, (0.4, -1.6, 0.85), DK, sides=5)
    B.box((0.6, 0.06, 0.06), (0.15, -1.6, 1.5), DK)
    c = Part()                                                                         # Spule mit Lichtbogen
    c.cyl(0.12, 0.35, (0, 0, 0), "6AD8FF", sides=8)
    c.ball(0.1, (0, 0, 0.25), "D8F4FF", subdiv=1)
    c.build("pulse_coil_glow", root, (tx, ty, 2.35))
    empty("fx_spark", root, (tx, ty, 2.5))
    # Stufe 2: zweiter, kleiner Trafo
    X2.box((0.8, 0.7, 0.9), (1.1, -0.2, 0.62), "6E8A6A", bevel=0.05, segs=1)
    for k in range(2):
        X2.cyl(0.1, 0.3, (1.0 + k * 0.2, -0.2, 1.22), "F0EEE6", sides=8)
    G2.box((0.15, 0.05, 0.1), (1.1, -0.57, 0.8), "5AFF7A")
    # Stufe 3: Obergeschoss des Schalthauses mit Fenstern
    X3.box((1.3, 1.4, 0.9), (hx, hy + 0.05, 2.5), CONC_L, bevel=0.05, segs=1)
    X3.box((1.5, 1.6, 0.12), (hx, hy + 0.05, 3.0), "4A4E56", bevel=0.03, segs=1)
    for x in (-0.3, 0.3):
        G3.box((0.3, 0.06, 0.3), (hx + x, hy - 0.67, 2.5), "9CE8FF")
    # Stufe 4: Schutzzaun und Panzerplatten
    for k in range(7):
        X4.box((0.05, 0.05, 1.1), (-1.55 + k * 0.5, 1.85, 0.7), STEEL_D)
    X4.box((3.1, 0.04, 0.9), (0, 1.85, 0.7), "8A9098")
    X4.box((0.12, 1.5, 0.6), (-1.6, -0.9, 0.46), "4A4E56", bevel=0.03, segs=1)
    # Stufe 5: goldene Isolatoren und Stern
    for k in range(3):
        X5.cyl(0.12, 0.08, (tx - 0.45 + k * 0.45, ty, 2.1), GOLD, sides=10)
    star(X5, (hx, hy - 0.82, 1.85), 0.18, GOLD, 0.05)
    X5.box((1.8, 0.06, 0.08), (hx, hy - 0.86, 2.06), GOLD)
    B.build("body", root)
    G.build("win_glow", root)
    X2.build("lv2_annex", root)
    G2.build("lv2_win_glow", root)
    X3.build("lv3_upper", root)
    G3.build("lv3_win_glow", root)
    X4.build("lv4_armor", root)
    X5.build("lv5_gold", root)
    empty("door", root, (hx + 0.3, hy - 1.2, 0))
    empty("bubble", root, (0, 0, 3.6))
    fin(name, yaw=-35, pitch=26, lv1=True)


# ================================================================== Werkzeug, Gebietsbild, Trophäe
@model("tool_cutter")
def tool_cutter(name):
    root, B, G = start(name)
    for s in (-1, 1):                                                                  # zwei lange Griffe
        limb(B, (0.04 * s, 0, 0.0), (0.12 * s, 0, 0.55), 0.03, 0.028, RED_C, 6)
        limb(B, (0.12 * s, 0, 0.55), (0.05 * s, 0, 0.72), 0.03, 0.025, STEELC, 6)
        B.box((0.05, 0.06, 0.16), (0.04 * s, 0, 0.8), STEEL_D, r=rot(0, -12 * s, 0), bevel=0.01, segs=1)
    B.cyl(0.03, 0.12, (0, 0, 0.64), GOLD, r=rot(90, 0, 0), sides=8)
    for s in (-1, 1):
        limb(B, (0.04 * s, 0, -0.02), (0.05 * s, 0, 0.1), 0.04, 0.04, DK, 6)
    B.build("body", root)
    fin(name, keep_glb=False, size=128, ao=False)


@model("area_stadt")
def a_stadt(name):
    root, B, G = start(name)
    clod(B, ASPH_L, soil="5A5650", soil_d="3A3834", rim=ASPH_D)
    rng = random.Random(141)
    B.box((5.0, 1.2, 0.04), (0, 0.3, 0.02), ASPH)                                       # Straße mit Mittellinie
    for k in range(4):
        B.box((0.5, 0.1, 0.01), (-1.8 + k * 1.2, 0.3, 0.045), LINE_W)
    B.cyl(0.35, 2.8, (-1.3, -1.0, 1.4), CONC, r2=0.28, sides=10)                        # Fernsehturm-Stumpf
    for k in range(4):
        B.cone(0.1, 0.35, (-1.3 + 0.25 * math.cos(k * 1.6), -1.0 + 0.25 * math.sin(k * 1.6), 2.9), CONC_L, sides=4)
    B.ball(0.6, (-0.4, -1.6, 0.4), "C8CCD2", subdiv=2)                                  # abgestürzte Kugel
    B.box((1.2, 1.0, 1.6), (1.2, -1.0, 0.8), CONC, bevel=0.05, segs=1)                  # Ruine
    B.box((1.0, 0.9, 1.2), (1.2, 1.3, 0.6), BRK, bevel=0.05, segs=1)
    for (x, y, z) in ((0.85, -1.52, 1.1), (1.55, -1.52, 1.1), (0.85, -1.52, 0.5)):
        B.box((0.25, 0.05, 0.3), (x, y, z), GLASS_D)
    B.box((0.9, 0.5, 0.45), (0.0, 0.3, 0.3), "8A3A30", bevel=0.1, segs=1)              # Autowrack
    B.cyl(0.03, 1.2, (-2.0, 0.9, 0.6), STEELC, sides=6)                                 # Ampel
    B.box((0.18, 0.12, 0.45), (-2.0, 0.85, 1.2), "2A2C30")
    ivy(B, 1.2, -1.53, 0.1, 0.9, 1.2, rng, "f", 5)
    B.build("body", root)
    for k, c in enumerate(("FF3A2A", "FFC21A", "3AFF6A")):
        G.ball(0.05, (-2.0, 0.78, 1.35 - k * 0.14), c, subdiv=1)
    G.build("lamp_glow", root)
    fin(name, yaw=-30, pitch=30, keep_glb=False)


def _piece_bolzen(B):
    from animkit import lathe
    lathe(B, [(0.42, 1.3, "2A2C34"), (0.62, 1.32, "2A2C34"), (0.62, 1.4, "3A3E48")], sides=14)     # Krempe
    lathe(B, [(0.4, 1.4, "3A3E48"), (0.42, 2.1, "4A4E58"), (0.44, 2.2, "3A3E48"), (0.0, 2.22, "3A3E48")], sides=14)   # Blech-Zylinder
    B.cyl(0.43, 0.12, (0, 0, 1.55), RED_C, sides=14)
    for k in range(8):                                                                 # Nieten
        a = k * math.tau / 8
        B.ball(0.03, (0.43 * math.cos(a), 0.43 * math.sin(a), 1.85), STEELC, subdiv=1)
    B.torus(0.5, 0.04, (0, -0.1, 1.3), GOLD, r=rot(70, 0, 0), seg=16, tseg=4)           # Amtskette
    B.cyl(0.13, 0.05, (0, -0.58, 1.15), GOLD, r=rot(80, 0, 0), sides=12)


def _trophy():
    import def_g2
    def_g2.trophy("b_trophy_bolzen", _piece_bolzen, "6AD8FF")()


REG["b_trophy_bolzen"] = _trophy

for _i in (1, 2):
    REG["p_tree_city_%d" % _i] = (lambda i=_i: tree_city("p_tree_city_%d" % i, i))
    REG["p_st_car_%d" % _i] = (lambda i=_i: car("p_st_car_%d" % i, i))
    REG["p_st_hochhaus_%d" % _i] = (lambda i=_i: hochhaus("p_st_hochhaus_%d" % i, i))
    REG["p_st_roof_%d" % _i] = (lambda i=_i: roof_house("p_st_roof_%d" % i, i))
for _i in (1, 2, 3):
    REG["p_st_rubble_%d" % _i] = (lambda i=_i: rubble("p_st_rubble_%d" % i, i))

MODELS = REG
STADT = ["p_tree_city_1", "p_tree_city_2", "p_st_rubble_1", "p_st_rubble_2", "p_st_rubble_3", "p_st_road", "p_st_cross",
         "p_st_car_1", "p_st_car_2", "p_st_bushalt", "p_st_litfass", "p_st_laterne", "p_st_weed", "p_st_hochhaus_1", "p_st_hochhaus_2",
         "p_st_roof_1", "p_st_roof_2", "p_st_ampel", "p_st_generator", "p_st_ubahn", "n_ewaste_1", "n_ewaste_2", "n_ewaste_3",
         "n_copper", "n_akku", "n_src_stadt", "lm_stadt", "x_barrier_stadt", "o_special_stadt", "tool_cutter", "area_stadt", "b_trophy_bolzen"]

if __name__ == "__main__":
    args = sys.argv[1:]
    if args == ["list"]:
        print("\n".join(STADT))
        sys.exit(0)
    for n in (args or STADT):
        if n not in MODELS:
            print("unbekannt:", n, flush=True)
            continue
        MODELS[n]()
        print("ok", n, flush=True)
