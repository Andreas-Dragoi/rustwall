extends Node3D
## Wind, Wetter und Tageszeit der Hauptbasis (Auftrag V3, Paket 5).
##
## Wind: ein einziger Wert mit Richtung und Stärke, der sich langsam dreht und in Böen anschwillt. Er geht an
## Gras, Blumen, Baumkronen (MK.mat_wind3), den Boden (helle Böen-Wellen), Fahnen (world.flag_yaw), Rauch
## (fx.set_wind) und Blätter in der Luft.
## Tageszeit aus der Geräte-Uhr: vier weich überblendete Stimmungen (Morgen, Tag, Abend, Nacht).
## Regen gelegentlich (alle 20–40 Minuten für 2–4 Minuten) mit Pfützen-Glanz, danach kurz ein Regenbogen.
## Testschalter: --daytime=morgen|tag|abend|nacht, --rain=1.

const MK = preload("res://src/mk.gd")
const Nature = preload("res://src/base_nature.gd")

const MOODS := ["morgen", "tag", "abend", "nacht"]
## Stimmungen: Sonnenfarbe, Sonnenkraft, Höhe und Richtung der Sonne (Grad), Umgebungslicht, Nebel, Laternen, Fenster
const MOOD := {
	"morgen": {"sun": Color("FFD3A0"), "e": 1.2, "pitch": -24.0, "yaw": -75.0, "amb": Color(0.95, 0.86, 0.86), "ae": 0.78, "fog": Color("F0DCC8"), "fd": 0.0028, "lamp": 0.25, "glow": 1.6},
	"tag": {"sun": Color("FFF0CF"), "e": 1.35, "pitch": -52.0, "yaw": -30.0, "amb": Color(0.82, 0.86, 1.0), "ae": 0.75, "fog": Color("CFE6F5"), "fd": 0.0022, "lamp": 0.0, "glow": 1.6},
	"abend": {"sun": Color("FFB27A"), "e": 1.05, "pitch": -26.0, "yaw": 50.0, "amb": Color(0.92, 0.8, 0.82), "ae": 0.8, "fog": Color("E6C2A6"), "fd": 0.0026, "lamp": 0.9, "glow": 1.85},
	"nacht": {"sun": Color("A8BEFF"), "e": 0.75, "pitch": -58.0, "yaw": -40.0, "amb": Color(0.55, 0.65, 1.0), "ae": 1.2, "fog": Color("26355E"), "fd": 0.003, "lamp": 1.0, "glow": 2.1},
}
## Stundenmarken (Geräte-Uhr) -> Stimmung; dazwischen wird überblendet
const HOURS := [[0.0, "nacht"], [5.0, "nacht"], [6.0, "morgen"], [9.0, "morgen"], [10.0, "tag"], [17.0, "tag"], [18.0, "abend"],
	[20.5, "abend"], [21.5, "nacht"], [24.0, "nacht"]]
const RAIN_GAP := [1200.0, 2400.0]
const RAIN_LEN := [120.0, 240.0]
const TRAMPLE_N := 16
const TRAMPLE_FADE := 8.0
const STEPS_N := 48

static var force := ""           # Admin/Testschalter: feste Tageszeit ("" = Geräte-Uhr)
static var force_rain := -1      # Admin: -1 normal, 1 Regen jetzt, 0 Regen aus

var w: Node3D
var nature: Node3D
var wind_angle := 0.6
var wind_str := 0.45
var wind_dir := Vector2(0.8, 0.6)
var gust := 0.0
var wind_phase := 0.0
var mood_w := {}                 # Stimmung -> Anteil 0..1
var day_k := 1.0
var night_k := 0.0
var rain_k := 0.0                # Regenstärke 0..1
var fog_extra := 0.0             # V6 Paket B: Nebel der Flut (zusätzliche Nebeldichte)
var _fog_now := 0.0
var wet := 0.0
var raining := false
var rainbow_k := 0.0
var last_us := 0.0               # Rechenzeit des letzten Bilds (Mikrosekunden)
var _gust_t := 4.0
var _gust_len := 0.0
var _gust_age := 0.0
var _target_angle := 0.6
var _target_str := 0.45
var _turn_t := 0.0
var _rain_t := 0.0
var _rain_left := 0.0
var _rain: CPUParticles3D
var _leaves: CPUParticles3D
var _rainbow: MeshInstance3D
var _rainbow_mat: ShaderMaterial
var _trample: Array = []         # Vector4 (x, z, Radius, Alter)
var _trample_t := 0.0
var _steps: MultiMesh
var _step_age := PackedFloat32Array()
var _step_i := 0
var _step_last := Vector2(1.0e6, 1.0e6)
var _step_side := false
var _fx_t := 0.0
var _snd_t := 0.0
var _rng := RandomNumberGenerator.new()
var _env_t := 0.0


func setup(world: Node3D, nat: Node3D) -> void:
	w = world
	nature = nat
	_rng.randomize()
	var dt_arg := G.arg("daytime")
	if dt_arg in MOODS:
		force = dt_arg
	elif dt_arg == "" and (G.selftest or G.autotest != ""):
		force = "tag"          # Tests sollen nicht von der Uhrzeit abhängen (nachts schlafen die Bewohner)
	wind_angle = _rng.randf() * TAU
	_target_angle = wind_angle
	_rain_t = _rng.randf_range(RAIN_GAP[0], RAIN_GAP[1])
	if G.arg("rain") == "1":
		_start_rain(true)
	_make_rain()
	_make_leaves()
	_make_rainbow()
	_make_steps()
	for i in TRAMPLE_N:
		_trample.append(Vector4(0, 0, 0, 99.0))
	_update_daytime(0.0, true)


func _exit_tree() -> void:
	MK.mat_glow().set_shader_parameter("boost", 1.6)


# ---------------------------------------------------------------- Wind
func _tick_wind(dt: float) -> void:
	_turn_t -= dt
	if _turn_t <= 0.0:
		_turn_t = _rng.randf_range(12.0, 30.0)
		_target_angle = wind_angle + _rng.randf_range(-0.9, 0.9)
		_target_str = _rng.randf_range(0.25, 0.75) + (0.25 if raining else 0.0)
	wind_angle = lerp_angle(wind_angle, _target_angle, minf(1.0, dt * 0.05))
	wind_str = lerpf(wind_str, _target_str, minf(1.0, dt * 0.08))
	wind_dir = Vector2(cos(wind_angle), sin(wind_angle))
	# Böen: schwellen an und ab, alle 6–16 s
	_gust_t -= dt
	if _gust_t <= 0.0 and _gust_len <= 0.0:
		_gust_len = _rng.randf_range(3.0, 6.0)
		_gust_age = 0.0
	if _gust_len > 0.0:
		_gust_age += dt
		gust = sin(clampf(_gust_age / _gust_len, 0.0, 1.0) * PI) * (0.6 + wind_str * 0.6)
		if _gust_age >= _gust_len:
			_gust_len = 0.0
			gust = 0.0
			_gust_t = _rng.randf_range(6.0, 16.0)
	wind_phase += dt * (1.4 + wind_str * 1.6)


## Fahnen wehen in Windrichtung (Tuch liegt im Modell entlang +X), Banner schwingen wie bisher.
func flag_yaw(n: Node3D, base: float, t: float, ph: float) -> float:
	var nm := String(n.name)
	if not nm.contains("flag"):
		return base + sin(t * 2.6 + ph) * 0.22
	var par := n.get_parent() as Node3D
	var py := par.global_rotation.y if par != null else 0.0
	var target := atan2(-wind_dir.y, wind_dir.x)
	return target - py + sin(t * (2.0 + wind_str * 3.0) + ph) * (0.1 + 0.18 * wind_str + gust * 0.15)


# ---------------------------------------------------------------- Tageszeit
func hour_now() -> float:
	var d := Time.get_datetime_dict_from_system()
	return float(d.hour) + float(d.minute) / 60.0


func _weights(h: float) -> Dictionary:
	var out := {"morgen": 0.0, "tag": 0.0, "abend": 0.0, "nacht": 0.0}
	if force != "":
		out[force] = 1.0
		return out
	for i in HOURS.size() - 1:
		var a: Array = HOURS[i]
		var b: Array = HOURS[i + 1]
		if h >= a[0] and h <= b[0]:
			var k: float = 0.0 if b[0] == a[0] else (h - a[0]) / (b[0] - a[0])
			k = k * k * (3.0 - 2.0 * k)
			out[a[1]] += 1.0 - k
			out[b[1]] += k
			return out
	out["tag"] = 1.0
	return out


func _update_daytime(dt: float, snap := false) -> void:
	var target := _weights(hour_now())
	for m in MOODS:
		var cur: float = mood_w.get(m, target[m])
		mood_w[m] = target[m] if snap else move_toward(cur, target[m], dt * 0.5)
	var best := "tag"
	var bw := -1.0
	for m in MOODS:
		if mood_w[m] > bw:
			bw = mood_w[m]
			best = m
	w.daytime = best
	night_k = mood_w["nacht"]
	day_k = mood_w["tag"]
	var sc := Color(0, 0, 0)
	var amb := Color(0, 0, 0)
	var fog := Color(0, 0, 0)
	var e := 0.0
	var pitch := 0.0
	var yaw := 0.0
	var ae := 0.0
	var fd := 0.0
	var lamp := 0.0
	var glow := 0.0
	for m in MOODS:
		var k: float = mood_w[m]
		var s: Dictionary = MOOD[m]
		sc += s.sun * k
		amb += s.amb * k
		fog += s.fog * k
		e += s.e * k
		pitch += s.pitch * k
		yaw += s.yaw * k
		ae += s.ae * k
		fd += s.fd * k
		lamp += s.lamp * k
		glow += s.glow * k
	# Regen dämpft das Licht etwas
	e *= 1.0 - 0.25 * rain_k
	ae *= 1.0 - 0.1 * rain_k
	if w.sun != null:
		w.sun.light_color = sc
		w.sun.light_energy = e
		w.sun.rotation = Vector3(deg_to_rad(pitch), deg_to_rad(yaw), 0)
	var env: Environment = w.world_env
	if env != null:
		env.ambient_light_color = amb
		env.ambient_light_energy = ae
		env.fog_light_color = fog.lerp(Color(0.6, 0.65, 0.72), rain_k * 0.4)
		_fog_now = move_toward(_fog_now, fog_extra, dt * 0.01 if not snap else 1.0)
		env.fog_density = fd + rain_k * 0.002 + _fog_now
		if _fog_now > 0.0001:
			env.fog_light_color = env.fog_light_color.lerp(Color(0.74, 0.77, 0.8), clampf(_fog_now * 45.0, 0.0, 0.7))
		env.background_color = env.fog_light_color
	if nature != null and nature.lamp_mat != null:
		nature.lamp_mat.albedo_color = Color(0.42, 0.4, 0.36).lerp(Color(1.0, 0.86, 0.45), clampf(lamp + rain_k * 0.3, 0.0, 1.0))
	MK.mat_glow().set_shader_parameter("boost", glow)


func is_night() -> bool:
	return w.daytime == "nacht"


# ---------------------------------------------------------------- Regen
func rain_allowed() -> bool:
	return bool(P.d.settings.get("rain", true))


func _start_rain(now := false) -> void:
	raining = true
	_rain_left = _rng.randf_range(RAIN_LEN[0], RAIN_LEN[1])
	if now:
		rain_k = 1.0
		wet = 1.0


func _stop_rain() -> void:
	if raining:
		raining = false
		rainbow_k = 1.0 if night_k < 0.5 else 0.0
	_rain_t = _rng.randf_range(RAIN_GAP[0], RAIN_GAP[1])


func _tick_rain(dt: float) -> void:
	if force_rain == 1 and not raining:
		_start_rain()
	elif force_rain == 0 and raining:
		_stop_rain()
	force_rain = -1
	if not rain_allowed() and raining:
		_stop_rain()
	if raining:
		_rain_left -= dt
		if _rain_left <= 0.0:
			_stop_rain()
	elif rain_allowed():
		_rain_t -= dt
		if _rain_t <= 0.0:
			_start_rain()
	rain_k = move_toward(rain_k, 1.0 if raining else 0.0, dt / 8.0)
	wet = move_toward(wet, 1.0 if raining else 0.0, dt / (20.0 if raining else 60.0))
	rainbow_k = move_toward(rainbow_k, 0.0, dt / 45.0)
	if _rain != null:
		_rain.emitting = rain_k > 0.15
		_rain.gravity = Vector3(wind_dir.x * (2.0 + wind_str * 6.0), -32.0, wind_dir.y * (2.0 + wind_str * 6.0))
	if _rainbow != null:
		_rainbow.visible = rainbow_k > 0.01
		if _rainbow.visible:
			_rainbow_mat.set_shader_parameter("alpha", minf(rainbow_k * 1.5, 1.0) * 0.55)


func _make_rain() -> void:
	var p := CPUParticles3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.035, 0.7, 0.035)
	p.mesh = bm
	p.amount = [160, 320, 520][G.quality()]
	p.lifetime = 0.55
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(26, 1, 22)
	p.direction = Vector3(0, -1, 0)
	p.spread = 4.0
	p.initial_velocity_min = 12.0
	p.initial_velocity_max = 15.0
	p.gravity = Vector3(0, -32, 0)
	p.local_coords = false
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(0.8, 0.88, 1.0, 0.45)
	p.material_override = m
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.emitting = false
	add_child(p)
	_rain = p


func _make_leaves() -> void:
	var p := CPUParticles3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.16, 0.02, 0.1)
	p.mesh = bm
	p.amount = [8, 16, 26][G.quality()]
	p.lifetime = 6.0
	p.preprocess = 6.0
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(24, 3, 20)
	p.local_coords = false
	p.spread = 30.0
	p.initial_velocity_min = 0.5
	p.initial_velocity_max = 1.2
	p.angular_velocity_min = -200.0
	p.angular_velocity_max = 200.0
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	p.material_override = m
	var g := Gradient.new()
	g.set_color(0, Color(0.5, 0.75, 0.25))
	g.set_color(1, Color(0.95, 0.65, 0.2))
	p.color_initial_ramp = g
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(p)
	_leaves = p


func _make_rainbow() -> void:
	var mi := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(110, 55)
	mi.mesh = qm
	_rainbow_mat = ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = """shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, fog_disabled;
uniform float alpha = 0.5;
void fragment() {
	vec2 p = vec2(UV.x - 0.5, 1.0 - UV.y) * vec2(2.0, 1.0);
	float r = length(p);
	float t = (r - 0.72) / 0.2;
	if (t < 0.0 || t > 1.0) { discard; }
	vec3 c = clamp(abs(mod(t * 5.0 + vec3(0.0, 4.0, 2.0), 6.0) - 3.0) - 1.0, 0.0, 1.0);
	ALBEDO = mix(vec3(1.0), c, 0.85);
	ALPHA = alpha * sin(t * 3.14159) * smoothstep(0.0, 0.25, p.y);
}
"""
	_rainbow_mat.shader = sh
	mi.material_override = _rainbow_mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visible = false
	add_child(mi)
	_rainbow = mi


# ---------------------------------------------------------------- Fußspuren, platt gedrücktes Gras
func _make_steps() -> void:
	var Models = load("res://src/models.gd")
	if not Models.has_glb("p_footprint"):
		return
	_steps = MultiMesh.new()
	_steps.transform_format = MultiMesh.TRANSFORM_3D
	_steps.use_colors = true
	_steps.mesh = Models.glb_mesh("p_footprint", "body")
	_steps.instance_count = STEPS_N
	_step_age.resize(STEPS_N)
	_step_age.fill(99.0)
	for i in STEPS_N:
		_steps.set_instance_transform(i, Transform3D(Basis.IDENTITY.scaled(Vector3.ZERO), Vector3.ZERO))
		_steps.set_instance_color(i, Color(1, 1, 1, 0))
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = _steps
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(1, 1, 1, 0.55)
	m.roughness = 1.0
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.custom_aabb = AABB(Vector3(-70, -1, -70), Vector3(140, 3, 140))
	add_child(mi)


func _tick_traces(dt: float) -> void:
	var h: Node3D = w.hero
	var hp := Vector2(1.0e6, 1.0e6)
	if h != null and h.alive:
		hp = Vector2(h.global_position.x, h.global_position.z)
	# Fahrzeug drückt das Gras platt
	_trample_t -= dt
	for i in TRAMPLE_N:
		var t: Vector4 = _trample[i]
		t.w += dt
		_trample[i] = t
	if h != null and h.alive and h.mounted and h.speed_now > 1.0 and _trample_t <= 0.0:
		_trample_t = 0.5
		var oldest := 0
		for i in TRAMPLE_N:
			if _trample[i].w > _trample[oldest].w:
				oldest = i
		_trample[oldest] = Vector4(hp.x, hp.y, 2.0, 0.0)
	# Fußspuren auf Sand und Wegen
	if _steps != null and h != null and h.alive and not h.mounted:
		if hp.distance_to(_step_last) > 0.95:
			var on_sand: bool = Nature.coast_s(hp) > Nature.BEACH_S + 1.0 or (nature != null and nature.on_path(hp))
			_step_last = hp
			if on_sand:
				var yaw: float = h.body.global_rotation.y if h.body != null else h.global_rotation.y
				_steps.set_instance_transform(_step_i, Transform3D(Basis(Vector3.UP, yaw), Vector3(hp.x, 0.03, hp.y)))
				_step_age[_step_i] = 0.0
				_step_i = (_step_i + 1) % STEPS_N
	if _steps != null:
		for i in STEPS_N:
			if _step_age[i] < TRAMPLE_FADE:
				_step_age[i] += dt
				_steps.set_instance_color(i, Color(1, 1, 1, clampf(1.0 - _step_age[i] / TRAMPLE_FADE, 0.0, 1.0)))


# ---------------------------------------------------------------- jedes Bild
func _process(dt: float) -> void:
	var t0 := Time.get_ticks_usec()
	_tick_wind(dt)
	_tick_rain(dt)
	_env_t -= dt
	if _env_t <= 0.0:
		_env_t = 0.1
		_update_daytime(0.1)
	_tick_traces(dt)
	var hero_pos := Vector3(0, -100, 0)
	if w.hero != null and w.hero.alive:
		hero_pos = w.hero.global_position
	var half := P.grid_size() * 0.5 * 2.0
	var editing: bool = w.has_method("editing") and w.editing()
	var tr := PackedVector4Array()
	tr.resize(TRAMPLE_N)
	for i in TRAMPLE_N:
		var t: Vector4 = _trample[i]
		tr[i] = Vector4(t.x, t.y, t.z, clampf(1.0 - t.w / TRAMPLE_FADE, 0.0, 1.0))
	var flat_k: float = 0.12 if editing else 1.0
	for m in MK.wind3_mats():
		m.set_shader_parameter("wind_dir", wind_dir)
		m.set_shader_parameter("wind_str", wind_str)
		m.set_shader_parameter("wind_phase", wind_phase)
		m.set_shader_parameter("gust", gust)
		m.set_shader_parameter("hero_pos", hero_pos)
		m.set_shader_parameter("trample", tr)
		m.set_shader_parameter("flat_k", flat_k)
		m.set_shader_parameter("grid_rect", Vector4(-half, -half, half, half))
	if w.ground_mat != null:
		w.ground_mat.set_shader_parameter("wind_dir", wind_dir)
		w.ground_mat.set_shader_parameter("wind_phase", wind_phase)
		w.ground_mat.set_shader_parameter("gust", gust)
		w.ground_mat.set_shader_parameter("wet", wet)
	var focus := Vector3.ZERO
	if w.cam != null:
		focus = w.cam.focus
	if _rain != null:
		_rain.global_position = focus + Vector3(0, 14, 0)
	if _leaves != null:
		_leaves.global_position = focus + Vector3(0, 3, 0)
		_leaves.gravity = Vector3(wind_dir.x, -0.25, wind_dir.y) * (0.6 + wind_str * 1.6 + gust)
		_leaves.direction = Vector3(wind_dir.x, 0.2, wind_dir.y)
	if _rainbow != null and _rainbow.visible:
		var cam := get_viewport().get_camera_3d()
		if cam != null:
			var back := -cam.global_transform.basis.z
			back.y = 0.0
			back = back.normalized() if back.length() > 0.01 else Vector3(0, 0, -1)
			_rainbow.global_position = focus + back * 70.0 + Vector3(0, -6, 0)
			_rainbow.look_at(cam.global_position, Vector3.UP, true)
	_fx_t -= dt
	if _fx_t <= 0.0 and G.fx != null:
		_fx_t = 0.5
		G.fx.set_wind(Vector3(wind_dir.x, 0.0, wind_dir.y) * (0.3 + wind_str * 1.2 + gust * 0.6))
	_snd_t -= dt
	if _snd_t <= 0.0:
		_snd_t = 0.5
		_sounds(focus)
	last_us = float(Time.get_ticks_usec() - t0)
	if G.arg("drawinfo") == "1" and Engine.get_process_frames() % 30 == 0:
		print("DRAWINFO calls=%d objects=%d prims=%d fps=%d wetter=%.3fms" % [
			get_viewport().get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE, Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME),
			get_viewport().get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE, Viewport.RENDER_INFO_OBJECTS_IN_FRAME),
			get_viewport().get_render_info(Viewport.RENDER_INFO_TYPE_VISIBLE, Viewport.RENDER_INFO_PRIMITIVES_IN_FRAME), Engine.get_frames_per_second(), last_us / 1000.0])


## Umgebungsklang: Vögel am Tag, Grillen nachts, Wind in den Bäumen, Wellen an der Küste, Regen.
func _sounds(focus: Vector3) -> void:
	if w.mode != "peace":
		for id in ["nat_birds", "nat_crickets", "nat_wind"]:
			Sfx.stop(id)
	else:
		Sfx.loop("nat_birds", "amb_birds", -24.0 + 6.0 * (1.0 - night_k) - 40.0 * night_k, 1.0, 1.0)
		Sfx.loop("nat_crickets", "amb_crickets", -26.0 + 6.0 * night_k - 40.0 * (1.0 - night_k), 1.0, 1.0)
		Sfx.loop("nat_wind", "amb_wind_trees", -30.0 + 10.0 * (wind_str + gust * 0.5), 1.0, 1.0)
	var sea_d := maxf(0.0, Nature.shore_at(Vector2(focus.x, focus.z)) - Nature.coast_s(Vector2(focus.x, focus.z)))
	Sfx.loop("nat_waves", "amb_waves", -18.0 - sea_d * 0.6, 1.0, 1.0)
	if rain_k > 0.05:
		Sfx.loop("nat_rain", "amb_rain", -26.0 + 10.0 * rain_k, 1.0, 1.0)
	elif Sfx.looping("nat_rain"):
		Sfx.stop("nat_rain")
