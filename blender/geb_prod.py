"""Rustwall – Produktionsgebäude und Lager nach dem Detail-Katalog (Auftrag V3, Kapitel 6).
Sägewerk, Steinbruch, Schrottpresse, Raffinerie, Generator, Lager. Vorderseite = -Y."""
import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from geb_kit import *


def hof(M, w, d, step_x=0.0, color=PAVE, skip=(), style="stein"):
    """Hofplatte (0,25 m hoch, sichtbare Fugen) mit Stufe an der Vorderkante. Liefert die Vorderkante (y)."""
    B = M["body"]
    y0 = -d / 2 + 0.28
    fundament(B, w, d - 0.28, 0.25, (0, 0.14), color, skip=skip, style=style)
    stufe(B, step_x, -d / 2 + 0.2, 1.9, 0.34, 0.13)
    return y0


# ================================================================== Sägewerk
def saege():
    M = Model("b_saege", 5.6, 5.6)
    B, G, L = M["body"], M["win_glow"], M["lamp_glow"]
    H = Haus(0.78, 1.08, 3.3, 2.4, 0.25, 3.2)
    hof(M, 5.5, 5.5, 0.9, skip=[(H.x0 + 0.1, H.y0 + 0.1, H.x1 - 0.1, H.y1 - 0.1)])
    H.kern(B)
    F, Rw, Bk, Lw = H.W("f"), H.W("r"), H.W("b"), H.W("l")
    # --- Tür, Fenster, Lampe (in allen Stufen gleich)
    hd = tuer(B, F, 0.95, 0.0)
    schwelle(B, F, 0.95)
    hw = fenster(B, G, F, 2.6, 1.25, 0.8, 1.05, laden=RED_D)
    hr = fenster(B, G, Rw, 1.2, 1.25, 0.9, 1.05)
    lampe(B, L, F, 1.95, 2.55)
    holes = {"f": [hd, hw], "r": [hr], "b": [], "l": []}
    for s in "frbl":                                                            # dunkler Steinsockel
        clad(B, H.W(s), "stone", shade(ST_D, 0.8), v1=0.42, out=0.13, holes=holes[s], size=0.21)
    # --- Stufe 1-3: Bretterwände
    W1 = M["lvmax3_haus"]
    for s in "frbl":
        clad(W1, H.W(s), "plank_v", WOOD, v0=0.42, holes=holes[s], out=0.07)
    ecken(W1, H, WOOD_D, 0.22, 0.11)
    for s in "frbl":
        tile(W1, H.W(s), 0.0, H.h - 0.2, H.W(s).len, H.h, 0.1, 0.1, WOOD_D)
    brett_quer(W1, F, 2.95, 0.85, 0.75, 0.2, -14)                               # schiefes Brett (Gebrauchsspur)
    # --- Stufe 4+: Steinsockel, Putz und Fachwerk
    W4 = M["lv4_haus"]
    for s in "frbl":
        pl = H.W(s)
        clad(W4, pl, "stone", ST, v0=0.42, v1=1.3, holes=holes[s], out=0.1, color2=ST_L)
        clad(W4, pl, "putz", PLASTER, v0=1.3, holes=holes[s], out=0.06)
        fachwerk(W4, pl, 0.0, pl.len, 1.3, H.h, WOOD_D, out=0.1, w=0.17)
    fachwerk(W4, Bk, 0.0, Bk.len, 1.3, H.h, WOOD_D, posts=(1.15, 2.25), diag=((0.17, 1.47, 1.07, 3.03), (3.23, 1.47, 2.33, 3.03)))
    fachwerk(W4, Lw, 0.0, Lw.len, 1.3, H.h, WOOD_D, posts=(1.2,), diag=((0.17, 1.47, 1.12, 3.03), (2.23, 1.47, 1.28, 3.03)))
    tile(W4, F, 1.82, 1.3, 1.98, H.h, 0.11, 0.1, WOOD_D)
    ecken(W4, H, ST_L, out=0.13, style="stein", v1=1.3)
    # --- Dach Stufe 1-6: rotes Ziegeldach
    D1 = M["lvmax6_dach"]
    R1 = dach(D1, (H.cx, H.cy, H.top), H.w, H.d, 1.25, RED, over=0.34, over_g=0.28, ground=0.25)
    giebelfeld(D1, H, 1.25, "plank_h", WOOD_L)
    flicken(D1, R1.planes[0], 2.6, 0.9, 0.7, 0.55, WOOD_P)                       # Flicken auf dem Dach
    px, py, pz = dach_pos(R1, -0.9, 0.55)
    D1.box((0.5, 0.5, 0.5), (px, py, pz + 0.05), STEEL_D)                        # Lüfterkasten
    D1.cyl(0.3, 0.12, (px, py, pz + 0.36), STEEL, r2=0.1, sides=8)
    # Sägeblatt-Schild im Giebel (rechts) und über der Tür
    sg = At(D1, Rw.M(1.2, H.h + 0.5, 0.12) @ rot(90, 0, 0))
    saegeblatt(sg, 0.36, STEEL_L, RED, 10)
    # --- Stufe 7+: Obergeschoss, größeres Dach, Gold
    H2 = Haus(H.cx, H.cy, H.w + 0.2, H.d + 0.2, H.top, 1.5)
    U = M["lv7_stock"]
    H2.kern(U)
    U.box((H.w + 0.5, H.d + 0.5, 0.2), (H.cx, H.cy, H.top + 0.02), WOOD_D)       # Geschossbalken
    g7 = M["lv7_win_glow"]
    hf = [fenster(U, g7, H2.W("f"), 0.95, 0.4, 0.7, 0.8), fenster(U, g7, H2.W("f"), 2.7, 0.4, 0.7, 0.8)]
    for s in "frbl":
        pl = H2.W(s)
        hh = hf if s == "f" else []
        clad(U, pl, "putz", PLASTER, v0=0.1, holes=hh, out=0.05)
        fachwerk(U, pl, 0.0, pl.len, 0.1, 1.5, WOOD_D, out=0.09, w=0.16, posts=(pl.len / 2,) if s != "f" else (1.82,),
                 diag=((0.16, 0.26, pl.len / 2 - 0.08, 1.34), (pl.len - 0.16, 0.26, pl.len / 2 + 0.08, 1.34)) if s != "f" else ())
    R2 = dach(U, (H.cx, H.cy, H2.top), H2.w, H2.d, 1.3, RED, over=0.3, over_g=0.2, ridge=GOLD, ground=0.25, trim=GOLD)
    giebelfeld(U, H2, 1.3, "plank_h", WOOD_L)
    sg = At(U, H2.W("r").M(1.32, 1.5 + 0.5, 0.12) @ rot(90, 0, 0))
    saegeblatt(sg, 0.36, GOLD, RED, 10)
    px, py, pz = dach_pos(R2, -0.9, 0.6)
    U.box((0.5, 0.5, 0.6), (px, py, pz + 0.05), STEEL_D)
    U.cyl(0.3, 0.12, (px, py, pz + 0.42), GOLD, r2=0.1, sides=8)
    for (x, y) in ((H.x0, H.y0), (H.x1, H.y0)):                                   # goldene Eckbeschläge
        U.box((0.3, 0.3, 0.16), (x, y - 0.0, H.z0 + 1.38), GOLD)
        U.box((0.3, 0.3, 0.12), (x, y - 0.0, H.z0 + 0.5), GOLD)
    tile(U, F, 0.25, 2.86, 1.65, 3.12, 0.2, 0.08, GOLD)
    # --- Sägetisch mit Schlitten, Stamm und Kreissäge
    tx, ty, tz = -1.25, -1.35, 0.25
    for sx in (-1.15, 0.0, 1.15):
        for sy in (-0.36, 0.36):
            B.box((0.18, 0.18, 0.72), (tx + sx, ty + sy, tz + 0.36), jit(WOOD_D))
    for sy in (-0.36, 0.36):
        B.box((2.7, 0.12, 0.14), (tx, ty + sy, tz + 0.5), WOOD_D)
    for i in range(3):
        B.box((2.7, 0.3, 0.1), (tx, ty + (i - 1) * 0.31, tz + 0.77), jit(WOOD_L, 0.08))
    for sy in (-0.3, 0.3):
        B.box((2.6, 0.05, 0.05), (tx, ty + sy, tz + 0.845), STEEL)                # Schienen
    B.box((1.15, 0.8, 0.09), (tx - 0.62, ty, tz + 0.915), STEEL_D)               # Schlitten
    for sx in (-0.45, 0.45):
        B.box((0.12, 0.74, 0.2), (tx - 0.62 + sx, ty, tz + 1.02), RED_D)
    stamm(B, (tx - 1.25, ty, tz + 1.25), (tx + 0.15, ty, tz + 1.25), 0.27)
    bx = tx + 0.72
    B.box((0.5, 0.1, 0.75), (bx, ty + 0.36, tz + 0.4), RED_D)                    # Sägelager
    B.box((0.08, 0.1, 0.5), (bx - 0.02, ty - 0.02, tz + 1.82), RED, r=rot(0, 0, 0))
    beam(B, (bx + 0.45, ty + 0.4, tz + 0.85), (bx + 0.2, ty + 0.1, tz + 1.95), 0.08, RED_D)
    B.cyl(0.74, 0.14, (bx, ty + 0.06, tz + 1.12), RED, r=rot(90, 0, 0) @ S(1, 1, 1), sides=14)   # Schutzhaube (hintere Hälfte verdeckt)
    sp = M.origin("spin_blade", (bx, ty - 0.06, tz + 1.12), (math.radians(90), 0, 0), local=True)
    saegeblatt(sp, 0.68)
    sp.cyl(0.06, 0.9, (0, 0, -0.45), DK, sides=6)                                 # Welle nach hinten
    sp.cyl(0.2, 0.12, (0, 0, -0.84), STEEL_D, sides=10)                           # Riemenscheibe
    # --- Motor mit Schwungrad und Riemen
    mx, my = -2.0, -0.18
    B.box((0.95, 0.62, 0.16), (mx, my, 0.33), DK)
    B.box((0.8, 0.5, 0.55), (mx, my, 0.68), "2F8F5A", bevel=0.08, segs=1)
    B.cyl(0.16, 0.5, (mx - 0.15, my, 1.02), "2F8F5A", sides=8)
    B.cyl(0.2, 0.08, (mx - 0.15, my, 1.3), STEEL_D, sides=8)
    pipe(B, [(mx + 0.25, my, 0.9), (mx + 0.25, my, 1.9), (mx + 0.25, my + 0.0, 2.1)], 0.07, STEEL_D, 6)
    B.cyl(0.11, 0.3, (mx + 0.25, my, 2.2), DK, sides=6)
    M.empty("fx_smoke", (mx + 0.25, my, 2.45))
    wy = ty + 0.06 + 0.84 - 0.06
    fw = M.origin("spin_wheel", (mx, wy, 0.95), (math.radians(90), 0, 0), local=True)
    fw.torus(0.4, 0.07, (0, 0, 0), RED_D, seg=12, tseg=6)
    for i in range(3):
        fw.box((0.78, 0.08, 0.06), (0, 0, 0), STEEL, r=rot(0, 0, i * 60))
    fw.cyl(0.12, 0.2, (0, 0, 0), DK, sides=8)
    B.cyl(0.06, 0.5, (mx, wy + 0.2, 0.95), DK, r=rot(90, 0, 0), sides=6)
    for dz in (-1, 1):                                                           # Riemen
        beam(B, (mx, wy, 0.95 + dz * 0.44), (bx, wy, tz + 1.12 + dz * 0.2), 0.035, "22252E", d=0.1)
    # --- Sägespäne-Auswurf
    B.box((0.34, 0.75, 0.06), (bx, ty - 0.75, tz + 0.5), STEEL, r=rot(-28, 0, 0))
    for sx in (-0.17, 0.17):
        B.box((0.04, 0.75, 0.16), (bx + sx, ty - 0.75, tz + 0.54), STEEL_D, r=rot(-28, 0, 0))
    B.cone(0.45, 0.4, (bx, ty - 0.92, tz + 0.2), "E9CF8E", sides=9)
    B.cone(0.3, 0.24, (bx + 0.4, ty - 0.85, tz + 0.11), "E2C27C", sides=7)
    fleck(B, bx - 0.1, ty - 0.75, 0.25, 0.75, "E6CB8A")
    M.empty("fx_steam_dust", (bx, ty - 0.2, tz + 1.7))
    # --- Stammlager (wächst mit dem Lagerstand)
    lx = -1.88
    for y in (0.55, 2.2):
        B.box((1.75, 0.16, 0.14), (lx, y, 0.32), WOOD_D)
        for sx in (-0.82, 0.82):
            B.box((0.14, 0.16, 1.5), (lx + sx, y, 1.0), jit(WOOD_D))
    f1, f2, f3 = M["fill1_logs"], M["fill2_logs"], M["fill3_logs"]
    for i in range(3):
        stamm(f1, (lx - 0.5 + i * 0.5, 0.25, 0.64), (lx - 0.5 + i * 0.5, 2.5 + RNG.uniform(-0.1, 0.1), 0.64), 0.24)
    for i in range(2):
        stamm(f2, (lx - 0.25 + i * 0.5, 0.3, 1.07), (lx - 0.25 + i * 0.5, 2.5 + RNG.uniform(-0.1, 0.1), 1.07), 0.24)
    stamm(f2, (lx - 0.7, 0.3, 1.05), (lx - 0.7, 2.4, 1.05), 0.2)
    stamm(f3, (lx, 0.3, 1.5), (lx, 2.45, 1.5), 0.24)
    stamm(f3, (lx + 0.48, 0.4, 1.48), (lx + 0.48, 2.5, 1.48), 0.2)
    # --- Bretterstapel, Hackklotz
    bretter(B, (2.1, -1.0, 0.25), 3, 1.5, 0.8, yaw=90)
    B.box((0.12, 0.9, 0.1), (2.1, -1.0, 0.25 + 0.0), WOOD_D)
    axtklotz(B, (2.15, -2.05, 0.25))
    scheit(B, (1.45, -2.1, 0.25), 5)
    A4 = M["lv4_anbau"]                                                           # Stufe 4: Unterstand für mehr Bretter
    for (x, y) in ((1.55, -1.75), (2.62, -1.75), (1.55, -0.2), (2.62, -0.2)):
        A4.box((0.14, 0.14, 2.0 if y < -1 else 2.35), (x, y, 0.25 + (1.0 if y < -1 else 1.17)), WOOD_D)
    pultdach(A4, (2.06, -0.97, 2.25), 1.1, 1.6, 0.36, "8FA0B8", over=0.14, style="blech")
    bretter(A4, (2.1, -1.0, 0.25 + 0.4), 3, 1.5, 0.8, yaw=90, color=WOOD_P)
    stamm(A4, (tx - 1.3, ty + 0.3, tz + 1.0), (tx - 0.2, ty + 0.3, tz + 1.0), 0.14)
    # --- Gebrauchsspuren
    moos(B, Bk, 0.8, 4, 1.2); moos(B, Lw, 1.9, 3, 0.8, out=0.16)
    fleck(B, mx + 0.3, my - 0.55, 0.25, 0.4, "3A3A40")                            # Ölfleck am Motor
    # --- Schaden
    d1, d2 = M["dmg1_spuren"], M["dmg2_bruch"]
    riss(d1, F, 2.2, 0.5, 1.1); riss(d1, Rw, 0.5, 0.6, 1.2); riss(d1, Bk, 1.5, 0.5, 1.3)
    russ(d1, F, 3.05, 2.3, 0.45); russ(d1, Rw, 1.9, 1.5, 0.5)
    brett_quer(d1, F, 2.6, 1.75, 1.3, 0.2, 18, out=0.24)
    loch(d2, Rw, 0.55, 2.2, 0.42); loch(d2, F, 2.1, 0.9, 0.3)
    stuetze(d2, (2.55, -0.55, 0.25), (H.x1 + 0.12, 0.35, 2.3))
    stuetze(d2, (0.9, -0.85, 0.25), (1.2, H.y0 - 0.12, 2.6))
    for i in range(4):
        d2.box((0.7, 0.16, 0.06), (0.4 + i * 0.25, -0.75 - i * 0.12, 0.3), jit(WOOD), r=rot(0, 6, 30 + i * 37))
    M.empty("fx_smoke_dmg", (H.x1 - 0.5, H.cy, H.top + 0.6))
    M.punkte(door=(H.x0 + 0.95, H.y0 - 0.55), work_1=(bx - 0.3, ty - 0.95), work_2=(1.45, -1.75), drop=(1.3, -0.9), bubble=(H.cx, H.cy, 6.4))
    M.finish()


MODELS = {"b_saege": saege}


# ================================================================== Steinbruch
def steinbruch():
    M = Model("b_steinbruch", 5.6, 5.6)
    B, G, L = M["body"], M["win_glow"], M["lamp_glow"]
    H = Haus(1.33, 1.5, 2.3, 1.8, 0.25, 2.9)
    hof(M, 5.5, 5.5, 1.35, color="D6CFC2", skip=[(H.x0 + 0.1, H.y0 + 0.1, H.x1 - 0.1, H.y1 - 0.1), (-2.7, 0.9, 0.0, 2.7)])
    H.kern(B)
    F, Rw = H.W("f"), H.W("r")
    hd = tuer(B, F, 0.95, 0.0, 1.4, 2.5)
    schwelle(B, F, 0.95)
    hr = fenster(B, G, Rw, 0.9, 1.2, 0.8, 0.95)
    lampe(B, L, F, 2.0, 2.2)
    holes = {"f": [hd], "r": [hr]}
    sockel(B, H, holes)
    wandsatz(M["lvmax3_huette"], H, "bretter", holes)
    wandsatz(M["lv4_huette"], H, "stein", holes, color="C9BFAE", color2="DDD5C6")
    R = dach(B, (H.cx, H.cy, H.top), H.w, H.d, 1.0, RED, over=0.28, over_g=0.2, ground=0.25)
    giebelfeld(B, H, 1.0, "plank_h", WOOD_L)
    flicken(B, R.planes[0], 0.9, 0.7, 0.6, 0.5, WOOD_P)
    px, py, pz = dach_pos(R, 0.5, -0.35)
    schornstein(M, B, (px, py, pz - 0.5), 1.1, 0.42, fx=None)
    sb = schild(B, F, 0.95, 2.95, 0.9, 0.42)                                      # Schild: Spitzhacke
    sb.box((0.6, 0.04, 0.07), (0, 0, 0), WOOD_D, r=rot(0, 35, 0))
    sb.box((0.5, 0.04, 0.09), (0.18, -0.01, 0.12), STEEL, r=rot(0, -50, 0))
    X7 = M["lv7_gold"]
    X7.cyl(0.16, H.w + 0.5, (H.cx, H.cy, H.top + 1.12), GOLD, r=rot(0, 90, 0), sides=6)
    for (x, y) in ((H.x0, H.y0), (H.x1, H.y0), (H.x1, H.y1)):
        X7.box((0.34, 0.34, 0.14), (x, y, H.z0 + 2.75), GOLD)
        X7.box((0.34, 0.34, 0.14), (x, y, H.z0 + 0.5), GOLD)
    # --- Felswand mit Abbaukante (hinten links, zwei Stufen)
    ROCK, ROCK_D, ROCK_L = "A39A9C", "857C82", "BDB5B2"
    B.box((2.7, 1.7, 1.5), (-1.25, 1.7, 1.0), ROCK_D)
    B.box((2.1, 1.1, 1.3), (-1.5, 1.98, 2.35), ROCK_D)
    for i in range(6):                                                           # untere Stufe
        fels(B, (-2.3 + i * 0.5, 0.95 + RNG.uniform(-0.1, 0.1), 0.25), (0.6, 0.6, RNG.uniform(1.3, 1.65)), ROCK)
    for i in range(4):
        fels(B, (-2.33, 1.35 + i * 0.36, 0.25), (0.55, 0.5, 1.7), ROCK)
        fels(B, (-0.05, 1.3 + i * 0.36, 0.25), (0.5, 0.5, RNG.uniform(1.2, 1.6)), ROCK)
    for i in range(5):                                                           # obere Stufe
        fels(B, (-2.28 + i * 0.47, 1.6 + RNG.uniform(-0.08, 0.08), 1.7), (0.6, 0.55, RNG.uniform(1.2, 1.5)), ROCK_L)
    for i in range(3):
        fels(B, (-2.2 + i * 0.68, 2.2, 2.6), (0.7, 0.6, RNG.uniform(0.5, 0.9)), ROCK_L)
        fels(B, (-0.35, 1.7 + i * 0.36, 1.7), (0.5, 0.45, RNG.uniform(0.9, 1.3)), ROCK)
    pl = boden(-2.55, 0.95, 1.76)
    for i in range(5):                                                           # helle Abbaufläche (frisch gebrochen)
        tile(B, pl, 0.2 + i * 0.5, 0.05, 0.66 + i * 0.5, 0.5, 0.03, 0.03, jit("D8D0C8", 0.05))
    B.box((0.5, 0.45, 0.4), (-1.2, 1.2, 1.9), "D8D0C8", r=rot(0, 0, 12), bevel=0.05, segs=1)     # halb gelöster Block
    beam(B, (-1.9, 1.15, 1.8), (-1.75, 1.05, 2.6), 0.05, WOOD_L)                 # Spitzhacke in der Wand
    B.box((0.45, 0.06, 0.08), (-1.75, 1.05, 2.58), STEEL, r=rot(0, 15, 30))
    leiter(B, (-0.7, 0.45, 0.25), (-0.7, 0.92, 1.85), 0.45)
    # --- Gleis und Lore
    schienen(B, (-1.85, 0.6), (-1.85, -2.42), 0.25)
    B.box((0.9, 0.14, 0.3), (-1.85, -2.4, 0.4), RED_D)                          # Prellbock
    lore(B, (-1.85, -1.3, 0.3), 0, STEEL_D, load="C9C1BD")
    # --- Kran mit Steinblock am Seil
    kx, ky = -0.75, -0.15
    tip = (-1.85, -0.35, 4.0)
    B.box((0.7, 0.7, 0.2), (kx, ky, 0.35), ST_D)
    K1, K7 = M["lvmax6_kran"], M["lv7_kran"]
    K1.box((0.2, 0.2, 3.1), (kx, ky, 1.95), WOOD_D)
    beam(K1, (kx + 0.15, ky, 3.2), tip, 0.16, WOOD)
    beam(K1, (kx + 0.5, ky, 0.5), (kx, ky, 1.7), 0.1, WOOD_D)
    beam(K1, (kx, ky + 0.5, 0.5), (kx, ky, 1.7), 0.1, WOOD_D)
    kabel(K1, (kx, ky, 3.5), tip, 0.0, 0.025, "C9B38A", 1)
    K1.box((0.24, 0.24, 0.1), (kx, ky, 3.52), WOOD_D)
    K7.box((0.26, 0.26, 3.1), (kx, ky, 1.95), GOLD_D)
    for i in range(5):
        K7.box((0.3, 0.3, 0.06), (kx, ky, 0.7 + i * 0.6), "22252E")
    beam(K7, (kx + 0.15, ky, 3.2), tip, 0.2, GOLD)
    beam(K7, (kx + 0.6, ky, 0.5), (kx, ky, 2.2), 0.1, STEEL_D)
    beam(K7, (kx, ky + 0.6, 0.5), (kx, ky, 2.2), 0.1, STEEL_D)
    kabel(K7, (kx, ky, 3.6), tip, 0.0, 0.03, "22252E", 1)
    K7.box((0.34, 0.34, 0.12), (kx, ky, 3.56), GOLD)
    B.cyl(0.2, 0.12, (kx + 0.16, ky - 0.14, 1.3), STEEL, r=rot(90, 0, 0), sides=8)      # Winde
    sw = M.origin("sway_block", tip, local=True)
    sw.cyl(0.02, 1.5, (0, 0, -0.75), "C9B38A", sides=4)
    sw.box((0.1, 0.1, 0.16), (0, 0, -1.5), STEEL_D)
    for sx in (-1, 1):
        beam(sw, (0, 0, -1.55), (sx * 0.3, 0, -1.85), 0.03, "C9B38A")
    sw.box((0.75, 0.6, 0.55), (0, 0, -2.1), "CFC7C2", bevel=0.06, segs=1)
    sw.box((0.78, 0.08, 0.57), (0, 0, -2.1), "8A6A42")
    # --- Brecher mit Schwungrad, Rutsche und Staub
    cx, cy = 0.15, -1.2
    for sx in (-1, 1):
        for sy in (-1, 1):
            B.box((0.14, 0.14, 1.3), (cx + sx * 0.5, cy + sy * 0.45, 0.9), STEEL_D)
    B.box((1.2, 1.1, 0.75), (cx, cy, 1.45), "D9912B", bevel=0.06, segs=1)
    B.cyl(0.95, 0.6, (cx, cy, 2.1), "D9912B", r=rot(0, 0, 45), r2=1.0, sides=4)
    B.cyl(0.78, 0.5, (cx, cy, 2.17), "3A3530", r=rot(0, 0, 45), r2=0.86, sides=4)
    for i in range(4):
        B.box((0.3, 0.28, 0.24), (cx + RNG.uniform(-0.3, 0.3), cy + RNG.uniform(-0.3, 0.3), 2.36), jit("BDB5B2", 0.1), r=rot(20, 10, i * 40), bevel=0.05, segs=1)
    warn = wand((cx - 0.6, cy - 0.56), (cx + 0.6, cy - 0.56), 1.1)
    warnstreifen(B, warn, 0.0, 1.2, 0.0, 0.2, 0.01)
    sp = M.origin("spin_brecher", (cx + 0.68, cy, 1.45), (0, math.radians(90), 0), local=True)
    sp.torus(0.42, 0.07, (0, 0, 0), DK, seg=12, tseg=6)
    for i in range(3):
        sp.box((0.84, 0.09, 0.06), (0, 0, 0), STEEL, r=rot(0, 0, i * 60))
    sp.cyl(0.13, 0.16, (0, 0, 0), RED, sides=8)
    B.box((0.5, 1.0, 0.07), (cx, cy - 0.85, 0.75), STEEL, r=rot(-32, 0, 0))                # Rutsche
    for sx in (-1, 1):
        B.box((0.05, 1.0, 0.2), (cx + sx * 0.25, cy - 0.85, 0.8), STEEL_D, r=rot(-32, 0, 0))
    M.empty("fx_smoke_staub", (cx, cy, 2.7))
    M.empty("fx_spark", (cx, cy - 0.5, 1.1))
    # --- Steinhaufen nach Größe sortiert (drei Buchten rechts vorn)
    for (y0, y1) in ((-2.45, -1.55), (-1.55, -0.65), (-0.65, 0.25)):
        B.box((1.0, 0.1, 0.5), (2.12, y1, 0.5), jit(WOOD_D))
    B.box((0.1, 2.8, 0.6), (2.66, -1.05, 0.55), WOOD_D)
    B.cone(0.42, 0.42, (2.1, -2.0, 0.24), "B9B1AC", sides=8)                              # Schotter
    steinhaufen(B, (2.1, -2.0, 0.3), 6, 0.14, "C4BCB6", 0.3)
    steinhaufen(B, (2.1, -1.1, 0.25), 8, 0.28, "ADA5A6", 0.24)                               # mittlere Steine
    for (dx, dy, dz) in ((-0.12, 0.0, 0.0), (0.2, 0.1, 0.0), (0.0, 0.05, 0.42)):           # große Quader
        B.box((0.5, 0.42, 0.4), (2.1 + dx * 1.5, -0.25 + dy, 0.45 + dz), jit("CFC7C2", 0.06), r=rot(0, 0, RNG.uniform(-8, 8)), bevel=0.04, segs=1)
    B.cone(0.36, 0.3, (cx + 0.0, cy - 1.15, 0.24), "B9B1AC", sides=8)
    # --- Stufe 4: zweite Lore, größere Haufen, Laterne; Stufe 7: Förderband
    X4 = M["lv4_ausbau"]
    lore(X4, (-1.85, 0.05, 0.3), 0, "5E7FB5")
    steinhaufen(X4, (2.1, -1.1, 0.55), 5, 0.28, "ADA5A6", 0.2)
    X4.box((0.5, 0.42, 0.4), (2.05, -0.2, 1.28), jit("CFC7C2"), r=rot(0, 0, 14), bevel=0.04, segs=1)
    laterne(X4, M["lv4_lamp_glow"], 0.75, 0.55, 0.25, 2.2)
    for i in range(3):
        fels(X4, (-2.2 + i * 0.6, 0.45, 0.25), (0.5, 0.45, 0.6), ROCK_L)
    beam(X7, (cx + 0.0, cy - 1.2, 0.5), (1.55, -2.1, 1.6), 0.4, "22252E", d=0.08)           # Förderband zum Schotter
    for q in ((cx, cy - 1.2, 0.3), (1.55, -2.1, 0.85)):
        X7.box((0.1, 0.1, q[2] * 1.6), (q[0], q[1], 0.25 + q[2] * 0.8), GOLD_D)
    X7.cone(0.45, 0.5, (2.1, -2.0, 0.6), "C4BCB6", sides=8)
    tile(X7, warn, -0.02, 0.5, 1.22, 0.64, 0.02, 0.03, GOLD)
    # --- Gebrauchsspuren
    moos(B, H.W("b"), 1.0, 3, 1.0); moos(B, wand((-2.7, 0.62), (0.2, 0.62), 0.25), 1.2, 4, 2.0, out=0.0)
    fleck(B, cx + 0.5, cy - 0.9, 0.25, 0.6, "BBB3AD")
    brett_quer(M["lvmax3_huette"], Rw, 1.45, 0.8, 0.6, 0.18, 10)
    # --- Schaden
    d1, d2 = M["dmg1_spuren"], M["dmg2_bruch"]
    riss(d1, F, 1.95, 0.5, 1.2); riss(d1, Rw, 0.3, 0.5, 1.4); russ(d1, Rw, 1.4, 2.0, 0.42); russ(d1, F, 2.0, 1.4, 0.35)
    loch(d2, Rw, 1.5, 1.0, 0.36)
    stuetze(d2, (H.x1 + 0.0, H.y0 - 0.75, 0.25), (H.x1 - 0.25, H.y0 - 0.12, 2.2))
    steinhaufen(d2, (1.2, 0.3, 0.25), 6, 0.22, ROCK, 0.4)
    d2.box((0.9, 0.16, 0.06), (0.9, -0.3, 0.3), WOOD, r=rot(0, 5, 40))
    M.empty("fx_smoke_dmg", (H.cx, H.cy, H.top + 0.9))
    M.punkte(door=(H.x0 + 0.95, H.y0 - 0.55), work_1=(-1.15, -1.3), work_2=(cx + 0.2, cy - 1.0 + 1.9), drop=(1.45, -1.9), bubble=(0.3, 0.6, 5.2))
    M.finish()


MODELS["b_steinbruch"] = steinbruch


# ================================================================== Schrottpresse
def schrott(p, loc, n=6, r=0.4, s=0.26):
    """Haufen bunter Schrott-Teile."""
    x, y, z = loc
    cols = (RUST, STEEL, "5E7FB5", "C9A227", STEEL_D, RED_D, "6E8F4E")
    for i in range(n):
        a = RNG.uniform(0, 6.28); d = RNG.uniform(0, r)
        ss = s * RNG.uniform(0.7, 1.3)
        k = RNG.random()
        q = (x + math.cos(a) * d, y + math.sin(a) * d, z + ss * 0.3 + (s * 0.5 if i > n * 0.6 else 0))
        rr = rot(RNG.uniform(-30, 30), RNG.uniform(-30, 30), RNG.uniform(0, 180))
        if k < 0.3:
            p.cyl(ss * 0.5, ss * 0.5, q, jit(cols[i % 7], 0.1), r=rr, sides=6)
        elif k < 0.5:
            p.torus(ss * 0.5, ss * 0.18, q, "tire", r=rr, seg=8, tseg=4)
        else:
            p.box((ss * 1.3, ss * 0.8, ss * 0.5), q, jit(cols[i % 7], 0.1), r=rr)


def wuerfel(p, loc, s=0.62, yaw=0.0):
    """Gepresster Schrottwürfel mit bunten Platten und Spannband."""
    x, y, z = loc
    a = At(p, T(x, y, z + s / 2) @ rot(0, 0, yaw))
    cols = (RUST, STEEL, "5E7FB5", "C9A227", STEEL_D, RED_D)
    a.box((s, s, s), (0, 0, 0), shade(STEEL_D, 0.8))
    for (dx, dy, dz, sx, sy, sz) in ((0, 0, 0.5, 0.46, 0.46, 0.04), (0.5, 0, 0, 0.04, 0.46, 0.46), (-0.5, 0, 0, 0.04, 0.46, 0.46),
                                     (0, 0.5, 0, 0.46, 0.04, 0.46), (0, -0.5, 0, 0.46, 0.04, 0.46)):
        for (qx, qy) in ((-0.24, -0.24), (0.24, -0.24), (-0.24, 0.24), (0.24, 0.24)):
            ox = (qx if dx == 0 else 0.0, (qx if dx != 0 else qy) if dy == 0 else 0.0, qy if dz == 0 else 0.0)
            a.box((sx * s if sx > 0.1 else 0.03, sy * s if sy > 0.1 else 0.03, sz * s if sz > 0.1 else 0.03),
                  ((dx + ox[0]) * s, (dy + ox[1]) * s, (dz + ox[2]) * s), jit(cols[RNG.randrange(6)], 0.1))
    a.box((s + 0.05, 0.07, s + 0.05), (0, 0, 0), "22252E")


def presse():
    M = Model("b_presse", 5.6, 5.6)
    B, G, L = M["body"], M["win_glow"], M["lamp_glow"]
    H = Haus(1.36, 1.55, 2.3, 1.9, 0.25, 2.9)
    hof(M, 5.5, 5.5, 1.3, color="C4C6CC", skip=[(H.x0 + 0.1, H.y0 + 0.1, H.x1 - 0.1, H.y1 - 0.1)])
    H.kern(B)
    F, Rw = H.W("f"), H.W("r")
    hd = tuer(B, F, 0.9, 0.0, 1.4, 2.5, color="6F7F9E", frame=DK, luke=True)
    schwelle(B, F, 0.9)
    hr = fenster(B, G, Rw, 0.95, 1.2, 0.9, 0.95, frame=DK)
    hf = fenster(B, G, F, 1.95, 1.5, 0.36, 0.7, frame=DK, kreuz=False)
    lampe(B, L, F, 1.95, 2.45)
    holes = {"f": [hd, hf], "r": [hr]}
    sockel(B, H, holes, shade(CONC_D, 0.8))
    wandsatz(M["lvmax3_kabine"], H, "blech", holes, color="B08A62")
    brett_quer(M["lvmax3_kabine"], Rw, 0.45, 0.9, 0.6, 0.5, 6, color=RUST)
    wandsatz(M["lv4_kabine"], H, "ziegel", holes)
    pl = pultdach(B, (H.cx, H.cy, H.top), H.w, H.d, 0.5, "5E7FB5", over=0.2, style="blech")
    for s, ln in (("l", pult(0, H.d, 0.5, 0.0)), ("r", pult(0, H.d, 0.0, 0.5))):
        w = H.W(s)
        slab(B, w, [(0, H.h), (w.len, H.h), ((w.len if s == "r" else 0), H.h + 0.5)], 0.0, 0.0, JOINT)
        clad(B, w, "plank_h", STEEL, v0=H.h, v1=H.h + 0.5, out=0.07, lines=[(-0.5 / H.d, 1.0, H.h)] if s == "r" else [(0.5 / H.d, 1.0, H.h + 0.5)])
    clad(B, H.W("b"), "plank_h", STEEL, v0=H.h, v1=H.h + 0.5, out=0.07)
    flicken(B, pl, 0.9, 0.9, 0.6, 0.5, RUST)
    B.cyl(0.14, 0.9, (H.x1 - 0.5, H.cy + 0.3, H.top + 0.75), STEEL_D, sides=8)          # Auspuff
    B.cyl(0.19, 0.12, (H.x1 - 0.5, H.cy + 0.3, H.top + 1.2), DK, sides=8)
    M.empty("fx_smoke", (H.x1 - 0.5, H.cy + 0.3, H.top + 1.4))
    # --- Presse: Rahmen, Kammer, hydraulischer Stempel
    px, py = -1.0, 1.2
    PC = "E0A21E"
    B.box((2.3, 1.7, 0.3), (px, py, 0.4), DK, bevel=0.04, segs=1)
    B.box((1.5, 1.3, 0.75), (px, py, 0.92), STEEL_D)
    B.box((1.3, 1.36, 0.5), (px, py - 0.02, 1.0), "22252E")
    for sx in (-1, 1):
        B.box((0.36, 0.5, 3.6), (px + sx * 0.95, py, 2.35), PC, bevel=0.05, segs=1)
        B.box((0.42, 0.56, 0.2), (px + sx * 0.95, py, 0.65), DK)
        w = wand((px + sx * 0.95 - 0.18, py - 0.26), (px + sx * 0.95 + 0.18, py - 0.26), 0.8)
        warnstreifen(B, w, 0.0, 0.36, 0.0, 0.5, 0.01, 3)
        for z in (1.6, 2.4, 3.2):
            for dx in (-0.1, 0.1):
                stud(B, w, 0.18 + dx, z - 0.8, 0.0, 0.035, STEEL_L)
    B.box((2.6, 0.7, 0.55), (px, py, 4.25), PC, bevel=0.06, segs=1)
    B.box((1.2, 0.76, 0.3), (px, py, 4.25), DK)
    B.cyl(0.3, 0.6, (px, py, 3.75), STEEL_D, sides=10)
    wuerfel(B, (px, py - 0.02, 0.86), 0.6)
    st = M.origin("bob_stempel", (px, py, 2.6), local=True)
    st.cyl(0.18, 1.4, (0, 0, 0.6), STEEL_L, sides=10)
    st.box((1.25, 1.1, 0.5), (0, 0, -0.3), "C9463E", bevel=0.05, segs=1)
    st.box((1.35, 1.2, 0.14), (0, 0, -0.6), STEEL_D)
    for sx in (-1, 1):
        st.cyl(0.07, 1.0, (sx * 0.45, 0, 0.45), STEEL_L, sides=6)
    for sx in (-1, 1):                                                           # Hydraulikschläuche
        kabel(B, (px + sx * 0.3, py + 0.3, 4.0), (px + sx * 0.95, py + 0.3, 2.3), 0.3, 0.04, "22252E", 4)
    M.empty("fx_spark", (px, py - 0.4, 1.55))
    M.empty("fx_steam", (px + 0.5, py + 0.2, 3.9))
    # --- Förderband mit Schrott (von vorn links hinauf in die Presse)
    a0, a1 = Vector((-1.0, -2.2, 0.75)), Vector((-1.0, 0.45, 1.5))
    beam(B, a0, a1, 0.85, "2A2C34", d=0.1)
    for sx in (-1, 1):
        beam(B, a0 + Vector((sx * 0.46, 0, 0.03)), a1 + Vector((sx * 0.46, 0, 0.03)), 0.07, PC, d=0.2)
    for (q, hh) in ((-1.9, 0.6), (-0.6, 0.95)):
        for sx in (-1, 1):
            B.box((0.1, 0.1, hh), (-1.0 + sx * 0.46, q, 0.25 + hh / 2), STEEL_D)
    for i in range(6):
        t = (i + 0.5) / 6
        q = a0 + (a1 - a0) * t
        if i % 2 == 0:
            B.box((0.4, 0.3, 0.2), (q.x + RNG.uniform(-0.15, 0.15), q.y, q.z + 0.16), jit((RUST, "5E7FB5", "C9A227")[i // 2], 0.1), r=rot(16, RNG.uniform(-20, 20), RNG.uniform(0, 90)))
        else:
            B.cyl(0.14, 0.3, (q.x + RNG.uniform(-0.15, 0.15), q.y, q.z + 0.2), jit(STEEL, 0.1), r=rot(60, 0, RNG.uniform(0, 90)), sides=6)
    for (nm, q) in (("spin_rolle", a0), ("spin_rolle2", a1)):
        sp = M.origin(nm, (q.x, q.y, q.z), (0, math.radians(90), 0), local=True)
        sp.cyl(0.14, 0.95, (0, 0, 0), STEEL, sides=8)
        for sx in (-1, 1):
            sp.cyl(0.2, 0.06, (0, 0, sx * 0.5), RED_D, sides=8)
            sp.box((0.3, 0.06, 0.02), (0, 0, sx * 0.535), STEEL_L)
    schrott(B, (-2.1, -1.9, 0.25), 9, 0.42, 0.3)                                          # Schrotthaufen am Bandanfang
    # --- Magnetkran
    kx, ky = 0.2, -0.6
    B.cyl(0.3, 0.2, (kx, ky, 0.35), DK, sides=8)
    B.cyl(0.12, 3.3, (kx, ky, 1.9), "5E7FB5", sides=8)
    tip = (-0.2, -1.95, 3.55)
    beam(B, (kx, ky, 3.45), tip, 0.16, "5E7FB5")
    beam(B, (kx, ky + 0.0, 2.3), (kx - 0.25, ky - 0.85, 3.5), 0.07, STEEL_D)
    B.box((0.4, 0.5, 0.4), (kx + 0.1, ky + 0.35, 3.35), DK)                              # Gegengewicht
    mg = M.origin("sway_magnet", tip, local=True)
    mg.cyl(0.02, 1.2, (0, 0, -0.6), "22252E", sides=4)
    mg.cyl(0.36, 0.2, (0, 0, -1.3), RED, sides=10)
    mg.cyl(0.4, 0.08, (0, 0, -1.42), STEEL_D, sides=10)
    mg.box((0.4, 0.3, 0.14), (0.05, 0.0, -1.55), RUST, r=rot(10, 8, 30))
    mg.cyl(0.13, 0.22, (-0.15, 0.1, -1.6), STEEL, r=rot(70, 0, 20), sides=6)
    # --- Würfelstapel (vorn rechts)
    for (x, y, z, yw) in ((2.2, -2.05, 0.25, 4), (1.5, -2.1, 0.25, -6), (2.25, -1.35, 0.25, 8), (1.85, -2.05, 0.87, 12)):
        wuerfel(B, (x, y, z), 0.6, yw)
    X4 = M["lv4_ausbau"]
    wuerfel(X4, (2.25, -1.4, 0.87), 0.6, -5); wuerfel(X4, (1.55, -1.4, 0.25), 0.6, 3)
    schrott(X4, (-2.15, -0.9, 0.25), 7, 0.35, 0.3)
    B.box((0.5, 0.3, 1.1), (0.75, 0.8, 0.8), "5E7FB5", bevel=0.04, segs=1)                 # Schalttafel
    M["panel_glow"].box((0.12, 0.04, 0.12), (0.63, 0.64, 1.15), "5FE38A")
    M["panel_glow"].box((0.12, 0.04, 0.12), (0.87, 0.64, 1.15), HOT)
    B.box((0.06, 0.06, 0.3), (0.75, 0.6, 0.95), RED, r=rot(-30, 0, 0))
    # --- Stufe 7: Stahl und Gold
    X7 = M["lv7_gold"]
    X7.box((2.7, 0.78, 0.14), (px, py, 4.58), GOLD)
    X7.box((2.7, 0.78, 0.12), (px, py, 3.95), GOLD)
    star(X7, (px, py - 0.4, 4.25), 0.3, GOLD, 0.06)
    for sx in (-1, 1):
        X7.box((0.44, 0.58, 0.14), (px + sx * 0.95, py, 1.45), GOLD)
    for (x, y) in ((H.x0, H.y0), (H.x1, H.y0), (H.x1, H.y1)):
        X7.box((0.32, 0.32, H.h - 0.4), (x, y, H.z0 + 0.4 + (H.h - 0.4) / 2), STEEL)
        X7.box((0.36, 0.36, 0.14), (x, y, H.z0 + 2.7), GOLD)
        X7.box((0.36, 0.36, 0.14), (x, y, H.z0 + 0.55), GOLD)
    tile(X7, F, 0.0, 2.7, F.len, 2.86, 0.16, 0.06, GOLD)
    tile(X7, Rw, 0.0, 2.7, Rw.len, 2.86, 0.16, 0.06, GOLD)
    wuerfel(X7, (1.5, -2.1, 0.87), 0.6, 9)
    X7.box((0.8, 0.5, 0.5), (H.cx - 0.4, H.cy, H.top + 0.5), STEEL_D)                      # Klimagerät auf dem Dach
    X7.cyl(0.2, 0.06, (H.cx - 0.4, H.cy, H.top + 0.78), GOLD, sides=8)
    # --- Gebrauchsspuren
    fleck(B, 0.1, -1.4, 0.25, 0.5, "2B2A30"); fleck(B, px + 0.2, py - 1.1, 0.25, 0.35, "3A3A40")
    moos(B, H.W("b"), 1.2, 3, 1.0)
    # --- Schaden
    d1, d2 = M["dmg1_spuren"], M["dmg2_bruch"]
    riss(d1, F, 2.0, 0.4, 1.0); riss(d1, Rw, 0.3, 0.5, 1.3); russ(d1, Rw, 1.5, 2.0, 0.45); russ(d1, F, 0.2, 2.3, 0.3)
    russ(d1, wand((px - 1.3, py - 0.36), (px + 1.3, py - 0.36), 3.98), 2.0, 0.3, 0.3, out=0.02)
    loch(d2, Rw, 1.55, 1.0, 0.36, splitter=STEEL_D)
    stuetze(d2, (H.x1 - 0.1, H.y0 - 0.8, 0.25), (H.x1 - 0.3, H.y0 - 0.12, 2.2))
    schrott(d2, (0.9, -0.2, 0.25), 6, 0.35, 0.26)
    beam(d2, (px - 0.6, py - 0.7, 0.3), (px - 0.95, py - 0.3, 2.6), 0.14, WOOD_L)
    M.empty("fx_smoke_dmg", (px + 0.6, py, 4.6))
    M.punkte(door=(H.x0 + 0.9, H.y0 - 0.55), work_1=(-0.2, -2.2), work_2=(0.75, 0.25), drop=(1.3, -1.3), bubble=(0.0, 0.8, 5.6))
    M.finish()


MODELS["b_presse"] = presse


# ================================================================== Raffinerie
def ventil(M, name, loc, euler, r=0.2, color=RED):
    """Ventilrad als drehendes Objekt."""
    sp = M.origin(name, loc, euler, local=True)
    sp.torus(r, 0.035, (0, 0, 0), color, seg=10, tseg=4)
    for i in range(2):
        sp.box((r * 2, 0.045, 0.035), (0, 0, 0), color, r=rot(0, 0, i * 90))
    sp.cyl(0.05, 0.14, (0, 0, -0.05), STEEL_D, sides=6)


def tank(p, x, y, z, r, h, style, color, band):
    """Stehender Tank: Holzdauben mit Eisenbändern (holz) oder genietete Stahlringe (stahl)."""
    n = 14
    if style == "holz":
        for i in range(n):
            a0, a1 = 2 * math.pi * i / n, 2 * math.pi * (i + 1) / n
            am = (a0 + a1) / 2
            w = wand((x + math.cos(a1) * r, y + math.sin(a1) * r), (x + math.cos(a0) * r, y + math.sin(a0) * r), z)
            tile(p, w, 0.012, 0.0, w.len - 0.012, h, 0.0, 0.06, jit(color, 0.08))
        p.cyl(r - 0.05, h - 0.1, (x, y, z + h / 2), shade(color, 0.5), sides=n, r=rot(0, 0, 180.0 / n))
        for k in (0.15, 0.5, 0.85):
            p.cyl(r + 0.035, 0.09, (x, y, z + h * k), band, sides=n, r=rot(0, 0, 180.0 / n))
        p.cyl(r + 0.06, 0.1, (x, y, z + h), shade(color, 0.8), sides=n, r=rot(0, 0, 180.0 / n))
        p.cone(r + 0.1, 0.5, (x, y, z + h + 0.28), shade(color, 0.9), sides=n)
    else:
        rings = 3
        for k in range(rings):
            p.cyl(r, h / rings - 0.03, (x, y, z + (k + 0.5) * h / rings), jit(color, 0.05), sides=n)
            p.cyl(r + 0.04, 0.08, (x, y, z + (k + 1) * h / rings), band, sides=n)
            for i in range(0, n, 2):
                a = 2 * math.pi * (i + 0.5) / n
                w = wand((x + math.cos(a + 0.2) * r, y + math.sin(a + 0.2) * r), (x + math.cos(a - 0.2) * r, y + math.sin(a - 0.2) * r), z)
                stud(p, w, w.len / 2, (k + 1) * h / rings - 0.14, 0.02, 0.035, shade(color, 1.2))
        p.cyl(r + 0.04, 0.1, (x, y, z + 0.05), band, sides=n)
        p.cyl(r, 0.35, (x, y, z + h + 0.17), shade(color, 1.08), r2=r * 0.45, sides=n)
        p.cyl(r * 0.28, 0.16, (x, y, z + h + 0.42), band, sides=8)


def raffinerie():
    M = Model("b_raffinerie", 5.6, 5.6)
    B, G, L = M["body"], M["win_glow"], M["lamp_glow"]
    H = Haus(1.42, -0.95, 2.1, 1.9, 0.25, 2.8)
    hof(M, 5.5, 5.5, 0.2, color="C4C6CC", skip=[(H.x0 + 0.1, H.y0 + 0.1, H.x1 - 0.1, H.y1 - 0.1)])
    H.kern(B)
    F, Rw, Lw = H.W("f"), H.W("r"), H.W("l")
    # Pumpenhaus: Tür nach links zum Hof hin wäre unpraktisch -> Tür vorn
    hd = tuer(B, F, 0.9, 0.0, 1.4, 2.45, color="B5482F", frame=DK)
    hr = fenster(B, G, Rw, 0.95, 1.2, 0.8, 0.9, frame=DK)
    lampe(B, L, F, 1.9, 2.2)
    holes = {"f": [hd], "r": [hr]}
    sockel(B, H, holes, shade(CONC_D, 0.8))
    wandsatz(M["lvmax3_haus"], H, "bretter_h", holes, color="B77B45")
    wandsatz(M["lv4_haus"], H, "stein", holes, color="C9BFA8", color2="DDD5C6")
    R = dach(B, (H.cx, H.cy, H.top), H.d, H.w, 0.85, "5E7FB5", over=0.25, over_g=0.2, yaw=90, style="blech", ground=0.25, fallrohr=False)
    giebelfeld(B, H, 0.85, "plank_h", STEEL_L, sides="fb")
    sb = schild(B, F, 1.05, 3.1, 0.7, 0.5, GOLD, DK)                               # Schild: Tropfen
    sb.ball(0.14, (0, 0, -0.05), "22252E", subdiv=1)
    sb.cone(0.13, 0.26, (0, 0, 0.12), "22252E", sides=6)
    # --- zwei Tanks mit Leitern (hinten)
    T1, T4, T7 = M["lvmax3_tanks"], M["lv4_tanks"], M["lv7_gold"]
    tz = 0.55
    for i, (x, y) in enumerate(((-1.6, 1.55), (0.55, 1.6))):
        B.cyl(1.0, 0.3, (x, y, 0.4), CONC_D, sides=14)
        tank(T1, x, y, tz, 0.88, 2.5, "holz", "B77B45", STEEL_D)
        tank(T4, x, y, tz, 0.92, 2.9, "stahl", ("D9D4C8", "C9463E")[i], STEEL_D)
        T4.cyl(0.95, 0.5, (x, y, tz + 1.2), ("C9463E", "E6E0D2")[i], sides=14)              # Farbring
        leiter(B, (x + 0.35, y - 1.02, 0.3), (x + 0.35, y - 0.97, tz + 2.6), 0.4, STEEL_L, 0.3, 0.05)
        T7.cyl(0.97, 0.12, (x, y, tz + 2.9), GOLD, sides=14)
        T7.cyl(0.97, 0.1, (x, y, tz + 0.2), GOLD, sides=14)
        T7.ball(0.16, (x, y, tz + 3.5), GOLD, subdiv=1)
        for k in range(8):                                                                   # Geländer oben (Stufe 4+)
            a = 2 * math.pi * k / 8
            T4.cyl(0.025, 0.4, (x + math.cos(a) * 0.86, y + math.sin(a) * 0.86, tz + 3.1), STEEL_L, sides=4)
        T4.torus(0.86, 0.025, (x, y, tz + 3.3), STEEL_L, seg=14, tseg=4)
    # Steg zwischen den Tanks (Stufe 4+)
    T4.box((1.4, 0.4, 0.06), (-0.52, 1.58, tz + 2.92), STEEL_D)
    for sy in (-0.2, 0.2):
        T4.box((1.3, 0.03, 0.03), (-0.52, 1.58 + sy, tz + 3.3), STEEL_L)
    # --- Fackel-Schornstein mit Flamme (hinten rechts)
    fx_, fy_ = 2.12, 1.85
    B.cyl(0.4, 0.4, (fx_, fy_, 0.45), CONC_D, sides=8)
    B.cyl(0.17, 4.3, (fx_, fy_, 2.75), STEEL, sides=8, r2=0.13)
    for z in (1.6, 2.8, 4.0):
        B.cyl(0.2, 0.08, (fx_, fy_, z), STEEL_D, sides=8)
    for (dx, dy) in ((-0.55, -0.4), (0.4, -0.55), (0.2, 0.6)):
        beam(B, (fx_ + dx, fy_ + dy, 0.3), (fx_, fy_, 2.8), 0.04, STEEL_D)
    B.cyl(0.24, 0.3, (fx_, fy_, 4.95), DK, sides=8, r2=0.2)
    fl = M.origin("pulse_flamme_glow", (fx_, fy_, 5.15), local=True)
    fl.cone(0.22, 0.75, (0, 0, 0.36), "FF8A1E", sides=7)
    fl.cone(0.13, 0.45, (0.02, 0, 0.26), "FFE066", sides=6)
    fl.ball(0.2, (0, 0, 0.1), "FF8A1E", subdiv=1)
    M.empty("fx_smoke", (fx_, fy_, 5.9))
    # --- Rohrgewirr mit Ventilrädern
    PC = "D9912B"
    pipe(B, [(-1.6, 0.62, 0.9), (-1.6, 0.2, 0.9), (0.55, 0.2, 0.9), (0.55, 0.68, 0.9)], 0.1, PC)
    pipe(B, [(-0.5, 0.2, 0.9), (-0.5, -0.9, 0.9), (0.45, -0.9, 0.9)], 0.1, PC)
    pipe(B, [(-1.6, 0.66, 2.2), (-1.6, 0.35, 2.2), (-1.6, 0.35, 1.5), (-2.4, 0.35, 1.5), (-2.4, -1.3, 1.5), (-2.4, -1.3, 0.3)], 0.08, STEEL_L)
    pipe(B, [(0.55, 0.7, 2.4), (0.55, 0.45, 2.4), (1.6, 0.45, 2.4), (2.2, 0.45, 2.4), (2.2, 1.7, 2.4)], 0.08, STEEL_L)
    pipe(B, [(1.6, 0.45, 2.4), (1.6, 0.05, 2.4), (1.6, 0.0, 2.0)], 0.08, STEEL_L)
    pipe(B, [(-0.5, -0.9, 0.9), (-0.5, -0.9, 1.6), (0.45, -0.9, 1.6)], 0.07, "5E7FB5")
    for (x, y, z) in ((-1.05, 0.2, 0.9), (-0.5, -0.35, 0.9), (1.1, 0.45, 2.4), (-2.4, -0.5, 1.5)):
        B.cyl(0.14, 0.12, (x, y, z), STEEL_D, r=rot(0, 90, 0) if abs(y - 0.2) < 0.01 or abs(y - 0.45) < 0.01 else rot(90, 0, 0), sides=8)
    ventil(M, "spin_ventil", (-1.05, 0.2, 1.22), (0, 0, 0))
    B.cyl(0.03, 0.3, (-1.05, 0.2, 1.06), STEEL_D, sides=4)
    ventil(M, "spin_ventil2", (-0.5, -0.35, 1.22), (0, 0, 0), color="5E7FB5")
    B.cyl(0.03, 0.3, (-0.5, -0.35, 1.06), STEEL_D, sides=4)
    for sp_ in ((-1.6, 0.2), (0.55, 0.2), (-0.5, -0.9)):
        B.box((0.16, 0.16, 0.6), (sp_[0], sp_[1], 0.52), STEEL_D)
    # Pumpe mit Druckanzeige (leuchtet)
    B.box((0.7, 0.6, 0.6), (-0.5, -0.9, 0.55), "3C8A6A", bevel=0.06, segs=1)
    B.cyl(0.25, 0.5, (-0.5, -0.9, 1.0), "3C8A6A", r=rot(0, 90, 0), sides=8)
    B.cyl(0.3, 0.12, (-1.25, -0.9, 1.75), DK, r=rot(90, 0, 0), sides=10)
    B.cyl(0.035, 0.6, (-1.25, -0.9, 1.35), STEEL_D, sides=4)
    B.box((0.5, 0.1, 0.1), (-0.95, -0.9, 1.1), STEEL_D)
    gz = M["gauge_glow"]
    gz.cyl(0.24, 0.05, (-1.25, -0.98, 1.75), "FFF1B8", r=rot(90, 0, 0), sides=10)
    B.box((0.035, 0.03, 0.2), (-1.2, -1.02, 1.8), HOT, r=rot(0, 35, 0))
    M.empty("fx_steam", (-0.5, -0.9, 1.75))
    # --- Fässer
    for (x, y, c) in ((-2.3, -2.05, RED), (-1.6, -2.1, "5E7FB5"), (-1.95, -1.5, RED), (-0.85, -2.0, "E0A21E")):
        barrel(B, (x, y, 0.25), c)
    fass_liegend(B, (0.0, -2.05, 0.25), RED, yaw=20)
    X4 = M["lv4_ausbau"]
    barrel(X4, (-1.95, -1.82, 1.15), "E0A21E"); barrel(X4, (-2.35, -0.6, 0.25), "5E7FB5")
    X4.cyl(0.45, 1.5, (2.2, 0.55, 1.0), "D9D4C8", r=rot(90, 0, 0) @ rot(0, 0, 0), sides=10)        # liegender Kessel
    for dy in (-0.5, 0.5):
        X4.box((0.7, 0.12, 0.5), (2.2, 0.55 + dy, 0.5), STEEL_D)
    X4.cyl(0.47, 0.12, (2.2, 0.55, 1.0), "C9463E", r=rot(90, 0, 0), sides=10)
    # Stufe 7: Destillierturm hinten Mitte, Gold
    T7.cyl(0.36, 4.4, (-0.52, 2.2, 2.5), "8FA0B8", sides=10)
    for z in (1.3, 2.3, 3.3, 4.3):
        T7.cyl(0.42, 0.1, (-0.52, 2.2, z), GOLD, sides=10)
    T7.cyl(0.36, 0.3, (-0.52, 2.2, 4.85), GOLD, r2=0.1, sides=10)
    pipe(T7, [(-0.52, 2.2, 4.9), (-0.52, 2.2, 5.15), (0.55, 1.6, 5.15), (0.55, 1.6, 4.0)], 0.07, GOLD)
    T7.cyl(0.2, 0.1, (fx_, fy_, 4.75), GOLD, sides=8)
    tile(T7, F, 0.0, 2.6, F.len, 2.76, 0.16, 0.06, GOLD)
    # --- Gebrauchsspuren
    fleck(B, -1.2, -1.75, 0.25, 0.55, "2B2A30"); fleck(B, 0.3, -1.6, 0.25, 0.35, "3A3A40")
    moos(B, H.W("b"), 1.0, 3, 0.8)
    flicken(B, R.planes[1], 0.8, 0.5, 0.5, 0.45, RUST)
    # --- Schaden
    d1, d2 = M["dmg1_spuren"], M["dmg2_bruch"]
    riss(d1, F, 1.95, 0.4, 1.2); riss(d1, Rw, 0.25, 0.5, 1.2); russ(d1, Rw, 1.5, 1.9, 0.4); russ(d1, F, 0.25, 2.3, 0.3)
    for (x, y) in ((-1.6, 1.55), (0.55, 1.6)):
        w = wand((x - 0.6, y - 0.98), (x + 0.6, y - 0.98), tz)
        russ(d1, w, 0.5, 1.2, 0.4, out=0.03)
    loch(d2, Rw, 1.5, 1.0, 0.33, splitter=STEEL_D)
    stuetze(d2, (H.x1 - 0.05, H.y0 - 0.45, 0.25), (H.x1 - 0.3, H.y0 - 0.12, 2.1))
    fleck(d2, 1.0, 0.5, 0.25, 0.8, "1E1D22")
    fass_liegend(d2, (1.0, 0.75, 0.25), RED_D, yaw=70)
    beam(d2, (-0.3, 0.6, 0.3), (0.2, 1.0, 2.6), 0.14, WOOD_L)
    M.empty("fx_smoke_dmg", (0.55, 1.6, 4.3))
    M.punkte(door=(H.x0 + 0.9, H.y0 - 0.5), work_1=(-1.05, -0.35), work_2=(-0.5, -1.6), drop=(0.4, -1.9), bubble=(0.0, 0.8, 5.9))
    M.finish()


MODELS["b_raffinerie"] = raffinerie


# ================================================================== Generator (2x2)
def generator():
    M = Model("b_generator", 3.6, 3.6)
    B, G, L = M["body"], M["win_glow"], M["lamp_glow"]
    H = Haus(-0.35, 0.6, 2.3, 1.7, 0.25, 2.8)
    hof(M, 3.5, 3.5, -0.75, color="C4C6CC", skip=[(H.x0 + 0.1, H.y0 + 0.1, H.x1 - 0.1, H.y1 - 0.1)])
    H.kern(B)
    F, Rw = H.W("f"), H.W("r")
    hd = tuer(B, F, 0.85, 0.0, 1.3, 2.4, color="5E7FB5", frame=DK, luke=True)
    hr = fenster(B, G, Rw, 0.85, 1.25, 0.7, 0.85, frame=DK)
    lampe(B, L, F, 1.85, 2.25)
    holes = {"f": [hd], "r": [hr]}
    sockel(B, H, holes, shade(CONC_D, 0.8))
    for s in "fr":                                                               # Warnstreifen am Sockel
        warnstreifen(B, H.W(s), 0.0 if s == "r" else 1.6, H.W(s).len, 0.42, 0.62, 0.15)
    wandsatz(M["lvmax3_haus"], H, "bretter", holes, v0=0.62)
    wandsatz(M["lv4_haus"], H, "ziegel", holes, v0=0.62)
    W7 = M["lv7_haus"]
    for s in "frbl":
        clad(W7, H.W(s), "panel", "A9BEDD", v0=0.62, holes=holes.get(s, ()), out=0.15, size=1.15)
    ecken(W7, H, STEEL_D, 0.34, 0.19)
    for s in "frbl":
        pl = H.W(s)
        tile(W7, pl, 0.0, H.h - 0.2, pl.len, H.h - 0.04, 0.16, 0.08, GOLD)
    R = dach(B, (H.cx, H.cy, H.top), H.w, H.d, 0.8, RED, over=0.22, over_g=0.2, ground=0.25, fallrohr=False, tw=0.46, row=0.42)
    giebelfeld(B, H, 0.8, "plank_h", WOOD_L)
    flicken(B, R.planes[0], 0.7, 0.55, 0.5, 0.42, WOOD_P)
    W7.cyl(0.15, H.w + 0.5, (H.cx, H.cy, H.top + 0.92), GOLD, r=rot(0, 90, 0), sides=6)
    # Blitz-Schild über der Tür
    sb = schild(B, F, 1.9, 1.95, 0.5, 0.36, DK, GOLD)
    slab(sb, wand((-0.2, 0), (0.2, 0), -0.16), [(0.24, 0.3), (0.1, 0.16), (0.2, 0.16), (0.14, 0.02), (0.3, 0.2), (0.2, 0.2)], 0.02, 0.0, GOLD)
    # Auspuff
    px, py, pz = dach_pos(R, 0.6, 0.4)
    B.cyl(0.12, 1.0, (px, py, pz + 0.3), STEEL_D, sides=8)
    B.cyl(0.17, 0.12, (px, py, pz + 0.8), DK, sides=8)
    M.empty("fx_smoke", (px, py, pz + 1.0))
    # --- Maschinensatz vorn rechts: Schwungrad, Dynamo, Spulen
    gx, gy = 1.05, -0.95
    B.box((1.2, 1.3, 0.22), (gx, gy, 0.36), DK, bevel=0.03, segs=1)
    B.cyl(0.42, 0.9, (gx, gy + 0.1, 0.92), "3C8A6A", r=rot(90, 0, 0), sides=10)
    for dy in (-0.3, 0.1, 0.5):
        B.cyl(0.46, 0.08, (gx, gy + dy, 0.92), STEEL_D, r=rot(90, 0, 0), sides=10)
    B.box((0.5, 0.5, 0.3), (gx, gy + 0.1, 1.42), "3C8A6A")
    sp = M.origin("spin_rad", (gx, gy - 0.52, 0.95), (math.radians(90), 0, 0), local=True)
    sp.torus(0.5, 0.08, (0, 0, 0), RED, seg=14, tseg=6)
    for i in range(3):
        sp.box((0.96, 0.1, 0.07), (0, 0, 0), STEEL_L, r=rot(0, 0, i * 60))
    sp.cyl(0.14, 0.2, (0, 0, 0), DK, sides=8)
    for (i, dx) in enumerate((-0.28, 0.28)):                                           # Spulen mit Blitzen
        cx_, cy_ = gx + dx, gy + 0.1
        B.cyl(0.1, 0.9, (cx_, cy_, 1.95), STEEL_D, sides=6)
        for k in range(5):
            B.torus(0.15, 0.05, (cx_, cy_, 1.68 + k * 0.13), "D9912B", seg=8, tseg=4)
        pc = M.origin("pulse_spule%s_glow" % ("" if i == 0 else "2"), (cx_, cy_, 2.55), local=True)
        pc.ball(0.2, (0, 0, 0), CYAN, subdiv=1)
    M.empty("fx_spark", (gx, gy + 0.1, 2.6))
    # --- Mast mit Isolatoren und Kabel
    mx, my = 1.2, 1.35
    B.box((0.4, 0.4, 0.2), (mx, my, 0.35), CONC_D)
    B.cyl(0.09, 4.6, (mx, my, 2.6), WOOD_D, sides=6, r2=0.07)
    for z in (4.3, 3.8):
        B.box((1.0, 0.1, 0.1), (mx, my, z), WOOD_D)
        for dx in (-0.4, 0.4):
            B.cyl(0.06, 0.16, (mx + dx, my, z + 0.12), "E6E0D2", sides=6)
    beam(B, (mx - 0.4, my, 3.8), (mx, my, 3.3), 0.05, WOOD_D)
    beam(B, (mx + 0.4, my, 3.8), (mx, my, 3.3), 0.05, WOOD_D)
    kabel(B, (gx - 0.28, gy + 0.1, 2.5), (mx - 0.45, my, 4.45), 0.35, 0.025)
    kabel(B, (gx + 0.28, gy + 0.1, 2.5), (mx + 0.45, my, 4.45), 0.3, 0.025)
    kabel(B, (mx - 0.45, my, 3.95), (H.x1 - 0.1, H.cy, H.top + 0.5), 0.2, 0.025)
    # --- Schalttafel mit Lämpchen (an der Hauswand rechts neben der Tür)
    a = At(B, F.M(1.95, 0.75, 0))
    a.box((0.62, 0.2, 0.95), (0, -0.1, 0.5), "5E7FB5", bevel=0.03, segs=1)
    a.box((0.5, 0.04, 0.3), (0, -0.21, 0.72), DK)
    a.box((0.07, 0.1, 0.24), (0.15, -0.24, 0.3), RED, r=rot(25, 0, 0))
    ag = At(M["panel_glow"], F.M(1.95, 0.75, 0))
    for (i, c) in enumerate(("5FE38A", GLOW, HOT)):
        ag.box((0.1, 0.04, 0.1), (-0.15 + i * 0.15, -0.24, 0.72), c)
    # --- Ausbau
    X4 = M["lv4_ausbau"]
    barrel(X4, (-1.35, -1.25, 0.25), "5E7FB5", 0.3, 0.8)
    X4.box((0.5, 0.36, 0.55), (H.x0 + 0.5, H.y0 - 0.3, 0.55), STEEL_D)                # Batteriekasten
    M["lv4_bat_glow"].box((0.3, 0.03, 0.12), (H.x0 + 0.5, H.y0 - 0.49, 0.65), CYAN)
    B.box((0.3, 0.4, 0.3), (-1.4, -0.75, 0.4), RED, bevel=0.04, segs=1)               # Kanister
    B.box((0.1, 0.1, 0.1), (-1.4, -0.85, 0.6), DK)
    X7 = M["lv7_gold"]
    for dy in (-0.3, 0.5):
        X7.cyl(0.48, 0.1, (gx, gy + dy, 0.92), GOLD, r=rot(90, 0, 0), sides=10)
    X7.ball(0.14, (mx, my, 5.0), GOLD, subdiv=1)
    X7.cyl(0.3, 0.1, (gx, gy + 0.1, 1.62), GOLD, sides=8)
    # --- Gebrauchsspuren
    fleck(B, gx - 0.5, gy - 0.5, 0.25, 0.35, "2B2A30")
    moos(B, H.W("l"), 0.8, 3, 0.8)
    brett_quer(M["lvmax3_haus"], Rw, 1.35, 0.95, 0.5, 0.18, 9)
    # --- Schaden
    d1, d2 = M["dmg1_spuren"], M["dmg2_bruch"]
    riss(d1, Rw, 0.25, 0.6, 1.2); riss(d1, F, 1.75, 1.7, 0.8); russ(d1, Rw, 1.35, 2.0, 0.36); russ(d1, F, 0.2, 2.2, 0.3)
    loch(d2, Rw, 1.4, 1.45, 0.3)
    stuetze(d2, (H.x1 + 0.5, H.cy + 0.3, 0.25), (H.x1 + 0.12, H.cy + 0.3, 2.2), 0.13)
    kabel(d2, (mx + 0.45, my, 3.95), (mx + 0.3, my - 0.5, 0.4), 0.0, 0.025, n=2)
    d2.box((0.6, 0.14, 0.05), (0.2, -1.3, 0.3), WOOD, r=rot(0, 5, 50))
    M.empty("fx_smoke_dmg", (gx, gy, 1.9))
    M.punkte(door=(H.x0 + 0.85, H.y0 - 0.5), work_1=(0.25, -1.2), work_2=(H.x0 + 1.95, H.y0 - 0.5), drop=(-1.0, -1.3), bubble=(0.0, 0.3, 5.0))
    M.finish()


MODELS["b_generator"] = generator


# ================================================================== Lager
def sackkarre(p, loc, yaw=0.0):
    a = At(p, T(*loc) @ rot(0, 0, yaw))
    for sx in (-0.2, 0.2):
        beam(a, (sx, 0.05, 0.12), (sx, 0.45, 1.25), 0.045, RED)
        a.cyl(0.14, 0.07, (sx * 1.3, 0.1, 0.14), "22252E", r=rot(0, 90, 0), sides=8)
    for t in (0.3, 0.6, 0.9):
        a.box((0.44, 0.04, 0.04), (0, 0.05 + 0.4 * t, 0.12 + 1.13 * t), RED_D)
    a.box((0.46, 0.34, 0.04), (0, -0.1, 0.05), STEEL)
    crate(a, (0, -0.08, 0.07), 0.42, WOOD_L)


def regal(p, m, w=1.6, h=2.2, d=0.45):
    """Regal mit Kisten und Säcken (lokal: x Breite, -y vorn)."""
    a = At(p, m)
    for sx in (-1, 1):
        a.box((0.08, d, h), (sx * w / 2, 0, h / 2), WOOD_D)
    cols = (WOOD_L, "5E7FB5", "C9463E", OLIVE, GOLD)
    for i, z in enumerate((0.1, 0.85, 1.55, h)):
        a.box((w, d, 0.06), (0, 0, z), WOOD)
        if z < h:
            for k in range(3):
                s = RNG.uniform(0.34, 0.44)
                a.box((s, d * 0.8, s), (-w / 2 + 0.3 + k * (w - 0.6) / 2, 0, z + 0.03 + s / 2), jit(cols[(i * 3 + k) % 5], 0.08))


def lager():
    M = Model("b_lager", 5.6, 5.6)
    B, G, L = M["body"], M["win_glow"], M["lamp_glow"]
    H = Haus(0.0, 0.95, 4.5, 2.9, 0.25, 3.2)
    hof(M, 5.5, 5.5, 0.0, skip=[(H.x0 + 0.1, H.y0 + 0.1, H.x1 - 0.1, H.y1 - 0.1)])
    F, Rw, Lw, Bk = H.W("f"), H.W("r"), H.W("l"), H.W("b")
    gw, gh, gd = 2.4, 2.7, 1.5                                                    # Toröffnung und Tiefe des sichtbaren Innenraums
    zc = H.z0 + H.h / 2
    side = (H.w - gw) / 2
    for sx in (-1, 1):
        B.box((side, H.d, H.h), (sx * (gw / 2 + side / 2), H.cy, zc), JOINT)
    B.box((gw, H.d - gd, H.h), (0, H.y0 + gd + (H.d - gd) / 2, zc), "2A2622")
    B.box((gw, gd, H.h - gh), (0, H.y0 + gd / 2, H.z0 + gh + (H.h - gh) / 2), JOINT)
    B.box((gw, gd, 0.06), (0, H.y0 + gd / 2, H.z0 + 0.03), "8A7A66")              # Hallenboden
    for sx in (-1, 1):                                                            # Innenwände hell genug, damit man hineinsieht
        tile(B, wand((sx * gw / 2, H.y0 + (0 if sx < 0 else gd)), (sx * gw / 2, H.y0 + (gd if sx < 0 else 0)), H.z0, gh), 0, 0, gd, gh, 0.01, 0.0, "6B5A48")
    tile(B, wand((-gw / 2, H.y0 + gd), (gw / 2, H.y0 + gd), H.z0, gh), 0, 0, gw, gh, 0.01, 0.0, "5C4D3E")
    regal(B, T(0.45, H.y0 + gd - 0.3, H.z0 + 0.06), 1.3, 2.1)
    crate(B, (-0.7, H.y0 + 0.95, H.z0 + 0.06), 0.7, WOOD); crate(B, (-0.72, H.y0 + 0.95, H.z0 + 0.78), 0.55, "5E7FB5", 12)
    sack(B, (-0.6, H.y0 + 0.4, H.z0 + 0.06)); barrel(B, (0.85, H.y0 + 0.45, H.z0 + 0.06), OLIVE, 0.28, 0.75)
    # Torrahmen und offene Flügel
    u0 = H.w / 2 - gw / 2
    for u in (u0 - 0.09, u0 + gw + 0.09):
        tile(B, F, u - 0.11, 0, u + 0.11, gh + 0.2, 0.2, 0.2, CREAM)
    tile(B, F, u0 - 0.2, gh, u0 + gw + 0.2, gh + 0.22, 0.22, 0.22, CREAM)
    for sx in (-1, 1):
        a = At(B, T(sx * (gw / 2 + 0.12), H.y0 - 0.14, H.z0) @ rot(0, 0, sx * -78))
        dw = gw / 2 - 0.06
        for i in range(4):
            a.box((dw / 4 - 0.02, 0.07, gh - 0.1), (sx * (i + 0.5) * dw / 4, 0, gh / 2), jit(RED_D, 0.07))
        for z in (0.35, gh - 0.4):
            a.box((dw, 0.05, 0.16), (sx * dw / 2, -0.06 * sx * -1 * 0 - 0.055, z), CREAM)
        beam(a, (sx * 0.08, -0.055, 0.45), (sx * (dw - 0.08), -0.055, gh - 0.5), 0.12, CREAM, d=0.05)
    hole_g = (u0 - 0.2, 0.0, u0 + gw + 0.2, gh + 0.22)
    hr = fenster(B, G, Rw, 1.55, 1.3, 0.9, 1.0)
    holes = {"f": [hole_g], "r": [hr]}
    sockel(B, H, holes)
    W1 = M["lvmax3_haus"]
    wandsatz(W1, H, "bretter", holes, color="B8473A")
    for s in "rl":                                                                # weiße Scheunen-Kreuze
        pl = H.W(s)
        for (a0, a1) in ((0.3, 0.9), (2.2, 2.8)) if s == "l" else ((2.2, 2.8),):
            fachwerk(W1, pl, a0, a1 + 0.0, 0.6, 2.4, CREAM, out=0.1, w=0.1, diag=((a0 + 0.1, 0.7, a1 - 0.1, 2.3), (a1 - 0.1, 0.7, a0 + 0.1, 2.3)))
    wandsatz(M["lv4_haus"], H, "fachwerk", holes)
    # --- Dach Stufe 1-6 (Giebel nach vorn)
    D1 = M["lvmax6_dach"]
    rh = 1.7
    R1 = dach(D1, (H.cx, H.cy, H.top), H.d, H.w, rh, BLUE, over=0.26, over_g=0.26, yaw=90, ground=0.25, fallrohr=False)
    hgf = fenster(D1, M["lvmax6_win_glow"], F, H.w / 2, H.h + 0.45, 0.6, 0.6)
    giebelfeld(D1, H, rh, "plank_h", "B8473A", sides="f", fenster_=[hgf])
    giebelfeld(D1, H, rh, "plank_h", "B8473A", sides="b")
    flicken(D1, R1.planes[1], 1.0, 1.3, 0.7, 0.6, WOOD_P)
    px, py, pz = dach_pos(R1, 0.6, 0.0)
    D1.box((0.5, 0.5, 0.45), (px, py, pz + 0.1), CREAM)
    D1.cyl(0.42, 0.3, (px, py, pz + 0.47), BLUE_D, r=rot(0, 0, 45), r2=0.05, sides=4)
    # --- Stufe 7: Speicherboden, größeres Dach, Gold
    H2 = Haus(H.cx, H.cy, H.w + 0.16, H.d + 0.16, H.top, 1.3)
    U = M["lv7_stock"]
    H2.kern(U)
    U.box((H.w + 0.4, H.d + 0.4, 0.18), (H.cx, H.cy, H.top + 0.02), WOOD_D)
    hl = tuer(U, H2.W("f"), H2.w / 2, 0.12, 0.9, 1.0, color=RED_D, frame=CREAM, fw=0.1)        # Ladeluke
    hw2 = [fenster(U, M["lv7_win_glow"], H2.W("r"), u, 0.35, 0.6, 0.65) for u in (0.9, 2.3)]
    wandsatz(U, H2, "fachwerk", {"f": [hl], "r": hw2}, v0=0.1, eck=False)
    R2 = dach(U, (H.cx, H.cy, H2.top), H2.d, H2.w, rh, BLUE, over=0.22, over_g=0.2, yaw=90, ridge=GOLD, trim=GOLD, ground=0.25, fallrohr=False)
    giebelfeld(U, H2, rh, "plank_h", "B8473A", sides="fb")
    star(U, (0, H2.y0 - 0.1, H2.top + 0.7), 0.42, GOLD, 0.08)
    px, py, pz = dach_pos(R2, 0.6, 0.0)
    U.box((0.5, 0.5, 0.45), (px, py, pz + 0.1), CREAM)
    U.cyl(0.42, 0.3, (px, py, pz + 0.47), GOLD, r=rot(0, 0, 45), r2=0.05, sides=4)
    for (x, y) in ((H.x0, H.y0), (H.x1, H.y0), (H.x1, H.y1)):
        U.box((0.36, 0.36, 0.14), (x, y, H.z0 + 0.55), GOLD)
        U.box((0.36, 0.36, 0.14), (x, y, H.z0 + 2.9), GOLD)
    # --- Kran am Giebel mit Last am Haken
    tip = (0.0, H.y0 - 1.0, H.z0 + 3.05)
    B.box((0.2, 1.5, 0.22), (0.0, H.y0 - 0.45, H.z0 + 3.05), WOOD_D)
    beam(B, (0.0, H.y0 - 0.02, H.z0 + 2.95 - 0.0), (0.0, H.y0 - 0.75, H.z0 + 3.0), 0.08, WOOD_D)
    B.cyl(0.14, 0.1, (0.0, tip[1], tip[2] - 0.16), STEEL_D, r=rot(0, 90, 0), sides=8)
    hk = M.origin("sway_haken", (tip[0], tip[1], tip[2] - 0.2), local=True)
    hk.cyl(0.02, 0.8, (0, 0, -0.4), "C9B38A", sides=4)
    hk.box((0.1, 0.06, 0.16), (0, 0, -0.85), STEEL_D)
    for (sx, sy) in ((-1, -1), (1, -1), (-1, 1), (1, 1)):
        beam(hk, (0, 0, -0.9), (sx * 0.25, sy * 0.25, -1.2), 0.025, "C9B38A")
    crate(hk, (0, 0, -1.72), 0.55, WOOD_L)
    # --- hängendes Schild, Lampe, Ofenrohr
    a = At(B, F.M(H.w - 0.5, 2.5, 0))
    a.box((0.06, 0.8, 0.06), (0, -0.4, 0.45), DK)
    beam(a, (0, -0.03, 0.1), (0, -0.55, 0.42), 0.04, DK)
    sg = M.origin("sway_schild", (H.x1 - 0.5, H.y0 - 0.55, H.z0 + 2.9), local=True)
    sg.box((0.04, 0.6, 0.5), (0, 0, -0.33), WOOD_L)
    sg.box((0.05, 0.66, 0.06), (0, 0, -0.06), WOOD_D)
    sg.box((0.06, 0.3, 0.26), (0, 0, -0.36), WOOD_D)
    sg.box((0.07, 0.34, 0.05), (0, 0, -0.36), GOLD)
    lampe(B, L, F, 0.55, 2.5)
    pipe(B, [(H.x0 - 0.02, 1.6, 2.3), (H.x0 - 0.36, 1.6, 2.3), (H.x0 - 0.36, 1.6, 3.4)], 0.09, STEEL_D, 6)
    B.cyl(0.14, 0.1, (H.x0 - 0.36, 1.6, 3.42), DK, sides=6)
    M.empty("fx_smoke", (H.x0 - 0.36, 1.6, 3.6))
    # --- Füllstand: Kistenstapel draußen (vier Stufen)
    f1, f2, f3, f4 = M["fill1_kisten"], M["fill2_kisten"], M["fill3_kisten"], M["fill4_kisten"]
    crate(f1, (-2.1, -1.2, 0.25), 0.8, WOOD); crate(f1, (-1.5, -2.0, 0.25), 0.62, WOOD_L, 14); sack(f1, (-2.25, -2.05, 0.25))
    crate(f2, (2.1, -1.3, 0.25), 0.8, WOOD_L, 4); barrel(f2, (1.55, -2.05, 0.25), "5E7FB5"); barrel(f2, (2.25, -2.1, 0.25), RED)
    sack(f2, (1.45, -1.35, 0.25), lie=True, yaw=30)
    crate(f3, (-2.12, -1.22, 1.07), 0.66, "5E7FB5", 8); crate(f3, (-2.2, -0.35, 0.25), 0.7, WOOD_L, -5); crate(f3, (-1.42, -1.2, 0.25), 0.55, OLIVE, 20)
    sack(f3, (-1.55, -1.95, 0.9), lie=True, yaw=80, s=0.9)
    crate(f4, (2.12, -1.32, 1.07), 0.7, WOOD, -9); crate(f4, (2.15, -1.3, 1.78), 0.5, "C9463E", 16); crate(f4, (2.2, -0.4, 0.25), 0.75, WOOD)
    barrel(f4, (1.9, -2.05, 1.17), OLIVE, 0.3, 0.8); sack(f4, (1.3, -0.75, 0.25)); sack(f4, (-2.2, -0.35, 0.96), lie=True)
    sackkarre(B, (-1.25, -0.55, 0.25), 200)
    X4 = M["lv4_ausbau"]                                                          # Stufe 4: Vordach über dem Tor, Laterne
    pultdach(X4, (0.0, H.y0 - 0.42, H.z0 + 3.28), 3.2, 0.7, -0.3, BLUE_D, over=0.08, style="blech", rinne=False, yaw=180)
    laterne(X4, M["lv4_lamp_glow"], 1.05, -2.2, 0.25, 2.1)
    # --- Gebrauchsspuren
    moos(B, Rw, 2.4, 4, 1.2); moos(B, Lw, 0.6, 3, 0.9)
    brett_quer(W1, Rw, 0.6, 1.0, 0.8, 0.2, -12)
    fleck(B, 0.3, -0.9, 0.25, 0.5, "A99C8C")
    # --- Schaden
    d1, d2 = M["dmg1_spuren"], M["dmg2_bruch"]
    riss(d1, F, 0.3, 0.5, 1.3); riss(d1, Rw, 0.4, 0.5, 1.4); riss(d1, F, 4.0, 0.6, 1.2); russ(d1, Rw, 2.5, 2.1, 0.5); russ(d1, F, 0.5, 2.9, 0.35)
    brett_quer(d1, F, 4.0, 1.8, 0.9, 0.2, 16, out=0.2)
    loch(d2, Rw, 2.55, 1.2, 0.42); loch(d2, F, 0.45, 1.5, 0.3)
    stuetze(d2, (H.x1 - 0.2, H.y0 - 0.85, 0.25), (H.x1 - 0.45, H.y0 - 0.14, 2.4))
    for i in range(4):
        d2.box((0.7, 0.16, 0.06), (-0.9 + i * 0.2, -1.5 - i * 0.15, 0.3), jit("B8473A"), r=rot(0, 6, 20 + i * 41))
    M.empty("fx_smoke_dmg", (H.x1 - 0.8, H.cy, H.top + 0.9))
    M.punkte(door=(0.0, H.y0 - 0.6), work_1=(-1.3, -1.2), work_2=(1.3, -1.6), drop=(0.0, H.y0 + 0.4, 0.31), bubble=(0.0, 0.8, 7.2))
    M.finish()


MODELS["b_lager"] = lager
