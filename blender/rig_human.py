"""Gemeinsames Skelett `rw_human` für Helden, Bewohner und menschenähnliche Gegner.

Alle Knochen zeigen in der Ruhelage senkrecht nach oben und haben dieselbe Ausrichtung
(Knochen-X = Welt-X, Knochen-Y = Welt-Z, Knochen-Z = Welt -Y = Vorderseite). Dadurch ist die
Ruhe-Ausrichtung jedes Knochens in Godot die Einheitsdrehung (+Z vorn, +Y oben) – Posen lassen
sich als Drehungen um Weltachsen beschreiben, und Godot kann Kopf, Brust und Waffe einfach zum
Ziel drehen.

Seiten: wie in heroes.py ist "_r" die Seite +X (dort hängt die Waffe), "_l" die Seite -X.

Knochen: root, hips, spine, chest, neck, head, je Seite shoulder, upper_arm, fore_arm, hand,
je Seite thigh, shin, foot, dazu prop_r (Waffe) und prop_back (Rucksack). Zubehör, das
nachschwingt, bekommt zusätzliche Knochen `spring_*` (siehe heroes.py).

Aufruf allein (`python3 blender/rig_human.py`) speichert blender/blend/rw_human.blend.
"""
import sys, os, math
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy
from mathutils import Vector, Matrix, Euler, Quaternion

LIFT = 0.04          # die Figur steht jetzt mit der Sohle genau auf z = 0
HIP_Z = 0.52 + LIFT

# Längen der Glieder (Modellmaß; im Spiel mal D.CHAR_SCALE = 1,5)
THIGH = 0.12
SHIN = 0.18
ANKLE = 0.18         # Knöchel über der Sohle
UPPER = 0.22
FORE = 0.24
GRIP = Vector((-0.03, -0.03, -0.09))   # Griffpunkt (prop_r) relativ zum Handgelenk


def joints(big=1.0):
    """Lage aller Gelenke im Modellraum (Blender: Z oben, -Y vorn) und der Elternknochen."""
    j = {}
    j["root"] = (None, Vector((0, 0, 0)))
    j["hips"] = ("root", Vector((0, 0, HIP_Z)))
    j["spine"] = ("hips", Vector((0, 0, HIP_Z + 0.12)))
    j["chest"] = ("spine", Vector((0, 0, HIP_Z + 0.24)))
    j["neck"] = ("chest", Vector((0, 0, HIP_Z + 0.54)))
    j["head"] = ("neck", Vector((0, 0, HIP_Z + 0.60)))
    j["prop_back"] = ("chest", Vector((0, 0.12, HIP_Z + 0.30)))
    for sx, t in ((-1, "l"), (1, "r")):
        ax = (0.34 * big) * sx + 0.03
        sh = Vector((ax, 0.03, HIP_Z + 0.50))
        j["shoulder_" + t] = ("chest", Vector((0.2 * big * sx, 0.0, HIP_Z + 0.46)))
        j["upper_arm_" + t] = ("shoulder_" + t, sh)
        j["fore_arm_" + t] = ("upper_arm_" + t, sh + Vector((0, 0, -UPPER)))
        j["hand_" + t] = ("fore_arm_" + t, sh + Vector((0, 0, -UPPER - FORE)))
        hip = Vector((0.15 * big * sx, 0, HIP_Z - 0.08))
        j["thigh_" + t] = ("hips", hip)
        j["shin_" + t] = ("thigh_" + t, hip + Vector((0, 0, -THIGH)))
        j["foot_" + t] = ("shin_" + t, hip + Vector((0, 0, -THIGH - SHIN)))
    j["prop_r"] = ("hand_r", j["hand_r"][1] + GRIP)
    return j


ORDER = ["root", "hips", "spine", "chest", "neck", "head",
         "shoulder_l", "upper_arm_l", "fore_arm_l", "hand_l", "shoulder_r", "upper_arm_r", "fore_arm_r", "hand_r", "prop_r", "prop_back",
         "thigh_l", "shin_l", "foot_l", "thigh_r", "shin_r", "foot_r"]


def build_rig(big=1.0, extra=None):
    """Erzeugt das Armature-Objekt `rw_human`. extra = {name: (elternknochen, (x, y, z))} für spring_*-Knochen."""
    js = joints(big)
    names = list(ORDER)
    if extra:
        for n, (par, pos) in extra.items():
            js[n] = (par, Vector(pos))
            names.append(n)
    arm = bpy.data.armatures.new("rw_human")
    ob = bpy.data.objects.new("rw_human", arm)
    bpy.context.scene.collection.objects.link(ob)
    bpy.context.view_layer.objects.active = ob
    bpy.ops.object.mode_set(mode="EDIT")
    for n in names:
        par, pos = js[n]
        b = arm.edit_bones.new(n)
        b.head = pos
        b.tail = pos + Vector((0, 0, 0.08))
        b.roll = 0.0
        if par is not None:
            b.parent = arm.edit_bones[par]
            b.use_connect = False
    bpy.ops.object.mode_set(mode="OBJECT")
    for n in names:                      # Prüfung: alle Knochen gleich ausgerichtet
        m = arm.bones[n].matrix_local.to_3x3()
        assert (m.col[0] - Vector((1, 0, 0))).length < 1e-4 and (m.col[2] - Vector((0, -1, 0))).length < 1e-4, (n, m)
    for pb in ob.pose.bones:
        pb.rotation_mode = "QUATERNION"
    arm.display_type = "STICK"
    ob.show_in_front = True
    ob["rw_big"] = big
    return ob


# Ruhe-Ausrichtung jedes Knochens im Armature-Raum (für alle gleich)
B = Matrix(((1, 0, 0), (0, 0, -1), (0, 1, 0)))
B_INV = B.inverted()


def basis_quat(rw):
    """Drehung um Weltachsen (3x3, relativ zum Elternknochen) -> Posen-Quaternion des Knochens."""
    return (B_INV @ rw @ B).to_quaternion()


def basis_loc(v):
    """Verschiebung im Modellraum -> Posen-Verschiebung des Knochens."""
    return B_INV @ Vector(v)


def R(rx=0.0, ry=0.0, rz=0.0):
    """Drehung in Grad um die Weltachsen X (+ = nach vorn beugen / Arm nach hinten), Y (+ = zur _r-Seite kippen),
    Z (+ = zur _r-Seite drehen). Reihenfolge: erst X, dann Y, dann Z."""
    return Euler((math.radians(rx), math.radians(ry), math.radians(rz)), "XYZ").to_matrix()


def aim_frame(direction, back_hint=(0, 1, 0)):
    """Drehung, die die Ruhelage eines hängenden Glieds (zeigt nach -Z) in `direction` dreht;
    back_hint legt fest, wohin die Rückseite (+Y) zeigen soll."""
    ez = -Vector(direction).normalized()
    h = Vector(back_hint)
    ey = h - ez * h.dot(ez)
    if ey.length < 1e-5:
        ey = Vector((0, 0, 1)) - ez * ez.z
    ey.normalize()
    ex = ey.cross(ez)
    m = Matrix((ex, ey, ez))
    m.transpose()
    return m


def two_bone(origin, target, l1, l2, pole):
    """Zwei-Glieder-Lösung: Gelenk in `origin`, Ende soll nach `target`; das Mittelgelenk weicht in Richtung `pole` aus.
    Gibt (Lage Mittelgelenk, tatsächliche Endlage) zurück."""
    o = Vector(origin)
    t = Vector(target)
    d = t - o
    dist = d.length
    lim = (l1 + l2) * 0.999
    if dist > lim:
        d = d * (lim / dist)
        dist = lim
        t = o + d
    lo = abs(l1 - l2) * 1.001 + 1e-4
    if dist < lo:
        d = (d.normalized() if dist > 1e-6 else Vector((0, 0, -1))) * lo
        dist = lo
        t = o + d
    n = d / dist
    a = (l1 * l1 - l2 * l2 + dist * dist) / (2.0 * dist)
    h = math.sqrt(max(l1 * l1 - a * a, 0.0))
    p = Vector(pole)
    pp = p - n * p.dot(n)
    if pp.length < 1e-5:
        pp = Vector((0, -1, 0)) - n * (-n.y)
    pp.normalize()
    return o + n * a + pp * h, t


if __name__ == "__main__":
    bpy.ops.wm.read_factory_settings(use_empty=True)
    build_rig(1.0)
    out = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "blender", "blend")
    os.makedirs(out, exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(out, "rw_human.blend"))
    print("ok rw_human", len(ORDER), "Knochen")
