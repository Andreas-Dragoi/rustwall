extends Node3D
## Tiere der Hauptbasis (Auftrag V3, Paket 5). Reiner Schmuck: Tiere greifen nie in den Kampf ein,
## laufen nie durch Gebäude oder Mauern (field.blocks_player) und verschwinden bei Alarm
## (Vögel fliegen auf, der Rest läuft in den Wald). Modelle aus blender/animals.py.
##
## Schmetterlinge: ein MultiMesh, Flügelschlag im Shader. Singvögel, Möwen, Hühner, Hasen, Enten, Katze, Hund:
## einzelne Nodes mit einfachen Zuständen (Clips = Zustände, die bewegliche Teile drehen).
## Fische (am Steg), Libellen (am Bach) und Glühwürmchen (ab Abend) sind Partikel.

const D = preload("res://src/data.gd")
const Models = preload("res://src/models.gd")
const Nature = preload("res://src/base_nature.gd")

const SCALE := 1.6               # Tiere etwas größer als echt, damit man sie aus der Spielsicht erkennt
const N_BUTTERFLY := [30, 50, 80]
const N_BIRD := [6, 8, 10]
const N_GULL := [3, 4, 5]
const N_CHICKEN := [4, 5, 6]
const N_RABBIT := [3, 4, 5]
const N_DUCK := 3
const FLEE_HERO := 5.0

const _SH_BUTTERFLY := """shader_type spatial;
render_mode cull_disabled;
// Flügelschlag: Punkte seitlich des Körpers (|x| > 0.02) klappen um die Längsachse.
// INSTANCE_CUSTOM.x = Schlagtempo (0 sitzt), .y = Phase, .z = Farbton-Verschiebung
varying vec3 v_col;
void vertex() {
	float side = VERTEX.x;
	float k = smoothstep(0.015, 0.05, abs(side));
	float sp = INSTANCE_CUSTOM.x;
	float a = (sin(TIME * (6.0 + sp * 16.0) + INSTANCE_CUSTOM.y * 6.28) * 0.5 + 0.5) * (0.35 + 0.85 * min(sp, 1.0)) * k;
	float ang = a * sign(side);
	VERTEX.y += abs(side) * sin(a);
	VERTEX.x = side * cos(a);
	v_col = COLOR.rgb;
	float h = INSTANCE_CUSTOM.z;
	if (h > 0.66) { v_col = v_col.bgr * vec3(1.2, 1.0, 1.4); } else if (h > 0.33) { v_col = mix(v_col, vec3(1.0, 1.0, 1.0), 0.6 * k); }
}
void fragment() {
	ALBEDO = v_col * 1.2;
	ROUGHNESS = 0.8;
}
"""

var w: Node3D
var nature: Node3D
var animals: Array = []          # {kind, n: Node3D, st, t, to: Vector3, home: Vector3, ...}
var last_us := 0.0
var _bf_mm: MultiMesh
var _bf: Array = []              # {p: Vector3, to: Vector3, st: 0 fliegt / 1 sitzt, t, ph}
var _rng := RandomNumberGenerator.new()
var _alarm := false
var _alarm_t := 0.0
var _fireflies: CPUParticles3D
var _fish: CPUParticles3D
var _dragon: CPUParticles3D
var _jetty := Vector3.ZERO
var _sea_c := Vector3.ZERO
var _fly_t := 0.0


func setup(world: Node3D, nat: Node3D) -> void:
	w = world
	nature = nat
	_rng.randomize()
	var dir := Vector2(-Nature.DIAG, Nature.DIAG)
	_jetty = Vector3(Nature.JETTY_AT.x, 0.62, Nature.JETTY_AT.y)
	var sea := Nature.JETTY_AT + dir * 16.0
	_sea_c = Vector3(sea.x, 0, sea.y)
	_make_butterflies()
	_spawn_all()
	_make_particles()


func _spawn_all() -> void:
	var q := G.quality()
	var dir := Vector2(-Nature.DIAG, Nature.DIAG)
	for i in N_BIRD[q]:
		_add("bird", "a_bird", _perch())
	for i in N_GULL[q]:
		_add("gull", "a_gull", _sea_c + Vector3(_rng.randf_range(-8, 8), 6.0, _rng.randf_range(-8, 8)))
	var coop := _home_of("quartier")
	for i in N_CHICKEN[q]:
		_add("chicken", "a_chicken", _free_near(coop, 4.0))
	for i in N_RABBIT[q]:
		_add("rabbit", "a_rabbit", _edge_spot())
	for i in N_DUCK:
		var c := Nature.JETTY_AT + dir * _rng.randf_range(6.0, 11.0) - dir.orthogonal() * _rng.randf_range(3.0, 5.0)
		_add("duck", "a_duck", Vector3(c.x, 0.0, c.y))
	_add("cat", "a_cat", _free_near(coop, 2.5))
	_add("dog", "a_dog", _free_near(_home_of("tor"), 3.0))


func _add(kind: String, model: String, p: Vector3) -> void:
	if not Models.has_glb(model):
		return
	var n := Models.glb(model)
	n.scale = Vector3.ONE * SCALE
	n.position = p
	n.rotation.y = _rng.randf() * TAU
	add_child(n)
	# Schatten nur für Hund und Katze (spart Zeichenaufrufe im Schattendurchgang)
	if not (kind in ["dog", "cat"]) or G.quality() == 0:
		for mi in n.find_children("*", "MeshInstance3D", true, false):
			(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var a := {"kind": kind, "n": n, "st": "idle", "t": _rng.randf_range(0.5, 3.0), "to": p, "home": p, "ph": _rng.randf() * TAU,
		"body": Models.find(n, "body"), "head": Models.find(n, "head"), "tail": Models.find(n, "tail"),
		"wl": Models.find(n, "wing_l"), "wr": Models.find(n, "wing_r"), "ears": Models.find(n, "ears"), "hidden": false,
		"legs": [Models.find(n, "leg_fl"), Models.find(n, "leg_br"), Models.find(n, "leg_fr"), Models.find(n, "leg_bl")], "follow": 0.0, "from": p, "k": 0.0}
	if kind in ["bird", "gull"]:
		a.st = "fly" if kind == "gull" else "sit"
	if kind == "cat":
		a.st = "sleep"
		a.t = _rng.randf_range(6.0, 14.0)
	animals.append(a)


# ---------------------------------------------------------------- Orte
func _home_of(key: String) -> Vector3:
	for id in w.nodes:
		var s: Node3D = w.nodes[id]
		if is_instance_valid(s) and s.key == key:
			var p: Vector2 = s.mid
			if key == "tor":
				var bm: Vector2 = w.bunker_node.mid if w.bunker_node != null else Vector2.ZERO
				p = s.mid + (bm - s.mid).normalized() * 3.0
			return Vector3(p.x, 0, p.y)
	var b: Vector2 = w.respawn_point()
	return Vector3(b.x + 3.0, 0, b.y + 1.0)


func _blocked(p: Vector3) -> bool:
	return w.field.blocks_player(Vector2(p.x, p.z))


func _free_near(c: Vector3, r: float) -> Vector3:
	for i in 24:
		var a := _rng.randf() * TAU
		var p := c + Vector3(cos(a), 0, sin(a)) * _rng.randf_range(r * 0.4, r * (1.0 + i * 0.1))
		if not _blocked(p) and not Nature.in_brook(Vector2(p.x, p.z), 2.2):
			return p
	return Vector3(w.respawn_point().x, 0, w.respawn_point().y)


func _edge_spot() -> Vector3:
	var half := P.grid_size() * 0.5 * D.CELL
	for i in 30:
		var side := _rng.randi() % 4
		var t := _rng.randf_range(-half, half)
		var d := half + _rng.randf_range(3.0, 8.0)
		var p := [Vector2(t, -d), Vector2(d, t), Vector2(t, d), Vector2(-d, t)][side] as Vector2
		var p3 := Vector3(p.x, 0, p.y)
		if not _blocked(p3) and not Nature.in_sea(p, -4.0) and not Nature.in_brook(p, 3.0):
			return p3
	return Vector3(0, 0, half + 4.0)


## Sitzplatz für Singvögel: Baumkrone im Baufeld, Mauer, Dach – oder ein freies Fleckchen Boden (picken).
func _perch() -> Vector3:
	var r := _rng.randf()
	if r < 0.4 and nature != null and not nature.perch_spots.is_empty():
		return nature.perch_spots[_rng.randi() % nature.perch_spots.size()]
	if r < 0.6 and not w.walls.is_empty():
		var wl = w.walls[_rng.randi() % w.walls.size()]
		if wl.alive:
			return Vector3(wl.mid.x, 2.2, wl.mid.y)
	if r < 0.75 and not w.nodes.is_empty():
		var ids: Array = w.nodes.keys()
		var s: Node3D = w.nodes[ids[_rng.randi() % ids.size()]]
		if is_instance_valid(s) and s.def.cat in ["core", "prod", "special"]:
			return Vector3(s.mid.x + _rng.randf_range(-0.8, 0.8), Models.height(s.model) * 0.92, s.mid.y + _rng.randf_range(-0.8, 0.8))
	var half := P.grid_size() * 0.5 * D.CELL - 2.0
	return _free_near(Vector3(_rng.randf_range(-half, half), 0, _rng.randf_range(-half, half)), 3.0)


# ---------------------------------------------------------------- Schmetterlinge
func _make_butterflies() -> void:
	if not Models.has_glb("a_butterfly"):
		return
	var n: int = N_BUTTERFLY[G.quality()]
	_bf_mm = MultiMesh.new()
	_bf_mm.transform_format = MultiMesh.TRANSFORM_3D
	_bf_mm.use_custom_data = true
	_bf_mm.mesh = Models.glb_mesh("a_butterfly", "body")
	_bf_mm.instance_count = n
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = _bf_mm
	var m := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = _SH_BUTTERFLY
	m.shader = sh
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.custom_aabb = AABB(Vector3(-70, -1, -70), Vector3(140, 12, 140))
	add_child(mi)
	for i in n:
		var p := _flower(Vector3.ZERO, 50.0)
		_bf.append({"p": p + Vector3(0, 1.0, 0), "to": p, "st": 0, "t": 0.0, "ph": _rng.randf(), "hue": _rng.randf(), "yaw": 0.0})


func _flower(near: Vector3, r: float) -> Vector3:
	if nature == null or nature.flower_spots.is_empty():
		return near + Vector3(_rng.randf_range(-r, r), 0, _rng.randf_range(-r, r))
	for i in 10:
		var f: Vector2 = nature.flower_spots[_rng.randi() % nature.flower_spots.size()]
		if Vector2(near.x, near.z).distance_to(f) > r:
			continue
		var p := Vector3(f.x + _rng.randf_range(-1.0, 1.0), 0.42, f.y + _rng.randf_range(-1.0, 1.0))
		if not _blocked(p) and not nature.on_path(Vector2(p.x, p.z)):
			return p
	return near + Vector3(_rng.randf_range(-6, 6), 0.42, _rng.randf_range(-6, 6))


func _tick_butterflies(dt: float) -> void:
	if _bf_mm == null:
		return
	var vis := not _alarm
	for i in _bf.size():
		var b: Dictionary = _bf[i]
		var p: Vector3 = b.p
		if b.st == 1:
			b.t -= dt
			if b.t <= 0.0:
				b.st = 0
				b.to = _flower(p, 14.0)
		else:
			var to: Vector3 = b.to
			var d := Vector3(to.x - p.x, 0, to.z - p.z)
			var dl := d.length()
			var fly_h := 1.1 + sin(w.time * 1.7 + b.ph * 9.0) * 0.35
			if _blocked(p):
				fly_h = 5.0                                  # über Gebäude hinweg
			var ty: float = to.y if dl < 1.2 else fly_h
			p.y = lerpf(p.y, ty, minf(1.0, dt * 2.5))
			if dl < 0.15:
				b.st = 1
				b.t = _rng.randf_range(2.0, 5.0)
				p = to
			else:
				var wob := Vector3(sin(w.time * 3.1 + b.ph * 20.0), 0, cos(w.time * 2.7 + b.ph * 13.0)) * 0.6
				var v := d / dl * 1.8 + wob
				p += v * dt
				b.yaw = atan2(v.x, v.z)
		b.p = p
		var s := 0.0 if not vis else SCALE * 1.15
		_bf_mm.set_instance_transform(i, Transform3D(Basis(Vector3.UP, b.yaw).scaled(Vector3(s, s, s)), p))
		_bf_mm.set_instance_custom_data(i, Color(1.0 if b.st == 0 else 0.0, b.ph, b.hue, 0))


# ---------------------------------------------------------------- Partikel
func _make_particles() -> void:
	_fireflies = _particles(Color(1.0, 0.95, 0.45), [16, 28, 40][G.quality()], 5.0, Vector3(24, 1.2, 20), 0.08)
	_fireflies.gravity = Vector3(0, 0.05, 0)
	_fireflies.initial_velocity_min = 0.2
	_fireflies.initial_velocity_max = 0.6
	_fireflies.spread = 180.0
	_fish = _particles(Color(0.75, 0.82, 0.9), 3, 1.1, Vector3(6, 0.0, 6), 0.0)
	_fish.mesh = _fish_mesh()
	_fish.direction = Vector3(0, 1, 0)
	_fish.spread = 25.0
	_fish.initial_velocity_min = 3.5
	_fish.initial_velocity_max = 4.5
	_fish.gravity = Vector3(0, -9.0, 0)
	_fish.explosiveness = 0.0
	_fish.randomness = 1.0
	_fish.global_position = _jetty + Vector3(-5.0, -0.6, 5.0)
	_dragon = _particles(Color(0.3, 0.75, 0.95), [4, 6, 8][G.quality()], 3.0, Vector3(4, 0.4, 14), 0.0)
	var dm := BoxMesh.new()
	dm.size = Vector3(0.36, 0.04, 0.08)
	_dragon.mesh = dm
	_dragon.initial_velocity_min = 1.5
	_dragon.initial_velocity_max = 3.0
	_dragon.spread = 180.0
	_dragon.gravity = Vector3.ZERO
	_dragon.angular_velocity_min = -300.0
	_dragon.angular_velocity_max = 300.0
	_dragon.global_position = Vector3(52.5, 0.9, -22.0)


func _fish_mesh() -> Mesh:
	var bm := BoxMesh.new()
	bm.size = Vector3(0.12, 0.38, 0.06)
	return bm


func _particles(col: Color, amount: int, life: float, ext: Vector3, size: float) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	if size > 0.0:
		var sm := SphereMesh.new()
		sm.radius = size
		sm.height = size * 2.0
		sm.radial_segments = 6
		sm.rings = 3
		p.mesh = sm
	p.amount = amount
	p.lifetime = life
	p.preprocess = life
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = ext
	p.local_coords = false
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	p.material_override = m
	var g := Gradient.new()
	g.set_color(0, Color(col.r, col.g, col.b, 0.0))
	g.add_point(0.15, col)
	g.add_point(0.85, col)
	g.set_color(g.get_point_count() - 1, Color(col.r, col.g, col.b, 0.0))
	p.color_ramp = g
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(p)
	return p


# ---------------------------------------------------------------- Tiere
func _hero2() -> Vector2:
	if w.hero != null and w.hero.alive:
		return Vector2(w.hero.global_position.x, w.hero.global_position.z)
	return Vector2(1.0e6, 1.0e6)


## Schritt am Boden: nie in Gebäude, Mauern, Wasser.
func _walk(a: Dictionary, to: Vector3, sp: float, dt: float) -> bool:
	var n: Node3D = a.n
	var p := n.position
	var d := Vector3(to.x - p.x, 0, to.z - p.z)
	var dl := d.length()
	if dl < 0.2:
		return true
	var np := p + d / dl * minf(sp * dt, dl)
	if _blocked(np) or Nature.in_brook(Vector2(np.x, np.z), 1.6):
		var side := Vector3(-d.z, 0, d.x) / dl
		np = p + side * sp * dt
		if _blocked(np):
			a.to = p
			return true
	n.position = Vector3(np.x, p.y, np.z)
	n.rotation.y = lerp_angle(n.rotation.y, atan2(d.x, d.z), minf(1.0, dt * 8.0))
	return false


func _wings(a: Dictionary, amp: float, speed: float) -> void:
	var k := sin(w.time * speed + a.ph) * amp
	if a.wl != null:
		a.wl.rotation.z = k
	if a.wr != null:
		a.wr.rotation.z = -k


func _fly_to(a: Dictionary, to: Vector3) -> void:
	a.st = "fly"
	a.from = a.n.position
	a.to = to
	a.k = 0.0
	if a.kind == "bird":
		Sfx.play_at("bird_flap", a.n.position, -16.0, 1.0, 0.2)


func _tick_bird(a: Dictionary, dt: float) -> void:
	var n: Node3D = a.n
	var hp := _hero2()
	match a.st:
		"sit", "peck":
			_wings(a, 0.0, 1.0)
			a.t -= dt
			var body: Node3D = a.body
			if a.st == "peck" and body != null:
				body.rotation.x = maxf(0.0, sin(w.time * 7.0 + a.ph)) * 0.5
			if hp.distance_to(Vector2(n.position.x, n.position.z)) < FLEE_HERO or a.t <= 0.0:
				if body != null:
					body.rotation.x = 0.0
				_fly_to(a, _perch())
				if _rng.randf() < 0.3:
					Sfx.play_at("bird_chirp", n.position, -14.0, _rng.randf_range(0.9, 1.2), 0.3)
		"fly":
			var dist: float = Vector2(a.from.x, a.from.z).distance_to(Vector2(a.to.x, a.to.z))
			a.k = minf(1.0, a.k + dt * 6.0 / maxf(dist, 4.0))
			var p: Vector3 = a.from.lerp(a.to, a.k)
			p.y += sin(a.k * PI) * (3.0 + dist * 0.15)
			var d: Vector3 = a.to - a.from
			n.rotation.y = atan2(d.x, d.z)
			n.position = p
			_wings(a, 0.9, 24.0)
			if a.k >= 1.0:
				a.st = "peck" if a.to.y < 0.1 else "sit"
				a.t = _rng.randf_range(4.0, 12.0)


func _tick_gull(a: Dictionary, dt: float) -> void:
	var n: Node3D = a.n
	match a.st:
		"fly":
			a.ph += dt * 0.35
			var r := 9.0 + sin(a.ph * 0.7) * 3.0
			var c := _sea_c + Vector3(0, 7.0 + sin(a.ph * 1.3) * 1.0, 0)
			var p := c + Vector3(cos(a.ph), 0, sin(a.ph)) * r
			var d := p - n.position
			n.position = p
			if d.length() > 0.001:
				n.rotation.y = atan2(d.x, d.z)
			n.rotation.z = -0.25
			_wings(a, 0.25 + 0.3 * maxf(0.0, sin(w.time * 0.8 + a.ph)), 7.0)
			a.t -= dt
			if a.t <= 0.0:
				a.t = _rng.randf_range(10.0, 25.0)
				if _rng.randf() < 0.4:
					a.st = "land"
					a.from = n.position
					a.to = _jetty + Vector3(-Nature.DIAG, 0, Nature.DIAG) * _rng.randf_range(3.0, 11.0)
					a.k = 0.0
				elif _rng.randf() < 0.5:
					Sfx.play_at("gull_call", n.position, -12.0, _rng.randf_range(0.9, 1.15), 0.5)
		"land":
			a.k = minf(1.0, a.k + dt * 0.3)
			n.position = a.from.lerp(a.to, a.k)
			n.rotation.z = 0.0
			_wings(a, 0.8, 16.0)
			if a.k >= 1.0:
				a.st = "sit"
				a.t = _rng.randf_range(6.0, 15.0)
		"sit":
			_wings(a, 0.0, 1.0)
			a.t -= dt
			if a.t <= 0.0 or _hero2().distance_to(Vector2(n.position.x, n.position.z)) < FLEE_HERO:
				a.st = "fly"
				a.t = _rng.randf_range(8.0, 20.0)
				Sfx.play_at("gull_call", n.position, -12.0, 1.0, 0.5)


func _tick_ground(a: Dictionary, dt: float) -> void:
	var n: Node3D = a.n
	var kind: String = a.kind
	var hp := _hero2()
	var p2 := Vector2(n.position.x, n.position.z)
	var hd := hp.distance_to(p2)
	var head: Node3D = a.head
	match kind:
		"chicken":
			var veh: bool = w.hero != null and w.hero.mounted
			if hd < (5.0 if veh else 2.2) and a.st != "flee":
				a.st = "flee"
				var away := (p2 - hp).normalized()
				a.to = _free_near(Vector3(p2.x + away.x * 4.0, 0, p2.y + away.y * 4.0), 1.0)
				Sfx.play_at("chicken_cluck", n.position, -12.0, _rng.randf_range(1.0, 1.3), 0.4)
			match a.st:
				"flee":
					_wings(a, 0.0, 1.0)
					if a.wl != null:
						a.wl.rotation.z = sin(w.time * 30.0) * 0.6
					n.position.y = absf(sin(w.time * 12.0)) * 0.15
					if _walk(a, a.to, 4.5, dt):
						a.st = "idle"
						a.t = 1.0
						n.position.y = 0.0
				"walk":
					if _walk(a, a.to, 1.0, dt):
						a.st = "peck"
						a.t = _rng.randf_range(1.0, 3.0)
				"peck":
					if head != null:
						head.rotation.x = maxf(0.0, sin(w.time * 8.0 + a.ph)) * 0.9
					a.t -= dt
					if a.t <= 0.0:
						if head != null:
							head.rotation.x = 0.0
						a.st = "idle"
						a.t = _rng.randf_range(0.5, 2.0)
						if _rng.randf() < 0.15:
							Sfx.play_at("chicken_cluck", n.position, -18.0, _rng.randf_range(0.9, 1.2), 0.5)
				_:
					a.t -= dt
					if a.t <= 0.0:
						a.st = "walk"
						a.to = _free_near(a.home, 4.0)
		"rabbit":
			var ears: Node3D = a.ears
			if hd < 6.0 and a.st != "flee":
				a.st = "flee"
				var out := p2.normalized()
				a.to = Vector3(out.x, 0, out.y) * (P.grid_size() * D.CELL * 0.5 + 14.0)
			match a.st:
				"flee", "hop":
					var ph := fmod(w.time * (5.0 if a.st == "flee" else 3.0) + a.ph, 1.0)
					n.position.y = sin(ph * PI) * (0.35 if a.st == "flee" else 0.2)
					var done := _walk(a, a.to, 6.0 if a.st == "flee" else 1.4, dt)
					if done:
						n.position.y = 0.0
						if a.st == "flee":
							a.st = "gone"
							n.visible = false
							a.t = _rng.randf_range(15.0, 30.0)
						else:
							a.st = "idle"
							a.t = _rng.randf_range(1.0, 4.0)
				"stand":
					var body: Node3D = a.body
					if body != null:
						body.rotation.x = -0.6
					if ears != null:
						ears.rotation.x = sin(w.time * 3.0) * 0.15
					a.t -= dt
					if a.t <= 0.0:
						if body != null:
							body.rotation.x = 0.0
						a.st = "idle"
						a.t = 1.0
				"gone":
					a.t -= dt
					if a.t <= 0.0:
						n.position = _edge_spot()
						n.visible = true
						a.home = n.position
						a.st = "idle"
				_:
					a.t -= dt
					if a.t <= 0.0:
						if _rng.randf() < 0.35:
							a.st = "stand"
							a.t = _rng.randf_range(1.5, 3.0)
						else:
							a.st = "hop"
							a.to = _free_near(a.home, 4.0)
		"duck":
			var c: Vector3 = a.home
			a.k += dt * 0.25
			var p := c + Vector3(cos(a.k + a.ph), 0, sin(a.k + a.ph)) * 2.2
			p.y = 0.02 + sin(w.time * 1.4 + a.ph) * 0.04
			var d := p - n.position
			n.position = p
			if d.length() > 0.0001:
				n.rotation.y = atan2(d.x, d.z)
			a.t -= dt
			if head != null:
				head.rotation.x = 1.6 if a.st == "dive" else 0.0
			var body: Node3D = a.body
			if body != null:
				body.rotation.x = 0.9 if a.st == "dive" else 0.0
			if a.t <= 0.0:
				if a.st == "dive":
					a.st = "swim"
					a.t = _rng.randf_range(5.0, 12.0)
				else:
					a.st = "dive"
					a.t = 1.2
					if _rng.randf() < 0.3:
						Sfx.play_at("duck_quack", n.position, -14.0, 1.0, 0.5)
		"cat":
			var tail: Node3D = a.tail
			if tail != null:
				tail.rotation.y = sin(w.time * (1.0 if a.st == "sleep" else 2.5) + a.ph) * 0.4
			match a.st:
				"sleep":
					n.scale = Vector3(SCALE, SCALE * (0.75 + sin(w.time * 1.5) * 0.02), SCALE)
					if head != null:
						head.rotation.x = 0.5
					a.t -= dt
					if a.t <= 0.0:
						n.scale = Vector3.ONE * SCALE
						if head != null:
							head.rotation.x = 0.0
						a.st = "walk"
						a.to = _cat_target()
				"walk":
					if _walk(a, a.to, 1.3, dt):
						a.st = "sit" if _rng.randf() < 0.6 else "rub"
						a.t = _rng.randf_range(3.0, 7.0)
				"sit", "rub":
					a.t -= dt
					if a.st == "rub":
						n.rotation.y += dt * 1.5
					if head != null:
						head.rotation.y = sin(w.time * 0.7) * 0.5
					if a.t <= 0.0:
						if head != null:
							head.rotation.y = 0.0
						if _rng.randf() < 0.4:
							a.st = "sleep"
							a.t = _rng.randf_range(10.0, 20.0)
							a.to = a.home
						else:
							a.st = "walk"
							a.to = _cat_target()
						if _rng.randf() < 0.2:
							Sfx.play_at("cat_meow", n.position, -16.0, 1.0, 0.5)
		"dog":
			_tick_dog(a, dt, hp, hd)


func _cat_target() -> Vector3:
	# zu einem Bewohner (streicht um ihn herum) oder zurück zum Quartier
	if w.has_method("friends"):
		var f: Array = w.friends()
		if f.size() > 1 and _rng.randf() < 0.6:
			var q: Vector2 = f[_rng.randi_range(1, f.size() - 1)]
			return _free_near(Vector3(q.x, 0, q.y), 1.2)
	return _free_near(_home_of("quartier"), 3.0)


func _tick_dog(a: Dictionary, dt: float, hp: Vector2, hd: float) -> void:
	var n: Node3D = a.n
	var tail: Node3D = a.tail
	var moving := false
	if tail != null:
		tail.rotation.y = sin(w.time * (14.0 if a.follow > 0.0 else 5.0)) * 0.6
	if hd < 4.0 and a.follow <= 0.0 and a.st != "follow":
		a.st = "follow"
		a.follow = 10.0
		Sfx.play_at("dog_bark", n.position, -12.0, 1.1, 0.5)
	match a.st:
		"follow":
			a.follow -= dt
			if hd > 2.0:
				moving = not _walk(a, Vector3(hp.x, 0, hp.y), 6.0 if hd > 6.0 else 4.0, dt)
			if a.follow <= 0.0:
				a.st = "walk"
				a.to = _free_near(a.home, 2.0)
				a.follow = -12.0        # danach eine Weile nicht wieder folgen
		"walk":
			moving = not _walk(a, a.to, 2.2, dt)
			if not moving:
				a.st = "idle"
				a.t = _rng.randf_range(2.0, 6.0)
		"sit":
			a.t -= dt
			var body: Node3D = a.body
			if body != null:
				body.rotation.x = -0.35
			if a.t <= 0.0:
				if body != null:
					body.rotation.x = 0.0
				a.st = "idle"
				a.t = 2.0
		_:
			a.t -= dt
			if a.follow < 0.0:
				a.follow = minf(0.0, a.follow + dt)
			if a.t <= 0.0:
				a.home = _home_of("tor")
				if _rng.randf() < 0.4:
					a.st = "sit"
					a.t = _rng.randf_range(4.0, 9.0)
				else:
					a.st = "walk"
					a.to = _free_near(a.home, 3.0)
	# Beine
	var k := sin(w.time * 14.0) * (0.6 if moving else 0.0)
	var legs: Array = a.legs
	for i in legs.size():
		if legs[i] != null:
			legs[i].rotation.x = k * (1.0 if i % 2 == 0 else -1.0)


# ---------------------------------------------------------------- Alarm
func _set_alarm(on: bool) -> void:
	_alarm = on
	_alarm_t = 0.0
	for a in animals:
		var n: Node3D = a.n
		if on:
			if a.kind in ["bird", "gull"]:
				_fly_to(a, n.position + Vector3(_rng.randf_range(-30, 30), 18.0, _rng.randf_range(-30, 30)))
			elif a.kind == "dog":
				a.st = "bark"
				a.t = 2.5
			else:
				a.st = "run_off"
				var p2 := Vector2(n.position.x, n.position.z)
				var out := p2.normalized() if p2.length() > 0.1 else Vector2(0, 1)
				a.to = Vector3(out.x, 0, out.y) * 70.0
		else:
			n.visible = true
			a.st = "idle"
			a.t = _rng.randf_range(0.5, 2.0)
			match a.kind:
				"bird":
					n.position = _perch()
					a.st = "sit"
				"gull":
					a.st = "fly"
				"chicken", "cat":
					n.position = _free_near(_home_of("quartier"), 3.0)
					a.home = n.position
					if a.kind == "cat":
						a.st = "sleep"
				"rabbit":
					n.position = _edge_spot()
					a.home = n.position
				"dog":
					n.position = _free_near(_home_of("tor"), 3.0)
					a.home = n.position
				"duck":
					n.position = a.home


func _tick_alarm(a: Dictionary, dt: float) -> void:
	var n: Node3D = a.n
	if not n.visible:
		return
	match a.kind:
		"bird", "gull":
			a.k = minf(1.0, a.k + dt * 0.35)
			n.position = a.from.lerp(a.to, a.k)
			_wings(a, 0.9, 24.0)
			if a.k >= 1.0:
				n.visible = false
		"dog":
			if a.st == "bark":
				a.t -= dt
				var body: Node3D = a.body
				if body != null:
					body.rotation.x = -absf(sin(w.time * 10.0)) * 0.15
				if fmod(a.t, 0.8) < dt:
					Sfx.play_at("dog_bark", n.position, -8.0, 1.0, 0.3)
				if a.t <= 0.0:
					if body != null:
						body.rotation.x = 0.0
					a.st = "run_off"
					var home: Vector2 = w.respawn_point()
					a.to = Vector3(home.x, 0, home.y)
			elif _walk(a, a.to, 7.0, dt):
				n.visible = false
		"duck":
			n.visible = false
		_:
			n.position.y = absf(sin(w.time * 12.0 + a.ph)) * 0.12
			if _walk(a, a.to, 6.5, dt) or n.position.length() > 62.0:
				n.visible = false
			elif _blocked(n.position + (a.to - n.position).normalized() * 0.5):
				n.visible = false                  # kein Durchkommen: verschwindet (läuft weg)


# ---------------------------------------------------------------- jedes Bild
func _process(dt: float) -> void:
	var t0 := Time.get_ticks_usec()
	var alarm: bool = w.mode != "peace"
	if alarm != _alarm:
		_set_alarm(alarm)
	if _alarm:
		for a in animals:
			_tick_alarm(a, dt)
	else:
		for a in animals:
			if not a.n.visible and a.st != "gone":
				continue
			match a.kind:
				"bird":
					_tick_bird(a, dt)
				"gull":
					_tick_gull(a, dt)
				_:
					_tick_ground(a, dt)
	_tick_butterflies(dt)
	var night: bool = w.daytime in ["abend", "nacht"]
	_fireflies.emitting = night and not _alarm
	if w.cam != null:
		_fireflies.global_position = w.cam.focus + Vector3(0, 0.9, 0)
	_fish.emitting = not _alarm
	_dragon.emitting = not _alarm and not night
	last_us = float(Time.get_ticks_usec() - t0)


## Wie viele Tierarten sind gerade sichtbar (im Umkreis r der Kamera)?
func kinds_visible(c: Vector3, r: float) -> Array:
	var out := {}
	for a in animals:
		if a.n.visible and Vector2(a.n.position.x - c.x, a.n.position.z - c.z).length() < r:
			out[a.kind] = true
	if _bf_mm != null and not _alarm:
		for b in _bf:
			if Vector2(b.p.x - c.x, b.p.z - c.z).length() < r:
				out["butterfly"] = true
				break
	return out.keys()


## Steht ein Bodentier gerade in einem Gebäude oder einer Mauer? (Test)
func animals_in_buildings() -> int:
	var n := 0
	for a in animals:
		if a.n.visible and a.kind in ["chicken", "rabbit", "cat", "dog"] and _blocked(a.n.position):
			n += 1
	return n
