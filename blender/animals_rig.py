"""Paket H (V6): echte Blender-Animationen für Hund, Katze und Singvogel der Basis (statt im Code gedrehter Teile).

Dieselben Formen wie in animals.py, aber mit Skelett: jedes Teil ist starr an einen Knochen gebunden (wie bei den
Helden), alle Knochen zeigen in der Ruhelage nach oben (Knochen-X = Welt-X), Posen als Drehungen um Weltachsen
(rig_human.R / basis_quat). Ergebnis: models/a_dog_rig.glb, a_cat_rig.glb, a_bird_rig.glb mit Skelett, einem Mesh `mesh`
und den Clips (Actions, je eine NLA-Spur). Clips mit Endung _loop laufen in Godot als Schleife (die Endung fällt beim
Import weg). src/animal_anim.gd wählt den Clip nach dem Zustand aus src/wildlife.gd.
  Hund:  idle_loop, walk_loop, run_loop, sit_loop, bark_loop
  Katze: idle_loop, walk_loop, run_loop, sit_loop, sleep_loop
  Vogel: idle_loop, peck_loop, fly_loop
Aufruf: python3 blender/animals_rig.py [a_dog a_cat a_bird]"""
import sys, os, math
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy
from mathutils import Vector, Matrix, Quaternion
import kit
from kit import Part, bind, skin, reset, save_rigged
import rig_human as rig
from rig_human import R
import animals

FPS = 30
CAP = {}


def _capture(name, root_parts, icon_too=False):
    CAP[name] = root_parts


animals.done = _capture                      # Formen aus animals.py übernehmen, ohne dort zu speichern


def build_rig(name, joints, parents):
    arm = bpy.data.armatures.new(name)
    ob = bpy.data.objects.new(name, arm)
    bpy.context.scene.collection.objects.link(ob)
    bpy.context.view_layer.objects.active = ob
    bpy.ops.object.mode_set(mode="EDIT")
    for n, pos in joints.items():
        b = arm.edit_bones.new(n)
        b.head = Vector(pos)
        b.tail = Vector(pos) + Vector((0, 0, 0.06))
        b.roll = 0.0
    for n, par in parents.items():
        if par:
            arm.edit_bones[n].parent = arm.edit_bones[par]
            arm.edit_bones[n].use_connect = False
    bpy.ops.object.mode_set(mode="OBJECT")
    for pb in ob.pose.bones:
        pb.rotation_mode = "QUATERNION"
    return ob


def make(model, fn, joints, parents, bone_of, clips):
    """fn baut die Teile (animals.py), joints/parents = Knochen, bone_of = Teil -> Knochen, clips = {name: (länge, keys, loop)}."""
    reset()
    fn()
    parts = []
    for nm, part, loc in CAP[model]:
        ob = part.build(nm, None, loc)
        parts.append(bind(ob, bone_of.get(nm, "body")))
    arm = build_rig(model + "_rig", joints, parents)
    skin(parts, arm, "mesh")
    ad = arm.animation_data_create()
    for cname, (length, keys, loop) in clips.items():
        act = bpy.data.actions.new(cname)
        act.use_fake_user = True
        ad.action = act
        last = {}
        for t, pose in keys:
            f = round(t * FPS, 3)
            for bn in joints:
                pb = arm.pose.bones[bn]
                m = pose.get(bn, R())
                q = rig.basis_quat(m)
                if bn in last and last[bn].dot(q) < 0.0:
                    q.negate()
                last[bn] = q.copy()
                pb.rotation_quaternion = q
                pb.keyframe_insert("rotation_quaternion", frame=f)
            pb = arm.pose.bones["root"]
            pb.location = rig.basis_loc(pose.get("loc", (0, 0, 0)))
            pb.keyframe_insert("location", frame=f)
        act.frame_range = (0, length * FPS)
        act.use_frame_range = True
        act.use_cyclic = loop
        ad.action = None
        for pb in arm.pose.bones:
            pb.rotation_quaternion = Quaternion()
            pb.location = (0, 0, 0)
        tr = ad.nla_tracks.new()
        tr.name = cname
        st = tr.strips.new(cname, 0, act)
        try:
            st.action_slot = act.slots[0]
        except Exception:
            pass
    for o in bpy.context.scene.objects:
        o.select_set(o == arm or o.parent == arm)
    save_rigged(model + "_rig", animations=True, blend=True, selection=True)
    print("ok", model + "_rig", len(clips), "Clips")


def cyc(n, length, fn):
    """Schleife aus n+1 Schlüsseln; fn(phase 0..1) -> Pose (dict Knochen -> Matrix, 'loc' -> Vektor)."""
    return [(length * i / n, fn(i / n)) for i in range(n + 1)]


S = math.sin
TAU = 2 * math.pi


# ---------------------------------------------------------------- Hund
def dog():
    j = {"root": (0, 0, 0), "body": (0, 0.02, 0.42), "head": (0, -0.3, 0.58), "tail": (0, 0.3, 0.48),
         "leg_fl": (-0.08, -0.18, 0.34), "leg_fr": (0.08, -0.18, 0.34), "leg_bl": (-0.08, 0.2, 0.34), "leg_br": (0.08, 0.2, 0.34)}
    par = {"root": None, "body": "root", "head": "body", "tail": "body", "leg_fl": "body", "leg_fr": "body", "leg_bl": "body", "leg_br": "body"}
    bone_of = {"body": "body", "head": "head", "tail": "tail", "leg_fl": "leg_fl", "leg_fr": "leg_fr", "leg_bl": "leg_bl", "leg_br": "leg_br"}

    def gait(ph, amp, bob, pitch, wag, head):
        a = amp * S(TAU * ph)
        return {"loc": (0, 0, bob * abs(S(TAU * ph))), "body": R(pitch * S(TAU * ph * 2), 0, 0),
                "leg_fl": R(a, 0, 0), "leg_br": R(a, 0, 0), "leg_fr": R(-a, 0, 0), "leg_bl": R(-a, 0, 0),
                "tail": R(-20, 0, wag * S(TAU * ph * 2)), "head": R(head * S(TAU * ph * 2), 0, 0)}

    def sit(ph):
        return {"loc": (0, 0, -0.1), "body": R(-28, 0, 0), "leg_fl": R(28, 0, 0), "leg_fr": R(28, 0, 0),
                "leg_bl": R(-62, 0, 0), "leg_br": R(-62, 0, 0), "head": R(18 + 3 * S(TAU * ph), 0, 6 * S(TAU * ph)), "tail": R(-50, 0, 25 * S(TAU * ph * 3))}

    def bark(ph):
        k = max(0.0, S(TAU * ph))
        return {"loc": (0, 0, 0.03 * k), "body": R(-6 * k, 0, 0), "head": R(-24 * k + 6, 0, 0), "tail": R(-30, 0, 30 * S(TAU * ph * 2)),
                "leg_fl": R(-10 * k, 0, 0), "leg_fr": R(-10 * k, 0, 0)}
    clips = {
        "idle_loop": (1.2, cyc(8, 1.2, lambda ph: {"loc": (0, 0, 0.004 * S(TAU * ph)), "tail": R(-25, 0, 32 * S(TAU * ph * 2)), "head": R(4 * S(TAU * ph), 0, 10 * S(TAU * ph))}), True),
        "walk_loop": (0.6, cyc(8, 0.6, lambda ph: gait(ph, 28, 0.02, 2, 25, 4)), True),
        "run_loop": (0.4, cyc(8, 0.4, lambda ph: gait(ph, 48, 0.07, 6, 35, 8)), True),
        "sit_loop": (1.5, cyc(6, 1.5, sit), True),
        "bark_loop": (0.4, cyc(4, 0.4, bark), True),
    }
    make("a_dog", animals.dog, j, par, bone_of, clips)


# ---------------------------------------------------------------- Katze
def cat():
    j = {"root": (0, 0, 0), "body": (0, 0.04, 0.22), "head": (0, -0.2, 0.3), "tail": (0, 0.24, 0.24)}
    par = {"root": None, "body": "root", "head": "body", "tail": "body"}
    bone_of = {"body": "body", "head": "head", "tail": "tail"}

    def walk(ph, bob, sway):
        return {"loc": (0, 0, bob * abs(S(TAU * ph))), "body": R(2 * S(TAU * ph * 2), sway * S(TAU * ph), 0),
                "tail": R(-10, 0, 25 * S(TAU * ph)), "head": R(-3 * S(TAU * ph * 2), 0, 4 * S(TAU * ph))}

    def sit(ph):
        return {"loc": (0, 0.03, -0.03), "body": R(-30, 0, 0), "head": R(26, 0, 14 * S(TAU * ph)), "tail": R(30, 0, 40 + 10 * S(TAU * ph))}

    def sleep(ph):
        b = 0.012 * S(TAU * ph)
        return {"loc": (0, 0, -0.08 + b), "body": R(4, 0, 0), "head": R(26, 0, -30), "tail": R(40, 0, 70)}
    clips = {
        "idle_loop": (2.0, cyc(8, 2.0, lambda ph: {"tail": R(-10, 0, 30 * S(TAU * ph)), "head": R(0, 0, 18 * S(TAU * ph))}), True),
        "walk_loop": (0.8, cyc(8, 0.8, lambda ph: walk(ph, 0.012, 3)), True),
        "run_loop": (0.45, cyc(8, 0.45, lambda ph: walk(ph, 0.05, 6)), True),
        "sit_loop": (2.0, cyc(6, 2.0, sit), True),
        "sleep_loop": (2.4, cyc(6, 2.4, sleep), True),
    }
    make("a_cat", animals.cat, j, par, bone_of, clips)


# ---------------------------------------------------------------- Singvogel
def bird():
    j = {"root": (0, 0, 0), "body": (0, 0, 0.1), "wing_l": (-0.06, 0.0, 0.15), "wing_r": (0.06, 0.0, 0.15)}
    par = {"root": None, "body": "root", "wing_l": "body", "wing_r": "body"}
    bone_of = {"body": "body", "wing_l": "wing_l", "wing_r": "wing_r"}

    def fly(ph):
        a = 60 * S(TAU * ph)
        return {"loc": (0, 0, 0.02 * S(TAU * ph)), "body": R(-8, 0, 0), "wing_l": R(0, -a, 0), "wing_r": R(0, a, 0)}

    def peck(ph):
        k = max(0.0, S(TAU * ph))
        return {"body": R(40 * k, 0, 0), "wing_l": R(0, 8, 0), "wing_r": R(0, -8, 0)}

    def idle(ph):
        return {"body": R(0, 0, 25 * S(TAU * ph)), "loc": (0, 0, 0.004 * abs(S(TAU * ph * 2)))}
    clips = {"idle_loop": (2.0, cyc(8, 2.0, idle), True), "peck_loop": (0.5, cyc(6, 0.5, peck), True), "fly_loop": (0.22, cyc(6, 0.22, fly), True)}
    make("a_bird", lambda: animals.bird("a_bird", False), j, par, bone_of, clips)


ALL = {"a_dog": dog, "a_cat": cat, "a_bird": bird}

if __name__ == "__main__":
    for n in (sys.argv[1:] or list(ALL)):
        ALL[n]()
