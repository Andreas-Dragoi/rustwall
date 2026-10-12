"""Paket Welt (V5): Wahrzeichen der sieben Gebiete, gebietseigene Rohstoffquellen und ihre Werkzeuge, Tagebuchseite,
Begleiter-Ei und Nest, Trainingspuppe, Meteorit, Schubkarre der Bewohner.

Aufruf:  python3 blender/welt.py [namen…]     (ohne Namen: alle; "list" zeigt die Namen)

| Name | Bedeutung | Objekte mit Wirkung |
|---|---|---|
| lm_<gebiet> | Wahrzeichen (ca. 7 × 7 m Grundfläche, 8–12 m hoch) | gruental: spin_sails · forst: sway_lamp*, win_glow · staub: spin_wheel · kueste: spin_light_glow, win_glow · sumpf: Leerobjekte fx_smoke1/2, pipe_glow · frost: ice_glow · krater: pulse_core_glow, spin_ring |
| n_src_<gebiet> | gebietseigene Quelle (Bienenstock, Harzkiefer, Wasserkaktus, Muschelbank, Ölquelle, Eiskristall, Schleimgeysir) | *_glow, bob_/pulse_ je nach Quelle |
| tool_<schlüssel> | Werkzeug (nur Symbol, die .glb wird gelöscht) | – |
| p_journal | Tagebuchseite (schwebt, leuchtet) | bob_page_glow |
| p_egg, p_egg_nest | Begleiter-Ei und Nest mit Ei | egg_glow (Nest) |
| p_dummy | Trainingspuppe mit Zielscheibe | sway_dummy |
| n_meteor | Meteorit (Rest eines Einschlags, abbaubar) | rock_glow |
| c_barrow | Schubkarre (Bewohner, wird geschoben; Griffe nach +Y) | – |
"""
import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from exp_common import *

BLUE_W, BLUE_D = "3E7FD8", "2A5AA8"
WHITE = "F4F6FA"


def big_rock(p, loc, s, color, rng):
    rockc(p, (s, s * 0.85, s * 0.7), (loc[0], loc[1], loc[2] + s * 0.3), color, rng)


# ================================================================== Wahrzeichen
@model("lm_gruental")
def lm_gruental(name):
    """Windmühle auf einem Hügel."""
    root, B, G = start(name)
    rng = random.Random(1)
    B.cyl(3.4, 0.5, (0, 0, 0.2), GREEN_D, r2=3.0, sides=16)
    B.cyl(2.9, 0.4, (0, 0, 0.6), GREEN, r2=2.6, sides=16)
    B.cyl(1.9, 5.6, (0, 0, 3.6), CREAM, r2=1.35, sides=12)                # Turm
    for z in (1.6, 3.2, 4.8):
        B.cyl(1.92 - (z - 0.8) * 0.1, 0.14, (0, 0, z), shade(CREAM, 0.8), r2=1.9 - (z - 0.8) * 0.1, sides=12)
    B.cone(1.75, 2.0, (0, 0, 7.3), RED_D, sides=12)                        # Dach
    B.ball(0.22, (0, 0, 8.35), GOLD, subdiv=1)
    door(B, (0, -1.88, 0.8), 1.0, 1.9, WOOD_D)
    window(G, B, (0.0, -1.62, 4.2), 0.6, 0.7, frame=WOOD_D)
    window(G, B, (-1.55, -0.5, 2.6), 0.5, 0.6, frame=WOOD_D)
    B.box((1.0, 0.8, 0.9), (0, -1.55, 6.3), WOOD_D, bevel=0.1, segs=1)    # Achslager vorn
    for i in range(3):                                                    # Mehlsäcke
        sack(B, (1.4 + i * 0.55, -2.0 - (i % 2) * 0.4, 0.8), 1.0, "EADCB8", i * 30)
    for x, y in ((-2.3, -1.6), (2.4, 1.2), (-2.0, 1.9)):
        tuft(B, x, y, 0.8, 6, 1.1, int(x * 10))
    for i in range(7):                                                    # Blumen am Hügel
        a = rng.uniform(0, 6.28)
        B.ball(0.12, (math.cos(a) * 2.6, math.sin(a) * 2.6, 0.82), rng.choice(["F7C531", "E04848", "FFFFFF", "B77BFF"]), subdiv=1)
    B.build("body", root)
    G.build("win_glow", root)
    s = Part()
    for k in range(4):                                                    # Flügel: Holzgitter mit Tuch
        m = rot(0, 0, k * 90)
        s.box((0.22, 4.0, 0.12), (0, 0, 0), WOOD_D, r=m @ T(0, 2.2, 0), bevel=0.04, segs=1)
        s.box((1.0, 3.3, 0.06), (0, 0, 0), CREAM, r=m @ T(0.55, 2.5, 0.04), bevel=0.03, segs=1)
        for j in range(4):
            s.box((1.05, 0.08, 0.1), (0, 0, 0), WOOD_D, r=m @ T(0.55, 1.2 + j * 0.85, 0.06))
    s.cyl(0.38, 0.5, (0, 0, 0.1), RED_D, sides=10)
    o = s.build("spin_sails", root, (0, -2.05, 6.3))
    o.rotation_euler = (math.radians(90), 0, 0)
    fin(name, yaw=-30, pitch=18)


@model("lm_forst")
def lm_forst(name):
    """Uralte Riesenkiefer mit Baumhaus und Strickleiter."""
    root, B, G = start(name)
    rng = random.Random(2)
    B.cyl(1.5, 7.5, (0, 0, 3.75), BARK, r2=0.9, sides=12)
    for a in range(0, 360, 60):                                           # Wurzeln
        ra = math.radians(a + 15)
        limb(B, (0, 0, 0.6), (math.cos(ra) * 2.6, math.sin(ra) * 2.6, 0.0), 0.5, 0.15, shade(BARK, 0.85), 6)
    # Baumhaus
    B.box((3.6, 3.0, 0.25), (0.3, -0.3, 4.4), WOOD, bevel=0.06, segs=1)
    B.box((2.4, 2.0, 1.6), (0.6, -0.7, 5.35), WOOD_L, bevel=0.08, segs=1)
    gable(B, (0.6, -0.7, 6.15), 2.4, 2.0, 0.9, GREEN_D, over=0.25, thick=0.18, fill=WOOD_L)
    door(B, (0.95, -1.71, 4.55), 0.7, 1.2, WOOD_D)
    window(G, B, (0.1, -1.72, 5.4), 0.5, 0.5, frame=WOOD_D)
    for x in (-1.4, 2.0):
        for y in (-1.7, 1.1):
            B.cyl(0.08, 0.9, (x, y, 4.95), WOOD_D, sides=5)
    B.box((3.5, 0.08, 0.08), (0.3, -1.75, 5.35), WOOD_D)
    for i in range(9):                                                    # Strickleiter
        B.box((0.7, 0.08, 0.06), (1.9, -1.9, 0.4 + i * 0.45), WOOD_L)
    B.cyl(0.03, 4.3, (1.6, -1.9, 2.2), CUT_D, sides=4)
    B.cyl(0.03, 4.3, (2.2, -1.9, 2.2), CUT_D, sides=4)
    for i in range(5):                                                    # Pilze am Fuß
        a = rng.uniform(0, 6.28)
        mushroom(B, math.cos(a) * 2.0, math.sin(a) * 2.0, 0, rng.uniform(0.8, 1.4))
    B.build("body", root)
    G.build("win_glow", root)
    c = Part()                                                            # Krone: Stufenkegel
    for i in range(4):
        r = 4.2 * (1.0 - 0.2 * i)
        c.cone(r, 3.0, (0, 0, i * 1.9), shade("3F7F3E", 1.0 + 0.1 * i), r=rot(0, 0, i * 25), sides=12)
    c.build("body_crown", root, (0, 0, 7.4))
    for k, (x, y) in enumerate(((-1.2, -1.75), (2.2, -1.2))):            # Laternen am Geländer
        l = Part()
        l.cyl(0.02, 0.3, (0, 0, -0.15), DK, sides=4)
        l.box((0.22, 0.22, 0.3), (0, 0, -0.45), GLOW, bevel=0.05, segs=1)
        l.build("sway_lamp%d_glow" % k, root, (x, y, 6.0))
    fin(name, yaw=-30, pitch=16)


@model("lm_staub")
def lm_staub(name):
    """Rostiger Wasserturm mit Windrad-Pumpe."""
    root, B, G = start(name)
    rng = random.Random(3)
    for sx in (-1, 1):
        for sy in (-1, 1):
            limb(B, (sx * 2.2, sy * 2.2, 0), (sx * 1.3, sy * 1.3, 6.0), 0.16, 0.13, RUST_D, 6)
    for z in (2.0, 4.0):
        k = 2.2 - (z / 6.0) * 0.9
        for a, b in (((-k, -k), (k, -k)), ((k, -k), (k, k)), ((k, k), (-k, k)), ((-k, k), (-k, -k))):
            beam(B, (a[0], a[1], z), (b[0], b[1], z), 0.12, RUST)
    B.cyl(2.2, 2.8, (0, 0, 7.4), RUST, sides=14, bevel=0.1)               # Tank
    for z in (6.4, 7.4, 8.4):
        B.cyl(2.24, 0.12, (0, 0, z), RUST_D, sides=14)
    B.cone(2.4, 1.2, (0, 0, 9.4), RUST_D, sides=14)
    B.box((3.2, 0.12, 0.9), (0, -2.25, 7.5), CREAM, bevel=0.04, segs=1)   # Schild
    for i in range(5):
        B.box((0.35, 0.14, 0.5), (-1.2 + i * 0.6, -2.3, 7.5), rng.choice([RED_D, BLUE_D, DK]))
    tube(B, (1.4, -1.4, 6.0), (1.4, -1.4, 0.3), 0.14, STEEL)              # Rohr mit Trog
    B.box((2.0, 0.9, 0.5), (1.6, -2.4, 0.25), WOOD_D, bevel=0.05, segs=1)
    B.box((1.8, 0.7, 0.1), (1.6, -2.4, 0.45), "4A9FDC")
    big_rock(B, (-2.6, -1.8, 0), 0.9, ROCK, rng)
    for x, y in ((2.8, 1.5), (-2.6, 2.4)):
        B.cyl(0.32, 1.4, (x, y, 0.7), "5FA54A", r2=0.28, sides=8)         # Kakteen
        limb(B, (x, y, 0.8), (x + 0.5, y, 1.2), 0.14, 0.12, "5FA54A", 6)
    # Windrad-Mast
    limb(B, (-1.8, 1.8, 0), (-1.8, 1.8, 10.5), 0.12, 0.1, STEEL, 6)
    B.box((0.3, 1.4, 0.4), (-1.8, 2.3, 10.5), STEEL, bevel=0.04, segs=1)
    B.box((0.05, 1.2, 0.8), (-1.8, 3.1, 10.6), RED_D)                     # Fahne
    B.build("body", root)
    w = Part()
    for k in range(12):
        w.box((0.36, 1.3, 0.04), (0, 0, 0), CREAM if k % 2 else RED, r=rot(0, 0, k * 30) @ T(0, 0.9, 0) @ rot(0, 25, 0))
    w.cyl(0.2, 0.3, (0, 0, 0), DK, sides=8)
    o = w.build("spin_wheel", root, (-1.8, 1.45, 10.5))
    o.rotation_euler = (math.radians(90), 0, 0)
    fin(name, yaw=-30, pitch=16)


@model("lm_kueste")
def lm_kueste(name):
    """Leuchtturm auf Felsen, rot-weiß gestreift."""
    root, B, G = start(name)
    rng = random.Random(4)
    for i in range(6):
        a = i * 60 + 10
        big_rock(B, (math.cos(math.radians(a)) * 2.4, math.sin(math.radians(a)) * 2.4, 0), rng.uniform(1.0, 1.6), rng.choice([ROCK, ROCK_D, ROCK_L]), rng)
    B.cyl(2.3, 0.8, (0, 0, 0.4), ROCK_D, r2=2.0, sides=14)
    for i in range(5):                                                    # Turm in Streifen
        z0 = 0.8 + i * 1.7
        r0 = 1.55 - i * 0.12
        B.cyl(r0, 1.7, (0, 0, z0 + 0.85), RED if i % 2 == 0 else WHITE, r2=r0 - 0.12, sides=14)
    door(B, (0, -1.5, 0.8), 0.8, 1.7, BLUE_D)
    window(G, B, (0, -1.3, 4.3), 0.4, 0.6, frame=DK)
    window(G, B, (0, -1.06, 7.6), 0.4, 0.6, frame=DK)
    B.cyl(1.25, 0.2, (0, 0, 9.4), DK, sides=14)                           # Galerie
    for k in range(12):
        a = math.radians(k * 30)
        B.cyl(0.04, 0.6, (math.cos(a) * 1.2, math.sin(a) * 1.2, 9.8), DK, sides=4)
    B.torus(1.2, 0.05, (0, 0, 10.1), DK, seg=16, tseg=4)
    B.cyl(0.75, 1.3, (0, 0, 10.15), "BFE6FF", sides=10)                   # Laternenhaus (Glas)
    B.cone(0.95, 0.9, (0, 0, 11.25), RED_D, sides=10)
    B.ball(0.16, (0, 0, 11.75), GOLD, subdiv=1)
    B.cyl(0.04, 2.0, (2.6, -0.8, 1.6), WOOD_D, sides=5)                   # Bootssteg-Pfahl mit Rettungsring
    B.torus(0.3, 0.09, (2.6, -0.92, 1.8), "F28A1E", r=rot(90, 0, 0), seg=12, tseg=6)
    B.build("body", root)
    G.build("win_glow", root)
    l = Part()
    l.cyl(0.32, 0.6, (0, 0, 0), GLOW, sides=8)
    l.box((0.5, 1.3, 0.3), (0, -0.55, 0), GLOW, bevel=0.08, segs=1)        # Lichtkegel-Spiegel
    l.build("spin_light_glow", root, (0, 0, 10.15))
    fin(name, yaw=-30, pitch=16)


@model("lm_sumpf")
def lm_sumpf(name):
    """Alter Fabrikschlot mit Kesselhaus und grünen Rohren."""
    root, B, G = start(name)
    rng = random.Random(5)
    B.box((5.6, 4.0, 0.3), (0, 0, 0.15), CONC_D, bevel=0.08, segs=1)
    B.box((4.2, 3.0, 3.0), (-0.6, 0.2, 1.8), BRICK, bevel=0.08, segs=1)   # Kesselhaus
    for z in (0.9, 1.6, 2.3, 3.0):
        B.box((4.24, 3.04, 0.06), (-0.6, 0.2, z), BRICK_D)
    B.box((4.6, 3.4, 0.25), (-0.6, 0.2, 3.4), DK, bevel=0.05, segs=1)
    door(B, (0.2, -1.32, 0.3), 1.4, 2.0, "5E6E44")
    window(G, B, (-1.8, -1.32, 2.1), 0.8, 0.6, frame=DK)
    B.cyl(0.95, 9.0, (1.6, 1.0, 4.8), BRICK, r2=0.7, sides=12)            # Schlot
    for z in (2.5, 5.0, 7.5, 9.0):
        B.cyl(1.0 - z * 0.03, 0.18, (1.6, 1.0, z), BRICK_D, sides=12)
    B.cyl(0.85, 0.3, (1.6, 1.0, 9.4), DK, sides=12)
    B.cyl(1.0, 1.8, (2.2, -1.2, 1.2), RUST, sides=12, r=rot(0, 90, 0))     # Kessel liegend
    for x in (1.5, 2.9):
        B.cyl(1.04, 0.1, (x, -1.2, 1.2), RUST_D, sides=12, r=rot(0, 90, 0))
    B.build("body", root)
    G.build("win_glow", root)
    pg = Part()                                                           # leuchtende Giftrohre
    tube(pg, (-2.6, -1.4, 0.4), (-2.6, -1.4, 2.6), 0.2, SLIME_D)
    tube(pg, (-2.6, -1.4, 2.6), (-0.6, -1.4, 2.6), 0.2, SLIME_D)
    tube(pg, (3.1, -1.2, 1.2), (3.1, -1.2, 0.2), 0.2, SLIME_D)
    pg.cyl(0.7, 0.12, (3.2, -2.2, 0.06), SLIME_L, sides=12)
    pg.build("pipe_glow", root)
    empty("fx_smoke1", root, (1.6, 1.0, 9.6))
    empty("fx_steam2", root, (2.9, -1.2, 2.2))
    fin(name, yaw=-30, pitch=16)


@model("lm_frost")
def lm_frost(name):
    """Gefrorener Wasserfall unter einem Eisbogen."""
    root, B, G = start(name)
    rng = random.Random(6)
    for x, h in ((-2.6, 7.5), (2.6, 7.0)):                               # Felspfeiler
        B.box((2.0, 2.2, h), (x, 0.6, h * 0.5), ROCK, r=rot(0, 0, rng.uniform(-8, 8)), bevel=0.4, segs=2)
        B.box((2.2, 2.4, 0.5), (x, 0.6, h + 0.1), SNOW, bevel=0.2, segs=2)
    B.box((7.4, 2.6, 1.4), (0, 0.6, 7.6), ROCK_D, bevel=0.5, segs=2)      # Bogen oben
    B.box((7.6, 2.8, 0.6), (0, 0.6, 8.5), SNOW, bevel=0.25, segs=2)
    for i in range(6):                                                    # Eiszapfen
        B.cone(0.25, 1.3, (-2.2 + i * 0.9, -0.5, 6.4), ICE_L, r=rot(180, 0, 0), sides=6)
    B.box((7.0, 3.6, 0.4), (0, 0.0, 0.2), SNOW, bevel=0.15, segs=2)
    B.build("body", root)
    ic = Part()                                                           # Wasserfall aus Eis
    for i in range(5):
        x = -1.2 + i * 0.6
        ic.box((0.62, 0.5, 6.4 - abs(i - 2) * 0.4), (x, 0.9, 3.4 - abs(i - 2) * 0.2), ICE if i % 2 else ICE_L, bevel=0.2, segs=2)
    ic.cyl(2.0, 0.3, (0, -0.4, 0.4), ICE_D, sides=14)                     # zugefrorener Teich
    for i in range(4):
        ic.cone(0.35, 1.0 + i * 0.3, (-1.6 + i * 1.1, -1.4, 0.8), ICE_L, r=rot(rng.uniform(-12, 12), rng.uniform(-12, 12), 0), sides=5)
    ic.build("ice_glow", root)
    fin(name, yaw=-30, pitch=16)


@model("lm_krater")
def lm_krater(name):
    """Schleimportal: Steinring um einen pulsierenden Schleimkern."""
    root, B, G = start(name)
    rng = random.Random(7)
    B.cyl(3.6, 0.6, (0, 0, 0.3), ROCK_D, r2=3.2, sides=16)
    for k in range(9):                                                    # Steinzähne im Kreis
        a = math.radians(k * 40)
        B.cone(0.6, rng.uniform(1.6, 2.8), (math.cos(a) * 3.0, math.sin(a) * 3.0, 1.3), ROCK, r=rot(rng.uniform(-10, 10), rng.uniform(-10, 10), 0), sides=6)
    for sx in (-1, 1):                                                    # Portalbogen
        B.box((0.9, 0.9, 6.2), (sx * 2.2, 0.4, 3.6), "4A4458", bevel=0.25, segs=2)
    B.box((5.4, 1.0, 0.9), (0, 0.4, 6.9), "4A4458", bevel=0.3, segs=2)
    B.cone(0.5, 1.2, (0, 0.4, 7.9), "4A4458", sides=6)
    B.build("body", root)
    c = Part()
    c.ball(1.4, (0, 0, 0), "3F8F2A", scale=(1.0, 0.6, 1.25), subdiv=3)
    c.ball(0.6, (0, -0.45, 0.1), "8BC43A", scale=(1.0, 0.5, 1.2), subdiv=2)
    c.build("pulse_core_glow", root, (0, 0.4, 3.6))
    r = Part()
    r.torus(2.0, 0.12, (0, 0, 0), SLIME, seg=24, tseg=6)
    for k in range(6):
        a = math.radians(k * 60)
        r.box((0.3, 0.3, 0.3), (math.cos(a) * 2.0, math.sin(a) * 2.0, 0), "C8EE5A", r=rot(45, 45, 0), bevel=0.06, segs=1)
    o = r.build("spin_ring", root, (0, 0.4, 3.6))
    o.rotation_euler = (math.radians(90), 0, 0)
    g = Part()
    g.cyl(2.6, 0.08, (0, 0, 0.62), "4F9F2E", sides=16)                     # Schleimpfütze
    g.build("pool_glow", root)
    fin(name, yaw=-30, pitch=16)


# ================================================================== Quellen
@model("n_src_gruental")
def src_gruental(name):
    """Bienenstock auf einem Holzbock (Honig)."""
    root, B, G = start(name)
    B.box((1.2, 1.0, 0.1), (0, 0, 0.7), WOOD_D, bevel=0.03, segs=1)
    for x in (-0.5, 0.5):
        for y in (-0.4, 0.4):
            B.box((0.1, 0.1, 0.7), (x, y, 0.35), WOOD_D)
    for i in range(4):
        B.cyl(0.55 - abs(i - 1.5) * 0.08, 0.28, (0, 0, 0.9 + i * 0.26), "E8B84A" if i % 2 else "D9A03A", sides=12, bevel=0.06)
    B.cone(0.42, 0.4, (0, 0, 2.0), "D9A03A", sides=12)
    B.box((0.2, 0.06, 0.12), (0, -0.52, 1.05), DK)                        # Flugloch
    for x, y in ((0.7, -0.6), (-0.7, 0.5)):
        B.ball(0.12, (x, y, 0.15), "F7C531", subdiv=1)
    B.build("body", root)
    h = Part()
    h.ball(0.2, (0, 0, 0), "FFC63A", scale=(1.0, 1.0, 0.6), subdiv=2)       # Honigtropfen
    h.build("bob_honey_glow", root, (0.3, -0.55, 0.85))
    fin(name, yaw=-30, pitch=20)


@model("n_src_forst")
def src_forst(name):
    """Harzkiefer mit Zapfrinne und Eimer."""
    root, B, G = start(name)
    B.cyl(0.42, 3.4, (0, 0, 1.7), BARK, r2=0.3, sides=9)
    B.box((0.5, 0.08, 0.7), (0, -0.4, 1.0), CUT, r=rot(0, 0, 0))         # Rindenschnitt
    for i in range(3):
        B.box((0.42, 0.06, 0.05), (0, -0.44, 0.75 + i * 0.22), "C8924E", r=rot(0, 25 * (1 if i % 2 else -1), 0))
    B.cyl(0.2, 0.28, (0.0, -0.62, 0.4), STEEL, sides=10)                  # Eimer
    for a in (0, 120, 240):
        limb(B, (0, 0, 2.6), (math.cos(math.radians(a)) * 0.9, math.sin(math.radians(a)) * 0.9, 3.0), 0.08, 0.04, BARK, 5)
    for i in range(3):
        B.cone(1.3 - i * 0.3, 1.3, (0, 0, 3.0 + i * 0.75), shade("3F7F3E", 1.0 + i * 0.1), sides=10)
    B.build("body", root)
    g = Part()
    g.cyl(0.17, 0.05, (0.0, -0.62, 0.52), "FFB43A", sides=10)
    g.ball(0.08, (0, -0.47, 0.95), "FFB43A", subdiv=1)
    g.build("resin_glow", root)
    fin(name, yaw=-30, pitch=18)


@model("n_src_staub")
def src_staub(name):
    """Wasserkaktus mit Zapfhahn."""
    root, B, G = start(name)
    B.cyl(0.45, 2.2, (0, 0, 1.1), "5FA54A", r2=0.4, sides=10, bevel=0.1)
    B.ball(0.42, (0, 0, 2.2), "6DB858", subdiv=2)
    for sx in (-1, 1):
        limb(B, (0, 0, 1.1), (sx * 0.8, 0, 1.3), 0.22, 0.2, "5FA54A", 7)
        B.cyl(0.2, 0.7, (sx * 0.8, 0, 1.6), "5FA54A", sides=7)
        B.ball(0.2, (sx * 0.8, 0, 1.95), "6DB858", subdiv=1)
    B.ball(0.14, (0.2, -0.2, 2.6), "F77FB0", subdiv=1)                   # Blüte
    B.box((0.12, 0.3, 0.1), (0.0, -0.5, 0.8), STEEL)                      # Hahn
    B.box((0.1, 0.1, 0.2), (0.0, -0.62, 0.72), STEEL)
    B.cyl(0.18, 0.22, (0.0, -0.66, 0.11), WOOD, sides=8)                  # Becher
    B.build("body", root)
    w = Part()
    w.ball(0.07, (0, 0, 0), "8FE0FF", scale=(1, 1, 1.4), subdiv=1)
    w.build("bob_drop_glow", root, (0.0, -0.62, 0.5))
    fin(name, yaw=-30, pitch=18)


@model("n_src_kueste")
def src_kueste(name):
    """Muschelbank mit Perlmuscheln auf einem Fels."""
    root, B, G = start(name)
    rng = random.Random(8)
    big_rock(B, (0, 0.2, 0), 1.3, ROCK_L, rng)
    for i in range(6):
        a = math.radians(i * 60 + 15)
        x, y = math.cos(a) * 0.8, math.sin(a) * 0.7
        B.ball(0.3, (x, y, 0.35 + (i % 2) * 0.2), "E9A8B8" if i % 2 else "F2D2B0", scale=(1.0, 0.8, 0.45), r=rot(0, 0, i * 60), subdiv=2)
        for k in range(3):
            B.box((0.04, 0.5, 0.05), (x, y, 0.42 + (i % 2) * 0.2), shade("E9A8B8", 0.8), r=rot(0, 0, i * 60 + (k - 1) * 25))
    B.build("body", root)
    g = Part()
    g.ball(0.11, (0.1, -0.75, 0.75), "FFFFFF", subdiv=2)
    g.ball(0.08, (-0.6, -0.5, 0.6), "FFFFFF", subdiv=1)
    g.build("pearl_glow", root)
    fin(name, yaw=-30, pitch=24)


@model("n_src_sumpf")
def src_sumpf(name):
    """Kleine Ölquelle: Holzbohrturm über einer schwarzen Pfütze."""
    root, B, G = start(name)
    for sx in (-1, 1):
        for sy in (-1, 1):
            limb(B, (sx * 0.8, sy * 0.8, 0), (sx * 0.2, sy * 0.2, 2.8), 0.07, 0.06, WOOD_D, 5)
    for z in (0.9, 1.8):
        k = 0.8 - z / 2.8 * 0.6
        for a, b in (((-k, -k), (k, -k)), ((k, -k), (k, k)), ((k, k), (-k, k)), ((-k, k), (-k, -k))):
            beam(B, (a[0], a[1], z), (b[0], b[1], z), 0.06, WOOD)
    B.box((0.6, 0.6, 0.15), (0, 0, 2.85), WOOD_D)
    B.cyl(0.12, 2.0, (0, 0, 1.0), STEEL, sides=8)
    B.cyl(0.95, 0.04, (0, 0, 0.02), "1E1E26", sides=14)                   # Ölpfütze
    B.build("body", root)
    o = Part()
    o.ball(0.22, (0, 0, 0), "26262E", scale=(1, 1, 0.6), subdiv=2)
    o.build("bob_oil", root, (0.0, 0.0, 0.15))
    fin(name, yaw=-30, pitch=20)


@model("n_src_frost")
def src_frost(name):
    """Eiskristall-Gruppe auf Schnee."""
    root, B, G = start(name)
    rng = random.Random(9)
    B.cyl(1.0, 0.2, (0, 0, 0.1), SNOW, r2=0.85, sides=12, bevel=0.06)
    B.build("body", root)
    c = Part()
    for i in range(6):
        a = rng.uniform(0, 6.28)
        r = rng.uniform(0.0, 0.5)
        h = rng.uniform(0.8, 1.9) if i else 2.3
        c.cyl(0.2, h, (0, 0, 0), ICE if i % 2 else ICE_L, r=T(math.cos(a) * r, math.sin(a) * r, h * 0.5 + 0.1) @ rot(rng.uniform(-18, 18), rng.uniform(-18, 18), 0), r2=0.0, sides=6)
    c.build("ice_glow", root)
    fin(name, yaw=-30, pitch=20)


@model("n_src_krater")
def src_krater(name):
    """Schleimgeysir: Steinkranz mit blubberndem Schleim."""
    root, B, G = start(name)
    rng = random.Random(10)
    for k in range(8):
        a = math.radians(k * 45)
        rockc(B, (0.5, 0.4, 0.45), (math.cos(a) * 0.75, math.sin(a) * 0.75, 0.22), ROCK_D, rng)
    B.build("body", root)
    g = Part()
    g.cyl(0.65, 0.12, (0, 0, 0.18), SLIME, sides=12)
    g.build("slime_glow", root)
    b = Part()
    b.ball(0.3, (0, 0, 0), SLIME_L, scale=(1, 1, 0.8), subdiv=2)
    b.ball(0.16, (0.25, 0.1, 0.2), SLIME_L, subdiv=1)
    b.build("pulse_blob_glow", root, (0, 0, 0.3))
    empty("fx_steam1", root, (0, 0, 0.6))
    fin(name, yaw=-30, pitch=22)


# ================================================================== Werkzeuge (nur Symbole)
def _handle(p, a, b, r=0.05, color=WOOD):
    limb(p, a, b, r, r * 0.9, color, 8)


@model("tool_smoker")
def tool_smoker(name):
    root, B, G = start(name)
    B.cyl(0.18, 0.45, (0, 0, 0.3), STEEL_L, sides=12, bevel=0.03)
    B.cone(0.18, 0.2, (0, 0, 0.62), STEEL, sides=12)
    B.box((0.25, 0.08, 0.3), (0.3, 0, 0.3), "8A5A30", bevel=0.03, segs=1)  # Blasebalg
    B.build("body", root)
    fin(name, keep_glb=False, size=128, ao=False)


@model("tool_tapper")
def tool_tapper(name):
    root, B, G = start(name)
    _handle(B, (0, 0, 0), (0, 0, 0.35), 0.05, WOOD)
    B.box((0.06, 0.02, 0.35), (0, 0, 0.53), STEEL_L, bevel=0.01, segs=1)
    B.cone(0.03, 0.08, (0, 0, 0.74), STEEL_L, sides=4)
    B.build("body", root)
    fin(name, keep_glb=False, size=128, ao=False)


@model("tool_tap")
def tool_tap(name):
    root, B, G = start(name)
    B.cyl(0.05, 0.4, (0, 0, 0.2), STEEL, r=rot(90, 0, 0), sides=8)
    B.box((0.08, 0.08, 0.15), (0, -0.2, 0.12), STEEL)
    B.cyl(0.03, 0.2, (0, 0.05, 0.32), RED, sides=6)
    B.box((0.2, 0.04, 0.04), (0, 0.05, 0.42), RED)
    B.build("body", root)
    fin(name, keep_glb=False, size=128, ao=False)


@model("tool_knife")
def tool_knife(name):
    root, B, G = start(name)
    _handle(B, (0, 0, 0), (0, 0, 0.18), 0.04, "3A7FC8")
    B.box((0.08, 0.02, 0.22), (0, 0, 0.3), STEEL_L, bevel=0.01, segs=1)
    B.ball(0.08, (0.12, 0, 0.05), "E9A8B8", scale=(1, 0.7, 0.4), subdiv=1)
    B.build("body", root)
    fin(name, keep_glb=False, size=128, ao=False)


@model("tool_pump")
def tool_pump(name):
    root, B, G = start(name)
    B.cyl(0.1, 0.5, (0, 0, 0.25), "C8A23A", sides=10)
    B.cyl(0.03, 0.3, (0, 0, 0.65), STEEL, sides=6)
    B.box((0.3, 0.05, 0.05), (0, 0, 0.8), DK)
    B.cyl(0.03, 0.4, (0.12, 0, 0.1), DK, r=rot(0, 70, 0), sides=6)
    B.build("body", root)
    fin(name, keep_glb=False, size=128, ao=False)


@model("tool_icepick")
def tool_icepick(name):
    root, B, G = start(name)
    _handle(B, (0, 0, 0), (0, 0, 0.6), 0.035, WOOD)
    B.box((0.45, 0.04, 0.06), (0.05, 0, 0.6), STEEL_L, bevel=0.01, segs=1)
    B.cone(0.04, 0.15, (0.33, 0, 0.56), STEEL_L, r=rot(0, 110, 0), sides=4)
    B.build("body", root)
    fin(name, keep_glb=False, size=128, ao=False)


@model("tool_canister")
def tool_canister(name):
    root, B, G = start(name)
    B.box((0.3, 0.16, 0.38), (0, 0, 0.19), "2F8F5A", bevel=0.04, segs=2)
    B.box((0.16, 0.04, 0.06), (0, 0, 0.42), DK)
    B.cyl(0.04, 0.08, (0.1, 0, 0.42), DK, sides=6)
    B.box((0.2, 0.18, 0.06), (0, 0, 0.2), SLIME_L)
    B.build("body", root)
    fin(name, keep_glb=False, size=128, ao=False)


# ================================================================== Kleinkram
@model("p_journal")
def p_journal(name):
    root, B, G = start(name)
    B.cyl(0.35, 0.06, (0, 0, 0.03), ROCK, sides=10)
    B.build("body", root)
    g = Part()
    g.box((0.42, 0.03, 0.56), (0, 0, 0), CREAM, r=rot(0, 0, 0), bevel=0.01, segs=1)
    for i in range(5):
        g.box((0.3, 0.035, 0.025), (0, 0, 0.18 - i * 0.09), "8A6A4A")
    g.box((0.05, 0.04, 0.08), (0.2, 0, 0.27), RED)
    g.build("bob_page_glow", root, (0, 0, 0.62))
    fin(name, keep_glb=True, size=128)


@model("p_egg")
def p_egg(name):
    root, B, G = start(name)
    B.ball(0.28, (0, 0, 0.33), "F4EBD6", scale=(1, 1, 1.25), subdiv=3)
    for i, (a, z) in enumerate(((20, 0.45), (140, 0.3), (250, 0.5), (300, 0.2), (80, 0.18))):
        ra = math.radians(a)
        B.ball(0.06, (math.cos(ra) * 0.25, math.sin(ra) * 0.25, z), ["6FA0E0", "E07A5A", "7AC05A"][i % 3], scale=(1, 1, 0.4), r=face_to((math.cos(ra), math.sin(ra), 0)), subdiv=1)
    B.build("body", root)
    fin(name, keep_glb=True, size=128)


@model("p_egg_nest")
def p_egg_nest(name):
    root, B, G = start(name)
    rng = random.Random(11)
    for k in range(14):
        a = math.radians(k * 26)
        limb(B, (math.cos(a) * 0.55, math.sin(a) * 0.55, 0.15), (math.cos(a + 1.2) * 0.55, math.sin(a + 1.2) * 0.55, 0.2 + rng.uniform(-0.05, 0.05)), 0.05, 0.04, "A8743A", 4)
    B.cyl(0.55, 0.16, (0, 0, 0.08), "8A5A30", r2=0.45, sides=12)
    B.build("body", root)
    g = Part()
    g.ball(0.24, (0, 0, 0.42), "F4EBD6", scale=(1, 1, 1.25), subdiv=2)
    g.build("egg_glow", root)
    fin(name, keep_glb=True, size=128)


@model("p_dummy")
def p_dummy(name):
    """Trainingspuppe: Pfahl mit Strohsack-Körper und Zielscheibe."""
    root, B, G = start(name)
    B.cyl(0.45, 0.2, (0, 0, 0.1), WOOD_D, sides=10)
    B.cyl(0.08, 0.9, (0, 0, 0.6), WOOD_D, sides=6)
    B.build("body", root)
    d = Part()
    d.cyl(0.32, 0.9, (0, 0, 0.45), "D9C08A", r2=0.28, sides=10, bevel=0.06)
    for z in (0.2, 0.7):
        d.cyl(0.33, 0.06, (0, 0, z), "8A5A30", sides=10)
    d.ball(0.25, (0, 0, 1.15), "D9C08A", subdiv=2)
    d.box((0.9, 0.12, 0.12), (0, 0, 0.75), WOOD, bevel=0.03, segs=1)       # Arme
    d.cyl(0.26, 0.04, (0, -0.33, 0.45), "FFFFFF", r=rot(90, 0, 0), sides=14)
    d.cyl(0.18, 0.045, (0, -0.335, 0.45), RED, r=rot(90, 0, 0), sides=14)
    d.cyl(0.09, 0.05, (0, -0.34, 0.45), "FFFFFF", r=rot(90, 0, 0), sides=10)
    d.cyl(0.04, 0.055, (0, -0.345, 0.45), RED, r=rot(90, 0, 0), sides=8)
    d.build("sway_dummy", root, (0, 0, 1.0))
    fin(name, yaw=-30, pitch=18, size=128)


@model("n_meteor")
def n_meteor(name):
    root, B, G = start(name)
    rng = random.Random(12)
    B.cyl(1.1, 0.15, (0, 0, 0.07), "4A4458", r2=0.9, sides=12)            # Krater
    rockc(B, (1.1, 0.95, 0.9), (0, 0, 0.45), "3A3442", rng, 0.3)
    B.build("body", root)
    g = Part()
    for i in range(5):
        a = rng.uniform(0, 6.28)
        g.box((0.22, 0.16, 0.3), (math.cos(a) * 0.4, math.sin(a) * 0.35, 0.6 + rng.uniform(-0.1, 0.2)), "FF7A3A" if i % 2 else SLIME_L, r=rot(rng.uniform(0, 60), rng.uniform(0, 60), 0), bevel=0.04, segs=1)
    g.build("rock_glow", root)
    fin(name, yaw=-30, pitch=22, size=128)


@model("c_barrow")
def c_barrow(name):
    """Schubkarre: Rad vorn (-Y), Griffe hinten (+Y) – die Hände des Bewohners greifen bei y ≈ +0,75."""
    root, B, G = start(name)
    B.box((0.55, 0.75, 0.25), (0, 0.0, 0.45), "3A7FC8", bevel=0.05, segs=1)
    B.box((0.45, 0.6, 0.06), (0, 0.0, 0.58), "8A8F98")
    for sx in (-1, 1):
        limb(B, (sx * 0.2, -0.45, 0.22), (sx * 0.24, 0.8, 0.55), 0.03, 0.03, WOOD_D, 5)
        limb(B, (sx * 0.2, 0.25, 0.4), (sx * 0.2, 0.3, 0.0), 0.025, 0.025, DK, 4)
    B.cyl(0.2, 0.08, (0, -0.48, 0.2), "23262E", r=rot(0, 90, 0), sides=12)
    B.cyl(0.08, 0.1, (0, -0.48, 0.2), STEEL, r=rot(0, 90, 0), sides=8)
    B.box((0.35, 0.35, 0.18), (0, 0.0, 0.66), ROCK, bevel=0.06, segs=1)    # Steinladung
    B.build("body", root)
    fin(name, yaw=-30, pitch=20, size=128)



MODELS = REG

if __name__ == "__main__":
    args = sys.argv[1:]
    if args == ["list"]:
        print("\n".join(MODELS))
        sys.exit(0)
    for n in (args or [k for k in MODELS if k.startswith(("lm_", "n_src_", "tool_", "p_journal", "p_egg", "p_dummy", "n_meteor", "c_barrow"))]):
        if n not in MODELS:
            print("unbekannt:", n, flush=True)
            continue
        MODELS[n]()
        print("ok", n, flush=True)
