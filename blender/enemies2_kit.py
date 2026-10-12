"""Paket G2 – Bewegungs-Baukasten für die neuen Gegnerrollen (Kapitel 6.3): Zweibeiner und Vierbeiner/Krabbler bekommen
dieselben Pflicht-Clips (idle, walk, attack, hit, death, spawn) und je Rolle ihren besonderen Clip:
  heal (Heiler) · block (Schildträger) · grab (Dieb) · jam (Turmstörer) · dig/under/rise (Tunnelgräber) · brood (Brutmutter) · skill (Miniboss)
Die Geometrie baut jede Art selbst (enemies2_<familie>.py); hier stehen nur die Abläufe. Teile, die eine Art nicht hat,
werden in den Posen still übergangen. Feste Teilnamen:
  Zweibeiner: hips (Gelenk), body, head, arm_l, arm_r, leg_l, leg_r – dazu frei: tool (in der Hand), prop (Rücken), glow, mound
  Vierbeiner: body, head, Beine mit Namen leg_* (Liste mit Phase), dazu frei: tail, prop, glow, mound
"mound" ist der Erdhügel der Tunnelgräber: sonst winzig, unter der Erde sichtbar (hebt das Absinken der Figur auf)."""
import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from animkit import *

HID = dict(scale=0.01)


def R(x=0, y=0, z=0):
    return dict(rot=(x, y, z))


def keep(rig, d):
    """Nur Teile, die es gibt (root immer)."""
    return {k: v for k, v in d.items() if k == "root" or k in rig.parts}


def K(c, rig, f, _i=None, **parts):
    c.key(f, _i=_i, **keep(rig, parts))


def rest_pose(rig, extra=None):
    r = {"root": dict(loc=(0, 0, 0), rot=(0, 0, 0), scale=1.0)}
    for n in rig.parts:
        r[n] = dict(loc=(0, 0, 0), rot=(0, 0, 0), scale=1.0)
    if "mound" in rig.parts:
        r["mound"] = dict(loc=(0, 0, 0), rot=(0, 0, 0), scale=0.01)
    if extra:
        for k, v in extra.items():
            r[k] = dict(r.get(k, {}), **v)
    return r


def spawn_clip(rig, rest, depth, n=24):
    with rig.clip("spawn", n) as c:
        K(c, rig, 0, **dict(rest, root=dict(loc=(0, 0, -depth), rot=(0, 0, -40), scale=(0.6, 0.6, 0.6))))
        K(c, rig, int(n * 0.55), root=dict(loc=(0, 0, 0.12 * depth), rot=(0, 0, 15), scale=(0.95, 0.95, 1.1)))
        K(c, rig, int(n * 0.8), root=dict(loc=(0, 0, 0), rot=(0, 0, -5), scale=(1.06, 1.06, 0.94)))
        K(c, rig, n, **rest)


# ================================================================= Zweibeiner
def biped(rig, H, top, speed, role, walk_n=24, arm_swing=22, leg_swing=30, rest_extra=None, attack=None, death_side=False, special=None):
    """Alle Clips eines Zweibeiners. H = Hüfthöhe, top = Höhe der Figur, speed = Tempo (m/s) für die Schrittlänge.
    attack: "swing" (rechter Arm schlägt von oben), "thrust" (stößt nach vorn), "bite" (Kopf schnappt).
    special(c, rig, rest): eigene Zusätze in den Rollen-Clips (wird mit dem Clipnamen gerufen)."""
    rest = rest_pose(rig, rest_extra)
    sp = special or (lambda name, c, rig, rest: None)
    with rig.clip("idle", 42, loop=True) as c:
        K(c, rig, 0, **rest)
        K(c, rig, 12, body=dict(rot=(3, 0, 5), scale=(1.02, 1.02, 0.99)), head=R(4, 0, 16), arm_l=dict(rot=(-6, 0, 6)), arm_r=dict(rot=(-4, 0, -6)))
        K(c, rig, 26, body=dict(rot=(-2, 0, -4), scale=(0.99, 0.99, 1.02)), head=R(-4, 0, -14))
        sp("idle", c, rig, rest)
    with rig.clip("walk", walk_n, loop=True, stride=speed * walk_n / 30.0) as c:
        K(c, rig, 0, **rest)
        if "leg_l" in rig.parts:
            c.wave("leg_l", rot=(leg_swing, 0, 0))
            c.wave("leg_r", rot=(leg_swing, 0, 0), phase=0.5)
        if "arm_l" in rig.parts:
            c.wave("arm_l", rot=(-arm_swing, 0, 0), phase=0.5, base_rot=rest["arm_l"]["rot"])
        if "arm_r" in rig.parts:
            c.wave("arm_r", rot=(-arm_swing, 0, 0), base_rot=rest["arm_r"]["rot"])
        if "hips" in rig.parts:
            c.wave("hips", loc=(0, 0, 0.05 * H), n=2, phase=0.25)
            c.wave("hips", rot=(0, 0, 5), phase=0.25)
        if "body" in rig.parts:
            c.wave("body", rot=(0, 4, 0), base_rot=(6, 0, 0), phase=0.5)
        sp("walk", c, rig, rest)
    kind = attack or "swing"
    with rig.clip("attack", 24, hit=12) as c:
        K(c, rig, 0, **rest)
        if kind == "swing":
            K(c, rig, 8, body=R(-12, 0, -14), arm_r=R(-155, 0, -10), head=R(-8, 0, 0))
            K(c, rig, 12, _i="LINEAR", body=R(18, 0, 10), arm_r=R(-20, 0, 6), hips=dict(loc=(0, -0.08 * H, -0.04 * H)))
        elif kind == "thrust":
            K(c, rig, 8, body=R(-8, 0, -20), arm_r=R(-60, 0, -10), root=dict(loc=(0, 0.12, 0)))
            K(c, rig, 12, _i="LINEAR", body=R(16, 0, 14), arm_r=R(-90, 0, 4), arm_l=R(-60, 0, 0), root=dict(loc=(0, -0.3, 0)))
        else:
            K(c, rig, 8, body=R(-14, 0, 0), head=R(-20, 0, 0), root=dict(loc=(0, 0.1, 0)))
            K(c, rig, 12, _i="LINEAR", body=R(20, 0, 0), head=R(24, 0, 0), root=dict(loc=(0, -0.35, 0)))
        K(c, rig, 17, body=R(8, 0, 4))
        K(c, rig, 24, **rest)
        sp("attack", c, rig, rest)
    with rig.clip("hit", 9) as c:
        K(c, rig, 0, **rest)
        K(c, rig, 3, body=R(-14, 0, 8), head=R(-22, 0, -6), arm_l=R(-20, 0, 30), arm_r=R(-20, 0, -30), root=dict(loc=(0, 0.06, 0)))
        K(c, rig, 9, **rest)
    with rig.clip("death", 33) as c:                                # sinkt auf die Knie und kippt um – bleibt um die Mitte liegen
        K(c, rig, 0, **rest)
        K(c, rig, 7, body=R(-14, 0, 0), head=R(-24, 0, 0), arm_l=R(-30, 0, 40), arm_r=R(-30, 0, -40))
        K(c, rig, 15, _i="LINEAR", hips=dict(loc=(0, 0, -0.42 * H)), leg_l=R(-80, 0, 0), leg_r=R(-80, 0, 0), body=R(14, 0, 0), arm_l=R(0, 0, 20), arm_r=R(0, 0, -20))
        if death_side:
            K(c, rig, 26, _i="LINEAR", root=dict(rot=(0, 84, 0), loc=(-top * 0.4, 0, 0.12)), arm_l=R(-60, 0, 30), arm_r=R(-100, 0, -20))
            K(c, rig, 33, root=dict(rot=(0, 82, 0), loc=(-top * 0.4, 0, 0.14)), hips=dict(loc=(0, 0, -0.42 * H)), leg_l=R(-60, 0, 0), leg_r=R(-90, 0, 0), head=R(10, 0, 20))
        else:
            K(c, rig, 26, _i="LINEAR", root=dict(rot=(84, 0, 0), loc=(0, top * 0.4, 0.12)), arm_l=R(-150, 0, 20), arm_r=R(-150, 0, -20))
            K(c, rig, 33, root=dict(rot=(82, 0, 0), loc=(0, top * 0.4, 0.14)), hips=dict(loc=(0, 0, -0.42 * H)), leg_l=R(-80, 0, 0), leg_r=R(-80, 0, 0), head=R(10, 0, 20))
        if "glow" in rig.parts:
            K(c, rig, 20, glow=dict(scale=1.0))
            K(c, rig, 33, glow=dict(scale=0.05))
        sp("death", c, rig, rest)
    _role_clip(rig, role, H, top, rest, sp, biped=True)
    spawn_clip(rig, rest, top * 0.9)
    return rest


# ================================================================= Vierbeiner / Krabbler
def quad(rig, legs, H, top, speed, role, walk_n=18, leg_swing=24, rest_extra=None, side_legs=False, special=None, hop=0.04):
    """legs = [(teil, phase, seite)], seite +1 links / -1 rechts (zum Spreizen beim Sterben).
    side_legs: Beine schwingen seitwärts (Spinne, Krabbe) statt vor/zurück."""
    rest = rest_pose(rig, rest_extra)
    sp = special or (lambda name, c, rig, rest: None)
    with rig.clip("idle", 36, loop=True) as c:
        K(c, rig, 0, **rest)
        K(c, rig, 12, body=dict(scale=(1.03, 1.03, 0.97), loc=(0, 0, -0.02)), head=R(6, 0, 12))
        K(c, rig, 24, body=dict(scale=(0.98, 0.98, 1.03)), head=R(-4, 0, -12))
        sp("idle", c, rig, rest)
    with rig.clip("walk", walk_n, loop=True, stride=speed * walk_n / 30.0) as c:
        K(c, rig, 0, **rest)
        for (nm, ph, s) in legs:
            if side_legs:
                c.wave(nm, rot=(leg_swing * 0.6, 0, leg_swing * s), phase=ph)
            else:
                c.wave(nm, rot=(leg_swing, 0, 0), phase=ph)
        c.wave("body", loc=(0, 0, hop * H), n=2, phase=0.25, base_rot=(0, 0, 0))
        if "head" in rig.parts:
            c.wave("head", rot=(4, 0, 6), phase=0.25)
        if "tail" in rig.parts:
            c.wave("tail", rot=(0, 0, 14), phase=0.5)
        sp("walk", c, rig, rest)
    with rig.clip("attack", 21, hit=11) as c:
        K(c, rig, 0, **rest)
        K(c, rig, 7, body=dict(rot=(-14, 0, 0), loc=(0, 0.15, 0.05)), head=R(-24, 0, 0))
        K(c, rig, 11, _i="LINEAR", body=dict(rot=(12, 0, 0), loc=(0, -0.3, -0.03)), head=R(26, 0, 0))
        K(c, rig, 21, **rest)
        sp("attack", c, rig, rest)
    with rig.clip("hit", 9) as c:
        K(c, rig, 0, **rest)
        K(c, rig, 3, body=dict(rot=(-10, 0, 8), loc=(0, 0.08, 0.04), scale=(1.06, 1.06, 0.92)), head=R(-18, 0, 10))
        K(c, rig, 9, **rest)
    with rig.clip("death", 30) as c:                                # bricht zusammen, die Beine knicken weg
        K(c, rig, 0, **rest)
        K(c, rig, 7, body=dict(rot=(-10, 0, 0), loc=(0, 0, 0.1)), head=R(-30, 0, 0))
        spl = {nm: R(0, -55 * s, 0) if not side_legs else R(0, 0, 40 * s) for (nm, ph, s) in legs}
        K(c, rig, 17, _i="LINEAR", body=dict(rot=(6, 0, 14), loc=(0, 0, -0.55 * H), scale=(1.05, 1.05, 0.9)), head=R(30, 0, 20), **spl)
        K(c, rig, 30, body=dict(rot=(6, 0, 16), loc=(0, 0, -0.6 * H), scale=(1.05, 1.05, 0.88)), head=R(36, 0, 24), **spl)
        if "glow" in rig.parts:
            K(c, rig, 30, glow=dict(scale=0.05))
        sp("death", c, rig, rest)
    _role_clip(rig, role, H, top, rest, sp, biped=False)
    spawn_clip(rig, rest, top * 0.9)
    return rest


# ================================================================= besondere Clips je Rolle
def _role_clip(rig, role, H, top, rest, sp, biped):
    if role == "healer":
        with rig.clip("heal", 30, hit=15) as c:                      # hebt Stab/Hände, Licht pulsiert
            K(c, rig, 0, **rest)
            K(c, rig, 10, body=R(-12, 0, 0), head=R(-18, 0, 0), arm_r=R(-125, 0, 8), arm_l=R(-60, 0, 30), glow=dict(scale=1.2))
            K(c, rig, 15, glow=dict(scale=1.9), root=dict(loc=(0, 0, 0.06)))
            K(c, rig, 20, glow=dict(scale=1.3))
            K(c, rig, 30, **rest)
            sp("heal", c, rig, rest)
    elif role == "shield":
        with rig.clip("block", 15) as c:                             # stemmt den Schild nach vorn, geht in die Knie
            K(c, rig, 0, **rest)
            K(c, rig, 3, _i="LINEAR", hips=dict(loc=(0, 0, -0.1 * H)), body=dict(rot=(10, 0, 0), loc=(0, 0, -0.06 * H) if not biped else (0, 0, 0)),
              arm_l=R(-20, 0, 6), shield=dict(loc=(0, -0.08, 0)), head=R(14, 0, 0))
            K(c, rig, 5, shield=dict(loc=(0.03, -0.04, 0), rot=(0, 0, 6)), _i="LINEAR")
            K(c, rig, 7, shield=dict(loc=(-0.03, -0.06, 0), rot=(0, 0, -6)))
            K(c, rig, 15, **rest)
            sp("block", c, rig, rest)
    elif role == "thief":
        with rig.clip("grab", 24, hit=10) as c:                      # greift zu und stopft die Beute in den Sack
            K(c, rig, 0, **rest)
            K(c, rig, 6, body=R(30, 0, 0), hips=dict(loc=(0, 0, -0.12 * H)), arm_l=R(-70, 0, 14), arm_r=R(-70, 0, -14), head=R(10, 0, 0), root=dict(loc=(0, -0.15, 0)))
            K(c, rig, 10, _i="LINEAR", body=R(38, 0, 0), arm_l=R(-40, 0, 6), arm_r=R(-40, 0, -6))
            K(c, rig, 16, body=R(-8, 0, -16), arm_r=R(-170, 0, -30), arm_l=R(-10, 0, 10), prop=dict(scale=1.3), root=dict(loc=(0, 0, 0.08)))
            K(c, rig, 24, **rest)
            sp("grab", c, rig, rest)
    elif role == "jammer":
        with rig.clip("jam", 27, hit=17) as c:                       # holt weit aus und schleudert die Ladung auf den Turm
            K(c, rig, 0, **rest)
            K(c, rig, 10, body=R(-16, 0, -24), arm_r=R(-170, 0, 30), arm_l=R(-60, 0, 20), head=R(-12, 0, 0), tool=dict(scale=1.25), glow=dict(scale=1.6))
            K(c, rig, 17, _i="LINEAR", body=R(20, 0, 18), arm_r=R(-40, 0, -10), arm_l=R(-10, 0, 0), head=R(10, 0, 0), tool=dict(scale=1.0), glow=dict(scale=0.6))
            K(c, rig, 27, **rest)
            sp("jam", c, rig, rest)
    elif role == "digger":
        D = top + 0.15
        with rig.clip("dig", 18) as c:                               # wühlt sich vornüber in die Erde
            K(c, rig, 0, **rest)
            K(c, rig, 6, body=R(40, 0, 0), arm_l=R(-80, 0, 20), arm_r=R(-80, 0, -20), head=R(20, 0, 0), mound=dict(scale=0.5, loc=(0, 0, 0)))
            K(c, rig, 10, arm_l=R(-20, 0, 30), arm_r=R(-120, 0, -30), root=dict(loc=(0, 0, -D * 0.4)), mound=dict(scale=0.9, loc=(0, 0, D * 0.4)))
            K(c, rig, 18, _i="LINEAR", root=dict(loc=(0, 0, -D), rot=(0, 0, 0)), mound=dict(scale=1.0, loc=(0, 0, D), rot=(0, 0, 0)))
            sp("dig", c, rig, rest)
        with rig.clip("under", 24, loop=True) as c:                  # nur der Erdhügel wandert und wackelt
            down = dict(rest, root=dict(loc=(0, 0, -D), rot=(0, 0, 0)), mound=dict(scale=1.0, loc=(0, 0, D)))
            K(c, rig, 0, **down)
            K(c, rig, 8, mound=dict(scale=(1.12, 0.9, 1.2), loc=(0, 0, D + 0.04)))
            K(c, rig, 16, mound=dict(scale=(0.92, 1.12, 0.85), loc=(0, 0, D)))
            sp("under", c, rig, rest)
        with rig.clip("rise", 21) as c:                              # bricht mit einem Satz aus der Erde
            K(c, rig, 0, **dict(rest, root=dict(loc=(0, 0, -D), rot=(0, 0, 0)), mound=dict(scale=1.0, loc=(0, 0, D))))
            K(c, rig, 8, _i="LINEAR", root=dict(loc=(0, 0, 0.25)), mound=dict(scale=1.3, loc=(0, 0, -0.25)), arm_l=R(-170, 0, 30), arm_r=R(-170, 0, -30), body=R(-14, 0, 0))
            K(c, rig, 13, root=dict(loc=(0, 0, 0)), mound=dict(scale=0.4, loc=(0, 0, 0)))
            K(c, rig, 21, **rest)
            sp("rise", c, rig, rest)
    elif role == "brood":
        with rig.clip("brood", 30, hit=18) as c:                     # hockt sich hin, der Brutsack pulsiert, Junge kommen heraus
            K(c, rig, 0, **rest)
            K(c, rig, 9, hips=dict(loc=(0, 0, -0.15 * H)), body=dict(rot=(-10, 0, 0), scale=(1.06, 1.06, 0.94)), prop=dict(scale=1.25))
            K(c, rig, 14, prop=dict(scale=(1.45, 1.45, 1.3)), glow=dict(scale=1.6))
            K(c, rig, 18, _i="LINEAR", body=dict(rot=(14, 0, 0), scale=(0.96, 0.96, 1.05)), prop=dict(scale=0.85), glow=dict(scale=0.8))
            K(c, rig, 30, **rest)
            sp("brood", c, rig, rest)
    elif role == "miniboss":
        with rig.clip("skill", 39, hit=27) as c:                     # holt mächtig aus, springt und schmettert auf den Boden
            K(c, rig, 0, **rest)
            K(c, rig, 10, hips=dict(loc=(0, 0, -0.12 * H)), body=dict(rot=(-18, 0, 0), loc=(0, 0.05, 0)), arm_l=R(-170, 0, 20), arm_r=R(-170, 0, -20), head=R(-24, 0, 0), glow=dict(scale=1.5))
            K(c, rig, 20, root=dict(loc=(0, 0, 0.45)), body=R(-22, 0, 0))
            K(c, rig, 27, _i="LINEAR", root=dict(loc=(0, -0.2, 0)), hips=dict(loc=(0, 0, -0.18 * H)), body=dict(rot=(28, 0, 0), loc=(0, 0, -0.05)), arm_l=R(-30, 0, 10), arm_r=R(-30, 0, -10), head=R(20, 0, 0), glow=dict(scale=1.0))
            K(c, rig, 32, body=R(10, 0, 0))
            K(c, rig, 39, **rest)
            sp("skill", c, rig, rest)


def mound(rig, r=0.7, color="7A5A3A", color2="5E4430"):
    """Erdhügel der Tunnelgräber (Kind von root, sonst winzig)."""
    p = Part()
    p.ball(r, (0, 0, 0.0), color, scale=(1.0, 1.25, 0.38), subdiv=2)
    for (x, y, rr) in ((0.3, -0.4, 0.16), (-0.35, 0.2, 0.13), (0.1, 0.5, 0.12), (-0.2, -0.55, 0.1)):
        p.ball(rr * r / 0.7, (x * r / 0.7, y * r / 0.7, 0.2 * r / 0.7), color2, subdiv=1)
    rig.add("mound", p, pivot=(0, 0, 0))
