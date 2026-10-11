"""Gemeinsame Helfer für towers.py, props.py und enemies.py (baut nur auf kit.py auf).

Als Programm:  python3 blender/rw_util.py sheet <ausgabe.png> <name> [name ...]   -> Kontaktbogen der Symbole
               python3 blender/rw_util.py nodes <name> [name ...]                 -> Knotennamen der .glb-Dateien
"""
import sys, os, json, struct, shutil
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from kit import *


def T(x=0.0, y=0.0, z=0.0):
    return Matrix.Translation(Vector((x, y, z)))


def S(x=1.0, y=None, z=None):
    if y is None:
        y = x
    if z is None:
        z = x
    return Matrix.Diagonal(Vector((x, y, z, 1.0)))


class KPart(Part):
    """Part, dessen Grundkörper alle um den Faktor k (um den Objektursprung) vergrößert werden."""

    def __init__(self, k=1.0):
        super().__init__()
        self.k = k

    def _finish(self, geom_faces, color, mat):
        super()._finish(geom_faces, color, S(self.k) @ mat)


class MPart(Part):
    """Part, dessen Grundkörper alle zusätzlich mit der Matrix m verschoben/gedreht werden (m ist änderbar)."""

    def __init__(self, m=None):
        super().__init__()
        self.m = m if m is not None else Matrix.Identity(4)

    def _finish(self, geom_faces, color, mat):
        super()._finish(geom_faces, color, self.m @ mat)


def limb(p, a, b, r1, r2=None, color="wood_d", sides=7):
    """Ast/Stange von Punkt a nach Punkt b."""
    a, b = Vector(a), Vector(b)
    d = b - a
    p.cyl(r1, d.length, (0, 0, 0), color, r=T(*((a + b) * 0.5)) @ face_to(d), r2=r2, sides=sides)
    return p


def vary(c, rng, amt=0.08):
    return shade(c, 1.0 + rng.uniform(-amt, amt))


AX_Y = rot(90, 0, 0)      # Zylinderachse Z -> -Y (oben = vorn)
AX_X = rot(0, 90, 0)      # Zylinderachse Z -> +X


def face_to(n):
    """Drehung, die die lokale Z-Achse auf die Richtung n legt."""
    return Vector((0, 0, 1)).rotation_difference(Vector(n).normalized()).to_matrix().to_4x4()


def star(p, c, R, color="white", thick=0.06, r=None, inner=0.42):
    """Fünfzackiger Stern, liegt in der lokalen XY-Ebene (zeigt nach +Z). r = Ausrichtung, c = Mitte."""
    base = T(*c) @ (r if r is not None else Matrix.Identity(4))
    b = R * inner
    for i in range(5):
        m = base @ rot(0, 0, i * 72) @ T(0, R * 0.5, 0) @ rot(-90, 0, 0) @ S(1, thick / (2 * b), 1)
        p.cone(b, R, (0, 0, 0), color, r=m, sides=4)
    return p


STAR_FRONT = rot(90, 0, 0)   # Stern schaut nach -Y (vorn)


def tris(ob):
    ob.data.calc_loop_triangles()
    return len(ob.data.loop_triangles)


def report(name):
    parts, total = [], 0
    for ob in bpy.context.scene.objects:
        if ob.type == "MESH":
            n = tris(ob)
            total += n
            parts.append("%s=%d" % (ob.name, n))
    empties = [ob.name for ob in bpy.context.scene.objects if ob.type == "EMPTY" and ob.parent is not None]
    print("TRIS %-22s %5d  [%s]%s" % (name, total, ", ".join(parts), ("  empties: " + ", ".join(empties)) if empties else ""), flush=True)
    return total


def finish(name, yaw=-35.0, pitch=24.0, size=256, glb=True, copies=(), margin=1.12, hide=()):
    """Zählt Dreiecke, speichert .blend/.glb und rendert das Symbol (plus Kopien unter anderen Namen).
    hide = Namensanfänge von Objekten, die im Symbol nicht erscheinen sollen (z. B. Ausbauteile "lv")."""
    report(name)
    if glb:
        save(name)
    for ob in list(bpy.context.scene.objects):
        if hide and ob.name.startswith(tuple(hide)):
            bpy.data.objects.remove(ob, do_unlink=True)
    icon(name, size, yaw=yaw, pitch=pitch, margin=margin)
    for c in copies:
        shutil.copyfile(os.path.join(OUT_ICON, name + ".png"), os.path.join(OUT_ICON, c + ".png"))


def run(table, argv):
    names = argv[1:] or list(table.keys())
    for n in names:
        if n not in table:
            print("unbekannt:", n)
            continue
        f = table[n]
        f() if not isinstance(f, tuple) else f[0](*f[1:])
        print("ok", n, flush=True)


# ------------------------------------------------------------------ Prüfwerkzeuge
def glb_nodes(name):
    with open(os.path.join(OUT_GLB, name + ".glb"), "rb") as f:
        f.read(12)
        ln, _ = struct.unpack("<II", f.read(8))
        js = json.loads(f.read(ln))
    return js.get("nodes", [])


def sheet(out, names, cols=8, cell=200):
    from PIL import Image, ImageDraw
    rows = (len(names) + cols - 1) // cols
    im = Image.new("RGB", (cols * cell, rows * (cell + 16)), "#0F2742")
    d = ImageDraw.Draw(im)
    for i, n in enumerate(names):
        x, y = (i % cols) * cell, (i // cols) * (cell + 16)
        fp = os.path.join(OUT_ICON, n + ".png")
        if os.path.exists(fp):
            ic = Image.open(fp).convert("RGBA").resize((cell, cell), Image.LANCZOS)
            im.paste(ic, (x, y), ic)
        else:
            d.text((x + 6, y + 60), "FEHLT", fill="#FF5050")
        d.text((x + 4, y + cell + 2), n, fill="#FFFFFF")
    im.save(out)
    print("sheet", out)


if __name__ == "__main__":
    if len(sys.argv) > 3 and sys.argv[1] == "sheet":
        sheet(sys.argv[2], sys.argv[3:])
    elif len(sys.argv) > 2 and sys.argv[1] == "nodes":
        for n in sys.argv[2:]:
            print(n, [x.get("name") for x in glb_nodes(n)])
