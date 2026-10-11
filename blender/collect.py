"""Fasst die einzelnen Modell-Dateien (blender/blend/*.blend) zu wenigen Sammeldateien zusammen
(blender/rustwall_<gruppe>.blend): je Modell eine Collection, in einem Raster aufgestellt."""
import bpy, os, glob, math
ROOT = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(ROOT, "blend")
GROUPS = {"helden": ["hero_"], "fahrzeuge": ["v_"], "gebaeude": ["b_", "wall_"], "tuerme": ["t_"], "kulissen": ["p_"],
          "gegner": ["e_"], "waffen_ausruestung": ["w_", "gear_"], "symbole": ["ui_", "res_"]}
for group, prefixes in GROUPS.items():
    files = sorted(f for f in glob.glob(os.path.join(SRC, "*.blend")) if any(os.path.basename(f).startswith(p) for p in prefixes))
    if not files:
        continue
    bpy.ops.wm.read_factory_settings(use_empty=True)
    cols = max(1, int(math.ceil(math.sqrt(len(files)))))
    step = 8.0 if group in ("gebaeude", "tuerme", "kulissen", "fahrzeuge") else 2.5
    for i, f in enumerate(files):
        name = os.path.splitext(os.path.basename(f))[0]
        with bpy.data.libraries.load(f, link=False) as (src, dst):
            dst.objects = list(src.objects)
        coll = bpy.data.collections.new(name)
        bpy.context.scene.collection.children.link(coll)
        holder = bpy.data.objects.new(name + "_platz", None)
        holder.location = ((i % cols) * step, -(i // cols) * step, 0)
        coll.objects.link(holder)
        for ob in dst.objects:
            if ob is None or ob.type in ("CAMERA", "LIGHT"):
                continue
            coll.objects.link(ob)
            if ob.parent is None:
                ob.parent = holder
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(ROOT, "rustwall_%s.blend" % group), compress=True)
    print("ok", group, len(files))
