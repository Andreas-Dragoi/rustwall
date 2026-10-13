extends "res://src/world.gd"
## V6 Paket M – Höhle (Dungeon-Abschnitt) der Expedition, eine eigene kleine Welt.
##
## Aufbau: 3–5 Räume (14 × 14 m) als Kette auf einem Raster, verbunden durch Gänge (6 m). Alle Teile aus Blender je Thema
## (cv_<thema>_floor/_hall/_wall_1/_wall_2/_rock/_deco_1/_deco_2, cv_torch, cv_exit, cv_<thema>_ore): wurzel (Forst, Sumpf),
## sand (Staubebene, Schrottküste), eis (Frostpass), glut (Schleimkrater, Vulkaninsel). Dunkel: kaum Umgebungslicht,
## Fackeln mit Lichtern, der Held trägt ein Licht. Gegner der Gebietsfamilie bewachen jeden Raum außer dem ersten;
## im letzten Raum stehen Truhe und Erzader, dazu ein Elite-Wächter. Rückweg: Leiter im ersten Raum (1 s draufstellen).
##
## Die Höhle gehört zur Expedition: diese wird beim Betreten aus dem Baum genommen (sie ruht, nichts geht verloren) und beim
## Verlassen wieder eingehängt (swap_in / swap_out). Rucksack, Feldmünzen, Wiedereinstiege und Depot sind die der Expedition
## (Eigenschaften unten leiten weiter); besiegte Gegner zählen dort mit. Für hud.gd verhält sich die Höhle wie eine Expedition
## (mode = "exp": Rucksack, Karte, Pfeil am Rand, Heimkehr-Knopf bleibt aus).

const DM = preload("res://src/data_modi.gd")
const Modi = preload("res://src/modi.gd")
const Backpack = preload("res://src/backpack.gd")
const CD = preload("res://src/companion_data.gd")

signal state_changed
signal battle_ended

const HALFM := 50.0                   # für die Übersichtskarte (hud.MiniMap)

var ex: Node3D                         # die ruhende Expedition
var mx: Node3D                         # modi_exp.gd der Expedition
var idx := 0
var theme_key := "wurzel"
var tdef: Dictionary
var adef: Dictionary
var area := 0
var mission := "expedition"
var result := {}
var rooms: Array = []                  # {c: Vector2, i, guards}
var exit_p := Vector2.ZERO
var chest_p := Vector2.ZERO
var ore_p := Vector2.ZERO
var chest_open := false
var ore_left := 1.0                    # Anteil, der noch in der Erzader steckt
var ore_k := 0.0                       # Abbau-Fortschritt 0..1
var fog := PackedByteArray()
var fog_n := 24
var pack: Node3D
var _seed := 0
var _rng2 := RandomNumberGenerator.new()
var _chest_n: Node3D
var _ore_n: Node3D
var _ore_label: Label3D
var _exit_ring: MeshInstance3D
var _exit_hold := 0.0
var _exit_armed := false
var _hero_light: OmniLight3D
var _fog_t := 0.0
var _dead_t := -1.0
var _leaving := false
var _bot_skill_t := 0.0
var _kills0 := 0
var _msg_t := 0.0
var _mm := {}                          # Modell -> [Transform3D] je Raum (eigene MultiMeshes, damit Lichter je Raum zählen)

# ---- Rucksack der Expedition (hud.gd, backpack.gd und companion.gd lesen diese Felder)
var loot: Dictionary:
	get:
		return ex.loot if is_instance_valid(ex) else {}
	set(v):
		ex.loot = v
var weight: float:
	get:
		return float(ex.weight) if is_instance_valid(ex) else 0.0
	set(v):
		ex.weight = v
var cap: float:
	get:
		return float(ex.cap) if is_instance_valid(ex) else 1.0
	set(v):
		ex.cap = v
var respawns_left: int:
	get:
		return int(ex.respawns_left) if is_instance_valid(ex) else 0
	set(v):
		ex.respawns_left = v
var loads: int:
	get:
		return int(ex.loads)
var dp_mult: float:
	get:
		return float(ex.dp_mult)
var factor: float:
	get:
		return float(ex.factor)


## Vor swap_in: Expedition, ihr Höhlen-Knoten, Nummer, Thema, Zufallswert.
func init(expedition: Node3D, modi_exp: Node3D, i: int, theme: String, seed_v: int) -> void:
	ex = expedition
	mx = modi_exp
	idx = i
	theme_key = theme
	_seed = seed_v
	area = int(ex.area)
	adef = ex.adef
	mission = String(ex.mission)


# ================================================================= Wechsel Expedition <-> Höhle
## Expedition aushängen (ruht), Höhle einhängen.
func swap_in() -> void:
	var m = G.main
	var hud = m.hud
	var hp_k: float = clampf(ex.hero.hp / maxf(ex.hero.max_hp, 1.0), 0.05, 1.0)
	if ex.state_changed.is_connected(hud._rebuild):
		ex.state_changed.disconnect(hud._rebuild)
	if ex.battle_ended.is_connected(hud._show_result):
		ex.battle_ended.disconnect(hud._show_result)
	if P.hero_level_up.is_connected(ex._on_hero_level):
		P.hero_level_up.disconnect(ex._on_hero_level)
	Sfx.stop_all()
	m.get_tree().paused = false
	m.pad.reset()
	m.remove_child(ex)
	G.player = null                     # die Kamera der Höhle darf nicht dem ruhenden Helden folgen
	G.game = null
	m.world = self
	m.add_child(self)
	m.move_child(self, 0)
	hero.hp = hero.max_hp * hp_k
	hud.set_world(self)
	_fade_in()
	Sfx.play("cave_enter", -3.0)
	P.toast.emit("%s – finde Truhe und Erzader. Die Leiter am Eingang führt zurück." % String(tdef.name))


## Höhle verlassen: Expedition wieder einhängen, Held an den Eingang stellen.
func swap_out(finished: bool) -> void:
	if _leaving:
		return
	_leaving = true
	ended = true
	running = false
	var m = G.main
	var hud = m.hud
	var hp_k: float = clampf(hero.hp / maxf(hero.max_hp, 1.0), 0.0, 1.0) if hero.alive else 0.0
	_flush_coins()
	_flush_xp()
	ex.horde.kills += horde.kills
	if state_changed.is_connected(hud._rebuild):
		state_changed.disconnect(hud._rebuild)
	if battle_ended.is_connected(hud._show_result):
		battle_ended.disconnect(hud._show_result)
	leave()
	m.remove_child(self)
	m.world = ex
	m.add_child(ex)
	m.move_child(ex, 0)
	# Verweise der Expedition wiederherstellen
	G.game = ex
	G.field = ex.field
	G.horde = ex.horde
	G.coins = ex.coins
	G.fx = ex.fx
	G.cam = ex.cam
	G.player = ex.hero
	if not P.hero_level_up.is_connected(ex._on_hero_level):
		P.hero_level_up.connect(ex._on_hero_level)
	ex.cam.cam.make_current()
	var h = ex.hero
	var c: Dictionary = mx.caves[idx] if mx != null and idx < mx.caves.size() else {}
	if not c.is_empty():
		var front := (c.p as Vector2) - (c.c as Vector2)
		var q: Vector2 = (c.p as Vector2) + front.normalized() * 2.0
		h.global_position = Vector3(q.x, 0, q.y)
	if hp_k > 0.0:
		h.hp = maxf(1.0, h.max_hp * hp_k)
	h.refresh_stats()
	ex.cam.snap()
	if mx != null:
		mx.cave_left(idx, finished)
	hud.set_world(ex)
	_fade_in()
	Sfx.play("cave_exit", -3.0)
	queue_free()


func _fade_in() -> void:
	var f = G.main.get("_fade")
	if f != null:
		f.color.a = 1.0
		var tw: Tween = G.main.create_tween()
		tw.tween_property(f, "color:a", 0.0, 0.45)


# ================================================================= Aufbau
func _ready() -> void:
	mode = "exp"
	tdef = DM.CAVE_THEMES[theme_key]
	_rng2.seed = _seed
	var plan := _plan()
	var mn: Vector2 = plan[0]
	var mxv: Vector2 = plan[1]
	var th: Dictionary = adef.duplicate()
	th["fog"] = tdef.fog
	th["ground"] = tdef.ground
	th["ground2"] = (tdef.ground as Color).darkened(0.2)
	th["path"] = tdef.ground
	th["sun"] = Color(0.9, 0.85, 0.8)
	var origin := Vector2(floor(mn.x / 2.0) * 2.0 - 12.0, floor(mn.y / 2.0) * 2.0 - 12.0)
	var size := (mxv - origin) + Vector2(12, 12)
	var cw := int(ceil(size.x / 2.0))
	var ch := int(ceil(size.y / 2.0))
	setup_common(th, origin, cw, ch, 2.0)
	_darken()
	for i in field.solid.size():
		field.solid[i] = 1
	_build_rooms()
	field.dirty = true
	field.set_goal(exit_p)
	make_ground(origin, Vector2(cw * 2.0, ch * 2.0), [], 1.0)
	ground_mat.set_shader_parameter("col_a", (tdef.fog as Color).lightened(0.05))
	ground_mat.set_shader_parameter("col_b", tdef.fog)
	cam.bounds = Rect2(mn.x - 4, mn.y - 4, mxv.x - mn.x + 8, mxv.y - mn.y + 8)
	horde.aggro_range = 9.0
	spawn_hero(String(P.d.hero_sel), exit_p + Vector2(0, 3.0))
	hero.died.connect(_on_hero_died)
	_hero_light = OmniLight3D.new()
	_hero_light.light_color = Color(1.0, 0.9, 0.75)
	_hero_light.light_energy = 1.8
	_hero_light.omni_range = 13.0
	_hero_light.omni_attenuation = 0.8
	_hero_light.shadow_enabled = false
	_hero_light.position = Vector3(0, 3.2, 0)
	hero.add_child(_hero_light)
	pack = Backpack.new()
	add_child(pack)
	pack.setup(self)
	fog.resize(fog_n * fog_n)
	running = true
	xp_factor = float(ex.xp_factor)
	_kills0 = 0
	Music.set_mood("battle")
	Sfx.loop("amb", "amb_cave", -14.0)
	_reveal(hero.pos2())
	state_changed.emit()


func _darken() -> void:
	world_env.background_color = tdef.fog
	world_env.fog_light_color = tdef.fog
	world_env.fog_density = 0.03
	world_env.ambient_light_color = tdef.amb
	world_env.ambient_light_energy = 0.55
	sun.light_energy = 0.32
	sun.light_color = Color(0.75, 0.75, 0.85)
	sun.shadow_enabled = false


## Räume auf einem Raster: Kette ab (0, 0), jede Zelle nur einmal. Rückgabe [min, max] der Fläche (Meter).
func _plan() -> Array:
	var n := _rng2.randi_range(int(DM.CAVE_ROOMS[0]), int(DM.CAVE_ROOMS[1]))
	if G.arg("cave_rooms") != "":
		n = clampi(int(G.arg("cave_rooms")), 2, 6)
	var cells: Array = [Vector2i.ZERO]
	var dirs := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	var tries := 0
	while cells.size() < n and tries < 200:
		tries += 1
		var last: Vector2i = cells[cells.size() - 1]
		var d: Vector2i = dirs[_rng2.randi() % 4]
		var nx: Vector2i = last + d
		if nx in cells:
			continue
		cells.append(nx)
	var step := DM.CAVE_ROOM + DM.CAVE_HALL
	var mn := Vector2(1e9, 1e9)
	var mxv := Vector2(-1e9, -1e9)
	var sum := Vector2.ZERO
	for c in cells:
		sum += Vector2(c) * step
	var off := -sum / float(cells.size())
	off = Vector2(round(off.x / 2.0) * 2.0, round(off.y / 2.0) * 2.0)
	for i in cells.size():
		var p := Vector2(cells[i]) * step + off
		rooms.append({"c": p, "i": i, "cell": cells[i], "guards": []})
		mn = Vector2(minf(mn.x, p.x - 7.0), minf(mn.y, p.y - 7.0))
		mxv = Vector2(maxf(mxv.x, p.x + 7.0), maxf(mxv.y, p.y + 7.0))
	return [mn, mxv]


func _build_rooms() -> void:
	var t := theme_key
	var half := DM.CAVE_ROOM * 0.5
	for ri in rooms.size():
		var rm: Dictionary = rooms[ri]
		var c: Vector2 = rm.c
		_mm = {}
		place_model("cv_%s_floor" % t, Vector3(c.x, 0, c.y), float(_rng2.randi() % 4) * PI * 0.5)
		field.clear_rect(c - Vector2(half - 1.0, half - 1.0), c + Vector2(half - 1.0, half - 1.0) - Vector2(0.01, 0.01))
		# Türen: zu welchen Nachbarn führt ein Gang?
		var doors := {}
		for rj in [ri - 1, ri + 1]:
			if rj >= 0 and rj < rooms.size():
				var d: Vector2i = rooms[rj].cell - rm.cell
				doors[d] = true
		for side in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var axis := Vector2(side)
			var along := axis.orthogonal()
			var yaw := atan2(-axis.x, -axis.y)
			for k in range(-3, 4):
				if doors.has(side) and absi(k) <= 1:
					continue
				var p: Vector2 = c + axis * (half + 0.2) + along * (k * 2.0)
				_mm_add("cv_%s_wall_%d" % [t, 1 + (_rng2.randi() % 2)], Vector3(p.x, 0, p.y), yaw)
			if doors.has(side):
				_build_hall(c, axis)
		for cx in [-1, 1]:
			for cz in [-1, 1]:
				_mm_add("cv_%s_rock" % t, Vector3(c.x + cx * (half + 0.4), 0, c.y + cz * (half + 0.4)), _rng2.randf() * TAU)
		# Fackeln in zwei Ecken, Schmuck verteilt
		var corners := [Vector2(-1, -1), Vector2(1, 1), Vector2(1, -1), Vector2(-1, 1)]
		for k in 2:
			var cp: Vector2 = c + (corners[(ri + k * 2) % 4] as Vector2) * (half - 1.6)
			_torch(cp)
			field.block_circle(cp, 0.4)
		for k in 3:
			var dp := c + Vector2(_rng2.randf_range(-4.5, 4.5), _rng2.randf_range(-4.5, 4.5))
			if dp.distance_to(c) < 2.5 or (ri == 0 and dp.distance_to(c) < 5.0):
				continue
			var dn := "cv_%s_deco_%d" % [t, 1 + (_rng2.randi() % 2)]
			_mm_add(dn, Vector3(dp.x, 0, dp.y), _rng2.randf() * TAU)
			field.block_circle(dp, 0.8)
		_mm_commit()
		if ri == 0:
			exit_p = c + Vector2(0, -2.0)
			place_model("cv_exit", Vector3(exit_p.x, 0, exit_p.y), 0.0)
			for bn in find_children("beam_glow", "", true, false):
				if bn is GeometryInstance3D:
					(bn as GeometryInstance3D).material_override = MK.glow(Color(1.0, 0.95, 0.75, 0.22), true)
					(bn as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			_exit_ring = MeshInstance3D.new()
			var tor := TorusMesh.new()
			tor.inner_radius = 1.35
			tor.outer_radius = 1.6
			tor.rings = 32
			tor.ring_segments = 4
			_exit_ring.mesh = tor
			_exit_ring.material_override = MK.glow(Color(1.0, 0.85, 0.4))
			_exit_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			_exit_ring.position = Vector3(exit_p.x, 0.12, exit_p.y)
			add_child(_exit_ring)
		if ri == rooms.size() - 1:
			chest_p = c + Vector2(-2.2, 0.8)
			ore_p = c + Vector2(2.6, -1.2)
			_chest_n = place_model("p_chest", Vector3(chest_p.x, 0, chest_p.y), 0.4, 1.2) if Models.has_glb("p_chest") else Node3D.new()
			_ore_n = place_model("cv_%s_ore" % t, Vector3(ore_p.x, 0, ore_p.y), _rng2.randf() * TAU, 1.3)
			field.block_circle(ore_p, 0.9)
			_ore_label = Label3D.new()
			_ore_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			_ore_label.pixel_size = 0.012
			_ore_label.font_size = 40
			_ore_label.outline_size = 10
			_ore_label.no_depth_test = true
			_ore_label.position = Vector3(ore_p.x, 2.8, ore_p.y)
			_ore_label.visible = false
			add_child(_ore_label)
	scatter_commit()
	_place_guards()


func _build_hall(c: Vector2, axis: Vector2) -> void:
	# nur einmal je Paar (Gang gehört zum Raum mit dem kleineren Index in Richtung +x/+z)
	if axis.x < 0.0 or axis.y < 0.0:
		return
	var t := theme_key
	var half := DM.CAVE_ROOM * 0.5
	var mid: Vector2 = c + axis * (half + DM.CAVE_HALL * 0.5)
	var along := axis.orthogonal()
	var yaw_floor := atan2(axis.x, axis.y)
	var hn := place_model("cv_%s_hall" % t, Vector3(mid.x, 0.01, mid.y), yaw_floor)
	hn.scale = Vector3(1.36, 1.0, 1.0)
	var a := mid - axis * (DM.CAVE_HALL * 0.5 + 1.2) - along * 1.9
	var b := mid + axis * (DM.CAVE_HALL * 0.5 + 1.2) + along * 1.9
	field.clear_rect(Vector2(minf(a.x, b.x), minf(a.y, b.y)), Vector2(maxf(a.x, b.x), maxf(a.y, b.y)) - Vector2(0.01, 0.01))
	for s in [-1, 1]:
		for k in [-1, 0, 1]:
			var p: Vector2 = mid + axis * (k * 2.0) + along * (s * 3.2)
			var yaw := atan2(along.x * s, along.y * s)
			_mm_add("cv_%s_wall_%d" % [t, 1 + (_rng2.randi() % 2)], Vector3(p.x, 0, p.y), yaw)


func _torch(p: Vector2) -> void:
	var n := place_model("cv_torch", Vector3(p.x, 0, p.y), _rng2.randf() * TAU)
	if G.web_mobile() and rooms.size() > 3:
		return
	var l := OmniLight3D.new()
	l.light_color = tdef.torch
	l.light_energy = 2.4
	l.omni_range = 10.0
	l.omni_attenuation = 1.0
	l.shadow_enabled = false
	l.position = Vector3(0, 2.6, 0)
	n.add_child(l)


func _mm_add(model: String, p: Vector3, yaw: float) -> void:
	if not _mm.has(model):
		_mm[model] = []
	_mm[model].append(Transform3D(Basis(Vector3.UP, yaw), p))


## Ein MultiMesh je Modell und Raum (Lichter wirken je Zeichenobjekt – so zählen nur die Fackeln des Raums).
func _mm_commit() -> void:
	for model in _mm:
		if not Models.has_glb(model):
			continue
		var list: Array = _mm[model]
		for part in ["body", "ice_glow", "crack_glow"]:
			var mesh = Models.glb_mesh(model, part)
			if mesh == null:
				continue
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.mesh = mesh
			mm.instance_count = list.size()
			for i in list.size():
				mm.set_instance_transform(i, list[i])
			var mi := MultiMeshInstance3D.new()
			mi.multimesh = mm
			mi.material_override = MK.mat_glow() if part.ends_with("_glow") else MK.mat_lin()
			if part.ends_with("_glow") or G.quality() < 2:
				mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(mi)
	_mm = {}


func _place_guards() -> void:
	var dc := float(D.DIFFS[int(ex.diff)].count)
	for ri in range(1, rooms.size()):
		var rm: Dictionary = rooms[ri]
		var n := int(ceil(_rng2.randi_range(int(DM.CAVE_GUARDS[0]), int(DM.CAVE_GUARDS[1])) * dc))
		for k in n:
			var q: Vector2 = rm.c + Vector2(_rng2.randf_range(-4.5, 4.5), _rng2.randf_range(-4.5, 4.5))
			if field.is_solid(q):
				continue
			var role: String = ["mass", "mass", "fast", "ranged", "tank"][k % 5] if k > 0 else "mass"
			_guard(q, rm.c, role)
		if ri == rooms.size() - 1:
			_guard(rm.c + Vector2(0, 2.5), rm.c, "elite")


func _guard(q: Vector2, home: Vector2, role: String) -> void:
	var hm: float = float(ex.hp_mult) * DM.CAVE_HP
	var dm := 1.0 + 0.1 * int(adef.level)
	var e = horde.spawn_for_area(area, q, hm, dm, float(ex.dp_mult), role)
	if e == null:
		return
	e.home = home
	e.leash = 6.0
	e.aggro = false


# ================================================================= Ablauf
func _physics_process(dt: float) -> void:
	tick_common(dt)
	if ended or hero == null:
		return
	_msg_t -= dt
	if _dead_t >= 0.0:
		_dead_t -= dt
		if _dead_t <= 0.0:
			_dead_end()
		return
	if not hero.alive:
		return
	var pp: Vector2 = hero.pos2()
	_fog_t -= dt
	if _fog_t <= 0.0:
		_fog_t = 0.4
		_reveal(pp)
	pack.tick(dt, pp)
	_tick_chest(pp)
	_tick_ore(dt, pp)
	_tick_exit(dt, pp)
	if G.autotest != "":
		_bot_skill_t -= dt
		if _bot_skill_t <= 0.0:
			_bot_skill_t = 1.0
			for i in 4:
				if hero.skills.ready(i) and horde.nearest(pp, 10.0) != null:
					hero.skills.use(i)


func _tick_chest(pp: Vector2) -> void:
	if chest_open or pp.distance_to(chest_p) > 1.9:
		return
	open_chest()


## Truhe öffnen: Feldmünzen in den Rucksack, mit etwas Glück eine Fundkiste für die Expedition.
func open_chest() -> void:
	if chest_open:
		return
	chest_open = true
	var coins := DM.CAVE_CHEST_COINS * float(ex.factor)
	ex.add_pack("coins", coins)
	var extra := ""
	if _rng2.randf() < DM.CAVE_CHEST_FIND or G.arg("cave_find") == "1":
		ex.chests_found = int(ex.chests_found) + 1
		extra = " und eine Fundkiste"
	fx.confetti(Vector3(chest_p.x, 1.0, chest_p.y), 4)
	fx.float_text(Vector3(chest_p.x, 2.4, chest_p.y), "+%d Münzen" % int(coins), D.C_GOLD)
	Sfx.play("cave_chest", -2.0)
	P.toast.emit("Truhe geöffnet: %d Feldmünzen%s!" % [int(coins), extra])
	if _chest_n != null:
		var lid := Models.find(_chest_n, "lid")
		if lid != null:
			lid.rotation.x = -1.1
		else:
			var tw := create_tween()
			tw.tween_property(_chest_n, "scale", _chest_n.scale * 1.15, 0.12)
			tw.tween_property(_chest_n, "scale", _chest_n.scale, 0.18)
	state_changed.emit()


func _tick_ore(dt: float, pp: Vector2) -> void:
	if ore_left <= 0.0:
		return
	var near: bool = pp.distance_to(ore_p) < 2.4 and hero.speed_now < 0.6 and not hero.mounted
	_ore_label.visible = near or ore_k > 0.0
	if not near:
		return
	ore_k += dt / DM.CAVE_ORE_TIME
	_ore_label.text = "Abbau %d %%" % int(minf(ore_k, 1.0) * 100.0)
	if int(ore_k * 6.0) != int((ore_k - dt / DM.CAVE_ORE_TIME) * 6.0):
		Sfx.play_at("hit_geode", Vector3(ore_p.x, 1.0, ore_p.y), -8.0, randf_range(0.9, 1.1), 0.1)
		fx.puff(Vector3(ore_p.x, 1.0, ore_p.y), D.RES_COLOR.get(tdef.ore.keys()[0], Color.WHITE), 5, 0.8)
		if hero.alive:
			hero.body.play("pay")
	if ore_k >= 1.0:
		mine_ore()


## Erzader abbauen: Rohstoffe des Themas (× Gebietsfaktor) in den Rucksack, so viel passt.
func mine_ore() -> void:
	var ore: Dictionary = tdef.ore
	var got: Array = []
	var any_left := false
	for r in ore:
		var amt: float = float(ore[r]) * float(ex.factor) * ore_left
		var took: float = ex.add_pack(String(r), amt)
		if took >= 1.0:
			got.append("%d %s" % [int(took), String(D.RES_NAME.get(r, r))])
			if pack != null and pack.has_method("load_point"):
				for i in mini(4, int(took / 4.0) + 1):
					fx.puff(pack.load_point(), D.RES_COLOR.get(r, Color.WHITE), 3, 0.5)
		if took < amt - 0.5:
			any_left = true
	ore_k = 0.0
	if got.is_empty():
		if _msg_t <= 0.0:
			_msg_t = 3.0
			P.toast.emit("Rucksack voll – wirf etwas ab oder bring erst etwas ins Depot.")
		return
	Sfx.play("cave_ore", -3.0)
	P.toast.emit("Erz abgebaut: %s" % ", ".join(got))
	if not any_left:
		ore_left = 0.0
		_ore_label.visible = false
		if _ore_n != null:
			var tw := create_tween()
			tw.tween_property(_ore_n, "scale", Vector3.ONE * 0.6, 0.4)
	else:
		ore_left *= 0.5
	state_changed.emit()


func _tick_exit(dt: float, pp: Vector2) -> void:
	var d := pp.distance_to(exit_p)
	if d > 2.4:
		_exit_armed = true
	if d < 1.5 and _exit_armed:
		_exit_hold += dt
		_exit_ring.scale = Vector3.ONE * (1.0 + 0.3 * _exit_hold)
		if _exit_hold >= 0.9:
			leave_cave()
	else:
		_exit_hold = 0.0
		_exit_ring.scale = Vector3.ONE * (1.0 + 0.05 * sin(time * 4.0))


## Rückweg: Höhle verlassen (fertig, wenn Truhe offen und Erz abgebaut ist – sonst bleibt der Eingang offen).
func leave_cave() -> void:
	var finished := chest_open and ore_left <= 0.0
	if chest_open or ore_left < 1.0:
		Modi.cave_done(chest_open, ore_left <= 0.0)
	swap_out.call_deferred(finished or chest_open)


func _on_hero_died() -> void:
	var keep := CD.death_keep()
	for r in loot.keys():
		loot[r] = float(loot[r]) * keep
	ex._recalc_weight()
	ex.respawns_left = int(ex.respawns_left) - 1
	if int(ex.respawns_left) < 0:
		_dead_t = 1.6
		P.toast.emit("Dein Held ist erschöpft – er wird aus der Höhle getragen.")
	else:
		hero._respawn = D.EXP_RESPAWN_TIME
		P.toast.emit("Wiedereinstieg am Höhleneingang in %d s (noch %d×)." % [int(D.EXP_RESPAWN_TIME), int(ex.respawns_left)])


func _dead_end() -> void:
	var e = ex
	_dead_t = -1.0
	await get_tree().process_frame
	swap_out(false)
	e._finish.call_deferred(false, "fell")


func can_respawn() -> bool:
	return int(ex.respawns_left) >= 0 and _dead_t < 0.0


## Wird die Höhle von außen verworfen (Hauptmenü, Basis), ist auch die ruhende Expedition vorbei.
func leave() -> void:
	super.leave()
	if not _leaving and is_instance_valid(ex) and ex.get_parent() == null:
		ex.queue_free()


func respawn_point() -> Vector2:
	return exit_p + Vector2(0, 2.5)


# ================================================================= Rucksack (leitet an die Expedition weiter)
func unit_weight(r: String) -> float:
	return float(ex.unit_weight(r))


func _recalc_weight() -> void:
	ex._recalc_weight()


func room_for(r: String) -> float:
	return float(ex.room_for(r))


func add_pack(r: String, amt: float) -> float:
	return float(ex.add_pack(r, amt))


func field_coins() -> int:
	return int(ex.field_coins())


func collect_coin(v: float) -> void:
	ex.collect_coin(v)


# ================================================================= für hud.gd (wie die Expedition)
func phase_name() -> String:
	return String(tdef.name)


func objective_text() -> String:
	if chest_open and ore_left <= 0.0:
		return "Alles gefunden! Zurück zur Leiter am Eingang."
	var parts: Array = []
	parts.append("Truhe ✓" if chest_open else "Truhe finden")
	parts.append("Erzader ✓" if ore_left <= 0.0 else "Erzader abbauen (%d s stehen)" % int(DM.CAVE_ORE_TIME))
	return "Höhle: " + " · ".join(parts) + " – Rückweg über die Leiter"


func side_quests() -> Array:
	return []


func can_go_home() -> bool:
	return false


func go_home() -> void:
	pass


## Pause → „Expedition abbrechen“: erst hinaus, dann abbrechen.
func abort() -> void:
	var e = ex
	swap_out(false)
	e.abort.call_deferred()


func hint_arrow() -> Array:
	if chest_open and ore_left <= 0.0:
		return [exit_p, Color("FFD23E")]
	return []


func map_points() -> Array:
	var out: Array = [[exit_p, "base"]]
	if _seen(chest_p) and not chest_open:
		out.append([chest_p, "chest"])
	if _seen(ore_p) and ore_left > 0.0:
		out.append([ore_p, "goal"])
	return out


func _seen(p: Vector2) -> bool:
	var x := clampi(int((p.x + HALFM) / (HALFM * 2.0 / fog_n)), 0, fog_n - 1)
	var z := clampi(int((p.y + HALFM) / (HALFM * 2.0 / fog_n)), 0, fog_n - 1)
	return fog[x + z * fog_n] == 1


func _reveal(pp: Vector2) -> void:
	var cell := HALFM * 2.0 / fog_n
	var r := 12.0
	for z in fog_n:
		for x in fog_n:
			var c := Vector2((x + 0.5) * cell - HALFM, (z + 0.5) * cell - HALFM)
			if c.distance_to(pp) < r:
				fog[x + z * fog_n] = 1


func node_locked(_n) -> bool:
	return false


func bot_goal():
	if hero == null or not hero.alive:
		return null
	var pp: Vector2 = hero.pos2()
	var e = horde.nearest(pp, 9.0)
	if e != null and e.p.distance_to(pp) < 4.0:
		var away: Vector2 = (pp - e.p).normalized()
		return pp + away * 3.0
	var goal := exit_p
	if not chest_open:
		goal = chest_p
	elif ore_left > 0.0:
		goal = ore_p + (pp - ore_p).normalized() * 1.6
	# festgefahren (Ecke im Gang)? Kurz zur Mitte des aktuellen Raums ausweichen
	var now := time
	if pp.distance_to(_bot_last) > 1.0:
		_bot_last = pp
		_bot_since = now
	elif now - _bot_since > 4.0:
		if now - _bot_since > 5.5:
			_bot_since = now
		return rooms[maxi(_room_at(pp), 0)].c
	return _path_step(pp, goal)


## Testbot: nächster Raummittelpunkt auf dem Weg (die Räume sind eine Kette).
func _path_step(pp: Vector2, goal: Vector2) -> Vector2:
	var ri := _room_at(pp)
	var gi := _room_at(goal)
	if ri < 0 or gi < 0 or ri == gi:
		return goal
	var nxt: int = ri + (1 if gi > ri else -1)
	var a: Vector2 = rooms[ri].c
	var b: Vector2 = rooms[nxt].c
	# erst zur Tür (Mitte des Gangs), dann in den nächsten Raum
	var door := (a + b) * 0.5
	if pp.distance_to(door) > 1.5 and pp.distance_to(a) < pp.distance_to(b):
		return door
	return b


func _room_at(p: Vector2) -> int:
	var best := -1
	var bd := 1e9
	for r in rooms:
		var d: float = (r.c as Vector2).distance_to(p)
		if d < bd:
			bd = d
			best = int(r.i)
	return best


# Testbot: Festfahren erkennen
var _bot_last := Vector2.ZERO
var _bot_since := 0.0
