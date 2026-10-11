"""Rustwall – Baukasten für alle Modelle (Blender 4.2+ / 5.x, Python-Modul bpy).

Jedes Modell wird per Skript in Blender gebaut, als .blend gespeichert (blender/blend/),
als .glb für Godot exportiert (models/) und bei Bedarf als Symbol gerendert (icons/).

Achsen: Blender Z = oben, Vorderseite des Modells zeigt nach -Y  ->  in Godot +Z.
Farben liegen als Vertex-Farben (Attribut "Col", linear) auf dem Mesh; ein Material für alles.
Objekte, deren Name auf "_glow" endet, leuchten in Godot (Fenster, Lampen).
"""
import bpy, bmesh, math, os, random
from mathutils import Vector, Matrix, Euler

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT_GLB = os.path.join(ROOT, "models")
OUT_BLEND = os.path.join(ROOT, "blender", "blend")
OUT_ICON = os.path.join(ROOT, "icons")
for d in (OUT_GLB, OUT_BLEND, OUT_ICON):
    os.makedirs(d, exist_ok=True)

# Palette (gleich wie src/data.gd)
C = dict(navy="0F2742", sky="38A9F5", gold="FFD23E", coin="FDCA14", grass="8FB02A", grass_d="4F7A2A", pine="3D6B3A",
         path="EDA865", rock="9A8F96", rock_d="5E5868", water="5DB2EA", stone="A7ADC6", blue="3C5CA4", sand="E8AE64",
         wood="A9622F", wood_d="7A4522", olive="9C9A4A", helm="0469CC", suit="E08A2E", red="D54144", red_d="9D2A35",
         slime="94B128", slime_l="C4DB45", fire="FD932C", flag="026AED", skin="F2C29B", dark="2E3340", steel="8A94A8",
         white="F4F6FA", black="181A22", glow="FFD24D", tire="23262E", brass="E0A82E")


def col(c):
    """Hex-Farbe oder Palettenname -> lineares RGBA."""
    if isinstance(c, (tuple, list)):
        return tuple(c) if len(c) == 4 else (c[0], c[1], c[2], 1.0)
    h = C.get(c, c).lstrip("#")
    out = []
    for i in (0, 2, 4):
        v = int(h[i:i + 2], 16) / 255.0
        out.append(v / 12.92 if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4)
    return (out[0], out[1], out[2], 1.0)


def shade(c, k):
    """Farbe heller (k > 1) oder dunkler (k < 1)."""
    r, g, b, a = col(c)
    return (min(r * k, 1.0), min(g * k, 1.0), min(b * k, 1.0), a)


def mix(a, b, t):
    a = col(a); b = col(b)
    return tuple(a[i] + (b[i] - a[i]) * t for i in range(4))


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)


_mat = {}

def material(glow=False):
    key = "RW_Glow" if glow else "RW_Toon"
    if key in bpy.data.materials:
        return bpy.data.materials[key]
    m = bpy.data.materials.new(key)
    m.use_nodes = True
    nt = m.node_tree
    bsdf = nt.nodes["Principled BSDF"]
    at = nt.nodes.new("ShaderNodeAttribute")
    at.attribute_name = "Col"
    nt.links.new(at.outputs["Color"], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = 0.55
    if glow:
        nt.links.new(at.outputs["Color"], bsdf.inputs["Emission Color"])
        bsdf.inputs["Emission Strength"].default_value = 2.5
    return m


def rot(x=0.0, y=0.0, z=0.0):
    """Drehung in Grad (X, Y, Z)."""
    return Euler((math.radians(x), math.radians(y), math.radians(z)), "XYZ").to_matrix().to_4x4()


class Part:
    """Sammelt Grundkörper zu EINEM Mesh mit Vertex-Farben."""

    def __init__(self):
        self.bm = bmesh.new()
        self.layer = self.bm.loops.layers.float_color.new("Col")

    def _finish(self, geom_faces, color, mat):
        c = col(color)
        verts = set()
        for f in geom_faces:
            f.smooth = True
            for l in f.loops:
                l[self.layer] = c
                verts.add(l.vert)
        for v in verts:
            v.co = mat @ v.co

    def _new_faces(self, before):
        return [f for f in self.bm.faces if f not in before]

    def box(self, size, loc=(0, 0, 0), color="stone", r=None, bevel=0.0, segs=2):
        """Quader. size = (x, y, z), loc = Mittelpunkt. bevel = Rundung der Kanten in Metern."""
        before = set(self.bm.faces)
        res = bmesh.ops.create_cube(self.bm, size=1.0)
        vs = res["verts"]
        bmesh.ops.scale(self.bm, vec=Vector(size), verts=vs)
        if bevel > 0.0:
            b = min(bevel, min(size) * 0.45)
            edges = list({e for v in vs for e in v.link_edges})
            bmesh.ops.bevel(self.bm, geom=edges, offset=b, segments=segs, profile=0.5, affect="EDGES")
        m = Matrix.Translation(Vector(loc)) @ (r if r is not None else Matrix.Identity(4))
        self._finish(self._new_faces(before), color, m)
        return self

    def cyl(self, radius, height, loc=(0, 0, 0), color="steel", r=None, r2=None, sides=20, bevel=0.0, segs=2):
        """Zylinder/Kegelstumpf entlang Z. loc = Mittelpunkt. r2 = Radius oben (Standard: gleich)."""
        before = set(self.bm.faces)
        res = bmesh.ops.create_cone(self.bm, cap_ends=True, cap_tris=False, segments=sides, radius1=radius,
                                    radius2=radius if r2 is None else max(r2, 0.0001), depth=height)
        vs = res["verts"]
        if bevel > 0.0:
            edges = [e for e in {e for v in vs for e in v.link_edges} if abs(e.verts[0].co.z - e.verts[1].co.z) < 1e-5]
            bmesh.ops.bevel(self.bm, geom=edges, offset=min(bevel, radius * 0.45, height * 0.45), segments=segs, profile=0.5, affect="EDGES")
        m = Matrix.Translation(Vector(loc)) @ (r if r is not None else Matrix.Identity(4))
        self._finish(self._new_faces(before), color, m)
        return self

    def cone(self, radius, height, loc=(0, 0, 0), color="pine", r=None, sides=12):
        return self.cyl(radius, height, loc, color, r, r2=0.0, sides=sides)

    def ball(self, radius, loc=(0, 0, 0), color="slime", r=None, scale=(1, 1, 1), subdiv=3):
        """Kugel (Ikosphäre). scale verzerrt sie zu einem Ei/Kissen."""
        before = set(self.bm.faces)
        res = bmesh.ops.create_icosphere(self.bm, subdivisions=subdiv, radius=radius)
        m = Matrix.Translation(Vector(loc)) @ (r if r is not None else Matrix.Identity(4)) @ Matrix.Diagonal(Vector((scale[0], scale[1], scale[2], 1.0)))
        self._finish(self._new_faces(before), color, m)
        return self

    def torus(self, radius, tube, loc=(0, 0, 0), color="tire", r=None, seg=20, tseg=8):
        before = set(self.bm.faces)
        ring = []
        for i in range(seg):
            a = 2 * math.pi * i / seg
            row = []
            for j in range(tseg):
                b = 2 * math.pi * j / tseg
                rr = radius + tube * math.cos(b)
                row.append(self.bm.verts.new((rr * math.cos(a), rr * math.sin(a), tube * math.sin(b))))
            ring.append(row)
        for i in range(seg):
            for j in range(tseg):
                self.bm.faces.new((ring[i][j], ring[(i + 1) % seg][j], ring[(i + 1) % seg][(j + 1) % tseg], ring[i][(j + 1) % tseg]))
        m = Matrix.Translation(Vector(loc)) @ (r if r is not None else Matrix.Identity(4))
        self._finish(self._new_faces(before), color, m)
        return self

    def voxels(self, vox, size, origin=(0, 0, 0)):
        """Voxel-Modell: vox = {(x, y, z): Farbe}. Nur sichtbare Flächen werden erzeugt.
        size = Kantenlänge eines Voxels, origin = Lage der Voxel-Ecke (0, 0, 0)."""
        ox, oy, oz = origin
        dirs = [((1, 0, 0), [(1, 0, 0), (1, 1, 0), (1, 1, 1), (1, 0, 1)]), ((-1, 0, 0), [(0, 1, 0), (0, 0, 0), (0, 0, 1), (0, 1, 1)]),
                ((0, 1, 0), [(1, 1, 0), (0, 1, 0), (0, 1, 1), (1, 1, 1)]), ((0, -1, 0), [(0, 0, 0), (1, 0, 0), (1, 0, 1), (0, 0, 1)]),
                ((0, 0, 1), [(0, 0, 1), (1, 0, 1), (1, 1, 1), (0, 1, 1)]), ((0, 0, -1), [(0, 1, 0), (1, 1, 0), (1, 0, 0), (0, 0, 0)])]
        cache = {}
        def vert(p):
            v = cache.get(p)
            if v is None:
                v = self.bm.verts.new((ox + p[0] * size, oy + p[1] * size, oz + p[2] * size))
                cache[p] = v
            return v
        for (x, y, z), c in vox.items():
            cc = col(c)
            for d, quad in dirs:
                if (x + d[0], y + d[1], z + d[2]) in vox:
                    continue
                f = self.bm.faces.new([vert((x + q[0], y + q[1], z + q[2])) for q in quad])
                f.smooth = False
                # leichte Schattierung je Richtung: wirkt plastischer, auch ohne Licht
                k = 1.0 if d[2] > 0 else (0.72 if d[2] < 0 else (0.93 if d[0] != 0 else 0.86))
                for l in f.loops:
                    l[self.layer] = (cc[0] * k, cc[1] * k, cc[2] * k, 1.0)
        return self

    def build(self, name, parent=None, loc=(0, 0, 0), sharp_angle=38.0, glow=False):
        """Erzeugt das Blender-Objekt. loc = Lage des Ursprungs (Drehpunkt) relativ zum Elternobjekt."""
        me = bpy.data.meshes.new(name)
        bmesh.ops.remove_doubles(self.bm, verts=self.bm.verts, dist=0.00001)
        self.bm.normal_update()
        self.bm.to_mesh(me)
        self.bm.free()
        try:
            me.set_sharp_from_angle(angle=math.radians(sharp_angle))
        except Exception:
            pass
        me.color_attributes.active_color = me.color_attributes["Col"]
        me.color_attributes.render_color_index = 0
        ob = bpy.data.objects.new(name, me)
        bpy.context.scene.collection.objects.link(ob)
        me.materials.append(material(glow or name.endswith("_glow")))
        ob.location = loc
        if parent is not None:
            ob.parent = parent
        return ob


def empty(name, parent=None, loc=(0, 0, 0)):
    ob = bpy.data.objects.new(name, None)
    bpy.context.scene.collection.objects.link(ob)
    ob.location = loc
    if parent is not None:
        ob.parent = parent
    return ob


def bake_ao(strength=0.55, samples=16, distance=1.2):
    """Rechnet Umgebungsverschattung in die Vertex-Farben aller Mesh-Objekte: Ecken und Fugen werden dunkler.
    Vor save() aufrufen. Leuchtende Objekte (*_glow) bleiben unverändert."""
    sc = bpy.context.scene
    obs = [o for o in sc.objects if o.type == "MESH" and not o.name.endswith("_glow") and "Col" in o.data.color_attributes]
    if not obs:
        return
    sc.render.engine = "CYCLES"
    sc.cycles.device = "CPU"
    sc.cycles.samples = samples
    if sc.world is None:
        sc.world = bpy.data.worlds.new("W")
    sc.world.light_settings.distance = distance
    for o in obs:
        me = o.data
        if "AO" in me.color_attributes:
            me.color_attributes.remove(me.color_attributes["AO"])
        me.color_attributes.active_color = me.color_attributes.new("AO", "FLOAT_COLOR", "CORNER")
    bpy.ops.object.select_all(action="DESELECT")
    for o in obs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = obs[0]
    sc.render.bake.target = "VERTEX_COLORS"
    bpy.ops.object.bake(type="AO")
    for o in obs:
        me = o.data
        ao = me.color_attributes["AO"]
        colr = me.color_attributes["Col"]
        for i in range(len(colr.data)):
            k = 1.0 - strength * (1.0 - min(1.0, ao.data[i].color[0] * 1.15))
            c = colr.data[i].color
            colr.data[i].color = (c[0] * k, c[1] * k, c[2] * k, c[3])
        me.color_attributes.remove(ao)
        me.color_attributes.active_color = me.color_attributes["Col"]
        me.color_attributes.render_color_index = 0
    bpy.ops.object.select_all(action="DESELECT")


def save(name):
    """Speichert die Szene als .blend und exportiert sie als .glb."""
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT_BLEND, name + ".blend"))
    bpy.ops.export_scene.gltf(filepath=os.path.join(OUT_GLB, name + ".glb"), export_format="GLB", export_apply=True,
                              export_vertex_color="ACTIVE", export_all_vertex_colors=False, export_materials="EXPORT",
                              export_cameras=False, export_lights=False, export_yup=True, export_animations=False)


def save_rigged(name, animations=False, blend=True, selection=False):
    """Wie save(), aber mit Skelett und Bindung (Skinning) und auf Wunsch mit allen Actions als Animationen
    (je Action eine NLA-Spur). selection=True exportiert nur die ausgewählten Objekte.
    Für Figuren mit dem Skelett aus rig_human.py. save() bleibt für starre Modelle unverändert."""
    if blend:
        bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT_BLEND, name + ".blend"))
    bpy.ops.export_scene.gltf(filepath=os.path.join(OUT_GLB, name + ".glb"), export_format="GLB", export_apply=True,
                              export_vertex_color="ACTIVE", export_all_vertex_colors=False, export_materials="EXPORT",
                              export_cameras=False, export_lights=False, export_yup=True, export_skins=True, use_selection=selection,
                              export_def_bones=False, export_rest_position_armature=True, export_reset_pose_bones=True,
                              export_animations=animations, export_animation_mode="ACTIONS", export_force_sampling=True,
                              export_optimize_animation_size=True, export_optimize_animation_keep_anim_armature=False,
                              export_anim_slide_to_zero=True, export_morph=False)


def bind(ob, bone):
    """Bindet alle Punkte eines Mesh-Objekts starr (Gewicht 1,0) an genau einen Knochen."""
    vg = ob.vertex_groups.new(name=bone)
    vg.add(list(range(len(ob.data.vertices))), 1.0, "REPLACE")
    return ob


def skin(parts, armature, name="body"):
    """Fügt gebundene Teile zu EINEM Mesh zusammen und hängt es mit Armature-Modifier an das Skelett."""
    for o in parts:
        o.parent = None
    bpy.context.view_layer.update()
    with bpy.context.temp_override(active_object=parts[0], selected_editable_objects=list(parts), selected_objects=list(parts), object=parts[0]):
        bpy.ops.object.join()
    ob = parts[0]
    ob.name = name
    ob.data.name = name
    ob.parent = armature
    mod = ob.modifiers.new("Armature", "ARMATURE")
    mod.object = armature
    me = ob.data
    me.color_attributes.active_color = me.color_attributes["Col"]
    me.color_attributes.render_color_index = 0
    return ob


def icon(name, size=256, yaw=35.0, pitch=24.0, margin=1.12, samples=24):
    """Rendert alle Mesh-Objekte der Szene freigestellt als Symbol (icons/<name>.png)."""
    sc = bpy.context.scene
    pts = []
    for ob in sc.objects:
        if ob.type == "MESH":
            for corner in ob.bound_box:
                pts.append(ob.matrix_world @ Vector(corner))
    if not pts:
        return
    lo = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
    hi = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
    ctr = (lo + hi) * 0.5
    cam = bpy.data.cameras.new("IconCam")
    cam.type = "ORTHO"
    co = bpy.data.objects.new("IconCam", cam)
    sc.collection.objects.link(co)
    e = Euler((math.radians(90.0 - pitch), 0.0, math.radians(yaw)), "XYZ")
    co.rotation_euler = e
    back = e.to_matrix() @ Vector((0, 0, 1))
    co.location = ctr + back * 50.0
    inv = e.to_matrix().inverted()
    xs = [(inv @ (p - ctr)).x for p in pts]
    ys = [(inv @ (p - ctr)).y for p in pts]
    cam.ortho_scale = max(max(xs) - min(xs), max(ys) - min(ys)) * margin
    co.location += e.to_matrix() @ Vector(((max(xs) + min(xs)) * 0.5, (max(ys) + min(ys)) * 0.5, 0))
    cam.clip_end = 200.0
    sc.camera = co
    added = [co]
    for nm, energy, rx, rz, colr in (("Key", 3.2, 50, yaw - 40, (1.0, 0.96, 0.9)), ("Fill", 1.3, 65, yaw + 110, (0.75, 0.85, 1.0)), ("Top", 0.9, 5, 0, (1, 1, 1))):
        l = bpy.data.lights.new(nm, "SUN")
        l.energy = energy
        l.color = colr
        l.angle = math.radians(12)
        lo2 = bpy.data.objects.new(nm, l)
        lo2.rotation_euler = (math.radians(rx), 0, math.radians(rz))
        sc.collection.objects.link(lo2)
        added.append(lo2)
    if sc.world is None:
        sc.world = bpy.data.worlds.new("W")
    sc.world.use_nodes = True
    bg = sc.world.node_tree.nodes.get("Background")
    if bg:
        bg.inputs[0].default_value = (0.55, 0.62, 0.8, 1.0)
        bg.inputs[1].default_value = 0.55
    sc.render.engine = "CYCLES"
    sc.cycles.device = "CPU"
    sc.cycles.samples = samples
    sc.cycles.use_denoising = False
    sc.render.film_transparent = True
    sc.render.resolution_x = size
    sc.render.resolution_y = size
    sc.render.image_settings.file_format = "PNG"
    sc.render.image_settings.color_mode = "RGBA"
    sc.view_settings.view_transform = "Standard"
    sc.render.filepath = os.path.join(OUT_ICON, name + ".png")
    bpy.ops.render.render(write_still=True)
    for o in added:
        bpy.data.objects.remove(o, do_unlink=True)


def hash3(x, y, z, seed=0):
    """Fester Zufallswert 0..1 für eine Gitterposition (für Tarnmuster usw.)."""
    n = (x * 73856093) ^ (y * 19349663) ^ (z * 83492791) ^ (seed * 2654435761)
    n = (n ^ (n >> 13)) * 1274126177
    return ((n ^ (n >> 16)) & 0xFFFF) / 65535.0
