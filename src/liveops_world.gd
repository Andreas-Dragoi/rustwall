extends Node3D
## Paket L – Live-Betrieb in der laufenden Welt (wird von main._swap an jede neue Welt gehängt):
##   Basis:      Feiertags-Deko (Kürbisse, Weihnachtsbaum, Geschenke, Schneemänner, Schnee), Fahne am Bunker,
##               Bunker-Skin (Farbe + Anbauten), Weltboss-Kampf (Zeit, Schaden zählen)
##   Expedition: Ostereier-Suche, Gebietsboss-Herausforderung der Außenbasis (Stufe 4/5)
##   überall:    Kürbishüte auf Schleimen (Halloween), Hut des Begleiters
## Alles Aussehen kommt aus Blender (blender/liveops_props.py).

const D = preload("res://src/data.gd")
const DL = preload("res://src/data_liveops.gd")
const Models = preload("res://src/models.gd")
const LO = preload("res://src/liveops.gd")
const MK = preload("res://src/mk.gd")
const Anim = preload("res://src/anim.gd")

var w: Node3D
var hol := ""
var _anims: Array = []
var _skin_anims: Array = []
var _t := 0.0
var _sec := 0.0
var _flag_node: Node3D
var _flag_id := "-"
var _hat_node: Node3D
var _hat_sig := "-"
var _hats: MultiMeshInstance3D
var _eggs: Array = []              # {n: Node3D, p: Vector2}
var _eggs_found := 0
var _snow: CPUParticles3D
var _raid_warn := 0


static func attach(world: Node3D) -> Node3D:
	var n = (load("res://src/liveops_world.gd") as GDScript).new()
	n.name = "LiveOps"
	n.w = world
	world.add_child(n)
	return n


func _ready() -> void:
	# Bilder und Tests: --lo_cos=skin:jona_marine,hat:krone (geben und anlegen), --lo_hol=halloween, --lo_event=weltboss
	if G.arg("lo_cos") != "":
		for id in G.arg("lo_cos").split(",", false):
			LO.give(id)
			LO.equip(id)
	if G.arg("lo_hol") != "":
		LO.set_holiday_force(G.arg("lo_hol"))
	if G.arg("lo_event") != "":
		LO.force_event = G.arg("lo_event")
	LO.set_world_flags(w)
	hol = LO.holiday()
	# erst bauen, wenn die Welt fertig aufgebaut ist (Basis und Expedition bauen in _ready)
	_setup.call_deferred()


func _setup() -> void:
	if not is_instance_valid(w):
		return
	if hol == "halloween":
		_make_hats()
	if w.get("mode") != "exp" and w.get("bunker_node") is Node3D:
		_decorate_base()
	elif w.get("mode") == "exp" and hol == "ostern" and String(w.get("mission")) != "befreiung":
		_hide_eggs()
	_update_skin()
	_update_flag()
	_update_hat()


## Aussehen (jedes Bild): Animationen der Deko, Kürbishüte, Schnee folgt dem Helden.
func _process(dt: float) -> void:
	if not is_instance_valid(w):
		return
	_t += dt
	if not _anims.is_empty() or not _skin_anims.is_empty():
		Anim.tick(_anims, _t, dt)
		Anim.tick(_skin_anims, _t, dt)
	if _hats != null:
		_place_hats()
	if _snow != null and w.get("hero") != null:
		_snow.global_position = w.hero.global_position + Vector3(0, 16, -4)


## Spielablauf (im Takt der Spielwelt): Weltboss-Zeit, Eier, Skins/Fahne/Hut, Außenbasis-Herausforderung.
func _physics_process(dt: float) -> void:
	if not is_instance_valid(w):
		return
	_tick_raid(dt)
	if not _eggs.is_empty():
		_tick_eggs()
	_sec -= dt
	if _sec <= 0.0:
		_sec = 1.0
		_update_skin()
		_update_flag()
		_update_hat()
		if w.get("mode") == "exp":
			LO.check_outpost(w)


# ================================================================= Basis: Feiertags-Deko
## Freie Stellen im Ring um den Bunker (fest je Basis, nicht auf Gebäuden oder Hindernissen).
func _spots(n: int, r0: float, r1: float, seed_txt: String) -> Array:
	var out: Array = []
	var bn = w.bunker_node
	var c: Vector2 = bn.mid
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(seed_txt)
	var tries := 0
	while out.size() < n and tries < n * 40:
		tries += 1
		var a := rng.randf() * TAU
		var r := rng.randf_range(r0, r1)
		var p := c + Vector2(cos(a), sin(a)) * r
		if w.field.is_solid(p) or w.field.structure_at(p) != null or w.field.blocks_player(p):
			continue
		var ok := true
		for q in out:
			if (q as Vector2).distance_to(p) < 2.4:
				ok = false
				break
		if ok:
			out.append(p)
	return out


func _put(model: String, p: Vector2, yaw := 0.0, s := 1.0) -> Node3D:
	if not Models.has_glb(model):
		return null
	var n := Models.glb(model)
	n.position = Vector3(p.x, 0, p.y)
	n.rotation.y = yaw
	n.scale = Vector3.ONE * s
	add_child(n)
	_anims.append_array(Anim.collect(n, false))
	return n


func _decorate_base() -> void:
	var bn = w.bunker_node
	var r: float = bn.radius
	match hol:
		"halloween":
			var sp := _spots(10, r + 3.0, r + 16.0, "rw-hw")
			for i in sp.size():
				_put("lo_pumpkins" if i % 3 == 0 else "lo_pumpkin", sp[i], float((i % 3) - 1) * 0.4, 1.6 if i % 3 == 0 else 1.4)
		"weihnachten":
			var front: Vector2 = bn.mid + Vector2(r + 3.5, r + 2.5)
			if not w.field.blocks_player(front):
				_put("lo_xmas_tree", front, 0.3, 1.25)
				_put("lo_gifts", front + Vector2(-1.8, 1.2), 0.4)
				_put("lo_gift", front + Vector2(1.4, 1.5), -0.5, 0.9)
			var sp2 := _spots(14, r + 3.0, r + 22.0, "rw-xm")
			for i in sp2.size():
				_put("lo_snowman" if i % 5 == 0 else "lo_snowpile", sp2[i], float(i) * 2.1, 1.0 if i % 5 == 0 else 0.8 + 0.1 * (i % 4))
			_make_snow()
		"ostern":
			var sp3 := _spots(6, r + 3.0, r + 14.0, "rw-os")
			for i in sp3.size():
				_put("lo_egg_%d" % (i % 4 + 1), sp3[i], float(i), 1.2)


func _make_snow() -> void:
	_snow = CPUParticles3D.new()
	_snow.amount = 420
	_snow.lifetime = 7.0
	_snow.preprocess = 7.0
	_snow.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_snow.emission_box_extents = Vector3(34, 1, 26)
	_snow.direction = Vector3(0.15, -1, 0)
	_snow.spread = 12.0
	_snow.gravity = Vector3(0, -0.6, 0)
	_snow.initial_velocity_min = 1.6
	_snow.initial_velocity_max = 2.6
	_snow.scale_amount_min = 0.7
	_snow.scale_amount_max = 1.4
	var q := SphereMesh.new()                      # runde Flocken (kein Bild nötig)
	q.radius = 0.055
	q.height = 0.11
	q.radial_segments = 6
	q.rings = 3
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(1, 1, 1)
	q.material = m
	_snow.mesh = q
	add_child(_snow)


# ================================================================= Halloween: Kürbishüte auf den Schleimen
func _make_hats() -> void:
	if not Models.has_glb("lo_pumpkin_hat"):
		return
	var mesh := Models.glb_mesh("lo_pumpkin_hat", "body")
	if mesh == null:
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = DL.PUMPKIN_HATS
	mm.visible_instance_count = 0
	_hats = MultiMeshInstance3D.new()
	_hats.multimesh = mm
	_hats.material_override = MK.mat_lin()
	_hats.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_hats)


func _place_hats() -> void:
	var h = w.get("horde")
	var mm := _hats.multimesh
	if h == null:
		mm.visible_instance_count = 0
		return
	var n := 0
	for e in h.list:
		if n >= DL.PUMPKIN_HATS:
			break
		if e.st == 2 or e.hide or e.fly or e.under:
			continue
		var def: Dictionary = D.ENEMIES[e.t]
		if String(def.family) != "schleim" or String(def.role) == "boss" or e.sc > 2.2:
			continue
		var top: float = h.elite_fx._height(h, e) if h.get("elite_fx") != null else 1.2 * e.sc     # wie die Elite-Krone
		var s: float = clampf(top * 0.7, 0.55, 2.4)
		var y: float = top - 0.1 * s
		var b := Basis(Vector3.UP, e.yaw).scaled(Vector3(s, s, s))
		mm.set_instance_transform(n, Transform3D(b, Vector3(e.p.x, y, e.p.y)))
		n += 1
	mm.visible_instance_count = n


# ================================================================= Bunker-Skin, Fahne, Begleiter-Hut
func _update_skin() -> void:
	var bn = w.get("bunker_node")
	if not is_instance_valid(bn) or not (bn is Node3D) or bn.get("model") == null or not is_instance_valid(bn.model):
		return
	var id := LO.equipped("bskin")
	if String(bn.model.get_meta("lo_skin", "")) != id:
		_skin_anims = LO.apply_bunker_skin(bn.model, id)


func _update_flag() -> void:
	var bn = w.get("bunker_node")
	if not is_instance_valid(bn) or not (bn is Node3D) or w.get("mode") == "exp":
		return
	var id := LO.equipped("flag")
	if id == _flag_id:
		return
	_flag_id = id
	if _flag_node != null:
		for a in _anims.duplicate():
			if is_instance_valid(a[1]) and _flag_node.is_ancestor_of(a[1]):
				_anims.erase(a)
		_flag_node.queue_free()
		_flag_node = null
	if id == "":
		return
	var r: float = bn.radius
	var p: Vector2 = bn.mid + Vector2(-(r + 1.0), r + 1.0)
	_flag_node = _put("lo_flag_" + LO.cos_key(id), p, 0.5, 1.15)


func _update_hat() -> void:
	var c = w.get("companion")
	if c == null or not is_instance_valid(c) or c.get("model") == null or not is_instance_valid(c.model):
		return
	var id := LO.equipped("hat")
	var sig := "%s|%d" % [id, c.model.get_instance_id()]
	if sig == _hat_sig:
		return
	_hat_sig = sig
	if _hat_node != null and is_instance_valid(_hat_node):
		_hat_node.queue_free()
	_hat_node = null
	if id == "":
		return
	_hat_node = put_hat(c.model, id)
	if _hat_node != null:
		_anims.append_array(Anim.collect(_hat_node, false))


## Setzt den Hut auf den Kopf (sonst Rumpf) eines Begleiter-Modells. Auch für die Vorschau der Garderobe.
static func put_hat(model: Node3D, id: String) -> Node3D:
	var mname := "lo_hat_" + LO.cos_key(id)
	if model == null or not Models.has_glb(mname):
		return null
	var holder: Node3D = Models.find(model, "head")
	if holder == null:
		holder = Models.find(model, "body")
	if holder == null:
		holder = model
	var mi: MeshInstance3D = holder as MeshInstance3D
	if mi == null:
		for ch in holder.find_children("*", "MeshInstance3D", true, false):
			mi = ch
			break
	var top := Vector3(0, 0.5, 0)
	var width := 0.5
	if mi != null and mi.mesh != null:
		var bb: AABB = mi.get_aabb()
		var xf: Transform3D = holder.global_transform.affine_inverse() * mi.global_transform if holder.is_inside_tree() else (Transform3D.IDENTITY if mi == holder else mi.transform)
		var c: Vector3 = xf * (bb.position + Vector3(bb.size.x * 0.5, bb.size.y, bb.size.z * 0.5))
		top = c
		width = maxf(0.15, minf(bb.size.x, bb.size.z))
	var hat := Models.glb(mname)
	hat.name = "LoHat"
	var k := clampf(width * 0.75 / 0.5, 0.25, 2.5)
	hat.scale = Vector3.ONE * k
	hat.position = top - Vector3(0, 0.04 * k, 0)
	holder.add_child(hat)
	return hat


# ================================================================= Weltboss: Zeit und Schaden
func _tick_raid(dt: float) -> void:
	if w.get("mode") != "practice" or not (w.get("flood") is Dictionary) or not w.flood.get("raid", false):
		return
	if not w.running or w.ended:
		return
	var t: float = float(w.get_meta("raid_t", 0.0)) + dt
	w.set_meta("raid_t", t)
	var b = w.horde.boss
	if b != null:
		LO.raid_dmg = maxf(LO.raid_dmg, b.mhp - maxf(b.hp, 0.0))
	var left := DL.BOSS_TIME - t
	if left <= 30.0 and _raid_warn == 0:
		_raid_warn = 1
		P.toast.emit("Noch 30 Sekunden!")
	elif left <= 10.0 and _raid_warn == 1:
		_raid_warn = 2
		P.toast.emit("Noch 10 Sekunden!")
	if left <= 0.0:
		Sfx.play("worldboss_retreat", -2.0)
		P.toast.emit("Der Leviathan taucht ab. Schaden: %s" % LO._fmt(int(LO.raid_dmg)))
		w.horde.clear()                 # Welle leer -> base_world beendet den Kampf (LO.raid_result)


func raid_left() -> float:
	return DL.BOSS_TIME - float(w.get_meta("raid_t", 0.0))


# ================================================================= Ostern: Eiersuche in der Expedition
func _hide_eggs() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("rw-eggs-%d-%d" % [int(w.area), P.day_index()])
	var tries := 0
	var lim := 100.0
	while _eggs.size() < DL.EGGS_PER_EXP and tries < 600:
		tries += 1
		var a := rng.randf() * TAU
		var r := rng.randf_range(24.0, lim)
		var p := Vector2(cos(a), sin(a)) * r
		if w.field.blocks_player(p) or w.field.is_solid(p):
			continue
		var ok := true
		for e in _eggs:
			if (e.p as Vector2).distance_to(p) < 18.0:
				ok = false
				break
		if not ok:
			continue
		var n := _put("lo_egg_%d" % (_eggs.size() % 4 + 1), p, rng.randf() * TAU, 1.3)
		if n != null:
			_eggs.append({"n": n, "p": p})
	if not _eggs.is_empty():
		P.toast.emit.call_deferred("Ostern: %d bunte Eier sind in diesem Gebiet versteckt!" % _eggs.size())


func _tick_eggs() -> void:
	var h = w.get("hero")
	if h == null or not h.alive:
		return
	var hp: Vector2 = h.pos2()
	for e in _eggs.duplicate():
		if hp.distance_to(e.p) < DL.EGG_RADIUS:
			_eggs.erase(e)
			_eggs_found += 1
			var n: Node3D = e.n
			if G.fx != null:
				G.fx.confetti(n.global_position + Vector3(0, 0.6, 0), 4)
			for a in _anims.duplicate():
				if is_instance_valid(a[1]) and n.is_ancestor_of(a[1]):
					_anims.erase(a)
			n.queue_free()
			Sfx.play("egg_found", -3.0)
			P.toast.emit("Osterei gefunden! (%d von %d)" % [_eggs_found, _eggs_found + _eggs.size()])
			LO.egg_found(_eggs.is_empty())


func eggs_left() -> int:
	return _eggs.size()


## Tests: Held direkt zum nächsten Ei setzen.
func egg_pos(i := 0) -> Vector2:
	return _eggs[i].p if i < _eggs.size() else Vector2.ZERO
