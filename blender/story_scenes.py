"""V6 Paket E (Geschichte): vorgerenderte Gebietsbilder für die Berichte der Auto-Expeditionen und die Chronik.
  icons/scene_<gebiet>.png   640 × 360, je Gebiet: Boden in den Gebietsfarben (src/data.gd AREAS), Weg, Bäume und Felsen
                             des Gebiets, das Wahrzeichen (models/lm_<gebiet>.glb) – aus den fertigen Spielmodellen (models/*.glb).
Der Held wird im Spiel davorgesetzt (UI.hero_pic), damit jedes Bild zu jedem Helden passt.
Aufruf: python3 blender/story_scenes.py [gebiet ...]   (ohne Namen: alle Gebiete)"""
import sys, os, math, random
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy
from mathutils import Vector, Euler
import kit
from kit import reset, col

ROOT = kit.ROOT
AREAS = {
    # gebiet: (boden, boden2, weg, nebel/himmel, sonne, baum, felsen, wasser)
    "gruental": ("8FB02A", "6E9A2B", "EDA865", "CFE6F5", "FFF0CF", "pine", "p_rock_%d", "5DB2EA"),
    "forst": ("5C8A3A", "3F6B35", "B98A5A", "A9C6B5", "E9F0CF", "pine_dense", "p_rock_%d", None),
    "staub": ("E0B46A", "C99A52", "9A6B45", "F0D8A8", "FFE6B0", "cactus", "p_rock_%d", None),
    "kueste": ("EBD79A", "D6BE7C", "B99B6A", "CFEAF5", "FFF4D8", "palm", "p_beach_rock_%d", "4FA3D9"),
    "sumpf": ("6F8A4A", "55703E", "7A6A52", "A8C89A", "DDEBB8", "dead", "p_rock_%d", "7FA05A"),
    "frost": ("DCE7F2", "BFD2E6", "B8C8DA", "E6F0FA", "F4F8FF", "snowpine", "p_rock_snow_%d", None),
    "krater": ("7FB23A", "5E9A30", "A6D24A", "C8F09A", "EAFFC0", "crystal", "p_rock_%d", "8EDB3A"),
    "vulkan": ("4C4648", "37302F", "7A5E4C", "A8948C", "FFE0B8", "lava", "p_rock_lava_%d", None),
    "stadt": ("707868", "5C6654", "4A4D50", "C4CCD2", "FFF0D8", "city", "p_st_rubble_%d", None),
}
W, H = 640, 360


def _mat_for(ob):
    me = ob.data
    if not me.color_attributes:
        return
    cname = me.color_attributes[0].name
    key = "IMP_" + cname + ("_glow" if "_glow" in ob.name else "")
    m = bpy.data.materials.get(key)
    if m is None:
        m = bpy.data.materials.new(key)
        m.use_nodes = True
        nt = m.node_tree
        bsdf = nt.nodes["Principled BSDF"]
        at = nt.nodes.new("ShaderNodeAttribute")
        at.attribute_name = cname
        nt.links.new(at.outputs["Color"], bsdf.inputs["Base Color"])
        bsdf.inputs["Roughness"].default_value = 0.6
        if "_glow" in ob.name:
            nt.links.new(at.outputs["Color"], bsdf.inputs["Emission Color"])
            bsdf.inputs["Emission Strength"].default_value = 2.0
    me.materials.clear()
    me.materials.append(m)


def place(name, loc, yaw=0.0, s=1.0):
    path = os.path.join(ROOT, "models", name + ".glb")
    if not os.path.exists(path):
        return None
    before = set(bpy.context.scene.objects)
    bpy.ops.import_scene.gltf(filepath=path)
    new = [o for o in bpy.context.scene.objects if o not in before]
    roots = [o for o in new if o.parent is None or o.parent not in new]
    for o in new:
        if o.type == "MESH":
            _mat_for(o)
        if o.name.startswith("fx_") or o.type == "EMPTY" and o.name in ("door", "work_1", "work_2", "drop", "bubble"):
            pass
    for r in roots:
        r.location = Vector(loc)
        r.rotation_mode = "XYZ"
        r.rotation_euler = Euler((r.rotation_euler.x, r.rotation_euler.y, yaw))
        r.scale = (s, s, s)
    return roots


def flat(name, size, loc, color, z=0.0, rot=0.0, sides=None):
    import bmesh
    me = bpy.data.meshes.new(name)
    bm = bmesh.new()
    if sides:
        bmesh.ops.create_circle(bm, cap_ends=True, segments=sides, radius=size[0] / 2)
    else:
        bmesh.ops.create_grid(bm, x_segments=1, y_segments=1, size=0.5)
        for v in bm.verts:
            v.co.x *= size[0]
            v.co.y *= size[1]
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    ob.location = (loc[0], loc[1], z)
    ob.rotation_euler = (0, 0, rot)
    if sides:
        ob.scale = (1.0, size[1] / size[0], 1.0)
    m = bpy.data.materials.new(name + "_m")
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = col(color)
    b.inputs["Roughness"].default_value = 0.95
    me.materials.append(m)
    return ob


def scene(key):
    g, g2, path, fog, sun_c, tree, rock_fmt, water = AREAS[key]
    reset()
    rng = random.Random(key)
    sc = bpy.context.scene
    flat("ground", (200, 200), (0, 0), g, 0.0)
    for i in range(18):
        a = rng.uniform(0, math.tau)
        r = rng.uniform(3, 34)
        d = rng.uniform(3, 9)
        flat("patch%d" % i, (d, d * rng.uniform(0.5, 1.0)), (math.cos(a) * r, math.sin(a) * r + 12), g2, 0.01 + i * 0.001, rng.uniform(0, 3), sides=16)
    flat("path", (3.0, 40.0), (-1.0, 14.0), path, 0.03, 0.1)
    if water:
        flat("water", (220, 70), (0, 66), water, 0.05)
    # Wahrzeichen hinten, Bäume ringsum (vorn frei für den Helden), Felsen
    place("lm_" + key, (3.0, 24.0, 0), math.radians(15), 1.5)
    placed = [(3.0, 24.0)]
    kinds = [n for n in ("p_tree_%s_%d" % (tree, i) for i in (1, 2, 3)) if os.path.exists(os.path.join(ROOT, "models", n + ".glb"))]
    tries = 0
    while len(placed) < 34 and tries < 500 and kinds:
        tries += 1
        x = rng.uniform(-30, 30)
        y = rng.uniform(2, 40)
        if y < 9 and abs(x) < 9:
            continue
        if abs(x - 3.0) < 7 and abs(y - 24) < 7:
            continue
        if any((x - px) ** 2 + (y - py) ** 2 < 10 for (px, py) in placed):
            continue
        placed.append((x, y))
        place(rng.choice(kinds), (x, y, 0), rng.uniform(0, math.tau), rng.uniform(0.9, 1.4))
    rocks = [n for n in (rock_fmt % i for i in (1, 2, 3)) if os.path.exists(os.path.join(ROOT, "models", n + ".glb"))]
    for i in range(9):
        x = rng.uniform(-18, 18)
        y = rng.uniform(4, 26)
        if abs(x) < 6 and y < 12:
            continue
        if rocks:
            place(rng.choice(rocks), (x, y, 0), rng.uniform(0, math.tau), rng.uniform(0.8, 1.7))
    # Himmel, Sonne, Kamera
    world = bpy.data.worlds.new("W")
    sc.world = world
    world.use_nodes = True
    bg = world.node_tree.nodes["Background"]
    fc = col(fog)
    sky = col("8EC3F0")
    bg.inputs["Color"].default_value = tuple(fc[i] * 0.65 + sky[i] * 0.35 for i in range(3)) + (1.0,)
    bg.inputs["Strength"].default_value = 1.0
    sd = bpy.data.lights.new("sun", "SUN")
    sd.energy = 3.4
    sd.color = col(sun_c)[:3]
    sd.angle = math.radians(8)
    so = bpy.data.objects.new("sun", sd)
    sc.collection.objects.link(so)
    so.rotation_euler = Euler((math.radians(48), math.radians(12), math.radians(-35)))
    cam = bpy.data.cameras.new("cam")
    cam.lens = 30
    co = bpy.data.objects.new("cam", cam)
    sc.collection.objects.link(co)
    co.location = (-6.0, -13.0, 9.5)
    target = Vector((1.5, 17.0, 3.2))
    d = target - co.location
    co.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()
    sc.camera = co
    sc.render.engine = "CYCLES"
    sc.cycles.device = "CPU"
    sc.cycles.samples = int(os.environ.get("SCENE_SAMPLES", "20"))
    sc.cycles.use_denoising = True
    sc.render.resolution_x = W
    sc.render.resolution_y = H
    sc.render.film_transparent = False
    sc.view_settings.view_transform = "Standard"
    sc.render.image_settings.file_format = "PNG"
    sc.render.filepath = os.path.join(ROOT, "icons", "scene_%s.png" % key)
    bpy.ops.render.render(write_still=True)
    print("ok scene_%s" % key, flush=True)


if __name__ == "__main__":
    keys = [a for a in sys.argv[1:] if a in AREAS] or list(AREAS)
    for k in keys:
        scene(k)
