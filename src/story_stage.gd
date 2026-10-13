extends Node3D
## V6 Paket E – Bühne der Zwischenszenen: eine kleine eigene 3D-Welt des Gebiets (in einem SubViewport mit eigener Welt).
## Boden in den Farben des Gebiets, Bäume und Felsen des Gebiets, das Wahrzeichen hinten, dazu die Darsteller
## (Helden, Bewohner, Gerettete, Boss, Schleimlinge, das Sternherz) aus DG.SCENES[*].cast. Kamera mit weicher Fahrt
## zwischen den Posen aus DG.SHOTS. Alles Aussehen kommt aus Blender-Modellen (Models.glb, Humanoid).
##
## build(area, cast)   aufbauen        shot(name)   neue Kamerapose anfahren      act(rolle, clip)   Darsteller spielt etwas
## tick(dt)            jedes Bild      actor_count()  Zahl der Darsteller (Tests)

const D = preload("res://src/data.gd")
const DG = preload("res://src/data_geschichte.gd")
const DW = preload("res://src/data_welt.gd")
const Models = preload("res://src/models.gd")
const Humanoid = preload("res://src/humanoid.gd")
const Vat = preload("res://src/vat.gd")
const BossFig = preload("res://src/boss_fig.gd")
const Anim = preload("res://src/anim.gd")
const MK = preload("res://src/mk.gd")
const Story = preload("res://src/story.gd")

const LM_POS := Vector3(0, 0, -14)
const ROCKS := {"frost": "p_rock_snow_%d", "vulkan": "p_rock_lava_%d", "kueste": "p_beach_rock_%d", "stadt": "p_st_rubble_%d"}

var area := 0
var cam: Camera3D
var sun: DirectionalLight3D
var env: Environment
var actors: Dictionary = {}          # rolle -> [{n, kind, base, ...}]
var humans: Array = []               # alle Humanoiden (tick)
var _anims: Array = []
var _t := 0.0
var _cur := [Vector3.ZERO, 0.0, 0.3, 20.0]      # Ziel, Drehung, Neigung, Abstand (geglättet)
var _want := [Vector3.ZERO, 0.0, 0.3, 20.0]
var _drift := 0.0
var _rng := RandomNumberGenerator.new()
var _fx: Array = []                  # laufende Bewegungen {n, kind, t, ...}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


# ================================================================= Aufbau
func build(a: int, cast: Array) -> void:
	area = clampi(a, 0, D.AREAS.size() - 1)
	var ad: Dictionary = D.AREAS[area]
	var ak := String(ad.key)
	_rng.seed = hash("story-stage|%s" % ak)
	_environment(ad)
	_ground(ad)
	_scenery(ad, ak)
	for c in cast:
		_add_actor(c)
	_anims = Anim.collect(self, false)
	cam = Camera3D.new()
	cam.fov = 42.0
	cam.near = 0.2
	cam.far = 220.0
	add_child(cam)
	cam.current = true


func _environment(ad: Dictionary) -> void:
	var we := WorldEnvironment.new()
	env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	var fog: Color = ad.fog
	env.background_color = fog.lerp(Color("7FB6EA"), 0.45)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.82, 0.86, 1.0)
	env.ambient_light_energy = 0.7
	env.fog_enabled = true
	env.fog_light_color = fog
	env.fog_density = 0.004
	env.fog_sky_affect = 0.0
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	we.environment = env
	add_child(we)
	sun = DirectionalLight3D.new()
	sun.rotation = Vector3(deg_to_rad(-50.0), deg_to_rad(-35.0), 0)
	sun.light_color = ad.sun
	sun.light_energy = 1.3
	sun.shadow_enabled = not G.web_mobile() and G.quality() >= 1
	sun.directional_shadow_max_distance = 70.0
	sun.shadow_bias = 0.06
	sun.shadow_normal_bias = 1.5
	sun.shadow_opacity = 0.55
	add_child(sun)


func _ground(ad: Dictionary) -> void:
	var g := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(140, 140)
	g.mesh = pm
	var m := StandardMaterial3D.new()
	m.albedo_color = ad.ground
	m.roughness = 1.0
	g.material_override = m
	add_child(g)
	# Flecken in der zweiten Bodenfarbe und ein Weg zum Wahrzeichen
	var m2 := StandardMaterial3D.new()
	m2.albedo_color = ad.ground2
	m2.roughness = 1.0
	for i in 14:
		var d := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		var r := _rng.randf_range(2.0, 6.0)
		cm.top_radius = r
		cm.bottom_radius = r
		cm.height = 0.02
		cm.radial_segments = 14
		d.mesh = cm
		d.material_override = m2
		var a := _rng.randf() * TAU
		var rr := _rng.randf_range(4.0, 30.0)
		d.position = Vector3(cos(a) * rr, 0.01 + i * 0.001, sin(a) * rr)
		d.scale = Vector3(1.0, 1.0, _rng.randf_range(0.5, 1.0))
		d.rotation.y = _rng.randf() * TAU
		d.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(d)
	var path := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(2.6, 0.03, 30.0)
	path.mesh = bm
	var mp := StandardMaterial3D.new()
	mp.albedo_color = ad.path
	mp.roughness = 1.0
	path.material_override = mp
	path.position = Vector3(-1.2, 0.02, -2.0)
	path.rotation.y = 0.08
	path.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(path)
	if String(ad.key) == "kueste" or String(ad.key) == "krater":
		var sea := MeshInstance3D.new()
		var sp := PlaneMesh.new()
		sp.size = Vector2(160, 60)
		sea.mesh = sp
		var ms := StandardMaterial3D.new()
		ms.albedo_color = Color("4FA3D9") if String(ad.key) == "kueste" else Color("8EDB3A")
		ms.roughness = 0.2
		ms.metallic_specular = 0.8
		sea.material_override = ms
		sea.position = Vector3(0, 0.04, -52.0)
		add_child(sea)
	if String(ad.key) == "vulkan":
		for i in 4:
			var lv := MeshInstance3D.new()
			var lb := BoxMesh.new()
			lb.size = Vector3(1.2, 0.05, _rng.randf_range(14.0, 24.0))
			lv.mesh = lb
			lv.material_override = MK.glow(Color("FF6A1E"))
			lv.position = Vector3(_rng.randf_range(-20.0, 20.0), 0.03, _rng.randf_range(-30.0, -8.0))
			lv.rotation.y = _rng.randf_range(-0.6, 0.6)
			lv.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(lv)


func _scenery(ad: Dictionary, ak: String) -> void:
	# Wahrzeichen hinten in der Mitte
	var lm: Dictionary = DW.LANDMARKS.get(ak, {})
	if not lm.is_empty() and Models.has_glb(String(lm.model)):
		var n := Models.glb(String(lm.model))
		n.position = LM_POS
		add_child(n)
		# so groß wie im Gebiet, aber nicht breiter als die Bühne (die Kamera steht sonst im Vulkan)
		var bb := _bounds(n)
		var k := DW.LANDMARK_SCALE * 1.2
		if bb.size.x > 0.01 and bb.size.z > 0.01:
			k = minf(k, minf(11.0 / maxf(bb.size.x, bb.size.z), 10.0 / maxf(bb.size.y, 0.01)))
		n.scale = Vector3.ONE * k
	# Bäume ringsum (nicht vor der Kamera), Felsen dazwischen
	var tree := String(ad.tree)
	var kinds: Array = []
	for i in range(1, 4):
		if Models.has_glb("p_tree_%s_%d" % [tree, i]):
			kinds.append("p_tree_%s_%d" % [tree, i])
	var rock_fmt := String(ROCKS.get(ak, "p_rock_%d"))
	var rocks: Array = []
	for i in range(1, 4):
		if Models.has_glb(rock_fmt % i):
			rocks.append(rock_fmt % i)
	var placed: Array = [Vector2(LM_POS.x, LM_POS.z)]
	_views()
	var n_trees := 46 if not G.web_mobile() else 26
	var tries := 0
	while placed.size() < n_trees and tries < 600 and not kinds.is_empty():
		tries += 1
		var a := _rng.randf_range(-PI, PI)
		var r := _rng.randf_range(9.0, 34.0)
		var p := Vector2(sin(a) * r, -cos(a) * r)
		if p.y > 3.0 and absf(p.x) < 14.0:
			continue                         # vor der Gruppe frei lassen (Kamera)
		if absf(p.x) < 6.0 and p.y > -9.0:
			continue                         # Platz für die Darsteller
		if absf(p.x - LM_POS.x) < 6.0 and absf(p.y - LM_POS.z) < 6.0:
			continue
		if _in_view(p, 2.8):
			continue
		var ok := true
		for q in placed:
			if p.distance_to(q) < 3.2:
				ok = false
				break
		if not ok:
			continue
		placed.append(p)
		var tn := Models.glb(String(kinds[_rng.randi() % kinds.size()]))
		tn.position = Vector3(p.x, 0, p.y)
		tn.rotation.y = _rng.randf() * TAU
		tn.scale = Vector3.ONE * _rng.randf_range(0.9, 1.35)
		add_child(tn)
	for i in 12:
		if rocks.is_empty():
			break
		var a2 := _rng.randf_range(-PI, PI)
		var r2 := _rng.randf_range(6.0, 22.0)
		var p2 := Vector2(sin(a2) * r2, -cos(a2) * r2)
		if absf(p2.x) < 5.0 and p2.y > -7.0:
			continue
		if _in_view(p2, 2.0):
			continue
		var rn := Models.glb(String(rocks[_rng.randi() % rocks.size()]))
		rn.position = Vector3(p2.x, 0, p2.y)
		rn.rotation.y = _rng.randf() * TAU
		rn.scale = Vector3.ONE * _rng.randf_range(0.8, 1.6)
		add_child(rn)


## Umriss eines Modells in seinem eigenen Bezug (alle Meshes zusammen).
func _bounds(n: Node3D) -> AABB:
	var out := AABB()
	var first := true
	var inv := n.global_transform.affine_inverse()
	for vi in n.find_children("*", "VisualInstance3D", true, false):
		var b: AABB = (inv * (vi as VisualInstance3D).global_transform) * (vi as VisualInstance3D).get_aabb()
		out = b if first else out.merge(b)
		first = false
	return out


## Sichtlinien aller Kamerposen (Kamera -> Ziel, auf dem Boden): dort stehen keine Bäume und Felsen.
var _sight: Array = []


func _views() -> void:
	_sight.clear()
	for k in DG.SHOTS:
		var s: Array = DG.SHOTS[k]
		var tgt: Vector3 = s[0]
		var yaw := float(s[1])
		var dist := float(s[3])
		for dy in [0.0, 0.25]:                   # die Kamera dreht sich während einer Tafel langsam weiter
			var c := Vector2(tgt.x + sin(yaw + dy) * dist, tgt.z + cos(yaw + dy) * dist)
			_sight.append([c, Vector2(tgt.x, tgt.z)])


func _in_view(p: Vector2, r: float) -> bool:
	for sg in _sight:
		var a: Vector2 = sg[0]
		var b: Vector2 = sg[1]
		if p.distance_to(a) < r + 3.0:
			return true
		var ab := b - a
		var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.001), 0.0, 1.0)
		if p.distance_to(a + ab * t) < r:
			return true
	return false


# ================================================================= Darsteller
func _hero_keys() -> Array:
	var lead := String(P.d.get("hero_sel", "jona"))
	if not D.HEROES.has(lead) or not P.hero_unlocked(lead):
		lead = "jona"
	var out: Array = [lead]
	for hk in D.HERO_ORDER:
		if hk != lead and P.hero_unlocked(hk):
			out.append(hk)
	return out


func _add_actor(c: Array) -> void:
	var role := String(c[0])
	var pos := Vector3(float(c[1]), 0, float(c[2]))
	var yaw := float(c[3])
	var clip := String(c[4]) if c.size() > 4 else ""
	var extra = c[5] if c.size() > 5 else ""
	var heroes := _hero_keys()
	match role:
		"lead", "ally", "ally2":
			var i := ["lead", "ally", "ally2"].find(role)
			if i < heroes.size():
				_human(role, String(heroes[i]), pos, yaw, clip)
		"jona":
			_human(role, "jona", pos, yaw, clip)
		"settler":
			_human(role, "settler", pos, yaw, clip)
		"haendlerin", "forscher", "schmied":
			if String(extra) == "trapped":
				_trapped(role, pos, yaw)
			elif Story.rescued(role) or G.arg("story_all") != "":
				_human(role, role, pos, yaw, clip)
		"boss":
			_boss(pos, yaw, String(extra) == "down")
		"slime":
			_slimes(pos, int(extra) if str(extra).is_valid_int() else 4)
		"heart":
			var hn := Models.glb("st_heart_red" if String(extra) == "red" and Models.has_glb("st_heart_red") else "st_heart") if Models.has_glb("st_heart") else Node3D.new()
			hn.position = pos + Vector3(0, 3.0 if String(extra) != "rise" else 0.4, 0)
			hn.scale = Vector3.ONE * 1.8
			add_child(hn)
			_reg(role, {"n": hn, "kind": "heart", "base": hn.position})
		"prop":
			if Models.has_glb(String(extra)):
				var pn := Models.glb(String(extra))
				pn.position = pos
				pn.rotation.y = yaw
				add_child(pn)
				_reg(role, {"n": pn, "kind": "prop", "base": pos})


func _reg(role: String, e: Dictionary) -> void:
	if not actors.has(role):
		actors[role] = []
	actors[role].append(e)


func _human(role: String, kind: String, pos: Vector3, yaw: float, clip: String) -> Node3D:
	var h := Humanoid.new()
	add_child(h)
	var look := {"kind": kind}
	if D.HEROES.has(kind):
		look["skin"] = preload("res://src/liveops.gd").hero_skin(kind)
	h.build(look)
	h.scale = Vector3.ONE * D.CHAR_SCALE * (0.92 if kind == "settler" else 1.0)
	h.position = pos
	h.rotation.y = yaw
	h.tick(0.016)
	humans.append(h)
	var e := {"n": h, "kind": "human", "base": pos, "loop": clip}
	_reg(role, e)
	if clip != "":
		_play(h, clip, true)
	return h


func _trapped(role: String, pos: Vector3, yaw: float) -> void:
	var r: Dictionary = DG.RESCUES[role]
	match String(r.kind):
		"camp":
			if Models.has_glb("st_camp"):
				var cp := Models.glb("st_camp")
				cp.position = pos
				cp.scale = Vector3.ONE * 0.8
				add_child(cp)
			var cage := Models.cage()
			cage.position = pos
			add_child(cage)
			var h := _human(role, role, pos, yaw, "sit")
			h.set_face("pain", 999.0)
		"cocoon":
			if Models.has_glb("st_cocoon"):
				var cc := Models.glb("st_cocoon")
				cc.position = pos
				cc.rotation.y = yaw
				add_child(cc)
		"ice":
			var h2 := _human(role, role, pos, yaw, "")
			h2.set_face("strain", 999.0)
			if Models.has_glb("st_icecage"):
				var ic := Models.glb("st_icecage")
				ic.position = pos
				add_child(ic)


func _boss(pos: Vector3, yaw: float, down: bool) -> void:
	var key := String(D.AREA_BOSS[area])
	var bi: Dictionary = Vat.boss_info(key)
	var n: Node3D
	if not bi.is_empty():
		var fig := BossFig.new()
		fig.setup(key, bi)
		fig.process_mode = Node.PROCESS_MODE_ALWAYS
		n = fig
		if down and fig.has_clip("death"):
			fig.cur = "death"
			fig.once = true
			fig.t = fig.clip_len("death") - 0.01
			fig._seek()
		else:
			fig.auto = true
	elif Vat.has(key):
		n = Vat.preview(key, "idle")
		if down:
			n.scale = Vector3(1.5, 0.16, 1.5)        # geplatzt: platt wie eine Pfütze
			n.position = pos
			add_child(n)
			_reg("boss", {"n": n, "kind": "boss", "base": pos, "down": true})
			return
	else:
		return
	n.position = pos
	n.rotation.y = yaw
	add_child(n)
	_fit_height(n, BOSS_MAX_H)
	if down and n.has_method("_seek"):
		n.call("_seek")                       # Todes-Pose erst jetzt anwenden: vor add_child greift der AnimationPlayer noch nicht
		n.call_deferred("_seek")
	_reg("boss", {"n": n, "kind": "boss", "base": pos, "down": down})


const BOSS_MAX_H := 4.2                       # größere Bosse werden für die Bühne verkleinert, sonst schneidet der Kinobalken den Kopf ab


## Verkleinert n gleichmäßig, wenn seine Meshes zusammen höher als max_h sind.
func _fit_height(n: Node3D, max_h: float) -> void:
	var box := AABB()
	var first := true
	for m in n.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		if mi.mesh == null:
			continue
		var b: AABB = n.global_transform.affine_inverse() * mi.global_transform * mi.get_aabb()
		box = b if first else box.merge(b)
		first = false
	if not first and box.size.y > max_h:
		n.scale *= max_h / box.size.y


func _slimes(pos: Vector3, count: int) -> void:
	var fam := String(D.AREA_FAMILY[area])
	var keys: Array = []
	for d in D.ENEMIES:
		if String(d.family) == fam and String(d.role) in ["mass", "fast"] and Vat.has(String(d.key)):
			keys.append(String(d.key))
	if keys.is_empty():
		return
	for i in count:
		var a := TAU * i / float(count) + _rng.randf() * 0.5
		var r := 0.6 + 1.4 * _rng.randf()
		var n := Vat.preview(String(keys[i % keys.size()]), "idle")
		n.position = pos + Vector3(cos(a) * r, 0, sin(a) * r)
		n.rotation.y = _rng.randf_range(-0.5, 0.5)
		add_child(n)
		_reg("slime", {"n": n, "kind": "slime", "base": n.position})


func actor_count() -> int:
	var n := 0
	for k in actors:
		n += (actors[k] as Array).size()
	return n


# ================================================================= Handlung
func _play(h: Node3D, clip: String, hold: bool) -> void:
	match clip:
		"cheer":
			h.cheer(2.2)
		"victory":
			h.victory(2.5)
		"":
			pass
		_:
			if not h.play(clip, hold or clip in ["sit", "warm_hands", "hammer", "eat", "pay", "sleep"]):
				h.cheer(1.5)


func act(role: String, clip: String) -> void:
	var roles: Array = [role]
	if role == "all":
		roles = actors.keys()
	for r in roles:
		for e in actors.get(r, []):
			match String(e.kind):
				"human":
					if role == "all" and String(e.get("loop", "")) in ["sit", "warm_hands", "hammer", "eat", "pay"]:
						continue
					_play(e.n, clip, false)
				"boss":
					var n: Node3D = e.n
					if clip == "flee":
						_fx.append({"n": n, "kind": "flee", "t": 0.0, "from": n.position, "s0": n.scale.x})
					elif n.has_method("play") and not bool(e.get("down", false)):
						n.play(clip)
				"heart":
					_fx.append({"n": e.n, "kind": clip, "t": 0.0, "from": (e.n as Node3D).position, "s0": (e.n as Node3D).scale.x})


## Kamera: neue Pose anfahren (Name aus DG.SHOTS); snap = sofort dort sein.
func shot(name: String, snap := false) -> void:
	var s: Array = DG.SHOTS.get(name, DG.SHOTS.wide)
	_want = [s[0], float(s[1]), float(s[2]), float(s[3])]
	_drift = 0.0
	if snap:
		_cur = [s[0], float(s[1]) - 0.12, float(s[2]), float(s[3]) * 1.15]
		_apply_cam()


func _apply_cam() -> void:
	if cam == null:
		return
	var tgt: Vector3 = _cur[0]
	var yaw: float = float(_cur[1]) + _drift
	var pitch: float = float(_cur[2])
	var dist: float = float(_cur[3])
	var off := Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)) * dist
	var p := tgt + off
	p.y = maxf(p.y, 0.4)
	cam.global_position = p
	if p.distance_to(tgt) > 0.01:
		cam.look_at(tgt, Vector3.UP)


func tick(dt: float) -> void:
	_t += dt
	_drift += dt * 0.025
	var k := 1.0 - exp(-dt * 1.7)
	_cur[0] = (_cur[0] as Vector3).lerp(_want[0], k)
	for i in [1, 2, 3]:
		_cur[i] = lerpf(float(_cur[i]), float(_want[i]), k)
	_apply_cam()
	for h in humans:
		if is_instance_valid(h):
			h.tick(dt)
	Anim.tick(_anims, _t, dt)
	# Sternherz schwebt; Bewegungen der Handlung
	for e in actors.get("heart", []):
		var hn: Node3D = e.n
		if not _moving(hn):
			hn.position.y = (e.base as Vector3).y + sin(_t * 1.8) * 0.18
			hn.rotation.y += dt * 0.6
	for f in _fx.duplicate():
		f.t = float(f.t) + dt
		var n: Node3D = f.n
		if not is_instance_valid(n):
			_fx.erase(f)
			continue
		var q := clampf(float(f.t) / 2.2, 0.0, 1.0)
		var from: Vector3 = f.from
		match String(f.kind):
			"flee":
				n.position = from + Vector3(0, q * 1.5, -q * 4.0)
				n.scale = Vector3.ONE * float(f.s0) * maxf(0.01, 1.0 - q)
			"gone":
				n.position = from + Vector3(q * 6.0, q * 9.0, -q * 14.0)
				n.scale = Vector3.ONE * float(f.s0) * maxf(0.01, 1.0 - q * 0.9)
			"rise":
				n.position = from.lerp(Vector3(from.x, 3.2, from.z), q)
			"circle":
				var a := float(f.t) * 1.8
				n.position = Vector3(sin(a) * 3.2, 2.6 + sin(a * 2.0) * 0.3, cos(a) * 3.2 - 1.0)
		if q >= 1.0 and String(f.kind) != "circle":
			_fx.erase(f)


func _moving(n: Node3D) -> bool:
	for f in _fx:
		if f.n == n:
			return true
	return false
