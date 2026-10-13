extends Node3D
## Figur für Helden, Bewohner, Turmschützen und Gefangene: Voxel-Modell aus Blender (blender/heroes.py) mit dem
## gemeinsamen Skelett rw_human und Animationen aus Blender (blender/anim_human.py -> models/anim_human.glb).
## Abgespielt wird über einen AnimationTree, der hier im Code aufgebaut wird. Blickrichtung ist +Z.
##
## ------------------------------------------------------------------ Schnittstelle
## build(look)                 look = {"kind": Heldenschlüssel oder "settler", ...}
## tick(dt)                    einmal je Bild aufrufen (wer das nicht tut, wird von selbst langsam weiterbewegt)
## set_weapon(node, length)    Waffe an den Knochen prop_r hängen; muzzle sitzt an der Mündung
## set_pose(weapon_key)        Haltung ausdrücklich wählen (sonst wird sie aus dem Waffenmodell erkannt)
## move_amount : float         Tempo-Anteil wie bisher (1.0 entspricht etwa 6,4 m/s)
## move_dir : Vector2          Bewegungsrichtung relativ zur Blickrichtung (x = seitwärts zur Waffenhand, y = vorwärts),
##                             Länge 0..1. Wer sie nicht setzt, läuft vorwärts.
## speed_mps : float           tatsächliches Tempo in m/s; 0 = aus der Bewegung des Knotens bzw. move_amount schätzen
## aiming : bool               Oberkörper nimmt die Zielhaltung der Waffe ein
## look_target                 Vector3 (Welt) oder null: Kopf (höchstens 60°), Brust (35°) und Waffe drehen sich dorthin
## carrying : bool             Trage-Gang (carry_walk)
## ride : String               Sitzpose im Fahrzeug: "quad", "bike", "car", "hover" ("buggy"/"pickup" = "car"); "" = keine
## two_handed, kneel, lean     wie bisher (kneel > 0,5 ohne ride = Sitzpose "quad"; lean -1..1 neigt vor/zurück)
## kick(stärke)                Schuss-Animation der Waffe (Rückstoß)       swing()       Nahkampf-Schwung
## reload(dauer)               Nachladen, auf die Dauer gestreckt           throw_anim()  Wurf
## cheer(sekunden)             Jubeln                                       hop(dauer)    Ausweichrolle + Abfedern
## die() / revive()            Umfallen und liegen bleiben / aufstehen      dead : bool
## play(clip, hold) -> bool    Einmal-Clip für den ganzen Körper (chop, mine, pick_up, hammer, pay, wave, cheer, sit, sleep,
##                             level_up, victory, defeat, hit_light, hit_heavy, mount, dismount, skill_1, skill_2, special ...);
##                             hold = true hält die Endpose bzw. Schleife bis stop_clip(). false, wenn es den Clip nicht gibt.
## stop_clip()                 beendet gehaltene und laufende Clips        has_clip(clip) -> bool
## signal footstep(left)       aus den Lauf-Clips (Ereignisse foot_l / foot_r)
## muzzle : Node3D             Mündung der Waffe                           extra : Node3D  Begleiter (Drohne, Falke)
## WEAPON_POSE / POSES         welche Waffe welche Halte-, Schuss- und Nachlade-Animation nutzt
## Paket H (V6):
## victory(sekunden)           Siegerpose des Helden (<held>_victory), danach zurück
## set_face(name, sekunden)    Gesicht: normal | blink | joy | pain | strain (Helden; blinzeln von selbst)
## set_gear(slot, modell, k)   Ausrüstung am Skelett (helmet -> head, vest -> chest, charm -> hips); "" nimmt sie ab
## set_modules([[schlüssel, ort], ...])   Waffenmodule am Waffenmodell (muzzle, top, under, side, core, head)
## Die Mündung sitzt am Leerobjekt "muzzle" des Waffenmodells; Laufstil je Held additiv (gait_<held>).
## ------------------------------------------------------------------

const MK = preload("res://src/mk.gd")
const D = preload("res://src/data.gd")
const Models = preload("res://src/models.gd")
const AD = preload("res://src/anim_human_data.gd")
const AimMod = preload("res://src/humanoid_aim.gd")
const DH = preload("res://src/data_helden.gd")

signal footstep(left: bool)

## Haltung je Waffenart: Halte-Clip, Schuss-Clip, Nachlade-Clip; add = Schuss wird additiv aufgelegt (reiner Rückstoß)
const POSES := {
	"rifle": {"aim": "aim_rifle", "fire": "fire_rifle", "reload": "reload_rifle", "add": true},
	"sniper": {"aim": "aim_rifle", "fire": "fire_heavy", "reload": "reload_rifle", "add": true},
	"heavy": {"aim": "aim_heavy", "fire": "fire_heavy", "reload": "reload_heavy", "add": true},
	"bow": {"aim": "aim_bow", "fire": "fire_bow", "reload": "reload_bow", "add": false},
	"thrower": {"aim": "aim_thrower", "fire": "fire_throw", "reload": "reload_thrower", "add": false},
	"melee": {"aim": "aim_melee", "fire": "fire_swing", "reload": "reload_heavy", "add": false},
	"spray": {"aim": "aim_spray", "fire": "fire_spray_loop", "reload": "reload_thrower", "add": true},
	# V4 Waffen-Arsenal
	"pistol": {"aim": "aim_pistol", "fire": "fire_rifle", "reload": "reload_rifle", "add": true},
	"spear": {"aim": "aim_spear", "fire": "fire_thrust", "reload": "reload_heavy", "add": false},
	"hammer": {"aim": "aim_hammer", "fire": "fire_slam", "reload": "reload_heavy", "add": false},
	"toss": {"aim": "aim_toss", "fire": "fire_toss", "reload": "reload_thrower", "add": false},
	"staff": {"aim": "aim_staff", "fire": "fire_cast", "reload": "reload_rifle", "add": false},
}
## Waffe -> Haltung (die 18 ersten Waffen; die Waffen des V4-Arsenals tragen ihre Haltung in D.WEAPONS[key].pose)
const WEAPON_POSE := {
	"j_rifle": "rifle", "j_parcel": "thrower", "j_burst": "rifle",
	"m_flame": "spray", "m_water": "spray", "m_fireball": "thrower",
	"b_nailer": "heavy", "b_ball": "melee", "b_cement": "heavy",
	"a_spark": "rifle", "a_shrink": "rifle", "a_cloud": "thrower",
	"y_rifle": "sniper", "y_bow": "bow", "y_swarm": "bow",
	"g_cracker": "thrower", "g_sparkler": "rifle", "g_cake": "thrower",
}
const RIDES := {"quad": "ride_quad", "bike": "ride_bike", "car": "ride_car", "buggy": "ride_car", "pickup": "ride_car", "hover": "ride_hover"}
## Lauf-Clips im BlendSpace "move": Stand in der Mitte, je 8 Richtungen Gehen (innerer Ring) und Rennen (äußerer Ring)
const DIR_NAMES := ["f", "fr", "r", "br", "b", "bl", "l", "fl"]
const DIRS := [Vector2(0, 1), Vector2(0.70710678, 0.70710678), Vector2(1, 0), Vector2(0.70710678, -0.70710678),
	Vector2(0, -1), Vector2(-0.70710678, -0.70710678), Vector2(-1, 0), Vector2(-0.70710678, 0.70710678)]
const LOCO := ["idle", "walk_f", "walk_fr", "walk_r", "walk_br", "walk_b", "walk_bl", "walk_l", "walk_fl",
	"run_f", "run_fr", "run_r", "run_br", "run_b", "run_bl", "run_l", "run_fl"]
const UPPER := ["spine", "chest", "neck", "head", "shoulder_l", "upper_arm_l", "fore_arm_l", "hand_l", "shoulder_r", "upper_arm_r", "fore_arm_r", "hand_r", "prop_r", "prop_back"]
const V_WALK := 1.5                  # m/s (Figur im Spielmaßstab), bei dem der reine Geh-Clip läuft
const V_RUN := 4.5                   # Lage des reinen Renn-Clips im BlendSpace
const V_SLOW := 0.25                 # darunter wird zum Stand hin gemischt, darüber läuft der reine Geh-Clip (langsamer)
const V_GAIT := 2.8                  # bis hier wird gegangen (schnellere Schritte), darüber gerannt – Gehen und Rennen
                                     # werden nie dauerhaft gemischt, sonst rutschen die Füße (verschiedene Standphasen)
const MAX_RATE := 6.0                # höchstens so viele Schrittzyklen je Sekunde
const FADE := 0.12                   # Übergänge
const FADE_MOVE := 0.18              # Stehen <-> Laufen
const FAR := 45.0                    # weiter weg von der Kamera: Animation nur jedes zweite Bild
const SKEL := "rw_human/Skeleton3D"

const P_MOVE := &"parameters/move/blend_position"
const P_MOVE_SEEK := &"parameters/move_seek/seek_request"
const P_CARRY_SEEK := &"parameters/carry_seek/seek_request"
const P_CARRY := &"parameters/loco/blend_amount"
const P_RIDE := &"parameters/ride/transition_request"
const P_RIDE_W := &"parameters/base/blend_amount"
const P_STEER := &"parameters/steer/add_amount"
const P_AIM := &"parameters/aim/transition_request"
const P_AIM_W := &"parameters/body/blend_amount"
const P_RELOAD := &"parameters/reload/transition_request"
const P_RELOAD_TS := &"parameters/reload_ts/scale"
const P_RELOAD_GO := &"parameters/up1/request"
const P_FIREMIX := &"parameters/firemix/transition_request"
const P_FIREMIX_GO := &"parameters/up2/request"
const P_FIREADD := &"parameters/fireadd/transition_request"
const P_FIREADD_GO := &"parameters/body2/request"
const P_SPRAY := &"parameters/spray/add_amount"
const P_GAIT := &"parameters/gait/transition_request"
const P_GAIT_SEEK := &"parameters/gait_seek/seek_request"
const P_GAIT_W := &"parameters/gait_add/add_amount"
const P_ACT: Array[StringName] = [&"parameters/act0/transition_request", &"parameters/act1/transition_request", &"parameters/act2/transition_request"]
const P_ACT_TS: Array[StringName] = [&"parameters/act0_ts/scale", &"parameters/act1_ts/scale", &"parameters/act2_ts/scale"]
const P_ACT_W: Array[StringName] = [&"parameters/full0/blend_amount", &"parameters/full1/blend_amount", &"parameters/full2/blend_amount"]
## Clips, die immer den ganzen Körper brauchen (alle anderen laufen im Gehen/Fahren nur auf dem Oberkörper)
const FULL_ONLY := ["dodge_roll", "dodge_land", "down", "revive", "mount", "dismount", "sit", "sleep", "defeat", "pick_up", "jona_skill_2"]
## Clips, die nicht abgebrochen werden, wenn die Figur losläuft
const LOCKED := ["dodge_roll", "dodge_land", "down", "revive", "mount", "dismount", "jona_skill_2"]

static var _lib: AnimationLibrary
static var _root: AnimationNodeBlendTree

# ---------------------------------------------------------------- öffentlich
var move_amount := 0.0
var move_dir := Vector2(0, 1)
var speed_mps := 0.0
var aiming := false
var two_handed := true
var kneel := 0.0
var lean := 0.0
var dead := false
var carrying := false
var ride := ""
var look_target = null
var muzzle: Node3D
var extra: Node3D                    # Begleiter (Drohne, Falke)
var kind := "settler"
var skel: Skeleton3D
var tree: AnimationTree

# ---------------------------------------------------------------- intern
var _pivot: Node3D
var _model: Node3D
var _prop: BoneAttachment3D
var _tgt: Node3D
var _looks: Array = []               # LookAtModifier3D für Brust und Kopf
var _aimer: SkeletonModifier3D       # richtet die Waffe aus (humanoid_aim.gd)
var _pose := "rifle"
var _has_weapon := false
var _pset := {}                      # zuletzt gesetzte Parameter (nur Änderungen gehen an den AnimationTree)
var _pos := Vector2.ZERO             # geglättete Lage im BlendSpace
var _aim_w := 0.0
var _ride_w := 0.0
var _ride_now := ""
var _carry_w := 0.0
var _spray_w := 0.0
var _look_w := 0.0
var _prop_w := 0.0
var _steer := 0.0
var _tau := 0.0                      # Abspielzeit der Lauf-Clips (0 .. 3 Zyklen)
var _running := false
var _reload_left := 0.0
var _fire_frame := -1
var _swing_left := 0.0
var updates := 0                     # Zahl der Animationsschritte (für Tests: ferne Figuren rechnen nur jedes zweite Bild)
# Kanäle für Aktionen: 0 und 1 = ganzer Körper (im Wechsel, für weiches Überblenden), 2 = nur Oberkörper
var _ch := [{"clip": "", "w": 0.0, "on": false, "left": 0.0, "hold": false, "next": ""}, {"clip": "", "w": 0.0, "on": false, "left": 0.0, "hold": false, "next": ""},
		{"clip": "", "w": 0.0, "on": false, "left": 0.0, "hold": false, "next": ""}]
var _ch_i := 0
var _ch_full := 0
var _cheer_left := 0.0
var _idle_wait := 8.0
var _idle_ch := -1
var _t := 0.0
var _acc := 0.0
var _half := false
var _odd := false
var _lod_t := 0.0
var _last_tick := -1000
var _pending := false
var _last_gp := Vector3.ZERO
var _last_dir := Vector2.ZERO
var _have_gp := false
var _speed := 0.0                    # geglättetes Tempo (m/s, Welt)
var _prev_speed := 0.0
var _tilt := Vector2.ZERO
var _k := 1.0                        # Größe der Figur gegenüber dem Spielmaßstab (D.CHAR_SCALE)
var _rng := RandomNumberGenerator.new()
# Paket H: Gesichter, Ausrüstung, Module, Laufstil
var face := "normal"
var _faces := {}                     # name -> MeshInstance3D (nur Helden)
var _face_t := 0.0                   # Restzeit eines gesetzten Gesichts
var _face_set := ""
var _blink_t := 3.0
var _hat: MeshInstance3D
var _gear := {}                      # slot -> Node3D (BoneAttachment3D mit Modell)
var _mods: Array = []
var _weapon_node: Node3D
var _has_gait := false
var _gait_w := 0.0


## look: {"kind": Heldenschlüssel oder "settler"}; weitere Felder (helm, suit, tier) werden nicht mehr gebraucht.
func build(look: Dictionary) -> void:
	kind = look.get("kind", "settler")
	var file := "hero_" + kind
	if String(look.get("skin", "")) != "" and Models.has_glb("hero_" + String(look.skin)):
		file = "hero_" + String(look.skin)                   # Paket L: Helden-Skin (gleiches Skelett, andere Farben)
	if not Models.has_glb(file):
		file = "hero_settler"
	_pivot = Node3D.new()
	_pivot.name = "P"
	add_child(_pivot)
	_model = Models._scene(file).instantiate()
	_model.name = "M"
	_pivot.add_child(_model)
	skel = _model.get_node(SKEL)
	skel.modifier_callback_mode_process = Skeleton3D.MODIFIER_CALLBACK_MODE_PROCESS_MANUAL
	for c in skel.get_children():
		if c is MeshInstance3D:
			c.material_override = MK.mat_lin()
			c.extra_cull_margin = 0.6
			var cn := String(c.name)
			if cn.begins_with("face_"):              # Paket H: austauschbare Gesichter, sichtbar ist immer genau eines
				_faces[cn.substr(5)] = c
				c.visible = cn == "face_normal"
				c.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			elif cn == "hat":
				_hat = c
	var ex := Models._find_mesh(_model, "extra")
	if ex != null:
		extra = Node3D.new()
		add_child(extra)
		ex.owner = null
		ex.get_parent().remove_child(ex)
		extra.add_child(ex)
		ex.transform = Transform3D.IDENTITY
		ex.material_override = MK.mat_lin()
		extra.position = Vector3(-0.6, 1.9, -0.2)
	_prop = BoneAttachment3D.new()
	_prop.name = "Prop"
	skel.add_child(_prop)
	_prop.bone_name = "prop_r"
	muzzle = Node3D.new()
	_prop.add_child(muzzle)
	muzzle.position = Vector3(0, 0.08, 0.6)
	_build_modifiers()
	tree = AnimationTree.new()
	tree.name = "Tree"
	tree.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	tree.callback_mode_method = AnimationMixer.ANIMATION_CALLBACK_MODE_METHOD_IMMEDIATE
	tree.add_animation_library(&"", library())
	tree.tree_root = _tree_root()
	add_child(tree)
	tree.root_node = NodePath("../P/M")
	tree.active = true
	_has_gait = AD.CLIPS.has("gait_" + kind)
	if _has_gait:
		tree.set(P_GAIT, "gait_" + kind)
	tree.set(P_GAIT_W, 0.0)
	_rng.randomize()
	_blink_t = _rng.randf_range(DH.BLINK_EVERY[0], DH.BLINK_EVERY[1])
	_idle_wait = _rng.randf_range(6.0, 14.0)
	_half = kind == "settler"
	_odd = _rng.randf() < 0.5
	set_process(true)


## Kopf, Brust und Waffe drehen sich zum Ziel (LookAtModifier3D); spring_*-Knochen schwingen nach (SpringBoneSimulator3D).
func _build_modifiers() -> void:
	_tgt = Node3D.new()
	_tgt.name = "LookTarget"
	add_child(_tgt)
	_tgt.top_level = true
	for cfg in [["chest", 35.0, 22.0], ["head", 60.0, 35.0]]:
		var la := LookAtModifier3D.new()
		la.name = "Look_" + String(cfg[0])
		skel.add_child(la)
		la.bone_name = cfg[0]
		la.target_node = NodePath("../../../../../LookTarget")
		la.forward_axis = SkeletonModifier3D.BONE_AXIS_PLUS_Z
		la.primary_rotation_axis = Vector3.AXIS_Y
		la.use_secondary_rotation = true
		la.relative = true            # Drehung kommt zur animierten Haltung dazu (Rückstoß, Nachladen bleiben sichtbar)
		la.use_angle_limitation = true
		la.symmetry_limitation = true
		la.primary_limit_angle = deg_to_rad(float(cfg[1]) * 2.0)
		la.secondary_limit_angle = deg_to_rad(float(cfg[2]) * 2.0)
		la.duration = 0.0
		la.influence = 0.0
		la.active = false
		_looks.append(la)
	# die Waffe selbst: eigener kleiner Modifier (die Grenzen des LookAtModifier3D gelten gegenüber dem Elternknochen,
	# und die Hand ist im Anschlag stark gedreht – die Waffe würde kippen)
	_aimer = AimMod.new()
	_aimer.name = "Aim_prop"
	skel.add_child(_aimer)
	_aimer.bone = skel.find_bone("prop_r")
	var springs: Array = []
	for i in skel.get_bone_count():
		if String(skel.get_bone_name(i)).begins_with("spring_"):
			springs.append(skel.get_bone_name(i))
	if springs.is_empty():
		return
	var sp := SpringBoneSimulator3D.new()
	sp.name = "Springs"
	skel.add_child(sp)
	sp.setting_count = springs.size()
	for i in springs.size():
		# Paket H: Haare, Tücher, Kittel hängen nach unten und schwingen weicher (DH.SPRINGS)
		var cfg: Array = DH.SPRINGS["spring_"]
		for pre in DH.SPRINGS:
			if String(springs[i]).begins_with(pre) and pre != "spring_":
				cfg = DH.SPRINGS[pre]
				break
		sp.set_root_bone_name(i, springs[i])
		sp.set_end_bone_name(i, springs[i])
		sp.set_extend_end_bone(i, true)
		sp.set_end_bone_length(i, float(cfg[3]))
		sp.set_end_bone_direction(i, SkeletonModifier3D.BONE_DIRECTION_PLUS_Y if int(cfg[4]) > 0 else SkeletonModifier3D.BONE_DIRECTION_MINUS_Y)
		sp.set_stiffness(i, float(cfg[0]))
		sp.set_drag(i, float(cfg[1]))
		sp.set_gravity(i, float(cfg[2]))


# ---------------------------------------------------------------- Animationen und Baum (einmal für alle Figuren)
## Alle Clips aus models/anim_human.glb, vorbereitet: Schleifen, nur Drehungen (+ Lage der Hüfte), Schritt-Ereignisse.
static func library() -> AnimationLibrary:
	if _lib != null:
		return _lib
	_lib = AnimationLibrary.new()
	var src: Node = Models._scene("anim_human").instantiate()
	var ap: AnimationPlayer = src.find_child("AnimationPlayer", true, false)
	for nm in AD.CLIPS:
		# Godot entfernt beim Import die Endung "_loop" aus Animationsnamen
		var src_name: String = nm if ap.has_animation(nm) else String(nm).trim_suffix("_loop")
		if not ap.has_animation(src_name):
			push_error("Animation fehlt in models/anim_human.glb: %s" % nm)
			continue
		var a: Animation = ap.get_animation(src_name).duplicate(true)
		var info: Dictionary = AD.CLIPS[nm]
		a.loop_mode = Animation.LOOP_LINEAR if info.get("loop", false) else Animation.LOOP_NONE
		a.length = float(info.len)
		for t in range(a.get_track_count() - 1, -1, -1):
			var ty := a.track_get_type(t)
			var path := a.track_get_path(t)
			var bone := String(path.get_subname(0)) if path.get_subname_count() > 0 else ""
			# Lage nur für die Hüfte (Figuren sind verschieden breit), keine Größenänderung
			if ty == Animation.TYPE_SCALE_3D or (ty == Animation.TYPE_POSITION_3D and bone != "hips"):
				a.remove_track(t)
		_lib.add_animation(nm, a)
	src.free()
	return _lib


static func _anim(clip: String) -> AnimationNodeAnimation:
	var n := AnimationNodeAnimation.new()
	n.animation = clip
	return n


static func _transition(clips: Array, xfade: float) -> AnimationNodeTransition:
	var tr := AnimationNodeTransition.new()
	tr.xfade_time = xfade
	tr.allow_transition_to_self = true
	tr.input_count = clips.size()
	return tr


static func _add_transition(bt: AnimationNodeBlendTree, name: String, clips: Array, xfade: float) -> void:
	var tr := _transition(clips, xfade)
	bt.add_node(name, tr)
	for i in clips.size():
		tr.set_input_name(i, clips[i])
		tr.set_input_reset(i, true)
		var an := "%s_%d" % [name, i]
		bt.add_node(an, _anim(clips[i]))
		bt.connect_node(name, i, an)


static func _timescale(bt: AnimationNodeBlendTree, name: String, input: String) -> void:
	bt.add_node(name, AnimationNodeTimeScale.new())
	bt.connect_node(name, 0, input)


static func _upper_filter(n: AnimationNode) -> void:
	n.filter_enabled = true
	for b in UPPER:
		n.set_filter_path(NodePath("%s:%s" % [SKEL, b]), true)


static func _oneshot(fade_in: float, fade_out: float, add := false) -> AnimationNodeOneShot:
	var os := AnimationNodeOneShot.new()
	os.fadein_time = fade_in
	os.fadeout_time = fade_out
	if add:
		os.mix_mode = AnimationNodeOneShot.MIX_MODE_ADD
	return os


## Aufbau: Unterkörper (BlendSpace2D "move" mit Stand + 8 Lauf-Clips, Abspielzeit über move_seek) -> Trage-Gang ->
## Sitzpose -> Oberkörper-Ebene (Zielhaltung, Nachladen und Schuss als OneShot, Knochenfilter ab spine aufwärts) ->
## additiver Rückstoß -> Ganzkörper-Aktionen auf zwei Kanälen (weiches Überblenden von Clip zu Clip, haltbare Endposen).
static func _tree_root() -> AnimationNodeBlendTree:
	if _root != null:
		return _root
	var lib := library()
	var bt := AnimationNodeBlendTree.new()
	# --- Unterkörper
	var bs := AnimationNodeBlendSpace2D.new()
	bs.min_space = Vector2(-V_RUN, -V_RUN)
	bs.max_space = Vector2(V_RUN, V_RUN)
	bs.auto_triangles = false
	# nicht "sync": statt alle 9 Clips mitlaufen zu lassen, setzt _update() jedem aktiven Clip dieselbe Zeit
	# (TimeSeek "move_seek") – alle Lauf-Clips sind gleich lang und bleiben so im Takt
	bs.add_blend_point(_anim("idle"), Vector2.ZERO)
	for i in 8:
		bs.add_blend_point(_anim(LOCO[1 + i]), DIRS[i] * V_WALK)
	for i in 8:
		bs.add_blend_point(_anim(LOCO[9 + i]), DIRS[i] * V_RUN)
	for i in 8:                      # je Richtungs-Sektor drei Dreiecke (dieselben wie in stride_at)
		var j := (i + 1) % 8
		bs.add_triangle(0, 1 + i, 1 + j)
		bs.add_triangle(1 + i, 9 + i, 9 + j)
		bs.add_triangle(1 + i, 9 + j, 1 + j)
	bt.add_node("move", bs)
	bt.add_node("move_seek", AnimationNodeTimeSeek.new())
	bt.connect_node("move_seek", 0, "move")
	bt.add_node("carry", _anim("carry_walk"))
	bt.add_node("carry_seek", AnimationNodeTimeSeek.new())
	bt.connect_node("carry_seek", 0, "carry")
	var loco := AnimationNodeBlend2.new()
	_upper_filter(loco)
	bt.add_node("loco", loco)
	bt.connect_node("loco", 0, "move_seek")
	bt.connect_node("loco", 1, "carry_seek")
	# --- Sitzpose im Fahrzeug, Lenken additiv
	_add_transition(bt, "ride", ["ride_quad", "ride_bike", "ride_car", "ride_hover"], FADE)
	bt.add_node("base", AnimationNodeBlend2.new())
	bt.connect_node("base", 0, "loco")
	bt.connect_node("base", 1, "ride")
	bt.add_node("steer_clip", _anim("ride_steer"))
	bt.add_node("steer", AnimationNodeAdd2.new())
	bt.connect_node("steer", 0, "base")
	bt.connect_node("steer", 1, "steer_clip")
	# --- Oberkörper: Zielhaltung -> Nachladen -> Schuss
	_add_transition(bt, "aim", ["aim_rifle", "aim_heavy", "aim_bow", "aim_thrower", "aim_melee", "aim_spray",
			"hold_rifle", "hold_heavy", "hold_bow", "hold_thrower", "hold_melee", "hold_spray",
			"aim_pistol", "aim_spear", "aim_hammer", "aim_toss", "aim_staff",
			"hold_pistol", "hold_spear", "hold_hammer", "hold_toss", "hold_staff"], FADE)
	_add_transition(bt, "reload", ["reload_rifle", "reload_heavy", "reload_bow", "reload_thrower"], 0.0)
	_timescale(bt, "reload_ts", "reload")
	bt.add_node("up1", _oneshot(FADE, FADE))
	bt.connect_node("up1", 0, "aim")
	bt.connect_node("up1", 1, "reload_ts")
	_add_transition(bt, "firemix", ["fire_bow", "fire_throw", "fire_swing", "fire_thrust", "fire_slam", "fire_toss", "fire_cast"], 0.0)
	bt.add_node("up2", _oneshot(0.04, 0.1))
	bt.connect_node("up2", 0, "up1")
	bt.connect_node("up2", 1, "firemix")
	var body := AnimationNodeBlend2.new()
	_upper_filter(body)
	bt.add_node("body", body)
	bt.connect_node("body", 0, "steer")
	bt.connect_node("body", 1, "up2")
	_add_transition(bt, "fireadd", ["fire_rifle", "fire_heavy"], 0.0)
	bt.add_node("body2", _oneshot(0.0, 0.04, true))
	bt.connect_node("body2", 0, "body")
	bt.connect_node("body2", 1, "fireadd")
	bt.add_node("spray_clip", _anim("fire_spray_loop"))
	bt.add_node("spray", AnimationNodeAdd2.new())
	bt.connect_node("spray", 0, "body2")
	bt.connect_node("spray", 1, "spray_clip")
	# --- Paket H: Laufstil je Held (additiv, nur Rumpf und Kopf, im Takt der Schritte)
	var gaits: Array = []
	for nm in lib.get_animation_list():
		if String(nm).begins_with("gait_"):
			gaits.append(String(nm))
	var prev := "spray"
	if not gaits.is_empty():
		_add_transition(bt, "gait", gaits, 0.0)
		bt.add_node("gait_seek", AnimationNodeTimeSeek.new())
		bt.connect_node("gait_seek", 0, "gait")
		bt.add_node("gait_add", AnimationNodeAdd2.new())
		bt.connect_node("gait_add", 0, "spray")
		bt.connect_node("gait_add", 1, "gait_seek")
		prev = "gait_add"
	# --- Ganzkörper-Aktionen (zwei Kanäle)
	var acts: Array = []
	for nm in lib.get_animation_list():
		if not LOCO.has(String(nm)) and not String(nm).begins_with("gait_"):
			acts.append(String(nm))
	for i in [2, 0, 1]:
		_add_transition(bt, "act%d" % i, acts, 0.0)
		_timescale(bt, "act%d_ts" % i, "act%d" % i)
		var fb := AnimationNodeBlend2.new()
		if i == 2:
			_upper_filter(fb)        # Kanal 2: nur Oberkörper, die Beine laufen weiter
		bt.add_node("full%d" % i, fb)
		bt.connect_node("full%d" % i, 0, prev)
		bt.connect_node("full%d" % i, 1, "act%d_ts" % i)
		prev = "full%d" % i
	bt.connect_node("output", 0, prev)
	_root = bt
	return _root


# ---------------------------------------------------------------- Waffe
func set_weapon(mesh_node: Node3D, length: float, hand_scale := 1.0) -> void:
	for c in _prop.get_children():
		if c != muzzle:
			c.queue_free()
	_mods.clear()
	_has_weapon = mesh_node != null
	_weapon_node = mesh_node
	muzzle.position = Vector3(0, 0.08, length)
	if mesh_node:
		_prop.add_child(mesh_node)
		mesh_node.scale = Vector3.ONE * hand_scale          # Paket H: Wurfwaffen sind in der Hand größer
		var f := mesh_node.scene_file_path.get_file().get_basename()        # "w_j_rifle"
		if f.begins_with("w_"):
			set_pose(f.substr(2))
		# Paket H: Mündung am Leerobjekt "muzzle" des Modells – Schüsse kommen aus dem Lauf
		var mz := Models.find(mesh_node, "muzzle")
		if mz != null and mz != mesh_node:
			muzzle.position = mesh_node.transform * _rel_xf(mz, mesh_node).origin


## Lage von n relativ zu root (ohne dass die Knoten im Baum sein müssen).
static func _rel_xf(n: Node3D, root: Node3D) -> Transform3D:
	var xf := Transform3D.IDENTITY
	var c: Node = n
	while c != null and c != root:
		if c is Node3D:
			xf = (c as Node3D).transform * xf
		c = c.get_parent()
	return xf


## Haltung nach Waffenschlüssel (D.WEAPONS) oder direkt nach Art ("rifle", "heavy", "bow", "thrower", "melee", "spray").
func set_pose(weapon_key: String) -> void:
	var p := pose_name(weapon_key)
	if POSES.has(p):
		_pose = p


## Name der Haltung einer Waffe (WEAPON_POSE, sonst D.WEAPONS[key].pose); unbekannte Schlüssel bleiben, wie sie sind.
static func pose_name(weapon_key: String) -> String:
	if WEAPON_POSE.has(weapon_key):
		return String(WEAPON_POSE[weapon_key])
	if D.WEAPONS.has(weapon_key):
		return String(D.WEAPONS[weapon_key].get("pose", "rifle"))
	return weapon_key


static func weapon_pose(weapon_key: String) -> Dictionary:
	return POSES.get(pose_name(weapon_key), {})


# ---------------------------------------------------------------- Aktionen (alte Namen bleiben)
func kick(_strength := 1.0) -> void:
	_fire()


func swing() -> void:
	_fire()


func throw_anim() -> void:
	_fire()


func _fire() -> void:
	if tree == null or dead or _fire_frame == Engine.get_process_frames():
		return
	_fire_frame = Engine.get_process_frames()
	if DH.STRAIN_POSES.has(_pose):
		set_face("strain", 0.35)
	var ps: Dictionary = POSES[_pose]
	if _pose == "spray":
		return                       # Sprühen läuft als Schleife, solange gezielt wird
	if ps.add:
		tree.set(P_FIREADD, ps.fire)
		tree.set(P_FIREADD_GO, AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
	else:
		tree.set(P_FIREMIX, ps.fire)
		tree.set(P_FIREMIX_GO, AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
		_swing_left = clip_len(ps.fire)   # solange der Ablauf läuft, wird die Waffe nicht nachgerichtet


func reload(duration: float) -> void:
	if tree == null or dead:
		return
	var clip: String = POSES[_pose].reload
	var d := maxf(duration, 0.15)
	_reload_left = d
	tree.set(P_RELOAD, clip)
	_sp(P_RELOAD_TS, clip_len(clip) / d)
	tree.set(P_RELOAD_GO, AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)


func cheer(t := 1.5) -> void:
	if dead:
		return
	if play("cheer", true):
		_cheer_left = t


## Paket H: Siegerpose des Helden (Clip <held>_victory, sonst victory), t Sekunden lang.
func victory(t := 3.0) -> void:
	if dead:
		return
	if play("victory", true):
		_cheer_left = t


## Paket H: Gesicht für t Sekunden setzen (normal, blink, joy, pain, strain). t <= 0: bis zum nächsten Aufruf.
func set_face(nm: String, t := 0.6) -> void:
	if _faces.is_empty() or not _faces.has(nm):
		return
	_face_set = nm
	_face_t = t if t > 0.0 else 9999.0
	_show_face(nm)


func _show_face(nm: String) -> void:
	if nm == face or not _faces.has(nm):
		return
	if _faces.has(face):
		_faces[face].visible = false
	_faces[nm].visible = true
	face = nm


func has_faces() -> bool:
	return not _faces.is_empty()


## Paket H: Ausrüstung am Skelett. slot: helmet (Kopf), vest (Brust), charm (Hüfte). model "" nimmt das Teil ab.
## Ein Helm ersetzt die eigene Kopfbedeckung des Helden (Mesh "hat").
func set_gear(slot: String, model: String, k := 1.0) -> void:
	if skel == null:
		return
	var old: Node3D = _gear.get(slot)
	if old != null and is_instance_valid(old):
		if String(old.get_meta("model", "")) == model:
			return
		old.queue_free()
	_gear.erase(slot)
	if slot == "helmet" and _hat != null:
		_hat.visible = model == "" or not DH.HIDE_HAT
	if model == "" or not Models.has_glb(model):
		if slot == "helmet" and _hat != null:
			_hat.visible = true
		return
	var ba := BoneAttachment3D.new()
	ba.name = "Gear_" + slot
	ba.bone_name = {"helmet": "head", "vest": "chest", "charm": "hips"}.get(slot, "chest")
	ba.set_meta("model", model)
	skel.add_child(ba)
	var g := Models.glb(model)
	g.scale = Vector3(k, 1.0, 1.0 if slot != "vest" else maxf(1.0, k * 0.9))
	ba.add_child(g)
	for mi in g.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).extra_cull_margin = 0.6
		if slot == "charm":
			(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_gear[slot] = ba


func gear_model(slot: String) -> String:
	var n: Node3D = _gear.get(slot)
	return String(n.get_meta("model", "")) if n != null and is_instance_valid(n) else ""


## Paket H: Waffenmodule am Waffenmodell. list = [[schlüssel, ort], ...]; Lage aus Mündung und Größe des Modells.
func set_modules(list: Array) -> void:
	for m in _mods:
		if is_instance_valid(m):
			m.queue_free()
	_mods.clear()
	if _weapon_node == null or not is_instance_valid(_weapon_node):
		return
	var mz := muzzle.position
	var hk: float = _weapon_node.scale.x
	# Lage aus der Mündung: der Lauf liegt auf Höhe mz.y, die Waffe reicht von z = 0 (Griff) bis mz.z
	for e in list:
		var key := String(e[0])
		var where := String(e[1])
		var mn := "mod_" + key
		if not Models.has_glb(mn):
			continue
		var n := Models.glb(mn)
		n.name = "Mod_" + key
		var len_z: float = maxf(mz.z, 0.2)
		match where:
			"muzzle":
				n.position = mz
			"top":
				n.position = Vector3(0, mz.y + 0.06 * hk, len_z * 0.4)
			"under":
				n.position = Vector3(0, mz.y - 0.05 * hk, len_z * 0.42)
			"side":
				n.position = Vector3(0.06 * hk, mz.y - 0.02, len_z * 0.2)
			"core":
				n.position = Vector3(-0.06 * hk, mz.y, len_z * 0.3)
			"head":
				n.position = Vector3(0, mz.y, len_z * 0.92)
		_prop.add_child(n)
		_mods.append(n)


func module_nodes() -> Array:
	return _mods.filter(func(x): return is_instance_valid(x))




## Ausweichrolle (dauer = Länge der Rolle), danach kurzes Abfedern.
func hop(duration := 0.3) -> void:
	if dead:
		return
	if _play("dodge_roll", false, clip_len("dodge_roll") / maxf(duration, 0.1)):
		_ch[_ch_i].next = "dodge_land"


func die() -> void:
	dead = true
	stop_clip()
	_play("down", true, 1.0)


func revive() -> void:
	dead = false
	rotation.x = 0.0
	position.y = 0.0
	scale = scale.abs()
	stop_clip()
	_play("revive", false, 1.0)


func has_clip(clip: String) -> bool:
	return _resolve(clip) != ""


static func clip_len(clip: String) -> float:
	return float(AD.CLIPS[clip].len) if AD.CLIPS.has(clip) else 1.0


## Spielt einen Clip für den ganzen Körper. hold = true: Endpose/Schleife bleibt bis stop_clip().
func play(clip: String, hold := false) -> bool:
	if dead:
		return false
	return _play(clip, hold, 1.0)


func stop_clip() -> void:
	for c in _ch:
		c.on = false
		c.next = ""
	_cheer_left = 0.0
	_idle_ch = -1


## "skill_1" wird zu "<held>_skill_1"; unbekannte Namen ergeben "".
func _resolve(clip: String) -> String:
	if AD.CLIPS.has(kind + "_" + clip):
		return kind + "_" + clip
	if AD.CLIPS.has(clip) and not LOCO.has(clip):
		return clip
	return ""


func _play(clip: String, hold: bool, rate: float) -> bool:
	var c := _resolve(clip)
	if c == "" or tree == null:
		return false
	for ch in _ch:                   # laufende Clips blenden aus, der neue auf dem anderen Kanal ein
		ch.on = false
		ch.next = ""
	_cheer_left = 0.0
	_idle_ch = -1
	var upper := (_speed > 0.6 or _ride_now != "") and not FULL_ONLY.has(c)
	if upper:
		_ch_i = 2
	else:
		_ch_full = 1 - _ch_full
		_ch_i = _ch_full
	var ch: Dictionary = _ch[_ch_i]
	ch.clip = c
	ch.on = true
	ch.hold = hold
	ch.left = clip_len(c) / rate
	tree.set(P_ACT[_ch_i], c)
	_sp(P_ACT_TS[_ch_i], rate)
	return true


# ---------------------------------------------------------------- Ablauf
func _ev(what: String) -> void:
	if _speed < 0.4 or _ride_w > 0.5 or dead or _ch[0].w + _ch[1].w > 0.5:
		return
	var i := 0 if what == "foot_l" else 1
	footstep.emit(i == 0)


func _sp(p: StringName, v: Variant) -> void:
	if _pset.get(p) != v:
		_pset[p] = v
		tree.set(p, v)


func _process(dt: float) -> void:
	# wer tick() nicht (mehr) aufruft – Turmschütze, wartender Gefangener –, wird von selbst weiterbewegt
	if tree != null and Engine.get_process_frames() - _last_tick > 20 and is_visible_in_tree():
		_run(dt, true)


func tick(dt: float) -> void:
	_last_tick = Engine.get_process_frames()
	_run(dt, false)


func _run(dt: float, own: bool) -> void:
	if tree == null or not is_inside_tree():
		return
	_acc += dt
	_lod_t -= dt
	if _lod_t <= 0.0:
		_lod_t = 0.5
		_k = maxf(global_transform.basis.get_scale().y / AD.CHAR_SCALE, 0.01)
		var cam := get_viewport().get_camera_3d()
		_half = kind == "settler" or own or (cam != null and cam.global_position.distance_to(global_position) > FAR)
	_odd = not _odd
	if _half and _odd:
		return                       # Bewohner und ferne Figuren: nur jedes zweite Bild
	dt = _acc
	_acc = 0.0
	_t += dt
	updates += 1
	_update(dt)
	tree.advance(dt)
	skel.advance(dt)
	if extra:
		extra.position = Vector3(-0.6 + sin(_t * 1.3) * 0.15, 1.9 + sin(_t * 2.6) * 0.12, -0.2 + cos(_t * 1.1) * 0.15)
		extra.rotation.y = sin(_t * 0.9) * 0.5


func _update(dt: float) -> void:
	var k_fade := minf(1.0, dt / FADE)
	# ---- Tempo: Vorgabe, sonst gemessene Bewegung des Knotens, sonst Schätzung aus move_amount
	var gp := global_position
	var step := Vector2(gp.x - _last_gp.x, gp.z - _last_gp.z)
	var meas := step.length() / maxf(dt, 0.0001) if _have_gp else 0.0
	_last_gp = gp
	_have_gp = true
	var v := 0.0
	if speed_mps > 0.0:
		v = speed_mps
	elif move_amount > 0.02:
		v = meas if meas > 0.05 and meas < 14.0 else move_amount * 6.4
	_prev_speed = _speed
	_speed = v
	var vn := v / _k                 # Tempo, als hätte die Figur den Spielmaßstab
	var riding := ride != "" or kneel > 0.5
	# ---- Unterkörper
	var want := Vector2.ZERO
	if vn > 0.05 and not riding:
		# Gangart mit etwas Abstand zwischen Hin- und Rückschalten
		if _running and vn < V_GAIT - 0.2:
			_running = false
		elif not _running and vn > V_GAIT + 0.2:
			_running = true
		want = on_ring(move_dir, V_RUN if _running else V_WALK * minf(vn / V_SLOW, 1.0))
	else:
		_running = false
	_pos = _pos.lerp(want, minf(1.0, dt / (FADE_MOVE * 0.4)))
	if want == Vector2.ZERO and _pos.length() < 0.02:
		_pos = Vector2.ZERO
	_sp(P_MOVE, _pos)
	# Abspieltempo = Tempo ÷ Schrittlänge (Zyklen je Sekunde); im Stand läuft die Zeit normal (Atmen)
	var adv := dt
	var stride := stride_at(_pos) * _k
	if v > 0.05 and stride > 0.001:
		adv = dt * minf(v / stride, MAX_RATE) * AD.LOCO_T
	# Schritt-Ereignisse der Lauf-Clips (foot_l / foot_r), die in diesem Zeitschritt überschritten werden
	if v > 0.4:
		var a := fposmod(_tau, AD.LOCO_T)
		var b := a + adv
		for ev in AD.CLIPS["walk_f"].events:
			var te: float = ev[0]
			if (te > a and te <= b) or (te + AD.LOCO_T > a and te + AD.LOCO_T <= b):
				_ev(ev[1])
	_tau = fposmod(_tau + adv, AD.LOCO_T * 3.0)                   # idle ist genau drei Lauf-Zyklen lang
	tree.set(P_MOVE_SEEK, _tau)
	_carry_w = move_toward(_carry_w, 1.0 if carrying else 0.0, k_fade)
	_sp(P_CARRY, _carry_w)
	if _has_gait:                    # Paket H: Laufstil – im Takt der Schritte, nur beim Gehen/Rennen
		var gw := clampf(vn / V_WALK, 0.0, 1.0) * (0.0 if riding or dead else 1.0) * (1.0 - 0.5 * _aim_w)
		_gait_w = move_toward(_gait_w, gw, dt * 4.0)
		_sp(P_GAIT_W, snappedf(_gait_w, 0.02))
		if _gait_w > 0.0:
			tree.set(P_GAIT_SEEK, fposmod(_tau, AD.LOCO_T))
	if _carry_w > 0.0:
		tree.set(P_CARRY_SEEK, _tau)
	# ---- Fahrzeug
	var rk: String = RIDES.get(ride, "ride_quad")
	var was := _ride_now != ""
	if riding:
		if rk != _ride_now:
			tree.set(P_RIDE, rk)
		if not was and _t > 0.3 and not dead:
			_play("mount", false, 1.0)
		_ride_now = rk
	elif was:
		_ride_now = ""
		if not dead:
			_play("dismount", false, 1.0)
	_ride_w = move_toward(_ride_w, 1.0 if riding else 0.0, k_fade)
	_sp(P_RIDE_W, _ride_w)
	# Lenken: Richtungsänderung der Fahrt
	var sdir := step.normalized() if step.length() > 0.002 else _last_dir
	var turn := 0.0
	if _last_dir != Vector2.ZERO and sdir != Vector2.ZERO and meas > 1.0:
		turn = _last_dir.angle_to(sdir) / maxf(dt, 0.0001)      # rad/s, + = im Uhrzeigersinn von oben (x -> z)
	_last_dir = sdir
	_steer = lerpf(_steer, clampf(-turn * 0.35, -1.0, 1.0) if riding else 0.0, minf(1.0, dt * 8.0))
	_sp(P_STEER, snappedf(_steer * _ride_w, 0.02))
	# ---- Oberkörper
	_reload_left = maxf(0.0, _reload_left - dt)
	var want_aim := aiming and not dead
	# mit Waffe in der Hand bleibt der Oberkörper auch ohne Ziel in Bereitschaft (hold_*), die Waffe schlenkert nicht
	var hold_ready := _has_weapon and not riding and not dead
	if want_aim:
		_sp(P_AIM, POSES[_pose].aim)
	elif hold_ready:
		_sp(P_AIM, String(POSES[_pose].aim).replace("aim_", "hold_"))
	_aim_w = move_toward(_aim_w, 1.0 if (want_aim or hold_ready) else 0.0, k_fade)
	_sp(P_AIM_W, _aim_w)
	_spray_w = move_toward(_spray_w, 1.0 if (want_aim and _pose == "spray" and _reload_left <= 0.0) else 0.0, k_fade)
	_sp(P_SPRAY, _spray_w)
	# ---- Ganzkörper-Kanäle
	if _cheer_left > 0.0:
		_cheer_left -= dt
		if _cheer_left <= 0.0:
			stop_clip()
	for i in 3:
		var ch: Dictionary = _ch[i]
		if i < 2 and ch.on and v > 1.2 and not riding and not LOCKED.has(ch.clip) and not FULL_ONLY.has(ch.clip):
			ch.on = false             # Figur läuft los: Ganzkörper-Clip ausblenden, sonst rutschen die Füße
		if ch.on and not ch.hold:
			ch.left -= dt
			if ch.next != "" and ch.left <= 0.0:
				var nx: String = ch.next
				ch.clip = nx
				ch.next = ""
				ch.left = clip_len(nx)
				tree.set(P_ACT[i], nx)
				_sp(P_ACT_TS[i], 1.0)
			elif ch.left <= FADE_MOVE * 0.6:
				ch.on = false
		ch.w = move_toward(ch.w, 1.0 if ch.on else 0.0, dt / (FADE if ch.on else FADE_MOVE))
		_sp(P_ACT_W[i], ch.w)
	# kleine Gesten im Stand, alle 6–14 s
	var busy: bool = _ch[0].on or _ch[1].on or _ch[2].on
	if _idle_ch >= 0 and (v > 0.3 or want_aim or riding):
		if _ch[_idle_ch].on:
			_ch[_idle_ch].on = false
		_idle_ch = -1
	if v < 0.05 and not want_aim and not riding and not dead and not carrying and not busy:
		_idle_wait -= dt
		if _idle_wait <= 0.0:
			_idle_wait = _rng.randf_range(6.0, 14.0)
			var opts := ["idle_look", "idle_stretch"]
			if _has_weapon:
				opts.append("idle_weapon_check")
			if _play(opts[_rng.randi() % opts.size()], false, 1.0):
				_idle_ch = _ch_i
	# ---- Blick zum Ziel
	var look: bool = look_target != null and not dead and _ch[0].w + _ch[1].w < 0.5
	_look_w = move_toward(_look_w, 1.0 if look else 0.0, dt / 0.15)
	if look_target != null:
		_tgt.global_position = look_target
	for i in 2:
		var la: LookAtModifier3D = _looks[i]
		var w := _look_w
		if i == 0 and not want_aim:
			w *= 0.6                  # ohne Waffe im Anschlag dreht die Brust nur teilweise mit
		la.active = w > 0.01
		if la.active:
			la.influence = w
	# die Waffe richtet sich nur im Anschlag aus (nicht beim Nachladen oder Schwingen)
	_swing_left = maxf(0.0, _swing_left - dt)
	var pw := _look_w if (want_aim and _reload_left <= 0.0 and _swing_left <= 0.0) else 0.0
	_prop_w = move_toward(_prop_w, pw, dt / FADE)
	_aimer.weight = _prop_w
	if look_target != null:
		_aimer.target = look_target
	# ---- Neigung: in Kurven bis 8° nach innen, beim Bremsen 5° zurück (Beschleunigen leicht vor)
	var tilt := Vector2.ZERO          # x = zur Seite +X, y = nach vorn (+Z), in Radiant, im Raum der Figur
	if not riding and not dead and v > 1.0 and sdir != Vector2.ZERO:
		var yaw := global_rotation.y
		var fwd := Vector2(sin(yaw), cos(yaw))
		var right := Vector2(fwd.y, -fwd.x)                     # +X der Figur in Welt (x, z)
		var inward := Vector2(-sdir.y, sdir.x) * clampf(turn * 0.05, -1.0, 1.0) * deg_to_rad(8.0) * clampf(v / 4.0, 0.0, 1.0)
		var acc := lean
		if absf(lean) < 0.01:
			acc = clampf((_speed - _prev_speed) / maxf(dt, 0.001) / 25.0, -1.0, 1.0)
		var along := sdir * (deg_to_rad(5.0) * acc if acc < 0.0 else deg_to_rad(3.0) * acc)
		var w2 := inward + along
		tilt = Vector2(w2.dot(right), w2.dot(fwd))
	elif not riding and not dead and absf(lean) > 0.01:
		tilt = Vector2(0, deg_to_rad(4.0) * lean)
	_tilt = _tilt.lerp(tilt, minf(1.0, dt * 8.0))
	_pivot.rotation = Vector3(_tilt.y, 0.0, -_tilt.x)
	if not _faces.is_empty():
		_update_face(dt)


## Paket H: welches Gesicht? Clip (Jubel, Treffer, Arbeit) > gesetztes Gesicht > Blinzeln > normal.
func _update_face(dt: float) -> void:
	var want := "normal"
	_face_t = maxf(0.0, _face_t - dt)
	if _face_t <= 0.0:
		_face_set = ""
	_blink_t -= dt
	if _blink_t <= -DH.BLINK_TIME:
		_blink_t = _rng.randf_range(DH.BLINK_EVERY[0], DH.BLINK_EVERY[1])
	if _blink_t <= 0.0:
		want = "blink"
	if _face_set != "":
		want = _face_set
	for i in [2, 0, 1]:
		var ch: Dictionary = _ch[i]
		if ch.on and ch.w > 0.3:
			var cl := String(ch.clip)
			if cl.begins_with(kind + "_"):
				cl = cl.substr(kind.length() + 1)
			if DH.FACE_OF_CLIP.has(cl):
				want = String(DH.FACE_OF_CLIP[cl])
				if cl.ends_with("victory") or cl == "cheer":
					want = "joy" if _blink_t > 0.0 else "blink"
	if dead:
		want = "pain"
	_show_face(want)


# ---------------------------------------------------------------- Rechnen: Schrittlänge im BlendSpace
static func _bary(p: Vector2, a: Vector2, b: Vector2, c: Vector2) -> Vector3:
	var v0 := b - a
	var v1 := c - a
	var v2 := p - a
	var den := v0.x * v1.y - v1.x * v0.y
	if absf(den) < 0.000001:
		return Vector3(-1, -1, -1)
	var v := (v2.x * v1.y - v1.x * v2.y) / den
	var w := (v0.x * v2.y - v2.x * v0.y) / den
	return Vector3(1.0 - v - w, v, w)


## Schrittlänge je Zyklus (m, Figur im Spielmaßstab) an einer Stelle des BlendSpace "move" – dieselben Dreiecke
## und Gewichte wie im AnimationTree. Abspieltempo = Tempo ÷ Schrittlänge.
static func stride_at(p: Vector2) -> float:
	if p.length() < 0.0001:
		return 0.0
	var i := int(floor(fposmod(atan2(p.x, p.y), TAU) / (PI / 4.0))) % 8
	var j := (i + 1) % 8
	var da: Vector2 = DIRS[i]
	var db: Vector2 = DIRS[j]
	var sw: float = AD.STRIDE_WALK
	var sr: float = AD.STRIDE_RUN
	var b := _bary(p, Vector2.ZERO, da * V_RUN, db * V_RUN)
	if b.x < 0.0:                    # außerhalb des äußeren Rings: auf den Rand holen
		p /= b.y + b.z
	b = _bary(p, Vector2.ZERO, da * V_WALK, db * V_WALK)
	if b.x >= -0.0001:
		return (da * sw * b.y + db * sw * b.z).length()
	b = _bary(p, da * V_WALK, da * V_RUN, db * V_RUN)
	if b.x >= -0.0001 and b.y >= -0.0001 and b.z >= -0.0001:
		return (da * (sw * b.x + sr * b.y) + db * sr * b.z).length()
	b = _bary(p, da * V_WALK, db * V_RUN, db * V_WALK)
	return (da * sw * b.x + db * (sr * b.y + sw * b.z)).length()


## Punkt im BlendSpace in Richtung dir auf dem Ring mit Radius r (die Ringe sind Achtecke zwischen den Clips).
static func on_ring(dir: Vector2, r: float) -> Vector2:
	if dir.length() < 0.01:
		dir = Vector2(0, 1)
	dir = dir.normalized()
	var i := int(floor(fposmod(atan2(dir.x, dir.y), TAU) / (PI / 4.0))) % 8
	var b := _bary(dir, Vector2.ZERO, DIRS[i], DIRS[(i + 1) % 8])
	return dir * r / maxf(b.y + b.z, 0.5)


## Lage im BlendSpace "move" für Tempo v (m/s, Figur im Spielmaßstab) in Richtung dir (x seitwärts, y vorwärts).
static func move_point(v: float, dir := Vector2(0, 1)) -> Vector2:
	return on_ring(dir, V_RUN if v >= V_GAIT else V_WALK * minf(v / V_SLOW, 1.0))


## Abspieltempo der Lauf-Clips (Zyklen je Sekunde) für Tempo v (m/s) in Richtung dir – für Tests und Anzeige.
static func cycle_rate(v: float, dir := Vector2(0, 1)) -> float:
	var st := stride_at(move_point(v, dir))
	return minf(v / st, MAX_RATE) if st > 0.001 else 0.0
