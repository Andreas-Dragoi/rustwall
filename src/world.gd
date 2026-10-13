extends Node3D
## Gemeinsame Grundlage für Hauptbasis und Expedition: Umgebung, Boden, Effekte, Horde,
## Münzen, Kamera, Held, Geschosse, Bodenflächen (Feuer, Gewitter, Fallen) und Hilfen für Fähigkeiten.

const D = preload("res://src/data.gd")
const MK = preload("res://src/mk.gd")
const Models = preload("res://src/models.gd")
const Field = preload("res://src/field.gd")
const Fx = preload("res://src/fx.gd")
const Coins = preload("res://src/coins.gd")
const Horde = preload("res://src/horde.gd")
const CameraRig = preload("res://src/camera_rig.gd")
const Hero = preload("res://src/hero.gd")
const Tower = preload("res://src/tower.gd")
const Anim = preload("res://src/anim.gd")
const Research = preload("res://src/research.gd")

const ZONE_COL := {"fire": Color(1.0, 0.45, 0.1, 0.4), "storm": Color(0.5, 0.7, 1.0, 0.35), "heal": Color(0.4, 1.0, 0.5, 0.35),
	"glue": Color(0.9, 0.8, 0.2, 0.0), "spike": Color(1, 1, 1, 0.0)}

var mode := "peace"            # peace | flood | practice | exp
var running := false           # Kampf läuft (Horde bewegt sich)
var ended := false
var zones: Array = []
var structures: Array = []
var towers: Array = []
var goal_structure = null
var barrier_t := 0.0
var fx: Node3D
var coins: Node3D
var horde: Node3D
var cam: Node3D
var hero: Node3D
var field: RefCounted
var theme := {}
var ground_mat: ShaderMaterial
var sun: DirectionalLight3D
var time := 0.0
var _proj: Array = []
var _proj_pool: Array = []
var _coin_buf := 0.0
var _coin_t := 0.0
var _zone_t := 0.0
var _rng := RandomNumberGenerator.new()
var _scatter := {}
var _ambient: CPUParticles3D
var _anims: Array = []
var xp_factor := 1.0           # Erfahrung je besiegtem Gegner (Gebiet bzw. Stärke der Flut)
var _xp_buf := 0.0
var _xp_t := 0.0
var daytime := "tag"           # morgen | tag | abend | nacht (lebendige Basis: weather.gd; sonst immer Tag)
var nature: Node3D             # Wiese, Wege, Pflanzen der Hauptbasis (base_nature.gd), sonst null
var weather: Node3D            # Wind, Tageszeit, Regen der Hauptbasis (weather.gd), sonst null
var wind3 := false             # Kulissen mit dem gemeinsamen Wind der lebendigen Basis zeichnen
var world_env: Environment     # Umgebung (Tageszeit stellt Farben und Licht um)
var companion: Node3D          # aktiver Begleiter (companion.gd, Paket B); folgt dem Helden
var lure_t := 0.0              # Köder des Begleiters (Paket Welt): solange > 0 laufen jagende Gegner zu lure_p
var lure_p := Vector2.ZERO
var flood_rate_k := 1.0        # V6 Paket B: Wetter der Flut (Regen: Türme langsamer)
var flood_range_k := 1.0       # V6 Paket B: Wetter der Flut (Nebel: kürzere Reichweite)


func is_running() -> bool:
	return running and not ended


func is_active() -> bool:
	return not ended


## Nacht? (Glühwürmchen, Laternen, Fenster)
func is_night() -> bool:
	return daytime == "nacht"


## Kosten eines Schritts für Bewohner: Wege sind billiger als Wiese (ohne lebendige Basis überall 1).
func path_cost(p: Vector2) -> float:
	return nature.path_cost(p) if nature != null else 1.0


## Drehung eines Fahnentuchs (anim.gd): mit Wetter weht es mit dem Wind, sonst wie bisher.
func flag_yaw(n: Node3D, base: float, t: float, ph: float) -> float:
	if weather != null:
		return weather.flag_yaw(n, base, t, ph)
	return base + sin(t * 2.6 + ph) * 0.22


func can_respawn() -> bool:
	return true


func respawn_point() -> Vector2:
	return Vector2.ZERO


func bot_goal():
	return null


## Im Baumodus bewegt die Eingabe die Kamera, nicht den Helden.
func hero_locked() -> bool:
	return false


func on_structure_destroyed(_s) -> void:
	pass


func collect_coin(v: float) -> void:
	_coin_buf += v


## Wer ein Tor öffnet (Positionen auf dem Boden).
func friends() -> Array:
	return [hero.pos2()] if hero != null and hero.alive else []


## Erfahrung für besiegte Gegner: kind 0 normal, 1 Elite, 2 Boss. Wird einmal je Sekunde gutgeschrieben.
func add_kill_xp(kind: int) -> void:
	_xp_buf += float(D.HERO_KILL_XP[clampi(kind, 0, 2)]) * xp_factor


func _flush_xp() -> void:
	if _xp_buf >= 1.0 and hero != null:
		var n := floorf(_xp_buf)
		_xp_buf -= n
		P.add_hero_xp(hero.key, n)


func _on_hero_level(key: String, _lvl: int) -> void:
	if hero == null or hero.key != key or fx == null:
		return
	hero.refresh_stats()
	hero.hp = hero.max_hp
	fx.ring(hero.global_position, 4.0, D.C_GOLD, 0.8)
	fx.confetti(hero.global_position + Vector3(0, 1.0, 0), 8)
	fx.float_text(hero.global_position + Vector3(0, 4.0, 0), "Stufe %d!" % _lvl, D.C_GOLD)
	if hero.alive:
		hero.body.play("level_up")


func _flush_coins() -> void:
	if _coin_buf >= 1.0:
		var n := int(_coin_buf)
		_coin_buf -= n
		P.add("coins", n)


## Tempo-Faktor für Türme an dieser Stelle (Adas Besonderheit: +15 % im Umkreis von 12 Metern).
func tower_rate(p: Vector2) -> float:
	var k := (1.0 + P.outpost_bonus("tower_rate")) * (1.0 + Research.bonus("tower_rate")) * flood_rate_k     # V6 Paket B: Forschung, Wetter
	if hero != null and hero.key == "ada" and hero.alive and hero.pos2().distance_squared_to(p) < 144.0:
		k *= 1.25 if hero.level >= D.HERO_PASSIVE_LEVEL else 1.15
	return k


## V6 Paket B: Reichweiten-Faktor aller Türme (Forschung, Nebel in der Flut).
func tower_range_k() -> float:
	return (1.0 + Research.bonus("tower_range")) * flood_range_k


## Schadens-Faktor für ein Gebäude (Brunos Besonderheit, Schildgenerator).
func dmg_factor(s) -> float:
	if hero != null and hero.key == "bruno" and hero.alive and hero.pos2().distance_squared_to(s.mid) < 64.0:
		return 0.7 if hero.level >= D.HERO_PASSIVE_LEVEL else 0.8
	return 1.0


func tower_buff(c: Vector2, radius: float, k: float, t: float) -> void:
	for tw in towers:
		if is_instance_valid(tw) and tw.pos2().distance_to(c) < radius:
			tw.buff(k, t)


func repair_around(c: Vector2, radius: float, ratio: float) -> int:
	var n := 0
	for s in structures:
		if s.alive and s.hp < s.max_hp and s.mid.distance_to(c) < radius + s.radius:
			s.repair(ratio)
			n += 1
	return n


func damage_structures(c: Vector2, radius: float, dmg: float) -> void:
	for s in structures:
		if s.alive and s.mid.distance_to(c) < radius + s.radius:
			s.hurt(dmg, true)


func spawn_tower(key: String, p: Vector2, life: float, lvl := 1, settler := false) -> Node3D:
	var t := Tower.new()
	t.settler = settler
	add_child(t)
	t.position = Vector3(p.x, 0, p.y)
	t.setup(key, lvl)
	t.life = life
	towers.append(t)
	fx.puff(t.position + Vector3(0, 0.5, 0), Color(0.9, 0.9, 0.9), 12)
	Sfx.play_at("tower_spawn", t.position, -7.0, 1.0, 0.08)
	return t


# ---------------------------------------------------------------- Aufbau
func setup_common(th: Dictionary, origin: Vector2, w: int, h: int, cell: float) -> void:
	theme = th
	_rng.randomize()
	field = Field.new(origin, w, h, cell)
	G.field = field
	G.game = self
	P.hero_level_up.connect(_on_hero_level)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = th.fog
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.82, 0.86, 1.0)
	env.ambient_light_energy = 0.75
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.fog_enabled = true
	env.fog_light_color = th.fog
	env.fog_density = 0.0022
	env.fog_sky_affect = 0.0
	var we := WorldEnvironment.new()
	we.environment = env
	world_env = env
	add_child(we)
	sun = DirectionalLight3D.new()
	sun.rotation = Vector3(deg_to_rad(-52.0), deg_to_rad(-30.0), 0)
	sun.light_color = th.sun
	sun.light_energy = 1.35
	sun.shadow_enabled = G.quality() >= 1
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL if G.quality() < 2 else DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = 90.0
	sun.shadow_bias = 0.06
	sun.shadow_normal_bias = 1.5
	sun.shadow_opacity = 0.55
	add_child(sun)
	fx = Fx.new()
	add_child(fx)
	G.fx = fx
	coins = Coins.new()
	add_child(coins)
	G.coins = coins
	horde = Horde.new()
	add_child(horde)
	G.horde = horde
	cam = CameraRig.new()
	add_child(cam)
	G.cam = cam
	var sph := SphereMesh.new()
	sph.radius = 0.24
	sph.height = 0.48
	sph.radial_segments = 8
	sph.rings = 4
	for i in 20:
		var m := MeshInstance3D.new()
		m.mesh = sph
		m.material_override = MK.glow(Color.WHITE, true)
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		m.visible = false
		add_child(m)
		_proj_pool.append(m)


## Bodenfläche mit Farbverlauf und Wegen. paths: Liste von Linienzügen (PackedVector2Array).
func make_ground(origin: Vector2, size: Vector2, paths: Array, path_width := 1.0) -> void:
	var pm := PlaneMesh.new()
	pm.size = size + Vector2(160, 160)
	var g := MeshInstance3D.new()
	g.mesh = pm
	g.position = Vector3(origin.x + size.x * 0.5, 0, origin.y + size.y * 0.5)
	g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ground_mat = ShaderMaterial.new()
	ground_mat.shader = load("res://shaders/ground.gdshader")
	var nt := NoiseTexture2D.new()
	nt.width = 256
	nt.height = 256
	nt.seamless = true
	var fn := FastNoiseLite.new()
	fn.frequency = 0.02
	fn.fractal_octaves = 3
	nt.noise = fn
	ground_mat.set_shader_parameter("noise_tex", nt)
	ground_mat.set_shader_parameter("map_origin", origin)
	ground_mat.set_shader_parameter("map_size", size)
	ground_mat.set_shader_parameter("col_a", theme.ground)
	ground_mat.set_shader_parameter("col_b", theme.ground2)
	ground_mat.set_shader_parameter("col_path", theme.path)
	ground_mat.set_shader_parameter("use_path", 1.0 if paths.size() > 0 else 0.0)
	if paths.size() > 0:
		var res := 160
		var img := Image.create(res, res, false, Image.FORMAT_L8)
		for y in res:
			for x in res:
				var p := origin + Vector2((x + 0.5) / res * size.x, (y + 0.5) / res * size.y)
				var best := 8.0
				for line: PackedVector2Array in paths:
					for i in line.size() - 1:
						var cp := Geometry2D.get_closest_point_to_segment(p, line[i], line[i + 1])
						var dd := p.distance_to(cp) / path_width
						if dd < best:
							best = dd
				img.set_pixel(x, y, Color(best / 8.0, 0, 0))
		ground_mat.set_shader_parameter("path_tex", ImageTexture.create_from_image(img))
	g.material_override = ground_mat
	add_child(g)


func spawn_hero(key: String, p: Vector2) -> void:
	hero = Hero.new()
	add_child(hero)
	hero.position = Vector3(p.x, 0, p.y)
	hero.setup(key)
	G.player = hero
	cam.snap()
	if companion == null:
		companion = preload("res://src/companion.gd").new()
		add_child(companion)
		companion.setup(self)


# ---------------------------------------------------------------- Kulissen aus Blender
## Merkt eine Kulisse vor (models/<name>.glb, Objekt "body"). Gezeichnet wird je Modell mit einem MultiMesh.
func scatter(model: String, p: Vector3, yaw := 0.0, s := 1.0) -> void:
	if not _scatter.has(model):
		_scatter[model] = []
	_scatter[model].append(Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3(s, s, s)), p))


## Zufällige Variante: "p_tree_pine" mit n = 3 ergibt p_tree_pine_1..3.
func scatter_var(base: String, n: int, p: Vector3, rng: RandomNumberGenerator, s_min := 0.85, s_max := 1.25) -> void:
	scatter("%s_%d" % [base, rng.randi_range(1, n)], p, rng.randf() * TAU, rng.randf_range(s_min, s_max))


func scatter_commit() -> void:
	for model in _scatter:
		if not Models.has_glb(model):
			continue
		var list: Array = _scatter[model]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = Models.glb_mesh(model, "body")
		mm.instance_count = list.size()
		for i in list.size():
			mm.set_instance_transform(i, list[i])
		var mi := MultiMeshInstance3D.new()
		mi.multimesh = mm
		var wind := 0.0
		if model.begins_with("p_tree_cactus") or model.begins_with("p_tree_crystal"):
			wind = 0.0
		elif model.begins_with("p_tree"):
			wind = 0.005
		elif model.begins_with("p_grass") or model.begins_with("p_flowers"):
			wind = 0.35
		elif model.begins_with("p_bush"):
			wind = 0.05
		mi.material_override = MK.mat_wind(wind) if wind > 0.0 else MK.mat_lin()
		if wind3 and wind > 0.0:
			mi.material_override = MK.mat_wind3(wind * (2.0 if model.begins_with("p_tree") else 1.0))
		var small: bool = model.begins_with("p_grass") or model.begins_with("p_flowers") or model.begins_with("p_mushroom")
		if small or G.quality() == 0:
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if small:
			mi.visibility_range_end = 70.0
		add_child(mi)
	_scatter.clear()


## Einzelnes Blender-Modell mit Daueranimation (Fahne, Lagerfeuer, Drohne ...).
func place_model(model: String, p: Vector3, yaw := 0.0, s := 1.0) -> Node3D:
	var n := Models.glb(model)
	n.position = p
	n.rotation.y = yaw
	n.scale = Vector3(s, s, s)
	add_child(n)
	_anims.append_array(Anim.collect(n))
	return n


## Schwebende Teilchen rund um die Kamera: Pollen, Blätter, Staub, Schnee, Glühwürmchen, Blasen.
func make_ambient(kind: String) -> void:
	var p := CPUParticles3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.09, 0.09, 0.09)
	var col := Color(1.0, 0.97, 0.7, 0.9)
	p.amount = [18, 34, 50][G.quality()]
	p.lifetime = 7.0
	p.preprocess = 7.0
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(26, 2.5, 22)
	p.local_coords = false
	p.direction = Vector3(1, 0.25, 0.3)
	p.spread = 40.0
	p.initial_velocity_min = 0.3
	p.initial_velocity_max = 0.9
	p.gravity = Vector3(0, 0.05, 0)
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.5
	p.angular_velocity_min = -90.0
	p.angular_velocity_max = 90.0
	match kind:
		"forst":
			col = Color(0.55, 0.75, 0.3, 0.95)
			bm.size = Vector3(0.16, 0.02, 0.1)
			p.gravity = Vector3(0.2, -0.5, 0)
		"staub":
			col = Color(0.95, 0.85, 0.6, 0.6)
			p.initial_velocity_max = 3.0
			p.direction = Vector3(1, 0.05, 0.1)
		"kueste":
			col = Color(1, 1, 1, 0.8)
		"sumpf":
			col = Color(0.75, 1.0, 0.4, 1.0)
			bm.size = Vector3(0.12, 0.12, 0.12)
		"frost":
			col = Color(1, 1, 1, 0.95)
			p.amount = p.amount * 3
			p.lifetime = 5.0
			p.direction = Vector3(0.3, -1, 0.1)
			p.initial_velocity_min = 1.5
			p.initial_velocity_max = 2.6
			p.emission_box_extents = Vector3(26, 6, 22)
		"krater":
			col = Color(0.7, 1.0, 0.3, 0.9)
			bm.size = Vector3(0.16, 0.16, 0.16)
			p.direction = Vector3(0, 1, 0)
			p.gravity = Vector3(0, 0.6, 0)
		"vulkan":                              # Paket Z: Glutfunken steigen auf
			col = Color(1.0, 0.55, 0.15, 1.0)
			bm.size = Vector3(0.07, 0.07, 0.07)
			p.direction = Vector3(0.2, 1, 0.1)
			p.gravity = Vector3(0.1, 0.5, 0)
			p.initial_velocity_max = 1.4
	p.mesh = bm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	p.material_override = m
	var grad := Gradient.new()
	grad.set_color(0, Color(col.r, col.g, col.b, 0.0))
	grad.add_point(0.2, col)
	grad.add_point(0.8, col)
	grad.set_color(grad.get_point_count() - 1, Color(col.r, col.g, col.b, 0.0))
	p.color_ramp = grad
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(p)
	_ambient = p


# ---------------------------------------------------------------- Bodenflächen
func add_zone(kind: String, c: Vector2, radius: float, t: float, dps: float, uses := 1.0e9) -> Dictionary:
	var z := {"kind": kind, "c": c, "r": radius, "r2": radius * radius, "t": t, "dps": dps, "uses": uses, "n": null}
	var col: Color = ZONE_COL[kind]
	match kind:
		"fire":
			Sfx.play_at("fire_whoosh", Vector3(c.x, 0, c.y), -10.0, 1.0, 0.25)
		"storm":
			Sfx.play_at("thunder", Vector3(c.x, 0, c.y), -8.0)
		"heal":
			Sfx.play_at("zone_heal", Vector3(c.x, 0, c.y), -8.0, 1.0, 0.25)
	if col.a > 0.0:
		var m := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = radius
		cm.bottom_radius = radius
		cm.height = 0.08
		cm.radial_segments = 20
		cm.rings = 1
		m.mesh = cm
		m.material_override = MK.glow(col, true)
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		m.position = Vector3(c.x, 0.08, c.y)
		add_child(m)
		z.n = m
	zones.append(z)
	return z


func clear_zones() -> void:
	for z in zones:
		if z.n != null:
			z.n.queue_free()
	zones.clear()


# ---------------------------------------------------------------- Geschosse
## Wirft ein Geschoss im Bogen von a nach b; cb wird beim Einschlag aufgerufen.
func launch(a: Vector3, b: Vector3, dur: float, arc: float, col: Color, cb: Callable, rocket := false) -> void:
	var n: MeshInstance3D = null
	if _proj_pool.size() > 0:
		n = _proj_pool.pop_back()
		(n.material_override as StandardMaterial3D).albedo_color = col
		n.scale = Vector3.ONE * (1.3 if rocket else 1.0)
		n.global_position = a
		n.visible = true
	_proj.append({"n": n, "a": a, "b": b, "t": 0.0, "d": maxf(dur, 0.05), "arc": arc, "cb": cb, "rocket": rocket, "pt": 0.0})
	Sfx.play_at("rocket_fly" if rocket else "whoosh", a, -15.0, 1.0, 0.12)


func blast(pos: Vector3, radius: float, dmg: float, opts := {}, col := Color(1.0, 0.55, 0.15)) -> void:
	fx.explosion(pos + Vector3(0, 0.4, 0), radius, col)
	# Einschlag-Klang: ausdrücklich gewünscht (opts.sfx) oder nach Art und Größe
	var snd := "explosion_small"
	var vol := -8.0 + minf(radius, 6.0)
	if opts.has("sfx"):
		snd = String(opts.sfx)
		vol = -5.0
	elif opts.has("stun") and float(opts.get("knock", 1.0)) <= 0.0:
		snd = "ice_shatter"
		vol = -4.0
	elif radius >= 4.4:
		snd = "explosion_big"
		vol = -9.0 + minf(radius, 8.0)
	Sfx.play_at(snd, pos, vol, 1.0, 0.06)
	horde.explode(Vector2(pos.x, pos.z), radius, dmg, opts)


func tick_common(dt: float) -> void:
	time += dt
	if not _anims.is_empty():
		Anim.tick(_anims, time, dt)
	if _ambient != null and cam != null:
		_ambient.global_position = cam.focus + Vector3(0, 3.0, 0)
	if barrier_t > 0.0:
		barrier_t -= dt
	if lure_t > 0.0:
		lure_t -= dt
	_coin_t += dt
	if _coin_t > 0.4:
		_coin_t = 0.0
		_flush_coins()
	_xp_t += dt
	if _xp_t > 1.0:
		_xp_t = 0.0
		_flush_xp()
	# Geschosse
	var i := _proj.size() - 1
	while i >= 0:
		var p: Dictionary = _proj[i]
		p.t += dt
		var k: float = minf(p.t / p.d, 1.0)
		var pos: Vector3 = p.a.lerp(p.b, k)
		pos.y += sin(k * PI) * p.arc
		if p.n != null:
			p.n.global_position = pos
		if p.rocket:
			p.pt -= dt
			if p.pt <= 0.0:
				p.pt = 0.05
				fx.puff(pos, Color(0.9, 0.9, 0.9, 0.7), 2, 0.3)
		if k >= 1.0:
			if p.n != null:
				p.n.visible = false
				_proj_pool.append(p.n)
			_proj.remove_at(i)
			p.cb.call()
		i -= 1
	# Bodenflächen
	_zone_t -= dt
	var puff := _zone_t <= 0.0
	if puff:
		_zone_t = 0.3
	i = zones.size() - 1
	while i >= 0:
		var z: Dictionary = zones[i]
		z.t -= dt
		if z.kind == "heal" and hero != null and hero.alive and hero.pos2().distance_squared_to(z.c) < z.r2:
			hero.heal(hero.max_hp * z.dps * dt)
		if puff and z.n != null:
			var a := _rng.randf() * TAU
			var q: Vector2 = z.c + Vector2(cos(a), sin(a)) * z.r * sqrt(_rng.randf())
			var col: Color = ZONE_COL[z.kind]
			col.a = 1.0
			fx.puff(Vector3(q.x, 0.3, q.y), col, 4, 0.7)
			if z.kind == "storm" and _rng.randf() < 0.4:
				fx.lightning(Vector3(q.x, 7.0, q.y), Vector3(q.x, 0.2, q.y))
				Sfx.play_at("thunder", Vector3(q.x, 0, q.y), -13.0, 1.3, 0.5)
		if z.t <= 0.0 or z.uses <= 0.0:
			if z.n != null:
				z.n.queue_free()
			zones.remove_at(i)
		i -= 1


func leave() -> void:
	Sfx.stop_all()                      # Motor, Umgebung, Flammen: alle Schleifen enden mit der Welt
	_flush_coins()
	_flush_xp()
	if P.hero_level_up.is_connected(_on_hero_level):
		P.hero_level_up.disconnect(_on_hero_level)
	G.game = null
	G.player = null
	G.horde = null
	G.coins = null
	G.fx = null
	G.field = null
	G.cam = null
