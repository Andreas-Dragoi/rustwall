"""Rustwall – Logo, App-Symbol und Startbild (Paket O).

Baut das Wappen (rostige Mauer mit Zinnen, Zahnrad dahinter, Schleim oben, blaue Fahne) und rendert:
  icons/app/icon_1024.png            App-Symbol 1024 x 1024 (deckend, für iOS und Stores)
  icons/app/android_fg_432.png       Android adaptiv: Vordergrund (durchsichtig, im sicheren Bereich)
  icons/app/android_bg_432.png       Android adaptiv: Hintergrund
  icons/app/android_mono_432.png     Android 13+: einfarbiges Symbol
  icons/app/android_192.png          Android Launcher (alt)
  icons/app/splash.png               Startbild 1280 x 720 (Logo + Schriftzug)
  docs/store/grafik/…                alle weiteren Größen (iOS 20…180 px, Play Store 512 px, Feature-Grafik 1024 x 500)
Aufruf: python3 blender/logo.py
"""
import math
import os
import sys

import bpy
from mathutils import Euler, Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import kit  # noqa: E402

ROOT = kit.ROOT
OUT = os.path.join(ROOT, "icons", "app")
STORE = os.path.join(ROOT, "docs", "store", "grafik")
os.makedirs(OUT, exist_ok=True)
os.makedirs(STORE, exist_ok=True)
NAVY = "12305F"
RUST = "B5532A"
RUST_D = "7E3418"
RUST_L = "D9783F"


def emblem():
    """Das Wappen. Vorderseite -Y, Mitte bei x = 0, Boden bei z = 0, ca. 4 m breit."""
    kit.reset()
    # Zahnrad hinter der Mauer
    g = kit.Part()
    g.torus(1.55, 0.32, loc=(0, 0.55, 2.35), color="dark", r=kit.rot(90, 0, 0), seg=40, tseg=10)
    for i in range(12):
        a = i * 30.0
        x = math.sin(math.radians(a)) * 1.95
        z = 2.35 + math.cos(math.radians(a)) * 1.95
        g.box((0.5, 0.5, 0.55), loc=(x, 0.55, z), color="steel", r=kit.rot(0, a, 0), bevel=0.08)
    g.cyl(0.55, 0.5, loc=(0, 0.55, 2.35), color="steel", r=kit.rot(90, 0, 0), sides=24, bevel=0.08)
    g.build("gear")
    # Mauer mit Zinnen aus rostigen Platten
    w = kit.Part()
    w.box((4.2, 1.0, 2.2), loc=(0, 0, 1.1), color=RUST, bevel=0.12)
    for i, x in enumerate((-1.75, -0.58, 0.58, 1.75)):
        w.box((0.86, 1.0, 0.75), loc=(x, 0, 2.55), color=RUST_L if i % 2 else RUST, bevel=0.1)
    # Plattenfugen und Nieten
    for x in (-1.4, 0.0, 1.4):
        w.box((0.06, 0.08, 2.0), loc=(x, -0.5, 1.1), color=RUST_D)
    w.box((4.0, 0.08, 0.06), loc=(0, -0.5, 1.1), color=RUST_D)
    for x in (-1.95, -0.85, 0.85, 1.95):
        for z in (0.35, 1.85):
            w.ball(0.09, loc=(x, -0.52, z), color="brass", subdiv=2)
    # Tor in der Mitte
    w.box((1.1, 0.2, 1.35), loc=(0, -0.45, 0.68), color="wood_d", bevel=0.06)
    w.cyl(0.55, 0.2, loc=(0, -0.45, 1.35), color="wood_d", r=kit.rot(90, 0, 0), sides=20)
    for x in (-0.3, 0.0, 0.3):
        w.box((0.07, 0.1, 1.3), loc=(x, -0.58, 0.75), color="dark")
    w.build("wall")
    # Schleim auf der Mauer
    s = kit.Part()
    s.ball(0.55, loc=(-1.15, -0.05, 2.25), color="slime", scale=(1.2, 1.0, 0.75))
    s.ball(0.32, loc=(-0.65, -0.2, 2.1), color="slime_l", scale=(1.0, 1.0, 0.8))
    s.ball(0.14, loc=(-1.45, -0.55, 2.35), color="white")
    s.ball(0.14, loc=(-1.0, -0.6, 2.4), color="white")
    s.ball(0.07, loc=(-1.45, -0.67, 2.36), color="black")
    s.ball(0.07, loc=(-1.0, -0.72, 2.41), color="black")
    s.ball(0.2, loc=(-1.6, -0.45, 1.75), color="slime", scale=(0.7, 0.7, 1.4))
    s.build("slime")
    # Fahne
    f = kit.Part()
    f.cyl(0.07, 2.0, loc=(1.75, 0, 3.6), color="steel")
    f.box((1.1, 0.06, 0.65), loc=(2.3, 0, 4.25), color="flag", bevel=0.03)
    f.ball(0.11, loc=(1.75, 0, 4.62), color="gold")
    f.build("flag")


def wordmark():
    """Schriftzug RUSTWALL (Blender-Schrift, in ein Mesh mit Vertex-Farben umgewandelt)."""
    bpy.ops.object.text_add(location=(0, 0, 0))
    t = bpy.context.object
    t.data.body = "RUSTWALL"
    t.data.align_x = "CENTER"
    t.data.extrude = 0.12
    t.data.bevel_depth = 0.03
    t.data.size = 1.6
    t.rotation_euler = (math.radians(90), 0, 0)
    bpy.ops.object.convert(target="MESH")
    me = t.data
    attr = me.color_attributes.new("Col", "FLOAT_COLOR", "CORNER")
    gold, edge = kit.col("gold"), kit.col("D9862A")
    for poly in me.polygons:
        c = gold if poly.normal.z > 0.7 else edge          # Vorderseite (vor dem Drehen +Z)
        for li in poly.loop_indices:
            attr.data[li].color = c
    me.color_attributes.active_color = attr
    me.materials.clear()
    me.materials.append(kit.material())
    t.name = "word"
    return t


def render(path, w, h, ortho, center, transparent, bg=NAVY, yaw=18.0, pitch=10.0, samples=48):
    sc = bpy.context.scene
    cam = bpy.data.cameras.new("Cam")
    cam.type = "ORTHO"
    cam.ortho_scale = ortho
    co = bpy.data.objects.new("Cam", cam)
    sc.collection.objects.link(co)
    e = Euler((math.radians(90.0 - pitch), 0.0, math.radians(yaw)), "XYZ")
    co.rotation_euler = e
    co.location = Vector(center) + e.to_matrix() @ Vector((0, 0, 40))
    cam.clip_end = 200.0
    sc.camera = co
    lights = []
    for nm, energy, rx, rz, colr in (("Key", 3.4, 50, yaw - 40, (1.0, 0.95, 0.88)), ("Fill", 1.4, 65, yaw + 110, (0.7, 0.82, 1.0)), ("Top", 1.0, 5, 0, (1, 1, 1))):
        l = bpy.data.lights.new(nm, "SUN")
        l.energy = energy
        l.color = colr
        l.angle = math.radians(10)
        lo = bpy.data.objects.new(nm, l)
        lo.rotation_euler = (math.radians(rx), 0, math.radians(rz))
        sc.collection.objects.link(lo)
        lights.append(lo)
    if sc.world is None:
        sc.world = bpy.data.worlds.new("W")
    sc.world.use_nodes = True
    bgn = sc.world.node_tree.nodes.get("Background")
    bgn.inputs[0].default_value = kit.col(bg)
    bgn.inputs[1].default_value = 0.6
    sc.render.engine = "CYCLES"
    sc.cycles.device = "CPU"
    sc.cycles.samples = samples
    sc.cycles.use_denoising = False
    sc.render.film_transparent = transparent
    sc.render.resolution_x = w
    sc.render.resolution_y = h
    sc.render.image_settings.file_format = "PNG"
    sc.render.image_settings.color_mode = "RGBA" if transparent else "RGB"
    sc.view_settings.view_transform = "Standard"
    sc.render.filepath = path
    bpy.ops.render.render(write_still=True)
    for o in lights + [co]:
        bpy.data.objects.remove(o, do_unlink=True)


def backdrop(radius, y=1.4, z=2.3):
    """Heller runder Hintergrund hinter dem Wappen (nur für deckende Bilder)."""
    p = kit.Part()
    p.cyl(radius, 0.1, loc=(0, y, z), color="2A5FA8", r=kit.rot(90, 0, 0), sides=64)
    p.cyl(radius * 0.93, 0.1, loc=(0, y - 0.05, z), color="3C7BD0", r=kit.rot(90, 0, 0), sides=64)
    return p.build("backdrop")


def main():
    from PIL import Image
    # 1) App-Symbol (deckend)
    emblem()
    bd = backdrop(3.5, z=2.55)
    render(os.path.join(OUT, "icon_1024.png"), 1024, 1024, 7.6, (0.15, 0, 2.55), False)
    bpy.data.objects.remove(bd, do_unlink=True)
    # 2) Android-Vordergrund: durchsichtig, Wappen im sicheren Bereich (66 % der Fläche)
    render(os.path.join(OUT, "android_fg_432.png"), 432, 432, 9.6, (0.15, 0, 2.55), True)
    # 3) Startbild: Wappen + Schriftzug
    word = wordmark()
    word.location = (0.1, -0.6, -1.6)
    render(os.path.join(OUT, "splash.png"), 1280, 720, 14.0, (0.1, 0, 1.55), False, yaw=0.0, pitch=4.0, samples=40)
    # 4) Feature-Grafik für Google Play (1024 x 500)
    render(os.path.join(STORE, "play_feature_1024x500.png"), 1024, 500, 14.0, (0.1, 0, 1.55), False, yaw=0.0, pitch=4.0, samples=32)
    kit.reset()
    # 5) abgeleitete Größen
    icon = Image.open(os.path.join(OUT, "icon_1024.png")).convert("RGB")
    icon.resize((192, 192), Image.LANCZOS).save(os.path.join(OUT, "android_192.png"))
    Image.new("RGB", (432, 432), "#" + NAVY).save(os.path.join(OUT, "android_bg_432.png"))
    fg = Image.open(os.path.join(OUT, "android_fg_432.png")).convert("RGBA")
    alpha = fg.split()[3]
    mono = Image.new("RGBA", fg.size, (255, 255, 255, 0))
    mono.putalpha(alpha)
    mono.save(os.path.join(OUT, "android_mono_432.png"))
    for s in (20, 29, 40, 58, 60, 76, 80, 87, 120, 152, 167, 180, 1024):
        icon.resize((s, s), Image.LANCZOS).save(os.path.join(STORE, "ios_%d.png" % s))
    for s in (48, 72, 96, 144, 192, 512):
        icon.resize((s, s), Image.LANCZOS).save(os.path.join(STORE, "android_%d.png" % s))
    print("Logo, App-Symbole und Startbild geschrieben")


if __name__ == "__main__":
    main()
