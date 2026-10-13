"""Paket H (V6): Waffenmodule (mod_<schlüssel>) – kleine Teile, die Godot an das Waffenmodell steckt (humanoid.gd set_modules).
Echte Größe (Meter), Vorderseite -Y (Laufrichtung der Waffe). Der Ursprung ist der Befestigungspunkt:
  silencer: hinteres Ende (sitzt an der Mündung)   scope: Unterseite der Montage (sitzt oben)   drum: Oberseite (hängt unten)
  loader: Innenseite (sitzt rechts)               core_*: Innenseite (sitzt links)            weight: Mitte (sitzt am Kopf)
  grip: nur Symbol (nicht sichtbar am Modell)
Objekte: body, dazu `*_glow` für leuchtende Linsen und Kerne. Symbole icons/mod_<schlüssel>.png.
Aufruf: python3 blender/weapon_mods.py [mod_scope ...]"""
import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from weapons import prism, lathe, sweep, toon, Y, ring, hole, star, GREY, GREY_L, DGREY, NAVY, YEL, ORG, RED, WHITE, CYAN, BLUE
from kit import *

CORE = {"feuer": ("FF3A10", "FFB070"), "eis": ("30A8FF", "D8F4FF"), "gift": ("38C020", "B8FF80"), "blitz": ("FFD000", "FFFFFF")}


def finish(name, p, glow=None, yaw=-40.0, pitch=20.0):
    toon(p)
    reset()
    root = empty(name)
    p.build("body", root)
    if glow is not None:
        glow.build("lens_glow", root)
    save(name)
    icon(name, 256, yaw=yaw, pitch=pitch, margin=1.15)
    print("ok", name)


def silencer():
    p = Part()
    Y(p, 0.045, 0.0, -0.24, 0, DGREY, sides=14, bevel=0.012)
    for y in (-0.04, -0.12, -0.2):
        ring(p, 0.047, 0.008, y, 0, GREY, seg=14, tseg=4)
    hole(p, 0.022, -0.24, 0)
    finish("mod_silencer", p)


def scope():
    p = Part()
    p.box((0.04, 0.08, 0.04), (0, 0, 0.02), DGREY, bevel=0.01, segs=1)            # Montage
    Y(p, 0.035, 0.12, -0.14, 0.07, NAVY, sides=12)
    Y(p, 0.048, -0.1, -0.16, 0.07, NAVY, sides=12, bevel=0.01)
    Y(p, 0.044, 0.16, 0.1, 0.07, NAVY, sides=12, bevel=0.01)
    p.cyl(0.015, 0.03, (0, -0.0, 0.115), YEL, sides=8)                             # Stellrad
    g = Part()
    Y(g, 0.04, -0.155, -0.165, 0.07, CYAN, sides=12)
    finish("mod_scope", p, g)


def loader():
    p = Part()
    p.box((0.05, 0.1, 0.08), (0.025, 0, 0), "6F7C96", bevel=0.012, segs=1)
    for i in range(3):
        p.cyl(0.012, 0.05, (0.03, -0.03 + i * 0.03, 0.06), YEL, sides=8)           # Patronen im Clip
    p.box((0.012, 0.06, 0.02), (0.055, 0, -0.02), ORG, bevel=0.004, segs=1)
    finish("mod_loader", p)


def drum():
    p = Part()
    p.box((0.04, 0.06, 0.04), (0, 0, -0.02), DGREY, bevel=0.008, segs=1)
    p.cyl(0.09, 0.07, (0, 0, -0.11), "4C5878", r=rot(0, 90, 0), sides=18, bevel=0.012)
    p.cyl(0.05, 0.075, (0, 0, -0.11), "6F7C96", r=rot(0, 90, 0), sides=12)
    for i in range(6):
        a = math.radians(i * 60)
        p.ball(0.01, (0.038, 0.065 * math.cos(a), -0.11 + 0.065 * math.sin(a)), YEL, subdiv=1)
    finish("mod_drum", p)


def grip():
    p = Part()
    p.box((0.05, 0.08, 0.14), (0, 0, -0.07), "2E3340", r=rot(10, 0, 0), bevel=0.02, segs=2)
    for z in (-0.03, -0.07, -0.11):
        p.box((0.056, 0.084, 0.012), (0, 0.0, z), ORG, r=rot(10, 0, 0), bevel=0.004, segs=1)
    p.box((0.06, 0.12, 0.025), (0, 0, 0.0), DGREY, bevel=0.008, segs=1)
    finish("mod_grip", p)


def weight():
    p = Part()
    p.cyl(0.07, 0.08, (0, 0, 0), "6F7C96", sides=8, bevel=0.012)
    for z in (-0.025, 0.025):
        p.torus(0.07, 0.01, (0, 0, z), GREY_L, seg=8, tseg=4)
    p.box((0.03, 0.03, 0.03), (0.07, 0, 0), RED, bevel=0.008, segs=1)
    finish("mod_weight", p)


def core(el):
    a, b = CORE[el]
    p = Part()
    p.box((0.02, 0.06, 0.04), (-0.01, 0, 0), DGREY, bevel=0.006, segs=1)          # Halter
    for y in (0.055, -0.055):
        p.cyl(0.03, 0.02, (-0.04, y, 0), "D9A84A", r=rot(90, 0, 0), sides=10)
    g = Part()
    g.cyl(0.024, 0.09, (-0.04, 0, 0), a, r=rot(90, 0, 0), sides=10)
    g.ball(0.016, (-0.04, 0, 0), b, subdiv=1)
    finish("mod_core_" + el, p, g)


ALL = {"mod_silencer": silencer, "mod_scope": scope, "mod_loader": loader, "mod_drum": drum, "mod_grip": grip, "mod_weight": weight}
for _e in CORE:
    ALL["mod_core_" + _e] = (lambda e=_e: core(e))

if __name__ == "__main__":
    for n in (sys.argv[1:] or list(ALL)):
        ALL[n]()
