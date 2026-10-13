"""Paket H (V6): Ausrüstungs-Sets zum Anziehen – je Set Helm, Weste und Glücksbringer (gear_<set>_<helmet|vest|charm>).

Die Teile sitzen am Skelett der Helden (src/humanoid.gd set_gear, BoneAttachment3D):
- Helm  -> Knochen head  (Ursprung = Halsgelenk, gleiches Voxel-Raster wie der Kopf in heroes.py: Kopf x −5..4, y −5..3, z 0..8)
- Weste -> Knochen chest (Ursprung = Brustgelenk; Raster des Rumpfs: Brust x −4..3, y −3..1, z 2..6 über dem Bauchgelenk)
- Glücksbringer -> Knochen hips (Ursprung = Hüftgelenk; hängt vorn rechts am Gürtel)
Helme und Westen sind eine Voxel-Schale, überall mindestens ein Voxel außerhalb der Figur (sonst flimmern deckungsgleiche
Flächen). Westen sind hinten offen (dort hängen Rucksäcke). Ein Objekt `body`; leuchtende Teile `*_glow`.
Die Farben stehen auch in src/data_helden.gd (SETS). Aufruf: python3 blender/gear_sets.py [gear_bau_helmet ...]"""
import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from kit import *
import rig_human as rig

V = 0.06
J = {n: p for n, (par, p) in rig.joints(1.0).items()}
CHEST_OFF = J["spine"] - J["chest"]            # Rumpf-Raster (Ursprung Bauchgelenk) relativ zum Brustgelenk


def fill(vox, x0, x1, y0, y1, z0, z1, color):
    for x in range(x0, x1):
        for y in range(y0, y1):
            for z in range(z0, z1):
                vox[(x, y, z)] = color(x, y, z) if callable(color) else color


def camo(colors, seed, cell=2):
    def f(x, y, z):
        return colors[int(hash3(x // cell, y // cell, z // cell, seed) * len(colors)) % len(colors)]
    return f


def carve(vox, x0, x1, y0, y1, z0, z1):
    for x in range(x0, x1):
        for y in range(y0, y1):
            for z in range(z0, z1):
                vox.pop((x, y, z), None)


# ---------------------------------------------------------------- Grundformen
def cap_shell(vox, col, z0=7, z1=11, front=-6, back=5):
    """Kappe über dem Kopf: Schale x −6..5, y front..back−1, z z0..z1−1 (innen hohl genug)."""
    fill(vox, -6, 6, front, back, z0, z1, col)
    carve(vox, -5, 5, front + 1, back - 1, z0, z1 - 1)


def dome(vox, col, zb, h, rx=6.6, ry=6.1, open_face=8):
    """Runde Helmkuppe (abgerundeter Kasten, oben zwei Stufen kleiner) ab Höhe zb, h Voxel hoch. Der Kopf darunter bleibt
    frei (mindestens ein Voxel Abstand); unterhalb open_face bleibt das Gesicht vorn frei."""
    for z in range(zb, zb + h):
        k = 1.0
        if z == zb + h - 1:
            k = 0.72
        elif z == zb + h - 2:
            k = 0.9
        for x in range(-8, 8):
            for y in range(-8, 7):
                if abs((x + 0.5) / (rx * k)) ** 4 + abs((y + 1.0) / (ry * k)) ** 4 <= 1.0:
                    if -5 <= x <= 4 and -5 <= y <= 3 and z <= 8:
                        continue                                  # Kopf
                    if z < open_face and y <= -5 and -5 <= x <= 4:
                        continue                                  # Gesicht frei
                    vox[(x, y, z)] = col(x, y, z) if callable(col) else col


def vest_shell(vox, col, z0=2, z1=7):
    """Weste: Vorderseite (y −5..−4), Seiten (x −5 und 4), Schulterträger; hinten offen."""
    fill(vox, -5, 5, -5, -3, z0, z1, col)
    fill(vox, -5, -4, -5, 2, z0, z1, col)
    fill(vox, 4, 5, -5, 2, z0, z1, col)
    for x0 in (-4, 2):
        fill(vox, x0, x0 + 2, -5, 2, 7, 8, col)                 # Träger über die Schultern


def finish(name, parts, origin, yaw=-28.0, pitch=16.0, render=True):
    """parts = [(vox, glow)], Voxel-Raster mit Ursprung origin (Lage der Ecke (0,0,0) relativ zum Gelenk)."""
    reset()
    root = empty(name)
    n = 0
    for vox, glow in parts:
        if not vox:
            continue
        p = Part()
        p.voxels(vox, V, origin)
        ob = p.build("lamp_glow" if glow else "body", root, (0, 0, 0), sharp_angle=1.0)
        n += len(ob.data.polygons)
    save(name)
    if render:
        icon(name, 256, yaw=yaw, pitch=pitch, margin=1.1)
    print("ok %s  %d Flächen" % (name, n))


def finish_charm(name, p, render=True):
    """Glücksbringer aus Grundkörpern (klein, am Gürtel): Ursprung Hüftgelenk, hängt vorn rechts."""
    reset()
    root = empty(name)
    p.build("body", root, (0.17, -0.25, -0.02))
    save(name)
    if render:
        icon(name, 256, yaw=-20.0, pitch=10.0, margin=1.15)
    print("ok", name)


HEAD = (0, 0, 0)                 # Kopf-Raster: Ursprung = Halsgelenk
CHEST = (CHEST_OFF.x, CHEST_OFF.y, CHEST_OFF.z)


# ---------------------------------------------------------------- Postbote (blau/gelb)
def bote_helmet():
    v = {}
    dome(v, "1E3A6E", 7, 2, 6.6, 6.1)                         # dunkles Band
    fill(v, -7, 7, -8, 6, 9, 11, "2E6EB8")                    # weiter Deckel der Schirmmütze
    fill(v, -6, 6, -7, 5, 11, 12, "3A7CC8")
    fill(v, -5, 5, -10, -7, 7, 8, "1E2028")                   # Schirm
    fill(v, -1, 1, -8, -7, 9, 11, "FFD23E")                   # Posthorn-Abzeichen
    finish("gear_bote_helmet", [(v, False)], HEAD, yaw=-24, pitch=12)


def bote_vest():
    v = {}
    vest_shell(v, "FFD23E")
    fill(v, -5, 5, -5, -4, 2, 3, "2E6EB8")                    # blaue Säume
    fill(v, -5, 5, -5, -4, 6, 7, "2E6EB8")
    for z in range(2, 7):                                      # Riemen der Posttasche schräg
        x = 3 - (z - 2) * 2
        fill(v, x - 1, x + 1, -6, -5, z, z + 1, "6B4A2E")
    fill(v, 1, 4, -6, -5, 2, 4, "F4F6FA")                     # Brief in der Brusttasche
    v[(2, -7, 3)] = "D54144"
    finish("gear_bote_vest", [(v, False)], CHEST, yaw=-18, pitch=6)


def bote_charm():
    p = Part()
    p.torus(0.045, 0.014, (0, 0, 0), "FFD23E", r=rot(90, 0, 0), seg=14, tseg=6)
    p.cone(0.03, 0.06, (0.05, 0, 0.0), "FFC21E", r=rot(0, -90, 0), sides=10)
    p.cyl(0.008, 0.04, (-0.03, 0, 0.05), "6B4A2E", sides=6)
    finish_charm("gear_bote_charm", p)


# ---------------------------------------------------------------- Löschzug (rot/gelb)
def feuerwehr_helmet():
    v = {}
    dome(v, "D54144", 6, 8)
    fill(v, -1, 1, -7, 6, 12, 14, "E0B02E")                   # Kamm
    fill(v, -6, 6, 5, 8, 3, 7, "C2383C")                      # Nackenschutz
    carve(v, -5, 5, 5, 6, 3, 6)
    fill(v, -2, 2, -8, -7, 8, 11, "E0B02E")                   # Wappenschild vorn
    v[(-1, -9, 9)] = "D54144"
    v[(0, -9, 9)] = "D54144"
    fill(v, -7, 7, -8, 6, 7, 8, "C2383C")                     # Krempe
    carve(v, -5, 5, -5, 4, 7, 8)
    finish("gear_feuerwehr_helmet", [(v, False)], HEAD, yaw=-24, pitch=12)


def feuerwehr_vest():
    v = {}
    vest_shell(v, "3A4152")
    for z in (3, 5):                                           # Reflexstreifen
        fill(v, -5, 5, -6, -5, z, z + 1, "E8E070")
    fill(v, -5, -4, -6, 2, 3, 4, "E8E070")
    fill(v, 4, 5, -6, 2, 3, 4, "E8E070")
    fill(v, -1, 0, -6, -5, 2, 7, "E0B02E")                    # Reißverschluss
    finish("gear_feuerwehr_vest", [(v, False)], CHEST, yaw=-18, pitch=6)


def feuerwehr_charm():
    p = Part()
    p.cyl(0.05, 0.016, (0, 0, 0), "F2C230", r=rot(90, 0, 0), sides=16, bevel=0.005)
    p.box((0.05, 0.01, 0.016), (0, -0.01, 0), "D54144")
    p.box((0.016, 0.01, 0.05), (0, -0.01, 0), "D54144")
    p.box((0.05, 0.01, 0.03), (0, 0, 0.065), "D54144")       # Band
    finish_charm("gear_feuerwehr_charm", p)


# ---------------------------------------------------------------- Baustelle (orange/weiß)
def bau_helmet():
    v = {}
    dome(v, "F08A1E", 8, 6)
    fill(v, -7, 7, -9, 7, 8, 9, "F59A2E")                     # Krempe rundum
    carve(v, -5, 5, -5, 4, 8, 9)
    fill(v, -1, 1, -7, 6, 13, 14, "FFB04A")                   # Mittelrippe
    lamp = {}
    fill(v, -1, 1, -9, -8, 9, 11, "2E3340")                   # Lampengehäuse
    fill(lamp, -1, 1, -10, -9, 9, 11, "FFF3B0")               # Licht
    finish("gear_bau_helmet", [(v, False), (lamp, True)], HEAD, yaw=-24, pitch=12)


def bau_vest():
    v = {}
    vest_shell(v, "FF7A1E")
    for z in (3, 5):
        fill(v, -5, 5, -6, -5, z, z + 1, "E6EAF0")
        fill(v, -5, -4, -6, 2, z, z + 1, "E6EAF0")
        fill(v, 4, 5, -6, 2, z, z + 1, "E6EAF0")
    fill(v, 1, 3, -6, -5, 6, 7, "2E3340")                     # Stift in der Tasche
    finish("gear_bau_vest", [(v, False)], CHEST, yaw=-18, pitch=6)


def bau_charm():
    p = Part()
    p.box((0.12, 0.025, 0.035), (0, 0, 0), "FFD23E", bevel=0.006, segs=1)
    p.box((0.03, 0.028, 0.02), (0, -0.002, 0), "5BD06A", bevel=0.004, segs=1)
    p.ball(0.007, (0, -0.016, 0), "FFFFFF", subdiv=1)
    finish_charm("gear_bau_charm", p)


# ---------------------------------------------------------------- Tüftlerin (violett/türkis)
def erfinder_helmet():
    v = {}
    dome(v, "4C5878", 6, 7)
    fill(v, -6, 6, -9, -7, 10, 12, "3A4460")                  # hochgeklapptes Visier
    glass = {}
    fill(glass, -4, 4, -10, -9, 10, 12, "7FE3FF")
    fill(v, -7, -6, -1, 1, 7, 10, "9A5CE0")                   # Gelenke seitlich
    fill(v, 6, 7, -1, 1, 7, 10, "9A5CE0")
    fill(v, -1, 1, 0, 2, 11, 13, "9A5CE0")                    # Antennchen
    glass[(0, 1, 13)] = "FF4FD8"
    finish("gear_erfinder_helmet", [(v, False), (glass, True)], HEAD, yaw=-24, pitch=12)


def erfinder_vest():
    v = {}
    vest_shell(v, "F4F6FA")
    fill(v, -4, -1, -6, -5, 2, 4, "9A5CE0")                   # Taschen
    fill(v, 1, 4, -6, -5, 2, 4, "9A5CE0")
    for x, c in ((1, "FF4F6D"), (2, "42C95E"), (3, "2E86F0")):  # Stifte
        fill(v, x, x + 1, -6, -5, 4, 6, c)
    fill(v, -1, 0, -6, -5, 2, 7, "C9CED8")
    finish("gear_erfinder_vest", [(v, False)], CHEST, yaw=-18, pitch=6)


def erfinder_charm():
    p = Part()
    p.cyl(0.04, 0.016, (0, 0, 0), "E0A82E", r=rot(90, 0, 0), sides=12)
    for i in range(8):
        a = i * 45.0
        p.box((0.018, 0.016, 0.022), (0.045 * math.cos(math.radians(a)), 0, 0.045 * math.sin(math.radians(a))), "E0A82E", r=rot(0, -a, 0))
    p.cyl(0.014, 0.02, (0, 0, 0), "7FE3FF", r=rot(90, 0, 0), sides=8)
    finish_charm("gear_erfinder_charm", p)


# ---------------------------------------------------------------- Kundschafter (grün/braun)
def jaeger_helmet():
    v = {}
    dome(v, "3FA35A", 8, 6, 6.4, 6.0)
    fill(v, -8, 8, -9, 7, 8, 9, "2E7A44")                     # breite Krempe
    fill(v, -6, 6, -6, 5, 9, 10, "6B4A2E")                    # Hutband
    feather = {}
    fill(feather, 5, 6, 0, 2, 10, 16, "F4F6FA")               # Feder
    fill(feather, 6, 7, 1, 3, 12, 17, "FF7043")
    v.update(feather)
    finish("gear_jaeger_helmet", [(v, False)], HEAD, yaw=-24, pitch=12)


def jaeger_vest():
    v = {}
    vest_shell(v, camo(["4C7426", "3F6322", "5E8A2E", "6E9A38"], 21))
    fill(v, -4, -2, -6, -5, 2, 4, "6B5A45")                   # Taschen
    fill(v, 1, 3, -6, -5, 2, 4, "6B5A45")
    fill(v, -4, -2, -6, -5, 5, 6, "8A6A4A")                   # Patronenschlaufen
    finish("gear_jaeger_vest", [(v, False)], CHEST, yaw=-18, pitch=6)


def jaeger_charm():
    p = Part()
    p.ball(1.0, (0, 0, 0.0), "F4F6FA", scale=(0.026, 0.008, 0.075), subdiv=2)
    p.ball(1.0, (0, -0.003, 0.035), "8A6A4A", scale=(0.022, 0.008, 0.035), subdiv=1)
    p.ball(1.0, (0, -0.004, -0.05), "FF7043", scale=(0.016, 0.006, 0.02), subdiv=1)
    p.cyl(0.005, 0.15, (0, -0.006, -0.01), "4A3A2A", sides=5)
    finish_charm("gear_jaeger_charm", p)


# ---------------------------------------------------------------- Talfest (rosa/gold)
def fest_helmet():
    v = {}
    fill(v, -6, 6, -6, 5, 8, 10, "F07AB4")                    # Rand (Gummiband und Schirm)
    carve(v, -5, 5, -5, 4, 8, 10)
    for i, z in enumerate(range(9, 16)):                      # Kegel mit Streifen
        r = max(1, 5 - i * 5 // 7)
        fill(v, -r, r, -r - 1, r, z, z + 1, "FFD23E" if i % 2 else "F07AB4")
    fill(v, -1, 1, -2, 0, 16, 18, "F4F6FA")                   # Bommel
    finish("gear_fest_helmet", [(v, False)], HEAD, yaw=-24, pitch=12)


def fest_vest():
    v = {}
    vest_shell(v, lambda x, y, z: "F07AB4" if (x + z) % 2 else "F890C2")
    for x, z in ((-3, 3), (2, 5), (0, 2), (-2, 6), (3, 3)):   # goldene Sterne
        v[(x, -6, z)] = "FFD23E"
    finish("gear_fest_vest", [(v, False)], CHEST, yaw=-18, pitch=6)


def fest_charm():
    p = Part()
    p.ball(1.0, (0, 0, 0), "E8B060", scale=(0.05, 0.03, 0.032), subdiv=2)
    p.box((0.05, 0.004, 0.012), (0.03, -0.02, 0.0), "FFFFFF", r=rot(0, 20, 0))
    finish_charm("gear_fest_charm", p)


# ---------------------------------------------------------------- Tiefsee (Petrol/Messing)
def tiefsee_helmet():
    v = {}
    brass = lambda x, y, z: "D9A84A" if (x + y + z) % 3 else "C8963A"
    fill(v, -6, 6, -6, 5, -1, 11, brass)                      # runde Kugel um den Kopf
    for z in (-1, 10):
        for x in (-6, 5):
            for y in (-6, 4):
                v.pop((x, y, z), None)
    fill(v, -4, 4, -4, 3, 11, 12, "C8963A")                   # Kuppel oben
    carve(v, -5, 5, -5, 4, -1, 10)                            # innen frei
    carve(v, -4, 4, -6, -5, 1, 8)                             # Fenster vor dem Gesicht
    fill(v, -5, 5, -7, -6, 0, 1, "8A6A2A")                    # Fensterrahmen (Schrauben)
    fill(v, -5, 5, -7, -6, 8, 9, "8A6A2A")
    fill(v, -5, -4, -7, -6, 1, 8, "8A6A2A")
    fill(v, 4, 5, -7, -6, 1, 8, "8A6A2A")
    fill(v, -1, 1, 5, 7, 4, 7, "8A94A8")                      # Luftanschluss hinten
    fill(v, -7, -6, -1, 1, 4, 6, "8A6A2A")                    # Seitenfenster-Rahmen
    fill(v, 6, 7, -1, 1, 4, 6, "8A6A2A")
    finish("gear_tiefsee_helmet", [(v, False)], HEAD, yaw=-24, pitch=10)


def tiefsee_vest():
    v = {}
    vest_shell(v, "1F6E8C")
    for x in (-4, -2, 1, 3):                                  # Bleigewichte
        fill(v, x, x + 1, -6, -5, 2, 4, "6F7C96")
    fill(v, -5, 5, -6, -5, 4, 5, "F2C230")                    # Gurt
    fill(v, -1, 1, -7, -6, 4, 5, "C9CED8")                    # Schnalle
    finish("gear_tiefsee_vest", [(v, False)], CHEST, yaw=-18, pitch=6)


def tiefsee_charm():
    p = Part()
    for i in range(5):
        a = math.radians(-60 + i * 30)
        p.box((0.014, 0.012, 0.07), (0.035 * math.sin(a), 0, 0.035 * math.cos(a) - 0.02), "F6C8B0" if i % 2 else "F0A890", r=rot(0, math.degrees(a), 0), bevel=0.004, segs=1)
    p.ball(0.018, (0, 0, -0.03), "F0A890", subdiv=1)
    p.torus(0.03, 0.004, (0, 0, 0.05), "7FD8E8", r=rot(90, 0, 0), seg=10, tseg=4)
    finish_charm("gear_tiefsee_charm", p)


ALL = {}
for _s in ("bote", "feuerwehr", "bau", "erfinder", "jaeger", "fest", "tiefsee"):
    for _p in ("helmet", "vest", "charm"):
        ALL["gear_%s_%s" % (_s, _p)] = globals()["%s_%s" % (_s, _p)]


if __name__ == "__main__":
    want = sys.argv[1:] or list(ALL)
    for n in want:
        ALL[n]()
