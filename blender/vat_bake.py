"""Rustwall – Animations-Textur brennen (Vertex-Animation-Texture) und Bildtafeln rendern.

bake_vat(key)     wertet für jedes gespeicherte Bild jedes Clips die Welt-Position und Normale jedes Eckpunkts aus
                  (scene.frame_set + ausgewertetes Mesh, also mit Keyframes, Eltern-Ketten, Modifikatoren, Armaturen) und schreibt
                    models/e_<key>.glb       ein Mesh "body" in Ruhepose: Vertex-Farben, UV 1 = (Leuchten, Kennung), UV 2 = Spalte/Zeile in der Textur
                    models/e_<key>_vat.png   drei Blöcke untereinander, je R Zeilen: Position obere 8 Bit, Position untere 8 Bit, Normale
                                             (RGB, 8 Bit, ohne Alpha – übersteht den Standard-Import von Godot verlustfrei)
                    models/e_<key>.json      Clips (Startzeile, Bildzahl, Dauer, Schleife, Schrittlänge, Treffer-Zeitpunkt), Grenzen, Größe
export_boss(key)  exportiert die Teile-Hierarchie MIT Objekt-Animationen als models/e_<key>.glb (Godot: AnimationPlayer) + .json
tafel(key)        Bildtafel für die Abnahme: vorn, Seite, oben neben einer 2,6 m großen Figur, darunter alle Clips als Bildfolge

Die Szene muss mit animkit.Rig gebaut sein (Clip-Liste steht in scene["rw_clips"]).
Aufruf als Programm:  python3 blender/vat_bake.py <blend-datei> [tafel]
"""
import sys, os, json, math
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import numpy as np
from kit import *

BAKE_STEP = 3
TEX_W_MAX = 1024
TEX_H_MAX = 512
SHOTS = os.environ.get("RW_TAFEL_DIR", os.path.join(os.path.dirname(ROOT), "shots_" + os.path.basename(ROOT)))


def clips_of_scene():
    return json.loads(bpy.context.scene["rw_clips"])


def set_pose(clip="idle", frame=0):
    """Stellt die Szene auf ein Bild eines Clips (für Symbol und Bildtafel)."""
    for c in clips_of_scene():
        if c["name"] == clip:
            bpy.context.scene.frame_set(int(c["start"] + frame))
            return True
    return False


def _mesh_objects():
    return [o for o in bpy.context.scene.objects if o.type == "MESH" and not o.hide_render]


def _eval_frame(obs, dg):
    """Welt-Positionen und -Normalen aller Ecken (loops) aller Objekte im aktuellen Bild."""
    pos, nrm = [], []
    for ob in obs:
        oe = ob.evaluated_get(dg)
        me = oe.to_mesh()
        nv, nl = len(me.vertices), len(me.loops)
        co = np.empty(nv * 3, dtype=np.float32)
        me.vertices.foreach_get("co", co)
        li = np.empty(nl, dtype=np.int32)
        me.loops.foreach_get("vertex_index", li)
        cn = np.empty(nl * 3, dtype=np.float32)
        me.corner_normals.foreach_get("vector", cn)
        m = np.array(oe.matrix_world, dtype=np.float64)
        p = co.reshape(-1, 3)[li].astype(np.float64) @ m[:3, :3].T + m[:3, 3]
        nm = np.linalg.inv(m[:3, :3]).T
        n = cn.reshape(-1, 3).astype(np.float64) @ nm.T
        ln = np.linalg.norm(n, axis=1, keepdims=True)
        n = n / np.maximum(ln, 1e-9)
        pos.append(p)
        nrm.append(n)
        oe.to_mesh_clear()
    return np.concatenate(pos), np.concatenate(nrm)


def _static_data(obs, dg):
    """Farben, Kennungen und Dreiecke (als Ecken-Indizes) aller Objekte."""
    cols, flags, tris = [], [], []
    base = 0
    for ob in obs:
        oe = ob.evaluated_get(dg)
        me = oe.to_mesh()
        nl = len(me.loops)
        c = np.ones(nl * 4, dtype=np.float32)
        if "Col" in me.color_attributes:
            me.color_attributes["Col"].data.foreach_get("color", c)
        cols.append(c.reshape(-1, 4))
        f = np.zeros((nl, 2), dtype=np.float32)
        f[:, 0] = float(ob.get("rw_glow", 1.0 if ob.name.endswith("_glow") else 0.0))
        f[:, 1] = float(ob.get("rw_code", 0)) / 3.0
        flags.append(f)
        me.calc_loop_triangles()
        t = np.empty(len(me.loop_triangles) * 3, dtype=np.int32)
        me.loop_triangles.foreach_get("loops", t)
        tris.append(t.reshape(-1, 3) + base)
        base += nl
        oe.to_mesh_clear()
    return np.concatenate(cols), np.concatenate(flags), np.concatenate(tris)


def bake_vat(key, limit=99999):
    sc = bpy.context.scene
    clips = clips_of_scene()
    obs = _mesh_objects()
    name = "e_" + key
    # ---- 1. alle Bilder auswerten
    frames = []          # Liste von (clip-index, szenen-bild)
    info = {}
    row = 0
    for ci, c in enumerate(clips):
        n = (c["end"] - c["start"]) // BAKE_STEP
        if not c["loop"]:
            n += 1
        info[c["name"]] = {"row": row, "n": n, "dur": (c["end"] - c["start"]) / float(sc.render.fps), "loop": c["loop"],
                           "stride": c["stride"], "hit": c["hit"]}
        for i in range(n):
            frames.append(c["start"] + i * BAKE_STEP)
        row += n
    sc.frame_set(clips[0]["start"])
    dg = bpy.context.evaluated_depsgraph_get()
    cols, flags, tris = _static_data(obs, dg)
    rest_p, rest_n = _eval_frame(obs, dg)
    # ---- 2. gleiche Ecken zusammenfassen (gleicher Punkt, gleiche Normale, gleiche Farbe = ein Eckpunkt der Grafikkarte)
    keyarr = np.concatenate([np.round(rest_p, 4), np.round(rest_n, 2), np.round(cols[:, :3], 3), flags], axis=1)
    _u, first, inverse = np.unique(keyarr, axis=0, return_index=True, return_inverse=True)
    inverse = inverse.reshape(-1)
    nv = len(first)
    if nv > limit:
        raise RuntimeError("%s: %d Eckpunkte – erlaubt sind %d. Weniger Unterteilungen (subdiv, sides) verwenden!" % (name, nv, limit))
    W = min(nv, TEX_W_MAX)
    rpf = int(math.ceil(nv / float(W)))
    R = len(frames) * rpf
    if R > TEX_H_MAX:
        raise RuntimeError("%s: Textur wäre %d x %d – höchstens %d Zeilen. Clips kürzen!" % (name, W, R, TEX_H_MAX))
    P = np.zeros((len(frames), nv, 3), dtype=np.float64)
    N = np.zeros((len(frames), nv, 3), dtype=np.float64)
    for fi, f in enumerate(frames):
        sc.frame_set(f)
        dg = bpy.context.evaluated_depsgraph_get()
        p, n = _eval_frame(obs, dg)
        P[fi] = p[first]
        N[fi] = n[first]
    # Blender (x, y, z) -> Godot (x, z, -y)
    def to_godot(a):
        return np.stack([a[..., 0], a[..., 2], -a[..., 1]], axis=-1)
    Pg, Ng = to_godot(P), to_godot(N)
    lo = Pg.reshape(-1, 3).min(axis=0) - 0.01
    hi = Pg.reshape(-1, 3).max(axis=0) + 0.01
    size = hi - lo
    q = np.clip(np.round((Pg - lo) / size * 65535.0), 0, 65535).astype(np.uint32)
    img = np.zeros((3 * R, W, 3), dtype=np.uint8)
    idx = np.arange(nv)
    cx, cy = idx % W, idx // W
    for fi in range(len(frames)):
        img[fi * rpf + cy, cx] = (q[fi] >> 8).astype(np.uint8)
        img[R + fi * rpf + cy, cx] = (q[fi] & 255).astype(np.uint8)
        img[2 * R + fi * rpf + cy, cx] = np.clip(np.round((Ng[fi] * 0.5 + 0.5) * 255.0), 0, 255).astype(np.uint8)
    from PIL import Image
    Image.fromarray(img, "RGB").save(os.path.join(OUT_GLB, name + "_vat.png"), optimize=True)
    # ---- 3. zusammengefasstes Mesh in Ruhepose
    me = bpy.data.meshes.new("body")
    tri_v = inverse[tris]
    # entartete Dreiecke entfernen
    ok = (tri_v[:, 0] != tri_v[:, 1]) & (tri_v[:, 1] != tri_v[:, 2]) & (tri_v[:, 0] != tri_v[:, 2])
    tri_v = tri_v[ok]
    me.from_pydata([tuple(v) for v in P[0]], [], [tuple(int(i) for i in t) for t in tri_v])
    me.update()
    colattr = me.color_attributes.new("Col", "FLOAT_COLOR", "POINT")
    colattr.data.foreach_set("color", cols[first].astype(np.float32).reshape(-1))
    me.color_attributes.active_color = colattr
    me.color_attributes.render_color_index = 0
    uv1 = me.uv_layers.new(name="flags")
    uv2 = me.uv_layers.new(name="vat")
    lv = np.empty(len(me.loops), dtype=np.int32)
    me.loops.foreach_get("vertex_index", lv)
    f1 = flags[first][lv].astype(np.float32).copy()
    f1[:, 1] = 1.0 - f1[:, 1]                                  # glTF dreht V um
    uv1.data.foreach_set("uv", f1.reshape(-1))
    u2 = np.stack([(cx[lv] + 0.5) / W, 1.0 - (cy[lv] + 0.5) / rpf], axis=1).astype(np.float32)
    uv2.data.foreach_set("uv", u2.reshape(-1))
    for pl in me.polygons:
        pl.use_smooth = True
    me.normals_split_custom_set_from_vertices([tuple(v) for v in N[0]])
    for ob in list(sc.objects):
        bpy.data.objects.remove(ob, do_unlink=True)
    body = bpy.data.objects.new("body", me)
    sc.collection.objects.link(body)
    me.materials.append(material(False))
    root = bpy.data.objects.new(name, None)
    sc.collection.objects.link(root)
    body.parent = root
    bpy.ops.export_scene.gltf(filepath=os.path.join(OUT_GLB, name + ".glb"), export_format="GLB", export_apply=False,
                              export_vertex_color="ACTIVE", export_all_vertex_colors=False, export_materials="EXPORT",
                              export_cameras=False, export_lights=False, export_yup=True, export_animations=False,
                              export_texcoords=True, export_normals=True)
    height = float(P[0][:, 2].max())
    radius = float(np.sqrt((P[0][:, 0] ** 2 + P[0][:, 1] ** 2).max()))
    desc = {"key": key, "kind": "vat", "role": sc.get("rw_role", ""), "verts": int(nv), "tris": int(len(tri_v)), "width": int(W), "rows": int(R), "rpf": int(rpf),
            "fps": 10, "bounds_min": [float(x) for x in lo], "bounds_size": [float(x) for x in size], "height": height, "radius": radius, "clips": info}
    with open(os.path.join(OUT_GLB, name + ".json"), "w") as f:
        json.dump(desc, f, indent=1)
    print("VAT %-24s %4d Eckpunkte (Grenze %d), %4d Dreiecke, Textur %d x %d (Datei %d x %d), %d Bilder, Clips: %s" % (
        name, nv, limit, len(tri_v), W, R, W, 3 * R, len(frames), ", ".join("%s %.1fs" % (k, v["dur"]) for k, v in info.items())), flush=True)
    return desc


def export_boss(key):
    """Boss: echte Figur aus Teilen mit Objekt-Animationen (eine durchgehende Zeitleiste; die Clips stehen in der .json)."""
    sc = bpy.context.scene
    name = "e_" + key
    clips = clips_of_scene()
    fps = float(sc.render.fps)
    tris = 0
    for ob in _mesh_objects():
        ob.data.calc_loop_triangles()
        tris += len(ob.data.loop_triangles)
    if tris > 8000:
        raise RuntimeError("%s: %d Dreiecke – erlaubt sind 8000" % (name, tris))
    for ob in _mesh_objects():
        if float(ob.get("rw_glow", 0.0)) > 0.5 and not ob.name.endswith("_glow"):
            ob.name = ob.name + "_glow"          # Godot lässt Objekte mit diesem Namensende leuchten
    sc.frame_set(clips[0]["start"])
    bpy.ops.export_scene.gltf(filepath=os.path.join(OUT_GLB, name + ".glb"), export_format="GLB", export_apply=False,
                              export_vertex_color="ACTIVE", export_all_vertex_colors=False, export_materials="EXPORT",
                              export_cameras=False, export_lights=False, export_yup=True, export_animations=True,
                              export_animation_mode="SCENE", export_force_sampling=True, export_frame_range=True,
                              export_bake_animation=True, export_optimize_animation_size=False)
    info = {}
    for c in clips:
        info[c["name"]] = {"start": (c["start"] - sc.frame_start) / fps, "dur": (c["end"] - c["start"]) / fps, "loop": c["loop"],
                           "stride": c["stride"], "hit": c["hit"]}
    hi = 0.0
    rad = 0.0
    for ob in _mesh_objects():
        for corner in ob.bound_box:
            w = ob.matrix_world @ Vector(corner)
            hi = max(hi, w.z)
            rad = max(rad, math.hypot(w.x, w.y))
    desc = {"key": key, "kind": "boss", "tris": tris, "height": hi, "radius": rad, "clips": info}
    with open(os.path.join(OUT_GLB, name + ".json"), "w") as f:
        json.dump(desc, f, indent=1)
    print("BOSS %-24s %d Dreiecke, %d Teile, Clips: %s" % (name, tris, len(_mesh_objects()), ", ".join(info.keys())), flush=True)
    return desc


# ---------------------------------------------------------------- Bildtafel
def _mannequin():
    """2,6 m große, graue Vergleichsfigur (so groß ist der Held im Spiel)."""
    p = Part()
    g, gd = "9AA3B5", "6F7A90"
    p.box((0.34, 0.3, 0.95), (-0.22, 0, 0.48), gd, bevel=0.06)
    p.box((0.34, 0.3, 0.95), (0.22, 0, 0.48), gd, bevel=0.06)
    p.box((0.9, 0.48, 0.95), (0, 0, 1.4), g, bevel=0.1)
    p.box((0.26, 0.28, 0.9), (-0.6, 0, 1.4), gd, bevel=0.06)
    p.box((0.26, 0.28, 0.9), (0.6, 0, 1.4), gd, bevel=0.06)
    p.box((0.74, 0.7, 0.7), (0, 0, 2.25), g, bevel=0.12)
    ob = p.build("vergleich")
    return ob


def _render(path, w, h, yaw, pitch, center, span, samples=12, bg=None):
    sc = bpy.context.scene
    cam = bpy.data.cameras.new("TafelCam")
    cam.type = "ORTHO"
    co = bpy.data.objects.new("TafelCam", cam)
    sc.collection.objects.link(co)
    e = Euler((math.radians(90.0 - pitch), 0.0, math.radians(yaw)), "XYZ")
    co.rotation_euler = e
    co.location = Vector(center) + (e.to_matrix() @ Vector((0, 0, 1))) * 60.0
    cam.ortho_scale = span
    cam.clip_end = 200.0
    sc.camera = co
    sc.render.resolution_x = w
    sc.render.resolution_y = h
    sc.render.filepath = path
    sc.cycles.samples = samples
    bpy.ops.render.render(write_still=True)
    bpy.data.objects.remove(co, do_unlink=True)


def _render_setup():
    sc = bpy.context.scene
    for nm, energy, rx, rz, colr in (("Key", 3.0, 50, -40, (1.0, 0.96, 0.9)), ("Fill", 1.4, 65, 110, (0.75, 0.85, 1.0)), ("Top", 1.0, 5, 0, (1, 1, 1))):
        l = bpy.data.lights.new(nm, "SUN")
        l.energy = energy
        l.color = colr
        l.angle = math.radians(12)
        lo2 = bpy.data.objects.new(nm, l)
        lo2.rotation_euler = (math.radians(rx), 0, math.radians(rz))
        sc.collection.objects.link(lo2)
    if sc.world is None:
        sc.world = bpy.data.worlds.new("W")
    sc.world.use_nodes = True
    bgn = sc.world.node_tree.nodes.get("Background")
    if bgn:
        bgn.inputs[0].default_value = (0.55, 0.62, 0.8, 1.0)
        bgn.inputs[1].default_value = 0.55
    sc.render.engine = "CYCLES"
    sc.cycles.device = "CPU"
    sc.cycles.use_denoising = False
    sc.render.film_transparent = True
    sc.render.image_settings.file_format = "PNG"
    sc.render.image_settings.color_mode = "RGBA"
    sc.view_settings.view_transform = "Standard"


def tafel(key, out_dir=None, strip_frames=7):
    """Bildtafel: oben Modell von vorn, von der Seite und von oben neben der 2,6-m-Figur, rechts Umriss aus der Spielkamera,
    darunter je Clip eine Bildfolge. Ergebnis: <out_dir>/tafel_<key>.png und umriss_<key>.png"""
    from PIL import Image, ImageDraw, ImageFont
    out_dir = out_dir or SHOTS
    os.makedirs(out_dir, exist_ok=True)
    tmp = os.path.join(out_dir, "_tmp_" + key)
    os.makedirs(tmp, exist_ok=True)
    sc = bpy.context.scene
    clips = clips_of_scene()
    _render_setup()
    set_pose("idle", 0)
    # Größe des Modells
    pts = []
    for ob in _mesh_objects():
        for corner in ob.bound_box:
            pts.append(ob.matrix_world @ Vector(corner))
    hi = max(p.z for p in pts)
    rad = max(max(abs(p.x), abs(p.y)) for p in pts)
    man = _mannequin()
    man.location = (rad + 1.1, 0, 0)
    span = max(3.0, hi + 0.4, rad * 2 + 2.6)
    cx = (rad + 1.1 + 0.75 - rad) * 0.5
    views = []
    for nm, yaw, pitch, ctr in (("vorn", 0, 0, (cx, 0, span * 0.5 - 0.15)), ("seite", 90, 0, (0, 0, span * 0.5 - 0.15)), ("oben", 0, 90, (cx, 0, 0))):
        if nm == "seite":
            man.location = (0, -(rad + 1.1), 0)
        elif nm == "oben":
            man.location = (rad + 1.1, 0, 0)
        fp = os.path.join(tmp, nm + ".png")
        _render(fp, 420, 420, yaw, pitch, ctr, span + 0.3, samples=16)
        views.append((nm, fp))
    bpy.data.objects.remove(man, do_unlink=True)
    # Spielkamera (55 Grad von oben), einmal farbig, einmal als Umriss
    fp = os.path.join(tmp, "spiel.png")
    s2 = max(hi * 0.9 + rad * 1.6, 1.6)
    _render(fp, 420, 420, 0, 55, (0, 0, hi * 0.35), s2 * 1.25, samples=16)
    views.append(("Spielkamera", fp))
    um = Image.open(fp).convert("RGBA")
    sil = Image.new("RGBA", um.size, (255, 255, 255, 255))
    black = Image.new("RGBA", um.size, (0, 0, 0, 255))
    sil.paste(black, (0, 0), um.split()[3].point(lambda a: 255 if a > 40 else 0))
    sil.save(os.path.join(out_dir, "umriss_%s.png" % key))
    views.append(("Umriss", os.path.join(out_dir, "umriss_%s.png" % key)))
    # Bildfolgen
    cell = 270
    strips = []
    for c in clips:
        row = []
        n = strip_frames
        for i in range(n):
            f = c["start"] + (c["end"] - c["start"]) * i / float(n if c["loop"] else n - 1)
            sc.frame_set(int(round(f)))
            fp = os.path.join(tmp, "%s_%d.png" % (c["name"], i))
            _render(fp, cell, cell, -28, 30, (0, 0, hi * 0.42), max(hi * 1.3, rad * 2.6, 0.8) * 1.1, samples=8)
            row.append(fp)
        strips.append((c, row))
    # zusammensetzen
    Wd = 5 * 430 + 20
    Hd = 60 + 440 + len(strips) * (cell + 8) + 20
    im = Image.new("RGB", (Wd, Hd), "#1A2A44")
    d = ImageDraw.Draw(im)
    try:
        font = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 22)
        small = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", 16)
    except Exception:
        font = small = ImageFont.load_default()
    desc_path = os.path.join(OUT_GLB, "e_%s.json" % key)
    extra = ""
    if os.path.exists(desc_path):
        dj = json.load(open(desc_path))
        extra = "   %s Eckpunkte, %d Dreiecke, Höhe %.2f m" % (dj.get("verts", "–"), dj.get("tris", 0), dj.get("height", 0))
    d.text((16, 14), "%s%s" % (key, extra), fill="#FFD23E", font=font)
    for i, (nm, fp) in enumerate(views):
        v = Image.open(fp).convert("RGBA")
        x = 10 + i * 430
        d.rectangle((x, 56, x + 420, 56 + 420), fill="#FFFFFF" if nm == "Umriss" else "#2E4468")
        im.paste(v, (x, 56), v)
        d.text((x + 8, 60), nm, fill="#000000" if nm == "Umriss" else "#FFFFFF", font=small)
    y = 60 + 440
    for c, row in strips:
        d.text((14, y + 4), "%s\n%.1f s%s" % (c["name"], (c["end"] - c["start"]) / float(sc.render.fps), "\nSchleife" if c["loop"] else ""), fill="#FFFFFF", font=small)
        for i, fp in enumerate(row):
            v = Image.open(fp).convert("RGBA")
            x = 120 + i * (cell + 6)
            d.rectangle((x, y, x + cell, y + cell), fill="#2E4468")
            im.paste(v, (x, y), v)
        y += cell + 8
    out = os.path.join(out_dir, "tafel_%s.png" % key)
    im.save(out)
    import shutil
    shutil.rmtree(tmp, ignore_errors=True)
    print("tafel", out, flush=True)
    return out


def umriss_tafel(family, keys, out_dir=None):
    """Alle Arten einer Familie als schwarze Umrisse aus der Spielkamera nebeneinander (aus den umriss_<key>.png)."""
    from PIL import Image, ImageDraw
    out_dir = out_dir or SHOTS
    ims = [Image.open(os.path.join(out_dir, "umriss_%s.png" % k)).convert("RGB") for k in keys]
    w = sum(i.size[0] for i in ims)
    im = Image.new("RGB", (w, ims[0].size[1] + 24), "#FFFFFF")
    d = ImageDraw.Draw(im)
    x = 0
    for k, i in zip(keys, ims):
        im.paste(i, (x, 24))
        d.text((x + 6, 4), k, fill="#000000")
        x += i.size[0]
    out = os.path.join(out_dir, "tafel_%s_umrisse.png" % family)
    im.save(out)
    print("umrisse", out)
    return out


if __name__ == "__main__":
    if len(sys.argv) > 1:
        bpy.ops.wm.open_mainfile(filepath=sys.argv[1])
        k = bpy.context.scene["rw_key"]
        if len(sys.argv) > 2 and sys.argv[2] == "tafel":
            tafel(k)
        else:
            bake_vat(k)
