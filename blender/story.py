"""V6 Paket E (Geschichte): Modelle und Symbole.
  hero_haendlerin, hero_forscher, hero_schmied   die drei Geretteten (Rosa Kramer, Professor Moosbach, Knut Amboss):
                         Voxel-Figuren mit dem Skelett rw_human wie die Helden (heroes.py, Gesichter face_*), dazu eigenes
                         Zubehör (Sonnenhut und Kraxe, Tropenhelm, Brille und Bart, Kopftuch, Bart, Schürze und Hammer).
  b_tauschladen          Rosas Tauschladen (2×2 Felder): Marktstand mit gestreiftem Dach, Waage, Waren, Bude dahinter.
  st_camp                Gegnerlager der Waschbär-Diebe in der Staubebene (Zelte aus Plane, Beutehaufen, Feuer), Mitte frei für den Käfig.
  st_cocoon              Schleim-Kokon im Sumpfwerk, aus dem der Tropenhelm des Professors schaut (pulsiert).
  st_icecage             Käfig aus Eis am Frostpass (Eissäulen, Eisboden, Frost).
  st_heart, st_heart_red  das Sternherz (leuchtet, pulsiert, Splitterkranz dreht sich); rot = in Brodels Feuer
  ui_chronik, ui_trade, ui_report   Symbole (128 px, Stil wie ui_icons.py)
Aufruf: python3 blender/story.py [namen...]   (ohne Namen: alle)"""
import sys, os, math, random
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy
from kit import *
import kit
import heroes
import rig_human as rig
from rw_util import run

V = heroes.V
FV = heroes.FV


# ================================================================== Figuren
heroes.SPECS["haendlerin"] = dict(cloth=["E07A2E", "D46E26", "EA8A3C"], cloth2=["6B4A32", "5E4029", "74513A"], helm=["E8C46A", "DDB65C"],
                                  hair="8A4A2A", skin="F0C8A0", mask=None, goggles=None, boots="5A3A22", gloves="F0C8A0", belt="F2C230",
                                  head="none", back="none", big=0.95)
heroes.SPECS["forscher"] = dict(cloth=["8A6A44", "7E6040", "967650"], cloth2=["C8B888", "BCAC7E", "D2C294"], helm=["E6D6A0", "DCCB92"],
                                hair="E6E6EA", skin="F2C29B", mask=None, goggles=None, boots="3A2A1E", gloves="F2C29B", belt="5A3A22",
                                head="none", back="none", big=1.0)
heroes.SPECS["schmied"] = dict(cloth=["3A4152", "343A4A", "444C60"], cloth2=["4A3A2A", "40322A", "52422F"], helm=["B03A2E", "C0463A"],
                               hair="C0462A", skin="E8B48C", mask=None, goggles=None, boots="2E2620", gloves="6B4A32", belt="8A6A3A",
                               head="none", back="none", big=1.15)


def _fill(vox, x0, x1, y0, y1, z0, z1, c):
    heroes.fill(vox, x0, x1, y0, y1, z0, z1, c)


def _join(body, parts):
    """Hängt zusätzliche, starr gebundene Teile an das Mesh body (Armature-Modifier und Gruppen bleiben)."""
    if not parts:
        return
    obs = [body] + parts
    bpy.context.view_layer.update()
    with bpy.context.temp_override(active_object=body, selected_editable_objects=obs, selected_objects=obs, object=body):
        bpy.ops.object.join()


def _glasses(H0, name="glasses"):
    """Runde Brille aus halben Voxeln vor den Augen (an head gebunden), vor den Gesichts-Platten."""
    rows = ["................",
            ".kkkkkk..kkkkkk.",
            ".k....k..k....k.",
            ".k....kkkk....k.",
            ".k....k..k....k.",
            ".kkkkkk..kkkkkk.",
            "................"]
    vox = {}
    for i, row in enumerate(rows):
        pz = 12 - i
        for c, ch in enumerate(row):
            if ch == "k":
                vox[(c - 8, 0, pz)] = "8A5A22"
    p = Part()
    p.voxels(vox, FV, (0, 0, 0))
    for v in p.bm.verts:
        v.co.y = v.co.y * (0.012 / FV)
    loc = H0 + Vector((0, -5 * V - 0.026, 0))
    return bind(p.build(name, None, loc, sharp_angle=1.0), "head")


def figure(key):
    arm, body = heroes.build(key)
    s = heroes.SPECS[key]
    J = {n: p for n, (par, p) in rig.joints(s["big"]).items()}
    T0, H0 = J["spine"], J["head"]
    w = int(round(4 * s["big"]))
    up = Vector((0, 0, 0.004))
    parts = []
    if key == "haendlerin":
        # breiter Sonnenhut aus Stroh mit rotem Band und Blume
        hat = {}
        straw = lambda x, y, z: "E8C46A" if (x + y) % 2 else "DDB65C"
        _fill(hat, -8, 8, -8, 7, 9, 10, straw)                  # Krempe
        _fill(hat, -5, 5, -5, 4, 10, 13, straw)                 # Kopf
        _fill(hat, -5, 5, -6, 5, 10, 11, "D54144")              # Band
        _fill(hat, -6, -5, -5, 4, 10, 11, "D54144")
        _fill(hat, 5, 6, -5, 4, 10, 11, "D54144")
        _fill(hat, 2, 4, -7, -6, 10, 12, "F4F6FA")              # Blume
        hat[(3, -7, 11)] = "F2C230"
        parts.append(heroes.part(hat, "sunhat", "head", H0 + up))
        # Zopf seitlich
        br = {}
        _fill(br, -6, -5, 0, 2, -3, 5, lambda x, y, z: "8A4A2A" if z % 2 else "7A3E22")
        _fill(br, -6, -5, 0, 2, -4, -3, "F2C230")
        parts.append(heroes.part(br, "braid", "head", H0))
        # Halstuch
        sc = {}
        _fill(sc, -w, w, -4, 2, 6, 7, "2E9AB0")
        _fill(sc, -2, 2, -5, -4, 4, 7, "2E9AB0")
        parts.append(heroes.part_scaled(sc, "neckerchief", "chest", T0, T0 + Vector((0, -0.5 * V, 6.5 * V)), 1.06))
        # Kraxe mit Töpfen, Pfanne, Teppichrolle und Laterne
        bk = {}
        _fill(bk, -4, -3, 2, 3, -2, 12, "8A5A32")              # Gestell
        _fill(bk, 3, 4, 2, 3, -2, 12, "8A5A32")
        for z in (0, 5, 11):
            _fill(bk, -4, 4, 2, 3, z, z + 1, "7A4A28")
        _fill(bk, -3, 3, 3, 6, 0, 5, "C98A4B")                 # Kiste
        _fill(bk, -3, 3, 3, 6, 2, 3, "8A5A32")
        _fill(bk, -2, 2, 3, 6, 5, 8, "6F7C96")                 # Topf
        _fill(bk, -3, 3, 3, 6, 8, 9, "8A94A8")
        _fill(bk, -6, 6, 3, 5, 9, 11, lambda x, y, z: "D54144" if x % 3 else "F2C230")   # Teppichrolle quer
        _fill(bk, 4, 5, 2, 4, 4, 9, "2E3340")                  # Pfanne seitlich
        _fill(bk, -5, -4, 3, 4, 6, 8, "F2C230")                # Laterne
        bk[(-5, 3, 8)] = "2E3340"
        parts.append(heroes.part(bk, "kraxe", "prop_back", T0))
        # Gürteltasche mit Münzen
        bag = {}
        _fill(bag, -w, -w + 2, -4, -3, -2, 1, "8A5A32")
        bag[(-w + 1, -5, 0)] = "FDCA14"
        parts.append(heroes.part(bag, "purse", "hips", J["hips"]))
    elif key == "forscher":
        # Tropenhelm
        hat = {}
        _fill(hat, -7, 7, -8, 7, 8, 9, "DCCB92")               # Krempe
        _fill(hat, -6, 6, -6, 5, 9, 11, "E6D6A0")
        _fill(hat, -5, 5, -5, 4, 11, 12, "E6D6A0")
        _fill(hat, -3, 3, -3, 2, 12, 13, "E6D6A0")
        _fill(hat, -6, 6, -6, 5, 9, 10, "7A5432")              # Band
        hat[(0, -1, 13)] = "7A5432"
        parts.append(heroes.part_scaled(hat, "pith", "head", H0 + up, H0 + Vector((0, -0.5 * V, 4.5 * V)), 1.02))
        parts.append(_glasses(H0))
        # weißer Bart unter dem Mund
        bd = {}
        _fill(bd, -5, 5, -6, -5, -2, 2, "F4F6FA")
        _fill(bd, -6, -5, -5, 0, 0, 4, "E6E6EA")
        _fill(bd, 5, 6, -5, 0, 0, 4, "E6E6EA")
        _fill(bd, -3, 3, -7, -6, -3, 1, "E6E6EA")
        _fill(bd, -4, 4, -6, -5, -3, -2, "E6E6EA")
        parts.append(heroes.part(bd, "beard", "head", H0))
        # Ledertasche am Riemen mit Notizbüchern, Lupe am Gürtel
        bag = {}
        _fill(bag, w, w + 3, -3, 2, -3, 1, "7A4A28")
        _fill(bag, w, w + 3, -4, -3, -2, 1, "8A5A32")
        _fill(bag, w + 1, w + 2, -2, 1, 1, 2, "F4F6FA")             # Papier schaut heraus
        parts.append(heroes.part(bag, "satchel", "hips", J["hips"]))
        lp = {}
        _fill(lp, -w, -w + 1, -4, -3, -4, -1, "6B4A32")
        _fill(lp, -w - 1, -w + 2, -5, -4, -6, -3, "C9D0DE")
        lp[(-w, -6, -5)] = "9FE8FF"
        parts.append(heroes.part(lp, "loupe", "hips", J["hips"]))
        # Fliege
        bw = {}
        _fill(bw, -2, 2, -5, -4, 5, 6, "D54144")
        bw[(0, -5, 6)] = "9D2A35"
        parts.append(heroes.part(bw, "bowtie", "chest", T0))
    elif key == "schmied":
        # Kopftuch (eng am Kopf, etwas größer gerechnet) mit Knoten hinten
        bn = {}
        _fill(bn, -5, 5, -5, 4, 8, 10, "B03A2E")
        _fill(bn, -5, 5, 2, 4, 6, 8, "B03A2E")
        _fill(bn, -5, -4, -2, 4, 6, 8, "B03A2E")
        _fill(bn, 4, 5, -2, 4, 6, 8, "B03A2E")
        for (x, z) in ((-3, 9), (1, 8), (3, 9), (-1, 9)):
            bn[(x, -5, z)] = "F4F6FA"
        _fill(bn, -1, 1, 4, 6, 5, 7, "9D2A35")
        parts.append(heroes.part_scaled(bn, "bandana", "head", H0, H0 + Vector((0, -0.5 * V, 4.5 * V)), 1.03))
        # großer roter Bart (unter dem Mund), Koteletten
        bd = {}
        _fill(bd, -5, 5, -6, -5, -3, 2, lambda x, y, z: "C0462A" if (x + z) % 3 else "A63A22")
        _fill(bd, -6, -5, -5, 1, -1, 6, "C0462A")
        _fill(bd, 5, 6, -5, 1, -1, 6, "C0462A")
        _fill(bd, -4, 4, -7, -6, -4, 1, "A63A22")
        parts.append(heroes.part(bd, "beard", "head", H0))
        # Lederschürze: Brust, Bauch, Hüfte (je am eigenen Knochen)
        ap = {}
        _fill(ap, -w + 1, w - 1, -5, -4, 0, 7, lambda x, y, z: "8A5A32" if z != 4 else "6B4228")
        _fill(ap, -w + 1, -w + 2, -5, -4, 7, 8, "6B4228")
        _fill(ap, w - 2, w - 1, -5, -4, 7, 8, "6B4228")
        parts.append(heroes.part({k: c for k, c in ap.items() if k[2] < 2}, "apron_b", "spine", T0))
        parts.append(heroes.part({k: c for k, c in ap.items() if k[2] >= 2}, "apron_c", "chest", T0))
        ah = {}
        _fill(ah, -w + 1, w - 1, -5, -4, -6, 1, "8A5A32")
        _fill(ah, -2, 2, -6, -5, -3, -1, "6B4228")               # Tasche
        ah[(-1, -6, -2)] = "8A94A8"
        parts.append(heroes.part(ah, "apron_h", "hips", J["hips"]))
        # Schmiedehammer auf dem Rücken, Zange am Gürtel
        hm = {}
        _fill(hm, -1, 0, 2, 3, -3, 10, "8A5A32")
        _fill(hm, -3, 2, 1, 4, 10, 13, "5A6274")
        _fill(hm, -3, 2, 1, 4, 12, 13, "8A94A8")
        parts.append(heroes.part(hm, "hammer_back", "prop_back", T0))
        tg = {}
        _fill(tg, w, w + 1, -2, -1, -6, 0, "5A6274")
        _fill(tg, w, w + 1, -1, 0, -6, -2, "5A6274")
        parts.append(heroes.part(tg, "tongs", "hips", J["hips"]))
    _join(body, parts)
    body.name = "body"
    body.data.name = "body"
    return arm, body


# ================================================================== Tauschladen (2×2)
def tauschladen():
    import geb_kit as gk
    from geb_kit import Model, Haus, At, T, I4, dach, tuer, fenster, lampe, crate, barrel, sack, fleck, beam, schild, fahne, \
        WOOD, WOOD_D, WOOD_L, WOOD_P, CREAM, RED, RED_D, GOLD, DK, STEEL, STEEL_L, STEEL_D, BLUE, PAVE, GLOW
    from geb_prod import hof
    M = Model("b_tauschladen", 3.6, 3.6, looks=1)
    B, G, L = M["body"], M["win_glow"], M["lamp_glow"]
    hof(M, 3.5, 3.5, 0.0, color="D8C9A8")
    # kleine Bude hinten mit Tür nach vorn
    H = Haus(0.5, 0.92, 2.1, 1.2, 0.25, 2.3)
    H.kern(B)
    F = H.W("f")
    hd = tuer(B, F, 1.55, 0.0, 0.8, 1.9, color="5E7FB5", frame=CREAM)
    hw = fenster(B, G, F, 0.55, 1.05, 0.6, 0.6)
    gk.sockel(B, H, {"f": [hd, hw]})
    gk.wandsatz(B, H, "bretter", {"f": [hd, hw]}, color="C98A4B")
    dach(B, (H.cx, H.cy, H.top), H.w, H.d, 0.6, RED, over=0.12, over_g=0.12, ground=0.25, fallrohr=False, style="blech")
    lampe(B, L, F, 1.15, 2.0, arm=0.18)
    # Marktstand vorn: Tresen mit Waren, gestreiftes Dach auf vier Pfosten
    cx, cy = -0.2, -0.75
    B.box((2.4, 0.7, 0.9), (cx, cy, 0.25 + 0.45), WOOD, bevel=0.03)
    B.box((2.5, 0.8, 0.08), (cx, cy, 0.25 + 0.94), WOOD_L, bevel=0.02)
    for i in range(5):
        B.box((0.06, 0.02, 0.8), (cx - 1.0 + i * 0.5, cy - 0.36, 0.7), WOOD_D)
    for (x, y) in ((cx - 1.2, cy - 0.38), (cx + 1.2, cy - 0.38), (cx - 1.2, cy + 0.42), (cx + 1.2, cy + 0.42)):
        B.box((0.1, 0.1, 2.15), (x, y, 0.25 + 1.07), WOOD_D, bevel=0.02)
    aw = M.origin("sway_awning", (cx, cy - 0.5, 2.45), local=True)
    for i in range(6):
        c = "F2802E" if i % 2 == 0 else "F4F6FA"
        aw.box((0.43, 1.25, 0.05), (-1.08 + i * 0.43, 0.42, 0.0), c, r=rot(-14, 0, 0))
        aw.box((0.43, 0.04, 0.18), (-1.08 + i * 0.43, -0.2, -0.13), c)
    # Waren: Äpfel, Stoffballen, Töpfe, Schrauben, Waage mit Gold
    top = 0.25 + 0.98
    for i in range(7):
        B.ball(0.07, (cx - 0.95 + (i % 4) * 0.13, cy - 0.15 + (i // 4) * 0.12, top + 0.07), "D54144" if i % 3 else "8FB02A", subdiv=1)
    B.cyl(0.11, 0.42, (cx - 0.25, cy + 0.12, top + 0.11), "3C5CA4", r=rot(0, 90, 0), sides=10)
    B.cyl(0.11, 0.42, (cx - 0.25, cy - 0.12, top + 0.11), "E0A82E", r=rot(0, 90, 0), sides=10)
    B.cyl(0.13, 0.16, (cx + 0.4, cy + 0.1, top + 0.08), "6F7C96", sides=12)
    B.cyl(0.14, 0.02, (cx + 0.4, cy + 0.1, top + 0.17), "8A94A8", sides=12)
    for i in range(4):
        B.cyl(0.03, 0.08, (cx + 0.75 + (i % 2) * 0.09, cy - 0.15 + (i // 2) * 0.09, top + 0.04), STEEL_L, sides=6)
    # Waage: Säule, Balken (wiegt sich), zwei Schalen
    wx, wy = cx + 0.95, cy + 0.15
    B.cyl(0.03, 0.42, (wx, wy, top + 0.21), "E0A82E", sides=8)
    B.cyl(0.09, 0.03, (wx, wy, top + 0.015), "E0A82E", sides=10)
    sc = M.origin("sway_scale", (wx, wy, top + 0.44), local=True)
    sc.box((0.46, 0.03, 0.03), (0, 0, 0), "E0A82E")
    for sx in (-1, 1):
        sc.cyl(0.008, 0.16, (sx * 0.22, 0, -0.08), "8A94A8", sides=4)
        sc.cyl(0.08, 0.02, (sx * 0.22, 0, -0.17), "E0A82E", sides=10)
    sc.cyl(0.03, 0.02, (-0.22, 0, -0.15), "FDCA14", sides=8)
    # Schild über dem Stand: zwei Pfeile (Tausch)
    sg = At(B, T(cx, cy - 0.45, 2.75))
    sg.box((0.95, 0.06, 0.38), (0, 0, 0), WOOD_L, bevel=0.03)
    sg.box((1.0, 0.04, 0.42), (0, 0.02, 0), WOOD_D, bevel=0.02)
    for (sz, sxd, c) in ((0.08, 1, "3C8A3A"), (-0.08, -1, "D54144")):
        sg.box((0.5, 0.03, 0.06), (0, -0.04, sz), c)
        sg.cone(0.07, 0.12, (sxd * 0.29, -0.04, sz), c, r=rot(0, 90 * sxd, 0), sides=4)
    beam(B, (cx - 0.4, cy - 0.4, 2.45), (cx - 0.4, cy - 0.45, 2.56), 0.03, DK)
    beam(B, (cx + 0.4, cy - 0.4, 2.45), (cx + 0.4, cy - 0.45, 2.56), 0.03, DK)
    # Fässer, Kisten, Säcke, Teppich
    barrel(B, (1.3, -0.35, 0.25), "3C5CA4", r=0.26, h=0.7)
    barrel(B, (1.32, 0.25, 0.25), RED, r=0.24, h=0.65)
    crate(B, (-1.32, 0.35, 0.25), 0.55, WOOD_L, 10)
    crate(B, (-1.3, 0.4, 0.8), 0.4, WOOD, -15)
    sack(B, (-1.3, -0.25, 0.25), yaw=20)
    sack(B, (0.95, -1.15, 0.25), yaw=-35, lie=True)
    B.box((1.0, 0.56, 0.02), (cx + 0.1, cy - 0.7, 0.26), "B03A2E", bevel=0.01)
    for i in range(4):
        B.box((0.9, 0.05, 0.012), (cx + 0.1, cy - 0.92 + i * 0.145, 0.275), "F2C230")
    # Wimpelkette zwischen Bude und Stand (wiegt sich), Teekessel auf kleinem Ofen (Dampf)
    wp = M.origin("sway_pennants", (0.0, 0.35, 2.3), local=True)
    for i in range(7):
        c = ("F2802E", "3C8A3A", "F2C230", "3C5CA4")[i % 4]
        wp.cone(0.08, 0.16, (-1.2 + i * 0.4, 0, -0.06 - 0.08 * math.sin(i / 6.0 * math.pi)), c, r=rot(180, 0, 0), sides=3)
    wp.cyl(0.01, 2.6, (0, 0, 0.02), DK, r=rot(0, 90, 0), sides=4)
    B.box((0.36, 0.36, 0.42), (1.3, 1.2, 0.25 + 0.21), "5A6274", bevel=0.03)
    B.cyl(0.13, 0.16, (1.3, 1.2, 0.25 + 0.5), "D54144", sides=10)
    B.cyl(0.02, 0.12, (1.42, 1.2, 0.25 + 0.55), "D54144", r=rot(0, 60, 0), sides=4)
    M.empty("fx_steam", (1.45, 1.2, 0.25 + 0.66))
    fleck(B, 0.9, -0.9, 0.26, 0.25, "B89A6A")
    M.punkte(door=(H.x0 + 1.55, H.y0 - 0.45), work_1=(cx, cy + 0.6), work_2=(-1.0, -1.35), drop=(1.3, -1.0), bubble=(cx, cy, 3.4))
    M.finish()


# ================================================================== Gegnerlager, Kokon, Eiskäfig
def _tent(p, x, y, yaw, c1, c2, s=1.0):
    """Zelt aus zwei schrägen Planen (A-Form), Stangen an den Giebeln, Eingang vorn."""
    m = Matrix.Translation(Vector((x, y, 0))) @ rot(0, 0, math.degrees(yaw))
    L = 1.3 * s
    for side, c in ((1, c1), (-1, c2)):
        ctr = m @ Vector((0, side * L * 0.5 * math.sin(math.radians(35)), L * 0.5 * math.cos(math.radians(35))))
        p.box((1.6 * s, 0.05, L), tuple(ctr), c, r=rot(0, 0, math.degrees(yaw)) @ rot(side * 35, 0, 0))
    ridge = L * math.cos(math.radians(35))
    for sx in (-1, 1):
        p.cyl(0.04, ridge + 0.15, tuple(m @ Vector((sx * 0.8 * s, 0, (ridge + 0.15) / 2))), "7A4522", sides=5)
    p.cyl(0.03, 1.7 * s, tuple(m @ Vector((0, 0, ridge + 0.02))), "7A4522", r=rot(0, 0, math.degrees(yaw)) @ rot(0, 90, 0), sides=5)
    p.box((0.05, 0.5 * s, 0.6 * s), tuple(m @ Vector((-0.82 * s, 0, 0.3 * s))), "F4F6FA", r=rot(0, 0, math.degrees(yaw)))


def _merge(p, q):
    """Hängt das bmesh von q an p an (gleiche Farbschicht)."""
    import bmesh
    me = bpy.data.meshes.new("_tmp")
    q.bm.to_mesh(me)
    q.bm.free()
    p.bm.from_mesh(me)
    bpy.data.meshes.remove(me)


def camp():
    reset()
    root = empty("st_camp")
    B = Part()
    rng = random.Random(7)
    # Zelte aus Planen (Waschbären mögen gestreift)
    for (x, y, yaw, c1, c2) in ((-3.2, 1.8, 30, "8A9A5A", "7A8A4A"), (3.0, 2.4, -25, "C9A86A", "B8975A"), (-2.6, -2.8, 160, "6F7C96", "5A6274")):
        _tent(B, x, y, math.radians(yaw), c1, c2, 1.25)
    # Beutehaufen: Kisten, Töpfe, Radkappen, Teppichrollen
    for (x, y, s) in ((2.6, -2.2, 0.6), (3.2, -1.4, 0.45), (-3.6, -0.6, 0.5)):
        B.box((s, s, s), (x, y, s / 2), "B5682F", r=rot(0, 0, rng.uniform(0, 90)), bevel=0.03)
    for i in range(6):
        a = rng.uniform(0, math.tau)
        x, y = 3.1 + math.cos(a) * 0.5, -2.0 + math.sin(a) * 0.5
        B.cyl(0.18, 0.04, (x, y, 0.62 + 0.04 * i), "C9D0DE", r=rot(rng.uniform(-20, 20), rng.uniform(-20, 20), 0), sides=10)
    B.cyl(0.14, 0.9, (-3.4, 0.4, 0.14), "D54144", r=rot(0, 90, 20), sides=8)
    B.cyl(0.14, 0.9, (-3.3, 0.7, 0.14), "F2C230", r=rot(0, 90, 35), sides=8)
    # Lagerfeuer mit Steinen
    fx, fy = 0.0, 2.9
    for i in range(7):
        a = i / 7 * math.tau
        B.ball(0.16, (fx + math.cos(a) * 0.45, fy + math.sin(a) * 0.45, 0.08), "8A8F96", scale=(1, 1, 0.7), subdiv=1)
    for i in range(3):
        B.cyl(0.06, 0.7, (fx, fy, 0.12), "7A4522", r=rot(0, 80, i * 60), sides=5)
    fl = Part()
    fl.cone(0.22, 0.5, (0, 0, 0.25), "FD932C", sides=6)
    fl.cone(0.12, 0.35, (0.05, 0.03, 0.2), "FFD24D", sides=5)
    fl.build("pulse_fire_glow", root, (fx, fy, 0.1))
    empty("fx_smoke", root, (fx, fy, 0.7))
    # Fahne der Diebe (Waschbärschwanz-Streifen) auf einer Stange
    B.cyl(0.05, 2.8, (-1.2, 3.4, 1.4), "7A4522", sides=6)
    fg = Part()
    for i in range(4):
        fg.box((0.9, 0.03, 0.14), (0.45, 0, -0.07 - i * 0.14), "3A3F4A" if i % 2 == 0 else "B8BCC6")
    fg.build("sway_flag", root, (-1.2, 3.4, 2.75))
    # Palisade aus Brettern (Halbkreis hinten), Spuren im Sand
    for i in range(9):
        a = math.radians(200 + i * 17)
        x, y = math.cos(a) * 4.6, math.sin(a) * 4.6
        B.box((0.22, 0.12, rng.uniform(0.9, 1.3)), (x, y, 0.5), "8A5A32" if i % 2 else "A9622F", r=rot(rng.uniform(-8, 8), 0, math.degrees(a) + 90))
    for i in range(10):
        a = rng.uniform(0, math.tau)
        r = rng.uniform(1.8, 4.0)
        B.ball(0.06, (math.cos(a) * r, math.sin(a) * r, 0.01), "C99A52", scale=(1.6, 1, 0.2), subdiv=1)
    B.build("body", root)
    bake_ao()
    save("st_camp")
    icon("st_camp", 256, yaw=30, pitch=34)


def cocoon():
    reset()
    root = empty("st_cocoon")
    B = Part()
    # Pfütze und Fäden am Boden
    B.cyl(1.4, 0.06, (0, 0, 0.03), "7FA024", sides=18)
    B.cyl(1.0, 0.07, (0.2, 0.1, 0.04), "94B128", sides=16)
    for i in range(6):
        a = i / 6 * math.tau + 0.3
        B.ball(0.12, (math.cos(a) * 1.15, math.sin(a) * 1.15, 0.06), "C4DB45", scale=(1.4, 1, 0.5), subdiv=1)
    B.build("body", root)
    C = Part()
    C.ball(0.75, (0, 0, 1.15), "94B128", scale=(1, 1, 1.45), subdiv=3)
    C.ball(0.42, (0.35, -0.35, 0.8), "A8C436", scale=(1, 1, 1.2), subdiv=2)
    C.ball(0.36, (-0.4, 0.25, 0.7), "86A022", subdiv=2)
    for (x, z) in ((-0.3, 1.5), (0.25, 1.1), (0.0, 0.7)):
        C.ball(0.12, (x, -0.68, z), "D6EA7A", scale=(1, 0.4, 1), subdiv=1)        # Glanzflecken
    # Tropenhelm schaut oben heraus, Brille an der Seite
    C.cyl(0.36, 0.05, (0, 0, 2.18), "DCCB92", sides=16)
    C.ball(0.26, (0, 0, 2.2), "E6D6A0", scale=(1, 1, 0.75), subdiv=2)
    C.cyl(0.27, 0.05, (0, 0, 2.24), "7A5432", sides=16)
    C.torus(0.07, 0.015, (0.42, -0.55, 1.45), "2E3340", r=rot(90, 0, 0), seg=10, tseg=4)
    C.torus(0.07, 0.015, (0.58, -0.5, 1.45), "2E3340", r=rot(90, 0, 0), seg=10, tseg=4)
    C.build("pulse_cocoon", root, (0, 0, 0))
    bake_ao()
    save("st_cocoon")
    icon("st_cocoon", 256, yaw=30, pitch=20)


def icecage():
    reset()
    root = empty("st_icecage")
    B = Part()
    rng = random.Random(3)
    B.cyl(1.6, 0.1, (0, 0, 0.05), "D6ECFF", sides=10)
    B.cyl(1.25, 0.12, (0, 0, 0.07), "BFE0FF", sides=9)
    # Eissäulen ringsum (eckig, unterschiedlich hoch), oben ein Eisdeckel
    n = 9
    for i in range(n):
        a = i / n * math.tau
        h = rng.uniform(2.3, 2.9)
        c = "A9D8FF" if i % 2 else "C8E8FF"
        B.cyl(0.17, h, (math.cos(a) * 1.15, math.sin(a) * 1.15, h / 2), c, r=rot(rng.uniform(-6, 6), rng.uniform(-6, 6), 0), sides=5)
        B.cone(0.17, 0.35, (math.cos(a) * 1.15, math.sin(a) * 1.15, h + 0.17), "E6F4FF", sides=5)
    B.cyl(1.35, 0.22, (0, 0, 2.55), "BFE0FF", sides=9, r2=1.1)
    for i in range(6):
        a = rng.uniform(0, math.tau)
        B.cone(0.2, rng.uniform(0.5, 0.9), (math.cos(a) * 0.6, math.sin(a) * 0.6, 2.85), "E6F4FF", r=rot(rng.uniform(-20, 20), rng.uniform(-20, 20), 0), sides=5)
    # Eiszapfen am Deckel, Schneehaufen
    for i in range(10):
        a = i / 10 * math.tau
        B.cone(0.06, 0.4, (math.cos(a) * 1.25, math.sin(a) * 1.25, 2.27), "E6F4FF", r=rot(180, 0, 0), sides=4)
    for (x, y, r) in ((1.7, 0.6, 0.45), (-1.6, -0.9, 0.4), (0.4, 1.8, 0.35)):
        B.ball(r, (x, y, 0.0), "F4F8FF", scale=(1.3, 1, 0.6), subdiv=2)
    B.build("body", root)
    gl = Part()
    gl.ball(0.2, (0, 0, 2.95), "9FE8FF", subdiv=2)
    gl.build("pulse_frost_glow", root, (0, 0, 0))
    empty("fx_steam", root, (0, 0, 2.7))
    bake_ao()
    save("st_icecage")
    icon("st_icecage", 256, yaw=30, pitch=24)


def heart(name, c1, c2, c3):
    """Das Sternherz: leuchtendes Herz aus Sternenkristall (pulsiert), ein Kranz kleiner Splitter dreht sich darum."""
    reset()
    root = empty(name)
    H = Part()
    a = 0.62
    H.box((a, 0.36, a), (0, 0, 0.0), c1, r=rot(0, 45, 0), bevel=0.12, segs=3)
    for sx in (-1, 1):
        H.ball(a * 0.5, (sx * a * 0.354, 0, a * 0.354), c1, scale=(1, 0.62, 1), subdiv=3)
    H.ball(0.12, (-0.18, -0.2, 0.28), c3, scale=(1, 0.3, 0.6), subdiv=1)
    H.build("pulse_heart_glow", root, (0, 0, 0))
    R = Part()
    for i in range(8):
        ang = i / 8 * math.tau
        R.cone(0.07, 0.22, (math.cos(ang) * 0.75, math.sin(ang) * 0.75, 0.0), c2, r=rot(0, 0, math.degrees(ang)) @ rot(0, 90, 0), sides=4)
        R.ball(0.035, (math.cos(ang + 0.4) * 0.62, math.sin(ang + 0.4) * 0.62, 0.12 * math.sin(i)), c3, subdiv=1)
    R.build("spin_ring_glow", root, (0, 0, 0))
    save(name)
    icon(name, 256, yaw=20, pitch=10)


# ================================================================== Symbole
def _ui(name, fn, yaw=-18.0, pitch=10.0):
    from weapons import toon, scale_all
    p = Part()
    fn(p)
    scale_all(p, 0.5)
    zmin = min(v.co.z for v in p.bm.verts)
    for v in p.bm.verts:
        v.co.z -= zmin
    toon(p, 0.82, 1.1)
    reset()
    root = empty("ui_" + name)
    p.build("body", root)
    save("ui_" + name)
    icon("ui_" + name, 128, yaw=yaw, pitch=pitch, margin=1.08)


def i_chronik(p):
    """Aufgeschlagenes Buch mit goldenem Stern und Lesezeichen."""
    from weapons import star
    for sx in (-1, 1):
        p.box((0.46, 0.08, 0.62), (sx * 0.24, 0.04, 0.0), "8A3A2E", r=rot(0, sx * -8, 0), bevel=0.03, segs=1)
        p.box((0.42, 0.06, 0.56), (sx * 0.22, -0.02, 0.02), "FFF2D0", r=rot(0, sx * -8, 0), bevel=0.02, segs=1)
        for k in range(4):
            p.box((0.26, 0.015, 0.03), (sx * 0.22, -0.06, 0.18 - k * 0.1), "D8C08A", r=rot(0, sx * -8, 0))
    p.box((0.05, 0.1, 0.62), (0, 0.04, -0.02), "6E2A22")
    star(p, 0.2, 0.08, (0.0, -0.12, 0.3), "FFD23E", n=5, inner=0.45)
    p.box((0.06, 0.02, 0.36), (0.12, -0.08, -0.32), "D54144")


def i_trade(p):
    """Zwei Pfeile im Kreis (Tausch) mit Münze in der Mitte."""
    from weapons import sweep, arc, prism
    for (a0, a1, c) in ((20, 160, "3C8A3A"), (200, 340, "D54144")):
        pts = arc(0, 0, 0.38, a0, a1, 12, y=-0.02)
        sweep(p, pts, 0.07, c, sides=8, ref=(0, 1, 0))
        tip = pts[-1]
        ang = a1 + 90
        prism(p, [(-0.13, 0.0), (0.13, 0.0), (0.0, 0.2)], 0.12, (tip[0], -0.02, tip[2]), c, r=rot(0, -ang, 0), bevel=0.02, segs=1)
    p.cyl(0.17, 0.08, (0, -0.02, 0), "FDCA14", r=rot(90, 0, 0), sides=18, bevel=0.02)
    p.cyl(0.11, 0.09, (0, -0.02, 0), "FFE27A", r=rot(90, 0, 0), sides=18)


def i_report(p):
    """Zettel mit Häkchen und kleiner Karte."""
    p.box((0.62, 0.06, 0.78), (0, 0.02, 0), "FFF2D0", bevel=0.03, segs=1)
    p.box((0.62, 0.08, 0.12), (0, 0.02, 0.4), "C98A4B", bevel=0.03, segs=1)
    for k in range(3):
        z = 0.18 - k * 0.2
        p.box((0.32, 0.02, 0.05), (0.08, -0.02, z), "B8A27A")
        p.box((0.1, 0.03, 0.05), (-0.2, -0.03, z - 0.02), "3C8A3A", r=rot(0, 40, 0))
        p.box((0.16, 0.03, 0.05), (-0.15, -0.03, z + 0.01), "3C8A3A", r=rot(0, -50, 0))


FIGURES = ["haendlerin", "forscher", "schmied"]
TABLE = {}
for _k in FIGURES:
    def _f(k=_k):
        figure(k)
        save_rigged("hero_" + k)
        icon("hero_" + k, 384, yaw=28, pitch=14)
    TABLE["hero_" + _k] = _f
TABLE["b_tauschladen"] = tauschladen
TABLE["st_camp"] = camp
TABLE["st_cocoon"] = cocoon
TABLE["st_icecage"] = icecage
TABLE["st_heart"] = lambda: heart("st_heart", "E8FF9A", "C4FF6A", "FFFFFF")
TABLE["st_heart_red"] = lambda: heart("st_heart_red", "FF8A3A", "FFC23A", "FFF2C0")
TABLE["ui_chronik"] = lambda: _ui("chronik", i_chronik)
TABLE["ui_trade"] = lambda: _ui("trade", i_trade)
TABLE["ui_report"] = lambda: _ui("report", i_report)

if __name__ == "__main__":
    run(TABLE, sys.argv)
