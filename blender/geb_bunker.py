"""Rustwall – Bunker in fünf Ausbau-Modellen (b_bunker_1 … b_bunker_5) nach dem Detail-Katalog (Auftrag V3, Kapitel 6).
Modell k gilt für Bunkerstufe 2k-1 und 2k: vom befestigten Betonbau zum goldverzierten Hauptquartier.
Teile mit dem Namen lv<2k>_* erscheinen erst auf der geraden Stufe (kleiner Zwischenausbau). Vorderseite = -Y."""
import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from geb_kit import *


def zinnen(p, H, n_f=7, n_s=5, color="C9CED6", h=0.42, sides="frbl", low="9EA3AD"):
    """Brüstung mit Zinnen auf der Mauerkrone."""
    for s in sides:
        w = H.W(s)
        n = n_f if s in "fb" else n_s
        for i in range(n):
            a = At(p, w.M((i + 0.5) * w.len / n, H.h + 0.2, 0.2))
            if i % 2 == 0:
                a.box((w.len / n + 0.06, 0.24, h), (0, 0.12, h / 2), jit(color, 0.05), bevel=0.03, segs=1)
            else:
                a.box((w.len / n, 0.2, h * 0.45), (0, 0.12, h * 0.22), low)


def rundturm(p, g, x, y, z0, h, r, stone, light, roof, tip, band=None):
    n = 12
    rings = max(3, round(h / 0.5))
    for k in range(rings):
        rr = r * (1.06 if k == 0 else 1.0)
        p.cyl(rr, h / rings - 0.03, (x, y, z0 + (k + 0.5) * h / rings), jit(stone if k % 2 else light, 0.05), sides=n, r=rot(0, 0, 15 * (k % 2)))
    p.cyl(r + 0.14, 0.26, (x, y, z0 + h + 0.05), band or shade(stone, 0.8), sides=n)
    for i in range(6):                                                                 # Zinnenkranz
        a = 2 * math.pi * i / 6
        p.box((0.36, 0.2, 0.3), (x + math.cos(a) * (r + 0.02), y + math.sin(a) * (r + 0.02), z0 + h + 0.3), light, r=rot(0, 0, math.degrees(a) + 90))
    p.cone(r + 0.02, r * 1.5, (x, y, z0 + h + 0.18 + r * 0.75), roof, sides=n)
    p.cyl(r + 0.06, 0.08, (x, y, z0 + h + 0.2), shade(roof, 0.75), sides=n)
    p.ball(0.13, (x, y, z0 + h + 0.2 + r * 1.5), tip, subdiv=1)
    sx = 1 if x > 0 else -1
    for (dz) in (h * 0.45, h * 0.78):                                                  # Schießscharten
        g.box((0.14, 0.06, 0.5), (x, y - r - 0.01, z0 + dz), GLOW)
        p.box((0.26, 0.08, 0.62), (x, y - r + 0.01, z0 + dz), DK)
        g.box((0.06, 0.14, 0.5), (x + sx * (r + 0.01), y, z0 + dz), GLOW)
        p.box((0.08, 0.26, 0.62), (x + sx * (r - 0.01), y, z0 + dz), DK)


def panzertor(p, pl, u, w, h, color, frame, niet, gold=None, warn=True):
    """Gepanzertes Doppeltor mit Nieten und Riegeln. Liefert die Aussparung."""
    a = At(p, pl.M(u, 0, 0))
    a.box((w, 0.12, h), (0, 0.0, h / 2), shade(color, 0.5))
    for sx in (-1, 1):
        tile(p, pl, u + (sx - 1) * w / 4 + 0.02 + (0 if sx < 0 else w / 2 - w / 2), 0.03, u + (sx + 1) * w / 4 - 0.02, h - 0.03, 0.09, 0.05, color) if False else None
        x0, x1 = (u - w / 2 + 0.02, u - 0.03) if sx < 0 else (u + 0.03, u + w / 2 - 0.02)
        tile(p, pl, x0, 0.03, x1, h - 0.03, 0.09, 0.05, jit(color, 0.04))
        for z in (0.45, h / 2, h - 0.45):
            tile(p, pl, x0 + 0.04, z - 0.1, x1 - 0.04, z + 0.1, 0.13, 0.04, shade(color, 0.72))
            for k in (0.2, 0.5, 0.8):
                stud(p, pl, x0 + (x1 - x0) * k, z, 0.13, 0.04, niet)
        a.box((0.08, 0.06, 0.5), (sx * 0.16, -0.13, h * 0.45), gold or niet)
    fw = 0.24
    for sx in (-1, 1):
        a.box((fw, 0.36, h + fw), (sx * (w / 2 + fw / 2), -0.08, (h + fw) / 2), frame)
        if warn:
            warnstreifen(p, pl, u + sx * (w / 2 + fw / 2) - fw / 2, u + sx * (w / 2 + fw / 2) + fw / 2, 0.0, 1.1, 0.27, 2)
    a.box((w + fw * 2 + 0.16, 0.42, fw + 0.06), (0, -0.08, h + fw / 2 + 0.03), gold or frame, bevel=0.03, segs=1)
    return (u - w / 2 - fw, 0.0, u + w / 2 + fw, h + fw + 0.06)


def scharte(p, g, pl, u, v, w=0.9, h=0.34, frame=DK):
    """Sehschlitz (leuchtet)."""
    At(g, pl.M(u, v, 0)).box((w, 0.06, h), (0, -0.04, h / 2), GLOW)
    a = At(p, pl.M(u, v, 0))
    a.box((w + 0.24, 0.24, 0.12), (0, -0.08, h + 0.06), frame)
    a.box((w + 0.24, 0.3, 0.1), (0, -0.1, -0.05), frame)
    for sx in (-1, 1):
        a.box((0.12, 0.24, h + 0.2), (sx * (w / 2 + 0.06), -0.08, h / 2), frame)
    a.box((0.06, 0.1, h), (0, -0.08, h / 2), frame)
    return (u - w / 2 - 0.12, v - 0.1, u + w / 2 + 0.12, v + h + 0.12)


def scheinwerfer(M, p, loc, yaw=0.0):
    """Suchscheinwerfer (schwenkt): Gabel fest, Lampe als sway-Objekt."""
    x, y, z = loc
    p.cyl(0.2, 0.14, (x, y, z + 0.07), DK, sides=8)
    p.cyl(0.06, 0.5, (x, y, z + 0.35), STEEL_D, sides=6)
    sw = M.origin("sway_scheinwerfer", (x, y, z + 0.62), (0, 0, math.radians(yaw)), local=True)
    for sx in (-1, 1):
        sw.box((0.05, 0.08, 0.5), (sx * 0.3, 0, 0.2), STEEL_D)
    sw.box((0.66, 0.08, 0.06), (0, 0, -0.03), STEEL_D)
    a = At(sw, T(0, 0, 0.32) @ rot(-14, 0, 0))
    a.cyl(0.26, 0.42, (0, 0, 0), "3F4654", r=rot(90, 0, 0), sides=10)
    a.cyl(0.29, 0.06, (0, -0.2, 0), STEEL_L, r=rot(90, 0, 0), sides=10)
    a.cyl(0.23, 0.03, (0, -0.235, 0), "FFF3B0", r=rot(90, 0, 0), sides=10)
    a.cyl(0.14, 0.12, (0, 0.25, 0), DK, r=rot(90, 0, 0), sides=8)


def schuessel(M, p, loc, r=0.62, name="spin_schuessel"):
    x, y, z = loc
    p.box((0.5, 0.5, 0.22), (x, y, z + 0.11), DK)
    p.cyl(0.07, 0.5, (x, y, z + 0.45), STEEL_D, sides=6)
    sp = M.origin(name, (x, y, z + 0.72), local=True)
    sp.cyl(0.1, 0.12, (0, 0, 0), STEEL_D, sides=6)
    d = At(sp, T(0, 0, 0.3) @ rot(55, 0, 0))
    d.cyl(r, 0.24, (0, 0, 0), "F4F6FA", r2=0.16, sides=12, r=rot(180, 0, 0))
    d.cyl(r * 0.92, 0.02, (0, 0, 0.125), "C9D0DE", sides=12)
    d.cyl(0.025, r * 0.8, (0, 0, r * 0.4), STEEL_D, sides=4)
    d.ball(0.07, (0, 0, r * 0.8), RED, subdiv=1)


def munkiste(p, loc, yaw=0.0, color="6E8F4E"):
    a = At(p, T(*loc) @ rot(0, 0, yaw))
    a.box((0.8, 0.45, 0.36), (0, 0, 0.18), color)
    a.box((0.84, 0.49, 0.08), (0, 0, 0.36), shade(color, 0.8))
    for sx in (-0.3, 0.3):
        a.box((0.06, 0.5, 0.38), (sx, 0, 0.19), DK)
    a.box((0.2, 0.03, 0.1), (0, -0.24, 0.2), GOLD)


def bunker(stage):
    name = "b_bunker_%d" % stage
    M = Model(name, 7.6, 7.6, tri_max=18000)
    B, G, L = M["body"], M["win_glow"], M["lamp_glow"]
    W, D = ((5.2, 4.0), (5.6, 4.2), (5.8, 4.2), (5.4, 4.0), (5.4, 4.0))[stage - 1]
    H = Haus(0.0, 0.75, W, D, 0.45, 3.4)
    gold = stage >= 4
    # Farben je Ausbau
    wall_c = ("B9BDC4", "B9BDC4", ST, ST, "D6DCEC")[stage - 1]
    wall_l = ("CDD1D8", "CDD1D8", ST_L, ST_L, "EEF1F8")[stage - 1]
    trim = (DK, BLUE_D, BLUE, BLUE, BLUE)[stage - 1]
    band = (None, BLUE, BLUE, GOLD, GOLD)[stage - 1]
    style = "beton" if stage <= 2 else "stein"
    # --- Fundament, Podest, Treppe
    fundament(B, 7.4, 7.12, 0.25, (0, 0.14), color="C4C6CC" if stage <= 2 else PAVE, skip=[(H.x0 - 0.3, H.y0 - 0.3, H.x1 + 0.3, H.y1 + 0.2)])
    B.box((W + 0.9, D + 0.8, 0.22), (0, H.cy - 0.05, 0.36), ST_D, bevel=0.04, segs=1)
    pl = boden(-W / 2 - 0.45, H.y0 - 0.45, 0.47)
    n = 8
    for i in range(n):
        tile(B, pl, i * (W + 0.9) / n + 0.02, 0.02, (i + 1) * (W + 0.9) / n - 0.02, 0.43, 0.0, 0.03, jit(wall_l, 0.05))
    B.box((3.4, 0.45, 0.3), (0, H.y0 - 0.66, 0.15), ST_L, bevel=0.02, segs=1)
    stufe(B, 0.0, H.y0 - 1.05, 3.8, 0.4, 0.15)
    H.kern(B)
    F, Rw, Lw, Bk = H.W("f"), H.W("r"), H.W("l"), H.W("b")
    # --- gepanzertes Doppeltor, Sehschlitze
    gw, gh = 2.4, 2.7
    hg = panzertor(B, F, W / 2, gw, gh, "4A6AAE" if stage >= 2 else "5A6274", DK if not gold else BLUE_D, STEEL_L, GOLD if gold else None, warn=stage <= 3)
    hf = [scharte(B, G, F, u, 1.7, 0.7 if W < 5.5 else 0.8) for u in (0.72, W - 0.72)]
    hr = [scharte(B, G, Rw, u, 1.7, 0.8) for u in (D * 0.28, D * 0.72)]
    holes = {"f": [hg] + hf, "r": hr}
    sockel(B, H, holes, shade(CONC_D, 0.75) if stage <= 2 else shade(ST_D, 0.8), v1=0.55)
    wandsatz(B, H, style, holes, color=wall_c, color2=wall_l, v0=0.55, size=None if style == "beton" else 0.4, eck=False, sides="fr")
    wandsatz(B, H, style, holes, color=wall_c, color2=wall_l, v0=0.55, size=None if style == "beton" else 0.57, eck=False, sides="bl")
    if band:
        for s in "frbl":
            tile(B, H.W(s), 0.0, H.h - 0.5, H.W(s).len, H.h - 0.28, 0.16, 0.08, band)
            if stage == 5:
                tile(B, H.W(s), 0.0, 0.55, H.W(s).len, 0.7, 0.16, 0.08, GOLD)
    for s, u in (("f", W / 2 - gw / 2 - 0.62), ("f", W / 2 + gw / 2 + 0.62)):
        lampe(B, L, F, u, 2.75, arm=0.26)
    wappen(B, F.M(W / 2, gh + 0.62 if stage >= 2 else gh + 0.55, 0.14), 0.62 if stage <= 3 else 0.8, rand=GOLD if stage >= 2 else STEEL_L)
    # --- Dachplatte mit Zinnen
    B.box((W + 0.5, D + 0.5, 0.26), (0, H.cy, H.top + 0.07), shade(wall_c, 0.8), bevel=0.04, segs=1)
    pl = boden(H.x0, H.y0, H.top + 0.2)
    nx, ny = 6, 5
    for i in range(nx):
        for j in range(ny):
            tile(B, pl, i * W / nx + 0.02, j * D / ny + 0.02, (i + 1) * W / nx - 0.02, (j + 1) * D / ny - 0.02, 0.03, 0.03, jit("AEB4BE" if stage <= 2 else "B9BFD6", 0.05))
    zinnen(B, H, 7, 5, wall_l, low=GOLD if stage == 5 else "9EA3AD")
    rz = H.top + 0.23
    # --- Ecken: Betonpfosten (1), Strebepfeiler (2, 3), Rundtürme (4, 5)
    cs = ((H.x0, H.y0), (H.x1, H.y0), (H.x1, H.y1), (H.x0, H.y1))
    if stage == 1:
        ecken(B, H, CONC_D, 0.36, 0.14, v1=H.h)
    elif stage <= 3:
        for (x, y) in cs:
            B.box((0.8, 0.8, H.h + 0.3), (x, y, H.z0 + (H.h + 0.3) / 2), shade(wall_c, 0.86), bevel=0.06, segs=1)
            B.box((0.9, 0.9, 0.5), (x, y, H.z0 + 0.45), trim, bevel=0.05, segs=1)
            B.box((0.9, 0.9, 0.3), (x, y, H.top + 0.3), trim, bevel=0.05, segs=1)
            if stage == 3:
                B.cyl(0.5, 0.5, (x, y, H.top + 0.7), BLUE_D, r=rot(0, 0, 45), r2=0.08, sides=4)
                B.ball(0.1, (x, y, H.top + 0.98), GOLD, subdiv=1)
    else:
        for (x, y) in cs:
            rundturm(B, G, x, y, 0.3, 4.7 if y < 0 else 5.3, 0.72, wall_c, wall_l, BLUE, GOLD, band=GOLD if stage == 5 else BLUE_D)
            if stage == 5:
                B.cyl(0.76, 0.12, (x, y, 2.6), GOLD, sides=12)
    # --- Sandsäcke, Munitionskisten
    sandbags(B, (-W / 2 - 0.2, H.y0 - 1.5, 0.25), 1, 0, 3, 2)
    sandbags(B, (W / 2 - 1.1, H.y0 - 1.5, 0.25), 1, 0, 3, 2)
    sandbags(B, (W / 2 + 0.55, H.y0 - 0.6, 0.25), 0, 1, 3 if stage >= 4 else 4, 2)
    munkiste(B, (-W / 2 + 0.3, H.y0 - 0.75, 0.47), 8)
    if stage >= 2:
        munkiste(B, (-W / 2 + 0.34, H.y0 - 0.78, 0.86), -14, "8FA043")
        crate(B, (-W / 2 - 0.2, H.y0 + 0.5, 0.25), 0.6, OLIVE)
    # --- Lüftungsrohr mit Dampf (rechte Seite)
    vx, vy = H.x1 + 0.34, H.y1 - 1.1
    pipe(B, [(H.x1 + 0.05, vy, 1.0), (vx, vy, 1.0), (vx, vy, H.top + 1.0)], 0.14, STEEL, 8)
    B.cyl(0.22, 0.14, (vx, vy, H.top + 1.02), STEEL_D, sides=8)
    B.cyl(0.2, 0.3, (vx, vy, H.top + 1.22), DK, sides=8, r2=0.26)
    for z in (1.6, 2.6):
        B.box((0.3, 0.1, 0.08), (H.x1 + 0.15, vy, z), STEEL_D)
    M.empty("fx_steam", (vx, vy, H.top + 1.5))
    # --- Aufbauten
    top_z = rz
    U = None
    if stage >= 2:
        uw, ud, uh = ((2.6, 2.0, 1.9), (3.6, 2.4, 2.7), (3.4, 2.3, 2.9), (3.4, 2.3, 3.0))[stage - 2]
        U = Haus(0.0 if stage < 4 else 0.0, H.cy + 0.25, uw, ud, rz, uh)
        U.kern(B)
        uf = [scharte(B, G, U.W("f"), u, uh - 1.15, 0.7) for u in ((uw * 0.27, uw * 0.73) if stage >= 3 else (uw / 2,))]
        ur = [scharte(B, G, U.W("r"), ud / 2, uh - 1.15, 0.7)]
        uho = {"f": uf, "r": ur}
        if stage >= 3:                                                                 # Tür zum Wachgang
            uho["f"] = uf + [tuer(B, U.W("f"), uw / 2, 0.0, 0.8, 1.5, color="4A6AAE", frame=DK, fw=0.1)]
        wandsatz(B, U, style, uho, color=wall_c, color2=wall_l, v0=0.0, size=None if style == "beton" else 0.45, eck=False)
        if stage == 2:
            ecken(B, U, CONC_D, 0.3, 0.12)
            B.box((uw + 0.4, ud + 0.4, 0.22), (0, U.cy, U.top + 0.05), shade(wall_c, 0.8), bevel=0.04, segs=1)
            for s in "frbl":
                w = U.W(s)
                At(B, w.M(w.len / 2, uh + 0.16, 0.16)).box((w.len + 0.36, 0.14, 0.26), (0, 0.07, 0.13), BLUE)
            top_z = U.top + 0.16
        else:
            ecken(B, U, wall_l, out=0.12, style="stein")
            for s in "frbl":
                tile(B, U.W(s), 0.0, uh - 0.3, U.W(s).len, uh - 0.12, 0.16, 0.08, band)
            R = dach(B, (0, U.cy, U.top), uw, ud, 1.15, BLUE, over=0.3, over_g=0.26, ground=rz, ridge=GOLD if gold else None, trim=GOLD if stage == 5 else CREAM, fallrohr=False)
            giebelfeld(B, U, 1.15, "plank_h", wall_l)
            flicken(B, R.planes[0], uw * 0.75, 0.7, 0.6, 0.5, "5E7FB5" if gold else WOOD_P)
            star(B, (U.x1 + 0.1 - 0.0, U.cy, U.top + 0.45), 0.0, GOLD)
            top_z = U.top + 1.3
    # --- Wachgang ab Modell 2 (Bunkerstufe 3): Geländer, Bohlen, Leiter, Sandsäcke
    if stage >= 2:
        for s in "frbl":
            w = H.W(s)
            n = 6 if s in "fb" else 4
            for i in range(n + 1):
                u = 0.5 + i * (w.len - 1.0) / n
                if stage >= 4 and (i == 0 or i == n):
                    continue
                At(B, w.M(u, H.h + 0.62, 0.0)).box((0.07, 0.07, 0.55), (0, 0.4, 0.27), STEEL_D)
            At(B, w.M(w.len / 2, H.h + 1.14, 0.0)).box((w.len - 0.9, 0.06, 0.07), (0, 0.4, 0), band or STEEL_L)
        plw = boden(H.x0 + 0.5, H.y0 + 0.45, rz)                                         # Bohlen des Wachgangs vorn
        for i in range(10):
            tile(B, plw, i * (W - 1.0) / 10 + 0.015, 0.0, (i + 1) * (W - 1.0) / 10 - 0.015, 0.75, 0.05, 0.05, jit(WOOD_P, 0.07))
        leiter(B, (H.x1 + 0.3, H.y0 + 0.9, 0.25), (H.x1 + 0.14, H.y0 + 0.9, H.top + 0.5), 0.5, STEEL_L, 0.34, 0.06)
        sandbags(B, (H.x0 + 0.7, H.y0 + 0.5, rz - 0.0), 1, 0, 3, 1)
    # --- Funkschüssel (dreht), Suchscheinwerfer (schwenkt), Fahne
    if stage == 1:
        schuessel(M, B, (H.x1 - 1.0, H.y1 - 0.9, rz), 0.6)
        scheinwerfer(M, B, (H.x1 - 0.7, H.y0 + 0.6, rz), -25)
        fahne(M, B, (H.x0 + 0.8, H.y1 - 0.8, rz), 2.8)
        B.box((1.4, 1.1, 0.5), (-0.3, H.cy + 0.3, rz + 0.25), CONC_D, bevel=0.05, segs=1)      # Luke
        B.box((0.9, 0.7, 0.08), (-0.3, H.cy + 0.3, rz + 0.54), "5A6274")
    else:
        schuessel(M, B, (H.x1 - 0.75, H.y1 - 0.7, rz) if stage < 4 else (U.x1 - 0.6, U.cy + 0.2, U.top + 0.62), 0.6 if stage < 4 else 0.5)
        scheinwerfer(M, B, (H.x1 - 0.65, H.y0 + 0.55, rz) if stage < 4 else (H.x1 - 1.05, H.y0 + 0.5, rz), -25)
        if stage == 2:
            fahne(M, B, (0.0, U.cy, top_z), 2.4)
        elif stage == 3:
            fahne(M, B, (-U.w / 2 + 0.3, U.cy, U.top + 0.75), 2.6)
        else:                                                                          # Fahnenturm auf dem Oberbau
            Tw = Haus(-U.w / 2 + 0.75, U.cy + 0.2, 1.3, 1.3, U.top + 0.3, 1.5)
            Tw.kern(B)
            wandsatz(B, Tw, "stein", {}, color=wall_c, color2=wall_l, v0=0.0, size=0.4, eck=False)
            for s in "fr":
                scharte(B, G, Tw.W(s), 0.65, 0.75, 0.4, frame=DK)
            B.box((1.6, 1.6, 0.2), (Tw.cx, Tw.cy, Tw.top + 0.05), GOLD if stage == 5 else BLUE_D)
            if stage == 4:
                B.cyl(1.05, 1.1, (Tw.cx, Tw.cy, Tw.top + 0.7), BLUE, r=rot(0, 0, 45), r2=0.06, sides=4)
                fahne(M, B, (Tw.cx, Tw.cy, Tw.top + 1.2), 1.9)
            else:
                B.cyl(0.7, 0.3, (Tw.cx, Tw.cy, Tw.top + 0.3), GOLD_D, sides=10)
                B.ball(0.68, (Tw.cx, Tw.cy, Tw.top + 0.45), GOLD, scale=(1, 1, 0.9), subdiv=2)
                fahne(M, B, (Tw.cx, Tw.cy, Tw.top + 1.0), 1.7)
    # --- Schornstein der Kommandostube (ab Modell 2)
    if stage >= 2:
        cx_, cy_ = H.x0 + 0.9, H.y1 - 0.7
        B.cyl(0.16, 1.3, (cx_, cy_, rz + 0.65), STEEL_D, sides=8)
        B.cyl(0.22, 0.1, (cx_, cy_, rz + 1.3), DK, sides=8)
        M.empty("fx_smoke", (cx_, cy_, rz + 1.5))
    # --- Gold und Zierde (Modell 4 und 5)
    if stage >= 4:
        for sx in (-1, 1):
            B.box((0.5, 0.5, 0.9), (sx * 2.25, H.y0 - 1.05, 0.45), wall_l, bevel=0.04, segs=1)
            B.box((0.6, 0.6, 0.12), (sx * 2.25, H.y0 - 1.05, 0.92), GOLD)
            laterne(B, L, sx * 2.25, H.y0 - 1.05, 0.98, 1.3, GOLD_D)
    if stage == 5:
        for (nm, sx) in (("sway_banner_l", -1), ("sway_banner_r", 1)):
            banner(M, nm, (sx * (gw / 2 + 0.72), H.y0 - 0.3, H.z0 + 2.55), 0.6, 1.6)
        for sx in (-1, 1):
            star(B, (sx * 2.25, H.y0 - 1.06 - 0.26, 0.5), 0.2, GOLD, 0.04)
        for s in "fr":
            w = H.W(s)
            for i in range(4):
                stud(B, w, w.len * (i + 0.5) / 4, H.h - 0.39, 0.16, 0.07, "FFF3B0", 0.05)
        pg = M.origin("pulse_stern_glow", (0, H.y0 - 0.3, H.z0 + gh + 1.55), local=True)
        star(pg, (0, 0, 0), 0.34, GLOW, 0.06)
    # --- kleiner Zwischenausbau auf der geraden Stufe
    X = M["lv%d_extra" % (stage * 2)]
    sandbags(X, (-W / 2 - 0.2, H.y0 - 1.5, 0.77), 1, 0, 2, 1)
    sandbags(X, (W / 2 - 0.8, H.y0 - 1.5, 0.77), 1, 0, 2, 1)
    munkiste(X, (min(W / 2 + 0.75, 3.4), H.y0 + 1.75, 0.25), 80)
    barrel(X, (-W / 2 - 0.3, H.y0 + 1.4, 0.25), OLIVE, 0.3, 0.85)
    if stage < 4:
        laterne(X, M["lv%d_lamp_glow" % (stage * 2)], -2.3, H.y0 - 2.1, 0.25, 2.1)
    else:
        X.cyl(0.9, 0.1, (0, H.y0 - 0.18, H.z0 + gh + 0.9), GOLD, r=rot(90, 0, 0), sides=3)
    # --- Gebrauchsspuren
    moos(B, Bk, W * 0.4, 5, 2.5); moos(B, Rw, D - 0.6, 3, 0.8)
    fleck(B, 1.2, H.y0 - 1.9, 0.25, 0.5, "8E8E96"); flicken(B, pl, W - 1.2, 0.6, 0.7, 0.5, RUST if stage <= 2 else "8C93A8", out=0.07)
    if stage <= 2:
        brett_quer(B, Rw, D * 0.5, 1.0, 0.8, 0.5, 6, color="8C919C", out=0.13)
    # --- Schaden
    d1, d2 = M["dmg1_spuren"], M["dmg2_bruch"]
    riss(d1, F, 0.5, 0.7, 1.5, out=0.2); riss(d1, F, W - 0.4, 0.6, 1.3, out=0.2); riss(d1, Rw, 0.5, 0.6, 1.6, out=0.2); riss(d1, Rw, D - 0.6, 1.2, 1.2, out=0.2)
    russ(d1, F, W - 1.0, 2.6, 0.5, out=0.19); russ(d1, Rw, D * 0.5, 2.7, 0.55, out=0.19); russ(d1, F, 0.9, 2.9, 0.4, out=0.19)
    loch(d2, Rw, D * 0.5, 1.0, 0.45, out=0.21, splitter=STEEL_D); loch(d2, F, 0.75, 1.1, 0.34, out=0.21, splitter=STEEL_D)
    stuetze(d2, (min(H.x1 + 0.8, 3.45), H.cy - 0.4, 0.25), (H.x1 + 0.18, H.cy - 0.4, 2.6), 0.2)
    stuetze(d2, (-1.9, H.y0 - 1.0, 0.45), (-1.9, H.y0 - 0.2, 2.6), 0.2)
    for i in range(5):
        d2.box((0.5, 0.36, 0.3), (1.6 + RNG.uniform(-0.5, 0.5), H.y0 - 0.9 + RNG.uniform(-0.3, 0.3), 0.5), jit(wall_c, 0.08), r=rot(RNG.uniform(-20, 20), 0, RNG.uniform(0, 90)), bevel=0.05, segs=1)
    M.empty("fx_smoke_dmg", (1.2, H.cy, H.top + 1.0))
    M.punkte(door=(0.0, H.y0 - 1.6), work_1=(-2.0, H.y0 - 1.9), work_2=(2.2, H.y0 - 2.0), drop=(1.3, H.y0 - 0.75, 0.47), bubble=(0.0, 0.3, top_z + (2.6 if stage < 4 else 3.4)))
    M.finish()


MODELS = {}
for _i in range(1, 6):
    MODELS["b_bunker_%d" % _i] = (lambda i=_i: bunker(i))
