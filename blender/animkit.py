"""Rustwall – Baukasten für animierte Gegner (baut auf kit.py / rw_util.py auf).

Ein Gegner besteht aus mehreren STARREN TEILEN (Rumpf, Kopf, Arme, Beine, Waffe …). Jedes Teil ist ein eigenes
Blender-Objekt mit Drehpunkt (pivot) in einer Eltern-Kind-Ordnung. Bewegt wird mit echten Blender-Keyframes
(Lage, Drehung, Größe) auf diesen Objekten. vat_bake.py brennt das Ergebnis in eine Animations-Textur.

Kurzform:

    from animkit import *
    rig = Rig("untote_matrose", role="mass")
    p = Part(); p.ball(0.4, (0, 0, 0.9), "5E8F6A")              # Geometrie in MODELL-Koordinaten (wie überall)
    rig.add("body", p, pivot=(0, 0, 0.5))                      # pivot = Drehpunkt in Modell-Koordinaten
    p = Part(); p.ball(0.3, (0, 0, 1.5), "7FB58A")
    rig.add("head", p, parent="body", pivot=(0, 0, 1.25))
    with rig.clip("idle", 30, loop=True) as c:                  # 30 Bilder = 1 Sekunde (30 Bilder/s)
        c.key(0, body=dict(scale=1.0))
        c.key(15, body=dict(scale=(1.03, 1.03, 0.97)), head=dict(rot=(4, 0, 0)))
    with rig.clip("walk", 24, loop=True, stride=0.9) as c: ...
    rig.finish()                                                # speichert .blend, brennt Textur, exportiert .glb, Symbol

Werte in key(): loc = VERSATZ gegenüber der Ruhelage (Meter), rot = Euler-Winkel XYZ in Grad (0 = Ruhelage),
scale = Zahl oder (x, y, z). Nicht genannte Kanäle bleiben, wie sie sind (weich dazwischengerechnet).
Bei loop=True wird die Pose von Bild 0 am Ende automatisch wiederholt (nahtlos).
"""
import sys, os, json, math
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from kit import *
from rw_util import *

FPS = 30            # Bilder je Sekunde beim Animieren
BAKE_STEP = 3       # jedes dritte Bild wird gespeichert = 10 Bilder je Sekunde
GAP = 12            # Abstand zwischen zwei Clips auf der Zeitleiste

# Grenzen je Rolle (Eckpunkte des fertigen Meshes, so wie die Grafikkarte sie zählt)
VERT_LIMIT = {"mass": 900, "fast": 900, "ranged": 1600, "air": 1600, "special": 1600, "tank": 2800, "boss": 99999}
CHANNELS = (("loc", "location"), ("rot", "rotation_euler"), ("scale", "scale"))

# Kennungen für Teile (landen in der ersten UV des fertigen Meshes; der Shader wertet sie aus)
CODE_NONE, CODE_LOOK, CODE_HIDE, CODE_GHOST = 0, 1, 2, 3


def _vec3(v, default):
    if v is None:
        return None
    if isinstance(v, (int, float)):
        return (float(v), float(v), float(v))
    return tuple(float(x) if x is not None else default for x in v)


class Clip:
    """Sammelt die Posen eines Clips. Zeit in Bildern ab Clip-Anfang (0 … length)."""

    def __init__(self, rig, name, length, loop, stride, hit):
        self.rig, self.name, self.length, self.loop, self.stride, self.hit = rig, name, int(length), loop, stride, hit
        self.keys = {}          # (teil, kanal) -> {bild: (x, y, z)}
        self.interp = {}        # (teil, kanal, bild) -> "LINEAR" | "CONSTANT"

    def __enter__(self):
        return self

    def __exit__(self, *a):
        return False

    def key(self, frame, _i=None, **parts):
        """Pose setzen: c.key(12, body=dict(loc=(0, 0, 0.1), rot=(10, 0, 0)), arm_l=dict(rot=(-40, 0, 0)))."""
        for pname, vals in parts.items():
            if pname not in self.rig.parts and pname != "root":
                raise KeyError("Teil '%s' gibt es nicht (Clip %s)" % (pname, self.name))
            for ch, _path in CHANNELS:
                if ch in vals:
                    v = _vec3(vals[ch], 1.0 if ch == "scale" else 0.0)
                    self.keys.setdefault((pname, ch), {})[int(frame)] = v
                    if _i:
                        self.interp[(pname, ch, int(frame))] = _i
        return self

    def wave(self, part, rot=None, loc=None, scale=None, n=1, phase=0.0, base_rot=(0, 0, 0), base_loc=(0, 0, 0), base_scale=(1, 1, 1), steps=4):
        """Gleichmäßiges Schwingen über den ganzen Clip: n Schwingungen, phase 0..1 verschiebt den Anfang.
        rot/loc/scale = Ausschlag je Achse. Für Laufzyklen: linkes Bein phase=0, rechtes phase=0.5."""
        total = n * steps
        for k in range(total + 1):
            f = round(self.length * k / total)
            s = math.sin(2 * math.pi * (k / steps + phase))
            vals = {}
            if rot is not None:
                vals["rot"] = tuple(base_rot[i] + rot[i] * s for i in range(3))
            if loc is not None:
                vals["loc"] = tuple(base_loc[i] + loc[i] * s for i in range(3))
            if scale is not None:
                vals["scale"] = tuple(base_scale[i] + scale[i] * s for i in range(3))
            self.key(f, **{part: vals})
        return self

    def hold(self, frame, *parts):
        """Ruhepose (alles 0) für die genannten Teile – oder für alle, wenn keine genannt sind."""
        for p in (parts or list(self.rig.parts.keys())):
            self.key(frame, **{p: dict(loc=(0, 0, 0), rot=(0, 0, 0), scale=1.0)})
        return self


class Rig:
    """Ein Gegner aus starren Teilen mit Clips."""

    def __init__(self, key, role="mass", yaw=0.0, size=1.0):
        """yaw: dreht die ganze Figur um die Hochachse (Grad). 90 = sie läuft seitwärts (Krabbe).
        size: vergrößert die fertige Figur (bequem, wenn sie beim Ansehen der Bildtafel zu klein wirkt)."""
        reset()
        sc = bpy.context.scene
        sc.render.fps = FPS
        self.key_name, self.role = key, role
        self.base = empty("base")
        self.base.rotation_euler = (0.0, 0.0, math.radians(yaw))
        self.base.scale = (size, size, size)
        self.root = empty("root", self.base)
        self.parts = {}                 # name -> Objekt
        self.pivots = {"root": Vector((0, 0, 0))}
        self.clips = []
        self._cursor = 1

    # ---------------------------------------------------------------- Teile
    def add(self, name, part, parent=None, pivot=(0, 0, 0), glow=False, look=False, hide=False, ghost=False, sharp=62.0):
        """Fügt ein Teil hinzu. part = kit.Part mit Geometrie in Modell-Koordinaten, pivot = Drehpunkt (Modell-Koordinaten).
        glow: leuchtet (Augen, Glut). look: Pupille, folgt im Spiel dem Helden. hide: Zubehör, das das Spiel ausblenden
        kann (Helm). ghost: durchscheinend (Geister, Quallen). sharp: ab diesem Winkel bleibt eine Kante hart."""
        pv = Vector(pivot)
        bmesh.ops.translate(part.bm, vec=-pv, verts=part.bm.verts)
        par_name = parent or "root"
        par = self.root if par_name == "root" else self.parts[par_name]
        ob = part.build(name, par, loc=tuple(pv - self.pivots[par_name]), sharp_angle=sharp)
        ob.rotation_mode = "XYZ"
        ob["rw_glow"] = 1.0 if glow else 0.0
        ob["rw_code"] = CODE_LOOK if look else (CODE_HIDE if hide else (CODE_GHOST if ghost else CODE_NONE))
        ob["rw_rest"] = list(ob.location)
        self.parts[name] = ob
        self.pivots[name] = pv
        return ob

    def node(self, name, parent=None, pivot=(0, 0, 0)):
        """Leeres Gelenk ohne Geometrie (z. B. Hüfte, an der Rumpf und Beine hängen)."""
        pv = Vector(pivot)
        par_name = parent or "root"
        par = self.root if par_name == "root" else self.parts[par_name]
        ob = empty(name, par, tuple(pv - self.pivots[par_name]))
        ob.rotation_mode = "XYZ"
        ob["rw_rest"] = list(ob.location)
        self.parts[name] = ob
        self.pivots[name] = pv
        return ob

    # ---------------------------------------------------------------- Clips
    def clip(self, name, length, loop=False, stride=0.0, hit=None):
        """Neuer Clip mit length Bildern (30 je Sekunde; wird auf ein Vielfaches von 3 aufgerundet).
        stride: Weg in Metern, den die Figur in EINEM Durchlauf zurücklegt (nur walk und ähnliche).
        hit: Bild, in dem der Schlag trifft / das Geschoss losfliegt (nur attack und Sonder-Clips)."""
        length = int(math.ceil(length / BAKE_STEP) * BAKE_STEP)
        c = Clip(self, name, length, loop, stride, hit)
        self.clips.append(c)
        return c

    def _obj(self, pname):
        return self.root if pname == "root" else self.parts[pname]

    def _apply(self):
        """Schreibt alle gesammelten Posen als Blender-Keyframes auf die Zeitleiste und merkt die Clip-Liste in der Szene."""
        sc = bpy.context.scene
        self.root.rotation_mode = "XYZ"
        self.root["rw_rest"] = [0.0, 0.0, 0.0]
        used = set()                                    # (teil, kanal), die irgendwo bewegt werden
        for c in self.clips:
            used.update(c.keys.keys())
        info = []
        cur = 1
        for c in self.clips:
            start, end = cur, cur + c.length
            for (pname, ch) in sorted(used):
                ob = self._obj(pname)
                path = dict(CHANNELS)[ch]
                rest = Vector(ob["rw_rest"])
                neutral = (1.0, 1.0, 1.0) if ch == "scale" else (0.0, 0.0, 0.0)
                ks = dict(c.keys.get((pname, ch), {}))
                if 0 not in ks:
                    ks[0] = neutral if not ks else ks[min(ks)]
                if c.loop:
                    ks[c.length] = ks[0]
                elif c.length not in ks:
                    ks[c.length] = ks[max(ks)]
                frames = sorted(ks)
                items = [(f, ks[f]) for f in frames]
                # Vor- und Nachlauf, damit die Kurve an den Clip-Grenzen stimmt (Schleife: nahtlos, sonst: ruhig)
                if c.loop and len(frames) > 2:
                    items.insert(0, (frames[-2] - c.length, ks[frames[-2]]))
                    items.append((c.length + frames[1], ks[frames[1]]))
                else:
                    items.insert(0, (-2, ks[frames[0]]))
                    items.append((c.length + 2, ks[frames[-1]]))
                for f, v in items:
                    if ch == "loc":
                        ob.location = rest + Vector(v)
                    elif ch == "rot":
                        ob.rotation_euler = tuple(math.radians(a) for a in v)
                    else:
                        ob.scale = v
                    ob.keyframe_insert(path, frame=start + f)
                    ip = c.interp.get((pname, ch, f))
                    if ip:
                        for fc in _fcurves(ob, path):
                            for kp in fc.keyframe_points:
                                if abs(kp.co[0] - (start + f)) < 0.01:
                                    kp.interpolation = ip
            m = sc.timeline_markers.new(c.name, frame=start)
            info.append({"name": c.name, "start": start, "end": end, "loop": bool(c.loop), "stride": float(c.stride),
                         "hit": (float(c.hit) / FPS if c.hit is not None else -1.0)})
            cur = end + GAP
        sc.frame_start = 1
        sc.frame_end = cur
        sc["rw_clips"] = json.dumps(info)
        sc["rw_key"] = self.key_name
        sc["rw_role"] = self.role
        # Ruhelage wiederherstellen
        sc.frame_set(info[0]["start"] if info else 1)
        return info

    def finish(self, icon_yaw=-30.0, icon_pitch=16.0, tafel=True, icon_clip="idle", icon_frame=0):
        """Keyframes schreiben, .blend speichern, Animations-Textur brennen, .glb exportieren, Symbol und Bildtafel rendern."""
        import vat_bake
        self._apply()
        name = "e_" + self.key_name
        bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT_BLEND, name + ".blend"))
        if self.role == "boss":
            vat_bake.export_boss(self.key_name)
        else:
            vat_bake.bake_vat(self.key_name, limit=VERT_LIMIT[self.role])
        bpy.ops.wm.open_mainfile(filepath=os.path.join(OUT_BLEND, name + ".blend"))
        vat_bake.set_pose(icon_clip, icon_frame)
        icon(name, 256, yaw=icon_yaw, pitch=icon_pitch)
        if tafel and "--notafel" not in sys.argv:
            bpy.ops.wm.open_mainfile(filepath=os.path.join(OUT_BLEND, name + ".blend"))
            vat_bake.tafel(self.key_name)
        print("ok", name, flush=True)


def _fcurves(ob, path):
    """F-Kurven eines Objekts für einen Datenpfad (Blender 4.4+/5.x mit Aktions-Ebenen und ältere)."""
    ad = ob.animation_data
    if ad is None or ad.action is None:
        return []
    act = ad.action
    out = []
    try:
        for layer in act.layers:
            for strip in layer.strips:
                cb = strip.channelbag(ad.action_slot)
                if cb is not None:
                    out += [fc for fc in cb.fcurves if fc.data_path == path]
    except Exception:
        out = [fc for fc in getattr(act, "fcurves", []) if fc.data_path == path]
    return out


# ---------------------------------------------------------------- Bau-Helfer für Figuren (sparsam mit Eckpunkten)
def lathe(p, prof, sides=10, loc=(0, 0, 0), r=None, cap=True, sx=1.0, sy=1.0):
    """Drehkörper um die Z-Achse. prof = [(radius, z, farbe), ...] von unten nach oben; die Farbe gilt für den Ring
    bis zum nächsten Eintrag (so entstehen Ringelhemden, Fässer, Hüte). sx/sy stauchen den Querschnitt zum Oval."""
    bm = p.bm
    before = set(bm.faces)
    m = Matrix.Translation(Vector(loc)) @ (r if r is not None else Matrix.Identity(4))
    if isinstance(getattr(p, "m", None), Matrix):          # MPart: zusätzliche Matrix des Teils
        m = p.m @ m
    rings = []
    for (rad, z, _c) in prof:
        row = []
        for i in range(sides):
            a = 2 * math.pi * i / sides
            row.append(bm.verts.new((math.cos(a) * rad * sx, math.sin(a) * rad * sy, z)))
        rings.append(row)
    for k in range(len(prof) - 1):
        c = col(prof[k][2])
        for i in range(sides):
            f = bm.faces.new((rings[k][i], rings[k][(i + 1) % sides], rings[k + 1][(i + 1) % sides], rings[k + 1][i]))
            f.smooth = True
            for l in f.loops:
                l[p.layer] = c
    if cap:
        for row, cc, flip in ((rings[0], prof[0][2], True), (rings[-1], prof[-1][2], False)):
            if prof[0 if flip else -1][0] > 0.002:
                f = bm.faces.new(list(reversed(row)) if flip else row)
                f.smooth = True
                for l in f.loops:
                    l[p.layer] = col(cc)
    verts = {v for f in bm.faces if f not in before for v in f.verts}
    for v in verts:
        v.co = m @ v.co
    return p


def capsule(p, a, b, r1, r2=None, color="steel", sides=6, round_k=0.6):
    """Glied von Punkt a nach Punkt b mit runden Enden (Arm, Bein, Finger). r1 = Dicke bei a, r2 bei b."""
    a, b = Vector(a), Vector(b)
    r2 = r1 if r2 is None else r2
    d = b - a
    L = d.length
    prof = [(r1 * 0.55, -r1 * round_k, color), (r1, 0.0, color), (r2, L, color), (r2 * 0.55, L + r2 * round_k, color)]
    return lathe(p, prof, sides=sides, loc=tuple(a), r=face_to(d))


def paint(p, color, zmin=-1e9, zmax=1e9, ymin=-1e9, ymax=1e9, xmin=-1e9, xmax=1e9):
    """Färbt alle bisherigen Flächen des Teils um, deren Mittelpunkt im Bereich liegt (Flecken, Bauch, Socken)."""
    c = col(color)
    for f in p.bm.faces:
        m = f.calc_center_median()
        if zmin <= m.z <= zmax and ymin <= m.y <= ymax and xmin <= m.x <= xmax:
            for l in f.loops:
                l[p.layer] = c
    return p
