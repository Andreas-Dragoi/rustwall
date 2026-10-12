"""Alle Animationen für das Skelett rw_human (Auftrag V3, Kapitel 1.2) als Blender-Actions.

Jeder Clip ist eine Action mit per Skript gesetzten Keyframes. Ergebnis:
- blender/blend/anim_human.blend  – Skelett + Bewohner-Figur zur Ansicht + alle Actions (je Action eine NLA-Spur)
- models/anim_human.glb           – nur Skelett + Animationen (Godot hängt sie an jede Figur)
- src/anim_human_data.gd          – Länge, Schleife, Schrittlänge und Ereignisse (foot_l / foot_r) je Clip

Posen werden als Drehungen um Weltachsen relativ zum Elternknochen beschrieben (rig_human.R):
X + = nach vorn beugen (ein hängender Arm geht nach hinten), Y + = zur _r-Seite (+X) kippen,
Z + = zur _r-Seite drehen. Beine und Zielhaltungen werden über eine Zwei-Glieder-Lösung gesetzt,
damit Füße am Boden bleiben und die Waffe genau nach vorn zeigt.

Aufruf: python3 blender/anim_human.py [clipname ...]   (ohne Namen: alle Clips)
"""
import sys, os, math
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy
from mathutils import Vector, Matrix, Quaternion
import kit
import rig_human as rig
from rig_human import R

FPS = 30
CHAR_SCALE = 1.5                     # D.CHAR_SCALE: Schrittlängen gelten für die Figur im Spielmaßstab
STRIDE_WALK = 1.1                    # m je Zyklus im Spiel
STRIDE_RUN = 2.0
LOCO_T = 0.8                         # Länge jedes Lauf-Clips in Sekunden (alle gleich, damit sie sich mischen lassen)
I3 = Matrix.Identity(3)
J = rig.joints(1.0)
REST = {n: p for n, (par, p) in J.items()}
PARENT = {n: par for n, (par, p) in J.items()}
CLIPS = {}                           # name -> dict(len, loop, keys, events, stride, dense)


# ---------------------------------------------------------------- Posen-Werkzeug
class Pose(dict):
    """bone -> 3x3 (Drehung relativ zum Elternknochen, Weltachsen); 'loc' -> Verschiebung der Hüfte."""

    def copy(self):
        p = Pose()
        for k, v in self.items():
            p[k] = v.copy()
        return p

    def rot(self, bone):
        return self.get(bone, I3)

    def D(self, bone):
        """Gesamtdrehung eines Knochens gegenüber der Ruhelage."""
        m = self.rot(bone)
        par = PARENT[bone]
        while par is not None:
            m = self.rot(par) @ m
            par = PARENT[par]
        return m

    def P(self, bone):
        """Lage eines Gelenks im Modellraum."""
        par = PARENT[bone]
        if par is None:
            return REST[bone].copy()
        p = self.P(par) + self.D(par) @ (REST[bone] - REST[par])
        if bone == "hips":
            p = p + self.get("loc", Vector((0, 0, 0)))
        return p

    def set(self, **kw):
        """pose.set(chest=(rx, ry, rz), head=(...), loc=(x, y, z)) – Winkel in Grad."""
        for k, v in kw.items():
            self[k] = Vector(v) if k == "loc" else R(*v)
        return self

    def both(self, bone, rx=0.0, ry=0.0, rz=0.0):
        """Beide Seiten gespiegelt setzen (Angabe gilt für die _r-Seite)."""
        self[bone + "_r"] = R(rx, ry, rz)
        self[bone + "_l"] = R(rx, -ry, -rz)
        return self

    def leg(self, side, ankle, foot=None, pole=(0, -1, 0)):
        """Bein so stellen, dass der Knöchel in `ankle` (Modellraum) liegt; foot = Ausrichtung des Fußes (Welt)."""
        th, sh, ft = "thigh_" + side, "shin_" + side, "foot_" + side
        hip = self.P(th)
        knee, end = rig.two_bone(hip, ankle, rig.THIGH, rig.SHIN, pole)
        back = -Vector(pole)
        d_th = rig.aim_frame(knee - hip, back)
        d_sh = rig.aim_frame(end - knee, back)
        self[th] = self.D("hips").inverted() @ d_th
        self[sh] = d_th.inverted() @ d_sh
        self[ft] = d_sh.inverted() @ (foot if foot is not None else I3)
        return self

    def arm(self, side, wrist, pole=(0, 0.3, -1), hand=None):
        """Arm so stellen, dass das Handgelenk in `wrist` liegt. hand = Ausrichtung der Hand (Welt), sonst wie Unterarm."""
        ua, fa, ha = "upper_arm_" + side, "fore_arm_" + side, "hand_" + side
        sh = self.P(ua)
        elbow, end = rig.two_bone(sh, wrist, rig.UPPER, rig.FORE, pole)
        back = Vector((0, 1, 0.01))
        d_ua = rig.aim_frame(elbow - sh, back)
        d_fa = rig.aim_frame(end - elbow, Vector((0, 0.2, 1)))
        self[ua] = self.D(PARENT[ua]).inverted() @ d_ua
        self[fa] = d_ua.inverted() @ d_fa
        self[ha] = d_fa.inverted() @ hand if hand is not None else I3.copy()
        return self

    def grip(self, target, aim=None, pole=(0.25, 0.3, -1)):
        """Waffenhand (_r): der Griffpunkt (prop_r) liegt in `target`, die Waffe zeigt genau in Richtung `aim`
        (Drehung gegenüber "geradeaus", Standard: keine). Der Unterarm zeigt in Laufrichtung der Waffe."""
        aim = aim if aim is not None else I3
        # Hand so drehen, dass ihre Ruhe-Achse "nach unten" in Richtung der Waffe (nach vorn) zeigt
        hand = aim @ R(-90, 0, 0)
        wrist = Vector(target) - hand @ rig.GRIP
        self.arm("r", wrist, pole, hand)
        self["prop_r"] = self.D("hand_r").inverted() @ aim
        return self


def lerp_pose(a, b, t):
    """Mischt zwei Posen (für eigene Zwischenschritte)."""
    out = Pose()
    for k in set(a.keys()) | set(b.keys()):
        if k == "loc":
            out[k] = a.get(k, Vector((0, 0, 0))).lerp(b.get(k, Vector((0, 0, 0))), t)
        else:
            qa = a.get(k, I3).to_quaternion()
            qb = b.get(k, I3).to_quaternion()
            out[k] = qa.slerp(qb, t).to_matrix()
    return out


def clip(name, length, keys, loop=False, events=(), stride=0.0, dense=False):
    """keys = [(zeit, Pose)]; bei loop muss die letzte Pose der ersten gleichen (Zeit = length)."""
    CLIPS[name] = dict(len=length, loop=loop, keys=keys, events=list(events), stride=stride, dense=dense)


# ---------------------------------------------------------------- Grundhaltungen
def body(loc=(0, 0, 0), hips=(0, 0, 0), l=(0, 0, 0), r=(0, 0, 0), lp=0.0, rp=0.0, arms=True):
    """Hüfte verschieben/drehen, Füße bleiben am Boden. l/r = Versatz der Knöchel gegenüber dem Stand (x, y, z),
    lp/rp = Fußspitze senken (+) oder heben (-) in Grad. arms=True: Arme locker hängen lassen."""
    p = Pose()
    p["loc"] = Vector(loc)
    p["hips"] = R(*hips)
    for sx, s, off, pitch in ((-1, "l", l, lp), (1, "r", r, rp)):
        base = Vector((REST["foot_" + s].x + 0.01 * sx, 0.0, rig.ANKLE))
        p.leg(s, base + Vector(off), R(pitch, 0, 0) if pitch else I3, (sx * 0.12, -1, 0))
    if arms:
        relax(p)
    return p


def relax(p, l=True, r=True):
    if l:
        p["upper_arm_l"] = R(4, 7, 0)
        p["fore_arm_l"] = R(-14, 0, 0)
        p["hand_l"] = I3.copy()
    if r:
        p["upper_arm_r"] = R(4, -7, 0)
        p["fore_arm_r"] = R(-14, 0, 0)
        p["hand_r"] = I3.copy()
        p["prop_r"] = I3.copy()
    return p


def stand(drop=0.0, lean=0.0):
    """Lockerer Stand mit der Waffe in der Hand."""
    return body((0, 0, -drop), (lean, 0, 0))


def tuck(p, thigh=-100.0, shin=115.0, spread=8.0):
    """Beine anziehen (ohne Bodenkontakt)."""
    p["thigh_l"] = R(thigh, spread, 0)
    p["thigh_r"] = R(thigh, -spread, 0)
    p["shin_l"] = R(shin, 0, 0)
    p["shin_r"] = R(shin, 0, 0)
    p["foot_l"] = R(20, 0, 0)
    p["foot_r"] = R(20, 0, 0)
    return p


def c_idle():
    keys = []
    for i in range(5):
        k = math.sin(i * math.pi / 2)                       # 0, 1, 0, -1, 0  (Atmen)
        p = stand(0.006 + 0.006 * k)
        p.set(spine=(1.0 + 1.0 * k, 0, 0), chest=(1.0 * k, 0, 0), head=(-2.0 * k, 0, 0))
        p["upper_arm_l"] = R(4 - 2 * k, 7 + 1.5 * k, 0)
        p["upper_arm_r"] = R(4 - 2 * k, -7 - 1.5 * k, 0)
        keys.append((i * 0.6, p))
    keys[4] = (2.4, keys[0][1])
    clip("idle", 2.4, keys, loop=True)
    # umsehen
    s0 = stand(0.006)
    a = stand(0.008).set(spine=(0, 0, -6), chest=(0, 0, -10), head=(-3, 0, -32))
    b = stand(0.008).set(spine=(0, 0, 5), chest=(0, 0, 8), head=(2, 0, 30))
    clip("idle_look", 2.6, [(0.0, s0), (0.5, a), (1.1, a.copy().set(head=(-6, 0, -36))), (1.7, b), (2.2, b.copy().set(head=(4, 0, 26))), (2.6, s0)])
    # strecken: Arme über den Kopf, auf die Zehenspitzen
    up = body((0, 0, 0.03), (-4, 0, 0), l=(0, 0, 0.03), r=(0, 0, 0.03), lp=18, rp=18, arms=False)
    up.set(spine=(-7, 0, 0), chest=(-8, 0, 0), head=(-14, 0, 0))
    up.both("upper_arm", -10, -158, 0).both("fore_arm", -25, 0, 0)
    up2 = up.copy().set(spine=(-9, 3, 0), chest=(-9, 4, 0))
    up2.both("upper_arm", -6, -164, 0)
    mid = stand(0.0).set(chest=(3, 0, 0))
    mid.both("upper_arm", 0, -70, 0).both("fore_arm", -30, 0, 0)
    clip("idle_stretch", 3.0, [(0.0, s0), (0.7, up), (1.5, up2), (1.9, up), (2.5, mid), (3.0, s0)])
    # Waffe prüfen: anheben, ansehen, kippen
    w1 = stand(0.006).set(spine=(3, 0, 0), chest=(4, 0, 6), head=(14, 0, 8))
    w1.set(upper_arm_r=(-48, -6, -12), fore_arm_r=(-72, 0, 0), hand_r=(0, 0, 25), upper_arm_l=(-40, 18, 20), fore_arm_l=(-85, 0, 0))
    w2 = w1.copy().set(hand_r=(0, 0, -35), head=(16, 0, 14), fore_arm_l=(-70, 0, 0))
    w3 = w1.copy().set(hand_r=(0, 30, 10), upper_arm_l=(-52, 18, 26), fore_arm_l=(-95, 0, 0))
    clip("idle_weapon_check", 2.8, [(0.0, s0), (0.5, w1), (1.0, w2), (1.5, w3), (1.9, w3.copy().set(fore_arm_l=(-75, 0, 0))), (2.3, w1), (2.8, s0)])


# ---------------------------------------------------------------- Gehen und Rennen
def loco(name, d, stride_world, run, carry=False):
    """Ein Lauf-Zyklus (zwei Schritte) in Richtung d (Modellraum, Länge 1). Der Standfuß bewegt sich mit genau
    stride / LOCO_T gegen die Laufrichtung – spielt Godot den Clip mit Tempo ÷ Schrittlänge ab, rutscht nichts."""
    d = Vector((d[0], d[1], 0.0)).normalized()
    fwd = -d.y                                               # 1 vorwärts, -1 rückwärts, 0 seitwärts
    side = d.x
    stride = stride_world / CHAR_SCALE
    duty = 0.27 if run else 0.56
    A = stride * duty * 0.5
    drop = 0.082 if run else 0.076
    bounce = -0.02 if run else 0.011                         # Rennen: in der Flugphase oben; Gehen: über dem Standbein oben
    lift = 0.13 if run else 0.07
    n = int(round(LOCO_T * FPS))
    axis = Vector((-d.y, d.x, 0.0))                          # Fuß kippt um die Achse quer zur Laufrichtung
    keys = []
    for f in range(n + 1):
        ph = f / n
        p = Pose()
        c2 = math.cos(2 * math.pi * ph)
        s2 = math.sin(2 * math.pi * ph)
        z = -drop + bounce * math.cos(4 * math.pi * (ph - duty * 0.5))
        sway = (0.012 if run else 0.02) * math.cos(2 * math.pi * (ph - duty * 0.5))
        p["loc"] = Vector((-sway * (1.0 - abs(side)), 0, z))
        lean = (9.0 if run else 3.0) * fwd if fwd > 0 else (4.0 if run else 2.0) * fwd
        yaw = (6.0 if run else 4.0) * c2 * fwd
        roll = (2.0 if run else 2.5) * math.cos(2 * math.pi * (ph - duty * 0.5)) * (1.0 - abs(side)) + side * (5.0 if run else 2.5)
        p["hips"] = R(lean, roll, yaw)
        p["spine"] = R(lean * 0.3, -roll * 0.6, -yaw * 0.8)
        p["chest"] = R(lean * 0.2, -roll * 0.4, -yaw * 1.0)
        p["head"] = R(-lean * 0.9, 0, yaw * 0.8) @ R(2.0 * math.cos(4 * math.pi * ph), 0, 0)
        for sx, s, off in ((-1, "l", 0.0), (1, "r", 0.5)):
            u = (ph + off) % 1.0
            if u < duty:
                k = u / duty
                along = A * (1.0 - 2.0 * k)
                h = 0.0
                pitch = 0.0
            else:
                k = (u - duty) / (1.0 - duty)
                along = -A * math.cos(math.pi * k)
                h = lift * math.sin(math.pi * k) ** 0.8
                pitch = (38.0 if run else 22.0) * math.sin(2 * math.pi * k) * (1.0 if k < 0.5 else 0.5)
            base = Vector((REST["foot_" + s].x + sx * (0.015 + 0.05 * abs(side)), 0.0, rig.ANKLE))
            foot = Matrix.Rotation(math.radians(pitch), 3, axis) if pitch != 0.0 else I3
            pole = Vector((sx * 0.12, -1.0, 0.0))
            p.leg(s, base + d * along + Vector((0, 0, h)), foot, pole)
        if carry:
            carry_arms(p, 0.006 * math.cos(4 * math.pi * ph))
        else:
            sw = (46.0 if run else 24.0) * c2 * (fwd if abs(fwd) > 0.3 else 0.35)
            bend = 72.0 if run else 22.0
            p["upper_arm_l"] = R(sw * 1.0 - (8 if run else 0), 9, 0)
            p["upper_arm_r"] = R(-sw * 1.0 - (8 if run else 0), -9, 0)
            p["fore_arm_l"] = R(-bend - max(-sw, 0.0) * 0.5, 0, 0)
            p["fore_arm_r"] = R(-bend - max(sw, 0.0) * 0.5, 0, 0)
        keys.append((ph * LOCO_T, p))
    ev = [(0.0, "foot_l"), (LOCO_T * 0.5, "foot_r")]
    clip(name, LOCO_T, keys, loop=True, events=ev, stride=stride_world, dense=True)


def carry_arms(p, bob=0.0):
    """Beide Hände halten eine Last vor dem Bauch."""
    ch = p.P("chest")
    for sx, s in ((-1, "l"), (1, "r")):
        p.arm(s, ch + p.D("chest") @ Vector((sx * 0.2, -0.36, 0.02 + bob)), (sx * 0.6, 0.3, -1))
    return p


# ---------------------------------------------------------------- Oberkörper: Zielhaltungen
AIM = {
    # Griffpunkt der Waffenhand, Stützhand (Handgelenk), Rumpf (spine, chest, head)
    "rifle": dict(g=(0.10, -0.27, 0.98), l=(-0.05, -0.40, 0.95), spine=(2, 0, 0), chest=(2, 0, 0), head=(0, 0, 0)),
    "heavy": dict(g=(0.19, -0.21, 0.80), l=(0.00, -0.38, 0.80), spine=(7, 0, 0), chest=(5, 0, 0), head=(-10, 0, 0)),
    "thrower": dict(g=(0.20, -0.25, 0.86), l=(0.02, -0.42, 0.84), spine=(-4, 0, 0), chest=(-3, 0, 0), head=(5, 0, 0)),
    "spray": dict(g=(0.17, -0.25, 0.82), l=(-0.04, -0.40, 0.86), spine=(9, 0, 0), chest=(6, 0, 0), head=(-12, 0, 0)),
    "bow": dict(g=(0.19, -0.50, 1.02), l=(-0.04, -0.12, 1.04), spine=(0, 0, 0), chest=(-2, 0, 0), head=(0, 0, 0)),
    "melee": dict(g=(0.38, -0.20, 0.92), l=None, spine=(4, 0, 0), chest=(3, 0, 0), head=(-3, 0, 0)),
    # V4 Waffen-Arsenal: Pistole (beidhändig vor der Brust), Speer (an der Hüfte, Stützhand vorn am Schaft),
    # schwere Zweihandwaffe (Hammer, Leiter), Wurfhaltung (Hand an der Schulter), Stab (Strahl, Aufladen)
    "pistol": dict(g=(0.10, -0.40, 1.06), l=(0.00, -0.38, 1.02), spine=(1, 0, 0), chest=(1, 0, 0), head=(0, 0, 0)),
    "spear": dict(g=(0.18, -0.16, 0.90), l=(-0.02, -0.46, 0.96), spine=(5, 0, 0), chest=(3, 0, -4), head=(-4, 0, 4)),
    "hammer": dict(g=(0.18, -0.20, 0.84), l=(0.08, -0.36, 0.88), spine=(6, 0, 0), chest=(4, 0, 0), head=(-6, 0, 0)),
    "toss": dict(g=(0.24, -0.14, 1.16), l=(-0.14, -0.38, 1.00), spine=(-2, 0, 0), chest=(-2, 0, 6), head=(2, 0, -4)),
    "staff": dict(g=(0.15, -0.30, 0.96), l=(-0.03, -0.48, 1.00), spine=(3, 0, 0), chest=(2, 0, 0), head=(-2, 0, 0)),
}


def aim_pose(kind, dg=(0, 0, 0), aim=None, lhand=None, **over):
    """Haltepose je Waffenart; dg verschiebt den Griff, aim dreht die Waffe, lhand setzt die Stützhand woanders hin."""
    a = AIM[kind]
    p = stand(0.01)
    p.set(spine=over.get("spine", a["spine"]), chest=over.get("chest", a["chest"]), head=over.get("head", a["head"]))
    g = Vector(a["g"]) + Vector(dg)
    p.grip(g, aim)
    if kind == "melee" and lhand is None:
        p.set(upper_arm_l=(-28, 0, 72), fore_arm_l=(-22, 0, 0))     # Schildarm quer vor dem Körper
    elif kind == "bow" and lhand is None:
        p.arm("l", a["l"], (-1, 0.6, 0.2))                           # Sehne am Kinn, Ellbogen nach außen-hinten
    else:
        lt = Vector(lhand) if lhand is not None else Vector(a["l"]) + Vector(dg)
        p.arm("l", lt, (-0.6, 0.2, -1))
    return p


def c_aims():
    for kind in AIM:
        a = aim_pose(kind)
        b = aim_pose(kind, dg=(0, 0, -0.006), chest=tuple(v + (0.8 if i == 0 else 0) for i, v in enumerate(AIM[kind]["chest"])))
        clip("aim_" + kind, 2.0, [(0.0, a), (1.0, b), (2.0, a)], loop=True)
        # Bereitschaft ohne Ziel: Waffe gesenkt vor dem Körper (Zusatz zur Clipliste, damit die Waffe nicht schlenkert)
        low = dict(dg=(0.0, 0.05, -0.1), aim=R(24, 0, -14), spine=(1, 0, 0), chest=(1, 0, 0), head=(0, 0, 0))
        if kind == "bow":
            low = dict(dg=(0.02, 0.2, -0.22), aim=R(30, 0, -10), lhand=(-0.2, -0.12, 0.74), spine=(1, 0, 0), chest=(1, 0, 0))
        elif kind in ("melee", "spear", "hammer"):
            low = dict(dg=(0.0, 0.1, -0.2), aim=R(30, 0, 0), spine=(1, 0, 0), chest=(1, 0, 0), head=(0, 0, 0))
        elif kind == "toss":
            low = dict(dg=(-0.04, 0.0, -0.26), aim=R(30, 0, -10), spine=(1, 0, 0), chest=(1, 0, 0), head=(0, 0, 0))
        a = aim_pose(kind, **low)
        low2 = dict(low)
        low2["dg"] = (low["dg"][0], low["dg"][1], low["dg"][2] - 0.008)
        low2["chest"] = (2, 0, 0)
        clip("hold_" + kind, 2.4, [(0.0, a), (1.2, aim_pose(kind, **low2)), (2.4, a)], loop=True)


def zero(*bones):
    z = Pose()
    for b in bones:
        z[b] = I3.copy()
    return z


def c_fire():
    """Schuss. rifle/heavy/spray sind additiv (Abweichung von der Ruhelage = reiner Rückstoß), bow/throw/swing sind
    vollständige Oberkörper-Abläufe, die in der Zielhaltung beginnen und enden."""
    bones = ("spine", "chest", "head", "shoulder_r", "upper_arm_r", "upper_arm_l", "fore_arm_r")
    z = zero(*bones)
    k = z.copy().set(spine=(-1.5, 0, 0), chest=(-3.0, 0, 1.5), head=(4.0, 0, -1.0), shoulder_r=(0, 0, 5.0), upper_arm_r=(-4.0, 0, 0), upper_arm_l=(-2.0, 0, 0), fore_arm_r=(3, 0, 0))
    clip("fire_rifle", 4 / 30, [(0.0, z), (1 / 30, k), (4 / 30, z)])
    k = z.copy().set(spine=(-5, 0, 0), chest=(-8, 0, 3), head=(9, 0, -2), shoulder_r=(0, 0, 10), upper_arm_r=(-9, 0, 0), upper_arm_l=(-5, 0, 0), fore_arm_r=(8, 0, 0))
    k2 = z.copy().set(spine=(-2, 0, 0), chest=(-3, 0, 1), head=(3, 0, 0), shoulder_r=(0, 0, 3), upper_arm_r=(-3, 0, 0), upper_arm_l=(-2, 0, 0), fore_arm_r=(2, 0, 0))
    clip("fire_heavy", 10 / 30, [(0.0, z), (2 / 30, k), (5 / 30, k2), (10 / 30, z)])
    a = z.copy().set(spine=(-2, 0, 0), chest=(-2, 0, 1.5), head=(1.5, 0, 0), upper_arm_r=(-1.5, 0, 0), upper_arm_l=(1, 0, 0))
    b = z.copy().set(spine=(-2.5, 0, 0), chest=(-1.5, 0, -1.5), head=(2, 0, 0), upper_arm_r=(1, 0, 0), upper_arm_l=(-1.5, 0, 0))
    clip("fire_spray_loop", 0.4, [(0.0, a), (0.1, b), (0.2, a.copy().set(chest=(-2.5, 0, 1))), (0.3, b), (0.4, a)], loop=True)
    # Bogen: lösen, neuen Pfeil auflegen, spannen
    aim = aim_pose("bow")
    rel = aim_pose("bow", dg=(0, 0.02, 0.01), lhand=(-0.12, 0.02, 1.08), chest=(-4, 0, 0))
    nock = aim_pose("bow", dg=(0, 0.03, 0), lhand=(0.06, -0.36, 1.02), chest=(1, 0, 0), head=(4, 0, 4))
    half = aim_pose("bow", lhand=(0.0, -0.24, 1.03))
    clip("fire_bow", 0.5, [(0.0, aim), (0.05, rel), (0.2, nock), (0.36, half), (0.5, aim)])
    # Werfer: dumpfer Stoß nach hinten-oben, Körper federt nach
    aim = aim_pose("thrower")
    k1 = aim_pose("thrower", dg=(0, 0.09, 0.05), aim=R(-10, 0, 0), spine=(-11, 0, 0), chest=(-9, 0, 2), head=(12, 0, 0))
    k2 = aim_pose("thrower", dg=(0, -0.02, -0.02), aim=R(3, 0, 0), spine=(0, 0, 0), chest=(1, 0, 0), head=(2, 0, 0))
    clip("fire_throw", 0.4, [(0.0, aim), (0.06, k1), (0.22, k2), (0.4, aim)])
    # Nahkampf: ausholen, quer durchziehen, zurück (die Waffe verlängert dabei den Unterarm)
    aim = aim_pose("melee")
    wind = aim_pose("melee", spine=(0, 0, 10), chest=(-4, 0, 22), head=(0, 0, -26))
    wind.set(upper_arm_r=(-125, -48, 0), fore_arm_r=(-62, 0, 0), hand_r=(0, 0, 0), prop_r=(60, 0, 0))
    hit = aim_pose("melee", spine=(8, 0, -14), chest=(8, 0, -28), head=(-4, 0, 34))
    hit.set(upper_arm_r=(-72, 58, 0), fore_arm_r=(-14, 0, 0), hand_r=(0, 0, 0), prop_r=(90, 0, 0))
    mid = aim_pose("melee", spine=(4, 0, -2), chest=(2, 0, -4), head=(-2, 0, 4))
    mid.set(upper_arm_r=(-96, 4, 0), fore_arm_r=(-20, 0, 0), hand_r=(0, 0, 0), prop_r=(84, 0, 0))
    clip("fire_swing", 0.34, [(0.0, aim), (0.07, wind), (0.14, mid), (0.2, hit), (0.34, aim)])


def c_fire_v4():
    """V4 Waffen-Arsenal: Stoß, Hammerschlag, Wurf, Stab-Stoß. Vollständige Oberkörper-Abläufe (wie fire_swing)."""
    # Speer/Brecheisen/Bohrer: zurücknehmen, kräftig nach vorn stoßen, zurück
    aim = aim_pose("spear")
    back = aim_pose("spear", dg=(0.02, 0.16, 0.0), spine=(0, 0, 6), chest=(-2, 0, 12), head=(0, 0, -10))
    hit = aim_pose("spear", dg=(-0.04, -0.28, 0.03), spine=(10, 0, -4), chest=(8, 0, -12), head=(-8, 0, 10))
    clip("fire_thrust", 0.36, [(0.0, aim), (0.1, back), (0.18, hit), (0.24, hit), (0.36, aim)])
    # schwere Zweihandwaffe: hoch über den Kopf, mit ganzem Körper herunter
    aim = aim_pose("hammer")
    up = aim_pose("hammer", dg=(-0.04, 0.12, 0.40), aim=R(-80, 0, 0), spine=(-8, 0, 0), chest=(-8, 0, 0), head=(8, 0, 0))
    down = aim_pose("hammer", dg=(0.0, -0.16, -0.22), aim=R(40, 0, 0), spine=(16, 0, 0), chest=(12, 0, 0), head=(-12, 0, 0))
    clip("fire_slam", 0.5, [(0.0, aim), (0.18, up), (0.3, down), (0.38, down), (0.5, aim)])
    # Wurf: ausholen hinter die Schulter, nach vorn schleudern
    aim = aim_pose("toss")
    wind = aim_pose("toss", dg=(0.04, 0.22, 0.10), aim=R(-50, 0, 20), spine=(-4, 0, 10), chest=(-4, 0, 24), head=(2, 0, -18))
    rel = aim_pose("toss", dg=(-0.10, -0.30, -0.04), aim=R(15, 0, -10), spine=(6, 0, -10), chest=(8, 0, -22), head=(-6, 0, 16))
    clip("fire_toss", 0.42, [(0.0, aim), (0.14, wind), (0.24, rel), (0.3, rel), (0.42, aim)])
    # Stab: kurzer Stoß nach vorn-oben (Strahl lösen, aufgeladenen Schuss abgeben)
    aim = aim_pose("staff")
    push = aim_pose("staff", dg=(0.0, -0.12, 0.08), aim=R(-12, 0, 0), spine=(-3, 0, 0), chest=(-4, 0, 0), head=(3, 0, 0))
    clip("fire_cast", 0.4, [(0.0, aim), (0.1, push), (0.2, push), (0.4, aim)])


def c_reload():
    # Gewehr: Waffe ankippen, Magazin vom Gürtel holen, einsetzen, durchladen
    aim = aim_pose("rifle")
    tilt = dict(dg=(0.04, 0.03, 0.03), aim=R(-32, 0, -18), head=(14, 0, 6))
    r1 = aim_pose("rifle", lhand=(-0.24, -0.10, 0.66), **tilt)
    r2 = aim_pose("rifle", lhand=(0.05, -0.30, 0.86), **tilt)
    r3 = aim_pose("rifle", lhand=(0.07, -0.31, 0.95), **tilt)
    r4 = aim_pose("rifle", dg=(0.02, 0.02, 0.02), aim=R(-12, 0, -8), lhand=(0.06, -0.20, 1.08), head=(6, 0, 4))
    r5 = aim_pose("rifle", dg=(0.02, 0.04, 0.02), aim=R(-12, 0, -8), lhand=(0.08, -0.10, 1.08), head=(6, 0, 4))
    clip("reload_rifle", 1.6, [(0.0, aim), (0.3, r1), (0.7, r2), (0.85, r3), (1.1, r4), (1.25, r5), (1.6, aim)])
    # schwere Waffe: abknicken, zwei Ladungen nachschieben, zuklappen
    aim = aim_pose("heavy")
    tilt = dict(dg=(0.0, 0.02, 0.04), aim=R(38, 0, -10), head=(8, 0, 4))
    h1 = aim_pose("heavy", lhand=(-0.25, -0.08, 0.64), **tilt)
    h2 = aim_pose("heavy", lhand=(0.10, -0.22, 0.90), **tilt)
    h3 = aim_pose("heavy", lhand=(-0.22, -0.10, 0.66), **tilt)
    h5 = aim_pose("heavy", dg=(0, 0.03, 0.06), aim=R(-14, 0, 0), spine=(-2, 0, 0), chest=(-2, 0, 0))
    clip("reload_heavy", 1.6, [(0.0, aim), (0.25, h1), (0.55, h2), (0.8, h3), (1.1, h2), (1.35, h5), (1.6, aim)])
    # Bogen: Pfeil aus dem Köcher über die Schulter ziehen
    aim = aim_pose("bow")
    low = dict(dg=(0, 0.12, -0.08), aim=R(14, 0, 0))
    b1 = aim_pose("bow", lhand=(-0.2, -0.2, 0.9), **low)
    b1.set(upper_arm_l=(-165, 24, 0), fore_arm_l=(-118, 0, 0), head=(0, 0, -14))
    b2 = aim_pose("bow", lhand=(-0.2, -0.2, 0.9), **low)
    b2.set(upper_arm_l=(-140, 30, 0), fore_arm_l=(-70, 0, 0), head=(0, 0, -6))
    b3 = aim_pose("bow", dg=(0, 0.04, 0), lhand=(0.06, -0.34, 1.02), head=(4, 0, 4))
    clip("reload_bow", 1.2, [(0.0, aim), (0.3, b1), (0.55, b2), (0.85, b3), (1.2, aim)])
    # Werfer/Sprühgerät: Rohr hochstellen, von oben nachfüllen, zurück in den Anschlag
    aim = aim_pose("thrower")
    up = dict(dg=(-0.06, 0.02, 0.0), aim=R(-62, 0, 0), head=(-6, 0, 4))
    t1 = aim_pose("thrower", lhand=(-0.22, -0.10, 0.66), **up)
    t2 = aim_pose("thrower", lhand=(0.10, -0.36, 1.12), **up)
    t3 = aim_pose("thrower", lhand=(0.12, -0.33, 0.98), **up)
    t4 = aim_pose("thrower", dg=(0, 0.02, 0.03), aim=R(-20, 0, 0))
    clip("reload_thrower", 1.8, [(0.0, aim), (0.35, t1), (0.8, t2), (1.05, t3), (1.25, t2), (1.5, t4), (1.8, aim)])


# ---------------------------------------------------------------- Ausweichen, Treffer, Tod
def roll_keys(total, spin=360.0, end_drop=0.13):
    """Rolle vorwärts: der ganze Körper dreht sich einmal um die Querachse, Arme und Beine angezogen."""
    start = body((0, 0, -0.05), (14, 0, 0))
    start.set(spine=(10, 0, 0), chest=(8, 0, 0))
    keys = [(0.0, start)]
    steps = [(0.14, 55, -0.20), (0.32, 135, -0.33), (0.5, 215, -0.34), (0.68, 290, -0.28), (0.86, 340, -0.18)]
    for k, ang, z in steps:
        p = Pose()
        p["loc"] = Vector((0, 0, z))
        p["hips"] = R(ang * spin / 360.0, 0, 0)
        p.set(spine=(34, 0, 0), chest=(30, 0, 0), neck=(14, 0, 0), head=(24, 0, 0))
        tuck(p)
        p.both("upper_arm", -62, -14, 0).both("fore_arm", -112, 0, 0)
        p["prop_r"] = I3.copy()
        p["hand_r"] = I3.copy()
        keys.append((k * total, p))
    keys.append((total, land_pose(end_drop)))
    return keys


def land_pose(drop=0.13):
    p = body((0, 0, -drop), (16, 0, 0), l=(-0.03, 0.05, 0), r=(0.03, -0.06, 0), arms=False)
    p.set(spine=(10, 0, 0), chest=(6, 0, 0), head=(-18, 0, 0))
    p.both("upper_arm", 16, -24, 0).both("fore_arm", -40, 0, 0)
    return p


def c_dodge_hit():
    clip("dodge_roll", 0.45, roll_keys(0.45))
    clip("dodge_land", 4 / 30, [(0.0, land_pose()), (4 / 30, stand(0.006))])
    s0 = stand(0.006)
    # leichter Treffer: kurzes Zucken
    h = body((0, 0.03, -0.02), (-6, 0, 0)).set(spine=(-6, 0, 0), chest=(-8, 0, 6), head=(12, 0, -8))
    h.set(upper_arm_l=(-10, 26, 0), upper_arm_r=(-6, -20, 0))
    clip("hit_light", 0.3, [(0.0, s0), (0.06, h), (0.3, s0)])
    # schwerer Treffer: taumeln, Schritt zurück
    h1 = body((0, 0.07, -0.05), (-14, 0, 6), r=(0.02, 0.16, 0), arms=False).set(spine=(-8, 0, 0), chest=(-10, 0, 10), head=(16, 0, -10))
    h1.set(upper_arm_l=(-50, 50, 0), fore_arm_l=(-40, 0, 0), upper_arm_r=(-30, -45, 0), fore_arm_r=(-50, 0, 0))
    h2 = body((0, 0.05, -0.08), (6, 0, 2), r=(0.02, 0.14, 0)).set(spine=(8, 0, 0), chest=(6, 0, 0), head=(-6, 0, 0))
    clip("hit_heavy", 0.55, [(0.0, s0), (0.1, h1), (0.3, h2), (0.55, s0)])
    # umfallen (nach hinten) und liegen bleiben
    k1 = body((0, 0.04, -0.10), (-18, 0, 0), arms=False).set(spine=(-8, 0, 0), chest=(-8, 0, 0), head=(14, 0, 0))
    k1.both("upper_arm", -70, -30, 0).both("fore_arm", -30, 0, 0)
    k2 = lying(-70, -0.34, 0.14)
    k2.both("upper_arm", -40, -60, 0)
    k3 = lying()
    k4 = lying(-88, -0.405, 0.2)
    clip("down", 0.7, [(0.0, s0), (0.14, k1), (0.36, k2), (0.5, k3), (0.58, k4), (0.7, k3)])
    # aufstehen: aufsetzen, abstützen, hochdrücken
    sit = Pose()
    sit["loc"] = Vector((0, 0.12, -0.37))
    sit["hips"] = R(-38, 0, 0)
    sit.set(spine=(18, 0, 0), chest=(14, 0, 0), head=(6, 0, 0), thigh_l=(-78, 8, 0), thigh_r=(-78, -8, 0), shin_l=(96, 0, 0), shin_r=(96, 0, 0), foot_l=(20, 0, 0), foot_r=(20, 0, 0))
    sit.both("upper_arm", 50, -22, 0).both("fore_arm", -10, 0, 0)
    cr = body((0, 0.02, -0.15), (22, 0, 0), l=(0, -0.04, 0), r=(0, 0.06, 0), arms=False).set(spine=(12, 0, 0), chest=(8, 0, 0), head=(-20, 0, 0))
    cr.both("upper_arm", -20, -16, 0).both("fore_arm", -50, 0, 0)
    clip("revive", 0.9, [(0.0, lying()), (0.3, sit), (0.6, cr), (0.9, s0)])


def lying(ang=-90.0, z=-0.415, y=0.2):
    """Auf dem Rücken liegend, Arme und Beine locker gespreizt."""
    p = Pose()
    p["loc"] = Vector((0, y, z))
    p["hips"] = R(ang, 0, 0)
    p.set(spine=(2, 0, 0), chest=(2, 0, 0), head=(-4, 0, 6), thigh_l=(6, 10, 0), thigh_r=(8, -12, 0), shin_l=(-4, 0, 0), shin_r=(-6, 0, 0),
          foot_l=(-10, 0, 0), foot_r=(-10, 0, 0))
    p.set(upper_arm_l=(4, 58, 0), upper_arm_r=(4, -50, 0), fore_arm_l=(-12, 0, 0), fore_arm_r=(-16, 0, 0), hand_r=(0, 0, 0), prop_r=(90, 0, 0))
    return p


# ---------------------------------------------------------------- Arbeit
def c_work():
    # Holz hacken: beidhändig über den Kopf, kräftig nach unten (Werkzeug an prop_r)
    def two_hand(up_r, fore, lean, drop=0.0, twist=0.0):
        p = body((0, -0.01 * lean / 10.0, -drop), (lean * 0.4, 0, 0), l=(-0.02, -0.06, 0), r=(0.02, 0.06, 0), arms=False)
        p.set(spine=(lean * 0.35, 0, twist * 0.4), chest=(lean * 0.3, 0, twist * 0.6), head=(-lean * 0.5, 0, -twist * 0.6))
        p.set(upper_arm_r=(up_r, 12, 0), fore_arm_r=(fore, 0, 0), upper_arm_l=(up_r, -22, 0), fore_arm_l=(fore - 10, 0, 0))
        p["hand_r"] = I3.copy()
        p["prop_r"] = I3.copy()
        return p
    ready = two_hand(-70, -50, 4)
    top = two_hand(-165, -55, -12)
    hit = two_hand(-48, -22, 30, 0.07)
    hit2 = two_hand(-52, -26, 27, 0.06)
    clip("chop", 1.0, [(0.0, ready), (0.38, top), (0.46, top.copy().set(chest=(-6, 0, 0))), (0.56, hit), (0.66, hit2), (1.0, ready)], loop=True)
    # Erz abbauen: seitlich ausholen, schräg nach vorn-unten schlagen
    ready = two_hand(-70, -50, 4, 0.0, 10)
    top = two_hand(-150, -70, -6, 0.0, 34)
    hit = two_hand(-58, -18, 22, 0.05, -24)
    hit2 = two_hand(-62, -22, 20, 0.04, -20)
    clip("mine", 1.0, [(0.0, ready), (0.4, top), (0.54, hit), (0.64, hit2), (1.0, ready)], loop=True)
    # aufheben: in die Knie, freie Hand (_l) greift nach unten
    s0 = stand(0.006)
    lo = body((0, -0.05, -0.2), (38, 0, 0), l=(0, -0.05, 0), r=(0, 0.07, 0)).set(spine=(22, 0, 0), chest=(14, 0, -8), head=(-30, 0, 0))
    lo.set(upper_arm_l=(-48, -6, 0), fore_arm_l=(-8, 0, 0))
    lo2 = lo.copy().set(upper_arm_l=(-56, -10, 0), fore_arm_l=(-30, 0, 0))
    clip("pick_up", 0.8, [(0.0, s0), (0.3, lo), (0.42, lo2), (0.8, s0)])
    loco("carry_walk", (0, -1), STRIDE_WALK, False, carry=True)
    # hämmern: Werkzeughand schlägt vor der Brust, freie Hand hält
    def ham(up, fore, bob):
        p = body((0, -0.02, -0.03 - bob), (10, 0, 0), l=(0, -0.05, 0), r=(0, 0.05, 0), arms=False)
        p.set(spine=(8, 0, 0), chest=(6 + bob * 100, 0, -6), head=(-8, 0, 4), upper_arm_r=(up, -8, 0), fore_arm_r=(fore, 0, 0), upper_arm_l=(-50, 14, 14), fore_arm_l=(-52, 0, 0))
        p["hand_r"] = I3.copy()
        p["prop_r"] = I3.copy()
        return p
    a = ham(-95, -105, 0.0)
    b = ham(-52, -30, 0.02)
    clip("hammer", 0.6, [(0.0, a), (0.2, a.copy().set(fore_arm_r=(-112, 0, 0))), (0.32, b), (0.4, ham(-56, -38, 0.015)), (0.6, a)], loop=True)
    # Münzen werfen: freie Hand zur Tasche, im Bogen nach vorn
    p1 = stand(0.01).set(chest=(4, 0, 8), head=(6, 0, -6), upper_arm_l=(22, 10, 0), fore_arm_l=(-70, 0, 0))
    p2 = stand(0.0).set(spine=(-2, 0, 0), chest=(-3, 0, -10), head=(-6, 0, 4), upper_arm_l=(-118, 6, 0), fore_arm_l=(-12, 0, 0), hand_l=(-30, 0, 0))
    p3 = stand(0.004).set(chest=(2, 0, -6), upper_arm_l=(-80, 8, 0), fore_arm_l=(-28, 0, 0))
    clip("pay", 0.9, [(0.0, s0), (0.22, p1), (0.46, p2), (0.62, p3), (0.9, s0)])
    # winken mit der freien Hand
    def wv(k):
        p = stand(0.004).set(spine=(0, -2, 0), chest=(-2, -3, -4), head=(-4, -4 + k * 0.1, 0), upper_arm_l=(0, 148, 0), fore_arm_l=(-10, 28 * k, 0), hand_l=(0, 14 * k, 0))
        return p
    clip("wave", 1.5, [(0.0, s0), (0.25, wv(-1)), (0.45, wv(1)), (0.65, wv(-1)), (0.85, wv(1)), (1.05, wv(-1)), (1.2, wv(0.4)), (1.5, s0)])
    # jubeln: hüpfen mit beiden Armen oben (Schleife)
    def ch(z, arm, fore, lean):
        p = body((0, 0, z), (lean, 0, 0), l=(0, 0, max(z, 0.0)), r=(0, 0, max(z, 0.0)), lp=30 if z > 0.02 else 0, rp=30 if z > 0.02 else 0, arms=False)
        p.set(spine=(-lean, 0, 0), chest=(-4, 0, 0), head=(-10, 0, 0))
        p.both("upper_arm", -8, arm, 0).both("fore_arm", fore, 0, 0)
        p["hand_r"] = I3.copy()
        p["prop_r"] = I3.copy()
        return p
    c0 = ch(-0.07, -138, -50, 8)
    clip("cheer", 0.6, [(0.0, c0), (0.14, ch(0.06, -158, -12, 0)), (0.28, ch(0.15, -164, -6, -4)), (0.42, ch(0.05, -156, -16, 0)), (0.6, c0)], loop=True)
    # sitzen (am Boden, Beine nach vorn); die Endpose wird gehalten
    def sit(k=0.0):
        p = Pose()
        p["loc"] = Vector((0, 0.1, -0.36))
        p["hips"] = R(-12 - k, 0, 0)
        p.set(spine=(8 + k, 0, 0), chest=(6, 0, 0), head=(2 - k, 0, 0), thigh_l=(-74, 10, 0), thigh_r=(-70, -12, 0), shin_l=(4, 0, 0), shin_r=(10, 0, 0), foot_l=(-8, 0, 0), foot_r=(-4, 0, 0))
        p.set(upper_arm_l=(-36, 14, 0), fore_arm_l=(-44, 0, 0), upper_arm_r=(-32, -14, 0), fore_arm_r=(-48, 0, 0), hand_r=(0, 0, 0), prop_r=(0, 0, 0))
        return p
    half = body((0, 0.06, -0.2), (14, 0, 0)).set(spine=(10, 0, 0), head=(-10, 0, 0))
    clip("sit", 2.6, [(0.0, s0), (0.3, half), (0.6, sit()), (1.6, sit(2.0)), (2.6, sit())])
    # schlafen: auf dem Rücken, ruhiges Atmen (Schleife)
    def sl(k):
        p = lying()
        p.set(chest=(2 - 3 * k, 0, 0), head=(-4, 0, 16), upper_arm_l=(-30, 30, 0), fore_arm_l=(-100, 0, 0), upper_arm_r=(-26, -28, 0), fore_arm_r=(-96, 0, 0), thigh_l=(-16, 8, 0), shin_l=(30, 0, 0))
        return p
    a = sl(0)
    clip("sleep", 3.0, [(0.0, a), (1.5, sl(1)), (3.0, a)], loop=True)


def c_welt():
    """Paket Welt (V5): Tagesablauf und Berufe der Bewohner – Stirn wischen, Hühner scheuchen, Hände am Feuer wärmen,
    frühstücken. (Die Schubkarre schiebt der Steinmetz im Trage-Gang carry_walk; die Karre hängt vor seinen Händen.)"""
    s0 = stand(0.006)
    # Stirn wischen: linke Hand an die Stirn, zur Seite streichen, ausatmen
    w1 = stand(0.004).set(head=(-8, 0, 0), upper_arm_l=(-122, 22, 0), fore_arm_l=(-118, 0, 0), hand_l=(0, 0, -20))
    w2 = stand(0.004).set(head=(-4, 0, -10), chest=(0, 0, 4), upper_arm_l=(-112, 52, 0), fore_arm_l=(-104, 0, 0), hand_l=(0, 0, -10))
    w3 = stand(0.012).set(spine=(7, 0, 0), chest=(5, 0, 0), head=(8, 0, 0), upper_arm_l=(-30, 30, 0), fore_arm_l=(-40, 0, 0))
    clip("wipe_brow", 1.6, [(0.0, s0), (0.35, w1), (0.7, w2), (0.85, w2), (1.15, w3), (1.6, s0)])
    # Hühner scheuchen: vorgebeugt, beide Arme schwingen nach vorn-unten
    def sh(up, fore, z):
        p = body((0, -0.03, -0.05 - z), (16, 0, 0))
        p.set(spine=(12, 0, 0), chest=(6, 0, 0), head=(-16, 0, 0))
        p.both("upper_arm", up, -18, 0).both("fore_arm", fore, 0, 0)
        p["hand_r"] = I3.copy()
        p["prop_r"] = I3.copy()
        return p
    a = sh(-72, -34, 0.0)
    b = sh(-22, -8, 0.02)
    clip("shoo", 0.8, [(0.0, a), (0.2, b), (0.4, a), (0.6, b), (0.8, a)], loop=True)
    # Hände am Feuer wärmen: Arme vor der Brust, Hände reiben sich
    def wm(k):
        p = stand(0.01).set(spine=(4, 0, 0), chest=(3, 0, 0), head=(-6, 0, 0))
        p.set(upper_arm_l=(-58, 20 + 4 * k, 0), fore_arm_l=(-58, 10 * k, 0), upper_arm_r=(-58, -20 + 4 * k, 0), fore_arm_r=(-58, 10 * k, 0), hand_r=(0, 0, 0), prop_r=(0, 0, 0))
        return p
    clip("warm_hands", 1.2, [(0.0, wm(-1)), (0.3, wm(1)), (0.6, wm(-1)), (0.9, wm(1)), (1.2, wm(-1))], loop=True)
    # frühstücken: Brot zum Mund, kauen
    e1 = stand(0.006).set(upper_arm_l=(-40, 14, 0), fore_arm_l=(-70, 0, 0))
    e2 = stand(0.006).set(head=(6, 0, 0), upper_arm_l=(-92, 16, 0), fore_arm_l=(-128, 0, 0))
    e3 = e2.copy().set(head=(-2, 0, 0))
    clip("eat", 1.6, [(0.0, e1), (0.45, e2), (0.7, e3), (0.95, e2), (1.25, e1), (1.6, e1)], loop=True)


# ---------------------------------------------------------------- Fahrzeug
def ride_pose(kind, k=0.0):
    """Sitzpose; der Ursprung der Figur liegt auf dem Sitz (hero.gd setzt sie dorthin)."""
    p = Pose()
    if kind == "quad":
        p["loc"] = Vector((0, 0.02, -0.22 - k))
        p["hips"] = R(6, 0, 0)
        p.set(spine=(10, 0, 0), chest=(6 + k * 60, 0, 0), head=(-14, 0, 0), thigh_l=(-74, 30, 0), thigh_r=(-74, -30, 0), shin_l=(82, 0, 0), shin_r=(82, 0, 0), foot_l=(-10, 0, 0), foot_r=(-10, 0, 0))
        hands = ((-0.22, -0.34, 0.74), (0.22, -0.34, 0.74))
    elif kind == "bike":
        p["loc"] = Vector((0, 0.04, -0.2 - k))
        p["hips"] = R(16, 0, 0)
        p.set(spine=(14, 0, 0), chest=(10 + k * 60, 0, 0), head=(-34, 0, 0), thigh_l=(-64, 22, 0), thigh_r=(-64, -22, 0), shin_l=(96, 0, 0), shin_r=(96, 0, 0), foot_l=(-20, 0, 0), foot_r=(-20, 0, 0))
        hands = ((-0.2, -0.4, 0.72), (0.2, -0.4, 0.72))
    elif kind == "car":
        p["loc"] = Vector((0, 0.04, -0.24 - k))
        p["hips"] = R(-8, 0, 0)
        p.set(spine=(4, 0, 0), chest=(4 + k * 60, 0, 0), head=(0, 0, 0), thigh_l=(-84, 8, 0), thigh_r=(-84, -8, 0), shin_l=(58, 0, 0), shin_r=(58, 0, 0), foot_l=(-24, 0, 0), foot_r=(-24, 0, 0))
        hands = ((-0.13, -0.36, 0.72), (0.13, -0.36, 0.72))
    else:                                                    # hover: breitbeinig stehend, leicht in den Knien
        p = body((0, 0, -0.09 - k), (8, 0, 0), l=(-0.07, -0.03, 0), r=(0.07, 0.05, 0), arms=False)
        p.set(spine=(6, 0, 0), chest=(4 + k * 60, 0, 0), head=(-14, 0, 0))
        hands = ((-0.2, -0.34, 0.8), (0.2, -0.34, 0.8))
    off = p.get("loc", Vector((0, 0, 0))) * 0.5
    p.arm("l", Vector(hands[0]) + off, (-0.5, 0.3, -1))
    p.grip(Vector(hands[1]) + off + Vector((-0.03, -0.06, 0.03)), None, (0.5, 0.3, -1))     # Waffe liegt nach vorn auf dem Lenker
    return p


def c_ride():
    for kind in ("quad", "bike", "car", "hover"):
        a = ride_pose(kind)
        clip("ride_" + kind, 1.2, [(0.0, a), (0.6, ride_pose(kind, 0.008)), (1.2, a)], loop=True)
    # Lenken: additiv, Stärke -1..1 kommt aus Godot (Rumpf dreht und neigt sich, Arme schieben/ziehen)
    st = zero("spine", "chest", "head", "upper_arm_l", "upper_arm_r").set(spine=(0, 5, 6), chest=(0, 4, 10), head=(0, -4, 10), upper_arm_l=(-12, 0, 0), upper_arm_r=(12, 0, 0))
    clip("ride_steer", 0.5, [(0.0, st), (0.5, st)])
    s0 = stand(0.006)
    hop = Pose()
    hop["loc"] = Vector((0, 0, 0.08))
    hop["hips"] = R(10, 0, 0)
    tuck(hop, -70, 80, 22)
    hop.set(spine=(8, 0, 0), head=(-8, 0, 0))
    hop.both("upper_arm", -40, -18, 0).both("fore_arm", -40, 0, 0)
    hop["prop_r"] = I3.copy()
    cr = body((0, 0, -0.1), (12, 0, 0)).set(spine=(8, 0, 0), head=(-10, 0, 0))
    clip("mount", 0.4, [(0.0, cr), (0.18, hop), (0.4, ride_pose("quad"))])
    clip("dismount", 0.4, [(0.0, ride_pose("quad")), (0.16, hop), (0.3, cr), (0.4, s0)])


# ---------------------------------------------------------------- Fähigkeiten (je Held drei) und Feier
def c_skills():
    s0 = stand(0.006)

    def st(drop=0.0, lean=0.0, yaw=0.0, **kw):
        p = body((0, 0, -drop), (lean * 0.5, 0, yaw * 0.3), l=kw.pop("l", (0, 0, 0)), r=kw.pop("r", (0, 0, 0)))
        p.set(spine=(lean * 0.3, 0, yaw * 0.3), chest=(lean * 0.2, 0, yaw * 0.4))
        p.set(**kw)
        return p
    # ---- Jona: 1 pfeift und zeigt nach vorn, 2 Kampfrolle, 3 Leuchtsignal nach oben, dann Zeichen zum Abwurfpunkt
    a = st(0.0, -4, head=(-6, 0, -6), upper_arm_l=(-78, -34, 0), fore_arm_l=(-128, 0, 0))
    b = st(0.02, 10, -10, head=(-8, 0, 8), upper_arm_l=(-96, 4, 0), fore_arm_l=(-4, 0, 0))
    clip("jona_skill_1", 0.8, [(0.0, s0), (0.12, a), (0.34, a.copy().set(head=(-9, 0, -6))), (0.46, b), (0.62, b), (0.8, s0)])
    clip("jona_skill_2", 0.5, roll_keys(0.5, 360.0, 0.1))
    a = st(0.0, -6, head=(-22, 0, 0), upper_arm_l=(-172, 8, 0), fore_arm_l=(-6, 0, 0))
    b = st(0.04, 14, head=(4, 0, 0), upper_arm_l=(-62, 4, 0), fore_arm_l=(-10, 0, 0), l=(0, -0.08, 0))
    clip("jona_special", 0.8, [(0.0, s0), (0.14, a), (0.4, a), (0.54, b), (0.66, b), (0.8, s0)])
    # ---- Mika: 1 Feuerwand – Arm zieht einen weiten Bogen, 2 Hitzeschild – Arme kreuzen und aufreißen, 3 Inferno – Sprung und Schlag in den Boden
    a = st(0.05, 8, 26, head=(0, 0, -20), upper_arm_l=(-80, 60, 0), fore_arm_l=(-16, 0, 0))
    b = st(0.05, 10, -30, head=(0, 0, 22), upper_arm_l=(-84, -44, 0), fore_arm_l=(-10, 0, 0))
    clip("mika_skill_1", 0.7, [(0.0, s0), (0.12, a), (0.42, b), (0.52, b), (0.7, s0)])
    a = st(0.05, 12, head=(-4, 0, 0), upper_arm_l=(-74, -44, 0), fore_arm_l=(-100, 0, 0), upper_arm_r=(-70, 40, 0), fore_arm_r=(-100, 0, 0))
    b = st(0.0, -8, head=(-8, 0, 0), upper_arm_l=(-30, 84, 0), fore_arm_l=(-20, 0, 0), upper_arm_r=(-30, -80, 0), fore_arm_r=(-20, 0, 0))
    clip("mika_skill_2", 0.6, [(0.0, s0), (0.12, a), (0.24, a), (0.34, b), (0.46, b), (0.6, s0)])
    cr = st(0.12, 16, head=(-12, 0, 0))
    up = Pose()
    up["loc"] = Vector((0, 0, 0.26))
    up["hips"] = R(-8, 0, 0)
    tuck(up, -40, 80, 10)
    up.set(spine=(-8, 0, 0), chest=(-8, 0, 0), head=(-6, 0, 0), upper_arm_l=(-170, 10, 0), fore_arm_l=(-20, 0, 0), upper_arm_r=(-160, -10, 0), fore_arm_r=(-30, 0, 0), hand_r=(0, 0, 0), prop_r=(0, 0, 0))
    slam = body((0, -0.04, -0.2), (36, 0, 0), l=(-0.04, -0.06, 0), r=(0.04, 0.08, 0), arms=False).set(spine=(18, 0, 0), chest=(12, 0, 0), head=(-34, 0, 0), upper_arm_l=(-36, 8, 0), fore_arm_l=(-6, 0, 0), upper_arm_r=(-30, -8, 0), fore_arm_r=(-10, 0, 0))
    clip("mika_special", 0.8, [(0.0, s0), (0.1, cr), (0.3, up), (0.44, slam), (0.6, slam), (0.8, s0)])
    # ---- Bruno: 1 rammt den Schild in den Boden, 2 flicken – zwei Hammerschläge, 3 Berta – stampfen und beide Fäuste hoch
    a = st(0.0, -6, 14, head=(0, 0, -10), upper_arm_l=(-120, 30, 0), fore_arm_l=(-60, 0, 0))
    b = body((0, -0.06, -0.19), (24, 0, -8), l=(-0.02, -0.14, 0), r=(0.02, 0.1, 0)).set(spine=(12, 0, 0), chest=(8, 0, -10), head=(-22, 0, 8), upper_arm_l=(-58, 30, 26), fore_arm_l=(-30, 0, 0))
    clip("bruno_skill_1", 0.75, [(0.0, s0), (0.14, a), (0.28, b), (0.36, b.copy().set(chest=(10, 0, -10))), (0.56, b), (0.75, s0)])
    a = st(0.03, 8, head=(-6, 0, 0), upper_arm_r=(-110, -8, 0), fore_arm_r=(-100, 0, 0), upper_arm_l=(-48, 14, 14), fore_arm_l=(-50, 0, 0))
    b = st(0.05, 14, head=(-10, 0, 0), upper_arm_r=(-50, -8, 0), fore_arm_r=(-26, 0, 0), upper_arm_l=(-48, 14, 14), fore_arm_l=(-50, 0, 0))
    clip("bruno_skill_2", 0.7, [(0.0, s0), (0.14, a), (0.24, b), (0.38, a), (0.48, b), (0.7, s0)])
    a = body((0, 0, -0.04), (-6, 0, 0), l=(-0.03, -0.02, 0.12), lp=-10).set(spine=(-6, 0, 0), chest=(-8, 0, 0), head=(-14, 0, 0))
    a.both("upper_arm", -20, -150, 0).both("fore_arm", -70, 0, 0)
    b = body((0, 0, -0.1), (8, 0, 0), l=(-0.05, -0.04, 0)).set(spine=(6, 0, 0), chest=(2, 0, 0), head=(-18, 0, 0))
    b.both("upper_arm", -10, -128, 0).both("fore_arm", -96, 0, 0)
    clip("bruno_special", 0.9, [(0.0, s0), (0.2, a), (0.32, b), (0.44, b.copy().set(head=(-22, 0, 6))), (0.62, b.copy().set(head=(-22, 0, -6))), (0.9, s0)])
    # ---- Ada: 1 Geschütz – hinknien und absetzen, 2 Überladung – Arme hoch, zittern, 3 Pieps – Drohne mit kreisendem Arm rufen
    a = body((0, -0.05, -0.2), (30, 0, 0), l=(0, -0.1, 0), r=(0, 0.08, 0)).set(spine=(16, 0, 0), chest=(10, 0, 6), head=(-22, 0, 0), upper_arm_l=(-64, -10, 0), fore_arm_l=(-14, 0, 0))
    clip("ada_skill_1", 0.7, [(0.0, s0), (0.2, a), (0.34, a.copy().set(fore_arm_l=(-34, 0, 0))), (0.46, a), (0.7, s0)])
    def ov(k):
        p = st(0.0, -8, head=(-12, 0, 5 * k), l=(0, 0, 0.02), r=(0, 0, 0.02))
        p.set(upper_arm_l=(-10, 150 + 8 * k, 0), fore_arm_l=(-36 - 10 * k, 0, 0), upper_arm_r=(-10, -150 + 8 * k, 0), fore_arm_r=(-36 + 10 * k, 0, 0))
        return p
    clip("ada_skill_2", 0.7, [(0.0, s0), (0.14, ov(0)), (0.22, ov(1)), (0.3, ov(-1)), (0.38, ov(1)), (0.46, ov(-1)), (0.54, ov(0)), (0.7, s0)])
    def pc(a1, a2):
        return st(0.0, -5, head=(-20, 0, -6), upper_arm_l=(-165 + a1, 16 + a2, 0), fore_arm_l=(-18, 0, 0))
    clip("ada_special", 0.8, [(0.0, s0), (0.14, pc(0, 0)), (0.26, pc(14, 18)), (0.38, pc(0, -16)), (0.5, pc(-14, 16)), (0.62, pc(0, 0)), (0.8, s0)])
    # ---- Yuki: 1 Kiko – Falknerarm schnellt nach oben-außen, 2 Rauch – in die Hocke, vor die Füße werfen, 3 Schwarm – beide Arme reißen nach oben
    a = st(0.03, 6, 10, head=(4, 0, -16), upper_arm_l=(-30, 30, 0), fore_arm_l=(-100, 0, 0))
    b = st(0.0, -6, -8, head=(-16, 0, -22), upper_arm_l=(-60, 128, 0), fore_arm_l=(-8, 0, 0))
    clip("yuki_skill_1", 0.7, [(0.0, s0), (0.16, a), (0.3, b), (0.5, b), (0.7, s0)])
    a = st(0.0, -4, head=(-6, 0, 0), upper_arm_l=(-150, 14, 0), fore_arm_l=(-60, 0, 0))
    b = body((0, -0.03, -0.17), (26, 0, 0), l=(0, -0.04, 0), r=(0, 0.06, 0)).set(spine=(14, 0, 0), chest=(10, 0, -10), head=(-14, 0, 0), upper_arm_l=(-30, -6, 0), fore_arm_l=(-8, 0, 0))
    clip("yuki_skill_2", 0.6, [(0.0, s0), (0.12, a), (0.26, b), (0.4, b), (0.6, s0)])
    a = st(0.08, 14, head=(-8, 0, 0))
    a.both("upper_arm", -30, -30, 0).both("fore_arm", -60, 0, 0)
    b = body((0, 0, 0.03), (-8, 0, 0), l=(0, 0, 0.03), r=(0, 0, 0.03), lp=20, rp=20).set(spine=(-8, 0, 0), chest=(-10, 0, 0), head=(-18, 0, 0))
    b.both("upper_arm", -40, -140, 0).both("fore_arm", -8, 0, 0)
    clip("yuki_special", 0.8, [(0.0, s0), (0.14, a), (0.3, b), (0.52, b.copy().set(chest=(-12, 0, 0))), (0.8, s0)])
    # ---- Greta: 1 Knallfrösche – lockerer Wurf von unten, 2 Thermoskanne – Schluck mit Kopf im Nacken, 3 Volksfest – Drehung mit ausgebreiteten Armen
    a = st(0.04, 8, 12, head=(0, 0, -8), upper_arm_l=(40, 8, 0), fore_arm_l=(-20, 0, 0))
    b = st(0.0, -4, -10, head=(-8, 0, 6), upper_arm_l=(-112, 4, 0), fore_arm_l=(-8, 0, 0), l=(0, 0, 0.03), r=(0, 0, 0.03))
    clip("greta_skill_1", 0.6, [(0.0, s0), (0.14, a), (0.3, b), (0.42, b), (0.6, s0)])
    a = st(0.0, -8, head=(-26, 0, 0), upper_arm_l=(-74, -30, 0), fore_arm_l=(-132, 0, 0))
    clip("greta_skill_2", 0.9, [(0.0, s0), (0.18, a), (0.4, a.copy().set(head=(-32, 0, 0))), (0.62, a), (0.9, s0)])
    keys = [(0.0, s0)]
    for i, ang in enumerate((60, 150, 240, 330)):
        p = Pose()
        p["loc"] = Vector((0, 0, 0.05 if i in (1, 2) else 0.0))
        p["hips"] = R(0, 0, ang)
        p.set(thigh_l=(-10, 6, 0), thigh_r=(8, -6, 0), shin_l=(24, 0, 0), shin_r=(10, 0, 0), foot_l=(10, 0, 0), foot_r=(6, 0, 0), spine=(-3, 0, 0), chest=(-4, 0, 0), head=(-8, 0, 0))
        p.both("upper_arm", 0, -96, 0).both("fore_arm", -12, 0, 0)
        p["hand_r"] = I3.copy()
        p["prop_r"] = I3.copy()
        keys.append((0.14 + i * 0.16, p))
    end = stand(0.03)
    end.both("upper_arm", -8, -150, 0).both("fore_arm", -30, 0, 0)
    keys += [(0.8, end), (1.0, s0)]
    clip("greta_special", 1.0, keys)


def c_party():
    s0 = stand(0.006)
    # Stufenaufstieg: in die Knie, Sprung mit Faust nach oben, landen, Faust ballen
    cr = body((0, 0, -0.13), (14, 0, 0)).set(spine=(8, 0, 0), head=(-10, 0, 0), upper_arm_l=(20, 14, 0), fore_arm_l=(-60, 0, 0))
    up = Pose()
    up["loc"] = Vector((0, 0, 0.24))
    up["hips"] = R(-6, 0, 0)
    up.set(thigh_l=(-36, 6, 0), shin_l=(70, 0, 0), thigh_r=(10, -6, 0), shin_r=(20, 0, 0), foot_l=(20, 0, 0), foot_r=(30, 0, 0), spine=(-6, 0, 0), chest=(-8, 0, 0), head=(-16, 0, 0),
           upper_arm_l=(-176, 6, 0), fore_arm_l=(-10, 0, 0), upper_arm_r=(10, -24, 0), fore_arm_r=(-30, 0, 0), hand_r=(0, 0, 0), prop_r=(0, 0, 0))
    ld = body((0, 0, -0.1), (10, 0, 0)).set(spine=(6, 0, 0), head=(-6, 0, 0), upper_arm_l=(-60, 20, 0), fore_arm_l=(-120, 0, 0))
    fl = stand(0.0).set(chest=(-4, 0, 0), head=(-8, 0, 0), upper_arm_l=(-70, 24, 0), fore_arm_l=(-124, 0, 0))
    clip("level_up", 1.4, [(0.0, s0), (0.16, cr), (0.4, up), (0.52, up), (0.72, ld), (0.9, fl), (1.1, fl.copy().set(fore_arm_l=(-112, 0, 0))), (1.4, s0)])
    # Sieg (Schleife): Arme abwechselnd hochreißen, federn
    def vc(k):
        p = body((0, 0, -0.03 + 0.03 * abs(k)), (0, 3 * k, 0)).set(spine=(-3, -2 * k, 0), chest=(-5, -3 * k, 6 * k), head=(-12, 0, -4 * k))
        p.set(upper_arm_l=(-10, 150 if k > 0 else 110, 0), fore_arm_l=(-20 if k > 0 else -80, 0, 0), upper_arm_r=(-10, -150 if k < 0 else -110, 0), fore_arm_r=(-20 if k < 0 else -80, 0, 0))
        p["hand_r"] = I3.copy()
        p["prop_r"] = I3.copy()
        return p
    a = vc(1)
    clip("victory", 1.2, [(0.0, a), (0.3, vc(0.0001)), (0.6, vc(-1)), (0.9, vc(-0.0001)), (1.2, a)], loop=True)
    # Niederlage: auf ein Knie sinken, Kopf und Schultern hängen (Endpose wird gehalten)
    k1 = body((0, 0, -0.08), (10, 0, 0)).set(spine=(10, 0, 0), chest=(8, 0, 0), head=(16, 0, 0))
    k2 = body((0, 0.02, -0.2), (16, 0, 0), l=(0, -0.08, 0), r=(0, 0.12, 0.02), rp=40).set(spine=(16, 0, 0), chest=(12, 0, 0), head=(26, 0, 0), shoulder_l=(0, 8, 0), shoulder_r=(0, -8, 0))
    k2.set(upper_arm_l=(-10, 4, 0), fore_arm_l=(-6, 0, 0), upper_arm_r=(-10, -4, 0), fore_arm_r=(-6, 0, 0))
    k3 = k2.copy().set(head=(30, 0, 5), chest=(14, 0, 0))
    clip("defeat", 1.6, [(0.0, s0), (0.4, k1), (0.9, k2), (1.25, k3), (1.6, k2)])


# ---------------------------------------------------------------- Aufbau in Blender
def bake(arm, names):
    ad = arm.animation_data_create()
    sc = bpy.context.scene
    sc.render.fps = FPS
    for name in names:
        c = CLIPS[name]
        act = bpy.data.actions.new(name)
        act.use_fake_user = True
        ad.action = act
        used = set()
        for t, p in c["keys"]:
            used |= set(p.keys())
        bones = [b for b in rig.ORDER if b in used]
        last = {}
        for t, p in c["keys"]:
            f = round(t * FPS, 3)
            for b in bones:
                pb = arm.pose.bones[b]
                q = rig.basis_quat(p.rot(b))
                if b in last and last[b].dot(q) < 0.0:
                    q.negate()
                last[b] = q.copy()
                pb.rotation_quaternion = q
                pb.keyframe_insert("rotation_quaternion", frame=f)
            if "loc" in used:
                pb = arm.pose.bones["hips"]
                pb.location = rig.basis_loc(p.get("loc", Vector((0, 0, 0))))
                pb.keyframe_insert("location", frame=f)
        for t, ev in c["events"]:
            mk = act.pose_markers.new(ev)
            mk.frame = int(round(t * FPS))
        if c["dense"]:
            for fc in _fcurves(act):
                for kp in fc.keyframe_points:
                    kp.interpolation = "LINEAR"
        act.frame_range = (0, c["len"] * FPS)
        act.use_frame_range = True
        act.use_cyclic = c["loop"]
        ad.action = None
        for pb in arm.pose.bones:
            pb.rotation_quaternion = Quaternion()
            pb.location = (0, 0, 0)
        tr = ad.nla_tracks.new()
        tr.name = name
        st = tr.strips.new(name, 0, act)
        st.name = name
        try:
            st.action_slot = act.slots[0]
        except Exception:
            pass
        tr.mute = False


def _fcurves(act):
    out = []
    for layer in act.layers:
        for strip in layer.strips:
            for cb in strip.channelbags:
                out.extend(cb.fcurves)
    return out


def write_data():
    """Schreibt die Clip-Tabelle für Godot."""
    path = os.path.join(kit.ROOT, "src", "anim_human_data.gd")
    lines = ["extends RefCounted",
             "## Erzeugt von blender/anim_human.py – nicht von Hand ändern.",
             "## Je Clip: Länge (s), Schleife, Schrittlänge je Zyklus (m, Figur im Spielmaßstab), Ereignisse [Zeit, Name].",
             "",
             "const FPS := %d" % FPS,
             "const CHAR_SCALE := %s" % CHAR_SCALE,
             "const LOCO_T := %s" % LOCO_T,
             "const STRIDE_WALK := %s" % STRIDE_WALK,
             "const STRIDE_RUN := %s" % STRIDE_RUN,
             "const CLIPS := {"]
    for name in CLIPS:
        c = CLIPS[name]
        ev = ", ".join('[%.4f, "%s"]' % (t, e) for t, e in c["events"])
        lines.append('\t"%s": {"len": %.4f, "loop": %s, "stride": %.3f, "events": [%s]},' % (name, c["len"], "true" if c["loop"] else "false", c["stride"], ev))
    lines.append("}")
    with open(path, "w") as f:
        f.write("\n".join(lines) + "\n")


HEROES = ["jona", "mika", "bruno", "ada", "yuki", "greta"]
ALL = (["idle", "idle_look", "idle_stretch", "idle_weapon_check",
        "walk_f", "walk_b", "walk_l", "walk_r", "run_f", "run_b", "run_l", "run_r",
        "walk_fr", "walk_fl", "walk_br", "walk_bl", "run_fr", "run_fl", "run_br", "run_bl",
        "aim_rifle", "aim_heavy", "aim_bow", "aim_thrower", "aim_melee", "aim_spray",
        "hold_rifle", "hold_heavy", "hold_bow", "hold_thrower", "hold_melee", "hold_spray",
        "fire_rifle", "fire_heavy", "fire_bow", "fire_throw", "fire_swing", "fire_spray_loop",
        "aim_pistol", "aim_spear", "aim_hammer", "aim_toss", "aim_staff",
        "hold_pistol", "hold_spear", "hold_hammer", "hold_toss", "hold_staff",
        "fire_thrust", "fire_slam", "fire_toss", "fire_cast",
        "reload_rifle", "reload_heavy", "reload_bow", "reload_thrower",
        "dodge_roll", "dodge_land", "hit_light", "hit_heavy", "down", "revive",
        "chop", "mine", "pick_up", "carry_walk", "hammer", "pay", "wave", "cheer", "sit", "sleep",
        "wipe_brow", "shoo", "warm_hands", "eat",
        "ride_quad", "ride_bike", "ride_car", "ride_hover", "ride_steer", "mount", "dismount"]
       + ["%s_%s" % (h, k) for h in HEROES for k in ("skill_1", "skill_2", "special")]
       + ["level_up", "victory", "defeat"])


def define_all():
    c_idle()
    # vier Hauptrichtungen laut Auftrag, dazu die vier Diagonalen (Zusatz): gemischte Lauf-Clips verschiedener
    # Richtung lassen die Füße rutschen, deshalb gibt es für schräges Laufen eigene Clips
    for nm, d in (("f", (0, -1)), ("b", (0, 1)), ("l", (-1, 0)), ("r", (1, 0)), ("fr", (1, -1)), ("fl", (-1, -1)), ("br", (1, 1)), ("bl", (-1, 1))):
        loco("walk_" + nm, d, STRIDE_WALK, False)
        loco("run_" + nm, d, STRIDE_RUN, True)
    c_aims()
    c_fire()
    c_fire_v4()
    c_reload()
    c_dodge_hit()
    c_work()
    c_welt()
    c_ride()
    c_skills()
    c_party()
    missing = [n for n in ALL if n not in CLIPS]
    assert not missing, missing


if __name__ == "__main__":
    import heroes
    define_all()
    names = [n for n in sys.argv[1:] if n in CLIPS] or list(CLIPS.keys())
    arm, body = heroes.build("settler", with_extra=False)
    bake(arm, names)
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(kit.OUT_BLEND, "anim_human.blend"))
    for o in bpy.context.scene.objects:
        o.select_set(o == arm)
    kit.save_rigged("anim_human", animations=True, blend=False, selection=True)
    write_data()
    print("ok anim_human:", len(names), "Clips")
