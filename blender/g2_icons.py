"""Paket G2 – drei weitere Menü-Symbole für die Schwächen im Monsterbuch (im Stil von ui_icons.py):
ui_bullet (Kugeln), ui_bomb (Explosion), ui_poison (Gift). Aufruf: python3 blender/g2_icons.py [ui_bomb ...]"""
import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import ui_icons
from ui_icons import *


def bullet(p):
    for k, x in enumerate((-0.22, 0.22)):
        p.cyl(0.13, 0.5, (x, 0, -0.12), "E8B33A", sides=14, bevel=0.03, segs=1)
        p.cyl(0.13, 0.06, (x, 0, -0.4), "C8922A", sides=14)
        lathe(p, [(0.13, 0.0), (0.12, 0.1), (0.07, 0.24), (0.0, 0.3)], loc=(x, 0, 0.13), color="C9D0DE", sides=14)
    gleam(p, -0.26, 0.0, -0.14, 0.04, 0.12, a=0)


def bomb(p):
    p.ball(0.36, (0, 0, -0.08), "3A4152", subdiv=3)
    p.cyl(0.12, 0.12, (0.18, 0, 0.3), "5A6274", r=rot(0, 30, 0), sides=10)
    bar(p, (0.05, 0.05, 0.22), (0.24, 0, 0.36), 50, 0.0, "C8A060")
    star(p, 0.14, 0.06, loc=(0.42, -0.05, 0.5), color="FFD23E")
    gleam(p, -0.14, 0.12, -0.3, 0.1, 0.05)


def poison(p):
    lathe(p, [(0.0, -0.45), (0.3, -0.38), (0.36, -0.15), (0.28, 0.05), (0.12, 0.18), (0.1, 0.35), (0.14, 0.38), (0.12, 0.48), (0.0, 0.5)],
          color=["58E86A", "58E86A", "58E86A", "58E86A", "3FB84A", "C8A060", "C8A060", "C8A060"], sides=16)
    p.ball(0.07, (-0.08, -0.33, -0.12), "FFFFFF", subdiv=1, scale=(1, 0.4, 1))
    p.ball(0.07, (0.08, -0.33, -0.12), "FFFFFF", subdiv=1, scale=(1, 0.4, 1))
    p.box((0.14, 0.05, 0.04), (0, -0.34, -0.25), "FFFFFF")
    gleam(p, -0.2, -0.05, -0.36, 0.06, 0.12, a=-10)


ui_icons.ALL.update(bullet=(bullet, (-20, 12)), bomb=(bomb, (-24, 14)), poison=(poison, (-20, 10)))

if __name__ == "__main__":
    want = [n[3:] if n.startswith("ui_") else n for n in sys.argv[1:] if not n.startswith("--")] or ["bullet", "bomb", "poison"]
    for n in want:
        print("ok ui_%s  %d Dreiecke" % (n, ui_icons.make(n)))
