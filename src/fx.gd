extends Node3D
## Effekte aus wiederverwendeten Objekten (Pool): Leuchtspuren, Mündungsfeuer,
## Einschläge, Explosionen, Lichtringe, Blitze. Im Spiel wird nichts neu erzeugt/gelöscht.

const MK = preload("res://src/mk.gd")

const N_TRACER := 48
const N_PUFF := 28
const N_FLASH := 14
const N_RING := 10
const N_BOOM := 8

var wind := Vector3(0.25, 0.0, 0.1)     # Schub für Rauch und Dampf (set_wind)
var wind_set := false
var _wind_emitters: Array = []
var _tracers: Array = []
var _ti := 0
var _puffs: Array[CPUParticles3D] = []
var _pi := 0
var _flashes: Array = []
var _fi := 0
var _rings: Array = []
var _ri := 0
var _booms: Array = []
var _bi := 0
var _light: OmniLight3D
var _light_t := 0.0
var _rng := RandomNumberGenerator.new()
var _texts: Array = []
var _xi := 0
var _splats := 0


func _ready() -> void:
	var box := BoxMesh.new()
	box.size = Vector3(1, 1, 1)
	for i in N_TRACER:
		var m := MeshInstance3D.new()
		m.mesh = box
		m.material_override = MK.glow(Color(1, 0.9, 0.55), true)
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		m.visible = false
		add_child(m)
		_tracers.append({"n": m, "t": 0.0, "d": 0.06})
	var pm := BoxMesh.new()
	pm.size = Vector3(0.09, 0.09, 0.09)
	for i in N_PUFF:
		var p := CPUParticles3D.new()
		p.mesh = pm
		p.one_shot = true
		p.emitting = false
		p.explosiveness = 0.95
		p.amount = 10
		p.lifetime = 0.45
		p.direction = Vector3.UP
		p.spread = 70.0
		p.initial_velocity_min = 1.5
		p.initial_velocity_max = 4.5
		p.gravity = Vector3(0, -11, 0)
		p.scale_amount_min = 0.6
		p.scale_amount_max = 1.5
		var pmat := StandardMaterial3D.new()
		pmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		pmat.vertex_color_use_as_albedo = true
		p.material_override = pmat
		p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(p)
		_puffs.append(p)
	# Mündungsfeuer: kleiner Stern aus zwei gekreuzten Quadern
	var fst := MK.begin()
	MK.box(fst, Vector3(0, 0, 0.22), Vector3(0.1, 0.1, 0.5), Color.WHITE)
	MK.box(fst, Vector3(0, 0, 0.1), Vector3(0.34, 0.07, 0.07), Color.WHITE)
	MK.box(fst, Vector3(0, 0, 0.1), Vector3(0.07, 0.34, 0.07), Color.WHITE)
	var fmesh := fst.commit()
	for i in N_FLASH:
		var m2 := MeshInstance3D.new()
		m2.mesh = fmesh
		m2.material_override = MK.glow(Color(1.0, 0.82, 0.4))
		m2.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		m2.visible = false
		add_child(m2)
		_flashes.append({"n": m2, "t": 0.0})
	var tor := TorusMesh.new()
	tor.inner_radius = 0.9
	tor.outer_radius = 1.0
	tor.rings = 28
	tor.ring_segments = 4
	for i in N_RING:
		var m3 := MeshInstance3D.new()
		m3.mesh = tor
		m3.material_override = MK.glow(Color.WHITE, true)
		m3.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		m3.visible = false
		add_child(m3)
		_rings.append({"n": m3, "t": 0.0, "d": 0.5, "r": 3.0, "c": Color.WHITE})
	var sph := SphereMesh.new()
	sph.radius = 1.0
	sph.height = 2.0
	sph.radial_segments = 12
	sph.rings = 6
	for i in N_BOOM:
		var m4 := MeshInstance3D.new()
		m4.mesh = sph
		m4.material_override = MK.glow(Color(1, 0.6, 0.2), true)
		m4.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		m4.visible = false
		add_child(m4)
		_booms.append({"n": m4, "t": 0.0, "d": 0.35, "r": 3.0, "c": Color.WHITE})
	for i in 14:
		var l := Label3D.new()
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.no_depth_test = true
		l.fixed_size = true
		l.pixel_size = 0.0011
		l.font = load("res://src/ui.gd").font(true)
		l.font_size = 44
		l.outline_size = 12
		l.outline_modulate = Color("081526")
		l.visible = false
		add_child(l)
		_texts.append({"n": l, "t": 0.0})
	_light = OmniLight3D.new()
	_light.omni_range = 9.0
	_light.light_color = Color(1.0, 0.75, 0.4)
	_light.light_energy = 0.0
	add_child(_light)


## Leuchtspur von a nach b.
func tracer(a: Vector3, b: Vector3, col := Color(1, 0.9, 0.55), width := 0.05, dur := 0.06) -> void:
	var d := b - a
	var l := d.length()
	if l < 0.05:
		return
	var tr: Dictionary = _tracers[_ti]
	_ti = (_ti + 1) % N_TRACER
	var m: MeshInstance3D = tr.n
	var z := d / l
	var x := z.cross(Vector3.UP)
	if x.length_squared() < 0.001:
		x = Vector3.RIGHT
	x = x.normalized()
	var y := z.cross(x).normalized()
	m.global_transform = Transform3D(Basis(x * width, y * width, z * l), a + d * 0.5)
	(m.material_override as StandardMaterial3D).albedo_color = col
	m.visible = true
	tr.t = dur
	tr.d = dur


func flash(pos: Vector3, dir: Vector3, size := 1.0, light := false) -> void:
	var f: Dictionary = _flashes[_fi]
	_fi = (_fi + 1) % N_FLASH
	var m: MeshInstance3D = f.n
	var z := dir.normalized()
	var x := z.cross(Vector3.UP)
	if x.length_squared() < 0.001:
		x = Vector3.RIGHT
	x = x.normalized()
	var y := z.cross(x)
	var b := Basis(x, y, z) * Basis(Vector3.BACK, _rng.randf() * TAU)
	m.global_transform = Transform3D(b.scaled(Vector3(size, size, size)), pos)
	m.visible = true
	f.t = 0.045
	if light:
		_light.global_position = pos + Vector3(0, 0.5, 0)
		_light.light_energy = 2.2
		_light_t = 0.07


func puff(pos: Vector3, col: Color, amount := 8, speed := 1.0) -> void:
	var p := _puffs[_pi]
	_pi = (_pi + 1) % N_PUFF
	p.global_position = pos
	p.amount = amount
	p.color = col
	p.initial_velocity_max = 4.5 * speed
	p.restart()
	p.emitting = true


func ring(pos: Vector3, radius: float, col: Color, dur := 0.5) -> void:
	var r: Dictionary = _rings[_ri]
	_ri = (_ri + 1) % N_RING
	r.n.global_position = Vector3(pos.x, 0.08, pos.z)
	r.n.visible = true
	r.t = dur
	r.d = dur
	r.r = radius
	r.c = col


func explosion(pos: Vector3, radius: float, col := Color(1.0, 0.55, 0.15)) -> void:
	var b: Dictionary = _booms[_bi]
	_bi = (_bi + 1) % N_BOOM
	b.n.global_position = pos
	b.n.visible = true
	b.t = 0.32
	b.d = 0.32
	b.r = radius * 0.75
	b.c = col
	ring(pos, radius * 1.15, Color(1, 0.85, 0.6), 0.4)
	puff(pos + Vector3(0, 0.3, 0), Color(0.25, 0.22, 0.2), 22, 1.8)
	puff(pos + Vector3(0, 0.5, 0), col, 14, 2.2)
	_light.global_position = pos + Vector3(0, 1.5, 0)
	_light.light_energy = 5.0
	_light_t = 0.18
	if G.cam:
		G.cam.shake(clampf(radius * 0.05, 0.08, 0.3))
	G.vibrate(25)


## Aufsteigender Text in der Welt (Beute, Volltreffer).
func float_text(pos: Vector3, text: String, col := Color("FFD23E")) -> void:
	var x: Dictionary = _texts[_xi]
	_xi = (_xi + 1) % _texts.size()
	x.n.text = text
	x.n.modulate = col
	x.n.global_position = pos
	x.n.visible = true
	x.t = 0.9


## Grüner Schleimspritzer beim Zerplatzen (höchstens ein paar pro Bild).
func splat(pos: Vector3, col: Color, big := false) -> void:
	if _splats >= 4 and not big:
		return
	_splats += 1
	puff(pos, col, 18 if big else 7, 1.6 if big else 1.0)
	if big:
		ring(pos, 4.0, col, 0.5)


## Zackiger Blitz zwischen zwei Punkten (Tesla).
func lightning(a: Vector3, b: Vector3) -> void:
	var prev := a
	var steps := 4
	for i in range(1, steps + 1):
		var p := a.lerp(b, float(i) / steps)
		if i < steps:
			p += Vector3(_rng.randf_range(-0.4, 0.4), _rng.randf_range(-0.3, 0.3), _rng.randf_range(-0.4, 0.4))
		tracer(prev, p, Color(0.6, 0.85, 1.0), 0.08, 0.12)
		prev = p


## Dauerhafter Flammen-Emitter (Flammenwerfer, Flammenturm). Zeigt in lokale +Z-Richtung.
func make_flame(parent: Node3D, rng: float) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.28, 0.28, 0.28)
	p.mesh = bm
	p.amount = 36
	p.lifetime = 0.42
	p.local_coords = false
	p.direction = Vector3(0, 0.05, 1)
	p.spread = 11.0
	p.initial_velocity_min = rng / 0.42 * 0.8
	p.initial_velocity_max = rng / 0.42
	p.gravity = Vector3(0, 2.0, 0)
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.6
	var grad := Gradient.new()
	grad.set_color(0, Color(1.0, 0.95, 0.5, 1.0))
	grad.set_color(1, Color(0.9, 0.15, 0.02, 0.0))
	grad.add_point(0.5, Color(1.0, 0.5, 0.08, 0.9))
	p.color_ramp = grad
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	p.material_override = m
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.emitting = false
	parent.add_child(p)
	return p


## Buntes Konfetti (Bau fertig, Welle geschafft, Sieg).
func confetti(pos: Vector3, bursts := 4) -> void:
	var cols := [Color("FFD23E"), Color("38A9F5"), Color("FB3D54"), Color("56C83C"), Color("B46CFF"), Color.WHITE]
	for i in bursts:
		puff(pos + Vector3(_rng.randf_range(-1.2, 1.2), 1.0 + _rng.randf() * 1.5, _rng.randf_range(-1.2, 1.2)), cols[_rng.randi() % cols.size()], 12, 1.6)
	ring(pos, 4.0, Color("FFD23E"), 0.5)


## Dauer-Partikel an einem Modell: "smoke" (Schornstein), "steam" (weiß), "spark" (Funken).
func make_emitter(parent: Node3D, kind: String) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	var bm := BoxMesh.new()
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var grad := Gradient.new()
	p.local_coords = false
	p.direction = Vector3.UP
	if kind == "spark":
		bm.size = Vector3(0.07, 0.07, 0.07)
		p.amount = 5
		p.lifetime = 0.5
		p.explosiveness = 0.6
		p.randomness = 1.0
		p.spread = 60.0
		p.initial_velocity_min = 1.5
		p.initial_velocity_max = 3.5
		p.gravity = Vector3(0, -8, 0)
		grad.set_color(0, Color(1.0, 0.95, 0.5, 1.0))
		grad.set_color(1, Color(1.0, 0.4, 0.05, 0.0))
	else:
		bm.size = Vector3(0.3, 0.3, 0.3)
		p.amount = 7
		p.lifetime = 2.4
		p.spread = 14.0
		p.initial_velocity_min = 0.7
		p.initial_velocity_max = 1.2
		p.gravity = Vector3(0.25, 0.3, 0.1)
		p.scale_amount_min = 0.6
		p.scale_amount_max = 1.2
		var cv := Curve.new()
		cv.add_point(Vector2(0, 0.5))
		cv.add_point(Vector2(1, 1.8))
		p.scale_amount_curve = cv
		var c := Color(1, 1, 1) if kind == "steam" else Color(0.62, 0.62, 0.66)
		grad.set_color(0, Color(c.r, c.g, c.b, 0.0))
		grad.add_point(0.15, Color(c.r, c.g, c.b, 0.75))
		grad.set_color(grad.get_point_count() - 1, Color(c.r, c.g, c.b, 0.0))
	p.mesh = bm
	p.color_ramp = grad
	p.material_override = m
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(p)
	if kind != "spark":
		_wind_emitters.append(p)
		if wind_set:
			p.gravity = Vector3(wind.x, 0.3, wind.z)
	return p


## Gemeinsamer Wind (nur Hauptbasis, weather.gd): Rauch und Dampf treiben mit. v = Seitwärts-Schub (x, z).
func set_wind(v: Vector3) -> void:
	wind = v
	wind_set = true
	var i := _wind_emitters.size() - 1
	while i >= 0:
		var p = _wind_emitters[i]
		if not is_instance_valid(p):
			_wind_emitters.remove_at(i)
		else:
			(p as CPUParticles3D).gravity = Vector3(v.x, 0.3, v.z)
		i -= 1


func _process(dt: float) -> void:
	_splats = 0
	for x in _texts:
		if x.t > 0.0:
			x.t -= dt
			x.n.global_position.y += dt * 1.6
			x.n.modulate.a = clampf(x.t / 0.3, 0.0, 1.0)
			if x.t <= 0.0:
				x.n.visible = false
	for tr in _tracers:
		if tr.t > 0.0:
			tr.t -= dt
			if tr.t <= 0.0:
				tr.n.visible = false
	for f in _flashes:
		if f.t > 0.0:
			f.t -= dt
			if f.t <= 0.0:
				f.n.visible = false
	for r in _rings:
		if r.t > 0.0:
			r.t -= dt
			var k: float = 1.0 - maxf(r.t, 0.0) / r.d
			var s: float = lerpf(0.3, r.r, 1.0 - (1.0 - k) * (1.0 - k))
			r.n.scale = Vector3(s, 1.0, s)
			var c: Color = r.c
			c.a = 1.0 - k
			(r.n.material_override as StandardMaterial3D).albedo_color = c
			if r.t <= 0.0:
				r.n.visible = false
	for b in _booms:
		if b.t > 0.0:
			b.t -= dt
			var k2: float = 1.0 - maxf(b.t, 0.0) / b.d
			var s2: float = lerpf(0.4, b.r, sqrt(k2))
			b.n.scale = Vector3(s2, s2, s2)
			var c2: Color = b.c.lerp(Color(0.2, 0.15, 0.12), k2)
			c2.a = 1.0 - k2 * k2
			(b.n.material_override as StandardMaterial3D).albedo_color = c2
			if b.t <= 0.0:
				b.n.visible = false
	if _light_t > 0.0:
		_light_t -= dt
		if _light_t <= 0.0:
			_light.light_energy = 0.0
