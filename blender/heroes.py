"""Helden und Siedler im Voxel-Stil des Referenzfotos (großer Kopf, Helm mit Brille, Tarnmuster).
Jede Figur hat das gemeinsame Skelett rw_human (rig_human.py) und ein Mesh body. Die Voxel-Teile
(Hüfte, Bauch, Brust, Hals, Kopf, Oberarm, Unterarm, Hand, Oberschenkel, Unterschenkel, Fuß, Rucksack ...)
sind starr an genau einen Knochen gebunden (Gewicht 1,0) – nichts verbiegt sich, der Klötzchen-Look bleibt.
Die Animationen kommen aus anim_human.py (models/anim_human.glb), Godot spielt sie ab (src/humanoid.gd).

Paket H (V6): Helden (nicht der Siedler) haben zusätzlich
- ein eigenes Mesh `hat` (Kopfbedeckung mit Brille, Kapuze, Tuch): Godot blendet es aus, wenn ein Helm angelegt ist,
- fünf Gesichts-Meshes `face_normal`, `face_blink`, `face_joy`, `face_pain`, `face_strain` (dünne Pixel-Platten vor dem
  Gesicht, an den Knochen head gebunden); Godot zeigt immer genau eines (humanoid.gd: Blinzeln, Jubel, Schmerz, Anstrengung),
- Knochen `spring_hair*`, `spring_scarf*`, `spring_coat_*`, `spring_belt*` für Haare, Tücher, Kittel und Werkzeug,
  die Godot nachschwingen lässt (SpringBoneSimulator3D, Einstellungen in src/data_helden.gd SPRINGS).
Neu: Nele, die Taucherin."""
import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from kit import *
import rig_human as rig

V = 0.06  # Kantenlänge eines Voxels in Metern
FV = 0.03  # Gesichts-Pixel (halbes Voxel)
FACE_D = 0.008  # Dicke der Gesichts-Platten


def fill(vox, x0, x1, y0, y1, z0, z1, color):
    for x in range(x0, x1):
        for y in range(y0, y1):
            for z in range(z0, z1):
                vox[(x, y, z)] = color(x, y, z) if callable(color) else color


def camo(colors, seed, cell=2):
    def f(x, y, z):
        return colors[int(hash3(x // cell, y // cell, z // cell, seed) * len(colors)) % len(colors)]
    return f


def part(vox, name, bone, loc):
    """Ein Voxel-Teil; loc = Lage der Voxel-Ecke (0, 0, 0) im Modellraum. Wird starr an `bone` gebunden."""
    p = Part()
    p.voxels(vox, V, (0, 0, 0))
    return bind(p.build(name, None, loc, sharp_angle=1.0), bone)


def part_scaled(vox, name, bone, loc, center, k):
    """Wie part(), aber um `center` (Modellraum) um den Faktor k vergrößert – für Kopfbedeckungen, die genau auf den
    Kopf-Voxeln liegen (sonst flimmern deckungsgleiche Flächen)."""
    p = Part()
    p.voxels(vox, V, (0, 0, 0))
    c = Vector(center) - Vector(loc)
    for v in p.bm.verts:
        v.co = c + (v.co - c) * k
    return bind(p.build(name, None, loc, sharp_angle=1.0), bone)


def attach(ob, armature):
    """Hängt ein einzelnes gebundenes Mesh-Objekt mit Armature-Modifier an das Skelett (wie kit.skin, ohne Zusammenfügen)."""
    ob.parent = armature
    mod = ob.modifiers.new("Armature", "ARMATURE")
    mod.object = armature
    me = ob.data
    me.color_attributes.active_color = me.color_attributes["Col"]
    me.color_attributes.render_color_index = 0
    return ob


SPECS = {
    # Jona: der Soldat vom Foto – grüner Helm mit gelber Brille, braune Haare, grünes Tuch, Tarnanzug, Funkrucksack
    "jona": dict(cloth=["5E8A2E", "4C7426", "6E9A38", "86A84A", "3F6322"], cloth2=["4C7426", "3F6322", "5E8A2E"], helm=["4C7426", "5E8A2E", "3F6322", "6E9A38"],
                 hair="6B4226", skin="F2B98C", mask="4E8A3A", goggles="FFD23E", boots="6B4A2E", gloves="E8A878", belt="3A3F2A", head="helmet", back="radio", big=1.0),
    "mika": dict(cloth=["E0B02E", "D4A226", "EABC3C"], cloth2=["3A4152", "30374A"], helm=["D54144", "C2383C"], hair="E06A2A", skin="F2C29B", mask=None,
                 goggles=None, boots="2E3340", gloves="2E3340", belt="2E3340", head="fire", back="tanks", big=1.0),
    "bruno": dict(cloth=["5E7FB8", "5474AC", "6A8AC2"], cloth2=["3C4E7A", "34456E"], helm=["F08A1E", "F59A2E"], hair="3A2A1E", skin="D9A679", mask=None,
                  goggles=None, boots="5A4028", gloves="E0A82E", belt="8A6A3A", head="hardhat", back="belt", big=1.18),
    "ada": dict(cloth=["EDEDF2", "E2E4EC", "F6F6FA"], cloth2=["5A4A8C", "4E4080"], helm=["9A5CE0", "8A4FD0"], hair="2E3340", skin="F2C29B", mask=None,
                goggles="7FE3FF", boots="3A4152", gloves="9A5CE0", belt="6F7C96", head="cap", back="coils", big=1.0),
    "yuki": dict(cloth=["6B5A45", "5E4E3C", "78664E"], cloth2=["3F5A3A", "364E32"], helm=["3FA35A", "369450", "48AE64"], hair="1E2028", skin="F0C8A0", mask="2E6E44",
                 goggles=None, boots="4A3A2A", gloves="4A3A2A", belt="2E3340", head="hood", back="quiver", big=0.96),
    "greta": dict(cloth=["8AA0C8", "7E94BE", "96AAD2"], cloth2=["B8C4E0", "AAB8D6"], helm=["F07AB4", "F48EC0"], hair="E6E6EA", skin="F2C29B", mask=None,
                  goggles="DDE3EE", boots="7A4522", gloves="F2C29B", belt="F07AB4", head="scarf", back="none", big=0.9),
    # Nele, die Taucherin: Neoprenanzug in Petrol mit Streifen, Tauchmaske auf der Stirn, Schnorchel, rote Haare im
    # langen Zopf, gelbe Pressluftflasche auf dem Rücken, Bleigurt
    "nele": dict(cloth=["1F6E8C", "1A6480", "247896"], cloth2=["163E58", "12344A"], helm=["F2C230", "E8B020"], hair="B8462A", skin="F0C09A", mask=None,
                 goggles="9FE8FF", boots="1E2A38", gloves="1F6E8C", belt="F2C230", head="diver", back="airtank", big=0.98),
    "settler": dict(cloth=["9C9A4A", "8E8C40", "A8A656"], cloth2=["6A6A3A", "5E5E34"], helm=["0469CC", "0A5CB4"], hair="5A3A22", skin="F2C29B", mask=None,
                    goggles="7FE3FF", boots="4A3A2A", gloves="2E3340", belt="2E3340", head="helmet", back="none", big=1.0),
}

# ---------------------------------------------------------------- Gesichter (Paket H)
# Pixel-Bilder 16 × 12 (je Zeichen ein halbes Voxel), oberste Zeile = Höhe 13 halbe Voxel über dem Halsgelenk,
# Spalte 0 = x −8 halbe Voxel. Augen liegen wie früher bei x −3..−2 und 1..2, Höhe 4..5 (Voxel).
FACE_COL = {"k": "1E2028", "w": "FFFFFF", "m": "B8704A", "r": "7A2A2A", "t": "F07A86", "p": "F0A0A0", "b": "6FC8FF", "W": "FFFFFF"}
FACES = {
    "normal": ["................",
               "................",
               "..kkww....kkww..",
               "..kkww....kkww..",
               "..kkkk....kkkk..",
               "..kkkk....kkkk..",
               "pp............pp",
               "pp............pp",
               "......mmmm......",
               "......mmmm......",
               "................",
               "................"],
    "blink": ["................",
              "................",
              "................",
              "................",
              "..kkkk....kkkk..",
              "................",
              "pp............pp",
              "pp............pp",
              "......mmmm......",
              "......mmmm......",
              "................",
              "................"],
    "joy": ["................",
            "................",
            "...kk......kk...",
            "..k..k....k..k..",
            "..k..k....k..k..",
            "................",
            "pp..rrrrrrrr..pp",
            "pp..rrrrrrrr..pp",
            "....rrrrrrrr....",
            ".....rttttr.....",
            "......rrrr......",
            "................"],
    "pain": [".............b..",
             "............bbb.",
             "..kk........kk..",
             "....kk....kk....",
             "....kk....kk....",
             "..kk........kk..",
             "pp............pp",
             "................",
             "......rrrr......",
             ".....rrrrrr.....",
             ".....rrrrrr.....",
             "......rrrr......"],
    "strain": ["..kk........kk..",
               "....kk....kk....",
               "................",
               "..kkkk....kkkk..",
               "................",
               "................",
               "pp............pp",
               "....kkkkkkkk....",
               "....kWWkWWWk....",
               "....kWWkWWWk....",
               "....kkkkkkkk....",
               "................"],
}


def face_part(name, rows, H0, masked):
    """Dünne Pixel-Platte vor dem Gesicht (an head gebunden). masked: nur die Augen (Tuch vor dem Mund)."""
    vox = {}
    for i, row in enumerate(rows):
        pz = 13 - i
        if masked and pz < 8:
            continue
        for c, ch in enumerate(row):
            if ch != ".":
                vox[(c - 8, 0, pz)] = FACE_COL[ch]
    if not vox:
        vox[(0, 0, 13)] = FACE_COL["k"]
    p = Part()
    p.voxels(vox, FV, (0, 0, 0))
    for v in p.bm.verts:
        v.co.y = v.co.y * (FACE_D / FV)
    loc = H0 + Vector((0, -5 * V - FACE_D, 0))
    return bind(p.build(name, None, loc, sharp_angle=1.0), "head")


def build(key, with_extra=True):
    """Baut eine Figur: Skelett rw_human + Mesh `body` (Helden zusätzlich `hat` und `face_*`), Teile starr an je einen
    Knochen gebunden. Gibt (Armature, Mesh body) zurück."""
    s = SPECS[key]
    reset()
    big = s["big"]
    split = key != "settler"         # Siedler bleiben ein einziges Mesh (viele Figuren: Zeichenaufrufe sparen)
    seed = sum(ord(c) for c in key)
    cl = camo(s["cloth"], seed)
    cl2 = camo(s["cloth2"], seed + 7)
    hm = camo(s["helm"], seed + 3)
    dark = "23262E"
    w = int(round(4 * big))          # halbe Rumpfbreite in Voxeln
    J = {n: p for n, (par, p) in rig.joints(big).items()}
    T0 = J["spine"]                  # Ursprung der Rumpf-Voxel (Unterkante Rumpf)
    H0 = J["head"]                   # Ursprung der Kopf-Voxel (Hals)
    springs = {}                     # Zubehör, das nachschwingt: {knochen: (eltern, lage)}
    parts = []
    hat_parts = []                   # eigenes Mesh "hat" (nur Helden)
    # ---------------- Hüfte
    vox = {}
    fill(vox, -w, w, -3, 2, -2, 2, cl2)
    fill(vox, -w, w, -3, 2, 1, 2, s["belt"])
    fill(vox, -1, 1, -4, -3, 1, 2, "E0A82E")
    fill(vox, w - 2, w, -4, -3, -1, 1, s["cloth2"][0])     # Tasche
    if s["back"] == "airtank":                               # Bleigurt mit Gewichten
        for x in (-w + 1, w - 2):
            fill(vox, x, x + 1, -4, -3, 0, 2, "6F7C96")
    parts.append(part(vox, "hips", "hips", J["hips"]))
    # ---------------- Rumpf: Bauch (spine) und Brust (chest) getrennt, Hals als eigenes Teil
    vox = {}
    fill(vox, -w, w, -3, 2, 0, 7, cl)
    fill(vox, -w + 1, w - 1, -4, -3, 2, 6, cl2)             # Weste / Brusttasche
    fill(vox, -w + 1, -w + 3, -4, -3, 3, 5, s["belt"])
    for z in range(1, 7):                                   # Schultergurt schräg
        x = -w + z
        if -w <= x < w:
            vox[(x, -4, z)] = dark
    fill(vox, -w - 1, w + 1, -3, 2, 6, 7, cl2)              # Schulterpolster
    if s["back"] == "airtank":                               # Neopren: helle Streifen an den Seiten
        for z in range(0, 6):
            vox[(-w, -3, z)] = "7FD8E8"
            vox[(w - 1, -3, z)] = "7FD8E8"
    b = s["back"]
    if b == "belt":
        fill(vox, -w - 1, w + 1, -4, 3, 0, 1, "8A6A3A")
        fill(vox, w - 1, w + 1, -5, -4, -1, 1, "9AA4B8")
    parts.append(part({k: c for k, c in vox.items() if k[2] < 2}, "belly", "spine", T0))
    parts.append(part({k: c for k, c in vox.items() if k[2] >= 2}, "chest", "chest", T0))
    vox = {}
    fill(vox, -2, 2, -2, 2, 7, 8, s["skin"])
    parts.append(part(vox, "neck", "neck", T0))
    # ---------------- Rucksack und Zubehör (Knochen prop_back; Antenne/Spulen schwingen nach)
    vox = {}
    if b == "radio":
        fill(vox, -3, 3, 2, 5, 0, 6, camo(["4C7426", "3F6322", "5E8A2E"], 5))
        fill(vox, -3, 3, 5, 6, 1, 3, "8A8F5A")
        fill(vox, -4, -3, 2, 4, 0, 5, "2E3340")             # Funkgerät seitlich
        ant = {}
        fill(ant, -4, -3, 3, 4, 5, 13, "2E3340")            # Antenne
        ant[(-4, 3, 13)] = "9AA4B8"
        springs["spring_antenna"] = ("prop_back", T0 + Vector((-3.5 * V, 3.5 * V, 5 * V)))
        parts.append(part(ant, "antenna", "spring_antenna", T0))
    elif b == "tanks":
        fill(vox, -4, -1, 2, 5, 0, 8, "D54144")
        fill(vox, 1, 4, 2, 5, 0, 8, "E0A82E")
        fill(vox, -3, 3, 3, 4, 8, 9, "3A4152")
    elif b == "coils":
        fill(vox, -3, 3, 2, 4, 1, 6, "6F7C96")
        for sx, tag in ((-3, "l"), (2, "r")):
            coil = {}
            fill(coil, sx, sx + 1, 2, 3, 6, 11, "E0A82E")
            fill(coil, sx - 0, sx + 1, 2, 3, 11, 12, "7FE3FF")
            springs["spring_coil_" + tag] = ("prop_back", T0 + Vector(((sx + 0.5) * V, 2.5 * V, 6 * V)))
            parts.append(part(coil, "coil_" + tag, "spring_coil_" + tag, T0))
    elif b == "quiver":
        for i in range(7):
            fill(vox, -2 + i // 2, 0 + i // 2, 2, 4, i, i + 1, "6B4A32")
        fill(vox, 1, 3, 2, 3, 7, 9, "F4F6FA")
    elif b == "airtank":                                     # Pressluftflasche mit Ventil und Schlauch
        fill(vox, -2, 2, 2, 5, -1, 8, "F2C230")
        fill(vox, -2, 2, 2, 5, 3, 4, "1E2A38")              # Band
        fill(vox, -1, 1, 3, 4, 8, 9, "8A94A8")              # Ventil
        fill(vox, -1, 0, 3, 4, 9, 10, "2E3340")
        fill(vox, 1, 2, 2, 3, 6, 9, "2E3340")               # Schlauch nach vorn
    if vox:
        parts.append(part(vox, "back", "prop_back", T0))
    # ---------------- Kopf (Gelenk am Hals)
    vox = {}
    hat = {}                                                 # Kopfbedeckung (bei Helden eigenes Mesh)
    fill(vox, -5, 5, -5, 4, 0, 9, s["skin"])
    hair = s["hair"]
    fill(vox, -5, 5, 2, 4, 0, 9, hair)                       # Hinterkopf
    fill(vox, -5, -4, -2, 4, 1, 9, hair)                     # Seiten
    fill(vox, 4, 5, -2, 4, 1, 9, hair)
    fill(vox, -5, 5, -5, 4, 8, 9, hair)
    fill(vox, -5, -3, -5, -3, 3, 8, hair)                    # Strähnen vorn links/rechts
    fill(vox, 3, 5, -5, -3, 3, 8, hair)
    # Gesicht (Vorderseite y = -5): beim Siedler im Kopf, bei Helden als austauschbare Platten (face_*)
    if not split:
        for ex in (-3, 1):
            fill(vox, ex, ex + 2, -5, -4, 4, 6, "1E2028")
            vox[(ex + 1, -5, 5)] = "FFFFFF"
    if s["mask"]:
        fill(vox, -4, 4, -6, -4, 0, 4, s["mask"])            # Tuch vor Mund und Nase
        fill(vox, -3, 3, -6, -5, 0, 1, shade(s["mask"], 0.8))
    elif not split:
        fill(vox, -1, 1, -5, -4, 2, 3, "B8704A")             # Mund
        vox[(-4, -5, 3)] = "F0A0A0"
        vox[(3, -5, 3)] = "F0A0A0"
    hd = s["head"]
    hv = hat if split else vox
    if hd in ("helmet", "hardhat", "fire"):
        fill(hv, -6, 6, -6, 5, 7, 10, hm)
        fill(hv, -5, 5, -5, 4, 10, 11, hm)
        fill(hv, -6, 6, -7, -6, 7, 8, hm)                    # Schirm
        if hd == "hardhat":
            fill(hv, -1, 1, -6, 5, 10, 12, shade(s["helm"][0], 1.15))
            fill(hv, -7, 7, -7, 6, 7, 8, hm)
        if hd == "fire":
            fill(hv, -1, 1, -6, 5, 11, 12, "E0A82E")
            fill(hv, -6, 6, 5, 7, 6, 8, hm)                  # Nackenschutz
            fill(hv, -2, 2, -7, -6, 8, 10, "E0A82E")
        if s["goggles"]:
            fill(hv, -5, 5, -7, -6, 8, 10, "1E2028")
            fill(hv, -4, -1, -8, -7, 8, 10, s["goggles"])
            fill(hv, 1, 4, -8, -7, 8, 10, s["goggles"])
            hv[(-3, -8, 9)] = "FFFFFF"
            hv[(2, -8, 9)] = "FFFFFF"
            fill(hv, -6, -5, -6, 5, 8, 9, "1E2028")
            fill(hv, 5, 6, -6, 5, 8, 9, "1E2028")
    elif hd == "cap":
        fill(hv, -6, 6, -6, 5, 7, 10, hm)
        fill(hv, -5, 5, -5, 4, 10, 11, hm)
        fill(hv, -6, -5, -3, 3, 2, 7, shade(s["helm"][0], 0.8))   # Ohrenklappen
        fill(hv, 5, 6, -3, 3, 2, 7, shade(s["helm"][0], 0.8))
        fill(hv, -5, 5, -6, -5, 4, 7, "2E3340")              # große Brille
        fill(hv, -4, -1, -7, -6, 4, 7, s["goggles"])
        fill(hv, 1, 4, -7, -6, 4, 7, s["goggles"])
    elif hd == "hood":
        fill(hv, -6, 6, -5, 5, 6, 10, hm)
        fill(hv, -6, 6, -1, 5, 0, 6, hm)
        fill(hv, -5, 5, -4, 4, 10, 11, hm)
        fea = {}
        fill(fea, 5, 6, 0, 2, 10, 14, "F4F6FA")              # Federn (schwingen nach)
        fill(fea, 4, 5, 1, 3, 10, 13, "FF7043")
        springs["spring_feather"] = ("head", H0 + Vector((5 * V, 1.5 * V, 10 * V)))
        (hat_parts if split else parts).append(part(fea, "feather", "spring_feather", H0))
    elif hd == "scarf":
        fill(hv, -6, 6, -5, 5, 5, 10, hm)
        fill(hv, -6, 6, -1, 5, 1, 5, hm)
        hv[(-3, -6, 7)] = "FFFFFF"; hv[(2, -6, 8)] = "FFD23E"; hv[(4, -6, 6)] = "FFFFFF"
        fill(hv, -5, 5, -5, 4, 10, 12, "6F7C96")             # Stahlhelm obendrauf
        fill(hv, -4, 4, -4, 3, 12, 13, "7C879C")
        fill(hv, -4, -1, -6, -5, 4, 6, s["goggles"])         # Brille
        fill(hv, 1, 4, -6, -5, 4, 6, s["goggles"])
        if split:                                            # Paket H: Zipfel des Kopftuchs schwingen nach
            tails = {}
            fill(tails, -2, 0, 5, 6, -2, 2, hm)
            fill(tails, 0, 2, 5, 6, -3, 1, shade(s["helm"][0], 0.9))
            springs["spring_scarf"] = ("head", H0 + Vector((0, 5.5 * V, 1.5 * V)))
            hat_parts.append(part(tails, "scarf_tails", "spring_scarf", H0))
    elif hd == "diver":                                      # Paket H: Nele – Tauchmaske auf der Stirn, Schnorchel
        fill(hv, -6, -5, -4, 5, 7, 9, "1F6E8C")              # Maskenband um den Kopf
        fill(hv, 5, 6, -4, 5, 7, 9, "1F6E8C")
        fill(hv, -5, 5, 4, 5, 7, 8, "1F6E8C")
        fill(hv, -4, 4, -6, -5, 8, 11, hm)                   # Maskenrahmen
        fill(hv, -3, 0, -7, -6, 9, 11, s["goggles"])         # Glas
        fill(hv, 0, 3, -7, -6, 9, 11, s["goggles"])
        hv[(-2, -7, 10)] = "FFFFFF"
        hv[(1, -7, 10)] = "FFFFFF"
        fill(hv, 6, 7, -3, -2, 2, 12, "F2C230")              # Schnorchel
        fill(hv, 6, 7, -3, -2, 12, 13, "FF7043")
        fill(hv, 5, 6, -4, -3, 2, 3, "F2C230")
    if split:
        # langes Haar / Zopf, das nachschwingt
        if key in ("mika", "nele"):
            tail = {}
            n = 5 if key == "nele" else 4
            col2 = shade(hair, 0.85)
            fill(tail, -1, 1, 4, 5, 6 - n, 6, lambda x, y, z: hair if (z % 2 == 0) else col2)
            fill(tail, -1, 1, 4, 5, 5 - n, 6 - n, col2)                                  # Spitze
            if key == "nele":
                fill(tail, -1, 1, 4, 5, 5, 6, "F2C230")                                   # Haargummi
            springs["spring_hair"] = ("head", H0 + Vector((0, 4.5 * V, 5.5 * V)))
            parts.append(part(tail, "ponytail", "spring_hair", H0))
        if hat:
            hat_parts.append(part_scaled(hat, "hat_vox", "head", H0, H0 + Vector((0, -0.5 * V, 4.5 * V)), 1.02))
        for fk, rows in FACES.items():
            face_part("face_" + fk, rows, H0, bool(s["mask"]))
    parts.append(part(vox, "head", "head", H0))
    # ---------------- Tücher und Kittel, die nachschwingen (nur Helden)
    if split:
        if key == "ada":                                     # Kittel-Schöße hinten
            for sx, tag in ((-1, "l"), (1, "r")):
                ct = {}
                x0 = -w + 1 if sx < 0 else 1
                fill(ct, x0, x0 + w - 1, 2, 3, -5, 0, s["cloth"][0])
                fill(ct, x0, x0 + w - 1, 2, 3, -5, -4, s["cloth"][1])
                springs["spring_coat_" + tag] = ("hips", J["hips"] + Vector((sx * 2.0 * V, 2.5 * V, -0.5 * V)))
                parts.append(part(ct, "coat_" + tag, "spring_coat_" + tag, J["hips"]))
        if key == "bruno":                                   # Hammer am Gürtel
            hmr = {}
            fill(hmr, 0, 1, 0, 1, -4, 0, "8A5A32")
            fill(hmr, -1, 2, 0, 1, -5, -4, "8A94A8")
            springs["spring_belt"] = ("hips", J["hips"] + Vector(((w + 0.5) * V, 0.5 * V, 0.0)))
            parts.append(part(hmr, "hammer", "spring_belt", J["hips"] + Vector((w * V, 0, 0))))
    # ---------------- Arme (Oberarm, Unterarm, Hand) und Beine (Oberschenkel, Unterschenkel, Fuß)
    for sx, tag in ((-1, "l"), (1, "r")):
        vox = {}
        fill(vox, -2, 1, -2, 1, -4, 1, cl)
        fill(vox, -2, 1, -2, 1, 0, 1, cl2)
        parts.append(part(vox, "upper_arm_" + tag, "upper_arm_" + tag, J["upper_arm_" + tag]))
        vox = {}
        fill(vox, -2, 1, -2, 1, -4, 0, cl)
        fill(vox, -2, 1, -2, 1, -4, -3, s["belt"])
        parts.append(part(vox, "fore_arm_" + tag, "fore_arm_" + tag, J["fore_arm_" + tag]))
        vox = {}
        fill(vox, -3, 2, -3, 2, -7, -4, s["gloves"])         # große Hand
        parts.append(part(vox, "hand_" + tag, "hand_" + tag, J["fore_arm_" + tag]))
        leg = {}
        fill(leg, -2, 2, -2, 2, -5, 1, cl2)
        fill(leg, -2, 2, -3, -2, -4, -2, s["cloth2"][-1])    # Kniepolster (am Unterschenkel)
        parts.append(part({k: c for k, c in leg.items() if k[2] >= -2}, "thigh_" + tag, "thigh_" + tag, J["thigh_" + tag]))
        parts.append(part({k: c for k, c in leg.items() if k[2] < -2}, "shin_" + tag, "shin_" + tag, J["thigh_" + tag]))
        vox = {}
        fill(vox, -2, 2, -4, 2, -8, -5, s["boots"])          # Stiefel
        fill(vox, -2, 2, -4, 2, -8, -7, shade(s["boots"], 0.7))
        if s["back"] == "airtank":                           # Taucherin: Flossen-Spitzen an den Stiefeln
            fill(vox, -2, 2, -5, -4, -8, -7, "F2C230")
        parts.append(part(vox, "foot_" + tag, "foot_" + tag, J["thigh_" + tag]))
    # ---------------- Extras
    if key == "bruno":                                       # Schild aus einer Baggerschaufel am _l-Unterarm
        p = Part()
        p.box((0.1, 0.72, 0.84), (0, 0, 0), "E0A82E", bevel=0.05)
        for i in range(3):
            p.box((0.09, 0.14, 0.16), (0, -0.24 + i * 0.24, -0.48), "C9CED8", bevel=0.02)
        p.box((0.12, 0.3, 0.3), (0.02, 0, 0.05), "B8842A", bevel=0.03)
        parts.append(bind(p.build("shield", None, J["fore_arm_l"] + Vector((-0.2, -0.05, -0.2))), "fore_arm_l"))
    arm = rig.build_rig(big, springs)
    if split:
        faces = [o for o in bpy.context.scene.objects if o.name.startswith("face_")]
        for o in faces:
            attach(o, arm)
            o.hide_render = o.name != "face_normal"          # Symbol: nur das normale Gesicht
        if len(hat_parts) == 1:
            hat_parts[0].name = "hat"
            hat_parts[0].data.name = "hat"
            attach(hat_parts[0], arm)
        elif hat_parts:
            skin(hat_parts, arm, "hat")
    body = skin(parts, arm)
    if with_extra and key == "ada":                          # Begleiter: Drohne (starr, Godot lässt sie schweben)
        p = Part()
        p.box((0.3, 0.3, 0.2), (0, 0, 0), "EDEDF2", bevel=0.06)
        p.box((0.62, 0.08, 0.03), (0, 0, 0.14), "3A4152")
        p.box((0.08, 0.62, 0.03), (0, 0, 0.14), "3A4152")
        p.box((0.1, 0.03, 0.1), (0, -0.16, 0), "FB3D54")
        p.build("extra", None, (-0.6, 0.2, 1.9))
    if with_extra and key == "yuki":                         # Begleiter: Falke
        p = Part()
        p.ball(0.17, (0, 0, 0), "8A6A4A", scale=(1, 1.25, 0.95), subdiv=2)
        p.box((0.26, 0.18, 0.04), (0.22, 0.02, 0.02), "6B4A32", bevel=0.015)
        p.box((0.26, 0.18, 0.04), (-0.22, 0.02, 0.02), "6B4A32", bevel=0.015)
        p.cone(0.04, 0.1, (0, -0.24, 0.0), "FDCA14", r=rot(90, 0, 0), sides=6)
        p.box((0.04, 0.02, 0.04), (0.07, -0.17, 0.05), "181A22")
        p.box((0.04, 0.02, 0.04), (-0.07, -0.17, 0.05), "181A22")
        p.build("extra", None, (-0.6, 0.2, 1.9))
    return arm, body


if __name__ == "__main__":
    keys = sys.argv[1:] or list(SPECS.keys())
    for k in keys:
        build(k)
        save_rigged("hero_" + k)
        icon("hero_" + k, 384, yaw=28, pitch=14)
        print("ok", k)
