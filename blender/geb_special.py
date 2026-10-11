"""Rustwall – besondere Gebäude nach dem Detail-Katalog (Auftrag V3, Kapitel 6).
Quartier, Kistenlager, Werkstatt, Garage, Funkturm, Clanhalle, Labor, Schildgenerator, Trainingsplatz. Vorderseite = -Y.
Besondere Gebäude gehen bis Stufe 5: zwei Ausbau-Aussehen (lvmax3_* / lv4_*). Der Schildgenerator hat drei."""
import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from geb_kit import *
from geb_prod import hof

MODELS = {}


def schaden_std(M, H, sides="fr", holz=True):
    """Übliche Schadens-Teile an den sichtbaren Wänden: Risse, Ruß (dmg1), Loch und Stützbalken (dmg2)."""
    d1, d2 = M["dmg1_spuren"], M["dmg2_bruch"]
    F, Rw = H.W("f"), H.W("r")
    riss(d1, F, F.len - 0.5, 0.5, min(1.3, H.h * 0.4)); riss(d1, Rw, 0.35, 0.5, min(1.4, H.h * 0.45))
    russ(d1, Rw, Rw.len - 0.6, H.h * 0.65, 0.42); russ(d1, F, 0.3, H.h * 0.75, 0.32)
    loch(d2, Rw, Rw.len - 0.6, H.h * 0.35, 0.36, splitter=WOOD_D if holz else STEEL_D)
    stuetze(d2, (H.x1 - 0.2, max(H.y0 - 0.7, -M.fy / 2 + 0.4), H.z0), (H.x1 - 0.4, H.y0 - 0.13, H.z0 + min(2.2, H.h * 0.7)))
    return d1, d2


# ================================================================== Quartier (3x2)
def fahrrad(p, loc, yaw=0.0, color=RED):
    a = At(p, T(*loc) @ rot(0, 0, yaw) @ rot(0, 12, 0))
    for sx in (-0.5, 0.5):
        a.torus(0.3, 0.035, (sx, 0, 0.33), "22252E", r=rot(90, 0, 0), seg=10, tseg=4)
        a.cyl(0.04, 0.08, (sx, 0, 0.33), STEEL, r=rot(90, 0, 0), sides=5)
    beam(a, (-0.5, 0, 0.33), (-0.1, 0, 0.75), 0.04, color); beam(a, (-0.1, 0, 0.75), (0.38, 0, 0.8), 0.04, color)
    beam(a, (-0.1, 0, 0.75), (0.0, 0, 0.35), 0.04, color); beam(a, (0.0, 0, 0.35), (0.38, 0, 0.8), 0.04, color)
    beam(a, (0.5, 0, 0.33), (0.36, 0, 0.95), 0.04, STEEL)
    a.box((0.06, 0.4, 0.04), (0.36, 0, 0.96), DK)
    a.box((0.22, 0.1, 0.05), (-0.14, 0, 0.85), "5A3A22")


def quartier():
    M = Model("b_quartier", 5.6, 3.6, looks=2)
    B, G, L = M["body"], M["win_glow"], M["lamp_glow"]
    H = Haus(-0.2, 0.62, 4.4, 1.75, 0.25, 3.0)
    fundament(B, 5.5, 3.22, 0.25, (0, 0.14), skip=[(H.x0 + 0.1, H.y0 + 0.1, H.x1 - 0.1, H.y1 - 0.1), (-2.4, -1.3, 0.75, H.y0)])
    stufe(B, -1.25, -1.6, 1.9, 0.34, 0.13)
    H.kern(B)
    F, Rw = H.W("f"), H.W("r")
    hd = tuer(B, F, 1.15, 0.12, 1.4, 2.6, color="3F7D4E", frame=CREAM)
    h1 = fenster(B, G, F, 2.55, 1.3, 0.7, 1.0, laden="3F7D4E")
    h2 = fenster(B, G, F, 3.75, 1.3, 0.8, 1.0, laden="3F7D4E", kasten=True)
    h3 = fenster(B, G, Rw, 0.88, 1.3, 0.8, 1.0, kasten=True)
    holes = {"f": [hd, h1, h2], "r": [h3]}
    sockel(B, H, holes)
    wandsatz(M["lvmax3_haus"], H, "bretter_h", holes, color="C98A4B")
    wandsatz(M["lv4_haus"], H, "fachwerk", holes)
    R = dach(B, (H.cx, H.cy, H.top), H.w, H.d, 1.15, RED, over=0.2, over_g=0.26, ground=0.25)
    giebelfeld(B, H, 1.15, "plank_h", WOOD_L)
    flicken(B, R.planes[0], 3.9, 0.75, 0.6, 0.5, WOOD_P)
    px, py, pz = dach_pos(R, 1.3, 0.25)
    schornstein(M, B, (px, py, pz - 0.45), 1.25, 0.46)
    # Wetterhahn (dreht)
    wx, wy, wz = dach_pos(R, -1.5, 0.0)
    B.cyl(0.03, 0.7, (wx, wy, wz + 0.4), DK, sides=4)
    sp = M.origin("spin_wetterhahn", (wx, wy, wz + 0.78), local=True)
    sp.box((0.7, 0.03, 0.04), (0, 0, 0), DK)
    sp.cone(0.09, 0.2, (0.38, 0, 0), GOLD, r=rot(0, 90, 0), sides=4)
    sp.box((0.24, 0.03, 0.22), (-0.3, 0, 0.06), GOLD)
    sp.ball(0.06, (0, 0, 0.06), GOLD, subdiv=1)
    # --- Veranda (links): Bretterboden, Pfosten, Vordach, Bank
    vx0, vx1, vy0 = -2.4, 0.75, -1.3
    pl = boden(vx0, vy0, 0.25)
    n = 9
    for i in range(n):
        w = (vx1 - vx0) / n
        tile(B, pl, i * w + 0.015, 0.0, (i + 1) * w - 0.015, H.y0 - vy0, 0.1, 0.1, jit(WOOD_P, 0.07))
    for x in (vx0 + 0.1, -0.35, vx1 - 0.1):
        B.box((0.14, 0.14, 2.25), (x, vy0 + 0.1, 0.35 + 1.12), CREAM)
        B.box((0.22, 0.22, 0.1), (x, vy0 + 0.1, 0.4), WOOD_D)
    B.box((vx1 - vx0, 0.12, 0.14), ((vx0 + vx1) / 2, vy0 + 0.1, 2.5), CREAM)
    for x in (vx0 + 0.1, vx1 - 0.1):                                                # Geländer
        pass
    zaun(B, (vx0 + 0.1, vy0 + 0.1), (-2.2 + 0.0, vy0 + 0.1), 0.35, 0.8, CREAM, 1)
    zaun(B, (-0.35, vy0 + 0.1), (vx1 - 0.1, vy0 + 0.1), 0.35, 0.8, CREAM, 2)
    pultdach(B, ((vx0 + vx1) / 2, (vy0 + H.y0) / 2 - 0.02, 2.55), vx1 - vx0, H.y0 - vy0 + 0.06, 0.42, RED_D, over=0.1, style="ziegel", rinne=False)
    bank(B, (-0.85 + 1.25, H.y0 - 0.34, 0.35), 1.3, 0)
    schwelle(B, F, 1.15, 1.7, 0.3, 0.06, v=0.06)
    lampe(B, L, F, 2.02, 2.2, arm=0.22)
    # Briefkasten
    B.box((0.09, 0.09, 1.0), (-2.5, -1.55, 0.5), WOOD_D)
    B.box((0.3, 0.42, 0.26), (-2.5, -1.55, 1.1), "5E7FB5", bevel=0.05, segs=1)
    B.box((0.04, 0.03, 0.2), (-2.33, -1.55, 1.24), RED)
    B.box((0.2, 0.02, 0.03), (-2.5, -1.77, 1.12), DK)
    # --- Wäscheleine (rechts vorn), Wäsche wiegt sich
    lx = 1.85
    B.box((0.1, 0.1, 2.1), (lx, -1.5, 0.25 + 1.05), WOOD_D)
    B.box((0.5, 0.08, 0.08), (lx, -1.5, 2.3), WOOD_D)
    kabel(B, (lx, -1.5, 2.3), (lx, H.y0 - 0.05, 2.3), 0.08, 0.018, "E6E0D2", 4)
    ws = M.origin("sway_waesche", (lx, (-1.5 + H.y0) / 2, 2.24), local=True)
    for (dy, w, h, c) in ((-0.42, 0.34, 0.5, "F4F6FA"), (-0.02, 0.3, 0.42, "5B93EE"), (0.34, 0.26, 0.6, "E04848")):
        ws.box((0.03, w, h), (0, dy, -h / 2 - 0.02), c)
        ws.box((0.05, 0.04, 0.07), (0, dy - w / 2 + 0.05, 0.0), WOOD_L)
        ws.box((0.05, 0.04, 0.07), (0, dy + w / 2 - 0.05, 0.0), WOOD_L)
    # Wäschekorb, Fahrrad, Blumen
    B.cyl(0.24, 0.26, (1.35, -1.1, 0.38), "D9A05A", r2=0.28, sides=8)
    B.ball(0.2, (1.35, -1.1, 0.5), "F4F6FA", scale=(1, 1, 0.5), subdiv=1)
    fahrrad(B, (H.x1 + 0.3, 0.45, 0.25), 90)
    blume(B, (1.1, -0.45, 0.25), 4, 0.25); blume(B, (2.45, -1.2, 0.25), 3, 0.2)
    # --- Stufe 4: Gold, Fahne, Fass mit Regenwasser
    X4 = M["lv4_ausbau"]
    X4.cyl(0.16, H.w + 0.6, (H.cx, H.cy, H.top + 1.27), GOLD, r=rot(0, 90, 0), sides=6)
    fahne(M, X4, (-2.55, -1.2, 0.25), 3.6, size=(0.8, 0.55))
    barrel(X4, (H.x1 - 0.25, H.y0 - 0.4, 0.25), "5E7FB5", 0.3, 0.8)
    tile(X4, F, 0.0, 2.72, F.len, 2.86, 0.15, 0.06, GOLD)
    star(X4, (H.cx + 0.3, H.y0 - 0.16, 2.62), 0.0, GOLD, 0.05)
    # --- Gebrauchsspuren
    moos(B, H.W("b"), 1.5, 4, 1.5); moos(B, Rw, 1.5, 2, 0.4)
    brett_quer(M["lvmax3_haus"], Rw, 0.45, 0.8, 0.5, 0.17, -11)
    fleck(B, 0.95, -1.45, 0.25, 0.3, "8FA9C4")
    d1, d2 = schaden_std(M, H)
    brett_quer(d1, F, 3.75, 1.9, 1.2, 0.18, 14, out=0.24)
    M.empty("fx_smoke_dmg", (H.cx - 0.8, H.cy, H.top + 0.8))
    M.punkte(door=(H.x0 + 1.15, -1.45), work_1=(1.45, -1.45), work_2=(0.4, -1.5), drop=(-0.3, -0.75, 0.35), bubble=(0.0, 0.5, 5.4))
    M.finish()


MODELS["b_quartier"] = quartier


# ================================================================== Kistenlager (2x2)
def kistenlager():
    M = Model("b_kistenlager", 3.6, 3.6, looks=2)
    B, G, L = M["body"], M["win_glow"], M["lamp_glow"]
    H = Haus(-0.1, 0.8, 2.9, 1.45, 0.25, 2.9)
    hof(M, 3.5, 3.5, -0.75, skip=[(H.x0 + 0.1, H.y0 + 0.1, H.x1 - 0.1, H.y1 - 0.1)])
    H.kern(B)
    F, Rw = H.W("f"), H.W("r")
    hd = tuer(B, F, 0.9, 0.0, 1.3, 2.5, color=PURPLE, frame=GOLD_D, knob=GOLD)
    hw = fenster(B, G, F, 2.35, 1.3, 0.7, 0.9)
    hr = fenster(B, G, Rw, 0.72, 1.3, 0.6, 0.9)
    holes = {"f": [hd, hw], "r": [hr]}
    sockel(B, H, holes)
    wandsatz(M["lvmax3_haus"], H, "bretter", holes, color="B5682F")
    wandsatz(M["lv4_haus"], H, "stein", holes)
    R = dach(B, (H.cx, H.cy, H.top), H.w, H.d, 1.0, BLUE, over=0.2, over_g=0.16, ground=0.25, fallrohr=False, tw=0.46)
    giebelfeld(B, H, 1.0, "plank_h", WOOD_L)
    flicken(B, R.planes[0], 0.7, 0.6, 0.5, 0.45, WOOD_P)
    px, py, pz = dach_pos(R, -0.9, 0.0)
    B.box((0.4, 0.4, 0.4), (px, py, pz + 0.05), CREAM)
    B.cyl(0.36, 0.28, (px, py, pz + 0.38), BLUE_D, r=rot(0, 0, 45), r2=0.04, sides=4)
    lampe(B, L, F, 1.75, 2.3, arm=0.24)
    sb = schild(B, F, 0.9, 2.78, 0.6, 0.34, PURPLE, GOLD)                              # Schild: Kiste
    sb.box((0.3, 0.03, 0.16), (0, 0, -0.02), GOLD)
    # --- Flaschenzug am Giebel rechts
    tip = (H.x1 + 0.2, -0.1, 3.3)
    beam(B, (H.x1 - 0.3, 0.5, 3.3), tip, 0.14, WOOD_D)
    beam(B, (H.x1 - 0.02, 0.5, 2.6), (H.x1 + 0.3, 0.05, 3.25), 0.07, WOOD_D)
    B.cyl(0.12, 0.08, (tip[0], tip[1] + 0.05, tip[2] - 0.14), STEEL_D, r=rot(0, 90, 0), sides=8)
    hk = M.origin("sway_haken", (tip[0], tip[1] + 0.05, tip[2] - 0.2), local=True)
    hk.cyl(0.018, 1.0, (0, 0, -0.5), "C9B38A", sides=4)
    hk.cyl(0.09, 0.07, (0, 0, -1.0), STEEL_D, r=rot(0, 90, 0), sides=6)
    truhe(hk, (0, 0, -1.72), 0.62, STEEL_L, "5E7FB5", yaw=90)
    # --- Podest mit leuchtender Kiste
    cx, cy = 0.55, -0.85
    B.cyl(0.62, 0.22, (cx, cy, 0.36), ST_L, sides=8, r=rot(0, 0, 22.5))
    B.cyl(0.5, 0.2, (cx, cy, 0.57), ST, sides=8, r=rot(0, 0, 22.5))
    B.cyl(0.52, 0.05, (cx, cy, 0.67), GOLD, sides=8, r=rot(0, 0, 22.5))
    ko = M.origin("bob_kiste", (cx, cy, 0.78), local=True)
    truhe(ko, (0, 0, 0), 0.7, GOLD, PURPLE, yaw=-12)
    pg = M.origin("pulse_schein_glow", (cx, cy, 1.62), local=True)
    star(pg, (0, 0, 0), 0.26, GLOW, 0.05)
    M.empty("fx_spark", (cx, cy, 1.5))
    # --- Stapel bunter Beutekisten, Brechstange
    truhe(B, (-1.15, -0.55, 0.25), 0.72, STEEL_L, WOOD, yaw=6)
    truhe(B, (-1.25, -1.2, 0.25), 0.72, GOLD, "5E7FB5", yaw=80)
    truhe(B, (-1.15, -0.6, 0.76), 0.6, GOLD, "C9463E", yaw=-10)
    crate(B, (1.35, -0.2, 0.25), 0.55, WOOD_L, 8)
    beam(B, (-0.55, -0.5, 0.27), (-0.75, -0.42, 1.3), 0.045, "C9463E")                     # Brechstange
    B.box((0.05, 0.12, 0.05), (-0.77, -0.38, 1.32), "C9463E")
    for i in range(3):                                                                    # verstreute Münzen
        B.cyl(0.07, 0.025, (0.1 + i * 0.22, -1.35 - i * 0.07, 0.27), GOLD, sides=8)
    X4 = M["lv4_ausbau"]
    truhe(X4, (-1.25, -1.2, 0.76), 0.6, STEEL_L, PURPLE, yaw=95)
    truhe(X4, (1.35, -1.3, 0.25), 0.66, GOLD, OLIVE, yaw=70)
    X4.cyl(0.14, H.w + 0.4, (H.cx, H.cy, H.top + 1.12), GOLD, r=rot(0, 90, 0), sides=6)
    X4.cyl(0.54, 0.07, (cx, cy, 0.48), GOLD, sides=8, r=rot(0, 0, 22.5))
    for (x, y) in ((H.x0, H.y0), (H.x1, H.y0)):
        X4.box((0.34, 0.34, 0.12), (x, y, H.z0 + 2.75), GOLD)
    moos(B, H.W("b"), 1.2, 3, 1.0, out=0.0); moos(B, F, 2.6, 2, 0.4)
    brett_quer(M["lvmax3_haus"], Rw, 1.05, 0.75, 0.5, 0.17, 10)
    d1, d2 = schaden_std(M, H)
    truhe(d2, (0.2, -1.3, 0.25), 0.55, STEEL_D, WOOD_D, yaw=40)
    M.empty("fx_smoke_dmg", (H.cx + 0.6, H.cy, H.top + 0.7))
    M.punkte(door=(H.x0 + 0.9, H.y0 - 0.5), work_1=(cx - 0.1, cy - 0.75), work_2=(-0.55, -0.9), drop=(0.3, -0.2), bubble=(0.0, 0.5, 5.0))
    M.finish()


MODELS["b_kistenlager"] = kistenlager


# ================================================================== Werkstatt (3x3)
def werkstatt():
    M = Model("b_werkstatt", 5.6, 5.6, looks=2)
    B, G, L = M["body"], M["win_glow"], M["lamp_glow"]
    H = Haus(-0.75, 1.25, 3.5, 2.3, 0.25, 3.1)
    hof(M, 5.5, 5.5, -1.0, skip=[(H.x0 + 0.1, H.y0 + 0.1, H.x1 - 0.1, H.y1 - 0.1)])
    H.kern(B)
    F, Rw = H.W("f"), H.W("r")
    hd = tuer(B, F, 1.0, 0.0)
    schwelle(B, F, 1.0)
    hw = fenster(B, G, F, 2.65, 1.3, 0.8, 1.0)
    holes = {"f": [hd, hw], "r": []}
    sockel(B, H, holes)
    wandsatz(M["lvmax3_haus"], H, "bretter", holes)
    wandsatz(M["lv4_haus"], H, "ziegel", holes)
    RC = "D9782E"
    R = dach(B, (H.cx, H.cy, H.top), H.w, H.d, 1.3, RC, over=0.3, over_g=0.2, ground=0.25, fallrohr=False)
    giebelfeld(B, H, 1.3, "plank_h", WOOD_L)
    flicken(B, R.planes[0], 0.8, 1.0, 0.65, 0.5, WOOD_P)
    lampe(B, L, F, 1.9, 2.5)
    # Zahnrad-Schild über der Tür (dreht langsam mit)
    B.box((0.08, 0.5, 0.08), (H.x0 + 1.0, H.y0 - 0.25, H.z0 + 3.02), DK)
    gz = M.origin("spin_zahnrad", (H.x0 + 1.0, H.y0 - 0.42, H.z0 + 3.02), (math.radians(90), 0, 0), local=True)
    gear(gz, 0.42, 0.09, GOLD, 9)
    # --- Esse mit Glut und Schornstein (rechts hinten, unter einem Vordach), Amboss mit Funken
    ex, ey = 1.9, 1.3
    E = Haus(ex, ey, 1.3, 1.2, 0.25, 1.0)
    B.box((1.2, 1.1, 1.0), (ex, ey, 0.75), shade(BRICK, 0.5))
    for s in "frbl":
        clad(B, E.W(s), "brick", BRICK, out=0.05)
    B.box((1.4, 1.3, 0.12), (ex, ey, 1.3), ST_D)
    M["esse_glow"].box((0.9, 0.8, 0.1), (ex, ey, 1.38), "FF7A1E")
    for i in range(5):
        B.box((0.2, 0.18, 0.14), (ex + RNG.uniform(-0.3, 0.3), ey + RNG.uniform(-0.25, 0.25), 1.44), "2A2622", r=rot(RNG.uniform(-20, 20), 0, RNG.uniform(0, 90)))
    B.cyl(0.85, 0.7, (ex, ey + 0.1, 2.75), BRICK, r=rot(0, 0, 45), r2=0.4, sides=4)                    # Rauchfang
    for (dx, dy) in ((-0.55, -0.5), (0.55, -0.5), (-0.55, 0.55), (0.55, 0.55)):
        B.box((0.09, 0.09, 1.1), (ex + dx, ey + dy, 1.9), DK)
    schornstein(M, B, (ex, ey + 0.1, 3.05), 1.9, 0.5)
    B.box((0.5, 0.36, 0.5), (ex - 0.95, ey + 0.2, 0.9), "8A5030", r=rot(0, -10, 0))                    # Blasebalg
    B.cone(0.14, 0.4, (ex - 0.62, ey + 0.2, 0.95), STEEL_D, r=rot(0, 90, 0), sides=6)
    amboss(B, (1.55, -0.3, 0.25), 15)
    beam(B, (1.25, -0.15, 1.25), (1.6, -0.35, 1.32), 0.05, WOOD_L)                                     # Hammer auf dem Amboss
    B.box((0.14, 0.24, 0.14), (1.62, -0.36, 1.33), STEEL_D, r=rot(0, 0, 60))
    M["esse_glow"].box((0.4, 0.07, 0.04), (1.55, -0.32, 1.24), "FF9A3A", r=rot(0, 0, 40))              # glühendes Werkstück
    M.empty("fx_spark", (1.55, -0.3, 1.35))
    B.cyl(0.3, 0.45, (2.35, 0.2, 0.47), WOOD_D, sides=9)                                               # Löschtrog
    B.cyl(0.25, 0.02, (2.35, 0.2, 0.69), "5FA9D8", sides=9)
    # --- Werkbank mit Schraubstock (vorn links)
    bx, by = -1.75, -1.45
    for i in range(3):
        B.box((1.9, 0.26, 0.1), (bx, by + (i - 1) * 0.27, 1.12), jit(WOOD_L, 0.07))
    for sx in (-0.85, 0.85):
        for sy in (-0.3, 0.3):
            B.box((0.14, 0.14, 0.85), (bx + sx, by + sy, 0.66), WOOD_D)
    B.box((1.7, 0.6, 0.06), (bx, by, 0.5), WOOD)
    B.box((0.3, 0.24, 0.2), (bx + 0.6, by - 0.25, 1.27), "5E7FB5")                                     # Schraubstock
    B.box((0.08, 0.34, 0.26), (bx + 0.6, by - 0.38, 1.32), "5E7FB5")
    B.cyl(0.03, 0.4, (bx + 0.6, by - 0.52, 1.25), STEEL_L, r=rot(0, 90, 0), sides=4)
    B.box((0.5, 0.12, 0.06), (bx - 0.3, by, 1.2), STEEL, r=rot(0, 0, 25))                              # Feile, Zange
    B.box((0.3, 0.3, 0.22), (bx - 0.6, by + 0.15, 0.64), RED)                                          # Werkzeugkiste
    crate(B, (bx + 0.35, by + 0.05, 0.53), 0.4, WOOD_L)
    # --- Schleifstein (dreht) mit Gestell
    sx_, sy_ = 0.35, -1.9
    for dx in (-0.22, 0.22):
        beam(B, (sx_ + dx, sy_ - 0.35, 0.25), (sx_ + dx, sy_, 1.0), 0.08, WOOD_D)
        beam(B, (sx_ + dx, sy_ + 0.35, 0.25), (sx_ + dx, sy_, 1.0), 0.08, WOOD_D)
    st = M.origin("spin_stein", (sx_, sy_, 0.98), (0, math.radians(90), 0), local=True)
    st.cyl(0.42, 0.18, (0, 0, 0), "B9B1AC", sides=12)
    st.cyl(0.12, 0.24, (0, 0, 0), WOOD_D, sides=6)
    st.box((0.05, 0.3, 0.04), (0, 0.1, 0.3), STEEL_D)
    B.box((0.5, 0.3, 0.12), (sx_, sy_, 0.42), WOOD_D)                                                  # Wassertrog
    # --- Waffenständer (an der Hauswand rechts)
    a = At(B, T(1.95, -1.75, 0.25))
    for sxx in (-0.7, 0.7):
        beam(a, (sxx, 0.5, 0.0), (sxx, -0.1, 1.5), 0.08, WOOD_D)
    for z in (0.5, 1.5):
        a.box((1.5, 0.12, 0.1), (0, -0.2, z), WOOD_D)
    for sxx in (-0.7, 0.7):
        a.box((0.1, 0.14, 1.9), (sxx, -0.12, 0.95), WOOD_D)
    for i, x in enumerate((-0.45, -0.15, 0.15, 0.45)):
        if i % 2 == 0:                                                                                 # Schwert
            a.box((0.08, 0.03, 1.1), (x, -0.3, 1.15), STEEL_L)
            a.box((0.3, 0.05, 0.06), (x, -0.3, 0.6), GOLD)
            a.box((0.06, 0.05, 0.25), (x, -0.3, 0.45), WOOD_D)
        else:                                                                                          # Gewehr
            a.box((0.07, 0.07, 1.2), (x, -0.3, 1.25), DK)
            a.box((0.12, 0.09, 0.5), (x, -0.3, 0.55), WOOD)
    # --- Stufe 4
    X4 = M["lv4_ausbau"]
    X4.cyl(0.16, H.w + 0.6, (H.cx, H.cy, H.top + 1.42), GOLD, r=rot(0, 90, 0), sides=6)
    pultdach(X4, (ex, ey, 3.3), 1.5, 1.5, 0.3, RC, over=0.1, style="ziegel", rinne=False)
    fahne(M, X4, (-2.6, -2.25, 0.25), 3.4, size=(0.85, 0.6))
    barrel(X4, (0.6, -0.25 + 0.0, 0.25), "5E7FB5", 0.3, 0.8)
    for (x, y) in ((H.x0, H.y0), (H.x1, H.y0)):
        X4.box((0.36, 0.36, 0.14), (x, y, H.z0 + 2.9), GOLD)
    X4.box((0.7, 0.5, 0.5), (2.35, -0.72, 0.5), STEEL_D)                                                # Stahlbarren-Stapel
    for i in range(3):
        X4.box((0.5, 0.16, 0.1), (2.35, -0.88 + i * 0.16, 0.8), STEEL_L)
    # --- Gebrauchsspuren
    moos(B, H.W("b"), 1.5, 4, 1.4); fleck(B, 1.2, -0.9, 0.25, 0.5, "3A3430"); fleck(B, sx_ + 0.3, sy_ - 0.3, 0.25, 0.3, "8FA9C4")
    brett_quer(M["lvmax3_haus"], F, 3.1, 0.85, 0.6, 0.18, 12)
    d1, d2 = schaden_std(M, H)
    M.empty("fx_smoke_dmg", (H.cx, H.cy, H.top + 1.0))
    M.punkte(door=(H.x0 + 1.0, H.y0 - 0.55), work_1=(1.0, -0.7), work_2=(bx, by - 0.75), drop=(-0.2, -1.0), bubble=(-0.3, 0.9, 5.8))
    M.finish()


MODELS["b_werkstatt"] = werkstatt


# ================================================================== Garage (4x3)
def garage():
    M = Model("b_garage", 7.6, 5.6, looks=2)
    B, G, L = M["body"], M["win_glow"], M["lamp_glow"]
    # Halle: außen 4,0 x 4,45 m, innen 3,7 x 4,3 m (Fahrzeugplatz mindestens 2,6 x 4,2 m)
    H = Haus(-1.48, 0.3, 4.0, 4.4, 0.25, 3.3)
    t = 0.15
    fundament(B, 7.5, 5.22, 0.25, (0, 0.14), color="C4C6CC", skip=[(H.x0 + 0.1, H.y0 + 0.1, H.x1 - 0.1, H.y1 - 0.1)])
    B.box((2.6, 0.5, 0.2), (H.cx, -2.5, 0.08), CONC_D, r=rot(-22, 0, 0))                # Rampe vor dem Tor
    stufe(B, 1.3, -2.6, 1.9, 0.34, 0.13)
    B.box((H.w - 0.2, H.d - 0.2, 0.06), (H.cx, H.cy, 0.25), "9EA3AD")                     # Hallenboden
    zc = H.z0 + H.h / 2
    IN = "8C8478"
    B.box((t, H.d, H.h), (H.x0 + t / 2, H.cy, zc), IN)                                    # linke Wand
    B.box((H.w, t, H.h), (H.cx, H.y1 - t / 2, zc), IN)                                    # Rückwand
    gw, gh = 3.0, 2.8
    # rechte Wand mit Türöffnung wird massiv gebaut (Tür ist außen aufgesetzt)
    B.box((t, H.d, H.h), (H.x1 - t / 2, H.cy, zc), IN)
    for sx in (-1, 1):                                                                    # Torpfeiler und Sturz
        B.box(((H.w - gw) / 2, 0.3, H.h), (H.cx + sx * (gw / 2 + (H.w - gw) / 4), H.y0 + 0.15, zc), IN)
    B.box((gw, 0.3, H.h - gh), (H.cx, H.y0 + 0.15, H.z0 + gh + (H.h - gh) / 2), IN)
    B.box((H.w - 0.1, H.d - 0.1, 0.1), (H.cx, H.cy, H.top - 0.05), shade(IN, 0.7))        # Decke
    F, Rw, Lw, Bk = H.W("f"), H.W("r"), H.W("l"), H.W("b")
    u0 = H.w / 2 - gw / 2
    for u in (u0 - 0.1, u0 + gw + 0.1):                                                   # Torrahmen mit Warnstreifen
        tile(B, F, u - 0.12, 0, u + 0.12, gh + 0.1, 0.16, 0.16, DK)
        warnstreifen(B, F, u - 0.12, u + 0.12, 0.0, 1.0, 0.17, 2)
    tile(B, F, u0 - 0.22, gh, u0 + gw + 0.22, gh + 0.3, 0.2, 0.2, DK)
    # Rolltor: halb offen (Lamellen von 1,75 m bis zum Sturz)
    rz = 1.75
    n = 6
    for i in range(n):
        z0 = rz + i * (gh - rz) / n
        tile(B, F, u0, z0 + 0.012, u0 + gw, z0 + (gh - rz) / n - 0.012, -0.03 + (0.03 if i % 2 else 0.0), 0.06, jit("C9D0DE", 0.04))
    tile(B, F, u0, rz - 0.1, u0 + gw, rz + 0.02, 0.02, 0.1, "E0A21E")
    At(B, F.M(H.w / 2, rz - 0.05, 0.03)).box((0.4, 0.05, 0.05), (0, -0.04, 0), DK)
    slab(B, wand((H.cx + gw / 2, H.y0 + 0.02), (H.cx - gw / 2, H.y0 + 0.02), H.z0), [(0, rz), (gw, rz), (gw, gh), (0, gh)], 0.0, 0.0, "9AA0AC")  # Tor-Rückseite
    hole_g = (u0 - 0.22, 0.0, u0 + gw + 0.22, gh + 0.3)
    hd = tuer(B, Rw, 0.9, 0.0, 1.3, 2.5, color="5E7FB5", frame=DK, luke=True)
    hw = fenster(B, G, Rw, 2.25, 1.35, 0.8, 0.9, frame=DK)
    holes = {"f": [hole_g], "r": [hd, hw]}
    sockel(B, H, holes, shade(CONC_D, 0.8))
    wandsatz(M["lvmax3_halle"], H, "blech", holes, color="9FB0C8")
    wandsatz(M["lv4_halle"], H, "ziegel", holes, size=0.27)
    # --- Dach: Giebel nach vorn, blau, mit weißem Schraubenschlüssel
    rh = 1.25
    R = dach(B, (H.cx, H.cy, H.top), H.d, H.w, rh, BLUE, over=0.24, over_g=0.2, yaw=90, style="blech", ground=0.25, fallrohr=False)
    hg = fenster(B, G, F, H.w / 2, H.h + 0.3, 0.7, 0.5)
    giebelfeld(B, H, rh, "plank_h", STEEL_L, sides="f", fenster_=[hg])
    giebelfeld(B, H, rh, "plank_h", STEEL_L, sides="b")
    pr = R.planes[0] if (R.planes[0].ez.x > 0) else R.planes[1]                           # rechte Dachfläche (zur Kamera)
    cu, cv = pr.len / 2, R.SL / 2
    def wr(u0_, v0_, u1_, v1_):
        tile(B, pr, cu + min(u0_, u1_), cv + v0_, cu + max(u0_, u1_), cv + v1_, 0.2, 0.05, "F4F6FA")
    wr(-1.0, -0.12, 1.0, 0.12)
    for sgn in (-1, 1):
        wr(sgn * 0.85, -0.36, sgn * 1.1, 0.36)
        wr(sgn * 1.1, 0.15, sgn * 1.45, 0.36)
        wr(sgn * 1.1, -0.36, sgn * 1.45, -0.15)
    flicken(B, R.planes[1] if pr is R.planes[0] else R.planes[0], 1.2, 0.8, 0.7, 0.55, RUST)
    px, py, pz = dach_pos(R, 1.3, 0.0)
    B.cyl(0.36, 0.3, (px, py, pz + 0.1), STEEL_D, sides=8)
    lf = M.origin("spin_luefter", (px, py, pz + 0.36), local=True)
    lf.cyl(0.34, 0.14, (0, 0, 0), STEEL_L, sides=8, r2=0.2)
    for i in range(6):
        lf.box((0.3, 0.05, 0.16), (math.cos(math.radians(i * 60)) * 0.25, math.sin(math.radians(i * 60)) * 0.25, 0.02), STEEL, r=rot(0, 0, i * 60 + 30))
    # --- Innen: Regal und Reifen an der Rückwand (durch das Tor zu sehen)
    B.box((1.4, 0.4, 0.06), (H.x0 + 1.0, H.y1 - 0.4, 1.2), STEEL_D)
    B.box((1.4, 0.4, 0.06), (H.x0 + 1.0, H.y1 - 0.4, 0.7), STEEL_D)
    reifen(B, (H.x1 - 0.6, H.y1 - 0.55, 0.28), 2, 0.34)
    M["innen_glow"].box((1.2, 0.1, 0.06), (H.cx, H.cy + 0.6, H.top - 0.14), "FFF1B8")     # Neonröhre
    M.empty("veh_slot", (H.cx, H.cy - 0.05, 0.28))
    # --- Schild über dem Tor, Lampen
    sb = schild(B, F, H.w / 2, gh + 0.62, 1.5, 0.42, "F4F6FA", BLUE_D, out=0.1)
    sb.box((0.9, 0.03, 0.09), (0, 0, 0), BLUE_D)
    for sx in (-0.5, 0.5):
        sb.box((0.2, 0.03, 0.24), (sx, 0, 0), BLUE_D)
    lampe(B, L, F, 0.3, 2.6, arm=0.25); lampe(B, L, Rw, 1.62, 2.35, arm=0.25)
    # --- Werkzeugwand (rechte Hallenwand, hinten)
    a = At(B, Rw.M(3.45, 0.75, 0.12))
    a.box((1.6, 0.06, 1.5), (0, -0.03, 0.75), "D9A05A")
    a.box((1.7, 0.1, 0.08), (0, -0.05, 1.54), WOOD_D); a.box((1.7, 0.1, 0.08), (0, -0.05, -0.02), WOOD_D)
    a.box((0.08, 0.04, 0.7), (-0.55, -0.09, 0.9), STEEL_L); a.box((0.24, 0.05, 0.14), (-0.55, -0.09, 1.28), STEEL_L)     # Schlüssel
    a.box((0.07, 0.04, 0.6), (-0.2, -0.09, 0.85), RED); a.box((0.05, 0.04, 0.4), (-0.2, -0.09, 1.25), STEEL)             # Schraubendreher
    a.box((0.1, 0.05, 0.5), (0.2, -0.09, 0.7), WOOD); a.box((0.34, 0.1, 0.16), (0.2, -0.1, 1.0), STEEL_D)                # Hammer
    a.torus(0.2, 0.04, (0.55, -0.1, 1.05), "22252E", r=rot(90, 0, 0), seg=10, tseg=4)                                    # Keilriemen
    a.box((0.5, 0.05, 0.08), (0.45, -0.09, 0.35), STEEL_L, r=rot(0, 20, 0))                                              # Säge
    a.box((1.5, 0.34, 0.06), (0, -0.2, -0.1), WOOD)                                                                     # Ablage
    a.box((0.3, 0.26, 0.24), (-0.4, -0.2, 0.05), RED); a.cyl(0.1, 0.26, (0.3, -0.2, 0.06), "5E7FB5", sides=6)
    # --- Hebebühne (rechts), mit Motorblock
    hx, hy = 2.2, 0.9
    for sx in (-1, 1):
        B.box((0.26, 0.4, 2.3), (hx + sx * 1.05, hy, 1.4), "E0A21E")
        B.box((0.5, 0.7, 0.1), (hx + sx * 1.05, hy, 0.3), DK)
        warnstreifen(B, wand((hx + sx * 1.05 - 0.13, hy - 0.2), (hx + sx * 1.05 + 0.13, hy - 0.2), 0.35), 0, 0.26, 0, 0.5, 0.01, 2)
    B.box((2.3, 0.14, 0.14), (hx, hy, 2.6), "E0A21E")
    bb = M.origin("bob_buehne", (hx, hy, 1.15), local=True)
    for sx in (-1, 1):
        bb.box((0.2, 0.3, 0.2), (sx * 0.86, 0, 0), DK)
        for sy in (-1, 1):
            beam(bb, (sx * 0.86, 0, 0), (sx * 0.4, sy * 0.75, 0.0), 0.1, STEEL_D)
            bb.cyl(0.12, 0.06, (sx * 0.4, sy * 0.75, 0.06), "22252E", sides=6)
    bb.box((0.9, 1.3, 0.12), (0, 0, 0.16), STEEL)                                          # Fahrgestell auf der Bühne
    bb.box((0.7, 0.6, 0.4), (0, -0.2, 0.42), "3C8A6A", bevel=0.05, segs=1)                 # Motorblock
    for i in range(3):
        bb.cyl(0.07, 0.16, (-0.2 + i * 0.2, -0.2, 0.68), STEEL_L, sides=6)
    for sx in (-1, 1):
        for sy in (-0.5, 0.5):
            bb.cyl(0.22, 0.14, (sx * 0.52, sy, 0.16), "22252E", r=rot(0, 90, 0), sides=8)
    M.empty("fx_spark", (hx + 0.3, hy - 0.4, 1.4))
    # --- Zapfsäule, Reifenstapel, Ölfass
    zx, zy = 3.1, -1.75
    B.box((0.9, 0.7, 0.14), (zx, zy, 0.32), CONC_D)
    B.box((0.6, 0.42, 1.5), (zx, zy, 1.12), RED, bevel=0.06, segs=1)
    B.box((0.66, 0.46, 0.14), (zx, zy, 1.9), "F4F6FA")
    M["pump_glow"].box((0.4, 0.04, 0.26), (zx, zy - 0.22, 1.45), "FFF1B8")
    B.box((0.44, 0.04, 0.3), (zx, zy - 0.21, 1.45), DK)
    kabel(B, (zx - 0.32, zy, 1.5), (zx - 0.34, zy - 0.1, 0.8), 0.25, 0.03, "22252E", 4)
    B.box((0.08, 0.08, 0.26), (zx - 0.36, zy - 0.12, 0.9), STEEL_D)
    reifen(B, (0.95, -2.05, 0.25), 3, 0.36); reifen(B, (1.7, -2.15, 0.25), 2, 0.36)
    B.torus(0.24, 0.13, (1.25, -1.6, 0.6), "tire", r=rot(74, 0, 30), seg=12, tseg=6)
    barrel(B, (3.25, 0.1, 0.25), "3F4654"); barrel(B, (0.95, 2.0, 0.25), RED)
    fleck(B, H.cx + 0.3, -2.3, 0.25, 0.55, "24232A"); fleck(B, 3.0, -0.4, 0.25, 0.4, "24232A"); fleck(B, hx, hy - 0.2, 0.25, 0.5, "33323A")
    crate(B, (3.3, 2.1, 0.25), 0.6, WOOD)
    # --- Stufe 4: Vordach über der Bühne (Rahmen), Kompressor, Gold
    X4 = M["lv4_ausbau"]
    X4.box((0.8, 0.5, 0.5), (1.4, 2.1, 0.55), "5E7FB5", bevel=0.05, segs=1)
    X4.cyl(0.25, 0.9, (1.4, 2.1, 1.05), "E6E0D2", r=rot(0, 90, 0), sides=8)
    X4.cyl(0.15, H.d + 0.44, (H.cx, H.cy, H.top + rh + 0.12), GOLD, r=rot(90, 0, 0), sides=6)
    tile(X4, F, 0.0, 3.0, u0 - 0.24, 3.16, 0.16, 0.06, GOLD); tile(X4, F, u0 + gw + 0.24, 3.0, F.len, 3.16, 0.16, 0.06, GOLD)
    tile(X4, Rw, 0.0, 3.0, Rw.len, 3.16, 0.16, 0.06, GOLD)
    fahne(M, X4, (3.5, 2.3, 0.25), 3.6, size=(0.85, 0.6), yaw=180)
    X4.box((0.5, 0.5, 0.1), (zx, zy, 2.02), GOLD)
    reifen(X4, (1.7, -2.15, 0.75), 2, 0.36)
    brett_quer(M["lvmax3_halle"], Rw, 2.3, 0.8, 0.7, 0.5, 5, color=RUST)
    moos(B, Bk, 2.0, 4, 1.5, out=0.02)
    # --- Schaden
    d1, d2 = schaden_std(M, H, holz=False)
    riss(d1, F, 0.25, 0.4, 1.4); russ(d1, F, u0 + gw + 0.3, 3.0, 0.3)
    schrott_ = [(2.6, -0.8), (2.2, -1.1), (2.9, -1.2)]
    for (x, y) in schrott_:
        d2.box((0.5, 0.3, 0.12), (x, y, 0.32), jit(RUST, 0.1), r=rot(8, 5, RNG.uniform(0, 90)))
    M.empty("fx_smoke_dmg", (H.cx + 0.8, H.cy, H.top + 0.9))
    M.punkte(door=(H.x1 + 0.55, H.y0 + 0.9), work_1=(hx, hy - 1.15), work_2=(H.x1 + 0.6, H.y0 + 3.45), drop=(2.3, -1.7), bubble=(-0.6, 0.4, 6.0))
    M.finish()


MODELS["b_garage"] = garage


# ================================================================== Funkturm (2x2)
def gittermast(p, x, y, z0, h, w0=0.9, w1=0.25, color=STEEL, n=6):
    """Gittermast: vier Eckstiele, Ringe und Kreuzstreben."""
    def cor(k, i):
        w = (w0 + (w1 - w0) * k) / 2
        sx, sy = ((-1, -1), (1, -1), (1, 1), (-1, 1))[i % 4]
        return (x + sx * w, y + sy * w, z0 + h * k)
    for i in range(4):
        beam(p, cor(0, i), cor(1, i), 0.09, color)
    for j in range(n + 1):
        k = j / n
        for i in range(4):
            beam(p, cor(k, i), cor(k, i + 1), 0.06, shade(color, 0.85))
            if j < n:
                beam(p, cor(k, i), cor((j + 1) / n, i + (1 if j % 2 == 0 else -1)), 0.05, shade(color, 0.92))


def kabelrolle(p, loc, r=0.42, w=0.5, yaw=0.0, liegend=False, color=WOOD_L, kab="22252E"):
    a = At(p, T(*loc) @ rot(0, 0, yaw) @ (T(0, 0, w / 2) if liegend else T(0, 0, r) @ rot(90, 0, 0)))
    for s in (-1, 1):
        a.cyl(r, 0.06, (0, 0, s * w / 2), jit(color, 0.06), sides=10)
    a.cyl(r * 0.62, w - 0.06, (0, 0, 0), kab, sides=10)
    a.cyl(r * 0.2, w + 0.1, (0, 0, 0), WOOD_D, sides=6)


def funkturm():
    M = Model("b_funkturm", 3.6, 3.6, looks=2)
    B, G, L = M["body"], M["win_glow"], M["lamp_glow"]
    H = Haus(0.16, -0.35, 2.2, 1.75, 0.25, 2.7)
    hof(M, 3.5, 3.5, 0.25, color="C4C6CC", skip=[(H.x0 + 0.1, H.y0 + 0.1, H.x1 - 0.1, H.y1 - 0.1)])
    H.kern(B)
    F, Rw = H.W("f"), H.W("r")
    hd = tuer(B, F, 0.85, 0.0, 1.3, 2.4, color="5E7FB5", frame=CREAM)
    hr = fenster(B, G, Rw, 0.88, 1.2, 0.85, 0.95)
    hf = fenster(B, G, F, 1.88, 1.5, 0.3, 0.6, kreuz=False)
    holes = {"f": [hd, hf], "r": [hr]}
    sockel(B, H, holes)
    wandsatz(M["lvmax3_bude"], H, "bretter_h", holes, color="C98A4B")
    wandsatz(M["lv4_bude"], H, "stein", holes)
    R = dach(B, (H.cx, H.cy, H.top), H.d, H.w, 0.8, BLUE, over=0.2, over_g=0.16, yaw=90, style="blech", ground=0.25, fallrohr=False)
    giebelfeld(B, H, 0.8, "plank_h", WOOD_L, sides="fb")
    flicken(B, R.planes[0], 0.6, 0.5, 0.45, 0.4, RUST)
    lampe(B, L, F, 1.88, 2.25, arm=0.2)
    # Kopfhörer am Fenster (auf der Fensterbank rechts), Funkgerät mit Skala
    a = At(B, Rw.M(0.88, 1.2, 0))
    a.torus(0.16, 0.03, (0.15, -0.3, 0.2), DK, r=rot(0, 90, 20), seg=8, tseg=4)
    for sy in (-1, 1):
        a.cyl(0.09, 0.07, (0.15 + sy * 0.06, -0.3 + sy * 0.15, 0.1), RED, r=rot(90, 0, 20), sides=6)
    a.box((0.34, 0.2, 0.22), (-0.2, -0.28, 0.06), "3C8A6A")
    At(M["funk_glow"], Rw.M(0.88, 1.2, 0)).box((0.2, 0.03, 0.08), (-0.2, -0.39, 0.09), GLOW)
    a.cyl(0.012, 0.5, (-0.32, -0.3, 0.4), STEEL_L, sides=4)
    # --- Gittermast hinten links mit blinkender Lampe und drehender Schüssel
    mx, my, mh = -0.85, 0.85, 6.0
    B.box((1.3, 1.3, 0.25), (mx, my, 0.37), CONC_D, bevel=0.04, segs=1)
    gittermast(B, mx, my, 0.45, mh, 1.0, 0.24, "C9463E", 7)
    for k in (2, 4, 6):                                                                # weiße Abschnitte
        z = 0.45 + mh * k / 7
        w = (1.0 + (0.24 - 1.0) * k / 7) + 0.06
        B.box((w, w, 0.1), (mx, my, z), "F4F6FA")
    B.box((0.5, 0.5, 0.08), (mx, my, 0.45 + mh), STEEL_D)
    B.cyl(0.03, 0.9, (mx, my, 0.45 + mh + 0.45), STEEL_L, sides=4)
    lg = M.origin("pulse_lampe_glow", (mx, my, 0.45 + mh + 0.95), local=True)
    lg.ball(0.14, (0, 0, 0), HOT, subdiv=1)
    M.empty("fx_spark", (mx, my, 0.45 + mh + 0.7))
    for (dz, yw) in ((4.6, 200), (5.3, 30)):                                           # feste Richtantennen
        a2 = At(B, T(mx, my, dz) @ rot(0, 0, yw))
        a2.box((0.05, 0.7, 0.05), (0, -0.4, 0), STEEL_D)
        for i in range(4):
            a2.box((0.5 - i * 0.08, 0.03, 0.03), (0, -0.25 - i * 0.16, 0), STEEL_L)
    B.box((0.5, 0.06, 0.06), (mx + 0.3, my - 0.3, 3.5), STEEL_D, r=rot(0, 0, -45))
    sp = M.origin("spin_schuessel", (mx + 0.5, my - 0.5, 3.55), local=True)
    sp.cyl(0.05, 0.3, (0, 0, 0.1), STEEL_D, sides=6)
    d = At(sp, T(0, 0, 0.45) @ rot(60, 0, 0))
    d.cyl(0.55, 0.2, (0, 0, 0), "F4F6FA", r2=0.15, sides=12, r=rot(180, 0, 0))
    d.cyl(0.5, 0.02, (0, 0, 0.105), "C9D0DE", sides=12)
    d.cyl(0.02, 0.4, (0, 0, 0.3), STEEL_D, sides=4)
    d.ball(0.06, (0, 0, 0.5), RED, subdiv=1)
    kabel(B, (mx + 0.2, my - 0.2, 3.2), (H.cx, H.cy, H.top + 0.85), 0.5, 0.025)
    leiter(B, (mx - 0.0, my - 0.56, 0.5), (mx, my - 0.36, 2.4), 0.36, STEEL_L, 0.3, 0.04)
    # --- Kabelrollen, Kiste
    kabelrolle(B, (-1.05, -1.05, 0.25), 0.42, 0.5, 25)
    kabelrolle(B, (-0.55, -0.4 + 0.0, 0.25), 0.3, 0.36, 0, liegend=True, kab="C9463E")
    kabel(B, (-1.05, -1.1, 0.5), (-1.4, -1.5, 0.27), 0.0, 0.025, n=2)
    crate(B, (1.3, 0.95, 0.25), 0.55, WOOD_L, 10)
    # --- Stufe 4: zweite Schüssel, Solartafel, Gold, Fahne
    X4 = M["lv4_ausbau"]
    d2_ = At(X4, T(mx - 0.25, my + 0.2, 2.6) @ rot(0, 0, 130) @ rot(70, 0, 0))
    d2_.cyl(0.42, 0.16, (0, 0, 0), "F4F6FA", r2=0.1, sides=10, r=rot(180, 0, 0))
    d2_.cyl(0.38, 0.02, (0, 0, 0.085), GOLD, sides=10)
    X4.cyl(0.13, H.d + 0.36, (H.cx, H.cy, H.top + 0.92), GOLD, r=rot(90, 0, 0), sides=6)
    X4.box((0.6, 0.6, 0.1), (mx, my, 0.45 + mh + 0.05), GOLD)
    fahne(M, X4, (1.55, 1.5, 0.25), 3.0, size=(0.75, 0.52), yaw=180)
    for (x, y) in ((H.x0, H.y0), (H.x1, H.y0)):
        X4.box((0.32, 0.32, 0.12), (x, y, H.z0 + 2.55), GOLD)
    kabelrolle(X4, (-0.55, -0.4, 0.61), 0.24, 0.3, 0, liegend=True, kab="5E7FB5")
    moos(B, H.W("b"), 1.0, 3, 0.8, out=0.02)
    brett_quer(M["lvmax3_bude"], Rw, 0.3, 0.75, 0.45, 0.16, 9)
    fleck(B, -1.1, -0.3, 0.25, 0.3, "8FA9C4")
    d1, d2 = schaden_std(M, H)
    beam(d2, (mx + 0.6, my - 0.9, 0.3), (mx + 0.2, my - 0.3, 2.6), 0.12, WOOD_L)
    M.empty("fx_smoke_dmg", (H.cx, H.cy, H.top + 0.6))
    M.punkte(door=(H.x0 + 0.85, H.y0 - 0.5), work_1=(H.x1 - 0.1, H.y0 - 0.5), work_2=(-0.9, -0.3), drop=(-0.3, -1.3), bubble=(0.3, -0.2, 4.6))
    M.finish()


MODELS["b_funkturm"] = funkturm


# ================================================================== Clanhalle (4x4)
def saeule(p, x, y, z, h, r=0.26, color=ST_L, holz=False):
    if holz:
        p.box((r * 1.7, r * 1.7, h), (x, y, z + h / 2), jit(WOOD_D, 0.06))
        p.box((r * 2.4, r * 2.4, 0.2), (x, y, z + 0.1), WOOD_D)
        p.box((r * 2.4, r * 2.4, 0.16), (x, y, z + h - 0.08), WOOD_D)
        for (dx, dy) in ((1, 0), (-1, 0)):
            beam(p, (x + dx * 0.1, y, z + h - 0.75), (x + dx * 0.7, y, z + h - 0.1), 0.12, WOOD)
    else:
        p.box((r * 2.8, r * 2.8, 0.22), (x, y, z + 0.11), shade(color, 0.85), bevel=0.03, segs=1)
        p.cyl(r, h - 0.44, (x, y, z + h / 2), color, sides=10, r2=r * 0.86)
        p.cyl(r * 1.25, 0.1, (x, y, z + 0.27), GOLD, sides=10)
        p.cyl(r * 1.1, 0.1, (x, y, z + h - 0.27), GOLD, sides=10)
        p.box((r * 2.6, r * 2.6, 0.22), (x, y, z + h - 0.11), shade(color, 0.92), bevel=0.03, segs=1)


def feuerschale(M, p, name, loc, sockel_c=ST):
    x, y, z = loc
    p.box((0.6, 0.6, 0.7), (x, y, z + 0.35), sockel_c, bevel=0.05, segs=1)
    p.box((0.7, 0.7, 0.12), (x, y, z + 0.7), shade(sockel_c, 0.85))
    p.cyl(0.2, 0.3, (x, y, z + 0.9), DK, sides=8, r2=0.44)
    p.cyl(0.46, 0.08, (x, y, z + 1.07), "3A3F4C", sides=8)
    f = M.origin(name, (x, y, z + 1.1), local=True)
    f.cone(0.3, 0.75, (0, 0, 0.36), "FF8A1E", sides=7)
    f.cone(0.17, 0.5, (0.04, 0, 0.26), "FFE066", sides=6)
    f.cyl(0.36, 0.06, (0, 0, 0.02), "FF6A1E", sides=8)


def clanhalle():
    M = Model("b_clanhalle", 7.6, 7.6, looks=2)
    B, G, L = M["body"], M["win_glow"], M["lamp_glow"]
    H = Haus(0.0, 1.1, 6.0, 4.4, 0.45, 3.6)
    py0 = -2.6                                                                        # Vorderkante der Vorhalle
    fundament(B, 7.4, 6.5, 0.25, (0, 0.35), skip=[(-3.3, py0 + 0.1, 3.3, H.y1 - 0.1)])
    B.box((6.7, H.y1 - py0 + 0.3, 0.2), (0, (H.y1 + py0) / 2, 0.35), ST_D)                  # Podest
    pl = boden(-3.35, py0 - 0.15, 0.45)
    for j in range(2):
        for i in range(7):
            tile(B, pl, i * 0.957 + 0.02, j * 0.75 + 0.02, (i + 1) * 0.957 - 0.02, (j + 1) * 0.75 - 0.02 + (0.0 if j == 0 else -0.3), 0.0, 0.04, jit("EFE9DC", 0.05))
    for i, (w, zz, yy) in enumerate(((3.6, 0.13, -3.42), (3.3, 0.3, -3.1))):                # Freitreppe
        B.box((w, 0.4, zz), (0, yy, zz / 2), ST_L, bevel=0.02, segs=1)
    B.box((3.0, 0.3, 0.42), (0, -2.85, 0.21), ST_L)
    H.kern(B)
    F, Rw, Lw, Bk = H.W("f"), H.W("r"), H.W("l"), H.W("b")
    # --- großes Doppeltor
    gw, gh = 2.4, 3.0
    u0 = H.w / 2 - gw / 2
    a = At(B, F.M(H.w / 2, 0, 0))
    a.box((gw, 0.1, gh), (0, 0, gh / 2), shade(WOOD_D, 0.6))
    for i in range(8):
        tile(B, F, u0 + i * gw / 8 + 0.012, 0.02, u0 + (i + 1) * gw / 8 - 0.012, gh - 0.02, 0.085, 0.04, jit("8A4B2A", 0.07))
    a.box((0.06, 0.06, gh), (0, -0.09, gh / 2), WOOD_D)
    for z in (0.5, 1.5, 2.5):
        a.box((gw - 0.1, 0.05, 0.14), (0, -0.1, z), GOLD_D)
        for sx in (-1, 1):
            for k in (0.25, 0.75):
                a.ball(0.045, (sx * gw / 2 * k, -0.14, z), GOLD, subdiv=1)
    for sx in (-1, 1):
        a.torus(0.12, 0.03, (sx * 0.25, -0.16, 1.45), GOLD, r=rot(90, 0, 0), seg=8, tseg=4)
        a.box((0.2, 0.3, gh + 0.2), (sx * (gw / 2 + 0.1), -0.08, (gh + 0.2) / 2), ST_L)
    a.box((gw + 0.6, 0.34, 0.26), (0, -0.08, gh + 0.13), ST_L, bevel=0.03, segs=1)
    hole_g = (u0 - 0.2, 0.0, u0 + gw + 0.2, gh + 0.26)
    wr = [fenster(B, G, Rw, u, 1.1, 0.7, 1.7, frame=CREAM) for u in (0.9, 2.2, 3.5)]
    wf = [fenster(B, G, F, u, 1.3, 0.6, 1.3, frame=CREAM) for u in (0.75, H.w - 0.75)]
    holes = {"f": [hole_g] + wf, "r": wr}
    sockel(B, H, holes, v1=0.5)
    wandsatz(M["lvmax3_halle"], H, "bretter", holes, v0=0.5, color="A8572C")
    wandsatz(M["lv4_halle"], H, "stein", holes, v0=0.5, color="D2CBBE", color2="E4DED2", size=0.4, sides="fr")
    wandsatz(M["lv4_halle"], H, "stein", holes, v0=0.5, color="D2CBBE", color2="E4DED2", size=0.62, sides="bl", eck=False)
    # --- Dach über Halle und Vorhalle (Giebel nach vorn)
    rh = 2.0
    ry0, ry1 = py0, H.y1
    R = dach(B, (0, (ry0 + ry1) / 2, H.top), ry1 - ry0, H.w, rh, BLUE, over=0.32, over_g=0.22, yaw=90, ground=0.45, fallrohr=False, tw=0.56, row=0.52)
    giebelfeld(B, H, rh, "plank_h", "A8572C", sides="b")
    # Giebelfeld vorn (über den Säulen) mit Wappen
    PF = wand((-H.w / 2, py0 + 0.1), (H.w / 2, py0 + 0.1), H.top)
    slab(B, PF, [(0, 0), (H.w, 0), (H.w / 2, rh)], 0.0, 0.0, JOINT)
    clad(M["lvmax3_halle"], PF, "plank_h", "A8572C", v0=0.0, v1=rh, out=0.06, lines=giebel(0, H.w, 0, rh))
    clad(M["lv4_halle"], PF, "putz", "E4DED2", v0=0.0, v1=rh, out=0.07, lines=giebel(0, H.w, 0, rh))
    B.box((H.w + 0.3, 0.5, 0.34), (0, py0 + 0.25, H.top - 0.17), CREAM)                    # Gebälk auf den Säulen
    for sx in (-1, 1):
        B.box((0.4, H.y0 - py0, 0.3), (sx * (H.w / 2 - 0.2), (H.y0 + py0) / 2, H.top - 0.15), CREAM)
    wappen(B, PF.M(H.w / 2, 0.82, 0.08), 1.1)
    M["lv4_gold"].cyl(0.18, ry1 - ry0 + 0.5, (0, (ry0 + ry1) / 2, H.top + rh + 0.12), GOLD, r=rot(90, 0, 0), sides=6)
    slab(M["lv4_gold"], PF, [(0.2, 0.0), (H.w - 0.2, 0.0), (H.w - 0.2, 0.14), (0.2, 0.14)], 0.12, 0.06, GOLD)
    # --- Säulen (Stufe 1-3 Holz, ab 4 Stein mit Gold)
    for x in (-2.6, -1.35, 1.35, 2.6):
        saeule(M["lvmax3_halle"], x, py0 + 0.3, 0.45, 3.6 - 0.34, 0.2, holz=True)
        saeule(M["lv4_halle"], x, py0 + 0.3, 0.45, 3.6 - 0.34, 0.25)
    # --- zwei Banner, Feuerschalen, Glocke
    for (nm, x) in (("sway_banner_l", -1.97), ("sway_banner_r", 1.97)):
        banner(M, nm, (x, py0 + 0.22, H.top - 0.45), 0.8, 2.0)
    feuerschale(M, B, "pulse_feuer_glow", (-2.55, -3.25, 0.0))
    feuerschale(M, B, "pulse_feuer2_glow", (2.55, -3.25, 0.0))
    M.empty("fx_smoke", (-2.55, -3.25, 2.0)); M.empty("fx_smoke2", (2.55, -3.25, 2.0))
    gx, gy, gz = dach_pos(R, -(ry1 - ry0) / 2 + 1.5, 0.0)                               # Glockentürmchen auf dem First
    for (dx, dy) in ((-0.4, -0.4), (0.4, -0.4), (-0.4, 0.4), (0.4, 0.4)):
        B.box((0.14, 0.14, 1.5), (gx + dx, gy + dy, gz + 0.5), CREAM)
    B.box((1.1, 1.1, 0.16), (gx, gy, gz - 0.1), CREAM)
    B.cyl(0.85, 0.7, (gx, gy, gz + 1.6), BLUE_D, r=rot(0, 0, 45), r2=0.05, sides=4)
    B.ball(0.12, (gx, gy, gz + 2.0), GOLD, subdiv=1)
    B.box((0.9, 0.08, 0.08), (gx, gy, gz + 1.18), WOOD_D)
    gl = M.origin("sway_glocke", (gx, gy, gz + 1.14), local=True)
    gl.cyl(0.14, 0.5, (0, 0, -0.32), GOLD, r2=0.34, sides=10, r=rot(180, 0, 0))
    gl.cyl(0.36, 0.06, (0, 0, -0.58), GOLD_D, sides=10)
    gl.ball(0.08, (0, 0, -0.66), DK, subdiv=1)
    lampe(B, L, F, u0 - 0.55, 2.7); lampe(B, L, F, u0 + gw + 0.55, 2.7)
    # --- Beiwerk
    B.box((1.6, 0.4, 0.08), (3.25, -1.2, 0.72), WOOD_L, r=rot(0, 0, 90))                # Bank an der Seite
    for dy in (-0.6, 0.6):
        B.box((0.3, 0.1, 0.44), (3.25, -1.2 + dy, 0.47), WOOD_D)
    X4 = M["lv4_gold"]
    for sx in (-1, 1):
        X4.box((0.5, 0.5, 0.5), (sx * 3.3, -2.35, 0.5), ST_L, bevel=0.04, segs=1)          # Sockel mit Goldkugel
        X4.ball(0.26, (sx * 3.3, -2.35, 0.98), GOLD, subdiv=2)
    for u in (0.02, Rw.len - 0.02):
        tile(X4, Rw, u - 0.02, 3.2, u + 0.02, 3.4, 0.14, 0.05, GOLD)
    tile(X4, Rw, 0.0, 3.24, Rw.len, 3.4, 0.16, 0.06, GOLD)
    star(X4, (gx, gy - 0.5, gz + 0.3), 0.0, GOLD)
    moos(B, Bk, 2.0, 5, 3.0); moos(B, Rw, 3.9, 3, 0.8)
    flicken(B, R.planes[0] if R.planes[0].ez.x > 0 else R.planes[1], 4.6, 1.6, 0.8, 0.6, WOOD_P)
    brett_quer(M["lvmax3_halle"], Rw, 2.85, 0.9, 0.6, 0.2, 10)
    # --- Schaden
    d1, d2 = M["dmg1_spuren"], M["dmg2_bruch"]
    riss(d1, Rw, 0.4, 0.6, 1.6); riss(d1, Rw, 2.9, 0.5, 1.3); riss(d1, F, 5.2, 0.6, 1.4); russ(d1, Rw, 4.0, 2.6, 0.6); russ(d1, F, 0.4, 2.8, 0.45)
    loch(d2, Rw, 4.1, 1.3, 0.5); stuetze(d2, (H.x1 + 0.6, 2.4, 0.25), (H.x1 + 0.13, 2.4, 2.7))
    stuetze(d2, (2.0, py0 - 0.45, 0.45), (2.0, py0 + 0.2, 2.9))
    for i in range(4):
        d2.box((0.8, 0.18, 0.07), (0.6 + i * 0.3, -2.2 - i * 0.1, 0.5), jit("A8572C"), r=rot(0, 6, 25 + i * 40))
    M.empty("fx_smoke_dmg", (1.5, 1.5, H.top + 1.5))
    M.punkte(door=(0.0, -3.4), work_1=(-1.9, -2.2, 0.45), work_2=(1.2, -1.9, 0.45), drop=(0.0, -2.0, 0.45), bubble=(0.0, 0.0, 7.6))
    M.finish()


MODELS["b_clanhalle"] = clanhalle


# ================================================================== Labor (3x3)
def warnkiste(p, loc, s=0.7, yaw=0.0, color="E0A21E"):
    """Kiste mit Warnzeichen (schwarzes Dreieck auf Gelb)."""
    x, y, z = loc
    crate(p, loc, s, color, yaw, band="22252E")
    a = At(p, T(x, y, z) @ rot(0, 0, yaw))
    w = wand((-s * 0.3, -s / 2 - 0.02), (s * 0.3, -s / 2 - 0.02), s * 0.25)
    slab(a, w, [(0, 0), (s * 0.6, 0), (s * 0.3, s * 0.5)], 0.01, 0.0, "22252E")
    slab(a, w, [(s * 0.14, s * 0.07), (s * 0.46, s * 0.07), (s * 0.3, s * 0.36)], 0.02, 0.0, GOLD)
    w2 = wand((s / 2 + 0.02, -s * 0.3), (s / 2 + 0.02, s * 0.3), s * 0.25)
    slab(a, w2, [(0, 0), (s * 0.6, 0), (s * 0.3, s * 0.5)], 0.01, 0.0, "22252E")


def labor():
    M = Model("b_labor", 5.6, 5.6, looks=2)
    B, G, L = M["body"], M["win_glow"], M["lamp_glow"]
    H = Haus(-0.35, 0.85, 4.0, 3.0, 0.25, 3.2)
    hof(M, 5.5, 5.5, -0.9, color="C4C6CC", skip=[(H.x0 + 0.1, H.y0 + 0.1, H.x1 - 0.1, H.y1 - 0.1)])
    H.kern(B)
    F, Rw = H.W("f"), H.W("r")
    hd = tuer(B, F, 1.1, 0.0, 1.4, 2.6, color="E6E0D2", frame="2FA6A0", knob=STEEL_D, luke=True)
    schwelle(B, F, 1.1)
    hw = fenster(B, G, F, 2.9, 1.3, 1.3, 1.0, frame="2FA6A0", glow=CYAN)
    hr = [fenster(B, G, Rw, u, 1.3, 0.8, 1.0, frame="2FA6A0", glow=CYAN) for u in (0.85, 2.15)]
    holes = {"f": [hd, hw], "r": hr}
    sockel(B, H, holes, shade(CONC_D, 0.8))
    wandsatz(M["lvmax3_haus"], H, "beton", holes, color="D9DDE4")
    W4 = M["lv4_haus"]
    for s in "frbl":
        clad(W4, H.W(s), "panel", "EEF2F6", v0=0.42, holes=holes.get(s, ()), out=0.14, size=1.0)
        tile(W4, H.W(s), 0.0, 1.0, H.W(s).len, 1.16, 0.17, 0.05, "2FA6A0") if s in "bl" else None
        tile(W4, H.W(s), 0.0, H.h - 0.2, H.W(s).len, H.h - 0.04, 0.2, 0.08, GOLD)
    ecken(W4, H, "2FA6A0", 0.34, 0.19)
    # --- Flachdach mit Brüstung
    B.box((H.w + 0.5, H.d + 0.5, 0.22), (H.cx, H.cy, H.top + 0.05), CONC_D, bevel=0.04, segs=1)
    pl = boden(H.x0, H.y0, H.top + 0.16)
    for i in range(5):
        for j in range(4):
            tile(B, pl, i * 0.8 + 0.02, j * 0.75 + 0.02, (i + 1) * 0.8 - 0.02, (j + 1) * 0.75 - 0.02, 0.03, 0.03, jit("AEB4BE", 0.05))
    for s in "frbl":
        w = H.W(s)
        At(B, w.M(w.len / 2, H.h + 0.16, 0.2)).box((w.len + 0.44, 0.14, 0.34), (0, 0.07, 0.17), jit("C9CED6", 0.04))
    tube(B, (H.x1 + 0.3, H.y0 - 0.2, H.top + 0.02), (H.x1 + 0.3, H.y0 - 0.2, 0.25), 0.06, STEEL_D, 6)       # Fallrohr
    tube(B, (H.x0 - 0.2, H.y0 - 0.26, H.top), (H.x1 + 0.2, H.y0 - 0.26, H.top), 0.07, STEEL_D, 6)             # Dachrinne
    flicken(B, pl, 3.3, 0.5, 0.7, 0.5, RUST, out=0.07)
    # --- Glaskuppel mit Blubber-Tank
    kx, ky, kz, kr = H.cx - 0.5, H.cy + 0.1, H.top + 0.19, 1.25
    B.cyl(kr + 0.12, 0.3, (kx, ky, kz + 0.15), "2FA6A0", sides=12)
    B.cyl(kr - 0.05, 0.08, (kx, ky, kz + 0.32), "3A3F4C", sides=12)
    n = 8
    for i in range(n):                                                                    # Rippen der Kuppel
        a0 = 2 * math.pi * i / n
        prev = None
        for k in range(5):
            t = math.radians(k * 22.5)
            q = (kx + math.cos(a0) * kr * math.cos(t), ky + math.sin(a0) * kr * math.cos(t), kz + 0.3 + kr * math.sin(t))
            if prev:
                beam(B, prev, q, 0.07, "E6E0D2")
            prev = q
    for k in (1, 2, 3):
        t = math.radians(k * 22.5)
        B.torus(kr * math.cos(t), 0.03, (kx, ky, kz + 0.3 + kr * math.sin(t)), "E6E0D2", seg=12, tseg=4)
    B.ball(0.14, (kx, ky, kz + 0.3 + kr), GOLD, subdiv=1)
    gl = M["kuppel_glow"]                                                                  # einzelne Glasfelder (leuchten kühl)
    for i in (0, 3, 5):
        a0, a1 = 2 * math.pi * (i + 0.12) / n, 2 * math.pi * (i + 0.88) / n
        pts = []
        t0, t1 = math.radians(4), math.radians(40)
        for (aa, tt) in ((a1, t0), (a0, t0), (a0, t1), (a1, t1)):
            pts.append(Vector((kx + math.cos(aa) * kr * 0.97 * math.cos(tt), ky + math.sin(aa) * kr * 0.97 * math.cos(tt), kz + 0.3 + kr * 0.97 * math.sin(tt))))
        f = gl.bm.faces.new([gl.bm.verts.new(q) for q in pts])
        for l in f.loops:
            l[gl.layer] = col("8FE6F0")
    B.cyl(0.5, 0.2, (kx, ky, kz + 0.4), STEEL_D, sides=10)                                 # Tank
    B.cyl(0.42, 0.9, (kx, ky, kz + 0.95), "2B4A52", sides=10)
    B.cyl(0.5, 0.12, (kx, ky, kz + 1.42), STEEL_D, sides=10)
    tk = M.origin("pulse_tank_glow", (kx, ky, kz + 0.9), local=True)
    tk.cyl(0.44, 0.6, (0, 0, 0), "7CF07A", sides=10)
    for (dx, dy, dz, r) in ((0.15, 0.1, 0.4, 0.12), (-0.2, 0.0, 0.52, 0.09), (0.0, -0.2, 0.62, 0.07)):
        tk.ball(r, (dx, dy, dz), "B9FFB0", subdiv=1)
    # --- Antennen auf dem Dach
    ax, ay = H.x1 - 0.55, H.y1 - 0.6
    B.box((0.5, 0.5, 0.3), (ax, ay, H.top + 0.34), STEEL_D)
    B.cyl(0.05, 1.3, (ax, ay, H.top + 1.1), STEEL_L, sides=6)
    sp = M.origin("spin_antenne", (ax, ay, H.top + 1.8), local=True)
    sp.box((1.0, 0.06, 0.06), (0, 0, 0), STEEL_D)
    for sx in (-1, 1):
        sp.box((0.06, 0.4, 0.3), (sx * 0.5, 0, 0), "2FA6A0")
    sp.cyl(0.1, 0.14, (0, 0, 0), GOLD, sides=6)
    B.cyl(0.025, 2.0, (H.x1 - 0.35, H.y0 + 0.4, H.top + 1.2), STEEL_L, sides=4)
    for z in (1.4, 1.75, 2.1):
        B.box((0.5 - (z - 1.4) * 0.4, 0.03, 0.03), (H.x1 - 0.35, H.y0 + 0.4, H.top + z), STEEL_D)
    pl_ = M.origin("pulse_spitze_glow", (H.x1 - 0.35, H.y0 + 0.4, H.top + 2.26), local=True)
    pl_.ball(0.08, (0, 0, 0), PURPLE, subdiv=1)
    # --- Dampfventil und Rohre (rechts), Gasflaschen
    vx, vy = H.x1 + 0.4, H.y0 + 2.8
    pipe(B, [(H.x1 + 0.05, vy, 0.7), (vx, vy, 0.7), (vx, vy, 2.85), (vx, vy - 1.3, 2.85), (H.x1 + 0.05, vy - 1.3, 2.85)], 0.09, "2FA6A0")
    B.cyl(0.16, 0.2, (vx, vy, 1.5), STEEL_D, sides=8)
    B.cyl(0.07, 0.3, (vx + 0.2, vy, 1.5), STEEL_D, r=rot(0, 90, 0), sides=6)
    M.empty("fx_steam", (vx + 0.42, vy, 1.55))
    vr = M.origin("spin_ventil", (vx, vy - 0.22, 1.5), (math.radians(90), 0, 0), local=True)
    vr.torus(0.17, 0.03, (0, 0, 0), RED, seg=10, tseg=4)
    for i in range(2):
        vr.box((0.34, 0.04, 0.03), (0, 0, 0), RED, r=rot(0, 0, i * 90))
    for i, c in enumerate(("5E7FB5", "3C8A6A", "C9463E")):
        B.cyl(0.16, 1.2, (H.x1 + 0.3 + i * 0.3, H.y0 + 0.25, 0.85), c, sides=8)
        B.cyl(0.06, 0.16, (H.x1 + 0.3 + i * 0.3, H.y0 + 0.25, 1.52), STEEL_L, sides=6)
    B.box((0.95, 0.08, 0.08), (H.x1 + 0.6, H.y0 + 0.05, 1.0), STEEL_D)
    # --- Kisten mit Warnzeichen, Fässer
    warnkiste(B, (1.3, -1.6, 0.25), 0.75, 8); warnkiste(B, (2.15, -1.75, 0.25), 0.62, -14)
    warnkiste(B, (1.35, -1.62, 1.0), 0.55, 24, color="E6E0D2")
    barrel(B, (-2.3, -1.3, 0.25), "7CC06A", 0.3, 0.85); barrel(B, (-2.2, -2.0, 0.25), "E0A21E", 0.3, 0.85)
    fleck(B, -1.8, -1.75, 0.25, 0.4, "7CC06A")                                             # ausgelaufene Brühe
    lampe(B, L, F, 2.0, 2.6)
    sb = schild(B, F, 1.1, 2.95 - 0.0, 0.5, 0.26, "2FA6A0", "E6E0D2")
    sb.cyl(0.09, 0.03, (0, 0, 0), "E6E0D2", r=rot(90, 0, 0), sides=8)
    # --- Stufe 4: Gold, zweite Kuppelleuchte, Messmast
    X4 = M["lv4_ausbau"]
    X4.torus(kr + 0.1, 0.06, (kx, ky, kz + 0.34), GOLD, seg=12, tseg=4)
    X4.box((0.6, 0.6, 0.1), (ax, ay, H.top + 0.54), GOLD)
    warnkiste(X4, (2.2, -0.9, 0.25), 0.7, 5)
    X4.cyl(0.3, 1.0, (-2.25, 0.0 - 0.4, 0.75), "E6E0D2", sides=10)                         # Stickstofftank
    X4.cyl(0.3, 0.2, (-2.25, -0.4, 1.35), "E6E0D2", r2=0.12, sides=10)
    X4.cyl(0.32, 0.08, (-2.25, -0.4, 0.8), "2FA6A0", sides=10)
    fahne(M, X4, (2.5, 2.4, 0.25), 3.4, size=(0.8, 0.56), yaw=180)
    moos(B, H.W("b"), 2.0, 4, 1.5)
    d1, d2 = schaden_std(M, H, holz=False)
    riss(d1, F, 2.2, 0.5, 1.2)
    warnkiste(d2, (0.3, -2.0, 0.25), 0.5, 40, color=RUST)
    M.empty("fx_smoke_dmg", (kx + 0.8, ky, kz + 1.2))
    M.punkte(door=(H.x0 + 1.1, H.y0 - 0.55), work_1=(vx + 0.2, vy - 0.9), work_2=(0.8, -1.3), drop=(0.2, -1.6), bubble=(-0.3, 0.6, 6.3))
    M.finish()


MODELS["b_labor"] = labor


# ================================================================== Schildgenerator (3x3, Verteidigung, drei Ausbau-Aussehen)
def schildgen():
    M = Model("b_schild", 5.6, 5.6)
    B, G, L = M["body"], M["win_glow"], M["lamp_glow"]
    H = Haus(0.0, 0.5, 3.4, 3.0, 0.25, 3.0)
    hof(M, 5.5, 5.5, 0.0, color="C4C6CC", skip=[(H.x0 + 0.1, H.y0 + 0.1, H.x1 - 0.1, H.y1 - 0.1)])
    H.kern(B)
    F, Rw = H.W("f"), H.W("r")
    hd = tuer(B, F, H.w / 2, 0.0, 1.4, 2.6, color="5E7FB5", frame=DK, knob=GOLD, luke=True)
    schwelle(B, F, H.w / 2)
    hr = fenster(B, G, Rw, 1.5, 1.5, 1.2, 0.6, frame=DK, glow=CYAN, kreuz=False)
    hl = [fenster(B, G, F, u, 1.6, 0.36, 0.7, frame=DK, glow=CYAN, kreuz=False, bank=False) for u in (0.5, H.w - 0.5)]
    holes = {"f": [hd] + hl, "r": [hr]}
    sockel(B, H, holes, shade(CONC_D, 0.8), v1=0.5)
    for s in "fr":
        warnstreifen(B, H.W(s), 0.0, H.W(s).len, 0.5, 0.7, 0.16) if s == "r" else None
    W1 = M["lvmax3_haus"]
    wandsatz(W1, H, "bretter", holes, v0=0.5 if True else 0.7)
    for (x0, y0, dx, dy, n) in ((H.x1 + 0.3, H.y0 - 0.1, 0, 1, 4), (H.x0 - 0.3, H.y0 - 0.1, 0, 1, 4)):
        sandbags(W1, (x0, y0, 0.25), dx, dy, n, 2)
    W4 = M["lv4_haus"]
    wandsatz(W4, H, "stein", holes, v0=0.5)
    for sx in (-1, 1):                                                                 # Strebepfeiler
        for y in (H.y0 + 0.5, H.y1 - 0.5):
            W4.box((0.5, 0.6, 1.6), (sx * (H.w / 2 + 0.2), y, 1.05), ST_D, bevel=0.05, segs=1)
            W4.box((0.4, 0.5, 0.9), (sx * (H.w / 2 + 0.12), y, 2.2), ST, r=rot(0, sx * -12, 0))
    W7 = M["lv7_haus"]
    for s in "frbl":
        clad(W7, H.W(s), "panel", "6F8FD0", v0=0.5, holes=holes.get(s, ()), out=0.16, size=1.1)
        tile(W7, H.W(s), 0.0, H.h - 0.22, H.W(s).len, H.h - 0.04, 0.2, 0.08, GOLD)
        tile(W7, H.W(s), 0.0, 0.5, H.W(s).len, 0.64, 0.2, 0.08, GOLD)
    ecken(W7, H, BLUE_D, 0.36, 0.2)
    # --- Flachdach mit Brüstung und Zinnen
    B.box((H.w + 0.4, H.d + 0.4, 0.24), (H.cx, H.cy, H.top + 0.06), CONC_D, bevel=0.04, segs=1)
    pl = boden(H.x0, H.y0, H.top + 0.18)
    for i in range(4):
        for j in range(4):
            tile(B, pl, i * 0.85 + 0.02, j * 0.75 + 0.02, (i + 1) * 0.85 - 0.02, (j + 1) * 0.75 - 0.02, 0.03, 0.03, jit("AEB4BE", 0.05))
    for s in "frbl":
        w = H.W(s)
        n = 5
        for i in range(n):
            if i % 2 == 0:
                At(B, w.M((i + 0.5) * w.len / n, H.h + 0.18, 0.16)).box((w.len / n + 0.06, 0.18, 0.4), (0, 0.09, 0.2), jit("C9CED6", 0.05))
            else:
                At(B, w.M((i + 0.5) * w.len / n, H.h + 0.18, 0.16)).box((w.len / n, 0.14, 0.16), (0, 0.09, 0.08), "9EA3AD")
    tube(B, (H.x0 - 0.1, H.y0 - 0.24, H.top - 0.02), (H.x1 + 0.1, H.y0 - 0.24, H.top - 0.02), 0.07, STEEL_D, 6)      # Dachrinne
    tube(B, (H.x1 - 0.12, H.y0 - 0.2, H.top - 0.05), (H.x1 - 0.12, H.y0 - 0.2, 0.25), 0.055, STEEL_D, 6)
    flicken(B, pl, 0.6, 0.5, 0.6, 0.45, RUST, out=0.07)
    # --- Emitter: Sockel, drei Klauen, pulsierender Kern, drehende Ringe
    ez = H.top + 0.2
    B.cyl(1.0, 0.4, (0, H.cy, ez + 0.2), DK, sides=10, r2=0.85)
    B.cyl(0.6, 0.5, (0, H.cy, ez + 0.6), "5E7FB5", sides=10, r2=0.4)
    for i in range(10):
        a = 2 * math.pi * i / 10
        stud(B, boden(math.cos(a) * 0.88, H.cy + math.sin(a) * 0.88, ez + 0.4), 0, 0, 0.0, 0.05, STEEL_L)
    kz = ez + 2.1
    for i in range(3):                                                                 # Klauen
        a = math.radians(90 + i * 120)
        cx_, sy_ = math.cos(a), math.sin(a)
        pts = [(cx_ * 0.55, H.cy + sy_ * 0.55, ez + 0.6), (cx_ * 1.15, H.cy + sy_ * 1.15, ez + 1.4), (cx_ * 1.2, H.cy + sy_ * 1.2, kz + 0.2), (cx_ * 0.75, H.cy + sy_ * 0.75, kz + 0.95)]
        for k in range(3):
            beam(B, pts[k], pts[k + 1], 0.2 - k * 0.03, "5E7FB5" if k < 2 else GOLD_D)
        B.ball(0.14, pts[1], STEEL_D, subdiv=1); B.ball(0.13, pts[2], STEEL_D, subdiv=1)
        M["lv7_gold"].ball(0.13, pts[3], GOLD, subdiv=1)
    kern = M.origin("pulse_kern_glow", (0, H.cy, kz), local=True)
    kern.ball(0.62, (0, 0, 0), CYAN, subdiv=2)
    r1 = M.origin("spin_ring", (0, H.cy, kz), local=True)
    r1.torus(0.98, 0.07, (0, 0, 0), GOLD, r=rot(18, 0, 0), seg=16, tseg=5)
    for i in range(4):
        a = math.radians(i * 90)
        r1.box((0.2, 0.14, 0.2), (math.cos(a) * 0.98, math.sin(a) * 0.98 * math.cos(math.radians(18)), math.sin(a) * 0.98 * math.sin(math.radians(18))), "5E7FB5")
    r2 = M.origin("spin_ring2_glow", (0, H.cy, kz), (0, 0, 0), local=True)
    r2.torus(0.8, 0.035, (0, 0, 0), "BFF4FF", r=rot(-35, 20, 0), seg=14, tseg=4)
    M.empty("fx_spark", (0, H.cy, kz + 0.2))
    # --- zwei Spulenmasten vorn, Kabel zum Emitter, Schaltpult
    for i, sx in enumerate((-1, 1)):
        x, y = sx * 2.15, -1.75
        B.cyl(0.36, 0.25, (x, y, 0.37), DK, sides=8)
        B.cyl(0.13, 2.2, (x, y, 1.5), STEEL, sides=8)
        for k in range(6):
            B.torus(0.2, 0.06, (x, y, 0.8 + k * 0.2), "D9912B", seg=8, tseg=4)
        B.cyl(0.24, 0.1, (x, y, 2.6), STEEL_D, sides=8)
        pc = M.origin("pulse_spule%s_glow" % ("" if i == 0 else "2"), (x, y, 2.9), local=True)
        pc.ball(0.22, (0, 0, 0), CYAN, subdiv=1)
        kabel(B, (x, y, 2.55), (sx * 1.0, H.cy - 0.5, ez + 0.5), 0.5, 0.035)
        warnstreifen(B, wand((x - 0.25, y - 0.37), (x + 0.25, y - 0.37), 0.27), 0, 0.5, 0, 0.18, 0.0, 3)
    a = At(B, T(1.25, -1.55, 0.25) @ rot(0, 0, -20))
    a.box((0.7, 0.45, 0.9), (0, 0, 0.45), "5E7FB5", bevel=0.04, segs=1)
    a.box((0.72, 0.5, 0.1), (0, -0.04, 0.95), DK, r=rot(20, 0, 0))
    ag = At(M["panel_glow"], T(1.25, -1.55, 0.25) @ rot(0, 0, -20))
    for i, c in enumerate(("5FE38A", CYAN, HOT)):
        ag.box((0.12, 0.1, 0.04), (-0.2 + i * 0.2, -0.08, 1.02), c, r=rot(20, 0, 0))
    lampe(B, L, F, H.w / 2 + 1.15, 2.55, arm=0.25)
    wappen(B, F.M(H.w / 2, 2.6 + 0.62 - 0.25, 0.12), 0.5)
    crate(B, (-2.3, 0.6, 0.25), 0.6, OLIVE); barrel(B, (-2.3, 1.5, 0.25), "5E7FB5", 0.3, 0.8)
    X4 = M["lv4_ausbau"]
    sandbags(X4, (0.9, -2.45, 0.25), 1, 0, 3, 2); sandbags(X4, (-2.1, -2.45, 0.25), 1, 0, 3, 2)
    X4.box((0.5, 0.5, 0.5), (2.3, 1.6, 0.5), STEEL_D); X4.cyl(0.05, 1.8, (2.3, 1.6, 1.6), STEEL_L, sides=4)      # Messmast
    M["lv4_mast_glow"].ball(0.09, (2.3, 1.6, 2.55), HOT, subdiv=1)
    X7 = M["lv7_gold"]
    X7.torus(1.02, 0.06, (0, H.cy, ez + 0.42), GOLD, seg=12, tseg=4)
    X7.cyl(0.42, 0.1, (0, H.cy, ez + 0.88), GOLD, sides=10)
    for sx in (-1, 1):
        X7.cyl(0.27, 0.08, (sx * 2.15, -1.75, 2.68), GOLD, sides=8)
    fahne(M, X7, (H.x0 + 0.3, H.y1 - 0.3, H.top + 0.2), 2.2, size=(0.8, 0.56))
    fleck(B, 0.5, -1.9, 0.25, 0.4, "2B2A30"); moos(B, H.W("b"), 1.5, 4, 1.5)
    brett_quer(W1, Rw, 0.5, 1.0, 0.7, 0.2, 11)
    d1, d2 = schaden_std(M, H, holz=False)
    riss(d1, F, 0.9, 0.6, 1.3)
    kabel(d2, (2.15, -1.75, 2.5), (1.6, -1.2, 0.3), 0.0, 0.035, n=2)
    M.empty("fx_smoke_dmg", (0.6, H.cy, ez + 0.8))
    M.punkte(door=(0.0, H.y0 - 0.6), work_1=(1.05, -2.1), work_2=(-1.6, -1.3), drop=(-0.9, -1.8), bubble=(0.0, 0.3, 7.3))
    M.finish()


MODELS["b_schild"] = schildgen


# ================================================================== Trainingsplatz (3x3)
def puppe(p, m, holz=WOOD_D):
    a = At(p, m)
    a.cyl(0.07, 1.5, (0, 0, 0.75), holz, sides=6)
    a.cyl(0.3, 0.75, (0, 0, 1.2), "D9B37A", sides=9)
    a.cyl(0.31, 0.1, (0, 0, 1.2), "8A5030", sides=9)
    a.ball(0.24, (0, 0, 1.82), "E6D2A4", subdiv=2)
    a.box((1.3, 0.11, 0.11), (0, 0, 1.38), jit(WOOD, 0.06))
    a.cyl(0.26, 0.06, (0, -0.3, 1.2), RED, r=rot(90, 0, 0), sides=10)
    a.cyl(0.14, 0.07, (0, -0.31, 1.2), "white", r=rot(90, 0, 0), sides=10)
    a.cyl(0.26, 0.12, (0, 0, 1.98), "5E7FB5", sides=8, r2=0.2)                              # Helm


def training():
    M = Model("b_training", 5.6, 5.6, looks=2)
    B, G, L = M["body"], M["win_glow"], M["lamp_glow"]
    H = Haus(-1.35, 1.58, 2.3, 1.7, 0.25, 2.8)
    y0 = hof(M, 5.5, 5.5, 0.6, skip=[(H.x0 + 0.1, H.y0 + 0.1, H.x1 - 0.1, H.y1 - 0.1), (-2.2, -2.0, 2.2, 0.6), (-0.2, 0.6, 2.2, 2.2)])
    B.box((4.4, 2.6, 0.1), (0.0, -0.7, 0.25), "E9D49A")                                    # Sandplatz
    B.box((2.4, 1.6, 0.1), (1.0, 1.4, 0.25), "E9D49A")
    for (x, y, r) in ((-1.2, -1.2, 0.5), (0.9, -0.2, 0.6), (1.4, 1.3, 0.45)):
        fleck(B, x, y, 0.3, r, "DCC384")
    H.kern(B)
    F, Rw = H.W("f"), H.W("r")
    hd = tuer(B, F, 0.9, 0.0, 1.3, 2.45, color="5E7FB5", frame=CREAM)
    hr = fenster(B, G, Rw, 0.85, 1.25, 0.7, 0.9)
    holes = {"f": [hd], "r": [hr]}
    sockel(B, H, holes)
    wandsatz(M["lvmax3_huette"], H, "bretter", holes)
    wandsatz(M["lv4_huette"], H, "stein", holes)
    R = dach(B, (H.cx, H.cy, H.top), H.w, H.d, 0.9, BLUE, over=0.22, over_g=0.2, ground=0.25, fallrohr=False, tw=0.46, row=0.42)
    giebelfeld(B, H, 0.9, "plank_h", WOOD_L)
    flicken(B, R.planes[0], 0.7, 0.6, 0.5, 0.42, WOOD_P)
    px, py, pz = dach_pos(R, 0.5, 0.3)
    B.cyl(0.1, 0.7, (px, py, pz + 0.2), STEEL_D, sides=6)
    B.cyl(0.16, 0.1, (px, py, pz + 0.55), DK, sides=6)
    M.empty("fx_smoke", (px, py, pz + 0.75))
    lampe(B, L, F, 1.9, 2.25, arm=0.22)
    sb = schild(B, F, 0.9, 2.72, 0.5, 0.3, "F4F6FA", RED)                                  # Schild: Zielscheibe
    sb.cyl(0.11, 0.03, (0, 0, 0), RED, r=rot(90, 0, 0), sides=8)
    # --- Zaun rundum, vorn offen
    zaun(B, (-2.6, -2.3), (-2.6, 0.55), 0.25, 0.95)
    zaun(B, (2.6, -2.3), (2.6, 2.6), 0.25, 0.95)
    zaun(B, (1.0, 2.6), (2.6, 2.6), 0.25, 0.95, n=2)
    zaun(B, (-2.6, -2.3), (-0.5, -2.3), 0.25, 0.95)
    zaun(B, (1.7, -2.3), (2.6, -2.3), 0.25, 0.95, n=1)
    # --- drehende Übungspuppe und feste Puppe
    B.cyl(0.34, 0.14, (0.9, -0.3, 0.32), ST_D, sides=10)
    sp = M.origin("spin_puppe", (0.9, -0.3, 0.38), local=True)
    puppe(sp, I4)
    sp.box((0.1, 0.5, 0.1), (0.6, -0.2, 1.38), WOOD_L)
    sp.ball(0.14, (0.6, -0.45, 1.38), SACK, subdiv=1)
    M.empty("fx_smoke_staub", (0.9, -0.3, 0.4))
    puppe(B, T(-1.3, -1.25, 0.28) @ rot(0, 0, 25))
    beam(B, (-1.3, -1.25, 0.3), (-1.7, -0.9, 0.3), 0.1, WOOD_D); beam(B, (-1.3, -1.25, 0.3), (-0.9, -1.6, 0.3), 0.1, WOOD_D)
    # --- Zielscheibe auf Gestell (hinten Mitte), Pfeile
    tx, ty = 0.55, 2.2
    for sx in (-0.4, 0.4):
        beam(B, (tx + sx, ty + 0.3, 0.25), (tx + sx * 0.5, ty, 1.9), 0.08, WOOD_D)
    beam(B, (tx, ty + 0.55, 0.25), (tx, ty + 0.05, 1.7), 0.08, WOOD_D)
    a = At(B, T(tx, ty - 0.08, 1.4) @ rot(-12, 0, 0))
    for (r, c, o) in ((0.6, "F4F6FA", 0.0), (0.46, RED, 0.02), (0.32, "F4F6FA", 0.04), (0.18, RED, 0.06), (0.07, GOLD, 0.08)):
        a.cyl(r, 0.08, (0, -o, 0), c, r=rot(90, 0, 0), sides=14)
    for (dx, dz) in ((0.1, 0.12), (-0.22, -0.08)):
        a.cyl(0.015, 0.5, (dx, -0.33, dz), WOOD_L, r=rot(90, 0, 0), sides=4)
        a.box((0.1, 0.1, 0.02), (dx, -0.56, dz), RED)
    # --- Boxsack am Galgen (wiegt sich)
    gx, gy = 2.0, 0.9
    B.box((0.18, 0.18, 2.9), (gx + 0.3, gy + 0.9, 1.7), WOOD_D)
    beam(B, (gx + 0.3, gy + 0.9, 3.05), (gx - 0.4, gy - 0.1, 3.05), 0.14, WOOD_D)
    beam(B, (gx + 0.3, gy + 0.9, 2.3), (gx - 0.05, gy + 0.4, 3.0), 0.09, WOOD)
    bs = M.origin("sway_sack", (gx - 0.3, gy + 0.05, 2.98), local=True)
    bs.cyl(0.02, 0.6, (0, 0, -0.3), "22252E", sides=4)
    bs.cyl(0.28, 1.1, (0, 0, -1.15), "C9463E", sides=10)
    bs.cyl(0.29, 0.1, (0, 0, -0.85), "8A2A2A", sides=10); bs.cyl(0.29, 0.1, (0, 0, -1.45), "8A2A2A", sides=10)
    # --- Hantelständer, Hantelbank, Reifen-Parcours, Hürde
    wx, wy = -0.2 + 0.4, 0.9
    a = At(B, T(H.x1 + 0.55, H.y0 + 0.35, 0.25))
    a.box((0.9, 0.36, 0.08), (0, 0, 0.5), STEEL_D); a.box((0.9, 0.36, 0.08), (0, 0, 0.95), STEEL_D)
    for sx in (-0.42, 0.42):
        a.box((0.07, 0.36, 1.1), (sx, 0, 0.55), STEEL_D)
    for i, c in enumerate((RED, "5E7FB5", GOLD)):
        for z in (0.62, 1.07):
            a.cyl(0.035, 0.3, (-0.27 + i * 0.27, 0, z), DK, r=rot(90, 0, 0), sides=5)
            for sy in (-1, 1):
                a.cyl(0.11, 0.08, (-0.27 + i * 0.27, sy * 0.16, z), c, r=rot(90, 0, 0), sides=8)
    B.cyl(0.03, 1.5, (-0.6, -0.35, 0.56), STEEL_L, r=rot(0, 90, 0), sides=5)                    # Langhantel am Boden
    for sx in (-1, 1):
        B.cyl(0.26, 0.1, (-0.6 + sx * 0.66, -0.35, 0.56), DK, r=rot(0, 90, 0), sides=10)
        B.cyl(0.18, 0.12, (-0.6 + sx * 0.56, -0.35, 0.56), RED, r=rot(0, 90, 0), sides=10)
    for i in range(4):
        B.torus(0.25, 0.1, (0.3 + (i % 2) * 0.55, -1.2 - (i // 2) * 0.55, 0.4), "tire", seg=10, tseg=5)
    for sx in (-0.5, 0.5):
        B.box((0.08, 0.3, 0.7), (1.9 + sx, -1.6, 0.6), WOOD_D)
    B.box((1.1, 0.07, 0.1), (1.9, -1.6, 0.92), "F4F6FA"); B.box((0.3, 0.075, 0.105), (1.9, -1.6, 0.92), RED)
    fahne(M, B, (-2.6, -2.3, 0.25), 3.3, size=(0.85, 0.6))
    crate(B, (H.x0 + 0.1 - 0.4 + 0.5, H.y0 - 0.45, 0.25), 0.5, WOOD_L, 12)
    # --- Stufe 4: Siegerpodest mit Pokal, zweite Zielscheibe, Kletterwand
    X4 = M["lv4_ausbau"]
    for (dx, h) in ((0.0, 0.5), (-0.5, 0.34), (0.5, 0.22)):
        X4.box((0.5, 0.5, h), (-1.9 + dx * 1.0, -0.2, 0.25 + h / 2), ("F4F6FA", "C9D0DE", "D9A05A")[int(abs(dx) * 2) if dx <= 0 else 2])
    X4.cyl(0.1, 0.1, (-1.9, -0.2, 0.8), GOLD, sides=6); X4.cyl(0.05, 0.16, (-1.9, -0.2, 0.92), GOLD, sides=6)
    X4.cyl(0.1, 0.22, (-1.9, -0.2, 1.1), GOLD, r2=0.17, sides=8)
    a = At(X4, T(2.45, -0.6, 1.35) @ rot(0, 0, -90) @ rot(-8, 0, 0))
    for (r, c, o) in ((0.42, "F4F6FA", 0.0), (0.3, "5E7FB5", 0.02), (0.16, RED, 0.04)):
        a.cyl(r, 0.07, (0, -o, 0), c, r=rot(90, 0, 0), sides=12)
    X4.box((0.1, 0.1, 1.1), (2.52, -0.6, 0.8), WOOD_D)
    X4.cyl(0.14, H.w + 0.4, (H.cx, H.cy, H.top + 1.02), GOLD, r=rot(0, 90, 0), sides=6)
    for (x, y) in ((H.x0, H.y0), (H.x1, H.y0)):
        X4.box((0.32, 0.32, 0.12), (x, y, H.z0 + 2.6), GOLD)
    moos(B, H.W("b"), 1.0, 3, 0.8, out=0.02); brett_quer(M["lvmax3_huette"], Rw, 1.35, 0.8, 0.5, 0.17, 10)
    d1, d2 = schaden_std(M, H)
    for i in range(3):
        d2.box((0.8, 0.12, 0.08), (2.55, -1.2 + i * 0.6, 0.5 + i * 0.1), jit(WOOD_L), r=rot(0, 30 - i * 25, 80))
    M.empty("fx_smoke_dmg", (H.cx, H.cy, H.top + 0.7))
    M.punkte(door=(H.x0 + 0.9, H.y0 - 0.5), work_1=(0.9, -1.1, 0.3), work_2=(gx - 0.3, gy - 0.7, 0.3), drop=(-0.3, 0.3, 0.3), bubble=(0.0, 0.0, 4.8))
    M.finish()


MODELS["b_training"] = training
