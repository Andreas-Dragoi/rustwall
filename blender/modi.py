"""V6 Paket M – Spielmodi: Turm der Prüfungen, Überlebenskarte, Höhlen, Ladefläche des Pickups, Symbole.

Aufruf:  python3 blender/modi.py [namen…]     (ohne Namen: alle; "list" zeigt die Namen)

| Name | Bedeutung | Objekte mit Wirkung |
|---|---|---|
| mt_floor_<1..5> | runder Arenaboden des Turms (Radius 16,5 m) je 10er-Block: 1 Moosgewölbe, 2 Sandsteinhalle, 3 Frostkammer, 4 Rostschmiede, 5 Glutspitze | `rune_glow` (Runenringe) |
| mt_wall_<1..5> | Wandstück der Arena, 4,6 m breit, Innenseite nach -Y | 5: `crack_glow` |
| mt_pillar_<1..5> | Säule mit Feuerschale zwischen den Toren | `pulse_flame_glow`, Leerobjekt `fx_spark` (4, 5) |
| mt_gate | Tor, aus dem die Gegner kommen (ersetzt ein Wandstück) | `rune_glow` |
| mt_generator | Generator der Aufgabe „Verteidige den Generator“ (2,6 × 2,6 m) | `spin_ring`, `pulse_core_glow`, `lamp_glow` |
| sv_barrier, sv_crates, sv_wreck, sv_container, sv_sandbags, sv_tower, sv_fence, sv_gate, sv_lamp | Deckung und Rand der Überlebenskarte „Schrottplatz“ | sv_gate/sv_lamp/sv_tower: `lamp_glow` |
| cv_<thema>_floor | Boden eines Höhlenraums 14 × 14 m (Themen: wurzel, sand, eis, glut) | wurzel: `shroom_glow`, eis: `ice_glow`, glut: `lava_glow` |
| cv_<thema>_hall | Boden eines Gangs 4 × 6 m (entlang Y) | wie floor |
| cv_<thema>_wall_1/2 | Felswand 2 m breit, 3,6 m hoch, Innenseite nach -Y | glut: `crack_glow`, eis: `ice_glow` |
| cv_<thema>_rock | Felssäule für Ecken (2,4 × 2,4 m) | – |
| cv_<thema>_deco_1/2 | Schmuck im Raum (Pilze, Wurzeln, Krüge, Schädel, Eiskristalle, Lavatümpel …) | `*_glow` |
| cv_<thema>_entry | Höhleneingang in der Expedition (7 × 6 m), Öffnung nach -Y | `pulse_torch_glow`; Leerobjekt `mouth` (Eingangspunkt) |
| cv_<thema>_ore | Erzader am Ende der Höhle | `ore_glow` |
| cv_torch | Fackel auf einem Pfahl | `pulse_flame_glow`; Leerobjekt `light` |
| cv_exit | Rückweg: Leiter nach oben mit Lichtschacht | `beam_glow` (Godot macht ihn durchscheinend) |
| v_pickup_rack | Ladegitter auf der Ladefläche der Pritsche (Ursprung = Leerobjekt turret des Fahrzeugs) | – |
| ui_tower, ui_survival, ui_raid, ui_cave | Symbole des Bildschirms „Modi“ | – |
"""
import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from exp_common import *
import weapons as WP

HOLE = "120E14"
WHITE = "F4F6FA"

# ================================================================== Turm der Prüfungen
BLOCK = {
    1: dict(st="8E9A84", st_d="66705E", st_l="AAB59E", acc="8BE04A", moss="5E9A32", name="moos"),
    2: dict(st="E0B46A", st_d="B9874A", st_l="F2CF8E", acc="FFC93E", cloth="C0392B", name="sand"),
    3: dict(st="BFD2E6", st_d="8FAFD0", st_l="E2EEF8", acc="6FE6FF", ice="9FE0FA", name="eis"),
    4: dict(st="8A7A70", st_d="5E5048", st_l="A89A8E", acc="FF9A3A", rust="A8562A", name="rost"),
    5: dict(st="3E3238", st_d="2A2228", st_l="57484F", acc="FF5A2A", lava="FF6A1E", name="glut"),
}


def _tile_ring(p, r0, r1, n, cols, z=0.05, h=0.08, gap=0.08, rng=None):
    """Ring aus Bodenplatten zwischen r0 und r1 (n Platten)."""
    w = r1 - r0
    rm = (r0 + r1) * 0.5
    seg = 2 * math.pi * rm / n - gap
    for i in range(n):
        a = 360.0 * (i + 0.5) / n
        c = cols[i % len(cols)]
        if rng is not None:
            c = vary(c, rng, 0.05)
        p.box((seg, w - gap, h), (0, 0, 0), c, r=rot(0, 0, a) @ T(0, rm, z + h * 0.5), bevel=0.03, segs=1)


@model("mt_floor_1", "mt_floor_2", "mt_floor_3", "mt_floor_4", "mt_floor_5")
def mt_floor(name):
    b = int(name[-1])
    c = BLOCK[b]
    root, B, G = start(name)
    rng = random.Random(b * 17)
    B.cyl(16.6, 0.36, (0, 0, -0.13), c["st_d"], sides=48)
    _tile_ring(B, 13.2, 16.4, 40, [c["st"], c["st_l"]], rng=rng)
    _tile_ring(B, 9.6, 13.0, 30, [c["st_l"], c["st"]], rng=rng)
    _tile_ring(B, 6.2, 9.4, 20, [c["st"], c["st_d"]], rng=rng)
    _tile_ring(B, 3.6, 6.0, 12, [c["st_l"], c["st"]], rng=rng)
    B.cyl(3.4, 0.14, (0, 0, 0.07), c["st_d"], sides=28)
    B.cyl(2.6, 0.18, (0, 0, 0.09), c["st"], sides=28, bevel=0.05, segs=1)
    WP.star(B, 1.7, 0.1, (0, 0, 0.2), c["st_l"], r=rot(90, 0, 0))
    # Runen: Ringe und Striche (leuchten)
    G.torus(15.0, 0.07, (0, 0, 0.13), c["acc"], seg=64, tseg=4)
    G.torus(3.5, 0.06, (0, 0, 0.17), c["acc"], seg=32, tseg=4)
    for i in range(8):
        a = 360.0 * i / 8 + 22.5
        G.box((0.14, 1.6, 0.04), (0, 0, 0), c["acc"], r=rot(0, 0, a) @ T(0, 7.8, 0.14))
        G.box((0.6, 0.14, 0.04), (0, 0, 0), c["acc"], r=rot(0, 0, a) @ T(0, 11.3, 0.14))
    # Schmuck je Block
    if b == 1:
        for i in range(26):
            a = rng.uniform(0, 6.283)
            r = rng.uniform(4.5, 15.5)
            B.ball(1.0, (math.cos(a) * r, math.sin(a) * r, 0.1), vary(c["moss"], rng, 0.12), scale=(rng.uniform(0.5, 1.1), rng.uniform(0.4, 0.9), 0.08), subdiv=1)
        for i in range(10):
            a = rng.uniform(0, 6.283)
            r = rng.uniform(13.5, 15.8)
            tuft(B, math.cos(a) * r, math.sin(a) * r, 0.12, 4, 0.8, i)
    elif b == 2:
        for i in range(16):
            a = rng.uniform(0, 6.283)
            r = rng.uniform(5.0, 15.5)
            B.ball(1.0, (math.cos(a) * r, math.sin(a) * r, 0.08), vary("F0CE8A", rng, 0.05), scale=(rng.uniform(0.9, 1.8), rng.uniform(0.5, 1.0), 0.1), r=rot(0, 0, rng.uniform(0, 180)), subdiv=1)
        for i in range(4):
            a = 90.0 * i + 45
            B.box((1.2, 2.4, 0.06), (0, 0, 0), c["cloth"], r=rot(0, 0, a) @ T(0, 5.0, 0.2), bevel=0.02, segs=1)
            B.box((1.3, 0.1, 0.07), (0, 0, 0), c["acc"], r=rot(0, 0, a) @ T(0, 6.2, 0.21))
    elif b == 3:
        for i in range(18):
            a = rng.uniform(0, 6.283)
            r = rng.uniform(4.0, 15.5)
            B.box((rng.uniform(0.8, 2.4), rng.uniform(0.5, 1.4), 0.05), (math.cos(a) * r, math.sin(a) * r, 0.14), vary(c["ice"], rng, 0.06), r=rot(0, 0, rng.uniform(0, 180)), bevel=0.02, segs=1)
        for i in range(12):
            a = rng.uniform(0, 6.283)
            r = rng.uniform(14.0, 15.9)
            B.ball(1.0, (math.cos(a) * r, math.sin(a) * r, 0.1), WHITE, scale=(0.7, 0.5, 0.18), subdiv=1)
    elif b == 4:
        for i in range(4):
            a = 90.0 * i
            B.box((2.2, 2.2, 0.08), (0, 0, 0), "3A3E4A", r=rot(0, 0, a) @ T(0, 7.8, 0.12), bevel=0.03, segs=1)
            for k in range(5):
                B.box((0.1, 1.9, 0.1), (0, 0, 0), "23262E", r=rot(0, 0, a) @ T(-0.8 + k * 0.4, 7.8, 0.15))
        for i in range(20):
            a = rng.uniform(0, 6.283)
            r = rng.uniform(4.0, 15.5)
            B.ball(1.0, (math.cos(a) * r, math.sin(a) * r, 0.1), vary(c["rust"], rng, 0.1), scale=(rng.uniform(0.3, 0.8), rng.uniform(0.3, 0.6), 0.05), subdiv=1)
    else:
        for i in range(14):                                                    # Glutrisse
            a = rng.uniform(0, 6.283)
            r = rng.uniform(4.5, 14.5)
            cx, cy = math.cos(a) * r, math.sin(a) * r
            yaw = rng.uniform(0, 180)
            for k in range(3):
                G.box((rng.uniform(0.6, 1.2), 0.08, 0.04), (0, 0, 0), c["lava"], r=T(cx, cy, 0.135) @ rot(0, 0, yaw + k * 35) @ T(0.4 * k, 0, 0))
        for i in range(10):
            a = rng.uniform(0, 6.283)
            r = rng.uniform(13.0, 15.6)
            rockc(B, (rng.uniform(0.5, 1.0), rng.uniform(0.4, 0.8), rng.uniform(0.3, 0.6)), (math.cos(a) * r, math.sin(a) * r, 0.2), "1E181C", rng)
    B.build("body", root)
    G.build("rune_glow", root)
    fin(name, yaw=-30, pitch=40, ao=False, size=192)


def _bricks(p, w, h, d, cols, rng, rows=4, y0=0.0, jit=0.05, bev=0.08):
    """Mauer aus versetzten Quadern: Breite w (x), Höhe h, Tiefe d (y ab y0)."""
    rh = h / rows
    for r in range(rows):
        n = 3 if r % 2 == 0 else 4
        bw = w / (n - (0.5 if r % 2 else 0.0))
        x = -w * 0.5 + (0 if r % 2 == 0 else -bw * 0.5)
        while x < w * 0.5 - 0.05:
            x0 = max(x, -w * 0.5)
            x1 = min(x + bw, w * 0.5)
            if x1 - x0 > 0.2:
                c = vary(cols[rng.randrange(len(cols))], rng, 0.06)
                p.box((x1 - x0 - 0.06, d + rng.uniform(-jit, jit), rh - 0.06), ((x0 + x1) * 0.5, y0 + d * 0.5 + rng.uniform(-jit, jit), r * rh + rh * 0.5), c, bevel=bev, segs=1)
            x += bw


@model("mt_wall_1", "mt_wall_2", "mt_wall_3", "mt_wall_4", "mt_wall_5")
def mt_wall(name):
    b = int(name[-1])
    c = BLOCK[b]
    root, B, G = start(name)
    rng = random.Random(b * 31)
    W, H, Dp = 4.6, 3.2, 1.2
    B.box((W + 0.1, Dp + 0.3, 0.3), (0, Dp * 0.5 - 0.1, 0.15), c["st_d"], bevel=0.05, segs=1)       # Sockel
    _bricks(B, W, H - 0.4, Dp, [c["st"], c["st_l"], c["st"]], rng, rows=4, y0=-0.05)
    for i in range(3):                                                                              # Zinnen
        x = -1.6 + i * 1.6
        B.box((1.0, Dp + 0.1, 0.5), (x, Dp * 0.5, H - 0.15), c["st_l"], bevel=0.08, segs=1)
    B.box((W + 0.05, Dp + 0.2, 0.14), (0, Dp * 0.5, H - 0.42), c["st_d"], bevel=0.04, segs=1)
    if b == 1:
        for i in range(5):
            x = rng.uniform(-2.0, 2.0)
            ln = rng.uniform(0.8, 2.0)
            B.box((rng.uniform(0.3, 0.6), 0.12, ln), (x, -0.12, H - 0.5 - ln * 0.5), vary(c["moss"], rng, 0.1), bevel=0.05, segs=1)
        for i in range(4):
            tuft(B, rng.uniform(-2.0, 2.0), Dp * 0.5, H + 0.1, 4, 0.7, i)
    elif b == 2:
        B.box((1.3, 0.06, 2.0), (0, -0.12, 1.55), c["cloth"], bevel=0.02, segs=1)                    # Wandbehang
        B.box((1.4, 0.1, 0.12), (0, -0.14, 2.58), c["acc"])
        B.cone(0.5, 0.4, (0, -0.16, 0.48), c["cloth"], r=rot(90, 0, 0), sides=3)
        WP.star(B, 0.3, 0.05, (0, -0.17, 1.7), c["acc"])
    elif b == 3:
        for i in range(9):
            x = -2.1 + i * 0.52 + rng.uniform(-0.1, 0.1)
            ln = rng.uniform(0.3, 0.9)
            B.cone(0.09, ln, (x, -0.1, H - 0.5 - ln * 0.5), c["ice"], r=rot(180, 0, 0), sides=5)
        for i in range(3):
            B.ball(1.0, (-1.6 + i * 1.6, Dp * 0.5, H + 0.12), WHITE, scale=(0.55, 0.6, 0.18), subdiv=1)
    elif b == 4:
        for x in (-1.6, 0.0, 1.6):
            B.box((0.12, 0.08, H - 0.8), (x, -0.1, (H - 0.4) * 0.5), "3A3E4A")
            for z in (0.5, 1.4, 2.3):
                B.ball(0.07, (x, -0.16, z), "C9CED8", subdiv=1)
        tube(B, (-2.3, -0.2, 2.2), (2.3, -0.2, 2.2), 0.12, c["rust"], sides=8)
    else:
        for i in range(4):
            x = rng.uniform(-1.8, 1.8)
            z0 = rng.uniform(0.4, 1.0)
            for k in range(3):
                G.box((0.07, 0.06, 0.55), (0, 0, 0), c["lava"], r=T(x + k * 0.12, -0.08, z0 + k * 0.45) @ rot(0, rng.uniform(-30, 30), 0))
    B.build("body", root)
    if len(G.bm.faces) > 0:
        G.build("crack_glow", root)
    else:
        G.bm.free()
    fin(name, yaw=-25, pitch=18, ao=True, size=128)


@model("mt_pillar_1", "mt_pillar_2", "mt_pillar_3", "mt_pillar_4", "mt_pillar_5")
def mt_pillar(name):
    b = int(name[-1])
    c = BLOCK[b]
    root, B, G = start(name)
    rng = random.Random(b * 7)
    B.box((1.7, 1.7, 0.4), (0, 0, 0.2), c["st_d"], bevel=0.08, segs=1)
    B.cyl(0.6, 3.4, (0, 0, 2.1), c["st"], sides=10, bevel=0.06, segs=1)
    for z in (0.7, 1.9, 3.1):
        B.cyl(0.66, 0.16, (0, 0, z), c["st_l"], sides=10, bevel=0.04, segs=1)
    B.cyl(0.9, 0.4, (0, 0, 3.95), c["st_d"], r2=1.0, sides=12, bevel=0.06, segs=1)                  # Schale
    B.cyl(0.85, 0.12, (0, 0, 4.18), "2A2228", sides=12)
    f = Part()
    col = c["acc"] if b != 3 else "8FF0FF"
    f.cone(0.55, 1.0, (0, 0, 0.5), col, sides=7)
    f.cone(0.32, 0.7, (0.12, 0.05, 0.6), "FFF2B0" if b != 3 else WHITE, sides=6)
    f.build("pulse_flame_glow", root, (0, 0, 4.22))
    if b == 1:
        for i in range(3):
            B.ball(1.0, (rng.uniform(-0.4, 0.4), -0.55, rng.uniform(0.8, 2.8)), c["moss"], scale=(0.4, 0.2, 0.5), subdiv=1)
    elif b == 2:
        B.box((0.08, 0.7, 1.4), (-0.62, 0, 2.4), c["cloth"])
    elif b == 3:
        for i in range(5):
            B.cone(0.08, 0.5, (math.cos(i * 1.25) * 0.85, math.sin(i * 1.25) * 0.85, 3.55), c["ice"], r=rot(180, 0, 0), sides=5)
    elif b == 4:
        for z in (1.3, 2.5):
            B.torus(0.64, 0.06, (0, 0, z), "3A3E4A", seg=16, tseg=4)
    if b >= 4:
        empty("fx_spark", root, (0, 0, 4.9))
    B.build("body", root)
    fin(name, yaw=-30, pitch=18, ao=True, size=128)


@model("mt_gate")
def mt_gate(name):
    root, B, G = start(name)
    W = 4.6
    B.box((W + 0.1, 1.5, 0.3), (0, 0.5, 0.15), "4A4450", bevel=0.05, segs=1)
    for sx in (-1, 1):
        B.box((0.85, 1.4, 3.4), (sx * (W * 0.5 - 0.42), 0.55, 1.7), "6E6672", bevel=0.1, segs=1)
        B.box((1.0, 1.55, 0.3), (sx * (W * 0.5 - 0.42), 0.55, 3.45), "8A8394", bevel=0.06, segs=1)
    B.box((W, 1.4, 0.75), (0, 0.55, 3.0), "6E6672", bevel=0.1, segs=1)                       # Sturz
    B.box((0.9, 0.3, 0.9), (0, -0.2, 3.05), "8A8394", r=rot(0, 45, 0), bevel=0.06, segs=1)      # Schlussstein
    B.box((W - 1.7, 0.5, 2.62), (0, 1.0, 1.31), HOLE)                                          # dunkle Öffnung
    for i in range(6):                                                                          # Fallgitter (hochgezogen)
        x = -1.25 + i * 0.5
        B.box((0.09, 0.09, 0.8), (x, 0.1, 2.25), "3A3E4A")
        B.cone(0.06, 0.18, (x, 0.1, 1.76), "C9CED8", r=rot(180, 0, 0), sides=4)
    B.box((2.7, 0.1, 0.1), (0, 0.1, 2.5), "3A3E4A")
    B.box((2.7, 0.1, 0.1), (0, 0.1, 2.05), "3A3E4A")
    G.box((0.34, 0.08, 0.34), (0, -0.36, 3.05), "FF4A3A", r=rot(0, 45, 0))
    for sx in (-1, 1):
        G.box((0.12, 0.08, 1.6), (sx * 1.9, -0.17, 1.6), "FF6A3A")
    B.build("body", root)
    G.build("rune_glow", root)
    fin(name, yaw=-25, pitch=16, size=128)


@model("mt_generator")
def mt_generator(name):
    root, B, G = start(name)
    B.cyl(1.35, 0.35, (0, 0, 0.17), "3A3E4A", sides=8, bevel=0.06, segs=1)
    B.cyl(1.15, 0.2, (0, 0, 0.42), "F7C531", sides=8)
    for i in range(8):
        a = math.radians(22.5 + 45 * i)
        B.box((0.36, 0.1, 0.06), (math.cos(a) * 1.1, math.sin(a) * 1.1, 0.53), "23262E", r=rot(0, 0, math.degrees(a)))
    B.cyl(0.55, 1.5, (0, 0, 1.25), "8A94A8", sides=12, bevel=0.08, segs=1)
    B.cyl(0.65, 0.16, (0, 0, 0.6), "5E6678", sides=12)
    B.cyl(0.65, 0.16, (0, 0, 1.95), "5E6678", sides=12)
    for sx in (-1, 1):                                                      # Spulen
        B.cyl(0.24, 1.0, (sx * 0.85, 0.0, 1.1), "B5682F", sides=10, bevel=0.05, segs=1)
        for z in (0.75, 0.95, 1.15, 1.35):
            B.cyl(0.27, 0.06, (sx * 0.85, 0.0, z), "E0A82E", sides=10)
        tube(B, (sx * 0.85, 0.0, 1.6), (sx * 0.4, 0.0, 1.9), 0.06, "23262E")
    B.box((0.7, 0.3, 0.6), (0, -0.75, 0.85), "3B6FD0", bevel=0.06, segs=1)  # Schaltkasten
    G.box((0.4, 0.06, 0.2), (0, -0.92, 0.95), "5FE3FF")
    G.ball(0.08, (0.2, -0.92, 0.7), "8BE04A", subdiv=1)
    G.ball(0.08, (-0.2, -0.92, 0.7), "FF4A3A", subdiv=1)
    B.build("body", root)
    G.build("lamp_glow", root)
    c = Part()
    c.ball(0.42, (0, 0, 0), "8FF0FF", subdiv=2)
    c.build("pulse_core_glow", root, (0, 0, 2.45))
    r = Part()
    r.torus(0.75, 0.07, (0, 0, 0), "E0A82E", seg=24, tseg=6)
    for i in range(4):
        a = math.radians(90 * i)
        r.box((0.5, 0.06, 0.06), (math.cos(a) * 0.45, math.sin(a) * 0.45, 0), "C9CED8", r=rot(0, 0, 90 * i))
    r.build("spin_ring", root, (0, 0, 2.45))
    fin(name, yaw=-30, pitch=22, size=192)


# ================================================================== Überlebenskarte „Schrottplatz“
@model("sv_barrier")
def sv_barrier(name):
    root, B, G = start(name)
    prof = [(-0.4, 0.0), (0.4, 0.0), (0.18, 0.3), (0.12, 1.05), (-0.12, 1.05), (-0.18, 0.3)]
    WP.prism(B, [(x, z) for x, z in prof], 3.0, (0, 0, 0), "C2BDB2", r=rot(0, 0, 90), bevel=0.04, segs=1)
    for i in range(4):
        x = -1.1 + i * 0.75
        B.box((0.36, 0.3, 0.3), (x, -0.13, 0.62), "E04848" if i % 2 == 0 else WHITE, r=rot(0, 0, 0), bevel=0.02, segs=1)
    B.box((0.5, 0.1, 0.14), (1.2, -0.25, 0.25), "9A968E")
    B.build("body", root)
    fin(name, yaw=-30, pitch=20, size=128)


@model("sv_crates")
def sv_crates(name):
    root, B, G = start(name)
    crate(B, (-0.5, -0.45, 0), 0.95, WOOD, 4)
    crate(B, (0.52, -0.4, 0), 0.95, shade(WOOD, 0.9), -6)
    crate(B, (0.0, 0.5, 0), 0.95, shade(WOOD, 1.05), 10)
    crate(B, (-0.1, -0.15, 0.95), 0.85, WOOD, 20)
    barrel(B, (0.75, 0.6, 0), "3B6FD0", 0.32, 0.85)
    B.build("body", root)
    fin(name, yaw=-30, pitch=22, size=128)


@model("sv_wreck")
def sv_wreck(name):
    root, B, G = start(name)
    rng = random.Random(5)
    rust, paint = "A8562A", "3E8F86"
    B.box((1.9, 3.9, 0.6), (0, 0, 0.55), paint, bevel=0.18, segs=2)
    B.box((1.7, 1.8, 0.6), (0, 0.25, 1.1), shade(paint, 0.9), bevel=0.2, segs=2)
    B.box((1.72, 1.4, 0.36), (0, 0.25, 1.12), "2A3240", bevel=0.08, segs=1)      # leere Fenster
    for i in range(10):
        B.ball(1.0, (rng.uniform(-0.9, 0.9), rng.uniform(-1.8, 1.8), rng.uniform(0.6, 1.3)), rust, scale=(0.25, 0.35, 0.08), r=rot(rng.uniform(-60, 60), rng.uniform(-60, 60), 0), subdiv=1)
    for sx, sy in ((-0.95, -1.25), (0.95, -1.25), (-0.95, 1.25), (0.95, 1.25)):
        tire(B, T(sx, sy, 0.32) @ rot(0, 90, 0) @ S(1, 1, 0.8), 0.36, 0.26, lp=True)
    B.box((1.95, 0.2, 0.25), (0, -1.98, 0.42), "8A94A8", r=rot(0, 8, 0), bevel=0.05, segs=1)
    B.box((1.0, 1.2, 0.08), (0.3, -1.5, 0.95), shade(paint, 1.1), r=rot(25, 10, 0), bevel=0.03, segs=1)    # Haube offen
    B.build("body", root)
    fin(name, yaw=-30, pitch=22, size=128)


@model("sv_container")
def sv_container(name):
    root, B, G = start(name)
    col = "C0603E"
    B.box((2.4, 6.0, 2.6), (0, 0, 1.3), col, bevel=0.06, segs=1)
    corr(B, (5.6, 0.06, 2.2), (-1.23, 0, 1.3), shade(col, 0.82), n=14, axis="y")
    corr(B, (5.6, 0.06, 2.2), (1.23, 0, 1.3), shade(col, 0.82), n=14, axis="y")
    B.box((2.3, 0.08, 2.4), (0, -3.02, 1.3), shade(col, 0.9))
    for sx in (-0.5, 0.5):
        B.box((0.06, 0.06, 2.3), (sx, -3.08, 1.3), "5E5048")
    B.box((2.5, 6.1, 0.12), (0, 0, 2.6), shade(col, 0.75))
    B.box((1.2, 0.1, 0.5), (0.3, 3.04, 1.8), WHITE)
    B.build("body", root)
    fin(name, yaw=-30, pitch=22, size=128)


@model("sv_sandbags")
def sv_sandbags(name):
    root, B, G = start(name)
    for r in range(3):
        n = 6 - r
        for i in range(n):
            a = math.radians(-35 + 70 * (i + 0.5 * r + 0.5) / 6.0)
            x, y = math.sin(a) * 3.0, 3.0 - math.cos(a) * 3.0 - 0.4
            c = shade("E8B76E", 1.0 - 0.08 * ((i + r) % 2))
            B.box((0.64, 0.42, 0.32), (x, y, 0.16 + r * 0.29), c, r=rot(0, 0, math.degrees(a)), bevel=0.13, segs=2)
    B.build("body", root)
    fin(name, yaw=-30, pitch=24, size=128)


@model("sv_tower")
def sv_tower(name):
    root, B, G = start(name)
    for sx in (-1, 1):
        for sy in (-1, 1):
            limb(B, (sx * 1.3, sy * 1.3, 0), (sx * 1.0, sy * 1.0, 4.4), 0.11, 0.09, WOOD_D, 6)
    for z in (1.4, 2.8):
        for a in range(4):
            m = rot(0, 0, 90 * a)
            B.box((2.4, 0.1, 0.1), (0, 0, 0), WOOD, r=m @ T(0, 1.18, z))
    B.box((2.8, 2.8, 0.18), (0, 0, 4.45), WOOD, bevel=0.04, segs=1)
    for a in range(4):
        m = rot(0, 0, 90 * a)
        B.box((2.8, 0.08, 0.8), (0, 0, 0), shade(WOOD, 0.85), r=m @ T(0, 1.36, 4.95))
    for sx in (-1, 1):
        for sy in (-1, 1):
            B.box((0.1, 0.1, 1.6), (sx * 1.3, sy * 1.3, 5.3), WOOD_D)
    gable(B, (0, 0, 6.05), 3.0, 3.0, 0.8, "6E6672", over=0.2, thick=0.12)
    G.box((0.4, 0.3, 0.3), (0.9, -1.45, 5.2), "FFE38A", bevel=0.05, segs=1)
    B.box((0.5, 0.2, 0.42), (0.9, -1.3, 5.2), "23262E", bevel=0.04, segs=1)
    B.build("body", root)
    G.build("lamp_glow", root)
    fin(name, yaw=-30, pitch=18, size=128)


@model("sv_fence")
def sv_fence(name):
    root, B, G = start(name)
    for x in (-2.0, 0.0, 2.0):
        B.cyl(0.07, 2.4, (x, 0, 1.2), "8A94A8", sides=6)
    for z in (0.15, 1.15, 2.15):
        B.cyl(0.035, 4.0, (0, 0, z), "8A94A8", r=rot(0, 90, 0), sides=5)
    for i in range(13):                                                     # Maschendraht als Rauten
        x = -1.85 + i * 0.31
        beam(B, (x, 0.0, 0.15), (x + 0.3, 0.0, 2.15), 0.025, "A9B3C6")
        beam(B, (x + 0.3, 0.0, 0.15), (x, 0.0, 2.15), 0.025, "A9B3C6")
    for i in range(8):
        B.torus(0.12, 0.012, (-1.8 + i * 0.52, 0, 2.38), "6E6672", r=rot(90, 0, 0), seg=8, tseg=3)
    B.build("body", root)
    fin(name, yaw=-25, pitch=14, size=128, ao=False)


@model("sv_gate")
def sv_gate(name):
    root, B, G = start(name)
    for sx in (-1, 1):
        B.box((0.4, 0.4, 2.6), (sx * 2.0, 0, 1.3), "6E6672", bevel=0.06, segs=1)
        B.box((0.55, 0.55, 0.2), (sx * 2.0, 0, 2.7), "8A94A8", bevel=0.04, segs=1)
        G.ball(0.16, (sx * 2.0, -0.05, 2.92), "FF8A1E", subdiv=2)
    B.box((1.6, 0.1, 1.9), (-1.0, -0.6, 1.05), "8A94A8", r=rot(0, 0, 50), bevel=0.02, segs=1)   # aufgerissener Flügel
    for i in range(4):
        x = -1.6 + i * 0.4
        B.box((0.05, 0.12, 1.9), (0, 0, 0), "A9B3C6", r=T(-0.95, -0.62, 1.05) @ rot(0, 0, 50) @ T(x + 0.6, 0, 0))
    B.box((4.4, 0.25, 0.25), (0, 0, 2.55), "E0A82E", bevel=0.03, segs=1)
    for i in range(6):
        B.box((0.36, 0.27, 0.27), (-1.75 + i * 0.7, 0, 2.55), "23262E", r=rot(0, 45, 0))
    B.build("body", root)
    G.build("lamp_glow", root)
    fin(name, yaw=-25, pitch=16, size=128)


@model("sv_lamp")
def sv_lamp(name):
    root, B, G = start(name)
    B.box((0.7, 0.7, 0.3), (0, 0, 0.15), "C2BDB2", bevel=0.04, segs=1)
    B.cyl(0.09, 5.0, (0, 0, 2.7), "5E6678", sides=8)
    B.box((1.4, 0.12, 0.12), (0, 0, 5.1), "5E6678")
    for sx in (-0.55, 0.55):
        B.box((0.45, 0.35, 0.35), (sx, -0.1, 5.0), "23262E", r=rot(-25, 0, 0), bevel=0.05, segs=1)
        G.box((0.36, 0.06, 0.28), (sx, -0.3, 4.92), "FFF2B0", r=rot(-25, 0, 0))
    B.build("body", root)
    G.build("lamp_glow", root)
    fin(name, yaw=-25, pitch=14, size=128, ao=False)


# ================================================================== Höhlen
THEME = {
    "wurzel": dict(rock="6E6050", rock_d="4E4438", rock_l="8A7A66", floor="5E5446", floor_l="756A58", acc="FFB347", moss="4F7A2A", root="7A5A3A"),
    "sand":   dict(rock="C99A62", rock_d="9A6E44", rock_l="E0BA84", floor="B58A58", floor_l="CDA472", acc="FFD27A", pot="C0603E"),
    "eis":    dict(rock="8FAFD0", rock_d="5F84B0", rock_l="BFD6EC", floor="A9C2DC", floor_l="D4E4F2", acc="7FE8FF", ice="BFEFFF"),
    "glut":   dict(rock="4A3E40", rock_d="2E2628", rock_l="64545A", floor="3C3234", floor_l="54474C", acc="FF6A2A", lava="FF7A22"),
}
THEMES = list(THEME)


def _cobbles(p, G, t, w, d, rng, n):
    """Pflaster aus flachen Steinen auf einer Fläche w × d (Mitte im Ursprung), dazu Schmuck je Thema."""
    c = THEME[t]
    p.box((w, d, 0.3), (0, 0, -0.12), c["floor"], bevel=0.05, segs=1)
    for i in range(n):
        x = rng.uniform(-w * 0.46, w * 0.46)
        y = rng.uniform(-d * 0.46, d * 0.46)
        s = rng.uniform(0.35, 0.9)
        hh = rng.uniform(0.05, 0.11)                       # verschiedene Höhen: keine deckungsgleichen Flächen (Flimmern)
        p.cyl(s, hh, (x, y, 0.02 + hh * 0.5), vary(c["floor_l"] if i % 3 else c["floor"], rng, 0.07), r=rot(0, 0, rng.uniform(0, 90)), sides=6, r2=s * 0.85)
    area = w * d
    if t == "wurzel":
        for i in range(int(area / 14)):
            x, y = rng.uniform(-w * 0.45, w * 0.45), rng.uniform(-d * 0.45, d * 0.45)
            p.ball(1.0, (x, y, rng.uniform(0.05, 0.09)), vary(c["moss"], rng, 0.12), scale=(rng.uniform(0.4, 0.9), rng.uniform(0.3, 0.7), 0.06), subdiv=1)
        for i in range(int(area / 40)):
            x, y = rng.uniform(-w * 0.42, w * 0.42), rng.uniform(-d * 0.42, d * 0.42)
            k = rng.uniform(0.6, 1.0)
            p.cyl(0.05 * k, 0.25 * k, (x, y, 0.12 * k), "E8DCC0", sides=5)
            G.ball(1.0, (x, y, 0.26 * k), "9BE85A", scale=(0.14 * k, 0.14 * k, 0.08 * k), subdiv=1)
    elif t == "sand":
        for i in range(int(area / 18)):
            x, y = rng.uniform(-w * 0.45, w * 0.45), rng.uniform(-d * 0.45, d * 0.45)
            p.ball(1.0, (x, y, 0.04), vary("E0BA84", rng, 0.05), scale=(rng.uniform(0.6, 1.4), rng.uniform(0.4, 0.8), 0.08), r=rot(0, 0, rng.uniform(0, 180)), subdiv=1)
        for i in range(int(area / 50)):
            x, y = rng.uniform(-w * 0.42, w * 0.42), rng.uniform(-d * 0.42, d * 0.42)
            p.cyl(0.04, 0.5, (x, y, 0.06), "F2E6CC", r=rot(90, 0, rng.uniform(0, 180)), sides=5)
    elif t == "eis":
        for i in range(int(area / 16)):
            x, y = rng.uniform(-w * 0.45, w * 0.45), rng.uniform(-d * 0.45, d * 0.45)
            p.box((rng.uniform(0.6, 1.6), rng.uniform(0.4, 1.1), 0.03), (x, y, rng.uniform(0.13, 0.16)), vary("D4ECF8", rng, 0.05), r=rot(0, 0, rng.uniform(0, 180)))
        for i in range(int(area / 30)):
            x, y = rng.uniform(-w * 0.45, w * 0.45), rng.uniform(-d * 0.45, d * 0.45)
            p.ball(1.0, (x, y, 0.06), WHITE, scale=(0.6, 0.4, 0.1), subdiv=1)
    else:
        for i in range(int(area / 22)):
            x, y = rng.uniform(-w * 0.42, w * 0.42), rng.uniform(-d * 0.42, d * 0.42)
            yaw = rng.uniform(0, 180)
            for k in range(3):
                G.box((rng.uniform(0.4, 0.9), 0.07, 0.03), (0, 0, 0), c["lava"], r=T(x, y, 0.14 + 0.004 * k) @ rot(0, 0, yaw + k * 40) @ T(0.3 * k, 0, 0))


@model(*["cv_%s_floor" % t for t in THEMES])
def cv_floor(name):
    t = name.split("_")[1]
    root, B, G = start(name)
    _cobbles(B, G, t, 14.0, 14.0, random.Random(sum(map(ord, name))), 70)
    B.build("body", root)
    glow = {"wurzel": "shroom_glow", "sand": "", "eis": "ice_glow", "glut": "lava_glow"}[t]
    if glow and len(G.bm.faces) > 0:
        G.build(glow, root)
    else:
        G.bm.free()
    fin(name, yaw=-30, pitch=45, ao=False, size=128)


@model(*["cv_%s_hall" % t for t in THEMES])
def cv_hall(name):
    t = name.split("_")[1]
    root, B, G = start(name)
    _cobbles(B, G, t, 4.4, 6.4, random.Random(sum(map(ord, name))), 14)
    B.build("body", root)
    glow = {"wurzel": "shroom_glow", "sand": "", "eis": "ice_glow", "glut": "lava_glow"}[t]
    if glow and len(G.bm.faces) > 0:
        G.build(glow, root)
    else:
        G.bm.free()
    fin(name, yaw=-30, pitch=45, ao=False, size=96)


def _rock_wall(B, G, t, rng, w=2.0, h=3.6, depth=1.6):
    c = THEME[t]
    # zwei bis drei große Brocken und kleinere davor, Innenseite bei y ≈ -0.2
    B.box((w + 0.3, depth, h * 0.9), (0, depth * 0.5, h * 0.45), c["rock_d"], bevel=0.25, segs=1)
    for i in range(3):
        sx = rng.uniform(0.9, 1.3)
        sz = rng.uniform(1.1, 1.6)
        rockc(B, (sx, rng.uniform(0.8, 1.2), sz), (-0.65 + i * 0.65 + rng.uniform(-0.1, 0.1), 0.2, 0.3 + i % 2 * 1.2 + sz * 0.4), vary(c["rock"], rng, 0.08), rng, 0.3)
    for i in range(2):
        rockc(B, (rng.uniform(0.7, 1.0), 0.8, rng.uniform(0.7, 1.0)), (rng.uniform(-0.6, 0.6), 0.25, h - rng.uniform(0.4, 0.8)), vary(c["rock_l"], rng, 0.06), rng, 0.3)
    rockc(B, (rng.uniform(0.5, 0.8), 0.5, 0.45), (rng.uniform(-0.5, 0.5), -0.15, 0.22), vary(c["rock_l"], rng, 0.08), rng, 0.3)
    if t == "wurzel":
        for i in range(3):
            x = rng.uniform(-0.8, 0.8)
            limb(B, (x, -0.1, h), (x + rng.uniform(-0.3, 0.3), -0.35, rng.uniform(0.6, 1.8)), 0.08, 0.03, c["root"], 5)
        B.ball(1.0, (rng.uniform(-0.6, 0.6), -0.18, h - 0.3), c["moss"], scale=(0.6, 0.15, 0.4), subdiv=1)
    elif t == "sand":
        for z in (0.9, 1.9, 2.8):
            B.box((w + 0.2, 0.1, 0.12), (0, -0.05, z), c["rock_l"], bevel=0.04, segs=1)
    elif t == "eis":
        for i in range(5):
            x = -0.8 + i * 0.4 + rng.uniform(-0.06, 0.06)
            ln = rng.uniform(0.35, 0.9)
            B.cone(0.1, ln, (x, -0.2, h - 0.25 - ln * 0.5), c["ice"], r=rot(180, 0, 0), sides=5)
        B.box((rng.uniform(0.5, 0.9), 0.06, rng.uniform(0.8, 1.6)), (rng.uniform(-0.5, 0.5), -0.25, rng.uniform(1.0, 2.0)), "D4ECF8", r=rot(0, rng.uniform(-15, 15), 0), bevel=0.02, segs=1)
    else:
        for i in range(2):
            x = rng.uniform(-0.7, 0.7)
            z0 = rng.uniform(0.5, 1.6)
            for k in range(3):
                G.box((0.06, 0.06, 0.5), (0, 0, 0), c["lava"], r=T(x + k * 0.1, -0.24, z0 + k * 0.4) @ rot(0, rng.uniform(-35, 35), 0))


@model(*["cv_%s_wall_%d" % (t, v) for t in THEMES for v in (1, 2)])
def cv_wall(name):
    parts = name.split("_")
    t, v = parts[1], int(parts[3])
    root, B, G = start(name)
    _rock_wall(B, G, t, random.Random(v * 101 + len(t) * 7))
    B.build("body", root)
    glow = {"wurzel": "", "sand": "", "eis": "ice_glow", "glut": "crack_glow"}[t]
    if glow and len(G.bm.faces) > 0:
        G.build(glow, root)
    else:
        G.bm.free()
    fin(name, yaw=-20, pitch=12, ao=True, size=96)


@model(*["cv_%s_rock" % t for t in THEMES])
def cv_rock(name):
    t = name.split("_")[1]
    c = THEME[t]
    root, B, G = start(name)
    rng = random.Random(len(name) * 13)
    B.cyl(1.25, 3.9, (0, 0, 1.95), c["rock_d"], r2=0.8, sides=7)
    for i in range(5):
        a = rng.uniform(0, 6.283)
        rockc(B, (rng.uniform(0.8, 1.3), rng.uniform(0.8, 1.2), rng.uniform(0.8, 1.6)), (math.cos(a) * 0.6, math.sin(a) * 0.6, rng.uniform(0.4, 3.2)), vary(c["rock"], rng, 0.08), rng, 0.3)
    if t == "eis":
        B.cone(0.3, 1.1, (0.2, -0.9, 0.55), c["ice"], sides=5)
    elif t == "wurzel":
        limb(B, (0, -0.4, 3.9), (0.3, -1.2, 0.0), 0.12, 0.05, c["root"], 5)
    B.build("body", root)
    fin(name, yaw=-25, pitch=15, ao=True, size=96)


@model(*["cv_%s_deco_%d" % (t, v) for t in THEMES for v in (1, 2)])
def cv_deco(name):
    parts = name.split("_")
    t, v = parts[1], int(parts[3])
    c = THEME[t]
    root, B, G = start(name)
    rng = random.Random(v * 53 + len(t))
    gname = "deco_glow"
    if t == "wurzel" and v == 1:
        for i in range(7):                                                  # Leuchtpilze
            a = rng.uniform(0, 6.283)
            r = rng.uniform(0.0, 0.8)
            k = rng.uniform(0.6, 1.4)
            B.cyl(0.08 * k, 0.5 * k, (math.cos(a) * r, math.sin(a) * r, 0.25 * k), "E8DCC0", r2=0.06 * k, sides=6)
            G.ball(1.0, (math.cos(a) * r, math.sin(a) * r, 0.5 * k), rng.choice(["9BE85A", "6FE6FF", "C08BFF"]), scale=(0.3 * k, 0.3 * k, 0.17 * k), subdiv=2)
        B.ball(1.0, (0, 0, 0.05), c["moss"], scale=(1.1, 0.9, 0.1), subdiv=1)
    elif t == "wurzel":
        log_(B, T(0, 0, 0.6) @ rot(0, 0, 0), 0.5, 1.2, 10, c["root"])        # Baumstumpf mit Wurzeln
        for i in range(5):
            a = math.radians(i * 72 + 10)
            limb(B, (0, 0, 0.6), (math.cos(a) * 1.4, math.sin(a) * 1.4, 0.0), 0.2, 0.06, c["root"], 5)
        mushroom(B, 0.5, -0.5, 0.0, 0.7)
    elif t == "sand" and v == 1:
        for i, (x, y, k, col) in enumerate(((0, 0, 1.0, c["pot"]), (0.6, 0.3, 0.75, "D9894A"), (-0.5, 0.35, 0.8, c["pot"]))):
            B.cyl(0.28 * k, 0.7 * k, (x, y, 0.35 * k), col, r2=0.18 * k, sides=10, bevel=0.06, segs=1)
            B.ball(0.3 * k, (x, y, 0.3 * k), col, scale=(1, 1, 0.8), subdiv=2)
            B.cyl(0.16 * k, 0.12 * k, (x, y, 0.74 * k), shade(col, 0.8), sides=10)
            B.box((0.5 * k, 0.04, 0.06), (x, y - 0.27 * k, 0.4 * k), "F2C94A")
        B.cyl(0.04, 0.6, (-0.2, -0.6, 0.05), "F2E6CC", r=rot(90, 0, 40), sides=5)
        B.ball(0.12, (0.2, -0.65, 0.08), "F2E6CC", subdiv=1)
    elif t == "sand":
        bone = "F2E6CC"
        B.ball(1.0, (0, 0.15, 0.5), bone, scale=(0.7, 0.75, 0.55), subdiv=2)            # Hirnschale
        B.box((0.7, 0.7, 0.36), (0, -0.55, 0.28), bone, bevel=0.15, segs=2)              # Schnauze
        for sx in (-1, 1):
            B.ball(0.2, (sx * 0.3, -0.42, 0.62), HOLE, scale=(1.0, 0.7, 0.85), subdiv=2)   # Augenhöhlen
            limb(B, (sx * 0.45, 0.1, 0.85), (sx * 0.95, 0.0, 1.35), 0.12, 0.04, bone, 6)   # Hörner
            B.cone(0.07, 0.18, (sx * 0.18, -0.9, 0.12), bone, r=rot(180, 0, 0), sides=4)  # Zähne
        B.ball(0.06, (0, -0.9, 0.36), HOLE, scale=(1.4, 0.6, 1), subdiv=1)
        B.ball(1.0, (0.5, 0.6, 0.05), "E0BA84", scale=(1.0, 0.6, 0.15), subdiv=1)
    elif t == "eis" and v == 1:
        for i in range(6):                                                  # Kristallgruppe
            a = rng.uniform(-40, 40)
            h = rng.uniform(0.8, 2.0)
            m = T(rng.uniform(-0.4, 0.4), rng.uniform(-0.4, 0.4), 0) @ rot(rng.uniform(-25, 25), rng.uniform(-25, 25), a)
            G.cyl(0.2, h, (0, 0, 0), rng.choice([c["ice"], "8FF0FF", "BFD6EC"]), r=m @ T(0, 0, h * 0.5), r2=0.02, sides=6)
        rockc(B, (1.2, 1.0, 0.4), (0, 0, 0.15), c["rock"], rng, 0.3)
        gname = "crystal_glow"
    elif t == "eis":
        barrel(B, (0, 0, 0.1), "E04848", 0.36, 1.25)                        # Fass im Eisblock (ragt heraus)
        B.box((1.3, 1.1, 0.8), (0, 0, 0.4), "D8F2FF", bevel=0.18, segs=2)
        for i in range(3):
            B.cone(0.12, 0.5, (-0.4 + i * 0.4, -0.5, 0.95), "BFEFFF", sides=5)
        B.ball(1.0, (0.3, -0.5, 0.05), WHITE, scale=(0.8, 0.5, 0.15), subdiv=1)
    elif t == "glut" and v == 1:
        G.cyl(1.0, 0.08, (0, 0, 0.06), c["lava"], sides=14)                 # Lavatümpel
        G.ball(0.12, (0.3, 0.2, 0.12), "FFE38A", subdiv=1)
        for i in range(9):
            a = math.radians(i * 40)
            rockc(B, (0.5, 0.4, 0.35), (math.cos(a) * 1.1, math.sin(a) * 1.1, 0.15), c["rock_d"], rng, 0.3)
        gname = "lava_glow"
    else:
        for i in range(5):                                                  # Obsidian-Spitzen
            a = rng.uniform(0, 6.283)
            r = rng.uniform(0.0, 0.6)
            h = rng.uniform(0.9, 2.0)
            B.cone(0.3, h, (math.cos(a) * r, math.sin(a) * r, h * 0.5), "1E181C", r=rot(rng.uniform(-15, 15), rng.uniform(-15, 15), 0), sides=5)
        G.box((0.6, 0.06, 0.06), (0.2, -0.5, 0.04), c["lava"], r=rot(0, 0, 30))
        gname = "lava_glow"
    B.build("body", root)
    if len(G.bm.faces) > 0:
        G.build(gname, root)
    else:
        G.bm.free()
    fin(name, yaw=-30, pitch=24, size=128)


@model(*["cv_%s_entry" % t for t in THEMES])
def cv_entry(name):
    t = name.split("_")[1]
    c = THEME[t]
    root, B, G = start(name)
    rng = random.Random(len(t) * 29)
    # Felshügel: breit und flach, vorn steil
    B.ball(1.0, (0, 1.6, 0.0), c["rock_d"], scale=(3.7, 2.9, 2.7), subdiv=2)
    for i in range(12):
        a = math.radians(rng.uniform(10, 170))
        r = rng.uniform(2.3, 3.1)
        rockc(B, (rng.uniform(1.2, 2.0), rng.uniform(1.0, 1.6), rng.uniform(1.0, 1.8)), (math.cos(a) * r, 1.4 + math.sin(a) * r * 0.45, rng.uniform(0.5, 2.4)), vary(c["rock"], rng, 0.08), rng, 0.3)
    for i in range(4):
        rockc(B, (rng.uniform(1.0, 1.6), 1.2, 0.9), (rng.uniform(-1.6, 1.6), rng.uniform(1.0, 2.2), rng.uniform(2.6, 3.2)), vary(c["rock_l"], rng, 0.06), rng, 0.3)
    for sx in (-1, 1):                                                      # Wangen neben der Öffnung
        rockc(B, (1.3, 1.3, 2.4), (sx * 2.0, -1.0, 1.1), vary(c["rock"], rng, 0.06), rng, 0.25)
    rockc(B, (3.4, 1.2, 0.9), (0, -0.9, 2.75), vary(c["rock_l"], rng, 0.05), rng, 0.25)      # Sturz
    # dunkle Öffnung (nach -Y): Rundbogen, innen fast schwarz
    B.box((2.4, 1.6, 1.7), (0, -0.85, 0.85), HOLE, bevel=0.1, segs=1)
    B.cyl(1.2, 1.6, (0, -0.85, 1.7), HOLE, r=rot(90, 0, 0), sides=14)
    B.box((3.0, 0.9, 0.12), (0, -2.0, 0.03), c["floor"], bevel=0.05, segs=1)
    for i in range(5):                                                      # Trittsteine
        B.cyl(0.35, 0.1, (rng.uniform(-0.8, 0.8), -2.3 - i * 0.05, 0.05 + 0.01 * i), c["floor_l"], sides=6)
    if t in ("wurzel", "sand"):                                             # Stollen-Rahmen aus Balken
        for sx in (-1, 1):
            B.box((0.28, 0.32, 2.7), (sx * 1.3, -1.7, 1.35), WOOD_D, bevel=0.05, segs=1)
        B.box((3.1, 0.34, 0.32), (0, -1.7, 2.75), WOOD, bevel=0.05, segs=1)
        B.box((0.9, 0.08, 0.4), (0.5, -1.92, 3.12), WOOD_L, r=rot(0, -8, 0), bevel=0.03, segs=1)    # Schild
        if t == "wurzel":
            for i in range(4):
                x = rng.uniform(-2.5, 2.5)
                limb(B, (x, -0.8, 3.6), (x * 1.2, -1.6, 0.0), 0.12, 0.05, c["root"], 5)
            for i in range(5):
                tuft(B, rng.uniform(-2.8, 2.8), rng.uniform(-1.9, -1.2), 0.0, 4, 0.9, i)
        else:
            B.ball(1.0, (-2.0, -1.8, 0.05), "E0BA84", scale=(1.4, 0.8, 0.3), subdiv=1)
            B.cyl(0.25, 1.2, (2.6, -1.6, 0.6), "6FA33A", sides=8, bevel=0.1, segs=1)                 # Kaktus
    elif t == "eis":
        for sx in (-1, 1):
            G.cone(0.35, 2.6, (sx * 1.45, -1.8, 1.3), c["ice"], sides=6)
        for i in range(7):
            x = -1.2 + i * 0.4
            B.cone(0.1, rng.uniform(0.3, 0.8), (x, -1.8, 2.45), c["ice"], r=rot(180, 0, 0), sides=5)
        B.ball(1.0, (0, 1.0, 3.2), WHITE, scale=(3.0, 2.4, 1.1), subdiv=2)
    else:
        for sx in (-1, 1):
            B.cone(0.45, 3.0, (sx * 1.5, -1.8, 1.5), "1E181C", sides=5)
        for i in range(3):
            G.box((0.07, 0.06, 0.8), (0, 0, 0), c["lava"], r=T(rng.uniform(-2.0, 2.0), -1.5, rng.uniform(1.0, 2.5)) @ rot(0, rng.uniform(-30, 30), 0))
    # zwei Fackeln
    for sx in (-1, 1):
        B.cyl(0.07, 1.6, (sx * 1.95, -2.1, 0.8), WOOD_D, sides=6)
        B.cyl(0.16, 0.25, (sx * 1.95, -2.1, 1.65), "3A3E4A", r2=0.2, sides=8)
    B.build("body", root)
    if len(G.bm.faces) > 0:
        G.build("rim_glow", root)
    else:
        G.bm.free()
    for sx in (-1, 1):
        f = Part()
        f.cone(0.2, 0.55, (0, 0, 0.27), "FFB347", sides=6)
        f.cone(0.11, 0.35, (0.03, 0.02, 0.3), "FFF2B0", sides=5)
        f.build("pulse_torch_glow_%s" % ("l" if sx < 0 else "r"), root, (sx * 1.95, -2.1, 1.78))
    empty("mouth", root, (0, -2.6, 0))
    fin(name, yaw=-25, pitch=20, size=192)


@model(*["cv_%s_ore" % t for t in THEMES])
def cv_ore(name):
    t = name.split("_")[1]
    c = THEME[t]
    root, B, G = start(name)
    rng = random.Random(len(t) * 41)
    ore = {"wurzel": ["FFB347", "FFD27A"], "sand": ["E0A82E", "F7C531"], "eis": ["6FE6FF", "BFEFFF"], "glut": ["FF4A3A", "FF9A3A"]}[t]
    for i in range(4):
        rockc(B, (rng.uniform(0.9, 1.4), rng.uniform(0.8, 1.2), rng.uniform(0.6, 1.1)), (rng.uniform(-0.5, 0.5), rng.uniform(-0.3, 0.4), rng.uniform(0.3, 0.8)), vary(c["rock"], rng, 0.08), rng, 0.3)
    for i in range(9):
        a = rng.uniform(0, 6.283)
        h = rng.uniform(0.5, 1.2)
        m = T(math.cos(a) * rng.uniform(0.2, 0.7), math.sin(a) * rng.uniform(0.2, 0.6), rng.uniform(0.4, 1.0)) @ rot(rng.uniform(-50, 50), rng.uniform(-50, 50), 0)
        if t == "sand":
            G.ball(1.0, (0, 0, 0), rng.choice(ore), r=m, scale=(0.2, 0.17, 0.15), subdiv=1)
        else:
            G.cyl(0.14, h, (0, 0, 0), rng.choice(ore), r=m @ T(0, 0, h * 0.5), r2=0.02, sides=6)
    B.build("body", root)
    G.build("ore_glow", root)
    fin(name, yaw=-30, pitch=22, size=128)


@model("cv_torch")
def cv_torch(name):
    root, B, G = start(name)
    B.cyl(0.25, 0.2, (0, 0, 0.1), "4E4438", sides=7)
    B.cyl(0.07, 1.9, (0, 0, 1.05), WOOD_D, sides=6)
    B.cyl(0.18, 0.28, (0, 0, 2.0), "3A3E4A", r2=0.24, sides=8)
    for i in range(4):
        B.box((0.04, 0.04, 0.3), (0, 0, 0), "23262E", r=rot(0, 0, 45 + i * 90) @ T(0.2, 0, 2.15) @ rot(0, 20, 0))
    B.build("body", root)
    f = Part()
    f.cone(0.24, 0.62, (0, 0, 0.31), "FFB347", sides=6)
    f.cone(0.13, 0.4, (0.03, 0.02, 0.32), "FFF2B0", sides=5)
    f.build("pulse_flame_glow", root, (0, 0, 2.12))
    empty("light", root, (0, 0, 2.5))
    fin(name, yaw=-25, pitch=15, size=96)


@model("cv_exit")
def cv_exit(name):
    root, B, G = start(name)
    B.cyl(1.6, 0.2, (0, 0, 0.1), "6E6672", sides=12)
    for i in range(8):
        a = math.radians(i * 45)
        rockc(B, (0.7, 0.6, 0.5), (math.cos(a) * 1.55, math.sin(a) * 1.55, 0.25), "8A8394", random.Random(i), 0.3)
    for sx in (-1, 1):                                                      # Leiter
        limb(B, (sx * 0.32, 0.2, 0.0), (sx * 0.32, 0.9, 4.2), 0.06, 0.05, WOOD_D, 6)
    for i in range(9):
        z = 0.35 + i * 0.45
        y = 0.2 + 0.7 * z / 4.2
        B.cyl(0.035, 0.66, (0, y, z), WOOD, r=rot(0, 90, 0), sides=5)
    limb(B, (0.6, 0.6, 4.4), (0.7, 0.3, 0.2), 0.03, 0.03, "D9C08A", 4)                    # Seil
    B.build("body", root)
    g = Part()
    g.cyl(1.4, 6.0, (0, 0, 3.0), "FFF2C8", r2=1.0, sides=16)
    g.build("beam_glow", root)
    fin(name, yaw=-25, pitch=18, size=128, ao=False)


# ================================================================== Ladefläche des Pickups
@model("v_pickup_rack")
def v_pickup_rack(name):
    """Ladegitter: Ursprung = Leerobjekt `turret` der Pritsche (Mitte der Ladefläche, Höhe Ladeboden).
    Ladefläche 1,6 × 1,5 m (x × y), Bordwände bis +0,3 m – das Gitter erhöht sie auf 0,9 m."""
    root, B, G = start(name)
    col, dk = "E0A82E", "3A3E4A"
    for sx in (-1, 1):
        for y in (-0.7, 0.0, 0.7):
            B.box((0.06, 0.06, 0.9), (sx * 0.86, y, 0.45), dk)
        for z in (0.45, 0.88):
            B.box((0.05, 1.5, 0.05), (sx * 0.86, 0, z), col)
    for x in (-0.8, 0.0, 0.8):
        B.box((0.06, 0.06, 0.9), (x, 0.78, 0.45), dk)
    for z in (0.45, 0.88):
        B.box((1.7, 0.05, 0.05), (0, 0.78, z), col)
    B.box((1.4, 0.04, 0.3), (0, 0.8, 0.66), "3B6FD0", bevel=0.02, segs=1)       # Plane-Streifen hinten
    B.build("body", root)
    fin(name, yaw=-35, pitch=22, size=96, ao=False)


# ================================================================== Symbole
def _icon_save(name, p, yaw, pitch):
    WP.scale_all(p, 0.5)
    zmin = min(v.co.z for v in p.bm.verts)
    for v in p.bm.verts:
        v.co.z -= zmin
    WP.toon(p, 0.82, 1.1)
    reset()
    root = empty(name)
    p.build("body", root)
    save(name)
    icon(name, 128, yaw=yaw, pitch=pitch, margin=1.08)


@model("ui_tower")
def ui_tower(name):
    """Turm der Prüfungen: Steinturm mit Zinnen und goldener Fahne."""
    p = Part()
    p.cyl(0.3, 0.9, (0, 0, -0.02), "AEB6D2", r2=0.25, sides=12, bevel=0.03, segs=1)
    for z in (-0.3, 0.0, 0.25):
        p.cyl(0.31 - (z + 0.3) * 0.08, 0.04, (0, 0, z), "8690B0", sides=12)
    p.cyl(0.34, 0.12, (0, 0, 0.47), "C6CDE4", sides=12, bevel=0.02, segs=1)
    for i in range(6):
        a = math.radians(i * 60)
        p.box((0.12, 0.1, 0.12), (math.cos(a) * 0.29, math.sin(a) * 0.29, 0.58), "C6CDE4", r=rot(0, 0, i * 60), bevel=0.02, segs=1)
    p.box((0.16, 0.06, 0.24), (0, -0.28, -0.38), "363D52", bevel=0.05, segs=2)
    p.box((0.1, 0.05, 0.12), (0, -0.27, 0.12), "FFD24D", bevel=0.03, segs=1)
    p.cyl(0.015, 0.4, (0, 0, 0.8), "7A4522", sides=6)
    WP.prism(p, [(0.0, 0.0), (0.24, 0.07), (0.0, 0.14)], 0.03, (0.01, 0, 0.88), "FFD23E")
    p.cyl(0.42, 0.06, (0, 0, -0.47), "8FB02A", sides=16)
    _icon_save(name, p, -24, 12)


@model("ui_survival")
def ui_survival(name):
    """Überleben: Sanduhr mit Totenkopf-Plakette."""
    p = Part()
    for z in (-0.42, 0.42):
        p.cyl(0.36, 0.08, (0, 0, z), "B5682F", sides=16, bevel=0.02, segs=1)
    for sx in (-1, 1):
        for sy in (-1, 1):
            p.cyl(0.025, 0.8, (sx * 0.27, sy * 0.27, 0), "7A4522", sides=6)
    p.cyl(0.26, 0.38, (0, 0, 0.2), "BFE6FA", r2=0.05, sides=16)
    p.cyl(0.05, 0.38, (0, 0, -0.2), "BFE6FA", r2=0.26, sides=16)
    p.cyl(0.2, 0.1, (0, 0, -0.32), "F2CF8E", r2=0.12, sides=16)
    p.cyl(0.1, 0.1, (0, 0, 0.1), "F2CF8E", r2=0.02, sides=12)
    p.ball(0.2, (0.24, -0.34, -0.14), "F4F6FA", scale=(1, 0.55, 0.95), subdiv=3)          # Schädel vorn
    p.box((0.2, 0.1, 0.12), (0.24, -0.4, -0.3), "F4F6FA", bevel=0.04, segs=2)
    for sx in (-1, 1):
        p.ball(0.06, (0.24 + sx * 0.08, -0.44, -0.11), "181A22", scale=(1, 0.5, 1.2), subdiv=2)
    for i in range(3):
        p.box((0.025, 0.12, 0.05), (0.18 + i * 0.06, -0.45, -0.31), "181A22")
    _icon_save(name, p, -20, 10)


@model("ui_raid")
def ui_raid(name):
    """Clan-Raid: grüner Riesenschleim mit Krone und gekreuzten Schwertern."""
    p = Part()
    p.ball(0.42, (0, 0, -0.08), "8BC43A", scale=(1.05, 0.85, 0.8), subdiv=3)
    for sx in (-1, 1):
        p.ball(0.1, (sx * 0.16, -0.33, 0.0), "F4F6FA", scale=(1, 0.6, 1.1), subdiv=2)
        p.ball(0.05, (sx * 0.16, -0.39, 0.0), "181A22", scale=(1, 0.6, 1), subdiv=1)
    p.box((0.3, 0.06, 0.06), (0, -0.36, -0.18), "4F7A2A", bevel=0.02, segs=1)
    p.cyl(0.22, 0.14, (0, 0, 0.33), "FFD23E", sides=8)
    for i in range(5):
        a = math.radians(i * 72)
        p.cone(0.06, 0.16, (math.cos(a) * 0.17, math.sin(a) * 0.17, 0.46), "FFD23E", sides=4)
    for sg in (-1, 1):
        m = T(0, 0.3, 0.05) @ rot(0, sg * 40, 0)
        p.box((0.07, 0.04, 1.05), (0, 0, 0), "C9D0DE", r=m @ T(0, 0, 0.1), bevel=0.015, segs=1)
        p.cone(0.05, 0.12, (0, 0, 0), "C9D0DE", r=m @ T(0, 0, 0.68), sides=4)
        p.box((0.26, 0.06, 0.05), (0, 0, 0), "E0A82E", r=m @ T(0, -0.02, -0.4))
        p.box((0.06, 0.05, 0.2), (0, 0, 0), "7A4522", r=m @ T(0, -0.02, -0.52))
    _icon_save(name, p, -18, 10)


@model("ui_cave")
def ui_cave(name):
    """Höhle: Felsbogen mit dunkler Öffnung und Fackel."""
    p = Part()
    rng = random.Random(3)
    p.ball(0.45, (0, 0.1, -0.1), "8A7A66", scale=(1.1, 0.8, 0.9), subdiv=2)
    for i in range(7):
        a = math.radians(10 + i * 26)
        p.box((0.22, 0.2, 0.2), (math.cos(a) * 0.42, -0.2, math.sin(a) * 0.4 - 0.1), "A89A8E", r=rot(rng.uniform(-20, 20), 0, rng.uniform(-20, 20)), bevel=0.05, segs=1)
    p.ball(0.26, (0, -0.22, -0.2), "120E14", scale=(1.0, 0.5, 1.15), subdiv=2)
    p.cyl(0.02, 0.4, (0.36, -0.36, -0.2), "7A4522", sides=6)
    p.cone(0.06, 0.16, (0.36, -0.36, 0.06), "FFB347", sides=6)
    p.cyl(0.5, 0.06, (0, 0, -0.5), "5E5446", sides=16)
    _icon_save(name, p, -16, 10)


MODELS = REG

if __name__ == "__main__":
    a = sys.argv[1:]
    if a == ["list"]:
        print("\n".join(MODELS))
        sys.exit(0)
    for n in (a or list(MODELS)):
        if n not in MODELS:
            print("unbekannt:", n, flush=True)
            continue
        MODELS[n]()
        print("ok", n, flush=True)
